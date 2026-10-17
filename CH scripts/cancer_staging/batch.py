"""Preview or execute approved cancer-staging cases through WebRIS."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from api_client import WebRISApi
from tnm_catalog import text_sha256
from workflow import batch_sha256, sendable_cases


# Append-only record of every confirmed send, kept across batches and archived
# reviews, so an accession is never staged in RIS twice by this pipeline.
DEFAULT_LEDGER = Path(__file__).with_name("sent_ledger.jsonl")
# Final lines of any cancer-tnm block: "... Cancer Staging:" then "TNM (Staging: X)".
STAGING_BLOCK = re.compile(r"Cancer Staging:[ \t]*\n[^\n]*\(Staging:", re.I)


def _normalized_report(text: str) -> str:
    """Normalize transport-only differences, not report wording."""
    return (text or "").replace("\r\n", "\n").replace("\r", "\n").rstrip()


def load_sent_ledger(path: Path) -> dict[str, dict[str, Any]]:
    """Latest ledger entry per accession."""
    entries: dict[str, dict[str, Any]] = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                entry = json.loads(line)
                entries[str(entry["accession"])] = entry
    return entries


def record_sent(path: Path, case: dict[str, Any], result: dict[str, Any]) -> None:
    entry = {
        "accession": case["source"]["accession"],
        "chart_no": case["source"]["chart_no"],
        "approved_text_sha256": case["approval"].get("approved_text_sha256", ""),
        "new_exam_sha256": (result.get("response") or {}).get("new_exam_sha256", ""),
        "at": result.get("at", ""),
        "how": result.get("status", ""),
    }
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def run_batch(
    review: dict[str, Any],
    *,
    api_url: str,
    execute: bool = False,
    expected_batch_sha256: str = "",
    userid: str | None = None,
    password: str | None = None,
    update_sheet: bool = False,
    ledger_path: Path | None = None,
) -> list[dict[str, Any]]:
    if review.get("trial"):
        raise ValueError("This is a local-LLM trial review; trial outputs are never sent to RIS")
    if update_sheet and not execute:
        raise ValueError("Sheet updates are allowed only with --execute")
    # Already-sent cases are skipped so their execution record (the proof of
    # sending, used for the sheet paste-back) is never overwritten.
    cases = sendable_cases(review)
    manifest_sha = batch_sha256(review)
    if execute and expected_batch_sha256 != manifest_sha:
        raise ValueError(
            f"Batch SHA mismatch: expected {expected_batch_sha256}, current {manifest_sha}"
        )
    if not cases:
        raise ValueError("No approved, unsent cases with intact text hashes")

    ledger = load_sent_ledger(ledger_path) if ledger_path else {}
    api = WebRISApi(api_url)
    results: list[dict[str, Any]] = []
    api.login(userid, password)
    try:
        for case in cases:
            source = case["source"]
            proposal = case["proposal"]
            result: dict[str, Any] = {
                "accession": source["accession"],
                "mode": "execute" if execute else "preview",
                "at": datetime.now(timezone.utc).isoformat(),
            }
            previous = ledger.get(str(source["accession"]))
            if previous:
                # Sent in an earlier batch that this review does not know about.
                result.update(
                    {
                        "status": "skipped",
                        "reason": f"Already sent on {previous.get('at', '?')} (sent ledger); not re-sending",
                    }
                )
                results.append(result)
                continue
            try:
                located = api.locate_study(
                    accession=source["accession"],
                    chart_no=source["chart_no"],
                    study_date=source["study_date"],
                )
                study = located["study"]
                detail = api.get_study(int(study["index"]))
                info = detail.get("info") or {}
                if str(info.get("referno") or "") != str(source["accession"]):
                    raise ValueError("Selected RIS study accession changed")
                if str(info.get("patno") or "").lstrip("0") != str(
                    source["chart_no"]
                ).lstrip("0"):
                    raise ValueError("Selected RIS study chart number changed")
                if info.get("pageid") != "MJB3N002":
                    raise ValueError(
                        f"Expected reported-study page MJB3N002; got {info.get('pageid')!r}"
                    )
                current_exam = info.get("exam") or ""
                exam = _normalized_report(current_exam)
                block = _normalized_report(proposal["staging_text"]).strip()
                if block and block in exam:
                    # This exact staging text is already in RIS: never post it again.
                    result.update(
                        {
                            "status": "skipped",
                            "reason": "RIS report already contains this staging text; not re-sending",
                        }
                    )
                    if execute:
                        result["response"] = {"submitted": False, "already_applied": True}
                        case["execution"] = result
                        if ledger_path:
                            record_sent(ledger_path, case, result)
                    results.append(result)
                    continue
                if STAGING_BLOCK.search(exam):
                    raise ValueError(
                        "RIS report already has a cancer-staging block; refusing to add another"
                    )
                if exam != _normalized_report(
                    source["report_txt"]
                ):
                    raise ValueError(
                        "Current RIS report differs substantively from the imported source report"
                    )
                response = api.cancer_staging_recheck(
                    index=int(study["index"]),
                    accession=source["accession"],
                    chart_no=source["chart_no"],
                    list_context_id=int(located["list_context_id"]),
                    staging_text=proposal["staging_text"],
                    approved_text_sha256=case["approval"]["approved_text_sha256"],
                    expected_exam_sha256=text_sha256(current_exam),
                    dry_run=not execute,
                    allow_url_index_fallback=True,
                )
                result.update({"status": "ok", "response": response})
                if execute and ledger_path and (
                    response.get("submitted") or response.get("already_applied")
                ):
                    record_sent(ledger_path, case, result)
                if execute and update_sheet:
                    try:
                        import sheet_client

                        result["sheet"] = sheet_client.write_study_result(
                            accession=source["accession"],
                            chart_no=source["chart_no"],
                            cancer_type=proposal["catalog_id"],
                        )
                    except Exception as sheet_exc:
                        # The RIS operation already succeeded. Mark this as partial
                        # so an operator fixes only the Sheet and never retries the
                        # potentially non-idempotent upstream submission blindly.
                        result["status"] = "partial"
                        result["sheet_error"] = str(sheet_exc)
                case["execution"] = result
            except Exception as exc:
                result.update({"status": "error", "error": str(exc)})
                case["execution"] = result
            results.append(result)
    finally:
        api.logout()
    return results
