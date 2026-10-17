"""Poll cycle: sheet -> cases -> read-only RIS fetch -> review case."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import workflow
from api_client import WebRISApi
from batch import _normalized_report, load_sent_ledger

from . import ris
from .config import TODO_STATUS, Settings
from .sheets import SheetClient, valid_identity
from .store import OPEN_PHASES, Store

NO_PROPOSAL = "No proposal yet. The night job writes one; you can also fill the form now."
# Sheet-owned fields of a case's source; the rest (report text, study date) comes from RIS.
SHEET_FIELDS = ("study_name", "report_date", "review_doctor", "patho_txt", "dx_txt", "cancer_type_existing",
                "status", "notes_txt", "notes2_txt", "notes3_txt", "input_row")


def staged_cancer_type(catalog, tumor_type: str, source: dict[str, Any]) -> str:
    """Sheet 癌別 for a staging block already in RIS ('Tumor Stage: <catalog name>')."""
    wanted = tumor_type.strip().lower()
    for cancer_id, cancer in catalog.documents.items():
        if wanted and cancer.get("name", cancer_id).strip().lower() == wanted:
            return workflow.CATALOG_SHEET_CANCER.get(cancer_id, "")
    return workflow._note_cancer_type(source)


def build_review(case: dict[str, Any], catalog) -> dict[str, Any]:
    """Review body (everything but `source`) of a fetched case, from its entry or RIS state."""
    source = case["source"]
    ris_state = case.get("ris") or {}
    if case["phase"] == "staged":
        entry: dict[str, Any] = {"skip": "RIS already has a cancer-staging block"
                                 + (f": {ris_state.get('stage_line')}" if ris_state.get("stage_line") else "")
                                 + ". Nothing to send; only the sheet row needs an update."}
    else:
        entry = case.get("entry") or {"skip": NO_PROPOSAL}
    try:
        built = workflow.prepare_case_from_proposal(source, entry, catalog)
    except ValueError as exc:
        built = workflow.prepare_case_from_proposal(
            source, {"skip": f"The saved proposal is not valid for the website form: {exc}"}, catalog)
    body = {key: value for key, value in built.items() if key != "source"}
    if case["phase"] == "staged":
        cancer_type = staged_cancer_type(catalog, ris_state.get("tumor_type", ""), source)
        body["sheet"] = {"status": "完成", **({"cancer_type": cancer_type} if cancer_type else {})}
    elif ris_state.get("differs_from_sheet"):
        body["proposal"]["warnings"].append(
            "The RIS report text differs from the sheet's 報告內容; the RIS text is shown and used.")
    return body


def has_human_work(review: dict[str, Any] | None) -> bool:
    return bool(review) and workflow.review_has_work({"cases": [review]})


def sync_sheet(store: Store, rows: list[dict[str, Any]], *, ledger: dict[str, Any] | None = None) -> dict[str, int]:
    """Refresh the sheet snapshot, open cases for new to-do rows, close cases that are done."""
    stats = {"rows": len(rows), "todo": 0, "created": 0, "closed": 0, "reopened": 0, "skipped": 0}
    ledger = ledger or {}
    with store.tx():
        store.replace_sheet_rows(rows)
        todo: dict[str, dict[str, Any]] = {}
        for row in rows:
            if row["status"] != TODO_STATUS:
                continue
            if row["duplicate"] or not valid_identity(row) or not row["review_doctor"]:
                stats["skipped"] += 1
                continue
            todo[row["accession"]] = row
        stats["todo"] = len(todo)
        for accession, row in todo.items():
            source = {key: value for key, value in row.items() if key != "duplicate"}
            case = store.get_case(accession)
            if case is None:
                store.create_case({**source, "sheet_report_txt": source["report_txt"],
                                   "sheet_study_date": source["study_date"]})
                store.log("case_created", accession=accession, doctor=row["review_doctor"], row=row["input_row"])
                stats["created"] += 1
                continue
            if case["chart_no"].lstrip("0") != row["chart_no"].lstrip("0"):
                store.update_case(accession, note="Sheet chart number changed; needs a manual check")
                continue
            merged = {**case["source"], **{key: source[key] for key in SHEET_FIELDS},
                      "sheet_report_txt": source["report_txt"], "sheet_study_date": source["study_date"]}
            fields: dict[str, Any] = {}
            if merged != case["source"]:
                fields["source"] = merged
            if case["doctor"] != row["review_doctor"]:
                fields["doctor"] = row["review_doctor"]
            if case["phase"] == "closed":
                if accession in ledger:
                    fields["note"] = "Sheet says 待修正 again, but this study was already sent; correct it in RIS"
                else:
                    fields.update(phase="new", note="", ris_tries=0, ris_at=None)
                    store.log("case_reopened", accession=accession, doctor=row["review_doctor"])
                    stats["reopened"] += 1
            if fields and fields != {"note": case["note"]}:
                store.update_case(accession, **fields)
        for case in store.cases(phases=OPEN_PHASES):
            if case["accession"] not in todo:
                row = store.sheet_row(case["accession"])
                reason = f"sheet status is now {row['status']!r}" if row else "row is not in the sheet (or is duplicated)"
                store.update_case(case["accession"], phase="closed", note=f"Closed: {reason}")
                store.log("case_closed", accession=case["accession"], doctor=case["doctor"], reason=reason)
                stats["closed"] += 1
    store.set_meta("last_sheet_sync", datetime.now(timezone.utc).isoformat())
    return stats


def _due(case: dict[str, Any], settings: Settings, now: datetime) -> bool:
    if case["phase"] == "new":
        return True
    last = datetime.fromisoformat(case["ris_at"]) if case["ris_at"] else None
    if case["phase"] in ("ris_error", "not_reported"):
        return last is None or now - last >= timedelta(hours=settings.ris_retry_hours)
    if case["phase"] == "ready":  # look again daily: the doctor may have staged or edited it in RIS
        sent = workflow.case_sent(case.get("review") or {})
        return not sent and (last is None or now - last >= timedelta(hours=settings.ris_refresh_hours))
    return False


def apply_ris(store: Store, case: dict[str, Any], state: dict[str, Any], catalog) -> str:
    """Store one fetch result; returns the new phase."""
    stamp = datetime.now(timezone.utc).isoformat()
    accession = case["accession"]
    base = {"ris_at": stamp, "ris_tries": case["ris_tries"] + 1}
    if state.get("error"):
        store.update_case(accession, phase="ris_error" if case["phase"] != "ready" else "ready",
                          note=state["error"], **base)
        return "ris_error"
    if state.get("not_reported"):
        store.update_case(accession, phase="not_reported", ris=state, review=None,
                          note=f"RIS status is {state.get('status')!r}; no report to stage yet", **base)
        return "not_reported"
    exam = state.pop("exam")
    source = dict(case["source"])
    state["differs_from_sheet"] = _normalized_report(exam) != _normalized_report(source.get("sheet_report_txt", ""))
    report_changed = case["phase"] == "ready" and _normalized_report(exam) != _normalized_report(source["report_txt"])
    source.update(report_txt=exam, study_date=ris.ris_date(state.get("study_date")) or source["study_date"])
    phase = "staged" if state["staging_blocks"] else "ready"
    updated = {**case, "phase": phase, "source": source, "ris": state}
    review = case.get("review")
    if phase == "staged" or not review or not has_human_work(review):
        review = build_review(updated, catalog)
    elif report_changed:
        review = {**review, "approval": {"state": "pending", "approved_text_sha256": "", "approved_at": ""}}
        review["proposal"] = {**review["proposal"], "warnings": [
            *review["proposal"].get("warnings", []),
            "The RIS report text changed after this staging was prepared; check it again."]}
    store.update_case(accession, phase=phase, source=source, ris=state, review=review, note="", **base)
    if phase != case["phase"]:
        store.log("ris_fetched", accession=accession, doctor=case["doctor"], phase=phase,
                  blocks=state["staging_blocks"], differs_from_sheet=state["differs_from_sheet"])
    return phase


def fetch_ris(store: Store, settings: Settings, catalog, *, limit: int | None = None, api=None,
              doctor: str | None = None) -> dict[str, int]:
    """Read-only RIS fetch for the cases that are due (of one doctor, if given), oldest attempt first."""
    now = datetime.now(timezone.utc)
    due = [case for case in store.cases(phases=OPEN_PHASES, doctor=doctor) if _due(case, settings, now)]
    due.sort(key=lambda case: (case["phase"] != "new", case["ris_at"] or ""))
    due = due[: settings.ris_fetch_per_cycle if limit is None else limit]
    stats: dict[str, int] = {"due": len(due)}
    if not due:
        return stats
    own_api = api is None
    api = api or WebRISApi(settings.webris_url)
    if own_api:
        api.login(None, None)
    try:
        for case in due:
            try:
                state = ris.fetch_report(api, case["accession"], case["chart_no"])
            except Exception as exc:  # one bad study must not stop the cycle
                state = {"error": f"{type(exc).__name__}: {exc}"[:300]}
            phase = apply_ris(store, case, state, catalog)
            stats[phase] = stats.get(phase, 0) + 1
    finally:
        if own_api:
            api.logout()
    store.set_meta("last_ris_fetch", datetime.now(timezone.utc).isoformat())
    return stats


def run_cycle(store: Store, settings: Settings, sheet: SheetClient, catalog) -> dict[str, Any]:
    ledger = load_sent_ledger(settings.ledger_path)
    result: dict[str, Any] = {"sheet": sync_sheet(store, sheet.read_rows(), ledger=ledger)}
    result["ris"] = fetch_ris(store, settings, catalog)
    return result


def set_entry(store: Store, accession: str, entry: dict[str, Any], *, by: str, catalog) -> bool:
    """Save an LLM proposal; rebuild the review case unless a person already worked on it."""
    with store.tx():
        case = store.get_case(accession)
        if case is None or case["phase"] != "ready":
            return False
        fields: dict[str, Any] = {"entry": entry, "entry_by": by, "entry_at": datetime.now(timezone.utc).isoformat()}
        rebuilt = not has_human_work(case.get("review"))
        if rebuilt:
            fields["review"] = build_review({**case, "entry": entry}, catalog)
        store.update_case(accession, **fields)
        store.log("proposal_saved", accession=accession, doctor=case["doctor"], by=by, shown=rebuilt,
                  skip=bool(entry.get("skip")))
    return rebuilt
