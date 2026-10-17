from __future__ import annotations

from api_client import WebRISApi


class _Response:
    ok = True
    status_code = 200

    def __init__(self, payload: dict):
        self._payload = payload

    def json(self) -> dict:
        return self._payload


class _Session:
    def __init__(self):
        self.calls: list[tuple[str, dict]] = []

    def get(self, url, params=None, timeout=None):
        self.calls.append((url, dict(params or {})))
        if url.endswith("/api/status"):
            return _Response({"status": "ok", "list_context_id": 7})
        return _Response(
            {
                "status": "ok",
                "studies": [
                    {"index": "0", "acc_no": "99900000001", "chart_no": "0001234567"}
                ],
            }
        )


def test_locate_study_queries_all_statuses_so_reported_studies_are_found():
    api = WebRISApi("http://example")
    api.session = _Session()

    located = api.locate_study(
        accession="99900000001", chart_no="1234567", study_date="2026/01/02"
    )

    assert located["study"]["acc_no"] == "99900000001"
    assert located["list_context_id"] == 7
    url, params = api.session.calls[0]
    assert url.endswith("/api/worklist")
    # RIS defaults to status '00' (unreported), which hides the reported
    # studies this workflow targets; the empty string requests all statuses.
    assert params["status"] == ""
    assert params["checktimestart"] == params["checktimeend"] == "2026/01/02"
