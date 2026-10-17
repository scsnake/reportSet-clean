# /// script
# requires-python = ">=3.10"
# dependencies = ["playwright"]
# ///
"""Run with: uv run tests/test_ch_ris_hx_preview.py (requires Playwright Chromium)."""

from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "Lib" / "CH_RIS_HX_enhance.js"
REPORT = "\n  Findings:  \n\tLeft side: A & B\t\n    Unchanged.   \n\u00a0  Indented\n\n"
EXISTING = "Existing report \t\n  "


def fixture(page, reported, quirks=False, report=REPORT):
    cells = ["branch", "eio", "status", "2026/09/01", "CT", "Study", "signed", "1", "site"]
    if not reported:
        cells = ["", "", "", "Study", "CT", "", "2026/09/01", "", "", "", "", '<input type="hidden">', ""]
    table_id = 'id="row_beforereport"' if not reported else ''
    row = "".join("<td>" + cell + "</td>" for cell in cells)
    page.set_content(
        ('' if quirks else '<!doctype html>') + '<meta charset="utf-8">'
        '<style>body{min-height:1800px}#memotx{position:absolute;left:20px;width:180px;height:40px}</style>'
        '<input name="mciname" value="CT"><textarea id="exam"></textarea>'
        '<textarea id="memotx"></textarea><div id="dbrlist"><table '
        + table_id + '><tbody><tr id="history-row">' + row + '</tr></tbody></table></div>'
    )
    page.evaluate(
        r"""({report, reported}) => {
          var row = document.getElementById('history-row');
          var encoded = report.replace(/&/g, '&amp;');
          if(reported) row.setAttribute('title', encoded.replace(/\n/g, '<br/>'));
          else row.cells[11].getElementsByTagName('input')[0].value = encoded.replace(/\n/g, '\\r\\n');
          window.replaceCalls = [];
          window.replaceReport = function(event, field){
            window.replaceCalls.push({field: field, value: document.getElementById('exam').value});
          };
        }""",
        {"report": report, "reported": reported},
    )
    page.add_script_tag(path=str(SCRIPT))


def check_append(page, reported):
    fixture(page, reported)
    for old in ("", EXISTING):
        page.locator("#exam").fill(old)
        page.locator("#history-row").hover()
        stored = page.locator("#ch-ris-hx-preview").get_attribute("data-report")
        assert stored.replace("\r\n", "\n") == REPORT, "decoder changed report whitespace"
        page.get_by_role("button", name="Append to Exam", exact=True).click()
        expected = old + ("\n\n" if old else "") + REPORT
        assert page.locator("#exam").input_value() == expected, "append changed report whitespace"
        call = page.evaluate("window.replaceCalls[window.replaceCalls.length - 1]")
        assert call == {"field": "exam", "value": expected}, "RIS callback received changed text"
        page.evaluate("window.chRisHxBuild()")


def check_memo(page, width, height, scroll, quirks=False):
    page.set_viewport_size({"width": width, "height": height})
    page.mouse.move(width - 1, 1)
    fixture(page, reported=True, quirks=quirks)
    # Emulate IE mode 5: max-height cannot constrain the panel.
    page.add_style_tag(content="#ch-ris-hx-memo-preview{max-height:none !important}")
    page.locator("#memotx").fill("\n".join("Long memo line " + str(i) for i in range(160)))
    page.evaluate(
        """scroll => {
          document.getElementById('memotx').style.top = (scroll + window.innerHeight * 0.6) + 'px';
          window.scrollTo(0, scroll);
        }""",
        scroll,
    )
    original_height = page.evaluate("document.documentElement.scrollHeight")
    memo = page.locator("#memotx").bounding_box()
    page.mouse.move(memo["x"] + memo["width"] / 2, memo["y"] + memo["height"] / 2)
    panel = page.locator("#ch-ris-hx-memo-preview")
    panel.wait_for(state="visible")
    geometry = panel.evaluate(
        """el => ({bottom: el.getBoundingClientRect().bottom,
          top: el.getBoundingClientRect().top, client: el.clientHeight,
          content: el.scrollHeight, pageHeight: document.documentElement.scrollHeight})"""
    )
    assert geometry["top"] >= 0 and geometry["bottom"] <= height, geometry
    assert geometry["content"] > geometry["client"], "long memo is not scrollable"
    assert panel.evaluate("el => parseInt(el.style.height, 10) > 0"), "IE needs an explicit height"
    assert geometry["pageHeight"] == original_height, "memo increased page height"
    panel.hover()
    page.mouse.wheel(0, 350)
    page.wait_for_function("document.getElementById('ch-ris-hx-memo-preview').scrollTop > 0")
    assert page.evaluate("window.scrollY") == scroll, "memo wheel scrolled the page"
    page.evaluate("document.getElementById('memotx').value = 'Short memo'")
    page.evaluate("document.getElementById('memotx').onmouseover()")
    assert panel.evaluate("el => el.offsetHeight < 100 && el.scrollTop === 0"), "short memo did not shrink/reset"


def check_report(page, width, height, scroll, quirks, reported):
    page.set_viewport_size({"width": width, "height": height})
    page.mouse.move(width - 1, 1)
    report = "\n".join("  Old report line " + str(i) for i in range(160))
    fixture(page, reported=reported, quirks=quirks, report=report)
    page.add_style_tag(content="#ch-ris-hx-preview{max-height:none !important}")
    page.evaluate(
        """scroll => {
          var box = document.getElementById('dbrlist');
          box.style.cssText = 'position:absolute;left:20px;width:250px;height:80px;overflow:auto';
          box.style.top = (scroll + window.innerHeight * 0.6) + 'px';
          window.scrollTo(0, scroll);
        }""", scroll,
    )
    original_height = page.evaluate("document.documentElement.scrollHeight")
    page.evaluate("document.getElementById('history-row').onmouseover()")
    panel = page.locator("#ch-ris-hx-preview")
    geometry = panel.evaluate(
        """el => ({bottom: el.getBoundingClientRect().bottom,
          top: el.getBoundingClientRect().top, right: el.getBoundingClientRect().right,
          client: el.clientHeight, content: el.scrollHeight,
          pageHeight: document.documentElement.scrollHeight})"""
    )
    assert geometry["top"] >= 0 and geometry["bottom"] <= height, geometry
    assert geometry["right"] <= width, geometry
    assert geometry["content"] > geometry["client"], "old report is not scrollable"
    assert geometry["pageHeight"] == original_height, "old report increased page height"
    panel.hover()
    page.mouse.wheel(0, 350)
    page.wait_for_function("document.getElementById('ch-ris-hx-preview').scrollTop > 0")
    assert panel.is_visible(), "scrolling hid the old report"
    assert page.evaluate("window.scrollY") == scroll, "old report wheel scrolled the page"
    assert page.locator("#dbrlist").evaluate("el => el.scrollTop") == 0, "wheel scrolled history table"
    stored = panel.get_attribute("data-report")
    assert stored.replace("\r\n", "\n") == report, "scrolling changed report text"


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.set_default_timeout(5000)
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto((ROOT / "tests" / "ch_ris_hx_reported.html").as_uri())
        assert page.locator("#test-result").inner_text() == "PASS"
        check_append(page, reported=False)
        check_append(page, reported=True)
        for quirks in (False, True):
            for width, height in ((1024, 768), (800, 300), (360, 220)):
                for scroll in (0, 300):
                    check_memo(page, width, height, scroll, quirks=quirks)
                    for reported in (False, True):
                        check_report(page, width, height, scroll, quirks, reported)
        assert not errors, errors
        browser.close()
    print("PASS: report whitespace, append callback, memo/report viewport bounds, and internal scrolling")


if __name__ == "__main__":
    main()
