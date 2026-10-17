$ErrorActionPreference = 'Stop'
$source = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'YCH_mammo_Enh.ahk') -Raw -Encoding UTF8
$toggle = [regex]::Match($source, '(?ms)^Mammo_ToggleSimpleRisIndication\(.*?(?=^Mammo_RequestSimpleRisIndicationToggle\()').Value
if (-not $toggle) { throw 'Cannot find production indication toggle' }
$harness = @'
#NoEnv
#Include <Edit>
DetectHiddenWindows, On
global __is_CH := true, __is_N := false
Gui, Test:New, +hwndguiHwnd +ToolWindow
Check(DllCall("LoadLibrary", "Str", A_ScriptDir "\SciLexer.dll", "Ptr"), "load Scintilla")
editor := DllCall("CreateWindowEx", "UInt", 0, "Str", "Scintilla", "Str", "", "UInt", 0x40000000, "Int", 0, "Int", 0, "Int", 400, "Int", 200, "Ptr", guiHwnd, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
Check(editor, "create isolated editor")
DllCall("SendMessage", "Ptr", editor, "UInt", 2037, "Ptr", 65001, "Ptr", 0, "Ptr")
body := "COMPARISON: no prior mammograms.`r`nMAMMOGRAPHY VIEWS: right MLO/CC.`r`nFINDINGS:`r`n- 中文測試 density (2).`r`nImpression: BI-RADS 2."
original := "INDICATION: screening mammography.`r`n" body
Edit_SetText(editor, original)
Check(Edit_GetText(editor) == original, "real Scintilla text round trip")
Check(Mammo_ToggleSimpleRisIndication([editor, editor]), "toggle returns success")
Check(Edit_GetText(editor) == "INDICATION: diagnostic mammography.`r`n" body, "screening becomes diagnostic without changing report")
Check(Mammo_ToggleSimpleRisIndication([editor, editor]), "second toggle returns success")
Check(Edit_GetText(editor) == original, "second toggle restores screening")
Loop, 40 {
    Check(Mammo_ToggleSimpleRisIndication([editor, editor]), "repeated toggle")
}
Check(Edit_GetText(editor) == original, "repeated toggles preserve Unicode and impression")
Edit_SetText(editor, "INDICATION: prior biopsy.`r`n" body)
Check(Mammo_ToggleSimpleRisIndication([editor, editor]), "custom indication can be replaced")
Check(Edit_GetText(editor) == original, "custom indication becomes screening without changing body")
Edit_SetText(editor, body)
Check(Mammo_ToggleSimpleRisIndication([editor, editor]), "missing indication can be inserted")
Check(Edit_GetText(editor) == original, "missing indication inserted without changing body")
DllCall("SendMessage", "Ptr", editor, "UInt", 2171, "Ptr", 1, "Ptr", 0, "Ptr")
Check(!Mammo_ToggleSimpleRisIndication([editor, editor]), "read-only editor never reports a successful edit")
Check(Edit_GetText(editor) == original, "read-only editor preserves report")
Gui, Test:Destroy
Check(!Mammo_ToggleSimpleRisIndication([editor, editor]), "closed editor rejected")
FileAppend, PASS: real Scintilla indication toggle and repeated Unicode edits (no live RIS calls)`n, *
ExitApp, 0
Check(ok, label) {
    if !ok {
        FileAppend, % "FAIL: " label "`n", *
        ExitApp, 1
    }
}
Mammo_SimpleRisHotkeyEditHwnds() {
    return []
}
'@
$testPath = Join-Path $PSScriptRoot ('.mammo_editor_' + [guid]::NewGuid().ToString('N') + '.ahk')
try {
    [IO.File]::WriteAllText($testPath, $harness + "`r`n" + $toggle, [Text.UTF8Encoding]::new($true))
    & (Join-Path $PSScriptRoot 'AutoHotkey.exe') /ErrorStdOut $testPath | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Editor test failed: $LASTEXITCODE" }
} finally {
    Remove-Item -LiteralPath $testPath -ErrorAction SilentlyContinue
}
