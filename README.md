# reportSet: Workstation Reporting Suite (Sanitized Reference Archive)

A sanitized reference snapshot of an actively maintained radiology workstation automation suite.

---

## Purpose & Scope

- **Workstation Automation Reference**: Documents the architecture of a portable clinical reporting and PACS automation suite.
- **Actively Maintained Source**: Derived from an actively developed suite for dual-monitor diagnostic reading rooms.
- **AI-Augmented**: Partially optimized, refactored, and documented with AI assistance.
- **Sanitized Baseline**: Scrubbed of Patient Health Information (PHI), hospital names, and staff identifiers.
- **Not Directly Runnable**: Function names, variable names, file/folder names, DOM selectors, URLs, and credentials have been sanitized. Because hospital web portals, RIS controls, and PACS servers require real site-specific identifiers, these scripts cannot be executed directly.

---

## Sanitization & Anonymization Notice

To protect institutional privacy and medical security, this repository replaces hospital-specific terms across file paths, code symbols, and configuration endpoints:

- **Hospitals & Branches**:
  - `N hospital` (`N`): Major national university teaching hospital (`Y branch`, `H branch`, `J branch`, `B branch`, `ZD branch`, `C branch`).
  - `C hospital` (`CH`): Regional Catholic teaching hospital.
- **File & Folder Names**: Hospital and branch abbreviations in paths use neutral initials (e.g. `CH scripts/`, `boneage_CH.ahk`, `Lib/CH_RIS.ahk`).
- **Function & Variable Names**: Identifiers, class names, and include guards use anonymized prefixes (e.g. `CH_RIS_*`, `NBranch`, `__is_N`, `__is_CH`).
- **URLs, Hosts & DOM Selectors**: Intranet URLs, IP addresses, DICOM AE titles, and web form element IDs use mock values (e.g. `*.hospital-n.local`, `10.0.0.1`).
- **Clinicians, Staff & PHI**: Staff names use generic titles (`張醫師`, `王醫師`), credentials use `MOCK_PASSWORD`, and all patient records use synthetic placeholders (`0000001`, `王小明`, `T0000000001`).

> [!IMPORTANT]
> Because file names, function names, DOM IDs, and URLs are sanitized, this repository serves as an architectural and code reference only and cannot be run directly.

---

## Architecture & Core Tools

| Component | Primary File | Description |
| :--- | :--- | :--- |
| **Central Hub** | [`autorun.ahk`](autorun.ahk) | Main entry point. Loads hooks, hardware mappings, and shared libraries. |
| **Editor Overlay** | [`textHotkey.ahk`](textHotkey.ahk) | Accelerates caret movement by word, clause, and sentence. |
| **Dynamic Templates** | [`RadTemplate/`](RadTemplate/) | Form engine with inline input fields and automated formula evaluation. |
| **Template Engine v2** | [`RadTemplate_v2/`](RadTemplate_v2/) | Enhanced DSL parser supporting subspecialty reporting forms. |
| **Screening Reporting** | [`LDCTreport.ahk`](LDCTreport.ahk) | Low Dose CT screening form complying with Fleischner 2017 guidelines. |
| **Pediatric Assessment** | [`boneage_CH.ahk`](boneage_CH.ahk) | Pediatric bone age assistant using Greulich & Pyle standards. |
| **Emergency Alerts** | [`urgentReport/`](urgentReport/) | Notification bridge to alert clinical teams of critical findings. |
| **PACS Integration** | [`EBMhelper/`](EBMhelper/) | Context tracker and image navigation accelerator for PACS viewers. |

---

## Reusable Library (`Lib/`)

The [`Lib/`](Lib/) directory contains 218 modular utilities. AutoHotkey resolves these automatically:

- **Win32 & UIAutomation**: Low-level accessibility hooks for hospital controls without visual scraping (`acc.ahk`, `UIAutomationServer.ahk`).
- **COM & OLE Abstractions**: Virtual table wrappers for Windows interfaces (`ComDispatch.ahk`, `wb.ahk`).
- **Networking & IPC**: Local TCP sockets and inter-process messaging (`AHKsock.ahk`, `CH_RIS_Server.ahk`).
- **Security & Data**: Checksum verification and string encoding (`hash.ahk`, `Crypt.ahk`).
- **GUI Controls**: Modern interface components, overlays, and custom tooltips (`OnScreenDisplay.ahk`).

---

## Interactive Architecture Catalog

Open [`reportset_catalog.html`](reportset_catalog.html) in any web browser to explore:
- Comprehensive listings for all 19 workflow tools and 218 `Lib\` modules.
- In-place description editor with localStorage autosave.
- Visual status indicators (**Edited** in green, **Read/Reviewed** in blue).
- Filter controls for instant search across categories and file paths.

---

## License

Released under the [MIT License](LICENSE) with Reference & Medical Disclaimer. Provided for clinical productivity reference, educational study, and workstation automation. Not a certified medical device.
