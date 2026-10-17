/*
scsnake@gmail.com
*/

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
SetBatchLines, -1
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
SetTitleMatchMode,2
SetControlDelay,-1
SetFormat, float, 2.1

; Talk to the single CH_RIS owner (autorun) over IPC instead of creating our own
; IE-polling owner. Must be set before any include whose auto-exec calls getPlace (portalLib
; / RisImpax both can) and before the explicit getPlace() below. See CH_RIS_IPC_HANDOFF.md.
; (GetCHRisInputValue/GetCHRisVisibleValue read wb.document but are dead code; live RIS
;  reads go through getRis* / the CH_RIS_GUI hidden window, both fine cross-process.)
global __CH_RIS_CLIENT := true
#include <portalLib>
#include <Acc>
#include <.NetGetControl>
#include <Chrome>
#include <RisImpax>

global thisPlace:=getPlace()
global CH_RIS

;~ askForPortalIdPw()
;~ ,thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))
;~ ,RISImpaxRegister([  {app: "Ris", type: "State", hwnd: thisHwnd, msg: {msg: 0x1001}, func: "RisStateChanged", initStart: 1}
	;~ , {app: "Ris", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x1002}, func: "AccNoChanged", initStart: 100}])


;~ iniRead,loginId,login.ini,portal,id
;~ iniRead,loginPw,login.ini,portal,pw



;~ while !checkSid(sid:=Login(loginId,loginPw)) {
	;~ if a_index>50
		;~ exitapp
	;~ inputbox,loginId,Enter portal login ID,,,,,,,,,% (loginId="ERROR")?"":loginId
	;~ if errorlevel
		;~ exitapp
	;~ inputbox,loginPw,Enter portal login password
	;~ if errorlevel
		;~ exitapp
	;~ sleep 200
;~ }
;~ iniwrite,% loginId,login.ini,portal,id
;~ iniwrite,% loginPw,login.ini,portal,pw

OnExit,exitsub

gui,new,+LastFound +AlwaysOnTop
gui,font,s8,Verdana
;~ winset,transparent,200
winget,guiHwnd,id
gui,add,edit,vChartNo Disabled w100,% getRisChartNo("")
gui,add,edit,vptGender Disabled xp+110 w30,% getRisPtGender("")
gui,add,edit,yp xp+40 vboneAge w80 hwndboneAgeId,
;~ gui,add,text,yp x+5,"12.5" for "12y5m"
gui,add,checkbox,xs vifCountCenters,ossified centers
gui,add,button,yp xp+150,CopyPaste
gui,font,s7,Verdana
gui,add,edit,w300 h80 xs vreport
gui,show,y100,% "Bone Age Report System"

;~ settimer,renewChartNo,250
;~ settimer,getAge,500
settimer,refreshReport,250
;---------------- bone age data

BoneAgeArr:=[]

; age, gender => sd
BoneAgeArr[1,"M"]:=2.1
BoneAgeArr[1,"F"]:=2.7
BoneAgeArr[2,"M"]:=4.0
BoneAgeArr[2,"F"]:=4.0
BoneAgeArr[3,"M"]:=6.0
BoneAgeArr[3,"F"]:=5.6
BoneAgeArr[4,"M"]:=7.0
BoneAgeArr[4,"F"]:=7.2
BoneAgeArr[5,"M"]:=8.4
BoneAgeArr[5,"F"]:=8.6
BoneAgeArr[6,"M"]:=9.3
BoneAgeArr[6,"F"]:=9.0
BoneAgeArr[7,"M"]:=10.1
BoneAgeArr[7,"F"]:=8.3
BoneAgeArr[8,"M"]:=10.8
BoneAgeArr[8,"F"]:=8.8
BoneAgeArr[9,"M"]:=11.0
BoneAgeArr[9,"F"]:=9.3
BoneAgeArr[10,"M"]:=11.4
BoneAgeArr[10,"F"]:=10.8
BoneAgeArr[11,"M"]:=10.5
BoneAgeArr[11,"F"]:=12.3
BoneAgeArr[12,"M"]:=10.4
BoneAgeArr[12,"F"]:=14.0
BoneAgeArr[13,"M"]:=11.1
BoneAgeArr[13,"F"]:=14.6
BoneAgeArr[14,"M"]:=12.0
BoneAgeArr[14,"F"]:=12.6
BoneAgeArr[15,"M"]:=14.2
BoneAgeArr[15,"F"]:=11.2
BoneAgeArr[16,"M"]:=15.1
BoneAgeArr[17,"M"]:=15.4
BoneAgeArr[1.5,"M"]:=2.7
BoneAgeArr[1.5,"F"]:=3.4
BoneAgeArr[2.5,"M"]:=5.4
BoneAgeArr[2.5,"F"]:=4.8
BoneAgeArr[3.5,"M"]:=6.6
BoneAgeArr[3.5,"F"]:=6.5
BoneAgeArr[4.5,"M"]:=7.8
BoneAgeArr[4.5,"F"]:=8.0
BoneAgeArr[5.5,"M"]:=9.1
BoneAgeArr[5.5,"F"]:=8.9

; number of ossified centers: [ average, sd ]
BoneAgeArr["1m","M"]:=[4.11,1.41]
BoneAgeArr["1m","F"]:=[4.58,1.76]
BoneAgeArr["3m","M"]:=[6.63,1.86]
BoneAgeArr["3m","F"]:=[7.78,2.16]
BoneAgeArr["6m","M"]:=[9.61,1.95]
BoneAgeArr["6m","F"]:=[11.44,2.53]
BoneAgeArr["9m","M"]:=[11.88,2.66]
BoneAgeArr["9m","F"]:=[15.36,4.92]
BoneAgeArr["12m","M"]:=[13.96,3.96]
BoneAgeArr["12m","F"]:=[22.40,6.93]
BoneAgeArr["18m","M"]:=[19.27,6.61]
BoneAgeArr["18m","F"]:=[34.10,8.44]
BoneAgeArr["24m","M"]:=[29.21,8.10]
BoneAgeArr["24m","F"]:=[43.44,6.65]
BoneAgeArr["30m","M"]:=[37.59,7.40]
BoneAgeArr["30m","F"]:=[48.91,6.50]
BoneAgeArr["36m","M"]:=[43.42,5.34]
BoneAgeArr["36m","F"]:=[52.73,5.48]
BoneAgeArr["42m","M"]:=[47.06,5.26]
BoneAgeArr["42m","F"]:=[56.61,3.98]
BoneAgeArr["48m","M"]:=[51.24,4.59]
BoneAgeArr["48m","F"]:=[57.94,3.91]
BoneAgeArr["54m","M"]:=[53.94,4.35]
BoneAgeArr["54m","F"]:=[59.89,3.36]
BoneAgeArr["60m","M"]:=[56.24,4.07]
BoneAgeArr["60m","F"]:=[61.52,2.69]
;~ ,RisStateChanged(), AccNoChanged()

return

RisStateChanged(){
	global
	RisState:=RisOpened()
}

AccNoChanged(){
	global 
	AccNo:=getRisAccNo(RisState[2])
	,RisReports:=getRisReports(RisState[2])
	guicontrol,,chartNo,% chartNo:=getRisChartNo(RisState[2])
	SetTimer,getAge,-1
}

func2(b,gender){
	global BoneAgeArr
	arr:=[1,3,6,9,12,18,24,30,36,42,48,54,60]
	for k,v in arr
		if BoneAgeArr[v "m",gender][1]>b
			break
	k:=k=1?2:k
	return round(arr[k-1]+(arr[k]-arr[k-1])*(b-BoneAgeArr[arr[k-1] "m",gender][1])/(BoneAgeArr[arr[k] "m",gender][1]-BoneAgeArr[arr[k-1] "m",gender][1]))
}

; update needed 
near(str,gender){
	tmp:=[]
	stringreplace,n,str,m
	
	
	
	
	if instr(str,"m")
	{
		if n>=60
			tmp:=["54m","60m"]
		else if n>=54
			tmp:=["48m","54m","60m"]
		else if n>=48
			tmp:=["42m","48m","54m"]
		else if n>=42
			tmp:=["36m","42m","48m"]
		else if n>=36
			tmp:=["30m","36m","42m"]
		else if n>=30
			tmp:=["24m","30m","36m"]
		else if n>=24
			tmp:=["18m","24m","30m"]
		else if n>=18
			tmp:=["12m","18m","24m"]
		else if n>=12
			tmp:=["9m","12m","18m"]
		else if n>=9
			tmp:=["6m","9m","12m"]
		else if n>=6
			tmp:=["3m","6m","9m"]
		else if n>=3
			tmp:=["1m","3m","6m"]
		else
			tmp:=["1m","3m"]
		
		n:=n/12		
	}
	else if(n>=17&&gender="m")
		tmp:=[16,17]
	else if(n>=15&&gender="f")
		tmp:=[14,15]
	else if n>=6
		tmp:=[floor(n),floor(n)+1]
	else if n>=1
		tmp:=[RegExReplace(floor(n*2)/2,".0+$"),regexreplace(floor(n*2)/2+0.5,".0+$")]
	else
		tmp:=[1]
	
	
	
	return tmp	
}



boneAgeReport(age,gender,ifCountCenters,boneage){
	global BoneAgeArr
	str:=""
	
	RegExMatch(age,"(?:(\d+)y?)?(?:(\d+)m)?(?:(\d+)d)?",match)
	match1+=0
	match2+=0
	

	if !ifCountCenters {
		for k,v in near(match1+match2/12,gender)
			str.="Standard deviation of " v " y/o: " BoneAgeArr[v][gender] " M`r`n"
		
		
		
		str.="Chronological age:  " match1 " Yr and " match2 " M`r`n"
		
		RegExMatch(boneage,"(\d+)(?:\.(\d+))?",match)
		match1+=0
		match2+=0
		str.="Examed skeletal bone age:  " match1 " Yr and " match2 " M"
		
	}else {
		str.="Chronological age:  " match1*12+match2 " M`r`n"
		str.="Number of ossification centers: " boneage "`r`n"
		
		near:=near(match1*12+match2 "m",gender)
		;~ if near.maxIndex()=3 {
			;~ a:=RegExReplace(near[2],"m"),b:=RegExReplace(near[3],"m")
			;~ c:=BoneAgeArr[near[2]][gender][1],d:=BoneAgeArr[near[3]][gender][1]
			;~ str.="Examed skeletal bone age:  " round(a+(b-a)*(boneage-c)/(d-c)) " M`r`n`r`n"
			
		;~ }else{
			;~ str.="Examed skeletal bone age:   M`r`n`r`n"
		;~ }
		str.="Examed skeletal bone age:  " func2(boneage,gender) " M`r`n`r`n"
		
		for k,v in near
			str.="Mean number of ossification centers at " RegExReplace(v,"m") " M: " BoneAgeArr[v][gender][1] "`t`tSD: " BoneAgeArr[v][gender][2] "`r`n"
	}
	return str
}


ButtonCopyPaste:
gui,%guihwnd%:submit,nohide
studyInfo:=GetBoneAgeStudyInfo()
if (ptgender="")
	ptgender:=studyInfo.gender
setReportText(boneAgeReport(studyInfo.ageText,ptgender,ifCountCenters,boneage), "", getRisReports())
;~ winactivate,% "ahk_id " RisState[2]
CH_RIS.activate()
return

renewChartNo:
;~ for k,v in risControls:=getcontrols(risId[2]) {
	;~ if RegExMatch(v.text,"(\w)\w{5}\d") && instr(v.classNN,"WindowsForms10.EDIT.app") && risControls[k-1].text="病歷號" && risControls[k+2].text="姓名" {
		;~ guicontrol,,chartNo,% v.text
		;~ break
	;~ }
;~ }
return






submit: 
return

getAge:
gui,submit,nohide
;~ if(chartNo=prevChartNo)
	;~ return
;~ else
	;~ prevChartNo:=chartNo


if !sid || !checkSID(sid)
	sid:=Login(loginId,loginPw)

ptInfo:=patientBasicInfo(chartNo,sid)
guicontrol,,boneage,% ""
guicontrol,,ifCountCenters,0
guicontrol,,report,% boneAgeReport(ptInfo.age,ptInfo.gender,0,"")
guicontrol,,ptGender,% ptInfo.gender

if (HisHistory:=getHisHistory(getkeystate("shift"))).maxindex() {
	last:=HisHistory[HisHistory.maxindex()]

	guicontrol,,boneage,% estimateBA(ptInfo.age,last.CA,last.BA)
	SendMessage, 0x00B1, 0, -1,, ahk_id %boneAgeId% ;EM_SETSEL
	guicontrol,focus,boneage
}
return

estimateBA(nowAge,priorAge,priorBA){
	
	
	RegExMatch(nowAge,"(?:(\d+)y)?(?:(\d+)m)?",a)
	RegExMatch(priorAge,"(?:(\d+)y)?(?:(\d+)m)?",b)
	RegExMatch(priorBA,"(?:(\d+)y)?(?:(\d+)m)?",c)
	
	a1:=a1?a1:0,a2:=a2?a2:0,b1:=b1?b1:0,b2:=b2?b2:0,c1:=c1?c1:0,c2:=c2?c2:0
	
	if (b1=c1 && b2=c2)
		return a1 "." a2
	
	c2+=0+a1*12+a2-b1*12-b2
	while c2>11
		c1++,c2-=12
	return c1 "." c2
	
}

getHisHistory(shiftStatus){
	global RisState
	arr:=[]
	,dgHisReport=0
	
	
	if !(RisId:=RisState[2])
		return
	
	;~ for k,v in riscontrol:=getControls(risid)
		;~ if k<5
			;~ continue
		;~ else if instr(riscontrol[k-4].classNN,"SysTabControl32") && instr(v.classNN,"WindowsForms10.Window.8.app")
			;~ dgHisReport:=v.hwnd,break
	
	;~ if ((!dgHisReport)||acc_ObjectFromWindow(dgHisReport).accName!="DataGridView") && !(dgHisReport:=getNetControl(RisId,"dgHisReport","DataGridView","WindowsForms"))
			;~ return
	if !dgHisReport:=getNetControl(RisId,"dgHisReport","DataGridView","WindowsForms")
		return 
	
	dgHisReport:=acc_ObjectFromWindow(dgHisReport)
	
	if !(reportHwnd:=getNetControl(RisId,"HISTORY_EXAM_TEXT","","WindowsForms"))
		return
	
	firstSelect:=0
	
	for k,v in rows:=acc_children(dgHisReport) {
		if (k=1) {
			for x,y in acc_children(v)
				if (y.accValue="檢查日")
					examDateCol:=x
				else if (y.accValue="檢查名稱")
					examNameCol:=x
		}else {
			if !(acc_children(v)[examNameCol].accValue="Bone Age Study")
				continue
			if !firstSelect
				firstSelect:=v
			v.accSelect(ComObj(3,3),0)
			sleep 50
			
			if(shiftStatus) {
				; log
				db:=""
				,loc:=Acc_Location(v)
				winactivate,ahk_id %RisId%
				winwaitactive,ahk_id %RisId%
				mouseclick,left,% loc.x+30,% loc.y+5,2,0
				winwait,History Report Dialog
				db.=getHxDialogData() "`r`n"
				fileappend,% db,BoneAgeDb.csv,utf-8
				;;;;;;
			}
			

			controlgettext,report,,ahk_id %reportHwnd%
			
			
			if RegExMatch(report,"is)Chronological age.+?(\d+?)\s*Yr(?:.+?(\d+?)\s*M)?",CA) && RegExMatch(report,"is)Examed skeletal bone age.+?(\d+?)\s*Yr(?:.+?(\d+?)\s*M)?",BA) 
				CA1:=CA1?CA1:0,CA2:=CA2?CA2:0,BA1:=BA1?BA1:0,BA2:=BA2?BA2:0
				,arr[RegExReplace(acc_children(v)[examDateCol].accValue,"\/")]:=object("CA",CA1 "y" CA2 "m","BA",BA1 "y" BA2 "m")
			
			if(!shiftStatus)
				break
			
		}
		
	}
	
	if firstSelect
		firstSelect.accSelect(ComObj(3,3),0)
	else
		rows[2].accSelect(ComObj(3,3),0)
	
	return arr
}
getHxDialogData(){
	IfWinNotExist,History Report Dialog
		return
	winget,id,id,History Report Dialog
	
	;~ arr:=["照會單號","檢查地","病歷號","姓名","性別","診別","病房","科別","臨床醫師","身份","Symptom","Special med.","檢查日","技術員","住院/撰寫Dr.","主治/發送Dr."]
	arr:=[2,4,6,8,10,12,14,16,18,20,22,24,26,28,29,31,33,34]
	,str:=""
	
	win:=acc_objectfromwindow(id)
	fields:=acc_children(acc_get("object","2.4",0,win))
	for k,v in arr
		str.="""" acc_Children(fields[v])[4].accValue ""","
	
	
	;exam
	str.="""" acc_get("object","4.4.1.4.1.4.1.4.1.4.1.4",0,win).accValue ""","
	;impression
	str.="""" acc_get("object","4.4.1.4.1.4.2.4.1.4.1.4",0,win).accValue """"
	
	controlsend,,{esc},ahk_id %id%
	return str
	
	
}


refreshReport:
gui,%guihwnd%:submit,nohide
studyInfo:=GetBoneAgeStudyInfo()
if (studyInfo.chartNo!="" && chartNo!=studyInfo.chartNo){
	chartNo:=studyInfo.chartNo
	guicontrol,%guihwnd%:,chartNo,% chartNo
}
if (studyInfo.gender!="" && ptGender!=studyInfo.gender){
	ptGender:=studyInfo.gender
	guicontrol,%guihwnd%:,ptGender,% ptGender
}
OpenBoneAgePdfForCurrentStudy(studyInfo)
;~ traytip,,% prevBoneAge "=" boneAge
if(chartNo!="") && (boneAge=prevBoneAge && strlen(boneage)=strlen(prevBoneage) && ifCountCenters=previfcountcenters && pPtGender=ptGender)
	return
else
	prevBoneAge:=boneAge,previfcountcenters:=ifCountCenters,pPtGender:=ptGender

if(chartNo=""){
	guicontrol,%guihwnd%:,chartNo,% getRisChartNo("")
}
if boneage && !regexmatch(boneAge,"^\d+(\.\d+?)?$")
	return

guicontrol,%guihwnd%:,report,% boneAgeReport(studyInfo.ageText,ptGender,ifCountCenters,boneage)
return

GetBoneAgeStudyInfo(){
	global CH_RIS, __is_CH, thisPlace
	chartNo:=getRisChartNo("")
	gender:=getRisPtGender("")
	ageText:=getRisPtAge("")
	examName:=""
	months:=BoneAgeMonthsFromAgeText(ageText)
	if InStr(thisPlace, "C hospital") {
		; Read from the YCH process's hidden CH_RIS_GUI window (IPC via ControlGetText).
		; Edit order from CH_RIS_REPORT.create_gui(): 5=gender, 7=examname, 8=examtime, 13=birthday
		; chartNo intentionally NOT read — keeping it "" disables the early-return gate in refreshReport
		ControlGetText, _gender,   Edit5,  CH_RIS_GUI ahk_class AutoHotkeyGUI
		ControlGetText, _examName, Edit7,  CH_RIS_GUI ahk_class AutoHotkeyGUI
		ControlGetText, _examtime, Edit8,  CH_RIS_GUI ahk_class AutoHotkeyGUI
		ControlGetText, _birthday, Edit13, CH_RIS_GUI ahk_class AutoHotkeyGUI
		if (_gender != "")
			gender := _gender
		if (_examName != "")
			examName := _examName
		if (_birthday != "" && _examtime != "") {
			age := ChronologicalAgeFromDates(_birthday, _examtime)
			if IsObject(age) {
				ageText := age.y "y" age.m "m"
				months := age.months
			}
		}
	}
	return Object("chartNo", chartNo, "gender", gender, "ageText", ageText, "months", months, "examName", examName)
}

GetCHRisInputValue(nameRegex){
	global CH_RIS
	try inputs:=CH_RIS.wb.document.getElementsByTagName("input")
	catch
		return ""
	Loop % inputs.length {
		input:=inputs[A_Index-1]
		try key:=input.name "|" input.id "|" input.title "|" input.outerHTML
		catch
			key:=""
		try value:=Trim(input.value)
		catch
			value:=""
		if (value!="" && key~=nameRegex)
			return value
	}
	return ""
}

GetCHRisVisibleValue(labelRegex, valueType){
	global CH_RIS
	try text:=CH_RIS.wb.document.body.innerText
	catch
		return ""
	text:=RegExReplace(text, "[\r\n\t]+", " ")
	if (valueType="date"){
		if RegExMatch(text, "i)(" labelRegex ").{0,30}?(\d{4}[/-]\d{1,2}[/-]\d{1,2})", match)
			return match2
	}else if (valueType="age"){
		if RegExMatch(text, "i)(" labelRegex ").{0,30}?((?:\d+\s*(?:Y|Yr|Yrs|歲|年))(?:\s*\d+\s*(?:M|Mo|Mos|月))?)", match)
			return match2
	}else if (valueType="gender"){
		if RegExMatch(text, "i)(" labelRegex ").{0,20}?([MF男女])", match)
			return (match2="男") ? "M" : (match2="女") ? "F" : match2
	}
	return ""
}

ChronologicalAgeFromDates(birthday, examtime){
	if !ParseYMD(birthday, by, bm, bd) || !ParseYMD(examtime, ey, em, ed)
		return ""
	y:=ey-by
	,m:=em-bm
	if (ed<bd)
		m-=1
	if (m<0)
		y-=1, m+=12
	if (y<0)
		return ""
	return Object("y", y, "m", m, "months", y*12+m)
}

ParseYMD(dateText, ByRef y, ByRef m, ByRef d){
	if RegExMatch(dateText, "(\d{4})[/-]?(\d{1,2})[/-]?(\d{1,2})", match){
		y:=match1+0, m:=match2+0, d:=match3+0
		return y && m && d
	}
	return false
}

BoneAgeMonthsFromAgeText(ageText){
	ageText:=Trim(ageText)
	if (ageText="" )
		return ""
	if RegExMatch(ageText, "i)^\s*(\d+)\s*y\s*/?\s*(\d+)\s*m", match)
		return (match1+0)*12 + (match2+0)
	if RegExMatch(ageText, "i)^\s*(\d+)\s*(?:years|year|yrs|yr|y|歲|年)\s*(?:(\d+)\s*(?:months|month|mos|mo|m|月))?", match)
		return (match1+0)*12 + (match2+0)
	if RegExMatch(ageText, "i)^\s*(?:(\d+)\s*(?:months|month|mos|mo|m|月))", match)
		return match1+0
	if RegExMatch(ageText, "^\s*(\d+)\s*$", match)
		return match1*12
	return ""
}

NormalizeBoneAgeGender(gender){
	gender:=Trim(gender)
	if (gender~="i)^(M|男|male|boy|1)$")
		return "M"
	if (gender~="i)^(F|女|female|girl|2)$")
		return "F"
	return ""
}

IsBoneAgeExamName(examName){
	return Trim(examName)~="i)\bbone[\s_-]*age\b"
}

BoneAgePdfPage(gender, months){
	static boyPages, girlPages
	if !IsObject(boyPages){
		boyPages:=[[8,41],[10,42],[12,43],[14,44],[16,45],[18,46],[20,47],[24,48],[28,49],[30,50],[36,51],[42,52],[48,53],[54,54],[60,55],[66,56],[72,57],[84,58],[96,59],[108,60],[120,61],[132,62],[144,63],[156,64],[168,65],[180,66],[192,67],[204,68],[216,69]]
		girlPages:=[[8,70],[10,71],[12,72],[14,73],[16,74],[18,75],[20,76],[24,77],[28,78],[30,79],[36,80],[42,81],[48,82],[54,83],[60,84],[66,85],[72,86],[84,87],[96,88],[108,89],[120,90],[132,91],[144,92],[156,93],[168,94],[180,95],[192,96],[204,97],[216,98]]
	}
	if (months="")
		return ""
	gender:=NormalizeBoneAgeGender(gender)
	if (gender="")
		return ""
	pages:=(gender="F") ? girlPages : boyPages
	bestPage:="", bestDiff:=""
	for k,v in pages {
		diff:=Abs(months-v[1])
		if (bestDiff="" || diff<bestDiff)
			bestDiff:=diff, bestPage:=v[2]
	}
	return bestPage
}

OpenBoneAgePdfForCurrentStudy(studyInfo){
	static lastKey, lastAccNo, pendingKey, pendingCount, skipCount, retryAfter
	global CH_RIS
	if !IsObject(studyInfo)
		return
	; A blank name is a transient reset_gui() read, not a new study. Keep the
	; completed key so a GUI refresh cannot open the same PDF again.
	if (Trim(studyInfo.examName)="") {
		pendingKey := "", pendingCount := 0
		return
	}
	if !IsBoneAgeExamName(studyInfo.examName) {
		lastKey := "", lastAccNo := "", pendingKey := "", pendingCount := 0, skipCount := 0, retryAfter := 0
		return
	}
	page:=BoneAgePdfPage(studyInfo.gender, studyInfo.months)
	if (page="") {
		pendingKey := "", pendingCount := 0
		return
	}
	; Read accNo only to detect study changes. reset_gui() transiently clears Edit4 to ""; ignore
	; those empty reads so the oscillation "" -> "accNo" -> "" -> "accNo" doesn't reopen Chrome.
	ControlGetText, accNo, Edit4, CH_RIS_GUI ahk_class AutoHotkeyGUI
	if (accNo != "" && accNo != lastAccNo) {
		lastAccNo := accNo, lastKey := "", pendingKey := "", pendingCount := 0, retryAfter := 0
		; After accNo changes, Edit5/8/13 (gender/examtime/birthday) still hold the OLD study's
		; data for several timer ticks. Skipping 3 ticks (750ms) ensures IPC fields have cleared
		; and repopulated before we start counting key stability, preventing a premature open
		; with the wrong page (old stale data appears "stable" across 2 ticks and passes debounce).
		skipCount := 3
	}
	if (skipCount > 0) {
		skipCount -= 1
		return
	}
	; Key uses only gender|months|page — stable within a study.
	key:=studyInfo.gender "|" studyInfo.months "|" page
	if (key=lastKey)
		return
	; Debounce: require key identical for 2 consecutive reads (~500ms) before opening.
	if (key != pendingKey) {
		pendingKey := key
		pendingCount := 1
		retryAfter := 0
		return
	}
	pendingCount += 1
	if (pendingCount < 2)
		return
	if (retryAfter && A_TickCount<retryAfter)
		return
	path:=A_Desktop "\bone_age.pdf"
	url:="file:///" StrReplace(path, "\", "/") "#page=" page
	opened := false
	if FileExist(path) {
		try opened := OpenBoneAgePdfUrlInBrowser(url)
		catch e
			DebugLog("boneage.pdf", "Browser error: " e.Message)
	}
	if (opened) {
		; Remember the accepted command even if Chrome cannot expose the PDF URL.
		lastKey := key
		pendingKey := "", pendingCount := 0, retryAfter := 0
		DebugLog("boneage.pdf", "Open command accepted; page=" page)
	} else {
		; Keep the pending key so an unavailable file/browser or lost focus can
		; recover on a later timer tick without hammering Chrome every 250ms.
		retryAfter := A_TickCount+2000
		DebugLog("boneage.pdf", "Open failed; retrying page=" page)
	}
}

OpenBoneAgePdfUrlInBrowser(url){
	static browser := new Chrome()
	; Chrome may hide/normalize a local PDF URL or lose focus to RIS. Once the
	; address is submitted or Run succeeds, do not launch again to verify it.
	return browser.OpenOrNavigate(url, BoneAgePdfUrlPrefix(), true, 20, false)
}

BoneAgePdfUrlPrefix(){
	path:=A_Desktop "\bone_age.pdf"
	return "file:///" StrReplace(path, "\", "/")
}






#ifwinactive,Bone Age Report System
numpadEnter::
enter::
gosub ButtonCopyPaste
return

tab::
guicontrolget,focused,focus
if (focused!="boneAge")
	controlfocus,,% "ahk_id " boneAgeId
return

#ifwinactive









;~ ~esc::
GuiClose:
exitsub:
!q::
exitapp
return
