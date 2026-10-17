; CH_RIS_ping.ahk — diagnostic probe for the single-owner CH_RIS IPC bridge.
; Client-only: it does NOT create a CH_RIS owner or touch IE. Safe to run anytime.
; Finds the autorun-hosted CH_RIS_SERVER window and pings it. Result -> tooltip + temp file.
#NoEnv
#SingleInstance Off
SetBatchLines, -1
DetectHiddenWindows, On
#include <CH_RIS_Client>

out := ""
h := CH_RIS_Server_Hwnd()
if !h {
    out := "CH_RIS_SERVER: NOT FOUND (owner not running new code, or not at C hospital)"
} else {
    p := CH_Ping()
    if (p.ok) {
        out := "CH_RIS_SERVER: OK  hwnd=" h "  owner_pid=" p.owner_pid "`n"
        s := CH_GetState()
        if IsObject(s)
            out .= "  accNo=" s.accNo "  chartNo=" s.chartNo "  examname=" s.examname "  examtime=" s.examtime
        else
            out .= "  get_state returned empty"
    } else {
        out := "CH_RIS_SERVER: window found (hwnd=" h ") but ping FAILED: " p.error
    }
}
out .= "`n@ " A_Hour ":" A_Min ":" A_Sec
FileDelete, % A_Temp "\ch_ris_ping.txt"
FileAppend, % out "`n", % A_Temp "\ch_ris_ping.txt", UTF-8
ToolTip, % out
Sleep, 2500
ExitApp
