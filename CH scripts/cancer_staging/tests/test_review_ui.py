from __future__ import annotations

import json
import threading
from pathlib import Path

import pytest
import requests

import workflow
from review_ui import build_server
from tnm_catalog import CancerCatalog, text_sha256


def _catalog() -> CancerCatalog:
    return CancerCatalog(
        {
            "documents": [
                {
                    "id": "Prostate",
                    "name": "Prostate Cancer",
                    "T_RL": False,
                    "N_RL": True,
                    "T": {"Tx": "Unknown", "T3b": "Seminal vesicle"},
                    "N": {"N0": "No positive regional nodes"},
                    "M": {"M0": "No distal metastasis", "M1b": "Bone(s)"},
                    "T_location": ["Left lobe"],
                    "N_location": ["Obturator"],
                    "M_location": ["bone"],
                    "Staging": [{"stage": "IIIB", "TNM": ["T3bN0"]}, {"stage": "IVB", "TNM": ["M1b"]}],
                }
            ]
        }
    )


def _review_file(tmp_path: Path) -> Path:
    staging_text = "Formal staging block."
    payload = {
        "schema_version": 1,
        "created_at": "2026-09-28T00:00:00+00:00",
        "catalog": {"source": "test", "sha256": "catalog"},
        "cases": [
            {
                "source": {
                    "accession": "99900000001",
                    "chart_no": "1234567",
                    "study_name": "ABDOMEN CT",
                    "study_date": "2026/09/01",
                    "report_txt": "Original report.",
                },
                "proposal": {
                    "t": "T3",
                    "n": "N0",
                    "m": "M0",
                    "stage": "IIIA",
                    "matching_stages": ["IIIA"],
                    "staging_text": staging_text,
                    "text_sha256": text_sha256(staging_text),
                    "warnings": [],
                    "assumptions": [],
                    "evidence": {},
                },
                "approval": {
                    "state": "pending",
                    "approved_text_sha256": "",
                    "approved_at": "",
                },
                "execution": {},
            }
        ],
    }
    path = tmp_path / "review.json"
    workflow.save_json(path, payload)
    return path


@pytest.fixture
def review_server(tmp_path: Path):
    path = _review_file(tmp_path)
    server = build_server(path, port=0, csrf_token="test-review-token", catalog=_catalog())
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    host, port = server.server_address[:2]
    try:
        yield path, f"http://{host}:{port}"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


def test_review_ui_serves_local_page_and_review(review_server) -> None:
    _path, base = review_server
    page = requests.get(base + "/", timeout=2)
    assert page.status_code == 200
    assert "Cancer staging" in page.text
    assert "frame-ancestors 'none'" in page.headers["Content-Security-Policy"]

    response = requests.get(base + "/api/review", timeout=2)
    assert response.status_code == 200
    payload = response.json()
    assert payload["review_token"] == "test-review-token"
    assert payload["summary"] == {
        "total": 1,
        "approved": 0,
        "pending": 1,
        "batch_sha256": workflow.batch_sha256(payload["review"]),
        "sent": [],
        "not_applicable": 0,
    }


def test_edit_approve_and_stale_write_protection(review_server) -> None:
    path, base = review_server
    headers = {
        "Content-Type": "application/json",
        "X-Review-Token": "test-review-token",
    }
    original = workflow.load_json(path)["cases"][0]
    original_sha = original["proposal"]["text_sha256"]
    endpoint = base + "/api/cases/99900000001"

    forbidden = requests.post(
        endpoint + "/approve",
        json={"expected_sha256": original_sha},
        headers={"X-Review-Token": "wrong"},
        timeout=2,
    )
    assert forbidden.status_code == 403

    edited_text = "Formal staging block.\nHuman edit."
    edited = requests.post(
        endpoint + "/text",
        data=json.dumps(
            {"staging_text": edited_text, "expected_sha256": original_sha}
        ),
        headers=headers,
        timeout=2,
    )
    assert edited.status_code == 200
    edited_case = edited.json()["case"]
    edited_sha = text_sha256(edited_text)
    assert edited_case["proposal"]["text_sha256"] == edited_sha
    assert edited_case["approval"]["state"] == "pending"

    stale = requests.post(
        endpoint + "/text",
        data=json.dumps(
            {"staging_text": "Another edit", "expected_sha256": original_sha}
        ),
        headers=headers,
        timeout=2,
    )
    assert stale.status_code == 409

    approved = requests.post(
        endpoint + "/approve",
        data=json.dumps({"expected_sha256": edited_sha}),
        headers=headers,
        timeout=2,
    )
    assert approved.status_code == 200
    assert approved.json()["case"]["approval"]["state"] == "approved"
    assert workflow.approved_cases(workflow.load_json(path))


def test_review_ui_refuses_non_loopback_bind(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="loopback"):
        build_server(_review_file(tmp_path), host="0.0.0.0", port=0)


def test_sheet_choice_updates_pasteback_block(review_server) -> None:
    _path, base = review_server
    headers = {"Content-Type": "application/json", "X-Review-Token": "test-review-token"}
    endpoint = base + "/api/cases/99900000001/sheet"
    saved = requests.post(endpoint, data=json.dumps({"status": "已備註"}), headers=headers, timeout=2)
    assert saved.status_code == 200
    block = requests.get(base + "/api/pasteback", timeout=2).json()
    assert block["rows"][0]["status"] == "已備註"
    assert block["rows"][0]["status_source"] == "chosen"
    rejected = requests.post(endpoint, data=json.dumps({"status": "done"}), headers=headers, timeout=2)
    assert rejected.status_code == 400


def test_template_form_catalog_render_and_save(review_server) -> None:
    path, base = review_server
    headers = {"Content-Type": "application/json", "X-Review-Token": "test-review-token"}
    choices = requests.get(base + "/api/catalog", timeout=2).json()
    assert choices["cancers"][0]["id"] == "Prostate"
    entry = {"cancer": "Prostate", "T": "T3b", "N": "N0", "M": "M1b", "M_location": ["bone"]}
    rendered = requests.post(
        base + "/api/render", data=json.dumps({"accession": "99900000001", "entry": entry}),
        headers=headers, timeout=2,
    ).json()
    assert "T3bN0M1b (Staging: IVB)" in rendered["text"]
    assert workflow.load_json(path)["cases"][0]["proposal"]["staging_text"] == "Formal staging block."
    bad = requests.post(
        base + "/api/render", data=json.dumps({"accession": "99900000001", "entry": {**entry, "T": "T9"}}),
        headers=headers, timeout=2,
    )
    assert bad.status_code == 400
    saved = requests.post(
        base + "/api/cases/99900000001/form",
        data=json.dumps({"entry": entry, "staging_text": rendered["text"],
                         "expected_sha256": text_sha256("Formal staging block.")}),
        headers=headers, timeout=2,
    )
    assert saved.status_code == 200
    proposal = workflow.load_json(path)["cases"][0]["proposal"]
    assert (proposal["t"], proposal["m"], proposal["stage"]) == ("T3b", "M1b", "IVB")
    assert proposal["staging_text"] == rendered["text"]


def test_not_applicable_action_and_undo(review_server) -> None:
    path, base = review_server
    headers = {"Content-Type": "application/json", "X-Review-Token": "test-review-token"}
    endpoint = base + "/api/cases/99900000001"
    marked = requests.post(endpoint + "/not_applicable", data="{}", headers=headers, timeout=2)
    assert marked.status_code == 200
    assert marked.json()["summary"]["not_applicable"] == 1 and marked.json()["summary"]["pending"] == 0
    assert workflow.load_json(path)["cases"][0]["approval"]["state"] == "not_applicable"
    block = requests.get(base + "/api/pasteback", timeout=2).json()
    assert block["tsv"] == "其他癌\t已備註"
    undone = requests.post(endpoint + "/revoke", data="{}", headers=headers, timeout=2)
    assert undone.json()["summary"]["pending"] == 1
