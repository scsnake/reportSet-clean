; ==============================================================================
; Library: CmdRet.ahk
; Classification: Pure Third-Party
; Original Author: Corrupt, SKAN
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/board/topic/9690-cmdret-return-cmd-output/
; ==============================================================================

CmdRet(cmd){
	clipboardOld:=ClipboardAll
	,ComObjCreate("WScript.Shell").Run("cmd /c " cmd " | clip", 0, true).StdOut.ReadAll()
	,ret:=Clipboard
	,clipboard:=clipboardOld
	return ret
}

MsgBox % CmdRet("ping 127.0.0.1")