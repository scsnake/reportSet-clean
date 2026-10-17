; ==============================================================================
; Library: getHotkeyList.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

GetHotkeyList(scriptFile=""){
	if (scriptFile="" || !FileExist(scriptFile))
		scriptFile:=A_IsCompiled?RegExReplace(A_ScriptFullPath, "i).exe$", ".ahk"):A_ScriptFullPath
	
	ret := []
	,tmp:=[]
	
	fileread,sc,% scriptFile
	loop,parse,sc,`n,`r
		if RegExMatch(A_LoopField, "^([^;:]+)::\s*$", m)
			m1:=RegExReplace(m1, "<^>!", "LControl & RAlt")
			,m1:=RegExReplace(m1, "<([!#\+^])", "$1")
			,m1:=RegExReplace(m1, "^[\*~\$]+", "") 
			,m1:=RegExReplace(m1, "(\w+)$", "{$1}") 
			,m1:=RegExReplace(m1, "^(\W+)$", "{$1}") 
			,tmp[m1]:=0
	for k,v in tmp
		ret.push(k)
	return ret
}

GetHotstringList(scriptFile=""){
	if (scriptFile="" || !FileExist(scriptFile))
		scriptFile:=A_IsCompiled?RegExReplace(A_ScriptFullPath, "i).exe$", ".ahk"):A_ScriptFullPath
	
	ret := []
	
	fileread,sc,% scriptFile
	loop,parse,sc,`n,`r
		if RegExMatch(A_LoopField, "^:[^:]*:([^:]+)::", match)
			ret.push(match1)
	
	return ret
}