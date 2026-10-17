; ==============================================================================
; Library: Control_GetClassNN.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

Control_GetClassNN(hWndWindow,hWndControl){
	DetectHiddenWindows, On
	WinGet, ClassNNList, ControlList, ahk_id %hWndWindow%
	Loop, PARSE, ClassNNList, `n
	{
		ControlGet, hwnd, hwnd,,%A_LoopField%,ahk_id %hWndWindow%
		if (hWnd = hWndControl)
			return A_LoopField
	}
}