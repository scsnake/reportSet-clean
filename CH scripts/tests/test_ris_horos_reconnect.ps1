param([string]$AhkExe = (Join-Path $PSScriptRoot '..\..\AutoHotkey.exe'))

$ErrorActionPreference = 'Stop'
$repoDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$syncSource = [IO.File]::ReadAllText((Join-Path $repoDir 'CH scripts\RisHorosSync.ahk'))
$autorunSource = [IO.File]::ReadAllText((Join-Path $repoDir 'autorun.ahk'))

function Get-AhkFunction([string]$Source, [string]$Name) {
    $pattern = '(?ms)^' + [regex]::Escape($Name) + '\([^\r\n]*\)\s*\{.*?^\}'
    $match = [regex]::Match($Source, $pattern)
    if (!$match.Success) { throw "Missing function ${Name}" }
    return $match.Value
}

function Get-AhkLabel([string]$Source, [string]$Name) {
    $pattern = '(?ms)^' + [regex]::Escape($Name) + ':\s*\r?\n.*?^return\b'
    $match = [regex]::Match($Source, $pattern)
    if (!$match.Success) { throw "Missing label ${Name}" }
    return $match.Value
}

# Run the actual reconnect routines with session/network/owner dependencies replaced.
# The production auto-execute section, hotkeys, windows and HTTP/SSH never run.
$harness = @'
#NoEnv
SetBatchLines, -1
global failures := 0, remote := false, reachable := true, runtimeStarts := 0
global reconnectRequests := 0, renewedSubscriptions := 0, localHooks := 0
global SYNC_ENABLED := true, g_wasRdp := false, g_rdpArrivalPending := false
global g_lastRdpArrivalTick := 0, g_lastAccNo := "CURRENT", g_syncAfterReconnect := false
global g_accNoHookRegistered := false, __CH_RIS_CLIENT := true
global __CH_RIS_CLIENT_AccNoMsg := 0x8401, POLL_INTERVAL := 10000
global thisPlace := "C hospital", launchChecks := 0, g_macReconnectTries := 0

RisHoros_WTSSessionChange(0x3, 2, 0, 0)
Assert(g_rdpArrivalPending && !g_wasRdp, "arrival does not assume protocol is ready")
HandleRdpArrivalNow("test")
Assert(g_rdpArrivalPending && localHooks = 0, "early arrival remains pending")
remote := true
Gosub, SessionModeWatch
Assert(g_wasRdp && !g_rdpArrivalPending && localHooks = 1 && g_lastAccNo = ""
    , "watchdog resumes monitoring and queues current study after session settles")
g_lastAccNo := "CURRENT"
RisHoros_WTSSessionChange(0x8, 2, 0, 0)
HandleRdpArrivalNow("test")
Assert(g_lastAccNo = "CURRENT" && renewedSubscriptions = 0, "duplicate unlock is debounced")
RisHoros_WTSSessionChange(0x4, 2, 0, 0)
Assert(!g_wasRdp && !g_rdpArrivalPending && g_lastRdpArrivalTick = 0, "disconnect resets arrival state")
RisHoros_WTSSessionChange(0x3, 2, 0, 0)
HandleRdpArrivalNow("test")
Assert(g_lastAccNo = "" && renewedSubscriptions = 1 && localHooks = 1
    , "fast reconnect resyncs and renews owner subscription without duplicate callbacks")

remote := false
Gosub, SessionModeWatch
Assert(!g_wasRdp && g_lastRdpArrivalTick = 0, "watchdog detects disconnect without notification")
remote := true
g_lastAccNo := "CURRENT"
Gosub, SessionModeWatch
Assert(g_wasRdp && g_lastAccNo = "", "watchdog recovers missed connect notification")

SYNC_ENABLED := false
RisHoros_WTSSessionChange(0x4, 2, 0, 0)
g_lastAccNo := "CURRENT"
RisHoros_WTSSessionChange(0x5, 2, 0, 0)
HandleRdpArrivalNow("test")
Assert(!SYNC_ENABLED && !g_rdpArrivalPending, "reconnect preserves disabled sync preference")
SYNC_ENABLED := true
reachable := false
RisHoros_WTSSessionChange(0x4, 2, 0, 0)
RisHoros_WTSSessionChange(0x3, 2, 0, 0)
HandleRdpArrivalNow("test")
Assert(g_syncAfterReconnect && reconnectRequests = 1, "offline arrival retains current-study sync")
g_lastAccNo := "CURRENT"
remote := false
Gosub, CheckMacReconnected
Assert(g_macReconnectTries = 0 && g_syncAfterReconnect, "disconnected session pauses Mac recovery")
remote := true
reachable := true
Gosub, CheckMacReconnected
Assert(!g_syncAfterReconnect && g_lastAccNo = "", "Mac recovery re-evaluates current study")
reachable := false
g_lastMccid := "54"
ShouldSendToMac()
Assert(g_syncAfterReconnect && reconnectRequests = 2, "offline poll also requests current-study replay")

; Autorun receives notifications for every Windows session. Its bridge restore
; must use our session only and precede its monitor-layout deduplication.
DllCall("ProcessIdToSessionId", "UInt", DllCall("GetCurrentProcessId"), "UInt*", sessionId)
WM_WTSSESSION_CHANGE(0x3, sessionId + 1, 0, 0)
Sleep, 800
Assert(launchChecks = 0, "another session cannot start our bridge")
WM_WTSSESSION_CHANGE(0x3, sessionId, 0, 0)
Sleep, 800
Assert(launchChecks = 1, "same-layout reconnect still ensures bridge exists")

FileAppend, % "Failures: " failures "`n", *
ExitApp, % failures ? 1 : 0

Assert(ok, name) {
    global failures
    if !ok
        failures++
    FileAppend, % (ok ? "PASS: " : "FAIL: ") name "`n", *
}
IsCurrentSessionRDPConnected() {
    global remote
    return remote
}
IsMacBookReachable(forceCheck := false) {
    global reachable
    return reachable
}
EnsureCHRIS(forceRefresh := false, skipUpdateWb := false) {
    global CH_RIS
    if !IsObject(CH_RIS)
        CH_RIS := new TestOwnerProxy()
}
class TestOwnerProxy {
    addAccNoChangedHookFn(fn) {
        global localHooks
        localHooks++
    }
}
CH_RIS_Call(cmd, args, wantReply) {
    global renewedSubscriptions, __CH_RIS_CLIENT_AccNoMsg
    Assert(cmd = "sub_accno" && args.hwnd = A_ScriptHwnd
        && args.msg = __CH_RIS_CLIENT_AccNoMsg && !wantReply, "subscription uses correct IPC message")
    renewedSubscriptions++
}
RisHoros_AccNoChanged() {
}
TriggerMacReconnect(syncAfterReconnect := false) {
    global g_syncAfterReconnect, reconnectRequests
    g_syncAfterReconnect := syncAfterReconnect
    reconnectRequests++
}
LogSync(msg) {
}
LogV(msg) {
}
; Avoid desktop notifications even for the offline tests.
monitorInfo() {
    return [{w: 1920}]
}
TaskKill(name) {
}
AltTab_window_list() {
    return []
}
WinGet(command, hwnd) {
    return 1
}
PollRIS:
PollRIS_Event:
HandleRdpArrival:
MacHealthCheck:
return
StartRisHorosSync:
    launchChecks++
return
'@

foreach ($name in @('RisHoros_WTSSessionChange', 'StartRdpSyncRuntime', 'HandleRdpArrivalNow', 'ShouldSendToMac')) {
    $harness += "`r`n" + (Get-AhkFunction $syncSource $name)
}
foreach ($name in @('SessionModeWatch', 'CheckMacReconnected')) {
    $harness += "`r`n" + (Get-AhkLabel $syncSource $name)
}
$harness += "`r`n" + (Get-AhkFunction $autorunSource 'WM_WTSSESSION_CHANGE')
# UI commands are outside the behavior under test; do not touch live simpleRIS.
$harness = [regex]::Replace($harness, '(?m)^\s*(TrayTip|PostMessage),[^\r\n]*', '')

$testPath = Join-Path ([IO.Path]::GetTempPath()) ('ris_horos_reconnect_test_' + [guid]::NewGuid().ToString('N') + '.ahk')
try {
    [IO.File]::WriteAllText($testPath, $harness, [Text.UTF8Encoding]::new($true))
    & $AhkExe /iLib NUL /ErrorStdOut $testPath | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Test harness failed syntax check' }
    & $AhkExe /ErrorStdOut $testPath | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Reconnect regression tests failed' }
} finally {
    Remove-Item -LiteralPath $testPath -ErrorAction SilentlyContinue
}
