# Execute only extracted cleanup methods with fixture objects and mocked UI/COM.
$ErrorActionPreference = 'Stop'
$ownerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ownerFixture = @'
#NoEnv
#SingleInstance, Off
SetBatchLines, -1
Thread, Interrupt, 0
Sleep, 150
checks:=ticks:=freed:=browserQuits:=0

child:=new TimerOwner()
child.SetTimer("Tick", 10)
outer:={INFINITTViewer:child, base:{__Delete:Func("DisposeActivePacs")}}
outer:=""
Assert(!child.HasKey("__setTimerBindFn"), "releasing activePacs stops and clears child timers")
child:=""
Assert(freed=1, "released activePacs child is freed")
outer:={base:{__Delete:Func("DisposeActivePacs")}}
outer:=""
Assert(freed=1, "non-INFINITT activePacs cleanup is harmless")

bridge:=new TimerOwner()
bridge.wb:={Quit:Func("MockBrowserQuit")}
bridge._SetStatus:=Func("MockStatus")
bridge.SetTimer("Tick", 10)
CloseMobile(bridge)
Assert(!bridge.HasKey("__setTimerBindFn") && browserQuits=1 && bridge.state="idle", "mobile Close disposes timers and closes browser")
bridge.SetTimer("Tick", -10)
Sleep, 60
Assert(bridge.ticks=1, "closed mobile owner can schedule after reopening")
bridge.DisposeTimers()
bridge:=""

window:=new TimerOwner()
window.SetTimer("Tick", 10)
window.active:=true
HideCommandWindow(window)
Assert(IsObject(window.__setTimerBindFn.Tick), "active command window keeps its timers")
window.active:=false
HideCommandWindow(window)
Assert(!window.HasKey("__setTimerBindFn"), "hidden command window disposes timers")
window:=""

for _, finishMethod in [Func("FinishBreastPrint"), Func("FinishBreastPrintHelper")] {
    job:=new TimerOwner()
    job.SetTimer("Tick", 10)
    finishMethod.Call(job)
    Assert(!job.HasKey("__setTimerBindFn"), "completed breast print job clears cached callbacks")
    job:=""
}

fixtureWindows:=[{hwnd:2, LocationURL:"http://example.test:9090/webcvis/MJB/MJB3W001.do"}]
holder:={ris_list_wb:new CH_RIS_LIST({hwnd:1})}
beforeReplacement:=freed
ReplaceRisList(holder)
Assert(holder.ris_list_wb.wb.hwnd=2 && freed=beforeReplacement+1, "RIS list replacement disposes and frees old list (hwnd=" holder.ris_list_wb.wb.hwnd ", freed=" freed ", before=" beforeReplacement ")")
holder.ris_list_wb.DisposeTimers()
holder:=""

FileAppend,% "PASS: " checks " timer owner checks`n",*
ExitApp, 0

class TimerOwner extends SetTimerClass {
    Tick(){
        this.ticks:=(this.ticks="" ? 0 : this.ticks)+1
    }
    __Delete(){
        global freed
        freed++
    }
}
class CH_RIS_LIST extends TimerOwner {
    __New(wb){
        this.wb:=wb
        this.SetTimer("Tick", 10)
    }
}
MockBrowserQuit(browser){
    global browserQuits
    browserQuits++
}
MockStatus(owner, status){
    owner.status:=status
}
MockWindowCommand(){
}
MockShell(){
    return {Windows:Func("MockWindows")}
}
MockWindows(shell){
    ; Shell.Windows exposes each COM object as the first enumeration value.
    return {_NewEnum:Func("MockEnumerator")}
}
MockEnumerator(windows){
    return {index:0, Next:Func("MockNextWindow")}
}
MockNextWindow(enumerator, ByRef window, ByRef unused:=""){
    global fixtureWindows
    if (++enumerator.index>fixtureWindows.Length())
        return false
    window:=fixtureWindows[enumerator.index]
    return true
}
WinGetTitle(hwnd){
    return "C醫院"
}
DebugLog(args*){
}
Assert(condition, description){
    global checks
    checks++
    if !condition {
        FileAppend,% "FAIL: " description "`n",**
        ExitApp, 1
    }
}
'@
$ownerFixture = '#Include ' + (Join-Path $ownerRoot 'Lib\SetTimerClass.ahk') + "`r`n" + $ownerFixture
$ownerMethods = @(
    @('Lib\RisImpax.ahk', 'activePacs', '__Delete', 'DisposeActivePacs'),
    @('Lib\CH_Mobile_Bridge.ahk', 'CH_Mobile_Bridge', 'Close', 'CloseMobile'),
    @('Lib\cmdWindow.ahk', 'cmdWindow', 'Hide', 'HideCommandWindow'),
    @('YCH_mammo_Enh.ahk', 'breastUS_SendPrint', 'ClosePrint', 'FinishBreastPrint'),
    @('Hotstring Helper\YCH_mammo.ahk', 'breastUS_SendPrint', 'ClosePrint', 'FinishBreastPrintHelper'),
    @('Lib\CH_RIS.ahk', 'CH_RIS_REPORT', 'RIS_list_wb_changed', 'ReplaceRisList')
)
foreach ($ownerMethod in $ownerMethods) {
    $ownerSource = [System.IO.File]::ReadAllText((Join-Path $ownerRoot $ownerMethod[0]))
    $ownerClassStart = [regex]::Match($ownerSource, '(?m)^class ' + [regex]::Escape($ownerMethod[1]) + '\b')
    if (-not $ownerClassStart.Success) { throw "Missing class: $($ownerMethod[1])" }
    $ownerSource = $ownerSource.Substring($ownerClassStart.Index)
    $ownerPattern = '(?m)^([ \t]+)' + [regex]::Escape($ownerMethod[2]) + '\(\)\s*\{[\s\S]*?^\1\}'
    $ownerMatch = [regex]::Match($ownerSource, $ownerPattern)
    if (-not $ownerMatch.Success) { throw "Missing method: $($ownerMethod[2])" }
    $ownerBody = $ownerMatch.Value.Replace($ownerMethod[2] + '()', $ownerMethod[3] + '(this)')
    $ownerBody = [regex]::Replace($ownerBody, '(?mi)^[ \t]*(WinHide|WinSet|WinClose|WinActivate|SetTimer),[^\r\n]*', '    MockWindowCommand()')
    $ownerBody = $ownerBody.Replace('ComObjCreate("Shell.Application")', 'MockShell()')
    $ownerFixture += "`r`n`r`n" + $ownerBody
}
$ownerTemp = Join-Path ([System.IO.Path]::GetTempPath()) ('timer-owner-test-' + [guid]::NewGuid().ToString('N') + '.ahk')
try {
    [System.IO.File]::WriteAllText($ownerTemp, $ownerFixture, [System.Text.UTF8Encoding]::new($true))
    & (Join-Path $ownerRoot 'AutoHotkey.exe') /iLib NUL /ErrorStdOut $ownerTemp | Out-String | Write-Output
    if ($LASTEXITCODE -ne 0) { throw "Owner fixture parse failed: $LASTEXITCODE" }
    & (Join-Path $ownerRoot 'AutoHotkey.exe') /ErrorStdOut $ownerTemp | Out-String | Write-Output
    if ($LASTEXITCODE -ne 0) { throw "Timer owner tests failed: $LASTEXITCODE" }
} finally {
    if (Test-Path -LiteralPath $ownerTemp) { Remove-Item -LiteralPath $ownerTemp }
}
