; ==============================================================================
; Library: UIAutomationServer.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

#include <WM_COPYDATA>
/*
eventHwnd: target control
eventType: 0 -> invoked, 1 -> value changed, 2 -> focus changed
responseMsg: OnMessage in this script
responseLparam: specify in eventType 0 and 1, will always return hwnd of focused control in eventType 2
responseToHwnd: usually hwnd of current script
*/
cmdUIAutomationServer(eventHwnd,eventType,responseMsg,responseLParam,responseToHwnd,hwnd=""){
	str:=(eventHwnd +0) "|" eventType "|" (responseMsg+0) "|" (responseLparam+0) "|" (responseToHwnd+0)
	DetectHiddenWindows,on
	winget,ProcessName,ProcessName,ahk_id %hwnd%
	if (!hwnd && (ProcessName!="UIAutomationServer.exe") && !(hwnd:=winexist("ahk_exe UIAutomationServer.exe"))){
		if FileExist(path:=A_ScriptDir "\UIAutomationServer.exe") || FileExist(path:=A_ScriptDir "\UIAutomationServer\UIAutomationServer.exe") || FileExist(path:=A_ScriptDir "\..\UIAutomationServer.exe") || FileExist(path:=A_ScriptDir "\..\UIAutomationServer\UIAutomationServer.exe") {
			run % path
			winwait,ahk_exe UIAutomationServer.exe,,5
			
			if (ErrorLevel)
				return 1
			
		}else{
			return 1
		}
	}
	
	
	Send_WM_COPYDATA(winexist("ahk_exe UIAutomationServer.exe"), 0, str)
	
}