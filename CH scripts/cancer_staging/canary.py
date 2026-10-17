"""One-case dry-run/live canary from a complete user-approved report."""

from __future__ import annotations

import re
from typing import Any

from api_client import WebRISApi
from tnm_catalog import text_sha256


def _lf(text: str) -> str:
    return (text or "").replace("\r\n", "\n").replace("\r", "\n")


_NOTIFICATION_LINE = re.compile(
    r"(?m)^[ \t]*通報臨床醫師[^\r\n]*(?:\r\n|\r|\n|$)"
)
_NOTIFICATION_INLINE = re.compile(r"(?m)[ \t]*通報臨床醫師[^\r\n]*$")


def strip_clinician_notification_markers(text: str) -> tuple[str, int]:
    """Remove only explicit RIS clinician-notification marker text."""
    cleaned, line_count = _NOTIFICATION_LINE.subn("", text or "")
    cleaned, inline_count = _NOTIFICATION_INLINE.subn("", cleaned)
    return cleaned, line_count + inline_count


def derive_staging_append(current_report: str, modified_report: str) -> tuple[str, int]:
    """Extract appended block/newline count while protecting original text."""
    current_base = _lf(current_report).rstrip()
    modified_base = _lf(modified_report).rstrip()
    if not current_base:
        raise ValueError("Current RIS report is empty")
    if not modified_base.startswith(current_base):
        raise ValueError(
            "Modified report does not preserve the current RIS report as an exact prefix"
        )
    remainder = modified_base[len(current_base) :]
    if not remainder or not remainder.startswith("\n"):
        raise ValueError("Modified report has no appended staging block")
    append_newlines = len(remainder) - len(remainder.lstrip("\n"))
    if append_newlines < 1 or append_newlines > 4:
        raise ValueError("The staging block separator must contain 1 to 4 newlines")
    staging_text = remainder[append_newlines:].strip()
    if not staging_text:
        raise ValueError("Appended staging block is empty")
    canonical = current_base + ("\n" * append_newlines) + staging_text
    if canonical != modified_base:
        raise ValueError("Modified report contains unsupported separator whitespace")
    return staging_text, append_newlines


def derive_staging_block(current_report: str, modified_report: str) -> str:
    return derive_staging_append(current_report, modified_report)[0]


def run_canary(
    *,
    api_url: str,
    accession: str,
    modified_report: str,
    execute: bool = False,
    expected_staging_sha256: str = "",
    expected_modified_sha256: str = "",
    userid: str | None = None,
    password: str | None = None,
) -> dict[str, Any]:
    api = WebRISApi(api_url)
    api.login(userid, password)
    try:
        located = api.locate_accession(accession)
        study = located["study"]
        detail = api.get_study(int(study["index"]))
        info = detail.get("info") or {}
        if str(info.get("referno") or "") != str(accession):
            raise ValueError("Selected RIS study accession changed")
        if info.get("pageid") != "MJB3N002":
            raise ValueError(
                f"Expected reported-study page MJB3N002; got {info.get('pageid')!r}"
            )
        current_report = info.get("exam") or ""
        effective_current, current_marker_count = strip_clinician_notification_markers(
            current_report
        )
        effective_modified, supplied_marker_count = strip_clinician_notification_markers(
            modified_report
        )
        staging_text, append_newlines = derive_staging_append(
            effective_current, effective_modified
        )
        staging_sha = text_sha256(staging_text)
        modified_sha = text_sha256(modified_report)
        if execute and expected_staging_sha256 != staging_sha:
            raise ValueError(
                "Live canary SHA mismatch; rerun preview and confirm its staging SHA"
            )
        if execute and expected_modified_sha256 != modified_sha:
            raise ValueError(
                "Live canary modified-report SHA mismatch; the supplied file changed"
            )

        response = api.cancer_staging_recheck(
            index=int(study["index"]),
            accession=str(accession),
            chart_no=str(info.get("patno") or study.get("chart_no") or ""),
            list_context_id=int(located["list_context_id"]),
            staging_text=staging_text,
            approved_text_sha256=staging_sha,
            expected_exam_sha256=text_sha256(current_report),
            dry_run=not execute,
            append_newlines=append_newlines,
            allow_url_index_fallback=True,
        )
        return {
            "status": "ok",
            "mode": "execute" if execute else "preview",
            "accession": str(accession),
            "pageid": info.get("pageid"),
            "current_report_length": len(current_report),
            "modified_report_length": len(modified_report),
            "modified_report_sha256": modified_sha,
            "effective_modified_report_sha256": text_sha256(effective_modified),
            "current_notification_markers_to_remove": current_marker_count,
            "supplied_notification_markers_removed": supplied_marker_count,
            "staging_length": len(staging_text),
            "staging_sha256": staging_sha,
            "append_newlines": append_newlines,
            "response": response,
        }
    finally:
        api.logout()
