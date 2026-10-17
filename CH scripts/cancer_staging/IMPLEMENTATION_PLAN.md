# Cancer staging re-report pipeline — implementation and test handoff

Last investigated: 2026-09-28 (Asia/Taipei)

## Objective

Build a human-approved pipeline for reported C hospital RIS studies:

1. Import the manually pasted spreadsheet rows (or fetch them from Google Sheets).
2. Suggest a cancer type and conservative T/N/M candidates from the original report.
3. Render the formal staging block using the same catalog and formatting logic as
   <https://cancer-tnm.firebaseapp.com/>.
4. Require explicit approval of the exact text for every study.
5. Use the WebRIS API on `gpu-host.example.invalid:7200` to append the approved block to the existing
   report, select `與原始診斷一致`, select `癌症評鑑分期格式化`, and dispatch
   `RECHECKSAVE`.
6. Record an auditable result and only then mark the source row complete.

No clinical suggestion is sent automatically. A row marked `待修正` is work to
review, not permission to submit it.

## Investigated system state

### Windows workspace

Existing project:

`C:\Users\raduser\Documents\reportSet\CH scripts\cancer_staging`

It already contains:

- Google Sheet OAuth/read/write support (`sheet_client.py`).
- A deterministic cancer-type classifier (`classify.py`).
- An AHK helper that can manually append text and click the IE form.
- A captured MJB3N002 DOM showing the required controls.

Known gaps:

- The sample sheet uses `覆審醫師`, which the existing reader does not recognize.
- The existing queue omits accession number and study date, both required for safe
  study identity checks.
- Status K already contains `待修正`, but the old write-back refuses to replace any
  non-empty value, so it cannot safely transition the row to `完成`.
- Cancer labels such as `Colorectal` do not directly match the TNM catalog document
  id `Colorectum`.
- There is no durable approval/hash model and no 7200 API batch client.

### gpu-host.example.invalid WebRIS server

- Repository: `/home/raduser/PycharmProjects/webris-project`
- Server code: `webris/server`
- Live command: `/opt/anaconda/envs/scs/bin/python -u app.py`
- Live port: `7200`
- Process is managed by Prefect deployment
  `webris-server-pipeline/webris-server-deploy` from
  `/opt/prefect-orchestration`.

The existing API has login, worklist, study detail, and generic report submission.
Generic submission dispatches `SAVE`/`SAVETEM`; it must not be reused unchanged for
this task.

The captured MJB3N002 form establishes the re-report contract:

- form: `MJB3N2Form`
- radio: `recheck=0` (`與原始診斷一致`)
- checkbox: `cancer=Y` (`癌症評鑑分期格式化`)
- submit action: `RECHECKSAVE=RECHECKSAVE`

The current HTTP client already extracts all hidden fields and the Struts token from
the real form, so the new operation should overlay the three fixed values on the
fresh form rather than maintain another hard-coded full form template.

### TNM catalog website

The site reads the `cancer_type` collection from the public `cancer-tnm` Firestore
project. Its generated report format is present in the deployed JavaScript and can
be reproduced deterministically.

Catalog data is not internally conflict-free. Examples discovered on 2026-09-28:

- Colorectum: `T1/2N2a` maps to both IIIA and IIIB.
- Lung: `T1aN1`, `T1bN1`, and `T1cN1` map to both IIA and IIB.
- Additional conflicts exist for endometrium, ovary, and prostate.

The website returns the first matching row. The pipeline may show that site result,
but must flag the collision and prohibit unattended approval.

The Colorectum document reported Firestore `updateTime`
`2022-07-27T08:40:27.040313Z`. “Matches the website” therefore does not necessarily
mean “latest external AJCC publication.” Catalog provenance must be displayed with
every generated batch.

## Planned architecture

### Local review pipeline

Commands should follow this state progression:

```text
import-tsv/fetch-todo -> prepare -> review/approve -> preview -> execute
```

Each case stores:

- accession and chart number;
- source row and study/report dates;
- original report/pathology/diagnosis;
- mapped TNM catalog cancer id;
- proposed T/N/M values;
- evidence separately from assumptions;
- catalog stage, collision warnings, and source `updateTime`;
- exact rendered staging text;
- approval state and SHA-256 of the approved text;
- execution result, timestamps, and non-PHI audit details.

Changing an approved field or the rendered text invalidates approval.

### Interactive review UI

The local loopback-only review interface is implemented in `review_ui.py` and
`review_ui_static/`. It displays the source patient/study identifiers, original
report, pathology, diagnosis/comments, agent evidence/assumptions/warnings, and
editable formal staging text. Identifiers and report text have copy controls.

All mutations require an in-memory review token and JSON same-origin requests.
Writes use optimistic text-SHA comparison and atomic file replacement. Saving a
changed text updates its SHA and returns the case to pending; approval is a single
click (no confirmation dialog, since 2026-09-28) and remains bound to the exact
saved SHA. The UI contains
no RIS submission endpoint.

Suggestion rules must be conservative. For example, wall thickening without an
invasion-depth statement should not become a definite T category. An explicit
negative finding and a user-accepted assumption are separate fields.

### Server endpoint

Add a dedicated endpoint, not an option on generic report submission:

```text
POST /api/study/<index>/cancer-staging
```

Default behavior is `dry_run=true`. The endpoint must:

1. Resolve and verify accession, chart number, worklist context, and MJB3N002 page.
2. Compare an expected SHA-256 of the current report to prevent stale overwrites.
3. Append only the approved block; return a no-op if the identical suffix exists.
4. Return conflict if a different cancer-staging block is already present.
5. Start from freshly extracted MJB3N2Form fields.
6. Remove `SAVE`, `SAVETEM`, and other dispatch actions.
7. Pin `recheck=0`, `cancer=Y`, and `RECHECKSAVE=RECHECKSAVE` server-side.
8. Validate the upstream response and return structured status.

Clients cannot override the three fixed recheck action values.

### Batch execution

- Preview every approved item first.
- Execute serially and retain the existing per-session throttle.
- Stop/skip a row on identity mismatch, stale report hash, catalog conflict,
  missing approval, or unexpected upstream response.
- Never retry a potentially successful POST blindly.
- Mark the sheet row complete only after confirmed upstream success, using a
  compare-and-swap transition from `待修正` to `完成`.
- For manual TSV input, produce a result TSV for paste-back.
- Audit logs contain accession, hashes, timestamps, and result codes, not patient
  names or complete report text.

The existing AHK helper remains available as a manual fallback.

## Test gates

No later gate should start until the prior gate passes.

### Gate 1 — offline/local tests

- Multiline quoted TSV parsing.
- Header aliases including `覆審醫師`.
- Catalog download/cache and provenance.
- Website-compatible stage resolution and conflict detection.
- Formal staging text snapshot.
- Approval hash invalidation.
- Sheet compare-and-swap behavior with a fake worksheet.

### Gate 2 — MJB3N002 manual contract capture

Run the AHK background monitor while the user manually re-reports one cancer-staging
case in IE. Capture a redacted form-field snapshot immediately before submit and the
navigation/result state afterward. The capture must confirm `recheck=0`, `cancer=Y`,
and the `RECHECKSAVE` dispatch without writing patient name or full report text to
the diagnostic log.

### Gate 3 — server mocked tests

Using a de-identified MJB3N002 fixture and mocked HTTP session, assert exact form
overlay/removal, dry-run behavior, duplicate/conflict handling, and stale-hash
rejection. Run `py_compile` and the focused server test suite.

### Gate 4 — deployment health check

Deploy through the repository and Prefect-managed process. Verify `/api/status`,
login, and an ordinary read-only worklist query. Do not submit a report here.

### Gate 5 — live dry-run

For one explicitly approved accession, call the new endpoint with `dry_run=true`.
Compare returned identity, page id, old/new lengths, and hashes with the review
record. No upstream POST occurs.

### Gate 6 — one live canary

After the user confirms the exact text again, submit one study. Manually inspect RIS
for appended text, same-diagnosis radio, cancer-format checkbox, and completed reply.
Only after this passes may batch mode be enabled for the remaining approved rows.

## Deployment and rollback

Implementation changes remain uncommitted until explicitly reviewed/approved for a
Git commit. The gpu-host.example.invalid repo was clean at investigation time.

Production restart must use the Prefect deployment, not a second background Flask
process. Record the current Git commit and Prefect run id before restart. Rollback is
performed by reverting the implementation change (or deploying the recorded prior
commit) and restarting the same Prefect deployment; do not use `git reset --hard`.

## New-session continuation checklist

1. Read `CURRENT_HANDOFF.md`, then this file completely.
2. Run `git status --short` in the Windows workspace and
   `/home/raduser/PycharmProjects/webris-project` before editing.
3. Read the current test log/status section below.
4. Do not repeat a live POST solely because the prior session lost context. Verify
   RIS state first.
5. Keep the user informed before every interactive or live-data test gate.

## Progress log

- 2026-09-28: investigation completed; plan approved for implementation.
- 2026-09-28: implementation started. No live RIS mutation authorized until the
  per-case approval and canary gates are reached.
- 2026-09-28: local review/catalog/batch pipeline implemented; local suite passes
  22 tests. Dedicated endpoint staged on gpu-host.example.invalid and its focused mocked tests pass.
  Live port 7200 has not been restarted. Gate 2 manual form-contract capture is
  next; see `TEST_GUIDE.md`. The monitor must be started only after the user says
  `start monitor`.
- 2026-09-28 17:01: Gate 2 passed. The PHI-safe monitor captured the exact
  MJB3N2Form pre-submit contract (`recheck=0`, `cancer=Y`, `RECHECKSAVE`, token
  present) and then observed the verified form disappear after the user's manual
  click. The monitor was stopped after capture.
- 2026-09-28 17:05: Gate 4 passed. The updated server was restarted through
  Prefect flow run `f7746985-4b9f-426b-a9ed-7ae7072a6cbb` (single Flask PID
  620939). Authenticated status and a read-only worklist query succeeded. No RIS
  report was submitted by this gate.
- 2026-09-28: Gate 5 passed for a user-supplied canary. The API preview verified
  the reported-study page and pinned action, returned `submitted=false`, and
  reproduced the supplied separator layout. A narrow filter for explicit
  `通報臨床醫師...` markers is active and audited by removal count. No identifier
  or report text is stored in this tracked handoff.
- 2026-09-28: Gate 6 passed, including user visual inspection. One explicitly confirmed canary returned
  `submitted=true`. A separate read-only fetch verified the accession identity,
  normalized saved content, staging suffix, and absence of clinician-notification
  markers. RIS trimmed the final newline during storage; no retry was performed.
  The user subsequently confirmed the RIS result visually.
- 2026-09-28: implemented the local interactive review UI. The focused local
  suite passes 29 tests, and the Playwright/Edge flow passed copy, edit/save,
  exact-text approval, progress update, and next-case navigation with no browser
  console errors. The two real cases in `review.json` remain unchanged/pending;
  browser mutation tests used an ignored copy.
- 2026-09-28: user manually edited and saved both current staging blocks through
  the webpage. Both cases remain pending exact-text approval and have not been
  sent. `CURRENT_HANDOFF.md` records the live UI state, current saved hashes, the
  server-side original-plus-staging append contract, and the required approval,
  two-case dry-run, explicit live confirmation, and execution sequence for the
  next Claude session.
