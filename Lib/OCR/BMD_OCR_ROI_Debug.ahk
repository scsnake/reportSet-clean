; BMD_OCR_ROI_Debug.ahk — AHK v1 ROI visual debug helper for BMD/DXA.
;
; Modelled on INFINITT_OCR_RegionReview.ahk:
;   colored filled box + label overlay per ROI (so you can see WHERE each region
;   sits on the INFINITT viewport), plus OCR text via the window-worker path
;   (the only path that reliably captures GPU-rendered INFINITT content).
;   No BMP saves — GDI/screen capture returns black for GPU windows.
;
; IMPORTANT: No bare labels or top-level return statements here.
;   This file is #include-d from INFINITT_OCR_BMD.ahk which is included
;   before the main return in YCH_BMD.ahk — bare labels with return would
;   terminate auto-execute prematurely and break OCR_WinRT_Init().
;   All code here is inside function bodies only.
;
; API
; ───
; BMD_OCR_DebugROI(rois)
;
;   rois — array of roi specs, each EITHER:
;     { label:"name", hwnd:viewportHwnd, ratio:[rx,ry,rw,rh] }
;       ratio = fraction of hwnd client; (0,0)=top-left, (1,1)=bottom-right
;     { label:"name", screen:[sx,sy,sw,sh] }
;       absolute screen coordinates (no hwnd -> OCR skipped)
;
; BMD_OCR_DebugROI_DXA()        -- all 6 DXA fields from INI + current viewports
; BMD_OCR_DebugROI_Subtype(sub) -- all fields for a calibrated BMD subtype
;
; Colors cycle: Red Lime Yellow Aqua Fuchsia Blue White Silver
; Overlays stay visible while MsgBox is open so you can compare to the screen.
; Summary is also copied to clipboard.

global _BORD_GUIS   := []
global _BORD_COLORS := ["Red", "Lime", "Yellow", "Aqua", "Fuchsia", "Blue", "White", "Silver"]
global _BORD_ALPHA  := 77   ; 30 % opacity, same as INFINITT_OCR_RegionReview

; ───────────────────────────────────────────────────────────────────────────
; Main entry point
; ───────────────────────────────────────────────────────────────────────────
BMD_OCR_DebugROI(rois) {
    global _BORD_GUIS, _BORD_COLORS

    if (!IsObject(rois) || rois.Length() = 0) {
        ToolTip, BMD_OCR_DebugROI: roi list is empty
        Sleep, 1800
        ToolTip
        return
    }

    _BORD_DestroyAll()   ; clear any leftover overlays from a previous run

    ; ── Resolve each ROI to screen + client coords ────────────────────────
    resolved := []
    for _, roi in rois
        resolved.Push(_BORD_Resolve(roi))

    ; ── OCR BEFORE showing overlays (AlwaysOnTop windows corrupt captures)
    for _, r in resolved {
        r.ocrText := ""
        if (!r.ok || !r.hasHwnd)
            continue
        if (r.isDxa) {
            r.ocrText := Trim(BMD_DXA_OCR_ReadText(r.label, [r.cx, r.cy, r.cw, r.ch], r.hwnd))
            if (r.label = "almi") {
                _BORD_AddAlmi4xProbe(r)
                _BORD_AddAlmiLineProbes(r)
            }
        } else {
            r.ocrText := Trim(_OWR_OcrWindowRectViaWorker(r.hwnd, r.cx, r.cy, r.cw, r.ch, "en-US"))
        }
    }
    _BORD_AddAlmiFatColumnProbe(resolved)

    ; ── Resolve viewport screen origin for relative-coord display ─────────
    vpX := 0, vpY := 0, vpW := 0, vpH := 0
    for _, r in resolved {
        if (r.ok && r.hasHwnd) {
            VarSetCapacity(pt, 8, 0)
            DllCall("ClientToScreen", "ptr", r.hwnd, "ptr", &pt)
            vpX := NumGet(pt, 0, "int"), vpY := NumGet(pt, 4, "int")
            VarSetCapacity(rc, 16, 0)
            DllCall("GetClientRect", "ptr", r.hwnd, "ptr", &rc)
            vpW := NumGet(rc, 8, "int"), vpH := NumGet(rc, 12, "int")
            break
        }
    }

    ; ── Show all overlays ─────────────────────────────────────────────────
    for i, r in resolved {
        color := _BORD_COLORS[Mod(i - 1, _BORD_COLORS.Length()) + 1]
        if (!r.ok) {
            _BORD_ShowBox(i, r.label " [ERROR:" r.err "]", vpX, vpY + (i * 20), 80, 16, color, vpX, vpY, vpW, vpH)
            continue
        }
        ocrDisplay := (r.ocrText != "") ? " OCR:[" r.ocrText "]" : " [EMPTY]"
        _BORD_ShowBox(i, r.label ocrDisplay, r.sx, r.sy, r.sw, r.sh, color, vpX, vpY, vpW, vpH)
        if (r.label = "almi" && IsObject(r.almi4xRegion)) {
            probeText := (r.almi4xText != "") ? " OCR:[" r.almi4xText "]" : " [EMPTY]"
            _BORD_ShowBox(i "_4x", "almi 4x" probeText, r.almi4xSx, r.almi4xSy, r.almi4xW, r.almi4xH, "White", vpX, vpY, vpW, vpH)
        }
        if (r.label = "almi" && IsObject(r.almiFatColumnRegion)) {
            colText := (r.almiFatColumnText != "") ? " OCR:[" _BORD_Truncate(_BORD_OneLine(r.almiFatColumnText), 80) "]" : " [EMPTY]"
            _BORD_ShowBox(i "_fatcol", "almi fat-column" colText, r.almiFatColumnSx, r.almiFatColumnSy, r.almiFatColumnW, r.almiFatColumnH, "Silver", vpX, vpY, vpW, vpH)
        }
        if (r.label = "almi" && IsObject(r.almiLineProbes)) {
            for j, p in r.almiLineProbes {
                pText := (p.text != "") ? " OCR:[" _BORD_Truncate(_BORD_OneLine(p.text), 60) "]" : " [EMPTY]"
                _BORD_ShowBox(i "_line" j, p.name pText, p.sx, p.sy, p.w, p.h, "Aqua", vpX, vpY, vpW, vpH)
            }
        }
    }

    ; ── Build summary ─────────────────────────────────────────────────────
    summary := "BMD OCR ROI Debug  " A_Now "`n"
    for i, r in resolved {
        color := _BORD_COLORS[Mod(i - 1, _BORD_COLORS.Length()) + 1]
        if (!r.ok) {
            summary .= i ". [" color "] " r.label " -- ERROR: " r.err "`n"
            continue
        }
        ocrMark := (r.ocrText = "") ? "  *** EMPTY ***" : ""
        summary .= i ". [" color "] " r.label ": [" r.ocrText "]" ocrMark "`n"
        if (r.hasHwnd)
            summary .= "   hwnd=" r.hwnd "  client=" r.cx "," r.cy "  " r.cw "x" r.ch "`n"
        else
            summary .= "   (screen only -- OCR skipped)`n"
        if (vpW > 0)
            summary .= "   screen=" r.sx "," r.sy "  " r.sw "x" r.sh
                . "  rel=[" (r.sx-vpX) "," (r.sy-vpY) "]"
                . "  ratio=[" _BORD_RatioFmt(r.sx-vpX, r.sy-vpY, r.sw, r.sh, vpW, vpH) "]`n"
        else
            summary .= "   screen=" r.sx "," r.sy "  " r.sw "x" r.sh "`n"
        if (r.label = "almi" && IsObject(r.almi4xRegion)) {
            summary .= "   almi 4x probe: [" r.almi4xText "]"
                . ((r.almi4xText = "") ? "  *** EMPTY ***" : "") "`n"
                . "      client=" r.almi4xX "," r.almi4xY "  " r.almi4xW "x" r.almi4xH
                . "  screen=" r.almi4xSx "," r.almi4xSy "  " r.almi4xW "x" r.almi4xH "`n"
        }
        if (r.label = "almi" && IsObject(r.almiFatColumnRegion)) {
            summary .= "   almi fat-column probe: [" r.almiFatColumnText "]"
                . ((r.almiFatColumnText = "") ? "  *** EMPTY ***" : "") "`n"
                . "      from fat_pct x/w to viewport bottom`n"
                . "      client=" r.almiFatColumnX "," r.almiFatColumnY "  " r.almiFatColumnW "x" r.almiFatColumnH
                . "  screen=" r.almiFatColumnSx "," r.almiFatColumnSy "  " r.almiFatColumnW "x" r.almiFatColumnH "`n"
        }
        if (r.label = "almi" && IsObject(r.almiLineProbes)) {
            for _, p in r.almiLineProbes {
                summary .= "   " p.name ": [" p.text "]"
                    . ((p.text = "") ? "  *** EMPTY ***" : "") "`n"
                    . "      client=" p.x "," p.y "  " p.w "x" p.h
                    . "  screen=" p.sx "," p.sy "  " p.w "x" p.h "`n"
                if (p.variants != "")
                    summary .= "      variants:`n" _BORD_Indent(p.variants, "        ") "`n"
            }
        }
    }
    clipboard := summary

    ; ── MsgBox holds overlays visible while user inspects the screen ──────
    MsgBox, 64, BMD OCR ROI Debug (summary in clipboard), %summary%
    _BORD_DestroyAll()
}

; ───────────────────────────────────────────────────────────────────────────
; DXA convenience wrapper
; ───────────────────────────────────────────────────────────────────────────
BMD_OCR_DebugROI_DXA() {
    global BMD_DXA_FIELD_DISPLAY
    vpCache := {}
    rois := []
    for fieldName, dispIdx in BMD_DXA_FIELD_DISPLAY {
        if !vpCache.HasKey(dispIdx) {
            vp := BMD_ResolveViewportN(dispIdx)
            vpCache[dispIdx] := IsObject(vp) ? vp : ""
        }
        vp := vpCache[dispIdx]
        if !IsObject(vp) {
            rois.Push({ label: fieldName " [no VP disp" dispIdx "]", screen: [0, 0, 1, 1] })
            continue
        }
        ratio := BMD_LoadRatio("dxa", fieldName)
        if !IsObject(ratio) {
            rois.Push({ label: fieldName " [no ratio]", screen: [0, 0, 1, 1] })
            continue
        }
        rois.Push({ label: fieldName, hwnd: vp.viewport, ratio: ratio, dxa: true })
    }
    BMD_OCR_DebugROI(rois)
}

; ───────────────────────────────────────────────────────────────────────────
; BMD subtype wrapper
; ───────────────────────────────────────────────────────────────────────────
BMD_OCR_DebugROI_Subtype(subtype, viewportHwnd := 0) {
    global BMD_OCR_SCHEMA
    if !BMD_OCR_SCHEMA.HasKey(subtype) {
        ToolTip, % "BMD_OCR_DebugROI_Subtype: unknown subtype '" subtype "'"
        Sleep, 1800
        ToolTip
        return
    }
    if (!viewportHwnd) {
        vp := BMD_ResolveViewport()
        viewportHwnd := IsObject(vp) ? vp.viewport : 0
    }
    if (!viewportHwnd) {
        ToolTip, BMD_OCR_DebugROI_Subtype: no INFINITT viewport found
        Sleep, 1800
        ToolTip
        return
    }
    rois := []
    for _, fieldName in BMD_OCR_SCHEMA[subtype] {
        ratio := BMD_LoadRatio(subtype, fieldName)
        if IsObject(ratio)
            rois.Push({ label: fieldName, hwnd: viewportHwnd, ratio: ratio })
        else
            rois.Push({ label: fieldName " [no ratio]", screen: [0, 0, 1, 1] })
    }
    BMD_OCR_DebugROI(rois)
}

; ───────────────────────────────────────────────────────────────────────────
; Internal helpers -- all inside function bodies, no bare labels or returns
; ───────────────────────────────────────────────────────────────────────────

_BORD_Resolve(roi) {
    r := { label: roi.HasKey("label") ? roi.label : "roi"
         , ok: false, hasHwnd: false, ocrText: ""
         , isDxa: roi.HasKey("dxa") ? roi.dxa : false }

    if (roi.HasKey("hwnd") && roi.HasKey("ratio")) {
        hwnd  := roi.hwnd
        ratio := roi.ratio
        if (!WinExist("ahk_id " hwnd)) {
            r.err := "hwnd " hwnd " not found"
            return r
        }
        VarSetCapacity(rect, 16, 0)
        DllCall("GetClientRect", "ptr", hwnd, "ptr", &rect)
        clW := NumGet(rect, 8, "int"), clH := NumGet(rect, 12, "int")
        if (clW <= 0 || clH <= 0) {
            r.err := "hwnd " hwnd " client size zero"
            return r
        }
        cx := Round(clW * ratio[1])
        cy := Round(clH * ratio[2])
        cw := Max(1, Round(clW * ratio[3]))
        ch := Max(1, Round(clH * ratio[4]))
        VarSetCapacity(pt, 8, 0)
        DllCall("ClientToScreen", "ptr", hwnd, "ptr", &pt)
        ox := NumGet(pt, 0, "int"), oy := NumGet(pt, 4, "int")
        r.ok := true, r.hasHwnd := true
        r.hwnd := hwnd, r.cx := cx, r.cy := cy, r.cw := cw, r.ch := ch
        r.sx := ox + cx, r.sy := oy + cy, r.sw := cw, r.sh := ch
        r.ratio := ratio
    } else if (roi.HasKey("screen")) {
        sc := roi.screen
        if (!IsObject(sc) || sc.Length() < 4) {
            r.err := "screen array needs 4 elements [x,y,w,h]"
            return r
        }
        r.ok := true, r.hasHwnd := false
        r.sx := sc[1], r.sy := sc[2], r.sw := sc[3], r.sh := sc[4]
    } else {
        r.err := "roi needs {hwnd,ratio} or {screen:[x,y,w,h]}"
    }
    return r
}

_BORD_AddAlmiFatColumnProbe(ByRef resolved) {
    almi := ""
    fat := ""
    for _, r in resolved {
        if (r.ok && r.hasHwnd && r.label = "almi")
            almi := r
        else if (r.ok && r.hasHwnd && r.label = "fat_pct")
            fat := r
    }
    if (!IsObject(almi) || !IsObject(fat) || almi.hwnd != fat.hwnd)
        return

    VarSetCapacity(rect, 16, 0)
    DllCall("GetClientRect", "ptr", fat.hwnd, "ptr", &rect)
    clH := NumGet(rect, 12, "int")
    if (clH <= fat.cy)
        return

    almi.almiFatColumnX := fat.cx
    almi.almiFatColumnY := fat.cy
    almi.almiFatColumnW := fat.cw
    almi.almiFatColumnH := clH - fat.cy
    almi.almiFatColumnRegion := [almi.almiFatColumnX, almi.almiFatColumnY, almi.almiFatColumnW, almi.almiFatColumnH]

    VarSetCapacity(pt, 8, 0)
    NumPut(almi.almiFatColumnX, pt, 0, "Int")
    NumPut(almi.almiFatColumnY, pt, 4, "Int")
    DllCall("ClientToScreen", "ptr", fat.hwnd, "ptr", &pt)
    almi.almiFatColumnSx := NumGet(pt, 0, "int")
    almi.almiFatColumnSy := NumGet(pt, 4, "int")

    text := Trim(_OWR_OcrWindowRectViaWorker(fat.hwnd, almi.almiFatColumnX, almi.almiFatColumnY, almi.almiFatColumnW, almi.almiFatColumnH, "en-US"))
    if (text = "") {
        cap := GetCaptureRectFromClient(fat.hwnd, almi.almiFatColumnX, almi.almiFatColumnY, almi.almiFatColumnW, almi.almiFatColumnH)
        text := Trim(OCR_WinRT_GetText(cap.screenX, cap.screenY, cap.screenW, cap.screenH, 0, 4))
    }
    almi.almiFatColumnText := text
}

_BORD_AddAlmiLineProbes(ByRef r) {
    r.almiLineProbes := []
    _BORD_AddAlmiLineProbe(r, "almi line wide", 3.0, 1.8, 0)
    _BORD_AddAlmiLineProbe(r, "almi line tall", 3.0, 2.6, 0)
    _BORD_AddAlmiLineProbe(r, "almi row above", 3.0, 1.8, -22)
    _BORD_AddAlmiLineProbe(r, "almi row below", 3.0, 1.8, 22)
    _BORD_AddAlmiLineProbe(r, "almi row below2", 3.0, 1.8, 44)
    _BORD_AddAlmiLineProbe(r, "almi row below3", 3.0, 1.8, 66)
    _BORD_AddAlmiLineProbe(r, "almi row bottom", 3.0, 2.2, 86)
}

_BORD_AddAlmiLineProbe(ByRef r, name, wScale, hScale, yShift) {
    probe := _BORD_ClientRegionCenterScaleShift(r.hwnd, r.cx, r.cy, r.cw, r.ch, wScale, hScale, 0, yShift)
    if !IsObject(probe)
        return

    p := { name: name, x: probe[1], y: probe[2], w: probe[3], h: probe[4] }
    VarSetCapacity(pt, 8, 0)
    NumPut(p.x, pt, 0, "Int")
    NumPut(p.y, pt, 4, "Int")
    DllCall("ClientToScreen", "ptr", r.hwnd, "ptr", &pt)
    p.sx := NumGet(pt, 0, "int")
    p.sy := NumGet(pt, 4, "int")

    p.text := Trim(_OWR_OcrWindowRectViaWorker(r.hwnd, p.x, p.y, p.w, p.h, "en-US"))
    if (p.text = "") {
        cap := GetCaptureRectFromClient(r.hwnd, p.x, p.y, p.w, p.h)
        p.text := Trim(OCR_WinRT_GetText(cap.screenX, cap.screenY, cap.screenW, cap.screenH, 0, 4))
    }
    if (p.text = "" || InStr(name, "below") || name = "almi line wide" || name = "almi line tall" || name = "almi row bottom")
        p.variants := Trim(_OWR_OcrWindowRectVariantsViaWorker(r.hwnd, p.x, p.y, p.w, p.h, "en-US"))
    else
        p.variants := ""
    r.almiLineProbes.Push(p)
}

_BORD_AddAlmi4xProbe(ByRef r) {
    probe := _BORD_ClientRegionCenterScaleShift(r.hwnd, r.cx, r.cy, r.cw, r.ch, 4, 4, 0, 0)
    if !IsObject(probe)
        return

    r.almi4xRegion := probe
    r.almi4xX := probe[1], r.almi4xY := probe[2], r.almi4xW := probe[3], r.almi4xH := probe[4]

    VarSetCapacity(pt, 8, 0)
    NumPut(r.almi4xX, pt, 0, "Int")
    NumPut(r.almi4xY, pt, 4, "Int")
    DllCall("ClientToScreen", "ptr", r.hwnd, "ptr", &pt)
    r.almi4xSx := NumGet(pt, 0, "int")
    r.almi4xSy := NumGet(pt, 4, "int")

    text := Trim(_OWR_OcrWindowRectViaWorker(r.hwnd, r.almi4xX, r.almi4xY, r.almi4xW, r.almi4xH, "en-US"))
    if (text = "") {
        cap := GetCaptureRectFromClient(r.hwnd, r.almi4xX, r.almi4xY, r.almi4xW, r.almi4xH)
        text := Trim(OCR_WinRT_GetText(cap.screenX, cap.screenY, cap.screenW, cap.screenH, 0, 4))
    }
    r.almi4xText := text
}

_BORD_ClientRegionCenterScaleShift(hwnd, x, y, w, h, wScale, hScale, xShift, yShift) {
    VarSetCapacity(rect, 16, 0)
    DllCall("GetClientRect", "ptr", hwnd, "ptr", &rect)
    clW := NumGet(rect, 8, "int"), clH := NumGet(rect, 12, "int")
    if (clW <= 0 || clH <= 0)
        return ""

    newW := Max(1, Round(w * wScale))
    newH := Max(1, Round(h * hScale))
    cx := x + (w / 2.0) + xShift
    cy := y + (h / 2.0) + yShift
    newX := Round(cx - (newW / 2.0))
    newY := Round(cy - (newH / 2.0))

    if (newW > clW)
        newW := clW
    if (newH > clH)
        newH := clH
    if (newX < 0)
        newX := 0
    if (newY < 0)
        newY := 0
    if (newX + newW > clW)
        newX := clW - newW
    if (newY + newH > clH)
        newY := clH - newH
    return [newX, newY, newW, newH]
}

_BORD_OneLine(text) {
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

_BORD_Truncate(text, limit) {
    if (StrLen(text) <= limit)
        return text
    return SubStr(text, 1, limit - 3) "..."
}

_BORD_Indent(text, prefix) {
    text := RegExReplace(text, "\r\n|\r|\n", "`n" prefix)
    return prefix text
}

; Filled semi-transparent box + label, mirroring INFINITT_OCR_RegionReview_ShowBox.
_BORD_ShowBox(i, label, x, y, w, h, color, vpX, vpY, vpW, vpH) {
    global _BORD_GUIS, _BORD_ALPHA

    boxGui   := "BMDROIDbg"    i
    labelGui := "BMDROIDbgLbl" i
    _BORD_GUIS.Push(boxGui)
    _BORD_GUIS.Push(labelGui)

    if (w >= 1 && h >= 1) {
        Gui, %boxGui%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
        Gui, %boxGui%:Color, %color%
        Gui, %boxGui%:Show, x%x% y%y% w%w% h%h% NoActivate, %boxGui%
        WinSet, Transparent, %_BORD_ALPHA%, %boxGui%
    }

    lx := x
    ly := y - 22
    if (ly < 0)
        ly := y + h + 2
    rel  := "[" (x - vpX) "," (y - vpY) "," w "," h "]"
    rStr := _BORD_RatioFmt(x - vpX, y - vpY, w, h, vpW, vpH)
    Gui, %labelGui%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %labelGui%:Color, Black
    Gui, %labelGui%:Font, s9 c%color%, Consolas
    Gui, %labelGui%:Add, Text, x3 y2, % i ". " label "  screen [" x "," y "," w "," h "]  rel " rel "  ratio [" rStr "]"
    Gui, %labelGui%:Show, x%lx% y%ly% NoActivate, %labelGui%
}

_BORD_RatioFmt(x, y, w, h, vpW, vpH) {
    if (!vpW || !vpH)
        return ""
    return Format("{:.4f},{:.4f},{:.4f},{:.4f}", x/vpW, y/vpH, w/vpW, h/vpH)
}

_BORD_DestroyAll() {
    global _BORD_GUIS
    for _, name in _BORD_GUIS {
        try
        Gui, %name%:Destroy
    }
    _BORD_GUIS := []
}
