import asyncio
import unittest
from datetime import date

from fastapi import HTTPException

import app as app_module
from app import create_app


class FakeService:
    def __init__(self):
        self.calls = []

    def search_radiology(self, chart_no, window):
        self.calls.append(("radiology", chart_no, window))
        return [{"source_schema": "XRAY", "apply_no": "A1"}]

    def search_exam_accessions(self, chart_no, window):
        self.calls.append(("exam_accession", chart_no, window))
        return [{"hospital_id": "000", "apply_no": "A1", "reference_no": "R1"}]

    def search_laboratory(self, chart_no, window):
        self.calls.append(("laboratory", chart_no, window))
        return []

    def search_pathology(self, chart_no, window):
        self.calls.append(("pathology", chart_no, window))
        return []

    def radiology_detail(self, source, hospital_id, apply_no):
        self.calls.append(("detail", source, hospital_id, apply_no))
        return {"items": [], "remarks": [], "reports": []}

    def exam_accession_detail(self, hospital_id, apply_no):
        self.calls.append(("exam_accession_detail", hospital_id, apply_no))
        return {"items": []}

    def accession_report(self, accession_no):
        self.calls.append(("accession_report", accession_no))
        return [{
            "source_schema": "XRAY", "hospital_id": "000", "apply_no": "A1",
            "access_no": accession_no, "items": [], "remarks": [],
            "reports": [{"caption": "Findings", "content": "Text"}],
        }]

    def patient_info(self, chart_no):
        self.calls.append(("patient_info", chart_no))
        return {"chart_no": chart_no, "pt_name": "TEST"}

    def search_admissions(self, chart_no, window):
        self.calls.append(("admission", chart_no, window))
        return [{"admit_no": "1150012345", "cut_no": "00"}]

    def search_inpatient_notes(self, chart_no, window):
        self.calls.append(("inpatient_note", chart_no, window))
        return [{"admit_no": "1150012345", "note_date": "1151008", "note_time": "0930"}]

    def search_outpatient_notes(self, chart_no, window):
        self.calls.append(("opd_note", chart_no, window))
        return [{"clinic_date": "1150910", "kind": "outpatient", "has_note": True, "sections": []}]

    def search_discharge_summaries(self, chart_no, window):
        self.calls.append(("discharge_summary", chart_no, window))
        return [{"document_no": "D000000001", "state": "confirmed"}]

    def discharge_summary_detail(self, document_no):
        self.calls.append(("discharge_summary_detail", document_no))
        if document_no == "bad-number":
            raise ValueError("Document number must contain letters and digits only")
        return {"sections": [{"section_no": "A", "section_name": "Admission diagnosis", "content": "Text"}]}

    def search_operations(self, chart_no, window):
        self.calls.append(("operation_note", chart_no, window))
        return [{"or_date": "1150910", "state": "noted", "note": "Text", "procedures": []}]

    def inpatient_note_detail(self, admit_no, note_date, note_time):
        self.calls.append(("inpatient_note_detail", admit_no, note_date, note_time))
        return {"sections": [{"section_type": "S", "content": "Text"}]}


def endpoint(application, path):
    return next(route.endpoint for route in application.routes if route.path == path)


class AppContractTests(unittest.TestCase):
    def setUp(self):
        self.service = FakeService()
        self.app = create_app(self.service)

    def test_expected_api_routes_are_exposed(self):
        paths = {route.path for route in self.app.routes}
        self.assertTrue(
            {
                "/api/health",
                "/api/workflows",
                "/api/search/{workflow}",
                "/api/radiology/{source}/{hospital_id}/{apply_no}",
                "/api/exam-accessions/{hospital_id}/{apply_no}",
                "/api/accession/{accession_no}",
                "/api/patient/{chart_no}",
                "/api/inpatient-notes/{admit_no}/{note_date}/{note_time}",
                "/api/discharge-summaries/{document_no}",
                "/",
            }.issubset(paths)
        )

    def test_search_endpoint_dispatches_with_explicit_dates(self):
        search = endpoint(self.app, "/api/search/{workflow}")
        response = asyncio.run(
            search(
                workflow="radiology",
                chart_no="12345",
                start_date=date(2026, 1, 1),
                end_date=date(2026, 8, 28),
            )
        )

        self.assertEqual(response["count"], 1)
        self.assertEqual(response["chart_no"], "0000012345")
        self.assertEqual(self.service.calls[0][0], "radiology")
        self.assertEqual(self.service.calls[0][2].start_roc, "1150101")

    def test_exam_accession_search_dispatches_to_dedicated_service(self):
        search = endpoint(self.app, "/api/search/{workflow}")
        response = asyncio.run(search(
            workflow="exam_accession",
            chart_no="12345",
            start_date=date(2026, 1, 1),
            end_date=date(2026, 8, 28),
        ))

        self.assertEqual(response["count"], 1)
        self.assertEqual(response["results"][0]["reference_no"], "R1")
        self.assertEqual(self.service.calls[0][0], "exam_accession")

    def test_exam_accession_detail_endpoint_is_separate_from_report_detail(self):
        detail = endpoint(self.app, "/api/exam-accessions/{hospital_id}/{apply_no}")
        response = asyncio.run(detail(hospital_id="000", apply_no="A1"))

        self.assertEqual(response["items"], [])
        self.assertEqual(self.service.calls[0], ("exam_accession_detail", "000", "A1"))

    def test_accession_endpoint_returns_matches_with_report_sections(self):
        search = endpoint(self.app, "/api/accession/{accession_no}")
        with self.assertLogs("his_query_app", level="INFO") as logs:
            response = asyncio.run(search(accession_no=" ct115100800 "))

        self.assertEqual(response["accession_no"], "CT115100800")
        self.assertEqual(response["count"], 1)
        self.assertEqual(response["results"][0]["reports"][0]["caption"], "Findings")
        self.assertEqual(self.service.calls[0], ("accession_report", "CT115100800"))
        self.assertNotIn("CT115100800", "".join(logs.output))

    def test_accession_endpoint_rejects_malformed_numbers(self):
        search = endpoint(self.app, "/api/accession/{accession_no}")
        with self.assertRaises(HTTPException) as caught:
            asyncio.run(search(accession_no="115-1008"))

        self.assertEqual(caught.exception.status_code, 422)
        self.assertEqual(self.service.calls, [])

    def test_patient_endpoint_normalizes_the_chart_and_reports_missing_patients(self):
        patient = endpoint(self.app, "/api/patient/{chart_no}")
        response = asyncio.run(patient(chart_no="12345"))

        self.assertTrue(response["found"])
        self.assertEqual(response["chart_no"], "0000012345")
        self.assertEqual(self.service.calls[0], ("patient_info", "0000012345"))

        self.service.patient_info = lambda chart_no: None
        response = asyncio.run(patient(chart_no="12345"))
        self.assertFalse(response["found"])
        self.assertIsNone(response["patient"])

    def test_inpatient_workflows_dispatch_to_their_services(self):
        search = endpoint(self.app, "/api/search/{workflow}")
        for workflow in ("admission", "inpatient_note", "discharge_summary", "operation_note", "opd_note"):
            with self.subTest(workflow=workflow):
                self.service.calls.clear()
                response = asyncio.run(search(
                    workflow=workflow,
                    chart_no="12345",
                    start_date=date(2026, 1, 1),
                    end_date=date(2026, 8, 28),
                ))
                self.assertEqual(response["count"], 1)
                self.assertEqual(self.service.calls[0][:2], (workflow, "0000012345"))

    def test_inpatient_note_detail_endpoint_passes_the_full_identity(self):
        detail = endpoint(self.app, "/api/inpatient-notes/{admit_no}/{note_date}/{note_time}")
        response = asyncio.run(detail(admit_no="1150012345", note_date="1151008", note_time="0930"))

        self.assertEqual(response["sections"][0]["section_type"], "S")
        self.assertEqual(
            self.service.calls[0],
            ("inpatient_note_detail", "1150012345", "1151008", "0930"),
        )

    def test_discharge_summary_detail_endpoint_returns_sections_and_rejects_bad_numbers(self):
        detail = endpoint(self.app, "/api/discharge-summaries/{document_no}")
        response = asyncio.run(detail(document_no="D000000001"))

        self.assertEqual(response["document_no"], "D000000001")
        self.assertEqual(response["sections"][0]["section_name"], "Admission diagnosis")
        self.assertEqual(self.service.calls[0], ("discharge_summary_detail", "D000000001"))

        with self.assertRaises(HTTPException) as caught:
            asyncio.run(detail(document_no="bad-number"))
        self.assertEqual(caught.exception.status_code, 422)

    def test_deferred_workflow_is_not_silently_queried(self):
        # Every workflow is available now, so a deferred one is injected into the catalog.
        original = app_module.workflow_catalog
        app_module.workflow_catalog = lambda: original() + [
            {"id": "future_note", "label": "Future", "implementation": "deferred", "evidence": "observed"}
        ]
        self.addCleanup(setattr, app_module, "workflow_catalog", original)
        search = endpoint(self.app, "/api/search/{workflow}")
        with self.assertRaises(HTTPException) as caught:
            asyncio.run(
                search(
                    workflow="future_note",
                    chart_no="12345",
                    start_date=date(2026, 1, 1),
                    end_date=date(2026, 8, 28),
                )
            )
        self.assertEqual(caught.exception.status_code, 409)
        self.assertEqual(self.service.calls, [])

    def test_unknown_workflow_is_rejected(self):
        search = endpoint(self.app, "/api/search/{workflow}")
        with self.assertRaises(HTTPException) as caught:
            asyncio.run(search(
                workflow="no_such_workflow", chart_no="12345",
                start_date=date(2026, 1, 1), end_date=date(2026, 8, 28),
            ))
        self.assertEqual(caught.exception.status_code, 404)

    def test_laboratory_response_includes_cascading_groups(self):
        self.service.search_laboratory = lambda chart_no, window: [{
            "order_date": "1150828", "hospital_id": "000", "lab_no": "L1",
            "specimen_code": "B", "specimen_name": "Blood",
            "category_code": "CH", "category_name": "Chemistry",
            "unique_seq": "1", "code": "GLU", "lab_name": "Glucose",
            "result_description": "90",
        }]
        search = endpoint(self.app, "/api/search/{workflow}")
        response = asyncio.run(search(
            workflow="laboratory",
            chart_no="12345",
            start_date=date(2026, 1, 1),
            end_date=date(2026, 8, 28),
        ))

        self.assertEqual(response["groups"][0]["date"], "2026-08-28")
        self.assertEqual(response["groups"][0]["specimens"][0]["specimen_name"], "Blood")

    def test_database_exception_is_sanitized(self):
        def fail(*args, **kwargs):
            raise RuntimeError("ORA-00000 secret internal detail")

        self.service.search_laboratory = fail
        search = endpoint(self.app, "/api/search/{workflow}")
        with self.assertLogs("his_query_app", level="ERROR"):
            with self.assertRaises(HTTPException) as caught:
                asyncio.run(
                    search(
                        workflow="laboratory",
                        chart_no="12345",
                        start_date=date(2026, 1, 1),
                        end_date=date(2026, 8, 28),
                    )
                )
        self.assertEqual(caught.exception.status_code, 503)
        self.assertNotIn("ORA", str(caught.exception.detail))


if __name__ == "__main__":
    unittest.main()
