# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "pydicom",
# ]
# ///

"""Minimal Tkinter front end for the TB CXR USB monitor."""

from __future__ import annotations

import argparse
from datetime import datetime
import logging
from pathlib import Path
import queue
import threading
import tkinter as tk
from tkinter import messagebox, ttk

from TB_CXR_copy_core import (
    APP_LOGGER_NAME,
    CopyProgress,
    DiskScanResult,
    DiskState,
    configure_file_logging,
    disk_label,
    scan_disk,
    source_root,
)


DEFAULT_DISKS = ["F", "H", "I"]
DEFAULT_DESTINATION = Path("D:/scsnake/CXR_health/")
DEFAULT_INTERVAL = 30
logger = logging.getLogger(f"{APP_LOGGER_NAME}.gui")


def format_result(result: DiskScanResult) -> tuple[str, str, bool]:
    """Return concise status, details, and warning flag for one GUI row."""
    if result.state == DiskState.DISCONNECTED:
        return "Not connected", "-", False
    if result.state == DiskState.NO_DICOM:
        return "No DICOM files", "-", False
    if result.state == DiskState.CANCELLED:
        return "Stopped", "-", False

    warning = bool(result.unreadable or result.failed)
    if result.copied:
        status = "Copy complete"
        details = f"{result.copied} copied / {result.total} total"
    else:
        status = "Up to date"
        details = f"{result.total} files"
    if warning:
        details += f" / {result.unreadable + result.failed} warning(s)"
    return status, details, warning


def overall_status(results: list[DiskScanResult]) -> str:
    warnings = sum(result.unreadable + result.failed for result in results)
    copied = sum(result.copied for result in results)
    if warnings:
        return f"Attention: {warnings} warning(s). See the log for details."
    if copied:
        return f"Copy complete: {copied} new file(s)."
    if any(result.total for result in results):
        return "All connected disks are up to date."
    if any(result.state == DiskState.NO_DICOM for result in results):
        return "Waiting for a TB CXR export."
    return "Waiting for a flash disk."


class CopyMonitorApp:
    def __init__(
        self,
        root: tk.Tk,
        disks: list[str],
        destination: Path,
        interval: int = DEFAULT_INTERVAL,
    ) -> None:
        self.root = root
        self.disks = disks
        self.destination = destination
        self.interval = max(interval, 1)
        self.events: queue.Queue[tuple[str, object]] = queue.Queue()
        self.rows: dict[str, str] = {}
        self.scan_thread: threading.Thread | None = None
        self.stop_event: threading.Event | None = None
        self.scan_timer: str | None = None
        self.poll_timer: str | None = None
        self.is_scanning = False
        self.close_when_done = False
        self.seconds_remaining = self.interval

        self.status_text = tk.StringVar(value="Starting...")
        self.last_checked_text = tk.StringVar(value="Last checked: -")
        self.progress_text = tk.StringVar(value="")

        self._build_window()
        self.root.protocol("WM_DELETE_WINDOW", self.close)
        self.poll_timer = self.root.after(100, self._poll_events)
        self.root.after(250, self.start_scan)

    def _build_window(self) -> None:
        self.root.title("TB CXR Copy")
        self.root.geometry("610x340")
        self.root.minsize(560, 320)

        style = ttk.Style(self.root)
        if "vista" in style.theme_names():
            style.theme_use("vista")
        style.configure("Title.TLabel", font=("Segoe UI", 16, "bold"))
        style.configure("Status.TLabel", font=("Segoe UI", 11))

        main = ttk.Frame(self.root, padding=18)
        main.pack(fill="both", expand=True)

        ttk.Label(main, text="TB CXR Copy", style="Title.TLabel").pack(
            anchor="w"
        )
        ttk.Label(
            main,
            text=f"Destination: {self.destination}",
            foreground="#555555",
        ).pack(anchor="w", pady=(2, 12))

        self.disk_table = ttk.Treeview(
            main,
            columns=("disk", "status", "details"),
            show="headings",
            height=max(len(self.disks), 3),
            selectmode="none",
        )
        self.disk_table.heading("disk", text="Disk")
        self.disk_table.heading("status", text="Status")
        self.disk_table.heading("details", text="Details")
        self.disk_table.column("disk", width=70, anchor="center", stretch=False)
        self.disk_table.column("status", width=165, anchor="w", stretch=False)
        self.disk_table.column("details", width=305, anchor="w")
        self.disk_table.tag_configure("warning", foreground="#a33b00")
        self.disk_table.pack(fill="x")

        for source_value in self.disks:
            label = disk_label(source_root(source_value))
            row_id = self.disk_table.insert(
                "", "end", values=(label, "Waiting", "-")
            )
            self.rows[label] = row_id

        status_frame = ttk.Frame(main)
        status_frame.pack(fill="x", pady=(14, 4))
        ttk.Label(
            status_frame,
            textvariable=self.status_text,
            style="Status.TLabel",
        ).pack(side="left")
        ttk.Label(
            status_frame,
            textvariable=self.last_checked_text,
            foreground="#666666",
        ).pack(side="right")

        self.progress_bar = ttk.Progressbar(main, mode="determinate")
        self.progress_bar.pack(fill="x", pady=(3, 2))
        ttk.Label(
            main,
            textvariable=self.progress_text,
            foreground="#555555",
        ).pack(anchor="w")

        buttons = ttk.Frame(main)
        buttons.pack(fill="x", pady=(12, 0))
        self.scan_button = ttk.Button(
            buttons, text="Scan now", command=self.start_scan
        )
        self.scan_button.pack(side="left")
        ttk.Button(buttons, text="Close", command=self.close).pack(side="right")

    def start_scan(self) -> None:
        if self.is_scanning or self.close_when_done:
            return
        if self.scan_timer is not None:
            self.root.after_cancel(self.scan_timer)
            self.scan_timer = None

        self.is_scanning = True
        self.scan_button.state(["disabled"])
        self.status_text.set("Scanning connected disks...")
        self.progress_text.set("")
        self.progress_bar.configure(value=0, maximum=1)
        self.stop_event = threading.Event()
        self.scan_thread = threading.Thread(
            target=self._scan_worker,
            args=(self.stop_event,),
            name="tb-cxr-scan",
            daemon=False,
        )
        self.scan_thread.start()

    def _scan_worker(self, stop_event: threading.Event) -> None:
        results: list[DiskScanResult] = []
        try:
            for source_value in self.disks:
                if stop_event.is_set():
                    break
                result = scan_disk(
                    source_value,
                    self.destination,
                    progress=lambda event: self.events.put(("progress", event)),
                    stop_event=stop_event,
                )
                results.append(result)
                self.events.put(("result", result))
            self.events.put(("done", results))
        except Exception as exc:
            logger.exception("GUI scan failed")
            self.events.put(("error", exc))

    def _poll_events(self) -> None:
        try:
            while True:
                kind, payload = self.events.get_nowait()
                if kind == "progress":
                    self._show_progress(payload)
                elif kind == "result":
                    self._show_result(payload)
                elif kind == "done":
                    self._finish_scan(payload)
                elif kind == "error":
                    self._show_error(payload)
        except queue.Empty:
            pass

        if self.root.winfo_exists():
            self.poll_timer = self.root.after(100, self._poll_events)

    def _show_progress(self, payload: object) -> None:
        progress = payload
        if not isinstance(progress, CopyProgress):
            return
        self.progress_bar.configure(
            maximum=max(progress.total, 1),
            value=progress.processed,
        )
        self.progress_text.set(
            f"{progress.disk_label}: {progress.processed}/{progress.total} checked, "
            f"{progress.copied} copied"
        )
        row_id = self.rows.get(progress.disk_label)
        if row_id is not None:
            self.disk_table.item(
                row_id,
                values=(
                    progress.disk_label,
                    "Scanning",
                    f"{progress.processed}/{progress.total}",
                ),
                tags=(),
            )

    def _show_result(self, payload: object) -> None:
        result = payload
        if not isinstance(result, DiskScanResult):
            return
        status, details, warning = format_result(result)
        row_id = self.rows.get(result.disk_label)
        if row_id is not None:
            self.disk_table.item(
                row_id,
                values=(result.disk_label, status, details),
                tags=("warning",) if warning else (),
            )

    def _finish_scan(self, payload: object) -> None:
        results = payload if isinstance(payload, list) else []
        self.is_scanning = False
        self.scan_button.state(["!disabled"])
        self.progress_bar.configure(value=0, maximum=1)
        self.progress_text.set("")
        self.last_checked_text.set(
            f"Last checked: {datetime.now():%H:%M:%S}"
        )

        if self.close_when_done:
            self._destroy()
            return

        self.status_text.set(overall_status(results))
        corrupt_messages = [
            f"{date}: {count} corrupt file(s)"
            for result in results
            for date, count in result.corrupted_by_date.items()
        ]
        if corrupt_messages:
            messagebox.showwarning(
                "TB CXR Copy - Corrupt Files",
                "Corrupt files were copied:\n\n" + "\n".join(corrupt_messages),
                parent=self.root,
            )

        self.seconds_remaining = self.interval
        self._count_down()

    def _count_down(self) -> None:
        if self.close_when_done:
            return
        base_status = self.status_text.get().split("  Next scan in", 1)[0]
        self.status_text.set(
            f"{base_status}  Next scan in {self.seconds_remaining}s."
        )
        if self.seconds_remaining <= 0:
            self.scan_timer = self.root.after(1, self.start_scan)
            return
        self.seconds_remaining -= 1
        self.scan_timer = self.root.after(1000, self._count_down)

    def _show_error(self, payload: object) -> None:
        self.is_scanning = False
        self.scan_button.state(["!disabled"])
        self.status_text.set("Scan failed. See TB_CXR_copy.log for details.")
        if self.close_when_done:
            self._destroy()
            return
        messagebox.showerror(
            "TB CXR Copy",
            f"Scan failed:\n\n{payload}\n\nSee TB_CXR_copy.log for details.",
            parent=self.root,
        )
        self.seconds_remaining = self.interval
        self._count_down()

    def close(self) -> None:
        if self.scan_timer is not None:
            self.root.after_cancel(self.scan_timer)
            self.scan_timer = None
        if self.is_scanning:
            self.close_when_done = True
            self.scan_button.state(["disabled"])
            self.status_text.set("Stopping safely after the current file...")
            if self.stop_event is not None:
                self.stop_event.set()
            return
        self._destroy()

    def _destroy(self) -> None:
        if self.poll_timer is not None:
            self.root.after_cancel(self.poll_timer)
            self.poll_timer = None
        self.root.destroy()


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="TB CXR Copy GUI")
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
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    configure_file_logging()
    args = parse_args(argv)
    logger.info("GUI monitor started for disks: %s", args.disks)
    logger.info("Destination: %s", args.destination)
    try:
        root = tk.Tk()
        CopyMonitorApp(root, args.disks, args.destination, args.interval)
        root.mainloop()
        logger.info("GUI monitor stopped")
        return 0
    except Exception:
        logger.exception("Fatal GUI error")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
