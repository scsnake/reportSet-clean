#NoEnv
#SingleInstance,force
SetWorkingDir,%A_ScriptDir%
DetectHiddenWindows,on
SetTitleMatchMode,2

logFile := A_ScriptDir "\test_simpleRIS_activate.log"
FileDelete,%logFile%

log(line){
    global logFile
    FileAppend,%line%`n,%logFile%
}

log("=== simpleRIS activation test " A_Now " ===")
log("")

; Step 1: simpleRIS_main
log("[Step 1] simpleRIS_main (background gui2)")
mainHwnd := WinExist("simpleRIS_main ahk_class AutoHotkeyGUI")
if mainHwnd {
    WinGet,mainPid,PID,ahk_id %mainHwnd%
    log("  FOUND  hwnd=" mainHwnd "  pid=" mainPid)
} else {
    log("  NOT FOUND - simpleRIS not running or title changed")
    mainPid := 0
}
log("")

; Step 2: gui[1] = "simple RIS" in same process
log("[Step 2] gui[1]: 'simple RIS' in mainPid")
gui1 := 0
editHwnd1 := 0
if mainPid {
    gui1 := WinExist("simple RIS ahk_class AutoHotkeyGUI ahk_pid " mainPid)
    if gui1 {
        WinGetTitle,g1title,ahk_id %gui1%
        WinGet,g1mm,MinMax,ahk_id %gui1%
        WinGet,g1ex,ExStyle,ahk_id %gui1%
        WinGet,g1trans,Transparent,ahk_id %gui1%
        g1topmost := (g1ex & 0x8) ? "YES" : "no"
        if (g1trans = "")
            g1transStr := "OFF(not set)"
        else
            g1transStr := g1trans
        ControlGet,editHwnd1,hwnd,,Scintilla1,ahk_id %gui1%
        if !editHwnd1
            ControlGet,editHwnd1,hwnd,,Edit1,ahk_id %gui1%
        log("  FOUND  hwnd=" gui1 "  title='" g1title "'")
        log("  minmax=" g1mm "  topmost=" g1topmost "  trans=" g1transStr)
        log("  editHwnd=" editHwnd1)
        if (g1trans+0 = 0 && g1trans != "")
            log("  *** WARNING: trans=0 = window is FULLY INVISIBLE ***")
    } else {
        log("  NOT FOUND  (pid=" mainPid ")")
    }
} else {
    log("  skipped (no mainPid)")
}
log("")

; Step 3: gui[2] via simpleRIS__main
log("[Step 3] gui[2]: via simpleRIS__main (secondary process)")
gui2 := 0
editHwnd2 := 0
pid2win := WinExist("simpleRIS__main ahk_class AutoHotkeyGUI")
if pid2win {
    WinGet,pid2val,PID,ahk_id %pid2win%
    simpleMode := !!WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
    SetTitleMatchMode,1
    if simpleMode
        gui2 := WinExist("simple RIS3 ahk_pid " pid2val)
    else
        gui2 := WinExist("simple RIS ahk_pid " pid2val)
    SetTitleMatchMode,2
    if gui2 {
        WinGetTitle,g2title,ahk_id %gui2%
        WinGet,g2trans,Transparent,ahk_id %gui2%
        if (g2trans = "")
            g2transStr := "OFF(not set)"
        else
            g2transStr := g2trans
        ControlGet,editHwnd2,hwnd,,Scintilla1,ahk_id %gui2%
        if !editHwnd2
            ControlGet,editHwnd2,hwnd,,Edit1,ahk_id %gui2%
        log("  FOUND  hwnd=" gui2 "  title='" g2title "'  trans=" g2transStr)
        log("  simpleMode=" simpleMode "  editHwnd=" editHwnd2)
    } else {
        log("  simpleRIS__main pid=" pid2val " but no gui window found")
    }
} else {
    log("  simpleRIS__main NOT running -> gui[2] falls back to gui[1]")
    gui2 := gui1
    editHwnd2 := editHwnd1
}
log("")

; Step 4: Codex target
log("[Step 4] Codex activateSimpleRis target")
simpleEditExists := !!WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
if simpleEditExists {
    targetGui  := gui2
    targetEdit := editHwnd2
    log("  mode: simpleRISsimpleEdit EXISTS -> uses gui[2]")
} else {
    targetGui  := gui1
    targetEdit := editHwnd1
    log("  mode: no simpleRISsimpleEdit -> Codex uses gui[1]  (OLD code used [2])")
}
log("  targetGui=" targetGui "  targetEdit=" targetEdit)
sameWin := (gui1 = gui2) ? "YES (single-edit)" : "NO (secondary process)"
log("  gui1=gui2? " sameWin)
if !targetGui
    log("  *** ABORT: targetGui=0, activateSimpleRis would silently return! ***")
log("")

; Step 5: PostMessage 0x2028
log("[Step 5] Sending PostMessage 0x2028 to simpleRIS_main")
if mainHwnd {
    PostMessage,0x2028,0,0,,simpleRIS_main ahk_class AutoHotkeyGUI
    log("  sent")
    Sleep,500
    WinGetTitle,activeTitle,A
    WinGet,activeProc,ProcessName,A
    ControlGetFocus,focCtrl,A
    log("  active window: '" activeTitle "' [" activeProc "]")
    log("  focused ctrl : " focCtrl)
    if targetGui {
        isAct := WinActive("ahk_id " targetGui) ? "YES" : "NO"
        WinGet,tgTrans,Transparent,ahk_id %targetGui%
        if (tgTrans = "")
            tgTransStr := "OFF(not set)"
        else
            tgTransStr := tgTrans
        log("  targetGui active=" isAct "  trans=" tgTransStr)
    }
} else {
    log("  skipped (no mainHwnd)")
}
log("")

; Step 6: force WinShow + WinActivate + ControlFocus
log("[Step 6] Direct force-activate on targetGui")
if targetGui {
    WinShow,ahk_id %targetGui%
    WinActivate,ahk_id %targetGui%
    Sleep,300
    if targetEdit
        ControlFocus,,ahk_id %targetEdit%
    Sleep,150
    WinGetTitle,activeTitle2,A
    isAct2 := WinActive("ahk_id " targetGui) ? "YES" : "NO"
    ControlGetFocus,focCtrl2,A
    WinGet,tgTrans2,Transparent,ahk_id %targetGui%
    if (tgTrans2 = "")
        tgTrans2Str := "OFF(not set)"
    else
        tgTrans2Str := tgTrans2
    log("  active window  : '" activeTitle2 "'")
    log("  targetGui active=" isAct2 "  trans=" tgTrans2Str)
    log("  focused ctrl   : " focCtrl2)
} else {
    log("  skipped (targetGui=0)")
}
log("")
log("=== done ===")

MsgBox,64,Test done,Log written to:`n%logFile%,5
ExitApp
