#MaxMem 4095
#NoEnv
#SingleInstance,force
process,Priority,,h
SetBatchLines,-1
DetectHiddenWindows, On
SetTitleMatchMode,2
coordmode,mouse,screen
sendmode input
#NoTrayIcon
OnExit,OnExit
#InstallKeybdHook
; Does not use CH_RIS — opt out of owning a local (IE-polling) CH_RIS. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <MonitorInfo>
#include <RisImpax>

monitors:=monitorInfo()

MouseMoveInterval:=monitors[2].h//200

thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))
,RISImpaxRegister([ {app: "Impax", type: "State", hwnd: thisHwnd, msg: {msg: 0x8001}, func: "ImpaxStateChange", initStart: 1}])
,impaxState:=impaxOpened()
GroupAdd,ImageWin,% "ahk_id " ImpaxState[2,1]

image_scroll_prior_key:=","
image_scroll_next_key:="."

Hotkey,IfWinActive,ahk_group ImageWin
Hotkey, % image_scroll_prior_key " UP",image_scroll_up,on
Hotkey, % image_scroll_prior_key,image_scroll_down,on
Hotkey, % image_scroll_next_key " UP",image_scroll_up,on
Hotkey, % image_scroll_next_key,image_scroll_down,on
Hotkey,IfWinActive

return


#ifWinActive,ahk_group ImageWin

image_scroll_up:
;~ ToolTip % A_ThisHotkey image_scroll_prior_key A_TickCount
if SubStr(A_ThisHotkey,1,1)!=__image_scroll
	return
if GetKeyState("Lbutton")
	send {LButton up}
ToolTip % A_ThisHotkey "," __image_scroll "," GetKeyState(image_scroll_next_key) "," GetKeyState(image_scroll_prior_key)
__image_scroll:=""
return


+j::
send {Left}
return

+k::
send {Right}
return

+h::
send {Up}
return

+l::
send {Down}
return

image_scroll_down:
if (__image_scroll=SubStr(A_ThisHotkey,1,1))
	return
else if (__image_scroll="")
	MoveToFrameEdge()

__image_scroll:=SubStr(A_ThisHotkey,1,1)
if !GetKeyState("Lbutton")
	send {LButton Down}
SetTimer,% InStr(__image_scroll, image_scroll_prior_key)?"MouseMoveUp":"MouseMoveDown",10
return


#IfWinActive

mouseMoveDown:
mouseMoveUp:
if (!__image_scroll || (InStr(A_ThisLabel, "UP") && __image_scroll=image_scroll_next_key) || (InStr(A_ThisLabel, "Down") && __image_scroll=image_scroll_prior_key)) {
	SetTimer,,Off
	return
}
MouseGetPos,x,y
MouseMove,% x,% y+(InStr(A_ThisLabel,"UP")?(-1):1)*MouseMoveInterval,1
return

MoveToFrameEdge(){
	global monitors
	MouseGetPos,x,y,win,con,2
	if !(Control_GetClassNN(win,con)~="AfxWnd\d+u\d+")
		return
	WinGetPos,wx,wy,,,% "ahk_id " win
	ControlGetPos,cx,cy,cw,ch,,% "ahk_id " con
	n:=whichMonitor(x,y,monitors)[1]=2?4:1
	mousemove,% wx+cx+cw*n//5,% wy+cy+ch//2,0
}

ImpaxStateChange(){
	global 
	impaxState:=impaxOpened()
	GroupAdd,ImageWin,% "ahk_id " ImpaxState[2,1]
}


esc::
OnExit:
ExitApp

