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
DetectHiddenWindows,on
comobjerror(false)
#include <risimpax>
#include <Acc>
#include <NoTrayOrphans>
#include <JoinScript>
#include <prettyReport>
#include <OnScreenDisplay>
;~ #InstallKeybdHook
;~ #include <sendByClipboard_test>
#include <resetHotstringBuffer>
resetHotstringBufferHook()
OnExit,OnExit

CloseOtherYCHAHK()
OnScreenDisplay("YCH AHK")
gosub openSimpleRIS
gosub RisGroup
;~ ThisScriptsHWND := WinExist("Ahk_PID " DllCall("GetCurrentProcessId"))
global thisPlace:=getPlace()


gui,new,+hwndmainguihwnd +LastFound
WinSetTitle,ahk_id %mainguihwnd%,,% "YCH_AHK_main"
;~ winget,list,list,ahk_exe AutoHotkey.exe
;~ loop % list 
	;~ if (ThisScriptsHWND-list%a_index%)!=0
		;~ PostMessage,0x10101,,,,% "ahk_id " list%a_index%

OnMessage(0x10101,"Exit")
,OnMessage(0x10102,"win_c")
,OnMessage(0x10103,"win_z")

,thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))
,RISImpaxRegister([{app: "Ris", type: "State", hwnd: thisHwnd, msg: {msg: 0x8000}, func: "RisStateChange", initStart: 1}])
,NoTrayOrphans()
;~ RisImpaxInfo:=RisImpaxLoadPw()
;~ ,IMPAX_id:=RisImpaxInfo.Impax.1.user
;~ ,IMPAX_pw:=RisImpaxInfo.Impax.1.pw
;~ ,RIS_id:=RisImpaxInfo.Ris.1.user
;~ ,RIS_pw:=RisImpaxInfo.Ris.1.pw
,IMPAX_title:="IMPAX 6.5.2.114 Radiologist with QC"
,bullet:="- "
,abbr:=loadAbbr()
#Hotstring EndChars -()[]{}:;",.?!`n `t
#Hotstring T

laterality:={r:"right", l:"left", b:"bilateral"}

,dynamic_hotstring("i)\b(b?n?c?a?p?d?t?l?u?v?)([012345])=$","examTitle",3, 0 )
,dynamic_hotstring("i)\b(t|s|\d+|\d+\.\d+)(go|gn|n)(s?)((?:[rl][uml])+|b)([rsnm]*)([\.\,\;])","lungNodule",3,0)
,dynamic_hotstring("i)([.\W])?(\d+)\.\.(\d+)(\W)","specifyImage",3, 0)
;~ dynamic_hotstring("i)\b(\d+)p(\W)","pigtail",3,0)
,dynamic_hotstring("i)\b(\d+)\.(\d+)c(\W)","catheter",3,0)
,dynamic_hotstring("i)\b([ftpoi]{2,4})9$","brainLobe",3,0)
,dynamic_hotstring("i)\b([apsiml]{2,3})(q?)(9)$","aspect",3, 0)
;~ ,dynamic_hotstring("i)(\W)?(pcn)(\w)(\d)?(\W)","pcn",3,0)
;~ ,dynamic_hotstring("i)(\W)?(ptcd)(\w)(\d)?(\W)","ptcd",3,0)
,dynamic_hotstring("i)\b(\d{8}|\d{6})(r?)(\/|\.|\-)","insertDate",3,0)

;;; b: vertebral body
;  c: compression fracture
; e: bone marrow edema 
,dynamic_hotstring("i)\b([ctls])([123456789]\d?\d?\d?)([bce])?([^l\=\d\w])","spine",3, 0)
;~ ,dynamic_hotstring("i)\b([blr])(\w+?)(s?)//","combineHotstring",3,0)
lineTubes:={t: "endotracheal tube", k: "tracheostomy tube", g: "nasoenteric tube", v: "central venous catheter", d: "double lumen catheter", s: "Swan-Ganz catheter", a: "implantable venous access port", p: "cardiovascular implantable electronic device", c: "chest tube", i: "PICC", b: "IABP", m: "ECMO vascular cannula", n: "drainage tube", l: "pigtail catheter", x: "VP shunt", w: "coronary stent", y: "aortic stent", q: "biliary stent", o: "esophageal stent", z: "VAD", j: "metalic sternal wires", h: "status post cardiac valve replacement with sternal wiring", r: "status post TAVI"}
,dynamic_hotstring("i)\b(3t|2t|3tr|2tr)?([a-z]+)?==","lineTubes",3,0)
,dynamic_hotstring("i)\b([bnd]+)([01239])([01239])([09])([129])?([129])?\W","ErBrainCT",3,0)
,dynamic_hotstring("i)\b([rlb])(\d\d?)r(\W)","RibNo",3,0)
,dynamic_hotstring("i)\b([rlb])?([mpa])ca([123])","BrainArtery",3,0)
,dynamic_hotstring("i)\but(\d+)(\W)","upToSize",3,0)
,dynamic_hotstring("i)\b([hrsp]{2,})cc","bodyCysts",3,0)
,dynamic_hotstring("i)\b([ctl]{1,3})s([skl]*)([12345]+)(\W)","degenerativeSpine",3,0)
,dynamic_hotstring("i)\b(\d+)l(\d+)s(\W)","lesion_subpleura",3,0)
,dynamic_hotstring("i)\bs((?:[12345678][ab]?)+)l(\W)","liver_lobe",3,0)
,dynamic_hotstring("i)\bb([123])l([0123])(\W)","brainAging",3,0)


/*
spine MRI 
[li[grade]][disc][fja][hlf][area][level]0[cst][cop][fn]

li: l(spondylolisthesis), r(retrolisthesis)

disc: b,p,e,c(caudal migration), r(rostral migration)
fja: f
hlf: h

area: [zone number](-?[zone number])?
zone number = {0: central,paracentral,subarticular,foraminal,extraforaminal}
left side = negative number

level: L1=L1-2, L13=L1-3

cst: 0 (adjacent thecal sac indentation) to 3 (severe spinal canal narrowing)

cop: p=possible 

fn: rlb=side, m=mild
*/
;~ ,dynamic_hotstring("i)\b([lr]\d?)?(b?p?e?[cr]?f?h?)([lr]?[npsmx]+?)?([ctls]\d+)z([0123])?(p?[pq]?)([rlbm]*)(\W)","spineMRI",3,0)
,dynamic_hotstring("i)\b([lr]\d?)?"
									. "(b?p?e?[cr]?f?h?)" 
									. "(a-?[01234](?:-?[1234])?)?" 
									. "([ctls]\d+)" 
									. "z([0123])?"
									. "(p?[pq]?)"
									. "(m?[rbl]?m?[rl]?)(\W)","spineMRI",3,0)


/*
1: calcification of aorta 
2: calcification of coronary artery 
3: calcification of cardiac valve
a: implantable venous access port
b: no egenerative change of spine
c: calcified mediastinal lymph nodes
f: fatty liver
e: bilateral pleural effusion
ee: right pleural effusion 
eee: left pleural effusion 
t: thyroid nodule 
g: cardiomegaly 
s: gallstone(s) 
h: hypodense lesion(s) in liver, probably cyst(s). 
r: hypodense lesion(s) in kidney(s), probably cyst(s). 
w: bilateral renal stones
ww: right renal stone
www: left renal stone
x: status post cholecystectomy.
*/
abrvReports:="123acfetbgshrw"
GroupAdd,PacsViewer,ahk_exe impax-client-main.exe
GroupAdd,PacsViewer,ahk_exe WebViewerComSrvEC.exe
GroupAdd,PacsViewer,ahk_exe WEBVIE~1.EXE
GroupAdd,PacsViewer,ahk_exe Miv2Lib.exe
GroupAdd,PacsViewer,ahk_exe G3PACS.exe
Hotkey,IfWinActive,ahk_group PacsViewer
Loop,parse,abrvReports
	Hotkey,% "+!" A_LoopField,AddAbrvReports
Hotkey,IfWinActive
Loop,parse,abrvReports
	Hotkey,% "appskey & " A_LoopField,AddAbrvReports


NoTrayOrphans()
try
	menu, tray, icon,% a_scriptdir "\CT.ico",1,0
monitors:=monitorInfo()
;~ WinMove,simple RIS ahk_class AutoHotkeyGUI,,% monitors.2.l+Floor(monitors.2.w/2)-505,% Floor(monitors.2.b/2)-155,
winwait,simpleRIS_main ahk_class AutoHotkeyGUI,,30
PostMessage,0x2022,,0,,simpleRIS_main ahk_class AutoHotkeyGUI
PostMessage,0x2025,1,,,simpleRIS_main ahk_class AutoHotkeyGUI
;~ PostMessage,0x2030,0,,,simpleRIS__main ahk_class AutoHotkeyGUI

;~ autoScrollMid:=monitors.2.r
;~ autoScrollRange:=100
;~ settimer,autoScroll,-100
WinHide,miniPACS Main ahk_class AutoHotkeyGUI
resetHotstringBuffer(2000)

if InStr(A_OSVersion, "10."){
	try
	run,% A_ScriptDir "\win10hook.exe",,Hide	
}
	;~ settimer,win10#c,1000
if (__is_CH){
	CH_RIS.addAccNoChangedHookFn(Func("simpleRisUpdateText"))
}

;~ gosub topGUI
return



simpleRisUpdateText(){
	PostMessage,0x2019,,,,simpleRIS_main ahk_class AutoHotkeyGUI
}

;~ #IfWinActive,ahk_group PacsViewer
;~ #c::
;~ settimer,#c,-1
;~ return
;~ #z::
;~ settimer,#z,-1
;~ return
;~ #IfWinActive
;~ #IfWinActive,ahk_exe Menu.exe
;~ #c::
;~ settimer,#c,-1
;~ return
;~ #z::
;~ settimer,#z,-1
;~ return
;~ #IfWinActive


win_c(){
	settimer,#c,-1
}
win_z(){
	settimer,#z,-1
}
win10#c:
Hotkey,#c,#c,on
return

topgui:
gui,topgui:Default
gui,new,+hwndtopguihwnd +ToolWindow +AlwaysOnTop -Caption -border +lastfound
winset,trans,100
gui,font,w700 s20,Verdana
gui,add,button,w100 h100 x0 y0 gwin_C,#C
gui,Show,% "x" monitors[2].l " y" Floor(monitors[2].h/2)+monitors[2].t " w100 h100 NA",YCH_TopGUI
return

win_C:
gosub #c
return

BrainArtery:
send % "{bs " StrLen($.value(0))  "}"
str:=$.value(2) "ca " $.value(2) $.value(3)
StringUpper,str,str
if($.value(1)!="")
	str:=laterality[$.value(1)] " " str
send % str
return


liver_lobe($){
	segments:=[]
	for k,v in RegExMatchAll($.value(1), "i)[12345678][ab]?").list
		segments.push(v[0])
	
	send % "{bs " StrLen($.value(0))  "}"
	str:="S" join("-", segments) " of liver" $.value(2)
	send % str
}

lesion_subpleura($){
	send % "{bs " StrLen($.value(0))  "}"
	str:="0." $.value(1) "ml at lesion and 0." $.value(2) "ml at subpleura." $.value(3)
	send % str
}

/*
9 -> skip
0-3: normal csf, mild atrophy, atrophy, prominent
0-3: no ICH, mild leukoaraiosis, leukoaraiosis, confluent leukoaraiosis
0: intact skull
1-2: mild atherosclerotic calcification of the intracranial vessels, atherosclerotic calcification of the intracranial vessels. 
1-2: mild paranasal sinusitis, paranasal sinusitis
*/
ErBrainCT:
send % "{bs " StrLen($.value(0))  "}"
str:=""
,imp:=""

if ($.value(2)=0)
	str.="Normal appearance of sulci, fissures and ventricles. "
else if $.value(2)<9
	str.=($.value(2)=1?"Mild ":$.value(2)=3?"Prominent ":"") "brain atrophy with dilated sulci, fissures and ventricles. " 
	,imp:=($.value(2)=1?"Mild ":"") "brain atrophy. "


str.="`r`n" bullet 

if ($.value(3)=0)
	str.="No definite acute intracranial hemorrhage. "
else if $.value(3)<9
	str.=($.value(3)=3?"Confluent ":"") "low densities at bilateral periventricular white matter, suggestive of " ($.value(3)=1?"mild ":"") "leukoaraiosis. "
	,imp.=($.value(3)=1?"Mild ":"") "leukoaraiosis. "

str.="`r`n" bullet 

if ($.value(4)=0)
	str.="Normal appearance of the cranial vault and skull base. `r`n" bullet 

str.="`r`n" bullet 

if $.value(5) && ($.value(5)<9)
	str.=($.value(5)=1?"Mild ":"") "atherosclerotic calcification of the intracranial vessels. `r`n" bullet  

if $.value(6) && ($.value(6)<9)
	str.=($.value(6)=1?"Mild ":"") "paranasal sinusitis. `r`n" bullet  

$.value(2):=1
,returnStr:=partValue:=1
gosub examTitle

;~ send % returnStr str
if imp=
	imp:="No definite acute intracranial hemorrhage. "
if __is_CH
	send % returnStr str "`r`n`r`nImpression: `r`n" imp
else
	setReportText(returnStr str, imp)
returnStr:=0
return

autoScroll:
mousegetpos,mx
if (abs(autoScrollMid-mx)<autoScrollRange) {
	if (inAutoScroll && !getkeystate("Lbutton")){
		send {lbutton down}
	}
	inAutoScroll:=1
	settimer,autoScroll,-500
}else{
	if (inAutoScroll  && getkeystate("Lbutton"))
		send {lbutton up}
	inAutoScroll:=0
	settimer,autoScroll,-100
}

return



getReportList:
parseDataGrid(getRisList(),reportList)
return
;~ cmdContextServer(str,hwnd=""){
	;~ DetectHiddenWindows,on
	;~ if !hwnd && !hwnd:=winexist("ahk_exe ImpaxContextServer.exe")
		;~ return 1
	;~ loop,parse,str
	;~ {
		;~ PostMessage,0x10303,,% asc(a_loopfield),,ahk_id %hwnd%
		;~ sleep 20
	;~ }
	;~ PostMessage,0x10303,,0x0,,ahk_id %hwnd%
	
;~ }
impaxNextStudy:
;~ controlsettext,Scintilla1,% "",simple RIS ahk_class AutoHotkeyGUI
;~ controlget,editHwnd,hwnd,,Scintilla1,simple RIS ahk_class AutoHotkeyGUI
editHwnd:=getSimpleRisEditHwnds[2]
;~ Edit_SetText(editHwnd,"")
resetSimpleRis()
if !(impaxContextServerHwnd:=ImpaxContextServer_Init()) {
	return
}
sheetNo:=getRisSheetNo(risOpened()[2])
,SendStr:=""
for k,v in reportList
	if (k>1 && v[reportListSheetCol]=sheetNo && k<reportList.maxIndex()-1) {
		thisReport:=v
		,sendStr.="SYNC_DISPLAY || " reportList[k+1,reportListSheetCol] " || "
		,sendStr.="ADD_TO_DISPLAY_LIST || " reportList[k+2,reportListSheetCol] " || "
		,ImpaxContextServer_SendCommand(sendstr,impaxContextServerHwnd)
		break
	}
;~ if (++impaxNextStudy>10){	
	;~ impaxNextStudy:=0
;~ }
winactivate % "ahk_id " risopened()[2]
return

#ifwinactive,ahk_group RisGroup
F8::
reportList:=[]
settimer,getReportList,-1
if !(impaxContextServerHwnd:=ImpaxContextServer_Init()) {
	return 
}
sleep 500
for k,v in reportList[1] {
	if (v="照會單號") {
		reportListSheetCol:=k
		break
	}
}
sheetNo:=getRisSheetNo(risOpened()[2])
,SendStr:=""
for k,v in reportList
	if (k>1 && v[reportListSheetCol]=sheetNo && k<reportList.maxIndex()-1) {
		sendStr.="SYNC_DISPLAY || " v[reportListSheetCol] " || "
		,sendStr.="ADD_TO_DISPLAY_LIST || " reportList[k+1,reportListSheetCol] " || "
		,ImpaxContextServer_SendCommand(sendStr,impaxContextServerHwnd)
		break
	}
winactivate % "ahk_id " risopened()[2]
return

F3::
+F3::
F1::
+F1::
F2::
+F2::
^F3::
thisHotkey:=a_thisHotkey
quicksend:
editHwnds:=getSimpleRisEditHwnds()
gosub checkReport
if simpleRisError
	return
;~ clipboard:=Edit_GetText(editHwnd)
;~ impaxCyclicListDo()
appendAbbr()
;~ clipboard:=Edit_GetText(editHwnd)
;~ gosub impaxNextStudy

if !WinExist("ahk_exe Menu.exe") && !InStr(thisPlace, "C hospital") {
	clipboard:=Edit_GetText(editHwnds[2])
	WinActivate,ahk_exe vncviewer.exe
	WinActivate,ahk_exe TightVNCViewerPortable.exe
}else if !(recentSent) && !InStr(thisHotkey, "^") {
	
	if instr(thisHotkey,"F3") {
		;~ if (!sendButton || !controlexists(sendButton))
			;~ sendButton:=getNetControl2(RisState[2],"存檔發送","cmdRunVerifySend","存檔發送","WindowsForms10.BUTTON.app","","","",0)[1]
		;~ controlclick,,% "ahk_id " sendButton
		risSendReport(RisState[2], 3)
	}else if instr(thisHotkey,"F1") {
		;~ if (!saveButton || !controlexists(saveButton))
			;~ saveButton:=getNetControl2(RisState[2],"暫存","cmdRunSave","暫存","WindowsForms10.BUTTON.app","","","",0)[1]
		;~ controlclick,,% "ahk_id " saveButton
		risSendReport(RisState[2], 1)
	}else if instr(thisHotkey,"F2"){
		;~ if (!verifyButton || !controlexists(verifyButton))
			;~ verifyButton:=getNetControl2(RisState[2],"存檔","cmdRunVerify","存檔","WindowsForms10.BUTTON.app","","","",0)[1]
		;~ controlclick,,% "ahk_id " verifyButton
		risSendReport(RisState[2], 2)
	}
	recentSent:=true
	settimer, recentSent, -3000
}
;~ Edit_SetText(editHwnd,"")
if WinExist("ahk_exe Menu.exe"){
	if lastChestCTtemplateAccNo!=getRisAccNo(risHwnd)
		resetSimpleRis()
}else
	setTimerF("resetSimpleRis", -1000)

if WinExist("ahk_exe SelectCT.exe"){
	PostMessage,0x10102,,,,ahk_exe selectCT.exe
}

;~ settimer,nextOldStudy,-1000
donothing:

return
#ifwinactive

nextOldStudy:
;~ if (getRisChartNo(RisState[2])=getImpaxChartNo()){
if RisChartNoMatchPacs(RisState, ImpaxState){
	risOpenOldStudy(RisState[2])
}else{
	PostMessage,0x10102,1,,,impaxOpenNext_main ahk_class AutoHotkeyGUI
}
return

checkReport:
risReports:=getRisReports(RisState[2])
gosub copyToRis

if simpleRisError
	return

if trim(text)=
	goto donothing

_imp:=parseImpressionSentences(Text)

if InStr(thisHotkey, "F3") || InStr(thisHotkey, "F2") {
	Text:=RegExReplace(Text,"is)\r?\n? *\(非正式報告，僅供參考\) *\r?\n?","")
}


if instr(text,"//")
	text:=parseChestCTCommand(text)
;~ text:=RegExReplace(text," *(-+|\d+[^\w\n\r]) +[^:]+: *\r\n?","")

Text:=reportReplace(Text)

,text:=parseReport(text)
;~ text:=RegExReplace(text,"\.+",".")

, Text:=RegExReplace(Text, "i)phayngeal", "phayrngeal")
, Text:=RegExReplace(Text, "i)no enlarge ", "no enlarged ")
, Text:=RegExReplace(Text, "LAPs?", "lymphadenopathy")
, Text:=RegExReplace(Text, "^Hx: |^History of ", "History: ")
, Text:=RegExReplace(Text, "i)- im\/?\.?(\r?\n)", "")
, Text:=RegExReplace(Text, "i)(- [^\r\n]*)im\/?\.?(\r?\n)", "$1$2")

,text:=RegExReplace(text,"\ {2,}(?!(-+ |\d+[^\w\n\r] ))"," ")
,text:=RegExReplace(text,"(\r?\n)(\ *)(\-)\ *(\w)","$1$2$3 $4")
,text:=RegExReplace(text,"(?<=[\,\.\;\(])\ {2,}"," ")
,text:=RegExReplace(text,"(?<!\n) {2,}"," ")
,text:=RegExReplace(text,"\.{2,}",".")
,text:=RegExReplace(text,",{2,}",",")
,text:=RegExReplace(text,"\.\,",",")
,text:=RegExReplace(text,"\,\.",".")
,text:=RegExReplace(text," ([,.;])","$1")
;~ text:=RegExReplace(text,"i)([a-z])\. ([a-z])","$1.$2")
,text:=RegExReplace(text,"([,;])(\w)","$1 $2")
,text:=RegExReplace(text,".  +(\r?\n)",". $1")
,text:=RegExReplace(text,"(?<=[\r\n])(-+|\d+[^\w\n\r\,\;]) +(\r?\n)|(-+|\d+[^\w\n\r\,\;]) +(\r?\n)*$","")
,text:=RegExReplace(text,"(?<=[\r\n])(-+|\d+[^\w\n\r\,\;]) +","$1 ")
,Text:=RegExReplace(Text, "<=?(5|4)mm" , "<6mm")
;~ text:=RegExReplace(text,"is)^(History[^\r\n]+?)\s*;","$1.")

,RegExMatch(text,"is)(History[^\r\n]+)?(.+)",match)
if regexmatch(match1,"(;)? *$",m) && strlen(m)
    text:=substr(match1,1,(-1)*strlen(m)) "." match2

;~ text:=RegExReplace(text,"(\.)  +(\w)",". $2")
arr1:=[],arr2:=[]
,incomplete:=0
;~ loop,parse,text,`.
		;~ newText.=stringupper(substr(a_loopfield,1,1)) substr(a_loopfield,2) ". "
,text:=RegExReplace(text,"(?<!\d)[\.\,\;](?![\d \)])","$0 ")
,rxms(text,"([\.|\n]\s*)|([->\*#]+\s+)|(\n?\d+[^\w\n\r\,\;]\s+)","sarr1[] marr2[]")
,newText:=""
for k,v in arr1
	newText.=stringupper(substr(v,1,1)) substr(v,2) arr2[k]
	;~ newText.=v arr2[k]
;~ msgbox % newText
;~ newText:=substr(newText,1,-2)
;~ newText:=RegExReplace(newText,"(\d). (\d)","$1.$2")
;~ newText:=RegExReplace(newText,"\. \)",".)")
newText:=RegExReplace(newText,"(?<!\n) {2,}"," ")

;~ newText:=parseReport(newText)
,newText:=moveText(newText)
;~ ,changeLineBreak(newText)
;~ controlsettext,Scintilla1,% newText,simple RIS ahk_class AutoHotkeyGUI
,PauseSimpleRis()
,editHwnds:=getSimpleRisEditHwnds()
if __is_N
	;~ Edit_SetText(editHwnds[2], newText)
	Edit_SetText(editHwnds[1], newText)
;~ controlsettext,,% newText,% "ahk_id " RisReports[1,1]
Edit_SetText(RisReports[1,1], newText)

;~ if incomplete
	;~ goto incomplete
if instr(a_thishotkey,"+")
	gosub referText

;~ impressionText:=Trim(controlgettext(risReports[1,2]))
if __is_N
	impressionText:=Trim(Edit_GetText(risReports[1,2]))
	,impressionText:=reportReplace(impressionText)
else
	impressionText:=""

if InStr(thisHotkey, "F3") || InStr(thisHotkey, "F2") {
	impressionText:=RegExReplace(impressionText,"is)\r?\n? *\(非正式報告，僅供參考\) *\r?\n?","")
}

if (_imp!="")
	impressionText.=(impressionText=""?"":"`r`n") _imp "`r`n"

arr1:=[],arr2:=[]
;~ ,rxms(impressionText,"([\.|\n]\s*)|([->\*#]+\s+)|(\n?\d+\W\s+)","sarr1[] marr2[]")
,rxms(impressionText,"([\.|\n]\s*)|([->\*#]+\s+)|(\n?\d+[^\w\n\r\,\;]\s+)","sarr1[] marr2[]")
,newImpressionText:=""
for k,v in arr1
	newImpressionText.=stringupper(substr(v,1,1)) substr(v,2) arr2[k]
;~ controlsettext,,% newImpressionText,% "ahk_id " risReports[1,2]
Edit_SetText(risReports[1,2], newImpressionText)

if (__is_CH){
	
	
	AllReportText:=RegExReplace((lastReport:=new ReportImpression(newText, newImpressionText)).combine(), "(?<!\r)\n", "`r`n")
	;~ Edit_SetText(editHwnds[2], AllReportText)
	if RegExMatch(AllReportText, "(通報臨床醫師\d+|疑似肺結核|通報臨床醫師\(急\)) ?", pmmatch) {
		StringReplace,newText,newText,% pmmatch,,all
		StringReplace,newImpressionText,newImpressionText,% pmmatch,,all
		AllReportText:=RegExReplace((lastReport:=new ReportImpression(newText, newImpressionText "`r`n`r`n" pmmatch)).combine(), "(?<!\r)\n", "`r`n")
	}
	
	Edit_SetText(editHwnds[1], AllReportText)
	;~ ,Edit_SetText(CH_RIS.gui.exam_edit, newText)
	;~ ,Edit_SetText(CH_RIS.gui.impression_edit, newImpressionText)
	,CH_RIS.exam:=newText
	,CH_RIS.impression:=newImpressionText
	,CH_RIS.report:=AllReportText
	,CH_RIS.flush()
}
return
incomplete:
msgbox % "Check the report for AHK error!"
return

referText:
if !instr(impressionText:=controlgettext(risReports[1,2]),"Please refer to the text above for detailed findings.") 
	&& !InStr(impressionText, "Please see the images and findings.")
	controlsettext,,% impressionText "`r`nPlease refer to the text above for detailed findings.",% "ahk_id " risReports[1,2]
return


Exit(){
	Exitapp
}

lungNodule:
send % "{bs " StrLen($.value(0))  "}"
str:="", meanSize:=false, upto:=""
if($.value(1)="t")
	str.="tiny (<6mm) "
else if($.value(1)="s")
	str.="small (<10mm) "
else if RegExMatch($.value(1), "(\d+)\.(\d+)", m)
	str.="", size:="(" m1 "*" m2 "mm, mean " Round((m1+m2)/2) "mm)", meanSize:=true
else if ($.value(4)!="b") && (len:=StrLen($.value(4)))<=2 && ($.value(3)!="s")
	str.=$.value(1) "mm "
else
	upto:=", up to " $.value(1) "mm"

if($.value(2)="gn")
	str.="GGN"
else if($.value(2)="go")
	str.="GGO"
else
	str.="nodule"

if($.value(3)="s" || (len:=StrLen($.value(4)))>2) || (upto!="")
	str.="s"
else 
	str:="a " str



if meanSize
	str.=" " size " "

lobes:=""
if ($.value(3)!="s") || ($.value(4)!="b"){
	Loop % len/2 {
		i:=A_Index*2-1
		,lobes.=SubStr($.value(4),i,2) "l, "
	}
	StringUpper,lobes,lobes
	lobes:=RegExReplace(lobes, "LML, ", "lingular LUL, ")
	
	,lobes:=" in " lobes
}

description:=""
if InStr($.value(5),"s")
	description:=", " (InStr($.value(5),"r")?"roughly ":"") "unchanged" (InStr($.value(5),"m")?" but malignancy can not be excluded":"")
if InStr($.value(5),"n")
	description.=", probably non-specific"
if upto=
	send % str SubStr(lobes,1,-2) description $.value(6)
else
	send % str upto SubStr(lobes,1,-2) description $.value(6)
return


lineTubes:
send % "{bs " StrLen($.value(0))  "}"
result:="placement of "
str:=$.value(2)
if($.value(0)="="){
	send {=}
	return
}
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
		str2.=lineTubes[a_loopfield] "."
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
if (result!="placement of ")
	send % RegExReplace(result,"\, $",".") 
send % str2
return

#IfWinActive,ahk_exe impax-client-main.exe


AddAbrvReports:
;~ MouseGetPos,,,win
;~ winget,ProcessName,ProcessName,A
;~ if !InStr(ProcessName, "impax"){
	;~ ToolTip % ProcessName
	;~ return
;~ }

RegExMatch(A_ThisHotkey, "([\d\w])$", thisHotkey)
MouseGetPos,,,win,con,2
;~ ToolTip, % "Add abbreviation: " thisHotkey1,% monitors.2.l+Floor(monitors.2.w/2),% 400
;~ SetTimer,ToolTip,-1000
SetTimerFn("OnScreenDisplay", -1, [thisHotkey1, 400, 50, "white"])
editHwnds:=getSimpleRisEditHwnds()
if (!editHwnds.length()){
	checkRis(RisState)
	gosub renewRisReports
	reportHwnd:=risReports[1,1]
}else
	reportHwnd:=editHwnds[2]
Edit_GetSel(reportHwnd,s,e)
if matched:=RegExMatch(Text:=ControlGetText(reportHwnd), "is)([123]*)(\w*)\/\/", match) {
	Edit_InsertText(reportHwnd, thisHotkey1, matched+StrLen(match1)-1)
	;~ Text:=SubStr(Text,1,matched-1) match1 thisHotkey1 SubStr(Text,matched+StrLen(match1 thisHotkey1))
	;~ s:=
}else{
	Edit_InsertText(reportHwnd, "`r`n" thisHotkey1 "//", -1)
}
WinActivate,% "ahk_id " win
ControlFocus,,% "ahk_id " con
;~ send {RButton up}
return
#IfWinActive


:*:tavi0::
(
Aortic Annulus:
- Thickened trileaflet aortic valve with mild calcifications.
- Aortic annulus short diameter:  22.8mm.
- Aortic annulus long diameter:  29.7mm.
- Aortic annulus circumference and circumference-derived diameter: 82.9mm, 26.4mm
- Aortic annulus area and area-derived diameter: 521.9mm2, 25.8mm

Iliac Artery: (Right, Left)
- CIA: 7.4*10.3mm, 6.3*10.8mm
- EIA: 6.0*7.6mm, 5.7*6.9mm
- Femoral: 5.7*6.8mm, 5.2*7.4mm
)

OnExit:
WinClose,ahk_exe AntiImpaxFlash.exe
ExitApp
return

::reqq::
RisHwnd:=risopened()[2]
,risReports:=getRisReports(RisHwnd)
while (!GetKeyState("Esc") && getRisStudyStatus(RisHwnd)=="待判讀" && parseRisExamItems(getRisExamItems(RisHwnd))[1,1]~="^Requesting"){
	thisAccNo:=getRisAccNo(risHwnd)
	,setReportText("Radiological images from outside hospital had been uploaded into the PACS (Picture Archiving and Communication System) server as a baseline or for comparison. Please check the original formal report of these images from the source hospital.", "", RisReports, 1, 1, 0, 0)
	,risSendReport(risHwnd)
	
	Loop 
		Sleep 100
	until getRisAccNo(risHwnd)!=thisAccNo || GetKeyState("Esc")
	Sleep 500
}
return


::lgis::
t=
(
Single contrast study of the colon under the fluoroscopic control was performed smoothly and it shows:
- Occult lesion may not be detected in single contrast study.
- Normal haustration, caliber and profile of the lower gastrointestinal tract.
- No obvious filling defect or obstructive lesion.
- Multiple small outpouching lesions are noted in ascending colon, compatible with diverticulosis. 
- No widening of the presacral space.
- The ileocecal valve is unremarkable.
- The appendix is not shown.

Impression:
No obvious abnormality in lower gastrointestinal tract.
)
send % t
return

::ugii::
t=
(
Esophageal and upper gastrointestinal series with barium meal under fluoroscopy shows:
- The mucosal pattern, contour and peristalsis of the esophagus are within normal limit.
- Visible gastroesophageal junction in normal position without definite focal lesion. No gastroesophageal reflux.
- Normal gastric contour and mucosal pattern without active ulcer. No widening and rigidity of the gastric angularis.
- The barium runs fluently through the pyloric canal into the duodenum and then reaches the jejunum. The pyloric canal expands well from then on.
- Well-distended duodenal bulb shows no ulcer formation or deformity. No definite mucosal thickening detected.

Impression:
No definite focal lesion.
)
send % t
return

:*:ttube::
t=
(
T-tube cholangiography with water-soluble contrast medium under fluoroscopy was smoothly performed and showed:
> status post T-tube insertion positioned in the cystic duct.
> status post cholecystectomy.
> Smooth opacification of the common bile duct and IHDs of both lobes without abnormal dilatation or filling defect.
> Smooth passage of contrast medium into the duodenal loop without evidence of obstructive lesion or extravasation.

Impression:
No definite extravasation or obstruction of opacified bile ducts.
)
send % t
return

::hsgg::
t=
(
Hysterosalpingography with water-soluble contrast under fluoroscopic control shows:
- Well-outlined uterine cavity with normal shape, size and position.
- Patent bilateral fallopian tubes with free intraperitoneal spilling.
- Fine dispersion of contrast medium in the pelvic cavity on delayed film.

Impression:
Bilateral patent fallopian tubes.
)
send % t
return

::cysto::
t=
(
Cystography shows: 
- Moderate distention of urinary bladder with smooth contour. 
- No evidence of urine leakage. 
- Failed urination during the procedure.

Impression:
No significant radiological abnormality.
)
send % t
return


::tacel::
t=
(%
TACE of liver is performed:
- Indication: a hypervascular tumor at S8 of liver.
- Patient consent: obtained.
- Instrument: 5Fr RC1 catheter, Progreat microcatheter (2.7Fr).
- Anesthesia: local anesthetia with xylocaine 2% 10ml.
- Material: epirubicin emulsified in lipiodol (half of total dose injected), Gelfoam fine particles. 
- Procedure:
  -- Puncture right common femoral artery.
  -- Angiography shows tumor stain supplied by one of the RHAs.
  -- Perform embolization at one RHA. Inject Gelfoam particles until flow stasis. 
- Complication: nil
- Recommendation:
  -- Sand bag compression, then total bed rest.
  -- Monitor local wound condition.
  -- Follow-up liver function.
  
(RHA: right hepatic artery.)

Impression:
A hypervascular hepatic tumor, status post TACE.
)
send % t
return

spineMRI($){ 
	static loc_term:={0: "central", -1: "left paracentral", -2: "left subarticular", -3: "left foraminal", -4: "left extraforaminal", 1: "right paracentral", 2: "right subarticular", 3: "right foraminal", 4: "right extraforaminal"}
		, cst_term:=["adjacent thecal sac indentation", "mild spinal canal narrowing", "moderate spinal canal narrowing", "severe spinal canal narrowing"]
send % "{bs " strlen($.value(0)) "}"
	hivd:=false
	
	disc:=[]
	disc_value := $.value(2)
	if InStr(disc_value, "b")
		disc.push("bulging")
	if InStr(disc_value, "p")
		disc.push("protruding"), hivd:=true
	if InStr(disc_value, "e"){
		disc.push("extruding"), hivd:=true
		ex:=InStr(disc_value, "c")?" with caudal migration":InStr(disc_value, "r")?" with rostral migration":""
	}
		
	
	part1:=[]
	part_hivd:=[]
	
	li_value:=$.value(1)
	if InStr(li_value, "l"){
		part1.push((RegExMatch(li_value, "\d", m)?"grade " m " ":"") "spondylolisthesis")
	}else if InStr(li_value, "r"){
		part1.push("retrolisthesis")
	}
	
	if hivd
		part_hivd.push(join("-", disc) " disc" ex)
	else
		part1.push(join("-", disc) " disc" ex)
	
	if InStr(disc_value, "f")
		part1.push("facet joint arthroses")
	if InStr(disc_value, "h")
		part1.push("hypertrophic ligamenta flava")
	
	; hivd zone
	loc:=[],
	,has_loc:=false

	for k,v in RegExMatchAll($.value(3), "-?\d").list
		if (v[0]!="") && loc_term.haskey(v[0])
			loc.push(loc_term[v[0]])
			,has_loc:=true
	zone_str := loc.length()>1?"zones":"zone"
	
	RegExMatch(lvl_str:=$.value(4), "\d+$", lvl_no)
	if StrLen(lvl_no)=1 {
		if lvl_str in C7,T12,L5
			lvl_str.="1"
		else
			lvl_str.=(lvl_no+1)
	}
	lvl:=spineLevel(lvl_str)
	
	part2:=[]
	if(cst:=cst_term[$.value(5)+1])
		part2.push(cst)
	
	cop:=""
	if InStr($.value(6), "pp")
		cop:="possible cord compression"
	else if InStr($.value(6), "pq")
		cop:="possible cauda equina compression"
	else if ($.value(6)="p")
		cop:="cord compression"
	else if ($.value(6)="q")
		cop:="cauda equina compression"
	if cop
		part2.push(cop)
	
	for k,v in RegExMatchAll($.value(7), "i)m?[lrb]").list {
		str:=""
		v:=v[0]
		if InStr(v, "m")
			str.="mild "
		part2.push(str (InStr(v,"l")?"left ":InStr(v,"r")?"right ":InStr(v,"b")?"bilateral ":"") "neural foraminal narrowing")
	}
	
	if hivd
		out:= join("", part_hivd) " at " (has_loc?(Join(" to ", loc) " " zone_str " of"):"") " " lvl (part1.length()=0?"":", with " Join(", ", part1)) (part2.length()=0?"":", causing " Join(", ", part2)) "."
	else 
		out:= Join(", ", part1) " " "at "  lvl (part2.length()=0?"":", causing " Join(", ", part2)) "."
	
	out:=RegExReplace(out, " {2,}", " ")
	send % out "`n- "
	
}


#if __is_CH && WinActive("ahk_exe G3PACS.exe")
~F2::
~F3::
~F4::
~F5::
~F6::
~F7::
~F8::
~F9::
~F10::
if (__is_CH && !GetKeyState("Lbutton") && !GetKeyState("Rbutton"))
{
	if(this_chartNo!=CH_RIS.chartNo){
		this_chartNo:=CH_RIS.chartNo
		Sleep 500
		SendLevelChange("q")
	}
}
return 
#IfWinActive


#include %a_scriptdir%\YCH_main.ahk

