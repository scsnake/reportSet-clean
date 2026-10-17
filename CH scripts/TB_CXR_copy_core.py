"""Reusable scan and copy logic for the TB CXR USB monitor."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from logging.handlers import TimedRotatingFileHandler
import logging
from pathlib import Path
import re
import shutil
from threading import Event
from typing import Callable, Iterable

import pydicom


APP_LOGGER_NAME = "TB_CXR_copy"
CORRUPT_SIZE_THRESHOLD = 50 * 1024
DICOM_HEADER_TAGS = ("StudyDate", "AccessionNumber", "PatientID")
logger = logging.getLogger(f"{APP_LOGGER_NAME}.core")
logging.getLogger(APP_LOGGER_NAME).addHandler(logging.NullHandler())


class DiskState(str, Enum):
    DISCONNECTED = "disconnected"
    NO_DICOM = "no_dicom"
    COPIED = "copied"
    UP_TO_DATE = "up_to_date"
    CANCELLED = "cancelled"


@dataclass(frozen=True)
class CopyProgress:
    disk_label: str
    total: int
    processed: int
    copied: int
    skipped: int
    unreadable: int
    failed: int
    current_date: str = ""


@dataclass
class DiskScanResult:
    disk_label: str
    source: Path
    state: DiskState
    layout: str = ""
    total: int = 0
    copied: int = 0
    skipped: int = 0
    unreadable: int = 0
    failed: int = 0
    corrupted_by_date: dict[str, int] = field(default_factory=dict)
    errors: list[str] = field(default_factory=list)


ProgressCallback = Callable[[CopyProgress], None]


def configure_file_logging(log_file: Path | None = None) -> Path:
    """Configure one rotating application log without adding console output."""
    if log_file is None:
        log_file = Path(__file__).with_name("TB_CXR_copy.log")

    app_logger = logging.getLogger(APP_LOGGER_NAME)
    app_logger.setLevel(logging.INFO)
    app_logger.propagate = False

    resolved_log = log_file.resolve()
    for handler in app_logger.handlers:
        if (
            isinstance(handler, TimedRotatingFileHandler)
            and Path(handler.baseFilename).resolve() == resolved_log
        ):
            return log_file

    handler = TimedRotatingFileHandler(
        log_file,
        when="midnight",
        interval=1,
        backupCount=7,
        encoding="utf-8",
    )
    handler.setFormatter(
        logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
    )
    app_logger.addHandler(handler)
    return log_file


def source_root(disk_or_path: str | Path) -> Path:
    """Accept H, H:, H:\\, or an explicit source directory."""
    value = str(disk_or_path).strip().rstrip("\\/")
    if re.fullmatch(r"[A-Za-z]:?", value):
        return Path(f"{value[0].upper()}:/")
    return Path(value)


def disk_label(source: Path) -> str:
    if source.drive and source == Path(source.anchor):
        return source.drive
    return source.name or source.drive or str(source)


def find_dicom_files(source: Path) -> tuple[list[Path], str]:
    """Find TB CXR DICOM files across the known USB export layouts."""
    flat_dcm_root = source / "DCM"
    flat_files = {
        file_path
        for study_dir in flat_dcm_root.glob("[0-9]*")
        if study_dir.is_dir() and study_dir.name.isdigit()
        for file_path in study_dir.glob("I0*")
        if file_path.is_file()
    }
    if flat_files:
        return sorted(flat_files), "DCM/<numeric study key>/I0*"

    patterns = [
        "DCM*/**/I0*",
        "*/I0*",
        "*/DCM*/**/I0*",
    ]
    files: set[Path] = set()
    for pattern in patterns:
        files.update(path for path in source.glob(pattern) if path.is_file())
    return sorted(files), "nested or dated DICOM export"


def safe_filename(value: str) -> str:
    value = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", value.strip())
    value = re.sub(r"\s+", "_", value)
    return value or "UNKNOWN"


def output_filename(study_date: str, study_key: str, dataset) -> str:
    accession = str(dataset.get("AccessionNumber", "") or "")
    patient_id = str(dataset.get("PatientID", "") or "")
    return safe_filename(
        f"{study_date}_{accession}_{study_key}_{patient_id}"
    )


def study_key_for(file_path: Path) -> str:
    parent_name = file_path.parent.name
    if parent_name.isdigit():
        return parent_name
    return file_path.parent.parent.name


def _emit_progress(
    callback: ProgressCallback | None,
    result: DiskScanResult,
    processed: int,
    current_date: str = "",
) -> None:
    if callback is None:
        return
    callback(
        CopyProgress(
            disk_label=result.disk_label,
            total=result.total,
            processed=processed,
            copied=result.copied,
            skipped=result.skipped,
            unreadable=result.unreadable,
            failed=result.failed,
            current_date=current_date,
        )
    )


def scan_disk(
    disk_or_path: str | Path,
    destination: Path,
    progress: ProgressCallback | None = None,
    stop_event: Event | None = None,
) -> DiskScanResult:
    """Scan one source and copy any new TB CXR DICOM files."""
    source = source_root(disk_or_path)
    result = DiskScanResult(
        disk_label=disk_label(source),
        source=source,
        state=DiskState.DISCONNECTED,
    )
    if not source.exists():
        return result

    dicom_files, result.layout = find_dicom_files(source)
    if not dicom_files:
        result.state = DiskState.NO_DICOM
        return result

    result.total = len(dicom_files)
    logger.info(
        "%s detected %s (%d DICOM file(s))",
        result.disk_label,
        result.layout,
        result.total,
    )

    for processed, file_path in enumerate(dicom_files, start=1):
        if stop_event is not None and stop_event.is_set():
            result.state = DiskState.CANCELLED
            break

        study_key = study_key_for(file_path)
        if not study_key.isdigit():
            result.failed += 1
            message = f"Unrecognized study folder for {file_path}"
            result.errors.append(message)
            logger.error(message)
            _emit_progress(progress, result, processed)
            continue

        try:
            dataset = pydicom.dcmread(
                file_path,
                force=True,
                stop_before_pixels=True,
                specific_tags=DICOM_HEADER_TAGS,
            )
            study_date = datetime.strptime(
                dataset.StudyDate, "%Y%m%d"
            ).strftime("%Y%m%d")
        except Exception as exc:
            result.unreadable += 1
            message = f"Cannot read DICOM header for {file_path}: {exc}"
            result.errors.append(message)
            logger.warning(message)
            study_date = "unknown"
            dataset = {}

        study_dir = destination / study_date
        study_dir.mkdir(parents=True, exist_ok=True)
        destination_file = study_dir / output_filename(
            study_date, study_key, dataset
        )

        try:
            source_size = file_path.stat().st_size
            if (
                destination_file.exists()
                and destination_file.stat().st_size == source_size
            ):
                result.skipped += 1
            else:
                shutil.copyfile(file_path, destination_file)
                result.copied += 1
                if source_size < CORRUPT_SIZE_THRESHOLD:
                    result.corrupted_by_date[study_date] = (
                        result.corrupted_by_date.get(study_date, 0) + 1
                    )
        except Exception as exc:
            result.failed += 1
            message = f"Error copying {file_path}: {exc}"
            result.errors.append(message)
            logger.error(message)

        _emit_progress(progress, result, processed, study_date)

    if result.state != DiskState.CANCELLED:
        result.state = (
            DiskState.COPIED if result.copied else DiskState.UP_TO_DATE
        )

    logger.info(
        "Finished scan on %s total=%d copied=%d skipped=%d unreadable=%d failed=%d",
        result.disk_label,
        result.total,
        result.copied,
        result.skipped,
        result.unreadable,
        result.failed,
    )
    for date, count in result.corrupted_by_date.items():
        logger.warning(
            "Corrupt files detected - %s: %d corrupt file(s) (0-byte pixel data)",
            date,
            count,
        )
    return result


def scan_disks(
    source_disks: Iterable[str | Path],
    destination: Path,
    progress: ProgressCallback | None = None,
    stop_event: Event | None = None,
) -> list[DiskScanResult]:
    """Scan each configured source once."""
    results: list[DiskScanResult] = []
    for source in source_disks:
        if stop_event is not None and stop_event.is_set():
            break
        results.append(
            scan_disk(source, destination, progress, stop_event)
        )
    return results
