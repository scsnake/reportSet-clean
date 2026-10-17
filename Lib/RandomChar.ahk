; ==============================================================================
; Library: RandomChar.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

RandomChar(len){
	static choices:="0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
	ret:="", ch:=StrLen(choices)
	Loop % len {
		Random,r,1,% ch
		ret.=SubStr(choices,r,1)
	}
	return ret
}

;~ MsgBox % RandomChar(512)