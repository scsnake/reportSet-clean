#MaxMem 4095
#NoEnv
#SingleInstance,force
#MaxHotkeysPerInterval,999999
#UseHook
process,Priority,,h
SetBatchLines,-1
DetectHiddenWindows, On
SetTitleMatchMode,2
coordmode,mouse,screen

SetTitleMatchMode 2
SetTitleMatchMode fast
SetBatchLines, -1
SetKeyDelay, -1, -1, -1
SetMouseDelay, -1
SetWinDelay, -1
SetControlDelay, -1
SetDefaultMouseSpeed, 0

#NoTrayIcon
#include <acc>
#include <wb>
#include <.netgetcontrol>
#include <INFINITT_PACS>
#include <risimpax>
#include <portallib>
#include <cmdWindow>
;~ #include <hotstring>
#include <SystemCursor>
#include <hash>
#include <WinVisible>
;~ #include <ahkmini>
;~ #include <ahkthread>
;~ #include <createscript>
;~ #include <getDllPath>
#include <JoinScript>
#include <RegJump>
;~ #include <UIAutomationServer>
;~ #Include <ComDispatch>
;~ #Include <ComDispTable>
;~ #Include <ComVar>
;~ #Include <SetTimerF>
#Include <RelToAbs>
#Include <GetActiveBrowserURL>
#Include <dcm4che>
;~ #Include <Array_DeepClone>
#Include <SetWindowsHookEx>
#include <OnScreenDisplay>
#include <Crypt>
#include <ParseArg>
#include <CryptFileRead>
#include <DateRange>
#include <ebmViewer>
#include <resetHotstringBuffer>
#include <ReportAnalysis>
#include <WinHook>
#include <CH_RIS_Server>   ; single-owner CH_RIS IPC bridge (owner side)
#include <HH_Announce>       ; persistent Hotstring Helper notifier (Win+N path)
#include <IsCurrentSessionRDP>
#InstallKeybdHook

;~ settimer,test,10
global thisPlace:=getPlace()
; Session-only G3PACS workaround state. Rerunning Autorun.exe resets every value.
global g_G3PacsAutoForcedLoadMode:=false
global g_G3PacsForcedLoadStreak:=0
global g_G3PacsStudySequence:=0
global g_G3PacsHasLastForcedSequence:=false
global g_G3PacsLastForcedSequence:=0
global g_G3PacsLastForcedStudyKey:=""
global g_G3PacsStudyChangeHook:=""
global g_G3PacsStudyChangeHookRegistered:=false
global g_G3PacsAutoLastScheduledStudyKey:=""
global g_G3PacsAutoPromptPending:=false
; autorun is the project's init point and stays resident, so it hosts the single
; CH_RIS IPC owner. Exactly ONE process should do this; other CH scripts talk to
; it through Lib\CH_RIS_Client.ahk instead of polling IE themselves.
if InStr(thisPlace, "C hospital")
	CH_RIS_Server_Start()
TaskKill("AllKill.exe")
isDebug:=isDebug()
DebugLogStartCleanupTimer(7)   ; prune logs\debug_*.log older than 1 week, checked daily
;~ #include <JSON>
ComObjError(false)
onexit,onexit
thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))
OnMessage(0x2033, "simpleRisCapsOverride")
KillReportSetProcs(thisPid)
RefreshTrayIcons()
gosub resetState
;~ args:=[]
;~ Loop %0%
	;~ args.push(%a_index%)

;~ v:=""
;~ for k,v in args
	;~ if(v~="i)autorun.(exe|ahk)")
		;~ continue
	;~ else
		;~ break
args:=ParseArg()
,RisImpaxDecodePw:=args[1]
;~ MsgBox % exploreobj(args) "`n" v

;~ gosub closeOtherAHK



if regexmatch(a_scriptdir,"is)(.+?)\\scripts\\Autorun$",match){
	root:=match1, partialMode:=false, ahkMain:=root "\scripts\Autorun\AutoHotkey.exe"
	
	Run, % ahkMain " " root "\scripts\Autorun\killUpdate.ahk",,hide
	
}else{
	root:=a_scriptdir, partialMode:=true, ahkMain:=root "\AutoHotkey.exe"
	
}
ToolTip % "Press Ctrl or Alt to exit all!"
Sleep 400
if (GetKeyState("Ctrl") && GetKeyState("Alt")){
	ToolTip % "Exiting..."
	goto terminateUSBprocess1
	return
}
ToolTip
if CryptFilePW()
	ExitApp
if (partialMode){
	if !FileExist("AutoHotkey.exe") || GetKeyState("Shift") || !fileexist("killUpdate.exe"){
		if !FileExist("AutoHotkey.exe")
			filecopy,autorun.exe,AutoHotkey.exe,1
		gosub copyMainExe
	}else{
		settimer,copyMainExe,-10000
	}
		
	;~ Run, % A_ScriptDir "\killUpdate.exe",,hide
	RunKeepFocus(A_ScriptDir "\killUpdate.exe", "", "hide")
	IfWinExist,開啟檔案 ahk_class #32770,% A_ScriptDir
		ControlClick,Button1,開啟檔案 ahk_class #32770,% A_ScriptDir
	IfWinExist,Symantec Endpoint Protection ahk_class #32770
	{
		ControlGetText,t,Static7,Symantec Endpoint Protection ahk_class #32770
		if (t="killUpdate")
			ControlClick,Button2,Symantec Endpoint Protection ahk_class #32770
	}
}

;~ #WarnContinuableException,off
sendmode input
;~ threadIds:=CriticalObject()
;~ updateLibPath()
;~ settimer,testpoll,200

command_hx:=[]
dllPath:=getDllPath()
,AllThreads:=[]
,reportDir:=a_mydocuments "\feedRIS"
if !isDebug && __is_N
	RisImpaxLoginInfo:=RisImpaxLoadPw(RisImpaxDecodePw)
startup_tickcount:=A_TickCount
IMPAX_id:=RisImpaxLoginInfo.Impax.1.user
,IMPAX_pw:=RisImpaxLoginInfo.Impax.1.pw
,RIS_id:=RisImpaxLoginInfo.Ris.1.user
,RIS_pw:=RisImpaxLoginInfo.Ris.1.pw
,askForPortalIdPw(0,0)
,IMPAX_title:="IMPAX 6.5.2.114 Radiologist with QC"
,RisName:="陳醫師"
,imageWinToggle:=1
,scrollImageConst:=0
,scrolling:=0,scrollingFreq:=100
,mouseHooks:=[]
,monitors:=monitorInfo()

if InStr(thisPlace, "N hospital")
	RISImpaxRegister([  {app: "Ris", type: "State", hwnd: thisHwnd, msg: {msg: 0x8000}, func: "RisStateChange", initStart: 1}
		, {app: "Ris", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x1122}, func: "accNoChanged", initStart: 100}
		, {app: "Impax", type: "State", hwnd: thisHwnd, msg: {msg: 0x8001}, func: "ImpaxStateChange", initStart: 1}])
mouseDragUtil:=1
,onmessage(0x10103,"mouseDragUtilInact")
,onmessage(0x10104,"focusImpression")
,onmessage(0x10105,"delayLockScreenOnTop")
,resetHotstringBufferHook()
,RisState:=risopened()
,ImpaxState:=ImpaxOpened()
;~ ,onmessage(0x1122,"accNoChanged")
;~ ,onmessage(0x8000,"risStateChange")
;~ ,onmessage(0x8001,"impaxStateChange")
;~ ,onmessage(0x8100,"lungCADResult")
,openedWindows:=[]
,hiddenWindows:=[]
,autofocus=1
,breakLineControls:=["txtALL","INDICATION","ALLERGY","HEALTHY_VOLUNTEER","DIAGNOSTIC","SPECIAL_MEDICAL","SYMPTOM"]
;~ ,mouseHooks.push(SetWindowsHookEx(WH_MOUSE_LL   := 14, RegisterCallback("MouseHook", "Fast")))
;~ ,ahkMain:= root "\scripts\Autohotkey\AutoHotkey" (A_Is64bitOS?"U64":"") ".exe"


;~ ,RisStateChange(), impaxStateChange(), accNoChanged()


sysget,monitorCount,monitorcount
;~ if (monitorcount>1){
	sysget,firstMonitor,monitor,% monitors.1.ind
	sysget,lastMonitor,monitor,% monitors[monitors.maxindex()].ind
	;~ settimer,cyclicMonitor,-1
;~ }

if(monitorcount=1 && __is_CH){
	WinHook.Shell.Add("WinShellHook",,, "iexplore.exe",1) 
}
if(__is_CH) {
	WinHook.Shell.Add("WinShellHook",,,,2)
	SetTimer, TrackRisReportIETimer, 1000
	SetTimer, TrackRisReportIETimer, -1
}


gui,new,+lastfound +toolwindow +AlwaysOnTop
winget,guiHWND,id
;~ wingettitle,a,ahk_id %thisHwnd%
;~ wingettitle,b,ahk_id %guiHwnd%
;~ msgbox % a "," b
gui,add,edit,vcommands,
gui,add,button,gterminateUSBprocess,% partialMode?"Leave":"Unmount USB"
gui,add,button,gexe yp x+5,Execute

gui,show,autosize,Enter command ...



settimer,task,-1
settimer,setNotOnTop,-3000

if InStr(A_OSVersion, "10.")
	settimer,EverythingSearchEngineHotkey,-1

GroupAdd,pycharm,ahk_exe pycharm64.exe
GroupAdd,pycharm,ahk_exe pycharm32.exe
GroupAdd,pycharm,ahk_exe pycharm.exe

settimer,autolock,60000

gui,hidden:+hwndhiddenguihwnd
WinSetTitle,% "ahk_id " hiddenguihwnd,,% "scsnake_autorun_main"
gosub removeOrphan
settimer,removeOrphan,60000
; Keep the CT/MR Horos bridge alive with the persistent CH_RIS owner. Modality
; filtering happens inside RisHorosSync, so other YCH variants do not tear it down.
; Start locally too: the idle bridge must be present to receive an RDP reconnect.
if InStr(thisPlace, "C hospital")
	SetTimer, StartRisHorosSync, -1

test:
winget,ProcessName,ProcessName,A
if (__lastActive="" || __lastActive!=ProcessName)
	clipboard.=ProcessName "`n", __lastActive:=ProcessName
return

StartRisHorosSync:
	risHorosScript := A_ScriptDir "\CH scripts\RisHorosSync.ahk"
	; An existing bridge handles its own reconnect. Do not replace it and lose its
	; sync toggle / pending prompt when connect, logon and unlock arrive together.
	if (FileExist(risHorosScript) && !WinExist(risHorosScript " ahk_class AutoHotkey"))
		Run, % """" A_ScriptDir "\AutoHotkey.exe"" """ risHorosScript """", % A_ScriptDir "\CH scripts", Hide
return

removeOrphan:
NoTrayOrphans()
return

EverythingSearchEngineHotkey:
hotkey,~!#f,EverythingSearchEngineHotkeysend
return
EverythingSearchEngineHotkeysend:
send !{AppsKey}
return

^+c::Explorer_GetSelected_CopyPath()

Explorer_GetSelected_CopyPath() {
    hwnd := WinExist("A")
    WinGetClass, class, ahk_id %hwnd%
    if !(class ~= "(CabinetWClass|Progman|WorkerW)")
        return
    shell := ComObjCreate("Shell.Application")
    paths := ""
    for window in shell.Windows {
        if (window.hwnd == hwnd) {
            sel := window.Document.SelectedItems
            for item in sel {
                paths .= (paths ? "`r`n" : "") . item.path
            }
            break
        }
    }
    if (paths) {
        Clipboard := paths
        ToolTip, % "Copied " sel.Count " path(s)"
        SetTimer, RemoveToolTip_CopyPath, -1000
    }
    return
}

RemoveToolTip_CopyPath:
    ToolTip
return

resetState:
keys=LButton|RButton|MButton|RCtrl|LCtrl|Alt|LWin|RWin|Shift
Loop,Parse,keys,|
	if GetKeyState(A_LoopField)
		send {%a_loopfiled% up}
keys=abcdefghijklmnopqrstuvwxyz1234567890-=[]\;',./``
Loop,Parse,keys,
	if GetKeyState(A_LoopField)
		send {%a_loopfiled% up}
Loop 12
	if GetKeyState(A_LoopField)
		send {F%A_Index% up}
if GetKeyState("CapsLock")
	SetCapsLockState,Off
if !GetKeyState("NumLock")
	SetNumLockState,On
if GetKeyState("ScrollLock")
	SetScrollLockState,Off
return



setNotOnTop:
winset,AlwaysOnTop,Off,ahk_id %guiHWND%
winactivate,ahk_id %guiHWND%
return

testpoll:
ToolTip % RisState[2] "," thisAccNo
return

;~ t::
;~ ahkthread("msgbox zxcv")
;~ return 
;~ r::
;~ Reload
;~ return

task:
threads:=[]
if InStr(thisPlace, "N hospital")
settimer, impaxContextServer,-20000
;~ settimer, UIAutomationServer,-3000
gosub commandArr
gosub RisGroup
gosub PacsGroup
;~ settimer,openAnotherRis,-60000
;~ SetTimer,impaxError,-1000

settimer,closeImpaxBridge,-1
setTimer,noIdle,540000
settimer,sciteSession,-1000
settimer,decryptKey,-1000
settimer,createNotifyGui,-1

;~ gosub RisImpaxRoutine
;~ settimer,OpenAnotherRisRoutine,-1

;~ ahkmini("msgbox")
if fileexist("AutoHotkey.dll")
	ahkdll := DllCall("LoadLibrary", "str", "AutoHotkey.dll")


if InStr(thisPlace, "C hospital"){
	settimer,autoActivateInfinitt,-300
	WinSessionChange(true)
	run, % ahkMain " """ root "\CH scripts\MovePacsRight.ahk""",,hide
}

if(!partialMode){
;~ try {
	
	run, % ahkMain " " root "\scripts\Radiology\textHotkey\textHotkey.ahk",,hide
	run, % ahkMain " " root "\scripts\Radiology\MouseKeyRemap\capslock_remap_alt.ahk",,hide
	run, % ahkMain " " root "\scripts\Radiology\RisHelper\AutoNum.ahk",,hide
	;~ run, % ahkMain " " root "\scripts\Autorun\RisListQuickSearch.ahk",,hide
	if __is_N
	run, % ahkMain " " root "\scripts\Autorun\RazerNaga.ahk",,hide
	if __is_N
	run, % ahkMain " " root "\scripts\Autorun\ImpaxSeriesList.ahk",,hide
	run, % ahkMain " " root "\scripts\Autorun\hotstringReset.ahk",,hide

	;~ run % ahkMain " " root "\scripts\Autorun\AltGrabWin.ahk"
	;~ run % ahkMain " " root "\scripts\ImprovedShowDesktop.ahk"
	run, % root "\scripts\Radiology\showLungCAD\showLungCAD.exe",,hide
	if __is_N
	run, % root "\scripts\alarm\alarm.exe",,hide
	;~ run % root "\scripts\Radiology\TextHotkey\TextHotkey.exe"
	;~ run % root "\scripts\Radiology\MouseKeyRemap\capslock_remap_alt.exe"
	;~ run % root "\scripts\Radiology\RisHelper\AutoNum.exe"
	;~ run % root "\scripts\Autorun\RazerNaga.exe"
	;~ }

}else{
	
if (0){
	if __is_N
		script=
		(LTrim %
		for k,v in ["mainHotkey.exe", "textHotkey.exe", "capslock_remap_alt.exe", "AutoNum.exe", "RazerNaga.exe", "showLungCAD.exe"
			, "ImpaxSeriesList.exe", "hotstringReset.exe", "alarm.exe", "GEUVhelper\GEUVhelper.exe"]
			try
				;~ run, % A_ScriptDir "\" v,,hide
				RunKeepFocus(A_ScriptDir "\" v, "", "hide")
		)
	else if __is_CH
		script=
		(LTrim %
		for k,v in ["mainHotkey.exe", "textHotkey.exe", "capslock_remap_alt.exe", "AutoNum.exe", "RazerNaga.exe", "hotstringReset.exe", "alarm.exe"]
			try
				;~ run, % A_ScriptDir "\" v,,hide
				RunKeepFocus(A_ScriptDir "\" v, "", "hide")
		)
	
	DllCall("AutoHotkey\ahktextdll", "str", "
	(LTrim %
	SetBatchLines,-1
	#NoEnv
	try{
		" script "
	}catch e
		msgbox % e
	finally
		exitapp
	)", "str", "1234567", "Cdecl Int")
	
}else {
	if __is_N
		for k,v in ["mainHotkey.exe", "textHotkey.exe", "capslock_remap_alt.exe", "AutoNum.exe", "RazerNaga.exe", "showLungCAD.exe", "RisListQuickSearch.exe"
			, "ImpaxSeriesList.exe", "hotstringReset.exe", "alarm.exe"]
			try
				RunKeepFocus(A_ScriptDir "\" v, "", "hide")
	else if __is_CH
		for k,v in ["mainHotkey.exe", "textHotkey.exe", "capslock_remap_alt.exe", "AutoNum.exe", "hotstringReset.exe"]
			try
				RunKeepFocus(A_ScriptDir "\" v, "", "hide")
}
settimer,delayRun,-5000
}
return


delayRun:
for k,v in ["win10hook.exe"]
	try 
		;~ run,% A_ScriptDir "\" v,,hide
		RunKeepFocus(A_ScriptDir "\" v, "", "hide")
return

;~ !#^+p::
;~ printThreadsInfo:
;~ clipboard:=str:=""
;~ for k,v in threads
	;~ str.=k ": " v.ahkgetvar("alive") "`n"
;~ MsgBox % clipboard:=str
;~ return

copyMainExe:
path:=""
if FileExist(path:=A_ScriptDir "\AutoHotkey.exe"){
}else if FileExist(path:=A_ScriptDir "\" RegExReplace(A_ScriptName, ".ahk", ".exe")){
}
if(path=""){
	showTooltip("Can't not copy AutoHotkey.exe!!")
	return
}

;~ try
ahkPaths:=[]
Loop, Files,% a_scriptdir "\*",FD
{
	if (A_LoopFileLongPath~="i)\\(Lib|\.git)")
		continue
	else if InStr(FileExist(A_LoopFileLongPath),"D") {
		Loop,files,% A_LoopFileLongPath "\*.ahk",F
			ahkPaths.push(A_LoopFileLongPath)
	}else if (A_LoopFileName~="i).ahk$")
		ahkPaths.push(A_LoopFileLongPath)
}
;~ clipboard:=exploreobj(ahkPaths)
A_ScriptDir_len:=StrLen(A_ScriptDir)
for k,ahkPath in ahkPaths {
	
	SplitPath,ahkPath,fileName,fileDir,ext,filenameNoExt
	
	if (fileDir~="i)\\(Lib|\.git)")
		continue

	;~ if InStr(FileExist(A_LoopFileLongPath), "D") && (A_LoopFileLongPath!=A_ScriptDir "\Lib"){
		;~ FileCreateShortcut,% A_ScriptDir "\Lib",% A_LoopFileLongPath "\Lib.lnk"
	;~ }else if (ext="ahk"){
	;~ if (ext="ahk"){
	
	
		if !FileExist(fileDir "\Lib.lnk") && !InStr(FileExist(fileDir "\Lib"), "D") && !InStr(fileDir, A_ScriptDir "\Lib")  && (fileDir!=A_ScriptDir) 
			;~ FileCreateShortcut,% A_ScriptDir "\Lib",% fileDir "\Lib.lnk"
			;~ run,% ComSpec " /c """ commands("mklink","/j", fileDir "\Lib", A_ScriptDir "\Lib") """",,hide
			;~ run,% ComSpec " /c """ commands("mklink","/j", fileDir "\Lib", RegExReplace(SubStr(fileDir,A_ScriptDir_len+2), "[^\\\/]+", "..") "\Lib") """",,hide
			run,% ComSpec " /c """ commands("mklink","/j","Lib", RegExReplace(SubStr(fileDir,A_ScriptDir_len+2), "[^\\\/]+", "..") "\Lib") """",% fileDir,hide
;clipboard.=fileDir "\Lib`n" 
		
		if (fileName="autorun.ahk")
			continue
		
		;~ MsgBox % filenameNoExt
		if !FileExist(target:=fileDir "\" filenameNoExt ".exe") && !(InStr(fileDir, "Hotstring Helper") && !(filenameNoExt~="i)Hotstring Helper|HotstringHint"))
			FileCopy,% path,% target,1
			;~ run,% ComSpec " /c """ commands("mklink","/h",filenameNoExt ".exe", (fileDir=A_ScriptDir ? "" : RegExReplace(SubStr(fileDir,A_ScriptDir_len+2) "\", "[^\\]+\\", "..\")) "AutoHotkey.exe") """",% fileDir,hide
		;~ MsgBox % fileDir "\" filenameNoExt ".exe"
	;~ }
}
return

closeImpaxBridge:
process,close,AgfaDTIWatchDog.exe
WinKill, ahk_exe AgfaDTIWatchDog.exe
process,close,AgfaDTIBridge.exe
WinKill,ahk_exe AgfaDTIBridge.exe
return

impaxError:
IfWinExist,發生錯誤 ahk_exe impax-client-main.exe
{
	WinClose
	Loop {
		Sleep 400
		process,close,impax-client-main.exe
		WinKill,ahk_exe impax-client-main.exe
	}until (!ErrorLevel) || (A_Index>10)
	SetTimer,login_impax,-1
}
SetTimer,impaxError,-1000
return

decryptKey:
if(RisImpaxDecodePw="")
	return
decryptKeyFiles:=[A_MyDocuments "\XRAY127_MAGIC"
	, A_MyDocuments "\XRAY127_MAGIC2"
	, A_MyDocuments "\XRAY127_RTX"
	, A_ScriptDir "\XRAY127_MAGIC"
	,  A_ScriptDir "\XRAY127_MAGIC2"
	,  A_ScriptDir "\XRAY127_RTX"]
for _, key_files in decryptKeyFiles {
	if FileExist(key_files ".enc"){
		Crypt.Encrypt.FileDecrypt(key_files ".enc", key_files, RisImpaxDecodePw, 7, 1)
			;~ FileDelete,% key_files ".enc"
	}		
}
return
sciteSession:
fileread,sciteSession,% root "\scripts\Autohotkey\SciTE\user\SciTE.session"
newSciteSession:=RegExReplace(sciteSession, "i)path=\w+:", "path=" root)
if(sciteSession!=newSciteSession){
	FileDelete,% root "\scripts\Autohotkey\SciTE\user\SciTE.session"
	FileAppend,% newSciteSession,% root "\scripts\Autohotkey\SciTE\user\SciTE.session",utf-8
}
return

createNotifyGUI:
try
	;~ run,% A_ScriptDir "\notifyGUI.exe",,hide
	RunKeepFocus(A_ScriptDir "\notifyGUI.exe", "", "hide")
;~ return ;pauseThread
;~ notifyTh:=ahkthread("
;~ (
;~ threadIds:=CriticalObject(" (&ThreadIds) "), threadIds[""notify""]:=DllCall(""GetCurrentThreadId""), clipboard.=""notify "" DllCall(""GetCurrentThreadId"") ""``n""
;~ #persistent
;~ #notrayicon
;~ setbatchlines,-1
;~ frame:=newX:=newY:=0
;~ alive:=1
;~ Loop, 4
;~ {
	;~ Gui, notify`%A_Index`%: -Caption +ToolWindow +AlwaysOnTOp
	;~ Gui, notify`%A_Index`%: Color, white
;~ }
;~ return
;~ show:
;~ if(!frame || frame="""")
	;~ frame:=400
;~ if(!newX || !newY){
	;~ mousegetpos,newX,newY
;~ }
;~ if (frame<20){
	;~ settimer,show,off
	;~ settimer,hide,-1
	;~ return
;~ }
;~ cornerX1:=floor(newX-frame/2),cornerY1:=floor(newY-frame/2)
;~ ,cornerX2:=floor(newX+frame/2),cornerY2:=floor(newY+frame/2)
;~ Gui, notify1: Show, `% ""x"" cornerX1 "" y"" cornerY1 "" w"" frame "" h2 NoActivate""
;~ Gui, notify4: Show, `% ""x"" cornerX1 "" y"" cornerY2 "" w"" frame "" h2 NoActivate""
;~ Gui, notify2: Show, `% ""x"" cornerX1 "" y"" cornerY1 "" w2 h"" frame "" NoActivate""
;~ Gui, notify3: Show, `% ""x"" cornerX2 "" y"" cornerY1 "" w2 h"" frame "" NoActivate""
;~ frame:=floor(frame/2)
;~ settimer,show,-50
;~ return
;~ hide:
;~ loop 4
	;~ gui, notify`%a_index`%:hide
;~ frame:=newX:=newY:=0
;~ return
;~ )")
;~ AllThreads.push(notifyTh)
;~ threads["notify"]:=notifyTh
;~ while !notifyTh.ahkReady()
	;~ Sleep 200
return

show:
;~ notifyTh.ahkAssign("frame", frame)
;~ ,notifyTh.ahkAssign("newX", newX)
;~ ,notifyTh.ahkAssign("newY", newY)
;~ ,notifyTh.ahkLabel("show")
Send_WM_COPYDATA(WinExist("notifyGUI_main ahk_class AutoHotkeyGUI"), 19
	, jxon_dump({show: 1, frame: frame, newX: newX, newY: newY}))


return


hide:
;~ notifyTh.ahkLabel("hide")
Send_WM_COPYDATA(WinExist("notifyGUI_main ahk_class AutoHotkeyGUI"), 19
	, jxon_dump({hide: 1}))

return

mouseDragUtilInact(wParam, lParam, msg, hwnd){
	global 
	mouseDragUtil:=0
	mammoAhkHwnd:=hwnd
	settimer,mouseDragUtilAct,5000
	return
}
mouseDragUtilAct:
;~ tooltip % winexist("ahk_id " mammoAhkHwnd)
if winexist("ahk_id " mammoAhkHwnd)
	return
settimer,mouseDragUtilAct,off
mouseDragUtil:=1
mammoAhkHwnd:=0
return
RisGroup:
groupadd,RisGroup,放射線資訊管理系統(Radiology Information System)
groupadd,RisGroup,simple RIS ahk_class AutoHotkeyGUI
return
PacsGroup:
GroupAdd,pacs,ahk_exe impax-client-main.exe
GroupAdd,pacs,ahk_exe WEBVIE~1.exe
GroupAdd,pacs,ahk_exe WebViewerComSrvEC.exe
GroupAdd,pacs,ahk_exe Miv2Lib.exe
GroupAdd,pacs,ahk_exe G3PACS.exe

GroupAdd,ebm,ahk_exe WEBVIE~1.exe
GroupAdd,ebm,ahk_exe WebViewerComSrvEC.exe
return


#IfWinActive,ahk_group ebm
2::
3::
4::
MouseGetPos,,,,con
if !InStr(con, "TPanel"){
	send % a_thishotkey 
	return
}
from:="EBM"
gosub MoveFromSeriesList

return
#IfWinActive


RefreshTrayIcons() {
    ; Send WM_SIZE to the tray notification area to flush ghost icons
    PostMessage, 0x0005, 0, 0,, ahk_class Shell_TrayWnd
    PostMessage, 0x0005, 0, 0,, ahk_class NotifyIconOverflowWindow
    ; Resize trick: nudge TrayNotifyWnd by 1px and back
    ControlGetPos, , , W, H, TrayNotifyWnd1, ahk_class Shell_TrayWnd
    ControlMove, TrayNotifyWnd1,,,, W+1, H, ahk_class Shell_TrayWnd
    ControlMove, TrayNotifyWnd1,,,, W,   H, ahk_class Shell_TrayWnd
}

KillReportSetProcs(myPid) {
    static base := "C:\Users\raduser\Documents\reportSet"
    for proc in ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId,ExecutablePath,CommandLine FROM Win32_Process") {
        if (proc.ProcessId = myPid)
            continue
        path := "" proc.ExecutablePath
        cmd  := "" proc.CommandLine
        if (InStr(path, base) = 1 || InStr(cmd, base))
            Process, Close, % proc.ProcessId
    }
}

closeOtherAHK:
;~ return ;pauseThread
;~ closeOtherTh:=ahkmini("
;~ (
;~ threadIds:=CriticalObject(" (&ThreadIds) "), threadIds[""closeOtherAhk""]:=DllCall(""GetCurrentThreadId""), clipboard.=""closeOtherAhk "" DllCall(""GetCurrentThreadId"") ""``n""
;~ #notrayicon
;~ DetectHiddenWindows,on
;~ Alias(thisPid, " getvar(thisPid) ")
;~ ,alive:=1
;~ for process in ComObjGet(""winmgmts:"").ExecQuery(""Select * from Win32_Process where name = 'AutoHotkey.exe' or name = 'AutoHotkeyU64.exe' and processID  <> "" thisPid )
   ;~ winclose,`% ""ahk_pid "" process.ProcessId
;~ winclose,ahk_exe capslock_remap_alt.exe
;~ winclose,ahk_exe textHotkey.exe
;~ winclose,ahk_exe AutoNum.exe
;~ winclose,ahk_exe RazerNaga.exe
;~ ExitApp
;~ )")
;~ threads["closeOther"]:=closeOtherTh
;~ AllThreads.push(closeOtherTh)
return



cyclicMonitor:

return
~^!z::
if !(a_priorhotkey=a_thishotkey && A_TimeSincePriorHotkey<300)
	return
tooltip,% "Autofocus " ((autofocus:=!autofocus)?"":"de") "activated!"
sleep 1000
tooltip
return



RisChanged:
if(RisChanged){
	;~ ToolTip % A_TickCount
	SetTimer,accNoRoutine,-1000
	RisChanged:=false
}
;~ HIMC:=DllCall("Imm32.dll\ImmAssociateContext","Ptr", risState[2], "Ptr", 0)
return

accNoRoutine:
;~ return
;~ if !WinExist("ahk_id " risAccHwnd) && !(risAccHwnd:=getRisAccNoHwnd(risState[2]))
	;~ SetTimer,accNoRoutine,-1000
;~ else if (!(pRisAcc)) || (pRisAcc!=(risAcc:=ControlGetText(risAccHwnd))){
	;~ SetTimer,risAccChanged,-1
	;~ pRisAccHwnd:=risAccHwnd
	;~ SetTimer,accNoRoutine,-1000
;~ }
;~ if WinExist("ahk_id " risAccHwnd) || (risAccHwnd:=getRisAccNoHwnd(risState[2])) {
	;~ if (!pRisAccHwnd){
		;~ SetTimer,risAccChanged,-500
		;~ cmdUIAutomationServer(risAccHwnd,1,0x1122,0,thisHwnd)
	;~ }else if (pRisAccHwnd!=risAccHwnd){
		;~ cmdUIAutomationServer(risAccHwnd,1,0x1122,0,thisHwnd)
	;~ }
	;~ pRisAccHwnd:=risAccHwnd
;~ }
;~ SetTimer,accNoRoutine,-1000
return

RisStateChange(){
	global
	RisState:=RisOpened()
}

impaxStateChange(){
	global 
	;~ ToolTip impaxStateChange
	ImpaxStateNew:=ImpaxOpened()
	
	if ImpaxState[2,1]!=ImpaxStateNew[2,1] 
		settimer,reopenImpaxContextServer,-2000
	;~ ToolTip % impaxstate[2,1] "," ImpaxStateNew[2,1]
	
	ImpaxState:=ImpaxStateNew
}

accNoChanged(){
	global
	RisReports:=getRisReports(RisState[2])
	SetTimer,risAccChanged,-500
}
risAccChanged:
thisAccNo:=getRisAccNo(RisState[2])
;~ settimer,RisHistoryBreakline,-1
return


autofocus:
if !autofocus
	return
mousegetpos,x,y,mouseWin
if(priorX<a_screenwidth&&x>a_screenwidth) && !winexist("匯出影像 ahk_class WindowsForms10.Window.8.app.0.2bf8098"){
	winactivate,% "ahk_id " mouseWin
}else if (priorX>a_screenwidth&&x<a_screenwidth) {
	wingetclass,mouseWinClass,ahk_id %mouseWin%
	if instr(mouseWinClass,"WindowsForms10.Window.8.app") && risState[2]!=mouseWin
		return
	if mouseWinClass not in Chrome_WidgetWin_1,AutoHotkeyGUI,#32770,IEFrame,SciTEWindow,MozillaWindowClass,SleipnirMainWindow
	{
		winactivate,% "ahk_id " risState[2]
	}
}
priorX:=x
return
checkActivateImpax:
loop 15 {
	if !winactive("ahk_class WindowsForms10.Window.8.app.0.2bf8098"){
		winactivate,% "ahk_id " reActivate
		break
	}
	sleep 200
}
return
AppsKey:
if ImpaxState[1]!=2
	return
winget,list,list,ahk_class WindowsForms10.Window.8.app.0.2bf8098
loop % list {
	for k,v in getControls(list%a_index%)
	if (instr(v.text,"BMP_SERIES_MODE") && instr(v.classNN,"WindowsForms10.BUTTON.app")) {
		loc:=Acc_Location(acc_objectfromwindow(v.hwnd))
		winget,id,id,A
		mousegetpos,x,y
		mouseclick,l,% loc.x+1,% loc.y+1,1,0
		winactivate,% id
		mousemove,% x,% y,0
		break
	}
}
return
noIdle:
for k,__v in RisOpened(1)[2]
	if winvisible(__v)
		RisNoIdle(__v)
return


lockSub:
if instr(a_thishotkey,"enter") {
	guicontrol,lock:,unlockPW,% ""
}else{
	mousegetpos,mx,my
	if(mx>a_screenwidth/2 && my>a_screenheight/2){
		gui,lock:submit,nohide
		if(unlockPW="1001")
			goto unlock
		++unlockRL
	}else if(mx<a_screenwidth/2 && my<a_screenheight/2){
		++unlockLU
	}else{
		unlockRL:=unlockLU:=0
	}
	;~ ToolTip % "RL: " unlockRL "`nLU: " unlockLU
	if(unlockRL=3 && unlockLU=1){
		goto unlock
	}
}
return

delayLockScreenOnTop(){
	global 
	lockScreenPauseTick:=A_TickCount
}

^!k::
lockScreen:
;~ hotkey,^!+z,unlockSub
if instr(thisPlace, "C hospital")
	return

gui,lock:new

;~ SetTimer,setlockhotkey,-60000
gui,lock: +toolwindow -caption +alwaysontop +hwndlockHwnd
gosub setlockhotkey
gui,lock:color,black
ymin:=min(0, monitors[monitors.length()].t)
gui,lock:add,edit,% "x" floor(a_screenwidth/4) " y" floor(a_screenheight/2)-ymin " w" floor(a_screenwidth/2) " vunlockPW password"
gui,lock:show,% "x0 y" ymin " w" lastMonitorRight " h" (lastMonitorBottom-ymin),lockscreen
unlockRL:=unlockLU:=0
return

setlockhotkey:
hotkey,ifwinexist,lockscreen ahk_class AutoHotkeyGUI
hotkey,enter,locksub,on
hotkey,numpadenter,locksub,on
hotkey,rbutton,locksub,on
hotkey,!F4,noQuit,on
hotkey,ifwinexist
SetTimer,keepActive,500
return

keepActive:
if (A_TickCount-lockScreenPauseTick<1000)
	return
IfWinNotActive,ahk_id %lockHwnd%
	winactivate,ahk_id %lockHwnd%
winset,AlwaysOnTop,on,ahk_id %lockHwnd%
return

noQuit:
return

^!+z::
if !(a_priorhotkey=a_thishotkey && a_timesincepriorhotkey<500)
	return 
unlock:
;~ msgbox
gui,lock:destroy
;~ WinFade(lockHwnd)
;~ hotkey,^!+z,,off
hotkey,ifwinexist,lockscreen ahk_class AutoHotkeyGUI
hotkey,enter,,off
hotkey,numpadenter,,off
hotkey,rbutton,,off
hotkey,!F4,,off
hotkey,ifwinexist
SetTimer,keepActive,off
ToolTip
return



parse_commands:
gui,%guiHWND%:Default
if !(nosubmit)
	gui,submit,nohide
nosubmit=0
if commands!=
	command_hx.push(commands)
	,command_hx_ind:=""
loop,parse,commands,`,
{
	command:=trim(a_loopfield)
	if(!command)
		continue
	if command in rel,reload
		goto reload
	else if command=renew
		refreshRisImpaxEncrypt()
		, RisImpaxLoadPw(RisImpaxDecodePw)
	else if command=adjustris
		configRisFrames()
	else if RegExMatch(command, "is)^kill (.+)", match){
		;~ process,close,% match1 . InStr(match1,".exe")?"":".exe"
		;~ WinKill,% "ahk_exe " match1 . InStr(match1,".exe")?"":".exe"
		;~ Run,% comspec " /c ""taskkill /IM " match1  (InStr(match1,".exe")?"":".exe") " /F""",,Hide
		TaskKill(match1)
	}else if RegExMatch(command, "i)^(HKEY|HKCR|HKCU|HKLM|HKU|HKCC)"){
		RegJump(command)
	}else if command in lock
	{
		gosub lockScreen
		
	}
	else if (command="bdg")
	{
		
		;~ if hwnd:=winexist("ahk_exe PacsIE.exe") {
			;~ sendMessage,0x10101,,,,PacsIE ahk_class AutoHotkey
			;~ if errorlevel 
				;~ process,close,PacsIE.exe
		;~ }
		;~ run % """" commandArr["pIE"] """ """ substr(commandArr["pIE"],1,-3) "ahk"" " (command="pIEo"?"-offline":"")
		run, % """" commandArr["bdg"] """" 
		;~ run % """" commandArr["pIE"] """" 
			
	}
	else if(val:=commandArr[command]){
		hasExecuted:=false
		if command in YCH,YXR,CXR,brus,mamm,bmd
		{
			if(partialMode){
				
				
				if command=YCH
					val:=root "\YCH_Enh.exe"
				else if command=YXR
					val:=root "\YCH_XR_Enh.exe"
				else if command=mamm
					val:=root "\AutoHotkey.exe " root "\YCH_mammo_Enh.ahk"
				else if command=bmd
					val:=root "\AutoHotkey.exe " root "\YCH_BMD.ahk"
				
				try
					run, % val,,hide

				if !fileexist(root "\Hotstring Helper\Hotstring Helper.ahk")
					runwait,%ComSpec% /c "git checkout HEAD -- "Hotstring Helper/Hotstring Helper.ahk"",% root,hide
				if !fileexist(root "\Hotstring Helper\HotstringHint.ahk")
					runwait,%ComSpec% /c "git checkout HEAD -- "Hotstring Helper/HotstringHint.ahk"",% root,hide

				; Persistent HH: only launch if not already running. Otherwise
				; HH_Announce() will reorder its dic + lazy-load this YCH variant.
				prev_dh_autorun_hh := A_DetectHiddenWindows
				DetectHiddenWindows On
				hh_running := WinExist("HotstringHelperMain ahk_class AutoHotkeyGUI")
				DetectHiddenWindows %prev_dh_autorun_hh%
				if !hh_running
					try
						RunKeepFocus("""Hotstring Helper.exe"" ""Hotstring Helper.ahk"" """ SubStr(val,StrLen(root)+2,-8) ".ahk"" """ SubStr(val,StrLen(root)+2,-8) "_main.ahk""", root "\Hotstring Helper\", "hide")
				HH_Announce(val)

				hasExecuted:=true

			}else{
				RegExMatch(val,"is)Autohotkey(?:U64)?.exe (.+)",match)
				if FileExist(SubStr(match1,1,-4) "_Enh.ahk")
					val:=SubStr(val,1,-4) "_Enh.ahk"
				
				;~ if InStr(match1, "ych_xr")
					;~ val:=RegExReplace(val, "i)_Enh", "")
				
				try
					run % val
				hasExecuted:=true

				;~ fileappend,% joinScript(match1),% root "\scripts\Radiology\Hotstring Helper\" regexreplace(match1,"s).+(\\|\/)",""),utf-8
				;~ filecopy,% match1,% root "\scripts\Radiology\Hotstring Helper",1

				; Persistent HH: only launch if not already running.
				prev_dh_autorun_hh := A_DetectHiddenWindows
				DetectHiddenWindows On
				hh_running := WinExist("HotstringHelperMain ahk_class AutoHotkeyGUI")
				DetectHiddenWindows %prev_dh_autorun_hh%
				try {
				if !hh_running
					RunKeepFocus("""" root "\scripts\Radiology\Hotstring Helper\Hotstring Helper.exe"" """ SubStr(match1,1,-4) ".ahk"" """ SubStr(match1,1,-4) "_main.ahk""", "", "hide")
				HH_Announce(val)

				if command=mamm
					run, % ahkMain " " root "\scripts\Radiology\mammoMagMove.ahk",,hide
				else if command=brus
					run, % ahkMain " " root "\scripts\Radiology\breastUS.ahk",,hide
				else if command=YXR
					run, % commandArr["simple"],,hide
				}
				winactivate,% "ahk_id " risstate[2]
				
			}
		}
		
		if !(hasExecuted)
			try {
				run,% val,,hide
			}
	}else if (command="rad"){
		;~ loop {
			;~ process,close,Menu.exe
		;~ } until !errorlevel
		work()
	}else if (command="rad1"){
		;~ loop {
			;~ process,close,Menu.exe
		;~ } until !errorlevel
		work(1)
	}else if (command="liu"){
		try {
			if partialMode
				;~ run, % A_ScriptDir "\XLiu\XLiu.exe",,hide
				RunKeepFocus(A_ScriptDir "\XLiu\XLiu.exe", "", "hide")
			else if fileexist(A_MyDocuments "\scsnake\XLiu\XLiu.exe")
				;~ run, % A_MyDocuments "\scsnake\XLiu\XLiu.exe",,hide
				RunKeepFocus(A_MyDocuments "\scsnake\XLiu\XLiu.exe", "", "hide")
			else
				;~ run, % root "\software\XLiu\Xliu.exe",,hide
				RunKeepFocus(root "\software\XLiu\Xliu.exe", "", "hide")
		}
	}else if (command="slp"){
		gosub run_slp
		settimer,run_slp,3000
	}else if (command="boneage"){
		try {
			run,% root "\scripts\bone_age\boneage report.exe"
		
			IfWinNotExist,Skeletal Development of the Hand and Wrist - A Radiographic Atlas and Digital Bone Age Companion
				run,% root "\R2\PED\Skeletal Development of the Hand and Wrist - A Radiographic Atlas and Digital Bone Age Companion.pdf"
		}
	}else{
		try {
			run % command
		}
		;~ Run %comspec% /c "start ""%command%"""
	}
}
gui,%guihwnd%:Default
guicontrol,%guihwnd%:,commands,% ""
winactivate,ahk_id %lastActiveWin%
lastActiveWin:=0
return
work(para=0){
	global
	nosubmit=1
	commands:="ych"
	try {
	if (!winexist("ahk_exe firefox.exe")) 
		if fileexist(lnk:=A_Desktop "\FirefoxLogin.lnk") || fileexist(lnk:=A_Desktop "\FirefoxLogin.exe.lnk") 
			run % lnk
		else if fileexist(lnk:=A_ProgramFiles "\Mozilla Firefox\firefox.exe")
			run % lnk
		else if fileexist(lnk:=A_MyDocuments "\Mozilla Firefox\firefox.exe")
			run % lnk
		
		
	}
	settimer,parse_commands,-1
	;~ gosub run_slp
	;~ settimer,run_slp,3000
	alternativeLogin:=!!para
	settimer,~^!l,-500
}
#ifwinactive,Enter command ...
exe:
~NumpadEnter::
~Enter::
gosub parse_commands
guicontrol,%guihwnd%:focus,commands
return
~esc::
guicontrol,%guihwnd%:,commands,% ""
return
up::
if command_hx_ind=
	command_hx_ind:=command_hx.length()+1
if (--command_hx_ind)<1
	command_hx_ind:=command_hx.length()
guicontrol,%guihwnd%:,commands,% command_hx[command_hx_ind]
guicontrol,%guihwnd%:focus,commands
return
Down::
if command_hx_ind=
	command_hx_ind:=0
if (++command_hx_ind)>command_hx.length()
	command_hx_ind:=1
guicontrol,%guihwnd%:,commands,% command_hx[command_hx_ind]
guicontrol,%guihwnd%:focus,commands
return
#IfWinActive
#ifwinactive,報告
~esc::
;~ winget,activeWin,hwnd,A
WinGetClass,winClass,A
if !instr(winClass,"WindowsForms10.Window.8.app")
	return
winclose,A
winactivate,% "ahk_id " RisOpened(1)[2][1]
return
#IfWinActive
~+!RButton::
gosub toggleAutoActivate
return

~rbutton::
if !(a_thishotkey=a_priorhotkey && A_TimeSincePriorHotkey<300 && GetKeyState("RButton","P")) {
	return
}
mousemove,-1,-1,0,R
mousegetpos,,,activeWin
wingetTitle,activeWinTitle,% "ahk_id " activeWin
keywait,rbutton
if (instr(activeWinTitle,"放射線資訊管理系統(Radiology Information System)") || instr(activeWinTitle,"DisplayMenuForm")) {
	mouseclick,l,-2,-2,1,0,,r
	mouseclick,r,2,2,1,0,,r
	sleep 100
	mouseclick,l,5,5,1,0,,r
}
return
#ifwinactive,ahk_class #32770
~esc::
winclose,A
return
#ifwinactive


#1::
#2::
#3::
#4::
ahkArr:=["ych","yxr","mamm","bmd"]
guicontrol,%guihwnd%:,commands,% ahkArr[substr(a_thishotkey,2,1)+0]
gosub parse_commands
Sleep 1000
RunKeepFocus(partialMode?root "\capslock_remap_alt.exe":ahkMain " " root "\scripts\Radiology\MouseKeyRemap\capslock_remap_alt.ahk","","hide")
return


renewRisReports:
if !(isobject(risReports) && controlexist(RisReports[1,1]))
	RisReports:=getRisReports(RisState[2])
return

~esc::
UnhookWindowsHookEx(hHookMouse)
return
;~ #ifwinactive,ahk_class WindowsForms10.Window.8.app.0.2bf8098


F10::
mousegetpos,,,win
winget,pName,processname,ahk_id %win%
if instr(pName,"impax")
	goto chestModule
else
	send {f10}
return


#ifwinactive,ahk_group pacs


~esc::
if(A_PriorHotkey=A_ThisHotkey && A_TimeSincePriorHotkey<400){
	send {Del}
}
return



$Space::
if __is_CH
	{
		send {space}
		return
	}
;~ winget,pName,ProcessName,A
;~ if(pName="impax-client-main.exe")
	;~ if !GetKeyState("Lbutton")
		;~ resetHotstringBuffer(-1)
;~ }else{
;~ if (lbuttonState:=GetKeyState("LButton"))
	;~ send {lbutton up}
if winexist("確認刪除 ahk_exe impax-client-main.exe"){
	winactivate,確認刪除 ahk_exe impax-client-main.exe
	winwaitactive,確認刪除 ahk_exe impax-client-main.exe,,1
	controlclick,是,確認刪除 ahk_exe impax-client-main.exe
	return
}
focused:=getFocusedHWND()
WinGetClass,focusedClass,ahk_id %focused%
if RegExMatch(focusedClass, "i)(?<!t)edit|text")
	return
MouseGetPos,,,,aControl,2
winactivate,% "ahk_id " aControl
ControlFocus,,% "ahk_id " aControl
PostMessage,0x2024,% lbuttonState,,,RazerNaga_main ahk_class AutoHotkeyGUI
;~ }
return

;~ Space up::
;~ winget,pName,ProcessName,A
;~ if(pName="impax-client-main.exe"){
	;~ send {Lbutton up}
;~ }else{
	;~ PostMessage,0x2024,,,,RazerNaga_main ahk_class AutoHotkeyGUI
;~ }
;~ return
;~ ~wheeldown::
;~ ~wheelup::
;~ scrollSeriesList:
;~ if GetKeyState("Rbutton"){
	;~ seriesList:=getSeriesList()
	;~ ,which:=seriesList.maxindex()>1?whichMonitor("","",monitorInfo).1-1:1
	;~ winactivate,% "ahk_id " seriesList[which].1
	;~ ControlFocus,,% "ahk_id " seriesList[which].2
	;~ send % "{" RegExReplace(A_ThisHotkey,"\W*","") "}"
;~ }
;~ return

focusImpression(){
	gosub focusImpression
}
focusImpression:
#space::
if __is_CH
{
if !WinExist("simple RIS ahk_class AutoHotkeyGUI"){
	CH_RIS.check_wb()
	CH_RIS.activate()
}else
	PostMessage,0x2032,,,,simple RIS ahk_class AutoHotkeyGUI
}else
{			
		
checkRis(RisState)
gosub renewRisReports
controlfocus,,% "ahk_id " RisReports[1,2]
winactivate,% "ahk_id " RisState[2]
controlfocus,,% "ahk_id " RisReports[1,2]
}
return

chestModule:
F10::
if (seriesX1 && seriesY1){
	mousegetpos,seriesX2,seriesY2
	
	impaxFrames:=getViewFrame(impaxState[2])
	controlgetpos,xx,yy,ww,hh,,% "ahk_id " impaxFrames[1,1,1]
	controlgetpos,xx2,yy2,ww2,hh2,,% "ahk_id " impaxFrames[2,1,1]
	xx+=firstMonitorRight-firstMonitorLeft
	mousemove,% xx+ww/2,% yy+hh/2,0
	click,2
	sleep 300
	
	mousemove,% seriesX1,% seriesY1,0
	send {lbutton down}
	sleep 100
	mousemove,% xx+ww/2,% yy+hh/4,2
	send {lbutton up}
	
	xx2+=firstMonitorRight-firstMonitorLeft
	mousemove,% seriesX2,% seriesY2,0
	send {lbutton down}
	sleep 100
	mousemove,% xx2+ww2/16,% yy2+hh2/4,2
	send {lbutton up}
	sleep 100
	send {F6}
	sleep 100
	send h

	gosub showSeriesList
	
	mousemove,% xx+ww/2,% yy,0
	send {F6}
	sleep 100
	send h
	
	seriesX1:=seriesY1:=seriesX2:=seriesY2:=0

}else{
	mousegetpos,seriesX1,seriesY1
}
return

setontop:
return
if(A_TickCount-setontoptick)<500
	goto setontopreturn
;~ simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")
IfWinNotActive,ahk_group pacs
	DllCall("SetWindowPos", "Ptr", simpleRis, "Ptr", 0, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	,DllCall("SetWindowPos", "Ptr", simpleRis, "Ptr", -1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	;~ ,DllCall("SetWindowPos", "Ptr", impaxOpened()[2,1], "Ptr", guihwnd, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	;~ settimer,setNotOnTop,-1000

setontopreturn:
setontoptick:=A_TickCount
return


activateSimpleRis:
;~ ~capslock up::
keywait,capslock,t1
resetHotstringBuffer(-1)
if __is_N
	checkRis(RisState)
if !(simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")) && (__is_N && RisState[1]!=2)
	return
if (simpleRis){
	;~ winactivate,% "ahk_id " risstate[2]
	;~ winset,alwaysontop,on,ahk_id %simpleRIS%
	if(winexist("ahk_exe PacsIE.exe")){
		winget,nextProcName,ProcessName,% "ahk_id " GetNextWindow(simpleRis)
		if(nextProcName!="PacsIE.exe") {
			SendMessage,0x10202,,,,ahk_exe PacsIE.exe
			winactivate,ahk_id %simpleRis%
			winwaitactive,,,1
			;~ controlfocus,Scintilla1,ahk_id %simpleRis%
			controlfocus,Scintilla1,ahk_id %simpleRis%
			
		}
	}else if (hwnd:=WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")){
		SendMessage,0x10202,,,,ahk_id %hwnd%
	}
	
	
	SendMessage,0x2028,,,,ahk_id %simpleRis%
	return
	
	WinShow,ahk_id %simpleRis%
	;~ winset,AlwaysOnTop,on,ahk_id %simpleRis%
	;~ if !WinExist("WM_COPYDATA_Listener_miniPACS")
		;~ winset,AlwaysOnTop,Off,ahk_id %simpleRis%
	winactivate,ahk_id %simpleRis%
	winwaitactive,,,1
	controlfocus,Scintilla1,ahk_id %simpleRis%
	;~ controlfocus,Scintilla1,ahk_id %simpleRis%
	
}else{
	winactivate,% "ahk_id " risstate[2]
	focused:=getFocusedHWND()
	gosub renewRisReports
	;~ risReports:=getRisReports(risstate[2])
	if (focused!=risReports[1,1] && focused!=risReports[1,2])
		controlfocus,,% "ahk_id " risReports[1,1]
}

return



~1::
~2::
~3::
~4::
;~ SendLevel,2
;~ leftDown:=getkeystate("Lbutton")
;~ mousegetpos,x,y
if __is_CH
	return
focused:=getFocusedHWND()
WinGetClass,focusedClass,ahk_id %focused%
if RegExMatch(focusedClass, "i)edit|text")
	return
from:="impax"
MoveFromSeriesList:
old_sendlevel:=a_sendlevel
sendlevel,0
RegExMatch(a_thishotkey, "\d+", key)
whichMonitor:=monitors[key=4?3:key]
;~ msgbox % whichMonitor.l
;~ t:=(A_OSVersion="WIN_XP")?100:400
if(key>1){
	;~ send {lbutton}
	;~ Sleep 100
	send {lbutton down}
	MouseMove,10,0,1,r
	postmessage,0x10101,,,,ImpaxSeriesList_main ahk_class AutoHotkeyGUI

	Sleep 100
	
}
;~ if(whichMonitor=1 && )

;~ else
	mousemove,% newX:=(whichMonitor.l)+100,% newY:=floor((whichMonitor.h)/2)+whichMonitor.t,0
;~ if(leftDown){
	;~ sleep 100
	;~ send [lbutton up}
	;~ sleep 100
	;~ mousemove,% x,% y,0
;~ }else{
mousemove,10,0,2,r
sleep 100
if(key>1){
	send {lbutton up}
	sleep 100
}
if(key=4){
	if from=impax
		gosub toggleSeriesList
	if GetKeyState("Lbutton")
		send {Lbutton UP}
	mousemove,% newX:=monitors.2.r-100,% newY:=floor((whichMonitor.h)/2)+whichMonitor.t,0
	mousemove,10,0,1,r
	;~ SetTimer,lungWindow,-1
	;~ Sleep 500
	send {F6}
	
	if from=impax
	{
		sleep 100
		send h!{.}
		Sleep 100
		send h
	}
}else{
	if from=impax
		SetTimer,toggleSeriesList,-500
}
SendLevel,% old_sendlevel
frame:=400
settimer,show,-1
;~ }
return



keepLbuttonDown:
;~ tooltip % getkeystate("lbutton","P") "," lbuttondown
;~ if getkeystate("lbutton","P") || lbuttonDown
	;~ return
;~ send {lbutton down}
;~ lbuttonDown:=1
;~ tooltip , down
return

;~ lbutton up::
;~ send {lbutton down}
;~ return

;~ lbutton::
;~ send {lbutton up}
;~ return

scrolling:
send % scrolling>0?"{WheelDown}":"{WheelUp}"
settimer,scrolling,% (-1)*scrollingFreq
return


;~ ~PgDn::
;~ if (scrolling=-1){
	;~ settimer,scrolling,off
	;~ scrolling:=0
;~ }
;~ if !(a_thishotkey=a_priorhotkey && A_TimeSincePriorHotkey<500)
	;~ return
ScrollLock:: 
send {lbutton down}
impaxMouseHook:=true
mouseHooks.push(SetWindowsHookEx(WH_MOUSE_LL   := 14, RegisterCallback("MouseHook", "Fast")))
;~ scrolling:=1
;~ settimer,scrolling,% (-1)*scrollingFreq
return


;~ ~PgUp::
;~ if (scrolling=1){
	;~ settimer,scrolling,off
	;~ scrolling:=0
;~ }
;~ if !(a_thishotkey=a_priorhotkey && A_TimeSincePriorHotkey<500)
	;~ return
;~ send {lbutton up}
;~ scrolling:=-1
;~ settimer,scrolling,% (-1)*scrollingFreq
;~ return

;~ ~wheelup::
;~ ~wheeldown::
;~ if scrolling=0
	;~ return
;~ scrollingFreq:=floor(scrollingFreq*(instr(a_thishotkey,"up")?(1/1.2):1.2))
;~ return




;~ LButton & RButton::
;~ if RisState[1]!=2
	;~ return
;~ winactivate,% "ahk_id " risstate[2]
;~ return

;~ ~F2::
;~ ~F4::
;~ ~F5::
;~ ~F7::
;~ ~F8::
;~ gosub applyOtherStudy
return

edgeEnhancing:
MouseGetPos,,,win,con,2
winget,pName,ProcessName,ahk_id %win%
if (pName="impax-client-main.exe"){
	send h
	winactivate,% "ahk_id " win
	ControlFocus,,% "ahk_id " con
	send !{.}h
}else if (pName="G3PACS.exe"){
	send {tab}
}
	
return

releaseMouseIfEBM:
lbuttonState:=GetKeyState("LButton")
if !lbuttonState
	return
MouseGetPos,cwmx,cwmy,win
winget,pName,ProcessName,ahk_id %win%
if (pName~="i)WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
	isEBM:=true
	;~ oldsendlevel:=A_SendLevel 
	BlockInput,MouseMove
	;~ send {LButton up}
	;~ Sleep 200
	;~ SendLevel,3
	;~ send +!^{UP}
	SendMessage,0x10222,% cwmx,% cwmy,,RazerNaga_main
	;~ StringReplace,windowHotkey,A_ThisHotkey,~,
	RegExMatch(A_ThisHotkey,"i)F\d+", windowHotkey)
	send % "{" windowHotkey "}"
	;~ send {lbutton Down}
	;~ send +!^{UP}
	SendMessage,0x10222,% cwmx,% cwmy,,RazerNaga_main
	BlockInput,MouseMoveOff
	;~ SendLevel,% oldsendlevel
}else{
	ifEBM:=false
}
return

;~ reclickMouseIfEBM:
;~ if (lbuttonState && isEBM)
	;~ send {lbutton Down}
;~ BlockInput,MouseMoveOff
;~ return

$F3::

send {F3}
sleep 100
settimer,edgeEnhancing,-1
SetTimer,HideSeriesListAll,-1
;~ gosub applyOtherStudy
gosub releaseMouseIfEBM
;~ gosub reclickMouseIfEBM
return
lungWindow:
$F6::
send {f6}
sleep 100
settimer,edgeEnhancing,-1
SetTimer,HideSeriesListAll,-1
;~ gosub applyOtherStudy
gosub releaseMouseIfEBM
;~ gosub reclickMouseIfEBM
return

~F2::
;~ ~F3::
~F4::
~F5::
;~ ~F6::
~F7::
~F8::
~F9::
SetTimer,HideSeriesListAll,-1
gosub releaseMouseIfEBM
;~ gosub reclickMouseIfEBM
return

;~ tab::
HideSeriesListAll:
showSeriesList:
toggleSeriesList:
Send_WM_COPYDATA(WinExist("ImpaxSeriesList_main ahk_class AutoHotkeyGUI"), 19
	, jxon_dump({command: A_ThisLabel}))
return


inArray(ele, arr){
	for k,v in arr
		if(ele=v)
			return true
	return false
}

applyOtherStudy:
if getkeystate("Rbutton")
	return
RegExMatch(a_thishotkey,"i)F\d+",key)
if monitors.maxIndex()<3
	return
impaxAccNo1:=getImpaxAccNo(impaxState[2,1],1)
impaxAccNo2:=getImpaxAccNo(impaxState[2,1],0)
if(impaxAccNo1 = impaxAccNo2)
	return
mousegetpos,mx,my
mousemove,% 2*mx-monitors.2.r,% my,0
sleep 100
send {%key%}
if(key="F3" || key="F8"){
	sleep 100
	send h 
}
return


;~ detectLbuttonUp:
;~ if !GetKeyState("Lbutton") {
	;~ SetTimer,_lbuttonup,-500
	;~ SetTimer,detectLbuttonUp,Off
;~ }
;~ return

UnhookWindowsHookEx:
for k,v in mouseHooks
	UnhookWindowsHookEx(v)
mouseHooks:=[]
return

_lbuttonup:
;~ ~lbutton up::
;~ for k,v in mouseHooks
	;~ UnhookWindowsHookEx(v)
gosub UnhookWindowsHookEx
impaxMouseHook:=false
MouseGetPos,mx,my,win
WinGetTitle,t,ahk_id %win%
;~ SetTimer,dragGuiFinish,-1
;~ mouseHooks:=[]
;~ SystemCursor("On")
settimer,hidecursor,off
lbuttonDown:=0
return
~lbutton::	
mousegetpos,mx,my,mouseWin,mouseControl
WinGetClass,mouseWinClass,ahk_id %mouseWin%
return
tryhook:=false
if(mouseWinClass="#32770" && mouseControl="SysListView321"){
	;~ SetTimerFn("lbuttonStay",-200, [mx, my])
	
}else{
	;~ tryhook:=true
	;~ KeyWait, LButton, T0.1
}
;~ if !mouseDragUtil
	;~ return

if (tryhook && errorlevel && regexmatch(mouseControl,"AfxWnd90u\d+")) {
	;~ mouseHooks.push(SetWindowsHookEx(WH_MOUSE_LL   := 14, RegisterCallback("MouseHook", "Fast")))
	;~ ,impaxMouseHook:=true
	;~ SetTimer,detectLbuttonUp,500
	;~ settimer,hideCursor,100
} else {
	;~ for k,v in mouseHooks
		;~ UnhookWindowsHookEx(v)
	gosub UnhookWindowsHookEx
	impaxMouseHook:=false
	;~ mouseHooks:=[]
	;~ SystemCursor("On")
	settimer,hideCursor,off
}
return

lbuttonStay(mx, my){
	global originalMouse
	if GetKeyState("Lbutton") {
		MouseGetPos,x,y,,mouseControlId,2
		if(x=mx && y=my){
			if(ControlGetText(mouseControlId)="List1"){
				originalMouse:={x:mx,y:my}
				;~ gosub createSeriesDragGUI
			}
		}
	}

}

createSeriesDragGUI:
if IsObject(dragGUIth)
	dragGUIth.ahkTerminate()
;~ return ;pauseThread
;~ MsgBox  % mx "," my
viewFrame:=getViewFrame(ImpaxState[2])

;~ threads["dragGUI"]:=dragGUIth
;~ while !dragGUIth.ahkReady()
	;~ Sleep 200

return
<createSeriesDragGUI:
;~ gosub <DestroyDragGUI
dragGUIs:=[]
,viewFrame:=getViewFrame(ImpaxState[2]), dimension:=[], w:=h:=0

,guiX:=mx+10, winStack:=[], dragWBs:=[]
Loop 
	if (viewFrame[A_Index,1]!=""){
		gui,dragGUI%a_index%:New
		gui,+hwnddragGUIhwnd +ToolWindow -Border -Caption +AlwaysOnTop 
		gui,Color,black
		dragGUIs.push(dragGUIhwnd), winStack.push(dragGUIhwnd)
		winset,AlwaysOnTop,on,ahk_id %dragGUIhwnd%
		w:=(xCount:=viewFrame[A_Index, 1].maxindex())*100
		,h:=(yCount:=viewFrame[A_Index].maxindex())*100
		;~ w:=h:=200
		;~ ToolTip % ++iii
		gui,Add,ActiveX,% "x0 y0 w" w " h" h " vWBdrag" A_Index, Shell.Explorer
		WBdrag%a_index%.silent:=true
		,WBdrag%a_index%.Navigate("about:blank")
		, dragWBs.push(WBdrag%a_index%)
		,cells:=""
		Loop % yCount {
			cells.="<tr>"
			Loop % xCount {
				cells.="<td></td>"
			}
			cells.="</tr>`n"
		}
		while (WBdrag%a_index%.ReadyState != 4)
			Sleep 10
		html=
		(LTrim
		<head>
		<style type="text/css">
		* {
			background-color: black;
		}
		body {
			overflow: hidden;
		}
		table {
			border-collapse: collapse; 
			left: 0; top: 0; position: absolute; 
			table-layout: fixed;
		}
		td {
			border: 1px white solid; 
			width: 100px; height: 100px; 
		}
		td:hover {
			background-color: gray;
		}
		</style>
		<script type="text/javascript">
		</script></head>
		<body>
		<table>
		%cells%
		</table></body>
		)
		WBdrag%a_index%.document.open()
		,WBdrag%a_index%.document.write(html)
		,WBdrag%a_index%.document.close()
		;~ MsgBox % guiX
		gui,show,% "x" guiX " y" my+10 " w" w " h" h, % "dragGUI" A_Index
		guiX+=w+10
	}else 
		break
WinStack(winStack.push(mouesWin))
SetTimer,<hoverDragGUI,-400
SetTimer,<DestroyDragGUI,-100000
createSeriesDragGUI>:
return

<hoverDragGUI:
MouseGetPos,mx,my,win
WinGetTitle,t,ahk_id %win%
if RegExMatch(t, "dragGUI(\d+)", match){
	WinGetPos,wx,wy,,,ahk_id %win%
	targetX:=Floor((mx-wx)/100)+1
	,targetY:=Floor((my-wy)/100)+1
	try
		prevCell.style.backgroundColor:="black"
	;~ ToolTip % targetX "," targetY
	(prevCell:=WBdrag%match1%.document.getElementsByTagName("table")[0].rows[targetY-1].cells[targetX-1]).style.backgroundColor:="grey"
}
SetTimer,<hoverDragGUI,-400
hoverDragGUI>:
return

<DestroyDragGUI:
for k,v in dragGUIs
	gui,dragGUI%k%:Destroy
SetTimer,<hoverDragGUI,off
DestroyDragGUI>:
return
dragGuiFinish:
if(dragGUIth)
	dragGUIth.ahkLabel("<dragGuiFinish")
return
<dragGuiFinish:
if RegExMatch(t, "dragGUI(\d+)", match){
	WinGetPos,wx,wy,,,ahk_id %win%
	targetX:=Floor((mx-wx)/100)+1
	,targetY:=Floor((my-wy)/100)+1
	mouseDragSeries(originalMouse, mouseWin, viewFrame[match1+0, targetY, targetX])
	;~ dragSeries(targetX,targetY,originalMouse,match1,seriesListStored,viewFrame)
}
SetTimer,<DestroyDragGUI,-1
dragGuiFinish>:
return

MouseHook(nCode, wParam, lParam){
	static lx,ly
	global impaxMouseHook, firstMonitorBottom, lastMonitorBottom, lastMonitorRight, newX, newY
	Critical
	if (wParam=0x202){ ;lbutton up
		;~ UnhookWindowsHookEx(hHookMouse)
		impaxMouseHook:=false
		SetTimer,dragGuiFinish,-1
		return CallNextHookEx(nCode, wParam, lParam)
	}else if(wParam=0x200){
		x := NumGet(lParam+0, 0, "Int")
		,y := NumGet(lParam+0, 4, "Int")
		if (x>=lastMonitorRight){
			if getkeystate("lbutton") || getkeystate("rbutton") || getkeystate("mbutton")
				return CallNextHookEx(nCode, wParam, lParam)
			DllCall("SetCursorPos", "Int", mx:=1, "Int", my:=Floor(y*firstMonitorBottom/lastMonitorBottom))
			,NumPut(newX:=mx, lParam+0, 0, "Int")
			,NumPut(newY:=my, lParam+0, 4, "Int")
			settimer,show,-1
			return 1
		}else if(x<=0){
			if getkeystate("lbutton") || getkeystate("rbutton") || getkeystate("mbutton")
				return CallNextHookEx(nCode, wParam, lParam)
			DllCall("SetCursorPos", "Int", mx:=lastMonitorRight-1, "Int", my:=Floor(y*firstMonitorBottom/lastMonitorBottom))
			,NumPut(newX:=mx, lParam+0, 0, "Int")
			,NumPut(newY:=my, lParam+0, 4, "Int")
			settimer,show,-1
			return 1
		}
		if(impaxMouseHook){
	;~ If nCode || !(wParam = 0x200)
	;~ return CallNextHookEx(nCode, wParam, lParam)
		VarSetCapacity(lpPoint,8)
		,DllCall("GetCursorPos", "Uint", &lpPoint)
		,lx := NumGet(lpPoint, 0, "Int")
		,ly := NumGet(lpPoint, 4, "Int")
		,mx := NumGet(lParam+0, 0, "Int")
		,my := NumGet(lParam+0, 4, "Int")
		,mx := lx + (mx-lx)
		,my := ly + (mx-lx) + (my-ly)
		,DllCall("SetCursorPos", "Int", mx, "Int", my)
		,NumPut(mx, lParam+0, 0, "Int")
		,NumPut(my, lParam+0, 4, "Int")
		;~ ,SystemCursor("Off")  ; not work on impax
		return 1
		}
	}
	
	return CallNextHookEx(nCode, wParam, lParam)
}
ClipCursor( Confine=True, x1=0 , y1=0, x2=1, y2=1 ) {
	VarSetCapacity(R,16,0),  NumPut(x1,&R+0),NumPut(y1,&R+4),NumPut(x2,&R+8),NumPut(y2,&R+12)
	Return Confine ? DllCall( "ClipCursor", UInt,&R ) : DllCall( "ClipCursor" )
}
;~ SetWindowsHookEx(idHook, pfn)
;~ {
	;~ Return DllCall("SetWindowsHookEx", "int", idHook, "Uint", pfn, "Uint", DllCall("GetModuleHandle", "Uint", 0), "Uint", 0)
;~ }
;~ CallNextHookEx(nCode, wParam, lParam, hHook = 0)
;~ {
	;~ Return DllCall("CallNextHookEx", "Uint", hHook, "int", nCode, "Uint", wParam, "Uint", lParam)
;~ }
;~ UnhookWindowsHookEx(hHook)
;~ {
	;~ Return DllCall("UnhookWindowsHookEx", "Uint", hHook)
;~ }
mouseGesture:
if (abs(gestureY2-gestureY1)+abs(gestureX2-gestureX1)<20) {
	gestureValue:=0
	return
}
if (gestureX2=gestureX1) {
	gestureValue:=(gestureY2>gestureY1)?4:8
}else if (gestureX2>gestureX1){
	if (slope:=(gestureY2-gestureY1)/(gestureX2-gestureX1))>2.414
		gestureValue:=4
	else if slope>0.414
	gestureValue:=3
	else if slope>-0.414
	gestureValue:=2
	else if slope>-2.414
	gestureValue:=1
	else
	gestureValue:=8
}else if (gestureX2<gestureX1){
	if (slope:=(gestureY2-gestureY1)/(gestureX2-gestureX1))>2.414
		gestureValue:=8
	else if slope>0.414
	gestureValue:=7
	else if slope>-0.414
	gestureValue:=6
	else if slope>-2.414
	gestureValue:=5
	else
	gestureValue:=4
}

if gesturevalue=2
	send {right}
else if gesturevalue=6
	send {left}
else if gesturevalue=8
	send %modifier%{up}
else if gesturevalue=4
	send %modifier%{down}
return

gestureStart:
mbutton::
mousegetpos,gestureX1,gestureY1,mouseWin
WinGetClass,mouseWinClass,ahk_id %mouseWin%
winactivate,ahk_id %mouseWin%
mouseMonInd:=whichMonitor()
modifier:=(whichMonitor[1]=3?"^":"")
return
mbutton up::
mousegetpos,gestureX2,gestureY2
gosub mouseGesture
if (Impax:=ImpaxState)[1]!=2
	return
if (!gestureValue){
	cursorModeToggle:=!cursorModeToggle
	if(mouseWinClass="TViewerForm"){
		ebmv:=new ebmViewer("", mouseWin)
		,ebmv.SelectTool("5.8")
	}else{
		for k,v in impaxControls:=getControls(Impax[2,1])
			if (v.text="BMP_CURSOR_MODE_NEW" && instr(v.classNN,"WindowsForms10.BUTTON.app")){
				controlclick,,% "ahk_id " impaxCursorModeHwnd:=v.hwnd
				break
			}
		;~ msgbox % acc_objectfromwindow(impaxCursorModeHwnd).accState
		if (cursorModeToggle)
			settimer,cursorModeToggle,-100
	}
	
	
}
gestureValue:=0
return

cursorModeToggle:
if(winactive("ahk_group pacs") && !getkeystate("Lbutton") && !getkeystate("mbutton") && !getkeystate("rbutton")){
	mousegetpos,mx,my
	if (mx-gestureX1)**2+(my-gestureY1)**2>2500 {
		controlclick,,% "ahk_id " impaxCursorModeHwnd
		cursorModeToggle:=!cursorModeToggle
		return
	}
}
settimer,cursorModeToggle,-100

return


`::
toggleImageText:
ImpaxToggleImageText(ImpaxState)
return
~!2::
Sleep 400
winwait,ahk_class #32770,Screen_0_format,2
winmove,ahk_class #32770,Screen_0_format,% 0,% 0
mousemove,-99999,-99999,0,R
wingetpos,x,y,,,ahk_class #32770,Screen_0_format
mousemove,% x+550, % y+550,0
return

~rbutton::
if !(a_thishotkey=a_priorhotkey && A_TimeSincePriorHotkey<300 && GetKeyState("RButton","P")) {
	return
}
sleep 100
mousemove,10,10,0,r
mousegetpos,,,menuHwnd
controlgetpos,,,w,h,,ahk_id %menuHwnd%
mouseclick,l,% w/2-10,% (h/9)*3,1,0,,R
return

~numpadenter::
~enter::
if (Impax:=ImpaxState)[1]!=2 && Impax[2,4]!=2
	return
selectChartNo:
for k,v in (impaxControls:=getcontrols(id2:=Impax[2,2]|Impax[2,3])){
	if k<2
		continue
	if instr(v.classNN,"WindowsForms10.EDIT.app") && ((impaxControls[k-1].text="病歷號碼" ) || (impaxControls[k-1].text="Patient ID")) {
		controlfocus,,% "ahk_id " impaxChartnoControl:=v.hwnd
		controlget,selectedText,Selected,,,% "ahk_id " impaxChartnoControl
		if !selectedText
			ControlClick,,% "ahk_id " impaxChartnoControl,,l,1
		break
	}
}
return
f1::
if GetKeyState("Lbutton")
	return
if (Impax:=ImpaxState)[1]!=2
	return
bar:=ImpaxBar(id2:=Impax[2,2]|Impax[2,3])
WinShow,% "ahk_id " id2
if(Impax[2,5]=2){
	if(Impax[2,4]=1){
		winactivate,ahk_id %id2%
		wingetpos,,,,h,ahk_id %id2%
		if !(bar.h>h-37)
			controlclick,,% "ahk_id " bar.hwnd
	}else if(Impax[2,4]=3){
		wingetpos,,,,h,ahk_id %id2%
		if !(bar.h>h-37)
			controlclick,,% "ahk_id " bar.hwnd
	}else if(Impax[2,4]=2){
		winactivate,% "ahk_id " Impax[2,1]
	}
}else if(Impax[2,5]=1){
	if(Impax[2,4]=2){
		controlclick,,% "ahk_id " bar.hwnd,,,,% "x" a_screenwidth/2 " y5"
		loop {
			sleep 200
			if(ImpaxState[2,4]=1){
		break
			}else if(ImpaxState[2,4]=3){
		for k,v in (impaxControls:=getcontrols(ImpaxState[2,2]|ImpaxState[2,3])){
			if (v.text="影像" || v.text="Image") && instr(v.ClassNN,"WindowsForms10.BUTTON") {
				controlclick,,% "ahk_id " v.hwnd
				break
			}
		}
			}
		}
	}else if(Impax[2,4]=1||Impax[2,4]=3){
		controlclick,,% "ahk_id " bar.hwnd
	}
}
if (Impax[2,4]!=2) {
	gosub selectChartNo
}
return
backToList:
return
gosub selectChartNo
return
#ifwinactive

~lbutton::	
mousegetpos,mx,my,mouseWin,mouseControl
WinGetClass,mouseWinClass,ahk_id %mouseWin%
return
if(mouseWinClass="#32770" && mouseControl="SysListView321"){
	;~ MouseGetPos,,,,mouseControlId,2
	;~ if(ControlGetText(mouseControlId)="List1"){
		;~ originalMouse:={x:mx,y:my}
		;~ winactivate,ahk_id %mouseWin%
		;~ gosub createSeriesDragGUI
	;~ }
	;~ SetTimerFn("lbuttonStay",-200, [mx, my])
	return
}
return

;~ ~lbutton up::
;~ mousegetpos,mx,my
;~ gosub dragGuiFinish
;~ SetTimer,DestroyDragGUI,-1
;~ return

slp_login:
ifwinnotexist,SleipnirLogin ahk_class AutoHotkeyGUI
{
	settimer,slp_login,-500
	return
}
control,uncheck,,Button8,SleipnirLogin ahk_class AutoHotkeyGUI

sleep 100
controlclick,Button1,SleipnirLogin ahk_class AutoHotkeyGUI
return

run_slp:
return
renewSid:
SlpWb:=getSlpWb()
SlpSid:=[]
for k,v in SlpWb
if regexmatch(v.document.body.innerHTML,"i)SESSION=(\w+)",match)
	isobject(SlpSid["" match1])?(SlpSid["" match1].push(k)):(SlpSid["" match1]:=array(k))
for k,v in SlpSid
if !checksid(k)
	for x,y in v
renewSlpUrl(SlpWb[y],sid:=login(newusername,newpassword))
return
renewSlpUrl(wb,sid){
	if regexmatch(href:=wb.LocationUrl,"i)SESSION=\w+")
		wb.Navigate(RegExReplace(href,"i)SESSION=\w+","SESSION=" sid))
	else if regexmatch(href,"is)/[^/\?]+(\?)?$",match)
	wb.Navigate(href (match1=""?"?":"") "SESSION=" sid)
	else if regexmatch(href,"is)/[^/&\?]+\?[^/\?]+(&?)$",match)
	wb.Navigate(href . (match1=""?"&":"") . "SESSION=" sid)
}
getSlpWb(){
	arr:=[]
	winget,SlpControlList,ControlListHwnd,ahk_class SleipnirMainWindow
	loop,parse,SlpControlList,`n
	{
		WinGetClass,controlClass,ahk_id %a_loopfield%
		if(controlClass!="Internet Explorer_Server")
			continue
		static msg := DllCall("RegisterWindowMessage", "str", "WM_HTML_GETOBJECT")
		, IID := "{0002DF05-0000-0000-C000-000000000046}"
		SendMessage msg, 0, 0, ,ahk_id %a_loopfield%
		if (ErrorLevel != "FAIL") {
			lResult:=ErrorLevel, VarSetCapacity(GUID,16,0)
			if DllCall("ole32\CLSIDFromString", "wstr","{332C4425-26CB-11D0-B483-00C04FD90119}", "ptr",&GUID) >= 0 {
		DllCall("oleacc\ObjectFromLresult", "ptr",lResult, "ptr",&GUID, "ptr",0, "ptr*",pdoc)
		arr.push(ComObj(9,ComObjQuery(pdoc,IID,IID),1)), ObjRelease(pdoc)
			}
		}else{
			continue
		}
	}
	return arr
}
GUIClose:
WinMinimize,ahk_id %guiHWND%
return
close_RIS:
if RisState[1]!=2
	return
wingettitle,RisTitle,% "ahk_id " RisState[2]
if !instr(RisTitle,RisName)
	return
winclose,% "ahk_id " RisState[2]
settimer,RisCloseConfirm,500
return
RisCloseConfirm:
if (RisState[1]!=2){
settimer,RisCloseConfirm,off
return
}
ifwinexist,Menu ahk_class #32770,是否確定要離開放射線資訊管理(RIS)系統?
controlclick,Button1
else
settimer,RisCloseConfirm,off
return
close_impax:
if (Impax:=ImpaxState)[1]!=2
	return
for k,v in ImpaxControls:=getControls(Impax[2,2]|Impax[2,3])
if ((v.text="登出" || v.text="Logout") && instr(v.classNN,"WindowsForms10.BUTTON.app") && instr(ImpaxControls[k-1].classNN,"WindowsForms10.STATIC.app") && ImpaxControls[k-1].text!=impax_id){
	controlclick,,% "ahk_id " v.hwnd
	return
}
winclose,% "ahk_id " ImpaxState[2,2]|ImpaxState[2,3]
return
close_SLP:
winget,slpList,list,ahk_class SleipnirMainWindow
closingSlp:=0
settimer,closeSLPconfirm,500
loop % slpList {
	winget,slpPath,processpath,% "ahk_id " slpList%a_index%
	if instr(slpPath,root)!=1
		continue
	winclose,% "ahk_id " closingSlp:=slpList%a_index%
	break
}
return
closeSLPconfirm:
ifwinexist,Sleipnir ahk_class #32770
	controlClick,Button1
if closingSlp && !winexist("ahk_id " closingSlp)
	settimer,closeSLPconfirm,off
return
closeSCITE:
winget,sciteList,list,SciTE4AutoHotkey
loop % sciteList {
	winget,scitePath,processpath,% "ahk_id " sciteList%a_index%
	if instr(scitePath,root)!=1
		continue
	winclose,% "ahk_id " sciteList%a_index%
}
return
NumLock::
activeWin:=winexist("A")
;~ MsgBox % activeWin "," ImpaxState[2,1] "," IsObject(ImpaxState)
if (activeWin=ImpaxState[2,1]){
	for k,v in getControls(ImpaxState[2,1])
		if (v.text="BMP_STUDY_MODE" || v.text="BMP_STUDY_MODE_2"){
			controlclick,,% "ahk_id " v.hwnd
			break
		}
}else{
	send {bs}
}
return

activateSelf:
!a::
winget,lastActiveWin,id,A
IfWinNotActive,ahk_id %guiHWND%
{
	winshow,ahk_id %guiHWND%
	winactivate,ahk_id %guiHWND%
	ControlFocus,Edit1,ahk_id %guihwnd%
}
else
	winhide,ahk_id %guiHWND%
if(!hiddenWindows[0]){
	;~ winget,fbWin,list,Facebook
	;~ loop % fbWin
	;~ {
		;~ hiddenWindows[a_index]:=fbWin%a_index%
		;~ winhide,% "ahk_id " fbWin%a_index%
	;~ }
	;~ hiddenWindows[0]:=1
}else {
	hiddenWindows[0]:=0
	while (hwnd:=hiddenWindows.pop())
	winshow,% "ahk_id " hwnd
}
resetHotstringBuffer(-1)
return

~!p::
input,choice,L1 T3,{esc}
if choice=1
	proxy:="10.0.0.1:8118"
else if choice=2
	proxy:="proxy.hospital-n.local:3128"
else
	proxy:=""
regread,proxy_state,HKEY_CURRENT_USER,Software\Microsoft\Windows\CurrentVersion\Internet Settings,ProxyEnable
if !proxy_state
{
	RegWrite,reg_dword,HKEY_CURRENT_USER,Software\Microsoft\Windows\CurrentVersion\Internet Settings,ProxyEnable,1
	RegWrite,reg_sz,HKEY_CURRENT_USER,Software\Microsoft\Windows\CurrentVersion\Internet Settings,ProxyServer,% proxy
	RegWrite,reg_sz,HKEY_CURRENT_USER,Software\Microsoft\Windows\CurrentVersion\Internet Settings,ProxyOverride,<local>
	tooltip,N hospital Proxy On
}
else
{
	RegWrite,reg_dword,HKEY_CURRENT_USER,Software\Microsoft\Windows\CurrentVersion\Internet Settings,ProxyEnable,0
	RegWrite,reg_sz,HKEY_CURRENT_USER,Software\Microsoft\Windows\CurrentVersion\Internet Settings,ProxyServer,% proxy
	tooltip,Proxy Off
}
settimer,tooltip,-5000
return
tooltip:
tooltip
return
^!d::
clipboard=
send ^c
clipwait,1
fileappend,% """" clipboard """`n",words.csv,utf-8
return
#ifwinexist,放射線資訊管理系統(Radiology Information System)
^#tab::
waitKeysUp(A_ThisHotkey)
sleep 100
clipboard=
send ^c
clipwait,1
if !regexmatch(clipboard,"(t|T|y|Y)\w{9}\d",match) && !regexmatch(clipboard,"\b\w{6}\d\b",match)
	return
clipboard:=match
winactivate,% "ahk_id " RisState[2]
searchRisChartNo(RisState[2],match)
return
#ifwinexist
mbutton::
;~ mousegetpos,gestureX1,gestureY1,mouseWin
;~ WinGetClass,mouseWinClass,ahk_id %mouseWin%
;~ winactivate,ahk_id %mouseWin%

gosub gestureStart
return
$mbutton up::
if (!gestureValue){
	oldSendLevel:=a_sendlevel
	SendLevel,0
	send {mbutton}
	SendLevel,% oldSendLevel
}
	
return


~wheeldown::
~wheelup::
;~ if impaxState[1]!=2
	;~ return
if (lastWheelActivateTick && A_TickCount-lastWheelActivateTick<500)
	goto returnWheelDown
mousegetpos,,,mouseWin,mouseControl,2
;~ WinGetClass,mouseWinClass,ahk_id %mouseWin%
if !WinActive("ahk_id " mouseWin) && !((mouseWinClass:=WinGetClass(mouseWin))=="#32770") && !((mouseConClass:=WinGetClass(mouseControl))~="i)combo\w*box") {
	winactivate,% "ahk_id " mouseWin
	;~ WinWaitActive,% "ahk_id " mouseWin,,1
	ControlFocus,,ahk_id %mouseControl%
}

return


#ifwinexist,ahk_group pacs

~wheeldown::
~wheelup::
;~ if impaxState[1]!=2
	;~ return
if (lastWheelActivateTick && A_TickCount-lastWheelActivateTick<500)
	goto returnWheelDown

mousegetpos,,,mouseWin,mouseControl,2

if !WinActive("ahk_id " mouseWin) && !((mouseWinClass:=WinGetClass(mouseWin))=="#32770") && !((mouseConClass:=WinGetClass(mouseControl))~="i)combo\w*box"){
	winactivate,% "ahk_id " mouseWin
	;~ WinWaitActive,% "ahk_id " mouseWin,,1
	ControlFocus,,ahk_id %mouseControl%
}
returnWheelDown:
lastWheelActivateTick:=A_TickCount
return

winget,ProcessName,ProcessName,ahk_id %mouseWin%


if(ProcessName~=MatchPacsProcessName()) && !WinActive("ahk_group pacs"){
	;~ winactivate,% "ahk_id " (impaxState[2,4]>1?(impaxState[2,2]|impaxState[2,3]):impaxState[2,1])
	winactivate,% "ahk_exe " ProcessName
	ControlFocus,,ahk_id %mouseControl%
	winset,AlwaysOnTop,off,simple RIS ahk_class AutoHotkeyGUI
	DllCall("SetWindowPos", "Ptr", WinExist("simple RIS ahk_class AutoHotkeyGUI"), "Ptr", mouseWin, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
}

return



^!tab::
if (Impax:=ImpaxState)[1]!=2
	return
ifwinactive,UniReport ahk_class TMainForm
{	
	wingettitle,str,UniReport ahk_class TMainForm
	clipboard:=str
}else{
	waitKeysUp(A_ThisHotkey)
	clipboard=
	send ^c
	clipwait,1
}
^!tab1:
stopSelectingRow:=true
if !(i:=regexmatch(clip:=clipboard,"\b\w{6}\d\b",match)) && !(j:=regexmatch(clip:=getRisChartNo(RisState[2]),"\b\w{6}\d\b",match))
	return
chartNo:=match
;~ RegExMatch(clipboard, "\b\w{11}\b", accno) || (j && (accno:=getRisAccNo(RisState[2])))
RegExMatch(clipboard, "\b(CT|MR)", examHasCTMR) || (j && RegExMatch(getRisExamItemsAll(RisState[2])[1][1], "\b(CT|MR)", examHasCTMR))
if !j
	RegExMatch(clip, "\d+\W\d+\W\d+", studyDate)
	,studyDate:=dateFormat(studyDate, "yyyy/M/d")
else
	studyDate:=dateFormat(SubStr(getRisExamDate(RisState[2]),1,10), "yyyy/M/d")
WinShow,% "ahk_id " id2:=Impax[2,2]|Impax[2,3]
winactivate,% "ahk_id " id2
bar:=ImpaxBar(id2)
wingetpos,,,,h,ahk_id %id2%
if !(bar.h>h-37)
	controlclick,,% "ahk_id " bar.hwnd
gosub selectChartNo
acc_objectfromwindow(impaxChartnoControl).accValue:=chartNo
impaxSearchListHwnd:=getimpaxSearchListHwnd(ImpaxState)
,pImpaxSearchListCount:=acc_objectfromwindow(impaxSearchListHwnd).accChildCount
controlsend,,{enter},% "ahk_id " impaxChartnoControl
impaxSearchListLoc:=acc_location(acc_objectfromwindow(impaxSearchListHwnd))
CoordMode,mouse,Screen
mousemove,% impaxSearchListLoc.x+impaxSearchListLoc.w//2,% impaxSearchListLoc.y,0
if (studyDate || accno){
	ToolTip % "Selecting row ... "
	stopSelectingRow:=false
	Loop {
		if acc_objectfromwindow(impaxSearchListHwnd).accChildCount!=pImpaxSearchListCount
			break
		Sleep 100
	}until A_Index>15 || stopSelectingRow
	ImpaxSearchListDo({studyDate: studyDate, StudyDescription: examHasCTMR}, "select", ImpaxSearchListChildren:=[], true)

	ToolTip
}
return
#ifwinexist
;~ ~!e::
;~ while(x:=winexist("Microsoft Internet Explorer"))
;~ winkill,ahk_id %x%
;~ return
^!q::
if !(a_priorhotkey=a_thishotkey && A_TimeSincePriorHotkey<300)
	return
winclose,autorun.exe,Quit?
settimer,close_RIS,-1
settimer,close_impax,-500
closeSLPind:=0
settimer,close_SLP,-1
process,close,XLiu.exe
settimer,closeUSBprocess,-1
return



closeUSBprocess:
;~ winget,pList,list
;~ loop % pList {
	;~ winget,pPath,processpath,% "ahk_id " pList%a_index%
	;~ if (instr(pPath,root)=1 && a_scripthwnd!=pList%a_index% )
		;~ winclose,% "ahk_id " pList%a_index%
;~ }
;~ p:=listProcess()[1]
;~ loop,parse,p,|
;~ {
	;~ if instr(GetModuleFileNameEx(a_loopfield),root)
		;~ process,close,% a_loopfield
;~ }

return

killProcesses:
if (partialMode){
	for k,p in ProcessList() {
		if (InStr(p.path, A_ScriptDir)=1 && p.pid!=thisPid)
			WinClose,% "ahk_pid " p.pid
	}
	Sleep 500
	for k,p in ProcessList() {
		if (InStr(p.path, A_ScriptDir)=1 && p.pid!=thisPid){
			process,close,% p.pid
			WinKill,% "ahk_pid " p.pid
		}
			
	}
}else{
	for k,p in ProcessList() {
		if (InStr(p.path, root)=1 && p.pid!=thisPid)
			WinClose,% "ahk_pid " p.pid
	}
	Sleep 500
	for k,p in ProcessList() {
		if (InStr(p.path, root)=1 && p.pid!=thisPid){
			;~ ToolTip % p.name
			process,close,% p.pid
			WinKill,% "ahk_pid " p.pid
		}
	}
}
return

killAhks:
WinGet,ID,List,AHK_class AutoHotkey
ahklist:=[]
Loop,%ID%
{
CID := ID%A_Index%
WinGetTitle,Title,ahk_id %CID%
If Title contains AutoHotKey v
{
Title := SubStr(Title,1,InStr(Title,"-",false,-1,1)-2)
if CID!=thisHwnd && ((partialMode && InStr(title,A_ScriptDir)=1) || (!partialMode && InStr(title,root)=1))
	ahklist.push(CID)
}
Else
{
if CID!=thisHwnd && ((partialMode && InStr(title,A_ScriptDir)=1) || (!partialMode && InStr(title,root)=1))
	ahklist.push(CID)
}
}
for k,v in ahklist
	WinClose,% "ahk_id " v
Sleep 500
for k,v in ahklist {
	process,close,% "ahk_id " v
	WinKill,% "ahk_id " v
}
return

/* currently used 
*/
terminateUSBprocess:
msgbox,1,,Sure?
ifmsgbox,Cancel
return
terminateUSBprocess1:
if partialMode
	goto partialModeUnmount
;~ run AllKill.exe
;~ gosub killProcesses
WinClose,ahk_exe firefox.exe
;~ gosub killAhks
;~ run % A_ScriptDir "\killAll.exe"
settimer,unmountUSB3,-1
;~ process,close,XLiu.exe

;~ gosub closeUSBprocess
;~ winget,pList,list
;~ loop % pList {
	;~ winget,pPath,processpath,% "ahk_id " pList%a_index%
	;~ if (instr(pPath,root)=1 && a_scripthwnd!=pList%a_index% && guiHwnd!=pList%a_index% && !instr(pPath,"Autorun.exe")){
		;~ winclose,% "ahk_id " pList%a_index%
	;~ }
;~ }
;~ sleep 1000
;~ winget,pList,list
;~ loop % pList {
	;~ winget,pPath,processpath,% "ahk_id " pList%a_index%
	;~ if !instr(pPath,"Autorun.exe") && (instr(pPath,root)=1 && a_scripthwnd!=pList%a_index% && guiHwnd!=pList%a_index%) || (pPath=root "\scripts\AutoHotkey\AutoHotkey.exe")  || (pPath=root "\scripts\AutoHotkey\AutoHotkeyU64.exe")  {
		;~ winget,pid,pid,% "ahk_id " pList%a_index%
		;~ process,close,% pid
	;~ }
;~ }

;~ settimer,OnExit,-1000

return

partialModeUnmount:
run, % A_ScriptDir "\AllKill.exe",,hide
ExitApp
return

unmountUSB:
;~ filecopy,% root "\scripts\Autorun\RemoveDrive\Win32\RemoveDrive.exe",% a_mydocuments,1
;~ run,% a_mydocuments "\RemoveDrive.exe " root " -L -w:3000 -s -h -a",% a_mydocuments
filecopy,% root "\software\USBDiskEjector\*.*",% a_mydocuments,1
;~ msgbox
run % a_mydocuments "\USB_Disk_Eject.exe /REMOVELETTER " substr(root,1,1)
exitapp
return

unmountUSBold:
;~ if (a_osversion!="WIN_XP")
	;~ exitapp
filecopy,% root "\software\USBDiskEjector\*.*",% a_mydocuments,1
FileAppend,% "`n@echo off`nping 1.1.1.1 -n 1 -w 2000`n:L1`nIF EXIST " root " (`USB_Disk_Eject.exe /REMOVELETTER " substr(root,1,1) "`nping 1.1.1.1 -n 1 -w 2000`ngoto L1 ) ELSE (`ndel USB_Disk_Eject.exe`ndel USB_Disk_Eject.cfg`ndel unmount.cmd )",% A_MyDocuments "\unmount.cmd",cp0
run,% A_MyDocuments "\unmount.cmd",% A_MyDocuments
exitapp
return

unmountUSB3:
for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name = 'cmd.exe' and CommandLine like '%simpleRISDelegate.cmd%' ")
	TaskKill(process.ProcessID)

TaskKill("ImpaxContextServer.exe")
ejectPath:=root "\software\EjectMedia\" (A_Is64bitOS?"x64":"Win32") "\EjectMedia.exe"
filecopy,% ejectPath,% A_MyDocuments,1
filecopy,% A_ScriptDir "\AllKill.exe",% A_MyDocuments,1
cmd:="@echo off"
cmd.="`nAllKill.exe " root
cmd.="`nping 1.1.1.1 -n 1 -w 30000"
cmd.="`ntaskkill /IM /F AllKill.exe"
cmd.="`ntaskkill /IM /F EjectMedia.exe"
cmd.="`ndel AllKill.exe"
cmd.="`ndel EjectMedia.exe"
cmd.="`ndel EjectMedia.dmp"
cmd.="`ndel k2.cmd"
cmd.="`ndel k.cmd"
f:=A_MyDocuments "\k.cmd"
FileDelete % f
FileAppend,% cmd,% f, cp0
run,% f,% A_MyDocuments,hide

cmd:="@echo off"
cmd.="`nEjectMedia.exe " root " -L -a -w:3000"
f:=A_MyDocuments "\k2.cmd"
FileDelete % f
FileAppend,% cmd,% f, cp0
run,% f,% A_MyDocuments
;~ FileDelete,% cmdPath:=% A_MyDocuments "\unmount.bat"
;~ FileAppend,
;~ (
;~ @echo off
;~ ping 1.1.1.1 -n 1 -w 2000
;~ del EjectMedia
;~ del unmount.bat
;~ taskkill /IM autorun.exe /F /T
;~ ),% cmdPath,cp0


;~ run % """" A_MyDocuments "\EjectMedia.exe"" " root " -L -a -w:3000"
exitapp
return

~^!l::
;~ critical
;~ SetTimer,~^!i,-1
risLoging:=0,waiting:=0,tryLoginRis:=0
if(!alternativeLogin){
	RIS_id:=loginId
}else{
	RIS_id:="H00000"
	settimer,login_IMPAX,-1
}
RisState1:=RisOpened(1)
if(!RisState1[2,1]){
	if(loginRis:=RisState1[1,1]){
		winshow,ahk_id %loginRis%
		winactivate,ahk_id %loginRis%
		gosub login_RIS_thread
	}else if(hiddenRis:=RisState1[2,1] && !winvisible(hiddenRis)){
		winshow,ahk_id %hiddenRis%
		winactivate,ahk_id %hiddenRis%
	}else{
		gosub login_RIS_thread
	}
}
;~ settimer,loginAnotherRis,-60000
;~ settimer,login_RIS,-100
settimer,maximizeImpax,2000
alternativeLogin:=0
return

login_RIS_thread:
return

openAnotherRis:
return 
RisState1:=RisOpened(1)
if(RisState1[1,1]){
	if (RisState1[2,1])
		winhide,% "ahk_id " RisState1[1,1]
	;~ settimer,openAnotherRisRoutine,off
	settimer,openAnotherRis,-60000
	return
}
if !(risPath:=getrispath()) {
	;~ settimer,openAnotherRisRoutine,off
	settimer,openAnotherRis,off
	return
}
run,% risPath,% RegExReplace(RISpath, "\\Menu\.exe$")
;~ settimer,openAnotherRisRoutine,200
while RisState1:=RisOpened(1) {
	IfWinNotExist,% "ahk_id " RisState1[1,1]
		sleep 500
	else 
		break
}
settimer,openAnotherRis,-60000
return


loginAnotherRis:
RisState1:=RisOpened(1)
currentRisCount:=RisState1[2].maxindex()
if (!loginRis:=RisState1[1,1]){
	run % getRisPath(1)
	while !loginRis:=(RisState1:=RisOpened(1))[1,1]
		sleep 200
}
winactivate,ahk_id %loginRis%
winwaitactive,,,3
send % ris_id
winactivate,ahk_id %loginRis%
send {tab}
winactivate,ahk_id %loginRis%
send % ris_pw
winactivate,ahk_id %loginRis%
send {enter} 
while !((RisState1:=RisOpened(1))[2].maxindex() > currentRisCount)
	sleep 200
winhide,% "ahk_id " RisState1[2, currentRisCount+1]
return

~^!i::
settimer,login_impax,-1
return

sig1:
sig1:=(Impax:=ImpaxOpened())[1]=1 && i++<60
return
login_impax:

if (Impax:=ImpaxState)[1]=2
	return
if(Impax[1]=0){
	settimer,restartImpax,300
	run,% A_ProgramFiles "\Agfa\IMPAX Client\AppStart.exe"
	loop
		sleep % 200
	until (ImpaxOpened()[1]||a_index>300)
}

loginText:=GetControlIdByText(controls,"登入")?"登入":"Login"
gosub login_impax2
settimer,login_impax2,2000
return
login_impax2:
if((Impax:=ImpaxOpened())[1]=1 && i++<60){
	for k,v in controls:=GetControls(impaxHwnd:=Impax[2,1])
	if (v.classNN="WindowsForms10.EDIT.app.0.2bf80982") {
		controlsettext,,%IMPAX_id%,% "ahk_id " v.hwnd
		break
	}
	for k,v in controls
	if (v.classNN="WindowsForms10.EDIT.app.0.2bf80981") {
		controlsettext,,%IMPAX_pw%,% "ahk_id " v.hwnd
		break
	}
	for k,v in controls
	if (v.classNN="WindowsForms10.BUTTON.app.0.2bf80981") {
		controlfocus,,% "ahk_id " v.hwnd
		controlsend,,{enter},% "ahk_id " v.hwnd
		break
	}
}else{
	return
}
settimer,restartImpax,off
settimer,login_impax2,off
gosub maximizeImpax
settimer,maximizeImpax,2000
return
maximizeImpax:
WinGet,minmaxImpax,minmax,% "ahk_id " ImpaxState[2,3]
if (minmaxImpax=1)
	settimer,maximizeImpax,off
else
WinMaximize,% "ahk_id " ImpaxState[2,3]
return
restartImpax:
if restartImpaxId:=winexist("重新啟動 ahk_class WindowsForms10.Window.8.app.0.2bf8098")
	controlclick,WindowsForms10.BUTTON.app.0.2bf80982,ahk_id %restartImpaxId%
return

openSimpleRis:
if !simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI"){
	run, % partialMode?commands(root "\AutoHotkey.exe", root "\PacsIE\simpleRIS.ahk"):root "\scripts\Radiology\PacsIE\simpleRIS.exe",% root "\PacsIE",hide
}
return


RisSetDefaultSearch:
if (RisState[1]=2){
	settimer,closeRisError,off
	control,choosestring,所有撰打住院醫師,,% "ahk_id " getNetControl2(RisState[2],"撰打住院醫師","FID_LABEL","撰打住院醫師","WindowsForms10.STATIC.app","","","",1)[1]
	controlfocus,,% "ahk_id " getNetControl2(RisState[2],"報告醫師","FID_LABEL","報告醫師","WindowsForms10.STATIC.app","","","",1)[1]
	
	settimer,RisSetDefaultSearch,off
}
return

closeRisError:
IfWinExist,Menu ahk_class #32770,查無使用者
{
	controlclick,Button1
	if (++RisLoginAttempt)>10 {
		settimer,closeRisError,off
		settimer,RisSetDefaultSearch,off
		RisLoginAttempt:=0
	}
}
ifwinexist,Menu ahk_class #32770,查無
	controlclick,Button1
return
~!q::
winactivate,ahk_exe autorun.exe,Quit?
msgbox,1,,Quit?
ifmsgbox,cancel
return
ExitApp
return

showCursor:
settimer,hideCursor,off
SystemCursor("On")
return

hideCursor:
SystemCursor("Off")
return

onexit:
if (A_ExitReason="Reload")
	ExitApp
;~ ToolTip % A_ExitReason
;~ PostMessage,0x10101,,,,ahk_exe ImpaxContextServer.exe
;~ gosub killProcesses
;~ gosub killAhks
;~ for k,v in AllThreads
	;~ v.ahkTerminate()
if (RisImpaxDecodePw!="")
	for _, key_files in decryptKeyFiles {
		if FileExist(key_files){
			;~ if Crypt.Encrypt.FileEncrypt(key_files, key_files ".enc", RisImpaxDecodePw, 7, 1)
				FileDelete,% key_files 
		}		
	}	

	

	
	
settimer,showCursor,-1
;~ for k,v in mouseHooks
	;~ UnhookWindowsHookEx(v)
impaxMouseHook:=false
;~ UnhookWindowsHookEx(mouseHook)
gosub UnhookWindowsHookEx
WinSessionChange(false)
RegWrite,reg_dword,HKEY_CURRENT_USER,Software\Microsoft\Windows\CurrentVersion\Internet Settings,ProxyEnable,0
while hwnd:=hiddenWindows.pop()
	winshow,% "ahk_id " hwnd
;~ if himc
	;~ DllCall("Imm32.dll\ImmAssociateContext","Ptr", risState[2], "Ptr", himc, "Ptr")

;~ for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name = 'AutoHotkey.exe' or name = 'AutoHotkeyU32.exe' or name = 'AutoHotkeyU64.exe'") {
	;~ if(process.ProcessId=thisPid) || InStr(process.ExecutablePath, root)!=1
		;~ continue
	;~ PostMessage,0x10101,,,,% "ahk_pid " process.ProcessId
	;~ PostMessage,0x10102,,,,% "ahk_pid " process.ProcessId
	;~ WinClose,% "ahk_pid " process.ProcessId
	;~ process,close,% process.ProcessId
	;~ WinKill,% "ahk_pid " process.ProcessId
;~ }
for k,v in ["textHotkey.exe", "capslock_remap_alt.exe", "AutoNum.exe", "RazerNaga.exe", "UIAutomationServer.exe", "ImpaxContextServer.exe", "killUpdate.exe"] {
		WinClose,ahk_exe %v%
		process,close,%v% 
		WinKill,ahk_exe %v%
		s:=RegExReplace(v, "i).exe$", ".ahk") " - AutoHotkey v" 
		WinClose,% s
		WinKill,% s
		TaskKill(v)
}
for k,v in RisOpened(1)
	for x,y in v
		winshow,% "ahk_id " y
;~ process,close,% thisPid

ExitApp


relativeDate(theDay,relative=-1){
	Formattime,d,% theDay,yyyyMMddHHmmss
	d+=%relative%,d
	return d
}

StringUpperFirst(str){
	a:=substr(str,1,1)
	b:=substr(str,2)
	StringUpper,a,a
	return a b
}

AddPeriodEndCapitalizeAll(ByRef str){
	s:=""
	Loop,Parse,str,`n,`r
		s.=AddPeriodEnd(capitalize(trim(A_LoopField))) "`r`n"
	return RegExReplace(s, "is)([a-z] ) +(.)|(.) +( [a-z])", "$1$2")
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

waitKeysUp(keys, timeout=2000){
	if !IsObject(keys){
		hotkey:=RegExReplace(keys, "^[$~\*]","")
		,hotkey:=RegExReplace(hotkey,"i) +up$", "")
		,keys:=[]
		Loop {
			if RegExMatch(Hotkey, "^([<>])?([!^#\+])", match){
				k:=match1="<"?"L":match1=">"?"R":""
				if match2=!
					k.="Alt", keys.push(k)
				else if match2=^
					k.="Ctrl", keys.push(k)
				else if match2=#
					if k=
						keys.push("LWin"), keys.push("RWin")
					else
						k.="Win", keys.push(k)
				else if match2=+
					k.="Shift", keys.push(k)
				Hotkey:=SubStr(Hotkey, StrLen(match)+1)
			}else{
				keys.push(Hotkey)
				break
			}
		}
	}
	Loop {
		AllUp:=true
		for k,key in keys
			AllUp&=!GetKeyState(key)
		Sleep 10
	}until (A_Index>timeout/10) || AllUp
	return AllUp
}

waitClipboard(){
	clipboard=
	Loop 3 {
		send ^c
		ClipWait,0.3
	}until !ErrorLevel
	return clipboard
}

#!b::
#b::
if (RisState[1]!=2 || winactive("ahk_group pacs")) && !__is_CH
	return
simpleRis:=getSimpleRisGuiHwnds()[2]
,editHwnd:=getSimpleRisEditHwnds()[2]

if winactive("ahk_id " simpleRis) {
	newText:=Edit_GetSelection(editHwnd)
	if (newText="")
		newText:=Edit_GetLine(editHwnd)
}else{
	waitKeysUp(A_ThisHotkey)
	sendmessage,0x2021,,,,simple RIS ahk_class AutoHotkeyGUI
	newText:=waitClipboard()

}
if ((newText:=RegExReplace(newText, "(^\s+)|(\s+$)", ""))="") && !()
	return
gosub renewRisReports
;~ RisReports:=getRisReports(RisState[2])
focused:=getFocusedHWND()


if (focused=RisReports[1,1] || winactive("ahk_id " simpleRis)){
	if(__is_CH){
		Edit_GetSel(editHwnd, s, e)
		currentReport:=new ReportImpression(Edit_GetText(editHwnd))
		currentReport.add_impression(StringUpperFirst(trim(new ReportText(newText).toImpression())))
		currentReport.set_text(editHwnd)
		Edit_SetSel(editHwnd, s, e)
		Edit_ScrollCaret(RisReports[1,2])	
	}else{
		controlsettext,,% sentText:=(txt:=controlgettext(RisReports[1,2])) (regexmatch(txt,"\n$")||txt=""?"":"`r`n") StringUpperFirst(trim(new ReportText(newText).toImpression())),% "ahk_id " risreports[1,2]
		Edit_SetSel(RisReports[1,2],strlen(sentText),strlen(sentText))
		Edit_ScrollCaret(RisReports[1,2])	
	}
	
	return
}


paste:="",oldText:=controlgettext(RisReports[1,1])
;~ StringReplace,paste,paste,`r,,all
;~ paste:=RegExReplace(paste,"\s*\n+\s*","`n")
;~ paste:=RegExReplace(paste,"\n+","`n")
;~ paste:=RegExReplace(paste,"\s*\n\s*","; ")
moreDelim:=instr(a_thishotkey,"!")?".":""
if (oldText="") || regexmatch(oldText,"i)History:\s+$") || (regexmatch(oldText,"i)History: ") && regexmatch(oldText,";\s*$")) {
	loop,parse,newText,`n`r
		if (trim(a_loopfield)!="")
			paste.=RegExReplace(trim(a_loopfield),"[^\w\+\)]+$","") "; "
	;~ Controlsettext,,% text:=RegExReplace(sentText:=abbr((oldText=""?"History: ":oldText) paste),"(\d).\r?\n- (\d)","$1.$2"),% "ahk_id " RisReports[1,1]
	text:=RegExReplace(sentText:=abbr((oldText=""?"History: ":oldText) paste),"(\d).\r?\n- (\d)","$1.$2")
} else if InStr(oldText,"  -- ") {
	
	Edit_GetSel(editHwnd, s, e)

	newText:=RegExReplace(newText,"m)^\d*\W+","")
	loop,parse,newText,`n`r%moreDelim%
		if (trim(a_loopfield)!="")
			paste.=AddPeriodEnd(capitalize(trim(a_loopfield)) moreDelim) "`r`n  -- "
	text:= (sentText:= SubStr(oldText, 1, s) paste ) SubStr(oldText, s+1)
	
} else if regexmatch(oldText,"\n([^\n\r\w]+)$",match) {
	newText:=RegExReplace(newText,"m)^\d*\W+","")
	loop,parse,newText,`n`r%moreDelim%
		if (trim(a_loopfield)!="")
			paste.=AddPeriodEnd(capitalize(trim(a_loopfield)) moreDelim) "`r`n" match1
	
	;~ Controlsettext,,% RegExReplace(sentText:=oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2"),% "ahk_id " RisReports[1,1]
	text:=RegExReplace(sentText:=oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2")
} else if regexmatch(oldText,"\n(\d+)([^\n\r\w]+)$",match) {
	newText:=RegExReplace(newText,"m)^\d*\W+","")	
	loop,parse,newText,`n`r%moreDelim%
		if (trim(a_loopfield)!="")
			paste.=AddPeriodEnd(capitalize(trim(a_loopfield)) moreDelim) "`r`n" (++match1) match2
	;~ Controlsettext,,% RegExReplace(sentText:=oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2"),% "ahk_id " RisReports[1,1]
	text:=RegExReplace(sentText:=oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2")
}else if RegExMatch(oldText, "\n([^\n\r\w]+)[^\r\n]+\s*$", match){
	selText:=RegExReplace(selText,"m)^\d*\W+","")	
	loop,parse,selText,`n`r%moreDelim%
		if (trim(a_loopfield)!="")
			paste.=match1 AddPeriodEnd(capitalize(trim(a_loopfield)) moreDelim) "`r`n"
	;~ Controlsettext,,% RegExReplace(sentText:=oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2"),% "ahk_id " RisReports[1,1]
	text:=RegExReplace(sentText:=RegExReplace(oldText, "\s+$", "") "`r`n" capitalize(paste)  match1,"(\d).\r?\n- (\d)","$1.$2")
}else if RegExMatch(oldText, "\n(\d+)([^\n\r\w]+)[^\r\n]+\s*$", match){
	selText:=RegExReplace(selText,"m)^\d*\W+","")	
	loop,parse,selText,`n`r%moreDelim%
		if (trim(a_loopfield)!="")
			paste.=(++match1) match2 AddPeriodEnd(capitalize(trim(a_loopfield)) moreDelim) "`r`n"
	;~ Controlsettext,,% RegExReplace(sentText:=oldText capitalize(paste),"(\d).\r?\n- (\d)","$1.$2"),% "ahk_id " RisReports[1,1]
	text:=RegExReplace(sentText:=RegExReplace(oldText, "\s+$", "") "`r`n" capitalize(paste)  ++match1,"(\d).\r?\n- (\d)","$1.$2")
}
controlsettext,,% text, % "ahk_id " RisReports[1,1]
Edit_SetSel(RisReports[1,1],len:=strlen(sentText),len)
Edit_ScrollCaret(RisReports[1,1])
if (simpleRis){
	;~ controlget,editHwnd,hwnd,,Scintilla1,ahk_id %simpleRis%
	;~ controlsettext,,% text, % "ahk_id " editHwnd
	Edit_SetText(editHwnd, text)
	
	Edit_SetSel(editHwnd,len,len)
	Edit_ScrollCaret(editHwnd)
}
tooltip,% "History added"
settimer,tooltip,-1000
return


abbr(str){
	str:=RegExReplace(str,"status post","s/p")
	str:=RegExReplace(str,"squamous cell carcinoma","SCC")
	str:=RegExReplace(str,"hepatocellular carcinoma","HCC")
	str:=RegExReplace(str,"left lower lobe","LLL")
	str:=RegExReplace(str,"right lower lobe","RLL")
	str:=RegExReplace(str,"left upper lobe","LUL")
	str:=RegExReplace(str,"right upper lobe","RUL")
	str:=RegExReplace(str,"right middle lobe","RML")
	str:=RegExReplace(str,"transarterial embolization","TAE")
	return str
}
capitalize(str){
	a:=substr(str,1,1)
	StringUpper,a,a
	return a substr(str,2)
}

;~ ~capslock up::
;~ keywait,capslock,t1
;~ mousegetpos,mx,my
;~ if (mx>a_screenwidth || my>a_screenheight)
	;~ gosub activateSimpleRis
;~ else if winactive("ahk_exe Sleipnir.exe") || winactive("ahk_exe firefox.exe")
	;~ gosub activateSimpleRis
;~ return

#ifwinactive,ahk_group RisGroup	


MButton::
PostMessage,0x2024,,,,RazerNaga_main ahk_class AutoHotkeyGUI
return



+#v::
!#v::
+!#v::
#v::
^+!#v::
if WinExist("YCH_MAMMO_AHK_main ahk_class AutoHotkeyGUI"){
	PostMessage,0x10103,,,,YCH_MAMMO_AHK_main ahk_class AutoHotkeyGUI
	return
}
_get_high_cp_ctmr(A_ThisLabel)
, emptyMem()
return

_get_high_cp_ctmr(thisHotkey){
	global reportdir, ____
	includeAP:=!!InStr(thisHotkey,"+")
	,excludeRequest:=!!InStr(thisHotkey, "!")
	,includeCAP:=!!InStr(thisHotkey, "^")
	
	if !(ret:=preprocessRisList())
		return
	for var, v in ret
		%var%:=v

	ToolTip % "Processing " A_ThisFunc
	;~ Sleep 5000
	;~ ToolTip 


	allAccNos:=[], mp:=[]
	;~ ,chartNoCol:=ReportList.colNos["ChartNo"]
	;~ ,AccNoCol:=ReportList.colNos["AccNo"]
	;~ ,examNameCol:=ReportList.colNos["ExamName"]
	;~ ,examDateCol:=ReportList.colNos["ExamDate"]


	reported:=[]
	for k,v in reportList {
		if k=1
			continue
	
		chartNo:=v[chartNoCol]
		,accNo:=v[AccNoCol]
		,examName:=v[examNameCol]
		,examDate:=v[examDateCol]
		,reportVS:=v[reportVScol]
		
		;~ ,last_add:=false
		;~ ,examName:=InStr(examName,"CT")=1?"CT":InStr(examName, "MRI")=1?"MR":""
		
		
		if InStr(reportVS, "陳醫師") || (excludeRequest && InStr(examName, "Requesting")) 
			|| !(examName~="(\bCT\b|\bMR)") || (InStr(v[statusCol], "assign")) 
			|| InStr(examName,"Low Dose Chest CT without contrast (for Lung ca study)")
;~			|| FileExistValid(reportDir "\" accNo " " chartNo ".txt") 
;~			|| FileExistValid(reportdir "\" __CryptStr(accNo " "  chartNo,____) ".txt")
			continue
		
		if (v[statusCol]="已發報告")
			reported[accNo]:=1
		
		;~ if(k>1){
		if mp.haskey(examDate chartNo)
			mp[examDate chartNo].push(accNo " " examName)
		else
			mp[examDate chartNo]:=[accNo " " examName]
		;~ }
		
		;~ for x,y in ["AccNo", "examName", "examDate", "chartNo"]
			;~ last_%y%:=%y%
	}

	;~ if (last_add || k=1)
		;~ allAccNos.push(last_accNo)

	for k,v in mp {
		;~ if InStr(k, "5500222")
			;~ a:=1
	
		if (v.length()=1 && !(v[1]~="i)Offering|Extremit"))
			|| (includeAP && v.length()=2 && ((v[1]~="i)(Abdomen|Pelvis)$" && v[2]~="i)(Abdomen|Pelvis)$") 
			|| (v[1]~="i)(Brain|Spine|Neck)$" && v[2]~="i)(Brain|Spine|Neck)$") || ((v[1] "|" v[2] )~="i)^(?:[^\|]*chest\|?()|[^\|]*abdomen\|?()|[^\|]*pelvis\|?()){2}\1\2$"))) 
			|| (includeAP && v.length()=3 && !InStr(v[1] "|" v[2] "|" v[3], "with/") && (v[1] "|" v[2] "|" v[3])~="i)^(?:[^\|]*chest\|?()|[^\|]*abdomen\|?()|[^\|]*pelvis\|?()){3}\1\2\3$") 
			|| (excludeRequest && v.length()=2 && ((v[1] "|" v[2] )~="i)^(?:[^\|]*brain\|?()|[^\|]*chest\|?()|[^\|]*abdomen\|?()){2}\1\2$"))
			|| (includeCAP && v.length()=3 && (((v[1] "|" v[2] "|" v[3] )~=RegExItems(["chest","abdomen","pelvis"]))
			   || ((v[1] "|" v[2] "|" v[3] )~=RegExItems(["chest","abdomen","brain"])) 
			   || ((v[1] "|" v[2] "|" v[3] )~=RegExItems(["chest","abdomen","neck"]))
			   || ((v[1] "|" v[2] "|" v[3] )~=RegExItems(["chest","brain","neck"]))))
			for x,y in v
				if !reported.haskey(thisAccNo:=RegExReplace(y, "s) .+$", ""))
					allAccNos.push(thisAccNo)
		
	}
	total=0
	focusFirst=
	for x,y in allAccNos {
		rn:=ReportList.getRow("AccNo", y).rowNo
		if !focusFirst
			(focusFirst:=RisListRowsAcc[rn]).accSelect(ComObj(3,3),0)
			
		RisListRowsAcc[rn].accSelect(ComObj(3,8),0), total++
	}
	focusFirst.accSelect(ComObj(3,1),0)
	ToolTip % "Done!`nTotal: " total
	settimer,ToolTip,-2000
	
	return
}


#space::
gosub focusImpression
return


!f4::
winclose,放射線資訊管理系統(Radiology Information System) ahk_exe Menu.exe
return


F5::
;~ controlclick,,% "ahk_id " getNetControl2(RisOpened()[2],"IMPAX","cmdDs3000","IMPAX","WindowsForms10.BUTTON.app","","","",0)[1]
if(WinExist("simple RIS ahk_class AutoHotkeyGUI"))
	PostMessage,0x2026,,,,simple RIS ahk_class AutoHotkeyGUI
else
	risOpenStudyImpax(RisState[2]),risOpenOldStudy(RisState[2])
return


F4::
;~ PostMessage,0x2031,3000,1,,prettyOldHx_main ahk_class AutoHotkeyGUI
;~ controlclick,,% "ahk_id " getNetControl2(RisOpened()[2],"臨床報告","cmdHisReport","臨床報告","WindowsForms10.BUTTON.app","","","",0)[1]
getNetAcc(RisOpened()[2],"cmdHisReport","WindowsForms10.BUTTON").accDoDefaultAction()
return


^down::
^up::
focused:=getFocusedHWND()
RisHistory:=getRisHistoryId(RisState[2])
ControlFocus,,ahk_id %RisHistory%
KeyWait,Ctrl,T0.4
if ErrorLevel
	send {Ctrl Up}
controlsend,,% "{" substr(a_thishotkey,2) "}",ahk_id %RisHistory%
controlfocus,,ahk_id %focused%
return

^i::
imageNumber:=getSEIM(ImpaxState)
if (imageNumber[1]!="")
	send % "SE" imageNumber[1] " IM" imageNumber[2]
return

^+d::
^d::
keywait,shift,t1
clipboard:=(instr(a_thishotkey,"+")?"History: ":"") getIndicationText(RisState[2]) ";"
send ^v
return


~^r::
~+^r::
RisState:=RisOpened()
if(RisState[1]!=2)
	return
shiftPressed:=GetKeyState("Shift")

control,choosestring,未發送,,% "ahk_id " getNetControl2(RisState[2],"狀態","FID_LABEL","狀態","WindowsForms10.STATIC.app","","","",1)[1]
control,choosestring,所有診別,,% "ahk_id " getNetControl2(RisState[2],"診別","FID_LABEL","診別","WindowsForms10.STATIC.app","","","",1)[1]
control,choosestring,所有報告醫師,,% "ahk_id " getNetControl2(RisState[2],"報告醫師","FID_LABEL","報告醫師","WindowsForms10.STATIC.app","","","",1)[1]
control,choosestring,所有撰打住院醫師,,% "ahk_id " getNetControl2(RisState[2],"撰打住院醫師","FID_LABEL","撰打住院醫師","WindowsForms10.STATIC.app","","","",1)[1]
control,choosestring,所有執行住院醫師,,% "ahk_id " getNetControl2(RisState[2],"執行住院醫師","FID_LABEL","執行住院醫師","WindowsForms10.STATIC.app","","","",1)[1]
controlsettext,,% "",% "ahk_id " getNetControl2(RisState[2],"病歷號","FID_LABEL","病歷號","WindowsForms10.STATIC.app","","","",1)[1]

WinGetTitle,title,% "ahk_id " RisState[2]
branch:="N總院"
if RegExMatch(title, " @ (\w+)$", titlebranch){
	titlebranchMapping:={T0: "N總院", A0: "C分院", T4: "H分院", Y0: "Y分院"}
	if titlebranchMapping.haskey(titlebranch1)
		branch:=titlebranchMapping[titlebranch1]
	control,choosestring,% shiftPressed?"一般攝影":"所有類別",,% "ahk_id " getNetControl2(RisState[2],"檢查類別","FID_LABEL","檢查類別","WindowsForms10.STATIC.app","","","",1)[1]
}else{
	control,choosestring,所有類別,,% "ahk_id " getNetControl2(RisState[2],"檢查類別","FID_LABEL","檢查類別","WindowsForms10.STATIC.app","","","",1)[1]
	if InStr(title, "HC")
		branch:="H分院"
	else if (shiftPressed){
		branch:="Y分院"
	}else{
		RisListRows:=acc_children(acc_objectfromwindow(getRisList(RisState[2])))
		,chartNoCol:=0
		for k,v in acc_children(RisListRows[1])
			if (v.accValue = "病歷號"){
				chartNoCol:=k
				break
			}
		if (chartNoCol){
			chartNo:=acc_children(RisListRows[2])[k].accValue
			if (chartNo~="i)^Y")
				branch:="Y分院"
		}
	}	
}

control,choosestring,% branch,,% "ahk_id " (test:=getNetControl2(RisState[2],"檢查地","FID_LABEL","檢查地","WindowsForms10.STATIC.app","","","",1))[1]
;~ Gui +LastFound +OwnDialogs +AlwaysOnTop
return


+^#!n::
^#!n::
_get_chest_abd_spine_XR(A_ThisLabel)
, emptyMem()
return

_get_chest_abd_spine_XR(thisHotkey){
	global reportdir, ____
	;~ KeyWait,Shift,D T1
	if(shiftPressed:=InStr(thisHotkey, "+"))
		showTooltip("CXR OPD & ER only",1000)
	
	if !(ret:=preprocessRisList())
		return
	for var, v in ret
		%var%:=v
	;~ ToolTip % "Click first row"
	;~ Sleep 5000
	;~ ToolTip 
	total=0
	focusFirst=
	for k, row in reportList {
		accNo:=row[accNoCol], chartNo:=row[chartNoCol]
		if (row[statusCol]!="已發報告" && !(row[examNameCol]~="i)^CT|^MR") && (row[examNameCol]~="i)spine|chest|abdomen") && !(row[examNameCol]~="TST or") && !InStr(row[reportVScol], "陳醫師")) 
			&& !(FileExistValid(reportDir "\" accNo " " chartNo ".txt") 
			|| FileExistValid(reportdir "\" __CryptStr(accNo " "  chartNo,____) ".txt")) 
			&& (!shiftPressed || (row[examNameCol]~="i)Chest\W+PA View" && !InStr(row[IOEcol], "住院"))) {
			if !focusFirst
				(focusFirst:=RisListRowsAcc[k]).accSelect(ComObj(3,3),0)
			RisListRowsAcc[k].accSelect(ComObj(3,8),0), total++
		}
	}
	focusFirst.accSelect(ComObj(3,1),0)
	ToolTip % "Done!`nTotal: " total
	settimer,ToolTip,-2000
	return 

}


preprocessRisList(){
	global RisState
	static RisListRowsAcc, reportList
	ToolTip % "parsing ... "
	
	clipboardTemp:=clipboard
	if InStr(clipboardTemp, "檢查日") && InStr(clipboardTemp, "病歷號") && InStr(clipboardTemp, "檢查名稱") {
		useClip:=true
	}else
		useClip:=false
	
	RisListHwnd:=getRisList(RisState[2])
	,RisListAcc:=acc_objectfromwindow(RisListHwnd)
	
	
	ret :=[]
	
	if !(useClip) { ; && (reportList:=parseDataGrid2("", RisState[2],"", "", true, false, false, true)).length() == RisListAcc.accChildCount-2){
		;~ if reportList.length()>0
			;~ ToolTip % reportList.length() "," RisListAcc.accChildCount
		
		
		
		winactivate,% "ahk_id " RisState[2]

		RisListRowsAcc:=acc_children(RisListAcc)
		Loop 3 {
			reportList:=parseDataGrid2(RisListHwnd,"",RisListRowsAcc, 20)
		}until reportList.length()>1
		
		
	}else{
		newReportList:=parseDataGrid2("", RisState[2],"", "", true, false, false, true)
		if(reportList.length()!=newReportList.length())
			RisListRowsAcc:=acc_children(RisListAcc)
		reportList:=newReportList
			;~ ,showTooltip(reportList.length() "," RisListRowsAcc.length())
	}
	ToolTip 	
	
	if !(reportList.length()>1){
		MsgBox % "Can't get report list!"
		return 0
	}
	
	;~ unselectAllRisList(RisListRowsAcc)
	for k,v in reportList[1] {
		if (v="照會單號") {
			AccNoCol:=k
		}
		if (v="病歷號") {
			chartNoCol:=k
		}
		if (v="檢查名稱") {
			examNameCol:=k
		}
		if (v="狀態") {
			statusCol:=k
		}
		if (v="檢查日") {
			examDateCol:=k
		}	
		if (v="報告醫師") {
			reportVScol:=k
		}	
		if (v="診別") {
			IOEcol:=k
		}	
	}
	
	for k,varName in ["RisListHwnd","RisListRowsAcc","reportList","AccNoCol","chartNoCol","examNameCol","statusCol","examDateCol","reportVScol","IOEcol"]
		ret[varName] := %varName%
	;~ Sleep 2000
	return ret
}

#g::
_unselect_VS()
return

_unselect_VS(){
	global RisState
	RisListHwnd:=getRisList(RisState[2])
	,RisListRowsAcc:=acc_children(acc_objectfromwindow(RisListHwnd))

	for k,v in acc_children(RisListRowsAcc[1]) {
		if (v.accValue="報告醫師") {
			reportVScol:=k
			break
		}	
	}
	
	for k,v in RisListRowsAcc {
		cells:=acc_children(v)
		,reportVS:=cells[reportVScol].accValue
		if (reportVS~="Y分院醫師|骨骼肌肉")
			v.accSelect(ComObj(3,16))
	}
	MsgBox % "Done!"
}

+#h::
#h::
_search_fx_op_hx()
, emptyMem()
return
_search_fx_op_hx(){
	global _search_fx_op_hx_allChartNoArr, _search_fx_op_hx_allChartNo, _search_fx_op_hx_allChartNoInd, partialMode, _search_fx_op_hx_RisListHwnd, _search_fx_op_hx_unselect, sid, thisHwnd,____, reportDir
	thread,Priority,-1
	unselect:=!!InStr(A_ThisHotkey,"+")
	if !(ret:=preprocessRisList())
		return
	for var, v in ret
		%var%:=v

	unselectAllRisList(RisListRowsAcc)
	,FirstSelect:=true
	if FileExist(resultPath:=A_ScriptDir "\searchOpHxResults.txt") {
		;~ MsgBox, 4, , Apply last results?
		;~ IfMsgBox,Yes
		if(false)
		{
			
			Loop,read,% resultPath
			{
				a_LoopReadLine_:=Crypt.Encrypt.StrDecrypt(a_LoopReadLine, ____,7,6)
				,arr:=[]
				Loop,parse,a_LoopReadLine_,`,
					arr.push(Trim(A_LoopField))
				
				found:=false
				total=0
				focusFirst=
				if (arr[1]=RisListHwnd){
					row:=RisListRowsAcc[arr[2]]
					if (acc_children(row)[AccNoCol].accValue=arr[3]){
						if !focusFirst
							(focusFirst:=row).accSelect(ComObj(3,3),0)
						row.accSelect(ComObj(3,8),0), found:=true, total++
					}
						
				}
				
				if (!found){
					if (foundRow:=reportList.getRow("AccNo", arr[3])) {
						if !focusFirst
							(focusFirst:=RisListRowsAcc[foundRow.rowNo]).accSelect(ComObj(3,3),0)
						RisListRowsAcc[foundRow.rowNo].accSelect(ComObj(3,8),0), total++
					}
						
				}
				focusFirst.accSelect(ComObj(3,1),0)
				
			}
			MsgBox % "Done!`nTotal: " total
			return
		}else{
			;~ FileDelete,% resultPath
		}
	}
	;~ ToolTip % "Click first row"
	;~ Sleep 5000
	;~ ToolTip 
	if !checksid(sid) && !sid:=askForPortalIdPw() {
		MsgBox % "Can't login!"
		return
	}
	

	ThreadMax:=30
	,ThreadCount:=0
	,ThreadPool:=[]

	,finished:=0
	,rowCount:=(RisListRowAccTotal:=RisListRowsAcc.maxindex())-1

	;~ ,RisListRowAccInd:=1
	,allChartNoInd:=1
	,allChartNo:=[]
	,allChartNoArr:=[]
	for k,reportListRow in ReportList {
		ch:=chartNo:=reportListRow[chartNoCol]	
		,accNo:=reportListRow[AccNoCol]
		
		if (k=1) || instr(reportListRow[reportVScol],"陳醫師") || reportListRow[statusCol]="已發報告"
			;~ || ((reportListRow[examNameCol]~="i)^(Chest|Abdomen)") && !InStr(reportListRow[IOEcol], "門診"))
			|| ((reportListRow[examNameCol]~="i)^(Chest|Abdomen)"))
			|| ((reportListRow[examNameCol]~="i)spine"))
			|| FileExistValid(reportDir "\" accNo " " chartNo ".txt") 
			|| FileExistValid(reportdir "\" __CryptStr(accNo " "  chartNo,____) ".txt")

			continue
		
		if allChartNo.haskey(ch)
			allChartNo[ch].push({ind: k, accNo: accNo, examDate: reportListRow[examDateCol], examName: reportListRow[examNameCol]})
		else
			allChartNo[ch]:=[{ind: k, accNo: accNo, examDate: reportListRow[examDateCol], examName: reportListRow[examNameCol]}]
			,allChartNoArr.push(ch) 
	}
	for k,var in ["allChartNoArr","allChartNo","allChartNoInd","RisListHwnd","unselect"]
		varName:="_search_fx_op_hx_" var
		,%varName% := %var%
	
	searchOpHx()
	return

}

		
searchOpHx(){
	global _search_fx_op_hx_allChartNoArr, _search_fx_op_hx_allChartNo, _search_fx_op_hx_allChartNoInd, partialMode, _search_fx_op_hx_RisListHwnd, _search_fx_op_hx_unselect, sid, thisHwnd
	
	
		;~ Loop {
		process_count:=0
		for iii,v in ProcessList()
			if (v.name="searchOpHx.exe") && ( (++process_count>20 )) {
				settimer,searchOpHx,-400
				return
			}
			
	;~ }
	;~ if k=6
		;~ return
	for k,var in ["allChartNoArr","allChartNo","allChartNoInd","RisListHwnd","unselect"]
		varName:="_search_fx_op_hx_" var
		,%var% := %varName%
	;["RisListHwnd", "rowNo", "unselect", "chartNo", "AccNo", "examDate", "sid", "hwnd"]
 	thisChartNo:=allChartNoArr[allChartNoInd]
	,chartNoInfo:=allChartNo[thisChartNo]
	,rowNoArr:=[], accNoArr:=[], examDateArr:=[], examNameArr:=[]
	for _, info in chartNoInfo
		rowNoArr.push(info.ind)
		,accNoArr.push(info.accNo)
		,examDateArr.push(info.examDate)
		,examNameArr.push(info.examName)
	
	
	ProcessLimit("searchOpHx.exe", 30)
	
	run % """" A_ScriptDir "\searchOpHx.exe"""  (partialMode?" """ A_ScriptDir "\searchOpHx.ahk"" ":"")    " """ RegExReplace(jxon_dump({RisListHwnd: RisListHwnd
		, rowNo: rowNoArr
		, unselect: unselect
		, chartNo: thisChartNo
		, AccNo: accNoArr
		, examDate: examDateArr
		, examName: examNameArr
		, sid: sid
		, hwnd: thisHwnd}), """", """""") """"
searchOpHxLoopEnd:
	if ++_search_fx_op_hx_allChartNoInd>allChartNoArr.length() 
		goto searchOpHxFinish
	else
		settimer,searchOpHx,-400

	
	return

	searchOpHxFinish:
	MsgBox % "Finished!"
	SetTimer,ToolTip,-2000
	return

}	


reportListProgress(k, ByRef rowAcc, ByRef cellsAcc){
	PacsHx:=getPacsHx(sid,chartNo)
	
}

+#j::
#j::
MouseGetPos,changeVSx,changeVSy
KeyWait,LShift,T0.5
if !InStr(A_ThisHotkey, "+")
	inputbox,changeVS,改派VS,,,150,120
else
	changeVS:="YCH"
	,RisReports:=getRisReports(RisState[2])
	,oldFindings:=ControlGetText(RisReports[1,1])
	,oldImpression:=ControlGetText(RisReports[1,2])
	,Edit_GetSel(RisReports[1,1], oldSel1s, oldSel1e)
	,Edit_GetSel(RisReports[1,2], oldSel2s, oldSel2e)
if !errorlevel || InStr(A_ThisHotkey, "+") {
	sleep 100
	mouseclick,r,% changeVSx,% changeVSy,1,1
	sleep 100
	mouseclick,l,20,10,1,1,,r
	winwait,報告醫師改派 ahk_exe Menu.exe,,1
	if ErrorLevel 
		return
	WinGetTitle,title,% "ahk_id " RisState[2]
	
	if (changeVS="YCHH")
		changeVS:="陳醫師HC"
	if (changeVS="YCHC")
		changeVS:="A00000 陳醫師"
	else if InStr(ControlGetText((getNetControl2(RisState[2],"檢查地","FID_LABEL","檢查地","WindowsForms10.STATIC.app","","","",1))[1]),"Y分院")  {
		if (changeVS="YCH")
			changeVS:="YCH*"
		else if (changeVS=" ")
			changeVS:="Y分院醫師"
	}
	control,choosestring,%changeVS%,,% "ahk_id " getNetAcc(changeVShwnd:=winexist("報告醫師改派 ahk_exe Menu.exe"),"cboReAssignDoctor","COMBOBOX",0,0)
	control,choosestring,% (changeVS="err")?"影像不足":"Group 分派",,% "ahk_id " control:=getNetAcc(changeVShwnd,"cboReasonCode","COMBOBOX",0,0)
	controlfocus,,% "ahk_id " getNetAcc(changeVShwnd,"cmdAssign","WindowsForms10.BUTTON",0,0)

}

if InStr(A_ThisHotkey, "+"){
	ControlClick,改派,報告醫師改派 ahk_exe Menu.exe
	winwait,kReport ahk_exe Menu.exe,% "是否確定要改派?",3
	if ErrorLevel 
		return
	Sleep 500
	Loop {
		ControlClick,Button1,kReport ahk_exe Menu.exe,是否確定要改派?
		Sleep 500
	} until !WinExist("kReport ahk_exe Menu.exe","是否確定要改派?") || A_Index>10
	
	
	winwait,kReport ahk_exe Menu.exe,% "成功",3
	if ErrorLevel 
		return
	Sleep 500
	Loop {
		ControlClick,Button1,kReport ahk_exe Menu.exe,成功
		Sleep 500
	} until !WinExist("kReport ahk_exe Menu.exe","成功") || A_Index>10
	
	
	searchRisChartNo(RisState[2],thisAccNo:=getRisAccNo(RisState[2]), thisChartNo:=getRisChartNo(RisState[2]))
	,RisListRowsAcc:=acc_children(acc_objectfromwindow(RisListHwnd:=getRisList(RisState[2])))
	for k,v in acc_children(RisListRowsAcc[1])
		if (v.accValue="照會單號"){
			AccNoCol:=k
			break
		}
	Loop {
		Sleep 500
		
		
		for k,v in RisListRowsAcc:=acc_children(acc_objectfromwindow(RisListHwnd:=getRisList(RisState[2])))
			if (acc_children(v)[AccNoCol].accValue=thisAccNo){
				loc:=acc_location(v)
				mouseclick,l,% loc.x+100,% loc.y+10,2,0
				winwait,kReport ahk_exe Menu.exe,% "報告資料已經修改,是否暫存報告？",3
				if ErrorLevel 
					return
				Sleep 500
				Loop {
					ControlClick,Button2,kReport ahk_exe Menu.exe,% "報告資料已經修改,是否暫存報告？"
					Sleep 500
				} until !WinExist("kReport ahk_exe Menu.exe","報告資料已經修改,是否暫存報告？") || A_Index>10
				
				break 2
			}
			
	}
	
	setReportText(oldFindings, oldImpression, "", 1)
	,Edit_SetSel(RisReports[1,1], oldSel1s, oldSel1e)
	,Edit_SetSel(RisReports[1,2], oldSel2s, oldSel2e)
}else if(changeVS~="i)^YCH|YCHH$"){
	ControlClick,改派,報告醫師改派 ahk_exe Menu.exe
	winwait,kReport ahk_exe Menu.exe,% "是否確定要改派?",3
	if ErrorLevel 
		return
	Sleep 500
	Loop {
		ControlClick,Button1,kReport ahk_exe Menu.exe,是否確定要改派?
		Sleep 500
	} until !WinExist("kReport ahk_exe Menu.exe","是否確定要改派?") || A_Index>10
	
}
return

#IfWinActive,ahk_exe Menu.exe
~^j::
gosub ~^r
control,choosestring,% "J分院",,% "ahk_id " (test:=getNetControl2(RisState[2],"檢查地","FID_LABEL","檢查地","WindowsForms10.STATIC.app","","","",1))[1]
return
~^m::
if (RisState[1]=2){
	if (modalityHwnd:=getNetControl2(RisState[2],"檢查類別","FID_LABEL","檢查類別","WindowsForms10.STATIC.app","","","",1)[1]) {
		inputbox,modalityInput,檢查類別,,,150,120
		if !errorlevel {
			if trim(modalityInput)=""
				control,choosestring,所有類別,,% "ahk_id " modalityHwnd
			else if (modalityInput="1" || modalityInput="plain")
				control,choosestring,一般攝影,,% "ahk_id " modalityHwnd
			else if (modalityInput="2" || modalityInput="special")
				control,choosestring,特殊攝影,,% "ahk_id " modalityHwnd
			else
				control,choosestring,%modalityInput%,,% "ahk_id " modalityHwnd
			
			
		}
	}
}
return
#IfWinActive

~^n::
if(RisState[1]!=2)
	return
control,choosestring,所有報告醫師,,% "ahk_id " getNetControl2(RisState[2],"報告醫師","FID_LABEL","報告醫師","WindowsForms10.STATIC.app","","","",1)[1]
control,choosestring,所有撰打住院醫師,,% "ahk_id " getNetControl2(RisState[2],"撰打住院醫師","FID_LABEL","撰打住院醫師","WindowsForms10.STATIC.app","","","",1)[1]
control,choosestring,所有執行住院醫師,,% "ahk_id " getNetControl2(RisState[2],"執行住院醫師","FID_LABEL","執行住院醫師","WindowsForms10.STATIC.app","","","",1)[1]
controlsettext,,% "",% "ahk_id " getNetControl2(RisState[2],"病歷號","FID_LABEL","病歷號","WindowsForms10.STATIC.app","","","",1)[1]
control,choosestring,CT,,% "ahk_id " getNetControl2(RisState[2],"檢查類別","FID_LABEL","檢查類別","WindowsForms10.STATIC.app","","","",1)[1]
control,choosestring,未發送,,% "ahk_id " getNetControl2(RisState[2],"狀態","FID_LABEL","狀態","WindowsForms10.STATIC.app","","","",1)[1]
control,choosestring,急診,,% "ahk_id " getNetControl2(RisState[2],"診別","FID_LABEL","診別","WindowsForms10.STATIC.app","","","",1)[1]
;~ control,choosestring,N總院,,% "ahk_id " getNetControl2(RisState[2],"檢查地","FID_LABEL","檢查地","WindowsForms10.STATIC.app","","","",1)[1]
WinGetTitle,title,% "ahk_id " RisState[2]
control,choosestring,% InStr(title, "HC")?"H分院":"N總院",,% "ahk_id " (test:=getNetControl2(RisState[2],"檢查地","FID_LABEL","檢查地","WindowsForms10.STATIC.app","","","",1))[1]

return
~^f::
if (RisState[1]=2){
	;~ for k,v in RISarr:=getControls(RisState[2]) {
		;~ if(v.text="報告醫師"){
			;~ reportDrHwnd:=RISarr[k+1].hwnd
			;~ break
		;~ }
	;~ }
	if (reportDrHwnd:=getNetControl2(RisState[2],"報告醫師","FID_LABEL","報告醫師","WindowsForms10.STATIC.app","","","",1)[1]) {
		inputbox,reportDrInput,報告VS,,,150,120
		if (!errorlevel){
			ControlGetText,originalSelectedVS,,% "ahk_id " reportDrHwnd
			
			if RegExMatch(reportDrInput, "i)(\w{2,3})(mm|\*\*)", vs_abrv){
				control,choosestring,%  StringUpper(vs_abrv1) "**",,% "ahk_id " reportDrHwnd
			}else if RegExMatch(reportDrInput, "i)(\w{2,3})(hc|aa)", vs_abrv){
				vs_abrv1:=StringUpper(vs_abrv1)
				control,ChooseString,% vs_abrv1 " ",,% "ahk_id " reportDrHwnd
				ControlGetText,rowVS,,% "ahk_id " reportDrHwnd
				if RegExMatch(rowVS, "i)^" vs_abrv1 " ([^\r\n]+)$", vsFullname){
					if vs_abrv2=hc
						control,choosestring,% vsFullname1 "HC",,% "ahk_id " reportDrHwnd
					else if vs_abrv2=aa
					{
						if !risVsList.SetCapacity(0)
							RisVsList:=[]
						if risVsList.haskey(vsFullname1)
							control,choosestring,% risVsList[vsFullname1],,% "ahk_id " reportDrHwnd
						else
							Loop {
								control,choose,% A_Index,,% "ahk_id " reportDrHwnd
								ControlGetText,rowVS,,% "ahk_id " reportDrHwnd
								if (lastRowVS=rowVS)
									break
								lastRowVS:=rowVS
								if RegExMatch(rowVS, "^A\d+ ([^\r\n]+)$", ncc_vs){
									risVsList[ncc_vs1]:=rowVS
									if (vsFullname1=ncc_vs1){
										;~ control,choosestring,% rowVS,,% "ahk_id " reportDrHwnd
										break
									}
								}
							}
						
					}
				}else{
					
				}
				;~ vs_list:=[]
				
				;~ vs_list_len:=vs_list.length()
				;~ Loop {
					;~ if vs_list_len {
						;~ if A_Index>vs_list_len
							;~ break
						;~ rowVS:=vs_list[A_Index]
					;~ }else{
						;~ control,choose,% A_Index,,% "ahk_id " reportDrHwnd
						;~ ControlGetText,rowVS,,% "ahk_id " reportDrHwnd
						;~ if (lastRowVS=rowVS)
							;~ break
						;~ vs_list.push(lastRowVS:=rowVS)
					;~ }
					;~ if RegExMatch(rowVS, "i)^" vs_abrv1 " ([^\r\n]+)$", vsFullname){
						;~ if vs_abrv2=hc
							;~ control,choosestring,% vsFullname1 "HC",,% "ahk_id " reportDrHwnd
						
						;~ break
					;~ }
				;~ }
				;~ if(vs_abrv2="aa"){
					;~ for k,rowVS in vs_list
						;~ if RegExMatch(rowVS, "^A\d+ " vsFullname1){
							;~ control,choosestring,% rowVS,,% "ahk_id " reportDrHwnd
							;~ break
						;~ }
				;~ }
			}else{
				control,choosestring,% (reportDrInput:=trim(reportDrInput))=""?"所有報告醫師":reportDrInput " ",,% "ahk_id " reportDrHwnd
			}
		}
			
	}
}
return
~^g::
if (RisState[1]=2){
	;~ for k,v in RISarr:=getControls(RisState[2]) {
		;~ if(v.text="撰打住院醫師"){
			;~ reportDrHwnd:=RISarr[k+1].hwnd
			;~ break
		;~ }
	;~ }
	if (reportDrHwnd:=getNetControl2(RisState[2],"撰打住院醫師","FID_LABEL","撰打住院醫師","WindowsForms10.STATIC.app","","","",1)[1]) {
		inputbox,reportDrInput,撰打R,,,150,120
		if !errorlevel
			control,choosestring,% trim(reportDrInput)=""?"所有撰打住院醫師":trim(reportDrInput),,% "ahk_id " reportDrHwnd
	}
}
return
~^h::
if (RisState[1]=2){
	;~ for k,v in RISarr:=getControls(RisState[2]) {
		;~ if(v.text="執行住院醫師"){
			;~ reportDrHwnd:=RISarr[k+1].hwnd
			;~ break
		;~ }
	;~ }
	if (reportDrHwnd:=getNetControl2(RisState[2],"執行住院醫師","FID_LABEL","執行住院醫師","WindowsForms10.STATIC.app","","","",1)[1]) {
		inputbox,reportDrInput,執行R,,,150,120
		if !errorlevel
			control,choosestring,% trim(reportDrInput)=""?"所有執行住院醫師":trim(reportDrInput),,% "ahk_id " reportDrHwnd
	}
}
return
AppsKey::
tmp:=clipboardall
send ^+{left}^c
regexmatch(clipboard,"is)(.+?)(\W*)$",match)
send {bs}%match1%
clipboard:=tmp
return
^numpadenter::
^Enter::
;~ for k,v in RISarr:=getControls(RisState[2])
;~ if (k>3 && RISarr[k-3].text="改派原因" && instr(v.classNN,"WindowsForms10.BUTTON.app.")) {
	;~ ControlClick,,% "ahk_id " v.hwnd
	;~ break
;~ }
controlclick,,% "ahk_id " getNetControl2(RisState[2],"","cmdSearch","","WindowsForms10.BUTTON.app","","","",0)[1]
return
#IfWinActive

#IfWinActive,報告全文檢索 ahk_exe Menu.exe
~^r::
resetReportTextSearch:
searchWin:=WinExist("A")
,setRisSearchStartDate("19000101",searchWin, getNetAcc(searchWin, "StartDate", "WindowsForms10.SysDateTimePick32",0,0))
,setRisSearchEndDate("19000101",searchWin, getNetAcc(searchWin, "EndDate", "WindowsForms10.SysDateTimePick32",0,0))
Control,ChooseString,OR,,% "ahk_id " getNetAcc(searchWin, "cboExam_1", "WindowsForms10.COMBOBOX",0,0)
;~ Edit_SetSel(sqlEdit:=getNetAcc(searchWin, "txtQExam_1", "WindowsForms10.Edit", 0, false), 0, -1)
ControlSetText,,% "",% "ahk_id " sqlEdit:=getNetAcc(searchWin, "txtQExam_1", "WindowsForms10.Edit", 0, false)

return
#IfWinActive

!#ctrl::
ifwinactive,UniReport ahk_class TMainForm
{
	wingettitle,str,UniReport ahk_class TMainForm
	clipboard:=str
}else{
	keywait,alt,t1
	if errorlevel
		return
	keywait,lwin,t1
	if errorlevel
		return
	keywait,ctrl,t1
	if errorlevel
		return
	sleep 100
	clipboard=
	send ^c                                                               
	clipwait,1
}
slpwb:=getSlpWb()
if (slpWb.maxIndex())
	settimer,!#tab1,-100
if (Impax:=ImpaxState)[1]=2
	settimer,^!tab1,-200
return


!#tab::
keywait,alt,t1
if errorlevel
   return
keywait,tab,t1
if errorlevel
   return
keywait,lwin,t1
if errorlevel
   return
sleep 100
clipboard=
send ^c
clipwait,1

if (!regexmatch(clipboard,"\b\w{6}\d\b",match) && winactive("放射線資訊管理系統(Radiology Information System)")) {
	clipboard:=(chartNo:=getRisChartNo(RisOpened()[2]))
}

!#tab1:
if !regexmatch(clipboard,"\b\w{6}\d\b",match) {
	return
}

chartNo:=match
queryPageOpened:=0
slpwb:=getSlpWb()
if slpWb.maxIndex(){
	Loop {
		for k,v in slpWb:=getSlpWb() {
			if instr(v.LocationUrl,"WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PatientMedicalRecordListQuery.aspx") {
				queryPageOpened:=1
				while (v.busy) || v.document.getElementsByTagName("INPUT").length<2 {
					Sleep 500
					if(A_Index>10)
						break,2
				}
				
				loop % (inputs:=v.document.getElementsByTagName("INPUT")).length {
					if (inputs[a_index-1].name="NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01"){
				inputs[a_index-1].value:=chartNo
				break
					}
				}
				loop % (inputs:=v.document.getElementsByTagName("INPUT")).length {
					if (inputs[a_index-1].name="NWeb1$PatientBasicInfoQueryByIDAndName1$ctl09"){
				inputs[a_index-1].click()
				break
					}
				}
				Loop
				sleep 200
				until !v.busy
				v.document.getElementById("NWeb1_PatAccountListRecord1_ButtonWebEMR").click()
				break
			}
		}
		
		if(!queryPageOpened){
			for k,v in slpWb:=getSlpWb() {
				if InStr(v.LocationUrl, ".hospital-n.local") {
					js=javascript:b=document.selection.createRange().text;b=b.match(/(?:\w)\w{5}\d/);a=location.href.match(/[\?&](SESSION=[^=&]+)&?/i);if(!a){a=document.documentElement.innerHTML.match(/(SESSION=[a-zA-Z0-9]+)/i);}if(a){o=open('http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PatientMedicalRecordListQuery.aspx?QueryBySelf=N&'+a[1]);o.onload=function(){if(!b){return 0}o.document.all('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01').value=b;o.document.all('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl09').click();}}else{open('http://portal.hospital-n.local/General/Login.aspx');alert('Log in Portal first!');}void 0;
					v.Navigate(js)
					Sleep 1000
					break
				}
			}
		}
		
	}until queryPageOpened
	winactivate,ahk_class SleipnirMainWindow
}else if WinExist("ahk_class MozillaWindowClass"){
	Send_WM_COPYDATA(WinExist("ahk_exe FirefoxLoginApp.exe"), 0, jxon_dump({"searchChartNo": chartNo}))
	winactivate,ahk_class MozillaWindowClass
}
return


checkExam:
if RisState[1]!=2
	return
for k,v in risControls:=getcontrols(risstate[2]) {
	if (instr(v.text,"下筆") && instr(v.classNN,"WindowsForms10.BUTTON")) {
		temp:=k
		break
	}
}
for k,v in risControls {
	if (v.text="Exam." && instr(risControls[k+1]["classNN"],"WindowsForms10.EDIT.app") && abs(k-temp)<13) {
		controlgettext,examText,,% "ahk_id " risControls[k+1]["hwnd"]
		break
	}
}
examTextTransform(examText)
return
examTextTransform(str){
	t:="",numbering:=false,ind:=0,
	loop,parse,str,`n,`r
	{
		if(regexmatch(a_loopfield,"is)^(\d)[^\d\w]?\s*?(.*)",m)){
		}
	}
}
^!t::
ifwinexist,Convert first word
return
gui, 2: +lastfound
gui2hwnd:=winexist()
gui, 2: font,s10,Verdana
gui, 2: add,edit,w800 h600 vreport hwndreportEditHwnd
gui, 2: add,edit,r1 w20 vfirstword,1
gui, 2: add,button,x+5 yp gConvertFirstWord,Convert
gui, 2: add,button,x+5 yp gCopyPaste,% "Copy && Paste"
gui, 2: show,w850 h650,Convert first word
return
CopyPaste:
clipboard:=""
controlgettext,clipboard,,% "ahk_id " reportEditHwnd
clipwait,1
winactivate,% "ahk_id " RisState[2]
winwaitactive,% "ahk_id " RisState[2],,1
send ^v
return
ConvertFirstWord:
gui, 2: submit,NoHide
firstword:=trim(firstword)
if !regexmatch(firstword,"\d+")
{
	report:=regexreplace(report,"\n\d+.\s*","`n" firstword " ")
}else{
	ind:=0
	while ind:=regexmatch(report,"\n[^\s\w\(\[]+(.|\)|\s+)\s*",match,ind+1)
	{
		report:=regexreplace(report,match,"`n" a_index ". ","",1,ind)
	}
}
guicontrol, 2: ,report,% report
guicontrol, 2: focus,report
sendmessage,0xB1,0,-1,, ahk_id %reportEditHwnd%
return
2GUIClose:
gui, 2: destroy
return
#ifwinactive,Convert first word
~esc::
gui, 2: destroy
return
#ifwinactive
:*:pxy1::proxy.hospital-n.local{tab}3128
:*:a;::
input,code,i L2 T1 V *
if(code+0!=a_min+mod(a_hour,12)){
	send a;
	return
}
;~ keywait,enter
;~ sleep 100
loop % strlen(code)
	send {bs}
send {alt down}{numpad1}{numpad0}{numpad9}{alt up}{alt down}{numpad1}{numpad0}{numpad3}{alt up}{alt down}{numpad1}{numpad1}{numpad2}{alt up}{alt up}{alt down}{numpad1}{numpad1}{numpad5}{alt up}{alt up}{alt down}{numpad1}{numpad1}{numpad0}{alt up}{alt up}{alt down}{numpad1}{numpad2}{numpad2}{alt up}
return


::;rp::radiopaedia
::;rg::radiographics
::;ra::radiology assistant
::;lr::learning radiology
::;conct::Please send consult sheet and patient stickers to CT room for scheduling. Thanks.
::;conan::Please send consult sheet and patient stickers to angioroom for scheduling. Thanks.
::;cns::We were consulted for
::qov0::MOCK_PASSWORD
:*:s2g::scsnake@gmail.com
:*:b2n::raduser@hospital-n.local
::scss::scsnake
:*:mdlb::raduser@hospital-n.local{tab}MOCK_PASSWORD{enter}
::ahkk::autohotkey
:*:ych1::YCH1{tab}YCH1{enter}

commandArr:
commandArr:=[]
,commandArr["note"]:=root "\software\Notepad++\notepad++.exe"
,commandArr["scite"]:=root "\scripts\Autohotkey\SciTE\SciTE.exe"
,commandArr["script"]:=root "\scripts\"
,commandArr["lib"]:=root "\scripts\Autohotkey\Lib\"
,commandArr["word"]:=(fileexist(path:=a_mydocuments "\Office 2010 Portable\WINWORD.EXE")?path:root "\software\Office 2010 Portable\WINWORD.EXE")
commandArr["access"]:=(fileexist(path:=a_mydocuments "\Office 2010 Portable\MSACCESS.EXE")?path:root "\software\Office 2010 Portable\MSACCESS.EXE")
,commandArr["excel"]:=(fileexist(path:=a_mydocuments "\Office 2010 Portable\EXCEL.EXE")?path:root "\software\Office 2010 Portable\EXCEL.EXE")
,commandArr["ppt"]:=(fileexist(path:=a_mydocuments "\Office 2010 Portable\POWERPNT.EXE")?path:root "\software\Office 2010 Portable\POWERPNT.EXE")
,commandArr["office"]:=root "\software\Office 2010 Portable\"
,commandArr["vfss"]:=root "\scripts\VFSS2\"
,commandArr["chm"]:=root "\scripts\Autohotkey\AutoHotkey.chm"
commandArr["spy"]:=root "\scripts\Autohotkey\AU3_Spy.exe"
,commandArr["seah"]:=root "\software\Sleipnir\plugins\seahorse\"
,commandArr["seah1"]:=A_MyDocuments "\scsnake\Sleipnir\plugins\seahorse\"
;~ commandArr["liu"]:=root "\software\XLiu\Xliu.exe"
,commandArr["autorun"]:=root "\scripts\Autorun\"
,commandArr["wjl"]:=ahkMain " " root "\scripts\Radiology\WJL.ahk"
,commandArr["YCH"]:=ahkMain " " root "\scripts\Radiology\YCH.ahk"
commandArr["YCHm"]:=root "\scripts\Autohotkey\SciTE\SciTE.exe " root "\scripts\Radiology\YCH_main.ahk"
,commandArr["YCHe"]:=root "\scripts\Autohotkey\SciTE\SciTE.exe " root "\scripts\Radiology\YCH.ahk"
,commandArr["YCHx"]:=root "\scripts\Autohotkey\SciTE\SciTE.exe " root "\scripts\Radiology\YCH_XR.ahk"
,commandArr["YCHmm"]:=root "\scripts\Autohotkey\SciTE\SciTE.exe " root "\scripts\Radiology\YCH_mammo.ahk"
,commandArr["YXR"]:=ahkMain " " root "\scripts\Radiology\YCH_XR.ahk"
,commandArr["BMD"]:=ahkMain " " root "\scripts\Radiology\YCH_BMD.ahk"
commandArr["CXR"]:=ahkMain " " root "\-----------R3\chest\AutoHotkey_chest\Chest_CXJ.ahk"
,commandArr["brus"]:=ahkMain " " root "\-----------R3\chest\AutoHotkey_chest\breast_CXJ.ahk"
;~ commandArr["mamm"]:=ahkMain " " root "\-----------R3\chest\AutoHotkey_chest\CUCmammo.ahk"
,commandArr["mamm"]:=ahkMain " " root "\scripts\Radiology\YCH_mammo.ahk"
,commandArr["chrome"]:=root "\software\GoogleChromePortable\GoogleChromePortable.exe --proxy-server=proxy.hospital-n.local:3128"
,commandArr["pcman"]:=root "\software\PCMan Combo\PCMan.exe"
,commandArr["firefox"]:=a_desktop "\FirefoxLogin.lnk"
;~ commandArr["chrome"]:=root "\software\ChromePlusPortable\chrome.exe"
;~ commandArr["msn"]:=root "\software\MSN 8.5\msnmsgr.exe"
commandArr["7z"]:=root "\software\7-Zip\"
,commandArr["tshark"]:=root "\software\tshark\"
,commandArr["server"]:=root "\software\TWAMPd\"
,commandArr["cmd"]:=root "\software\PowerCmd\PowerCmd.exe"
,commandArr["teamviewer"]:=root "\software\TeamViewerPortable\TeamViewer.exe"
,commandArr["ugi"]:=ahkMain " " root "\scripts\Radiology\YCH-UGI.ahk"
commandArr["hct"]:=ahkMain " " root "\scripts\Radiology\YCH-HCT.ahk"
,commandArr["info"]:=root "\scripts\AHK_Window_Info_v1.7.exe"
,commandArr["nginx"]:=root "\software\WNMP\"
,commandArr["diff"]:=root "\scripts\Radiology\diffReport.exe"
,commandArr["case"]:=(fileexist(path:=a_mydocuments "\Office 2010 Portable\EXCEL.EXE")?path " ":root "\software\Office 2010 Portable\EXCEL.EXE ") """" root "\case list.xlsx"""
,commandArr["pdf"]:=root "\software\PDF-XChange Viewer\PDFXCview.exe"
commandArr["ftp"]:=root "\software\FileZillaPortable\FileZillaPortable.exe"
,commandArr["icon"]:=root "\scripts\IconChanger\IconChangerMain.exe"
,commandArr["simple"]:=root "\scripts\Radiology\AntiImpaxFlash.exe"
,commandArr["type"]:=root "\scripts\Radiology\RisTyper\RisTyper.exe"
,commandArr["rfa"]:=root "\scripts\Radiology\RFA note.exe"
,commandArr["nhi"]:=root "\scripts\Radiology\NHIform"
commandArr["radtem"]:=(partialMode?root :root "\scripts\Radiology") "\RadTemplate\RadTemplate.exe"
,commandArr["reg"]:=root "\software\RegAlyzerPortable\RegAlyzerPortable.exe"
;~ ,commandArr["pIE"]:=(partialMode?root :root "\scripts\Radiology") "\PacsIE\miniPacsMain.exe"
;~ ,commandArr["feed"]:=root "\scripts\Radiology\PacsIE\feedRIS.exe"
,commandArr["ahks"]:=ahkMain " " root "\scripts\Autohotkey\AHKStudio\AHKStudio.ahk"
,commandArr["vnc"]:=root "\scripts\RemoteList\VNC_List.exe"
commandArr["msr"]:=root "\scripts\Radiology\MammoSR\MammoSR.exe"
commandArr["bdg"]:=(partialMode?root:root "\scripts\Radiology") "\PacsIE\miniPACSmain.exe"
commandArr["feed"]:=(partialMode?root:root "\scripts\Radiology") "\PacsIE\feedRIS.exe"
commandArr["feeda"]:=(partialMode?root:root "\scripts\Radiology") "\PacsIE\autoFeed.exe"
commandArr["ebm"]:=(partialMode?root:root "\scripts\Radiology\") "\EBMpreload\EBMpreload.exe"
commandArr["urg"]:=(partialMode?root:root "\scripts\Radiology\") "\urgentReport\urgentReport.exe"
commandArr["$$$"]:=(partialMode?root:root "\scripts\Radiology\") "\urgentReport\selectCT.exe"



return
listProcess(){
	d := "  |  "
	s := 4096
	Process, Exist
	h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", ErrorLevel, "Ptr")
	DllCall("Advapi32.dll\OpenProcessToken", "Ptr", h, "UInt", 32, "PtrP", t)
	VarSetCapacity(ti, 16, 0)
	NumPut(1, ti, 0, "UInt")
	DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", "SeDebugPrivilege", "Int64P", luid)
	NumPut(luid, ti, 4, "Int64")
	NumPut(2, ti, 12, "UInt")
	r := DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", t, "Int", false, "Ptr", &ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
	DllCall("CloseHandle", "Ptr", t)
	DllCall("CloseHandle", "Ptr", h)
	hModule := DllCall("LoadLibrary", "Str", "Psapi.dll")
	s := VarSetCapacity(a, s)
	c := 0
	DllCall("Psapi.dll\EnumProcesses", "Ptr", &a, "UInt", s, "UIntP", r)
	Loop, % r // 4
	{
		id := NumGet(a, A_Index * 4, "UInt")
		h := DllCall("OpenProcess", "UInt", 0x0010 | 0x0400, "Int", false, "UInt", id, "Ptr")
		if !h
			continue
		VarSetCapacity(n, s, 0)
		e := DllCall("Psapi.dll\GetModuleBaseName", "Ptr", h, "Ptr", 0, "Str", n, "UInt", A_IsUnicode ? s//2 : s)
		if !e
			if e := DllCall("Psapi.dll\GetProcessImageFileName", "Ptr", h, "Str", n, "UInt", A_IsUnicode ? s//2 : s)
			SplitPath n, n
		DllCall("CloseHandle", "Ptr", h)
		if (n && e)
			l .= n . d, c++
	}
	DllCall("FreeLibrary", "Ptr", hModule)
	return array(l,c)
}
GetModuleFileNameEx( p_pid )
{
	h_process := DllCall( "OpenProcess", "uint", 0x10|0x400, "int", false, "uint", p_pid, "Ptr")
	if ( ErrorLevel or h_process = 0 )
		return
	name_size = 255
	VarSetCapacity( name, name_size )
	result := DllCall( "psapi.dll\GetModuleFileNameExA", "Ptr", h_process, "Ptr", 0, "str", name, "uint", name_size )
	DllCall( "CloseHandle", "Ptr", h_process )
	return, name
}


RisHistoryBreakline:
for breakLineControlKey,breakLineControlValue in breakLineControls
	if breakLineControl:=getNetControl2(risState[2],"",breakLineControlValue,"","WindowsForms10.EDIT","","","",0)[1] 
		acc_objectfromwindow(breakLineControl).accValue:=RegExReplace(RegExReplace(controlgettext(breakLineControl),"\r|\n","€"),"€+","`r`n")
return



;~ ~ctrl::
;~ mousegetpos,x,y
;~ if (x>=firstMonitorLeft&&x<=firstMonitorRight && y>=firstMonitorTop&&y<=firstMonitorBottom)
	;~ mouseBoundaryLimit:=[firstMonitorLeft,firstMonitorRight,firstMonitorTop,firstMonitorBottom]
;~ else if(x>=lastMonitorLeft&&x<=lastMonitorRight && y>=lastMonitorTop&&y<=lastMonitorBottom)
	;~ mouseBoundaryLimit:=[lastMonitorLeft,lastMonitorRight,lastMonitorTop,lastMonitorBottom]
;~ else 
	;~ mouseBoundaryLimit:=[firstMonitorRight+1,lastMonitorLeft-1,lastMonitorTop,lastMonitorBottom]
;~ hHookMouse2 := SetWindowsHookEx(WH_MOUSE_LL:= 14, RegisterCallback("MouseHook2", "Fast"))
;~ settimer,cyclicMonitor,off
;~ return

;~ ~ctrl up::
;~ UnhookWindowsHookEx(hHookMouse2)
;~ settimer,cyclicMonitor,200
;~ return


;~ MouseHook2(nCode, wParam, lParam){
	;~ static lx,ly
	;~ global mouseBoundaryLimit
	;~ Critical
	;~ }
	;~ If nCode || !(wParam = 0x200)
		;~ return CallNextHookEx(nCode, wParam, lParam)
	;~ VarSetCapacity(lpPoint,8)
	;~ ,DllCall("GetCursorPos", "Uint", &lpPoint)
	;~ ,mx := NumGet(lParam+0, 0, "Int")
	;~ ,my := NumGet(lParam+0, 4, "Int")
	;~ ,mx:=mx<mouseBoundaryLimit[1]?mouseBoundaryLimit[1]:mx
	;~ ,mx:=mx>mouseBoundaryLimit[2]?mouseBoundaryLimit[2]:mx
	;~ ,my:=my<mouseBoundaryLimit[3]?mouseBoundaryLimit[3]:my
	;~ ,my:=my>mouseBoundaryLimit[4]?mouseBoundaryLimit[4]:my
	;~ ,DllCall("SetCursorPos", "Int", mx, "Int", my)
	;~ ,NumPut(mx, lParam+0, 0, "Int")
	;~ ,NumPut(my, lParam+0, 4, "Int")
	;~ return 1
;~ }


#ifwinactive AutoHotkey Help ahk_exe SciTE.exe
esc::
WinClose,AutoHotkey Help ahk_exe SciTE.exe
return
#ifwinactive
#ifwinactive AutoHotkey_L Help ahk_exe SciTE.exe
esc::
WinClose,AutoHotkey_L Help ahk_exe SciTE.exe
return
#ifwinactive


#j::
mousegetpos,x,y,win,conC
mousegetpos,,,,con,2
clipboard:=listcontrols(win)
msgbox % conC ", " con
return

#p::
gosub getChartNo
run % root "\scripts\Radiology\updateOpPatho\searchPatho.exe " chartNo
return

getChartNo:
chartNo:=""
if rChartNo:=getRisChartNo(RisOpened()[2])
	chartNo:=rChartNo, examDate:=getRisExamDate(RisOpened()[2])
else if iChartNo:=getImpaxChartNo(ImpaxOpened()[2,1])
	chartNo:=iChartNo, examDate:=getImpaxExamDate(ImpaxOpened()[2,1])[1]


;~ if winactive("ahk_id " RisOpened()[2]) && rChartNo:=getRisChartNo(RisOpened()[2])
	;~ chartNo:=rChartNo
;~ if !chartNo && winactive("ahk_id " ImpaxOpened()[2,1]) && iChartNo:=getImpaxChartNo(ImpaxOpened()[2])
	;~ chartNo:=iChartNo
;~ if !chartNo && regexmatch(clipboard,"\b\w{6}\d\b",match)
	;~ chartNo:=match

if !chartNo
	chartNo:=getRisChartNo(RisOpened()[2])

if !chartNo {
	msgbox,,,Failed to get chart No.,3
	;~ goto fail
}

return




SHA1dash(str){
	str:=SHA(str)
	stringlower,str,str
	return substr(str,1,8) "-" substr(str,9,8) "-" substr(str,17,8) "-" substr(str,25,8) "-" substr(str,33,8)
}

reopenImpaxContextServer:
if (A_TickCount-startup_tickcount)<10000
	settimer,,-2000
if (monitorcount>1 && ImpaxState[1]==2)
	Loop 3 {
		if (winvisible(Impaxstate[2,A_Index]) && Winget("MinMax", impaxstate[2,A_Index])!=-1){
			;~ WinMaximize,% "ahk_id " ImpaxState[2,A_Index]
			WinMove,% "ahk_id " ImpaxState[2,A_Index],,% monitors[2].l,% monitors[2].t,% monitors[2].w+(A_Index=1?monitors[3].w:0),% monitors[2].h
		}
	}
	
WinClose,ahk_exe ImpaxContextServer.exe
Run,% comspec " /c ""taskkill /IM ImpaxContextServer.exe /F""",,Hide
process,Exist,ImpaxContextServer.exe
if errorlevel
	Run,% comspec " /c ""taskkill /PID " ErrorLevel " /F""",,Hide
settimer,impaxContextServer,-1000
return 

impaxContextServer:
;~ return ;pauseThread
;~ Sleep 5000
if !winexist("ahk_exe ImpaxContextServer.exe") {
	if  FileExist(path:=root "\scripts\Radiology\MammoSR\ImpaxContextServer\ImpaxContextServer.exe")
		|| FileExist(path:=root "\send string by windows message\bin\Release\ImpaxContextServer.exe")
		|| fileexist(path:=A_ScriptDir "\ImpaxContextServer.exe")
		|| fileexist(path:=A_ScriptDir "\ImpaxContextServer\ImpaxContextServer.exe")
		||  fileexist(path:=a_mydocuments "\ImpaxContextServer\ImpaxContextServer.exe") 
		contextServerPath:=path
	;~ run,% contextServerPath,,hide
	RunKeepFocus(contextServerPath, "", "hide")
}else{
	winmove,-1,-1,1,1,ahk_exe ImpaxContextServer.exe
}
;~ settimer,impaxContextServerMinimize,-500
settimer,impaxContextServer,-5000
return

impaxContextServerMinimize:
if WinExist("ahk_exe ImpaxContextServer.exe") {
	settimer,,Off
	if !WinActive("ahk_exe ImpaxContextServer.exe")
		return
	if WinExist("ahk_exe RBTray.exe"){
		winactivate,ahk_exe ImpaxContextServer.exe
		WinWaitActive,ahk_exe ImpaxContextServer.exe,,2
		send !#{Down}
	}else
		winminimize,ahk_exe ImpaxContextServer.exe
}else
	settimer,,-500
return

UIAutomationServer:
;~ return ;pauseThread
if !winexist("ahk_exe UIAutomationServer.exe") {
	if fileexist(path:=a_mydocuments "\UIAutomationServer\UIAutomationServer.exe")
		|| FileExist(path:=A_ScriptDir "\UIAutomationServer\UIAutomationServer.exe")
		|| FileExist(path:=A_ScriptDir "\UIAutomationServer.exe")
		|| FileExist(path:=root "\UIAutomationServer\UIAutomationServer\UIAutomationServer\bin\Release\UIAutomationServer.exe")
		UIAutomationServerPath:=path
	else 
		UIAutomationServerPath:=root "\UIAutomationServer\UIAutomationServer\UIAutomationServer\bin\Release\UIAutomationServer.exe"
	run % UIAutomationServerPath
}

;~ winactivate,% "ahk_id " RisOpened()[2]
return


;~ ~ctrl::
;~ if(A_PriorHotkey = A_ThisHotkey && A_TimeSincePriorHotkey<500){
	;~ SendLevel,3
	;~ send {ctrl up}{Left}{Right}
;~ }
;~ return

:*b0:.,::
xetf:
keyboardLayout:=["1qaz!","2wsx@","3edc#","4rfv$","5tgb%","6yhn^","7ujm&","8ik,*","9ol.(","0p;/)"]
;~ kw:=$.value(2)
;~ code:=$.value(1)
input,en,T5 L4 i * V
if !RegExMatch(en,"i)(\w\w)(\d\d)", match)
	return
kw:=match1, code:=match2
if(code+0!=a_min+mod(a_hour,12))
	return
input,ed,T1 L3 i * V
if(ed!="/.,"){
	;~ send % $.value(0)
	return
}
;~ keywait,enter
;~ sleep 100
;~ loop % strlen(code)
	;~ send {bs}
send {bs 9}
str1:=str2:=""
stringupper,kw,kw
Loop,parse,kw
{
	ch:=A_LoopField
	for k,v in keyboardLayout
		if InStr(v,ch){
			str1.=SubStr(v,1,1), str2.=SubStr(v,0,1)
			break
		}
}
Sleep 50
send:=kw str2 str1
Loop,parse,Send
{
	send % "{" A_LoopField " down}{" A_LoopField " up}"
	Sleep 10
}
send {alt down}{numpad1}{numpad0}{numpad9}{alt up}{alt down}{numpad1}{numpad0}{numpad3}{alt up}{alt down}{numpad1}{numpad1}{numpad2}{alt up}{alt up}{alt down}{numpad1}{numpad1}{numpad5}{alt up}{alt up}{alt down}{numpad1}{numpad1}{numpad0}{alt up}{alt up}{alt down}{numpad1}{numpad2}{numpad2}{alt up}

return

:*:.,.,::
send {lwin up}{RWin up}{shift up}{ctrl up}{alt up}
return

^!+#r::
goto Reload
return

Reload:
Reload()
return

Reload(){
	global RisImpaxDecodePw
	if(RisImpaxDecodePw!=""){
		if(A_IsCompiled)
			run % """" A_ScriptFullPath  """ /restart """ RisImpaxDecodePw """"
		else{
			SplitPath,A_ScriptFullPath,,,,name
			run % """" A_ScriptDir "\" name ".exe"" /restart """ A_ScriptDir "\" name ".ahk"" """ RisImpaxDecodePw """"
		}
	}else
		Reload
}

tempDisableRis(activeWinPid){
	;~ winset,disable,,ahk_pid %activeWinPid%
	Loop {
		BlockInput,MouseMove
		BlockInput,MouseMoveOff
		winget,list,list,ahk_pid %activeWinPid%
		;~ ToolTip % list
		if(list>30){
			;~ winset,enable,,ahk_pid %activeWinPid%
			return
		}
		Sleep 200
	}until A_Index>100
	;~ winset,enable,,ahk_pid %activeWinPid%
	;~ preList:=WinGetList("ahk_exe Menu.exe")
	;~ WinGetTitle,t,ahk_id %activeWin%
	;~ WinGet,pName,ProcessName,ahk_id %activeWin%
	;~ if !InStr(t, "RIS系統登入<<陽明資訊>>") || (pName!="Menu.exe")
		;~ return
	;~ Loop {
		;~ if (newList:=WinGetList("ahk_exe Menu.exe")).length()>preList.length()
			;~ break
		;~ Sleep 10
	;~ }until A_Index>300
	;~ for k,v in newList {
		;~ if !hasval(preList, v){
			;~ WinHide,% "ahk_id " v
			;~ WinShow,% "ahk_id " v
			;~ Winactivate,% "ahk_id " v
			;~ break
		;~ }
	;~ }
}


:*:qz13::
activateLoginWin()
tagNewRisTitle("T0")
winget,activeWinPid,pid,A
SendRaw % RisImpaxLoginInfo.Ris.1.user
send {tab}
sendRaw % RisImpaxLoginInfo.Ris.1.pw
send {Enter}
SetTimerFn("tempDisableRis", -1, [activeWinPid])
return


:*:ec35::
activateLoginWin()
tagNewRisTitle("T4")
winget,activeWinPid,pid,A
sendRaw % RisImpaxLoginInfo.Ris.2.user
send {tab}
sendRaw % RisImpaxLoginInfo.Ris.2.pw
send {Enter}
SetTimerFn("tempDisableRis", -1, [activeWinPid])
return

:*:rv46::
activateLoginWin()
tagNewRisTitle("Y0")
winget,activeWinPid,pid,A
sendRaw % RisImpaxLoginInfo.Ris.3.user
send {tab}
sendRaw % RisImpaxLoginInfo.Ris.3.pw
send {Enter}
SetTimerFn("tempDisableRis", -1, [activeWinPid])
return

:*:wx24::
activateLoginWin()
tagNewRisTitle("A0")
winget,activeWinPid,pid,A
sendRaw % RisImpaxLoginInfo.Ris.4.user
send {tab}
sendRaw % RisImpaxLoginInfo.Ris.4.pw
send {Enter}
SetTimerFn("tempDisableRis", -1, [activeWinPid])
return




:*:caseurl::
send % "https://docs.google.com/spreadsheets/d/MOCK_SHEET_ID/edit?usp=sharing"
send {Enter}
return


#WheelUp::
#WheelDown::
send {lwin up}{rwin up}
if (impaxSelectImageWorking)
	settimer,,-1000
impaxSelectImageWorking:=true
oldRisReportSEIM:=parseOldSEIM()
if !(oldRisReportSEIM.maxindex()>0)
	return
if(!oldRisReportSEIMind)
	oldRisReportSEIMind:=InStr(A_ThisHotkey, "UP")?0:1
else
	oldRisReportSEIMind+=InStr(A_ThisHotkey,"UP")?-1:1
oldRisReportSEIMind:=Mod(oldRisReportSEIMind-1+oldRisReportSEIM.maxindex(), oldRisReportSEIM.maxindex())+1
, selectedSEIM:=oldRisReportSEIM[oldRisReportSEIMind]
,SetTimerFn("showSelectedSEIM", -1, [oldRisReportSEIM, oldRisReportSEIMind])
,impaxSelectImage(selectedSEIM.2, selectedSEIM.1, "", [2])
,impaxSelectImageWorking:=false
return

showSelectedSEIM(SEIMs, ind){
	str:=""
	for k,v in SEIMs
		str.= (ind=k?" => ":"    ") "SE " v.1 "     IM " v.2 "`n"
	SetTimerFn("OnScreenDisplay", -1, [str, 800, 30, "white"])
	;~ ToolTip % str
	;~ settimer,ToolTip,-2000
}




#IfWinActive,ahk_exe SciTE.exe
~{::
;~ KeyWait,},D T0.3
Input, k, L1 V T0.5 *,abcdefghijklmnopqrstuvwxyz1234567890_}{Enter}{Space}{tab}{esc}
if (ErrorLevel != "Timeout")
	return 
KeyWait,shift,T1
send {}}{Left}{Enter 2}{up}
Sleep 50
send {tab}
firedHotkey1:=A_TickCount
return

;~ ^{::
;~ send {{}
;~ return

~esc::
if firedHotkey1 && (A_TickCount-firedHotkey1<3000) {
	send ^z
	send ^z
}
	
firedHotkey1:=""
return
#IfWinActive

#IfWinActive,ahk_group pycharm
^9::
keywait,9,T1
send (
return
#IfWinActive

;~ ~ctrl up::
;~ ~shift up::
;~ ~lwin up::
;~ ~rwin up::
;~ ~alt up::
;~ settimer,Clickup,-310
;~ return

Clickup:
;~ if (GetKeyState("LButton") || GetKeyState("RButton") || GetKeyState("MButton"))
if A_TimeIdlePhysical<300
	return
BlockInput,MouseMove
resetHotstringBuffer(-1)
BlockInput,MouseMoveOff
return



:*:isd11::
send raduser{tab}raduser{!}{Enter}
return

:*:qwew::
;~ winget,activeWin,id,A
InputBox,inputdate
if (inputdate=""){
	WinActivate,% "ahk_id " activeWin
	return
}
;~ year:="20" SubStr(date,1,2)
;~ ,month:=SubStr(date,3,2)
;~ ,day:=SubStr(date,5,2)
;~ if StrLen(day)<2
	;~ day:="0" day
inputDate:=DateRange(inputdate)
,ParseDate(inputDate, year, month, day)
,d:=year "/" month "/" day
setRisSearchStartDate(d,RisState[2])
if(day=22){
	if month in 01,03,05,07,08,10,12
		d:=year "/" month "/31"
	else
		d:=year "/" month "/30"
}else{
	d:=year month day
	d+=6,Days
	d:=SubStr(d,1,4) "/" SubStr(d,5,2) "/" SubStr(d,7,2)
}
;~ WinActivate,% "ahk_id " activeWin
;~ send % d 
setRisSearchEndDate(d,RisState[2])
winactivate,% "ahk_id " RisState[2]
return


autolock:
;~ if (partialMode){
	if (A_TimeIdle>300000) && !WinExist("ahk_id " lockHwnd)
		gosub lockScreen
	
;~ }else{
	;~ if (A_TimeIdlePhysical>300000) && !WinExist("ahk_id " lockHwnd)
		;~ gosub lockScreen
	
;~ }
return

:*:aaaa::
if !GetKeyState("LButton")
	return
KeyWait,LButton,T1
KeyWait,a,T1
gosub activateSelf
return

:*:dddd::
if !GetKeyState("LButton")
	return
KeyWait,LButton,T1
KeyWait,d,T1
send #d
return

:*:ewq::
send !{tab}
return



:*:zxcx::
winactivate,% "ahk_id " guiHWND
gui,ahkcmd:Default
gui,ahkcmd:new,-Resize -MinimizeBox -MaximizeBox +AlwaysOnTop +hwndahkcmdguihwnd
DetectHiddenWindows,off
atw:=AltTab_window_list()
,allHotkey:=GetHotkeyList()
,s:=""

,HotkeyList:=""
for k,v in allHotkey
	Hotkeylist.="|" v 

DetectHiddenWindows,on
for k,v in atw
	s.="|" v.title " - " v.class
gui,Add,DropDownList,w500 vahkcmd_activateWin AltSubmit,% s
gui,Add,Edit,w30 vahkcmd_waitSec,3
gui,add,DropDownList,w500 vahkcmd_hotkeylist,% HotkeyList
gui,Add,Edit,r5 w500 vahkcmd_cmd

gui,Add,button,gahkcmdGo w30 Default,Go
gui,Show,Center

hotkey,IfWinActive,% "ahk_id " ahkcmdguihwnd
hotkey,esc,ahkcmdguiclose,on
hotkey,^Enter,ahkcmdGo,on
hotkey,NumpadEnter,ahkcmdGo,on
hotkey,IfWinActive
return

ahkcmdGo:
gui,ahkcmd:Submit

if ahkcmd_activateWin
{
	winactivate,% "ahk_id " atw[ahkcmd_activateWin-1].hwnd
	WinWaitActive,% "ahk_id " atw[ahkcmd_activateWin-1].hwnd,,5
}
if ahkcmd_waitSec>0
	Sleep % Abs(ahkcmd_waitSec)*1000 
if(ahkcmd_hotkeylist!="")
	ahkdll := DllCall("LoadLibrary", "str", "AutoHotkey.dll")
	,DllCall("AutoHotkey\ahktextdll", "str", "
	(LTrim
	sendlevel,10
	try
		send " ahkcmd_hotkeylist "
	catch e
		msgbox `% e
	finally
		exitapp
	)", "str", "1234567", "Cdecl Int")
if(ahkcmd_cmd!=""){
	if RegExMatch(ahkcmd_cmd, "i)send +([\+!#^]*)([^\r\n]+)", sendKeys) {
		prefix:=sendKeys1? Permutations(sendKeys1):[""]
		
		for k,v in prefix
			if IsLabel(v sendKeys2){
				settimer,% v sendKeys2,-1
				break
			}
				
	}else
		ahkdll := DllCall("LoadLibrary", "str", "AutoHotkey.dll")
		,DllCall("AutoHotkey\ahktextdll", "str", "
		(LTrim 
		sendlevel,10
		try {
			" ahkcmd_cmd "
		}catch e {
			msgbox `% e
		}finally
			exitapp
		)", "str", "1234567", "Cdecl Int")
}
	
return



ahkcmdguiclose:
gui,ahkcmd:Destroy
gosub activateSelf
return



^!+d::
in_str:=Clipboard
if InStr(in_str,":/") && FileExist(in_str) {
	__CryptFile(in_str, SubStr(in_str,1,-1),____,0)
}else{
	ToolTip % clipboard:=__CryptStr(in_str, ____,0)
}
return



!`::
switch_process()
return

switch_process(){
	global ImpaxState
	winget,pName,ProcessName,A
	winget,hwnd,id,A
	DetectHiddenWindows,Off
	atwl:=AltTab_window_list()
	DetectHiddenWindows,On
	
	if(pName~=MatchPacsProcessName()){
		chartNo:=(new ActivePacs(hwnd)).getChartNo()
		for k,v in atwl {
			winget,pn,ProcessName,% "ahk_id " v.hwnd
			if(pn~=MatchPacsProcessName() && v.hwnd!=hwnd && pn!=pName
				&& (new ActivePacs(v.hwnd).getChartNo()=chartNo)){
				winactivate,% "ahk_id " v.hwnd
				return
			}
		}
		
		for k,v in atwl {
			winget,pn,ProcessName,% "ahk_id " v.hwnd
			if(pn~=MatchPacsProcessName() && v.hwnd!=hwnd && pn!=pName){
				if InStr(pn, "impax")
					winactivate,% "ahk_id " ImpaxState[2,1]
				else
					winactivate,% "ahk_id " v.hwnd
				return
			}
		}
		
	}else	
		for k,v in atwl {
			winget,pn,ProcessName,% "ahk_id " v.hwnd
			if(pn=pName && v.hwnd!=hwnd){
				winactivate,% "ahk_id " v.hwnd
				return
			}
		}
	
}



~ScrollLock::
if(A_ThisHotkey==A_PriorHotkey && A_TimeSincePriorHotkey<400){
	send {Alt Down}
	showTooltip("Alt Down",2000)
	settimer,AltUp,-2000
}
return

AltUp:
send {Alt Up}
return


#IfWinExist,ahk_exe Menu.exe
~esc::
RisTempActivate.recoverAll()
return
#IfWinExist

#IfWinExist,ahk_exe impax-client-main.exe
~esc::
HideImpaxSearchWin(false)
Loop 3
{
	WinShow,% "ahk_id " ImpaxState[2, A_Index]
	WinGetPos,,,w,h,% "ahk_id " ImpaxState[2, A_Index]
	if(w<500 || h<500)
		WinRestore,% "ahk_id " ImpaxState[2, A_Index]
}
if (reportTextAreaHwnd:=getNetAcc(ImpaxState[2,2] | ImpaxState[2,3],"TextAreaView","WindowsForms10.Window.8.app",0,0)){
	WinShow,% "ahk_id " reportTextAreaHwnd
	WinRestore,% "ahk_id " reportTextAreaHwnd
}
ImpaxContextServer_SendCommand("SET_WINDOW_STATE | 2 || ")
,ImpaxContextServer_SendCommand("SET_FOCUS | IMPAX || ")
return
#IfWinExist


^#r::
gui,ListRis:Default
gui,ListRis:new,+ToolWindow
ListRisOptions:=[]
for k,v in (allris:=RisOpened(1))[1] {
	gui,add,button,gListRisClick,% v ": " WinGetTitle(v)
	ListRisOptions.push(v)
}
gui,add,Text,,% "----------------------"
for k,v in (allris:=RisOpened(1))[2] {
	gui,add,button,gListRisClick,% v ": " WinGetTitle(v)
	ListRisOptions.push(v)
}
gui,show,Center,All Ris
return

#IfWinActive,All Ris ahk_class AutoHotkeyGUI
ListRisGuiClose:
ListRisGuiEscape:
esc::
gui,ListRis:Destroy
return
#IfWinActive

ListRisClick:
RegExMatch(a_guicontrol,"^[\da-fx]+", risSelectedHwnd)
WinShow,% "ahk_id " risSelectedHwnd
winactivate,%  "ahk_id " risSelectedHwnd
winset,trans,Off,%  "ahk_id " risSelectedHwnd
winset,AlwaysOnTop,On,%  "ahk_id " risSelectedHwnd
winset,AlwaysOnTop,Off,%  "ahk_id " risSelectedHwnd
gui,ListRis:Destroy
return

:*:gepw::service{tab}MOCK_PASSWORD{enter}


^AppsKey::
ToolTip % "parsing ... "
parseDataGrid2("", "","", false, false, false, true, false, false, false, true)
ToolTip
return

:*:ebmhc::
pwb:=ComObjCreate("InternetExplorer.Application")
pwb.Navigate("http://pacs.hospital-n-h.local")
pwb.Visible:=true
winactivate,% "ahk_id " pwb.hwnd
return

:*:ebmbi::
pwb:=ComObjCreate("InternetExplorer.Application")
pwb.Navigate("https://bihwebpacs.hospital-n-h.local/")
pwb.Visible:=true
winactivate,% "ahk_id " pwb.hwnd
return

:*:ebmyl::
pwb:=ComObjCreate("InternetExplorer.Application")
pwb.Navigate("http://dlpacs.hospital-y.local/")
pwb.Visible:=true
winactivate,% "ahk_id " pwb.hwnd
return

:*:ebmzd::
pwb:=ComObjCreate("InternetExplorer.Application")
pwb.Navigate("http://pacs-web.zd.hospital-n.local")
pwb.Visible:=true
winactivate,% "ahk_id " pwb.hwnd
return

:c*:geuv::
pwb:=ComObjCreate("InternetExplorer.Application")
pwb.Navigate("https://geuv.hospital-n-cc.local/login.jsp")
pwb.Visible:=true
winactivate,% "ahk_id " pwb.hwnd
return


;~ #IfWinNotActive,simple RIS ahk_class AutoHotkeyGUI
;~ ~capslock up::
;~ gosub activateSimpleRis
;~ return
;~ #IfWinNotActive
:*:cmd=::
if IsObject(cmdWin)
	cmdWin.DisposeTimers()
cmdWin:=new cmdWindow("cmdWindowCall")
return

cmdWindowCall(cmd){
	global
	guicontrol,%guihwnd%:,commands,% cmd
	gosub parse_commands
	
}


~del::
resetHotstringBuffer(-1)
return

^F8::
configRisFrames()
return


zcbc:
:*:zcbc::
winactivate,% "ahk_id " guiHWND
gui,combineKeys:new,+hwndcombineKeyHwnd +ToolWindow -Resize -MinimizeBox -MaximizeBox +AlwaysOnTop
for k,v in ["Shift", "Ctrl", "Alt", "LWin"]
	gui,combineKeys:add,Checkbox,% "vcombineKeyCb" v,% v 
gui,combineKeys:Add,Edit,w50 vcombineKeyLastingSec,5
gui,combineKeys:Add,button,gcombineKeysGo,Go
gui,combineKeys:show,Center,CombineKeys
return

combineKeysClose:
gui,combineKeys:Destroy
return

combineKeysGo:
gui,combineKeys:Submit
combineKeyLastingSec*=1000
,toBeKeyUp:=[]
,DownKeys:=""
for k,v in ["Shift", "Ctrl", "Alt", "LWin"] {
	combineKeyVar:="combineKeyCb" v
	,combineKeyVal:=%combineKeyVar%
	if (combineKeyVal){
		send % "{" v " down}"
		toBeKeyUp.push(v)
		DownKeys.=v ", "
	}else
		send % "{" v " up}"
}
ShowToolTip("Key down: " SubStr(Downkeys,1,-2), Abs(combineKeyLastingSec))
,SetTimerF("__keyUp", (-1)*Abs(combineKeyLastingSec), [toBeKeyUp])
return

__keyUp(keys){
	for k,v in keys
		send % "{" v " up}"
}



#IfWinActive,ahk_exe Miv2Lib.exe
~k::
Sleep 200
send q
return


~^WheelUp::
~^WheelDown::
if (keepMouseScrollAction!=""){
	if InStr(A_ThisHotkey, keepMouseScrollAction){
		keepMouseScrollSpeed-=10
		if keepMouseScrollSpeed<10
			keepMouseScrollSpeed:=50
		SetTimer,keepMouseScroll,-1
	}else{
		keepMouseScrollAction:=RegExReplace(A_ThisHotkey, "^\W+", "")
		,keepMouseScrollSpeed:=50
		SetTimer,keepMouseScroll,-1
	}
	return
}
	
keepMouseScrollAction:=RegExReplace(A_ThisHotkey, "^\W+", "")
;~ ToolTip % A_TickCount 
,keepMouseScrollSpeed:=keepMouseScrollSpeed?keepMouseScrollSpeed:50
SetTimer,keepMouseScroll,-1
return
#IfWinActive


keepMouseScroll:
if !GetKeyState("LCtrl") || !WinActive("ahk_exe Miv2Lib.exe") {
	keepMouseScrollAction:=""
	,keepMouseScrollSpeed:=50
	SetTimer,,Off
	return
}	
oldSendLevel:=a_sendlevel
SendLevel,0
send % "{"keepMouseScrollAction  "}"
;~ ShowToolTip(keepMouseScrollAction, 500)
SendLevel,% oldSendLevel
SetTimer,,% (-1)*keepMouseScrollSpeed
return

activateLoginWin(){
	risLoginWin:=RisOpened(1)[1]
	if (risLoginWin.length()){
		risHwnd:=risLoginWin[1]
		,RisIdHwnd:=getNetAcc(risHwnd, "USER_ID", "WindowsForms10.EDIT",0,0)
		WinShow,ahk_id %risHwnd%
		winactivate,ahk_id %risHwnd%
		WinWaitActive,ahk_id %risHwnd%,,2
		ControlFocus,,ahk_id %RisIdHwnd%
		controlsend,,{Home}+{End},ahk_id %RisIdHwnd%
	}
}

tagNewRisTitle(tag, doTag=0, start_tick=0){
	static prvRisHwnds
	
	if !(doTag){
		if !WinActive("ahk_exe Menu.exe")
			return
		prvRisHwnds:=RisOpened(1)[2]
		settimerf(A_ThisFunc, 1000, [tag, true, A_TickCount])
	}else if(A_TickCount-start_tick>30000){
		settimerf(A_ThisFunc, "off")
	}else if (doTag=1){
		thisRisHwnds:=RisOpened(1)[2]
		for k,v in thisRisHwnds
			if !HasVal(prvRisHwnds, v) && getNetAcc(v, "B_ACTIVE", "WindowsForms10.BUTTON",0,0) {
				
				settimerf(A_ThisFunc, -3000, [tag, v, A_TickCount])
				break
			}
		
	}else{
		WinSetTitle,% "ahk_id " doTag,,% WinGetTitle(doTag) " @ " tag
	}
}

~!#q::
if (A_ThisHotkey = A_PriorHotkey) && (A_TimeSincePriorHotkey<400){
	if h:=WinExist("simple_main ahk_class AutoHotkeyGUI")
		PostMessage,0x10101,,,,% "ahk_id " h
	else if h:=WinExist("simple__main ahk_class AutoHotkeyGUI")
		PostMessage,0x10101,,,,% "ahk_id " h
}
return


:*:chp::
send 000000
send {tab}
send MOCK_PASSWORD
send {Enter}
return

checkLastActiveTick(ByRef lastActiveTick, item, interval){
	if (lastActiveTick[item]=""){
		lastActiveTick[item]:=A_TickCount
		return true
	}
	if (ret:=(lastActiveTick[item]+interval<=A_TickCount))
		lastActiveTick[item]:=A_TickCount
	return ret
}


toggleAutoActivate:
if (autoActiveInfinittToggle:=!autoActiveInfinittToggle){
	ShowToolTip("Disable auto activate", 2000)
}else{
	ShowToolTip("Enable auto activate", 2000)
	settimer,autoActivateInfinitt,-300
}
return

autoActivateInfinitt(){
	global __debug, autoActiveInfinittToggle, simpleRisCapsOverrideUntil
	static prvWin, lastActiveTick:=[], lastMousePos:=[]
	
	if autoActiveInfinittToggle
		return
	
	if WinExist("report? ahk_class AutoHotkeyGUI"){
		settimer,,-3000
		return
	}
	
	MouseGetPos,x,y,activeWin
	if (simpleRisCapsOverrideUntil>A_TickCount){
		; Discard movement sampled before CapsLock. New movement after the
		; override expires continues to activate PACS normally.
		prvWin:=activeWin
		lastMousePos.x:=x,lastMousePos.y:=y
		settimer,,-300
		return
	}
	if(prvWin=activeWin){
		if Abs(lastMousePos.x-x)<20 &&  Abs(lastMousePos.y-y)<20 {
			settimer,,-300
			return
		}else
			lastMousePos.x:=x, lastMousePos.y:=y
	}else{
		if  __debug
			a:=1
		prvWin:=activeWin
		,lastMousePos.x:=x, lastMousePos.y:=y
		settimer,,-300
		return
	}
	
	title:=WinGetTitle(activeWin)
	,activeClass:=WinGetClass(activeWin)
	;~ ,interval:=-300
	if(title="simple RIS" && activeClass="AutoHotkeyGUI"){
		
	}else if(title="INFINITT PACS"){
			MouseGetPos,,,,activeControl,2

		if  ControlGetText(activeControl)="WindowPane" && checkLastActiveTick(lastActiveTick, "infinitt_pacs", 500)
			winactivate,% "ahk_id " activeWin
	}else if(InStr(title, "/webcvis/") && activeClass~="i)Internet Explorer_Server|IEFrame"){
		if checkLastActiveTick(lastActiveTick, "CH_RIS", 500)
			winactivate,% "ahk_id " activeWin
	}else if (activeClass="Shell_TrayWnd"){
		acc:=Acc_ObjectFromPoint(childId)
		if (InStr(barItemName:=acc.accName(childId), "INFINITT PACS")=1 && !WinActive(waitActive:="ahk_id " FindInfinittViewerHwnd()))
			|| ((barItemName~="is)\/webcvis\/.+?Internet Explorer") && !WinActive(waitActive:="webcvis")) 
			|| (!WinExist("/webcvis/ ahk_exe iexplore.exe") && InStr(barItemName, "-C醫院") && !WinActive("-C醫院 ahk_exe iexplore.exe")) {
			if checkLastActiveTick(lastActiveTick, "bar_" barItemName, 1000)
				acc.accDoDefaultAction(childId)
			;~ WinWaitActive,% waitActive,,1
		}
	}
	settimer,autoActivateInfinitt,-300
}

simpleRisCapsOverride(wParam:=0, lParam:=0, msg:=0, hwnd:=0){
	global simpleRisCapsOverrideUntil
	simpleRisCapsOverrideUntil:=A_TickCount+1200
}


infinittLoadedBeep(){
	hwnd:=FindInfinittViewerHwnd()
	if !hwnd
		return
	WinGetPos,x,y,w,h,% "ahk_id " hwnd
	win:=acc_windowFromobject(acc_objectfrompoint("", x+w//3, y+h//3))
	win:=WinGetTitle(WinGetRoot(win))
	if WinGetTitle(win)!="INFINITT PACS"
		return
	
	w:=w//2, h:=h//2
	,x:=x+w//6
	,y:=y+h//5
	PixelGetColor,c,% x,% y
	if(c!=0x000000)
		goto loadedBeep
	PixelGetColor,c,% x+w//2,% y
	if(c!=0x000000)
		goto loadedBeep
	PixelGetColor,c,% x,% y+h//2
	if(c!=0x000000)
		goto loadedBeep
	PixelGetColor,c,% x+w//2,% y+h//2
	if(c!=0x000000)
		goto loadedBeep
	return
	loadedBeep:
	SoundBeep,100,0.1
}

WM_WTSSESSION_CHANGE(wParam, lParam, Msg, hWnd)                                              ; http://msdn.com/library/aa383828(vs.85,en-us)
{
    global thisPlace
    static WTS_CONSOLE_CONNECT        := 0x1    ; The session identified by lParam was connected to the console terminal or RemoteFX session.
			,WTS_CONSOLE_DISCONNECT     := 0x2    ; The session identified by lParam was disconnected from the console terminal or RemoteFX session.
			,WTS_REMOTE_CONNECT         := 0x3    ; The session identified by lParam was connected to the remote terminal.
			,WTS_REMOTE_DISCONNECT      := 0x4    ; The session identified by lParam was disconnected from the remote terminal.
			,WTS_SESSION_LOGON          := 0x5    ; A user has logged on to the session identified by lParam.
			,WTS_SESSION_LOGOFF         := 0x6    ; A user has logged off the session identified by lParam.
			,WTS_SESSION_LOCK           := 0x7    ; The session identified by lParam has been locked.
			,WTS_SESSION_UNLOCK         := 0x8    ; The session identified by lParam has been unlocked.
			,WTS_SESSION_REMOTE_CONTROL := 0x9    ; The session identified by lParam has changed its remote controlled status. To determine the status, call GetSystemMetrics and check the SM_REMOTECONTROL metric.
			,WTS_SESSION_CREATE         := 0xA    ; Reserved for future use.
			,WTS_SESSION_TERMINATE      := 0xB    ; Reserved for future use.
			,prv_monitor_count:=0
			,prv_monitor_width:=0
    
	; WinSessionChange registers for all sessions. Only our own arrival should
	; restore the bridge, and this must run before the monitor-layout early return.
	DllCall("ProcessIdToSessionId", "UInt", DllCall("GetCurrentProcessId"), "UInt*", currentSessionId)
	if (lParam = currentSessionId && InStr(thisPlace, "C hospital")
		&& (wParam = WTS_REMOTE_CONNECT || wParam = WTS_SESSION_LOGON || wParam = WTS_SESSION_UNLOCK))
		SetTimer, StartRisHorosSync, -750

	mon:=monitorInfo()
	switch wParam {
		case WTS_REMOTE_CONNECT,WTS_SESSION_LOGON,WTS_SESSION_UNLOCK:
			if (prv_monitor_count=mon.length() && prv_monitor_width=mon[1].w){
				
				return
			}
			prv_monitor_count:=mon.length()
			prv_monitor_width:=mon[1].w
			TaskKill("G3PACS.exe")
			; simpleRIS can now refresh its cached monitor layout without restarting.
			PostMessage,0x2033,,,,simpleRIS_main ahk_class AutoHotkeyGUI
			for k,v in AltTab_window_list() {
				WinGet,mm,MinMax,% "ahk_id " v.hwnd
				if(mm=1){
					WinGetPos,x,y,w,h,% "ahk_id " v.hWnd
					WinGetPos,,,ww,hh,ahk_class Shell_TrayWnd
					if (Abs(w-A_ScreenWidth)>10 || Abs(h-A_ScreenHeight+hh)>10){
						WinRestore,% "ahk_id " v.hwnd
						Loop
							Sleep 50
						until WinGet("MinMax", v.hwnd)!=1 || A_Index>20
						WinMaximize,% "ahk_id " v.hwnd
					}
						
				}
			}
	}
}


#If % __is_CH && WinActive("ahk_exe iexplore.exe")
F1::
ActivateOrWorkAroundStaleInfinittViewer()
return

+F1::
	; Send report (Alt+1) then block the IE popup that would load PACS next study.
	Send !1
	ArmSendRptIEBlock()
return


ActivateOrWorkAroundStaleInfinittViewer(automatic:=false){
	global CH_RIS

	hwnd:=FindInfinittViewerHwnd()
	if !hwnd
		return G3PacsFallbackActivate(automatic)

	; The G3 viewer can enter a broken single-instance state: RIS launches a new
	; study, the transient G3PACS process exits normally, but the existing viewer
	; keeps the prior patient. F1 is a deliberately manual, one-shot workaround.
	if !IsObject(CH_RIS) || !CH_RIS.has_active_report_wb()
		return G3PacsFallbackActivate(automatic)

	try CH_RIS.get_fields()
	catch
		return G3PacsFallbackActivate(automatic)
	risStudyKey:=G3PacsCurrentRisStudyKey()
	if (risStudyKey="")
		return G3PacsFallbackActivate(automatic)

	try pacs:=new INFINITT_PACS(hwnd)
	catch
		return G3PacsFallbackActivate(automatic)
	pacs.DisposeTimers()

	; An unknown identity normally means the viewer is still loading. Do not kill it.
	matchState:=G3PacsRisViewerMatchState(CH_RIS, pacs)
	if (matchState="" || matchState=1)
		return G3PacsFallbackActivate(automatic)

	; Recheck after a short grace period so F1 cannot interrupt a normal handoff.
	Sleep 1500
	try {
		CH_RIS.get_fields()
		pacs.RefreshInfo(["ChartNo", "ExamDate"])
	}
	catch
		return G3PacsFallbackActivate(automatic)
	matchState:=G3PacsRisViewerMatchState(CH_RIS, pacs)
	if (G3PacsCurrentRisStudyKey()!=risStudyKey || matchState="" || matchState=1)
		return G3PacsFallbackActivate(automatic)

	WinGet,g3Pid,PID,% "ahk_id " hwnd
	WinGet,g3Path,ProcessPath,% "ahk_id " hwnd
	expectedPath:=SubStr(A_WinDir,1,2) "\INFINITTG3\VIEWER\G3PACS.exe"
	if (!g3Pid || g3Path="" || g3Path!=expectedPath) {
		DebugLog("ActivateOrWorkAroundStaleInfinittViewer", "refused restart: viewer executable path was not the expected G3PACS path")
		return G3PacsFallbackActivate(automatic)
	}

	DebugLog("ActivateOrWorkAroundStaleInfinittViewer", "confirmed RIS/PACS mismatch; restarting G3PACS pid=" g3Pid)
	Process,Close,%g3Pid%
	Process,WaitClose,%g3Pid%,5
	if ErrorLevel {
		DebugLog("ActivateOrWorkAroundStaleInfinittViewer", "G3PACS did not exit; current study was not relaunched")
		return false
	}

	Sleep 300
	if !CH_RIS.has_active_report_wb() || G3PacsCurrentRisStudyKey()!=risStudyKey
		return false
	try CH_RIS.inputElements.openImage.Click()
	catch {
		DebugLog("ActivateOrWorkAroundStaleInfinittViewer", "G3PACS exited, but the RIS PACS button could not be clicked")
		return false
	}
	if !automatic
		G3PacsRecordManualForcedLoad(risStudyKey)
	return true
}

G3PacsFallbackActivate(automatic){
	if automatic
		return false
	return ActivateInfinittViewerFromRIS()
}

G3PacsCurrentRisStudyKey(){
	global CH_RIS
	studyKey:=Trim(CH_RIS.accNo)
	if (studyKey="")
		studyKey:=Trim(CH_RIS.referno)
	return studyKey
}

G3PacsRisViewerMatchState(ris, pacs){
	risChartNo:=Trim(ris.chartNo)
	,pacsChartNo:=Trim(pacs.ChartNo_)
	if (risChartNo="" || pacsChartNo="")
		return ""
	if (risChartNo!=pacsChartNo)
		return 0

	; Chart number identifies the patient, not necessarily the study. When both
	; sides expose examination time, use it to distinguish same-patient studies.
	risStamp:=RegExReplace(Trim(ris.checktime), "\D")
	risDate:=SubStr(risStamp,1,8)
	,risTime:=SubStr(risStamp,9,6)
	if (StrLen(risDate)<8)
		risDate:=SubStr(RegExReplace(Trim(ris.examdate), "\D"),1,8)
	if (StrLen(risTime)<4)
		risTime:=SubStr(RegExReplace(Trim(ris.examtime), "\D"),1,6)
	pacsDate:=SubStr(RegExReplace(Trim(pacs.examDate_), "\D"),1,8)
	,pacsTime:=SubStr(RegExReplace(Trim(pacs.examTime_), "\D"),1,6)
	if (StrLen(risDate)>=8 && StrLen(pacsDate)>=8 && risDate!=pacsDate)
		return 0
	if (StrLen(risTime)>=4 && StrLen(pacsTime)>=4 && SubStr(risTime,1,4)!=SubStr(pacsTime,1,4))
		return 0
	return 1
}

G3PacsEnsureStudyChangeHook(){
	global CH_RIS, g_G3PacsStudyChangeHook, g_G3PacsStudyChangeHookRegistered
	if !IsObject(CH_RIS)
		return false
	if g_G3PacsStudyChangeHookRegistered
		return true
	if !IsObject(g_G3PacsStudyChangeHook)
		g_G3PacsStudyChangeHook:=Func("G3PacsOnRisStudyChanged")
	CH_RIS.AddAccNoChangedHookFn(g_G3PacsStudyChangeHook)
	g_G3PacsStudyChangeHookRegistered:=true
	return true
}

G3PacsRecordManualForcedLoad(studyKey){
	global g_G3PacsAutoForcedLoadMode, g_G3PacsForcedLoadStreak
	global g_G3PacsStudySequence, g_G3PacsHasLastForcedSequence
	global g_G3PacsLastForcedSequence, g_G3PacsLastForcedStudyKey
	global g_G3PacsAutoPromptPending

	if (g_G3PacsAutoForcedLoadMode || studyKey="" || studyKey=g_G3PacsLastForcedStudyKey)
		return
	if !G3PacsEnsureStudyChangeHook()
		return

	if (g_G3PacsHasLastForcedSequence && g_G3PacsStudySequence=g_G3PacsLastForcedSequence+1)
		g_G3PacsForcedLoadStreak++
	else
		g_G3PacsForcedLoadStreak:=1
	g_G3PacsHasLastForcedSequence:=true
	g_G3PacsLastForcedSequence:=g_G3PacsStudySequence
	g_G3PacsLastForcedStudyKey:=studyKey
	DebugLog("G3PacsRecordManualForcedLoad", "manual forced-load streak=" g_G3PacsForcedLoadStreak)

	if (g_G3PacsForcedLoadStreak>=3 && !g_G3PacsAutoPromptPending) {
		g_G3PacsAutoPromptPending:=true
		g_G3PacsForcedLoadStreak:=0
		g_G3PacsHasLastForcedSequence:=false
		g_G3PacsLastForcedStudyKey:=""
		SetTimerFn("G3PacsOfferAutoForcedLoadMode", -2500)
	}
}

G3PacsOfferAutoForcedLoadMode(){
	global CH_RIS, g_G3PacsAutoForcedLoadMode, g_G3PacsAutoPromptPending
	global g_G3PacsAutoLastScheduledStudyKey
	g_G3PacsAutoPromptPending:=false
	if (g_G3PacsAutoForcedLoadMode)
		return

	message:="G3PACS required forced image loading for 3 consecutive studies."
		. "`n`nEnable automatic forced image loading for each new RIS study?"
		. "`n`nThis mode ends when Autorun.exe is restarted."
	MsgBox,36,G3PACS automatic forced image loading,%message%
	IfMsgBox,Yes
	{
		if !G3PacsEnsureStudyChangeHook()
			return
		g_G3PacsAutoForcedLoadMode:=true
		g_G3PacsAutoLastScheduledStudyKey:=G3PacsCurrentRisStudyKey()
		DebugLog("G3PacsOfferAutoForcedLoadMode", "automatic forced image loading enabled for this Autorun.exe session")
	}
	else
		DebugLog("G3PacsOfferAutoForcedLoadMode", "automatic forced image loading declined")
}

G3PacsOnRisStudyChanged(){
	global CH_RIS, g_G3PacsStudySequence, g_G3PacsAutoForcedLoadMode
	global g_G3PacsAutoLastScheduledStudyKey
	g_G3PacsStudySequence++
	if !g_G3PacsAutoForcedLoadMode
		return
	if !IsObject(CH_RIS) || !CH_RIS.has_active_report_wb()
		return
	try CH_RIS.get_fields()
	catch
		return
	studyKey:=G3PacsCurrentRisStudyKey()
	if (studyKey="" || studyKey=g_G3PacsAutoLastScheduledStudyKey)
		return
	g_G3PacsAutoLastScheduledStudyKey:=studyKey
	DebugLog("G3PacsOnRisStudyChanged", "new RIS study detected; scheduling automatic forced-load check")
	; The normal post-reboot handoff took about four seconds. Wait longer than
	; that before applying the guarded mismatch check, then allow its own recheck.
	SetTimerFn("G3PacsAutoForcedLoadForStudy", -4500, [studyKey])
}

G3PacsAutoForcedLoadForStudy(studyKey){
	global CH_RIS, g_G3PacsAutoForcedLoadMode
	if !g_G3PacsAutoForcedLoadMode
		return
	if !IsObject(CH_RIS) || !CH_RIS.has_active_report_wb()
		return
	try CH_RIS.get_fields()
	catch
		return
	if (G3PacsCurrentRisStudyKey()!=studyKey)
		return
	if ActivateOrWorkAroundStaleInfinittViewer(true)
		DebugLog("G3PacsAutoForcedLoadForStudy", "automatic forced-load workaround applied")
	else
		DebugLog("G3PacsAutoForcedLoadForStudy", "automatic forced-load workaround was not needed or could not be applied")
}



ch_ris_login:
~!r::

if (GetKeyState("Lbutton")){
	TaskKill("iexplore.exe")
	wb:=ComObjCreate("InternetExplorer.Application")
	wb.Visible:=true
	wb.NAvigate("http://10.0.0.1:9090/webcvis/comm/login.jsp")
	WinMaximize, % "ahk_id " wb.hwnd
	Winactivate, % "ahk_id " wb.hwnd
	send {LButton UP}
}else{

activeWin:=WinExist("A")
;~ if !InStr(activeTitle:=WinGetTitle(activeWin), "C醫院") && !InStr(activeTitle, "Web權控管理")
	;~ return
ch_ris_browser_found:=false
for wb in ComObjCreate("Shell.Application").Windows()
	if (InStr(WinGetTitle(wb.hwnd), "C醫院") || InStr(wb.LocationUrl,":9090/webcvis/MJB")) && (wb.hwnd=activeWin) {
		ch_ris_browser_found:=true
		break
	}
	
if(!ch_ris_browser_found){
	for wb in ComObjCreate("Shell.Application").Windows()
		if (wb.hwnd=activeWin) 
			break
}

ch_ris_ip:=InStr(wb.LocationUrl, "192.0.2.10") ?"192.0.2.10":"10.0.0.1"

wb.NAvigate("http://" ch_ris_ip ":9090/webcvis/comm/login.jsp")
}

wbWaitElement(wb, "loginButton")
Loop % (inputs:=wb.document.getElementsByTagName("input")).length {
	try{
		e:=inputs[A_Index]
		if(e.NAme="userid"){
			e.value:="000000"
		}else if(e.name="password")
			e.value:="MOCK_PASSWORD"
	}
}
wb.document.getElementById("loginButton").Click()
wbWaitElement(wb, "menuItem_EMN20081229102711")
if (IsCurrentSessionRDP()) {
	WinMaximize, % "ahk_id " wb.hwnd
	WinActivate, % "ahk_id " wb.hwnd
	WinWaitActive, % "ahk_id " wb.hwnd,, 2
	if WinActive("ahk_id " wb.hwnd)
		SendInput, ^0   ; restore IE's RDP default zoom (200%)
}
;~ wb.NAvigate("http://" ch_ris_ip ":9090/webcvis/MJB/MJB3W001.do")
wb.NAvigate("http://" ch_ris_ip ":9090/webcvis/MJB/MJB3W001.do?orderIndex=&checkdruserid=000000&continuousinput=on&status=00&mccid=54&d-4032128-s=7&d-4032128-p=1&d-4032128-o=2")
Sleep 500
wbWaitElement(wb, "QueryButton")
wb.document.getElementById("QueryButton").click()
return
#if

; Paste the current C hospital RIS study into Google Sheets.
; Select the row's Chart No cell first; the Index column to its left is left intact.
#If __is_CH
^!g::PasteRisBasicInfoToSheet()
#If

PasteRisBasicInfoToSheet(){
	global CH_RIS

	if !IsObject(CH_RIS) || !CH_RIS.has_active_report_wb() {
		RisSheetShowTip("No RIS report page is open.")
		return false
	}

	try CH_RIS.get_fields()
	catch e {
		RisSheetShowTip("Could not read the RIS report page.")
		return false
	}

	chartNo:=RisSheetClean(CH_RIS.chartNo)
	,age:=RisSheetClean(CH_RIS.age)
	,gender:=RisSheetGender(CH_RIS.gender)
	,imageDate:=RisSheetDate(CH_RIS.checktime, CH_RIS.examdate)
	,examName:=RisSheetClean(CH_RIS.examname)
	,modality:=RisSheetModality(CH_RIS.mdpid, CH_RIS.mccid, examName)
	,bodyPart:=RisSheetBodyPart(examName)

	if (chartNo="" || age="" || gender="" || imageDate="" || modality="" || bodyPart="") {
		RisSheetShowTip("RIS data is incomplete; nothing was pasted.")
		return false
	}

	; A leading apostrophe makes Sheets retain leading zeroes in the chart number.
	row:="'" chartNo "`t" age "`t" gender "`t" imageDate "`t" modality "`t" bodyPart
	Clipboard:=""
	Clipboard:=row
	ClipWait,1
	if ErrorLevel {
		RisSheetShowTip("Could not prepare the RIS row.")
		return false
	}
	SendInput,^v
	RisSheetShowTip("RIS info pasted: " chartNo)
	return true
}

RisSheetClean(value){
	return Trim(RegExReplace("" value, "[\t\r\n]+", " "))
}

RisSheetGender(value){
	value:=Trim("" value)
	if (value=1 || value~="i)^(m|male|男性)$")
		return "m"
	if (value=2 || value~="i)^(f|female|女性)$")
		return "f"
	return ""
}

RisSheetDate(checkTime, examDate){
	digits:=RegExReplace(SubStr(Trim("" checkTime),1,10), "\D")
	if (StrLen(digits)!=8)
		digits:=RegExReplace(Trim("" examDate), "\D")
	if (StrLen(digits)!=8)
		return ""
	return SubStr(digits,1,4) "/" SubStr(digits,5,2) "/" SubStr(digits,7,2)
}

RisSheetModality(mdpid, mccid, examName){
	source:=Trim("" mdpid) " " examName
	if (source~="i)\b(?:MRI|MRA|MRV|MRCP|MR)\b|磁振|核磁")
		return "MRI"
	if (source~="i)\b(?:CT|CTA|CTV)\b|電腦斷層")
		return "CT"
	if (source~="i)\b(?:X[- ]?RAY|XR)\b|一般攝影")
		return "X-ray"
	if (source~="i)\b(?:MAMMO|MG)\b|乳房攝影")
		return "Mammo"
	if (source~="i)\b(?:US|SONO)\b|超音波")
		return "US"
	if (source~="i)\bBMD\b|骨密")
		return "BMD"
	if (mccid=54)
		return "CT"
	if (mccid=55)
		return "MRI"
	if (mccid=57)
		return "BMD"
	return ""
}

RisSheetBodyPart(examName){
	if (examName~="i)(?:\bhead\b|頭).*(?:\bneck\b|頸)|(?:\bneck\b|頸).*(?:\bhead\b|頭)")
		return "head/neck"
	if (examName~="i)\bbrain\b|腦")
		return "brain"
	if (examName~="i)\bhead\b|頭")
		return "head"
	if (examName~="i)\bcervical\b.*\bspine\b|\bC[- ]?spine\b|頸椎")
		return "cervical spine"
	if (examName~="i)\bthoracic\b.*\bspine\b|\bT[- ]?spine\b|胸椎")
		return "thoracic spine"
	if (examName~="i)\blumbar\b.*\bspine\b|\bL[- ]?spine\b|腰椎")
		return "lumbar spine"
	if (examName~="i)\bspine\b|脊椎")
		return "spine"
	if (examName~="i)(?:\babdomen\b|腹).*(?:\bpelvis\b|骨盆)|(?:\bpelvis\b|骨盆).*(?:\babdomen\b|腹)")
		return "abdomen/pelvis"
	if (examName~="i)\bchest\b|\bthorax\b|\blung\b|胸|肺")
		return "chest"
	if (examName~="i)\babdomen\b|腹")
		return "abdomen"
	if (examName~="i)\bpelvis\b|骨盆")
		return "pelvis"
	if (examName~="i)\bbreast\b|乳房")
		return "breast"
	for _,part in ["shoulder","elbow","wrist","hand","finger","hip","knee","ankle","foot"]
		if (examName~="i)\b" part "\b")
			return part

	; Fallback for uncommon studies: remove modality and protocol wording.
	part:=RegExReplace(examName, "[（(][^）)]*[）)]", " ")
	,part:=RegExReplace(part, "i)\b(?:MRI|MRA|MRV|MRCP|MR|CT|CTA|CTV|X[- ]?RAY|XR|MAMMO|MG|US|SONO|BMD)\b", " ")
	,part:=Trim(RegExReplace(part, "\s+", " "))
	StringLower,part,part
	return part
}

RisSheetShowTip(message){
	ToolTip,% message
	SetTimer,RisSheetClearTip,-2000
}

RisSheetClearTip:
	ToolTip
return

#If __is_CH && WinActive("傳送 ahk_exe G3PACS.exe")
Space::
ControlClick,傳送,傳送 ahk_exe G3PACS.exe
return
RButton::
WinClose,傳送 ahk_exe G3PACS.exe
return
#IfWinExist

WinShellHook(hWnd, win_title, win_class, win_exe, win_event){
	global g_SendRptRisPid, CH_RIS, g_LastRisReportHwnd
	if(win_event=1){
		; If armed by +F1: close the openimg.jsp popup (same PID as RIS, not the MJB list page)
		if (g_SendRptRisPid) {
			WinGet, pid, PID, ahk_id %hWnd%
			if (pid = g_SendRptRisPid && win_class = "IEFrame" && !InStr(win_title, "webcvis/MJB")) {
				WinClose, ahk_id %hWnd%
				return
			}
		}
		TrackRisReportIE()
		SetTimerFn("WinHookWait", 500, [hWnd, win_title, win_class, win_exe, win_event, A_TickCount])
	}else if(win_event=2){
		current_wb_hwnd:=TrackRisReportIE()
		reportClosed:=(hWnd && ((current_wb_hwnd && hWnd=current_wb_hwnd) || (g_LastRisReportHwnd && hWnd=g_LastRisReportHwnd)))
		if (reportClosed) {
			g_LastRisReportHwnd:=0
			QueueActivateRisListIE()
		}
	}
}

TrackRisReportIETimer:
	TrackRisReportIE()
return

TrackRisReportIE(){
	global CH_RIS, g_LastRisReportHwnd
	DetectHiddenWindows,on
	try reportHwnd:=CH_RIS.wb.hwnd
	catch
		reportHwnd:=0
	if (reportHwnd && WinExist("ahk_id " reportHwnd)) {
		g_LastRisReportHwnd:=reportHwnd
		return reportHwnd
	}
	return 0
}

QueueActivateRisListIE(retries:=3){
	global g_ActivateRisListRetries
	g_ActivateRisListRetries:=retries
	SetTimer, ActivateRisListIELater, -100
}

ActivateRisListIELater:
	if (ActivateRisListIE())
		return
	if (g_ActivateRisListRetries>0) {
		g_ActivateRisListRetries--
		SetTimer, ActivateRisListIELater, -500
	}
return

ActivateRisListIE(){
	global CH_RIS
	DetectHiddenWindows,on
	try listHwnd:=CH_RIS.ris_list_wb.wb.hwnd
	catch
		listHwnd:=0
	if (listHwnd && WinExist("ahk_id " listHwnd)) {
		WinShow,% "ahk_id " listHwnd
		WinActivate,% "ahk_id " listHwnd
		return true
	}

	ControlGetText,listHwnd,Edit1,CH_RIS_LIST_GUI ahk_class AutoHotkeyGUI
	if (listHwnd && WinExist("ahk_id " listHwnd)) {
		WinShow,% "ahk_id " listHwnd
		WinActivate,% "ahk_id " listHwnd
		return true
	}

	for wb in ComObjCreate("Shell.Application").Windows() {
		try {
			if InStr(wb.FullName, "iexplore.exe") && InStr(wb.LocationURL, ":9090/webcvis/MJB/MJB3W001.do") {
				WinShow,% "ahk_id " wb.hwnd
				WinActivate,% "ahk_id " wb.hwnd
				return true
			}
		}
	}
	return false
}

WinHookWait(hWnd, win_title, win_class, win_exe, win_event, tickcount){
	;~ win_title:=WinGetTitle(hwnd)
	;~ if(win_title~="i)webcvis\/MJB"){
		;~ if(A_ScreenHeight>2300 || A_ScreenWidth>2300){
			;~ WinMove,% "ahk_id " hwnd,,55,0,% A_ScreenWidth//2,% A_ScreenHeight
		;~ }else{
			;~ WinMaximize,% "ahk_id " hwnd
		;~ }
	;~ }
	if(A_TickCount-tickcount>5000){
		SetTimerFn("WinHookWait", "off")
	}
}

#if % __is_CH
^#q::
TaskKill("G3PACS.exe")
return
#if

; list all processes of reportset 
+#l::
reportsetproclistall:
res:=[]
for k,proc in ProcessList()
{
	if instr(proc.path,root){
		win_list_1:=WinGetList("ahk_class AutoHotkeyGUI ahk_pid " proc.pid,"","","",true)
		win_list_2:=WinGetList("ahk_class AutoHotkeyGUI ahk_pid " proc.pid,"","","",true)
		win_titles:=","
		for k,w in win_list_1
			if !InStr(win_titles, "," t:=WinGetTitle(w) ",")
				win_titles.=t ","
		for k,w in win_list_2
			if !InStr(win_titles, "," t:=WinGetTitle(w) ",")
				win_titles.=t ","
		
		proc["wins"]:=SubStr(win_titles,2)
		res.push(proc)
	}
}
gui,reportsetproc:new,+lastfound +hwndreportsetprocguihwnd
gui,reportsetproc:add,ListView,r20 w700 ,PID|Name|WinTitles
for k,v in res
	LV_Add("",  v.pid, v.name, v.wins)
LV_ModifyCol()
gui,reportsetproc:show,Center,reportset processes
GroupAdd,reportsetprocgui,ahk_id %reportsetprocguihwnd%
return

#IfWinActive,ahk_group reportsetprocgui
reportsetprocGUIClose:
reportsetprocGUIEscape:
esc::
WinClose,ahk_group reportsetprocgui
return
k::
gui,reportsetproc:Default
RowNumber := 0  ; This causes the first loop iteration to start the search at the top of the list.
Loop
{
    RowNumber := LV_GetNext(RowNumber)  ; Resume the search at the row after that found by the previous iteration.
    if not RowNumber  ; The above returned zero, so there are no more selected rows.
        break
    LV_GetText(pid, RowNumber, 1)
	TaskKill(pid)
    ShowToolTip("Killed process: " pid)
	Loop{
		Sleep -1
		process,Exist,% pid
	}until !ErrorLevel
	goto reportsetproclistall
}
return
#IfWinActive

~r::
if (A_TimeSincePriorHotkey<500 && A_PriorHotkey==A_ThisHotkey && GetKeyState("Lbutton")){
	p:=ComObjCreate("InternetExplorer.Application")
	p.Visible:=true
	p.NAvigate("http://10.0.0.1:9090/webcvis/comm/login.jsp")
	WinMaximize,% "ahk_id " p.hwnd
	winactivate,% "ahk_id " p.hwnd
}
return 


#IfWinActive,ahk_exe G3PACS.exe
~RButton::
if !(A_ThisHotkey=A_PriorHotkey && A_TimeSincePriorHotkey<500)
	return
send {del}
return

RAlt::
	gosub ActivateRisPage
return

#IfWinActive,simpleRIS ahk_class AutoHotkeyGUI
RAlt::
	gosub ActivateRisPage
return

#IfWinActive


ActivateRisPage:
	; Try to activate RIS study (report) page
	; Look for IE window with /webcvis/ in title
	if WinExist("/webcvis/ ahk_exe iexplore.exe") {
		WinActivate
		return
	}

	; Fallback: activate any iexplore window as last resort
	if WinExist("ahk_exe iexplore.exe") {
		WinActivate
		return
	}

	; No RIS windows available
	ToolTip, No RIS windows available
	SetTimer, clearRisPageTooltip, 2000
return

clearRisPageTooltip:
	ToolTip
return


::pwtb::
send RA900159
send {Tab}
send 123123
send {Enter}
return

; ArmSendRptIEBlock([ieHwnd])
; Arms the shell-hook guard that closes the openimg.jsp IE popup (which would cause
; PACS to load the next study).  Also writes a flag file so RisHorosSync skips the
; next accNo change caused by the auto-advance of the RIS page after sending.
; ieHwnd: optional hwnd of the IE window; defaults to the current active window.
ArmSendRptIEBlock(ieHwnd := 0) {
	global g_SendRptRisPid, g_SendRptOwnHook, monitorCount
	if ieHwnd
		WinGet, g_SendRptRisPid, PID, ahk_id %ieHwnd%
	else
		WinGet, g_SendRptRisPid, PID, A
	if (monitorCount > 1 && !g_SendRptOwnHook)
		g_SendRptOwnHook := WinHook.Shell.Add("WinShellHook",,, "iexplore.exe", 1)
	SetTimer, SendRptDisarmHook, -10000
	; Signal RisHorosSync to skip the next accNo change (RIS auto-advances after send)
	try FileAppend, 1, % A_Temp "\RisHorosSyncSkip.flag"
	; Tooltip near cursor while suppression is active
	MouseGetPos, _armTipX, _armTipY
	ToolTip, Block next study: PACS + Horos sync suppressed, % _armTipX+16, % _armTipY+24
}

SendRptDisarmHook:
	; Disarm the IE-popup guard after 10 seconds.
	global g_SendRptRisPid, g_SendRptOwnHook
	g_SendRptRisPid := 0
	if g_SendRptOwnHook {
		WinHook.Shell.Remove(g_SendRptOwnHook)
		g_SendRptOwnHook := 0
	}
	ToolTip  ; clear the suppression tooltip
return
#If WinActive("ahk_exe RadTemplate.exe ahk_class AutoHotkeyGUI") && !WinActive("Radiology Template")
~LButton::
    if (A_PriorHotkey = "~LButton" && A_TimeSincePriorHotkey < 400)
    {
        MouseGetPos,,,, ctrl
        if InStr(ctrl, "Edit")
            return

        ControlGet, hBtn, Hwnd,, To Clipboard, A
        if (hBtn)
            ControlClick, To Clipboard, A
    }
return
#If
