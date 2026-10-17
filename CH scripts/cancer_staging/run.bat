@echo off
setlocal
cd /d "%~dp0"

echo [cancer_staging] Ensuring Python deps...
call uv sync --quiet || (echo uv sync failed & exit /b 1)

echo [cancer_staging] Refreshing queue from sheet...
call uv run --quiet python main.py fetch-todo || (echo fetch-todo failed & exit /b 1)

if not exist queue.json (
    echo No queue.json produced. Nothing to do.
    exit /b 0
)

echo [cancer_staging] Launching AHK helper...
start "" "C:\Users\raduser\Documents\reportSet\AutoHotkey.exe" "%~dp0cancer_staging_helper.ahk"

endlocal
