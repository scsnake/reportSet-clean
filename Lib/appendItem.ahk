; ==============================================================================
; Library: appendItem.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

; if arr is array, push item
; if arr not array, set to [item]
; if key specified, insert dict
appendItem(arr, item, key=""){
	if !IsObject(arr)
		arr:=[]
	if key=
		arr.push(item)
	else
		arr[key]:=item
}
appendItemObj(obj, attr, item, key=""){
	if !IsObject(obj[attr])
		obj[attr]:=[]
	if key=
		obj[attr].push(item)
	else
		obj[attr][key]:=item
}