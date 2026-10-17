# cancer_staging — Setup & Workflow Guide

Complete walkthrough: Google OAuth setup → environment configuration → one-time
DOM probe → daily workflow. Read once, then keep as reference.

---

## 0. What this tool does

For every `待修正` row on the shared Google Sheet, for doctor 陳醫師:

1. Reads the row's 報告內容 / 病理報告 / 臨床診斷 / 備註 columns.
2. Guesses 癌別 with a regex classifier (you confirm/edit).
3. Drives the RIS list IE to search the row's chart number (`院內病歷號碼`).
4. You double-click the matching row → the report IE opens (`MJB3A002.do`).
5. Opens **cancer-tnm.firebaseapp.com** in Chrome. You complete T/N/M/Stage.
6. You copy the rendered AJCC output; the helper reads clipboard.
7. Helper appends the staging block to the report's `#exam` textarea via
   `setReportText(..., -1)`.
8. Helper drives the `MJB3N002.do` follow-up form:
   - `<input name=recheck value="0">` = 與原始診斷一致 ✓
   - `<input name=cancer>` = 癌症評鑑分期格式化 ✓
   - `<button type=submit>` = 回覆確認
9. When the page changes, the report IE window auto-closes.
10. Writes 癌別 + `完成` (or `已備註` + reason) back to the sheet.

You keep the medical judgment. The tool automates the mechanics + the sheet
write-back.

---

## 1. Prerequisites

- Python 3.12 + `uv` installed (`uv --version` should print).
- AutoHotkey v1 at `C:\Users\raduser\Documents\reportSet\AutoHotkey.exe`.
- `autorun.ahk` running (it owns the CH_RIS IPC bridge; this tool is a client).
- IE with the RIS worklist (`MJB3W001.do`) reachable.
- A Google account that already owns / has edit access to the sheet
  `MOCK_SHEET_ID`.
- Chrome installed (any signed-in profile works).

---

## 2. Google OAuth Desktop client setup

One-time per Google Cloud project.

### 2.1 Create / pick a Cloud project

- <https://console.cloud.google.com/> → top-nav project dropdown → **New Project**.
- Name it `cancer-staging` (or reuse an existing one). No org needed.
- Wait for it to provision, then make sure it's the active project.

### 2.2 Enable the Google Sheets API

- Left nav → **APIs & Services → Library**.
- Search "Google Sheets API" → click it → **Enable**.

### 2.3 Configure the OAuth consent screen

- Left nav → **APIs & Services → OAuth consent screen**.
- User Type: **External** → **Create**.
- Required fields:
  - App name: `cancer-staging`
  - User support email: `scsnake@gmail.com`
  - Developer contact email: `scsnake@gmail.com`
- Skip everything else on that page → **Save and Continue**.
- **Scopes** step: no changes needed (the tool requests the scope at runtime) →
  **Save and Continue**.
- **Test users** step: **+ Add Users** → add `scsnake@gmail.com` →
  **Save and Continue** → **Back to Dashboard**.

The app stays in "Testing" mode indefinitely — that's fine for a personal desktop
tool. On first consent you'll see a "Google hasn't verified this app" warning —
click **Advanced → Go to cancer-staging (unsafe)** to proceed. Normal for
unpublished desktop OAuth apps.

### 2.4 Create the Desktop OAuth client

- Left nav → **APIs & Services → Credentials**.
- **+ Create Credentials → OAuth client ID**.
- Application type: **Desktop app**.
- Name: `cancer-staging desktop`.
- **Create** → click **Download JSON** in the dialog.

### 2.5 Move the JSON to where `.env` expects it

Default path from `.env.example`:
`C:\Users\raduser\.config\cancer_staging\oauth_client.json`

PowerShell:

```powershell
mkdir "$env:USERPROFILE\.config\cancer_staging" -Force | Out-Null
Move-Item -Force "$env:USERPROFILE\Downloads\client_secret_*.json" `
                 "$env:USERPROFILE\.config\cancer_staging\oauth_client.json"
```

If you'd rather save it elsewhere, edit the `OAUTH_CLIENT_JSON` line in `.env`
to point at your chosen path.

---

## 3. Environment configuration

```powershell
cd "C:\Users\raduser\Documents\reportSet\CH scripts\cancer_staging"
copy .env.example .env
notepad .env
```

Verify these lines match your environment:

| Key | Default | Notes |
| --- | --- | --- |
| `SHEET_ID` | `MOCK_SHEET_ID` | leave as-is |
| `SHEET_GID` | `40999601` | leave as-is |
| `DOCTOR_NAME` | `陳醫師` | leave as-is |
| `TODO_STATUS` | `待修正` | column K target value |
| `DONE_STATUS` | `完成` | column K written on success |
| `NOTED_STATUS` | `已備註` | column K written on skip-with-reason |
| `OAUTH_CLIENT_JSON` | `C:\Users\raduser\.config\cancer_staging\oauth_client.json` | must exist |
| `CANCER_TNM_URL` | `https://cancer-tnm.firebaseapp.com/#/` | leave as-is |

Then install Python deps:

```powershell
uv sync
```

---

## 4. First run — trigger OAuth consent

```powershell
uv run python main.py fetch-todo
```

- A browser tab opens → sign in with `scsnake@gmail.com`.
- "Google hasn't verified this app" → **Advanced → Go to cancer-staging (unsafe)**.
- Grant the "See, edit, create, and delete all your Google Sheets spreadsheets"
  scope → **Continue**.
- Browser: "The authentication flow has completed" — close the tab.
- Token cached at `%LOCALAPPDATA%\cancer_staging\token.json`.

Subsequent runs are headless (browser only reappears if the token expires and
cannot be refreshed).

Sanity-check parsing:

```powershell
uv run python main.py dump-classify
```

You should see a table of `待修正` rows with 癌別 guesses. If the tool errors
about missing columns, the sheet's header row uses different names than the
defaults in `sheet_client.py:DOCTOR_COL_CANDIDATES` etc. — either rename the
header or extend the candidate list.

---

## 5. Phase 0 — one-time DOM discovery for MJB3N002.do

Already done for the follow-up form we captured. `dom_selectors.json` contains:

```json
{
  "form_url_regex": "\\/webcvis\\/MJB\\/MJB3N002\\.do",
  "radio_same_dx":      { "selector": "input[name=recheck][value=\"0\"]" },
  "checkbox_stage_fmt": { "selector": "input[name=cancer]" },
  "btn_review_result":  { "selector": null,  "note": "section header, not a button" },
  "btn_reply_confirm":  { "selector": "button[type=submit]" }
}
```

Re-run only if the RIS form layout changes:

```powershell
"C:\Users\raduser\Documents\reportSet\AutoHotkey.exe" `
  "C:\Users\raduser\Documents\reportSet\CH scripts\cancer_staging\probe_cancer_form.ahk"
```

Then open the target `MJB3N002.do` form in IE, press **Ctrl+Alt+Shift+D**.
Two files are written: `dom_selectors.json` and `dom_dump_MJB3N002.txt`.
Manually inspect the JSON before committing.

Exit the probe with **Ctrl+Alt+Shift+Q**.

---

## 6. Daily workflow

### 6.1 Launch

Ensure open:
- IE window with RIS worklist (URL contains `MJB3W001.do`).
- Chrome (any window).
- `autorun.ahk` running.

Then:

```powershell
cd "C:\Users\raduser\Documents\reportSet\CH scripts\cancer_staging"
.\run.bat
```

`run.bat` does:
1. `uv sync --quiet`
2. `uv run python main.py fetch-todo` → writes `queue.json`.
3. Launches `cancer_staging_helper.ahk` — the always-on-top helper GUI.

### 6.2 Walking a row in the helper GUI

Per queued row you see:

| Field | What it shows |
| --- | --- |
| **Row (queue)** | `N / total — sheet row R` |
| **Chart no** | copied from `院內病歷號碼` |
| **癌別 guess** | classifier output, editable |
| **guess reason** | which column matched + snippet |
| **Source columns** | read-only quick reference |
| **Staging block** | fills after "Read clipboard" |

Actions:

- **Search chart in RIS** — writes `patno` into the RIS worklist and clicks
  `#QueryButton`. Focus RIS list; double-click the correct row → report IE opens.
- **Open cancer-tnm** — opens/navigates cancer-tnm.firebaseapp.com in Chrome
  (single tab, position it side-by-side with the helper).
- Complete the T/N/M/Stage on the site. Select the rendered AJCC output
  (usually a text block below the form), press **Ctrl+C**.
- **Read clipboard → staging** — pastes clipboard into the staging textarea.
  Edit the text in place if needed.
- **[Apply] Append + Confirm** — one shot:
  1. `setReportText(text, "", getRisReports(), -1)` → appends to `#exam`.
  2. `CH_RIS.flush()` (verify-and-retry commit).
  3. Finds `MJB3N002.do` IE → clicks radio → checkbox → 回覆確認.
  4. Waits up to 8 s for the page to change → closes the report IE.
  5. `uv run python main.py write-back --row R --cancer-type X --status 完成`.
  6. Loads next row.
- **Skip: 完成 (no stage)** — no staging text, but the row is done. Writes 癌別
  (if you filled it) + `完成` back to the sheet.
- **Skip: 已備註** — prompts for a reason (e.g. "path pending"), writes 癌別
  (optional) + `已備註` + the reason into the 備註 column.
- **‹ Prev / Next ›** — walk rows without acting.

### 6.3 Exiting

Close the helper window, or press **Ctrl+Alt+Shift+Q**.

---

## 7. Files produced by the tool

| Path | Kind | Notes |
| --- | --- | --- |
| `queue.json` | ephemeral | rewritten every `fetch-todo`; gitignored |
| `dom_selectors.json` | committed | source of truth for MJB3N002.do selectors |
| `dom_dump_MJB3N002.txt` | debug | full DOM dump; gitignored |
| `logs/helper_YYYYMMDD.log` | append | timestamped run log |
| `%LOCALAPPDATA%\cancer_staging\token.json` | user | cached OAuth token; never committed |

`sheet_client.write_row()` is PATCH-style: cells with existing non-empty values
are left alone (unless `--force`). This makes the tool safe to re-run against
rows that were already partially filled by hand.

---

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `queue.json not found` MsgBox at helper launch | never ran `fetch-todo` | `uv run python main.py fetch-todo` |
| Consent browser never opens | `OAUTH_CLIENT_JSON` path wrong | fix path in `.env` |
| "Google hasn't verified this app" | expected for Testing OAuth apps | Advanced → Go to cancer-staging (unsafe) |
| `Sheet header row missing columns: [...]` | column names in the sheet differ | rename in the sheet OR extend the candidate lists at the top of `sheet_client.py` |
| Chart search silently fails | no `MJB3W001.do` IE open | open the RIS worklist in IE |
| `No MJB3N002.do window found` when applying | follow-up form not open yet | some workflows require you to click a link first; open the form manually, then hit Apply |
| Radio/checkbox click errors | RIS form layout changed | rerun `probe_cancer_form.ahk`, commit updated `dom_selectors.json` |
| Report IE doesn't close after 回覆確認 | page didn't navigate within 8 s | not a failure — data is submitted, close by hand |
| `write-back cmd FAILED, exit=…` in log | `uv` not on PATH from AHK context | edit `UV_EXE` in `cancer_staging_helper.ahk` to full path (e.g. `C:\Users\raduser\.local\bin\uv.exe`) |
| Token expired, no browser prompt on refresh | `token.json` corrupted | delete `%LOCALAPPDATA%\cancer_staging\token.json` and re-run |
| Every row's guess is empty | source columns unusually short or non-English/non-Chinese | edit rules in `classify.py` |

---

## 9. Where each concern lives

- OAuth + sheet access: `sheet_client.py`
- 癌別 rules: `classify.py`
- Python ↔ AHK bridge: `queue.json` (write) + `main.py write-back` (read)
- Chart search: `SearchChartInRisList()` in `cancer_staging_helper.ahk`
- Report append: `setReportText(text, "", getRisReports(), -1)` — see
  `Lib\RisImpax.ahk:2473`
- Follow-up form clicks: `ClickFollowupWidgets()` + `ClickBySelector()` in
  the helper, consuming `dom_selectors.json`
- Page-change detection / close: `WaitForPageChange()` in the helper —
  mirrors the polling pattern in `Lib\CH_RIS.ahk:621`
- Owner election: this tool sets `global __CH_RIS_CLIENT := true`, so it
  never becomes a CH_RIS owner — the running `autorun.ahk` is the sole owner.
