"""Read-only comparison page for a local-LLM trial run (never sends to RIS).

The reference per study comes from the live review.json at report time: the
approved text if approved, otherwise the saved (Claude or edited) proposal.
"""

from __future__ import annotations

import html
import json
import re
import statistics
from datetime import datetime
from pathlib import Path
from typing import Any

STAGE_LINE = re.compile(r"^(T\S*?)(N\S*?)(M\S*) \(Staging: ([^)]*)\)\s*$", re.M)
TUMOR_LINE = re.compile(r"^Tumor Stage: (.+?)\s*$", re.M)


def _parse_text(text: str) -> dict[str, str]:
    match = STAGE_LINE.search(text or "")
    if not match:
        return {}
    name = TUMOR_LINE.search(text)
    return {
        "cancer": name.group(1) if name else "",
        "t": match.group(1),
        "n": match.group(2),
        "m": match.group(3),
        "stage": match.group(4),
    }


def reference_for(case: dict[str, Any]) -> dict[str, Any]:
    proposal = case.get("proposal", {})
    text = proposal.get("staging_text", "")
    approved = case.get("approval", {}).get("state") == "approved"
    if not text:
        return {"source": "skipped (no text)", "skip": True}
    parsed = _parse_text(text) or {
        "t": proposal.get("t", ""),
        "n": proposal.get("n", ""),
        "m": proposal.get("m", ""),
        "stage": proposal.get("stage", ""),
    }
    parsed.setdefault("cancer", proposal.get("catalog_name", ""))
    if approved:
        source = "approved text"
    elif proposal.get("manually_edited"):
        source = "saved edit (not approved yet)"
    else:
        source = "Claude proposal (not approved yet)"
    return {"source": source, "skip": False, **parsed}


def _load(path: Path, default: Any) -> Any:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def load_run(run_dir: Path) -> dict[str, Any]:
    run = _load(run_dir / "run.json", {})
    models = []
    for summary in run.get("models", []):
        key = summary["model"]
        review = _load(run_dir / key / "review.json", {"cases": []})
        logs = {item["accession"]: item for item in _load(run_dir / key / "log.json", [])}
        cases = {case["source"]["accession"]: case for case in review.get("cases", [])}
        models.append({"summary": summary, "cases": cases, "logs": logs})
    return {"run": run, "models": models}


def _model_result(model: dict[str, Any], accession: str) -> dict[str, Any]:
    log = model["logs"].get(accession, {})
    case = model["cases"].get(accession)
    if not case:
        return {"status": log.get("status", "not run"), "skip": None, "log": log}
    proposal = case["proposal"]
    return {
        "status": log.get("status", ""),
        "skip": not proposal.get("staging_text"),
        "cancer": proposal.get("catalog_name", ""),
        "t": proposal.get("t", ""),
        "n": proposal.get("n", ""),
        "m": proposal.get("m", ""),
        "stage": proposal.get("stage", ""),
        "proposal": proposal,
        "log": log,
    }


def score(reference: dict[str, Any], result: dict[str, Any]) -> dict[str, bool | None]:
    if result.get("skip") is None:
        return {}
    marks: dict[str, bool | None] = {"decision": reference["skip"] == result["skip"]}
    for key in ("t", "n", "m", "stage"):
        marks[key] = (
            reference.get(key) == result.get(key)
            if not reference["skip"] and not result["skip"]
            else None
        )
    return marks


def summarize(model: dict[str, Any], references: dict[str, dict[str, Any]]) -> dict[str, Any]:
    counts: dict[str, int] = {}
    agree = {key: [0, 0] for key in ("decision", "t", "n", "m", "stage", "tnm")}
    seconds: list[float] = []
    retries = 0
    for accession, reference in references.items():
        result = _model_result(model, accession)
        counts[result["status"]] = counts.get(result["status"], 0) + 1
        marks = score(reference, result)
        for key, value in marks.items():
            if value is not None:
                agree[key][0] += int(value)
                agree[key][1] += 1
        if all(marks.get(key) for key in ("t", "n", "m")):
            agree["tnm"][0] += 1
        if marks.get("t") is not None:
            agree["tnm"][1] += 1
        log = result["log"]
        if log.get("seconds") is not None:
            seconds.append(float(log["seconds"]))
        retries += max(0, len(log.get("attempts", [])) - 1)
    return {
        "counts": counts,
        "agree": agree,
        "median_seconds": round(statistics.median(seconds), 1) if seconds else None,
        "retries": retries,
    }


CSS = """
:root { --bg:#f6f7f5; --card:#fff; --ink:#1d2621; --muted:#5d6b63; --line:#d9e0db;
  --good:#1f7a4d; --good-bg:#e3f3ea; --bad:#a3361f; --bad-bg:#fbe6e0; --warn-bg:#fff3d6; }
@media (prefers-color-scheme: dark) { :root { --bg:#141917; --card:#1d2421; --ink:#e7ece9;
  --muted:#9aa8a0; --line:#34403a; --good:#6fd39c; --good-bg:#1d3a2b; --bad:#f19a85;
  --bad-bg:#43241d; --warn-bg:#3d3420; } }
* { box-sizing: border-box; }
body { margin:0; padding:24px 16px 60px; background:var(--bg); color:var(--ink);
  font:14px/1.5 system-ui, "Segoe UI", "Microsoft JhengHei", sans-serif; }
main { max-width:1200px; margin:0 auto; }
h1 { margin:0 0 4px; font-size:24px; } h2 { margin:32px 0 10px; font-size:18px; }
.muted { color:var(--muted); } .banner { padding:10px 14px; border-radius:8px;
  background:var(--warn-bg); margin:12px 0 20px; font-weight:600; }
.scroll { overflow-x:auto; } table { border-collapse:collapse; width:100%; background:var(--card); }
th, td { border:1px solid var(--line); padding:6px 8px; text-align:left; vertical-align:top; }
th { font-size:12px; text-transform:uppercase; letter-spacing:.03em; color:var(--muted); }
.ok { background:var(--good-bg); color:var(--good); font-weight:600; }
.bad { background:var(--bad-bg); color:var(--bad); font-weight:600; }
.case { background:var(--card); border:1px solid var(--line); border-radius:10px;
  padding:14px 16px; margin:14px 0; }
.case h3 { margin:0 0 8px; font-size:16px; }
details { margin:6px 0; } summary { cursor:pointer; color:var(--muted); }
pre { white-space:pre-wrap; font:12px/1.45 ui-monospace, Consolas, monospace; margin:6px 0;
  padding:8px; background:var(--bg); border-radius:6px; }
ul { margin:4px 0 4px 18px; padding:0; }
"""


def _cell(value: Any, mark: bool | None = None) -> str:
    cls = "" if mark is None else (' class="ok"' if mark else ' class="bad"')
    return f"<td{cls}>{html.escape(str(value if value not in (None, '') else '—'))}</td>"


def _local(stamp: Any) -> str:
    """ISO timestamp (UTC or naive local) shown as local YYYY-MM-DD HH:MM."""
    if not stamp:
        return ""
    try:
        return datetime.fromisoformat(stamp).astimezone().strftime("%Y-%m-%d %H:%M")
    except ValueError:
        return html.escape(str(stamp))


def _mb_to_gb(value: Any) -> Any:
    return round(value / 1024, 1) if isinstance(value, (int, float)) else None


def _generation(log: dict[str, Any], index: int) -> str:
    stats = log.get("generation") or []
    if index >= len(stats):
        return ""
    item = stats[index]
    return html.escape(
        f" · {item.get('completion_tokens')} tokens at {item.get('tokens_per_second')} tok/s"
        f" · finish {item.get('finish_reason')}"
    )


def _list(items: Any) -> str:
    items = items.items() if isinstance(items, dict) else enumerate(items or [])
    rendered = [
        f"<li>{html.escape(f'{k}: {v}' if isinstance(k, str) else str(v))}</li>" for k, v in items
    ]
    return f"<ul>{''.join(rendered)}</ul>" if rendered else "<p class='muted'>none</p>"


def build_html(run_dir: Path, review: dict[str, Any]) -> str:
    data = load_run(run_dir)
    run = data["run"]
    references = {
        case["source"]["accession"]: reference_for(case) for case in review.get("cases", [])
    }
    references = {acc: ref for acc, ref in references.items() if acc in run.get("cases", references)}
    sources = {case["source"]["accession"]: case["source"] for case in review.get("cases", [])}

    parts = [
        "<!doctype html><html lang='en'><head><meta charset='utf-8'>",
        "<meta name='viewport' content='width=device-width, initial-scale=1'>",
        f"<title>LLM Trial {html.escape(run_dir.name)}</title><style>{CSS}</style></head><body><main>",
        f"<h1>Local LLM trial {html.escape(run_dir.name)}</h1>",
        f"<p class='muted'>Started {_local(run.get('started_at'))} · finished "
        f"{_local(run.get('finished_at')) or 'not finished'} · deadline {_local(run.get('deadline'))}</p>",
        "<div class='banner'>Review only. Trial outputs are not in review.json, and batch.py refuses to send them to RIS.</div>",
        "<h2>Models</h2><div class='scroll'><table><tr><th>Model</th><th>Quant</th><th>Status</th><th>Load s</th>"
        "<th>Peak VRAM GB</th><th>Results</th><th>Staged vs skipped</th><th>T</th><th>N</th><th>M</th>"
        "<th>T+N+M</th><th>Stage</th><th>Median s/study</th><th>Retries</th></tr>",
    ]
    for model in data["models"]:
        summary = model["summary"]
        stats = summarize(model, references)

        def frac(key: str) -> str:
            hit, total = stats["agree"][key]
            return f"{hit}/{total}" if total else "—"

        counts = ", ".join(f"{k} {v}" for k, v in sorted(stats["counts"].items()))
        parts.append(
            "<tr>"
            + _cell(summary["model"])
            + _cell(f"{summary.get('quant', '')} · {summary.get('backend', '')}")
            + _cell(summary.get("status", "") + (f" ({summary['error']})" if summary.get("error") else ""))
            + _cell(summary.get("load_seconds"))
            + _cell(summary.get("peak_vram_gb") or _mb_to_gb(summary.get("gpu_used_mb_after_load")))
            + _cell(counts)
            + "".join(_cell(frac(key)) for key in ("decision", "t", "n", "m", "tnm", "stage"))
            + _cell(stats["median_seconds"])
            + _cell(stats["retries"])
            + "</tr>"
        )
    parts.append(
        "</table></div><p class='muted'>Agreement is against the reference column below: your "
        "approved text where approved, otherwise the saved proposal. T/N/M/stage are compared only "
        "where both staged.</p>"
    )

    # Group studies by cancer type like the review UI: alphabetical, skipped last.
    ordered = sorted(references.items(), key=lambda item: (item[1]["skip"], item[1].get("cancer") or ""))
    group = None
    for accession, reference in ordered:
        label = "No staging template" if reference["skip"] else reference.get("cancer") or "Unknown"
        if label != group:
            group = label
            count = sum(
                1 for _, other in ordered
                if ("No staging template" if other["skip"] else other.get("cancer") or "Unknown") == group
            )
            parts.append(f"<h2>{html.escape(group)} · {count}</h2>")
        source = sources.get(accession, {})
        parts.append(
            f"<section class='case'><h3>{html.escape(accession)} · {html.escape(source.get('study_name', ''))}</h3>"
            f"<p class='muted'>Committee note: {html.escape(source.get('notes_txt', '') or '—')}</p>"
            "<details><summary>Report and pathology</summary>"
            f"<pre>{html.escape(source.get('report_txt', ''))}</pre>"
            f"<pre>{html.escape((source.get('patho_txt', '') or '').replace('.H.', chr(10)))}</pre></details>"
            "<div class='scroll'><table><tr><th>Source</th><th>Result</th><th>Template</th><th>T</th>"
            "<th>N</th><th>M</th><th>Stage</th><th>Seconds</th></tr>"
        )
        parts.append(
            "<tr>"
            + _cell(f"Reference: {reference['source']}")
            + _cell("skip" if reference["skip"] else "staged")
            + _cell(reference.get("cancer"))
            + "".join(_cell(reference.get(key)) for key in ("t", "n", "m", "stage"))
            + _cell("")
            + "</tr>"
        )
        details = []
        for model in data["models"]:
            result = _model_result(model, accession)
            marks = score(reference, result)
            outcome = "skip" if result.get("skip") else ("staged" if result.get("skip") is False else "")
            parts.append(
                "<tr>"
                + _cell(model["summary"]["model"])
                + _cell(f"{outcome} ({result['status']})", marks.get("decision"))
                + _cell(result.get("cancer"))
                + "".join(_cell(result.get(key), marks.get(key)) for key in ("t", "n", "m", "stage"))
                + _cell(result["log"].get("seconds"))
                + "</tr>"
            )
            proposal = result.get("proposal") or {}
            attempts = result["log"].get("attempts", [])
            details.append(
                f"<details><summary>{html.escape(model['summary']['model'])}: evidence, warnings, text, raw reply</summary>"
                f"<p><b>Evidence</b></p>{_list(proposal.get('evidence'))}"
                f"<p><b>Assumptions</b></p>{_list(proposal.get('assumptions'))}"
                f"<p><b>Warnings</b></p>{_list(proposal.get('warnings'))}"
                + (f"<p><b>Skip reason</b>: {html.escape(proposal['skip_reason'])}</p>" if proposal.get("skip_reason") else "")
                + f"<pre>{html.escape(proposal.get('staging_text', '') or '(no staging text)')}</pre>"
                + "".join(
                    f"<p class='muted'>Attempt {i + 1} · {attempt.get('seconds')} s"
                    + _generation(result["log"], i)
                    + (f" · rejected: {html.escape(attempt['error'])}" if attempt.get("error") else "")
                    + (f" · fixes: {html.escape('; '.join(attempt['fixes']))}" if attempt.get("fixes") else "")
                    + f"</p><pre>{html.escape(attempt.get('reply', ''))}</pre>"
                    for i, attempt in enumerate(attempts)
                )
                + "</details>"
            )
        parts.append("</table></div>" + "".join(details) + "</section>")
    parts.append("</main></body></html>")
    return "".join(parts)
