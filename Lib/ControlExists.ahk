; ==============================================================================
; Library: ControlExists.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

ControlExists(hwnd){
	ControlGet, OutputVar, Hwnd,,, ahk_id %hwnd%
	return hwnd && outputVar=hwnd
}