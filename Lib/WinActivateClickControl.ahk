; ==============================================================================
; Library: WinActivateClickControl.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

WinActivateClickControl(controlHwndOrAcc, clickPos="", clickCount=1, button="left"){
	if IsObject(controlHwndOrAcc)
		controlAcc:=controlHwndOrAcc, controlHwnd:=acc_windowFromObject(controlAcc)
	else
		controlHwnd:=controlHwndOrAcc, controlAcc:=acc_objectfromwindow(controlHwnd)
	
	win:=WinGetRoot(controlHwnd)
	WinGet,Style,Style,% "ahk_id " win
	WinGet,ExStyle,ExStyle,% "ahk_id " win
	activeWin:=WinExist("A")
	isActive:=(activeWin=win)
	WinGet, Transparent, Transparent, ahk_id %win%
	
	
	if !(RegExMatch(clickPos, "i)x(\d+) +y(\d+)", match)){
		loc:=acc_location(controlAcc)
		,clickX:=loc.x+loc.w//2
		,clickY:=loc.y+loc.h//2
	}else{
		clickX:=match1, clickY:=match2
	}
	objAtPoint:=Acc_ObjectFromPoint("", clickX, clickY)
	
	if ((coverHwnd:=acc_windowFromObject(objAtPoint)) != controlHwnd){
		winget,coverStyle,ExStyle,% "ahk_id " 
		if (ExStyle & 0x8){
			coverTopHwnd:=coverHwnd
			winset,AlwaysOnTop,Off,% "ahk_id " coverTopHwnd
		}
			
		
		winset,trans,on,% "ahk_id " win
		winset,trans,100,% "ahk_id " win
		WinShow,% "ahk_id " win	
		if !isActive {
			winactivate,% "ahk_id " win
			WinWaitActive,% "ahk_id " win,,1
			activated:=true
		}	
	}
	
	
	MouseGetPos,x,y

	mouseclick,% button,% clickX,% clickY,% clickCount,0
	
	MouseMove,% x,% y,0
	
	if activated
		winactivate,% "ahk_id " activeWin
	if(Transparent="")
		winset,trans,Off,% "ahk_id " win
	else
		winset,trans,% Transparent,% "ahk_id " win
	WinSet,Style,% Style,% "ahk_id " win
	WinSet,ExStyle,% ExStyle,% "ahk_id " win
	
	if coverTopHwnd
		winset,AlwaysOnTop,on,% "ahk_id " coverTopHwnd
	
}