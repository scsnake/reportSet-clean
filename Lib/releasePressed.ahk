; ==============================================================================
; Library: releasePressed.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

#include <SetTimerF>

releasePressed(candidates="LButton,RButton,MButton", autoRepress=false){
	pressed:=""
	loop,parse,candidates,`,
	{
		if A_LoopField && GetKeyState(A_LoopField){
			pressed.=A_LoopField ","
			try
				send % "{" A_LoopField 	" UP}"
		}
	}
	if (autoRepress){
		if autoRepress=1
			autoRepress=1000
		SetTimerF("rePress", (-1)*abs(autoRepress), [pressed])
	}
	
	return pressed
}

rePress(pressList){
	Loop,Parse,pressList,`,
	{
		if A_LoopField {
			try
				send % "{" A_LoopField 	" DOWN}"
		}
	}
}