; ris_annotate_calib_test.ahk - IE/Silverlight breast annotation calibration test (AHK v1)
;
; Hotkeys:
;   F6  Find IE annotation host, calibrate, show report, draw overlays.
;   F7  Copy last calibration report to clipboard.
;   F8  Move through key anchors: RT/LT text, nipples, circle edges, buttons.
;   F9  Test lesion coordinate conversion by moving mouse only.
;   F10 Clear overlays.
;   F2  Toggle interactive calibration mode.
;   F3/F4 Cycle editable target while interactive mode is on.
;   Left-drag moves the selected target while interactive mode is on.
;   Arrow keys nudge selected target while interactive mode is on.
;   Ctrl+Alt+LeftClick snaps selected target to current mouse position.
;   Ctrl+Alt+S saves current host-relative pixel calibration to ris_annotate_calib.ini.
;   Esc Exit.
;
; This script does not place annotations. F8 only moves the mouse over candidate
; button centers; it does not click.

#NoEnv
#SingleInstance Force
#Include %A_ScriptDir%\..\..\..\Lib\IsCurrentSessionRDP.ahk
SetBatchLines, -1
SetTitleMatchMode, 2
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
CoordMode, ToolTip, Screen

global PIX_DARK := 80
global BREAST_RADIUS_CM := 5.5

; Screenshot-derived defaults are converted to host-relative pixels after the
; Silverlight host is detected. Saved calibration values are pixels, not ratios.
; These are from the provided 1180x836 capture where the host includes tab strip.
global DEFAULT_DRAW_X_FR := 0.006
global DEFAULT_DRAW_Y_FR := 0.091
global DEFAULT_DRAW_W_FR := 0.816
global DEFAULT_DRAW_H_FR := 0.891
global DEFAULT_RT_CX_FR := 0.305
global DEFAULT_RT_CY_FR := 0.304
global DEFAULT_LT_CX_FR := 0.575
global DEFAULT_LT_CY_FR := 0.304
global DEFAULT_R_FR := 0.128
global DEFAULT_RT_LABEL_X_FR := 0.178
global DEFAULT_RT_LABEL_Y_FR := 0.517
global DEFAULT_LT_LABEL_X_FR := 0.707
global DEFAULT_LT_LABEL_Y_FR := 0.517
global DEFAULT_LABEL_BOTTOM_GAP_FR := 0.037
global DEFAULT_BTN_COL0_X_FR := 0.899
global DEFAULT_BTN_COL1_X_FR := 0.958
global DEFAULT_BTN_ROW0_Y_FR := 0.130
global DEFAULT_BTN_ROW_PITCH_FR := 0.079

global REL_DRAW_X := 0
global REL_DRAW_Y := 0
global REL_DRAW_W := 0
global REL_DRAW_H := 0
global REL_RT_CX := 0
global REL_RT_CY := 0
global REL_LT_CX := 0
global REL_LT_CY := 0
global REL_R := 0
global REL_RT_LABEL_X := 0
global REL_RT_LABEL_Y := 0
global REL_LT_LABEL_X := 0
global REL_LT_LABEL_Y := 0
global REL_LABEL_BOTTOM_GAP := 0
global REL_BTN_COL0_X := 0
global REL_BTN_COL1_X := 0
global REL_BTN_ROW0_Y := 0
global REL_BTN_ROW_PITCH := 0

global g_ie_hwnd := 0
global g_ctrl_hwnd := 0
global g_ctrl_x := 0
global g_ctrl_y := 0
global g_ctrl_w := 0
global g_ctrl_h := 0
global g_dom_left := 0
global g_dom_top := 0
global g_dom_w := 0
global g_dom_h := 0
global g_dom_scale_x := 1
global g_dom_scale_y := 1
global g_dom_scroll_x := 0
global g_dom_scroll_y := 0
global g_dom_client_w := 0
global g_dom_client_h := 0
global g_dpi_awareness := ""
global g_dpi_x := 0
global g_dpi_y := 0
global g_screen_w := 0
global g_screen_h := 0
global g_virtual_w := 0
global g_virtual_h := 0
global g_is_rdp := 0
global g_loaded_user_calib := 0
global g_interactive := 0
global g_target_idx := 1
global g_targets := ["DRAW_POS","DRAW_SIZE","RT_CENTER","LT_CENTER","RADIUS","RT_LABEL","LT_LABEL","BTN_COL0","BTN_COL1","BTN_ROW0","BTN_PITCH"]
global g_rt_cx := 0
global g_rt_cy := 0
global g_lt_cx := 0
global g_lt_cy := 0
global g_rt_r := 0
global g_lt_r := 0
global g_radius := 0
global g_scale := 0
global g_last_report := ""
global g_overlay_ids := []

F6::
    _RunCalibration()
return

F7::
    Clipboard := g_last_report
    ToolTip, Calibration report copied to clipboard.
    SetTimer, _HideTip, -1200
return

F8::
    if (g_last_report = "")
        _RunCalibration()
    _WalkAnchors()
return

F9::
    if (g_last_report = "")
        _RunCalibration()
    _LesionMoveTest()
return

F10::
    _ClearOverlays()
return

F2::
    if (g_last_report = "")
        _RunCalibration()
    _ToggleInteractive()
return

F3::
    _CycleTarget(1)
return

F4::
    _CycleTarget(-1)
return

F5::
^!s::
    _SaveUserCalibration()
return

^!LButton::
    _SnapTargetToMouse()
return

#If (g_interactive)
LButton::_DragCurrentTarget()
Up::_NudgeTarget(0, -1)
Down::_NudgeTarget(0, 1)
Left::_NudgeTarget(-1, 0)
Right::_NudgeTarget(1, 0)
+Up::_NudgeTarget(0, -10)
+Down::_NudgeTarget(0, 10)
+Left::_NudgeTarget(-10, 0)
+Right::_NudgeTarget(10, 0)
^Up::_NudgeTarget(0, -50)
^Down::_NudgeTarget(0, 50)
^Left::_NudgeTarget(-50, 0)
^Right::_NudgeTarget(50, 0)
#If

Esc::ExitApp

_RunCalibration() {
    global g_last_report
    global g_loaded_user_calib

    _InitDpiAwareness()
    _RefreshDpiMetrics()
    if !_FindIEAnnotationHost()
        return
    _InitDefaultPixelCalibration()
    _LoadUserCalibration()
    if (g_loaded_user_calib)
        _ApplyRelToScreen()
    else {
        ; A rejected saved calibration may already have overwritten REL_* values.
        ; Restore safe proportional defaults before attempting screen detection.
        _InitDefaultPixelCalibration()
        _CalibrateFromScreen()
    }
    g_last_report := _BuildReport()
    _SaveReport(g_last_report)
    Clipboard := g_last_report
    _ClearOverlays()
    _DrawCalibrationOverlays()
    MsgBox, 64, RIS Annotate Calibration, %g_last_report%`n`nReport saved beside this script and copied to clipboard.
}

_InitDefaultPixelCalibration() {
    global g_ctrl_w, g_ctrl_h
    global DEFAULT_DRAW_X_FR, DEFAULT_DRAW_Y_FR, DEFAULT_DRAW_W_FR, DEFAULT_DRAW_H_FR
    global DEFAULT_RT_CX_FR, DEFAULT_RT_CY_FR, DEFAULT_LT_CX_FR, DEFAULT_LT_CY_FR, DEFAULT_R_FR
    global DEFAULT_RT_LABEL_X_FR, DEFAULT_RT_LABEL_Y_FR, DEFAULT_LT_LABEL_X_FR, DEFAULT_LT_LABEL_Y_FR
    global DEFAULT_LABEL_BOTTOM_GAP_FR, DEFAULT_BTN_COL0_X_FR, DEFAULT_BTN_COL1_X_FR, DEFAULT_BTN_ROW0_Y_FR, DEFAULT_BTN_ROW_PITCH_FR
    global REL_DRAW_X, REL_DRAW_Y, REL_DRAW_W, REL_DRAW_H
    global REL_RT_CX, REL_RT_CY, REL_LT_CX, REL_LT_CY, REL_R
    global REL_RT_LABEL_X, REL_RT_LABEL_Y, REL_LT_LABEL_X, REL_LT_LABEL_Y, REL_LABEL_BOTTOM_GAP
    global REL_BTN_COL0_X, REL_BTN_COL1_X, REL_BTN_ROW0_Y, REL_BTN_ROW_PITCH

    REL_DRAW_X := Round(g_ctrl_w * DEFAULT_DRAW_X_FR)
    REL_DRAW_Y := Round(g_ctrl_h * DEFAULT_DRAW_Y_FR)
    REL_DRAW_W := Round(g_ctrl_w * DEFAULT_DRAW_W_FR)
    REL_DRAW_H := Round(g_ctrl_h * DEFAULT_DRAW_H_FR)
    REL_RT_CX := Round(g_ctrl_w * DEFAULT_RT_CX_FR)
    REL_RT_CY := Round(g_ctrl_h * DEFAULT_RT_CY_FR)
    REL_LT_CX := Round(g_ctrl_w * DEFAULT_LT_CX_FR)
    REL_LT_CY := Round(g_ctrl_h * DEFAULT_LT_CY_FR)
    REL_R := Round(g_ctrl_w * DEFAULT_R_FR)
    REL_RT_LABEL_X := Round(g_ctrl_w * DEFAULT_RT_LABEL_X_FR)
    REL_RT_LABEL_Y := Round(g_ctrl_h * DEFAULT_RT_LABEL_Y_FR)
    REL_LT_LABEL_X := Round(g_ctrl_w * DEFAULT_LT_LABEL_X_FR)
    REL_LT_LABEL_Y := Round(g_ctrl_h * DEFAULT_LT_LABEL_Y_FR)
    REL_LABEL_BOTTOM_GAP := Round(g_ctrl_h * DEFAULT_LABEL_BOTTOM_GAP_FR)
    REL_BTN_COL0_X := Round(g_ctrl_w * DEFAULT_BTN_COL0_X_FR)
    REL_BTN_COL1_X := Round(g_ctrl_w * DEFAULT_BTN_COL1_X_FR)
    REL_BTN_ROW0_Y := Round(g_ctrl_h * DEFAULT_BTN_ROW0_Y_FR)
    REL_BTN_ROW_PITCH := Round(g_ctrl_h * DEFAULT_BTN_ROW_PITCH_FR)
}

_InitDpiAwareness() {
    global g_dpi_awareness

    ; showLungCAD-compatible mode:
    ; keep AHK screen coords, WinGetPos, MouseMove/Click, PixelGetColor, and
    ; overlay GUI in the same Windows logical coordinate space. Do not force
    ; process DPI awareness in this script.
    g_dpi_awareness := "Default(showLungCAD-compatible)"
}

_RefreshDpiMetrics() {
    global g_dpi_x, g_dpi_y, g_screen_w, g_screen_h, g_virtual_w, g_virtual_h, g_is_rdp

    g_is_rdp := IsCurrentSessionRDP() ? 1 : 0
    hDC := DllCall("User32.dll\GetDC", "Ptr", 0, "Ptr")
    if (hDC) {
        g_dpi_x := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "Int", 88, "Int")
        g_dpi_y := DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "Int", 90, "Int")
        DllCall("User32.dll\ReleaseDC", "Ptr", 0, "Ptr", hDC)
    }
    g_screen_w := DllCall("User32.dll\GetSystemMetrics", "Int", 0, "Int")
    g_screen_h := DllCall("User32.dll\GetSystemMetrics", "Int", 1, "Int")
    g_virtual_w := DllCall("User32.dll\GetSystemMetrics", "Int", 78, "Int")
    g_virtual_h := DllCall("User32.dll\GetSystemMetrics", "Int", 79, "Int")
}

_FindIEAnnotationHost() {
    global g_ie_hwnd, g_ctrl_hwnd, g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h

    ; Preferred path for the RIS reporting page: the Silverlight plugin is
    ; visible in IE DOM even when it is not exposed as a child HWND.
    if (_FindIEAnnotationHostViaDom())
        return 1

    ; Fallback for pages that expose the plugin as a native child window.
    WinGet, hwndList, List, ahk_class IEFrame
    Loop, %hwndList% {
        hwnd := hwndList%A_Index%
        ControlGetPos, cx, cy, cw, ch, SilverlightControlHost, ahk_id %hwnd%
        if (cw < 300 || ch < 300)
            continue

        ControlGet, ctrlHwnd, Hwnd,, SilverlightControlHost, ahk_id %hwnd%
        if (!ctrlHwnd)
            continue

        WinGetPos, x1, y1, w, h, ahk_id %ctrlHwnd%
        if (w < 300 || h < 300)
            continue

        g_ie_hwnd := hwnd
        g_ctrl_hwnd := ctrlHwnd
        g_ctrl_x := x1
        g_ctrl_y := y1
        g_ctrl_w := w
        g_ctrl_h := h
        WinActivate, ahk_id %hwnd%
        Sleep, 200
        return 1
    }

    MsgBox, 16, Not found, No IEFrame with a visible SilverlightControlHost larger than 300x300 was found.
    return 0
}

_FindIEAnnotationHostViaDom() {
    global g_ie_hwnd, g_ctrl_hwnd, g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global g_dom_left, g_dom_top, g_dom_w, g_dom_h, g_dom_scale_x, g_dom_scale_y
    global g_dom_scroll_x, g_dom_scroll_y, g_dom_client_w, g_dom_client_h

    shell := ComObjCreate("Shell.Application")
    wins := shell.Windows
    for wb in wins {
        try fullName := wb.FullName
        catch
            continue
        if !InStr(fullName, "iexplore.exe")
            continue

        try url := wb.LocationURL
        catch
            url := ""
        if !(InStr(url, "MJB3A035") || InStr(url, "reportformid=201"))
            continue

        try doc := wb.Document
        catch
            continue
        if !IsObject(doc)
            continue

        host := ""
        try host := doc.getElementById("silverlightControlHost")
        catch
            host := ""
        if !IsObject(host) {
            try objs := doc.getElementsByTagName("object")
            catch
                continue
            Loop, % objs.length {
                idx := A_Index - 1
                obj := objs.item(idx)
                try objType := obj.type
                catch
                    objType := ""
                if InStr(objType, "silverlight") {
                    host := obj
                    break
                }
            }
        }
        if !IsObject(host)
            continue

        try rc := host.getBoundingClientRect()
        catch
            continue

        left := Round(rc.left)
        top := Round(rc.top)
        width := Round(rc.right - rc.left)
        height := Round(rc.bottom - rc.top)
        if (width < 300 || height < 300) {
            try width := host.offsetWidth
            catch
                width := 0
            try height := host.offsetHeight
            catch
                height := 0
        }
        if (width < 300 || height < 300)
            continue

        hwnd := wb.HWND
        ControlGet, serverHwnd, Hwnd,, Internet Explorer_Server1, ahk_id %hwnd%
        if (!serverHwnd)
            ControlGet, serverHwnd, Hwnd,, Internet Explorer_Server, ahk_id %hwnd%
        if (!serverHwnd)
            continue

        WinGetPos, serverX, serverY, serverW, serverH, ahk_id %serverHwnd%

        scaleX := 1.0
        scaleY := 1.0
        scrollX := 0
        scrollY := 0
        clientW := 0
        clientH := 0
        try {
            scrollX := doc.documentElement.scrollLeft
            scrollY := doc.documentElement.scrollTop
            clientW := doc.documentElement.clientWidth
            clientH := doc.documentElement.clientHeight
        }
        catch {
        }
        if (!clientW || !clientH) {
            try {
                scrollX := doc.body.scrollLeft
                scrollY := doc.body.scrollTop
                clientW := doc.body.clientWidth
                clientH := doc.body.clientHeight
            }
            catch {
            }
        }
        if (clientW > 0)
            scaleX := serverW / clientW
        if (clientH > 0)
            scaleY := serverH / clientH

        g_ie_hwnd := hwnd
        g_ctrl_hwnd := serverHwnd
        ; getBoundingClientRect() is viewport-relative; do not subtract scroll.
        g_ctrl_x := Round(serverX + left * scaleX)
        g_ctrl_y := Round(serverY + top * scaleY)
        g_ctrl_w := Round(width * scaleX)
        g_ctrl_h := Round(height * scaleY)
        g_dom_left := left
        g_dom_top := top
        g_dom_w := width
        g_dom_h := height
        g_dom_scale_x := scaleX
        g_dom_scale_y := scaleY
        g_dom_scroll_x := scrollX
        g_dom_scroll_y := scrollY
        g_dom_client_w := clientW
        g_dom_client_h := clientH

        WinActivate, ahk_id %hwnd%
        Sleep, 200
        return 1
    }
    return 0
}

_CalibrateFromScreen() {
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global REL_RT_CX, REL_RT_CY, REL_LT_CX, REL_LT_CY, REL_R
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_rt_r, g_lt_r, g_radius, g_scale
    global BREAST_RADIUS_CM

    rtX0 := _SX(REL_RT_CX)
    rtY0 := _SY(REL_RT_CY)
    ltX0 := _SX(REL_LT_CX)
    ltY0 := _SY(REL_LT_CY)
    r0 := REL_R

    rtFound := _ScanCircleNear(rtX0, rtY0, r0, 0, rt_cx, rt_cy, rt_r)
    ltFound := _ScanCircleNear(ltX0, ltY0, r0, 1, lt_cx, lt_cy, lt_r)

    if (!rtFound) {
        rt_cx := rtX0
        rt_cy := rtY0
        rt_r := _RadiusFromLabel("R")
    }
    if (!ltFound) {
        lt_cx := ltX0
        lt_cy := ltY0
        lt_r := _RadiusFromLabel("L")
    }

    g_rt_cx := rt_cx
    g_rt_cy := rt_cy
    g_lt_cx := lt_cx
    g_lt_cy := lt_cy
    g_rt_r := rt_r
    g_lt_r := lt_r
    g_radius := Round((rt_r + lt_r) / 2)
    g_scale := g_radius / BREAST_RADIUS_CM
    _SyncRelFromScreen()
}

_ApplyRelToScreen() {
    global REL_RT_CX, REL_RT_CY, REL_LT_CX, REL_LT_CY, REL_R
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_rt_r, g_lt_r, g_radius, g_scale
    global BREAST_RADIUS_CM

    g_rt_cx := _SX(REL_RT_CX)
    g_rt_cy := _SY(REL_RT_CY)
    g_lt_cx := _SX(REL_LT_CX)
    g_lt_cy := _SY(REL_LT_CY)
    g_radius := Round(REL_R)
    g_rt_r := g_radius
    g_lt_r := g_radius
    g_scale := g_radius / BREAST_RADIUS_CM
}

_SyncRelFromScreen() {
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global REL_RT_CX, REL_RT_CY, REL_LT_CX, REL_LT_CY, REL_R
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_radius

    REL_RT_CX := g_rt_cx - g_ctrl_x
    REL_RT_CY := g_rt_cy - g_ctrl_y
    REL_LT_CX := g_lt_cx - g_ctrl_x
    REL_LT_CY := g_lt_cy - g_ctrl_y
    REL_R := g_radius
}

_ScanCircleNear(cx0, cy0, r0, isLeftBreast, ByRef cx, ByRef cy, ByRef r) {
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global PIX_DARK

    xMin := Max(g_ctrl_x, cx0 - Round(r0 * 1.35))
    xMax := Min(g_ctrl_x + g_ctrl_w - 1, cx0 + Round(r0 * 1.35))
    yMin := Max(g_ctrl_y, cy0 - Round(r0 * 1.35))
    yMax := Min(g_ctrl_y + g_ctrl_h - 1, cy0 + Round(r0 * 1.35))

    ; First scan vertical through the estimated center.
    topY := ""
    Loop, % (yMax - yMin + 1) {
        y := yMin + A_Index - 1
        if (_IsDark(cx0, y)) {
            topY := y
            break
        }
    }
    botY := ""
    Loop, % (yMax - yMin + 1) {
        y := yMax - A_Index + 1
        if (_IsDark(cx0, y)) {
            botY := y
            break
        }
    }
    if (topY = "" || botY = "")
        return 0

    midY := (topY + botY) // 2
    leftX := ""
    Loop, % (xMax - xMin + 1) {
        x := xMin + A_Index - 1
        if (_IsDark(x, midY)) {
            leftX := x
            break
        }
    }
    rightX := ""
    Loop, % (xMax - xMin + 1) {
        x := xMax - A_Index + 1
        if (_IsDark(x, midY)) {
            rightX := x
            break
        }
    }
    if (leftX = "" || rightX = "")
        return 0

    cx := (leftX + rightX) // 2
    cy := (topY + botY) // 2
    r := (rightX - leftX) // 2
    return (r > 20)
}

_IsDark(x, y) {
    global PIX_DARK

    PixelGetColor, col, %x%, %y%, RGB
    red := (col >> 16) & 0xFF
    green := (col >> 8) & 0xFF
    blue := col & 0xFF
    return (red < PIX_DARK && green < PIX_DARK && blue < PIX_DARK)
}

_RadiusFromLabel(side) {
    global REL_LABEL_BOTTOM_GAP, REL_RT_LABEL_Y, REL_LT_LABEL_Y
    global REL_RT_CY, REL_LT_CY, REL_R

    if (side = "R") {
        labelY := _SY(REL_RT_LABEL_Y)
        centerY := _SY(REL_RT_CY)
    } else {
        labelY := _SY(REL_LT_LABEL_Y)
        centerY := _SY(REL_LT_CY)
    }
    r := Round((labelY - REL_LABEL_BOTTOM_GAP) - centerY)
    if (r < 20)
        r := Round(REL_R)
    return r
}

_BuildReport() {
    global g_ie_hwnd, g_ctrl_hwnd, g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global g_dom_left, g_dom_top, g_dom_w, g_dom_h, g_dom_scale_x, g_dom_scale_y
    global g_dom_scroll_x, g_dom_scroll_y, g_dom_client_w, g_dom_client_h
    global g_dpi_awareness, g_dpi_x, g_dpi_y, g_screen_w, g_screen_h, g_virtual_w, g_virtual_h, g_is_rdp
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_rt_r, g_lt_r, g_radius, g_scale
    global REL_DRAW_X, REL_DRAW_Y, REL_DRAW_W, REL_DRAW_H
    global REL_RT_LABEL_X, REL_RT_LABEL_Y, REL_LT_LABEL_X, REL_LT_LABEL_Y
    global REL_BTN_COL0_X, REL_BTN_COL1_X, REL_BTN_ROW0_Y, REL_BTN_ROW_PITCH
    global BREAST_RADIUS_CM

    txt := ""
    txt .= "Session: " . (g_is_rdp ? "RDP" : "local") . "  DPI mode: " . g_dpi_awareness . "  dpi=" . g_dpi_x . "x" . g_dpi_y
    txt .= "  screen=" . g_screen_w . "x" . g_screen_h . " virtual=" . g_virtual_w . "x" . g_virtual_h . "`r`n"
    txt .= "IE hwnd: " . g_ie_hwnd . "  Silverlight hwnd: " . g_ctrl_hwnd . "`r`n"
    txt .= "Host rect screen: x=" . g_ctrl_x . " y=" . g_ctrl_y . " w=" . g_ctrl_w . " h=" . g_ctrl_h . "`r`n"
    txt .= "Host rect DOM: left=" . g_dom_left . " top=" . g_dom_top . " w=" . g_dom_w . " h=" . g_dom_h
    txt .= "  scroll=" . g_dom_scroll_x . "," . g_dom_scroll_y . " client=" . g_dom_client_w . "x" . g_dom_client_h
    txt .= " scale=" . Round(g_dom_scale_x, 3) . "," . Round(g_dom_scale_y, 3) . "`r`n"
    txt .= "Host-relative pixel calibration: draw=" . REL_DRAW_X . "," . REL_DRAW_Y . "," . REL_DRAW_W . "," . REL_DRAW_H
    txt .= " rt=" . REL_RT_CX . "," . REL_RT_CY . " lt=" . REL_LT_CX . "," . REL_LT_CY . " r=" . REL_R . "`r`n"
    txt .= "Drawing estimate: x=" . _SX(REL_DRAW_X) . " y=" . _SY(REL_DRAW_Y)
    txt .= " w=" . REL_DRAW_W . " h=" . REL_DRAW_H . "`r`n"
    txt .= "`r`nAnchors:`r`n"
    txt .= "RT text anchor: " . _SX(REL_RT_LABEL_X) . "," . _SY(REL_RT_LABEL_Y) . "`r`n"
    txt .= "LT text anchor: " . _SX(REL_LT_LABEL_X) . "," . _SY(REL_LT_LABEL_Y) . "`r`n"
    txt .= "RT nipple/center: " . g_rt_cx . "," . g_rt_cy . "  r=" . g_rt_r . "`r`n"
    txt .= "LT nipple/center: " . g_lt_cx . "," . g_lt_cy . "  r=" . g_lt_r . "`r`n"
    txt .= "Avg radius: " . g_radius . " px; scale: " . Round(g_scale, 2) . " px/cm using breast radius " . BREAST_RADIUS_CM . " cm`r`n"
    txt .= "Radius check: " . (_RelRadiusPlausible() ? "PASS" : "FAIL - do not save or place lesions") . "`r`n"
    txt .= "Overlay legend: red=nipple center; blue=outer-breast bounding square; orange=RT/LT text anchor; green=drawing area.`r`n"
    txt .= "`r`nButton grid:`r`n"
    txt .= "col0 x=" . _SX(REL_BTN_COL0_X) . "  col1 x=" . _SX(REL_BTN_COL1_X) . "`r`n"
    txt .= "row0 y=" . _SY(REL_BTN_ROW0_Y) . "  row pitch=" . REL_BTN_ROW_PITCH . " px`r`n"
    Loop, 11 {
        row := A_Index - 1
        txt .= "row " . row . ": col0 " . _ButtonX(0) . "," . _ButtonY(row) . "  col1 " . _ButtonX(1) . "," . _ButtonY(row) . "`r`n"
    }
    txt .= "row 11: col1 " . _ButtonX(1) . "," . _ButtonY(11) . "  bottom partial eye icon, no col0`r`n"

    txt .= "`r`nButton inventory:`r`n"
    txt .= "row 0: diagonal hatch large / diagonal hatch small`r`n"
    txt .= "row 1: vertical hatch / horizontal hatch`r`n"
    txt .= "row 2: filled blue circle large / filled blue circle small`r`n"
    txt .= "row 3: red star large / red star small`r`n"
    txt .= "row 4: duct or arch large / duct or arch small`r`n"
    txt .= "row 5: clustered dots large / clustered dots small`r`n"
    txt .= "row 6: oval ring large / oval ring small`r`n"
    txt .= "row 7: horizontal scar lines / vertical scar lines`r`n"
    txt .= "row 8: oblique scar slash / oblique scar backslash`r`n"
    txt .= "row 9: line-with-dot / shaded oval`r`n"
    txt .= "row 10: radiating starburst / scattered dots`r`n"
    txt .= "row 11: none / eye icon, bottom partial`r`n"
    txt .= "`r`nLesion formula:`r`n"
    txt .= "angle=clock*pi/6; x=center_x+dist_cm*scale*sin(angle); y=center_y-dist_cm*scale*cos(angle)`r`n"
    txt .= "Axillary default: RT clock 10.5, LT clock 1.5, distance=1.20*radius.`r`n"
    txt .= "`r`nInteractive mode:`r`n"
    txt .= "F2 toggle, F3/F4 target, arrows nudge 1px, Shift+arrows 10px, Ctrl+arrows 50px, Ctrl+Alt+LeftClick snap, Ctrl+Alt+S save.`r`n"
    return txt
}

_SaveReport(txt) {
    outFile := A_ScriptDir . "\ris_annotate_calib_last.txt"
    FileDelete, %outFile%
    FileAppend, %txt%, %outFile%, UTF-8
}

_DrawCalibrationOverlays() {
    global g_ctrl_w, g_ctrl_h
    global REL_DRAW_X, REL_DRAW_Y, REL_DRAW_W, REL_DRAW_H
    global REL_RT_LABEL_X, REL_RT_LABEL_Y, REL_LT_LABEL_X, REL_LT_LABEL_Y
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_radius

    _OverlayBox("draw", _SX(REL_DRAW_X), _SY(REL_DRAW_Y), REL_DRAW_W, REL_DRAW_H, "00AA00", 2)
    _OverlayCross("RT_text", _SX(REL_RT_LABEL_X), _SY(REL_RT_LABEL_Y), "FF6600")
    _OverlayCross("LT_text", _SX(REL_LT_LABEL_X), _SY(REL_LT_LABEL_Y), "FF6600")
    _OverlayCross("RT_center", g_rt_cx, g_rt_cy, "FF0000")
    _OverlayCross("LT_center", g_lt_cx, g_lt_cy, "FF0000")
    radiusColor := _RelRadiusPlausible() ? "0000FF" : "FF00FF"
    _OverlayCircleBox("RT_circle_box", g_rt_cx, g_rt_cy, g_radius, radiusColor)
    _OverlayCircleBox("LT_circle_box", g_lt_cx, g_lt_cy, g_radius, radiusColor)

    Loop, 11 {
        row := A_Index - 1
        _OverlayCross("btn0_" . row, _ButtonX(0), _ButtonY(row), "0000FF")
        _OverlayCross("btn1_" . row, _ButtonX(1), _ButtonY(row), "0000FF")
    }
    _OverlayCross("btn1_11", _ButtonX(1), _ButtonY(11), "0000FF")
}

_OverlayCross(name, x, y, color) {
    _OverlayBox(name . "_h", x - 8, y - 1, 17, 3, color, 0)
    _OverlayBox(name . "_v", x - 1, y - 8, 3, 17, color, 0)
}

_OverlayCircleBox(name, cx, cy, r, color) {
    _OverlayBox(name, cx - r, cy - r, 2 * r, 2 * r, color, 2)
}

_OverlayBox(name, x, y, w, h, color, borderOnly) {
    global g_overlay_ids

    if (borderOnly) {
        _OverlaySolid(name . "_t", x, y, w, borderOnly, color)
        _OverlaySolid(name . "_b", x, y + h - borderOnly, w, borderOnly, color)
        _OverlaySolid(name . "_l", x, y, borderOnly, h, color)
        _OverlaySolid(name . "_r", x + w - borderOnly, y, borderOnly, h, color)
        return
    }
    _OverlaySolid(name, x, y, w, h, color)
}

_OverlaySolid(name, x, y, w, h, color) {
    global g_overlay_ids

    guiName := "Calib_" . name
    Gui, %guiName%:Destroy
    Gui, %guiName%:+AlwaysOnTop -Caption +ToolWindow +E0x20
    ; Overlay coordinates and sizes are already physical screen pixels. Without
    ; -DPIScale, a 200% desktop stretches each segment into an offset "grid".
    Gui, %guiName%:-DPIScale
    Gui, %guiName%:Color, %color%
    Gui, %guiName%:Show, x%x% y%y% w%w% h%h% NoActivate, %guiName%
    g_overlay_ids.Push(guiName)
}

_ClearOverlays() {
    global g_overlay_ids

    for idx, guiName in g_overlay_ids {
        Gui, %guiName%:Destroy
    }
    g_overlay_ids := []
    ToolTip
}

_ToggleInteractive() {
    global g_interactive

    g_interactive := !g_interactive
    if (g_interactive) {
        _ApplyRelToScreen()
        _RefreshInteractive()
    } else {
        ToolTip
    }
}

_CycleTarget(delta) {
    global g_interactive, g_target_idx, g_targets

    if (!g_interactive)
        return
    g_target_idx += delta
    if (g_target_idx < 1)
        g_target_idx := g_targets.Length()
    if (g_target_idx > g_targets.Length())
        g_target_idx := 1
    _RefreshInteractive()
}

_NudgeTarget(dx, dy) {
    global g_interactive

    if (!g_interactive)
        return
    _AdjustCurrentTarget(dx, dy, 0)
    _RefreshInteractive()
}

_SnapTargetToMouse() {
    global g_interactive

    if (!g_interactive)
        return
    MouseGetPos, mx, my
    _AdjustCurrentTarget(mx, my, 1)
    _RefreshInteractive()
}

_DragCurrentTarget() {
    global g_interactive

    if (!g_interactive)
        return

    MouseGetPos, lastX, lastY
    moved := false
    while GetKeyState("LButton", "P") {
        Sleep, 15
        MouseGetPos, x, y
        dx := x - lastX
        dy := y - lastY
        if (dx || dy) {
            _AdjustCurrentTarget(dx, dy, 0)
            _RefreshInteractive()
            lastX := x
            lastY := y
            moved := true
        }
    }
    if (!moved)
        _SnapTargetToMouse()
}

_AdjustCurrentTarget(a, b, absolute) {
    global g_target_idx, g_targets
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global REL_DRAW_X, REL_DRAW_Y, REL_DRAW_W, REL_DRAW_H
    global REL_RT_CX, REL_RT_CY, REL_LT_CX, REL_LT_CY, REL_R
    global REL_RT_LABEL_X, REL_RT_LABEL_Y, REL_LT_LABEL_X, REL_LT_LABEL_Y
    global REL_BTN_COL0_X, REL_BTN_COL1_X, REL_BTN_ROW0_Y, REL_BTN_ROW_PITCH
    global g_rt_cx, g_rt_cy

    target := g_targets[g_target_idx]

    if (absolute) {
        mx := a
        my := b
        relX := mx - g_ctrl_x
        relY := my - g_ctrl_y
        if (target = "DRAW_POS") {
            REL_DRAW_X := relX
            REL_DRAW_Y := relY
        } else if (target = "DRAW_SIZE") {
            REL_DRAW_W := relX - REL_DRAW_X
            REL_DRAW_H := relY - REL_DRAW_Y
        } else if (target = "RT_CENTER") {
            REL_RT_CX := relX
            REL_RT_CY := relY
        } else if (target = "LT_CENTER") {
            REL_LT_CX := relX
            REL_LT_CY := relY
        } else if (target = "RADIUS") {
            dist := Sqrt((mx - g_rt_cx) ** 2 + (my - g_rt_cy) ** 2)
            REL_R := Round(dist)
        } else if (target = "RT_LABEL") {
            REL_RT_LABEL_X := relX
            REL_RT_LABEL_Y := relY
        } else if (target = "LT_LABEL") {
            REL_LT_LABEL_X := relX
            REL_LT_LABEL_Y := relY
        } else if (target = "BTN_COL0") {
            REL_BTN_COL0_X := relX
        } else if (target = "BTN_COL1") {
            REL_BTN_COL1_X := relX
        } else if (target = "BTN_ROW0") {
            REL_BTN_ROW0_Y := relY
        } else if (target = "BTN_PITCH") {
            REL_BTN_ROW_PITCH := Abs(relY - REL_BTN_ROW0_Y)
        }
        _ClampRelValues()
        return
    }

    dxRel := a
    dyRel := b
    if (target = "DRAW_POS") {
        REL_DRAW_X += dxRel
        REL_DRAW_Y += dyRel
    } else if (target = "DRAW_SIZE") {
        REL_DRAW_W += dxRel
        REL_DRAW_H += dyRel
    } else if (target = "RT_CENTER") {
        REL_RT_CX += dxRel
        REL_RT_CY += dyRel
    } else if (target = "LT_CENTER") {
        REL_LT_CX += dxRel
        REL_LT_CY += dyRel
    } else if (target = "RADIUS") {
        REL_R += b
    } else if (target = "RT_LABEL") {
        REL_RT_LABEL_X += dxRel
        REL_RT_LABEL_Y += dyRel
    } else if (target = "LT_LABEL") {
        REL_LT_LABEL_X += dxRel
        REL_LT_LABEL_Y += dyRel
    } else if (target = "BTN_COL0") {
        REL_BTN_COL0_X += dxRel
    } else if (target = "BTN_COL1") {
        REL_BTN_COL1_X += dxRel
    } else if (target = "BTN_ROW0") {
        REL_BTN_ROW0_Y += dyRel
    } else if (target = "BTN_PITCH") {
        REL_BTN_ROW_PITCH += dyRel
    }
    _ClampRelValues()
}

_ClampRelValues() {
    global REL_DRAW_X, REL_DRAW_Y, REL_DRAW_W, REL_DRAW_H
    global REL_RT_CX, REL_RT_CY, REL_LT_CX, REL_LT_CY, REL_R
    global REL_RT_LABEL_X, REL_RT_LABEL_Y, REL_LT_LABEL_X, REL_LT_LABEL_Y
    global REL_BTN_COL0_X, REL_BTN_COL1_X, REL_BTN_ROW0_Y, REL_BTN_ROW_PITCH

    global g_ctrl_w, g_ctrl_h

    REL_DRAW_X := _Clamp(REL_DRAW_X, -g_ctrl_w, g_ctrl_w * 2)
    REL_DRAW_Y := _Clamp(REL_DRAW_Y, -g_ctrl_h, g_ctrl_h * 2)
    REL_DRAW_W := _Clamp(REL_DRAW_W, 10, g_ctrl_w * 2)
    REL_DRAW_H := _Clamp(REL_DRAW_H, 10, g_ctrl_h * 2)
    REL_RT_CX := _Clamp(REL_RT_CX, -g_ctrl_w, g_ctrl_w * 2)
    REL_RT_CY := _Clamp(REL_RT_CY, -g_ctrl_h, g_ctrl_h * 2)
    REL_LT_CX := _Clamp(REL_LT_CX, -g_ctrl_w, g_ctrl_w * 2)
    REL_LT_CY := _Clamp(REL_LT_CY, -g_ctrl_h, g_ctrl_h * 2)
    REL_R := _Clamp(REL_R, 5, g_ctrl_w)
    REL_RT_LABEL_X := _Clamp(REL_RT_LABEL_X, -g_ctrl_w, g_ctrl_w * 2)
    REL_RT_LABEL_Y := _Clamp(REL_RT_LABEL_Y, -g_ctrl_h, g_ctrl_h * 2)
    REL_LT_LABEL_X := _Clamp(REL_LT_LABEL_X, -g_ctrl_w, g_ctrl_w * 2)
    REL_LT_LABEL_Y := _Clamp(REL_LT_LABEL_Y, -g_ctrl_h, g_ctrl_h * 2)
    REL_BTN_COL0_X := _Clamp(REL_BTN_COL0_X, -g_ctrl_w, g_ctrl_w * 2)
    REL_BTN_COL1_X := _Clamp(REL_BTN_COL1_X, -g_ctrl_w, g_ctrl_w * 2)
    REL_BTN_ROW0_Y := _Clamp(REL_BTN_ROW0_Y, -g_ctrl_h, g_ctrl_h * 2)
    REL_BTN_ROW_PITCH := _Clamp(REL_BTN_ROW_PITCH, 2, g_ctrl_h)
}

_RefreshInteractive() {
    global g_last_report, g_target_idx, g_targets
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h

    _ApplyRelToScreen()
    g_last_report := _BuildReport()
    _SaveReport(g_last_report)
    _ClearOverlays()
    _DrawCalibrationOverlays()

    target := g_targets[g_target_idx]
    radiusStatus := _RelRadiusPlausible() ? "OK (blue box must bound outer breast circle)" : "INVALID (magenta; select RADIUS and click outer edge)"
    txt := "Interactive calibration ON`nTarget: " . target . "`nRadius: " . radiusStatus . "`nF3/F4 target  Drag or arrows nudge  Ctrl+Alt+Click snap  Ctrl+Alt+S save"
    ToolTip, %txt%, % g_ctrl_x + 20, % g_ctrl_y + 20
}

_LoadUserCalibration() {
    global g_loaded_user_calib
    global g_ctrl_w, g_ctrl_h
    global REL_DRAW_X, REL_DRAW_Y, REL_DRAW_W, REL_DRAW_H
    global REL_RT_CX, REL_RT_CY, REL_LT_CX, REL_LT_CY, REL_R
    global REL_RT_LABEL_X, REL_RT_LABEL_Y, REL_LT_LABEL_X, REL_LT_LABEL_Y
    global REL_BTN_COL0_X, REL_BTN_COL1_X, REL_BTN_ROW0_Y, REL_BTN_ROW_PITCH

    iniFile := A_ScriptDir . "\ris_annotate_calib.ini"
    section := _CalibrationSection()
    g_loaded_user_calib := FileExist(iniFile) ? 1 : 0
    if (!g_loaded_user_calib)
        return
    IniRead, probe, %iniFile%, %section%, PX_DRAW_X, __missing__
    if (probe = "__missing__") {
        g_loaded_user_calib := 0
        return
    }

    baseW := _IniReadFloat(iniFile, section, "BASE_CTRL_W", 1155)
    baseH := _IniReadFloat(iniFile, section, "BASE_CTRL_H", 1162)
    if (baseW < 300 || baseH < 300) {
        g_loaded_user_calib := 0
        return
    }
    scaleX := g_ctrl_w / baseW
    scaleY := g_ctrl_h / baseH
    scaleR := (scaleX < scaleY) ? scaleX : scaleY

    REL_DRAW_X := Round(_IniReadFloat(iniFile, section, "PX_DRAW_X", REL_DRAW_X) * scaleX)
    REL_DRAW_Y := Round(_IniReadFloat(iniFile, section, "PX_DRAW_Y", REL_DRAW_Y) * scaleY)
    REL_DRAW_W := Round(_IniReadFloat(iniFile, section, "PX_DRAW_W", REL_DRAW_W) * scaleX)
    REL_DRAW_H := Round(_IniReadFloat(iniFile, section, "PX_DRAW_H", REL_DRAW_H) * scaleY)
    REL_RT_CX := Round(_IniReadFloat(iniFile, section, "PX_RT_CX", REL_RT_CX) * scaleX)
    REL_RT_CY := Round(_IniReadFloat(iniFile, section, "PX_RT_CY", REL_RT_CY) * scaleY)
    REL_LT_CX := Round(_IniReadFloat(iniFile, section, "PX_LT_CX", REL_LT_CX) * scaleX)
    REL_LT_CY := Round(_IniReadFloat(iniFile, section, "PX_LT_CY", REL_LT_CY) * scaleY)
    REL_R := Round(_IniReadFloat(iniFile, section, "PX_R", REL_R) * scaleR)
    REL_RT_LABEL_X := Round(_IniReadFloat(iniFile, section, "PX_RT_LABEL_X", REL_RT_LABEL_X) * scaleX)
    REL_RT_LABEL_Y := Round(_IniReadFloat(iniFile, section, "PX_RT_LABEL_Y", REL_RT_LABEL_Y) * scaleY)
    REL_LT_LABEL_X := Round(_IniReadFloat(iniFile, section, "PX_LT_LABEL_X", REL_LT_LABEL_X) * scaleX)
    REL_LT_LABEL_Y := Round(_IniReadFloat(iniFile, section, "PX_LT_LABEL_Y", REL_LT_LABEL_Y) * scaleY)
    REL_BTN_COL0_X := Round(_IniReadFloat(iniFile, section, "PX_BTN_COL0_X", REL_BTN_COL0_X) * scaleX)
    REL_BTN_COL1_X := Round(_IniReadFloat(iniFile, section, "PX_BTN_COL1_X", REL_BTN_COL1_X) * scaleX)
    REL_BTN_ROW0_Y := Round(_IniReadFloat(iniFile, section, "PX_BTN_ROW0_Y", REL_BTN_ROW0_Y) * scaleY)
    REL_BTN_ROW_PITCH := Round(_IniReadFloat(iniFile, section, "PX_BTN_ROW_PITCH", REL_BTN_ROW_PITCH) * scaleY)
    _ClampRelValues()
    if (!_RelRadiusPlausible()) {
        ; Preserve the user's valid button/label anchors. Repair only the old
        ; nipple-ring radius to the fixed layout's outer-circle proportion.
        dx := REL_LT_CX - REL_RT_CX
        dy := REL_LT_CY - REL_RT_CY
        REL_R := Round(Sqrt(dx ** 2 + dy ** 2) * 0.47)
    }
}

_SaveUserCalibration() {
    global g_loaded_user_calib
    global g_ctrl_w, g_ctrl_h
    global REL_DRAW_X, REL_DRAW_Y, REL_DRAW_W, REL_DRAW_H
    global REL_RT_CX, REL_RT_CY, REL_LT_CX, REL_LT_CY, REL_R
    global REL_RT_LABEL_X, REL_RT_LABEL_Y, REL_LT_LABEL_X, REL_LT_LABEL_Y
    global REL_BTN_COL0_X, REL_BTN_COL1_X, REL_BTN_ROW0_Y, REL_BTN_ROW_PITCH

    if (!_RelRadiusPlausible()) {
        MsgBox, 48, RIS Annotate Calibration, Radius is implausible and was not saved.`n`nSelect RADIUS, then Ctrl+Alt+LeftClick the outer breast-circle edge.
        return
    }

    iniFile := A_ScriptDir . "\ris_annotate_calib.ini"
    section := _CalibrationSection()
    _IniWriteFloat(g_ctrl_w, iniFile, section, "BASE_CTRL_W")
    _IniWriteFloat(g_ctrl_h, iniFile, section, "BASE_CTRL_H")
    _IniWriteFloat(REL_DRAW_X, iniFile, section, "PX_DRAW_X")
    _IniWriteFloat(REL_DRAW_Y, iniFile, section, "PX_DRAW_Y")
    _IniWriteFloat(REL_DRAW_W, iniFile, section, "PX_DRAW_W")
    _IniWriteFloat(REL_DRAW_H, iniFile, section, "PX_DRAW_H")
    _IniWriteFloat(REL_RT_CX, iniFile, section, "PX_RT_CX")
    _IniWriteFloat(REL_RT_CY, iniFile, section, "PX_RT_CY")
    _IniWriteFloat(REL_LT_CX, iniFile, section, "PX_LT_CX")
    _IniWriteFloat(REL_LT_CY, iniFile, section, "PX_LT_CY")
    _IniWriteFloat(REL_R, iniFile, section, "PX_R")
    _IniWriteFloat(REL_RT_LABEL_X, iniFile, section, "PX_RT_LABEL_X")
    _IniWriteFloat(REL_RT_LABEL_Y, iniFile, section, "PX_RT_LABEL_Y")
    _IniWriteFloat(REL_LT_LABEL_X, iniFile, section, "PX_LT_LABEL_X")
    _IniWriteFloat(REL_LT_LABEL_Y, iniFile, section, "PX_LT_LABEL_Y")
    _IniWriteFloat(REL_BTN_COL0_X, iniFile, section, "PX_BTN_COL0_X")
    _IniWriteFloat(REL_BTN_COL1_X, iniFile, section, "PX_BTN_COL1_X")
    _IniWriteFloat(REL_BTN_ROW0_Y, iniFile, section, "PX_BTN_ROW0_Y")
    _IniWriteFloat(REL_BTN_ROW_PITCH, iniFile, section, "PX_BTN_ROW_PITCH")
    g_loaded_user_calib := 1
    ToolTip, Saved calibration [%section%]:`n%iniFile%
    SetTimer, _HideTip, -1800
}

_CalibrationSection() {
    return "Calibration_" . (IsCurrentSessionRDP() ? "rdp" : "local")
}

_RelRadiusPlausible() {
    global REL_RT_CX, REL_RT_CY, REL_LT_CX, REL_LT_CY, REL_R

    dx := REL_LT_CX - REL_RT_CX
    dy := REL_LT_CY - REL_RT_CY
    centerGap := Sqrt(dx ** 2 + dy ** 2)
    if (centerGap < 100)
        return 0

    ; In this fixed Silverlight layout, each outer breast circle is a little
    ; under half of the nipple-to-nipple spacing. Broad limits tolerate scaling
    ; while rejecting the much smaller nipple/areola ring.
    return (REL_R >= centerGap * 0.30 && REL_R <= centerGap * 0.65)
}

_IniReadFloat(iniFile, section, key, defaultValue) {
    IniRead, out, %iniFile%, %section%, %key%, %defaultValue%
    return out + 0
}

_IniWriteFloat(value, iniFile, section, key) {
    v := Round(value)
    IniWrite, %v%, %iniFile%, %section%, %key%
}

_Clamp(v, lo, hi) {
    if (v < lo)
        return lo
    if (v > hi)
        return hi
    return v
}

_WalkAnchors() {
    global REL_RT_LABEL_X, REL_RT_LABEL_Y, REL_LT_LABEL_X, REL_LT_LABEL_Y
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_radius

    points := []
    points.Push({name:"RT text", x:_SX(REL_RT_LABEL_X), y:_SY(REL_RT_LABEL_Y)})
    points.Push({name:"LT text", x:_SX(REL_LT_LABEL_X), y:_SY(REL_LT_LABEL_Y)})
    points.Push({name:"RT nipple", x:g_rt_cx, y:g_rt_cy})
    points.Push({name:"LT nipple", x:g_lt_cx, y:g_lt_cy})
    points.Push({name:"RT 12 edge", x:g_rt_cx, y:g_rt_cy - g_radius})
    points.Push({name:"RT 3 edge", x:g_rt_cx + g_radius, y:g_rt_cy})
    points.Push({name:"RT 6 edge", x:g_rt_cx, y:g_rt_cy + g_radius})
    points.Push({name:"RT 9 edge", x:g_rt_cx - g_radius, y:g_rt_cy})
    Loop, 11 {
        row := A_Index - 1
        points.Push({name:"button row " . row . " col0", x:_ButtonX(0), y:_ButtonY(row)})
        points.Push({name:"button row " . row . " col1", x:_ButtonX(1), y:_ButtonY(row)})
    }
    points.Push({name:"button row 11 col1 bottom eye", x:_ButtonX(1), y:_ButtonY(11)})

    for idx, p in points {
        MouseMove, % p.x, % p.y, 8
        ToolTip, % p.name . "  " . p.x . "," . p.y, % p.x, % p.y
        Sleep, 700
    }
    ToolTip
}

_LesionMoveTest() {
    tests := []
    tests.Push({side:"R", clock:12, dist:3.0, ax:0, name:"R 12/3cm"})
    tests.Push({side:"R", clock:3, dist:3.0, ax:0, name:"R 3/3cm"})
    tests.Push({side:"R", clock:6, dist:3.0, ax:0, name:"R 6/3cm"})
    tests.Push({side:"R", clock:9, dist:3.0, ax:0, name:"R 9/3cm"})
    tests.Push({side:"L", clock:12, dist:3.0, ax:0, name:"L 12/3cm"})
    tests.Push({side:"L", clock:3, dist:3.0, ax:0, name:"L 3/3cm"})
    tests.Push({side:"R", clock:10.5, dist:0, ax:1, name:"R axillary"})
    tests.Push({side:"L", clock:1.5, dist:0, ax:1, name:"L axillary"})

    for idx, t in tests {
        _ClockToXY(t.side, t.clock, t.dist, t.ax, x, y)
        MouseMove, %x%, %y%, 8
        ToolTip, % t.name . " -> " . x . "," . y, %x%, %y%
        Sleep, 1000
    }
    ToolTip
}

_ClockToXY(side, clock, dist_cm, axillary, ByRef outX, ByRef outY) {
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_radius, g_scale

    cx := (side = "R") ? g_rt_cx : g_lt_cx
    cy := (side = "R") ? g_rt_cy : g_lt_cy
    if (axillary) {
        clock := (side = "R") ? 10.5 : 1.5
        dist_px := g_radius * 1.20
    } else {
        dist_px := dist_cm * g_scale
        if (dist_px > g_radius * 0.95)
            dist_px := g_radius * 0.95
    }
    pi := 3.14159265358979
    angle := clock * pi / 6
    outX := Round(cx + dist_px * Sin(angle))
    outY := Round(cy - dist_px * Cos(angle))
}

_ButtonX(col) {
    global REL_BTN_COL0_X, REL_BTN_COL1_X
    return (col = 0) ? _SX(REL_BTN_COL0_X) : _SX(REL_BTN_COL1_X)
}

_ButtonY(row) {
    global REL_BTN_ROW0_Y, REL_BTN_ROW_PITCH
    return _SY(REL_BTN_ROW0_Y) + Round(row * REL_BTN_ROW_PITCH)
}

_SX(relX) {
    global g_ctrl_x
    return Round(g_ctrl_x + relX)
}

_SY(relY) {
    global g_ctrl_y
    return Round(g_ctrl_y + relY)
}

Max(a, b) {
    return (a > b) ? a : b
}

Min(a, b) {
    return (a < b) ? a : b
}

_HideTip:
    ToolTip
return

GuiClose:
GuiEscape:
    _ClearOverlays()
return
