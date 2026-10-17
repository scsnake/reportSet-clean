; ==============================================================================
; Library: PathConcat.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

PathConcat(Abs, rels*){
	ret:=Abs
	for k,v in rels
		ret:=PathCombine(ret, v)
	return ret
}

;~ MsgBox % PathConcat("a", "", "*")