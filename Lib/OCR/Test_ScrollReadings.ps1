# Runs the production OCR read/parse helpers against simulated frames.
# Only extracted functions execute; the PACS startup code and input commands do not.
$ErrorActionPreference = 'Stop'
$scrollRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scrollAhk = Join-Path $scrollRoot 'AutoHotkey.exe'
$scrollSource = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'INFINITT_OCR_Scroll.ahk'))
$scrollFunctions = @('OCR_ReadAfterInput', 'ParseOCR', 'NormalizeOCR_SpSlText',
    'OCR_NormalizeImgDigits', 'ParseOCR_SPSpacing', 'ParseOCR_ImgTotal', 'INFINITT_OCR_IsAbortRequested', 'OCR_IncrementalDrag')
$scrollFixture = @'
#NoEnv
#SingleInstance, Off
SetBatchLines, -1
checks := 0
OCR_ACTIVE_RUN_ID := 1
OCR_RUN_ACTIVE := true
OCR_RUN_DEADLINE := A_TickCount + 10000
OCR_ABORTED_RUNS := {}
Assert(ParseOCR("SL : 1.251sp5.OO SP : -311.25", "SP") = -311.25, "position versus thickness")
Assert(ParseOCR("SL : 5.OOlsp5.OO SP : -32.35", "SP") = -32.35, "thick slice OCR")
Assert(ParseOCR("SP : 0.00", "SP") = 0, "zero SP")
Assert(ParseOCR("", "SP") = "", "empty OCR")
Assert(ParseOCR_ImgTotal("Img 298 / 300") = 300, "image total")

samples := ["SP: -100", "SP: -100", "SP: -110", "SP: -110"]
reads := 0
Assert(ParseOCR(OCR_ReadAfterInput([], 0, "SP", "", 0, 0, -100, 1), "SP") = -110 && reads = 4, "wait through stale frames")
samples := ["", "SP: -110", "SP: -110"]
reads := 0
Assert(ParseOCR(OCR_ReadAfterInput([], 0, "SP", "", 0, 0, -100, 1), "SP") = -110 && reads = 3, "recover blank frame")
samples := ["SP: -101", "SP: -102", "SP: -103", "SP: -104", "SP: -105"]
reads := 0
Assert(OCR_ReadAfterInput([], 0, "SP", "", 0, 0, -100, 1) = "" && reads = 5, "reject moving frame")
samples := ["SP: -100"]
reads := 0
Assert(OCR_ReadAfterInput([], 0, "SP", "", 0, 0, -100, 1) = "" && reads > 5 && reads <= 24, "bounded read-only wait on no movement")
samples := ["SP: -182.50", "SP: -182.50", "SP: -182.50", "SP: -182.50", "SP: -182.50", "SP: -172.50", "SP: -172.50"]
reads := 0
Assert(ParseOCR(OCR_ReadAfterInput([], 0, "SP", "", 0, 0, -182.5, 1), "SP") = -172.5 && reads = 7, "late first-jump render recovers without extra input")
samples := ["SP: 0", "SP: 0"]
reads := 0
Assert(ParseOCR(OCR_ReadAfterInput([], 0, "SP", "", 0, 0, -1, 1), "SP") = 0, "zero stable position")
OCR_ABORTED_RUNS[1] := true
reads := 0
Assert(OCR_ReadAfterInput([], 0, "SP", "", 0, 0, -1, 1) = "" && reads = 0, "physical abort before OCR")
OCR_ABORTED_RUNS := {}
OCR_RUN_DEADLINE := A_TickCount - 1
reads := 0
Assert(OCR_ReadAfterInput([], 0, "SP", "", 0, 0, -1, 1) = "" && reads = 0, "deadline before OCR")

; Exercise production drag control with mocked pointer I/O. No live cursor moves.
OCR_RUN_DEADLINE := A_TickCount + 10000
OCR_DRAG_STEP_PX := 12
OCR_DRAG_STEP_SLEEP := 0
OCR_DRAG_ENDPOINT_SLEEP := 0
ResetPointer()
motion := OCR_IncrementalDrag(2535, 743, 2535, -60, 1)
Assert(motion.ok && motion.steps = 67 && motion.finish.y = -60, "long local drag reaches exact endpoint")
Assert(buttonDown = 1 && buttonUp = 1, "normal drag releases button")
ResetPointer()
failMoveAt := 5
motion := OCR_IncrementalDrag(2535, 743, 2535, -60, 1)
Assert(!motion.ok && buttonDown = 1 && buttonUp = 1, "move failure releases button")
ResetPointer()
abortMoveAt := 5
motion := OCR_IncrementalDrag(2535, 743, 2535, -60, 1)
Assert(!motion.ok && buttonDown = 1 && buttonUp = 1, "manual cancellation releases button")
ResetPointer()
failMoveAt := 1
motion := OCR_IncrementalDrag(2535, 743, 2535, -60, 1)
Assert(!motion.ok && buttonDown = 0 && buttonUp = 0, "failed positioning never presses button")
ResetPointer()
throwMoveAt := 5
caught := false
try {
    OCR_IncrementalDrag(2535, 743, 2535, -60, 1)
} catch e {
    caught := true
}
Assert(caught && buttonDown = 1 && buttonUp = 1, "exception releases button")
ResetPointer()
badEndpoint := true
motion := OCR_IncrementalDrag(2535, 743, 2535, -60, 1)
Assert(!motion.ok && buttonUp = 1, "mismapped endpoint fails verification")
FileAppend, % "PASS: " checks " OCR reading, cancellation and drag checks`n", *
ExitApp, 0

ResetPointer() {
    global cursor, cursorReads, moves, buttonDown, buttonUp, failMoveAt, abortMoveAt, throwMoveAt, badEndpoint, OCR_ABORT_REQUESTED
    cursor := {x: 0, y: 0}
    cursorReads := moves := buttonDown := buttonUp := failMoveAt := abortMoveAt := throwMoveAt := 0
    badEndpoint := OCR_ABORT_REQUESTED := false
}
OCR_SetCursorPoint(x, y) {
    global cursor, moves, failMoveAt, abortMoveAt, throwMoveAt, OCR_ABORT_REQUESTED
    moves++
    if (moves = failMoveAt)
        return false
    if (moves = throwMoveAt)
        throw Exception("mock cursor failure")
    cursor := {x: x, y: y}
    if (moves = abortMoveAt)
        OCR_ABORT_REQUESTED := true
    return true
}
OCR_CursorPoint() {
    global cursor, cursorReads, badEndpoint
    cursorReads++
    result := cursor.Clone()
    if (badEndpoint && cursorReads > 1)
        result.x += 5
    return result
}
OCR_SendPointerClick(action) {
    global buttonDown, buttonUp
    if (action = "Down")
        buttonDown++
    else if (action = "Up")
        buttonUp++
}
OCR_ReadText(region, hwnd, mode) {
    global reads, samples
    reads++
    return samples[Min(reads, samples.Length())]
}
OCR_ReadTextDynamic(region, hwnd, mode, cacheId, clientW, clientH) {
    return OCR_ReadText(region, hwnd, mode)
}
OCR_LogStep(msg) {
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
$scrollFixture = '#Include ' + (Join-Path $PSScriptRoot 'OCR_ScrollMath.ahk') + "`r`n" + $scrollFixture
foreach ($scrollFunction in $scrollFunctions) {
    $scrollPattern = '(?m)^' + [regex]::Escape($scrollFunction) + '\([^\r\n]*\) \{[\s\S]*?^\}'
    $scrollMatch = [regex]::Match($scrollSource, $scrollPattern)
    if (-not $scrollMatch.Success) { throw "Cannot extract production function: $scrollFunction" }
    $scrollFixture += "`r`n`r`n" + $scrollMatch.Value
}
$scrollTemp = Join-Path ([System.IO.Path]::GetTempPath()) ('lungcad-scroll-test-' + [guid]::NewGuid().ToString('N') + '.ahk')
try {
    [System.IO.File]::WriteAllText($scrollTemp, $scrollFixture, [System.Text.UTF8Encoding]::new($true))
    & $scrollAhk /ErrorStdOut $scrollTemp | Out-String | Write-Output
    if ($LASTEXITCODE -ne 0) { throw "OCR reading tests failed: $LASTEXITCODE" }
} finally {
    if (Test-Path -LiteralPath $scrollTemp) { Remove-Item -LiteralPath $scrollTemp }
}
