﻿#SingleInstance,force
SetTitleMatchMode,2
SetBatchLines,-1
DetectHiddenWindows,on
OnExit,OnExit

tunnelpw := "MOCK_PASSWORD"
SetTimer,routine,500
if !path:=findVNCpath() {
	MsgBox % "Can't find tvnviewer.exe (TightVNCViewer)!"
	ExitApp
}
gosub loadList
;~ gosub putty

gui,Font,s14,Verdana
gui,Add,Checkbox,% "visVPN " (WinExist("ahk_exe dsNetworkConnect.exe")?"checked":""),Inside VPN?
for k,v in list
	gui,Add,button,% "gconnect vb" A_Index " w200 h60",% v.1
gui,Show,AutoSize,TightVNC List
return

routine:
IfWinExist,PuTTY Exit Confirmation
	ControlClick,Button1
return

connect:
;~ if !WinExist("ahk_exe putty.exe"){
	;~ Run,% "putty.exe -load 10.0.0.1 -pw " tunnelpw " -L 5900:" ip ":5900",% """" A_ScriptDir """"
	;~ winwait,ahk_exe putty.exe,,15
	;~ if(ErrorLevel){
		;~ MsgBox % "Can't connect SSH!"
		;~ return
	;~ }
	;~ WinSetTitle,ahk_exe putty.exe,,% "PuTTY: 10.0.0.1 10.0.0.1 " ip
;~ }else if !WinExist(ip " ahk_exe putty.exe")
	;~ WinClose,ahk_exe putty.exe
	;~ goto connect
	;~ return
;~ }

RegExMatch(A_GuiControl, "\d+", match)
,ip:=list[match,2]
,pw:=list[match,3]
gui,Submit,NoHide
if (isVPN){
	if (!WinExist(RegExReplace(ip, ":5900", "") " ahk_exe putty.exe"))
		gosub putty
	run,% "tvnviewer.exe 127.0.0.1::" (8000+match) " -password=" pw 
}else
	run,% "tvnviewer.exe " RegExReplace(ip, ":", "::") " -password=" pw 
return

if (path:=findVNCpath())="" {
	MsgBox % "Can't find tvnviewer.exe of TightVNC"
	return
}
run % path
winwait,TightVNC ahk_exe tvnviewer.exe,,3
if (ErrorLevel){
	MsgBox % "Can't run tvnviewer.exe"
	return
}
ControlSetText,Edit1,% ip,TightVNC ahk_exe tvnviewer.exe
Sleep 100
Controlsend,Button17,{Enter}
;~ ControlClick,Button17,TightVNC ahk_exe tvnviewer.exe
;~ ControlClick,連線,TightVNC ahk_exe tvnviewer.exe
;~ ControlClick,Connect,TightVNC ahk_exe tvnviewer.exe
Loop  
	Sleep 100
until (hwnd:=WinExist("TightVNC ahk_class #32770", "登入")) || (hwnd:=WinExist("TightVNC ahk_class #32770", "Log On")) || (hwnd:=WinExist("VNC Authentication ahk_class #32770", "Log On")) (A_Index>100)
ControlSetText,Edit1,% pw,% "ahk_id " hwnd
controlsend,Button1,{Enter}
;~ ControlClick,Button1,% "ahk_id " hwnd
return


findVNCpath(){
	if FileExist(VncPath:=A_ScriptDir "\tvnviewer.exe") 
		|| FileExist(VncPath:=A_MyDocuments "\TightVNC\tvnviewer.exe")
		|| FileExist(VncPath:=A_ProgramFiles "\TightVNC\tvnviewer.exe"){
	}else
		VncPath:=""
	
	return VncPath
}

putty:
WinClose,ahk_exe putty.exe
forwarding:="",AllIpTxt:=""
for k,v in AllIp
	forwarding.=" -L " (8000+k) ":" v  
	, AllIpTxt.=RegExReplace(v, ":5900", "") " "
Run,% """" A_ScriptDir "\PuTTY\putty.exe"" -N -load 10.0.0.1 -pw " tunnelpw forwarding,% A_ScriptDir "\PuTTY"
Sleep 4000
winwait,ahk_exe putty.exe,,15
if(ErrorLevel){
	MsgBox % "Can't connect SSH!"
	ExitApp
}
WinSetTitle,ahk_exe putty.exe,,% "PuTTY: 10.0.0.1 10.0.0.1 " AllIpTxt
WinHide,ahk_exe putty.exe
return

loadList:
list:=[], allIp:=[]
,csvPath:=A_ScriptDir "\TVN_list.txt"
Loop,read,% csvPath
{
	arr:=[]
	Loop,Parse,A_LoopReadLine,`,
	{
		arr.push(Trim(A_LoopField))
	}
	if !(arr[2]~=":\d+")
		arr[2].=":5900"
	list.push(arr)
	,AllIp.push(arr[2])
}
return

GuiClose:
ExitApp
return

OnExit:
gui,Destroy
WinClose,ahk_exe putty.exe
Sleep 1000
Loop 10 {
	gosub routine
	Sleep 300
	if !WinExist("PuTTY Exit Confirmation")
		break
}
ExitApp