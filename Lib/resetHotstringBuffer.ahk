#include <showToolTip>
#include <RemoteScintilla>
;~ #include <Dynamic_Hotstring>
#InstallKeybdHook
;~ DetectHiddenWindows,on
;~ resetHotstringBuffer()
;~ return 

;~ esc::ExitApp

resetHotstringBufferHook(post_msg = 0x2177){
	;~ return
	static fn:=Func("resetHotstringBuffer").bind(-2)
	OnMessage(post_msg, fn)
}

resetHotstringBufferGlobal(post_msg = 0x2177){
	static pidHx:={}
	;~ return
	DetectHiddenWindows,on
	if !(guihwnd:=WinExist("__resetHotstringBufferInfo_GUI ahk_class AutoHotkeyGUI")){
		gui,new,+hwndguihwnd +ToolWindow -Caption
	}else if (A_TickCount - RegExReplace(WinGetTitle(guihwnd), "\D", "") < A_TimeIdlePhysical)
		return
	
	WinSetTitle,% "ahk_id " guihwnd,,% "__resetHotstringBufferInfo_GUI" A_TickCount
	
	Hotstring("Reset"), ScintillaCaretChange(2), Dynamic_Hotstring("", "", "", "", "", true)
	
	tobedel:=[]
	for pid, v in pidHx
		if WinExist("ahk_pid " pid)
			PostMessage,% post_msg,,,,% "ahk_pid " pid
		else
			tobedel.push(pid)
	
	
	;~ ToolTip % exploreobj(pidHx)
	
	for k,v in tobedel
		pidHx.delete(v)
	
	for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name LIKE 'Autohotkey%.exe' or name LIKE '%AHK%.exe' or name LIKE 'YCH%.exe' or name = 'autorun.exe' ")
		if (!pidHx.haskey(pid:=process.ProcessId)){
			PostMessage,% post_msg,,,,% "ahk_pid " process.ProcessId
			pidHx[pid]:=true
		}
		
	;~ Suspend on 
	;~ Suspend Off
}

;~ a::
;~ ScintillaCaretChange(2)
;~ return

;~ esc::ExitApp
ScintillaCaretChange(Style=1, ByRef sci_=""){
	static sci
	return
	if (sci_)
		sci:=sci_
	else if (sci.hwnd != (Focused:=getFocusedHwnd())){
		if WinGetClass(Focused)!="Scintilla"
			return
		sci:=new RemoteScintilla(Focused)
	}
	sci.SetCaretStyle(Style)
	if(Style!=1)
		SetTimerF("ScintillaCaretChange", -300, [1, sci])
}

resetHotstringBuffer(resetAfter=2000, monitorEvery=100, ShowToolTip =false, method=0, post_msg = 0x2177){
	global __resetHotstringBufferInfo
	static lastReset
	Critical
	;~ ToolTip % A_ScriptName
	if(resetAfter=-1){
		Hotstring("Reset"), Dynamic_Hotstring("", "", "", "", "", true)
		return resetHotstringBufferGlobal(post_msg)
	}
	
	if(resetAfter<0){
		;~ Hotstring("reset"), Dynamic_Hotstring("", "", "", "", "", true)
		if (lastReset>0 && A_TickCount-lastReset<A_TimeIdlePhysical) 
			return
		
		lastReset:=A_TickCount
		, Hotstring("Reset"), ScintillaCaretChange(2), Dynamic_Hotstring("", "", "", "", "", true)
		;~ Click up 2
		return
	}
	
	return SetTimerF("resetHotstringBuffer", (-1)*resetAfter, [-2])
	
	__resetHotstringBufferInfo.Idle:=0
	,__resetHotstringBufferInfo.IdleUnit:=monitorEvery
	,__resetHotstringBufferInfo.IdleThreshold:=resetAfter
	,__resetHotstringBufferInfo.IdlePriorReset:=false
	,__resetHotstringBufferInfo.ShowTooltip:=ShowToolTip
	,__resetHotstringBufferInfo.Target:=method
	,__resetHotstringBufferInfo.PostMsg:=post_msg
	
	
	SetTimer,__resetHotstringBufferSub, % monitorEvery
}

__resetHotstringBufferSub(){
	global 
	__timeIdle:=A_TimeIdleKeyboard=""?a_timeidle:A_TimeIdleKeyboard
	if (__timeIdle>__resetHotstringBufferInfo.IdleUnit)
		__resetHotstringBufferInfo.Idle+=__resetHotstringBufferInfo.IdleUnit
	else
		__resetHotstringBufferInfo.Idle:=0
		,__resetHotstringBufferInfo.IdlePriorReset:=false
	if (__resetHotstringBufferInfo.Idle>__resetHotstringBufferInfo.IdleThreshold){
		if (!__resetHotstringBufferInfo.IdlePriorReset){
			;~ Suspend on 
			;~ Suspend Off
			if(__resetHotstringBufferInfo.Target)
				PostMessage,% __resetHotstringBufferInfo.PostMsg,,,,% __resetHotstringBufferInfo.Target  ; effect target script
			else{
				Click up 2 ; global effect
			}
				
				;~ Hotstring("reset"), Dynamic_Hotstring("", "", "", "", "", true)
			
			if __resetHotstringBufferInfo.ShowTooltip
				showToolTip("Reset hotstring!")
			__resetHotstringBufferInfo.IdlePriorReset:=true
		}
		__resetHotstringBufferInfo.Idle:=0
		
	}
	return

}
