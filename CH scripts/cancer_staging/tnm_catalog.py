"""Read and reproduce the public cancer-tnm Firebase catalog.

The catalog is reference data, not an inference engine. This module records
provenance, detects contradictory stage mappings, and mirrors the website's
first-match behavior without hiding contradictions.

`catalog_cache.json` is the website's data as it is. `load_catalog` adds the
local AJCC corrections of `catalog_corrections.py` unless `corrected=False`.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.request import Request, urlopen

import catalog_corrections

CATALOG_URL = (
    "https://firestore.googleapis.com/v1/projects/cancer-tnm/"
    "databases/(default)/documents/cancer_type?pageSize=100"
)
DEFAULT_CACHE = Path(__file__).with_name("catalog_cache.json")

# Fixed choice lists hard-coded in the deployed website's form components
# (app-tnm and app-hcc in main.*.js), not stored in Firestore.
SITE_MODALITIES = (
    "CT with contrast",
    "CT without contrast",
    "MRI with contrast",
    "MRI without contrast",
)
SITE_SIDES = ("Right", "Left", "Bilateral")
# The website's navigation menu (app-navi): top-level groups and their cancer
# ids in on-screen order, including the Pharynx/Larynx/Biliary Tree sub-menus.
SITE_CANCER_MENU = (
    ("LUNG", ("Lung",)),
    ("H & N", (
        "Lip_Oral_Cavity", "NPC", "Oropharynx_P16+", "Oropharynx_P16-", "Hypopharynx",
        "Supraglottis", "Glottis", "Subglottis",
    )),
    ("GI", (
        "Colorectum", "GIST", "Esophagus", "Stomach", "Pancreas", "HCC",
        "Distal_bile_duct", "Perihilar_bile_duct", "Intrahepatic_bil_duct",
    )),
    ("GU", ("RCC", "Urinary_bladder", "Prostate", "Ovary", "Endometrium", "Cervix")),
    ("OGS", ("OGS_spine", "OGS_pelvis", "OGS_others")),
)
HCC_LIVER_FEATURES = ("Cirrhosis", "Portosystemic collateral vessel", "Ascites")
HCC_CHARACTERISTICS = (
    "Typical enhancement pattern (hypervascular enhancement and early wash-out)",
    "Peripheral capsule",
    "Mosaic Pattern: heterogenous enhancement",
    "Presence of Fat on MRI",
    "Water restricted diffusion on MRI",
    "Vascular invasion",
    "Portal vein thrombosis",
    "Extrahepatic spread",
)


def _decode_value(value: dict[str, Any]) -> Any:
    for key in ("stringValue", "booleanValue", "integerValue", "doubleValue"):
        if key in value:
            return value[key]
    if "nullValue" in value:
        return None
    if "arrayValue" in value:
        return [_decode_value(v) for v in value["arrayValue"].get("values", [])]
    if "mapValue" in value:
        return {
            key: _decode_value(item)
            for key, item in value["mapValue"].get("fields", {}).items()
        }
    raise ValueError(f"Unsupported Firestore value: {value}")


def _decode_document(document: dict[str, Any]) -> dict[str, Any]:
    decoded = {
        key: _decode_value(value)
        for key, value in document.get("fields", {}).items()
    }
    decoded["id"] = document["name"].rsplit("/", 1)[-1]
    decoded["create_time"] = document.get("createTime", "")
    decoded["update_time"] = document.get("updateTime", "")
    return decoded


def _canonical_sha(payload: Any) -> str:
    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class StageResult:
    tnm: str
    lookup_key: str
    stage: str
    matching_stages: tuple[str, ...]

    @property
    def has_conflict(self) -> bool:
        return len(set(self.matching_stages)) > 1


class CancerCatalog:
    def __init__(self, snapshot: dict[str, Any]):
        self.snapshot = snapshot
        self.documents = {
            document["id"]: document for document in snapshot.get("documents", [])
        }

    @property
    def sha256(self) -> str:
        return self.snapshot.get("sha256") or _canonical_sha(
            self.snapshot.get("documents", [])
        )

    @property
    def fetched_at(self) -> str:
        return self.snapshot.get("fetched_at", "")

    def get(self, cancer_id: str) -> dict[str, Any] | None:
        return self.documents.get(cancer_id)

    def conflicts(self, cancer_id: str) -> dict[str, list[str]]:
        cancer = self.documents[cancer_id]
        stages_by_tnm: dict[str, list[str]] = {}
        for row in cancer.get("Staging", []):
            for tnm in row.get("TNM", []):
                stages_by_tnm.setdefault(tnm, []).append(row.get("stage", "N/A"))
        return {
            tnm: stages
            for tnm, stages in stages_by_tnm.items()
            if len(set(stages)) > 1
        }

    def resolve_stage(self, cancer_id: str, t: str, n: str, m: str) -> StageResult:
        """Mirror the deployed website's lookup and first-match behavior."""
        cancer = self.documents[cancer_id]
        all_keys = [
            tnm
            for row in cancer.get("Staging", [])
            for tnm in row.get("TNM", [])
        ]
        staging_string = ",".join(all_keys)
        full_tnm = f"{t}{n}{m}"

        if m and m in staging_string:
            lookup_key = m
        elif m and m[:2] in staging_string:
            lookup_key = m[:2]
        else:
            lookup_t = t if t and t in staging_string else t[:2]
            lookup_n = n if n and n in staging_string else n[:2]
            lookup_key = f"{lookup_t}{lookup_n}"

        matching = tuple(
            row.get("stage", "N/A")
            for row in cancer.get("Staging", [])
            if lookup_key in row.get("TNM", [])
        )
        return StageResult(full_tnm, lookup_key, matching[0] if matching else "N/A", matching)


def fetch_catalog(cache_path: Path = DEFAULT_CACHE) -> CancerCatalog:
    request = Request(CATALOG_URL, headers={"User-Agent": "cancer-staging-pipeline/1"})
    with urlopen(request, timeout=30) as response:  # noqa: S310 - fixed HTTPS URL
        raw = json.load(response)
    documents = [_decode_document(item) for item in raw.get("documents", [])]
    snapshot = {
        "source": "https://cancer-tnm.firebaseapp.com/",
        "firestore_collection": "cancer_type",
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "documents": documents,
    }
    snapshot["sha256"] = _canonical_sha(documents)
    cache_path.write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return CancerCatalog(snapshot)


def load_catalog(
    *, refresh: bool = False, cache_path: Path = DEFAULT_CACHE, corrected: bool = True
) -> CancerCatalog:
    """The cached website catalog, with the local AJCC corrections by default."""
    if refresh or not cache_path.exists():
        snapshot = fetch_catalog(cache_path).snapshot
    else:
        snapshot = json.loads(cache_path.read_text(encoding="utf-8"))
    if corrected:
        snapshot = catalog_corrections.apply(snapshot)
        snapshot["sha256"] = _canonical_sha(snapshot["documents"])
    return CancerCatalog(snapshot)


def format_study_date(value: str) -> str:
    value = (value or "").strip()
    for fmt in ("%Y/%m/%d", "%Y-%m-%d", "%Y.%m.%d", "%m/%d/%Y"):
        try:
            return datetime.strptime(value, fmt).strftime("%m/%d/%Y")
        except ValueError:
            continue
    return value


def render_staging_text(
    cancer: dict[str, Any],
    *,
    study_date: str,
    modality: str,
    t: str,
    n: str,
    m: str,
    stage: str,
    t_location: str = "",
    n_location: str = "",
    m_location: str = "",
    other_findings: str = "N/A",
) -> str:
    """Render the general staging block emitted by the deployed website."""
    name = cancer.get("name", cancer.get("id", ""))
    lines = [
        "===========================================",
        f"Tumor Stage: {name}",
        f"Study Date: {format_study_date(study_date)}",
        f"Imaging Modality: {modality}",
        "===========================================",
        f"1. Tumor invasion: {t}:{cancer.get('T', {}).get(t, '')}",
    ]
    if t_location:
        lines.append(f"@  Location: {t_location}")
    lines.extend(["", f"2. LAP: {n}:{cancer.get('N', {}).get(n, '')}"])
    if n_location:
        lines.append(f"@  Location: {n_location}")
    lines.extend(["", f"3. Metastasis: {m}:{cancer.get('M', {}).get(m, '')}"])
    if m_location:
        lines.append(f"@  Location: {m_location}")
    lines.extend(
        [
            "",
            "Other Findings:",
            other_findings or "N/A",
            "**************************************",
            f"{name} Cancer Staging:",
            f"{t}{n}{m} (Staging: {stage})",
            "**************************************",
        ]
    )
    return "\n".join(lines)


def _site_join(value: Any) -> str:
    """JS template literals render arrays as comma-joined text without spaces."""
    if isinstance(value, (list, tuple)):
        return ",".join(str(item) for item in value)
    return str(value or "")


def render_site_report(
    cancer: dict[str, Any], form: dict[str, Any], *, stage: str
) -> str:
    """Port of the website's generateReport() for app-report and app-report-HCC.

    ``form`` uses the website's form-control names (date, method, T, T_RL,
    T_location, N, N_location, N_location_R, N_location_L, M, M_location, and
    for HCC: liver, characters, number). The website's leading newline and
    trailing "\\n  " are dropped; the RIS append strips them anyway.
    """
    name = cancer.get("name", cancer.get("id", ""))
    t, n, m = form.get("T", ""), form.get("N", ""), form.get("M", "")
    date = format_study_date(form.get("date", ""))
    text = (
        "===========================================\n"
        f"Tumor Stage: {name}\n"
        f"Study Date: {date}\n"
        f"Imaging Modality: {form.get('method', '')}\n"
        "===========================================\n"
    )
    t_location = form.get("T_location")
    if cancer.get("id") == "HCC":
        liver = form.get("liver") or []
        text += "Associated Liver Features: \n"
        text += (
            "\n".join(f"> {item}" for item in liver) + "\n\n"
            if liver
            else "No special finding\n\n"
        )
        text += f"1. Tumor invasion: {t}:{cancer.get('T', {}).get(t, '')}\n"
        text += "@  Tumor characteristics: \n"
        characters = form.get("characters") or []
        text += (
            "\n".join(f"> {item}" for item in characters) + "\n\n"
            if characters
            else "No specific characteristic\n"
        )
        number = str(form.get("number") or "")
        if number and number != "0":
            text += f"@  Number: {number}\n"
        if t_location:
            text += f"@  Location: {_site_join(t_location)}\n"
        text += f"\n2. LAP: {n}:{cancer.get('N', {}).get(n, '')}\n"
    else:
        text += f"1. Tumor invasion: {t}:{cancer.get('T', {}).get(t, '')}\n"
        if cancer.get("T_RL"):
            if form.get("T_RL") and t_location:
                text += f"@  Location: {form['T_RL']} {_site_join(t_location)}\n"
        elif t_location:
            text += f"@  Location: {_site_join(t_location)}\n"
        text += f"\n2. LAP: {n}:{cancer.get('N', {}).get(n, '')}\n"
        if cancer.get("N_RL"):
            sides = []
            if form.get("N_location_R"):
                sides.append(f"Rt level {_site_join(form['N_location_R'])}")
            if form.get("N_location_L"):
                sides.append(f"Lt level {_site_join(form['N_location_L'])}")
            if sides:
                text += f"@  Location: {' & '.join(sides)}\n"
        elif form.get("N_location"):
            text += f"@  Location: {_site_join(form['N_location'])}\n"
    text += f"\n3. Metastasis: {m}:{cancer.get('M', {}).get(m, '')}\n"
    if form.get("M_location"):
        text += f"@  Location: {_site_join(form['M_location'])}\n"
    text += (
        "\nOther Findings:\nN/A\n"
        "**************************************\n"
        f"{name} Cancer Staging:\n"
        f"{t}{n}{m} (Staging: {stage})\n"
        "**************************************"
    )
    return text


def text_sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()
