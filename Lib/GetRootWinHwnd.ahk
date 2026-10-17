; ==============================================================================
; Library: GetRootWinHwnd.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

GetRootWinHwnd(controlHwnd){
	return DllCall("user32\GetAncestor", "Ptr",controlHwnd, "UInt",2, "Ptr") ;GA_ROOT := 2
}