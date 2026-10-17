; ris_annotate.ahk  —  Breast US RIS Annotation Auto-Clicker  (AHK v1)
;
; Workflow:
;   F8  = Calibrate canvas and show dry-run markers (no clicks)
;   F9  = Start full semi-auto annotation from lesions_pending.json
;
; During annotation:
;   F12 = Confirm placement and advance to next lesion
;   F11 = Skip current lesion (no click)
;   F10 = Abort remaining lesions
;
; Clock convention (SAME formula for both breasts, frontal-view diagram):
;   angle = clock * π/6   (12=top, 3=right, 6=bottom, 9=left on screen)
;   x = cx + dist_px * sin(angle)
;   y = cy - dist_px * cos(angle)
;
; Breast radius assumption: BREAST_RADIUS_CM (real cm) maps to g_radius (px).
; Lesions beyond the circle edge are clamped to 95% of radius then offset outward.

#NoEnv
#SingleInstance Force
#Include %A_ScriptDir%\..\..\..\Lib\IsCurrentSessionRDP.ahk
SetBatchLines, -1
CoordMode, Mouse,  Screen
CoordMode, Pixel,  Screen
SetTitleMatchMode, 2

; ── Tunables ──────────────────────────────────────────────────────────────────
global BREAST_RADIUS_CM := 5.5   ; assumed real radius for scale (px/cm = r_px / this)
global PIX_DARK         := 60    ; PixelSearch variation for "black" circle outline
global DBL_CLICK_DELAY  := 550   ; ms: pause between single and double-click
global PLACE_DELAY      := 350   ; ms: pause after each click action

; ── Finding type → button mapping ─────────────────────────────────────────────
; Clinical findings and their button grid positions (row 0-indexed, col 0=left 1=right).
; Button anchors are calibrated from the icon/button upper-left marker; clicking
; that anchor still lands inside the button on the current Silverlight canvas.
;
;   FCC  Fibrocystic change     → clustered dots
;   CYST Simple cyst            → oval ring
;   FA   Fibroadenoma           → solid blue filled circle (solid hypoechoic mass)
;   SUS  Suspicious lesion      → red star (spiculated / BIRADS 4-5)
;   DU   Ductal ectasia         → duct ectasia icon
;   LN   Lymph node             → lymph-node icon
;   SC-H Horizontal scar        → horizontal parallel lines  (mastectomy scar)
;   SC-V Vertical scar          → vertical parallel lines
;   SC-O Oblique scar           → diagonal lines
;
; Visible button inventory from calibrated live canvas:
;   row  0: col0 diagonal hatch large       col1 diagonal hatch small
;   row  1: col0 vertical hatch             col1 horizontal hatch
;   row  2: col0 filled blue circle large   col1 filled blue circle small
;   row  3: col0 red star large             col1 red star small
;   row  4: col0 coarse calcification large col1 coarse calcification small
;   row  5: col0 FCC large                  col1 FCC small
;   row  6: col0 cyst large                 col1 cyst small
;   row  7: col0 duct ectasia horizontal    col1 duct ectasia vertical
;   row  8: col0 oblique scar "/"           col1 oblique scar "\"
;   row  9: col0 intraductal papilloma      col1 complex cyst
;   row 10: col0 duct ectasia               col1 microcalcification
;   row 11: col1 lymph node
;
global BTN_FCC  := {row:  5, col: 0}   ; clustered dots (fibrocystic change)
global BTN_CYST := {row:  6, col: 0}   ; oval ring (simple cyst)
global BTN_FA   := {row:  2, col: 0}   ; large solid blue circle (fibroadenoma)
global BTN_SUS  := {row:  3, col: 0}   ; red star / spiculated (suspicious)
global BTN_DU   := {row: 10, col: 0}   ; generic duct ectasia
global BTN_LN   := {row: 11, col: 1}   ; lymph node
global BTN_SC_H := {row:  7, col: 0}   ; horizontal lines (horizontal scar)
global BTN_SC_V := {row:  7, col: 1}   ; vertical lines   (vertical scar)
global BTN_SC_O := {row:  8, col: 0}   ; diagonal lines   (oblique scar)

; DropDownList choices presented to user (order matters: index 1 = default FCC)
global FIND_TYPES := "FCC|CYST|FA|LN|SC-H|SC-V|SC-O|SUS|DU"

; ── Global state ──────────────────────────────────────────────────────────────
global g_ie_hwnd  := 0
global g_ie_wb    := ""
global g_ie_doc   := ""
global g_host_via_dom := 0
global g_ctrl_x   := 0
global g_ctrl_y   := 0
global g_ctrl_w   := 0
global g_ctrl_h   := 0
global g_view_x   := 0
global g_view_y   := 0
global g_view_w   := 0
global g_view_h   := 0

; Drawing area (white canvas, excluding tabs and button column)
global g_draw_x   := 0
global g_draw_y   := 0
global g_draw_w   := 0
global g_draw_h   := 0

; Calibrated circle geometry (screen coords)
global g_rt_cx    := 0    ; RT nipple center x
global g_rt_cy    := 0
global g_lt_cx    := 0    ; LT nipple center x
global g_lt_cy    := 0
global g_radius   := 0    ; average radius in px
global g_scale    := 0    ; px per cm

; Button grid anchor (screen coords)
global g_btn_c0x  := 0    ; col-0 button center x
global g_btn_c1x  := 0    ; col-1 button center x
global g_btn_r0y  := 0    ; row-0 button center y
global g_btn_rh   := 0    ; row height in px
global g_loaded_user_calib := 0

; Lesion queue
global g_lesions  := []
global g_current  := 1
global g_running  := 0
global g_rev_result := ""
global g_xml_before := ""
global g_expected_accession := ""

; ── Entry hotkeys ─────────────────────────────────────────────────────────────
F8::
    if !_FindIEWindow()
        return
    if !_Calibrate()
        return
    _DryRun()
return

F9::
    if g_running {
        MsgBox, 48, Running, Annotation in progress.`nUse F12 / F11 / F10.
        return
    }
    _RunAnnotation()
return

; ── Main workflow ──────────────────────────────────────────────────────────────
_RunAnnotation() {
    global g_running, g_current, g_lesions

    if !_FindIEWindow() {
        MsgBox, 16, Error, IE annotation window not found.`n`nLook for a window containing SilverlightControlHost.
        return
    }

    ToolTip, Calibrating canvas...
    if !_Calibrate() {
        ToolTip
        MsgBox, 16, Calibration failed, Could not locate breast circles.`nEnsure the annotation canvas is visible and unobstructed.
        return
    }
    ToolTip

    jsonFile := (A_Args.Length() >= 1) ? A_Args[1] : A_ScriptDir . "\lesions_pending.json"
    if !FileExist(jsonFile) {
        MsgBox, 16, No data, lesions_pending.json not found.`n`nRun export_lesions.py to generate it from the Ubuntu DB.
        return
    }
    if !_LoadLesions(jsonFile) {
        MsgBox, 16, Error, Could not parse lesions_pending.json.
        return
    }
    if !_VerifyStudyMatch(1)
        return
    if !g_lesions.Length() {
        MsgBox, 64, No lesions, No lesions found in the JSON file.
        return
    }

    if !_ShowReviewGUI()
        return

    g_running := 1
    g_current := 1
    _RegisterHotkeys(1)
    _ProcessNext()
}

; ── IE window detection ────────────────────────────────────────────────────────
_FindIEWindow() {
    global g_ie_hwnd, g_ie_wb, g_ie_doc, g_host_via_dom
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global g_view_x, g_view_y, g_view_w, g_view_h

    ; Current RIS pages commonly host Silverlight in windowless mode, where no
    ; SilverlightControlHost HWND exists. Prefer the DOM object rectangle.
    if (_FindIEWindowViaDom())
        return 1

    ; Legacy fallback for pages that expose a native Silverlight child HWND.
    WinGet, hwndList, List, ahk_class IEFrame
    loop % hwndList {
        hwnd := hwndList%A_Index%
        ControlGetPos, cx, cy, cw, ch, SilverlightControlHost, ahk_id %hwnd%
        if (cw > 200 && ch > 200) {
            g_ie_hwnd := hwnd
            g_ie_wb := ""
            g_ie_doc := ""
            g_host_via_dom := 0
            WinActivate, ahk_id %hwnd%
            Sleep, 300
            ; Use GetWindowRect on the Silverlight control hwnd for exact screen coords
            ControlGet, ctrlHwnd, Hwnd,, SilverlightControlHost, ahk_id %hwnd%
            if ctrlHwnd {
                VarSetCapacity(rc, 16, 0)
                DllCall("GetWindowRect", "Ptr", ctrlHwnd, "Ptr", &rc)
                g_ctrl_x := NumGet(rc, 0, "Int")
                g_ctrl_y := NumGet(rc, 4, "Int")
                g_ctrl_w := NumGet(rc, 8, "Int") - g_ctrl_x
                g_ctrl_h := NumGet(rc, 12, "Int") - g_ctrl_y
            } else {
                ; Fallback: window pos + ControlGetPos offset (less accurate)
                WinGetPos, wx, wy,,, ahk_id %hwnd%
                g_ctrl_x := wx + cx
                g_ctrl_y := wy + cy
                g_ctrl_w := cw
                g_ctrl_h := ch
            }
            g_view_x := g_ctrl_x
            g_view_y := g_ctrl_y
            g_view_w := g_ctrl_w
            g_view_h := g_ctrl_h
            _BindIEAutomation(hwnd)
            return 1
        }
    }
    MsgBox, 16, Not found, No RIS IE report page containing the Silverlight breast diagram was found.
    return 0
}

_FindIEWindowViaDom() {
    global g_ie_hwnd, g_ie_wb, g_ie_doc, g_host_via_dom
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global g_view_x, g_view_y, g_view_w, g_view_h

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
        g_ie_wb := wb
        g_ie_doc := doc
        g_host_via_dom := 1
        ; getBoundingClientRect() is already viewport-relative. Subtracting the
        ; document scroll here would double-apply scrolling and misplace clicks.
        g_ctrl_x := Round(serverX + left * scaleX)
        g_ctrl_y := Round(serverY + top * scaleY)
        g_ctrl_w := Round(width * scaleX)
        g_ctrl_h := Round(height * scaleY)
        g_view_x := serverX
        g_view_y := serverY
        g_view_w := serverW
        g_view_h := serverH

        WinActivate, ahk_id %hwnd%
        Sleep, 200
        return 1
    }
    return 0
}

_BindIEAutomation(hwnd) {
    global g_ie_wb, g_ie_doc
    shell := ComObjCreate("Shell.Application")
    for wb in shell.Windows {
        try wbHwnd := wb.HWND
        catch
            continue
        if (wbHwnd != hwnd)
            continue
        try doc := wb.Document
        catch
            continue
        g_ie_wb := wb
        g_ie_doc := doc
        return 1
    }
    return 0
}

; ── Canvas calibration ─────────────────────────────────────────────────────────
_Calibrate() {
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global g_draw_x, g_draw_y, g_draw_w, g_draw_h
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_radius, g_scale
    global g_btn_c0x, g_btn_c1x, g_btn_r0y, g_btn_rh
    global BREAST_RADIUS_CM
    global g_loaded_user_calib

    ; ── Drawing area (from image analysis: proportional to ctrl size) ─────────
    ; Tab bar  ≈ 7.5% of ctrl height
    ; Left/bottom border ≈ 1.5%
    ; Button column ≈ rightmost 17% of ctrl width
    g_draw_x := Round(g_ctrl_x + g_ctrl_w * 0.015)
    g_draw_y := Round(g_ctrl_y + g_ctrl_h * 0.075)
    g_draw_w := Round(g_ctrl_w * 0.825)
    g_draw_h := Round(g_ctrl_h * 0.910)

    ; ── Button grid ───────────────────────────────────────────────────────────
    ; Col-0 center x ≈ 89.3%, col-1 ≈ 95.2% of ctrl width
    ; Row-0 center y ≈ 12.7% of ctrl height; row pitch ≈ 7.6%
    g_btn_c0x := Round(g_ctrl_x + g_ctrl_w * 0.893)
    g_btn_c1x := Round(g_ctrl_x + g_ctrl_w * 0.952)
    g_btn_r0y  := Round(g_ctrl_y + g_ctrl_h * 0.127)
    g_btn_rh   := Round(g_ctrl_h * 0.076)

    if (_LoadUserCalibration()) {
        if (_CalibrationGeometryPlausible())
            return 1
        ; Never use a saved nipple/areola radius as the breast radius.
        g_loaded_user_calib := 0
    }

    ; ── Detect circles via PixelSearch ───────────────────────────────────────
    ; Drawing area is split into left half (RT) and right half (LT).
    drawMidX := g_draw_x + g_draw_w // 2

    ; RT circle: scan hint x at ~35% of draw width
    rtHintX := g_draw_x + Round(g_draw_w * 0.355)
    yBot_draw := g_draw_y + g_draw_h
    found_rt := _ScanCircle(rtHintX, g_draw_x, drawMidX, g_draw_y, yBot_draw, rt_cx, rt_cy, rt_r)
    if !found_rt {
        rt_cx := g_draw_x + Round(g_draw_w * 0.355)
        rt_cy := g_draw_y + Round(g_draw_h * 0.242)
        rt_r  := Round(g_draw_w * 0.187)
    }

    ; LT circle: scan hint x at ~68% of draw width
    ltHintX := g_draw_x + Round(g_draw_w * 0.685)
    found_lt := _ScanCircle(ltHintX, drawMidX, g_draw_x + g_draw_w, g_draw_y, yBot_draw, lt_cx, lt_cy, lt_r)
    if !found_lt {
        lt_cx := g_draw_x + Round(g_draw_w * 0.685)
        lt_cy := g_draw_y + Round(g_draw_h * 0.242)
        lt_r  := Round(g_draw_w * 0.181)
    }

    g_rt_cx  := rt_cx
    g_rt_cy  := rt_cy
    g_lt_cx  := lt_cx
    g_lt_cy  := lt_cy
    g_radius := Round((rt_r + lt_r) / 2)
    g_scale  := g_radius / BREAST_RADIUS_CM   ; px per cm

    return _CalibrationGeometryPlausible()
}

_CalibrationGeometryPlausible() {
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_radius

    dx := g_lt_cx - g_rt_cx
    dy := g_lt_cy - g_rt_cy
    centerGap := Sqrt(dx ** 2 + dy ** 2)
    if (centerGap < 100)
        return 0

    ; The outer breast radius is approximately half of the distance between
    ; nipple centers. These broad limits reject the small nipple ring while
    ; remaining tolerant of DPI and host-size scaling.
    return (g_radius >= centerGap * 0.30 && g_radius <= centerGap * 0.65)
}

_LoadUserCalibration() {
    global g_loaded_user_calib
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global g_draw_x, g_draw_y, g_draw_w, g_draw_h
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_radius, g_scale
    global g_btn_c0x, g_btn_c1x, g_btn_r0y, g_btn_rh
    global BREAST_RADIUS_CM

    iniFile := A_ScriptDir . "\ris_annotate_calib.ini"
    if !FileExist(iniFile) {
        g_loaded_user_calib := 0
        return 0
    }

    section := IsCurrentSessionRDP() ? "Calibration_rdp" : "Calibration_local"
    IniRead, probe, %iniFile%, %section%, PX_RT_CX, __missing__
    if (probe = "__missing__") {
        g_loaded_user_calib := 0
        return 0
    }

    ; Saved calibration values are host-relative screen pixels. Scale them from
    ; the host size used during calibration to today's live DOM/HWND rectangle.
    ; Legacy Calibration_rdp was captured against a 1155x1162 host.
    baseW := _IniReadFloat(iniFile, section, "BASE_CTRL_W", 1155)
    baseH := _IniReadFloat(iniFile, section, "BASE_CTRL_H", 1162)
    if (baseW < 300 || baseH < 300) {
        g_loaded_user_calib := 0
        return 0
    }
    scaleX := g_ctrl_w / baseW
    scaleY := g_ctrl_h / baseH
    scaleR := (scaleX < scaleY) ? scaleX : scaleY
    if (scaleX < 0.35 || scaleX > 3.0 || scaleY < 0.35 || scaleY > 3.0) {
        g_loaded_user_calib := 0
        return 0
    }

    pxDrawX := _IniReadFloat(iniFile, section, "PX_DRAW_X", g_draw_x - g_ctrl_x) * scaleX
    pxDrawY := _IniReadFloat(iniFile, section, "PX_DRAW_Y", g_draw_y - g_ctrl_y) * scaleY
    g_draw_x := g_ctrl_x + Round(pxDrawX)
    g_draw_y := g_ctrl_y + Round(pxDrawY)
    g_draw_w := Round(_IniReadFloat(iniFile, section, "PX_DRAW_W", g_draw_w) * scaleX)
    g_draw_h := Round(_IniReadFloat(iniFile, section, "PX_DRAW_H", g_draw_h) * scaleY)

    g_rt_cx := g_ctrl_x + Round(_IniReadFloat(iniFile, section, "PX_RT_CX", g_rt_cx - g_ctrl_x) * scaleX)
    g_rt_cy := g_ctrl_y + Round(_IniReadFloat(iniFile, section, "PX_RT_CY", g_rt_cy - g_ctrl_y) * scaleY)
    g_lt_cx := g_ctrl_x + Round(_IniReadFloat(iniFile, section, "PX_LT_CX", g_lt_cx - g_ctrl_x) * scaleX)
    g_lt_cy := g_ctrl_y + Round(_IniReadFloat(iniFile, section, "PX_LT_CY", g_lt_cy - g_ctrl_y) * scaleY)
    g_radius := Round(_IniReadFloat(iniFile, section, "PX_R", g_radius) * scaleR)
    g_scale := g_radius / BREAST_RADIUS_CM

    g_btn_c0x := g_ctrl_x + Round(_IniReadFloat(iniFile, section, "PX_BTN_COL0_X", g_btn_c0x - g_ctrl_x) * scaleX)
    g_btn_c1x := g_ctrl_x + Round(_IniReadFloat(iniFile, section, "PX_BTN_COL1_X", g_btn_c1x - g_ctrl_x) * scaleX)
    g_btn_r0y := g_ctrl_y + Round(_IniReadFloat(iniFile, section, "PX_BTN_ROW0_Y", g_btn_r0y - g_ctrl_y) * scaleY)
    g_btn_rh := Round(_IniReadFloat(iniFile, section, "PX_BTN_ROW_PITCH", g_btn_rh) * scaleY)

    g_loaded_user_calib := 1
    return 1
}

_IniReadFloat(iniFile, section, key, defaultValue) {
    IniRead, val, %iniFile%, %section%, %key%, %defaultValue%
    return val + 0
}

; Scan for the bounding box of a circle within [xLeft,xRight] × [yTop,yBottom].
; Returns 1 on success; sets cx, cy, r ByRef.
_ScanCircle(hintX, xLeft, xRight, yTop, yBottom, ByRef cx, ByRef cy, ByRef r) {
    global PIX_DARK

    ; Find topmost dark pixel at hintX, scanning downward
    topY := ""
    loop % (yBottom - yTop) {
        y := yTop + A_Index - 1
        PixelGetColor, col, hintX, y, RGB
        r_ch := (col >> 16) & 0xFF
        if (r_ch < PIX_DARK) {
            topY := y
            break
        }
    }
    if (topY = "")
        return 0

    ; Find bottommost dark pixel at hintX, scanning upward
    botY := ""
    loop % (yBottom - yTop) {
        y := yBottom - A_Index + 1
        PixelGetColor, col, hintX, y, RGB
        r_ch := (col >> 16) & 0xFF
        if (r_ch < PIX_DARK) {
            botY := y
            break
        }
    }
    if (botY = "")
        return 0

    midY := (topY + botY) // 2

    ; Find leftmost dark pixel at midY, scanning right-to-left within [xLeft, xRight]
    leftX := ""
    loop % (xRight - xLeft) {
        x := xLeft + A_Index - 1
        PixelGetColor, col, x, midY, RGB
        r_ch := (col >> 16) & 0xFF
        if (r_ch < PIX_DARK) {
            leftX := x
            break
        }
    }
    if (leftX = "")
        return 0

    ; Find rightmost dark pixel at midY, scanning left-to-right from xRight
    rightX := ""
    loop % (xRight - xLeft) {
        x := xRight - A_Index + 1
        PixelGetColor, col, x, midY, RGB
        r_ch := (col >> 16) & 0xFF
        if (r_ch < PIX_DARK) {
            rightX := x
            break
        }
    }
    if (rightX = "")
        return 0

    cx := (leftX + rightX) // 2
    cy := (topY  + botY)   // 2
    r  := (rightX - leftX) // 2
    return 1
}

; ── Coordinate mapping ─────────────────────────────────────────────────────────
; Convert breast clock position to screen coordinates.
;
; The clock face is viewed from the FRONT for both breasts:
;   angle = clock * π/6  (12=top, 3=right, 6=bottom, 9=left on screen)
;   x = cx + dist_px * sin(angle)
;   y = cy - dist_px * cos(angle)
;
; Anatomical note: for RT breast 3=medial, 9=lateral; for LT 3=lateral, 9=medial.
; This has NO effect on the screen formula — only the circle center (cx,cy) differs.
;
; Axillary nodes are placed outside the circle at the UOQ direction:
;   RT axillary → clock 10.5 (upper-left of RT circle)
;   LT axillary → clock  1.5 (upper-right of LT circle)
_ClockToXY(side, clock_avg, dist_cm, axillary, ByRef outX, ByRef outY) {
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_radius, g_scale

    cx := (side = "R") ? g_rt_cx : g_lt_cx
    cy := (side = "R") ? g_rt_cy : g_lt_cy

    if axillary {
        ; Place outside circle at UOQ angle
        clock_avg := (side = "R") ? 10.5 : 1.5
        dist_cm   := (g_radius / g_scale) * 1.20   ; 20% beyond edge
    }

    dist_px  := dist_cm * g_scale
    ; Clamp to 95% of radius if inside-circle placement is needed
    if (!axillary && dist_px > g_radius * 0.95)
        dist_px := g_radius * 0.95

    pi       := 3.14159265358979
    angle    := clock_avg * pi / 6
    outX     := Round(cx + dist_px * Sin(angle))
    outY     := Round(cy - dist_px * Cos(angle))
}

; ── JSON lesion loader ─────────────────────────────────────────────────────────
_LoadLesions(jsonFile) {
    global g_lesions, g_expected_accession
    g_lesions := []
    g_expected_accession := ""

    FileRead, raw, %jsonFile%
    if ErrorLevel
        return 0

    if RegExMatch(raw, """accession""\s*:\s*""?(\d{10,15})""?", accM)
        g_expected_accession := accM1
    if (g_expected_accession = "")
        return 0

    ; Extract the lesions array content between [ and ]
    if !RegExMatch(raw, """lesions""\s*:\s*\[([^]]+)\]", m)
        return 0
    arrContent := m1

    ; Parse each { ... } object
    startPos := 1
    while (matchPos := RegExMatch(arrContent, "\{([^}]+)\}", objM, startPos)) {
        obj      := objM1
        startPos := matchPos + StrLen(objM0)   ; advance past this match

        les          := {}
        les.side          := _JStr(obj, "side")
        les.side_hint     := _JStr(obj, "side_hint")
        les.side_inferred := (_JBool(obj, "side_inferred") = 1)
        les.region        := _JStr(obj, "region")
        les.clock_s       := _JNum(obj, "clock_start")
        les.clock_e       := _JNum(obj, "clock_end")
        les.dist_cm       := _JNum(obj, "dist_cm")
        les.max_mm        := _JNum(obj, "max_dim_mm")
        les.dims_text     := _JStr(obj, "dims_text")
        les.type          := _JStr(obj, "type")
        les.flags_text    := _JStr(obj, "flags_text")
        les.axillary      := (_JBool(obj, "axillary") = 1 || les.region = "AX" || les.type = "LN")
        if (les.type = "")
            les.type := "FCC"
        if (les.side_hint = "")
            les.side_hint := les.side
        les.include := 1   ; default: include (may be overridden by Review GUI)
        if (les.side = "")
            continue

        ; Clock average (handle clock_end = null)
        if (les.clock_e != "")
            les.clock_avg := (les.clock_s + les.clock_e) / 2
        else
            les.clock_avg := les.clock_s

        ; Handle 12→0 wrap (e.g. 11-1 o'clock avg = 12)
        ; avg of 11 and 1 = 12, but naive avg = 6 → fix via modular arithmetic
        if (les.clock_e != "") {
            a := les.clock_s, b := les.clock_e
            if Abs(b - a) > 6
                les.clock_avg := Mod((a + b + 12) / 2, 12)
            if (les.clock_avg = 0)
                les.clock_avg := 12
        }

        _FinalizeLesion(les)

        g_lesions.Push(les)
    }
    return 1
}

_JStr(obj, key) {
    if RegExMatch(obj, """" . key . """\s*:\s*""([^""]*?)""", m)
        return m1
    return ""
}

_JNum(obj, key) {
    if RegExMatch(obj, """" . key . """\s*:\s*(null|-?[\d.]+)", m) {
        if (m1 = "null" || m1 = "")
            return ""
        return m1 + 0
    }
    return ""
}

_JBool(obj, key) {
    if RegExMatch(obj, """" . key . """\s*:\s*(true|false)", m)
        return (m1 = "true") ? 1 : 0
    return 0
}

; ── Review GUI ──────────────────────────────────────────────────────────────────
_ShowReviewGUI() {
    global g_lesions, g_rev_result, g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_radius

    g_rev_result := ""
    n := g_lesions.Length()

    calibTxt := "RT nipple: (" . g_rt_cx . "," . g_rt_cy . ")   LT nipple: (" . g_lt_cx . "," . g_lt_cy . ")   r=" . g_radius . "px"

    Gui, Review:Destroy
    Gui, Review:+AlwaysOnTop
    Gui, Review:Font, s9, Segoe UI
    Gui, Review:Add, Text,, Calibration: %calibTxt%
    Gui, Review:Add, Text,, `n%n% lesions — ratify side, type, and Include for each:
    Gui, Review:Add, Text, cBlue, R? = inferred from frame sequence. ? must be changed to R/L before placement.

    loop % n {
        i        := A_Index
        les      := g_lesions[i]
        lesLabel := les.label

        ; Map current type hint to DDL index (1=FCC default)
        choiceIdx := 1
        if (les.type = "CYST") choiceIdx := 2
        if (les.type = "FA")   choiceIdx := 3
        if (les.type = "LN")   choiceIdx := 4
        if (les.type = "SC-H") choiceIdx := 5
        if (les.type = "SC-V") choiceIdx := 6
        if (les.type = "SC-O") choiceIdx := 7
        if (les.type = "SUS")  choiceIdx := 8
        if (les.type = "DU")   choiceIdx := 9

        sideIdx := 3
        if (les.side = "R")
            sideIdx := 1
        if (les.side = "L")
            sideIdx := 2

        labelLine := "[" . i . "] " . lesLabel . "  hint=" . les.side_hint . "  flags=" . les.flags_text
        Gui, Review:Add, Text,         xm        w520, %labelLine%
        Gui, Review:Add, DropDownList, xm   w55  vRevSide%i% Choose%sideIdx%, R|L|?
        Gui, Review:Add, DropDownList, x+8  yp   w120 vRevType%i% Choose%choiceIdx%, FCC|CYST|FA|LN|SC-H|SC-V|SC-O|SUS|DU
        Gui, Review:Add, Edit,         x+8  yp   w55  vRevClockS%i%, % les.clock_s
        Gui, Review:Add, Edit,         x+8  yp   w55  vRevClockE%i%, % les.clock_e
        Gui, Review:Add, Edit,         x+8  yp   w60  vRevDist%i%, % les.dist_cm
        Gui, Review:Add, Edit,         x+8  yp   w60  vRevMax%i%, % les.max_mm
        Gui, Review:Add, CheckBox,     x+8  yp+3 vRevIncl%i% Checked,
    }

    Gui, Review:Add, Text,, `nHotkeys during annotation:
    Gui, Review:Add, Text, cGreen, F12 = Confirm && place
    Gui, Review:Add, Text, cBlue,  F11 = Skip this lesion
    Gui, Review:Add, Text, cRed,   F10 = Abort all remaining
    Gui, Review:Add, Button, gRevProceed Default w120, Proceed
    Gui, Review:Add, Button, gRevCancel  w80,          Cancel
    Gui, Review:Show,, Breast US Annotation

    loop {
        Sleep, 80
        if (g_rev_result != "")
            break
    }
    Gui, Review:Destroy
    return (g_rev_result = "proceed")
}

RevProceed:
    global g_lesions, g_rev_result
    n2 := g_lesions.Length()
    Gui, Review:Submit, NoHide
    loop % n2 {
        i       := A_Index
        tVar    := "RevType" . i
        sideVar := "RevSide" . i
        csVar   := "RevClockS" . i
        ceVar   := "RevClockE" . i
        distVar := "RevDist" . i
        maxVar  := "RevMax" . i
        inclVar := "RevIncl" . i
        include := %inclVar%
        side := %sideVar%
        clockSRaw := Trim(%csVar%)
        clockERaw := Trim(%ceVar%)
        distRaw := Trim(%distVar%)
        maxRaw := Trim(%maxVar%)
        if (include) {
            if !(side = "R" || side = "L") {
                MsgBox, 48, Side required, Lesion %i% needs an explicit R or L side, or uncheck Include.
                return
            }
            if (!g_lesions[i].axillary) {
                if (!_IsNumericText(clockSRaw) || clockSRaw + 0 < 1 || clockSRaw + 0 > 12) {
                    MsgBox, 48, Clock required, Lesion %i% needs a clock value from 1 through 12.
                    return
                }
                if (clockERaw != "" && (!_IsNumericText(clockERaw) || clockERaw + 0 < 1 || clockERaw + 0 > 12)) {
                    MsgBox, 48, Invalid clock, Lesion %i% has an invalid ending clock. Use 1 through 12 or leave it blank.
                    return
                }
                if (!_IsNumericText(distRaw) || distRaw + 0 <= 0 || distRaw + 0 > 20) {
                    MsgBox, 48, Distance required, Lesion %i% needs a nipple distance greater than 0 and no more than 20 cm.
                    return
                }
            }
            if (!_IsNumericText(maxRaw) || maxRaw + 0 <= 0 || maxRaw + 0 > 200) {
                MsgBox, 48, Size required, Lesion %i% needs a maximum size greater than 0 and no more than 200 mm.
                return
            }
        }
        g_lesions[i].type    := %tVar%
        g_lesions[i].side    := side
        g_lesions[i].include := include
        g_lesions[i].clock_s := (clockSRaw = "") ? "" : clockSRaw + 0
        g_lesions[i].clock_e := (clockERaw = "") ? "" : clockERaw + 0
        g_lesions[i].dist_cm := (distRaw = "") ? "" : distRaw + 0
        g_lesions[i].max_mm  := (maxRaw = "") ? "" : maxRaw + 0
        _FinalizeLesion(g_lesions[i])
    }
    g_rev_result := "proceed"
return

RevCancel:
    global g_rev_result
    g_rev_result := "cancel"
return

; ── Semi-auto annotation loop ───────────────────────────────────────────────────
_ProcessNext() {
    global g_lesions, g_current, g_running, g_ie_hwnd

    ; Advance past any lesions the user unchecked in the Review GUI
    while (g_current <= g_lesions.Length() && g_lesions[g_current].include = 0)
        g_current++

    if (g_current > g_lesions.Length()) {
        g_running := 0
        _RegisterHotkeys(0)
        ToolTip
        n := g_lesions.Length()
        MsgBox, 64, Done, All %n% lesions processed.
        return
    }

    les := g_lesions[g_current]
    _ClockToXY(les.side, les.clock_avg, les.dist_cm, les.axillary, tgtX, tgtY)

    ; Preview must not alter Silverlight state. Button selection is deferred
    ; until F12, after a fresh geometry and XML-baseline check.
    if !_EnsurePlacementVisible(les.type, tgtX, tgtY, 1)
        return

    ; Move mouse to target position so user can verify before confirming
    WinActivate, ahk_id %g_ie_hwnd%
    Sleep, 150
    MouseMove, %tgtX%, %tgtY%, 8

    n        := g_lesions.Length()
    lesLabel := les.label
    ToolTip, [%g_current%/%n%] %lesLabel%`nF12=Place  F11=Skip  F10=Abort, %tgtX%, %tgtY%
}

_FinalizeLesion(ByRef les) {
    if (les.clock_e != "")
        les.clock_avg := (les.clock_s + les.clock_e) / 2
    else
        les.clock_avg := les.clock_s

    if (les.clock_e != "") {
        a := les.clock_s, b := les.clock_e
        if Abs(b - a) > 6
            les.clock_avg := Mod((a + b + 12) / 2, 12)
        if (les.clock_avg = 0)
            les.clock_avg := 12
    }

    clockStr := (les.clock_e != "") ? (_FmtNum(les.clock_s) . "-" . _FmtNum(les.clock_e)) : _FmtNum(les.clock_s)
    dimStr := (les.dims_text != "") ? les.dims_text : _FmtNum(les.max_mm)
    les.label := les.side . " " . clockStr . "/" . _FmtNum(les.dist_cm) . ", " . dimStr . "mm"
    if les.axillary
        les.label := les.side . " axillary, " . dimStr . "mm"
}

_FmtNum(v) {
    if (v = "")
        return ""
    v := Round(v + 0, 1)
    if (Mod(v, 1) = 0)
        return Round(v)
    return v
}

_IsNumericText(value) {
    return RegExMatch(Trim(value), "^-?(?:\d+(?:\.\d*)?|\.\d+)$")
}

_PlaceCurrent() {
    global g_lesions, g_current, g_ie_hwnd, g_running, g_xml_before

    les := g_lesions[g_current]

    ; The user may have scrolled or resized IE after preview. Reacquire the DOM
    ; rectangle and rescale calibration before any real click.
    if !_FindIEWindow()
        return
    if !_VerifyStudyMatch(1)
        return
    if !_Calibrate() {
        MsgBox, 16, Calibration failed, Could not refresh the live breast-diagram geometry. No click was sent.
        return
    }
    _ClockToXY(les.side, les.clock_avg, les.dist_cm, les.axillary, tgtX, tgtY)
    if !_EnsurePlacementVisible(les.type, tgtX, tgtY, 1)
        return

    g_xml_before := _GetCanvasXML()
    if (g_xml_before = "") {
        MsgBox, 16, Verification unavailable, Could not read the Silverlight canvas XML. No click was sent.`n`nReload the report page and try F12 again.
        return
    }

    if !_SelectButton(les.type)
        return

    WinActivate, ahk_id %g_ie_hwnd%
    Sleep, 150

    ; Single click to place the marker
    Click, %tgtX%, %tgtY%
    Sleep, %PLACE_DELAY%

    ; Double-click on the placed marker to open the text label box
    Click, %tgtX%, %tgtY%, 2
    Sleep, %DBL_CLICK_DELAY%

    ; Type the label and confirm
    lesLabel := les.label
    SendInput, ^a
    Sleep, 80
    SendInput, %lesLabel%
    Sleep, 200
    Send, {Enter}
    Sleep, 200

    xmlAfter := ""
    Loop, 10 {
        xmlAfter := _GetCanvasXML()
        if _VerifyPlacementXML(g_xml_before, xmlAfter, lesLabel, loopDetail)
            break
        Sleep, 150
    }
    if !_VerifyPlacementXML(g_xml_before, xmlAfter, lesLabel, verifyDetail) {
        g_running := 0
        _RegisterHotkeys(0)
        ToolTip
        MsgBox, 16, Placement not verified, The RIS canvas did not confirm the expected marker and label.`n`n%verifyDetail%`n`nThe run has stopped. Inspect the canvas and remove any partial/duplicate marker manually before restarting.
        return
    }

    ToolTip
    g_current++
    _ProcessNext()
}

_SkipCurrent() {
    global g_current
    ToolTip
    g_current++
    _ProcessNext()
}

_AbortAll() {
    global g_running
    g_running := 0
    _RegisterHotkeys(0)
    ToolTip
    c := g_current
    MsgBox, 64, Aborted, Annotation aborted at lesion %c%.
}

; ── Button selection ───────────────────────────────────────────────────────────
_SelectButton(lesType) {
    global g_btn_c0x, g_btn_c1x, g_btn_r0y, g_btn_rh, g_ie_hwnd
    global BTN_FCC, BTN_CYST, BTN_FA, BTN_SUS, BTN_DU, BTN_LN, BTN_SC_H, BTN_SC_V, BTN_SC_O

    _ButtonPoint(lesType, bx, by)
    if !_PointVisible(bx, by) {
        MsgBox, 48, Button not visible, The %lesType% button is outside the visible IE report area. No click was sent.`n`nScroll the breast diagram into view and press F12 again.
        return 0
    }

    WinActivate, ahk_id %g_ie_hwnd%
    Sleep, 100
    Click, %bx%, %by%
    Sleep, 200
    return 1
}

_ButtonPoint(lesType, ByRef bx, ByRef by) {
    global g_btn_c0x, g_btn_c1x, g_btn_r0y, g_btn_rh
    global BTN_FCC, BTN_CYST, BTN_FA, BTN_SUS, BTN_DU, BTN_LN, BTN_SC_H, BTN_SC_V, BTN_SC_O

    btn := BTN_FCC
    if (lesType = "CYST") btn := BTN_CYST
    if (lesType = "FA")   btn := BTN_FA
    if (lesType = "LN")   btn := BTN_LN
    if (lesType = "SUS")  btn := BTN_SUS
    if (lesType = "DU")   btn := BTN_DU
    if (lesType = "SC-H") btn := BTN_SC_H
    if (lesType = "SC-V") btn := BTN_SC_V
    if (lesType = "SC-O") btn := BTN_SC_O
    bx := (btn.col = 0) ? g_btn_c0x : g_btn_c1x
    by := g_btn_r0y + btn.row * g_btn_rh
}

_EnsurePlacementVisible(lesType, tgtX, tgtY, showMessage := 0) {
    _ButtonPoint(lesType, bx, by)
    targetOK := _PointVisible(tgtX, tgtY)
    buttonOK := _PointVisible(bx, by)
    if (targetOK && buttonOK)
        return 1
    if (showMessage) {
        missing := !targetOK ? "lesion target" : "finding button"
        MsgBox, 48, Diagram clipped, The %missing% is outside the visible IE report area. No click was sent.`n`nScroll the breast diagram into view, then retry the preview/F12 action.
    }
    return 0
}

_PointVisible(x, y) {
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global g_view_x, g_view_y, g_view_w, g_view_h
    margin := 4
    inHost := (x >= g_ctrl_x + margin && x <= g_ctrl_x + g_ctrl_w - margin
        && y >= g_ctrl_y + margin && y <= g_ctrl_y + g_ctrl_h - margin)
    inView := (x >= g_view_x + margin && x <= g_view_x + g_view_w - margin
        && y >= g_view_y + margin && y <= g_view_y + g_view_h - margin)
    return (inHost && inView)
}

_GetCanvasXML() {
    global g_ie_hwnd, g_ie_doc
    if !IsObject(g_ie_doc) {
        if !_BindIEAutomation(g_ie_hwnd)
            return ""
    }
    try xml := g_ie_doc.parentWindow.eval("appHost.Content.MainPage.GetXML()")
    catch
        return ""
    return "" . xml
}

_GetLiveAccession() {
    global g_ie_hwnd, g_ie_doc
    if !IsObject(g_ie_doc) {
        if !_BindIEAutomation(g_ie_hwnd)
            return ""
    }
    try nodes := g_ie_doc.getElementsByName("referno")
    catch
        return ""
    if (!IsObject(nodes) || nodes.length < 1)
        return ""
    try value := nodes.item(0).value
    catch
        return ""
    RegExMatch("" . value, "\d{10,15}", m)
    return m
}

_VerifyStudyMatch(showMessage := 0) {
    global g_expected_accession
    liveAccession := _GetLiveAccession()
    if (g_expected_accession != "" && liveAccession = g_expected_accession)
        return 1
    if (showMessage) {
        expectedText := (g_expected_accession = "") ? "unavailable" : g_expected_accession
        liveText := (liveAccession = "") ? "unavailable" : liveAccession
        MsgBox, 16, Study mismatch, No click was sent because the reviewed OCR study does not match the open RIS report.`n`nReviewed accession: %expectedText%`nOpen RIS accession: %liveText%
    }
    return 0
}

_VerifyPlacementXML(xmlBefore, xmlAfter, expectedLabel, ByRef detail) {
    if (xmlAfter = "") {
        detail := "Canvas XML became unavailable after the click."
        return 0
    }
    if (xmlAfter = xmlBefore) {
        detail := "Canvas XML did not change."
        return 0
    }
    RegExReplace(xmlBefore, "<Canvas(?:\s|>)", "", beforeCanvases)
    RegExReplace(xmlAfter, "<Canvas(?:\s|>)", "", afterCanvases)
    if (afterCanvases <= beforeCanvases) {
        detail := "Marker count did not increase (before=" . beforeCanvases . ", after=" . afterCanvases . ")."
        return 0
    }
    StrReplace(xmlBefore, expectedLabel, "", beforeLabels)
    StrReplace(xmlAfter, expectedLabel, "", afterLabels)
    if (afterLabels <= beforeLabels) {
        detail := "Expected label count did not increase: " . expectedLabel
        return 0
    }
    detail := "Marker and label verified."
    return 1
}

; ── Hotkey registration ─────────────────────────────────────────────────────────
_RegisterHotkeys(enable) {
    state := enable ? "On" : "Off"
    Hotkey, F12, _HK_Place, %state%
    Hotkey, F11, _HK_Skip,  %state%
    Hotkey, F10, _HK_Abort, %state%
}

_HK_Place:
    if g_running
        _PlaceCurrent()
return

_HK_Skip:
    if g_running
        _SkipCurrent()
return

_HK_Abort:
    if g_running
        _AbortAll()
return

; ── Dry-run / visual calibration check ────────────────────────────────────────
_DryRun() {
    global g_rt_cx, g_rt_cy, g_lt_cx, g_lt_cy, g_radius, g_scale

    ; Move to RT nipple
    MouseMove, %g_rt_cx%, %g_rt_cy%, 8
    ToolTip, RT nipple  (r=%g_radius%px  scale=%g_scale%px/cm), %g_rt_cx%, %g_rt_cy%
    Sleep, 1800

    ; Move to LT nipple
    MouseMove, %g_lt_cx%, %g_lt_cy%, 8
    ToolTip, LT nipple, %g_lt_cx%, %g_lt_cy%
    Sleep, 1800

    ; Trace 4 clock positions on RT to verify geometry
    clocks := [12, 3, 6, 9]
    loop % 4 {
        clock := clocks[A_Index]
        _ClockToXY("R", clock, 3.0, 0, tx, ty)
        MouseMove, %tx%, %ty%, 6
        ToolTip, RT %clock% o'clock @ 3cm, %tx%, %ty%
        Sleep, 1200
    }
    ToolTip
}
