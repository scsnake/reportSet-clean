; INFINITT_SP_CaptureTest.ahk
; AHK v1 — SP overlay capture API comparison tool.
;
; PURPOSE:
;   All target regions are stored as viewport-client-relative ratios (rx, ry, rw, rh)
;   where (0,0) = top-left and (1,1) = bottom-right of the viewport.
;   On each run the script resolves the viewport hwnd, converts ratios → pixel coords,
;   draws a GUI frame on-screen, then captures the same pixel rect via three APIs:
;     A. GDI screen capture  (BitBlt from desktop DC)
;     B. PrintWindow          (PW_RENDERFULLCONTENT|PW_CLIENTONLY)
;     C. v2 bridge OCR.FromWindow  (mode 5, then mode 4 fallback)
;   Bitmaps are saved to Lib/OCR/debug_roi/ and shown in preview panels.
;
; USAGE:
;   F5  – redraw / re-capture
;   Esc – exit
;   After examining the previews, paste screen coords into the USER_REGION below
;   and press F5 to re-test a new region.
;
; USER CONFIG — edit TEST_MODE, TEST_IS_RDP, then press F5.
; TEST_MODE   : "SP" or "Img"
; TEST_IS_RDP : 1 = use RDP ratios,  0 = use local Win10 ratios
; TEST_REGION_RATIO : set [rx,ry,rw,rh] to override automatic ratio selection.
;   Leave as "" to auto-pick based on TEST_MODE + TEST_IS_RDP.

global TEST_MODE   := "Img"   ; "SP" or "Img"
global TEST_IS_RDP := 1      ; 1 = RDP session, 0 = local Win10

; Local Win10 ratios (confirmed 2026-05-08):
global TEST_RATIO_SP      := [0, 0.08, 0.14, 0.06]             ; SP overlay block
global TEST_RATIO_IMG     := [0.9094, 0.053, 0.0890, 0.040]    ; Img counter (top-right)

; RDP session ratios (from showLungCAD.ini):
global TEST_RATIO_SP_RDP  := [0, 0.08, 0.14, 0.06]       ; INFINITTOCRSPRatioRDP
global TEST_RATIO_IMG_RDP := [0.9094, 0.053, 0.0890, 0.040] ;[0.9248, 0.0559, 0.0752, 0.0419]  ; INFINITTOCRImgRatioRDP

; Manual override: set [rx,ry,rw,rh] to force a specific region, or leave "".
global TEST_REGION_RATIO := ""

; ── Global state ──────────────────────────────────────────────────
global SPTest_GUIS      := []
global SPTest_SAVE_DIR  := ""

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

SPTest_SAVE_DIR := A_ScriptDir "\Lib\OCR\debug_roi"
LogRetention_DeleteFilesOlderThan(SPTest_SAVE_DIR)

OCR_WinRT_Init()

SPTest_Run()
return

F5::SPTest_Run()
Esc::ExitApp

; ─────────────────────────────────────────────────────────────────
SPTest_Run() {
    global TEST_MODE, TEST_IS_RDP, TEST_REGION_RATIO
    global TEST_RATIO_SP, TEST_RATIO_IMG, TEST_RATIO_SP_RDP, TEST_RATIO_IMG_RDP
    global SPTest_SAVE_DIR

    SPTest_Clear()

    hwnd := SPTest_GetViewerHwnd()
    if (!hwnd) {
        MsgBox, 48, OCR Capture Test, INFINITT PACS viewer not found.
        return
    }

    WinActivate, ahk_id %hwnd%
    Sleep, 150

    pacs := new INFINITT_PACS(hwnd)
    viewport := pacs.getViewportControl("image", hwnd)
    if (!viewport) {
        MsgBox, 48, OCR Capture Test, Image viewport control not found.
        return
    }

    ; ── Select ratio for this run ─────────────────────────────────
    if (IsObject(TEST_REGION_RATIO)) {
        ratio   := TEST_REGION_RATIO          ; user override
        session := "OVERRIDE"
    } else if (TEST_IS_RDP) {
        ratio   := (TEST_MODE = "Img") ? TEST_RATIO_IMG_RDP : TEST_RATIO_SP_RDP
        session := "RDP"
    } else {
        ratio   := (TEST_MODE = "Img") ? TEST_RATIO_IMG : TEST_RATIO_SP
        session := "Local"
    }

    ; Mode-dependent labels and frame color
    if (TEST_MODE = "Img") {
        modeLabel  := "Img"
        frameColor := "Yellow"
        iniKey     := TEST_IS_RDP ? "INFINITTOCRImgRatioRDP" : "INFINITTOCRImgRatio"
    } else {
        modeLabel  := "SP"
        frameColor := "Lime"
        iniKey     := TEST_IS_RDP ? "INFINITTOCRSPRatioRDP" : "INFINITTOCRSPRatio"
    }

    ; ── Viewport geometry ─────────────────────────────────────────
    ; Use ClientToScreen for the capture origin (screen coords).
    VarSetCapacity(pt, 8, 0)
    DllCall("ClientToScreen", "ptr", viewport, "ptr", &pt)
    vcX := NumGet(pt, 0, "int")   ; viewport client screen origin X
    vcY := NumGet(pt, 4, "int")   ; viewport client screen origin Y
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "ptr", viewport, "ptr", &rc)
    vcW := NumGet(rc, 8, "int")   ; viewport client width
    vcH := NumGet(rc, 12, "int")  ; viewport client height

    ; ── Resolve ratio → screen rect ───────────────────────────────
    rx := ratio[1], ry := ratio[2], rw := ratio[3], rh := ratio[4]

    roiX := vcX + Round(vcW * rx)
    roiY := vcY + Round(vcH * ry)
    roiW := Max(4, Round(vcW * rw))
    roiH := Max(4, Round(vcH * rh))

    ratioStr := Format("{:.4f},{:.4f},{:.4f},{:.4f}", rx, ry, rw, rh)
    screenStr := "[" roiX "," roiY "," roiW "," roiH "]"
    vcStr := "[" vcX "," vcY "," vcW "," vcH "]"

    ; ── Draw GUI frame around the target region ───────────────────
    SPTest_ShowFrame("Target", "[" session "] " modeLabel " [" ratioStr "]", roiX, roiY, roiW, roiH, frameColor, 3)

    ; ── Capture via three APIs ────────────────────────────────────
    ts := A_Now

    ; A: GDI screen capture
    capA := SPTest_CaptureGDI(ts, roiX, roiY, roiW, roiH, 4)

    ; B: PrintWindow (viewport hwnd, client-relative coords)
    ; We need client-relative coords relative to the viewport for PrintWindow.
    ; The viewport's client origin is (vcX, vcY) in screen coords.
    ; Since we're PrintWindow-ing the viewport hwnd, the region is client-relative.
    pwRelX := roiX - vcX
    pwRelY := roiY - vcY
    capB := SPTest_CaptureWindow(ts, viewport, pwRelX, pwRelY, roiW, roiH, 4)

    ; C: v2 bridge OCR.FromWindow — passes client-relative coords
    ; The bridge uses mode 5 / mode 4 from OCR.ahk which does its own capture.
    capC := SPTest_CaptureViaV2Bridge(ts, viewport, pwRelX, pwRelY, roiW, roiH)

    ; ── Build layout positions for preview panels ─────────────────
    WinGetPos, winX, winY, winW, winH, ahk_id %hwnd%
    previewY := winY + 60
    SPTest_ShowCapPreview("A: GDI screen", capA, roiX, roiY, roiW, roiH, "Yellow",  winX + 20,          previewY)
    SPTest_ShowCapPreview("B: PrintWindow", capB, roiX, roiY, roiW, roiH, "Aqua",   winX + 20 + 560,    previewY)
    SPTest_ShowCapPreview("C: v2 Bridge (OCR.FromWindow)", capC, roiX, roiY, roiW, roiH, "Fuchsia", winX + 20, previewY + 440)

    ; ── Info/clipboard ────────────────────────────────────────────
    ; Pre-extract object properties — AHK v1 cannot expand obj.prop inside %...%
    fileA := IsObject(capA) ? capA.file : "(none)"
    fileB := IsObject(capB) ? capB.file : "(none)"
    fileC := IsObject(capC) ? capC.file : "(none)"
    ocrC  := IsObject(capC) && capC.HasKey("ocrText") ? capC.ocrText : ""

    info =
    (LTrim
        === INFINITT OCR Capture Test (%modeLabel%) ===
        Viewport hwnd: %viewport%
        Viewport client screen: %vcStr%
        Mode: %modeLabel%
        Test ratio [%ratioStr%]
        Test screen rect: %screenStr%
        PrintWindow client-relative: [%pwRelX%,%pwRelY%,%roiW%,%roiH%]

        Saved bitmaps:
        A (GDI screen):   %fileA%
        B (PrintWindow):  %fileB%
        C (v2 bridge):    %fileC%
        C OCR text: %ocrC%

        INI candidate:
        %iniKey%=%ratioStr%

        To update region: edit TEST_REGION_RATIO (or TEST_MODE) at top of script.
        Ratio conversion from screen coords [x,y,w,h]:
        rx = (x - vcX) / vcW = (%roiX% - %vcX%) / %vcW%
        ry = (y - vcY) / vcH = (%roiY% - %vcY%) / %vcH%
        rw = w / vcW
        rh = h / vcH
    )
    Clipboard := info
    ToolTip, %info%, 10, 10
    SetTimer, SPTest_HideTip, -15000
}

; ── Capture helpers ────────────────────────────────────────────────

SPTest_CaptureGDI(ts, x, y, w, h, scale := 4) {
    global SPTest_SAVE_DIR
    if !FileExist(SPTest_SAVE_DIR)
        FileCreateDir, %SPTest_SAVE_DIR%
    sw := Max(40, Round(w * scale))
    sh := Max(40, Round(h * scale))
    hBM := _OWR_CaptureRect(x, y, w, h, sw, sh)
    file := SPTest_SAVE_DIR "\" ts "_A_GDI_x" x "_y" y "_w" w "_h" h ".bmp"
    if (hBM)
        _OWR_SaveBitmap(hBM, file)
    return {hBM: hBM, file: file, w: sw, h: sh, srcW: w, srcH: h, scale: scale, api: "A:GDI"}
}

SPTest_CaptureWindow(ts, hwnd, relX, relY, w, h, scale := 4) {
    global SPTest_SAVE_DIR
    if !FileExist(SPTest_SAVE_DIR)
        FileCreateDir, %SPTest_SAVE_DIR%
    sw := Max(40, Round(w * scale))
    sh := Max(40, Round(h * scale))
    hBM := _OWR_CaptureWindow(relX, relY, w, h, hwnd, sw, sh)
    file := SPTest_SAVE_DIR "\" ts "_B_PrtWin_rx" relX "_ry" relY "_w" w "_h" h ".bmp"
    if (hBM)
        _OWR_SaveBitmap(hBM, file)
    return {hBM: hBM, file: file, w: sw, h: sh, srcW: w, srcH: h, scale: scale, api: "B:PrintWindow"}
}

SPTest_CaptureViaV2Bridge(ts, hwnd, relX, relY, w, h) {
    global SPTest_SAVE_DIR
    if !FileExist(SPTest_SAVE_DIR)
        FileCreateDir, %SPTest_SAVE_DIR%

    ; Ask the v2 bridge to capture OCR.FromWindow and save a bitmap.
    ; We use _OWR_OcrWindowRectViaWorker to invoke it, but we also need the raw bitmap.
    ; Strategy: call via worker to get the text (confirms the bridge reached it),
    ; then do our own GDI capture of the same rect for visual comparison.
    ; Additionally capture with the bridge's PrintWindow path via a one-shot script.
    text := _OWR_OcrWindowRectViaWorker(hwnd, relX, relY, w, h, "en-US")

    ; For visual comparison, call the bridge in one-shot mode to get it to save a bitmap.
    ; We use a temp script wrapper that captures and saves before OCR.
    ; As a practical fallback, capture via PrintWindow from the worker's perspective
    ; (same API as _OWR_CaptureWindow but saving a 4x upscale).
    hBM := SPTest_BridgeSaveBitmap(hwnd, relX, relY, w, h, ts)

    file := SPTest_SAVE_DIR "\" ts "_C_v2Bridge_rx" relX "_ry" relY "_w" w "_h" h ".bmp"
    if (hBM)
        _OWR_SaveBitmap(hBM, file)

    return {hBM: hBM, file: file, w: Max(40, w*4), h: Max(40, h*4), srcW: w, srcH: h, scale: 4
        , api: "C:v2Bridge", ocrText: text}
}

; Capture the viewport via an AHK v2 one-shot that uses OCR.FromWindow internally
; and writes both the capture bitmap and the OCR text to files.
; Returns an HBITMAP of the saved BMP (reloaded via GDI).
SPTest_BridgeSaveBitmap(hwnd, relX, relY, w, h, ts) {
    global SPTest_SAVE_DIR
    bmpPath  := SPTest_SAVE_DIR "\" ts "_C_v2Bridge_cap_rx" relX "_ry" relY "_w" w "_h" h ".bmp"
    textPath := SPTest_SAVE_DIR "\" ts "_C_v2Bridge_ocrtext.txt"

    ahkV2        := "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
    helperScript := A_ScriptDir "\Lib\OCR\SPTest_BridgeHelper.ahk"

    ; Build the v2 helper script content line by line.
    ; Using concatenation avoids v1 heredoc expanding %vars% we want to keep literal.
    q := Chr(34)
    nl := "`n"
    esc := "`"
    lines := ""
    lines .= "#Requires AutoHotkey v2.0" nl
    lines .= "#SingleInstance Off" nl
    lines .= "#Include C:\Users\raduser\Documents\reportSet\Lib\OCR\OCR.ahk" nl
    lines .= "SetTimer(ExitApp, 12000)" nl
    lines .= "hwnd := " hwnd nl
    lines .= "x := " relX ", y := " relY ", w := " w ", h := " h nl
    lines .= "bmpPath := " q bmpPath q nl
    lines .= "textPath := " q textPath q nl
    lines .= "try {" nl
    lines .= "    result := OCR.FromWindow(hwnd, {lang:" q "en-US" q ", scale:4, x:x, y:y, w:w, h:h, mode:5})" nl
    lines .= "    FileAppend(result.Text, textPath, " q "UTF-8" q ")" nl
    lines .= "} catch as e {" nl
    lines .= "    try {" nl
    lines .= "        result := OCR.FromWindow(hwnd, {lang:" q "en-US" q ", scale:4, x:x, y:y, w:w, h:h, mode:4})" nl
    lines .= "        FileAppend(result.Text, textPath, " q "UTF-8" q ")" nl
    lines .= "    } catch as e2 {" nl
    lines .= "        FileAppend(" q "ERR: " q " . e.Message . " q " / " q " . e2.Message, textPath, " q "UTF-8" q ")" nl
    lines .= "    }" nl
    lines .= "}" nl
    lines .= "; PrintWindow capture of viewport client region" nl
    lines .= "hDC := DllCall(" q "GetDC" q ", " q "Ptr" q ", hwnd, " q "Ptr" q ")" nl
    lines .= "cr := Buffer(16, 0)" nl
    lines .= "DllCall(" q "GetClientRect" q ", " q "Ptr" q ", hwnd, " q "Ptr" q ", cr)" nl
    lines .= "cW := NumGet(cr, 8, " q "int" q "), cH := NumGet(cr, 12, " q "int" q ")" nl
    lines .= "scW := Max(40, w * 4), scH := Max(40, h * 4)" nl
    lines .= "pDC  := DllCall(" q "CreateCompatibleDC" q ", " q "Ptr" q ", hDC, " q "Ptr" q ")" nl
    lines .= "hBM  := DllCall(" q "CreateCompatibleBitmap" q ", " q "Ptr" q ", hDC, " q "Int" q ", cW, " q "Int" q ", cH, " q "Ptr" q ")" nl
    lines .= "oBM  := DllCall(" q "SelectObject" q ", " q "Ptr" q ", pDC, " q "Ptr" q ", hBM, " q "Ptr" q ")" nl
    lines .= "DllCall(" q "PrintWindow" q ", " q "Ptr" q ", hwnd, " q "Ptr" q ", pDC, " q "UInt" q ", 3)" nl
    lines .= "pDC2 := DllCall(" q "CreateCompatibleDC" q ", " q "Ptr" q ", hDC, " q "Ptr" q ")" nl
    lines .= "hBM2 := DllCall(" q "CreateCompatibleBitmap" q ", " q "Ptr" q ", hDC, " q "Int" q ", scW, " q "Int" q ", scH, " q "Ptr" q ")" nl
    lines .= "oBM2 := DllCall(" q "SelectObject" q ", " q "Ptr" q ", pDC2, " q "Ptr" q ", hBM2, " q "Ptr" q ")" nl
    lines .= "DllCall(" q "SetStretchBltMode" q ", " q "Ptr" q ", pDC2, " q "Int" q ", 3)" nl
    lines .= "DllCall(" q "StretchBlt" q "," q "Ptr" q ",pDC2," q "Int" q ",0," q "Int" q ",0," q "Int" q ",scW," q "Int" q ",scH," q "Ptr" q ",pDC," q "Int" q ",x," q "Int" q ",y," q "Int" q ",w," q "Int" q ",h," q "UInt" q ",0x00CC0020)" nl
    lines .= "DllCall(" q "SelectObject" q ", " q "Ptr" q ", pDC2, " q "Ptr" q ", oBM2)" nl
    lines .= "DllCall(" q "SelectObject" q ", " q "Ptr" q ", pDC,  " q "Ptr" q ", oBM)" nl
    lines .= "DllCall(" q "DeleteObject" q ", " q "Ptr" q ", hBM)" nl
    lines .= "DllCall(" q "DeleteDC" q ",     " q "Ptr" q ", pDC)" nl
    lines .= "DllCall(" q "DeleteDC" q ",     " q "Ptr" q ", pDC2)" nl
    lines .= "DllCall(" q "ReleaseDC" q ",    " q "Ptr" q ", hwnd, " q "Ptr" q ", hDC)" nl
    lines .= "si := Buffer(16, 0), NumPut(" q "uint" q ", 1, si)" nl
    lines .= "DllCall(" q "Gdiplus\GdiplusStartup" q ", " q "Ptr*" q ", &tok:=0, " q "Ptr" q ", si, " q "Ptr" q ", 0)" nl
    lines .= "DllCall(" q "Gdiplus\GdipCreateBitmapFromHBITMAP" q ", " q "Ptr" q ", hBM2, " q "Ptr" q ", 0, " q "Ptr*" q ", &pb:=0)" nl
    lines .= "clsid := Buffer(16, 0)" nl
    lines .= "DllCall(" q "ole32\CLSIDFromString" q ", " q "WStr" q ", " q "{557cf400-1a04-11d3-9a73-0000f81ef32e}" q ", " q "Ptr" q ", clsid)" nl
    lines .= "DllCall(" q "Gdiplus\GdipSaveImageToFile" q ", " q "Ptr" q ", pb, " q "WStr" q ", " q bmpPath q ", " q "Ptr" q ", clsid, " q "Ptr" q ", 0)" nl
    lines .= "DllCall(" q "Gdiplus\GdipDisposeImage" q ", " q "Ptr" q ", pb)" nl
    lines .= "DllCall(" q "Gdiplus\GdiplusShutdown" q ", " q "Ptr" q ", tok)" nl
    lines .= "DllCall(" q "DeleteObject" q ", " q "Ptr" q ", hBM2)" nl
    lines .= "ExitApp 0" nl

    if FileExist(helperScript)
        FileDelete, %helperScript%
    FileAppend, %lines%, %helperScript%

    if !FileExist(ahkV2) || !FileExist(helperScript)
        return 0

    q := Chr(34)
    cmd := q ahkV2 q " /ErrorStdOut=UTF-8 /script " q helperScript q
    exec := ComObjCreate("WScript.Shell").Exec(cmd)
    start := A_TickCount
    while (exec.Status = 0) {
        if (A_TickCount - start > 10000)
            break
        Sleep, 50
    }

    ; Load saved BMP back as HBITMAP for display
    if FileExist(bmpPath)
        return SPTest_LoadBitmapFromFile(bmpPath)
    return 0
}

SPTest_LoadBitmapFromFile(path) {
    VarSetCapacity(si, 16, 0)
    NumPut(1, si, 0, "UInt")
    DllCall("Gdiplus\GdiplusStartup", "UPtr*", tok, "Ptr", &si, "Ptr", 0)
    tok := tok + 0
    hBM := 0
    DllCall("Gdiplus\GdipCreateBitmapFromFile", "WStr", path, "UPtr*", pBmp)
    if (pBmp) {
        DllCall("Gdiplus\GdipCreateHBITMAPFromBitmap", "UPtr", pBmp, "UPtr*", hBM, "UInt", 0xFF000000)
        DllCall("Gdiplus\GdipDisposeImage", "UPtr", pBmp)
    }
    DllCall("Gdiplus\GdiplusShutdown", "UPtr", tok)
    return hBM
}

; ── GUI helpers ────────────────────────────────────────────────────

SPTest_ShowFrame(id, label, x, y, w, h, color, thick := 3) {
    global SPTest_GUIS
    names := ["T", "B", "L", "R", "Lbl"]
    coords := [[x, y, w, thick], [x, y+h-thick, w, thick], [x, y, thick, h], [x+w-thick, y, thick, h]]

    Loop, 4 {
        n := "SPTestFrame" id names[A_Index]
        SPTest_GUIS.Push(n)
        gx := coords[A_Index][1], gy := coords[A_Index][2], gw := coords[A_Index][3], gh := coords[A_Index][4]
        Gui, %n%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
        Gui, %n%:Color, %color%
        Gui, %n%:Show, x%gx% y%gy% w%gw% h%gh% NoActivate, %n%
    }

    n := "SPTestFrame" id "Lbl"
    SPTest_GUIS.Push(n)
    ly := y - 26
    if (ly < -32000)
        ly := y + h + 4
    Gui, %n%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %n%:Color, Black
    Gui, %n%:Font, s10 c%color% Bold, Consolas
    Gui, %n%:Add, Text, x4 y3, %label% screen [%x%,%y%,%w%,%h%]
    Gui, %n%:Show, x%x% y%ly% NoActivate, %n%
}

SPTest_ShowCapPreview(label, cap, srcX, srcY, srcW, srcH, color, px, py) {
    global SPTest_GUIS
    if (!IsObject(cap) || !cap.hBM)
        return

    safeId := RegExReplace(label, "[^\w#@$]", "_")
    n := "SPTestPreview" safeId
    SPTest_GUIS.Push(n)

    ocrLine := IsObject(cap) && cap.HasKey("ocrText") ? "`nOCR: " SubStr(RegExReplace(cap.ocrText, "\s+", " "), 1, 60) : ""
    hdr := label " [" srcX "," srcY "," srcW "," srcH "] scale x" cap.scale ocrLine

    pw := cap.w, ph := cap.h
    hBM := cap.hBM

    Gui, %n%:New, +AlwaysOnTop +ToolWindow -Caption +E0x20
    Gui, %n%:Color, Black
    Gui, %n%:Font, s9 c%color% Bold, Consolas
    Gui, %n%:Add, Text, x6 y4 w%pw%, %hdr%
    Gui, %n%:Add, Picture, x6 y44 w%pw% h%ph%, % "HBITMAP:*" hBM
    Gui, %n%:Show, x%px% y%py% NoActivate, %n%
}

SPTest_Clear() {
    global SPTest_GUIS
    for _, n in SPTest_GUIS {
        try
        Gui, %n%:Destroy
    }
    SPTest_GUIS := []
    ToolTip
}

SPTest_GetViewerHwnd() {
    return FindInfinittViewerHwnd("leftmost", true)
}

SPTest_HideTip:
    ToolTip
return
