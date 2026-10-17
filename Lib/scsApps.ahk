#include <WinHttpRequest>
#include <binaryIO>
#include <JXON>
#include <Zip>
SetBatchLines,-1
;~ (new scsApps("C:\Users\IDI\Documents\Wnmp\html\scsnake")).sync("FirefoxLogin")

;~ esc::ExitApp

class scsApps {
	;;; fileName(default .exe/.ahk): [is_folder, dropboxUrl, belongToAppName]
	static list:={"searchLab":[0, "", "searchLab"]
						,"AutoNum":[0, "", "AutoNum"]
						,"DigiSign":[1, "", "DigiSign"]
						,"EBMpreload":[1, "", "EBMpreload"]
						,"FirefoxLogin":[1, "", "FirefoxLogin"]
						,"Hotstring Helper":[1, "", "Hotstring Helper"]
						,"ImpaxContextServer":[0, "", "ImpaxContextServer"]
						,"LDCTreport":[1, "", "LDCTreport"]
						,"MammoSR":[1, "", "MammoSR"]
						,"RadTemplate":[1, "", "RadTemplate"]
						,"RisImpaxPolling":[0, "", "RisImpaxPolling"]
						,"TMS reader":[1, "", "TMS reader"]
						,"VFSS3":[1, "", "VFSS"]
						,"VFSS2":[1, "", "VFSS"]
						,"VFSS":[1, "", "VFSS"]
						,"boneage report":[1, "", "boneage report"]
						,"changeSchedule":[1, "", "changeSchedule"]
						,"changeSchedule2":[1, "", "changeSchedule"]
						,"changeSchedule3":[1, "", "changeSchedule"]
						,"changeSchedule4":[1, "", "changeSchedule"]
						,"diffReport":[1, "", "diffReport"]
						,"portalMessage":[1, "", "portalMessage"]
						,"scsPackageManager":[0, "", "scsPackageManager"]
						,"scsnakeUpdate":[0, "", "scsnakeUpdate"]
						,"showLungCAD":[1, "", "showLungCAD"]
						,"simpleRIS":[1, "", "simpleRIS"]
						,"prettyOldHx":[1, "", "simpleRIS"]
						,"simpleRIS_patch":[1, "", "simpleRIS"]
						,"textHotkey":[1, "", "textHotkey"]
						,"updateOpPatho":[1, "", "updateOpPatho"]
						,"urgentReport":[1, "", "urgentReport"]
						,"selectCT":[1, "", "selectCT"]
						,"shiftCT":[1, "", "shiftCT"]
						,"noIdle":[0, "", "noIdle"]
,"ImpaxSearch":[0, "", "ImpaxSearch"]
,"searchOpHx":[0, "", "searchOpHx"]
,"電子簽章":[0, "", "電子簽章"]
,"電子簽章2":[0, "", "電子簽章2"]
,"FirefoxLoginApp":[0, "", "FirefoxLogin"]
,"portallib.ahk": [0, "", "PortalLib"]
,"risimpax.ahk": [0, "", "RisImpax"]
,"AngioConsult":[0, "", "AngioConsult"]
,"Hotstring Lookup":[0, "", "Hotstring Lookup"]
,"noIdle2":[0, "", "noIdle2"]
,"RadMSN":[0, "", "RadMSN"]
,"recordMouseClicks":[0, "", "recordMouseClicks"]
,"ReplyConsultation":[0, "", "ReplyConsultation"]
,"RFA note":[0, "", "RFA note"]
,"RIS helper":[0, "", "RIS helper"]
,"UpDownArrow":[0, "", "UpDownArrow"]
,"值班日誌":[0, "", "值班日誌"]
,"執行住院醫師":[0, "", "執行住院醫師"]
,"病歷審查":[0, "", "病歷審查"]
,"ahkSwitch":[0, "", "ahkSwitch"]
,"uploadSchedule":[0, "", "uploadSchedule"]
,"dicomFetch":[0, "", "dicomFetch"]
,"dutyCSV":[0, "", "dutyCSV"]
,"feedRIS":[0, "", "feedRIS"]
,"GE_Mammo_Script":[0, "", "GE_Mammo_Script"]
,"HotstringFindDuplicate":[0, "", "HotstringFindDuplicate"]
,"HotstringSort":[0, "", "HotstringSort"]
,"IVrecord":[0, "", "IVrecord"]
,"LDCTreport_Fleischner2017":[0, "", "LDCTreport_Fleischner2017"]
,"LDCTreport_Fleischner2017_Full":[0, "", "LDCTreport_Fleischner2017_Full"]
,"OldExamHelper":[0, "", "OldExamHelper"]
,"MammoSR":[0, "", "MammoSR"]
,"MammoSRprint":[0, "", "MammoSRprint"]
,"MammoSRPrintClient":[0, "", "MammoSRPrintClient"]
,"MammoSRPrintServer":[0, "", "MammoSRPrintServer"]
,"MammoSRPrintServerMain":[0, "", "MammoSRPrintServerMain"]
,"MammoSRsend":[0, "", "MammoSRsend"]
,"MammoSRSilentPrint":[0, "", "MammoSRSilentPrint"]
,"NHIfollow":[0, "", "NHIfollow"]
,"NHIform":[0, "", "NHIform"]
,"RisTyper":[0, "", "RisTyper"]
,"RisTyper2":[0, "", "RisTyper2"]
,"showLungCAD_H":[0, "", "showLungCAD_H"]
,"showLungCAD_J":[0, "", "showLungCAD_J"]
,"getFullPatho":[0, "", "getFullPatho"]
,"matchPathoList":[0, "", "matchPathoList"]
,"searchPatho":[0, "", "searchPatho"]
,"fillPath":[0, "", "fillPath"]
,"angioconsult 2":[0, "", "angioconsult 2"]
,"replyERconsult":[0, "", "replyERconsult"]
,"TMS reader GUI":[0, "", "TMS reader GUI"]
,"TMS reader revising":[0, "", "TMS reader revising"]
,"TMS reader":[0, "", "TMS reader"]
						, "__package_list":[0, "", ""]
						, "__utils":[1, "", ""]}
						
	static proxy:=["", "proxy.hospital-n.local:3128", "10.0.0.1:8118"]
	static urls:=["http://127.0.0.1/scsnake/", "http://10.0.0.1/scsnake/", "http://10.0.0.1/scsnake/", "http://127.0.0.1:8000/scsnake/"] 
	
	__New(local_home=""){
		this.prefer_proxy:=""
		,this.prefer_url:=""
		,this.local_home:=local_home=""?A_MyDocuments "\scsnake\":(local_home (local_home~="\\$"?"":"\"))
		,this.hasSynced:=[]
		,this.pid:=DllCall("GetCurrentProcessId")
		,this.ProcessPath:=this.getProcessPath(this.pid)
		,this.createdDir(this.local_home)
		
		
		,this.has7z := FileExist(_7zpath:=PathConcat(this.local_home, "utils", "7z", "7z.exe")) || (_7zpath:=StdoutToVar_CreateProcess("where 7z")) ? _7zpath: ""
		,this.hasRobocopy := (robotpath:=StdoutToVar_CreateProcess("where robocopy"))? robotpath: ""
		,this.hasLockHunter :=FileExist(LockHunterPath:=PathConcat(this.local_home, "utils", "LockHunter", "LockHunter.exe")) ? LockHunterPath: ""
		,this.hasUtils:= this.has7z && this.hasRobocopy && this.hasLockHunter
		
		for _, p in this.proxy
			for _, u in this.urls {
				url:=u "package_info.json"
				if !this.connect(url, post:="", header:="", {proxy: proxy, timeout: 3})
					continue
				
				try 
					this.package_list:=JXON_load(RemoveBOM(post))
				catch 
					continue
				
				
				if (!this.hasUtils && this.connect(u "utils.zip", post:="", header:="",  proxy, zipFile:=this.local_home "utils.zip")){
					this.createdDir(outDir:=PathConcat(this.local_home, "utils"))
					,Unz(zipFile,outDir)
					FileDelete,% zipFile
					this.has7z:=PathConcat(outDir, "7z", "7z.exe")
					,this.hasLockHunter:=PathConcat(outDir, "LockHunter", "LockHunter.exe")
				}
					
				this.prefer_proxy:=p
				,this.prefer_url:=u
				
				break,2
				
			}
		
		if !this.package_list
			for _, p in this.proxy
				if this.connect(this.list["__package_list"][1], post:="", header:="", proxy){
					try
						this.package_list:=JXON_load(RemoveBOM(post))
					catch 
						continue
					
					if (!this.hasUtils && this.connect(this.list["__utils"][1], post:="", header:="",  proxy, zipFile:=this.local_home "utils.zip")){
						this.createdDir(outDir:=PathConcat(this.local_home, "utils"))
						,Unz(zipFile,outDir)
						FileDelete,% zipFile
						this.has7z:=PathConcat(outDir, "7z", "7z.exe")
						,this.hasLockHunter:=PathConcat(outDir, "LockHunter", "LockHunter.exe")
					}
					
					this.prefer_proxy:=p
					,this.prefer_url:="DROPBOX/"
					break
				}
				
		if !this.package_list
			MsgBox % "Can't download package list!"
	}
	
	sync(appName){
		if this.hasSynced.haskey(dependency)
			return
		
		if (this.package_list.haskey(appName) || (this.package_list.haskey(appName ".exe") && (appName:=appName ".exe"))){
			for k, dependency in this.package_list[appName][2]
				this.sync(dependency)
			
			is_folder := this.package_list[appName][1]
			,createdDir:=[]
			
			,safeAppName:=RegExReplace(appName, "\W", "_")
			,is_folder ? (createdDir[this.createDir(appHome:=PathConcat(this.local_home, appName))]:=1) : appHome:=this.local_home
			,createdDir[this.createDir(appTempHome:=this.local_home (now:=a_now) "_update_" safeAppName "\", "+H")]:=1
			
			,ext:=(appName~="i).\w+$"?"":".exe")

			if !this.hasUpdate(appName ext, appTempHome, is_folder)
				return this.deleteDir(createdDir)
			
			is_folder ? this.connect(this.prefer_url "_zip_folder/" appName ".zip", post:="", header:="", this.prefer_proxy, zipFile:=PathConcat(appTempHome, appName ".zip"))
				: this.connect(this.prefer_url appName ext, post:="", header:="", this.prefer_proxy, PathConcat(appTempHome, appName ext))
				
			if (is_folder){
				try {
					if this.has7z
						RunWait,% commands(this.has7z,"x","-mmt8","-y", "-aoa", zipFile),% appTempHome,Hide
					else
						Unz(zipFile, appTempHome)
					FileDelete,% zipFile
				}catch e {
					clipboard:=errorMsg:=exploreobj(e)
					MsgBox,4112,% appName, % "Unzip error for " zipFile "`n`n" errorMsg, 5
					unzipError:=true
				}
				
			}	
			
			this.Move(appTempHome)
		
			,this.deleteDir(appTempHome)
			
			,this.checkNeedUnzip(this.local_home appName)
			
			,this.hasSynced[appName]:=1
		}
		
	}
	
	checkNeedUnzip(appDir){
		Loop,files,% PathConcat(appDir, "*.version"),F
		{
			fileread,ver,% A_LoopFileLongPath
			if RegExMatch(ver, "i)unzip=([^\r\n]*)", m) {
				Loop,parse,m1,|
					if FileExist(zipFile:=PathConcat(A_LoopFileDir, A_LoopField)){
						if this.has7z
							RunWait,% commands(this.has7z,"x","-mmt8","-y", "-aoa", zipFile),% A_LoopFileDir,Hide
						else
							Unz(zipFile, A_LoopFileDir)
						FileDelete,% zipFile
					}
			}
		}
	}
	
	Move(appTempHome){
		len:=StrLen(appTempHome)+1
		,thisPath:=this.getProcessPath(thisPid:=this.pid)
			
		Loop,Files,% appTempHome "*",FD
		{
			if !FileExist(localFile:=this.local_home SubStr(A_LoopFileLongPath, len))
				continue
			if(localFile=thisPath){
				killSelf:=true
				continue
			}
			this.getProcessId(localFile, true)
			if this.hasLockHunter
				run,% commands(this.hasLockHunter, "-k", "-sm", "-x", localFile),,Hide
		}
		
		args:=this.getArgs()
		
		,localhome:=this.local_home
		
		if(killSelf){
			cmd=
			(LTrim
			TITLE Updating...
			@echo off
			taskkill /PID %thisPid%  /F /T
			xcopy "%appTempHome%" "%localhome%" /c /q /i /s /e /k /h /y
			start "" %args% 
			rd "%appTempHome%" /S /Q
			(goto) 2>nul & del "`%~f0"
			)
			fileappend,% cmd,% updateCmd:=localhome "\" pid a_tickcout  "update.bat",cp0
			Run,%updateCmd%,,Hide
			
		}else{
			if this.hasRobocopy
				RunWait,% commands("robocopy", appTempHome, this.local_home, "/MOVE","/E","/COPYALL","/NP","/R:0","/W:0"),,Hide
			else{
				RunWait,% commands("xcopy", appTempHome, this.local_home, "/c","/q","/i","/s","/e","/k","/h","/y"),,Hide
				Run,% commands("rd", appTempHome, "/S /Q"),,Hide
			}	
			
		}
		
	}
	
	getArgs(){
		args:=""
		ProcessPath:=this.getProcessPath(this.pid)
		SplitPath,A_ScriptName,,,,scriptName
		
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
		
		return args
	}
	
	getProcessPath(pid){
		for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ProcessId = " pid "")
			return process.ExecutablePath
	}
	
	getProcessId(ProcessPath, terminate=false){
		ret:=[]
		for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath = '" ProcessPath "'")
			ret.push(process.processId)
			,terminate? process.terminate(): 0
		for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath LIKE '" ProcessPath "%'")
			ret.push(process.processId)
			,terminate? process.terminate(): 0
		return ret
	}
	
	hasUpdate(appFileName, appTempHome, is_folder){
		static ext:=".version_"
		versionUrl:=this.prefer_url appFileName ext
		if this.package_list.haskey(appFileName)
			remoteVersionTxt:=this.package_list[appFileName][3]
		else if remoteVersionFile:=this.connect(versionUrl, post:="", header:="", this.prefer_proxy, PathConcat(appTempHome, appFileName ext))
			fileread,remoteVersionTxt,% remoteVersionFile
		
		if FileExist(localVersionFile:=PathConcat(this.local_home, appFileName ext)) 
			fileread,localVersionTxt,% localVersionFile
		
		localVersion:=Trim(localVersionTxt), remoteVersion:=Trim(remoteVersionTxt)
		if (localVersion="" || remoteVersion="" ||  checkUpdate_compareVersion(remoteVersion, localVersion)>0 ){
			if remoteVersion && !FileExist(remoteVersionFile:=PathConcat(appTempHome, appFileName ext)) {
				FileAppend,% Trim(remoteVersionTxt),% remoteVersionFile, utf-8-Raw
				FileSetAttrib,+H,% remoteVersionFile
			}
			return true
		}
			
	}
	
	deleteDir(dir_dict){
		for dir, _ in dir_dict 
			if (dir!="" && InStr(FileExist(dir),"D"))
				FileRemoveDir,% dir,1
	}
	
	createDir(dir, setAttrib=""){
		if !InStr(FileExist(dir),"D"){
			FileCreateDir,% dir
			FileSetAttrib,% setAttrib,% dir,1,0
			return dir
		}
	}
	
	connect(url, ByRef post, ByRef header, options:="", DownloadTo="", setAttrib=""){
		if IsObject(url) {
			for _,u in url 
				if ret:=this.connect(u, post, header, proxy, DownloadTo, setAttrib)
					return ret
			return false
		}
		
		if InStr(url, "DROBOX/")=1 {
			RegExMatch(url, "[^\/]+$", fileName)
			index:=1
			if (fileName~="i).version_$")
				fileName:=SubStr(fileName,1,-9), index:=2
			if this.list.haskey(fileName)
				url:=this.list[fileName][index] fileName
			else if this.list.haskey(fileNameNoExt:=RegExReplace(fileName, "\.\w+$", ""))
				url:=this.list[fileNameNoExt][index] fileName
			else
				return false
		}
		
		opt:=""
		if IsObject(options)
			for k,v in options
				opt:=k ": " v "`n"
		else if (options+0==options) && (options!="")
			opt:="Timeout: " options
		else if (options!="")
			opt:="Proxy: " options
		
		InStr(opt, "Timeout") ? WinHttpRequest(url,post:="",header:="","binary`n" opt) : HttpRequest(url,post:="",header:="","binary`n" opt)
		regexmatch(header," (\d+)",code), regexmatch(header,"(?<=Content-Length: )\d+",len)
		if (code1<200 || code1>=300)
			;~ OutputDebug % "Cannot download " url
			return false
		else if (DownloadTo){
			BinWrite(DownloadTo, post, len)
			if FileExist(DownloadTo)
				FileSetAttrib,% setAttrib,% DownloadTo
			return DownloadTo
		}
		return true
	}
	
	is_match(fileName){
		return this.list.haskey(fileName)?((a:=this.list[fileName][3])?a:fileName):""
	}	
}


collectMyAppsInDrives(){
	DriveGet, all, List
	DriveGet, usb, List, removable
	DriveGet, cd, List, cdrom
	All.=usb
	loop,parse,cd
		StringReplace,all,all,% a_loopfield,,all
	loop,parse,usb
		StringReplace,all,all,% a_loopfield,,all
	StringReplace,all,all,A,,all
	StringReplace,usb,usb,A,,all
	;~ MsgBox % All
	Loop,Parse,All
		driveInfo:=collectMyApps(A_LoopField ":", A_MyDocuments "\.scsAppInfo")
	
	Loop,Parse,usb
		usbInfo:=collectMyApps(A_LoopField ":", A_LoopField ":\.scsAppInfo")
	
	
}

;~ collectMyApps(A_MyDocuments)
;~ esc::ExitApp
collectMyApps(dir, logPath=""){
	global scsApps
	ret:=[]
	
	if !scsApps
		scsApps:=new scsApps
	if logPath=
		logPath:=A_MyDocuments "\_scsAppInfo"
	
	l:=StdoutToVar_CreateProcess("where /R """ dir """ *.exe *.ahk")
	
	Loop,Parse,l,`n
	{
		SplitPath,A_LoopField,fileName,filedir,ext
		
		if matchApp:=scsApps.is_match(SubStr(fileName,1,(-1)*StrLen(ext)-1)) {
			if !ret.haskey(matchApp)
				ret[matchApp]:={}
			ret[matchApp]["is_folder"]:=!! scsApps.list[matchApp][1]
			
			if !ret[matchApp].haskey("path")
				ret[matchApp]["path"]:=[]
			
			if (ret[matchApp]["is_folder"]) && (filedir~="i)" matchApp "$")
				target:=filedir
			else
				target:=A_LoopField
			
			if !hasVal(ret[matchApp]["path"], target)
				ret[matchApp]["path"].push(target)
		}
	}
	FileDelete,% logPath
	FileAppend,% jxon_dump(ret),% logPath,utf-8-Raw
	FileSetAttrib,+H,% logPath
	if InStr(logPath, "_scsAppInfo"){
		filemove,% logPath,% RegExReplace(logPath, "i)_scsAppInfo", ".scsAppInfo")
		StdoutToVar_CreateProcess(commands("type", logPath, ">", RegExReplace(logPath, "i)_scsAppInfo", ".scsAppInfo")))
		FileDelete,% logPath
	}
		
	return ret
}