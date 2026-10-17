#Requires AutoHotkey v2.0
Persistent()

; Global state variables
global isLocked := false
global lockedHwnd := 0

; Alt + Up to toggle focus lock
!Up:: {
    global isLocked, lockedHwnd

    if (!isLocked) {
        ; Get the current active window
        activeHwnd := WinExist("A")
        if (activeHwnd) {
            isLocked := true
            lockedHwnd := activeHwnd

            ; Set as AlwaysOnTop and start checking focus
            WinSetAlwaysOnTop(1, "ahk_id " activeHwnd)
            SetTimer(CheckFocus, 100)

            ShowHint("Focus LOCKED to:`n" WinGetTitle("ahk_id " activeHwnd))
        }
    } else {
        ; Unlock everything
        isLocked := false
        if (lockedHwnd && WinExist("ahk_id " lockedHwnd)) {
            WinSetAlwaysOnTop(0, "ahk_id " lockedHwnd)
        }
        SetTimer(CheckFocus, 0) ; Stop checking focus
        lockedHwnd := 0

        ShowHint("Focus UNLOCKED")
    }
}

; Function to force focus back to the locked window
CheckFocus() {
    global isLocked, lockedHwnd
    if (isLocked && lockedHwnd && WinExist("ahk_id " lockedHwnd)) {
        if (!WinActive("ahk_id " lockedHwnd)) {
            WinActivate("ahk_id " lockedHwnd)
        }
    } else if (isLocked) {
        ; If the window was closed while locked, unlock automatically
        isLocked := false
        SetTimer(CheckFocus, 0)
        ShowHint("Target window closed. Focus Unlocked.")
    }
}

; Show a temporary ToolTip hint
ShowHint(text) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -2000) ; Remove ToolTip after 2 seconds
}
