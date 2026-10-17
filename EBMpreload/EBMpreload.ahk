#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
SetBatchLines, -1
coordMode,mouse,screen
CoordMode,caret,screen
DetectHiddenWindows,on
SetTitleMatchMode,2
SetControlDelay,-1
comobjerror(false)
onexit,onexit
;~ #NoTrayIcon
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <PortalLib>
#include <EBMViewer>
#include <WindowShellEvent>
process,priority,,h
#InstallKeybdHook
;~ #InstallMouseHook
;~ WindowShellEvent("ShellProc")

;~ h_id:="H00000"
;~ Y_id:="Y00000"
;~ h_pw:=Y_pw:="MOCK_PASSWORD"

;~ loadKey:="F6"
;~ nextKey:="F3,F2,F1"

args:=ParseArg()
if RegExMatch(args[1], "i)([\w\d]{7})_(\w{10}\d)", m) {
	arg_chartno:=m1, arg_accNo:=m2, HiddenMode:=true
}

OnMessage(0x2020, "load")
,OnMessage(0x2021, "forceLoad")
,WindowShellEvent("ShellMessage")
,shellHook:=true
,monitors:=monitorInfo()
if (!HiddenMode)
	RISImpaxRegister([  {app: "Ris", type: "State", hwnd: thisHwnd, msg: {msg: 0x8000}, func: "RisStateChange", initStart: 1}
		, {app: "Ris", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x1122}, func: "accNoChanged", initStart: 100}])
else
	RisStateChange()
;~ gosub CloseHiddenIEs
GroupAdd,EBM,ahk_exe WEBVIE~1.exe
GroupAdd,EBM,ahk_exe WebViewerComSrvEC.exe
try
	run,% "..\EBMhelper\EBMhelper.exe",% "..\EBMhelper",hide

gosub readIni

;~ if (!HiddenMode){
Gui,+hwndguihwnd  +ToolWindow
gui,Font,s12,Verdana
gui,Add,button,gload,Open Study
gui,Add,button,gclose,Close All
gui,Show,NoActivate Center x-500 y-500,EBM Preload
WinGetPos,x,y,w,h,ahk_id %guihwnd%
WinMove,ahk_id %guihwnd%,,% A_ScreenWidth-w,% 30
gui,+AlwaysOnTop
	
;~ }else{
	;~ settimer,waitPwbClose,1000
;~ }


;~ DllCall( "RegisterShellHookWindow", UPtr,guihwnd) 
;~ MsgNum := DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" ) 
;~ OnMessage( MsgNum, "ShellMessage" ) 

garbage:=[]
gosub sethotkey
settimer,sethotkey,30000
HPwbTimeout:=YPwbTimeout:=ZDPwbTimeout:=true
settimer,refreshPwb,600000
settimer,logoutHint,1000

AllEBMV:=[]
settimer,monitorEBMV,500

if(HiddenMode){
	shellHook:=false
	,openNextEBM(cAccNo:=arg_accNo, cChartNo:=arg_chartno)
}
;~ debug:=true
;~ settimer,debugHpwb,1000
return 

debugHpwb:
ToolTip % WinExist("ahk_id " hpwb.hwnd)
return

monitorEBMV(){
	global AllEBMV, monitors
	winget,list,list,ahk_group EBM
	loop % list {
		h:=list%a_index%
		WinGetPos,x,y,w,h,ahk_id %h%
		if (x+w/2>=monitors[1].l && x+w/2<=monitors[1].r && y+h/2>=monitors[1].t && y+h/2<=monitors[1].b)
			continue
		wingettitle,t,ahk_id %h%
		if ((_:=isChartNo(t)).pacsViewer="EBM") && (chartNo:=_.chartNo) {
			if(AllEBMV.haskey(chartNo) && AllEBMV[chartNo]!=h && WinExist("ahk_id " AllEBMV[chartNo])){
				WinClose,ahk_id %h%
			}else
				AllEBMV[chartNo]:=h
		}
	}
	for k,v in AllEBMV
		if !winexist("ahk_id " v)
			AllEBMV.delete(k)
}


ShellMessage( wParam,lParam ) { 
	global shellHook, cChartNo, lastEBMhwnd, activeId, activatePriorTick, monitors
	if !shellHook || getkeystate("Shift")
		return
	
  If ( wParam=1 ) {
	winget,activeId,id,A
	WinGetTitle,t,ahk_id %lParam%
	WinGet,pName,ProcessName,ahk_id %lParam%
	WinGetPos,x,y,w,h,ahk_id %lParam%
	if InStr(t, "UniWeb") && (pName~="i)WEBVIE~1.exe|WebViewerComSrvEC.exe") {
		
		ShowToolTip("New EBM opened!",1000)
		
		if (h:=WinExist(cChartNo " ahk_group EBM")){
			if !winvisible(h)
				WinShow,ahk_id %h%
		}
		
		lst:=0
		winget,list,list,ahk_group EBM
		Loop % list {
			if isChartNo(WinGetTitle(list%a_index%)).pacsViewer="EBM"
				lst+=1
		}
		if(lst=0)
			return

		
		if !(x+w/2>=monitors[1].l && x+w/2<=monitors[1].r && y+h/2>=monitors[1].t && y+h/2<=monitors[1].b){
			settimer,checkCurrentEBM,500
			WinHide,ahk_id %lParam%
		}
		
		;~ activatePriorTick:=a_tickcount
		;~ settimer,activatePrior,-100
	}
		
  }
} 


checkCurrentEBM(){
	global cChartNo
	if (h:=WinExist(cChartNo " ahk_group EBM")) && !winvisible(h) {
		WinShow,ahk_id %h%
		winactivate,ahk_id %h%
		settimer,checkCurrentEBM,Off
	}
}

activatePrior:
if(a_tickcount-activatePriorTick > 5000)
	return
if winactive(nextChartNo " ahk_group EBM")  {
	winactivate,ahk_id %activeId%
	winhide,nextChartNo " ahk_group EBM"
}	
settimer,,-100
return


waitPwbClose:
return

CloseHiddenIEs:
closing:=true
winget,ielist,list,分院 MainPACS ahk_exe iexplore.exe
Loop % ielist
	if !winvisible(h:=ielist%a_index%) || 1
		WinClose,ahk_id %h%	
winget,ielist,list,分院 UniWeb ahk_exe iexplore.exe
Loop % ielist
	if !winvisible(h:=ielist%a_index%) || 1
		WinClose,ahk_id %h%	
return
Close:
closing:=true
settimer,waitLoadNext,Off
gosub CloseHiddenIEs
WinClose,ahk_group EBM
WinKill,ahk_group EBM
Run, %comspec% /c "taskkill /F /T /IM WEBVIE~1.exe",,Hide
Run, %comspec% /c "taskkill /F /T /IM WebViewerComSrvEC.exe",,Hide
winget,list,list,ahk_group EBM
Loop % list
{
	winget,pid,pid,% "ahk_id " list%a_index%
	Run, %comspec% /c "taskkill /F /T /PID " pid,,Hide
}
closing:=false
return

GuiClose:
gui,-AlwaysOnTop
MsgBox,4,,Exit?
IfMsgBox,Yes
	ExitApp
gui,+AlwaysOnTop
return


readIni:
ini:=A_ScriptDir "\EBMpreload.ini"
;~ IniRead,h_id,% ini,Settings,h_id
;~ IniRead,y_id,% ini,Settings,y_id
;~ IniRead,h_pw,% ini,Settings,h_pw
;~ IniRead,y_pw,% ini,Settings,y_pw
IniRead,loadKey,% ini,Settings,load
IniRead,nextKey,% ini,Settings,next
IniRead,hospitals,% ini,Settings,hospitals,% "H,Y"
vars:={"H": "H branch", "Y": "Y branch"}
Loop,parse,hospitals,`,
	if StrLen(askforportalidpw(0,true,A_LoopField, false))>2
		var:=vars[A_LoopField]
		,%var%_id:=loginId
		,%var%_pw:=loginPw
		,loginId:=loginPw:=""
		,%var%_info_ok:=true
return

sethotkey:
Hotkey,IfWinActive,ahk_exe Menu.exe
Hotkey,% loadKey,load,on
;~ Loop,parse,nextKey,`,
	;~ Hotkey,% "~*" A_LoopField,next,on
Hotkey,IfWinActive
return

logoutHint:
IfWinExist,ahk_class TLoginForm ahk_group EBM
{
	WinClose,ahk_class TLoginForm ahk_group EBM
	gosub refreshPwb
	settimer,refreshPwb,600000
}
IfWinExist,COM Server Warning
	ControlClick,Button1,COM Server Warning
return

load(){
	global debug
	;~ loading:=false
	if debug
		MsgBox load fn
	load_force:=false
	settimer,waitLoadNext,Off
	gosub load
}

forceLoad(){
	global 
	if debug
		MsgBox forceLoad
	settimer,waitLoadNext,Off
	stopWinWait:=true
	,loading:=false
	,load_force:=true
	,breakEBMquery:=true
	gosub load
}

reset_loading:
loading:=false
return

load:
ShiftDown:=GetKeyState("Shift")
load1:

if loading
	return

loading:=true
settimer,reset_loading,-120000
;~ AllRis:=risopened(1)
WinGetTitle,t,% "ahk_id " targetRis:=risopened(1)[2,1]
RisTitle:=t
winactivate,% "ahk_id " targetRis
cChartNo:=getRisChartNo(targetRis)
if(cChartNo=""){
	settimer,load,-10000
	return
}
if (cChartNo~="i)^\D") || instr(t,"HC") || ShiftDown || WinExist(cChartNo " ahk_group EBM") {
	;~ cChartNo:=getRisChartNo(targetRis)
	cAccNo:=getRisAccNo(targetRis)
	if (pChartNo) && (pChartNo!=cChartNo)
		WinClose, % pChartNo " ahk_group EBM"
	
	pChartNo:=cChartNo
	,previousOpened:=false
	
	,examDate:=getRisExamDate(targetRis)
	if h:=WinExist(cChartNo " ahk_group EBM") {
		WinShow,ahk_id %h%		
		WinActivate,ahk_id %h%
		previousOpened:=true
		,thisEBMViewer:=new EBMViewer(cChartNo)
		WinGetTitle,t,ahk_id %h%
		if !InStr(t, SubStr(examDate,1,10)) 
			MsgBox % "Exam date not match!"
	}else{
		;~ ShowToolTip(cChartNo " not open")
		if (ShiftDown){
			
			risOpenStudyImpax(targetRis)
			;~ openNextEBM(cAccNo, cChartNo)
			
			if __winwait(cChartNo " ahk_group EBM",5){
				ShowToolTip(cChartNo " failed to open!", 3000)
				return 
			}
				
			
			thisEBMViewer:=new EBMViewer(cChartNo)
		}else{
			;~ SetTimerFn("openNextEBM", -1, [cAccNo, cChartNo])
			Loop 3 {
				openNextEBM(cAccNo, cChartNo)
				if !__winwait(cChartNo " ahk_group EBM",5)
					break
			}
			if !WinExist(cChartNo " ahk_group EBM"){
				ShowToolTip(cChartNo " failed to open!", 3000)
				return
			}
				
			thisEBMViewer:=new EBMViewer(cChartNo)
			;~ settimer,load1,-30000
			settimer,waitLoadNext,500
			loading:=false
			;~ return
		}
	}
	
	;~ if loginPw=
		;~ askForPortalIdPw()
	
		;~ ,HPwb.Visible:=true
	;~ result:=ParseDataGrid2(getRisList(targetRis))
	compareList(result, RisListAcc, RisListHwnd)
	
	,r:=result.getRow("AccNo", cAccNo)
	,nextAccNo:="", nextnextAccNo:=""
	if(r.rowNo){
		Loop % (result.maxIndex()-r.rowNo) {
			nextRow:=r.rowNo+A_Index
			,row:=result.getRow(nextRow)
			if (nextAccNo="" && row.getCell("Status")!="已發報告" && row.getCell("ChartNo")!=cChartNo &&  isChartNo(row.getCell("ChartNo")).pacsViewer="EBM" && !(row.getCell("ExamName")~="i)^(Request|Offer)")){
				nextAccNo:=row.getCell("AccNo"), nextChartNo:=row.getCell("ChartNo")
				break
				;~ continue
			}
			;~ if (nextAccNo!="" && row.getCell("Status")!="已發報告" && row.getCell("ChartNo")!=cChartNo && row.getCell("ChartNo")!=nextAccNo) {
				;~ nextnextAccNo:=row.getCell("AccNo"), nextnextChartNo:=row.getCell("ChartNo")
				;~ break
			;~ }
		}
	}
	
	if(nextAccNo){
		if !WinExist(nextChartNo " ahk_group EBM")
			settimer,waitLoadNext,500
			;~ SetTimerFn("openNextEBM",previousOpened?-1:-60000, [nextAccNo, nextChartNo])
			;~ if (nextnextAccNo)
				;~ SetTimerFn("presearchEBM", -45000, [nextnextAccNo, nextnextChartNo])
		else {
			WinHide,% nextChartNo " ahk_group EBM"
			;~ winactivate,% nextChartNo " ahk_group EBM"
			WinShow,% cChartNo " ahk_group EBM"
			winactivate,% cChartNo " ahk_group EBM"
		}
			
	}
	
}else{
	MsgBox % "Hold shift to open " cChartNo " by EBM"
	if GetKeyState("Shift") {
		ShiftDown:=true, loading:=false
		goto load1
	}
}
loading:=false
return 

next:
if nextAccNo && WinExist(nextChartNo " ahk_group EBM") {
	WinShow,% nextChartNo " ahk_group EBM"
	winactivate,% nextChartNo " ahk_group EBM"
}
settimer,load,-2000
return

;~ presearchEBM(accNo, chartNo){
	;~ return openNextEBM(accNo, chartNo, 0, true)
;~ }

waitLoadNext:
;~ tooltip % a_tickcount "," thisEBMViewer.isHidden() "," thisEBMViewer.isLoading() "`n" nextChartNo
if !load_force
{
	if !thisEBMViewer || !thisEBMViewer.Exists()
		thisEBMViewer:=new EBMViewer(cChartNo)
	if thisEBMViewer.isHidden()
		return
	if thisEBMViewer.isLoading()
		return
}else{
	load_force:=false
}
openNextEBM(nextAccNo, nextChartNo)
settimer,waitLoadNext,Off
return

openNextEBM(nextAccNo, nextChartNo, tried=0, presearch=false){
	global HPwb, YPwb, cAccNo, cChartNo, h_id, h_pw, refreshing, y_id, y_pw,HPwbTimeout,YPwbTimeout, garbage, h_info_ok, y_info_ok, HiddenMode, ZDPwb, ZDPwbTimeout, breakEBMquery, debug, YPwb2, load_force, RisTitle
	
	
	if WinExist(nextChartNo " ahk_group EBM")
		return
	
	if (!presearch){
		ToolTip % "Opening: " nextChartNo " (" nextAccNo ")"
		KeyWait,LCtrl,T2 D
		if (!ErrorLevel){
			ToolTip 
			SetTimerFn("openNextEBM", -15000, [nextAccNo, nextChartNo, tried, presearch])
			return 
		}
			
	}
		
	
	;~ winget,EBM_count,list,ahk_group EBM 
	;~ EBM_win:="`n"
	;~ Loop % EBM_count
		;~ EBM_win.=EBM_count%a_index% "`n"
	
	priorActiveSimpleRis:=WinActive("simple RIS ahk_class AutoHotkeyGUI")
	
	if (isChartNo(nextChartNo)._value~="T4|T6") || instr(RisTitle,"HC") && h_info_ok {
		if !WinExist("ahk_id " HPwb.hwnd) || HPwbTimeout
			garbage.push(HPwb.hwnd)
			,HPwb:=EBMWebPacsLogin_IE(h_id, h_pw, "HC")
			
			,HPwbTimeout:=false
			,HPwb.Visible:=!!HiddenMode || debug
		HPwb.Visible:= debug
		thisPwb:=HPwb

	}else if (nextChartNo~="i)^C") && h_info_ok {
		if !WinExist("ahk_id " ZDPwb.hwnd) || ZDPwbTimeout
			garbage.push(ZDPwb.hwnd)
			,ZDPwb:=EBMWebPacsLogin_IE(h_id, h_pw, "ZD")
			
			,ZDPwbTimeout:=false
			,ZDPwb.Visible:=!!HiddenMode || debug
		ZDPwb.Visible:=debug
		thisPwb:=ZDPwb

	}else if SubStr(nextChartNo,1,1)="Y" && y_info_ok  {
		if !WinExist("ahk_id " YPwb.hwnd) || YPwbTimeout
			garbage.push(YPwb.hwnd)
			,YPwb:=EBMWebPacsLogin_IE(y_id, y_pw, "YL")
			
			,YPwbTimeout:=false,
		if !WinExist("ahk_id " YPwb2.hwnd) || YPwbTimeout
			garbage.push(YPwb2.hwnd)
			,YPwb2:=EBMWebPacsLogin_IE(y_id, y_pw, "YL")
			
			,YPwb.Visible:=!!HiddenMode || debug	
			,YPwb2.Visible:=!!HiddenMode || debug
		YPwb.Visible:= debug	
		,YPwb2.Visible:= debug
		
		thisPwb:=YPwb
		if load_force
			SetTimerFn("EBMWebPacsQuery_IE_loadmore", -10000, [nextAccNo, YPwb2, nextChartNo, !presearch, !presearch, breakEBMquery])
		
	}else{
		ShowToolTip("Chart No not supported!", 2000)
		tooltip
		return
	}
	
	
	
	LButtonState:=GetKeyState("LButton")
	,breakEBMquery:=false
	if (ret:=EBMWebPacsQuery_IE(nextAccNo, thisPwb, nextChartNo, !presearch, !presearch, breakEBMquery))<0 {
		tooltip 
		if (ret==-1)
			ShowToolTip("Fail to open study: " nextchartno ", " nextAccNo,2000)
		return
	}
	
	if presearch 
		return
	
	if state
		settimer,reclickButton,-2000
	ToolTip 
	;~ Loop {
		;~ winget,EBM_newcount,list,ahk_group EBM
		;~ MouseGetPos,mx,my
		;~ if EBM_newcount!=EBM_count || (last_index:=A_Index) >50
			;~ break
		;~ lastMx := mx, lastMy:=my
		;~ Sleep 1
	;~ }
	;~ MouseMove,% lastmx,% lastmy,0
	;~ if LButtonState
		;~ send {LButton Down}
	;~ else
		;~ send {LButton Up}
	;~ winwait,% nextChartNo " ahk_group EBM",,5
	if (last_index>50 && tried<3) {
		garbage.push(HPwb.hwnd)
		,garbage.push(YPwb.hwnd)
		,garbage.push(ZDPwb.hwnd)
		,HPwb:=YPwb:=ZDPwb:=0
		,SetTimerFn("openNextEBM", -500, [nextAccNo, nextChartNo, tried+1])
		return
	}else{
		;~ Loop % EBM_newcount {
			;~ hwnd:=EBM_newcount%a_index%
			;~ if !InStr(EBM_win, "`n" hwnd "`n"){
				;~ WinHide,% "ahk_id " hwnd
			;~ }
		;~ }
	}
	if(cChartNo!=nextChartNo){
		SetTimerFn("hideEBM", 100, [nextChartNo])
		;~ winwait,% nextChartNo " ahk_group EBM"
		;~ WinHide,% nextChartNo " ahk_group EBM"
		
	}
	WinShow,% cChartNo " ahk_group EBM"
	winactivate,% cChartNo " ahk_group EBM"
	WinShow,% cAccNo " ahk_group EBM"
	winactivate,% cAccNo " ahk_group EBM"
	if priorActiveSimpleRis
		WinActivate,ahk_id %priorActiveSimpleRis%
	settimer,gc,-1800000
	return
}

HideEBM(ChartNo){
	if WinExist(chartNo " ahk_group EBM"){
		WinHide,% chartNo " ahk_group EBM"
		return SetTimerFn("hideEBM", 0)
	}
}

EBMWebPacsQuery_IE_loadmore(nextAccNo, YPwb2, nextChartNo, no_re_search, open, breakEBMquery){
	if !WinExist(nextchartno " ahk_group EBM"){
		EBMWebPacsQuery_IE(nextAccNo, YPwb2, nextChartNo, no_re_search, open, breakEBMquery)
		,SetTimerFn("EBMWebPacsQuery_IE_loadmore", -2000, [nextAccNo, YPwb2, nextChartNo,no_re_search, open, breakEBMquery])
	}
}

reclickButton(){
	send {LButton Down}
}

releaseLButton(){
	if (ret:=GetKeyState("LButton"))
		send {LButton UP}
	return ret
}

gc:
;~ MsgBox % "GC"
for k,v in garbage
	WinClose,ahk_id %v%
garbage:=[]
return

refreshPwb:
;~ ToolTip refresh
HPwbTimeout:=YPwbTimeout:=ZDPwbTimeout:=true
;~ refreshing:=true
;~ if HPwb
	;~ HPwb.quit()
;~ HPwb:=EBMWebPacsLogin_IE(h_id, h_pw, "HC")
;~ ,HPwb.Visible:=false
;~ if YPwb
	;~ YPwb.quit()
;~ YPwb:=EBMWebPacsLogin_IE(Y_id, Y_pw, "YL")
;~ ,YPwb.Visible:=false
;~ ,refreshing:=false
return


OnExit:
if SubStr(nextChartNo,1,1)="H"
	HPwb.Visible:=true
	,YPwb.quit()
	,ZDPwb.quit()
else if SubStr(nextChartNo,1,1)="Y"
	HPwb.quit()
	,ZDPwb.quit()
	,YPwb.Visible:=YPwb2.Visible:=true
else if SubStr(nextChartNo,1,1)="C"
	HPwb.quit()
	,YPwb.quit()
	,ZDPwb.Visible:=true
else
	HPwb.Visible:=YPwb.Visible:=YPwb2.Visible:=ZDPwb.Visible:=true

gosub gc

WinShow,% nextChartNo " ahk_group EBM"
ExitApp:
if closing
	settimer,ExitApp,-500
else
	ExitApp


RisStateChange(){
	global 
	AllRis:=risopened(1)
}


accNoChanged(){
	global AllRis
	;~ cAccNo:=getRisAccNo(targetRis:=AllRis[2,1])
	if ((newChartNo:=getRisChartNo(targetRis:=AllRis[2,1]))="") || (newChartNo=cChartNo){
		settimer,accNoChanged,-500
		return
	}
		
	cChartNo:=newChartNo
	if WinExist(cChartNo " ahk_group EBM")
		settimer,load,-1
	
	settimer,checkCurrentEBM,500
}

Pause::
if(A_PriorHotkey==A_ThisHotkey && A_TimeSincePriorHotkey<400){
	if (nextChartNo){
		WinClose,%nextchartno% ahk_group EBM
	}
}else{
	keywait,Pause,D T0.5
	
	if errorlevel
		pwbVisible:=!pwbVisible
		,pwbVisible(HPwb, pwbVisible)
		,pwbVisible(ZDPwb, pwbVisible)
		,pwbVisible(YPwb, pwbVisible)
		,pwbVisible(YPwb2, pwbVisible)
;~		HPwb.visible:=ZDPwb.visible:=YPwb.visible:=YPwb2.visible:=pwbVisible:=!pwbVisible
}
return

pwbVisible(byref pwb, visible){
	h:=pwb.hwnd
	pwb.visible:=visible
	if (WinVisible(h)!=visible)
		if(visible)
			winshow,ahk_id %h%
		else
			winhide,ahk_id %h%
}


__WinWait(wintitle,wait_sec,interval=100){
	global stopWinWait
	
	loop % (wait_sec*1000/interval) {
		if (stopWinWait) {
			stopWinWait:=false
			return 2
		}
		sleep % interval
	}until WinExist(wintitle)
	return !WinExist(wintitle)
}

#IfWinActive,EBM Preload ahk_class AutoHotkeyGUI
^esc::
winget,l,list,ahk_group EBM
chartNo_hwnd:=[]
Loop % l {
	hwnd:=l%a_index%
	title:=WinGetTitle(hwnd)
	if RegExMatch(title, "病歷號: *\b(\w{6}\d)\b", chartNo)
		chartNo_hwnd[chartNo1]:=hwnd
}
gui,EBMlist:Default
gui,EBMlist:new,-Resize +AlwaysOnTop
gui,EBMlist:Font,s12,Verdana
for k,v in chartNo_hwnd
	gui,EBMlist:Add,button,gEBMlist,% k
gui,EBMlist:show,Center,EBM list
return
#IfWinActive


EBMlist:
if chartNo_hwnd.haskey(a_guicontrol){
	hwnd:=chartNo_hwnd[a_guicontrol]
	WinShow,% "ahk_id " hwnd
	winactivate,% "ahk_id " hwnd
}
return

EBMlistGuiClose:
EBMlistGuiEscape:
gui,EBMlist:Destroy
return


