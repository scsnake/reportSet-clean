from __future__ import annotations

import pytest

from tnm_catalog import CancerCatalog
import workflow
from workflow import (
    approve_case,
    import_tsv_text,
    prepare_review,
    review_has_work,
    set_case_tnm,
    site_modality,
)


@pytest.fixture
def catalog() -> CancerCatalog:
    return CancerCatalog(
        {
            "source": "test",
            "fetched_at": "2026-09-28T00:00:00+00:00",
            "sha256": "proposal-test",
            "documents": [
                {
                    "id": "Lip_Oral_Cavity",
                    "name": "Lip & Oral Cavity Cancer",
                    "T_RL": True,
                    "N_RL": True,
                    "T": {"T4b": "Very advanced local disease", "Tx": "Unknown"},
                    "N": {"N0": "No or Equivocal", "N2b": "Multiple ipsilateral"},
                    "M": {"M0": "No distal metastasis", "M1": "Distant metastasis"},
                    "T_location": ["Retromolar trigone", "Oral tongue"],
                    "N_location": ["I", "II", "III"],
                    "M_location": ["lung", "bone"],
                    "Staging": [
                        {"stage": "IVB", "TNM": ["T4bN2"]},
                        {"stage": "IVC", "TNM": ["M1"]},
                    ],
                },
                {
                    "id": "HCC",
                    "name": "HCC",
                    "T_RL": False,
                    "N_RL": False,
                    "T": {"T2": "Solitary >2 cm with vascular invasion"},
                    "N": {"N0": "No or Equivocal"},
                    "M": {"M0": "No distal metastasis"},
                    "T_location": ["S2", "S3"],
                    "N_location": ["Hepatic hilum"],
                    "M_location": ["lung"],
                    "Staging": [{"stage": "II", "TNM": ["T2N0"]}],
                },
                {
                    "id": "Prostate",
                    "name": "Prostate Cancer",
                    "T_RL": False,
                    "N_RL": True,
                    "T": {"T2a": "One-half of one side or less"},
                    "N": {"N0": "No positive regional nodes"},
                    "M": {"M0": "No distal metastasis"},
                    "T_location": ["Left lobe"],
                    "N_location": ["Obturator"],
                    "M_location": ["bone"],
                    "Staging": [
                        {"stage": "IIA", "TNM": ["T2aN0"]},
                        {"stage": "IIIA", "TNM": ["T2aN0"]},
                    ],
                },
            ],
        }
    )


HEADERLESS = (
    '99900000011\t1000011\tNECK MRI (有造影劑)\t2026/06/25\t2026/07/10\t 陳醫師\t"MRI:\n'
    '- Right retromolar tumor.\n\nImpression:\nMalignancy."\tSCC\t\t\t待修正\t癌委會:口腔癌\n'
    "99900000012\t1000012\tABDOMEN MRI (有造影劑)\t2026/05/05\t2026/05/08\t陳醫師\t"
    "HCC at S2.\tHCC (staging: pT2)\t\t\t待修正\t\n"
    "99900000013\t1000013\tWHOLE ABDOMEN CT (有&無造影劑)\t2026/06/23\t2026/06/27\t陳醫師\t"
    "Enlarged prostate.\tTURP adenocarcinoma\t\t\t待修正\t\n"
)


def _rows():
    return import_tsv_text(HEADERLESS)


def _proposals(**overrides):
    cases = {
        "99900000011": {
            "cancer": "Lip_Oral_Cavity",
            "T": "T4b",
            "T_RL": "Right",
            "T_location": "Retromolar trigone",
            "N": "N2b",
            "N_location_R": ["I", "II", "III"],
            "M": "M0",
            "evidence": {"T": "Masticator space invasion"},
        },
        "99900000012": {
            "cancer": "HCC",
            "T": "T2",
            "N": "N0",
            "M": "M0",
            "liver": ["Cirrhosis"],
            "characters": [
                "Typical enhancement pattern (hypervascular enhancement and early wash-out)"
            ],
            "number": "1",
            "T_location": ["S2"],
        },
        "99900000013": {"skip": "TURP percentage not reported"},
    }
    cases.update(overrides)
    return {"generated_by": "test", "generated_at": "2026-09-28", "cases": cases}


def test_headerless_paste_uses_sheet_column_order() -> None:
    rows = _rows()
    assert [row["accession"] for row in rows] == [
        "99900000011",
        "99900000012",
        "99900000013",
    ]
    assert rows[0]["chart_no"] == "1000011"
    assert rows[0]["review_doctor"] == "陳醫師"
    assert rows[0]["notes_txt"] == "癌委會:口腔癌"
    assert "\n- Right retromolar" in rows[0]["report_txt"]
    assert rows[0]["input_row"] == 1


def test_site_modality_follows_contrast_suffix() -> None:
    assert site_modality("NECK MRI (有造影劑)") == "MRI with contrast"
    assert site_modality("WHOLE ABDOMEN CT (有&無造影劑)") == "CT with contrast"
    assert site_modality("WHOLE ABDOMEN CT (無造影劑)") == "CT without contrast"
    assert site_modality("PET SCAN") == ""
    assert site_modality("ABD MRCP (有造影劑)") == "MRI with contrast"


def test_general_form_renders_website_sides_and_levels(catalog) -> None:
    review = prepare_review(_rows(), catalog, _proposals())
    text = review["cases"][0]["proposal"]["staging_text"]
    assert text == (
        "===========================================\n"
        "Tumor Stage: Lip & Oral Cavity Cancer\n"
        "Study Date: \n"
        "Imaging Modality: MRI with contrast\n"
        "===========================================\n"
        "1. Tumor invasion: T4b:Very advanced local disease\n"
        "@  Location: Right Retromolar trigone\n"
        "\n"
        "2. LAP: N2b:Multiple ipsilateral\n"
        "@  Location: Rt level I,II,III\n"
        "\n"
        "3. Metastasis: M0:No distal metastasis\n"
        "\n"
        "Other Findings:\n"
        "N/A\n"
        "**************************************\n"
        "Lip & Oral Cavity Cancer Cancer Staging:\n"
        "T4bN2bM0 (Staging: IVB)\n"
        "**************************************"
    )
    assert review["cases"][0]["proposal"]["origin"] == "llm"


def test_hcc_form_renders_website_hcc_template(catalog) -> None:
    review = prepare_review(_rows(), catalog, _proposals())
    text = review["cases"][1]["proposal"]["staging_text"]
    assert text == (
        "===========================================\n"
        "Tumor Stage: HCC\n"
        "Study Date: \n"
        "Imaging Modality: MRI with contrast\n"
        "===========================================\n"
        "Associated Liver Features: \n"
        "> Cirrhosis\n"
        "\n"
        "1. Tumor invasion: T2:Solitary >2 cm with vascular invasion\n"
        "@  Tumor characteristics: \n"
        "> Typical enhancement pattern (hypervascular enhancement and early wash-out)\n"
        "\n"
        "@  Number: 1\n"
        "@  Location: S2\n"
        "\n"
        "2. LAP: N0:No or Equivocal\n"
        "\n"
        "3. Metastasis: M0:No distal metastasis\n"
        "\n"
        "Other Findings:\n"
        "N/A\n"
        "**************************************\n"
        "HCC Cancer Staging:\n"
        "T2N0M0 (Staging: II)\n"
        "**************************************"
    )


def test_skip_entry_leaves_text_empty_with_reason(catalog) -> None:
    case = prepare_review(_rows(), catalog, _proposals())["cases"][2]
    assert case["proposal"]["staging_text"] == ""
    assert case["proposal"]["skip_reason"] == "TURP percentage not reported"
    assert case["proposal"]["warnings"][0].startswith("No staging proposed")


@pytest.mark.parametrize(
    "override, message",
    [
        ({"N": "N9"}, "N='N9'"),
        ({"T_location": "Hard palate"}, "T_location"),
        ({"N_location": ["I"]}, "N_location_R"),
        ({"M_location": ["lung"]}, "disabled"),
        ({"modality": "PET"}, "modality"),
        ({"stage": "IVB"}, "conflict"),
        ({"surprise": 1}, "Unknown proposal field"),
    ],
)
def test_proposal_rejects_values_the_website_cannot_produce(
    catalog, override, message
) -> None:
    entry = {**_proposals()["cases"]["99900000011"], **override}
    with pytest.raises(ValueError, match=message):
        prepare_review(_rows(), catalog, _proposals(**{"99900000011": entry}))


def test_proposals_must_match_imported_rows(catalog) -> None:
    proposals = _proposals()
    del proposals["cases"]["99900000013"]
    with pytest.raises(ValueError, match="missing"):
        prepare_review(_rows(), catalog, proposals)


def test_catalog_conflict_needs_explicit_stage_then_allows_approval(catalog) -> None:
    rows = _rows()[2:]
    entry = {"cancer": "Prostate", "T": "T2a", "N": "N0", "M": "M0"}
    with pytest.raises(ValueError, match="must choose one"):
        prepare_review(rows, catalog, {"cases": {"99900000013": entry}})

    review = prepare_review(
        rows, catalog, {"cases": {"99900000013": {**entry, "stage": "IIA"}}}
    )
    proposal = review["cases"][0]["proposal"]
    assert proposal["stage_resolution"] == {"chosen": "IIA", "candidates": ["IIA", "IIIA"]}
    assert any("conflict" in warning for warning in proposal["warnings"])
    assert "T2aN0M0 (Staging: IIA)" in proposal["staging_text"]
    approve_case(review, "99900000013", proposal["text_sha256"])
    assert review["cases"][0]["approval"]["state"] == "approved"


def test_set_tnm_rerenders_llm_case_with_site_template(catalog) -> None:
    review = prepare_review(_rows(), catalog, _proposals())
    case = set_case_tnm(review, catalog, "99900000011", t="Tx", n="N0", m="M1")
    text = case["proposal"]["staging_text"]
    assert "@  Location: Right Retromolar trigone" in text
    assert "TxN0M1 (Staging: IVC)" in text
    assert case["approval"]["state"] == "pending"


def test_review_has_work_detects_edits_approvals_and_results(catalog) -> None:
    review = prepare_review(_rows(), catalog, _proposals())
    assert not review_has_work(review)
    review["cases"][0]["execution"] = {"status": "ok"}
    assert review_has_work(review)


def test_render_form_matches_proposal_rendering_and_resolves_conflicts(catalog) -> None:
    row = _rows()[2]
    rendered = workflow.render_form(row, catalog, {"cancer": "Prostate", "T": "T2a", "N": "N0", "M": "M0"})
    assert rendered["candidates"] == ["IIA", "IIIA"] and rendered["stage"] == "IIA"
    assert rendered["form"]["method"] == "CT with contrast" and rendered["form"]["date"] == ""
    chosen = workflow.render_form(row, catalog, {"cancer": "Prostate", "T": "T2a", "N": "N0", "M": "M0", "stage": "IIIA"})
    assert "T2aN0M0 (Staging: IIIA)" in chosen["text"]
    with pytest.raises(ValueError, match="website option"):
        workflow.render_form(row, catalog, {"cancer": "Prostate", "T": "T9", "N": "N0", "M": "M0"})


def test_set_case_form_updates_digest_text_and_resets_approval(catalog) -> None:
    review = prepare_review(_rows(), catalog, _proposals())
    case = review["cases"][0]
    approve_case(review, "99900000011", case["proposal"]["text_sha256"])
    entry = {"cancer": "Lip_Oral_Cavity", "T": "T4b", "T_RL": "Right", "T_location": "Oral tongue",
             "N": "N0", "M": "M1", "M_location": ["lung"]}
    rendered = workflow.render_form(case["source"], catalog, entry)
    tweaked = rendered["text"].replace("N/A", "Hand note")
    with pytest.raises(ValueError, match="SHA mismatch"):
        workflow.set_case_form(review, catalog, "99900000011", entry=entry, expected_sha256="stale")
    workflow.set_case_form(
        review, catalog, "99900000011", entry=entry,
        expected_sha256=case["proposal"]["text_sha256"], staging_text=tweaked,
    )
    proposal = case["proposal"]
    assert (proposal["t"], proposal["n"], proposal["m"], proposal["stage"]) == ("T4b", "N0", "M1", "IVC")
    assert proposal["staging_text"] == tweaked and proposal["manually_edited"]
    assert proposal["site_form"]["M_location"] == ["lung"]
    assert case["approval"]["state"] == "pending"


def test_set_case_form_fills_a_skipped_case(catalog) -> None:
    review = prepare_review(_rows(), catalog, _proposals())
    skipped = review["cases"][2]
    workflow.set_case_form(
        review, catalog, "99900000013",
        entry={"cancer": "Prostate", "T": "T2a", "N": "N0", "M": "M0"}, expected_sha256="",
    )
    assert skipped["proposal"]["catalog_id"] == "Prostate" and "skip_reason" not in skipped["proposal"]
    assert skipped["proposal"]["stage_resolution"]["chosen"] == "IIA"
    approve_case(review, "99900000013", skipped["proposal"]["text_sha256"])


def test_catalog_choices_lists_website_options(catalog) -> None:
    choices = workflow.catalog_choices(catalog)
    # Website menu order (H & N before GI before GU), not alphabetical.
    assert [(c["group"], c["id"]) for c in choices["cancers"]] == [
        ("H & N", "Lip_Oral_Cavity"), ("GI", "HCC"), ("GU", "Prostate"),
    ]
    assert choices["cancers"][0]["T_RL"] is True and "Retromolar trigone" in choices["cancers"][0]["T_location"]
    assert "MRI with contrast" in choices["modalities"]


def test_site_menu_covers_the_whole_live_catalog() -> None:
    from pathlib import Path

    from tnm_catalog import SITE_CANCER_MENU, load_catalog

    cache = Path(__file__).resolve().parent.parent / "catalog_cache.json"
    if not cache.exists():
        pytest.skip("catalog cache not downloaded")
    listed = [cancer_id for _, ids in SITE_CANCER_MENU for cancer_id in ids]
    assert sorted(listed) == sorted(load_catalog(cache_path=cache).documents)
