; ==============================================================================
; Library: Text2Regex.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

Text2Regex(text, afterEachCharacter=""){
	ret:=""
	Loop,Parse,Text,
		if (A_LoopField~="\w")
			ret.=A_LoopField afterEachCharacter
		else if (A_LoopField="`t")
			ret.="\t" afterEachCharacter
		else if (A_LoopField="`n")
			ret.="\n" afterEachCharacter
		else if (A_LoopField="`r")
			ret.="\r" afterEachCharacter
		else
			ret.= "\" A_LoopField afterEachCharacter
	return ret
}