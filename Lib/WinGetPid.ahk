; ==============================================================================
; Library: WinGetPid.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

WinGetPid(ByRef title="",ByRef Text="",ByRef exclude_title="",ByRef exclude_text=""){
	if(title Text exclude_title exclude_text == "")
		return DllCall("GetCurrentProcessId")
	
	if title is integer
	{
	if(text exclude_title exclude_text==""){
		WinGet,pid,pid,ahk_id %title%
		return pid
	}
	}
	WinGet,pid,pid,% title,% Text,% exclude_title,% exclude_text
	return pid
}