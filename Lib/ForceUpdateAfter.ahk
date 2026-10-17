#include <WinHttpRequest>
#include <SetTimerF>
#include <binaryIO>
#include <checkUpdate_utils>
#include <Zip>
#include <ParseArg>

__MenuAboutHandler:
ForceUpdateAfter("","",true)
return

__show_about_info(info, remoteVersion){
	gui,__show_about_info:new,+ToolWindow +hwnd__show_about_info_hwnd +OwnDialogs
	gui,Font,s12,Verdana
	gui,Add,Text,,% info
	if(remoteVersion!="")
		gui,Add,button,g__show_about_info_button,% "Update to " remoteVersion
	gui,Show,Center,Script Info - %a_scriptname%
}

__show_about_info_button:
ForceUpdateAfter()
return

__echoKiller(wParam, lParam, msg, hwnd){
	PostMessage,0x12544,,,,% "ahk_id " hwnd
}

ForceUpdateAfter(date="", app="", AboutMenuInvoke=false, ByRef scsApps=""){
	static __about_info_menu_added:=false
	
	if updateZipFileName=
		updateZipFileName:=storedupdateZipFileName
	else
		storedupdateZipFileName:=updateZipFileName
	
	if(!__about_info_menu_added){
		Menu, Tray, Add 
		Menu, Tray, Add, About, __MenuAboutHandler , P1
		
		OnMessage(0x12543, "__echoKiller")
		__about_info_menu_added:=true
	}
	
	while StrLen(date)<14
		date.="0"
	
	now:=a_now

	if(now<date) && !AboutMenuInvoke
		if DateDiff(date, now)>7
			return
	
	scriptName:=RegExReplace(A_ScriptName, "i)(\.\w+)$", "") 
	
	if updateZipFileName=
		updateZipFileName:=scriptName ".zip"
	
	urlProxyOptions:=[]
	,urls:=""
	for k,v in updatebaseURL
		urlProxyOptions.push(v "_zip_folder/" updateZipFileName)
		,urls.=v
		
		
	for k,v in moreURL {
		if !InStr(v, "://")
			v:="http://" v
	
		if (v~="i).zip$")
			for x, y in updateProxy
				urlProxyOptions.push([v, y])
		else
			for x, y in updateProxy
				urlProxyOptions.push([v (v~="\/$"?"":"/") updateZipFileName, y])
		
		urls.=v "`n"
	}
	
	
	;~ SplitPath,A_ScriptDir,,fileDir
	Loop,Files,% A_ScriptDir "\*_update_" RegExReplace(scriptName, "\W", "_"),D
		FileRemoveDir,% A_LoopFileLongPath,1
	
	FileCreateDir,% localFolder:=A_ScriptDir "\" now "_update_" RegExReplace(scriptName, "\W", "_")
	FileSetAttrib,+H,% localFolder,2,0
	
	ToolTip % "Get update info ... "
	validURL:=""
	success:=false

	;~ goto ttest
	;;;;;; get version number		
	;~ try
		for k,urlProxy in urlProxyOptions {
			if IsObject(urlProxy)
				url:=urlProxy[1], proxy:=urlProxy[2]
			else
				url:=urlProxy, proxy:=""
			
			proxy:=(proxy=""?"":"`nProxy: " proxy)
			,url:=RegExReplace(url, "i).zip$", ".version_")
			,WinHttpRequest(url,post:="",header:="","Timeout: 1`nbinary" proxy)
			,regexmatch(header," (\d+) ",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
			if (code1<200 || code1>=300){
				OutputDebug % "Cannot download " url
				continue
			}else {
				BinWrite(downloadFile:=localFolder "\" scriptName ".version_", post, len)
				,validURL:=urlProxy
				FileSetAttrib,+H,% downloadFile
				break
			}
		}
	ToolTip
	if (validURL){
		;;; parse .version_ file
		fileRead,currentVersion,% A_ScriptDir "\" scriptName ".version_"
		fileRead,remoteVersion,% localFolder "\" scriptName ".version_"
		currentVersion:=Trim(currentVersion), remoteVersion:=Trim(remoteVersion)
		if !(currentVersion="" || remoteVersion="" ||  checkUpdate_compareVersion(remoteVersion, currentVersion)>0 ) && !AboutMenuInvoke {
			ToolTip
			goto forceUpdateEnd
		}
		
		newUrlProxyList:=[validURL]
		for k,v in urlProxyOptions
			newUrlProxyList.push(v)
		urlOptions:=newUrlProxyList
		
	}
	
	if (AboutMenuInvoke){
		info:="Author: scsnake@gmail.com`n`nCurrent version: " (currentVersion=""?"?":currentVersion)
		SetTimerF("__show_about_info", -1, [info, validURL&&checkUpdate_compareVersion(remoteVersion, currentVersion)>0?remoteVersion:""])
		goto forceUpdateEnd
	}
	
			
	if (now<date){
		optionalUpdate:=true
		MsgBox, 131108,% scriptName ,% "Found new version, update now?",30
		IfMsgBox,No 
			goto forceUpdateEnd
		
	}
	
	;~ try
		for k,urlProxy in urlProxyOptions {

			if IsObject(urlProxy)
				url:=urlProxy[1], proxy:=urlProxy[2]
			else
				url:=urlProxy, proxy:=""

			proxy:=(proxy=""?"":"`nProxy: " proxy)
			
			
			,WinHttpRequest(url,post:="",header:="","Timeout: 1`nbinary" proxy)
			,regexmatch(header," (\d+) ",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
			if (code1<200 || code1>=300){
				OutputDebug % "Cannot download " url
				continue
			}else {
				BinWrite(downloadFile:=localFolder "\" scriptName ".zip", post, len)
			}
			
			
			FileCreateDir,% unzipDir:=localFolder "\_zip_folder\"
			
			try
				Unz(downloadFile, unzipDir)
			catch e {
				clipboard:=errorMsg:=exploreobj(e)
				MsgBox,4112,% scriptName, % "Unzip error for " downloadFile "`n`n" errorMsg, 5
				unzipError:=true
				
				goto forceUpdateEnd

			}
			
			success:=true
			MsgBox,131120,% scriptName, % "This program will exit and update... ", 10
			
			unzipped_files := unzipped_folders := 0
			,subdir:=""
			Loop,Files,%unzipDir%*,FD
				if InStr(FileExist(subdir:=A_LoopFileLongPath), "D")
					unzipped_folders+=1
				else
					unzipped_files+=1
			
			if (unzipped_folders=1 && unzipped_files=0)
				unzipDir := subdir
			
			unzipDir:=RegExReplace(unzipDir, "\/$", "")
			filemove,% localFolder "\" scriptName ".version_", % unzipDir "\" scriptName ".version_",1		
			
			thisPid:=DllCall("GetCurrentProcessId")
			
			,args:=""
			winget,ProcessPath,ProcessPath,% "ahk_id " A_ScriptHwnd
			if(ProcessPath="")
				ProcessPath:=GetModuleFileNameExW(thisPid)
			
			if FileExist(exeFile:=A_ScriptDir "\" scriptName ".exe") {
				if (exeFile=A_ScriptFullPath && A_IsCompiled)  
					args:="""" exeFile """ " 
				else if FileExist(ahkFile:=A_ScriptDir "\" scriptName ".ahk") 
					args:="""" ProcessPath """ """ ahkFile """ " 
				else 
					args:="""" ProcessPath """ "
			}else if FileExist(ahkFile:=A_ScriptDir "\" scriptName ".ahk") {
				args:="""" ProcessPath """ """ ahkFile """ " 
			}
			
			for k,v in ParseArg(false)
				args.= """" v """ "
			
			
			cmd1=
			(LTrim
			TITLE Updating...
			@echo off
			
			)
			cmd2:="taskkill /PID " thisPid " /F /T`n"
			cmd3=
			(Ltrim
			xcopy "%unzipDir%" "%A_ScriptDir%" /c /q /i /s /e /k /h /y
			
			)
			cmd4:="start """" " args "`n"
			cmd5=
			(LTrim
			rd "%localFolder%" /S /Q
			(goto) 2>nul & del "`%~f0"
			
			)
			fileappend,% fullCmd:=cmd1 cmd2 cmd3 cmd4 cmd5,% updateCmd:=fileDir "\" now "update.bat",cp0
			Run,%updateCmd%,,Hide
			
			break
		}
	
	forceUpdateEnd:
	if (AboutMenuInvoke){
		return
	}
	else if(unzipError){
	
	}
	else if(optionalUpdate){
		FileRemoveDir,% localFolder,1
	}
	else if (!success){		
		MsgBox, 4112,% scriptName, % "Cannot update automatically, try to download manually from:`n" urls, 30
		;~ pwb:=ComObjCreate("InternetExplolrer.Application")
		;~ pwb.NAvigate()
		FileRemoveDir,% localFolder,1
		
	}
	ToolTip
	ExitApp
	return -1
}