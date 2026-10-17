; Talk to the single CH_RIS owner (autorun) over IPC instead of creating our own
; IE-polling owner. Set before any include whose auto-exec calls getPlace (portallib /
; risimpax). objprop=0: only scalars (.AccNo/.chartNo/.examDate) + getRis* are used, all
; proxy/IPC-routed. The two explicit creators below call getPlace() (flag-aware). See
; CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <hash>
#include <OnScreenDisplay>
#include <portallib>
#include <risimpax>
#include <GetActiveBrowserURL>
;~ #include <Acc>
;~ #include <CheckUpdate>
#include <NotifyCross>
#include <WM_COPYDATA>
#include <JXON>
#include <monitorInfo>
;~ #include <ProcessList>
#include <WinVisible>
#include <Socket>
ComObjError(false)
OnExit,OnExit
setbatchlines,-1
SetKeyDelay, -1, 0
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
SetControlDelay, -1
SendLevel,1
CoordMode,mouse,Screen
DetectHiddenWindows,on
SetTitleMatchMode,2
#SingleInstance,force
#InstallKeybdHook
#InstallMouseHook
try
Menu, Tray, Icon,% A_ScriptDir "\showLungCAD.ico"

noResults:={}
lungCADEnv:=showLungCAD_LoadEnv(A_ScriptDir "\.env")
	,lungCADUsername:=lungCADEnv["LUNGCAD_USERNAME"]
	,lungCADPassword:=lungCADEnv["LUNGCAD_PASSWORD"]
gosub sethotkey
;~ settimer,errorHandle,1000
if !CaptureTextPath()
	NoCaptureText:=true

if !WinExist("WM_COPYDATA_Listener_RegionGrowMorph") && OpenRegionGrow
	try {
	run % a_scriptdir "\RegionGrowMorph.exe"
	winwait,ahk_class ConsoleWindowClass ahk_exe RegionGrowMorph.exe,,30
}

; if RisImpaxPollingInit() {
; 	RISImpaxRegister([{app: "Impax", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x8002}, func: "RisImpaxStateChange", initStart: 100}
; 	, {app: "Ris", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x8003}, func: "RisAccNoChange", initStart: 100}])
; }
;~ WinMinimize,ahk_class ConsoleWindowClass ahk_exe RegionGrowMorph.exe
;~ SetTimerF("scs_sync", -1)
;~ goto test
;~ gosub setSocket

;~ gui,+ToolWindow +hwndinfo_hwnd +lastFound
;~ WinSetTitle,,,__nodule_info

;~ SplitPath,A_ScriptFullPath,,,,fileNoExt
;~ args:=[]
;~ Loop %0%
;~ if !(%a_index%~="i)" fileNoExt)
;~ args.push(%a_index%)

;~ if args.maxindex() {
;~ mainHwnd:=args[1]
;~ ,cornerHwnd:=args[2]
;~ ,corner:=args[3]
;~ goto grabCorner
;~ }else{
;~ i:=0
;~ for k,v in ProcessList()
;~ if (v.name = A_ScriptName)
;~ i++
;~ if i>1
;~ ExitApp
;~ }

;~ feedbackIp:="localhost"
;~ feedbackIp:="10.0.0.1"
feedbackPort:=10007
	,pwbs:=[]
	,monitorInfo:=monitorInfo()
	,OnMessage(0x4A, "On_WM_COPYDATA")

gui,+hwndguihwnd
WinSetTitle,ahk_id %guihwnd%,,showLungCAD_main

OnMessage(0x2001, "next")
	,OnMessage(0x2002, "prior")
	,OnMessage(0x8100, "search")
	,cross:=new NotifyCross("white")
	,clearReadUrl:="http://10.0.0.1:9104/?accession="

;~ Sleep 1000

;~ chartNo:="6______"
;~ gosub sendChartNo

return

#include <OCR\INFINITT_OCR_Scroll>

errorHandle:
	ifwinexist,ahk_class #32770,hotkeys have been received in the last
		ControlClick,Button1,ahk_class #32770,hotkeys have been received in the last
return

grabCorner:
	info:=getImpaxFrameInfo(cornerHwnd, corner)
		,info.CornerInfo:=1
		,Send_WM_COPYDATA(mainHwnd, 19, jxon_dump(info))
return

On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
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
		try
		j:=JXON_load(str)
		catch
			return

		;~ if j.haskey("CornerInfo")

		SetTimerF("ParseInfo", -1, [j])

	}
}

ParseInfo(j, tried=0){
	global monitorInfo, info, which, frames, NoCaptureText

	if (j.area=0)
		return
	if (!NoCaptureText && !info.FOV){
		if (tried<3){
			ToolTip % "Waiting for OCR..."
			SetTimerF("ParseInfo", -500, [j, tried+1])
		}
		return
	}
	;~ which:=whichMonitor(j.Center_X, j.Center_Y, monitorInfo)
	;~ ,frames:=getViewFrame()
	ToolTip
	if NoCaptureText && !info.FOV && !info.StudyDescription && !info.thickness && !info.WL && !info.WW && !info.z
		MsgBox,,,% "Please make IMPAX show corner informations!",5

	settimer,ReportGUI,-1
	SetTimerF("setReportGUI", -500, [info, j, frames[which.1-1,1,1]])
}

noduleLine(){
	global reporthwnd
	GuiControlGet,d1,%reportHwnd%:,rMinD
	GuiControlGet,d2,%reportHwnd%:,rMaxD
	GuiControlGet,lobe,%reportHwnd%:,selectLobe
	GuiControlGet,SE,%reportHwnd%:,rSE
	GuiControlGet,IM,%reportHwnd%:,rIM
	str:="A "
		, str.=d1=""||d2=""?d1 d2 "mm":(d2>=6||(d1=d2)?d2 "mm":d1 "*" d2 "mm (mean " Round(d1/2+d2/2) " mm)")
		, str.=" nodule in the " (lobe?lobe:"[lobe]") ". " (SE&&IM? "(SE" SE " IM" IM ")":"")
		,setReportGUIControl("rText", str)
	return str
}

setReportGUI(info, json, frameHwnd){
	global reporthwnd, ratio_coord_x, ratio_coord_y, rStudyDate, rAccNo, rChartNo
	if showLungCAD_ShouldSuppressCadGUI()
		return

	WinGetPos,x,y,w,h,% "ahk_id " frameHwnd
	ratio_coord_x:=h>w?(json.Center_X - x)/w:  (json.Center_X - (x+w/2-h/2))/w
		,ratio_coord_y:=w>h?(json.Center_Y-y)/h: (json.Center_Y-(y+h/2-w/2))/w
	MouseMove,% x,% y,0
	MouseMove,1,1,2,R
	SEIM:=getSEIM()
	MouseMove,% json.Center_X,% json.Center_Y,0
	setReportGUIControl("rMinDp", json.min_diameter)
		,setReportGUIControl("rMaxDp", json.max_diameter)
		,setReportGUIControl("rSE", SEIM.1)
		,setReportGUIControl("rIM", SEIM.2)
		,setReportGUIControl("rLoc", info.Z)

	if (info.FOV>0){
		setReportGUIControl("rMinD", d1:=Round(json.min_diameter/w*info.FOV))
			,setReportGUIControl("rMaxD", d2:=Round(json.max_diameter/w*info.FOV))

			;~ , str:="A "
			;~ ,str.=d1=""||d2=""?d1 d2 "mm":(d2>=6||(d1=d2&&d2>0)?d2 "mm":d1 "*" d2 "mm (mean " Round(d1/2+d2/2) " mm)")
			;~ ,str.=" nodule in the [lobe]. (SE" SEIM.1 " IM" SEIM.2 ")"
			,str:=noduleLine()
		;~ ,setReportGUIControl("rText", str)
	}

	impaxHwnd:=ImpaxOpened()[2,1]
		,rStudyDate:=getImpaxExamDate(impaxHwnd)[1]
		,rAccNo:=getImpaxAccNo(impaxHwnd)
		,rChartNo:=getImpaxChartNo(impaxHwnd)

	guicontrol,%reporthwnd%:Move,rFP,w0 h0 x-1 y-1
	gui,%reporthwnd%:show,% "x" json.Center_X-30 " y" json.Center_Y+100 " noactivate",Nodule info #New
	settimer,HideGUIifInactive,-5000
}

setReportGUIControl(var, value){
	global reporthwnd
	guicontrol,%reporthwnd%:,% var,% value
}

DisplayNoduleInfo(noduleInd, isSameSeries){
	global reporthwnd, jsonData, rNoduleInd, coord, noduleListHwnd, ShowNoduleList, lastX, lastY, thisInd, EBMmode, ebm_show_x, ebm_show_y, noduleButtonText
	if showLungCAD_ShouldSuppressCadGUI() {
		thisInd:=noduleInd
		showLungCAD_HideCadGUIs()
		return
	}
	CoordMode, Mouse, Screen
	gosub ReportGUI

	thisInd:=noduleInd
		,nodule:=jsonData.Nodules[rNoduleInd:=noduleInd-1]
	;~ ,str:="A " Round(nodule.Diameter) "mm nodule in the [lobe]. "
	if (isSameSeries){
		setReportGUIControl("rSE", jsonData.SeriesNumber)
			,setReportGUIControl("rIM", nodule.InstanceNumber)
		;~ ,str.="(SE" jsonData.SeriesNumber " IM" nodule.InstanceNumber ")"
	}
	setReportGUIControl("rMinD", Round(nodule.Diameter))
		,setReportGUIControl("rLoc", Round(nodule.SliceLocation))
		;~ ,setReportGUIControl("rText", str)
		,noduleLine()
	if (nodule.hasKey("MalignancyProbability")){
		; Keep the displayed probability at two decimal places regardless of the
		; script's current global floating-point format.
		prb:=Format("{:.2f}", nodule.MalignancyProbability+0)
			,setReportGUIControl("rMaligProb", prb)
			,setReportGUIControl("rProb", prb>0.5?": > 0.5":": < 0.5")
	}

	guicontrol,%reporthwnd%:Move,rFN,w0 h0 x-1 y-1
	guicontrol,%reporthwnd%:,rFNtext,% ""
	if !IsObject(coord) || coord.1="" || coord.2=""
		MouseGetPos, coordX, coordY
	else
		coordX:=coord.1, coordY:=coord.2
	if (ebm_show_x!="" && ebm_show_y!="")
		gui,%reporthwnd%:show,% "x" ebm_show_x " y" ebm_show_y " noactivate",Nodule info #%noduleInd%
	else
		gui,%reporthwnd%:show,% "x" coordX-30 " y" coordY+100 " noactivate",Nodule info #%noduleInd%

	for k,v in noduleButtonText {
		guicontrol,%noduleListHwnd%:,noduleButton%k%,% v
	}
	guicontrol,%noduleListHwnd%:,noduleButton%thisInd%,% "[" thisInd "]"

	width1:=80
	if (ebm_show_x!="" && ebm_show_y!="")
		gui,%noduleListHwnd%:show,% "x" ebm_show_x-80 " y" ebm_show_y " w" width1 " noactivate",List
	else if ShowNoduleList && lastX && lastY
		gui,%noduleListHwnd%:show,% "x" lastX " y" lastY " w" width1 " noactivate",List
	else
		gui,%noduleListHwnd%:show,% "x" coordX-120 " y" coordY+100 " w" width1 " noactivate",List
	settimer,HideGUIifInactive,-5000
}

HideGUIifInactive:
	MouseGetPos,,,win
	if !WinActive("ahk_id " reporthwnd) && win!=reporthwnd
		WinHide,% "ahk_id " reporthwnd
	if !WinActive("ahk_id " noduleListHwnd) && win!=noduleListHwnd && !ShowNoduleList
		WinHide,% "ahk_id " noduleListHwnd
return

#IfWinActive,Nodule info ahk_class AutoHotkeyGUI
	~LButton::
		MouseGetPos,,,,con,2
		if (con!=TextHwnd)
			return
		gosub CopyText
	return
#IfWinActive

ReportGUI:
	gui,report:new,+hwndReportHwnd +ToolWindow +AlwaysOnTop
	gui,Font,s10,Verdana
	gui,Color,ececec
	;~ winset,TransColor,ececec,ahk_id %reporthwnd%
	;~ winset,Trans,200,ahk_id %reporthwnd%
	gui,Add,Text,,% "Size:"
	gui,Add,Edit,xp+40 yp w40 vrMinD,
	gui,Add,Text,xp+50 yp,×
	gui,Add,Edit,xp+20 yp w40 vrMaxD,
	gui,Add,Text,xp+50 yp,mm
	gui,Add,Edit,xp+50 yp w40 vrMinDp,
	gui,Add,Text,xp+50 yp vrMulp,×
	gui,Add,Edit,xp+20 yp w40 vrMaxDp,
	gui,Add,Text,xp+50 yp vrPixel,px

	gui,Add,Text,xm,% "  "
	gui,Add,Text,xp+20 yp,SE
	gui,Add,Edit,xp+20 yp w40 vrSE
	gui,Add,Text,xp+50 yp,IM
	gui,Add,Edit,xp+20 yp w40 vrIM
	gui,Add,ComboBox,xp+100 yp w150 gselectLobe vselectLobe,RUL|RML|RLL|LUL|LLL|lingular LUL

	gui,Add,Text,xm,% "  "
	gui,Add,Text,xp+20,Loc
	gui,Add,Edit,vrLoc xp+40 w60
	gui,Add,Text,xp+80,Malig Prob
	gui,Add,Edit,xp+80 vrMaligProb w60
	gui,Add,Text,xp+80 yp+5 vrProb,% "              "

	gui,Add,Edit,xm r2 w400 vrText -VScroll hwndtextHwnd,

	gui,Add,button,greportFP xm vrFP,Report FP
	;~ gui,Add,Text,x+10 yp+5,: no further info needed
	gui,Add,button,greportFN xp yp vrFN,Report FN

	gui,Add,Text,x+10 yp+5 vrFNtext,: require at least SE/IM
	gui,Add,button,gundo x250 y+20,Undo last feedback

	if !thickSliceMode
		gui,Add,button,gthickSliceMode xm,% "Thick slice mode"
	else
		gui,Add,button,gthinSliceMode xm,% "Thin slice mode"
return

thinSliceMode:
	thickSliceMode:=0
	gosub magicResult
return
thickSliceMode:
	thickSliceMode:=1
	gosub magicResult
return

Undo:
	gosub HideGUI
	impaxHwnd:=ImpaxOpened()[2,1]
		;~ ,rStudyDate:=getImpaxExamDate(impaxHwnd)[1]
		,rAccNo:=getImpaxAccNo(impaxHwnd)
		,rChartNo:=getImpaxChartNo(impaxHwnd)

	feedback:={Undo: 1}
		,feedback["AccessionNumber"]:=rAccNo
		,feedback["PatientID"]:=rChartNo
		,SetTimerF("MoveMsgbox", 100, ["Undo"])
	MsgBox,4,Undo,% "Undo last feedback for " rChartNo "/" rAccNo " ?"
	IfMsgBox,Yes
	{
		sendFeedback(feedback)
		gosub HideGUI
	}
return

MoveMsgbox(title){
	if h:=WinExist(title " ahk_class #32770 ahk_exe showLungCAD.exe") {
		MouseGetPos,x,y
		WinMove,ahk_id %h%,,% x-100,% y-200
		SetTimerF("MoveMsgbox", 0)
	}
}

selectLobe:
	gui,%reporthwnd%:Submit,NoHide
	;~ StringReplace,reportText,rText,% "[lobe]",% Trim(selectLobe)
	reportText:=noduleLine()
	gosub CopyText1
return

CopyText:
	gosub selectLobe
return
CopyText1:
	if selectLobe=
		return
	clipboard:=noduleLine()
	ToolTip % "Text copied !"
	settimer,ToolTip,-2000
return

reportFP:
reportFN:
	if EBMmode
		return
	gui,%reporthwnd%:Default
	gui,Submit,NoHide
	gosub selectLobe
	if (A_ThisLabel="reportFN") && (rSE="" || rIM=""){
		MsgBox,,, % "Please at least specify SE/IM to feedback!",5
		return
	}

	feedback:={}
		,feedback[A_ThisLabel]:=1
	if InStr(A_ThisLabel, "FN"){
		feedback["SE"]:=rSE
			,feedback["IM"]:=rIM
			,feedback["X-Ratio"]:=ratio_coord_x
			,feedback["Y-Ratio"]:=ratio_coord_y
			,feedback["SliceLocation"]:=info.z
			,feedback["MinDiameter"]:=rMinD
			,feedback["MaxDiameter"]:=rMaxD
			,feedback["MinPixelDiameter"]:=rMinDp
			,feedback["MaxPixelDiameter"]:=rMaxDp
			,feedback["AccessionNumber"]:=rAccNo
			,feedback["PatientID"]:=rChartNo
			,RegExMatch(rStudyDate, "s)^(\d+)\W(\d+)\W(\d+).+", m)
			,feedback["StudyDate"]:=m1 (StrLen(m2)=1?"0":"") m2 (StrLen(m3)=1?"0":"") m3

	}else{
		for k,v in jsonData
			if !IsObject(v)
				feedback["" k]:="" v
		feedback["Nodules"]:={}
			, nodule:=jsonData.Nodules[rNoduleInd]
			,thisInd:=rNoduleInd+1
			;~ a:= nodule.hasKey("NoduleIndBeforeSort")?nodule.noduleIndBeforeSort:rNoduleInd
			,feedback["Nodules", "" (nodule.hasKey("NoduleIndBeforeSort")?nodule.noduleIndBeforeSort:rNoduleInd)]:=nodule.clone()
		;~ MsgBox % jxon_dump(feedback)
	}
	;~ ToolTip % exploreobj(feedback)
	sendFeedback(feedback)
	gosub HideGUI
return

HideGUI:
	try
	gui,report:Hide
	try {
		if !ShowNoduleList
			gui,noduleList:Hide
	}

return

sendFeedback(feedback){
	global myTCP, feedbackIp, feedbackPort

	if !(myTCP:=new SocketTCP())
		goto sendFeedbackFail
	if myTCP.connect(feedbackIp, feedbackPort)
		goto sendFeedbackFail
	j:=jxon_dump(feedback)
		,l:=StrLen(j), Encoding:="UTF-8"
		,VarSetCapacity(Buffer, (Length:=StrPut(j, Encoding) * ((Encoding="UTF-16"||Encoding="cp1200") ? 2 : 1) )+4)
		,Length-=1
		,NumPut(Length, Buffer, 0, "UInt")
		,Length := StrPut(j, &Buffer+4, Encoding)
		,myTCP.send(&Buffer, Length+3)
	ToolTip % "Feedback successfully!"
	settimer,ToolTip,-3000
	return
	sendFeedbackFail:
	MsgBox,,,% "Feedback fail, please contact YCH!",5
	return
}

setSocket:
;~ ip:="10.0.0.1"
;~ port:="54321"

;~ myTCP:=new SocketTCP()
;~ myTCP.onRecv:=Func("OnTCPRecv")
;~ myTCP.connect(ip, port)
return

;~ OnTCPRecv(this){
;~ global chartNo
;~ t:=this.recvText()
;~ if RegExMatch(t, "is)doingLungCAD\|(.+)", match){
;~ ToolTip % "Doing lung CAD: " match1
;~ SetTimer,ToolTip,-2000
;~ }else if RegExMatch(t, "is)Status: (.+)", match){
;~ if(match1="OK")
;~ this.sendText(A_IPAddress1 "|doLungCAD|" chartNo)
;~ }

;~ }

ToolTip:
ToolTip
return

getPwb(instance, position="", Visible=true){
	global monitorInfo, pwbs, __is_CH
	if __is_CH
		return

	if (position=""){
		mon:=monitorInfo[1]
			,position:={x: mon.l, y: mon.t, w: Floor(mon.w*0.75), h: Floor(mon.h*0.75)}
	}

	if !WinExist("ahk_id " pwbs[instance].hwnd){
		pwbs[instance]:=pwb:=ComObjCreate("InternetExplorer.Application")
			,pwb.Visible:=Visible
		WinMove,% "ahk_id " pwb.hwnd,,% position.x,% position.y,% position.w,% position.h
	}
	return pwbs[instance]
}

sethotkey:
	iniPath:=A_ScriptDir "\showLungCAD.ini"
	;~ IniRead,mainKey,% iniPath,Hotkey,QuerySyngovia,^i
	IniRead,secondKey,% iniPath,Hotkey,QueryMagic,#i
	IniRead,priorKey,% iniPath,Hotkey,Prior,#PgUp
	IniRead,nextKey,% iniPath,Hotkey,Next,#PGDN
	IniRead,ShowInBrowser,% iniPath,Hotkey,ShowInBrowser,0
	IniRead,ShowInImpax,% iniPath,Hotkey,ShowInImpax,1
	IniRead,OpenRegionGrow,% iniPath,Hotkey,OpenRegionGrow,1
	IniRead,EBMmode,% iniPath,Hotkey,EBMmode,0
	IniRead,ShowNoduleList,% iniPath,Hotkey,ShowNoduleList,1
	IniRead,ReportFPKey,% iniPath,Hotkey,reportFP,#p
	IniRead,reportFNKey,% iniPath,Hotkey,reportFN,#n
	IniRead,dismissKey,% iniPath,Hotkey,quickClose,% "F2,F3,Esc"
	IniRead,threshold,% iniPath,Hotkey,threshold,0.5
	IniRead,ShowClearRead,% iniPath,Hotkey,ShowClearRead,0
	IniRead,preloadingMode,% iniPath,Hotkey,preloading,1
	IniRead,INFINITTOCRDebug,% iniPath,Hotkey,INFINITTOCRDebug,0
	IniRead,INFINITTOCRDebugRegion,% iniPath,Hotkey,INFINITTOCRDebugRegion,0
	IniRead,INFINITTOCRSaveROI,% iniPath,Hotkey,INFINITTOCRSaveROI,% INFINITTOCRDebug
	IniRead,INFINITTOCRSPRatio,% iniPath,Hotkey,INFINITTOCRSPRatio,% "-0.0016,0.0000,0.1110,0.1318"
	IniRead,INFINITTOCRImgRatio,% iniPath,Hotkey,INFINITTOCRImgRatio,% "0.9094,0.0569,0.0890,0.0360"
	IniRead,INFINITTOCRSPRatioRDP,% iniPath,Hotkey,INFINITTOCRSPRatioRDP,% "0,0.0936,0.0955,0.0565"
	IniRead,INFINITTOCRImgRatioRDP,% iniPath,Hotkey,INFINITTOCRImgRatioRDP,% "0.9248,0.0559,0.0752,0.0419"
	IniRead,INFINITTOCRDragScrollDefault,% iniPath,Hotkey,INFINITTOCRDragScrollDefault,1
	IniRead,INFINITTOCRDragScrollRDPEnable,% iniPath,Hotkey,INFINITTOCRDragScrollRDPEnable,0
	IniRead,INFINITTOCRRDPDragUrl,% iniPath,Hotkey,INFINITTOCRRDPDragUrl,
	IniRead,INFINITTOCRDragScrollSPEnable,% iniPath,Hotkey,INFINITTOCRDragScrollSPEnable,1
	IniRead,INFINITTOCRDragScrollSPMinTicks,% iniPath,Hotkey,INFINITTOCRDragScrollSPMinTicks,10
	IniRead,INFINITTOCRDragScrollSPLeaveTicks,% iniPath,Hotkey,INFINITTOCRDragScrollSPLeaveTicks,1
	IniRead,INFINITTOCRDragScrollMaxRoughDrags,% iniPath,Hotkey,INFINITTOCRDragScrollMaxRoughDrags,6
	IniRead,INFINITTOCRDragScrollSPAutoLearn,% iniPath,Hotkey,INFINITTOCRDragScrollSPAutoLearn,1

	IniRead,INFINITTOCRDragScrollSPRatioPer100,% iniPath,Hotkey,INFINITTOCRDragScrollSPRatioPer100,0.11524
	IniRead,INFINITTOCRDragScrollSPRatioPer100RDP,% iniPath,Hotkey,INFINITTOCRDragScrollSPRatioPer100RDP,%INFINITTOCRDragScrollSPRatioPer100%
	IniRead,INFINITTOCRDragScrollSPSign,% iniPath,Hotkey,INFINITTOCRDragScrollSPSign,1
	IniRead,INFINITTOCRScrollInputMode,% iniPath,Hotkey,INFINITTOCRScrollInputMode,wheel
	IniRead,INFINITTOCRScrollKeyUp,% iniPath,Hotkey,INFINITTOCRScrollKeyUp,Up
	IniRead,INFINITTOCRScrollKeyDown,% iniPath,Hotkey,INFINITTOCRScrollKeyDown,Down
	IniRead,INFINITTOCRDragStepPx,% iniPath,Hotkey,INFINITTOCRDragStepPx,12
	IniRead,INFINITTOCRDragStepSleep,% iniPath,Hotkey,INFINITTOCRDragStepSleep,2
	IniRead,INFINITTOCRDragEndpointSleep,% iniPath,Hotkey,INFINITTOCRDragEndpointSleep,3
	OCR_DEBUG_MODE:=INFINITTOCRDebug
	OCR_DEBUG_REGION_VIEW:=INFINITTOCRDebugRegion
	OCR_SAVE_ROI_BITMAPS:=INFINITTOCRSaveROI
	OCR_DRAG_SCROLL_DEFAULT:=INFINITTOCRDragScrollDefault
	OCR_DRAG_SCROLL_RDP_ENABLE:=INFINITTOCRDragScrollRDPEnable+0
	OCR_RDP_DRAG_URL:=(INFINITTOCRRDPDragUrl="ERROR" ? "" : INFINITTOCRRDPDragUrl)
	OCR_DRAG_SCROLL_SP_ENABLE:=INFINITTOCRDragScrollSPEnable

	OCR_DRAG_SCROLL_SP_MIN_TICKS:=INFINITTOCRDragScrollSPMinTicks+0
	OCR_DRAG_SCROLL_SP_LEAVE_TICKS:=INFINITTOCRDragScrollSPLeaveTicks+0
	OCR_DRAG_SCROLL_MAX_ROUGH_ATTEMPTS:=Max(1, INFINITTOCRDragScrollMaxRoughDrags+0)
	OCR_DRAG_SCROLL_SP_AUTO_LEARN:=INFINITTOCRDragScrollSPAutoLearn+0
	OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100:=INFINITTOCRDragScrollSPRatioPer100+0.0
	OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100_RDP:=INFINITTOCRDragScrollSPRatioPer100RDP+0.0
	OCR_DRAG_SCROLL_SP_SIGN:=INFINITTOCRDragScrollSPSign+0
	OCR_DRAG_SCROLL_SP_CONFIG_FILE:=iniPath
	OCR_DRAG_SCROLL_SP_CONFIG_SECTION:="Hotkey"
	OCR_DRAG_SCROLL_SP_CONFIG_KEY:="INFINITTOCRDragScrollSPRatioPer100"
	OCR_DRAG_SCROLL_SP_CONFIG_KEY_RDP:="INFINITTOCRDragScrollSPRatioPer100RDP"
	OCR_SCROLL_INPUT_MODE:=INFINITTOCRScrollInputMode
	OCR_SCROLL_KEY_UP:=INFINITTOCRScrollKeyUp
	OCR_SCROLL_KEY_DOWN:=INFINITTOCRScrollKeyDown
	OCR_DRAG_STEP_PX:=INFINITTOCRDragStepPx+0
	OCR_DRAG_STEP_SLEEP:=INFINITTOCRDragStepSleep+0
	OCR_DRAG_ENDPOINT_SLEEP:=INFINITTOCRDragEndpointSleep+0
	OCR_SP_REGION_RATIO:=showLungCAD_ParseRegionRatio(INFINITTOCRSPRatio, [-0.0016, 0.0000, 0.1110, 0.1318])
	OCR_IMG_REGION_RATIO:=showLungCAD_ParseRegionRatio(INFINITTOCRImgRatio, [0.9094, 0.0569, 0.0890, 0.0360])
	OCR_SP_REGION_RATIO_RDP:=showLungCAD_ParseRegionRatio(INFINITTOCRSPRatioRDP, [0, 0.0936, 0.0955, 0.0565])
	OCR_IMG_REGION_RATIO_RDP:=showLungCAD_ParseRegionRatio(INFINITTOCRImgRatioRDP, [0.9248, 0.0559, 0.0752, 0.0419])

	GroupAdd,RisOrImpax,ahk_exe impax-client-main.exe
	GroupAdd,RisOrImpax,ahk_exe Menu.exe
	GroupAdd,RisOrImpax,ahk_exe WebViewerComSrvEC.exe
	GroupAdd,RisOrImpax,ahk_exe WEBVIE~1.EXE
	GroupAdd,RisOrImpax,ahk_exe Miv2Lib.exe
	GroupAdd,RisOrImpax,ahk_exe G3PACS.exe
	GroupAdd,RisOrImpax,simple RIS ahk_class AutoHotkeyGUI
	GroupAdd,RisOrImpax,ahk_exe showLungCAD.exe

	ncc_ip:="10.0.0.1"

	if(1){
		use_ip:="192.0.2.10"
			,baseurl:="http://" use_ip ":8089"
			,ip:= use_ip ":8089"
			,baseurl2:=baseurl
			,ncc_ok:=true
			,feedbackIp:= use_ip ":8089"
	}

	else if InStr("|" A_IPAddress1 "|" A_IPAddress2 "|" A_IPAddress3 "|" A_IPAddress1, "|172.2"){
		baseurl:="http://myserver.local:8000"
			,ip:="myserver.local:8000"
			,baseurl2:="http://10.0.0.1"
			,ncc_ok:=true
			,feedbackIp:="10.0.0.1"
	}else{

		ips=
	(
	10.0.0.1
	127.0.0.1:8000
	myserver.local:8000
	127.0.0.1:8000
	)
		baseurl:=feedbackIp:=""
		ToolTip % "Finding server ... "
		;~ if (A_IPAddress1~="^172.2")
		;~	ips:=ncc_ip "`n" ips
		Loop,parse,ips,`n
		{
			whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
				,whr.Open("GET",(url:="http://" (ip:=Trim(A_LoopField))) "/", true)
				,whr.Send()
				,whr.WaitForResponse(2)
			if (whr.Status>=200 && whr.Status<300){
				baseurl:=url, feedbackIp:=ip
				break
			}
		}

		ips=
	(
	10.0.0.1
	myserver.local:8182
	10.0.0.1:8000
	127.0.0.1:8182
	)
		Loop,parse,ips,`n
		{
			whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
				,whr.Open("GET",(url:="http://" Trim(A_LoopField)) "/", true)
				,whr.Send()
				,whr.WaitForResponse(2)
			if (whr.Status>=200 && whr.Status<300){
				baseurl2:=url, feedbackIp:=ip2:=Trim(A_LoopField)
					,ncc_ok:=true
				break
			}

		}
	}
	if (baseurl=""){
		MsgBox % "Can not connect to server!`nPlease contact YCH!"
		;~ ExitApp
	}
	ToolTip
	if(EBMmode){
		;~ baseurl:="http://127.0.0.1:8000"
		;~ ,feedbackIp:="127.0.0.1:8000"
		ShowInBrowser:=1
			,ShowInImpax:=0
	}else{
		;~ baseurl:="http://10.0.0.1"
		;~ ,feedbackIp:="10.0.0.1"
	}

	;~ if ShowInBrowser
	;~ gosub createPwb

	Hotkey,IfWinActive,ahk_group RisOrImpax
	;~ Hotkey,% Trim(mainKey),main,on
	;~ Hotkey,% "^" Trim(priorKey),prior,on
	;~ Hotkey,% "^" Trim(nextKey),next,on
	Hotkey,% Trim(priorKey),prior,on T3
	Hotkey,% Trim(nextKey),next,on T3
	if(!EBMmode){
		Hotkey,% Trim(ReportFPKey),ReportFPHotkey,on
		Hotkey,% Trim(ReportFNKey),ReportFNHotkey,on

	}
	dismissEscRegistered:=false
	Loop,parse,dismissKey,`,
	{
		dismissHotkey:=Trim(A_LoopField)
		if (dismissHotkey="")
			continue
		if (dismissHotkey~="i)^Esc$")
			dismissEscRegistered:=true
		Hotkey,% "~" dismissHotkey,dismiss,on
	}
	if !dismissEscRegistered
		Hotkey,~Esc,dismiss,on
	Hotkey,IfWinActive
	; Chrome briefly owns focus while its address bar is updated. Keep nodule
	; stepping available only during that update, then return to the PACS scope.
	chromeNavigationContext:=Func("showLungCAD_IsNavigatingChrome")
	Hotkey,If,% chromeNavigationContext
	Hotkey,% Trim(priorKey),prior,on T3
	Hotkey,% Trim(nextKey),next,on T3
	Hotkey,If
	; Register the physical-input abort hooks in their disabled state. They are
	; enabled only while CAD OCR is scrolling, so ordinary/RDP wheel bursts do
	; not count as showLungCAD hotkey firings.
	showLungCAD_SetManualAbortHotkeys(false)

	; Register Win+I globally so AHK intercepts it before Windows (prevents Settings from opening)
	Hotkey,% "$" Trim(secondKey),magicResultHotkey,on

	if OpenRegionGrow {
		Hotkey,IfWinExist,WM_COPYDATA_Listener_RegionGrowMorph
		Hotkey,~+LButton,~+LButton_
		Hotkey,IfWinExist
	}

;~ Hotkey,% "+" Trim(priorKey),prior,on
;~ Hotkey,% "+" Trim(nextKey),next,on

return

showLungCAD_ParseRegionRatio(text, fallback){
	ret := []
	Loop, Parse, text, `,
		ret.Push(Trim(A_LoopField) + 0.0)
	if (ret.Length()!=4)
		return fallback
	return ret
}

showLungCAD_LoadEnv(path){
	values:={}
	if !FileExist(path)
		return values
	FileRead, contents, %path%
	Loop, Parse, contents, `n, `r
	{
		line:=Trim(A_LoopField)
		if (line="" || SubStr(line, 1, 1)="#")
			continue
		separator:=InStr(line, "=")
		if (!separator)
			continue
		key:=Trim(SubStr(line, 1, separator-1))
		value:=Trim(SubStr(line, separator+1))
		if ((SubStr(value, 1, 1)="""" && SubStr(value, 0)="""")
			|| (SubStr(value, 1, 1)="'" && SubStr(value, 0)="'"))
			value:=SubStr(value, 2, StrLen(value)-2)
		values[key]:=value
	}
	return values
}

showLungCAD_ProtectedGet(url, ByRef responseBody, ByRef responseHeaders, timeout:=3){
	global lungCADUsername, lungCADPassword
	responseBody:=""
	responseHeaders:=""
	if (lungCADUsername="" || lungCADPassword="")
		return false
	http:=ComObjCreate("WinHttp.WinHttpRequest.5.1")
	http.Open("GET", url, true)
	http.SetCredentials(lungCADUsername, lungCADPassword, 0)
	http.Send()
	responseReceived:=http.WaitForResponse(timeout)
	if (!responseReceived)
		return false
	responseBody:=http.ResponseText
	responseHeaders:="HTTP/1.1 " http.Status "`n" http.GetAllResponseHeaders()
	return true
}

ReportFNHotkey:
	;~ SetTimerF("MoveMsgbox", 100, ["Report FN"])
	;~ MsgBox, 4,Report FN, Report False Negative? `n(New nodule)
	;~ IfMsgBox,No
	;~ return
	MouseGetPos,mx,my
	which:=whichMonitor("", "", monitorInfo)
		,frames:=getViewFrame()
	if !NoCaptureText {
		ToolTip % "Waiting for OCR..."
		info:=getImpaxFrameInfo(frames[which.1-1,1,1], "LL")
	}else
		info:={}
	ToolTip
	ParseInfo({Center_X:mx, Center_Y:my})
return

ReportFPHotkey:
	SetTimerF("MoveMsgbox", 100, ["Report FP"])
	MsgBox, 4,Report FP, Report False Positive? `n(Not a nodule)
	IfMsgBox,No
		return
	gosub ReportFP
return

search(){
	gosub magicResult
}
next(){
	gosub next
}
prior(){
	gosub prior
}

magicResultHotkey:
	if !WinActive("ahk_group RisOrImpax")
		return
	isPreloading:=false
magicResult:
	gosub HideGUI
	if (!isPreloading)
		showLungCAD_ResolveINFINITTTargetMonitor(true)

	gosub getChartNo

	if(preloadingMode && preloadedAccNo=AccNo && AccNo!=""){
		isPreloaded:=true
		goto magicResultPreloaded
	}

	if (chartNo="") {
		msgbox,,,Failed to get chart No.,3
		return
	}
	if (examDate=""){
		MsgBox,,,Failed to get exam date,3
		return
	}
	if (lungCADUsername="" || lungCADPassword=""){
		MsgBox,,,Missing LungCAD credentials in %A_ScriptDir%\.env,5
		return
	}
	if thisPacsViewer.GEViewer
		ncc_mode:=true, useUrl:=baseurl2
	else
		useUrl:=baseUrl

	if InStr(thisPacsViewer.Type, "INFINITT") && (AccNo=""){
		if !(CH_RIS)
			getPlace()   ; flag-aware create: proxy when __CH_RIS_CLIENT, else local owner
		AccNo:=CH_RIS.AccNo
	}

	showLungCAD_ProtectedGet(jsonUrl:=useUrl "/lungNoduleResult/" chartNo "_" AccNo ".json", post, header)
		,jsonExists:=true
	try
	jsonData:=jxon_load(jsonPostData:=post)
	catch
		jsonExists:=false, jsonData:=[]

	if (!jsonExists){
		showLungCAD_ProtectedGet(jsonUrl:=useUrl "/lungNoduleResult_backup/" chartNo "_" AccNo ".json", post, header)
			,jsonExists:=true
		try
		jsonData:=jxon_load(jsonPostData:=post)
		catch
			jsonExists:=false, jsonData:=[]
	}

	if (!jsonExists && ncc_ok){
		showLungCAD_ProtectedGet(jsonUrl:=(ip:=baseurl2) "/lungNoduleResult/" chartNo "_" AccNo ".json", post, header)
			,jsonExists:=true
		try
		jsonData:=jxon_load(jsonPostData:=post), useUrl:=ip
		catch
			jsonExists:=false, jsonData:=[]

		if (!jsonExists){
			showLungCAD_ProtectedGet(jsonUrl:=(ip:=baseurl2) "/lungNoduleResult_backup/" chartNo "_" AccNo ".json", post, header)
				,jsonExists:=true
			try
			jsonData:=jxon_load(jsonPostData:=post), useUrl:=ip
			catch
				jsonExists:=false, jsonData:=[]
		}

	}

	magicUrl:=(ip:=useUrl "/nodulePic/") (examDate:=SubStr(RegExReplace(examDate,"\D",""),1,8)) "/" chartNo "/"
		,showLungCAD_ProtectedGet(magicUrl, post, header)
		,regexmatch(header," (\d+)",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
		,FirstOpened:=true, nodulePicExists:=true
	if (code1<200 || code1>=300){
		nodulePicExists:=false
		if(ncc_ok){
			magicUrl:=(ip:=baseurl2 "/nodulePic/") examDate "/" chartNo "/"
				,showLungCAD_ProtectedGet(magicUrl, post, header)
				,regexmatch(header," (\d+)",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
				,FirstOpened:=true,nodulePicExists:=true

			if (code1<200 || code1>=300) {
				nodulePicExists:=false

				if(!jsonExists && !noResults.hasKey(examDate chartNo)){
					noResults[examDate chartNo]:=1
					MsgBox,260,, % "Can't find result of " chartNo " on " examDate " !`n`nRequest for CAD?",15
					IfMsgBox,Yes
					{
						sid:=askForPortalIdPw()
						if (sid){
							if portalMessage(sid, "0912000000", examDate " " chartNo "希望有CAD!"){
								MsgBox,,,% "已發送簡訊給CHM!",3
							}else{
								MsgBox,,,% "發送簡訊給CHM失敗，請電話(52113)告知病歷號、檢查日期!",3
							}
						}
					}
					return
				}

			}

		}

	}

	if nodulePicExists
		clipboard:=currentUrl:=magicUrl "#&gid=1&pid=1"
	else
		currentUrl:=""
	lastFound:="magic"
	if (isPreloading && nodulePicExists ){
		preloadedChartNo:=chartNo
			,preloadedAccNo:=AccNo
		if nodulePicExists
			gosub UrlToBrowser
		return
	}

magicResultPreloaded:
	if nodulePicExists
		gosub UrlToBrowser
	else
		SetTimerF("ShowToolTip", -1000, ["NodulePic not available!"])
	SetTimer,loadJson,-1
return

loadJson:
	;~ httprequest(jsonUrl:=baseurl "/lungNoduleResult/" chartNo "_" AccNo ".json"
	;~ , post:="", header, "charset: utf-8")
	;~ try
	;~ jsonData:=jxon_load(post)
	;~ catch {
	;~ MsgBox,,,% "JSON data error, plz contact CHM or YCH!",5
	;~ return
	;~ }

	thisInd:=1
		, nodCount:=jsonData.Nodules.SetCapacity(0)
		, First:=true
	showLungCAD_ResetCycleHint()
	if showLungCAD_ShouldSuppressCadGUI()
		showLungCAD_HideCadGUIs()
	else if nodCount>0
		gosub noduleListGui
	if nodCount=0
		goto noResult
	gosub pacsSelect
return

noduleListGui:
	if showLungCAD_ShouldSuppressCadGUI() {
		showLungCAD_HideCadGUIs()
		return
	}
	gui,noduleList:new,+hwndNoduleListHwnd +ToolWindow +AlwaysOnTop
	gui,Font,s12 w400,Verdana
	gui,Color,ececec
	noduleButtonText:=[]
	;~ winset,TransColor,ececec,ahk_id %noduleListHwnd%
	;~ winset,Trans,200,ahk_id %noduleListHwnd%
	width1:=80, width2:=40
	if (nodCount<=10){
		Loop % nodCount
			guiNoduleButton(A_Index, width1, width2, 0, "+0")

	}else{
		Loop % Floor(nodCount/2)
			guiNoduleButton(2*(A_Index-1)+1, width2, width2, 0, "+0")
				,guiNoduleButton(2*(A_Index), width2, width2, "+0", "p")

		if Mod(nodCount,2)
			guiNoduleButton(nodCount, width2, width2, 0, "+0")

	}
	gui,Font,s10 w400,Verdana
	gui,Add,button,gorderBySize w%width1% h%width2% x0 y+0 vorderBySizeButton,By Size
return

guiNoduleButton(_i, w, h, x, y){
	local conf,FontColor,t
	conf:=jsonData.Nodules[_i-1].Confidence
	gui,Font,% "s12 w" (conf>5?700:400),Verdana
	FontColor:=conf>threshold?"black":"gray"i
	gui,Add,button,gjumpToNodule w%w% h%h% x%x% y%y% vnoduleButton%_i% c%FontColor%,%  t:=(conf>5)?("-" _i "-"):(" " _i " ")
	noduleButtonText[_i]:=t
}

orderBySize:
	INFINITT_OCR_RequestAbort()
	gosub hideGUI
	orders:=[]
	for k,nodule in jsonData.Nodules {
		key:=Floor(nodule.Diameter*1000)
		if !orders.hasKey(key)
			orders[key]:=[]
		orders[key].push(k)
	}

	newNodules:=[]
		,Count:=jsonData.Nodules.maxindex()
		,i:=0
	for k,v in orders {
		for x,y in v
			newNodules[thisI:=Count-(i++)]:=jsonData.Nodules[y].clone()
				,newNodules[thisI, "NoduleIndBeforeSort"]:=y
	}

	jsonData.Nodules:=newNodules
		,thisInd:=1
	showLungCAD_ResetCycleHint()
	gosub noduleListGui
	guicontrol,noduleList:Move,orderBySizeButton,w0 h0 x-1
	gosub changeIm2

return

jumpToNodule:
	if RegExMatch(A_GuiControl, "\d+", jumpNoduleInd){
		INFINITT_OCR_RequestAbort()
		thisInd:=jumpNoduleInd
		showLungCAD_ResetCycleHint()
		SetTimer, showLungCAD_JumpToNoduleDeferred, -30
	}
return

showLungCAD_JumpToNoduleDeferred:
	if (OCR_RUN_ACTIVE || showLungCAD_BrowserNavigationActive) {
		SetTimer, showLungCAD_JumpToNoduleDeferred, -50
		return
	}
	if !showLungCAD_ShouldUseINFINITTOCR()
		gosub HideGUI
	if ShowNoduleList && !showLungCAD_ShouldUseINFINITTOCR()
		settimer,ShowNoduleListGUI,-1000
	gosub changeIm2
return

ShowNoduleListGUI:
	if showLungCAD_ShouldSuppressCadGUI() {
		showLungCAD_HideCadGUIs()
		return
	}
	gui,%nodulelisthwnd%:show,NoActivate
return
nextInd(ind){
	global nodCount, thisInd, threshold, jsonData
	if ind=
		ind:=thisInd

	Loop {
		if (++ind>nodCount)
			ind-=nodCount
		if (ind==thisInd) || (jsonData.Nodules[ind-1].Confidence>threshold)
			break
	}

	return ind
}
priorInd(ind){
	global nodCount, thisInd, threshold, jsonData
	if ind=
		ind:=thisInd

	Loop {
		if (--ind<1)
			ind:=nodCount
		if (ind==thisInd) || (jsonData.Nodules[ind-1].Confidence>threshold)
			break
	}

	return ind
}

showLungCAD_SetCycleIndex(key){
	global thisInd, nodCount, showLungCAD_cycleKey, showLungCAD_cycleInd

	if (nodCount<=1) {
		showLungCAD_ResetCycleHint()
		ToolTip % (nodCount=0) ? "No nodules to step." : "Only one nodule."
		SetTimer,ToolTip,-1800
		return false
	}

	nextIndCandidate:=showLungCAD_FindCycleIndex(thisInd, key, false)
	if (nextIndCandidate!="") {
		thisInd:=nextIndCandidate
		showLungCAD_ResetCycleHint()
		return true
	}

	if (showLungCAD_cycleKey=key && showLungCAD_cycleInd=thisInd) {
		nextIndCandidate:=showLungCAD_FindCycleIndex(thisInd, key, true)
		showLungCAD_ResetCycleHint()
		if (nextIndCandidate="")
			return false
		thisInd:=nextIndCandidate
		return true
	}

	showLungCAD_cycleKey:=key
	showLungCAD_cycleInd:=thisInd
	ToolTip % (key="next") ? "Last nodule. Press Next again to go to first." : "First nodule. Press Prior again to go to last."
	SetTimer,ToolTip,-1800
	return false
}

showLungCAD_FindCycleIndex(ind, key, allowWrap:=false){
	global nodCount, threshold, jsonData

	if (nodCount<=0)
		return ""

	step:=(key="next") ? 1 : -1
	i:=ind
	Loop %nodCount% {
		i+=step
		if (i>nodCount) {
			if !allowWrap
				return ""
			i:=1
		} else if (i<1) {
			if !allowWrap
				return ""
			i:=nodCount
		}

		if (i=ind)
			return allowWrap ? ind : ""
		if (jsonData.Nodules[i-1].Confidence>threshold)
			return i
	}
	return allowWrap ? ind : ""
}

showLungCAD_ResetCycleHint(){
	global showLungCAD_cycleKey, showLungCAD_cycleInd
	showLungCAD_cycleKey:=""
	showLungCAD_cycleInd:=0
}

showLungCAD_ShouldSuppressCadGUI(){
	global __is_CH
	return __is_CH
}

showLungCAD_HideCadGUIs(){
	global reporthwnd, noduleListHwnd
	if (reporthwnd && WinExist("ahk_id " reporthwnd))
		WinHide, ahk_id %reporthwnd%
	if (noduleListHwnd && WinExist("ahk_id " noduleListHwnd))
		WinHide, ahk_id %noduleListHwnd%
}

disconnectSocket:
	inUdp.disconnect()
	for k,v in outUdp
		v.disconnect()
return

sendChartNo:
;~ outUdp(ip, port, A_IPAddress1 "|queryStatus")
return

getChartNo:

	lastChartNo:=chartNo, lastAccNo:=AccNo
	chartNo:=""
	if !(CH_RIS) && __is_CH
		getPlace()   ; flag-aware create: proxy when __CH_RIS_CLIENT, else local owner

	if (isPreloading){
		preloadedAccNo:=preloadedChartNo:=""
			, rChartNo:=__is_CH?CH_RIS.chartNo:getRisChartNo(RisOpened()[2])
			, chartNo:=rChartNo, examDate:=__is_CH?CH_RIS.examDate:getRisExamDate(RisHwnd:=RisOpened()[2])
			, AccNo:=__is_CH?CH_RIS.AccNo:getRIsAccNo(RisHwnd)
		return
	}

	; Stop polling before constructing the next viewer. This script reads C hospital
	; study metadata from RIS and enumerates image HWNDs
	; directly, so it does not need INFINITT's recurring accessibility polling.
	showLungCAD_StopINFINITTRefresh(thisPacsViewer)
	thisPacsViewer:=new activePacs
	if (__is_CH)
		showLungCAD_StopINFINITTRefresh(thisPacsViewer)

	;~ winget,pName,ProcessName,A
	;~ if (EBMmode || pName~="i)WebViewerComSrvEC.exe|WEBVIE~1.EXE"){
	;~ if rChartNo:=getRisChartNo(RisOpened()[2])
	;~ chartNo:=rChartNo, examDate:=getRisExamDate(RisHwnd:=RisOpened()[2])
	;~ , AccNo:=getRIsAccNo(RisHwnd)
	;~ else
	;~ ret:=getEBMInfo()
	;~ ,chartNo:=ret.chartNo
	;~ ,examDate:=ret.examYear (StrLen(ret.examMonth)=1?"0":"") ret.examMonth (StrLen(ret.examDay)=1?"0":"") ret.examDay
	;~ ,AccNo:=ret.AccNo
	;~ }

	;~ else if iChartNo:=getImpaxChartNo(impaxHwnd:=ImpaxOpened()[2,1]){
	;~ chartNo:=iChartNo, examDate:=getImpaxExamDate(impaxHwnd)[1]
	;~ , AccNo:=getImpaxAccNo(impaxHwnd)
	;~ if RegExMatch(examDate, "^(\d+)\/(\d+)\/(\d+)", m)
	;~ examDate:=m1 (StrLen(m2)=1?"0":"") m2 (StrLen(m3)=1?"0":"") m3
	;~ }

	if(__is_CH){
		chartNo:=CH_RIS.chartNo
		AccNo:=CH_RIS.AccNo
		examDate:=CH_RIS.examDate
		return
	}

	if (chartNo:=thisPacsViewer.getChartNo()){
		AccNo:=thisPacsViewer.getAccNo()
			,examDate:=thisPacsViewer.getExamDate()
		if(InStr(thisPacsViewer.Type, "infinitt")){
			while % StrLen(chartNo)<10
				chartNo:="0" chartNo
		}
	}

	else if rChartNo:=getRisChartNo(RisOpened()[2])
		chartNo:=rChartNo, examDate:=getRisExamDate(RisHwnd:=RisOpened()[2])
			, AccNo:=getRIsAccNo(RisHwnd)
	else if regexmatch(clipboard,"\w{6}\d",match)
		chartNo:=match, AccNo:=""

;~ MsgBox % chartNo

return

main:
	gosub HideGUI
	chartNo:=AccNo:=examDate:=""
		, jsonData:=[]
	gosub getChartNo
	if (chartNo="") {
		msgbox,,,Failed to get chart No.,3
		return
	}
test:
	dateStr:=SubStr(examDate,1,4) SubStr(examDate,6,2) SubStr(examDate,9,2)

		,ip:="http://10.0.0.1:8042/"
		;~ chartNo:="6______"

		,winhttprequest(url:=ip "patients/" SHA1dash(chartNo),post:="",header:="","charset: utf-8`nTimeout: 3")
	if (!post){
		goto fail
		return
	}

	patient:=json_from(post)
		,url:="",processed:=0
	Loop % patient.studies.maxindex() {
		winhttprequest(ip "studies/" patient.studies[A_Index],post:="",header:="","charset: utf-8`nTimeout: 3")
		if !post
			continue
		study:=json_from(post)
		if(study.MainDicomTags.StudyDate=dateStr){
			Loop % study.series.maxindex() {
				winhttprequest(ip "series/" study.series[A_Index],post:="",header:="","charset: utf-8`nTimeout: 3")
				if(!post)
					continue
				series:=json_from(post)
				;~ else if ()
				if(series.MainDicomTags.SeriesDescription="Evidence Documents MM Oncology Reading"){
					processed:=1
				}else if(series.MainDicomTags.SeriesDescription="Results MM Oncology Reading" || series.MainDicomTags.SeriesDescription="Hologic R2 ImageChecker CAD SC"){
					clipboard:=url:=ip "web-viewer/app/viewer.html?series=" study.series[A_Index]
					break 2
				}

			}
		}
	}
	if(url=""){
		if(processed){
			goto noResult
			return
		}else{
			goto fail
			return
		}
	}

	;~ if post
	;~ clipboard:=url:=ip "web-viewer/app/viewer.html?series=" json_from(post).series.1
	;~ else
	;~ goto fail

	;~ test:
	;~ clipboard:=url:=ip:="http://www.yahoo.com.tw/"
	lastFound:="syngovia"
UrlToBrowser:
	if !nodulePicExists
		goto UrlToBrowserReturn
	if (!ShowInBrowser && lastFound!="syngovia")
		goto UrlToBrowserReturn

	;~ gosub createPwb
	if(!__is_CH && ShowClearRead && (AccNo!="")){
		if (!isPreloaded)
			getPwb(2).navigate(clearReadUrl AccNo)
		if (!isPreloading){
			getPwb(2).Visible:=true
			winactivate,% "ahk_id " getPwb(2).hwnd
		}
	}

	if (!isPreloaded)
		ShowCadBrowserUrl(currentUrl, !isPreloading)
	else if(!isPreloading)
		ShowCadBrowserWindow()
UrlToBrowserReturn:
	isPreloaded:=false
return

ShowCadBrowserUrl(url, activate:=true){
	global __is_CH, showLungCAD_BrowserNavigationActive
	if (__is_CH) {
		previousHwnd:=WinExist("A")
		previousNavigationActive:=showLungCAD_BrowserNavigationActive
		showLungCAD_BrowserNavigationActive:=true
		try {
			navigateChrome(url)
			if (activate)
				WinActivate, ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe
		} finally {
			if (!activate && previousHwnd && WinExist("ahk_id " previousHwnd))
				WinActivate, ahk_id %previousHwnd%
			showLungCAD_BrowserNavigationActive:=previousNavigationActive
		}
		return
	}

	pwb:=getPwb(1)
	pwb.navigate(url)
	if (activate){
		pwb.Visible:=true
		winactivate,% "ahk_id " pwb.hwnd
	}
}

ShowCadBrowserWindow(){
	global __is_CH
	if (__is_CH) {
		WinActivate, ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe
		return
	}
	pwb:=getPwb(1)
	pwb.Visible:=true
	winactivate,% "ahk_id " pwb.hwnd
}

navigateChrome(url){
	static urlPrefix := "http://192.0.2.10:8089/nodulePic/"
	sl=300
	oldclipboard:=ClipboardAll
	firstURL := ""

	winactivate,ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe
	WinWaitActive,ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe,,2
	if (ErrorLevel)
		return

	; Try to find existing tab by rotating through tabs
	; We check up to 20 tabs
	found := false
	Loop, 20
	{
		currentURL := GetActiveBrowserURL()
		if showLungCAD_UrlStartsWith(currentURL, urlPrefix)
		{
			found := true
			break
		}

		; If we've seen this URL before and we've looped, we might be stuck
		if (A_Index > 1 && currentURL == firstURL)
			break
		if (A_Index == 1)
			firstURL := currentURL

		Send ^{Tab}
		Sleep 35
	}

	if (found)
	{
		; Focus address bar more reliably
		Send !d
		Sleep 20
		clipboard := url
		Send ^v{Enter}
		Sleep 100
		if (GetActiveBrowserURL()!=url) {
			Send !d
			Sleep 20
			clipboard := url
			Send ^v{Enter}
		}
	}
	else
	{
		; Not found, open new tab
		Send ^t
		Sleep 60
		clipboard := url
		Send ^v{Enter}
		Sleep 100
	}

	clipboard:=oldclipboard
}

showLungCAD_UrlStartsWith(url, prefix){
	return SubStr(url, 1, StrLen(prefix)) = prefix
}

ifwinexist,ahk_class MozillaWindowClass
{
	winactivate,ahk_class MozillaWindowClass
	WinWaitActive,ahk_class MozillaWindowClass,,2
}else ifwinexist,ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe
{
	WinActivate,ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe
	WinWaitActive,ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe,,2
}else{
	openNew:=false
	gosub openNewChromeOrFirefox
	if(openNew="firefox" && !err){
		WinActivate,ahk_class MozillaWindowClass
		WinWaitActive,ahk_class MozillaWindowClass,,2
	}else if(openNew="chrome" && !err){
		WinActivate,ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe
		WinWaitActive,ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe,,2
	}else if (err){

		MsgBox,,, % "The URL is copied. Please paste in FireFox or Chrome browser.",5
		return
	}
}

Sleep 500
if !InStr(activeUrl:=GetActiveBrowserURL(),ip) && activeUrl!="" {
	send ^t
	Sleep 200
}
send !d
sleep 200
send ^v
sleep 200
send {enter}
recoverClip:
;~ clipboard:=pClip
;~ ExitApp
return

openNewChromeOrFirefox:
	appPath:=""
	Loop,% a_desktop "\*.lnk"
		if InStr(A_LoopFileName, "firefox"){
			FileGetShortcut,% A_LoopFileFullPath, appPath
			break
		}
	if(appPath!=""){
		run % """" appPath """ """ url """"
		err:=ErrorLevel
			,openNew:="firefox"
		return
	}
	Loop,% A_DesktopCommon "\*.lnk"
		if InStr(A_LoopFileName, "firefox"){
			FileGetShortcut,% A_LoopFileFullPath, appPath
			break
		}
	if(appPath!=""){
		run % """" appPath """ """ url """"
		err:=ErrorLevel
			,openNew:="firefox"
		return
	}
	Loop,% a_desktop "\*.lnk"
		if InStr(A_LoopFileName, "chrome"){
			FileGetShortcut,% A_LoopFileFullPath, appPath
			break
		}
	if(appPath!=""){
		run % """" appPath """ """ url """"
		err:=ErrorLevel
			,openNew:="chrome"
		return
	}
	Loop,% A_DesktopCommon "\*.lnk"
		if InStr(A_LoopFileName, "chrome"){
			FileGetShortcut,% A_LoopFileFullPath, appPath
			break
		}
	if(appPath!=""){
		run % """" appPath """ """ url """"
		err:=ErrorLevel
			,openNew:="chrome"
		return
	}
	MsgBox,,, % "Please open Firefox or Chrome first!",5
	openNew:=false
return

fail:
	;~ msgbox,,,Not found!,3
	MsgBox, 4164, ,% "Lung CAD not processed or study not found in SyngoVia?",60
;~ IfMsgBox,Yes
;~ gosub sendChartNo
;~ goto recoverClip
return

noResult:
	MsgBox,,,% "No lesion found by CAD !",3
;~ goto recoverClip
return

SHA1dash(str){
	str:=SHA(str)
	stringlower,str,str
	return substr(str,1,8) "-" substr(str,9,8) "-" substr(str,17,8) "-" substr(str,25,8) "-" substr(str,33,8)
}

next:
prior:
	; Repeated presses choose the latest target. Wait for the previous OCR or
	; browser operation to release input before starting that selection.
	INFINITT_OCR_RequestAbort()
	showLungCAD_LogNavigation("HOTKEY " A_ThisLabel)
	showLungCAD_UpdateINFINITTTargetFromMouseIfViewerMonitor()
	gosub HideGUI
	key:=A_ThisLabel
		,lastfound:=InStr(A_ThisHotkey, "^")?"syngovia":"magic"
	gosub changeIm
return

changeIm:
	if !showLungCAD_SetCycleIndex(key)
		return
changeIm2:
	showLungCAD_ChangeNodule()
return

showLungCAD_ChangeNodule(){
	global
	local navigationInd:=thisInd, navigationUrl:="", navigationStarted:=A_TickCount
	local navigationNodule, navigationPid

	if (showLungCAD_BrowserNavigationActive) {
		showLungCAD_LogNavigation("WAIT FOR BROWSER", navigationStarted)
		SetTimer, showLungCAD_JumpToNoduleDeferred, -50
		return
	}
	; Return promptly to the interrupted OCR thread so it can release input.
	; Browser tab scans must not hold that thread suspended while it aborts.
	if (ShowInImpax && showLungCAD_ShouldUseINFINITTOCR() && OCR_RUN_ACTIVE) {
		showLungCAD_LogNavigation("WAIT FOR OCR", navigationStarted)
		SetTimer, showLungCAD_JumpToNoduleDeferred, -50
		return
	}
	if (ShowInBrowser && nodulePicExists) {
		navigationNodule:=jsonData.Nodules[navigationInd-1]
		navigationPid:=navigationNodule.hasKey("noduleIndBeforeSort")?navigationNodule.noduleIndBeforeSort+1:navigationInd
		navigationUrl:=showLungCAD_CadPidUrl(currentUrl, navigationPid)
		currentUrl:=navigationUrl
	}

	if (EBMmode)
		gosub EBMselect
	if ShowInImpax {
		showLungCAD_LogNavigation("PACS BEGIN", navigationStarted)
		gosub pacsSelect
		showLungCAD_LogNavigation("PACS END", navigationStarted)
	}
	; A newer hotkey may interrupt the OCR scroll and select another nodule.
	if (thisInd != navigationInd)
		return
	if (ShowInBrowser && nodulePicExists) {
		showLungCAD_LogNavigation("BROWSER BEGIN", navigationStarted)
		ShowCadBrowserUrl(navigationUrl, false)
		showLungCAD_LogNavigation("BROWSER END", navigationStarted)
	}
	if (ShowInBrowser && nodulePicExists && !ShowInImpax) {
		ShowCadBrowserWindow()

	}
}

showLungCAD_LogNavigation(stage, started:=0){
	global INFINITTOCRDebug, thisInd, OCR_RUN_ACTIVE
	if !INFINITTOCRDebug
		return
	path:=A_ScriptDir "\Lib\OCR\Navigation_Log_" SubStr(A_Now, 1, 8) ".txt"
	elapsed:=started ? A_TickCount-started : 0
	FileAppend,% A_Now " tick=" A_TickCount " | " stage " | Nodule=" thisInd " | OCRActive=" (OCR_RUN_ACTIVE ? 1 : 0) " | ElapsedMs=" elapsed "`n",% path
}

showLungCAD_IsNavigatingChrome(){
	global showLungCAD_BrowserNavigationActive
	return showLungCAD_BrowserNavigationActive && WinActive("ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe")
}

showLungCAD_StopINFINITTRefresh(viewer){
	if IsObject(viewer.INFINITTViewer)
		viewer.INFINITTViewer.SetTimer("RefreshInfo", "Delete")
}

showLungCAD_CadPidUrl(url, pid){
	if RegExMatch(url, "pid=\d+")
		return RegExReplace(url, "pid=\d+", "pid=" pid)
	return RegExReplace(url, "#.*$") "#&gid=1&pid=" pid
}

activeWin:=WinExist("A")
MouseGetPos,beforeScrollX,beforeScrollY
if WinExist("ahk_class MozillaWindowClass ahk_exe firefox.exe")
	browser:="ahk_class MozillaWindowClass"
else if WinExist("ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe")
	browser=ahk_class Chrome_WidgetWin_1
else
	return
WinActivate,%browser%
WinWaitActive,,,2

RegExMatch(currentUrl:=GetActiveBrowserURL(), "(?<=pid=)\d+$", lastInd)
	,repeat:=false
WinGetPos,bx,by,bw,bh,% browser
if (LastFound="syngovia"){
	mousemove,% bx+bw-100,% by+Floor(bh/2),0
	Sleep 15
	send % (key="prior")?"{WheelUp}":"{WheelDown}"
	Sleep 15
}else{
	mouseclick,L,% bx+bw-10,% by+Floor(bh/2),1,0
	Sleep 15
	send % (key="next")?"{Right}":"{Left}"
	Loop {
		Sleep 35
	}until currentUrl!=GetActiveBrowserURL() || A_Index>10

	thisInd:=key="next"?nextInd(lastInd):priorInd(lastInd)
	repeat:=thisInd=1

}
;~ sleep 100
mousemove,% beforeScrollX,% beforeScrollY,0
WinActivate,ahk_id %activeWin%

if (lastFound!="syngovia")
	gosub pacsSelect

if (repeat && !First)
	MsgBox,,,% "Back to first picture!",2
First:=false
return

pacsSelect:
	if showLungCAD_ShouldUseINFINITTOCR()
		gosub infinittSelect
	else
		gosub impaxSelect
return

showLungCAD_ShouldUseINFINITTOCR(){
	global __is_CH, thisPacsViewer
	if !__is_CH
		return false
	if !WinExist("ahk_exe G3PACS.exe")
		return false
	if IsObject(thisPacsViewer) && InStr(thisPacsViewer.Type, "INFINITT")
		return true
	WinGet, pName, ProcessName, A
	return pName~="i)G3PACS\.exe"
}

infinittSelect:
	global coord
	if (OCR_RUN_ACTIVE) {
		INFINITT_OCR_RequestAbort()
		SetTimer, showLungCAD_JumpToNoduleDeferred, -50
		return
	}
	CoordMode, Mouse, Screen
	ebm_show_x:=ebm_show_y:=""
	if !ShowInImpax
		return
	if (jsonData.AccessionNumber!=AccNo) || nodCount<=0
		return
	if (ShowNoduleList)
		lastX:=lastY:=""

	selectedInd:=thisInd
	nodule:=jsonData.Nodules[selectedInd-1]
	hwnd:=showLungCAD_GetINFINITTHwnd()
	if (!hwnd) {
		ToolTip % "INFINITT viewer not found."
		SetTimer,ToolTip,-2000
		return
	}
	WinActivate, ahk_id %hwnd%
	WinWaitActive, ahk_id %hwnd%,,2
	showLungCAD_KeepInfoGUIsOnTop()
	viewportHwnd:=showLungCAD_GetINFINITTViewport(hwnd)
	if (!viewportHwnd) {
		ToolTip % "INFINITT image viewport not found."
		SetTimer,ToolTip,-2000
		return
	}
	WinGetPos,vx,vy,vw,vh,% "ahk_id " viewportHwnd
	mx:=vx+Round(vw*nodule["X-Ratio"])
	my:=vy+Round(vh*nodule["Y-Ratio"])
	coord:=[mx,my]
	MouseMove,% mx,% my,0
	showLungCAD_LogNavigation("MOUSE MOVED")

	; Physical input should abort an automatic OCR scroll, but these global
	; hooks must not remain active during normal RDP use.
	showLungCAD_SetManualAbortHotkeys(true)
	try {
		if (nodule.HasKey("SliceLocation") && nodule.SliceLocation!="")
			scrollResult:=INFINITT_OCR_Scroll({SP: nodule.SliceLocation}, "", {parentHwnd: hwnd, viewportHwnd: viewportHwnd, mouseX: mx, mouseY: my, calibrationKey: AccNo})
		else if (nodule.HasKey("InstanceNumber") && nodule.InstanceNumber!="")
			scrollResult:=INFINITT_OCR_Scroll({Img: nodule.InstanceNumber}, "", {parentHwnd: hwnd, viewportHwnd: viewportHwnd, mouseX: mx, mouseY: my, calibrationKey: AccNo})
		else {
			ToolTip % "No INFINITT scroll target in CAD JSON."
			SetTimer,ToolTip,-2000
			return
		}
	} finally {
		showLungCAD_SetManualAbortHotkeys(false)
	}
	if (INFINITT_OCR_WasAborted() || thisInd != selectedInd)
		return
	if (!IsObject(scrollResult) || !scrollResult.ok) {
		ToolTip % "Target slice not verified. Please retry or scroll manually."
		SetTimer,ToolTip,-2500
		return
	}

	cross.show(mx, my)
	OnScreenDisplay(selectedInd, 400, 50, "white")
	DisplayNoduleInfo(selectedInd, true)
	First:=false
return

showLungCAD_KeepInfoGUIsOnTop(){
	global reporthwnd, noduleListHwnd
	if showLungCAD_ShouldSuppressCadGUI() {
		showLungCAD_HideCadGUIs()
		return
	}
	if (reporthwnd && WinExist("ahk_id " reporthwnd))
		WinSet, AlwaysOnTop, On, ahk_id %reporthwnd%
	if (noduleListHwnd && WinExist("ahk_id " noduleListHwnd))
		WinSet, AlwaysOnTop, On, ahk_id %noduleListHwnd%
}

showLungCAD_GetINFINITTHwnd(){
	global thisPacsViewer
	targetMonitor:=showLungCAD_ResolveINFINITTTargetMonitor(false)
	if (hwnd:=showLungCAD_GetINFINITTHwndOnMonitor(targetMonitor))
		return hwnd
	if (targetMonitor!=2) {
		if (hwnd:=showLungCAD_GetINFINITTHwndOnMonitor(2))
			return hwnd
	}
	WinGet, activeHwnd, ID, A
	WinGet, activeProcess, ProcessName, ahk_id %activeHwnd%
	if (activeProcess ~= "i)G3PACS\.exe")
		return activeHwnd
	try {
		hwnd := thisPacsViewer.INFINITTViewer.hwnd
		if (hwnd && WinExist("ahk_id " hwnd))
			return hwnd
	}
	return GetLeftmostINFINITTHwnd()
}

showLungCAD_MouseMonitorIndex(){
	CoordMode, Mouse, Screen
	MouseGetPos, mx, my
	monitors:=monitorInfo()
	which:=whichMonitor(mx, my, monitors)
	if IsObject(which)
		return which.1
	return 0
}

showLungCAD_ResolveINFINITTTargetMonitor(updateFromMouse:=false){
	global showLungCAD_INFINITTTargetMonitor
	if (updateFromMouse) {
		mouseMonitor:=showLungCAD_MouseMonitorIndex()
		showLungCAD_INFINITTTargetMonitor:=(mouseMonitor=3) ? 3 : 2
		return showLungCAD_INFINITTTargetMonitor
	}
	if (showLungCAD_INFINITTTargetMonitor=2 || showLungCAD_INFINITTTargetMonitor=3)
		return showLungCAD_INFINITTTargetMonitor
	return showLungCAD_ResolveINFINITTTargetMonitor(true)
}

showLungCAD_UpdateINFINITTTargetFromMouseIfViewerMonitor(){
	global showLungCAD_INFINITTTargetMonitor
	mouseMonitor:=showLungCAD_MouseMonitorIndex()
	if (mouseMonitor=2 || mouseMonitor=3) {
		showLungCAD_INFINITTTargetMonitor:=mouseMonitor
		return mouseMonitor
	}
	return showLungCAD_ResolveINFINITTTargetMonitor(false)
}

showLungCAD_GetINFINITTHwndOnMonitor(monitorIndex:=2){
	monitors:=monitorInfo()
	if (!IsObject(monitors) || !IsObject(monitors[monitorIndex]))
		return 0
	mon:=monitors[monitorIndex]
	best:=0, bestArea:=0
	WinGet, list, List, ahk_exe G3PACS.exe
	Loop, %list% {
		thisHwnd:=list%A_Index%
		WinGet, style, Style, ahk_id %thisHwnd%
		if !(style & 0x10000000)
			continue
		WinGetClass, class, ahk_id %thisHwnd%
		; INFINITT's MFC class prefix varies by build/architecture (for example,
		; Afx:0000000140000000: on the current viewer). Keep the check scoped to
		; an INFINITT PACS top-level window rather than one exact class string.
		if (!RegExMatch(class, "^Afx:"))
			continue
		WinGetTitle, title, ahk_id %thisHwnd%
		if (!InStr(title, "INFINITT PACS"))
			continue
		WinGetPos, x, y, w, h, ahk_id %thisHwnd%
		if (w <= 300 || h <= 300)
			continue
		cx:=x + (w//2), cy:=y + (h//2)
		if (cx < mon.l || cx > mon.r || cy < mon.t || cy > mon.b)
			continue
		area:=w*h
		if (area > bestArea)
			best:=thisHwnd, bestArea:=area
	}
	return best
}

showLungCAD_GetINFINITTViewport(hwnd){
	try {
		; These methods only enumerate controls with an explicit parent HWND.
		; Constructing INFINITT_PACS also starts a permanent RefreshInfo timer.
		viewport:=INFINITT_PACS.getViewportControl("image", hwnd)
		if (viewport)
			return viewport
	}
	return 0
}

impaxSelect:
	ebm_show_x:=ebm_show_y:=""
	if EBMmode || (chartNo~="i)^[H]")
		goto EBMselect
	if !ShowInImpax
		return
	if (ShowNoduleList){
		WinGetPos,lastX,lastY
		WinHide,ahk_id %noduleListHwnd%
	}

	MouseGetPos,,,,mCon,2
	if !(ControlGetText(mCon)~="Screen_\d+_format_\d+_Position_\d+_\d+")
		return
	SEIM:=getSEIM()

	if (jsonData.AccessionNumber=AccNo) && nodCount>0 {
		nodule:=jsonData.Nodules[thisInd-1]
		if ((originalThickness:=jsonData.spacing[3])=""){
			if RegExMatch(jsonData.spacing, "\[[\d\.]+\, *[\d\.]+\, *([\d\.]+)\]", match)
				originalThickness:=match1
			else
				originalThickness:=1.0
		}

		if (preloadedAccNo!="") || (lastAccNo!=AccNo)
			thickSliceMode:=!(SEIM.1=jsonData.SeriesNumber)
				, z:=(SEIM.1=jsonData.SeriesNumber)?(nodule.InstanceNumber):Round(nodule.InstanceNumber*originalThickness/5)
		else
			z:=!thickSliceMode?(nodule.InstanceNumber):Round(nodule.InstanceNumber*originalThickness/5)

		if z<1
			z:=1
		coord:=impaxSelectImageCurrent(nodule["X-Ratio"], nodule["Y-Ratio"], z)
		if (coord){
			cross.show(coord.1, coord.2)
				,OnScreenDisplay(thisInd, 400, 50, "white")
				,DisplayNoduleInfo(thisInd, SEIM.1=jsonData.SeriesNumber)
		}

		;~ if (!ShowInBrowser && thisInd=1 && !First)
		;~ MsgBox,,,% "Back to first picture!",2

		First:=false
	}

return

EBMselect:
	if (ShowNoduleList){
		WinGetPos,lastX,lastY
		WinHide,ahk_id %noduleListHwnd%
	}
	if (jsonData.AccessionNumber=AccNo) && nodCount>0 {
		nodule:=jsonData.Nodules[thisInd-1]
		if ((originalThickness:=jsonData.spacing[3])=""){
			if RegExMatch(jsonData.spacing, "\[[\d\.]+\, *[\d\.]+\, *([\d\.]+)\]", match)
				originalThickness:=match1
			else
				originalThickness:=1.0
		}
		MouseGetPos,mx,my

		IMnumber:= nodule.InstanceNumber
			,IMinfo:=originalThickness=1?IMnumber " (1mm)":IMnumber " , " Floor((IMnumber-1)*originalThickness + 1) " (1mm)"
			,IMinfo.=" , " Floor((IMnumber-1)*originalThickness/3 + 1) " (3mm)`n" (StrLen((s:=Floor((IMnumber-1)*originalThickness/5 + 1)))<3?" ":"") s " (5mm) , " Floor((IMnumber-1)*originalThickness/2.5 + 1) " (2.5mm)"

		coord:=[]
			,coord.1:=mx, coord.2:=my
			,which:=whichMonitor("", "", monitorInfo).1
			,ebm_show_x:=nodule["X-Ratio"]<0.5?Floor(monitorInfo[which].l+monitorInfo[which].w*2/3):Floor(monitorInfo[which].l+monitorInfo[which].w/8)
			,ebm_show_y:=nodule["Y-Ratio"]<0.5?Floor(monitorInfo[which].t+monitorInfo[which].h*2/3):Floor(monitorInfo[which].t+monitorInfo[which].h/4)
		OnScreenDisplay("# " thisInd "`n" IMinfo "`n( X , Y ) = ( " Floor(512*nodule["X-Ratio"]) " , " Floor(512*nodule["Y-Ratio"]) " )", 120000, 50, "CCCCCC", "Verdana", [monitorInfo[which].l+10, monitorInfo[which].b-500])
			,DisplayNoduleInfo(thisInd, true)

		;~ if (!ShowInBrowser && thisInd=1 && !First)
		;~ MsgBox,,,% "Back to first picture!",2

		First:=false
	}

return

^!q::
exitapp
return

OnExit:
gosub disconnectSocket
for k,pwb in pwbs
	pwb.quit()
ExitApp

dismiss:
	if (A_ThisHotkey ~= "i)Esc" && INFINITT_OCR_RequestAbort())
		return
	winget,pActiveHwnd,id,A
	ControlGetFocus,pActiveControl,A
	if WinVisible(reporthwnd)
		WinHide,% "ahk_id " reporthwnd
	else if WinVisible(noduleListHwnd) {
		MouseGetPos,lastX,lastY
		WinHide,% "ahk_id " noduleListHwnd
	}else
		return

	if (A_ThisHotkey~="F\d"){
		MouseGetPos,lastX,lastY
		WinHide,% "ahk_id " noduleListHwnd
		WinHide,% "ahk_id " reporthwnd
		for k, pwb in pwbs
		{
			WinHide,% "ahk_id " pwb.hwnd
			WinMinimize,% "ahk_id " pwb.hwnd
			WinShow,% "ahk_id " pwb.hwnd
		}

	}
	OnScreenDisplay("", 1,1,"white")
	winget,pName,ProcessName,% "ahk_id " pActiveHwnd
	if(pName~= MatchPacsProcessName() "|Menu.exe"){
		winactivate,% "ahk_id " pActiveHwnd
		ControlFocus,% pActiveControl,% "ahk_id " pActiveHwnd
	}

return

showLungCAD_AbortOCRForManualInput:
	; Click/drag commands issued by the OCR routine can arrive through the same
	; mouse hook as a real user action.  Ignore only that command's short grace
	; period; physical input immediately afterwards still cancels the OCR run.
	if (OCR_IGNORE_MANUAL_ABORT_UNTIL && A_TickCount <= OCR_IGNORE_MANUAL_ABORT_UNTIL)
		return
	if INFINITT_OCR_RequestAbort()
		showLungCAD_SetManualAbortHotkeys(false)
return

showLungCAD_SetManualAbortHotkeys(enabled){
	static manualAbortInputs := "WheelUp,WheelDown,WheelLeft,WheelRight,LButton,LButton Up,RButton,MButton,XButton1,XButton2"
	static registered := false, currentlyEnabled := false
	enabled := enabled ? true : false
	if (registered && enabled=currentlyEnabled)
		return
	state := enabled ? "On" : "Off"
	Loop,Parse,manualAbortInputs,`,
		Hotkey,% "$~*" Trim(A_LoopField),showLungCAD_AbortOCRForManualInput,% state
	registered := true
	currentlyEnabled := enabled
}

#IfWinExist,WM_COPYDATA_Listener_RegionGrowMorph
		~+LButton_:
		;~ ToolTip % "OCR for corner info, please wait ... "
		settimer,LButton_Shift,-500
		settimer,LButtonUP,100
		gosub HideGUI
		which:=whichMonitor("", "", monitorInfo)
			,frames:=getViewFrame()
		if !NoCaptureText
			info:=getImpaxFrameInfo(frames[which.1-1,1,1], "LL")
		else
			info:={}

		;~ MsgBox % exploreobj(info)
		;~ ToolTip
		return

		LButton_Shift:
			if GetKeyState("Shift") && GetKeyState("Lbutton") {
				MouseGetPos,x,y
				Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_RegionGrowMorph"), 25, jxon_dump({"start":1
					, "mouse_pos": [x,y]}))
			}

		LButtonUp:
			if !GetKeyState("LButton") {
				settimer,LButton_Shift,Off
				settimer,LButtonUp,Off
				Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_RegionGrowMorph"), 25, jxon_dump({"end":1
					, "mouse_pos": [x,y]}))

			}
		return

	#IfWinExist

#IfWinActive,ahk_exe Menu.exe
	~*F3::
		lastX:=lastY:=""
		WinHide,% "ahk_id " reporthwnd
		WinHide,% "ahk_id " noduleListHwnd
	return
#IfWinActive

~Rbutton::
	mousegetpos,,,win,con,2
	if(win==reporthwnd || win==noduleListHwnd) && !instr(WinGetClass(con),"edit"){
		winhide,% "ahk_id " reporthwnd
		winhide,% "ahk_id " noduleListHwnd
	}
return

reset:
	currentUrl:=jsonPostData:=magicUrl:="", jsonData:=[]
	WinHide,% "ahk_id " noduleListHwnd
	WinHide,% "ahk_id " reporthwnd
	getPwb(1).Visible:=false
	getPwb(2).Visible:=false
return

RisImpaxStateChange(w,l,m,h){
	;~ ToolTip % m
	global preloadedChartNo
	if (preloadedChartNo!=(new activePacs).getChartNo())
		gosub reset
}

RisAccNoChange(w,l,m,h){
	global
	hasChest:=false
	for k,v in getRisExamItemsAll()[1]
		if (v~="i)chest|lung|thora") && (v~="\bCT\b") && !(v~="i)guide|needle|local") {
			hasChest:=true
			break
		}

	if !hasChest
		return
	isPreloading:=true
	gosub magicResult
}
