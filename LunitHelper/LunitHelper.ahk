#MaxMem 4095
#NoEnv
#SingleInstance,force
#MaxHotkeysPerInterval,999999
#UseHook
process,Priority,,h
SetBatchLines,-1
DetectHiddenWindows, On
SetTitleMatchMode,2
coordmode,mouse,screen

SetTitleMatchMode 2
SetTitleMatchMode fast
SetBatchLines, -1
SetKeyDelay, -1, -1, -1
SetMouseDelay, -1
SetWinDelay, -1
SetControlDelay, -1
SetDefaultMouseSpeed, 0

; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>


OnExit,OnExit
__debug:=1

monitors:=monitorInfo()
,RISImpaxRegister([  {app: "Ris", type: "State", hwnd: thisHwnd, msg: {msg: 0x8000}, func: "RisStateChange", initStart: 1}
	, {app: "Ris", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x1122}, func: "accNoChanged", initStart: 100}
	, {app: "Impax", type: "State", hwnd: thisHwnd, msg: {msg: 0x8001}, func: "ImpaxStateChange", initStart: 1}], true)
,resultPwb:=ComObjCreate("InternetExplorer.application")
,resultPwb.Visible:=!!__debug

return


RisStateChange(){
	global
	ToolTipDebug(A_ThisFunc)
	RisState:=RisOpened()
}

impaxStateChange(){
	global 
	ToolTipDebug(A_ThisFunc)
	ImpaxState:=ImpaxOpened()
	
}

accNoChanged(){
	global
	ToolTipDebug(A_ThisFunc)
	RisReports:=getRisReports(RisState[2])
	SetTimer,risAccChanged,-500
}

risAccChanged:
;~ gui,new,+ToolWindow
;~ gui,Add,Picture,x0 y0,
;~ pwbNav(resultPwb, "file:///C:\Users\IDI\Downloads\I0000001.png")
;~ WinMove,% resultPwb.hwnd,,% (m:=monitors[2]).l,% m.t, % m.w,% m.h
;~ resultPwb.Visible:=true
return


pwbNav(ByRef pwb, url){
	if !(WinExist("ahk_id " pwb.hwnd))
		pwb:=ComObjCreate("InternetExplorer.application")
	pwb.NAvigate(url)
}

esc::
OnExit:
try
	resultPwb.quit()
ExitApp