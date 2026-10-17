#persistent
#NoTrayIcon
#SingleInstance,force
;~ process,Priority,,h
; Does not use CH_RIS — opt out of owning a local (IE-polling) CH_RIS. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <risimpax>
#include <WindowShellEvent>
SetTitleMatchMode,2
SetTitleMatchMode,fast
SetBatchLines,-1
SetWinDelay, -1
SetControlDelay,-1
;~ OnExit,OnExit
;~ MsgBox
IgnoreKey=
(LTrim Join|
LButton
RButton
MButton
Ctrl
Shift
Alt
LWin
RWin
)
IgnoreKey:=StrSplit(Ignorekey, "|")


,WindowShellEvent("ShellMessage")

gui,+hwndguihwnd
WinSetTitle,ahk_id %guihwnd%,,killUpdate
if regexmatch(a_scriptdir,"is)(.+?)\\scripts\\Autorun$",match)
	root:=match1, partialMode:=false
else{
	root:=a_scriptdir, partialMode:=true
	;~ gosub copyMainExe
	AllowList:="`n"
	
	Loop,% a_scriptdir "\*.exe",1,1
	{
		SplitPath,A_LoopFileLongPath,,,,nameNoExt
		AllowList.=nameNoExt "`n"
	}
	
}
settimer,routine,3000
SetTimer,routine2,3000
return


ShellMessage( wParam,lParam ) { 
	global IgnoreKey
	
  If ( wParam=1 ) {
	for k,v in Ignorekey
		if GetKeyState(v)
			return
	
	;~ winget,activeId,id,A
	;~ WinGetTitle,t,ahk_id %lParam%
	;~ WinGet,pName,ProcessName,ahk_id %lParam%
	;~ if winMatchTitle(t,pName,"kReport","Menu.exe")
		;~ ControlClick,Button1,% t " ahk_exe " pName
	;~ else if winMatchTitle(
	
	routine(lParam)
		
  }
} 

routine(lParam){
	global partialMode, root, AllowList
	
	if (partialMode){
		if h:=winexist("開啟檔案 ahk_class #32770","% A_ScriptDir")
			ControlClick,Button1,開啟檔案 ahk_class #32770,% A_ScriptDir
		else if h:=winexist("Symantec Endpoint Protection ahk_class #32770")
		{
			ControlGetText,t,Static7,ahk_id %h%
			t:=RegExReplace(Trim(t), "i).exe$", "")
			if InStr(AllowList, "`n" t "`n")
				ControlClick,Button2,ahk_id %h%
		}
	}
	
	if h:=winexist("kReport ahk_exe Menu.exe", "已無任何待判讀")
		controlclick,Button1,ahk_id %h%
	else if h:=winexist("ahk_class #32770", "已有程式執行中,是否確定重複開啟程式")
		controlclick,Button1,ahk_id %h%
	else if h:=winexist("發生錯誤 ahk_exe impax-client-main.exe")
	{
		WinClose,ahk_id %h%
		SetTimer,kill_impax,-1
	}
	else if h:=winexist("Microsoft Office Activation Wizard ahk_class NUIDialog")
		controlsend,NetUIHWND1,{esc},ahk_id %h%
	else if h:=winexist("放射線資訊管理系統(Radiology Information System)","Unhandled exception")
		for k,v in getControls(h)
			if instr(v.text,"Continue"){
				controlclick,,% "ahk_id " v.hwnd
				break
			}
	else if h:=winexist("放射線資訊管理系統(Radiology Information System)","未處理的例外狀況")
		for k,v in getControls(h)
			if instr(v.text,"繼續"){
				controlclick,,% "ahk_id " v.hwnd
				break
			}
	else if (WinGetClass("ahk_id " lParam)=="#32770"){
		if h:=winexist("Error ahk_class #32770","A problem occurred and the application")
			controlclick,Button1,ahk_id %h%
		else if h:=winexist("錯誤 ahk_class #32770","發生問題，應用程式無法繼續執行")
			controlclick,Button1,ahk_id %h%
		else if h:=winexist("Windows - 沒有磁片")
			controlclick,Button1,ahk_id %h%
		else if h:=winexist("ahk_class #32770","Specifically: vinfoGuiText")
			controlclick,Button1,ahk_id %h%
		else if h:=winexist("SciTE4AutoHotkey Updater ahk_class #32770")
			controlclick,Button2,ahk_id %h%
		else if (controlgettext("Static7", "Symantec Endpoint Protection ahk_class #32770")="getalljpeg.exe")
			ControlClick,Button2,Symantec Endpoint Protection ahk_class #32770

		else if h:=winexist("ahk_class #32770","hotkeys have been received in the last")
			ControlClick,Button1,ahk_id %h%
	}	
	
	else if impaxExport:=h:=winexist("匯出影像 ahk_class WindowsForms10.Window.8.app.0.2bf8098")
		if impaxExportQuality:=getNetControl2(impaxExport,"(1-100)","","","","","","",6)[1]
			if (controlgettext(impaxExportQuality)="90")
				controlsettext,,100,ahk_id %impaxExportQuality%
	else if h:=winexist("Sleipnir ahk_class #32770","Latest version of Sleipnir")
		controlclick,Button2,ahk_id %h%
	else if winexist("","Unhandled exception")
		controlclick,&Quit,ahk_id %h%
else if h:=winexist("ahk_exe DW20.exe","發生問題")
	controlclick,Button1,ahk_id %h%
else if h:=winexist("","是否確定要離開放射線資訊管理")
	controlclick,Button1,ahk_id %h%
else if h:=winexist("","密碼輸入錯誤")
	controlclick,Button1,ahk_id %h%
else if h:=winexist("kReport","無符合篩選條件的資料")
	winclose,ahk_id %h%
else if h:=winexist("","查無使用者帳號")
	controlclick,Button1,ahk_id %h%
else if h:=winexist("ahk_exe dwwin.exe","simpleRIS")
{
	controlclick,Button1,ahk_id %h%
	sleep 100
	if(partialMode)
		run,% commands(root "\AutoHotkey.exe", root "\PacsIE\simpleRIS.ahk"),% root "\PacsIE"
	else
		run % root "\scripts\Radiology\PacsIE\simpleRIS.exe"
}
else if h:=winexist("simpleRIS.exe ahk_exe WerFault.exe")
{
	winclose,ahk_id %h%
	PostMessage,0x10101,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	TaskKill("simpleRIS.exe")
	if(partialMode)
		run,% commands(root "\AutoHotkey.exe", root "\PacsIE\simpleRIS.ahk"),% root "\PacsIE"
	else
		run % root "\scripts\Radiology\PacsIE\simpleRIS.exe"
}
else if h:=winexist("ahk_exe ContextServer.exe","HRESULT")
	winclose,ahk_id %h%

;~ else if h:=winexist("Handle is NULL","buffer")
	;~ WinClose,ahk_id %h%
;~ else if h:=winexist("OpenProcess Failed","Unable")
	;~ WinClose,ahk_id %h%
	else If (dh:=h:=winexist("Incoming Connection ahk_class MozillaDialogClass")) || (dh1:=h:=winexist("連入連線 ahk_class MozillaDialogClass")) {
		winactivate,ahk_id %dh%
		ControlClick,x211 y181,ahk_id %dh%
		winactivate,ahk_id %dh1%
		ControlClick,x152 y147,ahk_id %dh1%
	}
	else if h:=winexist("ahk_class #32770","查無此使用者帳號")
		WinClose,ahk_id %h%
	else if h:=winexist("ahk_exe rebootMsg.exe")
		WinClose,ahk_id %h%
	

	else if h:=winexist("EBMpreload.exe ahk_exe WerFault.exe"){
		SetTimer,reopenEBMpreload,-1
		

	}


}

reopenEBMpreload(){
	global EBMpath
	for k,v in pl:=processlist()
		if (v.name="EBMpreload.exe"){
			EBMpath:=v.path
			break
		}
	Loop {
		TaskKill("EBMpreload.exe")
		process,Close,EBMpreload.exe
	}until !ErrorLevel
	run % p
}


kill_impax(){
	Loop {
		TaskKill("impax-client-main.exe")
		process,close,impax-client-main.exe
	}until (!ErrorLevel) 
}
;~ OnExit:
;~ ListLinsuperior aspect of	
;~ return

winMatchTitle(ByRef title,ByRef pName,ByRef matchTitle,ByRef matchpName){
	if InStr(title, matchTitle) && (pName=matchpName)
		return true
	else
		return false
}

routine2:
ifwinexist,kReport ahk_exe Menu.exe,% "已無任何待判讀"
	controlclick,Button1
ifwinexist,ahk_class #32770,% "已有程式執行中,是否確定重複開啟程式"
	controlclick,Button1
return

routine:
IfWinExist,發生錯誤 ahk_exe impax-client-main.exe
{
	WinClose
	Loop {
		TaskKill("impax-client-main.exe")
		process,close,impax-client-main.exe
	}until (!ErrorLevel)
}

;~ MsgBox % partialMode
;~ ToolTip % WinExist("ahk_class #32770","已有程式執行中,是否確定重複開啟程式")
ifwinexist,Sleipnir ahk_class #32770,Latest version of Sleipnir
	controlclick,Button2,Sleipnir ahk_class #32770,Latest version of Sleipnir
ifwinexist,SciTE4AutoHotkey Updater ahk_class #32770
	controlclick,Button2,SciTE4AutoHotkey Updater ahk_class #32770
ifwinexist,Microsoft Office Activation Wizard ahk_class NUIDialog
	controlsend,NetUIHWND1,{esc},Microsoft Office Activation Wizard ahk_class NUIDialog
ifwinexist,ahk_class #32770,The type initializer for 'HL7.HL7Port' threw an exception.
{
	controlclick,Button1,ahk_class #32770,The type initializer for 'HL7.HL7Port' threw an exception.
	winshow,Sleipnir ahk_class SleipnirMainWindow
}
if winHwnd:=winexist("放射線資訊管理系統(Radiology Information System)","Unhandled exception")
	for k,v in getControls(winHwnd)
		if instr(v.text,"Continue")
			controlclick,,% "ahk_id " v.hwnd
if winHwnd:=winexist("放射線資訊管理系統(Radiology Information System)","未處理的例外狀況")
	for k,v in getControls(winHwnd)
		if instr(v.text,"繼續")
			controlclick,,% "ahk_id " v.hwnd
ifwinexist,Error ahk_class #32770,A problem occurred and the application
	controlclick,Button1,Error ahk_class #32770,A problem occurred and the application
ifwinexist,% "錯誤 ahk_class #32770",% "發生問題，應用程式無法繼續執行"
	controlclick,Button1,錯誤 ahk_class #32770,% "發生問題，應用程式無法繼續執行"
ifwinexist,% "Windows - 沒有磁片"
	controlclick,Button1,% "Windows - 沒有磁片"
ifwinexist,ahk_class #32770,Specifically: vinfoGuiText
	controlclick,Button1
if impaxExport:=winexist("匯出影像 ahk_class WindowsForms10.Window.8.app.0.2bf8098")
	if impaxExportQuality:=getNetControl2(impaxExport,"(1-100)","","","","","","",6)[1]
		if (controlgettext(impaxExportQuality)="90")
			controlsettext,,100,ahk_id %impaxExportQuality%
;~ ifwinexist,ahk_exe Sleipnir.exe,簽章完成
	;~ controlclick,Button1
;~ ifwinexist,% "Internet Explorer Script Error ahk_class Internet Explorer_TridentDlgFrame"
	;~ winclose,% "Internet Explorer Script Error ahk_class Internet Explorer_TridentDlgFrame"
;~ else ifwinexist,% "Internet Explorer 指令碼錯誤 ahk_class Internet Explorer_TridentDlgFrame"
	;~ winclose,% "Internet Explorer 指令碼錯誤 ahk_class Internet Explorer_TridentDlgFrame"
;~ ifwinexist,ahk_class #32770,已有程式執行中,是否確定重複開啟程式
	;~ controlclick,Button3
ifwinexist,,Unhandled exception
	controlclick,&Quit
ifwinexist,ahk_exe DW20.exe,發生問題
	controlclick,Button1
ifwinexist,,是否確定要離開放射線資訊管理
	controlclick,Button1
ifwinexist,,密碼輸入錯誤
	controlclick,Button1
ifwinexist,kReport,無符合篩選條件的資料
	winclose
ifwinexist,,查無使用者帳號
	controlclick,Button1
ifwinexist,ahk_exe dwwin.exe,simpleRIS
{
	controlclick,Button1
	sleep 100
	if(partialMode)
		run,% commands(root "\AutoHotkey.exe", root "\PacsIE\simpleRIS.ahk"),% root "\PacsIE"
	else
		run % root "\scripts\Radiology\PacsIE\simpleRIS.exe"
}
ifwinexist,simpleRIS.exe ahk_exe WerFault.exe
{
	winclose
	PostMessage,0x10101,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	process,close,simpleRIS.exe
	if(partialMode)
		run,% commands(root "\AutoHotkey.exe", root "\PacsIE\simpleRIS.ahk"),% root "\PacsIE"
	else
		run % root "\scripts\Radiology\PacsIE\simpleRIS.exe"
}
ifwinexist,ahk_exe ContextServer.exe,HRESULT
	winclose

IfWinExist,Handle is NULL,buffer
	WinClose
IfWinExist,OpenProcess Failed,Unable
	WinClose
If (dh:=WinExist("Incoming Connection ahk_class MozillaDialogClass")) || (dh1:=WinExist("連入連線 ahk_class MozillaDialogClass")) {
	winactivate,ahk_id %dh%
	ControlClick,x211 y181,ahk_id %dh%
	winactivate,ahk_id %dh1%
	ControlClick,x152 y147,ahk_id %dh1%
}
ifwinexist,ahk_class #32770,查無此使用者帳號
	winclose
ifwinexist,ahk_exe rebootMsg.exe
	winclose
ControlGetText,t,Static7,Symantec Endpoint Protection ahk_class #32770
if (t="getalljpeg.exe")
	ControlClick,Button2,Symantec Endpoint Protection ahk_class #32770

ifwinexist,ahk_class #32770,hotkeys have been received in the last
	ControlClick,Button1,ahk_class #32770,hotkeys have been received in the last

if WinExist("EBMpreload.exe ahk_exe WerFault.exe"){
	for k,v in pl:=processlist()
		if (v.name="EBMpreload.exe"){
			p:=v.path
			WinClose,% "ahk_id " WinExist("EBMpreload.exe ahk_exe WerFault.exe")
			Run,% comspec " /c ""taskkill /IM " v.name " /F""",,Hide
			Sleep 1000
			run % p
			break
		}

}

if (partialMode){
	IfWinExist,開啟檔案 ahk_class #32770,% A_ScriptDir
		ControlClick,Button1,開啟檔案 ahk_class #32770,% A_ScriptDir
	IfWinExist,Symantec Endpoint Protection ahk_class #32770
	{
		ControlGetText,t,Static7,Symantec Endpoint Protection ahk_class #32770
		t:=RegExReplace(Trim(t), "i).exe$", "")
		if InStr(AllowList, "`n" t "`n")
			ControlClick,Button2,Symantec Endpoint Protection ahk_class #32770
	}
}

IfWinExist,ahk_exe UV2.exe,執行開啓檢查時發生錯誤
	WinClose
return