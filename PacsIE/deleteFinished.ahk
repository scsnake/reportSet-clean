#MaxMem 4095
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

;~ #persistent
;~ #notrayicon
setbatchlines,-1

; Does not use CH_RIS — opt out of owning a local (IE-polling) CH_RIS. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <CryptFileRead>
#Include %A_ScriptDir%
#include jpegDirName.ahk

#SingleInstance,Off
DetectHiddenWindows,on
ComObjError(false)

reportdir:=A_MyDocuments "\feedRIS\"

if CryptFilePW()
	ExitApp


	;~ reportList:=[]
	reportListOriginal:=new DataGridTable(parseTable(clipboard))
	statusCol:=reportListOriginal.getColNo("status")
	,ChartNoCol:=reportListOriginal.getColNo("ChartNo")
	,AccNoCol:=reportListOriginal.getColNo("AccNo")
	,ExamDateCol:=reportListOriginal.getColNo("ExamDate")
	,ExamNameCol:=reportListOriginal.getColNo("ExamName")
	,reportvsCol:=reportListOriginal.getColNo("ReportVS")
	,deleted:=0
	;~ ,reportList.push(reportListOriginal[1])
	for k,v in reportListOriginal.data
		;~ if (v[statusCol]!="已發報告") && (substr(v[chartNoCol],1,1)!="Y" || !(v[ExamNameCol]~="i)^chest|^abdomen|spine")){
		if (k==1){
			continue
		}else if (v[statusCol]="已發報告"){
			filename1:=v[AccNoCol] " " v[ChartNoCol]
			,filename2:=__CryptStr(accNo " " chartNo,____)
			,file1:=reportdir filename1 ".txt"
			,file2:=reportdir filename2 ".txt"
			,dir1:=reportdir filename1
			,dir2:=reportdir filename2
			if FileExist(file1) || FileExist(file2) || FileExist(dir1) || FileExist(dir2) {
				FileDelete,% file1 
				FileDelete,% file2 
				FileRemoveDir,% dir1,1
				FileRemoveDir,% dir2,1
				deleted++
			}
		}
		
	MsgBox,0,,% "Deleted: " deleted,5
	ExitApp
		