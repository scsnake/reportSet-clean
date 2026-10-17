#MaxHotkeysPerInterval 999999
#UseHook
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
process,Priority,,H
SetBatchLines, -1
coordMode,mouse,screen
CoordMode,caret,screen
DetectHiddenWindows,on
SetWinDelay,-1
SetTitleMatchMode,2
SetControlDelay,-1
comobjerror(false)
onexit,onexit
#NoTrayIcon

#include <Acc>
#include <risimpax>
#include <prettyReport>
;~ #include <Class_RichEdit>
#include <winvisible>
#include <wingetatcoords>
#include <SCI>
#include <RemoteScintilla>
#include <FakeRemoteScintilla>
#include <SetTimerFn>
#include <SetWindowsHookEx>
;~ #include <UIAutomationServer>
#include <GetFocusedHwnd>
#include <CheckUpdate>
#include <SetTimerF>
#include <EmptyMem>
#include <Edit>
#include <portalLib>
#include <resetHotstringBuffer>
#InstallKeybdHook
#InstallMouseHook
;~ SetTimerF("_scs_sync",-1)
;~ _scs_sync()
;~ #include <Edit>
;~ runTimeBP("###")

;~ WinClose,ahk_exe simpleRIS_.exe

onmessage(0x2024,"resetEdit")

MsgBox % WinGetTitle(WinExist("ahk_pid " GetParentProcessID(GetCurrentProcessID())))
ExitApp
global thisPlace:=getPlace()
monitors:=monitorInfo()
,resetHotstringBufferHook()
,dwData:=17
,lastClick:=0
,initAtCenter:=true
;~ debug:=true

gui,2:Default
gui,+hwndmainHwnd
WinSetTitle,ahk_id %mainHwnd%,,simpleRIS__main

GroupAdd,AllSimpleRis,simple RIS ahk_class AutoHotkeyGUI

onmessage(0x2021,"redirect")
,onmessage(0x2020,"redirect")
,onmessage(0x2022,"redirect")
,onmessage(0x2023,"redirect")
,onmessage(0x2025,"redirect")
,onmessage(0x2026,"redirect")
,onmessage(0x2027,"redirect")
,onmessage(0x2028,"redirect")
,onmessage(0x2029,"redirect")
,onmessage(0x2030,"changeEdit")
,onmessage(0x1122,"redirect")
,onmessage(0x1123,"redirect")
,onmessage(0x1124,"redirect")
,onmessage(0x1125,"redirect")
,onmessage(0x1126,"sync_position")
,onmessage(0x10101,"exit")
,onmessage(0x8000,"redirect")



renewMainSimpleRis()
;~ MsgBox % guihwnd_

gosub sethotkey
gosub gui
settimer,SCI_ColorRadReport,2000

winset,trans,200,% "ahk_id " guihwnd1
winset,trans,200,% "ahk_id " guiHwnd3
settimer,sync_position,3000

thisPid:=WinGetPid()
,WindowShellEvent("onWin")
settimer,setfocus,200
return

renewMainSimpleRis(){
	global guihwnd_, editHwnd_, sci_, editHwnd1, edithwnd3, edithwnd, sci, guihwnd, guiHwnd3, sci_bk
	static guihwnd_2
	if (guihwnd_2:=getSimpleRisGuiHwnds()[1]) && (editHwnd_:=getSimpleRisEditHwnds()[1]) {
		if !WinExist("ahk_id " editHwnd_){
			settimer, renewMainSimpleRis, -200
			return
		}
		if (guihwnd_2!=guihwnd_)
			guihwnd_:=guihwnd_2
			,sci_:=new RemoteScintilla(editHwnd_)
		settimer,renewMainSimpleRis,-10000
	}else{
		sci_:=""
		,guihwnd_:=editHwnd_:=0
		settimer,renewMainSimpleRis,-1000
	}
	
	changeEdit()
	return
}
redirect(w,l,m,h){
	global guihwnd_
	
	static lastRecv:=[]
	
	if(lastRecv[m] && A_TickCount-lastRecv[m]<200)
		return 
	lastRecv[m]:=A_TickCount
	
	
	PostMessage,% m,% w,% l,,simpleRIS_main ahk_class AutoHotkeyGUI
}

gui:

;; gui with simple edit
gui,3:new,+hwndguiHwnd3 
groupadd,MyGui,ahk_id %guiHwnd3%
GroupAdd,mainGui,ahk_id %guiHwnd3%
gui,+toolwindow -caption +lastfound
gui,color,EEAACC,black
winset,TransColor,EEAACC
gui,font,s16 cwhite,Georgia
gui,add,button,w0 h0 gnothing
gui,add,text,vthisAccNoText3 hwndthisAccNoTextHwnd3 w0 h0



gui,1:new,+hwndguiHwnd 
guihwnd1:=guihwnd
groupadd,MyGui,ahk_id %guiHwnd%
GroupAdd,mainGui,ahk_id %guiHwnd%
gui,+toolwindow -caption +lastfound
gui,color,EEAACC,black
winset,TransColor,EEAACC
gui,font,s14 csilver,Georgia
gui,add,button,w0 h0 gnothing
gui,add,text,vthisAccNoText hwndthisAccNoTextHwnd w0 h0

GroupAdd,thisGUIs,ahk_id %guihwnd1%
GroupAdd,thisGUIs,ahk_id %guihwnd3%

gosub calWidthHeight
sci:=new scintilla(guihwnd,5,5,guiPos.w-10,guiPos.h-10)
,sr:=sciSettings(sci)

gui,3:Add,edit,% "x5 y5 w" guiPos.w-10 " h" guiPos.h-10 " hwndedithwnd3",

editHwnd:=sci.hwnd
,sci_bk:=sci
,editHwnd1:=editHwnd

WinGetPos,x,y,w,h,ahk_id %guihwnd_%
WinSetTitle,ahk_id %guihwnd1%,,simple RIS
WinSetTitle,ahk_id %guiHwnd3%,,simple RIS3

;~ MsgBox % WinExist("ahk_id " guihwnd1)
;~ MsgBox % WinExist("ahk_id " guiHwnd3)
;~ MsgBox % WinGetTitle(guihwnd1)
;~ MsgBox % WinGetTitle(guiHwnd3)
if !(x y w h =""){
	if !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
		gui,Show,% "x" x " y" y  " w" w " h" h,simple RIS
	else
		gui,3:Show,% "x" x " y" y  " w" w " h" h,simple RIS3
}else{
	if !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
		gui,show,% "x" guiPos.x " y" guiPos.y " w" guiPos.w " h" guiPos.h,simple RIS
	else
		gui,3:show,% "x" guiPos.x " y" guiPos.y " w" guiPos.w " h" guiPos.h,simple RIS3
}
changeEdit()
return



calWidthHeight:
guiPos:=[]
if monitors.maxindex()=1
	k:=1
else
	k:=2
b:=monitors[k].b
,h:=monitors[k].h
,w:=monitors[k].w
,l:=monitors[k].l
,guiPos.w:=w>h?Floor(w/2):Floor(w*2/3)
, guiPos.h:=Floor(guiPos.w*0.3)
, guiPos.x:=l+Floor(w/2 - guiPos.w/2)
,guiPos.y:=initAtCenter?Floor(b - h/2 - guiPos.h/2):b-Floor(guiPos.h*0.3)

;~ ToolTip % initAtCenter "," guiPos.y
return

nothing:
return



sciSettings(ByRef sci, main=true){
	global
	sci.SetWrapMode(true), sci.SetLexer(SCLEX_CONTAINER), sci.StyleClearAll()
	,sci.SetCodePage(65001)
	,sci.AUTOCSETCASEINSENSITIVEBEHAVIOUR(1)
	,sci.AUTOCSETSEPARATOR(0xA)
	

	;~ FontSize:=guiPos.w>1000?17:guiPos.w>700?14:12
	if(main){
		Fontsize:=Round((guiPos.w+70.4)/68.4)
		if Fontsize<14
			Fontsize:=14
		else if Fontsize>24
			Fontsize:=24
	}else{
		Fontsize:=12
	}
	;1366->21
	;1024->16

	; Change a style
	if (main){
		sci.SETVIEWEOL(!!ifShowLinebreak)
		,sci.SETCARETWIDTH(2)
		,sci.SetCaretFore(0xFFFFFF)
	}else{
		sci.SETCARETWIDTH(0)
		,sci.SetCaretFore(0x000000)
	}
	
	sci.SETSELALPHA(100)
	
	
	;~ sci.StyleSetBack(32, 0x000000)
	sci.StyleSetFore(SCLEX_CONTAINER, 0xF9F9F9), sci.StyleSetBack(SCLEX_CONTAINER, 0x000000), sci.StyleSetBold(SCLEX_CONTAINER, false), sci.StyleSetFont(SCLEX_CONTAINER, "Georgia"), sci.StyleSetSize(SCLEX_CONTAINER, Fontsize)
	,sci.StyleSetFore(STYLE_DEFAULT, 0xF9F9F9), sci.StyleSetBack(STYLE_DEFAULT, 0x000000), sci.StyleSetBold(STYLE_DEFAULT, false), sci.StyleSetFont(STYLE_DEFAULT, "Georgia"), sci.StyleSetSize(STYLE_DEFAULT, Fontsize)
	,sci.StyleSetFore(SCE_AHKL_USERDEFINED1, 0xFFFFFF), sci.StyleSetBack(SCE_AHKL_USERDEFINED1, 0x000000), sci.StyleSetBold(SCE_AHKL_USERDEFINED1, true), sci.StyleSetFont(SCE_AHKL_USERDEFINED1, "Georgia"), sci.StyleSetSize(SCE_AHKL_USERDEFINED1, Fontsize-1)
	
	, sci.SetMarginWidthN(1,0)
	if main
		sci.GrabFocus()
		;~ , sci.Notify:="Notify"
	else 
		sci.SetReadOnly(true)
	return new StyleRange("")
}


Notify(wParam, lParam, msg, hwnd, obj){
    global PauseUpdate,noUpdateMode,sci,SciAutoCompleteList,sr, DoNotTriggerModified
	
	if(noUpdateMode || PauseUpdate || WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI") || WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI") ){
		return
	}
	
    if (obj.scnCode = SCN_MODIFIED){
		SetTimer,SCI_ColorRadReport, -1000
	}
    return
	
}
SCI_ColorRadReport:
if !WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI") && !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI") {
	this_text:=SCI_GETTEXT(sci)
	if(Trim(prev_text)=Trim(this_text))
		return
	
	;~ sci.CONVERTEOLS(0)
	SCI_ColorRadReport(sci,sr,0)
	;~ if ((Text1:=this_text) != (Text2:=sci_.getText()) ){
		settimer,updateSci,-1000
	;~ }
	prev_text:=this_text
}
return


updateSci:
PostMessage,0x2020,,,,simpleRIS_main ahk_class AutoHotkeyGUI
return
sci.CONVERTEOLS(0)
if ((Text1:=SCI_GETTEXT(sci)) != (Text2:=sci_.getText()) ){
	if(Trim(Text1)!="")
		sci_.SetText(Text1)
		,Edit_GetSel(sci.hwnd,s,e)
		,Edit_SetSel(editHwnd_,s,e)
		;~ ,Edit_SetText(getRisReports()[1,1], Text1)
	else if (Trim(Text2)="")
		PostMessage,0x2024,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	else{
		sci_SetText(sci, tmp:=Text2)
		,Edit_GetSel(editHwnd_,s,e)
		,Edit_SetSel(sci.hwnd,s,e)
		,sci.ScrollCaret()
		PostMessage,0x2020,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	}
}
if(Trim(Text1)!="" && Trim(Text1)!=Trim(text3:=ControlGetText((RisReports:=getRisReports())[1,1]))){
	Edit_GetSel(sci.hwnd,s,e)
	,Edit_SetText(RisReports[1,1], Trim(Text1))
	,Edit_SetSel(RisReports[1,1],s,e)
}
	
return

;~ esc::
OnExit:
ExitApp

resetEdit(){
	static lastRecv
	if(lastRecv && A_TickCount-lastRecv<200)
		return
	lastRecv:=A_TickCount
	gosub resetEdit
}

sethotkey:
Hotkey,IfWinActive,ahk_group thisGUIs
Hotkey,^n,resetEdit
Hotkey,^b,updateText
Hotkey,MButton,_MButton,on
Hotkey,^RButton,_MButton,on
Hotkey,IfWinActive,ahk_group
return


#IfWinActive,ahk_group thisGUIs
_MButton:
PostMessage,0x2031,,,,simpleRIS_main ahk_class AutoHotkeyGUI
return

;~ ~^n::
resetEdit:
if(A_PriorHotkey = A_ThisHotkey && A_TimeSincePriorHotkey < 500){
	controlsettext,,,% "ahk_id " (RisReports:=getRisReports())[1,1]
	controlsettext,,,% "ahk_id " RisReports[1,2]
	PostMessage,0x2024,,,,simpleRIS_main ahk_class AutoHotkeyGUI
}
;~ ToolTip % A_TickCount "resetEdit"
;~ settimer,update,Off
sr.reset()
;~ sr.SetText(unused, t:="")
,sci.ClearAll()
,Edit_SetText(editHwnd1, tmp:="")
,Edit_SetText(edithwnd3, tmp:="")
;~ settimer,update,-3000
;~ FileAppend,% a_now ": resetEdit `r`n",templog.txt,utf-8
return

;~ ~^b::
updateText:
PostMessage,0x2019,,,,simpleRIS_main ahk_class AutoHotkeyGUI
return

#IfWinActive

exit(){
	ExitApp
}

~#!q::
if(a_thishotkey=a_priorhotkey && a_timesincepriorhotkey<300){
	if !WinExist("simpleRIS_main ahk_class AutoHotkeyGUI"){
		for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where CommandLine like '%simpleRISDelegate.cmd%' ")
			TaskKill(process.ProcessID)
		ExitApp
	}else
		PostMessage,0x10101,,,,simpleRIS_main ahk_class AutoHotkeyGUI
}
return


changeEdit(wP=0,lP=0,msg=0,handle=0){
	local x,y,w,h, changed, s, e, gui1,gui2,edit1,edit2,Text1,Text2
	changed:=false
	DetectHiddenWindows,on
	
	
	if(wP){
		if WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
			gui1:=guihwnd:=guiHwnd3, gui2:=guihwnd1
			,edithwnd:=edit1:=edithwnd3, edit2:=edithwnd1
		else
			gui2:=guiHwnd3, gui1:=guihwnd:=guihwnd1
			,edithwnd:=edit1:=editHwnd1, edit2:=edithwnd3
		
		WinHide,ahk_id %gui2%
		WinShow,ahk_id %guihwnd%
		WinWaitActive,ahk_id %guihwnd%,,1
		ControlFocus,,ahk_id %edithwnd%
		
		;~ Text1:=Trim(Edit_GetText(edit1))
		Text2:=Trim(Edit_GetText(edit2))
		,Edit_GetSel(edit2,s,e)
		,Edit_SetText(edit1, Text2)	
		,Edit_SetSel(edit1,s,e)	
		,Edit_ScrollCaret(edit1)	
		,sync_position()
	}else if WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI") {
		if (guihwnd!=guiHwnd3)  || !winvisible(guiHwnd3) {
			WinHide,ahk_id %guihwnd1%
			WinShow,ahk_id %guihwnd3%
			guihwnd:=guiHwnd3, edithwnd:=edithwnd3, sci:=new FakeRemoteScintilla(edithwnd3)
			
			,Edit_GetSel(editHwnd1, s, e)
			,Edit_SetText(editHwnd, Edit_GetText(editHwnd1))
			,Edit_SetSel(editHwnd, s, e)
			,changed:=true
		}
	}else{
		if (guihwnd!=guihwnd1) || !winvisible(guihwnd1) {
			WinHide,ahk_id %guiHwnd3%
			WinShow,ahk_id %guihwnd1%
			guihwnd:=guihwnd1, edithwnd:=editHwnd1, sci:=sci_bk
			
			,Edit_GetSel(edithwnd3, s, e)
			,Edit_SetText(editHwnd, Edit_GetText(edithwnd3))
			,Edit_SetSel(editHwnd, s, e)
			,changed:=true
		}
	}
	
	if (changed) {
		WinShow,ahk_id %guihwnd%
		winactivate,ahk_id %guihwnd%
		ControlFocus,,ahk_id %edithwnd%
		PostMessage,0x2030,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	}
		
}


sync_position(){
	global guihwnd1, guiHwnd3
	
	guihwnds:=getSimpleRisGuiHwnds()
	DetectHiddenWindows,on
	WinGetPos,x,y,w,h,% "ahk_id " guihwnds[1]
	WinGetPos,x2,y2,w2,h2,% "ahk_id " guihwnd1
	WinGetPos,x3,y3,w3,h3,% "ahk_id "  guiHwnd3
	
	if (x2=x && x3=x && y2=y && y3=y)
		return
	
	if !(x y w h ==""){
		WinMove,ahk_group AllSimpleRis,,% x,% y,% w,% h
	}
}

onWin(wParam, lParam){
	global thisPid, guihwnd1, guiHwnd3, editHwnd1, edithwnd3
	if (wParam = 1){
		;~ WinGetTitle,t,ahk_id %lParam%
		if (lParam=guihwnd1) || (lParam=guiHwnd3) || ((winget("PID", lParam)) != thisPid)
			return
		if winvisible(guihwnd1) {
			winactivate,ahk_id %guihwnd1%
			ControlFocus,,ahk_id %editHwnd1%
		}
		else if winvisible(guiHwnd3) {
			winactivate,ahk_id %guiHwnd3%
			ControlFocus,,ahk_id %edithwnd3%
		}
			
		;~ ToolTip % "activated window: " t
	}
}
	
setfocus(){
	global guihwnd1, guiHwnd3, editHwnd1, edithwnd3
	activeWin:=WinExist("A")
	if (activeWin!=guihwnd1) || (activeWin!=guiHwnd3)
		return
	activeCon:=GetFocusedHwnd()
	if(activeCon=editHwnd1 || activeCon=edithwnd3)
		ControlFocus,,% "ahk_id " winvisible(guihwnd1)?editHwnd1:(winvisible(guiHwnd3)?edithwnd3:0)
}