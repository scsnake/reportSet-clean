# Future Improvements for YCH*.ahk Scripts

Generated: 2026-04-01

---

## 1. Consolidate Duplicated Auto-Execute Setup

**Priority: High** | **Estimated savings: ~400 lines across 3 files**

YCH.ahk, YCH_XR.ahk, and YCH_mammo.ahk share nearly identical preambles (~70 lines each):

- Lines 1-15: Directives (`#Hotstring`, `Process`, `SendMode`, `SetWorkingDir`, `SetBatchLines`, etc.)
- Lines 17-24: `#Include` statements (risimpax, Acc, CH_Bridge, resetHotstringBuffer, etc.)
- Lines 31-49: Initialization (`CloseOtherYCHAHK`, `gosub openSimpleRIS`, `OnMessage` handlers)
- Identical `IMPAX_title` and `bullet` variable assignments

**Action**: Extract the shared preamble into a `YCH_base.ahk` include. Each modality file would only contain its unique setup (icon, modality-specific GroupAdd, gosub to its own dynamic hotstrings).

---

## 2. Move CT-Specific Functions Out of Shared Logic

**Priority: Medium**

`YCH_main_logic.ahk` (1925 lines) is included by all three modalities but contains functions only called from the CT modality:

| Function | Purpose | Called from |
|----------|---------|-------------|
| `BrainArtery()` | Brain arterial anatomy insertion | YCH.ahk only |
| `ErBrainCT()` | ER brain CT template | YCH.ahk only |
| `liver_lobe()` | Liver lobe anatomy | YCH.ahk only |
| `lesion_subpleura()` | Subpleural lesion description | YCH.ahk only |
| `editCCTAreport()` | CCTA report editing | YCH.ahk only |

**Action**: Move CT-only functions into YCH.ahk (or a new `YCH_ct_logic.ahk`). This keeps `YCH_main_logic.ahk` truly shared and avoids loading unused function definitions in XR/Mammo.

---

## 3. Programmatic Hotstring Generation

**Priority: Medium** | **Estimated reduction: 15-20% of YCH_main_hotstring.ahk**

Many hotstrings follow mechanical patterns that could be generated with loops:

### Left/Right/Bilateral variants
```ahk
; Current: 3 lines per anatomic structure
:*B0:lr/::left renal cyst(s)
:*B0:rr/::right renal cyst(s)
:*B0:br/::bilateral renal cysts
```
Dozens of structures repeat this pattern (renal, adrenal, pleural, etc.)

### Directional prefixes
```ahk
; qa/qc/qcc/qd/qi/ql/qm/qp/qpp/qs → anterior/central/centrilobular/dependent/inferior/lateral/medial/posterior/periportal/superior
```
10+ anatomic direction prefixes applied systematically across multiple body regions.

### Numbered series
Size descriptors, vertebral levels (C1-C7, T1-T12, L1-L5), rib numbers — all follow predictable patterns.

**Action**: Write a generator function (in auto-execute) that registers hotstrings from data arrays:
```ahk
sides := {"l": "left", "r": "right", "b": "bilateral"}
organs := {"r": "renal", "a": "adrenal", "p": "pleural"}
for side, sideWord in sides
    for org, orgWord in organs
        Hotstring(":*B0:" side org "/", sideWord " " orgWord " cyst(s)")
```

---

## 4. Remove Commented-Out Dead Code

**Priority: Low** | **~183 lines across all files**

| File | Approx. lines | Examples |
|------|---------------|----------|
| YCH.ahk | 42 | Lines 59-63: disabled `RisImpaxLoadPw` |
| YCH_XR.ahk | 74 | Lines 72-73: disabled WMI queries |
| YCH_mammo.ahk | 19 | Miscellaneous disabled blocks |
| YCH_main_logic.ahk | 48 | Various disabled alternatives |

**Action**: Delete commented-out code. Git history preserves it if needed later.

---

## 5. Externalize Hardcoded Configuration

**Priority: Medium**

Hardcoded values scattered across files make environment changes error-prone:

| Value | Location | Issue |
|-------|----------|-------|
| `"IMPAX 6.5.2.114 Radiologist with QC"` | YCH.ahk:64, YCH_XR.ahk:81 | Duplicated; IMPAX version upgrades break both |
| `"http://10.0.0.1:8042/"` | YCH_main_logic.ahk:1129 | Orthanc server IP hardcoded |
| `"CH scripts\LaunchRisHoros.bat"` | YCH.ahk:54 | Path depends on workstation layout |
| `"mammo.ico"` | YCH_mammo.ahk:72 | Relative path assumption |
| Sleep/WinWait timeouts | Various (100ms-500ms) | Inconsistent, no rationale documented |

**Action**: Create `YCH_config.ini` with sections for `[Network]`, `[Paths]`, `[UI]`, `[Timeouts]`. Read with `IniRead` during auto-execute. Single source of truth for all modalities.

---

## 6. Add Structured Error Handling

**Priority: Medium**

Current state:
- `comobjerror(false)` in YCH.ahk:17 and YCH_mammo.ahk:17 silently swallows all COM errors
- Only one `try/catch` block found (YCH_main_logic.ahk:848-851)
- Network operations (Orthanc HTTP requests at YCH_main_logic.ahk:1129-1160) have no error handling
- File I/O operations assume success
- `MsgBox` error dialogs in YCH_XR.ahk (lines 838, 896) are unstructured

**Action**:
1. Replace blanket `comobjerror(false)` with targeted `try/catch` around COM calls
2. Add `try/catch` for HTTP requests to Orthanc, with retry logic and user notification
3. Create a shared `LogError(source, message)` function that appends to a log file
4. Validate file existence before `FileRead`/`Run` operations

---

## 7. Summary / Prioritization

| # | Improvement | Effort | Impact | Priority |
|---|-------------|--------|--------|----------|
| 1 | Consolidate auto-execute | Low | High (maintainability) | **High** |
| 2 | Move CT functions to CT file | Low | Medium (cleanliness) | Medium |
| 3 | Programmatic hotstring generation | Medium | Medium (reduce 3000+ lines) | Medium |
| 4 | Remove dead code | Low | Low (hygiene) | Low |
| 5 | Externalize config | Medium | High (portability) | **Medium** |
| 6 | Error handling | Medium | High (reliability) | **Medium** |
