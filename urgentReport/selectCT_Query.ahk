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
#include <dcm4che>
;~ #include <class_sqlitedb>
;~ #include <RisImpax>
OnMessage(0x8001, "exitNow")
,args:=ParseArg()
,sendCount:=0
;~ Loop %0%
	;~ arg:=%a_index%
arg:=args[1]

;~ arg = 
;~ (
;~ {"ChartNo":5______,"Date_AccNo":{"20190718":["T__________"]},"hwnd":"0x160954","reportListTitleCol":{"保險別":27,"協同醫師":23,"合併報告序號":25,"回診日期":14,"執行住院醫師":11,"報告醫師":12,"姓名":8,"年齡":6,"床邊":15,"影像":17,"急":16,"性別":7,"撰打住院醫師":10,"放射師":24,"檢查名稱":5,"檢查地":20,"檢查日":3,"照會單號":19,"特療行為":26,"狀態":2,"病歷號":4,"診別":9,"醫令代碼\r":28,"開單日":21,"開單科別":13,"開單醫師":22},"rowData":{"accession":"99900000001","chart_no":"1000001","name":"MOCK_PATIENT","exam":"BRAIN CT"},"SearchInd":"","sid":"MOCK_SESSION_TOKEN"}
;~ )

;~ clipboard:=arg
;~ ExitApp
gui,+hwndguihwnd

try 
	info:=JXON_load(arg)
catch
	ExitApp

for k,v in ["rowData", "searchInd", "reportListTitleCol", "sid", "hwnd", "Date_AccNo", "ChartNo"]
	%v%:=info[v]
SetTimer,exit,-120000
SetTimer,checkMain,1000
;~ ChartNo:=row[reportListTitleCol["病歷號"]]




;~ chartNo:="5______"
;~ ,AccNo:="T__________"
;~ ,ExamName:="CT Without Contrast-Chest"
;~ ,ExamDate:="20180425"
;~ ,sid:=login("000000", "MOCK_PASSWORD")
info:=[]
;~ Loop 3 {
		;~ row:=reportList[searchInd]
		for ExamDate, AccNos in Date_AccNo {
			reportParts:=AccNos.length()
			for k, AccNo in AccNos {
				
			
			ExamDate:=SubStr(RegExReplace(ExamDate, "\D", ""),1,8)
			, row:=rowData[AccNo]
			, Pay:=row[reportListTitleCol["保險別"]]
			, ExamName:=Trim(row[reportListTitleCol["檢查名稱"]])
			, ExamDate:=SubStr(RegExReplace(row[reportListTitleCol["檢查日"]], "\D", ""), 1, 8)
			, clinician:=Trim(row[reportListTitleCol["開單醫師"]])
		
			if (ExamName~="i)low dose|screening") && (ExamName~="i)lung|chest|thora") {
				ldct:=true
			} 

				;~ ToolTip % "Loading PACS history: " ChartNo
				;~ 6______
				
				PacsCTHx:=PacsCTHxSearched?PacsCTHx:patientBasicInfoWebTree(patientBasicInfoWeb(chartNo, sid)).getNodeByNames("置頂","報告","影核醫報告").arr
				,PacsCTHxSearched:=true
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
					Pacs2YrHx:=Pacs2YrHxSearched?Pacs2YrHx:RisReport2Yr(sid, chartNo)
					, Pacs2YrHxArr:=Pacs2YrHxSearched?Pacs2YrHxArr:parseRisReport2Yr(Pacs2YrHx)
					, Pacs2YrHxSearched:=true
					;~ if(Pacs2YrHx~="i)(bone|lung|pulmonary) +metastas")
						;~ mets:=true
					Loop,Parse,Pacs2YrHx,.`,;:`r`n`t
					{
						s:=Trim(A_LoopField)
						if (s~="i)(bone|lung|pulmonary) +metastas") &&  !(s~="i)^No") {
							mets:=true
							break
						}
					}
					if(Pacs2YrHx~="i)operative|post[- ]?op|lobectomy|(wedge +resection)|segmentectomy|pneumonectomy")
						op:=true
					
					matchExamName:=RegExReplace(ExamName, "i)with\/without|without|with|contrast", "")
					,matchExamName:=Trim(RegExReplace(matchExamName, "\W+", " "))
					,beforeStable:=afterStable:=false
					,beforeImp:=afterImp:=""
					for _, studyPart in Pacs2YrHxArr {
						if (matchExamName!=Trim(RegExReplace(RegExReplace(studyPart[1,1], "i)with\/without|without|with|contrast", ""), "\W+", " ")))
							continue
						studyDate:=SubStr(RegExReplace(studyPart[1,3], "\D", ""),1,8)
						if(studyDate>ExamDate)
							afterImp:=studyPart[3], afterStable:=isStableCT(studyPart[3])
						else if(studyDate<ExamDate){
							beforeImp:=studyPart[3], beforeStable:=isStableCT(studyPart[3])
							break
						}
					}
					stable:=(beforeStable && afterStable) || (Trim(afterImp)!="" && Trim(afterImp)=Trim(beforeImp))
					
					 
					;~ RisListNewResult[AccNo]:=[searchInd, parts, pointsArr[ExamName]*(InStr(Pay, "自費")&&!(ExamName~="i)low dose (lung|chest)")?1.3:1)/parts/10*0.2, !!mets, !!op]
					;~ sendBack([AccNo, searchInd, parts, pointsArr[ExamName]*(InStr(Pay, "自費")&&!(ExamName~="i)low dose (lung|chest)")?1.3:1)/parts/10*0.2, !!mets, !!op])
					
					
					if !ldct && parts=1 && InStr(ExamName, "CT without contrast-chest") {
						d:=new dcm4che("PACSWFM2")
						if (d!=-1){
							s:=d.getSeriesInfo(AccNo)
							for k,v in s {
								if (v.NumberofSeriesRelatedInstances>200){
									ldct:=true
									break
								}
							}
						}
					}
					;~ schedule:=patientFutureSchedule(chartNo,sid)
					;~ ,opdDate:="",today:=SubStr(a_now,1,8),oldOpdDate
					;~ for x,y in schedule.OPD {
						;~ opdD:=RegExReplace(y.Date, "\D", "")
						;~ if(y.Doctor=clinician)
							;~ oldOpdDate:=opdD
						;~ if(opdD>=today && y.Doctor=clinician){
							;~ opdDate:=opdD
							;~ break
						;~ }
							
					;~ }
					;~ if opdDate=
						;~ opdDate:=oldOpdDate
					;~ MsgBox % clinician
					opdDate:=SubStr(RegExReplace(row[reportListTitleCol["回診日期"]], "\D", ""),1,8)
					,infoAccNo:=[], mets:=!!mets, op:=!!op, ldct:=!!ldct, stable:=!!stable
					for k,v in ["AccNo", "searchInd", "parts", "ExamName", "mets", "op", "pay", "ldct", "OpdDate", "examDate", "stable", "ChartNo"]
						infoAccNo[v]:=%v%
					info[AccNo]:=infoAccNo.clone()
					
					
					
					;~ break
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
		;~ }
		}}
		
		
;~ info:={"fail": true}
gosub sendResult
SetTimer,sendResult,2000
return 


isStableCT(ByRef imp){
	Loop,parse,imp,`n`r`t`.`;
		if (Trim(A_LoopField)!="") && !(Trim(A_LoopField)~="i)^(no|status post|s\/p|post|please)" || Trim(A_LoopField)~="i)stable|stationary")
			return false
	return true
}

checkMain:
IfWinNotExist,ahk_id %hwnd%
	ExitApp
return

sendResult:
;~ ToolTip % sendCount
if ++sendCount>20
	ExitApp
info["hwnd"]:=guihwnd

, Send_WM_COPYDATA(hwnd, 0x17, jxon_dump(info))
return

exitNow(){
	;~ MsgBox exit
	ExitApp
}

exit:
ExitApp