import unittest

from mobile_api import (
    MobileResponse,
    QueryError,
    ReadOnlyViolation,
    _ajax_action,
    _safe_internal_url,
    extract_element_document,
    extract_admissions,
    extract_menubar_tabs,
    normalize_chart_no,
    route_catalog,
)


BASE = "http://im.hospital-c.local:8080"


class MobileParsingTests(unittest.TestCase):
    def test_chart_numbers_are_validated_and_padded(self):
        self.assertEqual(normalize_chart_no("12345"), "0000012345")
        self.assertEqual(normalize_chart_no("0000012345"), "0000012345")
        for invalid in ("", "ABC", "12345678901"):
            with self.subTest(invalid=invalid), self.assertRaises(QueryError):
                normalize_chart_no(invalid)

    def test_document_preserves_tables_links_and_ajax_actions(self):
        body = b"""
        <html><head><title>Query</title></head><body>
        <h2>Results</h2>
        <table><tr><th>Date</th><th>Test</th></tr>
        <tr onclick="jQuery.ajax({type:'POST', data:{'labNo':'L1'}, url:'/mobile/lab/show'});">
        <td>115/08/29</td><td><a href="/mobile/lab/query?more=Y">CBC</a></td></tr></table>
        </body></html>
        """
        document = MobileResponse(200, BASE + "/mobile/lab/query", "text/html", body).document()

        self.assertEqual(document["title"], "Query")
        self.assertEqual(document["tables"][0]["rows"][1], ["115/08/29", "CBC"])
        self.assertEqual(document["links"][0]["params"], {"more": "Y"})
        self.assertEqual(document["actions"][0]["method"], "POST")
        self.assertEqual(document["actions"][0]["params"], {"labNo": "L1"})

    def test_admissions_are_extracted_in_display_order(self):
        body = b"""
        <table><tr><th>Case</th></tr>
        <tr><td><a href="/mobile/patAdmCase/ipdShowsearch?hhisnum=0000012345&amp;hcaseno=C2">new</a></td></tr>
        <tr><td><a href="/mobile/patAdmCase/ipdShowsearch?hhisnum=0000012345&amp;hcaseno=C1">old</a></td></tr>
        </table>
        """
        response = MobileResponse(200, BASE + "/mobile/patAdmCase/listbysearch", "text/html", body)
        admissions = extract_admissions(response)

        self.assertEqual([item.index for item in admissions], [0, 1])
        self.assertEqual(admissions[0].case_no, "C2")
        self.assertIn("new", admissions[0].summary)

    def test_page_show_and_menubar_are_scoped(self):
        body = """
        <div id="outside">do not include</div>
        <div id="page-show"><b>Chart:</b> 0000012345<div>Ward H1</div></div>
        <div id="Menubar"><ul>
          <li><a href="/mobile/lab/query?id=2">檢驗</a></li>
          <li><a href="javascript: return false;" onclick="tprQuery();">TPR</a></li>
        </ul></div>
        """.encode()
        response = MobileResponse(200, BASE + "/mobile/", "text/html", body)

        basic = extract_element_document(response, "page-show")
        tabs = extract_menubar_tabs(response)

        self.assertTrue(basic["found"])
        self.assertIn("Chart:", basic["text"])
        self.assertNotIn("do not include", basic["text"])
        self.assertEqual([item["section"] for item in tabs], ["laboratory", "tpr"])

    def test_ajax_contract_handles_variable_values_without_executing_them(self):
        action = _ajax_action(
            "jQuery.ajax({type:'POST', data:{pomrIdx: rowId}, url:'/mobile/pomr/detail'})",
            BASE,
        )
        self.assertEqual(action["params"], {"pomrIdx": "<rowId>"})

    def test_cross_origin_urls_are_blocked(self):
        with self.assertRaises(ReadOnlyViolation):
            _safe_internal_url(BASE, "https://example.com/mobile/lab/query")

    def test_logout_and_write_routes_are_not_in_catalog(self):
        routes = {(item["method"], item["path"]) for item in route_catalog()}
        self.assertNotIn(("GET", "/mobile/user/logout"), routes)
        self.assertFalse(any("delete" in path.lower() for _, path in routes))


if __name__ == "__main__":
    unittest.main()
