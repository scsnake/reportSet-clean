"""Playwright smoke test for the local review UI (run via with_server.py)."""

from __future__ import annotations

import argparse
from pathlib import Path

from playwright.sync_api import expect, sync_playwright


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8876")
    parser.add_argument("--screenshot", required=True)
    args = parser.parse_args()

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel="msedge", headless=True)
        context = browser.new_context(
            viewport={"width": 1500, "height": 1050},
            permissions=["clipboard-read", "clipboard-write"],
        )
        page = context.new_page()
        errors: list[str] = []
        http_errors: list[str] = []
        page.on(
            "console",
            lambda msg: errors.append(f"{msg.text} @ {msg.location}")
            if msg.type == "error"
            else None,
        )
        page.on(
            "response",
            lambda response: http_errors.append(f"{response.status} {response.url}")
            if response.status >= 400
            else None,
        )
        page.goto(args.base_url)
        page.wait_for_load_state("networkidle")

        # Expectations come from the served review copy, never from real
        # identifiers baked into this file. Sent studies are locked, so use
        # the first unsent study with text (revoking it first if approved).
        data = page.request.get(args.base_url.rstrip("/") + "/api/review").json()
        sent = set(data["summary"]["sent"])
        target = next(
            case for case in data["review"]["cases"]
            if case["source"]["accession"] not in sent and case["proposal"].get("staging_text")
        )
        accession = str(target["source"]["accession"])
        approved_before = data["summary"]["approved"]
        assert page.locator("#total-count").inner_text() == str(len(data["review"]["cases"]))
        page.locator(".case-card", has_text=accession).click()
        assert page.locator("#accession").inner_text() == accession
        if target["approval"]["state"] == "approved":
            page.once("dialog", lambda dialog: dialog.accept())
            page.locator("#revoke-approval").click()
            page.get_by_text("Approval revoked; text remains saved.").wait_for()
            approved_before -= 1
        report_head = target["source"]["report_txt"].strip().splitlines()[0]
        assert report_head in page.locator("#original-report").inner_text()

        page.locator("#copy-accession").click()
        page.locator("#toast.show").wait_for()
        assert page.evaluate("navigator.clipboard.readText()") == accession

        editor = page.locator("#staging-text")
        editor.fill(editor.input_value() + "\nBrowser test edit.")
        assert page.locator("#save-edit").is_enabled()
        assert page.locator("#approve-text").is_disabled()
        page.locator("#save-edit").click()
        page.get_by_text("Edits saved. Exact-text approval is now pending.").wait_for()

        page.locator("#approve-text").click()
        page.get_by_text("Exact staging text approved. No RIS submission was made.").wait_for()
        expect(page.locator("#approval-badge")).to_have_text("Approved")
        expect(page.locator("#approved-count")).to_have_text(str(approved_before + 1))

        if not page.locator("#next-case").is_disabled():
            page.locator("#next-case").click()
            assert page.locator("#accession").inner_text() != accession

        screenshot = Path(args.screenshot)
        screenshot.parent.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=str(screenshot), full_page=True)
        assert not errors and not http_errors, (
            f"Browser console errors: {errors}; HTTP errors: {http_errors}"
        )
        context.close()
        browser.close()

    print(f"Review UI browser test passed; screenshot={args.screenshot}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
