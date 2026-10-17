"""Client for the dedicated WebRIS cancer-staging recheck endpoint."""

from __future__ import annotations

import os
from datetime import date, datetime
from typing import Any

import requests


class WebRISApiError(RuntimeError):
    pass


class WebRISApi:
    def __init__(self, base_url: str, *, timeout: int = 90):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.session = requests.Session()

    def _json(self, response: requests.Response) -> dict[str, Any]:
        try:
            payload = response.json()
        except ValueError as exc:
            raise WebRISApiError(
                f"WebRIS returned HTTP {response.status_code} with non-JSON body"
            ) from exc
        if not response.ok or payload.get("status") != "ok":
            raise WebRISApiError(
                f"WebRIS HTTP {response.status_code}: {payload.get('message', payload)}"
            )
        return payload

    def login(self, userid: str | None = None, password: str | None = None) -> dict[str, Any]:
        userid = userid if userid is not None else os.environ.get("WEBRIS_USER")
        password = password if password is not None else os.environ.get("WEBRIS_PASSWORD")
        body: dict[str, Any] = {"keep_alive": False}
        if userid:
            body["userid"] = userid
        if password:
            body["password"] = password
        payload = self._json(
            self.session.post(
                f"{self.base_url}/api/login", json=body, timeout=self.timeout
            )
        )
        self.session.headers.update({"Authorization": f"Bearer {payload['token']}"})
        return payload

    def logout(self) -> None:
        try:
            self.session.post(f"{self.base_url}/api/logout", timeout=20)
        finally:
            self.session.headers.pop("Authorization", None)

    def status(self) -> dict[str, Any]:
        return self._json(
            self.session.get(f"{self.base_url}/api/status", timeout=self.timeout)
        )

    @staticmethod
    def _ris_date(value: str) -> str:
        for fmt in ("%Y/%m/%d", "%Y-%m-%d", "%Y.%m.%d", "%m/%d/%Y"):
            try:
                return datetime.strptime(value, fmt).strftime("%Y/%m/%d")
            except ValueError:
                continue
        raise ValueError(f"Unsupported study date: {value!r}")

    def locate_study(
        self, *, accession: str, chart_no: str, study_date: str
    ) -> dict[str, Any]:
        date = self._ris_date(study_date)
        response = self.session.get(
            f"{self.base_url}/api/worklist",
            params={
                "preset": "ALL_1W",
                "patno": chart_no,
                # Empty status = all statuses; the RIS default ('00') hides
                # already-reported studies, which are exactly the targets here.
                "status": "",
                "checktimestart": date,
                "checktimeend": date,
            },
            timeout=self.timeout,
        )
        payload = self._json(response)
        matches = [
            item
            for item in payload.get("studies", [])
            if str(item.get("acc_no", "")) == str(accession)
            and str(item.get("chart_no", "")).lstrip("0") == str(chart_no).lstrip("0")
        ]
        if len(matches) != 1:
            raise WebRISApiError(
                f"Expected one worklist match for {accession}/{chart_no}; found {len(matches)}"
            )
        current_context = self.status()["list_context_id"]
        return {
            "study": matches[0],
            "list_context_id": current_context,
        }

    def locate_accession(self, accession: str) -> dict[str, Any]:
        """Locate one reported study when only its accession is known."""
        response = self.session.get(
            f"{self.base_url}/api/worklist",
            params={
                "preset": "ALL",
                "referno": accession,
                "status": "",
                "checktimestart": "2000/01/01",
                "checktimeend": date.today().strftime("%Y/%m/%d"),
            },
            timeout=self.timeout,
        )
        payload = self._json(response)
        matches = [
            item
            for item in payload.get("studies", [])
            if str(item.get("acc_no", "")) == str(accession)
        ]
        if len(matches) != 1:
            raise WebRISApiError(
                f"Expected one worklist match for accession {accession}; found {len(matches)}"
            )
        current_context = self.status()["list_context_id"]
        return {
            "study": matches[0],
            "list_context_id": current_context,
        }

    def get_study(self, index: int) -> dict[str, Any]:
        """Load the selected report form for a read-only identity/text check."""
        return self._json(
            self.session.get(
                f"{self.base_url}/api/study/{index}", timeout=self.timeout
            )
        )

    def cancer_staging_recheck(
        self,
        *,
        index: int,
        accession: str,
        chart_no: str,
        list_context_id: int,
        staging_text: str,
        approved_text_sha256: str,
        expected_exam_sha256: str,
        dry_run: bool = True,
        append_newlines: int | None = None,
        allow_url_index_fallback: bool = False,
    ) -> dict[str, Any]:
        body = {
            "acc_no": accession,
            "chart_no": chart_no.zfill(10),
            "list_context_id": list_context_id,
            "staging_text": staging_text,
            "approved_text_sha256": approved_text_sha256,
            "expected_exam_sha256": expected_exam_sha256,
            "dry_run": dry_run,
            "allow_url_index_fallback": allow_url_index_fallback,
        }
        if append_newlines is not None:
            body["append_newlines"] = append_newlines
        return self._json(
            self.session.post(
                f"{self.base_url}/api/study/{index}/cancer-staging",
                json=body,
                timeout=self.timeout,
            )
        )
