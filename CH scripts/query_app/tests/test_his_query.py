import unittest
from datetime import date


from his_query import (
    ACCESSION_SEARCH_SQL,
    ADMISSION_SEARCH_SQL,
    DISCHARGE_SUMMARY_SEARCH_SQL,
    DISCHARGE_SUMMARY_TEXT_SQL,
    EXAM_ACCESSION_DETAIL_SQL,
    EXAM_ACCESSION_SEARCH_SQL,
    EXAM_ITEM_NAME_SQL,
    HisQueryService,
    INPATIENT_NOTE_SEARCH_SQL,
    INPATIENT_NOTE_TEXT_SQL,
    LAB_SCHEMAS,
    LAB_SEARCH_SQL,
    NODE_INPATIENT,
    NODE_PATIENT,
    OPERATION_SEARCH_SQL,
    OUTPATIENT_SCHEMAS,
    PATHOLOGY_CYTOLOGY_SQL,
    PATHOLOGY_GYN_SQL,
    PATHOLOGY_SEARCH_SQL,
    PATHOLOGY_SURGICAL_SQL,
    PATIENT_SQL,
    RADIOLOGY_DETAIL_SQL,
    RADIOLOGY_SEARCH_SQL,
    QueryConfig,
    SearchWindow,
    build_organisms,
    build_pathology_reports,
    exam_report_state,
    group_document_sections,
    group_inpatient_note_sections,
    inpatient_note_state,
    group_laboratory_rows,
    group_operations,
    group_outpatient_visits,
    group_report_sections,
    laboratory_sql,
    merge_laboratory_rows,
    microbiology_organism_sql,
    normalize_accession_no,
    normalize_chart_no,
    normalize_document_no,
    oracle_rows,
    outpatient_month_schema,
    outpatient_note_sql,
    outpatient_schemas,
    pad_char_key,
    roc_number_to_text,
    signed_roc_date_to_iso,
    summarize_exam_remarks,
    workflow_catalog,
)


class _RecordingCursor:
    def __init__(self, sink):
        self._sink = sink
        self.description = []

    def execute(self, sql, params):
        self._sink.append((sql, params))

    def fetchall(self):
        return []

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class _RecordingConnection:
    def __init__(self, sink):
        self._sink = sink

    def cursor(self):
        return _RecordingCursor(self._sink)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def make_recording_service(sink):
    return HisQueryService(
        config=QueryConfig(db_user="user", db_password="password", hospital_id="000"),
        connect=lambda **_kwargs: _RecordingConnection(sink),
    )


class _ScriptedCursor:
    """Return canned rows for the first SQL marker found in the statement."""

    def __init__(self, calls, dsn, script):
        self._calls = calls
        self._dsn = dsn
        self._script = script
        self.description = []
        self._rows = []

    def execute(self, sql, params):
        self._calls.append((self._dsn, sql, params))
        for marker, (columns, rows) in self._script.items():
            if marker in sql:
                self.description = [(column,) for column in columns]
                self._rows = rows
                return

    def fetchall(self):
        return self._rows

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class _ScriptedConnection:
    def __init__(self, calls, dsn, script):
        self._args = (calls, dsn, script)

    def cursor(self):
        return _ScriptedCursor(*self._args)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def make_scripted_service(calls, script=None):
    return HisQueryService(
        config=QueryConfig(db_user="user", db_password="password", hospital_id="000"),
        connect=lambda **kwargs: _ScriptedConnection(calls, kwargs["dsn"], script or {}),
    )


class QueryContractTests(unittest.TestCase):
    def test_chart_number_is_numeric_and_zero_padded(self):
        self.assertEqual(normalize_chart_no("12345"), "0000012345")
        self.assertEqual(normalize_chart_no("0000012345"), "0000012345")

        for invalid in ("", "12A45", "12345678901"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                normalize_chart_no(invalid)

    def test_search_window_converts_gregorian_to_roc_dates(self):
        window = SearchWindow.from_dates(date(2025, 1, 2), date(2026, 8, 28))

        self.assertEqual(window.start_roc, "1140102")
        self.assertEqual(window.end_roc, "1150828")

    def test_search_window_rejects_reverse_or_excessive_ranges(self):
        with self.assertRaises(ValueError):
            SearchWindow.from_dates(date(2026, 1, 2), date(2026, 1, 1))
        with self.assertRaises(ValueError):
            SearchWindow.from_dates(date(2015, 1, 1), date(2026, 1, 1))

    def test_query_config_requires_credentials_only_when_connecting(self):
        config = QueryConfig(db_user="", db_password="")
        with self.assertRaises(RuntimeError):
            config.connection_kwargs()

    def test_oracle_rows_trims_strings_and_preserves_nulls(self):
        description = [("CHART_NO",), ("ORDER_DATE",), ("CONTENT",)]
        rows = [("0000012345   ", "1150828", None)]

        self.assertEqual(
            oracle_rows(description, rows),
            [{"chart_no": "0000012345", "order_date": "1150828", "content": None}],
        )

    def test_pad_char_key_matches_blank_padded_char_columns(self):
        self.assertEqual(pad_char_key("0274", 20), "0274" + " " * 16)
        self.assertEqual(pad_char_key("  000  ", 3), "000")
        self.assertIsNone(pad_char_key("K" * 21, 20))

        with self.assertRaises(ValueError):
            pad_char_key("", 20)

    def test_detail_queries_bind_blank_padded_char_keys(self):
        bound = []
        service = make_recording_service(bound)

        service.radiology_detail("xray", "000", "0274")

        self.assertEqual(len(bound), 3)
        for _sql, params in bound:
            self.assertEqual(params["hospital_id"], "000")
            self.assertEqual(params["apply_no"], "0274" + " " * 16)

    def test_exam_remark_detail_uses_the_narrower_column_width(self):
        bound = []
        service = make_recording_service(bound)

        service.radiology_detail("exam", "000", "0274")

        widths = sorted(params["apply_no"] for _sql, params in bound)
        self.assertEqual(
            widths, ["0274" + " " * 11, "0274" + " " * 16, "0274" + " " * 16]
        )

    def test_detail_skips_tables_that_cannot_hold_the_key(self):
        bound = []
        service = make_recording_service(bound)

        result = service.radiology_detail("exam", "000", "K" * 18)

        self.assertEqual(result["remarks"], [])
        for sql, _params in bound:
            self.assertNotIn("PTEXAMREMARK", sql.upper())

    def test_accession_detail_binds_blank_padded_char_keys(self):
        bound = []
        service = make_recording_service(bound)

        service.exam_accession_detail("000", "0274")

        self.assertEqual(len(bound), 1)
        self.assertEqual(bound[0][1]["apply_no"], "0274" + " " * 16)

    def test_radiology_query_matches_confirmed_dual_schema_identity(self):
        self.assertEqual(set(RADIOLOGY_SEARCH_SQL), {"EXAM", "XRAY"})
        for sql in RADIOLOGY_SEARCH_SQL.values():
            normalized = " ".join(sql.upper().split())
            self.assertIn("I.CHART_NO = :CHART_NO", normalized)
            self.assertIn("I.ORDER_DATE BETWEEN :START_DATE AND :END_DATE", normalized)
            self.assertIn("E.HOSPITAL_ID = I.HOSPITAL_ID", normalized)
            self.assertIn("E.APPLY_NO = I.APPLY_NO", normalized)
            self.assertNotIn("TRIM(I.CHART_NO)", normalized)

    def test_exam_accession_search_matches_kardeuse_xray_workflow(self):
        normalized = " ".join(EXAM_ACCESSION_SEARCH_SQL.upper().split())
        self.assertIn("FROM XRAY.PTEXAMINDEX I", normalized)
        self.assertNotIn("EXAM.PTEXAMINDEX", normalized)
        self.assertIn("I.CHART_NO = :CHART_NO", normalized)
        self.assertIn("I.ORDER_DATE >= :START_DATE", normalized)
        self.assertIn("E.HOSPITAL_ID = I.HOSPITAL_ID", normalized)
        self.assertIn("E.APPLY_NO = I.APPLY_NO", normalized)
        self.assertIn("I.ACCESS_NO AS ACCESS_NO", normalized)
        self.assertIn("E.REF_NO AS REFERENCE_NO", normalized)
        self.assertNotIn("TRIM(I.CHART_NO)", normalized)

    def test_exam_accession_detail_uses_composite_identity_and_master_item_keys(self):
        normalized = " ".join(EXAM_ACCESSION_DETAIL_SQL.upper().split())
        self.assertIn("FROM XRAY.PTEXAMITEM I", normalized)
        self.assertIn("EXAMMAST.EXAMITEM M", normalized)
        self.assertIn("M.EXAM_CODE = I.EXAM_CODE", normalized)
        self.assertIn("M.EXAM_TYPE = I.EXAM_TYPE", normalized)
        self.assertIn("I.HOSPITAL_ID = :HOSPITAL_ID", normalized)
        self.assertIn("I.APPLY_NO = :APPLY_NO", normalized)
        self.assertNotIn("PTEXAMRPT", normalized)
        self.assertNotIn("PTEXAMREMARK", normalized)

    def test_lab_query_uses_hospital_aware_order_item_identity(self):
        normalized = " ".join(LAB_SEARCH_SQL.upper().split())
        self.assertIn("X1.HOSPITAL_ID = :HOSPITAL_ID", normalized)
        self.assertIn("X1.CHART_NO = :CHART_NO", normalized)
        self.assertIn("X2.HOSPITAL_ID = X1.HOSPITAL_ID", normalized)
        self.assertIn("X2.LAB_NO = X1.LAB_NO", normalized)
        self.assertNotIn("TRIM(X1.CHART_NO)", normalized)
        self.assertNotIn(" IN (", normalized)
        self.assertIn("LABMAST.SPECIMEN", normalized)
        self.assertIn("LABMAST.LABGROUP", normalized)
        self.assertIn("SP.SPECIMEN_CODE = X1.SPECIMEN_CODE", normalized)
        # CODE is blank on most item rows, so the test name is joined by LAB_CODE.
        self.assertIn("M1.LAB_CODE = X2.LAB_CODE", normalized)
        self.assertNotIn("M1.LAB_CODE = X2.CODE", normalized)
        # ORDER_DATE is unset on most orders; LAB_ORDER_DATE is set on every order.
        self.assertIn("X1.LAB_ORDER_DATE BETWEEN :START_DATE AND :END_DATE", normalized)
        self.assertIn("X1.LAB_ORDER_DATE AS ORDER_DATE", normalized)
        self.assertNotIn("X1.ORDER_DATE BETWEEN", normalized)

    def test_laboratory_statement_covers_four_schema_families_from_a_fixed_list(self):
        self.assertEqual(LAB_SCHEMAS, ("LAB", "LABHIS", "LAM", "LAMHIS"))
        self.assertEqual(laboratory_sql("LAB"), LAB_SEARCH_SQL)
        for schema in LAB_SCHEMAS:
            normalized = " ".join(laboratory_sql(schema).upper().split())
            self.assertIn(f"FROM {schema}.LABX1 X1", normalized)
            self.assertIn(f"JOIN {schema}.LABX2 X2", normalized)
            self.assertIn(f"'{schema}' AS SOURCE_SCHEMA", normalized)
        for unsafe in ("LAP", "lab", "LAB; DROP TABLE X", ""):
            with self.subTest(schema=unsafe), self.assertRaises(ValueError):
                laboratory_sql(unsafe)

        organism_sql = " ".join(microbiology_organism_sql("LAM").upper().split())
        self.assertIn("JOIN LAM.LABM M", organism_sql)
        self.assertIn("M.HOSPITAL_ID = X1.HOSPITAL_ID", organism_sql)
        self.assertIn("M.LAB_NO = X1.LAB_NO", organism_sql)
        self.assertIn("X1.CHART_NO = :CHART_NO", organism_sql)
        self.assertIn("M.MED_CODE_20, M.RSMI_20, M.RSMI_RESULT_20", organism_sql)
        self.assertNotIn("MED_CODE_21", organism_sql)
        with self.assertRaises(ValueError):
            microbiology_organism_sql("LAB")

    def test_laboratory_rows_merge_without_duplicates_newest_first(self):
        def row(source, order_date, lab_no, seq, time="0900"):
            return {"source_schema": source, "hospital_id": "000", "lab_no": lab_no, "unique_seq": seq,
                    "lab_code": "C1", "order_date": order_date, "lab_order_time": time}

        merged = merge_laboratory_rows([
            row("LAB", "1150910", "L2", "00002"), row("LAB", "1150910", "L2", "00001"),
            row("LABHIS", "1090601", "H1", "00001"), row("LABHIS", "1150910", "L2", "00001"),
            row("LAM", "1150912", "M1", "00001"),
        ])

        self.assertEqual(
            [(item["source_schema"], item["lab_no"], item["unique_seq"]) for item in merged],
            [("LAM", "M1", "00001"), ("LAB", "L2", "00001"), ("LAB", "L2", "00002"), ("LABHIS", "H1", "00001")],
        )
        self.assertEqual([item["microbiology"] for item in merged], [True, False, False, False])

    def test_organisms_list_only_the_filled_drug_sets_with_names(self):
        row = {"lab_no": "M1 ", "unique_seq": "00001", "lab_code": "CULT   ", "germ_seq": "1",
               "germ_code": "ECOLI     ", "germ_name": "Escherichia coli" + " " * 10, "colony_count": ">100000",
               "med_code_1": "AMP       ", "rsmi_1": "R ", "rsmi_result_1": ">=32",
               "med_code_2": "", "rsmi_2": "S",
               "med_code_3": "XYZ", "rsmi_3": "S", "rsmi_result_3": None}

        organisms = build_organisms([row], {"AMP": "Ampicillin"})

        self.assertEqual(list(organisms), [("M1", "00001", "CULT")])
        organism = organisms[("M1", "00001", "CULT")][0]
        self.assertEqual(organism["germ_name"], "Escherichia coli")
        self.assertEqual(organism["drugs"], [
            {"code": "AMP", "name": "Ampicillin", "result": "R", "value": ">=32"},
            {"code": "XYZ", "name": "XYZ", "result": "S", "value": ""},
        ])

    def test_laboratory_search_reads_all_families_and_attaches_organisms(self):
        connections, statements = [], []
        script = {
            "FROM LAM.LABX1 x1\n    JOIN LAM.LABX2": (
                ("SOURCE_SCHEMA", "HOSPITAL_ID", "LAB_NO", "UNIQUE_SEQ", "LAB_CODE", "ORDER_DATE"),
                [("LAM", "000", "M1", "00001", "CULT   ", "1150912")],
            ),
            "FROM LAB.LABX1 x1\n    JOIN LAB.LABX2": (
                ("SOURCE_SCHEMA", "HOSPITAL_ID", "LAB_NO", "UNIQUE_SEQ", "LAB_CODE", "ORDER_DATE"),
                [("LAB", "000", "L1", "00001", "GLU    ", "1150910")],
            ),
            "JOIN LAM.LABM": (
                ("LAB_NO", "UNIQUE_SEQ", "LAB_CODE", "GERM_CODE", "GERM_NAME", "MED_CODE_1", "RSMI_1", "RSMI_RESULT_1"),
                [("M1", "00001", "CULT   ", "ECOLI", "Escherichia coli", "AMP", "R", ">=32")],
            ),
            "FROM LABMAST.ANTIBIOTIC": (
                ("ANTIBIOTIC_CODE", "ANTIBIOTIC_NAME", "SHORT_NAME"), [("AMP       ", "Ampicillin", "AMP")],
            ),
        }

        class Cursor:
            def __init__(self):
                self.description, self._rows = [], []

            def execute(self, sql, params):
                statements.append(sql)
                for marker, (columns, rows) in script.items():
                    if marker in sql:
                        self.description = [(column,) for column in columns]
                        self._rows = rows
                        return

            def fetchall(self):
                return self._rows

            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

        class Connection:
            def __init__(self, dsn):
                connections.append(dsn)

            def cursor(self):
                return Cursor()

            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

        service = HisQueryService(
            config=QueryConfig(db_user="user", db_password="password", hospital_id="000"),
            connect=lambda **kwargs: Connection(kwargs["dsn"]),
        )
        window = SearchWindow.from_dates(date(2026, 1, 1), date(2026, 10, 13))

        rows = service.search_laboratory("12345", window)
        service.search_laboratory("12345", window)

        self.assertEqual([(row["source_schema"], row["lab_no"]) for row in rows], [("LAM", "M1"), ("LAB", "L1")])
        self.assertEqual(rows[0]["organisms"][0]["drugs"], [
            {"code": "AMP", "name": "Ampicillin", "result": "R", "value": ">=32"},
        ])
        self.assertNotIn("organisms", rows[1])
        self.assertTrue(all("(SID=he)" in dsn for dsn in connections))
        # One search: the four families on one connection, the organisms on one, the antibiotic names once.
        self.assertEqual(len(connections), 5)
        self.assertEqual(sum("LABMAST.ANTIBIOTIC" in sql and "LABX1" not in sql for sql in statements), 1)
        # Only LAM returned a row, so LAMHIS.LABM is not read.
        self.assertEqual(sum("JOIN LAMHIS.LABM" in sql for sql in statements), 0)

    def test_lab_rows_group_by_date_specimen_category_and_order(self):
        rows = [
            {
                "order_date": "1150828", "hospital_id": "000", "lab_no": "L2",
                "specimen_code": "B", "specimen_name": "Blood",
                "category_code": "CH", "category_name": "Chemistry",
                "unique_seq": "1", "code": "GLU", "lab_name": "Glucose",
                "result_description": "90",
            },
            {
                "order_date": "1150828", "hospital_id": "000", "lab_no": "L2",
                "specimen_code": "B", "specimen_name": "Blood",
                "category_code": "CH", "category_name": "Chemistry",
                "unique_seq": "2", "code": "CRE", "lab_name": "Creatinine",
                "result_description": "1.0",
            },
            {
                "order_date": "1150828", "hospital_id": "000", "lab_no": "L1",
                "specimen_code": "U", "specimen_name": "Urine",
                "category_code": "UA", "category_name": "Urinalysis",
                "unique_seq": "1", "code": "PH", "lab_name": "pH",
                "result_description": "6",
            },
            {
                "order_date": "1150827", "hospital_id": "000", "lab_no": "L0",
                "specimen_code": "", "specimen_name": "",
                "category_code": "", "category_name": "",
                "unique_seq": "1", "code": "X", "lab_name": "Other",
                "result_description": "negative",
            },
        ]

        groups = group_laboratory_rows(rows)

        self.assertEqual([group["date"] for group in groups], ["2026-08-28", "2026-08-27"])
        self.assertEqual(groups[0]["item_count"], 3)
        self.assertEqual(groups[0]["order_count"], 2)
        blood = groups[0]["specimens"][0]
        self.assertEqual(blood["specimen_name"], "Blood")
        self.assertEqual(blood["categories"][0]["category_name"], "Chemistry")
        self.assertEqual(len(blood["categories"][0]["orders"][0]["items"]), 2)
        self.assertEqual(groups[1]["specimens"][0]["specimen_name"], "Unknown specimen")
        self.assertEqual(groups[1]["specimens"][0]["categories"][0]["category_name"], "Uncategorized")

    def test_pathology_header_query_lists_orders_by_chart_and_order_date(self):
        normalized = " ".join(PATHOLOGY_SEARCH_SQL.upper().split())
        self.assertIn("FROM LAP.LABP1 P1", normalized)
        self.assertIn("P1.HOSPITAL_ID = :HOSPITAL_ID", normalized)
        self.assertIn("P1.CHART_NO = :CHART_NO", normalized)
        self.assertIn("P1.LAB_ORDER_DATE BETWEEN :START_DATE AND :END_DATE", normalized)
        self.assertNotIn("P1.ORDER_DATE BETWEEN", normalized)
        self.assertIn("P1.PATHOLOGY_TYPE", normalized)
        self.assertNotIn("TRIM(P1.CHART_NO)", normalized)
        # One row per order: the text tables are read by separate statements.
        for text_table in ("LAP.LABS2", "LAP.LABN", "LAP.LABG"):
            self.assertNotIn(text_table, normalized)

    def test_pathology_text_queries_join_each_family_on_hospital_and_lab_number(self):
        for sql, table, alias in (
            (PATHOLOGY_SURGICAL_SQL, "LAP.LABS2", "S2"),
            (PATHOLOGY_CYTOLOGY_SQL, "LAP.LABN", "N"),
            (PATHOLOGY_GYN_SQL, "LAP.LABG", "G"),
        ):
            with self.subTest(table=table):
                normalized = " ".join(sql.upper().split())
                self.assertIn(f"JOIN {table} {alias}", normalized)
                self.assertIn(f"{alias}.HOSPITAL_ID = P1.HOSPITAL_ID", normalized)
                self.assertIn(f"{alias}.LAB_NO = P1.LAB_NO", normalized)
                self.assertIn("P1.CHART_NO = :CHART_NO", normalized)
                for withheld in ("TEL_HOME", "ADDRESS"):
                    self.assertNotIn(withheld, normalized)

    def test_pathology_reports_attach_text_by_family_in_reading_order(self):
        headers = [
            {"lab_no": "L1", "pathology_type": "S", "confirmed_date": "1151001", "report_date": "1150930"},
            {"lab_no": "L2", "pathology_type": "N", "confirmed_date": "0000000", "report_date": "1150930"},
            {"lab_no": "L3", "pathology_type": "G", "receive_date": "1150929"},
            {"lab_no": "L4", "pathology_type": "S", "receive_date": "       "},
        ]
        reports = build_pathology_reports(
            headers,
            surgical=[
                {"lab_no": "L1", "unique_seq": "01", "report_type": "1", "report_description": "diagnosis text "},
                {"lab_no": "L1", "unique_seq": "01", "report_type": "2", "report_description": "gross text"},
                {"lab_no": "L1", "unique_seq": "01", "report_type": "3", "report_description": "   "},
            ],
            cytology=[{
                "lab_no": "L2", "unique_seq": "00", "specimen_content": None,
                "gross_appearance": "cloudy", "result_description": "negative", "lab_comment": "",
            }],
            gyn=[{"lab_no": "L3", "unique_seq": "00", "result_code": "01", "result_description": "  "}],
        )

        self.assertEqual([report["state"] for report in reports], ["confirmed", "reported", "received", "ordered"])
        self.assertEqual(reports[0]["kind"], "Surgical pathology")
        self.assertEqual(
            [(section["part"], section["label"], section["content"]) for section in reports[0]["sections"]],
            [("01", "Pathologic diagnosis", "diagnosis text"), ("01", "Gross description", "gross text")],
        )
        self.assertEqual([section["label"] for section in reports[1]["sections"]], ["Gross appearance", "Result"])
        self.assertEqual(reports[2]["kind"], "Cytology (gynecologic)")
        self.assertEqual(reports[2]["sections"], [])
        self.assertEqual(reports[2]["result_codes"], ["01"])
        self.assertEqual(reports[3]["sections"], [])

    def test_pathology_search_reads_only_the_text_tables_its_orders_need(self):
        calls = []
        service = make_scripted_service(calls, {
            "JOIN LAP.LABS2": (
                ("LAB_NO", "UNIQUE_SEQ", "REPORT_TYPE", "REPORT_DESCRIPTION"),
                [("L1", "01", "1", "diagnosis text")],
            ),
            "FROM LAP.LABP1 p1\n    LEFT JOIN LABMAST.SPECIMEN": (
                ("LAB_NO", "PATHOLOGY_TYPE", "CONFIRMED_DATE"),
                [("L1" + " " * 8, "S", "1151001")],
            ),
        })

        reports = service.search_pathology(
            "12345", SearchWindow.from_dates(date(2026, 1, 1), date(2026, 10, 13))
        )

        self.assertEqual(len(calls), 2)
        self.assertEqual(reports[0]["sections"][0]["label"], "Pathologic diagnosis")
        self.assertEqual(make_scripted_service([]).search_pathology(
            "12345", SearchWindow.from_dates(date(2026, 1, 1), date(2026, 10, 13))
        ), [])

    def test_exam_item_names_come_from_the_master_for_both_schemas(self):
        self.assertEqual(set(EXAM_ITEM_NAME_SQL), {"EXAM", "XRAY"})
        for schema, sql in EXAM_ITEM_NAME_SQL.items():
            normalized = " ".join(sql.upper().split())
            self.assertIn(f"FROM {schema}.PTEXAMINDEX I", normalized)
            self.assertIn(f"JOIN {schema}.PTEXAMITEM X", normalized)
            self.assertIn("X.HOSPITAL_ID = I.HOSPITAL_ID", normalized)
            self.assertIn("M.EXAM_CODE = X.EXAM_CODE", normalized)
            self.assertIn("M.EXAM_TYPE = X.EXAM_TYPE", normalized)
            self.assertIn("I.CHART_NO = :CHART_NO", normalized)
        for schema in ("exam", "xray"):
            self.assertIn("EXAMMAST.EXAMITEM", RADIOLOGY_DETAIL_SQL[schema]["items"].upper())

    def test_radiology_search_adds_names_category_and_state(self):
        calls = []
        service = make_scripted_service(calls, {
            "JOIN XRAY.PTEXAMITEM": (
                ("APPLY_NO", "UNIQUE_SEQ", "EXAM_CODE", "EXAM_SHORT_NAME", "EXAM_FULL_NAME"),
                [
                    ("A1" + " " * 18, "01", "C1", "Chest PA", "Chest PA erect position"),
                    ("A1" + " " * 18, "02", "C2", "KUB", None),
                ],
            ),
            "FROM XRAY.PTEXAMINDEX": (
                ("SOURCE_SCHEMA", "HOSPITAL_ID", "APPLY_NO", "ORDER_DATE", "EXAM_DATE", "REPORT_DATE"),
                [("XRAY", "000", "A1" + " " * 18, "1151001", "1151002", "0000000")],
            ),
        })

        rows = service.search_radiology(
            "12345", SearchWindow.from_dates(date(2026, 1, 1), date(2026, 10, 13))
        )

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["exam_names"], ["Chest PA erect position", "KUB"])
        self.assertEqual(rows[0]["exam_name"], "Chest PA erect position; KUB")
        self.assertEqual(rows[0]["category"], "radiology")
        self.assertEqual(rows[0]["state"], "examined")
        # EXAM returned no row, so its item-name statement is not run.
        self.assertEqual(len(calls), 3)

    def test_exam_state_treats_zero_dates_as_unset(self):
        self.assertEqual(exam_report_state({"report_date": "1151003"}), "reported")
        self.assertEqual(exam_report_state({"report_date": "0000000", "exam_date": "1151002"}), "examined")
        self.assertEqual(exam_report_state({"exam_date": "       ", "sch_date": "1151002"}), "scheduled")
        self.assertEqual(exam_report_state({"sch_date": None}), "ordered")

    def test_exam_state_marks_a_cancelled_order_only_when_the_exam_was_not_done(self):
        self.assertEqual(exam_report_state({"dc_flag": "Y", "sch_date": "1151002"}), "cancelled")
        self.assertEqual(exam_report_state({"dc_flag": "y ", "exam_date": "0000000", "report_date": "0000000"}), "cancelled")
        # In EXAM the flag is also set on exams that were done; the dates win.
        self.assertEqual(exam_report_state({"dc_flag": "Y", "exam_date": "1151002"}), "examined")
        self.assertEqual(exam_report_state({"dc_flag": "Y", "exam_date": "1151002", "report_date": "1151003"}), "reported")
        self.assertEqual(exam_report_state({"dc_flag": "N", "sch_date": "1151002"}), "scheduled")
        self.assertEqual(exam_report_state({"dc_flag": None}), "ordered")

    def test_exam_list_statements_select_the_cancel_flag_and_keep_cancelled_orders(self):
        statements = [*RADIOLOGY_SEARCH_SQL.values(), EXAM_ACCESSION_SEARCH_SQL, *ACCESSION_SEARCH_SQL.values()]
        self.assertEqual(len(statements), 5)
        for sql in statements:
            normalized = " ".join(sql.upper().split())
            self.assertIn("I.DC_FLAG,", normalized)
            self.assertNotIn("DC_FLAG =", normalized)
            self.assertNotIn("DC_FLAG <>", normalized)

    def test_report_sections_join_continuation_parts_without_a_separator(self):
        sections = group_report_sections([
            {"display_seq": 1, "seq": 1, "caption": "FINDING", "type": "F", "content": "second part"},
            {"display_seq": 1, "seq": 0, "caption": "FINDING", "type": "F", "content": "first part, "},
            {"display_seq": 0, "seq": 0, "caption": "PREMEDICATION", "type": "F", "content": "none\n"},
            {"display_seq": 2, "seq": 0, "caption": "", "type": "", "content": None},
        ])

        self.assertEqual([section["caption"] for section in sections], ["PREMEDICATION", "FINDING"])
        self.assertEqual(sections[0]["content"], "none")
        self.assertEqual(sections[1]["content"], "first part, second part")

    def test_exam_remarks_split_into_coded_diagnoses_and_free_text(self):
        clinical = summarize_exam_remarks([
            {"remark_type": "A", "seq": "01", "code": "K29.70", "context": "Gastritis"},
            {"remark_type": "D", "seq": "01", "code": "K29.70", "context": "Gastritis"},
            {"remark_type": "S", "seq": "01", "code": None, "context": "epigastric pain "},
            {"remark_type": "H", "seq": "01", "code": "", "context": ""},
        ])

        self.assertEqual(clinical["diagnoses"], [{"code": "K29.70", "text": "Gastritis"}])
        self.assertEqual(clinical["notes"], [{"type": "S", "text": "epigastric pain"}])

    def test_catalog_gives_each_workflow_a_plain_description(self):
        for item in workflow_catalog():
            with self.subTest(workflow=item["id"]):
                self.assertTrue(item["description"])
                for schema_word in ("PTEXAM", "LABX", "LABP", "IPTPROGRESS", "IPDINDEX", "_NO"):
                    self.assertNotIn(schema_word, item["description"].upper())
                    self.assertNotIn(schema_word, item["label"].upper())

    def test_catalog_distinguishes_confirmed_and_unknown_content_sources(self):
        catalog = {item["id"]: item for item in workflow_catalog()}

        self.assertEqual(catalog["radiology"]["implementation"], "available")
        self.assertEqual(catalog["exam_accession"]["implementation"], "available")
        self.assertEqual(catalog["exam_accession"]["source_scope"], "XRAY_only")
        self.assertEqual(catalog["laboratory"]["implementation"], "available")
        self.assertEqual(catalog["pathology"]["implementation"], "available")
        self.assertEqual(catalog["opd_note"]["implementation"], "available")
        self.assertEqual(catalog["opd_note"]["node"], "HO")
        self.assertEqual(catalog["admission"]["implementation"], "available")
        self.assertEqual(catalog["inpatient_note"]["implementation"], "available")
        self.assertEqual(catalog["inpatient_note"]["node"], "HI")
        self.assertNotIn("admission_note", catalog)
        self.assertEqual(catalog["discharge_summary"]["implementation"], "available")
        self.assertEqual(catalog["discharge_summary"]["node"], "HI")
        self.assertEqual(catalog["operation_note"]["implementation"], "available")
        self.assertEqual(catalog["operation_note"]["content_source"], "confirmed")
        self.assertEqual(catalog["opd_note"]["content_source"], "inferred")
        self.assertEqual([item["id"] for item in workflow_catalog() if item["implementation"] != "available"], [])


class AccessionSearchTests(unittest.TestCase):
    def test_accession_number_is_validated_and_upper_cased(self):
        self.assertEqual(normalize_accession_no(" 99900000001 "), "99900000001")
        self.assertEqual(normalize_accession_no("ct115100800"), "CT115100800")

        for invalid in ("", "   ", "115-1008", "A" * 21, "１１５"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                normalize_accession_no(invalid)

    def test_accession_query_uses_the_indexed_column_in_both_schemas(self):
        self.assertEqual(set(ACCESSION_SEARCH_SQL), {"EXAM", "XRAY"})
        for schema, sql in ACCESSION_SEARCH_SQL.items():
            normalized = " ".join(sql.upper().split())
            self.assertIn(f"FROM {schema}.PTEXAMINDEX I", normalized)
            self.assertIn("I.HOSPITAL_ID = :HOSPITAL_ID", normalized)
            self.assertIn("I.ACCESS_NO = :ACCESS_NO", normalized)
            self.assertIn("E.HOSPITAL_ID = I.HOSPITAL_ID", normalized)
            self.assertIn("E.APPLY_NO = I.APPLY_NO", normalized)
            self.assertIn("I.ACCESS_NO AS ACCESS_NO", normalized)
            self.assertIn("E.REF_NO AS REFERENCE_NO", normalized)
            # REF_NO has no index, and a function call would defeat the ACCESS_NO index.
            self.assertNotIn("REF_NO =", normalized)
            self.assertNotIn("TRIM(", normalized)
            self.assertNotIn("ORDER_DATE BETWEEN", normalized)

    def test_accession_search_binds_a_blank_padded_key_on_the_lab_node(self):
        calls = []
        service = make_scripted_service(calls)

        service.search_accession("ct115100800")

        self.assertEqual(len(calls), 2)
        for dsn, _sql, params in calls:
            self.assertIn("(HOST=10.0.0.1)", dsn)
            self.assertIn("(SID=he)", dsn)
            self.assertEqual(params["hospital_id"], "000")
            self.assertEqual(params["access_no"], "CT115100800" + " " * 9)

    def test_accession_search_marks_a_cancelled_order(self):
        service = make_scripted_service([], {
            "FROM XRAY.PTEXAMINDEX": (
                ("SOURCE_SCHEMA", "APPLY_NO", "SCH_DATE", "EXAM_DATE", "REPORT_DATE", "DC_FLAG"),
                [
                    ("XRAY", "A1", "1151002", "0000000", "0000000", "Y"),
                    ("XRAY", "A2", "1151002", "0000000", "0000000", "N"),
                ],
            ),
        })

        rows = service.search_accession("99900000001")

        self.assertEqual([row["state"] for row in rows], ["cancelled", "scheduled"])

    def test_accession_report_attaches_detail_sections_to_each_match(self):
        calls = []
        service = make_scripted_service(calls, {
            "FROM XRAY.PTEXAMINDEX": (
                ("SOURCE_SCHEMA", "HOSPITAL_ID", "APPLY_NO", "ACCESS_NO"),
                [("XRAY", "000", "A1" + " " * 18, "99900000001" + " " * 9)],
            ),
            "FROM XRAY.PTEXAMRPT": (("CAPTION", "CONTENT"), [("Findings", "Text")]),
        })

        rows = service.accession_report("99900000001")

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["access_no"], "99900000001")
        self.assertEqual(rows[0]["reports"], [{"caption": "Findings", "content": "Text"}])
        self.assertEqual(rows[0]["items"], [])
        detail_binds = [params for _dsn, sql, params in calls if "PTEXAMRPT" in sql]
        self.assertEqual(detail_binds[0]["apply_no"], "A1" + " " * 18)


class NodeRoutingTests(unittest.TestCase):
    def test_each_clinical_area_connects_to_its_own_node(self):
        config = QueryConfig(db_user="user", db_password="password")

        self.assertIn("(HOST=10.0.0.1)", config.connection_kwargs()["dsn"])
        patient = config.connection_kwargs(NODE_PATIENT)["dsn"]
        self.assertIn("(HOST=10.0.0.1)", patient)
        self.assertIn("(SID=ho)", patient)
        inpatient = config.connection_kwargs(NODE_INPATIENT)["dsn"]
        self.assertIn("(HOST=10.0.0.1)", inpatient)
        self.assertIn("(SID=hi)", inpatient)

        with self.assertRaises(ValueError):
            config.connection_kwargs("billing")

    def test_patient_query_runs_on_the_patient_node_with_the_full_key(self):
        normalized = " ".join(PATIENT_SQL.upper().split())
        self.assertIn("FROM CHART.CHART C", normalized)
        self.assertIn("C.HOSPITAL_ID = :HOSPITAL_ID", normalized)
        self.assertIn("C.CHART_NO = :CHART_NO", normalized)
        for withheld in ("ID_NO", "TEL_", "ADDRESS"):
            self.assertNotIn(withheld, normalized)

        calls = []
        service = make_scripted_service(calls, {
            "FROM CHART.CHART": (
                ("CHART_NO", "PT_NAME", "BIRTH_DATE"),
                [("0000012345", "TEST" + " " * 16, "+0650102")],
            ),
        })

        patient = service.patient_info("12345")

        self.assertIn("(SID=ho)", calls[0][0])
        self.assertEqual(calls[0][2], {"hospital_id": "000", "chart_no": "0000012345"})
        self.assertEqual(patient["pt_name"], "TEST")
        self.assertEqual(patient["birth_date"], "+0650102")
        self.assertEqual(patient["birth_date_iso"], "1976-01-02")

    def test_patient_info_is_none_when_the_chart_is_unknown(self):
        self.assertIsNone(make_scripted_service([]).patient_info("12345"))

    def test_signed_roc_birth_date_converts_only_the_confirmed_form(self):
        self.assertEqual(signed_roc_date_to_iso("+0650102"), "1976-01-02")
        self.assertEqual(signed_roc_date_to_iso("+1150229"), None)
        for unconfirmed in ("-0010102", "0650102", "", None, "+065010A"):
            with self.subTest(value=unconfirmed):
                self.assertIsNone(signed_roc_date_to_iso(unconfirmed))


class InpatientQueryTests(unittest.TestCase):
    WINDOW = SearchWindow.from_dates(date(2026, 1, 1), date(2026, 10, 13))

    def test_admission_query_overlaps_the_window_and_keeps_current_inpatients(self):
        normalized = " ".join(ADMISSION_SEARCH_SQL.upper().split())
        self.assertIn("FROM IPD.IPDINDEX A", normalized)
        self.assertIn("A.CHART_NO = :CHART_NO", normalized)
        self.assertIn("A.ADMIT_DATE <= :END_DATE", normalized)
        self.assertIn("A.DISCHARGE_DATE >= :START_DATE", normalized)
        self.assertIn("A.DISCHARGE_DATE = '0000000'", normalized)
        self.assertNotIn("HOSPITAL_ID", normalized)
        self.assertNotIn("TRIM(A.CHART_NO)", normalized)

    def test_inpatient_searches_run_on_the_inpatient_node_without_hospital_id(self):
        calls = []
        service = make_scripted_service(calls)

        service.search_admissions("12345", self.WINDOW)
        service.search_inpatient_notes("12345", self.WINDOW)

        self.assertEqual(len(calls), 2)
        for dsn, _sql, params in calls:
            self.assertIn("(HOST=10.0.0.1)", dsn)
            self.assertIn("(SID=hi)", dsn)
            self.assertEqual(params, {
                "chart_no": "0000012345",
                "start_date": "1150101",
                "end_date": "1151013",
            })

    def test_note_list_uses_the_chart_date_index_and_hides_deleted_notes(self):
        normalized = " ".join(INPATIENT_NOTE_SEARCH_SQL.upper().split())
        self.assertIn("FROM IDE.IPTPROGRESS1 N", normalized)
        self.assertIn("N.CHART_NO = :CHART_NO", normalized)
        self.assertIn("N.NOTE_DATE BETWEEN :START_DATE AND :END_DATE", normalized)
        self.assertIn("NVL(N.DELETED_DATE, 0) = 0", normalized)
        self.assertIn("IDE.PROGRESSNOTETYPE T", normalized)
        self.assertNotIn("IPTPROGRESS3T", normalized)

    def test_note_list_keeps_unsigned_notes_and_marks_them(self):
        normalized = " ".join(INPATIENT_NOTE_SEARCH_SQL.upper().split())
        self.assertIn("N.SIGNED_DATE,", normalized)
        self.assertNotIn("N.STATUS =", normalized)
        self.assertNotIn("SIGNED_DATE >", normalized)
        self.assertNotIn("SIGNED_DATE <>", normalized)

        service = make_scripted_service([], {
            "FROM IDE.IPTPROGRESS1": (
                ("NOTE_DATE", "STATUS", "SIGNED_DATE"),
                [("1151012", "S", 1151012), ("1151013", "C", 0), ("1151013", "I", None)],
            ),
        })

        rows = service.search_inpatient_notes("12345", self.WINDOW)

        self.assertEqual([row["state"] for row in rows], ["signed", "unsigned", "unsigned"])

    def test_note_state_comes_from_the_signature_date_not_the_status_code(self):
        self.assertEqual(inpatient_note_state({"signed_date": 1151012, "status": "C"}), "signed")
        self.assertEqual(inpatient_note_state({"signed_date": "1151012"}), "signed")
        self.assertEqual(inpatient_note_state({"signed_date": 0, "status": "S"}), "unsigned")
        self.assertEqual(inpatient_note_state({"signed_date": None}), "unsigned")
        self.assertEqual(inpatient_note_state({}), "unsigned")

    def test_note_body_query_binds_the_full_note_identity(self):
        normalized = " ".join(INPATIENT_NOTE_TEXT_SQL.upper().split())
        self.assertIn("FROM IDE.IPTPROGRESS3T S", normalized)
        self.assertIn("S.ADMIT_NO = :ADMIT_NO", normalized)
        self.assertIn("S.NOTE_DATE = :NOTE_DATE", normalized)
        self.assertIn("S.NOTE_TIME = :NOTE_TIME", normalized)
        self.assertNotIn("CHART_NO", normalized)

        calls = []
        service = make_scripted_service(calls)
        service.inpatient_note_detail("1150012345", "1151008", "0930")

        self.assertIn("(SID=hi)", calls[0][0])
        self.assertEqual(calls[0][2], {
            "admit_no": "1150012345", "note_date": "1151008", "note_time": "0930",
        })

    def test_note_detail_rejects_malformed_identity_parts(self):
        service = make_scripted_service([])
        for admit_no, note_date, note_time in (
            ("115001234", "1151008", "0930"),
            ("1150012345", "2026-10-08", "0930"),
            ("1150012345", "1151008", "930"),
            ("1150012345", "1151008", "09:3"),
        ):
            with self.subTest(note_time=note_time, note_date=note_date, admit_no=admit_no):
                with self.assertRaises(ValueError):
                    service.inpatient_note_detail(admit_no, note_date, note_time)

    def test_note_sections_join_split_rows_and_follow_soap_order(self):
        rows = [
            {"problem_no": "001", "section_type": "A", "seq": "0", "content": "assessment"},
            {"problem_no": "001", "section_type": "O", "seq": "1", "content": "second part"},
            {"problem_no": "001", "section_type": "O", "seq": "0", "content": "first part, "},
            {"problem_no": "001", "section_type": "P", "seq": "0", "content": "plan"},
            {"problem_no": "001", "section_type": "S", "seq": "0", "content": "subjective"},
            {"problem_no": "000", "section_type": "T", "seq": "0", "content": "free text\n"},
        ]

        sections = group_inpatient_note_sections(rows)

        self.assertEqual(
            [(item["problem_no"], item["section_type"]) for item in sections],
            [("000", "T"), ("001", "S"), ("001", "O"), ("001", "A"), ("001", "P")],
        )
        self.assertEqual(sections[2]["content"], "first part, second part")
        self.assertEqual(sections[1]["section_label"], "Subjective")
        self.assertIsNone(sections[0]["section_label"])
        self.assertEqual(sections[0]["content"], "free text")

    def test_note_body_keeps_whitespace_at_split_boundaries(self):
        calls = []
        service = make_scripted_service(calls, {
            "FROM IDE.IPTPROGRESS3T": (
                ("PROBLEM_NO", "SECTION_TYPE", "SEQ", "CONTENT"),
                [("001", "O", "0", "ends with a space "), ("001", "O", "1", "then continues")],
            ),
        })

        detail = service.inpatient_note_detail("1150012345", "1151008", "0930")

        self.assertEqual(detail["sections"][0]["content"], "ends with a space then continues")

    def test_oracle_rows_can_preserve_named_text_columns(self):
        description = [("SEQ",), ("CONTENT",)]
        rows = [("0 ", " padded text ")]

        self.assertEqual(
            oracle_rows(description, rows, preserve=("content",)),
            [{"seq": "0", "content": " padded text "}],
        )


class DischargeSummaryTests(unittest.TestCase):
    WINDOW = SearchWindow.from_dates(date(2026, 1, 1), date(2026, 10, 13))

    def test_summary_list_uses_the_chart_index_and_numeric_stay_dates(self):
        normalized = " ".join(DISCHARGE_SUMMARY_SEARCH_SQL.upper().split())
        self.assertIn("FROM DSR.DIAGDOCI H", normalized)
        self.assertIn("H.CHART_NO = :CHART_NO", normalized)
        self.assertIn("H.CREATED_DATE BETWEEN :START_DATE AND :END_DATE", normalized)
        self.assertIn("H.ADMIT_DATE <= :END_NUMBER", normalized)
        self.assertIn("H.DISCHARGE_DATE >= :START_NUMBER", normalized)
        self.assertIn("ORDER BY H.CREATED_DATE_C", normalized)
        self.assertNotIn("TRIM(H.CHART_NO)", normalized)
        self.assertNotIn("DIAGDOCIX", normalized)
        for withheld in ("ID_NO", "DIAGDOCLOG"):
            self.assertNotIn(withheld, normalized)

    def test_summary_text_query_binds_the_document_and_names_sections(self):
        normalized = " ".join(DISCHARGE_SUMMARY_TEXT_SQL.upper().split())
        self.assertIn("FROM DSR.DIAGDOCIX X", normalized)
        self.assertIn("X.DOCUMENT_NO = :DOCUMENT_NO", normalized)
        self.assertIn("S.DSR_TYPE = 'D'", normalized)
        self.assertIn("ORDER BY X.SECTION_NO, X.SEQ", normalized)
        self.assertNotIn("CHART_NO", normalized)

    def test_summary_search_runs_on_the_inpatient_node_with_text_and_number_dates(self):
        calls = []
        service = make_scripted_service(calls, {
            "FROM DSR.DIAGDOCI h": (
                ("DOCUMENT_NO", "ADMIT_DATE", "DISCHARGE_DATE", "CONFIRMED_DATE"),
                [("D000000001", 1150611, 0, "1150620"), ("D000000002", 990105, 990110, "0000000")],
            ),
        })

        rows = service.search_discharge_summaries("12345", self.WINDOW)

        dsn, _sql, params = calls[0]
        self.assertIn("(SID=hi)", dsn)
        self.assertEqual(params, {
            "chart_no": "0000012345", "start_date": "1150101", "end_date": "1151013",
            "start_number": 1150101, "end_number": 1151013,
        })
        self.assertEqual(rows[0]["admit_date"], "1150611")
        self.assertIsNone(rows[0]["discharge_date"])
        self.assertEqual(rows[0]["state"], "confirmed")
        self.assertEqual(rows[1]["admit_date"], "0990105")
        self.assertEqual(rows[1]["state"], "draft")

    def test_summary_detail_pads_the_document_key_and_joins_split_sections(self):
        calls = []
        service = make_scripted_service(calls, {
            "FROM DSR.DIAGDOCIX": (
                ("SECTION_NO", "SEQ", "CONTENT", "SECTION_NAME"),
                [
                    ("G", "002", "second part", "Course" + " " * 34),
                    ("G", "001", "first part,\r", "Course" + " " * 34),
                    ("A", "001", "admission diagnosis\r\n", "Admission diagnosis"),
                    ("H", "001", "   ", "Complications"),
                    ("Z", "001", "unnamed", None),
                ],
            ),
        })

        detail = service.discharge_summary_detail(" d0001 ")

        self.assertIn("(SID=hi)", calls[0][0])
        self.assertEqual(calls[0][2], {"document_no": "D0001" + " " * 5})
        self.assertEqual(
            [(s["section_no"], s["section_name"], s["content"]) for s in detail["sections"]],
            [
                ("A", "Admission diagnosis", "admission diagnosis"),
                ("G", "Course", "first part,\rsecond part"),
                ("Z", None, "unnamed"),
            ],
        )

    def test_document_number_is_validated(self):
        self.assertEqual(normalize_document_no(" d0001 "), "D0001")
        for invalid in ("", "D-0001", "D" * 11, "Ｄ１"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                normalize_document_no(invalid)

    def test_number_dates_become_seven_character_text(self):
        self.assertEqual(roc_number_to_text(1150611), "1150611")
        self.assertEqual(roc_number_to_text(990105), "0990105")
        self.assertIsNone(roc_number_to_text(0))
        self.assertIsNone(roc_number_to_text(None))


class OperationNoteTests(unittest.TestCase):
    def test_operation_query_follows_the_chart_index_and_the_full_report_key(self):
        normalized = " ".join(OPERATION_SEARCH_SQL.upper().split())
        self.assertIn("FROM ORMS.PTOR P", normalized)
        self.assertIn("LEFT JOIN ORMS.PTORDRPT R", normalized)
        self.assertIn("P.HOSPITAL_ID = :HOSPITAL_ID", normalized)
        self.assertIn("P.CHART_NO = :CHART_NO", normalized)
        self.assertIn("P.OR_DATE BETWEEN :START_DATE AND :END_DATE", normalized)
        for column in ("HOSPITAL_ID", "OR_DATE", "CHART_NO", "OR_DUPLICATE_NO"):
            self.assertIn(f"R.{column} = P.{column}", normalized)
        self.assertIn("R.OR_FINDINGS", normalized)
        self.assertNotIn("TRIM(P.CHART_NO)", normalized)
        # PTORDRPT has no chart-led index, so it is never filtered on its own.
        self.assertNotIn("WHERE R.", normalized)

    def test_operations_fold_procedure_rows_and_derive_a_state(self):
        base = {"hospital_id": "000", "chart_no": "0000012345", "or_duplicate_no": "1"}
        rows = [
            dict(base, or_date="1150910", status="3", or_in_date=1150910, cancel_date=0,
                 diagnosis_code="K35.80", diagnosis_english_name="Acute appendicitis",
                 diagnosis_code_2="K35.80", diagnosis_english_name_2="Acute appendicitis",
                 or_seq="0", or_code="P1", or_name="Appendectomy", or_findings="Findings text\n"),
            dict(base, or_date="1150910", status="3", or_in_date=1150910, cancel_date=0,
                 or_seq="1", or_code="P2", or_name="Drainage", or_findings=None),
            dict(base, or_date="1150801", status="2", or_in_date=0, cancel_date=1150801,
                 diagnosis_chinese_name="診斷", or_seq=None),
            dict(base, or_date="1150701", status="1", or_in_date=1150701, cancel_date=None, or_seq=None),
            dict(base, or_date="1151020", status="1", or_in_date=0, cancel_date=0, or_seq=None),
            dict(base, or_date="1050909", status="3", or_in_date=1050909, cancel_date=0,
                 or_seq="0", or_code="P3", or_name="Old procedure", or_findings="  "),
        ]

        operations = group_operations(rows)

        self.assertEqual(
            [operation["state"] for operation in operations],
            ["noted", "cancelled", "performed", "scheduled", "recorded"],
        )
        first = operations[0]
        self.assertEqual([procedure["or_name"] for procedure in first["procedures"]], ["Appendectomy", "Drainage"])
        self.assertEqual(first["note"], "Findings text")
        self.assertEqual(first["diagnoses"], [{"code": "K35.80", "name": "Acute appendicitis"}])
        self.assertEqual(operations[1]["diagnoses"], [{"code": "", "name": "診斷"}])
        self.assertEqual(operations[1]["cancel_date"], "1150801")
        self.assertEqual(operations[1]["procedures"], [])

    def test_operation_search_runs_on_the_inpatient_node_with_the_hospital_key(self):
        calls = []
        service = make_scripted_service(calls)

        result = service.search_operations(
            "12345", SearchWindow.from_dates(date(2026, 1, 1), date(2026, 10, 13))
        )

        self.assertEqual(result, [])
        dsn, _sql, params = calls[0]
        self.assertIn("(HOST=10.0.0.1)", dsn)
        self.assertEqual(params, {
            "hospital_id": "000", "chart_no": "0000012345",
            "start_date": "1150101", "end_date": "1151013",
        })


class OutpatientNoteTests(unittest.TestCase):
    TODAY = date(2026, 10, 13)

    def test_monthly_schema_follows_the_five_year_letter_cycle(self):
        self.assertEqual(outpatient_month_schema(111, 1), "OHIS01")
        self.assertEqual(outpatient_month_schema(112, 12), "OHISB12")
        self.assertEqual(outpatient_month_schema(113, 6), "OHISC06")
        self.assertEqual(outpatient_month_schema(114, 3), "OHISD03")
        self.assertEqual(outpatient_month_schema(115, 9), "OHISE09")
        # The cycle wraps: 110 shares a letter with 115, and 116 with 111.
        self.assertEqual(outpatient_month_schema(110, 11), "OHISE11")
        self.assertEqual(outpatient_month_schema(116, 1), "OHIS01")
        with self.assertRaises(ValueError):
            outpatient_month_schema(115, 13)

    def test_schema_list_covers_the_window_newest_first_with_the_live_schema(self):
        window = SearchWindow.from_dates(date(2026, 8, 20), date(2026, 10, 13))
        self.assertEqual(outpatient_schemas(window, self.TODAY), ["OPD", "OHISE10", "OHISE09", "OHISE08"])

        across_years = SearchWindow.from_dates(date(2025, 11, 30), date(2026, 2, 1))
        self.assertEqual(
            outpatient_schemas(across_years, self.TODAY),
            ["OPD", "OHISE02", "OHISE01", "OHISD12", "OHISD11"],
        )

    def test_schema_list_stops_at_the_sixty_months_that_are_kept(self):
        ten_years = SearchWindow.from_dates(date(2016, 10, 14), self.TODAY)
        schemas = outpatient_schemas(ten_years, self.TODAY)

        self.assertEqual(len(schemas), 61)
        self.assertEqual(len(set(schemas)), 61)
        self.assertEqual(set(schemas), set(OUTPATIENT_SCHEMAS))
        # The oldest kept month is 60 months back: November of ROC year 110.
        self.assertEqual(schemas[-1], "OHISE11")

        before_the_window = SearchWindow.from_dates(date(2018, 1, 1), date(2019, 1, 1))
        self.assertEqual(outpatient_schemas(before_the_window, self.TODAY), ["OPD"])

        future_end = SearchWindow.from_dates(date(2026, 10, 1), date(2026, 12, 31))
        self.assertEqual(outpatient_schemas(future_end, self.TODAY), ["OPD", "OHISE10"])

    def test_statement_takes_its_schema_from_the_fixed_list_only(self):
        normalized = " ".join(outpatient_note_sql("OHISE09").upper().split())
        self.assertIn("FROM OHISE09.PTOPD P", normalized)
        self.assertIn("LEFT JOIN OHISE09.ORDSOOPD O", normalized)
        self.assertIn("P.HOSPITAL_ID = :HOSPITAL_ID", normalized)
        self.assertIn("P.CHART_NO = :CHART_NO", normalized)
        # A schema is reused after five years, so the date range is always present.
        self.assertIn("P.CLINIC_DATE BETWEEN :START_DATE AND :END_DATE", normalized)
        for column in ("HOSPITAL_ID", "CHART_NO", "CLINIC_DATE", "DUPLICATE_NO"):
            self.assertIn(f"O.{column} = P.{column}", normalized)
        self.assertIn("M.HOSPITAL_ID = P.HOSPITAL_ID", normalized)
        self.assertNotIn("TRIM(P.CHART_NO)", normalized)
        for withheld in ("PT_NAME", "ID_NO", "BIRTH_DATE"):
            self.assertNotIn(withheld, normalized)
        self.assertIn("FROM OPD.PTOPD P", " ".join(outpatient_note_sql("OPD").upper().split()))

        for unsafe in ("OHISE13", "OHISF01", "opd", "OPD; DROP TABLE X", "MAST", ""):
            with self.subTest(schema=unsafe), self.assertRaises(ValueError):
                outpatient_note_sql(unsafe)

    def test_visits_fold_note_rows_in_reading_order(self):
        base = {"hospital_id": "000", "chart_no": "0000012345"}
        rows = [
            dict(base, source_schema="OHISE09", clinic_date="1150910", duplicate_no="1", clinic_flag="O",
                 div_name="Cardiology", doctor_name="Dr A", so_type="O", sub_type="", content="objective text "),
            dict(base, source_schema="OHISE09", clinic_date="1150910", duplicate_no="1", clinic_flag="O",
                 so_type="S", sub_type="", content="subjective text"),
            dict(base, source_schema="OHISE09", clinic_date="1150910", duplicate_no="1", clinic_flag="O",
                 so_type="C", sub_type="", content="other text"),
            dict(base, source_schema="OHISE08", clinic_date="1150801", duplicate_no="1", clinic_flag="O",
                 so_type=None, sub_type=None, content=None),
            dict(base, source_schema="OPD", clinic_date="1151012", duplicate_no="2", clinic_flag="E",
                 so_type="O", sub_type="AB", content="abdomen"),
            dict(base, source_schema="OPD", clinic_date="1151012", duplicate_no="2", clinic_flag="E",
                 so_type="S", sub_type="PI", content="illness"),
            dict(base, source_schema="OPD", clinic_date="1151012", duplicate_no="2", clinic_flag="E",
                 so_type="O", sub_type="VS", content="vitals"),
            dict(base, source_schema="OPD", clinic_date="1151012", duplicate_no="2", clinic_flag="E",
                 so_type="S", sub_type="CC", content="complaint"),
            dict(base, source_schema="OPD", clinic_date="1151012", duplicate_no="2", clinic_flag="E",
                 so_type="S", sub_type="ZZ", content="unknown part"),
            dict(base, source_schema="OPD", clinic_date="1151012", duplicate_no="2", clinic_flag="E",
                 so_type="S", sub_type="", content="   "),
        ]

        visits = group_outpatient_visits(rows)

        self.assertEqual([visit["clinic_date"] for visit in visits], ["1151012", "1150910", "1150801"])
        self.assertEqual([visit["kind"] for visit in visits], ["emergency", "outpatient", "outpatient"])
        self.assertEqual([visit["has_note"] for visit in visits], [True, True, False])
        self.assertEqual(
            [(s["so_type"], s["sub_type"], s["label"]) for s in visits[0]["sections"]],
            [
                ("S", "CC", "Chief complaint"), ("S", "PI", "Present illness"), ("S", "ZZ", None),
                ("O", "VS", "Vital signs"), ("O", "AB", "Abdomen"),
            ],
        )
        self.assertEqual(visits[0]["sections"][0]["group"], "Subjective")
        self.assertEqual(
            [(s["label"], s["content"]) for s in visits[1]["sections"]],
            [("Subjective", "subjective text"), ("Objective", "objective text"), (None, "other text")],
        )
        self.assertEqual(visits[1]["div_name"], "Cardiology")
        self.assertEqual(visits[2]["sections"], [])

    def test_search_reads_every_schema_on_one_patient_node_connection(self):
        connections, statements = [], []

        class Cursor:
            description = []

            def execute(self, sql, params):
                statements.append((sql, params))

            def fetchall(self):
                return []

            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

        class Connection:
            def __init__(self, dsn):
                connections.append(dsn)

            def cursor(self):
                return Cursor()

            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

        service = HisQueryService(
            config=QueryConfig(db_user="user", db_password="password", hospital_id="000"),
            connect=lambda **kwargs: Connection(kwargs["dsn"]),
        )
        window = SearchWindow.from_dates(date(2026, 8, 20), date(2026, 10, 13))

        self.assertEqual(service.search_outpatient_notes("12345", window, today=self.TODAY), [])

        self.assertEqual(len(connections), 1)
        self.assertIn("(HOST=10.0.0.1)", connections[0])
        self.assertIn("(SID=ho)", connections[0])
        self.assertEqual(len(statements), 4)
        for schema, (sql, params) in zip(("OPD", "OHISE10", "OHISE09", "OHISE08"), statements):
            self.assertIn(f"FROM {schema}.PTOPD p", sql)
            self.assertEqual(params, {
                "hospital_id": "000", "chart_no": "0000012345",
                "start_date": "1150820", "end_date": "1151013",
            })


if __name__ == "__main__":
    unittest.main()
