; ==============================================================================
; Library: ParseArg.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

ParseArg(IgnoreSelf=true){
	local ret
	ret:=[]
	loop %0%
	{
		if(IgnoreSelf && A_Index=1 && (%a_index%=RegExReplace(A_ScriptName,".[^.]+$", ".ahk") || %a_index%=RegExReplace(A_ScriptFullPath,".[^.]+$", ".ahk")))
			continue
		ret.push(%a_index%)
	}
	return ret
}