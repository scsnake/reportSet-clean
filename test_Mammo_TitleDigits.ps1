$ErrorActionPreference = 'Stop'
$source = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'YCH_mammo_Enh.ahk') -Raw -Encoding UTF8
$dynamic = [regex]::Match($source, '(?ms)^    dynamic_hotstring\(trigger,.*?(?=^    insertDate\()').Value
if (-not $dynamic) { throw 'Cannot find production dynamic hotstring function' }
# Drive callbacks directly; never install keyboard hooks in this test process.
$dynamic = $dynamic.Replace('keysBound := false', 'keysBound := true')
# Supply the names AHK gives its callback without sending keyboard events.
$dynamic = $dynamic.Replace('A_ThisHotkey', 'testCallbackHotkey')
$registration = [regex]::Match($source, '(?m)^dynamic_hotstring\("i\)\\b\(\[lrb\]\).*?"CHmammoTitle",3,0\)').Value
if (-not $registration) { throw 'Cannot find production title registration' }
$registration = $registration.Replace('"CHmammoTitle"', '"CaptureTitle"')
$digitBlock = [regex]::Match($source, '(?ms)^    1::.*?(?=^    ~numpad2::)').Value
if (-not $digitBlock) { throw 'Cannot find production PACS digit handler' }
$digitBlock = [regex]::Replace($digitBlock, '(?m)^    [12]::\r?\n', '')
$digitBlock = $digitBlock.Replace('A_ThisHotkey', 'testHotkey')
$digitBlock = [regex]::Replace($digitBlock, '(?m)^\s*SetTimer, CH_MammoPacsPostView\w+, Off', '            RecordTimerStop()')
$digitBlock = $digitBlock.Replace('SendInput, % testHotkey', 'RecordSend(testHotkey)')
$digitBlock = $digitBlock.Replace('SendLevelChange(testHotkey)', 'RefeedDigit(testHotkey)')
$harness = @'
#NoEnv
global captured := "", count := 0
global testCallbackHotkey := ""
global testHotkey := "", testFocusClass := "Edit", sendCount := 0, viewCount := 0, queueCount := 0, timerStops := 0
'@ + "`r`n" + $registration + "`r`n" + @'
; Static 1::/2:: are registered before the dynamic ~$ watchers. AHK keeps
; those original names for ALL variants, including the global watcher.
for k, side in ["r", "l"] {
    for k, testCallbackHotkey in ["1", "2", "$1", "$2", "~1", "~2", "~$1", "~$2", "~$3", "~$4", "~numpad1", "~numpad2", "~$Numpad3", "~$Numpad4"] {
        dynamic_hotstring("", "", "", "", "", true)
        captured := ""
        dynamic_hotstring(side, "", "CALLBACK")
        dynamic_hotstring("m", "", "CALLBACK")
        dynamic_hotstring("c", "", "CALLBACK")
        dynamic_hotstring("", "", "CALLBACK")
        dynamic_hotstring("Space", "", "CALLBACK")
        Check(IsObject(captured), "native callback preserves density: " side "mc + " testCallbackHotkey)
        Check(captured.Value(1) = side && captured.Value(4) = RegExReplace(testCallbackHotkey, "\D"), "native callback captures correct side and density")
    }
}
for k, symbol in ["$", "*", "~"] {
    dynamic_hotstring("", "", "", "", "", true)
    captured := ""
    dynamic_hotstring(symbol, "CaptureSymbol", 1, 0)
    testCallbackHotkey := "~$" symbol
    dynamic_hotstring("", "", "CALLBACK")
    Check(captured == symbol, "literal hook-prefix symbol preserved: " symbol)
    dynamic_hotstring(symbol, "", 1)
}
for k, side in ["r", "l", "b"] {
    for k, modifier in ["", "m"] {
        for k, implant in ["", "i"] {
            Loop, 4 {
                density := A_Index
                title := side modifier "mc" implant density
                for k, ending in ["Space", "/", "NumpadDiv"] {
                    dynamic_hotstring("", "", "", "", "", true)
                    captured := ""
                    Loop, Parse, title
                    {
                        dynamic_hotstring(A_LoopField, "", "CALLBACK")
                    }
                    Check(dynamic_hotstring("", "", "MAMMO_TITLE_PENDING"), "density digit belongs to title")
                    dynamic_hotstring(ending, "", "CALLBACK")
                    Check(IsObject(captured), "title triggers exactly once: " title " + " ending)
                    Check(captured.Value(1) = side && (captured.Value(2) != "") = (modifier != "") && (captured.Value(3) != "") = (implant != "") && captured.Value(4) = density, "side, magnification, implant and density preserved")
                    Check(!dynamic_hotstring("", "", "MAMMO_TITLE_PENDING"), "completed title clears buffer")
                }
            }
        }
    }
}
Loop, 4 {
    density := A_Index
    dynamic_hotstring("", "", "", "", "", true)
    captured := ""
    dynamic_hotstring("r", "", "CALLBACK")
    dynamic_hotstring("m", "", "CALLBACK")
    dynamic_hotstring("c", "", "CALLBACK")
    dynamic_hotstring("Numpad" density, "", "CALLBACK")
    Check(dynamic_hotstring("", "", "MAMMO_TITLE_PENDING"), "numpad density belongs to title")
    dynamic_hotstring("Space", "", "CALLBACK")
    Check(captured.Value(4) = density, "numpad density preserved")
}
dynamic_hotstring("", "", "", "", "", true)
dynamic_hotstring("2", "", "CALLBACK")
Check(!dynamic_hotstring("", "", "MAMMO_TITLE_PENDING"), "standalone digit keeps PACS behavior")
dynamic_hotstring("", "", "", "", "", true)
dynamic_hotstring("r", "", "CALLBACK")
dynamic_hotstring("m", "", "CALLBACK")
dynamic_hotstring("c", "", "CALLBACK")
dynamic_hotstring("2", "", "CALLBACK")
dynamic_hotstring("2", "", "CALLBACK")
Check(!dynamic_hotstring("", "", "MAMMO_TITLE_PENDING"), "duplicate synthetic digit corrupts title (regression trigger)")
for k, testFocusClass in ["Edit", "AfxWnd140u"] {
    for k, testHotkey in ["1", "2"] {
        dynamic_hotstring("", "", "", "", "", true)
        captured := ""
        sendCount := viewCount := queueCount := timerStops := 0
        dynamic_hotstring("r", "", "CALLBACK")
        dynamic_hotstring("m", "", "CALLBACK")
        dynamic_hotstring("c", "", "CALLBACK")
        Gosub, TestDigit
        Check(viewCount = 0 && queueCount = 0 && timerStops = 2, "title digit cancels viewer actions")
        Check(sendCount = (testFocusClass = "Edit" ? 1 : 0), "title digit delivered once to PACS edit")
        dynamic_hotstring("Space", "", "CALLBACK")
        Check(IsObject(captured) && captured.Value(4) = testHotkey, "scoped PACS handler preserves complete title")
    }
    dynamic_hotstring("", "", "", "", "", true)
    sendCount := viewCount := queueCount := 0
    testHotkey := "2"
    Gosub, TestDigit
    Check(sendCount = (testFocusClass = "Edit" ? 1 : 0) && viewCount = (testFocusClass = "Edit" ? 0 : 1) && queueCount = viewCount, "standalone PACS digit preserves typing and viewer actions")
}
FileAppend, % "PASS: " count " title variants plus numpad and standalone digit cases (no keyboard sends or live RIS calls)`n", *
ExitApp, 0
CaptureTitle(match) {
    global captured, count
    Check(!IsObject(captured), "single title callback")
    captured := match
    count++
}
CaptureSymbol(symbol) {
    global captured
    captured := symbol
}
Check(ok, label) {
    if !ok {
        FileAppend, % "FAIL: " label "`n", *
        ExitApp, 1
    }
}
getFocusedHwnd() {
    return 123
}
WinGetClass(hwnd) {
    global testFocusClass
    return testFocusClass
}
RecordSend(key) {
    global sendCount
    sendCount++
}
RefeedDigit(key) {
    RecordSend(key)
    dynamic_hotstring(key, "", "CALLBACK")
}
RecordTimerStop() {
    global timerStops
    timerStops++
}
CH_MammoPacsSendViewerKey(key) {
    global viewCount
    viewCount++
}
CH_MammoPacsQueuePostViewKeys() {
    global queueCount
    queueCount++
}
'@
$testPath = Join-Path ([IO.Path]::GetTempPath()) ('mammo_title_' + [guid]::NewGuid().ToString('N') + '.ahk')
try {
    [IO.File]::WriteAllText($testPath, $harness + "`r`nTestDigit:`r`n" + $digitBlock + "`r`n" + $dynamic, [Text.UTF8Encoding]::new($true))
    & (Join-Path $PSScriptRoot 'AutoHotkey.exe') /ErrorStdOut $testPath | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Title test failed: $LASTEXITCODE" }
} finally {
    Remove-Item -LiteralPath $testPath -ErrorAction SilentlyContinue
}
