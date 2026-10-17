# /// script
# requires-python = ">=3.11"
# dependencies = ["PyMuPDF"]
# ///
"""Render page 1 of the example PDF to a PNG for visual analysis."""
import sys
from pathlib import Path
import fitz

src = Path(r"Z:\乳篩病人資料\PDF 未套用病歷號\115.04.22測試區-01-乳攝.pdf")
out = Path(__file__).with_name("_page1.png")

doc = fitz.open(src)
page = doc.load_page(0)
mat = fitz.Matrix(2.5, 2.5)              # ~180 DPI
pix = page.get_pixmap(matrix=mat, alpha=False)
pix.save(out)
print(f"wrote {out}  ({pix.width}x{pix.height})")
