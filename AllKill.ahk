#NoEnv
#SingleInstance,force
SetBatchLines,-1
DetectHiddenWindows, On
SetTitleMatchMode,2
coordmode,mouse,screen
#NoTrayIcon
#include <ProcessList>
#include <ParseArg>
process,priority,,r
args:=ParseArg()
,thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))
winget,autorun_pid,pid,ahk_exe autorun.exe ahk_class AutoHotkeyGUI
if(args.Length()){
	root:=args[1]
	partialMode:=!!InStr(root, "reportSet")
}else{
	
	if regexmatch(a_scriptdir,"is)(.+?)\\scripts\\Autorun$",match)
		root:=match1, partialMode:=false
	else{
		root:=a_scriptdir, partialMode:=true
	}
}
;~ ToolTip % "Kill processes under " root " ..."
for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where CommandLine like '%simpleRISDelegate.cmd%' ")
	TaskKill(process.ProcessID)
WinClose,simple RIS ahk_class AutoHotkeyGUI
WinClose,simple RIS ahk_class AutoHotkeyGUI

for k,v in ProcessList() {
	if (InStr(v.path, root)==1 && v.pid!=thisPid && v.pid!=autorun_pid ){
		winget,list,list,% "ahk_pid " v.pid
		Loop % list
			WinClose,% "ahk_id " list%a_index%
	}
}


;~ MsgBox,4,,% "Kill all process under " root " ?",5
;~ IfMsgBox,Yes
	gosub killall

return 


killall:
;~ Loop 2
;~ for k,v in ProcessList() {
	;~ if (InStr(v.path, root)==1 && v.pid!=thisPid ){
		;~ p:=v.pid
		;~ Run,% comspec " /c ""taskkill /PID " p " /F /T""",,Hide
	;~ }
;~ }

;~ winget,pid,pid,ahk_exe autorun.exe ahk_class AutoHotkeyGUI
;~ if (pid){
	;~ if SubStr(a_now,1,8)="20190513"
		;~ ToolTip % pid
	;~ Run,% comspec " /c ""taskkill /PID " pid " /F /T""",,Hide
;~ }
	
Loop 2
for k,v in ProcessList() {
	if (InStr(v.path, root)==1 && v.pid!=thisPid ){
		n:=v.name
		Run,% comspec " /c ""taskkill /IM " n " /F""",,Hide
	}
}
for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where CommandLine like '%"  root "%' ")
	if (process.ProcessID!=thisPid)
		TaskKill(process.ProcessID)
SetTimer,killself,-1000
ExitApp
return 

killself:
TaskKill(thisPid)
ExitApp