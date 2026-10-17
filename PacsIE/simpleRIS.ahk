#MaxHotkeysPerInterval 999999
#UseHook
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
#Include %A_ScriptDir%\..\Lib\LogRetention.ahk
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
FormatTime, simpleRisLogDate,, yyyyMMdd
global SIMPLERIS_LOG_FILE := A_ScriptDir "\simpleris_" simpleRisLogDate ".log"
global SIMPLERIS_AUTOSAVE_INTERVAL_MS := 1500
global SIMPLERIS_AUTOSAVE_DEBOUNCE_MS := 750
global SIMPLERIS_RECOVERY_STABLE_MS := 750
global SIMPLERIS_RECOVERY_RETENTION_DAYS := 31
global SIMPLERIS_RECOVERY_CLEANUP_MS := 86400000
global SIMPLERIS_DISPLAY_CHECK_MS := 2000
global SIMPLERIS_DISPLAY_SETTLE_MS := 750
LogRetention_DeleteFilesOlderThan(A_ScriptDir, "simpleris_*.log")
LogRetention_DeleteFilesOlderThan(A_ScriptDir, "simplris.log")
LogRetention_DeleteFilesOlderThan(A_ScriptDir, "simpleris.log")
;~ global __debug:=1
#include <DebugLog>
#include <Acc>
; Talk to the single CH_RIS owner (autorun) over IPC instead of creating our own
; IE-polling owner. Must be set before <risimpax> (its auto-exec calls getPlace, which honours
; this flag). simpleRIS is the report editor — its RIS edits go through the owner's GUI edit
; HWNDs (getRisReports, cross-process) and getRis*/direct CH_RIS.* via the proxy; updateText
; is event-driven (msg 0x2019 / ^b), so IPC cost is per-event, not per-keystroke. Revert =
; set this false + re-login. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
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

gui,2:Default
gui,+hwndmainHwnd
WinSetTitle,ahk_id %mainHwnd%,,simpleRIS_main

;~ gosub runSimpleRISDelegate

;~ settimer,debugHandle,1

resetHotstringBufferHook()
dwData:=17
lastClick:=0
;~ debug:=true
global thisPlace:=getPlace()

try
run % A_ScriptDir "\simpleRIS_patch.exe"

if InStr(thisPlace, "N hospital")
	try
run, % commands(A_ScriptDir "\..\AutoHotkey.exe", A_ScriptDir "\prettyOldHx.ahk"),% A_ScriptDir

if InStr(thisPlace, "N hospital")
	try
run % A_ScriptDir "\impaxOpenNext.exe"

GroupAdd,simpleRISGUI,simple RIS ahk_class AutoHotkeyGUI
guihwnds:=getSimpleRisGuiHwnds("simpleRISGUI")

args:=ParseArg()

;~ MsgBox % exploreobj(args)
;~ settimer,CancelOnTop,1000
gosub setHotkey
confirmRenew:=0
	,history:=[]
	,historySize:=100
	,historyInd:=0
	;~ ,debug:=true
	,OnMsgRegs:=[]
	,OnMsgReg(0x2021,"update")
	,OnMsgReg(0x2020,"update1")
	,OnMsgReg(0x2019,"updateText")
	,OnMsgReg(0x2022,"noUpdateMode")
	,OnMsgReg(0x2023,"pauseUpdateMode")
	,OnMsgReg(0x2024,"resetEdit")
	,OnMsgReg(0x2025,"reposition")
	,OnMsgReg(0x2026,"openStudy")
	,OnMsgReg(0x2027,"resetReports")
	,OnMsgReg(0x2028,"activateSimpleRis")
	,OnMsgReg(0x2029,"createBlack")
	,OnMsgReg(0x2030,"changeEdit")
	,OnMsgReg(0x2031,"_MButton")
	,OnMsgReg(0x2032,"focusImpressionFn")
	,OnMsgReg(0x2033,"simpleRIS_OnDisplayChange")
	,OnMsgReg(0x007E,"simpleRIS_OnDisplayChange") ; WM_DISPLAYCHANGE
	,OnMsgReg(0x1122,"accNoChanged")
	,OnMsgReg(0x1123,"ReportChanged")
	,OnMsgReg(0x1124,"oldReportChanged")
	,OnMsgReg(0x1125,"listLines")
	,OnMsgReg(0x10101,"exit")

	,thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))
DebugLogSession("simpleRIS.ahk")
	,OnMessage(0x8000, "RisStateChange")
;~ if InStr(thisPlace, "N hospital")
RISImpaxRegister([  {app: "Ris", type: "State", hwnd: thisHwnd, msg: {msg: 0x8000}, Func:"RisStateChange", initStart:1}
	, {app: "Ris", type: "OldReport", hwnd: thisHwnd, msg: {msg: 0x1124}, Func:"oldReportChanged", initStart:100}
	, {app: "Ris", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x1122}, Func:"accNoChanged", initStart:100}])
;~ MsgBox %  thisHwnd+0 "`n"
;~ OnMessage( 0x111, "focusMsg" )
mouseHooks:=[]
	,monitors:=monitorInfo()
	,simpleRIS_DisplaySignature:=simpleRIS_GetDisplaySignature()

settimer,loadRisText,-1

;~ if InStr(thisPlace, "N hospital"){
gosub renewRis
gosub renewRisReports
;~ }
gosub gui
gosub commonTitleCH
;~ renewSecondSimpleRIS()

;~ clipboard.=guihwnd+0 "`n"
;~ gosub prettyReportGui
;~ settimer,autoActivate,-500,-1
;~ settimer,updateHxLoc,-500

settimer,GrabFocus,-2000,-2
Loop, 4
{
	Gui, notify%A_Index%: -Caption +ToolWindow +AlwaysOnTOp
	Gui, notify%A_Index%: Color, white
}
;~ settimer,test,500
;~ OnMessage( 0x200, "WM_MOUSEMOVE" )

;~ settimer,ShowOntop,1
GroupAdd,pacs,ahk_exe impax-client-main.exe
GroupAdd,pacs,ahk_exe WEBVIE~1.exe
GroupAdd,pacs,ahk_exe Miv2Lib.exe
GroupAdd,pacs,ahk_exe G3PACS.exe
;~ SetTimerF("activeWin",500)
;~ settimer,test,500
;~ settimer,ToolTip,5000
settimer,EmptyMem,300000
settimer,setAltHotkey,-1
gosub MButtonHotkey
settimer,MButtonHotkey,10000
settimer,checkMiniPacsForTransparentWin,10000,-2
winset,trans,0,% "ahk_id " guihwnd
winset,trans,200,% "ahk_id " guihwnd_
;~ settimer,debug,1
settimer,setupHxDir,-1
settimer,setupReportAutosave,-5000
settimer,adjustFontSize,1000
settimer,simpleRIS_CheckDisplayLayout,% SIMPLERIS_DISPLAY_CHECK_MS
return

commonTitleCH:
	if FileExist(commontitlePath:=A_ScriptDir "\commonTitle.json")
		fileread,commonTitles,% commontitlePath
	commonTitles:=jxon_load(commonTitles)
	commonTitleCH:=commonTitles["C hospital"]
return

OnMsgReg(msg, fn){
	global OnMsgRegs
	OnMsgRegs[msg]:=Func(fn)
	OnMessage(msg, "redirectOnMsg")
}
redirectOnMsg(w,l,m,h){
	global OnMsgRegs
	static lastRecv:=[]

	if(lastRecv[m] && A_TickCount-lastRecv[m]<200)
		return
	lastRecv[m]:=A_TickCount

	if(fn:=OnMsgRegs[m])
		;~ settimerF(fn, -1, [w,l,m,h])
		fn.call(w,l,m,h)
}

GetCHRisGuiText(controlNN, accNo:=""){
	DetectHiddenWindows,on
	WinGet, chRisGuiList, List, CH_RIS_GUI ahk_class AutoHotkeyGUI
	fallbackText:=""
	Loop % chRisGuiList {
		thisHwnd:=chRisGuiList%A_Index%
		ControlGetText, thisText, %controlNN%, % "ahk_id " thisHwnd
		thisText:=Trim(thisText)
		if (thisText="") {
			continue
		}
		if (fallbackText="")
			fallbackText:=thisText
		if (accNo!="") {
			ControlGetText, thisAccNo, Edit4, % "ahk_id " thisHwnd
			if (Trim(thisAccNo)=accNo)
				return thisText
		}
	}
	return fallbackText
}

CHIsXRayStudy(){
	global __is_CH, CH_RIS
	if !__is_CH
		return false
	examname := ""
	try examname := CH_RIS.examname
	if (examname = "")
		return false
	try {
		examType := CH_RIS.parse_exam_type(examname)
		return (examType = "X-Ray")
	} catch {
		return false
	}
}

debug:
	If h:=WinExist("Handle is NULL","buffer")
		ListLines,On
return

runSimpleRISDelegate:
	scriptName:=RegExReplace(A_ScriptName, ".\w+$", ".exe")
	cmd=
(
SETLOCAL EnableExtensions
set EXE=%scriptname%
:loop
@ping 127.0.0.1 -n 2 -w 1000 > nul
FOR /F `%`%x IN ('tasklist /NH /FI "IMAGENAME eq `%EXE`%"') DO IF `%`%x == `%EXE`% goto loop
start "" /wait "`%EXE`%"
goto loop
)
	;~ FileDelete,simpleRISDelegate.cmd
	if !FileExist("simpleRISDelegate.cmd")
		FileAppend,% cmd,simpleRISDelegate.cmd,cp0
	found:=false
	for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name = 'cmd.exe' and CommandLine like '%simpleRISDelegate.cmd%' ")
		found:=true
	if !found
		run,simpleRISDelegate.cmd,% A_ScriptDir,Hide,simpleRisDelegatePid
;~ winwait,% "ahk_pid " simpleRisDelegatePid,,3
;~ FileDelete,simpleRISDelegate.cmd
return

setAltHotkey:
	Hotkey,ifwinactive,ahk_group simpleRISGUI
	Loop 26 {
		Hotkey, % "!" Chr(A_Index+97), AltHotkey
		Hotkey, % "+!" Chr(A_Index+97), AltHotkey
	}
	Hotkey,ifwinactive
return

AltHotkey:
	AltHotkey(A_ThisHotkey)
return

AltHotkey(thisHotkey){
	global sci
	RegExMatch(thishotkey, "\w", thisHotkeyAlphabet)
		,toLeft:=!!InStr(thisHotkey, "+")
		,text:=SCI_GETTEXT(sci)

	if (m:=RegExMatch(text, reg:="im)^([^\w\(] *|\W?\d+\W *)" thisHotkeyAlphabet "[^\r\n]*", match, s:=new RemoteScintilla(sci.hwnd)._GetCurrentPos() +1)) || (m:=RegExMatch(text, reg, match)) {

		if !(toLeft){
			s:=m+StrLen(match)-1
			if RegExMatch(SubStr(text,s), "(\r?\n +-+ *[^\r\n]*)+", match2)
				s+=StrLen(match2)
		}else{
			s:=m
			if RegExMatch(SubStr(text,s), "(\r?\n +-+ *[^\r\n]*)*(\r?\n +-+ *)", match2)
				s+=StrLen(match2)
		}

		return Edit_Setsel(sci.hwnd, s, s), Edit_ScrollCaret(sci.hwnd),resetHotstringBuffer(-1)
	}

}

SimpleRIS_ExtendSpineLevel(direction){
	global editHwnd, editHwnd_
	focusedHwnd:=GetFocusedHwnd()
	if (focusedHwnd!=editHwnd && focusedHwnd!=editHwnd_) {
		SimpleRIS_SendCtrlUpDown(direction)
		return
	}

	text:=Edit_GetText(focusedHwnd)
	Edit_GetSel(focusedHwnd, selStart, selEnd)
	caretPos:=selEnd
	caretIndex:=caretPos+1
	prefix:=SubStr(text, 1, caretPos)
	lastLf:=InStr(prefix, "`n", false, 0)
	lineStartIndex:=lastLf ? lastLf+1 : 1
	nextLf:=InStr(text, "`n", false, caretIndex)
	lineEndIndex:=nextLf ? nextLf : StrLen(text)+1
	lineText:=SubStr(text, lineStartIndex, lineEndIndex-lineStartIndex)
	lineBody:=RegExReplace(lineText, "\r$", "")
	caretInLine:=caretPos-(lineStartIndex-1)+1

	level:=SimpleRIS_FindSpineLevelInLine(lineBody, caretInLine)
	if !IsObject(level) {
		SimpleRIS_SendCtrlUpDown(direction)
		return
	}

	if (direction="up")
		newStartIdx:=level.startIdx-1, newEndIdx:=level.endIdx
	else
		newStartIdx:=level.startIdx, newEndIdx:=level.endIdx+1

	if (newStartIdx<1 || newEndIdx>28 || newStartIdx>newEndIdx) {
		SimpleRIS_SendCtrlUpDown(direction)
		return
	}

	newLevel:=SimpleRIS_FormatSpineLevelRange(newStartIdx, newEndIdx, level.endSegment, level.endSegmentExplicit)
	if (newLevel="") {
		SimpleRIS_SendCtrlUpDown(direction)
		return
	}

	replaceStart:=lineStartIndex+level.pos-1
	newText:=SubStr(text, 1, replaceStart-1) newLevel SubStr(text, replaceStart+level.len)
	Edit_SetText(focusedHwnd, newText)
	newCaret:=replaceStart-1+StrLen(newLevel)
	Edit_SetSel(focusedHwnd, newCaret, newCaret)
	Edit_ScrollCaret(focusedHwnd)
}

SimpleRIS_SendCtrlUpDown(direction){
	if (direction="up")
		SendInput, ^{Up}
	else
		SendInput, ^{Down}
}

SimpleRIS_FindSpineLevelInLine(lineText, caretInLine){
	spineRegex:="Oi)\b([CTLS])\s*([1-9][0-2]?)(?:\s*-\s*([CTLS])?\s*([1-9][0-2]?))?(?![A-Z0-9])"
	searchPos:=1
	best:=""
	bestDistance:=""
	while (foundPos:=RegExMatch(lineText, spineRegex, match, searchPos)) {
		startSegment:=match.Value(1)
		startNum:=match.Value(2)+0
		endSegment:=match.Value(3)
		endNum:=match.Value(4)
		endSegmentExplicit:=endSegment!=""
		StringUpper, startSegment, startSegment
		StringUpper, endSegment, endSegment

		if (endNum="")
			endSegment:=startSegment, endNum:=startNum, endSegmentExplicit:=false
		else if (endSegment="")
			endSegment:=SimpleRIS_InferImplicitSpineEndSegment(startSegment, startNum, endNum+0)

		startIdx:=SimpleRIS_SpineLevelIndex(startSegment, startNum)
		endIdx:=SimpleRIS_SpineLevelIndex(endSegment, endNum+0)
		if (startIdx!="" && endIdx!="" && startIdx<=endIdx) {
			matchStart:=match.Pos(0)
			matchEnd:=matchStart+match.Len(0)-1
			if (caretInLine<matchStart)
				distance:=matchStart-caretInLine
			else if (caretInLine>matchEnd)
				distance:=caretInLine-matchEnd
			else
				distance:=0
			if (!IsObject(best) || distance<bestDistance) {
				best:={pos:matchStart, len:match.Len(0), startIdx:startIdx, endIdx:endIdx, endSegment:endSegment, endSegmentExplicit:endSegmentExplicit}
				bestDistance:=distance
			}
		}
		searchPos:=foundPos+match.Len(0)
	}
	return best
}

SimpleRIS_InferImplicitSpineEndSegment(startSegment, startNum, endNum){
	if (endNum>=startNum)
		return startSegment
	return SimpleRIS_NextSpineSegment(startSegment)
}

SimpleRIS_NextSpineSegment(segment){
	StringUpper, segment, segment
	if (segment="C")
		return "T"
	if (segment="T")
		return "L"
	if (segment="L")
		return "S"
	return ""
}

SimpleRIS_SpineLevelIndex(segment, num){
	StringUpper, segment, segment
	num+=0
	if (segment="C" && num>=1 && num<=7)
		return num
	if (segment="T" && num>=1 && num<=12)
		return 7+num
	if (segment="L" && num>=1 && num<=5)
		return 19+num
	if (segment="S" && num>=1 && num<=4)
		return 24+num
	return ""
}

SimpleRIS_SpineIndexLevel(index){
	if (index>=1 && index<=7)
		return {segment:"C", num:index}
	if (index>=8 && index<=19)
		return {segment:"T", num:index-7}
	if (index>=20 && index<=24)
		return {segment:"L", num:index-19}
	if (index>=25 && index<=28)
		return {segment:"S", num:index-24}
	return ""
}

SimpleRIS_FormatSpineLevelRange(startIdx, endIdx, originalEndSegment, originalEndSegmentExplicit){
	startLevel:=SimpleRIS_SpineIndexLevel(startIdx)
	endLevel:=SimpleRIS_SpineIndexLevel(endIdx)
	if !(IsObject(startLevel) && IsObject(endLevel))
		return ""
	if (startIdx=endIdx)
		return startLevel.segment startLevel.num
	endSegmentExplicit:=originalEndSegmentExplicit || (endLevel.segment!=originalEndSegment)
	return startLevel.segment startLevel.num "-" (endSegmentExplicit ? endLevel.segment : "") endLevel.num
}

test(){
	winget,id,id,A
	ControlGetFocus,c,ahk_id %id%
	ToolTip % id "," c
}

EmptyMem:
	EmptyMem(thisPid)
return

openStudy(wParam, lParam, msg, hwnd){
	;~ ToolTip % "OpenStudy"
	global debug
	if debug
		ToolTip % A_ThisFunc
	settimer,openStudy,-1
}

activeWin(){
	static lastActiveWin
	global guihwnd, guihwnd_
	thisActiveWin:=WinExist("A")
	if(lastActiveWin=thisActiveWin && (lastActiveWin:=thisActiveWin))
		return

	if(thisActiveWin=guihwnd) || (thisActiveWin=guihwnd_)
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

update1(){
	global debug, updating
	if debug
		ToolTip % A_ThisFunc
	updating:=false
	gosub update1
}

GrabFocus:
	if __is_CH
	{
		;~ if WinActive("CH_RIS_GUI ahk_class AutoHotkeyGUI ahk_pid " thisPid){
		;~ gosub activateSimpleRis
		;~ }
		return
	}

	focused:=GetFocusedHwnd()
		,changeFocus:=false
	if (focused=RisReports[1,1]){

		edit_getsel(RisReports[1,1],pCaretS,pCaretE)
		send {tab}

		ControlFocus,,% "ahk_id " risreports[1,2]
		WinShow,% "ahk_id " guihwnd
		winactivate,% "ahk_id " guihwnd
		;~ controlfocus,,% "ahk_id " editHwnd
		guihwnd_:=getSimpleRisGuiHwnds()[2]
		editHwnd_:=getSimpleRisEditHwnds()[2]
		WinShow,% "ahk_id " guihwnd_
		winactivate,% "ahk_id " guihwnd_
		controlfocus,,% "ahk_id " editHwnd_

		changeFocus:=true

	}else if(focused=guihwnd){
		activateOverlaySimpleRis()

		changeFocus:=true
	}

	if(changeFocus){

		if !WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
			&& !WinExist("feedRIS_main ahk_class AutoHotkeyGUI")
			&& !WinExist("autoFeed_main ahk_class AutoHotkeyGUI"){
			gosub update1
			Edit_Setsel(sci.hwnd, pCaretS,pCaretE)
				,Edit_ScrollCaret(editHwnd)
				,sci.ScrollCaret()
				,Edit_SetSel(editHwnd_, pCaretS,pCaretE)
				,sci_.ScrollCaret()

		}else{
			Edit_Setsel(sci.hwnd, -1, -1)
				,Edit_ScrollCaret(editHwnd)
				,sci.ScrollCaret()
				;~ ,Edit_Setsel(editHwnd_, pCaretS,pCaretE)
				,Edit_Setsel(editHwnd_, -1, -1)
				,sci_.ScrollCaret()
		}

		newX:=a_caretx,newY:=A_CaretY+6,frame:=400
		settimer,show,-1
	}
	settimer,GrabFocus,% WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")?-400:-2000,% WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")?2:-2
return

;~ setActivateHK:
;~ hotkey,capslock up,activateSimpleRis,on
;~ return

setHotkey:
	if fileexist(iniFile:=a_scriptdir "/simpleRIS.ini") {

	}else if fileexist(iniFile:=a_scriptdir "/RisHelper.ini"){

	}

	IniRead,initAtCenter,% iniFile,Setting,initAtCenter,1
	IniRead,ifShowLinebreak,% iniFile,Setting,顯示斷行符號,0
	IniRead,simpleRisCompensateDpiScale,% iniFile,Setting,compensateWindowsScale,1

	iniread,focusImpressionKey,% iniFile,Hotkey,focusImpression,#space
	iniread,updateTextKey,% iniFile,Hotkey,updateText,^b
	iniread,resetTextKey,% iniFile,Hotkey,resetText,^n
	iniread,addNextLine,% iniFile,Hotkey,addNextLine,^o
	iniread,toggleHideCHWebRis,% iniFile,Hotkey,toggleHideCHWebRis,^h

	try{
		hotkey,ifwinactive,ahk_group MyGui
		hotkey,% focusImpressionKey,focusImpression
		hotkey,% updateTextKey,updateText
		hotkey,% resetTextKey,resetText
		hotkey,% addNextLine,addNextLine
		if __is_CH
			hotkey,% toggleHideCHWebRis,toggleHideCHWebRis

		hotkey,ifwinactive
	}

	if winexist("ahk_exe autorun.exe") || winexist("ahk_exe PacsIE.exe") || WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
		return

	;~ settimer,setActivateHK,5000
	settimer,setcapslockstate,500
	hotkey,% "#Capslock",toggleCapslockState

	iniread,sendReportKey,% iniFile,Hotkey,發送,F3
	iniread,saveReportKey,% iniFile,Hotkey,存檔,F2
	iniread,tempReportKey,% iniFile,Hotkey,暫存,F1

	try{
		hotkey,ifwinactive,ahk_group simpleRISGUI
		hotkey,% sendReportKey,sendReport
		hotkey,% saveReportKey,sendReport
		hotkey,% tempReportKey,sendReport
		hotkey,ifwinactive

		;~ hotkey,% "~" sendReportKey,changeStudyKey
		;~ hotkey,% "~" saveReportKey,changeStudyKey
		;~ hotkey,% "~" tempReportKey,changeStudyKey

		;~ hotkey,% "~+" sendReportKey,changeStudyKey
		;~ hotkey,% "~+" saveReportKey,changeStudyKey
		;~ hotkey,% "~+" tempReportKey,changeStudyKey

		hotkey,ifwinactive,ahk_group MyGui
		hotkey,% "~" sendReportKey,reportStudy
		hotkey,% "~" saveReportKey,reportStudy
		hotkey,% "~" tempReportKey,reportStudy

		hotkey,% "~+" sendReportKey,reportStudy
		hotkey,% "~+" saveReportKey,reportStudy
		hotkey,% "~+" tempReportKey,reportStudy
		Hotkey,IfWinActive
	}

return

toggleHideCHWebRis:
	if (toggleHideCTHWebRisStatus:=!toggleHideCTHWebRisStatus){
		CH_RIS.HideWb()
	}else{
		CH_RIS.showWB()
	}
return

#IfWinNotActive,ahk_group simpleRISGUI
	~Space::
		if !GetKeyState("LButton")
			return
		KeyWait,LButton,T1
	^!+Space::
		goto activateSimpleRis
	return

	~LButton::
		if (A_PriorHotkey=A_ThisHotkey && A_TimeSincePriorHotkey<400){
			MouseGetPos,mx,my
			if (mx<10)
				goto activateSimpleRis
		}

	return
	#esc::
		gosub activateSimpleRis
	return
#IfWinNotActive

#IfWinActive,ahk_group simpleRISGUI
	$^Up::
		SimpleRIS_ExtendSpineLevel("up")
	return
	$^Down::
		SimpleRIS_ExtendSpineLevel("down")
	return

	$Left::
	LeftHotkeyLogic:
		if (__is_CH && GetFocusedHwnd() == EditHwnd && SCI_GETTEXT(sci) == "") {
			GuiControlGet, thisAccNoText,%guihwnd%:,thisAccNoText
			examname:=GetCHRisGuiText("Edit7", thisAccNoText)
			if (examname != "") {
				SCI_SETTEXT(sci, examname)
				sci.gotopos(StrLen(examname))
				; Fall through to check for commonTitle mapping
			} else {
				ToolTip, Unable to retrieve study info from CH_RIS_GUI
				SetTimer, tooltip, -3000
			}
		}

		if (__is_CH && !WinExist("YCH_XR_main ahk_class AutoHotkeyGUI") && GetFocusedHwnd()=EditHwnd && Edit_GetCurrentLineCount(EditHwnd)=0){
			currentLine := trim(Edit_GetLine(editHwnd))
			commonTitle := commonTitleCH[currentLine]
			if (commonTitle!="") {
				KeyWait,Left,t0.4
				gosub resetEdit
				if InStr(commonTitle, "\\"){
					oldSendLevel:=a_sendlevel
					SendLevel,2
					send % RegExReplace(commonTitle, "^\\\\")
					SendLevel,% oldSendLevel
				}else
					Edit_SetText(editHwnd, t:=t_:=commonTitle "`r`n- ")
						,Edit_Setsel(editHwnd, s:=StrLen(t_), s)
			}else{
				if (SCI_GETTEXT(sci)!="")
					send {End}{Enter}
				else
					send {Left}
			}
		}else{
			send {Left}
		}
	return

;~ capslock up::
;~ if A_TickCount-notactivecapslockpressed<500
;~ return
;~ if WinActive("ahk_id " getSimpleRisGuiHwnds()[1])
;~ goto capslockHotkey
;~ if !WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
;~ gosub activatePrior
;~ return
#IfWinActive

sendReport:
	if WinExist("WM_COPYDATA_Listener_miniPACS")
		return
	;~ RisState:=RisOpened()
	if(a_thishotkey=sendReportKey){
		;~ getNetAcc(RisState[2],"cmdRunVerifySend","WindowsForms10.BUTTON.app").accDoDefaultAction()
		if WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
			PostMessage,0x10203,,,,miniPACS_bridge ahk_class AutoHotkeyGUI
		else
			risSendReport(RisState[2], 3)
	}else if(a_thishotkey=saveReportKey){
		if WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
			PostMessage,0x10203,,,,miniPACS_bridge ahk_class AutoHotkeyGUI
		else
			risSendReport(RisState[2], 2)
	}else if(a_thishotkey=tempReportKey)
		;~ getNetAcc(RisState[2],"cmdRunSave","WindowsForms10.BUTTON.app").accDoDefaultAction()
		risSendReport(RisState[2], 1)
	pauseUpdateMode(2000,1)
return

setcapslockstate:
SetCapslockstate,% capslockstate?"on":"off"
return

toggleCapslockState:
	capslockstate:=!capslockstate
	gosub setcapslockstate
return

activatePrior:
	gosub CancelOnTop
	if WinExist("ahk_id " priorActiveWin) && priorActiveWin!=guihwnd && priorActiveWin!=guihwnd_
		winactivate,% "ahk_id " priorActiveWin
	else{
		MouseGetPos,,,win
		if (win=guihwnd) || (win=guihwnd_)
			winactivate,% "ahk_id " priorActiveWin:=impaxOpened()[2,1]
		else
			winactivate,% "ahk_id " priorActiveWin:=win
	}
return

testactive:
	if WinActive("CH_RIS_GUI")
		aaa++
return

;~ ^t::
activateSimpleRis:
	;~ simpleRis:=winexist("ahk_group simpleRISGUI")
	;~ if WinActive("ahk_id " guihwnd) && (editHwnd=GetFocusedHwnd())
	;~ return
	;~ if !WinActive("ahk_id " guihwnd)
	;~ resetHotstringBuffer(-1)
	;~ settimer,testactive,1

	if (__win11__)
		winactivate,cv2pacs:

	guihwnd_:=getSimpleRisGuiHwnds()[2]
		,editHwnd_:=getSimpleRisEditHwnds()[2]
	WinShow,ahk_id %guihwnd_%
	gosub checkMiniPacsForTransparentWin
	if WinActive("ahk_id " guihwnd_){
		ControlFocus,,ahk_id %editHwnd_%
		;~ return
	}else{
		winactivate,ahk_id %guihwnd_%
		ControlFocus,,ahk_id %editHwnd_%
		if WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
			return
	}
	priorActiveWin:=WinExist("A")
	;~ w:=WinExist("A")
	;~ h:=getFocusedHwnd()
	;~ ToolTip % WinGet("ProcessName", w) "`n" WinGetTitle(w) "`n" WinGetClass(w) "`n`n" WinGetClass(h)
	;~ PostMessage,0x2023,,,,RazerNaga_main ahk_class AutoHotkeyGUI
	;~ activateOverlaySimpleRis()
	;~ WinMove,ahk_id %guihwnd%,,% guiPos.x,% guiPos.y,% guiPos.w,% guiPos.h
	gosub setontop
;~ settimer,CancelOnTop,-1000

;~ if (bridge:=WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI"))
;~ SendMessage,0x10202,,,,ahk_id %bridge%
return

setontop:
	winset,AlwaysOnTop,On,ahk_id %guihwnd_%
	;~ if !WinExist("WM_COPYDATA_Listener_miniPACS")
	;~ winset,AlwaysOnTop,Off,ahk_id %guihwnd%
	;~ else
	settimer,CancelOnTop,-500
return

if(A_TickCount-setontoptick)<500
	goto setontopreturn
setontopinstant:
return
;~ simpleRis:=winexist("ahk_group simpleRISGUI")
IfWinNotActive,ahk_group pacs
	DllCall("SetWindowPos", "Ptr", guihwnd_, "Ptr", 0, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
		,DllCall("SetWindowPos", "Ptr", guihwnd_, "Ptr", -1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
else
	DllCall("SetWindowPos", "Ptr", guihwnd_, "Ptr", -2, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)

;~ ,DllCall("SetWindowPos", "Ptr", impaxOpened()[2,1], "Ptr", guihwnd, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
;~ settimer,setNotOnTop,-1000

setontopreturn:
	setontoptick:=A_TickCount
	settimer,CancelOnTop,-5000
return

CancelOnTop:
	winset,AlwaysOnTop,Off,ahk_id %guihwnd_%
return
setNotOnTop:
	;~ simpleRis:=winexist("ahk_group simpleRISGUI")
	winset,AlwaysOnTop,Off,ahk_id %guihwnd_%
	;~ gui,1:Hide
	DllCall("SetWindowPos", "Ptr", guihwnd_, "Ptr", 1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)

	;~ winactivate,ahk_id %activeWIn%
	WinInsertAfter(guihwnd_, WinExist("A"))
	;~ WinHide,% "ahk_id " guihwnd
	gui,1:Hide
	gui,1:show,NoActivate,simple RIS
;~ gui,1:show,NoActivate
return

setFocus:
	guicontrolget,guifocused,focus
	if !instr(guifocused,"scintilla")
		guicontrol,focus,scintilla1
return

reposition(wParam, lParam, msg, hwnd){
	global
	if debug
		ToolTip % A_ThisFunc
	initAtCenter:=wParam
	gosub calWidthHeight

	guihwnds:=getSimpleRisGuiHwnds()
		,guihwnd_:=guihwnds[2]
	DetectHiddenWindows,on
	WinHide,ahk_id %guihwnd%
	WinMove,ahk_id %guihwnd%,,% guiPos.x,% guiPos.y,% guiPos.w,% guiPos.h
	;~ WinGetPos,x,y,w,h,ahk_id %guihwnd%
	;~ MsgBox % x "," y "," w "," h
	PostMessage,0x1126,,,,simpleRIS__main ahk_class AutoHotkeyGUI
	PostMessage,0x2030,1,,,simpleRIS__main ahk_class AutoHotkeyGUI
	;~ WinMove,ahk_id %guihwnd_%,,% guiPos.x,% guiPos.y,% guiPos.w,% guiPos.h
	;~ ToolTip % guiPos.x "," guiPos.y "," guiPos.w "," guiPos.h
}

simpleRIS_OnDisplayChange(wParam:=0, lParam:=0, msg:=0, hwnd:=0){
	global SIMPLERIS_DISPLAY_SETTLE_MS
	; RDP reconnects can report several intermediate display configurations. Restarting
	; this one-shot timer lets Windows finish rebuilding the monitor topology first.
	SetTimer, simpleRIS_RefreshDisplayLayout, Off
	SetTimer, simpleRIS_RefreshDisplayLayout, % -SIMPLERIS_DISPLAY_SETTLE_MS
}

simpleRIS_GetDisplaySignature(){
	SysGet, monitorCount, MonitorCount
	signature:=monitorCount
	Loop % monitorCount {
		SysGet, mon, Monitor, % A_Index
		dpi:=Round(simpleRIS_GetDpiScale((monLeft+monRight)//2, (monTop+monBottom)//2)*96)
		signature.="|" monLeft "," monTop "," monRight "," monBottom "," dpi
	}
	return signature
}

simpleRIS_ApplyDisplayLayout(){
	global monitors, guiPos, guihwnd, sci, simpleRIS_EditorPad, initAtCenter
		, simpleRIS_DisplaySignature

	newMonitors:=monitorInfo()
	if (!IsObject(newMonitors) || !newMonitors.MaxIndex())
		return false

	monitors:=newMonitors
	gosub calWidthHeight
	simpleRIS_DisplaySignature:=simpleRIS_GetDisplaySignature()

	if (!guihwnd || !WinExist("ahk_id " guihwnd))
		return false

	WinMove, ahk_id %guihwnd%,, % guiPos.x, % guiPos.y, % guiPos.w, % guiPos.h
	WinGetPos, guiX, guiY, guiW, guiH, ahk_id %guihwnd%
	if (IsObject(sci) && sci.hwnd) {
		editorW:=guiW-simpleRIS_EditorPad*2
		editorH:=guiH-simpleRIS_EditorPad*2
		ControlMove,, % simpleRIS_EditorPad, % simpleRIS_EditorPad, % editorW, % editorH, % "ahk_id " sci.hwnd
		simpleRIS_UpdateEditorFontSize()
	}
	SimpleRIS_UpdateActiveRim()
	PostMessage, 0x1126,,,, simpleRIS__main ahk_class AutoHotkeyGUI
	return true
}

simpleRIS_UpdateEditorFontSize(){
	global sci, Fontsize
	if (!IsObject(sci) || !sci.hwnd)
		return
	Fontsize:=simpleRIS_CalculateMainFontSize()
	sci.StyleSetSize(SCLEX_CONTAINER, Fontsize)
	sci.StyleSetSize(STYLE_DEFAULT, Fontsize)
	sci.StyleSetSize(SCE_AHKL_USERDEFINED1, Fontsize-1)
}

simpleRIS_CalculateMainFontSize(){
	global guiPos
	fontSize:=Round((guiPos.w+70.4)/68.4)
	if (fontSize<14)
		fontSize:=14
	else if (fontSize>24)
		fontSize:=24
	return simpleRIS_AdjustFontSizeForDpi(fontSize)
}

simpleRIS_CheckDisplayLayout:
	if (simpleRIS_GetDisplaySignature()!=simpleRIS_DisplaySignature)
		simpleRIS_OnDisplayChange()
return

simpleRIS_RefreshDisplayLayout:
	simpleRIS_ApplyDisplayLayout()
return

noUpdateMode(wParam="", lParam="", msg="", hwnd=0, reactivation=-10000){
	global noUpdateMode:=lParam, debug
	if debug
		ToolTip % A_ThisFunc
	PostMessage,% msg,% wparam,% lparam,,prettyOldHx ahk_class AutoHotkeyGUI

	if(lParam){
		if (wParam+0)>0
			reactivation:=(-1)*(wParam+0)
		settimer,ReactivateUpdateMode,% Abs(reactivation)*(-1)

	}else{
		settimer,ReactivateUpdateMode,-1
	}
}

pauseUpdateMode(wParam="", lParam="", msg="", hwnd=0, reactivation=-10000){
	global PauseUpdate:=lParam, debug
	if debug
		ToolTip % A_ThisFunc
	PostMessage,% msg,% wparam,% lparam,,prettyOldHx ahk_class AutoHotkeyGUI
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
	settimer,update1,-1
;~ settimer,updatehxfirst,-1
return

#ifwinactive,ahk_group simpleRISGUI

	;~ ~#c::
	;~ PostMessage,0x10102,,,,YCH_AHK_main ahk_class AutoHotkeyGUI
	;~ return
	;~ ~#z::
	;~ PostMessage,0x10103,,,,YCH_AHK_main ahk_class AutoHotkeyGUI
	;~ return

	F9::
	F10::
		insertBefore:=(a_thishotkey="F9")?1:0
		sBeforeSearch:=sci.getAnchor(),eBeforeSearch:=sci.getcurrentpos()
		wingetpos,x,y,w,h,ahk_id %guihwnd_%
		inputbox,searchWord,Jump...,% insertBefore?"before":"after",,300,200,% x+w/2-150,% y-200
		if(searchWord="")
			return
		;~ sci.gettext(sci.GetTextLength()+3,text:="")
		text:=SCI_GETTEXT(sci)
		searchResult:=searchText(searchWord, text)
		if(!searchResult.maxIndex())
			return
		resultInd:=findClosedResult(searchResult, searchWordLen:=strlen(searchWord), sBeforeSearch, eBeforeSearch)
		if(resultInd="")
			return
		Edit_SetSel(sci.hwnd,searchedPos:=(insertBefore?searchResult[resultInd]:searchResult[resultInd]+searchWordLen)-1, searchedPos)
		newX:=a_caretx,newY:=A_CaretY+6,frame:=400
		settimer,show,-1
	return

	F7::
	F8::
		if((searchResultCount:=searchResult.maxindex())<2)
			return
		if(a_thishotkey="F7"){
			resultInd:=mod(resultInd-2+searchResultCount,searchResultCount)+1
		}else{
			resultInd:=mod(resultInd,searchResultCount)+1
		}
		Edit_SetSel(sci.hwnd,searchedPos:=(insertBefore?searchResult[resultInd]:searchResult[resultInd]+searchWordLen)-1, searchedPos)
		newX:=a_caretx,newY:=A_CaretY+6,frame:=400
		settimer,show,-1
	return

#IfWinActive

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
	if(win=RisState[2]){
		settimer,updatehxfirst,-1
		if ((t:=ControlGetText(con)) ~= "存檔|暫存")
			gosub reportStudy
		else if (t ~= "存檔|暫存|下筆|上筆")
			gosub changeStudy

	}
	else if (win=pr1hwnd || win=pr2hwnd){
		if (A_TickCount-lastClick<500){
			gosub copyOldReport
		}
		lastClick:=A_TickCount

	}
	resetHotstringBuffer(-1)
return

~LButton up::
return

;~ t::ListLines

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
		controlsettext,,% RegExReplace(controlgettext(risreports[1,2]) controlgettext(risReports[2,2]), "\r?\n", "`r`n"),% "ahk_id " risReports[1,2]
		;~ controlsettext,,% text:=controlgettext(risreports[1,1]) controlgettext(risReports[2,1]),% "ahk_id " editHwnd
		;~ sci.Notify:=""
		SCI_SETTEXT(sci, tmp:=text:=controlgettext(risreports[1,1]) controlgettext(risReports[2,1]))
		;~ ,sci.Notify:="Notify"
		controlsettext,,% RegExReplace(text, "\r?\n", "`r`n"),% "ahk_id " risReports[1,1]
		gosub activateSimpleRis
	}else if(win=pr2hwnd){
		controlsettext,,% RegExReplace(controlgettext(risreports[1,2]) controlgettext(risReports[2,2]), "\r?\n", "`r`n"),% "ahk_id " risReports[1,2]
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
	PostMessage,0x2021,,,,prettyOldHx ahk_class AutoHotkeyGUI
return

TrimClipboard:
	clipboard:=trim(clipboard)
return

prettyReportGui:
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

updateHxLoc:
	settimerF("updateHxLoc",-1,[],1)
return
;~ return
;~ ToolTip % A_TickCount ": updateLoc"

hxGuiHidden(){
	global
	Loop 3
		try
	gui,% pr%a_index%hwnd ":hide"
	hxGuiHidden:=true
}

updateHxLoc(){
	;~ return
	global noUpdateMode,hxGuiHidden,RisState,oldReportHwnd,RisReports,pr1hwnd,pr2hwnd,pr3hwnd,sci1,sci2,sci3,thisPid

	if GetKeyState("LButton") || GetKeyState("Shift") || GetKeyState("Alt"){
		settimer,updateHxLoc,-500,1
		return
	}

	;~ Thread,Priority,1
	if (noUpdateMode){
		hxGuiHidden()
		;~ winhide,ahk_id %pr2hwnd%
		;~ goto updateHxEnd
		settimer,updateHxLoc,-1000,1
		return
	}

	;~ RisReports:=getRisReports(RisState[2])
	wingetpos,risX,risY,,,% "ahk_id " RisState[2]
	controlgetpos,x1,y1,w1,h1,,% "ahk_id " oldReportHwnd:=risreports[2,1]
	if !controlvisible(oldReportHwnd){
		hxGuiHidden()
		return
	}
	coordHwnd:=wingetatcoords(risX+x1,risY+y1,"ID")

	if (coordHwnd!=RisState[2]){
		hxGuiHidden()
		return
	}

	controlgetpos,x2,y2,w2,h2,,% "ahk_id " risreports[2,2]
	controlgetpos,x3,y3,w3,h3,,% "ahk_id " getRisClinicalInfoHwnd(RisState[2])

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
		settimer,updateHxLoc,-1000,1
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
		else{
			gui,% pr%a_index%hwnd ":show",% "NoActivate x" risX+x%a_index%+1 " y" risY+y%a_index%+1 " w" w%a_index% " h" h%a_index%
			ControlMove,,,,% w%a_index%,% h%a_index%,% "ahk_id " sci%a_index%.hwnd
			settimer,updatehxfirst,-500
			hxGuiHidden:=false
			settimer,updateHxLoc,-1000,1
			settimer,pastHxGUIOnTop,-500
		}

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
	}

	settimer,updateHxLoc,-500,1
	return
}

updateHx:
	;~ Thread,Priority,-1
	if (noUpdateMode){
		Loop 3
			gui,pr%a_index%:hide
		;~ winhide,ahk_id %pr2hwnd%
		hxGuiHidden:=true
		return
	}
	if (PauseUpdate)
		return
;~ runTimeBP(1)
;~ gosub renewRis
;~ gosub renewRisReports
updatehxfirst:
	PostMessage,0x2020,,,,prettyOldHx ahk_class AutoHotkeyGUI
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
		;~ winset,AlwaysOnTop,Off,ahk_group simpleRISGUI

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
				Fontsize:=simpleRIS_CalculateMainFontSize()
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

			editorBack:=0x11161C
				,editorFore:=0xE8EDF2
				,editorAccent:=0x65D4FF
				,editorSelectionBack:=0x245A78
				,editorCaretLineBack:=0x18202A
				,editorFont:="Consolas"

			sci.SETSELALPHA(155)
				,sci.SetSelBack(1, editorSelectionBack)
				,sci.SetSelFore(1, 0xFFFFFF)
				,sci.SetCaretLineVisible(main)
				,sci.SetCaretLineBack(editorCaretLineBack)
				,sci.SetCaretLineBackAlpha(70)
				,sci.SetMarginLeft(0, 10)
				,sci.SetMarginRight(0, 10)
				,sci.SetHScrollBar(false)
				,sci.SetVScrollBar(true)

			;~ sci.StyleSetBack(32, 0x000000)
			sci.StyleSetFore(SCLEX_CONTAINER, editorFore), sci.StyleSetBack(SCLEX_CONTAINER, editorBack), sci.StyleSetBold(SCLEX_CONTAINER, false), sci.StyleSetFont(SCLEX_CONTAINER, editorFont), sci.StyleSetSize(SCLEX_CONTAINER, Fontsize)
				,sci.StyleSetFore(STYLE_DEFAULT, editorFore), sci.StyleSetBack(STYLE_DEFAULT, editorBack), sci.StyleSetBold(STYLE_DEFAULT, false), sci.StyleSetFont(STYLE_DEFAULT, editorFont), sci.StyleSetSize(STYLE_DEFAULT, Fontsize)
				,sci.StyleSetFore(SCE_AHKL_USERDEFINED1, editorAccent), sci.StyleSetBack(SCE_AHKL_USERDEFINED1, editorBack), sci.StyleSetBold(SCE_AHKL_USERDEFINED1, true), sci.StyleSetFont(SCE_AHKL_USERDEFINED1, editorFont), sci.StyleSetSize(SCE_AHKL_USERDEFINED1, Fontsize-1)

				, sci.SetMarginWidthN(1,0)
			if main
				sci.GrabFocus()
			;~ , sci.Notify:="Notify"
			else
				sci.SetReadOnly(true)
			return new StyleRange("")
	}

	simpleRIS_AdjustFontSizeForDpi(fontSize){
		global guiPos,simpleRisCompensateDpiScale
		if (!simpleRisCompensateDpiScale)
			return fontSize

		; Scintilla point sizes follow Windows DPI scaling; compensate to keep XP/100% size.
		scale:=simpleRIS_GetDpiScale(guiPos.x+guiPos.w//2, guiPos.y+guiPos.h//2)
		if (scale<=1)
			return fontSize

		adjustedFontSize:=Round(fontSize/scale)
		return adjustedFontSize<8?8:adjustedFontSize
	}

	simpleRIS_GetDpiScale(x:="", y:=""){
		dpi:=0
		if (x!="" && y!="") {
			hMon:=simpleRIS_MonitorFromPoint(x, y)
			if (hMon) {
				dpiX:=0, dpiY:=0
				try {
					if (DllCall("Shcore\GetDpiForMonitor", "ptr", hMon, "int", 0, "uint*", dpiX, "uint*", dpiY)=0)
						dpi:=dpiX
				}
			}
		}
		if (!dpi && A_ScreenDPI)
			dpi:=A_ScreenDPI
		if (!dpi) {
			hDC:=DllCall("GetDC", "ptr", 0, "ptr")
			if (hDC) {
				dpi:=DllCall("GetDeviceCaps", "ptr", hDC, "int", 88)
				DllCall("ReleaseDC", "ptr", 0, "ptr", hDC)
			}
		}
		if (!dpi)
			dpi:=96
		return dpi/96.0
	}

	simpleRIS_MonitorFromPoint(x, y, flags:=2){
		pt64:=((y & 0xFFFFFFFF) << 32) | (x & 0xFFFFFFFF)
		return DllCall("User32\MonitorFromPoint", "int64", pt64, "uint", flags, "ptr")
	}

	SimpleRIS_IsWindowsBuildAtLeast(minBuild){
		VarSetCapacity(osvi, 284, 0)
		NumPut(284, osvi, 0, "UInt")
		if (DllCall("ntdll\RtlGetVersion", "ptr", &osvi) != 0)
			return false
		major:=NumGet(osvi, 4, "UInt")
			,build:=NumGet(osvi, 12, "UInt")
		return (major>10 || (major=10 && build>=minBuild))
	}

	SimpleRIS_ApplyModernWindowStyle(hwnd){
		if (!hwnd)
			return
		if (!SimpleRIS_IsWindowsBuildAtLeast(10240))
			return
		hDwm:=DllCall("GetModuleHandle", "str", "dwmapi.dll", "ptr")
		if (!hDwm)
			hDwm:=DllCall("LoadLibrary", "str", "dwmapi.dll", "ptr")
		if (!hDwm)
			return
		if (!DllCall("GetProcAddress", "ptr", hDwm, "astr", "DwmSetWindowAttribute", "ptr"))
			return

		useDarkMode:=1
		if (DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 20, "int*", useDarkMode, "int", 4) != 0)
			DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 19, "int*", useDarkMode, "int", 4)

		if (SimpleRIS_IsWindowsBuildAtLeast(22000)) {
			cornerPreference:=2
			DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 33, "int*", cornerPreference, "int", 4)
		}
	}

	SimpleRIS_UpdateActiveRim(hwnd:=""){
		global guihwnd
		static isActive:=""
		if (!guihwnd)
			return
		if (hwnd="" || hwnd=guihwnd)
			activeNow:=WinActive("ahk_id " guihwnd)?1:0
		else
			return
		if (activeNow=isActive)
			return
		isActive:=activeNow
		Gui, 1:Color, % activeNow ? "18222C" : "0E1319", 11161C
	}

	SimpleRIS_WM_ACTIVATE(wParam, lParam, msg, hwnd){
		SimpleRIS_UpdateActiveRim(hwnd)
	}

		Notify(wParam, lParam, msg, hwnd, obj){
			global PauseUpdate,noUpdateMode,sci,SciAutoCompleteList,sr, DoNotTriggerModified
				, thisAccNoTextHwnd, simpleRIS_UserEditStamp, SIMPLERIS_AUTOSAVE_DEBOUNCE_MS
			;~ static lastNotify

			; PauseUpdate/noUpdateMode suppress RIS synchronization, but the editor can still
			; receive genuine keyboard edits. Record those before the early return so a user
			; revision made after a finalized send can become the new recovery draft.
			if (obj.scnCode = SCN_MODIFIED && obj.modType & SC_PERFORMED_USER) {
				userEditAccNo:=thisAccNoTextHwnd?Trim(ControlGetText(thisAccNoTextHwnd)):""
				if (userEditAccNo!="") {
					if !IsObject(simpleRIS_UserEditStamp)
						simpleRIS_UserEditStamp:={}
					simpleRIS_UserEditStamp[userEditAccNo]:=A_Now A_MSec
					SetTimer, autosaveReportTextDebounced, % -SIMPLERIS_AUTOSAVE_DEBOUNCE_MS
				}
			}

			if(noUpdateMode || PauseUpdate){
				;~ sci.Notify:=""
				return
			}

			if (obj.scnCode = SCN_MODIFIED){
				SetTimer,notifyDifferentStudy,-1

				;~ if(!lastNotify || A_TickCount-lastNotify<1000){
				;~ lastNotify:=A_TickCount
				;~ return
				;~ }
				;~ lastNotify:=A_TickCount
				;~ sci.CONVERTEOLS(0)
				SetTimer,SCI_ColorRadReport, -1000
				;~ SetTimerF("update",-3000)
				;~ settimer,setontop,-500

				;~ if (priorAccNo!=thisAccNo)
				;~ priorAccNo:=thisAccNo:=ControlGetText(AccNoHwnd)
			}
			;~ if (obj.scnCode = SCN_CHARADDED && SciAutoCompleteList!="" ){
			;~ currentPos:=sci.GetCurrentPos()
			;~ wordStartPos := sci.WordStartPosition(currentPos,true)
			;~ if((len:=currentPos - wordStartPos)>0)
			;~ SetTimerF("AutoComplete",-300,[len])
			;~ else
			;~ SetTimerF("AutoComplete",0)
			;~ }
			return
		}

		notifyDifferentStudy(){
			global lastNotifyDifferentStudy, RisState, sci
			if WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
				return

			if (!lastNotifyDifferentStudy || (A_TickCount - lastNotifyDifferentStudy>3000)){
				if !RisChartNoMatchPacs(RisState, impaxState) && trim(SCI_GETTEXT(sci))!=""
					ShowToolTip("!!!!!!!!!!!!!!!!!!!!!!!!!!`n`nDifferent study between RIS/IMPAX`n`n!!!!!!!!!!!!!!!!!!!!!!!!!!",2000)
						,lastNotifyDifferentStudy:=A_TickCount
			}
		}

		updateToRis:
			;~ sci.gettext(sci.GetTextLength()+3,text:="")
			text:=SCI_GETTEXT(sci)
				,Edit_SetText(RisReports[1,1], text), CH_RIS.flush()
				,Edit_SetSel(RisReports[1,1], sci.getAnchor(), sci.GetCurrentPos())
		return
		SCI_ColorRadReport:
			;~ ToolTip % A_TickCount
			if (!noUpdateMode&&!PauseUpdate){
				;~ DoNotTriggerModified:=1
				;~ SetTimer,SCI_ColorRadReport, Off
				;~ settimer,update,Off
				;~ sci.Notify:=""
				gosub update1
				SCI_ColorRadReport(sci,sr,0)
				;~ sci.Notify:="Notify"
			}
		return
	;~ AutoComplete(len){
	;~ global
	;~ sci.AutoCShow(len, lst:=SciAutoCompleteList)
	;~ }

	#IfWinActive,ahk_group mainGui
		~#esc::
			resetHotstringBuffer(-1)
		return
	#IfWinActive

	gui:
	;~ gui,1:default
	gui,1:new,+hwndguiHwnd +toolwindow -caption +lastfound
	groupadd,MyGui,ahk_id %guiHwnd%
	GroupAdd,mainGui,ahk_id %guiHwnd%
	gui,color,11161C,11161C
	gui,font,s14 cDDE6EF,Segoe UI
	gui,add,button,w0 h0 gnothing
	gui,add,text,vthisAccNoText hwndthisAccNoTextHwnd w0 h0
	WinSetTitle,ahk_id %guihwnd%,,simple RIS
	SimpleRIS_ApplyModernWindowStyle(guihwnd)
	OnMessage(0x06, "SimpleRIS_WM_ACTIVATE")
	;~ for arg in args
	;~ if (arg="initAtCenter=0")
	;~ initAtCenter:=0
	;~ else if (arg="initAtCenter=1")
	;~ initAtCenter:=1
	simpleRIS_EditorPad:=12
	gosub calWidthHeight
	sci:=new scintilla(guihwnd,simpleRIS_EditorPad,simpleRIS_EditorPad,guiPos.w-simpleRIS_EditorPad*2,guiPos.h-simpleRIS_EditorPad*2)
		,sr:=sciSettings(sci)
	;~ gui,add,edit,xp yp vedit w1000 h300 hwndeditHwnd,
	;~ gui,add,edit,vedit2 w1000 h0 hwndedit2Hwnd,
	;~ if !initAtCenter
	;~ gui,show,% "x" monitors.2.l+Floor(monitors.2.w/2)-505 " y" monitors.2.b-150 " w1010 h310",simple RIS
	;~ else if monitors.maxindex()=1
	;~ gui,show,% "x" Floor(a_screenwidth/2)-500 " y" a_screenheight-310 " w1010 h310",simple RIS
	;~ else
	;~ gui,show,% "x" monitors.2.l+Floor(monitors.2.w/2)-505 " y" Floor(monitors.2.b/2)-155 " w1010 h310",simple RIS
	if FileExist(A_ScriptDir "\*simpleRIS pos"){
		Loop,% A_ScriptDir "\*simpleRIS pos"
		{
			fileread,p,% A_LoopFileLongPath
			FileDelete,% A_LoopFileLongPath
		}

		pos:=[]
		Loop,Parse,p,`,
			pos.push(trim(A_LoopField))
		gui,show,% "x" pos[1] " y" pos[2] " w" pos[3] " h" pos[4],simple RIS
		;~ WinShow,simple RIS ahk_pid %simpleRIS__pid%
		WinMove,ahk_id %guihwnd%,,% pos[1], % pos[2], % pos[3], % pos[4]
	}else{
		gui,show,% "x" guiPos.x " y" guiPos.y " w" guiPos.w " h" guiPos.h,simple RIS
		;~ WinShow,simple RIS ahk_pid %simpleRIS__pid%
		WinMove,ahk_id %guihwnd%,,% guiPos.x, % guiPos.y, % guiPos.w, % guiPos.h
	}
	WinGetPos,x,y,w,h,ahk_id %guihwnd%
	ControlMove,,% simpleRIS_EditorPad,% simpleRIS_EditorPad,% w-simpleRIS_EditorPad*2,% h-simpleRIS_EditorPad*2,% "ahk_id " sci.hwnd
	SimpleRIS_UpdateActiveRim()
	;~ controlget,editHwnd,hwnd,,scintilla1,% "ahk_id " guihwnd
	editHwnd:=sci.hwnd
	;~ if(monitors.maxindex()<3){
	;~ guicontrol,-redraw,% editHwnd
	;~ redraw:=0
	;~ settimer,editRedraw,5
	;~ }
	;~ MsgBox % sci.hwnd
	settimer,setontop,-1
	settimerF("AccNoChanged", -1)
		,hIMC := DllCall("Imm32\ImmAssociateContext", "ptr", editHwnd, "ptr", 0, "ptr")
	;~ settimer,disableIME,-2000
	;~ settimer,disableIME2,5000
	return

	disableIME(){
		if (impaxState:=impaxOpened())[1]!=2
			return
		Loop 3
			for k,v in getControls(impaxState[2,A_Index])
				DllCall("Imm32\ImmAssociateContext", "ptr", v.hwnd, "ptr", 0, "ptr")
		disableIME2()
	}
	disableIME2(){
		for k,v in getViewFrame()
			for x,y in v
				for m,n in y
					DllCall("Imm32\ImmAssociateContext", "ptr", n, "ptr", 0, "ptr")
	}

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

	editRedraw:
	;~ guicontrol,% ((redraw:=!redraw)?"+":"-") "redraw",% editHwnd
	return

	caretPos:
		if(selectAll){
			selectAll:=0
			;~ settimer,caretPos,-5000
			return
		}else if ((editText:=controlgettext(editHwnd))!="") {
			;~ Edit_GetSel(editHwnd,cStart,cEnd)
			cStart:=sci.getAnchor(),cEnd:=sci.GetCurrentPos()
			if(cStart=0 && cEnd=strlen(editText) && pStart!="" && pEnd!="" && winactive("ahk_id " guiHwnd)){
				Edit_SetSel(sci.hwnd,pStart,pEnd)
			}else{
				pStart:=cStart,pEnd:=cEnd
			}
		}
	;~ settimer,caretPos,-500
	return

	focusEdit:
		if(winactive("ahk_id " guiHwnd)){
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
			if(p_l=editHwnd){
				controlfocus,,ahk_id %editHwnd%
			}
		}
	}

	update(){
		global debug
		if debug
			ToolTip % A_ThisFunc
		gosub update
	}

	windowHook:
	;~ DllCall( "RegisterShellHookWindow", UInt, guiHwnd )
	;~ MsgNum := DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" )
	;~ OnMessage( MsgNum, "ShellMessage" )
	return

#ifwinactive,ahk_exe Menu.exe
	F5::
		;~ IfWinNotActive,HC-
		;~ send {F5}
		;~ pAccNo:=cAccNo:=ControlGetText(risAccHwnd)
		settimer,ReactivateUpdateMode
		gosub openStudy
	;~ pauseUpdateMode(500, 1)

	return

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

#ifwinactive,ahk_group simpleRISGUI
;~ ~lbutton::
;~ gosub unhookMouse
;~ OnMessage( 0x200, "WM_MOUSEMOVE" )
;~ return

;~ ~lbutton up::
;~ OnMessage( 0x200, "" )
;~ return

#IfWinActive

MButtonHotkey:
	Hotkey,ifwinactive,ahk_group MyGui
	Hotkey,MButton,_MButton,on
	Hotkey,^RButton,_MButton,on
	Hotkey,IfWinActive
return

#ifwinactive,ahk_group MyGui
	_MButton:
	MButton::
		gosub update1
		convertNumber2Bullet()
	return

	convertNumber2Bullet(){
		global editHwnd, editHwnd_, sci_, sci
		t:=ControlGetText(editHwnd_)
			,ret:=""
			,bu:="- "
		Loop,parse,t,`n,`r
			ret.=RegExReplace(A_LoopField, "^[ \t]*\d+\.[ \t]*", bu) "`r`n"

		SCI_SetText(sci, r:=ret)
			,sci_.SetText(r:=ret)
			,Edit_SetText(RisReports[1,1], ret), CH_RIS.flush()
			,Edit_Setsel(editHwnd, len:=StrLen(ret), len)
			,Edit_Setsel(editHwnd_, len, len)
			,Edit_Setsel(RisReports[1,1], len, len)
	}

	addNextLine:
		KeyWait,Ctrl,t0.4
		KeyWait,o,t0.4
		SendLevelChange("{End}{Enter}")
	return

	resetText:
		;~ ^n::
		if(A_PriorHotkey = A_ThisHotkey && A_TimeSincePriorHotkey < 500){
			RisReports:=getRisReports()
			Edit_SetText(RisReports[1,1], "")
			Edit_SetText(RisReports[1,2], "")
			CH_RIS.exam:=""
				,CH_RIS.impression:=""
				,CH_RIS.report:=""
				,CH_RIS.flush()
			pAccNo:=cAccNo:=ControlGetText(risAccHwnd)
		}
		;~ gosub renewRis
		;~ gosub renewRisReports
		;~ controlsettext,,,% "ahk_id " editHwnd
		gosub resetEdit

		;~ controlsettext,,,% "ahk_id " RisReports[1,1]
		resetHotstringBuffer(-1)
	return
	updateText(){
		gosub updateText
	}

	updateText:
		;~ ^b::
		if (__is_CH){
			; Guard: only call update_wb when IE has finished loading (ReadyState=4)
			; Accessing IE DOM during navigation blocks the COM thread indefinitely.
			ieReady := false
			try ieReady := (CH_RIS.wb.ReadyState = 4)
			if ieReady
				CH_RIS.update_wb()

			chXRayStudy := CHIsXRayStudy()
			if (!chXRayStudy && SCI_GETTEXT(sci) == "") {
				try examText := CH_RIS.inputElements.reportText.value
				if (examText == "" || examText == CH_RIS.examname) {
					examname := CH_RIS.examname
					if (examname != "") {
						SCI_SETTEXT(sci, examname)
						sci.gotopos(StrLen(examname))
					}
				}
			}

			pAccNo:=cAccNo:=CH_RIS.accNo
		}else{
			pAccNo:=cAccNo:=ControlGetText(risAccHwnd)

		}
		editorAccNo:=Trim(ControlGetText(thisAccNoTextHwnd))
		if(cAccNo!=editorAccNo){
			; updateText is another accession-transition path. Save while the hidden field
			; still names the study whose text is in Scintilla, then clear and relabel it.
			if (editorAccNo!="")
				simpleRIS_AutosaveCurrentReport(editorAccNo, "before_acc_change")
			sci_SetText(sci, t:="")
				,Edit_SetText(editHwnd_, "")
		}
		guicontrol,%guihwnd%:,thisAccNoText,% cAccNo
		gosub update1
		;~ gosub loadRisText
		resetHotstringBuffer(-1)
	return

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
			,updating:=false
		gosub update1
		if(__is_CH){
			CH_RIS.check_wb()
			CH_RIS.activate()
		}else{
			controlfocus,,% "ahk_id " RisReports[1,2]
			winactivate,% "ahk_id " RisState[2]
			controlfocus,,% "ahk_id " RisReports[1,2]
		}
	return

	F11::
	F12::
		simpleRIS_AutosaveCurrentReport()
		gosub PacsIEnextStudy
		if !winexist("ahk_exe PacsIE.exe") && !WinExist("ahk_exe python.exe") && !WinExist("ahk_exe miniPACS.exe")
			gosub RisNextStudy
	;~ controlsettext,,% "",ahk_id %editHwnd%
	changeStudy:
	;~ gosub resetEdit
	;~ if !(noUpdateMode || PauseUpdate)
	;~ pauseUpdateMode(2000,1)
	;~ sci.clearAll()
	;~ priorAccNo:=""
	;~ settimer,update,-2000
	;~ settimer,updateHx,Off
	return

	;~ F11::
	;~ gosub PacsIEnextStudy
	;~ return

	;~ ~Enter::
	;~ ~numpadEnter::
	;~ ~,::
	;~ ~.::
	;~ ~:::
	;~ ~;::
	;~ ~-::
	;~ ~)::
	;~ ~pgup::
	;~ ~pgdn::
	;~ ~space::
	;~ gosub update
	;~ return

	reportStudy:
		;~ ~+F3::
		;~ ~+F1::
		;~ ~F2::
		;~ ~+F2::
		;~ ~F3::
		;~ ~F12::
		;~ ~F11::
		;~ ~F1::
		;~ settimer,resetReports,-500
		;~ settimer,update,Off
		;~ settimer,resetEdit,-500
		simpleRIS_AutosaveCurrentReport()
		if !(noUpdateMode || PauseUpdate) && !WinExist("ahk_exe PacsIE.exe") && !WinExist("WM_COPYDATA_Listener_miniPACS")
			&& !WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
			pauseUpdateMode(2000,1)
	;~ settimer,updateHx,Off
	;~ settimer,impaxNextStudy,-1000
	return

	~#up::
	~#down::
		historyInd:=mod(historyInd + (instr(a_thishotkey,"up")?(historySize-1):1), historySize)
			;~ controlsettext,,% history[mod(historyInd-1,historySize)+1],ahk_id %editHwnd%
			;~ sci.Notify:=""
			,SCI_SETTEXT(sci, tmp:=history[mod(historyInd,historySize)])
			,sci_.SetText(tmp:=history[mod(historyInd,historySize)])
		;~ ,sci.Notify:="Notify"
		tooltip,% "Stored report #" historyInd+1
		settimer,tooltip,-1000
	return

	openStudy:
	;~ t
	~F5::
	F6::
		if InStr(thisPlace, "N hospital") {
			;~ ToolTip % getControlNameByHwnd(risopened()[2], 0xC1BC8)
			;~ ToolTip % !(openImpax:=getNetAcc(RisOpened()[2],"cmdDs3000","WindowsForms10.BUTTON"))
			if ControlGetText(RisReports[1,1])="" && ControlGetText(RisReports[1,2])=""
				gosub resetEdit
			AllRis:=risopened(1)
			WinGetTitle,t,% "ahk_id " AllRis[2,1]
			;~ if !InStr(t, "HC-"){
			;~ If (h:=WinExist("__maskImpaxLoading ahk_class AutoHotkeyGUI")) && winvisible(h)
			;~ return

			thisChartNo:=getRisChartNo(AllRis[2,1])
			if (InStr(t, "HC-") || (thisChartNo~="i)^[YH]"))  {
				if  (ebm_hwnd:=WinExist("EBM Preload ahk_class AutoHotkeyGUI")){
					PostMessage,0x2020,,,,ahk_id %ebm_hwnd%
					risOpenOldStudy(RisState[2], false)
				}else{
					risOpenStudyImpax(RisState[2])
				}
			}else{

				if(WinExist("impaxOpenNext_main ahk_class AutoHotkeyGUI"))
					PostMessage,0x10102,,,,impaxOpenNext_main ahk_class AutoHotkeyGUI
				else {
					gosub createBlack
					risOpenStudyImpax(RisState[2])
						,risOpenOldStudy(RisState[2])
					try
					run % A_ScriptDir "\impaxOpenNext.exe"
				}

			}
		}else if InStr(thisPlace, "C hospital"){

		}
		pauseUpdateMode(500, 1)
		gosub updatehxfirst

	return

	;~ openNextEBM(nextAccNo, nextChartNo){
	;~ global HPwb, cAccNo
	;~ if !HPwb
	;~ HPwb:=HWebPacsLogin_IE("H00000", "MOCK_PASSWORD")
	;~ HPwb.Visible:=false
	;~ HWebPacsQuery_IE(nextAccNo, HPwb)
	;~ winwait,% nextChartNo " ahk_exe WEBVIE~1.EXE",,3
	;~ WinMinimize,% nextChartNo " ahk_exe WEBVIE~1.EXE"
	;~ winactivate,% cAccNo " ahk_exe WEBVIE~1.EXE"
	;~ return
	;~ }

	createBlack(){
		global debug
		if debug
			ToolTip % A_ThisFunc
		gosub createBlack
	}

	createBlack:
	return
	;~ maskImpaxLoading()
	if(monitors.maxindex()<2)
		return
	IfWinExist,__mask ahk_class AutoHotkeyGUI
		return
	;~ winget,_pName,ProcessName,% "ahk_id " wingetatcoords(monitors[2].l+1, monitors[2].t+1,"id")
	;~ if !InStr(_pName, "impax")
	;~ return

	;~ gui,__mask:new
	;~ gui,__mask:+toolwindow -caption +alwaysontop +hwnd__maskGuiHwnd
	;~ gui,__mask:color,black
	;~ winset,trans,200,% "ahk_id " __maskGuiHwnd
	;~ gui,__mask:show,% "x" monitors[2].l " y" monitors[2].t " w" monitors[monitors.maxindex()].r - monitors[2].l + 1 " h" monitors[2].h,__maskImpaxLoading
	return

#ifwinactive

#IfWinExist,__maskImpaxLoading ahk_class AutoHotkeyGUI
	~WheelUp::
	~WheelDown::
		;~ ToolTip % A_TickCount
		;~ gui,__mask:Destroy
		MouseGetPos,,win,con,2
		winget,pName,ProcessName,ahk_id %win%
		if (pName~=MatchPacsProcessName()){
			winactivate,ahk_id %win%
			ControlFocus,,ahk_id %con%
		}
	return
#IfWinExist

;~ #IfWinActive,__maskImpaxLoading ahk_class AutoHotkeyGUI
;~ ~Space::
;~ ~Enter::
;~ ~NumpadEnd::
;~ ~LButton::
;~ gui,__mask:Destroy
;~ return
;~ #IfWinActive

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
resetEdit(w=0,l=0,m=0,h=0){
	;~ ToolTip % "Reset Edit"
	global debug

	if (debug ){
		ToolTip % A_ThisFunc
		if WinExist("ahk_id " h)
			FileAppend,% WinGetTitle(h) "," winget("ProcessName", h) "`n", %SIMPLERIS_LOG_FILE%,utf-8-Raw
	}
	gosub resetEdit
}
resetEdit:
	;~ ToolTip % A_TickCount "resetEdit"
	;~ settimer,update,Off
	;~ sr.reset()
	;~ sr.SetText(unused, t:="")
	; CH_RIS posts reset before its accession-change notification. Capture the editor
	; under the still-displayed (old) accession before ClearAll() can discard recent text.
	resetAccNo:=thisAccNoTextHwnd?ControlGetText(thisAccNoTextHwnd):""
	if (resetAccNo!="")
		simpleRIS_AutosaveCurrentReport(resetAccNo, "before_reset")

	text2:=SCI_GETTEXT(sci)
		;~ ,text3:=sci_.GetText()
		,text2:=RegExReplace(trim(text2), "\r?\n", "`r`n")
		;~ ,text3:=RegExReplace(trim(text3), "\r?\n", "`r`n")

		,AddHistory(text2)
	;~ ,AddHistory(text3)

	sr.reset()
		,sci.ClearAll()
		,sci_.ClearAll()
		,Edit_SetText(edithwnd, "")
		,sci_.SetText("")
	;~ PostMessage,0x2024,,,,simpleRIS__main ahk_class AutoHotkeyGUI
	;~ settimer,update,-3000
	;~ FileAppend,% a_now ": resetEdit `r`n",templog.txt,utf-8
	gosub adjustFontSize
return

PacsIEnextStudy:
	;~ wingettitle,title,PacsIE Log GUI ahk_exe PacsIE.exe
	;~ regexmatch(title,"PacsIE Log GUI (\w+):",pacsIeHwnd)
	;~ if (pacsIeHwnd)
	;~ PostMessage,% a_thishotkey="F12"?0x10504:0x10503,,,,PacsIE ahk_class AutoHotkey
	PostMessage,% a_thishotkey="F12"?0x10504:0x10503,,,,miniPACS_bridge_main ahk_class AutoHotkeyGUI
return

#ifwinactive,ahk_exe Menu.exe
	~rbutton::
		keywait, rbutton, t0.3
		if errorlevel = 1
		{
			gosub update
		}
	return

	changeStudyKey:
	;~ ~F3::
	;~ ~+F3::
	;~ ~F4::
	;~ ~F2::
	~F12::
	~F11::
		;~ ~F1::
		;~ ~+F1::

		;~ settimer, resetEdit,-500
		if !(noUpdateMode || PauseUpdate) && !WinExist("ahk_exe PacsIE.exe") && !WinExist("WM_COPYDATA_Listener_miniPACS")
			&& !WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
			pauseUpdateMode(2000,1)
		;~ settimer,update,-2000
		settimer,impaxNextStudy,-1000
	return
#ifwinactive

impaxNextStudy:
	if !InStr(thisPlace, "N hospital")
		return
	;~ if(getRisChartNo(RisState[2])=getImpaxChartNo()){
	if RisChartNoMatchPacs(RisState, impaxState){
		risOpenOldStudy(RisState[2])
	}else{
		PostMessage,0x10102,,,,impaxOpenNext_main ahk_class AutoHotkeyGUI
	}
return

checkActive:
	if !winactive("ahk_id " guihwnd_) && !hooked
		gosub hookMouse
return

~#!q::
	if(a_thishotkey=a_priorhotkey && a_timesincepriorhotkey<300){
		for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name = 'cmd.exe' and CommandLine like '%simpleRISDelegate.cmd%' ")
			TaskKill(process.ProcessId)
		exitapp
	}
;~ esc::

hookMouse:
return
;~ OnMessage( 0x200, "" )
mouseHooks.push(SetWindowsHookEx(WH_MOUSE_LL   := 14, RegisterCallback("MouseHook", "Fast")))
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
	if(pName~=MatchPacsProcessName() "|PacsIE.exe|WEBVIE~1.exe|python.exe|miniPACS.exe")
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
DetectHiddenWindows,on
;~ MsgBox % A_ExitReason
noUpdateMode:=PauseUpdate:=0
	,updating:=false
simpleRIS_AutosaveCurrentReport()
gosub update
;~ gosub unhookMouse
;~ ListLines
;~ Sleep 10000
;~ runTimeBP("---")

;~ FileDelete,simpleRISDelegate.cmd
Process,Close,%simpleRisDelegatePid%
for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where CommandLine like 	'%simpleRISDelegate.cmd%' ")
	TaskKill(process.ProcessID)

PostMessage,0x10101,,,,simpleRIS__main ahk_class AutoHotkeyGUI
PostMessage,0x10101,,,,prettyOldHx ahk_class AutoHotkeyGUI
PostMessage,0x10101,,,,simpleRIS_patch_main ahk_class AutoHotkeyGUI

WinClose,ahk_exe simpleRIS_patch.exe
TaskKill(winget("PID", "simpleRIS_patch_main ahk_class AutoHotkeyGUI"))
TaskKill(winget("PID", "simple__main ahk_class AutoHotkeyGUI"))
TaskKill(winget("PID", "prettyOldHx ahk_class AutoHotkeyGUI"))
;~ if !WinExist("ahk_exe autorun.exe")
;~ WinClose,ahk_exe UIAutomationServer.exe
HPwb.Visible:=true

exitapp
return

AddHistory(text){
	global history, historyInd, historySize, hxDir
	if(text!="" && text!=history[Mod(historyInd, historySize)]){
		history[mod((++historyInd),historySize)]:=text
		FileAppend,% text,% hxDir "\" a_now "_" A_TickCount ".txt",utf-8-Raw
	}
}

setupReportAutosave:
	simpleRIS_SetupReportAutosave()
return

autosaveReportText:
	simpleRIS_AutosaveCurrentReport()
return

autosaveReportTextDebounced:
	simpleRIS_AutosaveCurrentReport("", "user_edit")
return

cleanupReportAutosave:
	SimpleRISRecovery_Cleanup(SIMPLERIS_RECOVERY_RETENTION_DAYS)
return

simpleRIS_AutosaveDir(){
	return SimpleRISRecovery_Dir()
}

simpleRIS_NormalizeReportText(text){
	return SimpleRISRecovery_NormalizeText(text)
}

simpleRIS_SetupReportAutosave(){
	global simpleRIS_AutosaveObserved, simpleRIS_UserEditStamp
		, SIMPLERIS_AUTOSAVE_INTERVAL_MS, SIMPLERIS_RECOVERY_RETENTION_DAYS
		, SIMPLERIS_RECOVERY_CLEANUP_MS
	FileCreateDir,% simpleRIS_AutosaveDir()
	SimpleRISRecovery_Cleanup(SIMPLERIS_RECOVERY_RETENTION_DAYS)
	if !IsObject(simpleRIS_AutosaveObserved)
		simpleRIS_AutosaveObserved:={}
	if !IsObject(simpleRIS_UserEditStamp)
		simpleRIS_UserEditStamp:={}
	; Keep crash exposure short while avoiding a disk write for every keystroke.
	SetTimer, autosaveReportText, % SIMPLERIS_AUTOSAVE_INTERVAL_MS
	SetTimer, cleanupReportAutosave, % SIMPLERIS_RECOVERY_CLEANUP_MS
}

simpleRIS_GetAutosaveStudyInfo(){
	global __is_CH, CH_RIS, RisState
	study:={chartNo:"", examDate:"", examName:""}
	if (__is_CH) {
		try study.chartNo:=CH_RIS.chartNo
		try study.examDate:=CH_RIS.examDate
		try study.examName:=CH_RIS.examName
	} else {
		try study.chartNo:=getRisChartNo(RisState[2])
		try study.examDate:=getRisExamDate(RisState[2])
		try study.examName:=parseRisExamItems(getRisExamItems(RisState[2]))[1,1]
	}
	return study
}

simpleRIS_NoteObservedReport(accNo, text){
	global simpleRIS_AutosaveObserved
	if !IsObject(simpleRIS_AutosaveObserved)
		simpleRIS_AutosaveObserved:={}
	simpleRIS_AutosaveObserved[Trim(accNo)]:=simpleRIS_NormalizeReportText(text)
}

simpleRIS_AutosaveCurrentReport(accNo:="", reason:="timer"){
	global sci, cAccNo, thisAccNoTextHwnd, simpleRIS_AutosaveObserved
		, simpleRIS_UserEditStamp, SimpleRISRecovery_LastError, SimpleRISRecovery_LastStep

	; The hidden GUI field deliberately lags the owner during a transition and therefore
	; identifies the report currently in Scintilla. Prefer it over the new owner accNo.
	if (accNo="" && thisAccNoTextHwnd)
		accNo:=ControlGetText(thisAccNoTextHwnd)
	if (accNo="")
		accNo:=cAccNo
	accNo:=Trim(accNo)
	if (accNo="")
		return false

	try text:=simpleRIS_NormalizeReportText(SCI_GETTEXT(sci))
	catch
		return false
	study:=simpleRIS_GetAutosaveStudyInfo()
	isBlankOrTitle:=SimpleRISRecovery_IsBlankOrTitle(text, study.examName)
	wasObserved:=IsObject(simpleRIS_AutosaveObserved) && simpleRIS_AutosaveObserved.HasKey(accNo)
	priorText:=wasObserved ? simpleRIS_AutosaveObserved[accNo] : ""
	simpleRIS_NoteObservedReport(accNo, text)

	; On startup/new-study load the editor is temporarily empty/title-only. Do not turn
	; that transient state into a tombstone before recovery has had a chance to run.
	if (isBlankOrTitle && !wasObserved)
		return false
	if (isBlankOrTitle && SimpleRISRecovery_IsBlankOrTitle(priorText, study.examName))
		return false
	status:=(Trim(text)="") ? "cleared" : "title_only"
	if !isBlankOrTitle
		status:="draft"
	editStamp:=(IsObject(simpleRIS_UserEditStamp)
		&& simpleRIS_UserEditStamp.HasKey(accNo)) ? simpleRIS_UserEditStamp[accNo] : ""
	saved:=SimpleRISRecovery_Save(accNo, text, status, study, false, editStamp)
	if !saved
		DebugLog("simpleRIS.autosave", "FAILED accNo=" accNo " reason=" reason
			. " step=" SimpleRISRecovery_LastStep " error=" SimpleRISRecovery_LastError)
	return saved
}

simpleRIS_ShouldLoadAutosavedReport(risExamText, examname){
	return SimpleRISRecovery_IsBlankOrTitle(risExamText, examname)
}

simpleRIS_ShouldCheckAutosavedReport(){
	return !WinExist("YCH_XR_main ahk_class AutoHotkeyGUI")
		&& !WinExist("YCH_BMD_main ahk_class AutoHotkeyGUI")
}

simpleRIS_RecoveryPageStable(accNo, risExamText, examname){
	global SIMPLERIS_RECOVERY_STABLE_MS
	static candidateAccNo:="", candidateSignature:="", candidateTick:=0
	signature:=SimpleRISRecovery_ComparableText(risExamText) "|"
		. SimpleRISRecovery_ComparableText(examname)
	if (candidateAccNo!=accNo || candidateSignature!=signature) {
		candidateAccNo:=accNo
		candidateSignature:=signature
		candidateTick:=A_TickCount
		SetTimer, update1, % -(SIMPLERIS_RECOVERY_STABLE_MS+50)
		return false
	}
	if (A_TickCount-candidateTick<SIMPLERIS_RECOVERY_STABLE_MS) {
		SetTimer, update1, % -(SIMPLERIS_RECOVERY_STABLE_MS+50)
		return false
	}
	return true
}

simpleRIS_LoadAutosavedReport(accNo){
	global sci, sci_, editHwnd_, __is_CH, CH_RIS

	savedText:=SimpleRISRecovery_Load(accNo, status, found)
	if (!found || status="cleared" || status="title_only" || Trim(savedText)="")
		return ""
	examname:=""
	if (__is_CH) {
		try examname:=CH_RIS.examname
		if (SimpleRISRecovery_ComparableText(examname)
			=SimpleRISRecovery_ComparableText(savedText))
			return ""
	}

	SCI_SETTEXT(sci, savedText)
	if (IsObject(sci_) && sci_.hwnd && WinExist("ahk_id " sci_.hwnd))
		sci_.SetText(savedText)
	len:=StrLen(savedText)
	Edit_SetSel(sci.hwnd, len, len)
	if (editHwnd_)
		Edit_SetSel(editHwnd_, len, len)
	sci.ScrollCaret()
	if (IsObject(sci_) && sci_.hwnd && WinExist("ahk_id " sci_.hwnd))
		sci_.ScrollCaret()
	simpleRIS_NoteObservedReport(accNo, savedText)
	; Migrate a legacy date_chart_accession.txt recovery into the stable v2 store.
	SimpleRISRecovery_Save(accNo, savedText, status, simpleRIS_GetAutosaveStudyInfo())
	AddHistory(savedText)
	return savedText
}

;~ t::
;~ sci.gettext(sci.GetTextLength()+1,text2:="")
;~ MsgBox % "." SCI_GETTEXT(sci) "." Edit_GetText(sci.hwnd) "." text2
;~ return

loadRisText:
	;~ gosub renewRis
	;~ gosub renewRisReports

	;~ text2:=controlgettext(editHwnd)
	;~ sci.gettext(sci.GetTextLength()+3,text2:="")

	AddHistory(text2:=SCI_GETTEXT(sci))

		;~ controlsettext,,% text:=controlgettext(RisReports[1,1]),% "ahk_id " editHwnd
		,SCI_SETTEXT(sci, tmp:=text:=controlgettext(RisReports[1,1]))
		,sci_.SetText(tmp:=text)
		,Edit_SetSel(sci.hwnd,len:=strlen(text),len)
		,Edit_SetSel(editHwnd_,len,len)
	;~ Edit_ScrollCaret(editHwnd)
	sci.ScrollCaret()
	sci_.ScrollCaret()

return

updateRisAccNo:
;~ gosub renewRis
;~ gosub renewRisReports
;~ gosub renewAccNo
;~ thisAccNo:=controlgettext(AccNoHwnd)
;~ if(priorAccNo && thisAccNo!=priorAccNo){
;~ controlsettext,,,% "ahk_id " editHwnd
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
updatingOff:
	updating:=false
return
;~ f::

GetEditText:
	guihwnds:=getSimpleRisGuiHwnds()
		,editHwnd_:=(editHwnds:=getSimpleRisEditHwnds(guihwnds))[2]
		,text1:=controlgettext(risreports[1,1]), text1_:=ControlGetText(RisReports[1,2])
		,sci.CONVERTEOLS(0)
		,sciText:=text2:=SCI_GETTEXT(sci)
		;~ ,text3:=sci_&&controlexists("ahk_id " sci_.hwnd)?sci_.GetText():(controlexists(edithwnd_)?((sci_:=new RemoteScintilla(edithwnd_)).GetText()):"")
		,oText1:=new ReportImpression(text1, text1_)
		,oText2:=new ReportImpression(text2)
	;~ ,oText3:=new ReportImpression(text3)
	/*
	text1: text on RIS, text1_: text on RIS impression
	text2: text on this simple RIS
	text3: text on new simple RIS

	priority: (if non-empty)
	text3 > text2 > text1
	*/

		,text1:=RegExReplace(trim(text1), "\r?\n", "`r`n")
		,text1_:=RegExReplace(trim(text1_), "\r?\n", "`r`n")
		,text2:=RegExReplace(trim(text2), "\r?\n", "`r`n")
return

update:
	;~ if(debug){
	;~ ListLines
	;~ pause
	;~ }
	critical
	DetectHiddenWindows,on
	if (noUpdateMode || PauseUpdate || RisState[1]!=2 || WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")){
		;~ ToolTip % "NOT UPDATING............."

		return
	}

update1:
	DetectHiddenWindows,on
	if updating
		return
	if WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
		return
update2:
	if (__is_CH && CH_RIS.accNo)
		risAccHwnd:=CH_RIS.gui.accNo_edit_auto
	if(thisAccNoTextHwnd && (getAccNo:=ControlGetText(risAccHwnd))!="" &&  (cAccNo:=ControlGetText(thisAccNoTextHwnd))!=getAccNo){
		DebugLog("simpleRIS.update1", "accNo mismatch risAcc=" getAccNo " gui=" cAccNo " -> accNoChanged()")
		accNoChanged()
		return
	}

	if __is_N &&  (ControlGetText(risAccHwnd)="" || cAccNo!=ControlGetText(risAccHwnd) || confirmRenew>0){
		settimer,,-1000
		return
	}
	if !__is_CH && (!sci_ || !WinExist(sci_.hwnd))
		renewSecondSimpleRIS()
	settimer,updatingOff,-1000
	updating:=true
	DebugLog("simpleRIS.update1", "GetEditText accNo=" cAccNo)
	gosub GetEditText
	;~ ,text3:=RegExReplace(trim(text3), "\r?\n", "`r`n")
	Edit_getsel(editHwnd_, caretS, caretE)

		;~ if !(edithwnd_)
		;~ text3:=text2
		,hasSimpleRISsimpleEdit:=WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
		,chXRayStudy:=CHIsXRayStudy()
		,recoveryLoadedThisCycle:=false

	recoveryEligible:=__is_CH && simpleRIS_ShouldCheckAutosavedReport()
		&& text2="" && text1_=""
		&& simpleRIS_ShouldLoadAutosavedReport(text1, CH_RIS.examname)
	if (recoveryEligible && !simpleRIS_RecoveryPageStable(cAccNo, text1, CH_RIS.examname)) {
		DebugLog("simpleRIS.update1", "waiting for stable title-only RIS page accNo=" cAccNo)
		goto updateEnd
	}
	if (recoveryEligible) {
		if ((autosavedText:=simpleRIS_LoadAutosavedReport(cAccNo))!="") {
			text2:=autosavedText
			oText2:=new ReportImpression(text2)
			recoveryLoadedThisCycle:=true
			DebugLog("simpleRIS.update1", "loaded autosaved report accNo=" cAccNo " len=" StrLen(text2))
		}
	}

	if !(hasSimpleRISsimpleEdit) {
		if (chXRayStudy) {
			if (text1!="" || text2!="")
				DebugLog("simpleRIS.update1", "C hospital X-Ray study -> skip simpleRIS/RIS text sync text1Len=" StrLen(text1) " text2Len=" StrLen(text2))
		} else if(text2!="" && !recoveryLoadedThisCycle) {
			DebugLog("simpleRIS.update1", "text2 non-empty -> push to RIS exam (len=" StrLen(text2) ")")
			; replace text1
			;~ Edit_SetText(RisReports[1,1], text2), CH_RIS.flush()
			__is_CH?oText2.set_text(RisReports[1,1],RisReports[1,2]):oText2.set_text(RisReports[1,1],0,1)
			CH_RIS.flush()
			Edit_Setsel(RisReports[1,1],caretS,caretE)
			Edit_ScrollCaret(RisReports[1,1])
			AddHistory(text2)
		} else if (recoveryLoadedThisCycle) {
			; Keep recovery local for this cycle. This prevents a title-only/async web page
			; from being overwritten before its server report has had time to populate.
			DebugLog("simpleRIS.update1", "recovery loaded locally; defer RIS push accNo=" cAccNo)
		} else if (text1!="" && !WinExist("YCH_XR_main ahk_class AutoHotkeyGUI")){  ;copy text1 to text2 and text3
			DebugLog("simpleRIS.update1", "text1 non-empty text2 empty -> pull from RIS to editor (len=" StrLen(text1) ")")
			if(__is_CH)
				text1:=RegExReplace(oText1.combine(), "(?<!\r)\n", "`r`n")
			sci_.SetText(t:=text1)
				,SCI_SetText(sci, tmp:=text1)
				,Edit_getsel(RisReports[1,1], caretS, caretE)
				,Edit_Setsel(sci.hwnd, caretS, caretE)
				,Edit_Setsel(editHwnd_, caretS, caretE)
				,sci_.ScrollCaret()
				,AddHistory(text1)
		}
	}
	goto updateEnd

	if(trim(text1)=trim(text3)){
		if(trim(text3)!=trim(text2))
			AddHistory(text2)
				, SCI_SETTEXT(sci, tmp:=text3)
				,Edit_getsel(editHwnd_, caretS, caretE)
				,Edit_Setsel(editHwnd, caretS, caretE)
				,sci.CONVERTEOLS(0)
				,SCI_ColorRadReport(sci, sr, 0)
	}
	else if(trim(text1)!="" && trim(text3)=""){

		SCI_SETTEXT(sci, tmp:=text1)
			,sci_.SetText(tmp:=text1)
			,Edit_getsel(RisReports[1,1],caretS,caretE)
			,Edit_SetSel(sci.hwnd,caretS,caretE)
			,Edit_SetSel(editHwnd_,caretS,caretE)
			,Edit_ScrollCaret(editHwnd)
			,sci.CONVERTEOLS(0)
			,SCI_ColorRadReport(sci, sr, 0)

	}else if !(text1==text3) && trim(text3)!="" {
		;~ if(text1!="")
		;~ clipboard:=text1
		AddHistory(text1)
		;~ ToolTip % "settext" A_TickCount
		;~ ToolTip % A_TickCount ":settext"
		controlsettext,,% text3,% "ahk_id " RisReports[1,1]
		Edit_getsel(editHwnd,caretS,caretE)
			,Edit_Setsel(RisReports[1,1],caretS,caretE)
			,Edit_ScrollCaret(RisReports[1,1])
	}else if (trim(text1)="" && trim(text3)!=""){
		sci_.SetText(t:=trim(text3))
			,SCI_SetText(sci, t:=trim(text3))
			,Edit_getsel(RisReports[1,1], caretS,caretE)
			,Edit_Setsel(editHwnds_, caretS,caretE)

	}
updateEnd:
	updating:=false
	settimer,updatingOff,Off
return

renewRis:
	RisState:=risopened()
	risAccHwnd:=getRisAccNoHwnd(RisState[2])
		,cAccNo:=ControlGetText(risAccHwnd)
		,RisReports:=getRisReports(RisState[2])
;~ ToolTip % RisState[2] "," cAccNo
return

renewRisReports:
	RisReports:=getRisReports(RisState[2])
		,risAccHwnd:=getRisAccNoHwnd(RisState[2])
	if debug
	FileAppend,% A_TickCount ": " ControlGetText(risAccHwnd) "`n" ,%SIMPLERIS_LOG_FILE%,utf-8-Raw
	if(ControlGetText(risAccHwnd)!="")
		cAccNo:=thisAccNo:=ControlGetText(risAccHwnd)
return
if(pOldReport!=(cOldReport:=ControlGetText(RisReports[2,1]))){
	oldReportChanged()
}
pOldReport:=cOldReport
;~ settimer,,-500
return

WM_MOUSEMOVE( wparam, lparam, msg, hwnd ){
	global guihwnd, guihwnd_
	if (wparam = 1){ ; LButton
		mousegetpos,,,,con
		if !instr(con,"Scintilla") && (hwnd=guihwnd || hwnd=guihwnd_)
			PostMessage, 0xA1, 2,,, A ;WM_NCLBUTTONDOWN
		else
			onmessage(0x200,"")
	}
	;~ if (hwnd=pr2hwnd || hwnd=pr1hwnd) {
	;~ if !WinActive("ahk_id " hwnd)
	;~ WinActivate,% "ahk_id " hwnd
	;~ }

}

activateImpax:
	mousegetpos,mx,my,mWin
	winget,mProcName,ProcessName,ahk_id %mWin%
	if (mProcName~=MatchPacsProcessName())
		winactivate,ahk_id %mWin%
return

activateGUI:
	mousegetpos,mx,my
	wingetpos,x,y,w,h,ahk_id %guihwnd_%
	if (mx>=x && mx<x+w && my>=y && my<y+h)
		winactivate,ahk_id %guihwnd_%
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
	if ((pName="simpleRIS.exe" || pName="simpleRIS_.exe" || (WinGetTitle(mouseWin)~="i)^simple RIS" && WinGetClass(mouseWin)="AutoHotkeyGUI") || mouseWin=guihwnd || mouseWin=guihwnd_ || mouseCon=RisReports[2,1] || mouseCon=RisReports[2,2]) && FocusedHWND!=mouseCon){
		WinActivate,% "ahk_id " mouseWin
		ControlFocus,,% "ahk_id " mouseCon
	}
return

#IfWinActive,ahk_group pacs

#IfWinActive

RisStateChange(){
	global
	if debug
		ToolTip % A_ThisFunc
	RisState:=risopened()
	DebugLog("simpleRIS.RisStateChange", "RisState=" RisState[1] " hwnd=" RisState[2])
}

accNoChanged(w=0,l=0,m=0,h=0){
	Critical
	global PauseUpdate, noUpdateMode, debug, guihwnd, guihwnd_, RisState

	if (WinExist("ahk_exe PacsIE.exe") || WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI"))
		return

	if (debug){
		if WinExist("ahk_id " h)
			FileAppend,% WinGetTitle(h) "," winget("processName", h) "`n",%SIMPLERIS_LOG_FILE%,utf-8-Raw
		ToolTip % A_ThisFunc
	}
	thisAccNo:=getRisAccNo(RisState[2])
	DebugLog("simpleRIS.accNoChanged", "getRisAccNo=" thisAccNo " RisState=" RisState[1] " hwnd=" RisState[2])
	if (thisAccNo="")
		return
	GuiControlGet,thisAccNoText,%guihwnd%:,thisAccNoText
	if(thisAccNo=thisAccNoText){
		; accNo unchanged — but if editor is empty and RIS has text (RS->4 late-load),
		; still run update1 so the report gets pulled in
		editorEmpty := (Trim(SCI_GETTEXT(sci)) = "")
		if !editorEmpty {
			DebugLog("simpleRIS.accNoChanged", "accNo unchanged=" thisAccNo " editor non-empty — skip")
			return
		}
		DebugLog("simpleRIS.accNoChanged", "accNo unchanged=" thisAccNo " but editor empty — scheduling update1 for RS->4 late-load")
		settimer,update1,-1
		return
	}
	if (thisAccNoText!="")
		simpleRIS_AutosaveCurrentReport(thisAccNoText, "before_acc_change")
	DebugLog("simpleRIS.accNoChanged", "accNo CHANGED: '" thisAccNoText "' -> '" thisAccNo "' noUpdateMode=" noUpdateMode " PauseUpdate=" PauseUpdate)
	settimer,SCI_ColorRadReport,Off

	; While synchronization is disabled, keep the old hidden accession attached to the
	; still-visible editor. ReactivateUpdateMode/update1 will revisit this mismatch later.
	; Relabeling now would let the timer save the old report under the new accession.
	if(noUpdateMode){
		DebugLog("simpleRIS.accNoChanged", "noUpdateMode=true — accession transition deferred")
		return
	}

	; resetEdit performs its own last-chance save. Keep the old accession in the
	; hidden field until after the editor has been saved and cleared; otherwise the
	; old report is written into the new study's recovery directory.
	DebugLog("simpleRIS.accNoChanged", "saving/resetting old editor before relabel + update1")
	gosub resetEdit
	guicontrol,%guihwnd%:,thisAccNoText,% thisAccNo
	gosub renewRisReports
	settimer,update1,-1
	if(!PauseUpdate){
		pauseUpdateMode(2000,1)
		PauseUpdate:=true
	}
}
ReportChanged(){
	Critical
	global noUpdateMode, debug
	settimer,renewRis,-1
	;~ ToolTip % "Report Changed"
	if debug
		ToolTip % A_ThisFunc
	if(!WinExist("ahk_exe PacsIE.exe") && !WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI"))
		noUpdateMode:=false
	else
		noUpdateMode:=true
}
oldReportChanged(){
	;~ ToolTip % "1:" A_TickCount
	global debug
	if debug
		ToolTip % A_ThisFunc
	if WinExist("ahk_exe PacsIE.exe") || WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
		return
	gosub renewRis

	;~ ToolTip % "Old report changed"
	;~ ToolTip % updatehxfirst
	;~ if(!noUpdateMode)
	;~ gosub updatehxfirst
	;~ else
	;~ gosub updatehx
}

;~ ^t::
;~ sci.getText(sci.GetTextLength()+3, text:="")
;~ ToolTip % "," text ","
;~ return

#IfWinActive,ahk_group simpleRISGUI
	^s::
		gosub update2
	return

	^#r::
		WinGetPos,x,y,w,h,ahk_id %guihwnd_%
		FileAppend,% x "," y "," w "," h,% path:=A_ScriptDir "\" a_now " simpleRIS pos",utf-8
		FileSetAttrib,+H,% path
		Reload
	return
#IfWinActive
;~ ^#l::
;~ ListLines
;~ return

resetReports(){
	global debug
	if debug
		ToolTip % A_ThisFunc
	RisReports:=getRisReports()
	if ((text:=ControlGetText(RisReports[1,1]))!="")
		AddHistory(text), resetRisReports("", RisReports)
	gosub resetEdit
}

activateSimpleRis(){
	global debug
	if debug
		ToolTip % A_ThisFunc
	gosub activateSimpleRis
}

#IfWinNotExist,ahk_exe Menu.exe
	!space::
		gosub activateSimpleRis
	return
#IfWinNotExist

exit(){
	gosub OnExit
}

checkMiniPacsForTransparentWin:
	if WinExist("ahk_exe miniPACS.exe") {
		;~ winset,trans,100,% "ahk_id " guihwnd
		winset,trans,100,% "ahk_id " guihwnd_
	}else{
		;~ winset,trans,200,% "ahk_id " guihwnd
		winset,trans,200,% "ahk_id " guihwnd_
		;~ winset,trans,Off,% "ahk-id " guihwnd
	}
return

overlaySimpleRis:
	IfWinActive,ahk_id %guihwnd%
		activateOverlaySimpleRis()
return

activateOverlaySimpleRis(){
	global guihwnd_, simpleRIS__pid, guihwnd, editHwnd_

	if (guihwnd_:=getSimpleRisGuiHwnds()[2]){
		;~ WinShow,ahk_id %guihwnd%
		WinGetPos,x,y,w,h,ahk_id %guihwnd%
		WinShow,ahk_id %guihwnd_%
		winactivate,ahk_id %guihwnd_%
		if !(x y w h = "")
			WinMove,ahk_id %guihwnd_%,,% x,% y,% w,% h
		ControlFocus,,% "ahk_id " editHwnd_:=getSimpleRisEditHwnds()[2]
	}else
		renewSecondSimpleRIS()
}

renewSecondSimpleRIS(){
	global guihwnd_, editHwnd_, sci_
	static guihwnd_2, editHwnd_2
	guihwnd_:=guihwnd,editHwnd_:=editHwnd,sci_:=sci
	return

	if !(WinExist("simpleRIS__main ahk_class AutoHotkeyGUI"))
		run, % A_ScriptDir "\..\AutoHotkey.exe simpleRIS_.ahk",A_ScriptDir
	winwait,simpleRIS__main ahk_class AutoHotkeyGUI,,5

	if (guihwnd_2:=getSimpleRisGuiHwnds()[2]) && (editHwnd_2:=getSimpleRisEditHwnds()[2]) {
		if(guihwnd_2!=guihwnd_) || (editHwnd_2!=editHwnd_) || (!sci_.hwnd) {
			if !controlexists(editHwnd_2){
				settimer, renewSecondSimpleRIS, -200
				return
			}
			guihwnd_:=guihwnd_2
				,edithwnd_:=editHwnd_2

			if WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
				sci_:=new FakeRemoteScintilla(editHwnd_)
			else
				;~ try
				sci_:=edithwnd_?new RemoteScintilla(editHwnd_):""
					, edithwnd_?Edit_getsel(editHwnd_, _, _):0
			;~ catch e {
			;~ MsgBox % e
			;~ sci_:=""
			;~ ,err:=true
			;~ }

			if !(WinExist("ahk_id " guihwnd_ " ahk_group MyGui")){
				groupadd,MyGui,ahk_id %guihwnd_%
			}
			if !(WinExist("ahk_id " guihwnd_ " ahk_group mainGui")){
				groupadd,mainGui,ahk_id %guihwnd_%
			}
		}
		settimer,renewSecondSimpleRIS,% err?-1000:-5000
		settimer,overlaySimpleRis,300
	}else{
		sci_:=""
			,guihwnd_:=editHwnd_:=0
		settimer,renewSecondSimpleRIS,-1000
		settimer,overlaySimpleRis,-2000
	}

	return
}

listLines(){
	ListLines,on
}

debugHandle:

	If h:=WinExist("Handle is NULL","buffer")
	{
		ListLines,on
	}
	IfWinExist,OpenProcess Failed,Unable
		ListLines,on
return

changeEdit(){
	renewSecondSimpleRIS()
}

setupHxDir:
	hxDir:=A_ScriptDir "\simpleRIS_hx"
	FileCreateDir,% hxDir
	savedHx:=[]
	thisDate:=A_YYYY a_mm a_dd
	Loop,files,% hxDir "\*.txt"
		if InStr(A_LoopFileName, thisDate)=1
			savedHx[SubStr(A_LoopFileName,1,-4)]:=FileRead(A_LoopFileLongPath)
		else
			FileDelete,% A_LoopFileLongPath
	savedHxOrder:=[]
	for k_,v_ in savedHx
		history.push(v_)
			,historyInd++
return

adjustFontSize:
	lineCount:=sci.GetLineCount()
	textCount:=sci.GetLength()
	;~ ToolTip % textCount
	if WinExist("YCH_XR_main ahk_class AutoHotkeyGUI"){
		if(lineCount>=6 || textCount>280)
			newFontSize:=Fontsize*4//9
		else if(lineCount>=3 || textCount>140)
			newFontsize:=Fontsize*3//5
		else
			newFontsize:=Fontsize
	}else{
		newFontsize:=Fontsize
	}
	if(sci.StyleGetSize(SCLEX_CONTAINER)!=newFontsize){
		sci.StyleSetSize(SCLEX_CONTAINER, newFontsize)
			,sci.StyleSetSize(STYLE_DEFAULT, newFontsize)
			,sci.StyleSetSize(SCE_AHKL_USERDEFINED1, newFontsize-1)
	}
return

focusImpressionFn(){
	gosub focusImpression
}
