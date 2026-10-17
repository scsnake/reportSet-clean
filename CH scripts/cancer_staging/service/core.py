"""Actions of the service: who may send, send approved cases, write results to the sheet."""

from __future__ import annotations

import copy
import threading
import time
from datetime import datetime, timedelta, timezone
from typing import Any

import workflow
from api_client import WebRISApi, WebRISApiError
from batch import _normalized_report, load_sent_ledger, run_batch

from . import ris
from .config import TODO_STATUS, Settings
from .sheets import SheetClient, SheetError
from .store import Store
from .sync import sync_sheet


SIGNIN_MAX_FAILS = 5
SIGNIN_WINDOW_MIN = 15


class Refused(Exception):
    """The request is not allowed or not possible; the message is shown to the doctor."""


class App:
    def __init__(self, settings: Settings, store: Store, sheet: SheetClient, catalog) -> None:
        self.settings, self.store, self.sheet, self.catalog = settings, store, sheet, catalog
        self._locks: dict[str, threading.RLock] = {}
        self._guard = threading.Lock()
        self._saved: dict[str, tuple[float, bool]] = {}
        self.sending: dict[str, bool] = {}
        self.last_send: dict[str, dict[str, Any]] = {}
        self.api_factory = WebRISApi  # replaced in tests

    def lock(self, doctor: str) -> threading.RLock:
        with self._guard:
            return self._locks.setdefault(doctor, threading.RLock())

    # ---- who may send ----------------------------------------------------------------------
    def credential_saved(self, userid: str, *, fresh: bool = False) -> bool:
        """True when WebRIS can log this user in without a password (login is saved there)."""
        cached = self._saved.get(userid)
        if cached and not fresh and time.time() - cached[0] < 300:
            return cached[1]
        api = self.api_factory(self.settings.webris_url)
        try:
            api.login(userid, None)
            api.logout()
            saved = True
        except WebRISApiError:
            saved = False
        self._saved[userid] = (time.time(), saved)
        return saved

    def send_open(self, doctor: str) -> bool:
        return self.settings.send_enabled and (not self.settings.send_doctors or doctor in self.settings.send_doctors)

    def signed_in(self, token: str, doctor: str) -> dict[str, Any] | None:
        """The sign-in of this browser for this doctor, while it is still valid."""
        device = self.store.device(token, doctor)
        if not device:
            return None
        until = datetime.fromisoformat(device["trusted_at"]) + timedelta(hours=self.settings.signin_hours)
        return {**device, "until": until.isoformat()} if until > datetime.now(timezone.utc) else None

    def readiness(self, doctor: str, token: str) -> dict[str, Any]:
        userid = self.store.ris_userid(doctor)
        session = self.signed_in(token, doctor)
        out: dict[str, Any] = {
            "send_open": self.send_open(doctor),
            "userid_known": bool(userid),
            "signed_in": bool(session),
            "signed_in_until": session["until"] if session else None,
            "ris_userid": userid if session else "",
            "auto_send": bool(session and session["auto_send"]),
            "credential_saved": None,
        }
        if not out["send_open"]:
            out["why_not"] = "Sending from this page is not open for your name. Review and approval work."
        elif not session:
            out["why_not"] = "Sign in with your RIS account to send."
        else:
            out["credential_saved"] = self.credential_saved(userid)
            if not out["credential_saved"]:
                out["why_not"] = "Your RIS login is not saved in WebRIS. Open the login page and save it."
        out["can_send"] = "why_not" not in out
        return out

    def sign_in(self, doctor: str, token: str, userid: str, password: str) -> dict[str, Any]:
        """WebRIS checks the typed RIS login (the password is never stored); the RIS account must be this doctor's."""
        if not self.send_open(doctor):
            raise Refused("Sending from this page is not open for your name.")
        userid = (userid or self.store.ris_userid(doctor)).strip()
        if not userid or not password or not token:
            raise Refused("RIS user ID and password are needed.")
        # Each wrong password counts against the RIS account too; stop before RIS locks it.
        since = (datetime.now(timezone.utc) - timedelta(minutes=SIGNIN_WINDOW_MIN)).isoformat()
        if self.store.count_events("signin_failed", doctor=doctor, since=since) >= SIGNIN_MAX_FAILS:
            raise Refused(f"Too many failed sign-ins for {doctor}. Wait {SIGNIN_WINDOW_MIN} minutes.")
        try:
            api = self.api_factory(self.settings.webris_url)
            try:
                name = str(api.login(userid, password).get("user") or "")
                api.logout()
            except WebRISApiError as exc:
                raise Refused(f"RIS login failed: {exc}") from exc
            name_matches = bool(name) and (doctor in name or name in doctor)
            if not name_matches and self.store.ris_userid(doctor) != userid:
                raise Refused(f"This RIS account belongs to {name or 'another user'}, not to {doctor}.")
        except Refused as exc:
            self.store.log("signin_failed", doctor=doctor, device=token, userid=userid, reason=str(exc)[:200])
            raise
        self.store.set_ris_userid(doctor, userid)
        self.store.trust_device(token, doctor)
        self.store.log("signed_in", doctor=doctor, device=token, userid=userid, ris_name=name)
        return {"signed_in": True, "credential_saved": self.credential_saved(userid, fresh=True)}

    def sign_out(self, doctor: str, token: str) -> dict[str, Any]:
        self.store.forget_device(token, doctor)
        self.store.log("signed_out", doctor=doctor, device=token)
        return {"signed_in": False}

    # ---- send --------------------------------------------------------------------------------
    def send(self, doctor: str, token: str, confirmed: dict[str, str] | None = None) -> dict[str, Any]:
        """Dry-run the approved cases, send the ones that pass, then read each back from RIS.

        `confirmed` maps accession -> approved text SHA that the doctor saw in the confirmation
        dialog; only those cases go, and only while their approved text is unchanged.
        None (auto-send on Approve) means every approved case.
        """
        state = self.readiness(doctor, token)
        if not state["can_send"]:
            raise Refused(state["why_not"])
        if confirmed is not None and not confirmed:
            raise Refused("No study was confirmed for sending.")
        userid = self.store.ris_userid(doctor)
        url, ledger = self.settings.webris_url, self.settings.ledger_path
        with self.lock(doctor):
            review = self.store.load_review(doctor)
            changed: list[dict[str, Any]] = []
            if confirmed is not None:
                current = {str(case["source"]["accession"]): case["approval"]["approved_text_sha256"]
                           for case in workflow.sendable_cases(review)}
                keep = {accession for accession, sha in confirmed.items() if current.get(accession) == sha}
                changed = [{"accession": accession, "reason": "not approved or changed after the confirmation"}
                           for accession in confirmed if accession not in keep]
                review = {**review, "cases": [case for case in review["cases"]
                                              if str(case["source"]["accession"]) in keep]}
            if not workflow.sendable_cases(review):
                return {"sent": [], "failed": changed, "message": "No approved study is waiting to be sent."}
            self.sending[doctor] = True
            try:
                preview = run_batch(copy.deepcopy(review), api_url=url, execute=False, userid=userid,
                                    ledger_path=ledger)
                passed = {str(item["accession"]) for item in preview if item["status"] == "ok"}
                failed = changed + [{"accession": item["accession"],
                                     "reason": item.get("error") or item.get("reason", "")}
                                    for item in preview if item["status"] != "ok"]
                results: list[dict[str, Any]] = []
                if passed:
                    subset = {**review, "cases": [case for case in review["cases"]
                                                  if str(case["source"]["accession"]) in passed]}
                    results = run_batch(subset, api_url=url, execute=True, userid=userid, ledger_path=ledger,
                                        expected_batch_sha256=workflow.batch_sha256(subset))
                    for case in subset["cases"]:
                        # What RIS did must be recorded whatever else changed meanwhile.
                        body = {key: value for key, value in case.items() if key not in ("source", "_rev")}
                        self.store.update_case(case["source"]["accession"], review=body)
                sent = []
                for item in results:
                    response = item.get("response") or {}
                    if item["status"] == "ok" and response.get("submitted"):
                        sent.append(str(item["accession"]))
                    else:
                        failed.append({"accession": item["accession"],
                                       "reason": item.get("error") or item.get("reason") or "not submitted"})
                    self.store.log("ris_send", accession=item["accession"], doctor=doctor, device=token,
                                   status=item["status"], submitted=bool(response.get("submitted")),
                                   error=item.get("error", ""))
                for item in failed:
                    self.store.log("ris_send_refused", accession=item["accession"], doctor=doctor, device=token,
                                   reason=item["reason"])
                readback = self._read_back(sent)
            finally:
                self.sending[doctor] = False
            out: dict[str, Any] = {"sent": sent, "failed": failed, "readback": readback}
            if sent and self.settings.sheet_write == "auto":
                out["sheet"] = self.write_sheet(doctor, token, only=sent)
            out["at"] = datetime.now(timezone.utc).isoformat()
            self.last_send[doctor] = out
            return out

    def _read_back(self, accessions: list[str]) -> dict[str, Any]:
        """Read-only check: the RIS report now holds exactly one staging block with the sent text."""
        out: dict[str, Any] = {}
        if not accessions:
            return out
        api = self.api_factory(self.settings.webris_url)
        api.login(None, None)
        try:
            for accession in accessions:
                case = self.store.get_case(accession)
                try:
                    state = ris.fetch_report(api, accession, case["chart_no"])
                    text = _normalized_report(case["review"]["proposal"]["staging_text"]).strip()
                    ok = (not state.get("error") and state.get("staging_blocks") == 1
                          and text in _normalized_report(state.get("exam", "")))
                    result = {"ok": bool(ok), "blocks": state.get("staging_blocks"), "error": state.get("error", "")}
                except Exception as exc:
                    result = {"ok": False, "error": f"{type(exc).__name__}: {exc}"[:200]}
                result["at"] = datetime.now(timezone.utc).isoformat()
                review = case["review"]
                review["execution"]["readback"] = result
                self.store.update_case(accession, review=review)
                self.store.log("ris_readback", accession=accession, doctor=case["doctor"], **result)
                out[accession] = result
        finally:
            api.logout()
        return out

    def send_async(self, doctor: str, token: str) -> None:
        def work() -> None:
            try:
                self.send(doctor, token)
            except Exception as exc:
                self.last_send[doctor] = {"sent": [], "failed": [], "error": str(exc),
                                          "at": datetime.now(timezone.utc).isoformat()}
                self.store.log("ris_send_error", doctor=doctor, device=token, error=str(exc)[:300])

        threading.Thread(target=work, daemon=True, name=f"send-{doctor}").start()

    # ---- sheet ---------------------------------------------------------------------------------
    def sheet_pending(self, doctor: str) -> list[dict[str, Any]]:
        """Finished rows whose 癌別/完成 differ from the sheet (the paste-back block, row by row)."""
        review = self.store.load_review(doctor)
        rows = workflow.sheet_pasteback(review)["rows"] if review["cases"] else []
        return [row for row in rows
                if row["finished"] and row["original_status"] == TODO_STATUS
                and (row["cancer_type"], row["status"]) != (row["original_cancer_type"], row["original_status"])]

    def write_sheet(self, doctor: str, token: str = "", *, only: list[str] | None = None) -> dict[str, Any]:
        if self.settings.sheet_write == "off":
            raise Refused("Automatic sheet writing is off; use Sheet paste-back.")
        written, refused = [], []
        with self.lock(doctor):
            for row in self.sheet_pending(doctor):
                accession = row["accession"]
                if only is not None and accession not in only:
                    continue
                case = self.store.get_case(accession)
                try:
                    if not row["cancer_type"] or not row["status"]:
                        raise SheetError("Choose 癌別 and 完成 for this row first (Sheet paste-back)")
                    result = self.sheet.write_result(
                        accession=accession, chart_no=case["chart_no"],
                        cancer_type=row["cancer_type"], status=row["status"])
                    written.append({"accession": accession, **result,
                                    "cancer_type": row["cancer_type"], "status": row["status"]})
                    self.store.log("sheet_written", accession=accession, doctor=doctor, device=token,
                                   cancer_type=row["cancer_type"], status=row["status"], **result)
                except SheetError as exc:
                    refused.append({"accession": accession, "reason": str(exc)})
                    self.store.log("sheet_refused", accession=accession, doctor=doctor, device=token, reason=str(exc))
            if written:
                try:
                    sync_sheet(self.store, self.sheet.read_rows(), ledger=load_sent_ledger(self.settings.ledger_path))
                except Exception as exc:  # the next poll refreshes the list
                    self.store.log("sync_error", error=str(exc)[:300])
        return {"written": written, "refused": refused}
