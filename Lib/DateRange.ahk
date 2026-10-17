; ==============================================================================
; Library: DateRange.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

; range: 20190101-1231 (omit year or month if same as start date)
;  or single date 0301 (omit year or month if same as a_now)
; or range with specified days: 20190101 to 6 days after
DateRange(str, Days=0, omitYear="", omitMonth=""){
	if RegExMatch(str, "^(\d+)-(\d+)$", m){
		startDate:=%A_ThisFunc%(m1,0)
		,Enddate:=%a_thisfunc%(m2,0,SubStr(startDate,1,4), SubStr(startDate,5,2))
		return [startDate, Enddate]
		
	}
	
	if(omitYear="")
		omitYear:=A_YYYY
	if(omitMonth="")
		omitMonth:=A_MM
	
	if StrLen(str)<=2
		str:=Format("{:04}{:02}{:02}",omitYear, omitMonth, str)
	else if StrLen(str)<=4
		str:=Format("{:04}{:04}",omitYear, str)
		,str:=DateDiff(str,SubStr(a_now,1,8),false)>0?(SubStr(str,1,4)-1) SubStr(str,5):str
	else if StrLen(str)<=6
		str:=Format("{}{:06}",SubStr(omitYear,1,2), str)
	
	
	if Days=0
		return str
	
	EndDate:=str
	EndDate+=Days,Days
	return [str, SubStr(Enddate,1,8)]
	
}

;~ MsgBox % exploreobj(DateRange("0701"))
;~ ExitApp 