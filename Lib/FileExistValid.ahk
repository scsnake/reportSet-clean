; ==============================================================================
; Library: FileExistValid.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

FileExistValid(file){
	f:=FileExist(file)
	if (!f || InStr(f,"D"))
		return false
	FileGetSize,s,% file
	return s>0
}