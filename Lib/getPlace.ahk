; ==============================================================================
; Library: getPlace.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

#include <CH_RIS>
getPlace(){
	global CH_RIS, __is_CH,__is_N, __win11__, __CH_RIS_CLIENT

	__win11__ := (RegExMatch(A_OSVersion, "10\.0\.(\d+)", build) && build1 >= 22000)

	FileExist(root_dir := A_MyDocuments "\reportSet") || FileExist(root_dir := A_MyDocuments "\reportSetCH")

	place_info := root_dir "\place"
	if !FileExist(place_info){
		if (A_UserName="C hospital"){
			p:="C hospital", __is_CH:=true
		}else{
			p:="N hospital", __is_N:=true
		}

		FileAppend,% p,% place_info,utf-8-Raw

	}else{
		fileread,p,% place_info

	}

	if InStr(p, "C hospital"){
		__is_CH:=true
		; A script that sets __CH_RIS_CLIENT before getPlace() opts out of owning a
		; local (IE-polling) CH_RIS: it gets a lightweight proxy that forwards report
		; operations to the autorun owner over IPC (see Lib\CH_RIS_Client.ahk).
		; Default (flag unset) is unchanged: create a local owner as before.
		; NOTE: the proxy factory is called DYNAMICALLY (%fn%()). getPlace is auto-included
		; by scripts that don't pull in CH_RIS_Client (e.g. RisHorosSync includes <CH_RIS>
		; only); a direct call would be an AHK load-time "nonexistent function" error there,
		; even though guarded by IsFunc. Dynamic calls resolve at runtime, so IsFunc applies.
		if !CH_RIS {
			if (__CH_RIS_CLIENT && IsFunc(__mkProxy:="CH_RIS_Client_MakeProxy"))
				CH_RIS:=%__mkProxy%()
			else if !__CH_RIS_CLIENT
				CH_RIS:=new CH_RIS_REPORT()
		}
	}
	if InStr(p, "N hospital")
		__is_N:=true

	return p
}