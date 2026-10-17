# Oracle HIS Schema — Ground Truth

> Verified by live database exploration: 2026-04-09  
> Corrected by live data-dictionary checks: 2026-10-13 — details in
> [`analysis/HIS_DB_TABLE_NOTES_20261013.md`](../analysis/HIS_DB_TABLE_NOTES_20261013.md)  
> This file is the single schema reference. The April 2026 root-level notes were removed on 2026-10-13.

Server: Oracle Database 11g Enterprise Edition 11.2.0.3.0 on IBM AIX. Character set `ZHT16BIG5`.
No `FETCH FIRST`, no `OFFSET` (use `ROWNUM`), no JSON functions.

---

## ⛔ WRONG (do not use)

| Assumed | Reality |
|---|---|
| `OPD.PTLABRESULT`, `OPD.PTEXAMRESULT`, `OPD.PTLAXRESULT` as the result store | ❌ Not on HE. They exist on HO only as a small working set of about two days (144, 11, and 0 rows on 2026-08-28). The longitudinal stores are `LAB`, `EXAM`, and `XRAY` on HE. |
| `CHART_NO` in `EXAM.PTEXAM` | ❌ Not in main table — in `EXAM.PTEXAMINDEX` |
| `MAST.PATIENT` | ❌ Does not exist on HO, HE, or HI — the patient master is `CHART.CHART` on HO |
| `CHART.PTHISMEDICAL` | ❌ Does not exist on HO, HE, or HI |
| Report text in `PTEXAM.RESULT` or `PTEXAM.EXCERPT` | ❌ `RESULT` is a CHAR(1) flag and `EXCERPT` was empty in every sampled row — the text is in `PTEXAMRPT.CONTENT` |
| `WHERE e.REF_NO = :accession` | ❌ `PTEXAM.REF_NO` has no index — look up `PTEXAMINDEX.ACCESS_NO` |
| A stripped value bound to a CHAR key | ❌ Matches no row — see the CHAR key rule below |
| `ACCESS_NO` is blank in `PTEXAMINDEX` | ❌ It is filled when the exam is performed, and it is indexed |

---

## Node map

Each clinical area lives on one node only. All nodes answer on port 1521 with a SID descriptor.

| Node | Address / SID | Holds |
|---|---|---|
| HO | 10.0.0.1 / `ho` | `CHART.CHART` (patient master), `CHART.CHARTNOTE`, `OPD.OPDPROGRESS` |
| HE | 10.0.0.1 / `he` | `EXAM.*`, `XRAY.*`, `LAB.LABX1/LABX2`, `LAP.LABP1/LABP2`, `EXAMMAST.EXAMITEM` |
| HI | 10.0.0.1 / `hi` | `IPD.IPDINDEX`, `IPD.PTIPD`, `IDE.IPTPROGRESS1/2/3T`, `NISOP.NOTEDOCUMENT`, `DSR.DSRSECTION`, `ORMS.PTORDRPT` |
| ONH, HB, PPF | 10.0.0.1, .141, .142 | None of the probed clinical tables. Role unverified. |

---

## CHAR key rule

Every key column is CHAR and blank-padded. Oracle compares a CHAR column with a VARCHAR2 bind
using non-padded semantics, so a stripped value matches no row. Pad each key bind to the exact
width of its column (`pad_char_key` in `his_query.py`). Do not wrap an indexed column in `TRIM()`.

| Column | Table | Width |
|---|---|---|
| `HOSPITAL_ID` | all | CHAR(3) |
| `CHART_NO` | all | CHAR(10) |
| `APPLY_NO` | `*.PTEXAM`, `*.PTEXAMINDEX`, `*.PTEXAMITEM`, `*.PTEXAMRPT`, `XRAY.PTEXAMREMARK` | CHAR(20) |
| `APPLY_NO` | `EXAM.PTEXAMREMARK` | CHAR(15) |
| `REF_NO`, `ACCESS_NO` | `*.PTEXAM`, `*.PTEXAMINDEX` | CHAR(20) |
| `LAB_NO` | `LAB.LABX1`, `LAB.LABX2`, `LAP.LABP2`, `LAP.LABS2` | VARCHAR2(15) — no padding |
| `LAB_NO` | `LAP.LABP1` | CHAR(10) |
| `ADMIT_NO` | `IPD.*`, `IDE.*` | CHAR(10) |
| `NOTE_DATE`, `NOTE_TIME` | `IDE.IPTPROGRESS*` | CHAR(7), CHAR(4) |

Most date columns are CHAR(7) in ROC era (`1151009` = 2026-10-09).

---

## ✅ CORRECT: HE Node (10.0.0.1 / SID=he)

### EXAM Schema — radiology/imaging

| Table | Rows | Purpose |
|---|---|---|
| `EXAM.PTEXAM` | 4,087,128 | Exam header — no date column and no `CHART_NO` |
| `EXAM.PTEXAMREMARK` | 25,200,000+ | Clinical remarks / indication text |
| `EXAM.PTEXAMINDEX` | 4,087,128 | Index and worklist — `CHART_NO`, `ACCESS_NO`, and the date columns |
| `EXAM.PTEXAMITEM` | — | Ordered items |
| `EXAM.PTEXAMRPT` | 8,700,000 | Report sections — `CAPTION`, `CONTENT`. Key adds `DISPLAY_SEQ` (section) + `SEQ` (continuation part) |

**EXAM.PTEXAM columns:**

| Column | Type | Notes |
|---|---|---|
| `HOSPITAL_ID` | CHAR(3) | Part of every key |
| `APPLY_NO` | CHAR(20) | Internal exam ID — primary join key with `HOSPITAL_ID` |
| `REF_NO` | CHAR(20) | **Accession**, filled at order time. No index. |
| `ID_NO` | CHAR(10) | Patient national/hospital ID |
| `PT_NAME` | VARCHAR2(30) | Patient name |
| `BIRTH_DATE` | CHAR(8) | Date of birth |
| `SEX` | CHAR(1) | Patient sex |
| `RESULT` | CHAR(1) | Flag, not report text |
| `REPORT_TYPE` | CHAR(1) | Flag |
| `REMARK` | CHAR(10) | Short code field, not a note |
| `EXCERPT` | VARCHAR2(1000) | Empty in every sampled row |
| `LAST_MODIFIED_DATE` | CHAR(7) | ROC date |

**EXAM.PTEXAMINDEX key columns:**

| Column | Type | Notes |
|---|---|---|
| `HOSPITAL_ID` + `APPLY_NO` | CHAR(3) + CHAR(20) | Unique (`PK_PTEXAMINDEX_HOSPITALID`) |
| `CHART_NO` | CHAR(10) | Indexed with `ORDER_DATE` (`AK_PTEXAMINDEX_CNO_HOSPITALID`) |
| `ACCESS_NO` | CHAR(20) | **Accession**, filled when the exam is performed. Indexed. |
| `ORDER_DATE`, `SCH_DATE`, `EXAM_DATE`, `REPORT_DATE` | CHAR(7) | ROC dates |
| `MODALITY`, `EXAM_TYPE`, `STATUS` | CHAR | — |

**EXAM.PTEXAMREMARK columns:**

| Column | Purpose |
|---|---|
| `APPLY_NO` | Join to PTEXAM — CHAR(15) in `EXAM`, CHAR(20) in `XRAY` |
| `REMARK_TYPE` | Classification code |
| `CODE` | Remark code |
| `CONTEXT` | **Full clinical indication text** |

**Report sections (`PTEXAMRPT`):** `DISPLAY_SEQ` orders the sections and `CAPTION` names them. A radiology
report is usually one section with the generic caption `報告內容`. An `EXAM` report often has many
captioned sections. `SEQ` > 0 is a continuation part; in a one-day slice, each such part followed a
part of 1,900 bytes or more, so join the parts with no separator.

**Remark types (`PTEXAMREMARK.REMARK_TYPE`):** values seen are `A`, `D`, `H`, `O`, `S`. Rows of type `A`
and `D` hold a `CODE` of ICD shape and a diagnosis name. Rows of type `H`, `O`, and `S` hold free text
and no code. The labels of the types are not confirmed.

**Dates and status (`PTEXAMINDEX`):** an unset date is `0000000`, not blank. `STATUS` values seen are
`1`, `2`, `3`, `5`; on one order date every report row belonged to an exam of status `5`. The other
meanings are not confirmed, so the app derives the exam state from the date columns.

**Cancelled orders (`PTEXAMINDEX.DC_FLAG`, CHAR(1), `Y` or `N`):** the column has no comment, so the meaning is inferred.
In `XRAY`, `Y` was only on `STATUS` `1` rows with no arrive, exam, or report date (85 of 85 on three order dates).
In `EXAM`, `Y` was also on exams that were done and reported (167 of 214; most are dental X-ray and health-check exams).
So the app shows "Cancelled" only when the flag is `Y` **and** the exam date and report date are unset. Do not filter on the
flag alone, and do not hide these rows.

**Exam names:** `EXAMMAST.EXAMITEM` (key `EXAM_CODE` + `EXAM_TYPE`) gives `EXAM_SHORT_NAME` and
`EXAM_FULL_NAME` for the items of both schemas. `EXAMMAST.EXAMTYPE` (key `EXAM_TYPE`) gives
`EXAM_DESCRIPTION` and `SYSTEM` (`XRAY` or `EXAM`). `XRAY` is radiology; `EXAM` is other exams such as
endoscopy, ultrasound by other departments, and ECG.

### XRAY Schema — identical structure to EXAM

| Table | Rows |
|---|---|
| `XRAY.PTEXAM` | 5,300,000 |
| `XRAY.PTEXAMREMARK` | 27,700,000 |
| `XRAY.PTEXAMINDEX` | 5,300,000 |
| `XRAY.PTEXAMRPT` | 5,200,000 |

### Accession numbers

- `PTEXAM.REF_NO` and `PTEXAMINDEX.ACCESS_NO` hold the same value when both are set.
- `REF_NO` is filled at order time. `ACCESS_NO` is filled when the exam is performed.
  An order that is not yet examined has `REF_NO` only.
- XRAY accessions are 11 digits. The first 7 digits are usually the ROC order date.
  Rows before ROC year 100 (2011) have 10 digits; this is from an April 2026 count and was not re-checked.
- EXAM accessions are 2 to 5 upper-case letters, then 9 to 11 digits.
- Indexes: `XRAY.PTEXAMINDEX` `AK_PTEXAMINDEX_ACC hospitalID (HOSPITAL_ID, ACCESS_NO)`,
  `EXAM.PTEXAMINDEX` `AK_PTEXAMINDEX_ACCESS_NO (ACCESS_NO)`. Both are non-unique.

### LAB Schema — lab results

Columns, types, and indexes in this section and the next were read from `ALL_TAB_COLUMNS` and
`ALL_IND_COLUMNS` on 2026-10-13.

| Table | Rows | Notes |
|---|---|---|
| `LAB.LABX1` | 9,200,000 | Lab order header, 112 columns. Key `HOSPITAL_ID` + `LAB_NO` (`PK_LABX1_HOSPITALID`). Holds `CHART_NO`. |
| `LABHIS.LABX1` / `LABX2` | 6,200,000 / 52,600,000 | Older orders, same columns and indexes. Confirmed dates 2016-10 to 2021-04. No order of two sampled days was in both `LAB` and `LABHIS`. |
| `LAM.LABX1` / `LABX2` | 412,000 / 1,240,000 | Microbiology orders and items, same used columns. Lab groups `M`, `M1`, `M2`. No order of a 3-day slice was also in `LAB`. |
| `LAM.LABM` | 119,000 | One row per organism of an item. Key `HOSPITAL_ID` + `LAB_NO` + `UNIQUE_SEQ` + `LAB_CODE` + `GERM_SEQ` + `GERM_CODE`. `COLONY_COUNT`, and 20 drug sets `MED_CODE_n`, `RSMI_n` (`S`, `I`, `R`), `RSMI_RESULT_n` (value). `DRUG_RESISTANT_ALERT_MSG`. |
| `LAMHIS.LABX1` / `LABX2` / `LABM` | 301,000 / 933,000 / 99,000 | Older microbiology, same shape. |
| `LABMAST.GERM` | 1,303 | Organism names. Key `GERM_CODE`. `GERM_NAME` CHAR(60). |
| `LABMAST.ANTIBIOTIC` | 87 | Antibiotic names. Key `ANTIBIOTIC_CODE`. `ANTIBIOTIC_NAME` CHAR(60). |
| `LAB.LABX2` | 68,900,000 | Lab items, 81 columns. Key `HOSPITAL_ID` + `LAB_NO` + `UNIQUE_SEQ` + `LAB_CODE` (`PK_LABX2_HOSPITALID`). |
| `LABMAST.LABITEM1` | — | Test master, 41 columns. Key `LAB_CODE` + `SPECIMEN_CODE`. |
| `LABMAST.LABITEM2` | — | Reference ranges, 24 columns. Key `LAB_CODE` + `SPECIMEN_CODE` + `APPARATUS_CODE` + `EFFECTIVE_DATE_C` + `START_AGE_C`. |
| `LABMAST.SPECIMEN` | — | Specimen names. Key `SPECIMEN_CODE`. `SPECIMEN_NAME` CHAR(60). |
| `LABMAST.LABGROUP` | — | Lab category names. Key `LAB_GROUP_CODE`. `LAB_GROUP_NAME` CHAR(10). |
| `LABEXCHANGE.LABRPT01` | 1,900,000 | Lab reports. Columns not verified. |

**Two traps in these tables, measured on 2026-10-13:**

- `LABX1.ORDER_DATE` is `0000000` on most orders: it was set on 1,004 of 8,741 `LAB` orders of one day and on 709 of 4,053
  `LABHIS` orders. `LAB_ORDER_DATE` was set on all of them, and equals `ORDER_DATE` when both are set. Filter on `LAB_ORDER_DATE`.
- `LABX2.CODE` is blank on more than half of the item rows (43,056 of 76,825 on one day). `LABX2.LAB_CODE` is never blank.
  A join `LABITEM1.LAB_CODE = LABX2.CODE` named 33,718 of those rows; a join on `LABX2.LAB_CODE` named all 76,825.

**LAB.LABX1 columns used for a chart search:**

| Column | Type | Notes |
|---|---|---|
| `LAB_NO` | VARCHAR2(15) | Order key. Not CHAR — no padding. |
| `CHART_NO` | CHAR(10) | Indexed with `CONFIRMED_DATE` (`AK_LABX1_9_HOSPITALID`) and with `CLINIC_DATE` (`AK_LABX1_5_HOSPITALID`). No index holds `ORDER_DATE`. |
| `PT_NAME` | CHAR(30) | Patient name |
| `LAB_ORDER_DATE`, `SPECIMEN_DATE`, `REPORT_DATE`, `CONFIRMED_DATE` | CHAR(7) | ROC dates. `LAB_ORDER_DATE` is always set. `ORDER_DATE` is usually `0000000`. |
| `LAB_ORDER_TIME`, `SPECIMEN_TIME`, `REPORT_TIME`, `CONFIRMED_TIME` | CHAR(4) | `HHMM`. There is no `ORDER_TIME` column. |
| `ORDER_DOCTOR_NO`, `ORDER_CLERK`, `SPECIMEN_CLERK`, `REPORT_CLERK`, `CONFIRMED_CLERK` | CHAR(8) | Staff codes |
| `ORDER_DIV_NO`, `ORDER_BED_NO` | CHAR(4), CHAR(10) | Division and bed |
| `SPECIMEN_CODE`, `LAB_GROUP_CODE` | CHAR(2) | Join `LABMAST.SPECIMEN` and `LABMAST.LABGROUP` for names |
| `SPECIMEN_SEQ` | CHAR(12) | Indexed |
| `LAB_STATUS` | CHAR(1) | — |
| `DIAGNOSIS_CODE`, `DIAGNOSIS_DESCRIPTION` | CHAR(10), VARCHAR2(2000) | Clinical diagnosis note |
| `LAB_COMMENT` | VARCHAR2(2000) | — |

**LAB.LABX2 columns:**

| Column | Type | Notes |
|---|---|---|
| `LAB_NO` | VARCHAR2(15) | Join to `LABX1` with `HOSPITAL_ID` |
| `UNIQUE_SEQ` | CHAR(5) | Row order within an order |
| `CODE`, `LAB_CODE` | CHAR(7) | `LAB_CODE` is the item code and joins `LABMAST.LABITEM1.LAB_CODE`. `CODE` is the ordered code and is often blank. |
| `SPECIMEN_CODE` | CHAR(2) | — |
| `RESULT_DESCRIPTION` | VARCHAR2(2000) | **Result value** |
| `RESULT_CONDITION` | CHAR(1) | `H` high, `L` low, blank normal |
| `UNIT` | CHAR(10) | `LABMAST.LABITEM1.UNIT` is CHAR(20) |
| `LOWER_LIMIT`, `UPPER_LIMIT` | NUMBER | — |
| `ORDER_DATE`, `REPORT_DATE`, `CONFIRMED_DATE` | CHAR(7) | ROC dates |
| `ORDER_REMARK`, `RESULT_REMARK` | VARCHAR2(100), VARCHAR2(50) | — |

`LABMAST.LABITEM1` holds `LAB_NAME` CHAR(50) and `CHINESE_LAB_NAME` VARCHAR2(60).
`LABMAST.LABITEM2` holds `REFERENCE` VARCHAR2(300) and the limits split by sex:
`LOWER_LIMIT_MAN`, `UPPER_LIMIT_MAN`, `LOWER_LIMIT_WOMAN`, `UPPER_LIMIT_WOMAN`. It has no
`LOWER_LIMIT` or `UPPER_LIMIT` column. One item can have several rows by apparatus, date, and age.

### LAP Schema — pathology

| Table | Notes |
|---|---|
| `LAP.LABP1` | Pathology order header, 93 columns. Key `HOSPITAL_ID` + `LAB_NO` (`PK_LABP1_HOSPITALID`). `LAB_NO` is CHAR(10) here. `CHART_NO` is indexed with `CONFIRMED_DATE` + `CONFIRMED_TIME`. |
| `LAP.LABP2` | Pathology items, 46 columns. Key `LAB_NO` + `UNIQUE_SEQ` (`PK_LABP2`). `LAB_NO` is VARCHAR2(15). |
| `LAP.LABS2` | Report text, 5 columns. Key `LAB_NO` + `UNIQUE_SEQ` + `REPORT_TYPE` (`PK_LABS2`). |

- `LAP.LABP1`: `PATHOLOGY_NO` CHAR(11) is the pathology number and is indexed. Also `CHART_NO`,
  `PT_NAME`, `ORDER_DATE`, `RECEIVE_DATE`, `REPORT_DATE`, `CONFIRMED_DATE` (all CHAR(7)),
  `CONFIRMED_CLERK` CHAR(8), `SPECIMEN_CODE` CHAR(2), `SPECIMEN_CONTENT` CHAR(200),
  `DIAGNOSIS_CODE` CHAR(7), `DIAGNOSIS_DESCRIPTION` VARCHAR2(2000).
- `LAP.LABS2`: `REPORT_TYPE` CHAR(1) and `REPORT_DESCRIPTION` VARCHAR2(2000). The April 2026 note
  mapped `REPORT_TYPE` `1` to diagnosis, `2` to gross, and `3` to microscopic. This mapping was not re-checked.
- `LAP.LABP1.PATHOLOGY_TYPE` selects the report family. In a 14-day slice of 1,351 confirmed orders:

  | Type | Orders | Text table | Text columns |
  |---|---|---|---|
  | `S` surgical pathology | 818 | `LAP.LABS2` | `REPORT_DESCRIPTION`, one row per part (`UNIQUE_SEQ`) and section (`REPORT_TYPE`) |
  | `N` non-gyn cytology | 225 | `LAP.LABN` (key `LAB_NO` + `UNIQUE_SEQ`) | `RESULT_DESCRIPTION` VARCHAR2(2000), `GROSS_APPEARANCE`, `SPECIMEN_CONTENT`, `LAB_COMMENT` |
  | `G` gyn cytology | 308 | `LAP.LABG` (key `LAB_NO` + `UNIQUE_SEQ`) | `RESULT_DESCRIPTION` was blank in 308 of 308 rows; the result is in `RESULT_CODE` and other code columns |

- `LABS2.REPORT_TYPE`: `2` is the gross description (952 of 1,117 rows hold the word GROSS) and `3` is the
  microscopic description (928 of 1,117 hold MICROSCOP). `1` is the diagnosis (by elimination and the April note).
- Each text table joins `LABP1` on `HOSPITAL_ID` + `LAB_NO`; `HOSPITAL_ID` matched in every joined row.
  The app does not need `LAP.LABP2` to read the text.
- An order that is not yet reported has no text row. Its `REPORT_DATE` and `CONFIRMED_DATE` are unset.
- `LABP1.ORDER_DATE` is unset on many orders: set on 600 of 799 type `S`, 93 of 202 type `N`, and 0 of 344 type `G` orders
  of a 14-day slice. `LABP1.LAB_ORDER_DATE` was set on all 1,345. Filter on `LAB_ORDER_DATE`.
- An order from an outside source stores a chart number of 3 to 8 digits with no zero padding (82 of 344 type `G` orders).
  A search by the 10-digit hospital chart number does not find it.
- `LAP.LABPNOTES` (types `A` to `E`) and `LAP.LABPNOTEN` (types `A` to `F`) hold short notes per order.
  The meaning of the types is not confirmed. `LAP.LABG` also has telephone and address columns; the app does not select them.
- `LABMAST.SPECIMEN` names every `LABP1.SPECIMEN_CODE` of the slice.

---

## HO Node (10.0.0.1 / SID=ho) — Patient Master

| Table | Purpose |
|---|---|
| `CHART.CHART` | Patient master. Key `HOSPITAL_ID` + `CHART_NO`. `PT_NAME`, `ID_NO`, `BIRTH_DATE` (`+YYYMMDD`, ROC), `SEX`, `BLOOD_TYPE`, `PT_TYPE`, `LAST_OPD_DATE`, `LAST_ADMIT_DATE`, `LAST_DISCHARGE_DATE` |
| `CHART.CHARTNOTE` | Chart-level notes. Key `HOSPITAL_ID` + `CHART_NO` + `NOTE_TYPE`. `CONTENT` VARCHAR2(2000) |
| `CHART.PTBODYMEASURE`, `CHART.PTVITALSIGN` | Exist on HO. Columns not verified. |
| `MAST.SORDERP`, `MAST.SORDERSO`, `MAST.SORDERA` | Exist on HO, HE, and HI. Columns not verified. |
| `PTOPD` | Outpatient and emergency visit, 124 columns. Key `HOSPITAL_ID` + `CLINIC_DATE` + `CHART_NO` + `DUPLICATE_NO`. Chart index `AK_PTOPD_CHA_HOSPITALID` on `(HOSPITAL_ID, CHART_NO, CLINIC_DATE, DUPLICATE_NO)`. `CLINIC_FLAG` `E` is an emergency visit. |
| `ORDSOOPD` | Visit note text. Key `HOSPITAL_ID` + `CHART_NO` + `CLINIC_DATE` + `DUPLICATE_NO` + `SO_TYPE` + `SUB_TYPE`. `CONTENT` VARCHAR2(4000), one row per section. `SO_TYPE` is `S`, `O`, `A`, `P`, or `C`. A `SUB_TYPE` is set for emergency notes only. |
| `MAST.DIV` | Division names, 158 rows. Key `DIV_NO`. `DIV_SHORT_NAME`, `DIV_FULL_NAME`, `ENGLISH_FULL_NAME`. |
| `MAST.DOCTOR` | Doctor names. Key `HOSPITAL_ID` + `DOCTOR_NO`. `DOCTOR_NAME` CHAR(10). |

`PTOPD` and `ORDSOOPD` exist in 61 schemas on HO:

- `OPD` holds the open encounters and the future appointments.
- `OHIS01`..`OHIS12`, `OHISB01`..`OHISB12`, `OHISC*`, `OHISD*`, `OHISE*` hold one calendar month each.
  The month is the two digits. The letter is none, `B`, `C`, `D`, `E` for `(ROC year - 111) mod 5` = 0 to 4.
  On 2026-10-13 these 60 schemas held 2021-11 to 2026-10. The rule for the letter is inferred from that content.
- A schema is reused after 5 years. Keep the `CLINIC_DATE` range in every statement.

---

## HI Node (10.0.0.1 / SID=hi) — Admissions and Inpatient Notes

The `IPD`, `IDE`, and `NISOP` tables have no `HOSPITAL_ID` column.

| Table | Rows | Purpose |
|---|---|---|
| `IPD.IPDINDEX` | 594,321 | Admission index. Key `ADMIT_NO` + `CUT_NO`. `CHART_NO` is indexed. `DISCHARGE_DATE` is `0000000` while the patient is in hospital. |
| `IDE.IPTPROGRESS1` | 3,736,782 | Inpatient note header. Key `ADMIT_NO` + `NOTE_DATE` + `NOTE_TIME`. Indexed on `(CHART_NO, NOTE_DATE, NOTE_TIME)`. `DELETED_DATE` is `0` for a live note. `SIGNED_DATE` (NUMBER) is `0` for an unsigned note; the app lists it with a "Not signed" mark. |
| `IDE.IPTPROGRESS3T` | 13,504,707 | Inpatient note body. Key adds `PROBLEM_NO` + `SECTION_TYPE` + `SEQ`. `CONTENT` VARCHAR2(2000). Always bind the full note identity. |
| `IDE.PROGRESSNOTETYPE` | 19 | Note type dictionary: `P` progress, `A` admission, `D` discharge summary, `J`/`K` pre-/post-operation, and others. `NOTE_TYPE` is case-sensitive. |
| `NISOP.NOTEDOCUMENT` | 537,235 | EMR document index. No index on `PATIENTID` — a chart lookup scans the table. |
| `ORMS.PTOR` | 512,808 | Operation list. Key `HOSPITAL_ID` + `OR_DATE` + `CHART_NO` + `OR_DUPLICATE_NO`. Chart index `AK_PTOR_2_CHART_NO_HOSPITALID` on `(HOSPITAL_ID, CHART_NO, OR_DATE, OR_DUPLICATE_NO)`. `OR_IN_DATE` and `CANCEL_DATE` are NUMBER(7); `OR_IN_DATE` is set only after the patient enters the room. |
| `ORMS.PTORDRPT` | 528,092 | One row per procedure. Key = the `PTOR` key + `OR_SEQ`. No other index. `OR_NAME` CHAR(160); the note text is `OR_FINDINGS` VARCHAR2(4000), on the `OR_SEQ` `0` row. `OR_PROCEDURE` and `OR_DESCRIPTION` are empty. |
| `DSR.DIAGDOCI` | 502,593 | Discharge summary header. Key `DOCUMENT_NO` CHAR(10). Indexed on `(CHART_NO, CREATED_DATE_C)` and `(ADMIT_NO, CREATED_DATE_C)`. `CREATED_DATE_C` is the complement of `CREATED_DATE`, so ascending order is newest first. `ADMIT_DATE` and `DISCHARGE_DATE` are NUMBER(7). |
| `DSR.DIAGDOCIX` | 7,810,604 | Discharge summary text. Key `DOCUMENT_NO` + `SECTION_NO` CHAR(1) + `SEQ` CHAR(3). `CONTENT` VARCHAR2(2000). A long section continues in the next `SEQ`; the cut is in the middle of the text, so join with no separator. |
| `DSR.DSRSECTION` | 27 | Section names. Key `DSR_TYPE` + `DIV_NO` + `SECTION_NO` CHAR(3). Type `D` is the discharge summary (15 sections), type `A` the admission note. All rows use `DIV_NO` `9999`. |

---

## Query Templates

Bind `:hospital_id` as 3 characters and pad the other CHAR keys as the CHAR key rule states.

### Accession → Exam

```sql
SELECT i.HOSPITAL_ID, i.APPLY_NO, i.CHART_NO, i.ORDER_DATE, i.EXAM_DATE,
       i.REPORT_DATE, i.MODALITY, i.ACCESS_NO, e.REF_NO
FROM XRAY.PTEXAMINDEX i
JOIN XRAY.PTEXAM e
  ON e.HOSPITAL_ID = i.HOSPITAL_ID AND e.APPLY_NO = i.APPLY_NO
WHERE i.HOSPITAL_ID = :hospital_id
  AND i.ACCESS_NO = :access_no          -- padded to 20 characters
```

Run the same statement on `EXAM` for a letter-prefixed accession.

### Exam → Clinical Indication and Report

```sql
SELECT REMARK_TYPE, SEQ, CODE, CONTEXT
FROM XRAY.PTEXAMREMARK
WHERE HOSPITAL_ID = :hospital_id AND APPLY_NO = :apply_no
ORDER BY REMARK_TYPE, SEQ;

SELECT DISPLAY_SEQ, SEQ, CAPTION, CONTENT
FROM XRAY.PTEXAMRPT
WHERE HOSPITAL_ID = :hospital_id AND APPLY_NO = :apply_no
ORDER BY DISPLAY_SEQ, SEQ;
```

### Chart → Recent Studies

```sql
SELECT i.APPLY_NO, i.ORDER_DATE, i.MODALITY, i.ACCESS_NO, e.REF_NO
FROM XRAY.PTEXAMINDEX i
JOIN XRAY.PTEXAM e
  ON e.HOSPITAL_ID = i.HOSPITAL_ID AND e.APPLY_NO = i.APPLY_NO
WHERE i.HOSPITAL_ID = :hospital_id
  AND i.CHART_NO = :chart_no
  AND i.ORDER_DATE BETWEEN :start_date AND :end_date
ORDER BY i.ORDER_DATE DESC, i.ORDER_TIME DESC
```

### Chart → Patient (HO)

```sql
SELECT CHART_NO, PT_NAME, BIRTH_DATE, SEX
FROM CHART.CHART
WHERE HOSPITAL_ID = :hospital_id AND CHART_NO = :chart_no
```

### Chart → Outpatient and Emergency Notes (HO)

Run this once for each monthly schema of the date window, and once for `OPD`. Take the schema name from
`outpatient_schemas()` in `his_query.py`, never from user input.

```sql
SELECT p.CLINIC_DATE, p.DUPLICATE_NO, p.CLINIC_FLAG, d.DIV_SHORT_NAME, m.DOCTOR_NAME,
       o.SO_TYPE, o.SUB_TYPE, o.CONTENT
FROM OHISE09.PTOPD p
LEFT JOIN OHISE09.ORDSOOPD o
  ON o.HOSPITAL_ID = p.HOSPITAL_ID AND o.CHART_NO = p.CHART_NO
 AND o.CLINIC_DATE = p.CLINIC_DATE AND o.DUPLICATE_NO = p.DUPLICATE_NO
LEFT JOIN MAST.DIV d ON d.DIV_NO = p.DIV_NO
LEFT JOIN MAST.DOCTOR m ON m.HOSPITAL_ID = p.HOSPITAL_ID AND m.DOCTOR_NO = p.DOCTOR_NO
WHERE p.HOSPITAL_ID = :hospital_id AND p.CHART_NO = :chart_no
  AND p.CLINIC_DATE BETWEEN :start_date AND :end_date
ORDER BY p.CLINIC_DATE DESC, p.DUPLICATE_NO, o.SO_TYPE, o.SUB_TYPE;
```

### Chart → Discharge Summaries and Operations (HI)

```sql
SELECT h.DOCUMENT_NO, h.ADMIT_NO, h.ADMIT_DATE, h.DISCHARGE_DATE, h.CREATED_DATE, h.CONFIRMED_DATE
FROM DSR.DIAGDOCI h
WHERE h.CHART_NO = :chart_no              -- no HOSPITAL_ID predicate; no index uses it
ORDER BY h.CREATED_DATE_C;

SELECT x.SECTION_NO, x.SEQ, x.CONTENT, s.SECTION_NAME
FROM DSR.DIAGDOCIX x
LEFT JOIN DSR.DSRSECTION s
  ON s.DSR_TYPE = 'D' AND s.DIV_NO = '9999' AND RTRIM(s.SECTION_NO) = x.SECTION_NO
WHERE x.DOCUMENT_NO = :document_no        -- padded to 10 characters
ORDER BY x.SECTION_NO, x.SEQ;

SELECT p.OR_DATE, p.OR_DUPLICATE_NO, p.OR_IN_DATE, p.CANCEL_DATE, r.OR_SEQ, r.OR_NAME, r.OR_FINDINGS
FROM ORMS.PTOR p
LEFT JOIN ORMS.PTORDRPT r
  ON r.HOSPITAL_ID = p.HOSPITAL_ID AND r.OR_DATE = p.OR_DATE
 AND r.CHART_NO = p.CHART_NO AND r.OR_DUPLICATE_NO = p.OR_DUPLICATE_NO
WHERE p.HOSPITAL_ID = :hospital_id AND p.CHART_NO = :chart_no
  AND p.OR_DATE BETWEEN :start_date AND :end_date
ORDER BY p.OR_DATE DESC, p.OR_DUPLICATE_NO, r.OR_SEQ;
```

### Chart → Admissions and Inpatient Notes (HI)

```sql
SELECT ADMIT_NO, CUT_NO, STATUS, ADMIT_DATE, DISCHARGE_DATE
FROM IPD.IPDINDEX
WHERE CHART_NO = :chart_no;

SELECT ADMIT_NO, NOTE_DATE, NOTE_TIME, NOTE_TYPE, REMARK
FROM IDE.IPTPROGRESS1
WHERE CHART_NO = :chart_no
  AND NOTE_DATE BETWEEN :start_date AND :end_date
  AND NVL(DELETED_DATE, 0) = 0;

SELECT PROBLEM_NO, SECTION_TYPE, SEQ, CONTENT
FROM IDE.IPTPROGRESS3T
WHERE ADMIT_NO = :admit_no AND NOTE_DATE = :note_date AND NOTE_TIME = :note_time
ORDER BY PROBLEM_NO, SECTION_TYPE, SEQ;
```

Join the `SEQ` rows of one section with no separator. Section code order is not reading order.

---

## Sources found but not yet used by the app

Details, evidence, and proposed SQL: [`analysis/HIS_DEFERRED_WORKFLOW_FINDINGS_20261013.md`](../analysis/HIS_DEFERRED_WORKFLOW_FINDINGS_20261013.md).

| Data | Node | Tables | Path |
|---|---|---|---|
| Admission note document | HI | `DSR.DIAGDOCA`, `DSR.DIAGDOCAX`, `DSR.DSRSECTION` type `A` | Same index pattern |
| Gyn cytology text | HE | `LABMAST.LABDIAGNOSIS` (`SAMPLE_TYPE` `G`), `LABMAST.LABREASON`, `LABMAST.INFECTION` | From `LAP.LABG.RESULT_CODE`, `LAB_REASON_CODE`, `INFECTION_FLAG` |
| Nursing EMR documents | HI | `NISOP.NOTEDOCUMENT`, `NISOP.NOTEVERSION` | `ENCOUNTERID` = `ADMIT_NO`, with `SUBSYSTEM` named in the predicate |

---

## Open Questions

1. Roles of the `ONH`, `HB`, and `PPF` nodes.
2. That the legacy Progress Notes window reads `ORDSOOPD`. No capture shows the table name. The app uses it.
3. Where outpatient encounters older than 60 months are.
4. The XML layout of `NISOP.NOTEVERSION.CONTENT`.
5. The labels of the pathology request note types, and several status code meanings.

The full open list is in
[`analysis/HIS_DB_EXPLORATION_CHECKLIST_20261013.md`](../analysis/HIS_DB_EXPLORATION_CHECKLIST_20261013.md).
