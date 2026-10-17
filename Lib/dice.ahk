; ==============================================================================
; Library: dice.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

dice(truePossibility=0.5){
	Random,r,0.0,1.0
	return r<truPossibility
}