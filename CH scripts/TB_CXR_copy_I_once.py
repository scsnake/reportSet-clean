# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "pydicom",
# ]
# ///

import argparse
import logging
import re
import shutil
from datetime import datetime
from pathlib import Path

import pydicom


CORRUPT_SIZE_THRESHOLD = 50 * 1024  # bytes; real CXR DICOM is always much larger
DEFAULT_SOURCE = Path("I:/")
DEFAULT_DESTINATION = Path("D:/scsnake/CXR_health/")


def find_dicom_files(source: Path) -> list[Path]:
    """Find files from both usual DCM exports and direct numeric-folder USB exports."""
    patterns = [
        "DCM*/**/I0*",
        "*/I0*",
    ]
    files: set[Path] = set()
    for pattern in patterns:
        files.update(path for path in source.glob(pattern) if path.is_file())
    return sorted(files)


def safe_filename(value: str) -> str:
    value = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", value.strip())
    value = re.sub(r"\s+", "_", value)
    return value or "UNKNOWN"


def study_key_from_path(file_path: Path) -> str | None:
    if file_path.parent.name.isdigit():
        return file_path.parent.name
    if file_path.parent.parent.name.isdigit():
        return file_path.parent.parent.name
    return None


def output_filename(study_date: str, study_key: str, ds) -> str:
    acc = str(ds.get("AccessionNumber", "") or "")
    patient_id = str(ds.get("PatientID", "") or "")
    return safe_filename(f"{study_date}_{acc}_{study_key}_{patient_id}")


def read_study_info(file_path: Path):
    ds = pydicom.dcmread(file_path, force=True, stop_before_pixels=True)
    study_date = datetime.strptime(ds.StudyDate, "%Y%m%d").strftime("%Y%m%d")
    return study_date, ds


def copy_once(source: Path, destination: Path, dry_run: bool = False) -> int:
    if not source.exists():
        logging.error("Source does not exist: %s", source)
        return 2

    dicom_files = find_dicom_files(source)
    if not dicom_files:
        logging.error("No I0* files found under %s", source)
        return 1

    copied = 0
    skipped = 0
    failed = 0
    corrupt = 0
    logging.info("Matched %d file(s) under %s", len(dicom_files), source)

    for file_path in dicom_files:
        study_key = study_key_from_path(file_path)
        if study_key is None:
            logging.warning("Skipping path without numeric study folder: %s", file_path)
            skipped += 1
            continue

        try:
            study_date, ds = read_study_info(file_path)
        except Exception as exc:
            logging.error("Cannot read DICOM header: %s: %s", file_path, exc)
            failed += 1
            continue

        study_dir = destination / study_date
        dest_file = study_dir / output_filename(study_date, study_key, ds)

        if dest_file.exists() and dest_file.stat().st_size == file_path.stat().st_size:
            skipped += 1
            continue

        if dry_run:
            logging.info("Would copy %s -> %s", file_path, dest_file)
            copied += 1
            continue

        try:
            study_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(file_path, dest_file)
            copied += 1
            if file_path.stat().st_size < CORRUPT_SIZE_THRESHOLD:
                corrupt += 1
            if copied % 10 == 0:
                logging.info("Copied %d file(s)", copied)
        except Exception as exc:
            logging.error("Copy failed: %s -> %s: %s", file_path, dest_file, exc)
            failed += 1

    logging.info(
        "Done. Copied: %d, skipped: %d, failed: %d, corrupt-size: %d",
        copied,
        skipped,
        failed,
        corrupt,
    )
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="One-time TB CXR copy from I: USB")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--destination", type=Path, default=DEFAULT_DESTINATION)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )
    return copy_once(args.source, args.destination, args.dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
