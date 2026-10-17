; probe_cancer_form.ahk — Phase 0 DOM discovery for the cancer follow-up form.
;
; Target: RIS follow-up form at MJB/MJB3N002.do (URL contains /webcvis/MJB/MJB3N002.do).
; Produces:
;   dom_selectors.json    — best guesses for the 4 target widgets
;   dom_dump_MJB3N002.txt — full element table for manual inspection / correction
;
; Usage:
;   1) Open the target follow-up form in IE.
;   2) Run this script.
;   3) Press Ctrl+Alt+Shift+D.
;   4) Files land next to this script. Inspect and commit dom_selectors.json.

#NoEnv
#SingleInstance, Force
SetBatchLines, -1
SetTitleMatchMode, 2
SetWorkingDir, %A_ScriptDir%

; Client mode is safe here (probe is read-only), keeps us out of CH_RIS owner election.
global __CH_RIS_CLIENT := true

#Include %A_ScriptDir%\..\..\Lib\JSON.ahk

global TARGET_URL_REGEX := "i)\/webcvis\/MJB\/MJB3N002\.do"
global RADIO_LABEL   := "與原始診斷一致"
global CHECK_LABEL   := "癌症評鑑分期格式化"
global BTN_REVIEW    := "複閱結果"
global BTN_REPLY     := "回覆確認"

MsgBox, 64, cancer_staging probe, Ready.`n`nOpen the MJB3N002.do follow-up form in IE, then press Ctrl+Alt+Shift+D.
return

^!+d::
    RunProbe()
return

RunProbe(){
    wb := FindTargetIE()
    if !IsObject(wb) {
        MsgBox, 48, probe, No IE window with URL matching`n%TARGET_URL_REGEX%`nfound. Open the form and retry.
        return
    }

    elements := ScanElements(wb)
    if elements.MaxIndex() < 1 {
        MsgBox, 48, probe, Could not enumerate DOM elements. Page may be loading — retry in a moment.
        return
    }

    dumpPath := A_ScriptDir "\dom_dump_MJB3N002.txt"
    WriteDump(elements, dumpPath)

    selectors := GuessSelectors(elements)
    outPath := A_ScriptDir "\dom_selectors.json"
    WriteSelectors(selectors, outPath)

    MsgBox, 64, probe done, Wrote:`n%dumpPath%`n%outPath%`n`nOpen the JSON and confirm ids for:`n- radio_same_dx`n- checkbox_stage_fmt`n- btn_review_result`n- btn_reply_confirm
}

FindTargetIE(){
    for wb in ComObjCreate("Shell.Application").Windows() {
        try {
            hwnd := wb.hwnd
        } catch {
            continue
        }
        WinGetTitle, title, ahk_id %hwnd%
        try {
            url := wb.LocationURL
        } catch {
            url := ""
        }
        if (title ~= TARGET_URL_REGEX) || (url ~= TARGET_URL_REGEX)
            return wb
    }
    return ""
}

ScanElements(wb){
    out := []
    try {
        all := wb.document.getElementsByTagName("*")
    } catch e {
        return out
    }
    Loop, % all.length {
        try {
            el := all.item(A_Index - 1)
            rec := {}
            rec.tag := el.tagName
            rec.id := el.id
            try rec.name := el.name
            try rec.type := el.type
            try rec.value := el.value
            try rec.checked := el.checked
            try rec.className := el.className
            try rec.title := el.title
            try {
                ot := el.outerText
                if StrLen(ot) > 200
                    ot := SubStr(ot, 1, 200) "…"
                rec.outerText := RTrim(RegExReplace(ot, "\R+", " | "))
            }
            try {
                if el.parentElement {
                    pt := el.parentElement.outerText
                    if StrLen(pt) > 120
                        pt := SubStr(pt, 1, 120) "…"
                    rec.parentText := RTrim(RegExReplace(pt, "\R+", " | "))
                }
            }
            out.Push(rec)
        } catch e {
            ; skip elements that fail to introspect (some IE controls throw on .value / .checked)
        }
    }
    return out
}

WriteDump(elements, path){
    FileDelete, %path%
    header := "tag`tid`tname`ttype`tvalue`tchecked`tclassName`ttitle`touterText`tparentText`n"
    FileAppend, %header%, %path%, UTF-8
    for _, r in elements {
        line := r.tag "`t" r.id "`t" r.name "`t" r.type "`t" r.value "`t" r.checked "`t" r.className "`t" r.title "`t" r.outerText "`t" r.parentText "`n"
        FileAppend, %line%, %path%, UTF-8
    }
}

GuessSelectors(elements){
    ; form_url_regex is stored as a raw JS-style regex (Q() will JSON-escape).
    sel := {form_url_regex: "\/webcvis\/MJB\/MJB3N002\.do"}
    sel.radio_same_dx      := FindByLabel(elements, RADIO_LABEL,  "radio")
    sel.checkbox_stage_fmt := FindByLabel(elements, CHECK_LABEL,  "checkbox")
    sel.btn_review_result  := FindByLabel(elements, BTN_REVIEW,   "button")
    sel.btn_reply_confirm  := FindByLabel(elements, BTN_REPLY,    "button")
    return sel
}

FindByLabel(elements, needle, wantKind){
    ; wantKind: "radio", "checkbox", or "button". Returns a best-guess CSS selector
    ; usable with document.querySelector() based on id / name+value / tag+type.
    best := {selector:"", id:"", name:"", value:"", note:"NOT FOUND — inspect dom_dump_MJB3N002.txt and set selector manually"}
    for _, r in elements {
        kind := ""
        t := r.type
        StringLower, tLower, t
        if (r.tag = "INPUT") {
            if (tLower = "radio")
                kind := "radio"
            else if (tLower = "checkbox")
                kind := "checkbox"
            else if (tLower = "button" || tLower = "submit")
                kind := "button"
        } else if (r.tag = "BUTTON") {
            kind := "button"
        }
        if (kind != wantKind)
            continue

        hay := r.outerText . " || " . r.parentText . " || " . r.title . " || " . r.value
        if InStr(hay, needle) {
            best := {id: r.id, name: r.name, value: r.value, note: "auto-matched via label; verify"}
            ; Build a CSS selector preferring id > name+value > tag[type=…].
            if (r.id != "") {
                best.selector := "#" . r.id
            } else if (r.name != "") {
                if (r.value != "" && (kind = "radio" || kind = "checkbox"))
                    best.selector := "input[name=" . r.name . "][value=""" . r.value . """]"
                else
                    best.selector := "input[name=" . r.name . "]"
            } else if (kind = "button") {
                best.selector := "button[type=""submit""]"
            } else {
                best.selector := ""
                best.note := "no id / name / distinguishing attr — set selector manually"
            }
            break
        }
    }
    return best
}

WriteSelectors(obj, path){
    ; Manual JSON pretty-print (JSON_to's default is one-line-ish; keep it readable).
    s := "{`n"
    s .= "  ""form_url_regex"": " Q(obj.form_url_regex) ",`n"
    s .= "  ""radio_same_dx"": "      Sel(obj.radio_same_dx)      ",`n"
    s .= "  ""checkbox_stage_fmt"": " Sel(obj.checkbox_stage_fmt) ",`n"
    s .= "  ""btn_review_result"": "  Sel(obj.btn_review_result)  ",`n"
    s .= "  ""btn_reply_confirm"": "  Sel(obj.btn_reply_confirm)  "`n"
    s .= "}`n"
    FileDelete, %path%
    FileAppend, %s%, %path%, UTF-8
}

Sel(x){
    return "{""selector"": " Q(x.selector) ", ""id"": " Q(x.id) ", ""name"": " Q(x.name) ", ""value"": " Q(x.value) ", ""note"": " Q(x.note) "}"
}

Q(s){
    ; JSON-escape a string, wrap in quotes.
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, """", "\""")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return """" . s . """"
}

^!+q::ExitApp
