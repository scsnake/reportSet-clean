#NoEnv
#SingleInstance,force
#Persistent
#NoTrayIcon
process,Priority,,R
SetBatchLines,-1
SetControlDelay,-1
DetectHiddenWindows, On
SetTitleMatchMode,2
coordmode,mouse,screen

; CH_RIS IPC opt-out: this script is the OLD N hospital RIS/Impax poller (RisOpened/impaxOpened/
; ActivePacs) and never touches the CH_RIS object — but #include <risimpax> would auto-create
; an unused IE-polling CH_RIS owner (redundant update_wb poll + duplicate CH_RIS_GUI at C hospital).
; Set before the include so getPlace() hands back a proxy (never referenced) instead. Old N hospital
; behavior is unaffected. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <SetTimerF>
#include <WM_COPYDATA>
;~ #include <UIAutomationServer>
#include <JXON>
#include <EmptyMem>

;~ WinClose, ahk_exe RisImpaxPolling.exe

gui,1:Default
gui,+hwndguihwnd
WinSetTitle,ahk_id %guihwnd%,,RisImpaxPolling_Main

thisHwnd:=WinExist("ahk_pid " thisPid:=DllCall("GetCurrentProcessId"))

,risRefreshInterval:=-300
,impaxRefreshInterval:=-300
;~ , MsgFunc:={0x8000: "Ris_StateChange"
	;~ ,0x8001: "Ris_AccNoChange"
	;~ ,0x8002: "Ris_OldReportChange"
	;~ ,0x8003: "Impax_StateChange"
	;~ ,0x8004: "Impax_AccNoChange"}



,OnMessage(0x4A, "On_WM_COPYDATA")
,OnMessage(0x1001, "updateRis")
,OnMessage(0x1002, "updateImpax")




,RisRegisterList:={StateChange:{}
	, AccNoChange:{}
	, OldReportChange:{}
	, Count:0}
,ImpaxRegisterList:={StateChange:{}
	, AccNoChange:{}
	, Count:0}	


;~ for msg, fun in MsgFunc
	;~ OnMessage(msg, "parseUIAutomationServer")

;~ cmdUIAutomationServer(0x402D2,3,0x8000,3,thisHwnd)
blacklist:=[]
settimer,risRefresh,% risRefreshInterval
settimer,impaxRefresh,% impaxRefreshInterval
settimer,check_hwnd,-30000
settimer,EmptyMem,300000
;~ settimer,test,1000
return

test:
ToolTip % RisRegisterList.Count
return

^#!+d::
debug:
MsgBox % "RisRegisterList:`n" Exploreobj(RisRegisterList) "`n`nimpaxRegisterList:`n" Exploreobj(impaxRegisterList)
return
;~ parseUIAutomationServer(wParam, lParam, msg, hwnd){
	;~ a:=1
;~ }

EmptyMem:
EmptyMem(thisPid)
return

updateRis(){
	gosub risRefresh
}

risRefresh:
if (RisRegisterList.Count=0){
	settimer,,% risRefreshInterval
	return
}

cRisState:=RisOpened()
if (pRisState[1]!=cRisState[1] || pRisState[2]!=cRisState[2])
	;~ postMsg(RisRegisterList.StateChange)
	settimer,postMsg_RisState,-1
pRisState:=cRisState

if !DllCall("IsHungAppWindow", "ptr", cRisState[2]) {

	if(RisRegisterList.AccNoChange.SetCapacity(0)>0){
		cRisAccNo:=getRisAccNo(cRisState[2])
		if(pRisAccNo!=cRisAccNo && (cRisAccNo!="" || (++emptyRisAccCount>2) ))
			SetTimerFn("postMsg", -500, [RisRegisterList.AccNoChange])
			, pRisAccNo:=cRisAccNo
			, emptyRisRisAccCount:=0
	}

	if(RisRegisterList.OldReportChange.SetCapacity(0)>0){
		cOldReport:=ControlGetText(getRisReports(cRisState[2])[2,1])
		;~ ToolTip % A_TickCount "`and" cOldReport
		if(pOldReport!=cOldReport){
			;~ ToolTip % exploreobj(RisRegisterList.OldReportChange)
			;~ postMsg(RisRegisterList.OldReportChange)
				settimer,postMsg_RisOldreport,-1
		}
		pOldReport:=cOldReport
	}
}
settimer,,% risRefreshInterval
return

updateImpax(){
	gosub impaxRefresh
}

impaxRefresh:

if (impaxRegisterList.Count=0){
	settimer,,% impaxRefreshInterval
	return 
}

cimpaxState:=impaxOpened()
;~ ToolTip % exploreobj(cimpaxState)
if (pimpaxState[1]!=cimpaxState[1] || pimpaxState[2,1]!=cimpaxState[2,1] || pimpaxState[2,4]!=cimpaxState[2,4]){
	;~ postMsg(impaxRegisterList.StateChange)
	settimer,postMsg_ImpaxState,-1
	
}
pimpaxState:=cimpaxState

if(impaxRegisterList.AccNoChange.SetCapacity(0)>0){
	;~ cImpaxAccNo:=getimpaxAccNo(cimpaxState[2])
	cImpaxAccNo:=(new ActivePacs).getAccNo()
	if(pImpaxAccNo!=cImpaxAccNo)
		SetTimerFn("postMsg", -500, [impaxRegisterList.AccNoChange])
	pImpaxAccNo:=cImpaxAccNo
}

settimer,,% impaxRefreshInterval
return


;~ esc::ExitApp

postMsg_ImpaxState:
postMsg_RisState:
postMsg_RisOldreport:
RegExMatch(A_ThisLabel, "_([A-Z][a-z]+)([A-Za-z]+)$", lbl)
postMsg(%lbl1%RegisterList[lbl2 "Change"])
return

postMsg(list){
	;~ ToolTip test
	;~ ToolTip % Exploreobj(list) "," A_TickCount
	for hwnd, msg in list
		PostMessage,% msg.msg,% msg.wParam,% msg.lParam,,% "ahk_id " hwnd
}

check_hwnd(){
	global hwnd_lock, RisRegisterList, impaxRegisterList
	if (hwnd_lock){
		settimer,,-500
		return 
	}
	hwnd_lock:=true
	
	,hwndList:=[]
	for item, list in RisRegisterList
		for hwnd, msg in list
			if !WinExist("ahk_id " hwnd)
				RisRegisterList[item].delete(hwnd)
			else
				hwndList[hwnd]:=1
	RisRegisterList.Count:=hwndList.SetCapacity(0)
				
	,hwndList:=[]
	for item, list in impaxRegisterList
		for hwnd, msg in list
			if !WinExist("ahk_id " hwnd)
				impaxRegisterList[item].delete(hwnd)
			else
				hwndList[hwnd]:=1
	impaxRegisterList.Count:=hwndList.SetCapacity(0)
	
	
	
	,hwnd_lock:=false
	
	if (RisRegisterList.Count + impaxRegisterList.Count =0)
		settimer,exit,-120000
	else
		settimer,exit,Off
	settimer,,-60000
}

exit:
ExitApp
return

ParseQuery(str){
	local json,app,k,cmd
	
	;~ if(hwnd_lock)
		;~ return SetTimerFn("ParseQuery", -500, [str])
	hwnd_lock:=true
	try
		json:=jxon_load(str)
	catch e
		return
	
	;~ if RisRegisterList.Count=1
		;~ a:=1
	
	for k, cmd in json
		if WinExist("ahk_id "  cmd.hwnd){
			app:=cmd.App ; Ris or Impax
			,%app%RegisterList[cmd.Type "Change", cmd.hwnd]:=cmd.msg ; {msg: , wParam, lParam}
			PostMessage,% cmd.msg,% cmd.wParam,% cmd.lParam,,% "ahk_id " cmd.hwnd
		}
	%app%RegisterList.Count++
	,hwnd_lock:=false
}

On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
; dwData = Command
; cbData = String lenght
; lpData = String
;~ static i:=0
	dwData := NumGet(lParam+0, 0)
	,cbData := NumGet(lParam + A_PtrSize)
	,lpData := NumGet(lParam + 2*A_PtrSize)
	,str := StrGet(lpData)
	
	;~ str:=lpData
	
	ParseQuery(str)
	;~ ToolTip % ++i
}
