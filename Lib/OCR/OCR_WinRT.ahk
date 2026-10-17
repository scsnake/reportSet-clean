; OCR_WinRT.ahk — AHK v1 native WinRT OCR (no subprocess, no ComCall)
; All COM vtable calls via DllCall. Compatible with all AHK v1.1.x.
; Call OCR_WinRT_Init() once; then OCR_WinRT_GetText(x,y,w,h,hwnd).

global _OWR_Engine    := 0   ; raw IOcrEngine*         (script lifetime)
global _OWR_SBFactory := 0   ; raw ISoftwareBitmapFactory*
global _OWR_CBLT      := 0   ; CAPTUREBLT flag
global _OWR_LastBitmap := 0   ; HBITMAP of last capture (for debugging)
global _OWR_Worker := ""
global _OWR_DebugCaptureStats := false
global _OWR_FastRectOCR := true
global _OWR_FallbackBitmapOCR := true

OCR_WinRT_Init() {
    global _OWR_Engine, _OWR_SBFactory, _OWR_CBLT
    if _OWR_Engine
        return

    ; Keep capture/debugging in v1, but hand OCR recognition to a persistent
    ; v2 worker process that wraps the Windows OCR API.
    _OWR_Engine := "bridge"
    _OWR_EnsureWorker()
    return

    DllCall("Combase.dll\RoInitialize", "UInt", 1)   ; MTA

    _OWR_SBFactory := _OWR_CreateClass("Windows.Graphics.Imaging.SoftwareBitmap"
        , "{c99feb69-2d62-4d47-a6b3-4fdb6a07fdf8}")    ; ISoftwareBitmapFactory

    pStatics := _OWR_CreateClass("Windows.Media.Ocr.OcrEngine"
        , "{5BFFA85A-3384-3540-9940-699120D428A8}")     ; IOcrEngineStatics
    
    ; 1. Try to create engine for "en-US" specifically (best for SP: -12.68 text)
    pLang := _OWR_CreateLanguage("en-US")
    if pLang {
        ; IOcrEngineStatics::TryCreateFromLanguage — slot 9
        DllCall(_vtbl(9, pStatics), "Ptr", pStatics, "Ptr", pLang, "Ptr*", _OWR_Engine)
        _COM_Release(pLang)
    }

    ; 2. Fallback to user profile languages if en-US failed or is not installed
    if !_OWR_Engine {
        ; IOcrEngineStatics::TryCreateFromUserProfileLanguages — vtable slot 10
        DllCall(_vtbl(10, pStatics), "Ptr", pStatics, "Ptr*", _OWR_Engine)
    }
    
    if _OWR_Engine {
        ; IOcrEngine::get_RecognizerLanguage — slot 7
        pLang := 0
        DllCall(_vtbl(7, _OWR_Engine), "Ptr", _OWR_Engine, "Ptr*", pLang)
        ; ILanguage::get_LanguageTag — slot 7
        hTag := 0
        DllCall(_vtbl(7, pLang), "Ptr", pLang, "Ptr*", hTag)
        pBuf := DllCall("Combase.dll\WindowsGetStringRawBuffer", "Ptr", hTag, "UInt*", len, "Ptr")
        tag := StrGet(pBuf, len, "UTF-16")
        MsgBox, 64, OCR Info, % "OCR Engine Initialized.`nLanguage: " tag
        _COM_Release(pLang)
        DllCall("Combase.dll\WindowsDeleteString", "Ptr", hTag)
    } else {
        MsgBox, 16, OCR Error, OCR Engine creation FAILED!`nNo supported languages found.
    }
    
    _COM_Release(pStatics)

    DllCall("Dwmapi\DwmIsCompositionEnabled", "Int*", dwmOn)
    _OWR_CBLT := dwmOn ? 0 : 0x40000000
}

; Drop-in replacement for OCR_GetText_v2.
; x,y,w,h: client-relative when hwnd given, screen-absolute otherwise.
OCR_WinRT_GetText(x, y, w, h, hwnd := 0, scale := 4) {
    global _OWR_Engine, _OWR_LastBitmap, _OWR_FastRectOCR, _OWR_FallbackBitmapOCR
    if !_OWR_Engine
        OCR_WinRT_Init()

    ; Fast path: let the persistent v2 worker capture and OCR the screen rect.
    ; This avoids v1 capture/preprocess, GDI+ temp BMP save, and v2 file reload.
    if (_OWR_FastRectOCR) {
        text := _OWR_OcrRectViaWorker(x, y, w, h)
        if (text != "" || !_OWR_FallbackBitmapOCR)
            return text
    }

    sW := Max(40, Ceil(w * scale))
    sH := Max(40, Ceil(h * scale))

    ; Use on-screen capture for OCR. Callers that have client-relative regions
    ; should convert them to absolute screen coordinates before calling here.
    hBM := _OWR_CaptureRect(x, y, w, h, sW, sH)
    if !hBM
        return ""

    ; Clear any previous debug frame before building the next OCR bitmap.
    if _OWR_LastBitmap {
        DllCall("DeleteObject", "Ptr", _OWR_LastBitmap)
        _OWR_LastBitmap := 0
    }

    if !_OWR_PreprocessBitmap(hBM, sW, sH) {
        DllCall("DeleteObject", "Ptr", hBM)
        return ""
    }
    DllCall("DeleteObject", "Ptr", hBM)
    return _OWR_OcrBitmapViaWorker(_OWR_LastBitmap)
}

; ── Capture helpers ───────────────────────────────────────────────

; PrintWindow capture of hwnd client area → crop+scale → standalone HBITMAP
_OWR_CaptureWindow(x, y, w, h, hwnd, sW, sH) {
    global _OWR_CBLT
    VarSetCapacity(cr, 16, 0)
    DllCall("GetClientRect", "Ptr", hwnd, "Ptr", &cr)
    wW := Max(40, NumGet(cr, 8, "Int"))
    wH := Max(40, NumGet(cr, 12, "Int"))

    hDC  := DllCall("GetDC", "Ptr", hwnd, "Ptr")
    pDC  := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
    hBM  := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", wW, "Int", wH, "Ptr")
    oBM  := DllCall("SelectObject", "Ptr", pDC, "Ptr", hBM, "Ptr")
    ; PW_RENDERFULLCONTENT(2)|PW_CLIENTONLY(1) — captures DirectX/OpenGL surfaces
    DllCall("PrintWindow", "Ptr", hwnd, "Ptr", pDC, "UInt", 3)

    ; Crop + upscale the region of interest into the output bitmap
    pDC2 := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
    hBM2 := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", sW, "Int", sH, "Ptr")
    oBM2 := DllCall("SelectObject", "Ptr", pDC2, "Ptr", hBM2, "Ptr")
    DllCall("SetStretchBltMode", "Ptr", pDC2, "Int", 3)   ; COLORONCOLOR (better for text than HALFTONE)
    DllCall("StretchBlt", "Ptr", pDC2, "Int", 0, "Int", 0, "Int", sW, "Int", sH
        , "Ptr", pDC, "Int", x, "Int", y, "Int", w, "Int", h
        , "UInt", 0x00CC0020 | _OWR_CBLT)   ; SRCCOPY

    DllCall("SelectObject", "Ptr", pDC2, "Ptr", oBM2)
    DllCall("SelectObject", "Ptr", pDC,  "Ptr", oBM)
    DllCall("DeleteObject", "Ptr", hBM)
    DllCall("DeleteDC",     "Ptr", pDC)
    DllCall("DeleteDC",     "Ptr", pDC2)
    DllCall("ReleaseDC",    "Ptr", hwnd, "Ptr", hDC)
    return hBM2
}

; GDI screen-region capture (no hwnd) → standalone HBITMAP
_OWR_CaptureRect(x, y, w, h, sW, sH) {
    global _OWR_CBLT
    hDC := DllCall("GetDC",  "Ptr", 0,   "Ptr")
    pDC := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
    hBM := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", sW, "Int", sH, "Ptr")
    oBM := DllCall("SelectObject", "Ptr", pDC, "Ptr", hBM, "Ptr")
    DllCall("SetStretchBltMode", "Ptr", pDC, "Int", 3)
    DllCall("StretchBlt", "Ptr", pDC, "Int", 0, "Int", 0, "Int", sW, "Int", sH
        , "Ptr", hDC, "Int", x, "Int", y, "Int", w, "Int", h
        , "UInt", 0x00CC0020 | _OWR_CBLT)
    DllCall("SelectObject", "Ptr", pDC, "Ptr", oBM)
    DllCall("DeleteDC",  "Ptr", pDC)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
    return hBM
}

; ── WinRT bitmap + OCR pipeline ───────────────────────────────────

; HBITMAP -> processed debug bitmap retained in _OWR_LastBitmap.
; Returns 1 on success.
_OWR_PreprocessBitmap(hBM, sW, sH) {
    global _OWR_LastBitmap

    ; Screen DC — format-compatible with any device bitmap
    hDC := DllCall("GetDC", "Ptr", 0, "Ptr")

    ; 32bpp top-down BITMAPINFOHEADER
    VarSetCapacity(bi, 40, 0)
    NumPut(40,   bi, 0,  "UInt")   ; biSize
    NumPut(sW,   bi, 4,  "Int")    ; biWidth
    NumPut(-sH,  bi, 8,  "Int")    ; biHeight < 0 → top-down
    NumPut(1,    bi, 12, "Short")  ; biPlanes
    NumPut(32,   bi, 14, "Short")  ; biBitCount (32-bit BGRA)
    ; biCompression = 0 = BI_RGB (rest stay 0)

    VarSetCapacity(bits, sW * sH * 4, 0)
    pPixels := &bits
    DllCall("GetDIBits", "Ptr", hDC, "Ptr", hBM
        , "UInt", 0, "UInt", sH, "Ptr", pPixels, "Ptr", &bi, "UInt", 0)

    ; Gentle preprocessing for OCR:
    ; preserve glyph shape in grayscale, then auto-invert if the ROI is mostly dark.
    pixelCount := sW * sH
    sumLum := 0
    minLum := 255
    maxLum := 0
    Loop, % pixelCount {
        ptr := pPixels + (A_Index-1)*4
        b := NumGet(ptr+0, "UChar"), g := NumGet(ptr+1, "UChar"), r := NumGet(ptr+2, "UChar")
        lum := Round(r * 0.299 + g * 0.587 + b * 0.114)
        sumLum += lum
        if (lum < minLum)
            minLum := lum
        if (lum > maxLum)
            maxLum := lum
        NumPut(lum, ptr+0, "UChar"), NumPut(lum, ptr+1, "UChar"), NumPut(lum, ptr+2, "UChar")
        NumPut(255, ptr+3, "UChar")
    }

    avgLum := (pixelCount ? sumLum / pixelCount : 0)
    shouldInvert := (avgLum < 128)
    contrastSpan := Max(1, maxLum - minLum)
    Loop, % pixelCount {
        ptr := pPixels + (A_Index-1)*4
        lum := NumGet(ptr+0, "UChar")
        lum := Round((lum - minLum) * 255 / contrastSpan)
        if (shouldInvert)
            lum := 255 - lum
        NumPut(lum, ptr+0, "UChar"), NumPut(lum, ptr+1, "UChar"), NumPut(lum, ptr+2, "UChar")
    }

    if (_OWR_DebugCaptureStats)
        ToolTip, % "Buffer: " sW "x" sH " | Avg=" Round(avgLum) " | Range=" minLum "-" maxLum " | Invert=" shouldInvert

    ; Create a copy of the processed bitmap for previewing/debugging
    _OWR_LastBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", sW, "Int", sH, "Ptr")
    DllCall("SetDIBits", "Ptr", hDC, "Ptr", _OWR_LastBitmap, "UInt", 0, "UInt", sH, "Ptr", pPixels, "Ptr", &bi, "UInt", 0)

    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
    return _OWR_LastBitmap ? 1 : 0
}

_OWR_EnsureWorker() {
    global _OWR_Worker
    if IsObject(_OWR_Worker) && (_OWR_Worker.Status = 0)
        return 1
    if IsObject(_OWR_Worker) {
        try {
            _OWR_Worker.Terminate()
        }
        _OWR_Worker := ""
    }

    bridge := A_ScriptDir "\OCR_Bridge.ahk"
    if !FileExist(bridge)
        bridge := A_ScriptDir "\Lib\OCR\OCR_Bridge.ahk"
    ahkV2 := "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
    if !FileExist(bridge) || !FileExist(ahkV2)
        return 0

    cmd := Chr(34) ahkV2 Chr(34) " /ErrorStdOut=UTF-8 /script " Chr(34) bridge Chr(34) " --server"
    _OWR_Worker := ComObjCreate("WScript.Shell").Exec(cmd)
    if !IsObject(_OWR_Worker)
        return 0

    ready := _OWR_ReadWorkerLine(_OWR_Worker, 2000)
    if (ready != "READY") {
        try {
            _OWR_Worker.Terminate()
        }
        _OWR_Worker := ""
        return 0
    }
    return (ready = "READY")
}

_OWR_OcrRectViaWorker(x, y, w, h, lang := "en-US") {
    global _OWR_Worker
    if !_OWR_EnsureWorker()
        return _OWR_OcrRectOneShot(x, y, w, h, lang)
    if (_OWR_Worker.Status != 0)
        return _OWR_OcrRectOneShot(x, y, w, h, lang)

    try {
        _OWR_Worker.StdIn.Write("OCR_RECT`t" x "`t" y "`t" w "`t" h "`t" lang "`n")
        line := _OWR_ReadWorkerLine(_OWR_Worker, 5000)
        text := _OWR_ParseWorkerTextLine(line)
        if (text != "")
            return text
    } catch e {
        _OWR_KillWorker()
    }

    return _OWR_OcrRectOneShot(x, y, w, h, lang)
}

_OWR_OcrWindowRectViaWorker(hwnd, x, y, w, h, lang := "en-US") {
    global _OWR_Worker
    if !_OWR_EnsureWorker()
        return _OWR_OcrWindowRectOneShot(hwnd, x, y, w, h, lang)
    if (_OWR_Worker.Status != 0)
        return _OWR_OcrWindowRectOneShot(hwnd, x, y, w, h, lang)

    try {
        _OWR_Worker.StdIn.Write("OCR_WINDOW_RECT`t" hwnd "`t" x "`t" y "`t" w "`t" h "`t" lang "`n")
        line := _OWR_ReadWorkerLine(_OWR_Worker, 5000)
        text := _OWR_ParseWorkerTextLine(line)
        if (text != "")
            return text
    } catch e {
        _OWR_KillWorker()
    }

    return _OWR_OcrWindowRectOneShot(hwnd, x, y, w, h, lang)
}

_OWR_OcrWindowRectVariantsViaWorker(hwnd, x, y, w, h, lang := "en-US") {
    global _OWR_Worker
    if !_OWR_EnsureWorker()
        return ""
    if (_OWR_Worker.Status != 0)
        return ""

    try {
        _OWR_Worker.StdIn.Write("OCR_WINDOW_RECT_VARIANTS`t" hwnd "`t" x "`t" y "`t" w "`t" h "`t" lang "`n")
        line := _OWR_ReadWorkerLine(_OWR_Worker, 12000)
        return _OWR_ParseWorkerTextLine(line)
    } catch e {
        _OWR_KillWorker()
    }
    return ""
}

_OWR_OcrBitmapViaWorker(hBM, lang := "en-US") {
    global _OWR_Worker
    if !hBM
        return ""

    tempBmp := A_Temp "\OWR_" A_TickCount "_" DllCall("GetCurrentProcessId") ".bmp"
    _OWR_SaveBitmap(hBM, tempBmp)
    if !FileExist(tempBmp)
        return ""

    text := ""
    if (_OWR_EnsureWorker() && _OWR_Worker.Status = 0) {
        try {
            _OWR_Worker.StdIn.Write("OCR_FILE`t" tempBmp "`t" lang "`n")
            line := _OWR_ReadWorkerLine(_OWR_Worker, 5000)
            text := _OWR_ParseWorkerTextLine(line)
        } catch e {
            _OWR_KillWorker()
        }
    }

    if (text = "")
        text := _OWR_OcrFileOneShot(tempBmp, lang)

    FileDelete, %tempBmp%
    return text
}

_OWR_ParseWorkerTextLine(line) {
    if (line = "")
        return ""

    parts := StrSplit(line, "`t")
    status := parts[1]
    payload := (parts.MaxIndex() >= 2) ? parts[2] : ""

    if (status = "OK")
        return _OWR_Base64Decode(payload)
    if (status = "ERR")
        return ""
    return ""
}

_OWR_OcrFileOneShot(imagePath, lang := "en-US") {
    bridge := A_ScriptDir "\OCR_Bridge.ahk"
    if !FileExist(bridge)
        bridge := A_ScriptDir "\Lib\OCR\OCR_Bridge.ahk"
    ahkV2 := "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
    if !FileExist(bridge) || !FileExist(ahkV2) || !FileExist(imagePath)
        return ""

    q := Chr(34)
    cmd := q ahkV2 q " /ErrorStdOut=UTF-8 /script " q bridge q " --file " q imagePath q " " lang
    return _OWR_ExecOneShot(cmd, 8000)
}

_OWR_OcrRectOneShot(x, y, w, h, lang := "en-US") {
    bridge := A_ScriptDir "\OCR_Bridge.ahk"
    if !FileExist(bridge)
        bridge := A_ScriptDir "\Lib\OCR\OCR_Bridge.ahk"
    ahkV2 := "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
    if !FileExist(bridge) || !FileExist(ahkV2)
        return ""

    q := Chr(34)
    cmd := q ahkV2 q " /ErrorStdOut=UTF-8 /script " q bridge q " " x " " y " " w " " h " " lang
    return _OWR_ExecOneShot(cmd, 8000)
}

_OWR_OcrWindowRectOneShot(hwnd, x, y, w, h, lang := "en-US") {
    bridge := A_ScriptDir "\OCR_Bridge.ahk"
    if !FileExist(bridge)
        bridge := A_ScriptDir "\Lib\OCR\OCR_Bridge.ahk"
    ahkV2 := "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
    if !FileExist(bridge) || !FileExist(ahkV2)
        return ""

    q := Chr(34)
    cmd := q ahkV2 q " /ErrorStdOut=UTF-8 /script " q bridge q " " x " " y " " w " " h " " lang " " hwnd
    return _OWR_ExecOneShot(cmd, 8000)
}


_OWR_LocateLineRectViaWorker(x, y, w, h, label, lang := "en-US") {
    global _OWR_Worker
    if !_OWR_EnsureWorker()
        return ""
    if (_OWR_Worker.Status != 0)
        return ""

    _OWR_Worker.StdIn.Write("LOCATE_LINE_RECT`t" x "`t" y "`t" w "`t" h "`t" label "`t" lang "`n")
    line := _OWR_ReadWorkerLine(_OWR_Worker, 5000)
    if (line = "")
        return ""

    parts := StrSplit(line, "`t")
    status := parts[1]
    if (status != "OK")
        return ""
    if (parts.MaxIndex() < 5)
        return ""

    return {x: parts[2] + 0, y: parts[3] + 0, w: parts[4] + 0, h: parts[5] + 0
        , text: (parts.MaxIndex() >= 6 ? _OWR_Base64Decode(parts[6]) : "")}
}

_OWR_ReadWorkerLine(worker, timeoutMs := 5000) {
    start := A_TickCount
    Loop {
        if !IsObject(worker)
            return ""
        if (worker.Status != 0) {
            try {
                if !worker.StdOut.AtEndOfStream
                    return RTrim(worker.StdOut.ReadLine(), "`r`n")
            }
            return ""
        }
        if !worker.StdOut.AtEndOfStream
            return RTrim(worker.StdOut.ReadLine(), "`r`n")
        if (A_TickCount - start > timeoutMs) {
            try {
                worker.Terminate()
            }
            return ""
        }
        Sleep, 20
    }
}

_OWR_KillWorker() {
    global _OWR_Worker
    if IsObject(_OWR_Worker) {
        try {
            _OWR_Worker.Terminate()
        }
    }
    _OWR_Worker := ""
}

_OWR_ExecOneShot(cmd, timeoutMs := 8000) {
    try {
        exec := ComObjCreate("WScript.Shell").Exec(cmd)
        start := A_TickCount
        while (exec.Status = 0) {
            if (A_TickCount - start > timeoutMs) {
                try {
                    exec.Terminate()
                }
                return ""
            }
            Sleep, 20
        }
        return RTrim(exec.StdOut.ReadAll(), "`r`n")
    } catch e {
        return ""
    }
}

_OWR_Base64Decode(text) {
    if (text = "")
        return ""

    DllCall("Crypt32\CryptStringToBinaryW"
        , "wstr", text
        , "uint", 0
        , "uint", 1
        , "ptr", 0
        , "uint*", outSize := 0
        , "ptr", 0
        , "ptr", 0)
    VarSetCapacity(out, outSize, 0)
    if !DllCall("Crypt32\CryptStringToBinaryW"
        , "wstr", text
        , "uint", 0
        , "uint", 1
        , "ptr", &out
        , "uint*", outSize
        , "ptr", 0
        , "ptr", 0)
        return ""
    return StrGet(&out, outSize, "UTF-8")
}

; Polls IAsyncInfo until Completed; replaces pAsync with the result value
_OWR_WaitForAsync(ByRef pAsync) {
    ; QI → IAsyncInfo  {00000036-...}
    pInfo := _COM_QI(pAsync, "{00000036-0000-0000-C000-000000000046}")
    Loop {
        status := 0
        DllCall(_vtbl(7, pInfo), "Ptr", pInfo, "UInt*", status)   ; get_Status
        if (status != 0)
            break
        Sleep, 0
    }
    _COM_Release(pInfo)

    if (status != 1) {   ; 1 = AsyncStatus.Completed
        ToolTip, % "OCR Async Error: status=" status " (2=Error, 4=Canceled)"
        _COM_Release(pAsync)
        pAsync := 0
        return
    }
    ; IAsyncOperation<OcrResult>::GetResults — slot 8
    pResult := 0
    DllCall(_vtbl(8, pAsync), "Ptr", pAsync, "Ptr*", pResult)
    _COM_Release(pAsync)
    pAsync := pResult
}

; Concatenates line texts from raw IOcrResult*
_OWR_ResultToText(pOcrResult) {
    ; IOcrResult::get_Lines — slot 7 → IVectorView<OcrLine>*
    pLines := 0
    DllCall(_vtbl(7, pOcrResult), "Ptr", pOcrResult, "Ptr*", pLines)
    ; IVectorView::get_Size — slot 7
    lineCount := 0
    DllCall(_vtbl(7, pLines), "Ptr", pLines, "UInt*", lineCount)

    fullText := ""
    Loop, %lineCount% {
        ; IVectorView::GetAt — slot 6
        pLine := 0
        DllCall(_vtbl(6, pLines), "Ptr", pLines, "UInt", A_Index - 1, "Ptr*", pLine)
        ; IOcrLine::get_Text — slot 7 → HSTRING
        hStr := 0
        DllCall(_vtbl(7, pLine), "Ptr", pLine, "Ptr*", hStr)
        pBuf := DllCall("Combase.dll\WindowsGetStringRawBuffer"
            , "Ptr", hStr, "UInt*", len, "Ptr")
        lineText := StrGet(pBuf, len, "UTF-16")
        DllCall("Combase.dll\WindowsDeleteString", "Ptr", hStr)
        fullText .= (A_Index > 1 ? "`n" : "") lineText
        _COM_Release(pLine)
    }
    _COM_Release(pLines)
    return fullText
}

; ── COM / WinRT primitives ────────────────────────────────────────

; Get function pointer at vtable slot n (0-indexed) of raw COM pointer pObj
_vtbl(n, pObj) {
    return NumGet(NumGet(pObj+0, "UPtr"), n * A_PtrSize, "UPtr")
}

; IUnknown::Release (slot 2)
_COM_Release(pObj) {
    if pObj
        DllCall(_vtbl(2, pObj), "Ptr", pObj)
}

; IUnknown::QueryInterface (slot 0) → new raw interface pointer (caller must Release)
_COM_QI(pObj, iid) {
    VarSetCapacity(GUID, 16, 0)
    DllCall("ole32\CLSIDFromString", "WStr", iid, "Ptr", &GUID, "UInt")
    pResult := 0
    DllCall(_vtbl(0, pObj), "Ptr", pObj, "Ptr", &GUID, "Ptr*", pResult)
    return pResult
}

; RoGetActivationFactory → raw interface pointer (script-lifetime, never Released)
_OWR_CreateClass(className, iid) {
    hStr := _OWR_HStrCreate(className)
    VarSetCapacity(GUID, 16, 0)
    DllCall("ole32\CLSIDFromString", "WStr", iid, "Ptr", &GUID, "UInt")
    cls := 0
    DllCall("Combase.dll\RoGetActivationFactory", "Ptr", hStr, "Ptr", &GUID, "Ptr*", cls)
    _OWR_HStrDelete(hStr)
    return cls
}

_OWR_HStrCreate(str) {
    hStr := 0
    DllCall("Combase.dll\WindowsCreateString", "WStr", str, "UInt", StrLen(str), "Ptr*", hStr)
    return hStr
}

_OWR_HStrDelete(hStr) {
    DllCall("Combase.dll\WindowsDeleteString", "Ptr", hStr)
}

; --- GDI+ Bitmap Saving Helper ---
_OWR_SaveBitmap(hBM, file) {
    if !hBM
        return
    VarSetCapacity(si, 16, 0), NumPut(1, si, "UInt")
    DllCall("Gdiplus\GdiplusStartup", "Ptr*", pToken, "Ptr", &si, "Ptr", 0)
    pBitmap := 0
    DllCall("Gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBM, "Ptr", 0, "Ptr*", pBitmap)
    
    ; Get CLSID for BMP
    VarSetCapacity(clsid, 16, 0)
    DllCall("ole32\CLSIDFromString", "WStr", "{557cf400-1a04-11d3-9a73-0000f81ef32e}", "Ptr", &clsid)
    
    DllCall("Gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", file, "Ptr", &clsid, "Ptr", 0)
    DllCall("Gdiplus\GdipDisposeImage", "Ptr", pBitmap)
    DllCall("Gdiplus\GdiplusShutdown", "Ptr", pToken)
}

; Create a Windows.Globalization.Language object (caller must _COM_Release)
_OWR_CreateLanguage(tag) {
    pFactory := _OWR_CreateClass("Windows.Globalization.Language", "{9B0252AC-0C27-44F8-B792-9793FB66C63E}")
    if !pFactory
        return 0
    hTag := _OWR_HStrCreate(tag)
    pLang := 0
    ; ILanguageFactory::CreateLanguage — slot 6
    DllCall(_vtbl(6, pFactory), "Ptr", pFactory, "Ptr", hTag, "Ptr*", pLang)
    _OWR_HStrDelete(hTag)
    _COM_Release(pFactory)
    return pLang
}
