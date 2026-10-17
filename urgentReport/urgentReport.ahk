#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,Off
SetBatchLines, -1
coordMode,mouse,screen
CoordMode,caret,screen
DetectHiddenWindows,on
SetTitleMatchMode,2
SetControlDelay,-1
comobjerror(false)
onexit,onexit

#include <portallib>
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <LVA>
#include <RegExSplit>
#include <CryptFileRead>
#include <ParseArg>
;~ if %0%
	;~ goto mp
if CryptFilePW()
	ExitApp

args:=ParseArg()
,thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))	
for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name = 'urgentReport.exe'")
	if(process.ProcessId!=thisPid && process.ExecutablePath==RegExReplace(A_ScriptFullPath,"i).ahk$",".exe")){
		process,Close,% process.ProcessId
		otherOpened:=true
	}
NoTrayOrphans()		
,askForPortalIdPw()
,OnMessage("0x4E", "LVA_OnNotify")
,OnMessage(0x1001, "selectCTClick")

gosub setFullStatText
gui,+hwndGuihwnd
gui,Font,s12,微軟正黑體
gui,Add,ListView,% "r20 w800 backgroundBlack cwhite AltSubmit vlv gLVClick",% s:="Type|Msg Time|Chart No|Exam Date|Msg|Acc No|Msg Index|Urgency"
colNo:={}
,buttonEventHandler:=new finishCommButtonEventHandler
Loop,Parse,s,|
	colNo[RegExReplace(A_LoopField, " ", "")]:=A_Index
for k,v in [30, 150, 100, 0, 350, 150, 0, 50]
	LV_ModifyCol(k, v)
LV_ModifyCol(colNo.Urgency, "Integer")
gui,add,button,gcheckAll,Check All
;~ gui,add,button,gAddRisList,Add RIS List
gui,Show,% (otherOpened?"NA":""),Urgent Report
for k,v in args
	if winexist("ahk_id " v)
		winactivate,ahk_id %v%
GroupAdd,Self,ahk_id %guihwnd%
gosub loadDeleteMsg
openedIE:=[]
,LVA_ListViewAdd("LV")
gosub routine
SetTimer,routine,% routineFreq()
;~ SetTimer,impaxContextServer,-1
RisActiveInfo:=[]
SetTimer,activeInfoCheck,1000
applyIcon()
settimer,ReloadAll,-1800000
return

ReloadAll:
reload()
return


reload(){
	run % commands(RegExReplace(A_ScriptFullPath,"i).ahk$",".exe"), "/restart", A_IsCompiled?"":RegExReplace(A_ScriptFullPath,"i).exe$",".ahk"), "activate=" winexist("A"))
	settimer,ExitApp,-10000
}

ExitApp:
ExitApp


activeInfoCheck(){
	global RisActiveInfo,colNo, grayRowInfo, LVClicking, checkingRow, RisState
	static grayRow:=[]
	RisActiveInfo[getRisAccNo((RisState:=RisOpened())[2])]:=getRisStudyState(RisState[2])
	
	for activeAccNo, activeStudyState in RisActiveInfo {
		if (activeStudyState="已發報告")
			grayRow[activeAccNo]:=1
		RisActiveInfo.delete(activeAccNo)
	}
	if !(grayRow.SetCapacity(0)>0)
		return
	
	Loop % LV_GetCount() {
		LV_GetText(AccNo, rowInd:=A_Index, colNo.AccNo)
		if (grayRow.haskey(AccNo)){
			if (LVClicking || checkingRow)
				return
			grayRowInfo[AccNo]:=1
			;~ ,setRowColor(rowInd, AccNo)
			,checkRow(rowInd)
			,grayRow.delete(AccNo)
			
			if !(grayRow.SetCapacity(0)>0)
				return
		}
	}
}

selectCTClick(){
	global selectCTClick:=1
}

reportListProgress(k, ByRef rowAcc, ByRef cellsAcc){
	global reportListCount, PacsIEhwnd, startDownload
	tooltip % "Get list from RIS: " k-1 " / " reportListCount-1 " ..."
}

routineFreq(){
	if(A_Hour<6)
		return 3600000
	else
		return 300000
}

#IfWinActive,ahk_group Self
F5::
reload()
;~ gosub routine
;~ SetTimer,routine,% routineFreq()
return
#IfWinActive

routine:
ToolTip % "Loading messages ..."
AllMsg:={}
;~ , LV_Delete()
,sid:=login(loginid, loginpw)
for k,v in portalMsg:=getPortalMessages2(sid)
	if InStr(v.MessageContent, "報告") {
		match:=RegExMatchAll(v.MessageContent, "\b\w{6}\d\b")
		if(match.list.maxIndex()>1){
			for x,y in match.list
				if !deletedMsgList.hasKey(v.MessageSeqNo "_" x)
					AllMsg[v.MessageSeqNo "_" x]:=v.clone()
					,AllMsg[v.MessageSeqNo "_" x, "index"]:=v.MessageSeqNo "_" x
					,AllMsg[v.MessageSeqNo "_" x, "ChartNo"]:=y.0
		}else if (match.list.maxIndex()=1) && !deletedMsgList.hasKey(v.MessageSeqNo)
			RegExMatch(v.MessageContent, "i)(\b[TY]\w{9}\d\b)", aNo)
			,AllMsg[v.MessageSeqNo]:=v
			,AllMsg[v.MessageSeqNo, "ChartNo"]:=match.list.1.0
			,AllMsg[v.MessageSeqNo, "AccNo"]:=aNo1
			,AllMsg[v.MessageSeqNo, "index"]:=v.MessageSeqNo
		else{
			match:=RegExMatchAll(v.MessageContent, "i)\b[TY]\w{9}\d\b")
			if(match.list.maxIndex()>1){
				for x,y in match.list
					if !deletedMsgList.hasKey(v.MessageSeqNo "_" x)
						AllMsg[v.MessageSeqNo "_" x]:=v.clone()
						,AllMsg[v.MessageSeqNo "_" x, "index"]:=v.MessageSeqNo "_" x
						,AllMsg[v.MessageSeqNo "_" x, "AccNo"]:=y.0
			}else if (match.list.maxIndex()=1) && !deletedMsgList.hasKey(v.MessageSeqNo)
				RegExMatch(v.MessageContent, "i)(\b[TY]\w{9}\d\b)", aNo)
				,AllMsg[v.MessageSeqNo]:=v
				;~ ,AllMsg[v.MessageSeqNo, "ChartNo"]:=match.list.1.0
				,AllMsg[v.MessageSeqNo, "AccNo"]:=aNo1
				,AllMsg[v.MessageSeqNo, "index"]:=v.MessageSeqNo
		}
		;~ ,LV_Add("", "催", shortenTime(v.sendTime), cNo1, "", v.MessageContent, aNo1, v.MessageSeqNo, 9)
	}
AllComm:={}
for k,v in msg:=getVSConfirmList(sid)
	if (v.Category = "醫師雙向溝通平台"){
		RegExMatch(v.TargetLink, "i)serialnumber=([^&]{11})", aNo)
		,AllComm[v.RawSequenceNo]:=v
		,AllComm[v.RawSequenceNo, "AccNo"]:=aNo1
		,AllComm[v.RawSequenceNo, "TargetLink"]:=url:=RegExReplace(v.TargetLink, "rhisaw", "ehisaw")
		,matchPwb(aNo1, url, false)
	}
	
rowDelete:=[], ExistedRow:=[]
Loop % LV_GetCount() {
	LV_GetText(ind, A_Index, colNo.MsgIndex)
	;~ ,LV_GetText(t, A_Index, colNo.Msg)
	
	if AllMsg.hasKey(ind) {
		row:=AllMsg[ind]
		,LV_Modify(A_Index, "", "催", (row.SendMessageTime), row.ChartNo, "", row.MessageContent, row.AccNo, row.index, 9)
		,ExistedRow[ind]:=1
	}else if AllComm.hasKey(ind) {
		row:=AllComm[ind]
		,pwb:=matchPwb(row.AccNo, row.TargetLink, true)
		,LV_Modify(A_Index, "", "雙", "", row.ChartNo, "", pwb.document.querySelectorAll("#page-content-wrapper .panel li.list-group-item div")[3].innerText
			, row.AccNo, ind, 10)
		,ExistedRow[ind]:=1
	}else{
		rowDelete.push(A_Index)
	}
}

Loop % (allCount:=rowDelete.maxIndex())
	LV_Delete(rowDelete[allCount-A_Index+1])


AddNew:=false

for k,v in AllMsg 
	if !ExistedRow.hasKey(v.index)
		;~ code:=urgentCode(v.MessageContent, 9)
		LV_Add("", "催", (v.SendMessageTime), v.ChartNo, "", v.MessageContent, v.AccNo, v.index, 9)
		;~ ,LVA_SetCell("LV", rowNo, 1, "", code.2)
		,ExistedRow[v.index]:=1
		,AddNew:=true

for k,v in AllComm
	if !ExistedRow.hasKey(v.RawSequenceNo){
		pwb:=matchPwb(v.AccNo, v.TargetLink)
		,LV_Add("", "雙", "", v.ChartNo, "", pwb.document.querySelectorAll("#page-content-wrapper .panel li.list-group-item div")[3].innerText
			, v.AccNo, v.RawSequenceNo, 10)
		,ExistedRow[v.RawSequenceNo]:=1
		,AddNew:=true
		;~ ,ComObjConnect(pwb.document.getElementById("btnFinishBoardMessage"), "Button_")
	}
	

if(AllMsg.SetCapacity(0) + AllComm.SetCapacity(0) = 0)
	LV_Add("", "", "", "", "", "查無結果")
LV_ModifyCol(colNo.Urgency, "Sort")
repaintLV()
ToolTip
if (AddNew){
	FlashCount:=0
	SetTimer,Flash,-1
}
return


repaintLV(){
	local t,a,code,m,i
	Loop % LV_GetCount() {
		LV_GetText(t, A_Index, colNo.Msg)
		,LV_GetText(a, A_Index, colNo.Type)
		,LV_GetText(m, A_Index, colNo.MsgTime)
		,LV_GetText(i, A_Index, colNo.MsgIndex)
		if(a="催"){
			code:=urgentCode(t, AllMsg[i].SendMessageTime, 9)
			,LV_Modify(A_Index, "Col" colNo.Urgency, code.1)
			,LVA_SetCell("LV", A_Index, 1, "", code.2)
		}else{
			LVA_SetCell("LV", A_Index, 1, "black", "white")
		}
	}
}

Flash:
if(++FlashCount>6)
	return
gui,Flash
SetTimer,Flash,-500
return


urgentCode(txt, MsgTime, Default){
	;~ datefrom := MsgTime
	;~ ,distance := dateto := A_YYYY a_mm a_dd
	;~ ,distance -= datefrom, days
	if(SubStr(RegExReplace(MsgTime, "\D", ""),1,8) = A_YYYY a_mm a_dd)
		distance:=0
	
	
	
	
	if RegExMatch(txt, "(周|週|星期)(一|二|三|四|五|六|日|天)", m) {
		wd:=instr("一二三四五六日", m2)
		wd:=wd?wd:7
		wd:=wd>6?1:wd+1
		FormatTime,WDay,, WDay
		
		d:=wd-wday
		d:=d>=0?d:d+7
		
		if (d=0)
			return instr(txt,"上午")?[1,"red"]:[2,"yellow"]
		else
			return [3, "yellow"]
		
		
	}else if InStr(txt, "後天") {
		d:=SubStr(RegExReplace(MsgTime, "\D", ""),1,14)
		d-=a_now,days
		if d<-2
			return [1, "red"]
		else if (d<-1)
			return instr(txt,"上午")?[1,"red"]:[2,"yellow"]
		else
			return [3, "yellow"]
		
		
	}else if (txt~="明日|明天|明上午|明下午") {
		d:=SubStr(RegExReplace(MsgTime, "\D", ""),1,14)
		d-=a_now,days
		if d<-1
			return [1, "red"]
		else if (d<0)
			return instr(txt,"上午")?[1,"red"]:[2,"yellow"]
		else
			return [3, "yellow"]
		
		
	}else if InStr(txt, "診") {
		if InStr(txt, "明") && distance=0
			return [3, "yellow"]
		else if InStr(txt, "下午") && distance=0
			return [2, "yellow"]
		else 
			return [1, "red"]
	}else if InStr(txt, "申請") || InStr(txt, "病摘") || InStr(txt, "藥物")
		return [4, "green"]
	else if InStr(txt, "病房")
		return [1, "yellow"]
	else if InStr(txt, "急診")
		return [1, "yellow"]
	
	return [Default, "white"]
}


shortenTime(timeStr){ ; yyyy/mm/dd hh:mm
	str:=""
	if !RegExMatch(timeStr, "(\d+)/(\d+)/(\d+) (\d+):(\d+)", match)
		return
	
	datefrom := match1 match2 match3
	,distance := dateto := A_YYYY a_mm a_dd
	,distance -= datefrom, days
	
	if (distance =0 || (datefrom=A_YYYY a_mm a_dd))
		return match4 ":" match5
	else if (distance<4)
		return match2 "/" match3 " " match4 ":" match5
	else if (distance<30)
		return match2 "/" match3
	else
		return match1 "/" match2
		
}


LVClick:
;~ ToolTip % A_GuiEvent
;~ Sleep 500
shiftPressed:=GetKeyState("Shift")
if !A_EventInfo && A_GuiEvent!="ColClick"
	return

LV_GetText(getExamName, A_EventInfo, colNo.ExamName)
,LV_GetText(getType, A_EventInfo, colNo.Type)
,LV_GetText(getIndex, A_EventInfo, colNo.MsgIndex)

if(getExamName="查無結果")
	return
SetTimer,activeInfoCheck,Off
LVClicking:=true
if (A_GuiEvent="DoubleClick" ){
	selectCTClick:=-1
	SetTimer,singleClick,Off
	;~ PostMessage,0x1001,,,,ahk_exe selectCT.exe
	;~ PostMessage,0x1001,,,,ahk_exe selectCT - threading.exe
	;~ PostMessage,0x1001,,,,ahk_exe selectCT - worker.exe
	if (getType="雙"){
		
		LV_GetText(getAccNo, A_EventInfo, colNo.AccNo)
		,LV_GetText(getChartNo, A_EventInfo, colNo.ChartNo)
		,url:=AllComm[getIndex].TargetLink
		,acc:=AllComm[getIndex].AccNo
		,acc:=acc?acc:getAccNo
		,matchPwb(acc, url).quit()
		,(pwb:=matchPwb(acc, url)).Visible:=true
		WinShow,% "ahk_id " pwb.hwnd
		Winactivate,% "ahk_id " pwb.hwnd
		
		searchRisChartNo(targetRis:=selectRis(getChartNo),acc=""?getChartNo:acc, clipboard:=getChartNo)
		winactivate,% "ahk_id " targetRis
		
	}else if (getType="催"){
		LV_GetText(getAccNo, A_EventInfo, colNo.AccNo)
		,LV_GetText(getChartNo, A_EventInfo, colNo.ChartNo)
		if (RisOpened()[1]=2){
			winactivate,% "ahk_id " RisOpened()[2]
			searchRisChartNo(targetRis:=selectRis(getChartNo),getAccNo=""?getChartNo:getAccNo, getChartNo)
			if(getAccNo!="")
				ClickFirstResult(getAccNo)
				, urgentReportClick:=1
			else{
				WinGetTitle,title,% "ahk_id " hwnd:=targetRis
				RegExMatch(title, "[^-\s]+", radName)
				,reportList:=parseDataGrid2(RisListHwnd:=getRisList(hwnd))
				,col1:=reportList.getColNo("status"), col2:=reportList.getColNo("報告醫師")
				,RisListRowsAcc:=acc_children(acc_objectfromwindow(RisListHwnd))
				;~ ,RisListRowsAcc[2].accSelect(ComObj(3,3),0)
				;~ ,RisListRowsAcc[2].accSelect(ComObj(3,16),0)
				controlsend,,^{Home},ahk_id %RisListHwnd%
				found:=0
				for k,v in reportList
					if (v[col1]!="已發報告" && v[col2]=radName){
						if(!found){
							(acc:=RisListRowsAcc[k]).accSelect(ComObj(3,3),0)
							,loc:=acc_location(acc)
							MouseMove,% loc.x+500,% loc.y+10,0
						}else{
							found++
						}
						
					}
				if(found=1){
					mouseclick,left,% loc.x+500,% loc.y+10,2,0
				}
						
			}
		}else{
			clipboard:=getChartNo
			ToolTip % "Chart No copied!"
			settimer,ToolTip,-2000
		}
	}
}else if (A_GuiEvent="RightClick"){
	checkRow(A_EventInfo, getExamName, getType, getIndex)
}else if (A_GuiEvent="Normal"){
	SetTimer,singleClick,-500
	
}else if (A_GuiEvent="ColClick"){
	SetTimerF("repaintLV", -100)
}else{
	ToolTip
}
SetTimer,activeInfoCheck,1000
LVClicking:=false
return


selectRis(ChartNo){
	ret1:=ret2:=0
	for k, v in allRis:=RisOpened(1)[2] {
		WinGetTitle,t,ahk_id %v%
		if(ChartNo~="i)^H" && InStr(t,"HC")) || (ChartNo~="i)^[YNA\d]" && !InStr(t,"HC"))	
			if winvisible(v) {
				ret1:=v
				winactivate,ahk_id %v%
				return ret1
			}else{
				if !ret2
					ret2:=v
			}
	}
	if ret2
		winactivate,ahk_id %ret2%
	return ret2
}

checkRow(rowInd, getExamName="", getType="", getIndex="", all=false){
	global 
	if (checkingRow){
		SetTimerF("checkRow", -1000, [rowInd, getExamName, getType, getIndex])
		return 
	}
		
	
	checkingRow:=true
	
	
	if (getExamName="" || getType="" || getIndex="")
		LV_GetText(getExamName, rowInd, colNo.ExamName)
		,LV_GetText(getType, rowInd, colNo.Type)
		,LV_GetText(getIndex, rowInd, colNo.MsgIndex)

	sid:=renewSid(sid, loginid, loginpw)
	if (getType="催") {
		if RegExMatch(getIndex, "([^_]+)_(\d+)", m) {
			MessageSeqNo:=m1
			,moreChartNo:=false
			Loop % 20 {
				if AllMsg.hasKey(MessageSeqNo "_" A_Index) && (getIndex!=MessageSeqNo "_" A_Index) {
					moreChartNo:=true
					break
				}
			}
			if (moreChartNo){
				;~ FileAppend,% getIndex "`n",% deletedMsgListFile, utf-8
				CryptFileAppend(getIndex, deletedMsgListFile, ____)
				,deletedMsgList[getIndex]:=1
			}
			
			
			if (moreChartNo) || (!moreChartNo && confirmMessage2(AllMsg[getIndex], sid))
				LV_Delete(rowInd)
				,remove:=AllMsg.Delete(getIndex)
				,clipboard:=remove.ChartNo
				,repaintLV()
			
			
		}else if confirmMessage2(AllMsg[getIndex], sid)
			LV_Delete(rowInd)
			,remove:=AllMsg.Delete(getIndex)
			,clipboard:=remove.ChartNo
			,repaintLV()
	}else if (getType="雙"){
		pwb:=matchPwb(acc, url)
		,pwb.document.getElementById("txbCommentPost_ifr").contentDocument.getElementById("tinymce").innerText:="Done!"
		,pwb.document.getElementById("EditBoardCommentInfoData_EventIDSE").parentNode.getElementsByTagName("BUTTON")[0].Click()
		,pwb.Visible:=true
		Loop 
			Sleep 300
		until !pwb.busy
		pwb.document.getElementById("btnFinishBoardMessage").Click()
		;~ ,SetTimerF("quitPwb", -5000, [pwb])
		,LV_Delete(rowInd)
		,remove:=AllComm.Delete(getIndex)
		,clipboard:=remove.ChartNo
		,repaintLV()
	}
	gosub routine
	checkingRow:=false
}

setRowColor(row, AccNo){
	local fg
	
	fg:=grayRowInfo.haskey(AccNo)?"gray":"white"
	
	Loop 8
		LVA_SetCell("LV", row, A_Index, "", fg)	
}


quitPwb(pwb){
	try 
		pwb.quit()
}

matchPwb(AccNo, url, waitLoaded=true){
	global openedIE
	if openedIE.hasKey(AccNo) && WinExist("ahk_id " openedIE[AccNo].hwnd)
			pwb:=openedIE[AccNo]
	else
		pwb:=comobjcreate("InternetExplorer.Application")
		,pwb.Navigate(url)
		,openedIE[AccNo]:=pwb
	
	if(waitLoaded && pwb.busy){
		Loop 
			Sleep 300
		until !pwb.busy
	}
	;~ pwb.Visible:=true
	;~ ToolTip % pwb.hwnd
	return pwb
}

singleClick:
if (getType="催") {
		ToolTip % WrapText(AllMsg[getIndex].MessageContent)
}else if (getType="雙"){
	ToolTip % "Loading..."
	url:=AllComm[getIndex].TargetLink
	,acc:=AllComm[getIndex].AccNo
	if openedIE.hasKey(acc) && WinExist("ahk_id " openedIE[acc].hwnd)
		pwb:=openedIE[acc]
	else {
		pwb:=comobjcreate("InternetExplorer.Application")
		,pwb.Navigate(url)
		,openedIE[acc]:=pwb
		Loop 
			Sleep 500
		until !pwb.busy
	}
	if shiftPressed
		pwb.Visible:=true
	ToolTip % WrapText(pwb.document.querySelectorAll("#page-content-wrapper .panel li.list-group-item div")[3].innerText)
}
SetTimer,ToolTip,-5000
return

mp:


return


checkAll:
;~ checkingRow:=true
Loop % (lvcount:=LV_GetCount())
	checkRow(lvcount+1-A_Index)
;~ checkingRow:=false
reload()
return

tobeChecked:=[]
sid:=renewSid(sid, loginid, loginpw)
,lvcount:=LV_GetCount()
,deletedRows:=[]
Loop % lvcount {
	ind:=lvcount-A_Index+1
	,LV_GetText(getExamName, ind, colNo.ExamName)
	,LV_GetText(getType, ind, colNo.Type)
	,LV_GetText(getIndex, ind, colNo.MsgIndex)
	,tobeChecked.push(getIndex)
	if (getType="催") {
		if RegExMatch(getIndex, "([^_]+)_(\d+)", m) {
			moreChartNo:=false
			Loop % 20 {
				if AllMsg.hasKey(m1 "_" A_Index) && (getIndex!=m1 "_" A_Index) {
					moreChartNo:=true
					break
				}
			}
			if (moreChartNo){
				;~ FileAppend,% getIndex "`n",% deletedMsgListFile, utf-8
				CryptFileAppend(getIndex, deletedMsgListFile, ____)
				,deletedMsgList[getIndex]:=1
			}
			
			
			if (moreChartNo) || (!moreChartNo && confirmMessage(m1, sid))
				;~ LV_Delete(ind)
				deletedRows.push(ind)
				,remove:=AllMsg.Delete(getIndex)
				,clipboard:=remove.ChartNo
				;~ ,repaintLV()
			
			
		}else if confirmMessage(getIndex, sid, portalMsg)
			;~ LV_Delete(ind)
			deletedRows.push(ind)
			,remove:=AllMsg.Delete(getIndex)
			,clipboard:=remove.ChartNo
			;~ ,repaintLV()
	}else if (getType="雙"){
		pwb:=matchPwb(acc, url)
		,pwb.document.getElementById("txbCommentPost_ifr").contentDocument.getElementById("tinymce").innerText:="Done!"
		,pwb.document.getElementById("EditBoardCommentInfoData_EventIDSE").parentNode.getElementsByTagName("BUTTON")[0].Click()
		Loop 
			Sleep 500
		until !pwb.busy
		pwb.document.getElementById("btnFinishBoardMessage").Click()
		,SetTimerF("quitPwb", -5000, [pwb])
		;~ ,LV_Delete(ind)
		,deletedRows.push(ind)
		,remove:=AllComm.Delete(getIndex)
		,clipboard:=remove.ChartNo
		;~ ,repaintLV()
	}
}
for k,v in deletedRows
	LV_Delete(v)
repaintLV()
gosub routine
return

WrapText(str, WrapLen=25){
	s:="", l:=StrLen(str)
	Loop % q:=Floor(l/WrapLen) 
		s.=SubStr(str, WrapLen*(A_Index-1)+1, WrapLen) "`n"
	
	if (l-q*WrapLen<4)
		s:=SubStr(s, 1, -1)
	s.= SubStr(str, WrapLen*q+1) 
	return s
}



ClickFirstResult(AccNo){
	global reportListTitleCol, RisActiveInfo
	WinWaitActive,% "ahk_id " RisOpened()[2],,3
	parseDataGrid(RisListRowsAcc:=acc_children(acc_objectfromwindow(RisListHwnd:=getRisList(RisOpened()[2])))
		,reportListTmp:=[], 1, 2)
	,extractTitleCol(reportListTmp[1], reportListTitleCol:=[])
	if (Trim(reportListTmp[2, reportListTitleCol["照會單號"]])=AccNo){
		loc:=acc_location(RisListRowsAcc[2])
		if (Trim(reportListTmp[2, reportListTitleCol["狀態"]])="已發報告"){
			MouseMove,% loc.x+100,% loc.y+10,2
			RisActiveInfo[AccNo]:="已發報告"
			,activeInfoCheck()
		}else
			mouseclick,l,% loc.x+100,% loc.y+10,2,0
	}
}


extractTitleCol(ByRef reportListFirstRow, ByRef reportListTitleCol){
	for k,v in reportListFirstRow
		reportListTitleCol[v]:=k
}


~LButton:
ToolTip
return

ToolTip:
ToolTip
return

GuiClose:
OnExit:
;~ esc::
for k,v in openedIE
	try
	v.quit()
ExitApp

loadDeleteMsg:
deletedMsgListFile:=A_ScriptDir "\deletedMsg.txt"
;~ fileread,deletedMsgTxt,% deletedMsgListFile

deletedMsgList:=[]
for k,v in CryptFileRead(deletedMsgListFile,____)
;~ Loop,Parse,deletedMsgTxt,`n,`r
	deletedMsgList[v]:=1
return




#IfWinActive,ahk_exe Menu.exe
~*F3::
F3:
if WinExist("ahk_exe selectCT.exe")
	return
if (selectCTClick=1 || !urgentReportClick)
	return
settimer,activate,-500
urgentReportClick:=0
return
#IfWinActive

#IfWinActive,simple RIS ahk_class AutoHotkeyGUI
~*F3::
gosub F3
return
#IfWinActive

activate:
winactivate,ahk_id %guihwnd%
WinGetPos,x,y,w,h,ahk_id %guihwnd%
MouseMove,% x+Floor(w/2),% y+30,0
return


setFullStatText:
return
fullStat=
(
本院放射科主治醫師負責所有院區影像診斷報告，遠超過合理工作量。2018 年 1-6 月共有 484,636 份X光、119,537 份CT、31,655 份MRI由37位主治醫師所負責，平均一位醫師一個月要負責 2,183 份X光、538 份CT、142 份MRI，以放射醫學會目前所共識判讀時間X光2分鐘、CT 20 分鐘、MRI 30 分鐘，每位醫師一週需要 81 小時才能完成。就算放射科醫師超速判讀，加上介入性診斷/治療、會議、行政、教學等事務，仍不可能完成全部報告。N院影像檢查持續增長，未完成報告只會累積越來越多，請見諒。如果您認同放射科需要合理工作量，就像門診掛號需要限號，請分享上述數據周知，讓更多人了解N醫院(而非影像醫學部)所面臨的問題。
)
return