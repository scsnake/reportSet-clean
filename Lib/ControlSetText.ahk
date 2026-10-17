; ==============================================================================
; Library: ControlSetText.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

ControlSetText(Byref control, ByRef var, ByRef title="",ByRef Text="",ByRef exclude_title="",ByRef exclude_text=""){
	if control is integer
	{
	if(title text exclude_title  exclude_text=="")
		ControlSetText,,% var,ahk_id %control%
		return
	}
	ControlSetText,% control,% var,% title,% Text,% exclude_title,% exclude_text
	
}
