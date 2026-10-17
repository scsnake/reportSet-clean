#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
SetBatchLines, -1
SetKeyDelay,-1,-1
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
SetTitleMatchMode,2
setformat,float,0.2
SetControlDelay,-1
#SingleInstance,force
#include <RisImpax>
#include <portallib>
#include <JXON>
#include <WM_COPYDATA>
ComObjError(false)
#include <resetHotstringBuffer>
resetHotstringBufferHook()
process,Priority,,h
DetectHiddenWindows,on
onexit,onexit

if instr(A_OSVersion, "10.0")
	__win11__:=true

CloseOtherYCHAHK()
OnScreenDisplay("YCH XR")
savedReportDir:=a_mydocuments "\feedRIS"
gosub openSimpleRIS
gosub RisGroup
gosub PacsIEgroup
global thisPlace:=getPlace()

gui,simpleRISsimpleEdit:new,+hwndsimpleRISsimpleEditGuiHwnd
WinSetTitle,ahk_id %simpleRISsimpleEditGuiHwnd%,,simpleRISsimpleEdit

__sendByClipboard_outputVarMode:=false
,OnMessage(0x1001, "sendByClipboard_outputVarMode")
,OnMessage(0x1002, "__sendByClipboard_outputVar_setText")
gui,1:new
gui,1:+hwndmainHwnd
WinSetTitle,ahk_id %mainHwnd%,,YCH_XR_main

if regexmatch(a_scriptdir,"is)(.+?)\\scripts\\Radiology$",match)
	root:=match1
else
	root:=a_scriptdir

;~ ThisScriptsHWND := WinExist("Ahk_PID " DllCall("GetCurrentProcessId"))
;~ winget,list,list,ahk_exe AutoHotkey.exe
;~ loop % list
	;~ if ThisScriptsHWND!=list%a_index%
		;~ PostMessage,0x10101,,,,% "ahk_id " list%a_index%


OnMessage(0x10101,"Exit")
,OnMessage(0x10104,"ImpaxNext")

,thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))
,RISImpaxRegister([{app: "Ris", type: "State", hwnd: thisHwnd, msg: {msg: 0x8000}, func: "RisStateChange", initStart: 1}])
,NoTrayOrphans()
;~ for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name = 'Autorun.exe' and not CommandLine like '%" A_ScriptName "%' ")
	;~ SendMessage,0x10103,,,,% "ahk_pid " process.ProcessId

askForPortalIdPw(0,0)
;~ ,RisImpaxInfo:=RisImpaxLoadPw("000000")
;~ ,IMPAX_id:=RisImpaxInfo.Impax.1.user
;~ ,IMPAX_pw:=RisImpaxInfo.Impax.1.pw
;~ ,RIS_id:=RisImpaxInfo.Ris.1.user
;~ ,RIS_pw:=RisImpaxInfo.Ris.1.pw
,IMPAX_title:="IMPAX 6.5.2.114 Radiologist with QC"
,bullet:="- "
,addPersonIdInd:=0
,RisState:=RisOpened()
,monitors:=monitorInfo()
,priorKeyWords:=[]
,boneKeywords:=["rib","fracture","bone","bony","\bsclero","lytic"]
	,lungKeyWords:=["(nodule|mass|tumor|lesion|metasta)"]
	,cancerKeywords:=["cancer","malignant","malignancy","lymphoma","leukemia","tumor"]
#Hotstring EndChars ()[]{}:;"\,.?!`n `t
#Hotstring T

;~ dynamic_hotstring("i)(b?n?c?a?p?d?t?l?u?v?)(\d)=$","examTitle",3)
dynamic_hotstring("i)([.\W])?(\d+)\.\.(\d+)(\W)","specifyImage",3,0)
;~ dynamic_hotstring("i)\b(\d+)p(\W)","pigtail",3)
;~ dynamic_hotstring("i)\b(\d+)\.(\d+)c(\W)","catheter",3)
;~ dynamic_hotstring("i)([ftpo]{2,4})9$","brainLobe",3)
,dynamic_hotstring("i)([apsiml]{2,3})(q?)(9)$","aspect",3,0)
;~ dynamic_hotstring("i)(\W)?(pcn)(\w)(\d)?(\W)","pcn",3)
;~ dynamic_hotstring("i)(\W)?(ptcd)(\w)(\d)?(\W)","ptcd",3)
,dynamic_hotstring("i)\b(\d{8}|\d{6})(r?)(\/|\.|\-)","insertDate",3,0)
;~ ,dynamic_hotstring("i)\b([ctls])([1-9]\d*)([^=\d\w])","spine",3,0)

;;; b: vertebral body
;  c: compression fracture
,dynamic_hotstring("i)\b([ctls])([123456789]\d?\d?\d?)([bc])?([^l\=\d\w])","spine",3, 0)

,dynamic_hotstring("i)\b([rlb])(\d\d?)r(\W)","RibNo",3,0)

,lineTubes:={t: "endotracheal tube"
	, k: "tracheostomy tube"
	, g: "nasoenteric tube"
	, v: "central venous catheter"
	, d: "double lumen catheter"
	, s: "Swan-Ganz catheter"
	, a: "implantable venous access port"
	, p: "cardiovascular implantable electronic device"
	, c: "chest tube"
	, i: "PICC"
	, b: "IABP"
	, m: "ECMO vascular cannula"
	, n: "drainage tube"
	, l: "pigtail catheter"
	, x: "VP shunt"
	, w: "coronary stent"
	, y: "aortic stent"
	, q: "biliary stent"
	, o: "esophageal stent"
	, z: "VAD"
	, j: "metallic sternal wires"
	, h: "status post cardiac valve replacement with sternal wiring"
	, r: "status post TAVI"}
,dynamic_hotstring("i)\b(3t|2t|3tr|2tr)?([a-z]+)?\/","lineTubes",3, 0)
,dynamic_hotstring("i)\b(\d+)(p[12345])(1?)(\W)","fingertoe",3, 0)
;~ dynamic_hotstring("i)\b([blr])(\w+?)(s?)//","combineHotstring",3)

;~ autoFocus:=["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y"]
;~ hotkey,ifwinactive,ahk_class WindowsForms10.Window.8.app.0.2bf8098
;~ for k,v in autoFocus
	;~ hotkey,% v,autoFocus
;~ hotkey,ifwinactive
,NoTrayOrphans()


menu, tray, icon,% a_scriptdir "\CXR.ico",1,0
;~ wingetpos,x,y,w,h,simple RIS ahk_class AutoHotkeyGUI
;~ monitors:=monitorInfo()
;~ WinMove,simple RIS ahk_class AutoHotkeyGUI,,% monitors.2.l+Floor(monitors.2.w/2)-500,% monitors.2.b-150,

gosub simpleRISnoUpdate
;~ settimer,simpleRISnoUpdate,1000

winwait,simpleRIS_main ahk_class AutoHotkeyGUI,,30
PostMessage,0x2025,0,,,simpleRIS_main ahk_class AutoHotkeyGUI
;~ PostMessage,0x2030,,,,simpleRIS__main ahk_class AutoHotkeyGUI
WinShow,miniPACS Main ahk_class AutoHotkeyGUI

resetHotstringBuffer(2000)
return

^;::
examname:=CH_RIS.examname

if (examname~="i)\bribs?\b"){
	NormalFinding:="no obvious displaced fracture. (Small bone fracture may not be detected by images.)"
}else if (examname~="i)\bchest\b|COVID-19"){
	NormalFinding:="no significant pulmonary nodular lesion identified. suggest clinical correlation."
}else if InStr(examname, "KUB") && InStr(examname, "Lumbar") {
	NormalFinding:="non-specific bowel gas. lumbar spondylosis. suggest clinical correlation."
}else if(examname~="i)abdomen|K.U.B."){
	NormalFinding:="non-specific bowel gas. suggest clinical correlation."
}else if(examname~="i)spine"){
	if InStr(examname, "thoracic")
		NormalFinding:="normal alignment of thoracic spine. suggest clinical correlation."
	else if InStr(examname, "thoracolumbar")
		NormalFinding:="thoracolumbar spondylosis. suggest clinical correlation."
	else if InStr(examname, "lumbar")
		NormalFinding:="lumbar spondylosis with marginal osteophyte formation. suggest clinical correlation."
	else if InStr(examname, "cervical")
		NormalFinding:="cervical spondylosis with marginal osteophyte formation. suggest clinical correlation."
}else{
	NormalFinding:="no obvious bony fracture. no evidence of joint subluxation or dislocation. suggest clinical correlation. (Small bone fracture or lesion may not be detected by the plain radiography.)"
}
winactivate,simple RIS ahk_class AutoHotkeyGUI
Edit_SetText(editHwnds[1], NormalFinding)
thishotkey:="F3"
gosub quicksend
return

pacsIEgroup:
GroupAdd,PacsIEgroup,miniPACS_bridge_main ahk_class AutoHotkeyGUI
;~ GroupAdd,PacsIEgroup,ahk_exe PacsIE.exe
;~ GroupAdd,PacsIEgroup,ahk_exe EbmIE.exe
;~ GroupAdd,PacsIEgroup,ahk_exe python.exe

return

ImpaxNext(){
	global
	impaxCyclicListDo()
	checkRis(RisState)

	++thisStudyInd

	if !(impaxContextServerHwnd:=ImpaxContextServer_Init()) {
		return
	}
	sheetNo:=getRisSheetNo(RisState[2])
	PostMessage,0x10101,,,,ahk_exe checkRReport.exe
	SendStr:=""



	for k,v in reportList
		if (k>1 && v[AccNoCol]=sheetNo) {
			thisReport:=v
			,sendStr.="SYNC_DISPLAY || " reportList[k+1,AccNoCol] " || "
			,sendStr.="ADD_TO_DISPLAY_LIST_WITH_PRIORS || " reportList[k+2,AccNoCol] " || "
			,ImpaxContextServer_SendCommand(sendstr,impaxContextServerHwnd)
			;~ msgbox % sendStr
			break
		}


}

!t::
tooltip,% "Fast mode " ((fastMode:=!fastMode)?"ON":"OFF") " !!"
menu, tray, icon,% a_scriptdir "\CXR" (fastMode?"_fast":"") ".ico",1,0


Loop,parse,ghotkeys
	Hotkey,% "+!" A_LoopField,% fastMode?"fastReport":"off"

;~ Hotkey,IfWinExist,ahk_exe PacsIE.exe
;~ Hotkey,;,% fastMode?"fastModeSend":"Off"
;~ Hotkey,IfWinActive
;~ Hotkey,IfWinExist,WM_COPYDATA_Listener
;~ Hotkey,;,% fastMode?"fastModeSend":"Off"
;~ Hotkey,IfWinActive
settimer,tooltip,-1000
;~ gosub simpleRISnoUpdate
;~ setTimer,simpleRISnoUpdate,% fastMode?(5000):"off"
;~ PostMessage, 0x111, 65305,,,ahk_exe Hotstring Helper.exe
return

fastModeSend:
PostMessage,0x10203,,,,ahk_group PacsIEgroup
return

simpleRISnoUpdate:
PostMessage,0x2022,3600000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
return
#l::
str:=""
for k,v in lineTubes
	str.=k ": " v "`r`n"
tooltip % str
settimer,tooltip,-4000
return

;~ tooltip:
;~ ToolTip
;~ return

Exit(){
	Exitapp
}

fingertoe:
order:=["1st", "2nd", "3rd", "4th", "5th"]
,parts:={p1: "distal phalanx bone", p2: "middle phalanx bone", p3: "proximal phalanx bone", p4: "metacarpal bone", p5: "metatarsal bone"}
,order_which := $.value(1)
,parts_which := $.value(2)
,Multi_:=$.value(3)?"s":""

if StrLen(order_which)==1 {
	order_:=order[order_which]
}else if StrLen(order_which)==2 {
	order1:=SubStr(order_which,1,1)
	,order2:=SubStr(order_which,2,1)
	
	if Abs(order1-order2)==1 {
		order_:=order[order1] " and " order[order2]
		, Multi_:="s"
	}else{
		order_:=order[order1] " to " order[order2]
		, Multi_:="s"
	}
	
}else if StrLen(order_which)==2 {
	resultArray:=[]
	 ; Split the string into individual characters
    Loop, Parse, order_which
    {
        ; Convert character to number and get the corresponding array element
        resultArray.Push(order[A_LoopField])
    }

    ; Join elements in the result array with ",", and the last one with "and"
    outputString := ""
    totalItems := resultArray.MaxIndex()
    Loop, % totalItems
    {
        if (A_Index < totalItems - 1)
            outputString .= resultArray[A_Index] . ", "
        else if (A_Index = totalItems - 1)
            outputString .= resultArray[A_Index] . " and "
        else
            outputString .= resultArray[A_Index]
    }
	order_:=outputString
	,Multi_:="s"
}

sendByEdit(order_ " " parts[parts_which] Multi_ $.value(4), $.value(0))

return

lineTubes:
result:="placement of "
,hasPlacementOf:=InStr(FocusedText:=ControlGetText(Focused:=getFocusedHwnd()), result)
,hasSternalWire:=InStr(FocusedText, "metallic sternal wires")
,str:=$.value(2)
if($.value(0)="="){
	return
}
if($.value(0)="w/"){
	;~ send with
	return
}
if InStr($.value(0), "button") ; contains special button
	return 
;~ send % "{bs " strlen($.value(0)) "}"
;~ focusedEditBS(StrLen($.value(0)))
;~ Sleep 20
if ($.value(1)="3t")
	str:="tgv" str
else if($.value(1)="2t")
	str:="tg" str
else if($.value(1)="3tr")
	str:="kgv" str
else if($.value(1)="2tr")
	str:="kg" str
str2:=""
loop,parse,str
{
	if a_loopfield in j,h,r
		str2.=lineTubes[a_loopfield] ". "
	else if (v:=lineTubes[a_loopfield])
		result.=v ", "
}

;~ ind:=1,max:=strlen(str)
;~ loop {
	;~ key:=substr(str,ind,1)
	;~ if v:=lineTubes[key]
		;~ result.=v ", ",ind+=1
	;~ else
		;~ ++ind
;~ }until ind>max
if(hasSternalWire)
	StringReplace,result,result,% "metallic sternal wires. ",

OnScreenDisplay(str)
if (result!="placement of ")
	;~ send % RegExReplace(result,"\, $",".") str2
	if(!hasPlacementOf){
		sendByEdit(RegExReplace(result,"\, $",".") str2, $.value(0))
	}else{
		Edit_InsertText(Focused, SubStr(result, 14), hasPlacementOf+12)
		sendByEdit("", $.value(0))
	}
else
	;~ send % str2
	sendByEdit(str2, $.value(0))

return

getReportList:
parseDataGrid(RisListHwnd?RisListHwnd:RisListHwnd:=getRisList(RisState[2]),reportList)
return

impaxNextStudy:
checkRis(RisState)


,editHwnds:=getSimpleRisEditHwnds()

,resetSimpleRis()
if !(impaxContextServerHwnd:=ImpaxContextServer_Init()) {
	return
}

if winexist("ahk_group PacsIEgroup") {
	gosub PacsIEnextStudy

}else{
	sheetNo:=getRisSheetNo(RisState[2])
	SendStr:=""
	for k,v in reportList
		if (k>1 && v[AccNoCol]=sheetNo) {
			thisReport:=v
			,sendStr.="SYNC_DISPLAY || " reportList[k+1,AccNoCol] " || "
			,sendStr.="ADD_TO_DISPLAY_LIST_WITH_PRIORS || " reportList[k+2,AccNoCol] " || "
			,ImpaxContextServer_SendCommand(sendstr,impaxContextServerHwnd)
			;~ msgbox % sendStr
			break
		}
}
;~ if (++impaxNextStudy>10){

	;~ impaxNextStudy:=0
;~ }
winactivate % "ahk_id " (simpleRis:=getSimpleRisGuiHwnds()[2])?simpleRis:RisState[2]
return

^F5::
if !simpleImpaxPwb
	simpleImpaxPwb:=ComObjCreate("InternetExplorer.Application")
;~ simpleImpaxPwb.Visible:=true
simpleImpaxPwb.navigate(getSimpleImpaxUrl(getRisChartNo(RisState[2]), thisAccNo:=getRisSheetNo(RisState[2])))

;~ simpleImpaxModeInd:=reportList.getRow("AccNo", thisAccNo).rowNo
return

simpleImpaxPwbNext(){
	global
	if !simpleImpaxPwb
		simpleImpaxPwb:=ComObjCreate("InternetExplorer.Application")
	simpleImpaxPwb.navigate(getSimpleImpaxUrl(getRisChartNo(RisState[2]), getRisSheetNo(RisState[2])))
}




;~ #IfWinExist,ahk_exe impax-client-main.exe
F3:
F3::
F1:
F1::
F2:
F2::
thishotkey:=A_ThisHotkey
quicksend:
;~ ToolTip ychxr
if miniPACShwnd:=WinExist("miniPACS_bridge_main ahk_class AutoHotkeyGUI") {
	;~ ToolTip % miniPACShwnd
	;~ Send_WM_COPYDATA(miniPACShwnd, 0, jxon_dump({"sendReport":1}))
	PostMessage,0x10203,,,,miniPACS_bridge_main ahk_class AutoHotkeyGUI
	return
}

if simpleImpaxPwb {
	if (simpleImpaxModeInd++)
		simpleImpaxPwb.navigate(getSimpleImpaxUrl(reportList.getCell(simpleImpaxModeInd, "ChartNo"), reportList.getCell(simpleImpaxModeInd, "AccNo")))
	else
		SetTimer,simpleImpaxPwbNext,-500
}

if (!fastMode) {
	;~ if(recentSent)
		;~ return

	;~ impaxCyclicListDo()

	if (!editHwnds.length() || !controlexists(editHwnds[2]))
		editHwnds:=getSimpleRisEditHwnds()

	gosub checkReport
	;~ if incomplete
		;~ return
	;~ gosub impaxNextStudy
	;~ recentSent:=true
	;~ SetTimer,recentSent,-2000
	if instr(thishotkey,"F3") {
		;~ if (!sendButton || !controlexists(sendButton))
			;~ sendButton:=getNetControl2(RisState[2],"????","cmdRunVerifySend","????","WindowsForms10.BUTTON.app","","","",0)[1]
		;~ controlclick,,% "ahk_id " sendButton
		;~ acc_objectfromwindow(sendButton).accDoDefaultAction()
		risSendReport(RisState[2], 3)
		settimer,newfilm2,-1000
	}else if instr(thishotkey,"F1") {
		;~ if (!saveButton || !controlexists(saveButton))
			;~ saveButton:=getNetControl2(RisState[2],"??","cmdRunSave","??","WindowsForms10.BUTTON.app","","","",0)[1]
		;~ controlclick,,% "ahk_id " saveButton
		;~ acc_objectfromwindow(saveButton).accDoDefaultAction()
		risSendReport(RisState[2], 1)
	}else if instr(thishotkey,"F2"){
		;~ if (!verifyButton || !controlexists(verifyButton))
			;~ verifyButton:=getNetControl2(RisState[2],"??","cmdRunVerify","??","WindowsForms10.BUTTON.app","","","",0)[1]
		;~ controlclick,,% "ahk_id " verifyButton
		;~ acc_objectfromwindow(verifyButton).accDoDefaultAction()
		risSendReport(RisState[2], 2)
	}
	settimer,activateSimpleRis,-1
	++thisStudyInd
	settimer,nextOldStudy,-1000
	;~ if regexmatch(reportList[thisStudyInd,examNameCol],"is)^Chest"){
		;~ showPriorKeyWords(thisStudyInd)
	;~ }
	;~ parseDataGrid(RisListHwnd?RisListHwnd:RisListHwnd:=getRisList(RisState[2]),reportList, 0, 0, 0, [thisStudyInd+2])
	;~ if regexmatch(reportList[thisStudyInd+2,examNameCol],"is)^Chest"){
		;~ addPriorKeyWords(priorKeyWords,thisStudyInd+2)
	;~ }



}else{
	;~ if (!RisAccNoHwnd || !controlexists(RisAccNoHwnd)){
		;~ checkRis(RisState)
		;~ RisAccNoHwnd:=getRisAccNoHwnd(RisState[2])
	;~ }

	if (!editHwnds.length() || !controlexists(editHwnds[2]))
		;~ controlget,editHwnd,hwnd,,Scintilla1,simple RIS ahk_class AutoHotkeyGUI
		editHwnds:=getSimpleRisEditHwnds()
	gosub checkReport
	if incomplete
		return
	gosub PacsIEnextStudy
	settimer,activateSimpleRis,-1
	;~ sendmessage,0x10404,,,,simple RIS ahk_class AutoHotkeyGUI
	;~ controlsettext,,% "",ahk_id %editHwnd%
	;~ Edit_SetText(editHwnd, "")
	resetSimpleRis()
}

return


nextOldStudy:
;~ if (getRisChartNo(RisState[2])=getImpaxChartNo()){
if RisChartNoMatchPacs(RisState, ImpaxState){
	risOpenOldStudy(RisState[2])
}else{
	PostMessage,0x10102,1,,,impaxOpenNext_main ahk_class AutoHotkeyGUI
}
return

NoText:
msgbox % "No text!"
return

activateSimpleRis:
PostMessage,0x2028,,,,simpleRIS_main ahk_class AutoHotkeyGUI
return

addPriorKeyWords(byref priorKeyWords,studyInd){
	global reportList,loginId,loginPw,sid,chartNoCol,lungKeyWords,boneKeyWords,cancerKeyWords,RisState,RisListHwnd,risPtInfoHwnd
	if !isobject(reportList[studyInd])
		parseDataGrid(RisListHwnd?RisListHwnd:RisListHwnd:=getRisList(RisState[2]),reportList, 0, 0, 0, [studyInd])

	;~ if !regexmatch(reportList[studyInd,examNameCol],"is)(Chest.*(AP|PA))|(Chest.*Lateral)")
		;~ return

	keyword:=""

	;~ if !controlexists(risPtInfoHwnd)
		;~ risPtInfoHwnd:=getNetControl2(RisState[2],"","txtALL","","WindowsForms10.EDIT","","","",0)[1]
	;~ keyword.=matchText(controlgettext(risPtInfoHwnd),cancerKeywords)
	CXRind:=0,CTind:=0
	for k,v in RisReport2Yr:=parseRisReport2Yr(RisReport2Yr(checksid(sid)?sid:sid:=login(loginid,loginpw),reportList[studyInd,chartNoCol])) {
		if regexmatch(priorExamItem:=v.1.1,"is)Chest.*(AP|PA)") && (++CXRind<11) {
			tmp:=matchText(v.2,boneKeyWords)
			keyWord.=tmp=""?"":(RegExReplace(substr(v.1.3,1,10),"\/","") "CXR: " tmp)
		}else if regexmatch(priorExamItem,"is)CT.*Chest|low dose") && (++CTind<2) {
			tmp:=matchText(v.3,lungKeyWords)
			keyWord.=tmp=""?"":(RegExReplace(substr(v.1.3,1,10),"\/","") "CT: "  tmp)
		}
	}



	priorKeyWords[studyInd]:=filterDuplicate(keyword)


}

showPriorKeyWords(thisStudyInd){
	global


	gui,hx:default
	gui,destroy
	if(priorKeyWords[thisStudyInd]="")
		return
	gui,color,black
	gui,+alwaysontop +hwndguiHwnd +toolwindow -Caption
	gui,font,s12 cwhite,Verdana
	gui,add,text,,% keyword:=priorKeyWords[thisStudyInd]
	;~ hxMonitor:=monitors[monitors.maxindex()>2?3:1]
	hxMonitor:=monitors[monitors.maxindex()>2?3:1]
	;~ gui,show,% "x" hxMonitor.l+10 " y" hxMonitor.b-200 " autosize noactivate",Prior Keywords
	gui,show,% "x" 400 " y" 364 " autosize noactivate",Prior Keywords
	settimer,killGui2,% -1000+(-1)*strlen(keyword)*50
	PostMessage,0x2028,,,,simpleRIS_main ahk_class AutoHotkeyGUI

}


killGUI2:
gui,hx:destroy
return

PacsIEnextStudy:
;~ wingettitle,title,PacsIE Log GUI ahk_class AutoHotkeyGUI
;~ regexmatch(title,"PacsIE Log GUI (\w+):",PacsIEHwnd)
;~ sendmessage,0x10504,,,,ahk_id %PacsIEHwnd1%
PostMessage,0x10504,,,,ahk_group PacsIEgroup
;~ winactivate,% "ahk_id " PacsIEGUIHwnd:=WinGetAtCoords(1700,300,"ID")
;~ winwaitactive,% "ahk_id " PacsIEGUIHwnd,,1
;~ sendlevel,2
;~ send {F12}

return

autoFocus:
checkRis(RisState)
gosub renewRisReports
winactivate,% "ahk_id " risHwnd:=RisState[2]
controlfocus,,% "ahk_id " risReport:=RisReports[1,1]
winwaitactive,ahk_id %risHwnd%
send % regexreplace(a_thishotkey,"\W","")
return

;~ #IfWinExist

addPersonId:
Thread, Priority, -5000
if (++addPersonIdInd)>reportList.maxindex() {
	settimer,addPersonId,off
	return
}
if !checksid(sid)
	sid:=login(loginId,loginPw)
if (reportList[addPersonIdInd,statusCol]="????") || !regexmatch(reportList[addPersonIdInd,examNameCol],"^Chest")
	settimer,addPersonId,-200
else
	settimer,addPersonId,-2000
reportList[addPersonIdInd,personIdCol]:=patientBasicInfo(reportList[addPersonIdInd,chartNoCol],sid).personId
reportList[addPersonIdInd,personIdCol+1]:=parseRisReport2Yr(RisReport2Yr(sid,reportList[addPersonIdInd,chartNoCol])).clone()
;~ tooltip,test %addPersonIdInd%
return

#ifwinactive,ahk_group RisGroup
f8::
checkRis(RisState)
reportList:=[]
DetectHiddenWindows,on
settimer,newFilm2,-1

if !(impaxContextServerHwnd:=ImpaxContextServer_Init()) {
	return
}
parseDataGrid(RisListHwnd?RisListHwnd:RisListHwnd:=getRisList(RisState[2]),reportList, 0, 1)
for k,v in reportList[1] {
	if (v="????") {
		AccNoCol:=k
	}
	if (v="???") {
		chartNoCol:=k
	}
	if (v="????") {
		examNameCol:=k
	}
	if (v="??") {
		statusCol:=k
	}
}
personIdCol:=k+1
;~ settimer,addPersonId,-2000
,sheetNo:=getRisSheetNo(RisState[2])
,SendStr:=""
,parseDataGrid(RisListHwnd,reportList, 0, 4, 0, [AccNoCol, sheetNo])
for k,v in reportList
	if (k>1 && v[AccNoCol]=sheetNo) {
		thisStudyInd:=k
		,sendStr.="SYNC_DISPLAY || " v[AccNoCol] " || "
		,sendStr.="ADD_TO_DISPLAY_LIST_WITH_PRIORS || " reportList[k+1,AccNoCol] "\" reportList[k+2,AccNoCol] "\" reportList[k+3,AccNoCol] " || "
		;~ sendStr.="ADD_TO_DISPLAY_LIST_WITH_PRIORS || " reportList[k+1,AccNoCol] " || "
		;~ sendStr.="ADD_TO_DISPLAY_LIST_WITH_PRIORS || " reportList[k+2,AccNoCol] " || "
		;~ sendStr.="ADD_TO_DISPLAY_LIST_WITH_PRIORS || " reportList[k+3,AccNoCol] " || "
		ImpaxContextServer_SendCommand(sendStr,impaxContextServerHwnd)
		break
	}
simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")
;~ controlsettext,Scintilla1,% "",ahk_id %simpleRis%
,editHwnds:=getSimpleRisEditHwnds()
settimer,activateSimpleRis,-1
addPriorKeyWords(priorKeywords,thisStudyInd)
,showPriorKeyWords(thisStudyInd)
,addPriorKeyWords(priorKeywords,thisStudyInd+1)
,addPriorKeyWords(priorKeywords,thisStudyInd+2)
;~ settimer,getReportList,-1

return

checkSameStudy:
checkRis(RisState)
if (hwnd:=winexist("PacsIE Log GUI ahk_class AutoHotkeyGUI")) ||  (hwnd:=winexist("EbmIE Log GUI ahk_class AutoHotkeyGUI")) {
	wingettitle,title,ahk_id %hwnd%
	if !instr(title,getRisChartNo(RisState[2]))
		msgbox % "Different patient chart numbers !!!! "
}else {
	if getRisChartNo(RisState[2])!=getImpaxChartNo(ImpaxOpened()[2,1])
		msgbox % "Different patient chart numbers !!!! "
}
return

F3::
gosub F3
return
F1::
gosub F1
return
F2::
gosub F2
return
#ifwinactive


#IfWinActive,simple RIS ahk_class AutoHotkeyGUI
F3::
gosub F3
return
F1::
gosub F1
return
F2::
gosub F2
return
#ifwinactive


checkReport:

risReports:=getRisReports(RisState[2])
,editHwnds:=getSimpleRisEditHwnds()
if !fastMode
	gosub copyToRis
else
	text:=controlgettext(editHwnds[2])


if (trim(text)="")
	goto NoText

if (CH_RIS.examname~="i)Chest PA|Chest AP|Chest 橫放包含兩肩|COVID\-19") && !regexmatch(Text,"i)normal heart size|cardiomegaly|borderline heart size|heart border|opacified (left|right) hemithorax")
		Text:="Normal heart size. " Text

Text:=reportReplace(Text)
;~ text:=RegExReplace(text,"\.+",".")
text:=RegExReplace(text,"(\w)\.+ *\.+(\w)","$1. $2")
text:=RegExReplace(text,"\ {2,}(?!(-+ |\d+\W ))"," ")
,text:=RegExReplace(text,"(?<=[\,\.\;\(])\ {2,}"," ")
;~ text:=RegExReplace(text," {2}"," ")
,text:=RegExReplace(text,"\.{2,}",".")
,text:=RegExReplace(text,",{2,}",",")
,text:=RegExReplace(text,"\.\,",",")
,text:=RegExReplace(text,"\,\.",".")
,text:=RegExReplace(text,"\ ([,.;])","$1")
,text:=RegExReplace(text,"i)([a-z])\. ([a-z])","$1.$2")
,text:=RegExReplace(text,"([,;])(\w)","$1 $2")
,text:=RegExReplace(text,".\ {2,}(\r?\n)",". $1")
,text:=RegExReplace(text,"(^(\r?\n)+)|((\r?\n)+$)","")
,text:=RegExReplace(text,"at at","at ")
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

if InStr(newText, "degenerative change of the spine with compression fracture.") && InStr(newText, "degenerative change of the spine.")
	newText:=RegExReplace(newText, "i)degenerative change of the spine\.", "")
	,newText:=RegExReplace(newText, " {2,}", " ")
hasCorrelation:=RegExMatch(newText, "i)suggest [a-z \-]*(correlation|evaluation|follow)")
if InStr(newText, "suggest clinical correlation.")
	newText:=RegExReplace(newText, "i)suggest clinical correlation.", "")
	,newText:=RegExReplace(Trim(newText), "is)(.+) *(\([^\)]+\))?", "$1 Suggest clinical correlation. $2")
else if !hasCorrelation
	newText:=RegExReplace(Trim(newText), "is)(.+) *(\([^\)]+\))?", "$1 Suggest clinical correlation. $2")
newText:=RegExReplace(newText,"\ {2,}(?!(-+ |\d+\W ))"," ")
,newText:=RegExReplace(newText,"\.\)\.",".)")


if(!fastMode){
	;~ Exam:=trim(parseRisExamItems(getRisExamItems(RisState[2]))[1,1])
}else{
	Exam:=thisAccNo:=thisChartNo:=""
	if winexist("PacsIE Log GUI ahk_class AutoHotkeyGUI"){
		wingetTitle,title,PacsIE Log GUI ahk_class AutoHotkeyGUI
	}else if WinExist("EbmIE Log GUI ahk_class AutoHotkeyGUI"){
		wingetTitle,title,EbmIE Log GUI ahk_class AutoHotkeyGUI
	}
	regexmatch(title,"is): ([^ ]+) ([^ ]+) ([^\n]+)",match)
	,Exam:=match3,thisAccNo:=match1,thisChartNo:=match2
	ToolTip % title "," exam "," thisAccNo "," thisChartNo
}

gosub incomplete
if incomplete
	return
if (__win11__){
	load_dir := "\\Mac\shared\test_dicom"  ;; use network drive to write file, use workingdir with local mapping drive to loop!!!
	old_wd := A_WorkingDir
	SetWorkingDir, Z:\test_dicom\miniPACS_action
	thisAccNo:=thisChartNo:=""
	loop,files,*,F
	{
		if instr(a_loopfilename, "thisStudy_") {
			RegExMatch(A_LoopFileName, "i)thisStudy_([^_]+)_([^_]+)", match)
			thisAccNo:=match1, thisChartNo:=match2
			break
		}
	}
	if(thisAccNo="")
		msgbox % "Can't get AccNo"
	else{
		SetWorkingDir,% old_wd
		filedelete,% filePath:=load_dir "\" thisAccNo " " thisChartNo ".txt"
		fileappend,% addTitle(newText,"",thisAccNo,thisChartNo) "`r`n-=-=-=-=-`r`n",% filePath,utf-8
		if (!ErrorLevel){
			FileRemoveDir,% load_dir "\" thisAccNo " " thisChartNo
			FileRemoveDir,% "Z:\test_dicom\" thisAccNo " " thisChartNo
		}
		tooltip % "Saved: " thisAccNo ", " thisChartNo
		settimer,tooltip,-1000
		fileappend,% "",% "Z:\test_dicom\miniPACS_action\minipacs_next_study"
		settimer,resetSimpleRis,-1
		settimer,activateSimpleRis,-500
	}
}else if (!fastMode){
	;~ SetTimer,simpleRISnoUpdate,1000
	if RegExMatch(newText, "(通報臨床醫師\d+|疑似肺結核|通報臨床醫師\(急\)) ?", pmmatch) {
		StringReplace,newText,newText,% pmmatch,,all
		newText.= "`r`n`r`n" pmmatch
	}


	Edit_SetText(getRisReports()[1,1], addTitle(newText))
	Edit_SetText(getRisReports()[1,2], "")
	CH_RIS.flush()
}else {
	if (thisAccNo="" || thisChartNo=""){
		msgbox,,,% "Accession No or chart No error !!!",5
		return
	}
	filedelete,% filePath:=savedReportDir "\" thisAccNo " " thisChartNo ".txt"
	fileappend,% addTitle(newText,Exam,thisAccNo,thisChartNo) "`r`n-=-=-=-=-`r`n",% filePath,utf-8
	tooltip % "Saved !"
	settimer,tooltip,-1000
}



return

#If % __win11__
F12::
fileappend,% "",% "Z:\test_dicom\miniPACS_action\minipacs_next_study"
return
#If

addTitle(newText,exam="",accNo="",chartNo=""){
	global risstate,fastMode,thisPlace
	if instr(newText,"EXAMINATION:")
		return newText
	if instr(newText,"shows")
		newText:=RegExReplace(newText,"is)^.+shows\s*","")
		,newText:=stringupper(substr(newText,1,1)) substr(newText,2)
	if(!fastMode){
		;~ indication:=trim(getIndication(RisHwnd:=RisState[2]))

		RegExMatch(clinicalHx:=getClinicalInfo(RisState[2]),"?SPECIAL MEDICAL?\r?\n???:([^\r\n\[]+)",match)
		if !regexmatch(match1:=trim(match1),"\w")
			match1:=""
		if(exam=""){
			for k,v in parseRisExamItems(getRisExamItems(RisState[2]))[2]
				exam.=trim(v) "; "
			exam:=substr(exam,1,-2)
		}

	}
	if RegExMatch(exam,"is)Chest ?: (PA|AP) View") && !regexmatch(newText,"i)normal heart size|cardiomegaly|borderline heart size|heart border|opacified (left|right) hemithorax")
		heartSize:="Normal heart size. "
	exam:=RegExReplace(exam," ?: ?"," - ")
	if exam=
		return  (chartNo=""?"":"Chart No: " chartNo "`r`n") (accNo=""?"":"Accession No: " accNo "`r`n") "FINDINGS:`r`n" heartSize RegExReplace(newText,"(^(\r?\n)+)|((\r?\n)+$)","")
	else
		return  (chartNo=""?"":"Chart No: " chartNo "`r`n") (accNo=""?"":"Accession No: " accNo "`r`n") "EXAMINATION: " exam (match1=""?"":" (" match1 ")") "`r`nFINDINGS:`r`n" heartSize RegExReplace(newText,"(^(\r?\n)+)|((\r?\n)+$)","")
}

incomplete:
selStart:=0,incomplete:=0
loop,parse,newText,`.
	if strlen(line:=trim(a_loopfield))<5 && regexmatch(line,"^[a-z]+\d*?$") {
		incomplete:=1
		break
	}else{
		selStart+=strlen(a_loopfield)+1
	}

if (incomplete){
	msgbox,4144,, % "Check the report for AHK error!"
	;~ controlsettext,,% newText,ahk_id %editHwnd%
	Edit_SetText(editHwnds[2], newText)
	,Edit_SetText(editHwnds[1], newText)
	,Edit_setsel(editHwnds[2],seltStart,selStart+strlen(line))
	,Edit_setsel(editHwnds[1],seltStart,selStart+strlen(line))
	,Edit_ScrollCaret(editHwnds[2])
}
return

;-----------------------------general
;~ :*:.::
;~ send % ". "
;~ return
#Hotstring, SI

;~ :*:zx::
;~ send unchanged findings as compared with the last similar study. suggest clinical correlation.
;~ gosub F3
;~ return
;~ :*:xz::
;~ send other findings are unchanged as compared with the last similar study.
;~ gosub F3
;~ return

:*:zx::this study is reassigned to current radiologist on

::comp::as compared with previous study on
;~ ::com0::as compared with previous study.

::lt::line(s) and/or tube(s) in position.



::o::opacity
:*:o1::opacities
::sh::shadow
::d::density
:*:d1::densities

::ao::atherosclerosis with wall calcification of the aorta.
::aoi::atherosclerosis with wall calcification of the aorta and biliateral iliac arteries.
::ca::calcification
:*:ca1::calcifications
::cao::calcifications of aorta.

::cmi::presence of contrast medium in

::isd::increased soft tissue density shadow at

;~ :*:zv::(Due to work overload of the radiologists, this report is completed in limited reading time, which may cause suboptimal detection rate for the lesions. Suggest double-reading by the clinician and correlate with clinical information.)
:*:zv::
send zv{Space}
return
::z::
quicksendFunc("z", "suggest clinical correlation.")
return
::zf::suggest clinical correlation and follow up.
::zct::suggest CT study for further evaluation.
::zmr::suggest MRI study for further evaluation.
::zus::suggest ultrasound study for further evaluation.
::zfa::suggest decubitus (>5min) abdomen with cross-table x-ray or standing (>5mm) CXR cover upper abdomen image to detect possible free air.
::zl::suggest lateral view for further evaluation.
::zpa::suggest correlate with AP/PA view.

;~ ::op::postoperative changes with surgical materials
::op::postoperative changes
:*:wq::postoperative changes.
::OO::post-operative changes with
::OOC::post-operative change with clips at
::OOCS::post-operative change with clips & suture materials at
::OOI::post-operative change with implant at
::OOS::post-operative change with suture materials at
::OOT::post-operative changes with tube(s) in the field of view with appropriate position,
::OOTSSG::post-operative changes with tube(s) in the field of view with appropriate position, sationary in compare to previous similar study, suggest correlate with clinical manifestration.
::OW::post-operative change with wiring at
::OX::status post internal fixation,
::coi::status post coil embolization at

::sil::silhouette
::si::superimposed
::sio::superimposed on


::AFL::air-fluid level
:*:AFL1::air-fluid levels

::clp::surgical clips at

;-----------------------------CXR
;-----------one alphabet
;~ ::a::a
;~ ::b::bilateral
::c::normal heart size. no obvious pulmonary nodular or mass lesion.
;~ ::d::density
;~ ::e::at
;~ ::f::from
::g::cardiomegaly
::mg::mild cardiomegaly
::h::hazy opacities at
::hb::hazy opacities at bilateral lungs
::hbl::hazy opacities at bilateral lungs, more on the left side.
::hbr::hazy opacities at bilateral lungs, more on the right side.
::hl::hazy opacities at left lung
::hr::hazy opacities at right lung

:*:hru::hazy opacities at right upper lung field.
:*:hrm::hazy opacities at right middle lung field.
:*:hrl::hazy opacities at right lower lung field.
:*:hlu::hazy opacities at left upper lung field.
:*:hlm::hazy opacities at left middle lung field.
:*:hll::hazy opacities at left lower lung field.

:*:ndru::nodular opacity at right upper lung field.
:*:ndrm::nodular opacity at right middle lung field.
:*:ndrl::nodular opacity at right lower lung field.
:*:ndlu::nodular opacity at left upper lung field.
:*:ndlm::nodular opacity at left middle lung field.
:*:ndll::nodular opacity at left lower lung field.

:*:maru::mass at right upper lung field.
:*:marm::mass at right middle lung field.
:*:marl::mass at right lower lung field.
:*:malu::mass at left upper lung field.
:*:malm::mass at left middle lung field.
:*:mall::mass at left lower lung field.

:*:conru::consolidation at right upper lung field.
:*:conrm::consolidation at right middle lung field.
:*:conrl::consolidation at right lower lung field.
:*:conlu::consolidation at left upper lung field.
:*:conlm::consolidation at left middle lung field.
:*:conll::consolidation at left lower lung field.

:*:ioru::ill-defined opacities at right upper lung field.
:*:iorm::ill-defined opacities at right middle lung field.
:*:iorl::ill-defined opacities at right lower lung field.
:*:iolu::ill-defined opacities at left upper lung field.
:*:iolm::ill-defined opacities at left middle lung field.
:*:ioll::ill-defined opacities at left lower lung field.

:*:ihdru::increased hazy densities at right upper lung field.
:*:ihdrm::increased hazy densities at right middle lung field.
:*:ihdrl::increased hazy densities at right lower lung field.
:*:ihdlu::increased hazy densities at left upper lung field.
:*:ihdlm::increased hazy densities at left middle lung field.
:*:ihdll::increased hazy densities at left lower lung field.

::i::bilateral increased interstitial infiltration
::j::tortuous aorta
::k::calcifications of aorta
;~ ::l::left
;~ ::m::mild
;~ ::o::opacity
::p::increased hazy densities at right lower lung field with obscured right lateral costophrenic angle
::q::increased hazy densities at left lower lung field with obscured left lateral costophrenic angle

;~ ::r::right
::s::ill-defined opacities at bilateral lungs
;~ ::t::the
::u::increased bilateral perihilar infiltration
::v::no significant pulmonary nodular lesion identified
::vz::
quicksendFunc("vz", "no significant pulmonary nodular lesion identified. suggest clinical correlation.")
return
::kvz::
quicksendFunc("kvz", "calcifications of aorta. no significant pulmonary nodular lesion identified. suggest clinical correlation.")
return
::vxz::
quicksendFunc("vxz", "no significant pulmonary nodular lesion identified. degenerative change of the spine. suggest clinical correlation.")
return
:*:vxxz::
quicksendFunc("vxxz", "no significant pulmonary nodular lesion identified. degenerative change of the spine with compression fracture. suggest clinical correlation.")
return
:*:kvxz::
quicksendFunc("kvxz", "calcifications of aorta. no significant pulmonary nodular lesion identified. degenerative change of the spine. suggest clinical correlation.")
return
:*:kvxxz::
quicksendFunc("kvxxz", "calcifications of aorta. no significant pulmonary nodular lesion identified. degenerative change of the spine with compression fracture. suggest clinical correlation.")
return
::w::increased hazy opacities at bilateral lower lung fields
::x::degenerative change of the spine
;~ ::y::y
;~ ::z::suggest clinical correlation
::kj::tortuous aorta with calcification
::gk::cardiomegaly. calcifications of aorta.
::gkj::cardiomegaly. tortuous aorta with calcification.
::gj::cardiomegaly. tortuous aorta.
::gq::cardiomegaly. increased hazy densities at left lower lung field with obscured left lateral costophrenic angle.
::gp::cardiomegaly. increased hazy densities at right lower lung field with obscured right lateral costophrenic angle.
::go::cardiomegaly. bilateral lung opacities.
::gc::cardiomegaly. bilateral lung consolidation.
::cb::bilateral lung consolidation. obscured bilateral costophrenic angles.
::cl::bilateral lung consolidation. bilateral pleural effusion.
::xx::degenerative change of the spine with compression fracture.
::bc::bilateral lung consolidation.
::bcr::bilateral lung consolidation, more on the right side.
::bcl::bilateral lung consolidation, more on the left side.
::bcf::bilateral lung consolidation and/or pleural effusion.
::bcfr::bilateral lung consolidation and/or pleural effusion, more on the right side.
::bcfl::bilateral lung consolidation and/or pleural effusion, more on the left side.
::lcf::left lung consolidation and/or pleural effusion.
::rcf::right lung consolidation and/or pleural effusion.
::lce::left lung consolidation and pleural effusion.
::rce::right lung consolidation and pleural effusion.
::rz::obscured right lateral costophrenic angle.
::lz::obscured left lateral costophrenic angle.
::bz::obscured bilateral costophrenic angles.
::qr::right pleural effusion.
::ql::left pleural effusion.
::qb::bilateral pleural effusion.
::qbl::bilateral pleural effusion, more on the left side.
::qbr::bilateral pleural effusion, more on the right side.
:*:rd1::radiopaque densities
::rd::radiopaque density
::xz::
quicksendFunc("xz", "degenerative change of the spine. suggest clinical correlation.")
return
::xxz::
quicksendFunc("xxz", "degenerative change of the spine with compression fracture. suggest clinical correlation. ")
return


::mlo::mass-like opacity

::pcl::previous fracture at left clavicle.
::pcr::previous fracture at right clavicle.
::pcb::previous fracture at bilateral clavicles.


::ap::Chest AP shows
::pa::Chest PA shows
;~ ::ch::Chest PA/AP shows
::cl::Chest lateral view shows
::c0::
send Chest PA/AP shows normal heart size and no obvious pulmonary nodular or mass lesion.
gosub checkReport
send {F3}
return
::cl0::Chest lateral view shows no definite abnormality. Suggest correlation with chest PA.
::CLM::Chest lateral view shows cardiomegaly and no definite abnormal opacity. Suggest correlation with chest PA.
::l0::no obvious pulmonary nodular or mass lesion.
::C0EL::Chest PA shows normal heart size, no obvious pulmonary nodular or mass lesion and elevated left diaphragm.
::C0ER::Chest PA shows normal heart size, no obvious pulmonary nodular or mass lesion and elevated right diaphragm.
::C0OP::Chest PA shows normal heart size, no definite abnormal ung lesion and postoperative change of the mediastinum with placement of multiple sternal wires.
::C0TA::Chest PA shows normal heart size, no deifnite lung lesion and tortuous aorta.
::cm0::Chest PA shows cardiomegaly and no obvious pulmonary nodular or mass lesion.
;~ ::C1::Chest PA shows cardiomegaly, tortuous aorta and no definite abnormal lung opacity.
::C1CD::Chest AP shows cardiomegaly and bilateral diffuse consolidation.
::C1CP::Chest AP shows cardiomegaly and bilateral patchy consolidation.
::C2::Chest AP shows cardiomegaly and bilateral lung consolidation.
::CABG0::Chest PA shows normal heart size and postoperative change consistent with CABG with placement of multiple sternal wires and mediastinal clips.
::CABG::Chest PA shows cardiomegaly and postoperative change consistent with CABG with placement of multiple sternal wires and mediastinal clips.
::CHOL::Chest PA/AP shows postoperative change of the left lung.
::CHOR::Chest PA/AP shows postoperative change of the right lung.

;heart
::dex::dextrocardia
::cos::coronary stent
:*:cos1::coronary stents
::rc::retrocardiac
::tvi::status post transcatheter aortic valve implantation.
::nh::normal heart size.
::cmg::cardiomegaly.
::bh::borderline heart size.
::asd::s/p ASD occluder placement.
::cad::calcification of the coronary arteries.
::rhb::right heart border
::lhb::left heart border
::olh::obscured left heart border
::orh::obscured right heart border
::upx::uplifted cardiac apex
::tv::s/p TAVI.
::as::s/p aortic stenting.

;mediastinum
:*:esre::status post esophagectomy and reconstruction.
::rss::retrosternal space
::cln::mottled calcified nodule(s), probable of calcified lymph node(s).
::ak::calcification of the aortic knob.
::me::mediastinum
:*:me1::mediastinal
::msw::metallic sternal wires.
::mw::mediastinum widening.
::mvp::status post cardiac valve replacement with sternal wiring.
::ta::tortuous aorta.
::tac::tortuous aorta with calcification.
::tdl::deviation of the trachea to the left side.
::tdr::deviation of the trachea to the right side.

;lung
::COPD::hyperinflation and increased volume of both lungs and flattening of diaphragms.

::rl::right lung
::ll::left lung
::bl::bilateral lungs
::rh::right hemithorax
::lh::left hemithorax

::bbl::bilateral basal lung fields
::bal::bilateral apical lung fields
::bml::bilateral middle lung fields
::bll::bilateral lower lung fields
::bul::bilateral upper lung fields
::ral::right apical lung field
::rul::right upper lung field
::rml::right middle lung field
::rll::right lower lung field
::lal::left apical lung field
::lul::left upper lung field
::lml::left middle lung field
::lll::left lower lung field
::lf::lung field
:*:lf1::lung fields
::lpr::left perihilar region
::rpr::right perihilar region
::bpr::bilateral perihilar regions



::co::consolidation
::blc::bilateral lung consolidation
::rlc::right lung consolidation
::llc::left lung consolidation
::bbc::bilateral basal lung consolidation
::bbcl::bilateral basal lung consolidation, more on the left side.
::bbcr::bilateral basal lung consolidation, more on the right side.
::lbc::left basal lung consolidation
::rbc::right basal lung consolidation
::dbc::diffuse bilateral lung consolidation
::blo::bilateral lung opacities.
::bln::bilateral lung nodular opacities.
::rlo::right lung opacities.
::llo::left lung opacities.

::reo::reticular opacities
::dho::diffuse hazy opacities
::ho::hazy opacities at
:*:ho1::hazy opacity
::iho::ill-defined hazy opacities at
:*:iho1::ill-defined hazy opacity
::po::patchy opacities at
:*:po1::patchy opacity
::ihd::increased hazy densities at
::ib::increased hazy densities at bilateral lungs
::il::increased hazy densities at left lung
::ir::increased hazy densities at right lung

::drno::diffuse bilateral reticulonodular lung opacities.
::bllv::bilateral low lung volume.
::dlc::decreased lung capacity
::dllc::decreased left lung capacity
::drlc::decreased right lung capacity
::bn::bilateral lung nodules.
::brs::bronchiectasis
::abg::air bronchogram

::igo::ill-defined ground-glass opacities

::fc::fibrotic change
::fca::fibrocalcified change
::fcb::fibrocalcified change of both upper lung fields.
::fcl::fibrocalcified change of the left upper lung fields.
::fcr::fibrocalcified change of the right upper lung fields.

::idf::ill-defined perihilar infiltration.
::ii::increased interstitial infiltration
::iil::increased interstitial infiltration in left lung.
::iir::increased interstitial infiltration in right lung.
::ipi::increased bilateral perihilar infiltration.
::ibf::increased bilateral basal lung infiltration.
::ih::increased hazy density at
::hd::hazy density

::ate::atelectasis
::sa::subsegmental atelectasis
::ssl::subsegmental atelectasis at left lower lung field.
::ssr::subsegmental atelectasis at right lower lung field.
::ssb::subsegmental atelectasis at bilateral lower lung fields.
::lia::linear atelectasis
::plh::prominent left hilar shadow
::prh::prominent right hilar shadow
::pbh::prominent bilateral hilar shadow

::pbc::peribronchial cuffing
::pbt::peribronchial thickening at
::peri::increased bilateral peribronchial cuffing and infiltration.

::emp::emphysematous change of both lungs.

::lhm::left hilar mass
::rhm::right hilar mass
::nd::nodular opacity
:*:nd1::nodular opacities
::lme::multiple bilateral lung nodules, consistent with metastases.

::pbl::prominent bilateral lung markings

::lkb::some Kerley's B lines at left lower lung field
::rkb::some Kerley's B lines at right lower lung field
::bkb::some Kerley's B lines at bilateral lower lung fields

::ioc::ill-defined opacities and consolidation at bilateral lungs
::io::ill-defined opacities
::iob::ill-defined opacities at bilateral lungs
::iol::ill-defined opacities at left lung
::ior::ill-defined opacities at right lung

::LH::increased pulmonary infiltration at bil peribronchial parahilar region; bronchitis is compatible.
::LHC::left ill-defined perihilar infiltration and consolidation.
::LHGGO::ill-defined ground-glass opacities at the left perihilar region with obscured bronchovascular bundle and hilum.
::LHH::prominent increased bilateral pulmonary infiltrations at peribronchial parahilar regions; bronchopneumonia is compatible.
::RHC::left ill-defined perihilar infiltration and consolidation.
::RHGGO::ill-defined ground-glass opacities at the right perihilar region with obscured bronchovascular bundle and hilum.
::RHH::prominent increased bilateral pulmonary infiltrations at peribronchial parahilar regions; bronchopneumonia is compatible.

::PWBI::posterior wall of the bronchus intermedius

;pleura
::pq::pleural plaque
:*:pq1::pleural plaques
::lpq::left calcified pleural plaque
:*:lpq1::left calcified pleural plaques
::rpq::right calcified pleural plaque
:*:rpq1::right calcified pleural plaques
::bpq::bilateral calcified pleural plaque
:*:bpq1::bilateral calcified pleural plaques
::obr::obscured right lateral costophrenic angle.
::obl::obscured left lateral costophrenic angle.
::obb::obscured bilateral costophrenic angles.
::lcp::left lateral costophrenic angle
::rcp::right lateral costophrenic angle
::bcp::bilateral costophrenic angle
::rpl::right pleural effusion
::lpl::left pleural effusion
::bpl::bilateral pleural effusion
::pl::pleural effusion
::ptx::pneumothorax
::hnx::hydropneumothorax
::pk::apical pleural thickening.
::rpk::right apical pleural thickening.
::lpk::left apical pleural thickening.
::bpk::bilateral apical pleural thickening.
::cfa::costophrenic angle
:*:cfa1::costophrenic angles

;diaphragm
:*:cfa2::cardiophrenic angle
::er::elevated right hemidiaphragm.
::el::elevated left hemidiaphragm.
::err::elevated right hemidiaphragm or right pleural effusion.
::ell::elevated left hemidiaphragm or left pleural effusion.
::rhd::right hemidiaphragm
::lhd::left hemidiaphragm
::bhd::bilateral hemidiaphragm
::hdp::hemidiaphragm


::rcw::right chest wall
::lcw::left chest wall


;breast
::lma::absence of left breast shadow, compatible with previous mastectomy.
::rma::absence of right breast shadow, compatible with previous mastectomy.
::bma::absence of bilateral breast shadow, compatible with previous mastectomy.
::abs::asymmetric breast shadow.
::br::breast

;abdomen
;~ ::gs::radiopaque density over RUQ of abdomen, suggestive of gallbladder stone.
::cab::post-operative change in the abdomen.
::cpe::post-operative change in the pelvis.
::crq::post-operative change with clips at RUQ abdomen.
::clq::post-operative change with clips at LUQ abdomen.
::rq::RUQ abdomen.
::lq::LUQ abdomen.
::uq::upper abdomen.

;tubes,lines,devices
::po::placement of
:*:3t,::placement of an endotracheal tube, a nasoenteric tube, a central venous line,
:*:2t,::placement of an endotracheal tube, a nasoenteric tube,
:*:3tr,::placement of a tracheostomy tube, a nasoenteric tube, a central venous line,
:*:2tr,::placement of a tracheostomy tube, a nasoenteric tube,
::3t::placement of an endotracheal tube, a nasoenteric tube, and a central venous line.
::2t::placement of an endotracheal tube, a nasoenteric tube.
::3tr::placement of a tracheostomy tube, a nasoenteric tube, and a central venous line.
::2tr::placement of a tracheostomy tube, a nasoenteric tube.
:*:cpm,::placement of a cardiovascular implantable electronic device,
::cpm::placement of a cardiovascular implantable electronic device.
:*:tpm,::placement of a temporary pacemaker,
::tpm::placement of a temporary pacemaker.
:*:cvcet,::placement of a central venous catheter, an endotracheal tube,
:*:cvcng,::placement of a nasoenteric tube, a central venous line,
::cvcet::placement of a central venous catheter and an endotracheal tube.
::cvcng::placement of a nasoenteric tube and a central venous line.
::ecmo::placement of large bore vascular cannula, consistent with ECMO.
:*:et,::placement of an endotracheal tube,
:*:etcvc,::placement of an endotracheal tube, a central venous catheter,
:*:etng,::placement of an endotracheal tube, a NG tube,
::et::placement of an endotracheal tube.
::etcvc::placement of an endotracheal tube and a central venous catheter.
::etng::placement of an endotracheal tube and a NG tube.
:*:lcvc,::placement of a left central venous catheter,
::lcvc::placement of a left central venous catheter.
:*:rcvc,::placement of a right central venous catheter,
::rcvc::placement of a right central venous catheter.
:*:lpo,::placement of a left implantable venous access port,
::lpo::placement of a left implantable venous access port.
;~ :*:lsv,::placement of a left subclavian venous catheter,
;~ ::lsv::placement of a left subclavian venous catheter.
:*:rpo,::placement of a right implantable venous access port,
::rpo::placement of a right implantable venous access port.
;~ :*:rsv,::placement of a right subclavian venous catheter,
;~ ::rsv::placement of a right subclavian venous catheter.
:*:ngcvc,::placement of a nasoenteric tube, a central venous line,
::ngcvc::placement of a nasoenteric tube and a central venous line.
::pic::status post pigtail drainage catheter insertion.
:*:dl,::placement of a double lumen catheter,
::dl::placement of a double lumen catheter.
::sgr::placement of a Swan-Ganz catheter with tip in the right pulmonary artery.
::sgl::placement of a Swan-Ganz catheter with tip in the left pulmonary artery.
:*:sgr,::placement of a Swan-Ganz catheter with tip in the right pulmonary artery,
:*:sgl,::placement of a Swan-Ganz catheter with tip in the left pulmonary artery,
:*:trcvc,::placement of a tracheostomy tube, a central venous catheter,
:*:trng,::placement of tracheostomy tube, a nasoenteric tube,
::trcvc::placement of a tracheostomy tube and a central venous catheter.
::trng::placement of tracheostomy tube and a nasoenteric tube.
::ng::placement of a nasoenteric tube.

::ngt::a nasoenteric tube
::cvc::a central venous catheter
::ett::an endotracheal tube
::tra::a tracheostomy tube
::pmr::cardiovascular implantable electronic device
::bct::bilateral chest tubes
::bjv::bilateral jugular venous catheters
::lct::a left chest tube
:*:lct1::left chest tubes
::rct::a right chest tube
:*:rct1::right chest tubes
::por::a implantable venous access port
;~ ::scv::a subclavian venous catheter
::pig::a pigtail catheter
::dlu::a double lumen catheter
::sg::a Swan-Ganz catheter

::esop::postoperative change with esophagectomy and reconstruction.
::lor::postoperative changes with surgical materials at mediastinum, right hilum and
::lol::postoperative changes with surgical materials at mediastinum, left hilum and
::lob::postoperative changes with surgical materials at mediastinum, bilateral hila and
::opl::postoperative changes of lung.

::OLL::postoperative change of the left lung with placement of clips and suture at the left hilum and mediastinum.
::OLU::postoperative change of the left upper abdomen with placement of clips.
::ORL::postoperative change of the right lung with placement of clips and suture at the right hilum and mediastinum.
::ORU::postoperative change of the right upper abdomen with placement of clips.


;soft tissue
:*:ax0::bilateral small axillary lymph nodes.
::nip::small nodular shadows at bilateral lower lung fields, suspicious of nipple shadows.
::lnip::small nodular shadow at left lower lung field, suspicious of nipple shadow.
::rnip::small nodular shadow at right lower lung field, suspicious of nipple shadow.
::se::subcutaneous emphysema at
::ser::subcutaneous emphysema at right chest wall.
::sel::subcutaneous emphysema at left chest wall.
::seb::subcutaneous emphysema at bilateral chest wall.

::pflc::previous fracture at left rib(s) and left clavicle.
::pfrc::previous fracture at right rib(s) and right clavicle.


;name
;~ ::LY::
;~ send (YCH/Dr.A){f1}{f5}
;~ return
;~ ::LJ::
;~ send (YCH/Dr.B){f1}{f5}
;~ return
;~ ::LW::
;~ send (YCH/Dr.C){f1}{f5}
;~ return
;~ ::LC::
;~ send (YCH/Dr.D){f1}{f5}
;~ return
;~ ::LH::
;~ send (YCH/Dr.E){f1}{f5}
;~ return
;~ ::LL::
;~ send (YCH/Dr.H){f1}{f5}
;~ return

:*:crup::narrowing of subglottic airway.

;-------------------------ABD
::abd::Standing abdominal film shows
::ab0::Standing abdominal film shows no definite abnormal bowel dilatation and normal bowel gas pattern.
:*:abd1::dilated bowel loops with air fluid level consistent with ileus.

;~ ::kb::KUB shows
:*:k0::normal bowel gas, no definite abnormal opacity, no definite abnormal bone change.
::kl::normal bowel gas, no definite abnormal opacity and degenerative change of the L spine.
::kg::decreased bowel gas
::kp::prominent bowel gas
::kt::prominent bowel gas
::ki::dilated bowel loops with air-fluid levels
::ks::stool impaction and no definite bowel dilatation.
::ekc::Non-specific bowel gas distribution is noted. No evidence of focal bone lesions is noted. Suggest correlation with clinical manifestations.
::eka::Non-specific bowel gas distribution is noted. No evidence of focal bone lesions is noted. Bilateral psoas shadows are clear. No definite radiopaque density is noted in the urinary collecting system. Suggest correlation with clinical manifestations.
::nb::non-specific bowel gas.
:*:nbzz::
quicksendFunc("nbz", "non-specific bowel gas. suggest clinical correlation.")
return
::nbz::
quicksendFunc("nbz", "non-specific bowel gas. suggest clinical correlation.")
return
::nbx::non-specific bowel gas. degenerative change of the spine.
::nbxu::urolithiasis or phlebolith in pelvic cavity.  non-specific bowel gas. degenerative change of the spine.
:*:nbxz::
quicksendFunc("nbxz", "non-specific bowel gas. degenerative change of the spine. suggest clinical correlation.")
return
:*:nbxxz::
quicksendFunc("nbxxz", "non-specific bowel gas. degenerative change of the spine with compression fracture. suggest clinical correlation.")
return
:*:nbxuz::
quicksendFunc("nbxuz", "urolithiasis or phlebolith in pelvic cavity. non-specific bowel gas. degenerative change of the spine. suggest clinical correlation.")
return
:*:nbxxu::
quicksendFunc("nbxxu", "urolithiasis or phlebolith in pelvic cavity. non-specific bowel gas. degenerative change of the spine with compression fracture. suggest clinical correlation.")
return


::NFA::no evidence of subphrenic free air.
:*:fr0::no evidence of intraabdominal free air.
::sfa::subphrenic free air

::hmg::increased liver span with blunting of the hepatic angle, suggestive of hepatomegaly.
::tae::post-TAE change with lipiodol retention in the liver.

::smg::enlarged splenic shadow, suggestive of splenomegaly.

::bg::bowel gas


::lrs::radiopaque density over left renal shadow represent renal stone, suggestive of renal stone.
::rrs::radiopaque density over right renal shadow represent renal stone, suggestive of renal stone.
:*:rs/::radiopaque density over bilateral renal shadow represent renal stone, suggestive of renal stone.
::pnl::status post left PCN catheter insertion.
::pnr::status post right PCN catheter insertion.
::pnb::status post bilateral PCN catheter insertion.
::djl::status post left double-J catheter insertion.
::djr::status post right double-J catheter insertion.
::djb::status post bilateral double-J catheter insertion.
::pjl::status post left PCN and DBJ insertion.
::pjr::status post right PCN and DBJ insertion.
::pjb::status post bilateral PCN and DBJ insertion.

::lus::opaque density over paraspinal region, probably left ureter stone.
::rus::opaque density over paraspinal region, probably right ureter stone.

:*:pr0::bilateral clear psoas and renal shadows.
::KPS::clear bilateral psoas shadows.
::KPR::obscured right psoas shadow.
::KPL::obscured left psoas shadow.
::KPB::obscured bilateral psoas shadows.
::UL::urolithiasis
::ull::urolithiasis, left.
::ulr::urolithiasis, right.
::krs::clear bilateral renal shadows.
::krr::obscured right renal shadow.
::krl::obscured left renal shadow.
::krb::obscured bilateral renal shadow.


::pbg::relative paucity of the bowel gas.
:*:ile0::dilated bowel loops, suspicious of ileus.
::ile::increased bowel gas and fluid retention are noted in the abdomen, compatible with ileus.
:*:ile2::markedly increased bowel gas is noted in the abdomen, compatible with prominent ileus.
:*:ile1::slightly increased bowel gas is noted in the abdomen, compatible with mild ileus.
::mga::much gas collection in the bowel loops at
::mgc::much gas collection in the bowel loops.
::mgf::much gas and fecal material collection in the bowel loops.
:*:bg0::unremarkable bowel gas pattern.
:*:bg1::prominent bowel gas.

::iud::IUD is noted superimposed in the pelvic cavity.
::cpr::scattered opaque density at lower pelvic cavity, suggestive of prostatic calcification.

::uph::urolithiasis or phlebolith in pelvic cavity.
:*:uphr::urolithiasis or phlebolith in right pelvic cavity.
:*:uphl::urolithiasis or phlebolith in left pelvic cavity.
::ph::pelvic phlebolith(s).
::cfb::mottled calcified nodule in pelvic cavity, calcified fibroid is suspected.
::ub::urinary bladder
::udc::double contour of the urinary bladder base is noted.
::uu::smooth concaved cephalic contour of the urinary bladder, compatible with uterus indentation.

::td::status post drainage tube(s) placement.
::vps::status post ventriculo-peritoneal (VP) shunt tube placement.


::xcm::extracorporal material

;------------------------spine
::adh::prominent soft tissue shadow at the posterior nasophryngx, compatible with adenoid hypertrophy.
::spm::multiple sclerotic foci of the spine, compatible with bone metastases.
::cf::compression fracture at
::cfx::compression fracture of spine
::ops::postoperative changes of spine

;~ :*:cs1::cervical spondylosis with disc space narrowing and posterior spur formation at the
;~ :*:cs1m::cervical spondylosis with disc space narrowing and posterior spur formation at multiple levels.
;~ :*:cs2::cervical spondylosis with disc space narrowing, intradiscal vacuum phenomenon and posterior spur formation at the
;~ :*:cs2m::cervical spondylosis with disc space narrowing, intradiscal vacuum phenomena and posterior spur formation at multiple levels.

::dt::degenerative change of the thoracic spine.
::dtl::degenerative change of the thoracolumbar spine.
::dtlc::degenerative change of the thoracolumbar with compression fracture.


;------------------------ortho
::hava::increased first metatarsophalangeal angle and 1st/2nd intermetatarsal angle.
::ons::osteonecrosis

::hu::humerus

::clv::clavicle
:*:clv1::clavicles


::ACR::acromion
::ACO::accessory ossicle
:*:ACO1::accessory ossicles
::ASS::multilevel syndesmophytoses, ligamentous ossifications, bamboo-appearance of spine, and ankylosis of bilateral sacroiliac joints, compatible with ankylosing spondylitis
::AVN::avascular necrosis
::AVN2::subchondral geographic lesion with serpigeous sclerotic margin
::AVN3::subchondral geographic lesion with serpigeous sclerotic margin and subchondral collapse
::B1::epiphysis
::B12::epimetaphysis
::B2::metaphysis
::B23::diametaphysis
::B3::diaphysis
::BB::non-aggressive bone lesion is likely
::BFG::femoral greater trochanter
::BFI::femoral intertrochanteric region
::BFIS::femoral inter- to subtrochanteric region
::BFL::femoral lesser trochanter
::BFS::femoral subtrochanteric region
::BHG::humeral greater tubercle
::BHL::humeral lesser tubercle
::BHN::humeral surgical neck
::BIP::biphalangism at the little toe
::BIP2::biphalangism at the little and 4th toes
::BIS::bone island(s) (enostosis)
::BTT::tibial tuberosity
::BUS::bursal-side
;~ ::CAV::pes cavus
::CAVV::increased calcaneal inclination angle (calcaneal pitch), suggestive of pes cavus
::COP::cord compression
::CID::cortical indistinctness
::CDHL::shallowing of acetabulum with superior lateral subluxation of the deformed femoral head and joint space narrowing and subchondral sclerosis, suggestive of congenital dysplasia of left hip joint.
::CDHR::shallowing of acetabulum with superior lateral subluxation of the deformed femoral head and joint space narrowing and subchondral sclerosis, suggestive of congenital dysplasia of right hip joint.
::CFF::wedge deformity and decreased height, suggestive of compression fracture, at
::CFH::compression fracture with decreased vertebral height at
;~ ::CFHH::decreased vertebral height(s), sugg. of compression fracture, at
::CFP::pathological compression fracture
::CFW::compression fracture with wedge deformity at
;~ ::CFWW::wedge deformity, sugg. of compression fracture, at
::CHC::chondrocalcinosis
::CPPD::CPPD (Calcium Pyrophosphate Dihydrate Deposition Disease)
::DA::degenerative arthroses
::DAC::degenerative arthrosis of the anterior atlantoaxial joint
::DAW::degenerative arthroses of the distal radioulnar, ulnocarpal and radiocarpal joints
::DBF::displaced bone fragment
:*:DBF1::displaced bone fragments
::DBP::distal bone part
:*:DBP1::distal bone parts
::DC::degenerative change
:*:DC1::degenerative changes
::DDD::degenerative disc disease
::DDH::developmental dysplasia of hip
::DDH1::shallowing of the acetabulum
::DDH2::mild lateral positioning of femoral head
::DDHB::shallowing of the acetabulum with relative lateral subluxated femoral head on both sides, suggesting developmental dysplasia of both hips
::DDHL::shallowing of the acetabulum with relative lateral subluxated femoral head on left side, suggesting developmental dysplasia of hip
::DDHR::shallowing of the acetabulum with relative lateral subluxated femoral head on right side, suggesting developmental dysplasia of hip
::DEF::deformity
::DEH::dehydrated disc
:*:DEH1::dehydrated discs
::DHB::degenerative arthroses of both hip joints
::DHL::degenerative arthroses of left hip joint
::DHR::degenerative arthroses of right hip joint
::DISH::flowing ossification of anterior longitudinal ligament at lower thoracic to upper lumbar spine, diffuse idiopathic skeletal hyperostosis (DISH) is suspected
::DISI::dorsal intercalated-segmental instability
::DLL::decreased lordosis of the lumbar spine
::DPAA::dorsalis pedis artery
::DS::degenerative change of spine
::DSD::degenerative spinal and disc disease
::DSI::degenerative arthroses of bilateral sacroiliac joints
::DSIH::degenerative arthroses of bilateral sacroiliac and hip joints
::DSIHL::degenerative arthroses of left sacroiliac and hip joints
::DSIHR::degenerative arthroses of right sacroiliac and hip joints
::DSIL::degenerative arthroses of left sacroiliac joint
::DSIR::degenerative arthroses of right sacroiliac joint
::DSSI::lumbar spondylosis and degenerative arthroses of bilateral sacroiliac joints
::DSSIH::lumbar spondylosis and degenerative arthroses of bilateral sacroiliac and hip joints
::DSS::degenerative change of spine and both shoulders
::EC::endplate change
::ECD::degenerative endplate change
::ECM::Modic type
::EH::edema/hyperemia
::EFS::increased suprapatellar effusion
::EFSB::effusion in the bilateral suprapatellar pouches
::EFSBB::effusion in the bilateral suprapatellar pouches and knee joint spaces
::EFSL::effusion in the left suprapatellar pouch
::EFSLL::effusion in the left suprapatellar pouch and knee joint space
::EFSR::effusion in the right suprapatellar pouch
::EFSRR::effusion in the right suprapatellar pouch and knee joint space
::ENT::enthesopathic change
::EXO::exostosis
::EXEC::except for degenerative endplate change
::F2::index (2nd) finger
::F3::middle (third) finger
::F4::ring (4th) finger
::F5::little (5th) finger
::FA::angulation of distal fragment
::FAA::anterior angulation of distal bone part
::FAD::dorsal angulation of distal bone part
::FAI::femoro-acetabular impingement
::FAL::lateral (valgus) angulation of distal bone part
::FAM::medial (varus) angulation of distal bone part
::FAP::posterior angulation of distal bone part
::FAV::volar angulation of distal bone part
::FCM::comminuted fracture
::FCAS::femoral condylar articular surface
::FCD::comminuted displaced fracture
::FCDI::comminuted displaced impacted fracture
::FCDIA::comminuted displaced intra-articular fracture
::FCDIIA::comminuted displaced intra-articular fracture
::FCI::comminuted impacted fracture
::FCIA::comminuted intraarticular fracture
::FCIIA::comminuted impacted intra-articular fracture
::FCLL::fibular collateral ligament
::FCP::complex fracture
::FD::displaced fracture
::FDA::anterior displacement of distal bone part
::FDD::dorsal displacement of distal bone part
::FDI::displaced impacted fracture
::FDIA::displaced intra-articular fracture
::FDIS::distraction of bone parts
::FDIIA::displaced impacted intra-articular fracture
::FDL::lateral displacement of distal bone part
::FDM::medial displacement of distal bone part
::FDP::posterior displacement of distal bone part
::FDV::volar displacement of distal bone part
::FE::neural foraminal encroachment
::FEL::encroachment to the left neural foramen
::FER::encroachment to the right neural foramen
::FH::healed fracture
::FHH::healing fracture
::FHO::healed oblique fracture
::FHS::healed spiral fracture
::FHT::healed transverse fracture
::FI::impacted fracture
::FIA::intra-articular fracture
::FIIA::impacted intraarticular fracture
::FJA::facet joint arthroses
::FJAL::facet joint arthroses at lower levels
::FN::neural foraminal stenosis
::FO::previous oblique fracture
::FOVER::overriding of fracture ends
::FP::pathological fracture
::FR::rotation of distal fragment
::FS::previous spiral fracture
::FT::previous transverse fracture
::HLF::hypertrophic ligamenta flava
::HOW::however, small osseous lesion or occlut fracture may not be detected on plain radiograph
::HV::hallux valgus
::IXT::intraarticular extention to
::IBFU::interbody fusion
::IFAR::inflammatory arthritis
::IFT::infraspinatus tendon
::IMP::shoulder impingement
::IMPL::lateral downsloping and lowlying of left acromion with subacromial spur formation and narrowed subacromial space, suggestive of shoulder impingment.
::IMPR::lateral downsloping and lowlying of right acromion with subacromial spur formation and narrowed subacromial space, suggestive of shoulder impingment.
::TSI::adjacent thecal sac indentation
::INJ::multiple calcified injection granulomas over bilateral buttocks
::ISB::intrasubstance
::ISTT::infraspinatus tendon
::JAC::acromioclavicular joint
:*:JAC1::acromioclavicular joints
::JCA::patellofemoral joint compartment
:*:JCA1::patellofemoral joint compartments
::JCAA::all joint compartment
:*:JCAA1::all joint compartments
::JCAL::patellofemoral and lateral joint comparment
:*:JCAL1::patellofemoral and lateral joint comparments
::JCAM::patellofemoral and medial joint compartment
:*:JCAM1::patellofemoral and medial joint compartments
::JCB::all joint compartments of both knee joints

::JCC::calcaneocuboid joint
:*:JCC1::calcaneocuboid joints
::JCL::lateral joint compartment
:*:JCL1::lateral joint compartments
::JCM::medial joint compartment
:*:JCM1::medial joint compartments
::JCMC::carpometacarpal joint
:*:JCMC1::carpometacarpal joints
::JCML::medial and lateral joint compartment
:*:JCML1::medial and lateral joint compartments
::JD::junction of middle and distal thirds of
::JDIP::distal interphalangeal joint
:*:JDIP1::distal interphalangeal joints
::JFT::femorotibial joint
:*:JFT1::femorotibial joints
::JGH::glenohumeral joint
:*:JGH1::glenohumeral joints
::JHR::humeroradial joint
:*:JHR1::humeroradial joints
::JHU::humeroulnar joint
:*:JHU1::humeroulnar joints
::JIP::interphalangeal joint
:*:JIP1::interphalangeal joints
::JIPF::interphalangeal joint(s) of thumb(s) and some distal interphalangeal joint(s) of finger(s)
::JIPFF::interphalangeal joint(s) of thumb(s) and some distal interphalangeal and proximal interphalangeal joint(s) of finger(s)
::JIPT::interphalangeal joint(s) of big toe(s) and some distal interphalangeal joint(s) of toe(s)
::JIPTT::interphalangeal joint(s) of big toe(s) and some distal interphalangeal and proximal interphalangeal joint(s) of toe(s)
::JK::knee joint
:*:JK1::knee joints
::JKB::both knee joint
:*:JKB1::both knee joints
::JKL::left knee joint
::JKR::right knee joint
::JMC::mid-carpal joint
:*:JMC1::mid-carpal joints
::JMP::metacarpophalangeal joint
:*:JMP1::metacarpophalangeal joints
::JMT::metatarsophalangeal joint
:*:JMT1::metatarsophalangeal joints
::JJ::
quicksendFunc("JJ", "no obvious bony fracture. no evidence of joint subluxation or dislocation. suggest clinical correlation. (Small bone fracture or lesion may not be detected by the plain radiography.) ")
return
:*:fd0::
quicksendFunc("fd0", "no obvious displaced fracture. (Small bone fracture may not be detected by images.) ")
return
::JO::no obvious bony fracture or destructive lesion; no evidence of joint subluxation or dislocation; suggest clinical correlation.
::JOO::no obvious bony fracture or destructive lesion; no evidence of joint subluxation or dislocation; however, small bone fracture or lesion may not be detected by the plain radiography.
::JP::junction of proximal and middle thirds of
::JPF::patellofemoral joint
:*:JPF1::patellofemoral joints
::JPIP::proximal interphalangeal joint
:*:JPIP1::proximal interphalangeal joints
::JRC::radiocarpal joint
:*:JRC1::radiocarpal joints
::JRU::radioulnar joint
:*:JRU1::radioulnar joints
::JSI::sacroiliac joint
:*:JSI1::sacroiliac joints
::JST::subtalar joint
:*:JST1::subtalar joints
::JT::joint
:*:JT1::joints
::JTTS::trapzium-trapzoid-scaphoid joint
:*:JTTS1::trapzium-trapzoid-scaphoid joints
::JTM::temporomandibular joint
:*:JTM1::temporomandibular joints
::JTMT::tarsometatarsal joint
:*:JTMT1::tarsometatarsal joints
::JTN::talonavicular joint
:*:JTN1::talonavicular joints
::JTT::tibiotalar joint
:*:JTT1::tibiotalar joints
::JUC::ulnocarpal joint
:*:JUC1::ulnocarpal joints
::KSC::kyphoscoliosis
::KY::kyphosis
::LBD::loose body
::LBD1::loose bodies
::LCPD::Legg-Calve-Perthes disease
::LEX::lower extremities
::LLS::lower lumbar levels
;~ ::LRS::lateral recess stenosis
::MAM::medial malleolus
::leom::medial malleolus
::leol::lateral malleolus
::leop::posterior malleolus
;~ ::MAL::distal fibula lateral malleolus
::MCLL::medial collateral ligament
::MDD::degenerative change with dehydrated discs at multi-levels
::MF::multifocal
::mi3::middle third
::MLL::multilevel
::ML::multiple levels
::FBA::fine bony alignment
::NDH::fine disc hydration
::NF::no obvious bony fracture
::NDS::the disc spaces are acceptable
::NJS::the joint spaces are within normal limit
::NL::no evidence of joint subluxation or dislocation
::NSI::normal morphology of the bilateral sacroiliac joints
::NUV::negative ulnar variance
::OA::osteoarthritis
::OAA::osteoarthritic change
::OA1::minimal osteoarthritis
::OA12::minimal to mild osteoarthritis
::OA2::mild osteoarthritis
::OA23::mild to moderate osteoarthritis
::OA3::moderate osteoarthritis
::OA34::moderate to severe osteoarthritis
::OA4::severe osteoarthritis
::OA11::minimal osteoarthritis with tiny marginal osteophyte at
::OA122::mild osteoarthritis with tiny or small marginal osteophyte at
::OA22::mild osteoarthritis with small marginal osteophyte at
::OA233::mild to moderate osteoarthritis with marginal osteophyte and mild joint space narrowing at
::OA33::moderate osteoarthritis with marginal osteophyte and joint space narrowing at
::OA344::moderate to severe osteoarthritis with marginal osteophyte, joint space narrowing, and mild uneven articular surface at
::OAA4::severe osteoarthritis with large marginal osteophyte, joint space narrowing, and uneven articular surface at
::OAANK::osteoarthritis at the tibiotalar joint, subtalar joint, and midtarsal joints
::OAF1::osteoarthritis at interphalangeal joint(s) of thumb(s) and some distal interphalangeal joint(s) of finger(s)
::OAF2::osteoarthritis at interphalangeal joint(s) of thumb(s) and some distal interphalangeal and proximal interphalangeal joint(s) of finger(s)
::OAT1::osteoarthritis at interphalangeal joint(s) of big toe(s) and some distal interphalangeal joint(s) of toe(s)
::OAT2::osteoarthritis at interphalangeal joint(s) of big toe(s) and some distal interphalangeal and proximal interphalangeal joint(s) of toe(s)
::OAB::osteoarthritic change at all joint compartments of both knee joints
::OABA::osteoarthritic change at all joint compartments, more at patellofemoral joint compartments, of both knee joints
::OAH::osteoarthritic change of both hip joints
::OAHR::osteoarthritic change of right hip joint
::OAHL::osteoarthritic change of left hip joint
::OAL::osteoarthritic change at all joint compartments of left knee joint
::OALA::osteoarthritic change at all joint compartments, more at patellofemoral joint compartment, of left knee joint
::OALB::the joint spaces are more narrowed at both lateral joint compartments and cause valgus deformity of both knee joints
::OALL::the joint space is more narrowed at lateral joint compartment and causes valgus deformity of left knee joint
::OALR::the joint space is more narrowed at lateral joint compartment and causes valgus deformity of right knee joint
::OAMB::the joint spaces are more narrowed at both medial joint compartments and cause varus deformity of both knee joints
::OAML::the joint space is more narrowed at medial joint compartment and causes varus deformity of left knee joint
::OAMR::the joint space is more narrowed at medial joint compartment and causes varus deformity of right knee joint
::oam::osteoarthritic change of knee joints with narrowed medial joint compartment
:*:oam1::osteoarthritic change of knee joints with narrowed medial joint compartments
::OAP::osteoarthritic change at the patellofemoral joint
::OAR::osteoarthritic change at all joint compartments of right knee joint
::OARA::osteoarthritic change at all joint compartments, more at patellofemoral joint compartment, of right knee joint
::OBG::bone grafting
::OBI::external immobilization
::OBP::status post blade plate and screw fixation
::OC::external cast or splint application
::OC1::status post external cast or splint application; the detail of bones is obliterated by artifacts of the cast or splint
::OCD::osteochondral
::OCDD::osteochondrosis
::OCI::patchy sclerotic change over lower poles of bilateral sacroiliac joints, suggesting osteitis condensans ilii
::OCP::status post calcaneal lengthening and 1st toe interphalangeal fusion
::ODDH1::acetabuloplasty
::ODDH2::varus osteotomy
::ODP::status post dynamic compression plate and screw fixation
::ODS::status post dynamic compression screw fixation
::OE::status post external fixator application
::OEB::status post external bandage with radiopaque artifacts and some detail of bones is obliterated
::OEI::status post external immobilization
::OFC::status post calcaneal lengthening
::OFN::posterior tibialis tendon transfer
::OFS::status post subtalar arthroereisis
::OFT::talonavicular stapling
::OHB::status post arthroplasty at both hip joints
::OHHB::status post hemiarthroplasty at both hip joints
::OHHL::status post hemiarthroplasty at left hip joint
::OHHR::status post hemiarthroplasty at right hip joint
::OHL::status post arthroplasty at left hip joint
::OHR::status post arthroplasty at right hip joint
::OI::status post internal (metallic) fixation
::OIB::interbody fusion at
::OIF::status post interbody fusion at
::OIN::status post intramedullary nail and interlocking screw fixation
::OIP::status post metallic pin fixation
::OIR::status post intramedullary rod insertion
::OKB::status post total knee arthroplasty at both knee joints
::OKBB::status post total knee arthroplasty at both knee joints with fine alignment and soft tissue swelling at anterior aspects; suggest clinical correlation.
::OKL::status post total knee arthroplasty at left knee joint
::OKLL::status post total knee arthroplasty at left knee joint with fine alignment and soft tissue swelling at anterior aspect; suggest clinical correlation.
::OKR::status post total knee arthroplasty at right knee joint
::OKRR::status post total knee arthroplasty at right knee joint with fine alignment and soft tissue swelling at anterior aspect; suggest clinical correlation.
::OKSL::status post limb salvage at left distal femur with long stem knee arthroplasty at left knee joint
::OKSR::status post limb salvage at left distal femur with long stem knee arthroplasty at right knee joint
::OKW::status post K-wire fixation
::OMP::status post metallic plate and screw fixation
::OMS::status post metallic screw fixation
::OMW::metallic wire fixation
::ONN::intravertebral vacuum, suggesting osteonecrosis
::ONS::decreased height with suspect intravertebral vacuum, suggesting osteonecrosis, at
::OPV::osteopenic change of visible bones
::OPCL::status post posterior cruciate ligament reconstruction with presence of tibial and femoral tunnels; fine alignment of the femorotibial joint and postOP change around the knee joint; suggest follow up study.
::OPD::osteopenic change at distal aspects of fracture site, suggestive of disuse osteopenia
::OPLL::ossification of posterior longitudinal ligament (OPLL)
::OPM::marked osteopenic change of visible bones
::OPP::periarticular osteopenia
::OPV1::suspected osteopenic change of visible bones
::ORE::removal of the implant
::ORP::status post reconstruction plate and screw fixation
::OSAL::status post soft tissue anchor fixation over the left humeral greater tuberosity
::OSAR::status post soft tissue anchor fixation over the right humeral greater tuberosity
::OSB::osteoblastic lesion
:*:OSB1::osteoblastic lesions
::OSG::irregularity and fragmentation at the tibial tuberosity with adjacent soft tissue swelling, Osgood-Schlatter disease is considered first
::OSL::status post posterior decompression and posterior instrumentation at
::OSLL::status post laminectomy and posterior decompression, lateral bony fusion, transpedicle screw insertion and posterior instrumentation at
::OSLLL::status post laminectomy and posterior decompression, lateral bony fusion, transpedicle screw insertion and posterior instrumentation, and interbody fusion at
::OSP::external splinting
::OTB::status post intramedullary pin and tension band wire fixation
::P1::distal phalanx bone
:*:P11::distal phalanx bones
::P2::middle phalanx bone
:*:P21::middle phalanx bones
::P3::proximal phalanx bone
:*:P31::proximal phalanx bones
::P4::metacarpal bone
:*:P41::metacarpal bones
::P5::metatarsal bone
:*:P51::metatarsal bones
::P11::distal phalangeal
::P22::middle phalangeal
::P33::proximal phalangeal
::P44::metacarpal
::P55::metatarsal
::PAOD::peripheral arterial occlusive disease
::PARS::pars interarticularis
::PCLL::posterior cruciate ligament
::PD::posterior decompression
::PERA::periprosthetic radiolucency
::PERI1::osteolysis
::PERI2::osteolysis or prosthetic loosening
::PERI3::prosthetic loosening
::PERIF::periprosthetic fracture
::pla::pes planus
::plaa::small calcaneal inclination angle (calcaneal pitch), suggestive of pes planus
::PF::previous fracture
::PFF::previous fracture or osteotomy
::PI::posterior instrumentation/fixation
::PLF::posterior lateral fusion
::sac0::the sacrum is obliterated by the bowel gas
::PTAA::posterior tibial artery
::PUV::positive ulnar variance
::R3MT::right 3rd metatarsal
::R4MT::right 4th metatarsal
::R5MT::right 5th metatarsal
::RA::rheumatoid arthritis
::ftr::full-thickness rupture
::ptr::partial-thickness rupture
::SAL::straightening alignment
::SACB::lumbar sacralization of L5 on both sides
::SACL::partial lumbar sacralization of L5 on left side
::SACR::partial lumbar sacralization of L5 on right side
::SASD::subacromion-subdeltoid bursa
;~ ::sbi::spina bifida
::SCANOL::left lower limb is measured about cm shorter than right one.
::SCANOR::right lower limb is measured about cm shorter than left one.
::SCANOO::there is no obvious length discrepancy of both lower limbs.
::SCOB::scoliosis with main (fixed) curvature at mid-thoracic spine and compensatory (correctable) curvature at the lumbar spine
::SCOL::scoliosis with convexity of the thoracic spine to left side
::SCOLR::scoliosis of spine with convexity of the thoracic spine to left side and convexity of the lumbar spine to right side
::SCOR::scoliosis with convexity of the thoracic spine to right side
::SCORL::scoliosis of spine with convexity of the thoracic spine to right side and convexity of the lumbar spine to left side
::SCTL::scoliosis of the thoracolumbar spine
::SD::decreased disc space and end-plate change
::SDS::decreased disc space and sclerotic end-plate change
::SEC::sclerotic endplate change
::SEQ::sequestrated disc
:*:SEQ1::sequestrated discs
::SFAA::superficial femoral artery
::SH0::the glenohumeral joint appear normal; no obvious fracture line; no evidence of joint subluxation or dislocation.
::SH1::lateral down-sloping
::SH2::subacromial spur
::SH3::inferior marginal spur
::SHD::lateral down-sloping of the acromion
::SHDL::lateral down-sloping and low-lying of the acromion
::SHL::low-lying
::SHN::subacromial space narrowing
::SHP::synovial herniation pit
:*:SHP1::synovial herniation pits
::SHS::subacromial spur formation
::SMN::Schmorl's node
::SONK::spontaneous osteonecrosis of the knee (SONK)
::SONKL::osteochondral defect with sclerotic margin at left medial femoral condylar articular surface, suggesting osteonecrosis.
::SONKR::osteochondral defect with sclerotic margin at right medial femoral condylar articular surface, suggesting osteonecrosis.
::SST::supraspinatus tendon
::SSTT::subscapularis tendon
::ST1::mild stenosis
::ST12::mild to moderate stenosis
::ST2::moderate stenosis
::ST23::moderate to severe stenosis
::ST3::severe stenosis
::ST4::nearly-total occlusion
::ST5::total occlusion
;~ ::ST::spinal stenosis
::STC::soft tissue calcification
:*:STC1::soft tissue calcifications
::cat::calcific tendinitis
::cabt::calcific bursitis or tendinosis
::STH::increased heterogeneous soft tissue density
::STI::increased soft tissue density
::STL::soft tissue lesion
:*:STL1::soft tissue lesions
::STOS::soft tissue ossification
:*:STOS1::soft tissue ossifications
::STSA::adjacent soft tissue swelling
::STSP::periarticular soft tissue swelling
::STT::soft tissue tumor
::SUBC::subchondral
::SUC::subcutaneous
::SUC1::subcutaneous swelling and fat stranding
::SUC2::subcutaneous swelling and edema
::T121::T12-L1
::T122::T12-L2
::T123::T12-L3
::T124::T12-L4
::T125::T12-L5
::T111::T11-L1
::T112::T11-L2
::T113::T11-L3
::T114::T11-L4
::T115::T11-L5
::T101::T10-L1
::T102::T10-L2
::T103::T10-L3
::T104::T10-L4
::T105::T10-L5
:*:T00::T1-2
::TE::traction enthesophyte formation at
::TECB::traction enthesophyte formation at bilateral calcaneal posterior processes
::TECL::traction enthesophyte formation at left calcaneal posterior process
::TECR::traction enthesophyte formation at right calcaneal posterior process
::TEHB::traction enthesopathy at bilateral humeral greater tuberosities
::TEHL::traction enthesopathy at left humeral greater tuberosity
::TEHR::traction enthesopathy at right humeral greater tuberosity
::TEPB::traction enthesophyte formation at bilateral patellar bases
::TEPL::traction enthesophyte formation at left patellar base
::TEPR::traction enthesophyte formation at right patellar base
::TIS::tibial intercondylar spine
::TLJ::thoracolumbar junction
::TLS::thoracolumbar spondylosis
:*:tlsk::thoracolumbar spondylosis. calcifications of aorta.
::TLS1::thoracolumbar spondylosis with marginal osteophyte formation
::TLSF::thoracolumbar spondylosis with marginal osteophyte formation and facet joint arthroses
::TLSS::thoracolumbar scoliosis and spondylosis
::TLSS1::thoracolumbar scoliosis and spondylosis with marginal osteophyte formation
::TEC::traction enthesopathic change
::TECH::traction enthesopathic change at the humeral greater tubercle
::TECC::subchondral cyst(s) at the humeral head which may relate to traction enthesopathic change.
::UC::callus formation
::UD::suggestive of delayed union
::UDN::radiolucent gap at fracture cleft, suggesting radiological delayed or non-union
::UAO::a small bony focus near the ulnar styloid process which is probably related to accessory ossicle or old fracture
::UOP::ulnar olecranon process
::USP::ulnar styloid process
::UUC::unilateral callus formation
::UW::well union of fracture cleft
::UWC::well union and callus formation
::VWC::vascular wall calcifications
::vld::valgus deformity
::vrd::varus deformity
;~ ::VP::status post vertebroplasty with bone cement in position
::WD::wedge deformity
::XC::subchondral cyst
:*:XC1::subchondral cysts
::XD::disc space narrowing
::XE::subchondral erosion
:*:XE1::subchondral erosions
::XEP::periarticular erosion
:*:XEP1::periarticular erosions
::XJ::joint space narrowing
::XJJ::joint space widening
::XJA::asymmetrical joint space narrowing
::XJL::localized joint space narrowing
::XJO::marginal spur formation and joint space narrowing at
::XJS::symmetrical joint space narrowing
::XO::marginal osteophyte
:*:XO1::marginal osteophytes
::XP::posterior spur
:*:XP1::posterior spurs
::XPP::disc space narrowing and posterior spur with potential spinal stenosis
::XR::subchondral radiolucencies
::XS::subchondral sclerosis
::XU::uneven articular surface
::ZJA::zygapophyseal joint arthrosis
::z0::remainder of the exam is unremarkable
::ZSA::subarticular zone


::CS::cervical spondylosis
::CS1::cervical spondylosis with marginal osteophyte formation
::CS2::cervical spondylosis with marginal osteophyte formation and facet joint arthroses
::CSL::cervical spondylosis with marginal osteophyte formation at lower levels
::CSM::mild cervical spondylosis with small marginal osteophyte formation
::CSP::fine alignment; no obvious fracture line; no abnormal retropharyngeal soft tissue;
::CSS::cervical scoliosis and spondylosis
::CSS::cervical scoliosis and spondylosis
::CSS1::cervical scoliosis and spondylosis with marginal osteophyte formation
::CSS2::cervical scoliosis and spondylosis with marginal osteophyte formation and facet joint arthroses
::CSSL::cervical scoliosis and spondylosis with marginal osteophyte formation at lower levels
::CSSM::cervical scoliosis and spondylosis with small marginal osteophyte formation
::LS::lumbar spondylosis
::lsk::lumbar spondylosis. calcifications of aorta.
::LS1::lumbar spondylosis with marginal osteophyte formation
::LS2::lumbar spondylosis with marginal osteophyte formation and facet joint arthroses
::LS3::lumbar spondylosis with marginal osteophyte formation at multiple levels and facet joint arthroses at lower levels
::LSL::lumbar spondylosis with marginal osteophyte formation at lower lumbar levels
::LSM::mild lumbar spondylosis with small marginal osteophyte formation
::LSS::lumbar scoliosis and spondylosis
::LSS1::lumbar scoliosis and spondylosis with marginal osteophyte formation
::LSS2::lumbar scoliosis and spondylosis with marginal osteophyte formation and facet joint arthroses
::LSSL::lumbar scoliosis and spondylosis with marginal osteophyte formation at lower lumbar levels
::LSSM::lumbar scoliosis and spondylosis with small marginal osteophyte formation
::LSK::lumbar kyphoscoliosis and spondylosis
::LSK1::lumbar kyphoscoliosis and spondylosis with marginal osteophyte formation
::LSK2::lumbar kyphoscoliosis and spondylosis with marginal osteophyte formation and facet joint arthroses
::LSKL::lumbar kyphoscoliosis and spondylosis with marginal osteophyte formation at lower lumbar levels
::LSKM::lumbar kyphoscoliosis and spondylosis with small marginal osteophyte formation
::LSTV::lumbosacral transitional vertebrae
::LSTVB::lumbosacral transitional vertebrae with pseudoarticulation on both sides
::LSTVR::lumbosacral transitional vertebrae with pseudoarticulation on right side
::LSTVL::lumbosacral transitional vertebrae with pseudoarticulation on left side

::b0::no definite abnormal bone change of this study.
::o0::no obvious fracture line is identified; no obvious destructive bone lesion; suggest clinical correlation.
::faf::relative flatten bony arcs of bilateral feet.
::tkr::status post total knee replacement
::pkr::status post partial knee replacement
::thr::status post total hip replacement

::fx::fracture

;~ ::OA::joint space narrowing with spurs formation, degenerative change is compatible.
;~ :*:OA1::minimal osteoarthritis with subtle or tiny marginal spur formation at the
;~ :*:OA2::mild osteoarthritis with small or tiny marginal spur formation at the
;~ :*:OA3::moderate osteoarthritis with uneven articular surfaces, subchondral sclerosis and marginal spur formation at the
;~ :*:OA4::advanced osteoarthritis with joint space narrowing, uneven articular surfaces, subchondral sclerosis and marginal spur formation at the

::ABN1::type I accessory navicular bone
::ABN2::type II accessory navicular bone

::AC1::type 1 acromion with flat acromial undersuface
::AC2::type 2 acromion with concave curved undersurface
::AC3::type 3 acromion with inferiorly directed beak or hook

::lhar::lipohemoarthrosis

;------------------------neuro
::cps::hazziness/fluid of the paranasal sinuses, sinusitis is compatible.
::sn::essential clear of the bilateral paranasal sinuses without definite bone change.
::cgi::faint cerebral gyral indentation on the skull bone.
::NSC::no abnormal prevertebral soft tissue swelling
::SKU::normal size and shape of sella turcica; no obvious fracture; no evidence of asymmetric soft tissue density;

newFilm2:
return
;~ aid:=getRisSheetNo(RisOpened()[2])
;~ if (aid=p_aid && p_aid:=aid)
	;~ return
;~ settimer,newFilm2,off
if !checksid(sid)
	sid:=login(loginId,loginPw)
checkRis(RisState)
;~ chartNo:=thisReport[personIdCol]?thisReport[personIdCol]:thisReport[chartNoCol],chartNo:=chartNo?chartNo:getRisChartNo(risHwnd:=RisState[2])
;~ RisReport2Yr:=isobject(thisReport[personIdCol+1])?thisReport[personIdCol+1]:parseRisReport2Yr(RisReport2Yr(sid,chartNo))
ExamItems:=parseRisExamItems(getRisExamItems(RisHwnd))
,risReports:=getRisReports(risHwnd)
if RegExMatch(ExamItem:=ExamItems[1,1],"is)Chest.*(AP|PA)") || chestLat:=!!regexmatch(ExamItem,"is)Chest.*Lateral") {
	boneKeywords:=["rib","fracture","bone","bony","\bsclero","lytic"]
	,lungKeyWords:=["(lung|pulmonary) (nodule|mass|tumor|lesion|metasta)"]
	,cancerKeywords:=["cancer","malignant","malignancy","lymphoma","leukemia","tumor"]

	,CXRind:=0,CTind:=0,keyWord:=""

	for k,v in RisReport2Yr {
		if regexmatch(priorExamItem:=v.1.1,"is)Chest.*(AP|PA)") && (++CXRind<11) {
			;~ v.accSelect(ComObj(3,3),0)
			;~ if (CXRind=1)
				;~ first:=v

			keyWord.=matchText(v.2,boneKeyWords)
		}else if regexmatch(priorExamItem,"is)CT.*Chest|low dose") && (++CTind<2) {
			;~ v.accSelect(ComObj(3,3),0)
			keyWord.=matchText(v.3,lungKeyWords)
		}

		;~ if (CXRind>10 && CTind>1)
			;~ break
	}

	first.accSelect(ComObj(3,3),0)

	if breakLineControl:=getNetControl2(RisHwnd,"","txtALL","","WindowsForms10.EDIT","","","",0)[1]
		keyword.=matchText(controlgettext(breakLineControl),cancerKeywords)

	;~ if (keyword!=""){
	if keyword=
		keyword:="..."

		monitorInfo:=monitorInfo()
		gui,destroy
		gui,new,+alwaysontop +hwndguiHwnd +toolwindow -Caption
		gui,font,s14,Verdana
		gui,add,text,,% keyword:=filterDuplicate(keyword)
		gui,show,% "x" monitorInfo.2.l " y" monitorInfo.2.b-200 " autosize"
		settimer,killGui,% -1000+(-1)*strlen(keyword)*50
		winactivate,ahk_id %risHwnd%
	;~ }

}
winactivate,ahk_id %risHwnd%
controlfocus,,% "ahk_id " RisReports[1,1]
return

newFilm:
mousegetpos,x,y
checkRis(RisState)
ExamItems:=parseRisExamItems(getRisExamItems(RisHwnd:=RisState[2]))
,risReports:=getRisReports(risHwnd)
if RegExMatch(ExamItem:=ExamItems[1,1],"is)Chest.*(AP|PA)") || chestLat:=!!regexmatch(ExamItem,"is)Chest.*Lateral") {
	boneKeywords:=["rib","fracture","bone","bony","\bsclero","lytic"]
	,lungKeyWords:=["(lung|pulmonary) (nodule|mass|tumor|lesion|metasta)"]
	,cancerKeywords:=["cancer","malignant","malignancy","lymphoma","leukemia","tumor"]

	,CXRind:=0,CTind:=0,keyWord:=""

	for k,v in rows:=acc_children(acc_ObjectFromWindow(getRisHistoryId(RisHwnd))) {
		if regexmatch(priorExamItem:=acc_children(v)[4].accValue,"is)Chest.*(AP|PA)") && (++CXRind<11) {
			v.accSelect(ComObj(3,3),0)
			if (CXRind=1)
				first:=v
			if (CXRind=1 && priorExamItem!=ExamItem){
				/* open prior related films
				sleep 100
				loc:=Acc_Location(v)
				mouseclick,r,% loc.x+50,% loc.y+5,1,0
				sleep 100
				mouseclick,l,10,10,1,0,,R
				*/
			}
			keyWord.=matchText(controlgettext(risReports[2,1]),boneKeyWords)
		}else if regexmatch(priorExamItem,"is)CT.*Chest|low dose") && (++CTind<2) {
			v.accSelect(ComObj(3,3),0)
			keyWord.=matchText(controlgettext(risReports[2,2]),lungKeyWords)
		}

		if (CXRind>10 && CTind>1)
			break
	}

	first.accSelect(ComObj(3,3),0)

	if breakLineControl:=getNetControl2(RisHwnd,"","txtALL","","WindowsForms10.EDIT","","","",0)[1]
		keyword.=matchText(controlgettext(breakLineControl),cancerKeywords)

	if (keyword!=""){
		monitorInfo:=monitorInfo()
		gui,destroy
		gui,new,+alwaysontop +hwndguiHwnd +toolwindow -Caption
		gui,font,s14,Verdana
		gui,add,text,,% keyword:=filterDuplicate(keyword)
		gui,show,% "x" monitorInfo.2.l " y" monitorInfo.2.b-200 " autosize"
		settimer,killGui,% -1000+(-1)*strlen(keyword)*50
		winactivate,ahk_id %risHwnd%
	}

}
winactivate,ahk_id %risHwnd%
controlfocus,,% "ahk_id " RisReports[1,1]
mousemove,% x,% y,0
return

killGui:
gui,destroy
return

matchText(byref str,byref arrOfKeyWords){
	ret:=""
	for k,v in arrOfKeyWords {
		ret.=(s:=RXMS(str,"is)[^\.;\r\n]*" v "[^\.;\r\n]*([\.;\r\n]|$)","r"))=""?"":s "`r`n"
	}
	return ret
}

filterDuplicate(str,del="`n"){
	arr:=[]
	loop,parse,str,%del%,`r
		if (trim(a_loopfield)!="" && regexmatch(a_loopfield,"(\d{8}[^:]+: )?([^\r\n]+)",match) && !regexmatch(match2,"i)no|absen|resolut"))
			arr["" match2].=RegExReplace(match1,":","")
	str:=""
	for k,v in arr
		str.=substr(v,1,-1) ": " k "`r`n"

	return substr(str,1,-1)
}

onexit:
DetectHiddenWindows,on
simpleImpaxPwb.quit()
;~ winclose,ahk_exe ImpaxContextServer.exe
;~ Process,close,ImpaxContextServer.exe
winclose,ahk_exe AntiImpaxFlash.exe
exitapp
return

::pha::phalanx
::phg::phalanges

sendByClipboard_outputVarMode(w,l,m,h){
	global __sendByClipboard_outputVarMode
	__sendByClipboard_outputVarMode:=!!w
	if !!w
		SetTimer,sendByClipboard_outputVarMode_reset,10000
}
sendByClipboard_outputVarMode_reset:
__sendByClipboard_outputVarMode:=false
return


:*:sz::s
:*:dtdf::distal tibia and distal fibula
:*:ptpf::proximal tibia and proximal fibula
::drup::distal radius and ulnar styloid process
:*:drdu::distal radius and distal ulna

#include %a_scriptdir%\YCH_main.ahk


