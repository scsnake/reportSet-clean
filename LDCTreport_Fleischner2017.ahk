#include <checkUpdate>
;~ SetTimerF("scs_sync",-1)
SetTitleMatchMode,2
SetBatchLines,-1
DetectHiddenWindows, On
SetTitleMatchMode,2
coordmode,mouse,screen
ComObjError(false)
FileEncoding,utf-8
OnExit,OnExit
#include <XML>
#include <Edit>
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; not used here — idle owner). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <SetTimerF>
#SingleInstance,force


LungLobes:=["RUL","LUL","RML","lingular LUL","RLL","LLL","right lung","left lung","bilateral lungs","bilateral upper lungs","bilateral lower lungs"]
,side:={r:"right", l:"left", b:"bilateral"}
,site:={u:"upper", m:"middle", l:"lower", n:"lung"}


gosub gui

monitorInfo:=monitorInfo()
,SEIM:=[]
;~ settimer,getSEIM,500
settimer,activeControl,-50

try 
	Menu,tray,icon,% a_scriptdir "\LDCTreport.ico",1,0

return

activeControl:
;~ activeControlHwnd:=getFocusedHwnd()
;~ if(pActiveControlhwnd && pActiveControlHwnd!=activeControlHwnd){
	;~ activeControlChanged(pActiveControlHwnd, activeControlHwnd)
;~ }	
;~ pActiveControlHwnd:=activeControlHwnd
GuiControlGet, activeCon, %guihwnd2%: FocusV
if(pactiveCon && pactiveCon!=activeCon)
	activeControlChanged(pActiveCon, activeCon)
pactiveCon:=activeCon
settimer,,-50
return

activeControlChanged(pActiveCon, ActiveCon){
	global guihwnd2, noduleSizeHwnd
	if(pActiveCon="size"){
		ToolTip
		GuiControlGet,noduleSize,%guihwnd2%:,size
		if RegExMatch(Trim(noduleSize), "([\d\.]+)\W *([\d\.]+)(cm)?", m){
			if(m3="cm")
				m1*=10, m2*=10
			s1:=Floor(m1+0.5)
			,s2:=Floor(m2+0.5)
			,mean:=Floor((m1+m2)/2+0.5)
			
			
			if(m3="cm"){
				s1:=Format("{:0.1f}", s1/10)
				,s2:=Format("{:0.1f}", s2/10)
				,mean:=Format("{:0.1f}", mean/10)
				,s:= mean "cm (" s1 "*" s2 "cm)"
			}else{
				s:= mean "mm (" s1 "*" s2 "mm)"
			}
			guicontrol,Text,% noduleSizeHwnd,% s
		}
	}else if(activeCon="size"){
		ShowToolTip("For example, ""5,7"" => ""6mm (5*7mm)""",5000)
		
	}
}

gui:
ToolTip
gui,1:Default
gui,+hwndguiHwnd
GroupAdd,MyGUI,ahk_id %guiHwnd%
gui,Font,s12,Verdana

gui,Add,Text,,Lung findings:
gui,Add,button,gaddFindings,Nodule/GGO
gui,Add,button,x+5 gaddFindings,PFN
gui,Add,button,x+5 gaddFindings,Ifxn
gui,Add,button,x+5 gaddFindings,Emphysema
gui,add,Edit,% "xs w600 r5 vlungFindings hwndeditHwnd",

gui,add,Text,,Other findings:
gui,add,button,gaddFindings,Cal
gui,add,button,x+5 gaddFindings,Cyst
gui,add,button,x+5 gaddFindings,Thyroid
gui,add,Edit,% "xs w600 r5 vextraFindings hwndedithwnd2",% DefaultExtraFindings:="- No definite mediastinal mass or lymphadenopathy. `r`n- Degenerative change of thoracic spine. `r`n- "

;~ gui,add,Text,,% "`n"
gui,Font,s12 w700,Verdana
gui,add,Text,,Impression:
gui,Font,s12 w400,Verdana
gui,add,Text,xm,Risk factor
gui,add,DropDownList,xp+100 vriskfactor gprovideSuggestion hwndimprfhwnd,% "Unknown||High Risk|Low Risk"
gui,add,Text,x+20,Multiplicity
gui,add,DropDownList,xp+100 vmultiplicity gprovideSuggestion hwndimpmulhwnd,% "||Single|Multiple"
gui,add,Text,xm,Nodule
gui,add,DropDownList,xp+100 vnoduleType gprovideSuggestion hwndimpnthwnd,% "||Solid|PSN|GGN"
gui,add,Text,x+20,Size
gui,add,DropDownList,xp+100 vnoduleSz gprovideSuggestion hwndimpnshwnd,% "||<6|≥6,<8|≥8"
gui,add,edit,xm r5 w600 vimpression hwndimpressionHwnd,

gui,add,button,gsubmit,Submit
gui,add,button,greset yp x+50,Reset
gui,add,button,gcopyimpression yp x+300,Copy

gui,Show,AutoSize,LDCT Report (Fleischner Guidelines 2017)
gosub provideSuggestion
return

copyimpression:
clipboard:=ControlGetText(ImpressionHwnd)
ShowToolTip("Impression copied!")
return

provideSuggestion:
sug:=""
Gui,1:Submit,NoHide
if(noduleType="solid"){
	if(noduleSz="<6"){
		choices:={"low risk": "No routine follow-up.", "high risk": "Optional follow-up CT at 12 months."}
		,sug:=considerRiskFactor(Riskfactor, choices)
	}else if(noduleSz="≥6,<8"){
		if(Multiplicity="single"){
			choices:={"low risk": "Follow-up CT at 6-12 months, then consider another CT at 18-24 months."
				, "high risk": "Follow-up CT at 6-12 months, then another CT at 18-24 months."}
			,sug:=considerRiskFactor(Riskfactor, choices)
		}else if (Multiplicity="multiple"){
			choices:={"low risk": "Follow-up CT at 3-6 months, then consider another CT at 18-24 months."
				, "high risk": "Follow-up CT at 3-6 months, then another CT at 18-24 months."}
			,sug:=considerRiskFactor(Riskfactor, choices)
		}
	}else if (noduleSz="≥8"){
		if(Multiplicity="single"){
			sug:="Consider follow-up CT at 3 months, or PET/CT, or tissue sampling."
		}else if (Multiplicity="multiple"){
			choices:={"low risk": "Follow-up CT at 3-6 months, then consider another CT at 18-24 months."
				, "high risk": "Follow-up CT at 3-6 months, then another CT at 18-24 months."}
			,sug:=considerRiskFactor(Riskfactor, choices)
		}
	}
		
	
}else if(noduleType="GGN"){
	if (Multiplicity="single"){
		if(noduleSz="<6"){
			sug:="No routine follow-up."
		}else if (noduleSz!=""){
			sug:="Follow-up CT at 6-12 months. If persistent, then CT at 3 and 5 years."
		}
	}else if (Multiplicity="multiple"){
		choices:=["Follow-up CT at 3-6 months. ","If stable, consider CT at 2 and 4 years."]
		,sug:=InStr(Riskfactor,"low")?choices[1]:(choices[1] choices[2])
	}
}else if(noduleType="PSN"){
	if (Multiplicity="single"){
		if(noduleSz="<6"){
			sug:="No routine follow-up."
		}else{
			sug:="Follow-up CT at 3-6 months. If persistent and stable with solid component <6mm, annual CT for 5 years."
		}
	}else if (Multiplicity="multiple"){
		choices:=["Follow-up CT at 3-6 months. ","If stable, consider CT at 2 and 4 years."]
		,sug:=InStr(Riskfactor,"low")?choices[1]:(choices[1] choices[2])
	}
}
if (sug=""){
	if (PFN_benign!="" && PFN_benign)
		sug:="For perifissural or other juxtapleural location with a morphology consistent with an intrapulmonary lymph node, follow-up CT is not recommended, even if the average dimension exceeds 6 mm."
}else{
	sug.="`n(This suggestion is based on ""Guidelines for Management of Incidental Pulmonary Nodules Detected on CT Images: From the Fleischner Society 2017"", please refer to original article for details.)"
}
guicontrol,Text,% ImpressionHwnd,% sug
return


considerRiskFactor(Riskfactor, choices){
	sug:=""
	if (Riskfactor="unknown"){
		for k,v in choices
			sug.= v " (" k ") / "
		sug:=SubStr(sug,1,-3)
	}else{
		sug:=choices[Riskfactor]
	}
	return sug
}

ToolTip:
ToolTip
return

Reset:
Reload
;~ guicontrol,,lungFindings,% ""
;~ guicontrol,,extraFindings,% DefaultExtraFindings
;~ guicontrol,,Conclusion,% "|" defaultConclusions
return

Submit:
gui,Submit,NoHide


finalReport:="TECHNIQUE: Low dose CT (LDCT) of the chest without intravenous contrast administration.`r`n`r`nLung findings: `r`n" (lungFindings=""?"- No significant lung abnormality. ":lungFindings) "`r`n`r`nOther findings: (Limited detection of extrapulmonary lesion on LDCT.)`r`n" extraFindings
,finalReport:=RegExReplace(finalReport, "(- \r?\n)|(- $)", "")

,finalReport:=addAbbr(finalReport)

,setReportText(finalReport, impression)
if(simpleRis:=WinExist("simple RIS ahk_class AutoHotkeyGUI")){
	controlget,ScintillaHwnd,hwnd,,Scintilla1,simple RIS ahk_class AutoHotkeyGUI
	Edit_SetText(ScintillaHwnd, finalReport)
}
winactivate,% "ahk_id " RisOpened()[2]
return

addAbbr(Report){
	static LungLobesArr:={RUL: "right upper lobe", RML: "right middle lobe", RLL: "right lower lobe", LUL: "left upper lobe", LLL:"left lower lobe"}
	str:=""
	for k,v in LungLobesArr
		if RegExMatch(Report, "\b" k "\b")
			str.=k ": " v "; "
	if(str="")
		return Report
	else
		return RegExReplace(Report, "(\r?\n?)*$", "") "`r`n`r`n(" SubStr(str,1,-2) ")"
}

AddFindings:
gui,2:Destroy
gui,2:+Owner1 +OwnDialogs +hwndguiHwnd2
gui,2:Default
gui,Font,s12,Verdana
gosub % RegExReplace(a_guicontrol, "\W", "_")
return


Nodule_GGO:
gui,add,ComboBox,% "w200 vquantity",% "A||Multiple"
gui,add,ComboBox,% "w200 vsize hwndnoduleSizehwnd",% "tiny (<6mm)||small (<=10mm)"
gui,add,ComboBox,% "w200 vcharacter",% "part-solid|cavitary|ill-defined|calcified"
gui,add,ComboBox,% "w200 vlesion",% "nodule|GGN|GGO|mass"
gui,add,Text,,in
gui,add,ListBox,% "x+200 ys w200 r11 vlobe 8 t4 hwndlbhwnd1",% "RUL|LUL|RML|lingular LUL|RLL|LLL|right lung|left lung|bilateral lungs|bilateral upper lungs|bilateral lower lungs"
gui,add,ComboBox,% "xs w200 vchange",% "stable|larger|smaller"
ShowSub:
gui,add,button,% "xs Default gadd_" RegExReplace(a_guicontrol, "\W", "_"),% "Add"
gui,Show,AutoSize,% A_GuiControl
return

Add_Nodule_GGO:
gui,2:Default
gui,Submit
str:=(quantity:=Trim(quantity)) " " size
if size is number
	str.="mm"
str.=" " character " "
if(quantity~="i)a|one|single|solitary")
	str.=lesion
else
	str.=pluralAppend(lesion)

str.=" in " itemsText(lobe)
if(Trim(change)!="")
	str.=", " Trim(change) "."
else 
	str.="."

if !RegExMatch(character, "i)calcified|fat") {
	if (lesion~="i)GGN|GGO|ground glass") || (character~="i)(part(ly)?|sub)-?solid"){
		if (character~="i)(part(ly)?|sub)-?solid"){
			guicontrol,ChooseString,% impnthwnd,PSN
		}else if (noduleType!="PSN"){
			guicontrol,ChooseString,% impnthwnd,GGN
		}
	}
	else if (lesion~="i)nodule|mass|tumor") && (noduleType!="PSN") && (noduleType!="GGN") {
		guicontrol,ChooseString,% impnthwnd,solid
	}
	
	if InStr(size, "<6") || InStr(size, "tiny")
		size:=5
	else if size is not number
		size:=RegExReplace(size, "is)^([\d\.]+).+", "$1")
	if (size>=8)
		guicontrol,ChooseString,% impnshwnd,% "≥8"
	else if(size>=6) && (noduleSz!="≥8")
		guicontrol,ChooseString,% impnshwnd,% "≥6,<8"
	else if(size<6) && (noduleSz!="≥8") && (noduleSz!="≥6,<8")
		guicontrol,ChooseString,% impnshwnd,% "<6"
		
	totalNodCount:=(quantity~="i)a|one|single|solitary")?Floor(totalNodCount)+1 :Floor(totalNodCount)+2 
	if (totalNodCount>1){
		guicontrol,ChooseString,% impmulhwnd,% "Multiple"
	}else if (Multiplicity!="multiple"){
		guicontrol,ChooseString,% impmulhwnd,% "Single"
	}
	settimer,provideSuggestion,-1
}
addLine:
str:=RegExReplace(str, "\s+", " ")
str:=StringUpperFirst(str)
AddReportLine(str, EditHwnd)
changeCategory:
;~ guicontrol,1:choose,Conclusion,% category
return


PFN:
gui,add,ComboBox,% "w200 vquantity",% "A||Multiple"
gui,add,ComboBox,% "w200 vsize hwndnoduleSizehwnd",% "tiny (<6mm)||small (<=10mm)"
gui,add,ComboBox,% "w200 vlesion",% "perifissural nodule||juxtapleural nodule"
gui,add,ComboBox,% "w200 vlocation",% "right minor fissure|right major fissure|left major fissure|bilateral fissures"
gui,add,ComboBox,% "w200 vchange",% "stable|larger|smaller"
gui,add,ComboBox,% "w500 vmorphology",% "the morphology consistent with intrapulmonary lymph node||"

gosub ShowSub
return

Add_PFN:
gui,2:Default
gui,Submit
str:=(quantity:=Trim(quantity)) " " size
if size is number
	str.="mm"
str.=" "
if(quantity~="i)a|one|single|solitary")
	str.=lesion
else
	str.=pluralAppend(lesion)

str.=" at " location
if(Trim(change)!="")
	str.=", " Trim(change)

if(Trim(morphology)!="")
	str.=", " Trim(morphology) "."
else 
	str.="."

if (morphology!="the morphology consistent with intrapulmonary lymph node") && !InStr(morphology,"benign")
	PFN_benign:=false
else
	PFN_benign:=true
settimer,provideSuggestion,-1
gosub addLine
return


Ifxn:
gui,add,ComboBox,% "w200 vlesion",% "tree-in-bud nodules||peribronchial nodules|fibrocalcified lesions"
gui,add,Text,,in
gui,add,ListBox,% "w200 vlobe x+200 ys r11 8 hwndlbhwnd2",% "RUL|LUL|RML|lingular LUL|RLL|LLL|right lung|left lung|bilateral lungs|bilateral upper lungs|bilateral lower lungs"
gosub ShowSub
return

Add_Ifxn:
gui,2:Default
gui,Submit
str:=lesion " in " itemsText(lobe) "."

if(category=1)
	category:=4

gosub addLine
return

Emphysema:
gui,add,ComboBox,% "w400 vlesion",% "Emphysematous change in bilateral lungs||Emphysematous change in bilateral upper lungs"
gui,add,Text,,with
gui,add,ComboBox,% "w200 vadditional",% "apical bullae"
gosub ShowSub
return

Add_Emphysema:
gui,2:Default
gui,Submit
str:=lesion 
if Trim(additional)!=""
	str.= " with " Trim(additional) 
str.="."

if(category=1)
	category:=4 

gosub addLine
return

Cal:
gui,add,Text,,% "Calcification of the"
gui,add,Checkbox,vca1 checked,% "aorta"
gui,add,Checkbox,vca2,% "coronary artery"
gui,add,Checkbox,vca3,% "cardiac valve"
gosub ShowSub
return

Add_Cal:
gui,2:Default
gui,Submit
str:="" 
Loop 3 {
	var:="ca" A_Index
	if !(t:=%var%)
		continue
	GuiControlGet,Text,,% var,Text
	str.=Text ", "
}
if (str="")
	return
str:="Calcification of the " SubStr(RegExReplace(str,"i), ([^,]+), $"," and $1, "),1,-2) "."
addLine2:
str:=RegExReplace(str, "\s+", " ")
str:=StringUpperFirst(str)
AddReportLine(str, EditHwnd2)
gosub changeCategory
return

Thyroid:
gui,add,Checkbox,vth1,% "right"
gui,add,Checkbox,vth2,% "left"
gui,add,Text,,% "thyroid nodule(s)"
gosub ShowSub
return

Add_Thyroid:
gui,2:Default
gui,Submit
str:="" 
if(th1)
	str.=th2?"bilateral ":"right "
else if (th2)
	str.="left "
str.="thyroid nodule" (str="bilateral "?"s":"(s)") "."
gosub addLine2
return

Cyst:
gui,add,ComboBox,vhc w600,% "hypodense lesion(s) in the liver, probably cyst(s).|hypodense lesion(s) in the liver, suggest ultrasound correlation."
gui,add,ComboBox,vrc w600,% "hypodense lesion(s) in the kidney, probably cyst(s).|hypodense lesion(s) in the kidney, suggest ultrasound correlation."
gosub ShowSub
return

Add_Cyst:
gui,2:Default
gui,Submit
str:="",rc:=Trim(rc),hc:=Trim(hc)
if(hc!=""){
	if (replaced:=RegExReplace(hc,"i)liver","!@#$"))=RegExReplace(rc, "i)(left |right |bilateral )?kidney\(?s?\)?","!@#$") {
		RegExMatch(rc, "i)(left |right |bilateral )?kidney(\(?s\)?)?", match)
		,str:=RegExReplace(hc,"i)liver","liver and " match)
		goto addLine2
	}
	str.=StringUpperFirst(hc) " "
}
if(rc!="")
	str.=StringUpperFirst(rc) " "

gosub addLine2
return


AddReportLine(str, EditHwnd){
	static bullet:="- "
	Text:=ControlGetText(EditHwnd)
	if(Trim(Text)="" || RegExMatch(Text, "i)\r?\n$"))
		Edit_SetText(EditHwnd, Text bullet str "`r`n" bullet)
	else if RegExMatch(Text, "i)\r?\n" bullet "$")
		Edit_SetText(EditHwnd, Text str "`r`n" bullet)
	else
		Edit_SetText(EditHwnd, Text "`r`n" bullet str "`r`n" bullet)
	
	Edit_SetSel(EditHwnd,-1,-1)
}

OnExit:
ExitApp

guiclose:
ExitApp

~esc::
if WinActive("ahk_id" guihwnd2)
	WinClose,ahk_id %guihwnd2%
return

StringUpper(str){
	StringUpper,str,str
	return str
}

StringUpperFirst(str){
	return StringUpper(SubStr(str,1,1)) SubStr(str,2)
}

pluralAppend(str){
	if RegExMatch(str, "i)(s|x|z|ch|sh)$")
		return str "es"
	else if RegExMatch(str, "i)([^aeiou])y$")
		return SubStr(str,1,-1) "ies"
	else
		return str "s"
}

getFocused(){
	static GuiThreadInfoSize = 48
	VarSetCapacity(GuiThreadInfo, GuiThreadInfoSize)
	NumPut(GuiThreadInfoSize, GuiThreadInfo, 0)
	DllCall("GetGUIThreadInfo", uint, 0, str, GuiThreadInfo)
	return FocusedHWND := NumGet(GuiThreadInfo, 12)
}

#IfWinActive,ahk_group MyGUI
~*tab::
Sleep 100
focused:=getFocused()
WinGetClass,focusedClass,ahk_id %focused%
if InStr(focusedClass,"Edit")
	Edit_SetSel(focused,-1,-1)
return


#IfWinActive


~r::
~b::
~l::
Critical
if (flagRunning)
	return
if WinActive("ahk_id " guihwnd2) {
	focused:=getFocused()
	;~ WinGetClass,focusedClass,ahk_id %focused%
	if matchHwnd(focused,"lbHwnd"){
		flagRunning:=true
		input,input,I L1 V T1,,u,m,l,n
		candidate:=""
		if (ErrorLevel="match"){
			thisHotkey:=SubStr(A_ThisHotkey,2,1)
			if(thisHotkey="l" && input="m")
				candidate:="lingular LUL"
			else{
				for k,v in LungLobes
					if InStr(v,thisHotkey input)=1 || InStr(v,side[thisHotkey] " " site[input])=1 {
						candidate:=v
						break
					}
			}
		}
		if(candidate!=""){
			GuiControlGet,chosenLobes,,% focused
			if !InStr("|" chosenLobes "|", "|" candidate "|")
				guicontrol,ChooseString,% focused,% candidate
			else {
				guicontrol,choose,% focused,0
				Loop,Parse,chosenLobes,|
					if (A_LoopField!=candidate)
						guicontrol,ChooseString,% focused,% A_LoopField
			}
		}
	}	
}
flagRunning:=false
return

matchHwnd(focused, varName="", hwndArr=""){
	Loop {
		var:=varName A_Index
		if !(hwnd:=%var%)
			break
		if (hwnd=focused)
			return true
	}
	
	if IsObject(hwndArr){
		for k,v in hwndArr
			if(hwnd=v)
				return true
	}
	return false
}

itemsText(str,del="|",newDel=", ",lastAnd=true){
	if (str="")
		return ""
	
	ret:="",Count:=0
	Loop,Parse,str,% Del
	{
		ret.=(lastItem:=A_LoopField) newDel
		Count++
	}
	
	if (lastAnd)
		return (Count>1?SubStr(ret,1,(-1)*StrLen(newDel lastItem newDel)) " and ":"") lastItem
	else
		return SubStr(ret,1,(-1)*StrLen(newDel))
}

getSEIM:
whichMonitor:=whichMonitor("","",monitorInfo)
SEIM[whichMonitor.1]:=getSEIM()
return