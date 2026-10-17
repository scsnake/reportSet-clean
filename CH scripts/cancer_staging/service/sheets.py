"""Google Sheets access with the service account: read the tab, write one study's result.

The write finds the row through a temporary row label (developer metadata), not through a
row number. Tested on a copy of the sheet (2026-10-07): the label follows its row when
other rows are inserted, deleted or moved and in a range sort. It does not follow a filter
sort or a cut-and-paste of the cells, so the row is checked through the label before the
write and read back after it.
"""

from __future__ import annotations

import re
import secrets
from typing import Any

import workflow

API = "https://sheets.googleapis.com/v4/spreadsheets"
READ_SCOPE = "https://www.googleapis.com/auth/spreadsheets.readonly"
WRITE_SCOPE = "https://www.googleapis.com/auth/spreadsheets"
LABEL_KEY = "cs_write"
ACCESSION = re.compile(r"\d{10,11}")


class SheetError(RuntimeError):
    pass


class SheetWriteRefused(SheetError):
    """The row is not in the expected state; nothing was written."""


def normalize_rows(values: list[list[str]]) -> list[dict[str, Any]]:
    """Sheet values (with header row) to pipeline row dicts; adds input_row and duplicate."""
    if not values:
        return []
    header = [str(cell).strip() for cell in values[0]]
    rows: list[dict[str, Any]] = []
    seen: dict[str, int] = {}
    for number, cells in enumerate(values[1:], start=2):
        raw = {name: str(cells[index]) if index < len(cells) else "" for index, name in enumerate(header) if name}
        row: dict[str, Any] = {key: workflow._first(raw, aliases) for key, aliases in workflow.HEADER_ALIASES.items()}
        if not row["accession"]:
            continue
        row["input_row"] = number
        seen[row["accession"]] = seen.get(row["accession"], 0) + 1
        rows.append(row)
    for row in rows:
        row["duplicate"] = seen[row["accession"]] > 1
    return rows


def valid_identity(row: dict[str, Any]) -> bool:
    return bool(ACCESSION.fullmatch(row["accession"])) and row["chart_no"].isdigit()


class SheetClient:
    def __init__(self, sheet_id: str, gid: int, key_path, *, session_factory=None) -> None:
        self.sheet_id, self.gid, self.key_path = sheet_id, int(gid), key_path
        self._session_factory = session_factory or self._authorized
        self._sessions: dict[str, Any] = {}
        self._tab = ""

    def _authorized(self, scope: str):
        from google.auth.transport.requests import AuthorizedSession
        from google.oauth2.service_account import Credentials

        return AuthorizedSession(Credentials.from_service_account_file(str(self.key_path), scopes=[scope]))

    def _call(self, scope: str, method: str, path: str, **kwargs: Any) -> dict[str, Any]:
        if scope not in self._sessions:
            self._sessions[scope] = self._session_factory(scope)
        response = self._sessions[scope].request(method, f"{API}/{self.sheet_id}{path}", timeout=120, **kwargs)
        if response.status_code >= 400:
            raise SheetError(f"Sheets API HTTP {response.status_code}: {response.text[:300]}")
        return response.json()

    @property
    def tab(self) -> str:
        if not self._tab:
            meta = self._call(READ_SCOPE, "GET", "", params={"fields": "sheets.properties(sheetId,title)"})
            titles = [s["properties"]["title"] for s in meta["sheets"] if s["properties"]["sheetId"] == self.gid]
            if len(titles) != 1:
                raise SheetError(f"Tab gid {self.gid} not found")
            self._tab = titles[0]
        return self._tab

    def read_values(self) -> list[list[str]]:
        return self._call(READ_SCOPE, "GET", f"/values/{self.tab}!A1:P").get("values", [])

    def read_rows(self) -> list[dict[str, Any]]:
        return normalize_rows(self.read_values())

    # ---- write one result ------------------------------------------------------------------
    def _filter(self, label: str) -> dict[str, Any]:
        return {"developerMetadataLookup": {"metadataKey": LABEL_KEY, "metadataValue": label}}

    def _row_by_label(self, label: str) -> tuple[int, list[str]] | None:
        data = self._call(WRITE_SCOPE, "POST", "/values:batchGetByDataFilter",
                          json={"dataFilters": [self._filter(label)], "majorDimension": "ROWS"})
        ranges = data.get("valueRanges", [])
        if len(ranges) != 1:
            return None
        value_range = ranges[0]["valueRange"]
        number = int(re.search(r"!(?:[A-Z]+)?(\d+)", value_range["range"]).group(1))
        return number, [str(cell) for cell in (value_range.get("values") or [[]])[0]]

    def write_result(
        self, *, accession: str, chart_no: str, cancer_type: str, status: str,
        expected_status: str = "待修正",
    ) -> dict[str, Any]:
        """Set 癌別 and 完成 of exactly one study row; raises without writing if anything is off."""
        if cancer_type not in workflow.SHEET_CANCER_TYPES or status not in workflow.SHEET_STATUSES:
            raise SheetWriteRefused(f"Not sheet dropdown values: {cancer_type!r}, {status!r}")
        values = self.read_values()
        header = [str(cell).strip() for cell in values[0]]
        col = {name: workflow_index(header, aliases) for name, aliases in (
            ("accession", workflow.HEADER_ALIASES["accession"]), ("chart", workflow.HEADER_ALIASES["chart_no"]),
            ("cancer", workflow.HEADER_ALIASES["cancer_type_existing"]), ("status", workflow.HEADER_ALIASES["status"]))}

        def cell(row: list[str], name: str) -> str:
            return str(row[col[name]]).strip() if col[name] < len(row) else ""

        def same_study(row: list[str]) -> bool:
            return cell(row, "accession") == str(accession) and cell(row, "chart").lstrip("0") == str(chart_no).lstrip("0")

        matches = [number for number, row in enumerate(values[1:], start=2) if same_study(row)]
        if len(matches) != 1:
            raise SheetWriteRefused(f"Expected one sheet row for {accession}; found {len(matches)}")
        label = secrets.token_hex(8)
        self._call(WRITE_SCOPE, "POST", ":batchUpdate", json={"requests": [{"createDeveloperMetadata": {
            "developerMetadata": {
                "metadataKey": LABEL_KEY, "metadataValue": label, "visibility": "PROJECT",
                "location": {"dimensionRange": {"sheetId": self.gid, "dimension": "ROWS",
                                                "startIndex": matches[0] - 1, "endIndex": matches[0]}}}}}]})
        try:
            found = self._row_by_label(label)
            if not found or not same_study(found[1]):
                raise SheetWriteRefused(f"The sheet rows moved while {accession} was being located; try again")
            old = {"cancer_type": cell(found[1], "cancer"), "status": cell(found[1], "status")}
            if (old["cancer_type"], old["status"]) == (cancer_type, status):
                return {"row": found[0], "old": old, "written": False}
            if old["status"] != expected_status:
                raise SheetWriteRefused(
                    f"Sheet status of {accession} is {old['status']!r}, not {expected_status!r}; not changed")
            if old["cancer_type"] not in ("", cancer_type):
                raise SheetWriteRefused(
                    f"Sheet 癌別 of {accession} is already {old['cancer_type']!r}; not changed to {cancer_type!r}")
            cells: list[Any] = [None] * (max(col["cancer"], col["status"]) + 1)
            cells[col["cancer"]], cells[col["status"]] = cancer_type, status
            self._write_by_label(label, cells)
            after = self._row_by_label(label)
            if not after or not same_study(after[1]):
                # A filter sort or cut-and-paste hit the window between check and write.
                wrong = after[1] if after else []
                previous = next((row for row in values[1:] if cell(row, "accession") == cell(wrong, "accession")), None)
                restored = False
                if after and previous is not None and cell(wrong, "accession"):
                    cells[col["cancer"]], cells[col["status"]] = cell(previous, "cancer"), cell(previous, "status")
                    self._write_by_label(label, cells)
                    restored = True
                raise SheetError(
                    f"Sheet rows were sorted during the write for {accession}. The write went to row "
                    f"{after[0] if after else '?'} (accession {cell(wrong, 'accession') or '?'}); "
                    f"{'its old values were restored' if restored else 'CHECK THAT ROW BY HAND'}.")
            if (cell(after[1], "cancer"), cell(after[1], "status")) != (cancer_type, status):
                raise SheetError(f"Read-back of {accession} does not show the written values")
            return {"row": after[0], "old": old, "written": True}
        finally:
            self._call(WRITE_SCOPE, "POST", ":batchUpdate", json={"requests": [{"deleteDeveloperMetadata": {
                "dataFilter": self._filter(label)}}]})

    def _write_by_label(self, label: str, cells: list[Any]) -> None:
        self._call(WRITE_SCOPE, "POST", "/values:batchUpdateByDataFilter", json={
            "valueInputOption": "RAW",
            "data": [{"dataFilter": self._filter(label), "majorDimension": "ROWS", "values": [cells]}]})


def workflow_index(header: list[str], aliases: tuple[str, ...]) -> int:
    for name in aliases:
        if name in header:
            return header.index(name)
    raise SheetError(f"Sheet header has no column {aliases[0]}")
