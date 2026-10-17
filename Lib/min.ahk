; ==============================================================================
; Library: min.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

min(params*){
	ret:=params[1]
	for k,v in params
		if (v<ret)
			ret:=v
	return ret
}

;~ MsgBox % min(1,-1)