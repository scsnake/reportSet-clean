#MaxMem 4095
#NoEnv
#SingleInstance,force
#Persistent
#NoTrayIcon
SetBatchLines,-1
DetectHiddenWindows, On
SetTitleMatchMode,2
coordmode,mouse,screen
#InstallKeybdHook
#InstallMouseHook
#MaxHotkeysPerInterval 200
process,priority,,r
;~ #InstallKeybdHook
#include <resetHotstringBuffer>

;~ #include <JSON>
ComObjError(false)
resetHotstringBufferHook()
;~ onexit,onexit
SetTimer,exit,3000
gosub avoidHotstring
return 


exit:
if !WinExist("scsnake_autorun_main ahk_class AutoHotkeyGUI")
	ExitApp
	return

avoidHotstring:
Loop 10 {
	Hotkey,% "~*^" (A_Index-1),avoidHotstringFiring
	Hotkey,% "~*^Numpad" (A_Index-1),avoidHotstringFiring
	Hotkey,% "~*#" (A_Index-1),avoidHotstringFiring
	Hotkey,% "~*#Numpad" (A_Index-1),avoidHotstringFiring
	Hotkey,% "~*!" (A_Index-1),avoidHotstringFiring
	Hotkey,% "~*!Numpad" (A_Index-1),avoidHotstringFiring
	
	Hotkey,% "~^" (A_Index-1),avoidHotstringFiring
	Hotkey,% "~^Numpad" (A_Index-1),avoidHotstringFiring
	Hotkey,% "~#" (A_Index-1),avoidHotstringFiring
	Hotkey,% "~#Numpad" (A_Index-1),avoidHotstringFiring
	Hotkey,% "~!" (A_Index-1),avoidHotstringFiring
	Hotkey,% "~!Numpad" (A_Index-1),avoidHotstringFiring
}
Loop 26 {
	Hotkey,% "~*^" chr(A_Index+96),avoidHotstringFiring
	Hotkey,% "~^" chr(A_Index+96),avoidHotstringFiring
	Hotkey,% "~*#" chr(A_Index+96),avoidHotstringFiring
	Hotkey,% "~*!" chr(A_Index+96),avoidHotstringFiring
	
	Hotkey,% "~^" chr(A_Index+96),avoidHotstringFiring
	Hotkey,% "~^" chr(A_Index+96),avoidHotstringFiring
	Hotkey,% "~#" chr(A_Index+96),avoidHotstringFiring
	Hotkey,% "~!" chr(A_Index+96),avoidHotstringFiring
}
	
Hotkey,% "~*^tab",avoidHotstringFiring
Hotkey,% "~*#tab",avoidHotstringFiring
Hotkey,% "~*!tab",avoidHotstringFiring

Hotkey,% "~^tab",avoidHotstringFiring
Hotkey,% "~#tab",avoidHotstringFiring
Hotkey,% "~!tab",avoidHotstringFiring
return

avoidHotstringFiring:
RegExMatch(A_ThisHotkey, "\w+$", avoidHotstringFiringmatchKey)
settimerFn("avoidHotstringFiring_", -1, [avoidHotstringFiringmatchKey])
return

avoidHotstringFiring_(avoidHotstringFiringmatchKey){
	KeyWait,% avoidHotstringFiringmatchkey,T0.2
	if !ErrorLevel
		resetHotstringBuffer(-1)
	return
}