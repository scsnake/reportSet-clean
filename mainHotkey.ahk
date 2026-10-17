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
SetTitleMatchMode fast
SetBatchLines, -1
SetKeyDelay, -1, -1, -1
SetMouseDelay, -1
SetWinDelay, -1
SetControlDelay, -1
SetDefaultMouseSpeed, 0

#NoTrayIcon


gui,1:Default
gui,+hwndguihwnd
WinSetTitle,ahk_id %guihwnd%,,mainHotkey_main

thisHwnd:=WinExist("ahk_pid " thisPid:=DllCall("GetCurrentProcessId"))



return 


+`::
^`::
if getkeystate("shift") {
	send ~
	return
}
if getkeystate("ctrl"){
	send ``
	return
}
ifwinactive,ahk_class SciTEWindow
{
	send ``
	return
}
send ^+{left}{bs}
return


:?*b0:(::
if WinActive("ahk_exe firefox.exe")
	return
Input, k, L1 V T0.3 *,abcdefghijklmnopqrstuvwxyz1234567890_} ; wait until a or b or c is pressed or sent by the script
if (ErrorLevel != "Timeout")
	return 
KeyWait,shift,T1
;~ keywait,9,T1
send ){left}
return
~^9::
keywait,9,T1
send (
return
+bs::
send ^+{right}{bs}
return

~^n::
if(A_PriorHotkey=A_ThisHotkey && A_TimeSincePriorHotkey<500){
	PostMessage,0x2024,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	PostMessage,0x2024,,,,simpleRIS__main ahk_class AutoHotkeyGUI
	PostMessage,0x2028,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	
	Edithwnds:=getSimpleRisGuiHwnds(guihwnds:=getSimpleRisGuiHwnds())
	if (guihwnd:=guihwnds[2]) || (guihwnd:=guihwnds[1])
		winactivate,% "ahk_id " guihwnd
	if (editHwnd:=editHwnd[2]) || (editHwnd:=editHwnd[1])
		ControlFocus,,% "ahk_id " editHwnd
	
}
return




#Rbutton::
send {MButton}
return


#u::
PostMessage,0x8100,,,,showLungCAD_main ahk_class AutoHotkeyGUI
return
