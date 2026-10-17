; ==============================================================================
; Library: DateDiff.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

DateDiff(date, refDate, AbsValue=true, unit="Days"){
	date-=refDate, %unit%
	return AbsValue?abs(date):date
}