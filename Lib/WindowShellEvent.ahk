; ==============================================================================
; Library: WindowShellEvent.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

; http://msdn.microsoft.com/zh-tw/library/windows/desktop/ms644989(v=vs.85).aspx
; wParam = 4 or 32772 -> window activated
; wParam = 1 -> window created
; lParam = hwnd


WindowShellEvent(funcName){
	global
	gui,shellEventGui: +hwndshellEventGUIhwnd
	;~ p:=DllCall("GetCurrentProcessId")
	;~ winget,id,id,ahk_pid %p%
	
	DllCall( "RegisterShellHookWindow", UInt,shellEventGUIhwnd )
	,OnMessage( DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" ), funcName)
	;~ return MsgNum
}

/*
shellMessage(wParam, lParam){
	if (wParam = 1){
		WinGetTitle,t,ahk_id %lParam%
		ToolTip % "activated window: " t
	}
}
	
	*/