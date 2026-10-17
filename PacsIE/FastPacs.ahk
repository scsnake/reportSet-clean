#MaxMem 4095
/*
	scsnake@gmail.com
*/

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
SetBatchLines, -1
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
SetTitleMatchMode,2
SetControlDelay,-1
DetectHiddenWindows,on
ComObjError(false)
onexit,onexit
#InstallKeybdHook

__debug:=true


try
	Menu,tray,icon,% A_ScriptDir "\B.ico"


if %0% {
	param:=ParseArg()
	for k,v in param {
		if(v="-fast"){
			fastMode:=1
		}else if(v="-turbo"){
			turboMode:=1
		}
	}
	
}
start_over:
; press shift in 1.5 seconds to activate fast mode (no old film, no recent RIS report search)
;~ ToolTip % "Press SHIFT for FAST MODE!"
wait:=Re_Init?15:10

;~ Loop {
	;~ if (shiftPressed:=GetKeyState("Shift")) || (AltPressed:=GetKeyState("Alt"))
		;~ break
	;~ Sleep 100
;~ }until A_Index >wait
;~ if (shiftPressed) {
	;~ fastMode:=true
	;~ ToolTip % "FAST MODE !"
	;~ settimer, ToolTip,-2000
;~ }else if (AltPressed) {
	;~ turboMode:=true
	;~ ToolTip % "TURBO MODE !"
	;~ settimer, ToolTip,-2000
;~ }else{
	;~ fastMode:=false
	;~ turboMode:=false
	;~ ToolTip 
;~ }

; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <PortalLib>
#include <JXON>
#include <WM_COPYDATA>
#include <DoublyLinkedList>
#include <CryptFileRead>
#Include %A_ScriptDir%
#include jpegDirName.ahk

if CryptFilePW()
	ExitApp

OnMessage(0x4a, "On_WM_COPYDATA")
,onmessage(0x10504,"next")
,onmessage(0x10503,"prior")
,onmessage(0x10101,"exit")
,onmessage(0x10201,"exit")
,OnMessage(0x10202,"activateMain")
,OnMessage(0x10203,"sendReport")
,OnMessage(0x10204,"openImpax")

,thisHwnd:=WinExist("ahk_pid " thisPid := DllCall("GetCurrentProcessId"))
,RISImpaxRegister([  {app: "Ris", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x1122}, func: "accNoChanged", initStart: 100}])
,dwData:=17
,miniPACS_instances:=8
,reportList:=[]
,root:=substr(a_scriptdir,1,1)
,ini:=a_scriptdir "\PacsIE.ini"
,sid:=askForPortalIdPw()
,fastReportQ:=new Queue()
,turboHotkeyState:=!!turboMode
,resultPath:=(InStr(A_ScriptFullPath,"reportSet")?(A_ScriptFullPath "\..\"):(SubStr(A_ScriptDir,1,2) "\scripts\Autorun\")  ) "searchOpHxResults.txt"
GroupAdd,EBM,ahk_exe WEBVIE~1.exe
GroupAdd,EBM,ahk_exe WebViewerComSrvEC.exe

;setting
iniread,reportDir,% ini,Settings,暫存資料夾
if !instr(fileexist(reportDir),"D")
	reportDir:=a_mydocuments "\feedRIS"


;~ run % A_ScriptDir "\decryptJpeg.exe"
;~ gosub openMiniPACS



gui,main:Default
gui,new
gui,+hwndguihwnd  -Resize -Caption +AlwaysOnTop
WinSetTitle,% "ahk_id " guihwnd,,FastPacs_main
GroupAdd,mainGui,ahk_id %guihwnd%
gui,Font,s12,Calibri
gui,Add,Text,,Data source
gui,Add,Radio,vdatasource,RIS list (All)
gui,Add,Radio,,RIS list (Selected)
gui,Add,Radio,checked,Clipboard

gui,Add,Text,,Filter
gui,Add,Radio,vopt,CXR/KUB/Spine
gui,Add,Radio,,Ortho films
gui,Add,Radio,checked,All
if fileexist(resultPath)
		gui,Add,Radio,,Last results
gui,add,Text,,Filter2
gui,add,Radio,vopt2,Downloaded
gui,add,Radio,checked,All

gui,Add,Text,,Mode
gui,Add,Radio,vmode checked,Normal
gui,Add,Radio,,Fast
gui,Add,Radio,,Turbo
if(fastMode)
	guicontrol,,Fast,1
if (turboMode)
	guicontrol,,Turbo,1

gui,Add,Text,,Report VS?
gui,Add,Radio,vreportvs checked,All
gui,Add,Radio,,Self only


gui,Add,button,ggo Default,Go!
gui,Add,button,gexit yp x+30,Exit

gui,Show,Center
if __debug
	ControlClick,Go!,% "ahk_id " guihwnd
return
GuiClose:
GuiEscape:
ExitApp
return

#IfWinActive,ahk_group mainGui
esc::
exit:
ExitApp
#IfWinActive

go:
gui,Submit
if (Mode==1)
	fastMode:=turboMode:=false
else if(Mode==2)
	fastMode:=true, turboMode:=false
else if(Mode==3)
	fastMode:=false, turboMode:=true

filter:="filter" opt
, filter_2:= "filter_2_" opt2
, filter_3:="filter_3_" (reportvs)

if(opt=4)
	lastResults:=CryptFileRead(resultPath, ____, true)

gosub getReportListData

;~ winwait,WM_COPYDATA_Listener_miniPACS
gosub openOthers
if !__debug
settimer,routine,500



;~ GroupAdd,MyGUI,ahk_exe python.exe
;~ GroupAdd,MyGUI,ahk_exe miniPACS.exe

GroupAdd,MyGUI,ahk_exe impax-client-main.exe
GroupAdd,MyGUI,ahk_exe WebViewerComSrvEC.exe
GroupAdd,MyGUI,ahk_exe WEBVIE~1.EXE


gosub setHotKey
gosub checkRisOpened

;~ ,boneKeywords:=["rib","fracture","bone","bony","\bsclero","lytic"]
;~ ,lungKeyWords:=["(lung|pulmonary) (nodule|mass|tumor|lesion|metasta)"]
;~ ,cancerKeywords:=["cancer","malignant","malignancy","lymphoma","leukemia","tumor"]

if fastMode || turboMode
	gosub setfastreport

if turboMode
	gosub setTurboHotkey


Menu, Tray, Add, Re-init, Re_Init
Menu, Tray, Default, Re-init 
notrayorphans()

return




Filter1(v){
	global examNameCol
	return (v[examNameCol]~="i)^chest|^abdomen|spine")
}
filter2(v){
	return !Filter1(v)
}
filter3(v){
	return true
}
filter4(v){
	global AccNoCol, lastResults
	return InStr(lastResults, v[AccNoCol])
}
filter_2_1(v){
	global AccNoCol,ChartNoCol,reportDir
	accNo:=v[AccNoCol], chartNo:=v[ChartNoCol]
	
	return % (FileExistValid(jpegFile:=jpegDirName(reportDir, AccNo, chartNo, AccNo, chartNo)) && isValidJpeg(jpegFile)) || FileExistValid(jpegFile:=jpegDirName(reportDir, AccNo, chartNo, AccNo, chartNo, 1, ".jpeg_"))
	
}
filter_2_2(v){
	return true
}
filter_3_1(v){
	return true
}
filter_3_2(v){
	global reportvsCol
	return InStr(v[reportvscol], "陳醫師")
}
getReportListData:
;~ loop {
	;~ sleep 100
;~ }until getListenerHwnd() || a_index>30
;~ if(h:=getListenerHwnd())
	;~ winminimize,ahk_id %h%
risState:=risopened()
;~ if (risState[1]!=2){
	;~ showErrorAndExit("Open RIS first.`nThis application will exit.")
;~ }
if !WinExist("ahk_id " RisHwnd:=RisState[2])
	RisHwnd:=risopened(1)[2][1]
reportList:=[]

;~ Loop 3 {
winactivate,ahk_id %risHwnd%
winwaitactive,ahk_id %risHwnd%,,3
goReportTab(risHwnd,2)
if (datasource==1)
	reportListOriginal:=ParseDataGrid2("", RisHwnd)
else if(datasource==2)
	reportListOriginal:=parseDataGrid2("", RisHwnd,"", "", false, false, false, true)
else if (datasource==3)
	reportListOriginal:=parseDataGrid2("", RisHwnd,"", "", true, false, false, true)

;~ if (reportListOriginal.length())
	;~ break
;~ else
	;~ Sleep 100

;~ }

statusCol:=reportListOriginal.getColNo("status")
	,ChartNoCol:=reportListOriginal.getColNo("ChartNo")
	,AccNoCol:=reportListOriginal.getColNo("AccNo")
	,ExamDateCol:=reportListOriginal.getColNo("ExamDate")
	,ExamNameCol:=reportListOriginal.getColNo("ExamName")
	,reportvsCol:=reportListOriginal.getColNo("ReportVS")
,reportListForFeed:=[]
,reportList.push(reportListOriginal[1])
,reportListForFeed.push(reportListOriginal[1])
,RisListHwnd:=getRisList(RisHwnd)

for k,v in reportListOriginal.data
	if (k==1){
		continue
	}else if (v[statusCol]!="已發報告") {
		reportListForFeed.push(v)
		if (!FileExistValid(jpegDirName(reportDir, v[AccNoCol] , v[ChartNoCol]) ".txt")) && (%filter%(v)) && (%filter_2%(v)){
			if (!FileExistValid(reportDir "\" v[AccNoCol] " " v[ChartNoCol] ".txt") && !FileExistValid(reportDir "\" __CryptStr(v[AccNoCol] " " v[ChartNoCol],____) ".txt"))
				reportList.push(v)
		}
	}
		
reportList:=new DataGridTable(reportList, reportListOriginal.titles)
,reportListCount:=reportList.maxindex()
return


fastReport:
ghotkey:=SubStr(A_ThisHotkey,3,1)
fastReport1:
if(ghotkey="z"){
	msgbox % exploreobj(fastSendStr)
}else if (fastReportText:=fastSendStr[InStr(ghotkeys, ghotkey)]){
	vacant:=fastReportQ.isEmpty()
	;~ str:=""
	;~ Loop 3
		;~ str.=fastReportQ.get(A_Index) "`n"
	;~ ToolTip % str
	
	
	if (vacant){
		if (repeat_times>1){
			sendReport1(thisAccNo:=miniPACS_simulator.AccNo, thisChartNo:=miniPACS_simulator.ChartNo, fastReportText, repeat_times)
		}else {
			fastReportQ.enqueue(fastReportText)
			gosub sendreport
		}
		
	}else
		Loop % repeat_times
			fastReportQ.enqueue(fastReportText)
	
	;~ if !controlexist(editHwnd)
		;~ controlget,editHwnd,hwnd,,Scintilla1,simple RIS ahk_class AutoHotkeyGUI
	;~ Edit_SetText(editHwnd, fastReportText)
	;~ if !WinExist("ahk_id " miniPacs_bridge_hwnd)
		;~ miniPacs_bridge_hwnd:=WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI")
	;~ PostMessage,0x10203,,,,ahk_id %miniPacs_bridge_hwnd%
}
return

turboHotkey_cont:
turboHotkey:
repeat_times:=InStr(A_ThisLabel, "_cont")?(!!InStr(A_ThisHotkey, "+"))*4:1
,ghotkey:=turboHotkeyPairs["" RegExReplace(A_ThisHotkey, "i)[^" turboHotkeyKeys "]", "")]
if (ghotkey!="")
	gosub fastReport1
return


setTurboHotkey:
target:="turboHotkey"
,turboHotkeyKeys:=   "123qweasdzxc456rtyfgh"
,turboHotkeyValues:="123thrafgscbweqzxdijl"
,turboHotkeyPairs:={}
,CancelTurboHotkey:="i"
Loop,parse,turboHotkeyKeys
{
	turboHotkeyPairs["" A_LoopField]:="" SubStr(turboHotkeyValues,A_Index,1)
	Hotkey,% A_LoopField,% target,% turboHotkeyState?"on":"off"
	Hotkey,% "+" A_LoopField,% target "_cont",% turboHotkeyState?"on":"off"
}
Loop,parse,CancelTurboHotkey
{
	Hotkey,% A_LoopField,% target,% turboHotkeyState?"on":"off"
}
Hotkey,+#t,toggleTurboHotkey
ToolTip % "TurboHotkey is " (turboHotkeyState?"ON":"OFF") "!"
Click up 2
settimer,ToolTip,-2000
return

toggleTurboHotkey:
if (turboHotkeyState:=!turboHotkeyState)
	WinHide,simple RIS ahk_class AutoHotkeyGUI
else
	settimer,activateSimpleRIS_2,-1
gosub setTurboHotkey
return

;~ esc::ExitApp

setfastreport:
fastSendStr:=["lung consolidation.", "increased interstitial infiltration of lung.", "increased hazy densities of lung."
	,"no significant pulmonary nodular lesion identified.", "pleural effusion.", "ill-defined opacities of lung."
	, "non-specific bowel gas.", "prominent bowel gas.", "post-operative change(s)."
	, "renal stone(s).",  "gallstone(s).", "status post double-J catheter insertion."
	, "pneumothorax.", "pulmonary nodular lesion(s).", "prominent hilar shadow."
	, "(N/A).", "fracture(s).", "degenerative change."
	, "(N/A).", "no obvious displaced fracture.", "normal alignment."]
,ghotkeys:="123thrafgscbweqzxdijl"
Loop,parse,ghotkeys
	Hotkey,% "+!" A_LoopField,fastReport,on
return

Re_Init:
send_data("miniPACS", {reset_all: 1})
,send_data("getAllJpeg", {reset:1})
,Re_Init:=true
;~ Sleep 1000
;~ initiateMiniPacs()
gosub start_over
return

routine:
WinClose,ahk_exe Hotstring Helper.exe

return

findStartAccNo:
if(datasource=3 && !WinExist("ahk_id " RisHwnd)){
	currentAccNo:=reportList.getCell(2, "AccNo")
}else
	currentAccNo:=getRisAccNo(RisHwnd)

currentRow:=reportList.getRow("AccNo", currentAccNo)
if (currentRow.rowNo){
	thisStudyInd:=currentRow.rowNo
}else{
	thisStudyInd:=2
}
ToolTip % Format("FastPacs: `n`ttotal {} RIS rows`n`ttotal {} unreported`n`tstart from #{} study`n`tESC to cancel"
			, reportListOriginal.length()-1, reportList.length()-1, thisStudyInd-1)
KeyWait,esc,D T1
if !ErrorLevel {
	ToolTip
	ToolTip % "FastPacs: canceled" 
	Sleep 1000
	ExitApp
}
ToolTip
;~ winwait,getAllJpeg_main ahk_class AutoHotkeyGUI,,30
;~ if ErrorLevel
	;~ showErrorAndExit("Can't open getAllJpeg!")


;~ winwait,WM_COPYDATA_Listener_portalLib,,30
;~ if ErrorLevel
	;~ showErrorAndExit("Can't open pyPortal!")
;~ winwait,WM_COPYDATA_Listener_miniPACS,,30
;~ if ErrorLevel
	;~ showErrorAndExit("Can't open miniPACS!")
;~ send_data("getAllJpeg", {reportList: reportList.data})
;~ ,send_data("getAllJpeg", {start_from: thisStudyInd})
;~ ,send_data("miniPACS", {reset_all: 1})
;~ Sleep 1000
initiateMiniPacs()
;~ ,settimerF("send_data", -2000, ["miniPACS", {reportList: reportList.data}])
;~ ToolTip % total_study_count:=reportList.maxindex()-1
;~ t:=""
;~ for k, v in reportList
	;~ t.=v[reportList.colnos["ChartNo"]] "`n"
;~ clipboard:=



send_data("miniPACS", {total_study_count: reportList.maxindex()-1})
for k,v in reportList.data {
	d:={study_data:1}
	,d[k]:={AccNo: v[AccNoCol], ChartNo: v[ChartNoCol]}
	,send_Data("miniPACS", d)
	
}

;~ Sleep 3000
send_data("miniPACS", {start_from: thisStudyInd-2})
	

if !fastMode && !turboMode
	gosub getOldHx

;~ winminimize,% "ahk_id " impaxopened()[2,1]
return

class miniPACS_simulation {
	__New(){
		global loginid, loginpw
		this.study_list:=[]
		,this.viewers:=[]
		,this.viewers2:=[]
		,this.viewer_index:=0
		,this.old_hx_list:=[]
		,this.study_index:=0
		,this.preloadFn:=ObjBindMethod(this, "preload")
		,this.preloadGEFn:=ObjBindMethod(this, "preloadGE")
		,this.preloadWebFn:=ObjBindMethod(this, "preloadWeb")
		,this.hospitalCode:=""
		,this.AccNo:=""
		,this.ChartNo:=""
		,this.monitors:=monitorInfo()
		,this.UseWebPacs:=true
		
	}
	Invoke(json_data){
		if json_data.haskey("study_data") {
			for k, l in json_data
				if (k != "study_data")
					this.study_list[k+0] := l
		}else if json_data.haskey("oldHx") {
			for k,v in json_data["oldHx"]
				this.old_hx_list[k]:=v
		}else if json_data.haskey("next_study") {
			case := (json_data["next_study"])+0
			if case = 1
				this.next_study()
			else if case > 1
				this.next_study(case, True)
			else
					this.prior_study()
		}else if json_data.haskey("next_image") {
			;~ case := (json_data["next_image"])+0
			;~ this.viewers[this.viewer_index].emit("change_image", case, json_data["x"], json_data["y"])
		}else if json_data.haskey("activate_main") {
			;~ this.emit("activate_main")
		}else if json_data.haskey("setBridgeHwnd") {
			;~ this.bridge_hwnd := (json_data["setBridgeHwnd"])+0
		}else if json_data.haskey("total_study_count") {
			this.total_study_count := (json_data["total_study_count"])+1
			;~ this.progressWin.total_count := this.total_study_count
		}else if json_data.haskey("request_info") {
			;~ v = this.viewers[this.viewer_index]
			;~ d = {}
			;~ d["request_info"] = 1
			;~ d["from"] = json_data["from"]
			;~ d["AccNo"] = v.AccNo
			;~ d["ChartNo"] = v.ChartNo
			;~ Send_WM_COPYDATA(this.bridge_hwnd, json.dumps(d), ImageViewerApp.dwData)
			;~ if json_data["from"] == "open_impax":
					;~ this.emit(SIGNAL("hide_all"))
		}else if json_data.haskey("downloadPortalJpeg") {
			;~ threading.Thread(target=this.portal.pacsMobileNewDownloadJpeg,
											 ;~ args={"accNo": json_data["accNo"],
														 ;~ "chartNo": json_data["chartNo"],
														 ;~ "flatten": True,
														 ;~ "folder": this.folder_path})
		}else if json_data.haskey("sendReportEnd") {
			;~ this.progressWin.next_study(json_data["sendReportEnd"])
		}else if json_data.haskey("fast_mode") {
			this.fast_mode := !!(json_data["fast_mode"])
			,this.fast_mode_change()
		}else if json_data.haskey("turbo_mode") {
			this.turbo_mode := !!(json_data["turbo_mode"])
			,this.fast_mode_change()
		}else if json_data.haskey("start_from") {
			this.emit("next_study", json_data["start_from"]+2)
		}else if json_data.haskey("reset_all") {
			;~ this.reset()
		}else if json_data.haskey("setHospitalCode") {
			this.hospitalCode:=json_data["setHospitalCode"]
			,this.check_env()
		}
	}
	clearWin(){
		for k,v in this.viewers
			WinClose, % "ahk_id " v.hwnd
		for k,v in this.viewers2
			WinClose, % "ahk_id " v.hwnd
		this.viewers:=[]
		,this.viewers2:=[]
	}
	
	fast_mode_change(){
		global __debug
		this.UseWebPacs:=true
		
		if(this.turbo_mode){
			if (this.win_conf="turbo")
				return
			this.clearWin()
			,xw:=[1,0,0,1,0,1,1,0]
			,yh:=[0,0,1,1,1,1,0,0]
			Loop % this.total_viewer_count:=8 {
				i:=A_Index-1
				,m:=this.monitors[mod(i//4,2)+2]
				,w:=Floor(m.w/2)
				,h:=Floor(m.h/2)
				,x:=m.l+xw[Mod(i,8)+1] * w
				,y:=m.t+yh[j] * h
				
				,pwb:=ComObjCreate("InternetExplorer.Application")
				,pwb.Toolbar:=pwb.Menubar:=false
				WinSet, Style, -0xC00000, % "ahk_id " pwb.hwnd
				WinSet, Style, -0x40000, % "ahk_id " pwb.hwnd
				WinMove,% "ahk_id " pwb.hwnd,,% x, % y,% w,% h
				if __debug
					pwb.Visible:=true, pwb.Navigate("http://portal.hospital-n.local")
				
				this.viewers.push(pwb)
			}
			this.win_conf:="turbo"
		}else if(this.fast_mode || this.viewer_type="ge"){
			if (this.win_conf="fast")
				return
			this.clearWin()
			
			Loop % this.total_viewer_count:=4 {
				i:=A_Index-1
				,m:=this.monitors[mod(i,2)+2]
				,w:=m.w
				,h:=m.h
				,x:=m.l
				,y:=m.t
				
				,pwb:=ComObjCreate("InternetExplorer.Application")
				,pwb.Toolbar:=pwb.Menubar:=false
				WinSet, Style, -0xC00000, % "ahk_id " pwb.hwnd
				WinSet, Style, -0x40000, % "ahk_id " pwb.hwnd
				WinMove,% "ahk_id " pwb.hwnd,,% x, % y,% w,% h
				if __debug
					pwb.Visible:=true, pwb.Navigate("http://portal.hospital-n.local")
				
				this.viewers.push(pwb)
			}
			this.win_conf:="fast"
		}else{
			if (this.win_conf="normal")
				return
			this.clearWin()
			
			,this.viewers2:=[] ; for old film
			,this.total_viewer_count:=3
			Loop % this.total_viewer_count*2 {
				i:=A_Index-1
				,m:=this.monitors[mod(i,2)+2]
				,w:=m.w
				,h:=m.h
				,x:=m.l
				,y:=m.t
				
				,pwb:=ComObjCreate("InternetExplorer.Application")
				,pwb.Toolbar:=pwb.Menubar:=false
				WinSet, Style, -0xC00000, % "ahk_id " pwb.hwnd
				WinSet, Style, -0x40000, % "ahk_id " pwb.hwnd
				WinMove,% "ahk_id " pwb.hwnd,,% x, % y,% w,% h
				if __debug
					pwb.Visible:=true, pwb.Navigate("http://portal.hospital-n.local")
				;~ msgbox % pwb.hwnd
				if mod(i,2)=0
					this.viewers.push(pwb)
				else
					this.viewers2.push(pwb)
				;~ msgbox % pwb.hwnd
				;~ msgbox % this.viewers[1].hwnd
			}
			this.win_conf:="normal"
		}
	}
	
	
	
	check_env(){
		global loginid, loginpw
		if(this.UseWebPacs){
			this.sid:=askforportalidpw()
			,this.loginId:=loginId
			,this.loginPw:=loginPw
			,this.viewer_index:=1	
			,this.viewer_type:="webpacs"
			if !this.total_viewer_count
				this.fast_mode_change()
		}else if (this.hospitalCode~="T4|Y0"){
			if StrLen(askforportalidpw(0,true, this.hospitalCode="T4"?"H":"Y", false))>2
				this.loginId:=loginId
				,this.loginPw:=loginPw
				,this.total_viewer_count:=10
				,this.viewers:=EBMWebPacsLogin_IE(loginId, loginpw, this.hospitalCode="T4"?"HC":"YL", "", this.total_viewer_count)
				,this.viewer_index:=1
				,this.viewer_type:="ebm"
		}else if (this.hospitalCode="C0"){
			this.sid:=askforportalidpw()
			,this.loginId:=loginId
			,this.loginPw:=loginPw
			,this.viewer_index:=1	
			,this.viewer_type:="ge"
			if !this.total_viewer_count
				this.fast_mode_change()
		}else{
			this.loginId:=loginId
			,this.loginPw:=loginPw
			,this.viewer_type:="impax"
			Loop {
				if((Impax:=ImpaxOpened())[1]=1){
					for k,v in controls:=GetControls(impaxHwnd:=Impax[2,1])
					if (v.classNN="WindowsForms10.EDIT.app.0.2bf80982") {
						controlsettext,,% this.loginid,% "ahk_id " v.hwnd
						break
					}
					for k,v in controls
					if (v.classNN="WindowsForms10.EDIT.app.0.2bf80981") {
						controlsettext,,% this.loginpw,% "ahk_id " v.hwnd
						break
					}
					for k,v in controls
					if (v.classNN="WindowsForms10.BUTTON.app.0.2bf80981") {
						controlfocus,,% "ahk_id " v.hwnd
						controlsend,,{enter},% "ahk_id " v.hwnd
						break
					}
				}
				Sleep 1000
			} until (impaxopened()[1]=2) || GetKeyState("ESC")
		}
	}
	emit(fn, args*){
		try
			this[fn](args*)
	}
	next_study(from_ind="", jump=false){
		if (from_ind!="")
			thisStudyInd:=jump?this.study_index+from_ind:from_ind
		else
			thisStudyInd:=this.study_index+1
		
		if thisStudyInd>this.total_study_count
			return this.exit()
		
		this.show_study(thisStudyInd)
	}
	prior_study(from_ind="", jump=false){
		thisStudyInd:=this.study_index-1
		
		if thisStudyInd<0
			return 
		
		this.show_study(thisStudyInd, false)
	}
	
	show_study(study, from_next=true){
		if (this.UseWebPacs){
			this.show_study_web(study, from_next, false)
		}else if (this.hospitalCode~="T4|Y0"){
			this.show_study_ebm(study, from_next)
		}else if (this.hospitalCode~="C0"){
			this.show_study_web(study, from_next, true)
		}else{
			this.show_study_impax(study, from_next)
		}
		settimer,activateSimpleRIS_2,-500
	}
	
	next_viewer_index(diff=1){
		return mod(this.viewer_index+diff-1, this.total_viewer_count)+1
	}
	
	
	show_study_web(study, from_next=true, GEviewer=false){
		if(this.showing)
			return
		this.showing:=true
		,s:=this.study_list[study]
		,this.AccNo:=AccNo:=s["AccNo"]
		,this.ChartNo:=ChartNo:=s["ChartNo"]
		WinHide,% "ahk_id " this.viewers[this.viewer_index].hwnd
		pwb:=this.viewers[this.viewer_index:=mod(this.viewer_index,this.total_viewer_count)+1]
		,pwb.Visible:=true
		WinShow,% "ahk_id " pwb.hwnd
		if (GEviewer){
			if !InStr(#(pwb, "titleBar-text-patientDemographicInfo").title, AccNo)
				this.loadWeb(s, this.viewer_index, true)
		}else{
			if !InStr(#(pwb, "StudyMenuS0ViewLine2BlackBg").innerText, AccNo)
				this.loadWeb(s, this.viewer_index, false)
		}
			
			

		WinActivate,% "ahk_id " pwb.hwnd
		WinGetPos,x,y,w,h,% "ahk_id " pwb.hwnd
		MouseMove,% Floor(x+w/2),% Floor(y+h/2),0
		this.showing:=false
		if(GEViewer){
			preloadGEFn:=this.preloadGEFn
			Settimer % preloadGEFn, -300	
		}else{
			preloadWebFn:=this.preloadWebFn
			settimer % preloadWebFn, -300
		}
	}
	loadWeb(study, viewer_index, GEViewer=false){
		s:=study
		,accNo:=s.AccNo
		,chartNo:=s.ChartNo
		,pwb:=this.viewers[viewer_index]
		if (GEViewer){
			url:=getGEZFPurl(this.sid, accNo, chartNo)
		}else{
			if !this.PacsWebLoginNew
				PacsWebLoginNew(AccNo,chartNo, this.loginid, this.loginpw)
				,this.PacsWebLoginNew:=true
			url:=PacsWebUrl(AccNo,chartNo, this.loginid, this.loginpw)
		}
		
		pwb.Navigate(url)
	}
	preloadGE(){
		Loop % this.total_viewer_count-2 {
			s:=this.study_list[this.study_index+A_Index]
			if !(AccNo:=s.AccNo) 
				return
			viewer_index:=mod(this.viewer_index+A_Index-1, this.total_viewer_count)+1
			if !InStr(#(this.viewers[viewer_index], "titleBar-text-patientDemographicInfo").title, AccNo)
				this.loadWeb(s, viewer_index, true)
		}
	}
	preloadWeb(){
		Loop % this.total_viewer_count-2  {
			s:=this.study_list[this.study_index+A_Index]
			if !(AccNo:=s.AccNo) 
				return
			viewer_index:=mod(this.viewer_index+A_Index-1, this.total_viewer_count)+1
			if !InStr(#(this.viewers[viewer_index], "titleBar-text-patientDemographicInfo").title, AccNo)
				this.loadWeb(s, viewer_index, false)
		}
	}
	
	
	show_study_ebm(study, from_next=true){
		if(this.showing)
			return
		this.showing:=true
		,s:=this.study_list[study]
		,this.AccNo:=AccNo:=s["AccNo"]
		,this.ChartNo:=ChartNo:=s["ChartNo"]
		,viewer:=new EBMViewer(chartNo)
		
		if(viewer.hwnd){
			WinShow,% "ahk_id " viewer.hwnd
			this.study_index:=study
			,this.showing:=false
			return
		}
		
		if (!from_next){
			EBMWebPacsQuery_IE(accno, this.viewers[this.next_viewer_index(-1)], chartNo)
			;~ ImpaxContextServer_Add(AccNo)
			;~ ,ImpaxContextServer_Show(AccNo)
			;~ ,this.study_index:=study
			;~ ,this.showing:=false
			;~ return
			return
		}
		
		
		Loop 10 
			EBMWebPacsQuery_IE(accno, this.viewers[this.next_viewer_index(A_Index)], chartNo)
		;~ preloadFn:=this.preloadFn
		;~ Settimer % preloadFn, -500
		this.study_index:=study
		,this.showing:=false
	}
	
	show_study_impax(study, from_next=true){
		if(this.showing)
			return
		this.showing:=true
		,s:=this.study_list[study]
		,this.AccNo:=AccNo:=s["AccNo"]
		,this.ChartNo:=ChartNo:=s["ChartNo"]
		
		if (!from_next){
			ImpaxContextServer_Add(AccNo)
			,ImpaxContextServer_Show(AccNo)
			,this.study_index:=study
			,this.showing:=false
			return
		}
		
		ImpaxContextServer_Show(AccNo)
		Loop {
			Sleep 50
		}until (impaxShown:=(getImpaxAccNo()=AccNo)) || A_Index>20
		
		if (!impaxShown){
			if (getImpaxQueueNumber()>100) {
				ImpaxContextServer_ClearDisplay()
				Sleep 500
			}
			ImpaxContextServer_Add(AccNo)
			,ImpaxContextServer_Show(AccNo)
			,preloadFn:=this.preloadFn
			Settimer % preloadFn, -500
		}
		
		this.study_index:=study
		,this.showing:=false
	}
	preload(){
		if(this.preloading)
			return
		this.preloading:=true
		Loop % 20 {
			if (ind:=this.study_index+A_Index) > this.total_study_count
				break
		
			accNo:=this.study_list[ind].AccNo
			if (accNo!="")
				ImpaxContextServer_Add(AccNo)
		}
		ImpaxContextServer_Show(this.study_list[this.study_index].AccNo)
		this.preloading:=false
	}
	exit(){
		msgbox,4,, % "Already last study!`nExit?"
		IfMsgBox,Yes
		{
			ImpaxContextServer_ClearDisplay()
			ExitApp
		}
			
	}
	__Delete(){
		this.clearWin()
	}
}


send_data(app, data){
	global dwData, miniPACS_simulator
	
	if(app="miniPACS"){
		miniPACS_simulator.Invoke(data)
		return
	}else if (app="feedRIS"){
		if !(hwnd:=WinExist("ahk_exe feedRIS.exe")){
			run % "feedRIS.exe"
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
	ToolTip % app ": " A_TickCount
	settimerF("send_data", -1000, [app, data])
	return -1
}

getOldHx:


if (thisStudyInd>reportList.maxindex()){
	settimer,,-1000
	return
}
if (thisStudyInd>reportListCount)
	return

;~ thisStudy:=reportList[thisStudyInd]
;~ ,WorkerThread%A_Index%:=new CWorkerThread("getOldHxWorkerThread")
;~ ,WorkerThread%A_Index%.start(thisStudyInd)

;~ activeFn++
;~ SetTimerFn("getOldHxWorkerThread", -1, [thisStudyInd])
loadHistory(thisStudyInd)
,thisStudyInd++
settimer,getOldHx,-1000
return

getOldHxWorkerThread(ind){
	global activeFn
	loadHistory(ind)
	;~ ,activeFn--
}

getListenerHwnd(){
	return WinExist("WM_COPYDATA_Listener_miniPACS")
	;~ if h1:=WinExist("WM_COPYDATA_Listener ahk_exe python.exe")
		;~ return h1
	;~ else if h2:=WinExist("WM_COPYDATA_Listener_miniPACS")
		;~ return h2
}

getPyPortalHwnd(){
	return WinExist("WM_COPYDATA_Listener_portalLib")
}

openMiniPACS:


;~ if !getPyPortalHwnd() && !WinExist("pyPortal.exe") {
	;~ pyPortalPath:=A_ScriptDir "\pyPortal.exe"
	;~ if !FileExist(pyPortalPath){
		;~ msgbox % "Cannot found pyPortal.exe!"
		;~ ExitApp
	;~ }
	;~ run % pyPortalPath
	;~ winwait,ahk_exe pyPortal.exe,,3
;~ }


if !getListenerHwnd() && !WinExist("miniPACS.exe") {
	miniPacsPath:=A_ScriptDir "\miniPACS.exe"
	if !FileExist(miniPacsPath){
		msgbox % "Cannot found miniPACS.exe!"
		ExitApp
	}
	run % miniPacsPath " " miniPACS_instances
	;~ winwait,WM_COPYDATA_Listener,,30
	;~ if(ErrorLevel){
		;~ msgbox % "Error opening miniPACS.exe"
		;~ ExitApp
	;~ }
}
;~ winwait,WM_COPYDATA_Listener_portalLib


;~ Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_portalLib")
		;~ , dwData
		;~ , jxon_dump({miniPACS_hwnd: WinExist("WM_COPYDATA_Listener_miniPACS")+0}))
;~ ,Send_WM_COPYDATA(WinExist("WM_COPYDATA_Listener_portalLib")
			;~ , dwData
			;~ , jxon_dump({portalLogin: 1, loginId: loginId, loginPw: loginPw}))

;~ miniPacsHwnd:=WinExist("ahk_exe miniPACS.exe")

return

openImpax(){
	gosub openInImpax
}

On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
; dwData = Command
; cbData = String lenght
; lpData = String
	Critical
	global AccNoCol, examDateCol, examNameCol, ChartNoCol, statusCol, loadSavedReportInfo, fastMode, thisReportListIndex, thisAccNo, thisChartNo, reportList, fastReportQ, turboMode
	;~ static lastTick
	dwData := NumGet(lParam+0, 0)
	,cbData := NumGet(lParam + A_PtrSize)
	,lpData := NumGet(lParam + 2*A_PtrSize)
	,lpData := StrGet(lpData)
	;~ msgbox % lpData
	try
		json:=jxon_load(lpData)
	catch 
		return
	;~ clipboard:=lpData "`n`n`n"
	;~ ToolTip % exploreObj(json)
	
	
	if (from:=json.from)!="" {
		if(from="open_impax")
			settimerF("openInImpax", -1, [json.AccNo])
		else if(from="sendReport"){
			;~ thisTick:=A_TickCount
			;~ if !(thisTick-lastTick<1000)
				settimerF("sendReport1",-1, [json.AccNo, json.ChartNo])
			;~ lastTick:=thisTick
		}
	}else if (json.sendReport){
		;~ thisTick:=A_TickCount
		;~ if !(thisTick-lastTick<1000)
			settimer,sendReport,-1
		;~ lastTick:=thisTick
	}else if(json.activateSimpleRIS){
		settimer,activateSimpleRis,-1
	}else if(json.activateSimpleRIS_2){
		settimer,activateSimpleRIS_2,-1
	}else if(json.exit){
		;~ WinGet,pname,ProcessName,WM_COPYDATA_Listener
		
		;~ WinClose,ahk_exe %pname%
		
		ExitApp
	}else if(json.AccNoCol){
		for k,v in ["AccNoCol", "examDateCol", "examNameCol", "ChartNoCol", "statusCol"]
			%v%:=json[v]
	}else if(json.showStudy){
		;~ json:=parseCurrentStudyInfo()
		 ;~ if !json
			;~ return
		;~ thisReportListIndex:=json.index+2
		thisAccNo:=json.AccNo
		,thisChartNo:=json.ChartNo
		if (json.w)
			moveSimpleRIS(json)
		send_data("getAllJpeg", {current_miniPACS_index: json.index+2})
		, loadSavedReportInfo:= [json.index+2, json.AccNo]
		;~ settimer,loadSavedReport, -500
		if !fastReportQ.isEmpty()
			settimer,sendreport,-1
		settimer,activateSimpleRIS_2,% fastMode||turboMode?(-1):(-500)
	}else if(json.haskey("request")){
		send_data("getAllJpeg", {request: json.request+2})
	
	}else if(json.haskey("reach_end")){
		settimer,exitMsgActivate,-1000
		msgbox,260,,% "Already last study!`nExit?"
		IfMsgBox,Yes
			ExitApp
	}else
		parseReportListData(json)
		;~ SetTimerFn("parseReportListData" , -1 [json])
	;~ ,sendData("received")	

}

exitMsgActivate:
winactivate,Already last study
return

parseCurrentStudyInfo(){
	WinGetTitle,t,CurrentStudy ahk_exe miniPACS.exe
		json:=RegExReplace(t, "^CurrentStudy: ", "")
		try
			return json:=jxon_load(json)
		catch 
			return
}

moveSimpleRIS(monitor_pos){
	m:=monitor_pos
	WinGetPos,x,y,w,h,simple RIS ahk_class AutoHotkeyGUI
	if x>m.x && x<m.x+m.w
		return 
	WinMove,simple RIS ahk_class AutoHotkeyGUI,,% Floor(m.x+(m.w-w)/2),% y,% w,% h
}

initiateMiniPacs(){
	global
	miniPACS_simulator:=new miniPACS_simulation
	,miniPACS_simulator.check_env()
	,send_data("miniPACS", {setBridgeHwnd: guiHwnd+0})
	;~ ,send_Data("pyPortal", {setBridgeHwnd: guiHwnd+0})
	;~ ,send_Data("pyPortal", {portalLogin: 1, loginId: loginid, loginPw: loginpw})
	if turboMode
		send_data("miniPACS", {turbo_mode: 1})
	else if fastMode
		send_data("miniPACS", {fast_mode: 1})
	else
		send_data("miniPACS", {fast_mode: 0})
	;~ ,send_data("miniPACS", {fast_mode: 0})
}


loadSavedReport:
loadSavedReport()
return
loadSavedReport(){
	
	global reportList, AccNoCol, reportDir, ChartNoCol, loadSavedReportInfo, ____
	index:=loadSavedReportInfo[1]
	,AccNo:=loadSavedReportInfo[2]
	,row:=reportList.getRow(index)
	if (row.getCell("AccNo")!=AccNo)
		return
	controlget,editHwnd,hwnd,,Scintilla1,simple RIS ahk_class AutoHotkeyGUI
	if !FileExistValid(path:=jpegDirName(reportDir , AccNo , row.getCell("ChartNo")) ".txt"){
		
		;~ if Trim(Edit_getText(editHwnd))!=""
			;~ Edit_SetText(editHwnd, t:="")
		return
	}
		
	
	fileread,r,% path
	r:=__CryptStr(r,____, 0)
	
	,Edit_SetText(editHwnd, r:=RegExReplace(r, "s)\r?\n-=-=-=-=-\r?\n.*$", ""))
	,edit_setsel(editHwnd, l:=StrLen(r), l)
	,Edit_ScrollCaret(editHwnd)
}


parseReportListData(json){
	global reportList, reportListLoaded
	;~ ToolTip % str
	
	
	;~ msgbox % ExploreObj(json)
	
	for k,v in json
		reportList[k+0]:=v
		,reportListLoaded++
	gosub findStartAccNo
	;~ ToolTip % reportListLoaded
}

sendData(str){
	if(h:=WinExist("ahk_exe getAllJpeg.exe"))
		Send_WM_COPYDATA(h, 0, str)

}


activateMain(){
	global 
	active:=true
	send_data("miniPACS", {"activate_main":1})
	winminimize,% "ahk_id " impaxopened()[2,1]
}

MinimizeMain(){
	global 
	local arr
	critical
	;~ gui,%shownGuiInd%: show
	if (!shownGuiInd)
		shownGuiInd:=1
	arr:=[simpleRis:=WinExist("simple RIS ahk_class AutoHotkeyGUI"), reportInfoHwnd, hxHwnd, info1hwnd, info2hwnd, guiHwnd[shownGuiInd], filterHwnd]
	Loop % totalGUI-1
		arr.push(guiHwnd[Mod(shownGuiInd+A_Index-1, totalGUI)+1])
	
	for k,v in arr
		winminimize,% "ahk_id " v
	
}

openOthers:
;~ if (!offlineMode && !winexist("ahk_exe getAllJpeg.exe")){
	;~ run,% """" a_scriptdir "\getAllJpeg.exe"" """ A_ScriptDir "\getAllJpeg.ahk""" (fastMode||turboMode?" -noOldFilm":" ") " " thisHwnd	
;~ }

;~ if !winexist("ahk_exe feedRIS.exe") && risopened()[1]=2
	;~ run % a_scriptdir "\feedRIS.exe"
if !winexist("ahk_exe simpleRIS.exe"){
	run % a_scriptdir "\simpleRIS.exe"
	;~ simpleRisOpened:=1
	winwait,simple RIS ahk_class AutoHotkeyGUI,,10
}
PostMessage,0x2025,0,,,simple RIS ahk_class AutoHotkeyGUI


return

showErrorAndExit(msg, exitapp=1, return=0){
	MsgBox, 4144, ,% msg
	if exitapp
		exitapp
	else
		return % return
}

setHotKey:
iniread,showChartNo,% ini,Settings,showChartNo,1
iniread,showAccNo,% ini,Settings,showAccNo,1
iniread,addNormalHeartSize,% ini,Settings,addNormalHeartSize,0
iniread,addReassignDate,% ini,Settings,addReassignDate,0


iniread,noAdditionalHotkey,% ini,Settings,noAdditionalHotkey,0
if(noAdditionalHotkey)
	return 

iniread,sendReportKey,% ini,Settings,發送,;
iniread,activateSimpleRisKey,% ini,Settings,activateSimpleRisKey,CapsLock
iniread,loadSavedReportKey,% ini,Settings,loadSavedReportKey,^u
try {
	hotkey,ifwinactive,simple RIS ahk_class AutoHotkeyGUI
	hotkey,% sendReportKey,sendReport,
	Hotkey,% loadSavedReportKey,loadSavedReport
	hotkey,ifwinactive
	hotkey,IfWinExist,ahk_group MyGUI
	hotkey,% sendReportKey,sendReport,
	Hotkey,IfWinExist
	
	hotkey,% activateSimpleRisKey " UP",activateSimpleRis,P10
	if(activateSimpleRisKey="CapsLock"){
		settimer,setcapslockstate,500
		hotkey,% "#" activateSimpleRisKey,toggleCapslockState,P10
	}
}catch e{
	tooltip % e.Message
}
;~ if !winexist("ahk_exe PacsIEMain.exe") {
	;~ hotkey,~!#q,guiclose,P10
;~ }
return

setcapslockstate:
SetCapslockstate,% capslockstate?"on":"off"
return

toggleCapslockState:
capslockstate:=!capslockstate
gosub setcapslockstate
return

sendReport(wParam, lParam, msg, hwnd){
	;~ ToolTip % "SEND"
	;~ global 
	;~ ptick:=A_TickCount
	gosub sendReport
}



sendReport:
;~ ToolTip miniPACS_bridge
;~ send_data("miniPACS", {"request_info":1, "from": "sendReport"})
sendReport1(thisAccNo:=miniPACS_simulator.AccNo, thisChartNo:=miniPACS_simulator.ChartNo)
return

keepSimpleRisActiveReset:
keepSimpleRisActive:=false
return

sendReport1(AccNo, ChartNo, report_txt="", repeat_times=1){
	local fastReportText
	settimer,keepSimpleRisActiveReset,off
	keepSimpleRisActive:=true
	settimer,keepSimpleRisActiveReset,-3000
	;~ msgbox
	;~ msgbox % A_TickCount-ptick
	;~ ptick:=A_TickCount
	;~ msgbox % accno "," chartNo
	fastReportText:=fastReportQ.isEmpty()?"":fastReportQ.dequeue()
	if (fastReportText="" && report_txt=""){
		if lastSendReport && (A_TickCount-lastSendReport<500) && (lastSendReport:=A_TickCount)
			return
		
		if (!editHwnd || !controlexist(editHwnd))
			controlget,editHwnd,hwnd,,Scintilla1,simple RIS ahk_class AutoHotkeyGUI
		if !controlexist(editHwnd)
			return
		if ((text:=trim(controlgettext(editHwnd)))="") || !(Text~="\w")
			return
	}else if(report_txt!=""){
		Text:=report_txt
	}else {
		Text:=fastReportText
		,fastReportText:=""
	}
	
	Text:=RegExReplace(Text, "[ \;]+$", ".")
	,Text:=RegExReplace(Text, "i)\/(placement|metal)", ".$1")
	,Text:=RegExReplace(Text, "i)placement of", ".placement of")
	if InStr(Text, "suggest clinical correlation.")
		Text:=RegExReplace(Text, "i)\; +suggest clinical correlation\.+", "") ". suggest clinical correlation. "
		,Text:=RegExReplace(Text, "i)suggest clinical correlation\.+", "") "suggest clinical correlation. "
	if RegExMatch(Text, "i)\.?\w+\/?placement", match) && !InStr(match, "replacement"){
		MsgBox, 4404, Typo in report, Continue?
		IfMsgBox,No
			return
	}
	ToolTip
	;~ for k, v in reportList
		;~ if v[AccNoCol]=AccNo
			;~ break
	assign_txt:=""
	reportListRow:=reportList.getRow("AccNo", AccNo)
	,thisStudyInd:=reportListRow.rowNo
	;~ msgbox % k
	,examDate:=RegExReplace(reportListRow.getCell("ExamDate"), "\D" ,"")
	;~ msgbox % examDate
	now:=A_Now
	now-=examDate, Days
	if addReassignDate && (examDate!="" && now>90 && !InStr(Text, "this study is reassigned to current radiologist on "))
		assign_txt:="this study is reassigned to current radiologist on " A_YYYY "/" a_mm "/" a_dd ". "
	checkReport(text assign_txt, AccNo, ChartNo, ExamName:=reportListRow.getCell("ExamName"))
	
	
	Loop % repeat_times-1 {
		thisStudyInd++
		,reportListRow:=reportList.getRow(thisStudyInd)
		,examDate:=RegExReplace(reportListRow.getCell("ExamDate"), "\D" ,"")
		,AccNo:=reportListRow.getCell("AccNo")
		,ChartNo:=reportListRow.getCell("ChartNo")
		if (AccNo="" || chartNo ="")
			continue
		now:=A_Now
		now-=examDate, Days
		if addReassignDate && (examDate!="" && now>90 && !InStr(Text, "this study is reassigned to current radiologist on "))
			assign_txt:="this study is reassigned to current radiologist on " A_YYYY "/" a_mm "/" a_dd ". "
		checkReport(text assign_txt, AccNo, ChartNo, ExamName:=reportListRow.getCell("ExamName"))
	}
	
	;~ msgbox % examname
	;~ controlsettext,,% "",ahk_id %editHwnd%
	;~ Edit_SetText(editHwnd, "")
	send_data("miniPACS", {"sendReportEnd": repeat_times})

	postmessage,0x2024,,,,simple RIS ahk_class AutoHotkeyGUI
	
	nextStudy(repeat_times)
	
	postmessage,0x1011,,,,feedRIS ahk_class AutoHotkeyGUI
	;~ if !fastMode
		;~ SoundBeep
	;~ msgbox % A_TickCount-ptick
	;~ PostMessage,0x2028,,,,simple RIS ahk_class AutoHotkeyGUI
	;~ ControlFocus,,ahk_id %editHwnd%
	if turbo_mode
		WinHide,simple RIS ahk_class AutoHotkeyGUI
	else
		settimer,activateSimpleRIS_2,-500
	;~ postmessage,0x2028,,,,simple RIS ahk_class AutoHotkeyGUI
	;~ keepSimpleRisActive:=false
	return
}
checkReport(text, AccNo, ChartNo, examName){
	global reportDir,offlineMode,editHwnd,title, shownGuiInd, ____
	Exam:=ExamName,thisAccNo:=AccNo,thisChartNo:=ChartNo
	;~ msgbox % superior aspect of	am "," thisAccNo "," thisChartNo
	;~ text:=RegExReplace(text,"\.+",".")
	text:=RegExReplace(text,"\ {2,}(?!(-+ |\d+\W ))"," ")
	,text:=RegExReplace(text,"(?<=[\,\.\;\(])\ {2,}"," ")
	;~ ,text:=RegExReplace(text," {2}"," ")
	,text:=RegExReplace(text,"\.{2,}",".")
	,text:=RegExReplace(text,",{2,}",",")
	,text:=RegExReplace(text,"\.\,",",")
	,text:=RegExReplace(text,"\,\.",".")
	,text:=RegExReplace(text,"\.\/",". ")
	,text:=RegExReplace(text,"\ ([,.;])","$1")
	,text:=RegExReplace(text,"i)([a-z])\. ([a-z])","$1.$2")
	,text:=RegExReplace(text,"([,;])(\w)","$1 $2")
	,text:=RegExReplace(text,".\ {2,}(\r?\n)",". $1")
	,text:=RegExReplace(text,"(^(\r?\n)+)|((\r?\n)+$)","")
	,text:=RegExReplace(text,"at at","at ")
	,text:=RegExReplace(text," *\b[a-zA-Z]\. *"," ")
	,text:=RegExReplace(text," +"," ")
	;~ ,Text:=RegExReplace(Text, "i)\/(placement)", ".$1")
	;~ text:=RegExReplace(text,"(\.)  +(\w)",". $2")
	,newText:=""
	,incomplete:=0
	loop,parse,text,`.
		if regexmatch(a_loopfield,"\w"){
			;~ if strlen(line:=trim(a_loopfield))<5
				;~ incomplete:=1
			newText.=stringupper(substr(trim(a_loopfield),1,1)) substr(trim(a_loopfield),2) ". "
		}else{
			newText.=trim(a_loopfield) ". "
		}
	newText:=substr(newText,1,-2)
	,newText:=RegExReplace(newText,"(\d). (\d)","$1.$2")
	,newText:=RegExReplace(newText,"\. \)",".)")
	,newText:=RegExReplace(newText,"(?<!\n) {2,}"," ")
	,newText:=RegExReplace(newText,"[\.\ ]+$",".")
	
	
	
	
	
	,selStart:=0
	loop,parse,nexText,`.
		if strlen(line:=trim(a_loopfield))<5 && regexmatch(line,"^[a-z]+\d*?$") {
			incomplete:=1
			break
		}else{
		selStart+=strlen(a_loopfield)+1
	}
	
	if (incomplete){
		settimer,moveMsgBox,20
		msgbox,4144,,% "Check the report for AHK error!"
		;~ controlsettext,,% newText,ahk_id %editHwnd%
		Edit_SetText(editHwnd, newText)
		,Edit_setsel(editHwnd,seltStart,selStart+strlen(line))
		,Edit_ScrollCaret(editHwnd)
		return -1
	}
		
	filedelete,% filePath:=reportDir "\" __CryptStr(thisAccNo " " thisChartNo, ____) ".txt"
	if instr(newText, "(N/A).") {
		fileappend,% "(N/A).",% filePath,utf-8
		FileSetAttrib,+H,% filePath
	}else{
		fileappend,% __CryptStr(addTitle(newText,Exam,thisAccNo,thisChartNo) "`r`n-=-=-=-=-`r`n",____),% filePath,utf-8
	}
	tooltip % "Saved !"
	settimer,tooltip,-1000
}	

addTitle(newText,exam="",accNo="",chartNo=""){
	global showAccNo, showChartNo, addNormalHeartSize, fastMode, turboMode
	;~ msgbox % newText "`n`n" exam "`n`n" accNo "`n`n" chartNo
	risState:=RisOpened()
	
	if instr(newText,"EXAMINATION:")
		return newText
	if instr(newText,"shows")
		newText:=RegExReplace(newText,"is)^.+shows\s*","")
		,newText:=stringupper(substr(newText,1,1)) substr(newText,2)
	
	if (!fastMode && !turboMode && addNormalHeartSize && RegExMatch(exam,"is)Chest : (PA|AP) View") && !regexmatch(newText,"i)normal heart size|cardiomegaly|borderline heart size|heart border|opacified (left|right) hemithorax"))
		heartSize:="Normal heart size. "
	else 
		heartSize:=""
	
	exam:=RegExReplace(exam," ?: ?"," - ")
	return  (showChartNo?(chartNo=""?"":"Chart No: " chartNo "`r`n"):"") (showAccNo?(accNo=""?"":"Accession No: " accNo "`r`n"):"") "EXAMINATION: " exam (match1=""?"":" (" match1 ")") ".`r`nFINDINGS:`r`n" heartSize RegExReplace(newText,"(^(\r?\n)+)|((\r?\n)+$)","")
}
stringupper(t){
	StringUpper,t,t
	return t
}

tooltip:
ToolTip
return

checkRisOpened:

if(reportListCount>=2){
	;~ winwait,ahk_exe feedRIS.exe,,10
	if WinExist("ahk_exe feedRIS.exe")
		send_Data("feedRIS", {ReportList: reportListForFeed})

	gosub findStartAccNo
}else{
	Msgbox % "List empty or not found!"
}
return

;~ n::
;~ nextStudy()
;~ return
exit(){
	
	exitapp
}


next(wParam, lParam){
	nextStudy()
}
prior(wParam, lParam){
	priorStudy()
}

#ifwinactive,simple RIS ahk_class AutoHotkeyGUI
+F12::
F12::
critical
Loop % InStr(A_ThisHotkey,"+")?4:1
	nextStudy()
return
+F11::
F11::
critical
Loop % InStr(A_ThisHotkey,"+")?4:1
	priorStudy()
return


F5::
gosub openInImpax
return
#ifwinactive

#ifwinactive,ahk_group MyGUI
+F12::
F12::
critical
Loop % InStr(A_ThisHotkey,"+")?4:1
	nextStudy()
return
+F11::
F11::
critical
Loop % InStr(A_ThisHotkey,"+")?4:1
	priorStudy()
return



#ifwinactive

PGUP::
PGDN::
Critical
if(A_PriorHotkey=A_ThisHotkey && A_TimeSincePriorHotkey<300)
	return
wheelGui:=1
gosub changePic
return


~wheeldown::
~wheelup::
Critical
if(A_PriorHotkey=A_ThisHotkey && A_TimeSincePriorHotkey<300)
	return
;~ mousegetpos,mx,my,mouseWin
;~ winget,processName,processName,ahk_id %mouseWin%
;~ if(processName!="PacsIE.exe")
	;~ return
;~ wheelGui:=(mx>monitors.2.r)?2:1
changePic:
if(!active)
	return
MouseGetPos,mx,my,mouseWin
winget,processName,processName,ahk_id %mouseWin%
if !(processName~="i)python.exe|miniPACS.exe|simpleRIS.exe")
	return
send_data("miniPACS", {"next_image": (InStr(A_ThisHotkey, "UP")?0:1)
	, "x": mx
	, "y": my})
return


createGUI:
WB:=[],GuiHwnd:=[],WBp:=[],loadedPic:=[],guiHwnd2:=[]
;~ ,loadedPicCount:=CriticalObject()
,loadedPicCount:=[]
loop % totalGUI {
	gui,color,black
	;~ Gui,%a_index%: +LastFound +ToolWindow  +hwndHwnd -border
	;~ if (pToken){
		;~ Gui,%a_index%: -Caption +E0x80000 +LastFound +ToolWindow -border +hwndHwnd
		;~ if (monitorCount>1){
			;~ Gui,2%a_index%: -Caption +E0x80000 +LastFound +ToolWindow -border +hwndHwnd2
			;~ guiHwnd2.push(hwnd2)
			;~ groupadd,MyGUI,ahk_id %hwnd2%
		;~ }
	;~ }else {
	Gui,%a_index%: -Caption +LastFound +ToolWindow -border +hwndHwnd
	;~ if (!pToken) {
	Gui,%a_index%: Add, Picture, % (noGdi?"":"altsubmit") " BackgroundBlack x0 y0 0xE hwndWBhwnd" a_index " vWB" a_index " w" (monitors.2.w) " h-1", 
	if monitorCount>1
		Gui,%a_index%: Add, Picture, % (noGdi?"":"altsubmit") " BackgroundBlack x" monitors.2.w+1 " y0 0xE hwndWBphwnd" a_index " vWBp" a_index " w" (monitors.3.w) " h-1" ,
	
	;~
	WB.push(WBhwnd%a_index%)
	,WBp.push(WBphwnd%a_index%)
	;~ }
	;~ WB%a_index%.Navigate("about:blank")
	;~ WBp%a_index%.document.body.style.backgroundColor := "black"
	,GuiHwnd.push(hwnd)
	
	groupadd,MyGUI,ahk_id %hwnd%
}




;~ bitmap2gui(WB[1],reportdir "\T__________ 8______\T__________ 8______ 1.jpeg",monitors.2.w)
;~ gui,1:show,% "w" (monitors.2.w)*2 " h" monitors.2.h " x" monitors.2.l " y0"
;~ bitmap2gui(WB[1],reportdir "\T__________ 6______\T__________ 6______ 1.jpeg",monitors.2.w)
;~ exitapp




gui,log: +hwndLogHwnd +toolwindow

gui,info1: font,s24 cSilver,Verdana
gui,info1: color,black
gui,info1: +ToolWindow  +hwndinfo1Hwnd -border  +lastFound +alwaysontop
WinSet, TransColor, black
gui,info1:add,text,vinfotext1,9999/9999
groupadd,MyGUI,ahk_id %info1hwnd%
if (monitorCount>1) {
	gui,info2: font,s24 cSilver,Verdana
	gui,info2: color,black
	gui,info2: +ToolWindow  +hwndinfo2Hwnd -border  +lastfound +alwaysontop
	winset,transcolor,black
	gui,info2: add,text,vinfotext2,9999/9999
	groupadd,MyGUI,ahk_id %info2hwnd%
}


gui,reportInfo: font,s14 cWhite,Verdana
gui,reportInfo: color,black
gui,reportInfo: +ToolWindow  +hwndreportInfoHwnd -border  +lastFound +alwaysontop
WinSet, TransColor, black
gui,reportInfo:add,text,vreportInfoText,% "T0123456789`n01234567`nStudy: 9999/9999`nTotal time: 99999999`nMean time: 9999999"
;~ gui,reportInfo:show,% "x" (monitors.2.r)-250 " y" (monitors.2.b)-150
groupadd,MyGUI,ahk_id %reportInfoHwnd%

;~ sleep 1000
;~ gui,add,text,,test
;~ gui,log:show

;~ WB.Navigate(PacsWebUrl("T__________","",loginId,loginPw))
;~ sleep 5000
;~ gui,show,% "x" monitors.3.l " y" monitors.3.t " w" (monitors.3.w) " h" (monitors.3.h)

;~ gui,filter:color,black
;~ gui,filter:+toolwindow -caption +alwaysontop +lastfound +hwndfilterHwnd
;~ winset,transparent,200
;~ gui,filter:show,% "x" (thisMonitor:=monitors[fixedMonitor]).l " y" thisMonitor.t " w" (thisMonitor.w+(monitorCount>1?monitors.3.w:0)) " h" (thisMonitor.h)" noactivate"

return


getReportList:
;~ parseDataGrid(RisListRowsAcc,reportList, 1, totalGUI,0, [AccNoCol, thisAccNo])
return
offLineModeReportList:
;~ parseDataGrid(RisListRowsAcc,reportList,1)
;~ msgbox % reportList.maxindex()
if (reportList.maxindex()!=reportListCount){
	settimer,offLineModeReportList, -500
	return
}
oldReportList:=reportList.clone()
,reportList:=[]
for k,v in oldReportList {
	;~ test:=fileexist(reportDir "\" v[AccNoCol] " " v[ChartNoCol] "\" v[AccNoCol] " " v[ChartNoCol] " 1.jpeg")
	if (k=1) || FileExistValid(jpegDirName(reportDir , v[AccNoCol], v[ChartNoCol] , v[AccNoCol] , v[ChartNoCol] ))
		reportList.push(v.clone())
}
reportListCount:=reportList.maxindex()
;~ msgbox % reportList.maxindex()
if FileExistValid(jxonFile:=reportDir "\reportList.json")
	FileDelete,% jxonFile
;~ FileAppend,% jxon_dump(reportList),% jxonFile,utf-8
return


init:
;~ critical
;~ reportListCount:=parseDataGrid(RisListRowsAcc,reportList, 1, 1)

;~ if !(AccNoCol && chartNoCol && examNameCol && statusCol){
	;~ settimer,init,-500
	;~ return
;~ }
if offLineMode 
	gosub offLineModeReportList
;~ else 
	;~ settimer,getReportList,-1

;~ initSearch:

;~ matched:=0
;~ for k,v in reportList {
	;~ if (v[AccNoCol]=thisAccNo){
		;~ matched:=1,thisStudyInd:=k
		;~ break
	;~ }
;~ }


;~ if (!matched){
	;~ settimer,initSearch,-1000
	;~ return
;~ }




;~ gosub showfilter

;~ gosub curtainThread

totalStudyCount:=reportListCount-thisStudyInd+1
,studyCount:=1
,tick0:=a_tickcount

,loadImage(guiInd,thisStudyInd,"",1)
,showReportInfo(reportList[thisStudyInd,AccNoCol],reportList[thisStudyInd,ChartNoCol],1)
winsettitle,ahk_id %logHwnd%,,% "PacsIE Log GUI " thisHwnd ": " reportList[thisStudyInd,AccNoCol] " " reportList[thisStudyInd,ChartNoCol] " " reportList[thisStudyInd,examNameCol] 

;~ msgbox
initLoad:=0
loop {
	if (initLoad >= totalGui-1)
		break
	while (reportList[thisStudyInd+a_index, AccNoCol]="" || reportList[thisStudyInd+a_index, ChartNoCol]="")
		sleep 500
	
	if (reportList[thisStudyInd+a_index, StatusCol]="已發報告")
		continue
	
	++initLoad
	,loadImage(guiInd+initLoad,thisStudyInd+a_index)
	Sleep 500
	
}


;~ }
;~ msgbox
monitorInd:=1
;~ gui,filter:hide
;~ settimer,filterHide,-1000
;~ winactivate,% reportList[thisStudyInd,AccNoCol] " ahk_class AutoHotkeyGUI"
gosub activateSimpleRis
;~ PostMessage,0x2028,,,,simple RIS ahk_class AutoHotkeyGUI

;~ setLogGui(reportList[thisStudyInd,AccNoCol])
;~ settimer,loadMore,-1000


settimer,show2ndGUI,-1000
;~ if(!offlineMode)
	;~ settimer,getAllReportList,-2000
getAllHxInd:=thisStudyInd
;~ if !fastMode
	;~ settimer,getAllHx,-1,-2
	;~ SetTimerFn("getAllHx",-1, [], -2)
	;~ SetTimer, getAllHxThread, -1
;~ settimer,getAllJpeg,-10000

gosub simpleRISnoUpdate
;~ settimer,simpleRISnoUpdate,1000

if (!fastMode && !turboMode){
	Loop 4 {
		loadHistory(thisStudyInd+A_Index-1)
	}
}

return

simpleRISnoUpdate:
postmessage,0x2022,3600000,1,,simple RIS ahk_class AutoHotkeyGUI
return

getAllJpeg:
/*
ahkmini("
(
#persistent
#notrayicon
setbatchlines,-1
#include <portallib>
reportList:=criticalobject(" (&reportList) ")
,loadedPicCount:=criticalobject(" (&loadedPicCount) ")
,thisStudyInd:=" thisStudyInd ", totalGUI:=" totalGUI "
,reportListCount:=" reportListCount ", AccNoCol:=" AccNoCol "
,ChartNoCol:=" chartNoCol ", reportDir:=""" reportDir """
,PicWidth:=" monitors[fixedMonitor].w "-6
,loginId:=""" loginId """, loginPw:=""" loginPw """
,i:=thisStudyInd+totalGUI+a_index-1
settimer,routine,1000
loop {
	AccNo:=reportList[i,AccNoCol],chartNo:=reportList[i,chartNoCol]
	if(i>reportListCount){
		exitapp
	}else if (AccNo!="""" && chartNo!="""") {
		
		if !fileexist(reportDir ""\"" AccNo "" "" chartNo ""\"" AccNo "" "" chartNo "" 1.jpeg"") {
			; tooltip `% ""downloading:"" AccNo "","" chartNo "","" reportDir "" "" loginId loginPw 
			; PacsWebDownloadJpeg(AccNo,chartNo,"""",reportDir,PicWidth,loginId,loginPw)
			output:=PacsWebInfoFlatten(PacsWebInfo(output,AccNo,chartNo,loginId,loginPw))
			,loadedPicCount[AccNo "" "" chartNo]:=output.maxindex()
			for k,v in output {
				PacsWebDownloadJpeg2(v.url,AccNo,chartNo,AccNo "" "" chartNo "" "" k "".jpeg"",reportdir ""\"" AccNo "" "" chartNo,PicWidth,loginId,loginPw)
				sleep 2000
			}
			sleep 5000
		}
		++i
	}else{
		sleep 5000
	}
}
return

routine:
ifwinnotexist,ahk_exe PacsIE.exe
	exitapp
return
)")
return
*/




getAllReportList:

;~ ahkmini("
;~ (
;~ #persistent
;~ #notrayicon
;~ setbatchlines,-1
;~ SetControlDelay,-1
;~ #include <risimpax>
;~ #include <acc>
;~ reportList:=criticalobject(" (&reportList) ")
;~ RisListHwnd:=" rislisthwnd ", thisStudyInd:=" thisStudyInd "
;~ RisListRowsAcc:=acc_children(Acc_objectfromwindow(RisListHwnd))
parseDataGrid(RisListRowsAcc,reportList,1,0,100,thisStudyInd)
;~ return
;~ )")
if FileExistValid(jxonFile:=reportDir "\reportList.json")
	FileDelete,% jxonFile
;~ FileAppend,% jxon_dump(reportList),% jxonFile,utf-8
return

reportListProgress(k, ByRef rowAcc, ByRef cellsAcc){
	global reportListCount
	tooltip % "Get list from RIS: " k " / " reportListCount " ..."
}

show2ndGUI:
;~ loadImage(2,thisStudyInd+1)
gui,2: show,% "x" (thisMonitor:=monitors[fixedMonitor]).l " y" thisMonitor.t " w" (thisMonitor.w+(monitorCount>1?monitors.3.w:0)) " h" (thisMonitor.h)" noactivate",% title[2]
;~ sleep 2000
;~ WB1.Navigate("javascript:var controller;if(controller){controller.itemAction('WindowLevelS0Se0',event );}")
;~ WBp1.Navigate("javascript:var controller;if(controller){controller.itemAction('WindowLevelS0Se0',event );}")
return

showFilter:
;~ gui,filter:default
;~ gui,color,black
;~ gui,+toolwindow -caption +alwaysontop +lastfound +hwndfilterHwnd
;~ gosub filterShow
;~ settimer,filterHide,-1000

;~ winset,transparent,200
;~ gui,show,% "x" (thisMonitor:=monitors[fixedMonitor]).l " y" thisMonitor.t " w" (thisMonitor.w+(monitorCount>1?monitors.3.w:0)) " h" (thisMonitor.h)" noactivate"
;~ gosub filterShow

return

filterShow:
;~ topGuiInd:=mod(guiInd-1,totalGUI)+1

return
;~ winset,transparent,200,ahk_id %filterHwnd%
;~ gui,filter:show,% "x" (thisMonitor:=monitors[fixedMonitor]).l " y" thisMonitor.t " w" (thisMonitor.w+(monitorCount>1?monitors.3.w:0)) " h" (thisMonitor.h)" noactivate"
;~ ahkthread(createscript("
;~ (
;~ #persistent
;~ #notrayicon
;~ #include <SetTimerF>
;~ transValue:=0,filterHwnd:=" filterHwnd "
;~ settimerF(""filterShowHide"",100)
;~ return
;~ filterShowHide{}
;~ )"))
return
;~ filterHide:
;~ if (!filterHideThread) {
	;~ filterHideThread:=ahkmini(createscript("
;~ (
;~ #persistent
;~ #notrayicon
;~ setbatchlines,-1
;~ transValue:=200,filterHwnd:=" filterHwnd "
;~ settimer,<filterHide,-1
;~ settimer,routine,1000
;~ return
;~ routine:
;~ ifwinnotexist,ahk_exe PacsIE.exe
	;~ exitapp
;~ return

;~ <filterHide:filterHide>
;~ )"))
;~ }else{
	;~ filterHideThread.ahkassign.transValue:="200"
	;~ filterHideThread.ahkLabel("<filterHide",1)
;~ }
;~ return
;~ <filterHide:
;~ transValue+=0
;~ if show && (transValue:=transValue+50)>200
	;~ return
;~ else if !show && (transValue:=transValue-50)<0 {
	;~ winhide,ahk_id %filterHwnd%
		winset,transparent,200,ahk_id %filterHwnd%
	;~ return
;~ }
;~ winset,transparent,% transValue,ahk_id %filterHwnd%
;~ settimer,<filterHide,-50
;~ filterHide>:
;~ return

setLogGui(title){
	;~ global
	;~ DetectHiddenWindows,on
	;~ winsettitle,ahk_id %logHwnd%,,% "PacsIE Log GUI " thisHwnd ": " title
	;~ tooltip % title
	;~ msgbox % title
}



<setLogGui:
thisTitle:=WinGetAtCoords(1700,300)
;~ msgbox % thisTitle
if (thisTitle="")
	return
;~ msgbox % logHwnd "," thisHwnd
setLogGui:
return
thisTitle:=WinGetAtCoords(1700,300)
winsettitle,ahk_id %logHwnd%,,% "PacsIE Log GUI " thisHwnd ": " thisTitle
regexmatch(thisTitle,"^(\w{11}) (\w{6}\d)",match)
controlget,editHwnd,hwnd,,Scintilla1,simple RIS ahk_class AutoHotkeyGUI
if (match1!="" && match2!=""){
	currentLogAccNo:=match1
	if FileExistValid(path:=reportDir "/" match ".txt") && (simpleRISHwnd:=winexist("simple RIS ahk_class AutoHotkeyGUI")) && priorLogAccNo!=currentLogAccNo {
		fileread,report,% path
		regexmatch(report,"is)FINDINGS:\r?\n(.+)\r?\n-=-=-=-=-",match)
		;~ controlsettext,Edit1,% match1,ahk_id %simpleRISHwnd%
		Edit_SetText(editHwnd, match1)
		,edit_setsel(editHwnd,len:=strlen(match1),len)
	}else{
		;~ controlsettext,Edit1,% "",ahk_id %simpleRISHwnd%
		;~ Edit_SetText(editHwnd, "")
		;~ postmessage,0x2024,,,,simple RIS ahk_class AutoHotkeyGUI
	}
	priorLogAccNo:=currentLogAccNo
}else{
	msgbox % "Can't get info!"
}
setLogGui>:
return

threadMonitor(){
	
}

bitmap2gui(picHwnd,imgPath,w="",h=""){
	
	
}	

checkLoadedPicCount(accno,chartNo,folderAcc="",folderChartNo=""){
	global loadedPicCount,reportDir
	k:=0
	loop,% jpegDirName(reportDir, (folderAcc?folderAcc:AccNo), (folderChartNo?folderChartNo:chartNo), AccNo, ChartNo ,"*", ".jpeg?")
	{
		if regexmatch(a_loopfilename,"\d+\.jpeg") && (A_LoopFileSizeKB>10)
			++k
	}
	loadedPicCount[AccNo " " chartNo]:=k
	
}

showImage(thisGuiInd,whichMonitor,byref thisMonitor,FolderAccNo,FolderChartNo,AccNo="",chartNo="",ind=1){
	global
	
	if(AccNo="")
		AccNo:=FolderAccNo
	
	if(ChartNo="")
		ChartNo:=FolderChartNo
	else if (ChartNo="*")
		loop % reportDir "\" FolderAccNo " " FolderChartNo "\* 1.jpeg"
			if regexmatch(a_loopfilename,"(\w+) (\w+) 1\.jpeg",match) && (match1!=FolderAccNo) {
				anyPriorImage:=1
				,ChartNo:=match2
				break
			}
	
	
	if(!pToken){
		picHwnd:=whichMonitor=1?WB[thisGuiInd]:WBp[thisGuiInd]
		
		;~ gui,%thisGuiInd%: show,% "x" (thisMonitor.l) " y" thisMonitor.t " w" (thisMonitor.w+(monitorCount>1?monitors.3.w:0)) " h" (thisMonitor.h)
		
		guicontrol,-redraw,% picHwnd
		
		
		loop 3 {
			guicontrol,,% picHwnd,% "*w" thisMonitor.w " *h-1 " reportDir "\" FolderAccNo " " FolderChartNo "\" AccNo " " chartNo " " ind ".jpeg"
			if (!errorlevel ){
				loadedPic[thisGuiInd,whichMonitor]:=FolderAccNo " " FolderChartNo "\" AccNo " " chartNo " " ind ".jpeg", fail:=false
				break
			}else
				loadedPic[thisGuiInd,whichMonitor]:="", fail:=true
		}
		
		if(fail)
			msgbox % "Failed to load image!!!"
		
		
		guicontrol,+redraw,% picHwnd
	}else{
		ret:=bitmap2gui(whichMonitor=1?WB[thisGuiInd]:WBp[thisGuiInd],reportDir "\" FolderAccNo " " FolderChartNo "\" AccNo " " chartNo " " ind ".jpeg",thisMonitor.w)
		;~ if (ret!=0)
			;~ msgbox % "Error in SetImage!!!"  ret 
		;~ else 
			loadedPic[thisGuiInd,whichMonitor]:=FolderAccNo " " FolderChartNo "\" AccNo " " chartNo " " ind ".jpeg"
		;~ else
			;~ loadedPic[thisGuiInd,whichMonitor]:=""
	}
	
	
	
	;~ checkLoadedPicCount(AccNo,chartNo,folderAccNo)
}


showReportInfo(AccNo,chartNo,noUpdate=0){
	global
	if(!noUpdate){
		thisTick:=A_TickCount
		,floatFormat:=A_FormatFloat
		setformat,float,0.1
		totalReportTime:=(thisTick-tick0)//6000/10
		,meanReportTime:=(thisTick-tick0)/studyCount//100/10
		setformat,float,%floatFormat%
		++studyCount
	}
	guicontrol,reportInfo:,reportInfoText,% AccNo "`n" chartNo (!noUpdate?"`nStudy: " studyCount " / " totalStudyCount "`nTotal time: " totalReportTime "min`nMean time: " meanReportTime "s":"")
	gui,reportInfo:show,% "x" (monitors.2.r)-250 " y" (monitors.2.b)-150 " noactivate"
	winset,AlwaysOnTop,off,% "ahk_id " simpleRIS
	WinInsertAfter(reportInfoHwnd, simpleRIS)
	winset,AlwaysOnTop,on,% "ahk_id " simpleRIS
	fileappend,% AccNo "`n",% reportDir "\resumePacsIE",utf-8
}


loadImage(GuiInd,studyInd,ChartNo="",show=0){
	global
	local AccNo,thisGuiInd,thisMonitor,thisStudy,PacsHx,k,v,thisStudyInd,anyPriorImage,th,output,oldAccNo,oldChartNo
	thisStudyInd:=studyInd
	
	;~ msgbox,,,1,1
	if(thisStudyInd>reportListCount){
		;~ msgbox,,,err1,1
		Return
	}
	if !isobject(thisStudy:=reportList[thisStudyInd]){
		parseDataGrid(RisListRowsAcc,reportList, 1, [thisStudyInd])
		,thisStudy:=reportList[thisStudyInd]
	}
	if ((AccNo:=thisStudy[AccNoCol])=""){
		;~ msgbox,,,err2,1
		;~ msgbox,,,% reportList[thisStudyInd,AccNoCol],1
		return
	}
	thisGuiInd:=mod(guiInd-1,totalGUI)+1
	;~ WB[0+thisGuiInd].Navigate("about:blank")
	;~ msgbox,,,2,1
	
	if (chartNo=""){
		chartNo:=thisStudy[chartNoCol]
	}
	
	if(show){
		shownGuiInd:=thisGuiInd
		,resetPicInfo()
	}
	
	if (trim(title[thisGuiInd]:=(AccNo " " (chartNo) " " thisStudy[examNameCol]))=""){
		;~ msgbox
		return loadImage(guiInd,studyInd,chartNo,show)
	}
	WinSetTitle,% "ahk_id " GuiHwnd[thisGuiInd],,% title[thisGuiInd]
	;~ if trim(title[guiInd])=""
		;~ aaaaa:=1
	
	thisMonitor:=monitors[fixedMonitor]
	
	if !FileExistValid(reportDir "\" AccNo " " chartNo "\" AccNo " " chartNo " 1.jpeg") && !offlineMode {
		output:=PacsWebInfoFlatten(PacsWebInfo(output,AccNo,chartNo,loginId,loginPw))
		,loadedPicCount[AccNo " " chartNo]:=output.maxindex()
		for k,v in output {
			if RegExMatch(v.objectUID,"[^\d\.]")
				continue
			PacsWebDownloadJpeg2(v.url,AccNo,chartNo,AccNo " " chartNo " " k ".jpeg",reportdir "\" AccNo " " chartNo,(thisMonitor).w-6,loginId,loginPw)
			;~ sleep 2000
		}
		;~ PacsWebDownloadJpeg(AccNo,chartNo,"",reportDir,(thisMonitor).w-6,loginid,loginpw)
	}else{
		checkLoadedPicCount(accno,chartNo)
	}
	
	
	showImage(thisGuiInd,1,thisMonitor,AccNo,chartNo)
	
	
	if (show){
		;~ ++monitorInd
		;~ msgbox % "x" (thisMonitor.l) " y" thisMonitor.t " w" (thisMonitor.w+(monitorCount>1?monitors.3.w:0)) " h" (thisMonitor.h)
		gui,%thisGuiInd%: show,% "x" (thisMonitor.l) " y" thisMonitor.t " w" (thisMonitor.w+(monitorCount>1?monitors.3.w:0)) " h" (thisMonitor.h),% title[thisGuiInd]
		showPicInfo(1,AccNo " " chartNo)
		;~ setLogGui(title)
		,thisTitle:=title[thisGuiInd]
		settimer,setLogGui,-500
		gosub activateSimpleRis
	}else{
		gui,%thisGuiInd%: hide
		;~ gui,%thisGuiInd%: show,% "x" (thisMonitor:=monitors[fixedMonitor]).l " y" thisMonitor.t " w" (thisMonitor.w+(monitorCount>1?monitors.3.w:0)) " h" (thisMonitor.h) " noactivate",% title
		
	}
	;~ msgbox,,,3,1
	;~ msgbox % WB%thisGuiInd%.busy
	;~ if(globalInd=1)
		;~ sleep 2000
	;~ WB%thisGuiInd%.Navigate(url:=PacsWebUrl(AccNo,thisStudy[chartNoCol],loginId,loginPw))
	;~ msgbox,,,3.1,1
	;~ msgbox,,,% url,1
	
	;~ msgbox,,,3.2,1
	if(monitorCount>1){
		anyPriorImage:=0
		loop % reportDir "\" AccNo " " chartNo "\* 1.jpeg"
			if regexmatch(a_loopfilename,"(\w+) (\w+) 1\.jpeg",match) && (match1!=AccNo) {
				anyPriorImage:=1
				,oldAccNo:=match1,oldChartNo:=match2
				break
			}
		
		if(anyPriorImage){
			showImage(thisGuiInd,2,thisMonitor,AccNo,chartNo,oldAccNo,oldChartNo)
			,checkLoadedPicCount(oldAccNo,oldChartNo,accNo,chartNo)
			
		}else if (regexmatch(thisStudy[examNameCol],"is)(Chest.*(AP|PA))|(Chest.*Lateral)")) && !offlineMode && !fastMode && !turboMode {
			
			PacsHx:=getPacsHx(sid,chartNo)
				
			for k,v in PacsHx {
				if RegExMatch(v.ExamName,"is)Chest.*(AP|PA)") && (regexreplace(v.ExamDate,"\D","")<=substr(regexreplace(thisStudy[examDateCol],"\D",""),1,8)) && (strlen(oldAccNo:=v.AccessNo)>=11) {  ;may catch exam on the same day
					
					if regexreplace(v.AccessNo,"i)^[a-z]+","")>=regexreplace(AccNo,"i)^[a-z]+","") && regexreplace(v.AccessNo,"\d+$","")=regexreplace(AccNo,"\d+$","")
							continue
					
					;~ WBp[thisGuiInd].Navigate("about:blank")
					;~ WBp[thisGuiInd].Navigate(PacsWebUrl(v.AccessNo,thisStudy[chartNoCol],loginId,loginPw))
					anyPriorImage:=1,oldChartNo:=v.ChartNo
					if !FileExistValid(reportDir "\" accno " " chartNo "\" oldAccNo " " oldChartNo " 1.jpeg") {
						output:=PacsWebInfoFlatten(PacsWebInfo(output, oldAccNo,oldChartNo,loginId,loginPw))
						,loadedPicCount[ oldAccNo " " oldChartNo ]:=output.maxindex()
						for q,r in output {
							if RegExMatch(r.objectUID,"[^\d\.]")
								continue
							PacsWebDownloadJpeg2(r.url,oldAccNo,oldChartNo,oldAccNo " " oldChartNo " " q ".jpeg",reportdir "\" AccNo " " chartNo,(thisMonitor).w-6,loginId,loginPw)
							;~ sleep 2000
						}
						;~ PacsWebDownloadJpeg(oldAccNo,chartNo,"",reportDir,thisMonitor.w-6,loginid,loginpw)
					}else{
						checkLoadedPicCount(oldAccNo,oldChartNo,accNo,chartNo)
					}
					
					showImage(thisGuiInd,2,thisMonitor,AccNo,chartNo,oldAccNo,oldChartNo)
					
					if(show)
						showPicInfo(2,oldAccNo " " oldChartNo)
					
					break
				}
			}
		}
		if(!anyPriorImage){
			;~ WBp%thisGuiInd%.Navigate("about:blank")
			;~ WBp%thisGuiInd%.document.body.style.backgroundColor := "black"
			if(!pToken){
				guicontrol,-redraw,WBp%thisGuiInd%
				guicontrol,,% WBp%thisGuiInd%,% ""
				;~ if !errorlevel 
				
				guicontrol,+redraw,WBp%thisGuiInd%
			}else{
				bitmap2gui(WBp[thisGuiInd],"")
			}
			loadedPic[thisGuiInd,2]:=""
			,loadedPicCount[oldAccNo " " oldChartNo]:=0
		}
		
		showPicInfo(2,oldAccNo " " oldChartNo)
	}
	
	
	
	
	;~ downloaded.push(loadedPic[thisGuiInd].clone())
	;~ settimer,deleteReportedPic,-1
	;~ msgbox,,,4,1
	
	;~ while loadHistoryFlag
		;~ sleep 500
	
	
	;~ settimerF("loadHistory",-1,[thisStudyInd, show],0)
	;~ msgbox % thisGuiInd
	;~ th:=ahkmini("
;~ (
;~ #persistent
;~ #notrayicon
;~ #include <portalLib>
;~ threadFinish:=0,threadReturn:=0
;~ hx:=CriticalObject(" (&Hx) "),studyInd:=" thisStudyInd "
;~ hx2Yr:=CriticalObject(" (&hx2Yr) ")
;~ ,examNameCol:=" examNameCol ",sid:=""" sid """,loginId:=""" loginId """,loginPw:=""" loginPw """
;~ ,chartNoCol:=" chartNoCol "
;~ Alias(boneKeyWords," getvar(boneKeyWords) ")
;~ Alias(lungKeyWords," getvar(lungKeyWords) ")
;~ reportList:=CriticalObject(" (&reportList) ")
;~ if loadHistory(studyInd)
	;~ threadFinish:=1,threadReturn:=studyInd
;~ settimer,routine,1000
;~ return
;~ routine:
;~ ifwinnotexist,ahk_exe PacsIE.exe
	;~ exitapp
;~ return
	
;~ )" function1 )
	;~ msgbox % script 
	;~ th:=ahkmini(script)
	
	if(show && !fastMode && !turboMode){
		hxStudyInd:=studyInd
		settimer,waitHxLoaded,-1
	}
	
	
	
	;~ loadHistory(thisStudyInd)
	;~ if(show)
		;~ showHx(thisStudyInd)
	;~ msgbox,,,5,1
	return 1
}

waitHxLoaded:
thread,priority,-10
	;~ global hx,hxDll
	;~ msgbox % (hx[studyInd]="" || !hxDll)
	if (!hxDll || hxDll.getvar("i")<=studyInd) {
		settimer,waitHxLoaded,-500
		return
	}
	
		hxDll.ahkExec("showHx(" hxStudyInd ")")
	
	
return

getAllHx(){
	return
	global getAllHxInd, reportListCount
	Loop {
		if (getAllHxInd >reportListCount )
			return
		while !(reportList[getAllHxInd,chartNoCol])
			sleep 500
		
		loadHistory(getAllHxInd)
		;~ ToolTip % "Loaded hx: " getAllHxInd
		getAllHxInd++
	}
}


deleteReportedPic:
++downloadedCount
if !FileExistValid(downloaded[downloadedCount-totalGui,1]){
	filedelete,% downloaded[downloadedCount-totalGUI,2]
	downloaded.removeAt(downloadedCount-totalGUI)
}
return

showPicInfo(which,AccChartNo,ind=1){
	global
	local count:=loadedPicCount[AccChartNo],title,activeHwnd
	wingettitle,title,A
	winget,activeHwnd,id,A
	if !(count>1){
		gui,info%which%:hide
		return
	}
	guicontrol,info%which%:,infotext%which%,% ind "/" count
	gui,info%which%:show,% "x" (monitors[which+1].l+5) " y5 noactivate"
	winset,AlwaysOnTop,off,% "ahk_id " simpleRIS
	WinInsertAfter(info%which%hwnd, simpleRIS)
	winset,AlwaysOnTop,on,% "ahk_id " simpleRIS
	;~ WinInsertAfter(guiHwnd[shownGuiInd], info%which%hwnd)
	;~ if(title="simple RIS")
		;~ winactivate,ahk_id %activeHwnd%
}


loadHistory(studyInd,show=0){
	global 
	local RisReport2Yr,priorExamItem,keyword,k,v,thisStudyInd,thisHx,thisChartNo, thisAccNo
	;~ Thread,Priority,-2
	thisStudyInd:=studyInd
	;~ ToolTip % "loading hx: " studyInd
	if !isobject(reportList[thisStudyInd])
		return
	
	if !regexmatch(reportList.getCell(thisStudyInd,"ExamName"),"is)(Chest.*(AP|PA))|(Chest.*Lateral)")
		return
	
	thisChartNo:=reportList.getCell(thisStudyInd,"ChartNo")
	,thisAccNo:=reportList.getCell(thisStudyInd,"AccNo")
	,sid:=checksid(sid)?sid:sid:=login(loginid,loginpw)
	if FileExist(p:=A_ScriptDir "\loadOldHx.exe"){
		;~ hx2Yr[thisChartNo]
		if InStr(p, "reportSet")
			run % """" p """ """ a_scriptdir "\loadOldHx.ahk"" " sid " " thisChartNo " " thisAccNo
		else
			run % """" p """ " sid " " thisChartNo " " thisAccNo
		return
	}
	
	keyword:="",loadHistoryFlag:=1
	;~ ToolTip % "loadin chartNo: " thisChartNo
	
	if !isobject(RisReport2Yr:=hx2Yr[thisChartNo]){
		RisReport2Yr:=parseRisReport2Yr(RisReport2Yr(sid,reportList[thisStudyInd,chartNoCol]))
		,hx2Yr[thisChartNo]:=RisReport2Yr.clone()
	}
	
	for k,v in RisReport2Yr {
		if regexmatch(priorExamItem:=v.1.1,"is)Chest.*(AP|PA)") && (++CXRind<11) {
			tmp:=matchText(v.2,boneKeyWords)
			,keyWord.=tmp=""?"":(RegExReplace(substr(v.1.3,1,10),"\/","") "CXR: " tmp)
		}else if regexmatch(priorExamItem,"is)CT.*Chest|low dose") && (++CTind<2) {
			tmp:=matchText(v.3,lungKeyWords)
			,keyWord.=tmp=""?"":(RegExReplace(substr(v.1.3,1,10),"\/","") "CT: "  tmp)
		}
	}
	
	;~ msgbox % thisStudyInd
	hx[thisStudyInd]:=keyword "   "
	
	,dict:={"oldHx": {}}
	,dict["oldHx", thisAccNo]:=keyword "   "
	,Send_WM_COPYDATA(getListenerHwnd(), dwData, jxon_dump(dict))
	;~ ToolTip % "keyword: " keyword
	;~ if(show)
		;~ showHx(thisStudyInd)
	
	loadHistoryFlag:=0
	return true
}


showHx(studyInd){
	global
	local keyword,hxMonitor,thisStudyInd
	thread,Priority,-2
	;~ msgbox
	thisStudyInd:=studyInd
	gui,hx:default
	gui,destroy
	RE.__Delete()
	
	if(!hxLoaded[thisStudyInd]){
		hxDll.ahkassign("ind", thisStudyInd)
		,hxDll.ahkLabel("getHx")
		,SetTimerFn("showHx", -500, [thisStudyInd])
		return
	}
	
	if ((keyword:=filterDuplicate(trim(hx[thisStudyInd])))=""){
		;~ RE.__Delete()
		return
	}
	gui,color,black
	gui,+alwaysontop +hwndhxHwnd +toolwindow -Caption
	gui,font,s14 csilver,Verdana
	gui,add,text,cblack hwndhxTextHwnd,% keyword
	controlgetpos,,,TW,TH,,ahk_id %hxTextHwnd%
	;~ tooltip % TW "," TH
	RE:=new RichEdit("hx","x0 y0 w" TW+50 " h" TH+20)
	,RE.setOptions(["readonly"])
	,RE.ShowScrollBar(0,false)
	,RE.ShowScrollBar(1,false)
	;~ RE.WordWrap(1)
	,RE.setText(keyword)
	;~ ,settimerF("colorRadReport",-1,[RE, 0])
	;~ colorRadReportFn:=Func("colorRadReport").bind(RE, 0)
	;~ Settimer,% ColorRadReportFn, -1
	,SetTimerFn("colorRadReport", -1, [RE, 0])
	;~ ,ahkmini("
	;~ (LTrim
	;~ #include <prettyReport>
	;~ #notrayicon
	;~ Alias(RE, " getVar(RE) ") 
	;~ colorRadReport(RE ,0)
	;~ exitapp
	;~ )")
	
	;~ RE.setBorder([0,0,0,0],[4,4,4,4])
	;~ hxMonitor:=monitors[monitors.maxindex()>2?3:1]
	,hxMonitor:=monitors[monitors.maxindex()>2?3:1]
	gui,show,% "x" hxMonitor.l+20 " y" hxMonitor.b-TH-20 " autosize noactivate",PacsIE Hx
	;~ wingetpos,x,y,w,h,ahk_id %hxHwnd%	
	;~ controlmove,,,,% w,% h,% "ahk_id " RE.hwnd
	;~ winmove,ahk_id %hxHwnd%,,% hxMonitor.l+20,% hxMonitor.b-h,w,h
	
	;~ gui,show,% "x" hxMonitor.l+50 " y" hxMonitor.b-200 " autosize noactivate",PacsIE Hx
	;~ settimer,killGui,% -1000+(-1)*strlen(keyword)*50
	PostMessage,0x2028,,,,simple RIS ahk_class AutoHotkeyGUI
}



matchText(byref str,byref arrOfKeyWords){
	ret:=""
	;~ for k,v in arrOfKeyWords {
		;~ ret.=(s:=RXMS(str,"is)[^\.;\r\n]*" v "[^\.;\r\n]*([\.;\r\n]|$)","r"))=""?"":s "`n"
	;~ }
	rt:=new ReportText(str)
	for k,v in arrOfKeyWords {
		con:=rt.contains(v, false, false)
		if !(con)
			continue
		for m,n in con 
			if !InStr(rt, n)
				ret.=n "`n"
	}
	return RegExReplace(ret, "i)[a-z ]+show[a-z]* *","")
}

filterDuplicate(str,del="`n"){
	arr:=[]
	loop,parse,str,%del%
		if (trim(a_loopfield)!="" && regexmatch(a_loopfield,"(\d{8}[^:]+: )?([^\r\n]+)",match)  && !instr(match2,"no"))
			arr["" match2].=RegExReplace(match1,":","")
	str:=""
	for k,v in arr
		str.=substr(v,1,-1) ": " k "`n"
	
	return substr(str,1,-1)
}

killGUI:
gui,hx:destroy
return

resetPicInfo(){
	global
	gui,info1:hide
	gui,info2:hide
}

nextStudy(wParam=0, lParam=0, msg=0, hwnd=0){
	global dwData
	send_data("miniPACS", {"next_study": wparam>1?wparam:1})
}




ensureStudy(AccNo, chartNo, guiInd, thisTitle){
	global
	local thisGetTitle
	thisGetTitle:=WinGetAtCoords(1700,300)
	,regexmatch(thisGetTitle,"^(\w{11}) (\w{6}\d)",match)
	if(match1!=AccNo || match2!=chartNo){
		ToolTip % "Error showing image!"
		gui,%guiInd%: show,% "noactivate",% thisTitle
	}
	
}

activateSimpleRis:
activateMain()
activateSimpleRIS_2:
active:=true
,simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")
if !turboHotkeyState
	SendMessage,0x2028,,,,ahk_id %simpleRIS%
winminimize,% "ahk_id " impaxopened()[2,1]
;~ activateMain()
return

winactivate,ahk_id %simpleRis%
ControlFocus,Scintilla1,ahk_id %simpleRIS%
;~ winget,nextProcName,ProcessName,% "ahk_id " GetNextWindow(simpleRis)
;~ if(nextProcName!="PacsIE.exe") {
	;~ activateMainsuperior aspect of
winset,AlwaysOnTop,on,ahk_id %simpleRIS%
if !getListenerHwnd()
	winset,AlwaysOnTop,Off,ahk_id %guihwnd%

;~ }
return

priorStudy(wParam=0, lParam=0, msg=0, hwnd=0){
	global dwData
	send_data("miniPACS", {"next_study":0})
}

loadMore(guiInd,studyInd){
	global 
	;~ msgbox,,,% guiINd "," studyInd,1
	;~ msgbox,,,1,1
	local loadMoreInd,thisMonitor,thisStudyInd
	
	loadMoreInd:=mod(guiInd-1,totalGUI)+1,loadMoreFlag:=1
	,thisStudyInd:=studyInd
	
	while (thisStudyInd<=reportListCount) && (reportList[thisStudyInd,statusCol]="已發報告")
		++thisStudyInd
	
	if(thisStudyInd>reportListCount)
		return
	
	;~ msgbox,,,2,1
	;~ msgbox % loadMoreInd "," studyInd
	;~ tooltip % !isobject(reportList[studyInd])
	if !isobject(reportList[thisStudyInd]){
		parseDataGrid(RisListRowsAcc,reportList, 1, [thisStudyInd])
	}
	;~ msgbox,,,loadMore,1
	;~ tooltip % loadMoreInd "," studyInd "loadmore"
	loadImage(loadMoreInd,thisStudyInd)
	;~ msgbox,,,4,1
	;~ tooltip % loadMoreInd "," studyInd
	,title[loadMoreInd]:=reportList[thisStudyInd,AccNoCol] " " reportList[thisStudyInd,ChartNoCol] " " reportList[thisStudyInd,examNameCol] 
	;~ gui,%loadMoreInd%: show,% "x" (thisMonitor:=monitors[fixedMonitor]).l " y" thisMonitor.t " w" (thisMonitor.w+(monitorCount>1?monitors.3.w:0)) " h" (thisMonitor.h) " noactivate",% title:=reportList[studyInd,AccNoCol] " " reportList[studyInd,ChartNoCol] " " reportList[studyInd,examNameCol] 
	;~ msgbox % title
	;~ msgbox,,,5,1
	
	;~ if(!fastMode)
		;~ loadHistory(studyInd)
	
	loadMoreFlag:=0
}
return



;~ guiclose:
;~ ~!#q::
esc::
critical
exitapp
return
;~ ~!#r::
;~ Reload
;~ return


^!+q::
onexit:
WinShow,simple RIS ahk_class AutoHotkeyGUI
if !WinExist("ahk_exe feedRIS.exe")
	WinShow,% "ahk_id " risopened()[2]
winactivate
;~ winshow,ahk_exe impax-client-main.exe
;~ loop 4 {
	;~ WB%a_index%.quit()
	;~ WBp%a_index%.quit()
;~ }
;~ filedelete,% reportDir "\resumePacsIE"
;~ SendMessage,0x10201,,,,getAllJpeg_main ahk_class AutoHotkeyGUI
;~ WinClose,ahk_pid %pid%
;~ process,Exist,getAllJpeg.exe
;~ if(!ErrorLevel)
	;~ filedelete,% reportDir "\reportList.json"
;~ winrestore,% "ahk_id " impaxopened()[2,1]
;~ winrestore,% "ahk_id " impaxopened()[2,2]
;~ winrestore,% "ahk_id " impaxopened()[2,3]
;~ winget,list,list,ahk_exe impax-client-main.exe
;~ Loop % List
	;~ WinRestore,% "ahk_id " list%a_index%
;~ for k,v in threadPool {
	;~ if (isobject(v.1)){
		;~ v.1.ahkterminate()
		;~ ,ahkthread_free(v.1)
	;~ }
;~ }
for k,v in downloaded {
	if !FileExistValid(v.1)
		filedelete, % v.2
}
Loop {
	process,close,loadOldHx.exe
}until !ErrorLevel
;~ winclose,ahk_exe getAllJpeg.exe
;~ if(pToken)
	;~ Gdip_Shutdown(pToken)
;~ if noAdditionalHotkey
	;~ winclose,ahk_exe simpleRIS.exe
;~ listenerHwnd:=getListenerHwnd()
;~ winget,pid,pid,ahk_id %listenerHwnd%
;~ winget,list,list,ahk_pid %pid%
;~ Loop % List
	;~ WinClose,% "ahk_id " list%a_index%
;~ WinClose,decryptJpeg_main ahk_class AutoHotkeyGUI
;~ Run,% comspec " /c ""taskkill /PID " pid " /F /T""",,Hide
;~ PostMessage,0X02,,,,% "ahk_id " listenerHwnd
;~ PostMessage,0x10,,,,% "ahk_id " listenerHwnd
;~ PostMessage,0x12,,,,% "ahk_id " listenerHwnd
;~ WinClose,% "ahk_id " listenerHwnd
;~ WinKill,% "ahk_id " listenerHwnd
;~ Sleep 1000
winactivate,miniPACS Main ahk_class AutoHotkeyGUI
;~ GroupAdd,miniPACS,ahk_exe miniPACS.exe
;~ winclose,ahk_group miniPACS
;~ WinClose,miniPACS.exe ahk_class ConsoleWindowClass
;~ PostMessage,0x10101,,,,miniPACS_bridge_main ahk_class AutoHotkeyGUI
;~ PostMessage,0x10201,,,,getAllJpeg_main ahk_class AutoHotkeyGUI
;~ send_Data("pyPortal", {exit: 1})
;~ while 1
;~ {
	;~ Process,Close,pyPortal.exe
	;~ if !ErrorLevel
		;~ break
;~ }
	
;~ winclose,ahk_exe miniPACS_bridge.exe
notrayorphans()
exitapp
closeError:
return


WM_MOUSEMOVE( wparam, lparam, msg, hwnd ){
	if (wparam = 1){ ; LButton
		PostMessage, 0xA1, 2,,, A ;WM_NCLBUTTONDOWN
	}
	if !winactive("ahk_id " hwnd)
		winactivate,ahk_id %hwnd%
	
	
}
moveMsgBox:
if msgboxHwnd:=winexist("ahk_class #32770 ahk_exe PacsIE.exe") {
	winmove,ahk_id %msgBoxHwnd%,,% monitors.2.l+(monitors.2.w)/2,% (monitors.2.h)/2
	winset,AlwaysOnTop,on,ahk_id %msgBoxHwnd%
	;~ winset,AlwaysOnTop,off,ahk_id %msgBoxHwnd%
	settimer,moveMsgBox,off
}
return

openInImpax:
active:=false
,send_data("miniPACS", {"request_info":1, "from":"open_impax"})
return
;~ MinimizeMain()
openInImpax(AccNo){
	WinShow,% "ahk_id " impaxopened()[2,1]
	;~ WinShow,% "ahk_id " impaxopened()[2,2]
	;~ WinShow,% "ahk_id " impaxopened()[2,3]
	WinRestore,% "ahk_id " impaxopened()[2,1]
	;~ winset,AlwaysOnTop,on,% "ahk_id " impaxopened()[2,1]
	;~ winset,AlwaysOnTop,off,% "ahk_id " impaxopened()[2,1]
	DllCall("SetWindowPos", "Ptr", impaxopened()[2,1], "Ptr", -2, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	Winactivate,% "ahk_id " impaxopened()[2,1]
	cmdContextServer(str:="ADD_TO_DISPLAY_LIST || " (AccNo) " || SYNC_DISPLAY || " AccNo " || ", WinExist("ahk_exe ImpaxContextServer.exe"))
}
return
cmdContextServer(str,hwnd=""){
	DetectHiddenWindows,on
	if !hwnd && !hwnd:=winexist("ahk_exe ImpaxContextServer.exe")
		return 1
	Send_WM_COPYDATA(hwnd, 0, str)
}


^;::
controlget,editHwnd,hwnd,,Scintilla1,simple RIS ahk_class AutoHotkeyGUI
Edit_SetText(editHwnd, "post-operative changes.")
gosub sendReport
return

;~ #include <WorkerThread>
accNoChanged(){
	global 
	if keepSimpleRisActive
		settimer,activateSimpleRIS_2,-1
}


~Pause::
~PrintScreen::
~ScrollLock::
WinHide,ahk_group MyGUI
WinClose,ahk_group MyGUI
PostMessage,0x10101,,,,miniPACS Main ahk_class AutoHotkeyGUI
ExitApp
return
