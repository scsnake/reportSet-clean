; ==============================================================================
; Library: changeLinebreak.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

changeLineBreak(ByRef str, linebreak = "`r`n", inplace = true){
	s:=RegExReplace(str, "\r?\n|\r", linebreak)
	if inplace
		str:=s
	return s
}