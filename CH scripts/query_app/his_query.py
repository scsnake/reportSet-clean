"""Confirmed HIS workflow queries used by the FastAPI application.

The SQL in this module follows the identities observed in the 2026-08-28
workflow captures.  All user values are binds; schema names are fixed constants.

The accession, patient, admission, and inpatient-note queries follow keys and
indexes read from the data dictionary on 2026-10-13
(analysis/HIS_DB_TABLE_NOTES_20261013.md).
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping, Sequence

import oracledb


RADIOLOGY_SEARCH_SQL = {
    schema: f"""
        SELECT
            '{schema}' AS source_schema,
            i.HOSPITAL_ID,
            i.APPLY_NO,
            i.CHART_NO,
            i.ORDER_DATE,
            i.ORDER_TIME,
            i.EXAM_DATE,
            i.EXAM_TIME,
            i.REPORT_DATE,
            i.REPORT_TIME,
            i.SCH_DATE,
            i.STATUS,
            i.DC_FLAG,
            i.MODALITY,
            i.EXAM_TYPE,
            t.EXAM_DESCRIPTION AS EXAM_TYPE_NAME,
            i.ACCESS_NO AS ACCESS_NO,
            e.REF_NO,
            e.RESULT,
            e.REPORT_TYPE,
            e.EXCERPT
        FROM {schema}.PTEXAMINDEX i
        JOIN {schema}.PTEXAM e
          ON e.HOSPITAL_ID = i.HOSPITAL_ID
         AND e.APPLY_NO = i.APPLY_NO
        LEFT JOIN EXAMMAST.EXAMTYPE t
          ON t.EXAM_TYPE = i.EXAM_TYPE
        WHERE i.HOSPITAL_ID = :hospital_id
          AND i.CHART_NO = :chart_no
          AND i.ORDER_DATE BETWEEN :start_date AND :end_date
        ORDER BY i.ORDER_DATE DESC, i.ORDER_TIME DESC, i.APPLY_NO DESC
    """
    for schema in ("EXAM", "XRAY")
}


# Exam item names for every exam of one chart search.  PK_EXAMITEM is
# (EXAM_CODE, EXAM_TYPE); the same master serves both schemas.
EXAM_ITEM_NAME_SQL = {
    schema: f"""
        SELECT
            x.APPLY_NO,
            x.UNIQUE_SEQ,
            x.EXAM_CODE,
            m.EXAM_SHORT_NAME,
            m.EXAM_FULL_NAME
        FROM {schema}.PTEXAMINDEX i
        JOIN {schema}.PTEXAMITEM x
          ON x.HOSPITAL_ID = i.HOSPITAL_ID
         AND x.APPLY_NO = i.APPLY_NO
        LEFT JOIN EXAMMAST.EXAMITEM m
          ON m.EXAM_CODE = x.EXAM_CODE
         AND m.EXAM_TYPE = x.EXAM_TYPE
        WHERE i.HOSPITAL_ID = :hospital_id
          AND i.CHART_NO = :chart_no
          AND i.ORDER_DATE BETWEEN :start_date AND :end_date
        ORDER BY x.APPLY_NO, x.UNIQUE_SEQ
    """
    for schema in ("EXAM", "XRAY")
}


EXAM_ACCESSION_SEARCH_SQL = """
    SELECT
        'XRAY' AS SOURCE_SCHEMA,
        i.HOSPITAL_ID,
        i.APPLY_NO,
        i.CHART_NO,
        i.ORDER_DATE,
        i.ORDER_TIME,
        i.SCH_DATE,
        i.SCH_TIME,
        i.EXAM_DATE,
        i.EXAM_TIME,
        i.REPORT_DATE,
        i.REPORT_TIME,
        i.STATUS,
        i.DC_FLAG,
        i.EXAM_TYPE,
        t.EXAM_DESCRIPTION AS EXAM_TYPE_NAME,
        i.MODALITY,
        i.ACCESS_NO AS ACCESS_NO,
        i.FINISH_FLAG,
        e.REF_NO AS REFERENCE_NO,
        e.RESULT,
        e.REPORT_TYPE,
        e.EXCERPT
    FROM XRAY.PTEXAMINDEX i
    JOIN XRAY.PTEXAM e
      ON e.HOSPITAL_ID = i.HOSPITAL_ID
     AND e.APPLY_NO = i.APPLY_NO
    LEFT JOIN EXAMMAST.EXAMTYPE t
      ON t.EXAM_TYPE = i.EXAM_TYPE
    WHERE i.HOSPITAL_ID = :hospital_id
      AND i.CHART_NO = :chart_no
      AND i.ORDER_DATE >= :start_date
      AND i.ORDER_DATE <= :end_date
    ORDER BY i.HOSPITAL_ID, i.CHART_NO, i.ORDER_DATE DESC,
             i.ORDER_TIME DESC, i.APPLY_NO DESC
"""


EXAM_ACCESSION_DETAIL_SQL = """
    SELECT
        i.HOSPITAL_ID,
        i.APPLY_NO,
        i.UNIQUE_SEQ,
        i.EXAM_TYPE,
        i.EXAM_CODE,
        m.EXAM_SHORT_NAME,
        m.EXAM_FULL_NAME,
        i.PRICE_CODE,
        i.COMPLETE_FLAG,
        i.ORDER_COMMENT,
        i.POSITION,
        i.POSITION_CODES,
        i.SIDE_CODE,
        i.TOTAL_QTY,
        i.EXECUTE_LOCATION,
        i.QUALITY,
        i.IMAGE_COUNT,
        i.ACCESS_NO AS ITEM_ACCESS_NO,
        m.OPD_MODALITY,
        m.IPD_MODALITY,
        m.ER_MODALITY,
        m.SCHEDULE_REMIND
    FROM XRAY.PTEXAMITEM i
    LEFT JOIN EXAMMAST.EXAMITEM m
      ON m.EXAM_CODE = i.EXAM_CODE
     AND m.EXAM_TYPE = i.EXAM_TYPE
    WHERE i.HOSPITAL_ID = :hospital_id
      AND i.APPLY_NO = :apply_no
    ORDER BY i.UNIQUE_SEQ
"""


# Laboratory results, node HE.  Four schema families hold the same two tables:
# LAB (current results), LABHIS (results up to about 2021-04), LAM
# (microbiology), and LAMHIS (microbiology history).  Their order sets do not
# overlap.  The test name comes from LABITEM1 by the item's LAB_CODE: the CODE
# column is blank on more than half of the item rows, so a join on CODE leaves
# those rows without a name.  The date filter is LAB_ORDER_DATE, which is set
# on every order; ORDER_DATE is '0000000' on about 9 of 10 orders.
LAB_SCHEMAS = ("LAB", "LABHIS", "LAM", "LAMHIS")
MICROBIOLOGY_SCHEMAS = ("LAM", "LAMHIS")

LAB_SEARCH_SQL_TEMPLATE = """
    SELECT
        '{schema}' AS SOURCE_SCHEMA,
        x1.HOSPITAL_ID,
        x1.LAB_NO,
        x1.LAB_ORDER_DATE AS ORDER_DATE,
        x1.LAB_ORDER_TIME,
        x1.REPORT_DATE,
        x1.REPORT_TIME,
        x1.CONFIRMED_DATE,
        x1.SPECIMEN_CODE,
        sp.SPECIMEN_NAME,
        COALESCE(x2.LAB_GROUP_CODE, x1.LAB_GROUP_CODE) AS CATEGORY_CODE,
        lg.LAB_GROUP_NAME AS CATEGORY_NAME,
        x1.LAB_STATUS,
        x1.DIAGNOSIS_DESCRIPTION,
        x2.UNIQUE_SEQ,
        x2.CODE,
        x2.LAB_CODE,
        m1.LAB_NAME,
        COALESCE(x2.UNIT, m1.UNIT) AS UNIT,
        x2.RESULT_DESCRIPTION,
        x2.RESULT_CONDITION,
        x2.LOWER_LIMIT,
        x2.UPPER_LIMIT,
        x2.RESULT_REMARK
    FROM {schema}.LABX1 x1
    JOIN {schema}.LABX2 x2
      ON x2.HOSPITAL_ID = x1.HOSPITAL_ID
     AND x2.LAB_NO = x1.LAB_NO
    LEFT JOIN LABMAST.LABITEM1 m1
      ON m1.LAB_CODE = x2.LAB_CODE
     AND m1.SPECIMEN_CODE = x2.SPECIMEN_CODE
    LEFT JOIN LABMAST.SPECIMEN sp
      ON sp.SPECIMEN_CODE = x1.SPECIMEN_CODE
    LEFT JOIN LABMAST.LABGROUP lg
      ON lg.LAB_GROUP_CODE = COALESCE(x2.LAB_GROUP_CODE, x1.LAB_GROUP_CODE)
    WHERE x1.HOSPITAL_ID = :hospital_id
      AND x1.CHART_NO = :chart_no
      AND x1.LAB_ORDER_DATE BETWEEN :start_date AND :end_date
    ORDER BY x1.LAB_ORDER_DATE DESC, x1.LAB_ORDER_TIME DESC,
             x1.LAB_NO DESC, x2.UNIQUE_SEQ
"""

LAB_SEARCH_SQL = LAB_SEARCH_SQL_TEMPLATE.format(schema="LAB")


# Organisms and susceptibility, microbiology families only.  LABM has one row
# per organism of an item (key adds GERM_SEQ + GERM_CODE) with up to 20 drug
# sets: MED_CODE_n (antibiotic), RSMI_n (S, I, or R), RSMI_RESULT_n (value).
MICROBIOLOGY_DRUG_SETS = 20
MICROBIOLOGY_ORGANISM_SQL_TEMPLATE = (
    """
    SELECT
        m.LAB_NO,
        m.UNIQUE_SEQ,
        m.LAB_CODE,
        m.GERM_SEQ,
        m.GERM_CODE,
        g.GERM_NAME,
        m.COLONY_COUNT,
        m.UNIT,
        m.DRUG_RESISTANT_TYPE,
        m.DRUG_RESISTANT_ALERT_MSG,
        """
    + ",\n        ".join(
        f"m.MED_CODE_{index}, m.RSMI_{index}, m.RSMI_RESULT_{index}"
        for index in range(1, MICROBIOLOGY_DRUG_SETS + 1)
    )
    + """
    FROM {schema}.LABX1 x1
    JOIN {schema}.LABM m
      ON m.HOSPITAL_ID = x1.HOSPITAL_ID
     AND m.LAB_NO = x1.LAB_NO
    LEFT JOIN LABMAST.GERM g
      ON g.GERM_CODE = m.GERM_CODE
    WHERE x1.HOSPITAL_ID = :hospital_id
      AND x1.CHART_NO = :chart_no
      AND x1.LAB_ORDER_DATE BETWEEN :start_date AND :end_date
    ORDER BY m.LAB_NO, m.UNIQUE_SEQ, m.GERM_SEQ
"""
)

ANTIBIOTIC_NAME_SQL = """
    SELECT ANTIBIOTIC_CODE, ANTIBIOTIC_NAME, SHORT_NAME
    FROM LABMAST.ANTIBIOTIC
"""


# Pathology and cytology, node HE.  LAP.LABP1 is the order header for three
# report families (PATHOLOGY_TYPE): S surgical pathology, N non-gynecologic
# cytology, G gynecologic cytology.  Each family keeps its text in another
# table, so the search runs one header query and one text query per family.
# The date filter is LAB_ORDER_DATE: ORDER_DATE is unset on every gynecologic
# order and on many others.
PATHOLOGY_SEARCH_SQL = """
    SELECT
        p1.HOSPITAL_ID,
        p1.LAB_NO,
        p1.PATHOLOGY_NO,
        p1.PATHOLOGY_TYPE,
        p1.LAB_ORDER_DATE AS ORDER_DATE,
        p1.RECEIVE_DATE,
        p1.REPORT_DATE,
        p1.CONFIRMED_DATE,
        p1.SPECIMEN_CODE,
        sp.SPECIMEN_NAME,
        p1.SPECIMEN_CONTENT,
        p1.DIAGNOSIS_DESCRIPTION,
        p1.DELETE_FLAG
    FROM LAP.LABP1 p1
    LEFT JOIN LABMAST.SPECIMEN sp
      ON sp.SPECIMEN_CODE = p1.SPECIMEN_CODE
    WHERE p1.HOSPITAL_ID = :hospital_id
      AND p1.CHART_NO = :chart_no
      AND p1.LAB_ORDER_DATE BETWEEN :start_date AND :end_date
    ORDER BY p1.LAB_ORDER_DATE DESC, p1.LAB_NO DESC
"""


# Surgical pathology text.  PK_LABS2 is (LAB_NO, UNIQUE_SEQ, REPORT_TYPE):
# UNIQUE_SEQ is the specimen part and REPORT_TYPE is the section.
PATHOLOGY_SURGICAL_SQL = """
    SELECT
        s2.LAB_NO,
        s2.UNIQUE_SEQ,
        s2.REPORT_TYPE,
        s2.REPORT_DESCRIPTION
    FROM LAP.LABP1 p1
    JOIN LAP.LABS2 s2
      ON s2.HOSPITAL_ID = p1.HOSPITAL_ID
     AND s2.LAB_NO = p1.LAB_NO
    WHERE p1.HOSPITAL_ID = :hospital_id
      AND p1.CHART_NO = :chart_no
      AND p1.LAB_ORDER_DATE BETWEEN :start_date AND :end_date
    ORDER BY s2.LAB_NO, s2.UNIQUE_SEQ, s2.REPORT_TYPE
"""


# Non-gynecologic cytology text.  PK_LABN is (LAB_NO, UNIQUE_SEQ).
PATHOLOGY_CYTOLOGY_SQL = """
    SELECT
        n.LAB_NO,
        n.UNIQUE_SEQ,
        n.SPECIMEN_CONTENT,
        n.GROSS_APPEARANCE,
        n.RESULT_DESCRIPTION,
        n.LAB_COMMENT
    FROM LAP.LABP1 p1
    JOIN LAP.LABN n
      ON n.HOSPITAL_ID = p1.HOSPITAL_ID
     AND n.LAB_NO = p1.LAB_NO
    WHERE p1.HOSPITAL_ID = :hospital_id
      AND p1.CHART_NO = :chart_no
      AND p1.LAB_ORDER_DATE BETWEEN :start_date AND :end_date
    ORDER BY n.LAB_NO, n.UNIQUE_SEQ
"""


# Gynecologic cytology.  The result is stored as codes; the text columns are
# usually blank.  Telephone and address columns of LAP.LABG are not selected.
PATHOLOGY_GYN_SQL = """
    SELECT
        g.LAB_NO,
        g.UNIQUE_SEQ,
        g.RESULT_CODE,
        g.RESULT_DESCRIPTION,
        g.SUGGEST_CODE,
        g.SUGGEST_DESCRIPTION,
        g.LAB_COMMENT
    FROM LAP.LABP1 p1
    JOIN LAP.LABG g
      ON g.HOSPITAL_ID = p1.HOSPITAL_ID
     AND g.LAB_NO = p1.LAB_NO
    WHERE p1.HOSPITAL_ID = :hospital_id
      AND p1.CHART_NO = :chart_no
      AND p1.LAB_ORDER_DATE BETWEEN :start_date AND :end_date
    ORDER BY g.LAB_NO, g.UNIQUE_SEQ
"""


RADIOLOGY_DETAIL_SQL = {
    "exam": {
        "items": """
            SELECT x.UNIQUE_SEQ, x.EXAM_CODE, x.EXAM_TYPE,
                   m.EXAM_SHORT_NAME, m.EXAM_FULL_NAME,
                   x.POSITION, x.SIDE_CODE, x.ORDER_COMMENT, x.ACCESS_NO
            FROM EXAM.PTEXAMITEM x
            LEFT JOIN EXAMMAST.EXAMITEM m
              ON m.EXAM_CODE = x.EXAM_CODE
             AND m.EXAM_TYPE = x.EXAM_TYPE
            WHERE x.HOSPITAL_ID = :hospital_id AND x.APPLY_NO = :apply_no
            ORDER BY x.UNIQUE_SEQ
        """,
        "remarks": """
            SELECT REMARK_TYPE, SEQ, CODE, CONTEXT
            FROM EXAM.PTEXAMREMARK
            WHERE HOSPITAL_ID = :hospital_id AND APPLY_NO = :apply_no
            ORDER BY REMARK_TYPE, SEQ
        """,
        "reports": """
            SELECT DISPLAY_SEQ, SEQ, CAPTION, SECTION_MODE, TYPE, CONTENT
            FROM EXAM.PTEXAMRPT
            WHERE HOSPITAL_ID = :hospital_id AND APPLY_NO = :apply_no
            ORDER BY DISPLAY_SEQ, SEQ
        """,
    },
    "xray": {
        "items": """
            SELECT x.UNIQUE_SEQ, x.EXAM_CODE, x.EXAM_TYPE,
                   m.EXAM_SHORT_NAME, m.EXAM_FULL_NAME,
                   x.POSITION, x.SIDE_CODE, x.ORDER_COMMENT, x.ACCESS_NO
            FROM XRAY.PTEXAMITEM x
            LEFT JOIN EXAMMAST.EXAMITEM m
              ON m.EXAM_CODE = x.EXAM_CODE
             AND m.EXAM_TYPE = x.EXAM_TYPE
            WHERE x.HOSPITAL_ID = :hospital_id AND x.APPLY_NO = :apply_no
            ORDER BY x.UNIQUE_SEQ
        """,
        "remarks": """
            SELECT REMARK_TYPE, SEQ, CODE, CONTEXT
            FROM XRAY.PTEXAMREMARK
            WHERE HOSPITAL_ID = :hospital_id AND APPLY_NO = :apply_no
            ORDER BY REMARK_TYPE, SEQ
        """,
        "reports": """
            SELECT DISPLAY_SEQ, SEQ, CAPTION, SECTION_MODE, TYPE, CONTENT
            FROM XRAY.PTEXAMRPT
            WHERE HOSPITAL_ID = :hospital_id AND APPLY_NO = :apply_no
            ORDER BY DISPLAY_SEQ, SEQ
        """,
    },
}


RADIOLOGY_DETAIL_APPLY_NO_WIDTH = {
    "exam": {"items": 20, "remarks": 15, "reports": 20},
    "xray": {"items": 20, "remarks": 20, "reports": 20},
}


# Direct lookup by accession number.  ACCESS_NO is indexed in both schemas
# (EXAM: AK_PTEXAMINDEX_ACCESS_NO, XRAY: AK_PTEXAMINDEX_ACC hospitalID), so no
# date window is needed.  PTEXAM.REF_NO has no index and is never filtered on.
ACCESSION_SEARCH_SQL = {
    schema: f"""
        SELECT
            '{schema}' AS source_schema,
            i.HOSPITAL_ID,
            i.APPLY_NO,
            i.CHART_NO,
            i.ORDER_DATE,
            i.ORDER_TIME,
            i.SCH_DATE,
            i.SCH_TIME,
            i.EXAM_DATE,
            i.EXAM_TIME,
            i.REPORT_DATE,
            i.REPORT_TIME,
            i.STATUS,
            i.DC_FLAG,
            i.EXAM_TYPE,
            t.EXAM_DESCRIPTION AS EXAM_TYPE_NAME,
            i.MODALITY,
            i.ACCESS_NO AS ACCESS_NO,
            e.REF_NO AS REFERENCE_NO,
            e.RESULT,
            e.REPORT_TYPE
        FROM {schema}.PTEXAMINDEX i
        JOIN {schema}.PTEXAM e
          ON e.HOSPITAL_ID = i.HOSPITAL_ID
         AND e.APPLY_NO = i.APPLY_NO
        LEFT JOIN EXAMMAST.EXAMTYPE t
          ON t.EXAM_TYPE = i.EXAM_TYPE
        WHERE i.HOSPITAL_ID = :hospital_id
          AND i.ACCESS_NO = :access_no
        ORDER BY i.ORDER_DATE DESC, i.ORDER_TIME DESC, i.APPLY_NO DESC
    """
    for schema in ("EXAM", "XRAY")
}


# Patient master, node HO.  Only the fields a report-reading banner needs;
# national ID, telephone, and address columns are deliberately not selected.
PATIENT_SQL = """
    SELECT
        c.HOSPITAL_ID,
        c.CHART_NO,
        c.PT_NAME,
        c.BIRTH_DATE,
        c.SEX,
        c.BLOOD_TYPE,
        c.PT_TYPE,
        c.LAST_OPD_DATE,
        c.LAST_ADMIT_DATE,
        c.LAST_DISCHARGE_DATE
    FROM CHART.CHART c
    WHERE c.HOSPITAL_ID = :hospital_id
      AND c.CHART_NO = :chart_no
"""


# Admission index, node HI.  The HI inpatient tables have no HOSPITAL_ID.
# An admission still in hospital stores DISCHARGE_DATE as '0000000', so the
# window test is an overlap test, not a plain BETWEEN on one date.
ADMISSION_SEARCH_SQL = """
    SELECT
        a.CHART_NO,
        a.ADMIT_NO,
        a.CUT_NO,
        a.STATUS,
        a.ADMIT_DATE,
        a.ADMIT_TIME,
        a.DISCHARGE_DATE,
        a.DISCHARGE_TIME
    FROM IPD.IPDINDEX a
    WHERE a.CHART_NO = :chart_no
      AND a.ADMIT_DATE <= :end_date
      AND (a.DISCHARGE_DATE >= :start_date
           OR a.DISCHARGE_DATE = '0000000'
           OR a.DISCHARGE_DATE IS NULL)
    ORDER BY a.ADMIT_DATE DESC, a.ADMIT_TIME DESC, a.CUT_NO
"""


# Inpatient note headers, node HI.  AK_IPTPROGRESS1_8_CHART_NO covers
# (CHART_NO, NOTE_DATE, NOTE_TIME).  DELETED_DATE is 0 for a live note.
# Unsigned notes (SIGNED_DATE = 0) are kept; the screen marks them.
INPATIENT_NOTE_SEARCH_SQL = """
    SELECT
        n.CHART_NO,
        n.ADMIT_NO,
        n.NOTE_DATE,
        n.NOTE_TIME,
        n.NOTE_TYPE,
        t.TYPE_DESC AS NOTE_TYPE_NAME,
        n.REMARK,
        n.STATUS,
        n.DIV_NO,
        n.NOTE_CLERK,
        n.SIGNED_DATE,
        n.SIGNED_TIME,
        n.SIGNED_DOCTOR_NO
    FROM IDE.IPTPROGRESS1 n
    LEFT JOIN IDE.PROGRESSNOTETYPE t
      ON t.NOTE_TYPE = n.NOTE_TYPE
    WHERE n.CHART_NO = :chart_no
      AND n.NOTE_DATE BETWEEN :start_date AND :end_date
      AND NVL(n.DELETED_DATE, 0) = 0
    ORDER BY n.NOTE_DATE DESC, n.NOTE_TIME DESC
"""


# Inpatient note body, node HI.  IDE.IPTPROGRESS3T holds 13.5M rows; always
# bind the full note identity, which is the leading part of PK_IPTPROGRESS3T.
INPATIENT_NOTE_TEXT_SQL = """
    SELECT
        s.PROBLEM_NO,
        s.SECTION_TYPE,
        s.SEQ,
        s.CONTENT
    FROM IDE.IPTPROGRESS3T s
    WHERE s.ADMIT_NO = :admit_no
      AND s.NOTE_DATE = :note_date
      AND s.NOTE_TIME = :note_time
    ORDER BY s.PROBLEM_NO, s.SECTION_TYPE, s.SEQ
"""


# Discharge summary documents, node HI.  DSR.DIAGDOCI is the header; index
# AK_DIAGDOCI_2_CHART_NO covers (CHART_NO, CREATED_DATE_C), and CREATED_DATE_C
# is the complement of the created date, so ascending order is newest first.
# ADMIT_DATE and DISCHARGE_DATE are NUMBER(7) here, so they take numeric binds.
# A document is listed when its stay overlaps the window or it was written in it.
DISCHARGE_SUMMARY_SEARCH_SQL = """
    SELECT
        h.DOCUMENT_NO,
        h.CHART_NO,
        h.ADMIT_NO,
        h.CUT_NO,
        h.ADMIT_DATE,
        h.DISCHARGE_DATE,
        h.CREATED_DATE,
        h.CONFIRMED_DATE,
        h.STATUS,
        h.COMPLETE_FLAG,
        h.WORK_DIV_NAME,
        h.DIV_NO,
        h.VS_NO,
        h.BED_NO
    FROM DSR.DIAGDOCI h
    WHERE h.CHART_NO = :chart_no
      AND (h.CREATED_DATE BETWEEN :start_date AND :end_date
           OR (h.ADMIT_DATE <= :end_number
               AND (h.DISCHARGE_DATE >= :start_number
                    OR NVL(h.DISCHARGE_DATE, 0) = 0)))
    ORDER BY h.CREATED_DATE_C
"""


# Discharge summary text, node HI.  PK_DIAGDOCIX is (DOCUMENT_NO, SECTION_NO,
# SEQ).  DSR.DSRSECTION names the sections; all of its rows use DIV_NO '9999'.
DISCHARGE_SUMMARY_TEXT_SQL = """
    SELECT
        x.SECTION_NO,
        x.SEQ,
        x.CONTENT,
        s.SECTION_NAME
    FROM DSR.DIAGDOCIX x
    LEFT JOIN DSR.DSRSECTION s
      ON s.DSR_TYPE = 'D'
     AND s.DIV_NO = '9999'
     AND RTRIM(s.SECTION_NO) = x.SECTION_NO
    WHERE x.DOCUMENT_NO = :document_no
    ORDER BY x.SECTION_NO, x.SEQ
"""


# Operations and operative notes, node HI.  ORMS.PTOR is the operation list;
# AK_PTOR_2_CHART_NO_HOSPITALID covers (HOSPITAL_ID, CHART_NO, OR_DATE,
# OR_DUPLICATE_NO).  ORMS.PTORDRPT has one row per procedure (OR_SEQ) and no
# chart-led index of its own, so it is reached through the full PTOR key.  The
# note text is in OR_FINDINGS; OR_PROCEDURE and OR_DESCRIPTION are empty.
OPERATION_SEARCH_SQL = """
    SELECT
        p.HOSPITAL_ID,
        p.CHART_NO,
        p.OR_DATE,
        p.OR_DUPLICATE_NO,
        p.STATUS,
        p.OR_SOURCE,
        p.ADMIT_NO,
        p.DIV_NO,
        p.VS_NO,
        p.OR_ROOM_NO,
        p.OR_IN_DATE,
        p.OR_IN_TIME,
        p.OR_OUT_TIME,
        p.CANCEL_DATE,
        p.CANCEL_REASON,
        p.DIAGNOSIS_CODE,
        p.DIAGNOSIS_CHINESE_NAME,
        p.DIAGNOSIS_ENGLISH_NAME,
        p.DIAGNOSIS_CODE_2,
        p.DIAGNOSIS_CHINESE_NAME_2,
        p.DIAGNOSIS_ENGLISH_NAME_2,
        r.OR_SEQ,
        r.OR_CODE,
        r.OR_NAME,
        r.OR_DOCTOR_NO,
        r.OR_FINDINGS
    FROM ORMS.PTOR p
    LEFT JOIN ORMS.PTORDRPT r
      ON r.HOSPITAL_ID = p.HOSPITAL_ID
     AND r.OR_DATE = p.OR_DATE
     AND r.CHART_NO = p.CHART_NO
     AND r.OR_DUPLICATE_NO = p.OR_DUPLICATE_NO
    WHERE p.HOSPITAL_ID = :hospital_id
      AND p.CHART_NO = :chart_no
      AND p.OR_DATE BETWEEN :start_date AND :end_date
    ORDER BY p.OR_DATE DESC, p.OR_DUPLICATE_NO, r.OR_SEQ
"""


# Outpatient and emergency visits with the physician's note, node HO.
# The data is split by month: schema OHIS<letter><MM> holds one calendar month,
# and the letter follows the ROC year in a 5-year cycle, so 60 schemas hold a
# 60-month window.  Schema OPD holds the open and future encounters.  A schema
# is reused after 5 years, so every statement keeps the CLINIC_DATE range.
# PTOPD uses AK_PTOPD_CHA_HOSPITALID (HOSPITAL_ID, CHART_NO, CLINIC_DATE,
# DUPLICATE_NO); ORDSOOPD has the same leading key and one row per
# (encounter, SO_TYPE, SUB_TYPE).  MAST.DIV and MAST.DOCTOR give the names.
OUTPATIENT_LIVE_SCHEMA = "OPD"
OUTPATIENT_YEAR_LETTERS = ("", "B", "C", "D", "E")
OUTPATIENT_BASE_ROC_YEAR = 111
OUTPATIENT_MONTHS_KEPT = 60
OUTPATIENT_SCHEMAS = frozenset(
    [OUTPATIENT_LIVE_SCHEMA]
    + [f"OHIS{letter}{month:02d}" for letter in OUTPATIENT_YEAR_LETTERS for month in range(1, 13)]
)

OUTPATIENT_NOTE_SQL_TEMPLATE = """
    SELECT
        '{schema}' AS SOURCE_SCHEMA,
        p.HOSPITAL_ID,
        p.CHART_NO,
        p.CLINIC_DATE,
        p.DUPLICATE_NO,
        p.CLINIC_FLAG,
        p.CLINIC_APN,
        p.CLINIC_NO,
        p.ORDER_STATE,
        p.DIV_NO,
        d.DIV_SHORT_NAME AS DIV_NAME,
        d.ENGLISH_FULL_NAME AS DIV_ENGLISH_NAME,
        p.DOCTOR_NO,
        m.DOCTOR_NAME,
        o.SO_TYPE,
        o.SUB_TYPE,
        o.CLERK_ID,
        o.CONTENT
    FROM {schema}.PTOPD p
    LEFT JOIN {schema}.ORDSOOPD o
      ON o.HOSPITAL_ID = p.HOSPITAL_ID
     AND o.CHART_NO = p.CHART_NO
     AND o.CLINIC_DATE = p.CLINIC_DATE
     AND o.DUPLICATE_NO = p.DUPLICATE_NO
    LEFT JOIN MAST.DIV d
      ON d.DIV_NO = p.DIV_NO
    LEFT JOIN MAST.DOCTOR m
      ON m.HOSPITAL_ID = p.HOSPITAL_ID
     AND m.DOCTOR_NO = p.DOCTOR_NO
    WHERE p.HOSPITAL_ID = :hospital_id
      AND p.CHART_NO = :chart_no
      AND p.CLINIC_DATE BETWEEN :start_date AND :end_date
    ORDER BY p.CLINIC_DATE DESC, p.DUPLICATE_NO, o.SO_TYPE, o.SUB_TYPE
"""


NODE_LAB = "lab"
NODE_PATIENT = "patient"
NODE_INPATIENT = "inpatient"


def _read_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            values[key] = value
    return values


@dataclass(frozen=True)
class QueryConfig:
    # Each clinical area lives on one node only: HE holds radiology, laboratory,
    # and pathology; HO holds the patient master; HI holds admissions and notes.
    db_host: str = "10.0.0.1"
    db_port: str = "1521"
    db_sid: str = "he"
    db_user: str = ""
    db_password: str = ""
    hospital_id: str = "000"
    oracle_client_dir: str = r"C:\instantclient_12_2"
    patient_host: str = "10.0.0.1"
    patient_sid: str = "ho"
    inpatient_host: str = "10.0.0.1"
    inpatient_sid: str = "hi"

    @classmethod
    def from_env(cls) -> "QueryConfig":
        project_dir = Path(__file__).resolve().parent
        file_values: dict[str, str] = {}
        for candidate in (project_dir.parent / ".env", project_dir / ".env"):
            file_values.update(_read_env_file(candidate))

        def setting(name: str, default: str = "") -> str:
            return os.environ.get(name, file_values.get(name, default))

        return cls(
            db_host=setting("HIS_DB_HOST_LAB", "10.0.0.1"),
            db_port=setting("HIS_DB_PORT", "1521"),
            db_sid=setting("HIS_DB_SERVICE_LAB", "he"),
            db_user=setting("HIS_DB_USER"),
            db_password=setting("HIS_DB_PASSWORD"),
            hospital_id=setting("HIS_HOSPITAL_ID", "000"),
            oracle_client_dir=setting("ORACLE_CLIENT_DIR", r"C:\instantclient_12_2"),
            patient_host=setting("HIS_DB_HOST_PATIENT", "10.0.0.1"),
            patient_sid=setting("HIS_DB_SERVICE_PATIENT", "ho"),
            inpatient_host=setting("HIS_DB_HOST_IPD", "10.0.0.1"),
            inpatient_sid=setting("HIS_DB_SERVICE_IPD", "hi"),
        )

    def node_address(self, node: str = NODE_LAB) -> tuple[str, str]:
        addresses = {
            NODE_LAB: (self.db_host, self.db_sid),
            NODE_PATIENT: (self.patient_host, self.patient_sid),
            NODE_INPATIENT: (self.inpatient_host, self.inpatient_sid),
        }
        if node not in addresses:
            raise ValueError(f"Unknown database node: {node}")
        return addresses[node]

    def connection_kwargs(self, node: str = NODE_LAB) -> dict[str, str]:
        if not self.db_user or not self.db_password:
            raise RuntimeError(
                "Database credentials are not configured. Set HIS_DB_USER and "
                "HIS_DB_PASSWORD in the environment or the parent .env file."
            )
        host, sid = self.node_address(node)
        dsn = (
            "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)"
            f"(HOST={host})(PORT={self.db_port}))"
            f"(CONNECT_DATA=(SID={sid})))"
        )
        return {"user": self.db_user, "password": self.db_password, "dsn": dsn}


@dataclass(frozen=True)
class SearchWindow:
    start: date
    end: date

    @classmethod
    def from_dates(cls, start: date, end: date) -> "SearchWindow":
        if start > end:
            raise ValueError("Start date must not be after end date")
        if end - start > timedelta(days=3660):
            raise ValueError("Date range must not exceed 10 years")
        return cls(start=start, end=end)

    @classmethod
    def recent(cls, days: int = 730) -> "SearchWindow":
        end = date.today()
        return cls.from_dates(end - timedelta(days=days), end)

    @staticmethod
    def _roc(value: date) -> str:
        year = value.year - 1911
        if year < 1 or year > 999:
            raise ValueError("Date is outside the supported Taiwan calendar range")
        return f"{year:03d}{value.month:02d}{value.day:02d}"

    @property
    def start_roc(self) -> str:
        return self._roc(self.start)

    @property
    def end_roc(self) -> str:
        return self._roc(self.end)


def normalize_chart_no(value: str) -> str:
    chart_no = (value or "").strip()
    if not chart_no or not chart_no.isascii() or not chart_no.isdigit():
        raise ValueError("Chart number must contain digits only")
    if len(chart_no) > 10:
        raise ValueError("Chart number must be at most 10 digits")
    return chart_no.zfill(10)


def normalize_apply_no(value: str) -> str:
    apply_no = (value or "").strip()
    if not apply_no or len(apply_no) > 20:
        raise ValueError("Invalid internal exam identifier")
    if any(ord(char) < 32 for char in apply_no):
        raise ValueError("Invalid internal exam identifier")
    return apply_no


def normalize_accession_no(value: str) -> str:
    """Validate an accession number and return its stored spelling.

    XRAY accessions are 11 digits.  EXAM accessions are 2 to 5 upper-case
    letters followed by digits.  Stored values are upper-case only.
    """
    accession_no = (value or "").strip().upper()
    if not accession_no or not accession_no.isascii() or not accession_no.isalnum():
        raise ValueError("Accession number must contain letters and digits only")
    if len(accession_no) > 20:
        raise ValueError("Accession number must be at most 20 characters")
    return accession_no


def _normalize_digits(value: str, width: int, label: str) -> str:
    text = (value or "").strip()
    if len(text) != width or not text.isascii() or not text.isdigit():
        raise ValueError(f"{label} must be {width} digits")
    return text


def normalize_admit_no(value: str) -> str:
    return _normalize_digits(value, 10, "Admission number")


def normalize_note_date(value: str) -> str:
    return _normalize_digits(value, 7, "Note date")


def normalize_note_time(value: str) -> str:
    return _normalize_digits(value, 4, "Note time")


CHAR_KEY_WIDTHS = {
    "hospital_id": 3,
    "chart_no": 10,
    "apply_no": 20,
    "ref_no": 20,
    "access_no": 20,
    "lab_no": 15,
    "admit_no": 10,
    "document_no": 10,
    "note_date": 7,
    "note_time": 4,
}


def pad_char_key(value: str, width: int) -> str | None:
    """Pad a key to a fixed CHAR width for blank-padded comparison.

    Oracle compares a CHAR column with a VARCHAR2 bind using non-padded
    semantics, so a stripped key never matches the stored value.  Return None
    when the key is wider than the column, because then no row can match.
    """
    text = (value or "").strip()
    if not text:
        raise ValueError("Key value must not be empty")
    if len(text) > width:
        return None
    return text.ljust(width)


def _json_value(value: Any) -> Any:
    if value is None:
        return None
    if hasattr(value, "read") and callable(value.read):
        value = value.read()
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


def oracle_rows(
    description: Sequence[Sequence[Any]],
    rows: Iterable[Sequence[Any]],
    preserve: Iterable[str] = (),
) -> list[dict[str, Any]]:
    """Convert fetched rows to dicts.  Strings are stripped, except the columns
    named in ``preserve``, whose surrounding whitespace is part of the text."""
    columns = [str(item[0]).lower() for item in description]
    kept = {name.lower() for name in preserve}
    result = []
    for row in rows:
        record = {}
        for column, value in zip(columns, row):
            if column in kept and isinstance(value, str):
                record[column] = value
            else:
                record[column] = _json_value(value)
        result.append(record)
    return result


def roc_date_to_iso(value: Any) -> str:
    text = str(value or "").strip()
    if len(text) != 7 or not text.isdigit():
        return text or "Unknown date"
    try:
        return date(int(text[:3]) + 1911, int(text[3:5]), int(text[5:7])).isoformat()
    except ValueError:
        return text


def signed_roc_date_to_iso(value: Any) -> str | None:
    """Convert CHART.CHART.BIRTH_DATE (CHAR(8), ``+YYYMMDD``) to an ISO date.

    Only the ``+`` (ROC era) form is converted.  Any other form returns None,
    and the caller keeps the raw value.
    """
    text = str(value or "").strip()
    if len(text) != 8 or text[0] != "+" or not text[1:].isdigit():
        return None
    try:
        return date(int(text[1:4]) + 1911, int(text[4:6]), int(text[6:8])).isoformat()
    except ValueError:
        return None


def laboratory_sql(schema: str) -> str:
    """Build the laboratory statement for one schema family from the fixed list."""
    if schema not in LAB_SCHEMAS:
        raise ValueError(f"Unknown laboratory schema: {schema}")
    return LAB_SEARCH_SQL_TEMPLATE.format(schema=schema)


def microbiology_organism_sql(schema: str) -> str:
    if schema not in MICROBIOLOGY_SCHEMAS:
        raise ValueError(f"Unknown microbiology schema: {schema}")
    return MICROBIOLOGY_ORGANISM_SQL_TEMPLATE.format(schema=schema)


def merge_laboratory_rows(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Merge the rows of all schema families: drop duplicates, newest order first."""
    seen: set[tuple[str, str, str, str]] = set()
    merged: list[dict[str, Any]] = []
    for row in rows:
        key = tuple(str(row.get(field) or "") for field in ("hospital_id", "lab_no", "unique_seq", "lab_code"))
        if key in seen:
            continue
        seen.add(key)
        item = dict(row)
        item["microbiology"] = str(row.get("source_schema") or "") in MICROBIOLOGY_SCHEMAS
        merged.append(item)
    merged.sort(key=lambda row: str(row.get("unique_seq") or ""))
    merged.sort(
        key=lambda row: (
            str(row.get("order_date") or ""), str(row.get("lab_order_time") or ""), str(row.get("lab_no") or "")
        ),
        reverse=True,
    )
    return merged


def build_organisms(
    rows: Sequence[Mapping[str, Any]],
    antibiotics: Mapping[str, str],
) -> dict[tuple[str, str, str], list[dict[str, Any]]]:
    """Turn LABM rows into organisms with a susceptibility list, keyed by the item."""
    organisms: dict[tuple[str, str, str], list[dict[str, Any]]] = {}
    for row in rows:
        drugs = []
        for index in range(1, MICROBIOLOGY_DRUG_SETS + 1):
            code = str(row.get(f"med_code_{index}") or "").strip()
            if not code:
                continue
            drugs.append({
                "code": code,
                "name": antibiotics.get(code) or code,
                "result": str(row.get(f"rsmi_{index}") or "").strip(),
                "value": str(row.get(f"rsmi_result_{index}") or "").strip(),
            })
        key = tuple(str(row.get(field) or "").strip() for field in ("lab_no", "unique_seq", "lab_code"))
        organisms.setdefault(key, []).append({
            "germ_seq": str(row.get("germ_seq") or "").strip(),
            "germ_code": str(row.get("germ_code") or "").strip(),
            "germ_name": str(row.get("germ_name") or "").strip(),
            "colony_count": str(row.get("colony_count") or "").strip(),
            "unit": str(row.get("unit") or "").strip(),
            "resistant_type": str(row.get("drug_resistant_type") or "").strip(),
            "alert": str(row.get("drug_resistant_alert_msg") or "").strip(),
            "drugs": drugs,
        })
    return organisms


def is_set_roc_date(value: Any) -> bool:
    """True for a real ROC date.  HIS stores an unset date as blanks or zeros."""
    text = str(value or "").strip()
    return len(text) == 7 and text.isdigit() and text.strip("0") != ""


def exam_report_state(row: Mapping[str, Any]) -> str:
    """Derive a reader-facing exam state from the date columns.

    The meaning of PTEXAMINDEX.STATUS codes is not confirmed, so the state
    comes from which dates are set.

    DC_FLAG = 'Y' marks a cancelled order only when the exam was not done.
    In EXAM the flag is also 'Y' on exams that were done and reported (most
    are dental X-ray and health-check exams), so the dates are tested first.
    """
    if is_set_roc_date(row.get("report_date")):
        return "reported"
    if is_set_roc_date(row.get("exam_date")):
        return "examined"
    if str(row.get("dc_flag") or "").strip().upper() == "Y":
        return "cancelled"
    if is_set_roc_date(row.get("sch_date")):
        return "scheduled"
    return "ordered"


def inpatient_note_state(row: Mapping[str, Any]) -> str:
    """Return "signed" or "unsigned" from SIGNED_DATE (NUMBER; 0 or NULL is unset).

    The meaning of IPTPROGRESS1.STATUS codes is not confirmed, so the state
    comes from the date.  An unsigned note is listed, not hidden: most are
    the newest notes of the stay.
    """
    return "signed" if roc_number_to_text(row.get("signed_date")) else "unsigned"


def exam_item_name(row: Mapping[str, Any]) -> str:
    for key in ("exam_full_name", "exam_short_name", "exam_code"):
        name = str(row.get(key) or "").strip()
        if name:
            return name
    return ""


def group_report_sections(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Rebuild report sections from PTEXAMRPT rows.

    DISPLAY_SEQ is the section and SEQ is a continuation part.  A part starts
    when the previous one is full (2000 bytes), so parts join with no separator.
    """
    sections: dict[Any, dict[str, Any]] = {}
    for row in rows:
        key = row.get("display_seq")
        section = sections.setdefault(key, {
            "caption": str(row.get("caption") or "").strip(),
            "type": str(row.get("type") or "").strip(),
            "_parts": [],
        })
        section["_parts"].append((row.get("seq") or 0, row.get("content") or ""))

    def order(value: Any) -> tuple[int, str]:
        try:
            return int(value), ""
        except (TypeError, ValueError):
            return 0, str(value)

    result = []
    for key in sorted(sections, key=order):
        section = sections[key]
        parts = sorted(section.pop("_parts"), key=lambda part: order(part[0]))
        section["content"] = "".join(text for _seq, text in parts).strip()
        if section["content"] or section["caption"]:
            result.append(section)
    return result


def summarize_exam_remarks(rows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    """Split PTEXAMREMARK rows into coded diagnoses and free-text notes.

    A row with a CODE is a coded diagnosis (the codes have ICD shape).  A row
    without a code is free text from the order.  REMARK_TYPE labels are not
    confirmed, so the text rows keep their type code and get no invented label.
    """
    diagnoses: list[dict[str, str]] = []
    notes: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for row in rows:
        code = str(row.get("code") or "").strip()
        text = str(row.get("context") or "").strip()
        if not code and not text:
            continue
        if code:
            if (code, text) not in seen:
                seen.add((code, text))
                diagnoses.append({"code": code, "text": text})
        else:
            notes.append({"type": str(row.get("remark_type") or "").strip(), "text": text})
    return {"diagnoses": diagnoses, "notes": notes}


PATHOLOGY_KINDS = {
    "S": "Surgical pathology",
    "N": "Cytology (non-gynecologic)",
    "G": "Cytology (gynecologic)",
}
PATHOLOGY_SECTION_LABELS = {
    "1": "Pathologic diagnosis",
    "2": "Gross description",
    "3": "Microscopic description",
}


def pathology_state(row: Mapping[str, Any]) -> str:
    if is_set_roc_date(row.get("confirmed_date")):
        return "confirmed"
    if is_set_roc_date(row.get("report_date")):
        return "reported"
    if is_set_roc_date(row.get("receive_date")):
        return "received"
    return "ordered"


def build_pathology_reports(
    headers: Sequence[Mapping[str, Any]],
    surgical: Sequence[Mapping[str, Any]] = (),
    cytology: Sequence[Mapping[str, Any]] = (),
    gyn: Sequence[Mapping[str, Any]] = (),
) -> list[dict[str, Any]]:
    """Attach report text to each pathology order, in reading order."""
    sections: dict[str, list[dict[str, Any]]] = {}

    def add(lab_no: Any, part: Any, label: str, content: Any, code: str = "") -> None:
        text = str(content or "").strip()
        if text:
            sections.setdefault(str(lab_no or "").strip(), []).append({
                "part": str(part or "").strip(),
                "type": code,
                "label": label,
                "content": text,
            })

    for row in surgical:
        code = str(row.get("report_type") or "").strip()
        add(row.get("lab_no"), row.get("unique_seq"),
            PATHOLOGY_SECTION_LABELS.get(code, f"Section {code}"),
            row.get("report_description"), code)
    for row in cytology:
        add(row.get("lab_no"), row.get("unique_seq"), "Specimen", row.get("specimen_content"))
        add(row.get("lab_no"), row.get("unique_seq"), "Gross appearance", row.get("gross_appearance"))
        add(row.get("lab_no"), row.get("unique_seq"), "Result", row.get("result_description"))
        add(row.get("lab_no"), row.get("unique_seq"), "Comment", row.get("lab_comment"))
    coded: dict[str, list[str]] = {}
    for row in gyn:
        lab_no = str(row.get("lab_no") or "").strip()
        add(lab_no, row.get("unique_seq"), "Result", row.get("result_description"))
        add(lab_no, row.get("unique_seq"), "Suggestion", row.get("suggest_description"))
        add(lab_no, row.get("unique_seq"), "Comment", row.get("lab_comment"))
        code = str(row.get("result_code") or "").strip()
        if code:
            coded.setdefault(lab_no, []).append(code)

    reports = []
    for header in headers:
        report = dict(header)
        lab_no = str(header.get("lab_no") or "").strip()
        kind = str(header.get("pathology_type") or "").strip()
        report["kind"] = PATHOLOGY_KINDS.get(kind, "Pathology")
        report["state"] = pathology_state(header)
        report["sections"] = sections.get(lab_no, [])
        report["result_codes"] = coded.get(lab_no, [])
        reports.append(report)
    return reports


def normalize_document_no(value: str) -> str:
    """Validate a DSR document number (CHAR(10))."""
    document_no = (value or "").strip().upper()
    if not document_no or not document_no.isascii() or not document_no.isalnum():
        raise ValueError("Document number must contain letters and digits only")
    if len(document_no) > 10:
        raise ValueError("Document number must be at most 10 characters")
    return document_no


def roc_number_to_text(value: Any) -> str | None:
    """Format a NUMBER(7) ROC date as the 7-character text the other tables use.

    Zero and NULL mean that the date is unset.
    """
    if value is None:
        return None
    try:
        number = int(value)
    except (TypeError, ValueError):
        return str(value).strip() or None
    return f"{number:07d}" if number > 0 else None


def group_document_sections(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Rebuild discharge summary sections from DSR.DIAGDOCIX rows.

    SEQ rows are parts of one section, cut at the 2000-byte column limit in the
    middle of the text, so they join with no separator.
    """
    sections: dict[str, dict[str, Any]] = {}
    for row in rows:
        section_no = str(row.get("section_no") or "").strip()
        section = sections.setdefault(section_no, {
            "section_no": section_no,
            "section_name": str(row.get("section_name") or "").strip() or None,
            "_parts": [],
        })
        section["_parts"].append((str(row.get("seq") or "").strip(), row.get("content") or ""))

    result = []
    for section_no in sorted(sections):
        section = sections[section_no]
        section["content"] = "".join(text for _seq, text in sorted(section.pop("_parts"))).strip()
        if section["content"]:
            result.append(section)
    return result


def group_operations(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Fold the PTOR x PTORDRPT rows into one record per operation.

    The state comes from facts in the row, because the PTOR.STATUS meanings
    are inferred only: a note text, a cancel date, a report row, a room-in date.
    """
    header_fields = (
        "hospital_id", "chart_no", "or_date", "or_duplicate_no", "status", "or_source",
        "admit_no", "div_no", "vs_no", "or_room_no", "or_in_time", "or_out_time", "cancel_reason",
    )
    operations: dict[tuple[str, str], dict[str, Any]] = {}
    for row in rows:
        key = (str(row.get("or_date") or ""), str(row.get("or_duplicate_no") or ""))
        operation = operations.get(key)
        if operation is None:
            operation = {field: row.get(field) for field in header_fields}
            operation["or_in_date"] = roc_number_to_text(row.get("or_in_date"))
            operation["cancel_date"] = roc_number_to_text(row.get("cancel_date"))
            diagnoses = []
            for suffix in ("", "_2"):
                code = str(row.get(f"diagnosis_code{suffix}") or "").strip()
                name = (
                    str(row.get(f"diagnosis_english_name{suffix}") or "").strip()
                    or str(row.get(f"diagnosis_chinese_name{suffix}") or "").strip()
                )
                if (code or name) and {"code": code, "name": name} not in diagnoses:
                    diagnoses.append({"code": code, "name": name})
            operation.update({"diagnoses": diagnoses, "procedures": [], "_notes": []})
            operations[key] = operation
        if row.get("or_seq") is not None or row.get("or_code") or row.get("or_name"):
            operation["procedures"].append({
                "or_seq": row.get("or_seq"),
                "or_code": row.get("or_code"),
                "or_name": row.get("or_name"),
                "or_doctor_no": row.get("or_doctor_no"),
            })
        note = str(row.get("or_findings") or "").strip()
        if note and note not in operation["_notes"]:
            operation["_notes"].append(note)

    result = []
    for operation in operations.values():
        operation["note"] = "\n\n".join(operation.pop("_notes"))
        if operation["note"]:
            operation["state"] = "noted"
        elif operation["cancel_date"]:
            operation["state"] = "cancelled"
        elif operation["procedures"]:
            operation["state"] = "recorded"
        elif operation["or_in_date"]:
            operation["state"] = "performed"
        else:
            operation["state"] = "scheduled"
        result.append(operation)
    return result


def outpatient_month_schema(roc_year: int, month: int) -> str:
    """Name the monthly schema that holds one calendar month of outpatient data."""
    if not 1 <= month <= 12:
        raise ValueError("Month must be 1 to 12")
    letter = OUTPATIENT_YEAR_LETTERS[(roc_year - OUTPATIENT_BASE_ROC_YEAR) % len(OUTPATIENT_YEAR_LETTERS)]
    return f"OHIS{letter}{month:02d}"


def outpatient_schemas(window: "SearchWindow", today: date | None = None) -> list[str]:
    """List the schemas to read for a date window, newest first.

    Only the last 60 months are kept in the monthly schemas.  The live schema
    is always read, because it holds the open and the future encounters.
    """
    today = today or date.today()
    newest = today.year * 12 + today.month - 1
    oldest = newest - (OUTPATIENT_MONTHS_KEPT - 1)
    first = max(window.start.year * 12 + window.start.month - 1, oldest)
    last = min(window.end.year * 12 + window.end.month - 1, newest)
    schemas = [OUTPATIENT_LIVE_SCHEMA]
    for index in range(last, first - 1, -1):
        schema = outpatient_month_schema(index // 12 - 1911, index % 12 + 1)
        if schema not in schemas:
            schemas.append(schema)
    return schemas


def outpatient_note_sql(schema: str) -> str:
    """Build the statement for one schema.  The name comes from a fixed list only."""
    if schema not in OUTPATIENT_SCHEMAS:
        raise ValueError(f"Unknown outpatient schema: {schema}")
    return OUTPATIENT_NOTE_SQL_TEMPLATE.format(schema=schema)


# ORDSOOPD.SO_TYPE follows SOAP.  A SUB_TYPE is used by emergency notes only.
# The sub type labels are inferred from the emergency template table
# MAST.ER_SOSO; no dictionary table holds them.
OUTPATIENT_SO_ORDER = ("S", "O", "A", "P")
OUTPATIENT_SO_LABELS = {"S": "Subjective", "O": "Objective", "A": "Assessment", "P": "Plan"}
OUTPATIENT_SUB_LABELS = {
    "S": (
        ("CC", "Chief complaint"), ("PI", "Present illness"), ("PS", "Past history"),
        ("AL", "Allergy"), ("OP", "Operation history"),
    ),
    "O": (
        ("VS", "Vital signs"), ("EA", "General appearance"), ("HE", "Head, eyes, ears, nose, throat"),
        ("NE", "Neck"), ("CL", "Chest"), ("HR", "Heart"), ("AB", "Abdomen"), ("BS", "Back"),
        ("EX", "Extremities"), ("NX", "Neurological"),
    ),
}


def group_outpatient_visits(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Fold the PTOPD x ORDSOOPD rows into one record per visit, newest first.

    Sections follow S, O, A, P.  Within S and O, the plain row comes first and
    the emergency sub types follow in examination order.
    """
    header_fields = (
        "source_schema", "hospital_id", "chart_no", "clinic_date", "duplicate_no", "clinic_flag",
        "clinic_apn", "clinic_no", "order_state", "div_no", "div_name", "div_english_name",
        "doctor_no", "doctor_name",
    )
    visits: dict[tuple[str, str, str], dict[str, Any]] = {}
    for row in rows:
        key = (
            str(row.get("clinic_date") or ""),
            str(row.get("duplicate_no") or ""),
            str(row.get("source_schema") or ""),
        )
        visit = visits.get(key)
        if visit is None:
            visit = {field: row.get(field) for field in header_fields}
            visit["kind"] = "emergency" if str(row.get("clinic_flag") or "").strip() == "E" else "outpatient"
            visit["_sections"] = []
            visits[key] = visit
        content = str(row.get("content") or "").strip()
        if content:
            visit["_sections"].append({
                "so_type": str(row.get("so_type") or "").strip(),
                "sub_type": str(row.get("sub_type") or "").strip(),
                "clerk_id": row.get("clerk_id"),
                "content": content,
            })

    def section_order(section: Mapping[str, Any]) -> tuple[int, str, int, str]:
        so_type, sub_type = section["so_type"], section["sub_type"]
        so_rank = OUTPATIENT_SO_ORDER.index(so_type) if so_type in OUTPATIENT_SO_ORDER else len(OUTPATIENT_SO_ORDER)
        known = [code for code, _label in OUTPATIENT_SUB_LABELS.get(so_type, ())]
        sub_rank = 0 if not sub_type else (known.index(sub_type) + 1 if sub_type in known else len(known) + 1)
        return so_rank, so_type, sub_rank, sub_type

    result = []
    for key in sorted(visits, key=lambda item: (item[0], item[1]), reverse=True):
        visit = visits[key]
        sections = sorted(visit.pop("_sections"), key=section_order)
        for section in sections:
            group = OUTPATIENT_SO_LABELS.get(section["so_type"])
            section["group"] = group
            sub_labels = dict(OUTPATIENT_SUB_LABELS.get(section["so_type"], ()))
            section["label"] = sub_labels.get(section["sub_type"]) if section["sub_type"] else group
        visit["sections"] = sections
        visit["has_note"] = bool(sections)
        result.append(visit)
    return result


# S/O/A/P are the POMR section codes.  Other codes are shown without a label.
NOTE_SECTION_ORDER = ("S", "O", "A", "P")
NOTE_SECTION_LABELS = {
    "S": "Subjective",
    "O": "Objective",
    "A": "Assessment",
    "P": "Plan",
}


def group_inpatient_note_sections(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Rebuild note sections from IPTPROGRESS3T rows.

    One section is split across SEQ rows at the 2000-byte column limit, so the
    SEQ parts are joined with no separator.  Within a problem, S/O/A/P come
    first in that order; other section codes follow in code order.
    """
    sections: dict[tuple[str, str], list[tuple[str, str]]] = {}
    for row in rows:
        key = (
            str(row.get("problem_no") or "").strip(),
            str(row.get("section_type") or "").strip(),
        )
        sections.setdefault(key, []).append(
            (str(row.get("seq") or "").strip(), row.get("content") or "")
        )

    def sort_key(key: tuple[str, str]) -> tuple[str, int, str]:
        problem_no, section_type = key
        if section_type in NOTE_SECTION_ORDER:
            return problem_no, NOTE_SECTION_ORDER.index(section_type), section_type
        return problem_no, len(NOTE_SECTION_ORDER), section_type

    return [
        {
            "problem_no": problem_no,
            "section_type": section_type,
            "section_label": NOTE_SECTION_LABELS.get(section_type),
            "content": "".join(text for _seq, text in sorted(sections[(problem_no, section_type)])).strip(),
        }
        for problem_no, section_type in sorted(sections, key=sort_key)
    ]


def group_laboratory_rows(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Build date → specimen → category → order → item display groups."""
    dates: dict[str, dict[str, Any]] = {}
    order_fields = (
        "hospital_id", "lab_no", "lab_order_time", "report_date", "report_time",
        "confirmed_date", "lab_status", "diagnosis_description",
    )
    item_fields = (
        "unique_seq", "code", "lab_code", "lab_name", "result_description", "unit",
        "lower_limit", "upper_limit", "result_condition", "result_remark",
        "source_schema", "microbiology", "organisms",
    )

    for row in rows:
        roc_date = str(row.get("order_date") or "").strip()
        date_group = dates.setdefault(roc_date, {
            "date": roc_date_to_iso(roc_date),
            "date_roc": roc_date,
            "item_count": 0,
            "_orders": set(),
            "_specimens": {},
        })

        specimen_code = str(row.get("specimen_code") or "").strip()
        specimen_name = str(row.get("specimen_name") or "").strip() or "Unknown specimen"
        specimen_key = (specimen_code, specimen_name)
        specimen = date_group["_specimens"].setdefault(specimen_key, {
            "specimen_code": specimen_code,
            "specimen_name": specimen_name,
            "item_count": 0,
            "_orders": set(),
            "_categories": {},
        })

        category_code = str(row.get("category_code") or "").strip()
        category_name = str(row.get("category_name") or "").strip() or "Uncategorized"
        category_key = (category_code, category_name)
        category = specimen["_categories"].setdefault(category_key, {
            "category_code": category_code,
            "category_name": category_name,
            "item_count": 0,
            "_orders": {},
        })

        order_key = (
            str(row.get("hospital_id") or "").strip(),
            str(row.get("lab_no") or "").strip(),
        )
        order = category["_orders"].setdefault(order_key, {
            **{field: row.get(field) for field in order_fields},
            "items": [],
        })
        order["items"].append({field: row.get(field) for field in item_fields})

        date_group["item_count"] += 1
        date_group["_orders"].add(order_key)
        specimen["item_count"] += 1
        specimen["_orders"].add(order_key)
        category["item_count"] += 1

    result: list[dict[str, Any]] = []
    for roc_date in sorted(dates, reverse=True):
        date_group = dates[roc_date]
        specimens: list[dict[str, Any]] = []
        for specimen in date_group.pop("_specimens").values():
            categories: list[dict[str, Any]] = []
            for category in specimen.pop("_categories").values():
                orders = list(category.pop("_orders").values())
                category["order_count"] = len(orders)
                category["orders"] = orders
                categories.append(category)
            specimen["order_count"] = len(specimen.pop("_orders"))
            specimen["categories"] = categories
            specimens.append(specimen)
        date_group["order_count"] = len(date_group.pop("_orders"))
        date_group["specimens"] = specimens
        result.append(date_group)
    return result


def workflow_catalog() -> list[dict[str, Any]]:
    return [
        {
            "id": "radiology",
            "label": "Radiology and exam reports",
            "description": "Imaging studies and other exams such as endoscopy and ultrasound, with the report text.",
            "evidence": "confirmed",
            "implementation": "available",
            "search": "EXAM.PTEXAMINDEX + XRAY.PTEXAMINDEX by hospital, chart, and order date",
            "detail": "PTEXAMITEM, PTEXAMREMARK, and PTEXAMRPT by hospital and apply number",
            "content_source": "confirmed",
        },
        {
            "id": "exam_accession",
            "label": "Radiology accession list",
            "description": "Radiology orders with their accession numbers and schedule, exam, and report dates.",
            "evidence": "confirmed",
            "implementation": "available",
            "source_scope": "XRAY_only",
            "search": "Kardeuse2 XRAY.PTEXAMINDEX chart/date search",
            "detail": "PTEXAM and PTEXAMITEM with exam-item master enrichment",
            "content_source": "confirmed_item_master",
            "caveat": "REF_NO and ACCESS_NO hold the same value when both are set; ACCESS_NO is blank until the exam is performed.",
        },
        {
            "id": "laboratory",
            "label": "Laboratory results",
            "description": "Test results grouped by date, specimen, and laboratory section.",
            "evidence": "confirmed_identity",
            "implementation": "available",
            "search": "LAB.LABX1 by hospital and chart; replacement applies an explicit order-date range",
            "detail": "LAB.LABX2 by hospital and lab number",
            "content_source": "confirmed",
            "caveat": "The legacy GUI's hidden date-filter mechanism remains unknown.",
        },
        {
            "id": "pathology",
            "label": "Pathology and cytology reports",
            "description": "Surgical pathology and cytology reports with diagnosis, gross, and microscopic text.",
            "evidence": "confirmed",
            "implementation": "available",
            "search": "LAP.LABP1 by hospital, chart, and order date",
            "detail": "LAP.LABS2 (surgical), LAP.LABN (cytology), LAP.LABG (gynecologic cytology) by hospital and lab number",
            "content_source": "confirmed_family",
            "caveat": "Gynecologic cytology results are stored as codes; the code-to-text source is not confirmed.",
        },
        {
            "id": "opd_note",
            "label": "Outpatient and emergency notes",
            "description": "Outpatient and emergency visits of the last five years, with the physician's note.",
            "evidence": "inferred",
            "implementation": "available",
            "node": "HO",
            "search": "PTOPD by hospital, chart, and clinic date in schema OPD and in each monthly OHIS* schema of the window",
            "detail": "ORDSOOPD by the encounter key; one row per SO_TYPE and SUB_TYPE",
            "content_source": "inferred",
            "caveat": (
                "The table was found by a data-dictionary search. No capture shows that the legacy "
                "Progress Notes window reads it. Only 60 months are kept in these schemas."
            ),
        },
        {
            "id": "admission",
            "label": "Admissions",
            "description": "Hospital stays that overlap the date range.",
            "evidence": "confirmed_identity",
            "implementation": "available",
            "node": "HI",
            "search": "IPD.IPDINDEX by chart; admissions that overlap the date range",
            "detail": "One row per ADMIT_NO + CUT_NO. No detail view.",
            "content_source": "confirmed",
            "caveat": "A DISCHARGE_DATE of 0000000 means the patient is still in hospital.",
        },
        {
            "id": "inpatient_note",
            "label": "Inpatient notes",
            "description": "Progress, admission, discharge summary, operation, and other inpatient notes.",
            "evidence": "confirmed_identity",
            "implementation": "available",
            "node": "HI",
            "search": "IDE.IPTPROGRESS1 by chart and note date; deleted notes are excluded",
            "detail": "IDE.IPTPROGRESS3T sections by admission number, note date, and note time",
            "content_source": "confirmed",
            "caveat": (
                "All note types are listed: progress, admission (A), discharge summary (D), "
                "pre-operation (J), post-operation (K), and others. Section order S, O, A, P "
                "is applied by this app; other section codes are shown without a label."
            ),
        },
        {
            "id": "discharge_summary",
            "label": "Discharge summaries",
            "description": "The discharge summary document of each hospital stay: diagnoses, course, results, and discharge plan.",
            "evidence": "confirmed_identity",
            "implementation": "available",
            "node": "HI",
            "search": "DSR.DIAGDOCI by chart; stays that overlap the date range, or documents written in it",
            "detail": "DSR.DIAGDOCIX sections by document number, named by DSR.DSRSECTION type D",
            "content_source": "confirmed",
            "caveat": "Found by data-dictionary and live checks on 2026-10-13, not by a legacy GUI capture.",
        },
        {
            "id": "operation_note",
            "label": "Operation notes",
            "description": "Operations with their procedures, diagnoses, and the surgeon's operative note.",
            "evidence": "confirmed_identity",
            "implementation": "available",
            "node": "HI",
            "search": "ORMS.PTOR by hospital, chart, and operation date",
            "detail": "ORMS.PTORDRPT by the full operation key; the note text is OR_FINDINGS",
            "content_source": "confirmed",
            "caveat": "Operations before about 2021 often have no note text in the database.",
        },
    ]


class HisQueryService:
    def __init__(
        self,
        config: QueryConfig | None = None,
        connect: Callable[..., Any] | None = None,
    ) -> None:
        self.config = config or QueryConfig.from_env()
        self._connect = connect or oracledb.connect
        self._antibiotics: dict[str, str] | None = None
        if connect is None:
            try:
                oracledb.init_oracle_client(lib_dir=self.config.oracle_client_dir)
            except oracledb.ProgrammingError:
                pass

    def _params(self, chart_no: str, window: SearchWindow) -> dict[str, str]:
        return {
            "hospital_id": pad_char_key(
                self.config.hospital_id, CHAR_KEY_WIDTHS["hospital_id"]
            ),
            "chart_no": normalize_chart_no(chart_no),
            "start_date": window.start_roc,
            "end_date": window.end_roc,
        }

    def _run(
        self,
        sql: str,
        params: Mapping[str, Any],
        node: str = NODE_LAB,
        preserve: Iterable[str] = (),
    ) -> list[dict[str, Any]]:
        with self._connect(**self.config.connection_kwargs(node)) as connection:
            with connection.cursor() as cursor:
                cursor.execute(sql, dict(params))
                return oracle_rows(cursor.description, cursor.fetchall(), preserve)

    def _attach_exam_names(
        self, rows: list[dict[str, Any]], schema: str, params: Mapping[str, Any]
    ) -> None:
        """Add the ordered exam names and a reader-facing state to list rows."""
        names: dict[str, list[str]] = {}
        if rows:
            for item in self._run(EXAM_ITEM_NAME_SQL[schema], params):
                name = exam_item_name(item)
                bucket = names.setdefault(str(item.get("apply_no") or ""), [])
                if name and name not in bucket:
                    bucket.append(name)
        for row in rows:
            row["exam_names"] = names.get(str(row.get("apply_no") or ""), [])
            row["exam_name"] = "; ".join(row["exam_names"])
            row["category"] = "radiology" if schema == "XRAY" else "other"
            row["state"] = exam_report_state(row)

    def search_radiology(self, chart_no: str, window: SearchWindow) -> list[dict[str, Any]]:
        params = self._params(chart_no, window)
        rows: list[dict[str, Any]] = []
        for schema, sql in RADIOLOGY_SEARCH_SQL.items():
            found = self._run(sql, params)
            self._attach_exam_names(found, schema, params)
            rows.extend(found)
        return sorted(
            rows,
            key=lambda row: (row.get("order_date") or "", row.get("order_time") or ""),
            reverse=True,
        )

    def search_exam_accessions(self, chart_no: str, window: SearchWindow) -> list[dict[str, Any]]:
        params = self._params(chart_no, window)
        rows = self._run(EXAM_ACCESSION_SEARCH_SQL, params)
        self._attach_exam_names(rows, "XRAY", params)
        return rows

    def search_laboratory(self, chart_no: str, window: SearchWindow) -> list[dict[str, Any]]:
        """Return laboratory items from the current, history, and microbiology families.

        All statements share one connection.  Organisms are read only when the
        chart has a microbiology order in the window.
        """
        params = self._params(chart_no, window)
        rows = merge_laboratory_rows(
            self._run_each([laboratory_sql(schema) for schema in LAB_SCHEMAS], params)
        )
        used = {str(row.get("source_schema") or "") for row in rows} & set(MICROBIOLOGY_SCHEMAS)
        if used:
            organism_rows = self._run_each(
                [microbiology_organism_sql(schema) for schema in MICROBIOLOGY_SCHEMAS if schema in used], params
            )
            if organism_rows:
                organisms = build_organisms(organism_rows, self._antibiotic_names())
                for row in rows:
                    key = tuple(str(row.get(field) or "") for field in ("lab_no", "unique_seq", "lab_code"))
                    if row["microbiology"] and key in organisms:
                        row["organisms"] = organisms[key]
        return rows

    def _antibiotic_names(self) -> dict[str, str]:
        """Load the antibiotic master once for the life of the service (87 rows)."""
        if self._antibiotics is None:
            self._antibiotics = {
                str(row.get("antibiotic_code") or ""): str(row.get("antibiotic_name") or row.get("short_name") or "")
                for row in self._run(ANTIBIOTIC_NAME_SQL, {})
            }
        return self._antibiotics

    def search_pathology(self, chart_no: str, window: SearchWindow) -> list[dict[str, Any]]:
        """Return one row per pathology order, each with its report sections."""
        params = self._params(chart_no, window)
        headers = self._run(PATHOLOGY_SEARCH_SQL, params)
        if not headers:
            return []
        kinds = {str(header.get("pathology_type") or "").strip() for header in headers}
        known = set(PATHOLOGY_KINDS)
        # An order of an unknown type is looked up in every text table.
        wanted = known if kinds - known else kinds
        return build_pathology_reports(
            headers,
            surgical=self._run(PATHOLOGY_SURGICAL_SQL, params) if "S" in wanted else (),
            cytology=self._run(PATHOLOGY_CYTOLOGY_SQL, params) if "N" in wanted else (),
            gyn=self._run(PATHOLOGY_GYN_SQL, params) if "G" in wanted else (),
        )

    def radiology_detail(self, source: str, hospital_id: str, apply_no: str) -> dict[str, Any]:
        source_key = source.strip().lower()
        if source_key not in RADIOLOGY_DETAIL_SQL:
            raise ValueError("Radiology source must be EXAM or XRAY")
        if hospital_id != self.config.hospital_id:
            raise ValueError("Hospital identifier is outside the configured scope")
        hospital_key = pad_char_key(hospital_id, CHAR_KEY_WIDTHS["hospital_id"])
        apply_key = normalize_apply_no(apply_no)
        result: dict[str, Any] = {}
        for name, sql in RADIOLOGY_DETAIL_SQL[source_key].items():
            width = RADIOLOGY_DETAIL_APPLY_NO_WIDTH[source_key][name]
            padded = pad_char_key(apply_key, width)
            if padded is None:
                result[name] = []
                continue
            result[name] = self._run(
                sql,
                {"hospital_id": hospital_key, "apply_no": padded},
                preserve=("content",) if name == "reports" else (),
            )
        for item in result.get("items", []):
            item["exam_name"] = exam_item_name(item)
        result["report_sections"] = group_report_sections(result.get("reports", []))
        result["clinical"] = summarize_exam_remarks(result.get("remarks", []))
        return result

    def exam_accession_detail(self, hospital_id: str, apply_no: str) -> dict[str, Any]:
        if hospital_id != self.config.hospital_id:
            raise ValueError("Hospital identifier is outside the configured scope")
        hospital_key = pad_char_key(hospital_id, CHAR_KEY_WIDTHS["hospital_id"])
        padded = pad_char_key(normalize_apply_no(apply_no), CHAR_KEY_WIDTHS["apply_no"])
        if padded is None:
            return {"items": []}
        return {
            "items": self._run(
                EXAM_ACCESSION_DETAIL_SQL,
                {"hospital_id": hospital_key, "apply_no": padded},
            )
        }

    def search_accession(self, accession_no: str) -> list[dict[str, Any]]:
        """Find exams by accession number in both radiology schemas.

        ACCESS_NO is filled when the exam is performed.  An order that is not
        yet examined has a blank ACCESS_NO and is not found here.
        """
        padded = pad_char_key(
            normalize_accession_no(accession_no), CHAR_KEY_WIDTHS["access_no"]
        )
        params = {
            "hospital_id": pad_char_key(
                self.config.hospital_id, CHAR_KEY_WIDTHS["hospital_id"]
            ),
            "access_no": padded,
        }
        rows: list[dict[str, Any]] = []
        for schema, sql in ACCESSION_SEARCH_SQL.items():
            found = self._run(sql, params)
            for row in found:
                row["category"] = "radiology" if schema == "XRAY" else "other"
                row["state"] = exam_report_state(row)
            rows.extend(found)
        return rows

    def accession_report(self, accession_no: str) -> list[dict[str, Any]]:
        """Return each matching exam together with its items, remarks, and report."""
        rows = self.search_accession(accession_no)
        for row in rows:
            row.update(
                self.radiology_detail(
                    row["source_schema"], row["hospital_id"], row["apply_no"]
                )
            )
            row["exam_names"] = [
                item["exam_name"] for item in row.get("items", []) if item.get("exam_name")
            ]
            row["exam_name"] = "; ".join(dict.fromkeys(row["exam_names"]))
        return rows

    def patient_info(self, chart_no: str) -> dict[str, Any] | None:
        params = {
            "hospital_id": pad_char_key(
                self.config.hospital_id, CHAR_KEY_WIDTHS["hospital_id"]
            ),
            "chart_no": normalize_chart_no(chart_no),
        }
        rows = self._run(PATIENT_SQL, params, node=NODE_PATIENT)
        if not rows:
            return None
        patient = rows[0]
        patient["birth_date_iso"] = signed_roc_date_to_iso(patient.get("birth_date"))
        return patient

    def _inpatient_params(self, chart_no: str, window: SearchWindow) -> dict[str, str]:
        # The HI inpatient tables have no HOSPITAL_ID column.
        return {
            "chart_no": normalize_chart_no(chart_no),
            "start_date": window.start_roc,
            "end_date": window.end_roc,
        }

    def search_admissions(self, chart_no: str, window: SearchWindow) -> list[dict[str, Any]]:
        return self._run(
            ADMISSION_SEARCH_SQL,
            self._inpatient_params(chart_no, window),
            node=NODE_INPATIENT,
        )

    def search_inpatient_notes(self, chart_no: str, window: SearchWindow) -> list[dict[str, Any]]:
        rows = self._run(
            INPATIENT_NOTE_SEARCH_SQL,
            self._inpatient_params(chart_no, window),
            node=NODE_INPATIENT,
        )
        for row in rows:
            row["state"] = inpatient_note_state(row)
        return rows

    def inpatient_note_detail(self, admit_no: str, note_date: str, note_time: str) -> dict[str, Any]:
        params = {
            "admit_no": pad_char_key(normalize_admit_no(admit_no), CHAR_KEY_WIDTHS["admit_no"]),
            "note_date": pad_char_key(normalize_note_date(note_date), CHAR_KEY_WIDTHS["note_date"]),
            "note_time": pad_char_key(normalize_note_time(note_time), CHAR_KEY_WIDTHS["note_time"]),
        }
        rows = self._run(
            INPATIENT_NOTE_TEXT_SQL,
            params,
            node=NODE_INPATIENT,
            preserve=("content",),
        )
        return {"sections": group_inpatient_note_sections(rows)}

    def search_discharge_summaries(self, chart_no: str, window: SearchWindow) -> list[dict[str, Any]]:
        params: dict[str, Any] = dict(self._inpatient_params(chart_no, window))
        params["start_number"] = int(window.start_roc)
        params["end_number"] = int(window.end_roc)
        rows = self._run(DISCHARGE_SUMMARY_SEARCH_SQL, params, node=NODE_INPATIENT)
        for row in rows:
            row["admit_date"] = roc_number_to_text(row.get("admit_date"))
            row["discharge_date"] = roc_number_to_text(row.get("discharge_date"))
            row["state"] = "confirmed" if is_set_roc_date(row.get("confirmed_date")) else "draft"
        return rows

    def discharge_summary_detail(self, document_no: str) -> dict[str, Any]:
        padded = pad_char_key(normalize_document_no(document_no), CHAR_KEY_WIDTHS["document_no"])
        rows = self._run(
            DISCHARGE_SUMMARY_TEXT_SQL,
            {"document_no": padded},
            node=NODE_INPATIENT,
            preserve=("content",),
        )
        return {"sections": group_document_sections(rows)}

    def search_operations(self, chart_no: str, window: SearchWindow) -> list[dict[str, Any]]:
        """Return one row per operation, each with its procedures and operative note."""
        rows = self._run(OPERATION_SEARCH_SQL, self._params(chart_no, window), node=NODE_INPATIENT)
        return group_operations(rows)

    def _run_each(
        self,
        statements: Iterable[str],
        params: Mapping[str, Any],
        node: str = NODE_LAB,
    ) -> list[dict[str, Any]]:
        """Run several statements with the same binds on one connection."""
        rows: list[dict[str, Any]] = []
        with self._connect(**self.config.connection_kwargs(node)) as connection:
            for sql in statements:
                with connection.cursor() as cursor:
                    cursor.execute(sql, dict(params))
                    rows.extend(oracle_rows(cursor.description, cursor.fetchall()))
        return rows

    def search_outpatient_notes(
        self, chart_no: str, window: SearchWindow, today: date | None = None
    ) -> list[dict[str, Any]]:
        """Return one row per outpatient or emergency visit, each with its note sections.

        One statement runs for each monthly schema in the window, and one for
        the live schema.  All of them share one connection.
        """
        statements = [outpatient_note_sql(schema) for schema in outpatient_schemas(window, today)]
        rows = self._run_each(statements, self._params(chart_no, window), node=NODE_PATIENT)
        return group_outpatient_visits(rows)
