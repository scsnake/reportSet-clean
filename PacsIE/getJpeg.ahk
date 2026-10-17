#MaxMem 4095
#NoTrayIcon
#Persistent
SetBatchLines,-1

DetectHiddenWindows,on
#SingleInstance,Off
#include <portallib>
#include <JXON>
#include <ParseArg>
#include <WM_COPYDATA>
#include <CryptFileRead>
#Include %A_ScriptDir%\..\Lib\LogRetention.ahk
#Include %A_ScriptDir%
#include jpegDirName.ahk
;~ OnExit,OnExit
SplitPath,A_ScriptFullPath,,,,fileName 
FormatTime, getJpegLogDate,, yyyyMMdd
getJpegLogFile := A_ScriptDir "\getJpeg_" getJpegLogDate ".log"
LogRetention_DeleteFilesOlderThan(A_ScriptDir, "getJpeg_*.log")
LogRetention_DeleteFilesOlderThan(A_ScriptDir, "getJpeg.log")
OnMessage(0x8001, "exitNow")
,args:=ParseArg()
,arg:=args[args.maxindex()]
gui,+hwndguihwnd

;~ clipboard:=arg
;~ MsgBox % arg

;~ ExitApp
;~ ToolTip % arg

;~ arg=
;~ (
;~ )

;~ ToolTip % clipboard:=arg
try {
	info:=JXON_load(arg)
}catch{
	MsgBox,,,% "getJpeg: info json error`n`n" arg,10
	ExitApp
}


for k,v in info
	%k%:=v
;~ MsgBox % ____
WinSetTitle,ahk_id %guihwnd%,,% title
hwnd+=0
SetTimer,exit,-60000
;~ SetTimer,checkMain,1000

if CryptFilePW()
	ExitApp

while StrLen(chartNo)<7
	chartNo:="0" chartNo

AccNoInfo :={}
,downloadedAccNo:={}

if !(chartNo~="i)^A")
	PacsWebLoginNew(AccNoArr[1], chartNo, loginId, loginPw)
for k, AccNo in AccNoArr {
	outputDict:={study_data:1}
	,i:=rowNo[k]
	,ExamDate:=ExamDateArr[k]
	,examName:=examNameArr[k]
	,outputDict[i-2]:={AccNo: "" AccNo, ChartNo: "" chartNo, expected_image_count:[]}
	,dict:={}, dictEmpty:=true, downloadNothing:=true
	, crypt_dir:=jpegDirName(reportdir, AccNo , chartNo)
	
	,downloadRet:=0
	
	if (AccNoInfo.haskey(accno)){
		dict:=AccNoInfo[AccNo]
		FileCreateDir,% crypt_dir
		Loop,files,% downloadedAccNo[AccNo] "\" __CryptStr(AccNo " " chartNo,____) " *.jpeg?"
			FileCopy,% A_LoopFileLongPath,% crypt_dir, 1
		
	}else{
		output:=PacsWebInfoFlatten(PacsWebInfo(output,AccNo,chartNo,loginId,loginPw))
		
		,max:=output.maxindex()
		;~ MsgBox % max
		;~ clipboard:=exploreobj(output)
		
		
		for k,v in output {
			if RegExMatch(v.objectUID,"[^\d\.]")
				continue
			dict[AccNo]:=k, dictEmpty:=false
			
			
			if InStr(examName,"Spine") && !(examName~="i)\b(CT|MRI?)\b")
				downloadRet+=initThread(v.url, AccNo,chartNo, AccNo,ChartNo, max-k+1, i), downloadNothing:=false
			else
				downloadRet+=initThread(v.url, AccNo,chartNo, AccNo,ChartNo, k, i), downloadNothing:=false
			
		}
		
		AccNoInfo[AccNo]:=dict
		;~ ,downloadedAccNo[AccNo]:=crypt_dir
		
	}
		
	if !dictEmpty
		outputDict[i-2].expected_image_count.push(dict)
	else
		outputDict[i-2].expected_image_count[AccNo]:=0
	;~ goto continueLoop
	dict:={}, dictEmpty:=true
	
	
	if(monitorsCount>2 && !noOldFilm){
		anyPriorImage:=0, priorImage:={}
		
		if (!PacsHx)
			PacsHx:=getPacsHx(sid,chartNo)
		
		
		for k,v in PacsHx {
			if relatedExam(v.ExamName,examName) && (regexreplace(v.ExamDate,"\D","")<=substr(regexreplace(examDate,"\D",""),1,8)) && (strlen(oldAccNo:=v.AccessNo)>=11) {  ;may catch exam on the same day
				
				if regexreplace(v.AccessNo,"i)^[a-z]+","")>=regexreplace(AccNo,"i)^[a-z]+","") && regexreplace(v.AccessNo,"\d+$","")=regexreplace(AccNo,"\d+$","")
					continue
				
				;~ WBp[thisGuiInd].Navigate("about:blank")
				;~ WBp[thisGuiInd].Navigate(PacsWebUrl(v.AccessNo,thisStudy[chartNoCol],loginId,loginPw))
				anyPriorImage:=1
				,oldChartNo:=v.ChartNo
				
				if (AccNoInfo.haskey(oldAccNo)){
					dict:=AccNoInfo[oldAccNo]
					FileCreateDir,% crypt_dir
					Loop,files,% downloadedAccNo[oldAccNo] "\" __CryptStr(OldAccNo " " OldchartNo,____) " *.jpeg?"
						FileCopy,% A_LoopFileLongPath,% crypt_dir, 1
				}else{
					output:=PacsWebInfoFlatten(PacsWebInfo(output, oldAccNo,oldChartNo,loginId,loginPw))
					
					,loadedPicCount[ oldAccNo " " oldChartNo ]:=output.maxindex()
					,max:=output.maxindex()
					
					for q,r in output {
						if RegExMatch(r.objectUID,"[^\d\.]")
							continue
						
						dict[oldAccNo]:=q, dictEmpty:=false

						if InStr(examName,"Spine") && !(examName~="i)\b(CT|MRI?)\b")
							downloadRet+=initThread(r.url, oldAccNo, oldChartNo, AccNo, chartNo, max-q+1, i), downloadNothing:=false
						else
							downloadRet+=initThread(r.url, oldAccNo, oldChartNo, AccNo, chartNo, q, i), downloadNothing:=false
						
					}
					
					AccNoInfo[oldAccNo]:=dict
					;~ ,downloadedAccNo[oldAccNo]:=crypt_dir
				}
					
		
				break
			}
		}

	}
	if !dictEmpty
		outputDict[i-2].expected_image_count.push(dict)
	
	if (downloadRet<0){
		FileAppend,% "getJpeg error: " accNo " " chartNo "`n",%getJpegLogFile%,utf-8
		isEmpty:=true
		Loop,file,% crypt_dir "\*.jpeg"
		{
			isEmpty:=false
			break
		}
		if isEmpty
			FileRemoveDir,%  crypt_dir
	}
	
	;~ Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_miniPACS"), dwData, jxon_dump(outputDict))
}

ExitApp
return 

initThread(url,oldAccNo,oldChartNo, AccNo,chartNo, k, i){
	global loginId, loginPw, reportdir, PicWidth, downloadedAccNo, ____, forceRedownload, downloading
			
	if !forceRedownload && (FileExistValid(jpegFile:=jpegDirName(reportDir, AccNo, chartNo, oldAccNo, oldChartNo, k)) && isValidJpeg(jpegFile)) 
		|| FileExistValid(jpegFile:=jpegDirName(reportDir, AccNo, chartNo, oldAccNo, oldChartNo, k, ".jpeg_"))
		return
			
	
	downloading:=true
	;~ PacsWebLoginNew(oldAccNo, oldChartNo, loginId, loginPw)
	ret:=PacsWebDownloadJpeg2(url,oldAccNo,oldChartNo,f:=__CryptStr(OldAccNo " " OldchartNo,____) " " k ".jpeg",d:=jpegDirName(reportDir, AccNo, chartNo),PicWidth*2,loginId,loginPw,3,100,1, "")
	
	if fileexist(d "\" f){
		__CryptFile(d "\" f, d "\" f "_", ____)
		;~ MsgBox % ____
		;~ MsgBox % __CryptStr(AccNo " " chartNo,____)
		;~ MsgBox % accNo "," chartNo "," OldAccNo "," OldchartNo
		;~ MsgBox % d "\" f
		,downloadedAccNo[OldAccNo]:=d
		FileDelete,% d "\" f
	}
	downloading:=false
	return ret
}


exit:
;~ threadPoolCount--
if (downloading && downloading_extend<5){
	downloading_extend:=downloading_extend?downloading_extend+1:1
	SetTimer,exit,-10000
}else
	exitapp
return


checkMain:
If !WinExist("ahk_id " hwnd)
	ExitApp
return


relatedExam(exam,thisExam){
	if (exam=thisExam)
		return 1
	else if regexmatch(exam,"is)chest\b.+?view") && regexmatch(thisExam,"is)chest\b.+?view")
		return 1
	
	return 0
}


OnExit:
Pause
