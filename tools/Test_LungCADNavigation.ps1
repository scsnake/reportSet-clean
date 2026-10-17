# Exercise production navigation with mocked PACS, Chrome, focus, and logging.
# No production startup, browser input, or mouse movement is executed.
$ErrorActionPreference = 'Stop'
$cadRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$cadSource = [System.IO.File]::ReadAllText((Join-Path $cadRoot 'showLungCAD.ahk'))
$cadFixture = @'
#NoEnv
#SingleInstance, Off
SetBatchLines, -1
Thread, Interrupt, 0
checks := 0
chromeNavigationContext := Func("showLungCAD_IsNavigatingChrome")
Hotkey, If, % chromeNavigationContext
Hotkey, ^!+F24, showLungCAD_JumpToNoduleDeferred, On T3 UseErrorLevel
Assert(ErrorLevel = 0, "Chrome context hotkey can register on installed AHK v1")
Hotkey, ^!+F24, Off
Hotkey, If

timerCalls := 0
showLungCAD_StopINFINITTRefresh({})
Assert(timerCalls = 0, "non-INFINITT viewers have no timer to stop")
showLungCAD_StopINFINITTRefresh({INFINITTViewer: {SetTimer: Func("MockSetTimer")}})
Assert(timerCalls = 1 && timerMethod = "RefreshInfo" && timerPeriod = "Delete", "retained INFINITT refresh timer is deleted")

timerTicks := 0
timedViewer := new NavigationTimerFixture()
timedViewer.SetTimer("RefreshInfo", 10)
Sleep, 180
Assert(timerTicks > 0, "real timer class starts polling")
timedViewer := ""
latestTimerViewer := ""
beforeReplacementTicks := timerTicks
Sleep, 60
Assert(timerTicks > beforeReplacementTicks, "replaced viewer remains alive through its timer")
showLungCAD_StopINFINITTRefresh({INFINITTViewer: latestTimerViewer})
stoppedTicks := timerTicks
Sleep, 60
Assert(timerTicks = stoppedTicks, "refresh deletion stops actual callbacks")

ResetNavigation()
showLungCAD_ChangeNodule()
Assert(events = "pacs|browser|", "PACS acts before browser work")
Assert(lastUrl = "http://example.test/nodulePic/study/#&gid=1&pid=2", "browser receives selected nodule")
Assert(activeHwnd = 111, "background update restores PACS focus")

ResetNavigation()
OCR_RUN_ACTIVE := true
showLungCAD_ChangeNodule()
Assert(events = "" && pendingTimer, "busy OCR defers without scanning Chrome")
SetTimer, showLungCAD_JumpToNoduleDeferred, Off
OCR_RUN_ACTIVE := false
showLungCAD_ChangeNodule()
Assert(events = "pacs|browser|", "deferred target runs after OCR releases input")

ResetNavigation()
showLungCAD_BrowserNavigationActive := true
activeHwnd := 222
Assert(showLungCAD_IsNavigatingChrome(), "stepping stays enabled during automated Chrome update")
showLungCAD_ChangeNodule()
Assert(events = "" && pendingTimer, "press during Chrome update queues without nested browser or PACS input")
SetTimer, showLungCAD_JumpToNoduleDeferred, Off
showLungCAD_BrowserNavigationActive := false
Assert(!showLungCAD_IsNavigatingChrome(), "ordinary Chrome use does not enable PACS hotkeys")
activeHwnd := 111
showLungCAD_ChangeNodule()
Assert(events = "pacs|browser|", "queued press runs when Chrome releases input")
Assert(!showLungCAD_BrowserNavigationActive, "successful update clears navigation flag")

ResetNavigation()
simulateNewer := true
showLungCAD_ChangeNodule()
SetTimer, showLungCAD_JumpToNoduleDeferred, Off
Assert(thisInd = 3 && events = "pacs|", "interrupted target cannot overwrite browser with stale nodule")
simulateNewer := false
showLungCAD_ChangeNodule()
Assert(lastUrl = "http://example.test/nodulePic/study/#&gid=1&pid=3", "latest requested nodule wins")

ResetNavigation()
jsonData.Nodules[1].noduleIndBeforeSort := 7
showLungCAD_ChangeNodule()
Assert(InStr(lastUrl, "pid=8"), "sorted nodule keeps original browser picture index")

ResetNavigation()
ShowInImpax := false
showLungCAD_ChangeNodule()
Assert(events = "browser|show-browser|", "browser-only mode still shows browser")

ResetNavigation()
ShowInBrowser := false
showLungCAD_ChangeNodule()
Assert(events = "pacs|", "PACS-only mode does no browser work")

ResetNavigation()
simulateBrowserFailure := true
caught := false
try showLungCAD_ChangeNodule()
catch e
    caught := true
Assert(caught && events = "pacs|browser|" && activeHwnd = 111, "Chrome failure follows PACS action and restores focus")
Assert(!showLungCAD_BrowserNavigationActive, "Chrome exception clears navigation flag")

ResetNavigation()
ShowCadBrowserUrl("http://example.test/", true)
Assert(activeHwnd = 222, "explicit browser activation remains active")

ResetNavigation()
previousWindowExists := false
ShowCadBrowserUrl("http://example.test/", false)
Assert(activeHwnd = 222, "destroyed previous window is not activated")

FileAppend, % "PASS: " checks " navigation checks`n", *
ExitApp, 0

pacsSelect:
    events .= "pacs|"
    if (simulateNewer) {
        thisInd := 3
        OCR_RUN_ACTIVE := true
        showLungCAD_ChangeNodule()
        OCR_RUN_ACTIVE := false
    }
return
EBMselect:
    events .= "ebm|"
return
showLungCAD_JumpToNoduleDeferred:
return

ResetNavigation() {
    global
    SetTimer, showLungCAD_JumpToNoduleDeferred, Off
    __is_CH := true
    ShowInImpax := true
    ShowInBrowser := true
    nodulePicExists := true
    EBMmode := false
    OCR_RUN_ACTIVE := false
    showLungCAD_BrowserNavigationActive := false
    simulateNewer := false
    simulateBrowserFailure := false
    previousWindowExists := true
    pendingTimer := false
    thisInd := 2
    activeHwnd := 111
    currentUrl := "http://example.test/nodulePic/study/#&gid=1&pid=1"
    jsonData := {Nodules: {0: {}, 1: {}, 2: {}}}
    events := lastUrl := ""
}
showLungCAD_ShouldUseINFINITTOCR() {
    return true
}
showLungCAD_LogNavigation(stage, started := 0) {
    global pendingTimer
    if (stage = "WAIT FOR OCR" || stage = "WAIT FOR BROWSER")
        pendingTimer := true
}
navigateChrome(url) {
    global events, lastUrl, activeHwnd, simulateBrowserFailure
    events .= "browser|"
    lastUrl := url
    activeHwnd := 222
    if (simulateBrowserFailure)
        throw Exception("mock Chrome failure")
}
ShowCadBrowserWindow() {
    global events
    events .= "show-browser|"
}
MockWinExist(title) {
    global activeHwnd, previousWindowExists
    return title = "A" ? activeHwnd : previousWindowExists
}
MockWinActive(title) {
    global activeHwnd
    return activeHwnd = 222
}
MockActivate(hwnd) {
    global activeHwnd
    activeHwnd := hwnd
}
getPwb(instance) {
    throw Exception("unexpected IE path")
}
MockSetTimer(viewer, method, period) {
    global timerCalls, timerMethod, timerPeriod
    timerCalls++
    timerMethod := method
    timerPeriod := period
}
class NavigationTimerFixture extends SetTimerClass {
    RefreshInfo() {
        global timerTicks, latestTimerViewer
        timerTicks++
        latestTimerViewer := this
    }
}
Assert(condition, description) {
    global checks
    checks++
    if (!condition) {
        FileAppend, % "FAIL: " description "`n", **
        ExitApp, 1
    }
}
'@
$cadFixture = '#Include ' + (Join-Path $cadRoot 'Lib\SetTimerClass.ahk') + "`r`n" + $cadFixture
foreach ($cadFunction in @('showLungCAD_ChangeNodule', 'showLungCAD_CadPidUrl', 'ShowCadBrowserUrl', 'showLungCAD_IsNavigatingChrome', 'showLungCAD_StopINFINITTRefresh')) {
    $cadPattern = '(?m)^' + [regex]::Escape($cadFunction) + '\([^\r\n]*\)\{[\s\S]*?^\}'
    $cadMatch = [regex]::Match($cadSource, $cadPattern)
    if (-not $cadMatch.Success) { throw "Cannot extract production function: $cadFunction" }
    $cadFunctionText = $cadMatch.Value
    if ($cadFunction -eq 'ShowCadBrowserUrl') {
        $cadFunctionText = $cadFunctionText.Replace('WinExist(', 'MockWinExist(')
        $cadFunctionText = $cadFunctionText.Replace('WinActivate, ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe', 'MockActivate(222)')
        $cadFunctionText = $cadFunctionText.Replace('WinActivate, ahk_id %previousHwnd%', 'MockActivate(previousHwnd)')
    }
    if ($cadFunction -eq 'showLungCAD_IsNavigatingChrome') {
        $cadFunctionText = $cadFunctionText.Replace('WinActive(', 'MockWinActive(')
    }
    $cadFixture += "`r`n`r`n" + $cadFunctionText
}
$cadTemp = Join-Path ([System.IO.Path]::GetTempPath()) ('lungcad-navigation-test-' + [guid]::NewGuid().ToString('N') + '.ahk')
try {
    [System.IO.File]::WriteAllText($cadTemp, $cadFixture, [System.Text.UTF8Encoding]::new($true))
    & (Join-Path $cadRoot 'AutoHotkey.exe') /iLib NUL /ErrorStdOut $cadTemp | Out-String | Write-Output
    if ($LASTEXITCODE -ne 0) { throw "Navigation fixture parse failed: $LASTEXITCODE" }
    & (Join-Path $cadRoot 'AutoHotkey.exe') /ErrorStdOut $cadTemp | Out-String | Write-Output
    if ($LASTEXITCODE -ne 0) { throw "Navigation tests failed: $LASTEXITCODE" }
} finally {
    if (Test-Path -LiteralPath $cadTemp) { Remove-Item -LiteralPath $cadTemp }
}
