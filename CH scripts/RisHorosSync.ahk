; RisHorosSync.ahk
#Requires AutoHotkey v1.1

; Subscribes to CH_RIS accession changes and POSTs to the Horos sync server on Mac.
; autorun.ahk keeps this standalone tray bridge alive for the whole RIS session.
;
; JSON payload sent to server:
; {
;   "accNo": "T0000000001",
;   "chartNo": "0000000001",
;   "studyDate": "20230901",
;   "patname": "Patient Name",
;   "examname": "BRAIN CT (無造影劑)",
;   "examtime": "2023-09-01 15:15:03.0",
;   "mccid": "54"
; }
; Note: Only sends to MacBook if mccid is 54 (CT) or 55 (MR)
;
; Hotkeys:
;   Ctrl+Alt+S  - Toggle Debug Mode (Tooltip follows mouse)
;   Ctrl+Alt+R  - Re-send current study info to MacBook
;   Ctrl+Alt+Q  - Terminate script and kill MacBook start.sh process
;
; CH_RIS_GUI Edit control layout (from CH_RIS_REPORT.create_gui):
;   Edit1  exam_edit
;   Edit2  impression_edit
;   Edit3  patname_edit_auto
;   Edit4  accno_edit_auto     <-- primary watch
;   Edit5  gender_edit_auto
;   Edit6  age_edit_auto
;   Edit7  examname_edit_auto
;   Edit8  examtime_edit_auto
;   Edit9  patidno_edit_auto
;   ...

#NoEnv
#SingleInstance, Force
#Persistent
#Include %A_ScriptDir%\..\Lib\IsCurrentSessionRDP.ahk
#Include %A_ScriptDir%\..\Lib\LogRetention.ahk
SetBatchLines, -1
DetectHiddenWindows, On
ComObjError(0)   ; suppress COM error dialogs (replaces CH_RIS top-level setting)

; Route RIS reads through the single CH_RIS owner (autorun) over IPC instead of creating
; our own IE-polling owner. Include the client here in the auto-exec section so its transport
; globals (CH_RIS_DW / CH_RIS_SERVER_TITLE) initialise at startup; <CH_RIS> below (after
; return) only supplies the class def for the no-owner fallback. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <CH_RIS_Client>

; ── Config ────────────────────────────────────────────────────────────────────
InitSyncConfig()
DebugLogSession("RisHorosSync.ahk")
RegisterSessionNotifications()
g_wasRdp := IsCurrentSessionRDPConnected()
SetTimer, SessionModeWatch, 2000

; Shift held at startup: skip the currently-loaded study on first poll so Horos
; does not auto-navigate when RisHorosSync is launched mid-reporting session.
if GetKeyState("Shift", "P") {
    g_skipNextSync := true
    if IsCurrentSessionRDPConnected()   ; local sessions never sync — stay silent
        TrayTip, RIS→Horos Sync, Not sync current study, 3, 1
}

; ── Tray ──────────────────────────────────────────────────────────────────────
Menu, Tray, NoStandard
Menu, Tray, Add, % syncLabel(),          ToggleSync
Menu, Tray, Add, Debug Mode (^!s),       ToggleDebug
Menu, Tray, Add, Re-send (^!r),          ManualResend
Menu, Tray, Add                          ; separator
Menu, Tray, Add, Exit (^!q),             DoExit
Menu, Tray, Default, % syncLabel()
Menu, Tray, Tip,   RIS→Horos Sync

ShowStartupStatus()
if (g_wasRdp)
    StartRdpSyncRuntime()
return

; #include after return so CH_RIS hotkey labels don't cut off auto-execute section
#include <CH_RIS>

InitSyncConfig() {
    global g_syncConfig, g_syncUrl, POLL_INTERVAL, SYNC_ENABLED, g_lastAccNo, g_debugMode
    global g_lastSendStatus, g_lastSendResponse, g_lastSendError
    global g_lastInfoSource, g_lastInfoError, g_logFile
    global g_pollBusy, g_debugBusy, g_sendBusy, g_verboseLog
    global g_syncHost, g_syncHealthUrl, g_syncRestartUrl, g_preflightCacheMs, g_lastPreflightTick, g_lastPreflightOk
    global g_lastMccid, g_lastRisStatus, g_haveStateSnapshot
    global g_macReconnecting, g_macReconnectTries
    global g_syncAfterReconnect, g_accNoHookRegistered
    global g_wtsNotificationRegistered, g_wasRdp, g_lastRdpArrivalTick, g_rdpArrivalPending
    global REPORTED_PROMPT_TITLE, g_reportedPromptAccNo, g_reportedPromptNewAccNo

    g_syncUrl := "http://192.0.2.10:7788/update"
    g_syncHost := "192.0.2.10"
    g_syncHealthUrl := "http://192.0.2.10:7788/health"
    g_syncRestartUrl := "http://192.0.2.10:7788/restart"
    g_syncConfig := {}
    g_syncConfig.url := g_syncUrl
    POLL_INTERVAL := 10000  ; recovery watchdog; accNo events are the primary trigger
    SYNC_ENABLED := true
    g_lastAccNo := ""
    g_debugMode := false
    g_lastSendStatus := ""
    g_lastSendResponse := ""
    g_lastSendError := ""
    g_lastInfoSource := ""
    g_lastInfoError := ""
    FormatTime, logDate,, yyyyMMdd
    LogRetention_DeleteFilesOlderThan(A_Temp, "RisHorosSync_*.log")
    LogRetention_DeleteFilesOlderThan(A_Temp, "RisHorosSync.log")
    g_logFile := A_Temp "\RisHorosSync_" logDate ".log"
    g_pollBusy := false
    g_debugBusy := false
    g_sendBusy := false
    g_verboseLog := true   ; set false to silence step-level logs
    g_skipNextSync := false  ; set true to skip one accNo change (Shift-at-startup or flag file)
    g_preflightCacheMs := 5000
    g_lastPreflightTick := 0
    g_lastPreflightOk := false
    g_lastMccid := ""
    g_lastRisStatus := ""
    g_haveStateSnapshot := false
    g_macReconnecting := false
    g_macReconnectTries := 0
    g_syncAfterReconnect := false
    g_accNoHookRegistered := false
    g_wtsNotificationRegistered := false
    g_wasRdp := false
    g_lastRdpArrivalTick := 0
    g_rdpArrivalPending := false
    REPORTED_PROMPT_TITLE := "RIS to Horos Sync"
    g_reportedPromptAccNo := ""
    g_reportedPromptNewAccNo := ""
}

RegisterSessionNotifications() {
    global g_wtsNotificationRegistered

    ; WM_WTSSESSION_CHANGE is delivered only after explicit registration.
    OnMessage(0x02B1, "RisHoros_WTSSessionChange")
    g_wtsNotificationRegistered := DllCall("Wtsapi32.dll\WTSRegisterSessionNotification"
        , "Ptr", A_ScriptHwnd
        , "UInt", 0)   ; NOTIFY_FOR_THIS_SESSION
    if (g_wtsNotificationRegistered)
        LogV("RDP session-change notification registered")
    else
        LogSync("RDP session-change registration failed A_LastError=" A_LastError "; watchdog remains active")
    OnExit, RisHoros_OnExit
}

UnregisterSessionNotifications() {
    global g_wtsNotificationRegistered
    if !g_wtsNotificationRegistered
        return
    DllCall("Wtsapi32.dll\WTSUnRegisterSessionNotification", "Ptr", A_ScriptHwnd)
    g_wtsNotificationRegistered := false
}

RisHoros_WTSSessionChange(wParam, lParam, msg, hwnd) {
    global g_wasRdp, g_rdpArrivalPending, g_lastRdpArrivalTick

    ; Remote connect / logon / unlock can precede the live protocol becoming RDP.
    ; Keep the arrival pending until the watchdog observes a connected session.
    if (wParam = 0x3 || wParam = 0x5 || wParam = 0x8) {
        g_rdpArrivalPending := true
        LogSync("RDP arrival notification event=" wParam " sessionId=" lParam)
        SetTimer, HandleRdpArrival, -750
    } else if (wParam = 0x1 || wParam = 0x4) {
        ; WTS_CONSOLE_CONNECT / WTS_REMOTE_DISCONNECT
        g_wasRdp := false
        g_rdpArrivalPending := false
        g_lastRdpArrivalTick := 0
        SetTimer, HandleRdpArrival, Off
    }
}

StartRdpSyncRuntime(queueInitialPoll := true) {
    global CH_RIS, POLL_INTERVAL, g_accNoHookRegistered, __CH_RIS_CLIENT, __CH_RIS_CLIENT_AccNoMsg

    EnsureCHRIS(false, true)
    if (IsObject(CH_RIS) && !g_accNoHookRegistered) {
        CH_RIS.addAccNoChangedHookFn(Func("RisHoros_AccNoChanged"))
        g_accNoHookRegistered := true
        LogSync("AccNo subscription registered with CH_RIS owner")
    } else if (__CH_RIS_CLIENT && IsObject(CH_RIS)) {
        ; Renew the owner's subscription without duplicating our local callback.
        ; The owner may have restarted or been unavailable at the first attempt.
        CH_RIS_Call("sub_accno", {hwnd: A_ScriptHwnd, msg: __CH_RIS_CLIENT_AccNoMsg}, false)
    }
    SetTimer, PollRIS, % POLL_INTERVAL
    SetTimer, MacHealthCheck, 30000
    if (queueInitialPoll)
        SetTimer, PollRIS_Event, -1
}

HandleRdpArrivalNow(source) {
    global SYNC_ENABLED, g_lastAccNo, g_syncAfterReconnect, g_lastRdpArrivalTick
    global g_wasRdp, g_rdpArrivalPending

    if !IsCurrentSessionRDPConnected() {
        LogV("RDP arrival waiting for connected session source=" source)
        return
    }
    g_wasRdp := true
    g_rdpArrivalPending := false
    if (g_lastRdpArrivalTick && A_TickCount - g_lastRdpArrivalTick < 5000)
        return
    g_lastRdpArrivalTick := A_TickCount

    LogSync("RDP arrival detected source=" source "; enabling sync runtime")
    StartRdpSyncRuntime(false)
    g_lastAccNo := ""   ; force the current RIS study to be evaluated again
    if !SYNC_ENABLED {
        LogSync("RDP arrival: Horos sync is disabled")
        return
    }

    g_syncAfterReconnect := true
    if IsMacBookReachable(true) {
        g_syncAfterReconnect := false
        LogSync("RDP arrival: Mac server reachable; syncing current study")
        SetTimer, PollRIS_Event, -1
    } else {
        LogSync("RDP arrival: Mac server unavailable; reconnecting before current-study sync")
        TrayTip, RIS→Horos Sync, RDP connected - reconnecting MacBook..., 5, 2
        TriggerMacReconnect(true)
    }
}

LogV(msg) {
    global g_verboseLog
    if g_verboseLog
        LogSync(msg)
}

RisHoros_AccNoChanged() {
    global SYNC_ENABLED
    LogV("AccNo event received from CH_RIS owner")
    if SYNC_ENABLED
        SetTimer, PollRIS_Event, -1
}

EnsureCHRIS(forceRefresh := false, skipUpdateWb := false) {
    global CH_RIS, g_lastInfoError, __CH_RIS_CLIENT
    g_lastInfoError := ""

    if !IsObject(CH_RIS) {
        ; Client mode: a lightweight proxy that forwards to the autorun owner over IPC.
        ; Created dynamically (IsFunc-guarded, %fn%()) per the AHK v1 load-time rule.
        if (__CH_RIS_CLIENT && IsFunc(__mkProxy := "CH_RIS_Client_MakeProxy")) {
            CH_RIS := %__mkProxy%()
            LogV("EnsureCHRIS: client proxy created (owner = autorun)")
        } else {
            LogV("EnsureCHRIS: new CH_RIS_REPORT ...")
            t0 := A_TickCount
            try CH_RIS := new CH_RIS_REPORT()
            catch e {
                g_lastInfoError := "CH_RIS init failed: " e.Message
                LogSync("EnsureCHRIS: init FAILED " g_lastInfoError)
                return false
            }
            LogV("EnsureCHRIS: init OK (" A_TickCount-t0 "ms)")
        }
    }

    if IsObject(CH_RIS) {
        if !skipUpdateWb {
            ; Guard: skip update_wb if IE is navigating — accessing the document
            ; of a loading page blocks the COM thread indefinitely.
            ; Default to skip (ieReady=false) so a stale/erroring wb never reaches update_wb.
            ieReady := false
            try {
                rs := CH_RIS.wb.ReadyState   ; 4 = READYSTATE_COMPLETE; safe on host object
                ieReady := (rs = 4)
                if !ieReady
                    LogV("EnsureCHRIS: IE navigating (ReadyState=" rs "), skipping update_wb")
            } catch {
                LogV("EnsureCHRIS: wb.ReadyState threw (stale wb), skipping update_wb")
            }
            if ieReady {
                LogV("EnsureCHRIS: update_wb ...")
                t0 := A_TickCount
                try CH_RIS.update_wb()
                catch e
                    g_lastInfoError := "update_wb failed: " e.Message
                LogV("EnsureCHRIS: update_wb done (" A_TickCount-t0 "ms)" (g_lastInfoError ? " err=" g_lastInfoError : ""))
            }
        }

        ; Client snapshot callers already read the complete owner state in one IPC below.
        ; Avoid a separate accNo property IPC (and unnecessary refresh) on that path.
        if (forceRefresh || (!(__CH_RIS_CLIENT && skipUpdateWb) && Trim("" CH_RIS.accNo) = "")) {
            LogV("EnsureCHRIS: refresh_info ...")
            t0 := A_TickCount
            try CH_RIS.refresh_info()
            catch e1 {
                LogV("EnsureCHRIS: refresh_info failed (" A_TickCount-t0 "ms) -> get_fields ...")
                t0 := A_TickCount
                try CH_RIS.get_fields()
                catch e2 {
                    g_lastInfoError := "refresh/get_fields failed: " e2.Message
                    LogSync("EnsureCHRIS: get_fields FAILED (" A_TickCount-t0 "ms) " g_lastInfoError)
                }
                LogV("EnsureCHRIS: get_fields done (" A_TickCount-t0 "ms)")
            }
            LogV("EnsureCHRIS: refresh done (" A_TickCount-t0 "ms)")
        }
    }

    return IsObject(CH_RIS)
}

; ── Hotkeys ───────────────────────────────────────────────────────────────────
^!s:: ; Ctrl+Alt+S: Toggle Debug Mode
ToggleDebug:
    g_debugMode := !g_debugMode
    if (g_debugMode) {
        SetTimer, DebugTip, 1000
        ToolTip, [RisHorosSync] Debug Mode: ON
        SetTimer, ClearTip, -1500
    } else {
        SetTimer, DebugTip, Off
        ToolTip, , , , 2 ; Clear debug tooltip
        ToolTip, [RisHorosSync] Debug Mode: OFF
        SetTimer, ClearTip, -1500
    }
return

^!r:: ; Ctrl+Alt+R: Re-send current study
ManualResend:
    global g_sendBusy
    if (g_sendBusy)
        return
    EnsureCHRIS(true)
    GetCurrentStudyInfo(accNo, chartNo, studyDate, patname, examname, examtime, mccid)
    if (accNo != "") {
        LogSync("Manual resend accNo=" accNo " mccid=" mccid " src=" g_lastInfoSource)
        PostToMac(accNo, chartNo, studyDate, patname, examname, examtime, mccid)
        ToolTip, [RisHorosSync] Re-sent: %accNo%
        SetTimer, ClearTip, -1500
    } else {
        LogSync("Manual resend skipped (no accNo), src=" g_lastInfoSource ", err=" g_lastInfoError)
        ToolTip, % "[RisHorosSync] No Accession Number found`nSrc: " g_lastInfoSource "`nErr: " g_lastInfoError
        SetTimer, ClearTip, -1500
    }
return

^!q:: ; Ctrl+Alt+Q: Terminate (the Mac server stays up; launchd owns it)
    ToolTip, [RisHorosSync] Terminating...
    Sleep, 1000
ExitApp
return

; ── Poll ──────────────────────────────────────────────────────────────────────
PollRIS_Event:
    LogV("PollRIS: event-triggered")
    Gosub, PollRIS
return

HandleRdpArrival:
    HandleRdpArrivalNow("WM_WTSSESSION_CHANGE")
return

SessionModeWatch:
    isRdpNow := IsCurrentSessionRDPConnected()
    if (isRdpNow && (!g_wasRdp || g_rdpArrivalPending)) {
        HandleRdpArrivalNow("watchdog")
    } else if (!isRdpNow && g_wasRdp) {
        g_wasRdp := false
        g_lastRdpArrivalTick := 0
        LogV("RDP client disconnected or session changed to local")
    }
return

; A native MsgBox leaves the originating poll busy. Retry only after that poll has
; unwound, otherwise the active-study change would be discarded by the busy guard.
RecheckActiveStudyAfterReportedPrompt:
    if (g_pollBusy || g_sendBusy) {
        SetTimer, RecheckActiveStudyAfterReportedPrompt, -50
        return
    }
    LogV("Reported-study prompt closed: evaluating active study")
    Gosub, PollRIS
return

PollRIS:
    global g_pollBusy, g_sendBusy
    if !SYNC_ENABLED
        return
    if (g_pollBusy || g_sendBusy)
        return
    ; Skip polling entirely in local session—sync never happens anyway
    if !IsCurrentSessionRDPConnected()
        return

    g_pollBusy := true
    pollT0 := A_TickCount
    LogV("PollRIS: start")

    EnsureCHRIS(false, __CH_RIS_CLIENT)
    LogV("PollRIS: after EnsureCHRIS (" A_TickCount-pollT0 "ms)")

    GetCurrentStudyInfo(accNo, chartNo, studyDate, patname, examname, examtime, mccid)
    LogV("PollRIS: after GetCurrentStudyInfo (" A_TickCount-pollT0 "ms) accNo=" accNo " mccid=" mccid " src=" g_lastInfoSource)

    if (accNo = "" || accNo = g_lastAccNo) {
        g_pollBusy := false
        return
    }

    ; Check for skip-next flag written by ArmSendRptIEBlock (report sent with Shift)
    if (!g_skipNextSync && FileExist(A_Temp "\RisHorosSyncSkip.flag")) {
        FileDelete, % A_Temp "\RisHorosSyncSkip.flag"
        g_skipNextSync := true
    }
    if (g_skipNextSync) {
        g_skipNextSync := false
        g_lastAccNo := accNo
        LogSync("Poll skip-next: suppressed sync for accNo=" accNo)
        TrayTip, RIS→Horos Sync, Not sync next study, 3, 1
        g_pollBusy := false
        return
    }

    ; Check if Shift is held when study changes
    if GetKeyState("Shift", "P") {
        g_lastAccNo := accNo
        LogSync("Poll shift-pressed: suppressed sync for accNo=" accNo)
        TrayTip, RIS→Horos Sync, Shift suppressed sync, 3, 1
        g_pollBusy := false
        return
    }

    ; FIX: Mark the study as processed immediately so the script doesn't
    ; get stuck in an infinite polling loop on unsupported modalities/offline states.
    g_lastAccNo := accNo

    if !ShouldSendToMac() {
        LogV("Poll suppressed accNo=" accNo " src=" g_lastInfoSource)
        g_pollBusy := false
        return
    }

    LogSync("Poll trigger accNo=" accNo " mccid=" mccid " src=" g_lastInfoSource " elapsed=" A_TickCount-pollT0 "ms")
    PostToMac(accNo, chartNo, studyDate, patname, examname, examtime, mccid)
    LogV("PollRIS: after PostToMac total=" A_TickCount-pollT0 "ms")
    g_pollBusy := false
return

; ── Debug Tooltip ─────────────────────────────────────────────────────────────
DebugTip:
    global g_lastSendStatus, g_lastSendResponse, g_lastSendError, g_lastInfoSource, g_lastInfoError, g_debugBusy, g_debugMode
    if (g_debugBusy)
        return
    if !g_debugMode {        ; debug toggled off while timer was queued
        ToolTip, , , , 2
        return
    }
    g_debugBusy := true
    if !g_debugMode {        ; debug toggled off between busy-check and here
        ToolTip, , , , 2
        g_debugBusy := false
        return
    }
    if !EnsureCHRIS(true) {
        ToolTip, % "[RisHorosSync] CH_RIS not ready`nInfoErr: " g_lastInfoError, , , 2
        g_debugBusy := false
        return
    }
    GetCurrentStudyInfo(dbgAccNo, dbgChartNo, dbgStudyDate, dbgPatName, dbgExamName, dbgExamTime, dbgMccid)
    dbgPatID := ""
    if IsObject(CH_RIS) {
        try dbgPatID := Trim("" CH_RIS.patidno)
        if (dbgPatID = "")
            try dbgPatID := Trim("" CH_RIS.patientID)
    }

    ; Mouse position logic (follows mouse)
    MouseGetPos, mX, mY
    dbgResponse := g_lastSendResponse
    StringReplace, dbgResponse, dbgResponse, `r`n, |, All
    if (StrLen(dbgResponse) > 120)
        dbgResponse := SubStr(dbgResponse, 1, 120) "..."
    ToolTip, % "[RisHorosSync] Mode: DEBUG"
        . "`nAccNo: " dbgAccNo
        . "`nChartNo: " dbgChartNo
        . "`nStudyDate: " dbgStudyDate
        . "`nPatName: " dbgPatName
        . "`nPatID: " dbgPatID
        . "`nExam: " dbgExamName
        . "`nMccid: " dbgMccid
        . "`nExamTime: " dbgExamTime
        . "`nInfoSrc: " g_lastInfoSource
        . "`nInfoErr: " g_lastInfoError
        . "`nLastSynced: " g_lastAccNo
        . "`nLastHTTP: " g_lastSendStatus
        . "`nLastResp: " dbgResponse
        . "`nLastErr: " g_lastSendError
        , mX + 20, mY + 20, 2
    g_debugBusy := false
return

; ── HTTP POST ─────────────────────────────────────────────────────────────────
PostToMac(accNo, chartNo, studyDate, patname, examname, examtime, mccid := "") {
    global g_syncConfig, g_syncUrl, g_debugMode, g_lastSendStatus, g_lastSendResponse, g_lastSendError, SYNC_ENABLED, g_sendBusy
    url := Trim("" g_syncUrl)
    if (url = "" && IsObject(g_syncConfig))
        url := Trim("" g_syncConfig.url)
    if (url = "")
        throw Exception("Sync URL is empty before POST. Config initialization failed or value was overwritten.", -1)
    if !ShouldSendToMac()
        return false
    if !ConfirmReportedStudyOpen(accNo, patname, examname)
        return false
    if (g_sendBusy)
        return false
    g_sendBusy := true
    ; Escape double-quotes inside values (basic safety)
    StringReplace, accNo,    accNo,    `", \"
    StringReplace, chartNo,  chartNo,  `", \"
    StringReplace, studyDate, studyDate, `", \"
    StringReplace, patname,  patname,  `", \"
    StringReplace, examname, examname, `", \"
    StringReplace, examtime, examtime, `", \"

    json := "{""accNo"":""" accNo """,""chartNo"":""" chartNo """,""studyDate"":""" studyDate """,""patname"":""" patname """,""examname"":""" examname """,""examtime"":""" examtime """,""mccid"":""" mccid """}"
    
    Loop {
        g_lastSendStatus := "SENDING"
        g_lastSendResponse := ""
        g_lastSendError := ""
        LogSync("POST -> url=" url " accNo=" accNo " chartNo=" chartNo " studyDate=" studyDate)
        try {
            http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
            http.Open("POST", url, false)  ; sync — async destroys object before send completes
            http.SetRequestHeader("Content-Type", "application/json")
            http.SetTimeouts(5000, 5000, 5000, 5000)   ; resolve/connect/send/receive ms
            try {
                http.Send(json)
            } catch eSend {
                throw Exception("Send() failed`n" DescribeException(eSend), -1)
            }

            try {
                g_lastSendStatus := http.Status " " http.StatusText
            } catch eStatus {
                g_lastSendStatus := "STATUS_READ_FAILED"
                g_lastSendError := "Status read failed`n" DescribeException(eStatus)
                LogSync("POST WARN " g_lastSendError)
            }

            try {
                g_lastSendResponse := http.ResponseText
            } catch eResp {
                if (g_lastSendError != "")
                    g_lastSendError .= "`n---`n"
                g_lastSendError .= "Response read failed`n" DescribeException(eResp)
                LogSync("POST WARN " g_lastSendError)
            }
            LogSync("POST OK " g_lastSendStatus " resp=" SubStr(g_lastSendResponse, 1, 200))
            if (g_debugMode) {
                MouseGetPos, mX, mY
                dbgResponse := g_lastSendResponse
                StringReplace, dbgResponse, dbgResponse, `r`n, |, All
                if (StrLen(dbgResponse) > 120)
                    dbgResponse := SubStr(dbgResponse, 1, 120) "..."
                ToolTip, % "[RisHorosSync] POST OK"
                    . "`nHTTP: " g_lastSendStatus
                    . "`nResp: " dbgResponse
                    . (g_lastSendError != "" ? "`nWarn: " SubStr(g_lastSendError, 1, 120) : "")
                    , mX + 20, mY + 20, 2
            }
            g_sendBusy := false
            return true ; Success
        } catch e {
            g_lastSendError := DescribeException(e)
            LogSync("POST FAILED err=" g_lastSendError)
            if (g_debugMode) {
                MouseGetPos, mX, mY
                ToolTip, % "[RisHorosSync] POST FAILED`nErr: " SubStr(g_lastSendError, 1, 220), mX + 20, mY + 20, 2
            }
            g_sendBusy := false
            return false
        }
    }
}

ShouldSendToMac() {
    global g_lastSendStatus, g_lastSendResponse, g_lastSendError, g_lastMccid

    if !IsCurrentSessionRDPConnected() {
        g_lastSendStatus := "SKIPPED_LOCAL_SESSION"
        g_lastSendResponse := ""
        g_lastSendError := ""
        LogV("POST skipped: current login session is local, not RDP")
        return false
    }

    if !IsMacBookReachable() {
        g_lastSendStatus := "SKIPPED_MAC_OFFLINE"
        g_lastSendResponse := ""
        g_lastSendError := ""
        LogV("POST skipped: MacBook not reachable")
        TriggerMacReconnect(true)
        return false
    }

    ; Only send if modality is CT (54) or MR (55)
    if (g_lastMccid != "54" && g_lastMccid != "55") {
        g_lastSendStatus := "SKIPPED_MODALITY"
        g_lastSendResponse := ""
        g_lastSendError := ""
        LogV("POST skipped: modality mccid=" g_lastMccid " is not CT(54) or MR(55)")
        return false
    }

    return true
}

ConfirmReportedStudyOpen(accNo, patname := "", examname := "") {
    global g_lastSendStatus, g_lastSendResponse, g_lastSendError
    global REPORTED_PROMPT_TITLE, g_reportedPromptAccNo, g_reportedPromptNewAccNo
    if !IsCurrentRisStudyReported()
        return true

    msg := "This RIS study is already reported (status=2).`n`n"
        . "AccNo: " accNo "`n"
        . (patname != "" ? "Patient: " patname "`n" : "")
        . (examname != "" ? "Exam: " examname "`n" : "")
        . "`nOpen this study on the MacBook side (Horos)?"
    g_reportedPromptAccNo := accNo
    g_reportedPromptNewAccNo := ""
    SetTimer, MonitorReportedStudyPrompt, 500
    MsgBox, 292, % REPORTED_PROMPT_TITLE, % msg
    SetTimer, MonitorReportedStudyPrompt, Off

    newAccNo := g_reportedPromptNewAccNo
    if (newAccNo = "") {
        activeAccNo := GetActiveStudyAccNoForReportedPrompt()
        if (activeAccNo != "" && activeAccNo != accNo)
            newAccNo := activeAccNo
    }
    g_reportedPromptAccNo := ""
    g_reportedPromptNewAccNo := ""
    if (newAccNo != "") {
        g_lastSendStatus := "SKIPPED_REPORTED_STUDY_CHANGED"
        g_lastSendResponse := ""
        g_lastSendError := ""
        LogSync("POST cancelled: active study changed while reported-study prompt was open oldAccNo=" accNo " newAccNo=" newAccNo)
        SetTimer, RecheckActiveStudyAfterReportedPrompt, -50
        return false
    }

    IfMsgBox, Yes
        return true

    g_lastSendStatus := "SKIPPED_REPORTED_USER_NO"
    g_lastSendResponse := ""
    g_lastSendError := ""
    LogSync("POST skipped: reported study status=2 user chose No accNo=" accNo)
    return false
}

MonitorReportedStudyPrompt:
    if (g_reportedPromptAccNo = "") {
        SetTimer, MonitorReportedStudyPrompt, Off
        return
    }

    activeAccNo := GetActiveStudyAccNoForReportedPrompt()
    if (activeAccNo = "" || activeAccNo = g_reportedPromptAccNo)
        return

    g_reportedPromptNewAccNo := activeAccNo
    LogSync("Reported-study prompt: study changed oldAccNo=" g_reportedPromptAccNo " newAccNo=" activeAccNo "; closing prompt")
    promptWinSpec := REPORTED_PROMPT_TITLE " ahk_class #32770 ahk_pid " DllCall("GetCurrentProcessId")
    if (promptHwnd := WinExist(promptWinSpec))
        ControlClick, Button2, ahk_id %promptHwnd%
return

GetActiveStudyAccNoForReportedPrompt() {
    global __CH_RIS_CLIENT, CH_RIS

    ; Fetch a new owner snapshot. Reusing g_lastAccNo or the prior state snapshot
    ; would leave the blocking prompt unaware of a study change.
    if (__CH_RIS_CLIENT && IsFunc("CH_GetState")) {
        try {
            state := CH_GetState()
            if IsObject(state) {
                accNo := Trim("" state.accNo)
                if (accNo != "")
                    return accNo
            }
        }
    }

    if WinExist("CH_RIS_GUI ahk_class AutoHotkeyGUI") {
        ControlGetText, accNo, Edit4, CH_RIS_GUI ahk_class AutoHotkeyGUI
        accNo := Trim(accNo)
        if (accNo != "")
            return accNo
    }

    if IsObject(CH_RIS) {
        try return Trim("" CH_RIS.accNo)
    }
    return ""
}

IsCurrentRisStudyReported() {
    status := GetCurrentRisStudyStatus()
    return (status = "2")
}

GetCurrentRisStudyStatus() {
    global CH_RIS, __CH_RIS_CLIENT, g_lastRisStatus, g_haveStateSnapshot
    if (__CH_RIS_CLIENT && g_haveStateSnapshot)
        return g_lastRisStatus

    status := ""
    if IsObject(CH_RIS) {
        try {
            if (CH_RIS.wb.ReadyState = 4)
                CH_RIS.get_fields()
        }
        try status := Trim("" CH_RIS.status)
        if (status != "")
            return status

        if (__CH_RIS_CLIENT) {
            ; No cross-process DOM; force an owner refresh and re-read the snapshot status
            ; (the IPC equivalent of the owner-mode input[name=status] DOM scan below).
            try CH_RIS.refresh_info()
            try status := Trim("" CH_RIS.status)
            return status
        }

        try inputs := CH_RIS.wb.document.getElementsByTagName("input")
        catch
            return ""
        Loop % inputs.length {
            input := inputs[A_Index-1]
            try name := input.name
            catch
                name := ""
            if (name = "status") {
                try return Trim("" input.value)
            }
        }
    }
    return status
}

IsMacBookReachable(forceCheck := false) {
    global g_syncHealthUrl, g_preflightCacheMs, g_lastPreflightTick, g_lastPreflightOk

    if (!forceCheck && g_lastPreflightTick && (A_TickCount - g_lastPreflightTick < g_preflightCacheMs))
        return g_lastPreflightOk

    g_lastPreflightTick := A_TickCount
    g_lastPreflightOk := false

    try {
        http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", g_syncHealthUrl, false)
        http.SetTimeouts(1000, 1000, 1000, 1000)   ; resolve/connect/send/receive ms
        http.Send()
        status := 0
        try status := http.Status
        if (status >= 200 && status < 300) {
            g_lastPreflightOk := true
            LogV("Mac preflight OK status=" status)
        } else {
            LogV("Mac preflight: Send() returned but status invalid (status=" status "), treating as unreachable")
        }
    } catch e {
        LogV("Mac preflight failed: " DescribeException(e))
    }

    return g_lastPreflightOk
}

ShowStartupStatus() {
    isRDP := IsCurrentSessionRDPConnected()
    sessionLabel := isRDP ? "RDP session" : "Local session"

    if (isRDP) {
        macOk := IsMacBookReachable(true)
        if (!macOk) {
            TrayTip, RIS→Horos Sync, Restarting MacBook server..., 10, 1
            RestartMacServer()
            loop, 15 {
                Sleep, 1000
                macOk := IsMacBookReachable(true)
                if (macOk)
                    break
            }
        }
        macLabel := macOk ? "MacBook connected" : "MacBook not reachable"
        icon := macOk ? 1 : 2
    } else {
        macLabel := "Sync disabled (local)"
        icon := 1
    }

    LogSync("Startup status: session=" sessionLabel " status=" macLabel)
    ; Local session: sync is disabled, so don't pop a tray notification — just log.
    if (isRDP)
        TrayTip, RIS→Horos Sync, % "Session: " sessionLabel "`nStatus: " macLabel, 4, %icon%
}

RestartMacServer() {
    LogSync("RestartMacServer: POST /restart")
    ; The old server still answers for ~0.5 s after it accepts the request;
    ; wait so the caller's first /health poll reaches the new server.
    if (PostMacRestart())
        Sleep, 2000
    LogSync("RestartMacServer: done")
}

TriggerMacReconnect(syncAfterReconnect := false) {
    global g_macReconnecting, g_macReconnectTries, g_syncAfterReconnect
    if (syncAfterReconnect)
        g_syncAfterReconnect := true
    if (g_macReconnecting)
        return
    g_macReconnecting := true
    g_macReconnectTries := 0
    LogSync("TriggerMacReconnect: POST /restart async")
    PostMacRestart(true)
    ; First /health poll is 2 s after the request (see RestartMacServer).
    SetTimer, CheckMacReconnected, 2000
}

; Ask the Mac server to exit; launchd (KeepAlive) starts it again.
; A server that does not answer cannot receive this — the Mac-side watchdog
; repairs that case, so errors are ignored and callers just poll /health.
; async: do not wait for the reply (a dead server costs ~4 s of WinHTTP connect
; retries). The request object stays in a global so it outlives this call.
PostMacRestart(async := false) {
    global g_syncRestartUrl, g_macRestartHttp
    try {
        http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", g_syncRestartUrl, async ? true : false)
        http.SetTimeouts(1000, 1000, 1000, 1000)   ; resolve/connect/send/receive ms
        http.Send()
        if (async) {
            g_macRestartHttp := http
            return true
        }
        status := 0
        try status := http.Status
        LogV("Mac restart request status=" status)
        return (status >= 200 && status < 300)
    } catch e {
        LogV("Mac restart request failed: " DescribeException(e))
    }
    return false
}

; ── Mac Reconnect ─────────────────────────────────────────────────────────────
MacHealthCheck:
    global g_macReconnecting, SYNC_ENABLED
    if (!SYNC_ENABLED || !IsCurrentSessionRDPConnected() || g_macReconnecting)
        return
    if !IsMacBookReachable(true) {
        LogSync("MacHealthCheck: server down, reconnecting")
        TrayTip, RIS→Horos Sync, MacBook disconnected - reconnecting..., 5, 2
        TriggerMacReconnect(true)
    }
return

CheckMacReconnected:
    global g_macReconnecting, g_macReconnectTries, g_syncAfterReconnect, g_lastAccNo
    if !IsCurrentSessionRDPConnected()
        return
    g_macReconnectTries++
    if (IsMacBookReachable(true)) {
        SetTimer, CheckMacReconnected, Off
        tries := g_macReconnectTries
        g_macReconnecting := false
        g_macReconnectTries := 0
        LogSync("Reconnect: Mac server back after " tries " tries")
        TrayTip, RIS→Horos Sync, MacBook reconnected, 4, 1
        if (g_syncAfterReconnect) {
            g_syncAfterReconnect := false
            g_lastAccNo := ""
            LogSync("Reconnect: syncing current RIS study")
            SetTimer, PollRIS_Event, -1
        }
    } else if (g_macReconnectTries >= 45) {   ; 90 s: the Mac watchdog needs up to 80 s
        SetTimer, CheckMacReconnected, Off
        g_macReconnecting := false
        g_macReconnectTries := 0
        LogSync("Reconnect: gave up after 45 tries")
        TrayTip, RIS→Horos Sync, MacBook reconnect failed, 4, 2
    }
return

; ── Toggle ────────────────────────────────────────────────────────────────────
ToggleSync:
    global SYNC_ENABLED, g_lastAccNo
    SYNC_ENABLED := !SYNC_ENABLED
    g_lastAccNo  := ""   ; reset so next poll fires immediately when re-enabled
    Menu, Tray, Rename, % syncLabel(!SYNC_ENABLED), % syncLabel()
    Menu, Tray, Default, % syncLabel()
    Menu, Tray, Tip, % "RIS→Horos Sync [" (SYNC_ENABLED ? "ON" : "OFF") "]"
    ToolTip, % "Horos Sync " (SYNC_ENABLED ? "ON" : "OFF")
    SetTimer, ClearTip, -1500
    if SYNC_ENABLED
        SetTimer, PollRIS_Event, -1
return

ClearTip:
    ToolTip
return

ClearTip2:
    ToolTip, , , , 2
return

; ── Helpers ───────────────────────────────────────────────────────────────────
syncLabel(enabled="") {
    global SYNC_ENABLED
    state := (enabled = "") ? SYNC_ENABLED : enabled
    return "Horos Sync: " . (state ? "ON  ✓" : "OFF")
}

GetCurrentStudyInfo(ByRef accNo, ByRef chartNo, ByRef studyDate, ByRef patname, ByRef examname, ByRef examtime, ByRef mccid) {
    global CH_RIS, __CH_RIS_CLIENT, g_lastInfoSource, g_lastInfoError, g_lastMccid
    global g_lastRisStatus, g_haveStateSnapshot
    accNo := ""
    chartNo := ""
    studyDate := ""
    patname := ""
    examname := ""
    examtime := ""
    mccid := ""
    g_lastInfoSource := ""
    g_lastRisStatus := ""
    g_haveStateSnapshot := false

    LogV("GetCurrentStudyInfo: EnsureCHRIS ...")
    t0 := A_TickCount
    EnsureCHRIS(false, true)   ; skipUpdateWb — caller already did it
    LogV("GetCurrentStudyInfo: EnsureCHRIS done (" A_TickCount-t0 "ms)")

    ; Client mode: fetch all study fields in one request. The old proxy-property path
    ; remains below as a compatibility fallback for owner mode or IPC snapshot failure.
    if (__CH_RIS_CLIENT && IsFunc("CH_GetState")) {
        snapshotT0 := A_TickCount
        state := CH_GetState()
        if IsObject(state) {
            accNo := Trim("" state.accNo)
            chartNo := Trim("" state.chartNo)
            studyDate := Trim("" state.examDate)
            patname := Trim("" state.patname)
            examname := Trim("" state.examname)
            examtime := Trim("" state.examtime)
            mccid := Trim("" state.mccid)
            if (chartNo = "")
                chartNo := Trim("" state.patno)
            if (patname = "")
                patname := Trim("" state.namec)
            g_lastRisStatus := Trim("" state.status)
            g_haveStateSnapshot := true
            g_lastMccid := mccid
            g_lastInfoSource := "IPC snapshot"
            if (studyDate = "" && examtime != "")
                studyDate := RegExReplace(SubStr(examtime, 1, 10), "\D", "")
            LogV("GetCurrentStudyInfo: IPC snapshot done (" A_TickCount-snapshotT0 "ms)")
            return
        }
        LogV("GetCurrentStudyInfo: IPC snapshot unavailable; using compatibility reads")
    }

    if IsObject(CH_RIS) {
        try accNo := Trim("" CH_RIS.accNo)
        try chartNo := Trim("" CH_RIS.chartNo)
        try studyDate := Trim("" CH_RIS.examDate)
        try patname := Trim("" CH_RIS.patname)
        try examname := Trim("" CH_RIS.examname)
        try examtime := Trim("" CH_RIS.examtime)
        try mccid := Trim("" CH_RIS.GetModalityCode())
        if (mccid = "")
            try mccid := Trim("" CH_RIS.mccid)

        if (chartNo = "")
            try chartNo := Trim("" CH_RIS.patno)
        if (patname = "") {
            try patname := Trim("" CH_RIS.namec)
            if (patname = "")
                try patname := Trim("" CH_RIS.patName)
        }

        if (accNo = "") {
            LogV("GetCurrentStudyInfo: accNo empty -> get_fields ...")
            t1 := A_TickCount
            try CH_RIS.get_fields()
            LogV("GetCurrentStudyInfo: get_fields done (" A_TickCount-t1 "ms)")
            try accNo := Trim("" CH_RIS.accNo)
            try chartNo := (chartNo = "") ? Trim("" CH_RIS.chartNo) : chartNo
            try studyDate := (studyDate = "") ? Trim("" CH_RIS.examDate) : studyDate
            try examname := (examname = "") ? Trim("" CH_RIS.examname) : examname
            try examtime := (examtime = "") ? Trim("" CH_RIS.examtime) : examtime
            try patname := (patname = "") ? Trim("" CH_RIS.patname) : patname
            try mccid := (mccid = "") ? Trim("" CH_RIS.GetModalityCode()) : mccid
            try mccid := (mccid = "") ? Trim("" CH_RIS.mccid) : mccid
            g_lastInfoSource := "IE(get_fields)"
        } else {
            g_lastInfoSource := "IE(update_wb)"
        }
        g_lastMccid := mccid
    }

    if (WinExist("CH_RIS_GUI ahk_class AutoHotkeyGUI")) {
        if IsObject(CH_RIS) && IsObject(CH_RIS.gui) {
            if (accNo = "")
                try ControlGetText, accNo, , % "ahk_id " CH_RIS.gui.accno_edit_auto
            if (patname = "")
                try ControlGetText, patname, , % "ahk_id " CH_RIS.gui.patname_edit_auto
            if (examname = "")
                try ControlGetText, examname, , % "ahk_id " CH_RIS.gui.examname_edit_auto
            if (examtime = "")
                try ControlGetText, examtime, , % "ahk_id " CH_RIS.gui.examtime_edit_auto
        } else {
            if (accNo = "")
                ControlGetText, accNo, Edit4, CH_RIS_GUI ahk_class AutoHotkeyGUI
            if (patname = "")
                ControlGetText, patname, Edit3, CH_RIS_GUI ahk_class AutoHotkeyGUI
            if (examname = "")
                ControlGetText, examname, Edit7, CH_RIS_GUI ahk_class AutoHotkeyGUI
            if (examtime = "")
                ControlGetText, examtime, Edit8, CH_RIS_GUI ahk_class AutoHotkeyGUI
        }
        if (g_lastInfoSource = "")
            g_lastInfoSource := "CH_RIS_GUI"
    }

    if (accNo = "" && WinExist("CH_RIS_GUI ahk_class AutoHotkeyGUI")) {
        ControlGetText, legacyAccNo, Edit4, CH_RIS_GUI ahk_class AutoHotkeyGUI
        if (Trim(legacyAccNo) != "") {
            accNo := Trim(legacyAccNo)
            if (patname = "")
                ControlGetText, patname, Edit3, CH_RIS_GUI ahk_class AutoHotkeyGUI
            if (examname = "")
                ControlGetText, examname, Edit7, CH_RIS_GUI ahk_class AutoHotkeyGUI
            if (examtime = "")
                ControlGetText, examtime, Edit8, CH_RIS_GUI ahk_class AutoHotkeyGUI
            g_lastInfoSource := "legacy Edit4"
        }
    }

    if (studyDate = "" && examtime != "")
        studyDate := RegExReplace(SubStr(examtime, 1, 10), "\D", "")
}

LogSync(msg) {
    global g_logFile
    try {
        if (Trim("" g_logFile) = "") {
            FormatTime, logDate,, yyyyMMdd
            LogRetention_DeleteFilesOlderThan(A_ScriptDir, "RisHorosSync_*.log")
            LogRetention_DeleteFilesOlderThan(A_ScriptDir, "RisHorosSync.log")
            g_logFile := A_ScriptDir "\RisHorosSync_" logDate ".log"
        }

        msg := "" msg
        ; Guard against NUL/invalid chars causing FileAppend failure.
        msg := StrReplace(msg, Chr(0), "<NUL>")
        FormatTime, ts, , yyyy-MM-dd HH:mm:ss
        FileAppend, % ts " | " msg "`r`n", % g_logFile
    } catch e {
        ; Logging must never break sync flow.
        return
    }
}

DescribeException(e) {
    err := ""
    try err .= "What: " e.What
    try err .= "`nMessage: " e.Message
    try if (e.Extra != "")
        err .= "`nExtra: " e.Extra
    try if (e.File != "")
        err .= "`nFile: " e.File
    try if (e.Line != "")
        err .= "`nLine: " e.Line
    err .= "`nA_LastError: " A_LastError
    return err
}

; ── Exit ──────────────────────────────────────────────────────────────────────
RisHoros_OnExit:
    UnregisterSessionNotifications()
return

DoExit:
ExitApp
return
