; ==============================================================================
; Library: RelToAbs.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

RelToAbs(root, dir, s = "\") {
	return GetFullPath(PathCombine(root, dir))
	
	pr := SubStr(root, 1, len := InStr(root, s, "", InStr(root, s . s) + 2) - 1)
		, root := SubStr(root, len + 1)
	If InStr(root, s, "", 0) = StrLen(root)
		StringTrimRight, root, root, 1
	If InStr(dir, s, "", 0) = StrLen(dir)
		StringTrimRight, dir, dir, 1
	Loop, Parse, dir, %s%
		If InStr(A_LoopField, "..") = 1 {
			StringTrimRight, root, root, StrLen(root)-InStr(root, s, "", 0)+1 
			StringTrimLeft, dir, dir, 3
		}
		Else If InStr(A_LoopField, ".") = 1
			StringTrimLeft, dir, dir, 2
		Else If A_LoopField =
		{
			root =
			StringTrimLeft, dir, dir, 1
		}
	Return, pr . root . s . dir
}

;~ MsgBox % reltoabs(A_ScriptDir, A_ScriptDir)

;~ isAbsPath(path){
	;~ p:=FileExist(path)
	
	;~ if(!p)
		;~ return false
	
	;~ if !InStr(p, "d"){
	
		;~ Loop % path
			;~ if (A_LoopFileLongPath=path)
				;~ return true
			;~ else
				;~ return false
	;~ }else{
		;~ path:=RegExReplace(path, "[\\\/]?$", "")
		;~ Loop, % path "\*",1,1
		;~ {
			;~ SplitPath,path,,outDir
			;~ return (outDir "\test")=RelToAbs(path, ".\test")
			;~ if(outDir=path)
				;~ return true
			;~ else
				;~ return false
		;~ }
	;~ }
;~ }
;~ MsgBox % InStr("\scripts\scsnake_sync", "\", "", 0)
;~ MsgBox % reltoabs("F:\scripts\scsnake_sync\", "..\test\")
;~ MsgBox % isAbsPath("F:\scripts\testUpdate\testUpdate2\")
;~ ExitApp