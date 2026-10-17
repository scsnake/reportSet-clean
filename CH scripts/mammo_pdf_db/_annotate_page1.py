# /// script
# requires-python = ">=3.11"
# dependencies = ["PyMuPDF", "Pillow"]
# ///
"""Render page 1 of the example PDF and overlay every observed checkbox coord
(from the corpus) with a numbered red marker. Output: _page1_annotated.png."""
import json
import sqlite3
import sys, io
from pathlib import Path
import fitz
from PIL import Image, ImageDraw, ImageFont

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

HERE = Path(__file__).parent
DB = HERE / "mammo_pdf.sqlite"
EXAMPLE = Path(r"Z:\乳篩病人資料\PDF 未套用病歷號\115.04.22測試區-01-乳攝.pdf")

# ---- 1. corpus checkbox positions + template-only slots -------------------
conn = sqlite3.connect(DB)
counts: dict[tuple[int, int], int] = {}
for (cbs,) in conn.execute("SELECT checkboxes_json FROM records WHERE checkboxes_json IS NOT NULL"):
    for cb in json.loads(cbs):
        k = (round(cb["x"]), round(cb["y"]))
        counts[k] = counts.get(k, 0) + 1

# Template-only positions (declared in form_template.json but never observed checked).
template_only: set[tuple[int, int]] = set()
TEMPLATE = HERE / "form_template.json"
if TEMPLATE.exists():
    tmpl = json.loads(TEMPLATE.read_text(encoding="utf-8"))
    for row in tmpl.get("y_rows", []):
        for opt in row.get("options", []):
            k = (round(opt["x"]), round(row["y"]))
            if k not in counts:
                template_only.add(k)
                counts[k] = 0

# stable order: y row, then x left-to-right
positions = sorted(counts.items(), key=lambda kv: (kv[0][1], kv[0][0]))

# ---- 2. render page 1 ------------------------------------------------------
doc = fitz.open(EXAMPLE)
page = doc.load_page(0)
SCALE = 2.5                     # 2.5 ≈ 180 DPI
mat = fitz.Matrix(SCALE, SCALE)
pix = page.get_pixmap(matrix=mat, alpha=False)
img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)

# ---- 3. overlay markers ---------------------------------------------------
draw = ImageDraw.Draw(img, "RGBA")
try:
    font = ImageFont.truetype("arial.ttf", 18)
    font_lg = ImageFont.truetype("arial.ttf", 22)
except OSError:
    font = font_lg = ImageFont.load_default()

# group by y-row for clearer numbering
y_rows: dict[int, list[tuple[int, int, int]]] = {}        # y -> [(x, idx, count)]
for idx, ((x, y), c) in enumerate(positions, start=1):
    y_rows.setdefault(y, []).append((x, idx, c))

print("# Annotated checkbox positions (idx → x,y,count)")
print("#  idx     x      y    count")
for idx, ((x, y), c) in enumerate(positions, start=1):
    px, py = x * SCALE, y * SCALE
    is_template_only = (x, y) in template_only
    color = (30, 100, 220, 255) if is_template_only else (220, 30, 30, 255)
    r = 14
    draw.ellipse((px - r, py - r, px + r + 21, py + r + 21),
                 outline=color, width=3)
    label = ("T" if is_template_only else "") + str(idx)
    tx, ty = px - 4, py - 22
    draw.rectangle((tx - 2, ty - 2, tx + 30, ty + 22),
                   fill=(255, 255, 255, 220), outline=color)
    draw.text((tx, ty), label, fill=color, font=font)
    print(f"   {idx:3d}   {x:5d}  {y:5d}  {c:6d}")

# y-row dividers
for y in sorted(y_rows):
    py = y * SCALE
    draw.line((0, py + 28, img.width, py + 28), fill=(180, 180, 180, 100), width=1)

out = HERE / "_page1_annotated.png"
img.save(out, "PNG", optimize=True)
print(f"\nwrote {out}")
print(f"\n# Y-row groups ({len(y_rows)} distinct y, {len(positions)} total positions)")
print(f"#   y     count    indices (left→right)")
for y in sorted(y_rows):
    row = sorted(y_rows[y], key=lambda t: t[0])
    idxs = ", ".join(f"#{idx}@x={x}" for x, idx, _ in row)
    print(f"   {y:4d}    {len(row):3d}     {idxs}")
