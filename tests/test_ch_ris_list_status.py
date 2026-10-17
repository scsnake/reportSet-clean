# /// script
# requires-python = ">=3.10"
# dependencies = ["playwright"]
# ///
"""Run: uv run tests/test_ch_ris_list_status.py [--ie]. Uses only a local fixture.

Downloads jQuery 1.2.6 from code.jquery.com to match the hospital page.
Pass --ie on Windows to also test a private IE mode 5 WebBrowser control.
"""

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
from threading import Thread
from urllib.request import urlopen

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
FIXTURE_PATH = "/webcvis/MJB/MJB3W001.do"


def check_cookies(context, value):
    cookies = context.cookies()
    status = [cookie for cookie in cookies if cookie["name"] == "selected_status"]
    assert len(status) == 1, status
    assert status[0]["value"] == value and status[0]["path"] == "/webcvis/MJB", status
    assert status[0]["expires"] == -1, "status must remain a session cookie"
    assert next(c for c in cookies if c["name"] == "RIS_TEST_AUTH")["value"] == "keep"


def check_browser(base_url):
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        context = browser.new_context()
        try:
            context.add_cookies([
                {"name": "selected_status", "value": "00", "domain": "127.0.0.1", "path": "/"},
                {"name": "selected_status", "value": "2", "domain": "127.0.0.1", "path": "/webcvis"},
                {"name": "RIS_TEST_AUTH", "value": "keep", "domain": "127.0.0.1", "path": "/"},
            ])
            page = context.new_page()
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(base_url + FIXTURE_PATH)
            check_cookies(context, "2")
            status = page.locator('select[name="status"]')
            for value in ("00", "2", ""):
                status.select_option(value)
                check_cookies(context, value)
                with page.expect_navigation():
                    page.get_by_role("button", name="Query", exact=True).click()
                assert status.input_value() == value, "Query lost manual status"
                check_cookies(context, value)
                page.reload()
                assert status.input_value() == value, "Reload lost manual status"

            status.select_option("2")
            page.locator("#ahk_reset").click()
            check_cookies(context, "00")
            page.reload()
            assert status.input_value() == "00", "Reset preset was not remembered"
            with page.expect_navigation():
                page.locator("#ahk_ct").click(modifiers=["Alt"])
            assert status.input_value() == "", ("Alt+CT lost All status", page.url, context.cookies())
            check_cookies(context, "")
            with page.expect_navigation():
                page.locator("#ahk_ct").click()
            assert status.input_value() == "00", "CT preset lost Unsent status"
            check_cookies(context, "00")

            page.evaluate("window.prompt = function(){ return '1234567890'; };")
            with page.expect_navigation():
                page.locator("#ahk_search_chartno").click()
            assert status.input_value() == "", "Chart search lost All status"
            check_cookies(context, "")
            status.select_option("2")
            page.locator("#ClearAllButton").click()
            page.reload()
            assert status.input_value() == "", "Clear restored stale status"
            check_cookies(context, "")

            # Reinjection must preserve the selection and avoid duplicate bindings.
            page.add_script_tag(path=str(ROOT / "Lib/CH_RIS_LIST_enhance.js"))
            status.select_option("2")
            check_cookies(context, "2")
            assert not errors, errors
        finally:
            context.close()
            browser.close()
    print("PASS: conflicting cookie paths, manual Query/reload, presets, Clear, and reinjection")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ie", action="store_true")
    args = parser.parse_args()
    with urlopen("https://code.jquery.com/jquery-1.2.6.min.js", timeout=30) as response:
        jquery = response.read()
    assets = {
        FIXTURE_PATH: (ROOT / "tests/ch_ris_list_status.html").read_bytes(),
        "/jquery.js": jquery,
        "/enhancer.js": (ROOT / "Lib/CH_RIS_LIST_enhance.js").read_bytes(),
    }

    class Handler(BaseHTTPRequestHandler):
        load_count = 0

        def do_GET(self):
            path = self.path.split("?", 1)[0]
            content = assets.get(path)
            if path == FIXTURE_PATH:
                Handler.load_count += 1
                marker = f'<input type="hidden" id="fixture-load" value="{Handler.load_count}">'
                content = content.replace(b"<!-- fixture-load -->", marker.encode())
            self.send_response(200 if content is not None else 404)
            self.send_header("Content-Type", "application/javascript" if path.endswith(".js") else "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(content or b"")

        def log_message(self, *args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base_url = f"http://127.0.0.1:{server.server_port}"
    try:
        check_browser(base_url)
        if args.ie:
            subprocess.run([
                "powershell", "-NoProfile", "-STA", "-File",
                str(ROOT / "tests/test_ch_ris_list_status_ie.ps1"),
                "-FixtureUrl", base_url + FIXTURE_PATH,
            ], check=True, timeout=60)
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == "__main__":
    main()
