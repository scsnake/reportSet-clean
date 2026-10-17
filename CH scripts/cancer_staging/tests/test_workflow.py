from __future__ import annotations

from pathlib import Path

import pytest

from tnm_catalog import CancerCatalog, render_staging_text, text_sha256
from workflow import (
    approve_case,
    approved_cases,
    import_tsv_text,
    prepare_review,
    set_case_tnm,
    update_case_staging_text,
)


@pytest.fixture
def catalog() -> CancerCatalog:
    return CancerCatalog(
        {
            "source": "test",
            "fetched_at": "2026-09-28T00:00:00+00:00",
            "sha256": "catalog-test",
            "documents": [
                {
                    "id": "Colorectum",
                    "name": "Colon and Rectum Cancer",
                    "update_time": "2022-07-27T08:40:27.040313Z",
                    "T": {
                        "Tx": "Primary tumor cannot be assessed",
                        "T1/2": "Colonic or rectal wall",
                    },
                    "N": {"N0": "No or Equivocal", "N2a": "4-6 regional LNs"},
                    "M": {"M0": "No distal metastasis", "M1a": "One organ"},
                    "Staging": [
                        {"stage": "I", "TNM": ["T1/2N0"]},
                        {"stage": "IIIA", "TNM": ["T1/2N2a"]},
                        {"stage": "IIIB", "TNM": ["T1/2N2a"]},
                        {"stage": "IVA", "TNM": ["M1a"]},
                    ],
                }
            ],
        }
    )


@pytest.fixture
def clinical_catalog() -> CancerCatalog:
    return CancerCatalog(
        {
            "source": "test",
            "fetched_at": "2026-09-28T00:00:00+00:00",
            "sha256": "clinical-test",
            "documents": [
                {
                    "id": "HCC",
                    "name": "HCC",
                    "T": {"Tx": "Unknown", "T3": "Multiple, one >5 cm", "T4": "Major portal branch"},
                    "N": {"N0": "No or Equivocal"},
                    "M": {"M0": "No distal metastasis"},
                    "Staging": [
                        {"stage": "IIIA", "TNM": ["T3N0"]},
                        {"stage": "IIIB", "TNM": ["T4N0"]},
                    ],
                },
                {
                    "id": "Lip_Oral_Cavity",
                    "name": "Lip & Oral Cavity Cancer",
                    "T": {"Tx": "Unknown", "T1": "Small/limited DOI"},
                    "N": {"N0": "No or Equivocal", "N2b": "Multiple ipsilateral nodes"},
                    "M": {"M0": "No distal metastasis"},
                    "Staging": [{"stage": "IVA", "TNM": ["T1N2"]}],
                },
            ],
        }
    )


SAMPLE_TSV = '''申請單號\t院內病歷號碼\t攝影名稱\t攝影日期\t報告日期\t覆審醫師\t報告內容\t病理報告\t臨床診斷\t癌別\t完成\t備註\t備註2\t備註3
99900000001\t1234567\tWHOLE ABDOMEN CT (有&無造影劑)\t2026/07/15\t2026/07/21\t陳醫師\t"CT shows:
- Suspect eccentric wall thickening at cecum to ascending colon.
- No definite abdominal lymphadenopathy.

Impression:
Suspect wall thickening."\tCecum, biopsy --- Adenocarcinoma.\t\t\t待修正\t癌委會:結腸癌\t\t修
'''


def test_imports_multiline_tsv_and_header_aliases() -> None:
    rows = import_tsv_text(SAMPLE_TSV, doctor="陳醫師")
    assert len(rows) == 1
    assert rows[0]["accession"] == "99900000001"
    assert rows[0]["review_doctor"] == "陳醫師"
    assert "\n- No definite" in rows[0]["report_txt"]


def test_prepare_separates_evidence_and_assumptions(catalog: CancerCatalog) -> None:
    row = import_tsv_text(SAMPLE_TSV)[0]
    review = prepare_review([row], catalog)
    proposal = review["cases"][0]["proposal"]
    assert proposal["catalog_id"] == "Colorectum"
    assert (proposal["t"], proposal["n"], proposal["m"]) == ("Tx", "N0", "M0")
    assert "No definite abdominal lymphadenopathy" in proposal["evidence"]["N"]
    assert any("M0 is assumed" in item for item in proposal["assumptions"])
    assert "TxN0M0 (Staging: N/A)" in proposal["staging_text"]
    assert review["cases"][0]["approval"]["state"] == "pending"


def test_site_first_match_and_conflict_are_both_retained(catalog: CancerCatalog) -> None:
    result = catalog.resolve_stage("Colorectum", "T1/2", "N2a", "M0")
    assert result.stage == "IIIA"
    assert result.matching_stages == ("IIIA", "IIIB")
    assert result.has_conflict


def test_render_matches_website_general_format(catalog: CancerCatalog) -> None:
    cancer = catalog.documents["Colorectum"]
    text = render_staging_text(
        cancer,
        study_date="2026/07/15",
        modality="CT",
        t="Tx",
        n="N0",
        m="M0",
        stage="N/A",
        t_location="cecum",
    )
    assert text.startswith("===========================================\nTumor Stage:")
    assert "Study Date: 07/15/2026" in text
    assert "1. Tumor invasion: Tx:Primary tumor cannot be assessed" in text
    assert text.endswith("**************************************")


def test_approval_uses_exact_hash_and_tnm_edit_invalidates(catalog: CancerCatalog) -> None:
    review = prepare_review([import_tsv_text(SAMPLE_TSV)[0]], catalog)
    case = review["cases"][0]
    sha = case["proposal"]["text_sha256"]
    approve_case(review, "99900000001", sha)
    assert approved_cases(review) == [case]

    set_case_tnm(
        review,
        catalog,
        "99900000001",
        t="T1/2",
        n="N0",
        m="M0",
    )
    assert case["approval"]["state"] == "pending"
    assert approved_cases(review) == []


def test_approval_rejects_wrong_hash(catalog: CancerCatalog) -> None:
    review = prepare_review([import_tsv_text(SAMPLE_TSV)[0]], catalog)
    with pytest.raises(ValueError, match="Text SHA mismatch"):
        approve_case(review, "99900000001", text_sha256("different"))


def test_manual_text_edit_updates_hash_and_invalidates_approval(
    catalog: CancerCatalog,
) -> None:
    review = prepare_review([import_tsv_text(SAMPLE_TSV)[0]], catalog)
    case = review["cases"][0]
    original_sha = case["proposal"]["text_sha256"]
    approve_case(review, "99900000001", original_sha)

    updated = update_case_staging_text(
        review,
        "99900000001",
        staging_text=case["proposal"]["staging_text"] + "\nReviewed edit.",
        expected_sha256=original_sha,
    )

    assert updated["approval"]["state"] == "pending"
    assert updated["proposal"]["manually_edited"] is True
    assert updated["proposal"]["text_sha256"] != original_sha
    assert approved_cases(review) == []


def test_manual_text_edit_rejects_stale_sha(catalog: CancerCatalog) -> None:
    review = prepare_review([import_tsv_text(SAMPLE_TSV)[0]], catalog)
    with pytest.raises(ValueError, match="Text SHA mismatch"):
        update_case_staging_text(
            review,
            "99900000001",
            staging_text="Changed",
            expected_sha256=text_sha256("stale"),
        )


def test_hcc_multiple_large_tumors_propose_t3_with_t4_warning(
    clinical_catalog: CancerCatalog,
) -> None:
    row = {
        "accession": "99900000002",
        "chart_no": "0000002",
        "study_name": "ABDOMEN MRI",
        "study_date": "2026/01/03",
        "report_txt": (
            "Multiple tumors in right lobe of liver, up to 96mm. "
            "Small para-aortic lymph nodes. Suspect right portal vein thrombosis."
        ),
        "patho_txt": "Hepatocellular carcinoma.",
        "dx_txt": "",
        "notes_txt": "癌委會:肝癌",
        "notes2_txt": "",
        "notes3_txt": "",
        "cancer_type_existing": "",
    }
    proposal = prepare_review([row], clinical_catalog)["cases"][0]["proposal"]
    assert (proposal["t"], proposal["n"], proposal["m"]) == ("T3", "N0", "M0")
    assert proposal["stage"] == "IIIA"
    assert any("Potential T4 alternative" in warning for warning in proposal["warnings"])


def test_explicit_pathologic_tn_overrides_imaging_node_size(
    clinical_catalog: CancerCatalog,
) -> None:
    row = {
        "accession": "99900000003",
        "chart_no": "0000003",
        "study_name": "NECK MRI",
        "study_date": "2026/01/04",
        "report_txt": "19mm left submandibular mass. Small lymph nodes in bilateral neck.",
        "patho_txt": "Left upper buccogingival SCC. Staging: (pT1N2b).",
        "dx_txt": "",
        "notes_txt": "癌委會:口腔癌",
        "notes2_txt": "",
        "notes3_txt": "",
        "cancer_type_existing": "",
    }
    proposal = prepare_review([row], clinical_catalog)["cases"][0]["proposal"]
    assert (proposal["t"], proposal["n"], proposal["m"]) == ("T1", "N2b", "M0")
    assert proposal["stage"] == "IVA"
    assert proposal["evidence"]["T"] == "Pathology staging: pT1N2b"
    assert any("M0 is assumed" in item for item in proposal["assumptions"])
