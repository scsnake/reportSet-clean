; ==============================================================================
; Library: map.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

map(fn, arr){
	ret:=[]
	if !IsObject(fn)
		fn:=Func(fn)
	for k,v in arr
		ret.push(fn.call(v))
	return ret
}

;~ a:="test"
;~ b:=[1,2,3]

;~ MsgBox % exploreobj(map(a, b))

;~ test(b){
	;~ return b*2
;~ }