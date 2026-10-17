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

categories:=["
(
a) No nodules 
b) definitely benign nodules
eg. calcified nodule, fat-containing nodule, etc.
)","
(
a) ≤ 4 mm solid/part-solid nodule
b) ≤ 5 mm GGO/GGN
c) plate-like GGO / atelectasis
)","
(
a) > 4 mm solid/part-solid nodule
b) > 5 mm GGO/GGN
)","
(
a) benign “non-nodule” lung lesion
b) extrapulmonary lesion
eg. emphysema, mediastinal tumor, adrenal tumor, etc
)","
(
a) part or all of lungs cannot be evaluated
)"]
categoryHint:="若同時符合選項1-4中的一個以上選項，優先順序為 3 > 2 > 4 > 1"

gosub gui

monitorInfo:=monitorInfo()
,SEIM:=[]
settimer,getSEIM,500
return

gui:
category:=""
ToolTip
gui,1:Default
gui,+hwndguiHwnd
GroupAdd,MyGUI,ahk_id %guiHwnd%
gui,Font,s12,Verdana

gui,Add,Text,,Lung findings:
gui,Add,button,gaddFindings,Nodule/GGO
gui,Add,button,x+5 gaddFindings,Ifxn
gui,Add,button,x+5 gaddFindings,Emphysema
gui,add,Edit,% "xs w600 r10 vlungFindings hwndeditHwnd",

gui,add,Text,,Other findings:
gui,add,button,gaddFindings,Cal
gui,add,button,x+5 gaddFindings,Cyst
gui,add,button,x+5 gaddFindings,Thyroid
gui,add,Edit,% "xs w600 r5 vextraFindings hwndedithwnd2",% DefaultExtraFindings:="- No definite mediastinal mass or lymphadenopathy. `r`n- Degenerative change of thoracic spine. `r`n- "

gui,add,Text,,Conclusion:
gui,add,ComboBox,gconclusionChanged hwndconclusionHwnd vconclusion w300,% defaultConclusions:="無異常(Category 1)|無顯著異常(Category 2)|有異常(Category 3)|其他(Category 4)|無法判讀(Category 5)"

gui,add,button,gsubmit,Submit
gui,add,button,greset yp x+50,Reset

gui,Show,AutoSize,LDCT Report

return


conclusionChanged:
SendMessage, 0x147, 0, 0, ,% "ahk_id " conclusionHwnd
ToolTip % hint:=categories[ErrorLevel+1] "`n`n" categoryHint
settimer,ToolTip,-5000
return

ToolTip:
ToolTip
return

Reset:
guicontrol,,lungFindings,% ""
guicontrol,,extraFindings,% DefaultExtraFindings
guicontrol,,Conclusion,% "|" defaultConclusions
return

Submit:
gui,Submit,NoHide
if(conclusion=""){
	MsgBox % "Please select conclusion."
	guicontrol,focus,conclusion
	return
}
	

finalReport:="TECHNIQUE: Low dose CT (LDCT) of the chest without intravenous contrast administration.`r`n`r`nLung findings: `r`n" (lungFindings=""?"- No significant lung abnormality. ":lungFindings) "`r`n`r`nOther findings: (Limited detection of extrapulmonary lesion on LDCT.)`r`n" extraFindings
finalReport:=RegExReplace(finalReport, "(- \r?\n)|(- $)", "")

finalReport:=addAbbr(finalReport)

setReportText(finalReport, conclusion)
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
gui,add,ComboBox,% "w200 vquantity",% "A||Multiple (n>3)"
gui,add,ComboBox,% "w200 vsize",% "tiny (<=4mm)||small (<=10mm)"
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
if (quantity="a" || quantity="one" || quantity="single")
	str.=lesion
else
	str.=pluralAppend(lesion)
str.=" in " itemsText(lobe)
if(Trim(change)!="")
	str.=", " Trim(change) "."
else 
	str.="."

if !RegExMatch(character, "i)calcified|fat") {
	if ((RegExMatch(lesion,"i)nodule|masss|tumor") && size>4) || (RegExMatch(lesion,"i)GG(O|N)") && size>5))
		category:=3
	else
		category:=2
}
addLine:
str:=RegExReplace(str, "\s+", " ")
str:=StringUpperFirst(str)
AddReportLine(str, EditHwnd)
changeCategory:
;~ guicontrol,1:choose,Conclusion,% category
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