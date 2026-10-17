; FixTaskbar.ahk
; Win+Alt+T to restart explorer.exe
#!t::
MsgBox, 4, Restart Explorer?, Do you want to restart Windows Explorer?
IfMsgBox, Yes
{
    Run, taskkill /f /im explorer.exe,, Hide
    Sleep, 1000
    Run, explorer.exe
}
return