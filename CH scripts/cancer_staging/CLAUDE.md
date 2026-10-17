# cancer_staging — Claude Code Notes

## Current continuation

The formal pipeline is paste sheet rows → Claude writes `proposals.json` →
`prepare --proposals` → webpage approval → batch send. Read `LLM_PROPOSALS.md`
for the steps and proposal contract, and `CURRENT_HANDOFF.md` for the live batch
state, before running commands. It records the user's saved staging-text hashes, the
still-pending approval state, the live local review-UI process, the exact
original-report-plus-staging append contract, and the mandatory dry-run/live-send
sequence. Do not send from this file alone; reload `review.json` first.

## Ground truth

- Doctor: **陳醫師**.
- Sheet: `MOCK_SHEET_ID`, gid `40999601`.
- Column K = status (`待修正` → to do; `完成` → done; `已備註` → skipped with note).
- Standard RIS report page: `http://10.0.0.1:9090/webcvis/MJB/MJB3A002.do?index=N&...`
- Follow-up form (has the 4 target widgets): `http://10.0.0.1:9090/webcvis/MJB/MJB3N002.do?index=N&pageid=MJB3N002&reportformid=129`

## Do

- Set `global __CH_RIS_CLIENT := true` **before** any `#include` in AHK helpers. Autorun.ahk owns CH_RIS; the helper is a client.
- Use `setReportText(text, "", getRisReports(), -1)` for append (`-1` = append mode; see `Lib\RisImpax.ahk:2473`).
- Use existing chart-search selectors: `input[name=patno]`, `#checktimestart`, `#checktimeend`, `#QueryButton` (Lib\CH_RIS_LIST_enhance.js:93).
- Use existing report editor id: `document.getElementById("exam")` (plain textarea).
- Save all `.ahk` files as UTF-8 BOM (PostToolUse hook handles this automatically).
- Sanity check every AHK write with the load-only parse (`/iLib NUL /ErrorStdOut`) before considering it done — see project CLAUDE.md.

## Don't

- Don't modify shared libraries (`Lib\CH_RIS.ahk`, `Lib\RisImpax.ahk`, `Lib\CH_RIS_LIST_enhance.js`) — this project only *consumes* them via IPC client mode.
- Don't hard-code widget IDs before Phase 0 DOM probe runs. `dom_selectors.json` is the source of truth for MJB3N002.do IDs.
- Don't overwrite non-empty sheet cells without confirmation (see `sheet_client.write_row(..., force=False)`).
- Don't `Stop-Process -Name AutoHotkey` — it kills production scripts. Kill only by CommandLine match on the specific script path.
- Don't invent `dom_selectors.json` values from thin air — if the file is missing/incomplete, refuse to click and prompt the user to run the probe first.

## Where to look

- Analog helper: `boneage_CH.ahk` — client-mode floating GUI + `setReportText` + `CH_RIS.activate`.
- Chrome DevTools Protocol AHK v1 lib: `Lib\Chrome.ahk` (already used by boneage_CH).
- WM_HTML_GETOBJECT / IE COM: `Lib\WBGet.ahk`.
- JSON: `Lib\JSON.ahk`.
- `Shell.Application.Windows()` window enumeration + title-regex match: `Lib\CH_RIS.ahk:283` and `:648` (the exact patterns to mirror for `MJB3W001.do` list and `MJB3N002.do` follow-up).

## Sheet write-back rules

- Only fill empty cells by default. If `癌別` cell is already non-empty and matches the guess, no write.
- If column K is already `完成` or `已備註`, skip the row (don't reprocess).
- On `已備註`: the tool must also populate the row's 備註 (notes) column with the reason ("no staging needed", "pending path", etc.) chosen from a fixed dropdown.
