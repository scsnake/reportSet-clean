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

OnExit,OnExit

; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <portallib>
#Include %A_ScriptDir%
#include jpegDirName.ahk

if CryptFilePW()
	ExitApp

preOpened:=16

GroupAdd,simpleRisGui,simple RIS ahk_class AutoHotkeyGUI
GroupAdd,simpleRisGui,ahk_exe Menu.exe

thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))
, RISImpaxRegister([  {app: "Ris", type: "State", hwnd: thisHwnd, msg: {msg: 0x8000}, func: "RisStateChange", initStart: 1}
	, {app: "Ris", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x1122}, func: "accNoChanged", initStart: 100} ])
	
, monitors:=monitorInfo()
,pwbPool:=[]   ;;; accNo: pwb's
,pwbHwndPool:=[]   ;;; accNo: pwb's hwnd
,thisPwbMonitor:=1
,personIdPool:=[]
,reportDir:=A_MyDocuments "\feedRIS"
,ini:=a_scriptdir "\PacsIE.ini"
gosub setHotKey
sid:=askForPortalIdPw(0,1,"A")
;~ SetTimer,refresh,120000
settimer,checkMatch,500
inputClipboard:=clipboard
RisHwnd:=RisOpened(1)[2][1]
	
	
	reportList:=[]
	reportListOriginal:=parseDataGrid2("", RisHwnd,"", "", true, false, false, true)
	statusCol:=reportListOriginal.getColNo("status")
	,ChartNoCol:=reportListOriginal.getColNo("ChartNo")
	,AccNoCol:=reportListOriginal.getColNo("AccNo")
	,ExamDateCol:=reportListOriginal.getColNo("ExamDate")
	,ExamNameCol:=reportListOriginal.getColNo("ExamName")
	,reportvsCol:=reportListOriginal.getColNo("ReportVS")
	
	,reportList.push(reportListOriginal[1])
	for k,v in reportListOriginal.data
		if (k==1){
			continue
		}else if (v[statusCol]!="已發報告") {
			if  (!FileExistValid(jpegDirName(reportDir, v[AccNoCol] , v[ChartNoCol]) ".txt")) 
    		  && (!FileExistValid(reportDir "\" v[AccNoCol] " " v[ChartNoCol] ".txt") && !FileExistValid(reportDir "\" __CryptStr(v[AccNoCol] " " v[ChartNoCol],____) ".txt")) {
				reportList.push(v)
			}
		}
	reportList:=new DataGridTable(reportList)
	,reportListLen:=reportList.data.length()
	,currentAccNo:=getRisAccNo(RisState[2])
	,currentChartNo:=getRisChartNo(RisState[2])
	,currentRow:=reportList.getRow("AccNo", currentAccNo)
	if (currentRow.rowNo){
		i:=currentRow.rowNo
	}else{
		i:=2
	}

if (reportListLen<2){
	MsgBox % "No study!"
	ExitApp
}


Loop % preOpened {
	row:=reportList[i+A_Index-1]
	hwnd:=openFilm(row[AccNoCol], row[ChartNoCol])
	if !personIdPool.haskey(row[ChartNoCol])
		personIdPool[row[ChartNoCol]]:=patientBasicInfo(row[ChartNoCol],sid).personId
	if (A_Index=1)
		FirstPwbHwnd:=hwnd
		,activateStudy(FirstPwbHwnd)
	else
		WinHide,% "ahk_id " hwnd
	;~ if A_Index!=preOpened
		;~ Sleep 1000
}
if preOpened>1
	preshow(i+1)
;~ PostMessage,0x2024,,,,simpleRIS__main ahk_class AutoHotkeyGUI
return

openFilm(accno, chartno){
	global sid, pwbPool, pwbHwndPool, personIdPool, thisAspId, priorAccNo, GEZAspId
	
	if(accNo=""  || chartNo="")
		return
	
	
	
	if !pwbPool.haskey(accNo) || !WinExist("ahk_id " pwbHwndPool[accNo])
		needLoad:=true
	else  {
		hwnd:=pwbHwndPool[accNo]
		pwb:=pwbPool[accNo]
		html:=pwb.document.body.innerHTML
		if !InStr(html, accno)
			needLoad:=true
		else {
			if InStr(html, "系統通訊錯誤")
				;~ Loop % (Buttons:=pwb.document.getElementsByTagName("BUTTON")).length {
					;~ button:=Buttons[A_Index-1]
					;~ if InStr(button.className, "ajs-button") && InStr(button.className, "ajs-ok") && button.innerText="確定" {
						;~ button.Click()
						;~ break
					;~ }
						
				;~ }
				;~ ReloadAll()
				pwb.quit(), pwbPool.delete(accNo), pwbHwndPool.delete(accNo)
				,needLoad:=true
		}
	}
	
	
	
	if (needLoad) {
		if !personIdPool.haskey(chartNo)
			personIdPool[chartNo]:=patientBasicInfo(ChartNo,sid).personId
		
		GEZFPurl:=getGEZFPurl(sid, accNo, chartNo, personIdPool[chartNo])
		;~ GEZFPurl:=getGEZFPurl(sid, accNo, chartNo,"TEST_NID_001")
		;~ if !thisAspId
			token:=GEZFPauth(GEZFPurl)
			;~ , thisAspId:=GEZAspId
		
		if pwbPool.haskey(priorAccNo)
			pwb:=pwbPool[priorAccNo]
		else
			pwb:=ComObjCreate("InternetExplorer.Application")
		hwnd:=pwb.hwnd
		;~ pwb.Visible:=true
		;~ smallActivate(hwnd)
		pwb.navigate(GEZFPurl)
		pwbPool[accNo]:=pwb
		pwbHwndPool[accNo]:=hwnd
		
		
	}else{
		hwnd:=pwbHwndPool[accNo]
	}
	
	return hwnd
}

smallActivate(hwnd){
	activeWin:=WinExist("A")
	WinMove,% "ahk_id " hwnd,,0,0,1,1
	WinShow,% "ahk_id " hwnd
	Winactivate,% "ahk_id " hwnd
	Winactivate,% "ahk_id " activeWin
}

refresh:
sid:=askForPortalIdPw(0,1,"A")
return

RisStateChange(){
	global 
	RisState:=RisOpened()
}

;~ accNoChanged(){
	;~ global
	;~ thisAccNo:=getRisAccNo(RisState[2])
	;~ thisChartNo:=getRisChartNo(RisState[2])
	
	;~ if (getRisStudyState(RisState[2])!="已發報告")
		;~ SetTimer,risAccChanged,-100
;~ }

risAccChanged(thisAccNo, thisChartNo, rowNo){
	global preOpened, AccNoCol, ChartNoCol, reportList
	thisHwnd:=openFilm(thisAccNo, thisChartNo)
	activateStudy(thisHwnd)
	;~ thisRow:=reportList.getRow("AccNo", thisAccNo)
	SetTimerF("preshow", -200, [rowNo+1], -1)
	
	nextRow:=reportList[rowNo+preOpened]
	
	SetTimerF("openFilm", -500, [nextRow[AccNoCol], nextRow[ChartNoCol]], -1)
}

activateStudy(thisHwnd){
	global monitors, thisPwbMonitor
	WinShow,% "ahk_id " thisHwnd
	winactivate,% "ahk_id "  thisHwnd
	m:=monitors[thisPwbMonitor+1]
	WinMove, % "ahk_id " thisHwnd,,% m.l, % m.t, % m.w, % m.h
	PostMessage,0x2028,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	moveSimpleRIS(m)
}

;~ #IfWinActive,ahk_group simpleRisGui
`;::
F3::
F2::
F12::
Critical
thisRow:=reportList.getRow(i)
;~ tempRowNo:=thisRow.rowNo
if(A_ThisLabel~="F3|F2|;"){
	if (notMatching){
		MsgBox % "ChartNo not matching !!!"
		return
	}
	
	Text:=ControlGetText(editHwnd:=getSimpleRisEditHwnds()[2])
	if (Trim(Text)="") || (checkReport(Text, thisRow[AccNoCol], thisRow[ChartNoCol], thisRow[ExamNameCol])=-1){
		ShowToolTip("Report text error!", 3000)
		return
	}

}
++i
if (++thisPwbMonitor)=3
	thisPwbMonitor:=1
priorAccNo:=thisRow[AccNoCol]
if preOpened>1
	WinHide,% "ahk_id " pwbHwndPool[priorAccNo]
	;~ pwbPool[priorAccNo].Visible:=false
if (i>reportListLen){
	WinHide,% "ahk_id " pwbHwndPool[priorAccNo]
	;~ pwbPool[priorAccNo].Visible:=false
	MsgBox % "Finished!"
	ExitApp
	return
}
;~ risAccChanged(a:=reportList[i][AccNoCol], b:=reportList[i][ChartNoCol], i)
if !pwbPool.haskey(reportList[i][AccNoCol])
	ReloadAll()

PostMessage,0x2024,,,,simpleRIS__main ahk_class AutoHotkeyGUI
;~ activateStudy(openFilm(a:=reportList[i][AccNoCol], b:=reportList[i][ChartNoCol]))
;~ tempAccNo:=thisAccNo
;~ ,tempChartNo:=thisChartNo
;~ if pwbHwndPool.haskey(tempAccNo)
	;~ WinClose,% "ahk_id " pwbHwndPool[tempAccNo]
return
;~ #IfWinActive

checkReport(text, AccNo, ChartNo, examName){
	global reportDir,offlineMode,editHwnd,title, shownGuiInd, ____, lastReportText
	Exam:=ExamName,thisAccNo:=AccNo,thisChartNo:=ChartNo
	;~ msgbox % superior aspect of	am "," thisAccNo "," thisChartNo
	;~ text:=RegExReplace(text,"\.+",".")
	text:=RegExReplace(text,"\ {2,}(?!(-+ |\d+\W ))"," ")
	,text:=RegExReplace(text,"(?<=[\,\.\;\(])\ {2,}"," ")
	;~ ,text:=RegExReplace(text," {2}"," ")
	,text:=RegExReplace(text,"\.{2,}",".")
	,text:=RegExReplace(text,",{2,}",",")
	,text:=RegExReplace(text,"\.\,",",")
	,text:=RegExReplace(text,"\,\.",".")
	,text:=RegExReplace(text,"\.\/",". ")
	,text:=RegExReplace(text,"\ ([,.;])","$1")
	,text:=RegExReplace(text,"i)([a-z])\. ([a-z])","$1.$2")
	,text:=RegExReplace(text,"([,;])(\w)","$1 $2")
	,text:=RegExReplace(text,".\ {2,}(\r?\n)",". $1")
	,text:=RegExReplace(text,"(^(\r?\n)+)|((\r?\n)+$)","")
	,text:=RegExReplace(text,"at at","at ")
	,text:=RegExReplace(text," *\b[a-zA-Z]\. *"," ")
	,text:=RegExReplace(text," +"," ")
	;~ ,Text:=RegExReplace(Text, "i)\/(placement)", ".$1")
	;~ text:=RegExReplace(text,"(\.)  +(\w)",". $2")
	,newText:=""
	,incomplete:=0
	loop,parse,text,`.
		if regexmatch(a_loopfield,"\w"){
			;~ if strlen(line:=trim(a_loopfield))<5
				;~ incomplete:=1
			newText.=stringupper(substr(trim(a_loopfield),1,1)) substr(trim(a_loopfield),2) ". "
		}else{
			newText.=trim(a_loopfield) ". "
		}
	newText:=substr(newText,1,-2)
	,newText:=RegExReplace(newText,"(\d). (\d)","$1.$2")
	,newText:=RegExReplace(newText,"\. \)",".)")
	,newText:=RegExReplace(newText,"(?<!\n) {2,}"," ")
	,newText:=RegExReplace(newText,"[\.\ ]+$",".")
	
	
	
	
	
	,selStart:=0
	loop,parse,newText,`.
		if strlen(line:=trim(a_loopfield))<5 && regexmatch(line,"^[a-z]+\d*?$") {
			incomplete:=1
			break
		}else{
		selStart+=strlen(a_loopfield)+1
	}
	
	if (incomplete){
		;~ settimer,moveMsgBox,20
		msgbox,4144,,% "Check the report for AHK error!"
		;~ controlsettext,,% newText,ahk_id %editHwnd%
		Edit_SetText(editHwnd, newText)
		,Edit_setsel(editHwnd,seltStart,selStart+strlen(line))
		,Edit_ScrollCaret(editHwnd)
		return -1
	}
		
	filedelete,% filePath:=reportDir "\" __CryptStr(thisAccNo " " thisChartNo, ____) ".txt"
	if instr(newText, "(N/A).") {
		fileappend,% lastReportText:="(N/A).",% filePath,utf-8
		FileSetAttrib,+H,% filePath
	}else{
		fileappend,% __CryptStr(addTitle(lastReportText:=newText,Exam,thisAccNo,thisChartNo) "`r`n-=-=-=-=-`r`n",____),% filePath,utf-8
	}
	tooltip % "Saved !"
	settimer,tooltip,-1000
}	

addTitle(newText,exam="",accNo="",chartNo=""){
	global showAccNo, showChartNo, addNormalHeartSize, fastMode, turboMode
	;~ msgbox % newText "`n`n" exam "`n`n" accNo "`n`n" chartNo
	risState:=RisOpened()
	
	if instr(newText,"EXAMINATION:")
		return newText
	if instr(newText,"shows")
		newText:=RegExReplace(newText,"is)^.+shows\s*","")
		,newText:=stringupper(substr(newText,1,1)) substr(newText,2)
	
	if (!fastMode && !turboMode && addNormalHeartSize && RegExMatch(exam,"is)Chest : (PA|AP) View") && !regexmatch(newText,"i)normal heart size|cardiomegaly|borderline heart size|heart border|opacified (left|right) hemithorax"))
		heartSize:="Normal heart size. "
	else 
		heartSize:=""
	
	exam:=RegExReplace(exam," ?: ?"," - ")
	return  (showChartNo?(chartNo=""?"":"Chart No: " chartNo "`r`n"):"") (showAccNo?(accNo=""?"":"Accession No: " accNo "`r`n"):"") "EXAMINATION: " exam (match1=""?"":" (" match1 ")") ".`r`nFINDINGS:`r`n" heartSize RegExReplace(newText,"(^(\r?\n)+)|((\r?\n)+$)","")
}

tooltip:
tooltip
return

setHotKey:

iniread,showChartNo,% ini,Settings,showChartNo,1
iniread,showAccNo,% ini,Settings,showAccNo,1
iniread,addNormalHeartSize,% ini,Settings,addNormalHeartSize,0
iniread,addReassignDate,% ini,Settings,addReassignDate,0
fastMode:=true
return

^F5::
openThis()
return

openThis(){
	global i, reportList, AccNoCol, ChartNoCol
	thisRow:=reportList.getRow(i)
	thisAccNo:=thisRow[AccNoCol]
	thisChartNo:=thisRow[ChartNoCol]
	thisHwnd:=openFilm(thisAccNo, thisChartNo)
	activateStudy(thisHwnd)
}


checkMatch(){
	global monitors, RisState, pwbHwndPool, reportList, i, AccNoCol, thisPwbMonitor, guihwnds, pwbPool, notMatching
	
	whichMonitor:=thisPwbMonitor+1
	m:=monitors[whichMonitor]
	
	currentPwbHwnd:=GetParentTop(acc_windowFromObject(Acc_ObjectFromPoint("", m.l+m.w//2, m.t+m.h//2)))
	;~ pwb:=WBGet("ahk_id " currentPwbHwnd)
	;~ title:=pwb.document.getElementById("titleBar-text-patientDemographicInfo").title
	
	thisAccNo:=reportList[i][AccNoCol]
	html:=currentPwbHwnd.document.body.innerHTML
	if InStr(html, "系統通訊錯誤")
		;~ ReloadAll()
		;~ Loop % (Buttons:=pwb.document.getElementsByTagName("BUTTON")).length {
			;~ button:=Buttons[A_Index-1]
			;~ if InStr(button.className, "ajs-button") && InStr(button.className, "ajs-ok") && button.innerText="確定" {
				;~ button.Click()
				;~ break
			;~ }
		;~ }
		{
			WinClose, % "ahk_id " pwbHwndPool[thisAccNo]
			pwbHwndPool.delete(thisAccNo)
			pwbPool.delete(thisAccNo)
			openThis()
		}

	
	
	;~ Loop 10 
		;~ if pwbHwndPool[thisAccNo]=(currentPwbHwnd:=DllCall("GetParent", UInt,currentPwbHwnd))
			;~ MsgBox 
	
	
	if pwbHwndPool.haskey(thisAccNo) && WinExist("ahk_id " openedHwnd:=pwbHwndPool[thisAccNo]) {
		if (currentPwbHwnd!=openedHwnd)
			activateStudy(openedHwnd)
	}
	if (GetParentTop(acc_windowFromObject(Acc_ObjectFromPoint("", m.l+m.w//2, m.t+m.h//2)))!=openedHwnd)
		ShowToolTip("Mismatched chart #", 2000), notMatching:=true
	else
		notMatching:=false
	
	WinGetPos,x,y,w,h,% "ahk_id " guihwnds[1]
	if !(x>m.l && x<m.l+m.w)
		moveSimpleRIS(m)
	
}

preshow(rowNo){
	global reportList, monitors, thisPwbMonitor, AccNoCol, ChartNoCol
	
	whichMonitor:=thisPwbMonitor-1
	if whichMonitor=0
		whichMonitor:=monitors.length()
	mon:=monitors[whichMonitor+1]
	
	hwnd:=openFilm(reportList[rowNo][AccNoCol], reportList[rowNo][ChartNoCol])
	if WinExist("ahk_id " hwnd){
		WinMove, % "ahk_id " hwnd,,% mon.l,% mon.t, % mon.w, % mon.h
		WinShow,% "ahk_id " hwnd
		WinMove, % "ahk_id " hwnd,,% mon.l,% mon.t, % mon.w, % mon.h
	}
}

moveSimpleRIS(monitor_pos){
	global guihwnds
	m:=monitor_pos
	,guihwnds:=getSimpleRisGuiHwnds()
	WinGetPos,x,y,w,h,% "ahk_id " guihwnds[1]
	if x>m.l && x<m.l+m.w
		return 
	
	WinMove,% "ahk_id " guihwnds[1],,% Floor(m.l+(m.w-w)/2),% y,% w,% h
	WinMove,% "ahk_id " guihwnds[2],,% Floor(m.l+(m.w-w)/2),% y,% w,% h
}


ReloadAll(){
	global 
	clipboard:=inputClipboard
	Reload
}

^+!r::
ReloadAll()
return

OnExit:
for k,v in pwbHwndPool
	WinClose,% "ahk_id " v
for k,v in pwbPool
	try
		v.quit()
ExitApp