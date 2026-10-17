; ==============================================================================
; Library: WinClose.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

WinClose(ByRef title="",ByRef Text="",ByRef exclude_title="",ByRef exclude_text=""){
	if title is integer
	{
	if (text exclude_title exclude_text == ""){
		WinClose,ahk_id %title%
	}
		
	}
	WinClose,% title,% Text,% exclude_title,% exclude_text
	return ErrorLevel
}