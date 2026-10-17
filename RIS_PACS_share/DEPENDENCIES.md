# RIS/PACS Automation Scripts — Dependency Report

Generated: 2026-04-23  
Source: `Lib/RisImpax.ahk` and related scripts (AutoHotkey v1)

---

## Files Included

### Core RIS/PACS Logic

| File | Description |
|------|-------------|
| `Lib/RisImpax.ahk` | **Central library.** Window detection for RIS (Yang-Ming `Menu.exe`) and IMPAX PACS, worklist grid parsing (`parseDataGrid2`, `parseDataGrid`), accession/chart-no extraction, PACS viewer URL construction, multi-RIS session management, encrypted credential loader (`RisImpaxLoadPw`), polling/registration bridge (`RisImpaxRegister`, `RisImpaxPollingSingle`). |
| `Lib/ImpaxContextServer.ahk` | Listens for IMPAX context-change events via `WM_COPYDATA` IPC. Allows other scripts to subscribe to PACS study changes without polling. |
| `Lib/INFINITT_PACS.ahk` | Window/control detection for the INFINITT PACS viewer. Mirrors the IMPAX-side logic for a different vendor. |
| `Lib/DataGridTable.ahk` | OOP wrapper (`DataGridTable` class) around a 2-D array. Used to represent parsed RIS worklist rows with named-column lookup. |
| `Lib/.NetGetControl.ahk` | Discovers .NET WinForms controls by name/class/accessibility attributes (`getNetControl2`, `getNetAcc`). Critical for interacting with the RIS (Yang-Ming `Menu.exe`) which exposes no standard ClassNN hierarchy. |
| `Lib/ReportImpression.ahk` | Parses free-text radiology reports into structured `exam` / `impression` sections. |
| `Lib/EBMViewer.ahk` | Detects and interacts with the EBM (Evidence-Based Medicine) viewer window. |
| `Lib/GEUV.ahk` | Detects and interacts with the GE Universal Viewer PACS window. |
| `Lib/getSimpleRisEditHwnds.ahk` | Returns cached HWNDs for the three Edit controls (report text areas) inside SimpleRIS. |
| `Lib/getSimpleRisGuiHwnds.ahk` | Returns cached HWNDs for the SimpleRIS GUI windows (persistent across hide/show cycles). |
| `Lib/MatchPacsProcessName.ahk` | Returns a single regex that matches all known PACS process names (`impax-client-main.exe`, `G3PACS.exe`, WEBVIE~1.EXE, etc.). |
| `PacsIE/simpleRIS.ahk` | Full SimpleRIS integration script: launches an embedded IE/browser RIS panel, syncs selection with PACS, handles report editing via Scintilla. |

### Utility Dependencies

These are generic helpers that the core files `#include`. They are not RIS/PACS-specific but are required for the scripts to compile.

| File | Required By | Description |
|------|------------|-------------|
| `Lib/Acc.ahk` | `.NetGetControl`, `EBMViewer`, `INFINITT_PACS`, `RisImpax` | Accessibility API (IAccessible) wrapper. |
| `Lib/RemoteScintilla.ahk` | `.NetGetControl`, `simpleRIS` | Sends/receives text from Scintilla editor controls over WM_COPYDATA. |
| `Lib/AltTab_window_list.ahk` | `RisImpax` | Enumerates visible alt-tab windows, used for multi-RIS detection. |
| `Lib/WM_COPYDATA.ahk` | `RisImpax`, `ImpaxContextServer` | `Send_WM_COPYDATA` / `OnMessage` helpers for inter-process messaging. |
| `Lib/JXON.ahk` | `RisImpax` | JSON serialise/parse (`JXON_Dump`, `JXON_Load`). Used to pass registration payloads over WM_COPYDATA. |
| `Lib/SetTimerF.ahk` | `RisImpax`, `simpleRIS` | `SetTimerF(func, interval, params)` — calls a closure/bound-function on a timer. |
| `Lib/setTimerClass.ahk` | `RisImpax`, `INFINITT_PACS` | Base class that lets an object instance schedule its own methods as timers. |
| `Lib/Edit.ahk` | `RisImpax`, `simpleRIS` | `Edit_GetSel`, `Edit_SetSel` and other Edit-control utilities. |
| `Lib/RegExSplit.ahk` | `RisImpax` | `RegExSplit(str, pattern)` — splits a string by regex, returns array. |
| `Lib/releasePressed.ahk` | `RisImpax` | Sends key-up events for any currently held modifier keys. |
| `Lib/appendItem.ahk` | `INFINITT_PACS` | Appends a value to an array variable by reference. |
| `Lib/WinVisible.ahk` | `RisImpax`, `EBMViewer`, `simpleRIS` | Returns whether a window is visible (not just exists). |
| `Lib/HasVal.ahk` | `RisImpax` | `HasVal(arr, val)` — checks if an array contains a value. |
| `Lib/GetFocusedHwnd.ahk` | `RisImpax`, `simpleRIS` | Returns HWND of the currently focused control. |
| `Lib/StrPutVar.ahk` | `RisImpax` | `StrPutVar(str, var, encoding)` — encodes a string into a buffer variable. |
| `Lib/EmptyMem.ahk` | `RisImpax`, `simpleRIS` | Trims the working set of a process (`EmptyWorkingSet`). |
| `Lib/MonitorInfo.ahk` | `RisImpax` | Returns an array of monitor rectangles (`monitorInfo()`). |
| `Lib/Crypt.ahk` | `RisImpax` | AES encryption/decryption. Used by `RisImpaxLoadPw` to decrypt the `.ini` credential file. |
| `Lib/Hex2Bin.ahk` | `RisImpax`, `Crypt` | Hex ↔ binary buffer conversion. |

---

## Dependency Graph

```
RisImpax.ahk
├── .NetGetControl.ahk
│   ├── RemoteScintilla.ahk
│   └── Acc.ahk
├── ImpaxContextServer.ahk
│   └── WM_COPYDATA.ahk
├── SetTimerF.ahk
├── Edit.ahk
├── JXON.ahk
├── MonitorInfo.ahk
├── WM_COPYDATA.ahk
├── WinVisible.ahk
├── AltTab_window_list.ahk
├── HasVal.ahk
├── GetFocusedHwnd.ahk
├── RegExSplit.ahk
├── Hex2Bin.ahk
├── Crypt.ahk  (← requires Hex2Bin)
├── releasePressed.ahk
├── EmptyMem.ahk
├── setTimerClass.ahk
├── EBMViewer.ahk
│   └── WinVisible.ahk
├── DataGridTable.ahk
├── GEUV.ahk
├── StrPutVar.ahk
└── ReportImpression.ahk

INFINITT_PACS.ahk
├── Acc.ahk
├── appendItem.ahk
└── DataGridTable.ahk

PacsIE/simpleRIS.ahk
├── Acc.ahk
├── RisImpax.ahk  (→ full tree above)
├── RemoteScintilla.ahk
├── WinVisible.ahk
├── GetFocusedHwnd.ahk
├── SetTimerF.ahk
├── EmptyMem.ahk
├── Edit.ahk
├── [portalLib.ahk]  ← EXCLUDED (see below)
└── [additional deps not included — see section below]
```

---

## Excluded Files

| File | Reason |
|------|--------|
| `Lib/portallib.ahk` | Contains hardcoded credentials (`user=MOCK_USER&password=MOCK_PASSWORD`) and hospital-specific internal IP addresses / web service endpoints. **Do not share.** |
| `Lib/changePortalPassword.ahk` | Password management utility; depends on `portallib`. |
| `Lib/getPlace.ahk` | Detects which hospital network the script is running on (C hospital/N hospital etc.). Institution-specific. |
| `Lib/CH_RIS.ahk` | C hospital-specific RIS Pub/Sub event bus. Not applicable outside C hospital. |

---

## Sanitizations Applied

| File | Line | Original | Replaced With |
|------|------|----------|---------------|
| `Lib/RisImpax.ahk` | 133 | `pw := "MOCK_AES_KEY"` | `pw := "yourKeyHere"` |

This was the **fallback default** for the AES encryption key used by `__RisImpaxPwEncrypt`. Replace `"yourKeyHere"` with a key of your choice before generating an encrypted `RisImpaxPw.ini`.

---

## Additional Dependencies in `simpleRIS.ahk` (Not Included)

`PacsIE/simpleRIS.ahk` references the following libraries that are not part of this share. You will need them if you intend to run `simpleRIS.ahk` directly:

| `#include` | Notes |
|------------|-------|
| `DebugLog` | Debug/logging helper |
| `prettyReport` | Formats report text for display |
| `wingetatcoords` | Gets window position at screen coordinates |
| `SCI` | Scintilla message constants |
| `FakeRemoteScintilla` | Stub for RemoteScintilla when editor is embedded |
| `SetTimerFn` | Variant of SetTimerF |
| `SetWindowsHookEx` | Low-level keyboard/mouse hook wrapper |
| `CheckUpdate` | Auto-update check |
| `resetHotstringBuffer` | Clears AHK hotstring buffer |
| `portalLib` | **Excluded** — see above |

`RisImpax.ahk` (the library, not a standalone script) does **not** require any of the above; only `simpleRIS.ahk` does.

---

## Usage Notes

1. All `.ahk` files must be saved with **UTF-8 BOM** (`EF BB BF`) — the files in this share already have BOM. AutoHotkey v1 requires BOM for correct Chinese character handling.
2. Place all `Lib/` files in your AutoHotkey `Lib` folder or use `#include` with relative paths.
3. `RisImpaxLoadPw` expects an `RisImpaxPw.ini` file (optionally AES-encrypted) alongside the script. Credentials are never hardcoded.
4. The RIS detection logic targets the Yang-Ming `Menu.exe` RIS system (title: `放射線資訊管理系統`). PACS detection targets Agfa IMPAX, INFINITT, and GE viewers.
