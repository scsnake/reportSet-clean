SetTitleMatchMode, 2
DetectHiddenWindows, On
WinGet, list, List, ahk_exe G3PACS.exe
Loop, %list%
{
    hwnd := list%A_Index%
    WinGet, controls, ControlList, ahk_id %hwnd%
    Loop, Parse, controls, `n
    {
        if (InStr(A_LoopField, "AfxWnd140u")) {
            ControlGetText, txt, %A_LoopField%, ahk_id %hwnd%
            if (txt != "") {
                FileAppend, %A_LoopField%: %txt%`n, *
            }
        }
    }
}
