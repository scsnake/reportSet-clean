; ==============================================================================
; Library: runAhkExe.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

runAhkExe(exePath, AddQuote=false){
	exePath:=RegExReplace(exePath, "^""|""$", "")
	,q:=AddQuote?"""":""
	return q exePath q (A_IsCompiled?" ":" " q  SubStr(exePath,1,-3) "ahk" q " ")
}