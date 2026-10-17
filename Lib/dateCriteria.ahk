; ==============================================================================
; Library: dateCriteria.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

#include <Monster>
dateCriteria(value, criteria){
	value:=RegExReplace(value, "\D", "")
	,criteria:=RegExMatch(Trim(criteria), "s)^(\D+)(.+)", match)
	,operant:=Trim(match1)
	,compareValue:=RegExReplace(match2, "\D", "")
	if (l1:=StrLen(value))>(l2:=StrLen(criteria))
		value:=SubStr(value,1,l2)
	else if(l1<l2)
		criteria:=SubStr(criteria,1,l1)
	return !!Eval(value operant compareValue) 
}