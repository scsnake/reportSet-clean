#Requires AutoHotkey v2.0
#SingleInstance Off
#Include C:\Users\raduser\Documents\reportSet\Lib\OCR\OCR.ahk

; Visual debug disabled for production speed
OCR.DisplayImage := 0

if (A_Args.Length >= 1 && A_Args[1] = "--server") {
    OCR_Bridge_Server()
    ExitApp 0
}

; One-shot mode remains available for debugging/manual testing.
; Watchdog timer: kill if stuck for more than 10s
SetTimer(ExitApp, 10000)

if A_Args.Length < 1 {
    FileAppend "Usage: OCR_Bridge.ahk --server  OR  OCR_Bridge.ahk --file image.bmp [lang]  OR  OCR_Bridge.ahk x y w h [lang] [hwnd]", "*"
    ExitApp 1
}

isFileMode := (A_Args[1] = "--file")
lang := "en-US"
result := ""

try {
    if (isFileMode) {
        if A_Args.Length < 2 {
            FileAppend "Usage: OCR_Bridge.ahk --file image.bmp [lang]", "*"
            ExitApp 1
        }
        imagePath := A_Args[2]
        if (A_Args.Length >= 3 && A_Args[3] != "")
            lang := A_Args[3]
        result := OCR_Bridge_FromFile(imagePath, lang)
    } else {
        if A_Args.Length < 4 {
            FileAppend "Usage: OCR_Bridge.ahk x y w h [lang] [hwnd]", "*"
            ExitApp 1
        }

        x := IsNumber(A_Args[1]) ? Integer(A_Args[1]) : 0
        y := IsNumber(A_Args[2]) ? Integer(A_Args[2]) : 0
        w := IsNumber(A_Args[3]) ? Integer(A_Args[3]) : 0
        h := IsNumber(A_Args[4]) ? Integer(A_Args[4]) : 0
        if (A_Args.Length >= 5 && A_Args[5] != "")
            lang := A_Args[5]
        hwnd := (A_Args.Length >= 6 && A_Args[6] != "") ? Integer(A_Args[6]) : 0
        result := OCR_Bridge_FromRectOrWindow(x, y, w, h, lang, hwnd)
    }

    if IsObject(result)
        FileAppend result.Text, "*"
    else
        FileAppend result, "*"
} catch Error as e {
    if (isFileMode)
        FileAppend "Error: [" Type(e) "] " e.Message "`nParams: file=" imagePath " lang=" lang, "*"
    else
        FileAppend "Error: [" Type(e) "] " e.Message "`nParams: x=" x " y=" y " w=" w " h=" h " lang=" lang " hwnd=" hwnd, "*"
    ExitApp 1
}

ExitApp 0

OCR_Bridge_Server() {
    stdin := FileOpen("*", "r `n", "UTF-8")

    if !stdin
        ExitApp 2

    SetTimer(OCR_Bridge_IdleExit, -300000)
    OCR_Bridge_ServerWrite("READY")
    Loop {
        try {
            line := RTrim(stdin.ReadLine(), "`r`n")
        } catch {
            break
        }
        if (line = "" && stdin.AtEOF)
            break
        if (line = "")
            continue
        SetTimer(OCR_Bridge_IdleExit, -300000)
        if (line = "PING") {
            OCR_Bridge_ServerWrite("PONG")
            continue
        }
        if (line = "QUIT") {
            OCR_Bridge_ServerWrite("BYE")
            break
        }

        try {
            SetTimer(OCR_Bridge_CommandTimeout, -5000)
            parts := StrSplit(line, "`t")
            cmd := parts[1]
            if (cmd = "OCR_RECT") {
                if (parts.Length < 6)
                    throw Error("OCR_RECT requires x y w h lang")
                x := Integer(parts[2]), y := Integer(parts[3]), w := Integer(parts[4]), h := Integer(parts[5])
                lang := (parts.Length >= 6 && parts[6] != "") ? parts[6] : "en-US"
                text := OCR_Bridge_FromRectOrWindow(x, y, w, h, lang, 0)
                OCR_Bridge_ServerWrite("OK`t" OCR_Bridge_Base64Encode(text))
                continue
            }
            if (cmd = "OCR_WINDOW_RECT") {
                if (parts.Length < 7)
                    throw Error("OCR_WINDOW_RECT requires hwnd x y w h lang")
                hwnd := Integer(parts[2]), x := Integer(parts[3]), y := Integer(parts[4]), w := Integer(parts[5]), h := Integer(parts[6])
                lang := (parts.Length >= 7 && parts[7] != "") ? parts[7] : "en-US"
                text := OCR_Bridge_FromRectOrWindow(x, y, w, h, lang, hwnd)
                OCR_Bridge_ServerWrite("OK`t" OCR_Bridge_Base64Encode(text))
                continue
            }
            if (cmd = "OCR_WINDOW_RECT_VARIANTS") {
                if (parts.Length < 7)
                    throw Error("OCR_WINDOW_RECT_VARIANTS requires hwnd x y w h lang")
                hwnd := Integer(parts[2]), x := Integer(parts[3]), y := Integer(parts[4]), w := Integer(parts[5]), h := Integer(parts[6])
                lang := (parts.Length >= 7 && parts[7] != "") ? parts[7] : "en-US"
                text := OCR_Bridge_WindowVariantReport(hwnd, x, y, w, h, lang)
                OCR_Bridge_ServerWrite("OK`t" OCR_Bridge_Base64Encode(text))
                continue
            }
            if (cmd = "LOCATE_LINE_RECT") {
                if (parts.Length < 6)
                    throw Error("LOCATE_LINE_RECT requires x y w h label [lang]")
                x := Integer(parts[2]), y := Integer(parts[3]), w := Integer(parts[4]), h := Integer(parts[5])
                label := parts[6]
                lang := (parts.Length >= 7 && parts[7] != "") ? parts[7] : "en-US"
                rect := OCR_Bridge_LocateLineRect(x, y, w, h, label, lang)
                if IsObject(rect)
                    OCR_Bridge_ServerWrite("OK`t" rect.x "`t" rect.y "`t" rect.w "`t" rect.h "`t" OCR_Bridge_Base64Encode(rect.text))
                else
                    OCR_Bridge_ServerWrite("OK")
                continue
            }
            if (cmd = "OCR_FILE") {
                if (parts.Length < 2)
                    throw Error("OCR_FILE requires path")
                imagePath := parts[2]
                lang := (parts.Length >= 3 && parts[3] != "") ? parts[3] : "en-US"
                text := OCR_Bridge_FromFile(imagePath, lang)
                OCR_Bridge_ServerWrite("OK`t" OCR_Bridge_Base64Encode(text))
                continue
            }

            throw Error("Unknown command: " cmd)
        } catch Error as e {
            OCR_Bridge_ServerWrite("ERR`t" OCR_Bridge_Base64Encode(Type(e) ": " e.Message))
        } finally {
            SetTimer(OCR_Bridge_CommandTimeout, 0)
        }
    }
}

OCR_Bridge_ServerWrite(line) {
    FileAppend(line "`n", "*", "UTF-8")
}

OCR_Bridge_CommandTimeout() {
    FileAppend("ERR`t" OCR_Bridge_Base64Encode("Timeout: OCR command exceeded 5 seconds") "`n", "*", "UTF-8")
    ExitApp 124
}

OCR_Bridge_IdleExit() {
    ExitApp 0
}

OCR_Bridge_FromFile(imagePath, lang := "en-US") {
    ; The v1 caller already captures, upscales, grayscales, contrast-normalizes,
    ; and auto-inverts before saving the temp BMP. Re-scaling here adds repeated
    ; WinRT OCR passes on every scroll step.
    result := OCR.FromFile(imagePath, { lang: lang })
    return result.Text
}

OCR_Bridge_FromRectOrWindow(x, y, w, h, lang := "en-US", hwnd := 0) {
    if (hwnd) {
        for _, baseOpts in [
            { scale: 4, mode: 5 },
            { scale: 4, mode: 4 },
            { scale: 6, mode: 5 },
            { scale: 6, mode: 4 },
            { scale: 4, mode: 5, grayscale: 1 },
            { scale: 4, mode: 4, grayscale: 1 },
            { scale: 4, mode: 5, invertcolors: 1 },
            { scale: 4, mode: 4, invertcolors: 1 },
            { scale: 6, mode: 5, grayscale: 1 },
            { scale: 6, mode: 4, grayscale: 1 }
        ] {
            opts := baseOpts.Clone()
            opts.lang := lang
            opts.x := x
            opts.y := y
            opts.w := w
            opts.h := h
            text := OCR_Bridge_TryWindow(hwnd, opts)
            if (text != "")
                return text
        }
    }

    for _, baseOpts in [
        { scale: 2 },
        { scale: 4 },
        { scale: 4, grayscale: 1 },
        { scale: 4, invertcolors: 1 }
    ] {
        opts := baseOpts.Clone()
        opts.lang := lang
        text := OCR_Bridge_TryRect(x, y, w, h, opts)
        if (text != "")
            return text
    }
    return ""
}

OCR_Bridge_WindowVariantReport(hwnd, x, y, w, h, lang := "en-US") {
    variants := [
        { name: "mode5_scale4", opts: { scale: 4, mode: 5 } },
        { name: "mode4_scale4", opts: { scale: 4, mode: 4 } },
        { name: "mode5_scale6", opts: { scale: 6, mode: 5 } },
        { name: "mode4_scale6", opts: { scale: 6, mode: 4 } },
        { name: "mode5_scale8", opts: { scale: 8, mode: 5 } },
        { name: "mode4_scale8", opts: { scale: 8, mode: 4 } },
        { name: "mode5_gray_s6", opts: { scale: 6, mode: 5, grayscale: 1 } },
        { name: "mode4_gray_s6", opts: { scale: 6, mode: 4, grayscale: 1 } },
        { name: "mode5_inv_s6", opts: { scale: 6, mode: 5, invertcolors: 1 } },
        { name: "mode4_inv_s6", opts: { scale: 6, mode: 4, invertcolors: 1 } },
        { name: "mode5_mono160_s6", opts: { scale: 6, mode: 5, monochrome: 160 } },
        { name: "mode4_mono160_s6", opts: { scale: 6, mode: 4, monochrome: 160 } }
    ]

    out := ""
    for _, v in variants {
        opts := v.opts.Clone()
        opts.lang := lang
        opts.x := x
        opts.y := y
        opts.w := w
        opts.h := h
        text := OCR_Bridge_TryWindow(hwnd, opts)
        out .= (out = "" ? "" : "`n") v.name ": [" text "]"
    }
    return out
}

OCR_Bridge_TryWindow(hwnd, opts) {
    try {
        result := OCR.FromWindow(hwnd, opts)
        return Trim(result.Text)
    } catch {
        return ""
    }
}

OCR_Bridge_TryRect(x, y, w, h, opts) {
    try {
        result := OCR.FromRect(x, y, w, h, opts)
        return Trim(result.Text)
    } catch {
        return ""
    }
}

OCR_Bridge_LocateLineRect(x, y, w, h, label, lang := "en-US") {
    slice := OCR_Bridge_LocateLineSliceRect(x, y, w, h, label, lang)
    if IsObject(slice)
        return slice

    result := OCR.FromRect(x, y, w, h, { lang: lang, scale: 2 })
    line := OCR_Bridge_FindMatchingLine(result, label)
    if IsObject(line)
        return line

    result := OCR.FromRect(x, y, w, h, { lang: lang, scale: 4 })
    return OCR_Bridge_FindMatchingLine(result, label)
}

OCR_Bridge_LocateLineSliceRect(x, y, w, h, label, lang := "en-US") {
    bandH := Max(24, Ceil(h * 0.45))
    steps := 4
    best := ""
    Loop steps {
        offset := (steps = 1) ? 0 : Round((h - bandH) * (A_Index - 1) / (steps - 1))
        text := OCR_Bridge_FromRectOrWindow(x, y + offset, w, bandH, lang, 0)
        score := OCR_Bridge_LabelScore(text, label)
        if (score > 0 && (!IsObject(best) || score > best.score || (score = best.score && StrLen(text) < StrLen(best.text))))
            best := {x: x, y: y + offset, w: w, h: bandH, text: text, score: score}
    }
    return IsObject(best) ? best : ""
}

OCR_Bridge_LabelScore(text, label) {
    norm := StrLower(RegExReplace(text, "\s+", " "))
    letters := StrLower(RegExReplace(text, "[^a-z]", ""))
    want := StrLower(label)
    if (want = "sp") {
        if RegExMatch(norm, "i)(^|[^a-z])sp([^a-z]|$)")
            return 3
        if InStr(letters, "sp")
            return 2
        if InStr(letters, "sl")
            return 1
        return 0
    }
    if (want = "img") {
        if RegExMatch(norm, "i)(^|[^a-z])img([^a-z]|$)")
            return 3
        if InStr(letters, "img")
            return 2
        return 0
    }
    return InStr(norm, want) ? 1 : 0
}

OCR_Bridge_FindMatchingLine(result, label) {
    if !IsObject(result)
        return ""

    want := StrLower(label)
    wordMatch := OCR_Bridge_FindMatchingWordBand(result, want)
    if IsObject(wordMatch)
        return wordMatch

    for line in result.Lines {
        text := Trim(line.Text)
        norm := StrLower(RegExReplace(text, "\s+", " "))
        if (want = "sp") {
            if RegExMatch(norm, "i)(^|[^a-z])sp([^a-z]|$)") {
                rect := line.BoundingRect
                return {x: rect.x, y: rect.y, w: rect.w, h: rect.h, text: text}
            }
        } else if (want = "img") {
            if RegExMatch(norm, "i)(^|[^a-z])img([^a-z]|$)") {
                rect := line.BoundingRect
                return {x: rect.x, y: rect.y, w: rect.w, h: rect.h, text: text}
            }
        } else if InStr(norm, want) {
            rect := line.BoundingRect
            return {x: rect.x, y: rect.y, w: rect.w, h: rect.h, text: text}
        }
    }
    return ""
}

OCR_Bridge_FindMatchingWordBand(result, want) {
    if !IsObject(result)
        return ""

    matchedWord := ""
    for word in result.Words {
        text := Trim(word.Text)
        norm := StrLower(RegExReplace(text, "[^a-z]", ""))
        if (want = "sp" && norm = "sp") {
            matchedWord := word
            break
        }
        if (want = "img" && norm = "img") {
            matchedWord := word
            break
        }
        if (want != "sp" && want != "img" && InStr(norm, want)) {
            matchedWord := word
            break
        }
    }
    if !IsObject(matchedWord)
        return ""

    centerY := matchedWord.y + (matchedWord.h / 2.0)
    top := 999999, left := 999999, right := -1, bottom := -1
    collected := false
    for word in result.Words {
        wordCenterY := word.y + (word.h / 2.0)
        if (Abs(wordCenterY - centerY) <= Max(matchedWord.h, word.h) * 0.8) {
            collected := true
            if (word.x < left)
                left := word.x
            if (word.y < top)
                top := word.y
            if (word.x + word.w > right)
                right := word.x + word.w
            if (word.y + word.h > bottom)
                bottom := word.y + word.h
        }
    }
    if !collected
        return ""
    return {x: left, y: top, w: right - left, h: bottom - top, text: matchedWord.Text}
}

OCR_Bridge_Base64Encode(text) {
    if (text = "")
        return ""

    size := StrPut(text, "UTF-8") - 1
    buf := Buffer(size, 0)
    StrPut(text, buf, "UTF-8")

    chars := 0
    DllCall("Crypt32\CryptBinaryToStringW"
        , "ptr", buf
        , "uint", size
        , "uint", 0x40000001 ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
        , "ptr", 0
        , "uint*", &chars := 0)

    out := Buffer(chars * 2, 0)
    DllCall("Crypt32\CryptBinaryToStringW"
        , "ptr", buf
        , "uint", size
        , "uint", 0x40000001
        , "ptr", out
        , "uint*", &chars)
    return StrGet(out, chars - 1)
}
