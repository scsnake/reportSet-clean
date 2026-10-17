; AHK v1 — INFINITT viewport OCR for YCH BMD reports.
;
; Responsibilities
;   1. Detect BMD subtype from the RIS exam name.
;   2. Read OCR values from named regions inside the INFINITT image viewport.
;      Region coordinates are stored as ratios of viewport client size in
;      Lib\OCR\BMD_OCR_Regions.ini, so different monitor / RDP geometries
;      reuse the same calibration. Local vs. RDP profiles are kept separate.
;   3. Build a BMD/DXA report from typed values, returning both the report
;      text and the byte-offset spans of OCR-derived tokens for highlighting.
;   4. Provide an interactive two-click calibration flow that the user
;      drives from a hotkey when no INI entry exists or values look wrong.
;
; This module is the OCR side of YCH_BMD.ahk. The script's existing hand-
; input loop (`Loop { input → gosub bmd }`) is left untouched.

; INFINITT_OCR_Scroll.ahk is included by the top-level script (YCH_BMD.ahk) AFTER its
; main return, so its subroutine labels (OCRPreviewClose:) land in the subroutine section
; and do not terminate the caller's auto-execute section.
#Include %A_LineFile%\..\..\IsCurrentSessionRDP.ahk
#Include %A_LineFile%\..\..\LogRetention.ahk

global BMD_OCR_INI := A_LineFile "\..\BMD_OCR_Regions.ini"

; Per-subtype field schema. Each entry is a list of named regions to OCR.
; Field names are referenced by BMD_BuildReport() so adding fields here
; without updating the report builder will simply produce blank values.
global BMD_OCR_SCHEMA := { "lumbar": ["level","bmd","tscore","zscore"]
                         , "hip_r":  ["fn_bmd","fn_tscore","fn_zscore","total_bmd","total_tscore","total_zscore"]
                         , "hip_l":  ["fn_bmd","fn_tscore","fn_zscore","total_bmd","total_tscore","total_zscore"]
                         , "whole":  ["bmd","tscore","zscore"]
                         , "sarco":  ["fat_pct","lean_kg","almi"] }

global BMD_OCR_LAST_SUBTYPE := ""
global BMD_OCR_LAST_PARSED := ""

; Per-field display index for the combined DXA study.
; 0 = leftmost INFINITT window (2nd physical display)
; 1 = second-from-left INFINITT window (3rd physical display)
global BMD_DXA_FIELD_DISPLAY := { "fat_pct": 1, "lean_kg_g": 0, "almi": 1, "bmd": 0, "tscore": 0, "gender": 0 }
global BMD_DXA_FIELD_OCR_PADDING := { "lean_kg_g": [8, 8, 20, 8]
                                    , "tscore":    [6, 8, 18, 8] }
global BMD_DXA_FRAME_COUNT := 0   ; count of currently shown persistent DXA ROI frames

; ───────────────────────────────────────────────────────────────────────────
; Subtype detection
; ───────────────────────────────────────────────────────────────────────────
BMD_DetectSubtype(examname) {
    if (examname = "")
        return ""
    if (examname ~= "i)body composition|sarcope")
        return "sarco"
    if (examname ~= "i)whole body|total body")
        return "whole"
    if (examname ~= "i)\bR(?:igh)?t?\b.*\bhip\b|\bhip\b.*\bR(?:igh)?t?\b")
        return "hip_r"
    if (examname ~= "i)\bL(?:ef)?t?\b.*\bhip\b|\bhip\b.*\bL(?:ef)?t?\b")
        return "hip_l"
    if (examname ~= "i)\bhip\b")
        return "hip_r"  ; default side; user can override via hand input
    if (examname ~= "i)spine|lumbar|L1|L2|L3|L4")
        return "lumbar"
    return ""
}

; ───────────────────────────────────────────────────────────────────────────
; Viewport / region helpers
; ───────────────────────────────────────────────────────────────────────────
BMD_ResolveViewport() {
    parentHwnd := GetLeftmostINFINITTHwnd()
    if (!parentHwnd)
        return ""
    viewportHwnd := OCR_GetViewportHwnd(parentHwnd, "Img")
    if (!viewportHwnd)
        viewportHwnd := parentHwnd
    return { parent: parentHwnd, viewport: viewportHwnd }
}

BMD_ViewportClientSize(viewportHwnd) {
    VarSetCapacity(rect, 16, 0)
    DllCall("GetClientRect", "ptr", viewportHwnd, "ptr", &rect)
    return { w: NumGet(rect, 8, "int"), h: NumGet(rect, 12, "int") }
}

BMD_RatioToRegion(viewportHwnd, ratio) {
    sz := BMD_ViewportClientSize(viewportHwnd)
    return [Round(sz.w * ratio[1]), Round(sz.h * ratio[2])
          , Max(1, Round(sz.w * ratio[3])), Max(1, Round(sz.h * ratio[4]))]
}

BMD_ScreenRectToRatio(viewportHwnd, sx1, sy1, sx2, sy2) {
    VarSetCapacity(pt, 8, 0)
    DllCall("ClientToScreen", "ptr", viewportHwnd, "ptr", &pt)
    vx := NumGet(pt, 0, "int"), vy := NumGet(pt, 4, "int")
    sz := BMD_ViewportClientSize(viewportHwnd)
    if (sz.w <= 0 || sz.h <= 0)
        return ""
    x := Min(sx1, sx2) - vx
    y := Min(sy1, sy2) - vy
    w := Abs(sx2 - sx1)
    h := Abs(sy2 - sy1)
    return [x / sz.w, y / sz.h, w / sz.w, h / sz.h]
}

; ───────────────────────────────────────────────────────────────────────────
; INI persistence
; ───────────────────────────────────────────────────────────────────────────
BMD_ProfileSection(subtype) {
    return "subtype_" subtype "_" (IsCurrentSessionRDP() ? "rdp" : "local")
}

BMD_LoadRatio(subtype, fieldName) {
    global BMD_OCR_INI
    section := BMD_ProfileSection(subtype)
    IniRead, raw, % BMD_OCR_INI, % section, % fieldName, % "__missing__"
    if (raw = "__missing__" || raw = "")
        return ""
    parts := StrSplit(raw, ",")
    if (parts.Length() < 4)
        return ""
    return [parts[1] + 0.0, parts[2] + 0.0, parts[3] + 0.0, parts[4] + 0.0]
}

BMD_SaveRatio(subtype, fieldName, ratio) {
    global BMD_OCR_INI
    section := BMD_ProfileSection(subtype)
    SetFormat, FloatFast, 0.6
    val := (ratio[1] + 0.0) "," (ratio[2] + 0.0) "," (ratio[3] + 0.0) "," (ratio[4] + 0.0)
    IniWrite, % val, % BMD_OCR_INI, % section, % fieldName
}

; ───────────────────────────────────────────────────────────────────────────
; OCR read pass
; ───────────────────────────────────────────────────────────────────────────
BMD_OCR_ReadAll(subtype, showOverlay := true) {
    global BMD_OCR_SCHEMA
    if !BMD_OCR_SCHEMA.HasKey(subtype)
        return ""
    vp := BMD_ResolveViewport()
    if !IsObject(vp)
        return ""

    out := { _subtype: subtype, _viewport: vp.viewport, _missing: [] }
    for _, fieldName in BMD_OCR_SCHEMA[subtype] {
        ratio := BMD_LoadRatio(subtype, fieldName)
        if !IsObject(ratio) {
            out[fieldName] := ""
            out._missing.Push(fieldName)
            continue
        }
        region := BMD_RatioToRegion(vp.viewport, ratio)
        if (showOverlay) {
            VarSetCapacity(pt, 8, 0)
            DllCall("ClientToScreen", "ptr", vp.viewport, "ptr", &pt)
            sx := NumGet(pt, 0, "int") + region[1]
            sy := NumGet(pt, 4, "int") + region[2]
            ShowOCRRegion(sx, sy, region[3], region[4], 250)
        }
        text := OCR_ReadText(region, vp.viewport)
        out[fieldName] := Trim(text)
    }
    return out
}

; ───────────────────────────────────────────────────────────────────────────
; OCR text → numeric value
;
; OCR yields strings like "0.853", "-1.5", "+0.8", "L1-L4". Convert to the
; numeric forms the report builder expects:
;   bmd     → numeric text g/cm² (e.g. 0.853)
;   score   → signed numeric text (e.g. -1.5, +0.8)
;   level   → "L<a>-L<b>" string
; Returns "" if the input could not be parsed.
; ───────────────────────────────────────────────────────────────────────────
BMD_ParseFloat(s) {
    s := RegExReplace(s, "\x{2212}", "-")   ; normalize Unicode minus sign → ASCII hyphen
    s := RegExReplace(s, "[^\d\.\+\-]", "")
    if (s = "")
        return ""
    ; Accept trailing decimal ("0." → 0.0) and optional leading sign
    if !RegExMatch(s, "^[\+\-]?\d+\.?\d*$", m)
        return ""
    return m
}

BMD_ParseLevel(s) {
    if RegExMatch(s, "i)L\s*(\d)\s*[-–to]+\s*L?\s*(\d)", m)
        return "L" m1 "-L" m2
    return ""
}

; ───────────────────────────────────────────────────────────────────────────
; Report builder
;
; Builds the BMD report text from a typed-values map and returns a result
; object with `.text` and `.spans` (list of [start, length, kind] triples,
; 0-based character offsets into `.text`). The report wording mirrors the
; existing `bmd:` label in YCH_BMD.ahk so handwritten and OCR-driven runs
; produce identical output.
;
; parsed schema:
;   subtype = "lumbar" | "hip_r" | "hip_l" | "whole" | "sarco"
;   lumbar : { level, bmd, score, useZ }
;   hip_*  : { side, fn_bmd, fn_score, fn_useZ, total_bmd, total_score, total_useZ }
;   whole  : { bmd, score, useZ }
;   sarco  : { fat_pct, lean_kg, almi }      ; report builder TODO
; ───────────────────────────────────────────────────────────────────────────
BMD_BuildReport(subtype, p, append_report := false, oldReport := "") {
    spans := []
    body := ""
    minT := 999, minZ := 999

    if (subtype = "lumbar") {
        level := (p.level != "") ? p.level : "L1-L4"
        bmd := p.bmd, score := p.score, useZ := !!p.useZ
        if (useZ)
            minZ := Min(minZ, score)
        else
            minT := Min(minT, score)
        bmdStr := Format("{:.3f}", bmd + 0.0)
        scoreStr := Format("{:+.1f}", score + 0.0)

        prefix := "Bone Mineral Density (BMD) of the lumbar spine with quantitative dual-energy X-ray absorptiometry shows:`n- The BMD of lumbar spine ("
        midA   := ") is "
        midB   := " g/cm2 ("
        midC   := "-score = "
        suffix := ").`n"

        body := prefix
        ; level token
        spans.Push([StrLen(body), StrLen(level), "bodypart"])
        body .= level . midA
        ; bmd token
        spans.Push([StrLen(body), StrLen(bmdStr), "number"])
        body .= bmdStr . midB . (useZ ? "Z" : "T") . midC
        ; score token
        spans.Push([StrLen(body), StrLen(scoreStr), "number"])
        body .= scoreStr . suffix
    }
    else if (subtype = "hip_r" || subtype = "hip_l") {
        side := (subtype = "hip_r") ? "right" : "left"
        fnBmd := Format("{:.3f}", p.fn_bmd + 0.0)
        totBmd := Format("{:.3f}", p.total_bmd + 0.0)
        fnScore := Format("{:+.1f}", p.fn_score + 0.0)
        totScore := Format("{:+.1f}", p.total_score + 0.0)
        if (p.fn_useZ)
            minZ := Min(minZ, p.fn_score)
        else
            minT := Min(minT, p.fn_score)
        if (p.total_useZ)
            minZ := Min(minZ, p.total_score)
        else
            minT := Min(minT, p.total_score)

        body := "Bone Mineral Density (BMD) of the "
        spans.Push([StrLen(body), StrLen(side), "bodypart"])
        body .= side . " hip with quantitative dual-energy X-ray absorptiometry shows:`n"

        body .= "- The BMD of femoral neck is "
        spans.Push([StrLen(body), StrLen(fnBmd), "number"])
        body .= fnBmd . " g/cm2 (" . (p.fn_useZ ? "Z" : "T") . "-score = "
        spans.Push([StrLen(body), StrLen(fnScore), "number"])
        body .= fnScore . ").`n"

        body .= "- The total BMD of "
        spans.Push([StrLen(body), StrLen(side), "bodypart"])
        body .= side . " hip is "
        spans.Push([StrLen(body), StrLen(totBmd), "number"])
        body .= totBmd . " g/cm2 (" . (p.total_useZ ? "Z" : "T") . "-score = "
        spans.Push([StrLen(body), StrLen(totScore), "number"])
        body .= totScore . ").`n"
    }
    else if (subtype = "whole") {
        bmdStr := Format("{:.3f}", p.bmd + 0.0)
        scoreStr := Format("{:+.1f}", p.score + 0.0)
        if (p.useZ)
            minZ := Min(minZ, p.score)
        else
            minT := Min(minT, p.score)

        body := "Bone Mineral Density (BMD) of the "
        spans.Push([StrLen(body), StrLen("whole body"), "bodypart"])
        body .= "whole body with quantitative dual-energy X-ray absorptiometry shows:`n- The BMD of "
        spans.Push([StrLen(body), StrLen("whole body"), "bodypart"])
        body .= "whole body is "
        spans.Push([StrLen(body), StrLen(bmdStr), "number"])
        body .= bmdStr . " g/cm2 (" . (p.useZ ? "Z" : "T") . "-score = "
        spans.Push([StrLen(body), StrLen(scoreStr), "number"])
        body .= scoreStr . ").`n"
    }
    else if (subtype = "sarco") {
        SetFormat, FloatFast, 0.1
        hasFat  := (p.fat_pct != "")
        hasLean := (p.lean_kg != "")
        hasAlmi := (p.almi    != "")
        fatStr  := hasFat  ? (p.fat_pct + 0.0) : "___"
        leanStr := hasLean ? (p.lean_kg + 0.0) : "___"
        almiStr := hasAlmi ? (p.almi    + 0.0) : "___"

        body := "Body composition was performed by dual-energy X-ray absorptiometry (DXA).`n`nFindings:`n- Total Body % fat: "
        if (hasFat)
            spans.Push([StrLen(body), StrLen(fatStr), "number"])
        body .= fatStr . " %`n(overweight: male>23 %, female>35 %; obese: male>25%, female>38%)`n- Total lean mass: "
        if (hasLean)
            spans.Push([StrLen(body), StrLen(leanStr), "number"])
        body .= leanStr . " kg`n- Appendicular lean mass index: "
        if (hasAlmi)
            spans.Push([StrLen(body), StrLen(almiStr), "number"])
        body .= almiStr . " kg/m^2`n(sarcopenia: male<7 kg/m^2, female<5.4 kg/m^2)`n"
        ; sarco does not feed minT/minZ; impression comes from whole body BMD in combined DXA report
    }

    impression := BMD_ImpressionFor(minT, minZ, subtype, p)
    impPrefix := "`nImpression:`n"
    prefix := (append_report && oldReport != "" ? oldReport : "")
    if (prefix != "") {
        offset := StrLen(prefix)
        for i, span in spans
            spans[i] := [span[1] + offset, span[2], span[3]]
    }
    text := prefix body
    if (impression != "") {
        text .= impPrefix
        spans.Push([StrLen(text), StrLen(impression), "impression"])
        text .= impression
    }
    return { text: text, spans: spans, minT: minT, minZ: minZ }
}

BMD_ImpressionFor(t, z, subtype, p) {
    if (subtype = "sarco")
        return ""   ; combined DXA report uses whole body BMD impression; standalone sarco has no auto-impression
    if (t <= -2.5)
        return "Osteoporosis. (T-score <= -2.5)"
    if (t < -1)
        return "Osteopenia. (-2.5 < T-score < -1)"
    if (t < 2)
        return "Normal."
    if (t != 999)
        return "High BMD."
    if (z < -2)
        return "Below the expected range for age. (Z-score < -2)"
    if (z != 999)
        return "Normal."
    return ""
}

; ───────────────────────────────────────────────────────────────────────────
; OCR map → typed parsed object expected by BMD_BuildReport
; Returns "" if a required field could not be parsed.
; ───────────────────────────────────────────────────────────────────────────
BMD_OCR_ToParsed(ocr) {
    if !IsObject(ocr)
        return ""
    subtype := ocr._subtype
    if (subtype = "lumbar") {
        bmd := BMD_ParseFloat(ocr.bmd)
        scoreT := BMD_ParseFloat(ocr.tscore)
        scoreZ := BMD_ParseFloat(ocr.zscore)
        if (bmd = "")
            return ""
        useZ := (scoreT = "" && scoreZ != "")
        return { level: BMD_ParseLevel(ocr.level), bmd: bmd
               , score: (useZ ? scoreZ : scoreT), useZ: useZ }
    }
    if (subtype = "hip_r" || subtype = "hip_l") {
        fnB := BMD_ParseFloat(ocr.fn_bmd), fnT := BMD_ParseFloat(ocr.fn_tscore), fnZ := BMD_ParseFloat(ocr.fn_zscore)
        toB := BMD_ParseFloat(ocr.total_bmd), toT := BMD_ParseFloat(ocr.total_tscore), toZ := BMD_ParseFloat(ocr.total_zscore)
        if (fnB = "" || toB = "")
            return ""
        fnUseZ := (fnT = "" && fnZ != "")
        toUseZ := (toT = "" && toZ != "")
        return { side: (subtype = "hip_r" ? "r" : "l")
               , fn_bmd: fnB, fn_score: (fnUseZ ? fnZ : fnT), fn_useZ: fnUseZ
               , total_bmd: toB, total_score: (toUseZ ? toZ : toT), total_useZ: toUseZ }
    }
    if (subtype = "whole") {
        bmd := BMD_ParseFloat(ocr.bmd)
        scoreT := BMD_ParseFloat(ocr.tscore), scoreZ := BMD_ParseFloat(ocr.zscore)
        if (bmd = "")
            return ""
        useZ := (scoreT = "" && scoreZ != "")
        return { bmd: bmd, score: (useZ ? scoreZ : scoreT), useZ: useZ }
    }
    if (subtype = "sarco") {
        return { fat_pct: BMD_ParseFloat(ocr.fat_pct)
               , lean_kg: BMD_ParseFloat(ocr.lean_kg)
               , almi:    BMD_ParseFloat(ocr.almi) }
    }
    if (subtype = "dxa") {
        fat   := BMD_ParseFloat(ocr.fat_pct)
        leanG := BMD_ParseFloat(ocr.lean_kg_g)
        leanKg := (leanG != "") ? Round(leanG / 1000.0, 1) : ""
        almi  := BMD_ParseFloat(ocr.almi)
        bmd   := BMD_ParseFloat(ocr.bmd)
        tscore := BMD_ParseFloat(ocr.tscore)
        genderRaw := Trim(ocr.gender)
        gender := (genderRaw ~= "i)^f") ? "female" : "male"
        genderConfident := !!(genderRaw ~= "i)male|female")
        return { fat_pct: fat, lean_kg: leanKg, almi: almi, bmd: bmd, tscore: tscore
               , gender: gender, genderConfident: genderConfident }
    }
    return ""
}

; ───────────────────────────────────────────────────────────────────────────
; Scintilla highlight for OCR-derived spans in the simpleRIS edit
; Indicator slots: 8 = number (yellow), 9 = bodypart (cyan), 10 = impression (green)
; ───────────────────────────────────────────────────────────────────────────
global BMD_HL_NUMBER     := 8
global BMD_HL_BODYPART   := 9
global BMD_HL_IMPRESSION := 10

BMD_InitIndicators(editHwnd) {
    static initialized := {}
    if initialized.HasKey(editHwnd)
        return
    ; SCI_INDICSETSTYLE = 2080, SCI_INDICSETFORE = 2082
    ; Style 6 = INDIC_ROUNDBOX (semi-transparent fill)
    SendMessage, 2080, % BMD_HL_NUMBER,     6,, ahk_id %editHwnd%
    SendMessage, 2082, % BMD_HL_NUMBER,     0x00FFFF,, ahk_id %editHwnd%   ; yellow (BGR)
    SendMessage, 2080, % BMD_HL_BODYPART,   6,, ahk_id %editHwnd%
    SendMessage, 2082, % BMD_HL_BODYPART,   0xFFFF00,, ahk_id %editHwnd%   ; cyan
    SendMessage, 2080, % BMD_HL_IMPRESSION, 6,, ahk_id %editHwnd%
    SendMessage, 2082, % BMD_HL_IMPRESSION, 0x00C800,, ahk_id %editHwnd%   ; green
    initialized[editHwnd] := true
}

BMD_ApplyHighlights(editHwnd, text, spans) {
    if (!editHwnd || !IsObject(spans))
        return
    BMD_InitIndicators(editHwnd)
    ; Scintilla works in UTF-8 byte offsets. The spans we built use AHK's
    ; native StrLen (UTF-16 code units). Convert each offset by encoding the
    ; preceding text to UTF-8.
    for _, span in spans {
        kind := span[3]
        ind := (kind = "number") ? BMD_HL_NUMBER
             : (kind = "bodypart") ? BMD_HL_BODYPART
             : (kind = "impression") ? BMD_HL_IMPRESSION : 0
        if (!ind)
            continue
        bytePos := BMD_Utf8ByteOffset(text, span[1])
        byteLen := BMD_Utf8ByteOffset(text, span[1] + span[2]) - bytePos
        ; SCI_SETINDICATORCURRENT = 2500, SCI_INDICATORFILLRANGE = 2504
        SendMessage, 2500, %ind%, 0,, ahk_id %editHwnd%
        SendMessage, 2504, %bytePos%, %byteLen%,, ahk_id %editHwnd%
    }
}

BMD_Utf8ByteOffset(text, charOffset) {
    if (charOffset <= 0)
        return 0
    sub := SubStr(text, 1, charOffset)
    return BMD_Utf8ByteLen(sub)
}

BMD_Utf8ByteLen(s) {
    if (s = "")
        return 0
    n := StrPut(s, "UTF-8")
    return (n > 0) ? n - 1 : 0  ; minus terminating null
}

; ───────────────────────────────────────────────────────────────────────────
; Interactive calibration (two-click rect per field)
;
; Walks every field in the schema for `subtype`. For each, prompts the user
; to click top-left then bottom-right of the value's bounding box on the
; INFINITT viewport, previews the rect, runs a test OCR, then stores the
; ratio in BMD_OCR_Regions.ini under the local-or-RDP profile section.
; Press Esc at any time to abort.
; ───────────────────────────────────────────────────────────────────────────
BMD_CalibrateSubtype(subtype) {
    global BMD_OCR_SCHEMA
    if !BMD_OCR_SCHEMA.HasKey(subtype) {
        ToolTip, % "Unknown BMD subtype: " subtype
        Sleep, 1500
        ToolTip
        return false
    }
    vp := BMD_ResolveViewport()
    if !IsObject(vp) {
        ToolTip, INFINITT viewport not found
        Sleep, 1500
        ToolTip
        return false
    }

    aborted := false
    for _, fieldName in BMD_OCR_SCHEMA[subtype] {
        rect := BMD_CaptureScreenRect(subtype, fieldName)
        if (rect = "ABORT") {
            aborted := true
            break
        }
        if !IsObject(rect)
            continue
        ratio := BMD_ScreenRectToRatio(vp.viewport, rect[1], rect[2], rect[3], rect[4])
        if !IsObject(ratio) {
            ToolTip, % "Invalid viewport size; skipping " fieldName
            Sleep, 1000
            ToolTip
            continue
        }
        BMD_SaveRatio(subtype, fieldName, ratio)

        ; Preview + test OCR so the user can see what was captured
        region := BMD_RatioToRegion(vp.viewport, ratio)
        VarSetCapacity(pt, 8, 0)
        DllCall("ClientToScreen", "ptr", vp.viewport, "ptr", &pt)
        sx := NumGet(pt, 0, "int") + region[1]
        sy := NumGet(pt, 4, "int") + region[2]
        ShowOCRRegion(sx, sy, region[3], region[4], 600)
        sample := OCR_ReadText(region, vp.viewport)
        ToolTip, % "Saved " subtype "." fieldName "`nOCR sample: " Trim(sample)
        Sleep, 900
        ToolTip
    }
    if (aborted) {
        ToolTip, Calibration aborted
        Sleep, 800
        ToolTip
        return false
    }
    ToolTip, % "Calibration complete: " subtype
    Sleep, 1200
    ToolTip
    return true
}

BMD_CaptureScreenRect(subtype, fieldName) {
    CoordMode, ToolTip, Screen
    CoordMode, Mouse, Screen
    ToolTip, % "Calibrate " subtype "." fieldName "`nClick TOP-LEFT corner (Esc=abort, F2=skip)"
    pt1 := BMD_WaitForClick()
    if (pt1 = "ABORT") {
        ToolTip
        return "ABORT"
    }
    if (pt1 = "SKIP") {
        ToolTip
        return ""
    }
    ToolTip, % "Calibrate " subtype "." fieldName "`nClick BOTTOM-RIGHT corner (Esc=abort)"
    pt2 := BMD_WaitForClick()
    ToolTip
    if (pt2 = "ABORT")
        return "ABORT"
    if (pt2 = "SKIP")
        return ""
    return [pt1.x, pt1.y, pt2.x, pt2.y]
}

BMD_WaitForClick() {
    Loop {
        if GetKeyState("Escape", "P") {
            KeyWait, Escape
            return "ABORT"
        }
        if GetKeyState("F2", "P") {
            KeyWait, F2
            return "SKIP"
        }
        if GetKeyState("LButton", "P") {
            CoordMode, Mouse, Screen
            MouseGetPos, mx, my
            KeyWait, LButton
            return { x: mx, y: my }
        }
        Sleep, 20
    }
}

; ───────────────────────────────────────────────────────────────────────────
; DXA combined OCR — multi-viewport helpers
; ───────────────────────────────────────────────────────────────────────────

; Returns the nth INFINITT window (G3PACS.exe) sorted left-to-right by screen X (0-indexed).
; n=0 → leftmost (2nd physical display), n=1 → next (3rd physical display).
GetNthINFINITTHwnd(n) {
    return GetNthInfinittViewerHwnd(n, true)
}

; Like BMD_ResolveViewport() but for the nth INFINITT window.
BMD_ResolveViewportN(n) {
    parentHwnd := GetNthINFINITTHwnd(n)
    if (!parentHwnd)
        return ""
    viewportHwnd := OCR_GetViewportHwnd(parentHwnd, "Img")
    if (!viewportHwnd)
        viewportHwnd := parentHwnd
    return { parent: parentHwnd, viewport: viewportHwnd }
}

; Reads all DXA fields using per-field viewport selection from BMD_DXA_FIELD_DISPLAY.
; When showOverlay=true, hides any old persistent ROI frames before OCR, then shows
; the current ROI frames once after OCR so they do not contaminate tight captures.
; Returns an OCR result object with _subtype="dxa" and _missing list.
BMD_DXA_OCR_ReadAll(showOverlay := true) {
    global BMD_DXA_FIELD_DISPLAY, BMD_DXA_FRAME_COUNT
    vpCache := {}
    out := { _subtype: "dxa", _missing: [] }
    ; Pass 1 — resolve every viewport and region before reading anything
    fNames := [], fRegions := [], fViewports := [], frameList := []
    for fieldName, dispIdx in BMD_DXA_FIELD_DISPLAY {
        if !vpCache.HasKey(dispIdx) {
            vp := BMD_ResolveViewportN(dispIdx)
            vpCache[dispIdx] := IsObject(vp) ? vp : ""
        }
        vp := vpCache[dispIdx]
        if !IsObject(vp) {
            out[fieldName] := ""
            out._missing.Push(fieldName)
            continue
        }
        ratio := BMD_LoadRatio("dxa", fieldName)
        if !IsObject(ratio) {
            out[fieldName] := ""
            out._missing.Push(fieldName)
            continue
        }
        region := BMD_RatioToRegion(vp.viewport, ratio)
        VarSetCapacity(pt, 8, 0)
        DllCall("ClientToScreen", "ptr", vp.viewport, "ptr", &pt)
        sx := NumGet(pt, 0, "int") + region[1]
        sy := NumGet(pt, 4, "int") + region[2]
        fNames.Push(fieldName)
        fRegions.Push(region)
        fViewports.Push(vp.viewport)
        frameList.Push({ x: sx, y: sy, w: region[3], h: region[4] })
    }
    ; Frames are AlwaysOnTop windows and can appear in WinRT captures, so make
    ; sure no persistent overlay is present while OCR reads the PACS viewport.
    if (showOverlay) {
        BMD_HideDXAFrames(BMD_DXA_FRAME_COUNT)
        BMD_DXA_FRAME_COUNT := 0
        Sleep, 80   ; let DWM composite the hide before capture
    }
    ; Pass 2 — OCR every resolved field with no overlays on screen
    for i, fieldName in fNames {
        text := BMD_DXA_OCR_ReadText(fieldName, fRegions[i], fViewports[i])
        out[fieldName] := Trim(text)
    }
    ; Show frames persistently — they remain until the study changes or script reloads
    if (showOverlay && frameList.Length() > 0) {
        BMD_DXA_FRAME_COUNT := BMD_ShowDXAFrames(frameList)
    }
    return out
}

; Show up to 6 simultaneous red border frames at the given screen positions.
; Each frame uses its own named GUI (BMDFrm1..BMDFrmN) so all are visible at once.
; Returns the count of frames shown.
BMD_ShowDXAFrames(frameList) {
    border := 2
    n := frameList.Length()
    Loop, %n% {
        i := A_Index
        f := frameList[i]
        name := "BMDFrm" i
        w := f.w, h := f.h, x := f.x, y := f.y
        if (w < 1 || h < 1)
            continue
        innerW := w - (border * 2)
        innerH := h - (border * 2)
        if (innerW < 1)
            innerW := 1
        if (innerH < 1)
            innerH := 1
        Gui, %name%: +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20
        Gui, %name%: Color, Red
        hFrm := WinExist()
        WinSet, Region, 0-0 %w%-0 %w%-%h% 0-%h% 0-0  %border%-%border% %innerW%-%border% %innerW%-%innerH% %border%-%innerH% %border%-%border%, ahk_id %hFrm%
        Gui, %name%: Show, x%x% y%y% w%w% h%h% NoActivate
    }
    return n
}

BMD_HideDXAFrames(n) {
    Loop, %n% {
        name := "BMDFrm" A_Index
        Gui, %name%: Hide
    }
}

; Quick OCR test: reads all 6 DXA fields with live frame overlay, then shows
; raw OCR values in a MsgBox. Does NOT re-seed coords — use ^!+n for that.
BMD_DXA_OCR_Test() {
    ocr := BMD_DXA_OCR_ReadAll(true)
    if !IsObject(ocr) {
        MsgBox, 16, DXA OCR Test, No INFINITT viewports found.
        return
    }
    msg := "DXA OCR Test Results`n" . "═══════════════════`n"
    global BMD_DXA_FIELD_DISPLAY
    for fieldName, dispIdx in BMD_DXA_FIELD_DISPLAY {
        val := ocr[fieldName]
        marker := (val = "") ? " [EMPTY]" : ""
        msg .= fieldName . " (disp" dispIdx "): [" val "]" marker "`n"
    }
    if (ocr._missing.Length() > 0)
        msg .= "`nMissing calibration: " BMD_JoinList(ocr._missing)
    MsgBox, % msg
}

; Saves a BMP screenshot of every DXA ROI region plus a text log, then opens
; the debug folder. Use ^!+g to invoke.
; Screenshots use logical screen coords so saved PNGs match the red ROI frames.
; Hides persistent overlay frames before OCR so they do not corrupt the capture.
BMD_DXA_OCR_Debug() {
    global BMD_DXA_FIELD_DISPLAY, BMD_DXA_FRAME_COUNT
    debugDir := A_ScriptDir "\debug_dxa"
    FileCreateDir, %debugDir%
    LogRetention_DeleteFilesOlderThan(debugDir)
    LogRetention_DeleteDirectoriesOlderThan(debugDir, "^almi_variants_\d{14}$")
    FileDelete, % debugDir "\*.png"
    FileDelete, % debugDir "\*.bmp"
    BMD_HideDXAFrames(BMD_DXA_FRAME_COUNT)
    Sleep, 80
    vpCache := {}
    entries := []
    SetFormat, FloatFast, 0.5
    for fieldName, dispIdx in BMD_DXA_FIELD_DISPLAY {
        if !vpCache.HasKey(dispIdx) {
            vp := BMD_ResolveViewportN(dispIdx)
            vpCache[dispIdx] := IsObject(vp) ? vp : ""
        }
        vp := vpCache[dispIdx]
        ratio := BMD_LoadRatio("dxa", fieldName)
        e := { field: fieldName, disp: dispIdx
             , hasVp: IsObject(vp), hasRatio: IsObject(ratio)
             , vpHwnd: IsObject(vp) ? vp.viewport : 0 }
        if (IsObject(vp) && IsObject(ratio)) {
            region := BMD_RatioToRegion(vp.viewport, ratio)
            cap := GetCaptureRectFromClient(vp.viewport, region[1], region[2], region[3], region[4])
            e.cx := region[1], e.cy := region[2], e.cw := region[3], e.ch := region[4]
            e.sx := cap.screenX, e.sy := cap.screenY, e.sw := cap.screenW, e.sh := cap.screenH
            e.px := cap.x, e.py := cap.y, e.pw := cap.w, e.ph := cap.h
            e.scale := cap.scale
            e.rx := ratio[1], e.ry := ratio[2], e.rw := ratio[3], e.rh := ratio[4]
            e.ocr := Trim(BMD_DXA_OCR_ReadText(fieldName, region, vp.viewport))
        } else {
            e.sx := 0, e.sy := 0, e.sw := 0, e.sh := 0
            e.cx := 0, e.cy := 0, e.cw := 0, e.ch := 0
            e.px := 0, e.py := 0, e.pw := 0, e.ph := 0
            e.scale := 1.0, e.ocr := "N/A"
        }
        entries.Push(e)
    }
    for _, e in entries {
        if (e.sw > 0 && e.sh > 0) {
            BMD_SaveDXADebugCapture(debugDir, e.field, e.vpHwnd, e.cx, e.cy, e.cw, e.ch)
        }
    }
    log := "DXA OCR Debug — " A_Now "`n"
    msg := "DXA OCR Debug`n══════════════════════`n"
    for _, e in entries {
        line := e.field " (disp" e.disp " hwnd=" e.vpHwnd " scale=" (e.scale+0.0) "):`n"
        if (e.hasVp && e.hasRatio) {
            line .= "  logical : " e.sx "," e.sy "  " e.sw "x" e.sh "`n"
            line .= "  physical: " e.px "," e.py "  " e.pw "x" e.ph "`n"
            line .= "  ratio   : " (e.rx+0.0) "," (e.ry+0.0) "  " (e.rw+0.0) "x" (e.rh+0.0) "`n"
            line .= "  OCR     : [" e.ocr "]`n"
        } else {
            line .= "  " (e.hasVp ? "" : "NO VIEWPORT  ") (e.hasRatio ? "" : "NO RATIO SAVED") "`n"
        }
        msg .= line
        log .= line
    }
    msg .= "`nBMPs + log → " debugDir
    logFile := debugDir "\debug.log"
    FileDelete, %logFile%
    FileAppend, %log%, %logFile%, UTF-8
    MsgBox, % msg
    Run, explorer "%debugDir%"
}

BMD_SaveDXADebugCapture(debugDir, fieldName, hwnd, x, y, w, h) {
    if (!hwnd)
        return
    pad := 6   ; client-coordinate padding around the saved diagnostic crop
    x := x - pad
    y := y - pad
    w := w + pad * 2
    h := h + pad * 2
    if (w < 1 || h < 1)
        return

    file := debugDir "\" fieldName ".bmp"
    FileDelete, %file%
    hBM := _OWR_CaptureWindow(x, y, w, h, hwnd, Max(1, w), Max(1, h))
    if (hBM) {
        _OWR_SaveBitmap(hBM, file)
        DllCall("DeleteObject", "Ptr", hBM)
    }

    scaleFile := debugDir "\" fieldName "_scale4.bmp"
    FileDelete, %scaleFile%
    hBM2 := _OWR_CaptureWindow(x, y, w, h, hwnd, Max(40, w * 4), Max(40, h * 4))
    if (hBM2) {
        _OWR_SaveBitmap(hBM2, scaleFile)
        DllCall("DeleteObject", "Ptr", hBM2)
    }
}

BMD_DXA_OCR_ReadText(fieldName, region, hwnd) {
    text := Trim(_OWR_OcrWindowRectViaWorker(hwnd, region[1], region[2], region[3], region[4], "en-US"))
    if (BMD_DXA_OCRAcceptable(fieldName, text))
        return BMD_DXA_NormalizeOCRText(fieldName, text)

    padded := BMD_DXA_PaddedRegion(hwnd, region, fieldName)
    if IsObject(padded) {
        text2 := Trim(_OWR_OcrWindowRectViaWorker(hwnd, padded[1], padded[2], padded[3], padded[4], "en-US"))
        if (BMD_DXA_OCRAcceptable(fieldName, text2))
            return BMD_DXA_NormalizeOCRText(fieldName, text2)
    }

    return BMD_DXA_NormalizeOCRText(fieldName, text)
}

BMD_DXA_OCRAcceptable(fieldName, text) {
    if (text = "")
        return false
    if (fieldName = "tscore" && text ~= "^[\+\-]?\d+\.$")
        return false
    return true
}

BMD_DXA_NormalizeOCRText(fieldName, text) {
    text := Trim(text)
    if (fieldName = "tscore" && text ~= "^[\+\-]?\d+\.$")
        text .= "0"
    return text
}

BMD_DXA_PaddedRegion(hwnd, region, fieldName) {
    global BMD_DXA_FIELD_OCR_PADDING
    if !BMD_DXA_FIELD_OCR_PADDING.HasKey(fieldName)
        return ""

    pad := BMD_DXA_FIELD_OCR_PADDING[fieldName]
    left := pad[1], top := pad[2], right := pad[3], bottom := pad[4]

    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "ptr", hwnd, "ptr", &rc)
    clW := NumGet(rc, 8, "int"), clH := NumGet(rc, 12, "int")
    if (clW <= 0 || clH <= 0)
        return ""

    x1 := Max(0, region[1] - left)
    y1 := Max(0, region[2] - top)
    x2 := Min(clW, region[1] + region[3] + right)
    y2 := Min(clH, region[2] + region[4] + bottom)
    if (x2 <= x1 || y2 <= y1)
        return ""
    return [x1, y1, x2 - x1, y2 - y1]
}

BMD_DXA_DebugAlmiCaptureVariants() {
    global BMD_DXA_FIELD_DISPLAY
    fieldName := "almi"
    if !BMD_DXA_FIELD_DISPLAY.HasKey(fieldName) {
        MsgBox, 16, ALMI Debug, Missing BMD_DXA_FIELD_DISPLAY.almi
        return
    }

    dispIdx := BMD_DXA_FIELD_DISPLAY[fieldName]
    vp := BMD_ResolveViewportN(dispIdx)
    ratio := BMD_LoadRatio("dxa", fieldName)
    if (!IsObject(vp) || !IsObject(ratio)) {
        MsgBox, 16, ALMI Debug, % "Missing viewport or ratio for almi`nviewport=" IsObject(vp) " ratio=" IsObject(ratio)
        return
    }

    region := BMD_RatioToRegion(vp.viewport, ratio)
    cap := GetCaptureRectFromClient(vp.viewport, region[1], region[2], region[3], region[4])
    VarSetCapacity(cr, 16, 0)
    DllCall("GetClientRect", "ptr", vp.viewport, "ptr", &cr)
    cW := NumGet(cr, 8, "int"), cH := NumGet(cr, 12, "int")

    debugRoot := A_ScriptDir "\debug_dxa"
    FileCreateDir, %debugRoot%
    LogRetention_DeleteDirectoriesOlderThan(debugRoot, "^almi_variants_\d{14}$")
    debugDir := debugRoot "\almi_variants_" A_Now
    FileCreateDir, %debugDir%
    ShowOCRRegion(cap.screenX, cap.screenY, cap.screenW, cap.screenH, 800)

    log := "ALMI capture variants — " A_Now "`n"
        . "viewport hwnd=" vp.viewport " display=" dispIdx " client=" cW "x" cH "`n"
        . "client region=" region[1] "," region[2] "," region[3] "," region[4] "`n"
        . "logical screen=" cap.screenX "," cap.screenY "," cap.screenW "," cap.screenH "`n"
        . "physical screen=" cap.x "," cap.y "," cap.w "," cap.h " scale=" cap.scale "`n"
        . "ratio=" ratio[1] "," ratio[2] "," ratio[3] "," ratio[4] "`n`n"

    BMD_DXA_SaveVariant_GDI(debugDir, "01_screen_logical_gdi", cap.screenX, cap.screenY, cap.screenW, cap.screenH, log)
    BMD_DXA_SaveVariant_GDI(debugDir, "02_screen_logical_gdi_scale4", cap.screenX, cap.screenY, cap.screenW, cap.screenH, log, 4)
    BMD_DXA_SaveVariant_GDI(debugDir, "03_screen_physical_gdi", cap.x, cap.y, cap.w, cap.h, log)
    BMD_DXA_SaveVariant_Window(debugDir, "04_window_print_client", vp.viewport, region[1], region[2], region[3], region[4], log)
    BMD_DXA_SaveVariant_Window(debugDir, "05_window_print_client_scale4", vp.viewport, region[1], region[2], region[3], region[4], log, 4)
    BMD_DXA_SaveVariant_PowerShell(debugDir, "06_powershell_logical", cap.screenX, cap.screenY, cap.screenW, cap.screenH, false, log)
    BMD_DXA_SaveVariant_PowerShell(debugDir, "07_powershell_logical_dpiaware", cap.screenX, cap.screenY, cap.screenW, cap.screenH, true, log)

    textWindow := BMD_DXA_OCR_ReadText(fieldName, region, vp.viewport)
    textScreen := OCR_WinRT_GetText(cap.screenX, cap.screenY, cap.screenW, cap.screenH, 0, 4)
    textPhysical := OCR_WinRT_GetText(cap.x, cap.y, cap.w, cap.h, 0, 4)
    log .= "OCR_WINDOW_RECT worker: [" textWindow "]`n"
    log .= "OCR screen logical: [" textScreen "]`n"
    log .= "OCR screen physical: [" textPhysical "]`n"

    logFile := debugDir "\summary.txt"
    FileAppend, %log%, %logFile%, UTF-8
    MsgBox, 64, ALMI Debug, % "Saved ALMI capture variants:`n" debugDir
    Run, explorer "%debugDir%"
}

BMD_DXA_SaveVariant_GDI(debugDir, name, x, y, w, h, ByRef log, scale := 1) {
    sW := Max(1, w * scale), sH := Max(1, h * scale)
    file := debugDir "\" name ".bmp"
    hBM := _OWR_CaptureRect(x, y, w, h, sW, sH)
    if (hBM) {
        _OWR_SaveBitmap(hBM, file)
        text := BMD_DXA_OCRBitmapText(hBM, sW, sH)
        DllCall("DeleteObject", "Ptr", hBM)
        log .= name " saved " w "x" h " -> " sW "x" sH " OCR=[" text "]`n"
        FileAppend, %text%, % debugDir "\" name ".txt", UTF-8
    } else {
        log .= name " FAILED capture`n"
    }
}

BMD_DXA_SaveVariant_Window(debugDir, name, hwnd, x, y, w, h, ByRef log, scale := 1) {
    sW := Max(1, w * scale), sH := Max(1, h * scale)
    file := debugDir "\" name ".bmp"
    hBM := _OWR_CaptureWindow(x, y, w, h, hwnd, sW, sH)
    if (hBM) {
        _OWR_SaveBitmap(hBM, file)
        text := BMD_DXA_OCRBitmapText(hBM, sW, sH)
        DllCall("DeleteObject", "Ptr", hBM)
        log .= name " saved client " x "," y "," w "," h " -> " sW "x" sH " OCR=[" text "]`n"
        FileAppend, %text%, % debugDir "\" name ".txt", UTF-8
    } else {
        log .= name " FAILED capture`n"
    }
}

BMD_DXA_SaveVariant_PowerShell(debugDir, name, x, y, w, h, dpiAware, ByRef log) {
    file := debugDir "\" name ".png"
    StringReplace, fileEsc, file, \, \\, All
    psFile := debugDir "\" name ".ps1"
    ps := ""
    if (dpiAware) {
        ps .= "Add-Type -TypeDefinition @'`n"
        ps .= "using System; using System.Runtime.InteropServices;`n"
        ps .= "public class DpiH { [DllImport(""user32.dll"")] public static extern bool SetProcessDPIAware(); }`n"
        ps .= "'@`n[DpiH]::SetProcessDPIAware() | Out-Null`n"
    }
    ps .= "Add-Type -Assembly System.Windows.Forms,System.Drawing`n"
    ps .= "$b=New-Object System.Drawing.Bitmap(" w "," h ");"
    ps .= "$g=[System.Drawing.Graphics]::FromImage($b);"
    ps .= "$g.CopyFromScreen(" x "," y ",0,0,[System.Drawing.Size]::new(" w "," h "));"
    ps .= "$b.Save('" fileEsc "');$g.Dispose();$b.Dispose()`n"
    FileDelete, %psFile%
    FileAppend, %ps%, %psFile%, UTF-8
    RunWait, powershell -noprofile -executionpolicy bypass -file "%psFile%",, Hide
    log .= name " saved via PowerShell x=" x " y=" y " w=" w " h=" h " dpiAware=" dpiAware "`n"
}

BMD_DXA_OCRBitmapText(hBM, w, h) {
    global _OWR_LastBitmap
    if (!hBM)
        return ""
    hCopy := DllCall("CopyImage", "Ptr", hBM, "UInt", 0, "Int", 0, "Int", 0, "UInt", 0x2000, "Ptr")
    if (!hCopy)
        return ""
    if !_OWR_PreprocessBitmap(hCopy, w, h) {
        DllCall("DeleteObject", "Ptr", hCopy)
        return ""
    }
    DllCall("DeleteObject", "Ptr", hCopy)
    return _OWR_OcrBitmapViaWorker(_OWR_LastBitmap)
}

; ───────────────────────────────────────────────────────────────────────────
; ROI debug helper — reusable tool for confirming OCR region calibrations.
; Included here so it shares the same OCR infrastructure (no extra #include
; needed in the top-level script).
; ───────────────────────────────────────────────────────────────────────────
#Include %A_LineFile%\..\BMD_OCR_ROI_Debug.ahk

; Gender-aware body-composition impression string.
; Returns sentences about overweight/obesity and sarcopenia (or "No ..." if within normal).
BMD_DXA_BodyCompImpression(fatPct, almi, gender) {
    isMale := (gender != "female")
    out := ""
    if (fatPct != "") {
        owThresh := isMale ? 23 : 35
        obThresh := isMale ? 25 : 38
        gStr := isMale ? "male" : "female"
        if (fatPct + 0 >= obThresh)
            out := "Obesity (" gStr " >= " obThresh "% body fat)."
        else if (fatPct + 0 >= owThresh)
            out := "Overweight (" gStr " >= " owThresh "% body fat)."
        else
            out := "No overweight."
    }
    if (almi != "") {
        sarcoThresh := isMale ? 7.0 : 5.4
        gStr := isMale ? "male" : "female"
        sarcoStr := isMale ? "7" : "5.4"
        sep := (out != "") ? " " : ""
        if (almi + 0 < sarcoThresh)
            out .= sep "Sarcopenia (" gStr " < " sarcoStr " kg/m^2)."
        else
            out .= sep "No sarcopenia."
    }
    return out
}

; Builds the combined DXA report (body composition + whole body BMD) with highlight spans.
; p fields: fat_pct, lean_kg, almi, bmd, tscore (any may be "" if OCR failed)
; gender: "male" or "female"
BMD_BuildDXAReport(p, gender) {
    spans := []
    missing := []
    hasFat  := (p.fat_pct != "")
    hasLean := (p.lean_kg != "")
    hasAlmi := (p.almi    != "")
    hasBmd  := (p.bmd     != "")
    hasT    := (p.tscore  != "")
    fatStr  := hasFat  ? BMD_DXA_ReportValue(p, "fat_pct", Format("{:.1f}", p.fat_pct + 0.0)) : ""
    leanStr := hasLean ? BMD_DXA_ReportValue(p, "lean_kg", Format("{:.1f}", p.lean_kg + 0.0)) : ""
    almiStr := hasAlmi ? BMD_DXA_ReportValue(p, "almi", Format("{:.1f}", p.almi + 0.0)) : ""
    ; Keep whole-body BMD at 1+3 digit precision, e.g. 1.195.
    bmdStr  := hasBmd  ? BMD_DXA_ReportValue(p, "bmd", Format("{:.3f}", p.bmd + 0.0)) : ""
    tStr    := hasT    ? BMD_DXA_ReportValue(p, "tscore", Format("{:+.1f}", p.tscore + 0.0)) : ""

    body := "Body composition and bone mineral density of the whole body was performed with quantitative dual-energy X-ray absorptiometry.`n`nFindings:`n- Total Body % fat: "
    if (hasFat)
        spans.Push([StrLen(body), StrLen(fatStr), "number"])
    else
        missing.Push({ field: "fat_pct", label: "Total Body % fat", pos: StrLen(body) })
    body .= fatStr . "%`n(overweight: male > 23%, female > 35%; obese: male > 25%, female > 38%)`n- Total lean mass: "
    if (hasLean)
        spans.Push([StrLen(body), StrLen(leanStr), "number"])
    else
        missing.Push({ field: "lean_kg", label: "Total lean mass", pos: StrLen(body) })
    body .= leanStr . " kg`n- Appendicular lean mass index: "
    if (hasAlmi)
        spans.Push([StrLen(body), StrLen(almiStr), "number"])
    else
        missing.Push({ field: "almi", label: "Appendicular lean mass index", pos: StrLen(body) })
    body .= almiStr . " kg/m^2`n(sarcopenia: male < 7 kg/m^2, female < 5.4 kg/m^2)`n- The BMD of "
    spans.Push([StrLen(body), StrLen("whole body"), "bodypart"])
    body .= "whole body is "
    if (hasBmd)
        spans.Push([StrLen(body), StrLen(bmdStr), "number"])
    else
        missing.Push({ field: "bmd", label: "Whole body BMD", pos: StrLen(body) })
    body .= bmdStr . " g/cm2 (T-score = "
    if (hasT)
        spans.Push([StrLen(body), StrLen(tStr), "number"])
    else
        missing.Push({ field: "tscore", label: "Whole body T-score", pos: StrLen(body) })
    body .= tStr . ").`n"

    tScore := hasT ? (p.tscore + 0.0) : 999
    bmdImp := (tScore <= -2.5) ? "Osteoporosis. (T-score <= -2.5)"
            : (tScore < -1)    ? "Osteopenia. (-2.5 < T-score < -1)"
            : (tScore < 2)     ? "Normal BMD."
            : (tScore != 999)  ? "High BMD."
            : ""
    bodyCompImp := BMD_DXA_BodyCompImpression(hasFat ? p.fat_pct : "", hasAlmi ? p.almi : "", gender)

    impression := bodyCompImp
    if (bmdImp != "")
        impression .= (impression != "" ? " " : "") bmdImp

    text := body
    if (impression != "") {
        text .= "`nImpression:`n"
        spans.Push([StrLen(text), StrLen(impression), "impression"])
        text .= impression
    }
    return { text: text, spans: spans, missing: missing }
}

BMD_DXA_ReportValue(p, fieldName, fallback) {
    if (IsObject(p) && IsObject(p._manualText) && p._manualText.HasKey(fieldName))
        return p._manualText[fieldName]
    return fallback
}

BMD_DXA_GetMissingParsedFields(parsed) {
    missing := []
    if (!IsObject(parsed))
        return missing
    if (parsed.fat_pct = "")
        missing.Push({ field: "fat_pct", ocrField: "fat_pct", label: "Total Body % fat", unit: "%" })
    if (parsed.lean_kg = "")
        missing.Push({ field: "lean_kg", ocrField: "lean_kg_g", label: "Total lean mass", unit: "kg" })
    if (parsed.almi = "")
        missing.Push({ field: "almi", ocrField: "almi", label: "Appendicular lean mass index", unit: "kg/m^2" })
    if (parsed.bmd = "")
        missing.Push({ field: "bmd", ocrField: "bmd", label: "Whole body BMD", unit: "g/cm2" })
    if (parsed.tscore = "")
        missing.Push({ field: "tscore", ocrField: "tscore", label: "Whole body T-score", unit: "" })
    return missing
}

BMD_DXA_PromptSingleMissing(parsed) {
    missing := BMD_DXA_GetMissingParsedFields(parsed)
    if (missing.Length() != 1)
        return false

    miss := missing[1]
    unitHint := (miss.unit != "") ? " (" miss.unit ")" : ""
    BMD_DXA_ShowMissingROI(miss.ocrField, miss.label)
    Loop {
        InputBox, raw, DXA OCR missing, % "Enter " miss.label unitHint ":",, 380, 135
        if ErrorLevel {
            BMD_DXA_HideMissingROI()
            return false
        }
        val := BMD_ParseFloat(raw)
        if (val != "")
            break
        ToolTip, % "Invalid number for " miss.label ". Try again or press Esc to leave blank."
        Sleep, 1300
        ToolTip
    }
    if !IsObject(parsed._manualText)
        parsed._manualText := {}
    parsed[miss.field] := val
    parsed._manualText[miss.field] := Trim(raw)
    BMD_DXA_HideMissingROI()
    return true
}

BMD_DXA_GetFieldScreenBox(fieldName) {
    global BMD_DXA_FIELD_DISPLAY
    if !BMD_DXA_FIELD_DISPLAY.HasKey(fieldName)
        return ""
    dispIdx := BMD_DXA_FIELD_DISPLAY[fieldName]
    vp := BMD_ResolveViewportN(dispIdx)
    ratio := BMD_LoadRatio("dxa", fieldName)
    if (!IsObject(vp) || !IsObject(ratio))
        return ""
    region := BMD_RatioToRegion(vp.viewport, ratio)
    VarSetCapacity(pt, 8, 0)
    DllCall("ClientToScreen", "ptr", vp.viewport, "ptr", &pt)
    return { x: NumGet(pt, 0, "int") + region[1]
           , y: NumGet(pt, 4, "int") + region[2]
           , w: region[3], h: region[4] }
}

BMD_DXA_ShowMissingROI(fieldName, label) {
    box := BMD_DXA_GetFieldScreenBox(fieldName)
    if !IsObject(box)
        return false

    BMD_DXA_HideMissingROI()
    x := box.x, y := box.y, w := box.w, h := box.h
    Gui, BMDMissROI:New, +AlwaysOnTop -Caption +ToolWindow +E0x20 +LastFound
    Gui, BMDMissROI:Color, Fuchsia
    Gui, BMDMissROI:Show, x%x% y%y% w%w% h%h% NoActivate, BMDMissROI
    hBox := WinExist()
    WinSet, Transparent, 85, ahk_id %hBox%

    lx := x
    ly := y - 24
    if (ly < 0)
        ly := y + h + 2
    Gui, BMDMissROILabel:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, BMDMissROILabel:Color, Black
    Gui, BMDMissROILabel:Font, s9 cFuchsia, Consolas
    Gui, BMDMissROILabel:Add, Text, x5 y3, % "Missing OCR: " label
    Gui, BMDMissROILabel:Show, x%lx% y%ly% NoActivate, BMDMissROILabel
    return true
}

BMD_DXA_HideMissingROI() {
    Gui, BMDMissROI:Destroy
    Gui, BMDMissROILabel:Destroy
}

; Global state shared between BMD_WaitForClick_Hook (function, runs in main thread)
; and the _BMD_ClickHook: label (runs in a new AHK thread on each hotkey fire).
global _BMD_ClickX := 0, _BMD_ClickY := 0, _BMD_ClickState := ""

; Interactive 2-click calibration for a single DXA field.
; Uses the correct display index from BMD_DXA_FIELD_DISPLAY so multi-viewport
; studies (fat_pct/almi on disp1, others on disp0) are handled automatically.
; Clicks are captured via a temporary LButton hotkey (no `~`) so they are never
; delivered to the PACS viewport underneath.
BMD_CalibrateDXAField(fieldName) {
    global BMD_DXA_FIELD_DISPLAY
    if !BMD_DXA_FIELD_DISPLAY.HasKey(fieldName) {
        ToolTip, % "Unknown DXA field: " fieldName
        Sleep, 1500
        ToolTip
        return false
    }
    dispIdx := BMD_DXA_FIELD_DISPLAY[fieldName]
    vp := BMD_ResolveViewportN(dispIdx)
    if !IsObject(vp) {
        ToolTip, % "No INFINITT viewport for display " dispIdx " (field: " fieldName ")"
        Sleep, 1500
        ToolTip
        return false
    }
    CoordMode, ToolTip, Screen
    ToolTip, % "Calibrate dxa." fieldName "`nClick TOP-LEFT of the value  (Esc=abort  F2=skip)"
    pt1 := BMD_WaitForClick_Hook()
    if (pt1 = "ABORT" || pt1 = "SKIP") {
        ToolTip
        return false
    }
    ToolTip, % "Calibrate dxa." fieldName "`nClick BOTTOM-RIGHT of the value  (Esc=abort)"
    pt2 := BMD_WaitForClick_Hook()
    ToolTip
    if (pt2 = "ABORT" || pt2 = "SKIP")
        return false
    ratio := BMD_ScreenRectToRatio(vp.viewport, pt1.x, pt1.y, pt2.x, pt2.y)
    if !IsObject(ratio) {
        ToolTip, % "Invalid viewport size for display " dispIdx
        Sleep, 1000
        ToolTip
        return false
    }
    BMD_SaveRatio("dxa", fieldName, ratio)
    region := BMD_RatioToRegion(vp.viewport, ratio)
    VarSetCapacity(pt, 8, 0)
    DllCall("ClientToScreen", "ptr", vp.viewport, "ptr", &pt)
    sx := NumGet(pt, 0, "int") + region[1]
    sy := NumGet(pt, 4, "int") + region[2]
    ShowOCRRegion(sx, sy, region[3], region[4], 700)
    sample := BMD_DXA_OCR_ReadText(fieldName, region, vp.viewport)
    ToolTip, % "Saved dxa." fieldName "`nOCR sample: [" Trim(sample) "]"
    Sleep, 1200
    ToolTip
    return true
}

; Waits for a left-click using a temporary LButton hotkey (without ~ passthrough),
; so the click is consumed by AHK and never reaches the window underneath.
; The _BMD_ClickHook: label in YCH_BMD.ahk fires in a new thread and stores coords.
; Returns { x, y } in screen coords, "ABORT" on Esc, or "SKIP" on F2.
BMD_WaitForClick_Hook() {
    global _BMD_ClickX, _BMD_ClickY, _BMD_ClickState
    _BMD_ClickState := "waiting"
    Hotkey, LButton, _BMD_ClickHook, On
    Loop {
        if (_BMD_ClickState = "got") {
            Hotkey, LButton, _BMD_ClickHook, Off
            return { x: _BMD_ClickX, y: _BMD_ClickY }
        }
        if GetKeyState("Escape", "P") {
            Hotkey, LButton, _BMD_ClickHook, Off
            _BMD_ClickState := ""
            KeyWait, Escape
            return "ABORT"
        }
        if GetKeyState("F2", "P") {
            Hotkey, LButton, _BMD_ClickHook, Off
            _BMD_ClickState := ""
            KeyWait, F2
            return "SKIP"
        }
        Sleep, 20
    }
}

; Seeds DXA ROI ratios in BMD_OCR_Regions.ini from hardcoded screen coordinates.
; Screen coords recorded for the standard 2nd/3rd display layout (local session only).
; Re-run via ^!+n if the PACS window layout changes.
BMD_SeedDXAFromScreenCoords() {
    ; [dispIdx, sx1, sy1, sx2, sy2]  (0=2nd display / leftmost, 1=3rd display)
    coords := { "lean_kg_g": [0, 2621, 867, 2670, 888]      ; manually calibrated — do not extend
              , "bmd":       [0, 2519, 867, 2572, 889]      ; +5 right, +5 inferior
              , "tscore":    [0, 2835, 867, 2879, 888]      ; original x1; +5 right, +5 inferior
              , "gender":    [0, 2117, -87, 2188, -64]      ; +5 right, +5 inferior
              , "fat_pct":   [1, 4329, 655, 4384, 677]      ; +5 right, +5 inferior
              , "almi":      [1, 4328, 929, 4384, 954] }    ; +5 right, +5 inferior

    vpCache := {}
    for fieldName, info in coords {
        dispIdx := info[1]
        if !vpCache.HasKey(dispIdx) {
            vp := BMD_ResolveViewportN(dispIdx)
            vpCache[dispIdx] := IsObject(vp) ? vp : ""
        }
        vp := vpCache[dispIdx]
        if !IsObject(vp) {
            ToolTip, % "No INFINITT viewport for display " dispIdx " (field: " fieldName ")"
            Sleep, 1200
            ToolTip
            continue
        }
        ratio := BMD_ScreenRectToRatio(vp.viewport, info[2], info[3], info[4], info[5])
        if !IsObject(ratio) {
            ToolTip, % "Invalid viewport for display " dispIdx " (field: " fieldName ")"
            Sleep, 1000
            ToolTip
            continue
        }
        BMD_SaveRatio("dxa", fieldName, ratio)
        ToolTip, % "Seeded dxa." fieldName
        Sleep, 350
        ToolTip
    }
    ToolTip, DXA coords seeded — all 6 fields written.
    Sleep, 1200
    ToolTip
}
