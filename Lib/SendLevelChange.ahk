; ==============================================================================
; Library: SendLevelChange.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

SendLevelChange(sendtext, newLevel=10){
	oldLevel:=a_sendlevel
	SendLevel % newLevel
	send % sendText
	SendLevel % oldLevel
}