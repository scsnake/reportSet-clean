; INFINITT_DragTest.ahk  — standalone drag-method comparison harness (AHK v1)
;
; Purpose: this machine has a mixed-DPI, negative-origin multi-monitor layout
;   - DISPLAY5 primary 1920x1080 @100% at (0,0)
;   - DISPLAY1/2 portrait 1536x2048 @125% at Y=-627 (logical 1229x1638)
; The INFINITT viewport lives on a 125% portrait monitor. AHK's absolute-coordinate
; MouseClickDrag mismaps there (oblique + short + jitter). This harness runs several
; drag implementations so we can SEE which one stays vertical and full-length.
;
; HOW TO USE
;   1. Run this script.
;   2. Move the mouse over the target (the INFINITT viewport on the portrait monitor).
;   3. Keep the mouse still and press a method hotkey. Watch the cursor; read the tooltip.
;      A good method: dx ~ 0 (vertical) and dy ~ planned length (full distance).
;   4. F9 dumps monitor/DPI info under the cursor. Esc quits.
;
; Each method drags DOWN by DRAG_LEN logical px from the current cursor position,
; then reports planned-vs-actual delta. Results append to a daily drag_test log.

#NoEnv
#SingleInstance Force
#Persistent
#Include %A_LineFile%\..\..\LogRetention.ahk
SetBatchLines, -1
CoordMode, Mouse, Screen
SetWinDelay, -1
SetMouseDelay, 10

global DRAG_LEN        := 300   ; logical px, downward — big enough to see obliqueness
global DRAG_STEPS      := 30    ; intermediate move steps (incremental drags)
global DRAG_STEP_SLEEP := 8     ; ms between steps
FormatTime, dragTestDate,, yyyyMMdd
global LOGFILE         := A_ScriptDir "\drag_test_" dragTestDate ".log"
LogRetention_DeleteFilesOlderThan(A_ScriptDir, "drag_test_*.log")
LogRetention_DeleteFilesOlderThan(A_ScriptDir, "drag_test_log.txt")

; mouse_event flags
global MEF_MOVE := 0x0001, MEF_LDOWN := 0x0002, MEF_LUP := 0x0004
global MEF_ABS := 0x8000, MEF_VDESK := 0x4000

ToolTip, % "DRAG TEST READY  (DRAG_LEN=" DRAG_LEN " px down)`n"
    . "Hover the INFINITT viewport, hold still, press a key:`n`n"
    . "F1 = MouseClickDrag Event (current prod behavior)`n"
    . "F2 = MouseClickDrag SendMode Input`n"
    . "F3 = Manual incremental MouseMove (AHK logical) + button`n"
    . "F4 = SetCursorPos drag, logical coords`n"
    . "F5 = SetCursorPos drag, PHYSICAL + per-thread PMv2 DPI  <-- candidate fix`n"
    . "F6 = mouse_event ABSOLUTE (VirtualDesk normalized)`n"
    . "F7 = Plain MouseMove, NO button (is oblique button-independent?)`n`n"
    . "F9 = dump monitor/DPI info    Esc = quit`n"
    . "Log: " LOGFILE
return

F1::RunMethod(1, "M1 MouseClickDrag Event (current)")
F2::RunMethod(2, "M2 MouseClickDrag SendMode Input")
F3::RunMethod(3, "M3 Manual MouseMove incremental (logical)")
F4::RunMethod(4, "M4 SetCursorPos drag (logical)")
F5::RunMethod(5, "M5 SetCursorPos PHYSICAL + PMv2")
F6::RunMethod(6, "M6 mouse_event ABSOLUTE VirtualDesk")
F7::RunMethod(7, "M7 Plain MouseMove (no button)")
F9::DumpInfo()
Esc::ExitApp

; ── measurement wrapper ───────────────────────────────────────────────
RunMethod(idx, name) {
    global LOGFILE, DRAG_LEN
    MouseGetPos, sx, sy
    fn := "DragMethod" idx
    %fn%(sx, sy)
    Sleep, 40
    MouseGetPos, ex, ey
    dx := ex - sx, dy := ey - sy
    verdict := ((Abs(dx) <= 2) ? "VERTICAL" : "OBLIQUE(dx=" dx ")")
        . " / " ((dy >= DRAG_LEN * 0.9) ? "FULL" : (dy <= DRAG_LEN * 0.5 ? "SHORT" : "PARTIAL"))
    line := A_Now " | " name " | start=" sx "," sy " | planned dx=0 dy=" DRAG_LEN
        . " | end=" ex "," ey " | actual dx=" dx " dy=" dy " | " verdict
    FileAppend, %line%`n, %LOGFILE%
    ToolTip, % name "`n`nplanned:  dx=0   dy=" DRAG_LEN
        . "`nactual:   dx=" dx "  dy=" dy
        . "`n=> " verdict
        . "`n`n(dx!=0 => oblique;  dy<planned => short)"
}

; ── drag implementations ──────────────────────────────────────────────

; M1: current production behavior — AHK absolute MouseClickDrag, Event mode.
DragMethod1(sx, sy) {
    global DRAG_LEN
    ex := sx, ey := sy + DRAG_LEN
    SendMode, Event
    MouseClickDrag, L, %sx%, %sy%, %ex%, %ey%, 2
}

; M2: same but SendMode Input (the swap that did nothing — kept for direct comparison).
DragMethod2(sx, sy) {
    global DRAG_LEN
    ex := sx, ey := sy + DRAG_LEN
    SendMode, Input
    MouseClickDrag, L, %sx%, %sy%, %ex%, %ey%, 2
    SendMode, Event
}

; M3: manual incremental drag — AHK MouseMove (logical) with raw button down/up.
DragMethod3(sx, sy) {
    global DRAG_LEN, DRAG_STEPS, DRAG_STEP_SLEEP, MEF_LDOWN, MEF_LUP
    MouseMove, %sx%, %sy%, 0
    Sleep, 10
    DllCall("mouse_event", "uint", MEF_LDOWN, "int", 0, "int", 0, "uint", 0, "uptr", 0)
    Loop, %DRAG_STEPS% {
        cy := Round(sy + DRAG_LEN * A_Index / DRAG_STEPS)
        MouseMove, %sx%, %cy%, 0
        Sleep, %DRAG_STEP_SLEEP%
    }
    DllCall("mouse_event", "uint", MEF_LUP, "int", 0, "int", 0, "uint", 0, "uptr", 0)
}

; M4: manual incremental drag via SetCursorPos in logical coords (no DPI context change).
DragMethod4(sx, sy) {
    global DRAG_LEN, DRAG_STEPS, DRAG_STEP_SLEEP, MEF_LDOWN, MEF_LUP
    DllCall("SetCursorPos", "int", sx, "int", sy)
    Sleep, 10
    DllCall("mouse_event", "uint", MEF_LDOWN, "int", 0, "int", 0, "uint", 0, "uptr", 0)
    Loop, %DRAG_STEPS% {
        cy := Round(sy + DRAG_LEN * A_Index / DRAG_STEPS)
        DllCall("SetCursorPos", "int", sx, "int", cy)
        Sleep, %DRAG_STEP_SLEEP%
    }
    DllCall("SetCursorPos", "int", sx, "int", sy + DRAG_LEN)
    DllCall("mouse_event", "uint", MEF_LUP, "int", 0, "int", 0, "uint", 0, "uptr", 0)
}

; M5: candidate fix — drag in PHYSICAL pixels under a temporary per-monitor (PMv2)
;     DPI-aware thread context, so SetCursorPos lands on exact physical pixels on the
;     125% monitor. All coords read/written via raw DllCall while PMv2 is active.
DragMethod5(sx, sy) {
    global DRAG_LEN, DRAG_STEPS, DRAG_STEP_SLEEP, MEF_LDOWN, MEF_LUP
    prev := DllCall("User32\SetThreadDpiAwarenessContext", "ptr", -4, "ptr") ; PMv2
    GetCur(px, py)                                ; true physical start
    hMon := MonitorFromPointDll(px, py, 2)
    scale := GetMonitorScale(hMon)
    physLen := Round(DRAG_LEN * scale)            ; DRAG_LEN logical -> physical px
    DllCall("SetCursorPos", "int", px, "int", py)
    Sleep, 10
    DllCall("mouse_event", "uint", MEF_LDOWN, "int", 0, "int", 0, "uint", 0, "uptr", 0)
    Loop, %DRAG_STEPS% {
        cy := Round(py + physLen * A_Index / DRAG_STEPS)
        DllCall("SetCursorPos", "int", px, "int", cy)
        Sleep, %DRAG_STEP_SLEEP%
    }
    DllCall("SetCursorPos", "int", px, "int", py + physLen)
    DllCall("mouse_event", "uint", MEF_LUP, "int", 0, "int", 0, "uint", 0, "uptr", 0)
    DllCall("User32\SetThreadDpiAwarenessContext", "ptr", prev, "ptr") ; restore
}

; M6: manual incremental drag via mouse_event ABSOLUTE normalized over the virtual
;     desktop (mirrors what AHK does internally — sanity check).
DragMethod6(sx, sy) {
    global DRAG_LEN, DRAG_STEPS, DRAG_STEP_SLEEP, MEF_LDOWN, MEF_LUP
    AbsMove(sx, sy)
    Sleep, 10
    DllCall("mouse_event", "uint", MEF_LDOWN, "int", 0, "int", 0, "uint", 0, "uptr", 0)
    Loop, %DRAG_STEPS% {
        cy := Round(sy + DRAG_LEN * A_Index / DRAG_STEPS)
        AbsMove(sx, cy)
        Sleep, %DRAG_STEP_SLEEP%
    }
    AbsMove(sx, sy + DRAG_LEN)
    DllCall("mouse_event", "uint", MEF_LUP, "int", 0, "int", 0, "uint", 0, "uptr", 0)
}

; M7: plain incremental MouseMove with NO button held — tells us whether obliqueness
;     is inherent to the move mapping (button-independent).
DragMethod7(sx, sy) {
    global DRAG_LEN, DRAG_STEPS, DRAG_STEP_SLEEP
    MouseMove, %sx%, %sy%, 0
    Loop, %DRAG_STEPS% {
        cy := Round(sy + DRAG_LEN * A_Index / DRAG_STEPS)
        MouseMove, %sx%, %cy%, 0
        Sleep, %DRAG_STEP_SLEEP%
    }
}

; ── helpers ───────────────────────────────────────────────────────────
GetCur(ByRef x, ByRef y) {
    VarSetCapacity(pt, 8, 0)
    DllCall("GetCursorPos", "ptr", &pt)
    x := NumGet(pt, 0, "int"), y := NumGet(pt, 4, "int")
}

AbsMove(x, y) {
    global MEF_MOVE, MEF_ABS, MEF_VDESK
    SysGet, vx, 76   ; SM_XVIRTUALSCREEN
    SysGet, vy, 77   ; SM_YVIRTUALSCREEN
    SysGet, vw, 78   ; SM_CXVIRTUALSCREEN
    SysGet, vh, 79   ; SM_CYVIRTUALSCREEN
    ax := Round((x - vx) * 65535 / Max(1, vw - 1))
    ay := Round((y - vy) * 65535 / Max(1, vh - 1))
    DllCall("mouse_event", "uint", MEF_MOVE | MEF_ABS | MEF_VDESK
        , "int", ax, "int", ay, "uint", 0, "uptr", 0)
}

MonitorFromPointDll(x, y, flags := 2) {
    pt64 := ((y & 0xFFFFFFFF) << 32) | (x & 0xFFFFFFFF)
    return DllCall("User32\MonitorFromPoint", "int64", pt64, "uint", flags, "ptr")
}

GetMonitorScale(hMon) {
    if (!hMon)
        return 1.0
    dx := 0, dy := 0
    if (DllCall("Shcore\GetDpiForMonitor", "ptr", hMon, "int", 0, "uint*", dx, "uint*", dy) = 0)
        return dx / 96.0
    return 1.0
}

DumpInfo() {
    global LOGFILE
    MouseGetPos, mx, my, hwnd
    prev := DllCall("User32\SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
    GetCur(px, py)
    hMon := MonitorFromPointDll(px, py, 2)
    scale := GetMonitorScale(hMon)
    DllCall("User32\SetThreadDpiAwarenessContext", "ptr", prev, "ptr")
    SysGet, vx, 76
    SysGet, vy, 77
    SysGet, vw, 78
    SysGet, vh, 79
    msg := "UNDER CURSOR (this AHK process is DPI-unaware)`n"
        . "logical mouse = " mx "," my "   hwnd=" hwnd "`n"
        . "physical mouse (PMv2) = " px "," py "`n"
        . "monitor scale = " scale "  (logical->physical factor)`n"
        . "virtualScreen = origin " vx "," vy "  size " vw "x" vh
    ToolTip, %msg%
    FileAppend, % A_Now " | INFO | " StrReplace(msg, "`n", " | ") "`n", %LOGFILE%
}
