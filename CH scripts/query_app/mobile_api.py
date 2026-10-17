"""Read-only client for the C hospital mobile rounding system.

The upstream application is an HTML/Grails application rather than a JSON API.
This module provides a small authenticated API facade, a generic HTML-to-JSON
normalizer, and strict allowlists for the query-only GET/POST endpoints observed
on the live system.

Credentials are intentionally kept in memory only.  The server itself is HTTP,
so callers should use this client only on a trusted hospital network.
"""

from __future__ import annotations

import argparse
import html
import http.cookiejar
import json
import re
import sys
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qsl, urlencode, urljoin, urlsplit, urlunsplit
from urllib.request import HTTPCookieProcessor, Request, build_opener


DEFAULT_BASE_URL = "http://im.hospital-c.local:8080"
DEFAULT_TIMEOUT = 30.0


class MobileAPIError(RuntimeError):
    """Base error for mobile API operations."""


class AuthenticationError(MobileAPIError):
    """Raised when login fails or an authenticated session expires."""


class ReadOnlyViolation(MobileAPIError):
    """Raised before a request that is outside the read-only contract."""


class QueryError(MobileAPIError):
    """Raised for invalid chart, admission, section, or response data."""


# Each entry is (HTTP method, path): permitted parameter names.  POST is used by
# this old application for many AJAX reads; no create/update/delete endpoint is
# present here.  Login is handled separately and logout is deliberately absent.
READ_ONLY_CONTRACTS: dict[tuple[str, str], frozenset[str]] = {
    ("GET", "/mobile/"): frozenset(),
    ("GET", "/mobile/patAdmCase/index"): frozenset(),
    ("GET", "/mobile/patAdmCase/list"): frozenset({"doctorNo"}),
    ("GET", "/mobile/patAdmCase/listBySta"): frozenset({"hnursta"}),
    ("GET", "/mobile/patAdmCase/ipdShowsearch"): frozenset({"hhisnum", "hcaseno"}),
    ("POST", "/mobile/patAdmCase/listbysearch"): frozenset({"hhisnum", "patNoYN", "search"}),
    ("GET", "/mobile/ptIdeOrderItem/index"): frozenset({"id"}),
    ("GET", "/mobile/lab/query"): frozenset({"id", "more"}),
    ("POST", "/mobile/lab/query"): frozenset({"more"}),
    ("POST", "/mobile/lab/show"): frozenset({"labNo"}),
    ("GET", "/mobile/lab/accumulate"): frozenset({"CASENO", "ID", "LABNO"}),
    ("GET", "/mobile/lap/list"): frozenset({"id", "more"}),
    ("POST", "/mobile/lap/detail"): frozenset({"lapIdx"}),
    ("GET", "/mobile/exam/index"): frozenset({"id"}),
    ("GET", "/mobile/exam/query"): frozenset({"more"}),
    ("POST", "/mobile/exam/query"): frozenset({"more"}),
    ("GET", "/mobile/xray/index"): frozenset({"id", "more"}),
    ("POST", "/mobile/xray/index"): frozenset({"more"}),
    ("POST", "/mobile/xray/show"): frozenset({"applyNo"}),
    ("GET", "/mobile/gcs/query"): frozenset({"id", "more"}),
    ("POST", "/mobile/gcs/query"): frozenset({"more"}),
    ("GET", "/mobile/admissionNote/query"): frozenset({"id"}),
    ("GET", "/mobile/dischargeNote/query"): frozenset({"id", "more"}),
    ("POST", "/mobile/dischargeNote/query"): frozenset({"more"}),
    ("GET", "/mobile/nursingNote/query"): frozenset({"id"}),
    ("GET", "/mobile/consult/query"): frozenset({"id"}),
    ("POST", "/mobile/consult/show"): frozenset(
        {"chartNo", "admitNo", "applyDate", "applyTime"}
    ),
    ("GET", "/mobile/pomr/list"): frozenset({"id", "more"}),
    ("POST", "/mobile/pomr/list"): frozenset({"more"}),
    ("POST", "/mobile/pomr/detail"): frozenset({"pomrIdx"}),
    ("GET", "/mobile/pomr/listproblem"): frozenset(),
    ("POST", "/mobile/pomr/listproblem"): frozenset(),
    ("GET", "/mobile/pomr/listMproblem"): frozenset({"more"}),
    ("POST", "/mobile/pomr/listMproblem"): frozenset({"more"}),
    ("GET", "/mobile/examSch/query"): frozenset({"id"}),
    ("GET", "/mobile/tpr/chart"): frozenset({"CASENO", "ID", "TPRIO"}),
}


SECTION_PATHS: dict[str, str] = {
    "orders": "/mobile/ptIdeOrderItem/index",
    "laboratory": "/mobile/lab/query",
    "pathology": "/mobile/lap/list",
    "exam": "/mobile/exam/index",
    "xray": "/mobile/xray/index",
    "tpr": "/mobile/tpr/chart",
    "gcs": "/mobile/gcs/query",
    "admission-note": "/mobile/admissionNote/query",
    "discharge-note": "/mobile/dischargeNote/query",
    "nursing-note": "/mobile/nursingNote/query",
    "consult": "/mobile/consult/query",
    "pomr": "/mobile/pomr/list",
    "exam-schedule": "/mobile/examSch/query",
}


def load_env_file(path: str | Path) -> dict[str, str]:
    """Read a small dotenv file without mutating process environment."""
    values: dict[str, str] = {}
    env_path = Path(path)
    if not env_path.is_file():
        raise MobileAPIError(f"Environment file not found: {env_path}")
    for raw_line in env_path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        values[key.strip()] = value
    return values


def credentials_from_env(path: str | Path = ".env") -> tuple[str, str]:
    values = load_env_file(path)
    username = values.get("user") or values.get("MOBILE_USER") or ""
    password = values.get("pw") or values.get("MOBILE_PASSWORD") or ""
    if not username or not password:
        raise MobileAPIError(
            f"{path} must define user/pw (or MOBILE_USER/MOBILE_PASSWORD)"
        )
    return username, password


def normalize_chart_no(value: str) -> str:
    chart_no = value.strip()
    if not chart_no.isdigit() or not 1 <= len(chart_no) <= 10:
        raise QueryError("chart number must contain 1 to 10 digits")
    return chart_no.zfill(10)


def _normalize_space(value: str) -> str:
    return " ".join(html.unescape(value).replace("\xa0", " ").split())


def _safe_internal_url(base_url: str, target: str) -> str:
    absolute = urljoin(base_url.rstrip("/") + "/", target)
    base = urlsplit(base_url)
    parsed = urlsplit(absolute)
    if (parsed.scheme.lower(), parsed.netloc.lower()) != (
        base.scheme.lower(),
        base.netloc.lower(),
    ):
        raise ReadOnlyViolation("cross-origin requests are not allowed")
    return urlunsplit((parsed.scheme, parsed.netloc, parsed.path, parsed.query, ""))


def _query_dict(url: str) -> dict[str, str]:
    return dict(parse_qsl(urlsplit(url).query, keep_blank_values=True))


def _parse_js_value(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return html.unescape(value[1:-1].replace("\\'", "'").replace('\\"', '"'))
    return f"<{value}>"


def _ajax_action(attribute_value: str, base_url: str) -> dict[str, Any] | None:
    if "ajax" not in attribute_value.lower() or "/mobile/" not in attribute_value:
        return None
    url_match = re.search(r"url\s*:\s*['\"]([^'\"]+)['\"]", attribute_value, re.I)
    if not url_match:
        return None
    method_match = re.search(r"type\s*:\s*['\"]([^'\"]+)['\"]", attribute_value, re.I)
    data_match = re.search(r"data\s*:\s*\{([^}]*)\}", attribute_value, re.I | re.S)
    params: dict[str, str] = {}
    if data_match:
        pair_pattern = re.compile(
            r"(?:['\"]([^'\"]+)['\"]|([A-Za-z_$][\w$]*))\s*:\s*"
            r"((?:['\"][^'\"]*['\"])|(?:[^,}]+))"
        )
        for match in pair_pattern.finditer(data_match.group(1)):
            key = match.group(1) or match.group(2)
            params[key] = _parse_js_value(match.group(3))
    target = _safe_internal_url(base_url, url_match.group(1))
    return {
        "method": (method_match.group(1) if method_match else "GET").upper(),
        "path": urlsplit(target).path,
        "params": params,
    }


class _DocumentParser(HTMLParser):
    """Loss-minimizing parser for the application's irregular HTML fragments."""

    _break_tags = {
        "br", "div", "p", "li", "tr", "section", "article", "header", "footer",
        "h1", "h2", "h3", "h4", "h5", "h6", "table", "ul", "ol", "pre",
    }

    def __init__(self, base_url: str):
        super().__init__(convert_charrefs=True)
        self.base_url = base_url
        self.title_parts: list[str] = []
        self._in_title = False
        self._skip_depth = 0
        self._text_parts: list[str] = []
        self.headings: list[dict[str, str]] = []
        self._heading: tuple[str, list[str]] | None = None
        self.links: list[dict[str, Any]] = []
        self._link: dict[str, Any] | None = None
        self.actions: list[dict[str, Any]] = []
        self.tables: list[dict[str, Any]] = []
        self._table: dict[str, Any] | None = None
        self._row: list[str] | None = None
        self._cell: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        attr_map = {key.lower(): value or "" for key, value in attrs}
        if tag in {"script", "style"}:
            self._skip_depth += 1
            return
        if self._skip_depth:
            return
        if tag == "title":
            self._in_title = True
        if tag in self._break_tags:
            self._text_parts.append("\n")
        if tag in {"h1", "h2", "h3", "h4", "h5", "h6"}:
            self._heading = (tag, [])
        if tag == "a" and attr_map.get("href"):
            try:
                href = _safe_internal_url(self.base_url, attr_map["href"])
            except ReadOnlyViolation:
                href = attr_map["href"]
            self._link = {"url": href, "text_parts": []}
        for value in attr_map.values():
            action = _ajax_action(value, self.base_url)
            if action and action not in self.actions:
                self.actions.append(action)
        if tag == "table":
            self._table = {"rows": []}
        elif tag == "tr" and self._table is not None:
            self._row = []
        elif tag in {"th", "td"} and self._row is not None:
            self._cell = []

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in {"script", "style"}:
            self._skip_depth = max(0, self._skip_depth - 1)
            return
        if self._skip_depth:
            return
        if tag == "title":
            self._in_title = False
        if tag == "a" and self._link is not None:
            url = self._link["url"]
            parsed = urlsplit(url)
            if parsed.path.startswith("/mobile/") and "/assets/" not in parsed.path:
                self.links.append(
                    {
                        "text": _normalize_space("".join(self._link["text_parts"])),
                        "path": parsed.path,
                        "params": dict(parse_qsl(parsed.query, keep_blank_values=True)),
                    }
                )
            self._link = None
        if tag in {"h1", "h2", "h3", "h4", "h5", "h6"} and self._heading:
            self.headings.append(
                {"level": self._heading[0], "text": _normalize_space("".join(self._heading[1]))}
            )
            self._heading = None
        if tag in {"th", "td"} and self._cell is not None and self._row is not None:
            self._row.append(_normalize_space("".join(self._cell)))
            self._cell = None
        elif tag == "tr" and self._row is not None and self._table is not None:
            if any(self._row):
                self._table["rows"].append(self._row)
            self._row = None
        elif tag == "table" and self._table is not None:
            self.tables.append(self._table)
            self._table = None
        if tag in self._break_tags:
            self._text_parts.append("\n")

    def handle_data(self, data: str) -> None:
        if self._skip_depth:
            return
        if self._in_title:
            self.title_parts.append(data)
        self._text_parts.append(data)
        if self._heading is not None:
            self._heading[1].append(data)
        if self._link is not None:
            self._link["text_parts"].append(data)
        if self._cell is not None:
            self._cell.append(data)

    def visible_text(self) -> str:
        lines = []
        for line in "".join(self._text_parts).splitlines():
            cleaned = _normalize_space(line)
            if cleaned:
                lines.append(cleaned)
        return "\n".join(lines)


class _ElementCapture(HTMLParser):
    """Capture one element by id while respecting nested elements of its tag."""

    def __init__(self, element_id: str, tag: str = "div") -> None:
        super().__init__(convert_charrefs=False)
        self.element_id = element_id.casefold()
        self.tag = tag.casefold()
        self.depth = 0
        self.parts: list[str] = []

    @property
    def capturing(self) -> bool:
        return self.depth > 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.casefold()
        attr_map = {key.casefold(): value or "" for key, value in attrs}
        if not self.capturing:
            if tag != self.tag or attr_map.get("id", "").casefold() != self.element_id:
                return
            self.depth = 1
            self.parts.append(self.get_starttag_text())
            return
        self.parts.append(self.get_starttag_text())
        if tag == self.tag:
            self.depth += 1

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if self.capturing:
            self.parts.append(self.get_starttag_text())

    def handle_endtag(self, tag: str) -> None:
        if not self.capturing:
            return
        self.parts.append(f"</{tag}>")
        if tag.casefold() == self.tag:
            self.depth -= 1

    def handle_data(self, data: str) -> None:
        if self.capturing:
            self.parts.append(data)

    def handle_entityref(self, name: str) -> None:
        if self.capturing:
            self.parts.append(f"&{name};")

    def handle_charref(self, name: str) -> None:
        if self.capturing:
            self.parts.append(f"&#{name};")

    def fragment(self) -> str:
        return "".join(self.parts)


@dataclass(frozen=True)
class MobileResponse:
    status: int
    url: str
    content_type: str
    body: bytes

    @property
    def text(self) -> str:
        # All observed pages declare UTF-8, including text/plan fragments.
        return self.body.decode("utf-8", errors="replace")

    def document(self) -> dict[str, Any]:
        parser = _DocumentParser(self.url)
        parser.feed(self.text)
        return {
            "status": self.status,
            "path": urlsplit(self.url).path,
            "content_type": self.content_type,
            "title": _normalize_space("".join(parser.title_parts)),
            "headings": [item for item in parser.headings if item["text"]],
            "tables": parser.tables,
            "links": parser.links,
            "actions": parser.actions,
            "text": parser.visible_text(),
        }


@dataclass(frozen=True)
class Admission:
    index: int
    chart_no: str
    case_no: str
    summary: str
    url: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "index": self.index,
            "chart_no": self.chart_no,
            "case_no": self.case_no,
            "summary": self.summary,
        }


@dataclass(frozen=True)
class AdmissionContext:
    admission: Admission
    dashboard: MobileResponse
    patient_basic_info: dict[str, Any]
    tabs: list[dict[str, Any]]


def _capture_element_html(response: MobileResponse, element_id: str) -> str:
    capture = _ElementCapture(element_id)
    capture.feed(response.text)
    return capture.fragment()


def extract_element_document(response: MobileResponse, element_id: str) -> dict[str, Any]:
    """Normalize one div from a response, notably #page-show and #Menubar."""
    fragment = _capture_element_html(response, element_id)
    if not fragment:
        return {"found": False, "id": element_id, "text": "", "tables": [], "links": [], "actions": []}
    fragment_response = MobileResponse(
        status=response.status,
        url=response.url,
        content_type=response.content_type,
        body=fragment.encode("utf-8"),
    )
    document = fragment_response.document()
    document["found"] = True
    document["id"] = element_id
    return document


def extract_menubar_tabs(response: MobileResponse) -> list[dict[str, Any]]:
    """Return patient data tabs, in their actual div#Menubar display order."""
    fragment = _capture_element_html(response, "Menubar")
    if not fragment:
        return []
    path_to_section = {path: name for name, path in SECTION_PATHS.items()}
    tabs: list[dict[str, Any]] = []
    for match in re.finditer(r"<a\b([^>]*)>(.*?)</a>", fragment, re.I | re.S):
        attrs = {
            key.casefold(): html.unescape(value)
            for key, _, value in re.findall(
                r"([\w:-]+)\s*=\s*(['\"])(.*?)\2", match.group(1), re.I | re.S
            )
        }
        label = _normalize_space(re.sub(r"<[^>]+>", " ", match.group(2)))
        href = attrs.get("href", "")
        onclick = attrs.get("onclick", "")
        path = ""
        params: dict[str, str] = {}
        if href and not href.lower().startswith("javascript:"):
            target = _safe_internal_url(response.url, href)
            path = urlsplit(target).path
            params = _query_dict(target)
        elif re.search(r"\btprQuery\s*\(", onclick):
            path = SECTION_PATHS["tpr"]
        section = path_to_section.get(path)
        if section:
            tabs.append(
                {
                    "section": section,
                    "label": label,
                    "method": "GET",
                    "path": path,
                    "params": params,
                }
            )
    return tabs


def extract_admissions(response: MobileResponse) -> list[Admission]:
    """Extract admission selectors and their enclosing result-row text."""
    admissions: list[Admission] = []
    seen: set[str] = set()
    for row_match in re.finditer(r"<tr\b.*?</tr>", response.text, re.I | re.S):
        row_html = row_match.group(0)
        href_match = re.search(
            r"href=['\"]([^'\"]*?/mobile/patAdmCase/ipdShowsearch\?[^'\"]+)['\"]",
            row_html,
            re.I,
        )
        if not href_match:
            continue
        url = _safe_internal_url(response.url, html.unescape(href_match.group(1)))
        if url in seen:
            continue
        seen.add(url)
        params = _query_dict(url)
        row_parser = _DocumentParser(response.url)
        row_parser.feed(row_html)
        admissions.append(
            Admission(
                index=len(admissions),
                chart_no=params.get("hhisnum", ""),
                case_no=params.get("hcaseno", ""),
                summary=row_parser.visible_text(),
                url=url,
            )
        )
    return admissions


class MobileClient:
    """Stateful, cookie-backed, read-only API client."""

    def __init__(
        self,
        username: str,
        password: str,
        *,
        base_url: str = DEFAULT_BASE_URL,
        timeout: float = DEFAULT_TIMEOUT,
        opener: Any | None = None,
    ) -> None:
        if not username or not password:
            raise MobileAPIError("username and password are required")
        parsed = urlsplit(base_url)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise MobileAPIError("base URL must be an absolute HTTP(S) URL")
        self.username = username
        self._password = password
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self._cookie_jar = http.cookiejar.CookieJar()
        self._opener = opener or build_opener(HTTPCookieProcessor(self._cookie_jar))
        self._authenticated = False
        self.last_context: AdmissionContext | None = None

    @property
    def uses_plaintext_http(self) -> bool:
        return urlsplit(self.base_url).scheme.lower() == "http"

    def login(self) -> MobileResponse:
        payload = {
            "clerkId": self.username,
            "passwd": self._password,
            "_action_authenticate": "login",
        }
        response = self._send(
            "POST",
            "/mobile/user/index",
            data=payload,
            referer="/mobile/user/login",
            enforce_contract=False,
        )
        if urlsplit(response.url).path.endswith("/user/login") or 'id="loginForm"' in response.text:
            raise AuthenticationError("mobile system rejected the credentials")
        self._authenticated = True
        return response

    def request(
        self,
        method: str,
        target: str,
        *,
        params: Mapping[str, str] | None = None,
        data: Mapping[str, str] | None = None,
        referer: str | None = None,
    ) -> MobileResponse:
        if not self._authenticated:
            self.login()
        return self._send(method, target, params=params, data=data, referer=referer)

    def _send(
        self,
        method: str,
        target: str,
        *,
        params: Mapping[str, str] | None = None,
        data: Mapping[str, str] | None = None,
        referer: str | None = None,
        enforce_contract: bool = True,
    ) -> MobileResponse:
        method = method.upper()
        url = _safe_internal_url(self.base_url, target)
        existing = dict(parse_qsl(urlsplit(url).query, keep_blank_values=True))
        request_params = {**existing, **dict(params or {})}
        request_data = dict(data or {})
        supplied_keys = set(request_params) | set(request_data)
        path = urlsplit(url).path
        if enforce_contract:
            allowed = READ_ONLY_CONTRACTS.get((method, path))
            if allowed is None:
                raise ReadOnlyViolation(f"blocked non-allowlisted request: {method} {path}")
            unknown = supplied_keys - allowed
            if unknown:
                raise ReadOnlyViolation(
                    f"blocked unexpected parameters for {method} {path}: {', '.join(sorted(unknown))}"
                )
        parsed = urlsplit(url)
        query = urlencode(request_params)
        url = urlunsplit((parsed.scheme, parsed.netloc, parsed.path, query, ""))
        body = urlencode(request_data).encode("utf-8") if method == "POST" else None
        headers = {
            "User-Agent": "CH-mobile-readonly-cli/1.0",
            "Accept": "text/html, text/plain;q=0.9, */*;q=0.1",
        }
        if method == "POST":
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        if referer:
            headers["Referer"] = _safe_internal_url(self.base_url, referer)
        request = Request(url, data=body, headers=headers, method=method)
        try:
            with self._opener.open(request, timeout=self.timeout) as result:
                final_url = result.url
                _safe_internal_url(self.base_url, final_url)
                response = MobileResponse(
                    status=result.status,
                    url=final_url,
                    content_type=result.headers.get("Content-Type", ""),
                    body=result.read(),
                )
        except HTTPError as exc:
            raise MobileAPIError(f"HTTP {exc.code} for {method} {path}") from exc
        except URLError as exc:
            raise MobileAPIError(f"network error for {method} {path}: {exc.reason}") from exc
        if enforce_contract and (
            urlsplit(response.url).path.endswith("/user/login") or 'id="loginForm"' in response.text
        ):
            self._authenticated = False
            raise AuthenticationError("authenticated session expired or was rejected")
        return response

    def search_admissions(self, chart_no: str) -> tuple[MobileResponse, list[Admission]]:
        chart_no = normalize_chart_no(chart_no)
        response = self.request(
            "POST",
            "/mobile/patAdmCase/listbysearch",
            data={"hhisnum": chart_no, "patNoYN": "Y"},
            referer="/mobile/",
        )
        return response, extract_admissions(response)

    def select_admission(self, chart_no: str, index: int = 0) -> Admission:
        _, admissions = self.search_admissions(chart_no)
        if not admissions:
            raise QueryError(f"no admissions found for chart {normalize_chart_no(chart_no)}")
        if index < 0 or index >= len(admissions):
            raise QueryError(f"admission index must be between 0 and {len(admissions) - 1}")
        admission = admissions[index]
        self.request("GET", admission.url, referer="/mobile/patAdmCase/listbysearch")
        return admission

    def dashboard(self) -> MobileResponse:
        return self.request("GET", "/mobile/")

    def enter_admission(self, chart_no: str, index: int = 0) -> AdmissionContext:
        """Enter a search-result row, then read #page-show and #Menubar."""
        admission = self.select_admission(chart_no, index)
        dashboard = self.dashboard()
        context = AdmissionContext(
            admission=admission,
            dashboard=dashboard,
            patient_basic_info=extract_element_document(dashboard, "page-show"),
            tabs=extract_menubar_tabs(dashboard),
        )
        self.last_context = context
        return context

    def _section_urls(self, context: AdmissionContext) -> dict[str, str]:
        resolved: dict[str, str] = {}
        for tab in context.tabs:
            params = dict(tab["params"])
            if tab["section"] == "tpr":
                params = {
                    "CASENO": context.admission.case_no,
                    "ID": self.username,
                    "TPRIO": "Y",
                }
            query = urlencode(params)
            resolved[tab["section"]] = tab["path"] + (f"?{query}" if query else "")
        return resolved

    def query_section(
        self, chart_no: str, section: str, *, admission_index: int = 0
    ) -> tuple[Admission, MobileResponse]:
        if section not in SECTION_PATHS:
            raise QueryError(f"unknown section: {section}")
        context = self.enter_admission(chart_no, admission_index)
        section_urls = self._section_urls(context)
        if section not in section_urls:
            raise QueryError(f"section is not available for this login: {section}")
        return context.admission, self.request("GET", section_urls[section], referer="/mobile/")

    def query_all_sections(
        self, chart_no: str, *, admission_index: int = 0
    ) -> tuple[Admission, dict[str, MobileResponse]]:
        context = self.enter_admission(chart_no, admission_index)
        section_urls = self._section_urls(context)
        responses: dict[str, MobileResponse] = {}
        for section in SECTION_PATHS:
            if section in section_urls:
                responses[section] = self.request(
                    "GET", section_urls[section], referer="/mobile/"
                )
        return context.admission, responses

    def query_tpr(
        self, chart_no: str, *, admission_index: int = 0
    ) -> tuple[Admission, MobileResponse]:
        admission = self.select_admission(chart_no, admission_index)
        response = self.request(
            "GET",
            "/mobile/tpr/chart",
            params={"CASENO": admission.case_no, "ID": self.username, "TPRIO": "Y"},
        )
        return admission, response

    def query_lab_accumulate(
        self, chart_no: str, lab_no: str, *, admission_index: int = 0
    ) -> tuple[Admission, MobileResponse]:
        admission = self.select_admission(chart_no, admission_index)
        response = self.request(
            "GET",
            "/mobile/lab/accumulate",
            params={"CASENO": admission.case_no, "ID": self.username, "LABNO": lab_no},
        )
        return admission, response


def route_catalog() -> list[dict[str, Any]]:
    return [
        {"method": method, "path": path, "parameters": sorted(parameters)}
        for (method, path), parameters in sorted(READ_ONLY_CONTRACTS.items())
    ]


def _parse_key_values(items: Iterable[str]) -> dict[str, str]:
    values: dict[str, str] = {}
    for item in items:
        if "=" not in item:
            raise QueryError(f"parameter must be KEY=VALUE: {item}")
        key, value = item.split("=", 1)
        if not key:
            raise QueryError(f"parameter key is empty: {item}")
        values[key] = value
    return values


def _response_payload(response: MobileResponse, output_format: str) -> str | dict[str, Any]:
    if output_format == "html":
        return response.text
    if output_format == "text":
        return response.document()["text"]
    return response.document()


def _serialize(value: Any, output_format: str, pretty: bool) -> str:
    if isinstance(value, str):
        return value
    return json.dumps(value, ensure_ascii=False, indent=2 if pretty else None)


def _write_output(content: str, output: str | None) -> None:
    if output:
        Path(output).write_text(content, encoding="utf-8")
    else:
        print(content)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="CH-mobile",
        description="Read-only CLI/API client for the C hospital mobile rounding system",
    )
    parser.add_argument("--env-file", default=".env", help="dotenv file (default: .env)")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT)
    parser.add_argument("--format", choices=("json", "text", "html"), default="json")
    parser.add_argument("--output", help="write UTF-8 output to a file instead of stdout")
    parser.add_argument("--compact", action="store_true", help="compact JSON")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("auth", help="verify credentials without querying a patient")
    sub.add_parser("routes", help="list the enforced read-only route contracts")

    admissions = sub.add_parser("admissions", help="list admissions for a chart")
    admissions.add_argument("chart_no")

    tabs = sub.add_parser(
        "tabs", help="enter an admission row and list #page-show plus #Menubar tabs"
    )
    tabs.add_argument("chart_no")
    tabs.add_argument("--admission-index", type=int, default=0)

    section = sub.add_parser("section", help="query one top-level patient section")
    section.add_argument("chart_no")
    section.add_argument("section", choices=tuple(SECTION_PATHS))
    section.add_argument("--admission-index", type=int, default=0)

    all_sections = sub.add_parser("all", help="query all top-level patient sections")
    all_sections.add_argument("chart_no")
    all_sections.add_argument("--admission-index", type=int, default=0)

    fetch = sub.add_parser("fetch", help="call any allowlisted read endpoint")
    fetch.add_argument("chart_no", help="chart used to initialize the admission session")
    fetch.add_argument("path", help="allowlisted /mobile/... path")
    fetch.add_argument("--method", choices=("GET", "POST"), default="GET")
    fetch.add_argument("--param", action="append", default=[], metavar="KEY=VALUE")
    fetch.add_argument("--admission-index", type=int, default=0)

    tpr = sub.add_parser("tpr", help="query the selected admission's TPR/IO chart")
    tpr.add_argument("chart_no")
    tpr.add_argument("--admission-index", type=int, default=0)

    accumulate = sub.add_parser("lab-accumulate", help="query cumulative lab data")
    accumulate.add_argument("chart_no")
    accumulate.add_argument("lab_no")
    accumulate.add_argument("--admission-index", type=int, default=0)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.command == "routes":
            payload: Any = {"read_only_routes": route_catalog(), "sections": SECTION_PATHS}
        else:
            username, password = credentials_from_env(args.env_file)
            client = MobileClient(
                username,
                password,
                base_url=args.base_url,
                timeout=args.timeout,
            )
            if client.uses_plaintext_http:
                print(
                    "WARNING: the upstream server uses plaintext HTTP; credentials and patient data "
                    "are not encrypted in transit.",
                    file=sys.stderr,
                )
            if args.command == "auth":
                response = client.login()
                auth_payload = {
                    "authenticated": True,
                    "status": response.status,
                    "path": urlsplit(response.url).path,
                    "cookie_names": sorted(cookie.name for cookie in client._cookie_jar),
                }
                payload = "authenticated\n" if args.format == "text" else auth_payload
            elif args.command == "admissions":
                _, admissions = client.search_admissions(args.chart_no)
                admissions_payload = {
                    "chart_no": normalize_chart_no(args.chart_no),
                    "count": len(admissions),
                    "admissions": [item.as_dict() for item in admissions],
                }
                if args.format == "html":
                    raise QueryError("HTML format is not available for 'admissions'")
                payload = (
                    "\n\n".join(
                        f"[{item.index}] case {item.case_no}\n{item.summary}" for item in admissions
                    )
                    if args.format == "text"
                    else admissions_payload
                )
            elif args.command == "tabs":
                if args.format == "html":
                    raise QueryError("HTML format is not available for 'tabs'")
                context = client.enter_admission(args.chart_no, args.admission_index)
                if args.format == "text":
                    tab_lines = "\n".join(
                        f"{item['section']}: {item['label']}" for item in context.tabs
                    )
                    payload = f"{context.patient_basic_info['text']}\n\n{tab_lines}"
                else:
                    payload = {
                        "admission": context.admission.as_dict(),
                        "patient_basic_info": context.patient_basic_info,
                        "tabs": context.tabs,
                    }
            elif args.command == "section":
                admission, response = client.query_section(
                    args.chart_no, args.section, admission_index=args.admission_index
                )
                response_payload = _response_payload(response, args.format)
                payload = (
                    {
                        "admission": admission.as_dict(),
                        "patient_basic_info": client.last_context.patient_basic_info,
                        "section": args.section,
                        "response": response_payload,
                    }
                    if args.format == "json"
                    else response_payload
                )
            elif args.command == "all":
                if args.format == "html":
                    raise QueryError("HTML format is ambiguous for 'all'; use json or text")
                admission, responses = client.query_all_sections(
                    args.chart_no, admission_index=args.admission_index
                )
                if args.format == "text":
                    payload = "\n\n".join(
                        f"===== {name} =====\n{response.document()['text']}"
                        for name, response in responses.items()
                    )
                else:
                    payload = {
                        "admission": admission.as_dict(),
                        "patient_basic_info": client.last_context.patient_basic_info,
                        "sections": {
                            name: _response_payload(response, args.format)
                            for name, response in responses.items()
                        },
                    }
            elif args.command == "fetch":
                admission = client.select_admission(args.chart_no, args.admission_index)
                values = _parse_key_values(args.param)
                response = client.request(
                    args.method,
                    args.path,
                    params=values if args.method == "GET" else None,
                    data=values if args.method == "POST" else None,
                    referer="/mobile/",
                )
                response_payload = _response_payload(response, args.format)
                payload = (
                    {"admission": admission.as_dict(), "response": response_payload}
                    if args.format == "json"
                    else response_payload
                )
            elif args.command == "tpr":
                admission, response = client.query_tpr(
                    args.chart_no, admission_index=args.admission_index
                )
                response_payload = _response_payload(response, args.format)
                payload = (
                    {"admission": admission.as_dict(), "response": response_payload}
                    if args.format == "json"
                    else response_payload
                )
            elif args.command == "lab-accumulate":
                admission, response = client.query_lab_accumulate(
                    args.chart_no, args.lab_no, admission_index=args.admission_index
                )
                response_payload = _response_payload(response, args.format)
                payload = (
                    {"admission": admission.as_dict(), "response": response_payload}
                    if args.format == "json"
                    else response_payload
                )
            else:  # pragma: no cover - argparse guarantees this
                parser.error("unknown command")
                return 2
        content = _serialize(payload, args.format, pretty=not args.compact)
        _write_output(content, args.output)
        return 0
    except (MobileAPIError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
