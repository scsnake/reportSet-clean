#NoEnv
#Persistent
#SingleInstance, Force
SetTitleMatchMode, 2
DetectHiddenWindows, Off

; Include the library for IsCurrentSessionRDP
#Include %A_ScriptDir%\..\Lib\IsCurrentSessionRDP.ahk
#Include %A_ScriptDir%\..\Lib\INFINITT_PACS.ahk

; The screen dimensions will be calculated dynamically inside the timer
; to account for RDP resolution changes.

; Set a timer to check every 1 second
SetTimer, CheckAndMovePacs, 1000
return

CheckAndMovePacs:
    ; Only perform the move if currently in an RDP session
    if (!IsCurrentSessionRDP())
        return

    ; Update virtual screen dimensions dynamically in case RDP resolution changes
    SysGet, VirtualWidth, 78
    SysGet, VirtualLeft, 76
    RightEdge := VirtualLeft + VirtualWidth

    ; Window/class discovery is centralized in Lib\INFINITT_PACS.ahk.
    hwnd := FindInfinittViewerHwnd("first", true)
    if (hwnd)
    {
        WinGetPos, X, Y, Width, Height, ahk_id %hwnd%

        NewX := RightEdge - Width
        ; Allow for the one-pixel invisible DWM resize border.
        if (Abs((X + Width) - RightEdge) > 2)
        {
            WinMove, ahk_id %hwnd%, , %NewX%, %Y%
        }
    }
return
