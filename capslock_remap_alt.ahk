; Autohotkey Capslock Remapping Script 
; Danik
; More info at http://danikgames.com/blog/?p=714
; danikgames.com
; 
; Functionality:
; - Deactivates capslock for normal (accidental) use.
; - Hold Capslock and drag anywhere in a window to move it (not just the title bar).
; - Access the following functions when pressing Capslock: 
;     Cursor keys           - J, K, L, I
;     Enter                 - Space
;     Home, PgDn, PgUp, End - U, O, Y, H
;     Backspace and Del     - N, M
;
;     Insert                - B
;     Select all            - A
;     Cut, copy, paste      - S, D, F
;     Close tab, window     - W, E
;     Esc                   - R
;     Next, previous tab    - Tab, Q
;     Undo, redo            - , and .
;  
; To use capslock as you normally would, you can press WinKey + Capslock


; This script is mostly assembled from modified versions of the following awesome scripts:
;
; # Home Row Computing by Gustavo Duarte: http://duartes.org/gustavo/blog/post/home-row-computing for 
; Changes: 
; - Does not need register remapping of AppsKey using SharpKeys.
; - Uses normal cursor key layout 
; - Added more hotkeys for insert, undo, redo etc.
;
; # Get the Linux Alt+Window Drag Functionality in Windows: http://www.howtogeek.com/howto/windows-vista/get-the-linux-altwindow-drag-functionality-in-windows/
; Changes: The only change was using Capslock instead of Alt. This 
; also removes problems in certain applications.


#NoTrayIcon
#SingleInstance,force
#Persistent
#InstallKeybdHook
#InstallMouseHook
process,Priority,,R
DetectHiddenWindows,On
;~ SetCapsLockState, AlwaysOff
CapsLockState:=0
settimer,setcapslockstate,200
sendlevel,2
OnMessage(0x10102,"Exit")
#include <resetHotstringBuffer>
return

exit:
ExitApp
return

; CapsLock is already the prefix for every remap chord in this script, so this
; standalone hotkey fires on release only when no CapsLock & key chord was used.
; Keep the physical-key decision here and notify the two feature owners.
CapsLock::
PostMessage,0x2033,,,,ahk_exe Autorun.exe
PostMessage,0x2028,,,,simple RIS ahk_class AutoHotkeyGUI
resetHotstringBuffer(-1)
return

; Capslock + jkli (left, down, up, right)
Capslock & j::
Send {Blind}{Left DownTemp}
;~ __clickUp()
return
Capslock & j up::
Send {Blind}{Left Up}{esc}
__clickUp()
return

Capslock & k::
Send {Blind}{Down DownTemp}
;~ __clickUp()
return
Capslock & k up::
Send {Blind}{Down Up}{esc}
__clickUp()
return

Capslock & i::
Send {Blind}{Up DownTemp}
;~ __clickUp()
return
Capslock & i up::
Send {Blind}{Up Up}{esc}
__clickUp()
return

Capslock & l::
Send {Blind}{Right DownTemp}
;~ __clickUp()
return
Capslock & l up::
Send {Blind}{Right Up}{esc}
__clickUp()
return


; Capslock + uohy (pgdown, pgup, home, end)

Capslock & u::
SendInput {Blind}{Home Down}
;~ __clickUp()
return
Capslock & u up::
SendInput {Blind}{Home Up}{esc}
__clickUp()
return

Capslock & o::
SendInput {Blind}{End Down}
;~ __clickUp()
return
Capslock & o up::
SendInput {Blind}{End Up}{esc}
__clickUp()
return

Capslock & y::
SendInput {Blind}{PgUp Down}
;~ __clickUp()
return
Capslock & y up::
SendInput {Blind}{PgUp Up}{esc}
__clickUp()
return

Capslock & h::
SendInput {Blind}{PgDn Down}
;~ __clickUp()
return
Capslock & h up::
SendInput {Blind}{PgDn Up}{esc}
__clickUp()
return


; Capslock + asdf (select all, cut-copy-paste)

Capslock & a::
SendInput {Ctrl Down}{a Down}
;~ __clickUp()
return
Capslock & a up::
SendInput {Ctrl Up}{a Up}{esc}
__clickUp()
return

Capslock & s::
SendInput {Ctrl Down}{x Down}
;~ __clickUp()
return
Capslock & s up::
SendInput {Ctrl Up}{x Up}{esc}
__clickUp()
return

Capslock & d::
SendInput {Ctrl Down}{c Down}
;~ __clickUp()
return
Capslock & d up::
SendInput {Ctrl Up}{c Up}{esc}
__clickUp()
return

Capslock & f::
SendInput {Ctrl Down}{v Down}
;~ __clickUp()
return
Capslock & f up::
SendInput {Ctrl Up}{v Up}{esc}
__clickUp()
return


; Capslock + wer (close tab or window, press esc)

Capslock & w::
SendInput {Ctrl down}{F4}{Ctrl up}
__clickUp()
return
Capslock & e::
SendInput {Alt down}{F4}{Alt up}
__clickUp()
return
Capslock & r::
SendInput {Blind}{Esc Down}
__clickUp()
return


; Capslock + nm (insert, backspace, del)

Capslock & b::
SendInput {Blind}{Insert Down}
__clickUp()
return
Capslock & m::
SendInput {Blind}{Del Down}{esc}
__clickUp()
return
Capslock & n::
SendInput {Blind}{BS Down}{esc}
__clickUp()
return
Capslock & BS::
SendInput {Blind}{BS Down}
__clickUp()
return


; Make Capslock & Enter equivalent to Control+Enter
Capslock & Enter::
SendInput {Ctrl down}{Enter}{Ctrl up}
__clickUp()
return


; Make Capslock & Alt Equivalent to Control+Alt
!Capslock::
SendInput {Ctrl down}{Alt Down}
;~ __clickUp()
return
!Capslock up::
SendInput {Ctrl up}{Alt up}
__clickUp()
return


; Capslock + TAB/q (prev/next tab)

Capslock & q::
SendInput {Ctrl Down}{Tab Down}
;~ __clickUp()
return
Capslock & q up::
SendInput {Ctrl Up}{Tab Up}{esc}
__clickUp()
return
Capslock & Tab::
SendInput {Ctrl Down}{Shift Down}{Tab Down}
;~ __clickUp()
return
Capslock & Tab up::
SendInput {Ctrl Up}{Shift Up}{Tab Up}
__clickUp()
return

; Capslock + ,/. (undo/redo)

Capslock & ,::
SendInput {Ctrl Down}{z Down}
;~ __clickUp()
return
Capslock & , up::
SendInput {Ctrl Up}{z Up}
__clickUp()
return
Capslock & .::
SendInput {Ctrl Down}{y Down}
;~ __clickUp()
return
Capslock & . up::
SendInput {Ctrl Up}{y Up}
__clickUp()
return


; Make Capslock+Space -> Enter
Capslock & Space::
SendInput {Enter Down}
__clickUp()
return

setcapslockstate:
SetCapslockstate,% capslockstate?"on":"off"
return

; Make Win Key + Capslock work like Capslock
#Capslock::

capslockstate:=!capslockstate
gosub setcapslockstate
;~ If GetKeyState("CapsLock", "T") = 1
    ;~ SetCapsLockState, AlwaysOff
;~ Else 
    ;~ SetCapsLockState, AlwaysOn
Return


__clickUp(){
    resetHotstringBuffer(-1R)
    ;~ Click up 2
}


; Drag windows anywhere
;
; This script modified from the original: http://www.autohotkey.com/docs/scripts/EasyWindowDrag.htm
; by The How-To Geek
; http://www.howtogeek.com 


Capslock & LButton::

CoordMode, Mouse  ; Switch to screen/absolute coordinates.
MouseGetPos, EWD_MouseStartX, EWD_MouseStartY, EWD_MouseWin
WinGetPos, EWD_OriginalPosX, EWD_OriginalPosY,,, ahk_id %EWD_MouseWin%
WinGet, EWD_WinState, MinMax, ahk_id %EWD_MouseWin% 
if EWD_WinState = 0  ; Only if the window isn't maximized 
    SetTimer, EWD_WatchMouse, 10 ; Track the mouse as the user drags it.
return

EWD_WatchMouse:
GetKeyState, EWD_LButtonState, LButton, P
if EWD_LButtonState = U  ; Button has been released, so drag is complete.
{
    SetTimer, EWD_WatchMouse, off
    return
}
GetKeyState, EWD_EscapeState, Escape, P
if EWD_EscapeState = D  ; Escape has been pressed, so drag is cancelled.
{
    SetTimer, EWD_WatchMouse, off
    WinMove, ahk_id %EWD_MouseWin%,, %EWD_OriginalPosX%, %EWD_OriginalPosY%
    return
}
; Otherwise, reposition the window to match the change in mouse coordinates
; caused by the user having dragged the mouse:
CoordMode, Mouse
MouseGetPos, EWD_MouseX, EWD_MouseY
WinGetPos, EWD_WinX, EWD_WinY,,, ahk_id %EWD_MouseWin%
SetWinDelay, -1   ; Makes the below move faster/smoother.
WinMove, ahk_id %EWD_MouseWin%,,% EWD_WinX + EWD_MouseX - EWD_MouseStartX,% EWD_WinY + EWD_MouseY - EWD_MouseStartY
EWD_MouseStartX := EWD_MouseX  ; Update for the next timer-call to this subroutine.
EWD_MouseStartY := EWD_MouseY
return
