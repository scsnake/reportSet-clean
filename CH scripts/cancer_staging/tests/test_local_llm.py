from __future__ import annotations

import json

import pytest

import batch
import local_llm
import trial_report
from tnm_catalog import CancerCatalog


@pytest.fixture
def catalog() -> CancerCatalog:
    return CancerCatalog(
        {
            "source": "test",
            "fetched_at": "2026-09-29T00:00:00+00:00",
            "sha256": "llm-test",
            "documents": [
                {
                    "id": "Prostate",
                    "name": "Prostate Cancer",
                    "T_RL": False,
                    "N_RL": True,
                    "T": {"Tx": "Unknown", "T2a": "One-half of one side or less", "T3b": "Seminal vesicle"},
                    "N": {"N0": "No positive regional nodes", "N1": "Regional nodes"},
                    "M": {"M0": "No distal metastasis", "M1b": "Bone(s)"},
                    "T_location": ["Right lobe", "Left lobe"],
                    "N_location": ["Obturator"],
                    "M_location": ["bone", "lung"],
                    "Staging": [
                        {"stage": "IIA", "TNM": ["T2aN0"]},
                        {"stage": "IIIA", "TNM": ["T2aN0"]},
                        {"stage": "IIIB", "TNM": ["T3bN0"]},
                        {"stage": "IVB", "TNM": ["M1b"]},
                    ],
                }
            ],
        }
    )


ROW = {
    "accession": "99900000014",
    "chart_no": "1000014",
    "study_name": "WHOLE ABDOMEN MRI (有造影劑)",
    "study_date": "2026/07/03",
    "report_txt": "T2 hypointense lesion in left lobe involving left seminal vesicle. Bone metastases.",
    "patho_txt": "Prostate, biopsy --- Adenocarcinoma, Gleason 4+4.",
    "dx_txt": "",
    "notes_txt": "癌委會:攝護腺癌",
}


def _fake(*replies: str):
    calls: list[list[dict[str, str]]] = []

    def generate(messages):
        calls.append(messages)
        return replies[len(calls) - 1]

    return generate, calls


def test_one_request_per_study_with_template_after_study(catalog) -> None:
    reply = json.dumps(
        {
            "T": "t3b",
            "T_location": ["Left lobe"],
            "N": "N0",
            "M": "M1b",
            "M_location": "bone",
            "evidence": {"T": "involving left seminal vesicle", "M": "Bone metastases."},
        }
    )
    generate, calls = _fake(reply)
    entry, log = local_llm.propose_case(generate, ROW, catalog, model_label="fake")
    assert log["status"] == "ok" and len(calls) == 1
    user = calls[0][-1]["content"]
    assert calls[0][0]["role"] == "system"
    assert user.index("Radiology report") < user.index("## TNM template") < user.index("## Output")
    assert "T3b: Seminal vesicle" in user
    assert (entry["cancer"], entry["T"], entry["M_location"]) == ("Prostate", "T3b", ["bone"])
    assert entry["T_location"] == "Left lobe"
    assert entry["warnings"][0] == "Draft by fake (local LLM trial)."
    assert any("string -> list" in fix for fix in log["attempts"][0]["fixes"])


def test_think_block_is_ignored_and_rejection_is_retried(catalog) -> None:
    bad = '<think>maybe {"T": "T9"}</think>{"T": "T2a", "N": "N0", "M": "M0"}'
    good = '{"T": "T2a", "N": "N0", "M": "M0", "stage": "IIA"}'
    generate, calls = _fake(bad, good)
    entry, log = local_llm.propose_case(generate, ROW, catalog, model_label="fake")
    assert log["status"] == "ok" and len(calls) == 2
    assert "more than one stage group: IIA, IIIA" in log["attempts"][0]["error"]
    assert calls[1][-1]["content"].startswith("That answer was rejected")
    assert calls[1][-2]["content"] == '{"T": "T2a", "N": "N0", "M": "M0"}'  # no think block resent
    assert entry["stage"] == "IIA"


def test_unresolved_conflict_falls_back_to_website_first_match(catalog) -> None:
    same = '{"T": "T2a", "N": "N0", "M": "M0"}'
    generate, _ = _fake(same, same)
    entry, log = local_llm.propose_case(generate, ROW, catalog, model_label="fake")
    assert log["status"] == "ok" and entry["stage"] == "IIA"
    assert any("did not choose" in warning for warning in entry["warnings"])


def test_stage_without_conflict_is_dropped(catalog) -> None:
    generate, _ = _fake('{"T": "T3b", "N": "N0", "M": "M0", "stage": "I"}')
    entry, log = local_llm.propose_case(generate, ROW, catalog, model_label="fake")
    assert log["status"] == "ok" and "stage" not in entry


def test_invalid_after_retry_becomes_visible_skip(catalog) -> None:
    generate, _ = _fake("no json here", '{"T": "T9", "N": "N0", "M": "M0"}')
    entry, log = local_llm.propose_case(generate, ROW, catalog, model_label="fake")
    assert log["status"] == "invalid"
    assert entry["skip"].startswith("fake output invalid after retry")


def test_no_template_skips_without_calling_the_model(catalog) -> None:
    generate, calls = _fake()
    row = {**ROW, "patho_txt": "Parotid carcinoma", "report_txt": "Neck mass", "notes_txt": ""}
    entry, log = local_llm.propose_case(generate, row, catalog, model_label="fake")
    assert log["status"] == "skip-no-template" and not calls and entry["skip"]


def test_normalize_drops_m_location_for_m0_and_moves_side_nodes(catalog) -> None:
    cancer = catalog.documents["Prostate"]
    entry, fixes = local_llm.normalize(
        {"T": "T2a", "N": "N1", "M": "M0", "M_location": ["bone"], "N_location": ["Obturator"], "extra": 1},
        cancer,
    )
    assert "M_location" not in entry and "N_location" not in entry
    assert any("unknown key" in fix for fix in fixes)


def test_reference_prefers_approved_text_and_parses_stage_line() -> None:
    case = {
        "proposal": {
            "staging_text": "Tumor Stage: HCC\n...\nHCC Cancer Staging:\nT1aN0M0 (Staging: IA)\n***",
            "t": "T2",
            "n": "N0",
            "m": "M0",
            "stage": "II",
        },
        "approval": {"state": "approved"},
    }
    reference = trial_report.reference_for(case)
    assert reference["source"] == "approved text"
    assert (reference["t"], reference["n"], reference["m"], reference["stage"]) == ("T1a", "N0", "M0", "IA")
    assert trial_report._parse_text("X\nT1/2N2aM1c (Staging: IVC)")["t"] == "T1/2"


def test_batch_refuses_trial_reviews() -> None:
    with pytest.raises(ValueError, match="never sent to RIS"):
        batch.run_batch({"trial": {"model": "x"}, "cases": []}, api_url="http://unused")
