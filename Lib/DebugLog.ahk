; DebugLog.ahk
; Shared debug logger. Activated when %A_MyDocuments%\reportSet\__is_debug contains "1".
;
; Daily log files:  %A_MyDocuments%\reportSet\logs\debug_YYYY-MM-DD.log
;   - A new file is started automatically each calendar day (handles cross-midnight runs).
;   - Old files are removed by DebugLogCleanup(), called daily by Autorun.
;
; Usage:
;   DebugLog("CH_RIS.update_wb", "accNo changed: " old " -> " new)
;   DebugLogSession("simpleRIS.ahk")   ; stamp PID at startup
;   DebugLogStartCleanupTimer(7)       ; drop logs older than 7 days, then check daily

DebugLog(section, msg) {
    static _init := false, _on := false, _dir := "", _date := "", _log := ""
    if !_init {
        _init := true
        _dir  := A_MyDocuments "\reportSet\logs"
        flag  := ""
        try FileRead, flag, % A_MyDocuments "\reportSet\__is_debug"
        _on := (Trim(flag) = "1")
    }
    if !_on
        return

    ; Roll over to a per-day file. _date caches the current day so the path is
    ; only rebuilt once per day, not on every (high-volume) call.
    FormatTime, today,, yyyy-MM-dd
    if (today != _date) {
        _date := today
        if !FileExist(_dir)
            FileCreateDir, % _dir
        _log := _dir "\debug_" _date ".log"
    }

    FormatTime, ts,, yyyy-MM-dd HH:mm:ss
    line := ts " [" section "] " msg
    ; strip NUL chars that break FileAppend
    StringReplace, line, line, % Chr(0), <NUL>, All
    try FileAppend, % line "`r`n", % _log
}

; Call at script startup to stamp which process owns this log session.
DebugLogSession(scriptName := "") {
    if (scriptName = "")
        scriptName := A_ScriptName
    DebugLog("SESSION", "=== START " scriptName " PID=" DllCall("GetCurrentProcessId") " ===")
}

; Delete debug_*.log files older than daysToKeep. Safe to call unconditionally
; (independent of the __is_debug flag) so logs are pruned even when debug is off.
DebugLogCleanup(daysToKeep := 7) {
    dir := A_MyDocuments "\reportSet\logs"
    if !FileExist(dir)
        return
    cutoff := A_Now
    EnvAdd, cutoff, % -Abs(daysToKeep), Days   ; cutoff = now - daysToKeep
    Loop, Files, % dir "\debug_*.log"
    {
        ; Prefer the date embedded in the filename; fall back to file mtime.
        if RegExMatch(A_LoopFileName, "debug_(\d{4})-(\d{2})-(\d{2})\.log$", m)
            fstamp := m1 m2 m3 "000000"
        else
            fstamp := A_LoopFileTimeModified
        if (fstamp < cutoff)
            FileDelete, % A_LoopFileFullPath
    }
}

; Autorun stays resident, so it owns the daily log pruning timer.
DebugLogStartCleanupTimer(daysToKeep := 7) {
    global __DebugLogCleanupDaysToKeep
    __DebugLogCleanupDaysToKeep := Abs(daysToKeep)
    if (__DebugLogCleanupDaysToKeep < 1)
        __DebugLogCleanupDaysToKeep := 7
    DebugLogCleanup(__DebugLogCleanupDaysToKeep)
    fn := Func("DebugLogCleanupTimer")
    SetTimer, % fn, 86400000
}

DebugLogCleanupTimer() {
    global __DebugLogCleanupDaysToKeep
    DebugLogCleanup(__DebugLogCleanupDaysToKeep ? __DebugLogCleanupDaysToKeep : 7)
}
