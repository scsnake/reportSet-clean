# Cancer staging pipeline — test guide

Last updated: 2026-09-28 (Asia/Taipei)

This guide is the continuation point for another Codex session. Read
`IMPLEMENTATION_PLAN.md` first. Do not skip gates and do not repeat a live POST
after a lost session without first checking the RIS report.

## Current checkpoint

- Gate 1 local/offline: **passed** (`29 passed`).
- Interactive review UI: **passed** API tests and a Playwright/Edge browser flow
  covering copy, edit, save, acknowledgment, exact-text approval, counters, and
  case navigation. The UI is loopback-only and has no RIS-send operation.
- Gate 2 manual MJB3N002 capture: **passed** at 2026-09-28 17:01
  (pre-submit contract verified; verified form disappeared after the manual click).
- Gate 3 remote mocked endpoint: **passed** (`6 passed`).
- Remote code is staged as uncommitted changes in
  `/home/raduser/PycharmProjects/webris-project`; the live port 7200 process has
  **not** been restarted and does not serve the new endpoint yet.
- Gate 4 deployment health check: **passed** at 2026-09-28 17:05. Prefect flow
  `f7746985-4b9f-426b-a9ed-7ae7072a6cbb` is running with one server PID; login,
  authenticated status, and a read-only worklist query succeeded.
- Gate 5 live dry-run: **passed** for one user-supplied canary. The endpoint
  returned `submitted=false`, verified `MJB3N002`, and reported the pinned
  `recheck=0`, `cancer=Y`, `RECHECKSAVE` action.
- Gate 6 live canary: **passed**, including user visual inspection. The API returned
  `submitted=true`; a separate read-only fetch confirmed accession identity,
  normalized report equality, the staging suffix, and zero remaining
  clinician-notification markers. The user then confirmed the RIS result visually.

## Gate 1 — rerun local tests

```powershell
cd "C:\Users\raduser\Documents\reportSet\CH scripts\cancer_staging"
uv sync --extra dev
uv run python -m py_compile main.py workflow.py review_ui.py tnm_catalog.py batch.py api_client.py sheet_client.py
uv run pytest -q
```

Expected: `29 passed`.

The AHK monitor must also pass a load-only check:

```powershell
cd "C:\Users\raduser\Documents\reportSet"
& ".\AutoHotkey.exe" /iLib NUL /ErrorStdOut "CH scripts\cancer_staging\monitor_cancer_recheck.ahk"
```

Expected: no output. This validates syntax without executing the script.

## Gate 2 — manual MJB3N002 contract capture

The monitor is read-only. It does not click, submit, or store patient identity or
report text. Its log contains the report character count, form/control values,
the submit handler, and navigation state.

Do **not** start it in advance. Wait until the user says exactly **start monitor**;
then start it in the background:

```powershell
cd "C:\Users\raduser\Documents\reportSet"
$monitor = Start-Process ".\AutoHotkey.exe" `
  -ArgumentList '"CH scripts\cancer_staging\monitor_cancer_recheck.ahk"' `
  -WindowStyle Hidden -PassThru
$monitor.Id
```

Then perform one normal manual cancer-staging re-report in IE:

1. Choose a case whose exact formal staging text you have reviewed.
2. Open its reported-study page (`MJB3N002`).
3. Append the approved formal staging block manually.
4. Select **與原始診斷一致**.
5. Check **癌症評鑑分期格式化**.
6. Wait for the tray message saying the required contract was captured. If it
   does not appear, press `Ctrl+Alt+Shift+M` once.
7. Manually click **回覆確認**.
8. Tell Codex that the manual re-report is complete. Codex should inspect only the
   newest `logs/recheck_monitor_*.log` and verify:
   `contract_ok=true`, `recheck=0`, `cancer=Y`, the `RECHECKSAVE` onclick, and a
   `post_submit_observed` event.

Exit the monitor with `Ctrl+Alt+Shift+Q`. If a hidden process must be stopped from
PowerShell, stop only the PID returned by `Start-Process`; never kill every
AutoHotkey process.

## Gate 3 — rerun remote mocked tests

This test does not contact RIS and does not issue an upstream POST.

```powershell
ssh gpu-host.example.invalid "cd /home/raduser/PycharmProjects/webris-project/webris/server && /opt/anaconda/envs/scs/bin/python -m py_compile app.py ch_ris_client.py test_cancer_staging_recheck.py && /opt/anaconda/envs/scs/bin/python -m unittest -v test_cancer_staging_recheck.py && git diff --check"
```

Expected: six tests pass.

## Gate 4 — restart through Prefect and health-check

Only proceed after Gate 2 is confirmed. Before restart, record the current commit,
diff, live PID, and deployment state. Restart through
`webris-server-pipeline/webris-server-deploy` in
`/opt/prefect-orchestration`; do not launch a second Flask process.

After restart, verify:

1. port 7200 has one listener and a new expected PID;
2. `/api/status` responds;
3. login succeeds;
4. a read-only worklist query succeeds;
5. server logs contain no startup exception.

No report submission belongs in this gate.

## Review workflow for a pasted list

Save the pasted tab-separated spreadsheet export as `input.tsv`, including the
header row. Quoted multiline reports are supported.

```powershell
cd "C:\Users\raduser\Documents\reportSet\CH scripts\cancer_staging"
uv run python main.py import-tsv --input input.tsv
uv run python main.py sync-catalog
uv run python main.py prepare
uv run python main.py review-ui
```

The browser opens at `http://127.0.0.1:8765/`. Review patient/study identifiers,
source reports, evidence, assumptions, and warnings. You may edit the exact formal
text, save it, then click **Approve** (one click; Ctrl+Enter also works). Saving a changed text invalidates any
prior approval. The UI updates only `review.json` and cannot call the RIS API.

The command-line equivalent remains available:

```powershell
uv run python main.py show-review
```

For each study, inspect the evidence, assumptions, warnings, exact formal text,
and its SHA. A proposal is not approval. Set corrected values when needed:

```powershell
uv run python main.py set-tnm --accession ACCESSION --t T_VALUE --n N_VALUE --m M_VALUE
uv run python main.py show-review --accession ACCESSION
uv run python main.py approve --accession ACCESSION --expect-sha TEXT_SHA_FROM_SHOW_REVIEW
```

Any T/N/M edit invalidates prior approval. Catalog collisions are displayed and
must not be silently accepted.

To rerun the browser smoke test without changing the real `review.json`, copy it
to `review_browser_test.json`, start that copy with the local server helper, and
run `tests/review_ui_browser.py`. The test copy is gitignored.

## Gate 5 — one live dry-run

After Gate 4, preview all approved items. This logs in and reads RIS but the new
endpoint performs no upstream POST:

```powershell
uv run python main.py batch
```

Review `batch_results.json`. A successful preview must report
`dry_run=true`, `submitted=false`, the pinned action, and expected old/new report
hashes and lengths. Stop on any identity, page, source-text, or context mismatch.

For a user-provided accession and complete modified report, save the text as the
ignored `canary_report.txt` and use the dedicated one-case path:

```powershell
uv run python main.py canary --accession ACCESSION --report-file canary_report.txt
```

The command requires the current RIS report to be an exact normalized prefix and
extracts only the appended staging block. It refuses altered original wording or
a different separator layout. Record the returned `staging_sha256`.

## Gate 6 — one live canary, then batch

Run `show-review` again and have the user reconfirm the exact canary text. Obtain
the current approved batch SHA printed by that command. Then execute exactly the
approved manifest:

```powershell
uv run python main.py batch --execute --expect-batch-sha APPROVED_BATCH_SHA
```

For the first use, approve only one case so this command is a one-case canary.
Manually verify the saved RIS report and reply state before approving or executing
the remaining cases. Never retry an uncertain POST blindly; inspect RIS first.

For the direct one-case path, execute only after the user reconfirms its preview:

```powershell
uv run python main.py canary --accession ACCESSION --report-file canary_report.txt `
  --execute --expect-staging-sha STAGING_SHA_FROM_PREVIEW `
  --expect-modified-sha MODIFIED_REPORT_SHA_FROM_PREVIEW
```

## Rollback

The remote worktree was clean before these staged files were copied. Rollback must
use a normal Git revert/restore of the reviewed files or deploy the recorded prior
commit, followed by the same Prefect deployment restart. Do not use
`git reset --hard` and do not alter unrelated worktree changes.
