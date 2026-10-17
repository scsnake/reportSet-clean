#persistent
#notrayicon
#SingleInstance,Force
DetectHiddenWindows,on
#include <WM_COPYDATA>
#include <JXON>
process,priority,,r
#InstallKeybdHook
#InstallMouseHook
OnMessage(0x4a, "ON_WM_COPYDATA")
,OnMessage(0x10101, "autorun_1234_hotkey")

;~ __debug:=1
setbatchlines,-1

RISImpaxRegister([ {app: "Impax", type: "State", hwnd: thisHwnd, msg: {msg: 0x8001}, func: "ImpaxStateChange", initStart: 1}])

gui,main: +hwndguihwnd
WinSetTitle,% "ahk_id " guihwnd,,% "ImpaxSeriesList_main"
SetTimer,exit,3000


; Does not use CH_RIS — opt out of owning a local (IE-polling) CH_RIS. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
monitorInfo:=monitorInfo()

;~ Hotkey,IfWinActive,ahk_exe impax-client-main.exe
;~ Hotkey,tab,tab

return


#IfWinActive,ahk_exe impax-client-main.exe
toggleSeriesList:
if MouseOn("ahk_exe Miv2Lib.exe"){
	;~ winactivate,ahk_exe Miv2Lib.exe
	oldSendLevel:=a_sendlevel
	SendLevel, 0
	send {tab}
	SendLevel,% oldSendLevel
	return
}

MouseGetPos,,,mouseOnWin
if inArray(mouseOnWin, seriesListStored)
	SetTimer,toggleSeriesList,-500
else{
	toggleSeriesList(ImpaxState,"off","all",monitorInfo)
	PostMessage,0x2022,,,,RazerNaga_main ahk_class AutoHotkeyGUI
}
return

tab::
showSeriesList:
if MouseOn("ahk_exe Miv2Lib.exe") && !winvisible(WinExist("導覽器 ahk_class Afx:MiniFrame:400000:8:10007:10 ahk_exe Miv2Lib.exe")){
	;~ winactivate,ahk_exe Miv2Lib.exe
	oldSendLevel:=a_sendlevel
	SendLevel, 0
	send {tab}
	SendLevel,% oldSendLevel
	return 
}


if (ImpaxState[1]!=2 && ImpaxState[2,4]!=1)
	return
;~ seriesListStored:=toggleSeriesList(ImpaxState, "toggle", "all", monitorInfo)
showSeriesButtons:=toggleSeriesListAll(ImpaxState)
gosub adjustSeriesListWin
SetTimer,HideSeriesListAll,-3000
winactivate,% "ahk_id " ImpaxState[2,1]
return 

return
#IfWinActive

MouseMoveBack:
MouseMove,% mx,% my,0
return

HideSeriesListAll:
if GetKeyState("Lbutton") || GetKeyState("Rbutton") || GetKeyState("Mbutton") {
	SetTimer,,-500
	return
}
if(mouseOnSeriesList()){
	SetTimer,,-500
	return
}
if MouseOn("ahk_exe Miv2Lib.exe") {
	if winvisible(WinExist("導覽器 ahk_class Afx:MiniFrame:400000:8:10007:10 ahk_exe Miv2Lib.exe")){
		;~ WinActivate,ahk_exe Miv2Lib.exe
		oldSendLevel:=a_sendlevel
		SendLevel, 0
		send {tab}
		SendLevel,% oldSendLevel
	}
		return 
}

seriesListOn:=false
seriesLists:=getSeriesList(true)
for k,v in seriesLists {
	seriesListHwnd:=v[1]
	if !WinExist("ahk_id " seriesListHwnd) || !winvisible(seriesListHwnd)
		continue
	WinGetPos,wx,wy,ww,wh,% "ahk_id " seriesListHwnd
	whichMon:=whichMonitor(wx+ww//2,wy+wh//2, monitorInfo).1
	for x,y in showSeriesButtons {
		WinGetPos,wx2,wy2,ww2,wh2,% "ahk_id " y
		if between(wx2+ww2//2, monitorInfo[whichMon].l, monitorInfo[whichMon].r) 
			&& between(wy2+wh2//2, monitorInfo[whichMon].t, monitorInfo[whichMon].b) {
			ControlClick,,% "ahk_id " y
			break
		}
	}
	
}
return

mouseOnSeriesList(){
	global seriesLists
	MouseGetPos,,,mouseWin,mouseCon,2
	
	if (WinGet("ProcessName", w:=mouseWin)="Miv2Lib.exe") {
		return !!InStr(WinGetTitle(mouseWin), "導覽器")
	}
	
	
	for k,v in seriesLists
		if(v[1]=mouseWin){
			return true
		}
	return false
}

adjustSeriesListWin:
seriesLists:=getSeriesList(true)
mouseDistances:=[]
MouseGetPos,mx,my
for k,v in seriesLists {
	seriesListHwnd:=v[1]
	if !WinExist("ahk_id " seriesListHwnd) || !winvisible(seriesListHwnd)
		continue
	WinGetPos,wx,wy,ww,wh,ahk_id %seriesListHwnd%
	mouseDistances[Floor(Sqrt((mx-(wx+ww//2))**2+(my-(wy+wh//2))**2))+0]:=k
	if (ww<=monitorInfo[2].w/2)
		WinMove,% "ahk_id " seriesListHwnd,,,,,1000
	else
		WinMove,% "ahk_id " seriesListHwnd,,,,,500
	
}
for k,v in mouseDistances {
	WinGetPos,x,y,w,h,% "ahk_id " seriesLists[v][2]
	MouseMove,% mx,% y+100,0
	ToolTipDebug(A_ThisLabel)
	break
}
seriesListOn:=true
return 

#if seriesListOn
~LButton::
if !mouseOnSeriesList() || (cChartNo=getImpaxChartNo(ImpaxState))
	seriesListOn:=false
else {
	MouseGetPos,lastMx,lastMy
	cChartNo:=getImpaxChartNo(ImpaxState)
	SetTimer,HideSeriesListAll,-3000	
}
return
~LButton up::
Sleep 200
mousemove,% lastMx+150,% lastMy,0
ToolTipDebug(A_ThisLabel)
return
#if

autorun_1234_hotkey(){
	global 
	seriesListOn:=false
}

adjustSeriesListWinBack:
	WinMove,ahk_id %seriesListWin%,,% seriesListx,% seriesListy
return



exit:
if !WinExist("scsnake_autorun_main ahk_class AutoHotkeyGUI")
	ExitApp
return



On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
	global newX,newY,frame
; dwData = Command
; cbData = String lenght
; lpData = String
	dwData := NumGet(lParam+0, 0)
	,cbData := NumGet(lParam + A_PtrSize)
	,lpData := NumGet(lParam + 2*A_PtrSize)
	,str := StrGet(lpData)
	
	;~ str:=lpData
	
	If  (dwData = 19) ; CMD_CURRENTPOSITION
	{
		try
			j:=JXON_load(str)
		catch
			return
		
		if(j.haskey("command")){
			try 
			SetTimer,% j.command,-1
		}

	}
}




inArray(ele, arr){
	for k,v in arr
		if(ele=v)
			return true
	return false
}



impaxStateChange(){
	global 
	ImpaxState:=ImpaxOpened()
}