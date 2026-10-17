#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
;~ #SingleInstance,Ignore
#SingleInstance,Force
process,Priority,,H
SetBatchLines, -1
coordMode,mouse,screen
CoordMode,caret,screen
DetectHiddenWindows,on
SetTitleMatchMode,2
SetControlDelay,-1
comobjerror(false)
onexit,onexit
#Persistent
#NoTrayIcon
#InstallKeybdHook
#InstallMouseHook


; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <risimpax>
#include <ImpaxContextServer>

preOpen:=false
gui,new,,impaxOpenNext_main
OnMessage(0x10102, "open")
monitors:=monitorInfo()
;~ open(0,0,0,0)
SetTimer,resetAllOpened,3600000
return

reset:
opening:=false
,escHook.stop()
,sameStudy:=""
,RisSameStudyAccNos:=[]
resetAllOpened:
AllOpened:=[]
return 

^+Up::
preOpen:=!preOpen
ShowToolTip("Pre-open mode: " preOpen, 2000)
return

~LButton::
~RButton::
ClickOnOldHx()
return

ClickOnOldHx(){
	global lastClickOnOldHx, noOldHx
	MouseGetPos,,,win,con,2
	if (WinGetTitle(win)~="Radiology Information System") && (getControlNameByHwnd(win,con)="dgHisReport")
		lastClickOnOldHx:=A_TickCount, noOldHx:=true
	
}


open(w,l,m,h){	
	local k,v
	
	
	RisHwnd:=RisOpened(1)[2,1]
	if !RisHwnd
		return
	if InStr(WinGetTitle(risHwnd), "HC"){
		PostMessage,0x2020,,,,EBM Preload ahk_class AutoHotkeyGUI
		return
	}
	
	
	if (opening) && !l {
		SetTimerF("open",-1000,[w,l,m,h])
		return
	}
	
	WinGetPos,,,w,,% "ahk_id " impaxopened()[2,1]
	winget,MinMax,MinMax,% "ahk_id " impaxopened()[2,1]
	if(MinMax=-1 || w<500){
		WinRestore,% "ahk_id " impaxopened()[2,1]
		;~ WinMove,% "ahk_id " impaxopened()[2,1],,% monitors[2].l,% monitors[2].t,% monitors[3].r-monitors[2].l+1,% monitors[2].h
	}
	
	
	accNo:=getRisAccNo(risHwnd)
	if !accNo
		return
	
	
	if(!l && preOpen)
		SetTimerF("open", -3000, [w,1,m,h])
	if RisChartNoMatchPacs(risHwnd,"", chartNo)
		return
	
	
	
	SetTimer,ConfirmOpen,Off
	
	
	if (!preOpen){
		if InStr(WinGetTitle(risHwnd), "A0") && ((chartNo:=getRisChartNo(risHwnd))~="^\d") {  ;;; T0 chartno in A0, open in impax
			__maskImpaxClose()
			,ImpaxSearch(chartNo, "", "", "dbclick")
			if !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
				maskImpaxLoading()
		}else{
			if !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
				maskImpaxLoading()
			risOpenStudyImpax(risHwnd)
		}
		risOpenOldStudy(risHwnd)
	}
	
	else {
		
	
	;~ /* practically slow 
	
	if (getImpaxQueueNumber()>20) {
		ImpaxContextServer_ClearDisplay()
	}
	;~ FileAppend,% "Opening: " A_TickCount ", " w ", " h "`n",log.txt,utf-8
	
	
	opening:=true
	,noOldHx:=false
	;~ ReportList:=ParseDataGrid2()
	,accNos:=[]
	;~ , ImpaxContextServer_Add(accNo)
	, ImpaxContextServer_Show(accNo)
	, accNos[accNo]:=1
	;~ Sleep 100
	,sameStudy:=ReportList.getSameStudy(accNo)
	,examItems:=parseRisExamItems(getRisExamItems(RisHwnd))
	if (examItems[1].length() != examItems[2].length()){
		RisSameStudyAccNos:=getRisSameStudyAccNos(risHwnd)
	}else{
		RisSameStudyAccNos:=[]
	}
	
	if(!w){
		
		accNos:=[]
		, ImpaxContextServer_Show(accNo)
		, accNos[accNo]:=1
		
		for k,v in sameStudy
			if !accNos.haskey(ac:=v.getCell("accNo")){
				ImpaxContextServer_Show(ac)
				,accNos[ac]:=1
				;~ Sleep 100
			}
		
		for k,v in RisSameStudyAccNos
			if !accNos.haskey(ac:=v){
				ImpaxContextServer_Show(ac)
				,accNos[ac]:=1
				;~ Sleep 100
			}

		Loop {
			Sleep 100
		}until RisChartNoMatchPacs(risHwnd) || (A_Index>15)
		
	}
	
	if !RisChartNoMatchPacs(risHwnd,"", chartNo){
		if (getImpaxQueueNumber()>20) {
			ImpaxContextServer_ClearDisplay()
			;~ Sleep 300
		}
		accNos:=[]
		,ImpaxContextServer_Add(accNo)
		,ImpaxContextServer_Show(accNo)
		,AllOpened[AccNo]:=1
		,accNos[accNo]:=1
		,sameStudyOpened:=IsObject(sameStudy)
		for k,v in sameStudy
			if !accNos.haskey(ac:=v.getCell("accNo")){
				ImpaxContextServer_Add(ac)
				,ImpaxContextServer_Show(ac)
				,accNos[ac]:=1
				,SetTimerFn("ResendImpaxContextServerForOldStudy", -3000, [ac])
				;~ Sleep 100
			}
		
		for k,v in RisSameStudyAccNos
			if !accNos.haskey(ac:=v){
				ImpaxContextServer_Add(ac)
				,ImpaxContextServer_Show(ac)
				,AllOpened[ac]:=1
				,accNos[ac]:=1
				;~ Sleep 100
			}
		
		;~ risOpenStudyImpax(risHwnd)
		
		RisListHwnd:=getRisList(risHwnd)
		,RisListAcc:=acc_ObjectFromWindow(RisListHwnd)
		,compareList(ReportList, RisListAcc, RisListHwnd)
		,sameStudy:=ReportList.getSameStudy(accNo)
		
		,accNos:=[]
		if !sameStudyOpened
			for k,v in sameStudy:=ReportList.getSameStudy(accNo)
				if !accNos.haskey(ac:=v.getCell("accNo")){
					ImpaxContextServer_Add(ac)
					,ImpaxContextServer_Show(ac)
					,SetTimerFn("ResendImpaxContextServerForOldStudy", -3000, [ac])
					,AllOpened[ac]:=1
					,accNos[ac]:=1
					;~ Sleep 100
				}
			
		
		if !(A_TickCount-lastClickOnOldHx<3000) && !noOldHx && !GetKeyState("Shift")
			risOpenOldStudy(risHwnd)
	
		
		escHook.stop()
		,escHook:=InputHook("V L1")
		,escHook.KeyOpt("{ESC}", "E")
		,escHook.start()
		
		;~ SetTimer,ConfirmOpen, 3000
		
		SetTimer,openNext, -3000
		;~ Loop {
			;~ Sleep 100
		;~ }until RisChartNoMatchPacs(risHwnd) || (A_Index>30)
		
		
	}else{
		if !(A_TickCount-lastClickOnOldHx<3000) && !noOldHx && !GetKeyState("Shift")
			risOpenOldStudy(risHwnd)
	}
	;~ */
	}
	opening:=false
}

ConfirmOpen(){
	global risHwnd, escHook, RisSameStudyAccNos, AllOpened, lastClickOnOldHx, noOldHx
	if RisChartNoMatchPacs(risHwnd,"", chartNo) || escHook.EndKey {
		if !(A_TickCount-lastClickOnOldHx<3000) && !noOldHx && !GetKeyState("Shift")
			risOpenOldStudy(risHwnd)
		SetTimer,openNext,-3000
		SetTimer,ConfirmOpen,Off
	}else{
		accNos:=[]
		,accNo:=getRisAccNo(risHwnd)
		,sameStudy:=ReportList.getSameStudy(accNo)
		for k,v in sameStudy
			if !accNos.haskey(ac:=v.getCell("accNo")){
				ImpaxContextServer_Add(ac)
				,ImpaxContextServer_Show(ac)
				,SetTimerFn("ResendImpaxContextServerForOldStudy", -3000, [ac])
				,AllOpened[ac]:=1
				,accNos[ac]:=1
				;~ Sleep 100
			}
		
		for k,v in RisSameStudyAccNos
		if !accNos.haskey(ac:=v){
			ImpaxContextServer_Add(ac)
			,ImpaxContextServer_Show(ac)
			,SetTimerFn("ResendImpaxContextServerForOldStudy", -3000, [ac])
			,AllOpened[ac]:=1
			,accNos[ac]:=1
			;~ Sleep 100
		}
	}
	
}


openNext(){
	global ReportList, sameStudy, sameStudyOpened, risHwnd, AllOpened, escHook
	accNos:=[]		
	,nextAccNos:=[]
	,nextChartNos:=[]
	,row:=ReportList.getRow("AccNo", accNo:=getRisAccNo(risHwnd))
	
	if escHook.EndKey
		return
	
	if !(rowNo:=row.rowNo)
		return 
	
	Loop 5 {
		if (nextAccNo:=ReportList.getCell(rowNo+A_Index, "AccNo")){
			for k,v in ReportList.getSameStudy(nextAccNo)
				if !accNos.haskey(ac:=v.getCell("accNo")){
					;~ ImpaxContextServer_Add(ac)
					nextAccNos.push(ac)
					,nextChartNos[v.getCell("ChartNo")]:=1
					;~ ,accNos[ac]:=1
					;~ Sleep 200
				}
		}
			
	}
	
	if(nextChartNos.length()>1){  ; if all same chartNo, pass
		for k,v in nextAccNos {
			if !AllOpened.haskey(v)
				ImpaxContextServer_Add(v)
				,AllOpened[v]:=1
			;~ Sleep 200
		}
		
		
		;~ Loop 3 {
		if !RisChartNoMatchPacs(risHwnd,"", chartNo)
			for k,v in sameStudy:=ReportList.getSameStudy(accNo) {
				ImpaxContextServer_Show(v.getCell("accNo"))
				;~ Sleep 100
			}
			;~ Sleep 300
			;~ if RisChartNoMatchPacs(risHwnd,"", chartNo)
				;~ break
		;~ }
		
			
	}
}

;~ esc::
OnExit:
ExitApp