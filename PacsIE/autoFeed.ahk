#MaxMem 4095
SetTitleMatchMode,2
SetBatchLines,-1
SetControlDelay,-1
ComObjError(false)
DetectHiddenWindows,on
DetectHiddenText,on
#persistent
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <risimpax>
;~ #include <winvisible>
;~ #include <WM_COPYDATA>
#SingleInstance,Off
#include <CryptFileRead>
#include <portallib>
#Include %A_ScriptDir%
#include jpegDirName.ahk
#InstallKeybdHook

args:=[]
Loop %0%
	args.push(%a_index%)	

;~ exploreobj(args)

if CryptFilePW()
	ExitApp

try
	Menu,tray,icon,% A_ScriptDir "\F.ico"


makeMainGui("autoFeed_main")

onexit,onexit
sid:=askforportalidpw()
;~ Spaces:=[32,160,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8287,12288]
Spaces:=[32,12288]
,cxrRE := "i)^Chest"
,abdRE:="i)^Abdomen"
,spineRE:="i)spine"
,reportdir:=a_mydocuments "\feedRIS"
,OnMessage(0x1012, "to_exit")

if !InStr(FileExist(reportdir), "D")
	filecreatedir,% reportdir
if !InStr(FileExist(reportdir "\saved"), "D")
	filecreatedir,% reportdir "\saved"

if(args.length()=0){
	gui,mainWin:new,+hwndguihwnd -Caption -Resize
	gui,Font,s12,Verdana
	for k,v in (AllRis:=RisOpened(true)[2]) {
		title:=""
		WinGetTitle,title,ahk_id %v%
		trygetchartNo:=getRisChartNo(v,false)
		gui,Add,Checkbox,% (trygetchartNo?"checked":"") " vcb" k,% RegExReplace(title, "s)-.+$", "") " " trygetchartNo " " getRisAccNo(v,false)
	}
	gui,Add,button,gselectRis Default,GO!
	gui,Show,Center,Select RIS
}else
	gosub selectRis

;~ gosub,RisState
return

selectRis:
;~ if turboMode:=GetKeyState("shift")
	;~ MsgBox,,,Turbo Mode!,1
turboMode:=true
if(args.length()=0)
gui,mainWin:Submit
else
	AllRis:=args
selectedRis:=[]
allhwnds:=""
for k,v in AllRis {
	if(args.length()=0) {
		
	
	var:="cb" k
	,var:=%var%
	if !var
		continue
	}
	tmp:=[]
	,tmp.rishwnd:=v
	,allhwnds.=v " "
	,tmp.RisReports:=getRisReports(v)
	,tmp.RisAccNoHwnd:=getRisAccNoHwnd(v, false)
	tmp.ChartNoHwnd:=getRisChartNoHwnd(v, false)
	,tmp.sendButtonHwnd:=saveMode?getNetControl2(v,"暫存","cmdRunSave","暫存","WindowsForms10.BUTTON.app","","","",0)[1]:getNetControl2(v,"存檔發送","cmdRunVerifySend","存檔發送","WindowsForms10.BUTTON.app","","","",0)[1]
	,tmp.nextButtonHwnd:=getNetControl2(v,"下筆","cmdRunNext","下筆","WindowsForms10.BUTTON.app","","","",0)[1]
	,tmp.RisHxHwnd:=getRisHistory(v, false)
	;~ ,tmp.lastSendTick:=0
	,tmp.paccno:=""
	,tmp.failedAccNos:={}
	
	
	,chkPlainfilm:=getNetAcc(v,"chkQueryHis","WindowsForms10.BUTTON.app")
	if (chkPlainFilm.accState!=1048592)
		chkPlainFilm.accDoDefaultAction()
		;~ ,tmp.originalChkPlainfilmState:=1
	
	selectedRis.push(tmp)
	WinHide,ahk_id %v%
}
reportedAccNo:=[]
,selectedRisInd:=0
,ClosedRis:=[]
SetTimer,riserror,500
SetTimer,feed,-100
SetTimer,re_run,-600000
return

re_run:
re_run:=true
return

rerunning:
run,% "autofeed.exe autofeed.ahk " allhwnds
ExitApp
return

feed:
if to_exit
	ExitApp
if re_run
	goto rerunning
;~ MsgBox %  selectedRis.length()
if (ClosedRis.Count() = selectedRis.length()){
	exitapp
}

if(++selectedRisInd>selectedRis.length())
	selectedRisInd:=1
;~ lastHwnd:=risHwnd

if DllCall("IsHungAppWindow", "ptr", selectedRis[selectedRisInd].risHwnd) {
	SetTimer,feed,-100
	return
	
}
for k,var in (thisRis:=selectedRis[selectedRisInd])
	%k%:=var

if ClosedRis.haskey(risHwnd) || !WinExist("ahk_id " rishwnd) || !WinExist("ahk_id " RisAccNoHwnd) {
	ClosedRis[risHwnd]:=1
	SetTimer,feed,-100
	return
}

accno:=ControlGetText(RisAccNoHwnd)

if(reportedAccNo.haskey(accNo) || getRisStudyStatus(risHwnd)="已發報告"){
	acc_objectfromwindow(nextbuttonhwnd).accDoDefaultAction()
	selectedRis[selectedRisInd].paccno:=accno
	SetTimer,feed,-100
	return
}

while ((accno:=ControlGetText(RisAccNoHwnd))= paccno) {
	Sleep 100
	if to_exit
		ExitApp
	if (A_Index>40 || (selectedRis.length()>3 && A_Index >5)) {
		;~ if  !IsObject(selectedRis[selectedRisInd].failedAccNos)
			;~ selectedRis[selectedRisInd]["failedAccNos"]:=[]
		if !(selectedRis[selectedRisInd].failedAccNos.haskey(accNo))
			selectedRis[selectedRisInd].failedAccNos[accNo]:=0
		if (++selectedRis[selectedRisInd].failedAccNos[accNo]>2){
			acc_objectfromwindow(nextbuttonhwnd).accDoDefaultAction()
			selectedRis[selectedRisInd].paccno:=accno
	
		}
		
		SetTimer,feed,-100
		return
	}
}
chartNo:=ControlGetText(ChartNoHwnd)
;~ chartNo:=getRisChartNo(risHwnd)




if (newFindings:=getExistedReport(accNo, chartNo))="" {


examName:=trim(parseRisExamItems(getRisExamItems(risHwnd))[1,1])
,examDate:=SubStr(RegExReplace(getRisExamDate(risHwnd), "\D", ""),1,8)


,examType:=""
for k,v in ["cxrRE", "abdRE", "spineRE"]
	if RegExMatch(examName, %v%){
		re:=%v%
		,examType:=SubStr(v,1,-2)
		break
	}
if(examType="" || DateDiff(examDate, SubStr(a_now,1,8))<30){
	acc_objectfromwindow(nextbuttonhwnd).accDoDefaultAction()
	selectedRis[selectedRisInd].paccno:=accno
	SetTimer,feed,-100
	return
}

RisHxAcc:=acc_ObjectFromWindow(RisHxHwnd)
,RisHxAccChildren:=""
;~ tooltip % RisHxAcc.accChildCount



if(!turboMode && RisHxAcc.accChildCount>2){
	
;~ risHx:=parseDataGrid2(RisHxHwnd, risHwnd, acc_children(RisHxAcc),log(RisHxAcc.accChildCount)*0.5,0,1,1,0,0,1)
parseDataGrid(RisHxAccChildren:=acc_children(RisHxAcc), risHx:=[], 1)
,risHx:=new DataGridTable(risHx)

,examDateCol:=risHx.colNos["ExamDate"]
,examVSCol:=risHx.colNos["報告醫師"]
,examNameCol:=risHx.colNos["ExamName"]
,accNoCol:=risHx.colNos["AccNo"]
,ReportIdxCol:=risHx.colNos["報告序號"]
;~ ,ageCol:=risHx.colNos["年齡"]

,foundAfter:=foundBefore:=0
,foundAfterDate:=foundBeforeDate:=""
for k,v in risHx {
	oldExamDate := RegExReplace(v[examDateCol], "\D", "")
	,oldExamVS:=Trim(v[examVSCol])
	,oldExamName:=Trim(v[examNameCol])
	,reportIdx:=Trim(v[ReportIdxCol])
	;~ ,oldAccNo:=v[accNoCol]
	
	if(RegExMatch(oldExamName, re) && !(oldExamVS~="陳醫師|YCH")  && reportIdx!=""){
		if (oldExamDate>=examDate) 
			foundAfter:=k
			,foundAfterDate:=oldExamDate
		else {
			foundBefore:=k
			,foundBeforeDate:=oldExamDate
			break
		}
			
	}

select_k:=0
	
	if(foundAfter && foundBefore){
	now:=SubStr(a_now,1,8)
	if(DateDiff(foundAfterDate, now) <= DateDiff(foundBeforeDate, now))
		select_k := foundAfter
	else
		select_k:=foundBefore
}else if (foundAfter){
	select_k:=foundAfter
}else if (foundBefore){
	select_k:=foundBefore
}

}

	
}else
	select_k:=0



if (select_k){
	if(RisHxAccChildren)
		RisHxAcc:=RisHxAccChildren
	else
		RisHxAcc:=acc_children(acc_objectfromwindow(RisHxHwnd))
	RisHxAcc[select_k].accSelect(comobj(3,3),0)
	Sleep 500
	oldFindings:=ControlGetText(RisReports[2,1])
	,oldFindings:=RegExReplace(oldFindings, "s)^.+?FINDINGS:\s+", "")
	,oldFindings:=RegExReplace(oldFindings, "is)^.+?show\w?\w?\s*", "")
}else{
	

	if  InStr(examName, "Abdomen") 
		oldFindings:="Non-specific bowel gas. "
	else if  InStr(examName, "Chest") {
		if InStr(examName, "AP"){
			tmp:=["Lung consolidation. "
				, "Hazy opacities of lung. "
				, "Increased hazy opacities of lung. "]
			Random,r,1,% tmp.maxindex()
			oldFindings:=tmp[r]
		}else {
			tmp:=["Increased hazy densities of lung. "
				, "Ill-defined opacities of lung. "
				, "Increased infiltration in the perihilar region. "
				, "Increased infiltrations of lung. "
				, "Increased vascular markings of lung. "
				, "Prominent lung markings. "
				, "Increased interstitial infiltrations of lung. "
				, "Prominent vascular lung markings. "
				, "Increased vascular lung markings with perivascular infiltrations. "]
			Random,r,1,% tmp.maxindex()
			oldFindings:=tmp[r]
			Random,r,1,2
			if (r>1)
				oldFindings:=RegExReplace(oldFindings, "of lung", "of the lung")
				
		}
	}else if  InStr(examName, "spine"){
		age:=getRisPtAge(risHwnd)
		,oldFindings:=age>45?"Degenerative change. ":"Normal alignment. "
	} 
		
}

FormatTime,today,% a_now,yyyy/MM/dd
newFindings:="Accession Number: " accno "`r`nChart Number: " chartno "`r`nExamination Date: " examDate "`r`nExamination Name: " examName "`r`nFindings: `r`n" oldFindings "This study is reassigned to current radiologist on " today ". "

}
newFindings:=RegExReplace(newFindings, "i)This study is reassigned to([^\.]+).", "This study is not reported for months and reassigned to$1 for a brief summary of major finding(s). ")
AddSpaces(newFindings)


setReportText(newFindings,"　.",RisReports,1,1,1,0)
;~ WinShow,% "ahk_id " risHwnd
risSendReport(risHwnd)
,selectedRis[selectedRisInd].paccno:=accno
,reportedAccNo[accno]:=1
,acc_chartNo:=__CryptStr(accNo " " chartNo,____)
filemove,% reportdir "\" accNo " " chartNo ".txt",% reportdir "\saved\" acc_chartNo ".txt" ,1
filemove,% reportdir "\" acc_chartNo ".txt",% reportdir "\saved\" acc_chartNo ".txt" ,1
if (acc_chartNo!="")
	FileRemoveDir,% reportdir "\" acc_chartNo,1
if (thisAccNo!="" && thisChartNo!="")
	FileRemoveDir,% reportdir "\" AccNo " " ChartNo,1
if WinExist("ahk_exe autorun.exe")
	TrayTip,, % "RIS #" selectedRisInd ": " accno " sent!",2
if to_exit
	ExitApp
SetTimer,feed,-100
return 

getExistedReport(accNo, chartNo){
	global reportdir, RisState, ____, cxrRE ,abdRE,spineRE, to_exit
	if to_exit
		ExitApp

	if  !FileExistValid(reportPath:=reportdir "\" accNo " "  chartNo ".txt") &&  !FileExistValid(reportPath:=reportdir "\" __CryptStr(accNo " "  chartNo,____) ".txt")
		return 
	FileGetSize,fs,% reportPath
	if (fs<=6)
		return
	
	FileGetAttrib,attr,% reportPath
	if InStr(attr, "H")
		return 
	
	fileread,contents,% reportPath
	if !InStr(contents,"Chart")
		contents:=__CryptStr(contents, ____, 0)
	if InStr(contents, "(N/A)"){
		FileSetAttrib,+H,% reportPath
		return
	}
		
	
	if RegExMatch(contents,"s)(.*)\r?\n-=-=-=-=-\r?\n(.*)",match) && !(match1="" && match2="")
		newFindings:=match1
	
	RegExMatch(contents, "EXAMINATION: ([^\r\n]+)", examName)
	
	if(Trim(match1)~="i)^Normal.|\nNormal."){
		if (examName1~=cxrRE) || (examName1~=abdRE) || (examName1~=spineRE) {
			return ""
		}
	}else if (Trim(match1)~="i)Normal.$")
		match1:=RegExReplace(Trim(match1), "i)Normal.$", "")
	
	
	if (examName1~="i)spine") && (match1~="i)\nfracture")
		newFindings:=RegExReplace(match1, "i)(^|\r?\n)fracture", "$1Compression fracture")
	else if (examName1~="^Neck") && (match1~="i)\nNo obvious displaced fracture")
		newFindings:=RegExReplace(match1, "i)(^|\r?\n)No obvious displaced fracture.[^\r\n]+(this study is reas[^\r\n]+)", "$1No abnormal prevertebral soft tissue swelling.$2")
	return newFindings
}



ToolTip:
ToolTip
return

DateDiff(Start, End, unit="days")
{
    Diff := End
    Diff -= Start, %unit%
    
    return Abs(Diff)
}

;~ risState:
;~ RisState:=RisOpened()
;~ ,RisReports:=getRisReports(RisState[2])
;~ ,RisAccNoHwnd:=getRisAccNoHwnd(RisState[2])
;~ ,ChartNoHwnd:=getRisChartNoHwnd(RisState[2])
;~ ,sendButtonHwnd:=saveMode?getNetControl2(RisState[2],"暫存","cmdRunSave","暫存","WindowsForms10.BUTTON.app","","","",0)[1]:getNetControl2(RisState[2],"存檔發送","cmdRunVerifySend","存檔發送","WindowsForms10.BUTTON.app","","","",0)[1]
;~ ,nextButtonHwnd:=getNetControl2(RisState[2],"下筆","cmdRunNext","下筆","WindowsForms10.BUTTON.app","","","",0)[1]
;~ ,RisHxHwnd:=getRisHistory(RisState[2])

;~ return

riserror:
;~ if !WinExist("ahk_id " RisState[2])
	;~ ExitApp
IfWinExist,kReport ahk_class #32770,because it is being used by another process.
	WinClose,kReport ahk_class #32770,because it is being used by another process.
IfWinExist,kReport ahk_class #32770,請重新查詢
{
	WinClose,kReport ahk_class #32770,請重新查詢
	ExitApp
}
	
ifwinexist,kReport ahk_exe Menu.exe,% "已無任何待判讀"
{
	winget,pid,pid,kReport ahk_exe Menu.exe,% "已無任何待判讀"
	controlclick,Button1
	process,close,%pid%
	;~ winshow,% "ahk_id " RisState[2]
	;~ winset,enable,,% "ahk_id " RisState[2]
	;~ winactivate,% "ahk_id " RisState[2]

}
ifwinexist,kReport ahk_exe Menu.exe,報告內容已修改, 是否確定存檔
	controlclick,Button2
ifwinexist,ahk_exe Menu.exe,Unhandled exception
{
	controlclick,&Quit
	;~ process,close,Menu.exe
	;~ pause:=1
	;~ MsgBox, 4144, ,% "RIS當掉！請重開！",10
	;~ ExitApp
}else{
	pause:=0
}
return


^!a::
Pause
return

;~ esc::
;~ ExitApp
;~ return
!#p::
;~ RisState:=RisOpened()
if (toggleState:=!toggleState){
	for k,v in selectedRis {
		WinShow,% "ahk_id " v.risHwnd
	}
}else{
	for k,v in selectedRis {
		WinHide,% "ahk_id " v.risHwnd
	}
}


return


AddSpaces(ByRef t){
	global Spaces
	
	sp_count:=Spaces.length()
	ret:=""
	
	;~ sp:=""
	;~ for k,v in Spaces
		;~ sp.=Chr(v)
	
	Loop,parse,t,`n,`r
	{
		sp:=""
		Random,s,0,5
		Loop % s
		{
			Random,r,1,% sp_count
			sp.=Chr(Spaces[r])
		}
		ret.=A_LoopField sp "`r`n"
	}
	return t:=ret
}


Quit:
ExitApp
return

onexit:
if re_run
	ExitApp

if (A_ExitReason!="Menu") && (!to_exit)
	portalMessage(sid:=askforportalidpw(),"0912000000","af")
send {ctrl up}
for k,v in selectedRis {
	risHwnd:=v.risHwnd
	winshow,% "ahk_id " risHwnd
	winset,enable,,% "ahk_id " risHwnd
	if (v.originalChkPlainfilmState)
		getNetAcc(risHwnd,"chkQueryHis","WindowsForms10.BUTTON.app").accDoDefaultAction()
	winactivate,% "ahk_id " risHwnd
}

ExitApp



to_exit(){
	global 
	to_exit:=true
	SetTimer,OnExit,-3000
}