#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
process,Priority,,H
SetBatchLines, -1
coordMode,mouse,screen
CoordMode,caret,screen
DetectHiddenWindows,on
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
;~ #include <FakeRemoteScintilla>
#include <SetTimerFn>
#include <SetWindowsHookEx>
;~ #include <UIAutomationServer>
#include <GetFocusedHwnd>
#include <CheckUpdate>
#include <SetTimerF>
#include <EmptyMem>
#include <Edit>
#include <portalLib>
;~ #include <resetHotstringBuffer>
#InstallKeybdHook
#InstallMouseHook
;~ SetTimerF("_scs_sync",-1)
;~ _scs_sync()
;~ #include <Edit>
;~ runTimeBP("###")

;~ WinClose,ahk_exe simpleRIS_.exe

;~ onmessage(0x2024,"resetEdit")



monitors:=monitorInfo()
;~ ,resetHotstringBufferHook()
,dwData:=17
,lastClick:=0
,initAtCenter:=true
;~ debug:=true

;~ gui,2:Default
;~ gui,+hwndmainHwnd
;~ WinSetTitle,ahk_id %mainHwnd%,,simpleRIS__main


;~ onmessage(0x2021,"redirect")
;~ ,onmessage(0x2020,"redirect")
;~ ,onmessage(0x2022,"redirect")
;~ ,onmessage(0x2023,"redirect")
;~ ,onmessage(0x2025,"redirect")
;~ ,onmessage(0x2026,"redirect")
;~ ,onmessage(0x2027,"redirect")
;~ ,onmessage(0x2028,"redirect")
;~ ,onmessage(0x2029,"redirect")
;~ ,onmessage(0x2030,"changeEdit")
;~ ,onmessage(0x1122,"redirect")
;~ ,onmessage(0x1123,"redirect")
;~ ,onmessage(0x1124,"redirect")
;~ ,onmessage(0x1125,"redirect")
;~ ,onmessage(0x10101,"exit")
;~ ,onmessage(0x8000,"redirect")



;~ renewMainSimpleRis()
;~ MsgBox % guihwnd_


gosub gui


winset,trans,200,% "ahk_id " guihwnd
;~ winset,trans,200,% "ahk_id " guiHwnd3
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
	
	
	PostMessage,% m,% w,% l,,% "ahk_id " guihwnd_
}

gui:

;; gui with simple edit
;~ gui,3:default
;~ gui,+hwndguiHwnd3 
;~ groupadd,MyGui,ahk_id %guiHwnd3%
;~ GroupAdd,mainGui,ahk_id %guiHwnd3%
;~ gui,+toolwindow -caption +lastfound
;~ gui,color,EEAACC,black
;~ winset,TransColor,EEAACC
;~ gui,font,s14 csilver,Georgia
;~ gui,add,button,w0 h0 gnothing
;~ gui,add,text,vthisAccNoText3 hwndthisAccNoTextHwnd3 w0 h0



gui,1:default
gui,+hwndguiHwnd 
guihwnd1:=guihwnd
groupadd,MyGui,ahk_id %guiHwnd%
GroupAdd,mainGui,ahk_id %guiHwnd%
gui,+toolwindow -caption +lastfound
gui,color,EEAACC,black
winset,TransColor,EEAACC
gui,font,s14 csilver,Georgia
gui,add,button,w0 h0 gnothing
gui,add,text,vthisAccNoText hwndthisAccNoTextHwnd w0 h0

gosub calWidthHeight
sci:=new scintilla(guihwnd,5,5,guiPos.w-10,guiPos.h-10)
,sr:=sciSettings(sci)

;~ gui,3:Add,edit,% "x5 y5 w" guiPos.w-10 " h" guiPos.h-10,

editHwnd:=sci.hwnd
;~ ,sci_bk:=sci
;~ ,editHwnd1:=editHwnd

;~ WinGetPos,x,y,w,h,ahk_id %guihwnd_%
;~ WinSetTitle,ahk_id %guihwnd1%,,simple RIS
;~ WinSetTitle,ahk_id %guiHwnd3%,,simple RIS3

;~ MsgBox % WinExist("ahk_id " guihwnd1)
;~ MsgBox % WinExist("ahk_id " guiHwnd3)
;~ MsgBox % WinGetTitle(guihwnd1)
;~ MsgBox % WinGetTitle(guiHwnd3)
;~ if !(x y w h =""){
	;~ if !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
		;~ gui,Show,% "x" x " y" y  " w" w " h" h,simple RIS
	;~ else
		;~ gui,3:Show,% "x" x " y" y  " w" w " h" h,simple RIS3
;~ }else{
	;~ if !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
		gui,show,% "x" guiPos.x " y" guiPos.y " w" guiPos.w " h" guiPos.h,simple RIS
	;~ else
		;~ gui,3:show,% "x" guiPos.x " y" guiPos.y " w" guiPos.w " h" guiPos.h,simple RIS3
;~ }
;~ changeEdit()
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
	sci.StyleSetFore(SCLEX_CONTAINER, 0xDDDDDD), sci.StyleSetBack(SCLEX_CONTAINER, 0x000000), sci.StyleSetBold(SCLEX_CONTAINER, false), sci.StyleSetFont(SCLEX_CONTAINER, "Georgia"), sci.StyleSetSize(SCLEX_CONTAINER, Fontsize)
	,sci.StyleSetFore(STYLE_DEFAULT, 0xDDDDDD), sci.StyleSetBack(STYLE_DEFAULT, 0x000000), sci.StyleSetBold(STYLE_DEFAULT, false), sci.StyleSetFont(STYLE_DEFAULT, "Georgia"), sci.StyleSetSize(STYLE_DEFAULT, Fontsize)
	,sci.StyleSetFore(SCE_AHKL_USERDEFINED1, 0xFFFFFF), sci.StyleSetBack(SCE_AHKL_USERDEFINED1, 0x000000), sci.StyleSetBold(SCE_AHKL_USERDEFINED1, true), sci.StyleSetFont(SCE_AHKL_USERDEFINED1, "Georgia"), sci.StyleSetSize(SCE_AHKL_USERDEFINED1, Fontsize-1)
	
	, sci.SetMarginWidthN(1,0)
	if main
		sci.GrabFocus()
		, sci.Notify:="Notify"
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
	sci.CONVERTEOLS(0)
	SCI_ColorRadReport(sci,sr,0)
	;~ if ((Text1:=SCI_GETTEXT(sci)) != (Text2:=sci_.getText()) ){
		;~ settimer,updateSci,-1000
	;~ }
	
}
return


updateSci:
return
sci.CONVERTEOLS(0)
if ((Text1:=SCI_GETTEXT(sci)) != (Text2:=sci_.getText()) ){
	if(Trim(Text1)!="")
		sci_.SetText(Text1)
		,Edit_GetSel(sci.hwnd,s,e)
		,Edit_SetSel(editHwnd_,s,e)
	else if (Trim(Text2)="")
		PostMessage,0x2024,,,,ahk_id %guihwnd_%
	else{
		sci_SetText(sci, tmp:=Text2)
		,Edit_GetSel(editHwnd_,s,e)
		,Edit_SetSel(sci.hwnd,s,e)
		,sci.ScrollCaret()
		PostMessage,0x2020,,,,ahk_id %guihwnd_%
	}
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

~^n::
resetEdit:
;~ ToolTip % A_TickCount "resetEdit"
;~ settimer,update,Off
;~ sr.reset()
sr.SetText(unused, t:="")
sci.ClearAll()
;~ Edit_SetText(editHwnd1, "")
;~ Edit_SetText(edithwnd3, "")
;~ settimer,update,-3000
;~ FileAppend,% a_now ": resetEdit `r`n",templog.txt,utf-8
return

exit(){
	ExitApp
}

esc::
~#!q::
ExitApp
return
if(a_thishotkey=a_priorhotkey && a_timesincepriorhotkey<300){
	if !WinExist("simpleRIS_main ahk_class AutoHotkeyGUI"){
		for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where CommandLine like '%simpleRISDelegate.cmd%' ")
			TaskKill(process.ProcessID)
		ExitApp
	}else
		PostMessage,0x10101,,,,simpleRIS_main ahk_class AutoHotkeyGUI
}
return


changeEdit(){
	local x,y,w,h, changed, s, e
	changed:=false
	if WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI"){
		if (guihwnd!=guiHwnd3){
			guihwnd:=guiHwnd3, edithwnd:=edithwnd3, sci:=new FakeRemoteScintilla(edithwnd3)
			WinGetPos,x,y,w,h,ahk_id %guihwnd1%
			WinHide,ahk_id %guihwnd1%
			WinShow,ahk_id %guihwnd%
			WinMove,ahk_id %guihwnd%,,% x,% y,% w, % h
			winactivate,ahk_id %guihwnd%
			Edit_GetSel(editHwnd1, s, e)
			,Edit_SetText(editHwnd, Edit_GetText(editHwnd1))
			,Edit_SetSel(editHwnd, s, e)
			,changed:=true
		}
	}else{
		if (guihwnd!=guihwnd1){
			guihwnd:=guihwnd1, edithwnd:=editHwnd1, sci:=sci_bk
			WinGetPos,x,y,w,h,ahk_id %guiHwnd3%
			WinHide,ahk_id %guiHwnd3%
			WinShow,ahk_id %guihwnd%
			WinMove,ahk_id %guihwnd%,,% x,% y,% w, % h
			winactivate,ahk_id %guihwnd%
			Edit_GetSel(edithwnd3, s, e)
			,Edit_SetText(editHwnd, Edit_GetText(edithwnd3))
			,Edit_SetSel(editHwnd, s, e)
			,changed:=true
		}
	}
	
	if changed
		PostMessage,0x2030,,,,simpleRIS_main ahk_class AutoHotkeyGUI
}