@echo off
git add -u
git commit -m "."
git push
git status> git_push_result.txt
for /f "delims=" %%x in (git_push_result.txt) do set VAR=%%x
Echo.%VAR% | findstr /C:"nothing to commit, working tree clean">nul && (
	REM updated
) || ( 
	start cmd /c "@echo off & mode con cols=18 lines=2 & echo git push error & pause>nul"
)
del git_push_result.txt