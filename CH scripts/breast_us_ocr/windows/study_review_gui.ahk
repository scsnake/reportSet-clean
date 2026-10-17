; study_review_gui.ahk - Windows review GUI for breast US OCR API (AHK v1)
;
; F6 = detect accession from active RIS/window/clipboard and fetch
; F7 = process current accession on Ubuntu
; F9 = launch ris_annotate.ahk using reviewed lesions_pending.json

#NoEnv
#SingleInstance Force
#Persistent
SetBatchLines, -1
SetTitleMatchMode, 2
CoordMode, Mouse, Screen
FileEncoding, UTF-8

global API_SERVER := "http://gpu-host.example.invalid:7205"
global PY_EXE := FileExist("C:\Python314\python.exe") ? "C:\Python314\python.exe" : "python"
global SCRIPT_DIR := A_ScriptDir
global CLIENT_PY := SCRIPT_DIR . "\study_client.py"
global PENDING_JSON := SCRIPT_DIR . "\lesions_pending.json"
global SUMMARY_TXT := SCRIPT_DIR . "\study_status.txt"
global ANNOTATE_AHK := SCRIPT_DIR . "\ris_annotate.ahk"

global g_accession := ""
global g_chart_no := ""
global g_study_date := ""
global g_patient_name := ""
global g_exam_name := ""
global g_exam_time := ""
global g_status := ""
global g_lesions := []
global g_side_flags := []
global g_review_result := ""
global g_main_hwnd := 0
global g_main_always_on_top := true

ParseArgs()
if (g_accession = "")
    g_accession := DetectAccession()

BuildMainGui()
return

F6::
    GuiControlGet, acc,, AccEdit
    if (Trim(acc) = "")
        acc := DetectAccession()
    GuiControl,, AccEdit, %acc%
    FetchStudy(acc)
return

F7::
    GuiControlGet, acc,, AccEdit
    ProcessStudy(Trim(acc))
return

F9::
    LaunchAnnotate()
return

#IfWinActive, Breast US OCR Review
    r::
        if MainLesionListHasFocus()
            ApplySideToSelected("R")
        else
            SendInput, r
    return

    l::
        if MainLesionListHasFocus()
            ApplySideToSelected("L")
        else
            SendInput, l
    return

    +r::
        if MainLesionListHasFocus()
            ApplySideToSelected("R")
        else
            SendInput, R
    return

    +l::
        if MainLesionListHasFocus()
            ApplySideToSelected("L")
        else
            SendInput, L
    return
#IfWinActive

BuildMainGui() {
    global

    Gui, Main:Destroy
    Gui, Main:+AlwaysOnTop +ToolWindow +Resize +Hwndg_main_hwnd
    Gui, Main:Margin, 12, 10
    Gui, Main:Font, s9, Segoe UI
    GetMainGuiGeometry(guiX, guiY, guiW, guiH)
    Gui, Main:Add, Text, xm ym w70, Accession
    Gui, Main:Add, Edit, x+8 yp-3 w170 vAccEdit, %g_accession%
    Gui, Main:Add, Button, xm y+10 w88 h26 gMainFetch Default, Fetch
    Gui, Main:Add, Button, x+6 yp w88 h26 gMainProcess, Process
    Gui, Main:Add, Button, x+6 yp w110 h26 gMainReview, Review/Edit
    Gui, Main:Add, Button, x+6 yp w110 h26 gMainAnnotate, Annotate RIS
    Gui, Main:Add, Button, x+6 yp w74 h26 gMainDetect, Detect
    lvW1 := 35, lvW2 := 40, lvW3 := 55, lvW4 := 92
    lvW5 := 55, lvW6 := 65, lvW7 := 90, lvW8 := 70
    lvW9 := 70, lvW10 := 70, lvW11 := 155, lvW12 := 120, lvW13 := 70
    listExtra := DllCall("GetSystemMetrics", "Int", 2) + 2 * DllCall("GetSystemMetrics", "Int", 45)
    listContentW := lvW1 + lvW2 + lvW3 + lvW4 + lvW5 + lvW6 + lvW7 + lvW8 + lvW9 + lvW10 + lvW11 + lvW12 + lvW13 + listExtra
    listW := MainContentWidth(guiW, listContentW)
    meta := FormatRisMeta()
    Gui, Main:Add, Text, xm y+10 w%listW% h34 vRisInfoText, %meta%
    Gui, Main:Add, Text, xm y+6 w%listW% h42 vStateText cBlue, Ready.
    Gui, Main:Add, Text, xm y+2 w%listW% h58 vStatusText cGray,
    Gui, Main:Add, ListView, xm y+6 w%listW% h300 vLesionLV gMainLesionLV Grid AltSubmit, #|Use|Side|Clock|Dist|Max mm|Dims mm|Probe|Type|Region|Graph|Flags|Frames
    LV_ModifyCol(1, lvW1)
    LV_ModifyCol(2, lvW2)
    LV_ModifyCol(3, lvW3)
    LV_ModifyCol(4, lvW4)
    LV_ModifyCol(5, lvW5)
    LV_ModifyCol(6, lvW6)
    LV_ModifyCol(7, lvW7)
    LV_ModifyCol(8, lvW8)
    LV_ModifyCol(9, lvW9)
    LV_ModifyCol(10, lvW10)
    LV_ModifyCol(11, lvW11)
    LV_ModifyCol(12, lvW12)
    LV_ModifyCol(13, lvW13)
    Gui, Main:Add, Text, xm y+8 w%listW% h48 vSideFlagsText, Detected text flags: none
    showOpt := "x" guiX " y" guiY " w" guiW " h" guiH
    if (MainSimpleRisActive())
        showOpt .= " NoActivate"
    Gui, Main:Show, %showOpt%, Breast US OCR Review
    MainSetAlwaysOnTop(true)

    if (g_accession != "")
        FetchStudy(g_accession)
}

GetMainGuiGeometry(ByRef x, ByRef y, ByRef w, ByRef h) {
    SysGet, mon, MonitorWorkArea
    scale := MainGuiScaleFactor()
    x := monLeft
    y := monTop
    h := Round((monBottom - monTop) / scale)
    workW := monRight - monLeft
    w := Round(workW * 2 / 5 / scale) - Round(150 / scale)
    if (w < 544)
        w := 544
    maxW := Round(workW / scale)
    if (w > maxW)
        w := maxW

    simpleHwnd := MainSimpleRisActiveHwnd()
    if (simpleHwnd) {
        WinGetPos, sx, sy, sw, sh, ahk_id %simpleHwnd%
        gap := Round(8 / scale)
        rightSpace := monRight - (sx + sw) - gap
        leftSpace := sx - monLeft - gap
        if (rightSpace >= w) {
            x := sx + sw + gap
        } else if (leftSpace >= w) {
            x := sx - w - gap
        } else if (rightSpace >= 544) {
            x := sx + sw + gap
            w := rightSpace
        } else if (leftSpace >= 544) {
            w := leftSpace
            x := sx - w - gap
        } else {
            x := (sx < monLeft + workW / 2) ? monRight - w : monLeft
        }
    }
}

MainGuiScaleFactor() {
    dpi := A_ScreenDPI + 0
    if (dpi <= 0) {
        hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
        dpi := DllCall("GetDeviceCaps", "Ptr", hDC, "Int", 88)
        DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
    }
    if (dpi <= 0)
        dpi := 96
    return dpi / 96.0
}

MainContentWidth(guiW, maxW := "") {
    visibleW := guiW - 24
    if (visibleW < 520)
        visibleW := 520
    if (maxW != "" && visibleW > maxW)
        visibleW := maxW
    return visibleW
}

MainSimpleRisActive() {
    return MainSimpleRisActiveHwnd() ? true : false
}

MainSimpleRisActiveHwnd() {
    if (hwnd := WinActive("simpleRISsimpleEdit ahk_class AutoHotkeyGUI"))
        return hwnd
    if (hwnd := WinActive("simple RIS ahk_class AutoHotkeyGUI"))
        return hwnd
    return 0
}

PulseMainGuiZOrder() {
    MainSetAlwaysOnTop(true)
}

MainSetAlwaysOnTop(enabled := true) {
    global g_main_hwnd, g_main_always_on_top
    g_main_always_on_top := enabled
    if (!g_main_hwnd)
        return
    SetTimer, MainAlwaysOnTopTick, % enabled ? 500 : "Off"
    if (!enabled) {
        WinSet, AlwaysOnTop, Off, ahk_id %g_main_hwnd%
        return
    }
    Gosub, MainAlwaysOnTopTick
}

MainApplyAlwaysOnTop() {
    global g_main_hwnd
    if (!g_main_hwnd)
        return
    if (MainSimpleRisActive()) {
        WinSet, AlwaysOnTop, Off, ahk_id %g_main_hwnd%
        return
    }
    WinSet, AlwaysOnTop, On, ahk_id %g_main_hwnd%
}

MainGuiClose:
MainGuiEscape:
ExitApp
return

MainGuiSize:
    if (A_EventInfo = 1)
        return
    contentW := MainContentWidth(A_GuiWidth)
    GuiControl, Main:Move, RisInfoText, w%contentW%
    GuiControl, Main:Move, StateText, w%contentW%
    GuiControl, Main:Move, StatusText, w%contentW%
    GuiControlGet, lvPos, Main:Pos, LesionLV
    if (ErrorLevel)
        return
    listH := A_GuiHeight - lvPosY - 66
    if (listH < 120)
        listH := 120
    sideY := lvPosY + listH + 8
    GuiControl, Main:Move, LesionLV, w%contentW% h%listH%
    GuiControl, Main:Move, SideFlagsText, y%sideY% w%contentW%
return

MainAlwaysOnTopOn:
    MainSetAlwaysOnTop(true)
return

MainAlwaysOnTopOff:
    MainSetAlwaysOnTop(false)
return

MainAlwaysOnTopTick:
    if (g_main_always_on_top)
        MainApplyAlwaysOnTop()
return

MainDetect:
    acc := DetectAccession()
    GuiControl, Main:, AccEdit, %acc%
return

MainFetch:
    GuiControlGet, acc, Main:, AccEdit
    FetchStudy(Trim(acc))
return

MainProcess:
    GuiControlGet, acc, Main:, AccEdit
    ProcessStudy(Trim(acc))
return

MainReview:
    if (!g_lesions.Length()) {
        MsgBox, 48, Nothing to review, No annotatable lesions are loaded.
        return
    }
    if (ShowReviewGui())
        RefreshLesionList()
return

MainAnnotate:
    LaunchAnnotate()
return

MainLesionLV:
    if (A_GuiEvent = "Normal" || A_GuiEvent = "I" || A_GuiEvent = "K")
        CopySelectedLesionToClipboard()
return

DetectAccession() {
    ; Prefer selected text / clipboard, then active window title.
    oldClip := ClipboardAll
    Clipboard :=
    SendInput, ^c
    ClipWait, 0.25
    txt := Clipboard
    Clipboard := oldClip
    if RegExMatch(txt, "\b(\d{10,15})\b", m)
        return m1

    WinGetTitle, title, A
    if RegExMatch(title, "\b(\d{10,15})\b", m2)
        return m21
    return ""
}

ParseArgs() {
    global g_accession, g_chart_no, g_study_date, g_patient_name, g_exam_name, g_exam_time
    i := 1
    while (i <= A_Args.Length()) {
        arg := A_Args[i]
        if (arg = "--accession") {
            i++, g_accession := A_Args[i]
        } else if (arg = "--chart-no") {
            i++, g_chart_no := A_Args[i]
        } else if (arg = "--study-date") {
            i++, g_study_date := A_Args[i]
        } else if (arg = "--patient-name") {
            i++, g_patient_name := A_Args[i]
        } else if (arg = "--exam-name") {
            i++, g_exam_name := A_Args[i]
        } else if (arg = "--exam-time") {
            i++, g_exam_time := A_Args[i]
        } else if (SubStr(arg, 1, 2) != "--" && g_accession = "") {
            g_accession := arg
        }
        i++
    }
}

FormatRisMeta() {
    global g_accession, g_chart_no, g_study_date, g_patient_name, g_exam_name, g_exam_time
    meta := "RIS: Acc=" . _NZ(g_accession, "?")
    if (g_chart_no != "")
        meta .= "  Chart=" . g_chart_no
    if (g_patient_name != "")
        meta .= "  Name=" . g_patient_name
    if (g_study_date != "")
        meta .= "  Date=" . g_study_date
    if (g_exam_time != "" && g_study_date = "")
        meta .= "  Time=" . g_exam_time
    if (g_exam_name != "")
        meta .= "`nExam: " . g_exam_name
    return meta
}

FetchStudy(acc) {
    global g_accession
    if (acc = "") {
        MsgBox, 48, Missing accession, Enter an accession or select it in RIS first.
        return
    }
    g_accession := Trim(acc)
    GuiControl, Main:, AccEdit, %g_accession%
    ClearFindings()
    SetState("FETCHING", "Fetching accession " . g_accession . " from gpu-host.example.invalid ...", "Blue")
    code := RunClient("fetch", g_accession)
    LoadSummary()
    if LoadPendingJson() {
        if (ResultMatchesAccession(g_accession)) {
            RefreshLesionList()
            RenderCurrentState(code)
            PulseMainGuiZOrder()
        } else {
            ClearFindings()
            SetState("STALE RESULT BLOCKED", "Wanted " . g_accession . ", file requested=" . g_status.requested_accession . ", returned=" . g_status.accession . ".", "Red")
        }
        return
    }
    SetState("ERROR", "Fetch failed before a state file was written.", "Red")
}

ProcessStudy(acc) {
    global g_accession
    if (acc = "") {
        MsgBox, 48, Missing accession, Enter an accession before processing.
        return
    }
    g_accession := Trim(acc)
    GuiControl, Main:, AccEdit, %g_accession%
    if !ConfirmLongProcess(acc)
        return
    ClearFindings()
    SetState("PROCESSING", "Processing accession " . g_accession . " on Ubuntu. This can take about a minute ...", "Blue")
    code := RunClient("process", g_accession)
    LoadSummary()
    if LoadPendingJson() {
        if (ResultMatchesAccession(g_accession)) {
            RefreshLesionList()
            RenderCurrentState(code)
            PulseMainGuiZOrder()
        } else {
            ClearFindings()
            SetState("STALE RESULT BLOCKED", "Wanted " . g_accession . ", file requested=" . g_status.requested_accession . ", returned=" . g_status.accession . ".", "Red")
        }
    } else if (code = 0) {
        LoadPendingJson()
        RefreshLesionList()
        RenderCurrentState(code)
        PulseMainGuiZOrder()
    } else if (code = 3) {
        SetState("BUSY", "Ubuntu pipeline is busy with another process request.", "Red")
    } else {
        SetState("ERROR", "Processing did not complete as annotatable OCR. See status and error detail.", "Red")
    }
}

ConfirmLongProcess(acc) {
    MsgBox, 33, Process study, Process accession %acc% on Ubuntu?`n`nThis triggers PACS retrieve + OCR and may take 40-60 seconds.
    IfMsgBox, OK
        return 1
    return 0
}

RunClient(command, acc) {
    global PY_EXE, CLIENT_PY, API_SERVER, PENDING_JSON, SUMMARY_TXT
    payloadJson := A_ScriptDir . "\study_payload.json"
    logFile := A_ScriptDir . "\study_client_last_run.log"
    FileDelete, %PENDING_JSON%
    FileDelete, %SUMMARY_TXT%
    FileDelete, %payloadJson%
    FileDelete, %logFile%
    cmd := """" . PY_EXE . """ """ . CLIENT_PY . """ " . command . " --server """ . API_SERVER . """ --accession """ . acc . """"
    shellCmd := ComSpec . " /d /c " . """" . cmd . " > """ . logFile . """ 2>&1" . """"
    RunWait, %shellCmd%, %A_ScriptDir%, Hide
    exitCode := ErrorLevel
    if !FileExist(PENDING_JSON)
        WriteClientErrorState(command, acc, exitCode, logFile)
    return exitCode
}

WriteClientErrorState(command, acc, exitCode, logFile) {
    global PENDING_JSON, SUMMARY_TXT, PY_EXE, CLIENT_PY
    logText := ""
    if FileExist(logFile) {
        FileRead, logText, %logFile%
    }
    if (Trim(logText) = "")
        logText := "(no stdout/stderr captured)"

    msg := "study_client.py did not write a state file. command=" . command . " exit=" . exitCode
    detail := "Python=" . PY_EXE . "`nClient=" . CLIENT_PY . "`n`n" . logText

    txt := "{`n"
    txt .= "  ""status"": ""error"",`n"
    txt .= "  ""message"": """ . JsonEscape(msg) . """,`n"
    txt .= "  ""error_detail"": """ . JsonEscape(detail) . """,`n"
    txt .= "  ""requested_accession"": """ . JsonEscape(acc) . """,`n"
    txt .= "  ""lesions"": [],`n"
    txt .= "  ""side_flags"": [],`n"
    txt .= "  ""source"": ""ahk_runclient""`n"
    txt .= "}`n"
    FileAppend, %txt%, %PENDING_JSON%, UTF-8

    summary := "status=error`n"
    summary .= "requested_accession=" . acc . "`n"
    summary .= "message=" . msg . "`n"
    summary .= "python=" . PY_EXE . "`n"
    summary .= "client=" . CLIENT_PY . "`n"
    summary .= "log_file=" . logFile . "`n`n"
    summary .= logText
    FileAppend, %summary%, %SUMMARY_TXT%, UTF-8
}

LoadSummary() {
    global SUMMARY_TXT
    if !FileExist(SUMMARY_TXT)
        return
    FileRead, txt, %SUMMARY_TXT%
    GuiControl, Main:, StatusText, %txt%
}

LoadPendingJson() {
    global PENDING_JSON, g_status, g_lesions, g_side_flags
    g_status := {}
    g_lesions := []
    g_side_flags := []

    if !FileExist(PENDING_JSON)
        return 0
    FileRead, raw, %PENDING_JSON%
    if ErrorLevel
        return 0

    g_status.status := JStr(raw, "status")
    g_status.message := JStr(raw, "message")
    g_status.requested_accession := JStr(raw, "requested_accession")
    g_status.accession := JStr(raw, "accession")
    g_status.patient_id := JStr(raw, "patient_id")
    g_status.study_date := JStr(raw, "study_date")
    g_status.run_status := JStr(raw, "run_status")
    g_status.finding_kind := JStr(raw, "finding_kind")
    g_status.error_detail := JStr(raw, "error_detail")
    g_status.anchored_lesion_count := JNum(raw, "anchored_lesion_count")
    g_status.unanchored_count := JNum(raw, "unanchored_count")
    g_status.frame_marker_count := JNum(raw, "frame_marker_count")
    g_status.frame_marker_side_summary := JStr(raw, "frame_marker_side_summary")

    ExtractObjectArray(raw, "lesions", arr)
    loop % arr.Length() {
        obj := arr[A_Index]
        les := {}
        les.source_kind := JStr(obj, "source_kind")
        if (les.source_kind = "")
            les.source_kind := "anchored"
        les.include := (JBool(obj, "include") ? 1 : 0)
        les.raw_side := JStr(obj, "raw_side")
        les.raw_side_hint := JStr(obj, "raw_side_hint")
        les.raw_side_inferred := JBool(obj, "raw_side_inferred") ? 1 : 0
        les.side := JStr(obj, "side")
        les.side_hint := JStr(obj, "side_hint")
        les.side_inferred := JBool(obj, "side_inferred") ? 1 : 0
        les.side_source := JStr(obj, "side_source")
        les.review_required := JBool(obj, "review_required") ? 1 : 0
        les.marker_conflict := JBool(obj, "marker_conflict") ? 1 : 0
        les.region := JStr(obj, "region")
        les.clock_start := JNum(obj, "clock_start")
        les.clock_end := JNum(obj, "clock_end")
        les.dist_cm := JNum(obj, "dist_cm")
        les.max_dim_mm := JNum(obj, "max_dim_mm")
        les.dims_text := JStr(obj, "dims_text")
        les.orientation := JStr(obj, "orientation")
        les.type := JStr(obj, "type")
        les.flags_text := JStr(obj, "flags_text")
        les.frames := JStr(obj, "frame_indices_text")
        les.caliper_count := JNum(obj, "caliper_count")
        les.marker_frame_index := JNum(obj, "marker_frame_index")
        les.marker_frame_indices := JStr(obj, "marker_frame_indices_text")
        les.marker_side := JStr(obj, "marker_side")
        les.marker_vote_side := JStr(obj, "marker_vote_side")
        les.marker_vote_text := JStr(obj, "marker_vote_text")
        les.marker_vote_tie := JBool(obj, "marker_vote_tie") ? 1 : 0
        les.marker_side_source := JStr(obj, "marker_side_source")
        les.marker_region := JStr(obj, "marker_region")
        les.marker_clock_hour := JNum(obj, "marker_clock_hour")
        les.marker_probe_orientation := JStr(obj, "marker_probe_orientation")
        les.marker_confidence := JNum(obj, "marker_confidence")
        les.marker_text := JStr(obj, "marker_text")
        g_lesions.Push(les)
    }

    ExtractObjectArray(raw, "side_flags", sfArr)
    loop % sfArr.Length() {
        obj := sfArr[A_Index]
        sf := {}
        sf.side := JStr(obj, "side")
        sf.side_hint := JStr(obj, "side_hint")
        sf.flag := JStr(obj, "flag")
        g_side_flags.Push(sf)
    }
    return 1
}

ResultMatchesAccession(acc) {
    global g_status
    acc := CanonAcc(acc)
    returnedAcc := CanonAcc(g_status.accession)
    requestedAcc := CanonAcc(g_status.requested_accession)

    if (requestedAcc != "")
        return (requestedAcc = acc)
    if (returnedAcc != "")
        return (returnedAcc = acc)
    return 0
}

CanonAcc(value) {
    return RegExReplace(Trim("" . value), "\D")
}

ExtractObjectArray(raw, key, ByRef outArr) {
    outArr := []
    keyPat := """" . key . """"
    pos := InStr(raw, keyPat)
    if (!pos)
        return 0
    start := InStr(raw, "[", false, pos)
    if (!start)
        return 0
    depth := 0
    objStart := 0
    inStr := 0
    esc := 0
    Loop, Parse, raw
    {
        idx := A_Index
        if (idx < start)
            continue
        ch := A_LoopField
        if (inStr) {
            if (esc)
                esc := 0
            else if (ch = "\")
                esc := 1
            else if (ch = """")
                inStr := 0
            continue
        }
        if (ch = """") {
            inStr := 1
        } else if (ch = "{") {
            if (depth = 0)
                objStart := idx
            depth++
        } else if (ch = "}") {
            depth--
            if (depth = 0 && objStart) {
                outArr.Push(SubStr(raw, objStart, idx - objStart + 1))
                objStart := 0
            }
        } else if (ch = "]" && depth = 0) {
            return outArr.Length()
        }
    }
    return outArr.Length()
}

RefreshLesionList() {
    global g_lesions, g_side_flags, g_status
    Gui, Main:Default
    LV_Delete()
    if (!g_lesions.Length() && !g_side_flags.Length()) {
        if (g_status.finding_kind = "negative")
            LV_Add("", "-", "-", "-", "No OCR lesions", "", "", "", "", "", "", "", "", "")
        else
            LV_Add("", "-", "-", "-", "No lesion rows", "", "", "", "", "", "", "", "", "")
    }
    loop % g_lesions.Length() {
        i := A_Index
        les := g_lesions[i]
        clk := (Trim("" . les.clock_start) = "") ? "?" : FormatClock(les.clock_start, les.clock_end)
        dist := (Trim("" . les.dist_cm) = "") ? "?" : les.dist_cm
        useTxt := les.include ? "Y" : "N"
        sideTxt := (les.side_hint != "") ? les.side_hint : les.side
        flagsTxt := FormatFindingFlags(les)
        graphTxt := FormatGraphHint(les)
        LV_Add("", i, useTxt, sideTxt, clk, dist, les.max_dim_mm, les.dims_text, FormatProbeGlyph(les.orientation), les.type, les.region, graphTxt, flagsTxt, les.frames)
    }
    AddSideFlagsToList()
    sfText := "Detected text flags: " . FormatSideFlags()
    GuiControl, Main:, SideFlagsText, %sfText%
}

AddSideFlagsToList() {
    global g_side_flags
    loop % g_side_flags.Length() {
        sf := g_side_flags[A_Index]
        sideTxt := (sf.side_hint != "") ? sf.side_hint : sf.side
        LV_Add("", "SF" . A_Index, "-", sideTxt, "-", "-", "", sf.flag, "", "TEXT", "", "", "", "")
    }
}

MainLesionListHasFocus() {
    GuiControlGet, focus, Main:FocusV
    return (focus = "LesionLV")
}

GetSelectedLesionIndex() {
    global g_lesions
    Gui, Main:Default
    row := LV_GetNext()
    if (row = 0)
        return 0
    if (row > g_lesions.Length())
        return 0
    return row
}

ApplySideToSelected(side) {
    global g_lesions
    idx := GetSelectedLesionIndex()
    if (!idx)
        return
    g_lesions[idx].side := side
    g_lesions[idx].side_hint := side
    g_lesions[idx].side_inferred := 0
    g_lesions[idx].side_source := "reviewed"
    g_lesions[idx].review_required := 0
    g_lesions[idx].marker_conflict := 0
    SaveReviewedPending()
    RefreshLesionList()
    Gui, Main:Default
    LV_Modify(idx, "Select Focus Vis")
    CopyLesionToClipboard(idx)
    SetState("SIDE SET", "Lesion " . idx . " side set to " . side . ". Clipboard updated.", "Blue")
}

CopySelectedLesionToClipboard() {
    idx := GetSelectedLesionIndex()
    if (!idx)
        return
    CopyLesionToClipboard(idx)
}

CopyLesionToClipboard(idx) {
    global g_lesions
    if (idx < 1 || idx > g_lesions.Length())
        return
    les := g_lesions[idx]
    clipText := FormatLesionClipboard(les)
    if (clipText = "")
        return
    Clipboard := clipText
}

FormatLesionClipboard(les) {
    clock := FormatClock(les.clock_start, les.clock_end)
    dist := FormatCmValue(les.dist_cm)
    size := FormatLesionSizeMm(les)
    if (clock = "" || dist = "")
        return ""
    if (size = "")
        return clock . "/" . dist
    return clock . "/" . dist . ", " . size
}

FormatCmValue(v) {
    if (Trim("" . v) = "")
        return ""
    return FormatPlainNumber(v + 0)
}

FormatLesionSizeMm(les) {
    if (Trim("" . les.max_dim_mm) != "")
        return Round(les.max_dim_mm + 0) . "mm"
    if (Trim("" . les.dims_text) != "") {
        out := ""
        dimsText := les.dims_text
        Loop, Parse, dimsText, xX
        {
            part := Trim(A_LoopField)
            if (part = "")
                continue
            out .= (out = "" ? "" : "x") . Round(part + 0)
        }
        if (out != "")
            return out . "mm"
    }
    return ""
}

FormatPlainNumber(v) {
    v := Round(v + 0, 1)
    if (Mod(v, 1) = 0)
        return Round(v)
    return v
}

ClearFindings() {
    global g_lesions, g_side_flags, g_status
    g_lesions := []
    g_side_flags := []
    g_status := {}
    Gui, Main:Default
    LV_Delete()
    GuiControl, Main:, SideFlagsText, Detected text flags: none
}

RenderCurrentState(exitCode := 0) {
    global g_status, g_lesions
    status := g_status.status
    runStatus := g_status.run_status
    findingKind := g_status.finding_kind
    msg := g_status.message
    markerNote := MarkerCountText()

    if (status = "not_found") {
        SetState("NOT PARSED", "No OCR DB record yet. Use Process to retrieve + OCR this study.", "Red")
        return
    }
    if (status = "busy") {
        SetState("BUSY", "gpu-host.example.invalid OCR pipeline is busy. Try Fetch again later.", "Red")
        return
    }
    if (status = "error" || status = "http_error") {
        SetState("ERROR", _NZ(msg, "HTTP/API error. See status text."), "Red")
        return
    }
    if (runStatus != "" && runStatus != "ocr_done") {
        detail := _NZ(g_status.error_detail, "No error_detail.")
        SetState("PARSED ERROR: " . runStatus, detail, "Red")
        return
    }
    if (findingKind = "negative") {
        SetState("NEGATIVE / NORMAL", "OCR completed and found no lesions or side-wide flags." . markerNote, "Green")
        return
    }
    if (findingKind = "positive") {
        anchored := CountFindingsByKind("anchored")
        unanchored := CountFindingsByKind("unanchored")
        sideFlags := FormatSideFlags()
        if (unanchored > 0)
            SetState("POSITIVE OCR", anchored . " anchored lesion row(s), " . unanchored . " unanchored measurement row(s)." . markerNote . " Add side and clock/dist before annotation.", "Green")
        else if (sideFlags != "none")
            SetState("POSITIVE OCR", anchored . " lesion row(s); detected text: " . sideFlags . "." . markerNote, "Green")
        else
            SetState("POSITIVE OCR", anchored . " lesion row(s) loaded as parsed." . markerNote . " Review side/graph hints before annotation.", "Green")
        return
    }
    SetState("UNKNOWN", _NZ(msg, "No recognized OCR state."), "Red")
}

FormatSideFlags() {
    global g_side_flags
    if (!g_side_flags.Length())
        return "none"
    out := ""
    loop % g_side_flags.Length() {
        sf := g_side_flags[A_Index]
        prefix := (out = "") ? "" : "; "
        out .= prefix . sf.side_hint . " " . sf.flag
    }
    return out
}

MarkerCountText() {
    global g_status
    if (Trim("" . g_status.frame_marker_count) = "")
        return ""
    if ((g_status.frame_marker_count + 0) <= 0)
        return ""
    summary := Trim("" . g_status.frame_marker_side_summary)
    if (summary != "")
        return " Graph markers: " . g_status.frame_marker_count . " (" . summary . ")."
    return " Graph markers: " . g_status.frame_marker_count . "."
}

ShowReviewGui() {
    global
    g_review_result := ""
    Gui, Review:Destroy
    Gui, Review:+AlwaysOnTop +ToolWindow
    Gui, Review:Margin, 12, 10
    Gui, Review:Font, s9, Segoe UI
    Gui, Review:Add, Text, xm ym w880, Review inferred values. R? means OCR-sequence inferred; R⟳ means graph-marker majority vote and must be ratified.
    Gui, Review:Add, Text, xm y+8 w24, Use
    Gui, Review:Add, Text, x+7 yp w48, Side
    Gui, Review:Add, Text, x+9 yp w70, Clock A
    Gui, Review:Add, Text, x+9 yp w70, Clock B
    Gui, Review:Add, Text, x+9 yp w70, Dist cm
    Gui, Review:Add, Text, x+9 yp w70, Max mm
    Gui, Review:Add, Text, x+9 yp w80, Type
    Gui, Review:Add, Text, x+9 yp w80, Region
    Gui, Review:Add, Text, x+9 yp w170, Hint

    loop % g_lesions.Length() {
        i := A_Index
        les := g_lesions[i]
        yOpt := (i = 1) ? "xm y+4" : "xm y+3"
        inclOpt := les.include ? "Checked" : ""
        sideChoice := SideChoiceIndex(les.side)
        typeChoice := TypeChoiceIndex(les.type)
        regionChoice := RegionChoiceIndex(les.region)
        hint := "[" . i . "] " . les.side_hint . " " . FormatClock(les.clock_start, les.clock_end) . "/" . les.dist_cm
        if (les.source_kind = "unanchored" && (Trim("" . les.clock_start) = "" || Trim("" . les.dist_cm) = ""))
            hint := "[" . i . "] unanchored frame " . les.frames . " - enter side + clock/dist"
        if (les.region != "")
            hint .= " " . les.region
        graphHint := FormatGraphHint(les)
        if (graphHint != "")
            hint .= " [" . graphHint . "]"
        if (les.flags_text != "")
            hint .= " {" . les.flags_text . "}"
        Gui, Review:Add, CheckBox, %yOpt% w24 vRevIncl%i% %inclOpt%,
        Gui, Review:Add, DropDownList, x+8 yp-2 w48 vRevSide%i% Choose%sideChoice%, R|L|?
        Gui, Review:Add, Edit, x+8 yp w70 vRevClockS%i%, % les.clock_start
        Gui, Review:Add, Edit, x+8 yp w70 vRevClockE%i%, % les.clock_end
        Gui, Review:Add, Edit, x+8 yp w70 vRevDist%i%, % les.dist_cm
        Gui, Review:Add, Edit, x+8 yp w70 vRevMax%i%, % les.max_dim_mm
        Gui, Review:Add, DropDownList, x+8 yp w80 vRevType%i% Choose%typeChoice%, FCC|CYST|FA|LN|SC-H|SC-V|SC-O|SUS|DU
        Gui, Review:Add, DropDownList, x+8 yp w80 vRevRegion%i% Choose%regionChoice%, Breast|AX|SCV|SUB|RETRO|PERI|NIPPLE|AREOLAR|TAIL
        Gui, Review:Add, Text, x+8 yp+3 w260, %hint%
    }
    Gui, Review:Add, Button, xm y+12 w110 h28 gReviewSave Default, Save
    Gui, Review:Add, Button, x+8 yp w90 h28 gReviewCancel, Cancel
    Gui, Review:Show,, Review OCR Lesions
    while (g_review_result = "")
        Sleep, 80
    Gui, Review:Destroy
    return (g_review_result = "save")
}

ReviewSave:
    global g_lesions, g_review_result
    Gui, Review:Submit, NoHide
    loop % g_lesions.Length() {
        i := A_Index
        inclVar := "RevIncl" . i
        sideVar := "RevSide" . i
        csVar := "RevClockS" . i
        ceVar := "RevClockE" . i
        distVar := "RevDist" . i
        maxVar := "RevMax" . i
        typeVar := "RevType" . i
        regionVar := "RevRegion" . i
        include := %inclVar%
        side := %sideVar%
        if (include && side = "?") {
            MsgBox, 48, Side required, Lesion %i% still has side "?". Choose R/L or uncheck Use.
            return
        }
        csValue := %csVar%
        distValue := %distVar%
        cs := Trim(csValue)
        dist := Trim(distValue)
        if (include && (cs = "" || dist = "")) {
            MsgBox, 48, Position required, Lesion %i% needs clock and distance before annotation. Enter them or uncheck Use.
            return
        }
        g_lesions[i].include := include
        g_lesions[i].side := side
        g_lesions[i].side_hint := side
        g_lesions[i].side_inferred := 0
        g_lesions[i].side_source := "reviewed"
        g_lesions[i].review_required := 0
        g_lesions[i].marker_conflict := 0
        g_lesions[i].clock_start := cs + 0
        ce := %ceVar%
        g_lesions[i].clock_end := (Trim(ce) = "") ? "" : ce + 0
        g_lesions[i].dist_cm := dist + 0
        g_lesions[i].max_dim_mm := %maxVar% + 0
        g_lesions[i].type := %typeVar%
        regionValue := %regionVar%
        g_lesions[i].region := (regionValue = "Breast") ? "" : regionValue
    }
    SaveReviewedPending()
    g_review_result := "save"
return

ReviewCancel:
ReviewGuiClose:
ReviewEscape:
    global g_review_result
    g_review_result := "cancel"
return

SaveReviewedPending() {
    global PENDING_JSON, g_status, g_lesions, g_side_flags
    txt := "{`n"
    txt .= "  ""status"": ""ok"",`n"
    txt .= "  ""patient_id"": """ . JsonEscape(g_status.patient_id) . """,`n"
    txt .= "  ""study_date"": """ . JsonEscape(g_status.study_date) . """,`n"
    txt .= "  ""accession"": """ . JsonEscape(g_status.accession) . """,`n"
    txt .= "  ""run_status"": """ . JsonEscape(g_status.run_status) . """,`n"
    txt .= "  ""finding_kind"": """ . JsonEscape(g_status.finding_kind) . """,`n"
    txt .= "  ""frame_marker_count"": " . JsonNum(g_status.frame_marker_count) . ",`n"
    txt .= "  ""frame_marker_side_summary"": """ . JsonEscape(g_status.frame_marker_side_summary) . """,`n"
    txt .= "  ""lesions"": [`n"
    loop % g_lesions.Length() {
        les := g_lesions[A_Index]
        comma := (A_Index < g_lesions.Length()) ? "," : ""
        txt .= "    {""include"": " . (les.include ? "true" : "false")
        txt .= ", ""source_kind"": """ . JsonEscape(les.source_kind) . """"
        txt .= ", ""raw_side"": """ . JsonEscape(les.raw_side) . """"
        txt .= ", ""raw_side_hint"": """ . JsonEscape(les.raw_side_hint) . """"
        txt .= ", ""raw_side_inferred"": " . (les.raw_side_inferred ? "true" : "false")
        txt .= ", ""side"": """ . JsonEscape(les.side) . """"
        txt .= ", ""side_hint"": """ . JsonEscape(les.side_hint) . """"
        txt .= ", ""side_inferred"": " . (les.side_inferred ? "true" : "false")
        txt .= ", ""side_source"": """ . JsonEscape(les.side_source) . """"
        txt .= ", ""review_required"": " . (les.review_required ? "true" : "false")
        txt .= ", ""marker_conflict"": " . (les.marker_conflict ? "true" : "false")
        txt .= ", ""region"": """ . JsonEscape(les.region) . """"
        txt .= ", ""clock_start"": " . JsonNum(les.clock_start)
        txt .= ", ""clock_end"": " . JsonNum(les.clock_end)
        txt .= ", ""dist_cm"": " . JsonNum(les.dist_cm)
        txt .= ", ""max_dim_mm"": " . JsonNum(les.max_dim_mm)
        txt .= ", ""dims_text"": """ . JsonEscape(les.dims_text) . """"
        txt .= ", ""orientation"": """ . JsonEscape(les.orientation) . """"
        txt .= ", ""type"": """ . JsonEscape(les.type) . """"
        txt .= ", ""flags_text"": """ . JsonEscape(les.flags_text) . """"
        txt .= ", ""frame_indices_text"": """ . JsonEscape(les.frames) . """"
        txt .= ", ""caliper_count"": " . JsonNum(les.caliper_count)
        txt .= ", ""marker_frame_index"": " . JsonNum(les.marker_frame_index)
        txt .= ", ""marker_frame_indices_text"": """ . JsonEscape(les.marker_frame_indices) . """"
        txt .= ", ""marker_side"": """ . JsonEscape(les.marker_side) . """"
        txt .= ", ""marker_vote_side"": """ . JsonEscape(les.marker_vote_side) . """"
        txt .= ", ""marker_vote_text"": """ . JsonEscape(les.marker_vote_text) . """"
        txt .= ", ""marker_vote_tie"": " . (les.marker_vote_tie ? "true" : "false")
        txt .= ", ""marker_side_source"": """ . JsonEscape(les.marker_side_source) . """"
        txt .= ", ""marker_region"": """ . JsonEscape(les.marker_region) . """"
        txt .= ", ""marker_clock_hour"": " . JsonNum(les.marker_clock_hour)
        txt .= ", ""marker_probe_orientation"": """ . JsonEscape(les.marker_probe_orientation) . """"
        txt .= ", ""marker_confidence"": " . JsonNum(les.marker_confidence)
        txt .= ", ""marker_text"": """ . JsonEscape(les.marker_text) . """}" . comma . "`n"
    }
    txt .= "  ],`n"
    txt .= "  ""side_flags"": [`n"
    loop % g_side_flags.Length() {
        sf := g_side_flags[A_Index]
        comma := (A_Index < g_side_flags.Length()) ? "," : ""
        txt .= "    {""side"": """ . JsonEscape(sf.side) . """, ""side_hint"": """ . JsonEscape(sf.side_hint) . """, ""flag"": """ . JsonEscape(sf.flag) . """}" . comma . "`n"
    }
    txt .= "  ]`n"
    txt .= "}`n"
    FileDelete, %PENDING_JSON%
    FileAppend, %txt%, %PENDING_JSON%, UTF-8
}

LaunchAnnotate() {
    global ANNOTATE_AHK, PENDING_JSON, g_lesions
    if (!FileExist(PENDING_JSON)) {
        MsgBox, 48, No reviewed JSON, Fetch or Process a study first.
        return
    }
    needsReview := 0
    loop % g_lesions.Length() {
        les := g_lesions[A_Index]
        if (les.include && (les.side = "?" || InStr(les.side_hint, "?") || les.review_required))
            needsReview := 1
        if (les.include && (Trim("" . les.clock_start) = "" || Trim("" . les.dist_cm) = ""))
            needsReview := 1
    }
    if (needsReview) {
        MsgBox, 48, Review required, At least one included finding has an inferred graph/OCR value, unknown side, or missing clock/dist. Press Review/Edit first.
        return
    }
    Run, % """" A_AhkPath """ """ ANNOTATE_AHK """ """ PENDING_JSON """", %A_ScriptDir%
}

SetStatus(text, color := "Blue") {
    GuiControl, Main:+c%color%, StatusText
    GuiControl, Main:, StatusText, %text%
}

SetState(label, text, color := "Blue") {
    GuiControl, Main:+c%color%, StateText
    GuiControl, Main:, StateText, %label%`n%text%
}

FormatClock(cs, ce) {
    if (Trim("" . cs) = "")
        return ""
    if (Trim("" . ce) != "")
        return FormatPlainNumber(cs + 0) . "-" . FormatPlainNumber(ce + 0)
    return FormatPlainNumber(cs + 0)
}

FormatProbeGlyph(orient) {
    o := Trim("" . orient)
    if (o = "")
        return ""
    StringUpper, u, o
    if (u = "HORIZONTAL" || u = "TRV" || u = "TRA" || u = "TRANS" || u = "TRANSVERSE")
        return "-"
    if (u = "VERTICAL" || u = "SAG" || u = "LON" || u = "LONG" || u = "SAGITTAL" || u = "LONGITUDINAL")
        return "|"
    if (u = "SLASH" || u = "RAD" || u = "RADIAL")
        return "/"
    if (u = "BACKSLASH" || u = "ANTI" || u = "ARAD" || u = "ANTIRAD" || u = "ANTIRADIAL")
        return "\"
    if (u = "OBL" || u = "OBLIQUE")
        return "/"
    return o
}

CountFindingsByKind(kind) {
    global g_lesions
    n := 0
    loop % g_lesions.Length() {
        les := g_lesions[A_Index]
        rowKind := (les.source_kind = "") ? "anchored" : les.source_kind
        if (rowKind = kind)
            n++
    }
    return n
}

FormatFindingFlags(les) {
    flags := les.flags_text
    if (les.source_kind = "unanchored") {
        if (flags = "")
            flags := "UNANCHORED"
        if (Trim("" . les.caliper_count) != "")
            flags .= " CAL=" . les.caliper_count
    }
    return flags
}

FormatGraphHint(les) {
    graph := les.marker_text
    if (graph = "") {
        if (les.marker_side != "")
            graph := "G:" . les.marker_side
        if (Trim("" . les.marker_clock_hour) != "")
            graph .= (graph = "" ? "" : " ") . "clk=" . les.marker_clock_hour
        if (les.marker_probe_orientation != "")
            graph .= (graph = "" ? "" : " ") . FormatProbeGlyph(les.marker_probe_orientation)
        if (les.marker_region != "")
            graph .= (graph = "" ? "" : " ") . les.marker_region
    }
    if (les.marker_vote_text != "") {
        votePrefix := (les.marker_vote_side != "") ? ("vote=" . les.marker_vote_side . " ") : "vote="
        graph .= (graph = "" ? "" : " ") . votePrefix . les.marker_vote_text
    }
    if (les.marker_vote_tie)
        graph .= (graph = "" ? "" : " ") . "TIE"
    if (Trim("" . les.marker_confidence) != "" && !InStr(graph, "c="))
        graph .= (graph = "" ? "" : " ") . "c=" . les.marker_confidence
    if (les.marker_conflict)
        graph := "CONFLICT " . graph
    if (les.review_required && graph != "")
        graph := graph . " REVIEW"
    return graph
}

SideChoiceIndex(side) {
    if (side = "R")
        return 1
    if (side = "L")
        return 2
    return 3
}

TypeChoiceIndex(t) {
    if (t = "CYST")
        return 2
    if (t = "FA")
        return 3
    if (t = "LN")
        return 4
    if (t = "SC-H")
        return 5
    if (t = "SC-V")
        return 6
    if (t = "SC-O")
        return 7
    if (t = "SUS")
        return 8
    if (t = "DU")
        return 9
    return 1
}

RegionChoiceIndex(region) {
    if (region = "AX")
        return 2
    if (region = "SCV")
        return 3
    if (region = "SUB")
        return 4
    if (region = "RETRO")
        return 5
    if (region = "PERI")
        return 6
    if (region = "NIPPLE")
        return 7
    if (region = "AREOLAR")
        return 8
    if (region = "TAIL")
        return 9
    return 1
}

JStr(obj, key) {
    if RegExMatch(obj, """" . key . """\s*:\s*""([^""]*)""", m)
        return JsonUnescape(m1)
    return ""
}

JNum(obj, key) {
    if RegExMatch(obj, """" . key . """\s*:\s*(null|-?[\d.]+)", m) {
        if (m1 = "null")
            return ""
        return m1
    }
    return ""
}

JBool(obj, key) {
    if RegExMatch(obj, """" . key . """\s*:\s*(true|false)", m)
        return (m1 = "true")
    return 0
}

JsonEscape(s) {
    s := "" . s
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, """", "\""")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    return s
}

JsonUnescape(s) {
    s := StrReplace(s, "\""", """")
    s := StrReplace(s, "\\", "\")
    return s
}

JsonNum(v) {
    if (Trim("" . v) = "")
        return "null"
    return "" . (v + 0)
}

_NZ(value, fallback) {
    return (Trim("" . value) = "") ? fallback : value
}
