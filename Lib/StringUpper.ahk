; ==============================================================================
; Library: StringUpper.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

StringUpper(ByRef str){
	if IsObject(str)
		str1:=str[0]
		,obj:=true
	else
		str1:=str
	StringUpper,str1,str1
	if !Obj
		str:=str1
	return str1
}