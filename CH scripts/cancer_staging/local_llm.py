"""Local-LLM backend for the proposal step: one study per request.

Per study: pick the cancer template by rules, send one fresh request
(system rules -> this study's report/pathology -> this cancer's template ->
output format), parse the JSON, normalise it deterministically, and validate it
with the same code `prepare --proposals` uses. One repair retry feeds the
validator's error back. Nothing here talks to RIS.

`generate` is any callable taking chat messages and returning the model's text,
so this module has no GPU dependency and is testable with a fake model.
"""

from __future__ import annotations

import json
import re
import time
from typing import Any, Callable

import classify as classify_mod
import workflow
from tnm_catalog import HCC_CHARACTERISTICS, HCC_LIVER_FEATURES, SITE_SIDES, CancerCatalog

Messages = list[dict[str, str]]
Generate = Callable[[Messages], str]

SYSTEM_PROMPT = """\
You help a radiologist add cancer staging to an existing CT/MRI report for the \
hospital cancer registry. You will get one study and the TNM template for its \
cancer. Choose the template values that this imaging study supports.

Rules:
1. Stage from THIS imaging study's findings. Use pathology, diagnosis, and the \
cancer-committee note to confirm the cancer type and primary site. If \
pathology states a pTNM that differs from what the imaging shows, keep the \
imaging values and mention the pTNM in "warnings".
2. Give your best estimate. A radiologist reviews every proposal before it is \
used, so a reasonable category is better than "cannot be assessed". Avoid Tx. \
Every value that rests on something not stated goes in "assumptions".
T, when the report does not give the exact extent:
- The tumor is seen but its depth is not given (wall thickening, mucosal \
thickening, a mass, a polypoid lesion). With no sign of spread outside the \
organ, choose the category for a tumor confined to the wall or organ: T1/2 \
where the template has it; otherwise T2 for clear wall thickening or a mass \
and T1 for a subtle change; the general T1 when the subcategories need detail \
that is not given. With fat stranding or infiltration around the tumor, choose \
the category for spread just outside the wall. With invasion of a neighbouring \
organ, choose that category.
- A size-based category with no size given: estimate from the wording (a \
nodule is at most 3 cm, a mass is more than 3 cm) and from the tumor count and \
the invasion that are described.
- The primary tumor is not visible on this study (not described, already \
removed, or outside the scan): use the pT from pathology when it is stated, \
mapped to the nearest template code. Without a pT, use the category for a \
tumor found only by biopsy (T1c in prostate), or else the lowest T category \
above T0. Use T0 when the primary was never found and only a metastasis is \
proven.
- Use Tx only when none of these gives an estimate, and say why in "warnings".
N: if regional nodes are not described, or are "no definite lymphadenopathy" \
or small/equivocal, use N0. If the report describes regional lymphadenopathy \
or metastatic nodes without a count, use the lowest node-positive category.
M: use M0 unless distant metastasis is described or favored.
3. Apply size cutoffs exactly as written in the definitions (10 mm = 1 cm).
4. Use only codes and location names listed in the template, spelled exactly.
5. "evidence" holds short verbatim quotes from the report for T, N and M.
6. Do not output a stage group; it is computed from your T/N/M. Add "stage" \
only when the template has a "Stage group" rule for your T/N/M, or when a \
follow-up message asks you to choose between stage groups.
7. If this template does not fit the tumor (for example a different histology \
such as a neuroendocrine tumor or lymphoma, or a different primary site), \
return {"skip": "reason"} instead. Do not skip because the imaging does not \
mention the primary tumor: when pathology states a definite cancer of this \
template's site, stage it with T from rule 2 and take N and M from the imaging.
8. Answer in English with one JSON object and nothing else."""

LIST_FIELDS = ("N_location", "N_location_R", "N_location_L", "M_location", "liver", "characters")
OUTPUT_FIELDS = {
    "T", "N", "M", "T_RL", "T_location", "N_location", "N_location_R",
    "N_location_L", "M_location", "liver", "characters", "number", "stage",
    "evidence", "assumptions", "warnings", "skip",
}
THINK_BLOCK = re.compile(r"<think>.*?</think>", re.S | re.I)


def select_template(row: dict[str, Any], catalog: CancerCatalog) -> str:
    """Rule-based template choice: classifier plus the cancer-committee note."""
    guess = classify_mod.classify(
        {
            "report_txt": row.get("report_txt", ""),
            "patho_txt": row.get("patho_txt", ""),
            "dx_txt": row.get("dx_txt", ""),
            "notes_txt": " ".join(
                str(row.get(key, "")) for key in ("notes_txt", "notes2_txt", "notes3_txt")
            ),
        }
    )
    return workflow._catalog_id(row, guess.cancer_type, catalog)


def _options(title: str, options: dict[str, str]) -> str:
    lines = [f"{title} (choose one code):"]
    lines += [f"- {code}: {text}".replace("\n", " ") for code, text in options.items()]
    return "\n".join(lines)


def template_block(cancer: dict[str, Any]) -> str:
    is_hcc = cancer.get("id") == "HCC"
    parts = [
        f"Template: {cancer.get('name', cancer.get('id'))}",
        _options("T", cancer.get("T", {})),
        _options("N", cancer.get("N", {})),
        _options("M", cancer.get("M", {})),
    ]
    t_locations = cancer.get("T_location", [])
    if is_hcc:
        parts.append(f'T_location: list of liver segments involved, from {t_locations}')
        parts.append(f"liver: list of associated liver features present, from {list(HCC_LIVER_FEATURES)}")
        parts.append(f"characters: list of tumor characteristics present, from {list(HCC_CHARACTERISTICS)}")
        parts.append('number: tumor count as text: "1", "2", "3" or "multiple"')
    else:
        if t_locations:
            parts.append(f"T_location: one primary-tumor location, from {t_locations}")
        if cancer.get("T_RL"):
            parts.append(f"T_RL: side of the primary tumor, one of {list(SITE_SIDES)} (only if stated)")
        n_locations = cancer.get("N_location", [])
        if cancer.get("N_RL"):
            parts.append(
                f"N_location_R / N_location_L: lists of involved nodal levels on the "
                f"right / left, from {n_locations} (only abnormal nodes)"
            )
        elif n_locations:
            parts.append(f"N_location: list of involved nodal stations, from {n_locations} (only abnormal nodes)")
    m_locations = cancer.get("M_location", [])
    if m_locations:
        parts.append(f"M_location: list of metastatic sites, from {m_locations} (only when M is not M0)")
    if cancer.get("Staging_note"):
        parts.append(
            f"Stage group: {cancer['Staging_note']} If this rule covers your T/N/M, add "
            '"stage" with the group you choose, and put the factors you used in "assumptions".'
        )
    return "\n\n".join(parts)


def _study_block(row: dict[str, Any]) -> str:
    notes = " / ".join(
        str(row[key]) for key in ("notes_txt", "notes2_txt", "notes3_txt") if row.get(key)
    )
    return "\n\n".join(
        [
            f"Study: {row.get('study_name', '')}",
            "Radiology report:\n" + (row.get("report_txt") or "(none)").strip(),
            "Pathology:\n" + (row.get("patho_txt") or "(none)").replace(".H.", "\n").strip(),
            "Clinical diagnosis: " + (row.get("dx_txt") or "(none)").strip(),
            "Cancer-committee note: " + (notes or "(none)"),
        ]
    )


OUTPUT_FORMAT = """\
Return one JSON object with these keys (leave out location keys that do not apply):
{"T": "...", "N": "...", "M": "...", "T_location": ..., "M_location": [...],
 "evidence": {"T": "quote", "N": "quote", "M": "quote"},
 "assumptions": ["..."], "warnings": ["..."]}
or {"skip": "reason"} if this template does not fit the tumor."""


def build_messages(row: dict[str, Any], cancer: dict[str, Any], *, system_in_user: bool = False) -> Messages:
    user = "\n\n".join(
        ["## Study", _study_block(row), "## TNM template", template_block(cancer), "## Output", OUTPUT_FORMAT]
    )
    if system_in_user:
        return [{"role": "user", "content": SYSTEM_PROMPT + "\n\n" + user}]
    return [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": user}]


def visible_answer(text: str) -> str:
    """The reply without any reasoning block (used for parsing and retries)."""
    text = THINK_BLOCK.sub("", text or "")
    if "</think>" in text:  # opening tag was part of the prompt template
        text = text.rsplit("</think>", 1)[1]
    return text.strip()


def extract_json(text: str) -> dict[str, Any]:
    """Return the last top-level JSON object in the reply, ignoring reasoning."""
    text = visible_answer(text)
    decoder = json.JSONDecoder()
    found: dict[str, Any] | None = None
    position = text.find("{")
    while position != -1:
        try:
            value, end = decoder.raw_decode(text, position)
        except json.JSONDecodeError:
            position = text.find("{", position + 1)
            continue
        # Top-level objects only: a nested "evidence" dict also has a "T" key.
        if isinstance(value, dict) and ("T" in value or "skip" in value):
            found = value
        position = text.find("{", end)
    if found is None:
        raise ValueError("No JSON object with T/N/M or skip found in the reply")
    return found


def _match(value: Any, allowed: Any) -> Any:
    """Case/space-insensitive match onto an allowed spelling; unknown values pass through."""
    if not isinstance(value, str):
        return value
    wanted = re.sub(r"\s+", "", value).lower()
    for option in allowed:
        if re.sub(r"\s+", "", str(option)).lower() == wanted:
            return option
    return value


def normalize(entry: dict[str, Any], cancer: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    """Deterministic fix-ups that do not change meaning; each one is logged."""
    fixes: list[str] = []
    if entry.get("skip"):
        return {"skip": str(entry["skip"])}, fixes
    out: dict[str, Any] = {}
    for key, value in entry.items():
        if key not in OUTPUT_FIELDS or value in (None, "", []):
            if key not in OUTPUT_FIELDS:
                fixes.append(f"dropped unknown key {key!r}")
            continue
        out[key] = value
    for label in ("T", "N", "M"):
        if label in out:
            fixed = _match(out[label], cancer.get(label, {}))
            if fixed != out[label]:
                fixes.append(f"{label}: {out[label]!r} -> {fixed!r}")
                out[label] = fixed
    is_hcc = cancer.get("id") == "HCC"
    location_choices = {
        "T_location": cancer.get("T_location", []),
        "N_location": cancer.get("N_location", []),
        "N_location_R": cancer.get("N_location", []),
        "N_location_L": cancer.get("N_location", []),
        "M_location": cancer.get("M_location", []),
        "liver": HCC_LIVER_FEATURES,
        "characters": HCC_CHARACTERISTICS,
        "T_RL": SITE_SIDES,
    }
    for key in LIST_FIELDS + (("T_location",) if is_hcc else ()):
        if key in out and isinstance(out[key], str):
            out[key] = [part.strip() for part in out[key].split(",") if part.strip()]
            fixes.append(f"{key}: string -> list")
    if not is_hcc and isinstance(out.get("T_location"), list):
        out["T_location"] = out["T_location"][0] if out["T_location"] else ""
        fixes.append("T_location: list -> single value")
        if not out["T_location"]:
            del out["T_location"]
    for key, allowed in location_choices.items():
        if key in out:
            if isinstance(out[key], list):
                out[key] = [_match(item, allowed) for item in out[key]]
            else:
                out[key] = _match(out[key], allowed)
    if out.get("M") == "M0" and out.pop("M_location", None):
        fixes.append("M_location dropped because M0")
    if not cancer.get("T_RL") and out.pop("T_RL", None):
        fixes.append("T_RL dropped: template has no side")
    if cancer.get("N_RL") and not is_hcc and out.get("N_location"):
        out.pop("N_location")
        fixes.append("N_location dropped: template needs N_location_R/L")
    if not cancer.get("N_RL"):
        for key in ("N_location_R", "N_location_L"):
            if key in out:
                out.setdefault("N_location", []).extend(out.pop(key))
                fixes.append(f"{key} merged into N_location")
    if is_hcc:
        out.pop("N_location", None)
    if "number" in out:
        out["number"] = str(out["number"])
    evidence = out.get("evidence")
    if evidence is not None and not isinstance(evidence, dict):
        out["evidence"] = {"T": str(evidence)}
        fixes.append("evidence: coerced to dict")
    for key in ("assumptions", "warnings"):
        if key in out and isinstance(out[key], str):
            out[key] = [out[key]]
    return out, fixes


def propose_case(
    generate: Generate,
    row: dict[str, Any],
    catalog: CancerCatalog,
    *,
    model_label: str,
    system_in_user: bool = False,
    retries: int = 1,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Return (proposal entry, log) for one study; the entry always validates."""
    log: dict[str, Any] = {"accession": row["accession"], "attempts": []}
    cancer_id = select_template(row, catalog)
    log["template"] = cancer_id
    if not cancer_id:
        entry = {"skip": "No cancer-tnm template matched the pathology, diagnosis, or committee note."}
        log["status"] = "skip-no-template"
        return entry, log
    cancer = catalog.documents[cancer_id]
    messages = build_messages(row, cancer, system_in_user=system_in_user)
    error = ""
    for attempt in range(retries + 1):
        started = time.monotonic()
        reply = generate(messages)
        record: dict[str, Any] = {"seconds": round(time.monotonic() - started, 1), "reply": reply}
        log["attempts"].append(record)
        try:
            entry, fixes = normalize(extract_json(reply), cancer)
            record["fixes"] = fixes
            if not entry.get("skip"):
                entry["cancer"] = cancer_id
            entry.setdefault("warnings", [])
            entry["warnings"] = [f"Draft by {model_label} (local LLM trial)."] + list(entry["warnings"])
            if not entry.get("skip"):
                result = catalog.resolve_stage(
                    cancer_id, str(entry.get("T", "")), str(entry.get("N", "")), str(entry.get("M", ""))
                )
                candidates = list(dict.fromkeys(result.matching_stages))
                if not result.has_conflict and entry.pop("stage", None):
                    fixes.append("stage dropped: no catalog conflict to resolve")
                elif result.has_conflict and entry.get("stage") not in candidates:
                    if attempt < retries:
                        raise ValueError(
                            f"The template maps {result.tnm} to more than one stage group: "
                            f"{', '.join(candidates)}. Keep your answer and add \"stage\" set to "
                            "exactly one of them, based on the findings."
                            + (f" {cancer['Staging_note']}" if cancer.get("Staging_note") else "")
                        )
                    entry["stage"] = result.stage
                    entry["warnings"].append(
                        f"Catalog maps {result.tnm} to {', '.join(candidates)}; the model did not "
                        f"choose, so the default (first match) {result.stage} is used."
                    )
                    fixes.append("stage set to first match")
            workflow.prepare_case_from_proposal(row, entry, catalog)
            log["status"] = "skip-by-model" if entry.get("skip") else "ok"
            log["seconds"] = sum(item["seconds"] for item in log["attempts"])
            return entry, log
        except ValueError as exc:
            error = str(exc)
            record["error"] = error
            messages = messages + [
                {"role": "assistant", "content": visible_answer(reply)},
                {
                    "role": "user",
                    "content": f"That answer was rejected: {error}\n"
                    "Return one corrected JSON object only.",
                },
            ]
    log["status"] = "invalid"
    log["seconds"] = sum(item["seconds"] for item in log["attempts"])
    return {"skip": f"{model_label} output invalid after retry: {error}"}, log
