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
#InstallKeybdHook
;~ #NoTrayIcon
comobjerror(false)
onexit,onexit

#include <ProcessList>
#include <CryptFileRead>
#include <portallib>
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <JXON>
#include <WM_COPYDATA>
#include <LVA>
#include <HtmlLib>
;~ #include <class_sqlitedb>
;~ #include <indexOf>
OnMessage(0x4a, "ON_WM_COPYDATA")
,OnMessage("0x4E", "LVA_OnNotify")
,OnMessage(0x10102, "reportSent")
;~ #include <JoinScript>
;~ #include <ExploreObj>
;~ fileread,____,% A_ScriptDir "\____"
if CryptFilePW()
	ExitApp
;~ MsgBox % ____
;~ root:=SubStr(A_ScriptDir ,1,1)
;~ FileDelete,% root ":\scripts\Radiology\urgentReport\datatable2.html"
;~ FileAppend,% JoinHtml(root ":\scripts\Radiology\urgentReport\datatable.html"),% root ":\scripts\Radiology\urgentReport\datatable2.html",utf-8-Raw
;~ ExitApp
Loop,% A_ScriptDir "\__dcm4cheOutput*",1,0
	if InStr(A_LoopFileLongPath, "D")
		FileRemoveDir,% A_LoopFileLongPath,1
	
abbrFull:=["i)with\/without contrast-chest", "i)with contrast-chest", "i)without contrast-chest", "i)low dose (lung|chest)"]
,abbrs:=["∓C", "+C", "-C", "LDCT"]
	
	
RisActiveInfo:=[]
SetTimer,activeInfoCheck,1000
settimer,activeInfo,2000
;~ #include <LVA>
gosub Main
applyIcon()
settimer,sethotkey,3000
return


sethotkey:
Hotkey,IfWinActive,ahk_exe Menu.exe
Hotkey,~*F3,reportSent,on
Hotkey,IfWinActive,simple RIS ahk_class AutoHotkeyGUI
Hotkey,~*F3,reportSent,on
Hotkey,IfWinActive
return
;~ a::
;~ gosub clickNextTest
;~ return

activeInfoCheck(){
	global RisActiveInfo,colNo, grayRowInfo, wb, lastFinishedAccNo, priorRow, started
	
	if !started
		return
	
	grayRow:=[]
	for activeAccNo, activeStudyState in RisActiveInfo {
		if (activeStudyState="已發報告"){
			grayRow[lastFinishedAccNo:=activeAccNo]:=1
			,openNext()
		}
		RisActiveInfo.delete(activeAccNo)
	}
	if !(grayRow.SetCapacity(0)>0)
		return
	
	toBeDel:=[]
	for k,v in grayRow {
		;~ grayRowInfo[k]:=1
		setRowColor(k)
		,toBeDel.push[k]
	}
	for k,v in toBeDel
		grayRow.delete(v)
	
	;~ Loop % (rows:=wb.document.getElementsByTagName("TR")).length {
		;~ row:=rows[A_Index-1]
		;~ ,AccNo:=row.cells[colNo.AccNo].innerText
		;~ if (grayRow.haskey(AccNo)){
			;~ grayRowInfo[AccNo]:=1
			;~ ,setRowColor(row, AccNo)
			;~ ,grayRow.delete(AccNo)
			
			;~ if !(grayRow.SetCapacity(0)>0)
				;~ return
		;~ }
	;~ }
	return
}

On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
; dwData = Command
; cbData = String lenght
; lpData = String
	global ThreadCount
	dwData := NumGet(lParam+0, 0)
	,cbData := NumGet(lParam + A_PtrSize)
	,lpData := NumGet(lParam + 2*A_PtrSize)
	,str:= StrGet(lpData)
	
	;~ str:=lpData
	
	If  (dwData = 0x17) {
		
		try 
			info:=jxon_load(str)
		catch
			return
		
		;~ if info.fail
			;~ --ThreadCount
		;~ else{
			SendMessage,0x8001,,,,% "ahk_id " info.hwnd
			newSearchThread_onFinish(info)
			
			
		;~ }
	}
}

WM_KEYDOWN(wParam, lParam, nMsg, hWnd)
{
   global wb
   static fields := "hWnd,nMsg,wParam,lParam,A_EventInfo,A_GuiX,A_GuiY"
   WinGetClass, ClassName, ahk_id %hWnd%
   if  (ClassName = "Internet Explorer_Server")
   {
   ;// Get the in place interface pointer
      pipa := ComObjQuery(wb.document, "{00000117-0000-0000-C000-000000000046}")
   ;// Build MSG Structure
      VarSetCapacity(Msg, 48)
      Loop Parse, fields, `,             ;`
         NumPut(%A_LoopField%, Msg, (A_Index-1)*A_PtrSize)
   ;// Call Translate Accelerator Method
      TranslateAccelerator := NumGet(NumGet(1*pipa)+5*A_PtrSize)
      Loop 2 ;// only necessary for Shell.Explorer Object
         r := DllCall(TranslateAccelerator, "Ptr",pipa, "Ptr",&Msg)
      until wParam != 9 || wb.document.activeElement != ""
   ;// Release the in place interface pointer
      ObjRelease(pipa)
		
      if r = 0 ;// S_OK: the message was translated to an accelerator.
         return 0
   }
}
embedIE:
	;// Create a gui	
   Gui, +LastFound -Resize +OwnDialogs +hwndGuihwnd
   
   ;// create an instance of Internet Explorer_Server
   ;// store the iwebbrowser2 interface pointer as *WB* & the hwnd as *ATLWinHWND*
   Gui, Add, ActiveX,% "w" A_ScreenWidth-20  " h600 x0 y0 vWB hwndATLWinHWND", Shell.Explorer
   
   ;// disable annoying script errors from the page
   ;~ WB.silent := true
   
   ;// necesary to accept enter and accelorator keys
   ;http://msdn.microsoft.com/en-us/library/microsoft.visualstudio.ole.interop.ioleinplaceactiveobject(VS.80).aspx
   ,IOleInPlaceActiveObject_Interface:="{00000117-0000-0000-C000-000000000046}"
   
   ;// necesary to accept enter and accelorator keys
   ;// get the in place interface pointer
   ,pipa := ComObjQuery(WB, IOleInPlaceActiveObject_Interface)
   
   ;// necesary to accept enter and accelorator keys
   ;// capture key messages
   ,OnMessage(WM_KEYDOWN:=0x0100, "WM_KEYDOWN")
   ,OnMessage(WM_KEYUP:=0x0101, "WM_KEYDOWN")
   
   ;//Display the GUI
   gui,add,Checkbox,vAutoOpen,Auto Open Next
	gui,Show,% "w" A_ScreenWidth-10,Select CT

   
return


main:
;~ FileDelete,rislistinfo.txt
askForPortalIdPw()
RisListQue:=[]
,RisListNewResult:=[]
,OnMessage(0x1001, "urgentReportClick")
;~ ,test:=20
;~ ,OnMessage("0x4E", "LVA_OnNotify")
gosub pointsDef
gosub loadHx
SetTimer,refreshAll,-1000

gosub embedIE
gui,Font,s12,微軟正黑體
url:="file:///" RegExReplace(A_ScriptDir "\datatable2.html", "\\", "/")
;~ url:="file:///D:\Users\raduser\Downloads\Table_Fixed_Header\index2.html"
,WB.Navigate(url)
loop
	sleep 10
until !WB.busy
colNames:="Type|Chart No|Exam Date|Exam Name|Acc No|OPD Date|Clinician|Pay|Points|Mets|Op"
,colWidth:=[30, 80, 150, 100, 130, 130, 80, 30, 80, 60, 60]
,cols:=[], colNo:=[]
,updateJs:="dt=$('#dataTable').DataTable({ 'scrollY': '500px', 'paging': false, 'order': [], 'fixedHeader': true, 'lengthChange': false, 'info':false,'destroy':true});"
,js:="javascript:$('table thead tr').append("
Loop,parse,colNames,|
{
	cols.push(A_LoopField)
	,colNo[RegExReplace(A_LoopField, " ", "")]:=A_Index-1
	,js.="'<th width=""" colWidth[A_Index]-3 "px"">" A_LoopField "</th>',"
	
}
js:=SubStr(js,1,-1) ");"
;~ Sleep 500
;~ MsgBox % wb.document.getElementById("dataTable").outerHTML
js2=
(LTrim Join`s
dt=$('#dataTable').DataTable({
			"destroy": true,
			"scrollY": "500px", 
			"paging": false, 
			"order": [], 
			"fixedHeader": true, 
			"info": false, 
			"scrollX": false,
			"lengthChange": false,
			"columnDefs": [
				{"className": "dt-center", "targets": "_all"},
				{"orderSequence": ['desc','asc'], "targets": "_all"}, 
				{"type": "natural-ci", "targets": "_all"}
			  ]
		});
setSearchDelay(2000);
document.oncontextmenu=function(){return false;};void 0;
)
wb.Navigate(js js2)
loop
	sleep 10
until !WB.busy

doc := wb.document
,ComObjConnect(doc, "Doc_")
,grayRowInfo:=[]
,needRefresh:={}
GroupAdd,Self,ahk_id %guihwnd%
;~ gosub debug
gosub routine 
;~ settimer,debug,-3000
return 


debug:
dt_modifyCell(0, 7, 8)
,dt_modifyCell(0, 8, 8)
,dt_modifyCell(0, 9, 8)
return


urgentReportClick(){
	global urgentReportClick:=1
}


#IfWinActive,ahk_group Self
F5::
MsgBox, 260, ,Reload?
IfMsgBox,Yes
	gosub routine
;~ SetTimer,routine,300000
return
#IfWinActive

strAbbr(str, patternArr, abbrArr){
	for k,v in patternArr
		if RegExMatch(str, v) 
			return abbrArr[k]
	return str
}


addRisList:
;~ ReportList:=[]
;~ ,reportListCount:=parseDataGrid(RisListRowsAcc:=acc_children(acc_objectfromwindow(RisListHwnd:=getRisList(RisOpened()[2]))),reportList, 1, 1)
;~ ,parseDataGrid(RisListRowsAcc,reportList, 1, test?10:"", "", "", "reportListProgress")
RisHwnd:=RisOpened()[2]
winactivate,% "ahk_id " RisHwnd
WinWaitActive,% "ahk_id " RisHwnd,,3
WinGetTitle,RisTitle,% "ahk_id " RisHwnd
if RegExMatch(RisTitle, "^([^-]+)-放射線資訊管理系統", match)
	thisVS:=RegExReplace(match1, "[\w\s]", "")
ToolTip % "Loading RIS list ..."
reportListCount:=(reportListAccChildren:=acc_children(reportListAcc:=acc_objectfromwindow(RisListHwnd:=getRisList(RisHwnd)))).maxindex()
Loop 3 {
	reportList:=parseDataGrid2(RisListHwnd,"",reportListAccChildren, "", GetKeyState("shift"))
	
	if !reportList.data.length()
		continue
	
	extractTitleCol(reportList[1], reportListTitleCol:=[])
	,dataTableList:=[]
	for k,v in reportList {
		;~ if k=11 || Mod(k,100)=0
			;~ dt_draw(false)
		reportListProgress(k, "", "", v)
	}	
	break
}

if !reportList.data.length()
	MsgBox % "Can't copy RIS list!"
else
	dt_add_clipboard(collectAllChartNos.length()=0)
	,started:=true
;~ dt_draw(false)
ToolTip 
return


reportListProgress(k, ByRef rowAcc, ByRef cellsAcc, ByRef rowValue){
	local haskey
	;~ tooltip % "Get list from RIS: " k-1 " / " reportListCount-1 " ..."
	
	if(k=1){
		priorKey:=k
		return
	}
		
	ToolTip % "Loading RIS List: #" (k-1)
	if !((ChartNo:=rowValue[reportListTitleCol["病歷號"]])~="\w{6}\d") 
			|| !(((ExamName:=Trim(rowValue[reportListTitleCol["檢查名稱"]]))~="i)^CT|low dose lung|coronary|calcium") && !(examName~="i)guide|request|offer"))
			|| (Trim(rowValue[reportListTitleCol["狀態"]])="已發報告")
			|| studyTooOld(ExamDate:=rowValue[reportListTitleCol["檢查日"]] )
			|| (thisVS!="" && !InStr(rowValue[reportListTitleCol["報告醫師"]], thisVS))
		return
	
	
	if RisListInfo.haskey(AccNo:=rowValue[reportListTitleCol["照會單號"]]){
		data:=RisListInfo[AccNo]
	}else{
		data:=[]
		;~ if (toBeSearch.haskey("" ChartNo)
			;~ toBeSearch["" ChartNo]:=[AccNo]
		;~ else
			;~ toBeSearch["" ChartNo].push(AccNo)
		,collect(ChartNo, ExamDate:=SubStr(RegExReplace(ExamDate, "\D", ""),1,8), AccNo)
	}
	
	

	;~ row:=dt_add(""
	dataTableList.push([strAbbr(rowValue[reportListTitleCol["診別"]], ["門診", "住院", "急診"], ["門", "住", "急"])
		, Trim(rowValue[reportListTitleCol["病歷號"]])
		, (Trim(rowValue[reportListTitleCol["檢查日"]]))
		, abr:=RegExReplace(trimExamName(data.ldct?"LDCT":strAbbr(ExamName:=rowValue[reportListTitleCol["檢查名稱"]], abbrFull, abbrs)), "^CT\s+", "")
		, Trim(AccNo)
		;~ , StrLen(t:=RegExReplace(SubStr(Trim(rowValue[reportListTitleCol["回診日期"]]), 1, 10), "-", "/"))>9?t:""
		, data.OpdDate?dateConv(data.OpdDate):(StrLen(t:=RegExReplace(SubStr(Trim(rowValue[reportListTitleCol["回診日期"]]), 1, 10), "-", "/"))>9?t:"")
		, OpdDr:=Trim(rowValue[reportListTitleCol["開單醫師"]])
		, (Pay:=trim(rowValue[reportListTitleCol["保險別"]]))="自費" || data.ldct || (examName~="i)自費|self\W?paid)") ? "自" : "健"
		, point:=getPoints(examName, InStr(Pay, "自費") || data.ldct || (examName~="i)自費|self\W?paid)"), InStr(Pay, "自費") || data.ldct || (examName~="i)自費|self\W?paid)") ? 1 : data.parts)
		, data.mets
		, data.Op
		, data.Stable])
		
	
	
		

}
;~ esc::ExitApp
collect(ChartNo, ExamDate, AccNo){
	global collectAll, collectAllChartNos
	if !collectAll.haskey(ChartNo:=trim(ChartNo))
		collectAll[ChartNo]:={}
	if !collectAll[ChartNo].haskey(d:=RegExReplace(ExamDate, "\D", ""))
		collectAll[ChartNo, d]:=[]
	collectAll[ChartNo, d].push(trim(AccNo))
	,collectAllChartNos.push(ChartNo)
}

studyTooOld(d){
	d:=SubStr(RegExReplace(d, "\D", ""),1,8)
	,n:=SubStr(A_Now,1,8)
	n-=d, Days
	return n>240
}

setRowColor(AccNo){
	global WB,grayRowInfo
	
	js:="javascript:grayRow('" AccNo "', 1);void 0;"
	WB.Navigate(js)
	;~ grayRowInfo.delete(AccNo)
	;~ ToolTip % js
	Loop
		sleep 10
	until !WB.busy
	
	
	;~ if grayRowInfo.haskey(AccNo) {
		;~ row.classList.add("grayText")
	;~ }else{
		;~ row.classList.remove("grayText")
	;~ }
}


routine:
if routineRunOnce
	Reload
;~ SetTimer,searching,Off
SetTimer,RisListRefresh,Off
;~ LVA_EraseAllCells("LV")
toBeSearch:=[], collectAll:=[], collectAllChartNos:=[], searching:=[]
SetFormat,FloatFast,0.1
gosub addRisList
;~ for k, v in reportList {
	
;~ }
;~ LV_ModifyCol(colNo.Urgency, "Sort")
toBeSearchInd:=1
;~ SetTimerF("searching", -1)
;~ search(searchInd)
if (collectAllChartNos.maxindex()>0) {
	;~ renewSid(sid, loginId, loginPw)
	sid:=login(loginId, loginPw)
	,RisListNewResult:=[]
	SetTimer,search,-1
	SetTimer,RisListRefresh,-1000
}
ToolTip
routineRunOnce:=true
return

test:
	MsgBox
return

search:
	;~ global reportList, reportListTitleCol, sid, RisListInfo, pointsArr, hxFile, colNo, stop, errorInds, searchingTh, ThreadCount
	;~ for k,v in reportList {
	;~ ToolTip % ThreadCount
	
	
	if(collectAll.SetCapacity(0)=0){
		settimer,,Off
		return
	}
	
	searchChartNo:=collectAllChartNos[toBeSearchInd]
	
	if (!searchChartNo) || searching[searchChartNo] {
		if(++toBeSearchInd<=collectAllChartNos.length()){
			SetTimer,search,-300
		}else{
			toBeSearchInd:=1
			settimer,search,-300
		}
		return
	}
	searching[searchChartNo]:=true
	
	;~ row:=reportList[searchInd]
		;~ if ((ChartNo:=row[reportListTitleCol["病歷號"]])~="\w{6}\d") 
			;~ && ((ExamName:=Trim(row[reportListTitleCol["檢查名稱"]]), "CT")~="is)CT.+with.*contrast|low dose (lung|chest)"){
			
		
		;~ Pay:=row[reportListTitleCol["保險別"]]
		;~ , ExamDate:=SubStr(RegExReplace(row[reportListTitleCol["檢查日"]], "\D", ""), 1, 8)
		;~ if(RisListInfo.haskey(AccNo:=row[reportListTitleCol["照會單號"]])){
			;~ SetFormat, FloatFast, 0.1
			;~ data:=RisListInfo[AccNo]
			;~ LV_Edit(colNo.AccNo, AccNo, colNo.Points
					;~ , pointsArr[ExamName]*(InStr(Pay, "自費")?1.3:1)/data.parts/10*0.2)
			;~ ,LV_Edit(colNo.AccNo, AccNo, colNo.Mets, data.mets)
			;~ ,LV_Edit(colNo.AccNo, AccNo, colNo.Op, data.Op)
			
		;~ }else{
			;~ RisListQue[AccNo]:=k
			if(ProcessCount(a_scriptdir "\selectCT_Query.exe")>20){
				settimer,search,% -200-(ProcessCount(a_scriptdir "\selectCT_Query.exe")*100)
				return
			}else{
				;~ ++ThreadCount
				rowData:=[]
				for __ExamDate, __AccNos in collectAll[searchChartNo]
					for k, __AccNo in __AccNos {
						rowData[__AccNo]:=row:=reportList.getRow("AccNo", __AccNo).data
						,SetTimerF("dt_modifyCell",-1,[row[reportListTitleCol["照會單號"]]
							,colNo.points, "."
							, colNo.mets,"."
							, colNo.Stable,"."
							, colNo.op,"."])
					}
						
				info:={"rowData": rowData, "hwnd": guihwnd, "ChartNo": searchChartNo, "Date_AccNo": collectAll[searchChartNo]}
				for k,v in ["SearchInd", "reportListTitleCol", "sid"]
					info[v]:=%v%
				
				run,% """" A_ScriptDir "\selectCT_Query.exe"" """ A_ScriptDir "\selectCT_Query.ahk"" """ RegExReplace(jxon_dump(info), """", """""") """"
				
						;~ newSearchThread(searchInd)
			}
		;~ }
	
	;~ }
	

				if(++toBeSearchInd<=collectAllChartNos.maxindex()){
					SetTimer,search,% -200-(ProcessCount(a_scriptdir "\selectCT_Query.exe")*100)
						;~ SetTimerF("search", -500, [searchInd+1])
				}else{
					toBeSearchInd:=1
					settimer,search,% -2000
				}
	;~ }
return

newSearchThread_onFinish(result){
	global ThreadCount, RisListInfo, colNo, hxFile, pointsArr, grayRowInfo,needRefresh, toBeSearch, collectAllChartNos, collectAll
	;~ global ThreadCount, RisListNewResult
	Critical
	;~ --ThreadCount
	
	for AccNo, res in result {
		if !(AccNo~="i)[TY]\w{10}")
			continue
	
		for k,v in ["AccNo", "searchInd", "parts", "ExamName", "mets", "op", "pay", "ldct", "opdDate", "examDate", "Stable", "ChartNo"]
			%v%:=res[v]
		
		;~ RisListNewResult[result[1]]:=[result[2], result[3], result[4], result[5], result[6]]
		;~ return
		;~ AccNo:=result[1]
		if (AccNo="")
			continue
		;~ v:=[]
		;~ Loop % result.maxindex()-1
			;~ v.push(result[A_Index+1])
		;~ tmp:=[]
		;~ ,tmp[colNo.Points]:=v[3]
		;~ ,tmp[colNo.mets]:=v[4]
		;~ ,tmp[colNo.Op]:=v[5]
		;~ ,LV_Edit(colNo.AccNo, AccNo, tmp)
		RisListInfo[AccNo]:={ldct: ldct, parts: parts, mets: mets, op: op, OpdDate: OpdDate, Stable: Stable
			, points: getPoints(examName, InStr(Pay, "自費") || ldct || (examName~="i)自費|self\W?paid)"),  InStr(Pay, "自費") || ldct || (examName~="i)自費|self\W?paid)")? 1 :parts)}
		,needRefresh[AccNo]:= AccNo "," parts "," mets "," op "," ldct "," ExamDate  "," OpdDate "," Stable
		
		
	}
	for k,v in collectAllChartNos {
		if (v=ChartNo){
			collectAllChartNos.delete(k)
			collectAll.delete(ChartNo)
			break
		}
	}
	
}

refreshAll(){
	global colNo, RisListInfo, needRefresh, hxFile, no_wrt, wb, ThreadCount, dt_modifying, ____, started
	Critical
	
	if !started
		return
	
	;~ ToolTip % ThreadCount "`n" exploreobj(needRefresh)
	
	if !needRefresh.SetCapacity(0) {
		SetTimer,refreshAll,-1000
		return
	}
	;~ WB.Navigate("javascript:var __rows=$('table tbody tr');void 0;")
	/*
	Loop % (rows:=wb.document.getElementById("dataTable").rows).length {
		table_row:=rows[A_Index-1]
		,cells:=table_row.cells
		
		if A_Index=1
			continue
		
		if no_wrt
			return
		AccNo:=cells[colNo.AccNo].innerText
		,mets:=cells[colNo.mets].innerText
		if ((mets!="") || !RisListInfo.haskey(AccNo))
			continue
		
		;~ MsgBox % exploreobj(RisListInfo[AccNo])
		row:=RisListInfo[AccNo]
		,dt_modifyCell(a_index-2,colNo.points, row.points)
		,dt_modifyCell(a_index-2,colNo.mets,row.mets)
		,dt_modifyCell(a_index-2,colNo.Stable,row.Stable)
		,dt_modifyCell(a_index-2,colNo.op,row.op)
		,dt_modifyCell(a_index-2,colNo.OpdDate,dateConv(row.OpdDate))
		if needRefresh.haskey(AccNo){
			if no_wrt
				return
			FileAppend,% needRefresh[AccNo],% hxFile,utf-8
			needRefresh.delete(AccNo)
		}
	}
	*/
	;~ toBeDel:=[]
	for AccNo, txtLine in needRefresh {
		if no_wrt
			return
		;~ if A_Index!=2
			;~ continue
		if (A_Index==2){
			quickRefresh:=true
			break
		}
		row:=RisListInfo[AccNo]
		;~ ,SetTimerF("dt_modifyCell",-1,[AccNo
			;~ ,colNo.points, row.points
			;~ , colNo.mets,row.mets
			;~ , colNo.Stable,row.Stable
			;~ , colNo.op,row.op])
		,dt_modifyCell(AccNo
			,colNo.points, row.points
			, colNo.mets,row.mets
			, colNo.Stable,row.Stable
			, colNo.op,row.op)
			;~ ,colNo.OpdDate, dateConv(row.OpdDate))
		;~ FileAppend,% Crypt.Encrypt.StrEncrypt(txtLine,____,7,6) "`r`n",% hxFile,utf-8
		,CryptFileAppend(txtLine,hxFile,____)
		,needRefresh.delete(AccNo)
	}
	
	;~ dt_draw(false)
	SetTimer,refreshAll,% quickRefresh?-1:WinExist("ahk_exe selectCT_Query.exe")?-1000:-10000
}



dateConv(str, del="/"){
	if str=
		return ""
	return SubStr(str,1,4) del SubStr(str,5,2) del SubStr(str,7,2)
}

newSearchThread(WT, searchInd, RisListInfo, reportList, reportListTitleCol, sid, pointsArr, colNo){

<searching:

Loop 3 {
		row:=reportList[searchInd]
		,ChartNo:=row[reportListTitleCol["病歷號"]]
		, AccNo:=row[reportListTitleCol["照會單號"]]
		, Pay:=row[reportListTitleCol["保險別"]]
		, ExamName:=Trim(row[reportListTitleCol["檢查名稱"]])
		, ExamDate:=SubStr(RegExReplace(row[reportListTitleCol["檢查日"]], "\D", ""), 1, 8)

				;~ ToolTip % "Loading PACS history: " ChartNo
				;~ 6______
				PacsCTHx:=patientBasicInfoWebTree(patientBasicInfoWeb(chartNo, sid)).getNodeByNames("置頂","報告","影核醫報告").arr
				, parts:=0
				for k,v in PacsCTHx {
					RegExMatch(v.innerText,"is)^([\d\/]{10})\_(.+)", match)
					,match1:=RegExReplace(match1, "\D", "")
					
					if (ExamDate=match1 && match2~="^CT") || ((ExamName~="i)low dose (lung|chest)") && (match2~="i)low dose (lung|chest)"))
						parts++
					else if (ExamDate>match1)
						break
				}
				;~ MsgBox % parts
				if(parts!=0){
					;~ clipboard:=ChartNo
					;~ MsgBox % "error"
					;~ if stop
						;~ ExitApp
					;~ else 
						;~ SetTimer,<searching,-100
					;~ Pacs2YrHx:=parseRisReport2Yr(RisReport2Yr(sid, chartNo))
					Pacs2YrHx:=(RisReport2Yr(sid, chartNo))
					if(Pacs2YrHx~="i)(bone|lung|pulmonary) +metastas")
						mets:=true
					if(Pacs2YrHx~="i)operative|post[- ]?op|lobectomy|(wedge +resection)|segmentectomy|pneumonectomy")
						op:=true
					 
					;~ RisListNewResult[AccNo]:=[searchInd, parts, pointsArr[ExamName]*(InStr(Pay, "自費")&&!(ExamName~="i)low dose (lung|chest)")?1.3:1)/parts/10*0.2, !!mets, !!op]
					return [AccNo, searchInd, parts, pointsArr[ExamName]*(InStr(Pay, "自費")&&!(ExamName~="i)low dose (lung|chest)")?1.3:1)/parts/10*0.2, !!mets, !!op]
					
					
					break
				}
				;~ MsgBox % ExploreObj(ahkSelf)
				;~ ahkSelf.Func("searching_onData", jxon_dump([parts, AccNo, pointsArr[ExamName]*(InStr(Pay, "自費")?1.3:1)/parts/10*0.2]))
				;~ ahkSelf.sub("test")
				;~ RisListInfo[AccNo]:=parts
				;~ ,LV_Edit(colNo.AccNo, AccNo, colNo.Points
					;~ , pointsArr[ExamName]*(InStr(Pay, "自費")?1.3:1)/parts/10*0.2)
				;~ FileAppend,% AccNo "," parts "`n",% hxFile,utf-8
				;~ ToolTip
				;~ Pacs2YrHx:=parseRisReport2Yr(RisReport2Yr(sid, chartNo))

		;~ if !(++searchInd > reportList.maxindex()) || (stop)
			;~ ExitApp
		;~ else
			;~ SetTimer,<searching,-100
			ToolTip
		}
return 
searching>:
return

}


; not used
RisListRefresh(){
	global RisListNewResult, colNo, RisListInfo, hxFile, started
	if !started
		return
	
	
	SetFormat,FloatFast,0.1
	
	;~ ToolTip % clipboard:=ExploreObj(RisListNewResult)
	
	if(RisListNewResult.SetCapacity(0)=0){
		SetTimer,RisListRefresh,-1000
		return
	}
	
	toBeDel:=[]
	for AccNo, v in RisListNewResult {
		if AccNo=
			continue
		ToolTip % "Set value for AccNo: " AccNo
		,tmp:=[]
		,tmp[colNo.Points]:=v[3]
		,tmp[colNo.mets]:=v[4]
		,tmp[colNo.Op]:=v[5]
		,tmp[colNo.OpdDate]:=dateConv(v[7])
		,tmp[colNo.Stable]:=v[8]
		,LV_Edit(colNo.AccNo, AccNo, tmp)
		,toBeDel.push(AccNo)
		,RisListInfo[AccNo]:={parts: v[2], mets: v[4], op: v[5], ldct: v[6], OpdDate: v[7], Stable: v[8]}
		;~ FileAppend,% AccNo "," v[2] "," v[4] "," v[5] "," v[6] "," v[7] "," v[8]  "`n",% hxFile,utf-8
		,CryptFileAppend(AccNo "," v[2] "," v[4] "," v[5] "," v[6] "," v[7] "," v[8], hxFile, ____)
	}
	ToolTip 
	for k,v in toBeDel
		RisListNewResult.delete(v)
	
	SetTimer,RisListRefresh,-500
}

LV_Edit(matchCol, matchValue, ColValPair){ ;EditCol, EditValue){
	local v, x, y, dr
	static lastInd:=0
	Critical
	
	SetFormat,FloatFast,0.1	
	if matchValue=
		return
	Loop % LV_GetCount()-lastInd+1 {
		LV_GetText(v, A_Index + lastInd -1, matchCol)
		
		if(v=matchValue){
			lastInd:=A_Index + lastInd -1
			for x,y in ColValPair
				LV_Modify(lastInd, "Col" x, y)
			return lastInd
		}
	}
	Loop % lastInd-1 {
		LV_GetText(v, A_Index, matchCol)
		if(v=matchValue){
			lastInd:=A_Index + lastInd -1
			for x,y in ColValPair
				LV_Modify(lastInd, "Col" x, y)
			return lastInd
		}
	
	}
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


RowEvent(src_row, eventName){
	global cols, colNo, RisActiveInfo, RisState, priorRow, lastDBClickx,lastDBClickY, RisListAcc, RisListAccChildren, reportList
	for k,v in colNo
		%k%:=Trim(src_row.cells[v].innerText)
	cells:=src_row.cells
	
	if InStr(eventName, "DblClick"){
		gosub setnottop
		SetTimerF("singleClick", 0)
		urgentReportClick:=-1
		;~ PostMessage,0x1001,,,,ahk_exe urgentReport.exe
		
		if (RisState[1]=2){
			MouseGetPos,lastDBClickx,lastDBClickY
			winactivate,% "ahk_id " RisState[2]
			thisAccNo:=AccNo, thisChartNo:=chartNo
			
			if getRisAccNo(RisState[2])!=thisAccNo
				if rowNo:=(matchRow:=reportList.getRow("AccNo", thisAccNo)).rowNo
					doubleClickRisList(rowNo, RisListAcc, RisListAccChildren, RisState[2], true)
				else
					searchRisChartNo(RisState[2],AccNo=""?chartNo:AccNo, chartNo)

			if(AccNo!=""){
				GuiControlGet,AutoOpen,,AutoOpen
				if (autoopen && ics_hwnd:=WinExist("ahk_exe ImpaxContextServer.exe" )){
					ImpaxContextServer_Add(AccNo, true, ics_hwnd)
					,ImpaxContextServer_Show(AccNo, ics_hwnd)
				}
				SelectCTClick:=1
				,ClickFirstResult(AccNo)
			}
				
				
		}else{
			clipboard:=ChartNo
			ToolTip % "Chart No copied!"
			settimer,ToolTip,-2000
		}
	}else if InStr(eventName, "ContextMenu"){
		
	}else if InStr(eventName, "Click"){
		dt_row_select(AccNo)
		,SetTimerF("singleClick",-400,[src_row])
	}
	priorRow:=src_row
	;~ Sleep 3000
	;~ gosub autoopennext
}



LVClick:
;~ ToolTip % A_GuiEvent
;~ Sleep 500
EventInfo:=A_EventInfo
, guievent:=A_GuiEvent
LVClick1:
if !EventInfo 
	return

LV_GetText(getAccNo, EventInfo, colNo.AccNo)
,LV_GetText(getChartNo, EventInfo, colNo.ChartNo)
,priorRow:=EventInfo
,RisActiveInfo[getRisAccNo((RisState:=RisOpened())[2])]:=getRisStudyState(RisState[2])
;~ ,lastDBClickx:=lastDBClickY:=-1
if (guiEvent="DoubleClick" ){
	gosub setnottop
	SetTimer,singleClick,Off
	urgentReportClick:=-1
	;~ PostMessage,0x1001,,,,ahk_exe urgentReport.exe
	if (RisOpened()[1]=2){
		MouseGetPos,lastDBClickx,lastDBClickY
		winactivate,% "ahk_id " RisOpened()[2]
		thisAccNo:=getAccNo, thisChartNo:=getChartNo
		
		if rowNo:=(matchRow:=reportList.getRow("AccNo", thisAccNo)).rowNo
			doubleClickRisList(rowNo, RisListAcc, RisListAccChildren, RisState[2], true)
		else
			searchRisChartNo(RisOpened()[2],getAccNo=""?getChartNo:getAccNo, getChartNo)
		
		if EventInfo
			thisRow:=EventInfo
		;~ FileAppend,% EventInfo "," guiEvent "," A_EventInfo "," A_GuiEvent "," thisRow "," getAccNo "," getChartNo "`n", test.log,utf-8
		;~ ToolTip % thisRow
		if(getAccNo!=""){
			GuiControlGet,AutoOpen,,AutoOpen
			if (autoopen && ics_hwnd:=WinExist("ahk_exe ImpaxContextServer.exe" )){
				ImpaxContextServer_Add(getAccNo, true, ics_hwnd)
				,ImpaxContextServer_Show(getAccNo, ics_hwnd)
			}
			SelectCTClick:=1
			,ClickFirstResult(getAccNo)
		}
			
			
	}else{
		clipboard:=getChartNo
		ToolTip % "Chart No copied!"
		settimer,ToolTip,-2000
	}
	
}else if (guiEvent="RightClick"){
	
}else if (guiEvent="Normal"){
	SetTimer,singleClick,-500
}else if (guiEvent="ColClick"){
	SetTimer,RedrawColor,-500
}else{
	ToolTip
}
return

RedrawColor(){
	global wb
	js=javascript:$('table tbody tr').removeClass('grayText');void 0;
	wb.Navigate(js)
}

quitPwb(pwb){
	try 
		pwb.quit()
}



ClickFirstResult(AccNo){
	global reportListTitleCol
	WinWaitActive,% "ahk_id " RisOpened()[2],,3
	parseDataGrid(RisListRowsAcc:=acc_children(acc_objectfromwindow(RisListHwnd:=getRisList(RisOpened()[2])))
		,reportListTmp:=[], 1, 2)
	if (Trim(reportListTmp[2, reportListTitleCol["照會單號"]])=AccNo){
		loc:=acc_location(RisListRowsAcc[2])
		mouseclick,l,% loc.x+100,% loc.y+10,2,0
	}
}

singleClick(row){
	global colNo
	ToolTip % row.cells[colNo.ExamName].innerText
	SetTimer, ToolTip, -2000
	
}

activeInfo:
if !started
	return
RisActiveInfo[lastAccNo:=getRisAccNo((RisState:=RisOpened())[2])]:=getRisStudyState(RisState[2])
return

singleClick:
ToolTip % priorRow.cells[colNo.ExamName].innerText
gosub activeInfo
SetTimer, ToolTip, -2000
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

~LButton:
ToolTip
return

ToolTip:
ToolTip
return

GuiClose:
gui,Destroy
OnExit:
ObjRelease(pipa)
;~ ExitApp
no_wrt:=true
;~ esc::
searchingTh.terminate()
while WinExist("ahk_exe selectCT_Query.exe")
	WinClose,ahk_exe selectCT_Query.exe
for k,v in openedIE
	try
	v.quit()
;~ FileGetSize,filesize,% RisListInfoPath:=A_ScriptDir "\RisListInfo.txt",k
;~ if (filesize>100){
	;~ ToolTip % "Clean up RisListInfo.txt"
	;~ str1:=str2:=""
	;~ fileread,RisInfoTxt,% RisListInfoPath
	;~ Loop,parse,RisInfoTxt,`n,`r
	;~ {
		;~ str2.=A_LoopField "`n"
		;~ if(A_Index=3000)
			;~ str1:=str2, str2:=""
	;~ }
	;~ FileDelete,% RisListInfoPath
	;~ FileAppend,% str2,% RisListInfoPath,utf-8
	;~ FileAppend,% str1,% A_ScriptDir "\RisListInfo_" a_now,utf-8
;~ }
for AccNo, lineText in needRefresh
	;~ FileAppend,% lineText,% hxFile,utf-8
	CryptFileAppend(lineText, hxFile, ____)
Loop,% A_ScriptDir "\__dcm4cheOutput*",1,0
	if InStr(A_LoopFileLongPath, "D")
		FileRemoveDir,% A_LoopFileLongPath,1
ExitApp


extractTitleCol(ByRef reportListFirstRow, ByRef reportListTitleCol){
	for k,v in reportListFirstRow
		if Trim(v)!=""
			reportListTitleCol[v]:=k
}


pointsDef:
if FileExist(pointsDefPath:=A_ScriptDir "\OrderCodes_T0.txt"){
	fileread,pointsDef,% pointsDefPath
	pointsArr:=[]
	Loop,parse,pointsDef,`n,`r
	{
		pointsRow:=[]
		Loop,parse,A_LoopField,`t
			pointsRow.push(trim(A_LoopField))
		pointsArr[pointsRow[2]]:=pointsRow
	}
	
}


;~ pointsArr:={"CT With/Without Contrast-Chest": 5035
	;~ , "CT With Contrast-Chest": 4560
	;~ , "CT Without Contrast-Chest": 3800 
	;~ , "Low dose lung cancer screening CT": 6000 
	;~ , "Low dose lung cancer screening CT for employee(N hospital)": 6000 
	;~ , "CT Without Contrast for low dose lung cancer screening": 6000 }

return


getPoints(examName, SelfCash=false, parts=1, HospitalCode="T0"){
	global pointsArr
	static hospitalRatio:={"T0": 0.1}
	examName:=trim(examName)
	if (pointsArr.haskey(examName)){
		row:=pointsArr[examName]
	}else{
		examName1:=RegExReplace(RegExReplace(examName, "i)自費|self\W?paid)|\W", " "), " +", " ")
		for k,v in pointsArr {
			if(RegExReplace(RegExReplace(k, "i)自費|self\W?paid)|\W", " "), " +", " ") == examName1){
				row:=v
				break
			}
		}
		
		if !row
		{
			examName2:=RegExReplace(RegExReplace(examName, "\W", " "), " +", " ")
			for k,v in pointsArr {
				if(RegExReplace(RegExReplace(k, "\W", " "), " +", " ") == examName2){
					row:=v
					break
				}
			}
		}
		
	}
	doctorRatio:=row[5]?RegExReplace(row[5], "\%", "")/100:0
	,price1:=row[3]
	,price2:=row[4]
	
	if (examName~="i)自費|self\W?paid)")
		SelfCash:=true
	
	if SelfCash
		price:=price2?price2:price1*1.3
	else
		price:=price1?price1:price2
	
	parts:=SelfCash?1:parts
	,ret:=price/parts * HospitalRatio[HospitalCode] * doctorRatio
	return ret=""?"":ret=0?0:Format("{:0.1f}", ret)
}

loadHx:
hxFile:=A_ScriptDir "\RisListInfo.txt"
fileread,RisListInfoTxt,% hxFile
RisListInfo:=[]
,cleaned:=""
,i:=0
,keepLines:=""
Loop,parse,RisListInfoTxt,`n,`r
	if RegExMatch(Crypt.Encrypt.StrDecrypt(A_LoopField, ____, 7,6), "i)([TY]\w{9}\d),(\d+),(\d),(\d),(\d),(\d+),([^,]*)(?:,(\d))?", match)
		|| RegExMatch(Crypt.Encrypt.StrDecrypt(A_LoopField, Hashed?Hashed:(Hashed:=Crypt.Hash.StrHash(____,6)), 7,6), "i)([TY]\w{9}\d),(\d+),(\d),(\d),(\d),(\d+),([^,]*)(?:,(\d))?", match) {
			if (match2!="" && match3!="" && match4!="" && match5!="") && (match6!="" && !studyTooOld(match6)){
				RisListInfo[match1]:={parts: match2, mets: match3, op: match4, ldct: match5, ExamDate: match6, Stable: match8, OpdDate: match7}
				,keepLines.=A_LoopField "`r`n"
			}
			i++
			;~ Sleep 2
		}
		
FileAppend,% keepLines,% hxFile ".new",utf-8			
FileDelete,% hxFile
FileMove,% hxFile ".new", % hxFile

return

reportSent(){
	gosub reportSent
}
;~ ~*F3::
reportSent:
RisActiveInfo[lastAccNo]:="已發報告"
SetTimer,activateCheck,-1
return


openNext(){
	gosub AutoOpenNext
}

AutoOpenNext:
GuiControlGet,AutoOpenNext,,AutoOpen
if (!AutoOpenNext ){
	;~ gosub activate
	return
}
SetTimer,clickNext,-100
return

clickNext:
if (priorRow.parentNode.lastChild.innerHTML==priorRow.innerHTML) || !InStr(priorRow.innerText, lastFinishedAccNo)
	return
clickNextTest:
lastFinishedChartNo:=trim(priorRow.cells[1].innerText)
, lastFinishedExamDate:=trim(priorRow.cells[2].innerText)
, lastChildHTML:=priorRow.parentNode.lastChild.innerHTML
Loop {
	WB.Navigate("javascript: selectNextRow();void 0;")
	Loop
		Sleep 10
	until !WB.busy
	priorRow:=priorRow.nextSibling
	,cn:=priorRow.className
	
	if (lastChildHTML==priorRow.innerHTML ){
		return
	}
	
	if (lastFinishedChartNo==trim(priorRow.cells[1].innerText) && lastFinishedExamDate==trim(priorRow.cells[2].innerText)){
		;~ grayRow[trim(priorRow.cells[4].innerText)]:=1
		;~ ,priorRow.className:="grayText"
		continue
	}
	
	if !(priorRow.className~="\s*grayText\s*")
		break
	
}

;~ ToolTip % priorRow.innerText
Loop
	sleep 10
until !WB.busy
RowEvent(priorRow, "OnDblClick")
return 
guiEvent:="DoubleClick"
,EventInfo:=NextRow:=thisRow+1
gosub LVClick1

LV_Modify(thisRow, "Select")
,LV_Modify(thisRow, "focus")
,LV_Modify(thisRow-1, "-Select")
,LV_Modify(thisRow-1, "-focus")
SetTimer,setNextRow,-500
return
setNextRow:
thisRow:=NextRow
return

activateCheck:
RisActiveInfo[getRisAccNo((RisState:=RisOpened())[2])]:=getRisStudyState(RisState[2])
winget,ProcessName,ProcessName,A
activeWin:=WinExist("A")
;~ ToolTip % ProcessName
;~ if((ProcessName~="Menu.exe|simpleRIS.exe") && SelectCTClick){
if((ProcessName~="Menu.exe|simpleRIS.exe") || (WinGetTitle(activeWin)~="i)^simple RIS" && WinGetClass(activeWin)="AutoHotkeyGUI")){
	SelectCTClick:=0
	GuiControlGet,AutoOpenNext,,AutoOpen
	if (AutoOpenNext ){
		SetTimer,autoopennext,-1
	}else{
		gosub activate
	}
	
}
return

;~ #IfWinActive,ahk_exe Menu.exe
;~ ~*F3::
;~ F3:
;~ if (urgentReportClick=1 || !SelectCTClick)
	;~ return
;~ settimer,activate,-500
;~ SelectCTClick:=0
;~ return
;~ #IfWinActive

;~ #IfWinActive,simple RIS ahk_class AutoHotkeyGUI
;~ ~*F3::
;~ gosub F3
;~ return
;~ #IfWinActive


activate:
winset,AlwaysOnTop,on,ahk_id %guihwnd%
settimer,setnottop,-3000
settimer,setAbbrWinOnTop,400
winactivate,ahk_id %guihwnd%

;~ WinGetPos,x,y,w,h,ahk_id %guihwnd%
;~ MouseMove,% x+Floor(w/2),% y+30,0
;~ ToolTip % lastDBClickx "," lastDBClickY
if (lastDBClickx>0 && lastDBClickY>0){
	MouseMove,% lastDBClickx, % lastDBClickY+30,0
	__lastDBx:=lastDBClickx
	,__lastDBy:=lastDBClickY
	,__lastDBtick:=A_TickCount
	settimer,monitorMouseMove,50
	;~ FileAppend,% lastDBClickx "," lastDBClickY "`r`n",temp.txt,utf-8
	;~ lastDBClickx:=lastDBClickY:=-1
}
return

monitorMouseMove:
if (A_TickCount-__lastDBtick>3000)
	goto monitorMouseMoveStop

MouseGetPos,__lastDBx1,__lastDBy1
;~ ToolTip % __lastDBy1-__lastDBy
if (Abs(__lastDBy1-__lastDBy)>200){
	MouseMove,% lastDBClickx, % lastDBClickY+30,0
	goto monitorMouseMoveStop
}
return
monitorMouseMoveStop:
settimer,monitorMouseMove,Off
lastDBClickx:=lastDBClickY:=-1
return


setAbbrWinOnTop:

if abbrWin:=winexist("What do you mean ahk_class #32770") {
	settimer,setAbbrWinOnTop,Off
	settimer,setnottop,Off
	
	winset,alwaysontop,on,ahk_id %abbrWin%
	winactivate,ahk_id %abbrWin%
	winset,AlwaysOnTop,Off,ahk_id %guihwnd%
	winset,alwaysontop,off,ahk_id %abbrWin%
	
}

return

setnottop:
settimer,setAbbrWinOnTop,off
winset,AlwaysOnTop,off,ahk_id %guihwnd%
return

dt_draw(sort=true){
	global WB
	js="javascript:setTimeout(""dt.draw(" (sort?"true":"false") ");"",0);void 0;"
	wb.Navigate(js)
	loop
	 sleep 10
	until !WB.busy
}

dt_add_clipboard(DefaultSort=false){
	global WB,dataTableList
	str:=""
	for k,v in dataTableList {
		for x,y in v
			str.=y "`t"
		str.="`n"
	}
	
	oldClipboard:=ClipboardAll
	,clipboard:=""
	Loop 3 {
		try {
			clipboard:=str
			ClipWait,1.0
			if(!ErrorLevel && clipboard=str)
				break
		}
	}
	Sleep 100
	WB.Navigate("javascript:setTimeout(""addRowsFromClipboard(" (!!DefaultSort) ");"",0);void 0;")
	loop
	 sleep 10
	until !WB.busy
	clipboard:=oldClipboard
}

dt_add(row, col_data*){
	global wb, cols
	loop
	 sleep 10
	until !WB.busy
	js=javascript:setTimeout("dt.row.add([
	Loop % cols.maxindex()
		js.="'" (col_data[A_Index]) "',"
		;~ js.="'" (col_data[A_Index]=""?".":col_data[A_Index]) "',"
	js:=SubStr(js,1,-1) "]).draw(false);"",0);void 0;"
	wb.Navigate(js)
	loop
	 sleep 10
	until !WB.busy
}
;~ dt_add(row, col_data*){
	;~ global wb, cols, updateJs
	;~ js=javascript:$('table tbody').append('<tr>
	;~ Loop % cols.maxindex()
		;~ js.="<td>" col_data[A_Index] "</td>"
	;~ js.="</tr>');" updateJs "void 0;"
	;~ wb.Navigate(js)
;~ }
dt_delete(rowNumber=""){
	global wb, cols
	loop
	 sleep 10
	until !WB.busy
	js=javascript:setTimeout("dt.clear().draw(false);",0);void 0;
	wb.Navigate(js)
	loop
	 sleep 10
	until !WB.busy
}
dt_row_select(AccNo){
	global WB
	loop
	 sleep 10
	until !WB.busy
	WB.Navigate("javascript:setTimeout(""selectRow('" AccNo "');"",0);void 0;")
	loop
	 sleep 10
	until !WB.busy
}


Doc_OnClick(doc) {
	;~ ToolTip LButton
    src:=doc.parentWindow.event.srcElement
	if (src.tagName="TD")
		src:=src.parentNode
	if(src.tagName="TR"){
		RowEvent(src, A_ThisFunc)
	}
}
Doc_OnDblClick(doc) {
	;~ ToolTip double click
    src:=doc.parentWindow.event.srcElement
	if (src.tagName="TD")
		src:=src.parentNode
	if(src.tagName="TR"){
		RowEvent(src, A_ThisFunc)
	}
}
Doc_OnContextMenu(doc) {
	;~ ToolTip RButton
    src:=doc.parentWindow.event.srcElement
	if (src.tagName="TD")
		src:=src.parentNode
	if(src.tagName="TR"){
		RowEvent(src, A_ThisFunc)
	}
	return false
}


dt_modifyCell(AccNo, colValuePairs*){
	global WB, updateJs, ModifyCount, dt_modifying
	;~ dt_modifying:=true
	;~ ModifyCount:=ModifyCount?ModifyCount++:1
		
	;~ ToolTip % AccNo
	;~ ToolTip % exploreobj(colValuePairs)
	;~ js:="javascript:(function(){var td=$('#dataTable tbody tr:nth-child(" rowNo+1 ") td:nth-child(" colNo+1 ")');dt.cell(td).data('" value "').draw(false);})();void 0;"
	
	;~ loop
	 ;~ sleep 10
	;~ until !WB.busy
	
	js:="javascript:setTimeout(""modifyCell('" AccNo "',["
	
	Loop % (colValuePairs.maxindex()/2) {
		colNo:=colValuePairs[A_Index*2-1]+1
		,colVal:=colValuePairs[A_Index*2]
		js.="[" colNo ", '" colVal "'],"
	}
	js:=SubStr(js,1,-1) "]);"",0);"
	
	;~ js:="javascript:__rows.eq(" rowNo ").find('td').eq(" colNo ").html('" value "');void 0;"
	;~ js:="javascript:dt.cell(" rowNo "," colNo ").data('" value "');void 0;"
	;~ if (ModifyCount>20)
		;~ js.="dt.draw();"
		;~ ,ModifyCount:=0
	js.="void 0;"
	
	,WB.Navigate(js)
	;~ ToolTip % js

	;~ loop
	 ;~ sleep 10
	;~ until !WB.busy
	;~ dt_modifying:=false
	
	
}


trimExamName(examName){
	if (examName~="^CT") && InStr(examName, "coronary") && InStr(examName, "angiography")
		return "CCTA"
	else if InStr(examName, "Calcium Score")
		return "CaS"
	else if InStr(examName, "low dose lung")
		return "LDCT"
	else if InStr(examName, "perfusion CT")
		return "B: CTA/P"
	else if RegExMatch(examName, "i)(CT|MRI) (With)?\/?(Without)? Contrast\-([\w ]+)", match)
		return match1 " " (match2&&match3?"∓":match1?"+":"-") ((match4~="i)spine|extremit")?trim(match4):InStr(match4,"neck")?"N":SubStr(match4,1,1))
	else if RegExMatch(examName, "i)Chest : (PA|AP) View", match)
		return "CXR" (match1="AP"?" (AP)":"")
	else if (examName="Abdomen:KUB")
		return "KUB"
	else
		return examName
}