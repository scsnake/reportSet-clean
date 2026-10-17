from __future__ import annotations

import hashlib

import pytest

import batch
import sheet_client
from workflow import batch_sha256


STAGING = "Fixture Cancer Staging:\nTxN0M0 (Staging: N/A)"
SOURCE_REPORT = "Original report.\n"


def _review() -> dict:
    text_sha = hashlib.sha256(STAGING.encode("utf-8")).hexdigest()
    review = {
        "catalog": {"sha256": "c" * 64},
        "cases": [
            {
                "source": {
                    "accession": "99900000001",
                    "chart_no": "0001234567",
                    "study_date": "2026/01/02",
                    "report_txt": SOURCE_REPORT,
                },
                "proposal": {
                    "catalog_id": "Fixture",
                    "t": "Tx",
                    "n": "N0",
                    "m": "M0",
                    "staging_text": STAGING,
                    "text_sha256": text_sha,
                },
                "approval": {
                    "state": "approved",
                    "approved_text_sha256": text_sha,
                },
            }
        ],
    }
    return review


class FakeApi:
    instances = []

    def __init__(self, base_url):
        self.base_url = base_url
        self.calls = []
        self.__class__.instances.append(self)

    def login(self, userid, password):
        self.calls.append(("login", userid, password))

    def logout(self):
        self.calls.append(("logout",))

    def locate_study(self, **kwargs):
        self.calls.append(("locate", kwargs))
        return {"study": {"index": 7}, "list_context_id": 4}

    def get_study(self, index):
        self.calls.append(("get", index))
        return {
            "info": {
                "referno": "99900000001",
                "patno": "0001234567",
                "pageid": "MJB3N002",
                "exam": "Original report.\r\n\r\n",
            }
        }

    def cancer_staging_recheck(self, **kwargs):
        self.calls.append(("submit", kwargs))
        return {"status": "ok", "dry_run": kwargs["dry_run"]}


def test_preview_uses_exact_ris_hash_after_normalized_source_match(monkeypatch):
    FakeApi.instances.clear()
    monkeypatch.setattr(batch, "WebRISApi", FakeApi)
    review = _review()

    results = batch.run_batch(review, api_url="http://fixture", execute=False)

    assert results[0]["status"] == "ok"
    submit = [call for call in FakeApi.instances[0].calls if call[0] == "submit"][0]
    expected = hashlib.sha256("Original report.\r\n\r\n".encode("utf-8")).hexdigest()
    assert submit[1]["expected_exam_sha256"] == expected
    assert submit[1]["dry_run"] is True


def test_execute_requires_current_batch_hash(monkeypatch):
    monkeypatch.setattr(batch, "WebRISApi", FakeApi)
    review = _review()
    expected = batch_sha256(review)

    results = batch.run_batch(
        review,
        api_url="http://fixture",
        execute=True,
        expected_batch_sha256=expected,
    )

    assert results[0]["status"] == "ok"
    submit = [call for call in FakeApi.instances[-1].calls if call[0] == "submit"][0]
    assert submit[1]["dry_run"] is False


def test_sheet_update_happens_only_after_execute_success(monkeypatch):
    monkeypatch.setattr(batch, "WebRISApi", FakeApi)
    writes = []
    monkeypatch.setattr(
        sheet_client,
        "write_study_result",
        lambda **kwargs: writes.append(kwargs) or {"status": "set='完成'"},
    )
    review = _review()

    results = batch.run_batch(
        review,
        api_url="http://fixture",
        execute=True,
        expected_batch_sha256=batch_sha256(review),
        update_sheet=True,
    )

    assert results[0]["status"] == "ok"
    assert writes == [
        {
            "accession": "99900000001",
            "chart_no": "0001234567",
            "cancer_type": "Fixture",
        }
    ]


def test_sheet_update_refused_for_preview():
    review = _review()
    try:
        batch.run_batch(
            review,
            api_url="http://fixture",
            execute=False,
            update_sheet=True,
        )
    except ValueError as exc:
        assert "only with --execute" in str(exc)
    else:
        raise AssertionError("preview unexpectedly allowed a Sheet mutation")


def test_already_sent_case_is_skipped_and_keeps_its_record(monkeypatch):
    FakeApi.instances.clear()
    monkeypatch.setattr(batch, "WebRISApi", FakeApi)
    review = _review()
    sent = {"mode": "execute", "status": "ok", "response": {"submitted": True}}
    review["cases"][0]["execution"] = dict(sent)
    with pytest.raises(ValueError, match="No approved, unsent cases"):
        batch.run_batch(review, api_url="http://fake")
    assert review["cases"][0]["execution"] == sent
    assert not FakeApi.instances


class SubmittingApi(FakeApi):
    """Fake RIS that reports a real submission."""

    def cancer_staging_recheck(self, **kwargs):
        self.calls.append(("submit", kwargs))
        return {"status": "ok", "dry_run": kwargs["dry_run"], "submitted": not kwargs["dry_run"],
                "new_exam_sha256": "n" * 64}


def _api_with_exam(exam: str):
    class Api(SubmittingApi):
        def get_study(self, index):
            info = super().get_study(index)
            info["info"]["exam"] = exam
            return info

    return Api


def test_ledger_blocks_resending_an_accession_from_an_earlier_batch(monkeypatch, tmp_path):
    SubmittingApi.instances.clear()
    monkeypatch.setattr(batch, "WebRISApi", SubmittingApi)
    ledger = tmp_path / "sent_ledger.jsonl"
    ledger.write_text('{"accession": "99900000001", "at": "2026-09-30T00:00:00"}\n', encoding="utf-8")
    review = _review()
    results = batch.run_batch(review, api_url="http://fake", execute=True,
                              expected_batch_sha256=batch_sha256(review), ledger_path=ledger)
    assert results[0]["status"] == "skipped" and "sent ledger" in results[0]["reason"]
    assert not any(call[0] == "submit" for call in SubmittingApi.instances[-1].calls)
    assert "execution" not in review["cases"][0]  # untouched by the skip


def test_successful_send_is_recorded_and_preview_is_not(monkeypatch, tmp_path):
    monkeypatch.setattr(batch, "WebRISApi", SubmittingApi)
    ledger = tmp_path / "sent_ledger.jsonl"
    review = _review()
    batch.run_batch(review, api_url="http://fake", execute=False, ledger_path=ledger)
    assert not ledger.exists()
    batch.run_batch(review, api_url="http://fake", execute=True,
                    expected_batch_sha256=batch_sha256(review), ledger_path=ledger)
    assert batch.load_sent_ledger(ledger)["99900000001"]["new_exam_sha256"] == "n" * 64


def test_same_staging_text_already_in_ris_is_skipped_and_marked_sent(monkeypatch, tmp_path):
    import workflow

    api = _api_with_exam("Original report.\r\n\r\n" + STAGING.replace("\n", "\r\n") + "\r\n")
    api.instances.clear()
    monkeypatch.setattr(batch, "WebRISApi", api)
    ledger = tmp_path / "sent_ledger.jsonl"
    review = _review()
    results = batch.run_batch(review, api_url="http://fake", execute=True,
                              expected_batch_sha256=batch_sha256(review), ledger_path=ledger)
    assert results[0]["status"] == "skipped" and "already contains this staging text" in results[0]["reason"]
    assert not any(call[0] == "submit" for call in api.instances[-1].calls)
    assert workflow.case_sent(review["cases"][0])
    assert "99900000001" in batch.load_sent_ledger(ledger)


def test_different_staging_block_already_in_ris_is_refused(monkeypatch):
    api = _api_with_exam("Original report.\r\n\r\nOther Cancer Staging:\r\nT1N0M0 (Staging: I)\r\n")
    api.instances.clear()
    monkeypatch.setattr(batch, "WebRISApi", api)
    review = _review()
    results = batch.run_batch(review, api_url="http://fake", execute=False)
    assert results[0]["status"] == "error" and "already has a cancer-staging block" in results[0]["error"]
    assert not any(call[0] == "submit" for call in api.instances[-1].calls)
