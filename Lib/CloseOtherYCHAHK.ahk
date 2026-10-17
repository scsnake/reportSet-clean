CloseOtherYCHAHK(callerTitle=""){
	DetectHiddenWindows,on
	thisPid := DllCall("GetCurrentProcessId")

	for k,v in ["YCH_AHK_main","YCH_MAMMO_AHK_main","YCH_XR_main","YCH_BMD_main"]
	{
		if !(h:=WinExist(v " ahk_class AutoHotkeyGUI"))
			continue
		if ((pid:=WinGet("PID", h))!=thisPid){
			PostMessage,0x10101,,,,% "ahk_id " h
			TaskKill(pid)
		}
	}

	if (callerTitle != "YCH_AHK_main") {
		if (h := WinExist("showLungCAD_main ahk_class AutoHotkeyGUI")) {
			pid := WinGet("PID", h)
			PostMessage,0x10101,,,,% "ahk_id " h
			TaskKill(pid)
		}
		if (h := WinExist("C:\Users\raduser\Documents\reportSet\showLungCAD.ahk ahk_class AutoHotkey")) {
			pid := WinGet("PID", h)
			PostMessage,0x10101,,,,% "ahk_id " h
			TaskKill(pid)
		}
	}
}
