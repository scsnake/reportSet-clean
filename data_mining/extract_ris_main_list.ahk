﻿FileEncoding,utf-8-Raw
SetTitleMatchMode,2
DetectHiddenWindows,on
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <JXON>
SetBatchLines,-1
ComObjError(false)

SetWorkingDir,% rootDir:="E:\RISDB_MAIN"
FileCreateDir,% rootDir
ProgressFile:=rootDir "\progress.txt"
fileread,finished,% ProgressFile
processing:=""
,startDate:="20201001"
,EndDate:="20201031"
,saveByDays:=30
,lastDate:=""	
,win_finished:=""
,win_working:=""
,win_working_date:=[]
,debug:=false
,nextExit:=false
SetTimer,handleerror,1000
SetTimer,main,-1
SetTimer,ifexit,120000
return

rislogincall(){
	Sleep 10000
	SetTimer,main,-1
}

handleerror:
if _h:=WinExist("ahk_exe Menu.exe", "Unhandled exception") {
	Process,Close,% WinGet("PID", _h)
}
if _h:=WinExist("ahk_exe Menu.exe", "密碼輸入錯誤") {
	WinClose,% "ahk_id " _h
}
if _h:=WinExist("kReport", "查詢筆數過大, 是否確定?") {
	ControlClick,Yes,% "ahk_id " _h
}
return

main:
AllRis:=getRisTree()
if !AllRis.length()
{
	RisLogin("MOCK_USER", "MOCK_PASSWORD", logincallback:="rislogincall")
	if nextExit
		ExitApp
	return
}
;~ if AllRis.length()<2
;~ {
	;~ Sleep 5000
	;~ RisLogin("MOCK_USER", "MOCK_PASSWORD", logincallback:="rislogincall")
	;~ if nextExit
		;~ ExitApp
	;~ return
;~ }
;~ searchWin:=0
;~ for k,v in AllRis {
	;~ for x,ch in v.children {
		;~ if InStr(ch.title, "報告數量統計"){
			;~ searchWin:=ch.hwnd
			;~ break,2
		;~ }
	;~ }
;~ }
;~ if !searchWin
	;~ noSearchWin:=true

for k,v in AllRis {
	if InStr(wingettitle(v.main), "HC")
		continue
	 {
		
	
	;~ searchWin:=0
	;~ for x,ch in v.children {
		;~ if InStr(ch.title, "報告數量統計"){
			;~ searchWin:=ch.hwnd
			;~ break
		;~ }
	;~ }
	;~ if (!searchWin && noSearchWin){
		;~ ControlFocus,,% "ahk_id " b_id:=getNetAcc(v.main,"cmdReportCount","WindowsForms10.BUTTON",0,false)
		;~ ControlSend,,{Enter},% "ahk_id " b_id
		;~ noSearchWin:=false
		;~ goto main_return
	;~ }else if !searchWin {
		;~ continue
	;~ }
	
	searchWin:=v.main
	if !searchWin
		continue
	
	if (DllCall("IsHungAppWindow", "ptr", searchWin)) { ; busy
		continue
	}
	
	if InStr(win_working, (searchWin+0) ",") && !InStr(win_finished, (searchWin+0) ","){
		win_finished.=InStr(win_finished, (searchWin+0) ",") ? "" : (searchWin+0) ","
		goto main_return
	}
		
	
	
	if  InStr(win_finished, (searchWin+0) ",") && InStr(win_working, (searchWin+0) ","){
		dg:=getNetAcc(searchWin, "DataGridView1", "WindowsForms10.Window")
		if !dg
			continue
		
		winactivate,% "ahk_id " v.main
		;~ winactivate,% "ahk_id " searchWin
		;~ WinWaitActive,% "ahk_id " searchWin,,20
		;~ if ErrorLevel 
			;~ continue
		clipboard:=""
		data:=parseDataGrid2(acc_windowfromobject(dg), searchWin, "", wait:=false, useCurrentClipboard:=false, unselectAll:=false, selectAll:=true, grabTitle:=false, preserveClipboard:=false, useCtrlA:=true, outputClipboard:=true, activateRis:=true)
		if (data=-1)
			continue
		
		StringReplace,win_finished,win_finished,% (searchWin+0) ",",,all
		StringReplace,win_working,win_working,% (searchWin+0) ",",,all
		
		FileDelete,% f:=rootDir "\" (d:=win_working_date[searchWin][1]) (saveByDays==1?"":"_") ".txt"
		FileAppend,% data,% f,utf-8-Raw
		Loop % abs(saveByDays) {
			_d:=d
			_d+=(A_Index-1), Days
			StringReplace,processing,processing,% SubStr(_d,1,8) "`n",,all
			finished.=SubStr(_d,1,8) " " a_now "`n"
		}
		
		
		FileDelete,% ProgressFile
		FileAppend,% finished "`r`n",% ProgressFile,utf-8-Raw
		ShowToolTip("Saved: " (saveByDays==1?d:d " - " SubStr(_d,1,8)), 2000)
		if nextExit
			ExitApp
	}
	if nextExit
		continue
	d:=getNextDate()
	if(d=-1){
		nextExit:=true
		goto main_return
	}
	ToolTip % "Searching " (saveByDays==1? d[1] : d[1] " - " d[2])
	if(d[1]<=d[2])
		setRisSearchStartDate(d[1])
		,setRisSearchEndDate(d[2])
	else
		setRisSearchStartDate(d[2])
		,setRisSearchEndDate(d[1])
	;~ Control,ChooseString,OR,,% "ahk_id " getNetAcc(searchWin, "cboExam_1", "WindowsForms10.COMBOBOX",0,0)
	
	;~ ControlSetText,,% " ",% "ahk_id " sqlEdit:=getNetAcc(searchWin, "cboVS", "WindowsForms10.COMBO", 0, false)
	control,choosestring,所有類別,,% "ahk_id " getNetControl2(searchWin,"檢查類別","FID_LABEL","檢查類別","WindowsForms10.STATIC.app","","","",1)[1]
	control,choosestring,全部,,% "ahk_id " getNetControl2(searchWin,"狀態","FID_LABEL","狀態","WindowsForms10.STATIC.app","","","",1)[1]
	control,choosestring,所有診別,,% "ahk_id " getNetControl2(searchWin,"診別","FID_LABEL","診別","WindowsForms10.STATIC.app","","","",1)[1]
	control,choosestring,所有報告醫師,,% "ahk_id " getNetControl2(searchWin,"報告醫師","FID_LABEL","報告醫師","WindowsForms10.STATIC.app","","","",1)[1]
	control,choosestring,所有撰打住院醫師,,% "ahk_id " getNetControl2(searchWin,"撰打住院醫師","FID_LABEL","撰打住院醫師","WindowsForms10.STATIC.app","","","",1)[1]
	control,choosestring,所有執行住院醫師,,% "ahk_id " getNetControl2(searchWin,"執行住院醫師","FID_LABEL","執行住院醫師","WindowsForms10.STATIC.app","","","",1)[1]
	controlsettext,,% "",% "ahk_id " getNetControl2(searchWin,"病歷號","FID_LABEL","病歷號","WindowsForms10.STATIC.app","","","",1)[1]
	control,choosestring,所有檢查地,,% "ahk_id " (test:=getNetControl2(searchWin,"檢查地","FID_LABEL","檢查地","WindowsForms10.STATIC.app","","","",1))[1]
	ControlFocus,,% "ahk_id " FocusButton:=getNetAcc(searchWin, "cmdSearch", "WindowsForms10.BUTTON", 0, false)
	ControlSend,,{Enter},% "ahk_id " FocusButton
	win_working.=(searchWin+0) ","
	win_working_date[searchWin]:=d
	}
}
main_return:
SetTimer,main,-5000
return

getNextDate(){
	global lastDate,startDate,finished,processing,rootDir,EndDate,saveByDays
	if lastDate
		thisDate:=lastDate
	else
		thisDate:=startDate
	
	Loop {
		if (finished~=SubStr(thisDate,1,8) " ") || InStr(processing, thisDate) || FileExist(rootDir "\" thisDate ".txt") || FileExist(rootDir "\" thisDate "_.txt") {
			thisDate+=saveByDays,Days
			thisDate:=SubStr(thisDate,1,8)
			continue
		}
		thisDate:=SubStr(thisDate,1,8)
		
		if (EndDate!="" && ((saveByDays>0 && thisDate>=EndDate) || (saveByDays<0 && thisDate<=EndDate)))
			return -1
		Loop % abs(saveByDays) {
			d:=thisDate
			d+=(A_Index-1)*Abs(saveByDays)//saveByDays, Days
			processing.=SubStr(d,1,8) "`n"
		}
		
		lastDate:=thisDate
		return [thisDate, SubStr(d,1,8)]
	}
}

makeSqlInjectCmd(date1, date2=""){
	global debug
	
	if (date1!="" && date2!="" && StrLen(date1)=8 && StrLen(date2)=8 && date1>date2)
		d:=date2
		,date2:=date1
		,date1:=d
	
	while StrLen(date1)<14
		date1.="0"
	if date2=
		date2:=date1
	else
		while StrLen(date2)<14
			date2.="235959"
	if(date1=date2)
		date2:=SubStr(date1, 1, 8) (debug?"001000":"235959")
	ret:="ZQQZ')>0) OR EXAMDATE BETWEEN to_date('" date1 "','YYYYMMDDHH24MISS') AND to_date('" date2 "','YYYYMMDDHH24MISS') -- "
	/*
	ZQQZ')>0) OR EXAMDATE BETWEEN to_date('000000','YYYYMMDDHH24MISS') AND to_date('235959','YYYYMMDDHH24MISS') -- ``
	*/
	return ret
}

~esc::
if !(A_PriorHotkey=A_ThisHotkey && A_TimeSincePriorHotkey<400)
	return
nextExit:=true
ToolTip % "Will exit..."
return


ifexit:
if nextExit
	ExitApp
return