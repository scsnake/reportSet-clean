#MaxMem 4095
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

#persistent
;~ #notrayicon
setbatchlines,-1
#include <portallib>
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <risimpax>
#include <JXON>
;~ #include <ACC>
;~ #include <WinVisible>
;~ #include <settimerFn>
#include <exploreobj>
#include <WM_COPYDATA>
#include <DoublyLinkedList>
#include <WinHttpRequest>
#include <ParseArg>
#include <CryptFileRead>
#Include %A_ScriptDir%
#include jpegDirName.ahk
#include excludeVS.ahk
#include guiTemplate.ahk

;~ #include <AhkSelf>
#SingleInstance,Off
DetectHiddenWindows,on
ComObjError(false)
dwData:=17
sid_no:=3

Loop {
	if (shiftPressed:=GetKeyState("Shift")) || (AltPressed:=GetKeyState("Alt"))
		break
	Sleep 100
} until A_Index >4
noOldFilm:=AltPressed
,forceRedownload:=shiftPressed


try
	Menu,tray,icon,% A_ScriptDir "\J.ico"

if CryptFilePW()
	ExitApp

if !(winexist("ahk_exe PacsIE.exe") || WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")) {
	hotkey,~!#q,onexit	
}
OnMessage(0x4A, "On_WM_COPYDATA")
;~ ,OnMessage(0x8000, "request_ind")
,OnMessage(0x10201, "exit")
;~ ,AhkSelf:=AhkSelf()
,downloadInterval:=400
, request_download_queue:=new queue

if %0% {
	param:=ParseArg()
	for k,v in param {
		if(v="-noOldFilm"){
			noOldFilm:=1
		}else if WinExist("ahk_id " v)
			PacsIEhwnd:=v
	}
}

if !(PacsIEhwnd)
	PacsIEhwnd:=WinExist("ahk_exe PacsIE.exe")?WinExist("ahk_exe PacsIE.exe"):WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")

;setting
iniread,reportDir,% ini,Settings,暫存資料夾
if !instr(fileexist(reportDir),"D")
	reportDir:=a_mydocuments "\feedRIS"

reportList:=[]



,monitors:=monitorInfo()
;~ ,PicWidth:=monitors[2].w-6



ThreadPoolCount:=0,threadPoolLimit:=50
,resultPath:=(InStr(A_ScriptFullPath,"reportSet")?(A_ScriptFullPath "\..\"):(SubStr(A_ScriptDir,1,2) "\scripts\Autorun\")  ) "searchOpHxResults.txt"
;~ fileread,lastResults,% resultPath
,allTried:=0

makeGUI("getAllJpeg_main")

gui,Add,Text,,Image quality
gui,Add,Radio,vquality checked,High
gui,Add,Radio,,Low

gui,Add,Text,,Old film?
gui,Add,Radio,voldfilm checked,Yes 
gui,Add,Radio,,No 

gui,Add,Text,,Report VS?
gui,Add,Radio,vreportvs checked,All
gui,Add,Radio,,Self only

gui,Add,Text,,Hospital branch
gui,Add,DropDownList,vhospital_branch,0||H

if (noOldFilm){
	guicontrol,,No,1
	guicontrol,,Low,1
}

gui,Add,button,ggo Default,Go!
gui,Add,button,gexit yp x+30,Exit

gui,Show,Center
return

deleteLog:
FileDelete,getJpeg.log
if (ErrorLevel)
	ShowToolTip(A_LastError)
else
	ShowToolTip("Deleted!")

return

#IfWinActive,ahk_group mainGui
esc::
exit:
ExitApp
#IfWinActive


getSids(sid_no=3, branch=0){
	global 
	sidPools:=[], sidPoolsInd:=0
	
	Loop % sid_no
		sid:=askForPortalIdPw(0,1, branch)
		,sidPools.push(sid)
}

go:
gui,Submit

getSids(sid_no, Hospital_branch)


noOldFilm:=(oldFilm==2)

, filter:="filter" opt
, filter_2:="filter_2_" (reportvs)

;~ if(opt=4)
	;~ lastResults:=CryptFileRead(resultPath, ____, true)

gosub debug
return



Filter1(v){
	global examNameCol
	return (v[examNameCol]~="i)^chest|^abdomen|spine")
}
filter2(v){
	return !Filter1(v)
}
filter3(v){
	return true
}
filter4(v){
	global EIOcol
	return !Filter1(v) && InStr(v[EIOcol], "E")
}

filter_2_1(v){
	return true
}
filter_2_2(v){
	global reportvsCol
	return InStr(v[reportvscol], "陳醫師")
}
GuiClose:
ExitApp
return
debug:
if !WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI"){
	RisState:=RisOpened()
	,RisHwnd:=RisState[2]
	if !WinExist("ahk_id " rishwnd)
		RisHwnd:=RisOpened(1)[2][1]
	
	
	reportList:=[]
	if (datasource==1)
		reportListOriginal:=ParseDataGrid2("", RisHwnd)
	else if(datasource==2)
		reportListOriginal:=parseDataGrid2("", RisHwnd,"", "", false, false, false, true)
	else if (datasource==3)
		reportListOriginal:=parseDataGrid2("", RisHwnd,"", "", true, false, false, true)
	statusCol:=reportListOriginal.getColNo("status")
	,ChartNoCol:=reportListOriginal.getColNo("ChartNo")
	,AccNoCol:=reportListOriginal.getColNo("AccNo")
	,ExamDateCol:=reportListOriginal.getColNo("ExamDate")
	,ExamNameCol:=reportListOriginal.getColNo("ExamName")
	,reportvsCol:=reportListOriginal.getColNo("ReportVS")
	,EIOcol:=reportListOriginal.getColNo("EIO")
	
	,reportList.push(reportListOriginal[1])
	
	fileread,downloaded_list,% reportdir "\downloaded"
	
	for k,v in reportListOriginal.data
		;~ if (v[statusCol]!="已發報告") && (substr(v[chartNoCol],1,1)!="Y" || !(v[ExamNameCol]~="i)^chest|^abdomen|spine")){
		if (k==1)  {
			continue
		}else if (v[statusCol]!="已發報告") && (%filter%(v)) && (%filter_2%(v)){
			if forceRedownload || (!FileExistValid(reportDir "\" v[AccNoCol] " " v[ChartNoCol] ".txt") && !FileExistValid(reportDir "\" (cryptedFilename:=__CryptStr(v[AccNoCol] " " v[ChartNoCol],____)) ".txt")  && !InStr(downloaded_list, cryptedFilename)) {
				reportList.push(v)
			}
		}
	reportList:=new DataGridTable(reportList)
	,currentAccNo:=getRisAccNo(RisState[2])
	,currentChartNo:=getRisChartNo(RisState[2])
	,currentRow:=reportList.getRow("AccNo", currentAccNo)
	if (currentRow.rowNo){
		i:=currentRow.rowNo
	}else{
		i:=2
	}
	runningPyPortalInfo:={}
	,singleMode:=true
	,partialMode:=!!(A_ScriptFullPath~="is)[\\\/]reportSet[\\\/]")
	,allChartNoInd:=1
	,allChartNo:=[]
	,allChartNoArr:=[]
	for k,reportListRow in ReportList {
		if (k=1) || (reportListRow[examNameCol]~="i)(\bCT\b)|(\bMRI\b)|(Angio)|(mammo)")
			continue
		ch:=reportListRow[chartNoCol]
		if allChartNo.haskey(ch)
			allChartNo[ch].push({ind: k, accNo: reportListRow[AccNoCol], examDate: reportListRow[examDateCol], examName: reportListRow[examNameCol]})
		else
			allChartNo[ch]:=[{ind: k, accNo: reportListRow[AccNoCol], examDate: reportListRow[examDateCol], examName: reportListRow[examNameCol]}]
			,allChartNoArr.push(ch) 
	}
	
	for k,v in allChartNo {
		if(v=currentChartNo){
			allChartNoInd:=k
			break
		}
	}
	showMsg:=Format("getAllJpeg: `n`ttotal {} RIS rows`n`ttotal {} unreported`n`tstart from #{} study`n`ttotal {} chart no`n`tESC to cancel"
			, reportListOriginal.length()-1, reportList.length()-1, i-1, allChartNoArr.length())
	if (forceRedownload){
		MsgBox, 49, ,% showMsg
		IfMsgBox,No
			ExitApp
	}else 
		ShowToolTip(showMsg)
	KeyWait,esc,D T1
	if !ErrorLevel {
		ShowToolTip("getAllJpeg: canceled" )
		Sleep 1000
		ExitApp
	}
	__allChartNoInd:=allChartNoInd
	,getJpegSubs:=[]
	,runJpegError:=0
	,batch_download()
}


return


batch_download(){
	global allChartNoArr, allChartNo, allChartNoInd, reportListCount, partialMode, sid, downloadInterval, loginPw, monitors, noOldFilm, reportDir,  dwData,guihwnd, quality, getJpegSubs, redownload, ____, hasRedownload, runJpegError, forceRedownload, sidPools, sidPoolsInd, sid_no
	
	while CPULoad()>80
		Sleep 500
	ProcessLimit("getJpeg.exe", 10)
	
	if(!WinExist("WM_COPYDATA_Listener_miniPACS"))
		ToolTip % "Downloading: " allChartNoInd " / " allChartNoArr.length()
	
	thisChartNo:=allChartNoArr[allChartNoInd]
	,chartNoInfo:=allChartNo[thisChartNo]
	,rowNoArr:=[], accNoArr:=[], examDateArr:=[], examNameArr:=[]
	,allDownloaded:=true
	
	while StrLen(thisChartNo)<7
		thisChartNo:="0" thisChartNo
	chartNo:=thisChartNo
	
	;~ ,hasRedownload:=!!redownload.setcapacity(0)
	
	for _, info in chartNoInfo {
		rowNoArr.push(info.ind)
		,accNoArr.push(accNo:=info.accNo)
		,examDateArr.push(info.examDate)
		,examNameArr.push(info.examName)
		
		
		if(hasRedownload)
			allDownloaded &= !redownload.haskey(accNo)
		else
			allDownloaded &= !forceRedownload &&  (( (FileExistValid(jpegFile:=reportDir "\" AccNo " " chartNo "\" AccNo " " chartNo ".jpeg")) && isValidJpeg(jpegFile)) || FileExistValid(jpegFile:=reportDir "\" (cryptfilename:=__CryptStr(AccNo " " chartNo,____)) "\" (cryptfilename) " 1.jpeg_"))
	}
		;~ ,allDownloaded &= (FileExistValid(jpegFile:=reportDir "\" AccNo " " chartNo "\" AccNo " " chartNo ".jpeg")) && isValidJpeg(jpegFile)) || FileExistValid(jpegFile:=reportDir "\" (cryptfilename:=__CryptStr(AccNo " " chartNo)) "\" (cryptfilename) " 1.jpeg_")
		;~ ,allDownloaded &= (redownload.setcapacity(0) && !InStr(redownload, accNo)) || (!redownload && (( (FileExistValid(jpegFile:=reportDir "\" AccNo " " chartNo "\" AccNo " " chartNo ".jpeg")) && isValidJpeg(jpegFile)) || FileExistValid(jpegFile:=reportDir "\" (cryptfilename:=__CryptStr(AccNo " " chartNo,____)) "\" (cryptfilename) " 1.jpeg_")))
	
	if (!allDownloaded){
		if SubStr(chartNo,1,1)="Y"
			loginId:="Y00000"
		else if SubStr(chartNo,1,1)="H"
			loginId:="H00000"
		else
			loginId:="000000"
		
		picWidth := quality==1 ? monitors[2].w : Floor(monitors[2].w/4)
		
		,title:="_" (guihwnd+0) "_" A_TickCount "_"
		,getJpegSubs.push(title)
		Loop 3
		{
			run % """" A_ScriptDir "\getJpeg.exe"""  (partialMode?" """ A_ScriptDir "\getJpeg.ahk"" ":"")    " """ RegExReplace(jxon_dump({rowNo: rowNoArr
			, chartNo: thisChartNo
			, accNoArr: accNoArr
			, examDateArr: examDateArr
			, examNameArr: examNameArr
			, sid: sidPools[Mod(++sidPoolsInd, sid_no)+1]
			, loginId: loginId
			, loginPw: loginPw
			, monitorsCount: monitors.length()
			, noOldFilm: noOldFilm
			, PicWidth: PicWidth
			, reportDir: reportDir
			, dwData: dwData
			, forceRedownload: forceRedownload
			, ____: ____
			, hwnd: guihwnd, title: title}), """", """""") """"
			winwait,%title% ahk_exe getJpeg.exe,,3
			if !ErrorLevel
				break
		}
		runJpegError+=ErrorLevel
		if(runJpegError>3){
			MsgBox % "Can't run getJpeg.exe!"
			ExitApp
		}
		
	}
	
	searchOpHxLoopEnd:
	if ++allChartNoInd>allChartNoArr.length()
		goto batchDownloadFinish
	else
		settimer,batch_download,% allDownloaded? -1 : (-1) * Abs(downloadInterval) / (process_count>=5?1:2)

	
	return

	batchDownloadFinish:
	SetTimer,waitFinish,% !hasRedownload ? -1 : -5000
	;~ if !redownload
	;~ MsgBox,,, % "Finished!",3
	SetTimer,ToolTip,-2000
	
	return
}

waitFinish:
;~ for iii,v in ProcessList()
	;~ if (v.name="getJpeg.exe") {
		;~ return
	;~ }
for k,v in getJpegSubs
	if WinExist(v " ahk_exe getJpeg.exe")
		if hasRedownload
			return
		else{
			SetTimer,waitFinish,-2000
			return
		}
SetTimer,waitFinish,Off
getJpegSubs:=[]	
;~ getJpegLogCount:=getJpegLogCount?getJpegLogCount:0
;~ ,getJpegLogCount2:=0
;~ Loop,read,getJpeg.log
	;~ getJpegLogCount2++
;~ if(getJpegLogCount2 - getJpegLogCount){
	;~ SetTimer,waitFinish,Off
	;~ MsgBox % "Some new errors downloading jpeg!"
;~ }
;~ jpegNotDownloaded:=[]
jpegNotDownloadedList:=""
;~ ,hasRedownload:=redownload.setcapacity(0)
,_redownload:=[]
for chartNo, infos in allChartNo {
	while StrLen(chartno)<7
		chartNo:="0" chartNo
	for k, info in infos {
		if(hasRedownload && !redownload.haskey(info.AccNo))
			continue
		if !FileExistValid(reportDir "\" __CryptStr(info.AccNo " " chartNo,____) "\" __CryptStr(info.AccNo " " chartNo,____) " 1.jpeg_") && !FileExistValid(reportdir "\" info.AccNo " " chartNo "\" info.AccNo " " chartNo " 1.jpeg")
			;~ jpegNotDownloaded.push(info.accNo " " chartNo)
			jpegNotDownloadedList.=info.accNo " " chartNo "`n"
			,_redownload[info.accNo]:=1
	}
}
redownload:=_redownload
,hasRedownload:=redownload.setcapacity(0)
if(hasRedownload){
	;~ clipboard:=RegExReplace("照會單號 病歷號`n" jpegNotDownloadedList, " ", "`t")
	RegExReplace("照會單號 病歷號`n" jpegNotDownloadedList, " ", "`t")
	,jpegNotDownloadedList:=StrLen(jpegNotDownloadedList)>200?SubStr(jpegNotDownloadedList,1,200) "`n...":jpegNotDownloadedList
	
	
	
	if(++allTried>3 || (lastRedownload && lastRedownload==hasRedownload)){
		MsgBox, 4, ,% hasRedownload " not downloaded, retry?`n`n" jpegNotDownloadedList
		IfMsgBox,Yes
		{
			
			allChartNoInd:=__allChartNoInd
			;~ ,allChartNoArr:=[]
			;~ ,allChartNoNew:=[]
			;~ for k, v in jpegNotDownloaded {
				;~ chartNo:=SubStr(v,12,7)
				;~ ,accNo:=SubStr(v,1,11)
				;~ if !allChartNoArrNew.haskey(chartNo)
					;~ allChartNoArr.push(chartNo)
					;~ ,allChartNoNew[chartNo]:=[]
				;~ for x, info in allChartNo[chartNo]
					;~ if (info.AccNo==AccNo){
						;~ allChartNoNew[chartNo].push(info.clone())
						;~ break
					;~ }
			;~ }
			;~ allChartNo:=allChartNoNew
			;~ ,redownload:=jpegNotDownloadedList
			,allDownloaded:=false
			getSids(3, Hospital_branch)
			runJpegError:=0
			SetTimer,batch_download,-1000
			
		}else{
			jpegNotDownloaded:=[]
			ExitApp
		}
	}else{
		allChartNoInd:=__allChartNoInd
		,allDownloaded:=false
		getSids(3, Hospital_branch)
		runJpegError:=0
		SetTimer,batch_download,-1000
	}
	lastRedownload:=hasRedownload
	
}else{
	MsgBox,,, % "Finished!",3
	ExitApp
}
return

On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
; dwData = Command
; cbData = String lenght
; lpData = String
	Critical
	global i, reportList, reportListCount, request_download_queue, pyPortal_received, chartNoCol, allChartNo, allChartNoInd
	dwData := NumGet(lParam+0, 0)
	,cbData := NumGet(lParam + A_PtrSize)
	,lpData := NumGet(lParam + 2*A_PtrSize)
	,str := StrGet(lpData)
	
	;~ global PacsIEhwnd, sendDataLock
	;~ if(hwnd=PacsIEhwnd && lpData="received")
		;~ sendDataLock:=false
		
	
		
		
	if (dwData=17){
		try
			j:=jxon_load(str)
		catch e
			return
		;~ ToolTip % exploreobj(j)
		if(j.haskey("start_from")){
			i:=j.start_from
			
			chartNo:=reportList[i, chartNoCol]
			for k,v in allChartNo {
				if (v=chartNo){
					allChartNoInd:=k
					SetTimer,batch_download,-1
					return
				}
			}
			;~ SetTimer,download,Off
			;~ settimer,download,-1
		}else if(j.haskey("reportList")){
			try
				reportList:=new DataGridTable(j.reportList)
				,reportListCount:=reportList.maxindex()
		}else if(j.haskey("current_miniPACS_index")){
			adjustDownloadInterval(j.current_miniPACS_index)
		}else if(j.haskey("request")){
			request_download_queue.enqueue(j.request)
			;~ SetTimerF("request_download", -1, [j.request])
			settimer,request_download,-100
		}else if(j.haskey("reset")){
			settimer,request_download,Off
			settimer,download,Off
		}else if(j.haskey("received")){
			pyPortal_received:=true
		}
	}
	
}


test:
ToolTip % "                        " i "," reportList.maxindex() "," reportList.setcapacity(0) "," IsObject(reportList[21])
return

;~ startDownload:


request_download(){
	global i, request, downloadInterval, request_download_queue
	if request_download_queue.isEmpty() {
		SetTimer,request_download,Off
		settimer,download,% (-1)*downloadInterval
		return
	}else {
		ind:=request_download_queue.dequeue()
		settimer,download,Off
		p_i:=i
		,request:=true
		,i:=ind
		gosub download
		i:=p_i
		SetTimer,request_download,-50
	}
	
	
}

download:
	;~ thread,Priority,1
	;~ ToolTip % i "," RisSearchResultCount
	;~ ToolTip % i
	
	
	if (i=""){
		settimer,download,% (-1)*downloadInterval
		return
	}
	
	if(i>reportList.maxIndex()){
		if (singleMode)
			ExitApp
		SetTimer,,% (-1)*downloadInterval
		return
	}
		
		;~ goto downloadEnd
	;~ if(i>reportListCount){
		;~ exitapp
	;~ }
	;~ if(!reportList.haskey(i) || !IsObject(reportList[i])){
		;~ settimer,download,-500
		;~ return
	;~ } 
	
	;~ thisStudy:=reportList[i]
	;~ ,AccNo:=reportList[i,AccNoCol],chartNo:=reportList[i,chartNoCol],examName:=reportList[i,examNameCol]
	
	
	thisStudy:=reportList.getRow(i)
	for k,v in ["AccNo", "ChartNo", "ExamName", "ExamDate"]
		%v%:=thisStudy.getCell(v)
	
	callPyPortal:=false
	;~ ,noOldFilm:=false
	if SubStr(chartNo,1,1)="Y"
		loginId:="Y00000"
	else if SubStr(chartNo,1,1)="H"
		loginId:="H00000"
	else{
		loginId:="000000"
		;~ if !(WinExist("WM_COPYDATA_Listener_portalLib")){
			;~ run % "pyPortal.exe"
			;~ WinWait,WM_COPYDATA_Listener_portalLib,,30
			;~ if ErrorLevel {
				;~ MsgBox % "Can't open pyPortal.exe"
				;~ ExitApp
			;~ }
			;~ Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_portalLib")
				;~ , dwData:=17
				;~ , jxon_dump({portalLogin: 1, loginId: loginId, loginPw: loginPw}))
			;~ ,Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_portalLib")
				;~ , dwData:=17
				;~ , jxon_dump({getAllJpegHwnd: WinExist("getAllJpeg_main ahk_class AutoHotkeyGUI")+0}))
		;~ }
		;~ pyPortal_received:=false
		;~ while !pyPortal_received {
			;~ Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_portalLib")
				;~ , dwData:=17
				;~ , jxon_dump({downloadJpeg: 1, accNo: accNo, chartNo: chartNo
					;~ , folder: reportDir "\" accNo " " chartNo "\", flatten: 0, index: i-2}))
			;~ ToolTip % "Send: " accNo "," chartNo "   " A_TickCount
			;~ Sleep 100
		;~ }
		if 0 {
			
			callPyPortal:=true
			
			if !FileExistValid(reportDir "\" accNo " " chartNo "\" accNo " " chartNo " 1.jpeg")
			{
				;~ Loop {
					;~ pyp=0
					;~ for k,v in processList()
						;~ if SubStr(k, "pyPortal.exe")=1
							;~ pyp++
					;~ ToolTip % pyp
					;~ if (pyp<20)
						;~ break
					;~ Sleep 500
				;~ }
				
				run % "pyPortal.exe " loginId " """ loginPw """ " accNo " " chartNo " """ reportDir "\" accNo " " chartNo "\""" 
				Sleep 1000
				
				if(monitors.maxindex()>2 && !noOldFilm && SubStr(loginId,1,1)~="\d" && dayDiff(a_now, examDate)<180){
					anyPriorImage:=0, priorImage:={}
						PacsHx:=getPacsHx(sid,chartNo)
						
						for k,v in PacsHx {
							if relatedExam(v.ExamName,examName) && (regexreplace(v.ExamDate,"\D","")<=substr(regexreplace(thisStudy.getCell("ExamDate"),"\D",""),1,8)) && (strlen(oldAccNo:=v.AccessNo)>=11) {  ;may catch exam on the same day
								
								if regexreplace(v.AccessNo,"i)^[a-z]+","")>=regexreplace(AccNo,"i)^[a-z]+","") && regexreplace(v.AccessNo,"\d+$","")=regexreplace(AccNo,"\d+$","")
									continue
								
								;~ WBp[thisGuiInd].Navigate("about:blank")
								;~ WBp[thisGuiInd].Navigate(PacsWebUrl(v.AccessNo,thisStudy[chartNoCol],loginId,loginPw))
								anyPriorImage:=1
								,oldChartNo:=v.ChartNo
								
								if !FileExistValid(reportDir "\" accno " " chartNo "\" oldAccNo " " oldChartNo " 1.jpeg"){
									run % "pyPortal.exe " loginId " """ loginPw """ " oldAccNo " " oldChartNo " """ reportDir "\" accNo " " chartNo "\""" 
									Sleep 1000
								}
									
								break
							}
						}
					
				}
				
				
				
				if !runningPyPortal
					runningPyPortal=1
				else
					runningPyPortal++
				
				runningPyPortalInfo[runningPyPortal]:={AccNo: AccNo, chartNo:chartNo}
				
				if (runningPyPortal>5) {
					Loop{
						WinClose,ahk_exe pyPortal.exe,Failed to execute script
						prior_path := reportDir "\" runningPyPortalInfo[runningPyPortal-5].accNo " " runningPyPortalInfo[runningPyPortal-5].chartNo "\" runningPyPortalInfo[runningPyPortal-5].accNo " " runningPyPortalInfo[runningPyPortal-5].chartNo " 1.jpeg"
						if FileExistValid(prior_path) || A_Index>100
							break
						else
							Sleep 500
					}
				}
				
				
				
				++i
				;~ settimer,, % (-1)*downloadInterval
				SetTimer,,-100
			}else{
				++i
				settimer,, -1
			}
			
			
			;~ ExitApp
			return
		}
	}
	
	;~ while getJpegCount()>threadPoolLimit
		;~ Sleep % downloadInterval
	
	;~ json:=[]
	;~ for _,v in ["AccNo", "chartNo", "loginId", "loginPw", "threadPoolLimit", "monitors", "noOldFilm", "dwData", "reportDir", "downloadInterval", "picWidth", "i", "reportListCount"]
		;~ json[v]:=%v%
	;~ run % """" A_ScriptDir "\getJpeg.exe"" """ A_ScriptDir "\getJpeg.ahk"" """ RegExReplace(jxon_dump(json), """", """""") """"

Loop {
	process_count:=0
	for iii,v in ProcessList()
		if (v.name="getJpeg.exe") && ( (++process_count>30 )) {
			break
		}
	if(process_count>30)
		break
}
if 1
{
	if(!WinExist("WM_COPYDATA_Listener_miniPACS"))
		ToolTip % "Downloading: " i-1 " / " reportListCount-1
	
	
	outputDict:={study_data:1}
	,outputDict[i-2]:={AccNo: AccNo, ChartNo: chartNo, expected_image_count:[]}
	;~ FileAppend,% a_now ": " i " - " chartNo "," accno,logtem.txt,utf-8
	if (AccNo="" || chartNo=""){
		;~ MsgBox % exploreobj(reportList)
		settimer,, % (-1)*downloadInterval
		return
	}
	
	;~ if(thisStudy[statusCol]="已發報告"){
		;~ ++i
		
		;~ Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_miniPACS"), dwData, jxon_dump(outputDict))
		;~ goto continueLoop
		;~ if(leave)
			;~ exitapp
		;~ continue
	;~ }
	
	
	;~ msgbox % fileexist(reportDir "\" AccNo " " chartNo "\" AccNo " " chartNo " 1.jpeg")
	dict:={}, dictEmpty:=true, downloadNothing:=true
	;~ if !fileexist(reportDir "\" AccNo " " chartNo "\" AccNo " " chartNo " 1.jpeg") {
		; tooltip `% "downloading:" AccNo "," chartNo "," reportDir " " loginId loginPw 
		; PacsWebDownloadJpeg(AccNo,chartNo,"",reportDir,PicWidth,loginId,loginPw)
		output:=PacsWebInfoFlatten(PacsWebInfo(output,AccNo,chartNo,loginId,loginPw))
		;~ loadedPicCount[AccNo " " chartNo]:=output.maxindex()
		,max:=output.maxindex()
		
		
		
		for k,v in output {
			while (threadPoolCount>threadPoolLimit)
				sleep % downloadInterval
			if RegExMatch(v.objectUID,"[^\d\.]")
				continue
			dict[AccNo]:=k, dictEmpty:=false
			if FileExistValid(jpegFile:=reportDir "\" AccNo " " chartNo "\" AccNo " " chartNo " " k ".jpeg") && isValidJpeg(jpegFile)
				continue
			
			if InStr(examName,"Spine") && !(examName~="i)\b(CT|MRI?)\b")
				initThread(v.url, AccNo,chartNo, AccNo,ChartNo, max-k+1, i), downloadNothing:=false
			else
				initThread(v.url, AccNo,chartNo, AccNo,ChartNo, k, i), downloadNothing:=false
			
			;~ PacsWebDownloadJpeg2(v.url,AccNo,chartNo,AccNo " " chartNo " " k ".jpeg",reportdir "\" AccNo " " chartNo,PicWidth,loginId,loginPw)
			;~ if !winexist("ahk_exe PacsIE.exe") {
				;~ traytip,% "Downloaded: " k "/" max " images (" (i-1) "/" (reportListCount-1) " studies)"
				;~ settimer,traytip,-2000
			;~ }
			;~ sleep 500
		}
		
		
	if !dictEmpty
		outputDict[i-2].expected_image_count.push(dict)
	else
		outputDict[i-2].expected_image_count[AccNo]:=0
	;~ goto continueLoop
	dict:={}, dictEmpty:=true
	if(monitors.maxindex()>2 && !noOldFilm){
		anyPriorImage:=0, priorImage:={}
		;~ loop % reportDir "\" AccNo " " chartNo "\*.jpeg"
			;~ if regexmatch(a_loopfilename,"(\w+) \w+ (\d+)\.jpeg",match) && (match1!=AccNo) {
				;~ anyPriorImage:=1
				;~ ,oldAccNo:=match1
				;~ ,priorImage[oldAccNo]:=match2
			;~ }
		
			
			PacsHx:=""
			if FileExistValid(PacsHxJsonFile:=A_ScriptDir "\PacsHx_" chartNo ".json"){
				try {
					fileread,json_data,% PacsHxJsonFile
					PacsHx:=jxon_load(json_data)
				}
			}
			if(PacsHx=""){
				PacsHx:=getPacsHx(sid,chartNo)
				FileDelete,% PacsHxJsonFile
				FileAppend,% jxon_dump(PacsHx),% PacsHxJsonFile,utf-8
			}
				
			
			for k,v in PacsHx {
				if relatedExam(v.ExamName,examName) && (regexreplace(v.ExamDate,"\D","")<=substr(regexreplace(thisStudy.getCell("ExamDate"),"\D",""),1,8)) && (strlen(oldAccNo:=v.AccessNo)>=11) {  ;may catch exam on the same day
					
					if regexreplace(v.AccessNo,"i)^[a-z]+","")>=regexreplace(AccNo,"i)^[a-z]+","") && regexreplace(v.AccessNo,"\d+$","")=regexreplace(AccNo,"\d+$","")
						continue
					
					;~ WBp[thisGuiInd].Navigate("about:blank")
					;~ WBp[thisGuiInd].Navigate(PacsWebUrl(v.AccessNo,thisStudy[chartNoCol],loginId,loginPw))
					anyPriorImage:=1
					,oldChartNo:=v.ChartNo
					
					
						output:=PacsWebInfoFlatten(PacsWebInfo(output, oldAccNo,oldChartNo,loginId,loginPw))
						,loadedPicCount[ oldAccNo " " oldChartNo ]:=output.maxindex()
						,max:=output.maxindex()
						
						for q,r in output {
							if RegExMatch(r.objectUID,"[^\d\.]")
								continue
							while (threadPoolCount>threadPoolLimit)
								sleep % downloadInterval
							dict[oldAccNo]:=q, dictEmpty:=false
							if FileExistValid(jpegFile:=reportDir "\" accno " " chartNo "\" oldAccNo " " oldChartNo " " q ".jpeg") && isValidJpeg(jpegFile)
								continue
							if InStr(examName,"Spine") && !(examName~="i)\b(CT|MRI?)\b")
								initThread(r.url, oldAccNo, oldChartNo, AccNo, chartNo, max-q+1, i), downloadNothing:=false
							else
								initThread(r.url, oldAccNo, oldChartNo, AccNo, chartNo, q, i), downloadNothing:=false
							;~ initThread(r.url, oldAccNo, oldChartNo, AccNo, chartNo, q, i)
							
							;~ PacsWebDownloadJpeg2(r.url,oldAccNo,chartNo,oldAccNo " " chartNo " " q ".jpeg",reportdir "\" AccNo " " chartNo,PicWidth,loginId,loginPw)
							;~ if !winexist("ahk_exe PacsIE.exe") {
								;~ traytip,% "Downloaded: " q "/" max " old images (" (i-1) "/" (reportListCount-1) " studies)"
								;~ settimer,traytip,-2000
							;~ }
							;~ sleep 500
						}
						;~ PacsWebDownloadJpeg(oldAccNo,chartNo,"",reportDir,thisMonitor.w-6,loginid,loginpw)
					
					
					
					break
				}
			}
		
	}
	if !dictEmpty
		outputDict[i-2].expected_image_count.push(dict)
		
		
		
	Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_miniPACS"), dwData, jxon_dump(outputDict))
	;~ ExitApp
}
	
	if (request){
		request:=false
		return
	}
		
	
	continueLoop:
	if(leave)
		exitapp
	++i
	settimer,download,% downloadNothing?-1:(-1)*downloadInterval
return 


getJpegCount(){
	i:=0
	for k,v in processlist()
		if (v="getJpeg.exe")
			i++
	return i
}

dayDiff(now_day, prior_day){
	a:=RegExReplace(now_day, "\D", "")
	,b:=RegExReplace(prior_day, "\D", "")
	
	,a:=SubStr(a,1,8)
	,b:=SubStr(b,1,8)
	
	a-=b, Days
	return a
	
}

downloadEnd:
leave:=1
ToolTip

while A_Index<240 && threadPoolCount>0
	Sleep 500

if(!PacsIEhwnd)
	MsgBox % "Finished download!"
exitapp
return




;~ updateThread(){
	;~ global threadPool, threadPoolCount, threadPoolLimit

	;~ count:=0
	;~ for k,v in threadPool {
		;~ if !isobject(v)
			;~ continue
		;~ if v.ahkgetvar("threadStart") && v.ahkgetvar("threadFinished"){
			;~ v.ahkTerminate(), ahkthread_free(v)
			;~ ,threadPool.removeAt(k)
		;~ }else{
			;~ ++Count
		;~ }
	;~ }
	;~ threadPoolCount:=count
	
	;~ if(threadPoolCount > 0.8* threadPoolLimit)
		;~ settimerF("updateThread",-500)
	;~ else
		;~ settimerF("updateThread",-2000)
;~ }
;~ return

downloadCallback(){
	global threadPoolCount
	threadPoolCount--
	;~ ToolTip % "--count"
}

initThread(url,oldAccNo,oldChartNo, AccNo,chartNo, k, i){
	global reportdir, picWidth, loginId, loginPw, threadPool, reportListCount, threadPoolCount,loginId,loginPw, threadPoolLimit
	
	kk:=k
	json:={}
	for k,v in ["url", "oldAccNo", "oldChartNo", "accNo", "chartNo", "kk", "i", "reportDir", "picWidth", "loginId", "loginPw"]
		json["" v]:=%v%
	
	;~ MsgBox % exploreobj(json)
	;~ MsgBox % """" A_ScriptDir "\getJpeg.exe"" """ A_ScriptDir "\getJpeg.ahk"" """ RegExReplace(jxon_dump(json), """", """""") """"
	run % """" A_ScriptDir "\getJpeg.exe"" """ A_ScriptDir "\getJpeg.ahk"" """ RegExReplace(jxon_dump(json), """", """""") """"
	;~ PacsWebDownloadJpeg2(url,oldAccNo,oldChartNo,oldAccNo " " oldChartNo " " kk ".jpeg",reportdir "\" AccNo " " chartNo,PicWidth*4,loginId,loginPw,3,100,1)
	;~ Sleep 300
	return
	
	
	
	
	
	
	
	while threadPoolCount>=threadPoolLimit
		Sleep 500
	;~ PacsWebDownloadJpeg2(url,oldAccNo,oldChartNo,oldAccNo " " oldChartNo " " k ".jpeg",reportdir "\" AccNo " " chartNo,PicWidth*2,loginId,loginPw,3,100,1)
	;~ if i=8
		;~ aaa=1
	threadPoolCount++
	;~ settimerFn("PacsWebDownloadJpeg2", -1, [url,oldAccNo,oldChartNo,oldAccNo " " oldChartNo " " k ".jpeg",reportdir "\" AccNo " " chartNo,PicWidth,loginId,loginPw,3,100,1, "downloadCallback"])
	/*
	,ahkmini("
	(LTrim
	#NoTrayIcon
	#Persistent
	SetBatchLines,-1
	settimer,exit,-60000
	DetectHiddenWindows,on
	#include <portallib>
	threadStart:=1
	,threadFinished:=0
	,url:=""" url """
	,AccNo:=""" AccNo """
	,oldAccNo:=""" oldAccNo """
	,oldChartNo:=""" oldChartNo """
	,ChartNo:=""" ChartNo """
	,reportDir:=""" reportDir """
	,picWidth:=""" PicWidth """
	,loginId:=""" loginId """
	,loginPw:=""" loginPw """
	,k:=""" k """, i:=""" i """, reportListCount:=""" reportList.maxIndex() """
	,Alias(threadPoolCount, " getvar(threadPoolCount) ")
	PacsWebDownloadJpeg2(url,oldAccNo,oldChartNo,oldAccNo "" "" oldChartNo "" "" k "".jpeg"",reportdir ""\"" AccNo "" "" chartNo,PicWidth*2,loginId,loginPw,3,100,1, ""downloadCallback"")
	return
	downloadCallback(){
		global
		if !winexist(""ahk_exe PacsIE.exe"") && !WinExist(""miniPACS_bridge_main ahk_class AutoHotkeyGUI"") {
			ToolTip,% ""Downloaded: "" k ""/"" max "" images ("" (i-1) ""/"" (reportListCount-1) "" studies)""
		}
		threadPoolCount--
		exitapp
	}
	exit:
	threadPoolCount--
	exitapp
	)")
	;~ PacsWebDownloadJpeg2(url,oldAccNo,oldChartNo,oldAccNo " " oldChartNo " " k ".jpeg",reportdir "\" AccNo " " chartNo,PicWidth*2,loginId,loginPw,3,100,1, "downloadCallback")
	
	
	
	Sleep 500
	return
	
	;~ return
	;~ th:=AhkThread("
	;~ (Ltrim
	;~ #notrayicon
	;~ setbatchlines,-1
	;~ #include <portallib>
	;~ threadStart:=1
	;~ ,threadFinished:=0
	;~ ,url:=""" url """
	;~ ,AccNo:=""" AccNo """
	;~ ,oldAccNo:=""" oldAccNo """
	;~ ,oldChartNo:=""" oldChartNo """
	;~ ,ChartNo:=""" ChartNo """
	;~ ,reportDir:=""" reportDir """
	;~ ,picWidth:=""" PicWidth """
	;~ ,loginId:=""" loginId """
	;~ ,loginPw:=""" loginPw """
	;~ ,k:=""" k """, i:=""" i """, reportListCount:=""" reportListCount """
	;~ ,Alias(threadPoolCount, " getvar(threadPoolCount) ")
	;~ ,PacsWebDownloadJpeg2(url,oldAccNo,oldChartNo,oldAccNo "" "" oldChartNo "" "" k "".jpeg"",reportdir ""\"" AccNo "" "" chartNo,PicWidth,loginId,loginPw)
	;~ loop 100 
		;~ tooltip `% threadPoolCount "","" a_index
	
	;~ if !winexist(""ahk_exe PacsIE.exe"") {
		;~ traytip,`% ""Downloaded: "" k ""/"" max "" images ("" (i-1) ""/"" (reportListCount-1) "" studies)""
	;~ }
	;~ Sleep 1000
	;~ threadFinished:=1
	;~ ,threadPoolCount--
	;~ exitapp
	;~ )")
	;~ while !th.ahkReady()
		;~ Sleep 100
		
	*/
}


relatedExam(exam,thisExam){
	if (exam=thisExam)
		return 1
	else if regexmatch(exam,"is)chest\b.+?view") && regexmatch(thisExam,"is)chest\b.+?view")
		return 1
	
	return 0
}

;~ esc::ExitApp

getAllReportList:
;~ parseDataGrid(RisListHwnd,reportList)
 loadFinished:=false
,RisListRowsAcc:=acc_children(Acc_objectfromwindow(RisListHwnd))
,RisListRowsCount:=RisListRowsAcc.maxindex()
;~ ,parseDataGrid(RisListRowsAcc,reportList,1,loadReportListInd:=20,"","","reportListProgress")
;~ ,parseDataGrid(RisListRowsAcc,reportList,1,loadReportListInd:=0,"","","reportListProgress")

Loop % reportListCount 
	if !(reportList[reportListCount-A_Index+1, AccNoCol]~="\w{9}\d")
		reportList.remove(reportListCount-A_Index+1)
	else
		break
reportListCount:=reportList.maxindex()
,Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_miniPACS"), dwData, jxon_dump({total_study_count: reportListCount-1}))
,Send_WM_COPYDATA(WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI"), 0, jxon_dump(reportList))
;~ parseDataGrid(RisListRowsAcc,reportList,1,[21, 30],"""","""","""")
;~ getInterval:=Floor(RisListRowsCount/5)+1
;~ parseThreadCount:=0
;~ Loop 5 {
	;~ ahkThread("
	;~ (LTrim
	;~ #include <RisImpax>
	;~ #include <Acc>
	;~ #persistent
	;~ #notrayicon
	;~ SetBatchLines,-1
	;~ reportList:=CriticalObject(" (&reportList) ")
	;~ ,Alias(RisListRowsAcc, " getvar(RisListRowsAcc) ")
	;~ ,Alias(parseThreadCount, " parseThreadCount ")
	;~ ,parseDataGrid(RisListRowsAcc,reportList,1," getInterval ",0," 1+(a_index-1)*getInterval ",""reportListProgress"")
	;~ ,++parseThreadCount
	;~ exitapp
	;~ )")
;~ }

;~ while parseThreadCount<5
	;~ Sleep 500
ToolTip
;~ settimer,keepLoadReportList,-2000
;~ settimer,keepLoadReportListTh,-2000
if !WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI"){
	i:=2
	gosub download
}
return


keepLoadReportListTh:

return

writeReportList(str){
	global reportListCount, reportList
	try 
		json:=jxon_load(str)
	catch
		return
	for k,v in json
		if k>reportListCount
			return
		else
			reportList[k]:=v
}

ToolTip:
ToolTip
return

saveResult:
;~ if FileExistValid(jxonFile:=reportDir "\reportList.json")
	;~ FileDelete,% jxonFile
;~ FileAppend,% jxon_dump(reportList),% jxonFile,utf-8

return

reportListProgress(k, ByRef rowAcc, ByRef cellsAcc){
	global reportListCount, PacsIEhwnd, startDownload
	;~ if k<100
		tooltip % "Get list from RIS: " k-1 " / " reportListCount-1 " ..."
	;~ settimerFn("sendData", -1, [k])
	;~ sendData(k)
	;~ if(k=10){
		;~ startDownload:=true
		;~ settimer,startDownload,-1,-1
	;~ }
}



sendData(k){
	thread,Priority,-1
	global reportList, PacsIEhwnd, sendDataLock
	if (PacsIEhwnd){
		obj:=[]
		,obj[k]:=reportList[k]
		
		;~ while sendDataLock || A_Index<50
			;~ Sleep 100
		;~ sendDataLock:=true
		,Send_WM_COPYDATA(PacsIEhwnd, 0, jxon_dump(obj))
		
	}
	
}



adjustDownloadInterval(ind){
	global downloadInterval,i
	if (ind>=i || i-ind<6)
		downloadInterval:=100
	else if (i-ind<20)
		downloadInterval:=200
	else
		downloadInterval:=300
}


traytip:
TrayTip
return

;~ routine:
;~ ifwinnotexist,ahk_exe PacsIE.exe
	;~ exitapp
;~ return
onexit:
for k,v in sidPools
	logout(v)
Loop % A_ScriptDir "\PacsHx_*.json"
	FileDelete % A_LoopFileLongPath
notrayorphans()

if (++leave>1){
	;~ winclose,ahk_exe PacsIE.exe
	exitapp
}else{
	sleep 5000
	;~ winclose,ahk_exe PacsIE.exe
	exitapp
}
