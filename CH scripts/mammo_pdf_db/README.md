# Mammo PDF DB

Small local index for screening mammography PDF forms in:

`Z:\乳篩病人資料\PDF 未套用病歷號`

The updater parses the PDFs into `mammo_pdf.sqlite`. The AHK RIS hook calls
`mammo_show.py` when the current IE RIS study is a screening mammography exam,
then the Python GUI shows matched questionnaire data and opens the source PDF
when a field needs manual inspection.

## Network Credentials

If `Z:` needs credentials, copy `.env.example` to `.env` and fill:

```text
MAMMO_PDF_DB_NET_USER=
MAMMO_PDF_DB_NET_PASSWORD=
MAMMO_PDF_DB_NET_DOMAIN=
```

`search_pdf_db.py update` reads `.env`, clears a stale inaccessible `Z:` mapping,
then remaps `Z:` to `\\192.0.2.10\Rad-pub`.

## Common Usage

Update or rebuild the DB:

```powershell
.\update.bat
uv run --quiet search_pdf_db.py update --dir "Z:\乳篩病人資料\PDF 未套用病歷號" --force
```

Missing PDFs are not deleted from the DB. The updater marks their `pdfs` and
`records` rows with `file_removed=1` and keeps the parsed patient data.

Show the popup for one national ID:

```powershell
uv run --quiet mammo_show.py --id TEST_NID_001
```

Query records as JSON for debugging:

```powershell
uv run --quiet search_pdf_db.py query --id TEST_NID_001
uv run --quiet mammo_show.py --id TEST_NID_001 --print-json
```

## Files

- `search_pdf_db.py`: PDF parser, SQLite schema, update/query CLI.
- `mammo_show.py`: Tk popup used by the AHK RIS hook.
- `form_template.json`: checkbox coordinate rules and zh-TW display labels.
- `update.bat`: daily/manual updater wrapper.
- `feedback.jsonl`: append-only GUI feedback log, created on first feedback.

See `SCHEMA_FINAL.md` and `FIELDS_TODO.md` for schema and template notes.
