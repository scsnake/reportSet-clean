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
#NoTrayIcon
comobjerror(false)
;~ onexit,onexit

#include <portallib>
#include <JXON>
#include <WM_COPYDATA>
#include <ParseArg>
#include <CryptFileRead>


;~ #include <RisImpax>
OnMessage(0x8001, "exitNow")
,args:=ParseArg()
,sendCount:=0
;~ Loop %0%
	;~ arg:=%a_index%
,arg:=args[args.maxindex()]
;~ msgbox % clipboard:=arg
gui,+hwndguihwnd


try 
	info:=JXON_load(arg)
catch
	ExitApp

if CryptFilePW()
	ExitApp

for k,v in ["RisListHwnd", "rowNo", "unselect", "chartNo", "AccNo", "examDate", "sid", "hwnd", "examName"]
	%v%:=info[v]


SetTimer,exit,-120000
; SetTimer,checkMain,1000


;~ str:=""
;~ for k,v in ["RisListHwnd", "rowNo", "unselect", "chartNo", "AccNo", "examDate", "sid", "hwnd"]
	;~ str.=v ": " %v% "`n"
;~ MsgBox % str
select:=false
;~ opHx:=false
,needOphx:=false
,needLaterHx:=false
,opHxWritten:=false
,laterHxWritten:=false

;~ for k,v in examName
	;~ if (v~="i)^(Chest|Abdomen)")
		;~ needLaterHx:=true
	;~ else
		needOpHx:=true


while StrLen(chartNo)<7
	chartNo:="0" chartNo

;~ if (chartNo~="i)^Y"){	
ptInfo:=patientBasicInfoWeb(chartNo, sid, personId)

if(needOpHx && !opHxWritten){
	AdmissionHx:=patientBasicInfoWebTree(ptInfo).getNodeByNames("住院").arr
	;~ MsgBox % exploreobj(AdmissionHx)
	for k,v in AdmissionHx {
		;~ hxDate:=SubStr(RegExReplace(v.innerText, "\D", ""), 1, 8)
		
		if (instr(v.innerText, "骨科")){
			select:=true
			break
		}
	}
	;~ RisListChildrenAcc:=acc_children(acc_objectfromwindow(RisListHwnd))
	if (select && !unselect) || (!select && unselect) {
	;~ ToolTip % "Row " rowNo " selected!"
		for k, AccNo_ in AccNo {
			;~ FileAppend,% RisListHwnd "," rowNo[k] "," AccNo_ "`n",searchOpHxResults.txt,utf-8
			CryptFileAppend(RisListHwnd "," rowNo[k] "," AccNo_, "searchOpHxResults.txt",____)
			,opHxWritten:=true
			;~ ,opHx:=true
			;~ RisListChildrenAcc[rowNo[k]].accSelect(ComObj(3,8),0)
		}
		
	}
	
	
}

if ((needLaterHx && !laterHxWritten) || (needOphx && !opHxWritten)) && (Pacs2YrHx:=parseRisReport2Yr(RisReport2Yr(sid, personId, substr(chartNo,1,1)~="i)H|Y"?substr(chartNo,1,1):"T0"))).length()

	for k_, examDate_ in examDate {
		examDate_:=SubStr(RegExReplace(examDate_, "\D", ""), 1, 8)
		,select:=false
		;~ ,noLaterReport:=true
		;~ ,RegExMatch(examName[k_], "i)^Chest|Abdomen", payAttention)
		for k,v in Pacs2YrHx {
			hxDate:=SubStr(RegExReplace(v[1,3], "\D", ""), 1, 8)

			if (examDate_<=hxDate) && (v[2]~="i)s\/p|status post|post[\- ]op|arthroplasty|(total (hip|knee) replace)"){
				select:=true
				;~ break
			}
			
			;~ if(payAttention && examDate_<=hxDate && ((v[1,1]~="i)^" payAttention) || (v[1,1]~="is)^(CT|MR).+" payAttention) ) )
				;~ noLaterReport:=false
			
		}
		
		if (select && !unselect) || (!select && unselect)  {
		
			;~ FileAppend,% RisListHwnd "," rowNo[k_] "," AccNo[k_] "`n",searchOpHxResults.txt,utf-8
			CryptFileAppend(RisListHwnd "," rowNo[k_] "," AccNo[k_], "searchOpHxResults.txt",____)
			, ophxwritten:=true
			;~ RisListChildrenAcc[rowNo[k_]].accSelect(ComObj(3,8),0)
		}
		
		;~ if  payAttention && ((noLaterReport && !unselect) || (!noLaterReport && unselect))
			;~ CryptFileAppend(AccNo[k_], "noLaterReport.txt",____)
			;~ , laterHxWritten:=true
			
		
	}	
ExitApp
return 
/*
else if (!Pacs2YrHx.length()) && (needLaterHx && !laterHxWritten){
	
	for k_, examDate_ in examDate {
		examDate_:=SubStr(RegExReplace(examDate_, "\D", ""), 1, 8)
		,noLaterReport:=true
		,RegExMatch(examName[k_], "i)^Chest|Abdomen", payAttention)
		
		if(payAttention){
			
		if !PacsHx 
			pacsHx:=getPacsHxByPortal(sid, chartNo, pacsHx, personId)
		
		for k,v in PacsHx {
			if (payAttention && examDate_<=v.ExamDate && v.ReportDate && ((v.ExamName~="i)^" payAttention) || (v.ExamName~="is)^(CT|MR).+" payAttention) )){
				noLaterReport:=false
				break
			}
		}
		
		if  payAttention && ((noLaterReport && !unselect) || (!noLaterReport && unselect))
			CryptFileAppend(AccNo[k_], "noLaterReport.txt",____)
			,laterHxWritten:=true
		}
	}

}


if !(ophxwritten || laterHxWritten)
	portalInfoTemp(chartNo, "", "", "", deleteAction:=true)
	,portalInfoTemp(personId, "", "", "", deleteAction:=true)


*/
checkMain:
If !WinExist("ahk_id " hwnd)
	ExitApp
return

sendResult:
;~ ToolTip % sendCount
if ++sendCount>20
	ExitApp
info["hwnd"]:=guihwnd
,Send_WM_COPYDATA(hwnd, 0x17, jxon_dump(info))
return

exitNow(){
	;~ MsgBox exit
	ExitApp
}

exit:
ExitApp








