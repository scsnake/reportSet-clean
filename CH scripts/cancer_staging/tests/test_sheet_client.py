from __future__ import annotations

import pytest

import sheet_client


HEADERS = [
    "申請單號",
    "院內病歷號碼",
    "攝影名稱",
    "攝影日期",
    "報告日期",
    "覆審醫師",
    "報告內容",
    "病理報告",
    "臨床診斷",
    "癌別",
    "完成",
    "備註",
]


class FakeWorksheet:
    def __init__(self, status: str = "待修正"):
        self.rows = [
            HEADERS,
            [
                "99900000001",
                "1234567",
                "WHOLE ABDOMEN CT",
                "2026/07/15",
                "2026/07/21",
                "陳醫師",
                "report",
                "pathology",
                "",
                "",
                status,
                "",
            ],
        ]
        self.updates = []

    def row_values(self, row: int):
        return list(self.rows[row - 1])

    def get_all_values(self):
        return [list(row) for row in self.rows]

    def batch_update(self, updates):
        self.updates.extend(updates)


def test_list_todo_understands_review_doctor(monkeypatch) -> None:
    ws = FakeWorksheet()
    monkeypatch.setattr(sheet_client, "_open_worksheet", lambda: ws)
    rows = sheet_client.list_todo("陳醫師")
    assert rows[0]["accession"] == "99900000001"
    assert rows[0]["study_date"] == "2026/07/15"


def test_status_compare_and_swap(monkeypatch) -> None:
    ws = FakeWorksheet()
    monkeypatch.setattr(sheet_client, "_open_worksheet", lambda: ws)
    result = sheet_client.write_row(2, status="完成")
    assert result["status"] == "set='完成' (was='待修正')"
    assert ws.updates == [{"range": "K2", "values": [["完成"]]}]


def test_status_compare_and_swap_rejects_unexpected_state(monkeypatch) -> None:
    ws = FakeWorksheet(status="已備註")
    monkeypatch.setattr(sheet_client, "_open_worksheet", lambda: ws)
    with pytest.raises(RuntimeError, match="compare-and-swap failed"):
        sheet_client.write_row(2, status="完成")


def test_write_study_result_matches_both_accession_and_chart(monkeypatch) -> None:
    ws = FakeWorksheet()
    monkeypatch.setattr(sheet_client, "_open_worksheet", lambda: ws)
    result = sheet_client.write_study_result(
        accession="99900000001",
        chart_no="0001234567",
        cancer_type="Colorectum",
    )
    assert result["row_idx"] == "2"
    assert {update["range"] for update in ws.updates} == {"J2", "K2"}


def test_write_study_result_rejects_identity_mismatch(monkeypatch) -> None:
    ws = FakeWorksheet()
    monkeypatch.setattr(sheet_client, "_open_worksheet", lambda: ws)
    with pytest.raises(RuntimeError, match="found 0"):
        sheet_client.write_study_result(
            accession="99900000001",
            chart_no="7654321",
            cancer_type="Colorectum",
        )
