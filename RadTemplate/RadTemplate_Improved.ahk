/*
scsnake@gmail.com
*/

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,off
SetBatchLines, -1
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
SetTitleMatchMode,2
SetControlDelay,-1
DetectHiddenWindows,on
ComObjError(false)
;~ #notrayicon
onexit,onexit
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <Class_ScrollGUI>
#include <.NetGetControl>
#Include <Edit>
#include <Monster>
#include <ParseArg>
guiHwndFile:=[]
	,thisPID:=DllCall("GetCurrentProcessId")
gosub checkBoxStyle

gui,1: font,s10,Verdana
Gui,1: -Resize

;~ args:=[".\Procedure\TAVI.txt"]

SplitPath,A_ScriptFullPath,,,,fileNameNoExt
args:=ParseArg()

;~ Loop %0%
;~ if !(%a_index%~="i)" fileNameNoExt ".ahk$") && fileexist(param:=%a_index%)
;~ goto parseInput
;~ MsgBox % exploreobj(args)
;~ MsgBox %0%

if FileExist(param:=args[1])
	goto parseInput

gui,+hwndtemplateListHwnd
templateList:=""
l:=StrLen(A_ScriptDir)+2
loop,% "*.txt",0,1
	if (a_loopfilename!="ReadMe.txt")
		templateList.=SubStr(A_LoopFileLongPath, l) "|"

;~ gui,1: font,s10,Verdana
;~ gui,add,dropdownlist,% "gGoTemplate vchoosen " DropDownSize(templateList,"Verdana",10,30),% templateList
gui,Add,ListView,% "vLS gLV_Click AltSubmit w500 h" A_ScreenHeight-100,Folder|File
LV_ModifyCol(1, 150)
LV_ModifyCol(2, 350)
Loop,parse,templateList,|
{
	RegExMatch(A_LoopField, "s)(.*?)\\?([^\\]+)\.txt", m)
		,LV_Add("", m1, m2)
}

gui,show,autosize,Radiology Template
;~ gosub readTemplate
;~ gosub gui

return

LV_Click:
	if (A_GuiEvent="DoubleClick" & !A_EventInfo){
		LV_GetText(Folder, A_EventInfo, 1)
			,LV_GetText(File, A_EventInfo, 2)
		if FileExist(p:=A_ScriptDir "\" Folder "\" file ".txt"){
			;~ fileread,template,% p
			;~ choosen:=Folder "\" file
			;~ gosub tabToSpaces
			;~ SetTimer,Gui,-1
			if A_IsCompiled
				run % """" A_ScriptFullPath """ """ p """"
			else
				run % """" A_ScriptDir "\" fileNameNoExt ".exe"" """ A_ScriptFullPath """ """ p """"
		}
	}
return

checkBoxStyle:
	iniread,checkedCheckBox,RadTemplate.ini,Settings,checkedCheckBox,■
	iniread,uncheckedCheckbox,RadTemplate.ini,Settings,checkedCheckBox,□
	iniread,checkedRadio,RadTemplate.ini,Settings,checkedCheckBox,●
	iniread,uncheckedRadio,RadTemplate.ini,Settings,checkedCheckBox,○
;~ checkedCheckbox:="■"
;~ uncheckedCheckbox:="□"
;~ checkedRadio:="●"
;~ uncheckedRadio:="○"

;~ checkedCheckbox:="[v]"
;~ uncheckedCheckbox:="[ ]"
;~ checkedRadio:="[v]"
;~ uncheckedRadio:="[ ]"

return

tabToSpaces:
	template:=RegExReplace(template,"\t","    ")
return

parseInput:
	;~ MsgBox % param
	fileread,template,% param
	gosub tabToSpaces
	parsed:=1
	gosub gui
return

GoTemplate:
	if !FileExist(pChoosen:=choosen)
		pChoosen:=choosen:=A_ScriptDir "\" choosen
	gui,submit,nohide
	fileread,template,% a_scriptdir "\" choosen
	gosub tabToSpaces
	if pChoosen!=choosen
		gosub gui
return

readTemplate:
	fileread,template,% a_scriptdir "\CT guided biopsy.txt"
return

gui:
;~ OnMessage(0x115, "OnScroll") ; WM_VSCROLL
;~ OnMessage(0x114, "OnScroll") ; WM_HSCROLL

gui,2:New
gui,2: +hwndtemplateHwnd
; Show ScrollGUI1
guiHwndFile[templateHwnd]:=choosen

;~ if not %0%
;~ gui,2:+Owner1
gui,2: font,s8,Verdana
gui,2: +lastfound
GroupAdd, MyGui, % "ahk_id " templateHwnd
gui,2:default

i:=0,j:=1,match:=pMatch:="",matchArr:=[],matchArr[1,1]:=1,lineLen:=0,lineLenLim:=120

/*
matchArr[n,1] = text start position
matchArr[n,2] = text end position
matchArr[n,3] = control var name
matchArr[n,4] = control type
*/

	,checkBoxCount:=0,radioBoxCount:=0,formArr:=[]
	,generatedCode:="", varName:=[], formula:=[]
while i:=regexmatch(template,"is)\[(.*?)\]|\{(.*?)\}",match,j) {
	RegExMatch(match1?match1:match2,"is)^(?:(c|r)\))?(.*)$",lst)
		,matchArr[a_index,2]:=i-1,list:=match1?lst2:match2,listBox:=match2&&instr(match2,"|")?1:0
		,box:=lst1?1:0
		,whileInd:=a_index
	;~ if instr(match,"tumor > 7")
	;~ tooltip

	;~ RegExMatch(substr(template,j,i-j),"is)^(\r?\n?)(.+?)(\r?\n?)$",mtc)
	;~ RegExMatch(substr(template,j,i-j),"is)^(?: *)([\r\n]*)(.+?)([\r\n]*)$",txt)
	txt:=substr(template,j,i-j)

	gosub textParser

	vars:=[]
	if RegExMatch(list,"is)\/\/(.*)$",m)
		m3:=m1,m1:=substr(list,1,(-1)*strlen(m))
	else
		m3:="",m1:=list

	thisVarName:="%", thisFormula:=""
	if RegExMatch(m3, "\bv(\w+)\b", ma){
		thisVarName:=__escape_for_monster_eval(ma1)
	}

	if RegExMatch(m3, "s)\bv=""([^""]+)""", ma) || RegExMatch(m3, "s)\bv=([^ ]+)", ma){
		thisFormula:=__escape_for_monster_eval(ma1)
	}
	m3:=RegExReplace(m3,"s)\bv\w+\b"," ")
		,m3:=RegExReplace(m3,"s)\bv=""([^""]+)"""," ")
		,m3:=RegExReplace(m3,"s)\bv=([^ ]+)"," ")

	if (box){
		boxArr:=[],boxWidth:=[],matchArr[a_index,4]:=boxType:=(lst1="c"?"checkbox":"radio")

		;~ stringreplace,list,list,||,€,all

		;~ loop,parse,list,€
		;~ {
		;~ boxRow:=a_index
		;~ loop,parse,a_loopfield,|
		;~ {
		;~ boxCol:=a_index
		;~ RegExMatch(a_loopfield,"is)^(.+?)(\/\/(.*))?$",ma)
		;~ boxArr[boxRow,boxCol,2]:=RegExReplace(ma3,"\bv\w+\b"," ")
		;~ if (w:=BoxSize(boxArr[boxRow,boxCol,1]:=ma1,boxType,"Verdana"))>boxWidth[boxCol]
		;~ boxWidth[boxCol]:=w

		;~ }
		;~ }
		stringreplace,list,list,||,€|,all
		;~ loop,parse,list,€
		;~ {
		boxRow:=1
		loop,parse,list,|
		{
			if a_loopfield=
				continue
			boxCol:=a_index
			RegExMatch(a_loopfield,"is)^(.+?)(\/\/(.*))?$",ma)
			if substr(ma1,0,1)="€"
				ma1:=substr(ma1,1,-1),ma3:=instr(ma3,"i) checked|checked ")?ma3:(ma3 " checked"),ma3:=RegExReplace(ma3,"unchecked")
			boxArr[boxRow,boxCol,2]:=RegExReplace(ma3,"\bv\w+\b"," ")
			if (w:=BoxSize(boxArr[boxRow,boxCol,1]:=ma1,boxType,"Verdana"))>boxWidth[boxCol]
				boxWidth[boxCol]:=w

		}
		;~ }
		outer_index:=a_index
		;~ regexmatch(,"\bw(\d+)\b",boxW)
		if (boxType="checkbox"){

			for k,v in boxArr
				for x,y in v {
					if regexmatch(txt,"[\r\n]$") || (whileInd=1 && txt="")
						s:="xm",lineLen:=len
					else
						s:="x+5", lineLen+=len
					try{
						gui,add,checkbox,% "vcb" ++checkBoxCount " " s " " y.2 ((lineLen+(len:=strlen(y.1)+5)>linelenlim)?" w" w:""),% y.1
						generatedCode.="gui,add,checkbox,vcb " checkBoxCount " " s " " y.2 "," y.1 "`n"
						varName[thisVarName="%"? "%cb" checkBoxCount:thisVarName]:={var: "cb" checkBoxCount, formula: thisFormula}
					}catch e
						MsgBox, 16,, % "Exception thrown!`n`nwhat: " e.what "`nfile: " e.file
							. "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
					matchArr[outer_index,3].="cb" checkBoxCount ","

					;~ if (lineLen+(len:=strlen(y.1)+5)>linelenlim) || regexmatch(txt,"[\r\n]$") || (whileInd=1 && txt="")
					;~ s:="xm",lineLen:=len
					;~ else
					;~ s:="x+5", lineLen+=len
					;~ try{
					;~ gui,add,checkbox,% "vcb" ++checkBoxCount " " s " " y.2,% y.1
					;~ generatedCode.="gui,add,checkbox,vcb " checkBoxCount " " s " " y.2 "," y.1 "`n"
					;~ varName[thisVarName="%"? "%cb" checkBoxCount:thisVarName]:={var: "cb" checkBoxCount, formula: thisFormula}
					;~ }catch e
					;~ MsgBox, 16,, % "Exception thrown!`n`nwhat: " e.what "`nfile: " e.file
					;~ . "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
					;~ matchArr[outer_index,3].="cb" checkBoxCount ","
				}
			;~ vars.push(
		}else{
			for k,v in boxArr
				for x,y in v {
					if (lineLen+(len:=strlen(y.1)+5)>linelenlim) || regexmatch(txt,"[\r\n]$") || (whileInd=1 && txt="")
						s:="xm",lineLen:=len
					else
						s:="x+5", lineLen+=len
					try{
						gui,add,radio,% ("vrb" ++radioBoxCount " " (x=1?"group":"") " ") " " s " " y.2 " gradioClick",% y.1
						generatedCode.="gui,add,radio," ("vrb" radioBoxCount " " (x=1?"group":"") " ") " " s " " y.2 " gradioClick," y.1 "`n"
						if (thisVarName!="")
							varName[thisVarName="%"?"%rb" radioBoxCount :thisVarName]:={var: "rb" radioBoxCount, formula: thisFormula}
					}catch e
						MsgBox, 16,, % "Exception thrown!`n`nwhat: " e.what "`nfile: " e.file
							. "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
					matchArr[outer_index,3].="rb" radioBoxCount ","
				}

		}
	}else if instr(m1,"|") {
		max:=0
		loop,parse,m1,|
			if strlen(a_loopfield)>max
				max:=strlen(a_loopfield)
					,maxStr:=a_loopfield
		(s:=regexmatch(txt,"[\r\n]$")?"xm":"x+5") ,t:=m1
		if RegExMatch(m3,"i)^(\W\&?|nl) ?", delmt) {
			m3:=RegExReplace(m3, "i)^(\W\&?|nl) ?", "")
			,matchArr[A_Index,5]:=delmt1
		}
		m3.=" " maxWidth(lineLen,maxStr)
		,matchArr[a_index,4]:=boxType:=listBox?"listbox":"combobox"
		,matchArr[a_index,3]:="var" a_index

		if (lineLen+max>linelenlim){
			try{
				gui,add,% boxType,% "vvar" a_index " " "xm" " " m3 " 0x8",% t
				generatedCode.="gui,add," boxType ",vvar " a_index  " xm " m3 " 0x8," t "`n"
				if (thisVarName!="")
					varName[thisVarName="%"?"%var" A_Index :thisVarName]:={var: "var" A_Index, formula: thisFormula}
			}catch e
						MsgBox, 16,, % "Exception thrown!`n`nwhat: " e.what "`nfile: " e.file
							. "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
			lineLen:=max

		}else{
			try{
				gui,add,% boxType,% "vvar" a_index " " s " " m3 " 0x8",% t
				generatedCode.="gui,add," boxType ",vvar " a_index  " xm " m3 " 0x8," t "`n"
				if (thisVarName!="")
					varName[thisVarName="%"?"%var" A_Index :thisVarName]:={var: "var" A_Index, formula: thisFormula}
			}catch e
						MsgBox, 16,, % "Exception thrown!`n`nwhat: " e.what "`nfile: " e.file
							. "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
			lineLen+=max
		}

	}else{
		(s:=regexmatch(txt,"[\r\n]$")?"xm":"x+5") ,t:=RegExReplace(m1,"^[\r\n]+")
		,m3.=regexmatch(m3,"i)w\d+")?" ":" " (t=""?"w100":maxWidth(lineLen,t))
		,matchArr[a_index,4]:="edit"
		,matchArr[a_index,3]:="var" a_index
		;~ y:=matchArr[a_index-1,4]="edit"&&txt=""?"yp":"yp+3"
		;~ y2:=y="yp"?"yp":"yp+3"

		if (lineLen+strlen(t)>linelenlim){
			try {
				gui,add,text,% "xm",% " "
				gui,add,edit,% "vvar" a_index " " " yp-3 " " " m3,% t
				gui,add,text,% "x+0 w0 yp+3",% " "
				generatedCode.="gui,add,text,xm,% "" ""`ngui,add,edit,vvar" a_index " yp-3 " m3 "," t "`ngui,add,text,x+0 w0 yp+3,% "" ""`n"
				if (thisVarName!="")
					varName[thisVarName="%"? "%var" A_Index:thisVarName]:={var: "var" A_Index, formula: thisFormula}
			}catch e
						MsgBox, 16,, % "Exception thrown!`n`nwhat: " e.what "`nfile: " e.file
							. "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
			lineLen:=strlen(t)
		}else{
			try {
				if(s="xm"){
					gui,Add,text,% "xm w0",% " "
					generatedCode.="gui,add,text,xm w0,% "" """
				}
				gui,add,edit,% "vvar" a_index " " (s="xm"?"":s) " yp-3 " m3,% t
				gui,add,text,% "x+0 w0 yp+3",% " "
				generatedCode.="gui,add,edit,vvar" a_index " " (s="xm"?"":s) " yp-3 " m3 "," t "`ngui,add,text,x+0 w0 yp+3,% "" ""`n"
				if (thisVarName!="")
					varName[thisVarName="%"?"%var" A_Index :thisVarName]:={var: "var" A_Index, formula: thisFormula}
			}catch e
						MsgBox, 16,, % "Exception thrown!`n`nwhat: " e.what "`nfile: " e.file
							. "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
			lineLen+=strlen(t)
		}
		;~ gui,add,edit,% "vvar" a_index " " (regexmatch(txt3,"[\r\n]")?"xm":"x+5") " " m3,% RegExReplace(m1,"^[\s\r\n]+")
	}
	matchArr[a_index+1,1]:=j:=i+strlen(match)
}
matchArr[matchArr.maxIndex(),2]:=strlen(template)
;~ lastTxt:=substr(template,j)
;~ gui,add,text,% lineLen+strlen(lastTxt)>linelenlim?"":"x+5",% substr(template,j)
txt:=substr(template,j)
gosub textParser

;~ gui,show,autosize,% RegExReplace(choosen,"\.\w+$","")
Global SG1 := New ScrollGUI(templateHwnd, 0, a_screenheight-260, "+Resize +Label2GUI",3,4)
if parsed
{
	filePath:=args[1]
	splitpath,filePath,choosen
}
guiTitle:=RegExReplace(choosen,"\.\w+$","")
,SG1.Show(guiTitle, "y0 autosize")
hParent := SG1.HWND
Gui, %hParent%:Default
Gui, Font, s10, Verdana
Gui, Add, Button, gSubmit x20 y+20 w120 h40, To Clipboard
Gui, Add, Button, gSubmitRis x+20 w120 h40, To RIS
Gui, Add, Button, gReset x+40 w120 h40, Reset
GroupAdd,MyGui,% "ahk_id " sg1.hwnd
gosub fillExamDate
gosub parseFormula
return

Reset:
;~ winget,activeHwnd,id,A
MsgBox, 52, Reset ,Are you sure?
IfMsgBox,Yes
{

	;~ MsgBox % exploreobj(args)
	if A_IsCompiled
		run % """" RegExReplace(A_ScriptFullPath, "i).ahk$", ".exe") """ """ args[1] """"
	else
		run % """" RegExReplace(A_ScriptFullPath, "i).ahk$", ".exe") """ """ RegExReplace(A_ScriptFullPath, "i).exe$", ".ahk") """ """ args[1] """"
	ExitApp
	;~ if guiHwndFile.haskey(activeHwnd) {
	;~ pChoosen:=choosen:=A_ScriptDir "\" choosen
	;~ fileread,template,% a_scriptdir "\" choosen
	;~ gosub tabToSpaces
	;~ WinKill,ahk_id %activeHwnd%
	;~ gosub gui
	;~ }

}
return

parseFormula:
AllFormula:={}
,updateVars:=[]
for k,v in varName
	if (v.formula!=""){
		f:=v.formula
		for x,y in varName
			if !InStr(x,"%") && RegExMatch(f, "\b" x "\b")
				f:=RegExReplace(f, "\b" x "\b", y.var)
				,updateVars.push(y.var)
		AllFormula[v.var]:=f
	}
;~ SetTimer,updateFormulaCell,% AllFormula.SetCapacity(0)>0?1000:"off"

Hotkey,IfWinActive,ahk_group MyGui
for k,v in ["tab", "Lbutton", "Rbutton", "Mbutton", "WheelUp", "WheelDown"]
	Hotkey,% "~*" v,updateFormulaTimer,% AllFormula.SetCapacity(0)>0?"ON":"OFF"
Hotkey,IfWinActive

return

updateFormulaTimer:
SetTimer,updateFormulaCell,-500
return

updateFormulaCell:
for k,v in updateVars
	GuiControlGet,%v%,2:
;~ gui,2:submit,NoHide
for k,v in AllFormula {
	f:=v
	,val:=""
	for x,y in updateVars
		if RegExMatch(f, "\b" y "\b")
			if (%y%=""){
				f:=""
				break
			}else if (f=y){
				val:=%y%
				break
			}else
				f:=RegExReplace(f, "\b" y "\b", %y%)
	if val=
		val:=f=""?"":Eval(f)
	;~ GuiControlGet,fo,2:FocusV
	if (SubStr(%k%,1,1)!="'" && val!=%k%){
		GuiControl,2: ,%k%,% val
		GuiControlGet,h,2:hwnd,%k%
		%k%:=val
		,Edit_SetSel(h, 0, -1)
		,Edit_SetSel(h, -1, -1)
	}
}
return

textParser:
	loop,parse,txt,`n
	{
		t:=RegExReplace(A_LoopField,"\r")
		parseInd:=a_index,startPoint:=1
		loop {
			if(parseInd=1 && a_index=1)
				t1:=substr(t,startPoint,linelenlim-linelen),len:=strlen(t1),startPoint:=linelenlim-linelen+1
			else
				t1:=substr(t,startPoint,linelenlim),len:=strlen(t1),startPoint+=linelenlim+1

			if (len){
				if(parseInd=1 && a_index=1){
					try {
						gui,add,text,% "x+5",% t1
						generatedCode.="gui,add,text,x+5,% """ t1 """`n"
					}
					linelen+=len
				}else{
					try {
						gui,add,text,% "xm",% t1
						generatedCode.="gui,add,text,xm,% """ t1 """`n"
					}
					lineLen:=len
				}
			}else
				break

		}

	}
return

radioClick:
if(A_guievent="DoubleClick"){
	guicontrol,,% a_guicontrol,0
}
return

fillExamDate:
examDate:=""
if instr(substr(template,1,matchArr[1,2]),"date") {
	if hwnd:=getNetControl2(RisOpened()[2],"","EXAM_DATE_TIME","檢查日期","WindowsForms10.EDIT")[1]
		examDate:=controlgettext(hwnd)
}
if RegExMatch(examDate,"(\d{4})\/(\d\d)\/(\d\d) \d\d:\d\d:\d\d",match) {
	controlsettext,Edit1,% match1,% "ahk_id " templateHwnd
	controlsettext,Edit2,% match2,% "ahk_id " templateHwnd
	controlsettext,Edit3,% match3,% "ahk_id " templateHwnd
}
return

2GUISize:
SG1.adjusttoparent()
return

submit:
gui,submit,nohide
if ((len:=matchArr.maxIndex())<1){
	clipboard:=template
	return
}
var%len%:=""
export:=""

for k,v in matchArr {
	;~ test:=var%k%
	;~ if instr(test,"supine")
	;~ tooltip

	if (v.4="checkbox"){
		tempStr:="",tempVar:=v.3
		loop,parse,tempVar,`,
			if (a_loopfield!=""){
				guicontrolget,tempCbVar,,% a_loopfield
				guicontrolget,tempCbText,,% a_loopfield,text
				tempStr.=(tempCbVar?checkedCheckbox:uncheckedCheckbox) tempCbText " "
			}
		export:=conc(export,substr(template,v.1,v.2-v.1+1),tempStr)
	}else if (v.4="radio"){
		tempStr:="",tempVar:=v.3
		loop,parse,tempVar,`,
			if (a_loopfield!=""){
				guicontrolget,tempRbVar,,% a_loopfield
				guicontrolget,tempRbText,,% a_loopfield,text
				tempStr.=(tempRbVar?checkedRadio:uncheckedRadio) tempRbText " "
			}
		export.=conc(substr(template,v.1,v.2-v.1+1),tempStr)
	}else if (v.4="listbox"){
		tempStr:="",tempVar:=var%k%
		,usingAnd:=InStr(v.5, "&")?1:0
		,delmtSetting:=RegExReplace(v.5, "\&", "")
		,delmt:=InStr(delmtSetting, "nl")?"`n":RegExMatch(delmtSetting, "\W", match)?match:", "
		loop,parse,tempVar,|
			tempStr.=((seg:=a_loopfield) delmt " ")
		if(usingAnd)
			tempStr:=SubStr(tempStr, 1, (-1)*StrLen(delmt " " seg delmt " ")) " and " seg
		else
			tempStr:=SubStr(tempStr, 1, (-1)*StrLen(delmt " "))
		export:=conc(export,substr(template,v.1,v.2-v.1+1),regexreplace(tempStr,"\n$",""))
	}else{
		export:=conc(export,substr(template,v.1,v.2-v.1+1), RegExReplace(var%k%, "^\'", ""))
	}

}
export:=RegExReplace(export,"≤","≦")
export:=RegExReplace(export,"≥","≧")
clipboard:=export
tooltip,Copied!
settimer,tooltip,-2000
return

maxWidth(lineLen,maxStr){
	global linelenlim
	;~ if maxStr=
	;~ tooltip
	max:=strlen(maxStr)
	if(lineLen+max>linelenlim){
		return maxWidth:=dropdownsize(substr(maxStr,1,maxStrlen:=linelenlim-lineLen),"Verdana",8,30)
	}else{
		return maxWidth:=dropdownsize(maxStr,"Verdana",8,30)
	}
}

conc(param*){
	a:=b:=""
	for k,b in param {
		a.=b

		;~ m1:=substr(a,0,1)
		;~ n1:=substr(b,1,1)

		;~ if regexmatch(m1 n1,"\w[\w\(\[\{]")
		;~ a.= b
		;~ else if m1 in `,,;,.,!,?,),:,
		;~ a.=" " b
		;~ else
		;~ a.=b
	}
	return a
}

submitRis:
gosub submit
if (RisOpened()[1]!=2){
    tooltip,Copied!
    settimer,tooltip,-1000
	return
}
RegExMatch(export,"is)^(.*?)[\s\r\n]*(?:Impression\W*(.*))?$",match)
ris:=getRisReports(RisOpened()[2])
controlsettext,,% rep:=controlgettext(ris[1,1]) LineBreakConvert(match1),% "ahk_id " ris[1,1]
controlsettext,Edit1,% rep,simple RIS ahk_class AutoHotkeyGUI
controlget,editHwnd,hwnd,,Scintilla1,simple RIS ahk_class AutoHotkeyGUI
Edit_SetText(editHwnd,tmp:=rep)
controlsettext,,% LineBreakConvert(match2),% "ahk_id " ris[1,2]
winactivate,% "ahk_id " RisOpened()[2]
return

tooltip:
ToolTip
return

~esc::
if (a_priorhotkey=a_thishotkey && a_timesincepriorhotkey<500){
	if %0%
		goto guiclose
	else if winactive("ahk_id " templateHwnd){
		msgbox,4,,Close template?
		ifmsgbox,yes
			sg1.destroy()
	}else
		goto guiclose
}
return
;~ !q::
gui1close:
2guiclose:
if %0%
{
	goto guiclose
}else{
	sg1.destroy()
}
return
guiclose:
;~ MsgBox % WinExist("RadTemplateCloseAll")
if WinExist("RadTemplateCloseAll")
	ExitApp
if GetKeyState("SHIFT")
	goto Closeall2
i:=0
for k,v in processList()
	if (v.name ="RadTemplate.exe")
		i++
if(i=1 && WinExist("ahk_id " templateListhwnd))
	ExitApp
MsgBox, 4, ,% "Quit?"  (i=1?"":" `n`n (Hold SHIFT to quit all)")
ifmsgbox,yes
{

	if GetKeyState("SHIFT"){
		gosub Closeall2

	}
	exitapp
}

return

Closeall2:
gui,CloseAll:new,+ToolWindow
gui,Closeall:Show,x-1 y-1 w1 h1 NA,RadTemplateCloseAll

RadTemplateExe:=[]
for k,v in processList() {
	if(v.name="RadTemplate.exe")
		RadTemplateExe.push(v)
	if(v.pid = thisPID){
		trueMainExePath:=v.path
	}
}

for k,v in RadTemplateExe {
	if(v.path = trueMainExePath && v.pid!=thisPID)
		run,% "taskkill /F /PID " v.pid,,Hide
}
ExitApp
return

onexit:
ExitApp
return

DropDownSize(List, Font:="", FontSize:=10, Padding:=30)
{
	x:=0
	Loop, Parse, List, |
	{
		if Font
			Gui DropDownSize:Font, s%FontSize%, %Font%
		Gui DropDownSize:Add, Text, R1, %A_LoopField%
		GuiControlGet T, DropDownSize:Pos, Static1
		Gui DropDownSize:Destroy
		TW > X ? X := TW :
	}
	return "w" X + Padding
}
BoxSize(text,boxType, Font:="", FontSize:=10, Padding:=0)
{

		if Font
			Gui BoxSize:Font, s%FontSize%, %Font%
		Gui BoxSize:Add, % boxType,,% text
		GuiControlGet,T, BoxSize:Pos, Button1
		Gui BoxSize:Destroy
		return TW+Padding
}

;~ GuiSize:
;~ UpdateScrollBars(A_Gui, A_GuiWidth, A_GuiHeight)
;~ return
