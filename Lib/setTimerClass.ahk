; ==============================================================================
; Library: setTimerClass.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

class setTimerClass {
	setTimer(method, period, params:=""){
		; Each instance owns its callback cache. Off preserves a resumable timer;
		; Delete also breaks the cached BoundFunc -> this reference.
		wasCritical:=A_IsCritical
		Critical
		try {
			if !this.HasKey("__setTimerBindFn") || !IsObject(this.__setTimerBindFn)
				this.__setTimerBindFn:={}
			callbacks:=this.__setTimerBindFn
			; An explicit parameter array on a new schedule replaces the callback.
			; Control operations keep the existing arguments for pause/resume.
			bindParams:=IsObject(params) && period!="Off" && period!="On" && period!="Delete"
			if callbacks.HasKey(method) && bindParams {
				fn:=this[method].Bind(this, params*)
				previousFn:=callbacks[method]
				SetTimer,% previousFn,Delete
				callbacks[method]:=fn
			} else if callbacks.HasKey(method)
				fn:=callbacks[method]
			else {
				; Stopping an unknown timer must not create a retaining callback.
				if (period="Off" || period="Delete")
					return true
				callbacks[method]:=fn:=bindParams ? this[method].Bind(this, params*) : this[method].Bind(this)
			}
			SetTimer,% fn,% period
			if (period="Delete")
				callbacks.Delete(method)
			return true
		} catch e {
			ToolTip % e
			return false
		} finally {
			if wasCritical
				Critical,% wasCritical
			else
				Critical,Off
		}
	}

	; Call before abandoning an instance. __Delete cannot initiate cleanup when
	; timers or cached bound callbacks still retain it. New timers may be started
	; on the same instance afterwards (for example, reopening a mobile window).
	DisposeTimers(){
		wasCritical:=A_IsCritical
		Critical
		try {
			if this.HasKey("__setTimerBindFn") && IsObject(this.__setTimerBindFn) {
				for method, fn in this.__setTimerBindFn
					SetTimer,% fn,Delete
				this.Delete("__setTimerBindFn")
			}
		} finally {
			if wasCritical
				Critical,% wasCritical
			else
				Critical,Off
		}
	}
}

;~ class test extends setTimerClass {
	;~ __New(){
		;~ this.i:=0
		;~ this.setTimer("test",10)
	;~ }
	;~ test(){
		;~ ToolTip % ++this.i
	;~ }
;~ }


;~ new test()
;~ esc::ExitApp
