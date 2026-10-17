#Persistent
#NoTrayIcon
#SingleInstance,force
SetBatchLines,-1

gui,+hwndmainHwnd
WinSetTitle,ahk_id %mainHwnd%,,simpleRIS_patch_main
OnMessage(0x10101, "exit")

SetTimer,routine,500
SetTimer,checkGUIs,2000
;~ SetTimer,debug,1
return

debug:
If h:=WinExist("Handle is NULL","buffer")
	PostMessage,0x1125,,,,simpleRIS_main ahk_class AutoHotkeyGUI
;~ IfWinExist,OpenProcess Failed,Unable
	;~ PostMessage,0x1125,,,,simpleRIS_main ahk_class AutoHotkeyGUI
return

routine:
ifwinexist,ahk_exe dwwin.exe,simpleRIS
{
	controlclick,Button1
	sleep 100
	run, % commands(A_ScriptDir "\..\AutoHotkey.exe", A_ScriptDir "\simpleRIS.ahk"),% A_ScriptDir
}
ifwinexist,simpleRIS.exe ahk_exe WerFault.exe
{
	winclose
	;~ process,close,simpleRIS.exe
	run, % commands(A_ScriptDir "\..\AutoHotkey.exe", A_ScriptDir "\simpleRIS.ahk"),% A_ScriptDir
}
If h:=WinExist("Handle is NULL","buffer")
{
	;~ pid:=winget("PID", h)
	;~ {
		;~ winget,list,list,ahk_pid %pid%
		;~ s:=""
		;~ Loop % List
			;~ s.=WinGetTitle(list%a_index%) "`n"
		;~ ToolTip % s
	;~ }
		
	WinClose,ahk_id %h%
}
IfWinExist,OpenProcess Failed,Unable
	WinClose
if !WinExist("simple RIS ahk_class AutoHotkeyGUI")
	ExitApp
return


checkGUIs:
guihwnds:=getSimpleRisGuiHwnds()
if !WinExist("ahk_id " guihwnds[1]){
	run, % commands(A_ScriptDir "\..\AutoHotkey.exe", A_ScriptDir "\simpleRIS.ahk"),% A_ScriptDir
}else if !WinExist("ahk_id " guihwnds[2]){
	run, % commands(A_ScriptDir "\..\AutoHotkey.exe", A_ScriptDir "\simpleRIS_.ahk"),% A_ScriptDir
}
return

~!#q::
if (A_ThisHotkey = A_PriorHotkey && A_TimeSincePriorHotkey<500){
	
	;~ PostMessage,0x10101,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	;~ PostMessage,0x10101,,,,simpleRIS__main ahk_class AutoHotkeyGUI
	;~ WinClose,simpleRIS_main ahk_class AutoHotkeyGUI
	;~ WinClose,simpleRIS__main ahk_class AutoHotkeyGUI
	if !WinExist("simpleRIS_main ahk_class AutoHotkeyGUI"){
		for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where CommandLine like 	'%simpleRISDelegate.cmd%' ")
			TaskKill(process.ProcessID)
		PostMessage,0x10101,,,,simpleRIS__main ahk_class AutoHotkeyGUI
		PostMessage,0x10101,,,,prettyOldHx ahk_class AutoHotkeyGUI
		TaskKill(winget("PID", "simple__main ahk_class AutoHotkeyGUI"))
		TaskKill(winget("PID", "prettyOldHx ahk_class AutoHotkeyGUI"))
		ExitApp
	}else
		PostMessage,0x10101,,,,simpleRIS_main ahk_class AutoHotkeyGUI
}
return

exit(){
	ExitApp
}