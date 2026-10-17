#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,Ignore
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
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <risimpax>
#include <prettyReport>
;~ #include <Class_RichEdit>
#include <winvisible>
#include <wingetatcoords>
#include <SCI>
#include <RemoteScintilla>
#include <SetTimerFn>
#include <SetWindowsHookEx>
;~ #include <UIAutomationServer>
#include <GetFocusedHwnd>
#include <CheckUpdate>
#include <SetTimerF>
#include <EmptyMem>
#include <Edit>
#InstallMouseHook
#InstallKeybdHook
;~ SetTimerF("scs_sync", -1)
;~ scs_sync()
;~ #include <Edit>
;~ runTimeBP("###")


;~ MsgBox,,,,1



lastClick:=0
;~ try
	;~ run % A_ScriptDir "\simpleRIS_patch.exe"
;~ gosub setHotkey
confirmRenew:=0
,history:=[]
,historySize:=100
,historyInd:=0
,onmessage(0x2020,"updatehxfirst")
,onmessage(0x2021,"clearSelection")
,onmessage(0x2022,"noUpdateMode")
,onmessage(0x2023,"pauseUpdateMode")
;~ ,onmessage(0x2024,"resetEdit")
;~ ,onmessage(0x2025,"reposition")
;~ ,onmessage(0x2026,"openStudy")
;~ ,onmessage(0x2027,"resetReports")
,OnMessage(0x2030, "CopyOldReport")
,OnMessage(0x2031, "HideWin")

,onmessage(0x1122,"accNoChanged")
,onmessage(0x1123,"ReportChanged")
,onmessage(0x1124,"oldReportChanged")
,thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))
,OnMessage(0x8000, "RisStateChange")
,OnMessage(0x10101, "exit")

RISImpaxRegister([  {app: "Ris", type: "State", hwnd: thisHwnd, msg: {msg: 0x8000}, Func: "RisStateChange"}
	, {app: "Ris", type: "OldReport", hwnd: thisHwnd, msg: {msg: 0x1124}, Func: "oldReportChanged"}
	, {app: "Ris", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x1122}, Func: "accNoChanged"}])

gui,main:new,+hwndguihwnd
WinSetTitle,% "ahk_id " guihwnd,,prettyOldHx_main

;~ clipboard:=thisHwnd

;~ gui,main:Default
;~ gui +hwndguihwnd
;~ WinSetTitle,% WinExist(),,prettyOldHx_main
;~ clipboard.=guihwnd+0 "`n"

;~ OnMessage( 0x111, "focusMsg" )
mouseHooks:=[]
,monitors:=monitorInfo()
;~ settimer,loadRisText,-1

gosub renewRis
gosub renewRisReports
;~ gosub gui
gosub calWidthHeight
settimer,prettyReportGui,-1000
;~ settimer,autoActivate,-500,-1
;~ settimer,updateHxLoc,-500


;~ settimer,GrabFocus,-2000,-2
;~ Loop, 4
;~ {
	;~ Gui, notify%A_Index%: -Caption +ToolWindow +AlwaysOnTOp
	;~ Gui, notify%A_Index%: Color, white
;~ }
;~ settimer,test,500
;~ OnMessage( 0x200, "WM_MOUSEMOVE" )

;~ settimer,ShowOntop,1
;~ GroupAdd,pacs,ahk_exe impax-client-main.exe
;~ GroupAdd,pacs,ahk_exe WEBVIE~1.exe
;~ SetTimerF("activeWin",500)
;~ settimer,test,500
;~ settimer,ToolTip,5000
settimer,EmptyMem,300000
return

register:

return

updatehxfirst(){
	gosub updatehxfirst
}
ClearSelection(){
	gosub ClearSelection
}

EmptyMem:
EmptyMem(thisPid)
return


activeWin(){
	static lastActiveWin
	global guihwnd
	thisActiveWin:=WinExist("A")
	if(lastActiveWin=thisActiveWin && (lastActiveWin:=thisActiveWin))
		return
	
	if(thisActiveWin=getSimpleRisGuiHwnd())
			;~ ToolTip % "On top"
		settimer,setontop,-1
	else {
		winget,ProcessName,ProcessName,ahk_id %thisActiveWin%
		 if (ProcessName ~= MatchPacsProcessName() ){
			;~ ToolTip % ProcessName
			settimer,setNotOnTop,-1
			;~ WinInsertAfter(guihwnd, thisActiveWin)
		}
	}
	lastActiveWin:=thisActiveWin
}

Showontop:
Critical
WinGet, ExStyle, ExStyle, % "ahk_id " RisState[2]
if (ExStyle & 0x8)
	pause
return

;~ esc::ListLines

getSimpleRisGuiHwnd(){
	;~ PID:=winget("PID", "simpleRIS__main ahk_class AutoHotkeyGUI")
	;~ return WinExist("simple RIS ahk_pid " PID)
	h:=getSimpleRisGuiHwnds()
	return h[2]?h[2]:h[1]
}
getSimpleRisEditHwnd(){
	;~ controlget,hwnd,hwnd,,Scintilla1,% "ahk_id " getSimpleRisGuiHwnd()
	;~ return hwnd
	static pEditHwnd
	if controlexists(pEditHwnd)
		return pEditHwnd
	h:=getSimpleRisEditHwnds()
	return pEditHwnd:=h[2]?h[2]:h[1]
}
;~ ^t::
activateSimpleRis:
;~ simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")
winactivate,% "ahk_id " getSimpleRisGuiHwnd()
ControlFocus,,% "ahk_id " getSimpleRisEditHwnd()
;~ gosub setontop
;~ settimer,setontopinstant,-100
return

#IfWinActive,ahk_exe prettyOldHx.exe
~CapsLock up::
PostMessage,0x2028,,,,simpleRIS_main ahk_class AutoHotkeyGUI
#IfWinActive

setontop:
return
winset,AlwaysOnTop,On,% "ahk_id " getSimpleRisGuiHwnd()
if !WinExist("WM_COPYDATA_Listener_miniPACS")
	winset,AlwaysOnTop,Off,% "ahk_id " getSimpleRisGuiHwnd()
return


if(A_TickCount-setontoptick)<500
	goto setontopreturn
setontopinstant:
return
;~ simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")
IfWinNotActive,ahk_group pacs
	DllCall("SetWindowPos", "Ptr", getSimpleRisGuiHwnd(), "Ptr", 0, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	,DllCall("SetWindowPos", "Ptr", getSimpleRisGuiHwnd(), "Ptr", -1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
else 
	DllCall("SetWindowPos", "Ptr", getSimpleRisGuiHwnd(), "Ptr", -2, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	
	
	;~ ,DllCall("SetWindowPos", "Ptr", impaxOpened()[2,1], "Ptr", guihwnd, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	;~ settimer,setNotOnTop,-1000

setontopreturn:
setontoptick:=A_TickCount
settimer,CancelOnTop,-5000
return

CancelOnTop:
winset,AlwaysOnTop,Off,% "ahk_id " getSimpleRisGuiHwnd()
return
setNotOnTop:
;~ simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")
winset,AlwaysOnTop,Off,% "ahk_id " getSimpleRisGuiHwnd()
;~ gui,1:Hide
DllCall("SetWindowPos", "Ptr", getSimpleRisGuiHwnd(), "Ptr", 1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)

;~ winactivate,ahk_id %activeWIn%
WinInsertAfter(getSimpleRisGuiHwnd(), WinExist("A"))
WinHide,% "ahk_id " getSimpleRisGuiHwnd()
gui,1:show,NoActivate,simple RIS
;~ gui,1:show,NoActivate
return

setFocus:
guicontrolget,guifocused,focus
if !instr(guifocused,"scintilla")
	guicontrol,focus,scintilla1
return

reposition(wParam, lParam, msg, hwnd){
	;~ global
	;~ initAtCenter:=wParam
	;~ gosub calWidthHeight
	;~ WinMove,% "ahk_id " getSimpleRisGuiHwnd(),,% guiPos.x,% guiPos.y,% guiPos.w,% guiPos.h
}

noUpdateMode(wParam="", lParam="", msg="", hwnd=0, reactivation=-10000){
	global noUpdateMode:=lParam
	;~ winget,pn,ProcessName,ahk_id %hwnd%
	;~ ToolTip % "noupdate," wParam "," lParam  "," pn
	;~ ToolTip % A_TickCount "," reactivation
	if(lParam){
		if (wParam+0)>0
			reactivation:=(-1)*(wParam+0)
		;~ ToolTip % reactivation
		settimer,ReactivateUpdateMode,% Abs(reactivation)*(-1)
		
	}else{
		settimer,ReactivateUpdateMode,-1
	}
}

pauseUpdateMode(wParam="", lParam="", msg="", hwnd=0, reactivation=-10000){
	global PauseUpdate:=lParam
	;~ ToolTip % "pause," wParam "," lParam
	if(lParam){
		if (wParam+0)>0
			reactivation:=(-1)*(wParam+0)
		;~ ToolTip % reactivation
		settimer,ReactivateUpdateMode,% Abs(reactivation)*(-1)
		
	}else{
		settimer,ReactivateUpdateMode,-1
	}
}
ReactivateUpdateMode:
;~ ToolTip % "reactive" A_TickCount
noUpdateMode:=PauseUpdate:=0
;~ , sci.Notify:="Notify"
;~ PostMessage,0x2020,,,,simple RIS ahk_class AutoHotkeyGUI
settimer,updatehxfirst,-1
return


findClosedResult(arr, len, s, e){
	min:="", minInd:=""
	for k,v in arr
		if (min="" || min<(newMin:=getMinDis(arr-s, arr-e, arr+len-s, arr+len-e)))
			min:=newMin,minInd:=k
	
	return k
}

getMinDis(param*){
	min:=""
	
	for k,v in param
		if(min="" || min<v)
			min:=v
		
	return min
		
}

searchText(findWhat, inText){
	arr:=[],i:=0,match:="0"
	findWhat:=RegExReplace(findWhat,"\W","\$0")
	
	while (i:=regexmatch(inText, "i)" findWhat, match, i+strlen(match))) {
		arr.push(i)
	}
	return arr
}

;~ #ifwinactive,ahk_group pr
~lbutton::
;~ return
;~ settimer,updateHxLoc,-1
;~ settimer,ReactivateUpdateMode,-1
mousegetpos,,,win,con,2
;~ winget,processName,processName,ahk_id %win%
if (win=pr1hwnd || win=pr2hwnd){
	if (A_TickCount-lastClick<500){
		gosub copyOldReport
	}
	lastClick:=A_TickCount
	
}
return


if !(win=pr1hwnd || win=pr2hwnd || win=pr3hwnd)
	return
if !(InStr(a_priorhotkey, a_thishotkey) && a_timesincepriorhotkey<500)
;~ if(A_TickCount-guiClickTick>500){
	;~ guiClickTick:=A_TickCount
	return
;~ }
;~ gosub renewRis
;~ gosub renewRisReports

copyOldReport:
gosub ClearSelection
ditto:
;~ mousegetpos,,,win,con,2
if(win=pr1hwnd){
	controlsettext,,% AddPeriodEndCapitalizeAll(RegExReplace(controlgettext(risreports[1,2]) reportReplace(controlgettext(risReports[2,2])), "\r?\n", "`r`n")),% "ahk_id " risReports[1,2]
	;~ controlsettext,,% text:=controlgettext(risreports[1,1]) controlgettext(risReports[2,1]),% "ahk_id " getSimpleRisEditHwnd()
	;~ sci.Notify:=""
	Edit_SETTEXT((editHwnds:=getSimpleRisEditHwnds())[2],tmp:=text:=AddPeriodEndCapitalizeAll(controlgettext(risreports[1,1]) reportReplace(controlgettext(risReports[2,1]))))
	,Edit_SETTEXT(editHwnds[1],tmp:=text)
	;~ ,sci.Notify:="Notify"
	controlsettext,,% RegExReplace(text, "\r?\n", "`r`n"),% "ahk_id " risReports[1,1]
	gosub activateSimpleRis
}else if(win=pr2hwnd){
	controlsettext,,% AddPeriodEndCapitalizeAll(RegExReplace(controlgettext(risreports[1,2]) reportReplace(controlgettext(risReports[2,2])), "\r?\n", "`r`n")),% "ahk_id " risReports[1,2]
	winactivate,% "ahk_id " RisState[2]
	ControlFocus,,% "ahk_id " RisReports[1,2]
	Edit_Setsel(RisReports[1,2],len:=Edit_GetTextLength(RisReports[1,2]),len)
	,Edit_ScrollCaret(RisReport[1,2])
}

return
;~ #IfWinActive

;~ t::
;~ ListLines
;~ Pause
;~ return

;~ !+t::
;~ ListLines
;~ return


getSelectionText(ByRef sci){
	return (new RemoteScintilla(sci.hwnd)).GetSelText()
}

AddPeriodEndCapitalizeAll(ByRef str){
	s:=""
	Loop,Parse,str,`n,`r
		s.=AddPeriodEnd(capitalize(RTrim(A_LoopField))) "`r`n"
	return RegExReplace(s, "is)([a-z] ) +(.)|(.) +( [a-z])", "$1$2$3$4")
}


AddPeriodEnd(ByRef str){
	if !(str~="\w")
		return str
	else if !(str~="\W\s*$"){
		RegExMatch(str, "(\w+)(\s*)$", match)
		End:=(match1~="i)^show")?":":"."
		return match2=""?str End:SubStr(str,1, (-1)*StrLen(match2)) End match2
	}else
		return str
}

CopyOldReport(w=0,l=0,m=0,h=0){
	global
	CopyOldReportFromClipboard:=true
	gosub autoCopyOldReport
}

~lbutton up::
if(A_TimeSincePriorHotkey<400)
	return
mousegetpos,,,win
;~ winget,processName,processName,ahk_id %win%
;~ MsgBox % (win=pr1hwnd) "," (win=pr2hwnd) "," (win=pr3hwnd)
if !(win=pr1hwnd || win=pr2hwnd || win=pr3hwnd)
	return
altPressed:=GetKeyState("Alt"), shiftPressed:=GetKeyState("Shift"), ctrlPressed:=GetKeyState("Ctrl")
;~ KeyWait,LButton,t0.5 D
;~ if !ErrorLevel
	;~ return
;~ ToolTip % getSelectionText(sci1) 
postmessage,0x2020,,,,simpleRIS_main ahk_class AutoHotkeyGUI
autoCopyOldReport:
controlget,mammoSRMode,hwnd,,Edit3,Mammography Structured Report ahk_class AutoHotkeyGUI
if CopyOldReportFromClipboard || (win=pr1hwnd && (selText:=getSelectionText(sci1))!="") || (win=pr3hwnd && (selText:=getSelectionText(sci3))!=""){
	
	if CopyOldReportFromClipboard
		selText:=clipboard
	;~ ToolTip % selText "," CopyOldReportFromClipboard
	selText:=RegExReplace(selText, "i) *\(? *SE\d+[ ,]*IM\d+[ ,\-\~;\d+IM]*\)?","")
	selText:=reportReplace(selText)
	
	if(shiftPressed && !CopyOldReportFromClipboard){
		clipboard:=selText
		ToolTip % "Text copied!"
		settimer,ToolTip,-1000
	}else{
		postmessage,0x2021,,,,simpleRIS_main ahk_class AutoHotkeyGUI
		paste:="",oldText:=mammoSRMode?ControlGetText(mammoSRMode):Edit_GetText(getSimpleRisEditHwnd())
		;~ StringReplace,paste,paste,`r,,all
		;~ paste:=RegExReplace(paste,"\s*\n+\s*","`n")
		;~ paste:=RegExReplace(paste,"\n+","`n")
		;~ paste:=RegExReplace(paste,"\s*\n\s*","; ")
		
		
		RegExMatch(oldText, "is)(.*?)[\r\n]*([\da-z]+\/\/)?$", oldTextMatch)
		oldText:=oldTextMatch1
		,oldTextAbrv:=oldTextMatch2
		,moreDelim:=altPressed?".":""
		
		if !mammoSRMode && ((oldText="") || regexmatch(oldText,"i)History:\s+$") || (regexmatch(oldText,"i)History: ") && regexmatch(oldText,";\s*$"))) {
			selText:=RegExReplace(selText, "i)(^[^a-z0-9\(\)]+)|([^a-z0-9\(\)]+$)", "")
			loop,parse,selText,`n`r
				if (trim(a_loopfield)!="")
					paste.=RegExReplace(trim(a_loopfield),"[^\w\+\)]+$","") "; "
			;~ Controlsettext,,% text:=RegExReplace(sentText:=abbr((oldText=""?"History: ":oldText) paste),"(\d).\r?\n- (\d)","$1.$2"),% "ahk_id " RisReports[1,1]
			text:=RegExReplace(sentText:=abbr((oldText=""?"History: ":oldText) paste),"(\d).\r?\n- (\d)","$1.$2")
		} else if (ctrlPressed) {
			;;; multiple to one line
			selText:=RegExReplace(selText, "i)(^[^a-z0-9]+)|([^a-z0-9]+$)", "") 
			loop,parse,selText,`n,`r
				if (trim(a_loopfield)!="")
					line:=trim(a_loopfield)
					,line:=RegExReplace(line, "^\s*(([^\w\(])+|(\(?\d+\W?))\s*", "")
					,paste.=AddPeriodEnd(line) " "
			
			paste:=StringLowerFirst(paste)
			,Edit_GetSel(getSimpleRisEditHwnd(), s, e)
			,text:= (sentText:= SubStr(oldText, 1, s) paste ) SubStr(oldText, s+1)
		} else if InStr(oldText,"  -- ") {
			
			Edit_GetSel(getSimpleRisEditHwnd(), s, e)

			,selText:=RegExReplace(selText,"m)^\d*\W+","")
			loop,parse,selText,`n,`r%moreDelim%
				if (trim(a_loopfield)!="")
					paste.=AddPeriodEnd(capitalize(trim(a_loopfield)) moreDelim) "`r`n  -- "
			text:= (sentText:= SubStr(oldText, 1, s) paste ) SubStr(oldText, s+1)
			
		} else if regexmatch(oldText,"\n([^\n\r\w]+)$",match) || (mammoSRMode) {
			if(mammoSRMode && match1="") || CopyOldReportFromClipboard
				match1:="- "
		
			selText:=RegExReplace(selText,"m)^\d*\W+","")
			loop,parse,selText,`n%moreDelim%,`r
				if (trim(a_loopfield)!="")
					paste.=AddPeriodEnd(capitalize(trim(a_loopfield)) moreDelim) "`r`n" match1
			
			;~ Controlsettext,,% RegExReplace(sentText:=oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2"),% "ahk_id " RisReports[1,1]
			text:=RegExReplace(sentText:=(oldText="" && mammoSRMode?match1:"") oldText capitalize(paste),"(\d).\r?\n" match1 "(\d)","$1.$2")
		} else if regexmatch(oldText,"\n(\d+)([^\n\r\w]+)$",match) {
			selText:=RegExReplace(selText,"m)^\d*\W+","")	
			loop,parse,selText,`n%moreDelim%,`r
				if (trim(a_loopfield)!="")
					paste.=AddPeriodEnd(capitalize(trim(a_loopfield)) moreDelim) "`r`n" (++match1) match2
			;~ Controlsettext,,% RegExReplace(sentText:=oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2"),% "ahk_id " RisReports[1,1]
			text:=RegExReplace(sentText:= oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2")
		}else if RegExMatch(oldText, "\n([^\n\r\w]+)[^\r\n]+\s*$", match){
			selText:=RegExReplace(selText,"m)^\d*\W+","")	
			loop,parse,selText,`n%moreDelim%,`r
				if (trim(a_loopfield)!="")
					paste.=match1 AddPeriodEnd(capitalize(trim(a_loopfield)) moreDelim) "`r`n"
			;~ Controlsettext,,% RegExReplace(sentText:=oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2"),% "ahk_id " RisReports[1,1]
			text:=RegExReplace(sentText:=RegExReplace(oldText, "\s+$", "") "`r`n" capitalize(paste)  match1,"(\d).\r?\n- (\d)","$1.$2")
		}else if RegExMatch(oldText, "\n(\d+)([^\n\r\w]+)[^\r\n]+\s*$", match){
			selText:=RegExReplace(selText,"m)^\d*\W+","")	
			loop,parse,selText,`n%moreDelim%,`r
				if (trim(a_loopfield)!="")
					paste.=(++match1) match2 AddPeriodEnd(capitalize(trim(a_loopfield)) moreDelim) "`r`n"
			;~ Controlsettext,,% RegExReplace(sentText:=oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2"),% "ahk_id " RisReports[1,1]
			text:=RegExReplace(sentText:=RegExReplace(oldText, "\s+$", "") "`r`n" capitalize(paste)  ++match1,"(\d).\r?\n- (\d)","$1.$2")
		}
		;~ controlsettext,,% text, % "ahk_id " RisReports[1,1]
		;~ Edit_SetSel(RisReports[1,1],len:=strlen(sentText),len)
		;~ Edit_ScrollCaret(RisReports[1,1])
		CopyOldReportFromClipboard:=false
		,text.="`r`n" oldTextAbrv
		,Edit_SETTEXT(targetEdit:=mammoSRMode?mammoSRMode:getSimpleRisEditHwnd(),  text)
		,Edit_SETTEXT(getSimpleRisEditHwnds()[1],  text)
		;~ Edit_SetText(sci, text)
		 ;~ (new RemoteScintilla(sci.hwnd)).SetText(text)
		,Edit_SetSel(targetEdit,len:=strlen(sentText),len)
		,Edit_ScrollCaret(targetEdit)
		
		if (mammoSRMode){
			winactivate,Mammography Structured Report ahk_class AutoHotkeyGUI
		}else{
			postmessage,0x2020,,,,simpleRIS_main ahk_class AutoHotkeyGUI
			gosub activateSimpleRis
		}
		
	}
}else if (win=pr2hwnd && (selText:=getSelectionText(sci2))!=""){
	selText:=reportReplace(selText)

	if(shiftPressed){
			clipboard:=selText
			ToolTip % "Text copied!"
		settimer,ToolTip,-1000
	}else{
		controlsettext,,% AddPeriodEndCapitalizeAll(RegExReplace((oldImp:=controlgettext(risreports[1,2])) (oldImp=""?"":"`r`n") selText "`r`n", "(\r?\n){2,}", "`r`n")),% "ahk_id " risReports[1,2]
		WinActivate,% "ahk_id " RisState[2]
		ControlFocus,,% "ahk_id " RisReports[1,2]
		Edit_Setsel(RisReports[1,2],len:=Edit_GetTextLength(RisReports[1,2]),len)
		,Edit_ScrollCaret(RisReport[1,2])
	}
}
settimer,ClearSelection,-500
return



reportReplace(Text){
	Text:=RegExReplace(Text, "i)a (stable|stationary) *(\W)", "an unchanged$2")
	,Text:=RegExReplace(Text, "i)(stable|stationary) *(\W)", "unchanged$2")
	,Text:=RegExReplace(Text, "(\r?\n)+$", "`r`n")
	, Text:=RegExReplace(Text, "i)phayngeal", "phayrngeal")
	, Text:=RegExReplace(Text, "i)masectomy", "mastectomy")
	, Text:=RegExReplace(Text, "i)no enlarge ", "no enlarged ")
	, Text:=RegExReplace(Text, "\bLAPs?\b", "lymphadenopathy")
	, Text:=RegExReplace(Text, "i)\bsusp(\.|\b)", "suspicious")
	, Text:=RegExReplace(Text, "i)\bLt(\.|\b)", "left")
	, Text:=RegExReplace(Text, "i)(?<!-)\bRt(\.|\b)", "right")
	, Text:=RegExReplace(Text, "i)\bBil?(\.|\b)(?!-)", "bilateral")
	, Text:=RegExReplace(Text, "i)\bs/p\b", "status post")
	, Text:=RegExReplace(Text, "\bL.?N.?s\b", "lymph nodes")
	, Text:=RegExReplace(Text, "\bL.?N.?\b", "lymph node")
	return Text
}



abbr(str){
	str:=RegExReplace(str,"status post","s/p")
	,str:=RegExReplace(str,"squamous cell carcinoma","SCC")
	,str:=RegExReplace(str,"hepatocellular carcinoma","HCC")
	,str:=RegExReplace(str,"left lower lobe","LLL")
	,str:=RegExReplace(str,"right lower lobe","RLL")
	,str:=RegExReplace(str,"left upper lobe","LUL")
	,str:=RegExReplace(str,"right upper lobe","RUL")
	,str:=RegExReplace(str,"right middle lobe","RML")
	,str:=RegExReplace(str,"transarterial embolization","TAE")
	return str
}

ClearSelection:
if GetKeyState("LButton") || GetKeyState("Shift") || GetKeyState("Alt") {
	settimer,,-1000
	return
}
Loop 3 {
	(new RemoteScintilla(sci%a_index%.hwnd)).GetSel(curS, curE)
	if !(curS=curE)
		sci%a_index%.SETSEL(curS, curS)	
	;~ ToolTip % curS "," curE
}
return

TrimClipboard:
clipboard:=trim(clipboard)
return

prettyReportGui:
Critical
if(pr1hwnd||pr2hwnd||pr3hwnd)
	return

Loop 3 {
	gui,pr%a_index%:default 
	gui,+hwndpr%a_index%hwnd +toolwindow -caption -border  +lastfound
	Groupadd,pr,% "ahk_id " pr%a_index%hwnd
	Groupadd,MyGUI,% "ahk_id " pr%a_index%hwnd
	gui,color,EEAACC,black
	winset,TransColor,EEAACC
	gui,font,s14 csilver,Georgia
	gui,add,button,w0 h0 gnothing
	sci%a_index% := new scintilla(pr%a_index%hwnd,1,1,1,1)
	,prSR%a_index%:=sciSettings(sci%a_index%, false)
}


gosub updateHxLoc
settimerF("accNoChanged", -1)
return

RangeBetween(x,min,max){
	return x>=min && x<=max
}
RangeOverlap(x1,x2,y1,y2){
	return RangeBetween(x1,y1,y2) || RangeBetween(y1,x1,x2)
}
PointInArea(x,y, x1,y1,w1,h1){
	return RangeBetween(x,x1,x1+w1-1) && RangeBetween(y,y1,y1+h1-1)
}
AreaOverlap(x1,y1,w1,h1, x2,y2,w2,h2){
	return PointInArea(x1,y1, x2,y2,w2,h2) || PointInArea(x1+w1-1,y1, x2,y2,w2,h2) || PointInArea(x1,y1+h1-1, x2,y2,w2,h2) || PointInArea(x1+w1-1,y1+h1-1, x2,y2,w2,h2) || PointInArea(x2,y2, x1,y1,w1,h1) || PointInArea(x2+w2-2,y2, x1,y1,w1,h1) || PointInArea(x2,y2+h2-2, x1,y1,w1,h1) || PointInArea(x2+w2-2,y2+h2-2, x1,y1,w1,h1)
}



hxGuiHidden(){
	global
	Loop 3
			try
			gui,% pr%a_index%hwnd ":hide"
		hxGuiHidden:=true
}

hxGuiShow(i){
	global
	if (i=1){
		gui,% pr%i%hwnd ":show",% "NoActivate x" risX+x%i%+1 " y" risY+y1-19 " w" (w%i%+1) " h" (risH-y1+20)*3//4+1
		ControlMove,,,,% w%i%,% (risH-y1+20)*3//4,% "ahk_id " sci%i%.hwnd
	}else if(i=2){
		gui,% pr%i%hwnd ":show",% "NoActivate x" risX+x%i%+1 " y" risY+y1-19+(risH-y1+20)*3//4+1 " w" (w%i%+1) " h" (risH-y1+20)//4+1
		ControlMove,,,,% w%i%,% (risH-y1+20)//4,% "ahk_id " sci%i%.hwnd
	}else if(i=3){
		gui,% pr%i%hwnd ":show",% "NoActivate x" risX+x%i%+1 " y" risY+y%i%+1 " w" (w%i%)+1 " h" (h%i%)+101
	ControlMove,,,,% w%i%,% h%i%+100,% "ahk_id " sci%i%.hwnd
	}
	;~ WinMove,% "ahk_id " pr%i%hwnd,,% risX+x%i%+1,% risY+y%i%+1,% w%i%,% h%i%
	;~ ToolTip % risX+x%i%+1 "," risY+y%i%+1 "," w%i% "," h%i%
	
	
	hxGuiHidden:=false
	settimer,updateHxLoc,-1000
	;~ settimer,pastHxGUIOnTop,-500
	winset,AlwaysOnTop,on,% "ahk_id " pr%i%hwnd	
	gosub updatehx_%i%
}

updateHxLoc:
;~ ToolTip % A_TickCount
	;~ global noUpdateMode,hxGuiHidden,RisState,oldReportHwnd,RisReports,pr1hwnd,pr2hwnd,pr3hwnd,sci1,sci2,sci3,thisPid
	
	
	if GetKeyState("LButton") || GetKeyState("Shift") || GetKeyState("Alt"){
		settimer,updateHxLoc,-500
		return
	}
	
	if(prettyOldHxWinHidden){
		hxGuiHidden()
		settimer,updateHxLoc,-100
		return
	}
	
	;~ Thread,Priority,1
	if (noUpdateMode){
		hxGuiHidden()
		;~ winhide,ahk_id %pr2hwnd%
		;~ goto updateHxEnd
		settimer,updateHxLoc,-1000
		return
	}
	
	;~ RisReports:=getRisReports(RisState[2])
	wingetpos,risX,risY,,risH,% "ahk_id " RisState[2]
	
	if !controlvisible(oldReportHwnd:=risreports[2,1]){
		hxGuiHidden()
		settimer,updateHxLoc,-100
		return
	}
	controlgetpos,x1,y1,w1,h1,,% "ahk_id " oldReportHwnd
	controlgetpos,x2,y2,w2,h2,,% "ahk_id " risreports[2,2]
	controlgetpos,x3,y3,w3,h3,,% "ahk_id " getRisClinicalInfoHwnd(RisState[2])
	coordHwnd:=wingetatcoords(risX+x1,risY+y1,"ID")
	
	if (coordHwnd!=RisState[2]){
		hxGuiHidden()
		settimer,updateHxLoc,-100
		return
	}

	WinGet,activeProcName,ProcessName,A
	WinGet,activePID,PID,A
	winget,activeHwnd,id,A
	WinGetPos,ax,ay,aw,ah,A
	if(ProcessName="Menu.exe"){
		ControlGetPos,cx,cy,aw,ah,,% "ahk_id " GetFocusedHwnd()
		ax+=cx
		ay+=cy
	}
	;~ ToolTip % x "," y "," x2 "," y2 "," x3 "," y3 ","x "," ay

	;~ ToolTip %  controlvisible(oldReportHwnd) "`n" (coordHwnd!=RisState[2]) "`n" (activePID!=thisPid) "`n" (activeHwnd!=RisState[2]) "`n" AreaOverlap(ax,ay,aw,ah,risX+x,risY+y,w,h) "`n" AreaOverlap(ax,ay,aw,ah,risX+x3,risY+y3,w3,h3) "`n" AreaOverlap(ax,ay,aw,ah,risX+x2,risY+y2,w2,h2)
	
	if !(pr1hwnd && pr2hwnd && pr3hwnd){
			settimer,updateHxLoc,-1000
			gosub prettyReportGui
			return
		}
			
	
	 if  ((activePID!=thisPid) && (activeHwnd!=RisState[2])){

	;~ msgbox % controlvisible(risreports[2,1])
	;~ if !(oldReportHwnd:=risreports[2,1]) || (!controlvisible(oldReportHwnd)) {
		;~ if(!hxGuiHidden){
			
			Loop 3
				try
				if AreaOverlap(ax,ay,aw,ah,risX+x%a_index%,risY+y%a_index%,w%a_index%,h%a_index%)
					gui,% pr%a_index%hwnd ":hide"
				else
					hxGuiShow(A_Index)
			
			;~ gui,% "pr3:" (AreaOverlap(ax,ay,aw,ah,risX+x3,risY+y3,w3,h3)?"hide":"show")
			;~ gui,% "pr2:" (AreaOverlap(ax,ay,aw,ah,risX+x2,risY+y2,w2,h2)?"hide":"show")
			;~ gui,% "pr1:" (AreaOverlap(ax,ay,aw,ah,risX+x,risY+y,w,h)?"hide":"show")
			
			
		;~ }
		;~ winhide,ahk_id %pr2hwnd%
		;~ return
	;~ }else{
		;~ tooltip % "show: " a_tickcount
		
		
		;~ WinInsertAfter(RisState[2], pr1hwnd)
		;~ gui,pr1:show,NoActivate
		;~ if(hxGuiHidden){
			;~ settimer,updatehxfirst,-500
			;~ Loop 3 
				;~ try
				;~ gui,% pr%a_index%hwnd ":show",NoActivate
			;~ hxGuiHidden:=false
			;~ settimer,updateHxLoc,-1000
			;~ gosub pastHxGUIOnTop
		;~ }
	}else{
		Loop 3 
			try 
				hxGuiShow(A_Index)
				
	}

	
	settimer,updateHxLoc,-500
	return





updateHx:
;~ Thread,Priority,-1
if (noUpdateMode){
	Loop 3
		gui,pr%a_index%:hide
	;~ winhide,ahk_id %pr2hwnd%
	hxGuiHidden:=true
	goto updateHxEnd
	return
}
if (PauseUpdate)
	goto updateHxEnd
;~ runTimeBP(1)
;~ gosub renewRis
;~ gosub renewRisReports
updatehxfirst:


if !IsObject(sci1) || !IsObject(sci2)  || !IsObject(sci3){
	gosub prettyReportGUI
	settimer,% A_ThisLabel,-500
	return
}

gosub ClearSelection
;~ ToolTip % SCI_GETTEXT(sci1)!= (txt:=controlgettext(risReports[2,1]))
gosub updatehx_1
gosub updatehx_2
gosub updatehx_3


updateHxEnd:
return


updatehx_1:
if(SCI_GETTEXT(sci1)!= (txt:=controlgettext(risReports[2,1])))
	sci1.SetReadOnly(false)
	,sci_SetText(sci1,tmp:=txt)
	,SCI_ColorRadReport(sci1,prSR1,1)
	,sci1.SetReadOnly(true)

return
updatehx_2:
if(SCI_GETTEXT(sci2)!= (txt:=controlgettext(risReports[2,2])))
	sci2.SetReadOnly(false)
	,sci_SetText(sci2,tmp:=controlgettext(risReports[2,2]))
	,SCI_ColorRadReport(sci2,prSR2,1)
	,sci2.SetReadOnly(true)

return
updatehx_3:
if(SCI_GETTEXT(sci3)!= (txt:=getClinicalInfo(RisState[2]))){
	sci3.SetReadOnly(false)
	,sci_SetText(sci3,tmp:=txt)
	,SCI_ColorRadReport(sci3,prSR3,1)
	,sci3.SetReadOnly(true)
	settimer,sci3Scroll,-500
	
}
return

sci3Scroll:
sci3.LineScroll(0, 9999)
return


pastHxGUIonTop:
<pastHxGUIonTop:
;~ winOrder:=GetWindowOrder(pr1hwnd)
;~ gosub renewRis
;~ isBeforeRIS:=0,idx:=winOrder.index
;~ for k,v in winOrder.arr
	;~ if (k>idx) && (v=RisState[2]) {
		;~ isBeforeRIS:=1
		;~ return
	;~ }
;~ winset,AlwaysOnTop,Off,simple RIS ahk_class AutoHotkeyGUI


;~ gui,pr1:show,NoActivate
;~ winset,alwaysontop,on,ahk_id pr1hwnd
;~ Sleep 100
;~ gui,pr2:show,NoActivate
;~ winset,alwaysontop,on,ahk_id pr2hwnd
;~ settimer,pastHxGUINotOnTop,-500
;~ gui,pr1:show,NoActivate
;~ gui,pr2:show,NoActivate
;~ WinShow,% "ahk_id " pr2hwnd
;~ DllCall("SetWindowPos", "UINT", pr1hwnd, "UINT", -1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
;~ ,DllCall("SetWindowPos", "UINT", pr2hwnd, "UINT", -1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
;~ winset,AlwaysOnTop,Off,% "ahk_id " pr1hwnd
;~ winset,AlwaysOnTop,Off,% "ahk_id " pr2hwnd
WinInsertAfter(pr3hwnd, pr2hwnd)
,WinInsertAfter(pr2hwnd, pr1hwnd)
;~ ,WinInsertAfter(RisState[2], pr2hwnd)

;~ WinGet, Style, Style, % "ahk_id " pr1hwnd 
;~ If (Style & 0x10000000){  ; 0x10000000 is WS_VISIBLE
	winset,AlwaysOnTop,On,% "ahk_id " pr1hwnd
	winset,AlwaysOnTop,On,% "ahk_id " pr2hwnd
	winset,AlwaysOnTop,On,% "ahk_id " pr3hwnd
;~ }
DllCall("SetWindowPos", "Ptr", RisState[2], "Ptr", -2, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
;~ DllCall("SetWindowPos", "UINT", RisState[2], "UINT", pr2hwnd, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
pastHxGUIonTop>:
return

pastHxGUINotOnTop:
winset,alwaysontop,Off,ahk_id %pr1hwnd%
winset,alwaysontop,Off,ahk_id %pr2hwnd%
winset,alwaysontop,Off,ahk_id %pr3hwnd%
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

;~ AutoComplete(len){
    ;~ global
    ;~ sci.AutoCShow(len, lst:=SciAutoCompleteList)
;~ }


calWidthHeight:
guiPos:=[]
if monitors.maxindex()=1
	guiPos.w:=A_ScreenWidth>A_ScreenHeight?Floor(A_ScreenWidth/2):Floor(A_ScreenWidth*2/3)
	,guiPos.h:=Floor(guiPos.w*0.3)
	, guiPos.x:="center"
	,guiPos.y:=initAtCenter?"center":A_ScreenHeight
else
	guiPos.w:=monitors.2.w>monitors.2.h?Floor(monitors.2.w/2):Floor(monitors.2.w*2/3)
	, b:=monitors.2.b
	, guiPos.h:=Floor(guiPos.w*0.3)
	, guiPos.x:=monitors.2.l+Floor(monitors.2.w/2 - guiPos.w/2)
	,guiPos.y:=initAtCenter?Floor(b/2 - guiPos.h/2):(b-150)

;~ ToolTip % initAtCenter "," guiPos.y
return

nothing:
return

editRedraw:
;~ guicontrol,% ((redraw:=!redraw)?"+":"-") "redraw",% editHwnd
return



focusEdit:
if(winactive("ahk_id " getSimpleRisGuiHwnd())){
	guicontrolget,focused,Focus
	if (focused!="Scintilla1"){
		guicontrol,Focus,scintilla1
	}
}

return


sizing:

return

focusMsg(p_w, p_l, p_m, p_hw){
	global editHwnd
	; EN_KILLFOCUS
	if ( p_w & 0x2000000 ){
		if(p_l=getSimpleRisEditHwnd()){
			controlfocus,,% "ahk_id " getSimpleRisEditHwnd()
		}
	}
}


update(){
	postmessage,0x2021,,,,simpleRIS_main ahk_class AutoHotkeyGUI
}

windowHook:
;~ DllCall( "RegisterShellHookWindow", UInt, guiHwnd )
;~ MsgNum := DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" )
;~ OnMessage( MsgNum, "ShellMessage" )
return

#ifwinactive,ahk_exe Menu.exe

;~ ~lbutton::
;~ if(a_priorhotkey=a_thishotkey && a_timesincepriorhotkey<500){
	;~ sleep 500
	;~ sci.SetText(unused, tmp:=controlgettext(RisReports[1,1]))
	;~ ,sci.Notify:="Notify"
	;~ settimer,update,-2000
;~ }
;~ settimer,updatehxfirst,-500
;~ return

;~ ~^b::
;~ gosub renewRis
;~ gosub renewRisReports
;~ if(getFocused()!=RisReports[1,1])
	;~ return

;~ return

#ifwinactive

#ifwinexist,ahk_exe Menu.exe
~^up::
~^down::
settimer,updateHx,-500
return
#IfWinExist



#ifwinactive,ahk_group MyGui



;~ ~rbutton::
;~ keywait, rbutton, t0.3
;~ if errorlevel = 1
;~ {
	;~ gosub loadRisText
;~ }

;~ ~^a::
;~ selectAll:=1
;~ return


focusImpression:
;~ ^space::
;~ if !(a_thishotkey=a_priorhotkey && a_timesincepriorhotkey<400)
	;~~ return
;~ gosub renewRis
;~ gosub renewRisReports
focusImpression:=1
,pAccNo:=cAccNo:=ControlGetText(risAccHwnd)
postmessage,0x2020,,,,simpleRIS_main ahk_class AutoHotkeyGUI
controlfocus,,% "ahk_id " RisReports[1,2]
winactivate,% "ahk_id " RisState[2]
controlfocus,,% "ahk_id " RisReports[1,2]
return



createBlack:
if(monitors.maxindex()<2)
	return

gui,black:new
gui,black:+toolwindow -caption +alwaysontop +hwndblackGuiHwnd
gui,black:color,black
winset,trans,200,% "ahk_id " blackGuiHwnd
gui,black:show,% "x" monitors[2].l " y" monitors[2].t " w" monitors[monitors.maxindex()].r - monitors[2].l + 1 " h" monitors[2].h,black
return




#ifwinactive

tooltip:
ToolTip
return

RisNextStudy:
getNetAcc(RisState[2],instr(a_thishotkey,"F12")?"cmdRunNext":"cmdRunFoword","WindowsForms10.BUTTON").accDoDefaultAction()
return

;~ resetReports:
;~ gosub renewRis
;~ gosub renewRisReports

;~ return




PacsIEnextStudy:
wingettitle,title,PacsIE Log GUI ahk_exe PacsIE.exe
regexmatch(title,"PacsIE Log GUI (\w+):",pacsIeHwnd)
if (pacsIeHwnd)
	PostMessage,% a_thishotkey="F12"?0x10504:0x10503,,,,PacsIE ahk_class AutoHotkey
return


checkActive:
if !winactive("ahk_id " getSimpleRisGuiHwnd()) && !hooked
 	gosub hookMouse
return

~#!q::
if(a_thishotkey=a_priorhotkey && a_timesincepriorhotkey<300)
;~ esc::
	exitapp

hookMouse:
return
;~ OnMessage( 0x200, "" ) 
;~ mouseHooks.push(SetWindowsHookEx(WH_MOUSE_LL   := 14, RegisterCallback("MouseHook", "Fast")))
;~ hooked:=1
return


autoActivate:
	;~ global pr1hwnd,pr2hwnd
	;~ static pMouseOverWin,MouseOverWin,lastActivateWin
	if getkeystate("Lbutton") || getkeystate("Rbutton") || getkeystate("Mbutton")
		return
	mousegetpos,,,MouseOverWin
	
	winget,processName,processName,ahk_id %MouseOverWin%
	if(ProcessName="Menu.exe" && (pMouseOverWin=pr3hwnd || pMouseOverWin=pr2hwnd || pMouseOverWin=pr1hwnd))
		winactivate,ahk_id %MouseOverWin%
	else if (MouseOverWin=pr3hwnd || MouseOverWin=pr2hwnd || MouseOverWin=pr1hwnd) && (pProcessName="Menu.exe") {
		winactivate,ahk_id %MouseOverWin%
		
	}
	pMouseOverWin:=MouseOverWin
	,pProcessName:=ProcessName
	

winget,pName,ProcessName,% "ahk_id " WinExist("A")
if(pName~=MatchPacsProcessName() "|PacsIE.exe|miniPACS_bridge.exe")
	settimer,setNotOnTop,-1,-2

settimer,,-500,-1
return

unhookMouse:
for k,v in mouseHooks
	UnhookWindowsHookEx(v)
mouseHooks:=[]
;~ hooked:=0
return

onexit:

noUpdateMode:=PauseUpdate:=0
;~ postmessage,0x2021,,,,simple RIS ahk_class AutoHotkeyGUI
;~ gosub unhookMouse
;~ ListLines
;~ Sleep 10000
;~ runTimeBP("---")
;~ WinClose,ahk_exe simpleRIS_patch.exe
;~ if !WinExist("ahk_exe autorun.exe")
	;~ WinClose,ahk_exe UIAutomationServer.exe
exitapp
return


AddHistory(text){
	global history, historyInd, historySize
	if(text!="" && text!=history[Mod(historyInd, historySize)])
		history[mod((++historyInd),historySize)]:=text
}


;~ t::
 ;~ sci.gettext(sci.GetTextLength()+1,text2:="")
;~ MsgBox % "." Edit_GetText(getSimpleRisEditHwnd()) "." Edit_GetText(sci.hwnd) "." text2
;~ return

loadRisText:
;~ gosub renewRis
;~ gosub renewRisReports

;~ text2:=controlgettext(editHwnd)
;~ sci.gettext(sci.GetTextLength()+3,text2:="")

AddHistory(text2:=Edit_GETTEXT(getSimpleRisEditHwnd()))

;~ controlsettext,,% text:=controlgettext(RisReports[1,1]),% "ahk_id " getSimpleRisEditHwnd()
,Edit_SETTEXT(getSimpleRisEditHwnd(), tmp:=text:=controlgettext(RisReports[1,1]))
,Edit_SETTEXT(getSimpleRisEditHwnds()[1], tmp:=text)
,Edit_SetSel(getSimpleRisEditHwnd(),len:=strlen(text),len)
;~ Edit_ScrollCaret(editHwnd)
Edit_ScrollCaret(getSimpleRisEditHwnd())
return

updateRisAccNo:
gosub renewRis
;~ gosub renewRisReports
;~ gosub renewAccNo
;~ thisAccNo:=controlgettext(AccNoHwnd)
;~ if(priorAccNo && thisAccNo!=priorAccNo){
	;~ controlsettext,,,% "ahk_id " getSimpleRisEditHwnd()
	;~ if(++updateAccNoCount>2)
	
		;~ gosub resetEdit
		;~ updateAccNoCount:=0
;~ }
;~ priorAccNo:=thisAccNo
return

getFocused(){
	static GuiThreadInfoSize = 48
	VarSetCapacity(GuiThreadInfo, GuiThreadInfoSize)
	NumPut(GuiThreadInfoSize, GuiThreadInfo, 0)
	DllCall("GetGUIThreadInfo", uint, 0, str, GuiThreadInfo)
	return FocusedHWND := NumGet(GuiThreadInfo, 12)  ; Retrieve the hwndFocus field from the struct.
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

;~ f::
;~ debug:=1
;~ return

;~ f`


renewRis:
RisState:=risopened()
,risAccHwnd:=getRisAccNoHwnd(RisState[2])
,cAccNo:=ControlGetText(risAccHwnd)
,RisReports:=getRisReports(RisState[2])
return


renewRisReports:
RisReports:=getRisReports(RisState[2])
,risAccHwnd:=getRisAccNoHwnd(RisState[2])
if (ControlGetText(risAccHwnd)!="")
	cAccNo:=thisAccNo:=ControlGetText(risAccHwnd)
return

activateImpax:
mousegetpos,mx,my,mWin
winget,mProcName,ProcessName,ahk_id %mWin%
if (mProcName~=MatchPacsProcessName())
	winactivate,ahk_id %mWin%
return

activateGUI:
mousegetpos,mx,my
wingetpos,x,y,w,h,% "ahk_id " getSimpleRisGuiHwnd()
if (mx>=x && mx<x+w && my>=y && my<y+h)
	winactivate,% "ahk_id " getSimpleRisGuiHwnd()
return

;~ ~esc::exitapp
/*
■Measurable:  □Left □Right □Bilateral 
*/

~WheelUp::
~WheelDown::
MouseGetPos,,,mouseWin,mouseCon,2
WinGet,pName,ProcessName,% "ahk_id " mouseWin
FocusedHWND:=GetFocusedHwnd()
;~ ToolTip % pName "," FocusedHWND "," mouseCon
if ((mouseCon=sci1.hwnd || mouseCon=sci2.hwnd || mouseCon=sci3.hwnd || mouseCon=RisReports[2,1] || mouseCon=RisReports[2,2]) && FocusedHWND!=mouseCon){
	WinActivate,% "ahk_id " mouseWin
	ControlFocus,,% "ahk_id " mouseCon
}
return

#IfWinActive,ahk_group pacs
Pause::
if(tempMove) || ((whichMonitor:=whichMonitor("","",monitors).1)=1) {
	return
}
tempMove:=true
;~ WinGetPos,xpr,ypr,,hpr,ahk_id %pr1hwnd%
;~ WinGetPos,xpr2,ypr2,,,ahk_id %pr2hwnd%
settimer,updateHx,Off
whichMonitor:=monitors[whichMonitor]
ControlGetPos,,,w,h,,% "ahk_id " sci1.hwnd
WinMove,% "ahk_id " sci1.hwnd,,% whichMonitor.l+Floor((whichMonitor.w-w)/2),% Floor((whichMonitor.h-h)/2)
WinMove,% "ahk_id " sci2.hwnd,,% whichMonitor.l+Floor((whichMonitor.w-w)/2),% Floor((whichMonitor.h-h)/2)+h
return


Pause Up::
if !(tempMove){
	send {Pause Up}
	return
}
WinGetPos,risX,risY,,,% "ahk_id " RisState[2]
ControlGetPos,x1,y1,,,,% "ahk_id " RisReports[2,1]
ControlGetPos,x2,y2,,,,% "ahk_id " RisReports[2,2]
WinMove,ahk_id %pr1hwnd%,,% risX+x1+1,% risY+y1+1
WinMove,ahk_id %pr2hwnd%,,% risX+x2+1,% risY+y2+1
settimer,updateHx,-500
tempMove:=false
return
#IfWinActive


resetEdit:
;~ SendMessage,0x2024,,,,simple RIS ahk_class AutoHotkeyGUI
return

RisStateChange(){
	global
	RisState:=risopened()
	gosub renewRisReports
}
	

accNoChanged(){
	Critical
	;~ ToolTip % "Acc changed"
	;~ ToolTip
	;~ ToolTip % A_TickCount
	global PauseUpdate, noUpdateMode, RisState, cAccNo
	;~ SendMessage,0x1122,,,,simple RIS ahk_class AutoHotkeyGUI
	;~ ToolTip % PauseUpdate "," noUpdateMode
	;~ ToolTip % "Acc changed 1"
	gosub renewRisReports
	
	thisAccNo:=getRisAccNo(RisState[2])
	if (thisAccNo="")
		return 
	if (thisAccNo=cAccNo)
		return
	
	
	if (WinExist("ahk_exe PacsIE.exe"))
		return
	if(!noUpdateMode){
		;~ ToolTip % "resetEdit on acc change"
		;~ settimer,resetEdit,-1
		;~ settimer,resetEdit,-1
		settimer,updatehxfirst,-500
		;~ postmessage,0x2020,,,,simple RIS ahk_class AutoHotkeyGUI
		;~ ToolTip % "Reset!"
		if(!PauseUpdate){
			pauseUpdateMode(2000,1)
			PauseUpdate:=true
		}
	}
}
ReportChanged(){
	Critical
	global noUpdateMode
	SendMessage,0x1123,,,,simple RIS ahk_class AutoHotkeyGUI
	;~ ToolTip % "Report Changed"
	if(!WinExist("ahk_exe PacsIE.exe"))
		noUpdateMode:=false
}
oldReportChanged(){
	;~ SendMessage,0x1124,,,,simple RIS ahk_class AutoHotkeyGUI
	 ;~ ToolTip % A_TickCount
	if WinExist("ahk_exe PacsIE.exe")
		return
	;~ ToolTip % "Old report changed"
	;~ ToolTip % updatehxfirst
	;~ if(!noUpdateMode)
		gosub updatehxfirst
	;~ else
		;~ postmessage,0x2021,,,,simple RIS ahk_class AutoHotkeyGUIhx
}

;~ ^t::
;~ sci.getText(sci.GetTextLength()+3, text:="")
;~ ToolTip % "," text ","
;~ return


;~ ^#r::
;~ Reload
;~ return

;~ ^#l::
;~ ListLines
;~ return


resetReports(){
	RisReports:=getRisReports()
	if ((text:=ControlGetText(RisReports[1,1]))!="")
		AddHistory(text), resetRisReports("", RisReports)
	;~ gosub resetEdit
}


~esc::
HideWin:
HideWin(5000)
return

HideWin(unhideAfter=5000, notCheckWinActive=false){
	global 
	if(prettyOldHxWinHidden){
		prettyOldHxWinHidden:=false
	}else{
		if(!notCheckWinActive){
			MouseGetPos,,,win
			if (win=pr1hwnd || win=pr2hwnd || win=pr3hwnd){
				prettyOldHxWinHidden:=true
				settimer,HideWin,% (-1)*unhideAfter
			}
		}else{
			prettyOldHxWinHidden:=true
			settimer,HideWin,% (-1)*unhideAfter
		}
		
			
		
	}
}

exit(){
	ExitApp
}