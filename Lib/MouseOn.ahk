; ==============================================================================
; Library: MouseOn.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

MouseOn(win="", con=""){
	if (win="" && con="")
		return false
	MouseGetPos,,,w,c,2
	if (win!=""){
		if win+0=win
			winMatch:=(win=w)
		else if RegExMatch(win, "is)ahk_(\w+) +(.+)", match){
			match2:=Trim(match2)
			if (match1="exe")
				winMatch:=(match2=WinGet("ProcessName", w))
			else if (match1="class")
				winMatch:=(match2=WinGetClass(w))
			else if (match1="id")
				winMatch:=(match2=w)
			else if (match1="pid")
				winMatch:=(match2=WinGet("PID", w))
			else
				winMatch:=!!InStr(WinGetTitle(w), match2)
		}
	}else
		winMatch:=true
	
	if(con!="")
		conMatch:=(con=c)
	else
		conMatch:=true
	
	return winMatch & conMatch
	
}