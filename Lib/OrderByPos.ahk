; ==============================================================================
; Library: OrderByPos.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

OrderByPos(ByRef arrOfHwnds, orderBy="x"){
	order:=[]
	for k,hwnd in arrOfHwnds {
		WinGetPos,x,y,,,% "ahk_id " hwnd
		order[%orderBy%]:=k
	}
	ret:=[]
	for x,k in order
		ret.push(arrOfHwnds[k])
	return ret
}