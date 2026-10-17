; ==============================================================================
; Library: MonitorInfo.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

monitorInfo(){
	sysget,monitorCount,monitorCount
	arr:=[],sorted:=[]
	loop % monitorCount {
		sysget,mon,monitor,% a_index
		arr.push({l:monLeft,r:monRight,b:monBottom,t:monTop,w:monRight-monLeft+1,h:monBottom-monTop+1,ind: A_Index})
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
whichMonitor(x="",y="",byref monitorInfo=""){
	CoordMode,mouse,screen
	if (x="" || y="")
		mousegetpos,x,y
	if !IsObject(monitorInfo)
		monitorInfo:=monitorInfo()
	
	for k,v in monitorInfo
		if (x>=v.l&&x<=v.r&&y>=v.t&&y<=v.b)
			return [k,monitorInfo.maxIndex()]
}
