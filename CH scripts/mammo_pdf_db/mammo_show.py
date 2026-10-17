# /// script
# requires-python = ">=3.11"
# dependencies = ["PyMuPDF"]
# ///
"""
Look up a mammo screening record by national ID and pop a small Tk window
showing the matched fields plus per-needs_visual 'Open PDF' buttons.

Invoked by YCH_mammo_Enh.ahk (fire-and-forget) when CH_RIS reports a study
whose exam name matches the screening pattern. Lives next to search_pdf_db.py
so it can reuse the matcher.

Usage:
    uv run mammo_show.py --id TEST_NID_001
    uv run mammo_show.py --id TEST_NID_001 --auto-open   # skip GUI; open PDF immediately
"""
from __future__ import annotations

import argparse
import io
import json
import os
import sqlite3
import sys
from pathlib import Path

# Reuse the matcher from search_pdf_db.py
HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import search_pdf_db as core  # noqa: E402

core._ensure_utf8_streams()

FEEDBACK_LOG = HERE / "feedback.jsonl"


# ---------------------------------------------------------------------------
# Lookup
# ---------------------------------------------------------------------------

def lookup(nid: str, db_path: Path) -> list[dict]:
    conn = core.open_db(db_path)
    template = core.load_template()
    cols = list(core.QUERY_COLS) + ["checkboxes_json"]
    sql = f"SELECT {','.join(cols)} FROM records WHERE national_id = ? ORDER BY exam_iso DESC, id"
    rows = [dict(r) for r in conn.execute(sql, (nid,)).fetchall()]
    suppressed = load_suppressed_records()
    rows = [r for r in rows if not is_suppressed(r, suppressed)]
    for r in rows:
        core.apply_template_to_row(r, template)
        r.pop("checkboxes_json", None)
    return rows


def load_suppressed_records() -> set[tuple]:
    """Load feedback entries that should suppress future popup records."""
    suppressed: set[tuple] = set()
    if not FEEDBACK_LOG.exists():
        return suppressed
    with FEEDBACK_LOG.open("r", encoding="utf-8") as f:
        for line in f:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("reason") != "suppress_pdf":
                continue
            record_id = entry.get("record_id")
            if record_id is not None:
                suppressed.add(("id", record_id))
            suppressed.add((
                "stable",
                entry.get("national_id"),
                entry.get("mg_serial"),
                entry.get("pdf_path"),
                entry.get("form_page"),
                entry.get("exam_iso"),
            ))
    return suppressed


def is_suppressed(record: dict, suppressed: set[tuple]) -> bool:
    if ("id", record.get("id")) in suppressed:
        return True
    stable_key = (
        "stable",
        record.get("national_id"),
        record.get("mg_serial"),
        record.get("pdf_path"),
        record.get("form_page"),
        record.get("exam_iso"),
    )
    return stable_key in suppressed


# ---------------------------------------------------------------------------
# PDF opener (Edge with #page= anchor; fallback to OS default)
# ---------------------------------------------------------------------------

def open_pdf(path: str, page: int = 1) -> None:
    if not path:
        return
    try:
        uri = "file:///" + path.replace("\\", "/")
        os.system(f'start msedge "{uri}#page={page}"')
    except Exception:
        os.startfile(path)


# ---------------------------------------------------------------------------
# Tk GUI
# ---------------------------------------------------------------------------

FALLBACK_LABELS = {
    "education":                "教育程度",
    "disease_history":          "疾病史",
    "family_hx_breast_cancer":  "乳癌家族史",
    "menarche_other_text":      "初經其他說明",
    "is_menopause":             "已停經",
    "menopause_reason":         "停經原因",
    "menopause_reason_other":   "停經其他原因",
    "not_menopause":            "未停經",
    "breastfed_yn":             "曾哺餵母乳",
    "oral_contraceptive_usage": "曾使用口服避孕藥",
    "hrt_usage":                "曾使用荷爾蒙補充療法",
    "palpable_mass":            "自覺可觸摸腫塊",
    "exam_in_two_years":        "兩年內乳房檢查",
    "breast_op_history":        "乳房手術史",
}


def template_field_labels(template: dict | None) -> dict:
    labels = dict(FALLBACK_LABELS)
    if template:
        labels.update(template.get("field_labels_zh_tw") or {})
    return labels


def template_value_labels(template: dict | None) -> dict:
    labels = {
        "true": "是",
        "false": "否",
        "yes": "是",
        "no": "否",
    }
    if template:
        labels.update(template.get("value_labels_zh_tw") or {})
    return labels


def template_negative_values(template: dict | None) -> dict[str, set[str]]:
    negative: dict[str, set[str]] = {}
    if not template:
        return negative
    for row in template.get("y_rows", []):
        field = row.get("field")
        if not field:
            continue
        for opt in row.get("options", []):
            if opt.get("negative"):
                negative.setdefault(field, set()).add(value_key(opt.get("value")))
    return negative


def template_gray_values(template: dict | None) -> dict[str, set[str]]:
    gray: dict[str, set[str]] = {}
    if not template:
        return gray
    for row in template.get("y_rows", []):
        field = row.get("field")
        if not field:
            continue
        for opt in row.get("options", []):
            if opt.get("display_gray"):
                gray.setdefault(field, set()).add(value_key(opt.get("value")))
    return gray


def value_key(v) -> str:
    if v is True:
        return "true"
    if v is False:
        return "false"
    return str(v)


def is_negative_value(field: str, value, negative_values: dict[str, set[str]]) -> bool:
    keys = negative_values.get(field, set())
    if isinstance(value, list):
        return bool(value) and all(value_key(v) in keys for v in value)
    return value_key(value) in keys


def is_gray_value(value) -> bool:
    gray_keys = {"false", "none", "no"}
    if isinstance(value, list):
        return bool(value) and all(value_key(v).lower() in gray_keys for v in value)
    return value_key(value).lower() in gray_keys


def is_template_gray_value(field: str, value, gray_values: dict[str, set[str]]) -> bool:
    keys = gray_values.get(field, set())
    if isinstance(value, list):
        return bool(value) and all(value_key(v) in keys for v in value)
    return value_key(value) in keys


def fmt_value(v, value_labels: dict) -> str:
    if v is None:
        return "-"
    if isinstance(v, list):
        return "、".join(fmt_value(item, value_labels) for item in v)
    return value_labels.get(value_key(v), str(v))


def fmt_matched_value(record: dict, field: str, value, value_labels: dict) -> str:
    text = fmt_value(value, value_labels)
    if field == "is_menopause" and value is True and record.get("menopause_age") is not None:
        text += f" {record.get('menopause_age')}y/o"
    return text


def log_feedback(record: dict, reason: str, note: str = "") -> None:
    """Append a feedback entry to feedback.jsonl for later analysis."""
    import datetime
    entry = {
        "ts": datetime.datetime.now().isoformat(timespec="seconds"),
        "national_id":  record.get("national_id"),
        "record_id":    record.get("id"),
        "mg_serial":    record.get("mg_serial"),
        "pdf_path":     record.get("pdf_path"),
        "form_page":    record.get("form_page"),
        "exam_iso":     record.get("exam_iso"),
        "reason":       reason,
        "note":         note,
    }
    with FEEDBACK_LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def open_feedback_dialog(parent, record: dict, on_close=None) -> None:
    import tkinter as tk
    from tkinter import ttk
    dlg = tk.Toplevel(parent)
    dlg.title("回報問題")
    dlg.attributes("-topmost", True)
    dlg.configure(padx=12, pady=10)
    dlg.transient(parent); dlg.grab_set()

    ttk.Label(dlg, text=f"Record: {record.get('name','-')} ({record.get('national_id','')})",
              font=("Segoe UI", 9, "bold")).pack(anchor="w")
    ttk.Label(dlg, text=Path(record.get("pdf_path","")).name,
              font=("Segoe UI", 8), foreground="#666").pack(anchor="w", pady=(0, 8))

    reason = tk.StringVar(value="wrong_info")
    for val, lbl in [
        ("wrong_info",   "病人資料錯誤 / 配對錯誤"),
        ("suppress_pdf", "此筆不要顯示 PDF 開啟提示"),
        ("other",        "其他"),
    ]:
        ttk.Radiobutton(dlg, value=val, variable=reason, text=lbl).pack(anchor="w")

    ttk.Label(dlg, text="備註（選填）：",
              font=("Segoe UI", 9)).pack(anchor="w", pady=(8, 2))
    note_text = tk.Text(dlg, height=3, width=44, font=("Segoe UI", 9))
    note_text.pack(fill="x")

    def submit():
        log_feedback(record, reason.get(), note_text.get("1.0", "end").strip())
        dlg.destroy()
        if on_close:
            on_close()

    btns = ttk.Frame(dlg); btns.pack(fill="x", pady=(10, 0))
    ttk.Button(btns, text="送出", command=submit).pack(side="right")
    ttk.Button(btns, text="取消", command=dlg.destroy).pack(side="right", padx=(0, 6))
    dlg.bind("<Escape>", lambda e: dlg.destroy())


def show_window(records: list[dict], nid: str) -> None:
    import tkinter as tk
    from tkinter import ttk

    if not records:
        # Matched exam but ID not in DB → tray-style toast, not a full window.
        core.show_toast("No mammo PDF on file",
                        f"ID {nid} not found in screening DB.",
                        duration_ms=4500)
        return

    root = tk.Tk()
    root.title(f"Mammo PDF lookup — {nid}")
    root.attributes("-topmost", True)
    root.configure(padx=14, pady=12)
    template = core.load_template()
    labels = template_field_labels(template)
    value_labels = template_value_labels(template)
    negative_values = template_negative_values(template)
    gray_values = template_gray_values(template)

    # If multiple visits, expose a chooser at the top
    visit_var = tk.IntVar(value=0)

    container = ttk.Frame(root)
    container.pack(fill=tk.BOTH, expand=True)

    def render(idx: int) -> None:
        for w in container.winfo_children():
            w.destroy()
        rec = records[idx]
        m = rec.get("matched", {}) or {}
        nv = rec.get("needs_visual", []) or []
        pdf = rec.get("pdf_path", "")
        page = rec.get("form_page", 1)

        # Header
        hdr = ttk.Frame(container)
        hdr.pack(fill=tk.X, pady=(0, 8))
        name_str = f"{rec.get('name','-')}  ({rec.get('national_id','')})"
        ttk.Label(hdr, text=name_str, font=("Segoe UI", 12, "bold")).pack(anchor="w")
        ttk.Label(hdr, text=f"檢查日期: {rec.get('exam_iso','-')}    "
                            f"生日: {rec.get('birth_iso','-')}",
                  font=("Segoe UI", 9)).pack(anchor="w")
        if rec.get("file_removed"):
            ttk.Label(hdr, text="來源 PDF 已不在目前資料夾",
                      font=("Segoe UI", 9), foreground="#9A5A00").pack(anchor="w")

        pdf_button_text = f"開啟 PDF 人工檢視 (p.{page})" if nv else f"開啟表單 (p.{page})"
        pdf_btn = ttk.Button(container, text=pdf_button_text,
                             command=lambda: open_pdf(pdf, page))
        pdf_btn.pack(fill=tk.X, pady=(0, 8))
        if rec.get("file_removed"):
            pdf_btn.state(["disabled"])

        # Numeric / locked fields
        loc = ttk.LabelFrame(container, text="基本資料", padding=8)
        loc.pack(fill=tk.X, pady=(0, 6))
        for lbl, key in [("身高", "height_cm"), ("體重", "weight_kg"),
                         ("初經年齡", "menarche_age"),
                         ("生產次數", "birth_count"),
                         ("第一胎年齡", "first_birth_age")]:
            v = rec.get(key)
            ttk.Label(loc, text=f"{lbl}: {fmt_value(v, value_labels)}",
                      font=("Segoe UI", 9)).pack(anchor="w")

        # Matched fields
        mtd = ttk.LabelFrame(container, text="表單欄位", padding=8)
        mtd.pack(fill=tk.X, pady=(0, 6))
        for key, lbl in labels.items():
            if key not in m:
                continue
            needs_inspect = key in nv
            font = ("Segoe UI", 9, "bold") if needs_inspect else ("Segoe UI", 9)
            foreground = "#9a9a9a" if (
                is_gray_value(m[key]) or is_negative_value(key, m[key], negative_values)
                or is_template_gray_value(key, m[key], gray_values)
            ) else None
            text = f"{lbl}: {fmt_matched_value(rec, key, m[key], value_labels)}"
            if needs_inspect:
                text = f"● {text}"
                foreground = "#9A5A00"
            kwargs = {"text": text, "font": font}
            if foreground:
                kwargs["foreground"] = foreground
            ttk.Label(mtd, **kwargs).pack(anchor="w")

        # Feedback footer
        ftr = ttk.Frame(container)
        ftr.pack(fill=tk.X, pady=(8, 0))
        ttk.Button(ftr, text="回報問題…",
                   command=lambda r=rec: open_feedback_dialog(root, r,
                                                              on_close=root.destroy)
                   ).pack(side="right")

    if len(records) > 1:
        chooser = ttk.Frame(root)
        chooser.pack(fill=tk.X, pady=(0, 8))
        ttk.Label(chooser, text=f"{len(records)} visits — pick one:",
                  font=("Segoe UI", 9, "bold")).pack(anchor="w")
        for i, r in enumerate(records):
            ttk.Radiobutton(chooser, value=i, variable=visit_var,
                            text=f"  {r.get('exam_iso','-')}  ({Path(r.get('pdf_path','')).name})",
                            command=lambda i=i: render(i)
                            ).pack(anchor="w")

    render(0)
    root.geometry("+40+40")
    root.bind("<Escape>", lambda e: root.destroy())
    root.mainloop()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--id", required=True, help="national ID (CH_RIS.patidno)")
    p.add_argument("--db", default=str(core.DEFAULT_DB))
    p.add_argument("--auto-open", action="store_true",
                   help="skip GUI; open the most-recent matched PDF directly")
    p.add_argument("--print-json", action="store_true",
                   help="dump matched records as JSON to stdout (no GUI)")
    args = p.parse_args(argv)

    records = lookup(args.id, Path(args.db))

    if args.print_json:
        print(json.dumps(records, ensure_ascii=False, indent=2))
        return 0 if records else 1

    if args.auto_open:
        if records:
            r = records[0]
            open_pdf(r.get("pdf_path", ""), r.get("form_page", 1))
            return 0
        return 1

    show_window(records, args.id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
