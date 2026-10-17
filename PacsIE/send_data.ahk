#include <jxon>
send_data(app, data){
	global dwData, miniPACS_instances
	;~ ToolTip % app "`n" exploreobj(data)
	if(app="getAllJpeg"){
		if !(hwnd:=WinExist("getAllJpeg_main ahk_class AutoHotkeyGUI")){
			return
			run % "getAllJpeg.exe"
		}else{
			return Send_WM_COPYDATA(hwnd, dwData, jxon_dump(data))
		}
		return
		
	}else if(app="miniPACS"){
		if !(hwnd:=getListenerHwnd()){
			run % "miniPACS.exe " miniPACS_instances
		}else{
			return Send_WM_COPYDATA(hwnd, dwData, jxon_dump(data))
		}
	}else if (app="feedRIS"){
		if !(hwnd:=WinExist("ahk_exe feedRIS.exe")){
			run % "feedRIS.exe"
		}else{
			return Send_WM_COPYDATA(hwnd, dwData, jxon_dump(data))
		}
	}else if (app="decryptJpeg"){
		if !(hwnd:=WinExist("decryptJpeg_main ahk_class AutoHotkeyGUI")){
			run % "decryptJpeg.exe"
		}else{
			return Send_WM_COPYDATA(hwnd, dwData, jxon_dump(data))
		}
	}else{
		return
	}
	;~ else if (app="pyPortal"){
		;~ if !(hwnd:=getPyPortalHwnd()){
			;~ run % "pyPortal.exe"
		;~ }else{
			;~ return Send_WM_COPYDATA(hwnd, dwData, jxon_dump(data))
		;~ }
	;~ }
	;~ ToolTip % app ": " A_TickCount
	settimerF("send_data", -1000, [app, data])
	return -1
}

getListenerHwnd(){
	return WinExist("WM_COPYDATA_Listener_miniPACS")
	;~ if h1:=WinExist("WM_COPYDATA_Listener ahk_exe python.exe")
		;~ return h1
	;~ else if h2:=WinExist("WM_COPYDATA_Listener_miniPACS")
		;~ return h2
}