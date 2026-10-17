#!/usr/bin/env python
"""Headless launcher for the "MammoPdfDB Logon" scheduled task.

Run via *pythonw.exe* (GUI subsystem -> no console window) from Task Scheduler.
The visible cmd flash was caused by the task launching cmd.exe directly under an
interactive logon. This launcher instead re-runs the existing logon_setup.bat
with a HIDDEN console (CREATE_NO_WINDOW); its children (net use, uv run) attach
to that same hidden console, so nothing flashes on screen.

Nothing about the workflow changes: logon_setup.bat still maps Z:/P:/Q:, waits
for the network, and calls update.bat -> search_pdf_db.py update --toast, and it
still appends its own output to update.log. The toast (a Tk top-level window)
displays normally because GUI windows are independent of console visibility.

Register/re-register via:  register_logon_task.ps1
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BAT = HERE / "logon_setup.bat"

CREATE_NO_WINDOW = 0x08000000  # subprocess.CREATE_NO_WINDOW (Windows-only flag)


def main() -> int:
    if not BAT.exists():
        return 1
    # Do NOT redirect stdin: a hidden console is still a real console, so the
    # bat's `timeout /t 5` keeps working during the network-wait retry loop.
    # (Redirecting stdin would make `timeout` error out and busy-loop instead.)
    proc = subprocess.run(
        ["cmd.exe", "/c", str(BAT)],
        cwd=str(HERE),
        creationflags=CREATE_NO_WINDOW,
    )
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
