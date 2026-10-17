@echo off
cd %UserProfile%\Documents\reportSet
start "" autorun.exe
git pull > git_pull_result.txt
set /p VAR=<git_pull_result.txt
Echo.%VAR% | findstr /C:"Already up to date">nul && (
	REM updated
) || ( 
start "" autorun.exe
)
del git_pull_result.txt