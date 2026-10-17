@echo off
set "LOG=%TEMP%\session_test.log"
echo === Session Detection Test === > "%LOG%"
echo Date/Time: %DATE% %TIME% >> "%LOG%"
echo. >> "%LOG%"

echo [1] SESSIONNAME=[%SESSIONNAME%] >> "%LOG%"
echo [2] CLIENTNAME=[%CLIENTNAME%] >> "%LOG%"
echo [3] COMPUTERNAME=[%COMPUTERNAME%] >> "%LOG%"
echo [4] USERNAME=[%USERNAME%] >> "%LOG%"
echo. >> "%LOG%"

echo [5] All session-related vars: >> "%LOG%"
set | findstr /i "session\|client\|rdp\|remote\|terminal" >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo [6] PowerShell TerminalServerSession: >> "%LOG%"
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; Write-Host ([System.Windows.Forms.SystemInformation]::TerminalServerSession)" >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo [7] CLIENTNAME check result: >> "%LOG%"
if "%CLIENTNAME%"=="" (
    echo   CLIENTNAME is empty - would skip SSH >> "%LOG%"
) else (
    echo   CLIENTNAME=[%CLIENTNAME%] - would attempt SSH >> "%LOG%"
)

echo. >> "%LOG%"
echo [8] SESSIONNAME check result: >> "%LOG%"
if /i "%SESSIONNAME%"=="Console" (
    echo   SESSIONNAME is Console - would skip SSH >> "%LOG%"
) else (
    echo   SESSIONNAME=[%SESSIONNAME%] - would attempt SSH >> "%LOG%"
)

echo Done. Log at %LOG%
notepad "%LOG%"
