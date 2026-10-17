; ris_button_map_test.ahk - RIS breast annotation button mapping harness (AHK v1)
;
; Hotkeys:
;   F6  Find IE/Silverlight host, load calibration, draw button overlays.
;   F7  Open button mapping editor.
;   F8  Walk through button anchors with mouse only, no clicks.
;   F9  Save current map and copy report to clipboard.
;   F10 Clear overlays.
;   Esc Exit.

#NoEnv
#SingleInstance Force
#Include %A_ScriptDir%\..\..\..\Lib\IsCurrentSessionRDP.ahk
SetBatchLines, -1
SetTitleMatchMode, 2
CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen

global g_ie_hwnd := 0
global g_ctrl_hwnd := 0
global g_ctrl_x := 0
global g_ctrl_y := 0
global g_ctrl_w := 0
global g_ctrl_h := 0
global g_btn_c0x := 0
global g_btn_c1x := 0
global g_btn_r0y := 0
global g_btn_rh := 0
global g_loaded_calib := 0
global g_overlay_ids := []
global g_button_map := {}
global g_edit_hwnds := {}
global g_last_report := ""

_InitButtonDefaults()
_LoadButtonMap()

F6::
    _RunButtonMapOverlay()
return

F7::
    if (!g_loaded_calib)
        _RunButtonMapOverlay()
    _ShowMapEditor()
return

F8::
    if (!g_loaded_calib)
        _RunButtonMapOverlay()
    _WalkButtons()
return

F9::
    _SaveButtonMap()
    g_last_report := _BuildReport()
    Clipboard := g_last_report
    ToolTip, Button map saved and copied to clipboard.
    SetTimer, _HideTip, -1200
return

F10::
    _ClearOverlays()
return

Esc::ExitApp

_HideTip:
    ToolTip
return

_RunButtonMapOverlay() {
    global g_last_report

    if (!_FindIEAnnotationHost())
        return
    if (!_LoadCalibration()) {
        MsgBox, 16, Missing calibration, Could not load ris_annotate_calib.ini for this session.`n`nRun ris_annotate_calib_test.ahk and press Ctrl+Alt+S first.
        return
    }
    _LoadButtonMap()
    _ClearOverlays()
    _DrawButtonOverlays()
    g_last_report := _BuildReport()
    _SaveReport(g_last_report)
    Clipboard := g_last_report
    MsgBox, 64, RIS Button Map, %g_last_report%`n`nReport saved beside this script and copied to clipboard.
}

_InitButtonDefaults() {
    global g_button_map

    g_button_map := {}
    _SetButton("0", "0", "SCAR_DIAGONAL_SLASH")
    _SetButton("0", "1", "SCAR_DIAGONAL_BACKSLASH")
    _SetButton("1", "0", "SCAR_VERTICAL")
    _SetButton("1", "1", "SCAR_HORIZONTAL")
    _SetButton("2", "0", "FA_LARGE")
    _SetButton("2", "1", "FA_SMALL")
    _SetButton("3", "0", "SUS_LARGE")
    _SetButton("3", "1", "SUS_SMALL")
    _SetButton("4", "0", "COARSE_CALCIFICATION_LARGE")
    _SetButton("4", "1", "COARSE_CALCIFICATION_SMALL")
    _SetButton("5", "0", "FCC_LARGE")
    _SetButton("5", "1", "FCC_SMALL")
    _SetButton("6", "0", "CYST_LARGE")
    _SetButton("6", "1", "CYST_SMALL")
    _SetButton("7", "0", "DUCT_ECTASIA_HORIZONTAL")
    _SetButton("7", "1", "DUCT_ECTASIA_VERTICAL")
    _SetButton("8", "0", "DUCT_ECTASIA_DIAGONAL_SLASH")
    _SetButton("8", "1", "DUCT_ECTASIA_DIAGONAL_BACKSLASH")
    _SetButton("9", "0", "INTRADUCTAL_PAPILLOMA")
    _SetButton("9", "1", "COMPLEX_CYST")
    _SetButton("10", "0", "DUCT_ECTASIA")
    _SetButton("10", "1", "MICROCALCIFICATION")
    _SetButton("11", "0", "")
    _SetButton("11", "1", "LN")
}

_SetButton(row, col, label) {
    global g_button_map
    g_button_map["R" . row . "C" . col] := label
}

_GetButton(row, col) {
    global g_button_map
    key := "R" . row . "C" . col
    if g_button_map.HasKey(key)
        return g_button_map[key]
    return ""
}

_LoadButtonMap() {
    global g_button_map

    mapFile := A_ScriptDir . "\ris_button_map.ini"
    if !FileExist(mapFile)
        return

    Loop, 12 {
        row := A_Index - 1
        Loop, 2 {
            col := A_Index - 1
            key := "R" . row . "C" . col
            IniRead, val, %mapFile%, Buttons, %key%, __missing__
            if (val != "__missing__")
                g_button_map[key] := val
        }
    }
}

_SaveButtonMap() {
    global g_button_map

    mapFile := A_ScriptDir . "\ris_button_map.ini"
    FileDelete, %mapFile%
    IniWrite, RIS breast annotation button map, %mapFile%, Meta, Description
    IniWrite, % A_Now, %mapFile%, Meta, SavedAt
    Loop, 12 {
        row := A_Index - 1
        Loop, 2 {
            col := A_Index - 1
            key := "R" . row . "C" . col
            val := _GetButton(row, col)
            IniWrite, %val%, %mapFile%, Buttons, %key%
        }
    }
}

_ShowMapEditor() {
    global g_button_map, g_edit_hwnds

    g_edit_hwnds := {}
    Gui, ButtonMap:Destroy
    Gui, ButtonMap:+AlwaysOnTop +Resize
    Gui, ButtonMap:Font, s9, Segoe UI
    Gui, ButtonMap:Add, Text, xm ym w520, Edit each button label. Row 11 col0 is intentionally blank; row 11 col1 is the bottom partial eye icon.
    y := 35
    Loop, 12 {
        row := A_Index - 1
        Gui, ButtonMap:Add, Text, x10 y%y% w50, Row %row%
        Loop, 2 {
            col := A_Index - 1
            xLabel := (col = 0) ? 70 : 390
            xEdit := (col = 0) ? 125 : 445
            key := "R" . row . "C" . col
            val := _GetButton(row, col)
            Gui, ButtonMap:Add, Text, x%xLabel% y%y% w45, Col %col%
            Gui, ButtonMap:Add, Edit, x%xEdit% y%y% w250 hwndhEdit, %val%
            g_edit_hwnds[key] := hEdit
        }
        y += 28
    }
    btnY := y + 8
    Gui, ButtonMap:Add, Button, x125 y%btnY% w110 gButtonMapSave, Save
    Gui, ButtonMap:Add, Button, x245 y%btnY% w130 gButtonMapSaveOverlay, Save + Overlay
    Gui, ButtonMap:Add, Button, x385 y%btnY% w110 gButtonMapClose, Close
    Gui, ButtonMap:Show, w720 h%btnY% AutoSize, RIS Button Map Editor
}

ButtonMapSave:
    _SubmitMapEditor()
    _SaveButtonMap()
    ToolTip, Button map saved.
    SetTimer, _HideTip, -1200
return

ButtonMapSaveOverlay:
    _SubmitMapEditor()
    _SaveButtonMap()
    _ClearOverlays()
    _DrawButtonOverlays()
    g_last_report := _BuildReport()
    _SaveReport(g_last_report)
    Clipboard := g_last_report
    ToolTip, % "Button map saved, overlays refreshed, report copied."
    SetTimer, _HideTip, -1500
return

ButtonMapClose:
ButtonMapGuiClose:
    Gui, ButtonMap:Destroy
return

_SubmitMapEditor() {
    global g_button_map, g_edit_hwnds

    Loop, 12 {
        row := A_Index - 1
        Loop, 2 {
            col := A_Index - 1
            key := "R" . row . "C" . col
            hEdit := g_edit_hwnds[key]
            ControlGetText, val,, ahk_id %hEdit%
            _SetButton(row, col, val)
        }
    }
}

_LoadCalibration() {
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h
    global g_btn_c0x, g_btn_c1x, g_btn_r0y, g_btn_rh, g_loaded_calib

    iniFile := A_ScriptDir . "\ris_annotate_calib.ini"
    if !FileExist(iniFile) {
        g_loaded_calib := 0
        return 0
    }
    section := IsCurrentSessionRDP() ? "Calibration_rdp" : "Calibration_local"
    IniRead, probe, %iniFile%, %section%, PX_BTN_COL0_X, __missing__
    if (probe = "__missing__") {
        g_loaded_calib := 0
        return 0
    }

    baseW := _IniReadFloat(iniFile, section, "BASE_CTRL_W", 1155)
    baseH := _IniReadFloat(iniFile, section, "BASE_CTRL_H", 1162)
    if (baseW < 300 || baseH < 300) {
        g_loaded_calib := 0
        return 0
    }
    scaleX := g_ctrl_w / baseW
    scaleY := g_ctrl_h / baseH
    g_btn_c0x := g_ctrl_x + Round(_IniReadFloat(iniFile, section, "PX_BTN_COL0_X", 0) * scaleX)
    g_btn_c1x := g_ctrl_x + Round(_IniReadFloat(iniFile, section, "PX_BTN_COL1_X", 0) * scaleX)
    g_btn_r0y := g_ctrl_y + Round(_IniReadFloat(iniFile, section, "PX_BTN_ROW0_Y", 0) * scaleY)
    g_btn_rh := Round(_IniReadFloat(iniFile, section, "PX_BTN_ROW_PITCH", 66) * scaleY)
    g_loaded_calib := 1
    return 1
}

_IniReadFloat(iniFile, section, key, defaultValue) {
    IniRead, val, %iniFile%, %section%, %key%, %defaultValue%
    return val + 0
}

_FindIEAnnotationHost() {
    global g_ie_hwnd, g_ctrl_hwnd, g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h

    if (_FindIEAnnotationHostViaDom())
        return 1

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

        scaleX := 1.0
        scaleY := 1.0
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
        WinActivate, ahk_id %hwnd%
        Sleep, 200
        return 1
    }
    return 0
}

_DrawButtonOverlays() {
    Loop, 12 {
        row := A_Index - 1
        Loop, 2 {
            col := A_Index - 1
            if (row = 11 && col = 0)
                continue
            x := _ButtonX(col)
            y := _ButtonY(row)
            label := row . "," . col . " " . _GetButton(row, col)
            _OverlayCross("btn_" . row . "_" . col, x, y, "0000FF")
            _OverlayLabel("lbl_" . row . "_" . col, x - 500, y - 10, label)
        }
    }
}

_OverlayCross(name, x, y, color) {
    _OverlaySolid(name . "_h", x - 8, y - 1, 17, 3, color)
    _OverlaySolid(name . "_v", x - 1, y - 8, 3, 17, color)
}

_OverlaySolid(name, x, y, w, h, color) {
    global g_overlay_ids

    guiName := "BtnMap_" . name
    Gui, %guiName%:Destroy
    Gui, %guiName%:+AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %guiName%:Color, %color%
    Gui, %guiName%:Show, x%x% y%y% w%w% h%h% NoActivate, %guiName%
    g_overlay_ids.Push(guiName)
}

_OverlayLabel(name, x, y, txt) {
    global g_overlay_ids

    guiName := "BtnMap_" . name
    Gui, %guiName%:Destroy
    Gui, %guiName%:+AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %guiName%:Color, FFFFCC
    Gui, %guiName%:Font, s8 cBlack, Segoe UI
    Gui, %guiName%:Add, Text, x3 y1 w230 h18, %txt%
    Gui, %guiName%:Show, x%x% y%y% w236 h20 NoActivate, %guiName%
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

_WalkButtons() {
    if (!g_loaded_calib)
        return

    Loop, 12 {
        row := A_Index - 1
        Loop, 2 {
            col := A_Index - 1
            if (row = 11 && col = 0)
                continue
            x := _ButtonX(col)
            y := _ButtonY(row)
            label := _GetButton(row, col)
            MouseMove, %x%, %y%, 8
            ToolTip, row %row% col %col%`n%label%, % x + 15, % y + 15
            Sleep, 1100
        }
    }
    ToolTip
}

_BuildReport() {
    global g_ctrl_x, g_ctrl_y, g_ctrl_w, g_ctrl_h, g_btn_c0x, g_btn_c1x, g_btn_r0y, g_btn_rh

    txt := "RIS breast annotation button map`r`n"
    txt .= "Session: " . (IsCurrentSessionRDP() ? "RDP" : "local") . "`r`n"
    txt .= "Host rect screen: x=" . g_ctrl_x . " y=" . g_ctrl_y . " w=" . g_ctrl_w . " h=" . g_ctrl_h . "`r`n"
    txt .= "Button anchors: col0=" . g_btn_c0x . " col1=" . g_btn_c1x . " row0=" . g_btn_r0y . " pitch=" . g_btn_rh . "`r`n`r`n"
    Loop, 12 {
        row := A_Index - 1
        Loop, 2 {
            col := A_Index - 1
            if (row = 11 && col = 0) {
                txt .= "row 11 col0: none`r`n"
                continue
            }
            txt .= "row " . row . " col " . col . ": " . _GetButton(row, col)
            txt .= " @ " . _ButtonX(col) . "," . _ButtonY(row) . "`r`n"
        }
    }
    return txt
}

_SaveReport(txt) {
    outFile := A_ScriptDir . "\ris_button_map_last.txt"
    FileDelete, %outFile%
    FileAppend, %txt%, %outFile%, UTF-8
}

_ButtonX(col) {
    global g_btn_c0x, g_btn_c1x
    return (col = 0) ? g_btn_c0x : g_btn_c1x
}

_ButtonY(row) {
    global g_btn_r0y, g_btn_rh
    return g_btn_r0y + Round(row * g_btn_rh)
}
