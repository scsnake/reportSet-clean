# CH_RIS Single-Owner IPC Migration — Session Handoff

_Last updated: 2026-05-21. Author: previous Claude Code session._

## TL;DR

- **Server side: DONE & verified.** `autorun.ahk` hosts the single CH_RIS IPC owner. It reads RIS study info from the IE page and survives IE reopen / re-login / study changes.
- **Client side: STARTED.** Generic client bridge built (proxy object + `func`/`set`/`wb_hwnd`/`click_save`/`reset`/`sub_accno` commands + accNo-change pub/sub). **`YCH_Enh.ahk` is the first converted consumer.** Read-path verified live; write-path needs a re-login to test (see "Session 2"). Other consumers not yet converted.
- **Root inefficiency identified:** every script that `#include <risimpax>` becomes a *redundant* CH_RIS owner (each runs its own ~2/sec IE-polling `update_wb`). Idle = 4 owners; working peak observed = 9.

> **Deploy order matters:** the new YCH_Enh client needs the new owner commands. Always **re-login first** (restart autorun → new server code), *then* relaunch YCH (Win+1). Relaunching YCH against an old autorun makes `getRis*` (routed via the new `func` command) return blank.

---

## What was done this session

1. **Logging rework** (`Lib/DebugLog.ahk`): per-day files `reportSet\logs\debug_YYYY-MM-DD.log`; `DebugLogCleanup(14)` called at `autorun.ahk` startup; the runaway 12 GB `__debug.log` was truncated and removed. Gated by `__is_debug` = `1`.
2. **IPC foundation (additive, default behavior unchanged):**
   - `Lib/CH_RIS_IPC.ahk` — shared protocol (constants, ids, temp-file reply helpers).
   - `Lib/CH_RIS_Server.ahk` — owner listener, chained `0x4A` handler, queue/drain, command dispatch, scalar snapshot.
   - `Lib/CH_RIS_Client.ahk` — `CH_RIS_Call` + wrappers; opt-in via `__CH_RIS_CLIENT`.
   - Transport validated with a 2-process round-trip.
3. **Owner = autorun**: `autorun.ahk` includes `<CH_RIS_Server>` and calls `CH_RIS_Server_Start()` (line ~66) for C hospital. Verified live (`CH_RIS_ping.ahk` → `owner_pid` = Autorun.exe).
4. **Owner-election rail**: `getPlace()` and `CH_RIS_Func()` skip creating a local owner when `__CH_RIS_CLIENT` is set. Flag unset = old behavior (nothing converted yet).
5. **Churn fix**: `try`-guarded both `PostMessage … simpleRIS_main` calls in `update_wb` (`Lib/CH_RIS.ahk` ~541/552) so a missing simpleRIS can't throw → wipe `accNo` → re-parse loop.

### Files changed
`Lib/DebugLog.ahk`, `autorun.ahk`, `Lib/CH_RIS.ahk`, `Lib/getPlace.ahk`, `Lib/RisImpax.ahk`, plus new: `Lib/CH_RIS_IPC.ahk`, `Lib/CH_RIS_Server.ahk`, `Lib/CH_RIS_Client.ahk`, `CH_RIS_ping.ahk`. (`PacsIE/simpleRIS.ahk` was edited then reverted — no net change.)

---

## Session 2 — YCH_Enh converted to client (2026-05-21)

**Goal (per user):** convert `YCH_Enh.ahk` first, verify it works, then roll the pattern out to the other CH_RIS consumers.

### Key discoveries that shaped the design
- At C hospital, **every `getRis*` function delegates to `CH_RIS_Func(A_ThisFunc)`** (`Lib/RisImpax.ahk`). That one function is the single chokepoint for all RIS reads/actions — so client routing lives there, not at the ~hundreds of call sites.
- `CH_RIS_REPORT.gui.*` are **AHK GUI Edit control HWNDs** (system-wide, valid cross-process); `.exam`/`.impression` are getter/setters over those edits; `.wb`/`.inputElements` are IE COM (process-bound). So `getRisReports()` returning the owner's edit HWNDs still lets a client `ControlGetText`/`Edit_SetText` them directly.
- `RisOpened()` finds the **N hospital** WinForms RIS app — dead at C hospital (so `RisState[2]` is irrelevant; `getRis*` ignore it).
- `getRisStudyStatus`/`getRisStudyState` have their C hospital delegation **commented out** → return "" at C hospital → YCH_Enh's batch-report `while` loop (`~line 758`) never runs at C hospital (already dead). 
- `risSendReport` at C hospital delegates to `CH_RIS_Func`, but its body is **interactive** (`GetKeyState`/`MsgBox`) → must run in the client process, not the owner's deferred drain thread. `risSaveReportWin11()` is **empty** (win11 = no-op); this machine is Win10 → full interactive path is live.
- AHK v1 **dedupes `#include <Lib>`** (verified empirically) → safe to add `#include <CH_RIS_Client>` into `RisImpax.ahk` even though sub-includes overlap with the server.

### What was implemented (all gated by `__CH_RIS_CLIENT`; flag unset = unchanged behavior)
1. **`Lib/CH_RIS_Client.ahk`** — added: `CH_Set`/`CH_WbHwnd`/`CH_ClickSave`/`CH_Reset` wrappers; accNo-change subscription (`CH_RIS_Client_AddAccNoHook` + dispatcher on private msg `0x8401`); and the **`CH_RIS_CLIENT_PROXY`** class (`__Get`→`get`, `__Set`→`set`, `__Call`→flush/activate/next/prior/reset/addAccNoChangedHookFn) + `CH_RIS_Client_MakeProxy()`.
2. **`Lib/CH_RIS_Server.ahk`** — new dispatch cases `func` (runs `CH_RIS_Func` on owner; refuses `risSendReport`), `set`, `wb_hwnd`, `click_save`, `reset`, `sub_accno`; added global `__CH_RIS_IPC_AccNoSubs`.
3. **`Lib/CH_RIS.ahk`** — `accNoChanged()` now PostMessages every window in `__CH_RIS_IPC_AccNoSubs` (guarded by `IsObject`; prunes dead windows; empty ⇒ no-op).
4. **`Lib/RisImpax.ahk`** — `#include <CH_RIS_Client>`; `CH_RIS_Func` client-mode early routing (`func` IPC; intercepts `risSendReport` → `CH_RIS_RisSendReport_Client`); new `CH_RIS_RisSendReport_Client()` (interactive bits local, owner ops via IPC); `setReportText` guards its one direct `CH_RIS.inputElements.reportText.value` write behind `!__CH_RIS_CLIENT` (the cross-process `ControlSetText` + `flush()` cover it).
5. **`Lib/getPlace.ahk`** — in client mode sets `CH_RIS := CH_RIS_Client_MakeProxy()` (guarded by `IsFunc`) instead of `new CH_RIS_REPORT()`.
6. **`YCH_Enh.ahk`** — `global __CH_RIS_CLIENT := true` before `#include <risimpax>`. **No other body edits** — the 5 direct `CH_RIS.x` sites (lines 181, 586–589, 976–977, 11161, 11217–11223) all work through the proxy.

### Verified this session
- ✅ Load-only `/iLib NUL` clean (EXIT=0, no stderr): `YCH_Enh.ahk`, `autorun.ahk`, `CH_RIS_ping.ahk`.
- ✅ **Read path, live, non-destructive** (temp `__proxy_smoke.ahk`, since deleted): proxy `__Get` → IPC `get` returned correct `accNo` / `chartNo` / `examtime` and **UTF-8 Chinese `examname` intact** (`巡迴車-乳房篩檢造影(...)`); `__Call` no-op paths don't throw. (Tested against the *running old* owner, which already has `get`/`ping`.)

### NEXT — runtime verification (needs a re-login; current owner runs old server code)
1. **Re-login** (restart autorun → loads new `CH_RIS_Server` + `CH_RIS` code). Confirm single server: `CH_RIS_ping.ahk` → `owner_pid` = Autorun.exe.
2. **Win+1** to launch YCH (CT). In `logs\debug_*.log` confirm **no `CH_RIS_REPORT instantiated` line for YCH_Enh's PID** (it should NOT create a local owner). Watch `sub_accno hwnd=...` appears once.
3. Open a CT study; exercise: F3/F1/F2 (risSendReport — MsgBox should pop in **YCH_Enh**, not autorun), report submit (lines 586/11220 paths), abbr append (11217), chartNo-driven `q` send (976). Confirm reports reach the RIS IE correctly and Chinese is intact.
4. Confirm the owner count dropped (no YCH owner; no duplicate `C hospital RIS Hx` GUI fights).
5. If broken: unset the YCH_Enh flag (`__CH_RIS_CLIENT := false`) to instantly revert to a local owner.

### Rollout status (2026-05-21, batch 1)

**Converted (set `__CH_RIS_CLIENT := true` before the risimpax include):**
- Scalar consumers (objprop=0, mirror YCH_Enh): **YCH_Enh** (verified live), **YCH_XR_Enh**, **YCH_BMD**, **textHotkey**.
- Zero-use opt-outs (use=0; just stop owning): **killUpdate**, **AutoNum** (the two confirmed idle owners), **RazerNaga**, **ImpaxSeriesList**, **ImpaxKeyboardMode**, **getEBMSquareLoc**, **PacsIE/decryptJpeg**, **PacsIE/deleteFinished**, **data_mining/extract_patho_json**, **data_mining/extract_pacshx_json**.
- All load-check clean. Runtime-verify: re-login, then Win+1~4 / trigger each; confirm no `CH_RIS_REPORT instantiated` line for their PID. Revert any one = set its flag `false`.

**Skipped — `Hotstring Helper/*`:** `CH_RIS_REPORT.__New` early-returns when `A_ScriptName` contains "Hotstring Helper" (CH_RIS.ahk:227), so they never become functional owners; no opt-out needed.

### NEXT — object-prop consumers (proxy blind spots — need sub-proxy or bespoke work)
The proxy returns "" for `.wb/.gui/.inputElements/.pacs_hx`. These consumers use them directly, so they need either a proxy sub-proxy (for `.gui` hwnds, `.inputElements` get/click, `.pacs_hx.data`) + new IPC commands, or per-script refactor:
- **feedRIS_ch** — `.inputElements.saveReport.Click()`, `.wb.hwnd` → add `CH_ClickSave`/`CH_WbHwnd` (already exist) or inputElements sub-proxy.
- **YCH_mammo_Enh / Hotstring Helper/YCH_mammo** — `.pacs_hx.data` (→ IPC get), `ch_ris.inputElements.reportText.value` get+set (→ IPC).
- **boneage_CH** — `.wb.document.getElementsByTagName("input")`, `.wb.document.body.innerText` (raw DOM) → refactor to use snapshot/IPC; can't proxy generically.
- **RisHorosSync** — `.wb.ReadyState`/`.wb.document...` (raw DOM) + `.gui.*_edit_auto` (hwnds, cross-process OK). Has explicit `new CH_RIS_REPORT()` (124/126) → currently still an owner; refactor DOM reads first.
- **simpleRIS — LAST.** Hosts the report editor; uses `.wb.ReadyState`, `.inputElements.reportText.value`, `.gui.accNo_edit_auto`. Highest blast radius.

**Explicit `new CH_RIS_REPORT()` (bypass the flag — replace with proxy/getPlace when converting):** showLungCAD:757/1095, miniPACS_bridge:87, chestCT_lungcad_commands:4, getAllJpeg_CH:5, RisHorosSync:126, Hotstring Helper/YCH_mammo:1701.

**Other use≥1 consumers to verify-then-flag (objprop=0, likely proxy-safe but check each):** PacsIE `autoFeed`/`autoFeedFix`/`impaxOpenNext`/`feedRIS`/`prettyOldHx`/`GEZFPpreload`/`FastPacs`/`miniPacsMain`/`mirrorRIS`/`PacsIE`/`getAllJpeg`, `EBMpreload`, `Lib/portallib`, `RisListQuickSearch`, `LDCTreport*`, `data_mining/extract_ris*`, `RadTemplate/*`, `urgentReport/*`, `LunitHelper`, `Lib/RadiologyReportTemplate`.

---

## Session 3 — object-prop infra + remaining consumers (2026-05-21)

**Did Steps 1–6 (all gated by `__CH_RIS_CLIENT`, load-clean). ⚠️ NOTHING runtime-verified yet — re-login + exercise before relying on any of it; revert any consumer with its flag = `false`.**

### Step 1 — sub-proxy + method-routing foundation (`Lib/CH_RIS_Client.ahk`, `Lib/CH_RIS_Server.ahk`)
- Proxy `__Get` now returns **sub-proxies** for `gui` (→ `get_gui_hwnd`), `inputElements` (element-proxy: `.value` get/set → `get_input_value`/`set_input_value`, `.Click()` → `click_input`), `pacs_hx` (`.data` → `get_pacs_hx_data`, `.colNo` → `get_pacs_hx_colno`), `wb` (`.hwnd`/`.ReadyState` → `wb_hwnd`/`wb_ready`), `ris_list_wb` (`.wb.hwnd` → `ris_list_wb_hwnd`); plus top-level `pacs_hx_colNo` (the getter = `pacs_hx[data_type]`, fallback `pacs_hx.colNo`).
- Proxy `__Call` routes a **whitelist** of non-interactive methods via `call_method`: `refresh_info, check_wb, get_fields, Parse_pacs_hx, RIS_list_wb_changed, update_wb, HideWb, showWB, GetModalityCode, parse_exam_type` (server-side `CH_RIS_IPC_CallMethod`, allow-list guarded). Anything else → no-op + log (a stray non-whitelisted method stays visible).
- New server cases: `get_gui_hwnd, get_input_value, set_input_value, click_input, get_pacs_hx_data, get_pacs_hx_colno, wb_ready, ris_list_wb_hwnd, call_method`.
- Removed the dead `__CH_RIS_IPC` flag (defined, never read; the real flag is `__CH_RIS_CLIENT`) + fixed the misleading header comment.
- `.wb.document.*` / `.ris_list_wb.wb.document.*` (raw IE DOM) still can't cross IPC → those callers need refactor, not the proxy.

### Steps 2–5 — consumers converted (flag + minimal edits)
- **YCH_mammo_Enh** (flag only; pacs_hx/pacs_hx_colNo/methods via the new sub-proxies).
- **boneage_CH** (flag only — its `wb.document` funcs `GetCHRisInputValue`/`GetCHRisVisibleValue` are **dead code**; live reads use getRis*/`CH_RIS_GUI` cross-process).
- **RisHorosSync** (flag + `#include <CH_RIS_Client>` in the auto-exec section so transport globals init; `EnsureCHRIS` create-site → guarded proxy; `GetCurrentRisStudyStatus` raw-DOM fallback → client branch = force `refresh_info` + re-read snapshot status).
- **simpleRIS** — **FLIPPED (user chose "flip now")**. Pure flag flip: report edits go through owner GUI edit HWNDs (`getRisReports`, cross-process) + getRis*/proxy; `updateText` is event-driven (msg `0x2019`/`^b`) so IPC cost is per-event. **Highest blast radius — verify reporting works first; revert = flag false + re-login.**
- **showLungCAD** (flag + both `new CH_RIS_REPORT()` → `getPlace()`).
- **Hotstring Helper/YCH_mammo** (flag + line-1701 `new` → `getPlace()`; was a non-functional stub owner, client mode restores real data).

### CORRECTIONS to this handoff's earlier classification (were WRONG)
The earlier "objprop=0" list mis-classified scripts that call `CH_RIS.parse_RIS_LIST()` — it returns a **`DataGridTable` object** built from the **RIS list DOM** (`ris_list_wb.wb.document`), neither of which crosses IPC. These **STAY LOCAL OWNERS** (documented in-file; do NOT flag):
- **feedRIS_ch** (raw list-DOM row iteration + batch report writes; one-shot on-demand).
- **chestCT_lungcad_commands**, **getAllJpeg_CH** (one-shot list tools).
- **miniPACS_bridge** (resident; its report-list feature needs parse_RIS_LIST → would require a bespoke list-IPC + DataGridTable refactor = future work).

### Step 6 — flagged 23 verified objprop=0 / idle consumers (scalar/getRis*-only; no `.wb/.gui/.inputElements/.pacs_hx`, no non-whitelisted methods)
data_mining/{extract_ris_finish_list,extract_RIS_reports,extract_ris_main_list}, EBMpreload, LunitHelper, RadTemplate/{RadTemplate2,RadTemplate_Improved}, urgentReport/{urgentReport,selectCT}, PacsIE/{autoFeed,autoFeedFix,feedRIS,getAllJpeg,impaxOpenNext,miniPacsMain,mirrorRIS,prettyOldHx,FastPacs,GEZFPpreload,PacsIE}, LDCTreport, LDCTreport_Fleischner2017, RisListQuickSearch.
- 4 of these (feedRIS, mirrorRIS, FastPacs, PacsIE) **don't load-check clean in isolation — but that's PRE-EXISTING** (missing optional libs `Gdip`/`Class_CTLCOLORS`, working-dir-relative `jpegDirName.ahk`, a pre-existing duplicate `stringupper`); verified the HEAD versions fail identically two lines up. The flag edit is correct.
- **NOT flagged (skipped):** shared libs (portallib, RadiologyReportTemplate, .NetGetControl, SearchImage, changePortalPassword) — flagging a lib converts every includer **incl. autorun** (the owner!); Hotstring Helper/* stubs (early-return in `__New`); `PacsIE/simpleRIS_`/`simpleRIS_proto` (editor variants — verify if active); `RisImpaxPolling` (polling engine — special); `RIS_PACS_share/*` (untracked copy). Several earlier "candidates" (extract_with_contrast_chest, searchOpHx, selectCT_Query) have **commented-out** risimpax → not owners at all.

### Runtime verification still required (only the user can do this)
Re-login (restart autorun → new server/CH_RIS code) → confirm single owner (`CH_RIS_ping.ahk` → owner_pid = Autorun.exe) → Win+1~4 → exercise each modality + **write a real report via simpleRIS** + mammo history (YCH_mammo) + RisHorosSync sync + showLungCAD. Watch `logs\debug_*.log` for proxy/`call_method`/sub-proxy logs and confirm no `CH_RIS_REPORT instantiated` for converted PIDs. Revert any breakage = that script's `__CH_RIS_CLIENT := false`.

### Post-restart verification + efficiency fixes (2026-05-21, after re-login)
Verified live after the user restarted autorun/YCH/simpleRIS: only `autorun.ahk` + `RisImpaxPolling.ahk` instantiated owners; `simpleRIS`, `RisHorosSync`, `YCH_Enh`, `showLungCAD` ran as **clients** (no local owner); one `sub_accno` (YCH_Enh); **zero** proxy/IPC errors. Two inefficiencies then fixed (both take effect on next re-login):
1. **RisImpaxPolling opted out** (`RisImpaxPolling.ahk` — corrects the earlier "skip"): it's the OLD N hospital RIS/Impax poller (`RisOpened`/`impaxOpened`/`ActivePacs`) and never touches the `CH_RIS` object, but `#include <risimpax>` auto-created an unused IE-polling owner (the 2nd owner + redundant `update_wb` flood + duplicate `CH_RIS_GUI`). `__CH_RIS_CLIENT := true` → getPlace returns a never-referenced proxy; its real N hospital/Impax polling+broadcasting is untouched. (It stays alive because it has Impax-side subscribers — so it's NOT dead, just shouldn't own CH_RIS.)
2. **`update_wb` idle-log throttle** (`Lib/CH_RIS.ahk`, addresses old TODO #5): the per-poll `entry` + `accNo unchanged` lines (~2/sec, ~100 MB/day) now emit only when the wb/ReadyState/accNo signature changes or every 60s heartbeat. Real events (accNo CHANGED / RS->4 / wb lost / re-acquired) still log every time. Logging-only change — no poll/refresh/PostMessage logic altered.

---

## ▶ DONE (superseded by Session 3) — original next-session plan

> Handed off deliberately: the remaining work is the most delicate (sub-proxy infra, raw-DOM refactors, simpleRIS = report editor). Do it with a fresh context budget. Batches 0–1 are committed (`13002db`, `6e67b5d`) and load-clean; **runtime-verify batch 1 first** (re-login → Win+1~4 → confirm XR/BMD/textHotkey write reports + no `CH_RIS_REPORT instantiated` for their PIDs).

### Step 1 — build proxy sub-proxy support (Lib/CH_RIS_Client.ahk)
Make `CH_RIS_CLIENT_PROXY.__Get` return small sub-proxy objects instead of "" for the object props, each forwarding to the owner over IPC:
- `.gui` → sub-proxy whose `__Get(field)` returns the owner's edit **hwnd** via a new `get_gui_hwnd` command (cache per field). Owner hwnds are valid cross-process, so callers' `ControlGetText`/`Edit_SetText`/`Edit_SetSel` keep working.
- `.inputElements` → sub-proxy whose `__Get(name)` returns an *element-proxy* exposing `.value` (get→`get_input_value`, set→`set_input_value`) and `.Click()` (→`click_input {name}`; generalises the existing `click_save`).
- `.pacs_hx` → sub-proxy whose `.data` → new `get_pacs_hx_data` command (nested array; JXON-serialisable — `parseRisHistory` already returns it).
- `.wb` → sub-proxy: `.hwnd` → existing `wb_hwnd`; `.ReadyState` → new `wb_ready`. **`.wb.document.*` cannot be proxied** — those callers must be refactored (see Step 3).

New server cases needed (CH_RIS_Server.ahk dispatch): `get_gui_hwnd`, `get_input_value`, `set_input_value`, `click_input`, `get_pacs_hx_data`, `wb_ready`.

### Step 2 — convert the proxy-able object-prop consumers (set flag, verify)
- **feedRIS_ch** — `.inputElements.saveReport.Click()` (→ click_input/CH_ClickSave), `.wb.hwnd` (→ CH_WbHwnd). No raw DOM. Convert after Step 1.
- **YCH_mammo_Enh** (+ `Hotstring Helper/YCH_mammo`) — `.pacs_hx.data` (→ get_pacs_hx_data), `ch_ris.inputElements.reportText.value` get+set (→ get/set_input_value). The Hotstring one also has explicit `new CH_RIS_REPORT()` at 1701.

### Step 3 — refactor raw-DOM consumers (no generic proxy possible)
- **boneage_CH** (503/522): reads `wb.document` inputs + `body.innerText`. The fields it wants (accNo/chartNo/examname/patname…) are in the scalar snapshot → replace DOM reads with `CH_GetState()` / `CH_Get(field)`.
- **RisHorosSync** (142/495/502 DOM; 727-735 gui hwnds): gui-hwnd reads work via the `.gui` sub-proxy; replace `wb.ReadyState`/`wb.document` with `wb_ready` + snapshot. Then drop its explicit `new CH_RIS_REPORT()` (124/126).

### Step 4 — simpleRIS LAST (highest blast radius; it hosts the report editor)
Uses `.wb.ReadyState` (→ wb_ready), `.inputElements.reportText.value` (→ get_input_value), `.gui.accNo_edit_auto` (→ gui sub-proxy). Convert + verify carefully on its own; keep a quick revert (flag false).

### Step 5 — explicit `new CH_RIS_REPORT()` sites
For objprop=0 ones (showLungCAD, miniPACS_bridge, chestCT_lungcad_commands, getAllJpeg_CH): set `__CH_RIS_CLIENT` and replace `CH_RIS := new CH_RIS_REPORT()` with a dynamic proxy create (`if IsFunc(f:="CH_RIS_Client_MakeProxy") CH_RIS := %f%()`) — **don't** call undefined funcs directly (AHK v1 load-time resolution, see [[reference_ahk_v1_loadtime_func_resolution]]).

### Step 6 — verify-then-flag the remaining objprop=0 consumers
The ~15 listed above. Quick per-file check (no `.wb/.gui/.inputElements/.pacs_hx`, no odd `CH_RIS :=`), then set the flag like batch 1.

**Reminder:** any new cross-lib helper referenced from getPlace/CH_RIS (reachable without risimpax) must be called dynamically + IsFunc-guarded, or it's a load crash (that's what bit RisHorosSync).

---

## Architecture

- **Transport:** WM_COPYDATA (`0x4A`, dwData namespace `0x43544852` = "CHR") carries a JSON request; reply is a JSON temp file `%TEMP%\ch_ris_resp_<id>.json` (avoids cross-process SendMessage reply deadlock).
- **Server window:** hidden `CH_RIS_SERVER` (class `AutoHotkeyGUI`), created only in autorun. The `0x4A` handler chains to any prior handler.
- **Server commands:** `ping`, `get_state`, `get`, `set_report`, `flush`, `set_and_flush`, `activate`, `next_study`, `prior_study`, `refresh`, **`set`, `func`, `wb_hwnd`, `click_save`, `reset`, `sub_accno`** (Session 2). `func` runs `CH_RIS_Func` on the owner (refuses interactive `risSendReport`); `sub_accno` registers a client window for accNo-change pings.
- **Client wrappers:** `CH_Ping`, `CH_GetState`, `CH_Get`, `CH_SetReport`, `CH_FlushReport`, `CH_SetAndFlush`, `CH_Activate`, `CH_NextStudy`, `CH_PriorStudy`, `CH_Refresh`, **`CH_Set`, `CH_WbHwnd`, `CH_ClickSave`, `CH_Reset`** (Session 2). Plus the **`CH_RIS_CLIENT_PROXY`** drop-in object and `CH_RIS_Client_AddAccNoHook`.
- **Snapshot fields (scalars only):** accNo, chartNo, examname, examtime, examDate, patname, patidno, gender, age, patno, namec, mccid, status, memo, remark, exam, impression, report.
  - ⚠️ **Object properties cannot cross IPC:** `.wb`, `.gui`, `.inputElements`, `.pacs_hx`. Clients using these need redesign (snapshot fields or new commands), not a 1:1 swap.

---

## Root cause of the multi-owner inefficiency

`Lib/RisImpax.ahk:33` runs `thisPlace:=getPlace()` in its **auto-execute** section, and `Lib/getPlace.ahk:30` **auto-creates** a polling `CH_RIS_REPORT`. Therefore **any script that `#include <risimpax>` becomes a CH_RIS owner at load**, whether or not it uses RIS — each running its own ~2×/sec `update_wb` IE poll against the *same* page.

Evidence (from `logs\debug_*.log`, `CH_RIS_REPORT instantiated` lines):
- **Idle (autorun + helpers):** autorun, **killUpdate**, **textHotkey**, **AutoNum** = 4 owners.
- **Working peak:** + YCH_XR_Enh, simpleRIS, RisImpaxPolling, YCH_Enh, showLungCAD = up to 9 owners.

Secondary: `update_wb` logs `entry` + `accNo unchanged` **every poll** even when idle (last 400 lines were 100% idle noise).

---

## NEXT SESSION — TODO

### 1. CH_RIS client behavior recheck
Re-verify the IPC client path against the live owner before/after changes (use `CH_RIS_ping.ahk`). Confirm `get_state` returns correct live data and write commands (`set_and_flush`) work end-to-end with autorun as owner.

### 2. Audit every script that includes / creates CH_RIS
Classify each (see table below). For each owner:
- **Doesn't use CH_RIS** (no `CH_RIS.` / `getRis*` / `parseRisExam*`) → set `global __CH_RIS_CLIENT := true` **before** the `#include <risimpax>` line (so the auto-exec `getPlace()` skips owner creation). Quick win, near-zero risk.
- **Uses CH_RIS** → convert calls to the client API, then set `__CH_RIS_CLIENT`.

Reproduce the audit:
```
# scripts that pull in CH_RIS (become owners via risimpax auto-exec)
rg -n "#include\s*<(risimpax|getPlace|CH_RIS)>" -i
# explicit owner creation (bypasses __CH_RIS_CLIENT guard)
rg -n "new CH_RIS_REPORT"
# who actually USES the object
rg -n "CH_RIS\.|getRis|parseRisExam|risSendReport"
# server creation — must stay autorun-only
rg -n "CH_RIS_Server_Start"
```

### 3. ⚠️ Be aware of new CH_RIS **server** creation
Only **one** process may host the server. Currently only `autorun.ahk:66` calls `CH_RIS_Server_Start()`. When converting clients, make sure none of them start a server (clients include `<CH_RIS_Client>`, **not** `<CH_RIS_Server>`). Two `CH_RIS_SERVER` windows = clients pick one arbitrarily.

### 4. Clean root fix (recommended)
Decouple **place detection** from **owner creation**: `getPlace()` should only detect place; CH_RIS_REPORT creation should be explicit (autorun only). That removes the "include risimpax ⇒ become owner" trap for all ~50 scripts at once. Watch the explicit `new CH_RIS_REPORT()` sites too (they bypass the flag).

### 5. State-change-only logging
In `update_wb`, log only when the state signature changes (+ a periodic heartbeat), and back off the poll when the wb is lost. Kills the idle log flood regardless of owner count.

---

## Audit results (2026-05-21)

**Server creation:** only `autorun.ahk:66` `CH_RIS_Server_Start()`. ✓

**Explicit `new CH_RIS_REPORT()` (bypass `__CH_RIS_CLIENT` — handle individually):**
`CH scripts/RisHorosSync.ahk:126`, `Hotstring Helper/YCH_mammo.ahk:1701`, `showLungCAD.ahk:757,1095`, `PacsIE/miniPACS_bridge.ahk:87`, `PacsIE/getAllJpeg_CH.ahk:5`, `PacsIE/chestCT_lungcad_commands.ahk:4`, plus the lazy creators `getPlace.ahk:30` and `RisImpax.ahk:4843`.

**Confirmed CH_RIS consumers (need client conversion, not just opt-out):**
`autorun.ahk` (owner), `PacsIE/simpleRIS.ahk` (hosts report editor; uses `.wb/.gui/.inputElements` — convert last/carefully), `YCH_Enh.ahk`, `YCH_XR_Enh.ahk`, `YCH_mammo_Enh.ahk`, `YCH_BMD.ahk`, `boneage_CH.ahk`, `showLungCAD.ahk`, `CH scripts/RisHorosSync.ahk`, `PacsIE/feedRIS_ch.ahk`, `PacsIE/miniPACS_bridge.ahk`, `PacsIE/chestCT_lungcad_commands.ahk`, `PacsIE/getAllJpeg_CH.ahk`, `textHotkey.ahk` (5 `getRis*` refs), `Hotstring Helper/{YCH,YCH_main,YCH_mammo,YCH_XR}.ahk`, `Lib/MammoPdfDB.ahk`.

**Opt-out candidates — include risimpax but show 0 CH_RIS use (verify each before flipping):**
`killUpdate.ahk` ✓0, `AutoNum.ahk` ✓0, and (likely) `data_mining/extract_*.ahk`, `EBMpreload/EBMpreload.ahk`, `getEBMSquareLoc.ahk`, `ImpaxKeyboardMode.ahk`, `ImpaxSeriesList.ahk`, `LDCTreport*.ahk`, `LunitHelper/LunitHelper.ahk`, `PacsIE/{autoFeed,autoFeedFix,impaxOpenNext,miniPacsMain,mirrorRIS,PacsIE,prettyOldHx,decryptJpeg,deleteFinished,FastPacs,GEZFPpreload}.ahk`, `RazerNaga.ahk`, `RisListQuickSearch.ahk`, `RadTemplate/*.ahk`, `urgentReport/*.ahk`, `Lib/{RadiologyReportTemplate,changePortalPassword}.ahk`. **Verify per file** with the `rg` commands above — some may use RIS data indirectly.

---

## How to test / operate

- **Probe the owner (non-disruptive, client-only):** run `AutoHotkey.exe CH_RIS_ping.ahk` → tooltip + `%TEMP%\ch_ris_ping.txt` show `owner_pid`, accNo, examname, examtime. Good for before/after checks.
- **Logs:** `reportSet\logs\debug_YYYY-MM-DD.log` (when `__is_debug` = `1`). Useful greps: `wb re-acquired`, `wb lost`, `EXCEPTION`, `accNo CHANGED`, `CH_RIS_REPORT instantiated`.
- **Startup workflow (important):** autorun does NOT launch simpleRIS/YCH. Normal flow: autorun (resident, `Autorun.exe`) → user presses **Win+1~4** (ych/yxr/mamm/bmd) → launches `YCH_*` → each `gosub openSimpleRis` launches simpleRIS (`YCH_XR_Enh.ahk:15001`).
- **⚠️ Running `Autorun.exe` kills sibling AHK scripts** (KillReportSetProcs / `#SingleInstance,force`) but does **not** relaunch YCH/simpleRIS. To restore: re-login, or press Win+1~4.
- **Code changes to `Lib/CH_RIS.ahk` / autorun take effect only after autorun restart** (re-login), which kills siblings — plan changes accordingly.
- **Syntax check (load-only):** `MSYS_NO_PATHCONV=1 "…/AutoHotkey.exe" /iLib NUL /ErrorStdOut "…/script.ahk"; echo EXIT=$?` (pass = `EXIT=0`, empty stderr).

## Verified scenarios
- ✅ IE pages stay, autorun reopens → owner reads study immediately.
- ✅ autorun stays active, study changes / IE reopened / re-login → owner re-acquires (19+ `wb re-acquired`, new hwnds) and reads the current study.
