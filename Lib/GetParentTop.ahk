; ==============================================================================
; Library: GetParentTop.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

GetParentTop(hwnd){
	h:=hwnd
	Loop {
		h_:=DllCall("GetParent", UInt, h)
		if (h_=h)
			return h_
		if !WinExist("ahk_id " h_)
			return h
		h:=h_
	}
}