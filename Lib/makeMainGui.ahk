; ==============================================================================
; Library: makeMainGui.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

makeMainGUI(title, guiTag="__OnMessageGUI"){
	static mainHwnd
	gui,%guiTag%:new,+hwndmainHwnd +ToolWindow
	WinSetTitle,ahk_id %mainHwnd%,,% title
}