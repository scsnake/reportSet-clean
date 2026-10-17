; ==============================================================================
; Library: RemoveBOM.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

RemoveBOM(ByRef str){
	StringReplace,str,str,ï»¿,,All
	return str
}