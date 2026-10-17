#NoEnv
#SingleInstance,force
SetBatchLines,-1
DetectHiddenWindows, On
SetTitleMatchMode,2
coordmode,mouse,screen
coordmode,pixel,screen
#NoTrayIcon
#Persistent
; Does not use CH_RIS — opt out of owning a local (IE-polling) CH_RIS. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <WM_COPYDATA>
#include <RisImpax>
#include <jxon>
;~ #include <DoublyLinkedList>

SetTimer,exit,3000
;~ OnMessage(0x4a, "ON_WM_COPYDATA")
OnMessage(0x10102, "getEBMSquareLocEvent")

GroupAdd,EBM,ahk_exe WebViewerComSrvEC.exe
GroupAdd,EBM,ahk_exe WEBVIE~1.EXE

gui,+hwndguihwnd
WinSetTitle,ahk_id %guihwnd%,,% "getEBMSquareLoc_main"


monitors:=monitorinfo()

,getEBMSquareLocFn:=Func("getEBMSquareLoc")
,EBMSquareLocXY:=[] ; whichMon [ [x1,y1], [x2,y2] ]
;~ ,EBMSquareLocXYQueue:=[]
for k,v in monitors
	EBMSquareLocXY[k]:=[]
	;~ ,EBMSquareLocXYQueue[k]:=new Queue
getEBMSquareLoc()

return

getEBMSquareLocEvent(){
	SetTimer,getEBMSquareLoc,-1
}

getEBMSquareLoc(){
	global monitors, getEBMSquareLocFn, EBMSquareLocXY, EBMSquareLocXYQueue, __lbuttondown, psquare
	
	;~ if (__lbuttondown || !winexist("ahk_group EBM"))
		;~ goto getEBMSquareLocReturn2
	winget,list,list,ahk_group EBM
	if !(list){
		;~ goto getEBMSquareLocReturn2
		SetTimer,% getEBMSquareLocFn,% -10000,-1
		return
	}
	
	_EBMSquareLocXY:=[]
	for k, mon in monitors {
		;~ _EBMSquareLocXY[k]:=[]
		if(psquare!=2){
			image:=A_ScriptDir "\square.png"
			,res:=SearchImage(mon.l,mon.t,mon.r,mon.b, image, "*10")
			if(res.length())
				psquare:=1
		}
		if(psquare!=1){
			image:=A_ScriptDir "\square2.png"
			,res:=SearchImage(mon.l,mon.t,mon.r,mon.b, image, "*10")
			if(res.length())
				psquare:=2
		}
		_EBMSquareLocXY[k]:=res.length()?res:EBMSquareLocXY[k]
	}
	EBMSquareLocXY:=_EBMSquareLocXY
	;~ if(pimx && pimy &&  whichMon=whichMonitor(pimx, pimy)[1] && psquare=1){
		;~ ImageSearch,cimx,cimy,% pimx-50,% pimy-50,% pimx+50,% pimy+50,*10 %a_scriptdir%\square.png
		;~ if (!ErrorLevel){
			;~ pimx:=imx:=cimx, pimy:=imy:=cimy
			;~ goto getEBMSquareLocReturn
		;~ }
			
	;~ }
	;~ if(pimx && pimy &&  whichMon=whichMonitor(pimx, pimy)[1] && psquare=2){
		;~ ImageSearch,cimx,cimy,% pimx-50,% pimy-50,% pimx+50,% pimy+50,*10 %a_scriptdir%\square2.png
		;~ if (!ErrorLevel){
			;~ pimx:=imx:=cimx, pimy:=imy:=cimy
			;~ goto getEBMSquareLocReturn
		;~ }
	;~ }
	;~ ImageSearch,cimx,cimy,% mon.l,% mon.t,% mon.r,% mon.b,*10 %a_scriptdir%\square.png
	;~ if (!ErrorLevel){
		;~ pimx:=imx:=cimx, pimy:=imy:=cimy, psquare:=1
		;~ goto getEBMSquareLocReturn
	;~ }
	;~ ImageSearch,cimx,cimy,% mon.l,% mon.t,% mon.r,% mon.b,*10 %a_scriptdir%\square2.png
	;~ if (!ErrorLevel){
		;~ pimx:=imx:=cimx, pimy:=imy:=cimy, psquare:=2
		;~ goto getEBMSquareLocReturn
	;~ }
getEBMSquareLocReturn:	
	SetTimer,getEBMSquareLocXYQueueRefresh,-1
getEBMSquareLocReturn2:		
	SetTimer,% getEBMSquareLocFn,% (cpul:=CPULoad())>70?-1000:cpul>50?-400:-100,-1
	return
}

getEBMSquareLocXYQueueRefresh(){
	global EBMSquareLocXY, EBMSquareLocXYQueue
	
	Send_WM_COPYDATA(WinExist("RazerNaga_main ahk_class AutoHotkeyGUI"), 19
		, jxon_dump({EBMSquareLocXY: EBMSquareLocXY}))
	
	return
	for k, LocXYs in EBMSquareLocXY {
		while EBMSquareLocXYQueue[k].length>10
			EBMSquareLocXYQueue[k].dequeue()
		;~ for _, LocXY_ in LocXYs
			;~ EBMSquareLocXYQueue[k].enqueue(LocXY_)
		EBMSquareLocXYQueue[k].fromArray(LocXYs)
	}
}



exit:
if !WinExist("RazerNaga_main ahk_class AutoHotkeyGUI")
	ExitApp
return



On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
	global newX,newY,frame
; dwData = Command
; cbData = String lenght
; lpData = String
	dwData := NumGet(lParam+0, 0)
	,cbData := NumGet(lParam + A_PtrSize)
	,lpData := NumGet(lParam + 2*A_PtrSize)
	,str := StrGet(lpData)
	
	;~ str:=lpData
	
	If  (dwData = 19) ; CMD_CURRENTPOSITION
	{
		

	}
}

