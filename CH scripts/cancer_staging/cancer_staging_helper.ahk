; cancer_staging_helper.ahk — human-in-the-loop cancer-staging workflow driver.
;
; Reads queue.json (produced by `uv run python main.py fetch-todo`), walks each
; row: chart-search in RIS list IE, open cancer-tnm in Chrome, append staged text
; to the report, click the 4 widgets on MJB3N002.do, write results back to the
; Google Sheet via `uv run python main.py write-back`.
;
; Owner model: this is a CLIENT of the CH_RIS IPC bridge (autorun owns).

#NoEnv
#SingleInstance, Force
SendMode Input
SetBatchLines, -1
CoordMode, Mouse, Screen
CoordMode, Tooltip, Screen
SetTitleMatchMode, 2
SetControlDelay, -1
SetWorkingDir, %A_ScriptDir%

; Must be set BEFORE the first #include that may trigger owner election.
global __CH_RIS_CLIENT := true

#Include %A_ScriptDir%\..\..\Lib\portalLib.ahk
#Include %A_ScriptDir%\..\..\Lib\Acc.ahk
#Include %A_ScriptDir%\..\..\Lib\.NetGetControl.ahk
#Include %A_ScriptDir%\..\..\Lib\JXON.ahk
#Include %A_ScriptDir%\..\..\Lib\Chrome.ahk
#Include %A_ScriptDir%\..\..\Lib\WBGet.ahk
#Include %A_ScriptDir%\..\..\Lib\RisImpax.ahk
#Include %A_ScriptDir%\..\..\Lib\CH_RIS_Client.ahk
#Include %A_ScriptDir%\..\..\Lib\LogRetention.ahk

global thisPlace := getPlace()
global CH_RIS

; ---------------- Config ----------------
global QUEUE_PATH        := A_ScriptDir . "\queue.json"
global SELECTORS_PATH    := A_ScriptDir . "\dom_selectors.json"
global LOG_PATH          := A_ScriptDir . "\logs\helper_" . A_YYYY . A_MM . A_DD . ".log"
global UV_EXE            := "uv"
global PY_MAIN           := A_ScriptDir . "\main.py"
global CANCER_TNM_URL    := "https://cancer-tnm.firebaseapp.com/#/"
global LIST_URL_REGEX    := "i)\/webcvis\/MJB\/MJB3W001\.do"
global REPORT_URL_REGEX  := "i)\/webcvis\/MJB\/MJB3A002\.do"
global FOLLOWUP_URL_REGEX := "i)\/webcvis\/MJB\/MJB3N002\.do"

; ---------------- State ----------------
global QueueRows := []          ; parsed from queue.json
global CurRow := ""             ; current row object
global CurIdx := 0              ; 1-based index into QueueRows
global Selectors := ""          ; parsed from dom_selectors.json
global StagedText := ""         ; the staging block waiting to be applied
global HelperHwnd := 0

; ---------------- Bootstrap ----------------
FileCreateDir, %A_ScriptDir%\logs
LogRetention_DeleteFilesOlderThan(A_ScriptDir "\logs", "helper_*.log")
LoadQueue()
LoadSelectors()
BuildGui()
LoadCurrent(1)
return

; ---------------- Queue ----------------
LoadQueue(){
    global QueueRows
    if !FileExist(QUEUE_PATH) {
        MsgBox, 48, cancer_staging, queue.json not found at:`n%QUEUE_PATH%`n`nRun ``uv run python main.py fetch-todo`` first.
        ExitApp
    }
    FileRead, raw, %QUEUE_PATH%
    parsed := Jxon_Load(raw)
    if !IsObject(parsed) {
        MsgBox, 48, cancer_staging, queue.json failed to parse.
        ExitApp
    }
    QueueRows := parsed
    Log("queue loaded: " QueueRows.MaxIndex() " row(s)")
}

LoadSelectors(){
    global Selectors
    if !FileExist(SELECTORS_PATH) {
        Log("dom_selectors.json missing — will refuse Apply until it exists")
        Selectors := ""
        return
    }
    FileRead, raw, %SELECTORS_PATH%
    Selectors := Jxon_Load(raw)
    Log("selectors loaded")
}

; ---------------- GUI ----------------
BuildGui(){
    global HelperHwnd
    Gui, Main:New, +LastFound +AlwaysOnTop +Resize +HwndHelperHwnd, cancer_staging helper
    Gui, Main:Font, s9, Segoe UI

    Gui, Main:Add, Text, xm w80, Row (queue)
    Gui, Main:Add, Text, x+5 yp w360 vLblRow, —
    Gui, Main:Add, Button, x+10 yp-4 w60 gGoPrev, ‹ Prev
    Gui, Main:Add, Button, x+3 yp w60 gGoNext, Next ›

    Gui, Main:Add, Text, xm w80, Chart no
    Gui, Main:Add, Edit, x+5 yp w200 ReadOnly vTxtChartNo
    Gui, Main:Add, Button, x+10 yp gDoSearchChart, Search chart in RIS

    Gui, Main:Add, Text, xm w80, 癌別 guess
    Gui, Main:Add, Edit, x+5 yp w200 vTxtCancerType
    Gui, Main:Add, Text, x+10 yp w300 vLblGuessReason, —

    Gui, Main:Font, s8, Consolas
    Gui, Main:Add, GroupBox, xm w720 h300 Section, Source columns
    Gui, Main:Add, Text, xp+10 yp+20 w80, 報告內容
    Gui, Main:Add, Edit, x+5 yp w620 h60 ReadOnly vTxtReport
    Gui, Main:Add, Text, xs+10 y+3 w80, 病理報告
    Gui, Main:Add, Edit, x+5 yp w620 h60 ReadOnly vTxtPatho
    Gui, Main:Add, Text, xs+10 y+3 w80, 臨床診斷
    Gui, Main:Add, Edit, x+5 yp w620 h40 ReadOnly vTxtDx
    Gui, Main:Add, Text, xs+10 y+3 w80, 備註
    Gui, Main:Add, Edit, x+5 yp w620 h40 ReadOnly vTxtNotes

    Gui, Main:Font, s9, Segoe UI
    Gui, Main:Add, GroupBox, xm y+15 w720 h180 Section, Staging block (append to RIS report)
    Gui, Main:Add, Button, xp+10 yp+20 gDoOpenCancerTnm, Open cancer-tnm
    Gui, Main:Add, Button, x+5 yp gDoReadClipboard, Read clipboard → staging
    Gui, Main:Add, Text, x+10 yp+3 w200 vLblStagingLen, 0 chars
    Gui, Main:Font, s8, Consolas
    Gui, Main:Add, Edit, xs+10 y+5 w700 h120 vTxtStaged,

    Gui, Main:Font, s9, Segoe UI
    Gui, Main:Add, Button, xm y+15 w160 h32 gDoApply, [Apply] Append + Confirm
    Gui, Main:Add, Button, x+10 yp w160 h32 gDoSkipDone, Skip: 完成 (no stage)
    Gui, Main:Add, Button, x+10 yp w160 h32 gDoSkipNoted, Skip: 已備註
    Gui, Main:Add, Text, x+15 yp+8 w180 vLblStatus, ready

    Gui, Main:Show, w750 h700, cancer_staging helper
}

MainGuiClose:
MainGuiEscape:
    ExitApp
return

GoPrev:
    LoadCurrent(CurIdx - 1)
return
GoNext:
    LoadCurrent(CurIdx + 1)
return

LoadCurrent(idx){
    global QueueRows, CurRow, CurIdx, StagedText
    if (idx < 1 || idx > QueueRows.MaxIndex()) {
        SetStatus("index out of range")
        return
    }
    CurIdx := idx
    CurRow := QueueRows[idx]
    StagedText := ""
    GuiControl, Main:, LblRow, % idx " / " QueueRows.MaxIndex() " — sheet row " CurRow.row_idx
    GuiControl, Main:, TxtChartNo, % CurRow.chart_no
    GuiControl, Main:, TxtCancerType, % (CurRow.cancer_type_existing ? CurRow.cancer_type_existing : CurRow.guess)
    GuiControl, Main:, LblGuessReason, % (CurRow.guess ? "guess=" CurRow.guess " (via " CurRow.matched_column ": " CurRow.matched_snippet ")" : "no rule matched — pick manually")
    GuiControl, Main:, TxtReport, % CurRow.report_txt
    GuiControl, Main:, TxtPatho,  % CurRow.patho_txt
    GuiControl, Main:, TxtDx,     % CurRow.dx_txt
    GuiControl, Main:, TxtNotes,  % CurRow.notes_txt
    GuiControl, Main:, TxtStaged,
    GuiControl, Main:, LblStagingLen, 0 chars
    SetStatus("row " idx " loaded")
}

; ---------------- Chart search (list IE) ----------------
DoSearchChart:
    SearchChartInRisList()
return

SearchChartInRisList(){
    global CurRow
    GuiControlGet, chartNo, Main:, TxtChartNo
    chartNo := Trim(chartNo)
    if (chartNo = "") {
        SetStatus("no chart_no")
        return
    }
    listWb := FindIeByUrlRegex(LIST_URL_REGEX)
    if !IsObject(listWb) {
        MsgBox, 48, cancer_staging, No RIS worklist IE window found (URL must match MJB3W001.do). Open the RIS list first.
        return
    }
    try {
        listWb.document.getElementById("patno").value := chartNo
        listWb.document.getElementById("checktimestart").value := DateOffset(-365)
        listWb.document.getElementById("checktimeend").value   := DateOffset(0)
        try listWb.document.getElementById("checkdruserid").value := ""
        try listWb.document.getElementById("status").value := ""
        listWb.document.getElementById("QueryButton").click()
    } catch e {
        MsgBox, 48, cancer_staging, DOM interaction on RIS list failed: %e%
        return
    }
    try {
        WinActivate, % "ahk_id " listWb.hwnd
    }
    SetStatus("searched chart " chartNo " — pick a row in RIS")
}

DateOffset(daysDelta){
    ; RIS list expects YYYY/MM/DD.
    t := A_Now
    t += daysDelta, Days
    FormatTime, s, %t%, yyyy/MM/dd
    return s
}

; ---------------- cancer-tnm in Chrome ----------------
DoOpenCancerTnm:
    (new Chrome()).OpenOrNavigate(CANCER_TNM_URL, "https://cancer-tnm.firebaseapp.com")
    SetStatus("opened cancer-tnm — complete T/N/M/Stage, copy result, then click Read clipboard")
return

DoReadClipboard:
    ReadClipboardStaging()
return

ReadClipboardStaging(){
    global StagedText
    clip := Trim(Clipboard)
    if (clip = "") {
        SetStatus("clipboard empty")
        return
    }
    StagedText := clip
    GuiControl, Main:, TxtStaged, %clip%
    GuiControl, Main:, LblStagingLen, % StrLen(clip) " chars"
    SetStatus("staging text loaded from clipboard — review, then Apply")
}

; ---------------- Apply ----------------
DoApply:
    ApplyStaging()
return

ApplyStaging(){
    global CurRow, StagedText, Selectors
    GuiControlGet, staged, Main:, TxtStaged
    staged := Trim(staged, " `r`n`t")
    if (staged = "") {
        MsgBox, 48, cancer_staging, No staging text to apply.
        return
    }
    GuiControlGet, cancerType, Main:, TxtCancerType
    cancerType := Trim(cancerType)
    if (cancerType = "") {
        MsgBox, 48, cancer_staging, 癌別 is empty — fill it before applying.
        return
    }

    ; 1) Append staging block to the RIS report editor.
    RisReports := getRisReports()
    if !IsObject(RisReports) {
        MsgBox, 48, cancer_staging, getRisReports() returned nothing — is a RIS report window open?
        return
    }
    setReportText(staged, "", RisReports, -1)   ; -1 = append; see Lib\RisImpax.ahk:2473
    Sleep, 200
    try CH_RIS.activate()

    ; 2) Follow-up form: click radio → checkbox → 複閱結果 → 回覆確認.
    if !IsObject(Selectors) {
        MsgBox, 48, cancer_staging, dom_selectors.json missing — cannot click follow-up widgets.`nRun probe_cancer_form.ahk first.
        return
    }
    followWb := FindIeByUrlRegex(FOLLOWUP_URL_REGEX)
    if !IsObject(followWb) {
        MsgBox, 48, cancer_staging, No MJB3N002.do window found. Open the follow-up form and retry Apply.
        return
    }
    result := ClickFollowupWidgets(followWb, Selectors)
    if !result.ok {
        MsgBox, 48, cancer_staging, % "Follow-up click failed: " . result.error
        return
    }

    ; 3) Wait for page contents to change, then close.
    if WaitForPageChange(followWb, 8000) {
        try hwnd := followWb.hwnd
        if hwnd {
            WinClose, ahk_id %hwnd%
            SetStatus("follow-up submitted + closed")
        }
    } else {
        SetStatus("follow-up submitted but page did not change within 8s — leaving window open")
    }

    ; 4) Write-back to sheet.
    WriteBack(CurRow.row_idx, cancerType, "完成", "")
    LoadCurrent(CurIdx + 1)
}

ClickFollowupWidgets(wb, sel){
    doc := wb.document
    ; Radio 與原始診斷一致
    r := ClickBySelector(doc, sel.radio_same_dx, "radio_same_dx", "radio")
    if !r.ok
        return r
    Sleep, 80
    ; Checkbox 癌症評鑑分期格式化
    r := ClickBySelector(doc, sel.checkbox_stage_fmt, "checkbox_stage_fmt", "checkbox")
    if !r.ok
        return r
    Sleep, 80
    ; 複閱結果 — usually null (it's a section header, not a button). Skip if selector empty.
    if (sel.btn_review_result.selector != "" && sel.btn_review_result.selector != "null") {
        r := ClickBySelector(doc, sel.btn_review_result, "btn_review_result", "button")
        if !r.ok
            return r
        Sleep, 200
    }
    ; 回覆確認 (submit)
    r := ClickBySelector(doc, sel.btn_reply_confirm, "btn_reply_confirm", "button")
    if !r.ok
        return r
    return {ok:true}
}

ClickBySelector(doc, entry, label, kind){
    sel := entry.selector
    if (sel = "" || sel = "null")
        return {ok:false, error: label ".selector empty in dom_selectors.json"}
    try {
        el := doc.querySelector(sel)
    } catch e {
        return {ok:false, error: label " querySelector failed (" sel "): " e.Message}
    }
    if !IsObject(el)
        return {ok:false, error: label " selector matched nothing: " sel}
    try {
        if (kind = "checkbox") {
            if (!el.checked)
                el.click()
            el.checked := true
        } else if (kind = "radio") {
            el.checked := true
            el.click()
        } else {
            el.click()
        }
    } catch e {
        return {ok:false, error: label " click failed: " e.Message}
    }
    return {ok:true}
}

WaitForPageChange(wb, timeoutMs){
    ; Considered "changed" when URL differs OR readyState transitions loading→complete OR hwnd goes away.
    startUrl := ""
    startRs  := 4
    try startUrl := wb.LocationURL
    try startRs  := wb.ReadyState
    endTick := A_TickCount + timeoutMs
    Loop {
        Sleep, 150
        try {
            if !WinExist("ahk_id " wb.hwnd)
                return true
            curUrl := wb.LocationURL
            curRs  := wb.ReadyState
            if (curUrl != startUrl)
                return true
            if (startRs = 4 && curRs != 4)
                return true
        } catch e {
            return true         ; wb gone / navigation in progress
        }
        if (A_TickCount > endTick)
            return false
    }
}

; ---------------- Skip actions ----------------
DoSkipDone:
    GuiControlGet, ct, Main:, TxtCancerType
    ct := Trim(ct)
    if (ct = "")
        ct := ""    ; allow empty; user chose to skip
    WriteBack(CurRow.row_idx, ct, "完成", "")
    SetStatus("skipped as 完成")
    LoadCurrent(CurIdx + 1)
return

DoSkipNoted:
    InputBox, reason, cancer_staging, Reason for 已備註 (pending path / no staging needed / etc.):
    if ErrorLevel
        return
    GuiControlGet, ct, Main:, TxtCancerType
    WriteBack(CurRow.row_idx, Trim(ct), "已備註", reason)
    SetStatus("skipped as 已備註")
    LoadCurrent(CurIdx + 1)
return

; ---------------- Sheet write-back (shell out to Python) ----------------
WriteBack(rowIdx, cancerType, status, notes){
    ; Build the argument list for main.py write-back and run via uv. Runs synchronously
    ; but the actual sheet call is a few hundred ms.
    args := " write-back --row " . rowIdx
    if (cancerType != "")
        args .= " --cancer-type " . QuoteArg(cancerType)
    if (status != "")
        args .= " --status " . QuoteArg(status)
    if (notes != "")
        args .= " --notes " . QuoteArg(notes)
    cmd := "cmd /c " . Chr(34) . UV_EXE . Chr(34) . " run --project " . Chr(34) . A_ScriptDir . Chr(34) . " python " . Chr(34) . PY_MAIN . Chr(34) . args
    Log("write-back cmd: " cmd)
    RunWait, %cmd%, %A_ScriptDir%, Hide UseErrorLevel
    if (ErrorLevel != 0)
        Log("write-back FAILED, exit=" ErrorLevel)
}

QuoteArg(s){
    ; Escape a single command-line argument for cmd.exe. Wraps in double quotes and
    ; doubles internal quotes.
    s := StrReplace(s, Chr(34), Chr(34) . Chr(34))
    return Chr(34) . s . Chr(34)
}

; ---------------- IE window discovery ----------------
FindIeByUrlRegex(rx){
    for wb in ComObjCreate("Shell.Application").Windows() {
        try {
            url := wb.LocationURL
            if (url ~= rx)
                return wb
        } catch {
            continue
        }
    }
    return ""
}

; ---------------- Misc ----------------
SetStatus(msg){
    GuiControl, Main:, LblStatus, %msg%
    Log(msg)
}

Log(msg){
    FileAppend, % A_YYYY "-" A_MM "-" A_DD " " A_Hour ":" A_Min ":" A_Sec " " msg "`n", %LOG_PATH%, UTF-8
}

^!+q::ExitApp
