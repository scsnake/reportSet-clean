;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                      ;;
;; KDE-Style Alt-Grab Window Move Convenience Script    ;;
;;                                                      ;;
;; version 0.1 - 07/24/04                               ;;
;; ck <use www.autohotkey.com forum to contact me>      ;;
;;                                                      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Usage Instructions:
;; -------------------
;; Load Script into AutoHotKey (only verified to work properly with 1.0.16 and Windows XP)
;; - Hold down the Alt key and lef-click anywhere in a window to move the window
#NoTrayIcon
#SingleInstance,force

LAlt & LButton::
; If this command isn't used, all commands except those documented otherwise (e.g. WinMove and InputBox) 
; use coordinates that are relative to the active window
CoordMode, Mouse, Screen

; speed things up
SetWinDelay, 0

; get current mouse position
MouseGetPos, OLDmouseX, OLDmouseY, WindowID

; get the postition and ID of the window under the mouse cursor
WinGetPos, winX, winY, winW, winH ,ahk_id %WindowID%

; Turn off Window Animation
;RegRead, BoolMinAni, HKEY_CURRENT_USER,Control Panel\Desktop\WindowMetrics, MinAnimate
;if BoolMinAni = 1
;{
;	; this has no effect until it's reloaded / re-logon... (-> disabled code)
;	RegWrite, REG_SZ, HKEY_CURRENT_USER, Control Panel\Desktop\WindowMetrics, MinAnimate, 0
;}

; this restore (= undo max or min) call tells the OS that originally 
; maximized windows are now restored/normal and can be moved even after this script takes off
; this is absolutely mandatory for windows which remember their last location like IE windows
; otherwise you cannot properly maximize them anymore

;WinHide, ahk_id %WindowID%
WinRestore, ahk_id %WindowID%
WinMove, ahk_id %WindowID%,,%winX%,%winY%,%winW%,%winH%
;WinShow, ahk_id %WindowID%

Loop
{
	; is the User still keeping that Alt key down?
	GetKeyState, AltKeyState, Alt, P
	if AltKeyState = U ; key has been released
	{
		break
	}
		
	; get new mouse position
	MouseGetPos, newMouseX, newMouseY

	; get relative mouse X movement
	if newMouseX < %OLDmouseX% 
	{
		; mouse was moved to the left
		Xdistance = %OLDmouseX%
		EnvSub, Xdistance, %newMouseX%	
		EnvSub, winX, %Xdistance%
	}
	else if newMouseX > %OLDmouseX% 
	{
		; mouse was moved to the right
		Xdistance = %newMouseX%
		EnvSub, Xdistance, %OLDmouseX%	
		EnvAdd, winX, %Xdistance%
	}
	else 
	{
		; mouse X coordinate wasn't changed
	}
	
	; set OLDmouseX
	OLDmouseX = %newMouseX%

	; repeat the same stuff for the Y-axis
	if newMouseY < %OLDmouseY% 
	{
		Ydistance = %OLDmouseY%
		EnvSub, Ydistance, %newMouseY%	
		EnvSub, winY, %Ydistance%
	}
	else if newMouseY > %OLDmouseY% 
	{
		Ydistance = %newMouseY%
		EnvSub, Ydistance, %OLDmouseY%	
		EnvAdd, winY, %Ydistance%
	}
	else 
	{
	}
	OLDmouseY = %newMouseY%

	; move Window accordingly
	WinMove, ahk_id %WindowID%,,%winX%,%winY%
}
return