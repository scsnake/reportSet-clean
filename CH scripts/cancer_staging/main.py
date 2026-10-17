"""CLI bridge between the Google Sheet and the AHK helper.

Subcommands:
    fetch-todo       write queue.json for the AHK helper to consume
    write-back       PATCH a single row (called by the AHK helper via shell-out)
    dump-classify    debug: list all todo rows with 癌別 guesses
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

# Ensure sibling modules import cleanly when invoked via `uv run python main.py …`
sys.path.insert(0, str(Path(__file__).parent))

import catalog_corrections  # noqa: E402
import classify as classify_mod  # noqa: E402
import sheet_client  # noqa: E402
import workflow  # noqa: E402
from batch import DEFAULT_LEDGER, run_batch  # noqa: E402
from canary import run_canary  # noqa: E402
from review_ui import run_review_ui  # noqa: E402
from tnm_catalog import (  # noqa: E402
    HCC_CHARACTERISTICS,
    HCC_LIVER_FEATURES,
    SITE_MODALITIES,
    SITE_SIDES,
    load_catalog,
)


def _load_env() -> None:
    load_dotenv(Path(__file__).parent / ".env")


def _queue_path() -> Path:
    _load_env()
    raw = os.environ.get("QUEUE_PATH", "queue.json")
    p = Path(raw)
    if not p.is_absolute():
        p = Path(__file__).parent / p
    return p


def _local_path(raw: str) -> Path:
    path = Path(raw)
    return path if path.is_absolute() else Path(__file__).parent / path


def cmd_fetch_todo(args: argparse.Namespace) -> int:
    rows = sheet_client.list_todo(args.doctor)
    payload = []
    for row in rows:
        g = classify_mod.classify(row)
        payload.append({**row, **g.to_dict()})
    out_path = _queue_path()
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(payload)} row(s) to {out_path}")
    return 0


def cmd_write_back(args: argparse.Namespace) -> int:
    result = sheet_client.write_row(
        row_idx=args.row,
        cancer_type=args.cancer_type,
        status=args.status,
        notes=args.notes,
        force=args.force,
    )
    print(json.dumps(result, ensure_ascii=False))
    return 0


def cmd_dump_classify(args: argparse.Namespace) -> int:
    from rich.console import Console
    from rich.table import Table

    rows = sheet_client.list_todo(args.doctor)
    table = Table(show_lines=True)
    table.add_column("row")
    table.add_column("chart_no")
    table.add_column("guess")
    table.add_column("matched_col")
    table.add_column("snippet")
    for row in rows:
        g = classify_mod.classify(row)
        table.add_row(
            str(row["row_idx"]),
            row.get("chart_no", ""),
            g.cancer_type or "—",
            g.matched_column or "—",
            g.matched_snippet or "—",
        )
    Console().print(table)
    return 0


def cmd_import_tsv(args: argparse.Namespace) -> int:
    all_rows: list[dict[str, Any]] = []
    rows = workflow.import_tsv_file(
        _local_path(args.input),
        only_status=None if args.include_all_status else args.status,
        doctor=args.doctor,
        all_rows=all_rows,
    )
    output = _local_path(args.output)
    workflow.save_json(output, rows)
    # Every pasted row, so the paste-back block matches the copied block 1:1.
    workflow.save_json(workflow.source_rows_sidecar(output), workflow.minimal_source_rows(all_rows))
    print(f"Imported {len(rows)} of {len(all_rows)} row(s) to {output}")
    return 0


def cmd_sync_catalog(args: argparse.Namespace) -> int:
    catalog = load_catalog(refresh=True)
    conflicts = {
        cancer_id: catalog.conflicts(cancer_id)
        for cancer_id in catalog.documents
        if catalog.conflicts(cancer_id)
    }
    print(
        json.dumps(
            {
                "documents": len(catalog.documents),
                "fetched_at": catalog.fetched_at,
                "sha256": catalog.sha256,
                "conflicts": conflicts,
                # Corrected templates that the website changed: review catalog_corrections.py.
                "corrections_to_review": catalog_corrections.stale(catalog.snapshot),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


def cmd_catalog_options(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    ids = args.cancer or sorted(catalog.documents)
    payload: dict[str, Any] = {
        "modality": list(SITE_MODALITIES),
        "sides": list(SITE_SIDES),
        "hcc_liver": list(HCC_LIVER_FEATURES),
        "hcc_characters": list(HCC_CHARACTERISTICS),
        "cancers": {},
    }
    for cancer_id in ids:
        cancer = catalog.documents[cancer_id]
        payload["cancers"][cancer_id] = {
            "name": cancer.get("name", cancer_id),
            **{key: cancer.get(key) for key in ("T", "N", "M")},
            **{
                key: cancer.get(key)
                for key in ("T_RL", "N_RL", "T_location", "N_location", "M_location")
            },
            "staging": {row["stage"]: row["TNM"] for row in cancer.get("Staging", [])},
            "conflicts": catalog.conflicts(cancer_id),
        }
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


TRIAL_HOST = os.environ.get("TRIAL_HOST", "gpu-host.example.invalid")
TRIAL_BASE = "/opt/cancer_staging_trial"
TRIAL_FILES = (
    "workflow.py",
    "classify.py",
    "tnm_catalog.py",
    "catalog_corrections.py",
    "local_llm.py",
    "llm_trial.py",
    "run_trial.sh",
    "catalog_cache.json",
)


def _ssh(command: str) -> str:
    result = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", TRIAL_HOST, command],
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        raise RuntimeError(f"ssh {TRIAL_HOST} failed: {result.stderr.strip()}")
    return result.stdout


def cmd_trial_schedule(args: argparse.Namespace) -> int:
    from llm_trial import DEFAULT_ORDER, MODELS

    models = [key.strip() for key in (args.models or DEFAULT_ORDER).split(",") if key.strip()]
    unknown = [key for key in models if key not in MODELS]
    if unknown:
        print(f"Unknown model key(s) {unknown}; choose from {list(MODELS)}", file=sys.stderr)
        return 2
    here = Path(__file__).parent
    code = f"{TRIAL_BASE}/code"
    _ssh(f"mkdir -p {code} {TRIAL_BASE}/runs && chmod 700 {TRIAL_BASE}")
    for local, remote in [(here / name, name) for name in TRIAL_FILES] + [
        (_local_path(args.cases), "cases.json")
    ]:
        subprocess.run(["scp", "-q", str(local), f"{TRIAL_HOST}:{code}/{remote}"], check=True)
    job = f"bash {code}/run_trial.sh {','.join(models)} {args.deadline}"
    print(_ssh(f"echo '{job}' | at {args.at} 2>&1").strip())
    print(f"Queued on {TRIAL_HOST}: {job}")
    return 0


def cmd_trial_report(args: argparse.Namespace) -> int:
    import webbrowser

    import trial_report

    # Scheduled runs are named YYYYMMDD_HHMM; smoke-test folders are ignored.
    run_id = args.run or _ssh(
        f"ls -1 {TRIAL_BASE}/runs | grep -E '^[0-9]{{8}}_[0-9]{{4}}$' | tail -1"
    ).strip()
    if not run_id:
        print("No trial runs found", file=sys.stderr)
        return 2
    trials = _local_path("trials")
    trials.mkdir(exist_ok=True)
    if not args.no_pull:
        subprocess.run(
            ["scp", "-q", "-r", f"{TRIAL_HOST}:{TRIAL_BASE}/runs/{run_id}", str(trials)],
            check=True,
        )
    run_dir = trials / run_id
    page = run_dir / "comparison.html"
    page.write_text(
        trial_report.build_html(run_dir, workflow.load_json(_local_path(args.review))),
        encoding="utf-8",
    )
    print(f"Wrote {page}")
    if not args.no_open:
        webbrowser.open(page.resolve().as_uri())
    return 0


def cmd_prepare(args: argparse.Namespace) -> int:
    rows = workflow.load_json(_local_path(args.input))
    catalog = load_catalog(refresh=args.refresh_catalog)
    proposals = workflow.load_json(_local_path(args.proposals)) if args.proposals else None
    review = workflow.prepare_review(rows, catalog, proposals)
    sidecar = workflow.source_rows_sidecar(_local_path(args.input))
    if sidecar.exists():
        review["source_rows"] = workflow.load_json(sidecar)
    output = _local_path(args.output)
    if output.exists() and workflow.review_has_work(workflow.load_json(output)):
        if not args.archive_existing:
            print(
                f"{output.name} holds edits, approvals, or send results. "
                "Re-run with --archive-existing to move it to archive/ first.",
                file=sys.stderr,
            )
            return 2
        archive = output.parent / "archive"
        archive.mkdir(exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        moved = archive / f"{output.stem}_{stamp}{output.suffix}"
        output.replace(moved)
        print(f"Archived previous review to {moved}")
    workflow.save_json(output, review)
    print(
        f"Prepared {len(review['cases'])} case(s) in {output}; "
        f"catalog={catalog.sha256[:12]}"
    )
    return 0


def cmd_show_review(args: argparse.Namespace) -> int:
    review = workflow.load_json(_local_path(args.review))
    cases = review.get("cases", [])
    if args.accession:
        cases = [workflow.find_case(review, args.accession)]
    for index, case in enumerate(cases, start=1):
        source = case["source"]
        proposal = case["proposal"]
        approval = case["approval"]
        print("=" * 78)
        print(
            f"[{index}/{len(cases)}] accession={source.get('accession')} "
            f"chart={source.get('chart_no')} state={approval.get('state')}"
        )
        print(
            f"cancer={proposal.get('catalog_id')}  "
            f"TNM={proposal.get('t')}{proposal.get('n')}{proposal.get('m')}  "
            f"stage={proposal.get('stage')}  sha={proposal.get('text_sha256')}"
        )
        if proposal.get("evidence"):
            print("Evidence:", json.dumps(proposal["evidence"], ensure_ascii=False))
        for assumption in proposal.get("assumptions", []):
            print(f"ASSUMPTION: {assumption}")
        for warning in proposal.get("warnings", []):
            print(f"WARNING: {warning}")
        print("-" * 78)
        print(proposal.get("staging_text") or "[no staging text generated]")
    print("=" * 78)
    print(f"Approved batch SHA: {workflow.batch_sha256(review)}")
    return 0


def cmd_set_tnm(args: argparse.Namespace) -> int:
    path = _local_path(args.review)
    review = workflow.load_json(path)
    catalog = load_catalog()
    case = workflow.set_case_tnm(
        review,
        catalog,
        args.accession,
        t=args.t,
        n=args.n,
        m=args.m,
    )
    workflow.save_json(path, review)
    print(
        json.dumps(
            {
                "accession": args.accession,
                "tnm": f"{args.t}{args.n}{args.m}",
                "stage": case["proposal"]["stage"],
                "text_sha256": case["proposal"]["text_sha256"],
                "approval": "invalidated",
            },
            ensure_ascii=False,
        )
    )
    return 0


def cmd_approve(args: argparse.Namespace) -> int:
    path = _local_path(args.review)
    review = workflow.load_json(path)
    case = workflow.approve_case(review, args.accession, args.expect_sha)
    workflow.save_json(path, review)
    print(
        json.dumps(
            {
                "accession": args.accession,
                "state": case["approval"]["state"],
                "approved_text_sha256": case["approval"]["approved_text_sha256"],
                "batch_sha256": workflow.batch_sha256(review),
            },
            ensure_ascii=False,
        )
    )
    return 0


def cmd_batch(args: argparse.Namespace) -> int:
    path = _local_path(args.review)
    review = workflow.load_json(path)
    results = run_batch(
        review,
        api_url=args.api_url,
        execute=args.execute,
        expected_batch_sha256=args.expect_batch_sha,
        userid=args.userid,
        password=args.password,
        update_sheet=args.update_sheet,
        ledger_path=None if args.no_ledger else DEFAULT_LEDGER,
    )
    workflow.save_json(path, review)
    output = _local_path(args.output)
    workflow.save_json(output, results)
    tsv_output = _local_path(args.results_tsv)
    with tsv_output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=(
                "accession",
                "mode",
                "status",
                "at",
                "submitted",
                "already_applied",
                "error",
                "sheet_status",
            ),
            delimiter="\t",
        )
        writer.writeheader()
        for item in results:
            response = item.get("response") or {}
            writer.writerow(
                {
                    "accession": item.get("accession", ""),
                    "mode": item.get("mode", ""),
                    "status": item.get("status", ""),
                    "at": item.get("at", ""),
                    "submitted": response.get("submitted", ""),
                    "already_applied": response.get("already_applied", ""),
                    "error": item.get("error") or item.get("sheet_error") or item.get("reason", ""),
                    "sheet_status": json.dumps(
                        item.get("sheet", {}), ensure_ascii=False
                    ),
                }
            )
    print(json.dumps(results, ensure_ascii=False, indent=2))
    print(f"Saved results to {output}")
    print(f"Saved paste-back TSV to {tsv_output}")
    return 1 if any(item["status"] not in ("ok", "skipped") for item in results) else 0


def cmd_canary(args: argparse.Namespace) -> int:
    report_path = _local_path(args.report_file)
    modified_report = report_path.read_text(encoding="utf-8-sig")
    result = run_canary(
        api_url=args.api_url,
        accession=args.accession,
        modified_report=modified_report,
        execute=args.execute,
        expected_staging_sha256=args.expect_staging_sha,
        expected_modified_sha256=args.expect_modified_sha,
        userid=args.userid,
        password=args.password,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def cmd_review_ui(args: argparse.Namespace) -> int:
    run_review_ui(
        _local_path(args.review),
        host=args.host,
        port=args.port,
        open_browser=not args.no_browser,
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="cancer_staging CLI bridge")
    sub = p.add_subparsers(dest="cmd", required=True)

    f = sub.add_parser("fetch-todo", help="write queue.json")
    f.add_argument("--doctor", default=None)
    f.set_defaults(func=cmd_fetch_todo)

    w = sub.add_parser("write-back", help="PATCH one row")
    w.add_argument("--row", type=int, required=True)
    w.add_argument("--cancer-type", default=None)
    w.add_argument("--status", default=None, choices=[None, "完成", "已備註"])
    w.add_argument("--notes", default=None)
    w.add_argument("--force", action="store_true")
    w.set_defaults(func=cmd_write_back)

    d = sub.add_parser("dump-classify", help="debug: list todos with guesses")
    d.add_argument("--doctor", default=None)
    d.set_defaults(func=cmd_dump_classify)

    i = sub.add_parser("import-tsv", help="import a pasted multiline TSV file")
    i.add_argument("--input", required=True)
    i.add_argument("--output", default="cases.json")
    i.add_argument("--status", default="待修正")
    i.add_argument("--include-all-status", action="store_true")
    i.add_argument("--doctor", default=None)
    i.set_defaults(func=cmd_import_tsv)

    c = sub.add_parser("sync-catalog", help="refresh TNM website catalog cache")
    c.set_defaults(func=cmd_sync_catalog)

    pr = sub.add_parser("prepare", help="generate review records and proposed text")
    pr.add_argument("--input", default="cases.json")
    pr.add_argument("--output", default="review.json")
    pr.add_argument("--refresh-catalog", action="store_true")
    pr.add_argument(
        "--proposals",
        default=None,
        help="LLM proposal JSON (see LLM_PROPOSALS.md); omit for the legacy heuristic",
    )
    pr.add_argument(
        "--archive-existing",
        action="store_true",
        help="move a review holding edits/approvals/results to archive/ first",
    )
    pr.set_defaults(func=cmd_prepare)

    co = sub.add_parser(
        "catalog-options", help="print website form choices for the LLM proposal step"
    )
    co.add_argument("--cancer", action="append", default=None)
    co.set_defaults(func=cmd_catalog_options)

    ts = sub.add_parser(
        "trial-schedule",
        help="copy code + cases to gpu-host.example.invalid and queue the overnight local-LLM trial with `at`",
    )
    ts.add_argument(
        "--models", default=None, help="comma-separated keys from llm_trial.MODELS (default: DEFAULT_ORDER)"
    )
    ts.add_argument("--cases", default="cases.json")
    ts.add_argument("--at", default="00:05", help="`at` time spec on gpu-host.example.invalid")
    ts.add_argument("--deadline", default="02:45", help="hard stop (HH:MM), before CheXagent at 03:00")
    ts.set_defaults(func=cmd_trial_schedule)

    tr = sub.add_parser(
        "trial-report", help="pull a trial run and open its read-only comparison page"
    )
    tr.add_argument("--run", default=None, help="run id (default: latest)")
    tr.add_argument("--review", default="review.json", help="reference: approved/saved texts")
    tr.add_argument("--no-pull", action="store_true")
    tr.add_argument("--no-open", action="store_true")
    tr.set_defaults(func=cmd_trial_report)

    sr = sub.add_parser("show-review", help="print proposed text for human review")
    sr.add_argument("--review", default="review.json")
    sr.add_argument("--accession", default=None)
    sr.set_defaults(func=cmd_show_review)

    st = sub.add_parser("set-tnm", help="change T/N/M and invalidate prior approval")
    st.add_argument("--review", default="review.json")
    st.add_argument("--accession", required=True)
    st.add_argument("--t", required=True)
    st.add_argument("--n", required=True)
    st.add_argument("--m", required=True)
    st.set_defaults(func=cmd_set_tnm)

    ap = sub.add_parser("approve", help="approve the exact staging text by SHA")
    ap.add_argument("--review", default="review.json")
    ap.add_argument("--accession", required=True)
    ap.add_argument("--expect-sha", required=True)
    ap.set_defaults(func=cmd_approve)

    b = sub.add_parser("batch", help="preview approved cases or explicitly execute")
    b.add_argument("--review", default="review.json")
    b.add_argument("--output", default="batch_results.json")
    b.add_argument("--results-tsv", default="batch_results.tsv")
    b.add_argument("--api-url", default=os.environ.get("WEBRIS_URL", "http://gpu-host.example.invalid:7200"))
    b.add_argument("--userid", default=None)
    b.add_argument("--password", default=None)
    b.add_argument("--execute", action="store_true")
    b.add_argument("--expect-batch-sha", default="")
    b.add_argument(
        "--update-sheet",
        action="store_true",
        help="after confirmed execute success, CAS matching Sheet row to 完成",
    )
    b.add_argument(
        "--no-ledger",
        action="store_true",
        help="do not consult or write sent_ledger.jsonl (the cross-batch re-send guard)",
    )
    b.set_defaults(func=cmd_batch)

    ca = sub.add_parser(
        "canary",
        help="preview/execute one accession from a complete modified report file",
    )
    ca.add_argument("--accession", required=True)
    ca.add_argument("--report-file", required=True)
    ca.add_argument("--api-url", default=os.environ.get("WEBRIS_URL", "http://gpu-host.example.invalid:7200"))
    ca.add_argument("--userid", default=None)
    ca.add_argument("--password", default=None)
    ca.add_argument("--execute", action="store_true")
    ca.add_argument("--expect-staging-sha", default="")
    ca.add_argument("--expect-modified-sha", default="")
    ca.set_defaults(func=cmd_canary)

    ui = sub.add_parser(
        "review-ui",
        help="open the local exact-text review and approval interface",
    )
    ui.add_argument("--review", default="review.json")
    ui.add_argument("--host", default="127.0.0.1")
    ui.add_argument("--port", type=int, default=8765)
    ui.add_argument("--no-browser", action="store_true")
    ui.set_defaults(func=cmd_review_ui)

    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
