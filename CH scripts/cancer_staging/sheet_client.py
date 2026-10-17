"""Google Sheet client: OAuth desktop flow + gspread read/write.

Uses the InstalledAppFlow (opens browser once for consent). Token is cached at
``%LOCALAPPDATA%\\cancer_staging\\token.json``. Refresh happens transparently.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Iterable

import gspread
from dotenv import load_dotenv
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ["https://www.googleapis.com/auth/spreadsheets"]

# Column headers used in the sheet. Whitespace is stripped on match.
DOCTOR_COL_CANDIDATES = ("覆審醫師", "報告醫師", "主治醫師", "Doctor", "醫師")
STATUS_COL_LETTER = "K"  # per user spec
CANCER_TYPE_COL_CANDIDATES = ("癌別", "Cancer", "Cancer Type")
ACCESSION_COL_CANDIDATES = ("申請單號", "開單序號", "Accession", "Acc No")
CHART_NO_COL_CANDIDATES = ("院內病歷號碼", "病歷號", "Chart No", "ChartNo")
STUDY_NAME_COL_CANDIDATES = ("攝影名稱", "檢查項目", "Study Name")
STUDY_DATE_COL_CANDIDATES = ("攝影日期", "檢查日期", "Study Date")
REPORT_DATE_COL_CANDIDATES = ("報告日期", "Report Date")
REPORT_COL_CANDIDATES = ("報告內容",)
PATHO_COL_CANDIDATES = ("病理報告",)
DX_COL_CANDIDATES = ("臨床診斷",)
NOTES_COL_CANDIDATES = ("備註",)

TOKEN_PATH = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "cancer_staging" / "token.json"


def _load_env() -> None:
    load_dotenv(Path(__file__).parent / ".env")


def _authorize() -> Credentials:
    _load_env()
    client_json = os.environ.get("OAUTH_CLIENT_JSON")
    if not client_json:
        raise RuntimeError("OAUTH_CLIENT_JSON not set in .env")
    client_path = Path(os.path.expandvars(client_json))
    if not client_path.exists():
        raise FileNotFoundError(
            f"OAuth client JSON missing at {client_path}. Create Desktop OAuth "
            "credentials in Google Cloud Console and download the JSON there."
        )

    creds: Credentials | None = None
    if TOKEN_PATH.exists():
        try:
            creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), SCOPES)
        except (ValueError, json.JSONDecodeError):
            creds = None

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(str(client_path), SCOPES)
            creds = flow.run_local_server(port=0, prompt="consent")
        TOKEN_PATH.parent.mkdir(parents=True, exist_ok=True)
        TOKEN_PATH.write_text(creds.to_json(), encoding="utf-8")

    return creds


def _open_worksheet() -> gspread.Worksheet:
    _load_env()
    sheet_id = os.environ["SHEET_ID"]
    gid = int(os.environ.get("SHEET_GID", "0"))
    gc = gspread.authorize(_authorize())
    sh = gc.open_by_key(sheet_id)
    for ws in sh.worksheets():
        if ws.id == gid:
            return ws
    raise RuntimeError(f"No worksheet with gid={gid} in sheet {sheet_id}")


def _col_letter(idx1: int) -> str:
    """1 -> A, 27 -> AA."""
    s = ""
    n = idx1
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(ord("A") + r) + s
    return s


def _find_col(headers: list[str], candidates: Iterable[str]) -> int | None:
    stripped = [h.strip() for h in headers]
    for cand in candidates:
        if cand in stripped:
            return stripped.index(cand) + 1  # 1-indexed
    return None


class SheetContext:
    """Cached column indexes for a worksheet."""

    def __init__(self, ws: gspread.Worksheet):
        self.ws = ws
        self.headers = ws.row_values(1)
        self.col_doctor = _find_col(self.headers, DOCTOR_COL_CANDIDATES)
        self.col_status = ord(STATUS_COL_LETTER) - ord("A") + 1  # K = 11
        self.col_cancer_type = _find_col(self.headers, CANCER_TYPE_COL_CANDIDATES)
        self.col_accession = _find_col(self.headers, ACCESSION_COL_CANDIDATES)
        self.col_chart_no = _find_col(self.headers, CHART_NO_COL_CANDIDATES)
        self.col_study_name = _find_col(self.headers, STUDY_NAME_COL_CANDIDATES)
        self.col_study_date = _find_col(self.headers, STUDY_DATE_COL_CANDIDATES)
        self.col_report_date = _find_col(self.headers, REPORT_DATE_COL_CANDIDATES)
        self.col_report = _find_col(self.headers, REPORT_COL_CANDIDATES)
        self.col_patho = _find_col(self.headers, PATHO_COL_CANDIDATES)
        self.col_dx = _find_col(self.headers, DX_COL_CANDIDATES)
        self.col_notes = _find_col(self.headers, NOTES_COL_CANDIDATES)
        missing = [
            name
            for name, val in (
                ("doctor", self.col_doctor),
                ("cancer_type(癌別)", self.col_cancer_type),
                ("accession(申請單號)", self.col_accession),
                ("chart_no(院內病歷號碼)", self.col_chart_no),
                ("study_name(攝影名稱)", self.col_study_name),
                ("study_date(攝影日期)", self.col_study_date),
                ("report_date(報告日期)", self.col_report_date),
                ("report(報告內容)", self.col_report),
                ("patho(病理報告)", self.col_patho),
                ("dx(臨床診斷)", self.col_dx),
                ("notes(備註)", self.col_notes),
            )
            if val is None
        ]
        if missing:
            raise RuntimeError(
                f"Sheet header row missing columns: {missing}. Headers seen: {self.headers}"
            )

    def cell(self, row: list[str], col_idx1: int) -> str:
        if col_idx1 is None or col_idx1 - 1 >= len(row):
            return ""
        return row[col_idx1 - 1].strip()


def list_todo(doctor: str | None = None) -> list[dict[str, Any]]:
    """Rows where 報告醫師 == doctor AND column K == TODO_STATUS."""
    _load_env()
    doctor = doctor or os.environ.get("DOCTOR_NAME", "陳醫師")
    todo_status = os.environ.get("TODO_STATUS", "待修正")
    ws = _open_worksheet()
    ctx = SheetContext(ws)
    all_rows = ws.get_all_values()

    out: list[dict[str, Any]] = []
    for i, row in enumerate(all_rows[1:], start=2):  # sheet row is 1-indexed; skip header
        if doctor not in ctx.cell(row, ctx.col_doctor):
            continue
        if ctx.cell(row, ctx.col_status) != todo_status:
            continue
        out.append(
            {
                "row_idx": i,
                "accession": ctx.cell(row, ctx.col_accession),
                "chart_no": ctx.cell(row, ctx.col_chart_no),
                "study_name": ctx.cell(row, ctx.col_study_name),
                "study_date": ctx.cell(row, ctx.col_study_date),
                "report_date": ctx.cell(row, ctx.col_report_date),
                "review_doctor": ctx.cell(row, ctx.col_doctor),
                "status": ctx.cell(row, ctx.col_status),
                "cancer_type_existing": ctx.cell(row, ctx.col_cancer_type),
                "report_txt": ctx.cell(row, ctx.col_report),
                "patho_txt": ctx.cell(row, ctx.col_patho),
                "dx_txt": ctx.cell(row, ctx.col_dx),
                "notes_txt": ctx.cell(row, ctx.col_notes),
            }
        )
    return out


def write_row(
    row_idx: int,
    cancer_type: str | None = None,
    status: str | None = None,
    notes: str | None = None,
    force: bool = False,
    expected_status: str | None = None,
) -> dict[str, str]:
    """PATCH-style write. Only fills empty cells unless force=True.

    Returns a dict describing which cells were actually written.
    """
    ws = _open_worksheet()
    return _write_row_on_worksheet(
        ws,
        row_idx=row_idx,
        cancer_type=cancer_type,
        status=status,
        notes=notes,
        force=force,
        expected_status=expected_status,
    )


def _write_row_on_worksheet(
    ws: gspread.Worksheet,
    *,
    row_idx: int,
    cancer_type: str | None = None,
    status: str | None = None,
    notes: str | None = None,
    force: bool = False,
    expected_status: str | None = None,
) -> dict[str, str]:
    ctx = SheetContext(ws)
    row_values = ws.row_values(row_idx)

    updates: list[dict[str, Any]] = []
    result: dict[str, str] = {}

    def _stage(col_idx1: int, label: str, new_val: str) -> None:
        existing = ctx.cell(row_values, col_idx1)
        if existing == new_val:
            result[label] = f"unchanged (already='{existing}')"
            return
        if existing and not force:
            result[label] = f"skipped (existing='{existing}')"
            return
        updates.append(
            {
                "range": f"{_col_letter(col_idx1)}{row_idx}",
                "values": [[new_val]],
            }
        )
        result[label] = f"set='{new_val}'"

    if cancer_type is not None:
        _stage(ctx.col_cancer_type, "cancer_type", cancer_type)
    if status is not None:
        existing_status = ctx.cell(row_values, ctx.col_status)
        expected = expected_status or os.environ.get("TODO_STATUS", "待修正")
        if existing_status == status:
            result["status"] = f"unchanged (already='{status}')"
        elif force or existing_status == expected:
            updates.append(
                {
                    "range": f"{_col_letter(ctx.col_status)}{row_idx}",
                    "values": [[status]],
                }
            )
            result["status"] = f"set='{status}' (was='{existing_status}')"
        else:
            raise RuntimeError(
                f"Status compare-and-swap failed at row {row_idx}: "
                f"expected '{expected}', found '{existing_status}'"
            )
    if notes is not None:
        _stage(ctx.col_notes, "notes", notes)

    if updates:
        ws.batch_update(updates)
    return result


def write_study_result(
    *,
    accession: str,
    chart_no: str,
    cancer_type: str,
    status: str = "完成",
    expected_status: str = "待修正",
) -> dict[str, str]:
    """Update exactly one Sheet study, with identity and status safeguards."""
    ws = _open_worksheet()
    ctx = SheetContext(ws)
    rows = ws.get_all_values()
    matches: list[int] = []
    for row_idx, row in enumerate(rows[1:], start=2):
        same_accession = ctx.cell(row, ctx.col_accession) == str(accession)
        same_chart = ctx.cell(row, ctx.col_chart_no).lstrip("0") == str(
            chart_no
        ).lstrip("0")
        if same_accession and same_chart:
            matches.append(row_idx)
    if len(matches) != 1:
        raise RuntimeError(
            f"Expected one Sheet row for accession/chart identity; found {len(matches)}"
        )
    result = _write_row_on_worksheet(
        ws,
        row_idx=matches[0],
        cancer_type=cancer_type,
        status=status,
        expected_status=expected_status,
    )
    return {"row_idx": str(matches[0]), **result}


if __name__ == "__main__":
    from rich import print as rprint

    rows = list_todo()
    rprint(f"[bold]{len(rows)}[/bold] 待修正 rows for the configured doctor:")
    for r in rows:
        rprint(r)
