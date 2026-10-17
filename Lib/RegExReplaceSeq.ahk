; ==============================================================================
; Library: RegExReplaceSeq.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

RegExReplaceSeq(str, regexseq, repl){
	ret:=""
	for k,v in regexseq {
		ret:=RegExReplace(str, v, repl, var)
		if var
			return ret
	}
	return str
}
