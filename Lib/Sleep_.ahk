; ==============================================================================
; Library: Sleep_.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

Sleep_(t){
	DllCall("Sleep",UInt,t)
}
