; ==============================================================================
; Library: checkUpdate_utils.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

checkUpdate_splitVersion(version){
	ret:=[]
	Loop,Parse,version,.
		ret.push(A_LoopField)
	return ret
}

sort_version(ver){
	ret:=[], s:=""
	for k,v in ver 
		s.=k "`n"
	
	sort,s,F checkUpdate_compareVersion
	
	;~ MsgBox % s
	Loop,Parse,s,`n
		if Trim(A_LoopField)!=""
			ret.push(Trim(A_LoopField))
	return ret
}
;~ MsgBox % checkUpdate_compareVersion("2", "1")

;; return 1 if v1>v2
checkUpdate_compareVersion(v1, v2){

	if !IsObject(v1)
		v1:=checkUpdate_splitVersion(v1)
	if !IsObject(v2)
		v2:=checkUpdate_splitVersion(v2)
	
	for k,v in v1
		if (v2[k]="" || v>v2[k])
			return 1
		else if (v<v2[k])
			return -1
	
	if (v2[k+1]!="")
		return -1
	else 
		return 0
}