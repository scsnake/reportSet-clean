@echo off
REM Daily updater for mammo screening PDF index.
REM   - search_pdf_db.py maps Z: using .env credentials if needed.
REM   - Runs `search_pdf_db.py update`, appending stdout/stderr to update.log.
REM
REM Register with Windows Task Scheduler, e.g. daily at 02:00:
REM   schtasks /Create /TN "MammoPdfDB Daily" /SC DAILY /ST 02:00 ^
REM       /TR "\"C:\Users\raduser\Documents\reportSet\CH scripts\mammo_pdf_db\update.bat\"" /F
REM
REM Manual run:
REM   "C:\Users\raduser\Documents\reportSet\CH scripts\mammo_pdf_db\update.bat"

setlocal
set SCRIPT_DIR=%~dp0
set LOG=%SCRIPT_DIR%update.log

echo. >> "%LOG%"
echo ======== %DATE% %TIME% ======== >> "%LOG%"

uv run --quiet "%SCRIPT_DIR%search_pdf_db.py" update >> "%LOG%" 2>&1
set RC=%ERRORLEVEL%

echo exit_code=%RC% >> "%LOG%"
endlocal & exit /b %RC%
