; ==============================================================================
; Library: WinGetRoot.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

WinGetRoot(hwnd){
	static GA_ROOT:=2
	return DllCall("GetAncestor", "Ptr", hwnd, "UINT", GA_ROOT)
}