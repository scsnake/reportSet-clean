#MaxMem 4095
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,Force
SetBatchLines, -1
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
SetTitleMatchMode,2
SetControlDelay,-1
DetectHiddenWindows,on
ComObjError(false)
process,Priority,,h
#notrayicon
;~ onexit,onexit
#persistent
; Does not use CH_RIS — opt out of owning a local (IE-polling) CH_RIS. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <CryptFileRead>
#include <WM_COPYDATA>
#include <RisImpax>
#include <JXON>
#Include %A_ScriptDir%
#include jpegDirName.ahk
#include send_data.ahk
OnExit,OnExit
if CryptFilePW()
	ExitApp


OnMessage(0x4a, "On_WM_COPYDATA")
OnMessage(0x10101, "exit")
,reportDir:=A_MyDocuments "\feedRIS"
,decrypted:=[]
,reportListStatus:=[]
,dwData:=17
;~ MsgBox % __CryptStr("w9NUmEZOkhoSpaL2fPrcb4FkIlbhD3Dp26LlZLM6LkCka34I7d8=",____,0)
;~ ExitApp
;~ reportList:=ParseDataGrid2().data
;~ decryptAll()

gui,main:Default
gui,+hwndguihwnd
WinSetTitle,% "ahk_id " guihwnd,,decryptJpeg_main
;~ ToolTip % guihwnd
return 

exit(){
	ExitApp
}


On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
; dwData = Command
; cbData = String lenght
; lpData = String
	Critical
	global AccNoCol, examDateCol, examNameCol, ChartNoCol, statusCol, loadSavedReportInfo, fastMode, thisReportListIndex, thisAccNo, thisChartNo, reportList, fastReportQ, turboMode, start_ind, reportDir, valid_jpeg_ind, valid_jpeg_k, exit_process
	,AccNoCol, ChartNoCol, examNameCol, examDateCol
	;~ static lastTick
	dwData := NumGet(lParam+0, 0)
	,cbData := NumGet(lParam + A_PtrSize)
	,lpData := NumGet(lParam + 2*A_PtrSize)
	,str := StrGet(lpData)
	
	if (dwData=17){
		try
			j:=jxon_load(str)
		catch e
			return
		;~ MsgBox % exploreobj(j)
		if(j.haskey("start_from")){
			start_ind:=j.start_from
		}else if(j.haskey("reportList")){
			reportList:=j.reportList
			;~ MsgBox % ExploreObj(reportList)
			SetTimer,decryptAll,-1
			
		}else if(j.haskey("reportDir")){
			reportDir:=j.reportDir
		}else if(j.haskey("checkValidJpeg")){
			valid_jpeg_ind:=j.valid_jpeg_ind
			valid_jpeg_k:=j.valid_jpeg_k
			for k,v in j.colVars
				%k%:=v
			SetTimer,checkValidJpeg,-1
		}else if(j.haskey("exit"))
			exit_process:=true
	}

}


decryptAll(){
	global reportList, reportListCount, start_ind, reportDir, ____, decrypted, reportListStatus, exit_process
	reportList:=new DataGridTable(reportList)
	,reportListCount:=reportList.maxindex()
	, start_ind:=start_ind?start_ind:2
	
	
	for k, row in reportList {
		if (k==1)
			continue
		if exit_process
			exitapp
		accNo:=row.getCell("AccNo")
		,chartNo:=row.getCell("ChartNo")
		jpegValid:=false
		if fileexist(jpegPath:=reportDir "\" accNo " " chartNo "\" accNo " " chartNo " 1.jpeg"){ 
			if testJpeg(jpegPath, ""){
				FileRemoveDir,% reportDir "\" accNo " " chartNo
			}else
				jpegValid:=true
		}
		if (jpegValid){
			reportListStatus[k]:=[jpegValid]
			continue
		}
		
		crypt_acc_chart:=__CryptStr(accNo " " chartNo,____)
		FileCreateDir,% reportDir "\" accNo " " chartNo
		noFile:=true
		Loop, Files, % reportDir "\" crypt_acc_chart "\*.jpeg_"
		{
			if !RegExMatch(A_LoopFileName, "is)^(.+) (\d+)\.([^\.]+)", match)
				continue
			if !FileExist(decrypt_path:=reportDir "\" accNo " " chartNo "\" (match1==crypt_acc_chart?(accNo " " chartNo):__CryptStr(match1,____, 0)) " " match2 "." SubStr(match3,1,-1))
				if !r:=Crypt.Encrypt.FileDecrypt(A_LoopFileLongPath, decrypt_path,____,7,6)
					FileDelete,% A_LoopFileLongPath
			noFile:=false
		}
		
		jpegValid:=false
		if fileexist(jpegPath:=reportDir "\" accNo " " chartNo "\" accNo " " chartNo " 1.jpeg"){ 
			if testJpeg(jpegPath, ""){
				FileRemoveDir,% reportDir "\" accNo " " chartNo
				FileRemoveDir,% reportDir "\" crypt_acc_chart
			}else
				jpegValid:=true
		}
		reportListStatus[k]:=[jpegValid]
		;~ ToolTip % k ":" jpegValid
		
		
		if noFile
			FileRemoveDir,% reportDir "\" accNo " " chartNo
		else
			decrypted.push(reportDir "\" accNo " " chartNo)
	}
	
}

OnExit:
for k,v in decrypted
	FileRemoveDir,% v, 1

ExitApp


checkValidJpeg(){
	global valid_jpeg_ind, valid_jpeg_k, reportListCount, reportList, reportDir, ____, AccNoCol, ChartNoCol, examNameCol, examDateCol
		,reportListStatus, reportList, exit_process
	static RetryCount:=[]	
	
	
	valid_jpeg_k++
	 ;~ ToolTip % valid_jpeg_k
	if (valid_jpeg_k>reportListCount){
		send_data("miniPACS", {total_study_count: valid_jpeg_ind})
		return
	}
	
	;~ ToolTip % valid_jpeg_k "," reportListStatus[valid_jpeg_k][1]
	if !IsObject(decryptStatus:=reportListStatus[valid_jpeg_k]){
		if (RetryCount[valid_jpeg_k]="")
			RetryCount[valid_jpeg_k]:=0
		if !(++RetryCount[valid_jpeg_k]>10)
			valid_jpeg_k--
		;~ ShowToolTip("Retry: " valid_jpeg_k ", " reportList[valid_jpeg_k][ChartNoCol], 1000)
		goto checkValidJpegTimer
	}else if !(decryptStatus[1])
		goto checkValidJpegTimer
	
	
	if exit_process
		exitapp
	
	v:=reportList[k:=valid_jpeg_k]
	
	
	AccNo:= v[AccNoCol], ChartNo:= v[ChartNoCol]
	
	
	,d:={study_data:1}
	,d[valid_jpeg_ind]:={AccNo: v[AccNoCol], ChartNo: v[ChartNoCol], ExamName: v[examNameCol], ExamDate: v[examDateCol]}
	,send_Data("miniPACS", d)
	,send_data("miniPACS", {total_study_count: ++valid_jpeg_ind})
	;~ ,ShowToolTip(valid_jpeg_ind ": " v[ChartNoCol], 1000)
	;~ ,valid_jpeg_ind++
	;~ FileAppend,% jxon_dump(d) "`n",log.txt,utf-8-Raw
	
	checkValidJpegTimer:
	settimer,checkValidJpeg,-100
}
