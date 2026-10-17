"""Local-only browser UI for exact-text cancer-staging review and approval."""

from __future__ import annotations

import argparse
import hmac
import json
import os
import secrets
import tempfile
import threading
import webbrowser
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, unquote, urlsplit

import workflow
from tnm_catalog import load_catalog, text_sha256

STATIC_DIR = Path(__file__).with_name("review_ui_static")
MAX_REQUEST_BYTES = 2 * 1024 * 1024


class ApiError(Exception):
    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


def _summary(review: dict[str, Any]) -> dict[str, int | str]:
    cases = review.get("cases", [])
    approved = workflow.approved_cases(review)
    not_applicable = sum(workflow.is_not_applicable(case) for case in cases)
    return {
        "total": len(cases),
        "approved": len(approved),
        "not_applicable": not_applicable,
        "pending": len(cases) - len(approved) - not_applicable,
        "batch_sha256": workflow.batch_sha256(review),
        "sent": [case["source"]["accession"] for case in cases if workflow.case_sent(case)],
    }


class ReviewStore:
    """Reload on every action and atomically replace the review JSON on mutation."""

    def __init__(self, path: Path) -> None:
        self.path = path.resolve()
        self._lock = threading.RLock()
        self._load()

    def _load(self) -> dict[str, Any]:
        if not self.path.is_file():
            raise FileNotFoundError(f"Review file not found: {self.path}")
        review = workflow.load_json(self.path)
        if not isinstance(review, dict) or not isinstance(review.get("cases"), list):
            raise ValueError("Review file does not contain a cases list")
        return review

    def _save(self, review: dict[str, Any]) -> None:
        temp_path: Path | None = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                newline="\n",
                prefix=f".{self.path.name}.",
                suffix=".tmp",
                dir=self.path.parent,
                delete=False,
            ) as handle:
                json.dump(review, handle, ensure_ascii=False, indent=2)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
                temp_path = Path(handle.name)
            os.replace(temp_path, self.path)
            temp_path = None
        finally:
            if temp_path is not None:
                temp_path.unlink(missing_ok=True)

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return self._load()

    def update_text(
        self, accession: str, *, staging_text: str, expected_sha256: str
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        with self._lock:
            review = self._load()
            try:
                case = workflow.update_case_staging_text(
                    review,
                    accession,
                    staging_text=staging_text,
                    expected_sha256=expected_sha256,
                )
            except ValueError as exc:
                if "SHA mismatch" in str(exc):
                    raise ApiError(HTTPStatus.CONFLICT, str(exc)) from exc
                raise ApiError(HTTPStatus.BAD_REQUEST, str(exc)) from exc
            self._save(review)
            return case, _summary(review)

    def approve(
        self, accession: str, *, expected_sha256: str
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        with self._lock:
            review = self._load()
            try:
                case = workflow.approve_case(review, accession, expected_sha256)
            except ValueError as exc:
                status = (
                    HTTPStatus.CONFLICT
                    if "SHA mismatch" in str(exc)
                    else HTTPStatus.BAD_REQUEST
                )
                raise ApiError(status, str(exc)) from exc
            self._save(review)
            return case, _summary(review)

    def render(self, accession: str, entry: dict[str, Any], catalog) -> dict[str, Any]:
        review = self.snapshot()
        try:
            case = workflow.find_case(review, accession)
            return workflow.render_form(case["source"], catalog, entry)
        except ValueError as exc:
            raise ApiError(HTTPStatus.BAD_REQUEST, str(exc)) from exc

    def set_form(
        self,
        accession: str,
        catalog,
        *,
        entry: dict[str, Any],
        expected_sha256: str,
        staging_text: str | None,
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        with self._lock:
            review = self._load()
            try:
                case = workflow.set_case_form(
                    review,
                    catalog,
                    accession,
                    entry=entry,
                    expected_sha256=expected_sha256,
                    staging_text=staging_text,
                )
            except ValueError as exc:
                status = HTTPStatus.CONFLICT if "SHA mismatch" in str(exc) else HTTPStatus.BAD_REQUEST
                raise ApiError(status, str(exc)) from exc
            self._save(review)
            return case, _summary(review)

    def set_sheet(
        self, accession: str, *, cancer_type: str | None, status: str | None
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        with self._lock:
            review = self._load()
            try:
                case = workflow.set_case_sheet(
                    review, accession, cancer_type=cancer_type, status=status
                )
            except ValueError as exc:
                raise ApiError(HTTPStatus.BAD_REQUEST, str(exc)) from exc
            self._save(review)
            return case, _summary(review)

    def mark_not_applicable(self, accession: str) -> tuple[dict[str, Any], dict[str, Any]]:
        with self._lock:
            review = self._load()
            try:
                case = workflow.mark_not_applicable(review, accession)
            except ValueError as exc:
                raise ApiError(HTTPStatus.BAD_REQUEST, str(exc)) from exc
            self._save(review)
            return case, _summary(review)

    def revoke(self, accession: str) -> tuple[dict[str, Any], dict[str, Any]]:
        with self._lock:
            review = self._load()
            try:
                case = workflow.revoke_case_approval(review, accession)
            except ValueError as exc:
                raise ApiError(HTTPStatus.NOT_FOUND, str(exc)) from exc
            self._save(review)
            return case, _summary(review)


class ReviewServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(
        self,
        server_address: tuple[str, int],
        store: ReviewStore,
        csrf_token: str | None = None,
        catalog=None,
    ) -> None:
        self.review_store = store
        self.csrf_token = csrf_token or secrets.token_urlsafe(32)
        self._catalog = catalog
        super().__init__(server_address, ReviewHandler)

    @property
    def catalog(self):
        """The cached cancer-tnm catalog, loaded on first use."""
        if self._catalog is None:
            self._catalog = load_catalog()
        return self._catalog


class ReviewHandler(BaseHTTPRequestHandler):
    server: ReviewServer

    def log_message(self, _format: str, *args: Any) -> None:
        # URLs contain accessions, so the review server deliberately has no access log.
        return

    def _security_headers(self) -> None:
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self'; style-src 'self'; "
            "img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'",
        )
        self.send_header("Cache-Control", "no-store")

    def _send_bytes(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self._security_headers()
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json(self, status: int, payload: Any) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self._send_bytes(status, body, "application/json; charset=utf-8")

    def _error(self, status: int, message: str) -> None:
        self._json(status, {"error": message})

    def _read_json(self) -> dict[str, Any]:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as exc:
            raise ApiError(HTTPStatus.BAD_REQUEST, "Invalid Content-Length") from exc
        if length <= 0 or length > MAX_REQUEST_BYTES:
            raise ApiError(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "Invalid request size")
        # Consume the body before any rejection: closing with unread bytes makes
        # Windows reset the socket, and the client never sees the error status.
        raw = self.rfile.read(length)
        content_type = self.headers.get("Content-Type", "").split(";", 1)[0].strip()
        if content_type != "application/json":
            raise ApiError(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, "Expected application/json")
        token = self.headers.get("X-Review-Token", "")
        if not token or not hmac.compare_digest(token, self.server.csrf_token):
            raise ApiError(HTTPStatus.FORBIDDEN, "Invalid review token")
        origin = self.headers.get("Origin")
        if origin and urlsplit(origin).netloc != self.headers.get("Host", ""):
            raise ApiError(HTTPStatus.FORBIDDEN, "Cross-origin mutation rejected")
        try:
            payload = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ApiError(HTTPStatus.BAD_REQUEST, "Invalid JSON body") from exc
        if not isinstance(payload, dict):
            raise ApiError(HTTPStatus.BAD_REQUEST, "JSON body must be an object")
        return payload

    def _accession_action(self) -> tuple[str, str]:
        parts = urlsplit(self.path).path.strip("/").split("/")
        if len(parts) != 4 or parts[:2] != ["api", "cases"]:
            raise ApiError(HTTPStatus.NOT_FOUND, "Unknown endpoint")
        accession = unquote(parts[2]).strip()
        if not accession:
            raise ApiError(HTTPStatus.BAD_REQUEST, "Missing accession")
        return accession, parts[3]

    def do_GET(self) -> None:  # noqa: N802
        path = urlsplit(self.path).path
        if path == "/healthz":
            self._json(HTTPStatus.OK, {"ok": True})
            return
        if path == "/api/review":
            review = self.server.review_store.snapshot()
            self._json(
                HTTPStatus.OK,
                {
                    "review": review,
                    "summary": _summary(review),
                    "review_token": self.server.csrf_token,
                },
            )
            return
        if path == "/api/catalog":
            self._json(HTTPStatus.OK, workflow.catalog_choices(self.server.catalog))
            return
        if path == "/api/pasteback":
            query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
            mode = query.get("unfinished", ["empty"])[0]
            # Absent = default selection (finished rows); present but blank = none.
            selected = (
                [item for item in query["selected"][0].split(",") if item]
                if "selected" in query
                else None
            )
            self._json(
                HTTPStatus.OK,
                workflow.sheet_pasteback(
                    self.server.review_store.snapshot(), unfinished=mode, selected=selected
                ),
            )
            return
        if path == "/favicon.ico":
            self._send_bytes(HTTPStatus.NO_CONTENT, b"", "image/x-icon")
            return
        static_files = {
            "/": ("index.html", "text/html; charset=utf-8"),
            "/review_ui.js": ("review_ui.js", "text/javascript; charset=utf-8"),
            "/review_ui.css": ("review_ui.css", "text/css; charset=utf-8"),
        }
        item = static_files.get(path)
        if item is None:
            self._error(HTTPStatus.NOT_FOUND, "Not found")
            return
        filename, content_type = item
        try:
            body = (STATIC_DIR / filename).read_bytes()
        except FileNotFoundError:
            self._error(HTTPStatus.INTERNAL_SERVER_ERROR, "UI asset is missing")
            return
        self._send_bytes(HTTPStatus.OK, body, content_type)

    def do_POST(self) -> None:  # noqa: N802
        try:
            if urlsplit(self.path).path == "/api/render":
                # Preview only: renders the template from form values, saves nothing.
                payload = self._read_json()
                if not isinstance(payload.get("entry"), dict):
                    raise ApiError(HTTPStatus.BAD_REQUEST, "entry must be an object")
                self._json(
                    HTTPStatus.OK,
                    self.server.review_store.render(
                        str(payload.get("accession", "")), payload["entry"], self.server.catalog
                    ),
                )
                return
            accession, action = self._accession_action()
            payload = self._read_json()
            expected_sha = str(payload.get("expected_sha256", ""))
            if action == "text":
                staging_text = payload.get("staging_text")
                if not isinstance(staging_text, str):
                    raise ApiError(HTTPStatus.BAD_REQUEST, "staging_text must be a string")
                case, summary = self.server.review_store.update_text(
                    accession,
                    staging_text=staging_text,
                    expected_sha256=expected_sha,
                )
            elif action == "approve":
                case, summary = self.server.review_store.approve(
                    accession, expected_sha256=expected_sha
                )
            elif action == "revoke":  # also undoes N/A
                case, summary = self.server.review_store.revoke(accession)
            elif action == "not_applicable":
                case, summary = self.server.review_store.mark_not_applicable(accession)
            elif action == "form":
                staging_text = payload.get("staging_text")
                if not isinstance(payload.get("entry"), dict) or not (
                    staging_text is None or isinstance(staging_text, str)
                ):
                    raise ApiError(HTTPStatus.BAD_REQUEST, "entry must be an object and staging_text a string")
                case, summary = self.server.review_store.set_form(
                    accession,
                    self.server.catalog,
                    entry=payload["entry"],
                    expected_sha256=expected_sha,
                    staging_text=staging_text,
                )
            elif action == "sheet":
                choices = {key: payload.get(key) for key in ("cancer_type", "status")}
                if any(value is not None and not isinstance(value, str) for value in choices.values()):
                    raise ApiError(HTTPStatus.BAD_REQUEST, "cancer_type and status must be strings")
                case, summary = self.server.review_store.set_sheet(accession, **choices)
            else:
                raise ApiError(HTTPStatus.NOT_FOUND, "Unknown action")
            self._json(HTTPStatus.OK, {"case": case, "summary": summary})
        except ApiError as exc:
            self._error(exc.status, exc.message)
        except ValueError as exc:
            self._error(HTTPStatus.NOT_FOUND, str(exc))


def build_server(
    review_path: Path,
    *,
    host: str = "127.0.0.1",
    port: int = 8765,
    csrf_token: str | None = None,
    catalog=None,
) -> ReviewServer:
    if host not in {"127.0.0.1", "localhost", "::1"}:
        raise ValueError("Review UI must bind to a loopback address")
    return ReviewServer((host, port), ReviewStore(review_path), csrf_token=csrf_token, catalog=catalog)


def run_review_ui(
    review_path: Path,
    *,
    host: str = "127.0.0.1",
    port: int = 8765,
    open_browser: bool = True,
) -> None:
    server = build_server(review_path, host=host, port=port)
    actual_port = server.server_address[1]
    url = f"http://{host}:{actual_port}/"
    print(f"Cancer staging review UI: {url}")
    print(f"Review file: {review_path.resolve()}")
    print("Approval only; this UI does not send reports to RIS. Press Ctrl+C to stop.")
    if open_browser:
        threading.Timer(0.4, webbrowser.open, args=(url,)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Local cancer-staging review UI")
    parser.add_argument("--review", default="review.json")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--no-browser", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    review_path = Path(args.review)
    if not review_path.is_absolute():
        review_path = Path(__file__).parent / review_path
    run_review_ui(
        review_path,
        host=args.host,
        port=args.port,
        open_browser=not args.no_browser,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
