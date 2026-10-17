; ==============================================================================
; Library: GuiPos.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

/*

*/
GuiPos(guiHwnd, x_pos, y_pos){
		monitors:=monitorInfo()
	WinGetPos,,,gw,gh,% "ahk_id " guihwnd
	
	if RegExMatch(x_pos, "^(\d+)?([rlc])", match){
		if (match1="")
			match1:="1"
		if (match2="r")
			x_pos:="x" monitors[match1].r-gw
		else if(match2="l")
			x_pos:="x" monitors[match1].l
		else
			x_pos:="x" monitors[match1].l + monitors[match1].w//2-gw//2
	}else
		x_pos:="x" monitors[1].l + monitors[1].w//2-gw//2
	
	if RegExMatch(y_pos, "^(\d+)?([tbc])", match){
		if (match1="")
			match1:="1"
		if (match2="b")
			y_pos:="y" monitors[match1].b-gh
		else if(match2="t")
			y_pos:="y" monitors[match1].t
		else
			y_pos:="y" monitors[match1].t + monitors[match1].h//2-gh//2
	}else
		y_pos:="y" monitors[1].t + monitors[1].b//2-gh//2
	
	return x_pos " " y_pos " "
	
}
