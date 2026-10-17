# ReportSet Project Guidelines

## Git workflow

Follow [AGENTS.md](AGENTS.md) before editing or committing.
Read [docs/BRANCHES.md](docs/BRANCHES.md) for branch roles and the legacy branch audit.

`dev/ch` is the integration branch; GitLab's default `main` branch is legacy.
Start new features and fixes on topic branches based on `dev/ch`.
Verify the current branch and staged files before each commit.

## Active cancer-staging continuation

For C hospital RIS cancer-staging work (paste sheet rows → LLM proposals → webpage
approval → batch send), read `CH scripts/cancer_staging/LLM_PROPOSALS.md` and
`CH scripts/cancer_staging/CURRENT_HANDOFF.md` (live batch state, send contract,
and safety invariants) before running commands.

## Project Structure

- `Lib/` — shared AHK v1 libraries (CH_RIS, INFINITT_PACS, DebugLog, ~150 utility libs)
- `CH scripts/` — C hospital workflow scripts (RisHorosSync, query_app)
- `PacsIE/` — PACS IE integration scripts (simpleRIS, FocusLock)
- `RadTemplate/`, `RadTemplate_v2/` — radiology report template scripts
- `YCH_*.ahk` — YCH modality scripts: `YCH_Enh.ahk` (CT), `YCH_XR_Enh.ahk` (XR), `YCH_mammo_Enh.ahk` (mammo), `YCH_BMD.ahk` (BMD)
- `CH scripts/query_app/` — Python HIS query application (Oracle, multi-node)
- `ahk-mcp/` — AHK MCP server integration

## AutoHotkey v1 Script Encoding (Critical)

All `.ahk` files for AutoHotkey v1 **MUST** be saved with UTF-8 BOM encoding to prevent character corruption, especially for Chinese characters.

### Encoding Rule

The BOM fixer runs **automatically** via a PostToolUse hook after every Write/Edit. No manual action is needed during normal editing.

To run manually (e.g. after bulk changes):

```powershell
cd "C:\Users\raduser\Documents\reportSet"
python "C:\Users\raduser\Documents\fix_all_bom.py"
```

**What this does:**
- Scans the current directory recursively for `.ahk` files modified in the last 2 hours
- Adds UTF-8 BOM (`EF BB BF`) if missing
- Removes duplicate BOMs if present
- Skips directories containing `ahkv2` in the path

### Process All Files

To process **all** `.ahk` files regardless of modification time:

```powershell
python "C:\Users\raduser\Documents\fix_all_bom.py" all
```

### Why Python Instead of PowerShell

The Python utility is more reliable than manual PowerShell commands because:
- Avoids byte array concatenation issues in PowerShell
- Prevents variable swallowing in subprocess calls
- Handles edge cases (duplicate BOMs, missing BOMs) automatically
- Single command applies to all modified files

### Verification

To confirm a file has the BOM, check that it begins with these three bytes:
```
EF BB BF
```

---

## Syntax Verification — Load-Only via /iLib

Do a **load-only** parse — it catches syntax errors but does NOT run the script (no
MsgBox, no tray/GUI, no `#SingleInstance, Force` killing your running copy). The Claude
Code `Bash` tool runs Git Bash, so prefix `MSYS_NO_PATHCONV=1`:

```bash
MSYS_NO_PATHCONV=1 "C:/Users/raduser/Documents/reportSet/AutoHotkey.exe" /iLib NUL /ErrorStdOut "C:/Users/raduser/Documents/reportSet/CH scripts/RisHorosSync.ahk"; echo "EXIT=$?"
```

- **Pass:** `EXIT=0` + empty stderr. **Fail:** nonzero exit (2) + error on stderr.
- Without `/iLib NUL`, plain `/ErrorStdOut` RUNS the script. Without `MSYS_NO_PATHCONV=1`,
  Git Bash mangles `/ErrorStdOut` into `C:\Program Files\Git\ErrorStdOut` → "Script file not found" dialog.

After any fix, rerun the check to confirm clean. If a check leaves a dialog or live
process, kill ONLY the offender (matched by script path) — **never**
`Stop-Process -Name AutoHotkey`, which kills production scripts like `simpleRIS`:

```bash
MSYS_NO_PATHCONV=1 powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='AutoHotkey.exe'\" | Where-Object { \$_.CommandLine -match 'YOUR_SCRIPT' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }"
```

---

## AutoHotkey v2 Coding Standards

When working on AutoHotkey v2 scripts, refer to `AHKv2_Scripts\ClautoHotkey\Modules\Module_Instructions.md` for detailed standards including:
- Object-oriented architecture (classes, no globals)
- Map-based data storage (not object literals)
- Event binding with `.Bind(this)`
- Proper instantiation (no `new` keyword)
- Deterministic GUI layouts
