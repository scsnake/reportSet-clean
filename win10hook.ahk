#persistent
#notrayicon
#SingleInstance,Force
DetectHiddenWindows,on
SetTitleMatchMode,2
#InstallKeybdHook
setbatchlines,-1
SetTimer,exit,3000
SendLevel,10


GroupAdd,dependent,YCH_MAMMO_AHK_main ahk_class AutoHotkeyGUI
GroupAdd,dependent,YCH_AHK_main ahk_class AutoHotkeyGUI

return

#IfWinExist,YCH_AHK_main ahk_class AutoHotkeyGUI
#c::
PostMessage,0x10102,,,,YCH_AHK_main ahk_class AutoHotkeyGUI
return
#z::
PostMessage,0x10103,,,,YCH_AHK_main ahk_class AutoHotkeyGUI
return
#IfWinExist

#IfWinExist,Enter command ahk_class AutoHotkeyGUI
#space::
PostMessage,0x10104,,,,Enter command ahk_class AutoHotkeyGUI
return
#IfWinExist


#IfWinExist,YCH_MAMMO_AHK_main ahk_class AutoHotkeyGUI
+#a::
#a::
PostMessage,0x10102,% !!InStr(A_ThisHotkey,"+"),,,YCH_MAMMO_AHK_main ahk_class AutoHotkeyGUI
return

#v::
PostMessage,0x10103,,,,YCH_MAMMO_AHK_main ahk_class AutoHotkeyGUI
return
#IfWinExist


#IfWinExist,__maskImpaxLoading ahk_class AutoHotkeyGUI


$+#left::
$+#right::
$+#m::
Modifier:=RegExReplace(A_ThisHotkey, "\w", "")
,key:=RegExReplace(A_ThisHotkey, "\W", "")
ifwinactive,ahk_exe impax-client-main.exe
	PostMessage,0x10104,% key="left"?1:key="right"?2:0,,,YCH_MAMMO_AHK_main ahk_class AutoHotkeyGUI
else
	send % Modifier "{" key "}"
return
#IfWinExist


exit:
if !WinExist("ahk_group dependent")
	ExitApp
return

