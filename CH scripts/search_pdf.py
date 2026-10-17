# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "PyMuPDF",
# ]
# ///

import os
import sys
import fitz  # PyMuPDF
from pathlib import Path

def search_in_pdfs(pdf_list, keyword):
    for pdf_path in pdf_list:
        try:
            doc = fitz.open(pdf_path)
            for page_num in range(len(doc)):
                page = doc.load_page(page_num)
                # Search for keyword (case-insensitive by default in PyMuPDF depending on usage, 
                # but search_for is case-insensitive usually or we can rely on its default)
                text_instances = page.search_for(keyword)
                if text_instances:
                    return pdf_path, page_num + 1  # 1-based page number
        except Exception as e:
            print(f"Error reading {pdf_path}: {e}")
    return None, None

def search_pdf(keyword):
    # The mounted drive Z: maps to \\192.0.2.10\Rad-pub
    base_dir = Path(r"Z:\乳篩病人資料\PDF 未套用病歷號")
    parent_dir = base_dir.parent
    
    print(f"Searching for '{keyword}' in {base_dir}...")
    
    if not base_dir.exists():
        print(f"Warning: Directory {base_dir} does not exist. Is Z: drive mounted?")
        # Fallback to network path if Z: is not available
        base_dir = Path(r"\\192.0.2.10\Rad-pub\乳篩病人資料\PDF 未套用病歷號")
        parent_dir = base_dir.parent
        if not base_dir.exists():
            print(f"Error: Network path {base_dir} also inaccessible.")
            return None, None

    # 1. Search in base_dir
    pdfs = list(base_dir.glob("*.pdf"))
    found_pdf, page_num = search_in_pdfs(pdfs, keyword)
    
    if found_pdf:
        return found_pdf, page_num
        
    print(f"Not found in {base_dir}. Searching in parent directory {parent_dir}...")
    
    # 2. Search in one layer of parent folder (excluding the base_dir itself)
    parent_pdfs = list(parent_dir.glob("*.pdf"))
    found_pdf, page_num = search_in_pdfs(parent_pdfs, keyword)
    
    return found_pdf, page_num

def open_pdf_at_page(pdf_path, page_num):
    print(f"Opening {pdf_path} at page {page_num}")
    try:
        # Edge is commonly available on Windows and supports opening PDFs at a specific page
        # Format: msedge "file:///C:/path/to/file.pdf#page=5"
        pdf_uri = f"file:///{str(pdf_path).replace(chr(92), '/')}"
        cmd = f'start msedge "{pdf_uri}#page={page_num}"'
        os.system(cmd)
    except Exception as e:
        print(f"Failed to open with Edge, falling back to default viewer: {e}")
        os.startfile(pdf_path)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: uv run search_pdf.py <keyword>")
        sys.exit(1)
        
    keyword = sys.argv[1]
    found_pdf, page_num = search_pdf(keyword)
    
    if found_pdf:
        print(f"\nSuccess! Keyword '{keyword}' found in:\n{found_pdf}\nPage: {page_num}")
        open_pdf_at_page(found_pdf, page_num)
    else:
        print(f"\nKeyword '{keyword}' not found in any PDF.")
