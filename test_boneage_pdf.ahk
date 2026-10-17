#NoEnv
SetBatchLines, -1
SetWorkingDir, % A_ScriptDir

; Extract only the PDF functions, never the production GUI/auto-execute section.
; The generated worker uses its own hidden IPC window and a mocked browser.
FileRead, production, % A_ScriptDir "\boneage_CH.ahk"
start := InStr(production, "NormalizeBoneAgeGender(gender){")
finish := InStr(production, "#ifwinactive,Bone Age Report System", false, start)
pdfFunctions := SubStr(production, start, finish-start)
pdfFunctions := StrReplace(pdfFunctions, "CH_RIS_GUI", "BoneAgePdf_TEST_IPC")
pdfFunctions := StrReplace(pdfFunctions, "A_Desktop ""\bone_age.pdf""", "A_ScriptFullPath")
pdfFunctions := StrReplace(pdfFunctions, "global CH_RIS", "global CH_RIS, TestPdfMissing")
pdfFunctions := StrReplace(pdfFunctions, "if FileExist(path)", "if (!TestPdfMissing && FileExist(path))")
pdfFunctions := StrReplace(pdfFunctions, "static browser := new Chrome()", "global TestBrowser`n browser := TestBrowser")
worker := A_Temp "\boneage_pdf_test_" DllCall("GetCurrentProcessId") ".ahk"
source := "#NoEnv`n#Include " A_ScriptDir "\Lib`n#Include " A_ScriptDir "\Lib\Chrome.ahk`n"
    . "#Include " A_ScriptDir "\tests\boneage_pdf_cases.inc.ahk`n" pdfFunctions
FileAppend, % source, % worker, UTF-8
savedClipboard := ClipboardAll
RunWait, % """" A_AhkPath """ /ErrorStdOut """ worker """",, Hide UseErrorLevel
result := ErrorLevel
Clipboard := savedClipboard
FileDelete, % worker
ExitApp, % result
