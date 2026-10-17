#include <EBMViewer>
SetBatchLines,-1
CoordMode,mouse,Screen
SetTitleMatchMode,2
DetectHiddenWindows,On
sendmode input
#SingleInstance,force
#Persistent
#NoTrayIcon
#InputLevel, 0
#InstallKeybdHook
#InstallMouseHook
process,Priority,,h
OnExit,OnExit

GroupAdd,EBM,ahk_class TViewerForm
GroupAdd,EBM,ahk_exe WebViewerComSrvEC.exe
GroupAdd,EBM,ahk_exe WEBVIE~1.EXE

gosub assignHotkey

return

assignHotkey:
defaultHotkey:=ImportHotkeyIni("EBMhelperHotkey_default.ini")
,userHotkey:=ImportHotkeyIni("EBMhelperHotkey.ini")
,HotkeyToTag:=[]
assignHotkey2:
Hotkey,IfWinActive,ahk_group EBM 
for k,v in userHotkey {
	i:=RegExReplace(k, "s)^(\d+)_.+", "$1")+0
	for x,y in v {
		if (y!=""){
			try
				Hotkey,% InStr(y,"$")=1?y:"$" y,EBMhotkey
			
			HotkeyToTag["" y]:=[i, RegExReplace(x, "s)^(\d+)_.+", "$1")+0, SubStr(k,4), SubStr(x,4)]
		}
	}
}
Hotkey,IfWinActive
;~ SetTimer,assignHotkey2,-3000
return

EBMHotkey:
MouseGetPos,,,win
thisHotkey:=RegExReplace(A_ThisHotkey, "^\$", "")
,tag:=HotkeyToTag["" thisHotkey]
,ebm:=new EBMViewer("", win)
;~ if(tag[1]=2 && tag[2]=2)
	;~ msgbox % a_thishotkey
if((originalHotkey:=defaultHotkey[substr("0" tag[1],-1) "_" tag[3],substr("0" tag[2],-1) "_" tag[4]])!=""){ ;replaced hotkey
	StringLower,originalHotkey,originalHotkey
	sendHK:=RegExReplace(originalHotkey, "^(\W*)(\w+)", "$1{$2}")
	send % sendHK
}else if !InStr(tag[3], "工具列"){
	ebm.SelectTool(tag[1] "." tag[2])
}else if (tag[3]="工具列1"){
	ebm.SelectTool2(tag[2])
}else if (tag[3]="工具列2"){
	ebm.PopupMenuWin(tag[2])
}else{
	;~ ToolTip % thisHotkey
	send % A_ThisHotkey
}
return

;~ esc::
OnExit:
ExitApp

