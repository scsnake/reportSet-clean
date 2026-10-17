# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "pydicom",
# ]
# ///

"""Refreshing command-line monitor for TB CXR USB copies."""

from __future__ import annotations

import argparse
from datetime import datetime
import logging
import os
from pathlib import Path
import sys
import time

from TB_CXR_copy_core import (
    APP_LOGGER_NAME,
    CopyProgress,
    DiskScanResult,
    DiskState,
    configure_file_logging,
    scan_disk,
)


DEFAULT_DISKS = ["F", "H", "I"]
DEFAULT_DESTINATION = Path("D:/scsnake/CXR_health/")
DEFAULT_INTERVAL = 30
logger = logging.getLogger(f"{APP_LOGGER_NAME}.cli")


def result_line(result: DiskScanResult) -> str:
    label = f"{result.disk_label}:"
    if result.state == DiskState.DISCONNECTED:
        return f"{label:<5} not connected"
    if result.state == DiskState.NO_DICOM:
        return f"{label:<5} no matching DICOM files"
    if result.state == DiskState.CANCELLED:
        return f"{label:<5} scan stopped"

    details = f"{result.total} files"
    if result.copied:
        details += f", {result.copied} copied"
    if result.skipped:
        details += f", {result.skipped} already copied"
    if result.unreadable:
        details += f", {result.unreadable} unreadable"
    if result.failed:
        details += f", {result.failed} failed"
    state = "copy complete" if result.copied else "up to date"
    return f"{label:<5} {state} ({details})"


def summary_line(results: list[DiskScanResult]) -> str:
    warnings = sum(result.unreadable + result.failed for result in results)
    copied = sum(result.copied for result in results)
    matching = any(result.total for result in results)
    if warnings:
        return f"Attention: {warnings} warning(s); see TB_CXR_copy.log."
    if copied:
        return f"Copy complete: {copied} new file(s)."
    if matching:
        return "All connected disks are up to date."
    if any(result.state == DiskState.NO_DICOM for result in results):
        return "Waiting for a TB CXR export."
    return "Waiting for a flash disk."


def render_dashboard(
    results: list[DiskScanResult],
    destination: Path,
    checked_at: datetime,
    next_scan_seconds: int | None,
    progress: CopyProgress | None = None,
) -> str:
    lines = [
        "TB CXR Copy",
        (
            f"Destination: {destination} | "
            f"Last checked: {checked_at:%Y-%m-%d %H:%M:%S}"
        ),
    ]
    lines.extend(result_line(result) for result in results)
    if progress is not None:
        lines.append(
            f"{progress.disk_label}: scanning {progress.processed}/{progress.total} "
            f"({progress.copied} copied)"
        )
    else:
        lines.append(summary_line(results))
    if next_scan_seconds is not None:
        lines.append(f"Next scan in {next_scan_seconds}s | Ctrl+C to stop")
    else:
        lines.append("Scanning now... | Ctrl+C to stop")
    return "\n".join(lines)


def enable_virtual_terminal() -> bool:
    if os.name != "nt":
        return True
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        handle = kernel32.GetStdHandle(-11)
        mode = ctypes.c_uint32()
        if not kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            return False
        return bool(kernel32.SetConsoleMode(handle, mode.value | 0x0004))
    except Exception:
        return False


def refresh_console(text: str, use_ansi: bool) -> None:
    if not sys.stdout.isatty():
        print(text, flush=True)
        return
    if use_ansi:
        print(f"\033[2J\033[H{text}", end="", flush=True)
    else:
        os.system("cls" if os.name == "nt" else "clear")
        print(text, end="", flush=True)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Monitor flash disks and copy TB CXR DICOM files."
    )
    parser.add_argument(
        "disks",
        nargs="*",
        default=DEFAULT_DISKS,
        help="drive letters or source directories (default: F H I)",
    )
    parser.add_argument(
        "--destination",
        type=Path,
        default=DEFAULT_DESTINATION,
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=DEFAULT_INTERVAL,
        help="seconds between scans (default: 30)",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="scan once and exit",
    )
    return parser.parse_args(argv)


def run_cli(args: argparse.Namespace) -> int:
    configure_file_logging()
    use_ansi = enable_virtual_terminal()
    logger.info("CLI monitor started for disks: %s", args.disks)
    logger.info("Destination: %s", args.destination)

    while True:
        results: list[DiskScanResult] = []
        scan_started = datetime.now()

        for disk in args.disks:
            def show_progress(event: CopyProgress) -> None:
                dashboard = render_dashboard(
                    results,
                    args.destination,
                    scan_started,
                    None,
                    progress=event,
                )
                refresh_console(dashboard, use_ansi)

            results.append(
                scan_disk(disk, args.destination, progress=show_progress)
            )

        checked_at = datetime.now()
        if args.once:
            refresh_console(
                render_dashboard(results, args.destination, checked_at, None),
                use_ansi,
            )
            if sys.stdout.isatty():
                print()
            return 0

        for remaining in range(max(args.interval, 1), 0, -1):
            refresh_console(
                render_dashboard(
                    results,
                    args.destination,
                    checked_at,
                    remaining,
                ),
                use_ansi,
            )
            time.sleep(1)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        return run_cli(args)
    except KeyboardInterrupt:
        logger.info("Stopped by user")
        if sys.stdout.isatty():
            print("\nStopped.")
        return 0
    except Exception:
        logger.exception("Fatal error")
        print("Fatal error. See TB_CXR_copy.log for details.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
