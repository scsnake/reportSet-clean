#SingleInstance,force
SetBatchLines,-1

source:="F:\"
destination:="D:\scsnake\CXR_health\"
i:=0
InputBox,dir_studydate,study date
if StrLen(dir_studydate)==8
	FileCreateDir,% destination dir_studydate
else 
	ExitApp

Loop,files,% source "*",FR
{
	SplitPath,% A_LoopFileLongPath,file_name,dir
	SplitPath,% dir,dir_name
	if (dir_name~="^\d+$"){
		if (Mod((++i),10)==0)
			ToolTip % "Copy: " i
		dest_file:=destination dir_studydate "\" dir_name "_" i
		while FileExist(dest_file) 
			dest_file.="_"
		
		filecopy,% A_LoopFileLongPath,% dest_file,1
	}
}
ToolTip

MsgBox,,, % "Copied: " i,10
run, % A_AhkPath " UpDownCounter.ahk" 
;~ run, % "explorer.exe /separate, /n, /e ,   " destination
;~ Run,  %ComSpec% /c explorer.exe %destination%
run, % "OpenFolder.vbs   " destination
winactivate,% "ahk_exe G3PACS.exe"
ExitApp