; ==============================================================================
; Library: RunKeepFocus.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

RunKeepFocus(target, workingdir="", arg3="", ByRef arg4=""){
	SetTimerF(A_ThisFunc, "off")
	,activeWin:=WinExist("A")
	run,% target,% workingdir,% arg3,_arg4
	arg4:=_arg4
	,SetTimerFn("RunKeepFocusWorker", 100, [activeWin, _arg4, A_TickCount])
}

RunKeepFocusWorker(activeWin, run_pid, start_tick){
	if (A_TickCount - start_tick)>5000 {
		SetTimerFn("RunKeepFocusWorker", "off", [activeWin, run_pid, start_tick])
		return
	}
	
	if !WinActive("ahk_id " activeWin) && WinActive("ahk_pid " run_pid)
		winactivate,% "ahk_id " activeWin
	
}