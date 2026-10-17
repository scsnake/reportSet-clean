# HIS Workflow Query

Local FastAPI web app for chart/date searches reconstructed from the confirmed
HIS workflows in
[`analysis/confirmed_workflows/WORKFLOW_20260828.md`](analysis/confirmed_workflows/WORKFLOW_20260828.md).

## Current coverage

| Workflow | Query status | Identity used |
|---|---|---|
| Radiology and exam reports | Available | Both `EXAM` (non-radiology exams such as endoscopy) and `XRAY` (radiology); `HOSPITAL_ID + APPLY_NO`. Exam names come from `EXAMMAST.EXAMITEM` |
| Exam accession list | Available | `XRAY` chart/date register search; list keeps `REF_NO`, `ACCESS_NO`, and `APPLY_NO` separate |
| Accession search | Available | Both `EXAM` and `XRAY`; indexed `PTEXAMINDEX.ACCESS_NO`, no date range |
| Patient banner | Available | `CHART.CHART` on HO; `HOSPITAL_ID + CHART_NO` |
| Laboratory | Available | `LABX1` + `LABX2` by chart and `LAB_ORDER_DATE` in four schema families: `LAB`, `LABHIS` (history), `LAM` (microbiology), `LAMHIS`. Organisms and susceptibility from `LABM` |
| Pathology and cytology | Available | `LAP.LABP1` orders by chart; text from `LAP.LABS2` (surgical), `LAP.LABN` (non-gyn cytology), `LAP.LABG` (gyn cytology) by `HOSPITAL_ID + LAB_NO`. Gyn cytology results are codes only |
| Outpatient and emergency notes | Available | `PTOPD` on HO by `HOSPITAL_ID + CHART_NO + CLINIC_DATE`, in schema `OPD` and in each monthly `OHIS*` schema of the window; text from `ORDSOOPD` by the encounter key. 60 months are kept |
| Admissions | Available | `IPD.IPDINDEX` on HI by chart; admissions that overlap the date range |
| Inpatient notes | Available | `IDE.IPTPROGRESS1` on HI by chart and note date; body from `IDE.IPTPROGRESS3T` by `ADMIT_NO + NOTE_DATE + NOTE_TIME`. All note types, including admission notes |
| Discharge summaries | Available | `DSR.DIAGDOCI` on HI by chart; stays that overlap the date range, or documents written in it. Text from `DSR.DIAGDOCIX` by `DOCUMENT_NO`, sections named by `DSR.DSRSECTION` |
| Operation notes | Available | `ORMS.PTOR` on HI by `HOSPITAL_ID + CHART_NO + OR_DATE`; note text from `ORMS.PTORDRPT.OR_FINDINGS` by the full operation key |

No workflow is deferred now. The UI can still show a deferred workflow as greyed, and the API
answers it with 409. The app does not silently substitute a different document type.

The status of each data area is in
[`analysis/HIS_WORKFLOW_COVERAGE_AND_EXPLORATION_BRIEF_20261013.md`](analysis/HIS_WORKFLOW_COVERAGE_AND_EXPLORATION_BRIEF_20261013.md).
The sources found for the deferred workflows, with proposed SQL, are in
[`analysis/HIS_DEFERRED_WORKFLOW_FINDINGS_20261013.md`](analysis/HIS_DEFERRED_WORKFLOW_FINDINGS_20261013.md).

## Screen design

The screens are for a clinician who reads results. They follow these rules:

- No table, column, or schema name is shown. `tests/e2e_smoke.py` checks this.
- Each list shows clinical fields only. Administrative fields (accession number, order number,
  test code, status code, internal exam number) are behind the **i** button at the end of the row.
- The exam list has a filter: all exams, radiology only (`XRAY`), or other exams only (`EXAM`).
- The exam detail shows the report first, then the clinical information from the order, then the
  ordered items.
- The exam and pathology state comes from the date columns, because the status codes are not confirmed.
  An unset HIS date is `0000000`.
- A cancelled exam order stays in the list with a "Cancelled" mark. The mark needs the cancel flag and no
  exam date, because non-radiology exams that were done can also have the flag.
- An inpatient note with no signature date stays in the list with a "Not signed" mark. It is not hidden:
  it is usually one of the newest notes of the stay.
- Each laboratory specimen group has an icon. The icon is matched loosely from the specimen name
  (blood, urine, stool, and so on). It is a reading aid only.

Laboratory rows are displayed as a collapsible hierarchy:

```text
order date → specimen/source → laboratory category → order → test items
```

Specimen labels come from `LABMAST.SPECIMEN`; category labels come from
`LABMAST.LABGROUP`. Unknown codes remain visible under explicit fallback labels.

## Configuration

The app reads these variables from the process environment, `query_app/.env`, or
the parent `CH scripts/.env` file:

```text
HIS_DB_USER=
HIS_DB_PASSWORD=
HIS_DB_HOST_LAB=10.0.0.1
HIS_DB_PORT=1521
HIS_DB_SERVICE_LAB=he
HIS_HOSPITAL_ID=000
ORACLE_CLIENT_DIR=C:\instantclient_12_2
```

The clinical data is split across three nodes. `HIS_DB_HOST_LAB` is HE (radiology,
laboratory, pathology). These optional keys set the other two nodes; the defaults
are correct for this site:

```text
HIS_DB_HOST_PATIENT=10.0.0.1
HIS_DB_SERVICE_PATIENT=ho
HIS_DB_HOST_IPD=10.0.0.1
HIS_DB_SERVICE_IPD=hi
```

All three nodes use the same account and port.

Do not commit the `.env` file. The browser UI is intended to be bound to
`127.0.0.1`; authentication for multi-user or network deployment is not yet
implemented.

## Run

```powershell
uv sync
uv run uvicorn app:app --host 127.0.0.1 --port 8000
```

Then open <http://127.0.0.1:8000>. `run.bat` runs the same command.

## API

- `GET /api/health` — configuration state (does not perform a database login)
- `GET /api/workflows` — confirmed/deferred workflow map
- `GET /api/search/{workflow}?chart_no=...&start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`
- `GET /api/radiology/{source}/{hospital_id}/{apply_no}` — selected-study `items`, `remarks`, and `reports` rows, plus
  `report_sections` (continuation parts joined) and `clinical` (coded diagnoses and free-text notes)
- `GET /api/exam-accessions/{hospital_id}/{apply_no}` — item/master detail for a selected exam-register row
- `GET /api/accession/{accession_no}` — exams with this accession number, each with items, remarks, and report sections
- `GET /api/patient/{chart_no}` — patient banner fields; `found` is false for an unknown chart
- `GET /api/inpatient-notes/{admit_no}/{note_date}/{note_time}` — sections of one inpatient note
- `GET /api/discharge-summaries/{document_no}` — named sections of one discharge summary

Available search workflow IDs are `radiology`, `exam_accession`, `laboratory`, `pathology`,
`opd_note`, `admission`, `inpatient_note`, `discharge_summary`, and `operation_note`.
An `opd_note` row is one visit with `kind` (`outpatient` or `emergency`), `has_note`, and its `sections`.
A `discharge_summary` row is one document with `state` (`confirmed` or `draft`). An `operation_note` row is
one operation with its `procedures`, `diagnoses`, `note`, and `state` (`noted`, `recorded`, `performed`,
`scheduled`, `cancelled`).
A `radiology` row has `exam_name`, `category` (`radiology` or `other`), and `state`
(`reported`, `examined`, `scheduled`, `ordered`). A `pathology` row is one order with `kind`, `state`,
and its `sections`.
Database work runs off the async event loop, values use Oracle binds, and API
errors do not expose Oracle exception text.

### Migration from the previous API

The workflow API replaces `/api/query`, `/api/accession-inquiry`, and
`/api/schema-info`. These older routes are no longer available.
Update callers to use the chart/date workflow routes listed above.
The exam accession workflow lists studies by chart. To search by accession number, use
`GET /api/accession/{accession_no}`.

The accession search reads `PTEXAMINDEX.ACCESS_NO`, which HIS fills when the exam is
performed. An order that is not yet examined is not found. Every key bind is padded to
the width of its `CHAR` column; a stripped key matches no row.

The patient banner selects name, sex, birth date, blood type, and last-visit dates only.
It does not select the national ID, telephone, or address columns.

Inpatient note sections are ordered S, O, A, P by the app. Other section codes follow
without a label. Deleted notes (`DELETED_DATE` not 0) are not listed.

Outpatient data is split by month on HO. Schema `OHIS<letter><MM>` holds one calendar month, and the letter
(none, `B`, `C`, `D`, `E`) follows the ROC year in a 5-year cycle that starts at year 111. The search runs one
statement for each month of the window and one for the live schema `OPD`, all on one connection; a 2-year
window is 26 statements and takes about half a second. Each statement keeps the `CLINIC_DATE` range, because a
schema is reused after 5 years. Visits older than 60 months are not in these schemas.
The section labels of an emergency note (chief complaint, vital signs, and so on) are inferred from the
template table `MAST.ER_SOSO`. No capture shows that the legacy Progress Notes window reads `ORDSOOPD`.

The discharge summary and operation note sources come from data-dictionary and live checks, not from a
capture of the legacy screens. The operation state comes from facts in the row: a note text, a cancel date,
a report row, or a room-in date. Operations before about 2021 often have no note text in the database.

## Verification

```powershell
uv run python -m unittest discover -s tests -v
```

The unit suite locks in direct indexed predicates, the dual radiology schemas,
the `XRAY` exam-register mapping, hospital-aware composite joins, date conversion,
workflow availability, endpoint dispatch, laboratory grouping, and error
sanitization. `tests/e2e_smoke.py` is a Playwright browser
smoke test with mocked, non-patient result rows.

Install the browser test dependencies once:

```powershell
uv sync --group dev
uv run playwright install chromium
```

Start the app on `127.0.0.1:8000`, then run the smoke test in another terminal:

```powershell
uv run python tests/e2e_smoke.py
```

Set `QUERY_APP_URL` to test an app on a different address.
The smoke test mocks patient search and detail responses.
The app still needs an installed Oracle Instant Client to start.

The app applies an explicit `LAB_ORDER_DATE` range for laboratory and pathology
searches. `ORDER_DATE` is not usable: it is `0000000` on about 9 of 10 laboratory orders
and on every gynecologic cytology order. The legacy lab GUI's exact hidden date-filter
mechanism remains unobserved, as documented in the workflow capture.

The laboratory test name comes from `LABMAST.LABITEM1` by the item's `LAB_CODE`. The item's
`CODE` column is blank on more than half of the rows.

An order from an outside source can store a chart number that is shorter than 10 digits.
A search by hospital chart number does not find such an order.

## Documentation

- [`docs/oracle_schema.md`](docs/oracle_schema.md) — schema reference: node map, keys, `CHAR` key rule, query templates.
- [`docs/infrastructure.md`](docs/infrastructure.md) — servers and network paths.
- [`docs/his_architecture.md`](docs/his_architecture.md) — legacy HIS application structure and timing.
- [`analysis/HIS_DB_TABLE_NOTES_20261013.md`](analysis/HIS_DB_TABLE_NOTES_20261013.md) — data-dictionary evidence.
- [`analysis/HIS_LIVE_QUERY_VERIFICATION_20261013.md`](analysis/HIS_LIVE_QUERY_VERIFICATION_20261013.md) — live test record, counts only.
- [`analysis/HIS_DB_EXPLORATION_CHECKLIST_20261013.md`](analysis/HIS_DB_EXPLORATION_CHECKLIST_20261013.md) — open database questions.

- [`analysis/DOC_STALENESS_REVIEW_20261013.md`](analysis/DOC_STALENESS_REVIEW_20261013.md) — which files are current, stale, or uncertain.

[`legacy/`](legacy/README.md) holds the exploratory scripts and the retired apps from earlier sessions.
The web app does not use them, and several use wrong table names.

## Mobile system read-only CLI/API

All chart numbers below are synthetic examples. Do not query them on a live system.

`mobile_api.py` is a separate, cookie-backed client for the hospital mobile
rounding system at `http://im.hospital-c.local:8080/mobile/`. It reads `user` and `pw`
from `.env`, logs in with a transient `JSESSIONID`, and enforces an explicit
allowlist of query-only routes. The upstream service uses plaintext HTTP, so run
it only on a trusted hospital network; credentials and returned patient data are
not encrypted in transit.

Set `MOBILE_USER` and `MOBILE_PASSWORD` in `query_app/.env`.
The legacy `user` and `pw` keys are also accepted.
For credentials in the parent `.env`, put `--env-file ..\.env` before the subcommand.

```powershell
# Verify login without selecting a patient
uv run python src/mobile_cli.py auth

# List the discovered read-only HTTP contracts (does not log in)
uv run python src/mobile_cli.py routes

# Find admissions in the order shown by the mobile system
uv run python src/mobile_cli.py admissions 0000012345

# Enter admission row 0, then return div#page-show and div#Menubar
uv run python src/mobile_cli.py tabs 0000012345 --admission-index 0

# Query one patient section; admission index 0 is the first/current result
uv run python src/mobile_cli.py --output mobile-output.json section 0000012345 laboratory
uv run python src/mobile_cli.py section 0000012345 xray --admission-index 1

# Retrieve every data tab discovered inside div#Menubar in one session
uv run python src/mobile_cli.py --output mobile-output.json all 0000012345

# TPR/IO and cumulative lab iframe APIs
uv run python src/mobile_cli.py tpr 0000012345
uv run python src/mobile_cli.py lab-accumulate 0000012345 LAB_NUMBER
```

Nested AJAX detail calls are exposed through `fetch`. Query output contains an
`actions` array with the method, path, and exact parameters needed for these
calls. Examples:

```powershell
uv run python src/mobile_cli.py fetch 0000012345 /mobile/lab/show --method POST --param labNo=LAB_NUMBER
uv run python src/mobile_cli.py fetch 0000012345 /mobile/xray/show --method POST --param applyNo=APPLY_NUMBER
uv run python src/mobile_cli.py fetch 0000012345 /mobile/pomr/detail --method POST --param pomrIdx=ROW_INDEX
```

Output defaults to parsed UTF-8 JSON (`text`, `tables`, `links`, and AJAX
`actions`). Use `--format text` for visible text, `--format html` for the exact
upstream fragment, or `--output FILE` to avoid printing large reports. Global
options must appear before the subcommand.

The same implementation is importable as a Python API:

```python
from mobile_api import MobileClient, credentials_from_env

user, password = credentials_from_env(".env")
client = MobileClient(user, password)
search_page, admissions = client.search_admissions("0000012345")
context = client.enter_admission("0000012345", index=0)
basic_info = context.patient_basic_info  # parsed only from div#page-show
tabs = context.tabs                     # parsed only from div#Menubar
admission, response = client.query_section("0000012345", "laboratory")
document = response.document()  # text, tables, links, and AJAX actions
```
