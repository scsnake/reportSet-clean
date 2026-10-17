@echo off
set "MAC_HOST=192.0.2.10"
set "AHK_EXE=C:\Users\raduser\Documents\reportSet\AutoHotkey.exe"
set "LOCAL_AHK=C:\Users\raduser\Documents\reportSet\CH scripts\RisHorosSync.ahk"
set "LOCAL_EXE=C:\Users\raduser\Documents\reportSet\CH scripts\RisHorosSync.exe"

:: --- Robust detection for Local vs RDP session ---
set "IS_REMOTE=0"

:: 1. Check CLIENTNAME (Usually populated in RDP, empty locally)
if not "%CLIENTNAME%"=="" set "IS_REMOTE=1"

:: 2. Check SESSIONNAME (Looks for "rdp")
echo "%SESSIONNAME%" | find /i "rdp" >nul 2>&1
if not errorlevel 1 set "IS_REMOTE=1"

:: 3. Query the active session directly (Catches AHK/Elevated/Scheduler edge cases)
:: 'query session' outputs the sessions. We look for the line starting with ">" (current process)
:: query.exe is 64-bit only. A 32-bit cmd.exe (started from 32-bit AutoHotkey) must use Sysnative.
set "QUERY_EXE=%SystemRoot%\System32\query.exe"
if exist "%SystemRoot%\Sysnative\query.exe" set "QUERY_EXE=%SystemRoot%\Sysnative\query.exe"
for /f "tokens=1" %%a in ('%QUERY_EXE% session 2^>nul ^| findstr "^>"') do (
    echo "%%a" | find /i "rdp" >nul 2>&1
    if not errorlevel 1 set "IS_REMOTE=1"
    
    echo "%%a" | find /i "console" >nul 2>&1
    if not errorlevel 1 set "IS_REMOTE=0"
)

if "%IS_REMOTE%"=="0" (
    echo [+] Local session detected ^(Console^). Skipping MacBook connection checks.
    goto SKIP_MAC_CHECKS
)
:: -------------------------------------------------

:: Ask the MacBook server to restart itself; launchd starts it again.
:: A server that does not answer cannot receive this request. The Mac repairs
:: that case itself, so on failure we only wait and poll /health.
echo [+] Requesting MacBook server restart at %MAC_HOST%...
curl -f -s -m 5 -X POST http://%MAC_HOST%:7788/restart >nul 2>&1
if errorlevel 1 echo [!] Restart request not accepted - MacBook server did not answer. Check Tailscale is connected.
:: The old server still answers for a moment. Wait before the first /health poll.
timeout /t 2 /nobreak >nul
echo [+] Waiting for MacBook server to be ready...
set /a "_mac_tries=0"
:WAIT_MAC_SERVER
curl -fsS --connect-timeout 1 --max-time 2 http://%MAC_HOST%:7788/health >nul 2>&1
if not errorlevel 1 (
    echo [+] MacBook server ready.
    goto SKIP_MAC_CHECKS
)
set /a "_mac_tries+=1"
if %_mac_tries% geq 15 (
    echo [!] MacBook server not ready after %_mac_tries%s, proceeding anyway.
    goto SKIP_MAC_CHECKS
)
timeout /t 1 /nobreak >nul
goto WAIT_MAC_SERVER

:SKIP_MAC_CHECKS
echo [+] Starting RisHorosSync...
if exist "%LOCAL_AHK%" if exist "%AHK_EXE%" (
    echo [+] Starting local script via AutoHotkey: %LOCAL_AHK%
    start "" "%AHK_EXE%" "%LOCAL_AHK%"
) else if exist "%LOCAL_EXE%" (
    echo [+] Starting local %LOCAL_EXE%...
    start "" "%LOCAL_EXE%"
) else (
    echo [!] Local script/exe not found.
    echo     AHK: %LOCAL_AHK%
    echo     EXE: %LOCAL_EXE%
)

:: Local session: nothing to diagnose (Mac sync skipped) — close window immediately.
if "%IS_REMOTE%"=="1" timeout /t 5
