; ==============================================================================
; Library: OnScreenDisplay.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

OnScreenDisplay(str, DestroyAfter=1000, FontSize="50", FontColor="red", FontFamily="Verdana", xy_coord=""){
	global 
	local __OnScreenDisplayGuiHwnd, __OnScreenDisplayGui,which,monitorInfo,w,h,mon
	CoordMode,mouse,Screen
	which:=OnScreenDisplay_whichMonitor("","", monitorInfo)
	,mon:=monitorInfo[which.1]
	gui,__OnScreenDisplay:Default
	gui,destroy
	gui,Font,s%fontsize% c%fontColor%,%fontFamily%
	gui,Color,EEAA99
	gui,+ToolWindow -Border -Caption +hwnd__OnScreenDisplayGuiHwnd +lastfound
	WinSet, TransColor, EEAA99
	gui,Add,Text,,% str
	gui,Show,NA,__OnScreenDisplayGui
	
	WinGetPos,,,w,h,% "ahk_id " __OnScreenDisplayGuiHwnd
	WinMove,% "ahk_id " __OnScreenDisplayGuiHwnd,,% xy_coord?xy_coord[1]:Floor(mon.l+mon.w/2-w/2)
		,% xy_coord?xy_coord[2]: Floor(mon.t+mon.h/2-h/2)
	
	
	DllCall("SetWindowPos", "Ptr", __OnScreenDisplayGuiHwnd, "Ptr", 0, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	,DllCall("SetWindowPos", "Ptr", __OnScreenDisplayGuiHwnd, "Ptr", -1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	SetTimer,__CloseOnScreenDisplayGUI,% (-1) * DestroyAfter
	return
	
	__CloseOnScreenDisplayGUI:
	gui,__OnScreenDisplay:destroy
	SetTimer,__CloseOnScreenDisplayGUI,Off
	return

}
;~ Sleep 1000
;~ OnScreenDisplay("test", 400, 50, "white")
;~ Sleep 1000
;~ ExitApp

OnScreenDisplay_monitorInfo(){
	sysget,monitorCount,monitorCount
	arr:=[],sorted:=[]
	loop % monitorCount {
		sysget,mon,monitor,% a_index
		arr.push({l:monLeft,r:monRight,b:monBottom,t:monTop,w:monRight-monLeft+1,h:monBottom-monTop+1})
		k:=a_index
		while strlen(k)<3
			k:="0" k
		sorted[monLeft k]:=a_index
	}
	arr2:=[]
	for k,v in sorted
		arr2.push(arr[v])
	return arr2
}

/*
	return [current monitor, monitor count]
*/
OnScreenDisplay_whichMonitor(x="",y="",byref monitorInfo=""){
	CoordMode,mouse,screen
	if (x="" || y="")
		mousegetpos,x,y
	if !IsObject(monitorInfo)
		monitorInfo:=OnScreenDisplay_monitorInfo()
	
	for k,v in monitorInfo
		if (x>=v.l&&x<=v.r&&y>=v.t&&y<=v.b)
			return [k,monitorInfo.maxIndex()]
}