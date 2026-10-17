"""Playwright smoke test of the service page with fixture data and a fake RIS (nothing real).

    uv run python tests/service_ui_browser.py --screenshot logs/service_ui.png
"""

from __future__ import annotations

import argparse
import sys
import tempfile
import threading
from pathlib import Path

from playwright.sync_api import expect, sync_playwright

sys.path.insert(0, str(Path(__file__).parent))
import test_service as fx  # noqa: E402

import batch  # noqa: E402
from service import core, sync  # noqa: E402
from service.web import build_server  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screenshot", required=True)
    args = parser.parse_args()

    tmp = Path(tempfile.mkdtemp(prefix="cs_ui_"))
    app = fx._app(tmp, [fx.HEADER, fx._row("99900000001", note="癌委會:攝護腺癌"), fx._row("99900000001"),
                        fx._row("99900000001", fx.DOC_B)])
    sync.sync_sheet(app.store, app.sheet.read_rows())
    for accession in ("99900000001", "99900000001", "99900000001"):
        fx._fetched(app, accession)
    fx._with_text(app, "99900000001", approve=True)
    fx.FakeRis.exams = {"99900000001": "Report of 99900000001."}
    fx.FakeRis.submitted = []
    batch.WebRISApi = fx.FakeRis
    app.api_factory = fx.FakeRis
    core.ris.fetch_report = lambda api, accession, chart: {
        "exam": fx.FakeRis.exams[accession],
        "staging_blocks": len(batch.STAGING_BLOCK.findall(fx.FakeRis.exams[accession]))}
    server = build_server(app, port=0)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_address[1]}/"

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel="msedge", headless=True)
        page = browser.new_context(viewport={"width": 1500, "height": 1000}).new_page()
        errors: list[str] = []
        page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None)
        page.on("pageerror", lambda exc: errors.append(str(exc)))
        page.on("dialog", lambda dialog: dialog.accept())

        page.goto(base)
        expect(page.locator("#cs-modal h2")).to_have_text("Choose your name")
        expect(page.locator(".cs-name")).to_have_count(2)
        page.locator(".cs-name", has_text=fx.DOC_A).click()
        expect(page.locator("#cs-bar .cs-who strong")).to_have_text(fx.DOC_A)
        expect(page.locator("#case-list button")).to_have_count(2)   # only this doctor's two rows
        expect(page.locator("#cs-bar .cs-info")).to_contain_text("1 without a proposal yet")
        expect(page.locator(".safety-pill")).to_have_text("Approval only · no RIS send")

        page.get_by_role("button", name="Sign in with RIS to send").click()
        page.get_by_placeholder("RIS user ID").fill("u-a")
        page.get_by_placeholder("RIS password").fill("wrong")
        page.locator("#cs-modal").get_by_role("button", name="Sign in").click()
        expect(page.locator(".cs-note")).to_contain_text("RIS login failed")
        page.get_by_placeholder("RIS password").fill("right")
        page.locator("#cs-modal").get_by_role("button", name="Sign in").click()
        send = page.get_by_role("button", name="Send approved to RIS (1)")
        expect(send).to_be_enabled()
        expect(page.locator("#cs-bar .cs-session")).to_contain_text("RIS u-a · until")
        expect(page.locator(".safety-pill")).to_have_text("Approve, then Send to RIS")

        # One study: the button next to Approve opens the confirmation; Cancel sends nothing.
        page.locator("#case-list button", has_text="99900000001").click()
        expect(page.locator("#cs-send-one")).to_be_visible()
        page.locator("#cs-send-one").click()
        expect(page.locator("#cs-modal h2")).to_have_text("Send this study to RIS?")
        expect(page.locator(".cs-send-item pre")).to_have_text(fx.STAGING)
        page.locator("#cs-modal").get_by_role("button", name="Cancel").click()
        page.locator("#case-list button", has_text="99900000001").click()
        expect(page.locator("#cs-send-one")).to_be_hidden()       # no approved text on this study
        assert fx.FakeRis.submitted == []

        send.click()
        expect(page.locator("#cs-modal h2")).to_have_text("Send this study to RIS?")
        expect(page.locator(".cs-send-item")).to_have_count(1)
        page.locator("#cs-modal").get_by_role("button", name="Send this study to RIS").click()
        expect(page.locator("#cs-message")).to_contain_text("Sent 1: 99900000001. RIS read-back is correct.")
        assert len(fx.FakeRis.submitted) == 1
        expect(page.get_by_role("button", name="Send approved to RIS (0)")).to_be_disabled()

        page.get_by_role("button", name="Write to sheet (1)").click()
        expect(page.locator("#cs-message")).to_contain_text("Sheet updated: 1 row(s).")
        assert app.sheet.writes == [{"accession": "99900000001", "cancer_type": "攝護腺癌", "status": "完成"}]
        expect(page.locator("#case-list button")).to_have_count(1)   # the finished row left the list

        Path(args.screenshot).parent.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=args.screenshot, full_page=False)
        browser.close()
    server.shutdown()
    # The wrong-password step above makes one expected 403.
    unexpected = [text for text in errors if "403" not in text]
    assert not unexpected and len(errors) == 1, errors
    print("service UI smoke test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
