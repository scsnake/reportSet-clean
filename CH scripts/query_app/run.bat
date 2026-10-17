@echo off
setlocal
cd /d "%~dp0"
echo Starting HIS Workflow Query at http://127.0.0.1:8000
uv run uvicorn app:app --host 127.0.0.1 --port 8000
pause
