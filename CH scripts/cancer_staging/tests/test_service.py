from __future__ import annotations

import threading
from pathlib import Path
from urllib.parse import quote

import pytest
import requests

import batch
import workflow
from service import core, sheets, sync
from service.config import Settings
from service.core import App, Refused
from service.sheets import SheetClient, SheetError, SheetWriteRefused
from service.store import Conflict, Store
from service.web import build_server
from tnm_catalog import CancerCatalog, text_sha256

HEADER = ["申請單號", "院內病歷號碼", "攝影名稱", "攝影日期", "報告日期", "覆審醫師", "報告內容", "病理報告",
          "臨床診斷", "癌別", "完成", "備註", "備註2", "備註3", "確認有格式化", ""]
DOC_A, DOC_B = "甲醫師", "乙醫師"
STAGING = "Fixture Cancer Staging:\nT3bN0M0 (Staging: IIIB)"


def _row(accession: str, doctor: str = DOC_A, status: str = "待修正", cancer: str = "", note: str = "") -> list[str]:
    return [accession, "1234567", "ABDOMEN CT (有&無造影劑)", "2026/9/1", "2026/9/2", doctor,
            f"Report of {accession}.", "pathology", "dx", cancer, status, note, "", "", "", ""]


def _catalog() -> CancerCatalog:
    return CancerCatalog({"documents": [{
        "id": "Prostate", "name": "Prostate Cancer", "T_RL": False, "N_RL": True,
        "T": {"Tx": "Unknown", "T3b": "Seminal vesicle"}, "N": {"N0": "No positive regional nodes"},
        "M": {"M0": "No distal metastasis", "M1b": "Bone(s)"}, "T_location": ["Left lobe"],
        "N_location": ["Obturator"], "M_location": ["bone"],
        "Staging": [{"stage": "IIIB", "TNM": ["T3bN0"]}, {"stage": "IVB", "TNM": ["M1b"]}]}]})


class FakeSheet:
    """Stands in for SheetClient in the app tests."""

    def __init__(self, values: list[list[str]]) -> None:
        self.values = values
        self.writes: list[dict] = []

    def read_rows(self):
        return sheets.normalize_rows(self.values)

    def write_result(self, *, accession, chart_no, cancer_type, status, expected_status="待修正"):
        row = next(r for r in self.values[1:] if r[0] == accession)
        old = {"cancer_type": row[9], "status": row[10]}
        row[9], row[10] = cancer_type, status
        self.writes.append({"accession": accession, "cancer_type": cancer_type, "status": status})
        return {"row": self.values.index(row) + 1, "old": old, "written": True}


def _app(tmp_path: Path, values: list[list[str]], **settings) -> App:
    config = Settings(data_dir=tmp_path, **{"send_doctors": (DOC_A,), **settings})
    return App(config, Store(config.db_path), FakeSheet(values), _catalog())


def _fetched(app: App, accession: str, *, exam: str | None = None, blocks: int = 0, **extra) -> None:
    case = app.store.get_case(accession)
    state = {"accession": accession, "status": "已發送", "study_date": "2026/09/03 10:00:00",
             "exam": exam if exam is not None else case["source"]["report_txt"], "staging_blocks": blocks, **extra}
    sync.apply_ris(app.store, case, state, app.catalog)


def _with_text(app: App, accession: str, *, approve: bool = False) -> None:
    """Give a ready case a staging text, as a form edit or a proposal would."""
    case = app.store.get_case(accession)
    review = case["review"]
    review["proposal"].update(staging_text=STAGING, text_sha256=text_sha256(STAGING), catalog_id="Prostate",
                              matching_stages=["IIIB"], manually_edited=True)
    review["proposal"].pop("skip_reason", None)
    if approve:
        review["approval"] = {"state": "approved", "approved_text_sha256": text_sha256(STAGING), "approved_at": "x"}
    app.store.update_case(accession, review=review)


# ---- sheet sync -----------------------------------------------------------------------------------
def test_sync_opens_closes_and_reopens_cases(tmp_path):
    values = [HEADER, _row("99900000001"), _row("99900000001", DOC_B), _row("99900000001", status="完成"),
              _row("99900000001"), _row("99900000001"), _row("", DOC_A), _row("ABC")]
    app = _app(tmp_path, values)
    stats = sync.sync_sheet(app.store, app.sheet.read_rows())
    assert (stats["created"], stats["skipped"]) == (2, 3)  # 2 duplicates and 1 bad accession are skipped
    assert app.store.get_case("99900000001")["source"]["input_row"] == 2
    assert app.store.get_case("99900000001") is None

    values.insert(1, _row("99900000001", DOC_B, status="完成"))  # a row is added above: row numbers shift
    values[2][10] = "完成"
    stats = sync.sync_sheet(app.store, app.sheet.read_rows())
    assert stats["closed"] == 1 and app.store.get_case("99900000001")["phase"] == "closed"
    assert app.store.get_case("99900000001")["source"]["input_row"] == 4

    values[2][10] = "待修正"
    assert sync.sync_sheet(app.store, app.sheet.read_rows())["reopened"] == 1
    assert app.store.get_case("99900000001")["phase"] == "new"
    # A study this pipeline already sent is never reopened for a second send.
    sync.sync_sheet(app.store, [r for r in app.sheet.read_rows() if r["accession"] != "99900000001"])
    sync.sync_sheet(app.store, app.sheet.read_rows(), ledger={"99900000001": {"at": "t"}})
    assert app.store.get_case("99900000001")["phase"] == "closed"


def test_ris_fetch_results_set_the_phase(tmp_path):
    values = [HEADER, _row("99900000001"), _row("99900000001", note="癌委會:結腸癌"), _row("99900000001")]
    app = _app(tmp_path, values)
    sync.sync_sheet(app.store, app.sheet.read_rows())

    _fetched(app, "99900000001", exam="Report text in RIS, edited.\n")
    case = app.store.get_case("99900000001")
    assert case["phase"] == "ready" and case["source"]["report_txt"] == "Report text in RIS, edited.\n"
    assert case["source"]["study_date"] == "2026/09/03" and case["source"]["sheet_study_date"] == "2026/9/1"
    assert case["review"]["proposal"]["skip_reason"].startswith("No proposal yet")
    assert any("differs from the sheet" in text for text in case["review"]["proposal"]["warnings"])

    _fetched(app, "99900000001", blocks=1, tumor_type="Unknown Tumor", stage_line="T1N0M0 (Staging: I)")
    staged = app.store.get_case("99900000001")
    assert staged["phase"] == "staged"
    assert staged["review"]["sheet"] == {"status": "完成", "cancer_type": "大腸直腸癌"}  # from the committee note
    assert [row["accession"] for row in app.sheet_pending(DOC_A)] == ["99900000001"]

    sync.apply_ris(app.store, app.store.get_case("99900000001"),
                   {"accession": "99900000001", "status": "報告中", "not_reported": True}, app.catalog)
    assert app.store.get_case("99900000001")["phase"] == "not_reported"
    assert [c["source"]["accession"] for c in app.store.load_review(DOC_A)["cases"]] == ["99900000001", "99900000001"]


def test_report_change_in_ris_resets_an_approval(tmp_path):
    app = _app(tmp_path, [HEADER, _row("99900000001")])
    sync.sync_sheet(app.store, app.sheet.read_rows())
    _fetched(app, "99900000001")
    _with_text(app, "99900000001", approve=True)
    _fetched(app, "99900000001", exam="The doctor changed the report in RIS.")
    review = app.store.get_case("99900000001")["review"]
    assert review["approval"]["state"] == "pending" and review["proposal"]["staging_text"] == STAGING


def test_proposal_does_not_replace_human_work(tmp_path):
    app = _app(tmp_path, [HEADER, _row("99900000001"), _row("99900000001")])
    sync.sync_sheet(app.store, app.sheet.read_rows())
    for accession in ("99900000001", "99900000001"):
        _fetched(app, accession)
    _with_text(app, "99900000001")
    entry = {"skip": "model says no"}
    assert sync.set_entry(app.store, "99900000001", entry, by="m", catalog=app.catalog) is False
    assert sync.set_entry(app.store, "99900000001", entry, by="m", catalog=app.catalog) is True
    assert app.store.get_case("99900000001")["review"]["proposal"]["staging_text"] == STAGING
    assert app.store.get_case("99900000001")["review"]["proposal"]["skip_reason"] == "model says no"


def test_stale_save_is_a_conflict(tmp_path):
    app = _app(tmp_path, [HEADER, _row("99900000001")])
    sync.sync_sheet(app.store, app.sheet.read_rows())
    _fetched(app, "99900000001")
    first, second = app.store.load_review(DOC_A), app.store.load_review(DOC_A)
    first["cases"][0]["proposal"]["warnings"] = ["a"]
    assert app.store.save_review(DOC_A, first) == ["99900000001"]
    second["cases"][0]["proposal"]["warnings"] = ["b"]
    with pytest.raises(Conflict):
        app.store.save_review(DOC_A, second)


def test_ris_fetch_and_proposals_can_be_limited_to_one_doctor(tmp_path, monkeypatch):
    from service import propose

    app = _app(tmp_path, [HEADER, _row("99900000001"), _row("99900000001", DOC_B)])
    sync.sync_sheet(app.store, app.sheet.read_rows())
    monkeypatch.setattr(sync.ris, "fetch_report", lambda api, accession, chart: {
        "accession": accession, "status": "已發送", "study_date": "2026/09/03", "exam": "Report.", "staging_blocks": 0})
    assert sync.fetch_ris(app.store, app.settings, app.catalog, api=object(), doctor=DOC_B) == {"due": 1, "ready": 1}
    assert app.store.get_case("99900000001")["phase"] == "new"
    assert [case["accession"] for case in propose.pending(app, DOC_B)] == ["99900000001"]
    assert propose.pending(app, DOC_A) == []
    assert sync.fetch_ris(app.store, app.settings, app.catalog, api=object()) == {"due": 1, "ready": 1}
    assert len(propose.pending(app)) == 2


def test_redo_mark_makes_old_proposals_pending_but_not_human_work(tmp_path):
    from service import propose
    from service.store import now

    accessions = ["99900000001", "99900000001", "99900000001"]
    app = _app(tmp_path, [HEADER, *(_row(accession) for accession in accessions)])
    sync.sync_sheet(app.store, app.sheet.read_rows())
    for accession in accessions:
        _fetched(app, accession)
    for accession in accessions[:2]:
        sync.set_entry(app.store, accession, {"skip": "old rule"}, by="m", catalog=app.catalog)
        app.store.update_case(accession, entry_at="2026-10-01T00:05:00+00:00")
    _with_text(app, "99900000001")  # a person worked on this one
    assert [case["accession"] for case in propose.pending(app)] == ["99900000001"]

    app.store.set_meta(propose.REDO_MARK, now())
    assert [case["accession"] for case in propose.pending(app)] == ["99900000001", "99900000001"]
    sync.set_entry(app.store, "99900000001", {"skip": "new rule"}, by="m", catalog=app.catalog)
    assert [case["accession"] for case in propose.pending(app)] == ["99900000001"]


def test_daily_poll_time_and_no_send_setting(tmp_path, monkeypatch):
    from datetime import datetime

    from service.config import load_settings
    from service.run import seconds_until

    assert seconds_until("23:30", datetime(2026, 10, 7, 23, 0)) == 1800
    assert seconds_until("23:30", datetime(2026, 10, 7, 23, 30)) == 24 * 3600
    monkeypatch.setenv("CS_SEND_DOCTORS", "")
    assert load_settings(tmp_path).send_doctors == ()
    monkeypatch.setenv("CS_POLL_AT", "25:00")
    with pytest.raises(ValueError):
        load_settings(tmp_path)


# ---- sheet write by row label -----------------------------------------------------------------------
class FakeSheetsApi:
    """Enough of the Sheets REST API for write_result; a label follows its row object."""

    def __init__(self, values: list[list[str]]) -> None:
        self.rows = [list(row) for row in values]
        self.labels: dict[str, list[str]] = {}
        self.before_write = None

    def request(self, method, url, timeout=None, params=None, json=None):
        path = url.split("/SHEET", 1)[1]
        if method == "GET" and path == "":
            return _Response({"sheets": [{"properties": {"sheetId": 1, "title": "TNM"}}]})
        if method == "GET":
            return _Response({"values": [list(row) for row in self.rows]})
        if path == ":batchUpdate":
            for request in json["requests"]:
                if "createDeveloperMetadata" in request:
                    meta = request["createDeveloperMetadata"]["developerMetadata"]
                    self.labels[meta["metadataValue"]] = self.rows[meta["location"]["dimensionRange"]["startIndex"]]
                else:
                    lookup = request["deleteDeveloperMetadata"]["dataFilter"]["developerMetadataLookup"]
                    self.labels.pop(lookup["metadataValue"], None)
            return _Response({})
        if path == "/values:batchGetByDataFilter":
            row = self._labelled(json["dataFilters"][0])
            if row is None:
                return _Response({})
            number = next(i for i, item in enumerate(self.rows) if item is row) + 1
            return _Response({"valueRanges": [{"valueRange": {"range": f"TNM!A{number}:P{number}", "values": [list(row)]}}]})
        if path == "/values:batchUpdateByDataFilter":
            if self.before_write:
                hook, self.before_write = self.before_write, None
                hook(self)
            row = self._labelled(json["data"][0]["dataFilter"])
            for index, value in enumerate(json["data"][0]["values"][0]):
                if value is not None and row is not None:
                    row[index] = value
            return _Response({})
        raise AssertionError(path)

    def _labelled(self, data_filter):
        return self.labels.get(data_filter["developerMetadataLookup"]["metadataValue"])


class _Response:
    status_code = 200

    def __init__(self, payload):
        self._payload = payload

    def json(self):
        return self._payload


def _client(values):
    fake = FakeSheetsApi(values)
    return SheetClient("SHEET", 1, "unused", session_factory=lambda scope: fake), fake


def test_write_result_checks_the_row_and_removes_its_label():
    client, fake = _client([HEADER, _row("99900000001"), _row("99900000001", status="完成", cancer="肺癌"),
                            _row("99900000001", cancer="肺癌")])
    result = client.write_result(accession="99900000001", chart_no="0001234567", cancer_type="大腸直腸癌", status="完成")
    assert result == {"row": 2, "old": {"cancer_type": "", "status": "待修正"}, "written": True}
    assert fake.rows[1][9:11] == ["大腸直腸癌", "完成"] and fake.rows[1][:9] == _row("99900000001")[:9]
    assert fake.labels == {}
    with pytest.raises(SheetWriteRefused, match="not '待修正'"):
        client.write_result(accession="99900000001", chart_no="1234567", cancer_type="大腸直腸癌", status="完成")
    with pytest.raises(SheetWriteRefused, match="already '肺癌'"):
        client.write_result(accession="99900000001", chart_no="1234567", cancer_type="大腸直腸癌", status="完成")
    with pytest.raises(SheetWriteRefused, match="found 0"):
        client.write_result(accession="99900000001", chart_no="7654321", cancer_type="大腸直腸癌", status="完成")
    assert fake.rows[2][9:11] == ["肺癌", "完成"] and fake.rows[3][9:11] == ["肺癌", "待修正"] and fake.labels == {}


def test_write_result_follows_the_row_when_rows_are_inserted_during_the_write():
    client, fake = _client([HEADER, _row("99900000001"), _row("99900000001")])
    fake.before_write = lambda api: api.rows.insert(1, _row("99900000001", status="完成", cancer="胃癌"))
    result = client.write_result(accession="99900000001", chart_no="1234567", cancer_type="肝癌", status="完成")
    assert result["row"] == 4 and fake.rows[3][0] == "99900000001" and fake.rows[3][9:11] == ["肝癌", "完成"]
    assert fake.rows[2][9:11] == ["", "待修正"]  # the row now at the old row number is untouched


def test_write_result_restores_the_other_row_after_a_filter_sort_during_the_write():
    client, fake = _client([HEADER, _row("99900000001"), _row("99900000001", status="已備註", cancer="胃癌")])

    def filter_sort(api):  # cell contents move, the label stays on the row position
        api.rows[1][:], api.rows[2][:] = api.rows[2][:], api.rows[1][:]

    fake.before_write = filter_sort
    with pytest.raises(SheetError, match="old values were restored"):
        client.write_result(accession="99900000001", chart_no="1234567", cancer_type="肝癌", status="完成")
    by_accession = {row[0]: row[9:11] for row in fake.rows[1:]}
    assert by_accession == {"99900000001": ["", "待修正"], "99900000001": ["胃癌", "已備註"]} and fake.labels == {}


# ---- send ---------------------------------------------------------------------------------------------
class FakeRis:
    """WebRISApi stand-in for login checks and for batch.run_batch."""

    exams: dict[str, str] = {}
    submitted: list[dict] = []
    saved = {"u-a"}

    def __init__(self, base_url):
        self.base_url = base_url

    def login(self, userid, password):
        if password is None and userid not in self.saved and userid is not None:
            raise core.WebRISApiError("Missing credentials")
        if password not in (None, "right"):
            raise core.WebRISApiError("Login failed")
        return {"user": {"u-a": DOC_A, "u-b": DOC_B}.get(userid, "default")}

    def logout(self):
        pass

    def locate_study(self, *, accession, chart_no, study_date):
        return {"study": {"index": 7, "acc_no": accession}, "list_context_id": 4}

    def get_study(self, index):
        accession = next(iter(self.exams))
        return {"info": {"referno": accession, "patno": "0001234567", "pageid": "MJB3N002",
                         "exam": self.exams[accession]}}

    def cancer_staging_recheck(self, **kwargs):
        if not kwargs["dry_run"]:
            self.submitted.append(kwargs)
            self.exams[kwargs["accession"]] += "\n\n" + kwargs["staging_text"]
        return {"status": "ok", "dry_run": kwargs["dry_run"], "submitted": not kwargs["dry_run"]}


@pytest.fixture
def sending_app(tmp_path, monkeypatch):
    app = _app(tmp_path, [HEADER, _row("99900000001", note="癌委會:攝護腺癌")])
    sync.sync_sheet(app.store, app.sheet.read_rows())
    _fetched(app, "99900000001")
    _with_text(app, "99900000001", approve=True)
    FakeRis.exams = {"99900000001": "Report of 99900000001."}
    FakeRis.submitted = []
    monkeypatch.setattr(batch, "WebRISApi", FakeRis)
    app.api_factory = FakeRis
    monkeypatch.setattr(core.ris, "fetch_report", lambda api, accession, chart: {
        "exam": FakeRis.exams[accession], "staging_blocks": len(batch.STAGING_BLOCK.findall(FakeRis.exams[accession]))})
    return app


def test_send_needs_a_ris_sign_in_with_the_doctors_own_account(sending_app):
    app = sending_app
    with pytest.raises(Refused, match="Sign in"):
        app.send(DOC_A, "device-1")
    with pytest.raises(Refused, match="RIS login failed"):
        app.sign_in(DOC_A, "device-1", "u-a", "wrong")
    with pytest.raises(Refused, match=f"belongs to {DOC_B}"):
        app.sign_in(DOC_A, "device-1", "u-b", "right")
    with pytest.raises(Refused, match="not open"):
        app.sign_in(DOC_B, "device-1", "u-b", "right")
    assert app.sign_in(DOC_A, "device-1", "u-a", "right") == {"signed_in": True, "credential_saved": True}
    assert app.readiness(DOC_A, "device-1")["can_send"] and not app.readiness(DOC_A, "device-2")["can_send"]
    assert app.readiness(DOC_A, "device-1")["ris_userid"] == "u-a"
    app.sign_out(DOC_A, "device-1")
    assert not app.readiness(DOC_A, "device-1")["can_send"]
    assert FakeRis.submitted == []


def test_every_doctor_with_a_saved_ris_login_can_sign_in_by_default(tmp_path, monkeypatch):
    monkeypatch.setattr(FakeRis, "saved", {"u-a"})
    app = _app(tmp_path, [HEADER, _row("99900000001")], send_doctors=())
    app.api_factory = FakeRis
    assert app.sign_in(DOC_B, "device-1", "u-b", "right") == {"signed_in": True, "credential_saved": False}
    state = app.readiness(DOC_B, "device-1")
    assert state["signed_in"] and not state["can_send"] and "not saved in WebRIS" in state["why_not"]
    FakeRis.saved = {"u-a", "u-b"}
    app._saved.clear()
    assert app.readiness(DOC_B, "device-1")["can_send"]
    # A preview process (`service.run --no-send`) refuses everybody.
    off = _app(tmp_path / "off", [HEADER], send_doctors=(), send_enabled=False)
    off.api_factory = FakeRis
    with pytest.raises(Refused, match="not open"):
        off.sign_in(DOC_B, "device-1", "u-b", "right")


def test_sign_in_expires_and_stops_after_repeated_failures(sending_app):
    app = sending_app
    app.sign_in(DOC_A, "device-1", "u-a", "right")
    with app.store.tx() as db:
        db.execute("UPDATE devices SET trusted_at=?", ("2026-01-01T00:00:00+00:00",))
    state = app.readiness(DOC_A, "device-1")
    assert not state["signed_in"] and "Sign in" in state["why_not"]
    for _ in range(core.SIGNIN_MAX_FAILS):
        with pytest.raises(Refused, match="RIS login failed"):
            app.sign_in(DOC_A, "device-1", "u-a", "wrong")
    # The right password is not even tried now, so RIS cannot lock the account through this page.
    with pytest.raises(Refused, match="Too many failed sign-ins"):
        app.sign_in(DOC_A, "device-1", "u-a", "right")


def test_send_goes_only_for_the_confirmed_text(sending_app):
    app = sending_app
    app.sign_in(DOC_A, "device-1", "u-a", "right")
    with pytest.raises(Refused, match="No study was confirmed"):
        app.send(DOC_A, "device-1", {})
    result = app.send(DOC_A, "device-1", {"99900000001": text_sha256("an older text")})
    assert result["sent"] == [] and "changed after the confirmation" in result["failed"][0]["reason"]
    assert app.send(DOC_A, "device-1", {"99900000001": "x"})["failed"][0]["accession"] == "99900000001"
    assert FakeRis.submitted == []
    result = app.send(DOC_A, "device-1", {"99900000001": text_sha256(STAGING)})
    assert result["sent"] == ["99900000001"] and len(FakeRis.submitted) == 1


def test_send_runs_dry_run_then_sends_once_and_reads_back(sending_app):
    app = sending_app
    app.sign_in(DOC_A, "device-1", "u-a", "right")
    result = app.send(DOC_A, "device-1")
    assert result["sent"] == ["99900000001"] and result["failed"] == []
    assert result["readback"]["99900000001"]["ok"] is True
    assert len(FakeRis.submitted) == 1 and FakeRis.submitted[0]["staging_text"] == STAGING
    case = app.store.get_case("99900000001")
    assert workflow.case_sent(case["review"]) and case["review"]["execution"]["readback"]["ok"]
    assert "99900000001" in batch.load_sent_ledger(app.settings.ledger_path)
    assert app.send(DOC_A, "device-1")["sent"] == [] and len(FakeRis.submitted) == 1
    # The sheet row is offered for writing, with 癌別 from the committee note.
    assert [(r["cancer_type"], r["status"]) for r in app.sheet_pending(DOC_A)] == [("攝護腺癌", "完成")]
    written = app.write_sheet(DOC_A, "device-1")
    assert [w["accession"] for w in written["written"]] == ["99900000001"]
    assert app.store.get_case("99900000001")["phase"] == "closed"


def test_send_refuses_when_the_ris_report_changed(sending_app):
    app = sending_app
    app.sign_in(DOC_A, "device-1", "u-a", "right")
    FakeRis.exams["99900000001"] = "Somebody edited the report."
    result = app.send(DOC_A, "device-1")
    assert result["sent"] == [] and "differs substantively" in result["failed"][0]["reason"]
    assert FakeRis.submitted == []


# ---- web page -----------------------------------------------------------------------------------------
@pytest.fixture
def served(tmp_path):
    app = _app(tmp_path, [HEADER, _row("99900000001"), _row("99900000001", DOC_B)])
    sync.sync_sheet(app.store, app.sheet.read_rows())
    for accession in ("99900000001", "99900000001"):
        _fetched(app, accession)
        _with_text(app, accession)
    server = build_server(app, port=0, csrf_token="token")
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield app, f"http://127.0.0.1:{server.server_address[1]}"
    server.shutdown()
    server.server_close()


def test_each_doctor_sees_only_their_own_rows(served):
    app, base = served
    session = requests.Session()
    page = session.get(base + "/", timeout=5)
    assert "/service.js" in page.text and "cs_device" in session.cookies
    assert session.get(base + "/api/review", timeout=5).json()["review"]["cases"] == []
    headers = {"X-Review-Token": "token"}
    assert session.post(base + "/api/service/doctor", json={"doctor": "nobody"}, headers=headers, timeout=5).status_code == 400
    assert session.post(base + "/api/service/doctor", json={"doctor": DOC_B}, headers=headers, timeout=5).ok
    assert session.cookies["cs_doctor"] == quote(DOC_B)
    cases = session.get(base + "/api/review", timeout=5).json()["review"]["cases"]
    assert [case["source"]["accession"] for case in cases] == ["99900000001"]

    # Another doctor's study cannot be approved from this browser.
    body = {"expected_sha256": text_sha256(STAGING)}
    assert session.post(base + "/api/cases/99900000001/approve", json=body, headers=headers, timeout=5).status_code == 400
    assert app.store.get_case("99900000001")["review"]["approval"]["state"] == "pending"
    assert session.post(base + "/api/cases/99900000001/approve", json=body, headers=headers, timeout=5).ok
    state = session.get(base + "/api/service/state", timeout=5).json()
    assert state["doctor"] == DOC_B and state["sendable"] == 1 and state["can_send"] is False
    assert not state["send_open"] and [item["accession"] for item in state["send_list"]] == ["99900000001"]
    assert session.post(base + "/api/service/send", json={}, headers=headers, timeout=5).status_code == 400
    confirmed = {"cases": {"99900000001": state["send_list"][0]["approved_text_sha256"]}}
    assert session.post(base + "/api/service/send", json=confirmed, headers=headers, timeout=5).status_code == 403
    assert session.post(base + "/api/service/signin", json={"userid": "u-b", "password": "right"},
                        headers=headers, timeout=5).status_code == 403
    assert session.post(base + "/api/service/send", json={}, timeout=5).status_code == 403  # no token
    assert app.store.events(1)[0]["kind"] == "review_saved" and app.store.events(1)[0]["doctor"] == DOC_B
