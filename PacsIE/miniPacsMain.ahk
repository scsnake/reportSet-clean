#MaxMem 4095
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
SetBatchLines, -1
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
SetTitleMatchMode,2
SetControlDelay,-1
DetectHiddenWindows,on
ComObjError(false)
#notrayicon
onexit,onexit
#persistent
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <CryptFileRead>
#Include %A_ScriptDir%
#include jpegDirName.ahk

if CryptFilePW()
	ExitApp


gosub changeLibRoot


partialMode:=!!FileExist(A_ScriptDir "\..\portable")
,OnMessage(0x10101, "closeminipacs")
gui,-resize +lastfound +AlwaysOnTop +hwndguihwnd +ToolWindow
gui,font,s12,Verdana
gui,add,button,gopenminiPACS w300,% "Open miniPACS"
gui,add,button,gcloseminiPACS w300,% "Close miniPACS"

gui,add,button,gopengetAllJpeg w300 y+20,% "Open getAllJpeg"
gui,add,button,gclosegetAllJpeg w300,% "Close getAllJpeg"

gui,add,button,gopenfeedRIS w300 y+20,% "Open feedRIS"
gui,add,button,gclosefeedRIS w300,% "Close feedRIS"

gui,Add,button,gselectReported w300 y+20,% "Select reported"
gui,add,button,gselectSearchOpHxResults w300,% "Select searchOpHxResults"
gui,add,button,gselectdownloaded w300,% "Select downloaded"
;~ gui,add,button,gcheckJpeg w300,% "Check jpeg"
;~ gui,add,button,gselectnolaterreport w300,% "Select no later report"

gui,show,autosize x-500 y-500,miniPACS Main
wingetpos,x,y,w,h
winmove,,,% a_screenwidth-w,% Floor((A_ScreenHeight-h)/2),w,h

GroupAdd,self,ahk_id %guihwnd%
SetTimer, routine, 200
return

routine:
IfWinExist,kReport ahk_class #32770,because it is being used by another process.
		WinClose,kReport ahk_class #32770,because it is being used by another process.
return

;~ #IfWinActive,ahk_group self
;~ 1::
;~ 2::
;~ 3::
;~ 4::
;~ HotkeyButtons:=["openminipacs", "closeminipacs", "openfeedris", "closefeedris"]
;~ gosub % HotkeyButtons[A_ThisHotkey+0]
;~ return
;~ #IfWinActive

opengetAllJpeg:
run % A_ScriptDir "\getAllJpeg.exe"
return

closegetAllJpeg:
if !WinExist("ahk_exe getAllJpeg.exe"){
	Loop 500
		process,close,pyPortal.exe
}
process,close,getAllJpeg.exe
notrayorphans()
return

openFeedRIS:
if WinExist("ahk_exe feedRIS.exe"){
	MsgBox, 36, , Reopen feedRIS ?
	IfMsgBox,Yes
		gosub closefeedRIS
}
run % A_ScriptDir "\feedRIS.exe"	
return

closefeedRIS:
PostMessage,0x1012,,,,autoFeed_main ahk_class AutoHotkeyGUI
PostMessage,0x1012,,,,feedRIS_main ahk_class AutoHotkeyGUI
notrayorphans()
return

openminiPACS:
if winexist("ahk_exe miniPACS.exe"){
	MsgBox, 36, , Reopen miniPACS ?
	IfMsgBox,Yes
		gosub closeminiPACS
}
run % A_ScriptDir "\miniPACS_bridge.exe"	
return

closeminipacs(){
	gosub,closeminiPACS
}
closeminiPACS:
GroupAdd,miniPACS,ahk_exe miniPACS.exe
winclose,ahk_group miniPACS
WinClose,miniPACS.exe ahk_class ConsoleWindowClass
PostMessage,0x10101,,,,miniPACS_bridge_main ahk_class AutoHotkeyGUI
;~ PostMessage,0x10201,,,,getAllJpeg_main ahk_class AutoHotkeyGUI
winclose,ahk_exe miniPACS_bridge.exe
;~ WinClose,ahk_exe pyPortal.exe
WinClose,WM_COPYDATA_Listener_miniPACS
PostMessage,0x10101,,,,decryptJpeg_main ahk_class AutoHotkeyGUI
WinClose,ahk_exe decryptJpeg.exe
;~ WinClose,WM_COPYDATA_Listener_portalLib
while 1
{
	Process,Close,pyPortal.exe
	if !ErrorLevel
		break
}
;~ process,close,miniPACS_bridge.exe
notrayorphans()
return

guiclose:
onexit:
gosub closeminiPACS
notrayorphans()
exitapp


changeLibRoot:
if !FileExist(libLnk:=A_ScriptDir "\Lib.lnk")
	return
FileGetShortcut,% libLnk,libTarget
if SubStr(libTarget,1,1)!=SubStr(A_ScriptDir,1,1){
	FileDelete,% libLnk
	FileCreateShortcut,% SubStr(A_ScriptDir,1,1) SubStr(libTarget,2),% libLnk
}
return


preprocessRisList:
RisState:=RisOpened()
,RisHwnd:=RisState[2]

if !WinExist("ahk_id " rishwnd)
	RisHwnd:=RisOpened(1)[2][1]
winactivate,% "ahk_id " RisHwnd
ToolTip % "parsing..."
RisListHwnd:=getRisList(RisHwnd)
,RisListRowsAcc:=acc_children(acc_objectfromwindow(RisListHwnd))
,reportList:=[]
Loop 3 {
	reportList:=parseDataGrid2(RisListHwnd,"",RisListRowsAcc, 20)
}until reportList.length()>1

ToolTip
if !(reportList.length()>1){
	MsgBox % "Can't get report list!"
	return 
}

statusCol:=reportList.getColNo("status")
,ChartNoCol:=reportList.getColNo("ChartNo")
,AccNoCol:=reportList.getColNo("AccNo")
,ExamDateCol:=reportList.getColNo("ExamDate")
,ExamNameCol:=reportList.getColNo("ExamName")
,reportvsCol:=reportList.getColNo("ReportVS")

return


selectReported:
if processingRisList
	return

processingRisList:=true
gosub preprocessRisList
if !(reportList.length()>1){
	processingRisList:=false
	return 
}

FocusFirst:=""
,feedRISList:=[]
total=0
Loop,files,% A_MyDocuments "\feedRIS\*.txt"
	feedRISList.push(A_LoopFileLongPath)

if feedRISList.length()*2>reportList.data.length() {
	reportDir:=A_MyDocuments "\feedRIS\" 
	for k,row in reportList.data {
		accNo:=row[AccNoCol]
		,reportVS:=row[reportvsCol]
		,chartNo:=row[ChartNoCol]
			
		if !InStr(row[reportvsCol], "陳醫師") && FileExist(feedRisTxt:=reportDir __CryptStr(AccNo " " ChartNo,____) ".txt") {
			FileGetAttrib,attr,% feedRisTxt
			if InStr(attr, "H")
				continue 
			fileread,f,% feedRisTxt
			
			if InStr(f, "(N/A)") || (!InStr(f, "Chart") && InStr(__CryptStr(f,____, 0), "(N/A)")){
				FileSetAttrib,+H,% feedRisTxt
				continue
				
			}
			
			if !FocusFirst
				(FocusFirst:=RisListRowsAcc[k]).accSelect(ComObj(3,3),0)
			RisListRowsAcc[k].accSelect(ComObj(3,8),0), total++
		
			
	
			
		}
	
	}
	
}else{
	
	for k, feedRisTxt in feedRISList {
		FileGetAttrib,attr,% feedRisTxt
		if InStr(attr, "H")
			continue 
		fileread,f,% feedRisTxt
		
		if InStr(f, "(N/A)") || (!InStr(f, "Chart") && InStr(__CryptStr(f,____, 0), "(N/A)")){
			FileSetAttrib,+H,% feedRisTxt
			continue
			
		}
			
		SplitPath,feedRisTxt,LoopFileName
		if(LoopFileName~="i)[TYH]\w{10} \w{7}.txt")
			accNo:=SubStr(LoopFileName,1,11)
		else {
			SplitPath,LoopFileName,,,,crypt_accno_chartNo
			accNo:=SubStr(__CryptStr(crypt_accno_chartNo,____, 0),1,11)
		}
		
		for k,row in reportList.data {
			if(accNo==row[AccNoCol] && !InStr(row[reportvsCol], "陳醫師")){
				if !FocusFirst
					(FocusFirst:=RisListRowsAcc[k]).accSelect(ComObj(3,3),0)
				RisListRowsAcc[k].accSelect(ComObj(3,8),0), total++
				break
			}
		}
		;~ currentRow:=reportList.getRow("AccNo", accNo)
		;~ if (currentRow.rowNo) && !InStr(currentRow.getCell("ReportVS"), "陳醫師")
			;~ RisListRowsAcc[currentRow.rowNo].accSelect(ComObj(3,FirstSelect?8:8),0), FirstSelect:=false
	}
	
	

}
FocusFirst.accSelect(ComObj(3,1),0)	
,showtooltip("Done!`nTotal: " total,10000)
,RisListRowsAcc:=reportList:=""
,processingRisList:=false
, emptyMem()
return


selectSearchOpHxResults:
if processingRisList
	return

processingRisList:=true

,searchOpHxPath:=partialMode?A_ScriptDir "\..\searchOpHxResults.txt":SubStr(A_ScriptDir,1,2) "\scripts\autorun\searchOpHxResults.txt"
;~ fileread,searchOpHxData,% searchOpHxPath
,searchOpHxData:=CryptFileRead(searchOpHxPath, ____, true)
if !FileExist(searchOpHxPath) || !searchOpHxData
{
	processingRisList:=false
	return
}
	
gosub preprocessRisList
if !(reportList.length()>1){
	processingRisList:=false
	return 
}

FocusFirst=
total=0
for k,v in reportList 
	if InStr(searchOpHxData, v[AccNoCol]){
		if !FocusFirst
			(FocusFirst:=RisListRowsAcc[k]).accSelect(ComObj(3,3),0)
		RisListRowsAcc[k].accSelect(ComObj(3,8),0), total++
	}
		
FocusFirst.accSelect(ComObj(3,1),0)	
,showtooltip("Done!`nTotal: " total,10000)
,RisListRowsAcc:=reportList:=""
,processingRisList:=false
, emptyMem()
return

selectdownloaded:
if processingRisList
	return

processingRisList:=true
gosub preprocessRisList
if !(reportList.length()>1){
	processingRisList:=false
	return 
}

reportDir:=A_MyDocuments "\feedRIS"
FocusFirst=
total=0
for k,v in reportList {
	accNo:=v.getCell("AccNo")
	,chartNo:=v.getCell("chartNo")
	if FileExistValid(jpegDirName(reportDir, AccNo , ChartNo,AccNo , ChartNo)){
		if !FocusFirst
			(FocusFirst:=RisListRowsAcc[k]).accSelect(ComObj(3,3),0)
		RisListRowsAcc[k].accSelect(ComObj(3,8),0), total++
	}
		
}
FocusFirst.accSelect(ComObj(3,1),0)	
,showtooltip("Done!`nTotal: " total,10000)
,RisListRowsAcc:=reportList:=""
,processingRisList:=false
, emptyMem()
return




selectnolaterreport:
if processingRisList
	return

processingRisList:=true

,noLaterReportPath:=partialMode?A_ScriptDir "\..\noLaterReport.txt":SubStr(A_ScriptDir,1,2) "\scripts\autorun\noLaterReport.txt"
;~ fileread,noLaterReportData,% noLaterReportPath
,noLaterReportData:=CryptFileRead(noLaterReportPath, ____, true)
if !FileExist(noLaterReportPath) || !noLaterReportData
{
	processingRisList:=false
	return
}
	
gosub preprocessRisList
if !(reportList.length()>1){
	processingRisList:=false
	return 
}

FocusFirst=
total=0
for k,v in reportList 
	if InStr(noLaterReportData, v[AccNoCol]){
		if !FocusFirst
			(FocusFirst:=RisListRowsAcc[k]).accSelect(ComObj(3,3),0)
		RisListRowsAcc[k].accSelect(ComObj(3,8),0), total++
	}

FocusFirst.accSelect(ComObj(3,1),0)	
,showtooltip("Done!`nTotal: " total,10000)
,RisListRowsAcc:=reportList:=""
,processingRisList:=false
, emptyMem()
return

checkJpeg:
if fileexist("testJpeg.exe")
	run testJpeg.exe
else
	msgbox % "testJpeg.exe not found!"
return