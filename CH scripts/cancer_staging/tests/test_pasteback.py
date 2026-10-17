from __future__ import annotations

import pytest

import workflow


def _case(accession: str, row: int, catalog_id: str = "Prostate", *, sent: bool = False, notes: str = "") -> dict:
    case = {
        "source": {
            "accession": accession,
            "input_row": row,
            "study_name": "CT",
            "cancer_type_existing": "",
            "status": "待修正",
            "notes_txt": notes,
        },
        "proposal": {"catalog_id": catalog_id},
        "approval": {"state": "approved"},
        "execution": {},
    }
    if sent:
        case["execution"] = {"mode": "execute", "status": "ok", "response": {"submitted": True}}
    return case


def test_sent_rows_finish_and_unsent_rows_keep_sheet_values() -> None:
    review = {
        "cases": [
            _case("A1", 1, sent=True),
            _case("A2", 2, "Colorectum"),
            _case("A3", 3, "", notes="癌委會:結腸癌", sent=True),
        ]
    }
    block = workflow.sheet_pasteback(review, unfinished="keep")
    assert block["tsv"] == "攝護腺癌\t完成\n\t待修正\n大腸直腸癌\t完成"
    assert block["rows"][1]["suggested_cancer_type"] == "大腸直腸癌"
    assert block["rows"][2]["cancer_source"] == "committee note"
    assert block["gaps"] == []


def test_preview_run_is_not_sent_and_existing_sheet_value_wins() -> None:
    case = _case("A1", 1)
    case["execution"] = {"mode": "preview", "status": "ok", "response": {"submitted": False}}
    case["source"]["cancer_type_existing"] = "其他癌"
    assert workflow.sheet_pasteback({"cases": [case]}, unfinished="keep")["tsv"] == ""  # nothing finished
    assert workflow.sheet_pasteback({"cases": [case]}, unfinished="keep", selected=["A1"])["tsv"] == "其他癌\t待修正"
    case["execution"] = {"mode": "execute", "status": "ok", "response": {"submitted": True}}
    assert workflow.sheet_pasteback({"cases": [case]}, unfinished="keep")["tsv"] == "其他癌\t完成"


def test_source_rows_keep_filtered_rows_in_place() -> None:
    review = {
        "cases": [_case("A1", 1, sent=True), _case("A3", 3, sent=True)],
        "source_rows": [
            {"input_row": 1, "accession": "A1", "cancer_type_existing": "", "status": "待修正"},
            {"input_row": 2, "accession": "B2", "cancer_type_existing": "肺癌", "status": "完成"},
            {"input_row": 3, "accession": "A3", "cancer_type_existing": "", "status": "待修正"},
        ],
    }
    block = workflow.sheet_pasteback(review, unfinished="keep")
    assert block["tsv"] == "攝護腺癌\t完成\n肺癌\t完成\n攝護腺癌\t完成"
    assert not block["rows"][1]["in_review"]


def test_gap_in_imported_rows_is_reported() -> None:
    block = workflow.sheet_pasteback({"cases": [_case("A1", 1), _case("A3", 3)]})
    assert block["gaps"] == [2]


def test_reviewer_choice_overrides_and_clears() -> None:
    review = {"cases": [_case("A1", 1)]}
    workflow.set_case_sheet(review, "A1", cancer_type="其他癌", status="已備註")
    row = workflow.sheet_pasteback(review)["rows"][0]
    assert (row["cancer_type"], row["status"], row["status_source"]) == ("其他癌", "已備註", "chosen")
    assert workflow.review_has_work(review)
    workflow.set_case_sheet(review, "A1", cancer_type="", status="")
    assert "sheet" not in review["cases"][0]
    with pytest.raises(ValueError, match="not a sheet dropdown option"):
        workflow.set_case_sheet(review, "A1", cancer_type=None, status="done")


def test_import_collects_all_rows_for_the_sidecar() -> None:
    text = (
        "99900000001\t1\tCT\t2026/01/01\t2026/01/02\tDr\trep\tpath\t\t\t待修正\t\n"
        "99900000001\t2\tCT\t2026/01/01\t2026/01/02\tDr\trep\tpath\t\t肺癌\t完成\t\n"
    )
    all_rows: list[dict] = []
    rows = workflow.import_tsv_text(text, all_rows=all_rows)
    assert [row["accession"] for row in rows] == ["99900000001"]
    assert workflow.minimal_source_rows(all_rows)[1] == {
        "input_row": 2,
        "accession": "99900000001",
        "cancer_type_existing": "肺癌",
        "status": "完成",
    }


def test_empty_mode_spans_finished_rows_and_blanks_the_rest() -> None:
    review = {
        "cases": [
            _case("A1", 1),
            _case("A2", 2, sent=True),
            _case("A3", 3),
            _case("A4", 4, sent=True),
            _case("A5", 5),
        ]
    }
    block = workflow.sheet_pasteback(review)
    assert block["unfinished"] == "empty"
    assert block["block_start_row"] == 2 and block["block_length"] == 3
    assert block["tsv"] == "攝護腺癌\t完成\n\t\n攝護腺癌\t完成"
    workflow.set_case_sheet(review, "A5", cancer_type=None, status="已備註")
    assert workflow.sheet_pasteback(review)["tsv"].endswith("\t\n攝護腺癌\t完成\n\t已備註")
    assert workflow.sheet_pasteback({"cases": [_case("A1", 1)]})["tsv"] == ""


def test_only_selected_rows_are_copied() -> None:
    # Rows 1-6 sent except row 4.
    review = {
        "cases": [
            _case(f"A{n}", n, sent=n != 4) for n in range(1, 7)
        ]
    }
    # Select 1,2,3,5,6: five lines, no line at all for row 4.
    block = workflow.sheet_pasteback(review, selected=["A1", "A2", "A3", "A5", "A6"])
    assert block["tsv"].split("\n") == ["攝護腺癌\t完成"] * 5
    assert block["skipped_rows"] == [4] and block["block_length"] == 5
    # Select 1..6 with row 4 not sent: six lines, the 4th blank.
    block = workflow.sheet_pasteback(review, selected=[f"A{n}" for n in range(1, 7)])
    assert block["tsv"].split("\n") == ["攝護腺癌\t完成"] * 3 + ["\t"] + ["攝護腺癌\t完成"] * 2
    assert block["skipped_rows"] == []
    kept = workflow.sheet_pasteback(review, unfinished="keep", selected=["A3", "A4"])
    assert kept["tsv"] == "攝護腺癌\t完成\n\t待修正"
    assert workflow.sheet_pasteback(review, selected=[])["tsv"] == ""
    assert workflow.sheet_pasteback(review)["block_length"] == 6  # default: span of finished rows


def test_sent_case_is_locked() -> None:
    review = {"cases": [_case("A1", 1, sent=True)]}
    review["cases"][0]["proposal"].update({"staging_text": "x", "text_sha256": workflow.text_sha256("x")})
    with pytest.raises(ValueError, match="locked"):
        workflow.update_case_staging_text(review, "A1", staging_text="y", expected_sha256=workflow.text_sha256("x"))
    with pytest.raises(ValueError, match="locked"):
        workflow.revoke_case_approval(review, "A1")
    workflow.set_case_sheet(review, "A1", cancer_type="其他癌", status=None)  # paste-back choice still allowed


def test_not_applicable_is_never_sent_and_pastes_back_as_other_cancer_noted() -> None:
    review = {"cases": [_case("A1", 1, sent=True), _case("A2", 2)]}
    case = review["cases"][1]
    case["proposal"].update({"staging_text": "x", "text_sha256": workflow.text_sha256("x")})
    case["approval"] = {"state": "approved", "approved_text_sha256": workflow.text_sha256("x")}
    assert [c["source"]["accession"] for c in workflow.sendable_cases(review)] == ["A2"]

    workflow.mark_not_applicable(review, "A2")
    assert workflow.sendable_cases(review) == []
    assert workflow.review_has_work(review)
    row = workflow.sheet_pasteback(review)["rows"][1]
    assert row["not_applicable"] and row["finished"] and row["selected"]
    assert (row["cancer_type"], row["status"], row["status_source"]) == ("其他癌", "已備註", "N/A")
    assert workflow.sheet_pasteback(review)["tsv"] == "攝護腺癌\t完成\n其他癌\t已備註"
    with pytest.raises(ValueError, match="undo N/A"):
        workflow.update_case_staging_text(review, "A2", staging_text="y", expected_sha256=workflow.text_sha256("x"))
    with pytest.raises(ValueError, match="undo N/A"):
        workflow.approve_case(review, "A2", workflow.text_sha256("x"))

    workflow.revoke_case_approval(review, "A2")  # undo N/A
    assert review["cases"][1]["approval"]["state"] == "pending"
    with pytest.raises(ValueError, match="locked"):
        workflow.mark_not_applicable(review, "A1")  # sent studies cannot become N/A
