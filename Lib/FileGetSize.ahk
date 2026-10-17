; ==============================================================================
; Library: FileGetSize.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

FileGetSize(fileName, Unit="K"){
	FileGetSize,ret,% fileName,% unit
	return ret
}