#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
SetBatchLines, -1
coordMode,mouse,screen
CoordMode,caret,screen
DetectHiddenWindows,on
SetTitleMatchMode,2
SetControlDelay,-1
comobjerror(false)
onexit,onexit
#NoTrayIcon

#include <Acc>
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <risimpax>
#include <winvisible>
#include <Class_CTLCOLORS>
#include <Class_RichEdit>
#include <prettyReport>

gosub gui
SetTimer,routine
gosub simpleRisNoUpdate
SetTimer,simpleRisNoUpdate,5000

return


gui:
gui,+hwndguiHwnd 
gui,Color,black
gui,Font,s14 cwhite,Verdana

editHwndArr:=[]
gui,Add,Edit,% "hwndeditAccNo w200",
editHwndArr.push(EditAccNo)

gui,Add,Edit,% "hwndeditChartNo w150 yp x+20",
editHwndArr.push(editChartNo)

gui,Add,Edit,% "hwndeditDate w220 yp x+20",
editHwndArr.push(editDate)

gui,Add,Edit,% "hwndeditPatient w160 yp x+20",
editHwndArr.push(editPatient)

gui,Add,Edit,% "hwndeditStatus w120 yp x+20",
editHwndArr.push(editStatus)

gui,Add,Edit,% "hwndeditOrderFrom w200 yp x+20",
editHwndArr.push(editOrderFrom)

gui,Font,s12 cwhite,Verdana
RE_hx:=new RichEdit("1","y+20 xs w" A_ScreenWidth-30 " h500")
,RE_hx.WordWrap(1)
,RE_hx.ShowScrollBar(0,false)
,RE_hx.SetBkgndColor("Black")
,RE_hx.SetDefaultFont({"Name": "Verdana", "Size": 14, "Color": "White"})
,RE_hx.SetParaSpacing({"After": 2})

gui,Font,s14 cwhite,Verdana
gui,Add,Edit,% "hwndeditExams w400 y+20 xs h200 section",
editHwndArr.push(editExams)

gui,Add,ListView,% "hwndLVOldExams w400 y+20 h600 gLVclick AltSubmit BackgroundBlack cWhite", % "Date|VS|Exam"
LV_ModifyCol(1, 100)
LV_ModifyCol(2, 100)

RE_Exam:=new RichEdit("1","w750 x+20 ys h600")
,RE_Exam.WordWrap(1)
,RE_Exam.ShowScrollBar(0,false)
,RE_Exam.SetBkgndColor("Black")
,RE_Exam.SetDefaultFont({"Name": "Verdana", "Size": 14, "Color": "White"})
,RE_Exam.SetParaSpacing({"After": 2})

RE_Imp:=new RichEdit("1","w750 xp y+20 h200")
,RE_Imp.WordWrap(1)
,RE_Imp.ShowScrollBar(0,false)
,RE_Imp.SetBkgndColor("Black")
,RE_Imp.SetDefaultFont({"Name": "Verdana", "Size": 14, "Color": "White"})
,RE_Imp.SetParaSpacing({"After": 2})

gui,Add,Button,% "x700 y+20 gactionButton w100",% "上筆"
gui,Add,Button,% "x+20 yp gactionButton w100",% "下筆"
gui,Add,Button,% "x+20 yp gactionButton w100",% "暫存"
gui,Add,Button,% "x+20 yp gactionButton w100",% "發送"

for k,editHwnd in editHwndArr
	CtlColors.Change(editHwnd, "000000", "FFFFFF")

SysGet,workArea,MonitorWorkArea ,1
gui,Show,% "x0 y0 w" A_ScreenWidth-5 " h" (workAreaBottom-workAreaTop-20),mirror RIS
return

ColorRichEdit:
guicontrol,-Redraw,% RE_exam.hwnd
guicontrol,-Redraw,% RE_Imp.hwnd
colorRadReport(RE_exam,1,1,0)
colorRadReport(RE_Imp,1,1,0)
guicontrol,+Redraw,% RE_exam.hwnd
guicontrol,+Redraw,% RE_Imp.hwnd
return

actionButton:

return


update:


ControlSetText(EditAccNo, cAccNo)
ControlSetText(editChartNo, getRisChartNo(RisState[2]))

ControlSetText(editDate, ControlGetText(getNetControl2(RisState[2],"","EXAM_DATE_TIME","","WindowsForms10.EDIT")[1]))

ptName:=ControlGetText(getNetControl2(RisState[2],"","FID_TEXT","姓名","WindowsForms10.EDIT")[1])
ptGender:=ControlGetText(getNetControl2(RisState[2],"","FID_TEXT","性別","WindowsForms10.EDIT")[1])
ptAge:=ControlGetText(getNetControl2(RisState[2],"","FID_TEXT","年齡","WindowsForms10.EDIT")[1])
ControlSetText(editPatient, ptName " " ptAge " " ptGender)

ControlSetText(editStatus, ControlGetText(getNetControl2(RisState[2],"","FID_TEXT","狀態","WindowsForms10.EDIT")[1]))

ptType:=ControlGetText(getNetControl2(RisState[2],"","FID_TEXT","診別","WindowsForms10.EDIT")[1])
ptWard:=ControlGetText(getNetControl2(RisState[2],"","FID_TEXT","病房","WindowsForms10.EDIT")[1])
ptDept:=ControlGetText(getNetControl2(RisState[2],"","FID_TEXT","開單科別","WindowsForms10.EDIT")[1])
orderDr:=ControlGetText(getNetControl2(RisState[2],"","FID_TEXT","開單醫師姓名","WindowsForms10.EDIT")[1])
ControlSetText(editOrderFrom, (ptType="O"?"OPD":ptType="E"?"ER":ptWard) " " ptDept " " orderDr)

guicontrol,-Redraw,% RE_hx.hwnd
RE_hx.SetText(txt:=ControlGetText(getNetControl2(RisState[2],"","txtALL","","WindowsForms10.EDIT")[1]))
,RE_hx.setSel(0,strlen(txt))
,RE_hx.SetFont({"Name": "Verdana", "Size": 12, "Color": "White"})
,RE_hx.setSel(-1,-1)
guicontrol,+Redraw,% RE_hx.hwnd

exam:=""
for k,v in parseRisExamItems(getRisExamItems(RisState[2]))[2]
	exam.=trim(v) "`n"
ControlSetText(editExams, SubStr(exam, 1, -1))

SetTimer,loadRadHx,-1
SetTimer,ReloadOldRad,-1
return

LVclick:
if(A_GuiEvent="Normal"){
	RadHxAcc[A_EventInfo+1].accSelect(ComObj(3,3),0)
	Sleep 200
	SetTimer,ReloadOldRad,-1
}
return

ReloadOldRad:
guicontrol,-Redraw,% RE_exam.hwnd
RE_exam.SetText(txt:=ControlGetText(getNetControl2(RisState[2],"","HISTORY_EXAM_TEXT","","WindowsForms10.EDIT")[1]))
,RE_exam.setSel(0,strlen(txt))
,RE_exam.SetFont({"Name": "Verdana", "Size": 12, "Color": "White"})
,RE_exam.setSel(-1,-1)
guicontrol,+Redraw,% RE_exam.hwnd

guicontrol,-Redraw,% RE_Imp.hwnd
RE_Imp.SetText(txt:=ControlGetText(getNetControl2(RisState[2],"","HISTORY_IMPRESSION_TEXT","","WindowsForms10.EDIT")[1]))
,RE_Imp.setSel(0,strlen(txt))
,RE_Imp.SetFont({"Name": "Verdana", "Size": 12, "Color": "White"})
,RE_Imp.setSel(-1,-1)
guicontrol,+Redraw,% RE_Imp.hwnd

SetTimer,ColorRichEdit,-1
return


loadRadHx:
if !RadHxHwnd:=getNetAcc(RisState[2], "dgHisReport", "WindowsForms10.Window", 0, 0)
	return


th.terminate()
RadHx:=CriticalObject()
RadHxAcc:=acc_children(acc_objectfromwindow(RadHxHwnd))
RadHxTotal:=0
th:=ahkmini("
(
#persistent
#notrayicon
#include <ACC>
#include <RisImpax>
RadHx:=CriticalObject(" (&RadHx) ")
Alias(RadHxTotal," getvar(RadHxTotal) ")
RadHxAcc:=acc_objectfromwindow(" RadHxHwnd ")
parseDataGrid(acc_children(RadHxAcc),RadHx,1)
RadHxTotal:=RadHx.maxIndex()
exitapp
)")

RadHxLoadingInd:=1
Loop {
	if RadHxTotal && RadHxLoadingInd>RadHxTotal
		break
	
	if !IsObject(newRow:=RadHx[RadHxLoadingInd]){
		Sleep 500
		continue
	}
	
	if(RadHxLoadingInd=1){
		for m,n in newRow {
			if (n="報告醫師"){
				examVSCol:=m
			}else if (n="檢查日"){
				examDateCol:=m
			}else if (n="檢查名稱"){
				examNameCol:=m
			}
		
		}
		
	}else{
		LV_Add("", TrimDate(newRow[examDateCol]), (vs:=newRow[examVSCol])?vs:" ", trimExamName(newRow[examNameCol]))
	}
	++RadHxLoadingInd
}
LV_Modify(1,"+Select")
return

TrimDate(date){
	return RegExReplace(date, "^" A_Year "\/", "")
}
trimExamName(examName){
	if RegExMatch(examName, "i)(CT|MRI) (With)?\/?(Without)? Contrast\-([\w ]+)", match)
		return match1 " " (match2&&match3?"±":match1?"+":"-") (InStr(match4,"neck")?"Neck":match4)
	else if RegExMatch(examName, "i)Chest : (PA|AP) View", match)
		return "CXR" (match1="AP"?" (AP)":"")
	else if (examName="Abdomen:KUB")
		return "KUB"
	else
		return examName
}
routine:
if !((RisState:=RisOpened()) && (RisHwnd:=RisState[2])){
	return
}
if !((controlexist(AccNoHwnd) || (AccNoHwnd:=getRisAccNoHwnd(RisHwnd))) && (cAccNo:=ControlGetText(AccNoHwnd))){
	return
}
if (pAccNo=cAccNo){
	return
}

gosub update


routineEnd:
pAccNo:=cAccNo
return

ControlSetText(hwnd, Text){
	ControlSetText,,% Text,ahk_id %hwnd%
}

simpleRisNoUpdate:
sendmessage,0x2022,,1,,simple RIS ahk_class AutoHotkeyGUI
return

GuiClose:
;~ esc::
#q::
OnExit:
th.terminate()
ExitApp
return