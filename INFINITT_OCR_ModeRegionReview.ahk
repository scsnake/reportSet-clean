; AHK v1 standalone OCR region review helper for INFINITT.
; Assumes one combined image viewport and overlays SP + Img OCR regions.

#NoEnv
#SingleInstance, Force
#Include %A_ScriptDir%\Lib\INFINITT_PACS.ahk
#Include %A_ScriptDir%\Lib\LogRetention.ahk
#Include %A_ScriptDir%\Lib\OCR\OCR_WinRT.ahk

SetBatchLines, -1
SetTitleMatchMode, 2
DetectHiddenWindows, Off
CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen

global OCR_MODE_REVIEW_GUIS := []
global OCR_MODE_REVIEW_INI := A_ScriptDir "\showLungCAD.ini"
global OCR_MODE_REVIEW_CAPTURE_DIR := A_ScriptDir "\Lib\OCR\debug_roi"

LogRetention_DeleteFilesOlderThan(OCR_MODE_REVIEW_CAPTURE_DIR)

INFINITT_OCRModeReview_Draw()
return

F5::INFINITT_OCRModeReview_Draw()
Esc::ExitApp

INFINITT_OCRModeReview_Draw() {
    global OCR_MODE_REVIEW_INI

    INFINITT_OCRModeReview_Clear()

    hwnd := INFINITT_OCRModeReview_GetActiveOrLeftmostHwnd()
    if (!hwnd) {
        MsgBox, 48, INFINITT OCR mode region review, INFINITT PACS viewer not found.
        return
    }

    WinActivate, ahk_id %hwnd%
    Sleep, 150

    pacs := new INFINITT_PACS(hwnd)
    viewport := pacs.getViewportControl("image", hwnd)
    if (!viewport) {
        MsgBox, 48, INFINITT OCR mode region review, INFINITT image viewport not found.
        return
    }

    WinGetPos, winX, winY, winW, winH, ahk_id %hwnd%
    WinGetPos, viewX, viewY, viewW, viewH, ahk_id %viewport%
    viewClient := INFINITT_OCRModeReview_ClientScreenRect(viewport)
    viewportClassNN := INFINITT_OCRModeReview_ControlClassNN(hwnd, viewport)
    viewportText := INFINITT_OCRModeReview_ControlText(viewport)

    slRatio := INFINITT_OCRModeReview_ReadRatio("INFINITTOCRSPRatio", [-0.0016, 0.0000, 0.1110, 0.1318])
    imgRatio := INFINITT_OCRModeReview_ReadRatio("INFINITTOCRImgRatio", [0.9094, 0.0569, 0.0890, 0.0360])

    sl := INFINITT_OCRModeReview_RatioRect(viewClient.x, viewClient.y, viewClient.w, viewClient.h, slRatio)
    img := INFINITT_OCRModeReview_RatioRect(viewClient.x, viewClient.y, viewClient.w, viewClient.h, imgRatio)
    rdpSpRatioText := "0.0000,0.0936,0.0955,0.0565"
    rdpImgRatioText := "0.9248,0.0559,0.0752,0.0419"

    ; Manually verified local boxes from screen corner coordinates.
    manualSp := {label: "SP overlay block", x: 1920, y: -326, w: 2056 - 1920, h: 176}
    manualSpBottom := {label: "SP OCR bottom 70", x: manualSp.x, y: manualSp.y + manualSp.h - 70, w: manualSp.w, h: 70}
    manualImg := {label: "Img manual local", x: 3036, y: -250, w: 3145 - 3036, h: -202 - -250}

    ; Capture before drawing overlays so the debug bitmap is not contaminated by our frames.
    spCapture := INFINITT_OCRModeReview_CaptureScreenRect("SP_manual_logical", manualSp.x, manualSp.y, manualSp.w, manualSp.h, 4)
    spBottomCapture := INFINITT_OCRModeReview_CaptureScreenRect("SP_bottom70_logical", manualSpBottom.x, manualSpBottom.y, manualSpBottom.w, manualSpBottom.h, 4)
    imgCapture := INFINITT_OCRModeReview_CaptureScreenRect("Img_manual_logical", manualImg.x, manualImg.y, manualImg.w, manualImg.h, 4)
    imgPhysicalRect := INFINITT_OCRModeReview_LogicalToPhysicalRect(viewport, manualImg.x, manualImg.y, manualImg.w, manualImg.h)
    imgPhysicalCapture := INFINITT_OCRModeReview_CaptureScreenRect("Img_manual_physical", imgPhysicalRect.x, imgPhysicalRect.y, imgPhysicalRect.w, imgPhysicalRect.h, 4)

    INFINITT_OCRModeReview_ShowFrame("Viewport", "1x1 viewport hwnd " viewport, viewX, viewY, viewW, viewH, "White", 4)
    INFINITT_OCRModeReview_ShowFrame("SPManual", "SP overlay block", manualSp.x, manualSp.y, manualSp.w, manualSp.h, "Lime", 2)
    INFINITT_OCRModeReview_ShowBox("SPBottom", "SP OCR bottom 70", manualSpBottom.x, manualSpBottom.y, manualSpBottom.w, manualSpBottom.h, "Lime", 84)
    INFINITT_OCRModeReview_ShowBox("ImgManual", "Img manual local", manualImg.x, manualImg.y, manualImg.w, manualImg.h, "Yellow", 84)
    INFINITT_OCRModeReview_ShowFrame("SPIni", "SP current INI", sl.x, sl.y, sl.w, sl.h, "Aqua", 2)
    INFINITT_OCRModeReview_ShowFrame("ImgIni", "Img current INI", img.x, img.y, img.w, img.h, "Fuchsia", 2)
    INFINITT_OCRModeReview_ShowCapturePreview("SP logical", spCapture, manualSp.x, manualSp.y, manualSp.w, manualSp.h, "Lime", winX + 20, winY + 40)
    INFINITT_OCRModeReview_ShowCapturePreview("SP bottom70", spBottomCapture, manualSpBottom.x, manualSpBottom.y, manualSpBottom.w, manualSpBottom.h, "Aqua", winX + 620, winY + 40)
    INFINITT_OCRModeReview_ShowCapturePreview("Img logical", imgCapture, manualImg.x, manualImg.y, manualImg.w, manualImg.h, "Yellow", winX + 20, winY + 320)
    INFINITT_OCRModeReview_ShowCapturePreview("Img physical", imgPhysicalCapture, imgPhysicalRect.x, imgPhysicalRect.y, imgPhysicalRect.w, imgPhysicalRect.h, "Fuchsia", winX + 620, winY + 320)

    slRel := INFINITT_OCRModeReview_Relative(sl, viewClient.x, viewClient.y)
    imgRel := INFINITT_OCRModeReview_Relative(img, viewClient.x, viewClient.y)
    slRatioText := INFINITT_OCRModeReview_RatioArrayText(slRatio)
    imgRatioText := INFINITT_OCRModeReview_RatioArrayText(imgRatio)
    manualSpRel := INFINITT_OCRModeReview_Relative(manualSp, viewClient.x, viewClient.y)
    manualImgRel := INFINITT_OCRModeReview_Relative(manualImg, viewClient.x, viewClient.y)
    manualSpRatio := INFINITT_OCRModeReview_RatioText(manualSp.x - viewClient.x, manualSp.y - viewClient.y, manualSp.w, manualSp.h, viewClient.w, viewClient.h)
    manualImgRatio := INFINITT_OCRModeReview_RatioText(manualImg.x - viewClient.x, manualImg.y - viewClient.y, manualImg.w, manualImg.h, viewClient.w, viewClient.h)
    manualSpCompare := INFINITT_OCRModeReview_RatioDeltaText(manualSpRatio, rdpSpRatioText)
    manualImgCompare := INFINITT_OCRModeReview_RatioDeltaText(manualImgRatio, rdpImgRatioText)
    viewClientText := "[" viewClient.x "," viewClient.y "," viewClient.w "," viewClient.h "]"
    slScreenText := "[" sl.x "," sl.y "," sl.w "," sl.h "]"
    imgScreenText := "[" img.x "," img.y "," img.w "," img.h "]"
    manualSpScreenText := "[" manualSp.x "," manualSp.y "," manualSp.w "," manualSp.h "]"
    manualImgScreenText := "[" manualImg.x "," manualImg.y "," manualImg.w "," manualImg.h "]"
    spTip := manualSp.x "," manualSp.y " " manualSp.w "x" manualSp.h
    imgTip := manualImg.x "," manualImg.y " " manualImg.w "x" manualImg.h
    spCaptureFile := spCapture.file
    spBottomCaptureFile := spBottomCapture.file
    imgCaptureFile := imgCapture.file
    imgPhysicalCaptureFile := imgPhysicalCapture.file
    spCaptureSize := spCapture.w "x" spCapture.h
    imgCaptureSize := imgCapture.w "x" imgCapture.h
    spBottomScreenText := "[" manualSpBottom.x "," manualSpBottom.y "," manualSpBottom.w "," manualSpBottom.h "]"
    imgPhysicalScreenText := "[" imgPhysicalRect.x "," imgPhysicalRect.y "," imgPhysicalRect.w "," imgPhysicalRect.h "]"

    clip =
    (LTrim
        INFINITT OCR mode region review
        Layout assumption: 1x1 combined viewport
        Window hwnd: %hwnd%
        Window screen: [%winX%,%winY%,%winW%,%winH%]

        Viewport:
        hwnd %viewport%
        ClassNN %viewportClassNN%
        text %viewportText%
        WinGetPos [%viewX%,%viewY%,%viewW%,%viewH%]
        client screen %viewClientText%

        SP manual local region:
        screen %manualSpScreenText%
        viewport-relative %manualSpRel%
        ratio %manualSpRatio%
        delta vs RDP default %manualSpCompare%
        capture file %spCaptureFile%
        capture scale4 %spCaptureSize%
        OCR bottom region %spBottomScreenText%
        OCR bottom capture file %spBottomCaptureFile%

        Img manual local region:
        screen %manualImgScreenText%
        viewport-relative %manualImgRel%
        ratio %manualImgRatio%
        delta vs RDP default %manualImgCompare%
        capture file %imgCaptureFile%
        capture scale4 %imgCaptureSize%
        physical-equivalent screen %imgPhysicalScreenText%
        physical capture file %imgPhysicalCaptureFile%

        Current INI ratio boxes:
        SP current screen %slScreenText%
        SP current relative %slRel%
        SP current ratio %slRatioText%
        Img current screen %imgScreenText%
        Img current relative %imgRel%
        Img current ratio %imgRatioText%

        RDP defaults:
        INFINITTOCRSPRatioRDP=%rdpSpRatioText%
        INFINITTOCRImgRatioRDP=%rdpImgRatioText%

        INI candidates:
        INFINITTOCRSPRatio=%manualSpRatio%
        INFINITTOCRImgRatio=%manualImgRatio%
    )
    Clipboard := clip

    info =
    (LTrim
        INFINITT OCR mode region review - copied to clipboard

        F5: redraw
        Esc: exit

        Viewport: %viewX%,%viewY% %viewW%x%viewH%
        SP: %spTip%
        Img: %imgTip%
    )
    ToolTip, %info%, 20, 20
    SetTimer, INFINITT_OCRModeReview_HideTooltip, -12000
}

INFINITT_OCRModeReview_ReadRatio(key, fallback) {
    global OCR_MODE_REVIEW_INI
    IniRead, raw, %OCR_MODE_REVIEW_INI%, Hotkey, %key%, ERROR
    if (raw = "ERROR")
        return fallback

    parts := StrSplit(raw, ",")
    if (parts.Length() != 4)
        return fallback

    ret := []
    Loop, 4 {
        value := Trim(parts[A_Index])
        if (value = "")
            return fallback
        ret.Push(value + 0)
    }
    return ret
}

INFINITT_OCRModeReview_RatioRect(baseX, baseY, baseW, baseH, ratio) {
    return {x: baseX + Round(baseW * ratio[1])
        , y: baseY + Round(baseH * ratio[2])
        , w: Max(1, Round(baseW * ratio[3]))
        , h: Max(1, Round(baseH * ratio[4]))}
}

INFINITT_OCRModeReview_Relative(r, baseX, baseY) {
    return "[" (r.x - baseX) "," (r.y - baseY) "," r.w "," r.h "]"
}

INFINITT_OCRModeReview_RatioText(x, y, w, h, baseW, baseH) {
    if (!baseW || !baseH)
        return ""
    return Format("{:.4f},{:.4f},{:.4f},{:.4f}", x/baseW, y/baseH, w/baseW, h/baseH)
}

INFINITT_OCRModeReview_RatioArrayText(ratio) {
    if (!IsObject(ratio) || ratio.Length() != 4)
        return ""
    return Format("{:.4f},{:.4f},{:.4f},{:.4f}", ratio[1], ratio[2], ratio[3], ratio[4])
}

INFINITT_OCRModeReview_RatioDeltaText(ratioText, refRatioText) {
    ratio := INFINITT_OCRModeReview_ParseRatioText(ratioText)
    refRatio := INFINITT_OCRModeReview_ParseRatioText(refRatioText)
    if (!IsObject(ratio) || !IsObject(refRatio))
        return ""
    return Format("{:+.4f},{:+.4f},{:+.4f},{:+.4f}"
        , ratio[1] - refRatio[1]
        , ratio[2] - refRatio[2]
        , ratio[3] - refRatio[3]
        , ratio[4] - refRatio[4])
}

INFINITT_OCRModeReview_ParseRatioText(text) {
    parts := StrSplit(text, ",")
    if (parts.Length() != 4)
        return ""
    ret := []
    Loop, 4
        ret.Push(Trim(parts[A_Index]) + 0)
    return ret
}

INFINITT_OCRModeReview_CaptureScreenRect(label, x, y, w, h, scale := 4) {
    global OCR_MODE_REVIEW_CAPTURE_DIR

    if !FileExist(OCR_MODE_REVIEW_CAPTURE_DIR)
        FileCreateDir, %OCR_MODE_REVIEW_CAPTURE_DIR%

    sw := Max(40, Round(w * scale))
    sh := Max(40, Round(h * scale))
    hBM := _OWR_CaptureRect(x, y, w, h, sw, sh)
    file := OCR_MODE_REVIEW_CAPTURE_DIR "\" A_Now "_" label "_x" x "_y" y "_w" w "_h" h "_scale" scale ".bmp"
    if (hBM)
        _OWR_SaveBitmap(hBM, file)
    return {hBM: hBM, file: file, x: x, y: y, w: sw, h: sh, srcW: w, srcH: h, scale: scale}
}

INFINITT_OCRModeReview_LogicalToPhysicalRect(hwnd, x, y, w, h) {
    p1 := INFINITT_OCRModeReview_LogicalToPhysicalPoint(hwnd, x, y)
    p2 := INFINITT_OCRModeReview_LogicalToPhysicalPoint(hwnd, x + w, y + h)
    return {x: p1.x, y: p1.y, w: Max(1, p2.x - p1.x), h: Max(1, p2.y - p1.y)}
}

INFINITT_OCRModeReview_LogicalToPhysicalPoint(hwnd, x, y) {
    VarSetCapacity(pt, 8, 0)
    NumPut(x, pt, 0, "Int")
    NumPut(y, pt, 4, "Int")
    if DllCall("User32\LogicalToPhysicalPointForPerMonitorDPI", "ptr", hwnd, "ptr", &pt)
        return {x: NumGet(pt, 0, "Int"), y: NumGet(pt, 4, "Int")}
    return {x: x, y: y}
}

INFINITT_OCRModeReview_ShowCapturePreview(id, cap, srcX, srcY, srcW, srcH, color, x, y) {
    global OCR_MODE_REVIEW_GUIS

    if (!IsObject(cap) || !cap.hBM)
        return

    safeId := RegExReplace(id, "[^\w#@$]", "_")
    guiName := "OCRModeCapture" safeId
    OCR_MODE_REVIEW_GUIS.Push(guiName)

    Gui, %guiName%:New, +AlwaysOnTop +ToolWindow -Caption +E0x20
    Gui, %guiName%:Color, Black
    Gui, %guiName%:Font, s10 c%color% Bold, Consolas
    Gui, %guiName%:Add, Text, x6 y4, % id " capture [" srcX "," srcY "," srcW "," srcH "] scale x" cap.scale
    picW := cap.w
    picH := cap.h
    hBitmap := cap.hBM
    Gui, %guiName%:Add, Picture, x6 y24 w%picW% h%picH%, % "HBITMAP:*" hBitmap
    Gui, %guiName%:Show, x%x% y%y% NoActivate, %guiName%
}

INFINITT_OCRModeReview_ShowBox(id, label, x, y, w, h, color, transparent := 84) {
    global OCR_MODE_REVIEW_GUIS

    boxGui := "OCRModeBox" id
    labelGui := "OCRModeLabel" id
    OCR_MODE_REVIEW_GUIS.Push(boxGui)
    OCR_MODE_REVIEW_GUIS.Push(labelGui)

    Gui, %boxGui%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %boxGui%:Color, %color%
    Gui, %boxGui%:Show, x%x% y%y% w%w% h%h% NoActivate, %boxGui%
    WinSet, Transparent, %transparent%, %boxGui%

    ly := y - 24
    if (ly < -32000)
        ly := y + h + 4
    Gui, %labelGui%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %labelGui%:Color, Black
    Gui, %labelGui%:Font, s10 c%color% Bold, Consolas
    Gui, %labelGui%:Add, Text, x4 y3, % label " [" x "," y "," w "," h "]"
    Gui, %labelGui%:Show, x%x% y%ly% NoActivate, %labelGui%
}

INFINITT_OCRModeReview_ShowFrame(id, label, x, y, w, h, color, thickness := 3) {
    global OCR_MODE_REVIEW_GUIS

    if (w <= 0 || h <= 0)
        return

    topGui := "OCRModeFrame" id "Top"
    bottomGui := "OCRModeFrame" id "Bottom"
    leftGui := "OCRModeFrame" id "Left"
    rightGui := "OCRModeFrame" id "Right"
    labelGui := "OCRModeFrame" id "Label"
    OCR_MODE_REVIEW_GUIS.Push(topGui)
    OCR_MODE_REVIEW_GUIS.Push(bottomGui)
    OCR_MODE_REVIEW_GUIS.Push(leftGui)
    OCR_MODE_REVIEW_GUIS.Push(rightGui)
    OCR_MODE_REVIEW_GUIS.Push(labelGui)

    INFINITT_OCRModeReview_ShowLine(topGui, x, y, w, thickness, color)
    INFINITT_OCRModeReview_ShowLine(bottomGui, x, y + h - thickness, w, thickness, color)
    INFINITT_OCRModeReview_ShowLine(leftGui, x, y, thickness, h, color)
    INFINITT_OCRModeReview_ShowLine(rightGui, x + w - thickness, y, thickness, h, color)

    ly := y - 26
    if (ly < -32000)
        ly := y + h + 4
    Gui, %labelGui%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %labelGui%:Color, Black
    Gui, %labelGui%:Font, s10 c%color% Bold, Consolas
    Gui, %labelGui%:Add, Text, x4 y3, % label " [" x "," y "," w "," h "]"
    Gui, %labelGui%:Show, x%x% y%ly% NoActivate, %labelGui%
}

INFINITT_OCRModeReview_ShowLine(guiName, x, y, w, h, color) {
    Gui, %guiName%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %guiName%:Color, %color%
    Gui, %guiName%:Show, x%x% y%y% w%w% h%h% NoActivate, %guiName%
}

INFINITT_OCRModeReview_ControlClassNN(parentHwnd, controlHwnd) {
    try {
        ret := Control_GetClassNN(parentHwnd, controlHwnd)
        if (ret != "")
            return ret
    }
    return ""
}

INFINITT_OCRModeReview_ControlText(hwnd) {
    ControlGetText, text,, ahk_id %hwnd%
    return INFINITT_OCRModeReview_OneLine(text)
}

INFINITT_OCRModeReview_OneLine(text) {
    text := "" text
    text := RegExReplace(text, "[\r\n\t]+", " ")
    return Trim(text)
}

INFINITT_OCRModeReview_ClientScreenRect(hwnd) {
    VarSetCapacity(pt, 8, 0)
    DllCall("ClientToScreen", "ptr", hwnd, "ptr", &pt)
    x := NumGet(pt, 0, "int")
    y := NumGet(pt, 4, "int")
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "ptr", hwnd, "ptr", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
    return {x: x, y: y, w: w, h: h}
}

INFINITT_OCRModeReview_Clear() {
    global OCR_MODE_REVIEW_GUIS
    for _, guiName in OCR_MODE_REVIEW_GUIS {
        try
        Gui, %guiName%:Destroy
    }
    OCR_MODE_REVIEW_GUIS := []
    ToolTip
}

INFINITT_OCRModeReview_GetActiveOrLeftmostHwnd() {
    WinGet, activeHwnd, ID, A
    if (INFINITT_OCRModeReview_IsPacsViewer(activeHwnd))
        return activeHwnd
    return INFINITT_OCRModeReview_GetLeftmostHwnd()
}

INFINITT_OCRModeReview_IsPacsViewer(hwnd) {
    return IsInfinittViewerWindow(hwnd)
}

INFINITT_OCRModeReview_GetLeftmostHwnd() {
    return FindInfinittViewerHwnd("leftmost", true)
}

INFINITT_OCRModeReview_HideTooltip:
    ToolTip
return
