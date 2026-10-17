; ==============================================================================
; Library: WinGet.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

WinGet(ByRef cmd="",ByRef title="",ByRef Text="",ByRef exclude_title="",ByRef exclude_text=""){
	if title is integer
	{
	if (text exclude_title exclude_text == "")
		new_title:="ahk_id " title
	}
	WinGet,var,% cmd,% new_title?new_title:title,% Text,% exclude_title,% exclude_text
	return var
}