; monitor_cancer_recheck.ahk — read-only MJB3N002 contract monitor.
;
; This script never clicks a control and never records report text or patient data.
; It records only the fixed recheck contract, report character count, timestamps,
; and whether the target IE document navigated/disappeared after the pre-submit
; snapshot.
;
; Hotkeys:
;   Ctrl+Alt+Shift+M  capture another safe snapshot
;   Ctrl+Alt+Shift+Q  exit

#NoEnv
#SingleInstance, Force
#Persistent
SetBatchLines, -1
SetTitleMatchMode, 2
SetWorkingDir, %A_ScriptDir%

global TARGET_URL_REGEX := "i)\/webcvis\/MJB\/MJB3N002\.do"
global LOG_DIR := A_ScriptDir . "\logs"
global LOG_PATH := ""
global TargetWb := ""
global TargetHwnd := 0
global TargetDocId := 0
global PreCaptured := false
global CompletionCaptured := false
global InitialSnapshotCaptured := false
global MissingPolls := 0

FileCreateDir, %LOG_DIR%
FormatTime, runStamp, %A_Now%, yyyyMMdd_HHmmss
LOG_PATH := LOG_DIR . "\recheck_monitor_" . runStamp . ".log"
WriteHeader()
Menu, Tray, Tip, Cancer staging recheck monitor
TrayTip, Cancer staging monitor, Waiting for an MJB3N002 form. No PHI will be logged., 5, 1
SetTimer, MonitorTarget, 200
return

MonitorTarget:
    MonitorOnce()
return

^!+m::
    ManualSnapshot()
return

^!+q::
    LogEvent("monitor_exit", "manual=true")
    ExitApp
return

MonitorOnce(){
    global TargetWb, TargetHwnd, TargetDocId, PreCaptured
    global InitialSnapshotCaptured
    global CompletionCaptured, MissingPolls
    global TARGET_URL_REGEX

    ; Once the verified pre-submit form is captured, stay bound to that exact
    ; IE window. IE may replace COM document wrappers during ordinary control
    ; changes, so wrapper identity is not a reliable submission signal.
    if (PreCaptured && !CompletionCaptured) {
        targetGone := false
        if !IsObject(TargetWb) {
            targetGone := true
        } else {
            try targetUrl := TargetWb.LocationURL
            catch e
                targetGone := true
            if (!targetGone && !(targetUrl ~= TARGET_URL_REGEX))
                targetGone := true
            if (!targetGone) {
                try targetDoc := TargetWb.document
                catch e
                    targetGone := true
            }
            if (!targetGone && !IsObject(FindForm(targetDoc)))
                targetGone := true
        }
        if (targetGone) {
            MissingPolls += 1
            if (MissingPolls >= 3) {
                LogEvent("post_submit_observed", "reason=verified_form_disappeared")
                CompletionCaptured := true
                TrayTip, Cancer staging monitor, Submission/navigation observed. The safe log is ready., 8, 1
            }
        } else {
            MissingPolls := 0
        }
        return
    }

    wb := FindTargetIE()
    if !IsObject(wb) {
        if (PreCaptured && !CompletionCaptured) {
            MissingPolls += 1
            if (MissingPolls >= 3) {
                LogEvent("post_submit_observed", "reason=target_window_or_page_disappeared")
                CompletionCaptured := true
                TrayTip, Cancer staging monitor, Submission/navigation observed. The safe log is ready., 8, 1
            }
        }
        return
    }

    MissingPolls := 0
    try hwnd := wb.hwnd
    catch e
        return
    try doc := wb.document
    catch e
        return

    docId := ComObjValue(doc)
    if (!TargetHwnd || hwnd != TargetHwnd) {
        TargetWb := wb
        TargetHwnd := hwnd
        TargetDocId := docId
        PreCaptured := false
        CompletionCaptured := false
        InitialSnapshotCaptured := false
        LogEvent("target_found", "ready=true")
    }

    if (!PreCaptured) {
        snapshot := ReadSafeSnapshot(doc)
        if (!InitialSnapshotCaptured) {
            WriteSnapshot("initial_snapshot", snapshot)
            InitialSnapshotCaptured := true
        }
        if (snapshot.readable && snapshot.contract_ok) {
            WriteSnapshot("pre_submit", snapshot)
            PreCaptured := true
            TargetDocId := docId
            TrayTip, Cancer staging monitor, Required form contract captured. You may click 回覆確認 manually., 8, 1
        }
    }
}

ManualSnapshot(){
    wb := FindTargetIE()
    if !IsObject(wb) {
        TrayTip, Cancer staging monitor, No MJB3N002 IE form found., 5, 2
        return
    }
    try snapshot := ReadSafeSnapshot(wb.document)
    catch e {
        TrayTip, Cancer staging monitor, The target form is not readable yet., 5, 2
        return
    }
    WriteSnapshot("manual_snapshot", snapshot)
    TrayTip, Cancer staging monitor, Safe snapshot captured., 5, 1
}

FindTargetIE(){
    global TARGET_URL_REGEX
    fallback := ""
    formCandidate := ""
    for wb in ComObjCreate("Shell.Application").Windows() {
        try url := wb.LocationURL
        catch e
            continue
        if ((url ~= TARGET_URL_REGEX) && !IsObject(fallback))
            fallback := wb
        try doc := wb.document
        catch e
            continue
        form := FindForm(doc)
        radio := FindNamedValue(doc, "recheck", "0")
        cancer := FindNamedValue(doc, "cancer", "Y")
        button := FindSubmitButton(doc)
        if (IsObject(form) && IsObject(radio) && IsObject(cancer) && IsObject(button)) {
            if !IsObject(formCandidate)
                formCandidate := wb
            try radioChecked := radio.checked
            catch e
                radioChecked := false
            try cancerChecked := cancer.checked
            catch e
                cancerChecked := false
            if (radioChecked && cancerChecked)
                return wb
        }
    }
    if IsObject(formCandidate)
        return formCandidate
    return fallback
}

ReadSafeSnapshot(doc){
    out := {readable:false, contract_ok:false}
    form := FindForm(doc)
    radio := FindNamedValue(doc, "recheck", "0")
    cancer := FindNamedValue(doc, "cancer", "Y")
    button := FindSubmitButton(doc)
    exam := FindNamedValue(doc, "exam", "")
    if !IsObject(exam) {
        try exam := doc.getElementById("exam")
    }

    if (!IsObject(form) || !IsObject(radio) || !IsObject(cancer) || !IsObject(button)) {
        out.error := "missing DOM field(s): form=" . BoolText(IsObject(form))
        out.error .= ",radio=" . BoolText(IsObject(radio))
        out.error .= ",cancer=" . BoolText(IsObject(cancer))
        out.error .= ",button=" . BoolText(IsObject(button))
        return out
    }

    try out.form_name := SafeString(form.name)
    catch e
        out.form_name := "unreadable"
    try out.form_method := SafeString(form.method)
    catch e
        out.form_method := "unreadable"
    try out.form_action := SafeAction(form.action)
    catch e
        out.form_action := "unreadable"
    try out.radio_value := SafeString(radio.value)
    catch e
        out.radio_value := "unreadable"
    try out.radio_checked := radio.checked ? "true" : "false"
    catch e
        out.radio_checked := "unreadable"
    try out.cancer_value := SafeString(cancer.value)
    catch e
        out.cancer_value := "unreadable"
    try out.cancer_checked := cancer.checked ? "true" : "false"
    catch e
        out.cancer_checked := "unreadable"
    try out.button_type := SafeString(button.type)
    catch e
        out.button_type := "unreadable"
    try out.button_text := SafeString(button.innerText)
    catch e
        out.button_text := "unreadable"
    out.button_onclick := ReadButtonOnclick(button)
    out.token_present := IsObject(FindNamedValue(doc, "org.apache.struts.taglib.html.TOKEN", "")) ? "true" : "false"
    try out.exam_length := IsObject(exam) ? StrLen(exam.value) : -1
    catch e
        out.exam_length := -1
    out.readable := true

    out.contract_ok := (out.form_name = "MJB3N2Form" && out.radio_value = "0" && out.radio_checked = "true" && out.cancer_value = "Y" && out.cancer_checked = "true" && out.button_onclick = "submitButton('RECHECKSAVE','RECHECKSAVE')")
    return out
}

FindForm(doc){
    try forms := doc.forms
    catch e
        return ""
    Loop, % forms.length {
        try form := forms.item(A_Index - 1)
        catch e
            continue
        try name := form.name
        catch e
            name := ""
        if (name = "MJB3N2Form")
            return form
    }
    return ""
}

FindNamedValue(doc, name, wantedValue){
    try elements := doc.getElementsByName(name)
    catch e
        return ""
    Loop, % elements.length {
        try el := elements.item(A_Index - 1)
        catch e
            continue
        if (wantedValue = "")
            return el
        try value := "" . el.value
        catch e
            value := ""
        if (value = wantedValue)
            return el
    }
    return ""
}

FindSubmitButton(doc){
    try buttons := doc.getElementsByTagName("button")
    catch e
        return ""
    fallback := ""
    Loop, % buttons.length {
        try button := buttons.item(A_Index - 1)
        catch e
            continue
        try kind := button.type
        catch e
            kind := ""
        StringLower, kind, kind
        if (kind != "submit")
            continue
        if !IsObject(fallback)
            fallback := button
        if (ReadButtonOnclick(button) = "submitButton('RECHECKSAVE','RECHECKSAVE')")
            return button
    }
    return fallback
}

ReadButtonOnclick(button){
    raw := ""
    try {
        attr := button.attributes.getNamedItem("onclick")
        if IsObject(attr)
            raw .= " " . attr.nodeValue
    }
    try raw .= " " . button.getAttribute("onclick", 2)
    try raw .= " " . button.outerHTML
    if RegExMatch(raw, "i)submitButton[^>]*RECHECKSAVE[^>]*RECHECKSAVE")
        return "submitButton('RECHECKSAVE','RECHECKSAVE')"
    return "missing_or_unexpected"
}

WriteHeader(){
    global LOG_PATH
    header := "# C hospital MJB3N002 recheck monitor`n"
    header .= "# PHI policy: no patient identifiers, URLs, or report text are recorded.`n"
    header .= "started_at=" . IsoNow() . "`n"
    header .= "target_page=MJB3N002`n"
    FileAppend, %header%, %LOG_PATH%, UTF-8
}

WriteSnapshot(kind, s){
    detail := "readable=" . BoolText(s.readable)
    detail .= " contract_ok=" . BoolText(s.contract_ok)
    if (s.readable) {
        detail .= " form_name=" . LogValue(s.form_name)
        detail .= " form_method=" . LogValue(s.form_method)
        detail .= " form_action=" . LogValue(s.form_action)
        detail .= " radio_value=" . LogValue(s.radio_value)
        detail .= " radio_checked=" . LogValue(s.radio_checked)
        detail .= " cancer_value=" . LogValue(s.cancer_value)
        detail .= " cancer_checked=" . LogValue(s.cancer_checked)
        detail .= " button_type=" . LogValue(s.button_type)
        detail .= " button_text=" . LogValue(s.button_text)
        detail .= " button_onclick=" . LogValue(s.button_onclick)
        detail .= " token_present=" . LogValue(s.token_present)
        detail .= " exam_length=" . s.exam_length
    } else {
        detail .= " error=" . LogValue(s.error)
    }
    LogEvent(kind, detail)
}

LogEvent(kind, detail){
    global LOG_PATH
    line := IsoNow() . " event=" . kind
    if (detail != "")
        line .= " " . detail
    line .= "`n"
    FileAppend, %line%, %LOG_PATH%, UTF-8
}

SafeAction(value){
    ; Keep only a known route suffix, never host/query/path parameters.
    value := SafeString(value)
    if RegExMatch(value, "i)(/webcvis/MJB/MJB3N002\.do)", m)
        return m1
    return "unexpected_action"
}

SafeString(value){
    value := "" . value
    value := StrReplace(value, "`r", " ")
    value := StrReplace(value, "`n", " ")
    value := RegExReplace(value, "\s+", " ")
    return Trim(value)
}

LogValue(value){
    value := SafeString(value)
    value := StrReplace(value, "\", "\\")
    value := StrReplace(value, Chr(34), "\" . Chr(34))
    value := StrReplace(value, " ", "\x20")
    return Chr(34) . value . Chr(34)
}

BoolText(value){
    return value ? "true" : "false"
}

IsoNow(){
    FormatTime, stamp, %A_Now%, yyyy-MM-ddTHH:mm:ss
    return stamp
}
