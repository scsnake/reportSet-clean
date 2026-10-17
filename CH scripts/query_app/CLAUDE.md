# CLAUDE.md — query_app project knowledge

> Read this first. It encodes ground-truth domain knowledge so you don't have to re-derive it from captures.

---

## What This Project Does

Two parallel research tracks:

1. **RIS→PACS interaction analysis** (`analysis/`) — AHK + tshark tooling to capture and document the full process chain when a radiologist clicks "open image" in the web-based RIS (IE) and INFINITT PACS loads the study.
2. **HIS Oracle query app** (`app.py`, `his_query.py`, `index.html`) — FastAPI web app that queries the Hospital Information System's Oracle databases directly, reverse-engineered from packet captures.

---

## Network Topology

```
Workstation (10.0.0.1 / 192.0.2.10 on PACS VLAN)
    │
    ├─[HTTP]──────────────────────► RIS Web   10.0.0.1:9090   /webcvis/
    │
    ├─[WADO/HTTP direct LAN]──────► PACS image server  192.0.2.10:80
    │                                 GET /Image01/YYYYMMDD/StudyUID/ImageUID.dcm
    │
    ├─[HTTP metadata]─────────────► PACS mgmt  192.0.2.10:80  (gpu-host.example.invalid, INFINITT server)
    │   (NOTE: 192.0.2.10 is a Tailscale node — see Tailscale warning below)
    │
    └─[Oracle TNS Port 1521]───────► HIS Database cluster
          ├─► HO  10.0.0.1  SID=ho   (Patient master — CHART.CHART; OPD encounter lists)
          ├─► HE  10.0.0.1  SID=he   (Radiology, lab, pathology — EXAM/XRAY/LAB/LAP schemas)
          ├─► HI  10.0.0.1  SID=hi   (Admissions and inpatient notes — IPD/IDE schemas)
          └─► ONH 10.0.0.1, HB 10.0.0.1, PPF 10.0.0.1   (roles unverified — no probed clinical table)

HIS App Server (SMB2):  \\10.0.0.1\Relexe\HOSPITAL\   (executables streamed at runtime)
HIS Log/Config Server:  \\10.0.0.1\Settings\Exam\PACS.Ini  +  \ExamLog\  +  \EventLog\
```

---

## RIS → PACS Calling Chain (fully captured 2026-03-26)

```
User clicks study in RIS (IE tab, iexplore.exe pid=25284)
│
├─ IE navigates to openimg.jsp (same iexplore.exe, new IEFrame hwnd)
│   URL: http://10.0.0.1:9090/webcvis/MJB/openimg.jsp?imgurl=...
│   Lifetime: ~2 s  →  RUDE_ACTIVATE #1 (focus steal)
│
│   imgurl parameter (double-URL-decoded):
│     C:\INFINITTG3\VIEWER\G3Launcher.exe  http://192.0.2.10+[userID]+[PASSWORD]+[?]+[type]+[studyID]+++
│   ⚠️  PACS password is in PLAINTEXT in this GET URL (visible in browser history, server logs, pcap)
│
├─ Java applet CallClient.jar (from /webcvis/MJB/CallClient.jar) launches:
│
└─ G3Launcher.exe  C:\INFINITTG3\VIEWER\G3Launcher.exe
    Lifetime: ~330–650 ms  →  RUDE_ACTIVATE #2
    Performs blocking HTTP calls to 192.0.2.10 during session setup
    │
    └─ Starter.exe  C:\ProgramData\infstarter\Starter.exe
        Receives:  infstarter:///?su=<zlib+base64 study params>
        Lifetime: ~6 ms  →  RUDE_ACTIVATE #3
        Decodes payload, writes study params to temp .tmp files:
          /us:C:\INFINITTG3\VIEWER\<uuid>.tmp   (user session)
          /op:C:\INFINITTG3\VIEWER\<uuid>.tmp   (open params)
        │
        ├─ SmartUpdate.exe  C:\INFINITT\Smartupdate\Smartupdate.exe
        │   →  RUDE_ACTIVATE #4   Does NOT self-destruct — persists (needs SW_HIDE)
        │
        └─ G3PACS.exe  C:\INFINITTG3\VIEWER\G3PACS.exe   (already running)
            Args: /us:<uuid>.tmp  /op:<uuid>.tmp
            →  RUDE_ACTIVATE (legitimate — study loaded)
```

**infstarter:// payload decoder**: `python src/decode_infstarter.py "eJyF..."` — zlib-decompresses the base64 payload to reveal study fields.

**Focus-steal summary** (for FocusLock.ahk):

| # | Process | Class | Suppress strategy |
|---|---|---|---|
| 1 | `iexplore.exe` openimg.jsp hwnd | `IEFrame` | SW_HIDE that specific hwnd only — NOT the main RIS IEFrame |
| 2 | `G3Launcher.exe` | `#32770` | SW_HIDE on CREATE |
| 3 | `Starter.exe` | `#32770` | SW_HIDE on CREATE |
| 4 | `SmartUpdate.exe` | `#32770` | SW_HIDE on CREATE |
| ✓ | `G3PACS.exe` | Afx:00400000:... | ALLOW — legitimate activation |

---

## PACS Image Retrieval — Protocol Reality

**NOT DICOM DIMSE (port 104).** INFINITT uses HTTP:

- **Image data**: `GET http://192.0.2.10/Image01/YYYYMMDD/StudyUID/ImageUID.dcm` (WADO-style)
- **Metadata/session**: POST to `http://192.0.2.10/WDOServer2/WDOLibrary.Service.svc` (×6 calls)
- **SmartUpdate**: POST to `http://192.0.2.10/webservices/smartupdate.asmx` (×3 calls)

Both `192.0.2.10` and `192.0.2.10` are on the PACS VLAN (`192.0.2.10/24`). The PACS NIC (`NPF_{5B7D...}`) is the right capture interface for this traffic.

---

## ⚠️ Tailscale DERP Relay Warning

`192.0.2.10` (gpu-host.example.invalid, INFINITT PACS server) **is a Tailscale node** (Tailscale IP: `192.0.2.10`).

When Tailscale is active on the workstation, all TCP connections to `192.0.2.10` are routed through a DERP relay at `127.0.0.1:55761` (RTT 266 ms) instead of the direct LAN path. This causes:

| Condition | G3PACS load time | DICOM throughput |
|---|---|---|
| Tailscale ON | ~12 s (via DERP relay) | 3.5 Mbps |
| Tailscale OFF | ~4–8 s (direct LAN) | 58–120 Mbps |

**Fix**: Disable Tailscale during reporting sessions, or configure subnet routing for `192.0.2.10/24`.

---

## Oracle Schema — GROUND TRUTH (verified 2026-04-09, corrected 2026-10-13)

Full reference: `docs/oracle_schema.md` and `analysis/HIS_DB_TABLE_NOTES_20261013.md`.

### ⛔ WRONG — Do NOT use these
- `OPD.PTLABRESULT`, `OPD.PTEXAMRESULT`, `OPD.PTLAXRESULT` ← not on HE; on HO they are only a two-day working set, not the result store
- `MAST.PATIENT` ← does not exist on HO, HE, or HI; the patient master is `CHART.CHART` on HO
- `CHART.PTHISMEDICAL` ← does not exist on HO, HE, or HI
- `WHERE e.REF_NO = :accession` ← `PTEXAM.REF_NO` has no index; look up `PTEXAMINDEX.ACCESS_NO`
- `PTEXAM.RESULT` / `PTEXAM.EXCERPT` as report text ← `RESULT` is a CHAR(1) flag, `EXCERPT` is empty; the text is `PTEXAMRPT.CONTENT`

The April 2026 root-level notes that used these were removed on 2026-10-13. Many scripts in `legacy/` still use them — do not copy SQL from those scripts.

### ⚠️ CHAR key rule
Every key column is blank-padded CHAR (`HOSPITAL_ID` 3, `CHART_NO` 10, `APPLY_NO` 20, `ACCESS_NO` 20,
`ADMIT_NO` 10). A stripped value bound to a CHAR column matches **no row**. Pad each key bind to the
column width (`pad_char_key` in `his_query.py`). `EXAM.PTEXAMREMARK.APPLY_NO` is CHAR(15), not 20.

### ✅ CORRECT Schema (HE node: 10.0.0.1)

**EXAM schema** — radiology/imaging exams:
| Table | Rows | Key columns |
|---|---|---|
| `EXAM.PTEXAM` | 4.1M | `HOSPITAL_ID` + `APPLY_NO`, `REF_NO` (accession, set at order time, no index), `ID_NO` (patient), `PT_NAME` |
| `EXAM.PTEXAMREMARK` | 25.2M | `APPLY_NO`, `REMARK_TYPE`, `CONTEXT` (clinical indication text) |
| `EXAM.PTEXAMINDEX` | 4.1M | `HOSPITAL_ID` + `APPLY_NO`, `CHART_NO`, `ACCESS_NO` (accession, set at exam time, indexed), ROC date columns |
| `EXAM.PTEXAMRPT` | 8.7M | Report sections — `CAPTION`, `CONTENT` (the report text) |

**XRAY schema** — identical structure to EXAM:
| Table | Rows |
|---|---|
| `XRAY.PTEXAM` | 5.3M |
| `XRAY.PTEXAMREMARK` | 27.7M |
| `XRAY.PTEXAMINDEX` | 5.3M |

**LAB / LAP schemas** — lab and pathology results (columns in `docs/oracle_schema.md`):
| Table | Rows | Key |
|---|---|---|
| `LAB.LABX1` | 9.2M | Order header — `HOSPITAL_ID` + `LAB_NO` (VARCHAR2(15), no padding); holds `CHART_NO`. Filter on `LAB_ORDER_DATE`, never `ORDER_DATE` (unset on about 9 of 10 orders) |
| `LAB.LABX2` | 68.9M | Items — `HOSPITAL_ID` + `LAB_NO` + `UNIQUE_SEQ` + `LAB_CODE`; value in `RESULT_DESCRIPTION`. Join `LABMAST.LABITEM1` on `LAB_CODE` (the `CODE` column is often blank) |
| `LABHIS.*`, `LAM.*`, `LAMHIS.*` | — | Same `LABX1`/`LABX2` shape: lab history (to about 2021-04), microbiology, microbiology history. `LAM.LABM` holds organisms and susceptibility |
| `LAP.LABP1` | 0.8M | Pathology order header for three families (`PATHOLOGY_TYPE`): `S` surgical, `N` non-gyn cytology, `G` gyn cytology |
| `LAP.LABS2` / `LAP.LABN` / `LAP.LABG` | — | Report text of family `S` / `N` / `G`, joined on `HOSPITAL_ID` + `LAB_NO`. `LABG` holds codes, not text |
| `LABEXCHANGE.LABRPT01` | 1.9M | Columns not verified |

### Key identifier relationships
- `PTEXAM.REF_NO` = `PTEXAMINDEX.ACCESS_NO` = **PACS accession number** when both are set
- `REF_NO` is set at order time; `ACCESS_NO` is set when the exam is performed and is the indexed one
- XRAY accession: 11 digits (ROC date prefix). EXAM accession: 2–5 upper-case letters + digits
- `APPLY_NO` = internal HIS exam identifier (joins PTEXAM ↔ PTEXAMREMARK ↔ PTEXAMINDEX, always with `HOSPITAL_ID`)
- `CHART_NO` is in `PTEXAMINDEX`, not in `PTEXAM` main table
- `ID_NO` = patient national ID / hospital ID

### Canonical query: accession → exam → clinical indication
```sql
SELECT i.HOSPITAL_ID, i.APPLY_NO, i.CHART_NO, i.ACCESS_NO, e.REF_NO
FROM XRAY.PTEXAMINDEX i
JOIN XRAY.PTEXAM e ON e.HOSPITAL_ID = i.HOSPITAL_ID AND e.APPLY_NO = i.APPLY_NO
WHERE i.HOSPITAL_ID = :hospital_id
  AND i.ACCESS_NO = :access_no      -- padded to 20 characters; use EXAM for a letter prefix

SELECT REMARK_TYPE, SEQ, CODE, CONTEXT
FROM XRAY.PTEXAMREMARK
WHERE HOSPITAL_ID = :hospital_id AND APPLY_NO = :apply_no
```

### HO node (10.0.0.1) — patient master
- `CHART.CHART` — key `HOSPITAL_ID` + `CHART_NO`; `PT_NAME`, `ID_NO`, `BIRTH_DATE` (`+YYYMMDD`, ROC), `SEX`, `BLOOD_TYPE`
- `CHART.CHARTNOTE` — chart-level notes
- `CHART.PTBODYMEASURE`, `CHART.PTVITALSIGN` — exist on HO; chart index; not used by the app
- `PTOPD` (visit) + `ORDSOOPD` (note text, one row per `SO_TYPE` + `SUB_TYPE`) — in schema `OPD` (open and future visits)
  and in 60 monthly schemas `OHIS<letter><MM>`; letter = none/`B`/`C`/`D`/`E` by `(ROC year - 111) mod 5`. Always keep the
  `CLINIC_DATE` range; use `outpatient_schemas()` and `outpatient_note_sql()` in `his_query.py`, never a schema name from input
- `MAST.DIV` (key `DIV_NO`) and `MAST.DOCTOR` (key `HOSPITAL_ID` + `DOCTOR_NO`) — division and doctor names

### HI node (10.0.0.1) — admissions and inpatient notes (no `HOSPITAL_ID` column)
- `IPD.IPDINDEX` — admissions; key `ADMIT_NO` + `CUT_NO`; `CHART_NO` indexed; `DISCHARGE_DATE` `0000000` = still in hospital
- `IDE.IPTPROGRESS1` — note header; key `ADMIT_NO` + `NOTE_DATE` + `NOTE_TIME`; indexed on `(CHART_NO, NOTE_DATE, NOTE_TIME)`
- `IDE.IPTPROGRESS3T` — note body (13.5M rows); always bind the full note identity
- `IDE.PROGRESSNOTETYPE` — note types (`P` progress, `A` admission, `D` discharge summary, `J`/`K` operation)
- `DSR.DIAGDOCI` — discharge summary header; key `DOCUMENT_NO`; indexed on `(CHART_NO, CREATED_DATE_C)`; `ADMIT_DATE`/`DISCHARGE_DATE` are NUMBER(7)
- `DSR.DIAGDOCIX` — discharge summary text; key `DOCUMENT_NO` + `SECTION_NO` + `SEQ`; join `SEQ` parts with no separator; section names in `DSR.DSRSECTION` (`DSR_TYPE` `D`)
- `ORMS.PTOR` — operation list (has `HOSPITAL_ID`); indexed on `(HOSPITAL_ID, CHART_NO, OR_DATE, OR_DUPLICATE_NO)`
- `ORMS.PTORDRPT` — one row per procedure; note text in `OR_FINDINGS` only; no chart-led index, so reach it through the `PTOR` key

### DB connection template
```python
import oracledb
oracledb.init_oracle_client(lib_dir=r"C:\instantclient_12_2")  # thick mode required
dsn = f"(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST={host})(PORT=1521))(CONNECT_DATA=(SID={sid})))"
conn = oracledb.connect(user=user, password=password, dsn=dsn)  # HIS_DB_USER / HIS_DB_PASSWORD from CH scripts/.env
```

---

## HIS Application Architecture

- **Shell**: `MENU_1120621.EXE` ver 105.4.20 (VB6, class `ThunderRT6FormDC`)
- **Launch**: `\\gpu-host.example.invalid\Relexe\HOSPITAL\Utility\Exe\` via SMB2 — entire exe streamed at runtime
- **Credentials**: Read from `\\gpu-host.example.invalid\HOSPITAL\PFILE\pwdKS1.txt` via unencrypted SMB2 at startup and before each sub-module launch
- **Sub-modules** (also SMB-streamed on demand):
  - `ILABRPT.EXE` — lab results query (~3 s load)
  - `IQuery_Ver1110420.exe` — history/treatment query (~2 s load)
  - `Kardeuse2_Ver1110519.exe` — history/prevention/exam follow-up (⚠️ ~3.5 min load — 102 s SMB binary stream + 65 s OCX init + 43 s auth; has its OWN login dialog)
  - `KPTOR.EXE` — pending items / protection needs (~2 s load)

### ⚠️ Security findings (documented, not remediated)
1. `pwdKS1.txt` — Oracle credentials in plaintext over unencrypted SMB2 (site KS1 = 新耕醫院)
2. Oracle TNS (port 1521) — all queries unencrypted; patient IDs visible in raw pcap
3. PACS password in plaintext in HTTP GET URL (`openimg.jsp?imgurl=...+[password]+...`)
4. HIS app binaries (~119 MB) streamed from open SMB share — no signature verification

---

## Tshark / Network Capture Interfaces

| Interface GUID | Network | What to capture |
|---|---|---|
| `NPF_{5B7D693E-4B7F-4C90-B24D-71DC9D8704AD}` | PACS VLAN (`192.0.2.10/24`) | WADO image download, PACS HTTP |
| `NPF_{3F1ED1C0-497C-4A19-903D-45FC4636C6D4}` | HIS/RIS (`172.16.x.x`) | RIS HTTP, Oracle TNS, SMB2, HIS app traffic |

DICOM does NOT flow on port 104 — do not filter for it.

For HIS-only Oracle captures, filter: `tcp port 1521` on HIS interface. Avoids 119 MB of SMB2 app binary noise.

---

## File Layout

```
query_app/
├── CLAUDE.md                   ← this file
├── analysis/
│   ├── RIS_PACS_capture.ahk    ← main capture tool (AHK v1, AutoHotkeyU64.exe)
│   │                              F10=start  F11=stop  F12=marker  Esc=exit
│   ├── calling_chain.md        ← AUTHORITATIVE RIS→PACS process chain doc
│   ├── PLAN.md                 ← 3-phase research plan (April 2026; not kept current)
│   ├── confirmed_workflows/WORKFLOW_20260828.md   ← HIS workflow captures the app is built from
│   ├── HIS_DB_TABLE_NOTES_20261013.md             ← live dictionary evidence: keys, indexes, type traps
│   ├── HIS_LIVE_QUERY_VERIFICATION_20261013.md    ← live test record of the app (counts only)
│   ├── HIS_DB_EXPLORATION_CHECKLIST_20261013.md   ← open database questions
│   ├── HIS_WORKFLOW_COVERAGE_AND_EXPLORATION_BRIEF_20261013.md   ← what the app covers; brief for more exploration
│   ├── DOC_STALENESS_REVIEW_20261013.md           ← which files are current, stale, or uncertain
│   ├── dump_proctree.ps1       ← process snapshot helper
│   ├── list_interfaces.bat     ← tshark interface discovery
│   └── logs/                   ← captures: win.log + proc_*.txt + net_*.pcapng (not committed)
├── src/
│   ├── decode_infstarter.py    ← CLI: decode infstarter:// zlib+b64 payload
│   ├── cli.py                  ← unified CLI entry point (oracle/pcap/decode subcommands)
│   └── mobile_cli.py           ← CLI for the mobile rounding system (see README)
├── docs/
│   ├── oracle_schema.md        ← the schema reference (HO/HE/HI tables, keys, query templates)
│   ├── infrastructure.md       ← IP/service topology
│   └── his_architecture.md     ← HIS app architecture + timing data
├── README.md                   ← how to run, configure, and test the web app; API routes
├── app.py                      ← FastAPI web app (routes only) — the current app
├── his_query.py                ← SQL, node routing, CHAR key padding, row shaping — the current query layer
├── index.html                  ← web UI
├── tests/                      ← unittest suite + Playwright smoke test (mocked rows)
├── mobile_api.py               ← separate client for the mobile rounding system
├── mount_drives.ps1            ← started by a logon scheduled task — do not move
├── pyproject.toml / uv.lock    ← Python project (uv)
└── legacy/                     ← 40 exploratory scripts and the retired apps (app_radiology.py,
                                   radiology_queries.py, app_updated.py). Not used. Many hold wrong
                                   table names. Read legacy/README.md before you open one.
```

The schema reference is `docs/oracle_schema.md`. Analysis notes hold counts, column names, and index names only — never a chart number, an accession number, a patient name, or report text.

---

## Tech Stack

- **Python**: `oracledb` (thick mode, `C:\instantclient_12_2`), `fastapi`, `uvicorn`, `starlette`, `pydantic`
- **AHK**: v1 (AutoHotkeyU64.exe) for capture and PACS workflow automation
- **Network**: tshark (Wireshark CLI) for pcap; Wireshark GUI for analysis
- **Run**: `uv run uvicorn app:app --host 127.0.0.1 --port 8000`

---

## Open Questions (as of 2026-10-13)

1. Kardeuse2 sub-login — does it reuse `pwdKS1.txt` credentials? (automatable?)
2. Where are the discharge summary body (`DSR`), the operation narrative (`ORMS`), and the OPD note body?
3. Roles of the `ONH`, `HB`, and `PPF` nodes.

The full database list is in `analysis/HIS_DB_EXPLORATION_CHECKLIST_20261013.md`.

---

## Web UI rules (set by the user, 2026-10-13)

- The screens are for a clinician. Do not show table, column, or schema names.
- Show only fields a clinician needs. Put administrative fields (codes, order numbers, accession
  numbers, status codes) behind the row's **i** button or the "Administrative details" block.
- `XRAY` is radiology. `EXAM` is non-radiology exams such as endoscopy. The exam list has a filter for this.
- Detail views are reader-oriented: report text first, then clinical information, then ordered items.
- Do not print a raw key-value dump of a database row.
- Do not hide a cancelled exam order or an unsigned inpatient note. Mark it ("Cancelled", "Not signed").
