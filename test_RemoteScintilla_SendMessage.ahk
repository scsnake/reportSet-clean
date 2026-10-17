#NoEnv
#include <RemoteScintilla>
; A null HWND cannot modify any live editor. Exercise the WinAPI signature.
sci := {base: RemoteScintilla, hwnd: 0}
try {
    sci.ClearAll()
    sci.SelAll()
    sci.ScrollCaret()
    sci.GetSelectionStart()
    sci.GetSelectionEnd()
    sci.GetCurrentPos()
    sci.GetAnchor()
    sci.GetLineCount()
    sci._GetSelectionStart("x")
    sci._GetSelectionEnd("x")
    sci._GetCurrentPos("x")
    sci._GetAnchor("x")
    sci.LineLength(0)
    sci.LineFromPosition(0)
    sci.SetSelectionStart(0)
    sci.SetSelectionEnd(0)
    sci.SetCurrentPos(0)
    sci.SetAnchor(0)
    sci._SetSelectionStart(0, "x")
    sci._SetSelectionEnd(0, "x")
    sci._SetCurrentPos(0, "x")
    sci._SetAnchor(0, "x")
    sci.SetCodePage(65001)
    sci.GetCodePage()
    sci.SetCaretStyle(1)
    sci.GetCaretStyle()
    sci.DelLine()
    sci.Do(2004)
    if ErrorLevel
        throw Exception("Do() DllCall failed", -1, ErrorLevel)
    FileAppend, PASS: 28 SendMessage wrappers (null HWND; no live report modified)`n, *
    ExitApp, 0
} catch err {
    FileAppend, % "FAIL: " err.Message " | " err.Extra " | line " err.Line "`n", *
    ExitApp, 1
}
