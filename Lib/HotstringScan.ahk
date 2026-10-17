; HotstringScan.ahk -- AHK v1 hotstring catalog scanner for Hotstring Helper.
;
; Recognises single-line, block-continuation, and command-body hotstrings
; (the last is the gap in Lib\HotstringEnhancer.ahk's listHotstrings()).
; Classifies bodies by "sendKind" so HH can choose paste / display / simulate.
;
; Depends on Lib\JoinScript.ahk (PreprocessScript) for #include expansion.
;
; Public:
;   HS_Scan(path)         -> array of entries (see shape below)
;   HS_BuildMap(entries)  -> {trigger -> displayBody} drop-in for legacy callers
;
; Entry shape:
;   { sourcePath  : string        ; path passed to HS_Scan
;   , header      : ":opts:trig"  ; original :opts:trigger (no trailing "::")
;   , trigger     : "trig"
;   , opts        : {str, trigger, star, omit, noBS, raw, conform, caseSensitive}
;   , sendKind    : "auto" | "clip" | "sendLit" | "sendExpr" | "complex"
;   , payload     : ""            ; literal text to paste when sendable
;   , displayBody : ""            ; multi-line, decoded {Enter}->\n for preview/search
;   , endChar     : " "           ; end-char to append in simulate-trigger mode
;   }

#include <JoinScript>

HS_Scan(path) {
    expanded := ""
    extra    := []
    PreprocessScript(expanded, path, extra)
    return HS_ScanText(expanded, path)
}

HS_ScanText(src, sourcePath := "") {
    entries   := []
    lines     := StrSplit(src, "`n", "`r")
    state     := "global"
    bodyBuf   := []
    curHeader := ""
    curOpts   := {}
    contBuf   := []
    contOpen  := ""
    endChars  := " "

    Loop % lines.MaxIndex() {
        line    := lines[A_Index]
        trimmed := Trim(line, " `t")

        if (state = "global") {
            if RegExMatch(trimmed, "i)^#Hotstring\s+EndChars\s+(.+)$", m) {
                endChars := HS_DecodeEscapes(Trim(m1, " `t"))
                continue
            }
            if (RegExMatch(trimmed, "^(:[^:]*:[^:]+)::(.+)$", m)
                    && !RegExMatch(m2, "^\s*$")) {
                opts      := HS_ParseHsOpts(m1)
                converted := HS_TryConvertText(m2, opts.raw)
                if (converted != "")
                    entries.Push(HS_MakeEntry(sourcePath, m1, opts, "auto", converted, converted, endChars))
                else
                    entries.Push(HS_MakeEntry(sourcePath, m1, opts, "complex", "", m2, endChars))
                continue
            }
            if RegExMatch(trimmed, "^(:[^:]*:[^:]+)::$", m) {
                curOpts   := HS_ParseHsOpts(m1)
                curHeader := m1
                state     := "body"
                bodyBuf   := []
                continue
            }
        }
        else if (state = "body") {
            if (bodyBuf.MaxIndex() = "" && RegExMatch(trimmed, "^\(")) {
                state    := "directCont"
                contBuf  := []
                contOpen := line
                continue
            }
            if (trimmed = "return") {
                HS_ClassifyBody(entries, sourcePath, curHeader, curOpts, bodyBuf, endChars)
                state     := "global"
                bodyBuf   := []
                curOpts   := {}
                curHeader := ""
                continue
            }
            bodyBuf.Push(line)
        }
        else if (state = "directCont") {
            if RegExMatch(trimmed, "^\)\s*(?:;.*)?$") {
                text      := HS_ContinuationText(contOpen, contBuf)
                converted := HS_TryConvertText(text, curOpts.raw)
                if (converted != "")
                    entries.Push(HS_MakeEntry(sourcePath, curHeader, curOpts, "auto", converted, converted, endChars))
                else
                    entries.Push(HS_MakeEntry(sourcePath, curHeader, curOpts, "complex", "", text, endChars))
                state     := "global"
                contBuf   := []
                contOpen  := ""
                curOpts   := {}
                curHeader := ""
                continue
            }
            contBuf.Push(line)
        }
    }

    if (state = "body" && curHeader != "")
        HS_ClassifyBody(entries, sourcePath, curHeader, curOpts, bodyBuf, endChars)
    else if (state = "directCont" && curHeader != "")
        entries.Push(HS_MakeEntry(sourcePath, curHeader, curOpts, "complex", "", HS_ContinuationText(contOpen, contBuf), endChars))

    return entries
}

HS_ClassifyBody(entries, sourcePath, header, opts, bodyLines, endChars) {
    nonEmpty := []
    for _, ln in bodyLines
        if (Trim(ln, " `t") != "")
            nonEmpty.Push(Trim(ln, " `t"))

    body := HS_JoinLines(bodyLines)

    if (nonEmpty.MaxIndex() = 1) {
        only := nonEmpty[1]
        if RegExMatch(only, "i)^sendByClipboard\(\s*""((?:[^""]|"""")*)""\s*(?:,\s*-?\d+\s*)?\)$", sm) {
            payload := HS_UnescapeAhkString(sm1)
            entries.Push(HS_MakeEntry(sourcePath, header, opts, "clip", payload, payload, endChars))
            return
        }
        ; Word boundary so user functions like sendAndNextLine(...) aren't
        ; mis-classified as Send + remainder.
        if RegExMatch(only, "i)^(SendInput|SendRaw|Send)\b\s*,?\s*(.+)$", sm) {
            sendStr := sm2
            if RegExMatch(sendStr, "^%\s+(.+)$", em) {
                entries.Push(HS_MakeEntry(sourcePath, header, opts, "sendExpr", "", "send % " em1, endChars))
                return
            }
            rawMode   := sm1 ~= "i)Raw"
            converted := HS_TryConvertText(sendStr, rawMode)
            if (converted != "") {
                entries.Push(HS_MakeEntry(sourcePath, header, opts, "sendLit", converted, converted, endChars))
                return
            }
        }
    }

    entries.Push(HS_MakeEntry(sourcePath, header, opts, "complex", "", body, endChars))
}

HS_MakeEntry(sourcePath, header, opts, kind, payload, displayBody, endChars) {
    endChar := " "
    if (endChars != "" && !InStr(endChars, " "))
        endChar := SubStr(endChars, 1, 1)
    return { sourcePath  : sourcePath
           , header      : header
           , trigger     : opts.trigger
           , opts        : opts
           , sendKind    : kind
           , payload     : payload
           , displayBody : displayBody
           , endChar     : endChar }
}

HS_BuildMap(entries) {
    map := {}
    for _, e in entries
        if !map.HasKey(e.trigger)
            map[e.trigger] := e.displayBody
    return map
}

HS_BuildEntryMap(entries) {
    map := {}
    for _, e in entries
        if !map.HasKey(e.trigger)
            map[e.trigger] := e
    return map
}

HS_ParseHsOpts(header) {
    RegExMatch(header, "^:([^:]*):(.+)$", m)
    opts := m1
    return { str           : opts
           , trigger       : m2
           , star          : !!InStr(opts, "*")
           , omit          : !!RegExMatch(opts, "i)O(?!\d)")
           , noBS          : !!RegExMatch(opts, "B0")
           , raw           : !!RegExMatch(opts, "i)[RT]")
           , conform       : !RegExMatch(opts, "i)C(?!0)")
           , caseSensitive : !!RegExMatch(opts, "C(?!0)") }
}

HS_TryConvertText(s, rawMode := false) {
    if (rawMode)
        return s
    result := ""
    pos    := 1
    len    := StrLen(s)
    while (pos <= len) {
        ch     := SubStr(s, pos, 1)
        nextCh := SubStr(s, pos + 1, 1)
        if (InStr("!^+#", ch) && nextCh != "{")
            return ""
        if (ch = "}" && nextCh = "}") {
            result .= "}"
            pos    += 2
            continue
        }
        if (ch != "{") {
            result .= ch
            pos    += 1
            continue
        }
        if (SubStr(s, pos, 3) = "{{}") {
            result .= "{"
            pos    += 3
            continue
        }
        if (nextCh = "{") {
            result .= "{"
            pos    += 2
            continue
        }
        if (SubStr(s, pos, 3) = "{}}") {
            result .= "}"
            pos    += 3
            continue
        }
        endPos := InStr(s, "}", false, pos + 1)
        if (!endPos)
            return ""
        keyName := SubStr(s, pos + 1, endPos - pos - 1)
        pos := endPos + 1
        if RegExMatch(keyName, "i)^(Enter|Return)(\s+(\d+))?$", km)
            result .= HS_Repeat("`n", km3 ? km3+0 : 1)
        else if RegExMatch(keyName, "i)^Tab(\s+(\d+))?$", km)
            result .= HS_Repeat("`t", km2 ? km2+0 : 1)
        else if RegExMatch(keyName, "i)^Space(\s+(\d+))?$", km)
            result .= HS_Repeat(" ", km2 ? km2+0 : 1)
        else if RegExMatch(keyName, "^[!^+#`{`}]$")
            result .= keyName
        else
            return ""
    }
    return result
}

HS_Repeat(s, n) {
    r := ""
    Loop % n
        r .= s
    return r
}

HS_ContinuationText(openLine, lines) {
    opts   := Trim(SubStr(Trim(openLine, " `t"), 2), " `t")
    joiner := "`n"
    if RegExMatch(opts, "i)\bJoin(\S*)", m)
        joiner := HS_DecodeEscapes(m1)
    ltrim := !!RegExMatch(opts, "i)\bLTrim\b")
    text  := ""
    for i, line in lines {
        ln := ltrim ? RegExReplace(line, "^[ \t]+") : line
        if (i > 1)
            text .= joiner
        text .= ln
    }
    return text
}

HS_DecodeEscapes(s) {
    if (s = "")
        return ""
    s := StrReplace(s, "``n", "`n")
    s := StrReplace(s, "``r", "`r")
    s := StrReplace(s, "``t", "`t")
    s := StrReplace(s, "`` ", " ")
    return s
}

HS_UnescapeAhkString(s) {
    return StrReplace(s, """""", """")
}

HS_JoinLines(lines) {
    out := ""
    for i, ln in lines
        out .= (i > 1 ? "`n" : "") . ln
    return out
}
