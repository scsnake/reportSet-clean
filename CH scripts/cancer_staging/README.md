# cancer_staging

Human-approved TNM staging review and WebRIS re-report pipeline. The durable
architecture, safety rules, and test sequence are in
[`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) and
[`TEST_GUIDE.md`](TEST_GUIDE.md).

The formal flow is:

```text
paste sheet rows -> import-tsv -> Claude writes proposals.json
-> prepare --proposals -> review-ui edit/approve -> batch dry-run -> batch --execute
```

See [`LLM_PROPOSALS.md`](LLM_PROPOSALS.md) for commands and the proposal contract.

## Interactive review UI

After importing and preparing cases, start the local review interface:

```powershell
uv run python main.py review-ui
```

It opens <http://127.0.0.1:8765/> and provides:

- a searchable pending/approved study list, either grouped by cancer type
  (alphabetical, "No staging template" last, with approved counts per group) or
  in the sheet's pasted order (**Sheet order** toggle, remembered per browser);
  Prev/Next follows the chosen order, and sent studies are marked "sent to RIS";
- **Template form** above the staging text: the cancer-tnm website's own fields
  (template, modality, T/N/M with definitions, side, tumor/LAP/metastasis
  locations, and HCC liver features, characteristics and number). It is prefilled
  from the LLM proposal. The cancer dropdown follows the website's menu order
  and groups (LUNG, H & N, GI, GU, OGS). Every change re-renders the exact website template
  through `/api/render`; the stage comes from the catalog, with a picker when
  the catalog maps the TNM to more than one stage. Saving stores the form
  fields (so the T/N/M/stage digest matches the text) together with the text,
  including any hand tweak made after rendering;
- **Sheet paste-back** (top bar): the two columns 癌別 | 完成 in sheet order,
  ready to copy and paste into the sheet.
  - **Which rows are copied:** exactly the ticked rows, one line each, in sheet
    order. An unticked row adds no line, and the page warns when unticked rows
    sit between ticked ones (paste such a block only where those rows are
    hidden).
  - **Ticking:** each row has a checkbox, and the header has select-all. You can
    also drag across rows (or click one) to invert the ticks of every row
    touched; the space bar toggles a focused checkbox.
  - **Default ticks:** every row from the first to the last finished row.
    Finished means sent to RIS (完成 plus the template's 癌別), or a row whose
    values you chose in the per-row dropdowns (the sheet's own choices, saved
    in `review.json`).
  - **Ticked but unfinished rows:** a blank line in the default "Unfinished
    rows: leave empty" mode, or their current sheet values in "keep sheet
    values" mode.
- **Sent studies are locked:** the text, form, approval and revoke are
  disabled, and the server refuses changes too. The page also shows when the
  study was sent.
- **N/A (not applicable):** a one-click button next to Approve for studies
  that cannot be staged, such as an unsupported cancer type. An N/A study is:
  - never sent to RIS
  - locked until you click **Undo N/A**
  - shown with a grey dot, counted as "done" in its group, and left out of the
    Pending filter
  - finished in the paste-back, with defaults 其他癌 / 已備註
- **After Approve or N/A:** the page scrolls to the top and keyboard focus
  moves to the study's card in the list.
  - Rows filtered out at import (for example not 待修正) are kept in place from
    `cases_source_rows.json`, so the block always lines up with the copied rows;
- click-to-copy accession, chart number, and study dates;
- original report, pathology, diagnosis, and comments;
- the agent-derived TNM proposal with evidence, assumptions, and warnings;
- editable exact staging text, with stale-write protection;
- one-click **Approve** (or Ctrl+Enter) of the saved exact text, with no extra
  confirmation dialog.

Saving changed staging text invalidates prior approval. Approval is bound to the
SHA-256 of the exact text. The UI only updates `review.json`; it cannot submit a
report to RIS. Stop it with `Ctrl+C`.

The API operation is dedicated to reported-study page `MJB3N002` and pins the
three required values server-side: `recheck=0`, `cancer=Y`, and
`RECHECKSAVE=RECHECKSAVE`. It will not silently reuse the generic report-send
action.

For current commands and the mandatory gate sequence, use `TEST_GUIDE.md`.

## Legacy interactive helper

Human-in-the-loop cancer-staging workflow for **陳醫師**.

## What it does

For each `待修正` row on the shared Google Sheet:

1. Filter rows: `報告醫師 == 陳醫師` AND column K == `待修正`.
2. Guess `癌別` from `報告內容 / 病理報告 / 臨床診斷 / 備註` with `classify.py` — always shown for user confirmation.
3. Drive the RIS list IE to search the row's `院內病歷號碼` (mirrors `ahk_search_chartno_fn` in `Lib\CH_RIS_LIST_enhance.js:93`).
4. Doctor double-clicks the row → the report IE (`MJB3A002.do`) opens.
5. Launch **cancer-tnm.firebaseapp.com** in Chrome via `Lib\Chrome.ahk` (CDP). Doctor completes T/N/M; helper scrapes the rendered staging block.
6. Append the staging block to `#exam` via `setReportText(text, "", getRisReports(), -1)`.
7. On the follow-up form (`MJB3N002.do`): click **與原始診斷一致** radio, check **癌症評鑑分期格式化**, click **複閱結果**, click **回覆確認** — IDs from `dom_selectors.json` produced by `probe_cancer_form.ahk`.
8. Detect page change (URL / readyState / `#exam` clears) → `WinClose` the report IE.
9. Write back to the sheet: `癌別 = <confirmed>`, column K = `完成` or `已備註`.

## Setup

```powershell
cd "C:\Users\raduser\Documents\reportSet\CH scripts\cancer_staging"
copy .env.example .env    # edit values as needed
uv sync
```

Then obtain **Desktop app** OAuth client credentials from Google Cloud Console (APIs & Services → Credentials → Create → OAuth client ID → Desktop). Save the downloaded JSON at the path set in `.env` `OAUTH_CLIENT_JSON`. First run of `main.py fetch-todo` opens a browser once for consent; the token is cached under `%LOCALAPPDATA%\cancer_staging\token.json`.

## One-time DOM discovery (Phase 0)

```powershell
# 1) With the target follow-up form open in IE (URL contains /webcvis/MJB/MJB3N002.do):
"C:\Users\raduser\Documents\reportSet\AutoHotkey.exe" probe_cancer_form.ahk
# 2) In the follow-up form, press Ctrl+Alt+Shift+D. dom_selectors.json + dom_dump_MJB3N002.txt are written next to the script.
# 3) Confirm the four IDs in dom_selectors.json are non-empty, commit to the repo.
```

## Running

```powershell
run.bat
```

Which does:
- `uv sync` (idempotent).
- `uv run python main.py fetch-todo` → produces `queue.json`.
- Launches `cancer_staging_helper.ahk` — the always-on-top helper GUI that walks each queued row.

## Files

| File | Purpose |
| --- | --- |
| `pyproject.toml` | uv project manifest |
| `.env.example` / `.env` | config (sheet id, doctor name, OAuth path, Chrome debug port) |
| `sheet_client.py` | OAuth + gspread read/write |
| `classify.py` | regex-based `癌別` classifier |
| `main.py` | CLI entry point, including `review-ui` |
| `review_ui.py` / `review_ui_static/` | Local exact-text review and approval interface |
| `queue.json` | Python → AHK handoff (ephemeral, gitignored) |
| `dom_selectors.json` | RIS form + Chrome staging-result selectors (committed) |
| `probe_cancer_form.ahk` | one-shot DOM discovery for `MJB3N002.do` |
| `cancer_staging_helper.ahk` | main AHK v1 helper (client mode, `boneage_CH`-style) |
| `run.bat` | launcher |

## References

- Standard report page DOM: `ych_refactor_worktree\report_page.html` (URL `MJB3A002.do`).
- List page enhancements: `Lib\CH_RIS_LIST_enhance.js` (chart search fn).
- Report editor helpers: `Lib\CH_RIS.ahk` (`get_elements`, `flush`), `Lib\RisImpax.ahk` (`setReportText`).
- Analog helper GUI: `boneage_CH.ahk`.
- Cancer-tnm site: <https://cancer-tnm.firebaseapp.com/#/>
