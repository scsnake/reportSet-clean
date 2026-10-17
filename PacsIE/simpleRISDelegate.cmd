@echo off
SETLOCAL EnableExtensions
:loop
@ping 127.0.0.1 -n 2 -w 1000 > nul
FOR /F %%x IN ('tasklist /NH /FI "WINDOWTITLE eq simple RIS"') DO IF %%x == %EXE% goto loop
start "" /wait /HIGH /D . ..\AutoHotkey.exe simpleRIS.ahk
goto loop