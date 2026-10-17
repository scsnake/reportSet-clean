#include <MonitorInfo>
#include <SetTimerClass>
#include <ShowToolTip>
#include <WinFocus>
#InstallKeybdHook
DetectHiddenWindows,on

;~ w:= new cmdWindow("test")
;~ esc::ExitApp
;~ test(t){
	;~ MsgBox % t
;~ }

class cmdWindow extends SetTimerClass {
	static monitors, hwnd, EditHwnd, callback
	__New(callbackFunc="", show=5000){
		MouseGetPos,x,y
		
		if !cmdWindow.monitors
			cmdWindow.monitors:=monitorInfo()
		
		if !callbackFunc
			callbackFunc:=Func("ShowToolTip")
		else if !IsObject(callbackFunc)
			callbackFunc:=Func(callbackFunc)
		
		cmdWindow.callback:=callbackFunc
		
		m:=monitors[whichMonitor(x,y,monitors)[1]]
		this.show:=show
		
		if WinActive("ahk_id " cmdWindow.hwnd){
			this.setTimer("hide", "off")
			,this.setTimer("hide", (-1)*show)
			,this.active:=false
			,this.SetTimer("activity", 500)
			return
		}
			
		
		
		if !WinExist(cmdWindow.hwnd){
			gui,cmdWindow:new,+hwndguihwnd +ToolWindow -Caption
			gui,Color,060606
			winset,trans,200,% "ahk_id " guihwnd
			gui,Font,s12,Calibri
			cmdWindow.hwnd:=guihwnd
			gui,Add,edit,hwndeditHwnd w400 h50
			;~ gui,Add,button,g__cmdWindowSubmit x0 y0 w0 h0 Default
			cmdWindow.EditHwnd:=EditHwnd
			gui,show,NoActivate
			
			Hotkey,IfWinActive,% "ahk_id " guihwnd
			Hotkey,esc,__cmdWindowHide,on
			Hotkey,^Enter,__cmdWindowSubmit,on
			Hotkey,NumpadEnter,__cmdWindowSubmit,on
			Hotkey,IfWinActive
		}
		if ((show) && !WinActive("ahk_id " cmdWindow.hwnd)){
			this.setTimer("hide", "off")
			WinFocus(cmdWindow.hwnd, cmdWindow.EditHwnd)
			WinGetPos,,,w,h
			WinMove,% "ahk_id " cmdWindow.hwnd,,% m.l+(m.w-w)//2,% m.t+(m.h-h)//2
			winset,AlwaysOnTop,on,% "ahk_id " cmdWindow.hwnd
			this.setTimer("hide", (-1)*show)
			this.active:=false
			this.SetTimer("activity", 500)
		}
		
	}
	
	activity(){
		if WinActive("ahk_id " cmdWindow.hwnd) && (A_TimeIdleKeyboard<500)
			this.active:=true
		else 
			this.setTimer("hide", "off"), this.setTimer("hide", (-1)*this.show)
			,this.active:=false
		;~ ToolTip % this.active
	}
	
	Hide(){
		if this.active
			return
		WinHide,% "ahk_id " cmdWindow.hwnd
		winset,AlwaysOnTop,Off,% "ahk_id " cmdWindow.hwnd
		this.DisposeTimers()
	}
	
	Submit(){
		ControlGetText,cmd,,% "ahk_id " cmdWindow.EditHwnd
		ControlSetText,,% "",% "ahk_id " cmdWindow.EditHwnd
		this.Hide()
		cmdWindow.callback.call(cmd)
	}
}


__cmdWindowSubmit(){
	cmdWindow.Submit()
}
__cmdWindowHide(){
	cmdWindow.Hide()
}
