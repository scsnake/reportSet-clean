"""
export_lesions.py — Read latest study from SQLite DB, write lesions_pending.json.

Run this on Windows after the Ubuntu pipeline has finished and the DB is accessible
(via SMB share or scp).  The JSON is consumed by ris_annotate.ahk.

Usage:
    python export_lesions.py                         # latest study in DB
    python export_lesions.py --accession T0000000001
    python export_lesions.py --patient_id 0000000001
    python export_lesions.py --db path\to\lesions.db
"""
import argparse
import json
import sqlite3
import sys
from pathlib import Path

DEFAULT_DB = Path(__file__).parent.parent / "lesions.db"   # adjust if DB is on SMB mount


def get_conn(db_path):
    con = sqlite3.connect(str(db_path))
    con.row_factory = sqlite3.Row
    return con


def fetch_study(con, accession=None, patient_id=None):
    if accession:
        row = con.execute(
            "SELECT * FROM studies WHERE accession = ?", (accession,)
        ).fetchone()
    elif patient_id:
        row = con.execute(
            "SELECT * FROM studies WHERE patient_id = ? ORDER BY study_date DESC LIMIT 1",
            (patient_id,)
        ).fetchone()
    else:
        row = con.execute(
            "SELECT * FROM studies ORDER BY study_date DESC, processed_at DESC LIMIT 1"
        ).fetchone()
    return row


def fetch_lesions(con, study_uid):
    return con.execute(
        "SELECT * FROM lesions WHERE study_uid = ?", (study_uid,)
    ).fetchall()


# Map from DB lesion type to AHK button name
TYPE_MAP = {
    "solid":    "SOLID",
    "hypo":     "SOLID",
    "cyst":     "CYST",
    "anechoic": "CYST",
    "complex":  "COMPLEX",
    "spic":     "SPIC",
    "calcif":   "CALCIF",
}


def to_ahk_type(raw_type):
    if not raw_type:
        return "SOLID"
    return TYPE_MAP.get(raw_type.lower(), "SOLID")


def build_json(study_row, lesion_rows):
    lesions = []
    for r in lesion_rows:
        clock_s = r["clock_start"]
        clock_e = r["clock_end"]   # None if single clock value
        dist    = r["dist_cm"]
        max_mm  = r["max_dim_mm"] or 0

        # Derive axillary flag: dist > 5cm usually means axillary node
        axillary = dist is not None and dist > 5.5

        lesions.append({
            "side":        r["side"],
            "clock_start": clock_s,
            "clock_end":   clock_e,   # null if single
            "dist_cm":     dist,
            "max_dim_mm":  max_mm,
            "type":        to_ahk_type(r.get("orientation") or ""),
            "axillary":    axillary,
        })

    return {
        "patient_id": study_row["patient_id"],
        "study_date": study_row["study_date"],
        "accession":  study_row["accession"] or "",
        "study_uid":  study_row["study_uid"],
        "lesions":    lesions,
    }


def main():
    ap = argparse.ArgumentParser(description="Export lesions from SQLite to JSON for ris_annotate.ahk")
    ap.add_argument("--accession",  help="Accession number")
    ap.add_argument("--patient_id", help="Patient chart number")
    ap.add_argument("--db",         help="Path to lesions.db", default=str(DEFAULT_DB))
    ap.add_argument("--out",        help="Output JSON path",
                    default=str(Path(__file__).parent / "lesions_pending.json"))
    args = ap.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        print(f"DB not found: {db_path}", file=sys.stderr)
        sys.exit(1)

    con = get_conn(db_path)
    study = fetch_study(con, accession=args.accession, patient_id=args.patient_id)
    if not study:
        print("No matching study found in DB.", file=sys.stderr)
        sys.exit(1)

    lesions = fetch_lesions(con, study["study_uid"])
    payload = build_json(study, lesions)

    out_path = Path(args.out)
    out_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False))
    print(f"Wrote {len(lesions)} lesions → {out_path}")
    print(f"  Patient: {study['patient_id']}  Date: {study['study_date']}  Acc: {study['accession']}")
    for les in payload["lesions"]:
        side = les["side"]
        cs   = les["clock_start"]
        ce   = les["clock_end"]
        clk  = f"{cs}-{ce}" if ce else str(cs)
        print(f"  [{side}] {clk}/{les['dist_cm']}cm  {les['max_dim_mm']}mm  {les['type']}")


if __name__ == "__main__":
    main()
