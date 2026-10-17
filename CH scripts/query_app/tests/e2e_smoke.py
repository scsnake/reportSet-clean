"""Browser smoke test for the local HIS workflow UI.

Every patient-bearing route is mocked with fixture rows, so no chart reaches HIS.
"""

import json
import os
import re
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright


BASE_URL = os.environ.get("QUERY_APP_URL", "http://127.0.0.1:8000")
SCREENSHOT = Path(tempfile.gettempdir()) / "query_app_ui_smoke.png"
SCRIPT_FIXTURE = "<script>window.fixtureExecuted=true</script>"
# The reader-facing page must not show database object names.
SCHEMA_WORDS = ("PTEXAM", "LABX", "LABP1", "IPTPROGRESS", "IPDINDEX", "REF_NO", "ACCESS_NO", "APPLY_NO", "XRAY.", "EXAM.")


def json_route(payload: dict):
    return lambda route: route.fulfill(
        status=200, content_type="application/json", body=json.dumps(payload)
    )


def search_payload(workflow: str) -> dict:
    lab_items = [
        {
            "unique_seq": "1", "code": "GLU", "lab_name": "Glucose",
            "result_description": "190", "unit": "mg/dL", "lower_limit": 70,
            "upper_limit": 100, "result_condition": "H", "result_remark": "Fixture remark",
        },
        {
            "unique_seq": "2", "code": "CRE", "lab_name": "Creatinine",
            "result_description": "1.0", "unit": "mg/dL", "lower_limit": 0,
            "upper_limit": 0, "result_condition": "N", "result_remark": None,
        },
        {
            "unique_seq": "3", "code": "", "lab_code": "MCULT1", "lab_name": "Fixture culture",
            "result_description": "Fixture growth", "unit": None, "lower_limit": None,
            "upper_limit": None, "result_condition": None, "result_remark": None,
            "source_schema": "LAM", "microbiology": True,
            "organisms": [{
                "germ_seq": "1", "germ_code": "GERM01", "germ_name": "Fixture organism",
                "colony_count": ">100000", "unit": "CFU/mL", "alert": "Fixture resistance alert",
                "drugs": [
                    {"code": "AB1", "name": "Fixture antibiotic A", "result": "R", "value": ">=16"},
                    {"code": "AB2", "name": "Fixture antibiotic B", "result": "S", "value": "<=1"},
                ],
            }],
        },
    ]
    rows = {
        "radiology": [
            {
                "source_schema": "XRAY", "category": "radiology", "state": "reported",
                "hospital_id": "000", "apply_no": "TEST-A1",
                "order_date": "1150828", "order_time": "0900", "exam_date": "1150828",
                "report_date": "1150829", "modality": "CR", "exam_type": "1",
                "exam_type_name": "General", "exam_name": f"Chest PA {SCRIPT_FIXTURE}",
                "ref_no": "TEST-REF", "access_no": "TEST-REF", "status": "5",
            },
            {
                "source_schema": "EXAM", "category": "other", "state": "examined",
                "hospital_id": "000", "apply_no": "TEST-A9",
                "order_date": "1150820", "order_time": "1000", "exam_date": "1150821",
                "report_date": "0000000", "modality": "ES", "exam_type": "ENDO",
                "exam_type_name": "Upper endoscopy", "exam_name": "Fixture endoscopy",
                "ref_no": "TESTENDO1", "access_no": "", "status": "3",
            },
            {
                "source_schema": "XRAY", "category": "radiology", "state": "cancelled",
                "hospital_id": "000", "apply_no": "TEST-A7",
                "order_date": "1150815", "order_time": "1100", "sch_date": "1150816",
                "exam_date": "0000000", "report_date": "0000000", "modality": "MR", "exam_type": "4",
                "exam_type_name": "MRI", "exam_name": "Fixture cancelled MRI", "status": "1", "dc_flag": "Y",
            },
        ],
        "laboratory": [dict(item, lab_no="TEST-L1", order_date="1150828") for item in lab_items],
        "pathology": [
            {
                "hospital_id": "000", "lab_no": "TESTPATH01", "pathology_no": "TESTPNO1",
                "pathology_type": "S", "kind": "Surgical pathology", "state": "confirmed",
                "order_date": "1150810", "receive_date": "1150810", "report_date": "1150812",
                "confirmed_date": "1150813", "specimen_code": "ZA", "specimen_name": "Tissue",
                "diagnosis_description": "Fixture order diagnosis", "result_codes": [],
                "sections": [
                    {"part": "01", "type": "1", "label": "Pathologic diagnosis", "content": "Fixture pathology diagnosis"},
                    {"part": "01", "type": "2", "label": "Gross description", "content": "Fixture gross text"},
                ],
            },
            {
                "hospital_id": "000", "lab_no": "TESTPATH02", "pathology_no": "",
                "pathology_type": "S", "kind": "Surgical pathology", "state": "received",
                "order_date": "1150826", "receive_date": "1150826", "report_date": "0000000",
                "confirmed_date": "0000000", "specimen_name": "Tissue", "sections": [], "result_codes": [],
            },
        ],
        "exam_accession": [
            {
                "source_schema": "XRAY", "category": "radiology", "state": "reported",
                "hospital_id": "000", "apply_no": "TEST-A2",
                "order_date": "1150828", "sch_date": "1150829", "exam_date": "1150829",
                "report_date": "1150830", "modality": "CT", "exam_type": "3",
                "exam_name": "Fixture CT", "status": "5",
                "reference_no": "TEST-REF-2", "access_no": "TEST-ACC-2",
            },
            {
                "source_schema": "XRAY", "category": "radiology", "state": "cancelled",
                "hospital_id": "000", "apply_no": "TEST-A7",
                "order_date": "1150815", "sch_date": "1150816", "sch_time": "0900", "exam_date": "0000000",
                "report_date": "0000000", "modality": "MR", "exam_type": "4",
                "exam_name": "Fixture cancelled MRI", "status": "1", "dc_flag": "Y",
            },
        ],
        "admission": [
            {
                "chart_no": "0000012345", "admit_no": "TESTADMIT1", "cut_no": "00",
                "status": "1", "admit_date": "1150820", "admit_time": "101500",
                "discharge_date": "0000000", "discharge_time": "000000",
            }
        ],
        "inpatient_note": [
            {
                "chart_no": "0000012345", "admit_no": "TESTADMIT1",
                "note_date": "1150821", "note_time": "0930", "note_type": "P",
                "note_type_name": "Progress Note(POMR)", "remark": "Fixture remark",
                "status": "S", "div_no": "TESTDIV", "signed_date": 1150821, "state": "signed",
            },
            {
                "chart_no": "0000012345", "admit_no": "TESTADMIT1",
                "note_date": "1150822", "note_time": "0815", "note_type": "P",
                "note_type_name": "Progress Note(POMR)", "remark": "Fixture unsigned remark",
                "status": "C", "div_no": "TESTDIV", "signed_date": 0, "state": "unsigned",
            },
        ],
        "opd_note": [
            {
                "source_schema": "OPD", "hospital_id": "000", "chart_no": "0000012345",
                "clinic_date": "1150827", "duplicate_no": "2", "clinic_flag": "E", "clinic_apn": "N",
                "clinic_no": "ER01", "div_no": "TER1", "div_name": "Fixture emergency", "doctor_no": "TESTDR09",
                "doctor_name": "Fixture ER doctor", "kind": "emergency", "has_note": True,
                "sections": [
                    {"so_type": "S", "sub_type": "CC", "group": "Subjective", "label": "Chief complaint", "content": "Fixture chief complaint", "clerk_id": "TESTCK01"},
                    {"so_type": "O", "sub_type": "VS", "group": "Objective", "label": "Vital signs", "content": "Fixture vital signs", "clerk_id": "TESTCK01"},
                ],
            },
            {
                "source_schema": "OHISE08", "hospital_id": "000", "chart_no": "0000012345",
                "clinic_date": "1150805", "duplicate_no": "1", "clinic_flag": "O", "clinic_apn": "1",
                "clinic_no": "C101", "div_no": "TCV1", "div_name": "Fixture cardiology", "div_english_name": "Cardiology",
                "doctor_no": "TESTDR08", "doctor_name": "Fixture clinic doctor", "kind": "outpatient", "has_note": True,
                "sections": [
                    {"so_type": "S", "sub_type": "", "group": "Subjective", "label": "Subjective", "content": "Fixture outpatient subjective", "clerk_id": "TESTCK02"},
                    {"so_type": "O", "sub_type": "", "group": "Objective", "label": "Objective", "content": "Fixture outpatient objective", "clerk_id": "TESTCK02"},
                    {"so_type": "C", "sub_type": "", "group": None, "label": None, "content": "Fixture other part", "clerk_id": "TESTCK02"},
                ],
            },
            {
                "source_schema": "OHISE07", "hospital_id": "000", "chart_no": "0000012345",
                "clinic_date": "1150702", "duplicate_no": "1", "clinic_flag": "O", "div_no": "TCV1",
                "div_name": "Fixture cardiology", "doctor_no": "TESTDR08", "doctor_name": "Fixture clinic doctor",
                "kind": "outpatient", "has_note": False, "sections": [],
            },
        ],
        "discharge_summary": [
            {
                "document_no": "TESTDOC001", "chart_no": "0000012345", "admit_no": "TESTADMIT0",
                "cut_no": "00", "admit_date": "1150611", "discharge_date": "1150620",
                "created_date": "1150621", "confirmed_date": "1150622", "status": "2",
                "complete_flag": "C", "div_no": "TDIV", "vs_no": "TESTVS01", "state": "confirmed",
            }
        ],
        "operation_note": [
            {
                "hospital_id": "000", "chart_no": "0000012345", "or_date": "1150612",
                "or_duplicate_no": "1", "status": "3", "or_source": "I", "admit_no": "TESTADMIT0",
                "div_no": "TDIV", "vs_no": "TESTVS01", "or_room_no": "07", "or_in_date": "1150612",
                "or_in_time": 830, "or_out_time": 1015, "cancel_date": None, "state": "noted",
                "diagnoses": [{"code": "K35.80", "name": "Fixture appendicitis"}],
                "procedures": [
                    {"or_seq": "0", "or_code": "ORCODE1", "or_name": "Fixture appendectomy", "or_doctor_no": "TESTDR01"},
                    {"or_seq": "1", "or_code": "ORCODE2", "or_name": "Fixture drainage", "or_doctor_no": "TESTDR01"},
                ],
                "note": "Fixture operative note\n<Fixture heading> second line",
            },
            {
                "hospital_id": "000", "chart_no": "0000012345", "or_date": "1150601",
                "or_duplicate_no": "1", "status": "2", "or_source": "I", "or_in_date": None,
                "cancel_date": "1150601", "cancel_reason": "01", "state": "cancelled",
                "diagnoses": [], "procedures": [], "note": "",
            },
        ],
    }[workflow]
    payload = {
        "workflow": workflow,
        "chart_no": "0000012345",
        "start_date": "2026-01-01",
        "end_date": "2026-08-28",
        "count": len(rows),
        "results": rows,
        "evidence": "confirmed",
        "caveat": "FIXTURE CAVEAT naming LAB.LABX1",
    }
    if workflow == "laboratory":
        payload["groups"] = [{
            "date": "2026-08-28", "date_roc": "1150828", "order_count": 1,
            "item_count": 2, "specimens": [{
                "specimen_code": "09", "specimen_name": "Blood", "order_count": 1,
                "item_count": 2, "categories": [{
                    "category_code": "C", "category_name": "Chemistry",
                    "order_count": 1, "item_count": 2,
                    "orders": [{
                        "hospital_id": "000", "lab_no": "TEST-L1", "lab_order_time": "0915",
                        "report_date": "1150828", "report_time": "1030", "lab_status": "R",
                        "items": lab_items,
                    }],
                }],
            }, {
                "specimen_code": "23", "specimen_name": "Urine-random", "order_count": 1,
                "item_count": 0, "categories": [],
            }],
        }]
    return payload


EXAM_DETAIL = {
    "items": [{
        "unique_seq": "01", "exam_code": "CODE-X1", "exam_name": "Fixture chest radiograph",
        "side_code": "", "position": "", "order_comment": "Fixture order comment",
    }],
    "remarks": [],
    "reports": [],
    "report_sections": [
        {"caption": "報告內容", "type": "C", "content": "Fixture report"},
        {"caption": "IMPRESSION", "type": "S", "content": "Fixture impression"},
    ],
    "clinical": {
        "diagnoses": [{"code": "J18.9", "text": "Fixture pneumonia"}],
        "notes": [{"type": "S", "text": "Fixture indication"}],
    },
}


def visible_text(locator) -> str:
    return locator.inner_text()


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 1440, "height": 1000})
    console_errors = []
    page.on("console", lambda message: console_errors.append(message.text) if message.type == "error" else None)
    page.goto(BASE_URL)
    page.wait_for_load_state("networkidle")

    assert page.title() == "HIS Workflow Query"
    assert page.locator(".workflow").count() == 9
    assert page.locator(".workflow.available").count() == 9
    assert page.locator(".workflow.selected").count() == 3
    assert page.locator(".workflow.deferred").count() == 0
    assert page.locator("#workflow-hint").inner_text() == "Select one or more."
    assert "configured" in page.locator("#health").inner_text().lower()
    landing = visible_text(page.locator("body"))
    for word in SCHEMA_WORDS:
        assert word not in landing, f"schema word on the landing page: {word}"

    page.route(
        re.compile(r".*/api/patient/[^/?]+(?:\?.*)?$"),
        json_route({
            "chart_no": "0000012345", "found": True,
            "patient": {
                "chart_no": "0000012345", "pt_name": "Fixture Patient", "sex": "F",
                "birth_date": "+0650102", "birth_date_iso": "1976-01-02",
                "blood_type": "O", "last_opd_date": "1150801",
                "last_admit_date": "1150820", "last_discharge_date": "0000000",
            },
        }),
    )
    page.route(
        re.compile(r".*/api/accession/[^/?]+(?:\?.*)?$"),
        json_route({
            "accession_no": "TESTACC3", "count": 1,
            "results": [dict(
                EXAM_DETAIL,
                source_schema="EXAM", category="other", state="reported", hospital_id="000",
                apply_no="TEST-A3", chart_no="0000012345", order_date="1150828", modality="MR",
                exam_type="TEST", status="5", exam_date="1150829", report_date="1150830",
                access_no="TESTACC3", reference_no="TESTACC3", exam_name="Fixture accession exam",
                report_sections=[{"caption": "FINDING", "type": "F", "content": "Fixture accession report"}],
            )],
        }),
    )
    page.route(
        re.compile(r".*/api/inpatient-notes/[^/]+/[^/]+/[^/?]+(?:\?.*)?$"),
        json_route({
            "admit_no": "TESTADMIT1", "note_date": "1150821", "note_time": "0930",
            "sections": [
                {"problem_no": "001", "section_type": "S", "section_label": "Subjective", "content": "Fixture subjective"},
                {"problem_no": "001", "section_type": "O", "section_label": "Objective", "content": "Fixture objective"},
                {"problem_no": "000", "section_type": "T", "section_label": None, "content": "Fixture free text"},
            ],
        }),
    )

    page.route(
        re.compile(r".*/api/discharge-summaries/[^/?]+(?:\?.*)?$"),
        json_route({
            "document_no": "TESTDOC001",
            "sections": [
                {"section_no": "A", "section_name": "Fixture admission diagnosis", "content": "Fixture diagnosis text"},
                {"section_no": "G", "section_name": "Fixture hospital course", "content": "Fixture course text"},
                {"section_no": "Z", "section_name": None, "content": "Fixture unnamed text"},
            ],
        }),
    )

    def route_search(route):
        workflow = route.request.url.split("/api/search/", 1)[1].split("?", 1)[0]
        route.fulfill(status=200, content_type="application/json", body=json.dumps(search_payload(workflow)))

    page.route(re.compile(r".*/api/search/[^?]+(?:\?.*)?$"), route_search)
    page.route(re.compile(r".*/api/radiology/[^/]+/[^/]+/[^/?]+(?:\?.*)?$"), json_route(EXAM_DETAIL))
    page.route(
        re.compile(r".*/api/exam-accessions/[^/]+/[^/?]+(?:\?.*)?$"),
        json_route({
            "hospital_id": "000",
            "apply_no": "TEST-A2",
            "items": [{
                "unique_seq": "1", "exam_code": "CT-TEST", "exam_type": "3",
                "exam_short_name": "Fixture CT", "exam_full_name": "Fixture computed tomography",
                "position": "CHEST", "price_code": "PRICE-1",
            }],
        }),
    )

    page.locator("[data-workflow='exam_accession']").click()
    page.locator("[data-workflow='admission']").click()
    page.locator("[data-workflow='inpatient_note']").click()
    page.locator("[data-workflow='discharge_summary']").click()
    page.locator("[data-workflow='operation_note']").click()
    page.locator("[data-workflow='opd_note']").click()
    assert page.locator(".workflow.selected").count() == 9

    page.locator("#chart-no").fill("12345")
    page.locator("#start-date").fill("2026-01-01")
    page.locator("#end-date").fill("2026-08-28")
    page.get_by_role("button", name="Search selected").click()
    page.locator("[data-result='radiology']").wait_for()
    assert page.locator(".result-section").count() == 9
    # Results follow the order of the cards, whatever order the responses arrive in.
    assert [node.get_attribute("data-result") for node in page.locator(".result-section").all()] == [
        "radiology", "exam_accession", "laboratory", "pathology", "opd_note", "admission", "inpatient_note",
        "discharge_summary", "operation_note",
    ]

    banner = page.locator("#patient-banner")
    banner.locator("strong", has_text="Fixture Patient").wait_for()
    banner_text = banner.inner_text()
    assert "1976-01-02" in banner_text
    assert "2026-08-20" in banner_text
    assert "0000000" not in banner_text

    results_text = visible_text(page.locator("#results"))
    for word in SCHEMA_WORDS + ("FIXTURE CAVEAT",):
        assert word not in results_text, f"schema word in the results: {word}"

    # Exams: the kind filter, reader-facing columns, and administrative fields behind the info button.
    exams = page.locator("[data-result='radiology']")
    assert exams.locator("tr.data-row").count() == 3
    assert exams.locator("#exam-kind-filter option").all_inner_texts() == [
        "All exams (3)", "Radiology only (2)", "Other exams only (1)"
    ]
    exams.locator("#exam-kind-filter").select_option("radiology")
    assert exams.locator("tr.data-row").count() == 2
    assert "Chest PA" in visible_text(exams)
    # A cancelled order: the mark, the order date in place of the old schedule, the flag behind the info button.
    cancelled_exam = exams.locator("tr.data-row", has_text="Fixture cancelled MRI")
    cancelled_text = visible_text(cancelled_exam)
    assert "Cancelled" in cancelled_text and "Ordered 2026-08-15" in cancelled_text
    assert "2026-08-16" not in cancelled_text
    assert "Order stop flag" not in visible_text(exams)
    cancelled_exam.locator(".info-button").click()
    assert "Order stop flag Y" in " ".join(visible_text(exams).split())
    cancelled_exam.locator(".info-button").click()
    assert "Fixture endoscopy" not in visible_text(exams)
    exams.locator("#exam-kind-filter").select_option("other")
    assert exams.locator("tr.data-row").count() == 1
    assert "Report pending" in visible_text(exams)
    exams.locator("#exam-kind-filter").select_option("all")
    assert exams.locator("tr.data-row").count() == 3
    assert "TEST-REF" not in visible_text(exams)
    exams.locator("tr.data-row").first.locator(".info-button").click()
    assert "TEST-REF" in visible_text(exams)
    assert "TEST-A1" in visible_text(exams)
    assert page.get_by_text(SCRIPT_FIXTURE).count() == 1
    assert page.evaluate("() => window.fixtureExecuted") is None

    exams.locator("tr.data-row").first.get_by_role("button", name="Open").click()
    page.locator("#detail-dialog[open]").wait_for()
    page.locator("#detail-body .report-text", has_text="Fixture report").wait_for()
    assert page.locator("#detail-body h4").all_inner_texts() == [
        "Report", "Clinical information from the order", "Ordered items"
    ]
    # The generic caption is dropped; a meaningful caption is a heading.
    assert [text.upper() for text in page.locator("#detail-body h5").all_inner_texts()] == ["IMPRESSION", "DIAGNOSIS"]
    dialog_text = visible_text(page.locator("#detail-body"))
    for expected in ("Fixture impression", "Fixture indication", "Fixture pneumonia", "J18.9", "Fixture chest radiograph", "Fixture order comment"):
        assert expected in dialog_text, expected
    assert "CODE-X1" not in dialog_text
    page.locator("#detail-body details.admin > summary").click()
    assert "CODE-X1" in visible_text(page.locator("#detail-body"))
    page.locator("#detail-dialog .close").click()

    # Laboratory: specimen icons, flags, reference range, and the test code behind the info button.
    lab_result = page.locator("[data-result='laboratory']")
    assert lab_result.locator(".lab-date").count() == 1
    assert "2026-08-28" in lab_result.locator(".lab-date > summary").inner_text()
    specimens = lab_result.locator(".lab-specimen > summary")
    assert "Blood" in specimens.nth(0).inner_text()
    assert [node.get_attribute("data-specimen-kind") for node in lab_result.locator(".spec-icon").all()] == ["blood", "urine"]
    assert lab_result.locator(".spec-icon[data-specimen-kind='urine'] svg").count() == 1
    assert "Chemistry" in lab_result.locator(".lab-category > summary").inner_text()
    order_text = visible_text(lab_result.locator(".lab-order"))
    for expected in ("Glucose", "190", "70 – 100", "High", "Fixture remark", "Reported 2026-08-28 10:30"):
        assert expected in order_text, expected
    assert lab_result.locator(".lab-order .flag-high").count() == 2
    # Culture: organism, alert, and susceptibility are clinical content and are visible.
    for expected in ("Fixture culture", "Fixture growth", "Fixture organism", ">100000 CFU/mL", "Fixture resistance alert",
                     "Fixture antibiotic A", ">=16", "Fixture antibiotic B"):
        assert expected in order_text, expected
    assert lab_result.locator("table.suscept .badge").all_inner_texts() == ["R", "S"]
    assert "MCULT1" not in order_text and "GERM01" not in order_text and "LAM" not in order_text
    assert "GLU" not in order_text and "TEST-L1" not in order_text
    lab_result.locator(".lab-order tr.data-row").first.locator(".info-button").click()
    assert "GLU" in visible_text(lab_result.locator(".lab-order"))
    lab_result.locator(".lab-order-head .info-button").click()
    assert "TEST-L1" in visible_text(lab_result.locator(".lab-order"))

    # Pathology: the report text is on the card; a pending order says so.
    pathology = page.locator("[data-result='pathology']")
    assert pathology.locator(".report-card").count() == 2
    first_report = visible_text(pathology.locator(".report-card").nth(0))
    for expected in ("Surgical pathology", "Final report", "Fixture pathology diagnosis", "Fixture gross text", "Fixture order diagnosis"):
        assert expected in first_report, expected
    assert "TESTPNO1" not in first_report
    pathology.locator(".report-card").nth(1).locator("summary").first.click()
    assert "The report is not issued yet." in visible_text(pathology.locator(".report-card").nth(1))

    admission_result = page.locator("[data-result='admission']")
    admission_text = visible_text(admission_result)
    assert "2026-08-20 10:15" in admission_text and "In hospital" in admission_text
    assert "TESTADMIT1" not in admission_text
    assert admission_result.get_by_role("button", name="Open").count() == 0
    admission_result.locator(".info-button").click()
    assert "TESTADMIT1" in visible_text(admission_result)

    note_result = page.locator("[data-result='inpatient_note']")
    assert "Progress Note(POMR)" in note_result.inner_text()
    assert "TESTDIV" not in visible_text(note_result)
    # An unsigned note is listed and marked, in the list and in the opened note.
    note_rows = note_result.locator("tr.data-row")
    assert note_rows.count() == 2
    assert "Signed" in visible_text(note_rows.nth(0)) and "Not signed" not in visible_text(note_rows.nth(0))
    assert "Not signed" in visible_text(note_rows.nth(1))
    note_rows.nth(1).get_by_role("button", name="Open").click()
    page.locator("#detail-dialog[open]").wait_for()
    page.locator("#detail-body .report-text", has_text="Fixture objective").wait_for()
    assert "The doctor has not signed this note." in visible_text(page.locator("#detail-body"))
    page.locator("#detail-dialog .close").click()
    note_rows.nth(0).get_by_role("button", name="Open").click()
    page.locator("#detail-dialog[open]").wait_for()
    page.locator("#detail-body .report-text", has_text="Fixture objective").wait_for()
    assert "not signed" not in visible_text(page.locator("#detail-body")).lower()
    assert [text.upper() for text in page.locator("#detail-body h5").all_inner_texts()] == ["SUBJECTIVE", "OBJECTIVE"]
    assert "Fixture free text" in visible_text(page.locator("#detail-body"))
    assert "Progress Note(POMR) · 2026-08-21 09:30" in page.locator("#detail-title").inner_text()
    page.locator("#detail-dialog .close").click()

    # Outpatient notes: visits with a note by default, the note on the card, codes behind the block.
    visit_result = page.locator("[data-result='opd_note']")
    assert visit_result.locator("#visit-filter option").all_inner_texts() == ["Visits with a note (2)", "All visits (3)"]
    assert visit_result.locator(".report-card").count() == 2
    assert visit_result.locator(".notice").count() == 0
    first_visit = visible_text(visit_result.locator(".report-card").nth(0))
    for expected in ("2026-08-27", "Fixture emergency", "Fixture ER doctor", "Emergency", "Fixture chief complaint", "Fixture vital signs"):
        assert expected in first_visit, expected
    assert [text.upper() for text in visit_result.locator(".report-card").nth(0).locator("h5").all_inner_texts()] == ["CHIEF COMPLAINT", "VITAL SIGNS"]
    assert "TESTDR09" not in first_visit and "TESTCK01" not in first_visit and "OPD" not in first_visit
    visit_result.locator(".report-card").nth(0).locator("details.admin > summary").click()
    assert "TESTDR09" in visible_text(visit_result.locator(".report-card").nth(0))
    visit_result.locator(".report-card").nth(1).locator("summary").first.click()
    second_visit = visible_text(visit_result.locator(".report-card").nth(1))
    assert "Fixture outpatient subjective" in second_visit and "Fixture other part" in second_visit
    assert [text.upper() for text in visit_result.locator(".report-card").nth(1).locator("h5").all_inner_texts()] == ["SUBJECTIVE", "OBJECTIVE", "OTHER NOTE"]
    visit_result.locator("#visit-filter").select_option("all")
    assert visit_result.locator(".report-card").count() == 3
    visit_result.locator(".report-card").nth(2).locator("summary").first.click()
    assert "No note is recorded for this visit." in visible_text(visit_result.locator(".report-card").nth(2))
    visit_result.locator("#visit-filter").select_option("noted")
    assert visit_result.locator(".report-card").count() == 2

    # Discharge summary: stay dates and state in the list, named sections in the dialog.
    summary_result = page.locator("[data-result='discharge_summary']")
    summary_text = visible_text(summary_result)
    for expected in ("2026-06-11", "2026-06-20", "9 days", "2026-06-21", "Confirmed"):
        assert expected in summary_text, expected
    assert "TESTDOC001" not in summary_text and "TESTVS01" not in summary_text
    summary_result.get_by_role("button", name="Open").click()
    page.locator("#detail-dialog[open]").wait_for()
    page.locator("#detail-body .report-text", has_text="Fixture course text").wait_for()
    assert "Discharge summary · 2026-06-11 to 2026-06-20" in page.locator("#detail-title").inner_text()
    assert [text.upper() for text in page.locator("#detail-body h5").all_inner_texts()] == [
        "FIXTURE ADMISSION DIAGNOSIS", "FIXTURE HOSPITAL COURSE", "SECTION Z"
    ]
    assert "TESTDOC001" not in visible_text(page.locator("#detail-body"))
    page.locator("#detail-body details.admin > summary").click()
    assert "TESTDOC001" in visible_text(page.locator("#detail-body"))
    page.locator("#detail-dialog .close").click()

    # Operation notes: the note text is on the card; codes are behind the administrative block.
    operation_result = page.locator("[data-result='operation_note']")
    assert operation_result.locator(".report-card").count() == 2
    first_operation = visible_text(operation_result.locator(".report-card").nth(0))
    for expected in ("2026-06-12", "Fixture appendectomy; Fixture drainage", "Operative note", "Fixture operative note",
                     "<Fixture heading> second line", "Fixture appendicitis", "K35.80"):
        assert expected in first_operation, expected
    assert "ORCODE1" not in first_operation and "TESTDR01" not in first_operation
    operation_result.locator(".report-card").nth(0).locator("details.admin > summary").click()
    opened = visible_text(operation_result.locator(".report-card").nth(0))
    assert "ORCODE1, ORCODE2" in opened and "08:30" in opened and "10:15" in opened
    operation_result.locator(".report-card").nth(1).locator("summary").first.click()
    assert "This operation was cancelled." in visible_text(operation_result.locator(".report-card").nth(1))

    accession_result = page.locator("[data-result='exam_accession']")
    accession_text = visible_text(accession_result)
    assert "TEST-ACC-2" in accession_text and "Fixture CT" in accession_text
    assert "TEST-REF-2" not in accession_text
    cancelled_order = accession_result.locator("tr.data-row", has_text="Fixture cancelled MRI")
    assert "Cancelled" in visible_text(cancelled_order)
    assert "2026-08-16" not in visible_text(cancelled_order)
    accession_result.locator("tr.data-row", has_text="Fixture CT").get_by_role("button", name="Items").click()
    page.locator("#detail-dialog[open]").wait_for()
    page.locator("#detail-body .report-text", has_text="Fixture computed tomography").wait_for()
    items_text = visible_text(page.locator("#detail-body"))
    assert "CHEST" in items_text and "PRICE-1" not in items_text
    page.locator("#detail-dialog .close").click()

    page.locator("#accession-no").fill("testacc3")
    page.get_by_role("button", name="Find accession").click()
    direct_result = page.locator("[data-result='accession']")
    direct_result.locator(".report-text", has_text="Fixture accession report").wait_for()
    assert page.locator(".result-section").count() == 1
    direct_text = visible_text(direct_result)
    assert "Accession TESTACC3" in direct_text
    assert "1 exam" in direct_text and "Fixture accession exam" in direct_text
    assert "Other exam" in direct_text
    banner.locator("strong", has_text="Fixture Patient").wait_for()

    page.screenshot(path=str(SCREENSHOT), full_page=True)
    assert not console_errors, console_errors
    browser.close()
    print("UI smoke test passed; screenshot:", SCREENSHOT)
