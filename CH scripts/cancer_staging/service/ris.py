"""Read-only RIS access through WebRIS (GET requests only), with the default saved login.

The worklist shows only the logged-in doctor's studies unless `checkdruserid` is empty,
so every search here sends it empty. A study is opened only when it is already reported.
"""

from __future__ import annotations

import re
from datetime import date
from typing import Any

from api_client import WebRISApi
from batch import STAGING_BLOCK, _normalized_report

REPORTED = "已發送"
TUMOR_TYPE = re.compile(r"Tumor Stage:[ \t]*(.+)")
STAGE_LINE = re.compile(r"^(.*\(Staging:.*\))[ \t]*$", re.M)


def fetch_report(api: WebRISApi, accession: str, chart_no: str) -> dict[str, Any]:
    """Current RIS state of one study; `error` is set when it cannot be used."""
    out: dict[str, Any] = {"accession": str(accession)}
    response = api.session.get(f"{api.base_url}/api/worklist", timeout=120, params={
        "preset": "ALL", "referno": accession, "status": "", "checkdruserid": "",
        "checktimestart": "2000/01/01", "checktimeend": date.today().strftime("%Y/%m/%d")})
    matches = [item for item in api._json(response).get("studies", []) if str(item.get("acc_no")) == str(accession)]
    if len(matches) != 1:
        return {**out, "error": f"RIS worklist matches: {len(matches)}"}
    study = matches[0]
    out.update({key: study.get(key) for key in ("study_date", "study_name", "status", "report_dr")})
    if str(study.get("chart_no", "")).lstrip("0") != str(chart_no).lstrip("0"):
        return {**out, "error": "RIS chart number differs from the sheet"}
    if study.get("status") != REPORTED:
        return {**out, "not_reported": True}
    context = api.status()["list_context_id"]
    detail = api._json(api.session.get(
        f"{api.base_url}/api/study/{int(study['index'])}", timeout=90,
        params={"list_context_id": context, "acc_no": accession}))
    info = detail.get("info") or {}
    if str(info.get("referno")) != str(accession):
        return {**out, "error": "RIS opened a different study"}
    if info.get("pageid") != "MJB3N002":
        return {**out, "error": f"RIS page is {info.get('pageid')!r}, not MJB3N002"}
    exam = info.get("exam") or ""
    normalized = _normalized_report(exam)
    blocks = len(STAGING_BLOCK.findall(normalized))
    out.update({"exam": exam, "staging_blocks": blocks})
    if blocks:
        tumor = TUMOR_TYPE.findall(normalized)
        stage = STAGE_LINE.findall(normalized)
        out.update({"tumor_type": tumor[-1].strip() if tumor else "", "stage_line": stage[-1].strip() if stage else ""})
    return out


def ris_date(value: str) -> str:
    """'2026/09/14 16:19:39' -> '2026/09/14'."""
    return str(value or "").split(" ")[0]
