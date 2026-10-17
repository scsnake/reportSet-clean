from __future__ import annotations

import pytest

from classify import classify, has_definite_cancer


def _row(**columns: str) -> dict[str, str]:
    return {"report_txt": "", "patho_txt": "", "dx_txt": "", "notes_txt": "", **columns}


def test_pathology_cancer_wins_when_imaging_never_mentions_the_primary() -> None:
    row = _row(
        report_txt="Tiny nodules in bilateral lower lungs. Mild gastric wall thickening.",
        patho_txt="Prostate, RALRP --- Adenocarcinoma, Gleason 4+3, staging (pT3aN0).",
    )
    guess = classify(row)
    assert (guess.cancer_type, guess.matched_column) == ("Prostate", "patho_txt")


def test_benign_pathology_does_not_pick_the_template() -> None:
    row = _row(
        patho_txt="Colon, polypectomy --- Tubular adenoma, benign; negative for malignancy.",
        notes_txt="癌委會:肝癌",
        report_txt="Hypervascular nodule at S2 of liver.",
    )
    assert classify(row).cancer_type == "HCC"
    assert classify(row).matched_column == "notes_txt"


def test_committee_note_outranks_incidental_report_findings() -> None:
    row = _row(report_txt="Tiny lung nodules. Suspect CBD stones.", notes_txt="癌委會新增/攝護腺癌")
    assert classify(row).cancer_type == "Prostate"


def test_report_is_used_only_without_definite_pathology() -> None:
    assert classify(_row(report_txt="Eccentric wall thickening at cecum.")).cancer_type == "Colorectal"
    definite_unmapped = _row(patho_txt="Parotid, core biopsy --- Carcinoma.", report_txt="Lung nodules.")
    assert classify(definite_unmapped).cancer_type == ""


@pytest.mark.parametrize(
    "text, expected",
    [
        ("Hepatocellular carcinoma (staging: pT2)", True),
        ("Neuroendocrine tumor, malignant, grade 1", True),
        ("Adenocarcinoma, Gleason grade 3+3", True),
        ("Squamous cell carcinoma", True),
        ("Benign prostatic hyperplasia", False),
        ("No evidence of malignancy", False),
        ("無", False),
        ("", False),
    ],
)
def test_definite_cancer_detection(text: str, expected: bool) -> None:
    assert has_definite_cancer(text) is expected
