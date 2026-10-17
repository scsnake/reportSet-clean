; ==============================================================================
; Library: HH_Announce.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

; HH_Announce.ahk -- tell a persistent Hotstring Helper which YCH variant is now
; "active." Sends WM_COPYDATA "activate\t<sourcePath>" to the
; "HotstringHelperMain" hidden window. Silent no-op if HH is not running.
;
; Callers:
;   autorun.ahk parse_commands (YCH/YXR/mamm/bmd) + #1::#4:: hotkeys
;   Lib\CH_RIS.ahk change_ahk() (exam-name → YCH switch)
;
; The script path passed here is the LIVE script (e.g., YCH_Enh.ahk or .exe).
; We strip the `_Enh` / `.exe` suffix so HH matches against the source name it
; was launched with (YCH.ahk).

#include <WM_COPYDATA>

HH_Announce(scriptPath) {
	if (scriptPath = "")
		return false
	SplitPath, scriptPath, fname
	if (fname = "")
		return false
	base := RegExReplace(fname, "i)\.(exe|ahk)$", "")
	base := RegExReplace(base, "i)_Enh$", "")
	; YCH_Mammo (capitalised in CH_RIS) → YCH_mammo (lowercased source basename)
	base := RegExReplace(base, "i)^YCH_Mammo$", "YCH_mammo")
	announcePath := base ".ahk"

	prev_dh := A_DetectHiddenWindows
	DetectHiddenWindows On
	hh := WinExist("HotstringHelperMain ahk_class AutoHotkeyGUI")
	DetectHiddenWindows %prev_dh%
	if !hh
		return false
	return Send_WM_COPYDATA(hh, 0x48485F31, "activate`t" announcePath)
}
