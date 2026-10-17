; ==============================================================================
; Library: FileExistWildcard.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

FileExistWildcard(pathPattern, dir="", LoopMode="FDR", returnAll=true){
	old_workingdir:=A_WorkingDir
	SetWorkingDir,% dir?dir:A_WorkingDir
	ret := []
	Loop,files,% pathPattern,% LoopMode 
	{
		if (returnAll){
			SetWorkingDir,% old_workingdir
			return A_LoopFileLongPath
		}else
			ret.push(A_LoopFileLongPath)
	}
	SetWorkingDir,% old_workingdir
	return ret
}