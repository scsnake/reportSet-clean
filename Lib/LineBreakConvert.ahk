; ==============================================================================
; Library: LineBreakConvert.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

LineBreakConvert(str, regex="\r?\n", replace="`r`n"){
	return regexreplace(str, regex, replace)
}