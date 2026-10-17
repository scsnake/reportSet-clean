$ErrorActionPreference = 'Stop'
$mammoSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'YCH_mammo_Enh.ahk') -Raw -Encoding UTF8
$mammoHandler = [regex]::Match($mammoSource, '(?ms)^Mammo_RequestSimpleRisIndicationToggle\(\)\{.*?(?=^Mammo_NotifyPriorHistory\()').Value
if (-not $mammoHandler) { throw 'Cannot find production indication handler' }
$mammoHistoryNotify = [regex]::Match($mammoSource, '(?ms)^Mammo_NotifyPriorHistory\(historyHwnd\)\{.*?(?=^Mammo_FlushReport\()').Value
if (-not $mammoHistoryNotify) { throw 'Cannot find production history notification helper' }
$mammoHarness = @'
#NoEnv
DetectHiddenWindows, On
global __is_CH := true, CH_RIS := {}, Mammo_ReportBuildBusy := true
global Mammo_PendingIndicationToggle := false, Mammo_ReportReadyEdits := ""
global Mammo_ReportSyncDirty := false, toggleCount := 0, flushCount := 0
global Mammo_IndicationSyncEdits := "", Mammo_IndicationSyncBusy := false
global interruptSync := false, notifyCount := 0
global allowToggle := true, targetEdits := [123, 123]
Mammo_RequestSimpleRisIndicationToggle()
Check(Mammo_PendingIndicationToggle && toggleCount = 0 && flushCount = 0, "construction queues the key")
Mammo_RequestSimpleRisIndicationToggle()
Check(!Mammo_PendingIndicationToggle && toggleCount = 0, "two early presses cancel the pending toggle")
Mammo_RequestSimpleRisIndicationToggle()
Check(Mammo_PendingIndicationToggle && toggleCount = 0, "third early press queues one toggle")
Mammo_PendingIndicationToggle := false
Mammo_ReportReadyEdits := targetEdits
Mammo_RequestSimpleRisIndicationToggle()
Check(toggleCount = 1 && Mammo_ReportSyncDirty && flushCount = 0, "ready report toggles before sync completes")
Mammo_ReportSyncDirty := false
Mammo_RequestSimpleRisIndicationToggle()
Check(toggleCount = 2 && Mammo_ReportSyncDirty && flushCount = 0, "another key toggles again during sync")
Mammo_ReportSyncDirty := false
allowToggle := false
Mammo_RequestSimpleRisIndicationToggle()
Check(!Mammo_ReportSyncDirty && flushCount = 0, "failed local edit does not request a sync")
allowToggle := true
Mammo_ReportBuildBusy := false
Mammo_RequestSimpleRisIndicationToggle()
Check(toggleCount = 3 && flushCount = 0 && IsObject(Mammo_IndicationSyncEdits), "idle key returns before RIS sync")
SetTimer, Mammo_SyncIndicationReport, Off
interruptSync := true
Mammo_SyncIndicationReport()
SetTimer, Mammo_SyncIndicationReport, Off
Check(toggleCount = 4 && flushCount = 1 && IsObject(Mammo_IndicationSyncEdits), "key pressed during sync edits immediately and schedules latest report")
Mammo_SyncIndicationReport()
Check(flushCount = 2 && !IsObject(Mammo_IndicationSyncEdits) && !Mammo_IndicationSyncBusy, "latest report synced after interrupted wait")
allowToggle := false
Mammo_RequestSimpleRisIndicationToggle()
Check(notifyCount = 1 && flushCount = 2, "failed idle edit is visible and never synced")
Mammo_IndicationSyncEdits := targetEdits
Mammo_ReportBuildBusy := true
Mammo_SyncIndicationReport()
Check(flushCount = 2 && !IsObject(Mammo_IndicationSyncEdits), "new builder discards older pending sync")
Check(!Mammo_NotifyPriorHistory(0), "absent history window is non-fatal")
Gui, TestHistory:New, +hwndhistoryHwnd +ToolWindow
Check(Mammo_NotifyPriorHistory(historyHwnd), "existing history window receives notification")
Gui, TestHistory:Destroy
Check(!Mammo_NotifyPriorHistory(historyHwnd), "closed history window is non-fatal")
FileAppend, PASS: indication dispatch including keys during RIS sync and history notifications (no live RIS calls)`n, *
ExitApp, 0
Check(ok, label) {
    if !ok {
        FileAppend, % "FAIL: " label "`n", *
        ExitApp, 1
    }
}
Mammo_SimpleRisHotkeyEditHwnds() {
    global targetEdits
    return targetEdits
}
Mammo_ToggleSimpleRisIndication(edits) {
    global toggleCount, allowToggle, targetEdits
    Check(edits = targetEdits, "captured editor is used")
    if !allowToggle
        return false
    toggleCount++
    return true
}
Mammo_FlushReport(edits) {
    global flushCount, interruptSync
    flushCount++
    if interruptSync {
        interruptSync := false
        Mammo_RequestSimpleRisIndicationToggle()
    }
}
OnScreenDisplay(text) {
    global notifyCount
    notifyCount++
}
'@
$mammoTestPath = Join-Path ([IO.Path]::GetTempPath()) ('mammo_indication_' + [guid]::NewGuid().ToString('N') + '.ahk')
try {
    [IO.File]::WriteAllText($mammoTestPath, $mammoHarness + "`r`n" + $mammoHandler + "`r`n" + $mammoHistoryNotify, [Text.UTF8Encoding]::new($true))
    & (Join-Path $PSScriptRoot 'AutoHotkey.exe') /ErrorStdOut $mammoTestPath | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Indication test failed: $LASTEXITCODE" }
} finally {
    Remove-Item -LiteralPath $mammoTestPath -ErrorAction SilentlyContinue
}
