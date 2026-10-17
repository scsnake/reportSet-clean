"""The local AJCC corrections, checked against the cached website snapshot."""

from __future__ import annotations

import pytest

import catalog_corrections
import local_llm
import workflow
from tnm_catalog import DEFAULT_CACHE, CancerCatalog, load_catalog

# The snapshot is gitignored; without it `load_catalog` would fetch from the website.
pytestmark = pytest.mark.skipif(
    not DEFAULT_CACHE.exists(), reason="needs catalog_cache.json (uv run python main.py sync-catalog)"
)


@pytest.fixture(scope="module")
def catalog() -> CancerCatalog:
    return load_catalog()


@pytest.fixture(scope="module")
def website() -> CancerCatalog:
    return load_catalog(corrected=False)


def _stage(catalog: CancerCatalog, cancer: str, t: str, n: str, m: str = "M0") -> tuple[str, list[str]]:
    result = catalog.resolve_stage(cancer, t, n, m)
    return result.stage, list(dict.fromkeys(result.matching_stages))


def test_website_snapshot_is_not_changed(catalog, website) -> None:
    assert website.documents["Lung"]["M"]["M0"] == "No distal metastasis"
    assert _stage(website, "Lung", "T1b", "N0") == ("IA", ["IA"])
    assert "corrected" not in website.documents["Lung"]
    assert catalog.snapshot["website_sha256"] == website.sha256 != catalog.sha256
    assert all(cancer["M"]["M0"] == "No distant metastasis" for cancer in catalog.documents.values())


def test_reviewed_templates_are_the_ones_in_the_snapshot(website) -> None:
    """A failure here means the website changed a corrected template: review its correction."""
    assert catalog_corrections.stale(website.snapshot) == []
    assert set(catalog_corrections.REVIEWED) == set(catalog_corrections.CORRECTIONS)


@pytest.mark.parametrize(
    ("cancer", "t", "n", "m", "expected"),
    [
        ("Lung", "T1a", "N0", "M0", ("IA1", ["IA1"])),
        ("Lung", "T1b", "N0", "M0", ("IA2", ["IA2"])),
        ("Lung", "T1c", "N1", "M0", ("IIA", ["IIA"])),
        ("Lung", "T1a", "N2a", "M0", ("IIB", ["IIB"])),
        ("Lung", "T2b", "N2b", "M0", ("IIIB", ["IIIB"])),
        ("Lung", "T3", "N2a", "M0", ("IIIA", ["IIIA"])),
        ("Lung", "T4", "N3", "M0", ("IIIC", ["IIIC"])),
        ("Lung", "T2a", "N0", "M1c1", ("IVB", ["IVB"])),
        ("GIST", "T3", "N0", "M0", ("IB", ["IB", "II", "IIIA", "IIIB"])),
        ("GIST", "T4", "N0", "M0", ("II", ["II", "IIIA", "IIIB"])),
        ("GIST", "T2", "N1", "M0", ("IV", ["IV"])),
        ("GIST", "T1", "N0", "M1", ("IV", ["IV"])),
        ("Prostate", "T1c", "N0", "M0", ("I", ["I", "IIA", "IIB", "IIC", "IIIA", "IIIC"])),
        ("Prostate", "T2c", "N0", "M0", ("IIA", ["IIA", "IIB", "IIC", "IIIA", "IIIC"])),
        ("Prostate", "T3a", "N0", "M0", ("IIIB", ["IIIB", "IIIC"])),
        ("Prostate", "T2a", "N1", "M0", ("IVA", ["IVA"])),
        ("Prostate", "T3b", "N0", "M1b", ("IVB", ["IVB"])),
        ("Endometrium", "T3a", "N1", "M0", ("IIIC1", ["IIIC1"])),
        ("Endometrium", "T3b", "N0", "M0", ("IIIB", ["IIIB"])),
        ("Ovary", "T3b", "N1", "M0", ("IIIB", ["IIIB"])),
        ("Ovary", "T3a", "N1", "M0", ("IIIA2", ["IIIA2"])),
        ("Cervix", "T1a", "N2", "M0", ("IIIC2", ["IIIC2"])),
        ("Esophagus", "T3", "N0", "M0", ("II", ["II", "III"])),
        ("Esophagus", "T4a", "N1", "M0", ("IVA", ["IVA", "III"])),
        ("Esophagus", "T3", "N1", "M0", ("III", ["III"])),
        ("OGS_others", "T2", "N0", "M0", ("IIB", ["IIB", "IB"])),
        ("OGS_others", "T1", "N1", "M0", ("IVB", ["IVB"])),
        ("OGS_spine", "T2", "N0", "M0", ("N/A", [])),
        ("OGS_pelvis", "T1", "N0", "M1a", ("N/A", [])),
        ("Urinary_bladder", "T4a", "N0", "M0", ("IIIA", ["IIIA"])),
        ("Oropharynx_P16+", "T2", "N3", "M0", ("III", ["III"])),
    ],
)
def test_corrected_stage_groups(catalog, cancer, t, n, m, expected) -> None:
    assert _stage(catalog, cancer, t, n, m) == expected


def test_stage_keys_of_rewritten_tables_use_template_codes(catalog) -> None:
    for cancer_id in ("Lung", "GIST", "Prostate", "Endometrium", "Ovary", "Esophagus", "OGS_others"):
        cancer = catalog.documents[cancer_id]
        allowed = {f"{t}{n}" for t in cancer["T"] for n in cancer["N"]} | set(cancer["M"])
        keys = [key for row in cancer["Staging"] for key in row["TNM"]]
        assert set(keys) <= allowed, (cancer_id, sorted(set(keys) - allowed))


def test_every_m0_combination_of_rewritten_tables_has_a_stage(catalog) -> None:
    for cancer_id in ("Lung", "GIST", "Prostate", "OGS_others"):
        cancer = catalog.documents[cancer_id]
        for t in cancer["T"]:
            for n in cancer["N"]:
                if t in ("Tx", "T0"):
                    continue
                assert _stage(catalog, cancer_id, t, n)[0] != "N/A", (cancer_id, t, n)


def test_a_stage_choice_always_has_a_rule(catalog) -> None:
    """Corrected templates with more than one group for a TNM say how to choose."""
    for cancer_id in catalog_corrections.CORRECTIONS:
        if catalog.conflicts(cancer_id):
            assert catalog.documents[cancer_id].get("Staging_note"), cancer_id


def test_definitions_and_location_lists(catalog) -> None:
    docs = catalog.documents
    assert "T4" not in docs["Urinary_bladder"]["T"] and "seminal vesicles" in docs["Urinary_bladder"]["T"]["T4a"]
    assert docs["Pancreas"]["T"]["T1"].startswith("Tumor ≤2 cm")
    assert docs["RCC"]["T"]["T1"].startswith("Tumor ≤ 7 cm")
    assert "esophageal muscle" in docs["Hypopharynx"]["T"]["T4a"]
    assert "cricoid or thyroid cartilage" in docs["Subglottis"]["T"]["T4a"]
    assert "nonadjacent" in docs["OGS_spine"]["T"]["T3"]
    assert "> 4 cm with DOI > 10 mm" in docs["Lip_Oral_Cavity"]["T"]["T4a"]
    assert "extranodal extension" in docs["Oropharynx_P16+"]["N"]["N2"]
    assert docs["Lung"]["N"]["N2a"].startswith("Single N2 station")
    assert docs["Prostate"]["N_location"] == ["External iliac", "Internal iliac", "Obturator", "Sacral"]
    assert "common iliac lymph nodes" in docs["Prostate"]["M_location"]
    for cancer_id in ("Ovary", "Endometrium"):
        assert "Para-aortic" in docs[cancer_id]["N_location"] and "Inguinal" not in docs[cancer_id]["N_location"]
    assert "Middle colic artery" not in docs["Stomach"]["N_location"] and "Middle colic" in docs["Stomach"]["M_location"]
    assert docs["Intrahepatic_bil_duct"]["N_location"].count("hilar") == 1
    assert "S8" in docs["Intrahepatic_bil_duct"]["T_location"]


ROW = {"accession": "1", "chart_no": "2", "study_name": "ABDOMEN CT (有&無造影劑)", "report_txt": "x"}


def test_stage_choice_and_review_note_reach_the_proposal(catalog) -> None:
    entry = {"cancer": "GIST", "T": "T3", "N": "N0", "M": "M0"}
    with pytest.raises(ValueError, match="must choose one"):
        workflow.prepare_case_from_proposal(ROW, entry, catalog)
    proposal = workflow.prepare_case_from_proposal(ROW, {**entry, "stage": "IIIA"}, catalog)["proposal"]
    assert proposal["stage"] == "IIIA" and "T3N0M0 (Staging: IIIA)" in proposal["staging_text"]
    assert any("mitotic rate" in warning and "default: IB" in warning for warning in proposal["warnings"])

    spine = workflow.prepare_case_from_proposal(
        ROW, {"cancer": "OGS_spine", "T": "T2", "N": "N0", "M": "M0"}, catalog)["proposal"]
    assert spine["stage"] == "N/A" and any("no stage groups" in warning for warning in spine["warnings"])


def test_model_gets_the_stage_rule_only_where_one_exists(catalog) -> None:
    assert "Stage group: For N0 M0 the stage group needs the PSA" in local_llm.template_block(catalog.documents["Prostate"])
    assert "Stage group:" not in local_llm.template_block(catalog.documents["Lung"])
