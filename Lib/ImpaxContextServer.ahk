#include <WM_COPYDATA>
DetectHiddenWindows,on

;~ sc=
;~ (
;~ Option Strict Off
;~ Imports System
;~ Imports System.Windows.Forms
;~ Module Script
;~ Sub Main()
;~ ScriptDisplay.ClearDisplay()
;~ End Sub
;~ End Module
;~ )

;~ ImpaxContextServer_SendCommand("RUN_SCRIPT | MyScript || " sc)
;~ ImpaxContextServer_SendCommand("SET_FOCUS | IMPAX || ")
;~ ImpaxContextServer_ClearDisplay()
;~ ExitApp
ImpaxContextServer_Init(hwnd=""){
	return 0
	static prvHwnd
	if WinExist("ahk_id " hwnd) || WinExist("ahk_id " hwnd:=prvHwnd){
		winget,ProcessName,ProcessName,ahk_id %hwnd%
		if(ProcessName="ImpaxContextServer.exe")
			return hwnd
	}
	
	process,Exist,ImpaxContextServer.exe
	if (!ErrorLevel){
		root:=SubStr(A_ScriptDir, 1, 2)
		if  FileExist(path:=root "\scripts\Radiology\MammoSR\ImpaxContextServer\ImpaxContextServer.exe")
			;~ || FileExist(path:=root "\send string by windows message\bin\Release\ImpaxContextServer.exe")
			|| fileexist(path:=A_ScriptDir "\ImpaxContextServer.exe")
			|| fileexist(path:=A_ScriptDir "\ImpaxContextServer\ImpaxContextServer.exe")
			||  fileexist(path:=a_mydocuments "\ImpaxContextServer\ImpaxContextServer.exe") 
			contextServerPath:=path
		run % contextServerPath
		winwait,ahk_exe ImpaxContextServer.exe,,5
		winminimize,ahk_exe ImpaxContextServer.exe
	}
	return (h:=WinExist("ahk_exe ImpaxContextServer.exe"))?(prvHwnd:=h):0
}

ImpaxContextServer_SendCommand(str, hwnd=""){
	Send_WM_COPYDATA(ImpaxContextServer_Init(hwnd), 0, str)
}

ImpaxContextServer_Show(AccNo, hwnd=""){
	ImpaxContextServer_SendCommand("SYNC_DISPLAY || " Trim(AccNo) " || ", hwnd)
}

ImpaxContextServer_Add(AccNo, withPrior=false, hwnd=""){
	ImpaxContextServer_SendCommand("ADD_TO_DISPLAY_LIST" (withPrior?"_WITH_PRIORS":"") " || " Trim(AccNo) " || ", hwnd)
}

ImpaxContextServer_BlankDisplay(hwnd=""){
	ImpaxContextServer_SendCommand("BLANK_DISPLAY || " Trim(AccNo) " || ", hwnd)
}

ImpaxContextServer_ClearDisplay(hwnd=""){
	script=
(
Option Strict Off
Imports System
Imports System.Windows.Forms
Module Script
Sub Main()
ScriptDisplay.ClearDisplay()
End Sub
End Module
)
	;~ MsgBox % script
	ImpaxContextServer_RunScript(script, hwnd)
}

ImpaxContextServer_RunScript(script, hwnd=""){
	path:=scriptText:=""
	if FileExist(script)
		path:=script
	else
		scriptText:=script
	
	ImpaxContextServer_SendCommand("RUN_SCRIPT | MyScript | " path " | " scriptText)
}
