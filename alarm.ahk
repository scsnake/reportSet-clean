#SingleInstance,Ignore
#persistent
CoordMode,mouse,Screen
SetTitleMatchMode,2

try
	menu, tray, icon,% a_scriptdir "\alarm.ico",1,0

loop {
	inputbox,t,% "設定",% "每隔幾分鐘提醒?",,300,160,,,,20,20
	if errorlevel=1
		exitapp
	if (t+=0) && t>0
		break
}
if(t<1)
	t:=1
menu,tray,add,暫停/繼續,pauseTimer
menu,tray,add,重新計時,reset
pause:=0
start:=a_now
idle:=0
idling:=0
settimer,alarm,60000

;~ debug:
;~ Elapsed:=100
;~ gosub test

return

pauseTimer:
pause
return

reset:
start:=A_Now
idle:=0
idling:=0
traytip,,重新計時!,1
settimer,alarm,60000
SetTimer,waitMsgBoxClose,Off
;~ winclose,% "活動一下" ,% "分鐘過去了，站起來伸展一下！"
WinClose,__alarm_mask ahk_class AutoHotkeyGUI
return

alarm:
if pause
	goto alarmEnd
if (A_TimeIdlePhysical>40000) {
	++idle,++idling
	if(idling>=10){
		start:=a_now
		goto alarmEnd
	}
}else{
	idle:=0
	idling:=0
}
now:=A_Now
now-=start,s

elapsed:=now/60-idle
;~ traytip,,% floor(elapsed) "min",5
test:
if (elapsed>=t-0.1) {
	winget,activeWin,id,A
	MouseGetPos,x,y
	SetTimer,waitMsgBoxClose,-1
	;~ MsgBox, 4160,% "活動一下" ,% t "分鐘過去了，站起來伸展一下！",% t*60-10
	
	monitorInfo:=monitorInfo()
	,maskDim:=[]
	
	for k,v in monitorInfo {
		for _, attr in ["l","t"] {
			if (maskDim[attr]="") || (maskDim[attr]>v[attr])
				maskDim[attr]:=v[attr]
		}
		for _, attr in ["r","b"] {
			if (maskDim[attr]="") || (maskDim[attr]<v[attr])
				maskDim[attr]:=v[attr]
		}
	}
	SetTimer,closeMask,-20000
	countInd:=20
	SetTimer,Counting,1000
	start:=a_now
	idle:=0
	idling:=0
	while 1 {
		if A_Index>10
			break
		if A_TimeIdlePhysical>1000
			break
		Sleep 1000
	}

	gui,__alarm_mask:new
	gui,+toolwindow -caption +alwaysontop +hwnd__alarm_mask_Hwnd
	gui,__alarm_mask:Color,black
	gui,__alarm_mask:Font,cGray s30,Verdana
	gui,__alarm_mask:Add,Text,% "x" Floor(monitorInfo[1].l + monitorInfo[1].w/2)-maskDim.l " y" Floor(monitorInfo[1].t + monitorInfo[1].h/2)-maskDim.t " valarm_mask_text",% "Eye rest for 20 seconds ..."
	gui,__alarm_mask:Show,% "x" maskDim.l " y" maskDim.t " w" (maskDim.r-maskDim.l) " h" (maskDim.b-maskDim.t),__alarm_mask
	
	return
}
alarmEnd:
gui,Font,s50 cred,Verdana
gui,Color,EEAA99
gui,+ToolWindow -Border -Caption +hwndguihwnd +lastfound
WinSet, TransColor, EEAA99
gui,Add,Text,,% Floor(elapsed)
gui,Show,xcenter ycenter NA,Show Elapsed
DllCall("SetWindowPos", "UINT", guihwnd, "UINT", 0, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
,DllCall("SetWindowPos", "UINT", guihwnd, "UINT", -1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
SetTimer,CloseGUI,-1000
return

Counting:
guicontrol,__alarm_mask:,alarm_mask_text,% "Eye rest for " (--countInd) " seconds ..."
return

#IfWinExist,__alarm_mask ahk_class AutoHotkeyGUI
^q::
gosub closeMask
return
#IfWinActive

;~ esc::
CloseGUI:
gui,Destroy
return

closeMask:
gui,__alarm_mask:Destroy
;~ WinFade(__alarm_mask_Hwnd)
return

waitMsgBoxClose:
;~ WinWaitClose,活動一下,分鐘過去了，站起來伸展一下
if WinExist("__alarm_mask ahk_class AutoHotkeyGUI"){
	SetTimer,,-1000
	return
}
winactivate,ahk_id %activeWin%
MouseMove,% x,% y,0
return