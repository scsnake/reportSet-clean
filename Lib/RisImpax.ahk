﻿#MaxMem 4095
#include <.NetGetControl>
;~ #include <WM_COPYDATA>
#include <ImpaxContextServer>
#include <SetTimerF>
;~ #include <EditFunctions>
#include <Edit>
#include <JXON>
#include <monitorInfo>
#include <WM_COPYDATA>
#include <WinVisible>
#include <AltTab_window_list>
#include <HasVal>
#include <getFocusedHwnd>
#include <RegExSplit>
#include <Hex2Bin>
#include <Crypt>
#include <releasePressed>
#include <EmptyMem>
#include <setTimerClass>
#include <EBMViewer>
#include <DataGridTable>
#include <GEUV>
#include <StrPutVar>
#include <ReportImpression>
;~ #include <INFINITT_PACS>
; Single-owner CH_RIS IPC bridge (client side). Pulling it in here makes the proxy +
; client wrappers available to every risimpax consumer; it stays inert unless the script
; sets __CH_RIS_CLIENT := true before including risimpax. (Dedup-safe shared sub-includes.)
#include <CH_RIS_Client>
#include <SimpleRISRecovery>

SetTitleMatchMode,2
DetectHiddenWindows,on
CoordMode,mouse,screen

if thisPlace=
	thisPlace:=getPlace()
;~ SendMessage,4388,,,,ahk_id 0x4c2fc0

;~ SetTitleMatchMode,2
;~ clipboard:=ListControls(risOpened()[2])
;~ ExitApp
;~ msgbox % risopened()[2]
;~ clipboard:=listcontrols(impaxopened()[2,1])
;~ ExitApp
;~ MsgBox % exploreobj(impaxOpened())
/*
*/
;~ RisImpaxLoadPw()
;~ esc::ExitApp

RisImpaxLoadPw(ByRef RisImpaxDecodePw="", iniPath:=""){
	static fileName:="RisImpaxPw.ini"
	ret:={Ris:[], Impax:[]}
	if FileExist(path:=iniPath) || FileExist(path:=A_ScriptDir "\" fileName)
		|| FileExist(path:=A_ScriptDir "\..\" fileName)
		|| FileExist(path:=SubStr(A_ScriptDir,1,1) ":\scripts\Radiology\" fileName)
		|| FileExist(path:=SubStr(A_ScriptDir,1,1) ":\scripts\Autorun\" fileName) {
		fileread,RisImpaxPwData,% iniPath:=path
		if InStr(RisImpaxPwData, "ENCRYPT"){
			if(RisImpaxDecodePw!="")
				AES_pw := "" RisImpaxDecodePw
			else {
				Gui +LastFound +OwnDialogs +AlwaysOnTop
				InputBox,AES_pw,,Decrypt pw,Hide
				if errorlevel=1
					return
			}

			;~ Hex_Bin(enc_dec,RisImpaxPwData:=RegExReplace(RisImpaxPwData, "^\s*ENCRYPT", ""))
			;~ ,size:=Crypt_AES(&enc_dec, floor(strlen(RisImpaxPwData)/2), AES_pw, 256, 0)
			;~ ,RisImpaxPwData:=substr(substr(enc_dec,1,size),1,size-160)
			;~ MsgBox % RisImpaxPwData
			;~ ,clipboard:=RisImpaxPwData
			try
				RisImpaxPwData:=Crypt.Encrypt.StrDecrypt(RegExReplace(RisImpaxPwData, "^\s*ENCRYPT", ""),AES_pw,7,6)

			if InStr(RisImpaxPwData,"user1="){
				ret.RisImpaxDecodePw:=RisImpaxDecodePw:=AES_pw
				,ret.path := path

				,fe:=A_FileEncoding
				FileDelete,% tmppath:=A_ScriptDir "\RisImpaxPwTmp.ini"
				FileAppend,% RisImpaxPwData,% tmppath,utf-8-Raw
				tmp:=true
			}else{
				MsgBox, 53, , Password error
				RisImpaxDecodePw:=""
				,AES_pw:=""
				IfMsgBox,Retry
					;~ return RisImpaxLoadPw(RisImpaxDecodePw, iniPath)
					reload
				else
					return ret
			}
		}
		loop {
			IniRead,user,% tmppath,RIS,% "user" A_Index,% "$%^&*"
			IniRead,pw,% tmppath,RIS,% "pw" A_Index
			;~ MsgBox % pw
			if(user!="$%^&*") && (user!="ERROR")
				ret.Ris.push({user: user, pw: iniSpecialChar(pw)})
			else
				break
		}

		loop {
			IniRead,user,% tmppath,IMPAX,% "user" A_Index,% "$%^&*"
			IniRead,pw,% tmppath,IMPAX,% "pw" A_Index
			if(user!="$%^&*") && (user!="ERROR")
				ret.Impax.push({user: user, pw: iniSpecialChar(pw)})
			else
				break
		}

		if(tmp)
			FileDelete,% tmppath



		return ret
	}

}

;~ clipboard:=__RisImpaxPwEncrypt(clipboard, "000000")
;~ ExitApp
__RisImpaxPwEncrypt(str="", pw=""){
	global ____
	if str=
		str:=clipboard

	if (PW="" && ____!="")
		PW:=____

	if pw =
		pw := "MOCK_ENCRYPTION_KEY"
	;~ enc_dec:=str
	;~ loop % 10
		;~ enc_dec.="0123456789abcdef"
	;~ size:=Crypt_AES(&enc_dec, strlen(enc_dec), pw, 256, 1)
	;~ ,aes:=Bin_Hex(enc_dec,size,32,"")
	return Crypt.Encrypt.StrEncrypt(str, pw, 7,6)
}

;~ refreshRisImpaxEncrypt("", "", "")
;~ ExitApp

refreshRisImpaxEncrypt(ByRef new_pw="", ByRef loginIds="", newIds=""){
	old:=RisImpaxLoadPw()
	,str:="[RIS]`n"
	if new_pw=
		InputBox,new_pw,,new portal pw,
	for k,v in old.RIS
		str.= "user" k "=" v.user "`n"
		,str.= "pw" k "=" new_pw "`n"
		,loginIds.push(v.user)
	if IsObject(newIds)
		for x,v in newIds
			str.= "user" (k+x) "=" v "`n"
			,str.= "pw" (k+x) "=" new_pw "`n"
			,loginIds.push(v)
	else if newIds!=
		str.= "user" (k+1) "=" newIds "`n"
		,str.= "pw" (k+1) "=" new_pw "`n"
		,loginIds.push(newIds)
	str.="[IMPAX]`n"
	for k,v in old.Impax
		str.= "user" k "=" v.user "`n"
		,str.= "pw" k "=" new_pw "`n"
		;~ ,loginIds.push(v.user)

	if(old.path){
		FileDelete,% old.path
		FileAppend,% "ENCRYPT" __RisImpaxPwEncrypt(str, old.RisImpaxDecodePw),% old.path,utf-8-Raw
	}

}

iniSpecialChar(pw){
	return RegExReplaceFn(pw, "i)\\x([a-f\d]+)\\", "_Chr2")
}
_Chr2(c){
	return Chr("0x" c.1)
}

RisImpaxPollingInit(){
	static exeNAme:="RisImpaxPolling.exe"
	if (hwnd:=WinExist("RisImpaxPolling_Main ahk_class AutoHotkeyGUI")) || (hwnd:=WinExist("ahk_exe " exeName)){
		SetTimer,RisImpaxPollingNotExist,off
		return hwnd
	}
	if FileExist(path:=A_ScriptDir "\" exeName) || FileExist(path:=A_ScriptDir "\..\" exeName) || FileExist(path:=A_ScriptDir "\RisImpaxPolling\" exeName) || FileExist(path:=A_ScriptDir "\..\RisImpaxPolling\" exeName) || FileExist(path:=SubStr(A_ScriptDir,1,1) ":\scripts\Radiology\RisServer\" exeName)  || FileExist(path:=A_ScriptDir "\..\simpleRIS\" exeName) {
		Run % path
		winwait,% "ahk_exe " exeName,,3
		if (!ErrorLevel){
			;~ SetTimer,RisImpaxPollingNotExist,off
			return RisImpaxPollingInit()
		}

	}
	;~ SetTimer,RisImpaxPollingNotExist,500
	return 0
}
RisImpaxPollingNotExist(){
	;~ global
	;~ RisState:=risOpened(), impaxState:=impaxOpened()
}

RisImpax__tooltip(){
	ToolTip
}
/*
infoJson := [ {app: "Ris"
					, type: "State/AccNo/OldReport"
					, hwnd: thisHwnd
					, msg: {msg: returnMsg, wParam: returnWParam, lParam: returnLParam}
					, func: "funcName"
					, initStart: 1/0/delayMiliSec }
					, {app: "Impax", type: "State/AccNo", hwnd: thisHwnd, msg: {msg: returnMsg, wParam: returnWParam, lParam: returnLParam}} ]
*/
RisImpaxRegister(infoJson, forceStandalone=false){
	if forceStandalone || !(hwnd:=RisImpaxPollingInit()) {
		;~ MsgBox % "RisImpaxPolling.exe not found!"
		;~ settimer,RisImpax__tooltip,-2000
		return new RisImpaxPollingSingle(infoJson)
	}
	thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))

	for k,v in infoJson {
		if (v.msg.msg && v.func && v.func!=OnMessage(v.msg.msg))
			OnMessage(v.msg.msg, v.func)
		if (v.func && v.initStart)
			SetTimerF(v.func, (-1)*v.initStart)
		if !WinExist("ahk_id " v.hwnd)
			infoJson[k, "hwnd"]:=thisHwnd
	}

	Send_WM_COPYDATA(hwnd, 0, JXON_Dump(infoJson))
	,SetTimerF("RisImpaxRegisterMonitor", 30000, [hwnd, infoJson])

}

class RisImpaxPollingSingle extends setTimerClass {
	static __RisImpaxPollingSingleInstance:=0
	__New(infoJson){
		if IsObject( this.__RisImpaxPollingSingleInstance )
			return this.__RisImpaxPollingSingleInstance

		this.thisHwnd:=WinExist("Ahk_PID " this.thisPid:=DllCall("GetCurrentProcessId"))
		for k,v in infoJson {
			if (v.msg.msg && v.func && v.func!=OnMessage(v.msg.msg))
				OnMessage(v.msg.msg, v.func)
			if (v.func && v.initStart)
				SetTimerF(v.func, (-1)*v.initStart)
			if !WinExist("ahk_id " v.hwnd)
				infoJson[k, "hwnd"]:=this.thisHwnd
		}
		this.RisRegisterList:={StateChange:{}
			, AccNoChange:{}
			, OldReportChange:{}
			, Count:0}
		,this.ImpaxRegisterList:={StateChange:{}
			, AccNoChange:{}
			, Count:0}
		for k, cmd in infoJson
			if WinExist("ahk_id "  cmd.hwnd){
				app:=cmd.App ; Ris or Impax
				,this[%app%RegisterList][cmd.Type "Change", cmd.hwnd]:=cmd.msg ; {msg: , wParam, lParam}
				PostMessage,% cmd.msg,% cmd.wParam,% cmd.lParam,,% "ahk_id " cmd.hwnd
			}


		this.infoJson:=infoJson
		,this.risRefreshInterval:=-300
		,this.impaxRefreshInterval:=-300
		,this.setTimer("RisRefresh", this.risRefreshInterval)
		,this.setTimer("ImpaxRefresh", this.impaxRefreshInterval)
		,this.setTimer("EmptyMem", 300000)
	}


	RisRefresh(){
		if (this.RisRegisterList.Count=0){
			this.setTimer("RisRefresh", this.risRefreshInterval)
			return
		}

		this.cRisState:=RisOpened()
		if !DllCall("IsHungAppWindow", "ptr", this.cRisState[2]) {
			if (this.pRisState[1]!=this.cRisState[1] || this.pRisState[2]!=this.cRisState[2])
				;~ postMsg(this.RisRegisterList.StateChange)
				this.SetTimer("postMsg_RisState",-1)
			this.pRisState:=this.cRisState

			if(this.RisRegisterList.AccNoChange.SetCapacity(0)>0){
				cAccNo:=getRisAccNo(this.cRisState[2])
				if(pAccNo!=cAccNo)
					SetTimerF("postMsg_RisAccNo", -500)
				pAccNo:=cAccNo
			}

			if(this.RisRegisterList.OldReportChange.SetCapacity(0)>0){
				this.cOldReport:=ControlGetText(getRisReports(this.cRisState[2])[2,1])
				;~ ToolTip % A_TickCount "`and" this.cOldReport
				if(this.pOldReport!=this.cOldReport){
					;~ ToolTip % exploreobj(this.RisRegisterList.OldReportChange)
					;~ postMsg(this.RisRegisterList.OldReportChange)
						this.SetTimer("postMsg_RisOldreport",-1)
				}
				this.pOldReport:=this.cOldReport
			}
		}
		this.setTimer("RisRefresh", this.risRefreshInterval)
	}

	ImpaxRefresh(){

		if (this.impaxRegisterList.Count=0){
			this.setTimer("ImpaxRefresh", this.impaxRefreshInterval)
			return
		}

		this.cImpaxState:=impaxOpened()
		;~ ToolTip % exploreobj(this.cImpaxState)
		if (this.pImpaxState[1]!=this.cImpaxState[1] || this.pImpaxState[2,1]!=this.cImpaxState[2,1] || this.pImpaxState[2,4]!=this.cImpaxState[2,4])
			;~ postMsg(this.impaxRegisterList.StateChange)
			this.SetTimer("postMsg_ImpaxState",-1)
		this.pImpaxState:=this.cImpaxState

		if(this.impaxRegisterList.AccNoChange.SetCapacity(0)>0){
			cAccNo:=getimpaxAccNo(this.cImpaxState[2])
			if(pAccNo!=cAccNo)
				this.SetTimer("postMsg_ImpaxAccNo",-500)
			pAccNo:=cAccNo
		}

		this.setTimer("ImpaxRefresh", this.impaxRefreshInterval)
	}

	postMsg_RisState(){
		this.postMsg(this.RisRegisterList["StateChange"])
	}
	postMsg_RisOldreport(){
		this.postMsg(this.RisRegisterList["OldreportChange"])
	}
	postMsg_RisAccNo(){
		this.postMsg(this.RisRegisterList.AccNoChange)
	}
	postMsg_ImpaxState(){
		this.postMsg(this.ImpaxRegisterList["StateChange"])
	}
	postMsg_ImpaxAccNo(){
		this.postMsg(this.impaxRegisterList.AccNoChange)
	}

	postMsg(list){
		for hwnd, msg in list
			PostMessage,% msg.msg,% msg.wParam,% msg.lParam,,% "ahk_id " hwnd
	}

	EmptyMem(){
		EmptyMem(this.thisPid)
	}
}

RisImpaxRegisterMonitor(hwnd, infoJson){
	if !WinExist("ahk_id " hwnd)
		if (hwnd:=RisImpaxPollingInit())
			Send_WM_COPYDATA(hwnd, 0, JXON_Dump(infoJson))
			,SetTimerF("RisImpaxRegisterMonitor", 0)
			,SetTimerF("RisImpaxRegisterMonitor", 30000, [hwnd, infoJson])
}

RisImpaxMsgProtocol(){
	global
	local k,v
	registerRisChangeMsg:=[0x1000, 0x1003]
	,registerRisChangeItem:=["ris", "risAcc", "risReport", "risOldReport"]
	,registerImpaxChangeMsg:=[0x2000,0x2001]
	,registerImpaxChangeItem:=["impax", "impaxAcc"]
	,RisImpaxChangeMsg2Item:=[]
	,RisImpaxChangeItem2Msg:=[]

	loop % registerRisChangeMsg.2-registerRisChangeMsg.1+1 {
		RisImpaxChangeMsg2Item[registerRisChangeMsg.1+A_Index-1]:=registerRisChangeItem[A_Index]
		,RisImpaxChangeItem2Msg[registerRisChangeItem[A_Index]]:=registerRisChangeMsg.1+A_Index-1
	}
	loop % registerImpaxChangeMsg.2-registerImpaxChangeMsg.1+1 {
		RisImpaxChangeMsg2Item[registerImpaxChangeMsg.1+A_Index-1]:=registerImpaxChangeItem[A_Index]
		,RisImpaxChangeItem2Msg[registerImpaxChangeItem[A_Index]]:=registerImpaxChangeMsg.1+A_Index-1
	}

}


checkRIS(byref RisState,refresh=1){
	SetTitleMatchMode,2
	winget,winList,list,放射線資訊管理系統(Radiology Information System)
	match:=0
	loop % winList
	{
		wingetclass, winClass,% "ahk_id " id:=winList%a_index%
		if instr(winClass,"WindowsForms10.Window.8.app.") && id=RisState[2] {
			match:=1
			break
		}
	}
	if (!match && refresh){
		if !IsObject(RisState)
			RisState:=[]
		for k,v in RisOpened()
			RisState[k]:=v
	}
	return match
}

;~ getRisTree()
;~ ExitApp

getRisTree(){
	oldDetectHiddenWindows:=A_DetectHiddenWindows
	DetectHiddenWindows,off
	ret:=[]
	,pids:=[]
	,alttabList:=AltTab_window_list()
	for k,v in alttabList {
		winget,pname,ProcessName,% "ahk_id " v.hwnd
		if (pname="Menu.exe"){
			pid:=winget("PID", v.hwnd)

			if pids.haskey(pid)
				continue
			else
				pids[pid]:=1

			winget,winList,list,% "ahk_pid " pid

			risTree:=[]
			,risMain:=[]
			loop % winList {
				WinGetTitle,t,% "ahk_id " h:=winList%a_index%
				if RegExMatch(t, "^([^-]+)-放射線資訊管理系統\(Radiology Information System\)", m) {
					risMain:={main: v.hwnd, user: m1, hidden: false
						, active: !!WinActive("ahk_id " v.hwnd), pid: pid, children: []}
				}else if (Trim(t)!=""){
					risTree.push({hwnd: v.hwnd, title: t})
				}
			}
			if risMain.SetCapacity(0)
				risMain.children:=risTree
				,ret.push(risMain)
		}
	}
	DetectHiddenWindows,on
	winget,risList,list,ahk_exe Menu.exe
	loop % risList {
		pid:=winget("PID", h:=risList%a_index%)
		if pids.haskey(pid)
			continue
		else
			pids[pid]:=1

		winget,winList,list,% "ahk_pid " pid

		risTree:=[]
		,risMain:=[]
		loop % winList {
			WinGetTitle,t,% "ahk_id " h:=winList%a_index%
			if RegExMatch(t, "^([^-]+)-放射線資訊管理系統\(Radiology Information System\)", m) {
				risMain:={main: v.hwnd, user: m1, hidden: true
					, active: false, pid: pid, children: []}
			}else if (Trim(t)!=""){
				risTree.push({hwnd: v.hwnd, title: t})
			}
		}
		if risMain.SetCapacity(0)
			risMain.children:=risTree
			,ret.push(risMain)
	}

	DetectHiddenWindows,% oldDetectHiddenWindows
	return ret
}

/* check if RIS opened
	[0, 0]: no
	[1, HWND]: wait for login
	[2, HWND]: opened


	for multiple RIS
	1: [HWNDs]
	2: [HWNDs]
*/

;~ MsgBox % exploreobj(risOpened(1))
;~ WinClose,% "ahk_id " risOpened(1)[2][1]
;~ ExitApp
;~ msgbox % dllcall("IsHungAppWindow", "UInt", risopened()[2])

RisOpened(allRis=0)
{
	;~ if (A_TitleMatchMode!=2){
		;~ oldTitleMatchMode:=A_TitleMatchMode
		;~ SetTitleMatchMode,2
	;~ }
	;~ if( A_DetectHiddenWindows!="on" ){
		;~ oldDetectHiddenWindows:=A_DetectHiddenWindows
		;~ detectHiddenWindows,on
	;~ }

	alttabList:=AltTab_window_list()
	if(allRis=0){


		for k,v in alttabList
			if InStr(v.title, "放射線資訊管理系統(Radiology Information System)") && winvisible(v.hwnd){
				winget,pname,ProcessName,% "ahk_id " v.hwnd
				if (pname="Menu.exe"){
					return Array(2, v.hwnd)
				}
			}
		;~ for k,v in alttabList
			;~ if InStr(v.title, "RIS系統登入<<陽明資訊>>"){
				;~ winget,pname,ProcessName,% "ahk_id " v.hwnd
				;~ if (pname="Menu.exe"){
					;~ return Array(1, v.hwnd)
				;~ }
			;~ }


		winget,winList,list,放射線資訊管理系統(Radiology Information System)
		winget,activeWin,id,A
		loop % winList
		{
			if !winvisible(winList%a_index%)
				continue
			wingetclass, winClass,% "ahk_id " winList%a_index%
			if instr(winClass,"WindowsForms10.Window.8.app."){
				return array(2,winList%a_index%)

			}
		}

		winget,winList,list,RIS系統登入<<陽明資訊>>
		loop % winList
		{
			if !winvisible(winList%a_index%)
				continue
			wingetclass, winClass,% "ahk_id " winList%a_index%
			if instr(winClass,"WindowsForms10.Window.8.app."){
				return array(1,winList%a_index%)

			}
		}

		return array(0,0)
	}else{


		ret:=[[],[]]
		;~ ,arr1:=[], arr2:=[]
		;~ ,ret[2]:=[]
		for k,v in alttabList
			if InStr(v.title, "放射線資訊管理系統(Radiology Information System)") {
				winget,pname,ProcessName,% "ahk_id " v.hwnd
				if(pname="Menu.exe")
					ret[2].push(v.hwnd)
			}

		winget,winList,list,放射線資訊管理系統(Radiology Information System) ahk_exe Menu.exe
		loop % winList
			;~ if dllcall("IsHungAppWindow", "Ptr", winList%a_index%)
				;~ process,close,% "ahk_id " winList%a_index%
		;~ else if(winvisible(winList%a_index%))
			;~ arr1.push(winList%a_index%)
		;~ else
			;~ if !winvisible(winList%a_index%)
			if !HasVal(ret[2], hwnd:=winList%a_index%)
				ret[2].push(hwnd)

		;~ ret[2]:=[]
		;~ for k,v in arr1
			;~ ret[2].push(v)
		;~ for k,v in arr2
			;~ ret[2].push(v)

		;~ ret[1]:=[]
		for k,v in alttabList
			if InStr(v.title, "RIS系統登入<<陽明資訊>>") {
				winget,pname,ProcessName,% "ahk_id " v.hwnd
				if(pname="Menu.exe") && winvisible(v.hwnd)
					ret[1].push(v.hwnd)
			}
		winget,winList,list,RIS系統登入<<陽明資訊>> ahk_exe Menu.exe
		loop % winList
			if !HasVal(ret[1], hwnd:=winList%a_index%) && winvisible(hwnd)
				ret[1].push(hwnd)


	}

	;~ if(oldTitleMatchMode)
		;~ SetTitleMatchMode,% oldTitleMatchMode
	;~ if(oldDetectHiddenWindows)
		;~ DetectHiddenWindows,% oldDetectHiddenWindows


	return ret


}

GetControls(hwnd, controls="")
{
	if !isobject(controls)
		controls:=[]

	if isobject(hwnd){
		for k,v in hwnd
			controls:=GetControls(v, controls)
		return controls
	}

	winget,classnn,ControlList,ahk_id %hwnd%
	winget,controlId,controllisthwnd,ahk_id %hwnd%
	loop,parse,classnn,`n
	{
		controls[a_index]:=[]
		controls[a_index]["ClassNN"]:=a_loopfield
	}

	loop,parse,controlId,`n
	{
		controls[a_index]["Hwnd"]:=a_loopfield
		controlgetText,txt,,ahk_id %a_loopfield%
		controls[a_index]["text"]:=txt
	}
	return controls
}

GetOtherControl(refHwnd,shift,controls,type="hwnd"){
	for k,v in controls
		if v[type]=refHwnd
			return controls[k+shift].hwnd
}

/* check if IMPAX opened
	arr[1]=0	no IMPAX
	arr[1]=1, arr[2,1]=hwnd of login window
	arr[1]=2, arr[2,1]=hwnd of image window
	arr[1]=2, arr[2,2]=hwnd of list & text window
	arr[1]=2, arr[2,3]=hwnd of list window
	arr[1]=2, arr[2,4]=which type of active IMPAX window (1:image, 2:list, 3:text)
	arr[1]=2, arr[2,5]=which configuration of IMPAX windows (1 for one window, 2 for double window)
*/
ImpaxOpened()
{
	winget,ImpaxIdList,list,ahk_class WindowsForms10.Window.8.app.0.2bf8098
	winget,activeWin,id,A
	arr:=[],ind1:=ind2:=ind3:=0,a1:=a2:=a3:=0
	arr[1]:=0
	loop 5
		arr[2,a_index]:=0


	loop % ImpaxIdList
	{
		id:=ImpaxIdList%a_index%
		wingettext,text,ahk_id %id%
		if ind:=instr(text,"STUDY_NAV_TOOLBAR0"){
			ind1:=ind,a1:=a_index,arr[2,1]:=id
			;~ if((arr[2,1]:=id)=activeWin)
				;~ arr[2,4]:=1

		}
		if((instr(text,"工作清單")&&instr(text,"相關性")&&instr(text,"更新"))||(instr(text,"Worklists")&&instr(text,"Relevance")&&instr(text,"Refresh"))){
			if((instr(text,"臨床資訊")&&instr(text,"RIS 狀態")&&instr(text,"病患 HIS 代碼"))||(instr(text,"Clinical Information")&&instr(text,"RIS Status")&&instr(text,"Patient HIS Code"))){
			ind2:=instr(text,"臨床資訊")|instr(text,"Clinical Information")
				a2:=a_index,arr[2,2]:=id
				;~ if((arr[2,2]:=id)=activeWin)
					;~ arr[2,4]:=2
			}else{
				ind3:=instr(text,"工作清單")|instr(text,"Worklists")
				a3:=a_index,arr[2,3]:=id
				;~ if((arr[2,3]:=id)=activeWin)
					;~ arr[2,4]:=3

			}
		}
		wingetpos,,,,h,ahk_id %id%
		if (maxH<h)
			maxH:=h
	}

	h:=maxH
	h-=41


	if (arr[2,1]||arr[2,2]||arr[2,3]){

		arr[1]:=2
		if(arr[2,1]=(arr[2,2]|arr[2,3])){
			arr[2,5]:=1

			if ((bar:=impaxBar(arr[2,2]|arr[2,3])).h>h){
				arr[2,4]:=2
			}else if(ind1<(ind2|ind3)){
				arr[2,4]:=1
			}else {
				arr[2,4]:=3
			}


		}else{
			arr[2,5]:=2

			;~ if(arr[2,4]>1&&(impaxBar(arr[2,2]|arr[2,3]).h>h)){
				;~ arr[2,4]:=2
			;~ }else if (arr[2,4]>1&&(impaxBar(arr[2,2]|arr[2,3]).h<=h)){
				;~ arr[2,4]:=3
			;~ }else{
				;~ arr[2,4]:=1
			;~ }

			if(a1<(a2|a3)){
				arr[2,4]:=1
			}else if(impaxBar(arr[2,2]|arr[2,3]).h>h){
				arr[2,4]:=2
			}else{
				arr[2,4]:=3
			}


		}
		return arr
	}

	loop % ImpaxIdList
	{
		id:=ImpaxIdList%a_index%
		wingettext,text,ahk_id %id%
		if (instr(text,"登入") && instr(text,"密碼") && instr(text,"選項")) || (instr(text,"Login") && instr(text,"Options") && instr(text,"User ID"))
			return array(1,array(id))
	}

	return array(0,0)
}

GetControlIdByText(byref arr,RefControlText,offset=0,UseRegEx=0)
{
	if !isobject(arr)||!arr.maxIndex()
		return
	k=0
	if UseRegEx
	{
		for k,v in arr
			if RegExMatch(v.text,RefControltext)
				break
	}
	else
	{
		for k,v in arr
			if v.text=RefControltext
				break
		if !k
			for k,v in arr
				if instr(v.text,RefControltext)
					break
	}

	if !offset
		i:=k
	else
	{
		i:=k+offset
		l:=arr.MaxIndex()
		while i>l
			i-=l
		while i<1
			i+=l
	}
	return (k=0 ? 0 : arr[i]["Hwnd"])

}

;~ run % GetRisPath(1)
GetRisPath(direct=0){
	if(!direct){
		if fileexist(path:=a_desktop "\放射線資訊管理系統(Radiology Information System).appref-ms")
			return path

		if fileexist(path:=a_desktop "\RIS.appref-ms")
			return path

		if fileexist(path:=A_StartMenu "\Programs\放射線資訊管理系統(Radiology Information System).appref-ms")
			return path
		if fileexist(path:=A_StartMenu "\程式集\放射線資訊管理系統(Radiology Information System).appref-ms")
			return path
		if fileexist(path:=A_StartMenu "\Programs\陽明資訊\RIS.appref-ms")
			return path
		if fileexist(path:=A_StartMenu "\程式集\陽明資訊\RIS.appref-ms")
			return path
	}

	directPaths:=[]

	;~ if (h:=WinExist("Radiology Information System ahk_exe Menu.exe")) {
		;~ winget,pid,pid,ahk_id %h%
		;~ for k,v in ProcessList() {
			;~ if(v.pid=pid){
				;~ directPaths.push(v.path)
				;~ break
			;~ }
		;~ }
	;~ }


	loop,HKCU,Software\Microsoft\Windows\ShellNoRoam\MUICache
		if instr(a_loopregname,"Menu.exe") && fileexist(a_loopregname)
			directPaths.push(a_loopregname)
	loop,HKCU,Software\Microsoft\Internet Explorer\TypedURLs
	{
		regread,v
		if instr(a,"Menu.exe") && fileexist(v)
			directPaths.push(v)
	}

	for k,v in searchFile("Menu.exe",a_appdata "\..\Local\Apps\2.0")
		directPaths.push(v)

	return directPaths

}

;~ if (a:=searchFile("Menu.exe",substr(a_windir,1,3) "Documents and Settings\" a_username "\Local Settings\Apps\2.0")).maxindex()
		;~ clipboard:= a[1]

ListControls(hwnd, obj=0, arr="")
{
	if !isobject(arr)
		arr:=[]

	if isobject(hwnd){
		for k,v in hwnd
			arr:=ListControls(v, 1, arr)
		goto ListControlsReturn
	}

	str=
	arr:=GetControls(hwnd)
ListControlsReturn:
	if obj
		return arr

	for k,v in arr
		str.="""" v["Hwnd"] """,""" v["ClassNN"] """,""" v["text"] """,""" getControlNameByHwnd(hwnd,v["Hwnd"]) """`n"
	return str
}

/*
	return switch bar: hwnd, x,y,w,h
*/
ImpaxBar(impaxStateOrHwnd){
	if isobject(impaxStateOrHwnd)
		hwnd:=impaxStateOrHwnd[2,2] | impaxStateOrHwnd[2,3]
	else
		hwnd:=impaxStateOrHwnd

	for k,v in (impaxControls:=getcontrols(hwnd)) {
		if ((v.text="登出"||v.text="Logout") && instr(v.classNN,"WindowsForms10.BUTTON.app") && instr(impaxControls[k-2].classNN,"WindowsForms10.Window.8.app")) {
			controlgetpos,x,y,w,h,,% "ahk_id " barId:=impaxControls[k-2].hwnd
			break
		}
	}
	return {hwnd:barId, x:x, y:y, w:w, h:h}
}

/*
	ImpaxStateArr[1]=image window (in  monitor), ImpaxStateArr[2]=search window
	which=0, switch to search page
	which=1, switch to image page
*/
ImpaxSwitchPage(ImpaxStateArr,which=0,bar=""){
	if !bar
		bar:=ImpaxBar(ImpaxStateArr[2])
	wingetpos,winx,winy,,,% "ahk_id " ImpaxStateArr[2]
	if (which=0){
		winactivate,% "ahk_id " ImpaxStateArr[2]
		controlclick,,% "ahk_id " bar.hwnd
	} else if (which=1) {
		if(ImpaxState[1]) {
			winactivate,% "ahk_id " ImpaxStateArr[1]
		}else if !(bar.h>100) {
			mouseclick,,% winx+bar.x+bar.w/3,% winy+bar.y+10,,0
		}

	}
}

/*
	arr[1,1]=main findings
	arr[1,2]=main impression
	arr[1,3]=main suggestion
	arr[2,1]=prior findings
	arr[2,2]=prior impression
	arr[2,3]=prior suggestion
	to be editted!!
*/
;~ msgbox % controlgettext(getRisReports(RisOpened()[2])[1,1])
;~ ExitApp
getRisReports(risHwnd=""){
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)


	if !WinExist("ahk_id " RisHwnd)
		RisHwnd:=risOpened()[2]

	arr:=[]
	for k,v in risControls:=getcontrols(risHwnd) {
		if (instr(v.text,"下筆") && instr(v.classNN,"WindowsForms10.BUTTON")) {
			temp:=k
			break
		}
	}
	for k,v in risControls {
		if (v.text="Exam." && instr(risControls[k+1]["classNN"],"WindowsForms10.EDIT.app")) {
			if(abs(k-temp)<18){
				arr[1]:=array(risControls[k+1]["hwnd"],risControls[k+4]["hwnd"],risControls[k+7]["hwnd"])
			}else if (risControls[k-13,"text"]="歷史報告") || (risControls[k-12,"text"]="歷史報告") {
				arr[2]:=array(risControls[k+1]["hwnd"],risControls[k+4]["hwnd"],risControls[k+7]["hwnd"])
			}else if (risControls[k-12,"text"]="報告版本查詢") || (risControls[k-11,"text"]="報告版本查詢") {
				arr[3]:=array(risControls[k+1]["hwnd"],risControls[k+4]["hwnd"])
			}
		}
	}
	return arr
}


getRisReportsHwnd(risHwnd=""){
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)

	for k,v in risControls:=getcontrols(risHwnd) {
		if (instr(v.text,"下筆") && instr(v.classNN,"WindowsForms10.BUTTON")) {
			temp:=k
			break
		}
	}
	for k,v in risControls {
		if (v.text="Exam." && instr(risControls[k+1]["classNN"],"WindowsForms10.EDIT.app") && abs(k-temp)<13) {
			return array(risControls[k+1]["hwnd"])
			break
		}

	}
	return []

}




getTextByHwnd(id){
	controlgettext,t,,ahk_id %id%
	return t
}

;~ getChartNo(id){
	;~ for k,v in risControls:=getcontrols(id) {
		;~ if RegExMatch(v.text,"(\w)\w{5}\d") && instr(v.classNN,"WindowsForms10.EDIT.app") && risControls[k-1].text="???" && risControls[k+2].text="??" {
			;~ return v.text
		;~ }
	;~ }
;~ }
;~ info:=getImpaxInfo("",["chartNo"])
;~ b=1
getImpaxInfo(ByRef impaxState, ByRef items){
	params:=[]
	if !IsObject(impaxState)
		for k,v in impaxOpened()
			if isobject(v)
				for x,y in v
					impaxState[k,x]:=y
			else
				impaxState[k]:=v
	for k,v in items
		if IsFunc(FuncName:="getImpax" v){
			func:=func(FuncName), param:=[impaxState]
			Loop % func.MaxParams-2
				param.push("")
			param.push(true)
			,params.push(func.call(param*))
		}
	result:=getNetControls(params)
	info:=[]
	for k,v in items
		info[v]:=ControlGetText(result[k].1)
	return info

}
;~ getImpaxExamDate(impaxOpened()[2,1])
getImpaxExamDate(impaxHwnd){
	arr:=[], sort:=[]
	for k,v in (ret:=getNetControl2(impaxHwnd,"","studyDateTimeLabel","","WindowsForms10.STATIC.app","","","",0)) {
		arr.push(dateFormat(ControlGetText(v)))
		loc:=Acc_Location(acc_ObjectFromWindow(v))
		,sort[loc.x]:=k
	}
	arr2:=[]
	for k,v in sort
		arr2.push(arr[v])
	return arr2
}

getImpaxChartNo(impaxStateOrHwnd="", returnFilter=false){

	if isobject(impaxStateOrHwnd)
		hwnd:=impaxStateOrHwnd[2,1]
	else if (impaxStateOrHwnd)
		hwnd:=impaxStateOrHwnd
	else
		hwnd:=impaxopened()[2,1]
	if (returnFilter)
		return {winHwnd: hwnd, controlName: "patientIdLabel", ClassNN: "WindowsForms10.STATIC.app", getNonEmpty: 1}

	controlgettext,chartNo,,% "ahk_id " getNetControl2(hwnd,"","patientIdLabel","","WindowsForms10.STATIC.app","","","",0)[1]

	if(chartNo="")
		return

	while strlen(chartNo)<7
		chartNo:="0" chartNo

	return chartNo
}
getImpaxUserId(impaxStateOrHwnd="", returnFilter=false){

	if isobject(impaxStateOrHwnd)
		hwnd:=impaxStateOrHwnd[2,2] | impaxStateOrHwnd[2,3]
	else if (impaxStateOrHwnd)
		hwnd:=impaxStateOrHwnd
	else
		hwnd:=impaxopened()[2,1]
	if (returnFilter)
		return {winHwnd: hwnd, controlName: "userIDLabel", ClassNN: "WindowsForms10.STATIC.app", getNonEmpty: 1}
	controlgettext,UserId,,% "ahk_id " getNetControl2(hwnd,"","userIDLabel","","WindowsForms10.STATIC.app","","","",0)[1]

	return UserId
}

;~ msgbox % getImpaxAccNo()

getImpaxAccNo(impaxStateOrHwnd="",leftUpper=1, returnFilter=false){
	if isobject(impaxStateOrHwnd)
		hwnd:=impaxStateOrHwnd[2,1]
	else if (impaxStateOrHwnd)
		hwnd:=impaxStateOrHwnd
	else
		hwnd:=impaxopened()[2,1]
	if (returnFilter)
		return {winHwnd: hwnd, controlName: "accessionNumberLabel", ClassNN: "WindowsForms10.STATIC.app", getNonEmpty: 1}


	if(leftUpper="")
		leftUpper:=1

	con:=getNetControl2(hwnd,"","accessionNumberLabel","","WindowsForms10.STATIC.app","","","",0)
	controlgettext,AccNo,,% "ahk_id " selectControlByPos(con)

	return AccNo
}
;~ getTopParent(0x1C0BB2)
;~ winget,class,processname,ahk_id 1______
;~ msgbox % class
;~ getTopParent(hwnd){
	;~ while (hwnd!=(parent:=DllCall("GetParent", "int" , hwnd))) && parent
		;~ hwnd:=parent
	;~ return hwnd
;~ }

selectControlByPos(byref controlArr,mostLeft=1,mostUpper=0,first=1){
	selected:=[],ind:=1
	selected[ind]:=controlArr[1]
	controlgetpos,cx,cy,,,,% "ahk_id " controlArr[1]

	if(mostLeft=0&&mostUpper=0)
		mostLeft:=1

	for k,v in controlArr {
		if k=1
			continue
		controlgetpos,x,y,,,,ahk_id %v%
		if (x=cx && y=cy)
			selected[++ind]:=v
		else if  (((mostLeft=1 && x<cx) || (mostLeft=-1 && x>cx)) && mostUpper=0)
			|| (((mostUpper=1 && y<cy) || (mostUpper=-1 && y>cy)) && mostLeft=0)
			|| (((mostUpper=1 && y<cy) || (mostUpper=-1 && y>cy)) && ((mostUpper=1 && y<cy) || (mostUpper=-1 && y>cy)))
			|| ((x=cx) && mostUpper=0 && y<cy)
			|| ((y=cy) && mostLeft=0 && x<cx)
			selected:=[],ind:=1,selected[1]:=v


		cx:=x,cy:=y
	}

	if(first)
		return selected[1]
	else
		return selected

}


;~ msgbox % getRisChartNo(RisOpened()[2])
;~ ExitApp
getChartNo(id, getprv=true){
	return getRisChartNo(id, getprv)
}
getRisChartNo(hwnd="", getprv=true){
	;~ controlgettext,chartNo,,% "ahk_id " (ids:=getNetControl2(hwnd,"???","FID_LABEL","???","WindowsForms10.STATIC.app.0.378734a","","","",1))[2]
	;~ if chartNo=
		;~ controlgettext,chartNo,,% "ahk_id " ids[1]
	;~ while strlen(chartNo)<7
		;~ chartNo:="0" chartNo

	;~ return chartno



	static prvHwnd

	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)


	if hwnd=
		hwnd:=RisOpened()[2]


	for k,v in controls:=getcontrols(hwnd)
		if (RegExMatch(v.text,"^\w{6}\d$") && controls[k-1].text="病歷號" && instr(controls[k-1].classNN,"WindowsForms10.STATIC")){
			chartNo:=v.text, prvHwnd:=v.hwnd
			;~ break
		}
	if(chartNo="") && getprv && !prvHwnd
		chartNo:=ControlGetText(prvHwnd)

	if chartNo!=
		while strlen(chartNo)<7
			chartNo:="0" chartNo

	return chartNo

	for k,v in getcontrols(hwnd)
		if instr(v.classNN,"WindowsForms10.EDIT") && acc_objectfromwindow(v.hwnd).accName="病歷號"
		{
			controlgettext,str,,% "ahk_id " v.hwnd
			return str
		}
}
;~ MsgBox % getRisChartNoHwnd(risOpened()[2])
;~ ExitApp
getRisChartNoHwnd(hwnd, getprv=true){
	static prvHwnd
	;~ for k,v in controls:=getcontrols(hwnd)
		;~ if RegExMatch(v.text,"^\w{6}\d$") && controls[k-1].text="病歷號"
			;~ return % prvHwnd:=id:=v.hwnd
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)

	id:=0
	for k,v in controls:=getcontrols(hwnd)
		if (RegExMatch(v.text,"^\w{6}\d$") && controls[k-1].text="病歷號" && instr(controls[k-1].classNN,"WindowsForms10.STATIC")){
			prvHwnd:=id:=v.hwnd
		}
	if (id)
		return id
	;~ if chartNo!=
		;~ while strlen(chartNo)<7
			;~ chartNo:="0" chartNo


	if getprv
	return prvHwnd

	for k,v in getcontrols(hwnd)
		if instr(v.classNN,"WindowsForms10.EDIT") && acc_objectfromwindow(v.hwnd).accName="病歷號"
		{
			;~ controlgettext,str,,% "ahk_id " v.hwnd
			return v.hwnd
		}

}

getRisAccNo(hwnd, getprv=true){
	return getRisSheetNo(hwnd, getprv)
}
getRisSheetNo(hwnd, getprv=true){
	static prvHwnd

	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)

	for k,v in controls:=getcontrols(hwnd)
		if controls[k-1].text="照會單號" && regexmatch(v.text,"^\w{11}$") && instr(v.classNN,"WindowsForms10.EDIT")
		{
			;~ controlgettext,str,,% "ahk_id " v.hwnd
			prvHwnd:=v.hwnd
			return v.text
		}

	if getprv
	return ControlGetText(prvHwnd)
}

getRisAccNoHwnd(risHwnd="", getPrv=true){
	static prvHwnd

	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)


	for k,v in controls:=getcontrols(risHwnd)
		if controls[k-1].text="照會單號" && regexmatch(v.text,"^\w{11}$") && instr(v.classNN,"WindowsForms10.EDIT")
		{
			;~ controlgettext,str,,% "ahk_id " v.hwnd
			return prvHwnd:=v.hwnd
		}
	if getprv
	return prvHwnd
}


getRisHistoryId(hwnd, getprv=true){
	static prvHwnd
	for k,v in controls:=getControls(hwnd)
		if (instr(v.classNN,"WindowsForms10.Window.8.app") && v.text="歷史報告" && instr(controls[k+3,"classNN"],"WindowsForms10.Window.8.app")){
			if (controlId:=controls[k+3,"hwnd"])
				return prvHwnd:=controlId

		}
	if getprv
	return prvHwnd
}

/*
	getRisHistory(hwnd,byref arr="",n=""){
		if !isobject(arr)
			arr:=[]

	;~ if !controlId:=getNetControl(hwnd,controlName:="dgHisReport",accName:="DataGridView",classNN:="WindowsForms",accHelp:="")
		;~ return arr

	;~ for k,v in controls:=getControls(hwnd)
		;~ if (instr(v.classNN,"WindowsForms10.Window.8.app") && v.text="????" && instr(controls[k+3,"classNN"],"WindowsForms10.Window.8.app")){
			;~ controlId:=controls[k+3,"hwnd"]
			;~ break
		;~ }

		if !(controlId:=getRisHistoryId(hwnd)) || !(acc:=acc_objectfromwindow(controlId))
			return

		acc:=acc_objectfromwindow(controlId)

		colNo:=[]
		loop % acc_children(acc_get("Object",1,0,acc)).maxindex()-1
			colNo["" acc_get("Value","1." a_index+1,0,acc)]:=a_index+1

		loop % (n=""?(acc_children(acc).maxindex()-1):1) {
			i:=(n=""?(a_index+1):n),arr2:=[]
			arr2["ExamDate"]:="" acc_get("Value",i "." colNo["???"],0,acc)
			arr2["DrName"]:="" acc_get("Value",i "." colNo["????"],0,acc)
			arr2["ExamName"]:="" acc_get("Value",i ".4" colNo["????"],0,acc)
			arr2["SheetNo"]:="" acc_get("Value",i ".5" colNo["????"],0,acc)
			arr2["ChartNo"]:="" acc_get("Value",i ".6" colNo["????"],0,acc)
			arr2["ReportIndex"]:="" acc_get("Value",i ".7" colNo["????"],0,acc)
			arr2["Hospital"]:="" acc_get("Value",i ".8" colNo["??"],0,acc)
			arr.push(arr2.clone())
		}
	;~ arr[0]:=acc
		return arr
	}
*/
getRisHistoryIndex(dgHisReportAcc,rowAcc){
	loop % acc_children(dgHisReportAcc).maxIndex()-1 {
		check:=true
		i:=a_index+1
		loop % acc_children(acc_get("Object",1,0,dgHisReportAcc)).maxindex()-1 {
			j:=A_Index
			check:=check & (acc_get("Value",i "." j,0,dgHisReportAcc)=acc_get("Value",j,0,rowAcc))
		}
		if (check)
			return i
	}
	return 0
}

searchFile(f,dir){
	arr:=[]
	;~ originalWorkingDir:=A_WorkingDir
	;~ SetWorkingDir,% dir
	loop,Files,% RegExReplace(dir, "\\$", "") "\" f,FR
		arr.push(A_LoopFileLongPath)
	;~ SetWorkingDir,% originalWorkingDir
	return arr
}


searchRisChartNo(hwnd,AccNoOrChartNo, chartNo=""){
	static prvHwnd
	for k,v in controls:=getControls(hwnd)
		if (instr(v.text,"查詢單號") && instr(v.classNN,"WindowsForms10.STATIC")){
			thisHwnd:=prvHwnd:=controls[k+1].hwnd
			break
		}

	if(!thisHwnd)
		for k,v in controls
			if (instr(v.text,"病歷號") && instr(v.classNN,"WindowsForms10.STATIC") && !instr(controls[k-3].text,"照會單號")){
				thisHwnd:=prvHwnd:=controls[k+1].hwnd
				, useChartNo:=true
				break
			}

	if(!thisHwnd || (thisHwnd:=prvHwnd)){
		controlfocus,,% "ahk_id " thisHwnd
		controlsettext,,% useChartNo&&chartNo!=""?chartNo:AccNoOrChartNo,% "ahk_id " thisHwnd
		controlsend,,{Enter},% "ahk_id " thisHwnd
		return true
	}
	return false
}



goReportTab(risHwnd, ind=2){
	if !ind
		return
	tabs:=getNetControl2(risHwnd,"","B_ACTIVE","","WindowsForms10.BUTTON")
	if tabs[ind]
		acc_objectfromwindow(tabs[ind]).accDoDefaultAction()
	else
		return -1
}

class RisTempActivate {
	static instances:=[]
	__New(targetHwnd, goTab=""){
		PostMessage,0x10105,,,,ahk_exe autorun.exe
		this.oldActive:=WinExist("A")
		,this.targetState:={ visible: WinVisible(targetHwnd)
			,hwnd: targetHwnd}
		,this.sameRis:=(targetHwnd==this.oldActive)
		,this.setTrans:=0

		,this.escHook:=InputHook("L1 V")
		,this.escHook.KeyOpt("{ESC}", "ES")

		,this.escHook.OnEnd:=(this.deleteFn:=ObjBindMethod(this,"__Delete"))
		,this.escHook.start()


		if (!this.sameRis){
			RisTempActivate.HiddenRis[targetHwnd]:=1
			winset,trans,% this.setTrans,% "ahk_id " targetHwnd
			winactivate,% "ahk_id " targetHwnd
			winwaitactive,% "ahk_id " targetHwnd,,3
			winshow,% "ahk_id " targetHwnd

		}

		this.targetState.tab:=controlvisible(RisListHwnd:=getRisList(targetHwnd))?2:3
		if (gotab!=""){
			goReportTab(targetHwnd, goTab)
			,targetControl:=goTab=2?RisListHwnd:getRisAccNoHwnd(targetHwnd)
			loop{
				sleep 10
			}until controlvisible(targetControl) || a_index>200
		}
		RisTempActivate.instances.push(this)

	}
	recover(){
		goReportTab(this.targetState.hwnd, this.targetState.tab)
		if (!this.sameRis){
			if !this.targetState.visible
				winhide,% "ahk_id " this.targetState.hwnd
			;~ winhide,% "ahk_id " this.oldActive
			winactivate,% "ahk_id " this.oldActive
			;~ winshow,% "ahk_id " this.oldActive
			winset,trans,off,% "ahk_id " this.targetState.hwnd
		}
		this.recovered:=true
	}

	__Delete(){
		if !(this.recovered)
			this.recover()

		for k,v in RisTempActivate.instances
			if (v==this){
				RisTempActivate.instances.delete(k)
				break
			}
	}

	recoverAll(){
		inst:=[]
		for k,v in RisTempActivate.instances
			inst.push(v)
		for k,v in inst
			v.recover()
	}
}

getLastRis(risHwnd=""){
	if IsObject(risHwnd)
		return getLastRis(risHwnd[2])

	if WinExist("ahk_id " risHwnd)
		return risHwnd

	risHwnd:=risOpened()[2]

	if WinExist("ahk_id " risHwnd)
		return risHwnd

	return risHwnd:=risOpened(1)[2,1]
}
;~ risTemp:=new RisTempActivate(risopened()[2],2)
;~ sleep 1000
;~ risTemp.recover()

;~ msgbox % parseDataGrid2(risListHwnd:=getRisList(risOpened()[2]), risOpened()[2], acc_children(acc_ObjectFromWindow(risListHwnd))).length()
;~ msgbox % parseDataGrid2("", risOpened()[2]).length()
;~ DetectHiddenWindows,on
;~ risHwnd:=risOpened()[2]
;~ WinHide,ahk_id %rishwnd%
;~ listHwnd:=getRisHistory(RisHwnd)
;~ MsgBox % ParseDataGrid2().length()
;~ WinShow,ahk_id %rishwnd%
;~ ExitApp
;~ parseDataGrid2_f
parseDataGrid2(listHwnd="", RisHwnd="",ByRef childrenAcc="", wait=false, useCurrentClipboard=false, unselectAll=true, selectAll=true, grabTitle=false, preserveClipboard=false, useCtrlA=false, outputClipboard=false, activateRis=true){
	;~ MsgBox 0
	if (!useCurrentClipboard){
		;~ if !RisHwnd
			risHwnd:=getLastRis(risHwnd)

		if !listHwnd
			listHwnd:=getRisList(RisHwnd)

		if (childrenAcc!=""){
			if childrenAcc is Integer
			{
				if childrenAcc<4
					return []
			}else if IsObject(childrenAcc) && !childrenAcc.length()>0
				return []
		}

		childCount:=acc_objectFromWindow(listHwnd).accChildCount

		if (childCount<=20){
			parseDataGrid(listHwnd, ret)
			return new DataGridTable(ret)
		}


		#ClipboardTimeout 2000
		if preserveClipboard
			clipboardOld:=ClipboardAll
		clipboard:=""
		if activateRis
			risTemp:=new RisTempActivate(RisHwnd)
		loop 3 {
			;~ index:=A_Index
			if (selectAll){
				;~ if(!useCtrlA && childrenAcc && winvisible(risHwnd))
					;~ selectAllRisList(childrenAcc)

				;~ else{
					;~ MsgBox 1
					PostMessage,0x10105,,,,ahk_exe autorun.exe
					BlockInput,on
					send {LCtrl Up}{RCtrl Up}
					ControlFocus,,ahk_id %listHwnd%
					controlsend,,^a,ahk_id %listHwnd%

					BlockInput,off
				;~ }

				Sleep % log(childCount+1) * 500 * (A_Index*2-2) + 200
			}
			;~ MsgBox 2
			PostMessage,0x10105,,,,ahk_exe autorun.exe
			BlockInput,on
			send {LCtrl Up}{RCtrl Up}
			ControlFocus,,ahk_id %listHwnd%
			controlsend,,^c,ahk_id %listHwnd%

			BlockInput,off
			;~ Sleep % 100*(A_Index)*2

			if Wait
				ClipWait,% wait+0
			else
				ClipWait,% childCount<5000? log(childCount+1) * 0.5 *(A_Index) : 120
			lb_count:=RegExCount(clipboard, "\n")
			if !ErrorLevel && lb_count>0 && lb_count>=childCount-3
				break
			WinClose,,Can't open clipboard for reading
		}
		if activateRis
			risTemp.recover()
		;~ MsgBox % index
		if(clipboard=""){
			ShowToolTip(A_ScriptName ": Copy failed!",2000)
			return -1
		}
		data:=Clipboard
		if preserveClipboard
			clipboard:=clipboardOld

	}else{
		data:=clipboard
	}




	if(grabTitle){

		loop,parse,data,`n,`r
		{
			if (A_LoopField~="檢查|單號|病歷|姓名")
				grabTitle:=false

			break
		}

		if (grabTitle){
			title:=""

			if (!childrenAcc){
				if !listHwnd
					listHwnd:=getRisList(RisHwnd)
				titleRow:=Acc_Children_first(acc_ObjectFromWindow(listHwnd))[1]
			}else{
				titleRow:=childrenAcc[1]
			}
			for k,v in acc_children(titleRow)
				title.=v.accValue "`t"

			data:=SubStr(title,1,-1) "`n" data
		}

	}

	if (outputClipboard)
		clipboard:=ret:= data
	else{
		output:=[]
		Loop,parse,data,`n
		{
			row:=[]
			;~ ,txt:=RegExReplace(A_LoopField, "^\t+", "")
			,txt:=A_LoopField
			loop,parse,txt,`t
				row.push(Trim(A_LoopField))
			output.push(row)
		}
		ret:=new DataGridTable(output)
	}

	;~ if (RisHwnd && (accNo:=getRisAccNo(RisHwnd)) && (rn:=ret.getRow("AccNo", accno).rowNo)){
		;~ controlsend,,^{Home},% "ahk_id " listHwnd
		;~ acc_children(acc_ObjectFromWindow(listHwnd))[rn].accSelect(ComObj(3,2),0)
	;~ }
	if(unselectAll)
		if childrenAcc
			unselectAllRisList(childrenAcc)
		else if listHwnd
			controlsend,,^{Home},% "ahk_id " listHwnd
	return ret

}
;~ t:=0

;~ SetBatchLines,-1
;~ _t:=A_TickCount
;~ out:=ParseDataGrid(0x250602)
;~ MsgBox % A_TickCount-_t
;~ ExitApp

	; limit can be range: [2, 5] or [7, ] or [8]
; callback: func(rowIndex, rowAcc, cellsAcc)
; parseDataGrid_f
parseDataGrid(hwnd,byref output="",is_acc=0,limit=0,sleep=0,start="",callback=""){

	if(is_acc=0)
		acc:=acc_ObjectFromWindow(hwnd)
		,rows:=acc_children(acc)
	else if(is_acc=1)
		rows:=hwnd
	rowsCount:=rows.maxIndex()
	;~ callback:=func(callback)

	if (output="")
		output:=[]
	;~ tmpArr:=[]
	;~ msgbox % start.1 "," 0+start.1 "," start.2
	;~ msgbox % acc_children(acc).maxindex()
	if (isobject(start) && !isobject(limit)){
		for k,v in rows {
			;~ if(!controlexist(hwnd,is_acc) && !acc_windowfromobject(acc_parent(hwnd[1]))){
				;~ OutputDebug, % "Data grid not exist!"
				;~ return output
			;~ }

			cells:=acc_children(v)
			if(cells[0+start.1].accValue=start.2)
				found:=k
			else if(limit && found && k-found>limit-1)
				break

			tmp:=[]
			for x,y in cells
				tmp[x]:=y.accValue
			output[x,y]:=tmp
			%callback%(k, v, cells, tmp)

			if (sleep)
				sleep % sleep
		}
	}else if (!isobject(limit)){
		if (start="" || start=0)
			start:=1
		;~ for k,v in rows:=acc_children(acc) {

		loop {
			if (limit && a_index>limit)
				break

			;~ if(!controlexist(hwnd) && !acc_windowfromobject(acc_parent(hwnd[1]))){
				;~ OutputDebug,  % "Data grid not exist!"
				;~ return output
			;~ }

			if (k:=start+a_index-1)>rowsCount
				break
			;~ if (limit && k<=limit){
			tmp:=[]
			for x,y in cells:=acc_children(row:=rows[k])
				tmp[x]:=y.accValue
			output[k]:=tmp
			;~ }
			%callback%(k, row, cells, tmp)

			if (sleep)
				sleep % sleep
		}
	}else{

		k1:=limit.1&&limit.1>=1&&limit.1<=rows.maxIndex()?limit.1:1
		if(limit.maxIndex()=1)
			k2:=k1
		else
			k2:=limit.2&&limit.2<=rows.maxindex()&&limit.2>=1?limit.2:rows.maxIndex()
		loop % abs(k2-k1)+1 {
			;~ if(!controlexist(hwnd) && !acc_windowfromobject(acc_parent(hwnd[1]))){
				;~ msgbox % "Data grid not exist!"
				;~ return output
			;~ }

			ind:=k2>=k1?a_index-1+k1:k1-a_index+1
			if (ind> rowsCount)
				break
			tmp:=[]
			for x,y in cells:=acc_children(row:=rows[ind])
				tmp[x]:=y.accValue
			output[ind]:=tmp

			%callback%(ind, row, cells, tmp)
			if(sleep)
				sleep % sleep
		}

	}

	return rowsCount
}
;~ msgbox % getRisMenu()
getRisMenu(){
	global menuHwnd=0
	EnumAddress := RegisterCallback("EnumProc")
	DllCall("EnumWindows", "Ptr", EnumAddress, "Ptr", 0)
	return menuHwnd
}

EnumProc(hwnd, lParam)
{
	global menuHwnd

	if (DllCall("GetWindowLong",Ptr,hwnd,Int,-20)=0x10008){
		;~ msgbox % hwnd "," acc_children(acc_objectfromwindow(hwnd))[1].accName
		;~ STYLE:=DllCall("GetWindowLong",Ptr,hwnd,Int,-16)
		if ((acc:=acc_children(acc_objectfromwindow(hwnd))).maxindex()=6 && acc[1].accName="瀏覽影像"){
			menuHwnd:=hwnd
			;~ msgbox % DllCall("GetWindowLong",Ptr,hwnd,Int,-16)
			return false
		}
	}

	return true  ; Tell EnumWindows() to continue until all windows have been enumerated.
}
getRisExamItemsAll(RisState=""){
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)
	if (RisState="")
		RisState:=RisOpened(), RisHwnd:=RisState[2]
	else if WinExist("ahk_id " RisState+0)
		RisHwnd:=RisState

	return parseRisExamItems(getRisExamItems(RisHwnd))
}
getRisExamItems(hwnd){
	;~ arr:=[]
	;~ if !controlId:=getNetControl(hwnd,controlName:="EXAMITEM",accName:="DataGridView",classNN:="WindowsForms",accHelp:="")
		;~ return arr
	static prvHwnd
	for k,v in getcontrols(hwnd) {
		;~ if instr(name:=getControlNameByHwnd(hwnd,v.hwnd),"EXAM"){
		if (instr(name:=getControlNameByHwnd(hwnd,v.hwnd),"EXAMITEM")) {
			return prvHwnd:=v.hwnd
			;~ acc:=acc_objectFromWindow(v.hwnd)
			;~ break
		}
	}

	return prvHwnd


	;~ ExitApp

	;~ controlgetpos,x,y,w,h,,ahk_id %controlId%
	;~ winactivate,ahk_id %hwnd%
	;~ mousemove,% x,% y
	;~ mousemove,% x+w,% y+h
	;~ pause

}

/*
	arr[1]: active exams done this time
	arr[2]: all exams done this time
*/
parseRisExamItems(hwnd){
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)

	arr:=[[],[]]

	acc:=acc_objectFromWindow(hwnd)

	if !acc
		return arr

	loop % acc_children(acc).maxindex()-1 {
		i:=a_index+1
		str:=acc_get("Value",i ".2",0,acc)
		if(str="")
			continue
		if instr(str,"※")
			arr[1].push(RegExReplace(str,"※"))
		arr[2].push(RegExReplace(str,"※"))
	}
	return arr
}
parseRisHistory(hwnd){
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)

	arr:=[]

	if !acc:=acc_objectfromwindow(hwnd)
		return arr

	;~ col:=[]
	;~ for k,v in acc_children(acc_get("Object",1,0,acc))
		;~ col[k]:="" acc_get("Value","1." k+1,0,acc)


	for i,j in rows:=acc_children(acc) {
		if i=1
			continue
		for x,y in acc_children(v)
			arr[i-1,x]:=y.accValue
	}


	;~ loop % acc_children(acc).maxIndex()-1 {
		;~ i:=a_index+1
		;~ loop % k
			;~ arr[a_index,"" col[k]]:=acc_get("Value",i "." k,0,acc)
	;~ }
	return arr

}


getRisHistory(hwnd, getprv=true){

	;~ if !controlId:=getNetControl(hwnd,controlName:="dgHisReport",accName:="DataGridView",classNN:="WindowsForms",accHelp:="")
		;~ return arr
	static prvHwnd
	for k,v in getcontrols(hwnd) {
		if (getControlNameByHwnd(hwnd,v.hwnd)="dgHisReport") {
			return prvHwnd:=v.hwnd

		}
	}
	if getprv
	return prvHwnd


}




;~ Sleep 2000
;~ t:=getSEIM()
;~ a:=1
getSEIM(ImpaxState="", recur=0){
	if !impaxstate
		impaxstate:=impaxOpened()
	if IsObject(impaxState)
		impaxImageHwnd:=impaxState[2,1]
	else
		impaxImageHwnd:=impaxState

	SEIM:=getNetControl2(impaxImageHwnd,"","DicomImageNumbers","","WindowsForms10.STATIC.app","","","",0)
	for k,v in SEIM
		if RegExMatch(text:=controlgettext(v),"i)S:\s+(\d+)\s+I:\s+(\d+)",match)
			break

	if (match1=""){
		SEIM:=getNetControl2(impaxImageHwnd,"","ClientImageNumbers","","WindowsForms10.STATIC.app","","","",0)
		for k,v in SEIM
			if RegExMatch(text:=controlgettext(v),"i)S:\s+(\d+)\/\d+\s+I:\s+(\d+)",match)
				break
	}
	;~ controlgettext,t,,ahk_id %impaxImageHwnd%
	;~ msgbox % t
	if (match1="" && recur<3){
		mousemove,-1,-1,1,R
		mousemove,1,1,1,R
		return getSEIM(ImpaxState, recur+1)
	}

	return [match1,match2]
}


RisExamEditInfo(RisHwnd="",RisExamHwnd=""){
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)

	if !rishwnd && !risexamhwnd
		risHwnd:=risOpened()[2]

	if !risexamhwnd
		risexamhwnd:=getRisReports(risHwnd)[1,1]

	Edit_GetSel(risexamhwnd,start,end)

	return {id: risexamhwnd, start: start,end: end}

}

getReportHint(risHwnd){
	static prvHwnd
	return ControlGetText((h:=acc_windowfromobject(getNetAcc(risHwnd,"REPORT_HINT","WindowsForms10.STATIC")))?(prvHwnd:=h):prvHwnd)
}

;~ MsgBox % getIndication()
;~ ExitApp
getIndication(RisHwnd="",filter=1){
	static prvHwnd

	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)


	if !WinExist(risHwnd)
		risHwnd:=risOpened()[2]

	thisHnwd:=(indication:=getNetControl2(RisHwnd,"","REPORT_HINT","","WindowsForms10.STATIC.app","","","",0))[1]?indication[1]:prvHwnd

	if regexmatch(controlgettext(thisHwnd),"Indication:([^\n\r]*)",match) || regexmatch(controlgettext(indication[1]),"Indication:([^\n\r]*)",match) {
		str:=match1
	}else{

		for k,v in getControls(RisHwnd)
			if regexmatch(v.text,"Indication:([^\n\r]*)",match) {
				str:=match1
				break
			}
	}

	str:=RegExReplace(trim(str),"[^\w\+\)]+$","")

	if(filter=1){
		str:=RegExReplace(str,"is)(.+?)(有.+)?","$1")
	}
	return trim(str)
}

getRisClinicalInfoHwnd(RisHwnd){
	static prvHwnd

	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)

	return (h:=getNetControl2(risHwnd,"","txtALL","","WindowsForms10.EDIT.app","","","",0)[1])?(prvHwnd:=h):prvHwnd
}

getRisClinicalInfoText(RisHwnd){
	t:=ControlGetText(getRisClinicalInfoHwnd(RisHwnd))
	,StrPutVar(t, ret, "utf-16")
	return ret
}

getIndicationText(RisHwnd){
	clinicalHx:=getClinicalInfo(RisHwnd)
	indication:=getIndication(RisHwnd)
	if(indication="" && RegExMatch(clinicalHx,"is)\[The Others\]:([^\r\n\※]+)",match)){
		indication:=Trim(match1)
	}
	if(indication="")
		indication:="N/A"
	return indication

}



;~ a:=getSeriesList()
;~ for k,v in a
	;~ msgbox % acc_location(a.1).x
/*
	return arr:	(screen1): [hwnd of series window, hwnd of series control]
	(screen2):
*/
getSeriesList(ExpandByPos=false){
	winget,impaxList,list,ahk_exe impax-client-main.exe ahk_class #32770,Slider1
	SeriesList:=[]
	loop % impaxList {
		;~ acc:=acc_objectfromwindow(id:=impaxList%a_index%)
		;~ if (acc_children(acc).maxindex()=10)
			SeriesList.push(id:=impaxList%a_index%)
	}

	if impaxList && !seriesList.maxIndex()
		return -1


	;~ sysget,mon,monitor,2
	;~ sysget,mon2,monitor,3
	monitorInfo:=monitorInfo()

	List:=[] , pos:=[]
	;~ Series:=[]
	for k,v in SeriesList {
		for x,y in getControls(v)
			if (y.ClassNN="SysListView321" && y.text="List1") {
				WinGetPos,x,y,,,% "ahk_id " hwnd:=y.hwnd

				if ExpandByPos
					pos[x]:=[v, hwnd]
				else
					Loop % (monitorInfo.maxIndex())
						if(x<=monitorInfo[a_index].r && x>=monitorInfo[a_index].l && y>=monitorInfo[a_index].t && y<=monitorInfo[a_index].b){
							List[A_Index]:=[v, hwnd]
							break, 2
						}

				;~ wingetpos,x,,,,% "ahk_id " y.hwnd
				;~ if (x<=monRight)
					;~ List[1]:=[v,y.hwnd]
				;~ else
					;~ List[2]:=[v,y.hwnd]
				;~ break
			}
	}

	;simple sort of two screen list according to x
	;~ pos:=[]
	;~ for k,v in List {
		;~ wingetpos,x,y,,,ahk_id %v%
		;~ pos.push(x)
	;~ }
	;~ sortedList:=[]
	;~ if pos[2]<pos[1]
		;~ sortedList:=[List[2],List[1]]
	;~ else
		;~ sortedList:=List

	if ExpandByPos
		for k,v in Pos
			list.push(v)

	return List

}

;~ a:=getSeriesName()
;~ b:=1

getSeriesName(list="",screen=2){
	if list=
		list:=getSeriesList()
	if (screen>list.length())
		screen:=list.length()
	if isobject(list)
		listAcc:=acc_objectfromwindow(listHwnd:=list[screen,2])
	else
		listAcc:=acc_objectfromwindow(list)

	seriesName:=[],ch:=acc_children(listAcc),count:=ch.maxindex()
	for k,v in ch {
		if (k=count)
			break
		RegExMatch(acc_get("Name","",k,listAcc),"is)(\d+)\s*:\s*(\d+)\s*:\s*(.*)",match)
		seriesName.push([match3,match2])
	}
	return seriesName
}


;~ a:=getViewFrame("",2)
;~ b=1
/*
	axis:
	(1,1) (1,2)
	(2,1) (2,2)

	return arr:	screen:	hwnd of frame at (x,y)
*/
getViewFrame(ImpaxHwnd="", whichScreen=""){
	if impaxHwnd=
		impaxHwnd:=impaxOpened()[2,1]

	if !impaxHwnd
		return

	if(whichScreen="")
		whichScreen:=[1,2]

	arr:=[]
	;~ screen:=0,x:=0,y:=0,xMax:=0,yMax:=0
	for k,v in getControls(impaxHwnd)
		if RegExMatch(v.ClassNN,"AfxWnd90u\d+") && RegExMatch(v.text,"Screen_(\d+)_format_\d+_Position_(\d)_(\d)",match) {
			screen:=match1+1,x:=match2+1,y:=match3+1
			if (!IsObject(whichScreen) && screen!=whichScreen)
				|| (IsObject(whichScreen) && !eleInArr(screen, whichScreen))
				continue
			if !isobject(arr[screen])
				arr[screen]:=[]
			arr[screen,x,y]:=v.hwnd
		}

	return arr
}

eleInArr(e, a){
	for k,v in a
		if(v=e)
			return true
	return false
}
;~ CoordMode,mouse,screen
;~ dragSeries(9,1,2,2)

/*
	seriesInd: 0 as cursor position
	frameX, frameY: axis of frame, one dimension axis if frameY=0
*/

dragSeries(frameX,frameY=0,seriesInd=0,screen=2,ByRef seriesList="",frame=""){
	CoordMode,mouse,screen
	if (frame="")
  		frame:=getViewFrame()
	if (seriesList="")
		seriesList:=getSeriesList()

	min_index := min(frame.length(), seriesList.length())
	if(screen>min_index)
		screen:=min_index

	frameFlat:=[]
	for k,v in frame[screen]
		for m,n in v
			frameFlat.push(n)

	if !(frameHwnd:=frame[screen,frameX,frameY]) && !(frameHwnd:=frameFlat[frameX+frameY])
		return

	listAcc:=acc_objectfromwindow(listHwnd:=seriesList[screen,2])
	,listWin:=seriesList[screen,1]
	mousegetpos,mX,mY


	if(seriesInd=0){
		seriesLoc:={x:mX,y:mY,w:0,h:0}
	}else if IsObject(seriesInd){
		seriesLoc:={x: seriesInd.x, y: seriesInd.y}
	}else{
		seriesLoc:=acc_location(listAcc,seriesInd)
		if (!seriesLoc.x || !seriesLoc.y)
			return
	}



	if (seriesInd!=0 && !IsObject(seriesInd)){
		wingetpos,x,y,w,h,ahk_id %listWin%

		xMax:=0,columns:=0
		loop % (seriesNum:=acc_children(listAcc).maxindex()-1) {
			loc:=acc_location(listAcc,a_index)
			;~ if loc.x>xMax
				;~ xMax:=loc.x
			if(loc.x>xMax){
				xMax:=loc.x
			}else{
				columns:=a_index-1
				break
			}
		}

		controlsend,,{home},ahk_id %listHwnd%
		Loop % floor(seriesInd/columns)
			controlsend,,{down},ahk_id %listHwnd%
		sleep 500
		seriesLoc:=acc_location(listAcc,seriesInd)
	}


	wingetpos,fX,fY,fW,fH,% "ahk_id " frameHwnd

	;~ sysget,mon1,monitor,% screen
	;~ sysget,mon2,monitor,% screen+1
	;~ if (fX<mon2Left){
		;~ fX+=mon1Right-mon1Left
	;~ }
	winactivate,ahk_id %listWin%
	mousemove,% seriesLoc.x+seriesLoc.w/2,% seriesLoc.y+seriesLoc.h/2,0
	;~ controlsend,,{lbutton down},ahk_id %listHwnd%
	send {lbutton down}
	sleep 100

	mousemove,% fX+fW/2,% fY+20,2
	;~ controlsend,,{lbutton up},ahk_id %frameHwnd%
	send {lbutton up}

	mousemove,% mX,% mY,0

}
mouseDragSeries(originalXY, originalWin, targetFrame){
	WinActivate,ahk_id %originalWin%
	mousemove,% originalXY.x,% originalXY.y,0
	send {LButton Down}
	Sleep 100
	WinGetPos,x,y,w,h,ahk_id %targetFrame%
	MouseMove, % x+w/2, % y+20,2
	send {LButton up}

}

;~ toggleSeriesListAll()
;~ Sleep 3000
;~ toggleSeriesListAll()
;~ ExitApp
toggleSeriesListAll(impaxState=""){
	static showSeriesButtons

	if !IsObject(impaxState)
		impaxState:=impaxOpened()

	if !WinExist("ahk_exe impax-client-main.exe") || (impaxState[1]!=2 && impaxState[2,4]!=1)
		return

	clickedButton:=[]
	if IsObject(showSeriesButtons){

		for k,v in showSeriesButtons {
			ControlClick,,% "ahk_id " v.hwnd
			clickedButton.push(v.hwnd)
		}

	}
	showSeriesButtons:=[]

	for k,v in (impaxControls:=getcontrols(impaxState[2,1])){
		if v.text="BMP_VIRTUAL_SCREEN_BUTTON" && instr(v.ClassNN,"WindowsForms10.BUTTON") {
			if !HasVal(clickedButton, v.hwnd){
				ControlClick,,% "ahk_id " v.hwnd
				clickedButton.push(v.hwnd)
			}
			showSeriesButtons.push(v.hwnd)
		}
	}
	return showSeriesButtons
}

;~ Sleep 1000

;~ toggleSeriesList("", "toggle", "mouse")
;~ Sleep 1000
;~ toggleSeriesList("", "on", 2)
;~ esc::ExitApp
;~ ExitApp
/*
action="on", "off", "toggle"
for="all", 1, 2, "mouse"
return= seriesListStored
*/
;~ Sleep 1000
;~ toggleSeriesList(ImpaxState, "toggle", "all", monitorInfo)
;~ Sleep 1000
;~ ti:=A_TickCount
;~ toggleSeriesList(ImpaxState, "toggle", "all", monitorInfo)
;~ MsgBox % A_TickCount-ti
;~ ExitApp
toggleSeriesList(impaxState="", action="toggle", for="all", ByRef monitorInfo="", activate=false){
	static seriesListStored:=[] ; button1, seriesList1, button2, seriesList2
		, impaxControlList:=[]
	;~ ti:=A_TickCount
	if !IsObject(impaxState)
		impaxState:=impaxOpened()

	if !WinExist("ahk_exe impax-client-main.exe") || (impaxState[1]!=2 && impaxState[2,4]!=1)
		return

	if IsObject(for){
		for k,v in for
			ret:=toggleSeriesList(impaxState, action, v, monitorInfo, activate)
		return ret
	}

	screenNo:=(for+0)*2-1
	if screenNo is number
	{
		if WinExist("ahk_id " seriesListStored[screenNo]) && winvisible(seriesListStored[screenNo]) && WinExist("ahk_id " seriesListStored[screenNo+1]) {
			if (((winvisible(seriesListStored[screenNo+1]))=(action="off")) || (action="toggle")){
				pressed:=releasePressed()
				ControlClick,,% "ahk_id " seriesListStored[screenNo]
				rePress(pressed)
				;~ ToolTip test
			}
			;~ MsgBox % A_TickCount-ti
			return seriesListStored
		}else{

			if !IsObject(monitorInfo)
				monitorInfo:=monitorInfo()
			;~ winget,impaxList,list,ahk_exe impax-client-main.exe
			seriesListButton:=[]
			;~ loop % impaxList {

			loop 2 {
				for k,hwnd in impaxControlList {
					impaxId:=hwnd
					for k,v in (impaxControls:=getcontrols(impaxId)){
						if v.text="BMP_VIRTUAL_SCREEN_BUTTON" && instr(v.ClassNN,"WindowsForms10.BUTTON") {

							WinGetPos,x,y,,,% "ahk_id " v.hwnd

							Loop % (monitorInfo.maxIndex())
								if(x<=monitorInfo[a_index].r && x>=monitorInfo[a_index].l && y>=monitorInfo[a_index].t && y<=monitorInfo[a_index].b){
									seriesListButton[A_Index]:=v.hwnd
									break
								}

						}
					}
				}

				if (!seriesListButton.maxIndex()){
					winget,impaxListCount,list,ahk_exe impax-client-main.exe
					;~ MsgBox % A_TickCount-ti
					impaxControlList:=[]
					loop % impaxListCount
						impaxControlList.push(impaxListCount%a_index%)
				}else
					break
			}

			for k,v in seriesListButton
				seriesListStored[k*2-1]:=v
			for k,v in seriesList:=getSeriesList()
				seriesListStored[2*k]:=v.1

			if (winvisible(sHwnd:= seriesListStored[screenNo+1])=(action="off")) || (action="toggle") {
				pressed:=releasePressed()
				ControlClick,,% "ahk_id " seriesListStored[screenNo]
				if(action="off")
					WinHide, % "ahk_id " sHwnd
				else if(action="on")
					WinShow, % "ahk_id " sHwnd
				rePress(pressed)
			}
			;~ MsgBox % A_TickCount-ti
			return seriesListStored
		}

	}else{
		if !IsObject(monitorInfo)
				monitorInfo:=monitorInfo()

		whichMonitor:=whichMonitor("","",monitorInfo)
		,which:=whichMonitor.1

		 if (for="mouse"){

			return toggleSeriesList(impaxState, action, which+0, monitorInfo, activate)
		}else if(for="all"){
			;~ ti:=A_TickCount
			if (!impaxControlList.maxIndex()){
				winget,impaxListCount,list,ahk_exe impax-client-main.exe
				;~ MsgBox % A_TickCount-ti
				impaxControlList:=[]
				loop % impaxListCount
					impaxControlList.push(impaxListCount%a_index%)
			}
			;~ MsgBox % A_TickCount-ti
			ret:=toggleSeriesList(impaxState, action, which+0, monitorInfo, activate)

			,others:=[]
			Loop % monitorInfo.maxIndex()-1
				if(A_Index+1!=which){
					others.push(A_Index+1)

				toggleSeriesList(impaxState, action, A_Index+1, monitorInfo, activate)
				}
			;~ SetTimerF("toggleSeriesList", -1, [impaxState, action, others, monitorInfo, activate])
			return ret
		}
		return
	}

	if(activate)
		winactivate,% "ahk_id " ImpaxState[2,1]

}



;~ a:=parseDataGrid(getRisList())
;~ b=1
;~ msgbox % getRisList()
getRisList(hwnd=""){
	if !hwnd
		hwnd:=risOpened()[2]

	static prvHwnd

	return (h:=getNetAcc(hwnd,"DataGridView1","WindowsForms",0,0,"",""))?(prvHwnd:=h):prvHwnd

}

RisAddToDisplayList(risHwnd="",list=""){
	if !risHwnd
		risHwnd:=risOpened()[2]

	if !list || !isobject(list)
		list:=parseDataGrid(getRisList(risHwnd))

	str:=""
	i:=list.maxIndex()

	for k,v in list.1
		if (v="照會單號") {
			ind:=k
			break
		}

	if !ind
		return
	arr:=[]
	for k,v in list
		if (k!=1 && k!=i)
			str.="ADD_TO_DISPLAY_LIST """" " v[ind] " """" "
	,arr.push(v[ind])

	str.="SYNC_DISPLAY """" " list[2,ind] " """""

	return arr

}
;~ impaxCyclicListDo()
impaxCyclicListDo(next=1,hwnd=""){
	if !hwnd
		hwnd:=impaxOpened()[2,1]
	controlclick,,% "ahk_id " getNetAcc(hwnd,next=1?"nextButton":"previousButton","WindowsForms10.BUTTON",0,0,"","")
}



RisSearchResultCount(risHwnd){
	static RisSearchResultTextHwnd
	if !controlexist(RisSearchResultTextHwnd)
		RisSearchResultTextHwnd:=getNetAcc(risHwnd,"lblSearchResult","WindowsForms10.STATIC",0,0,"","")
	text:=controlgettext(RisSearchResultTextHwnd)
	regexmatch(text,"共搜尋到\s*(\d+)\s*筆資料",match)
	return match1

}

getRisExamDate(risHwnd=""){
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)

	if IsObject(risHwnd)
		risHwnd:=risHwnd[2]
	static prvHwnd
	return ControlGetText((h:=getNetControl2(risHwnd,"","EXAM_DATE_TIME","","WindowsForms10.EDIT")[1])?(prvHwnd:=h):prvHwnd)
}

getImpaxListAcc(impaxState){
	impaxHwnd:=impaxState[2,2] | impaxState[2,3]
	return getNetAcc(impaxHwnd, "grid", "windowsForms")
}

;~ acc:=getImpaxList(impaxOpened())
;~ parseDataGrid(acc_children(acc), arr:=[], 1)

;~ ExitApp
;~ MsgBox % getRisLoginName(risOpened()[2])
;~ ExitApp


getRisLoginName(risHwnd){
	WinGetTitle,title,% "ahk_id " risHwnd
	RegExMatch(title,"^([^\-])+", match)
	return match
}

resetRisReports(RisHwnd="", RisReports=""){
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)

	if(RisReports=""){
		if !WinExist("ahk_id " RisHwnd)
			RisHwnd:=risOpened()[2]

		RisReports:=getRisReports(RisHwnd)
	}



	ControlSetText,,,% "ahk_id " RisReports[1,1]
	ControlSetText,,,% "ahk_id " RisReports[1,2]
}

; replaceFindings: 0->two new lines, 1->replace, -1->append
setReportText(findings, impression, RisReports="", replaceFindings=0, replaceImpression=true, caretToEnd=true, updateSimpleRis=true){
	global CH_RIS, __CH_RIS_CLIENT
	if (RisReports="" || !IsObject(RisReports)) || !WinExist("ahk_id " RisReports[1,1])
		RisReports:=getRisReports(risOpened()[2])

	oldReport:=EditHwnd?edit_getText(EditHwnd):ControlGetText(RisReports[1,1])

	if (replaceFindings=0)
		findings:=oldReport (oldReport=""?"":"`n`n") findings
	else if (replaceFindings=-1)
		findings:=(oldReport) findings
	if !(replaceImpression)
		impression:=Trim(ControlGetText(RisReports[1,2])) "`n" impression

	findings:=RegExReplace(findings, "(?<!\r)\n", "`r`n")

	if (updateSimpleRis){
		if(simpleRis:=WinExist("simple RIS ahk_class AutoHotkeyGUI")){
			editHwnds:=getSimpleRisEditHwnds()
		}
		if (editHwnds.length()){
			if InStr(thisPlace, "C hospital")
				__findings:=RegExReplace((new ReportImpression(findings, impression)).combine(), "(?<!\r)\n", "`r`n")
			else
				__findings:=findings

			Edit_SetText(editHwnds[2], __findings)
			,Edit_SetText(editHwnds[1], __findings)
			if(caretToEnd){
				Edit_SetSel(EditHwnds[2], len:=StrLen(__findings), len)
				,Edit_SetSel(EditHwnds[1], len, len)
			}
		}


	}
	impression:=RegExReplace(impression, "(?<!\r)\n", "`r`n")

	if InStr(thisPlace, "C hospital"){
		chFindings:=Trim(LineBreakConvert(findings, "\r?\n", "`n"))
		chImpression:=Trim(LineBreakConvert(impression, "\r?\n", "`n"))
		; In client mode CH_RIS is a proxy (no IE COM); the cross-process ControlSetText
		; below + flush() (which re-derives reportText.value from the edits) cover this write.
		if !__CH_RIS_CLIENT
			CH_RIS.inputElements.reportText.value:=chFindings "`n`nImpression:`n" chImpression
		findings:=RegExReplace(chFindings, "(?<!\r)\n", "`r`n")
		impression:=RegExReplace(chImpression, "(?<!\r)\n", "`r`n")
	}

	ControlSetText,,% findings,% "ahk_id " RisReports[1,1]
	ControlSetText,,% impression:=RegExReplace(impression, "^\s+|\s+$", ""),% "ahk_id " RisReports[1,2]

	if InStr(thisPlace, "C hospital"){
		CH_RIS.flush()
	}

	if(caretToEnd){
		Edit_SetSel(RisReports[1,1], len:=StrLen(findings), len)
		,Edit_SetSel(RisReports[1,2], len:=StrLen(impression), len)
	}
}

getRisTechName(risHwnd){
	static prvHwnd
	return (t:=(acc:=getNetAcc(risHwnd,"FID_TEXT","WindowsForms10.EDIT",0,true,"放射師","")).accValue)!="" && (prvHwnd:=acc_windowfromobject(acc))?t:acc_ObjectFromWindow(prvHwnd).accValue
}

getRisPtName(risHwnd){
	static prvHwnd
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)
	return (t:=(acc:=getNetAcc(risHwnd,"FID_TEXT","WindowsForms10.EDIT",0,true,"姓名","")).accValue)!="" && (prvHwnd:=acc_windowfromobject(acc))?t:acc_ObjectFromWindow(prvHwnd).accValue
}
getRisPtGender(risHwnd){
	static prvHwnd
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)
	return (t:=(acc:=getNetAcc(risHwnd,"FID_TEXT","WindowsForms10.EDIT",0,true,"性別","")).accValue)!="" && (prvHwnd:=acc_windowfromobject(acc))?t:acc_ObjectFromWindow(prvHwnd).accValue
}
getRisPtAge(risHwnd){
	static prvHwnd
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)
	return (t:=(acc:=getNetAcc(risHwnd,"FID_TEXT","WindowsForms10.EDIT",0,true,"年齡","")).accValue)!="" && (prvHwnd:=acc_windowfromobject(acc))?t:acc_ObjectFromWindow(prvHwnd).accValue
}
getRisStudyStatus(risHwnd){
	;~ if InStr(thisPlace, "C hospital")
		;~ return CH_RIS_Func(A_ThisFunc)
	return getRisStudyState(risHwnd)
}

getRisStudyState(risHwnd){
	static prvHwnd
	;~ if InStr(thisPlace, "C hospital")
		;~ return CH_RIS_Func(A_ThisFunc)
	return (t:=(acc:=getNetAcc(risHwnd,"FID_TEXT","WindowsForms10.EDIT",0,true,"狀態","")).accValue)!="" && (prvHwnd:=acc_windowfromobject(acc))?t:acc_ObjectFromWindow(prvHwnd).accValue
}
getClinicalInfo(RisHwnd){
	static prvHwnd
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)
	return (h:=getNetControl2(risHwnd,"","txtALL","","WindowsForms10.EDIT.app","","","",0)[1])?controlgettext(prvHwnd:=h):ControlGetText(prvHwnd)
}

getImpaxContextServerPath(){
	if FileExist(path:=A_ScriptDir "\ImpaxContextServer.exe")
		return path
	else if FileExist(path:=A_ScriptDir "\ImpaxContextServer\ImpaxContextServer.exe")
		return path
	else if FileExist(path:=RegExReplace(A_ScriptDir, "is)[\/\\][^\/\\]+$", "") "\ImpaxContextServer\ImpaxContextServer.exe")
		return path

}
;~ risSendReport(risOpened()[2])
;~ ExitApp

;~ MsgBox % acc_windowfromobject(getNetAcc(risOpened()[2],"cmdRunSave","WindowsForms10.BUTTON",0,true))
;~ ExitApp
risSendReport(risHwnd, type=3){
	static prvHwnd1, prvHwnd2, prvHwnd3
	global __win11__

	if __win11__
		return

	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc, type)


	if !WinExist("ahk_id " risHwnd)
		risHwnd:=risOpened()[2]
	while !(button:=getNetAcc(risHwnd,type=1?"cmdRunSave":type=2?"cmdRunVerify":"cmdRunVerifySend","WindowsForms10.BUTTON",0,true))
	&& !(button:=acc_objectfromwindow(getNetControl2(risHwnd,type=1?"暫存":type=2?"存檔":"存檔發送" ,"","","WindowsForms10.BUTTON")[1])) && !controlexist(prvHwnd%type%) && A_Index<4
		Sleep 50
	if(!button){
		if controlexist(prvHwnd%type%)
			button:=acc_ObjectFromWindow(prvHwnd%type%)
		else {
			MsgBox,,,% "Can't get RIS button, suggest re-open RIS!",3
			return 1
		}
	}

	prvHwnd%type%:=acc_windowfromobject(button)
	return button.accDoDefaultAction()
}

risNextStudy(RisHwnd, next=true){
	static nextHwnd0, nextHwnd1
	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc, next)

	next:=!!next

	while !(button:=getNetAcc(risHwnd, next?"cmdRunNext":"cmdRunFoword","WindowsForms10.BUTTON",0,true))
	 && !controlexist(nextHwnd%next%) && A_Index<4
	;~ && !(button:=acc_objectfromwindow(getNetControl2(risHwnd,type=1?"暫存":type=2?"存檔":"存檔發送" ,"","","WindowsForms10.BUTTON")[1])) && !controlexist(nextHwnd%next%) && A_Index<4
		Sleep 50
	if(!button){
		if controlexist(nextHwnd%next%)
			button:=acc_ObjectFromWindow(nextHwnd%next%)
		else {
			MsgBox,,,% "Can't get RIS button, suggest re-open RIS!",3
			return 1
		}
	}
	nextHwnd%next%:=acc_windowfromobject(button)
	return button.accDoDefaultAction()
}

;~ MsgBox % !( openImpax:=getNetAcc(risOpened()[2],"cmdDs3000","WindowsForms10.BUTTON"))
;~ risOpenStudyImpax(RisOpened()[2])
;~ ExitApp
risOpenStudyImpax(risHwnd="", blackFilter=true){
	global ImpaxState
	static prvHwnd

	if InStr(thisPlace, "C hospital")
		return CH_RIS_Func(A_ThisFunc)

	if !ImpaxState
		impaxstate:=impaxOpened()

	impaxHasOpened:=!!getNetAcc(ImpaxListWin:=impaxstate[2,2] | impaxstate[2,3], "_pnlStudyInfoHolder", "", 0, false)

	if impaxHasOpened
		HideImpaxSearchWin()

	if !WinExist("ahk_id " risHwnd)
		risHwnd:=risOpened()[2]
	while !(openImpax:=getNetAcc(risHwnd,"cmdDs3000","WindowsForms10.BUTTON")) && !(openImpax:=acc_objectfromwindow(getNetControl2(risHwnd,"IMPAX6","","","WindowsForms10.BUTTON")[1])) && !controlexist(prvHwnd) && A_Index<4
		Sleep 50

	if(!openImpax){
		if controlexist(prvHwnd)
			openImpax:=acc_ObjectFromWindow(prvHwnd)
		else{
			MsgBox,,,% "Can't get RIS button, suggest re-open RIS!",3
			return 1
		}
	}

	prvHwnd:=acc_windowfromobject(openImpax)

	if(blackFilter && impaxHasOpened){
		;~ settimerF("maskImpaxLoading", -1)
		maskImpaxLoading()
	}
	if (!impaxHasOpened)
		settimer,ClickImpaxReport,-5000

	return openImpax.accDoDefaultAction()
}

RisHistoryQueryByAccNo(AccNo, RisHwnd="", RisHistoryAcc=""){
	static prvRisHistoryAcc, prvRisHwnd
	if (!RisHistoryAcc) && !controlexist(acc_windowfromobject(RisHistoryAcc:=prvRisHistoryAcc)) {
		if !WinExist(RisHwnd) && !WinExist(RisHwnd:=prvHwnd)
			prvHwnd:=RisHwnd:=risOpened()[2]
		prvRisHistoryAcc:=RisHistoryAcc:=acc_ObjectFromWindow(getRisHistoryId(prvHwnd:=RisHwnd))
	}
	prvRisHistoryAcc:=RisHistoryAcc

	for k,v in rows:=acc_children(RisHistoryAcc){
		cells:=acc_children(v)
		if(k=1){
			for x,y in cells {
				if (y.accValue="照會單號"){
					AccNoCol:=x
				}else if (y.accValue="檢查日"){
					examDateCol:=x
				}else if (y.accValue="檢查名稱"){
					examNameCol:=x
				}
			}
		}else if (cells[AccNoCol].accValue=AccNo){
			return {examDate: cells[examDateCol].accValue, examName: cells[examNameCol].accValue}
		}
	}
}

;~ risOpenOldStudy(RisOpened()[2])
;~ ExitApp
risOpenOldSingleStudy(AccNo, ExamDate="", ExamName="", RisHwnd="", RisHistoryAcc=""){
	static prvRisHistoryAcc, prvRisHwnd

	HideImpaxSearchWin()

	if (!RisHistoryAcc) && !controlexist(acc_windowfromobject(RisHistoryAcc:=prvRisHistoryAcc)) {
		if !WinExist("ahk_id " RisHwnd) && !WinExist("ahk_id "  RisHwnd:=prvHwnd)
			prvHwnd:=RisHwnd:=risOpened()[2]
		prvRisHistoryAcc:=RisHistoryAcc:=acc_ObjectFromWindow(getRisHistoryId(prvHwnd:=RisHwnd))
	}
	prvRisHistoryAcc:=RisHistoryAcc

	if(examDate="" || examName="")
		res:=RisHistoryQueryByAccNo(AccNo, RisHwnd, RisHistoryAcc)
		, examDate:=res.examDate, examName:=res.examName

	examType:=InStr(examName,"CT")?"CT":InStr(examName,"MRI")?"MRI":examName

	for k,v in rows:=acc_children(RisHistoryAcc){
		cells:=acc_children(v)
		if(k=1){
			for x,y in cells {
				if (y.accValue="照會單號"){
					AccNoCol:=x
				}else if (y.accValue="檢查日"){
					examDateCol:=x
				}else if (y.accValue="檢查名稱"){
					examNameCol:=x
				}
			}
		}else if InStr(cells[examNameCol].accValue, examType) && (Trim(cells[examDateCol].accValue)=examDate){
			ImpaxContextServer_Add(Trim(cells[AccNoCol].accValue))
		}
	}
}

/*
origin.x .y .z: upper left corner of first slice
spacing.x .y .z
coord.x .y .z: lesion
dimension.x .y
framePos.x .y .w .h
*/
coordToPacs(framePos, coord, dicomInfo){
	origin:=dicomInfo.origin
	, spacing:=dicomInfo.spacing
	, dimension:=dicomInfo.dimension

	if IsObject(coord.pacsPos)
		pacsPos:=coord.pacsPos
	else{
		pacsPos:=coordToPacsPos(origin, coord, spacing)
	}

	target:=[]
	if(framePos.w/framePos.h > dimension.x*spacing.x/dimension.y/spacing.y){ ;image height = frame height
		target.y:=Floor(framePos.h * pacsPos.y / dimension.y ) + framePos.y -1
		, imageW:=framePos.h * dimension.x / dimension.y
		, target.x:=Floor(imageW * pacsPos.x / dimension.x ) + framePos.x -1
	}else{ ;image width = frame width
		target.x:=Floor(framePos.w * pacsPos.x / dimension.x ) + framePos.x -1
		, imageH:=framePos.w * dimension.y / dimension.y
		, target.y:=Floor(imageH * pacsPos.y / dimension.y ) + framePos.y -1
	}

	return {x: target.x, y: target.y}
	;~ impaxSelectImage(pacsPos.z, seriesNo, {x: target.x, y: target.y})
}

coordToPacsPos(origin, coord, spacing){
	pacsPos:=[]
	for k,v in coord
		pacsPos[k]:=Floor((v-origin[k])/spacing[k])+1
	return pacsPos
}
PacsToCoord(impaxHwnd="", aspectRatio=1){
	if !WinExist("ahk_id " impaxHwnd)
		if !WinExist("ahk_id " impaxHwnd:=impaxOpened()[2,1])
			return
	static clientImNoReg:="i)S: \d+\/(\d+) +I: \d+\/(\d+)"
	MouseGetPos,mX,mY,win,frameHwnd,2
	SEIM:=getSEIM(impaxHwnd)

	;~ for k,v in clientImNo:=getNetControl2(impaxHwnd,"","ClientImageNumbers","","WindowsForms10.STATIC.app","","","",0)
		;~ if ((t:=ControlGetText(v))!="" && RegExMatch(t, clientImNoReg, match)){
			;~ allImNo:=match2
			;~ break
		;~ }
	WinGetPos,fX,fY,fW,fH,ahk_id %frameHwnd%
	if(fW/fH > aspectRatio){ ; image height = frame height
		coordY:=(mY-fY)/fH
		,coordX:=(mX - (fW-fH*aspectRatio)/2) / (fH*aspectRatio)
	}else{
		coordX:=(mX-fX)/fW
		,coordY:=(mY-(fH-fW/aspectRatio)/2) / (fW/aspectRatio)
	}
	SEIM.push(Floor(coordX*1024)), SEIM.push(Floor(coordY*1024))
	return SEIM
}

getImpaxAllImNo(impaxHwnd){
	static clientImNoReg:="i)S: \d+\/(\d+) +I: \d+\/(\d+)"
	if !WinExist("ahk_id " impaxHwnd)
		if !WinExist("ahk_id " impaxHwnd:=impaxOpened()[2,1])
			return

	for k,v in getNetControl2(impaxHwnd,"","ClientImageNumbers","","WindowsForms10.STATIC.app","","","",0)
		if ((t:=ControlGetText(v))!="" && RegExMatch(t, clientImNoReg, match)){
			return match2
		}

}

;~ impaxSelectImage(35,8)
;~ a:=1
;~ esc::ExitApp

/*
move to series (using nextKey, prvKey), scroll to specific image
MouseMoveCoord default = {x: 0.8, y: 0.5} (relative to frame width/height of that series)
*/
impaxSelectImageCurrent(xratio, yratio, slice_number){
	return impaxSelectImage(slice_number, "", {x: xratio, y:yratio}, "", "", "", "", true)
}
;~ Sleep 2000
;~ impaxSelectImage(22, "", {x: 0.8, y:0.5}, "", "", "", "", true)
impaxSelectImage(im, SeriesNoOrFrameCoord="", MouseMoveCoord="", whichScreen="", impaxHwnd="", nextKey="{Right}", prvKey="{Left}", current=false, timeOut=10){
	CoordMode,mouse,screen
	static SEIMReg:="i)DICOM S: (\d+) +I: (\d+)", clientImNoReg:="i)S: (\d+)\/\d+ +I: (\d+)\/(\d+)"
	static lastFoundFrameHwnd

	startImpaxSelectImage:=A_TickCount


	if !WinExist("ahk_id " impaxHwnd)
		if !WinExist("ahk_id " impaxHwnd:=impaxOpened()[2,1])
			return

	winactivate, % "ahk_id " impaxHwnd
	WinGetPos,wx,wy,,,% "ahk_id " impaxHwnd

	SEIM:=getNetControl2(impaxHwnd,"","DicomImageNumbers","","WindowsForms10.STATIC.app","","","",0)
	,clientImNo:=getNetControl2(impaxHwnd,"","ClientImageNumbers","","WindowsForms10.STATIC.app","","","",0)
	if (current){
		frameHwnd:=getFocusedHwnd(), matched:=false
		for screen, v1 in frames:=getViewFrame(impaxHwnd)
			for x, v2 in v1
				for y, hwnd in v2
					if(hwnd=frameHwnd){
						matched:=true
						break, 3
					}

		if !matched
			return

		ControlGetPos,cx,cy,cw,ch,,% "ahk_id " frameHwnd
		ControlFocus,,% "ahk_id " frameHwnd
		MouseMove,% mX:=wx+cx+Floor(cw*3/4),% wy+cy+Floor(ch/2),0
		Sleep 50
	}else if IsObject(seriesNoOrFrameCoord){
		frameHwnd:=getViewFrame(impaxHwnd)[seriesNoOrFrameCoord[1], seriesNoOrFrameCoord[2], seriesNoOrFrameCoord[3]]
		if !frameHwnd
			return
		ControlGetPos,cx,cy,cw,ch,,% "ahk_id " frameHwnd
		ControlFocus,,% "ahk_id " frameHwnd
		MouseMove,% mX:=wx+cx+Floor(cw*3/4),% wy+cy+Floor(ch/2),0
		Sleep 50
	}else{ ;specify SE
		se:=seriesNoOrFrameCoord, matched:=false, recordFrameSe:=""
		Loop 15 {
			if controlexist(lastFoundFrameHwnd){

				v3:=lastFoundFrameHwnd

				ControlGetPos,cx,cy,cw,ch,,% "ahk_id " v3
				ControlFocus,,% "ahk_id " v3
				MouseMove,% mX:=wx+cx+Floor(cw*3/4),% mY:=wy+cy+Floor(ch/2),0
				Sleep 100

				for k,v in SEIM
					if ((t:=ControlGetText(v))!=""){
						if RegExMatch(t, SEIMReg, match){
							;~ if(recordFrameSe=match1) ; full loop, not found
								;~ return
							;~ if (LoopInd=2 && recordFrameSe="")
								;~ recordFrameSe:=match1
							if(match1=se){
								frameHwnd:=v3, matched:=true
								break, 2
							}
						}
						break
					}
			}

			LoopInd:=A_Index
			for k1,v1 in frames:=getViewFrame(impaxHwnd, whichScreen)
				for k2,v2 in v1
					for k3,v3 in v2 {
						;~ if(v3=lastFoundFrameHwnd)
							;~ continue

						ControlGetPos,cx,cy,cw,ch,,% "ahk_id " v3
						ControlFocus,,% "ahk_id " v3
						MouseMove,% mX:=wx+cx+Floor(cw*3/4),% mY:=wy+cy+Floor(ch/2),0
						Sleep 100

						for k,v in SEIM
							if ((t:=ControlGetText(v))!=""){
								if RegExMatch(t, SEIMReg, match){
									;~ if(recordFrameSe=match1) ; full loop, not found
										;~ return
									;~ if (LoopInd=2 && recordFrameSe="")
										;~ recordFrameSe:=match1
									if(match1=se){
										lastFoundFrameHwnd:=frameHwnd:=v3, matched:=true
										break, 5
									}
								}
								break
							}

						for k,v in clientImNo
						if ((t:=ControlGetText(v))!=""){
							if RegExMatch(t, clientImNoReg, match){
								if(recordFrameSe=match1) ; full loop, not found
									return
								if (LoopInd=2 && recordFrameSe="")
									recordFrameSe:=match1

							}
							break
						}
					}

			if(!matched){
				winactivate,% "ahk_id " impaxHwnd
				ControlFocus,,ahk_id %v3%
				send % nextKey
				Sleep 200
			}
		}
	}

	if(!matched)
		return

	;~ for k,v in SEIM
		;~ if ((t:=ControlGetText(v))!=""){
			;~ SEIMhwnd:=v
			;~ ,SEIMtext:=t
			;~ break
		;~ }

	for k,v in clientImNo
		if ((t:=ControlGetText(v))!=""){
			clientImNoHwnd:=v
			,clientImNoText:=t
			break
		}

	priorSendLevel:=a_sendlevel
	SendLevel,0
	if RegExMatch(clientImNoText, clientImNoReg, match){
		allImNo:=match3
		send {LButton Down}

		MouseMove,% mX, % mY:=impaxImNoToMousePos(im, wy+cy, ch, allImNo),3
		send {LButton up}
	}
	if im>allImNo
		im:=allImNo
	winactivate,% "ahk_id " impaxHwnd
	ControlFocus,,ahk_id %frameHwnd%
	wheelWay:=1, dist:=confirmPos:=0, tried:=0

	escHook:=InputHook("L1 V")
	,escHook.KeyOpt("{ESC}", "ES")
	,escHook.start()

	loop {
		if ((A_TickCount-startImpaxSelectImage)>1000*timeOut) || escHook.EndKey {
			tried:=999
			break
		}

		if !RegExMatch(ControlGetText(clientImNoHwnd), clientImNoReg, match) {
			if ++tried>10
				break
			Sleep 100
			continue
		}

		;~ ToolTip % match2
		if(match2=im && ++confirmPos>1)
			break
		if(dist && Abs(match2-im)>dist)
			wheelWay:=!wheelWay
		if (match2-im)*(wheelWay-0.5)>0
			send % "{WheelUp " Abs(match2-im) "}"
		else
			send % "{WheelDown " Abs(match2-im) "}"
		;~ ifwinexist,ahk_class #32770,hotkeys have been received in the last
			;~ ControlClick,Button1,ahk_class #32770,hotkeys have been received in the last
		dist:=Abs(match2-im)
		Sleep 100
		;~ mousemove,-1,-1,1,R
		;~ mousemove,1,1,1,R
	}
	SendLevel,% priorSendLevel
	if tried>10
		return

	if(MouseMoveCoord="" || !MouseMoveCoord.x || !MouseMoveCoord.y)
		MouseMoveCoord:={x:0.8, y:0.5}

	; assume square image, eg 512*512
	WinGetPos,fX,fY,fW,fH,ahk_id %frameHwnd%
	if(fW>=fH)
		MoveCoordX:=Floor(fX+(fW-fH)/2+fH*MouseMoveCoord.x)
		,MoveCoordY:=Floor(fY+fH*MouseMoveCoord.y)
	else
		MoveCoordY:=Floor(fY+(fH-fW)/2+fW*MouseMoveCoord.y)
		,MoveCoordX:=Floor(fX+fW*MouseMoveCoord.x)
	mousemove,% MoveCoordX,% MoveCoordY,1
	return [MoveCoordX, MoveCoordY]
}

;~ a:=impaxMousePosToImNo(469, 1, 936,21)
;~ b:=impaxMousePosToImNo(468, 1, 936,21)
;~ MsgBox % a "," b
;~ a:=impaxImNoToMousePos(1, 1, 936, 21, true)
;~ MsgBox % a.1 "," a.2
;~ ExitApp

impaxMousePosToImNo(mouseY, frameY, frameH, allImNo){
	return Floor((mouseY-frameY)*allImNo/frameH + 0.5)+1
}
impaxImNoToMousePos(k, frameY, frameH, allImNo, interval=false){
	range:=[k=1?frameY:impaxImNoToMousePos(k-1, frameY, frameH, allImNo)+1,k=allImNo?frameY+frameH-1:Ceil(frameH*(2*k-1)/2/allImNo)+frameY-1]
	if !interval
		return Floor((range.1 + range.2)/2)
	else
		return range
}

;~ risOpenOldStudy(RisOpened()[2])
;; only for CT MR
risOpenOldStudy(risHwnd, open=true, chooseRecent=false){
	;~ static openOldStudyRule:={CT:{}, MR: {}, XR:{}, other:{}}
	HideImpaxSearchWin()
	,regEx:=""
	for k,v in (ExamItems:=parseRisExamItems(getRisExamItems(RisHwnd)))[1]
		if RegExMatch(v, "i)(CT|MRI)[^-]+-+([\w ]+)", match)
			regEx.="((CT|MRI)[^-]+-+" match2 ")|" ((match~="i)chest|lung|thora")?"chest|lung|thora|":"")
		else if (v~="i)((CT|MRI)[^-]+-+Brain)|(Perfusion CT)")
			regEx.="((CT|MRI)[^-]+-+Brain)|(Perfusion CT)|"
		else if (v~="i)Mammogra|乳房|LOCALIZATION- BREAST|Medio-lateral oblique|Mammotome|Stereotic|tomosynthesis")
			regEx.="Mammogra|乳房|LOCALIZATION- BREAST|Medio-lateral oblique|Mammotome|Stereotic|tomosynthesis|"
		else if RegExMatch(v, "^(\w{3,}) *:", match)
			regEx.=match1 " *:|"


	regEx:="i)" SubStr(regEx,1,-1)
	if(regEx="")
		return

	examDate:=getRisExamDate(risHwnd)
	;~ ,thisAccNo:=getRisAccNo(risHwnd)

	,afterStudy:="", priorStudy:=""
	,afterStudyDate:="", priorStudyDate:=""

	escHook:=InputHook("L1 V")
	,escHook.KeyOpt("{ESC}", "ES")
	,escHook.start()

	for k,v in rows:=acc_children(RisHistoryAcc:=acc_ObjectFromWindow(getRisHistoryId(RisHwnd))){
		if escHook.EndKey
			return
		if(k=1){
			for x,y in cells:=acc_children(v) {
				if (y.accValue="照會單號"){
					AccNoCol:=x
				}else if (y.accValue="檢查日"){
					examDateCol:=x
				}else if (y.accValue="檢查名稱"){
					examNameCol:=x
				}
			}
		}else if regexmatch(ExamName:=acc_children(v)[examNameCol].accValue, regEx) {
			priorDate:=acc_children(v)[examDateCol].accValue
			if RegExReplace(priorDate,"\W","")>SubStr(RegExReplace(examDate,"\W",""),1,8){
				afterStudy:=v, afterStudyDate:=priorDate
				continue
			}

			else if RegExReplace(priorDate,"\W","")=SubStr(RegExReplace(examDate,"\W",""),1,8){
				isSameStudy:=false
				for x,y in ExamItems[1]
					if(y=ExamName){
						isSameStudy:=true
						break
					}
				if(isSameStudy)
					continue
			}

			priorStudy:=v, priorStudyDate:=priorDate
			break
		}
	}

	if(priorStudy || afterStudy){

		if(priorStudy && !afterStudy)
			v:=priorStudy
		else if !priorStudy {
			v:=afterStudy
		}else if chooseRecent {
			v:=DateDiff(RegExReplace(priorStudyDate,"\W",""),SubStr(RegExReplace(examDate,"\W",""),1,8))<DateDiff(RegExReplace(afterStudyDate,"\W",""),SubStr(RegExReplace(examDate,"\W",""),1,8)) ? priorStudy : afterStudy
		}

		if escHook.EndKey
			return

		v.accSelect(ComObj(3,3),0)

		if (open){
			if(impaxContextServerHwnd:=winexist("ahk_exe ImpaxContextServer.exe")){
			;~ if(0){
				;~ sendStr:="SYNC_DISPLAY || " thisAccNo " || "
				ImpaxContextServer_Add(Trim(acc_children(v)[AccNoCol].accValue))
				Loop {
					if !(RegExReplace(priorDate,"\W","")=RegExReplace(test:=(nearRow:=acc_children(rows[k-A_Index]))[examDateCol].accValue,"\W","") && InStr(test2:=nearRow[examNameCol].accValue,"CT"))
						break
					ImpaxContextServer_Add(Trim(nearRow[AccNoCol].accValue))
				}
				Loop {
					if !(RegExReplace(priorDate,"\W","")=RegExReplace((nearRow:=acc_children(rows[k+A_Index]))[examDateCol].accValue,"\W","") && InStr(nearRow[examNameCol].accValue,"CT"))
						break
					ImpaxContextServer_Add(Trim(nearRow[AccNoCol].accValue))
				}
				;~ sendStr.="ADD_TO_DISPLAY_LIST_WITH_PRIORS || " thisAccNo " || "
				;~ SetTimerFn("cmdContextServer", -1, [sendStr, impaxContextServerHwnd])
				;~ Send_WM_COPYDATA(impaxContextServerHwnd, 0, sendStr)
			}else{
				if escHook.EndKey
					return
				winfocus(RisHwnd)
				sleep 200
				loc:=Acc_Location(v)
				mouseclick,r,% loc.x+50,% loc.y+5,1,0
				sleep 200
				mouseclick,l,10,10,1,0,,R
			}

		}



	}

}

;~ MsgBox % ExploreObj(parseOldSEIM())
;~ ExitApp

parseOldSEIM(RisHwnd=""){
	if !WinExist("ahk_id " RisHwnd)
		RisHwnd:=risOpened()[2]

	RisReports:=getRisReports(RisHwnd)
	, oldReportText:=ControlGetText(RisReports[2,1])
	, ret:=[]
	if Trim(oldReportText)=""
		return ret

	i:=0, j:=1
	while i:=RegExMatch(oldReportText, "i)\(([^\)\n]+)\)", match, j) {
		thisSE:=""
		if (k:=RegExMatch(match1, "i)SE *(\d+) *[\/\\]?", SE)) || (k:=RegExMatch(match1, "i)^(\d+) *[\/\\]", SE))
			IMtext:=SubStr(match1, k+StrLen(SE)), thisSE:=SE1
		else
			IMtext:=match1

		if (k:=InStr(IMtext, "IM")) && (RegExReplace(IMtext:=SubStr(IMtext,k), "i)IM|[\,\; ]", "") ~= "^\d+$"){
			IMs:=RegExReplace(IMtext, "i)IM|[\,\; ]", ","), IMarr:=[]
			loop,parse,IMs,`,
				if RegExMatch(A_LoopField, "\d+", imMatch)
					IMarr.push(imMatch)

			if (IMarr.maxIndex()>0){
				if !(thisSE ~= "^\d+$")
					thisSE:=lastSE

				if thisSE!=
					for x,im in IMarr
						ret.push([thisSE, im])

				lastSE:=thisSE
			}
		}

		j:=i+StrLen(match)
	}
	return ret

}
/*
class RisClass extends Polling {

	refresh(){
		this.base.state:=RisOpened()
		if this.compareState() && this.callback
			this.callback.call()
	}
}

;~ Ris:=CriticalObject(new Ris), Impax:=CriticalObject(new Impax), RisChanged:=false
;~ ,Ris.changeCallback("t")
;~ ,impax.StartPoll()

;~ th:=ahkthread("
;~ (%
;~ #Persistent
;~ Ris:=CriticalObject(" (&Ris) ")
;~ settimer,test,500
;~ return
;~ test:
;~ ToolTip % "","" Ris.state[1,2]
;~ return
;~ )")
;~ i:=CriticalObject(new Ris)
;~ i.changeCallback("t")

;~ t(){
	;~ MsgBox
;~ }
;~ esc::ExitApp
class ImpaxClass extends Polling  {

	refresh(){
		this.base.state:=impaxOpened()
		if this.compareState() && this.callback
			this.callback.call()
	}

}

class Polling {
	__New(){
		this.callback:=""
		,this.base.state:=[]
		,this.base.priorState:=[]
		,this.refresh()

	}
StartPoll(interval=500, timeout=-1) {
		this.StopPoll()
		,this.refresh()
		,this.SetTimer(this.base.refresh,interval,[AllRis])
		if(timeout>0){
			 this.SetTimer(this.base.StopPoll, Floor(timeout)*(-1))
		}
	}

  StopPoll() {
    this.SetTimer(this.base.refresh)
	,this.SetTimer(this.base.StopPoll)
  }
  changeCallback(func, interval=500, timeout=-1){
		this.callback:=IsObject(func)?func:func(func)
		,this.base.priorState:=this.base.state
		,this.StartPoll(interval, timeout)
	}


  compareState(){
		state1:=this.base.state, state2:=this.base.priorState
		,ret:=true
		for k,v in state1
			if IsObject(v)
				for x,y in v
					ret&= (y=state2[k][x])
			else
				ret &= (v=state2[k])
		this.base.priorState:=this.base.state
		return !ret
	}
  SetTimer( Function, Period=0, ParmObject=0, Priority=0 ) {
    Static tmrs:=[] ; will hold timers that are currently running
    If IsFunc( Function ) {
      if IsObject(tmr:=tmrs[this]) ;destroy timer before creating a new one
        ret := DllCall( "KillTimer", "Ptr",0, "UPtr", tmr.tmr)
        , DllCall("GlobalFree", "Ptr", tmr.CBA)
        , ObjRemove(tmrs,this)
      if (Period = 0 || Period = "off")
        return ret ;Return as we want to turn off timer
      ; create object that will hold information for timer, it will be passed trough A_EventInfo when Timer is launched
      tmr:=tmrs[this]:={func:Function,ref:this,Period:Period="on" ? 250 : Period,Priority:Priority
                        ,OneTime:Period<0,params:IsObject(ParmObject)?ParmObject:[],Tick:A_TickCount}
      ,tmr.CBA := RegisterCallback(this.base.SetTimer,"F",4,&tmr)
      return !!(tmr.tmr  := DllCall("SetTimer", "Ptr",0, "Ptr",0, "UInt"
            , (Period && Period!="On") ? Abs(Period) : (Period := 250)
            , "Ptr",tmr.CBA)) ;Create Timer and return true if a timer was created
            , tmr.Tick:=A_TickCount
   }
  if IsObject(tmr := Object(A_EventInfo)) { ;A_Event holds object which contains timer information
    DllCall("KillTimer", "Ptr",0, "UPtr",tmr.tmr) ;deactivate timer so it does not run again while we are processing the function
    ,tmr.tick:= ErrorLevel := A_TickCount ;update tick to launch function on time
    ,func:=tmr.func,%func%(tmr.ref,tmr.params*) ; call function
    if (tmr.OneTime) ;One time timer, deactivate and delete it
      return DllCall("GlobalFree", "Ptr",tmr.CBA)
            ,ObjRemove(tmrs,tmr.ref?tmr.ref:tmr.func)
   tmr.tmr := DllCall("SetTimer", "Ptr",0, "Ptr",0, "UInt" ;reset timer
            ,((A_TickCount-tmr.Tick) > tmr.Period) ? 0 : (tmr.Period-(A_TickCount-tmr.Tick)), "Ptr",tmr.CBA)
  }
  }

}
*/


getEBMChartNo(all=false){
	if (!all){
		WinGetTitle,title,% "病歷號: ahk_class TViewerForm"
		RegExMatch(title, "病歷號: ([^ ]+) 姓名: ([^ ]+) (\d+)(M|F) 日期: (\d{4})\/(\d\d)\/(\d\d) 存取編號: ([^ ]+)", match)
		return match1
	}

	winget,list,list,% "病歷號: ahk_class TViewerForm"
	ret:=[]
	loop % list {
		WinGetTitle,title,% "ahk_id " list%a_index%
		if RegExMatch(title, "病歷號: ([^ ]+) 姓名: ([^ ]+) (\d+)(M|F) 日期: (\d{4})\/(\d\d)\/(\d\d) 存取編號: ([^ ]+)", match)
			ret.push(match1)
	}
	return ret
}

getEBMInfo(Hwnd=""){
	if Hwnd
		WinGetTitle,title,% "ahk_id " Hwnd
	else
		WinGetTitle,title,% "病歷號: ahk_class TViewerForm"

	ret:=[]

	if RegExMatch(title, "病歷號: ([^ ]+) 姓名: ([^ ]+) (\d+)(M|F) 日期: (\d{4})\/(\d\d)\/(\d\d) 存取編號: ([^ ]+)", match){
		ret.ChartNo:=match1
		,ret.name:=match2
		,ret.age:=match3
		,ret.gender:=match4
		,ret.examYear:=match5
		,ret.examMonth:=match6
		,ret.examDay:=match7
		,ret.AccNo:=match8
	}
	return ret

}

;~ selectRisListItem("", "", "J003615", true)
;~ ExitApp

;~ ParseDataGrid2()
;~ selectAllRisList()
;~ ExitApp

selectAllRisList(RIsListAccChildren=""){
	global RisState

	if(RisListAccChildren=""){
		if !WinExist("ahk_id " RisState[2]){
			RisState:=risOpened()
		}
		RisListAccChildren := acc_children(acc_ObjectFromWindow(getRisList(RisState[2])))
	}
	h:=acc_windowfromobject(RisListAccChildren[1])
	ControlFocus,% "ahk_id " h
	ControlClick,x1 y1,% "ahk_id " h
}

unselectAllRisList(RisListAccChildren=""){
	global RisState

	if(RisListAccChildren=""){
		if !WinExist("ahk_id " RisState[2]){
			RisState:=risOpened()
		}
		RisListAccChildren := acc_children(acc_ObjectFromWindow(getRisList(RisState[2])))
	}
	ControlClick,,% "ahk_id " acc_windowfromobject(RisListAccChildren[2])
	RisListAccChildren[lastInd:=RisListAccChildren.length()].accSelect(ComObj(3,3),0)
	;~ ,RisListAccChildren[lastInd].accSelect(ComObj(3,16),0)
	,RisListAccChildren[2].accSelect(ComObj(3,3),0)
	,RisListAccChildren[2].accSelect(ComObj(3,16),0)

}


;~ #include <WinGetAtCoords>
;~ coordmode,mouse,screen
;~ doubleClickRisList(2)
;~ ExitApp


activateRisListTab(tabHwnd="", risHwnd=""){
	global RisState

	if !WinExist("ahk_id " risHwnd)
		risHwnd:=(RisState:=risOpened())[2]

	if !WinExist("ahk_id " tabHwnd){
		tabHwnd:=getNetControl2(risHwnd,"報告工作清單","B_ACTIVE","報告工作清單","WindowsForms10.BUTTON.app","","","",0)[1]
	}
	controlclick,,% "ahk_id " tabHwnd
}

doubleClickRisList(index, RisListAcc="", RisListAccChildren="", risHwnd="", activateRis=true){
	return ClickRisList(index, RisListAcc, RisListAccChildren, risHwnd, activateRis, "dbclick")
}
RClickRisList(index, RisListAcc="", RisListAccChildren="", risHwnd="", activateRis=true){
	return ClickRisList(index, RisListAcc, RisListAccChildren, risHwnd, activateRis, "rclick")
}

ClickRisList(index, RisListAcc="", RisListAccChildren="", risHwnd="", activateRis=true, action="click"){
	global RisState

	if !WinExist("ahk_id " risHwnd)
		risHwnd:=(RisState:=risOpened())[2]


	if(RisListAcc=""){
		RisListAcc:=acc_ObjectFromWindow(RisListHwnd:=getRisList(risHwnd))
	}else if !IsObject(RisListAcc) {
		RisListHwnd:=RisListAcc
		,RisListAcc:=acc_ObjectFromWindow(RisListAcc)

	}else{
		RisListHwnd:=acc_windowfromobject(RisListAcc)
	}

	if(RisListAccChildren=""){
		;~ if !WinExist("ahk_id " RisState[2]){
			;~ RisState:=risOpened()
		;~ }
		RisListAccChildren := acc_children(RisListAcc)
	}

	activateRisListTab()
	,(ch:=RisListAccChildren[index]).accSelect(ComObj(3,3),0)


	;~ ,pos0:=Acc_Location(RisListAcc)
	,pos:=Acc_Location(ch)

	;~ MsgBox % acc_windowfromobject(ch) "`n" CoordGetConrol(pos.x, pos.y)+0

	;~ BlockInput,mousemove
	WinHide,ahk_exe prettyOldHx.exe
	MouseGetPos,x0,y0
	if (activateRis){
		activeWin:=risHwnd
		winactivate,% "ahk_id " RisHwnd
		WinWaitActive,% "ahk_id " RisHwnd,,3
	}
	if (activeWin:=WinActive("A")) == risHwnd{
		mousemove,% pos.x+1,% pos.y+1,0
		Loop {
			MouseGetPos,,,,con,2
			if(con==RisListHwnd)
				break
			Sleep 1
		}until A_Index>1000
		state:="active"
	}else if winvisible(RisHwnd){
		winset,Transparent,1,% "ahk_id " RisHwnd
		state:="non_active"
	}else{
		winset,Transparent,1,% "ahk_id " RisHwnd
		WinShow,% "ahk_id " RisHwnd
		state:="hidden"
	}
	winactivate,% "ahk_id " RisHwnd
	WinWaitActive,% "ahk_id " RisHwnd,,3
	;~
		ControlFocus,,% "ahk_id " RisListHwnd
		;~ mousemove,% pos.x+1,% pos.y+1,0
		if(action="dbclick")
			mouseclick,l,% pos.x+1,% pos.y+1,2,0
		else if(action="rclick")
			mouseclick,r,% pos.x+1,% pos.y+1,1,0
		else
			mouseclick,l,% pos.x+1,% pos.y+1,1,0

	;~ }else{

	;~ }

	;~ mousemove,% x0,% y0,0
	;~ BlockInput,mousemoveoff


	if(state="non_active"){
		winset,Transparent,255,% "ahk_id " RisHwnd
	}else if(state="hidden"){
		winset,Transparent,255,% "ahk_id " RisHwnd
		WinHide,% "ahk_id " RisHwnd
	}
	winactivate,% "ahk_id " activeWin

}

selectRisListItem(index="", AccNo="", chartNo="", ByRef ReportList="", RisListAccChildren="", ByRef RisState="",MultiSelect=false){
	if (RisState="")
		RisState:=risOpened()

	if (RisListAccChildren="")
		RisListHwnd:=getRisList(RisState[2])
		,RisListAcc:=acc_ObjectFromWindow(RisListHwnd)
		,RisListAccChildren:=acc_children(RisListAcc)
	else if(RisListAccChildren.length()="")
		RisListHwnd:=acc_windowfromobject(RisListAccChildren)
		,RisListACC:=RisListAccChildren
		,RisListAccChildren:=acc_children(RisListAcc)


	if (!index && AccNo="" && chartNo ="")
		index:=1

	if (AccNo chartNo = ""){
		if IsObject(index){
			RisListAccChildren[2].accSelect(ComObj(3,16),0) ;unselect
			for k,v in index
				selectRisListItem(v, "", "", doubleClick, ReportList, RisListAcc, true)
		}else{
			item:=RisListAccChildren[index+1]
			if !IsObject(item)
				return -1

			item.accSelect(MultiSelect?ComObj(3,8):ComObj(3,3),0)


		}
	}else{
		if (ReportList="")
			ReportList:=parseDataGrid2(RisListHwnd)


		for k,v in reportList[1] {
			if (v="照會單號") {
				AccNoCol:=k
			}
			if (v="病歷號") {
				chartNoCol:=k
			}
		}

		if (AccNo){
			if IsObject(AccNo){
				RisListAccChildren[2].accSelect(ComObj(3,16),0) ;unselect
				for k,v in AccNo
					selectRisListItem("", v, "", doubleClick, ReportList, RisListAcc, true)
			}else{

				for k,v in ReportList
					if (v[AccNoCol]=AccNo){
						item:=RisListAccChildren[k]
						if !IsObject(item)
							return -1

						item.accSelect(MultiSelect?ComObj(3,8):ComObj(3,3),0)
						break
					}
			}
		}else{
			if IsObject(ChartNo){
				RisListAccChildren[2].accSelect(ComObj(3,16),0) ;unselect
				for k,v in ChartNo
					selectRisListItem("", v, "", doubleClick, ReportList, RisListAcc, true)
			}else{

				for k,v in ReportList
					if (v[ChartNoCol]=ChartNo){
						item:=RisListAccChildren[k]
						if !IsObject(item)
							return -1

						item.accSelect(MultiSelect?ComObj(3,8):ComObj(3,3),0)
						break
					}
			}
		}


	}

	;~ if (doubleClick && !MultiSelect){
		;~ loc:=Acc_Location(item)

		;~ acc_children(item)[3].accDoDefaultAction()
		;~ ControlClick,% "x510 y510",% "ahk_id " RisState[2],,L,10
	;~ }
	return item

}



CaptureTextPath(){
	if FileExist(path:=a_mydocuments "\Capture2Text\Capture2Text.exe")
		|| FileExist(path:=A_ScriptDir "\Capture2Text\Capture2Text.exe")
		|| FileExist(path:=A_ScriptDir "\..\Capture2Text\Capture2Text.exe")
		|| FileExist(path:=A_ScriptDir "\..\..\Capture2Text\Capture2Text.exe")
		|| FileExist(path:=SubStr(A_ScriptDir,1,2) "\software\Capture2Text\Capture2Text.exe")
		return path
}

CaptureText(x0="",y0="",x1="",y1="", ByRef path=""){
	WinClose,ahk_exe Capture2Text.exe
	if !FileExist(path)
		path:=CaptureTextPath()
	if !FileExist(path)
		return

	if (x0="" || y0="" || x1="" || y0="") {
		monitorInfo:=monitorInfo()
		,w:=whichMonitor("","",monitorInfo)[1]
		,w:=monitorInfo[w]
		, x0:=w.l
		, y0:=w.t
		, x1:=w.r
		, y1:=w.b
	}

	oldClip:=ClipboardAll
	,tick:=a_now A_TickCount
	,clipboard:=""
	,output:=A_ScriptDir "\output" tick ".txt"
	run % """" path """ " x0 " " y0 " " x1 " " y1 " """ output """ -b"
	ClipWait,20
	if ErrorLevel
		fileread,t,% output
	else
		t:=Clipboard
	clipboard:=oldClip
	FileDelete,% output
	WinClose,ahk_exe Capture2Text.exe
	return t
}
;~ t:=A_TickCount
;~ getImpaxFrameInfo("", "LL")
;~ MsgBox % A_TickCount-t
;~ ExitApp

/*
hwnd: frame hwnd, default: second screen first frame
corners: specify LU/RU/LL/RL, default all four corner
*/
getImpaxFrameInfo(hwnd="", corners=""){
	if hwnd=
	{
		frames:=getViewFrame()
		for k,v in frames {
			hwnd:=v[1,1]
			break
		}
	}
	if !hwnd
		return {}

	WinGetPos,x,y,w,h,% "ahk_id " hwnd

	info:={}
	,cornerSize1:=250
	,cornerSize2:=400

	if corners=
		corners=LU/RU/LL/RL

	if (corners~="i)\bLU\b"){
		t:=CaptureText(x,y,x+cornerSize2-1, y+cornerSize1-1)
		,RegExMatch(t, "i)(\d+)Y *(M|F)", age_sex)
		,RegExMatch(t, "i)@(\w+)", accno)
		,RegExMatch(t, "is) *(\d+)\/(\d+)\/(\d+)\s*(\d+):(\d+):(\d+)\s*(.*)$", date)
		,info.age:=age_sex1
		,info.gender:=age_sex2
		,info.AccNo:=accno1
		,info.Date:=date1 "/" date2 "/" date3
		,info.Time:=date4 ":" date5 ":" date6
		,info.Year:=date1
		,info.Month:=date2
		,info.Day:=date3
		,info.Hour:=date4
		,info.Minute:=date5
		,info.Second:=date6
		,info.SeriesDescription:=Trim(date7)
	}
	if (corners~="i)\bRU\b"){
		t:=CaptureText(x+w-cornerSize2,y,x+w-1, y+cornerSize1-1)
		,o:=[]
		loop,parse,t,`n,`r
			if Trim(A_LoopField)!=""
				o.push(Trim(A_LoopField))
		info.hospital := o[1]
		,info.ModalityName := o[2]
		,info.studyId:=o[3]
		,info.SE:=RegExReplace(o[4], "\D", "")
		,info.IM:=RegExReplace(o[5], "\D", "")
	}
	if (corners~="i)\bLL\b"){
		t:=CaptureText(x,y+h-cornerSize1,x+cornerSize2-1, y+h-1)
		 ,o:=[]
		 ;~ mousemove,% x+cornerSize2-1,% y+h-cornerSize1
		loop,parse,t,`n,`r
			if Trim(A_LoopField)!="" && !(Trim(A_LoopField)~="i)(^\d+$)|(^thk)|(^DF)|(^W )") {
				info.StudyDescription:=Trim(A_LoopField)
				break
			}
		RegExMatch(t, "-?[\d\.]+", m)
		,info.z := m
		,RegExMatch(t, "is)thk:([\d\.]+)mm", m)
		,info.thickness:=m1
		,RegExMatch(t, "is)\r?\nDF[^\r\n\.\d]+?([\.\d]+)", m)
		,info.FOV:=m1

		,RegExMatch(t, "i)W *([\-\d]+)[^\r\n]*L *([\-\d]+)", w)
		,info.WW:=w1
		,info.WL:=w2

	}
	if (corners~="i)\bRL\b"){
		t:=CaptureText(x+w-cornerSize1,y+h-cornerSize1,x+w-1, y+h-1)
		,o:=[]
		loop,parse,t,`n,`r
			if Trim(A_LoopField)!=""
				o.push(Trim(A_LoopField))
		info.kV:=RegExReplace(o[1], "is)kV\W*(\d+).+", "$1")
		,info.mA:=RegExReplace(o[1], "is).+mA\W*(\d+)", "$1")
		,info.FocalSpot:=RegExReplace(o[2], "[^\d\.]", "")
		,info.ExposureTime:=RegExReplace(o[3], "\D", "")
		,info.ConvolutionKernel:=RegExReplace(o[4], "i)^ALG *: *", "")
	}

	return info
}

getRisSmallMenu(getActive=true){
	winget,list,list,ahk_exe Menu.exe ahk_class WindowsForms10.Window.808.app.0.33c0d9d
	ret :=[]
	loop % list
		ret.push(list%a_index%)

	if(!getActive){
		return ret
	}else{
		for k,v in ret
			if winvisible(v)
				return v
	}
}

RisNoIdle(RisHwnd=""){
	if !RisHwnd
		RisHwnd:=risOpened()[2]

	if WinActive("ahk_id " risHwnd){
		mousegetpos,,,win
		if (win=risHwnd)
		{
			mousemove,1,0,0,R
			mousemove,-1,0,0,R
			return
		}
	}

	for k,v in risControls:=GetControls(RisHwnd)
		if instr(v.ClassNN,"WindowsForms10.SysTreeView32") {
			controlsend,,{space},% "ahk_id " v.Hwnd
			break
		}
}

getRisTabs(risHwnd=""){
	if !risHwnd
		risHwnd:=risOpened()[2]
	return tabs:=getNetControl2(risHwnd,"","B_ACTIVE","","WindowsForms10.BUTTON")
	;~ if tabs[2]
		;~ acc_objectfromwindow(tabs[2]).accDoDefaultAction()

}

getSimpleImpaxUrl(chartNO, accNo){
	global loginId, loginPw
	while StrLen(chartNo)<7
		chartNo:="0" chartNO
	return "agfahc://impax-client-epr/?user=" loginId "&password=" loginPw "&domain=Agfa Healthcare&patientid=" ChartNo "&accession=" AccNo "&representation=Original"
}

;~ maskImpaxLoading()

;~ esc::ExitApp

maskImpaxLoading(impaxState="", timeOut=10){
	;~ global __SetTimerFn__maskImpaxWait
	;~ __maskImpaxClose()

	if impaxState =
		impaxState:=impaxOpened()

	if impaxState[1]!=2
		return

	w1:=impaxState[2,1]
	,w2:=impaxState[2,2] | impaxState[2,3]

	;~ if(winvisible(w1) && winvisible(w2)){
		;~ WinGetPos,x1,y1,w1,h1,ahk_id %w1%
		;~ WinGetPos,x2,y2,w2,h2,ahk_id %w2%

		;~ mask:=[]
		;~ ,mask.l:=min(x1,x2)
		;~ ,mask.t:=min(y1,y2)
		;~ ,mask.r:=(x1+w1>=x2+w2)?x1+w1:x2+w2
		;~ ,mask.b:=(y1+h1>=y2+h2)?y1+h1:y2+h2
		;~ ,mask.w:=mask.r-mask.l
		;~ ,mask.h:=mask.b-mask.t
	;~ }else{
		;~ WinGetPos,x2,y2,w2,h2,ahk_id %w2%
		;~ mask:=[]
		;~ ,mask.l:=x2
		;~ ,mask.r:=x2+w2-1
		;~ ,mask.t:=y2
		;~ ,mask.b:=y2+h2-1
		;~ ,mask.w:=w2
		;~ ,mask.h:=h2
	;~ }


	m:=monitorInfo()
	len:=m.length()

	mask:=m[len]
	,mask.l := len>1?m[2].l:m[1].l
	,mask.w :=mask.r - mask.l + 1

	if h:=WinExist("__maskImpaxLoading ahk_class AutoHotkeyGUI"){
		__maskHwnd:=h
		WinShow,ahk_id %h%
		winactivate,ahk_id %h%
		WinMove,ahk_id %h%,,% mask.l,% mask.t,% mask.w,% mask.h
		winset,trans,200, ahk_id %h%
		winset,AlwaysOnTop,on,ahk_id %h%
		;~ winset,AlwaysOnTop,off,ahk_id %h%
	}else{
		gui,__mask:+toolwindow -caption +alwaysontop +hwnd__maskHwnd
		gui,__mask:color,black
		winset,trans,200,% "ahk_id " __maskHwnd
		gui,__mask:Show,% "x" mask.l " y" mask.t " w" mask.w " h" mask.h " noactivate",__maskImpaxLoading

	}
	__setMaskImpaxHotkey()
	setTimerF("__maskImpaxClose", (-1000)*timeOut)
	;~ ,__SetTimerFn__maskImpaxWait:=SetTimerF("__maskImpaxWait", 500, [impaxState, __maskHwnd, timeOut, A_TickCount])
}

__setMaskImpaxHotkey(on=true){
	global
	Hotkey,IfWinExist,__maskImpaxLoading ahk_class AutoHotkeyGUI
	Hotkey,~WheelDown,__maskImpaxCloseCheck,% on?"on":"off"
	Hotkey,~WheelUp,__maskImpaxCloseCheck,% on?"on":"off"
	Hotkey,~LButton,__maskImpaxCloseCheck,% on?"on":"off"
	Hotkey,IfWinExist

}

__maskImpaxCloseCheck(){
	MouseGetPos,,,win
	if(WinGetTitle(win)="__maskImpaxLoading")
		__maskImpaxClose()
}

__maskImpaxClose(){
	;~ global __SetTimerFn__maskImpaxWait
	;~ SetTimerFn(__SetTimerFn__maskImpaxWait,0)

	if !hwnd:=WinExist("__maskImpaxLoading ahk_class AutoHotkeyGUI")
		return

	;~ WinFade(hwnd)

	WinClose,__maskImpaxLoading ahk_class AutoHotkeyGUI
	__setMaskImpaxHotkey(false)
	MouseGetPos,,win,con,2
	winget,pName,ProcessName,ahk_id %win%
	if (pName~=MatchPacsProcessName()){
		winactivate,ahk_id %win%
		ControlFocus,,ahk_id %con%
	}
}

__maskImpaxWait(impaxState, __maskHwnd, timeOut, tickcount){
	global __SetTimerFn__maskImpaxWait
	elapsed:=(A_TickCount-tickcount)/1000
	;~ ToolTip % elapsed
	if (elapsed<1.5)
		return

	if !WinExist("ahk_id " __maskHwnd) || impaxState[1]!=2{
		__maskImpaxClose()
		return
	}

	h:=impaxState[2,2] | impaxState[2,3]
	WinGetPos,x,y,,,ahk_id %h%
	;~ ToolTip % x "," y
	if (timeOut && elapsed>timeOut) || (x<0 && y<0){
		SetTimerFn(__SetTimerFn__maskImpaxWait,0)
		Sleep 500
		__maskImpaxClose()
		return
	}

}


compareList(ByRef ReportList, ByRef RisListAcc, ByRef RisListHwnd, colName="AccNo", ByRef RisListAccChildren=""){
	if !WinExist("ahk_id " RisListHwnd)
		RisListHwnd:=getRisList(risHwnd:=risOpened()[2])
		,RisListAcc:=acc_ObjectFromWindow(RisListHwnd)
		,RisListAccChildren:=acc_children(RisListAcc)
	if !RisListAcc
		RisListAcc:=acc_ObjectFromWindow(RisListHwnd)

	if !RisListAccChildren
		rows:=RisListAccChildren:=acc_children(RisListAcc)
	else
		rows:=RisListAccChildren

	lastInd:=rows.maxIndex()
	,colNo:=ReportList.getColNo(colName)

	if (colNo="") || (ReportList[1][ColNo] != acc_children(rows[1])[ColNo].accValue)
		|| lastInd<2
		|| (ReportList[2][ColNo] != acc_children(rows[2])[ColNo].accValue) {
			ReportList:=ParseDataGrid2(RisListHwnd, risHwnd, RisListAccChildren)

		}

	return ReportList

	Loop {
		v:=acc_children(rows[lastInd-A_Index+1])[ColNo].accValue
		if (v="")
			continue
		if (v!=ReportList[lastInd-A_Index+1][ColNo])
			return ReportList:=ParseDataGrid2(RisListHwnd, risHwnd, RisListAccChildren)
		else
			break
	}

}


getRisSearchDate(risHwnd="", type=0){
	if !WinExist("ahk_id " risHwnd)
		risHwnd:=risOpened()[2]
	d:=getNetAcc(risHwnd,"FID_LABEL","STATIC",-1,1,type?"結束日期":"起始日期").accName
	if(d!=""){
		if RegExMatch(d, "(\d{4})\/(\d\d?)\/(\d\d?)", m)
			return m1 SubStr("0" m2,-2) SubStr("0" m3,-2)
		else if RegExMatch(d, "(\d\d?)\/(\d\d?)\/(\d{4})", m)
			return m3 SubStr("0" m1,-2) SubStr("0" m2,-2)
	}
}

getRisSearchStartDate(risHwnd=""){
	return getRisSearchDate(risHwnd, 0)
}
getRisSearchEndDate(risHwnd=""){
	return getRisSearchDate(risHwnd, 1)
}

;~ setRisSearchDate("20190807")
;~ ExitApp



setRisSearchStartDate(date, risHwnd="", control="main"){
	return setRisSearchDate(date, risHwnd, 0, control)
}
setRisSearchEndDate(date, risHwnd="", control="main"){
	return setRisSearchDate(date, risHwnd, 1, control)
}
setRisSearchDate(date, risHwnd="", type=0, control="main"){
	if !WinExist("ahk_id " risHwnd)
		risHwnd:=risOpened()[2]
	if (control="main")
		acc:=getNetAcc(risHwnd,"FID_LABEL","STATIC",-1,1,type?"結束日期":"起始日期")
		,controlHwnd:=acc_windowfromobject(acc)
	else
		controlHwnd:=Control
		,acc:=acc_objectfromwindow(controlHwnd)

	date:=RegExReplace(date, "\D", ""),yr:=SubStr(date,1,4),mn:=SubStr(date,5,2),dy:=SubStr(date,7,2)
	,oldDate:=acc.accName
	if(oldDate="")
		return
	else if RegExMatch(oldDate, "(\d{4})\/(\d\d?)\/(\d\d?)", m)
		NormalDateFormat:=true

	;~ loop 10
		;~ if !InStr(oldDate, testDigit:=A_Index-1)
			;~ break
	if (NormalDateFormat)
		setDate:=yr "/" mn "/" dy
	else
		setDate:= mn "/" dy "/" yr

	setDate_:=RegExReplace(setDate, "^0|(?<=\/)0", "")
	loop 4 {
		;~ if (A_Index>1){
			;~ ControlFocus,,ahk_id %controlHwnd%
			;~ controlsend,,{right},ahk_id %controlHwnd%
		;~ }
		ControlFocus,,ahk_id %controlHwnd%
		controlsend,,% setDate,ahk_id %controlHwnd%
		Sleep 100
		if (setDate_==acc.accName)
			break
		else
			controlsend,,% "{right}{right}",ahk_id %controlHwnd%
	}

}

setRisSearchFields(RisState, query_dict, search=true){
	static examTypes:=["All","Plain","Special","CT","MR"]
		, examStatus:=["All","NotReport","Recorded","Save","NotSend","Sent","Unassigned","NotVerify"]
		, hospital:=["All", "CC", "T0", "T2", "T3", "T4", "T5", "Y0"]
		, hospital2:=["All", "CC", "T", "N", "J", "H", "C", "Y"]
		, examFrom:=["All", "E", "HMC", "I", "O"]

	if (!query_dict.SetCapacity(0))
		return

	if query_dict.haskey("QuickButton"){
		return RisQuickButton(RisState, query_dict["QuickButton"])
	}
	risHwnd:=IsObject(RisState)?RisState[2]:RisState
	,controls:=GetControls(risHwnd)


	for x,y in query_dict {
		if(x="ChartNo"){
			for k,v in controls
				if (instr(v.text,"病歷號") && instr(v.classNN,"WindowsForms10.STATIC") && !instr(controls[k-3].text,"照會單號")){
					thisHwnd:=controls[k+1].hwnd
					controlfocus,,% "ahk_id " thisHwnd
					controlsettext,,% y,% "ahk_id " thisHwnd
					;~ controlsend,,{Enter},% "ahk_id " thisHwnd
					;~ return
					break
				}
		}else if (x="ExamType"){
			if (modalityHwnd:=getNetControl2(RisState[2],"檢查類別","FID_LABEL","檢查類別","WindowsForms10.STATIC.app","","","",1)[1]) {
				control,choose,% (y:=HasVal(examTypes, y))?y:1,,% "ahk_id " modalityHwnd
			}
		}else if (x="ExamStatus"){
			if (modalityHwnd:=getNetControl2(RisState[2],"狀態","FID_LABEL","狀態","WindowsForms10.STATIC.app","","","",1)[1]) {
				control,choose,% (y:=HasVal(examStatus, y))?y:1,,% "ahk_id " modalityHwnd
			}
		}else if (x="Hospital"){
			if (modalityHwnd:=getNetControl2(RisState[2],"檢查地","FID_LABEL","檢查地","WindowsForms10.STATIC.app","","","",1)[1]) {
				control,choose,% (y:=HasVal(hospital, y))?y:(y:=HasVal(hospital, query_dict["Hospital"]))?y:1,,% "ahk_id " modalityHwnd
			}
		}else if (x="VS"){
			if (y="YCHH")
				y:="陳醫師HC"
			if (reportDrHwnd:=getNetControl2(RisState[2],"報告醫師","FID_LABEL","報告醫師","WindowsForms10.STATIC.app","","","",1)[1]) {
				control,choosestring,% (y:=trim(y))=""?"所有報告醫師":y " ",,% "ahk_id " reportDrHwnd
			}
		}else if (x="ExamFrom"){
			if (modalityHwnd:=getNetControl2(RisState[2],"診別","FID_LABEL","診別","WindowsForms10.STATIC.app","","","",1)[1]) {
				control,choose,% (y:=HasVal(examFrom, y))?y:1,,% "ahk_id " modalityHwnd
			}
		}else if(x="StartDate"){
			setRisSearchStartDate(y, risHwnd)
		}else if(x="EndDate"){
			setRisSearchEndDate(y, risHwnd)
		}
	}

	if(search){
		controlclick,,% "ahk_id " getNetControl2(risHwnd,"","cmdSearch","","WindowsForms10.BUTTON.app","","","",0)[1]
	}
}

RisQuickButton(RisState, which){
	static RisButtons:={ERCT: "cmdER_CT"
									, ER: "cmdER"
									, CT: "cmdCT"
									, MR: "cmdMR"
									, Special: "cmdSC"
									, XR: "cmdXR"
									, plain: "cmdXR"
									, notReport: "cmdNOT_REPORT"
									;~ , unread: "cmdNOT_REPORT"
									, notSend: "cmdNOT_SEND"
									;~ , unSent: "cmdNOT_SEND"
									, save: "cmdSAVE"
									;~ , saved: "cmdSAVE"
									, notVerify: "cmdNOT_VERIFY"}
	if (which="")
		return
	risHwnd:=IsObject(RisState)?RisState[2]:RisState
	if RisButtons.haskey(which) && (acc:=getNetAcc(risHwnd,RisButtons[which],"WindowsForms10.BUTTON.app"))
		acc.accDoDefaultAction()
}

RisOpenMoreDialog(){
	if h:=winexist("ahk_class #32770", "已有程式執行中,是否確定重複開啟程式")
		controlclick,Button1,ahk_id %h%
}

StopRisLogin(){
	settimer,RisOpenMoreDialog,off
}

checkNewRisLogin(oldRis, logincallback, initTick=""){
	if(initTick!="" && A_TickCount-initTick>120000)
		return logincallback.call(0)

	for k,v in risOpened(1)[2]
		if !HasVal(oldRis, v){
			if !IsObject(logincallback)
				logincallback:=func(logincallback)
			return logincallback.call(v)
		}
	SetTimerFn("checkNewRisLogin", -1000, [oldRis, logincallback, initTick])
}

RisLogin(RisId="", RisPw="", logincallback="", RisPath="", state=0, initTick=""){
	if (initTick!="" && A_TickCount-initTick>120000){
		settimer,StopRisLogin,-1
		return
	}else if(initTick="")
		initTick:=A_TickCount

	if (state=0){
		settimer,StopRisLogin,-60000
		if !risOpened(1)[1].length() {
			if !FileExist(RisPath) && !(RisPath:=GetRisPath(1)[1])
				RisPath:=GetRisPath()

			settimer,RisOpenMoreDialog,100
			try {
				SplitPath,RisPath,,wdir
				run,% RisPath,% wdir
				SetTimerFn("RisLogin", -500, [RisId, RisPw, logincallback, RisPath, 1, initTick])
			}catch
				settimer,StopRisLogin,-1
		}else{
			RisLogin(RisId, RisPw, logincallback, RisPath, 2, initTick)
		}
	}else if(state=1){
		if !risOpened(1)[1].length() {
			SetTimerFn("RisLogin", -500, [RisId, RisPw,logincallback, RisPath, 1, initTick])
		}else{
			RisLogin(RisId, RisPw, logincallback, RisPath, 2, initTick)
		}
	}else if(state=2){
		settimer,RisOpenMoreDialog,off
		risHwnd:=risOpened(1)[1,1]
		,RisIdHwnd:=getNetAcc(risHwnd, "USER_ID", "WindowsForms10.EDIT",0,0)
		,RisPwHwnd:=getNetAcc(risHwnd, "PASSWORD", "WindowsForms10.EDIT",0,0)
		,usernameHwnd:=getNetAcc(risHwnd, "USER_NAME", "WindowsForms10.EDIT",0,0)
		,oldRis:=risOpened(1)[2]
		WinShow,ahk_id %risHwnd%
		winactivate,ahk_id %risHwnd%
		WinWaitActive,ahk_id %risHwnd%,,2
		ControlFocus,,ahk_id %RisIdHwnd%
		controlsend,,{Home}+{End},ahk_id %RisIdHwnd%
		ControlSendRaw,,% risid,ahk_id %RisIdHwnd%
		ControlSend,,{tab},ahk_id %RisIdHwnd%
		loop {
			Sleep 100
		}until ControlGetText(usernameHwnd) || (A_Index>30)
		winactivate,ahk_id %risHwnd%
		WinWaitActive,ahk_id %risHwnd%,,2
		ControlFocus,,ahk_id %RisPwHwnd%
		ControlSendRaw,,% RisPw,ahk_id %RisPwHwnd%
		ControlSend,,{Enter},ahk_id %RisPwHwnd%
		SetTimerFn("checkNewRisLogin", 1000, [oldRis, logincallback, initTick])
	}

}
risGoToStudyCall(ChartNo, AccNo, ReportList="", RisSearchFields="", RisListAccChildren="", RisReports="", RisState="", loginHospital="", RisImpaxLoginInfo="", hwnd=0){
	risGoToStudy(ChartNo, AccNo, ReportList,RisSearchFields, RisListAccChildren, RisReports, hwnd, loginHospital,RisImpaxLoginInfo, 2.5)
}
risGoToStudy(ChartNo, AccNo, ReportList="",RisSearchFields="", RisListAccChildren="", RisReports="", RisState="", loginHospital="", RisImpaxLoginInfo="", state=0){
	if(state=0){
		risHwnd:=IsObject(RisState)?RisState[2]:RisState
		if !WinExist("ahk_id " risHwnd){
			return risGoToStudy(ChartNo, AccNo, ReportList,RisSearchFields, RisListAccChildren, RisReports, RisState, loginHospital,RisImpaxLoginInfo, 1)
		}else{
			return risGoToStudy(ChartNo, AccNo, ReportList,RisSearchFields, RisListAccChildren, RisReports, risHwnd, loginHospital,RisImpaxLoginInfo, 2)
		}
	}else if(state=1){  ; login Ris
		h_idx:=(loginHospital~="T0|N總院")?1:(loginHospital~="T4|H分院")?2:(loginHospital~="Y0|Y分院")?3:(AccNo~="^(T[023]|TH)")?1:(AccNo~="^(T4|HH)")?2:(AccNo~="^(Y0|YH)")?3:(chartNo~="^(\d|N|J)")?1:(chartNo~="^(H)")?2:(chartNo~="^(Y)")?3:1
		, RisId:=RisImpaxLoginInfo.ris[h_idx].user
		, RisPw:=RisImpaxLoginInfo.ris[h_idx].pw
		if(risid="" || rispw=""){
			OutputDebug,No RIS ID/PW!
			return -1
		}
		RisLogin(RisId, RisPw, Func("risGoToStudyCall").bind(ChartNo, AccNo, ReportList,RisSearchFields, RisListAccChildren, RisReports, RisState, loginHospital,RisImpaxLoginInfo))
	}else if(state<3){  ;get current accno
		if WinExist("ahk_id " RisReports[1,1]) && (accNo=getRisAccNo(RisState)){
			return 0
		}else
			return risGoToStudy(ChartNo, AccNo, ReportList,RisSearchFields, RisListAccChildren, RisReports, RisState, loginHospital,RisImpaxLoginInfo, state+1)
	}else if(state<4){ ; get ris list
		if (state=3.5 && RisSearchFields!="" ){
			Loop
				Sleep 100
			until (RisListHwnd:=getRisList(RisState)) || A_Index>200
			ReportList:=""
			,setRisSearchFields(RisState, RisSearchFields)
			loop {
				if(lastcount = (thiscount:=acc_ObjectFromWindow(RisListHwnd).accChildCount))
					break
				else
					lastcount:=thisCount
				Sleep 100
			}until A_Index>200
		}

		if(ReportList=""){
			RisListHwnd:=getRisList(RisState)
			if(RisListAccChildren="")
				RisListAccChildren:=acc_children(acc_ObjectFromWindow(RisListHwnd))
			ReportList:=ParseDataGrid2(RisListHwnd, RisState, RisListAccChildren)
			if(ReportList.data.length()<2){
				OutputDebug,Empty Report List
				return -1
			}
		}

		currentRow:=ReportList.getRow("AccNo", thisAccNo:=getRisAccNo(RisState))
		,nextRow:=ReportList.getRow("AccNo", nextAccNo:=AccNo)
		if(!nextRow.rowNo){
			OutputDebug,% "Can't find next AccNo: " AccNo
			return -1
		}
		if(currentRow.rowNo && currentRow.rowNo=nextRow.rowNo-1){
			risNextStudy(RisState)
			return 0
		}
		if(RisListAccChildren="")
			RisListAccChildren:=acc_children(acc_ObjectFromWindow(RisListHwnd))
		doubleClickRisList(nextRow.rowNo, RisListHwnd, RisListAccChildren, RisState, false)
	}
}
;~ esc::ExitApp


/* check if IMPAX opened
	arr[1]=0	no IMPAX
	arr[1]=1, arr[2,1]=hwnd of login window
	arr[1]=2, arr[2,1]=hwnd of image window
	arr[1]=2, arr[2,2]=hwnd of list & text window
	arr[1]=2, arr[2,3]=hwnd of list window
	arr[1]=2, arr[2,4]=which type of active IMPAX window (1:image, 2:list, 3:text)
	arr[1]=2, arr[2,5]=which configuration of IMPAX windows (1 for one window, 2 for double window)
*/
;~ HideImpaxSearchWin()
;~ esc::ExitApp
HideImpaxSearchWin(hide=true){
	static m:=monitorInfo()[1]
	impaxState:=impaxOpened()
	if impaxState[1]!=2 || impaxState[2,5]=1
		return



	if(hide){
		loop 2 {
			win:=impaxState[2,A_Index+1]
			if !win || !winvisible(win)
				continue
			WinGetPos,x,y,w,h,ahk_id %win%
			if x+w/2>=m.l && y+h/2>=m.t
				WinHide,ahk_id %win%
		}
		SetTimerF("HideImpaxSearchWin", -10000, [false])
	}else{
		SetTimerF("HideImpaxSearchWin", "off")
		loop 2 {
			win:=impaxState[2,A_Index+1]
			if !win
				continue
			DllCall("SetWindowPos", "Ptr", win, "Ptr",1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0053)
			;~ WinShow,ahk_id %win%
		}
	}
}

;~ MsgBox % RisChartNoMatchPacs()
;~ ExitApp

; if match any pacs chartno -> true
RisChartNoMatchPacs(RisState="", ImpaxState="", ByRef risChartNo="", ByRef impaxChartNo=""){
	risHwnd:=getLastRis(RisState)
	,risChartNo:=getRisChartNo(risHwnd)
	,impaxChartNo:=(new activePacs).getChartNo()
	return risChartNo=impaxChartNo
}


class activePacs {
	; This owner is also used for temporary metadata lookups. Its INFINITT
	; child has bound timers which outlive it unless explicitly disposed.
	__Delete(){
		if IsObject(this.INFINITTViewer)
			this.INFINITTViewer.DisposeTimers()
	}

	__New(hwnd=""){
		monitors:=monitorInfo()
		,x:=monitors[2].l+10
		,y:=monitors[2].t+10
		,o:=Acc_ObjectFromPoint("", x, y)

		winget,ProcessName,ProcessName,% "ahk_id " h:=hwnd && WinExist("ahk_id " hwnd)?hwnd:acc_windowfromobject(o)

		if (ProcessName="impax-client-main.exe")
			this.type:="impax"
			, this.impaxState:=impaxOpened()
		else if (ProcessName~="i)WebViewerComSrvEC.exe|WEBVIE~1.EXE")
			this.type:="EBM"
			,this.EBMViewer:=new EBMViewer("", h)
		else if (ProcessName~="i)Miv2Lib.exe")
			this.type:="GEUV"
			,this.GEViewer:=new GEUV("", h)
		else if (ProcessName~="i)G3PACS.exe")
			this.type:="INFINITT"
			,this.INFINITTViewer:=new INFINITT_PACS(h)
		else{
			for k,v in alttabList:=AltTab_window_list() {
				winget,pName,ProcessName,% "ahk_id " v.hwnd
				if (pName="impax-client-main.exe"){
					this.type:="impax"
					, this.impaxState:=impaxOpened()
					break
				}else if (pName~="i)WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
					this.type:="EBM"
					,this.EBMViewer:=new EBMViewer("", v.hwnd)
					break
				}else if (pName~="i)Miv2Lib.exe"){
					this.type:="GEUV"
					,this.GEViewer:=new GEUV("", v.hwnd)
					break
				}else if (pName~="i)G3PACS.exe"){
					this.type:="INFINITT"
					,this.INFINITTViewer:=new INFINITT_PACS(v.hwnd)
					break
				}
			}
		}
	}

	getChartNo(){
		switch this.Type {
			case "impax":
				return getImpaxChartNo(this.impaxState)
			case "ebm":
				return this.EBMViewer.ChartNo
			case "geuv":
				return this.GEViewer.ChartNo
			case "INFINITT":
				return this.INFINITTViewer.ChartNo_
		}
	}

	getAccNo(){
		switch this.Type {
			case "impax":
				return getImpaxAccNo(this.impaxState)
			case "ebm":
				return this.EBMViewer.AccNo
			case "geuv":
				return this.GEViewer.AccNo
			case "INFINITT":
				return this.INFINITTViewer.AccNo_
		}
	}

	getExamDate(){
		switch this.Type {
			case "impax":
				return getImpaxExamDate(this.impaxState[2,1])[1]
			case "ebm":
				return this.EBMViewer.ExamDate
			case "geuv":
				return this.GEViewer.ExamDate
			case "INFINITT":
				return this.INFINITTViewer.ExamDate_
		}

	}
}


;~ MsgBox % getImpaxQueueNumber()[2]
;~ ExitApp
getImpaxQueueNumber(impaxState=""){
	if WinExist("ahk_id " impaxState)
		impaxHwnd:=impaxState
	else if WinExist("ahk_id " impaxState[2,1])
		impaxHwnd:=impaxState[2,1]
	else
		impaxHwnd:=impaxOpened()[2,1]

	e:=getNetAcc(impaxHwnd, "itemIndicatorLabel", "WindowsForms10.STATIC.app.0.2bf8098")
	RegExMatch(ControlGetText(acc_windowfromobject(e)), "(\d+)\D+(\d+)", m)
	return [m1, m2]
}

;~ a:=getRisSameStudyAccNos()
;~ ExitApp
getRisSameStudyAccNos(RisState=""){
	risHwnd:=getLastRis(RisState[2])
	,AccNos:=[]
	,AccNos[AccNo:=getRisAccNo(risHwnd)]:=1
	,ExamDate:=getRisExamDate(risHwnd)
	,chartNo:=getRisChartNo(risHwnd)
	,RisHxHwnd:=getRisHistoryId(risHwnd)
	,parseDataGrid(RisHxHwnd, RisHx:=[])
	,RisHx:=new DataGridTable(RisHx)
	,examDateCol:=RisHx.getColNo("檢查日")
	,ChartNoCol:=RisHx.getColNo("病歷號碼")
	,AccNoCol:=RisHx.getColNo("AccNo")
	for k,v in RisHx.data
		;~ ToolTip % "," v[ExamDateCol] "," v[ChartNoCol]
		if(v[ExamDateCol]=SubStr(ExamDate,1,10) && v[ChartNoCol]=chartNo)
			AccNos[v[AccNoCol]]:=1
	ret:=[]
	for k,v in AccNos
		ret.push(k)
	return ret
}


getImpaxSearchListHwnd(ImpaxState=""){
	if !WinExist("ahk_id " hwnd:=impaxState) && !WinExist("ahk_id " hwnd:=impaxState[2,2]) && !WinExist("ahk_id " hwnd:=ImpaxState[2,3]) {
		hwnd:=impaxOpened()[2,2] | impaxOpened()[2,3]
	}
	listGrid:=getNetAcc(hwnd,"grid","WindowsForms10.Window",0,false)

	return listGrid
}

getImpaxSearchList(ImpaxSearchListHwnd=""){
	if !WinExist("ahk_id "  ImpaxSearchListHwnd)
		ImpaxSearchListHwnd:=getImpaxSearchListHwnd()

	listGrid := acc_ObjectFromWindow(ImpaxSearchListHwnd)
	ret:=[]
	for k,v in acc_children(listGrid)
		if (v.accChildCount){
			row:=[]
			for x,y in acc_children(v) {
				row.push(Trim(y.accValue))
			}
			ret.push(row)
		}

	return new DataGridTable(ret)
}

;~ hwnd:=getImpaxSearchListHwnd()
;~ WinRestore,% "ahk_id " WinGetRoot(hwnd)
;~ __maskImpaxClose()
;~ ImpaxSearchListDo({StudyDate: "2020/11/02"}, "dbclick")
;~ esc::ExitApp
ImpaxSearchListDo(searchCriteria, action="select", ByRef ImpaxSearchList="", mouseMove=false){
	static title1:=["檢查狀態", "病患姓名 (音譯)", "身份證字號", "病歷號碼", "檢查流水號", "影像檢查設備", "檢查之日期", "檢查之時間", "影像", "檢查之敘述", "病患生日", "建立的日期時間"]
	, title2:=["status", "patientName", "patientID", "chartNo", "accNo", "modality", "studydate", "studytime", "numberOfImages", "StudyDescription", "PatientBirthday", "StudyCreateDate"]


	if !ImpaxSearchList || !ImpaxSeriesList.length()
		ImpaxSearchList:=acc_children(acc_ObjectFromWindow(getImpaxSearchListHwnd()))

	deleteKey:=[]
	for k,v in searchCriteria
		if (v="")
			searchCriteria.delete(k)
		else if (i:=HasVal(title2, k)){
			searchCriteria[title1[i]]:=v
			,deleteKey.push(k)
		}

	for k,v in deleteKey
		searchCriteria.delete(v)

	ind:=0
	for k,row in ImpaxSearchList {
		if !row.accChildCount
			continue
		ind+=1
		if (ind=1){
			titles:=[]
			for x, cell in acc_children(row)
				if v:=Trim(cell.accValue)
					titles[v]:=x
			continue
		}

		cells:=acc_children(row)

		match:=true
		for i,v in searchCriteria
			if (titles.haskey(i)){
				cellValue:=cells[titles[i]].accValue
				,criteria:=v
				if (SubStr(criteria,1,1)~="[\<\>\!]")
					match:=dateCriteria(cellValue, criteria)
				else if !(InStr(cellValue, criteria)) && !(InStr(cellValue, RegExReplace(criteria, "\/0", "/")))
					match:=false

				if !match
					break
			}

		if !match
			continue

		if (action="select"){
			row.accSelect(ComObj(3,3),0)
			if (mousemove){
				pos:=acc_location(row)
				mousemove,% pos.x+pos.w//2,% pos.y+pos.h//2,0
			}
		}else if (action="dbclick"){

			WinActivateClickControl(row, "", 2)

			;~ pos:=Acc_Location(row)

			;~ WinShow,% "ahk_id " searchListHwnd:=((ImpaxState:=impaxOpened())[2,2] | impaxstate[2,3])
			;~ winactivate,% "ahk_id "  searchListHwnd
			;~ WinWaitActive,% "ahk_id " searchListHwnd,,2
			;~ mouseclick,L,% pos.x+pos.w//2,% pos.y+pos.h//2,2,0
			;~ WinGetPos,x,y,,,% "ahk_id " hwnd:=acc_windowfromobject(row)
			;~ mousemove,% x,% y
			;~ mousemove,% pos.x+pos.w//2,% pos.y+pos.h//2
			;~ ControlClick,% "x" pos.x+pos.w//2-x " y" pos.y+pos.h//2-y,% "ahk_id " hwnd,,left,2

			;~ mousemove,% x,% y, 0
		}
		return ind
	}
}



;~ configRisFrames()
;~ esc::ExitApp
configRisFrames(){
	RisState:=RisOpened()
	if RisState[1]!=2
		return

	if h:=WinExist("simpleRIS_main ahk_class AutoHotkeyGUI"){
		winget,pid,pid,% "ahk_id " h
		simpleRisPath:=GetModuleFileNameExW(pid)
		PostMessage,0x10101,,,,% "ahk_id " h
		TaskKill("prettyOldHx.exe")
		,TaskKill("simpleRIS_.exe")
		,TaskKill("simpleRIS_patch.exe")
		,reopen_simpleRis:=true
	}

	mon:=monitorInfo()[1]
	RisHwnd:=RisState[2]
	hh:=mon.h, ww:=mon.w


	winget,MinMax,MinMax,% "ahk_id " RisHwnd
	if (MinMax!=1){
		WinMove,% "ahk_id " RisHwnd,,% mon.l,% mon.t
		WinMaximize,% "ahk_id " RisHwnd
	}


	if goReportTab(RisHwnd, 3)=-1
		return
	escHook:=InputHook("L1 V")
	,escHook.KeyOpt("{ESC}", "ES")
	,escHook.start()
	Loop 4 {
		winfocus(RisHwnd)

		Moved:=configRisFrames_adjustSize(getNetAcc(RisHwnd, "EXAMITEM", "WindowsForms"), hh//6, ww//2)
		| configRisFrames_adjustSize(getNetAcc(RisHwnd, "dgHisReport", "WindowsForms"), hh//5)
		| configRisFrames_adjustSize(acc_parent(acc_parent(getNetAcc(RisHwnd, "HISTORY_EXAM_TEXT", "WindowsForms"))), hh//5)
		| configRisFrames_adjustSize(getNetAcc(RisHwnd, "tabQuery", "WindowsForms10.SysTabControl32"), hh*8//15)
		| configRisFrames_adjustSize(getNetAcc(RisHwnd, "TabPage6", "WindowsForms10"), hh*2//5)
		| configRisFrames_adjustSize(getNetAcc(RisHwnd, "TabPage6", "WindowsForms10", 6), hh//50)
		;~ configRisFrames_adjustSize(getNetAcc(RisHwnd, "FlowLayoutPanel2", "WindowsForms10"), hh//50)
		| configRisFrames_adjustSize(getNetAcc(RisHwnd, "pnlRemarkEvent", "WindowsForms10"), hh//50)
		| configRisFrames_adjustSize(getNetAcc(RisHwnd, "pnlDoctorConsultation", "WindowsForms10"), hh//50)
		| configRisFrames_adjustSize(acc_parent(acc_parent(getNetAcc(RisHwnd, "FlowLayoutPanel3", "WindowsForms10"))), hh/25)
		| configRisFrames_adjustSize(getNetAcc(RisHwnd, "grpEXAM", "WindowsForms10"), hh//7)
		;~ configRisFrames_adjustSize(getNetAcc(RisHwnd, "grpIMPRESSION", "WindowsForms10"), hh//8)
		if(!Moved) || escHook.EndKey
			break
	}
	escHook.stop()
	if (reopen_simpleRis){
		run,% simpleRisPath
	}
	ShowToolTip("Done!")
}

configRisFrames_adjustSize(acc, h, w=""){
	loc:=acc_location(acc)
	Moved:=false

	if (!acc || !ControlExist(acc_windowfromobject(acc)))
		return false

	if(w && loc.w!=w){
		;~ BlockInput,MouseMove
		MouseMove,% loc.x+loc.w-1,% loc.y+loc.h//2,0
		Loop {
			MouseMove,1,0,1,R
		}until A_Cursor="Unknown" || A_Index>10
		MouseMove,1,0,1,R
		MouseClickDrag,L,0,0,% w-loc.w,0,3,R
		;~ BlockInput,MouseMoveOff
		Moved:=true
	}


	loc:=acc_location(acc)

	if (h!=loc.h){
		;~ BlockInput,MouseMove
		MouseMove,% loc.x+loc.w//2,% loc.y+loc.h-1,0
		Loop {
			MouseMove,0,1,1,R
		}until A_Cursor="Unknown" || A_Index>10
		MouseMove,0,1,1,R
		MouseClickDrag,L,0,0,0,% h-loc.h,3,R
		;~ BlockInput,MouseMoveoff
		Moved:=true
	}
	return Moved
}


ImpaxToggleImageText(ImpaxState=""){
	if (impaxstate="")
		impaxState:=impaxOpened()

	if (Impax:=ImpaxState)[1]!=2
		return
	if(Impax[2,5]=2){
		if(Impax[2,4]=1){
			;~ for k,v in (impaxControls:=getcontrols(Impax[2,1])){
				;~ if (v.text="文字" || v.text="Text" || v.text="影像" || v.text="Image") && instr(v.ClassNN,"WindowsForms10.BUTTON") {
			;~ controlclick,,% "ahk_id " v.hwnd
			;~ return
				;~ }
			;~ }
			if(getNetAcc(ImpaxListWin, "_pnlStudyInfoHolder", "", 0, false)){
				getNetAcc(ImpaxState[2,1], "ShowTextArea", "Button").accDoDefaultAction()
			}else{
				MouseGetPos,x,y
				loc:=acc_location(getNetAcc(ImpaxState[2,1], "ShowTextArea", "Button"))
				mouseclick,L,% loc.x+loc.w//2,% loc.y+loc.h//2,1,0
				mousemove,% x, % y,0
			}

		}else if(Impax[2,4]=3){
			winactivate,% "ahk_id " Impax[2,1]
		}
	}else if(Impax[2,5]=1){
		for k,v in (impaxControls:=getcontrols(Impax[2,1])){
			if (v.text="文字" || v.text="Text" || v.text="影像" || v.text="Image") && instr(v.ClassNN,"WindowsForms10.BUTTON") {
				controlclick,,% "ahk_id " v.hwnd
				return
			}
		}
	}
}


;~ ClickImpaxReport()
ClickImpaxReport(i=0){
	global escHook

	ImpaxState:=impaxOpened()
	ImpaxListWin:=ImpaxState[2,2] | ImpaxState[2,3]

	if(getNetAcc(ImpaxListWin, "_pnlStudyInfoHolder", "", 0, false)){
		;~ MsgBox
		return
	}

	if !escHook
		escHook:=InputHook("L1 V")
		,escHook.KeyOpt("{ESC}", "ES")
		,escHook.start()


	ShowTextButton:=getNetAcc(ImpaxState[2,1], "ShowTextArea", "Button", 0, false)

	if !(ShowTextButton) {
		;~ ToolTip % A_TickCount
		if i<15 && !escHook.EndKey
			SetTimerF("ClickImpaxReport",-1000, [i+1])
		return
	}

	MouseGetPos,x,y
	loc:=acc_location(acc_objectfromwindow(ShowTextButton))
	Loop{
		if escHook.EndKey
			return
		else if ((h:=acc_windowfromobject(acc_objectfrompoint("", loc.x, loc.y)))!=ShowTextButton){
			WinClose,__maskImpaxLoading
			winactivate,% "ahk_id " impaxOpened[2,1]
		}
		else
			break
	}
	MouseMove,% loc.x+loc.w//2,% loc.y+loc.h//2,0
	MouseMove,1,1,1,R
	click
	mousemove,% x, % y,0

	Loop {
		Sleep 100
		if escHook.EndKey
			return
	} until getNetAcc(ImpaxListWin, "_pnlStudyInfoHolder", "", 0, false) || A_Index>50

	winactivate,% ImpaxState[2,1]

	return
	;~ if (testHwnd:=getNetAcc(ImpaxListWin, "_pnlStudyInfoHolder", 0, false))
		;~ return
	;~ Loop 2
		;~ ImpaxToggleImageText(ImpaxState)
}

getImpaxChartNoSearchInput(Impax=""){
	if impax=
		impax:=impaxOpened()

	for k,v in (impaxControls:=getcontrols(id2:=Impax[2,2]|Impax[2,3])){
		if k<2
			continue
		if instr(v.classNN,"WindowsForms10.EDIT.app") && ((impaxControls[k-1].text="病歷號碼" ) || (impaxControls[k-1].text="Patient ID")) {
			return v.hwnd
		}
	}
}


;~ ImpaxSearch()
ImpaxSearch(chartNo="", studyDate="",ImpaxState="", action="select"){
	if ImpaxState=
		impaxState:=impaxOpened()
	Impax:=ImpaxState
	static stopSelectingRow:=true

	if chartNo=
		chartNo:=getRisChartNo()

	studyDate:=dateFormat(studyDate, "yyyy/M/d")
	WinShow,% "ahk_id " id2:=Impax[2,2]|Impax[2,3]
	winactivate,% "ahk_id " id2
	bar:=ImpaxBar(id2)
	wingetpos,,,,h,ahk_id %id2%
	if !(bar.h>h-37)
		controlclick,,% "ahk_id " bar.hwnd
	if (impaxChartnoControl:=impaxChartNoSearchHwnd:=getImpaxChartNoSearchInput(Impax)){
		controlfocus,,% "ahk_id " impaxChartNoSearchHwnd
		controlget,selectedText,Selected,,,% "ahk_id " impaxChartNoSearchHwnd
		if !selectedText
			ControlClick,,% "ahk_id " impaxChartNoSearchHwnd,,l,1
	}

	acc_objectfromwindow(impaxChartnoControl).accValue:=chartNo
	,impaxSearchListHwnd:=getimpaxSearchListHwnd(ImpaxState)
	,pImpaxSearchListCount:=acc_objectfromwindow(impaxSearchListHwnd).accChildCount
	controlsend,,{enter},% "ahk_id " impaxChartnoControl
	impaxSearchListLoc:=acc_location(acc_objectfromwindow(impaxSearchListHwnd))
	CoordMode,mouse,Screen
	mousemove,% impaxSearchListLoc.x+impaxSearchListLoc.w//2,% impaxSearchListLoc.y,0
	if (studyDate || (getRisChartNo((RisState:=RisOpened())[2])=chartNo && (studyDate:=SubStr(getRisExamDate(RisState[2]),1,10)))){
		ToolTip % "Selecting row ... "
		stopSelectingRow:=false
		Loop {
			if acc_objectfromwindow(impaxSearchListHwnd).accChildCount!=pImpaxSearchListCount
				break
			Sleep 100
		}until A_Index>15 || stopSelectingRow
		ImpaxSearchListDo({studyDate: studyDate}, action, ImpaxSearchListChildren:=[], true)

		ToolTip
	}
	return
}

;~ getImpaxOpenedStudyCount()
;~ ExitApp
getImpaxOpenedStudyCount(impaxState=""){
	if ImpaxState=
		impaxState:=impaxOpened()

	CountLabels:=getNetControl2(impaxState[2,1], "", "studyPositionLabel", "", "WindowsForms10.STATIC")
	CountLabels:=OrderByPos(CountLabels)
	ret:=[]
	for k,l in CountLabels {
		if RegExMatch(tmp:=ControlGetText(l), "(\d+)\D+(\d+)", match)
			ret.push([match1, match2])
	}
	return ret
}



CH_RIS_Func(FuncName, args*){
	global CH_RIS, __win11__, __CH_RIS_CLIENT
	; Client mode (set __CH_RIS_CLIENT before first use): don't spin up a local IE-polling
	; owner. Forward the call to the autorun owner over IPC; it runs the switch below
	; against the real CH_RIS and returns a serializable result (scalars / hwnds / arrays).
	; risSendReport is interactive (GetKeyState / MsgBox) and must run in this (client)
	; process, using IPC only for the owner-object operations — see CH_RIS_RisSendReport_Client.
	if (__CH_RIS_CLIENT) {
		if (FuncName = "risSendReport")
			return CH_RIS_RisSendReport_Client(args*)
		r := CH_RIS_Call("func", {fn: FuncName, args: args})
		return (IsObject(r) && r.ok) ? r.value : ""
	}
	if !CH_RIS
		CH_RIS:=new CH_RIS_REPORT()

	switch FuncName {
		case "getRisReports":
			return [[CH_RIS.gui.exam_edit, CH_RIS.gui.impression_edit],[CH_RIS.gui.old_exam_edit, CH_RIS.gui.old_impression_edit]]
		case "getRisReportsHwnd":
			return [CH_RIS.gui.exam_edit]
		case "getRisAccNoHwnd":
			return CH_RIS.gui.accno_edit_auto
		case "getRisSheetNo":
			return CH_RIS.accno
		case "getRisChartNoHwnd":
			return CH_RIS.gui.chartno_edit_auto
		case "getRisChartNo":
			return CH_RIS.chartNo
		case "parseRisExamItems":
			return [[t:=CH_RIS.examname],[t]]
		case "getRisExamItemsAll":
			return [CH_RIS.examname]
		case "parseRisHistory":
			return CH_RIS.pacs_hx.data
		case "RisExamEditInfo":
			Edit_GetSel(risexamhwnd:=CH_RIS.gui.exam_edit,start,end)
			return {id: risexamhwnd, start: start,end: end}
		case "getRisClinicalInfoHwnd":
			return CH_RIS.gui.memo_edit_auto
		case "getIndication":
			return CH_RIS.remark
		case "getRisExamDate":
			return CH_RIS.examtime
		case "resetRisReports":
			Edit_SetText(CH_RIS.gui.exam_edit, "")
			,Edit_SetText(CH_RIS.gui.impression_edit, "")
			,CH_RIS.inputElements.reportText.value:=""
		case "getRisPtName":
			return CH_RIS.patname
		case "getRisPtGender":
			return CH_RIS.gender
		case "getRisPtAge":
			return CH_RIS.age
		case "getClinicalInfo":
			return CH_RIS.memo
		case "risSendReport":
				if (__win11__){
					risSaveReportWin11()
					return
				}

				if(GetKeyState("Alt")){
					ShowToolTip("Alt pressed: stop sending report")
					return
				}
			;~ if (args[1]=3)
			global fastMammoScreenReport
				if (!fastMammoScreenReport)
				flush_error:=CH_RIS.flush()
				,CH_RIS.activate()

				if (flush_error){
					return flush_error
				}
				if !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI"){
					to_send:=false
					shiftArm:=false
					if GetKeyState("shift")
						to_send:=true, shiftArm:=true, ShowToolTip("Shift: sending + suppressing PACS next study")
					else if WinExist("YCH_MAMMO_AHK_main ahk_class AutoHotkeyGUI"){
						to_send:=true
					}
					else {
						MsgBox,262145, ,report?,5
						IfMsgBox,Ok
							to_send:=true
						if (to_send && GetKeyState("shift"))
							shiftArm:=true
					}

					if (shiftArm && IsFunc("ArmSendRptIEBlock")) {
						fn := "ArmSendRptIEBlock"
						%fn%(CH_RIS.wb.hwnd)
					}

					if(to_send){
						CH_RIS.inputElements.saveReport.Click()
						Sleep 400
						CH_RIS.reset(1)
						;~ PostMessage,0x2024,,,,simpleRIS_main ahk_class AutoHotkeyGUI
						;~ PostMessage,0x2024,,,,simpleRIS__main ahk_class AutoHotkeyGUI
					}
				}else{
					CH_RIS.inputElements.saveReport.Click()
					CH_RIS.reset(1)
					;~ PostMessage,0x2024,,,,simpleRIS_main ahk_class AutoHotkeyGUI
					;~ PostMessage,0x2024,,,,simpleRIS__main ahk_class AutoHotkeyGUI
				}
				;~ MsgBox
		case "risNextStudy":
			if (args[1])
				CH_RIS.inputElements.nextExam.Click()
			else
				CH_RIS.inputElements.priorExam.Click()
		case "risOpenStudyImpax":
			return CH_RIS.inputElements.openImage.Click()
		Default:
			return Exception("Not implemented!")
	}
}

; Client-side risSendReport. Mirrors the risSendReport case in CH_RIS_Func, but keeps the
; interactive bits (GetKeyState / MsgBox / ShowToolTip) in this process and routes only the
; owner-object operations (flush / activate / save click / reset / wb hwnd) to the autorun
; owner via IPC. Reached only when __CH_RIS_CLIENT is set (see CH_RIS_Func).
CH_RIS_RisSendReport_Client(args*){
	global __win11__, fastMammoScreenReport
	sendType:=(args[1]="") ? 3 : args[1]
	if (__win11__){
		risSaveReportWin11()
		return
	}
	if (GetKeyState("Alt")){
		ShowToolTip("Alt pressed: stop sending report")
		return
	}
	flush_error := ""
	readyText := ""
	recoveryState := ""
	if (!fastMammoScreenReport){
		r := CH_FlushReport()
		flush_error := (IsObject(r) && r.ok) ? "" : (IsObject(r) ? r.error : "flush failed")
		if (IsObject(r) && r.ok) {
			readyText := r.reportText
			recoveryState := r.state
			CH_RIS_Client_RecordRecovery(recoveryState, readyText, "draft")
		}
		CH_Activate(true)
	}
	if (flush_error)
		return flush_error

	if !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI"){
		to_send := false
		shiftArm := false
		if GetKeyState("shift")
			to_send := true, shiftArm := true, ShowToolTip("Shift: sending + suppressing PACS next study")
		else if WinExist("YCH_MAMMO_AHK_main ahk_class AutoHotkeyGUI")
			to_send := true
		else {
			MsgBox, 262145, , report?, 5
			IfMsgBox, Ok
				to_send := true
			if (to_send && GetKeyState("shift"))
				shiftArm := true
		}

		if (shiftArm && IsFunc("ArmSendRptIEBlock")){
			fn := "ArmSendRptIEBlock"
			%fn%(CH_WbHwnd())
		}

		if (to_send){
			if !CH_RIS_Client_ReportReady(sendErr, readyText) {
				ShowToolTip("Stop send: " sendErr, 3000)
				return
			}
			clickResult := CH_RIS_Client_ClickAndRecord(recoveryState, readyText, sendType)
			if !(IsObject(clickResult) && clickResult.ok) {
				ShowToolTip("Stop send: RIS save click failed", 3000)
				return clickResult
			}
			Sleep 400
			CH_Reset(1)
		}
	}else{
		if !CH_RIS_Client_ReportReady(sendErr, readyText) {
			ShowToolTip("Stop send: " sendErr, 3000)
			return
		}
		clickResult := CH_RIS_Client_ClickAndRecord(recoveryState, readyText, sendType)
		if !(IsObject(clickResult) && clickResult.ok) {
			ShowToolTip("Stop send: RIS save click failed", 3000)
			return clickResult
		}
		CH_Reset(1)
	}
	return clickResult
}

CH_RIS_Client_RecordRecovery(state, reportText, status, forceSnapshot:=false){
	if !IsObject(state)
		state:=CH_GetState()
	if !IsObject(state)
		return false
	accNo:=""
	try accNo:=state.accNo
	if (Trim(accNo)="" || Trim(reportText)="")
		return false
	return SimpleRISRecovery_Save(accNo, reportText, status, state, forceSnapshot)
}

CH_RIS_Client_ClickAndRecord(ByRef recoveryState, reportText, sendType:=3){
	if !IsObject(recoveryState)
		recoveryState:=CH_GetState()
	pendingStatus:=(sendType=3) ? "send_pending" : "save_pending"
	CH_RIS_Client_RecordRecovery(recoveryState, reportText, pendingStatus, true)
	clickResult:=CH_ClickSave()
	if (IsObject(clickResult) && clickResult.ok) {
		completedStatus:=(sendType=3) ? "finalized"
			: (sendType=2) ? "verified_saved" : "temporarily_saved"
		CH_RIS_Client_RecordRecovery(recoveryState, reportText, completedStatus, true)
	}
	return clickResult
}

CH_RIS_Client_ReportReady(ByRef errorMsg, ByRef reportText){
	global Mammo_CH_ExpectedReport
	errorMsg := ""
	if (reportText = "") {
		r := CH_RIS_Call("get_input_value", {name: "reportText"})
		if !(IsObject(r) && r.ok) {
			errorMsg := "cannot verify RIS report"
			return false
		}
		reportText := r.value
	}
	txt := Trim(RegExReplace(reportText, "\r", ""))
	if (txt = "") {
		errorMsg := "RIS report is empty"
		return false
	}
	if RegExMatch(txt, "i)^\s*(Impression:|IMP:)\b") {
		errorMsg := "RIS report has impression only"
		return false
	}
	if IsObject(Mammo_CH_ExpectedReport) {
		expectedExam := CH_RIS_Client_NormalizeReportText(Mammo_CH_ExpectedReport.exam)
		expectedImpression := CH_RIS_Client_NormalizeReportText(Mammo_CH_ExpectedReport.impression)
		if (expectedExam != "" && !CH_RIS_Client_TextMatchesExpectedReport(txt, expectedExam, expectedImpression)) {
			errorMsg := "RIS report is missing expected mammo report text"
			return false
		}
	}
	return true
}

CH_RIS_Client_TextMatchesExpectedReport(currentText, expectedExam, expectedImpression:="") {
	currentText := CH_RIS_Client_NormalizeReportText(currentText)
	if (currentText = "")
		return false
	if RegExMatch(currentText, "i)^\s*(Impression:|IMP:)\b")
		return false

	probes := CH_RIS_Client_FindingProbes(expectedExam)
	if (probes.MaxIndex()) {
		for _, probe in probes {
			if !InStr(currentText, probe)
				return false
		}
	} else {
		probe := CH_RIS_Client_FirstProbe(expectedExam)
		if (probe != "" && !InStr(currentText, probe))
			return false
	}

	impProbe := CH_RIS_Client_FirstProbe(expectedImpression)
	if (impProbe != "" && !InStr(currentText, impProbe))
		return false
	return true
}

CH_RIS_Client_FindingProbes(expectedExam) {
	probes := []
	Loop, Parse, expectedExam, `n, `r
	{
		line := CH_RIS_Client_CleanProbeLine(A_LoopField)
		if (line = "")
			continue
		if RegExMatch(line, "i)^(INDICATION|COMPARISON|MAMMOGRAPHY VIEWS|FINDINGS)\b")
			continue
		probes.Push(SubStr(line, 1, 120))
		if (probes.MaxIndex() >= 2)
			break
	}
	return probes
}

CH_RIS_Client_FirstProbe(text) {
	Loop, Parse, text, `n, `r
	{
		line := CH_RIS_Client_CleanProbeLine(A_LoopField)
		if (line != "")
			return SubStr(line, 1, 120)
	}
	return ""
}

CH_RIS_Client_CleanProbeLine(line) {
	line := Trim(line)
	line := RegExReplace(line, "^\s*[-*]\s+", "")
	line := RegExReplace(line, "\s+", " ")
	return Trim(line)
}

CH_RIS_Client_NormalizeReportText(text) {
	text := RegExReplace(text, "\r\n?", "`n")
	text := RegExReplace(text, "[ `t]+", " ")
	text := RegExReplace(text, "\n{3,}", "`n`n")
	return Trim(text)
}

risSaveReportWin11(){

}
