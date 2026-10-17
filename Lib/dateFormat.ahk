; ==============================================================================
; Library: dateFormat.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

dateFormat(inputDate, format="yyyyMMdd"){
	inputDate:=Trim(inputDate)
	if RegExMatch(inputDate, "^(\d{4})\W(\d\d?)\W(\d\d?)", m){
		inputDate:=m1 (StrLen(m2)=1?"0":"") m2 (StrLen(m3)=1?"0":"") m3 "000000"
		FormatTime,ret,% inputDate,% format
	}else if RegExMatch(inputDate, "^(\d\d?)\W(\d\d?)\W(\d{4})", m){
		inputDate:=m3 (StrLen(m1)=1?"0":"") m1 (StrLen(m2)=1?"0":"") m2 "000000"
		FormatTime,ret,% inputDate,% format
	}else if RegExMatch(inputDate, "^(\d\d)(\d\d)(\d\d)(\d\d)", m){
		inputDate:=SubStr(m1,1,2)>12? m1 m2 m3 m4 "000000": m3 m4 m1 m2 "000000"
		FormatTime,ret,% inputDate,% format
	}
	return ret
}
