; ==============================================================================
; Library: GetFullPath.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

GetFullPath(path) {
	VarSetCapacity(fullpath, 260 * (!!A_IsUnicode + 1))
	if DllCall("GetFullPathName", "Str", path, "UInt", 260, "Ptr", &fullpath, "Ptr", 0, "UInt")
		return fullpath,VarSetCapacity(fullpath,-1)
}
