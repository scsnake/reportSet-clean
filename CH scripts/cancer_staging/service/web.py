"""Web page of the service: the existing review UI, one list per doctor, plus send and sheet actions.

The doctor's name and a random device key live in browser cookies. Review and approval need
no login; the page is reachable only through the reverse tunnel on the office PC (hospital LAN).
To send to RIS, the browser signs in with the doctor's own RIS account, which WebRIS checks.
"""

from __future__ import annotations

import hashlib
import json
import secrets
import threading
from http import HTTPStatus
from http.cookies import SimpleCookie
from http.server import ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import quote, unquote, urlsplit

import workflow
from review_ui import STATIC_DIR, ApiError, ReviewHandler, ReviewStore

from .core import App, Refused
from .store import OPEN_PHASES, Conflict

SERVICE_STATIC = Path(__file__).with_name("static")
COOKIE_AGE = 5 * 365 * 24 * 3600
INJECT = b'<link rel="stylesheet" href="/service.css">\n  <script src="/service.js" defer></script>\n</body>'


class DoctorStore(ReviewStore):
    """ReviewStore over the database: the review of one doctor."""

    def __init__(self, app: App, doctor: str, device: str) -> None:
        self.app, self.doctor, self.device = app, doctor, device
        self._lock = app.lock(doctor)

    def _load(self) -> dict[str, Any]:
        return self.app.store.load_review(self.doctor)

    def _save(self, review: dict[str, Any]) -> None:
        try:
            self.app.store.save_review(self.doctor, review, device=self.device)
        except Conflict as exc:
            raise ApiError(HTTPStatus.CONFLICT, str(exc)) from exc


class ServiceServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], app: App, csrf_token: str | None = None) -> None:
        if address[0] not in {"127.0.0.1", "localhost", "::1"}:
            raise ValueError("The service binds to loopback only; the SSH tunnel publishes it")
        self.app = app
        self.csrf_token = csrf_token or secrets.token_urlsafe(32)
        self.catalog = app.catalog
        self.request_state = threading.local()
        super().__init__(address, ServiceHandler)

    @property
    def review_store(self) -> DoctorStore:
        state = self.request_state
        return DoctorStore(self.app, getattr(state, "doctor", ""), getattr(state, "device", ""))


class ServiceHandler(ReviewHandler):
    server: ServiceServer

    # ---- identity from cookies ---------------------------------------------------------------
    def _identify(self) -> None:
        cookies = SimpleCookie(self.headers.get("Cookie", ""))
        doctor = unquote(cookies["cs_doctor"].value) if "cs_doctor" in cookies else ""
        self.doctor = doctor if doctor in self.server.app.store.sheet_counts() else ""
        self.device = cookies["cs_device"].value if "cs_device" in cookies else ""
        self.server.request_state.doctor, self.server.request_state.device = self.doctor, self.device

    def _cookie(self, name: str, value: str, *, http_only: bool) -> str:
        return f"{name}={value}; Max-Age={COOKIE_AGE}; Path=/; SameSite=Strict" + ("; HttpOnly" if http_only else "")

    def _send_with_cookies(self, status: int, body: bytes, content_type: str, cookies: list[str]) -> None:
        self.send_response(status)
        self._security_headers()
        for cookie in cookies:
            self.send_header("Set-Cookie", cookie)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    # ---- state for the page --------------------------------------------------------------------
    def _state(self) -> dict[str, Any]:
        app, doctor = self.server.app, self.doctor
        store = app.store
        counts = store.sheet_counts()
        open_cases = store.cases(phases=OPEN_PHASES, doctor=doctor) if doctor else []
        review = store.load_review(doctor)
        waiting = [{"accession": case["accession"], "phase": case["phase"], "note": case["note"],
                    "row": case["source"].get("input_row")}
                   for case in open_cases if case["phase"] not in ("ready", "staged")]
        send_list = [{"accession": case["source"]["accession"], "study_name": case["source"].get("study_name", ""),
                      "study_date": case["source"].get("study_date", ""),
                      "staging_text": case["proposal"].get("staging_text", ""),
                      "approved_text_sha256": case["approval"]["approved_text_sha256"]}
                     for case in workflow.sendable_cases(review)]
        # Changes made by the service (new rows, RIS fetch, proposals), not the doctor's own edits.
        version = hashlib.sha256(json.dumps(
            [(case["accession"], case["phase"], case["entry_at"]) for case in open_cases]).encode()).hexdigest()[:16]
        state: dict[str, Any] = {
            "doctor": doctor,
            "doctors": [{"name": name, "todo": by_status.get("待修正", 0)} for name, by_status in sorted(counts.items())],
            "review_token": self.server.csrf_token,
            "sendable": len(send_list),
            "send_list": send_list,
            "no_proposal": sum(1 for case in review["cases"]
                               if case["proposal"].get("skip_reason", "").startswith("No proposal yet")),
            "waiting": waiting,
            "sheet_write": app.settings.sheet_write,
            "sheet_pending": len(app.sheet_pending(doctor)) if doctor else 0,
            "credentials_url": app.settings.credentials_url,
            "signin_hours": app.settings.signin_hours,
            "last_sheet_sync": store.get_meta("last_sheet_sync"),
            "sending": bool(app.sending.get(doctor)),
            "last_send": app.last_send.get(doctor),
            "version": version,
        }
        if doctor:
            state.update(app.readiness(doctor, self.device))
        return state

    # ---- routes ----------------------------------------------------------------------------------
    def do_GET(self) -> None:  # noqa: N802
        self._identify()
        path = urlsplit(self.path).path
        if path == "/":
            body = (STATIC_DIR / "index.html").read_bytes().replace(b"</body>", INJECT)
            cookies = [] if self.device else [self._cookie("cs_device", secrets.token_urlsafe(32), http_only=True)]
            self._send_with_cookies(HTTPStatus.OK, body, "text/html; charset=utf-8", cookies)
        elif path in ("/service.js", "/service.css"):
            kind = "text/javascript" if path.endswith(".js") else "text/css"
            self._send_bytes(HTTPStatus.OK, (SERVICE_STATIC / path[1:]).read_bytes(), f"{kind}; charset=utf-8")
        elif path == "/api/service/state":
            self._json(HTTPStatus.OK, self._state())
        else:
            super().do_GET()

    def do_POST(self) -> None:  # noqa: N802
        self._identify()
        path = urlsplit(self.path).path
        if not path.startswith("/api/service/"):
            super().do_POST()
            app = self.server.app
            if path.endswith("/approve") and self.doctor:
                session = app.signed_in(self.device, self.doctor)
                if session and session["auto_send"] and workflow.sendable_cases(app.store.load_review(self.doctor)):
                    app.send_async(self.doctor, self.device)
            return
        try:
            payload = self._read_json()
            action = path.rsplit("/", 1)[-1]
            app = self.server.app
            if action == "doctor":
                name = str(payload.get("doctor", ""))
                if name and name not in app.store.sheet_counts():
                    raise ApiError(HTTPStatus.BAD_REQUEST, "Unknown doctor name")
                body = json.dumps({"doctor": name}, ensure_ascii=False).encode("utf-8")
                self._send_with_cookies(HTTPStatus.OK, body, "application/json; charset=utf-8",
                                        [self._cookie("cs_doctor", quote(name), http_only=False)])
                return
            if not self.doctor:
                raise ApiError(HTTPStatus.BAD_REQUEST, "Choose your name first")
            if action == "signin":
                result = app.sign_in(self.doctor, self.device, str(payload.get("userid", "")),
                                     str(payload.get("password", "")))
            elif action == "signout":
                result = app.sign_out(self.doctor, self.device)
            elif action == "auto_send":
                if not app.signed_in(self.device, self.doctor):
                    raise Refused("Sign in with your RIS account first.")
                app.store.set_auto_send(self.device, self.doctor, bool(payload.get("enabled")))
                app.store.log("auto_send", doctor=self.doctor, device=self.device, enabled=bool(payload.get("enabled")))
                result = {"auto_send": bool(payload.get("enabled"))}
            elif action == "send":
                # Only the studies shown in the confirmation dialog, with the text shown there.
                confirmed = payload.get("cases")
                if not isinstance(confirmed, dict) or not all(isinstance(v, str) for v in confirmed.values()):
                    raise ApiError(HTTPStatus.BAD_REQUEST, "Confirm the studies to send first")
                result = app.send(self.doctor, self.device, {str(k): v for k, v in confirmed.items()})
            elif action == "sheet_write":
                result = app.write_sheet(self.doctor, self.device)
            else:
                raise ApiError(HTTPStatus.NOT_FOUND, "Unknown action")
            self._json(HTTPStatus.OK, result)
        except ApiError as exc:
            self._error(exc.status, exc.message)
        except Refused as exc:
            self._error(HTTPStatus.FORBIDDEN, str(exc))
        except Exception as exc:  # shown to the doctor; details are in the event log
            self.server.app.store.log("action_error", doctor=self.doctor, device=self.device,
                                      path=path, error=f"{type(exc).__name__}: {exc}"[:300])
            self._error(HTTPStatus.INTERNAL_SERVER_ERROR, f"{type(exc).__name__}: {exc}"[:300])


def build_server(app: App, *, host: str | None = None, port: int | None = None,
                 csrf_token: str | None = None) -> ServiceServer:
    return ServiceServer((host or app.settings.host, app.settings.port if port is None else port), app,
                         csrf_token=csrf_token)
