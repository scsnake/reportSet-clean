# HIS Application Architecture

> Distilled from captures: `analysis/logs/20260326_122300_run_01/analysis.md` and `run_02/analysis.md`

---

## Shell Application

| Property | Value |
|---|---|
| Exe | `MENU_1120621.EXE` ver 105.4.20 |
| Technology | VB6 (`ThunderRT6FormDC`) |
| Launch path | `\\gpu-host.example.invalid\Relexe\HOSPITAL\Utility\Exe\MENU_1120621.Exe` |
| Site ID | KS1 (新耕醫院 — 新進系統) |
| Operator | `000000` (observed), Station: `RAD-D6` |

The shell and all sub-modules are streamed from `\\gpu-host.example.invalid\relexe` via SMB2 at runtime. There is no local installation. Total binary transfer on first launch: **~119 MB** of `.exe`, `.dll`, `.ocx` files.

---

## Credential Handling (⚠️ insecure)

`HOSPITAL\PFILE\pwdKS1.txt` is read via SMB2 (plaintext, port 445) at:
- Application startup
- Before each sub-module launch
- Multiple times during session (5+ reads observed in a 4-minute session)

This file contains Oracle DB credentials used for TNS connections. Readable by any host on the `172.19.x.x` subnet that can reach `\\gpu-host.example.invalid\relexe`.

---

## Sub-Modules (all SMB-streamed on demand)

| Exe | Title (zh) | Load time | Oracle nodes | Notes |
|---|---|---|---|---|
| `ILABRPT.EXE` | 檢驗(查)可查詢 — Lab results | ~3 s | .137, .138, .140 | Fast; patient ID in TNS frames |
| `IQuery_Ver1110420.exe` | 歷程/處置查詢 — History/treatment | ~2 s | .137, .138 | Fast; ~17 s query time |
| `Kardeuse2_Ver1110519.exe` | 歷程系統及預防/檢查需求/後續作業 | **~3 min 30 s** | .137, .138, .139, .140 | ⚠️ Extremely slow — see below |
| `KPTOR.EXE` | 代辦事項/保護需求作業 | ~2 s | .137, .138, .139, .140 | Fast; fan-out to all 4 nodes |

### Kardeuse2 load breakdown (3 min 30 s total)

| Phase | Duration | Cause |
|---|---|---|
| Menu select → first window | **102 s** | SMB2 binary streaming (exe + OCX dependencies) |
| First window → login dialog | **65 s** | OCX init + Oracle connections to all 4 nodes |
| Login dialog → ready | **43 s** | Separate authentication dialog (has own login!) |
| **Total** | **~210 s** | |

> Note: Kardeuse2 has its own login dialog separate from the MENU shell. The operator (000000) must re-authenticate. May reuse `pwdKS1.txt` credentials — not yet confirmed.

---

## Oracle TNS Connection Pattern

All sub-modules fan out to multiple DB nodes simultaneously (parallel TNS SYN bursts):

```
MENU startup burst:   .137, .138, .139, .140 (8+ SYNs in <7 s)
Sub-module trigger:   .137, .138 (reconnect before module appears)
ILABRPT active:       .137, .138, .140 (parallel lab queries)
IQuery active:        .137, .138
Kardeuse2 active:     .137, .138
KPTOR active:         .137, .138, .139, .140 (all nodes)
```

Single logical patient query fans out across 3–4 Oracle servers — federated patient record lookup spanning lab and clinical databases.

---

## Observed Oracle Query Timing (run_01, one test patient)

| Mark | Clock | Module | Interpretation |
|---|---|---|---|
| QM1 | 12:23:13 | MENU | Menu navigation |
| QM2 | 12:23:20 | MENU | Sub-module select |
| QM3 | 12:23:24 | MENU | Triggers Oracle reconnect |
| QM4 | 12:23:46 | ILABRPT | Lab viewer loaded (3 s after CREATE) |
| QM5 | 12:23:56 | ILABRPT | Patient query submitted |
| QM6–9 | 12:24:01–11 | ILABRPT | Result tabs 1–4 loaded |
| QM10 | 12:24:45 | IQuery | History viewer loaded (2 s) |
| QM11 | 12:25:02 | IQuery | Patient history result (~17 s query) |

---

## Second File Server (10.0.0.1)

Accessed for:
- `\Settings\Exam\PACS.Ini` — PACS configuration (read at module init)
- `\ExamLog\TimeLog\RAD-D6\YYYYMMDD.Txt` — append-only daily timing log (written repeatedly)
- `\EventLog\HospMsg\HospMsgSvr_LAB\RAD-D6\` — lab notification events

---

## Network Traffic Summary (run_01, 4 min 32 s)

| Protocol | Volume | Key finding |
|---|---|---|
| SMB2 → `10.0.0.1:445` | **119 MB** | App binary streaming |
| Oracle TNS → .137/.138/.139/.140:1521 | 9.9 MB | All queries **unencrypted** |
| SMB2 → `10.0.0.1:445` | 1.4 MB | Logs + settings |
| TLS → `127.0.0.1:443` | 7.7 KB | INFINITT telemetry (same as PACS) |

---

## Security Findings

1. **Plaintext credentials over SMB**: `pwdKS1.txt` read 5+ times per session, unencrypted
2. **Unencrypted Oracle TNS**: all patient queries (including patient ID, lab values) visible in pcap
3. **No binary signing**: 119 MB of executables streamed from open SMB share; substitution attack possible
4. **PACS password in RIS URL**: `openimg.jsp?imgurl=...+[password]+...` visible in access logs and pcap
5. **Second SMB server**: PACS config (`PACS.Ini`) and exam logs accessible without auth challenges

---

## TODO from Captures

- [ ] Confirm whether Kardeuse2 sub-login reuses `pwdKS1.txt` credentials
- [ ] Re-run KPTOR with a patient that has a record — capture full query flow
- [x] Map `LAB.LABX2` column structure — done from the data dictionary on 2026-10-13; see `docs/oracle_schema.md`
- [x] Investigate `CHART.PTHISMEDICAL` — closed 2026-10-13: the table does not exist on HO, HE, or HI
