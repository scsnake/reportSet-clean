"""
study_client.py - Windows bridge for the breast US OCR HTTP API.

The AHK GUI delegates HTTP and JSON work here because AutoHotkey v1 is brittle
for nested JSON. This script writes:

- study_payload.json: full API response for inspection
- lesions_pending.json: simplified lesion list consumed by ris_annotate.ahk

Exit codes:
  0 ok
  2 not found / not processed yet
  3 service busy
  4 processed but not annotatable, or pipeline error status
  1 transport or unexpected error
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


DEFAULT_SERVER = "http://gpu-host.example.invalid:7205"
SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_PAYLOAD = SCRIPT_DIR / "study_payload.json"
DEFAULT_PENDING = SCRIPT_DIR / "lesions_pending.json"
DEFAULT_SUMMARY = SCRIPT_DIR / "study_status.txt"


class ApiError(Exception):
    def __init__(self, message: str, status_code: int | None = None, payload: dict[str, Any] | None = None):
        super().__init__(message)
        self.status_code = status_code
        self.payload = payload or {}


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def write_summary(path: Path, text: str) -> None:
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def write_state(args: argparse.Namespace, status: str, message: str = "", **extra: Any) -> None:
    payload = {
        "status": status,
        "message": message,
        "requested_accession": args.accession or "",
        "requested_chart_no": args.chart_no or "",
        "requested_study_date": args.study_date or "",
        "lesions": [],
        "side_flags": [],
        "source": "http_api",
    }
    payload.update(extra)
    write_json(args.pending_out, payload)


def request_json(method: str, server: str, path: str, *, params: dict[str, str] | None = None,
                 body: dict[str, Any] | None = None, timeout: int = 90) -> tuple[int, dict[str, Any]]:
    server = server.rstrip("/")
    url = server + path
    if params:
        url += "?" + urlencode(params)
    data = None
    headers = {"Accept": "application/json"}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = Request(url, data=data, headers=headers, method=method.upper())
    try:
        with urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            return resp.status, json.loads(raw) if raw else {}
    except HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            payload = {"status": "error", "message": raw}
        return exc.code, payload
    except (URLError, TimeoutError) as exc:
        raise ApiError(f"HTTP request failed: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ApiError(f"API returned invalid JSON: {exc}") from exc


def choose_ahk_type(lesion: dict[str, Any]) -> str:
    flags = {str(v).upper() for v in lesion.get("flags") or []}
    region = str(lesion.get("region") or "").upper()
    if "LN" in flags or "NODE" in flags or region == "AX":
        return "LN"
    if "CYST" in flags:
        return "CYST"
    if "FA" in flags or "FIBROADENOMA" in flags:
        return "FA"
    if "SCAR" in flags or "BX" in flags or "BIOPSY" in flags:
        return "SC-H"
    return "FCC"


def clean_number(value: Any, digits: int = 1) -> Any:
    if value is None:
        return None
    try:
        rounded = round(float(value), digits)
    except (TypeError, ValueError):
        return value
    if rounded.is_integer():
        return int(rounded)
    return rounded


def dims_text(values: list[Any]) -> str:
    return "x".join(str(clean_number(v)) for v in values)


def side_hint(side: str, side_inferred: bool) -> str:
    if side == "?":
        return "?"
    return f"{side}?" if side_inferred else side


def valid_marker_side(marker: dict[str, Any]) -> str:
    side = str(marker.get("side") or "")
    if side not in {"R", "L"}:
        return ""
    confidence = marker.get("confidence")
    try:
        if confidence is not None and float(confidence) < 0.5:
            return ""
    except (TypeError, ValueError):
        pass
    return side


def clean_int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def normalise_marker(marker: dict[str, Any]) -> dict[str, Any]:
    confidence = marker.get("confidence")
    try:
        confidence = None if confidence is None else round(float(confidence), 2)
    except (TypeError, ValueError):
        confidence = None
    if confidence is not None and confidence < 0.5:
        side = ""
    else:
        side = str(marker.get("side") or "")
    return {
        "frame_index": clean_int(marker.get("frame_index")),
        "model_name": marker.get("model_name") or "",
        "processed_at": marker.get("processed_at") or "",
        "marker_present": marker.get("marker_present"),
        "icon_style": marker.get("icon_style") or "",
        "side": side if side in {"R", "L", "?"} else "",
        "side_source": marker.get("side_source") or "",
        "region": marker.get("region") or "",
        "probe_visible": marker.get("probe_visible"),
        "probe_orientation": marker.get("probe_orientation") or "",
        "angle_deg": clean_number(marker.get("angle_deg")),
        "r_ratio": clean_number(marker.get("r_ratio"), 2),
        "clock_hour": clean_int(marker.get("clock_hour")),
        "confidence": confidence,
        "notes": marker.get("notes") or "",
    }


def markers_for_frames(frame_indices: list[Any], marker_by_frame: dict[int, dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for frame_index in frame_indices:
        idx = clean_int(frame_index)
        if idx is not None and idx in marker_by_frame:
            out.append(marker_by_frame[idx])
    return out


def marker_vote(markers: list[dict[str, Any]]) -> dict[str, Any]:
    votes = {"R": 0, "L": 0}
    for marker in markers:
        side = valid_marker_side(marker)
        if side:
            votes[side] += 1
    if votes["R"] > votes["L"]:
        side = "R"
    elif votes["L"] > votes["R"]:
        side = "L"
    else:
        side = ""
    total = votes["R"] + votes["L"]
    return {
        "side": side,
        "r_count": votes["R"],
        "l_count": votes["L"],
        "total": total,
        "tie": bool(total and votes["R"] == votes["L"]),
    }


def representative_marker(markers: list[dict[str, Any]], side: str = "") -> dict[str, Any] | None:
    candidates = [m for m in markers if not side or valid_marker_side(m) == side]
    if not candidates:
        candidates = markers
    if not candidates:
        return None
    return max(candidates, key=lambda m: (m.get("confidence") or 0, m.get("marker_present") is True))


_PROBE_GLYPHS = {
    "HORIZONTAL": "-", "TRV": "-", "TRA": "-", "TRANS": "-", "TRANSVERSE": "-",
    "VERTICAL": "|", "SAG": "|", "LON": "|", "LONG": "|", "SAGITTAL": "|", "LONGITUDINAL": "|",
    "SLASH": "/", "RAD": "/", "RADIAL": "/",
    "BACKSLASH": "\\", "ANTI": "\\", "ARAD": "\\", "ANTIRAD": "\\", "ANTIRADIAL": "\\",
    "OBL": "/", "OBLIQUE": "/",
}


def probe_glyph(orient: Any) -> str:
    text = str(orient or "").strip()
    if not text:
        return ""
    return _PROBE_GLYPHS.get(text.upper(), text)


def marker_display(marker: dict[str, Any] | None) -> str:
    if not marker:
        return ""
    parts: list[str] = []
    side = marker.get("side") or ""
    if side:
        parts.append(f"G:{side}")
    if marker.get("clock_hour") is not None:
        parts.append(f"clk={marker['clock_hour']}")
    if marker.get("probe_orientation"):
        parts.append(probe_glyph(marker["probe_orientation"]))
    if marker.get("region"):
        parts.append(str(marker["region"]))
    if marker.get("confidence") is not None:
        parts.append(f"c={marker['confidence']}")
    return " ".join(parts)


def marker_region_code(marker: dict[str, Any] | None) -> str:
    if not marker:
        return ""
    region = str(marker.get("region") or "").lower()
    if region == "axilla":
        return "AX"
    if region == "scv":
        return "SCV"
    return ""


def frame_marker_side_summary(markers: list[dict[str, Any]]) -> str:
    counts = {"R": 0, "L": 0}
    for marker in markers:
        side = valid_marker_side(marker)
        if side:
            counts[side] += 1
    if counts["R"] and counts["L"]:
        return f"bilateral R={counts['R']} L={counts['L']}"
    if counts["R"]:
        return f"R={counts['R']}"
    if counts["L"]:
        return f"L={counts['L']}"
    return ""


def marker_fields(markers: list[dict[str, Any]], vote: dict[str, Any] | None = None) -> dict[str, Any]:
    vote = vote or marker_vote(markers)
    marker = representative_marker(markers, vote.get("side") or "")
    vote_text = ""
    if vote.get("total"):
        vote_text = f"R={vote['r_count']} L={vote['l_count']}"
    frame_text = ",".join(str(m.get("frame_index")) for m in markers if m.get("frame_index") is not None)
    return {
        "marker_frame_index": marker.get("frame_index") if marker else None,
        "marker_frame_indices_text": frame_text,
        "marker_side": marker.get("side") if marker else "",
        "marker_vote_side": vote.get("side") or "",
        "marker_vote_text": vote_text,
        "marker_vote_tie": vote.get("tie") or False,
        "marker_side_source": marker.get("side_source") if marker else "",
        "marker_region": marker.get("region") if marker else "",
        "marker_clock_hour": marker.get("clock_hour") if marker else None,
        "marker_probe_orientation": marker.get("probe_orientation") if marker else "",
        "marker_confidence": marker.get("confidence") if marker else None,
        "marker_text": marker_display(marker),
    }


def normalise_study(api_payload: dict[str, Any]) -> dict[str, Any]:
    study = api_payload.get("study") or {}
    frame_markers_out = [normalise_marker(item) for item in study.get("frame_markers") or []]
    marker_by_frame = {
        item["frame_index"]: item
        for item in frame_markers_out
        if item.get("frame_index") is not None
    }
    lesions_out: list[dict[str, Any]] = []
    for lesion in study.get("lesions") or []:
        raw_side = str(lesion.get("side") or "?")
        side = raw_side
        inferred = bool(lesion.get("side_inferred"))
        region = lesion.get("region")
        flags = [str(v).upper() for v in (lesion.get("flags") or [])]
        dims = lesion.get("dims_mm") or []
        frame_indices = lesion.get("frame_indices") or []
        les_type = choose_ahk_type(lesion)
        markers = markers_for_frames(frame_indices, marker_by_frame)
        vote = marker_vote(markers)
        marker_side = vote["side"]
        marker = representative_marker(markers, marker_side)
        graph_region = marker_region_code(marker)
        row_region = region or graph_region
        axillary = row_region == "AX" or les_type == "LN"
        marker_conflict = bool(marker_side and side in {"R", "L"} and marker_side != side)
        side_source = "ocr_sequence" if inferred else "ocr_text"
        review_required = bool(inferred or side == "?" or (graph_region and not region))
        display_hint = side_hint(side, inferred)
        if side in {"R", "L"} and not inferred:
            display_hint = side
            side_source = "ocr_text"
        elif marker_side:
            side = marker_side
            display_hint = f"{marker_side}⟳"
            side_source = "marker"
            review_required = True

        row = {
            "source_kind": "anchored",
            "raw_side": raw_side,
            "raw_side_hint": side_hint(raw_side, inferred),
            "raw_side_inferred": inferred,
            "side": side,
            "side_hint": display_hint,
            "side_inferred": inferred,
            "side_source": side_source,
            "review_required": review_required,
            "marker_conflict": marker_conflict,
            "region": row_region,
            "clock_start": clean_number(lesion.get("clock_start")),
            "clock_end": clean_number(lesion.get("clock_end")),
            "dist_cm": clean_number(lesion.get("dist_cm")),
            "max_dim_mm": clean_number(lesion.get("max_dim_mm")),
            "dims_text": dims_text(dims),
            "orientation": lesion.get("orientation") or "",
            "flags_text": ",".join(flags),
            "frame_indices_text": ",".join(str(v) for v in frame_indices),
            "type": les_type,
            "axillary": axillary,
            "include": True,
        }
        row.update(marker_fields(markers, vote))
        lesions_out.append(row)

    unanchored_out: list[dict[str, Any]] = []
    for item in study.get("unanchored_measurements") or []:
        dims = item.get("dims_mm") or []
        frame_index = item.get("frame_index")
        markers = markers_for_frames([frame_index], marker_by_frame)
        vote = marker_vote(markers)
        marker_side = vote["side"]
        marker = representative_marker(markers, marker_side)
        side = marker_side or "?"
        clock_hour = marker.get("clock_hour") if marker else None
        probe_orientation = marker.get("probe_orientation") if marker else ""
        graph_region = marker_region_code(marker)
        row = {
            "source_kind": "unanchored",
            "raw_side": "?",
            "raw_side_hint": "?",
            "raw_side_inferred": True,
            "side": side,
            "side_hint": f"{side}⟳" if marker_side else "?",
            "side_inferred": True,
            "side_source": "marker" if marker_side else "",
            "review_required": True,
            "marker_conflict": False,
            "region": graph_region,
            "clock_start": clean_number(clock_hour) if clock_hour is not None else None,
            "clock_end": None,
            "dist_cm": None,
            "max_dim_mm": clean_number(item.get("max_dim_mm")),
            "dims_text": dims_text(dims),
            "orientation": probe_orientation,
            "flags_text": "UNANCHORED",
            "frame_indices_text": "" if frame_index is None else str(frame_index),
            "type": "FCC",
            "axillary": False,
            "include": True,
            "caliper_count": item.get("caliper_count"),
        }
        row.update(marker_fields(markers, vote))
        unanchored_out.append(row)
        lesions_out.append(row)

    side_flags = []
    for item in study.get("side_flags") or []:
        side = str(item.get("side") or "?")
        inferred = bool(item.get("side_inferred"))
        side_flags.append({
            "side": side,
            "side_hint": side_hint(side, inferred),
            "side_inferred": inferred,
            "flag": item.get("flag") or "",
        })

    return {
        "status": api_payload.get("status"),
        "message": api_payload.get("message", ""),
        "patient_id": study.get("patient_id") or "",
        "study_date": study.get("study_date") or "",
        "accession": study.get("accession") or "",
        "study_uid": study.get("study_uid") or "",
        "processed_at": study.get("processed_at") or "",
        "run_status": study.get("run_status") or "",
        "finding_kind": study.get("finding_kind") or "",
        "frame_count": study.get("frame_count"),
        "expected_instance_count": study.get("expected_instance_count"),
        "received_instance_count": study.get("received_instance_count"),
        "error_detail": study.get("error_detail") or "",
        "lesions": lesions_out,
        "anchored_lesion_count": len(study.get("lesions") or []),
        "unanchored_measurements": unanchored_out,
        "unanchored_count": len(unanchored_out),
        "frame_markers": frame_markers_out,
        "frame_marker_count": len(frame_markers_out),
        "frame_marker_side_summary": frame_marker_side_summary(frame_markers_out),
        "side_flags": side_flags,
        "source": "http_api",
    }


def format_summary(payload: dict[str, Any], normalised: dict[str, Any] | None = None) -> str:
    if payload.get("status") == "not_found":
        next_action = payload.get("next_action") or {}
        return "\n".join([
            "status=not_found",
            payload.get("message") or "No DB record for this accession.",
            f"next_action={next_action.get('method', 'POST')} {next_action.get('url', '/api/process')}",
        ])
    if payload.get("status") == "busy":
        return "status=busy\nAnother /api/process job is already running."
    if not normalised:
        return json.dumps(payload, ensure_ascii=False, indent=2)

    lines = [
        f"status={payload.get('status')}",
        f"accession={normalised.get('accession')}",
        f"patient_id={normalised.get('patient_id')}",
        f"study_date={normalised.get('study_date')}",
        f"run_status={normalised.get('run_status')}",
        f"finding_kind={normalised.get('finding_kind')}",
        f"anchored_lesion_count={normalised.get('anchored_lesion_count') or 0}",
        f"unanchored_count={normalised.get('unanchored_count') or 0}",
        f"finding_row_count={len(normalised.get('lesions') or [])}",
        f"frame_marker_count={normalised.get('frame_marker_count') or 0}",
        f"frame_marker_side_summary={normalised.get('frame_marker_side_summary') or ''}",
        f"side_flag_count={len(normalised.get('side_flags') or [])}",
    ]
    if normalised.get("error_detail"):
        lines.append("error_detail=" + str(normalised["error_detail"]))
    return "\n".join(lines)


def fetch_study(args: argparse.Namespace) -> tuple[int, dict[str, Any]]:
    params: dict[str, str] = {}
    if args.accession:
        params["accession"] = args.accession
    else:
        params["chart_no"] = args.chart_no
        params["study_date"] = args.study_date
    return request_json("GET", args.server, "/api/study", params=params, timeout=args.timeout)


def process_study(args: argparse.Namespace) -> tuple[int, dict[str, Any]]:
    if not args.accession:
        raise ApiError("--accession is required for process")
    return request_json("POST", args.server, "/api/process", body={"accession": args.accession}, timeout=args.timeout)


def health(args: argparse.Namespace) -> tuple[int, dict[str, Any]]:
    return request_json("GET", args.server, "/healthz", timeout=args.timeout)


def handle_study_result(http_status: int, payload: dict[str, Any], args: argparse.Namespace) -> int:
    write_json(args.payload_out, payload)

    if http_status == 404 or payload.get("status") == "not_found":
        write_state(args, "not_found", payload.get("message", ""), next_action=payload.get("next_action"))
        write_summary(args.summary_out, format_summary(payload))
        return 2
    if http_status == 409 or payload.get("status") == "busy":
        write_state(args, "busy", payload.get("message", "Pipeline busy."))
        write_summary(args.summary_out, format_summary(payload))
        return 3
    if http_status < 200 or http_status >= 300:
        write_state(args, "http_error", f"HTTP {http_status}", http_status=http_status, payload=payload)
        write_summary(args.summary_out, f"status=http_error\nHTTP {http_status}\n{payload}")
        return 1

    normalised = normalise_study(payload)
    normalised["requested_accession"] = args.accession or ""
    normalised["requested_chart_no"] = args.chart_no or ""
    normalised["requested_study_date"] = args.study_date or ""
    write_json(args.pending_out, normalised)
    write_summary(args.summary_out, format_summary(payload, normalised))

    run_status = normalised.get("run_status")
    if run_status and run_status != "ocr_done":
        return 4
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    ap = argparse.ArgumentParser(description="Fetch/process breast US OCR data from the Ubuntu HTTP API")
    ap.add_argument("command", choices=["health", "fetch", "process"], nargs="?", default="fetch")
    ap.add_argument("--server", default=DEFAULT_SERVER)
    ap.add_argument("--accession")
    ap.add_argument("--chart-no")
    ap.add_argument("--study-date")
    ap.add_argument("--timeout", type=int, default=90)
    ap.add_argument("--payload-out", type=Path, default=DEFAULT_PAYLOAD)
    ap.add_argument("--pending-out", type=Path, default=DEFAULT_PENDING)
    ap.add_argument("--summary-out", type=Path, default=DEFAULT_SUMMARY)
    args = ap.parse_args(argv)
    if args.command == "fetch" and not args.accession and not (args.chart_no and args.study_date):
        ap.error("fetch requires --accession or both --chart-no and --study-date")
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    started = time.monotonic()
    try:
        if args.command == "health":
            status, payload = health(args)
            write_json(args.payload_out, payload)
            write_summary(args.summary_out, f"status={payload.get('status', 'ok')}\nhttp_status={status}")
            print(json.dumps(payload, ensure_ascii=False))
            return 0 if 200 <= status < 300 else 1
        if args.command == "process":
            status, payload = process_study(args)
        else:
            status, payload = fetch_study(args)
        code = handle_study_result(status, payload, args)
        elapsed = time.monotonic() - started
        print(f"HTTP {status}; exit={code}; elapsed={elapsed:.1f}s")
        print(args.summary_out.read_text(encoding="utf-8"))
        return code
    except ApiError as exc:
        write_state(args, "error", str(exc))
        write_summary(args.summary_out, "status=error\n" + str(exc))
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
