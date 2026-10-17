; INFINITT_DragCalib.ahk — calibrate drag pixels -> slices scrolled (AHK v1)
;
; MUST live at the repo root: INFINITT_PACS.ahk uses a library include
; (#include <SetTimerClass>) that resolves against A_ScriptDir\Lib\, which only
; exists at the root. Reuses the production OCR_IncrementalDrag + viewport
; discovery (INFINITT_OCR_Scroll.ahk #Included at the bottom), so the ratio it
; produces plugs straight into OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100.
;
; Relationship in production:
;   pxPerTick = vh * RATIO / 100         (1 tick = 1 slice / Img frame)
;   => RATIO  = pxMoved * 100 / (slicesScrolled * vh)
;
; WORKFLOW A — guided, computes RATIO for you:
;   F8  detect viewport (run first; re-run if you change series/layout)
;   F1  one trial: type drag px -> type Img# BEFORE -> drag -> type Img# AFTER
;       -> prints slices moved, px/slice, this trial's RATIO and running average
;
; WORKFLOW B — you log Img yourself and report back:
;   F8  detect viewport
;   F2  drag DOWN UNIT_PX   F3  drag UP UNIT_PX   (repeat; cumulative px is logged)
;   F9  mark: type the current Img# -> pairs it with the cumulative px
;
; Esc quit.   Log: drag_calib_YYYYMMDD.log (next to this script)

#NoEnv
#SingleInstance Force
#Persistent
#Include %A_ScriptDir%\Lib\LogRetention.ahk
SetBatchLines, -1
CoordMode, Mouse, Screen
SetWinDelay, -1
SetMouseDelay, 10

FormatTime, dragCalibDate,, yyyyMMdd
global CAL_LOG := A_ScriptDir "\drag_calib_" dragCalibDate ".log"
LogRetention_DeleteFilesOlderThan(A_ScriptDir, "drag_calib_*.log")
LogRetention_DeleteFilesOlderThan(A_ScriptDir, "drag_calib_log.txt")
global UNIT_PX := 100
global g_hwnd := 0, g_vp := 0, g_vx := 0, g_vy := 0, g_vw := 0, g_vh := 0
global g_cumPx := 0, g_drags := 0
global g_ratioSum := 0, g_ratioN := 0

ShowGuide()
return

; ── hotkeys ────────────────────────────────────────────────────────────
F8::DetectViewport()

F1::
    if (!g_vp && !DetectViewport())
        return
    InputBox, pxStr, Drag Calib, Drag distance in px (negative = up):
    if ErrorLevel
        return
    px := pxStr + 0
    InputBox, before, Drag Calib, Img# BEFORE drag (read it on screen now):
    if ErrorLevel
        return
    movedDy := DoDrag(px)
    InputBox, after, Drag Calib, % "Img# AFTER drag (commanded dy=" movedDy "):"
    if ErrorLevel
        return
    slices := Abs((after + 0) - (before + 0))
    if (slices = 0) {
        CalLog("TRIAL | dy=" movedDy " | before=" before " | after=" after " | slices=0 (NO MOVE?)")
        ToolTip, slices=0 - no movement or same Img#. Check viewport/series.
        return
    }
    pxPerSlice := Abs(movedDy) / slices
    ratio := Abs(movedDy) * 100 / (slices * g_vh)
    g_ratioSum += ratio, g_ratioN += 1
    avg := g_ratioSum / g_ratioN
    CalLog("TRIAL | dy=" movedDy " | before=" before " | after=" after " | slices=" slices
        . " | px/slice=" pxPerSlice " | RATIO=" ratio " | avgRATIO=" avg " (n=" g_ratioN ")")
    ToolTip, % "slices moved: " slices "    px/slice: " pxPerSlice
        . "`nRATIO this trial: " ratio
        . "`navg RATIO (n=" g_ratioN "): " avg
        . "`n`n=> set OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100 := " avg
return

F2::
    if (!g_vp && !DetectViewport())
        return
    DoDrag(UNIT_PX)
    ToolTip, % "Dragged DOWN " UNIT_PX "px | cumPx=" g_cumPx " | drag#=" g_drags "`nRead Img and press F9 to mark."
return

F3::
    if (!g_vp && !DetectViewport())
        return
    DoDrag(-UNIT_PX)
    ToolTip, % "Dragged UP " UNIT_PX "px | cumPx=" g_cumPx " | drag#=" g_drags "`nRead Img and press F9 to mark."
return

F9::
    InputBox, img, Drag Calib, % "Current Img# (cumPx=" g_cumPx "):"
    if ErrorLevel
        return
    CalLog("MARK | cumPx=" g_cumPx " | Img=" img " | vh=" g_vh)
    ToolTip, % "Marked Img=" img " at cumPx=" g_cumPx
return

Esc::ExitApp

; ── helpers ────────────────────────────────────────────────────────────
ShowGuide() {
    global UNIT_PX, CAL_LOG
    ToolTip, % "DRAG CALIB`n"
        . "F8 detect viewport (run first)`n"
        . "F1 guided trial (px -> Img before -> drag -> Img after -> RATIO)`n"
        . "F2 drag DOWN " UNIT_PX "px    F3 drag UP " UNIT_PX "px    (cumulative)`n"
        . "F9 mark current Img#    Esc quit`n"
        . "Log: " CAL_LOG
}

CalLog(msg) {
    global CAL_LOG
    FileAppend, % A_Now " | " msg "`n", %CAL_LOG%
}

DetectViewport() {
    global g_hwnd, g_vp, g_vx, g_vy, g_vw, g_vh, g_cumPx, g_drags
    hwnd := GetLeftmostINFINITTHwnd()
    if (!hwnd) {
        ToolTip, INFINITT window not found
        return false
    }
    region := OCR_DefaultRegion("SP", 0)
    vp := OCR_GetViewportHwnd(hwnd, "SP", region)
    if (!vp) {
        ToolTip, Viewport control not found
        return false
    }
    WinGetPos, vx, vy, vw, vh, ahk_id %vp%
    g_hwnd := hwnd, g_vp := vp, g_vx := vx, g_vy := vy, g_vw := vw, g_vh := vh
    g_cumPx := 0, g_drags := 0
    msg := "viewport hwnd=" vp " | rect=" vx "," vy " " vw "x" vh
        . " | start=" (vx + Round(vw * 0.5)) "," (vy + Round(vh * 0.2))
    CalLog("DETECT | " msg)
    ToolTip, % "Detected " msg "`n(cumulative reset)"
    return true
}

; Drag dy px (negative = up) from the production start point; returns the actual
; commanded dy after viewport clamping.
DoDrag(dy) {
    global g_vx, g_vy, g_vw, g_vh, g_cumPx, g_drags
    sx := g_vx + Round(g_vw * 0.5)
    sy := g_vy + Round(g_vh * 0.2)
    maxUp := sy - (g_vy + 10)               ; same clamp as OCR_TrySPRoughDrag
    maxDown := (g_vy + g_vh - 10) - sy
    if (dy < 0)
        dy := -Min(Abs(dy), maxUp)
    else
        dy := Min(dy, maxDown)
    ex := sx, ey := sy + dy
    MouseGetPos, bx, by
    OCR_IncrementalDrag(sx, sy, ex, ey)
    Sleep, 60
    MouseGetPos, ax, ay
    actualDy := ay - by
    g_cumPx += dy
    g_drags += 1
    CalLog("DRAG | cmd_dy=" dy " | actual_dy=" actualDy " | from=" sx "," sy " -> " ex "," ey
        . " | vh=" g_vh " | cumPx=" g_cumPx " | drag#=" g_drags)
    return dy
}

; Production lib (drag + viewport discovery). At repo root so its nested
; #include <SetTimerClass> resolves against root\Lib\.
#Include %A_LineFile%\..\Lib\OCR\INFINITT_OCR_Scroll.ahk
