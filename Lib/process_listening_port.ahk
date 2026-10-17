; ==============================================================================
; Library: process_listening_port.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

process_listening_port(port){
	o:=StdoutToVar_CreateProcess(a_ComSpec " /c ""netstat -abno | findstr " port """")
	Loop,Parse,o,`n,`r
	{
		if InStr(o,"LISTENING") && RegExMatch(A_LoopField, "\d+$", m)
			return m
	}
}
