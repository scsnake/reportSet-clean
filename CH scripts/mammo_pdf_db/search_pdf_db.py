# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "PyMuPDF",
# ]
# ///
"""
Mammo screening PDF parser & local index.

The PDFs in `Z:\\乳篩病人資料\\PDF 未套用病歷號` are 2-page-per-patient bundles of
positioned text (no real PDF widgets). This script extracts the form fields
by bbox y-coordinate bands and stores them in a local SQLite database, so
YCH_mammo_Enh.ahk can look up the current study against patient identifiers
shown on the IE RIS.

Subcommands:
    update                 Scan the PDF directory; (re)parse changed PDFs.
    query --id NID         Find records by national ID.
    query --name NAME      Find records by name (substring match).
    query --hosp CODE      Find records by hospital code.
    query --serial S       Find records by patient form serial (M...).
    query --date YYY/MM/DD Find records by ROC exam date.
    query --pdf PATH       Find records belonging to a PDF.
    dump                   Print all records as JSON.
    inspect PATH           Debug: print bboxes for one PDF (no DB write).

The DB lives next to this script (mammo_pdf.sqlite). Use `--db PATH` to override.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Iterable

import fitz  # PyMuPDF

def show_toast(title: str, message: str, duration_ms: int = 4000) -> None:
    """Tiny borderless top-right Tk window that auto-dismisses. No extra deps."""
    try:
        import tkinter as tk
    except ImportError:
        print(f"[toast] {title}: {message}")
        return
    root = tk.Tk()
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    try: root.attributes("-alpha", 0.94)
    except Exception: pass
    root.configure(bg="#202020")
    width, height = 340, 76
    sw = root.winfo_screenwidth()
    root.geometry(f"{width}x{height}+{sw - width - 24}+60")
    fr = tk.Frame(root, bg="#202020")
    fr.pack(fill="both", expand=True, padx=12, pady=10)
    tk.Label(fr, text=title, fg="#ffffff", bg="#202020",
             font=("Segoe UI", 10, "bold")).pack(anchor="w")
    tk.Label(fr, text=message, fg="#c8c8c8", bg="#202020",
             font=("Segoe UI", 9), wraplength=width - 24,
             justify="left").pack(anchor="w", pady=(2, 0))
    root.bind("<Button-1>", lambda e: root.destroy())
    root.after(duration_ms, root.destroy)
    root.mainloop()


def _ensure_utf8_streams():
    for name in ("stdout", "stderr"):
        s = getattr(sys, name)
        if getattr(s, "encoding", "").lower() != "utf-8":
            setattr(sys, name, io.TextIOWrapper(s.buffer, encoding="utf-8", errors="replace"))

# UNC primary: drive letters are per-logon-session in Windows; UNC paths bind
# to cached creds at the user-profile level and work from any session.
DEFAULT_DIRS = [
    Path(r"\\192.0.2.10\Rad-pub\乳篩病人資料\PDF 未套用病歷號"),
]
UNC_FALLBACK = [
    Path(r"Z:\乳篩病人資料\PDF 未套用病歷號"),
]
Z_DRIVE = Path("Z:\\")
Z_UNC = r"\\192.0.2.10\Rad-pub"
DEFAULT_DB = Path(__file__).with_name("mammo_pdf.sqlite")
ENV_PATH = Path(__file__).with_name(".env")

SERIAL_RE = re.compile(r"^M\d{11,13}$")
NID_RE = re.compile(r"^[A-Z][12]\d{8}$")  # Taiwan national ID
ACC_RE = re.compile(r"^\d{8,11}$")
ROC_DATE_FILE_RE = re.compile(r"^(\d{3})\.(\d{2})\.(\d{2})")


# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS pdfs (
    path          TEXT PRIMARY KEY,
    mtime         REAL    NOT NULL,
    size          INTEGER NOT NULL,
    parsed_at     TEXT    NOT NULL,
    page_count    INTEGER,
    record_count  INTEGER,
    error         TEXT,
    file_removed  INTEGER NOT NULL DEFAULT 0,
    removed_at    TEXT
);

CREATE TABLE IF NOT EXISTS records (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    pdf_path        TEXT    NOT NULL REFERENCES pdfs(path) ON DELETE CASCADE,
    form_page       INTEGER NOT NULL,
    hosp_page       INTEGER,
    mg_serial       TEXT,                 -- MG xray machine serial (e.g. M115042211001)
    car_plate       TEXT,                 -- MG screening car licence plate (e.g. KER-3777)
    license_id      TEXT,                 -- government-issued MG-screening licence id
    national_id     TEXT,
    name            TEXT,
    birth_roc_y     INTEGER,
    birth_m         INTEGER,
    birth_d         INTEGER,
    birth_iso       TEXT,
    phone_home      TEXT,
    phone_mobile    TEXT,
    postal          TEXT,
    address         TEXT,
    height_cm       REAL,
    weight_kg       REAL,
    menarche_age    INTEGER,              -- first menstrual cycle age
    menopause_age   INTEGER,              -- menopause age, if already menopausal
    birth_count     INTEGER,              -- number of births
    first_birth_age INTEGER,              -- age at first birth
    checkboxes_json TEXT,                 -- list of {x,y,w,h,kind}; kind = 'fill' or 'X'
    x_marks_json    TEXT,                 -- list of {x,y,t} for typed 'X<text>' annotations
    hospital_name   TEXT,
    hospital_code   TEXT,                 -- hospital code (page 2; was exam_accession)
    exam_roc_y      INTEGER,
    exam_m          INTEGER,
    exam_d          INTEGER,
    exam_iso        TEXT,
    file_removed    INTEGER NOT NULL DEFAULT 0,
    removed_at      TEXT,
    raw_json        TEXT
);

CREATE INDEX IF NOT EXISTS idx_records_nid       ON records(national_id);
CREATE INDEX IF NOT EXISTS idx_records_name      ON records(name);
CREATE INDEX IF NOT EXISTS idx_records_mgserial  ON records(mg_serial);
CREATE INDEX IF NOT EXISTS idx_records_hospcode  ON records(hospital_code);
CREATE INDEX IF NOT EXISTS idx_records_examiso   ON records(exam_iso);
CREATE INDEX IF NOT EXISTS idx_records_pdf       ON records(pdf_path);
"""


def open_db(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.executescript(SCHEMA_SQL)
    ensure_schema_migrations(conn)
    return conn


def ensure_schema_migrations(conn: sqlite3.Connection) -> None:
    record_cols = {r["name"] for r in conn.execute("PRAGMA table_info(records)").fetchall()}
    if "menopause_age" not in record_cols:
        conn.execute("ALTER TABLE records ADD COLUMN menopause_age INTEGER")
    if "file_removed" not in record_cols:
        conn.execute("ALTER TABLE records ADD COLUMN file_removed INTEGER NOT NULL DEFAULT 0")
    if "removed_at" not in record_cols:
        conn.execute("ALTER TABLE records ADD COLUMN removed_at TEXT")

    pdf_cols = {r["name"] for r in conn.execute("PRAGMA table_info(pdfs)").fetchall()}
    if "file_removed" not in pdf_cols:
        conn.execute("ALTER TABLE pdfs ADD COLUMN file_removed INTEGER NOT NULL DEFAULT 0")
    if "removed_at" not in pdf_cols:
        conn.execute("ALTER TABLE pdfs ADD COLUMN removed_at TEXT")


# ---------------------------------------------------------------------------
# Span extraction
# ---------------------------------------------------------------------------

@dataclass
class Span:
    x0: float
    y0: float
    x1: float
    y1: float
    text: str

    @property
    def yc(self) -> float:
        return (self.y0 + self.y1) / 2

    @property
    def xc(self) -> float:
        return (self.x0 + self.x1) / 2


DECOR_BOXES = {(81, 75), (142, 96)}      # template decoration squares present on every form page
TEMPLATE_PATH = Path(__file__).with_name("form_template.json")


def load_template() -> dict | None:
    if not TEMPLATE_PATH.exists():
        return None
    return json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))


def match_checkboxes(checkboxes: list[dict], template: dict | None) -> tuple[dict, list[str]]:
    """Apply the template to checked-checkbox positions.

    Returns:
      (resolved_fields, visual_needed)
        resolved_fields: {field_name: value | [values]}
        visual_needed: [field_name, ...]  fields whose checked value triggers
                       the AHK 'Open PDF' button.
    """
    if not template:
        return {}, []
    tol = template.get("tolerance_pt", 4)
    raw: dict = {}
    visual: list[str] = []
    negative_values: dict[str, set] = {}
    for row in template.get("y_rows", []):
        for opt in row.get("options", []):
            if opt.get("negative") and row.get("field"):
                negative_values.setdefault(row["field"], set()).add(opt.get("value"))

    for cb in checkboxes:
        cx, cy = cb["x"], cb["y"]
        for row in template.get("y_rows", []):
            if abs(cy - row["y"]) > tol:
                continue
            for opt in row.get("options", []):
                if abs(cx - opt["x"]) > tol:
                    continue
                field = row.get("field")
                value = opt.get("value")
                if field:
                    kind = row.get("kind", "enum")
                    if kind == "multi":
                        raw.setdefault(field, []).append(value)
                    else:
                        raw[field] = value
                if opt.get("needs_visual"):
                    tag = field or f"row_y{row['y']}_x{round(opt['x'])}"
                    if tag not in visual:
                        visual.append(tag)
                break
            break

    return _post_process(raw, negative_values), visual


def _post_process(raw: dict, neg: dict[str, set]) -> dict:
    """Standardize negatives (false / [] / null) and apply field-specific collapses."""
    out: dict = {}
    for field, val in raw.items():
        negs = neg.get(field, set())
        if isinstance(val, list):
            positives = [v for v in val if v not in negs]
            negatives_present = any(v in negs for v in val)
            if positives:
                out[field] = positives
            elif negatives_present:
                out[field] = False
            else:
                out[field] = None
        else:
            out[field] = False if val in negs else val

    # Field-specific: breast_op_history → canonical scalar.
    # Codes: Y (yes, unspecified side), L (left), R (right), N (no surgery).
    # Rule: any of L/R/B implies Y; L+R collapses to B.
    if "breast_op_history" in raw:
        items = raw.get("breast_op_history") or []
        s = set(items) if isinstance(items, list) else set()
        if not s:
            out["breast_op_history"] = None
        elif "N" in s and not (s & {"Y", "L", "R"}):
            out["breast_op_history"] = False
        elif "L" in s and "R" in s:
            out["breast_op_history"] = "B"
        elif "L" in s:
            out["breast_op_history"] = "L"
        elif "R" in s:
            out["breast_op_history"] = "R"
        elif "Y" in s:
            out["breast_op_history"] = "Y"

    return out

def checkboxes_for_page(page) -> list[dict]:
    """Return filled-square drawings interpreted as checked checkboxes.

    Each entry: {x: x0, y: y0, w: width, h: height} (PDF points, rounded).
    Decoration squares (logo bullets) are filtered out.
    """
    out = []
    for d in page.get_drawings():
        if d.get("type") != "f":             # filled
            continue
        fill = d.get("fill")
        if not (fill and all(c < 0.05 for c in fill[:3])):  # not solid black-ish
            continue
        r = d.get("rect")
        if not r:
            continue
        w, h = r.x1 - r.x0, r.y1 - r.y0
        # checkbox-shaped: ~6-14 pt square, area 30..200 pt²
        if not (4 <= w <= 16 and 4 <= h <= 16 and 0.6 <= (w / max(h, 0.1)) <= 1.6):
            continue
        key = (round(r.x0), round(r.y0))
        if key in DECOR_BOXES:
            continue
        out.append({"x": round(r.x0, 1), "y": round(r.y0, 1),
                    "w": round(w, 1), "h": round(h, 1)})
    return out


def spans_for_page(page) -> list[Span]:
    out: list[Span] = []
    d = page.get_text("dict")
    for blk in d.get("blocks", []):
        for line in blk.get("lines", []):
            for sp in line.get("spans", []):
                t = sp.get("text", "").strip().lstrip("﻿")
                if not t:
                    continue
                bb = sp["bbox"]
                out.append(Span(bb[0], bb[1], bb[2], bb[3], t))
    return out


def in_band(s: Span, y_lo: float, y_hi: float, x_lo: float | None = None, x_hi: float | None = None) -> bool:
    if not (y_lo <= s.yc <= y_hi):
        return False
    if x_lo is not None and s.xc < x_lo:
        return False
    if x_hi is not None and s.xc > x_hi:
        return False
    return True


def first(items: Iterable):
    for x in items:
        return x
    return None


# ---------------------------------------------------------------------------
# Field extraction (bbox bands derived from sample PDF inspection)
# ---------------------------------------------------------------------------

def parse_form_page(spans: list[Span]) -> dict:
    """Form page (odd page): patient demographics + questionnaire."""
    out: dict = {}

    def _band(y_lo, y_hi, x_lo=None, x_hi=None):
        return [s for s in spans if in_band(s, y_lo, y_hi, x_lo, x_hi)]

    # MG xray machine serial e.g. M115042211001 — top right
    s = first(s for s in spans if SERIAL_RE.fullmatch(s.text))
    out["mg_serial"] = s.text if s else None

    # MG screening car licence plate e.g. KER-3777 (yc≈101)
    s = first(_band(90, 115, 220, 340))
    if s and re.match(r"^[A-Z]+-?\d+", s.text):
        out["car_plate"] = s.text

    # Government-issued MG-screening licence id e.g. 1036338 (yc≈116)
    s = first(_band(105, 130, 110, 220))
    if s and s.text.isdigit():
        out["license_id"] = s.text

    # National ID (yc≈160, x>380)
    s = first(s for s in spans if NID_RE.fullmatch(s.text))
    out["national_id"] = s.text if s else None

    # Name (yc≈170, x≈140-220)
    s = first(_band(155, 180, 130, 220))
    if s and not s.text.isdigit() and not NID_RE.fullmatch(s.text):
        out["name"] = s.text

    # Birth date — three numeric spans yc≈210
    by = _band(195, 225, 110, 270)
    nums = [b for b in by if b.text.isdigit()]
    nums.sort(key=lambda s: s.x0)
    if len(nums) >= 3:
        try:
            out["birth_roc_y"] = int(nums[0].text)
            out["birth_m"] = int(nums[1].text)
            out["birth_d"] = int(nums[2].text)
            out["birth_iso"] = roc_to_iso(out["birth_roc_y"], out["birth_m"], out["birth_d"])
        except (ValueError, TypeError):
            pass

    # Phone home: area code + number, yc≈205 / yc≈220 — anything in x>320
    phones = sorted([s for s in spans if in_band(s, 195, 230, 320, 460) and re.fullmatch(r"\d{6,10}", s.text)],
                    key=lambda s: (s.y0, s.x0))
    if phones:
        # Heuristic: home (yc≈205) = first; mobile (yc≈220) = next.
        home = [p for p in phones if p.yc < 213]
        mob = [p for p in phones if p.yc >= 213]
        if home:
            area = first(s for s in spans if in_band(s, 195, 215, 320, 360) and s.text.isdigit())
            out["phone_home"] = ((area.text + " ") if area else "") + home[0].text
        if mob:
            out["phone_mobile"] = mob[0].text

    # Postal (yc≈237, x≈170-220)
    s = first(_band(225, 250, 165, 230))
    if s and s.text.isdigit():
        out["postal"] = s.text

    # Address (yc≈260, wide)
    s = first(_band(245, 275, 110, 530))
    if s:
        out["address"] = s.text

    # Height / Weight (yc≈330)
    hw = sorted(_band(315, 345, 140, 320), key=lambda s: s.x0)
    nums = [h for h in hw if re.fullmatch(r"\d+(\.\d+)?", h.text)]
    if len(nums) >= 1:
        try: out["height_cm"] = float(nums[0].text)
        except ValueError: pass
    if len(nums) >= 2:
        try: out["weight_kg"] = float(nums[1].text)
        except ValueError: pass

    # Menarche age (yc≈532, x≈188)
    s = first(_band(515, 545, 165, 215))
    if s and s.text.isdigit():
        try: out["menarche_age"] = int(s.text)
        except ValueError: pass

    # Menopause age (same row as 已停經 checkbox; yc≈549, x≈273)
    s = first(_band(535, 565, 250, 305))
    if s and s.text.isdigit():
        try: out["menopause_age"] = int(s.text)
        except ValueError: pass

    # Birth count / parity (yc≈617, x≈188)
    s = first(_band(600, 625, 165, 215))
    if s and s.text.isdigit():
        try: out["birth_count"] = int(s.text)
        except ValueError: pass

    # First birth age (yc≈645, x≈241)
    s = first(_band(625, 660, 215, 270))
    if s and s.text.isdigit():
        try: out["first_birth_age"] = int(s.text)
        except ValueError: pass

    # Typed-X annotations (e.g. 'X痣', 'X手術無scar') — checkbox-equivalent free text
    x_marks = [
        {"x": round(s.x0, 1), "y": round(s.y0, 1), "t": s.text}
        for s in spans if s.text.startswith("X") and len(s.text) >= 2 and not s.text[1:].isdigit()
    ]
    out["x_marks"] = x_marks

    # Questionnaire region (y > 400) — store all positioned text as JSON for later mining
    q = [{"x": round(s.x0, 1), "y": round(s.y0, 1), "t": s.text} for s in spans if s.yc > 400]
    out["raw_form"] = q

    return out


def parse_hosp_page(spans: list[Span]) -> dict:
    """Hospital page (even page): hospital + accession + ROC exam date."""
    out: dict = {}

    # Hospital name (top-left, yc≈55, contains 醫院 or 院)
    s = first(s for s in spans if 40 <= s.yc <= 75 and s.x0 < 250 and ("醫院" in s.text or "院" in s.text))
    if s:
        out["hospital_name"] = s.text

    # Hospital code (top-right, yc≈55, numeric 8-11 digits)
    s = first(s for s in spans if 40 <= s.yc <= 75 and s.x0 > 380 and ACC_RE.fullmatch(s.text))
    if s:
        out["hospital_code"] = s.text

    # Date YYY MM DD — three numeric spans yc≈78
    nums = sorted(
        [s for s in spans if 60 <= s.yc <= 95 and s.text.isdigit()],
        key=lambda s: s.x0,
    )
    if len(nums) >= 3:
        try:
            out["exam_roc_y"] = int(nums[0].text)
            out["exam_m"] = int(nums[1].text)
            out["exam_d"] = int(nums[2].text)
            out["exam_iso"] = roc_to_iso(out["exam_roc_y"], out["exam_m"], out["exam_d"])
        except (ValueError, TypeError):
            pass

    return out


def roc_to_iso(y: int, m: int, d: int) -> str | None:
    try:
        if y < 1 or m < 1 or m > 12 or d < 1 or d > 31:
            return None
        return f"{1911 + y:04d}-{m:02d}-{d:02d}"
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Per-PDF processing
# ---------------------------------------------------------------------------

def extract_records(doc) -> list[dict]:
    n = len(doc)
    pages_spans = [spans_for_page(doc.load_page(i)) for i in range(n)]
    records = []
    i = 0
    while i < n:
        spans = pages_spans[i]
        has_serial = any(SERIAL_RE.fullmatch(s.text) for s in spans)
        if has_serial:
            form = parse_form_page(spans)
            form["checkboxes"] = checkboxes_for_page(doc.load_page(i))
            hosp = {}
            if i + 1 < n:
                next_spans = pages_spans[i + 1]
                if any("醫院" in s.text or "院" in s.text for s in next_spans):
                    hosp = parse_hosp_page(next_spans)
                    rec_pages = (i + 1, i + 2)
                else:
                    rec_pages = (i + 1, None)
            else:
                rec_pages = (i + 1, None)
            rec = {"form_page": rec_pages[0], "hosp_page": rec_pages[1], **form, **hosp}
            records.append(rec)
            i += 2 if rec_pages[1] else 1
        else:
            i += 1
    return records


def parse_pdf(path: Path) -> tuple[int, list[dict], str | None]:
    try:
        doc = fitz.open(path)
    except Exception as e:
        return 0, [], f"open_error: {e}"
    try:
        recs = extract_records(doc)
        return len(doc), recs, None
    except Exception as e:
        return len(doc), [], f"parse_error: {e}"
    finally:
        doc.close()


# ---------------------------------------------------------------------------
# Update logic
# ---------------------------------------------------------------------------

def load_env_file(path: Path = ENV_PATH) -> dict[str, str]:
    """Load simple KEY=VALUE lines from .env without adding a dependency."""
    env: dict[str, str] = {}
    if not path.exists():
        return env
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        if key:
            env[key] = value
    return env


def network_credentials() -> tuple[str | None, str | None]:
    env = load_env_file()
    user = env.get("MAMMO_PDF_DB_NET_USER") or os.environ.get("MAMMO_PDF_DB_NET_USER")
    password = env.get("MAMMO_PDF_DB_NET_PASSWORD") or os.environ.get("MAMMO_PDF_DB_NET_PASSWORD")
    domain = env.get("MAMMO_PDF_DB_NET_DOMAIN") or os.environ.get("MAMMO_PDF_DB_NET_DOMAIN")
    if user and domain and "\\" not in user and "@" not in user:
        user = f"{domain}\\{user}"
    return user, password


def run_net_use(args: list[str]) -> int:
    proc = subprocess.run(["net", "use", *args], text=True,
                          stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT)
    if proc.stdout.strip():
        print(proc.stdout.strip(), file=sys.stderr)
    return proc.returncode


def ensure_z_drive() -> bool:
    """Make sure Z: is reachable; if not, try `net use Z: <UNC>` once."""
    try:
        if Z_DRIVE.exists():
            return True
    except OSError as e:
        print(f"[net] Z: not reachable ({e}); remapping/fallback will be tried.", file=sys.stderr)
    user, password = network_credentials()
    if user and password:
        print("[net] credentials found in .env; clearing stale Z: mapping before remap.", file=sys.stderr)
        run_net_use(["Z:", "/delete", "/y"])
        print(f"[net] mapping Z: to {Z_UNC} with .env credentials ...", file=sys.stderr)
        rc = run_net_use(["Z:", Z_UNC, password, f"/user:{user}", "/persistent:no"])
    else:
        print(f"[net] Z: not reachable; mapping to {Z_UNC} without explicit credentials ...", file=sys.stderr)
        rc = run_net_use(["Z:", Z_UNC, "/persistent:no"])
    if rc != 0:
        print(f"[net] `net use` returned {rc}.", file=sys.stderr)
    try:
        if Z_DRIVE.exists():
            print("[net] Z: mapped OK.", file=sys.stderr)
            return True
    except OSError as e:
        print(f"[net] Z: still not reachable ({e}).", file=sys.stderr)
    print(f"[net] FAILED to mount Z: — falling back to UNC paths if accessible.", file=sys.stderr)
    return False


def resolve_dirs(args_dirs: list[str] | None) -> list[Path]:
    if args_dirs:
        return [Path(d) for d in args_dirs if path_exists(Path(d))]
    found: list[Path] = []
    seen: set[Path] = set()
    for d in DEFAULT_DIRS:
        if path_exists(d) and d not in seen:
            found.append(d); seen.add(d)
    if not found:
        for d in UNC_FALLBACK:
            if path_exists(d) and d not in seen:
                found.append(d); seen.add(d)
    return found


def path_exists(path: Path) -> bool:
    try:
        return path.exists()
    except OSError as e:
        print(f"[net] cannot access {path}: {e}", file=sys.stderr)
        return False


def cmd_update(args):
    conn = open_db(Path(args.db))
    ensure_z_drive()
    dirs = resolve_dirs(args.dir)
    if not dirs:
        print("ERROR: no PDF directory accessible.", file=sys.stderr)
        return 2

    seen_paths: set[str] = set()
    parsed = changed = skipped = errored = 0
    for d in dirs:
        for p in d.glob("*.pdf"):
            sp = str(p)
            seen_paths.add(sp)
            st = p.stat()
            row = conn.execute(
                "SELECT mtime, size, file_removed FROM pdfs WHERE path=?", (sp,)
            ).fetchone()
            if row and row["mtime"] == st.st_mtime and row["size"] == st.st_size and not args.force:
                if row["file_removed"]:
                    with conn:
                        conn.execute(
                            "UPDATE pdfs SET file_removed=0, removed_at=NULL WHERE path=?", (sp,)
                        )
                        conn.execute(
                            "UPDATE records SET file_removed=0, removed_at=NULL WHERE pdf_path=?", (sp,)
                        )
                skipped += 1
                continue
            page_count, records, err = parse_pdf(p)
            parsed += 1
            if err:
                errored += 1
            else:
                changed += 1
            with conn:
                conn.execute("DELETE FROM records WHERE pdf_path=?", (sp,))
                conn.execute(
                    "INSERT INTO pdfs (path, mtime, size, parsed_at, page_count, record_count, error, file_removed, removed_at)"
                    " VALUES (?, ?, ?, ?, ?, ?, ?, 0, NULL)"
                    " ON CONFLICT(path) DO UPDATE SET"
                    " mtime=excluded.mtime,"
                    " size=excluded.size,"
                    " parsed_at=excluded.parsed_at,"
                    " page_count=excluded.page_count,"
                    " record_count=excluded.record_count,"
                    " error=excluded.error,"
                    " file_removed=0,"
                    " removed_at=NULL",
                    (sp, st.st_mtime, st.st_size, time.strftime("%Y-%m-%d %H:%M:%S"),
                     page_count, len(records), err),
                )
                for r in records:
                    insert_record(conn, sp, r)
            print(f"  {'ERR' if err else 'OK '}  {p.name}  pages={page_count} records={len(records)}"
                  + (f"  ({err})" if err else ""))

    # Mark missing PDFs as removed, but keep their parsed records for history.
    active_existing = {
        r["path"] for r in conn.execute(
            "SELECT path FROM pdfs WHERE file_removed=0"
        ).fetchall()
    }
    # Sentinel: if the walk saw nothing but we have active rows, the share is
    # almost certainly unreachable (intermittent net drive, expired creds, etc).
    # Refuse to mark everything removed — that would silently destroy state.
    if not seen_paths and active_existing:
        print("[net] aborting removal sweep: walked 0 PDFs but DB has "
              f"{len(active_existing)} active rows — share likely unreachable.",
              file=sys.stderr)
        removed: set[str] = set()
    else:
        removed = active_existing - seen_paths
    removed_at = time.strftime("%Y-%m-%d %H:%M:%S")
    for sp in removed:
        with conn:
            conn.execute(
                "UPDATE pdfs SET file_removed=1, removed_at=? WHERE path=?",
                (removed_at, sp),
            )
            conn.execute(
                "UPDATE records SET file_removed=1, removed_at=? WHERE pdf_path=?",
                (removed_at, sp),
            )
        print(f"  REMOVED  {sp}")

    summary = f"parsed={parsed} changed={changed} skipped={skipped} errored={errored} removed={len(removed)}"
    print(f"\nupdate: {summary}")
    if args.toast and (changed or errored or removed):
        show_toast("Mammo PDF DB updated", summary, duration_ms=5000)
    return 0


def insert_record(conn: sqlite3.Connection, pdf_path: str, r: dict) -> None:
    raw = r.pop("raw_form", None)
    cbs = r.pop("checkboxes", None)
    xms = r.pop("x_marks", None)
    cols = [
        "pdf_path", "form_page", "hosp_page",
        "mg_serial", "car_plate", "license_id",
        "national_id", "name", "birth_roc_y", "birth_m", "birth_d", "birth_iso",
        "phone_home", "phone_mobile", "postal", "address", "height_cm", "weight_kg",
        "menarche_age", "menopause_age", "birth_count", "first_birth_age",
        "checkboxes_json", "x_marks_json",
        "hospital_name", "hospital_code", "exam_roc_y", "exam_m", "exam_d", "exam_iso",
        "file_removed", "removed_at",
        "raw_json",
    ]
    vals = [
        pdf_path, r.get("form_page"), r.get("hosp_page"),
        r.get("mg_serial"), r.get("car_plate"), r.get("license_id"),
        r.get("national_id"), r.get("name"),
        r.get("birth_roc_y"), r.get("birth_m"), r.get("birth_d"), r.get("birth_iso"),
        r.get("phone_home"), r.get("phone_mobile"), r.get("postal"), r.get("address"),
        r.get("height_cm"), r.get("weight_kg"),
        r.get("menarche_age"), r.get("menopause_age"), r.get("birth_count"), r.get("first_birth_age"),
        json.dumps(cbs, ensure_ascii=False) if cbs else None,
        json.dumps(xms, ensure_ascii=False) if xms else None,
        r.get("hospital_name"), r.get("hospital_code"),
        r.get("exam_roc_y"), r.get("exam_m"), r.get("exam_d"), r.get("exam_iso"),
        0, None,
        json.dumps(raw, ensure_ascii=False) if raw else None,
    ]
    conn.execute(
        f"INSERT INTO records ({','.join(cols)}) VALUES ({','.join('?' * len(cols))})",
        vals,
    )


# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

QUERY_COLS = [
    "id", "pdf_path", "form_page", "hosp_page",
    "mg_serial", "car_plate", "license_id",
    "national_id", "name", "birth_iso", "phone_home", "phone_mobile",
    "postal", "address", "height_cm", "weight_kg",
    "menarche_age", "menopause_age", "birth_count", "first_birth_age",
    "hospital_name", "hospital_code", "exam_iso", "file_removed", "removed_at",
]


def apply_template_to_row(row: dict, template: dict | None) -> dict:
    """Add `matched` (resolved field values) + `needs_visual` (list) to a record dict."""
    if not template:
        row["matched"] = {}
        row["needs_visual"] = []
        return row
    cbs_json = row.get("checkboxes_json")
    cbs = json.loads(cbs_json) if cbs_json else []
    matched, visual = match_checkboxes(cbs, template)
    row["matched"] = matched
    row["needs_visual"] = visual
    return row


def cmd_query(args):
    conn = open_db(Path(args.db))
    template = load_template()
    where, params = [], []
    if args.id:        where.append("national_id = ?");       params.append(args.id)
    if args.name:      where.append("name LIKE ?");           params.append(f"%{args.name}%")
    if args.hosp:      where.append("hospital_code = ?");     params.append(args.hosp)
    if args.serial:    where.append("mg_serial = ?");         params.append(args.serial)
    if args.date:
        iso = normalize_date_arg(args.date)
        where.append("exam_iso = ?");                          params.append(iso)
    if args.pdf:       where.append("pdf_path LIKE ?");        params.append(f"%{args.pdf}%")
    if not where:
        print("query: provide at least one of --id --name --hosp --serial --date --pdf",
              file=sys.stderr)
        return 2

    cols = list(QUERY_COLS)
    if "checkboxes_json" not in cols:
        cols = cols + ["checkboxes_json"]
    sql = f"SELECT {','.join(cols)} FROM records WHERE " + " AND ".join(where) + " ORDER BY exam_iso DESC, id"
    rows = [dict(r) for r in conn.execute(sql, params).fetchall()]
    for r in rows:
        apply_template_to_row(r, template)
    if not args.raw:
        for r in rows:
            r.pop("checkboxes_json", None)
    if args.raw:
        for r in rows:
            r["raw_form"] = json.loads(
                conn.execute("SELECT raw_json FROM records WHERE id=?", (r["id"],)).fetchone()[0] or "null"
            )
    print(json.dumps(rows, ensure_ascii=False, indent=None if args.compact else 2))
    return 0 if rows else 1


def normalize_date_arg(s: str) -> str:
    """Accept '115/04/22', '115.04.22', '2026-04-22', '20260422' → ISO."""
    s = s.strip()
    m = re.match(r"^(\d{3})[./-](\d{1,2})[./-](\d{1,2})$", s)
    if m:
        return roc_to_iso(int(m.group(1)), int(m.group(2)), int(m.group(3))) or s
    m = re.match(r"^(\d{4})[./-]?(\d{1,2})[./-]?(\d{1,2})$", s)
    if m:
        return f"{int(m.group(1)):04d}-{int(m.group(2)):02d}-{int(m.group(3)):02d}"
    return s


def cmd_dump(args):
    conn = open_db(Path(args.db))
    rows = [dict(r) for r in conn.execute(f"SELECT {','.join(QUERY_COLS)} FROM records ORDER BY id").fetchall()]
    print(json.dumps(rows, ensure_ascii=False, indent=2))
    return 0


def cmd_template(args):
    """Calibration: list every distinct checkbox (x,y) the corpus ever marked,
    sorted by frequency. Use this to build a label-to-coordinate map for the form."""
    conn = open_db(Path(args.db))
    rows = conn.execute("SELECT checkboxes_json FROM records WHERE checkboxes_json IS NOT NULL").fetchall()
    counts: dict[tuple[float, float], int] = {}
    for r in rows:
        for cb in json.loads(r["checkboxes_json"]):
            key = (round(cb["x"], 0), round(cb["y"], 0))
            counts[key] = counts.get(key, 0) + 1
    items = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0][1], kv[0][0]))
    print(f"# unique checkbox positions: {len(items)} (across {len(rows)} records)")
    print("#  count   x      y    label?")
    for (x, y), c in items:
        print(f"   {c:5d}  {x:6.0f}  {y:6.0f}")
    return 0


def cmd_inspect(args):
    """Debug: print bboxes for one PDF (no DB write)."""
    p = Path(args.path)
    doc = fitz.open(p)
    print(f"== {p.name} ==  pages={len(doc)}")
    for pno in range(min(args.pages, len(doc))):
        spans = spans_for_page(doc.load_page(pno))
        print(f"\n--- page {pno+1} ({len(spans)} spans) ---")
        for s in spans:
            print(f"  ({s.x0:6.1f},{s.y0:6.1f},{s.x1:6.1f},{s.y1:6.1f})  '{s.text}'")
    return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="search_pdf_db.py", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--db", default=str(DEFAULT_DB), help=f"SQLite path (default: {DEFAULT_DB.name})")
    sub = p.add_subparsers(dest="cmd", required=True)

    u = sub.add_parser("update", help="scan PDFs and (re)parse changed ones")
    u.add_argument("--dir", action="append", help="PDF directory (repeatable). Default: known mammo dirs.")
    u.add_argument("--force", action="store_true", help="reparse even if mtime/size unchanged")
    u.add_argument("--toast", action="store_true", help="show tray toast at end (only if anything changed)")
    u.set_defaults(func=cmd_update)

    q = sub.add_parser("query", help="search the indexed records")
    q.add_argument("--id");      q.add_argument("--name")
    q.add_argument("--hosp", "--acc", dest="hosp",
                   help="hospital_code (page-2 number); --acc is accepted as a legacy alias")
    q.add_argument("--serial", help="mg_serial (M.....)")
    q.add_argument("--date");    q.add_argument("--pdf")
    q.add_argument("--raw", action="store_true", help="include raw_form bbox data")
    q.add_argument("--compact", action="store_true", help="single-line JSON")
    q.set_defaults(func=cmd_query)

    d = sub.add_parser("dump", help="print every record as JSON")
    d.set_defaults(func=cmd_dump)

    t = sub.add_parser("template", help="list distinct checkbox coords across the corpus (calibration)")
    t.set_defaults(func=cmd_template)

    insp = sub.add_parser("inspect", help="print bbox spans for a single PDF (debug)")
    insp.add_argument("path")
    insp.add_argument("--pages", type=int, default=4)
    insp.set_defaults(func=cmd_inspect)

    return p


def main(argv=None) -> int:
    args = build_argparser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    _ensure_utf8_streams()
    sys.exit(main())
