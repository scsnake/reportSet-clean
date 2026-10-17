; ==============================================================================
; Library: Timer.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

class Timer {
	__New(){
		this.start()
	}
	start(){
		this.tick:=A_TickCount
	}
	stop(){
		_t:=(A_TickCount-this.tick)
		,this.tick:=A_TickCount
		return _t
	}
}