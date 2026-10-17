"""Import, prepare, edit, and approve cancer-staging review records."""

from __future__ import annotations

import csv
import io
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import classify as classify_mod
from tnm_catalog import (
    HCC_CHARACTERISTICS,
    HCC_LIVER_FEATURES,
    SITE_CANCER_MENU,
    SITE_MODALITIES,
    SITE_SIDES,
    CancerCatalog,
    render_site_report,
    render_staging_text,
    text_sha256,
)

SCHEMA_VERSION = 1

# Column order of the Google Sheet, used when rows are pasted without a header.
SHEET_COLUMNS = (
    "申請單號",
    "院內病歷號碼",
    "攝影名稱",
    "攝影日期",
    "報告日期",
    "覆審醫師",
    "報告內容",
    "病理報告",
    "臨床診斷",
    "癌別",
    "完成",
    "備註",
    "備註2",
    "備註3",
)
HEADERLESS_FIRST_CELL = re.compile(r"^\d{10,11}$")

# Dropdown choices of the sheet's 癌別 and 完成 columns (adjacent, 癌別 first),
# used for the two-column paste-back after sending.
SHEET_CANCER_TYPES = (
    "口腔癌", "口咽癌", "鼻咽癌", "下咽癌", "喉癌(Larynx)", "肺癌", "食道癌", "胃癌",
    "大腸直腸癌", "胃腸道基質細胞瘤(GIST)", "肝癌", "膽管癌", "胰臟癌", "腎臟癌",
    "膀胱癌", "攝護腺癌", "卵巢癌", "子宮頸癌", "子宮內膜癌", "子宮體癌", "骨肉瘤", "其他癌",
)
SHEET_STATUSES = ("完成", "待修正", "已備註", "轉移", "復發", "未作相關檢查", "無病理報告")
CATALOG_SHEET_CANCER = {
    "Lip_Oral_Cavity": "口腔癌",
    "Oropharynx_P16+": "口咽癌",
    "Oropharynx_P16-": "口咽癌",
    "NPC": "鼻咽癌",
    "Hypopharynx": "下咽癌",
    "Glottis": "喉癌(Larynx)",
    "Supraglottis": "喉癌(Larynx)",
    "Subglottis": "喉癌(Larynx)",
    "Lung": "肺癌",
    "Esophagus": "食道癌",
    "Stomach": "胃癌",
    "Colorectum": "大腸直腸癌",
    "GIST": "胃腸道基質細胞瘤(GIST)",
    "HCC": "肝癌",
    "Intrahepatic_bil_duct": "膽管癌",
    "Perihilar_bile_duct": "膽管癌",
    "Distal_bile_duct": "膽管癌",
    "Pancreas": "胰臟癌",
    "RCC": "腎臟癌",
    "Urinary_bladder": "膀胱癌",
    "Prostate": "攝護腺癌",
    "Ovary": "卵巢癌",
    "Cervix": "子宮頸癌",
    "Endometrium": "子宮內膜癌",
    "OGS_others": "骨肉瘤",
    "OGS_pelvis": "骨肉瘤",
    "OGS_spine": "骨肉瘤",
}
NOTE_CANCER_ALIASES = {"結腸癌": "大腸直腸癌", "直腸癌": "大腸直腸癌", "大腸癌": "大腸直腸癌", "喉癌": "喉癌(Larynx)"}

HEADER_ALIASES = {
    "accession": ("申請單號", "開單序號", "Accession", "Acc No"),
    "chart_no": ("院內病歷號碼", "病歷號", "Chart No", "ChartNo"),
    "study_name": ("攝影名稱", "檢查項目", "Study Name"),
    "study_date": ("攝影日期", "檢查日期", "Study Date"),
    "report_date": ("報告日期", "Report Date"),
    "review_doctor": ("覆審醫師", "報告醫師", "主治醫師", "Doctor", "醫師"),
    "report_txt": ("報告內容",),
    "patho_txt": ("病理報告",),
    "dx_txt": ("臨床診斷",),
    "cancer_type_existing": ("癌別", "Cancer", "Cancer Type"),
    "status": ("完成", "狀態", "Status"),
    "notes_txt": ("備註",),
    "notes2_txt": ("備註2",),
    "notes3_txt": ("備註3",),
}

CANCER_ID_MAP = {
    "Colorectal": "Colorectum",
    "Gastric": "Stomach",
    "Esophageal": "Esophagus",
    "Pancreatic": "Pancreas",
    "Nasopharyngeal": "NPC",
    "Oral cavity": "Lip_Oral_Cavity",
    "Hypopharyngeal": "Hypopharynx",
    "Prostate": "Prostate",
    "RCC": "RCC",
    "Urinary bladder": "Urinary_bladder",
    "Ovarian": "Ovary",
    "Endometrial": "Endometrium",
    "Cervical": "Cervix",
    "GIST": "GIST",
    "HCC": "HCC",
    "Lung": "Lung",
}

NEGATIVE_NODE = re.compile(
    r"\bno\s+(?:definite\s+)?(?:abdominal\s+|pelvic\s+|regional\s+)?"
    r"(?:lymphadenopathy|enlarged\s+lymph\s+nodes?|LAP)\b|無(?:明顯)?淋巴結",
    re.I,
)
NEGATIVE_MET = re.compile(
    r"\bno\s+(?:evidence\s+of\s+|definite\s+)?(?:distant\s+)?"
    r"(?:metastasis|metastases|metastatic\s+disease)\b|無(?:明顯)?遠端轉移",
    re.I,
)
MET_WORD = re.compile(r"metasta|遠端轉移|轉移性", re.I)
EXPLICIT_PATH_TNM = re.compile(
    r"\b(?P<prefix>[cpyra]{0,3})T(?P<t>\d[a-c]?)N(?P<n>\d[a-c]?)"
    r"(?:M(?P<m>\d[a-c]?))?",
    re.I,
)


def _first(row: dict[str, str], aliases: tuple[str, ...]) -> str:
    for name in aliases:
        if name in row:
            return (row.get(name) or "").strip()
    return ""


def import_tsv_text(
    text: str,
    *,
    only_status: str | None = "待修正",
    doctor: str | None = None,
    all_rows: list[dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    """Rows to review; `all_rows`, if given, also receives the filtered-out rows."""
    text = text.lstrip("\ufeff")
    # Rows copied straight from the sheet have no header; their first cell is
    # an accession number, so fall back to the sheet's fixed column order.
    headerless = bool(HEADERLESS_FIRST_CELL.match(text.split("\t", 1)[0].strip()))
    reader = csv.DictReader(
        io.StringIO(text),
        fieldnames=SHEET_COLUMNS if headerless else None,
        delimiter="\t",
    )
    if not reader.fieldnames:
        raise ValueError("TSV has no header row")
    rows: list[dict[str, Any]] = []
    for input_row, raw in enumerate(reader, start=1 if headerless else 2):
        normalized = {
            key: _first(raw, aliases) for key, aliases in HEADER_ALIASES.items()
        }
        normalized["input_row"] = input_row
        if not normalized["accession"] or not normalized["chart_no"]:
            raise ValueError(
                f"TSV row {input_row} is missing 申請單號 or 院內病歷號碼"
            )
        if all_rows is not None:
            all_rows.append(normalized)
        if only_status and normalized["status"] != only_status:
            continue
        if doctor and doctor not in normalized["review_doctor"]:
            continue
        rows.append(normalized)
    return rows


def import_tsv_file(
    input_path: Path,
    *,
    only_status: str | None = "待修正",
    doctor: str | None = None,
    all_rows: list[dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    return import_tsv_text(
        input_path.read_text(encoding="utf-8-sig"),
        only_status=only_status,
        doctor=doctor,
        all_rows=all_rows,
    )


def source_rows_sidecar(cases_path: Path) -> Path:
    """Where import-tsv records every pasted row (sheet order) for paste-back."""
    return cases_path.with_name(f"{cases_path.stem}_source_rows.json")


def minimal_source_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    keys = ("input_row", "accession", "cancer_type_existing", "status")
    return [{key: row.get(key, "") for key in keys} for row in rows]


def infer_modality(study_name: str) -> str:
    upper = study_name.upper()
    if "CT" in upper:
        return "CT"
    # MRCP is an MR study; RIS names it "ABD MRCP" with no "MRI" in the name.
    if "MRI" in upper or "MRCP" in upper or re.search(r"\bMR\b", upper):
        return "MRI"
    if "PET" in upper:
        return "PET/CT"
    if "US" in upper or "ULTRASOUND" in upper:
        return "Ultrasound"
    return ""


def site_modality(study_name: str) -> str:
    """Map a RIS study name to the website's Imaging Modality choice."""
    base = infer_modality(study_name)
    if base not in ("CT", "MRI"):
        return ""
    # 有造影劑 / 有&無造影劑 = contrast given; 無造影劑 alone = non-contrast.
    contrast = "有" in study_name or "WITH CONTRAST" in study_name.upper()
    return f"{base} with contrast" if contrast else f"{base} without contrast"


def _require_choice(value: Any, allowed: Any, field: str) -> None:
    if value not in allowed:
        raise ValueError(f"{field}={value!r} is not a website option {list(allowed)}")


def _require_choices(values: Any, allowed: Any, field: str) -> list[str]:
    if values in (None, ""):
        return []
    if not isinstance(values, list):
        raise ValueError(f"{field} must be a list")
    for value in values:
        _require_choice(value, allowed, field)
    return values


def _site_form(
    row: dict[str, Any], cancer: dict[str, Any], entry: dict[str, Any]
) -> dict[str, Any]:
    """Validate an LLM proposal against the website's own form choices."""
    is_hcc = cancer.get("id") == "HCC"
    known = {
        "cancer", "modality", "T", "N", "M", "T_RL", "T_location", "N_location",
        "N_location_R", "N_location_L", "M_location", "liver", "characters",
        "number", "stage", "evidence", "assumptions", "warnings",
    }
    unknown = set(entry) - known
    if unknown:
        raise ValueError(f"Unknown proposal field(s): {sorted(unknown)}")
    for label in ("T", "N", "M"):
        _require_choice(entry.get(label), cancer.get(label, {}), label)
    form: dict[str, Any] = {
        # Reviewer preference: leave the website's optional Study Date blank.
        "date": "",
        "method": entry.get("modality") or site_modality(row.get("study_name", "")),
        "T": entry["T"],
        "N": entry["N"],
        "M": entry["M"],
    }
    _require_choice(form["method"], SITE_MODALITIES, "modality")
    t_locations = cancer.get("T_location", [])
    if is_hcc:
        form["T_location"] = _require_choices(entry.get("T_location"), t_locations, "T_location")
        form["liver"] = _require_choices(entry.get("liver"), HCC_LIVER_FEATURES, "liver")
        form["characters"] = _require_choices(
            entry.get("characters"), HCC_CHARACTERISTICS, "characters"
        )
        form["number"] = str(entry.get("number") or "")
    else:
        for field in ("liver", "characters", "number"):
            if entry.get(field):
                raise ValueError(f"{field} is only used by the HCC form")
        if entry.get("T_location"):
            _require_choice(entry["T_location"], t_locations, "T_location")
            form["T_location"] = entry["T_location"]
        if entry.get("T_RL"):
            if not cancer.get("T_RL"):
                raise ValueError("T_RL is not offered for this cancer type")
            _require_choice(entry["T_RL"], SITE_SIDES, "T_RL")
            form["T_RL"] = entry["T_RL"]
    n_locations = cancer.get("N_location", [])
    if cancer.get("N_RL") and not is_hcc:
        if entry.get("N_location"):
            raise ValueError("Use N_location_R / N_location_L for this cancer type")
        for field in ("N_location_R", "N_location_L"):
            form[field] = _require_choices(entry.get(field), n_locations, field)
    elif not is_hcc:
        if entry.get("N_location_R") or entry.get("N_location_L"):
            raise ValueError("Use N_location for this cancer type")
        form["N_location"] = _require_choices(entry.get("N_location"), n_locations, "N_location")
    m_locations = _require_choices(
        entry.get("M_location"), cancer.get("M_location", []), "M_location"
    )
    if m_locations and form["M"] == "M0":
        raise ValueError("M_location is disabled on the website when M0 is selected")
    form["M_location"] = m_locations
    return form


def prepare_case_from_proposal(
    row: dict[str, Any], entry: dict[str, Any], catalog: CancerCatalog
) -> dict[str, Any]:
    """Build a review case from one validated LLM proposal entry.

    The LLM chooses only website form values; the stage always comes from the
    catalog lookup, and the text from the ported website template.
    """
    warnings = list(entry.get("warnings") or [])
    proposal: dict[str, Any] = {
        "origin": "llm",
        "catalog_id": "",
        "catalog_name": "",
        "t": "",
        "n": "",
        "m": "",
        "stage": "N/A",
        "lookup_key": "",
        "matching_stages": [],
        "evidence": dict(entry.get("evidence") or {}),
        "assumptions": list(entry.get("assumptions") or []),
        "warnings": warnings,
        "staging_text": "",
        "text_sha256": "",
    }
    if entry.get("skip"):
        proposal["skip_reason"] = entry["skip"]
        warnings.insert(0, f"No staging proposed: {entry['skip']}")
    else:
        cancer_id = entry.get("cancer", "")
        cancer = catalog.documents.get(cancer_id)
        if not cancer:
            raise ValueError(f"Unknown TNM catalog cancer id {cancer_id!r}")
        form = _site_form(row, cancer, entry)
        result = catalog.resolve_stage(cancer_id, form["T"], form["N"], form["M"])
        stage = result.stage
        if result.has_conflict:
            candidates = list(dict.fromkeys(result.matching_stages))
            if entry.get("stage") not in candidates:
                raise ValueError(
                    f"{result.tnm} maps to {candidates} in the catalog; "
                    "the proposal must choose one as 'stage'"
                )
            stage = entry["stage"]
            proposal["stage_resolution"] = {"chosen": stage, "candidates": candidates}
            if cancer.get("Staging_note"):
                warnings.append(
                    f"The stage group of {result.tnm} needs a choice: {', '.join(candidates)}; "
                    f"proposal chose {stage} (default: {result.stage}). {cancer['Staging_note']}"
                )
            else:
                warnings.append(
                    f"TNM website catalog conflict for {result.tnm}: {', '.join(candidates)}; "
                    f"proposal chose {stage} (website first match: {result.stage})."
                )
        elif entry.get("stage"):
            raise ValueError("'stage' may only be set to resolve a catalog conflict")
        if cancer.get("Review_note"):
            warnings.append(cancer["Review_note"])
        text = render_site_report(cancer, form, stage=stage)
        proposal.update(
            {
                "catalog_id": cancer_id,
                "catalog_name": cancer.get("name", cancer_id),
                "catalog_update_time": cancer.get("update_time", ""),
                "site_form": form,
                "t": form["T"],
                "n": form["N"],
                "m": form["M"],
                "stage": stage,
                "lookup_key": result.lookup_key,
                "matching_stages": list(result.matching_stages),
                "staging_text": text,
                "text_sha256": text_sha256(text),
            }
        )
    return {
        "source": row,
        "proposal": proposal,
        "approval": {
            "state": "pending",
            "approved_text_sha256": "",
            "approved_at": "",
        },
        "execution": {},
    }


def render_form(
    row: dict[str, Any], catalog: CancerCatalog, entry: dict[str, Any]
) -> dict[str, Any]:
    """Render the website template from reviewer form values (no save).

    Same validation as LLM proposals. On a catalog stage conflict the chosen
    `stage` is used if it is a candidate, otherwise the website's first match.
    """
    cancer = catalog.documents.get(entry.get("cancer", ""))
    if not cancer:
        raise ValueError(f"Unknown TNM catalog cancer id {entry.get('cancer')!r}")
    form = _site_form(row, cancer, {key: value for key, value in entry.items() if key != "cancer"})
    result = catalog.resolve_stage(cancer["id"], form["T"], form["N"], form["M"])
    candidates = list(dict.fromkeys(result.matching_stages))
    stage = entry["stage"] if result.has_conflict and entry.get("stage") in candidates else result.stage
    return {
        "cancer": cancer["id"],
        "catalog_name": cancer.get("name", cancer["id"]),
        "form": form,
        "stage": stage,
        "candidates": candidates if result.has_conflict else [],
        "lookup_key": result.lookup_key,
        "matching_stages": list(result.matching_stages),
        "text": render_site_report(cancer, form, stage=stage),
    }


def set_case_form(
    review: dict[str, Any],
    catalog: CancerCatalog,
    accession: str,
    *,
    entry: dict[str, Any],
    expected_sha256: str,
    staging_text: str | None = None,
) -> dict[str, Any]:
    """Save a reviewer's template-form edit: structured fields plus the text.

    `staging_text` keeps any hand tweak made after rendering; the T/N/M/stage
    digest always comes from the form. Approval returns to pending.
    """
    case = find_case(review, accession)
    ensure_editable(case)
    proposal = case["proposal"]
    current_text = proposal.get("staging_text", "")
    current_sha = text_sha256(current_text) if current_text else ""
    if current_sha != expected_sha256:
        raise ValueError(f"Text SHA mismatch: expected {expected_sha256}, current {current_sha}")
    rendered = render_form(case["source"], catalog, entry)
    text = (staging_text if staging_text is not None else rendered["text"])
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    if not text.strip():
        raise ValueError("Staging text cannot be empty")
    cancer = catalog.documents[rendered["cancer"]]
    proposal.update(
        {
            "catalog_id": rendered["cancer"],
            "catalog_name": rendered["catalog_name"],
            "catalog_update_time": cancer.get("update_time", ""),
            "site_form": rendered["form"],
            "t": rendered["form"]["T"],
            "n": rendered["form"]["N"],
            "m": rendered["form"]["M"],
            "stage": rendered["stage"],
            "lookup_key": rendered["lookup_key"],
            "matching_stages": rendered["matching_stages"],
            "staging_text": text,
            "text_sha256": text_sha256(text),
            "manually_edited": True,
            "edited_at": datetime.now(timezone.utc).isoformat(),
        }
    )
    proposal.pop("skip_reason", None)
    if rendered["candidates"]:
        proposal["stage_resolution"] = {"chosen": rendered["stage"], "candidates": rendered["candidates"]}
    else:
        proposal.pop("stage_resolution", None)
    case["approval"] = {"state": "pending", "approved_text_sha256": "", "approved_at": ""}
    return case


def catalog_choices(catalog: CancerCatalog) -> dict[str, Any]:
    """Everything the template form needs, in the website's terms."""
    keys = ("T", "N", "M", "T_RL", "N_RL", "T_location", "N_location", "M_location")
    # Website menu order and groups; catalog entries the menu lacks go last.
    menu = [(group, cancer_id) for group, ids in SITE_CANCER_MENU for cancer_id in ids]
    listed = {cancer_id for _, cancer_id in menu}
    menu += [("Other", cancer_id) for cancer_id in sorted(catalog.documents) if cancer_id not in listed]
    cancers = [
        {
            "id": cancer_id,
            "group": group,
            "name": catalog.documents[cancer_id].get("name", cancer_id),
            **{key: catalog.documents[cancer_id].get(key) for key in keys},
        }
        for group, cancer_id in menu
        if cancer_id in catalog.documents
    ]
    return {
        "cancers": cancers,
        "modalities": list(SITE_MODALITIES),
        "sides": list(SITE_SIDES),
        "hcc_liver": list(HCC_LIVER_FEATURES),
        "hcc_characters": list(HCC_CHARACTERISTICS),
    }


def _catalog_id(row: dict[str, Any], guess: str, catalog: CancerCatalog) -> str:
    existing = (row.get("cancer_type_existing") or "").strip()
    for candidate in (existing, guess):
        if candidate in catalog.documents:
            return candidate
        mapped = CANCER_ID_MAP.get(candidate)
        if mapped:
            return mapped
    combined = " ".join(
        str(row.get(key, "")) for key in ("notes_txt", "notes2_txt", "notes3_txt")
    )
    if "結腸癌" in combined or "大腸癌" in combined:
        return "Colorectum"
    return ""


def _location(cancer_id: str, report: str) -> str:
    if cancer_id == "Colorectum":
        match = re.search(
            r"(cecum(?:\s+to\s+ascending\s+colon)?|ascending\s+colon|"
            r"transverse\s+colon|descending\s+colon|sigmoid\s+colon|rectum)",
            report,
            re.I,
        )
        return match.group(1) if match else ""
    return ""


def _canonical_option(options: dict[str, Any], value: str) -> str:
    return next((key for key in options if key.lower() == value.lower()), "")


def _explicit_path_tnm(
    patho: str, cancer: dict[str, Any]
) -> tuple[dict[str, str], str]:
    match = EXPLICIT_PATH_TNM.search(patho or "")
    if not match:
        return {}, ""
    values: dict[str, str] = {}
    for label, group in (("T", "t"), ("N", "n"), ("M", "m")):
        raw = match.group(group)
        if raw:
            canonical = _canonical_option(cancer.get(label, {}), label + raw)
            if canonical:
                values[label] = canonical
    return values, match.group(0)


def _render_context(cancer_id: str, row: dict[str, Any]) -> dict[str, str]:
    report = row.get("report_txt", "") or ""
    patho = row.get("patho_txt", "") or ""
    if cancer_id == "HCC":
        return {
            "t_location": "right lobe of liver" if "right lobe" in report.lower() else "",
            "n_location": (
                "Small para-aortic lymph nodes"
                if re.search(r"small\s+para-aortic\s+lymph nodes", report, re.I)
                else ""
            ),
            "other_findings": (
                "Suspected right portal vein thrombosis and invasion into "
                "right proximal IHD."
                if re.search(r"suspect right portal vein thrombosis", report, re.I)
                else "N/A"
            ),
        }
    if cancer_id == "Lip_Oral_Cavity":
        return {
            "t_location": (
                "left upper buccogingival"
                if "left upper buccogingival" in patho.lower()
                else ""
            ),
            "n_location": "Pathology-stated nodal category",
            "other_findings": (
                "19 mm left submandibular gland mass and small bilateral neck "
                "lymph nodes (<1 cm)."
                if "19mm" in report and "bilateral neck" in report
                else "N/A"
            ),
        }
    return {
        "t_location": _location(cancer_id, report),
        "n_location": "",
        "other_findings": "N/A",
    }


def prepare_case(row: dict[str, Any], catalog: CancerCatalog) -> dict[str, Any]:
    classify_row = {
        "report_txt": row.get("report_txt", ""),
        "patho_txt": row.get("patho_txt", ""),
        "dx_txt": row.get("dx_txt", ""),
        "notes_txt": " ".join(
            str(row.get(key, ""))
            for key in ("notes_txt", "notes2_txt", "notes3_txt")
        ),
    }
    guess = classify_mod.classify(classify_row)
    cancer_id = _catalog_id(row, guess.cancer_type, catalog)
    warnings: list[str] = []
    evidence: dict[str, str] = {}
    assumptions: list[str] = []

    if not cancer_id:
        warnings.append("Cancer type could not be mapped to the TNM website catalog.")
        proposal = {
            "catalog_id": "",
            "catalog_name": "",
            "t": "",
            "n": "",
            "m": "",
            "stage": "N/A",
            "lookup_key": "",
            "matching_stages": [],
            "evidence": evidence,
            "assumptions": assumptions,
            "warnings": warnings,
            "staging_text": "",
            "text_sha256": "",
        }
    else:
        cancer = catalog.documents[cancer_id]
        report = row.get("report_txt", "") or ""
        patho = row.get("patho_txt", "") or ""
        explicit, explicit_text = _explicit_path_tnm(patho, cancer)
        hcc_sizes_mm = [
            int(value)
            for value in re.findall(r"(?:up to\s+)?(\d+)\s*mm", report, re.I)
        ]

        if explicit.get("T"):
            t = explicit["T"]
            evidence["T"] = f"Pathology staging: {explicit_text}"
        elif (
            cancer_id == "HCC"
            and re.search(r"multiple tumors", report, re.I)
            and any(value > 50 for value in hcc_sizes_mm)
            and "T3" in cancer.get("T", {})
        ):
            t = "T3"
            evidence["T"] = (
                "Multiple tumors, with the largest measuring up to "
                f"{max(hcc_sizes_mm)} mm (>5 cm)."
            )
            if re.search(r"suspect right portal vein thrombosis", report, re.I):
                warnings.append(
                    "Potential T4 alternative: use T4 only if the suspected right "
                    "portal-vein finding is confirmed as tumor involvement of a major branch."
                )
        else:
            t = "Tx" if "Tx" in cancer.get("T", {}) else ""
            if t:
                evidence["T"] = "Primary-tumor invasion depth is not established by the report text."
            else:
                warnings.append("Catalog has no Tx option; T requires manual selection.")

        node_match = NEGATIVE_NODE.search(report)
        small_node_match = re.search(
            r"small\s+(?:para-aortic\s+)?lymph nodes(?:\s*\(<\s*1\s*cm\))?",
            report,
            re.I,
        )
        if explicit.get("N"):
            n = explicit["N"]
            evidence["N"] = f"Pathology staging: {explicit_text}"
        elif node_match and "N0" in cancer.get("N", {}):
            n = "N0"
            evidence["N"] = node_match.group(0)
        elif small_node_match and "N0" in cancer.get("N", {}):
            n = "N0"
            evidence["N"] = (
                small_node_match.group(0)
                + " (treated as equivocal/non-pathologic for the website's N0 option)"
            )
        elif "N0" in cancer.get("N", {}):
            n = "N0"
            assumptions.append("N0 is assumed because no suspicious regional nodes are described.")
        else:
            n = ""
            warnings.append("Catalog has no N0 option; N requires manual selection.")

        met_match = NEGATIVE_MET.search(report)
        if explicit.get("M"):
            m = explicit["M"]
            evidence["M"] = f"Pathology staging: {explicit_text}"
        elif met_match and "M0" in cancer.get("M", {}):
            m = "M0"
            evidence["M"] = met_match.group(0)
        elif "M0" in cancer.get("M", {}) and not MET_WORD.search(report):
            m = "M0"
            assumptions.append(
                "M0 is assumed because no distant metastasis is described; verify imaging coverage."
            )
        else:
            m = ""
            warnings.append("M category requires manual review.")

        if t and n and m:
            stage_result = catalog.resolve_stage(cancer_id, t, n, m)
            if stage_result.has_conflict:
                warnings.append(
                    "TNM website catalog conflict: "
                    + ", ".join(stage_result.matching_stages)
                )
            render_context = _render_context(cancer_id, row)
            staging_text = render_staging_text(
                cancer,
                study_date=row.get("study_date", ""),
                modality=infer_modality(row.get("study_name", "")),
                t=t,
                n=n,
                m=m,
                stage=stage_result.stage,
                **render_context,
            )
            stage = stage_result.stage
            lookup_key = stage_result.lookup_key
            matching_stages = list(stage_result.matching_stages)
        else:
            staging_text = ""
            stage = "N/A"
            lookup_key = ""
            matching_stages = []

        proposal = {
            "catalog_id": cancer_id,
            "catalog_name": cancer.get("name", cancer_id),
            "catalog_update_time": cancer.get("update_time", ""),
            "classifier_guess": guess.cancer_type,
            "classifier_reason": {
                "column": guess.matched_column,
                "snippet": guess.matched_snippet,
            },
            "t": t,
            "n": n,
            "m": m,
            "stage": stage,
            "lookup_key": lookup_key,
            "matching_stages": matching_stages,
            "evidence": evidence,
            "assumptions": assumptions,
            "warnings": warnings,
            "staging_text": staging_text,
            "text_sha256": text_sha256(staging_text) if staging_text else "",
        }
        if (
            cancer_id == "Lip_Oral_Cavity"
            and "submandibular" in report.lower()
            and "buccogingival" in patho.lower()
        ):
            proposal["warnings"].append(
                "Primary-site correlation required: MRI describes a submandibular-gland "
                "mass, while pathology identifies left upper buccogingival SCC."
            )

    return {
        "source": row,
        "proposal": proposal,
        "approval": {
            "state": "pending",
            "approved_text_sha256": "",
            "approved_at": "",
        },
        "execution": {},
    }


def prepare_review(
    rows: list[dict[str, Any]],
    catalog: CancerCatalog,
    proposals: dict[str, Any] | None = None,
) -> dict[str, Any]:
    review: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "catalog": {
            "source": catalog.snapshot.get("source", ""),
            "fetched_at": catalog.fetched_at,
            "sha256": catalog.sha256,
        },
    }
    if proposals is None:
        review["cases"] = [prepare_case(row, catalog) for row in rows]
        return review

    entries = proposals.get("cases", {})
    accessions = [str(row["accession"]) for row in rows]
    missing = [acc for acc in accessions if acc not in entries]
    extra = [acc for acc in entries if acc not in accessions]
    if missing or extra:
        raise ValueError(
            f"Proposals must cover exactly the imported rows; "
            f"missing={missing} extra={extra}"
        )
    cases = []
    for row in rows:
        try:
            cases.append(prepare_case_from_proposal(row, entries[str(row["accession"])], catalog))
        except ValueError as exc:
            raise ValueError(f"Proposal for {row['accession']}: {exc}") from exc
    review["proposals"] = {
        key: proposals.get(key, "") for key in ("generated_by", "generated_at")
    }
    review["cases"] = cases
    return review


def review_has_work(review: dict[str, Any]) -> bool:
    """True when overwriting the review would discard human edits or results."""
    return any(
        case.get("proposal", {}).get("manually_edited")
        or case.get("approval", {}).get("state") in ("approved", NOT_APPLICABLE)
        or case.get("execution")
        or case.get("sheet")
        for case in review.get("cases", [])
    )


def save_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def find_case(review: dict[str, Any], accession: str) -> dict[str, Any]:
    matches = [
        case
        for case in review.get("cases", [])
        if str(case.get("source", {}).get("accession", "")) == str(accession)
    ]
    if len(matches) != 1:
        raise ValueError(f"Expected one case for accession {accession}; found {len(matches)}")
    return matches[0]


def set_case_tnm(
    review: dict[str, Any],
    catalog: CancerCatalog,
    accession: str,
    *,
    t: str,
    n: str,
    m: str,
) -> dict[str, Any]:
    case = find_case(review, accession)
    ensure_editable(case)
    proposal = case["proposal"]
    cancer_id = proposal["catalog_id"]
    cancer = catalog.documents[cancer_id]
    for label, value in (("T", t), ("N", n), ("M", m)):
        if value not in cancer.get(label, {}):
            raise ValueError(f"{value} is not a valid {label} option for {cancer_id}")
    stage_result = catalog.resolve_stage(cancer_id, t, n, m)
    proposal.pop("stage_resolution", None)
    if proposal.get("site_form"):
        form = {**proposal["site_form"], "T": t, "N": n, "M": m}
        if m == "M0":
            form["M_location"] = []
        proposal["site_form"] = form
        text = render_site_report(cancer, form, stage=stage_result.stage)
    else:
        render_context = _render_context(cancer_id, case["source"])
        text = render_staging_text(
            cancer,
            study_date=case["source"].get("study_date", ""),
            modality=infer_modality(case["source"].get("study_name", "")),
            t=t,
            n=n,
            m=m,
            stage=stage_result.stage,
            **render_context,
        )
    proposal.update(
        {
            "t": t,
            "n": n,
            "m": m,
            "stage": stage_result.stage,
            "lookup_key": stage_result.lookup_key,
            "matching_stages": list(stage_result.matching_stages),
            "staging_text": text,
            "text_sha256": text_sha256(text),
        }
    )
    case["approval"] = {
        "state": "pending",
        "approved_text_sha256": "",
        "approved_at": "",
    }
    return case


def update_case_staging_text(
    review: dict[str, Any],
    accession: str,
    *,
    staging_text: str,
    expected_sha256: str,
) -> dict[str, Any]:
    """Save an exact human edit and invalidate approval when content changes."""
    case = find_case(review, accession)
    ensure_editable(case)
    proposal = case["proposal"]
    current_text = proposal.get("staging_text", "")
    current_sha = text_sha256(current_text) if current_text else ""
    if current_sha != expected_sha256:
        raise ValueError(
            f"Text SHA mismatch: expected {expected_sha256}, current {current_sha}"
        )

    normalized = staging_text.replace("\r\n", "\n").replace("\r", "\n")
    if not normalized.strip():
        raise ValueError("Staging text cannot be empty")
    new_sha = text_sha256(normalized)
    if new_sha == current_sha:
        return case

    proposal["staging_text"] = normalized
    proposal["text_sha256"] = new_sha
    proposal["manually_edited"] = True
    proposal["edited_at"] = datetime.now(timezone.utc).isoformat()
    case["approval"] = {
        "state": "pending",
        "approved_text_sha256": "",
        "approved_at": "",
    }
    return case


def case_sent(case: dict[str, Any]) -> bool:
    """True once RIS accepted this case's staging (not for previews)."""
    execution = case.get("execution") or {}
    response = execution.get("response") or {}
    return (
        execution.get("mode") == "execute"
        and execution.get("status") in ("ok", "partial", "skipped")
        and bool(response.get("submitted") or response.get("already_applied"))
    )


def ensure_not_sent(case: dict[str, Any]) -> None:
    """Sent text is final: changing it here could never reach RIS."""
    if case_sent(case):
        raise ValueError(
            "Already sent to RIS; this staging text is locked. Correct it in RIS directly."
        )


# Reviewer disposition for studies that cannot be staged (e.g. an unsupported
# cancer type): never sent, pasted back as 其他癌 / 已備註.
NOT_APPLICABLE = "not_applicable"
NOT_APPLICABLE_SHEET = ("其他癌", "已備註")


def is_not_applicable(case: dict[str, Any]) -> bool:
    return case.get("approval", {}).get("state") == NOT_APPLICABLE


def ensure_editable(case: dict[str, Any]) -> None:
    ensure_not_sent(case)
    if is_not_applicable(case):
        raise ValueError("Marked not applicable (N/A); undo N/A before editing or approving.")


def mark_not_applicable(review: dict[str, Any], accession: str) -> dict[str, Any]:
    """One-click N/A; undone with revoke_case_approval()."""
    case = find_case(review, accession)
    ensure_not_sent(case)
    case["approval"] = {
        "state": NOT_APPLICABLE,
        "approved_text_sha256": "",
        "approved_at": "",
        "marked_at": datetime.now(timezone.utc).isoformat(),
    }
    return case


def _note_cancer_type(source: dict[str, Any]) -> str:
    notes = " ".join(str(source.get(key, "")) for key in ("notes_txt", "notes2_txt", "notes3_txt"))
    for label in SHEET_CANCER_TYPES:
        if label in notes:
            return label
    return next((label for alias, label in NOTE_CANCER_ALIASES.items() if alias in notes), "")


def source_rows(review: dict[str, Any]) -> list[dict[str, Any]]:
    """Every pasted row in sheet order; falls back to the imported cases."""
    if review.get("source_rows"):
        return review["source_rows"]
    return [
        {
            "input_row": case["source"].get("input_row"),
            "accession": case["source"]["accession"],
            "cancer_type_existing": case["source"].get("cancer_type_existing", ""),
            "status": case["source"].get("status", ""),
        }
        for case in review.get("cases", [])
    ]


def sheet_pasteback(
    review: dict[str, Any],
    *,
    unfinished: str = "empty",
    selected: list[str] | None = None,
) -> dict[str, Any]:
    """Two-column (癌別, 完成) block in sheet order for pasting back.

    A row is finished when it was sent to RIS (完成) or the reviewer chose its
    values with set_case_sheet(). Exactly the `selected` rows (accessions) are
    copied, one line each, in sheet order; unselected rows add no line. By
    default every row from the first to the last finished row is selected.
    A selected row that is not finished is blank (unfinished="empty", the
    reviewer's default) or repeats its current sheet values ("keep").
    """
    cases = {str(case["source"]["accession"]): case for case in review.get("cases", [])}
    rows = []
    for source in source_rows(review):
        accession = str(source["accession"])
        case = cases.get(accession)
        original_cancer = source.get("cancer_type_existing", "") or ""
        original_status = source.get("status", "") or ""
        row: dict[str, Any] = {
            "input_row": source.get("input_row"),
            "accession": accession,
            "in_review": case is not None,
            "sent": False,
            "study_name": "",
            "original_cancer_type": original_cancer,
            "original_status": original_status,
            "cancer_type": original_cancer,
            "cancer_source": "sheet" if original_cancer else "",
            "status": original_status,
            "status_source": "sheet",
        }
        if case is not None:
            chosen = case.get("sheet") or {}
            sent = case_sent(case)
            template = CATALOG_SHEET_CANCER.get(case["proposal"].get("catalog_id", ""), "")
            note = _note_cancer_type(case["source"])
            suggested = template or note
            # Unsent rows keep the sheet's value unless the reviewer chooses.
            default_cancer, default_cancer_source = (
                (original_cancer, "sheet")
                if original_cancer or not sent
                else (suggested, "template" if template else "committee note" if note else "")
            )
            default_status, default_status_source = (
                ("完成", "sent") if sent else (original_status, "sheet")
            )
            if is_not_applicable(case):
                (default_cancer, default_status) = NOT_APPLICABLE_SHEET
                default_cancer_source = default_status_source = "N/A"
            row.update(
                {
                    "sent": sent,
                    "study_name": case["source"].get("study_name", ""),
                    "default_cancer_type": default_cancer,
                    "default_status": default_status,
                    "cancer_type": chosen.get("cancer_type") or default_cancer,
                    "cancer_source": "chosen" if chosen.get("cancer_type") else default_cancer_source,
                    "status": chosen.get("status") or default_status,
                    "status_source": "chosen" if chosen.get("status") else default_status_source,
                    "suggested_cancer_type": suggested,
                    "template_cancer_type": template,
                    "note_cancer_type": note,
                }
            )
        row["not_applicable"] = case is not None and is_not_applicable(case)
        row["finished"] = (
            row["sent"]
            or row["not_applicable"]
            or "chosen" in (row["cancer_source"], row["status_source"])
        )
        rows.append(row)
    numbers = [row["input_row"] for row in rows if isinstance(row["input_row"], int)]
    gaps = sorted(set(range(min(numbers), max(numbers) + 1)) - set(numbers)) if numbers else []
    if selected is None:
        finished = [index for index, row in enumerate(rows) if row["finished"]]
        span = range(finished[0], finished[-1] + 1) if finished else range(0)
        for index, row in enumerate(rows):
            row["selected"] = index in span
    else:
        for row in rows:
            row["selected"] = row["accession"] in selected
    keep = unfinished == "keep"
    block = [row for row in rows if row["selected"]]
    picked = [index for index, row in enumerate(rows) if row["selected"]]
    # Unselected rows inside the selection: the block only lines up with a sheet
    # view where these rows are hidden (e.g. a filter), so the page warns.
    skipped = [
        rows[index]["input_row"]
        for index in range(picked[0], picked[-1] + 1)
        if not rows[index]["selected"]
    ] if picked else []

    def line(row: dict[str, Any]) -> str:
        if row["finished"]:
            return f"{row['cancer_type']}\t{row['status']}"
        return f"{row['original_cancer_type']}\t{row['original_status']}" if keep else "\t"

    return {
        "rows": rows,
        "unfinished": "keep" if keep else "empty",
        "block_start_row": block[0]["input_row"] if block else None,
        "block_length": len(block),
        "skipped_rows": skipped,
        "tsv": "\n".join(line(row) for row in block),
        "gaps": gaps,
        "options": {"cancer_types": list(SHEET_CANCER_TYPES), "statuses": list(SHEET_STATUSES)},
    }


def set_case_sheet(
    review: dict[str, Any], accession: str, *, cancer_type: str | None, status: str | None
) -> dict[str, Any]:
    """Save the reviewer's paste-back choice; an empty string clears it."""
    case = find_case(review, accession)
    chosen = dict(case.get("sheet") or {})
    for key, value, allowed in (
        ("cancer_type", cancer_type, SHEET_CANCER_TYPES),
        ("status", status, SHEET_STATUSES),
    ):
        if value is None:
            continue
        if value == "":
            chosen.pop(key, None)
        elif value in allowed:
            chosen[key] = value
        else:
            raise ValueError(f"{key}={value!r} is not a sheet dropdown option")
    if chosen:
        case["sheet"] = chosen
    else:
        case.pop("sheet", None)
    return case


def approve_case(review: dict[str, Any], accession: str, expected_sha256: str) -> dict[str, Any]:
    case = find_case(review, accession)
    ensure_editable(case)
    proposal = case["proposal"]
    staging_text = proposal.get("staging_text", "")
    actual = text_sha256(staging_text) if staging_text else ""
    if (
        not actual
        or actual != expected_sha256
        or proposal.get("text_sha256", "") != actual
    ):
        raise ValueError(f"Text SHA mismatch: expected {expected_sha256}, current {actual}")
    # A catalog conflict is resolved by an explicit stage choice recorded in the
    # proposal (shown as a warning) or by the reviewer's own text edit.
    if (
        len(set(proposal.get("matching_stages", []))) > 1
        and not proposal.get("stage_resolution")
        and not proposal.get("manually_edited")
    ):
        raise ValueError("Catalog stage conflict must be resolved manually before approval")
    case["approval"] = {
        "state": "approved",
        "approved_text_sha256": actual,
        "approved_at": datetime.now(timezone.utc).isoformat(),
    }
    return case


def revoke_case_approval(review: dict[str, Any], accession: str) -> dict[str, Any]:
    case = find_case(review, accession)
    ensure_not_sent(case)
    case["approval"] = {
        "state": "pending",
        "approved_text_sha256": "",
        "approved_at": "",
    }
    return case


def approved_cases(review: dict[str, Any]) -> list[dict[str, Any]]:
    approved: list[dict[str, Any]] = []
    for case in review.get("cases", []):
        proposal = case.get("proposal", {})
        approval = case.get("approval", {})
        current_sha = text_sha256(proposal.get("staging_text", ""))
        if (
            approval.get("state") == "approved"
            and approval.get("approved_text_sha256") == current_sha
            and proposal.get("text_sha256") == current_sha
        ):
            approved.append(case)
    return approved


def sendable_cases(review: dict[str, Any]) -> list[dict[str, Any]]:
    """Approved cases not yet sent: a sent case keeps its execution record."""
    return [case for case in approved_cases(review) if not case_sent(case)]


def batch_sha256(review: dict[str, Any]) -> str:
    manifest = [
        {
            "accession": case["source"]["accession"],
            "chart_no": case["source"]["chart_no"],
            "approved_text_sha256": case["approval"]["approved_text_sha256"],
        }
        for case in sendable_cases(review)
    ]
    raw = json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return text_sha256(raw)
