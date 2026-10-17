; ==============================================================================
; Library: StringUpperFirst.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

StringUpperFirst(str){
	f:=SubStr(str,1,1)
	stringupper,f,f
	return f SubStr(str,2)
}