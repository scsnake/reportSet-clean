; notify.ahk — Windows tray notification helper
; Usage: AutoHotkey.exe notify.ahk "Title" "Message" [durationSec=5]

title := A_Args[1] ? A_Args[1] : "Claude Code"
msg := A_Args[2] ? A_Args[2] : "Done"
duration := A_Args[3] ? A_Args[3] : 5

TrayTip, %title%, %msg%, %duration%
ExitApp
