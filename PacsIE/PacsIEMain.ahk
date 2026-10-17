#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
SetBatchLines, -1
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
SetTitleMatchMode,2
SetControlDelay,-1
DetectHiddenWindows,on
ComObjError(false)
#notrayicon
onexit,onexit
#persistent

SetTimer,changeLibRoot,-1
OnMessage(0x200,"WM_MOUSEMOVE")
gui,-resize +lastfound 
gui,font,s14,Verdana
gui,add,button,gopenPacsIE vopenPacsIE w400,% "      Open PacsIE      "
gui,add,button,gclosePacsIE w400,% "      Close PacsIE      "
gui,add,button,gopenPacsIEoffline vopenPacsIEoffline w400,% "     Open PacsIE`n(offline mode)     "
gui,show,autosize,PacsIE Main
wingetpos,x,y,w,h
winmove,,,% a_screenwidth-w,0,w,h

groupadd,PacsIE,ahk_exe PacsIE.exe

iniread,loginId,% ini,Settings,portal帳號
iniread,loginPw,% ini,Settings,portal密碼
if (loginId="" || loginPw=""){
	msgbox % "請先設定portal帳號密碼"
	run % ini
}else{
	;~ sleep 1000
	;~ gosub openPacsIE
}
return

WM_MOUSEMOVE( wparam, lparam, msg, hwnd ){
	if (wparam = 1){ ; LButton
		PostMessage, 0xA1, 2,,, A ;WM_NCLBUTTONDOWN
	}
}
;~ #ifExist,PacsIE Main
~shift::
guicontrol,,openPacsIE,Open PacsIE (no GDI+)
guicontrol,,openPacsIEoffline,Open PacsIE`n(offline and no GDI+ mode)
return

~shift up::
guicontrol,,openPacsIE,Open PacsIE
guicontrol,,openPacsIEoffline,Open PacsIE`n(offline mode)
return

~Ctrl::
guicontrol,,openPacsIE,Open PacsIE (fast mode)
guicontrol,,openPacsIEoffline,Open PacsIE`n(offline and fast mode)
return

~ctrl up::
guicontrol,,openPacsIE,Open PacsIE
guicontrol,,openPacsIEoffline,Open PacsIE`n(offline mode)
return
;~ #ifwinactive 

lockButton:
gdi:=getkeystate("shift")?" -noGDI":""
fast:=getkeystate("ctrl")?" -fast":""
guicontrol,disable,openPacsIE
guicontrol,disable,openPacsIEoffline
SetTimer,reactivateButton,-500
return

reactivateButton:
winwait,ahk_exe PacsIE.exe,,10
guicontrol,enable,openPacsIE
guicontrol,enable,openPacsIEoffline
return

openPacsIE:
gosub lockButton
if !winexist("ahk_exe PacsIE.exe")
	;~ run,% "PacsIE.exe"  gdi fast, % A_ScriptDir
	run,% "PacsIE.exe" (fileexist("PacsIE.ahk")?" PacsIE.ahk":"") gdi fast, % A_ScriptDir
else {
	SendMessage,0x10202,,,,ahk_exe PacsIE.exe
	if(errorlevel){
		gosub closePacsIE
		goto openPacsIE
	}
}
return

openPacsIEOffline:
gosub lockButton

if !winexist("ahk_exe PacsIE.exe")
	;~ run % "PacsIE.exe"  (" -offline") gdi fast, % A_ScriptDir
	run % "PacsIE.exe" (fileexist("PacsIE.ahk")?" PacsIE.ahk":"") (" -offline") gdi fast, % A_ScriptDir
else {
	SendMessage,0x10202,,,,ahk_exe PacsIE.exe
	if(errorlevel){
		gosub closePacsIE
		goto openPacsIEoffline
	}
}
return

~!#q:
gosub closePacsIE
return


closePacsIE:
sendmessage,0x10101,,,,ahk_exe PacsIE.exe
winclose,ahk_exe PacsIE.exe
Sleep 1000
process,close,PacsIE.exe
return

guiclose:
onexit:
gosub closePacsIE
exitapp


changeLibRoot:
if !FileExist(libLnk:=A_ScriptDir "\Lib.lnk")
	return
FileGetShortcut,% libLnk,libTarget
if SubStr(libTarget,1,1)!=SubStr(A_ScriptDir,1,1){
	FileDelete,% libLnk
	FileCreateShortcut,% SubStr(A_ScriptDir,1,1) SubStr(libTarget,2),% libLnk
}
return