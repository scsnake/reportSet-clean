; ==============================================================================
; Library: StringLowerFirst.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

StringLowerFirst(str){
	f:=SubStr(str,1,1)
	StringLower,f,f
	return f SubStr(str,2)
}