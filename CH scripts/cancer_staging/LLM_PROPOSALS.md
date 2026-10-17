# Formal pipeline and the LLM proposal step

## Pipeline

```text
1. paste sheet rows      -> import-tsv            -> cases.json
2. LLM proposal          -> proposals.json        (Claude writes it; see below)
3. render + validate     -> prepare --proposals   -> review.json
4. human edit/approve    -> review-ui             (http://127.0.0.1:8765/)
5. batch send            -> batch (dry-run), then batch --execute --expect-batch-sha
```

Run all commands from this directory with `uv run python main.py ...`
(set `PYTHONIOENCODING=utf-8` when piping output).

1. **Paste.** Save the copied Google Sheet rows to a text file. The header row is
   optional: headerless rows are read in the sheet's column order (`申請單號`,
   `院內病歷號碼`, `攝影名稱`, `攝影日期`, `報告日期`, `覆審醫師`, `報告內容`,
   `病理報告`, `臨床診斷`, `癌別`, `完成`, `備註`).
   `import-tsv --input FILE --output cases.json` keeps only `待修正` rows.
2. **LLM proposal.** Claude reads `cases.json` and writes `proposals.json`. Use
   `catalog-options --cancer ID` to get the website's exact choices.
3. **Prepare.** `prepare --input cases.json --proposals proposals.json`. If
   `review.json` holds edits, approvals, or send results, `prepare` refuses to
   overwrite it. Add `--archive-existing` to move it to `archive/` first; this is
   how finished batches are cleared from the webpage.
4. **Review.** The user edits and approves in the webpage (one click per case).
   A study that cannot be staged, such as an unsupported cancer type, gets
   **N/A** instead. It is never sent and is pasted back as 其他癌 / 已備註.
   The running UI rereads `review.json` on every request, so a refresh shows a
   newly prepared batch. Restart the UI only after Python code changes.
5. **Send.** Run `batch`, the dry-run. Report the per-case result, then run
   `batch --execute --expect-batch-sha SHA` with the SHA that `show-review`
   printed.
   - Only approved cases that have not been sent yet are included.
   - Sent cases are skipped, so their execution record, which the paste-back
     relies on, is never overwritten.
   - Pending and skipped cases stay in `review.json` for a later batch.
   - **Re-send guards, all without posting:**
     - An accession recorded in `sent_ledger.jsonl` is skipped. The ledger is
       append-only and gitignored, and survives archiving `review.json`.
     - A RIS report that already contains the exact approved staging text is
       skipped and marked sent.
     - A RIS report with any other cancer-staging block is refused.
     - The existing checks still apply: RIS must match the imported report, and
       the server refuses a different block that is already present.
6. **Paste back.** In the webpage, open **Sheet paste-back**. Set 完成 or 癌別
   for any unsent rows that need it (e.g. 已備註), then copy the two columns.
   Paste them at the 癌別 cell of the row the page names, keeping the same sheet
   filter and sort as when copying.
   - Exactly the ticked rows are copied, one line each; an unticked row adds no
     line.
   - The default ticks cover the first to the last finished row. A ticked row
     that is not finished becomes a blank line (the reviewer's preference).
   - Drag across rows to invert their ticks.

## proposals.json contract

```json
{
  "generated_by": "Claude Code (model id)",
  "generated_at": "YYYY-MM-DD",
  "cases": {
    "<accession>": {
      "cancer": "<catalog id, e.g. Prostate>",
      "T": "T2a", "N": "N0", "M": "M0",
      "modality": "MRI with contrast",
      "T_RL": "Right",
      "T_location": "Left lobe",
      "N_location": ["Obturator"],
      "N_location_R": ["I", "II"], "N_location_L": [],
      "M_location": ["bone"],
      "liver": ["Cirrhosis"], "characters": ["..."], "number": "1",
      "stage": "IIA",
      "evidence": {"T": "quoted finding", "N": "...", "M": "..."},
      "assumptions": ["..."],
      "warnings": ["..."]
    },
    "<accession>": {"skip": "reason no staging is proposed"}
  }
}
```

- Cover every imported accession exactly once. Use `{"skip": reason}` when the
  site has no template (for example, salivary gland or NET) or staging is not
  assessable.
- Every value must be a website option. `prepare` rejects anything else:
  - `modality` defaults from the study name (`有造影劑` means with contrast,
    `無造影劑` without).
  - `T_RL` and `N_location_R`/`L` apply only when the catalog's `T_RL`/`N_RL` is
    true.
  - `M_location` is only allowed when M is not M0.
  - `liver`, `characters`, and `number` are HCC only, and HCC `T_location` is a
    list.
- Never choose the stage. It comes from the catalog lookup. Set `stage` only when
  the catalog maps the TNM to more than one stage; `prepare` then requires one of
  those candidates and adds a visible conflict warning.
- Quote report or pathology text in `evidence`. Anything not stated goes in
  `assumptions`: for example, N0/M0 because nothing is described. Put
  discrepancies in `warnings`, such as imaging vs explicit pathology staging, a
  primary-site mismatch, or missing pathology.
- **Best estimate, not `Tx`.** This is the reviewer's preference (2026-10-08).
  A doctor reviews every proposal before approval, so a reasonable category is
  better than "cannot be assessed". `local_llm.SYSTEM_PROMPT` holds the same
  rules for the local model; keep the two in step.
  - **Tumor seen, depth not given** (wall thickening, a mass, a polypoid
    lesion). With no sign of spread outside the organ, use the category for a
    tumor confined to the wall or organ: `T1/2` where the template has it
    (Colorectum, Esophagus); otherwise `T2` for clear wall thickening or a mass
    and `T1` for a subtle change; the general `T1` when the subcategories need
    detail that is not given. Fat stranding or infiltration around the tumor
    means the category for spread just outside the wall. Invasion of a
    neighbouring organ means that category.
  - **Size-based category, no size given.** Estimate from the wording (a nodule
    is at most 3 cm, a mass is more than 3 cm), the tumor count and the invasion.
  - **Primary not visible on this study** (not described, already removed, or
    outside the scan). Use the pT from pathology when it is stated, mapped to
    the nearest template code. Without a pT, use the category for a tumor found
    only by biopsy (Prostate `T1c`), or else the lowest T category above `T0`.
    Use `T0` when the primary was never found and only a metastasis is proven.
  - **`Tx` is the last resort.** Use it only when none of these gives an
    estimate, and put the reason in `warnings`.
  - **N.** Not described, "no definite lymphadenopathy", or small/equivocal
    nodes are `N0`. Regional lymphadenopathy with no count is the lowest
    node-positive category.
  - **M.** `M0` unless distant metastasis is described or favored.
- **Template from pathology.** When pathology states a definite cancer, use
  that cancer's template, even if the imaging never mentions the primary tumor.
  Do not skip such a study: T follows the "primary not visible" rule above, N
  and M come from the imaging, and the missing primary goes in `warnings`. The
  rule-based chooser (`classify.py`) follows the same order:
  1. pathology with a definite cancer
  2. the committee note
  3. the clinical diagnosis
  4. the report text, only when pathology states no definite cancer
- **Stage from imaging.** This is the reviewer's preference. T/N/M come from what
  this study's images show. Use pathology only to confirm the cancer type and
  primary site. When pathology gives an explicit pTNM that differs, keep the
  imaging values and put the pTNM (and its website stage) in `warnings`. If the
  study does not show the primary, T comes from the pT (see "Best estimate").
- **Study Date stays blank.** This is also the reviewer's preference, so
  `prepare` does not fill the website's optional date.
- The renderer is a port of the site's `generateReport()`, so "Other Findings" is
  always `N/A`. The reviewer edits the text in the webpage if needed.

`proposals.json`, `cases.json`, `review.json`, and `archive/` contain report
excerpts and are gitignored.

## AJCC corrections to the website catalog

The website is not ours to edit, and some of its templates differ from AJCC
(review of 2026-10-08; the list for the site owner is
`logs/tnm_template_review.html`). `catalog_corrections.py` holds our fixes.

- `catalog_cache.json` stays an exact copy of the website. `load_catalog()`
  returns the corrected catalog; `load_catalog(corrected=False)` returns the
  website's data. So the staging text can now differ from the website's text.
- **Stage tables** corrected: Lung (Version 9: IA1/IA2/IA3, T1 N1 = IIA), GIST,
  Prostate, Endometrium, Ovary, Cervix (T1a N2), OGS.
- **Definitions** corrected: Oropharynx p16+ N (Version 9, extranodal
  extension), oral cavity T3/T4a, lung T2a/N2, and small text errors
  ("distal" metastasis, `<` for `≤`).
- **Node lists** corrected: Prostate, Ovary, Endometrium, Stomach,
  Intrahepatic bile duct. Urinary bladder has no general `T4` any more.
- **Stage needs a factor the form does not have.** GIST (site, mitotic rate),
  Prostate (PSA, Grade Group), Esophagus (histology), OGS (grade) and
  Colorectum `T1/2N2a` map one TNM to more than one stage on purpose. The
  template's `Staging_note` gives the rule. The proposal sets `stage`, the
  review page shows a stage picker, and a warning shows the rule. The first
  matching row is the default.
- `Review_note` is a warning on every proposal of a template (Oropharynx p16+:
  Version 9 applies to a diagnosis from 2026-01-01; OGS spine and pelvis: AJCC
  has no stage groups, so the stage is `N/A`).
- **After `sync-catalog`:** the output lists `corrections_to_review`, the
  corrected templates that the website changed. Review their corrections, then
  update `REVIEWED`. `tests/test_catalog_corrections.py` fails until then.

## Local LLM trial (overnight on gpu-host.example.invalid, never sent to RIS)

This tests whether a local model on gpu-host.example.invalid can do the LLM step.

```powershell
uv run python main.py trial-schedule --models KEY1,KEY2 --at 00:05 --deadline 02:45
uv run python main.py trial-report          # next morning: pull the latest run, open the page
```

- **`trial-schedule`** copies the pipeline modules, `catalog_cache.json` and
  `cases.json` to `gpu-host.example.invalid:/opt/cancer_staging_trial/code` (mode 700),
  then queues `run_trial.sh` with `at`. Model keys live in `llm_trial.MODELS`.
- **`run_trial.sh`** takes the GPU scheduler's exclusive `local-llm` lease. That
  drains gemma-llm, paddleocr and trocr and restores them afterwards; lungcad
  waits. It runs `llm_trial.py` with gemma-llm's venv and `HF_HUB_OFFLINE=1`, so
  download weights beforehand.
- **Time window:** lungcad has had no night GPU activity (20:37–08:31), CheXagent
  runs at 03:00 daily, and the Notion flow runs Friday 01:00. So start after
  midnight, keep the deadline at or before 02:45, and don't queue a run for
  Friday morning.
- **Backends.** Most models run as GGUF files through a private `llama-server`
  (llama.cpp built with CUDA in `/opt/llama.cpp`, files in
  `/opt/gguf`, fetched by `gguf/download.sh` into `<file>.done`
  markers). `--fit` places layers and MoE experts automatically between the
  12 GB GPU and system RAM, with explicit offload fallbacks. `--reasoning-budget`
  caps thinking so the JSON always fits. MoE models must use llama.cpp:
  bitsandbytes cannot quantize fused expert tensors. `transformers` is kept
  for the MedGemma 4B baseline.
- **Model order** (`llm_trial.DEFAULT_ORDER`, chosen by a 2026-09-29 web
  review): Qwen3.6-35B-A3B, Gemma 4 26B-A4B (QAT), Qwen3.8-27B, Gemma 4 12B
  (QAT), HuatuoGPT-3-9B, MedGemma 4B. Each has a time cap (`minutes`) and a
  per-request cap (`case_seconds`).
- **`llm_trial.py`** loads each model once. Every study is its own fresh request
  (`local_llm.py`): the rules, then the study, then that cancer's template, then
  the output format. The template is chosen by rules, not by the model. Output
  is normalised, validated with `prepare_case_from_proposal`, and retried once
  with the validator's error. An output that is still invalid becomes a visible
  skip.
- **Results** are written after every study to `runs/<id>/<model>/`
  (`proposals.json`, `log.json`, `review.json`), plus `run.json` for the run.
  Tracebacks go to `stderr.log`, because the scheduler reruns a job whose stdout
  mentions OOM. On a rerun, models that already finished are kept.
- **`trial-report`** writes `trials/<id>/comparison.html`, a read-only page. The
  reference for each study is the live `review.json` at report time: the
  approved text where approved, otherwise the saved proposal.
- **Trial reviews are marked `"trial"`, and `batch.py` refuses them.**
