/*
	File Structure 
	
	targetFolderUrl : files and folder, FOLDERNAME.version
	OR
	targetFileUrl : single file, FILENAME.version (filename includes extension)
	
	
	.version File 
	
	FILENAMEorPATH_TO_BE_UPDATED1 (omit if single file)
	?00000000000000000000000000000000 (optional)
	FILENAMEorPATH_TO_BE_UPDATED2 (optional)
	?00000000000000000000000000000000 (optional)
	
	[OLDER_VERSION] (optional)
	FILENAMEorPATH_TO_BE_UPDATED1 (omit if single file)
	?00000000000000000000000000000000 (optional)
	FILENAMEorPATH_TO_BE_UPDATED2 (optional)
	?00000000000000000000000000000000 (optional)
	
	
*/
#include <MD5_File>
#include <binaryIO>
#include <ProcessList>
#include <URLDownloadToVar>
#include <NoTrayOrphans>
#include <checkUpdate_utils>
#include <Zip>
;~ #include <RelToAbs>

_scs_sync(){
	if FileExist(path:=A_ScriptDir "\scsnakeUpdate.exe")
		|| FileExist(path:=A_ScriptDir "\..\scsnakeUpdate.exe")
		|| FileExist(path:=A_MyDocuments "\scsnakeUpdate.exe")
		|| FileExist(path:=A_MyDocuments "\scsnake\scsnakeUpdate.exe"){
		path:=GetFullPath(path)
		run % """" path """ """ A_ScriptFullPath """"
	}
}

;~ FileDelete,F:\scripts\radiology\pacsie\simpleRIS.version
;~ FileDelete,F:\scripts\radiology\pacsie\lastUpdate_simpleRIS
;~ scs_sync("", "F:\scripts\radiology\pacsie\simpleRIS.exe", 0, 3, 0, 1, 1)
;~ ExitApp
scs_update(name, base_url, localFolderFile, is_folder){
	if(is_folder){
		if !InStr(FileExist(localFolderFile), "D")
			FileCreateDir,% localFolderFile
		if !FileExist(p:=PathCombine(localFolderFile, name ".version"))
			FileAppend,,% p, utf-8
		scs_sync([base_url (base_url~="\/$"?"":"/") name "/"], localFolderFile, 0, 3, 0, 0, 1, 1)
	}else{
		SplitPath,localFolderFile,,dir
		if !InStr(FileExist(dir), "D")
			FileCreateDir,% dir
		if !FileExist(p:=localFolderFile)
			FileAppend,,% p, utf-8
		scs_sync([base_url (base_url~="\/$"?"":"/") name], p, 0, 3, 0, 0, 1, 0)
	}
}

update_self(url){
	SplitPath,A_ScriptDir,,fileDir
	FileCreateDir,% localFolder:=A_ScriptDir "\" a_now "_update"
	;~ URLDownloadToFile,% url,% downloadFile:=localFolder "\" A_ScriptName
	httprequest(url,post:="",header:="","binary`nProxy: proxy.hospital-n.local:3128")
	regexmatch(header," (\d+) ",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
	if (code1<200 || code1>=300){
		MsgBox % "Download error !"
		return
	}else
		BinWrite(downloadFile:=localFolder "\" A_ScriptName, post, len)
	lastUpdate:=fileDir "\lastUpdate_" A_ScriptName
	cmd1=
	(LTrim
	TITLE Updating...
	@echo off
	)
	cmd2:="taskkill /IM """ a_scriptname """ /F`n"
	cmd3=
	(Ltrim
	xcopy "%localFolder%" "%fileDir%" /c /q /i /s /e /k /h /y
	echo %now% > "%lastUpdate%"
	attrib +h "%lastUpdate%" 
	)
	cmd4:="start """" """ A_ScriptFullPath """`n"
	cmd5=
	(LTrim
	rd "%localFolder%" /s /q
	(goto) 2>nul & del "`%~f0"
	)
	fileappend,% fullCmd:=cmd1 cmd2 cmd3 cmd4 cmd5,% updateCmd:=fileDir "\" now "update.bat",cp0
	Run,%updateCmd%,,Hide
}

;~ scs_sync("", "D:\Users\raduser\Documents\scsnake\contacts.csv", 1,3,0,720,1,1)
scs_sync(url="", localFolderFile="", showMessageBox=1, Retry=3, isRecur=0, noUpdateWithin=720, noStart=false, is_folder=""){
	tried:=0, errLog:="",targetType:=0, tmpFile:=""
	;~ ,tmpFile:=A_ScriptDir "\" a_now "_temp.tmp"
	
	if !(noUpdateWithin+0>0)
		noUpdateWithin:=720
	
	localFolderFile:=RegExReplace(localFolderFile, "\/", "\")
	
	if (localFolderFile~="\\$")
		localFolderFile:=SubStr(localFolderFile,1,-1)
		,is_folder:=true

	;get local .version file
	inputPath:=GetFullPath(localFolderFile)
	f:=FileExist(localFolderFile)
	SplitPath,inputPath,fileNameWithExt,dir,fileExt,fileNameNoExt
	SplitPath,dir,dirName,pDir
	
	if (is_folder!=""){
		if(is_folder){
			if InStr(f, "D") || (fileExt=""){
				FileCreateDir,% inputPath
				localFolderFile:=fileDir:=PathCombine(dir, fileNameWithExt)
				,isFolder:=true
				,i:=0
				Loop,files,% localFolderFile "\*.version"
					localVersionFile:=A_LoopFileLongPath
					,i++
				if (i>1)
					if !FileExist(p:=PathCombine(localFolderFile, fileNameWithExt ".version"))
						return err.="Cannot determine target!"
					else
						localVersionFile:=p
				
				
				if (!localVersionFile){
					localVersionFile:=PathCombine(localFolderFile, fileNameWithExt ".version")
					FileAppend,,% localVersionFile,utf-8
					FileSetAttrib,+H,% localVersionFile
				}
				
				SplitPath,localVersionFile,,,,identifier
			}else{
				localFolderFile:=fileDir:=dir
				,isFolder:=true, 
				Loop,files,% PathCombine(localFolderFile, "*.version")
				{
					localVersionFile:=A_LoopFileLongPath
					break
				}
				if (!localVersionFile){
					localVersionFile:=fileExt="version"?inputPath:PathCombine(localFolderFile, dirName ".version")
					FileAppend,,% localVersionFile,utf-8
					FileSetAttrib,+H,% localVersionFile
				}
				
				SplitPath,localVersionFile,,,,identifier
				SplitPath,identifier,withExt,,Ext
				
				if(fileNameWithExt=identifier)
					isFolder:=false
					,localFolderFile:=PathCombine(dir, identifier)
				else if (Ext){
					isFolder:=false
					,identifier:=fileNameWithExt
					,localVersionFile:=PathCombine(dir, identifier ".version")
					,localFolderFile:=PathCombine(dir, identifier)
					FileAppend,,% localVersionFile,utf-8
					FileSetAttrib,+H,% localVersionFile
				}
			}
		}else{
			if InStr(f, "D"){
				return err.="Cannot determine target!"
			}else{
				localFolderFile:=fileDir:=dir
				,isFolder:=false
				,vf:=FileExist(localVersionFile:=fileExt="version"?inputPath:PathCombine(localFolderFile, fileNameWithExt ".version"))
				if (!vf || InStr(vf,"D")){
					FileAppend,,% localVersionFile,utf-8
					FileSetAttrib,+H,% localVersionFile
				}
				
				SplitPath,localVersionFile,,,,identifier
			}
		}
	}else{
		if InStr(f,"D"){
			FileCreateDir,% inputPath
			localFolderFile:=fileDir:=PathCombine(dir, fileNameWithExt)
			,isFolder:=true
			,i:=0
			Loop,files,% PathCombine(localFolderFile, "*.version")
				localVersionFile:=A_LoopFileLongPath
				,i++
			if (i>1)
				if !FileExist(p:=PathCombine(localFolderFile, fileNameWithExt ".version"))
					return err.="Cannot determine target!"
				else
					localVersionFile:=p
			if (!localVersionFile){
				localVersionFile:=PathCombine(localFolderFile, fileNameWithExt ".version")
				FileAppend,,% localVersionFile,utf-8
				FileSetAttrib,+H,% localVersionFile
			}
			SplitPath,localVersionFile,,,,identifier
		}else if (fileExt="version"){
			localVersionFile:=inputPath
			SplitPath,localVersionFile,,,,identifier
			SplitPath,identifier,withExt,,Ext
			if(Ext){
				isFolder:=false
				,fileDir:=dir
				if !FileExist(localFolderFile:=PathCombine(dir, identifier)){
					FileAppend,,% localFolderFile,utf-8
					;~ FileSetAttrib,+H,% localVersionFile
				}
			}else{
				isFolder:=true
				,localFolderFile:=fileDir:=dir
			}
		}else{
			if FileExist(PathCombine(dir, fileNameNoExt ".version")) || (dirName=fileNameNoExt) {
				localVersionFile:=PathCombine(dir, fileNameNoExt ".version")
				,isFolder:=true
				,fileDir:=dir
				,localFolderFile:=dir
				,identifier:=fileNameNoExt
			}else{
				localVersionFile:=PathCombine(dir, fileNameWithExt ".version")
				,isFolder:=false
				,fileDir:=dir
				,localFolderFile:=inputPath
				,identifier:=fileNameWithExt
			}
			if !FileExist(localVersionFile){
					FileAppend,,% localVersionFile,utf-8
					FileSetAttrib,+H,% localVersionFile
				}
			;~ i:=0
			;~ Loop,files,% PathCombine(dir, "*.version")
				;~ localVersionFile:=A_LoopFileLongPath
				;~ ,i++
			;~ if (i>1)
				;~ if FileExist(p:=PathCombine(dir, fileNameWithExt ".version"))
					;~ isFolder:=false, localVersionFile:=p, localFolderFile:=PathCombine(dir, fileNameWithExt), identifier:=fileNameWithExt
					;~ ,fileDir:=dir
				;~ else if FileExist(p:=PathCombine(dir, fileNameNoExt ".version"))
					;~ localVersionFile:=p, isFolder:=true, localFolderFile:=fileDir:=dir, identifier:=fileNameNoExt
				;~ else
					;~ return err.="Cannot determine target!"
			;~ else if (i=1){
				;~ SplitPath,localVersionFile,,,,identifier
				;~ SplitPath,identifier,withExt,,Ext
				;~ if(Ext){
					;~ isFolder:=false
					;~ ,fileDir:=dir
					;~ if !FileExist(localFolderFile:=PathCombine(dir, identifier)){
						;~ FileAppend,,% localFolderFile,utf-8
					;~ }
				;~ }else{
					;~ isFolder:=true
					;~ ,localFolderFile:=fileDir:=dir
				;~ }
			;~ }else{
				;~ if(dirName = fileNameNoExt){
					;~ FileAppend,,% localVersionFile:=PathCombine(dir, dirName ".version")
					;~ FileSetAttrib,+H,% localVersionFile
					;~ SplitPath,localVersionFile,,,,identifier
					;~ isFolder:=true
					;~ localFolderFile:=fileDir:=dir
				;~ }else{
					;~ FileAppend,,% localVersionFile:=PathCombine(dir, fileNameWithExt ".version")
					;~ FileSetAttrib,+H,% localVersionFile
					;~ SplitPath,localVersionFile,,,,identifier
					;~ isFolder:=false
					;~ ,localFolderFile:=PathCombine(dir, fileNameWithExt)
					;~ ,fileDir:=dir
				;~ }
			;~ }
		}
	}
	;~ MsgBox % isFolder "," localFolderFile "," identifier "," localVersionFile "," FileExist(localVersionFile)
	;~ ExitApp
	
	/*
	localVersionFile:=""
	if (is_folder=1) && InStr(FileExist(localFolderFile),"d"){
		;~ RegExMatch(localFolderFile, "is)^(.+?(?:\\|\/))([^\/\\]+)(?:\\|\/)?$",match)
		localVersionFile:=(localFolderFile:=dir "\" fileNameWithExt) "\" (identifier:=fileNameWithExt) ".version"
		,fileDir:=dir "\" fileNameWithExt
		,isFolder:=true
	}else if FileExist(localFolderFile){
		if (is_folder=0) || (FileExist(localVersionFile:=(fileDir:=dir) "\" fileNameWithExt ".version")){
			isFolder:=false, localFolderFile:=dir "\" fileNameWithExt, identifier:=fileNameWithExt
		}else{
			isFolder:=true, localFolderFile:=dir, localVersionFile:=dir "\" (identifier:=fileNameNoExt) ".version"
		}
		fileDir:=isFolder?localFolderFile:dir
		;~ SplitPath,localFolderFile,fileNameWithExt,fileDir,,fileNameNoExt
		;~ localVersionFile:=fileDir "\" (fileNameWithExt) ".version"
		;~ ,isFolder:=false, identifier:=fileNameWithExt
	}
	;~ else{
		;~ SplitPath,A_ScriptFullPath,fileNameWithExt,fileDir,,fileNameNoExt
		;~ if FileExist(localVersionFile:=fileDir "\" fileNameWithExt ".version") {
			;~ isFolder:=false, localFolderFile:=A_ScriptFullPath, identifier:=fileNameWithExt
		;~ }else{
			;~ isFolder:=true
			;~ ,RegExMatch(fileDir, "^(.+?(?:\\|\/))([^\/\\]+)(?:\\|\/)?$", match)
			;~ ,localFolderFile:=match1 match2 "\"
			;~ ,localVersionFile:=fileDir "\" (identifier:=fileNameNoExt) ".version"
		;~ }
		;~ MsgBox % localVersionFile
		;~ if (isFolder:=( RegExMatch(fileDir, "^(.+?(?:\\|\/))([^\/\\]+)(?:\\|\/)?$", match) && (match2=fileNameNoExt) ))
			;~ localFolderFile:=match1 match2 "\"
		;~ else 
			;~ localFolderFile:=A_ScriptFullPath
			
		;~ localVersionFile:=fileDir "\" (identifier:=fileNameNoExt) ".version"
		
		;~ fileDir:=isFolder?localFolderFile:fileDir
	;~ }
	*/
	
	SplitPath,A_ScriptFullPath,,,,thisScriptName
	;~ updateOther:=(fileDir!=A_ScriptDir) && (identifier!=thisScriptName)
	;~ updateOther:=(thisScriptName="scsnakeUpdate" || thisScriptName="checkUpdate")
	;~ MsgBox % fileDir "," A_ScriptDir "," identifier "," thisScriptName
	;~ MsgBox % updateOther
	
	;get local version
	if !FileExist(localVersionFile)
		currentVersion:="0.0"
	else{
		FileReadLine,localVersion,% localVersionFile,1
		RegExMatch(localVersion,"\[([^\]]+)\] *(\d{8})?", match)
		if(match1!="")
			currentVersion:=match1
		else
			currentVersion:="0.0"
	}
	
	
	if(!IsObject(url) && !isRecur){
		;~ SplitPath,A_ScriptFullPath,fileNameWithExt,fileDir,,fileNameNoExt
		
		;~ if(url!=""){
			;~ match2:="/" RegExReplace(url, "^\/", "")
		;~ }else{
			;~ urlAppend:=RegExMatch(RegExReplace(localFolderFile,"\\", "/"),"is)^(.+)(\/scsnake\/.+?)$", match)
			;~ if(match2=""){
				;~ match2:="/scsnake/" identifier (isFolder?"/":"")
			;~ }
		;~ }
		
		;~ MsgBox % match2

		if(url="")
			url:=["http://10.0.0.1/scsnake/" identifier (isFolder?"/":"")]
		else
			url:=[RegExReplace(url, "\/$", "") "/" identifier (isFolder?"/":"")]
		;~ url.push("http://localhost:8899" match2)
		
		;~ url.push()
	}
	
	
	
	;just updated, do nothing
	lastUpdate:=RegExReplace(fileDir "\lastUpdate_" identifier,"\.","_")
	if !isRecur && FileExist(lastUpdate) {
		FileRead,lastUpdateTime,% lastUpdate
		lastUpdateTime-=a_now,Minutes
		if(lastUpdateTime<noUpdateWithin){
		;~ FileDelete,% lastUpdate
			NoTrayOrphans()
			return "justUpdated"
		}
	}
	
	
	if IsObject(url){
		notLink:=0
		for k, Link in url {
			Link:=RegExReplace(Link, "\\", "/")
			try 
				var:=URLDownloadToVar(isFolder?Link identifier ".version":Link ".version", [1000,1000,1000,1000], 1000)
			if(var=""){
				++notLink
				continue
			}
			errLog.=(errLog=""?"":"`n`n") (ret:=scs_sync(Link, inputPath, showMessageBox, Retry, 1, noUpdateWithin, noStart, is_folder)) 
			if (ret~="i)no newer|user cancel|not quit|cannot determine") 
				return errLog
		}
		if(notLink=url.maxindex()){
			errLog.="All url are invalid`n"
			if(showMessageBox){
				MsgBox % "Can't link to update server."
			}
		}
		return errLog
	}
	
	
	;download .version file
	;~ FileDelete,% tmpFile
	RegExMatch(url, "is)^(.+?(?:\\|\/))([^\/\\]+)(?:\\|\/)?$",match)
	fileFolderName:=match2
	;~ MsgBox % match1 "," match2
	httprequest((remoteFolder:=match1) match2 ".version",post:="",header:="","binary")
	regexmatch(header," (\d+) ",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
	if (code1<200 || code1>=300){
		httprequest((remoteFolder:=match1 match2 "/") match2 ".version",post:="",header:="","binary")
		regexmatch(header," (\d+) ",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
		if(code1<200 || code1>=300){
			errLog.="Can't find version file.`n"
			return errLog
			;~ if(showMessageBox)
				;~ MsgBox,% errLog
			;~ goto checkUpdate_EOF
		}else{
			;~ BinWrite(tmpFile,post,len)
			tmpFile:=StrGet(&post, "utf-8")
			targetType:=1
		}
	}else{
		tmpFile:=StrGet(&post, "utf-8")
	}
	;~ MsgBox % localVersionFile
	
	
	;parse .version file
	version:=[], unzip:=[], dependency:=[]
	loop,Parse,tmpFile,`n,`r
	{
		if ((line:=Trim(A_LoopField))=""){
			continue
		}else if RegExMatch(line,"unzip=([^\n]*)",match) {
			Loop,Parse,match1,|
				unzip[Trim(A_LoopField)]:=true
		}else if RegExMatch(line,"dependency=([^\n]*)",match) {
			Loop,Parse,match1,|
				dependency.push(Trim(A_LoopField))
		}else if RegExMatch(line,"\?--([^\n]*)",match) {
			version[ver, "?delete " match1]:=""
		}else if RegExMatch(line,"\[([^\]]+)\] *(\d{8})?",match) {
			version[ver:=match1]:=[],version[ver,"?date"]:=match2
			if(targetType=0)
				version[ver, file:=fileFolderName]:=""
		}else if !RegExMatch(line,"i)^\?(\w+)",match) {
			version[ver, file:=line]:=""
		}else if (file && match1) {
			version[ver, file]:=match1
		}
	}
	
	;sort version
	ordered_version := sort_version(version)
	

	;check if update
	update:=0,toUpdate:=[]
	for k,ver in ordered_version{
		v:=version[ver]
		if !isobject(v)
			continue
	
		if checkUpdate_compareVersion(checkUpdate_splitVersion(currentVersion), checkUpdate_splitVersion(ver))>-1
			continue
		
		anyFile:=0
		for file,md5 in v {
			anyFile:=1
			break
		}
		if(anyFile)
			toUpdate[ver]:=v.clone()
		,update:=1
	}
	if(!update){
		errLog.="No newer version available.`n"
		;~ if(showMessageBox){
			;~ msgbox,% "No newer version available."
		;~ }
		FileDelete,% localVersionFile
		FileAppend,% tmpFile,% localVersionFile,utf-8
		FileSetAttrib,+H,% localVersionFile
		goto scs_sync_EOF
	}
	
	;announce update, choose if update
	updateInfo:=""
	for k,ver in ordered_version {
		if !toUpdate.haskey(ver)
			continue
		v:=toUpdate[ver]
		updateInfo.="Version " ver " (" toUpdate[ver,"?date"] ")`n" 
		for file,md5 in v {
			if (file~="\?delete")
				updateInfo.=SubStr(file, 2) "`n"
			else if (file!="?date")
				updateInfo.=file "`n"
		}
	}
	
	if(showMessageBox){
		gui,versionInfo:Default
		Gui, +LastFound
		GuiHWND := WinExist()           ;--get handle to this gui..
		Gui, Add, Text, ,% "Current version: " currentVersion
		Gui, Add , Edit  ,% "readonly w500 h300",% updateInfo
		Gui, Add , Button, Default gscs_sync_Update, Update
		Gui, Add , Button, x+20 gscs_sync_Cancel, Cancel
		Gui, Show
		WinWaitClose, ahk_id %GuiHWND%  ;--waiting for gui to close
		if(ReturnCode=0){
			errLog.="User cancels update.`n"
			goto scs_sync_EOF
		}
	}
	FileDelete,% localVersionFile
	FileAppend,% tmpFile,% localVersionFile,utf-8
	FileSetAttrib,+H,% localVersionFile
	
	
	
	
	;download list (remove duplicated)
	updateList:=[], delete:=[]
	for k,ver in ordered_version {
		if !toUpdate.haskey(ver)
			continue
		v:=toUpdate[ver]
		for file,md5 in v
			if RegExMatch(file, "\?delete ([^\n]+)", match)
				try
					updateList.delete(match1)
					,delete[match1]:=true
			else if(file!="?date"){
				updateList[file]:=md5
				if delete.haskey(match1)
					delete.delete(match1)
			}
	}
	
	;download and update
	localFolder:=RegExReplace(fileDir "\" a_now "_update_" identifier "\","\.","_")
	
	for file,md5 in updateList {
		try:=0
		loop % retry {
			SplitPath,% localFolder file,,dir
			if !InStr(FileExist(dir),"D")
				FileCreateDir,% dir
			filedelete,% localFolder file
			httprequest(remoteFolder file,post:="",header:="","binary")
			regexmatch(header," (\d+) ",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
			;~ if InStr(remoteFolder file, "contacts.csv")
				;~ MsgBox % header
			if !(code1<200 || code1>=300) {
				BinWrite(localFolder file, post, len)
				if (!md5 || md5=md5_file(localFolder file)){
					break
				}else{
					++try
				}
			}else{
				++try
			}
		}
		if (try=retry){
			errLog.="Can't download """ file """.`n"
			goto scs_sync_EOF
		}
	}
	
	;unzip
	if (unzip.SetCapacity(0)!=0){
		for file, md5 in updateList {
			if !unzip.haskey(file)
				continue
			SplitPath,% localFolder file,,dir
			try
				Unz(localFolder file, dir)
			catch e {
			}
			if !e
				FileDelete,% localFolder file
		}
	}
	;~ /*
	;~ if(updateOther){
	;check if EXE opened, asked for termination
	;~ MsgBox 1
	
	;~ MsgBox % opened.maxindex()
	;~ if(opened.maxindex()>0){
		;~ if(showMessageBox){
			;~ MsgBox,,,% "Please close the following application: `n" SubStr(openedStr,1,-2),120
		;~ }
		;~ for k, pid in opened {
			;~ Loop {
				;~ process,Close,% pid
			;~ }until ErrorLevel || A_Index>2
		;~ }
	;~ }
;~ }
	;~ */
	
	SplitPath,localVersionFile,fileNameWithExt,dir,,fileNameNoExt
	SplitPath,dir,dirName,pDir
	
	for k,v in delete {
			FileDelete,% PathCombine(dir, k)
	}
	
	
	for k,v in dependency {
		;~ if (v="contacts.csv")
			;~ MsgBox
		if (v~="\.([^\n]+)$")
			target_is_file:=true
		if (isFolder){
			if (target_is_file){
				;~ if !FileExist(p:=dir "\..\" v)
					;~ FileAppend,,% p,utf-8
				;~ if !FileExist(p:=dir "\..\" v ".version")
					;~ FileAppend,,% p,utf-8
				scs_sync([url "../" v] , GetFullPath(dir "\..\" v),0,3,0,1,1,0)
			}else{
				;~ if !InStr(FileExist(p:=dir "\..\" v), "D")
					;~ FileCreateDir,% p
				;~ if !FileExist(p:=dir "\..\" v "\" v ".version")
					;~ FileAppend,,% p,utf-8
				scs_sync([url "../" v "/"], GetFullPath(dir "\..\" v),0,3,0,1,1,1)
			}
		}else{
			if (target_is_file){
				;~ if !FileExist(p:=dir "\" v)
					;~ FileAppend,,% p,utf-8
				;~ if !FileExist(p:=dir "\" v ".version")
					;~ FileAppend,,% p,utf-8
				scs_sync([RegExReplace(url, "\/[^\/]+$", "/") v], GetFullPath(dir "\" v),0,3,0,1,1,0)
			}else{
				;~ if !InStr(FileExist(p:=dir "\" v), "D")
					;~ FileCreateDir,% p
				;~ if !FileExist(p:=dir "\" v "\" v ".version")
					;~ FileAppend,,% p,utf-8
				scs_sync([RegExReplace(url, "\/[^\/]+$", "/") v "/"], GetFullPath(dir "\" v),0,3,0,1,1,1)
			}
		}
		
		
	}
	
	;~ if(!replaceCurrentScript){
		;~ goto scs_sync_EOF
	;~ }
	
	if(showMessageBox && !updateOther){
		MsgBox, 4161, Quit and Update, The script will quit and update.
		IfMsgBox,Cancel
		{
			errLog.="Script not quit for updating.`n"
			goto scs_sync_EOF
		}
	}
	
	
	processList:=ProcessList()
	,opened:=[],openedStr:="", updateOther:=true, selfOpenedPid:=0
	if (isFolder){
	
		for file,md5 in updateList {
			;~ if !RegExMatch(file, "i).exe$")
				;~ continue
			for k, ProcessInfo in ProcessList {
				;~ clipboard.=ProcessName "," processInfo.pid 
			
				if(ProcessInfo.path=(localFolderFile "\" file)){
					if(ProcessInfo.path=A_ScriptFullPath)
						updateOther:=false
						,selfOpenedPid:=ProcessInfo.pid
					else {
						SplitPath,file,fileName
						;~ MsgBox % ProcessInfo.pid 
						opened.push(ProcessInfo.pid)
						,openedStr.=fileName ", "
					}
					break
				}
			}
		}
	}else{
		for ProcessName, ProcessInfo in ProcessList
			if(ProcessInfo.path=localFolderFile){
				if(ProcessInfo.path=A_ScriptFullPath)
					updateOther:=false
					,selfOpenedPid:=ProcessInfo.pid
				else {
					SplitPath,localFolderFile,fileName
					opened.push(ProcessInfo.pid)
					,openedStr.=fileName ", "
				}
				break
			}
	}
	tasksKill:="taskkill"
	for k,v in opened
		tasksKill.=" /PID " v
	if selfOpenedPid
		tasksKill.=" /PID " selfOpenedPid
	
	
	
	;replace files
	;~ if(isFolder){
		;~ FileCopyDir,% SubStr(localFolder,1,-1),% SubStr(localFolderFile,1,-1),1
	;~ }else{
		;~ filecopy,% localFolder fileNameWithExt,% localFolderFile,1
	;~ }
	
	;replace using cmd
	localFolder:=SubStr(localFolder,1,-1)
	now:=a_now
	cmd1=
	(LTrim
	TITLE Updating...
	@echo off
	
	)
	cmd1.="`n" tasksKill	"`n"
	
	if(updateOther){
		
		
		if !(InStr(FileExist(inputPath), "D")){
			;~ process,Exist,% identifier
			;~ if(ErrorLevel){
				;~ cmd2:="taskkill /IM """ identifier """ /F`n"
				cmd4:=noStart?"":"start """" """ inputPath """`n"
			;~ }
		}else
			cmd2:=cmd4:=""
	}else{
		if (a_iscompiled){
			;~ cmd2:="taskkill /IM """ a_scriptname """ /F`n"
			cmd4:=noStart?"":"start """" """ A_ScriptFullPath """`n"
		}else{
			cmd2=
			cmd4:=noStart?"":"start """" """ A_AhkPath """ """ A_ScriptFullPath """`n"
		}
	}
	cmd3=
	(Ltrim
	xcopy "%localFolder%" "%fileDir%" /c /q /i /s /e /k /h /y
	echo %now% > "%lastUpdate%"
	attrib +h "%lastUpdate%" 
	
	)
	cmd5=
	(LTrim
	rd "%localFolder%" /s /q
	(goto) 2>nul & del "`%~f0"
	)
	fileappend,% fullCmd:=cmd1 cmd2 cmd3 cmd4 cmd5,% updateCmd:=fileDir "\" now "update_" RegExReplace(identifier, "\.", "_") ".bat",cp0
	;~ MsgBox % fullCmd
	;~ FileDelete,% tmpFile
	Run,%updateCmd%,,Hide
	;~ MsgBox % RunWaitMany(fullCmd)
	;~ Sleep 5000
	return errLog
	
	
	scs_sync_EOF:
	FileDelete,% tmpFile
	if(localFolder!=""){
		if (replaceCurrentScript)
			FileRemoveDir,% localFolder,1
		else if (showMessageBox)
			run % localFolder
	}
	return errLog
	
	
;-------
	scs_sync_Update:
	ReturnCode:=1
	Gui,versionInfo:Destroy
	return
;-------
	scs_sync_Cancel:
	versionInfoGuiEscape:
	versionInfoGuiClose:
	ReturnCode = 0
	Gui, versionInfo:Destroy
	return
}

checkUpdate(url,currentVersion,replaceCurrentScript=1,showMessageBox=1,retry=3){
	tried:=0, errLog:="",targetType:=0
	,tmpFile:=A_ScriptDir "\" a_now "_temp.tmp"
	
	;just updated, do nothing
	if FileExist(lastUpdate:=RegExReplace(a_scriptdir "\lastUpdate_" A_ScriptName,"\.","_")) {
		FileRead,lastUpdateTime,% lastUpdate
		lastUpdateTime-=a_now,Seconds
		if(lastUpdateTime<3600)
		;~ FileDelete,% lastUpdate
			return "justUpdated"
	}
	
	
	;download .version file
	FileDelete,% tmpFile
	RegExMatch(url, "is)^(.+?(?:\\|\/))([^\/\\]+)(?:\\|\/)?$",match)
	fileFolderName:=match2
	httprequest((remoteFolder:=match1) match2 ".version",post:="",header:="","binary")
	regexmatch(header," (\d+) ",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
	if (code1<200 || code1>=300){
		httprequest((remoteFolder:=match1 match2 "\") match2 ".version",post:="",header:="","binary")
		regexmatch(header," (\d+) ",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
		if(code1<200 || code1>=300){
			errLog.="Can't find version file.`n"
			if(showMessageBox)
				MsgBox,% errLog
			goto checkUpdate_EOF
		}else{
			BinWrite(tmpFile,post,len)
			targetType:=1
		}
	}else{
		BinWrite(tmpFile,post,len)
	}
	
	;parse .version file
	version:=[]
	loop,read,% tmpFile
	{
		if (line:=Trim(A_LoopReadLine))="" {
			continue
		}else if RegExMatch(line,"\[([^\]]+)\] *(\d{8})?",match) {
			version[ver:=match1]:=[],version[ver,"?date"]:=match2
			if(targetType=0)
				version[ver, file:=fileFolderName]:=""
		}else if !RegExMatch(line,"i)^\?(\w+)",match) {
			version[ver, file:=line]:=""
		}else if (file && match1) {
			version[ver, file]:=match1
		}
	}
	
	;check if update
	update:=0,toUpdate:=[]
	for ver,v in version {
		if !isobject(v)
			continue
	
		if checkUpdate_compareVersion(checkUpdate_splitVersion(currentVersion), checkUpdate_splitVersion(ver))>-1
			continue
		
		anyFile:=0
		for file,md5 in v {
			anyFile:=1
			break
		}
		if(anyFile)
			toUpdate[ver]:=v.clone()
		,update:=1
	}
	if(!update){
		errLog.="No newer version available.`n"
		if(showMessageBox){
			msgbox,% "No newer version available."
		}
		FileDelete,% lastUpdate
		FileAppend,% a_now, % lastUpdate,utf-8
		FileSetAttrib,+H,% lastUpdate
		goto checkUpdate_EOF
	}
	
	;announce update, choose if update
	updateInfo:=""
	for ver,v in toUpdate {
		updateInfo.="Version " ver " (" toUpdate[ver,"?date"] ")`n" 
		for file,md5 in v {
			if (file!="?date")
				updateInfo.=file "`n"
		}
	}
	
	if(showMessageBox){
		gui,checkUpdate:Default
		Gui, +LastFound
		GuiHWND := WinExist()           ;--get handle to this gui..
		Gui, Add, Text, ,% "Current version: " currentVersion
		Gui, Add , Edit  ,% "readonly w500 h300",% updateInfo
		Gui, Add , Button, Default gcheckUpdate_Update, Update
		Gui, Add , Button, x+20 gcheckUpdate_Cancel, Cancel
		Gui, Show
		WinWaitClose, ahk_id %GuiHWND%  ;--waiting for gui to close
		if(ReturnCode=0){
			errLog.="User cancels update.`n"
			goto checkUpdate_EOF
		}
	}
	;download list (remove duplicated)
	updateList:=[]
	for ver,v in toUpdate {
		for file,md5 in v
			if(file!="?date")
				updateList[file]:=md5
	}
	
	;download and update
	localFolder:=RegExReplace(a_scriptdir "\" a_now "_update_" fileFolderName "\","\.","_")
	
	for file,md5 in updateList {
		try:=0
		loop % retry {
			SplitPath,% localFolder file,,dir
			if !InStr(FileExist(dir),"D")
				FileCreateDir,% dir
			filedelete,% localFolder file
			httprequest(remoteFolder file,post:="",header:="","binary")
			regexmatch(header," (\d+) ",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
			if !(code1<200 || code1>=300) {
				BinWrite(localFolder file, post, len)
				if (!md5 || md5=md5_file(localFolder file)){
					break
				}else{
					++try
				}
			}else{
				++try
			}
		}
		if (try=retry){
			errLog.="Can't download """ file """.`n"
		}
	}
	
	
	
	if(!replaceCurrentScript){
		goto checkUpdate_EOF
	}
	
	if(showMessageBox){
		MsgBox, 4161, Quit and Update, The script will quit and update.
		IfMsgBox,Cancel
		{
			errLog.="Script not quit for updating.`n"
			replaceCurrentScript:=0
			goto checkUpdate_EOF
		}
	}
	
	;replace using cmd
	localFolder:=SubStr(localFolder,1,-1)
	now:=a_now
	cmd1=
	(LTrim
	TITLE Updating...
	@echo off
	ping 1.1.1.1 -n 1 -w 3000
	
	)
	if (a_iscompiled){
		cmd2:="taskkill /IM """ a_scriptname """ /F`n"
		cmd4:="start """" """ A_ScriptFullPath """`n"
	}else{
		cmd2=
		cmd4:="start """" """ A_AhkPath """ """ A_ScriptFullPath """`n"
	}
	cmd3=
	(Ltrim
	xcopy "%localFolder%" "%a_scriptdir%" /c /q /i /s /e /k /h /y
	type %a_now% > "%lastUpdate%"
	attrib +h "%lastUpdate%" 
	
	)
	cmd5=
	(LTrim
	rd "%localFolder%" /s /q
	(goto) 2>nul & del "`%~f0"
	)
	fileappend,% fullCmd:=cmd1 cmd2 cmd3 cmd4 cmd5,% updateCmd:=a_scriptdir "\" now "update.bat",cp0
	
	FileDelete,% tmpFile
	Run,%updateCmd%,,Hide
	;~ MsgBox % RunWaitMany(fullCmd)
	;~ Sleep 5000
	ExitApp
	return errLog
	
	
	checkUpdate_EOF:
	FileDelete,% tmpFile
	if(localFolder!=""){
		if (replaceCurrentScript)
			FileRemoveDir,% localFolder,1
		else if (showMessageBox)
			run % localFolder
	}
	return errLog
	
	
;-------
	checkUpdate_Update:
	ReturnCode:=1
	Gui, checkUpdate:Destroy
	return
;-------
	checkUpdate_Cancel:
	checkUpdateGuiEscape:
	checkUpdateGuiClose:
	ReturnCode = 0
	Gui, checkUpdate:Destroy
	return
}


