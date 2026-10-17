; ==============================================================================
; Library: SetTimerFn.ahk
; Classification: Modified Third-Party
; Original Author: AutoHotkey Community / scsnake
; Origin: AutoHotkey Forum / local
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; Local Modifications: Workstation-specific extensions
; ==============================================================================

SetTimerFn(Function, Period=0, ParmObject=0, Priority=0, overriding=True){
	return new SelfDeletingTimer(Priority, Period, Function, overriding, ParmObject*)
}
class SelfDeletingTimer {
    static allTimers:=[]
    __New(Priority, period, fn, overriding, prms*) {
		is_off:=period=0||period="off"||period="delete"
		if (fn.__Class="SelfDeletingTimer"){
			this:=fn
	        if(overriding || is_off){
	            this.DeleteOldTimer(this)
	        }	
		}else{
			this.fn := IsObject(fn) ? fn : Func(fn)
	        if(overriding || is_off){
	            this.DeleteOld(this.fn)
	        }
		}
        
        this.prms := prms
        ,this.period:=period
        ,this.tick:=A_TickCount
        
    
        
        if (!is_off){
            this.AddTimer()
        }
        
        SetTimer,% this, % period=0?"off":period,% Priority
    
        ;~ if is_off
            ;~ settimer % this,delete
		
    }
	
	DeleteOld(fn) {
		if(SelfDeletingTimer.allTimers.haskey(fn)){
			for timer, tick in SelfDeletingTimer.allTimers[fn]
				settimer % timer,Delete
			SelfDeletingTimer.allTimers[fn]:={}
        }
	}
	DeleteOldTimer(timer){
        for fn,arr in SelfDeletingTimer.allTimers
			SelfDeletingTimer.allTimers[fn].delete(this)
		settimer % timer,delete
	}
	AddTimer() {
		fn:=this.fn
		if(!SelfDeletingTimer.allTimers.haskey(fn)){
			SelfDeletingTimer.allTimers[fn]:={}
		}
		SelfDeletingTimer.allTimers[fn, this]:=this.tick
	}
	
    Call() {
        this.fn.Call(this.prms*)
        if (this.period<0){
            this.DeleteOldTimer(this)
        }
            
    }
}

;~ #Persistent
;~ SetTimerFn("test", 1000, [1], 0)
;~ Sleep 500
;~ a:=SetTimerFn("test", 1000, [2], 0, 0)
;~ Sleep 3000
;~ SetTimerFn("test", 0, [2], 0, 1)
;~ return
;~ esc::ExitApp

;~ test(i){
 ;~ ToolTip % i "," A_TickCount   
;~ }
