﻿; MammoPdfDB.ahk -- AHK v1 helper to query the local mammo screening PDF index.
;
; The index is built by:
;   "C:\Users\raduser\Documents\reportSet\CH scripts\mammo_pdf_db\search_pdf_db.py"  (run daily by update.bat)
;
; Usage from YCH_mammo_Enh.ahk:
;
;   #include <JXON>
;   #include <MammoPdfDB>
;
;   recs := MammoPdfDB_Query({nid: "TEST_NID_001"})         ; list of record objects
;   recs := MammoPdfDB_Query({name: "MOCK_PATIENT"})
;   recs := MammoPdfDB_Query({hosp: "0000000000"})
;   recs := MammoPdfDB_Query({date: "115/04/22"})         ; ROC date or ISO
;   if (recs.MaxIndex()) {
;       r := recs[1]
;       msgbox % "match: " r.name " ID=" r.national_id "`n"
;             . "exam=" r.exam_iso " hosp=" r.hospital_code "`n"
;             . "PDF: " r.pdf_path " p" r.form_page
;   }
;
; Pre-reqs:
;   - `uv` on PATH (single-file uv script handles dependencies).
;   - The Python script's path is configurable via MammoPdfDB_PyPath below.
;   - JXON.ahk on the include path (already in Lib\).

global MammoPdfDB_PyPath  := "C:\Users\raduser\Documents\reportSet\CH scripts\mammo_pdf_db\search_pdf_db.py"
global MammoPdfDB_ShowPath := "C:\Users\raduser\Documents\reportSet\CH scripts\mammo_pdf_db\mammo_show.py"
global MammoPdfDB_UpdateBat := "C:\Users\raduser\Documents\reportSet\CH scripts\mammo_pdf_db\update.bat"
global MammoPdfDB_DbPath  := ""  ; blank => script default (mammo_pdf.sqlite next to py)
global MammoPdfDB_LastNid := ""  ; debounce: avoid re-spawning for the same patient
global MammoPdfDB_AutoShow := true


; ----------------------------------------------------------------------------
; Fire the DB updater asynchronously. Call once at YCH_mammo_Enh.ahk startup;
; the Task Scheduler logon entry calls update.bat directly, so duplicate fires
; on the same day are harmless (uv resolves quickly, skipped rows do no work).
; ----------------------------------------------------------------------------
MammoPdfDB_RefreshAsync() {
    global MammoPdfDB_UpdateBat
    if !FileExist(MammoPdfDB_UpdateBat) {
        OutputDebug % "[MammoPdfDB] update.bat not found: " MammoPdfDB_UpdateBat
        return
    }
    Run, %ComSpec% /C """%MammoPdfDB_UpdateBat%""",, Hide UseErrorLevel
    if (ErrorLevel)
        OutputDebug % "[MammoPdfDB] failed to spawn update.bat"
}


; ----------------------------------------------------------------------------
; Read the tail of update.log, locate the most recent "update: parsed=..." line,
; and return a small object summarising what changed in that run. Returns "" if
; the log is missing or no summary line is present yet.
;
;   { ts, parsed, changed, skipped, errored, removed, records, raw }
; ----------------------------------------------------------------------------
MammoPdfDB_ReadLastSummary() {
    global MammoPdfDB_UpdateBat
    logPath := RegExReplace(MammoPdfDB_UpdateBat, "[^\\]+$") "update.log"
    if !FileExist(logPath)
        return ""
    FileRead, content, %logPath%
    if (content = "")
        return ""
    todayTag := A_YYYY "/" A_MM "/" A_DD          ; matches "2026/05/13" inside header
    lastTs := "", lastSummary := "", lastRecords := 0
    curTsIsToday := false, blockRecords := 0
    Loop, parse, content, `n, `r
    {
        line := A_LoopField
        if RegExMatch(line, "^=+\s*(.+?)\s*=+$", m) {
            curTs := m1
            curTsIsToday := InStr(curTs, todayTag) > 0
            blockRecords := 0
            continue
        }
        if !curTsIsToday
            continue
        if RegExMatch(line, "records=(\d+)", m)
            blockRecords += m1
        if RegExMatch(line, "^update:\s*(.+?)\s*$", m) {
            lastSummary := m1, lastTs := curTs, lastRecords := blockRecords
        }
    }
    if (lastSummary = "")
        return ""
    out := { ts: lastTs, raw: lastSummary, records: lastRecords
           , parsed: 0, changed: 0, skipped: 0, errored: 0, removed: 0 }
    for _, key in ["parsed","changed","skipped","errored","removed"] {
        if RegExMatch(lastSummary, key "=(\d+)", m)
            out[key] := m1 + 0
    }
    return out
}


; ----------------------------------------------------------------------------
; Format the last summary into { body, ts } strings for caller-side display.
; The actual GUI lives in YCH_mammo_Enh.ahk so that g-labels do not terminate
; the auto-execute section here in this include.
; ----------------------------------------------------------------------------
MammoPdfDB_FormatLastSummary() {
    s := MammoPdfDB_ReadLastSummary()
    if !IsObject(s)
        return { body: "No parse run today (yet).", ts: "" }
    body := "New / parsed:  " s.parsed "`n"
          . "Changed:       " s.changed "`n"
          . "Skipped:       " s.skipped "`n"
          . "Errored:       " s.errored "`n"
          . "Removed:       " s.removed "`n"
          . "Records added: " s.records
    return { body: body, ts: s.ts }
}


; ----------------------------------------------------------------------------
; Public API
; ----------------------------------------------------------------------------

; criteria keys: nid, name, hosp, acc, serial, date, pdf  -- pass as object
;                e.g. {nid: "TEST_NID_001"} or {name: "MOCK_PATIENT", date: "115/04/22"}
; returns: AHK array of record objects (empty array if no match / error)
MammoPdfDB_Query(criteria) {
    global MammoPdfDB_PyPath, MammoPdfDB_DbPath

    if !FileExist(MammoPdfDB_PyPath) {
        OutputDebug % "[MammoPdfDB] python script not found: " MammoPdfDB_PyPath
        return []
    }

    args := "query --compact"
    if (MammoPdfDB_DbPath != "")
        args .= " --db """ MammoPdfDB_DbPath """"
    if (criteria.nid    != "")  args .= " --id """    criteria.nid    """"
    if (criteria.name   != "")  args .= " --name """  criteria.name   """"
    hosp := criteria.hosp ? criteria.hosp : criteria.acc
    if (hosp            != "")  args .= " --hosp """  hosp             """"
    if (criteria.serial != "")  args .= " --serial """ criteria.serial """"
    if (criteria.date   != "")  args .= " --date """  criteria.date   """"
    if (criteria.pdf    != "")  args .= " --pdf """   criteria.pdf    """"

    cmd := "uv run --quiet """ MammoPdfDB_PyPath """ " args
    json := MammoPdfDB_RunCapture(cmd)
    if (json = "")
        return []

    arr := Jxon_Load(json)
    return IsObject(arr) ? arr : []
}


; ----------------------------------------------------------------------------
; Internal: capture stdout from a console command without flashing a window
; ----------------------------------------------------------------------------
MammoPdfDB_RunCapture(cmd) {
    static shell := ComObjCreate("WScript.Shell")
    try {
        ; 0x0 = hidden, true = wait
        oExec := shell.Exec(ComSpec " /C chcp 65001 >nul && " cmd)
        out := oExec.StdOut.ReadAll()
        return out
    } catch e {
        OutputDebug % "[MammoPdfDB] Exec failed: " e.Message
        return ""
    }
}


; ----------------------------------------------------------------------------
; Fire-and-forget hook for RisStateChange callbacks.
;
; Drop this single line into RisStateChange (or any other study-change site):
;
;     MammoPdfDB_FireOnRisChange()
;
; Behavior:
;   - Returns immediately if CH_RIS isn't ready or the exam name doesn't
;     match a screening mammo exam name.
;   - Closes the previous lookup window when RIS shifts to a different patient.
;   - Debounces by patidno so rapid list-scroll events don't spawn duplicates.
;   - Spawns mammo_show.py asynchronously (Run, no Wait) so the AHK subscriber
;     thread is never blocked.
; ----------------------------------------------------------------------------
MammoPdfDB_FireOnRisChange() {
    global CH_RIS, MammoPdfDB_ShowPath, MammoPdfDB_LastNid, MammoPdfDB_AutoShow

    if !IsObject(CH_RIS)
        return

    examName := CH_RIS.examName
    nid := Trim("" CH_RIS.patidno)
    if (nid != "" && nid != MammoPdfDB_LastNid)
        MammoPdfDB_CloseLookupWindows()

    if (!MammoPdfDB_AutoShow) {
        if (nid != "")
            MammoPdfDB_LastNid := nid
        return
    }

    if !MammoPdfDB_IsMGExam(examName)
        return

    if (nid = "" || nid = MammoPdfDB_LastNid)
        return
    MammoPdfDB_LastNid := nid

    if !FileExist(MammoPdfDB_ShowPath) {
        OutputDebug % "[MammoPdfDB] mammo_show.py not found: " MammoPdfDB_ShowPath
        return
    }

    cmd := "uv run --quiet """ MammoPdfDB_ShowPath """ --id """ nid """"
    Run, %ComSpec% /C %cmd%,, Hide UseErrorLevel
    if (ErrorLevel)
        OutputDebug % "[MammoPdfDB] failed to spawn mammo_show.py for nid=" nid
}


MammoPdfDB_CloseLookupWindows() {
    WinClose, Mammo PDF lookup
}


; ----------------------------------------------------------------------------
; Auto-match: if the current CH_RIS study is any MG exam, look up by
; national ID (the IE page's hidden 'patidno' input, exposed via CH_RIS.patidno).
;
; Returns:
;   array of matching record objects, or empty array if exam doesn't match
;   the MG pattern / no patidno / no DB hit.
; ----------------------------------------------------------------------------
MammoPdfDB_AutoMatchByChRIS() {
    global CH_RIS
    if !IsObject(CH_RIS)
        return []
    examName := CH_RIS.examName
    nid      := Trim("" CH_RIS.patidno)
    if !MammoPdfDB_IsMGExam(examName)
        return []
    if (nid = "")
        return []
    return MammoPdfDB_Query({nid: nid})
}


; Matches any mammography exam in C hospital RIS (non-ultrasound). Covers screening,
; diagnostic, mobile-unit, and tomosynthesis studies.
MammoPdfDB_IsMGExam(examName) {
    return (examName ~= "Mammogra|乳房造影|乳篩|巡迴車")
        && !InStr(examName, "超音波")
        && !InStr(examName, "立體定位組織切片術")
}


; Narrow screening-only gate — preserved for reference.
;~ MammoPdfDB_IsScreeningExam(examName) {
;~     return InStr(examName, "乳篩-乳房篩檢造影")
;~         || InStr(examName, "巡迴車-乳房篩檢造影")
;~ }


; ----------------------------------------------------------------------------
; Open the source PDF in Edge at a specific page (for fields flagged
; needs_visual when checked — radiologist reads handwritten companion text).
;
;   MammoPdfDB_OpenAtPage(rec.pdf_path, rec.form_page)
;
; Edge supports the #page=N anchor, so the file opens directly at the form.
; ----------------------------------------------------------------------------
MammoPdfDB_OpenAtPage(pdfPath, page := 1) {
    if (pdfPath = "")
        return
    uri := "file:///" StrReplace(pdfPath, "\", "/")
    Run, % "msedge """ uri "#page=" page """",, UseErrorLevel, edgePid
    if (ErrorLevel) {
        ; fallback to default PDF handler (no page anchor)
        Run, % pdfPath
    }
}


; ----------------------------------------------------------------------------
; Convenience: format a single record for tooltip / OSD display
; ----------------------------------------------------------------------------
MammoPdfDB_FormatRecord(r) {
    s := ""
    s .= (r.name        ? "Name:   " r.name "`n"            : "")
    s .= (r.national_id ? "ID:     " r.national_id "`n"     : "")
    s .= (r.birth_iso   ? "Birth:  " r.birth_iso "`n"       : "")
    s .= (r.exam_iso    ? "Exam:   " r.exam_iso "`n"        : "")
    s .= (r.hospital_code  ? "Code:   " r.hospital_code "`n" : "")
    s .= (r.hospital_name  ? "Hosp:   " r.hospital_name "`n" : "")
    s .= (r.address     ? "Addr:   " r.address "`n"         : "")
    s .= (r.phone_mobile ? "Mobile: " r.phone_mobile "`n"   : "")
    s .= (r.phone_home   ? "Home:   " r.phone_home "`n"     : "")
    s .= (r.height_cm   ? "H/W:    " r.height_cm "cm / " r.weight_kg "kg`n" : "")
    s .= (r.serial      ? "Serial: " r.serial "`n"          : "")
    s .= (r.pdf_path    ? "PDF:    " r.pdf_path " p" r.form_page "`n" : "")
    return s
}
