@echo off
REM Local-logon entry point for network drives + mammo PDF DB workflow.
REM
REM Mounts P: and Q: on logon:
REM   P: -> \\10.0.0.1\relexe    (HIS app executables)
REM   Q: -> \\10.0.0.1\vbtool6   (HIS app tools)
REM The PDF update handles its own Z: mapping with Python so credentials with
REM CMD-special characters cannot break this logon script.
REM
REM Optional pre-req for the PDF update only (run ONCE interactively):
REM   cmdkey /add:192.0.2.10 /user:<DOMAIN\user> /pass:<password>
REM
REM Register/re-register via Task Scheduler (elevated PowerShell):
REM   powershell -ExecutionPolicy Bypass -File "%~dp0register_logon_task.ps1"

setlocal EnableDelayedExpansion
set SCRIPT_DIR=%~dp0
set LOG=%SCRIPT_DIR%logon_setup.log
set P_MAP_EXIT=1
set Q_MAP_EXIT=1

echo. >> "%LOG%"
echo ======== LOGON %DATE% %TIME% ======== >> "%LOG%"

REM Wait for the HIS server before mapping (up to 60 s, checks every 5 s).
set /a TRIES=0
:WAIT_NET
ping -n 1 -w 1000 10.0.0.1 >nul 2>&1
if %ERRORLEVEL%==0 goto NET_READY
set /a TRIES+=1
if %TRIES% GEQ 12 (
    echo Network not reachable after 60 s — skipping drive mounts. >> "%LOG%"
    goto SKIP_MOUNTS
)
timeout /t 5 /nobreak >nul
goto WAIT_NET

:NET_READY
echo Network reachable after %TRIES% retries. >> "%LOG%"

REM --- P: (HIS relexe) ---
net use P: /delete /yes >nul 2>&1
REM P: and Q: must be available in both console and RDP logon sessions.
REM Map these first: Z: can require different credentials and must never prevent
REM the HIS drive mappings.  <nul prevents an invisible scheduled task from
REM hanging on a credential prompt.
net use P: \\10.0.0.1\relexe /persistent:yes <nul >> "%LOG%" 2>&1
set P_MAP_EXIT=%ERRORLEVEL%
echo P: map exit %P_MAP_EXIT% >> "%LOG%"

REM --- Q: (HIS vbtool6) ---
net use Q: /delete /yes >nul 2>&1
net use Q: \\10.0.0.1\vbtool6 /persistent:yes <nul >> "%LOG%" 2>&1
set Q_MAP_EXIT=%ERRORLEVEL%
echo Q: map exit %Q_MAP_EXIT% >> "%LOG%"

:SKIP_MOUNTS

REM DB refresh — UNC-driven, tolerates mount failures.
call "%SCRIPT_DIR%update.bat"
set UPDATE_EXIT=%ERRORLEVEL%
set FINAL_EXIT=%UPDATE_EXIT%
if not "%P_MAP_EXIT%"=="0" set FINAL_EXIT=%P_MAP_EXIT%
if not "%Q_MAP_EXIT%"=="0" set FINAL_EXIT=%Q_MAP_EXIT%
endlocal & exit /b %FINAL_EXIT%
