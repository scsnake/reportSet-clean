; ==============================================================================
; Library: WinGetClass.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

WinGetClass(ByRef title="",ByRef Text="",ByRef exclude_title="",ByRef exclude_text=""){
	if title is integer
	{
	if(text exclude_title exclude_text==""){
		WinGetClass,t,ahk_id %title%
		return t
	}
	}
	WinGetClass,var,% title,% Text,% exclude_title,% exclude_text
	return var
}