# Infrastructure Reference

> Last updated: 2026-10-13 (database cluster table corrected from live checks)

---

## Database Cluster (Oracle 11.2.0.3, port 1521)

Credentials: `HIS_DB_USER` / `HIS_DB_PASSWORD` in `CH scripts/.env` (not committed). All nodes accept the same read account.  
Thick mode required: `oracledb.init_oracle_client(lib_dir=r"C:\instantclient_12_2")`

| IP | Node | Schemas | Use for |
|---|---|---|---|
| `10.0.0.1` | HO (SID `ho`) | CHART, OPD | Patient master (`CHART.CHART`), OPD encounter lists |
| `10.0.0.1` | HE (SID `he`) | EXAM, XRAY, LAB, LAP, LABMAST, EXAMMAST | Radiology, lab, and pathology results |
| `10.0.0.1` | HI (SID `hi`) | IPD, IDE, NISOP, DSR, ORMS | Admissions, inpatient notes, EMR documents, operation notes |
| `10.0.0.1` | ONH | — | Role unverified; holds none of the probed clinical tables |
| `10.0.0.1` | HB | — | Role unverified (assumed billing); holds none of the probed clinical tables |
| `10.0.0.1` | PPF | — | Role unverified; holds none of the probed clinical tables |

Table-level detail: [`oracle_schema.md`](oracle_schema.md).

---

## RIS / Web Services

| IP:Port | Service | URLs |
|---|---|---|
| `10.0.0.1:9090` | RIS web (Java EE) | `/webcvis/MJB/MJB3A002.do` — study report |
| | | `/webcvis/MJB/openimg.jsp` — PACS launcher trigger |
| | | `/webcvis/ajax/AJAXAction.do` — phrase library, prior reports |
| | | `/webcvis/MJB/CallClient.jar` — Java applet (bridges web → PACS exe) |

---

## PACS Servers

| IP | Port | Service | Notes |
|---|---|---|---|
| `192.0.2.10` | 80 | INFINITT PACS management (gpu-host.example.invalid) | Tailscale node (`192.0.2.10`) → DERP relay when TS active |
| `192.0.2.10` | 80 | PACS image server | NOT a Tailscale node → always direct LAN |

**PACS endpoints** (HTTP, not DICOM port 104):
- `GET /Image01/YYYYMMDD/StudyUID/ImageUID.dcm` — image download from `192.0.2.10`
- `POST /WDOServer2/WDOLibrary.Service.svc` — study metadata (to `192.0.2.10`)
- `GET /pkg_pacs/external_interface.aspx?type=S&lid=...&an=<accession>` — study lookup
- `POST /webservices/smartupdate.asmx` — update service

---

## SMB2 / File Servers

| IP | Share / Path | Content |
|---|---|---|
| `10.0.0.1` (gpu-host.example.invalid) | `\Relexe\HOSPITAL\Utility\Exe\` | HIS app executables (streamed at runtime) |
| | `\HOSPITAL\PFILE\pwdKS1.txt` | ⚠️ Oracle credentials in plaintext |
| `10.0.0.1` | `\Settings\Exam\PACS.Ini` | PACS config |
| | `\ExamLog\TimeLog\RAD-D6\YYYYMMDD.Txt` | Daily exam timing log |
| | `\EventLog\HospMsg\HospMsgSvr_LAB\RAD-D6\` | Lab notification events |

---

## PACS Launcher Executables (local workstation)

| Exe | Path | Role |
|---|---|---|
| `G3Launcher.exe` | `C:\INFINITTG3\VIEWER\G3Launcher.exe` | Called by Java applet; performs blocking HTTP session setup to `192.0.2.10` |
| `Starter.exe` | `C:\ProgramData\infstarter\Starter.exe` | Decodes `infstarter://` payload; writes temp `.tmp` files for G3PACS |
| `SmartUpdate.exe` | `C:\INFINITT\Smartupdate\Smartupdate.exe` | Update checker — persists, focus-steals, can be suppressed |
| `G3PACS.exe` | `C:\INFINITTG3\VIEWER\G3PACS.exe` | Main PACS viewer (already running) |

---

## Network Topology Diagram

```
Workstation (10.0.0.1 / 192.0.2.10)
    │
    ├─[HIS NIC: 172.19.x.x]──────────────────────────────────────────────┐
    │   ├─► RIS web          10.0.0.1:9090   HTTP (plain)             │
    │   ├─► Oracle TNS       10.0.0.1–142:1521  unencrypted           │
    │   └─► SMB2             10.0.0.1 / .171:445  unencrypted          │
    │                                                                       │
    └─[PACS NIC: 10.16.0.x]─────────────────────────────────────────────────┐
        ├─► Image server     192.0.2.10:80    HTTP WADO (always direct LAN)  │
        └─► PACS server      192.0.2.10:80   HTTP metadata                  │
             ↑ Tailscale node: when TS active, this goes via DERP relay       │
             └─► 127.0.0.1:55761 (WireGuard/DERP, RTT 266ms) → LAN PACS │
```

---

## Tailscale Impact Summary

| TS state | PACS metadata path | Image path | G3PACS load time |
|---|---|---|---|
| ON | Via DERP relay (266 ms RTT) | Direct LAN (usually) | ~8–12 s |
| OFF | Direct LAN (<1 ms RTT) | Direct LAN | ~4–8 s |

Fix: disable Tailscale during reporting, or configure subnet routing for `192.0.2.10/24`.
