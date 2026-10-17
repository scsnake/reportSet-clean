; ==============================================================================
; Library: fileLog.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

filelog(txt, filepath=""){
	static _filepath
	
	if(filepath=""){
		filepath:=_filepath
	}else{
		_filepath:=filepath
	}
	if(_filepath="")
		_filepath:=A_ScriptDir "\fileLog.txt"
	
	FileAppend,% a_now "," A_TickCount ":" A_ScriptName ":" txt "`n",% _filepath,utf-8-Raw
}