from __future__ import annotations

import hashlib

import pytest

import canary


def test_derive_staging_block_preserves_original_and_layout():
    assert canary.derive_staging_block(
        "Original report.\r\n", "Original report.\n\nFormal staging block.\n"
    ) == "Formal staging block."


def test_derive_staging_block_rejects_changed_original():
    with pytest.raises(ValueError, match="exact prefix"):
        canary.derive_staging_block(
            "Original report.", "Edited original report.\n\nFormal staging block."
        )


def test_derive_staging_block_accepts_supplied_separator_exactly():
    block, append_newlines = canary.derive_staging_append(
        "Original report.", "Original report.\n\n\nFormal staging block."
    )
    assert block == "Formal staging block."
    assert append_newlines == 3


def test_derive_staging_block_rejects_separator_spaces():
    with pytest.raises(ValueError, match="unsupported separator whitespace"):
        canary.derive_staging_block(
            "Original report.", "Original report.\n \nFormal staging block."
        )


def test_strip_clinician_notification_marker_line_only():
    source = "Impression:\r\nFinding.\r\n通報臨床醫師0 \r\n"
    cleaned, count = canary.strip_clinician_notification_markers(source)
    assert cleaned == "Impression:\r\nFinding.\r\n"
    assert count == 1


def test_strip_clinician_notification_marker_inline_suffix():
    cleaned, count = canary.strip_clinician_notification_markers(
        "Finding. 通報臨床醫師sent"
    )
    assert cleaned == "Finding."
    assert count == 1


class FakeApi:
    instance = None

    def __init__(self, base_url):
        self.calls = []
        self.__class__.instance = self

    def login(self, userid, password):
        self.calls.append(("login", userid, password))

    def logout(self):
        self.calls.append(("logout",))

    def locate_accession(self, accession):
        self.calls.append(("locate", accession))
        return {
            "study": {"index": 7, "chart_no": "0001234567"},
            "list_context_id": 4,
        }

    def get_study(self, index):
        self.calls.append(("get", index))
        return {
            "info": {
                "referno": "99900000001",
                "patno": "0001234567",
                "pageid": "MJB3N002",
                "exam": "Original report.\r\n",
            }
        }

    def cancer_staging_recheck(self, **kwargs):
        self.calls.append(("recheck", kwargs))
        return {"dry_run": kwargs["dry_run"], "submitted": False}


def test_canary_preview_extracts_only_appended_block(monkeypatch):
    monkeypatch.setattr(canary, "WebRISApi", FakeApi)
    modified = "Original report.\n\nFormal staging block.\n"

    result = canary.run_canary(
        api_url="http://fixture",
        accession="99900000001",
        modified_report=modified,
    )

    assert result["mode"] == "preview"
    recheck = [call for call in FakeApi.instance.calls if call[0] == "recheck"][0]
    assert recheck[1]["staging_text"] == "Formal staging block."
    assert recheck[1]["dry_run"] is True
    assert recheck[1]["append_newlines"] == 2
    assert recheck[1]["allow_url_index_fallback"] is True
    assert recheck[1]["approved_text_sha256"] == hashlib.sha256(
        b"Formal staging block."
    ).hexdigest()
