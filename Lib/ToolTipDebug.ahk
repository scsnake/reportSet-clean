; ==============================================================================
; Library: ToolTipDebug.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

ToolTipDebug(Text, timeout=1000, dismiss_action=false){
	static current_text
	global __debug
	if (!__debug){
		return
	}if(dismiss_action){
		
		MouseGetPos,,,win
		if InStr(WinGetClass(w:=win), "tooltip") && (WinGetPid(w:=win)=WinGetPid()) {
			SetTimerF(A_ThisFunc, -1000, [0,0,true])
		}else{
			ToolTip % (current_text:="")
			SetTimerF(A_ThisFunc, "off")	
		}
	}else if (current_text!=""){
		StringReplace,current_text,current_text,##########`n,,A
		ToolTip % (current_text.="`n##########`n" SubStr(a_now,1,8) " " SubStr(a_now,9,6) " " A_MSec "`t" Text)
		SetTimerF(A_ThisFunc, (-1)*timeout, [0,0,true])
	}else{
		ToolTip % (current_text:=SubStr(a_now,1,8) " " SubStr(a_now,9,6) " " A_MSec "`t" Text)
		SetTimerF(A_ThisFunc, (-1)*timeout, [0,0,true])
	}
}

;~ __debug:=1
;~ ToolTipDebug("test")

;~ Sleep 2500
;~ ToolTipDebug("test4")
;~ Sleep 3000
;~ ExitApp