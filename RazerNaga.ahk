#NoEnv
#SingleInstance,force
SetBatchLines,-1
process,Priority,,h
DetectHiddenWindows, On
SetTitleMatchMode,2
coordmode,mouse,screen
coordmode,pixel,screen
#NoTrayIcon
SendMode Input
#inputlevel,2
onexit,onexit
; Does not use CH_RIS — opt out of owning a local (IE-polling) CH_RIS. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <SetWindowsHookEx>
#include <risImpax>
#include <ImpaxContextServer>
#include <DoublyLinkedList>
#include <jxon>
#include <WM_COPYDATA>
#InstallKeybdHook
#InstallMouseHook
#include <resetHotstringBuffer>
resetHotstringBufferHook()

; set main gui for messaging
gui,main:Default
gui,+hwndguihwnd
WinSetTitle,% "ahk_id " guihwnd,,RazerNaga_main

default:={"1":"!{left}", "2":"!{right}", "3":"{home}", "4":"^w", "5":"^t", "6":"{end}", "7":"", "8":"", "9":"", "0":"!{tab}", "-":"", "=":""}
,impax:={"1":"{del}", "2":"_+!^Up", "3":"{NumLock}", "4":"{left}", "5":"{right}", "6":"FirefoxDownScroll", "7":"", "8":"", "9":"FirefoxUpScroll", "0":"", "-":"", "=":""}
,ris:={"1":"", "2":"_+!^Up", "3":"!#{tab}", "4":"", "5":"", "6":"", "7":"", "8":"", "9":"", "0":"", "-":"", "=":""}
,ebm:=impax.clone()
,ebm["1"]:="{F2}{esc}"

;~ mouseHooks:=[]
,monitors:=monitorInfo()
,mouseHooks:=[]
,OnMessage(0x10222, "AuxUp")
;~ ,OnMessage(0x2022, "impaxSeriesOff")
,OnMessage(0x2023, "stopActivateImpax")
,OnMessage(0x2024, "scrollImage")
,OnMessage(0x4a, "ON_WM_COPYDATA")
,partialMode:=!regexmatch(a_scriptdir,"is)(.+?)\\scripts\\Autorun$",match)
Loop, 4
{
	Gui, notify%A_Index%: -Caption +ToolWindow +AlwaysOnTOp
	Gui, notify%A_Index%: Color, white
}
OnMessage(0x10102,"Exit")

GroupAdd,EBM,ahk_exe WebViewerComSrvEC.exe
GroupAdd,EBM,ahk_exe WEBVIE~1.EXE




SetTimer,preventPersistentHook,1000

getEBMSquareLocFn:=Func("getEBMSquareLoc")
,EBMSquareLocXY:=[] ; whichMon [ [x1,y1], [x2,y2] ]
,EBMSquareLocXYQueue:=[]
for k,v in monitors
	EBMSquareLocXY[k]:=[]
	,EBMSquareLocXYQueue[k]:=new Queue

try{
	run,getEBMSquareLoc.exe,,Hide
	winwait,getEBMSquareLoc_main ahk_class AutoHotkeyGUI,,3
}

;~ gosub +!^UP
;~ SetTimer,% getEBMSquareLocFn,-2000,-1
getEBMSquareLoc()

;~ gui,debug:Default
;~ gui,debug:+ToolWindow
;~ gui,debug:Add,Edit,x0 y0 w300 h600 vdebugtext hwnddebugtexthwnd,
;~ gui,debug:show,w300 h600 Center NA
;~ SetTimer,debug,500
return



On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
	global newX,newY,frame,EBMSquareLocXY,EBMSquareLocXYRefreshTick
; dwData = Command
; cbData = String lenght
; lpData = String
	dwData := NumGet(lParam+0, 0)
	,cbData := NumGet(lParam + A_PtrSize)
	,lpData := NumGet(lParam + 2*A_PtrSize)
	,str := StrGet(lpData)
	
	;~ str:=lpData
	
	If  (dwData = 19) ; CMD_CURRENTPOSITION
	{
		try
			j:=JXON_load(str)
		catch
			return
		
		if(j.haskey("command")){
			try 
			SetTimer,% j.command,-1
		}else if (j.haskey("EBMSquareLocXY")){
			EBMSquareLocXY:=j["EBMSquareLocXY"]
			,EBMSquareLocXYRefreshTick:=A_TickCount
			SetTimer,getEBMSquareLocXYQueueRefresh,-1
		}

	}
}


debug:
guicontrol,,% debugtexthwnd,% exploreobj(EBMSquareLocXY)
return

exit:
ExitApp
return

~Lbutton up::
__lbuttondown:=false
gosub UnhookWindowsHookEx
;~ hHookMouse:=false
;~ SetTimer,keepActivateImpax,Off
SetTimer,% getEBMSquareLocFn,-1,10
~Lbutton::
;~ gosub mouseOnWin
;~ ToolTip % (WinActive("ahk_group EBM"))
if(!InStr(A_ThisHotkey,"up") && A_TickCount-lastLbuttonDown<400) && WinActive("ahk_group EBM"){
	SetTimer,% getEBMSquareLocFn,-1,10
}
if !InStr(A_ThisHotkey, "up"){
	lastLbuttonDown:=A_TickCount
	,__lbuttondown:=true
	SetTimer,lbuttondown__,-1000
}
	
lastLbutton:=A_TickCount

return

~LCtrl::
~Shift::
if (hHookMouse){
	gosub UnhookWindowsHookEx
	;~ hHookMouse:=false
}
return

lbuttonDown__(){
	global hHookMouse, mouseHooks, lastLbuttonDown, lastLbutton
	if GetKeyState("LButton") && (lastLbutton==lastLbuttonDown) && !GetKeyState("RButton") {
		winget,pName,ProcessName,A
		WinGetTitle,pTitle,A
		if (pName~="WebViewerComSrvEC.exe|WEBVIE~1.EXE") || instr(pTitle,"IMPAX Volume Viewing")  {
			hHookMouse:=true
			,mouseHooks.push(SetWindowsHookEx(WH_MOUSE_LL   := 14, RegisterCallback("MouseHook", "Fast")))
		}
	}
	
}


#IfWinActive,ahk_group EBM
~WheelUp::
~WheelDown::
SetTimer,% getEBMSquareLocFn,-500,-1
#IfWinActive


getEBMSquareLoc(){
	global monitors, getEBMSquareLocFn, EBMSquareLocXY, EBMSquareLocXYQueue, __lbuttondown, psquare
	
	
	
	if (!winexist("ahk_group EBM"))
		goto getEBMSquareLocReturn2
	
	PostMessage,0x10102,,,,getEBMSquareLoc_main ahk_class AutoHotkeyGUI
	goto getEBMSquareLocReturn
	return
	
	_EBMSquareLocXY:=[]
	for k, mon in monitors {
		;~ _EBMSquareLocXY[k]:=[]
		if(psquare!=2){
			image:=A_ScriptDir "\square.png"
			,res:=SearchImage(mon.l,mon.t,mon.r,mon.b, image, "*10")
			if(res.length())
				psquare:=1
		}
		if(psquare!=1){
			image:=A_ScriptDir "\square2.png"
			,res:=SearchImage(mon.l,mon.t,mon.r,mon.b, image, "*10")
			if(res.length())
				psquare:=2
		}
		_EBMSquareLocXY[k]:=res.length()?res:EBMSquareLocXY[k]
	}
	EBMSquareLocXY:=_EBMSquareLocXY
	;~ if(pimx && pimy &&  whichMon=whichMonitor(pimx, pimy)[1] && psquare=1){
		;~ ImageSearch,cimx,cimy,% pimx-50,% pimy-50,% pimx+50,% pimy+50,*10 %a_scriptdir%\square.png
		;~ if (!ErrorLevel){
			;~ pimx:=imx:=cimx, pimy:=imy:=cimy
			;~ goto getEBMSquareLocReturn
		;~ }
			
	;~ }
	;~ if(pimx && pimy &&  whichMon=whichMonitor(pimx, pimy)[1] && psquare=2){
		;~ ImageSearch,cimx,cimy,% pimx-50,% pimy-50,% pimx+50,% pimy+50,*10 %a_scriptdir%\square2.png
		;~ if (!ErrorLevel){
			;~ pimx:=imx:=cimx, pimy:=imy:=cimy
			;~ goto getEBMSquareLocReturn
		;~ }
	;~ }
	;~ ImageSearch,cimx,cimy,% mon.l,% mon.t,% mon.r,% mon.b,*10 %a_scriptdir%\square.png
	;~ if (!ErrorLevel){
		;~ pimx:=imx:=cimx, pimy:=imy:=cimy, psquare:=1
		;~ goto getEBMSquareLocReturn
	;~ }
	;~ ImageSearch,cimx,cimy,% mon.l,% mon.t,% mon.r,% mon.b,*10 %a_scriptdir%\square2.png
	;~ if (!ErrorLevel){
		;~ pimx:=imx:=cimx, pimy:=imy:=cimy, psquare:=2
		;~ goto getEBMSquareLocReturn
	;~ }
getEBMSquareLocReturn:	
	SetTimer,getEBMSquareLocXYQueueRefresh,-1,10
getEBMSquareLocReturn2:		
	SetTimer,% getEBMSquareLocFn,-2000,-1
	return
}

getEBMSquareLocXYQueueRefresh(){
	global EBMSquareLocXY, EBMSquareLocXYQueue
	for k, LocXYs in EBMSquareLocXY {
		while EBMSquareLocXYQueue[k].length>100
			EBMSquareLocXYQueue[k].dequeue()
		;~ for _, LocXY_ in LocXYs
			;~ EBMSquareLocXYQueue[k].enqueue(LocXY_)
		EBMSquareLocXYQueue[k].fromArray(LocXYs)
	}
}


impaxSeriesOff(){
	global lastLbutton
	if GetKeyState("Lbutton"){
		if A_TickCount-lastLbutton<1000
			return
		send {LButton Up}
		lastLbutton:=A_TickCount
		gosub +!^Up
	}
}

scrollImage(wParam, lParam, msg, hwnd){
	global scrollImageLbuttonState:=wParam
	gosub _+!^Up
}

show:
if (frame<20){
	settimer,show,off
	settimer,hide,-1
	return
}
cornerX1:=floor(newX-frame/2),cornerY1:=floor(newY-frame/2)
,cornerX2:=floor(newX+frame/2),cornerY2:=floor(newY+frame/2)
Gui, notify1: Show, % "x" cornerX1 " y" cornerY1 " w" frame " h2 NoActivate"
Gui, notify4: Show, % "x" cornerX1 " y" cornerY2 " w" frame " h2 NoActivate"
Gui, notify2: Show, % "x" cornerX1 " y" cornerY1 " w2 h" frame " NoActivate"
Gui, notify3: Show, % "x" cornerX2 " y" cornerY1 " w2 h" frame " NoActivate"
frame:=floor(frame/2)
settimer,show,-50

return


hide:
loop 4
	gui, notify%a_index%:hide
return

AuxUp(w,l,m,h){
	global
	changeWindow:=true
	cwmx:=w,cwmy:=l
	gosub +!^Up
}

;~ ~PGUP::
;~ if !hasModifiers("+!^")
	;~ return
+!^PgUp::
gosub mouseOnWin
if (pName~=MatchPacsProcessName()){
	if !GetKeyState("Lbutton"){
		if (pName~="WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
			Click
			;~ send {Left 2}
			send {PGUP}
		}else{ 
			send {Left}
		}
	}else
		impaxMoveThenScroll("L")
	
}else if (pName~="WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
	send {PGUP}
}else if (pName="Menu.exe"){
	;~ send {F11}
	getNetAcc(RisOpened()[2],"cmdRunFoword","BUTTON").accDoDefaultAction()
}else if (pName="SciTE.exe"){
	send +{F6}
}else {
	send ^{PgUp}
}
settimer,freeKeys,-500
return

;~ ~PGDN::
;~ if !hasModifiers("+!^")
	;~ return

+!^PgDn::
gosub mouseOnWin
if (pName~=MatchPacsProcessName()){
	if !GetKeyState("Lbutton")
		if (pName~="WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
			Click
			;~ send {Right 2}
			send {PGDN}
		}else 
			send {Right}
	else
		impaxMoveThenScroll("R")
}else if (pName~="WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
	send {PGDN}
}else if (pName="Menu.exe"){
	;~ send {F12}
	getNetAcc(RisOpened()[2],"cmdRunNext","BUTTON").accDoDefaultAction()
}else if (pName="SciTE.exe"){
	send {F6}
}else {
	send ^{PgDn}
}
settimer,freeKeys,-500
return

UnhookWindowsHookEx:
;~ Critical
hHookMouse:=false
for k,v in mouseHooks
	UnhookWindowsHookEx(v)
mouseHooks:=[]
return

FindNearestSquare(x, y, whichMon){
	global EBMSquareLocXY, EBMSquareLocXYQueue, monitors, psquare, EBMSquareLocXYRefreshTick
	;~ MsgBox % exploreobj(EBMSquareLocXY)
	;~ MsgBox % EBMSquareLocXY[whichMon].length()
	LocXY:=EBMSquareLocXY[whichMon].length()?EBMSquareLocXY[whichMon]:""
	if !LocXY || (!LocXY.length() && !((LocXY:=EBMSquareLocXYQueue[whichMon].toArray()).length())) {
		mon:=monitors[whichMon]
		if(psquare!=2)
			LocXY:=ret1:=SearchImage(mon.r-80, mon.t, mon.r, mon.b, A_ScriptDir "\square.png", "*10")
			,psquare:=ret1.length()?1:""
		if(psquare!=1 || !ret1.length())
			LocXY:=ret2:=SearchImage(mon.r-80, mon.t, mon.r, mon.b, A_ScriptDir "\square2.png", "*10")
			, psquare:=ret2.length()?2:""
		
		if(LocXY)
			EBMSquareLocXY[whichMon]:=LocXY
			,EBMSquareLocXYQueue[whichMon].fromArray(LocXY)
		else{
			beforeRefresh:=EBMSquareLocXYRefreshTick
			,getEBMSquareLoc()
			Loop {
				Sleep -1
			}until EBMSquareLocXYRefreshTick>beforeRefresh
			LocXY:=EBMSquareLocXY[whichMon]
		}
			
	}
	
	if !LocXY || !LocXY.length()
		return
	
	if (LocXY.length()==1)
		return locXY[1]
	
	min_d:="", ret:=[]
	for k,xy in LocXY {
		dist:=(xy[1]-x)**2 + (xy[2]-y)**2
		if(dist!="" && min_d=="" || dist<min_d)
			min_d:=dist, ret:=xy
	}
	;~ if(ret[1]==""){
		;~ getEBMSquareLoc()
		;~ return FindNearestSquare(x, y, whichMon)
	;~ }else
		return ret
}


;~ ~Up::
;~ if hasModifiers("+!^")
	;~ goto +!^Up
;~ return

_+!^Up:
Critical
if (GetKeyState("LButton") || scrollImageLbuttonState){
	gosub UnhookWindowsHookEx
	send {lbutton up}
	
	;~ SetTimer,keepActivateImpax,Off
	;~ mousemove,% newX:=beforeLbuttonX,% newY:=beforeLbuttonY,0
	__lbuttondown:=false
	SetTimer,% getEBMSquareLocFn,-1,10
	return
}
+!^Up::
Critical
gosub mouseOnWin
if (pName~=MatchPacsProcessName()) || instr(pTitle,"IMPAX Volume Viewing") {
	winset,AlwaysOnTop,Off,simple RIS ahk_class AutoHotkeyGUI
	DllCall("SetWindowPos", "Ptr", WinExist("simple RIS ahk_class AutoHotkeyGUI"), "Ptr", -2, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	winactivate,ahk_id %win%
	;~ SetTimerF("toggleSeriesList", ["", "off", "all"])
	if getkeystate("lbutton") {
		send {lbutton up}
		;~ for k,v in mouseHooks
			;~ UnhookWindowsHookEx(mouseHook)
			gosub UnhookWindowsHookEx
			;~ SetTimer,keepActivateImpax,Off
		;~ mouseHooks:=[]
		;~ sleep 100
		mousemove,% newX:=beforeLbuttonX,% newY:=beforeLbuttonY,0
		SetTimer,% getEBMSquareLocFn,-1,10
		;~ frame:=400
		;~ settimer,show,-1
	}else {
		mousegetpos,beforeLbuttonX,beforeLbuttonY,win,con,2
		wingetpos,wx,,,,ahk_id %win%
		controlgetpos,x,,w,,,ahk_id %con%
		
		BlockInput,MouseMove
		if(pName ~= "WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
			mon:=monitors[whichMon:=whichMonitor()[1]]
			;~ ImageSearch,imx,imy,% mon.r-300,% mon.t,% mon.r,% mon.h,*10 square.png
			;~ ImageSearch,imx,imy,% mon.l,% mon.t,% mon.r,% mon.b,*10 %a_scriptdir%\square.png
			;~ ,getEBMSquareLoc(imx, imy)
			
			if changeWindow
				nearest:=[cwmx,cwmy], changeWindow:=false
			else
				nearest:=FindNearestSquare(beforeLbuttonX, beforeLbuttonY, whichMon)
			;~ ToolTip % ErrorLevel
			if (nearest[1]!="" && nearest[2]!="")
				mousemove,% lbuttonDownX:=(imx:=nearest[1])+16,% (imy:=nearest[2])+16,0
			else
				lbuttonDownX:=wx+x+w-floor(w/20)-1
			
		}else{
			if (whichMonitor()[1]=3){
				mousemove,% lbuttonDownX:=wx+x+floor(w/20)+1,% beforeLbuttonY,0
			}else{
				mousemove,% lbuttonDownX:=wx+x+w-floor(w/20)-1,% beforeLbuttonY,0
			}
			Sleep 50
		}
		
		send {lbutton down}
		__lbuttondown:=true
		BlockInput,MouseMoveOff
		
		if (pName~="WebViewerComSrvEC.exe|WEBVIE~1.EXE")
			hHookMouse:=true
			,mouseHooks.push(SetWindowsHookEx(WH_MOUSE_LL   := 14, RegisterCallback("MouseHook", "Fast")))
		;~ ,impaxWin:=win
		;~ SetTimer,keepActivateImpax,1000
		;~ SetTimer,stopKeepActivateImpax,-10000
	}
}else if (pName="Menu.exe"){
	send {lbutton}
	SetTimer,updateSimpleRISoldHx,-1000
	Sleep 300
	oldclipboard:=ClipboardAll
	,clipboard:=""
	send ^c
	ClipWait,0.5
	if RegExMatch(row:=clipboard, "\b[TY]\w{9}\d\b", AccNo){
		;~ ImpaxContextServer_Add(AccNo)
		RegExMatch(row, "\b\w{6}\d\b", chartNo)
		
		examName:=VS:=examDate:=""
		,len:=0
		Loop,Parse,row,`t
			if(A_LoopField~="\d{4}\/\d\d\/\d\d")
				examDate:=A_LoopField
			else if (A_LoopField~="^[^a-zA-Z0-9\/\-\s]{2,3}$")
				VS:=A_LoopField
			else if StrLen(A_LoopField)>len
				len:=StrLen(A_LoopField), examName:=A_LoopField
		
		if (SubStr(chartNo,1,1)~="H|Y|M"){
			ebmPreloadPath:=partialMode?"""" A_ScriptDir "\EBMpreload\EBMpreload.exe"" """ A_ScriptDir "\EBMpreload\EBMpreload.ahk""":"""" SubStr(A_ScriptDir,1,1) ":\scripts\radiology\EBMpreload\EBMpreload.exe"""
			run % ebmPreloadPath " " chartNo "_" AccNo
			ToolTip % "Open study in EBM: " examDate ", " VS ", " examName ", " AccNo
		}else{
			risOpenOldSingleStudy(AccNo, examDate, examName)
			ToolTip % "Open study in PACS: " examDate ", " VS ", " examName ", " AccNo
		}
		
		SetTimer	,ToolTip,-2000
	}
	clipboard:=oldclipboard
	
	;~ MouseGetPos,x,y
	;~ send {lbutton}
	;~ sleep 300
	;~ MouseMove,% x,% y,0
	;~ send {rbutton}
	;~ sleep 200
	;~ mousemove,10,5,1,r
	;~ click

}else if (pName="SciTE.exe"){
	send !{left}
}else {
	send {PgUp}
}
settimer,freeKeys,-500
return

ToolTip:
ToolTip
return

stopActivateImpax(){
	global __lbuttondown
	__lbuttondown:=GetKeyState("LButton")
	gosub stopKeepActivateImpax
}


;~ ~Down::
;~ if !hasModifiers("+!^")
	;~ return
+!^Down::
gosub mouseOnWin
if (pName~=MatchPacsProcessName()) || instr(pTitle,"IMPAX Volume Viewing") {
	send {lbutton 2}
}else if (pName="Menu.exe"){
	
}else if (pName="SciTE.exe"){
	send !{right}
}else {
	send {PgDn}
}
settimer,freeKeys,-500
return

stopKeepActivateImpax:
SetTimer,keepActivateImpax,Off
return
;~ AddAbrvReports:
;~ if(AddAbrvReportsActiveState:=!AddAbrvReportsActiveState){
	;~ AbrvReports:=""
	;~ input,AbrvReports,{Space}{Enter}
	
;~ }else{
	
;~ }
;~ return

+#^1::
+#^2::
+#^3::
+!^1::
+!^2::
+!^3::
+!^4::
+!^5::
+!^6::
+!^7::
+!^8::
+!^9::
+!^0::
+!^-::
+!^=::
gosub mouseOnWin
__lbuttondown_tmp := __lbuttondown
if (pName~=MatchPacsProcessName()) && substr(a_thishotkey,4,1)=1 {
	if (__lbuttondown_tmp && pName~="i)WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
		resetHotstringBuffer(-1)
	}
}else{
	resetHotstringBuffer(-1)
}
if (pName~="impax-client-main.exe"){
	var:="impax"
}else if (pName~="WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
	var:="ebm"
}else if (pName="Menu.exe"){
	var:="ris"
}else if (pName="SciTE.exe"){
	
}else {
	var:="default"
}
v:=%var%["" substr(a_thishotkey,4,1)]
if IsLabel(v)
	goto % v
else 
	send % v
if (pName~=MatchPacsProcessName()) && substr(a_thishotkey,4,1)=1 {
	if (__lbuttondown_tmp && pName~="i)WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
		__lbuttondown:=false
		gosub _+!^Up
	}
}else{
	resetHotstringBuffer(-1)
	settimer,freeKeys,-500	
}
return

FirefoxUpScroll:
FirefoxDownScroll:
PostMessage,% InStr(A_ThisLabel, "Up")?0x2002:0x2001,,,,showLungCAD_main ahk_class AutoHotkeyGUI
return

activeWin:=WinExist("A")
MouseGetPos,beforeScrollX,beforeScrollY
if GetKeyState("Lbutton"){
	gosub +!^Up
	recoverImpaxScroll:=true
}
if WinExist("- Mozilla Firefox ahk_class MozillaWindowClass")
	browser:="- Mozilla Firefox ahk_class MozillaWindowClass"
else if WinExist("ahk_class Chrome_WidgetWin_1")
	browser=ahk_class Chrome_WidgetWin_1
else
	return
WinActivate,%browser%
WinWaitActive,,,2
;~ if (LastFound="syngovia"){
	;~ mousemove,% A_ScreenWidth-100,% Floor(A_ScreenHeight/2),0
	;~ sleep 50
	;~ send % (key="next")?"{WheelUp}":"{WheelDown}"
;~ }else{
	mouseclick,L,% A_ScreenWidth-10,% Floor(A_ScreenHeight/2),1,0
	Sleep 50
	send % !InStr(A_ThisLabel,"Up")?"{Right}":"{Left}"
	repeat:= (GetActiveBrowserURL()~="pid=1$")
;~ }
sleep 100
mousemove,% beforeScrollX,% beforeScrollY,0
WinActivate,ahk_id %activeWin%
if (recoverImpaxScroll)
	gosub +!^Up
recoverImpaxScroll:=false

if (repeat){
	ToolTip % "Back to first picture!"
	SetTimer,ToolTip, -2000
}

;~ BlockInput,mousemove
;~ MouseGetPos,beforeScrollX,beforeScrollY
;~ if GetKeyState("Lbutton"){
	;~ gosub +!^Up
	;~ recoverImpaxScroll:=true
;~ }
;~ SetTimer,freeKeys,-1000
;~ WinActivate,ahk_class MozillaWindowClass
;~ mousemove,% monitors.1.r-100,% Floor(monitors.1.h/2),0
;~ sleep 50
;~ send % InStr(A_ThisLabel,"Up")?"{WheelUp}":"{WheelDown}"
;~ sleep 100
;~ mousemove,% beforeScrollX,% beforeScrollY,0
;~ sleep 50
;~ if (recoverImpaxScroll)
	;~ gosub +!^Up
;~ recoverImpaxScroll:=false
;~ BlockInput,MouseMoveOff
return


;~ esc::ExitApp

freeKeys:
send {LWin up}{RWIN up}{Shift UP}{ctrl UP}{ALt UP}
return

;~ default:
;~ send % default["" substr(a_thishotkey,4,1)]
;~ return


;~ impax:
;~ send % impax["" substr(a_thishotkey,4,1)]
;~ return

;~ ris:
;~ send % ris["" substr(a_thishotkey,4,1)]
;~ return

;~ scite:
;~ return



mouseOnWin: 
mousegetpos,,,win,con,2
for k,accKey in ["shift","alt","ctrl"]
{
		KeyWait,% accKey,L T0.4
		if ErrorLevel
			send {%accKey% up}
	}

winget,pName,processname,ahk_id %win%
wingettitle,pTitle,ahk_id %win%
;~ MsgBox % pName "," pTitle
if(((pName="simpleRIS.exe") || (WinGetTitle(win)~="i)^simple RIS" && WinGetClass(win)="AutoHotkeyGUI")) && pTitle="__maskImpaxLoading"){
	WinClose,ahk_id %win%
	goto mouseOnWin
}else if (((pName="simpleRIS.exe") || (WinGetTitle(win)~="i)^simple RIS" && WinGetClass(win)="AutoHotkeyGUI"))){
	WinHide,ahk_id %win%
	goto mouseOnWin
}
if (pName~="i)Miv2Lib.exe")
	return
if !WinActive("ahk_id " win)
	winactivate,ahk_id %win%
ControlFocus,,% "ahk_id " con
return


;~ esc::exitapp
onexit:
;~ for k,v in mouseHooks
	;~ UnhookWindowsHookEx(mouseHook)
gosub UnhookWindowsHookEx
exitapp
return
MouseHook(nCode, wParam, lParam){
	static lx,ly
	global hHookMouse, imx, imy
	;~ Critical
	;~ ToolTip % hHookMouse
	if (wParam=0x202){
		hHookMouse:=false
		SetTimer,UnhookWindowsHookEx,-10
		return CallNextHookEx(nCode, wParam, lParam)
	}
	If nCode || !(wParam = 0x200) || !hHookMouse
	return CallNextHookEx(nCode, wParam, lParam)
	VarSetCapacity(lpPoint,8)
	,DllCall("GetCursorPos", "Uint", &lpPoint)
	lx := NumGet(lpPoint, 0, "Int")
	,ly := NumGet(lpPoint, 4, "Int")
	,mx := NumGet(lParam+0, 0, "Int")
	,my := NumGet(lParam+0, 4, "Int")
	,mx := lx + (mx-lx)
	,my := ly + (mx-lx) + (my-ly)
	,DllCall("SetCursorPos", "Int", imx:=lx, "Int", imy:=my)
	,NumPut(mx, lParam+0, 0, "Int")
	,NumPut(my, lParam+0, 4, "Int")
	;~ ToolTip % lx "," ly
	return 1
}



impaxMoveThenScroll(direction){
	global 
	local x,y,mxx,myy
	if monitors.maxIndex()<3
		return
	BlockInput,mousemove
	MouseGetPos,x,y
	
	gosub +!^Up
	SetTimer,freeKeys,-1000
	
	x:=monitors.2.r*2-lbuttonDownX
	Loop {
		MouseGetPos,mxx,myy
		if (mxx=x && myy=y)
			break
		MouseMove,% x-1,% y-1,0
		mousemove,1,1,1,R
		Sleep 10
	}until A_Index>50
		
	
	
	;~ Sleep 50
	;~ oldsendlevel:=a_sendlevel
	;~ SendLevel,3
	gosub +!^Up
	;~ send +!^{UP}
	;~ SendLevel,% oldsendlevel
	BlockInput,MouseMoveOff
}


keepActivateImpax:
return
winactivate,ahk_id %impaxWin%
__lbuttondown:=GetKeyState("LButton")
return

updateSimpleRISoldHx:
PostMessage,0x1124,1,0,,simple RIS ahk_class AutoHotkeyGUI
return



; for G mouse
XButton2::
SendLevel,3
send +!^3
return

XButton1::
SendLevel,3
send +!^6
return


preventPersistentHook:
if !GetKeyState("LButton") && !GetKeyState("RButton") && !GetKeyState("MButton") && !GetKeyState("XButton1") && !GetKeyState("XButton2")
	gosub UnhookWindowsHookEx
return