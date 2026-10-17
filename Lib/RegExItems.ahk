; ==============================================================================
; Library: RegExItems.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

RegExItems(itemsArr, matchCount="", Delimiter="|", IgnoreCase=true){
	if itemsArr.length()=0
		return
	
	d:=Delimiter
	,ret:=IgnoreCase?"i)":""
	,ret.="^(?:[^\" d "]*"
	,matchCount:=matchCount?matchCount:itemsArr.length()
	,last:=""
	for k,v in itemsArr 
		ret.= v "\" d "?()|[^\" d "]*"
	
	Loop % matchCount
		last.="\" A_Index
	
	ret:=SubStr(ret, 1, -6-StrLen(d)) "){" matchCount "}" last "$"
	return ret
}


/*
"i)^(?:[^\|]*chest\|?()|[^\|]*abdomen\|?()|[^\|]*pelvis\|?()){3}\1\2\3$"
*/

;~ str:="CT With/Without Contrast-Abdomen|CT With/Without Contrast-Brain|CT With/Without Contrast-Chest"
;~ pattern:=RegExItems(["chest","abdomen","brain","neck"],3)
;~ MsgBox % RegExMatch(str, pattern)