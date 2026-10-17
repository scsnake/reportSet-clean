﻿#include <httprequest>
;~ #include <Hex2Bin>
#include <Crypt>
#include <binaryIO>
#include <json>
#include <JXON>
#include <XML>
#include <SetTimerFn>
#include <StrPutVar>
#include <md5>
#include <DataGridTable>
#include <Base64ToFile>
#include <isValidJpeg>
#include <Edit>
#include <winhttprequest>
#include <StringUpper>
#include <CryptFileRead>
#include <WBGet>
#include <WB>

portalUrl:="http://portal.hospital-n.local"
__ua_header:="User-Agent: Mozilla/5.0 (compatible, MSIE 11, Windows NT 6.3; Trident/7.0;  rv:11.0) like Gecko"
;~ portalStatus("http://www.google.com")
;~ portalStatus(url="http://portal.hospital-n.local"){
	;~ try {
		;~ httprequest(url,post,header)
	;~ } catch {
		;~ msgbox test
	;~ }
	;~ msgbox % header
;~ }



html2dom(page){
	d:=ComObjCreate("HtmlFile")
	d.write(page)
	return d
}

/*
function as getElementById(identifier).value
return false if no id match
return "" if value=""

future rewrite: <(\w+)((?:\s+\w+(?:\s*=\s*(?:(?:"[^"]*")|(?:'[^']*')|[^>\s]+))?)*)\s*(\/?)>
*/


table2arr(tableElement, hasTitle=true){
	ret:=[]
	if !hasTitle
		ret.push([])
	
	Loop % (rows:=tableElement.rows).length {
		row:=rows[A_Index-1]
		,rowData:=[]
		Loop % (cells:=row.cells).length {
			rowData.push(Trim(cells[A_Index-1].innerText))
		}
		ret.push(rowData)
	}
	return new DataGridTable(ret)
}

get(byref html,identifier,from="id",get="value"){
	
	dom:=ComObjCreate("HtmlFile")
	
	dom.write(regexreplace(html,"is)(<\/html>).*$","$1"))
		if(from="id"){
			return dom.getElementById(identifier)[get]
		}else if (from="name"){
			return dom.all[identifier][get]
		}
	
}

getText(byref html){
	html:=RegExReplace(html,"[\n\r\t]+","")
	
	html:=regexreplace(html,"\s{2,}<"," <")
	html:=regexreplace(html,">\s{2,}","> ")
	html:=regexreplace(html,">\s+<","><")
	
	html:=RegExReplace(html,"is)<script[^>]*>.*?<\s*\/\s*script\s*>","")

	html:=regexreplace(html,"<[^<>]+>","")
	html:=regexreplace(html,"i)&nbsp;"," ")
	return html
}


getHtmlById(byref html,id,outer=false){
	RegExMatch(html,"is)<([^>\s]+)[^>]*\sid=(?:(?:""" id """)|(?:'" id "')|(?:" id "))[^>]*>(.*?)<\s*\/\s*\1\s*>",match)
	return outer ? match : match2
}

getTextById(byref html,id,trim=true){
	return trim ? trim(s:=getText(getHtmlById(html,id))) : s
}

getElement(ByRef dom, filter="", returnFirst=true){
	if !IsObject(filter) 
		return dom.getElementById(filter)
	else if (filter.hasKey("id"))
		return dom.getElementById(filter.id)
	else{
		f:=filter.tagName
		if f=
			f:="*"
		e:=dom.getElementsByTagName(f)
		
		if (returnFirst){
			Loop % e.length {
				v:=e[A_Index-1]
				for x,y in filter
					if !(v.getAttribute(x)=y)
						continue,2
				MsgBox % v.Name "," v.classname
				return v
			}
		}else{
			ret:=[]
			for k,v in e {
				r:=true
				for x,y in filter
					r &= (v.getAttribute(x)=y)
				if r
					ret.push(v)
			}
		}
	}
}


;~ MsgBox % convertHTMLchar("&lt;ciasdf&gt;")
;~ ExitApp
convertHTMLchar(ByRef str){
	s:=""
	j:=1
	while i:=RegExMatch(ss:=SubStr(str,j), "i)&(x[a-f\d]{1,4};|#\d{1,5};|[a-z]{2,5};)", match) {
		s.=SubStr(ss,1,i-1)
		dom:=ComObjCreate("HtmlFile")
		,dom.write(match)
		s.=dom.documentElement.innerText
		j+=i+StrLen(match)
	}
	return s ss
	
}

getHtmlByTagName(byref html,tagName,outer=false){
	arr:=[]
	i:=0
	while i:=regexmatch(html,"is)<" tagName "(?:\s[^>]*)?>(.*?)<\s*\/\s*" tagName "\s*>",match,i+1)
		outer ? arr.push(match) : arr.push(match1)
	return arr
}

getTextByTagName(byref html,tagName,trim=true){
	arr:=getHtmlByTagName(html,tagName)
	arr2:=[]
	for k,v in arr
		trim ? arr2.push(trim(s:=getText(v))) : arr2.push(s)
	return arr2
}

;~ msgbox % getUserName(loginId,"2B4124D6A69E491BB08F47AF9F1D367A")
getUserName(userId,sid){
	if !checkSid(sid)
		return
	global portalUrl
	
	httprequest(url:="http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/OpenWard.aspx?SESSION=" sid,html:="",header:="")
	
	RegExMatch(header,"ASP.NET_SessionId=(\w+)",match)
	
	
	header:="Accept: image/gif, image/jpeg, image/pjpeg, image/pjpeg, application/x-shockwave-flash, application/msword, application/x-ms-application, application/x-ms-xbap, application/vnd.ms-xpsdocument, application/xaml+xml, */*`nReferer: http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/OpenWard.aspx?SESSION=" sid "`nAccept-Language: zh-tw`nUser-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; Trident/4.0; GTB7.4; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR 3.0.04506.648; .NET CLR 3.5.21022; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729)`nContent-Type: application/x-www-form-urlencoded`nAccept-Encoding: gzip, deflate`nHost: ihisaw.hospital-n.local`nConnection: Close`nPragma: no-cache`nCookie: " match
	
	post:="scrollLeft=&scrollTop=&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=" encodeurl(get(html,"__VIEWSTATE")) "&__EVENTVALIDATION=" encodeurl(get(html,"__EVENTVALIDATION")) "&NWeb1%24QueryInPatientPersonAccountControl1%24DropListHosp=T0&NWeb1%24QueryInPatientPersonAccountControl1%24DropListWard=&NWeb1%24QueryInPatientPersonAccountControl1%24SearchDayRangeTextBox=4&NWeb1%24QueryInPatientPersonAccountControl1%24PersonIDInput=&NWeb1%24QueryInPatientPersonAccountControl1%24AccountIDSEInput=&NWeb1%24QueryInPatientPersonAccountControl1%24tbxChartNoInput=&NWeb1%24QueryInPatientPersonAccountControl1%24PatientBasicInfoQueryByName1%24ctl00=&NWeb1%24QueryInPatientPersonAccountControl1%24OperationRoomInput=&NWeb1%24QueryInPatientPersonAccountControl1%24OPDateInput%24YearInput=" a_yyyy "&NWeb1%24QueryInPatientPersonAccountControl1%24OPDateInput%24MonthInput" 0+a_mm "&NWeb1%24QueryInPatientPersonAccountControl1%24OPDateInput%24DayInput" 0+a_dd "&NWeb1%24QueryInPatientPersonAccountControl1%24IDInputTextBox=" getUserId(sid) "&NWeb1%24QueryInPatientPersonAccountControl1%24DateTextBoxYearMonthDayInputUI1%24YearInput=" a_yyyy "&NWeb1%24QueryInPatientPersonAccountControl1%24DateTextBoxYearMonthDayInputUI1%24MonthInput" 0+a_mm "&NWeb1%24QueryInPatientPersonAccountControl1%24DateTextBoxYearMonthDayInputUI1%24DayInput" 0+a_dd "&NWeb1%24QueryInPatientPersonAccountControl1%24DateTextBoxYearMonthDayInputUI2%24YearInput=" a_yyyy "&NWeb1%24QueryInPatientPersonAccountControl1%24DateTextBoxYearMonthDayInputUI2%24MonthInput" 0+a_mm "&NWeb1%24QueryInPatientPersonAccountControl1%24DateTextBoxYearMonthDayInputUI2%24DayInput" 0+a_dd "&NWeb1%24QueryInPatientPersonAccountControl1%24CheckBoxShowDrMainColumn=on&NWeb1%24QueryInPatientPersonAccountControl1%24ShowIntraReportCheck=on&NWeb1%24QueryInPatientPersonAccountControl1%24QueryPersonIDByChartNo1%24ChartNoTextBox=&NWeb1%24QueryInPatientPersonAccountControl1%24QueryPersonIDByChartNo1%24LNameInput=&NWeb1%24QueryInPatientPersonAccountControl1%24QueryPersonIDByChartNo1%24FNameInput=&NWeb1%24QueryInPatientPersonAccountControl1%24QueryPersonIDByChartNo1%24BirthDayInput=&NWeb1%24QueryInPatientPersonAccountControl1%24HiddenFieldIntraReport=&NWeb1%24Group=BySelectPrint&NWeb1%24ConditionLevelDropList=%23&NWeb1%24DateExecuteSwitchDate%24YearInput=" a_yyyy "&NWeb1%24DateExecuteSwitchDate%24MonthInput" 0+a_mm "&NWeb1%24DateExecuteSwitchDate%24DayInput" 0+a_dd "&NWeb1%24OriginalUserID=&NWeb1%24TransferUserID=&NWeb1%24QueryDrIDInfoByDrName1%24EmpNoQueryInput=" userId "&NWeb1%24QueryDrIDInfoByDrName1%24QueryByID=ID%E6%9F%A5%E5%A7%93%E5%90%8D&NWeb1%24DateTextBoxYearMonthDayInputDrugGiven%24YearInput=" a_yyyy "&NWeb1%24DateTextBoxYearMonthDayInputDrugGiven%24MonthInput" 0+a_mm "&NWeb1%24DateTextBoxYearMonthDayInputDrugGiven%24DayInput" 0+a_dd "&NWeb1%24PrintStartDate%24YearInput=1500&NWeb1%24PrintStartDate%24MonthInput=1&NWeb1%24PrintStartDate%24DayInput=1&NWeb1%24PrintEndDate%24YearInput=" a_yyyy "&NWeb1%24PrintEndDate%24MonthInput" 0+a_mm "&NWeb1%24PrintEndDate%24DayInput" 0+a_dd
	 
	httprequest(url,post,header,"charset: utf-8")
	
	
	
	regexmatch(getTextById(post,"NWeb1_QueryDrIDInfoByDrName1_EmpNoLabel"),"姓名：([^\s　]+)",match)
	return match1
	
	
}

getUserId(sid){
	if !checkSid(sid)
		return
	global portalUrl
	httprequest(portalUrl "/General/Redirect.aspx?SESSION=" sid,page)
	RegExMatch(page,"Portal_UserID=([^\']+)\'",match)
	return match1
}


;~ msgbox % getText(clipboard,"NWeb1_PatAccountListRecord1_GridViewInPatRecord_ctl02_InLabelStatusName")

/*
check if sid valid for portal
return 1 if valid 
return 0 if invalid
*/
;~ checksid("MOCK_SESSION_TOKEN")
checkSid(sid){
	global portalUrl
	if !RegExMatch(sid,"i)^[A-Z\d]+$")
		return 0
	httprequest(portalUrl "/General/Redirect.aspx?SESSION=" sid,page)
	return instr(page,sid) ? 1 : 0
}

/*
return valid sid
*/
renewSid(sid,loginId,loginPw){
	if checkSid(sid)
		return sid
	else
		return login(loginId,loginPw)
}



;~ getPortalAspId(url=""){
	;~ global portalUrl, portalAspId
	;~ httprequest(url,html:="", header:="")
	;~ ,RegExMatch(header,"(?<=ASP.NET_SessionId=)[^;]+", portalAspId)
;~ }
;~ ExitApp
;~ askForPortalIdPw()
login(loginId, loginPw, hospitalCode=0){
	global portalUrl, portalAspId, thisPlace
	
	if InStr(thisPlace, "C hospital")
		return
	
	if InStr(loginId loginPw, "ERROR")
		return
	
	StringUpper,loginId,loginId
	hospitalCode:=hospitalCode="A"?"C0":hospitalCode="H"?"T4":hospitalCode="Y"?"Y0":SubStr(hospitalCode,1,1)="T"?hospitalCode:"T" hospitalCode
	header=
	(Ltrim
	SOAPAction: "http://10.0.0.1/General/SessionService.asmx/NewSession"
	Host: sess.hospital-n.local
	Content-Type: text/xml; charset=utf-8
	)
	httprequest(url:="http://sess.hospital-n.local/SessionService/SessionService.asmx"
		, post:="<?xml version=""1.0"" encoding=""utf-8""?><soap:Envelope xmlns:soap=""http://schemas.xmlsoap.org/soap/envelope/"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema""><soap:Body><NewSession xmlns=""http://10.0.0.1/General/SessionService.asmx""><UserID>"  loginId "</UserID><password>" md5(loginPw)"</password><RemoteIP>10.0.0.1</RemoteIP><strHospital>" hospitalCode "</strHospital></NewSession></soap:Body></soap:Envelope>"
		, header, "charset: utf-8")
		
	,RegExMatch(post, "> *(\w{32,}) *<", match)
	
	,httprequest(url:="http://portal.hospital-n.local/General/NewRedirect.aspx?SESSION=" match1, post:="", header:="")
	,RegExMatch(header,"(?<=ASP.NET_SessionId=)[^;]+", portalAspIdNew)
	if portalAspIdNew!=
		portalAspId:=portalAspIdNew
	return match1
}

addPortalAspId(ByRef header){
	global portalAspId
	if !InStr(header, "Cookie: ")
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	else if InStr(header, "ASP.NET_SessionId: ")
		header:=RegExReplace(header, "(?<=ASP.NET_SessionId=)[^;]+", portalAspId)
	else
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	return header
}

refreshPortalAspId(ByRef header){
	global portalAspId
	RegExMatch(header,"(?<=ASP.NET_SessionId=)[^;]+", portalAspIdNew)
	if portalAspIdNew!=
		portalAspId:=portalAspIdNew
	return portalAspId
}

portal_httprequest(url, ByRef post="", ByRef header="", options=""){
	;~ global portalAspId
	post0:=post, header0:=header
	ret:=httprequest(url, post, header, options)
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
		if !InStr(header0, "Cookie: ")
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
		else if InStr(header0, "ASP.NET_SessionId: ")
			header0:=RegExReplace(header0, "(?<=ASP.NET_SessionId=)[^;]+", portalAspIdNew)
		else
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
		return httprequest(url, post:=post0, header:=header0, options)
	}
	return ret	
}

login_without_captcha(loginId,loginPw,HospitalCode=0){
	global portalUrl, portalAspId
	
	httprequest(url:=portalUrl "/General/Login.aspx",html:="", header:="")
	,inputs:=[]
	,inputs[s:="__VIEWSTATE"]:="" get(html,s)
	,inputs[s:="__EVENTVALIDATION"]:="" get(html,s)
	,inputs["txtUserID"]:="" loginId
	,inputs["txtPass"]:="" md5(loginpw)
	,inputs["ddlHospital"]:=hospitalCode="H"?"T4":hospitalCode="Y"?"Y0":SubStr(hospitalCode,1,1)="T"?hospitalCode:"T" hospitalCode
	,inputs["rdblQuickMenu"]:="H"
	,RegExMatch(header,"(?<=ASP.NET_SessionId=)[^;]+", portalAspIdNew)
	if portalAspIdNew!=
		portalAspId:=portalAspIdNew
	str=
	for k,v in inputs
	  str.= encodeurl(k) "=" encodeurl(v) "&"
	
	post:=str "imgBtnSubmitNew.x=0&imgBtnSubmitNew.y=0"
	;~ header:="Accept: image/jpeg, application/x-ms-application, image/gif, application/xaml+xml, image/pjpeg, application/x-ms-xbap, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword, */*`nReferer: http://portal/General/Login.aspx`nAccept-Language: zh-TW`nUser-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; InfoPath.2; .NET4.0C; .NET4.0E)`nContent-Type: application/x-www-form-urlencoded`nAccept-Encoding: gzip, deflate`nHost: portal`nConnection: Close`nPragma: no-cache"
	,header:=""
	
	,httprequest(url,post,header,"charset: utf-8")
	,RegExMatch(post,"i)SESSION=([A-Z\d]+)",match)
	
	return match1 ? match1 : ""
}


logout(sid, __=""){
	global portalUrl, portalAspId
	
	httprequest(url:="http://portal.hospital-n.local/General/Redirect.aspx?SESSION=" sid,html:="")
	
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	post:="__EVENTTARGET=&__EVENTARGUMENT=&__VIEWSTATE=" encodeurl(get(html,"__VIEWSTATE")) "&__EVENTVALIDATION=" encodeurl(get(html,"__EVENTVALIDATION")) "&ibtnLogOut.x=63&ibtnLogOut.y=22"
	
	httprequest(url,post,header,"charset: utf-8")
	
	
}

patientBasicInfo(chartNo,sid,byref html=""){
	if cache:=portalInfoTemp(chartNo, A_ThisFunc)
		return cache
	
	if !checkSid(sid)
		return []
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	if !regexmatch(chartNo,"(\w)\w{5}\d")
		return
	
	if(html=""){
		httprequest(url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PatientMedicalRecordListQuery.aspx?QueryBySelf=N&SESSION=" sid,html:="")
		,inputs:=[]
		,inputs[s:="__VIEWSTATE"]:="" get(html,s)
		,inputs[s:="__EVENTVALIDATION"]:="" get(html,s)
		,inputs["NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01"]:="" chartNo
		,inputs["NWeb1$PatientBasicInfoQueryByIDAndName1$ctl09"]:="查詢"
		post=
		for k,v in inputs
			post.= encodeurl(k) "=" encodeurl(v) "&"
		header:="Accept: image/jpeg, application/x-ms-application, image/gif, application/xaml+xml, image/pjpeg, application/x-ms-xbap, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword, */*`nReferer: " url "`nAccept-Language: zh-TW`nUser-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; InfoPath.2; .NET4.0C; .NET4.0E)`nContent-Type: application/x-www-form-urlencoded`nAccept-Encoding: gzip, deflate`nHost: ihisaw.hospital-n.local`nConnection: Close`nPragma: no-cache"
		
		httprequest(url,post,header,"charset: utf-8`n+NO_COOKIES")
	}else {
		post:=html
	}
	;~ clipboard:=post
	ptInfo:=[]
	,RegExMatch(post,"<[^>]+\sid=""NWeb1_PatAccountListRecord1_PatBasicDescription""[^>]*>([^\(]+)\(([^\,])\,(\d+)\/(\d+)\/(\d+)\,([^\)]+)\)",match)
	,ptInfo.name:=match1
	,ptInfo.gender:=match2
	,ptInfo.birthYear:=match3
	,ptInfo.birthMonth:=match4
	,ptInfo.birthDay:=match5
	,ptInfo.age:=match6
	,ptInfo.personId:=get(post,"NWeb1_PatAccountListRecord1_personidHidden")
	
	if (instr(post,"住院中")||instr(post,"已住院登記")||(trim(txt:=getTextById(post,"NWeb1_PatAccountListRecord1_GridViewInPatRecord_ctl02_InLabelStatusName"))&&(!instr(txt,"已出院"))))
		ptInfo.ward:=getTextById(post,"NWeb1_PatAccountListRecord1_GridViewInPatRecord_ctl02_InLabelWardName") " " getTextById(post,"NWeb1_PatAccountListRecord1_GridViewInPatRecord_ctl02_InLabelRoomName") "-" getTextById(post,"NWeb1_PatAccountListRecord1_GridViewInPatRecord_ctl02_InLabelBedName")
	else if s:=getTextById(post,"NWeb1_PatAccountListRecord1_GridViewEmergencyContent_ctl02_LabelEmerTempBedID")
		ptInfo.ward:="ER " s
	else if (trim(txt:=getTextById(post,"NWeb1_PatAccountListRecord1_GridViewEmergencyContent_ctl02_LabelEmerStatusName"))&&txt!="已離部")
		ptInfo.ward:="ER"
	else
		ptInfo.ward:="OPD"
	
	portalInfoTemp(chartNo, A_ThisFunc, ptInfo)
	return ptInfo
}

patientLabDataRecent(personId,sid){
	if !checkSid(sid)
		return
	
	url:= "http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/ReportResultQuery.aspx?SESSION=" sid "&PatClass=I&PersonID=" personId "&Hosp=T0&DefaultQuery=EMRContent"
	
	httprequest(url,data,header,"charset: utf-8`n+NO_COOKIES")
	arr:=new portalLib_patientLabDataRecent(getHtmlById(data,"TablePatientLabResult"))
	return arr
}



class portalLib_patientLabDataRecent {
	__New(html){
		i:=0,arr:=[]
		while i:=RegExMatch(html,"is)<td>([^<]*)<\/td>",match,i+1) {
			if a_index<10
				continue
			
			if mod(a_index,3)=1
				item:=match1
			else if mod(a_index,3)=2
				value:=match1
			else {
				date:=match1
				arr[item,"" date]:=value
			}
		}
		this.lab:=arr
	}
	
	getValue(labName){
		value:=[]
		for k,v in this.lab {
			if (isobject(labName)) {
				for m,n in labName
					if(k=n)
						for x,y in v
							value.push(array(x,y))
			}else if(k=labName)
				for x,y in v
					value.push(array(x,y))
		}
		return value
	}
	
}






; http://portal/DigReport/CheckUser_report.asp?'+a[1]+'&myurl=DigReport/Lab/NewQuery.asp'+b
;~ msgbox % patientBasicInfo(chartNo,"EE041FCC02C947A9B7009BE5A6D72444")
;~ msgbox % getText(clipboard,"NWeb1_PatAccountListRecord1_GridViewEmergencyContent_ctl02_LabelEmerTempBedID")

/* ;~ old site is closed on 2012/10/1 
patientLabDataRecent(chartno,sid){
	global portalUrl
	if !checkSid(sid)
		return 
	url:= portalUrl "/DigReport/CheckUser_report.asp?SESSION=" sid "&myurl=DigReport/Lab/NewQuery.asp?chartno=" chartNo
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	httprequest(url,data,header,"charset: utf-8`n+NO_COOKIES")
	return data
}
*/
/* ;~ old site is closed on 2012/10/1 
patientLabDataAll(chartno,sid){
	global portalUrl
	
	if !checkSid(sid)
		return
	
	patientLabDataRecent(chartno,sid)
	
	url:=portalUrl "/DigReport/Lab/NewQuery_notsure.asp"
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	httprequest(url,data:="",header,"charset: utf-8`n+NO_COOKIES")
	return lab:=new portalLib_parseLabData(data)
	
}
*/



/*
return 0: time out
return 1
*/
waitLoaded(byref pwb,judge="",waitSeconds=30,firstDelay=200){
	sleep % firstDelay
	if !isobject(judge) {
		while pwb.busy {
			if (a_index>waitSeconds*10)
				return 0
			sleep 100
		}
		return 1
	}else{
		while !judge.(pwb) {
			if (a_index>waitSeconds*10)
				return 0
			sleep 100
		}
		return 1
	}
}

IEGet2(Name="",matchMode="1")      ;Retrieve pointer to existing IE window/tab
	{
		Name := ( Name="New Tab - Windows Internet Explorer" ) ? "about:Tabs" : RegExReplace( Name, " - (Windows|Microsoft) Internet Explorer" )
		
		if(matchMode="1"){
			For Pwb in ComObjCreate( "Shell.Application" ).Windows
				If ( RegExMatch(Pwb.LocationName,"^" Name) && InStr( Pwb.FullName, "iexplore.exe" ))
					Return Pwb
		}else if(matchMode="2"){
			For Pwb in ComObjCreate( "Shell.Application" ).Windows
				If ( instr(Pwb.LocationName,Name) && InStr( Pwb.FullName, "iexplore.exe" ))
					Return Pwb
		}else if(matchMode="3"){
			For Pwb in ComObjCreate( "Shell.Application" ).Windows
				If ( Pwb.LocationName=Name) && InStr( Pwb.FullName, "iexplore.exe" )
					Return Pwb
		}else if(matchMode="RegEx"){
			For Pwb in ComObjCreate( "Shell.Application" ).Windows
			If ( RegExMatch(Pwb.LocationName,Name) && InStr( Pwb.FullName, "iexplore.exe" ))
				Return Pwb
	}
	
	return ""
} 


/*
return array with key=(innerText), value=(id)
*/
labOrderList(byref pwb,divId="NWeb1_OrderSearch1_pnlSearchOrders"){
	arr:=[]
	if instr(pwb.document.getElementById(divId).innerText,"查無醫令")
		return arr
	tr:=pwb.document.getElementById(divId).getElementsByTagName("a")
	
	loop % tr.length
		if RegExMatch(tr[a_index-1].id,"NWeb1_OrderSearch1_dlsOrders_ctl\d+_lbnName")
			arr[tr[a_index-1].innerText]:=tr[a_index-1].id
	
	return arr
}

/*
return array with key=(academic name), value=(business name)
*/
medOrderList(pwb,divId="NWeb1_MedicationDrugSearchBox_pnlControl"){
	arr:=[]
	
	
	
	tr:=pwb.document.getElementById(divId).rows
	
	loop % tr.length-1 {
		name:=tr[a_index].cells[1].innerText
		arr[name,"id"]:=tr[a_index].getElementsByTagName("input")[0].id
		arr[name,"bName"]:=tr[a_index].cells[2].innerText
	}
	
	return arr
}



class portalLib_parseLabDataRegex
{
	__New(html){
		if !html
			return ""
		labTable:=getHtmlByTagName(html,"table")[2]
		labTableRows:=getHtmlByTagName(labTable,"tr")
		lab:=[]
		loop % labTableRows.maxIndex()
		{
			i:=a_index
			labTableRowText:=getText(labTableRows[i])
			if(i=1){
				RegExMatch(labTableRowText,"病歷號:(\w{6}\d)\s+姓名:([^\n]+)(?:先生|小姐)\s+生日:\s民國\s([^\s]+)",match)
				if !match1
					break
				lab.chartNo:="" match1
				lab.name:="" match2
				lab.birthDate:="" match3
				continue
			}
			if (!labTableRowText)
				continue
			if(regexmatch(labTableRowText,"登記\s([^\s]+)\s+([^\s]+)\s+([^\n]+\s+)([^\s]+)\s+No:([^\s]+)\s+(?:詳細資料\s+)?報告\s([^\s]+)\s+([^\s]+)",match)){
				labNo:=match5
				lab[labNo]:=[]
				lab[labNo].registerDate:="" match1
				lab[labNo].registerTime:="" match2
				lab[labNo].sample:="" trim(match3)
				lab[labNo].examRoom:="" match4
				lab[labNo].reportDate:="" match6
				lab[labNo].reportTime:="" match7
				continue
			}
			
			if(instr(labTableRowText,"檢查項目")){
				labNameCol:=labValueCol:=labUnitCol:=labRangeCol:=labInfoCol:=""
				loop % getHtmlByTagName(labTableRows[i],"td").maxIndex() 
				{
					labTableCellText:=getText(getHtmlByTagName(labTableRows[i],"td")[a_index])
					if instr(labTableCellText,"檢查項目")
						labNameCol:=a_index
					else if instr(labTableCellText,"數值")
						labValueCol:=a_index
					else if instr(labTableCellText,"單位")
						labUnitCol:=a_index
					else if instr(labTableCellText,"標準值")
						labRangeCol:=a_index
					else if instr(labTableCellText,"說明")
						labInfoCol:=a_index
				}
				continue
			}
			
			if !labNameCol || !labNo
				continue
			else
			{
				labTableCells:=getHtmlByTagName(labTableRows[i],"td")
				labName:=trim(getText(labTableCells[labNameCol]))
				lab[labNo][labName]:=[]
				if labValueCol
					lab[labNo][labName].value:="" trim(getText(labTableCells[labValueCol]))
				if labUnitCol
					lab[labNo][labName].unit:="" trim(getText(labTableCells[labUnitCol]))
				if labRangeCol
					lab[labNo][labName].range:="" trim(getText(labTableCells[labRangeCol]))
				if labInfoCol
					lab[labNo][labName].info:="" trim(getText(labTableCells[labInfoCol]))
			}
		}
		
		labHxTable:=getHtmlByTagName(html,"table")[3]
		labHxTableRows:=getHtmlByTagName(labHxTable,"tr")
		labHx:=[]
		loop % labHxTableRows.maxIndex()-1
		{
			labHxTableRow:=labHxTableRows[a_index+1]
			labHx[a_index]:=[]
			labHx[a_index].account:="" getText(getHtmlByTagName(labHxTableRow,"td")[2])
			labHx[a_index].ptFrom:="" getText(getHtmlByTagName(labHxTableRow,"td")[3])
			labHx[a_index].earliest:="" getText(getHtmlByTagName(labHxTableRow,"td")[4])
			labHx[a_index].last:="" getText(getHtmlByTagName(labHxTableRow,"td")[5])
			labHx[a_index].newest:="" getText(getHtmlByTagName(labHxTableRow,"td")[6])
			RegExMatch(getHtmlByTagName(labHxTableRow,"td")[2],"href=""([^""]+)""",match)
			labHx[a_index].link:="" match1
			
		}
		
		lab["labHx"]:=labHx
		this.lab:=lab	
	}
	
	
	/* result:
	(index)
		1
			register date and time in format of 100.01.01 00:00
		2
			value
	*/
	getValue(labName,sample="BLOOD"){
		StringUpper,sample,sample
		result:=[]
		for k,v in this.lab
		{
			if k is not number
				continue
			
			if !(v.sample=sample)
				continue
			
			
			for i,j in v
			{
				if !isobject(j)
					continue
				
				if(i=labName)
					result.push(array("" v.registerDate " " v.registerTime,"" j.value))
			}
		}
		
		return result
	}
}

; parse lab data (old website) webpage html into object
/* structure:
name: patient name
chartNo: patient chart no.
birthDate: patient birthday in format of 74.01.01
(labNo): 7 digits of number
	examRoom
	registerDate
	registerTime
	reportDate
	reportTime
	(labName)
		value
		unit
		range
		info
labHx	
	(index)
		account
		earliest
		last
		link
		newest
		ptFrom
		
future rewrite: use regex to parse
*/
class portalLib_parseLabData
{
	__New(html){
		if !html
			return ""
		doc := ComObjCreate("{25336920-03F9-11CF-8FD0-00AA00686F13}")
		doc.write(html)
		labTable:=doc.getElementsByTagName("table")[1]
		labTableRows:=labTable.rows
		lab:=[]
		loop % labTableRows.length
		{
			i:=a_index-1
			labTableRowText:=labTableRows[i].innerText
			if(!i){
				RegExMatch(labTableRowText,"病歷號:(\w{6}\d)\s+姓名:([^\n]+)(?:先生|小姐)\s+生日:\s民國\s([^\s]+)",match)
				if !match1
					break
				lab.chartNo:="" match1
				lab.name:="" match2
				lab.birthDate:="" match3
				continue
			}
			if (!labTableRowText)
				continue
			if(regexmatch(labTableRowText,"登記\s([^\s]+)\s+([^\s]+)\s+([^\n]+\s+)([^\s]+)\s+No:([^\s]+)\s+(?:詳細資料\s+)?報告\s([^\s]+)\s+([^\s]+)",match)){
				labNo:=match5
				lab[labNo]:=[]
				lab[labNo].registerDate:="" match1
				lab[labNo].registerTime:="" match2
				lab[labNo].sample:="" trim(match3)
				lab[labNo].examRoom:="" match4
				lab[labNo].reportDate:="" match6
				lab[labNo].reportTime:="" match7
				continue
			}
			
			if(instr(labTableRowText,"檢查項目")){
				labNameCol:=labValueCol:=labUnitCol:=labRangeCol:=labInfoCol:=""
				loop % labTableRows[i].cells.length 
				{
					labTableCellText:=labTableRows[i].cells[a_index-1].innerText
					if instr(labTableCellText,"檢查項目")
						labNameCol:=a_index-1
					else if instr(labTableCellText,"數值")
						labValueCol:=a_index-1
					else if instr(labTableCellText,"單位")
						labUnitCol:=a_index-1
					else if instr(labTableCellText,"標準值")
						labRangeCol:=a_index-1
					else if instr(labTableCellText,"說明")
						labInfoCol:=a_index-1
				}
				continue
			}
			
			if !labNameCol || !labNo
				continue
			else
			{
				labTableCells:=labTableRows[i].cells
				labName:=trim(labTableCells[labNameCol].innerText)
				lab[labNo][labName]:=[]
				if labValueCol
					lab[labNo][labName].value:="" trim(labTableCells[labValueCol].innerText)
				if labUnitCol
					lab[labNo][labName].unit:="" trim(labTableCells[labUnitCol].innerText)
				if labRangeCol
					lab[labNo][labName].range:="" trim(labTableCells[labRangeCol].innerText)
				if labInfoCol
					lab[labNo][labName].info:="" trim(labTableCells[labInfoCol].innerText)
			}
		}
		
		labHxTable:=doc.getElementsByTagName("table")[2]
		labHxTableRows:=labHxTable.rows
		labHx:=[]
		loop % labHxTableRows.length-1
		{
			labHxTableRow:=labHxTableRows[a_index]
			labHx[a_index]:=[]
			labHx[a_index].account:="" labHxTableRow.cells[1].innerText
			labHx[a_index].ptFrom:="" labHxTableRow.cells[2].innerText
			labHx[a_index].earliest:="" labHxTableRow.cells[3].innerText
			labHx[a_index].last:="" labHxTableRow.cells[4].innerText
			labHx[a_index].newest:="" labHxTableRow.cells[5].innerText
			labHx[a_index].link:="" labHxTableRow.cells[1].getElementsByTagName("a")[0].href
			
		}
		
		lab["labHx"]:=labHx
		this.lab:=lab
		
	}
	
	/* result:
	(index)
		1
			register date and time in format of 100.01.01 00:00
		2
			value
	*/
	getValue(labName,sample="BLOOD"){
		StringUpper,sample,sample
		result:=[]
		for k,v in this.lab
		{
			if k is not number
				continue
			
			if !(v.sample=sample)
				continue
			
			
			for i,j in v
			{
				if !isobject(j)
					continue
				
				if(i=labName)
					result.push(array("" v.registerDate " " v.registerTime,"" j.value))
			}
		}
		
		return result
	}
	
}


EncodeURL( p_data, p_reserved=true, p_encode=true )
{
   old_FormatInteger := A_FormatInteger
   SetFormat, Integer, hex

   unsafe = 
      ( Join LTrim
         25000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20
         22233C3E5B5C5D5E607B7C7D7F808182838485868788898A8B8C8D8E8F9091929394
         95969798999A9B9C9D9E9FA0A1A2A3A4A5A6A7A8A9AAABACADAEAFB0B1B2B3B4B5B6
         B7B8B9BABBBCBDBEBFC0C1C2C3C4C5C6C7C8C9CACBCCCDCECFD0D1D2D3D4D5D6D7D8
         D9DADBDCDDDEDF7EE0E1E2E3E4E5E6E7E8E9EAEBECEDEEEFF0F1F2F3F4F5F6F7F8F9
         FAFBFCFDFEFF
      )
      
   if ( p_reserved )
      unsafe = %unsafe%24262B2C2F3A3B3D3F40
   
   if ( p_encode )
      loop, % StrLen( unsafe )//2
      {
         StringMid, token, unsafe, A_Index*2-1, 2
         StringReplace, p_data, p_data, % Chr( "0x" token ), `%%token%, all 
      }
   else
      loop, % StrLen( unsafe )//2
      {
         StringMid, token, unsafe, A_Index*2-1, 2
         StringReplace, p_data, p_data, `%%token%, % Chr( "0x" token ), all
      }
      
   SetFormat, Integer, %old_FormatInteger%

   return, p_data
}

DecodeURL( p_data )
{
   return, EncodeURL( p_data, true, false )
}

;~ getLab4New("5______","7B41E7A37F49482D9C79CCEC9C8F8C68")
;~ getLab4New(chartNo,sid,days=90){
	;~ url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MedicalReportContent.aspx?SESSION=" sid "&PatClass=I&WardCode=09B&ChartNo=" chartNo "&HospitalCode=T0&Seed=" a_now "&IntervalDay=-" days
	;~ httprequest(url,html:="","","charset: utf-8")
	;~ clipboard:=html
;~ }

;~ findLab4New(getLab4New("3______","BE164D69C80A490AB37529824EF16D13",20),"T-BIL")
getLab4New(chartNo,sid,days=10){
	global lab4portalAspId
	url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MedicalReportContent.aspx?PatClass=I&WardCode=03C1&ChartNo=" chartNo "&HospitalCode=T0&Seed=" a_now "&IntervalDay=-" days-1 "&SESSION=" sid
	
	header:="Accept: image/gif, image/jpeg, image/pjpeg, image/pjpeg, application/x-shockwave-flash, application/msword, application/xaml+xml, application/vnd.ms-xpsdocument, application/x-ms-xbap, application/x-ms-application, */*`nAccept-Language: zh-tw`nUser-Agent: Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; BTRS105843; SIMBAR={170CCC21-65EC-11E2-B538-FEB49644ABDD}; GTB7.5; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30; .NET CLR 3.0.04506.648; .NET CLR 3.5.21022; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729)`nAccept-Encoding: gzip, deflate`nConnection: Close`nHost: ihisaw.hospital-n.local`nCookie: CK_MedicalReportOpen_PatientQueryCookie=SelectPatListTypeCookieIPatList=&SelectPatListTypeCookieEPatList=&SelectPatListTypeCookieOPatList=&SelectPatListTypeCookieLabPatList=&SelectPatListTypeCookieSpeList=&SelectPatListTypeCookie=IPatList;"
	
	httprequest(url,post:="",header,"charset: utf-8")
	RegExMatch(header,"is).+ASP.NET_SessionId=(\w{24}).+",match)
	lab4portalAspId:=match1
	
	url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MedicalReportContent.aspx?PatClass=I&WardCode=03C1&ChartNo=" chartNo "&HospitalCode=T0&Seed=" a_now "&IntervalDay=-" days-1 "&SESSION=" sid
	
	
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	httprequest(url,post:="",header,"charset: utf-8")
	
	dom:=ComObjCreate("HtmlFile")
	dom.write(post)
	return parseLab4New(dom)
}


parseLab4New(byref dom){
	arr:=[]
	loop % (spans:=$(dom,"lReportTab_lsvReportBody_ctrl0_ctl00_LabDetailedSheetControl1_SpanSort").parentNode.childNodes).length-1 {
		specimen:=[]
		span:=spans[a_index]
		
		RegExMatch(text:=span.firstChild.innerText,"isO)([^:\d]+?):(.+?)\s([^:\d]+?):(\d+?)\s(.+)\s([^:\d]+?):(.+?)\s([^:\d]+?):(.+?)\s([^:\d]+?):(.+?)$",match)
		specimen["Info","" trim(match.1)]:=trim(match.2)
		specimen["Info","" trim(match.3)]:=trim(match.4)
		specimen["Info","SpecimenName"]:=trim(match.5)
		specimen["Info","" trim(match.6)]:=trim(match.7)
		specimen["Info","" trim(match.8)]:=trim(match.9)
		specimen["Info","" trim(match.10)]:=trim(match.11)
		
		table:=span.getElementsByTagName("TABLE")[0]
		titles:=[]
		loop % (tds:=table.rows[0].childNodes).length
			titles.push(trim(tds[a_index-1].innerText))
		loop % (trs:=table.childNodes[1].childNodes).length {
			item:=[],i:=a_index
			for k,v in titles
				item["" v]:="" trim(regexreplace(trs[i-1].childNodes[k-1].innerText,"歷$"))
			specimen.push(item.clone())
		}
		arr.push(specimen.clone())
	}
	return arr
}

findLab4New(byref lab,itemName,specimenName="BLOOD"){
	arr:=[],itemNameText:="檢驗項目",sort:=[],foundCount:=0
	for i,specimen in lab
		for k,item in specimen {
			if (k="Info" || !(item[itemNameText]=itemName))
				continue
			
			if (time:=regexreplace(specimen["info","採檢"],"\D")) {
			}else if (time:=regexreplace(specimen["info","登入"],"\D")) {
			}else 
				time:=regexreplace(specimen["info","最後報告"],"\D")
			
			sort[time]:=(++foundCount)
			found:=item.clone()
			for m,n in specimen.Info
				found["" m]:="" n
			arr.push(found.clone())
		}
	
	sortedArr:=[]
	for k,v in sort
		sortedArr[foundCount+1-a_index]:=arr[v].clone()
	return sortedArr
}

searchLab4(chartNo,sid){
	if !checksid(sid)
		return
	
	;~ global portalUrl
	httprequest(url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MedicalReportContent.aspx?SESSION=" sid,html:="")
	inputs:=[]
	inputs["__LASTFOCUS"]:=""
	inputs["__EVENTTARGET"]:=""
	inputs["__EVENTARGUMENT"]:=""
	inputs[s:="__VIEWSTATE"]:="" get(html,s)
	inputs["__VIEWSTATEENCRYPTED"]:=""
	inputs[s:="__PREVIOUSPAGE"]:="" get(html,s)
	inputs[s:="__EVENTVALIDATION"]:="" get(html,s)
	inputs["hdfDelayedAction"]:=""
	inputs["hdfAction"]:=""
	inputs["hdfSplitted"]:="false"
	inputs["hdfSelectPatientList"]:=""
	inputs["hdfPatientInfoStaus"]:=""
	inputs["CleanCookie"]:="false"
	inputs["HeaderTemplate1$hdfSelectedFilter"]:=""
	inputs["HeaderTemplate1$hdfIsFilterSetModified"]:="False"
	inputs["sltexample4"]:="LabReport"
	inputs["sltexample4"]:="XrayTextReport"
	inputs["sltexample4"]:="UltraSonicReport"
	inputs["sltexample4"]:="ECGReport"
	inputs["sltexample4"]:="CECGReport"
	inputs["sltexample4"]:="TreadmillReport"
	inputs["sltexample4"]:="ABPMReport"
	inputs["sltexample4"]:="LungFunctionReport"
	inputs["sltexample4"]:="ExerciseLungReport"
	inputs["sltexample4"]:="GEEndoScopeReport"
	inputs["sltexample4"]:="EchocardiogramExternalReport"
	inputs["sltexample4"]:="EchocardiogramReport"
	inputs["sltexample4"]:="HolterReport"
	inputs["sltexample4"]:="HealthyCenterReport"
	inputs["sltexample4"]:="PathologyReport"
	inputs["sltexample4"]:="PapTestReport"
	inputs["sltexample4"]:="SLP"
	inputs["sltexample4"]:="UBTReport"
	inputs["sltexample4"]:="UltraSoundReport"
	inputs["sltexample4"]:="EEGReport"
	inputs["sltexample4"]:="ConductionReport"
	inputs["sltexample4"]:="EvokeReport"
	inputs["sltexample4"]:="RTNoteReport"
	inputs["sltexample4"]:="GeneticReport"
	inputs["sltexample4"]:="ChromosomesReport"
	inputs["sltexample4"]:="PEDEEGReport"
	inputs["sltexample4"]:="PEDHEARTSONOReport"
	inputs["sltexample4"]:="01400-4-601266"
	inputs["sltexample4"]:="01400-4-601197"
	inputs["sltexample4"]:="01400-4-601267"
	inputs["sltexample4"]:="01400-4-601431"
	inputs["multiselect_sltReportFilter"]:="LabReport"
	inputs["multiselect_sltReportFilter"]:="XrayTextReport"
	inputs["multiselect_sltReportFilter"]:="UltraSonicReport"
	inputs["multiselect_sltReportFilter"]:="ECGReport"
	inputs["multiselect_sltReportFilter"]:="CECGReport"
	inputs["multiselect_sltReportFilter"]:="TreadmillReport"
	inputs["multiselect_sltReportFilter"]:="ABPMReport"
	inputs["multiselect_sltReportFilter"]:="LungFunctionReport"
	inputs["multiselect_sltReportFilter"]:="ExerciseLungReport"
	inputs["multiselect_sltReportFilter"]:="GEEndoScopeReport"
	inputs["multiselect_sltReportFilter"]:="EchocardiogramExternalReport"
	inputs["multiselect_sltReportFilter"]:="EchocardiogramReport"
	inputs["multiselect_sltReportFilter"]:="HolterReport"
	inputs["multiselect_sltReportFilter"]:="HealthyCenterReport"
	inputs["multiselect_sltReportFilter"]:="PathologyReport"
	inputs["multiselect_sltReportFilter"]:="PapTestReport"
	inputs["multiselect_sltReportFilter"]:="SLP"
	inputs["multiselect_sltReportFilter"]:="UBTReport"
	inputs["multiselect_sltReportFilter"]:="UltraSoundReport"
	inputs["multiselect_sltReportFilter"]:="EEGReport"
	inputs["multiselect_sltReportFilter"]:="ConductionReport"
	inputs["multiselect_sltReportFilter"]:="EvokeReport"
	inputs["multiselect_sltReportFilter"]:="RTNoteReport"
	inputs["multiselect_sltReportFilter"]:="GeneticReport"
	inputs["multiselect_sltReportFilter"]:="ChromosomesReport"
	inputs["multiselect_sltReportFilter"]:="PEDEEGReport"
	inputs["multiselect_sltReportFilter"]:="PEDHEARTSONOReport"
	inputs["multiselect_sltReportFilter"]:="01400-4-601266"
	inputs["multiselect_sltReportFilter"]:="01400-4-601197"
	inputs["multiselect_sltReportFilter"]:="01400-4-601267"
	inputs["multiselect_sltReportFilter"]:="01400-4-601431"
	inputs["q"]:=""
	inputs["HeaderTemplate1$txbIDInput"]:="" chartNo
	inputs["HeaderTemplate1$TextBoxWatermarkExtender1_ClientState"]:=""
	inputs["HeaderTemplate1$btnQueryAction"]:="查詢"
	inputs["PatientListTemplate1$rblPatList"]:="IPatList"
	inputs["PatientListTemplate1$ddlBedHosp"]:="T0"
	inputs["PatientListTemplate1$ddlWard"]:=""
	
	post=
	for k,v in inputs
	  post.= encodeurl(k) "=" encodeurl(v) "&"
	
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	httprequest(url,post,header,"charset: utf-8")
	return header "`n`n" post
}

LabIn10Days(chartNo,sid,personId=""){
	if !checksid(sid)
		return
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	if !personId
		personId:=patientBasicInfo(chartNo,sid).personId
	
	seed:=a_now
	
	header:="Accept: image/jpeg, application/x-ms-application, image/gif, application/xaml+xml, image/pjpeg, application/x-ms-xbap, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword, */*`nReferer: http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleShowiframePage.aspx?SESSION=" sid "&PersonID=" personId "&Seed=" seed "`nAccept-Language: zh-TW`nUser-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)`nAccept-Encoding: gzip, deflate`nHost: portal.hospital-n.local`nConnection: Close`nCookie: _CK_NPortal=HospitalCode=T0&HospitalCodeIndex=0&UserID=" getUserId(sid) "&SessionKey=" sid "&LoginPosCode=H&LoginPosCodeIndex=0"
	
	httprequest("http://portal.hospital-n.local/new_digreport/Lab/NewQuery.asp?result_latest=Y&chartno=" chartNo,post:="",header,"charset: utf-8")
	lab:=new portalLib_patientLabIn10Days(post)
	return lab
}

class portalLib_patientLabIn10Days {
	__New(html){
		i:=0,arr:=[],labNo:=""
		dom:=ComObjCreate("HtmlFile")
		dom.write(html)
		
		
		loop % (tables:=dom.getElementsByTagName("TABLE")).length {
			v:=tables[a_index-1]
			
			if RegExMatch(v.innerText,"[^\s]+\s+([^\n]+)\s+No:(\d+)\s+\(\s+(\d+).(\d+).(\d+)\s+(\d+:\d+)[^\(]+\((\d+).(\d+).(\d+)\s+(\d+:\d+)",match){
				labNo:=match2
				arr["" labNo,"sample"]:="" trim(match1)
				arr["" labNo,"regDate"]:=(match3+1911) match4 match5
				arr["" labNo,"regTime"]:="" match6
				arr["" labNo,"reportDate"]:=(match7+1911) match8 match9
				arr["" labNo,"reportTime"]:="" match10
				
				continue
			}
			
			if !labNo
				continue

			if(v.getElementsByTagName("TABLE").length)
				continue
			
			
			loop % (tr:=v.rows).length {
				if(a_index=1)
					continue
				
				
				if (td:=tr[a_index-1].cells).length<6
					continue
				
				labName:="" trim(td[1].innerText)
				arr["" labNo,"" labName,"value"]:="" trim(td[2].innerText)
				arr["" labNo,"" labName,"unit"]:="" trim(td[3].innerText)
				arr["" labNo,"" labName,"range"]:="" trim(td[4].innerText)
				arr["" labNo,"" labName,"condition"]:="" trim(td[5].innerText)
				
			}
			labNo:=""
			
		}
		
		this.lab:=arr
	}
	
	getValue(byref labName,sample="BLOOD"){
		result:=[]
		StringUpper,sample,sample
		
		for k,v in this.lab {
			if (!isobject(v) || v.sample!=sample)
				continue
			if (isobject(labName))
				for m,n in labName
					if(isobject(v[n]))
						result[v.reportDate]:=v[n]
			else if (isobject(v[labName]))
				result[v.reportDate]:=v[labName]
			
		}
		return result
	}
	
}

/*
StrPutVar(string, ByRef var, encoding)
{
    ; Ensure capacity.
    VarSetCapacity( var, StrPut(string, encoding)
        ; StrPut returns char count, but VarSetCapacity needs bytes.
        * ((encoding="utf-16"||encoding="cp1200") ? 2 : 1) )
    ; Copy or convert the string.
    return StrPut(string, &var, encoding),VarSetCapacity(var,-1)
}
*/

;~ a:=new portalLib_patientLabIn10Days(labin10days("5______","6F7FEA74511B4A84984B2BFB85E17C24"))
;~ msgbox % a["1______","HB","value"]
;~ fileappend,% test,test.txt



patientBasicInfoTree(chartNo,sid,function="",personId=""){
	global portalAspId
	if !function
		return
	if !checkSid(sid)
		return
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	if !personId
		personId:=patientBasicInfo(chartNo,sid).personId
	
	url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleShowiframePage.aspx?SESSION=" sid "&PersonID=" personId "&Seed=" a_now
	,header:="Accept: */*`nAccept-Language: zh-TW`nUser-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)`nAccept-Encoding: gzip, deflate`nConnection: Close`nHost: ihisaw.hospital-n.local`nPragma: no-cache"
	,httprequest(url,page:="",header,"charset: utf-8")
	;~ checkMedicalManagement(url, header, page)
	,RegExMatch(page,"i)http:[^']+?SimpleInfoShowUsingPlaceHolder[^']+?Func=" function "&[^']+?Seed=\d+",match)
	if InStr(match, "\\"){
		split:=RegExSplit(match, "\\\\")
		for k,v in split.split
			if InStr(v, function){
				match:=v
				break
			}
	}
	
	return (match?RegExReplace(match,"&amp;","&"):"")


}

;~ getReportByPortal("465E241D9ED93645B5B45CC7EAD2A8EF0A","8______","T__________")
;~ getReportByPortal("47DF53FD4A208B4FECA4FC8DCD98D937A7","8______","T__________")

getReportByPortal(sid, chartNo, ByRef AccNo, ByRef PacsHx="", ByRef personId="", ExamNameRegex=""){
	static prvChartNo, prvPacsHx, prvPersonId
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	if !(PacsHx.maxIndex()>0)
		if (chartNo=prvChartNo && prvPacsHx.maxIndex()>0)
			PacsHx:=prvPacsHx
		else
			PacsHx:=patientBasicInfoWebTree(patientBasicInfoWeb(chartNo, sid, personId)).getNodeByNames("置頂","報告","影核醫報告").arr
	if !personId
		if (chartNo=prvChartNo && prvPersonId!="")
			personId:=prvPersonId
		else
			personId:=patientBasicInfo(chartNo,sid).personId
	
	prvChartNo:=chartNo
	, prvPacsHx:=PacsHx
	, prvPersonId:=personId
	
	if (accno="" && ExamNameRegex!=""){
		ret:=[]
		for k,v in PacsHx
			if (RegExMatch(v.innerText, ExamNameRegex))  {
				RegExMatch(v.href, "_([TY]\w{9}\d)&", accno)
				, accno:=accno1
				,RegExMatch(v.href, "http[^']+", url)
				,httprequest(url, post:=""
					, header:="Referer: http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleShowiframePage.aspx?SESSION=" sid "&PersonID=" personId "&Seed=" a_now " `nHost: ihisaw.hospital-n.local", "charset: utf-8")
				;~ clipboard:=header "`n`n" post
				
				,dom:=ComObjCreate("HtmlFile")
				,dom.write(post)
				,arr:=[]
				,fields:=[["", "AccessNo", "","IOE","","ReferDept"],["","Status","","FormalVersion","","ExamDate"]
					,["","OrderDescription","","ReportDate"],[],["ReportBody"],[],["Impression"],["","ReportDr"]]
				,table:=dom.getElementById("rReportTab_lsvReportBody_ctrl0_ctl00_tblDisplay")
				for k,v in fields
					for m,n in v
						if (n!="")
							try
								arr[n]:=Trim((n~="i)reportbody|impression")?(table.rows[k-1].cells[m-1].getElementsByTagName("textarea")[0].innerText):(table.rows[k-1].cells[m-1].innerText))
				
				ret[accno1]:=arr
				
			}
		return ret
	}else if(accno!="") {
		for k,v in PacsHx
			if (InStr(v.href, "_" AccNo "&"))  {
				RegExMatch(v.href, "http[^']+", url)
				,httprequest(url, post:=""
					, header:="Referer: http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleShowiframePage.aspx?SESSION=" sid "&PersonID=" personId "&Seed=" a_now " `nHost: ihisaw.hospital-n.local", "charset: utf-8")
				;~ clipboard:=header "`n`n" post
				
				,dom:=ComObjCreate("HtmlFile")
				,dom.write(post)
				,arr:=[]
				,fields:=[["", "AccessNo", "","IOE","","ReferDept"],["","Status","","FormalVersion","","ExamDate"]
					,["","OrderDescription","","ReportDate"],[],["ReportBody"],[],["Impression"],["","ReportDr"]]
				,table:=dom.getElementById("rReportTab_lsvReportBody_ctrl0_ctl00_tblDisplay")
				for k,v in fields
					for m,n in v
						if (n!="")
							try
								arr[n]:=Trim((n~="i)reportbody|impression")?(table.rows[k-1].cells[m-1].getElementsByTagName("textarea")[0].innerText):(table.rows[k-1].cells[m-1].innerText))
				
				return arr
				
			}
	}
	
	
	
}


getPacsHxByPortalParser(ByRef arr){
	for k,v in arr {
		if RegExMatch(v.innerText, "s)^(\d+)\/(\d+)\/(\d+)_(.+?)(?:\(V(\d+)\))?$", m) 
			arr[k, "ExamDate"]:=m1 m2 m3
			, arr[k, "ExamName"]:=m4
			, arr[k, "FormalVersion"]:=m5
		else if RegExMatch(v.innerText, "s)^(\d+)(\d+)(\d+) (.+?)(?:\(V(\d+)\))?$", m) 
			arr[k, "ExamDate"]:=m1 m2 m3
			,arr[k, "ExamName"]:=m4
			, arr[k, "FormalVersion"]:=m5
		if RegExMatch(v.href, "i)PersonID=([a-z\d]+)", m)
			arr[k, "PersonId"]:=m1
		if RegExMatch(v.href, "i)ChartNo(?:List)?=([^&]+)", m)
			arr[k, "ChartNo"]:=m1
		if RegExMatch(v.href, "i)ReportKey=([^_]+)_([^_]+)?_([^&]+)", m)
			arr[k, "HospitalCode"]:=m1
			,arr[k, "ReportDate"]:=SubStr(m2, 1, 8)
			,arr[k, "ReportKey"]:=m2
			,arr[k, "AccNo"]:=m3
		else if RegExMatch(v.href, "i)RequestSheetNoList=([^&]+)", m)
			arr[k, "AccNo"]:=m1
	}
	
	
}

getPathoByPortalParser(arr){
	for k,v in arr {
			
	}
	
}

getPathoByPortal(sid, chartNo, ByRef PathoHx="", ByRef personId="", ByRef PatientInfo=""){
	PatientInfo:=IsObject(PatientInfo)?PatientInfo:patientBasicInfoWebTree(patientBasicInfoWeb(chartNo, sid, personId))
	arr:=(infoTree:=PatientInfo).getNodeByNames("置頂","報告","病理報告").arr
	
	getPathoByPortalParser(arr)
	
	return PathoHx:=arr
}

getPacsHxByPortal(sid, chartNo, ByRef PacsHx="", ByRef personId="", ByRef PatientInfo=""){
	PatientInfo:=IsObject(PatientInfo)?PatientInfo:patientBasicInfoWebTree(patientBasicInfoWeb(chartNo, sid, personId))
	arr:=(infoTree:=PatientInfo).getNodeByNames("置頂","報告","影核醫報告").arr
	
	; requesting
	for k,v in infoTree.getNodeByNames("置頂", "PACS","CTOT").arr
		arr.push(v)
	
	for k,v in infoTree.getNodeByNames("置頂", "PACS","MROT").arr
		arr.push(v)
	
	for k,v in infoTree.getNodeByNames("置頂", "PACS","MGOT").arr
		arr.push(v)
	
	getPacsHxByPortalParser(arr)
	
	return PacsHx:=arr
}

;~ a:=getCancerHxByPortal(askForPortalIdPw(), "")
;~ url:=a[1].url
;~ httprequest(url, post:="", header:="Host: ihisaw.hospital-n.local", "Binary")
;~ ExitApp

confirmPatientEmployCrossHospNotify(url, sid, personId){
	static __pwb
	header:="Host: ihisaw.hospital-n.local"
	addPortalAspId(header)
	httprequest(url, post:="", header, "+NO_AUTO_REDIRECT")
	if RegExMatch(header, "Location: (http[^\r\n]+)", m){
		url:=m1
		,renewPortalState(post)
		
		if !__pwb
			__pwb:=ComObjCreate("InternetExplorer.Application")
		__pwb.navigate(url)
		;~ ,__pwb.Visible:=true
		Loop
			Sleep 10
		until !__pwb.busy || A_Index>1000
		
		__pwb.document.getElementById("btnConfirm").click()
		
		
		Loop
			Sleep 10
		until !__pwb.busy || A_Index>1000
		
		__pwb.quit()
		;~ header=
		;~ (LTrim
		;~ Referer: %url%
		;~ Host: ihisaw.hospital-n.local
		;~ Cookie: WardListColumnSelect100860=DR; InPatientWardDefaultQuery=T0||||QByBed|4 
		;~ )
		
		;~ post:="btnConfirm=%E7%A2%BA%E5%AE%9A"
		;~ addPortalState(post)
		;~ addPortalAspId(header)
		;~ httprequest(url, post, header, "+NO_AUTO_REDIRECT")
	}
}


getCancerHxByPortal(sid, chartNo, ByRef CancerHx="", ByRef personId="", ByRef PatientInfo=""){
	PatientInfo:=IsObject(PatientInfo)?PatientInfo:patientBasicInfoWebTree(patientBasicInfoWeb(chartNo, sid, personId))
	arr:=(infoTree:=PatientInfo).getNodeByNames("其他","癌症治療計畫").arr
	
	getCancerHxByPortalParser(arr)
	if !(chartNo~="^\d")
	for k,v in arr {
		confirmPatientEmployCrossHospNotify(v.url, sid, personId)
		break
	}
		
	return CancerHx:=arr
}
getCancerHxByPortalParser(arr){
	ret:=[]
	for k,v in arr {
		if RegExMatch(v.innerText, "^(\d+)\/(\d+)\/(\d+)_(\d+)? *([^\n]*)$", m)
			arr[k, "Date"]:=m1 m2 m3
			,arr[k, "Name"]:=Trim(m5)
		if RegExMatch(v.href, "i)EMRRecord=([a-z\d]+)", m)
			arr[k, "EMRRecord"]:=m1
		if RegExMatch(v.href, "i)EMRIDSE=([a-z\d]+)", m)
			arr[k, "EMRIDSE"]:=m1
		if RegExMatch(v.href, "i)http[^']+", m)
			arr[k, "url"]:=m
		
	}
	return arr
}

getPacsHxTimeline(sid, ByRef PacsHx, ByRef AllReports=""){
	ret:=[]
	,first:=getReportByPortal(sid, PacsHx[1].chartNo, PacsHx[1].AccNo, PacsHx, PacsHx[1].personId)
	, status:=first.IOE
	, PacsHx[1, "report"]:=first
	,ret[1]:=[PacsHx[1]]
	
	for k,v in PacsHx {
		if k=1
			continue
		report := getReportByPortal(sid, v.chartNo, v.AccNo, PacsHx, v.personId)
		,AllReports.push(report)
		,v["report"]:=report
		if (report.IOE=status){
			ret[ret.maxIndex()].push(v)
		}else{
			status:=report.IOE
			,ret.push([v])
		}
	}
	return ret
}

getOtherHospitalReports(chartNo, sid, ByRef personId=""){
	h:=patientBasicInfoWeb(chartNo, sid, personId)
	t:=patientBasicInfoWebTree(h)
	ret:=[]
	for k,v in t.getNodeByNames("門診").arr
		if InStr(v.innerText, "門診") && !InStr(v.innerText, "整合")
			for _,opd in v.childNodes {
				for _,item in opd.childNodes
					if InStr(item.innerText, "外院重要") {
						ret.push(item.href)
						break
					}
			}
	
	return ret
}

;~ a:=getPacsHxByPortal(sid:="", "4______")
;~ b:=getPacsHxTimeline(sid, a)
;~ h:=patientBasicInfoWeb("","")
;~ t:=patientBasicInfoWebTree(h)
;~ esc::ExitApp
;~ b:=1

patientBasicInfoWeb(chartNo,sid,ByRef personId="",medicalPrivacy="C5"){
	
	if (cache:=portalInfoTemp(chartNo, A_ThisFunc)) ||  (cache:=portalInfoTemp(personId, A_ThisFunc))
		return cache
	
	
	if !checkSid(sid)
		return
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	if !personId
		if (cache:=portalInfoTemp(personId:=patientBasicInfo(chartNo,sid).personId, A_ThisFunc))
			return cache
	
	
	
	url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleShowiframePage.aspx?SESSION=" sid "&PersonID=" personId "&Seed=" a_now
	,header2:=header:="Accept: */*`nAccept-Language: zh-TW`nUser-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)`nAccept-Encoding: gzip, deflate`nConnection: Close`nHost: ihisaw.hospital-n.local`nPragma: no-cache"
	,httprequest(url,page:="",header,"charset: utf-8`n+NO_COOKIES")
	
	if(instr(page,"確認非醫療業務執行期間開檔申請")){
		RegExMatch(page,"<form[^>]+action=""[^>]+ReturnPath=(\w+)[^>]+>",match)
		url2:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/MedicalManagementAuthor.aspx?SESSION=" sid "&PersonID=" personId "&ReturnPath=" match1
		header2:="Accept: */*`nAccept-Language: zh-tw`nReferer: " url2 "`nx-microsoftajax: Delta=true`nContent-Type: application/x-www-form-urlencoded; charset=utf-8`nCache-Control: no-cache`nAccept-Encoding: gzip, deflate`nUser-Agent: Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)`nHost: ihisaw.hospital-n.local`nConnection: Close`nPragma: no-cache"
		post2:="ScriptManager1=UpdatePanelContent%7CConfirmButton&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=" encodeurl(get(page,"__VIEWSTATE")) "&__EVENTVALIDATION=" encodeurl(get(page,"__EVENTVALIDATION")) "&SelectCodeValue=" medicalPrivacy "&RBList=" medicalPrivacy "&OtherReason=&__ASYNCPOST=true&ConfirmButton=%E7%A2%BA%E8%AA%8D%E7%94%B3%E8%AB%8B%E9%96%8B%E6%AA%94"
		httprequest(url2,post2,header2,"charset: utf-8`n+NO_COOKIES")
		;~ regexmatch(post2,"pageRedirect\|\|([^\|]+)\|",match)
		;~ httprequest(match1,page:="",header2,"charset: utf-8`n+NO_COOKIES")
		
		url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleShowiframePage.aspx?SESSION=" sid "&PersonID=" personId "&Seed=" a_now
		header2:=header:="Accept: */*`nAccept-Language: zh-TW`nUser-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)`nAccept-Encoding: gzip, deflate`nConnection: Close`nHost: ihisaw.hospital-n.local`nPragma: no-cache"
		httprequest(url,page:="",header,"charset: utf-8`n+NO_COOKIES")

		
		
	}
	renewPortalState(page)
	portalInfoTemp(chartNo, A_ThisFunc, page)
	return page
}


patientBasicInfoWebTree(html,recursing="",returnClass=1){
	;~ if !IsObject(html) {
		;~ dom:=ComObjCreate("HtmlFile")
		;~ ,dom.write(html)
		;~ ,page:=dom
	;~ }else{
		;~ page:=html.clone()
	;~ }
	
	if(!recursing){
		static dom:=ComObjCreate("HtmlFile")
		dom.write(html)
		,page:=dom.getElementById("TreeViewItemn0Nodes")
	}else{
		page:=dom.getElementById(recursing)
	}
	
	arr:=[]
	Loop % (children:=page.childNodes).length {
		v:=children[A_Index-1]
		if(v.tagName="table"){
			node:=[],a:=v.getElementsByTagName("a"),a:=a[a.length-1]
			,node.innerText:=Trim(a.innerText)
			,node.id:=a.id
			,node.href:="" a.href
			if(v.nextSibling.tagName!="div"){
				arr.push(node)
			}
		}else if(v.tagName="div"){
			
			node.childNodes:=patientBasicInfoWebTree(html, v.id)
			,arr.push(node)
		}
	}
	if (returnClass && !recursing){
		return new portalLib_patientBasicInfoWebTree(arr)
	}else
		return arr
	
}

class portalLib_patientBasicInfoWebTree {
	__New(ByRef arr){
		this.arr:=arr
	}
	
	getNodeByNames(params*){
		thisNode:=this.arr
		for k,v in params {
			found:=0
			if v is integer
			{
				thisNode:=thisNode[v].childNodes, found:=1
				continue
			}
			
			for m,n in thisNode {
				if (n.innerText=v){
					thisNode:=n.childNodes, found:=1
					break
				}
			}
			if(!found)
				return []
		}
		
		return new portalLib_patientBasicInfoWebTree(thisNode)
	}
}



checkMedicalManagement(url, header, ByRef post, check="C5"){
	global __VIEWSTATE, __VIEWSTATEGENERATOR, __EVENTVALIDATION, portalAspId
	if InStr(post, "確認非醫療業務執行期間開檔申請"){
		dom:=ComObjCreate("HtmlFile")
		,dom.write(post)
		,url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/" dom.getElementById("form1").action
		,pwb:=ComObjCreate("InternetExplorer.Application")
		,pwb.navigate(url)
		;~ ,pwb.Visible:=true
		Loop
			Sleep 100
		until !pwb.busy || A_Index>300
		b:=pwb.document.getElementsByTagName("input")
		;~ MsgBox % b.length
		Loop % b.length
		{
			e:=b[A_Index-1]
			;~ ToolTip % e.getAttribute("name")
			if(e.getAttribute("name")="RBList" && e.getAttribute("type")="radio" && e.getAttribute("value")=check){
				e.Click()
				break
			}
		}
		pwb.document.getElementById("ConfirmButton").Click()
		Loop
			Sleep 100
		until !pwb.busy || A_Index>30
		
		post:=pwb.document.documentElement.innerHTML
		,pwb.quit()
		;~ RegExMatch(header,"(?<=ASP.NET_SessionId=)[^;]+", portalAspIdNew)
		;~ if portalAspIdNew!=
			;~ portalAspId:=portalAspIdNew
		;~ header=
		;~ (LTrim 
		;~ Content-Type: application/x-www-form-urlencoded; charset=utf-8
		;~ Referer: %url%
		;~ Host: ihisaw.hospital-n.local
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
		;~ X-MicrosoftAjax: Delta=true
		;~ Connection: Close
		;~ )
		;~ renewPortalState(post)
		;~ ,post:="ScriptManager1=UpdatePanelContent%7CConfirmButton&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE="  encodeurl(__VIEWSTATE) "&__VIEWSTATEGENERATOR=" encodeurl(__VIEWSTATEGENERATOR) " &__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) " &SelectCodeValue=" check "&RBList=" check "&OtherReason=&__ASYNCPOST=true&ConfirmButton=%E7%A2%BA%E8%AA%8D%E7%94%B3%E8%AB%8B%E9%96%8B%E6%AA%94"
		;~ ,httprequest(url, post, header, "charset: utf-8")
	}
	return post
}


patientBriefMedicalRecord(chartNo,sid,personId=""){
	if !checkSid(sid)
		return
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	if !personId
		personId:=patientBasicInfo(chartNo,sid).personId
	
	url:=patientBasicInfoTree(chartNo,sid,"PatientBriefMedicalRecord",personId)
	,httprequest(url,page:="",header:="","charset: utf-8`n+NO_COOKIES")
	,arr:=[]
	
	,dom:=ComObjCreate("HtmlFile")
	,dom.write(page)
	
	,RegExMatch(page,"體重:([.\d]+)",match)
	,arr["BW"]:="" (match1?"" match1:"")
	,RegExMatch(page,"身高:([.\d]+)",match)
	,arr["BH"]:="" (match1?"" match1:"")
	
	,e:=dom.getElementById("PanelDetailBasicInfo")
	
	,RegExMatch(e.innerText, "is)(\(?電話\)?)?([^手]*)(\(?手機\)?)?([^住]*)(住址)?:?(.*)", match)
	,arr["Phone"]:= (Trim(match2)="" || InStr(match2, "(00)0"))?"":Trim(RegExReplace(match2, "\($", ""))
	,arr["CellPhone"]:=Trim(match4)
	,arr["Address"]:=Trim(match6)
	
	return arr
	
	
}


patientFutureSchedule(chartNo,sid,personId=""){
	global portalAspId
	if !checkSid(sid)
		return
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	if !personId
		personId:=patientBasicInfo(chartNo,sid).personId
	
	url:=patientBasicInfoTree(chartNo,sid,"FutureSchedule",personId)
	,httprequest(url,page:="",header:="","charset: utf-8")
	,arr:=[]
	
	,dom:=ComObjCreate("HtmlFile")
	,dom.write(page)

	,e:=dom.getElementById("TableFutureSchedule")
	if(e.id)
		arr.OPD:=[]
	Loop % (rows:=e.rows).length-2 {
		cells:=row:=rows[A_Index+1].cells
		,c:=[]
		for k,v in ["Date","Shift","Department","OPDnumber","OrderNumber","Doctor"]
			c[v]:=Trim(cells[k-1].innerText)
		arr.OPD.push(c)
	}
	
	e:=dom.getElementById("TableImageSchedule")
	if(e.id)
		arr.Image:=[]
	Loop % (rows:=e.rows).length-2 {
		cells:=row:=rows[A_Index+1].cells
		,c:=[]
		for k,v in ["Date","Shift","ExamRoom","OrderNumber","ExamName"]
			c[v]:=Trim(cells[k-1].innerText)
		arr.Image.push(c)
	}
	return arr
	
	
}
;~ sid:=askForPortalIdPw()
;~ a:=patientBWBH("", sid)
patientBWBH(chartNo,sid,personId=""){
	if !checkSid(sid)
		return
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	if !personId
		personId:=patientBasicInfo(chartNo,sid).personId
	
	;~ url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PatientBasicExaminationInfo.aspx?SESSION=" sid "&PersonID=" personId "&Hosp=T0&PatClass=E"
	url:="http://ihisaw.hospital-n.local/WebApplication/InPatient/ChildCurve/QueryHeightWeightByPersonID.aspx?SESSION=" sid "&PersonID=" personId "&Seed=" a_now
	,httprequest(url,page:="",header:="","charset: utf-8`n+NO_COOKIES`n+NO_AUTO_REDIRECT")
	,dom:=html2dom(page)
	,table:=table2arr($(dom, "ctl13_RecordTabPanel_PatientHeightWeightGrid"))
	,arr:=[]
	,arr["BH"]:=table.getCell(2, "身高(cm)")
	,arr["BW"]:=table.getCell(2, "體重(kg)")
	,arr["BMI"]:=table.getCell(2, "BMI")
	,arr["BSA"]:=table.getCell(2, "BSA")
	,arr["UpdateDate"]:=table.getCell(2, "時間") ; yyyy/mm/dd
	;~ ,arr["BH"]:="" regexreplace(getTextById(page,"TextBoxInputArea_ctl00_Label1"),"i)上次記錄 *: *([\d.]+|nil|NA)","$1")
	;~ ,arr["BW"]:="" regexreplace(t:=getTextById(clipboard:=page,"TextBoxInputArea_ctl01_Label1"),"i)上次記錄 *: *([\d.]+|nil|NA)","$1")
	;~ ,arr["UpdateDate"]:="" RegExReplace(getTextById(page,"ErrorMessage"),"is).+?([\d\/]+).*?","$1")
	return arr
}

;~ k:=patientLabHistory(chartNo,"850F789FB5444D5990EA80650603459F")
;~ k.getValue("TSH")

patientLabHistory(chartNo,sid,personId=""){
	if !checkSid(sid)
		return
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	if !personId
		personId:=patientBasicInfo(chartNo,sid).personId
	
	url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleInfoShowUsingPlaceHolder.aspx?SESSION=" sid "&PersonID=" personId "&Func=LabResultHistory&Seed=" a_now
	httprequest(url,page:="",header:="","charset: utf-8`n+NO_COOKIES")
	
	return o:=new portalLib_patientLabHistory(page)
	
	
}

fill0(str,n=2,fill="0"){
	while strlen(str)<n
		str:=fill str
	
	return str
}

;~ getRisSchedule("F568CE2492064B999D3979B690657BD4","","CHCT","2013/03/04")
;~ html:=getRisPatientMainPage("F568CE2492064B999D3979B690657BD4",11)
;~ a:=parseRisPatientMainPage(html)
parseRisPatientMainPage(html){
	arr:=[]
	
	html:=RegExReplace(html,"is)<input type=""hidden"" name=""__VIEWSTATE"" id=""__VIEWSTATE"" value="".+?"" \/>")
	
	dom:=comobjcreate("HtmlFile")
	dom.write(html)
	
	arr["OrderName"]:=$(html,"NWeb1_OrderScheduleInfo1_OrderNameLabel").innerText
	arr["CreatePersonName"]:=$(html,"NWeb1_OrderScheduleInfo1_lblCreateName").innerText
	arr["AccountNo"]:=$(html,"NWeb1_OrderScheduleInfo1_lblAccountNo").innerText
	arr["SheetNo"]:=$(html,"NWeb1_OrderScheduleInfo1_RequestSheetLabel").innerText
	arr["OrderStatus"]:=$(html,"NWeb1_OrderScheduleInfo1_OrderStatusLabel").innerText
	arr["ConfirmPersonName"]:=$(html,"NWeb1_OrderScheduleInfo1_LabelConfirmEmp").innerText
	arr["OrderTime"]:=$(html,"NWeb1_OrderScheduleInfo1_lblCreateDateTime").title
	arr["RegisterTime"]:=$(html,"NWeb1_OrderScheduleInfo1_RegisterTimeLabel").title
	arr["LoginTime"]:=$(html,"NWeb1_OrderScheduleInfo1_LoginDateTimeLabel").title
	arr["NotPerformReason"]:=$(html,"NWeb1_OrderScheduleInfo1_NotPerformReasonList").value
	arr["SpecialInstruction"]:=$(html,"NWeb1_OrderScheduleInfo1_SpecialInstructionLabel").innerText
	arr["ExecuteDr"]:=$(html,"NWeb1_OrderScheduleInfo1_ExecuteDrListLabel").innerText
	arr["CCC"]:=$(html,"NWeb1_OrderScheduleInfo1_lblExecuteCCC").innerText
	arr["ReportDr"]:=$(html,"NWeb1_OrderScheduleInfo1_ReportDrListLabel").innerText
	arr["Technician"]:=$(html,"NWeb1_OrderScheduleInfo1_TechnicianList").innerText
	arr["Machine"]:=$(html,"NWeb1_OrderScheduleInfo1_ExecuteMachineList").innerText
	arr["ExecuteRecord"]:=$(html,"NWeb1_OrderScheduleInfo1_ExcuteRecordInfo").innerText
	arr["ReportTime"]:=$(html,"NWeb1_OrderScheduleInfo1_txbReportDateTime").value
	arr["ShouldPayAmount"]:=$(html,"NWeb1_OrderScheduleInfo1_lblShouldPayAmount").innerText
	arr["PaidAmount"]:=$(html,"NWeb1_OrderScheduleInfo1_lblPaidAmount").innerText
	arr["NeedToPayAmount"]:=$(html,"NWeb1_OrderScheduleInfo1_lblNeedToPayAmount").innerText
	arr["LastPaidDate"]:=$(html,"NWeb1_OrderScheduleInfo1_lblLastPaidDate").innerText
	arr["LastPaidDate"]:=$(html,"NWeb1_OrderScheduleInfo1_lblLastPaidDate").innerText
	
	loop % (tr:=$(html,"NWeb1_AppendCreateOrders1_grvTreOrders").rows).length {
		arr["CreateOrders",a_index,"class"]:=(td:=tr[a_index+1].cells)[2].innerText
		arr["CreateOrders",a_index,"code"]:=td[3].innerText
		arr["CreateOrders",a_index,"name"]:=td[4].innerText
		arr["CreateOrders",a_index,"amount"]:=td[5].innerText
		arr["CreateOrders",a_index,"ifEmergent"]:=td[6].innerText
		arr["CreateOrders",a_index,"accountType"]:=td[7].innerText
		arr["CreateOrders",a_index,"executeTime"]:=td[8].innerText
	}
	
	return arr
	
	
}

;~ getAccountIdFromAccNo("B728452E2D45454E8E527099157D5648","T__________")
getAccountIdFromAccNo(sid, AccNo){
	global __VIEWSTATE,__EVENTVALIDATION,portalAspId
	
	
	url:="http://hisaw.hospital-n.local/WebApplication/Radiology/RISPatientRegistration.aspx?SESSION=" sid
	
	if (__VIEWSTATE="" || __EVENTVALIDATION="" || portalAspId=""){
		httprequest(url, post:="",header:="", "charset: utf-8")
		RegExMatch(header,"i)(?<=ASP.NET_SessionId=)\w+",portalAspId)
		renewPortalState(post)
	}
	
	
	StartDate:=substr(a_now,1,4) "/" substr(a_now,5,2) "/" substr(a_now,7,2)

	header=
	(LTrim
	Accept: */*
	Accept-Language: zh-tw
	Referer: %url%
	Host: hisaw.hospital-n.local
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	Connection: Keep-Alive
	x-microsoftajax: Delta=true
	Content-Type: application/x-www-form-urlencoded; charset=utf-8
	Cache-Control: no-cache
	Accept-Encoding: gzip, deflate
	User-Agent: Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; .NET CLR 1.1.4322; .NET4.0C; .NET4.0E)
	Pragma: no-cache
	)
	post:="NWeb1%24ScriptManager1=NWeb1%24uPnlQuery%7CNWeb1%24btnQueryByPatient&scrollLeft=&scrollTop=&__LASTFOCUS=&__EVENTTARGET=&__EVENTARGUMENT=&__VIEWSTATE=" encodeurl(__VIEWSTATE) "&__VIEWSTATEGENERATOR=377EE134&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&NWeb1%24ddlOrderType=X&NWeb1%24ddlUnitList=BDE1&NWeb1%24ddlStatisticGroupCode=MRI&NWeb1%24ddlShiftType=&NWeb1%24ddlPatClass=&NWeb1%24txbQueryStartDate=" encodeurl(StartDate) "&NWeb1%24ddlQueryDays=1&NWeb1%24txbRequestSheetNo=" AccNo "&NWeb1%24txbPersonID=&NWeb1%24txbAccountNo=&NWeb1%24txbChartNo=&NWeb1%24ddlStatisticGroupCodeFilter=&NWeb1%24cbxIsShowChartNo=on&__ASYNCPOST=true&NWeb1%24btnQueryByPatient=%E7%97%85%E4%BA%BA%E6%9F%A5%E8%A9%A2"
	;~ clipboard:=post
	httprequest(url, post, header1:=header, "charset: utf-8")
	if !instr(post,AccNo)
		return -1
	
	
	renewPortalState(post)
	post:="NWeb1%24ScriptManager1=NWeb1%24uPnlOrders%7CNWeb1%24grvPatientOrderList%24ctl02%24lbnSelect&scrollLeft=&scrollTop=&NWeb1%24ddlOrderType=X&NWeb1%24ddlUnitList=BDE1&NWeb1%24ddlStatisticGroupCode=MRI&NWeb1%24ddlShiftType=&NWeb1%24ddlPatClass=&NWeb1%24txbQueryStartDate=" encodeurl(StartDate) "&NWeb1%24ddlQueryDays=1&NWeb1%24txbRequestSheetNo=" AccNo "&NWeb1%24txbPersonID=&NWeb1%24txbAccountNo=&NWeb1%24txbChartNo=&NWeb1%24ddlStatisticGroupCodeFilter=&NWeb1%24cbxIsShowChartNo=on&NWeb1%24txbExecuteDate=" encodeurl(StartDate) " " substr(a_now,9,2) "%3A" substr(a_now,11,2) "&NWeb1%24ddlNotPerformReasonList=&NWeb1%24ddlFunctionType=&NWeb1%24ddlFunctionType2=&__LASTFOCUS=&__EVENTTARGET=NWeb1%24grvPatientOrderList%24ctl02%24lbnSelect&__EVENTARGUMENT=&__VIEWSTATE=" encodeurl(__VIEWSTATE) "&__EVENTVALIDATION="  encodeurl(__EVENTVALIDATION) "&__AjaxControlToolkitCalendarCssLoaded=&__ASYNCPOST=true&"
	httprequest(url,post,header1:=header,"charset: utf-8")
	
	if !instr(post,"pageRedirect")
		return -1
	
	url:="http://hisaw.hospital-n.local/WebApplication/Radiology/PatientMainPage.aspx?SESSION=" sid
	
	httprequest(url,post:="",header,"charset: utf-8")
	
	if !instr(post,AccNo)
		return -1
	
	dom:=comobjcreate("HtmlFile")
	dom.write(post)
	
	return dom.getElementById("NWeb1_OrderScheduleInfo1_lblAccountNo").innerText
}

renewPortalState(post){
	global __VIEWSTATE,__EVENTVALIDATION,__VIEWSTATEGENERATOR
	if !VIEWSTATE:=get(post,"__VIEWSTATE")
		regexmatch(post,"i)(?<=__VIEWSTATE\|)[^\|]+",VIEWSTATE)
	if (VIEWSTATE!="")
		__VIEWSTATE:=VIEWSTATE
		
	if !EVENTVALIDATION:=get(post,"__EVENTVALIDATION")
		regexmatch(post,"i)(?<=__EVENTVALIDATION\|)[^\|]+",EVENTVALIDATION)
	if (EVENTVALIDATION!="")
		__EVENTVALIDATION:=EVENTVALIDATION
	
	if !VIEWSTATEGENERATOR:=get(post,"__VIEWSTATEGENERATOR")
		regexmatch(post,"i)(?<=__VIEWSTATEGENERATOR\|)[^\|]+",VIEWSTATEGENERATOR)
	if (VIEWSTATEGENERATOR!="")
		__VIEWSTATEGENERATOR:=VIEWSTATEGENERATOR
	
	;~ if portalAspId=
		;~ getPortalAspId()
}

addPortalState(ByRef post){
	global __VIEWSTATE,__EVENTVALIDATION,__VIEWSTATEGENERATOR
	if !InStr(post, "__VIEWSTATE")
		post.=(post=""?"":"&") "__VIEWSTATE=" encodeurl(__VIEWSTATE)
	if !InStr(post, "__EVENTVALIDATION")
		post.=(post=""?"":"&") "__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION)
	if !InStr(post, "__VIEWSTATEGENERATOR")
		post.=(post=""?"":"&") "__VIEWSTATEGENERATOR=" encodeurl(__VIEWSTATEGENERATOR)
	return post
}

getRisPatientMainPage(sid,which="",ChartNo="",UnitList="X",StartDate="",ShiftType="",PatClass="",QueryDays=1,SheetNo="",PersonID="",AccountNo=""){
	global __VIEWSTATE,__EVENTVALIDATION,portalAspId
	if portalAspId=
		portalAspId=3aq1hx55dvooyqyzlp0nod22
	
	if which=
		which:="02"
	else
		which:=fill0(which+1)
	
	if (StartDate="")
		StartDate:=substr(a_now,1,4) "/" substr(a_now,5,2) "/" substr(a_now,7,2)

	
	
	url:="http://hisaw.hospital-n.local/WebApplication/Radiology/RISPatientRegistration.aspx?SESSION=" sid
	
	if (__VIEWSTATE="" || __EVENTVALIDATION=""){
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID

		httprequest(url,post:="",header,"charset: utf-8")
		
		__VIEWSTATE:=get(post,"__VIEWSTATE")
		__EVENTVALIDATION:=get(post,"__EVENTVALIDATION")
	}

    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	post:="NWeb1%24ScriptManager1=NWeb1%24uPnlOrders%7CNWeb1%24grvPatientOrderList%24ctl" which "%24lbnSelect&scrollLeft=0&scrollTop=99&__LASTFOCUS=&__EVENTTARGET=NWeb1%24grvPatientOrderList%24ctl" which "%24lbnSelect&__EVENTARGUMENT=&__VIEWSTATE=" encodeurl(__VIEWSTATE) "&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&NWeb1%24ddlOrderType=X&NWeb1%24ddlUnitList=CHCT&NWeb1%24ddlStatisticGroupCode=MRI&NWeb1%24ddlShiftType=&NWeb1%24ddlPatClass=&NWeb1%24txbQueryStartDate=" encodeurl(StartDate) "&NWeb1%24ddlQueryDays=1&NWeb1%24txbRequestSheetNo=&NWeb1%24txbPersonID=&NWeb1%24txbAccountNo=&NWeb1%24txbChartNo=&NWeb1%24ddlStatisticGroupCodeFilter=&NWeb1%24cbxIsShowChartNo=on&NWeb1%24txbExecuteDate=" encodeurl(StartDate) " " substr(a_now,9,2) "%3A" substr(a_now,11,2) "&NWeb1%24ddlNotPerformReasonList=&NWeb1%24ddlFunctionType=&NWeb1%24grvPatientOrderList%24ctl" which "%24cbxSelect=on&NWeb1%24ddlFunctionType2=&__ASYNCPOST=true&"
	
	httprequest(url,post,header,"charset: utf-8")
	
	
	
	url:="http://hisaw.hospital-n.local/WebApplication/Radiology/PatientMainPage.aspx?SESSION=" sid
	
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	httprequest(url,post:="",header,"charset: utf-8")
	
	return post
	
}

is_selfPaid(sid, accno){
	a:=getRisSchedule(sid,"",accno)
	,b:=new portalLib_parseRisSchedule(a)
	,sch:=b.schedule
	if !(sch.maxIndex()>=1)
		return -1
	return !!InStr(sch[1].BillType, "自費")
}

;~ comobjerror(false)
;~ a:=getRisSchedule("472518074158924838B0290796C3D08EDB","","T__________")
;~ b:=new portalLib_parseRisSchedule(a)
;~ d:=b.query([["Date","2015/04/13"]])
;~ c:=1
class portalLib_parseRisSchedule{

	__New(html){
		arr:=[]
		dom:=comobjcreate("HtmlFile")
		dom.write(html)
		
		table:=$(dom,"NWeb1_grvPatientOrderList")
		loop % table.rows.length-1 {
			row:=table.rows[a_index]
			exam:=[]
			exam.Date:=trim(row.cells[2].firstChild.title)
			exam.Shift:=trim(row.cells[3].innerText)
			exam.ExamOrder:=trim(row.cells[4].innerText)
			exam.ChartNo:=trim(row.cells[5].innerText)
			exam.Name:=trim(row.cells[6].innerText)
			exam.IdBirth:=trim(row.cells[6].firstChild.title)
			exam.Gender:=trim(row.cells[7].innerText)
			exam.Dept:=trim(row.cells[8].innerText)
			exam.Dept1:=trim(row.cells[8].firstChild.title)
			exam.BillType:=trim(row.cells[9].innerText)
			exam.OrderName:=trim(row.cells[10].innerText)
			exam.SheetNo:=trim(row.cells[10].firstChild.title)
			exam.Status:=trim(row.cells[11].innerText)
			exam.AccountStatus:=trim(row.cells[12].innerText)
			exam.ArriveTime:=trim(row.cells[13].innerText)
			exam.Emergent:=trim(row.cells[14].innerText)
			exam.Portable:=trim(row.cells[15].innerText)
			arr.push(exam.clone())
		}
			
		this.schedule:=arr
	}
	
	filter(byref exam,filterName,filterValue,fitType=0){
		if instr(exam.Status,"刪除")
			return 0
		if(fitType=1)
			return exam[filterName]=trim(filterValue)?1:0
		else if(fitType=0 || fitType="")
			return instr(exam[filterName],trim(filterValue))?1:0
		else if(fitType=2)
			return regexmatch(exam[filterName],trim(filterValue))?1:0
	}
	
	query(param){
		arr:=[]
		
		for k,v in this.schedule {
			match:=true
			for x,y in param
				if !(match:=match && this.filter(v,y.1,y.2,y.3))
					break
			if match
				arr.push(v.clone())
		}
		return arr
	}
	
}
getRisSchedule(sid,ChartNo="",SheetNo="",UnitList="BDE1",StartDate="",ShiftType="",PatClass="",QueryDays=1,PersonID="",AccountNo=""){
	global __VIEWSTATE,__EVENTVALIDATION,portalAspId
	
	;~ if portalAspId=
		;~ portalAspId=3aq1hx55dvooyqyzlp0nod22
	if (chartNo!="")	
		loop % 7-strlen(chartNo)
			chartNo:="0" chartNo
	
	url:="http://hisaw.hospital-n.local/WebApplication/Radiology/RISPatientRegistration.aspx?SESSION=" sid
	
	
	if (__VIEWSTATE="" || __EVENTVALIDATION="" || !portalAspId){
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID

		httprequest(url,post:="",header,"charset: utf-8")
		portalAspId:=RegExReplace(header,"s).+ASP\.NET_SessionId=([^;]+);.+","$1")
		__VIEWSTATE:=get(post,"__VIEWSTATE")
		__EVENTVALIDATION:=get(post,"__EVENTVALIDATION")
	}
	
	
	
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	if (StartDate="")
		formattime,StartDate,% a_now,yyyy/MM/dd
		;~ StartDate:=substr(a_now,1,4) "/" substr(a_now,5,2) "/" substr(a_now,7,2)
	
	queryType:="NWeb1$uPnlQuery"
	
	if (chartNo!="" || SheetNo !="" || PatientID!="" || AccountNo!="")
		queryType.="|NWeb1$btnQueryByPatient"
	else if UnitList!=X
		queryType.="|NWeb1$ddlUnitList"
	
	formattime,now,% a_now,yyyy/MM/dd hh:mm
	
	;~ post:="NWeb1%24ScriptManager1=" queryType "&scrollLeft=&scrollTop=&__LASTFOCUS=&__EVENTTARGET=&__EVENTARGUMENT=&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&NWeb1%24ddlOrderType=X&NWeb1%24ddlUnitList=" encodeurl(UnitList) "&NWeb1%24ddlStatisticGroupCode=MRI&NWeb1%24ddlShiftType=" encodeurl(ShiftType) "&NWeb1%24ddlPatClass=" encodeurl(PatClass) "&NWeb1%24txbQueryStartDate=" encodeurl(StartDate) "&NWeb1%24ddlQueryDays=" encodeurl(QueryDays) "&NWeb1%24txbRequestSheetNo=" encodeurl(SheetNo) "&NWeb1%24txbPersonID=" encodeurl(PersonID) "&NWeb1%24txbAccountNo=" encodeurl(AccountNo) "&NWeb1%24txbChartNo=" encodeurl(ChartNo) "&NWeb1%24ddlStatisticGroupCodeFilter=&NWeb1%24cbxIsShowChartNo=on&__ASYNCPOST=true&NWeb1%24cbxIsShowChartNo=on&NWeb1%24ddlFunctionType=&NWeb1%24ddlFunctionType2=&NWeb1%24ddlNotPerformReasonList=&NWeb1%24txbExecuteDate=" encodeurl(now) "&__AjaxControlToolkitCalendarCssLoaded="
	post:="NWeb1%24ScriptManager1=" encodeurl(queryType) "&scrollLeft=&scrollTop=&__LASTFOCUS=&__EVENTTARGET=&__EVENTARGUMENT=&__VIEWSTATE=" encodeurl(__VIEWSTATE) "&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&NWeb1%24ddlOrderType=X&NWeb1%24ddlUnitList=" encodeurl(UnitList) "&NWeb1%24ddlStatisticGroupCode=MRI&NWeb1%24ddlShiftType=" encodeurl(ShiftType) "&NWeb1%24ddlPatClass=" encodeurl(PatClass) "&NWeb1%24txbQueryStartDate=" encodeurl(StartDate) "&NWeb1%24ddlQueryDays=" encodeurl(QueryDays) "&NWeb1%24txbRequestSheetNo=" encodeurl(SheetNo) "&NWeb1%24txbPersonID=" encodeurl(PersonID) "&NWeb1%24txbAccountNo=" encodeurl(AccountNo) "&NWeb1%24txbChartNo=" encodeurl(ChartNo) "&NWeb1%24ddlStatisticGroupCodeFilter=&NWeb1%24cbxIsShowChartNo=on&__ASYNCPOST=true"

	if (chartNo!="" || SheetNo !="" || PatientID!="" || AccountNo!="")
		post.="&NWeb1%24btnQueryByPatient=%E6%8E%92%E7%A8%8B%E6%9F%A5%E8%A9%A2"

	httprequest(url,post,header,"charset: utf-8")
	return post
}


class portalLib_patientLabHistory {
	__New(html){
		arr:=[]
		,ComObjError(false)
		,dom:=ComObjCreate("HtmlFile")
		,dom.write(html)
		
		loop % (tr:=dom.getElementById("TableLabHistoryNote").rows).length {
			if (td:=tr[a_index-1].cells).length <=1
				continue
			labName:=td[1].innerText
			
			ind=0
			loop % (i:=td[2].cells).length {
				if(ind:=!ind){
					RegExMatch(i[a_index-1].innerText,"is)(.+)\s([^\s]+?)$",match)
					,labValue:=match1
					,labUnit:=match2
				}else{
					labDate:=i[a_index-1].innerText
					if !isobject(arr["" labName,"" labDate]) 
						arr["" labName,"" labDate]:=[]
					arr["" labName,"" labDate].push(array("" labValue,"" labUnit))
				}
			}	
			
		}
		
		
		this.lab:=arr
	}
	
	getValue(labName){
		result:=[]
		if(!isobject(this.lab[labName]))
			return result
		
		for k,v in this.lab[labName] 
			result[k]:=v
		return result
	}
	
}

getPathoAspId(sid){
	url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/MedicalReportQuery/PathExam.aspx?SESSION=" sid
	
	header:="Accept: image/gif, image/jpeg, image/pjpeg, image/pjpeg, application/x-shockwave-flash, application/msword, application/x-ms-application, application/x-ms-xbap, application/vnd.ms-xpsdocument, application/xaml+xml, */*`nAccept-Language: zh-tw`nUser-Agent: Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; Trident/4.0; GTB7.4; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR 3.0.04506.648; .NET CLR 3.5.21022; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729)`nAccept-Encoding: gzip, deflate`nConnection: Keep-Alive`nHost: ihisaw.hospital-n.local`nCookie: NPage_MenuSettingCookie=%u5831%u544a%u7d22%u5f15%u7cfb%u7d71=Y&%u5831%u544a%u67e5%u8a62=Y"
	
		
	httprequest(url,post:="",header)
	
	RegExMatch(header,"ASP.NET_SessionId=(\w{24})",match)
	
	return match1
}

;~ getPatho("97CDB02E597943BFAC35E57968A1354E","5______")
getPatho(sid,chartNo){
	global pathoportalAspId
	
	if !pathoportalAspId
		pathoportalAspId:=getPathoAspId(sid)
		
	url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/MedicalReportQuery/PathExam.aspx"
	
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	httprequest(url "?SESSION=" sid,html:="",h:=header)
	
	
	post:="__EVENTTARGET=&__EVENTARGUMENT=&ctl07_ExpandState=eununnunnnnununnunnunnnnnununnunnn&ctl07_SelectedNode=&ctl07_PopulateLog=&__VIEWSTATE=" encodeurl(get(html,"__VIEWSTATE")) "&__EVENTVALIDATION=" encodeurl(get(html,"__EVENTVALIDATION")) "&QueryByChartNo1%24txbPatChar=" chartNo "&QueryByChartNo1%24btnPerIDPatChar=%E6%9F%A5%E8%A9%A2"
	
	httprequest(url,post,header,"charset: utf-8")
	
	dom:=ComObjCreate("HtmlFile")
	dom.write(post)
	arr:=[]
	
	loop % (rows:=dom.getElementById("PathExam_Control1_GridViewPathExamno").rows).length
	{
		if a_index=1
			continue
		cells:=rows[i:=a_index-1].cells
		arr[i,"Name"]:=trim(cells[0].innerText)
		arr[i,"PathoNo"]:=trim(cells[1].innerText)
		arr[i,"Department"]:=trim(cells[2].innerText)
		arr[i,"Ward"]:=trim(cells[3].innerText)
		arr[i,"Specimen"]:=trim(cells[4].innerText)
		arr[i,"getDate"]:="" trim(convertTaiwanDateToWestern(cells[5].innerText))
		arr[i,"reportDate"]:="" trim(convertTaiwanDateToWestern(cells[6].innerText))
		arr[i,"linkId"]:=trim(cells[7].firstChild.id)
		
	}
	
	return arr
	
}

;~ arr:=getPatho2("3______")
;~ a=1
getPatho2(chartNo){
	url:="http://converws.hospital-n.local/WebApplication/PathologyReportWS/PathologyReportWS.asmx"

	header:="SOAPAction: ""http://PathologyReportWS.hospital-n.local/GetPathReportListByChartNo""`nHost: converws.hospital-n.local`nContent-Type: text/xml; charset=utf-8"

	post=
	(
	<?xml version="1.0" encoding="utf-8"?>
	<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
	  <soap:Body>
		<GetPathReportListByChartNo xmlns="http://PathologyReportWS.hospital-n.local/">
		  <chartNo>%chartNo%</chartNo>
		</GetPathReportListByChartNo>
	  </soap:Body>
	</soap:Envelope>
	)

	httprequest(url,post,header,"charset: utf-8")
	
	;~ try
		;~ res:=new XML(clipboard:=post)
	;~ catch e
		;~ return []
	
	
	
	
	i:=0,arr:=[]
	while (i:=regexmatch(post,"is)<Table.+?<PATHCODE>(.+?)</PATHCODE><CHARTNO>" chartNo "</CHARTNO><SPECIMENGETDATE>(.+?)</SPECIMENGETDATE><REPORTDATETIME>(.+?)</REPORTDATETIME><ORGSOURCE>(.+?)</ORGSOURCE>(?:<CHECKREPORT>(.+?)</CHECKREPORT>)?</Table>",match,i+1)) {
		arr[a_index,"" "pathCode"]:="" match1
		arr[a_index,"" "getDate"]:="" dateTimeParse1(match2).str
		arr[a_index,"" "reportDate"]:="" dateTimeParse1(match3).str
		arr[a_index,"" "resource"]:="" match4
		arr[a_index,"" "report"]:="" match5
	}
	return arr
}

; if ItenName starts with //, use regex
getLabValue(byref Lab2Arr,ItemName,SpecimenName="BLOOD"){
	arr:=[],sort:=[],newArr:=[],foundCount:=0

		if(isobject(ItemName)){
			for k,v in Lab2Arr
				for m,n in ItemName
					if (InStr(n,"//")=1 && v.ItemName~=SubStr(n,3)) || (v.ItemName=n && v.SpecimenName=SpecimenName) {
						arr.push(v.clone())
						
						if ((time:=regexreplace(v.LogDateTime,"\D"))&&floor(substr(time,1,1))>1){
						}else
							time:=regexreplace(v.ReleaseDateTime,"\D")
						
						sort["" time (++foundCount)]:=(foundCount)
						
					}
						
		}else {
			for k,v in Lab2Arr
				if (InStr(ItemName,"//")=1 && v.ItemName~=SubStr(ItemName,3)) || (v.ItemName=ItemName && v.SpecimenName=SpecimenName) {
					arr.push(v.clone())
					if ((time:=regexreplace(v.LogDateTime,"\D"))&&floor(substr(time,1,1))>1){
					}else
						time:=regexreplace(v.ReleaseDateTime,"\D")
					
					sort["" time (++foundCount)]:=(foundCount)
					
				
				}
		}
	
	for k,v in sort
		newArr[foundCount+1-a_index]:=arr[v].clone()
	
	
	return newArr
}

;~ sid:=askForPortalIdPw()
;~ a:=getLab2("M001017", sid)
;~ b:=1
getLab2(chartNo,sid="",startDays=14,endDays=0,startTime="",endTime=""){
	global ptInfo,birthday,userId
	url:="http://converws.hospital-n.local/WebApplication/MedicalReportWS/MedicalReportSelectedLabItemReportWS.asmx"

	header:="SOAPAction: ""http://tempuri.org/QueryLabReportWithNormalRange""`nHost: converws.hospital-n.local`nContent-Type: text/xml; charset=utf-8"
	
	while(strlen(chartNo)<7)
		chartNo:="0" chartNo
	
	;~ if !ptInfo
		;~ ptInfo:=patientBasicInfo(chartNo,sid)
	;~ if !birthDay
		;~ birthDay:=ptInfo.birthYear "-" ptInfo.birthMonth "-" ptInfo.birthDay "T00:00:00"
	;~ if !userId
		;~ userId:=getUserId(sid)
	
	if (startTime=""){
		date:=a_now
		date+=-%startDays%,d
		FormatTime,startTime,% date,yyyy-MM-ddTHH:mm:ss
	}
	
	if (endTime=""){
		date:=a_now
		date+=-%endDays%,d
		FormatTime,endTime,% date,yyyy-MM-ddTHH:mm:ss
	}
	
	post=
	(
	<?xml version="1.0" encoding="utf-8"?>
	<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
	  <soap:Body>
		<QueryLabReportWithNormalRange xmlns="http://tempuri.org/">
		  <chartNo>%chartNo%</chartNo>
		  <birthday>1900-01-01T00:00:00</birthday>
		  <loginEmpNo>000000</loginEmpNo>
		  <startTime>%startTime%</startTime>
		  <endTime>%endTime%</endTime>
		</QueryLabReportWithNormalRange>
	  </soap:Body>
	</soap:Envelope>
	)

	httprequest(url,post,header,"charset: utf-8")
	;~ clipboard:=post
	
	
	itemName:=["SybaseAcc","PortalAcc","DeptCode","Value","itemCode","LoginNo","ItemName","UnitName","ItemNameShort","OrderCode","ACMGroupName","OrderSeqNo","SpecimenName","SpecimenCode","LogDate","LogDateTime","ReleaseDateTime","Description","ViewCondition","OperatorDefineRange","RangeResult","MaxValue","MinValue","PatientClassCode"]
	
	i:=0,arr:=[]
	;~ clipboard:=post
	while i:=RegExMatch(post,"is)<LabItem>(.+?)</LabItem>",m,i+1) {
		j:=a_index
		for k,v in itemName {
			RegExMatch(m1,"<" v ">(.+?)</" v ">",match)
			StringReplace,match1,match1,&gt;,>
			StringReplace,match1,match1,&lt;,<
			StringReplace,match1,match1,&nbsp;,%a_space%
			StringReplace,match1,match1,&quot;,"
			StringReplace,match1,match1,&amp;,&
			arr[j,v]:=match1
		}
	}
	
	
	return arr
	
	/*
	
	*/
	
	
	
	/* response-------------------------------------------
	<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <QueryLabReportWithNormalRangeResponse xmlns="http://tempurf.org/">
      <QueryLabReportWithNormalRangeResult>
        <_LabItemList>
          <LabItem>
            <ChartNo>string</ChartNo>
            <SybaseAcc>string</SybaseAcc>
            <PortalAcc>string</PortalAcc>
            <DeptCode>string</DeptCode>
            <Value>string</Value>
            <itemCode>string</itemCode>
            <LoginNo>string</LoginNo>
            <ItemName>string</ItemName>
            <UnitName>string</UnitName>
            <ItemNameShort>string</ItemNameShort>
            <OrderCode>string</OrderCode>
            <ACMGroupName>string</ACMGroupName>
            <OrderSeqNo>string</OrderSeqNo>
            <SpecimenName>string</SpecimenName>
            <SpecimenCode>string</SpecimenCode>
            <LogDate>string</LogDate>
            <LogDateTime>dateTime</LogDateTime>
            <ReleaseDateTime>dateTime</ReleaseDateTime>
            <Description>string</Description>
            <ViewCondition>string</ViewCondition>
            <OperatorDefineRange>string</OperatorDefineRange>
            <RangeResult>Normal or Over or Below or Unknown</RangeResult>
            <MaxValue>string</MaxValue>
            <MinValue>string</MinValue>
            <PatientClassCode>string</PatientClassCode>
          </LabItem>
          <LabItem>
            <ChartNo>string</ChartNo>
            <SybaseAcc>string</SybaseAcc>
            <PortalAcc>string</PortalAcc>
            <DeptCode>string</DeptCode>
            <Value>string</Value>
            <itemCode>string</itemCode>
            <LoginNo>string</LoginNo>
            <ItemName>string</ItemName>
            <UnitName>string</UnitName>
            <ItemNameShort>string</ItemNameShort>
            <OrderCode>string</OrderCode>
            <ACMGroupName>string</ACMGroupName>
            <OrderSeqNo>string</OrderSeqNo>
            <SpecimenName>string</SpecimenName>
            <SpecimenCode>string</SpecimenCode>
            <LogDate>string</LogDate>
            <LogDateTime>dateTime</LogDateTime>
            <ReleaseDateTime>dateTime</ReleaseDateTime>
            <Description>string</Description>
            <ViewCondition>string</ViewCondition>
            <OperatorDefineRange>string</OperatorDefineRange>
            <RangeResult>Normal or Over or Below or Unknown</RangeResult>
            <MaxValue>string</MaxValue>
            <MinValue>string</MinValue>
            <PatientClassCode>string</PatientClassCode>
          </LabItem>
        </_LabItemList>
        <ChartNo>string</ChartNo>
        <StartTime>dateTime</StartTime>
        <EndTime>dateTime</EndTime>
      </QueryLabReportWithNormalRangeResult>
      <errMsg>string</errMsg>
    </QueryLabReportWithNormalRangeResponse>
  </soap:Body>
</soap:Envelope>
	*/
}

;~ sid:=askForPortalIdPw()
;~ a:=getAllChartNos(sid, "N000001")
getAllChartNos(sid, chartNo){
	url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MedicalReportContent.aspx?SESSION=" sid "&PatClass=I&WardCode=12PW&ChartNo=" chartNo "&HospitalCode=T0&Seed=" A_now "&IntervalDay=0"
	header=
	(LTrim
	User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko
	Host: ihisaw.hospital-n.local
	)
	
	httprequest(url, post:="", header1:=header, "charset: utf-8")
	if !RegExMatch(post, "i)<title>([^\<]+?)<\/title>", title)
		return
	res:=RegExMatchAll(title1, "\b\w{7}\b")
	ret:=[]
	
	for k,v in res.list
		ret.push(v[0])
	
	return ret
}


dateTimeParse1(str,delim="-"){
	arr:=[]
	RegExMatch(str,"(\d{4})" delim "(\d{2})" delim "(\d{2})T(\d{2}):(\d{2}):(\d{2})((?:\+|-)(?:\d{2}):(?:\d{2}))",match)
	arr.year:=match1
	arr.month:=match2
	arr.day:=match3
	arr.hour:=match4
	arr.minute:=match5
	arr.second:=match6
	arr.zone:=match7
	arr.dateStr:=match1 fill0(match2) fill0(match3)
	arr.timeStr:=fill0(match4) fill0(match5) fill0(match6)
	arr.str:=arr.dateStr arr.timeStr
	return arr
}

convertTaiwanDateToWestern(tw,delim="/"){
	RegExMatch(tw,"(\d+)\" delim "(\d+)\" delim "(\d+)",match)
	return (match1<200?(1911+match1):match1) fill0(match2) fill0(match3)
}
;~ sid:=login(loginId,loginPw)
;~ msgbox % portalMessage(sid,"0912000000","test")
portalMessage(sid,phoneNos,msg,msgType=3){
	global portalAspId
	url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/CriticalVentilator/MessageSend.aspx?SESSION=" sid
	
	if (msgType=2)
		category:="rdbUnNormal"
	else if (msgType=1)
		category:="rdbCritical"
	else
		category:="rdbNormal"
	
	
	
	httprequest(url,html:="")
	
	header:="Accept: image/jpeg, application/x-ms-application, image/gif, application/xaml+xml, image/pjpeg, application/x-ms-xbap, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword, */*`nReferer: " url "`nAccept-Language: zh-TW`nUser-Agent: Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E; Sleipnir/2.9.14)`nContent-Type: application/x-www-form-urlencoded`nAccept-Encoding: gzip, deflate`nHost: ihisaw.hospital-n.local`nConnection: Keep-Alive`nPragma: no-cache"
	
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	post:="scrollLeft=&scrollTop=&__EVENTTARGET=NWeb1%24btnSendSMSAndEmail&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=" encodeurl(get(html,"__VIEWSTATE")) "&__EVENTVALIDATION=" encodeurl(get(html,"__EVENTVALIDATION")) "&NWeb1%24PersonIDInput=&NWeb1%24txbwardno=&NWeb1%24QueryInputByDr=&NWeb1%24PHSSendSeqNo=&NWeb1%24PHSTelNo=" phoneNos "&NWeb1%24txbEmail=&NWeb1%24MessageContent=" encodeurl(msg) "&NWeb1%24Category=" category "&NWeb1%24txbSearchID=loginId&NWeb1%24txbStartDate=2013%2F4%2F29&NWeb1%24txbEndDate=2013%2F5%2F2"
	
	httprequest(url,post,header str,"charset: utf-8")
	
	;~ clipboard:=header "`n`n" post
	
	return RegExMatch(post,"is)<script>alert.+?簡訊發送完成\\n")?true:false
	
}

;~ getOpHistory("5AC650F058384DE2BFB90BA005E3E433","3______")
getOpHistory(sid,chartNo,personId=""){
	if(personId=""){
		personId:=patientBasicInfo(chartNo,sid).personId
	}
	httprequest("http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleInfoShowUsingPlaceHolder.aspx?SESSION=" sid "&PersonID=" personId "&Func=OPNoteList&Seed=" a_now,html:="")
	
	dom:=ComObjCreate("HtmlFile")
	dom.write(html)
	arr:=[]
	
	loop {
		if((t:=getTextById(html,"TreeViewItemt" a_index-1))="")
			break
		RegExMatch(t,"is)(.+)_(\d+)\/(\d+)\/(\d+)",match)
		arr["" match2 match3 match4]:=match1
	}
	
	return arr
}


;~ sid:=login(loginId,loginPw)
;~ clipboard:=searchLab4(chartNo,sid)
;~ getLab4(sid,chartNo)

getLab4(sid,chartNo){
	global portalAspId
	
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MedicalReportOpen.aspx"
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	
}

htmlEscapeBack(str){
	static escapeCode:="&euro;,&nbsp;,&quot;,&amp;,&lt;,&gt;,&iexcl;,&cent;,&pound;,&curren;,&yen;,&brvbar;,&sect;,&uml;,&copy;,&ordf;,&not;,&reg;,&macr;,&deg;,&plusmn;,&sup2;,&sup3;,&acute;,&micro;,&para;,&middot;,&cedil;,&sup1;,&ordm;,&raquo;,&frac14;,&frac12;,&frac34;,&iquest;,&Agrave;,&Aacute;,&Acirc;,&Atilde;,&Auml;,&Aring;,&AElig;,&Ccedil;,&Egrave;,&Eacute;,&Ecirc;,&Euml;,&Igrave;,&Iacute;,&Icirc;,&Iuml;,&ETH;,&Ntilde;,&Ograve;,&Oacute;,&Ocirc;,&Otilde;,&Ouml;,&times;,&Oslash;,&Ugrave;,&Uacute;,&Ucirc;,&Uuml;,&Yacute;,&THORN;,&szlig;,&agrave;,&aacute;,&acirc;,&atilde;,&auml;,&aring;,&aelig;,&ccedil;,&egrave;,&eacute;,&ecirc;,&euml;,&igrave;,&iacute;,&icirc;,&iuml;,&eth;,&ntilde;,&ograve;,&oacute;,&ocirc;,&otilde;,&ouml;,&divide;,&oslash;,&ugrave;,&uacute;,&ucirc;,&uuml;,&yacute;,&thorn;"
	static characters:="€ ""&<>¡¢£¤¥¦§¨©ª¬®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþ"
	
	i:=0
	s:=str
	while RegExMatch(s,"&([\w\d#]+?);",m,i+1) {
		if RegExMatch(m,"#(\d+)",n) {
			s:=RegExReplace(s,m,chr(n1))
		}else {
			loop,parse,escapeCode,`,
				if(a_loopfield=m) {
					s:=RegExReplace(s,m,substr(characters,a_index,1))
					break
				}
		}
	}
	
	
	return s
	
}

OpdHxArrToCSV(byref arr,chartNo){
	
	
	csv:=""
	csv.="""病歷號"",""性別"",""生日年"",""生日月"",""生日日"",""姓名"",""門診日期"",""診斷"",""處方"",""醫令"",""年齡"",""帳號"",""院區"",""部門"",""主治醫師"",""Subjective"",""Objective"",""未來影像檢查排程"",""未來其他檢查排程"",""未來門診預約""`n"
	
	for k,v in arr {
		
		csv.=OpdHxToCSV(v,chartNo)
		
	}
	
	return csv
	
}

escapeQuote(str){
	return trim(RegExReplace(str,"""",""""""))
}

OpdHxToCSV(html,chartNo){
	v:=parseOpdHx(html)
	csv:=""
	
	csv.= """" escapeQuote(chartNo) ""","
	csv.= """" escapeQuote(v.gender) ""","
	RegExMatch(v.birthDay,"(\d+)\/(\d+)\/(\d+)",match)
	csv.= """" escapeQuote(match1) ""","
	csv.= """" escapeQuote(match2) ""","
	csv.= """" escapeQuote(match3) ""","
	csv.= """" escapeQuote(v.name) ""","
	csv.= """" escapeQuote(v.OpdDate) ""","
	
	str:=""
	for x,y in v.diagnosis
		str.= y.1 "," y.2 "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) ""","
	
	str:=""
	for x,y in v.drug
		str.= y.name " | " y.dose " | " y.frequency " | " y.duration " | " y.totalAmount " | " y.ifChronic " | " y.orderDate " | " y.specialOrder "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) ""","	
	
	str:=""
	for x,y in v.order
		str.= y "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) ""","		
	
	
	csv.= """" escapeQuote(v.age) ""","
	csv.= """" escapeQuote(v.account) ""","
	csv.= """" escapeQuote(v.hospital) ""","
	csv.= """" escapeQuote(v.department) ""","
	csv.= """" escapeQuote(v.VS) ""","
	csv.= """" escapeQuote(v.subjective) ""","
	csv.= """" escapeQuote(v.objective) ""","
	
	str:=""
	for x,y in v.imageSchedule
		str.= y.date " | " y.timeShift " | " y.examRoom " | " y.number " | " y.orderName "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) ""","	
	
	str:=""
	for x,y in v.examSchedule
		str.= y.date " | " y.timeShift " | " y.examRoom " | " y.number " | " y.orderName "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) ""","	
	
	str:=""
	for x,y in v.FutureSchedule
		str.= y.date " | " y.timeShift " | " y.department " | " y.OpdNo " | " y.number " | " y.VS "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) """`n"	
	
	return csv
}


parseOpdHx(byref html){
	arr:=[]
	
	dom:=ComObjCreate("HtmlFile")
	dom.write(html)
	
	str:=$(dom,"TablePatientBasic").rows[1].innerText
	regexmatch(str,regex:="is)([^\s]+)\s+?\((\w),\s+?(\w+),\s+?([^)]+)\)",match)
	arr.name:=match1
	arr.gender:=match2
	arr.age:=match3
	arr.birthDay:=match4
	
	str:=$(dom,"TablePatientBasic").rows[2].innerText
	regexmatch(str,regex:="is)([^\s]+)\s+?([^\s]+)\s+?([^\s]+)\s+?主治醫師：([^\s]+)\s+?看診日期：([\d\/]+)",match)
	arr.account:=match1
	arr.hospital:=match2
	arr.department:=match3
	arr.VS:=match4
	arr.OpdDate:=match5
	
	arr.subjective:=htmlEscapeBack($(dom,"TableSubjectContent").rows[1].innerText)
	arr.objective:=htmlEscapeBack($(dom,"TableObjectContent").rows[1].innerText)
	
	dx:=[]
	loop % $(dom,"TableDiagnosis").rows.length {
		RegExMatch($(dom,"TableDiagnosis").rows[a_index-1].innerText,"is)([^,]+),\s+?(.+)",match)
		dx.push(array("" match1, "" htmlEscapeBack(match2)))
	}
	arr.diagnosis:=dx
	
	if $(dom,"TablePlanningContent").rows[1].getElementsByTagName("TABLE").length=0
		arr.plan:=$(dom,"TablePlanningContent").rows[1].innerText
	
	drug:=[]
	loop % (tr:=$(dom,"TableDrugData").rows).length-2 {
		d:=[],td:=tr[a_index+1].cells
		if ((name:=htmlEscapeBack(td[0].innerText))="") || td.length<8 {
			drug[drug.maxIndex(),"specialOrder"]:="" tr[a_index+1].innerText
			continue
		}
		d.name:="" name
		d.dose:="" td[1].innerText
		d.frequency:="" td[2].innerText
		d.duration:="" td[3].innerText
		d.totalAmount:="" td[4].innerText
		d.ifChronic:="" td[5].innerText
		d.orderDate:="" td[6].innerText
		drug.push(d.clone())
	}
	arr.drug:=drug
	
	order:=[]
	loop % (tr:=$(dom,"TableOrderInfo").rows).length-1 {
		contents:=RegExReplace(tr[a_index].cells[0].innerHTML,"is)<br\s*(\/)?>","ω")
		loop,parse,contents,ω
		{
			;~ ifDC:=""
			;~ if regexmatch(a_loopfield,"is)<span\s+?style=""?text-decoration\:\s*?line\-through""?[^>]*?>(.+)<\/span>",match)
				;~ ifDC:="(DC!)",a_loopfield:=decodeurl(match1)
			if ((txt:=trim(htmlEscapeBack(regexreplace(a_loopfield,"is)<span[^>]+?line-through[^>]+?>.+?<\/span>"))))!="")
				order.push(RegExReplace(txt,",$"))
		}
	}
	arr.order:=order
	
	
	imageSchedule:=[]
	loop % (tr:=dom.getElementById("TableImageSchedule").rows).length-2 {
		i:=[],td:=tr[a_index+1].cells
		if(instr(tr.innerText,"未來一般檢查排程")||instr(tr.innerText,"日期"))
			continue
		i.date:=td[0].innerText
		i.timeShift:=td[1].innerText
		i.examRoom:=htmlEscapeBack(td[2].innerText)
		i.number:=td[3].innerText
		i.orderName:=htmlEscapeBack(td[4].innerText)
		imageSchedule.push(i.clone())
	}
	arr.imageSchedule:=imageSchedule
	
	if ((table:=dom.getElementById("TableImageSchedule").nextSibling).tagName="TABLE"&&instr(table.innerText,"未來一般檢查排程")) {
		examSchedule:=[]
		loop % (tr:=table.rows).length-2 {
			e:=[],td:=tr[a_index+1].cells
			e.date:=td[0].innerText
			e.timeShift:=td[1].innerText
			e.examRoom:=htmlEscapeBack(td[2].innerText)
			e.number:=td[3].innerText
			e.orderName:=htmlEscapeBack(td[4].innerText)
			examSchedule.push(e.clone())
		}
		arr.examSchedule:=examSchedule
	}
	
	
	
	FutureSchedule:=[]
	loop % (tr:=$(dom,"TableFutureSchedule").rows).length-2 {
		f:=[],td:=tr[a_index+1].cells
		f.date:=td[0].innerText
		f.timeShift:=td[1].innerText
		f.department:=htmlEscapeBack(td[2].innerText)
		f.OpdNo:=td[3].innerText
		f.number:=td[4].innerText
		f.VS:=td[5].innerText
		FutureSchedule.push(f.clone())
	}
	arr.FutureSchedule:=FutureSchedule
	
	return arr
}
parseOldOpdHx(byref html){
	arr:=[]
	
	dom:=ComObjCreate("HtmlFile")
	dom.write(html)
	loop % (elm:=dom.body.childNodes).length {
		title:=trim((tr:=elm[a_index-1].firstChild.childNodes)[0].innerText)
		if(title="基本資料"){
			RegExMatch(tr[1].innerText,"([^\s]+)\s*?\((\w),([\d\/]+)\)\s*?\(電話\)([^\s]*?)\s*?\(手機\)([^\s]*?)\s*?\(住址\)([^\n]*)",match)
			arr.name:=match1
			arr.gender:=match2
			arr.birthDay:=match3
			arr.phone:=match4
			arr.cellPhone:=match5
			arr.address:=match6
		}else if(title="帳號資料"){
			RegExMatch(tr[1].innerText,"N醫院([^\s]+) 科部：([^\s]+) 主治醫師：([^\s]+) 看診時間：([\d\/]+)",match)
			arr.hospital:=match1
			arr.department:=match2
			arr.VS:=match3
			arr.OpdDate:=match4
		}else if(title="病歷內容"){
			arr.chart:=htmlEscapeBack(tr[1].innerText)
		}else if(title="診斷內容"){
			dx:=[],text:=tr[1].innerText
			StringReplace,text,text,`,(,¢
			temp:=""
			loop,parse,text,¢
			{
				if(RegExMatch(a_loopfield,"^\w)")){
					if(temp)
						dx.push(htmlEscapeBack(temp)),temp:=A_LoopField
				}else{
					temp.=a_loopfield
				}
			}
			dx.push(RegExReplace(htmlEscapeBack(temp),",\s?$"))
			arr.diagnosis:=dx
		}else if(title="處方內容"){
			drug:=[]
			loop % tr.length-2 {
				d:=[]
				name:=(td:=tr[a_index+1].childNodes)[0].innerText
				d.route:=td[1].innerText
				d.dose:=td[2].innerText
				d.frequency:=td[3].innerText
				d.duration:=td[4].innerText
				d.totalAmount:=td[5].innerText
				d.ifChronic:=td[6].innerText
				d.specialOrder:=htmlEscapeBack(td[7].innerText)
				drug["" name]:=d
			}
			arr.drug:=drug
		}else if(title="醫令內容"){
			order:=[]
			loop % tr.length-1 {
				order.push(htmlEscapeBack(tr[a_index].innerText))
			}
			arr.order:=order
		}
		
	}
	return arr
	
}

OldOpdHxToCSV(byref html,chartNo){
	v:=parseOldOpdHx(html)
	csv:=""
	
	csv.= """" escapeQuote(chartNo) ""","
	csv.= """" escapeQuote(v.gender) ""","
	RegExMatch(v.birthDay,"(\d+)\/(\d+)\/(\d+)",match)
	csv.= """" escapeQuote(match1) ""","
	csv.= """" escapeQuote(match2) ""","
	csv.= """" escapeQuote(match3) ""","
	csv.= """" escapeQuote(v.name) ""","
	csv.= """" escapeQuote(v.OpdDate) ""","
	
	;;
	str:=""
	for x,y in v.diagnosis
		str.= y "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) ""","
	
	str:=""
	for x,y in v.drug
		str.= x " | " y.dose " | " y.frequency " | " y.duration " | " y.totalAmount " | " y.ifChronic " |  | " y.route " | " y.specialOrder "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) ""","	
	
	str:=""
	for x,y in v.order
		str.= y "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) ""","		
	
	
	csv.= """" escapeQuote(v.age) ""","
	csv.= """" escapeQuote(v.account) ""","  ;;;
	csv.= """" escapeQuote(v.hospital) ""","
	csv.= """" escapeQuote(v.department) ""","
	csv.= """" escapeQuote(v.VS) ""","
	;~ csv.= """" escapeQuote(v.subjective) ""","  ;;;
	csv.= """" escapeQuote(v.chart) ""","  ;;;
	csv.= """" escapeQuote(v.objective) ""","  ;;;
	
	return csv ","""","""",""""`n"
	
	str:=""
	for x,y in v.imageSchedule
		str.= y.date " | " y.timeShift " | " y.examRoom " | " y.number " | " y.orderName "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) ""","	
	
	str:=""
	for x,y in v.examSchedule
		str.= y.date " | " y.timeShift " | " y.examRoom " | " y.number " | " y.orderName "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) ""","	
	
	str:=""
	for x,y in v.FutureSchedule
		str.= y.date " | " y.timeShift " | " y.department " | " y.OpdNo " | " y.number " | " y.VS "`n"
	csv.= """" escapeQuote(regexreplace(str,"\n?$")) """`n"	
	
	
}


;~ replyConsult(sid,AccountIDSE,NotifyIDSE,ReplyContent,Diagnosis,Suggestion){
	;~ global __VIEWSTATE,__EVENTVALIDATION,portalAspId
	
	;~ url:="http://tihisaw.hospital-n.local/WebApplication/InPatient/Ward/NotifyOtherDoctor.aspx?SESSION=" sid "&AccountIDSE=" AccountIDSE "&NotifyIDSE=" NotifyIDSE
	
	;~ httprequest(url,html:="",header:="","charset: utf-8")
	
	;~ RegExMatch(header,"i)ASP\.NET_SessionId=\w{24}",portalAspId)
	
	;~ header:="Referer: " url "`nHost: tihisaw.hospital-n.local`nCookie: " portalAspId
	
	;~ post:="__EVENTTARGET=NWeb1%24btnRecordFisrtAnalysisTime&__VIEWSTATE=" encodeurl(__VIEWSTATE:=get(html,"__VIEWSTATE")) "&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION:=get(html,"__EVENTVALIDATION")) "&NWeb1%24TextboxReplyContent=" ReplyContent "&NWeb1%24TextboxDiagnosis=" Diagnosis "&NWeb1%24TextboxSuggestion=" Suggestion "&hiddenInputToUpdateATBuffer_CommonToolkitScripts=1"
	
	;~ httprequest(url,post,header,"charset: utf-8")

;~ }

/* 
params:
startYear
startMonth
startDay
endYear
endMonth
endDate
DeptCode
userId
ward
hospital
patientId
*/
consultInfo(sid,queryBy="",byref params="",html="",parse=1){
	if (params="")
		params:=[]
	if (queryBy="")
		queryBy:="NWeb1$QueryNotifyContent"
	
	if queryBy=Dept
		queryBy=NWeb1$ButtonQueryByDept
	
	
	
	global __VIEWSTATE,__EVENTVALIDATION,portalAspId,__VIEWSTATEGENERATOR
	
	if (__VIEWSTATE="" || __EVENTVALIDATION="" || portalAspId="" || __VIEWSTATEGENERATOR="")
		httprequest(url:="http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/QueryNotifyRecordByDr.aspx?SESSION=" sid,html:="",header:="","charset: utf-8")	
		,RegExMatch(header,"i)ASP\.NET_SessionId=\w{24}",portalAspId)
	
	header:="Accept: image/gif, image/jpeg, image/pjpeg, image/pjpeg, application/x-shockwave-flash, application/msword, application/xaml+xml, application/vnd.ms-xpsdocument, application/x-ms-xbap, application/x-ms-application, */*`nReferer: " url "`nAccept-Language: zh-tw`nContent-Type: application/x-www-form-urlencoded`nAccept-Encoding: gzip, deflate`nHost: ihisaw.hospital-n.local`nPragma: no-cache`nCookie: " portalAspId 
	
	
	endDate:=startDate:=a_now
	if(!params.endYear)
		params.endYear:=substr(endDate,1,4)
	if(!params.endMonth)
		params.endMonth:=substr(endDate,5,2)*1
	if(!params.endDay)
		params.endDay:=substr(endDate,7,2)*1
	
	startDate+=-3,D
	if(!params.startYear)
		params.startYear:=substr(startDate,1,4)
	if(!params.startMonth)
		params.startMonth:=substr(startDate,5,2)*1
	if(!params.startDay)
		params.startDay:=substr(startDate,7,2)*1
	
	
	if (queryBy="NWeb1$ButtonQueryByDept"){
		post:="scrollLeft=0&scrollTop=0&__EVENTTARGET=" encodeurl("NWeb1$NotDepartSelectionObj$ddlDeptCode") "&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=" encodeurl(__VIEWSTATE:=get(html,"__VIEWSTATE")) "&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION:=get(html,"__EVENTVALIDATION")) "&NWeb1%24DateTextBoxYearMonthDayStart%24YearInput=" params.startYear "&NWeb1%24DateTextBoxYearMonthDayStart%24MonthInput=" params.startMonth "&NWeb1%24DateTextBoxYearMonthDayStart%24DayInput=" params.startDay "&NWeb1%24DateTextBoxYearMonthDayEnd%24YearInput=" params.endYear "&NWeb1%24DateTextBoxYearMonthDayEnd%24MonthInput=" params.endMonth "&NWeb1%24DateTextBoxYearMonthDayEnd%24DayInput=" params.endDay "&NWeb1%24NotDepartSelectionObj%24ddlHospitalCode=" ((hospital:=params.hospital)?hospital:"T0") "&NWeb1%24NotDepartSelectionObj%24ddlDeptCode=" params.DeptCode "&NWeb1%24DropDownListPatClass=&NWeb1%24PersonIDInput=" ((id:=params.userId)?id:getUserid(sid)) "&NWeb1%24DropDownListWardCode=" params.ward "&NWeb1%24txbChartNo=" params.chartNo "&NWeb1%24txbPatientPID=" params.patientId "&NWeb1%24QueryDrIDInfoByDrName1%24EmpNoQueryInput=&NWeb1%24HiddenFieldHospitalCode=T0&NWeb1%24NotDepartSelectionObj%24ddlSubDept=&__VIEWSTATEGENERATOR=" encodeurl(__VIEWSTATEGENERATOR:=get(html,"__VIEWSTATEGENERATOR"))
    	httprequest(url,html:=post,header1:=header,"charset: utf-8")

	}
	
	
	post:="scrollLeft=0&scrollTop=0&__EVENTTARGET=" encodeurl(queryBy) "&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=" encodeurl(__VIEWSTATE:=get(html,"__VIEWSTATE")) "&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION:=get(html,"__EVENTVALIDATION")) "&NWeb1%24DateTextBoxYearMonthDayStart%24YearInput=" params.startYear "&NWeb1%24DateTextBoxYearMonthDayStart%24MonthInput=" params.startMonth "&NWeb1%24DateTextBoxYearMonthDayStart%24DayInput=" params.startDay "&NWeb1%24DateTextBoxYearMonthDayEnd%24YearInput=" params.endYear "&NWeb1%24DateTextBoxYearMonthDayEnd%24MonthInput=" params.endMonth "&NWeb1%24DateTextBoxYearMonthDayEnd%24DayInput=" params.endDay "&NWeb1%24NotDepartSelectionObj%24ddlHospitalCode=" ((hospital:=params.hospital)?hospital:"T0") "&NWeb1%24NotDepartSelectionObj%24ddlDeptCode=" params.DeptCode "&NWeb1%24DropDownListPatClass=&NWeb1%24PersonIDInput=" ((id:=params.userId)?id:getUserid(sid)) "&NWeb1%24DropDownListWardCode=" params.ward "&NWeb1%24txbChartNo=" params.chartNo "&NWeb1%24txbPatientPID=" params.patientId "&NWeb1%24QueryDrIDInfoByDrName1%24EmpNoQueryInput=&NWeb1%24HiddenFieldHospitalCode=T0&NWeb1%24NotDepartSelectionObj%24ddlSubDept=&__VIEWSTATEGENERATOR=" encodeurl(__VIEWSTATEGENERATOR:=get(html,"__VIEWSTATEGENERATOR"))
	
	httprequest(url,post,header,"charset: utf-8")
	
	if !parse
		return post
	
	dom:=ComObjCreate("HtmlFile")
	dom.write(post)
	arr:=[]
	
	if !(table:=$(dom,"NWeb1_NotifyDrRecord"))
		return arr
	
	vsName:=getUserName(params.userId,sid)
	
	loop % (tr:=table.rows).length-1 {
		if(instr(tr[a_index].innerHTML,"line-through"))
			continue
		
		vs:="" trim((td:=tr[a_index].cells)[9].innerText)
		R:="" trim(td[10].innerText)
		replyBy:="" trim(td[11].innerText)
		GCA:="" trim(td[12].innerText)
		if(params.userId && vsName!=vs && vsName!=R && vsName!=replyBy && vsName!=GCA)
			continue
		if !(time:=trim(RegExReplace(td[4].firstChild.title,"[\/\s:]")))
			continue
		
		row:=[]
		RegExMatch(td[1].firstChild.title,"is)T0-(.+)分機:(.+)",match)
		row.department:="" (d:=RegExReplace(match1,"\s"))?d:td[1].innerText
		row.departmentPhone:="" trim(match2)
		row.chartNo:="" trim(td[2].innerText)
		row.notifyId:="" td[2].firstChild.title
		row.account:="" trim(td[3].firstChild.title)
		RegExMatch(td[3].innerText,"is)([^\(]+)\((\w),([^\)]+)\)",match)
		row.name:=match1,row.gender:=match2,row.age:=match3
		row.time:=time
		row.type:="" trim(td[5].innerText)
		row.type2:=td[5].firstChild.title
		row.consulter:="" trim(td[6].innerText)
		RegExMatch(td[6].firstChild.title,"\d+",match)
		row.consulterPhone:=match
		row.purpose:=td[7].firstChild.title
		row.consulted:="" trim(td[8].innerText)
		row.VS:=vs
		RegExMatch(td[9].firstChild.title,"\d+",match)
		row.Rphone:=match
		row.R:=R
		RegExMatch(td[10].firstChild.title,"\d+",match)
		row.Rphone:=match
		row.replyBy:=replyBy
		row.GCA:=GCA
		row.status:="" trim(td[13].innerText)
		row.leftTime:="" trim(td[14].innerText)
		
		arr.push(row.clone())
	}
	
	return arr
}

getConsult(sid,accountIDSE,notifyIDSE,PatClass){
	seed2:=(substr(a_now,9,2)<12?"上午":"下午") " " substr(a_now,11,2) ":" substr(a_now,13,2) ":" substr(a_now,15,2)
	url:="http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/NotifyOtherDoctor.aspx?SESSION=" sid "&AccountIDSE=" accountIDSE "&NotifyIDSE=" notifyIDSE  "&Reply=Y&Seed=" seed2
	
	httprequest(url,html:="",header:="","charset: utf-8`n+NO_COOKIES")
	return html
	
}


replyConsult(sid,accountIDSE,notifyIDSE,PatClass,replyContent,diagnosis,suggestion,byref params=""){
	
	seed1:=(substr(a_now,9,2)<12?"%ufffdU%ufffd%ufffd":"%ufffdU%ufffd%ufffd") "+" substr(a_now,11,2) "%3a" substr(a_now,13,2) "%3a" substr(a_now,15,2)
	seed2:=(substr(a_now,9,2)<12?"上午":"下午") " " substr(a_now,11,2) ":" substr(a_now,13,2) ":" substr(a_now,15,2)
	
	url:="http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/NotifyOtherDoctor.aspx?SESSION=" sid "&AccountIDSE=" accountIDSE "&NotifyIDSE=" notifyIDSE  "&Reply=Y&Seed=" seed1
	
	referer:="http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/NotifyOtherDoctor.aspx?SESSION=" sid "&AccountIDSE=" accountIDSE "&NotifyIDSE=" notifyIDSE  "&Reply=Y&Seed=" seed2
	
	
	html:=getConsult(sid,accountIDSE,notifyIDSE,PatClass)
	
	
	
	dom:=ComObjCreate("HtmlFile")
	dom.write(html)
	
	
	
	header:="Accept: image/jpeg, application/x-ms-application, image/gif, application/xaml+xml, image/pjpeg, application/x-ms-xbap, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword, */*`nReferer: " referer "`nAccept-Language: zh-TW`nUser-Agent: Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)`nContent-Type: application/x-www-form-urlencoded`nAccept-Encoding: gzip, deflate`nHost: ihisaw.hospital-n.local`nConnection: Close`nPragma: no-cache"
	
	post:="scrollLeft=0&scrollTop=0&__EVENTTARGET=NWeb1%24btnRecordFisrtAnalysisTime&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=" encodeurl($(dom,"__VIEWSTATE").value) "&__EVENTVALIDATION=" encodeurl($(dom,"__EVENTVALIDATION").value) "&NWeb1%24TextboxMainPurpose=" regexreplace(encodeurl($(dom,"NWeb1_TextboxMainPurpose").value),"%20","+") "&NWeb1%24TextboxDescription=" regexreplace(encodeurl($(dom,"NWeb1_TextboxDescription").value),"%20","+") "&NWeb1%24TextboxReplyContent=" regexreplace(encodeurl(replyContent),"%20","+") "&NWeb1%24TextboxDiagnosis=" regexreplace(encodeurl(diagnosis),"%20","+") "&NWeb1%24TextboxSuggestion=" regexreplace(encodeurl(suggestion),"%20","+") "&NWeb1%24atxbGCAEmpNo%24txbContent=" (params.VS?params.VS:$(dom,"NWeb1_atxbGCAEmpNo_txbContent").value) "&NWeb1%24TextboxCostCenterInput=" (params.costCenter?params.costCenter:$(dom,"NWeb1_TextboxCostCenterInput").value) "&hiddenInputToUpdateATBuffer_CommonToolkitScripts=1&__VIEWSTATEGENERATOR=" encodeurl($(dom,"__VIEWSTATEGENERATOR").value)
	
	httprequest(url,post,header,"charset: utf-8`n+NO_COOKIES")
	
	return 1
	;~ return !!(instr(post,"<script>alert(""成功產生照會醫令") || instr(post,"<script>alert(""\n初次評估完成"");"))
	
		
	
}

;~ askForPortalIdPw(0,1,"A")
;~ ExitApp
;  __askforportalidpw
askForPortalIdPw(opt=0, check_valid=true, hospital=0, exitapp=true){
	global loginId,loginPw,sid,askForPortalIdPw_loginId,askForPortalIdPw_loginPw,askForPortalIdPw_loginId_hwnd, askForPortalIdPwHwnd, ____, thisPlace
	
	if InStr(thisPlace, "C hospital")
		return
	
	priorSid:=Sid
	,branch:=""
	,prompt1:="ID"
	,prompt2:="Password"
	if hospital=0 
		key1:="loginId"
		,key2:="loginPw"
		
	else if hospital=H
		key1:="H_ID"
		,key2:="H_PW"
		;~ ,prompt1.=" (H branch)"
		;~ ,prompt2.=" (H branch)"
		,branch:="(H分院)"
	else if hospital=Y
		key1:="Y_ID"
		,key2:="Y_PW"
		;~ ,prompt1.=" (Y branch)"
		;~ ,prompt2.=" (Y branch)"
		,branch:="(Y分院)"
	else if hospital=A
		key1:="C_ID"
		,key2:="C_PW"
		,branch:="(C分院)"
	else if hospital=J
		key1:="J_ID"
		,key2:="J_PW"
		,branch:="(J分院)"
	
	
	if fileexist("portal.ini")
		path:="portal.ini"
	else if fileexist((dir:=regexreplace(a_scriptdir,"[/\\][^/\\]+$")) "\portal.ini")
		path:=dir "\portal.ini"
	
	CryptFilePW()
	AES_pw:="MOCK_AES_KEY"
	if(!opt){
		enc_dec:=""
		if(loginId=""&&loginPw=""&&fileexist(path)){
			iniread,loginId,% path,login,% key1
			iniread,loginPw,% path,login,% key2
			;~ Hex_Bin(enc_dec,loginPw)
			;~ ,size:=Crypt_AES(&enc_dec, floor(strlen(loginPw)/2), AES_pw, 256, 0)
			;~ ,loginPw:=substr(substr(enc_dec,1,size),1,size-16)
			if (loginPw!="" && loginPw!="ERROR")
				try
					loginPw:=Crypt.Encrypt.StrDecrypt(loginPw,____,7,6)
				catch 
					loginPw:=""
			if (loginPw="")
				try
					loginPw:=Crypt.Encrypt.StrDecrypt(loginPw,AES_pw,7,6)
				catch 
					loginPw:=""
		}
		if i:=InStr(loginPw, "!@#" loginId "$%^")
			loginPw:=SubStr(loginPw,1,i-1) SubStr(loginPw, i+StrLen(loginId)+6)
		priorPw:=loginPw
		,priorId:=loginId
	}else{
		priorPw:=loginPw
		,priorId:=loginId
		,loginId:="",loginPw:=""
	}
	if !(check_valid)
		return
	
	ToolTip % "Login portal..."
	while (loginPw="") || (!checkSid(sid:=Login(loginId,loginPw, hospital))) {
		ToolTip % "Login portal..."
		if (a_index>50) {
			msgbox % Can not login Portal !!
			exitapp
		}
		
		
		if(A_Index>=2 && loginId="canceled" && !opt){
			if ExitApp
				ExitApp
			else 
				return -1
		}
		
		gui,askForPortalIdPw:new,+hwndaskForPortalIdPwHwnd -Resize -MaximizeBox  -MinimizeBox +Owner +LabelaskForPortalIdPw
		gui,add,Text,,% A_ScriptName " asking for portal id/pw " branch " ..."
		gui,add,Text,,% prompt1
		gui,add,Edit,% "vaskForPortalIdPw_loginId hwndaskForPortalIdPw_loginId_hwnd",% (loginId="ERROR")?"":loginId
		gui,add,Text,,% prompt2
		gui,add,Edit,% "vaskForPortalIdPw_loginPw password"
		gui,add,button,% "gaskForPortalIdPw_submit default",% "Login"
		gui,Show,% "center autosize",% "Portal Login"
		Edit_SetSel(askForPortalIdPw_loginId_hwnd,0,-1)
		WinWaitClose, ahk_id %askForPortalIdPwHwnd%
		
		
		
		if(loginId="canceled")
			loginId:=priorId
		
		;~ loop {
			;~ ToolTip
			;~ inputbox,loginId,Portal login ID,% prompt1,,300,150,,,,,% (loginId="ERROR")?"":loginId
			;~ if (errorlevel && !opt){
				;~ if ExitApp
					;~ ExitApp
				;~ else 
					;~ return -1
			;~ }
				
			;~ else if (errorlevel) {
				;~ loginId:=priorId,loginPw:=priorPw,Sid:=priorSid
				;~ return
			;~ }
		;~ } until loginId!=""
		
		;~ loop {
			;~ inputbox,loginPw,Portal login password,% prompt2,Hide,300,150
			;~ if (errorlevel && !opt){
				;~ if ExitApp
					;~ ExitApp
				;~ else 
					;~ return -1
			;~ }
			;~ else if (errorlevel){
				;~ loginId:=priorId,loginPw:=priorPw,Sid:=priorSid
				;~ return
			;~ }
		;~ } until loginPw!=""
		;~ sleep 200
	}
	ToolTip 
	;~ enc_dec:=loginPw "0123456789abcdef"
	;~ ,size:=Crypt_AES(&enc_dec, strlen(enc_dec), AES_pw, 256, 1)
	;~ ,encloginPw:=Bin_Hex(enc_dec,size,32,"")
	
	
	Random,rand,0,% StrLen(loginPw)
	loginPw_:=rand=0?"!@#" loginId "$%^" loginPw:(SubStr(loginPw,1,rand) "!@#" loginId "$%^" SubStr(loginPw, rand+1))
	
	encloginPw:=Crypt.Encrypt.StrEncrypt(loginPw_,____,7,6)
	
	
	if !fileexist(path)
		path:="portal.ini"
	
	if !opt && (encloginPw!="") {
		iniwrite,% loginId,% path,login,% key1
		iniwrite,% encloginPw,% path,login,% key2
	}
	return sid
	
	askForPortalIdPwGuiClose:
	askForPortalIdPwGuiEscape:
	loginId:=loginPw:="canceled"
	gui,askForPortalIdPw:Destroy
	;~ WinClose, ahk_id %askForPortalIdPwHwnd%
	return 
	askForPortalIdPw_submit:
	GuiControlGet,loginId,askForPortalIdPw:,askForPortalIdPw_loginId
	GuiControlGet,loginPw,askForPortalIdPw:,askForPortalIdPw_loginPw
	gui,askForPortalIdPw:Destroy
	;~ WinClose, ahk_id %askForPortalIdPwHwnd%
	return
}

getOptionByText(byref el,str){
	if(el.tagName="select"){
		loop % el.options.length {
			if instr(el.options[a_index-1].innerText,str)
				return object("index",a_index-1,"value",el.options[a_index-1].value)
		}
	}
}

;~ clipboard:=queryDigiSign("MOCK_SESSION_TOKEN",loginId)
queryDigiSign(sid,id){
	global __VIEWSTATE,__EVENTVALIDATION,portalAspId
	
	url:="http://ihisaw.hospital-n.local/WebApplication/DigitalSignature/DSQuery.aspx?SESSION=" sid
	if (!__VIEWSTATE || !__EVENTVALIDATION || !portalAspId) {
		header:="Host: ihisaw.hospital-n.local`nUser-Agent: Mozilla/5.0 (Windows NT 5.1; rv:29.0) Gecko/20100101 Firefox/29.0`nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8`nAccept-Language: en-US,en;q=0.5`nAccept-Encoding: gzip, deflate`nConnection: keep-alive"
		
		,httprequest(url,html:="",header,"charset: utf-8")
		,portalAspId:=RegExReplace(header,"s).+ASP\.NET_SessionId=([^;]+);.+","$1")
		,__VIEWSTATE:=get(html,"__VIEWSTATE")
		,__EVENTVALIDATION:=get(html,"__EVENTVALIDATION")
	}
	
	while strlen(id)<6
		id:="0" id
	
	formattime,date,% a_now,yyyy/MM/dd
	
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	,post:="scrollLeft=0&scrollTop=0&__EVENTTARGET=NWeb1%24txbEmpNO&__EVENTARGUMENT=&__LASTFOCUS=&__VIEWSTATE=" encodeurl(__VIEWSTATE) "&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&NWeb1%24txbEmpNO=" id "&NWeb1%24txbPinCode=&NWeb1%24txtSDateChar=" encodeurl(date) "&NWeb1%24txtSDateChar_MaskedEditExtender_ClientState=&NWeb1%24txtEDateChar=" encodeurl(date) "&NWeb1%24txtEDateChar_MaskedEditExtender_ClientState="
	
	,httprequest(url,post,header,"charset: utf-8")
	
	return post
	
}
;~ clipboard:=queryDigiSignN("MOCK_SESSION_TOKEN","000000")
queryDigiSignN(sid,id){
	global __VIEWSTATE,__EVENTVALIDATION,portalAspId,loginId
	
	url:="http://ihisaw.hospital-n.local/WebApplication/DigitalSignature/DrugGivenDS.aspx?SESSION=" sid
	if (!__VIEWSTATE || !__EVENTVALIDATION || !portalAspId) {
		header:="Host: ihisaw.hospital-n.local`nUser-Agent: Mozilla/5.0 (Windows NT 5.1; rv:29.0) Gecko/20100101 Firefox/29.0`nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8`nAccept-Language: en-US,en;q=0.5`nAccept-Encoding: gzip, deflate`nConnection: keep-alive"
		
		httprequest(url,html:="",header,"charset: utf-8")
		portalAspId:=RegExReplace(header,"s).+ASP\.NET_SessionId=([^;]+);.+","$1")
		__VIEWSTATE:=get(html,"__VIEWSTATE")
		__EVENTVALIDATION:=get(html,"__EVENTVALIDATION")
	}
	
	while strlen(id)<6
		id:="0" id
	
	formattime,date,% a_now,yyyy/MM/dd
	
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	
	d:=A_Now
	d+=-6,days
	
	post:="NWeb1%24ScriptManager1=NWeb1%24UpdatePanel1%7CNWeb1%24BtnGetEmgPatientListByDoctor&scrollLeft=0&scrollTop=0&hiddenHl7Reg=http%3A%2F%2Fihiswsvc.hospital-n.local%2FHL7Central_IIS%2FCentral.asmx-" sid "-" loginId "-" A_IPAddress1 "-DigitalSignature%2FDrugGivenDS&NWeb1%24txbEmpNO=" id "&NWeb1%24txtSDateChar=" substr(d,1,4) "%2F" substr(d,5,2) "%2F" substr(d,7,2) "&NWeb1%24txtSDateChar_MaskedEditExtender_ClientState=&NWeb1%24txtEDateChar=" a_yyyy "%2F" a_MM "%2F" a_dd "&NWeb1%24txtEDateChar_MaskedEditExtender_ClientState=&NWeb1%24txbPinCode=&NWeb1%24hiddenPin=undefind&__EVENTTARGET=&__EVENTARGUMENT=&__VIEWSTATE=" encodeurl(__VIEWSTATE) "&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&__AjaxControlToolkitCalendarCssLoaded=&hiddenRecord=000000-" loginId "-T0&__ASYNCPOST=true&NWeb1%24BtnGetEmgPatientListByDoctor=%E6%9F%A5%E8%A9%A2"
	
	httprequest(url,post,header,"charset: utf-8")
	
	return post
	
}

;~ a:=EMRViewerMobile("777C5B94A94B4A3C97F61C6C5345442E",chartNo)
;~ b:=EMRgetRadExams(a)
;~ a.getReport("PA View","20130808")
EMRViewerMobile(sid,chartNo){
	global __VIEWSTATE,__EVENTVALIDATION,portalAspId,reportpageguid
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	if !(__VIEWSTATE && __EVENTVALIDATION && reportpageguid){
		url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MedicalReportOpen.aspx?SESSION=" sid
		,header:="Host: ihisaw.hospital-n.local`nConnection: Keep-Alive"		
		,httprequest(url,post:="",header,"charset: utf-8")
		
		RegExMatch(post,"reportpageguid=([\w\-]+)",match)
		reportpageguid:=match1
		,__VIEWSTATE:=get(post,"__VIEWSTATE")
		,__EVENTVALIDATION:=get(post,"__EVENTVALIDATION")
	}
	
	;~ url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MobileMasterPage.aspx?reportpageguid=" reportpageguid
	;~ header:="Host: ihisaw.hospital-n.local`nConnection: Keep-Alive"
	;~ httprequest(url,post:="",header,"charset: utf-8")
	
	url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MobileMasterPage.aspx?reportpageguid="reportpageguid
	,header:="Referer: http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MobileMasterPage.aspx?reportpageguid=" reportpageguid "`nHost: ihisaw.hospital-n.local`nConnection: Keep-Alive`nPragma: no-cache"
	,post:="__LASTFOCUS=&__EVENTTARGET=&__EVENTARGUMENT=&__VIEWSTATE=" encodeurl(__VIEWSTATE) "&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&txbIDInput=" chartNo "&btnQueryAction=%E6%9F%A5%E8%A9%A2"
	,httprequest(url,post,header,"charset: utf-8")
	
	,RegExMatch(post,"reportpageguid=([\w\-]+)",match)
	,reportpageguid:=match1
	,__VIEWSTATE:=get(post,"__VIEWSTATE")
	,__EVENTVALIDATION:=get(post,"__EVENTVALIDATION")
	
	
	return new portalLib_EMRViewerMobile(post)
}

EMRgetRadExams(EMRViewerMobile){
	radExams:=[]
	sorting:=[],i:=0
	for k,v in EMRViewerMobile.EMR
		if instr(v.title,"影核醫") {
			for x,y in v
				if x is number
				{
					regexmatch(y.param,"([^_]+)_([^_]+)_([^_]+)",match)
					radExams.push({ExamName: RegExReplace(y["報告類別"],"i) \(V\d+\)$","") 
						,ExamDate: y["檢查日期"] ;yyyy/mm/dd
						,Hospital: match1 ;T0
						,AccessNo: match3
						,ReportDate: y["報告日期"]}) ;yyyymmdd
					sorting[RegExReplace(y["檢查日期"],"\D","") match3]:=++i
				}
		}
	sorted:=[]
	for k,v in sorting
		sorted.push(radExams[v])
	return sorted
}

class portalLib_EMRViewerMobile {
	__New(html){
		dom:=ComObjCreate("HtmlFile")
		dom.write(html)
		
		ret:=[]
		
		loop % $(dom,"MobileMenu").childNodes.length
		{	
			arr:=[]
			group:=$(dom,"MobileMenu").childNodes[a_index-1]
			arr["title"]:=group.firstChild.firstChild.nodeValue
			col:=[]
			loop % group.childNodes[1].firstChild.firstChild.childNodes.length
				col.push(trim(group.childNodes[1].firstChild.firstChild.childNodes[a_index-1].innerText))
			
			loop % group.childNodes[1].childNodes[1].childNodes.length {
				i:=a_index
				item:=[]
				item["param"]:=trim(group.childNodes[1].childNodes[1].childNodes[i-1].param)
				loop % group.childNodes[1].childNodes[1].childNodes[i-1].childNodes.length {
					j:=a_index
					if (col[j]="開報告"){
						regexmatch(group.childNodes[1].childNodes[1].childNodes[i-1].childNodes[j-1].firstChild.href,"WebForm_PostBackOptions\(""([^""]+)",match)
						item["" col[j]]:="" trim(match1)
					}else{
						item["" col[j]]:="" trim(group.childNodes[1].childNodes[1].childNodes[i-1].childNodes[j-1].innerText)
					}
				}
				arr.push(item.clone())
			}
			ret.push(arr.clone())
		}
		this.EMR:=ret	
		
		RegExMatch(html,"reportpageguid=([\w\-]+)",match)
		this.reportpageguid:=match1
		this.__VIEWSTATE:=get(html,"__VIEWSTATE")
		this.__EVENTVALIDATION:=get(html,"__EVENTVALIDATION")
		
		this.chartNo:=get(html,"txbIDInput")
	}
	
	getReport(reportNameSubStr,examDate,titleSubStr="影核醫",Number=0,reportDate=""){
		if (reportNameSubStr="" || titleSubStr="")
			return []
		
		arr:=[],arr2:=[]
		
		if isobject(reportNameSubStr) {
			for k,v in this.EMR {
				if instr(v.title,titleSubStr) {
					for x,y in v {
						if x is not number
							continue
						if reportNameSubStr.(y["報告類別"]) && instr(RegExReplace(y["檢查日期"],"\D",""),RegExReplace(examDate,"\D","")){ 
							arr2.push(y["開報告"])
							if (reportDate="" || instr(RegExReplace(y["報告日期"],"\D",""),RegExReplace(reportDate,"\D","")))
								arr.push(y["開報告"])
						}
					}
					break
				}
			}
		}else{
			for k,v in this.EMR {
				if instr(v.title,titleSubStr) {
					for x,y in v {
						if x is not number
							continue
						if instr(y["報告類別"],reportNameSubStr) && instr(RegExReplace(y["檢查日期"],"\D",""),RegExReplace(examDate,"\D","")){
							arr2.push(y["開報告"])
							if (reportDate="" || instr(RegExReplace(y["報告日期"],"\D",""),RegExReplace(reportDate,"\D","")))
								arr.push(y["開報告"])
						}
					}
					break
				}
			}
		}
		
		if !arr.maxIndex()
			arr:=arr2.clone()
		
		if !arr.maxIndex()
			return 0
		arr2:=[]
		
		for k,v in arr {
			if (number>0&&a_index>number)
				break
			arr2.push(this.getReportByLink(v))
		}
		return arr2
	}
	
	getReportByLink(linkId){
		url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MobileMasterPage.aspx?reportpageguid=" this.reportpageguid
		header:="Referer: http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MobileMasterPage.aspx?reportpageguid=" this.reportpageguid "`nHost: ihisaw.hospital-n.local`nConnection: Keep-Alive`nPragma: no-cache"
		post:="__LASTFOCUS=&__EVENTTARGET=" encodeUrl(linkId) "&__EVENTARGUMENT=&__VIEWSTATE=" encodeurl(this.__VIEWSTATE) "&__EVENTVALIDATION=" encodeurl(this.__EVENTVALIDATION) "&ddlPatChartNo=" encodeUrl(this.chartNo) "&txbIDInput=" encodeUrl(this.chartNo) "&txtEndDate=&txtStartDate="
		httprequest(url,post,header,"charset: utf-8")
		
		url:=RegExReplace(get(post,"Reportifrm","id","src"),"&amp;","&")
		httprequest(url,post:="",header:="","charset: utf-8")
		
		return post
	}
	
	radReportText(html){
		dom:=ComObjCreate("HtmlFile")
		dom.write(html)
		
		table1:=$(dom,"rReportTab_lsvReportBody_ctrl0_ctl00_tblDisplay").previousSibling.childNodes[5].firstChild
		table2:=$(dom,"rReportTab_lsvReportBody_ctrl0_ctl00_tblDisplay")
		str:=""
		
		loop % table1.firstChild.childNodes.length {
			i:=a_index
			loop % table1.firstChild.childNodes[i-1].childNodes.length {
				j:=a_index
				str.=trim(table1.firstChild.childNodes[i-1].childNodes[j-1].innerText) " "
			}
			str.="`n"
		}
		loop % table2.firstChild.childNodes.length {
			i:=a_index
			loop % table2.firstChild.childNodes[i-1].childNodes.length {
				j:=a_index
				if(table2.firstChild.childNodes[i-1].childNodes[j-1].getElementsByTagName("textarea").length>0)
					str.=trim(table2.firstChild.childNodes[i-1].childNodes[j-1].firstChild.firstChild.innerText) " "
				else
					str.=trim(table2.firstChild.childNodes[i-1].childNodes[j-1].innerText) " "
			}
			str.="`n"
		}
		
		return str
		
	}
	
	
}

/*
arr[1]
	醫令
	報告醫師
	影像時間 (format=2015/10/19 17:29)
	醫令碼
	報告時間
arr[2]	report
arr[3]	impression
*/
parseRisReport2Yr(html){
	
	;~ dom:=ComObjCreate("HtmlFile")
	;~ dom.write(html)
	
	;~ table:=$(dom,"TableRISReport")
	
	;~ table:=RegExMatch(html, "is)<table [^>]*id=[^>]*TableRisReport[^>]*>.+?</table>", match)
	table:=getHtmlById(html, "TableRisReport")
	,rows:=getHtmlByTagName(table, "TR")
	
	,arr:=[]
	;~ loop % table.rows.length-1 {
	loop % rows.maxIndex()-1 {
		;~ row:=table.rows[a_index]
		row:=rows[a_index+1]
		;~ text:=row.innerText
		Text:=convertHTMLchar(RegExReplace(getHtmlByTagName(row, "TD")[1], "<\/?\w+?>",""))
		
		if regexmatch(text,"is)^醫令: (.+?) 報告醫師: (.+?) 影像時間: (.+?) \(([^\)]+)\) 發報告時間: (.+?)",match)
			tmp:=[],tmp.push([trim(match1), trim(match2), trim(match3), trim(match4), trim(match5)])
		else if regexmatch(text,"is)^報告內容: (.+)",match) || regexmatch(text,"is)^Impression: (.+)",match)
			;~ tmp.push(trim(RegExReplace(row.cells[0].innerHTML, "is)^(報告內容|Impression):", "")))
			tmp.push(trim(match1))
			;~ ,Clipboard:=row.innerHTML
		else if regexmatch(text,"^症狀: ",match)
			arr.push(tmp)
	}
	return arr
}
;~ sid:="MOCK_SESSION_TOKEN"
;~ chartNo:="Y______"
;~ b:=RisReport2Yr(sid,chartNo)
;~ c:=parseRisReport2Yr(b)
;~ d:=1
;~ ExitApp
RisReport2Yr(sid,chartNo, hospital=""){
	if cache:=portalInfoTemp(chartNo, A_ThisFunc)
		return cache
	
	
	if !checksid(sid){
		return -1
	}
	
	if hospital!=
		hospitalSpecified:=true
	
	if StrLen(chartNo)!=10 {
		if SubStr(chartNo,1,1)="H" 
			hospital=T4
		else if SubStr(chartNo,1,1)="Y" 
			hospital=Y0
			;~ return
	}
	
	if hospital=H
		hospital=T4
	else if hospital=Y
		hospital=Y0
	
	;~ if hospital!=
		hospital:="&Hosp=" hospital
	
	if RegExMatch(chartNo,"i)\w\d{9}"){
		personId:=chartNo
	}else {
		while strlen(chartNo)<7
			chartNo:="0" chartNo
		
		if cache:=portalInfoTemp(personId:=patientBasicInfo(chartNo,sid).personId, A_ThisFunc)
			return cache
	}
	
	url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleInfoShowUsingPlaceHolder.aspx?SESSION=" sid "&Func=RISReport&AccountIDSE=&PersonID=" personid "&WinPup=True&Seed=" a_hour a_min a_sec hospital
	,header:="Referer: http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleShowiframePage.aspx?SESSION=" sid "&PersonID=" personid "&Seed=" a_now "`nHost: ihisaw.hospital-n.local"
	,httprequest(url,post:="",header,"charset: utf-8")
	

	,portalInfoTemp(chartNo, A_ThisFunc, post)
	return post
	
}

AppendAspInfo(post,html){
	global __VIEWSTATE,__EVENTVALIDATION
	post:=RegExReplace(post,"i)&?(__VIEWSTATE|__EVENTVALIDATION)=[^&]+","")
	post:=RegExReplace(post,"i)(__VIEWSTATE|__EVENTVALIDATION)=[^&]+&?","")
	
	if (post!="")
		post.="&"
	if (__VIEWSTATE="")
		__VIEWSTATE:=get(html,"__VIEWSTATE")
	if (__EVENTVALIDATION="")
		__EVENTVALIDATION:=get(html,"__EVENTVALIDATION")
	
	return post "__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&__VIEWSTATE=" encodeurl(__VIEWSTATE)
}

ExtractHeaderCookie(responseHeader){
	i:=0,match:=str:=""
	while i:=regexmatch(responseHeader,"i)Set-Cookie: ([^\n]+)",match,i+strlen(match)+1)
		str.=match1
	
	return str:=RegExReplace(str,"(path=\/|HttpOnly|expires=[^;]+);?","")
}

queryInjectionRecords(sid,chartno){
	global __VIEWSTATE,__EVENTVALVIEWSTATE,__EVENTVALIDATION,portalAspId
	url:="http://hisaw.hospital-n.local/WebApplication/InspectionReport/ReportOfCase.aspx?SESSION=" sid
	if (!__VIEWSTATE || !__EVENTVALIDATION || !portalAspId) {
		header:="Host: hisaw.hospital-n.local`nUser-Agent: Mozilla/5.0 (Windows NT 5.1; rv:29.0) Gecko/20100101 Firefox/29.0`nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8`nAccept-Language: en-US,en;q=0.5`nAccept-Encoding: gzip, deflate`nConnection: keep-alive`nCookie: CK_Radiology_RISPatientRegistration=X_StatisticGroupCodeCookie=IsShowChartNo=Y; CK_Clinics_OrderSearch=IsShowOrderCode=N;"
		httprequest(url,html:="",header,"charset: utf-8")
		portalAspId:=RegExReplace(header,"s)^.+ASP\.NET_SessionId=([^;]+);.+$","$1")
		__VIEWSTATE:=get(html,"__VIEWSTATE")
		__EVENTVALIDATION:=get(html,"__EVENTVALIDATION")
	}
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	httprequest(url,html:="",header,"charset: utf-8")
	ToolkitScriptManager1_HiddenField:=RegExReplace(html,"is)^.+\/WebApplication\/InspectionReport\/ReportOfCase\.aspx\?_TSM_HiddenField_=ToolkitScriptManager1_HiddenField&amp;_TSM_CombinedScripts_=([^""]+).+$","$1")
	ucQueryHandler_QueryTab_ClientState:=RegExReplace(get(html,"ucQueryHandler_QueryTab_ClientState"),"i)&quot;","""")
	__VIEWSTATE:=get(html,"__VIEWSTATE")
	__EVENTVALIDATION:=get(html,"__EVENTVALIDATION")
	while strlen(chartno)<6
		chartno:="0" chartno
	formattime,startDate,% a_now,yyyy/M/d
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	post:="ToolkitScriptManager1_HiddenField=" ToolkitScriptManager1_HiddenField "&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&ucQueryHandler_QueryTab_ClientState=" encodeurl("{""ActiveTabIndex"":1,""TabEnabledState"":[true,true],""TabWasLoadedOnceState"":[true,false]}") "&__VIEWSTATE=" encodeurl(__VIEWSTATE) "&__SCROLLPOSITIONX=0&__SCROLLPOSITIONY=0&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&ucQueryHandler%24ddlSystem=17&ucQueryHandler%24QueryTab%24QueryFromScheduling%24ddlOrder=CHMRX&ucQueryHandler%24QueryTab%24QueryFromScheduling%24txbDateStart=" encodeurl(startDate) "&ucQueryHandler%24QueryTab%24QueryFromScheduling%24ddlShiftType=&ucQueryHandler%24QueryTab%24QueryFromScheduling%24txbQueryPat=&ucQueryHandler%24QueryTab%24QueryFromScheduling%24TextBoxWatermarkExtender2_ClientState=&ucQueryHandler%24QueryTab%24QueryForFilledCase%24txbChartNoOrPersonId=" encodeurl(chartNo) "&ucQueryHandler%24QueryTab%24QueryForFilledCase%24TextBoxWatermarkExtender1_ClientState=&ucQueryHandler%24QueryTab%24QueryForFilledCase%24txbStartDate=" encodeurl(startDate) "&ucQueryHandler%24QueryTab%24QueryForFilledCase%24txbEndDate=" encodeurl(startDate) "&ucQueryHandler%24QueryTab%24QueryForFilledCase%24btnQueryFilled=%E6%9F%A5%E8%A9%A2&isMenuVisible=true"
	httprequest("http://hisaw.hospital-n.local/WebApplication/InspectionReport/ReportOfCase.aspx",post,header,"charset: utf-8")
	return new portalLib_FoundInjectionRecords(post)
}
class portalLib_FoundInjectionRecords {
	__New(post){
		dom:=ComObjCreate("HtmlFile")
		dom.write(post)
		this.ToolkitScriptManager1_HiddenField:=RegExReplace(post,"is)^.+\/WebApplication\/InspectionReport\/ReportOfCase\.aspx\?_TSM_HiddenField_=ToolkitScriptManager1_HiddenField&amp;_TSM_CombinedScripts_=([^""]+).+$","$1")
		this.ucQueryHandler_QueryTab_ClientState:=RegExReplace(get(post,"ucQueryHandler_QueryTab_ClientState"),"i)&quot;","""")
		arr:=[]
		table:=$(dom,"UpdatePanel1").childNodes[2]
		loop % table.rows.length-1 {
			v:=table.rows[a_index]
			pt:=[]
			pt.ChartNo:=trim(v.cells[1].innerText)
			pt.Name:=trim(v.cells[2].innerText)
			pt.Gender:=trim(v.cells[3].innerText)
			pt.Age:=trim(v.cells[4].innerText)
			pt.Status:=trim(v.cells[5].innerText)
			pt.Date:=trim(v.cells[6].innerText)
			pt.PostBack:=RegExReplace(v.cells[2].firstChild.href,"is)^.+(lvQuery\$ctrl\d+\$lbtName).+$","$1")
			arr.push(pt.clone())
		}
		this.results:=arr
	}
	getLink(n="",chartNo="",date="",postback:=""){
		global sid,portalAspId,__VIEWSTATE,__EVENTVALIDATION
		if(n!=""){
			return this.getLink("","","",this.results[n].PostBack)
		}else{
			arr:=[]
			for k,v in this.results {
				if (instr(v.chartNo,chartNo) && instr(RegExReplace(v.date,"\D",""),substr(RegExReplace(date,"\D",""),1,8))){
					formattime,startDate,% a_now,yyyy/M/d
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
					post:="ToolkitScriptManager1=" encodeurl("UpdatePanel1|" (postback=""?v.PostBack:postback)) "&ToolkitScriptManager1_HiddenField=" this.func1(RegExReplace(this.ToolkitScriptManager1_HiddenField,"\+","%20")) "&__EVENTTARGET=" encodeurl(postback=""?v.PostBack:postback) "&__EVENTARGUMENT=&__LASTFOCUS=&ucQueryHandler_QueryTab_ClientState=" encodeurl("{""ActiveTabIndex"":1,""TabEnabledState"":[true,true],""TabWasLoadedOnceState"":[true,true]}") "&__VIEWSTATE=" encodeurl(__VIEWSTATE) "&__SCROLLPOSITIONX=0&__SCROLLPOSITIONY=0&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&ucQueryHandler%24ddlSystem=17&ucQueryHandler%24QueryTab%24QueryFromScheduling%24ddlOrder=CHMRX&ucQueryHandler%24QueryTab%24QueryFromScheduling%24txbDateStart=" encodeurl(startDate) "&ucQueryHandler%24QueryTab%24QueryFromScheduling%24ddlShiftType=&ucQueryHandler%24QueryTab%24QueryFromScheduling%24txbQueryPat=&ucQueryHandler%24QueryTab%24QueryFromScheduling%24TextBoxWatermarkExtender2_ClientState=&ucQueryHandler%24QueryTab%24QueryForFilledCase%24txbChartNoOrPersonId=" v.chartNo "&ucQueryHandler%24QueryTab%24QueryForFilledCase%24TextBoxWatermarkExtender1_ClientState=&ucQueryHandler%24QueryTab%24QueryForFilledCase%24txbStartDate=" encodeurl(startDate) "&ucQueryHandler%24QueryTab%24QueryForFilledCase%24txbEndDate=" encodeurl(startDate) "&isMenuVisible=true&__ASYNCPOST=true"
					;~ clipboard:=header "`n`n" post
					httprequest("http://hisaw.hospital-n.local/WebApplication/InspectionReport/ReportOfCase.aspx",post,header,"charset: utf-8")
					arr.push(RegExReplace(clipboard:=post,"is)^.+(http:\/\/hisaw\.hospital-n\.local\/WebApplication\/InspectionReport\/ReportSheet\.aspx\?SESSION=" sid "[^\\]+).+$","$1"))
					if (PostBack!="")
						break
				}
			}
			return arr
		}
	}
	StringUpper(str){
		StringUpper,str,str
		return str
	}
	func1(str){
		str:=RegExReplace(str,"(\%\d)b","$1B")
		str:=RegExReplace(str,"(\%\d)a","$1A")
		str:=RegExReplace(str,"(\%\d)d","$1D")
		str:=RegExReplace(str,"(\%\d)c","$1C")
		str:=RegExReplace(str,"(\%\d)e","$1E")
		str:=RegExReplace(str,"(\%\d)f","$1F")
		return str
	}
}



/*
POST http://hiswsvc.hospital-n.local/HL7Central_IIS/Central.asmx HTTP/1.1
User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; MS Web Services Client Protocol 2.0.50727.3053)
Content-Type: text/xml; charset=utf-8
SOAPAction: "http://localhost/HL7Central/HL7Port"
Host: hiswsvc.hospital-n.local
Content-Length: 763
Expect: 100-continue

<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><HL7Port xmlns="http://localhost/HL7Central/"><HL7Input>&lt;QBP_Z10&gt;&lt;MSH&gt;&lt;MSH.3&gt;&lt;HD.1&gt;WebPageID&lt;/HD.1&gt;&lt;/MSH.3&gt;&lt;MSH.7&gt;&lt;TS.1&gt;20200101000000.0000&lt;/TS.1&gt;&lt;/MSH.7&gt;&lt;MSH.9&gt;&lt;MSG.2&gt;Z01&lt;/MSG.2&gt;&lt;/MSH.9&gt;&lt;/MSH&gt;&lt;PV1&gt;&lt;PV1.2&gt;I&lt;/PV1.2&gt;&lt;PV1.3&gt;&lt;PL.11&gt;&lt;HD.1&gt;T0&lt;/HD.1&gt;&lt;/PL.11&gt;&lt;/PV1.3&gt;&lt;PV1.19&gt;&lt;CX.1&gt;T0000000001&lt;/CX.1&gt;&lt;/PV1.19&gt;&lt;/PV1&gt;&lt;/QBP_Z10&gt;</HL7Input></HL7Port></soap:Body></soap:Envelope>


<QBP_Z10><MSH><MSH.3><HD.1>WebPageID</HD.1></MSH.3><MSH.7><TS.1>20200101000000.0000</TS.1></MSH.7><MSH.9><MSG.2>Z01</MSG.2></MSH.9></MSH><PV1><PV1.2>I</PV1.2><PV1.3><PL.11><HD.1>T0</HD.1></PL.11></PV1.3><PV1.19><CX.1>T0000000001</CX.1></PV1.19></PV1></QBP_Z10>



response:
HTTP/1.1 200 OK
Date: Fri, 23 Oct 2015 00:49:20 GMT
Server: Microsoft-IIS/6.0
X-Powered-By: ASP.NET
X-AspNet-Version: 2.0.50727
Cache-Control: private, max-age=0
Content-Type: text/xml; charset=utf-8
Content-Length: 11269

<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><HL7PortResponse xmlns="http://localhost/HL7Central/"><HL7PortResult>&lt;BAR_Z01&gt;&lt;PID&gt;&lt;PID.3&gt;&lt;CX.1&gt;TEST_NID_001&lt;/CX.1&gt;&lt;/PID.3&gt;&lt;/PID&gt;&lt;BAR_Z01.VISIT&gt;&lt;PV1&gt;&lt;PV1.2&gt;I&lt;/PV1.2&gt;&lt;PV1.3&gt;&lt;PL.11&gt;&lt;HD.1&gt;T0&lt;/HD.1&gt;&lt;HD.2&gt;EMER&lt;/HD.2&gt;&lt;HD.3&gt;NA&lt;/HD.3&gt;&lt;/PL.11&gt;&lt;/PV1.3&gt;&lt;PV1.19&gt;&lt;CX.1&gt;T0000000001&lt;/CX.1&gt;&lt;/PV1.19&gt;&lt;/PV1&gt;&lt;ZDG1&gt;&lt;ZDG1.1&gt;I&lt;/ZDG1.1&gt;&lt;ZDG1.2&gt;M&lt;/ZDG1.2&gt;&lt;ZDG1.3&gt;486&lt;/ZDG1.3&gt;&lt;ZDG1.4&gt;Pneumonia&lt;/ZDG1.4&gt;&lt;ZDG1.5&gt;02&lt;/ZDG1.5&gt;&lt;ZDG1.6&gt;000000&lt;/ZDG1.6&gt;&lt;ZDG1.7&gt;&lt;TS.1&gt;20200101000000.0000&lt;/TS.1&gt;&lt;/ZDG1.7&gt;&lt;ZDG1.8&gt;10.0.0.1&lt;/ZDG1.8&gt;&lt;ZDG1.9&gt;000000&lt;/ZDG1.9&gt;&lt;ZDG1.10&gt;&lt;TS.1&gt;20200101000000.0000&lt;/TS.1&gt;&lt;/ZDG1.10&gt;&lt;ZDG1.11&gt;Y&lt;/ZDG1.11&gt;&lt;ZDG1.13&gt;000000&lt;/ZDG1.13&gt;&lt;ZDG1.14&gt;10.0.0.1&lt;/ZDG1.14&gt;&lt;ZDG1.15&gt;&lt;TS.1&gt;20200101000000.0000&lt;/TS.1&gt;&lt;/ZDG1.15&gt;&lt;ZDG1.16&gt;I&lt;/ZDG1.16&gt;&lt;ZDG1.17&gt;N&lt;/ZDG1.17&gt;&lt;/ZDG1&gt;&lt;/BAR_Z01.VISIT&gt;&lt;/BAR_Z01&gt;</HL7PortResult></HL7PortResponse></soap:Body></soap:Envelope>


<BAR_Z01><PID><PID.3><CX.1>TEST_NID_001</CX.1></PID.3></PID><BAR_Z01.VISIT><PV1><PV1.2>I</PV1.2><PV1.3><PL.11><HD.1>T0</HD.1><HD.2>EMER</HD.2><HD.3>NA</HD.3></PL.11></PV1.3><PV1.19><CX.1>T0000000001</CX.1></PV1.19></PV1><ZDG1><ZDG1.1>I</ZDG1.1><ZDG1.2>M</ZDG1.2><ZDG1.3>486</ZDG1.3><ZDG1.4>Pneumonia</ZDG1.4><ZDG1.5>02</ZDG1.5><ZDG1.6>000000</ZDG1.6><ZDG1.7><TS.1>20200101000000.0000</TS.1></ZDG1.7><ZDG1.8>10.0.0.1</ZDG1.8><ZDG1.9>000000</ZDG1.9><ZDG1.10><TS.1>20200101000000.0000</TS.1></ZDG1.10><ZDG1.11>Y</ZDG1.11><ZDG1.13>000000</ZDG1.13><ZDG1.14>10.0.0.1</ZDG1.14><ZDG1.15><TS.1>20200101000000.0000</TS.1></ZDG1.15><ZDG1.16>I</ZDG1.16><ZDG1.17>N</ZDG1.17></ZDG1></BAR_Z01.VISIT></BAR_Z01>
*/

; clipboard:=PacsImageViewerRequest()
; ExitApp
PacsImageViewerRequest(){
	global portalUrl
	url:="http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/ExternalPage/PacesImageViewer.aspx?SESSION=MOCK_SESSION_TOKEN"
	header=
	(Ltrim
	Referer: http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/ExternalPage/PACSImage.aspx?isfrombackupdb=False&sheetnolist=T__________&chartnolist=H______&personid=TEST_NID_001&reportpageguid=TEST_NID_001&hospitalcode
	Host: ihisaw.hospital-n.local
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	)
	httprequest(url, post:="", header)
	return header "`n`n" post
}


;~ PacsWebInfo(output,"Y__________","Y______","000000","MOCK_PASSWORD")
;~ a:=1
;~ a:=1
;~ PacsWebInfo(output,"T__________","3______",loginId,loginPw)
;~ PacsWebInfo(output,"T__________","6______",loginId,loginPw)
;~ PacsWebInfo(output,"T__________","H______",loginId,loginPw)
;~ ExitApp



PacsWebInfoY(byref output,AccNo,chartNo="",loginId="",loginPw="",count="1500"){
	baseUrl:="http://dlpacs.hospital-n-y.local/DicomWeb/DicomWeb.dll/WADO?User=" loginId "&Password=" md5(loginPw)
	,httprequest(url:=baseUrl "&requestType=Query&patientID=" chartNo "&accessionNumber=" accNo "&flag=2"
	,post:=""
	,header:="Host: dlpacs.hospital-n-y.local"
	, "charset: utf-8")
	
	if !IsObject(output)
		output:=[]
	try {
		x:=new xml(post)
		,output.studyUID:=x.getText("/queryResult/dataset/study/studyUID")
		, series:=x.selectNodes("/queryResult/dataset/study/series")
		Loop % series.length {
			s:=[]
			,s.seriesUID:=series.item(A_Index-1).getElementsByTagName("seriesUID").item(0).Text
			,im:=series.item(A_Index-1).getElementsByTagName("image")
			Loop % im.length {
				i:=[]
				, i.objectUID:=im.item(A_Index-1).getElementsByTagName("objectUID").item(0).Text
				, i.filePath:=im.item(A_Index-1).getElementsByTagName("filePath").item(0).Text
				, i.url:= baseUrl "&requestType=WADO&psHash=&studyUID=" output.studyUID "&seriesUID=" s.seriesUID "&objectUID=" i.objectUID "&flag=2&contentType=image/jpeg&imageQuality=100&columns=1536&windowCenter=&windowWidth=&frameNumber="
				, s[A_Index]:=i
			}
			output[A_Index]:=s
		}
	}catch e 
		MsgBox % e.message
	
	return output
	
}


PacsWebInfoH(byref output,AccNo,chartNo="",loginId="",loginPw="",count="1500"){
	baseUrl:="http://pacs.hospital-n-h.local/DicomWeb/DicomWeb.dll/WADO?User=" loginId "&Password=" md5(loginPw)
	,httprequest("http://pacs.hospital-n-h.local/DicomWeb/DicomWeb.dll/WADO?requestType=Query&User=" loginId "&Password=" md5(loginPw) "&patientID=" chartNo "&accessionNumber=" AccNo "&flag=2"
		, post:=""
		, header:="Host: pacs.hospital-n-h.local"
		, "charset: utf-8")
		
	
	if !IsObject(output)
		output:=[]
	try {
		x:=new xml(post)
		,output.studyUID:=x.getText("/queryResult/dataset/study/studyUID")
		, series:=x.selectNodes("/queryResult/dataset/study/series")
		Loop % series.length {
			s:=[]
			,s.seriesUID:=series.item(A_Index-1).getElementsByTagName("seriesUID").item(0).Text
			,im:=series.item(A_Index-1).getElementsByTagName("image")
			Loop % im.length {
				i:=[]
				, i.objectUID:=im.item(A_Index-1).getElementsByTagName("objectUID").item(0).Text
				, i.filePath:=im.item(A_Index-1).getElementsByTagName("filePath").item(0).Text
				, i.url:= baseUrl "&requestType=WADO&psHash=&studyUID=" output.studyUID "&seriesUID=" s.seriesUID "&objectUID=" i.objectUID "&flag=2&contentType=image/jpeg&imageQuality=100&columns=1536&windowCenter=&windowWidth=&frameNumber="
				, s[A_Index]:=i
			}
			output[A_Index]:=s
		}
	}catch e 
		MsgBox % e.message
	
	return output
	
}


PacsWebInfo(byref output,AccNo,chartNo="",loginId="",loginPw="",count="1500", new=true){
	;~ url:="http://pacsmobile.hospital-n.local/?user=" loginId "&password=" loginPw "&tab=Display&PatientID=" chartNo "&AccessionNumber=" AccNo "&theme=epr"
	;~ header=
	;~ ( ltrim
	;~ Referer: http://pacswide.hospital-n.local:8080/kQuery.php
	;~ Host: pacsmobile.hospital-n.local
	;~ )
	;~ httprequest(url,post,header)
	;~ clipboard:=header "`n`n" post
	;~ exitapp
	PacsWebServer(AccNo, baseUrl, host)
	
	if(host="dlpacs.hospital-n-y.local")
		return PacsWebInfoY(output, AccNo, chartNo, loginId, loginPw, Count)
	
	if InStr(baseUrl, "pacsmobile"){
		
		if(new){
			return PacsWebInfoNew(AccNo,chartNo,loginId,loginPw)
		}else{
			url:=baseUrl "/wado/?v=2.0.SU3.3&requestType=STUDY&contentType=text/javascript&maxResults=250&PatientID=" chartNo "&AccessionNumber=" AccNo "&ae=local&IssuerOfPatientID=&groupByIssuer=*&language=zh_TW&user=" loginId "&password=" loginPw 
			header=
			( Ltrim
			Referer: %baseUrl%/?&tab=Display&PatientID=%chartNo%&AccessionNumber=%AccNo%&theme=epr
			Host: %host%
			)
			httprequest(url,post:="",header)
			cookie:=""
		}
		
		;~ clipboard:=post
	}else if InStr(baseUrl, "H branch"){
		return PacsWebInfoH(output, AccNo, chartNo, loginId, loginPw, Count)
	
		/*
	
	
		httprequest(url:="http://pacswide.hospital-n.local:8080/"
			, post:=""
			, header:="Host: pacswide.hospital-n.local:8080", "+NO_AUTO_REDIRECT`ncharset: utf-8")
	
		RegExMatch(header, "Set-Cookie: PHPSESSID=([^;]+)", match)
		, PHPSESSID:=match1
	
		httprequest(url:="http://pacswide.hospital-n.local:8080/auth_n.php"
			, post:="account=" loginId "&pwd=" loginPw "&signIn=%E7%99%BB%E5%85%A5"
			, header:="Referer: http://pacswide.hospital-n.local:8080/`nHost: pacswide.hospital-n.local:8080`nCookie: PHPSESSID=" PHPSESSID
			, "+NO_AUTO_REDIRECT`ncharset: utf-8")
		
		;~ httprequest(url:="http://pacswide.hospital-n.local:8080/kQuery.php"
			;~ , post:=""
			;~ , header:="Referer: http://pacswide.hospital-n.local:8080/auth_n.php`nHost: pacswide.hospital-n.local:8080`nCookie: PHPSESSID=" PHPSESSID
			;~ , "+NO_AUTO_REDIRECT`ncharset: utf-8")
			
		;~ httprequest(url:="http://pacswide.hospital-n.local:8080/gXWL.php"
			;~ , post:="qMethod=pt_id&hosp_id=hosp_id_04&user_hosp=01&pt_id=" chartNo "&fetchDbFlag=Y&qDirect=+&emgFlag=F"
			;~ , header:="Referer: http://pacswide.hospital-n.local:8080/kQuery.php`nHost: pacswide.hospital-n.local:8080`nCookie: PHPSESSID=" PHPSESSID
			;~ , "+NO_AUTO_REDIRECT`ncharset: utf-8")
			
		httprequest(url:=baseUrl "/"
			, post:=""
			, header:="Host: " host "`nCookie: JSESSIONID=""""", "+NO_AUTO_REDIRECT`ncharset: utf-8")
		
		RegExMatch(header, "Set-Cookie: JSESSIONID=([^;]+)", match)
		, JSESSIONID:=match1
		
		;~ httprequest(url:="http://pacswide.hospital-n.local:8080/giFrameXero.php"
			;~ , post:="ptID=" chartNo "&ptTitle=&ptInfo=&accessionNO=" AccNo "&width=1184&height=1521&hospID=04&emgFlag=F&hospPtIDs=" chartNo
			;~ , header:="Referer: http://pacswide.hospital-n.local:8080/kQuery.php`nHost: pacswide.hospital-n.local:8080`nCookie: PHPSESSID=" PHPSESSID
			;~ , "+NO_AUTO_REDIRECT`ncharset: utf-8")
			
		;~ httprequest(url:="http://pacswide.hospital-n.local:8080/gXero.php"
			;~ , post:=""
			;~ , header:="Referer: http://pacswide.hospital-n.local:8080/kQuery.php`nHost: pacswide.hospital-n.local:8080`nCookie: PHPSESSID=" PHPSESSID
			;~ , "+NO_AUTO_REDIRECT`ncharset: utf-8")
			
		httprequest(url:=baseUrl "/?user=MOCK_USER&password=MOCK_PASSWORD&tab=Display&PatientID=" chartNo "&AccessionNumber=" AccNo "&theme=epr"
			, post:=""
			, header:="Referer: http://pacswide.hospital-n.local:8080/kQuery.php`nHost: " host "`nCookie: JSESSIONID=" JSESSIONID
			, "+NO_AUTO_REDIRECT`ncharset: utf-8")
		
		RegExMatch(header, "Set-Cookie: JSESSIONIDSSO=([^;]+)", match)
		, JSESSIONIDSSO:=match1
		
		cookie:=PacsWebCookie(JSESSIONID, JSESSIONIDSSO, "1184/1152")
		
		;~ httprequest(url:=baseUrl "/?&tab=Display&PatientID=" chartNo "&AccessionNumber=" AccNo "&theme=epr"
			;~ , post:=""
			;~ , header:="Referer: http://pacswide.hospital-n.local:8080/kQuery.php`nHost: " host "`nCookie: JSESSIONID=" JSESSIONID "; JSESSIONIDSSO=" JSESSIONIDSSO
			;~ , "+NO_AUTO_REDIRECT`ncharset: utf-8")
			
		;~ clipboard:=post
		
		url:=baseUrl "/wado/?v=2.0.SU3.3&requestType=STUDY&contentType=text/javascript&maxResults=250&PatientID=" chartNo "&AccessionNumber=" AccNo "&ae=local&IssuerOfPatientID=&groupByIssuer=*&language=zh_TW&user=" loginId "&password=" loginPw 
		header=
		( Ltrim
		Referer: %baseUrl%/?&tab=Display&PatientID=%chartNo%&AccessionNumber=%AccNo%&theme=epr
		Host: %host%
		Cookie: %cookie%
		)
		httprequest(url,post:="",header, "+NO_AUTO_REDIRECT`ncharset: utf-8")
		global __PacsWebCookie:=cookie
		*/
	}
	
	regexmatch(post,"(?<=studyUID=)[^&]+",studyUID)
		

	
	;~ regexmatch(post,"(?<=Count=)[^&]+",count)
	;~ count:=2
	,regexmatch(post,"(?<=""ver"":"")[^""]+",ver)
	,regexmatch(post,"(?<=Count=)\d+",count)
	
	,url:=baseUrl "/wado/?v=2.0.SU3.3&requestType=IMAGE&contentType=text/javascript&regroup=*&studyUID=" (studyUid) "&Position=0&Count=" count "&ver=" ver "&ae=local&language=zh_TW"
	if InStr(baseUrl, "pacsmobile")
		url.="&user=" loginId "&password=" loginPw

	header=
	( Ltrim
	Referer: %baseUrl%/?&tab=Display&PatientID=%chartNo%&AccessionNumber=%AccNo%&theme=epr
	Host: %host%
	)
	if(cookie!="")
		header.="`nCookie: " cookie
	httprequest(url,post:="",header)
	
	
	,json:=json_from(post)
	if(!isobject(output))
		output:=[]
	
	output.studyUID:=json.children.1.children.1.studyUID
	,output.url:=PacsWebUrlTrans(json.children.1.children.1.url, baseUrl, host)
	
	header=
	( Ltrim
	Referer: %baseUrl%/?&tab=Display&PatientID=%chartNo%&AccessionNumber=%AccNo%&theme=epr
	Host: %host%
	)
	if(cookie!="")
		header.="`nCookie: " cookie
	
	
	ind:=0
	for k,v in json.children.1.children.1.children {
		if (v.seriesUID="")
			continue
		++ind
		output[ind]:=[]
		,output[ind,"seriesUID"]:=v.seriesUID
		,output[ind,"url"]:=PacsWebUrlTrans(v.url, baseUrl, host)
		
		url:=baseUrl "/wado/?v=2.0.SU3.3&" regexreplace(substr(v.url,2),"i)&url=true&regroup=true","")  "&contentType=text/javascript&regroup=*&ver=" ver
		if InStr(baseUrl, "pacsmobile")
			url.="&user=" loginId "&password=" loginPw
		;~ url:=regexreplace(url,"i)&url=true&regroup=true","") 
		httprequest(url,post:="",header1:=header)
		
		,json2:=json_from(post)
		
		,ind2:=0
		
		for x,y in json2.children.1.children.1.children {
			if (y.seriesUID=v.seriesUID){
				ind3:=x
				break
			}
		}
		
		for x,y in json2.children.1.children.1.children[ind3].children {
			if(y.objectUID="")
				continue
			++ind2
			output[ind,ind2,"objectUID"]:=y.objectUID
			,output[ind,ind2,"url"]:=PacsWebUrlTrans(y.url, baseUrl, host)
		}
	}
	return output
	
}

PacsWebInfoFlatten(byref result){
	output:=[]
	for k,v in result
		if isobject(v)
			for x,y in v
				if isobject(y) && y.hasKey("ObjectUID")
					output.push(y)
	return output
}
PacsWebUrlTrans(url, baseUrl, host){
	regexmatch(url,"is)(?<=studyUID=)[\d\.]+",studyUID)
	regexmatch(url,"is)(?<=seriesUID=)[\d\.]+",seriesUID)
	regexmatch(url,"is)(?<=objectUID=)[\d\.]+",objectUID)
	return baseUrl "/wado/?v=2.0.SU3.3&requestType=XERO" (studyUID?"&studyUID=" studyUID:"") (seriesUID?"&seriesUID=" seriesUID:"") (objectUID?"&objectUID=" objectUID:"") "&language=zh_TW&ae=local"
}

PacsWebUrl(AccNo,chartNo="",loginId="",loginPw=""){
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	PacsWebServer(AccNo, baseUrl, host)
		
	return baseUrl "/?user=" loginId "&password=" loginPw "&tab=Display&PatientID=" chartNo "&AccessionNumber=" AccNo "&theme=epr"
}
;~ PacsWebDownloadJpeg2("http://pacsmobile.hospital-n.local/wado/?v=2.0.SU3.3&requestType=XERO&studyUID=1.2.840.10008.1.1.0000.20200101.000001&seriesUID=1.2.840.10008.1.1.0000.20200101.000002&language=zh_TW&objectUID=1.2.840.10008.1.1.0000.20200101.000003&ae=local&user=MOCK_USER&password=MOCK_PASSWORD"T__________",chartNo,"test.jpeg","","2500")

;~ PacsWebLogin(loginId,loginPw)

;~ httprequest("http://pacsmobile.hospital-n.local/?user=MOCK_USER&password=MOCK_PASSWORD&tab=Display&PatientID=4______&AccessionNumber=T__________&theme=epr",post,header)
;~ PacsWebDownloadJpeg2("http://pacsmobile.hospital-n.local/wado/?v=2.0.SU3.3&requestType=XERO&studyUID=1.2.840.10008.1.1.0000.20200101.000004&seriesUID=1.2.840.10008.1.1.0000.20200101.000005&objectUID=1.2.840.10008.1.1.0000.20200101.000006&language=zh_TW&ae=local","T__________","4______","test.jpeg","","2500",loginId,loginPw)

;~ ?requestType=WADO&studyUID=1.2.840.10008.1.1.0000.20200101.000004&seriesUID=1.2.840.10008.1.1.0000.20200101.000005&objectUID=1.2.840.10008.1.1.0000.20200101.000006&ae=local

;~ output:=PacsWebInfoFlatten(PacsWebInfo(output,"T__________","N000001",loginId,loginPw))

;~ v:=output[output.maxindex()]
				;~ PacsWebDownloadJpeg2(v.url,"T__________",chartNo,"T__________ " chartNo.jpeg", "T__________" "" "" chartNo,1000,loginId,loginPw)

PacsWebCookie(ByRef inout_JSESSIONID="", ByRef inout_JSESSIONIDSSO="", ByRef inout_ViewportSize=""){
	static candidates1:="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-_"
	, candidates2:="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	if (inout_JSESSIONID=""){
		loop 24 {
			random,rand,1,% strlen(candidates1)
			inout_JSESSIONID.=substr(candidates1,rand,1)
		}
	}
	if(inout_JSESSIONIDSSO=""){
		loop 32 {
			random,rand,1,% strlen(candidates2)
			inout_JSESSIONIDSSO.=substr(candidates2,rand,1)
		}
	}
	if(inout_ViewportSize=""){
		inout_ViewportSize:="1024/643"
	}
	return "JSESSIONID=" inout_JSESSIONID "; JSESSIONIDSSO=" inout_JSESSIONIDSSO "; xero-viewport-size=" inout_ViewportSize
}

PacsWebTemp(accNo,chartNo,loginId,loginPw){
	global JSESSIONID,JSESSIONIDSSO
	
	cookie:=PacsWebCookie(JSESSIONID, JSESSIONIDSSO)
	
	PacsWebServer(AccNo, baseUrl, host)
	
	url:=baseUrl "/?user=" loginId "&password=" loginpw "&tab=Display&PatientID=" chartNo "&AccessionNumber=" AccNo "&theme=epr"
	header=
	(
	Referer: http://pacswide.hospital-n.local:8080/kQuery.php
	Host: %host%
	Cookie: %cookie%
	)
	httprequest(url,post:="",header)
	
}
;~ sid:=askForPortalIdPw(0,0)
;~ ,accNo:="", chartNo:=""
;~ ,PacsWebLoginNew(accNo, chartNo, loginId, loginPw)
;~ ,output:=PacsWebInfoFlatten(PacsWebInfoNew(AccNo, chartNo, loginId, loginPw))
;~ PacsWebDownloadJpeg2(output[1].url, AccNo, chartNo,  "test.jpeg", "D:", "2855", loginId, loginPw)
;~ PacsWebLogoutNew()
;~ PacsWebDownloadJpeg2(output[1].url, AccNo, chartNo,  "test.jpeg2", "D:", "2855", loginId, loginPw)
;~ PacsWebLoginNew(AccNo, chartNo, loginId, loginPw)
;~ PacsWebDownloadJpeg2(output[1].url, AccNo, chartNo,  "test.jpeg3", "D:", "2855", loginId, loginPw)

;~ p:=1
;~ ExitApp


PacsWebDownloadDicom(url,AccNo,chartNo,fileName="",folder="",PicWidth="",loginId="",loginPw="",retry=3,fileSize=100,first=1, callback="", param=""){
	return PacsWebDownloadJpeg2(url,AccNo,chartNo,fileName,folder,PicWidth,loginId,loginPw,retry,fileSize,first, callback, param, "dicom")
}
PacsWebDownloadPng(url,AccNo,chartNo,fileName="",folder="",PicWidth="",loginId="",loginPw="",retry=3,fileSize=100,first=1, callback="", param=""){
	return PacsWebDownloadJpeg2(url,AccNo,chartNo,fileName,folder,PicWidth,loginId,loginPw,retry,fileSize,first, callback, param, "png")
}
PacsWebDownloadJpeg2(url,AccNo,chartNo,fileName="",folder="",PicWidth="",loginId="",loginPw="",retry=3,fileSize=100,first=1, callback="", param="", DownloadFileType="jpeg"){
	global __PacsWebCookie, __ua_header
	;~ global JSESSIONID,JSESSIONIDSSO
	
	;~ if(!JSESSIONID || !JSESSIONIDSSO)
		;~ PacsWebTemp(AccNo,chartNo,loginId,loginPw)

	PacsWebServer(AccNo, baseUrl, host)
	
	if(first=1){
		;~ url:=PacsWebUrl(AccNo,chartNo,loginId,loginPw)
		;~ header:="Host: pacsmobile.hospital-n.local`nReferer: http://pacswide.hospital-n.local:8080/kQuery.php"
		;~ httprequest(url,post:="",header)
		
		
		while strlen(chartNo)<7
			chartNo:="0" chartNo
		
		if InStr(baseUrl, "dlpacs.hospital-n-y.local") || InStr(baseUrl, "H branch"){
			if !instr(url,"User=", true)
					url.="&User=" loginId
			if !instr(url,"Password=", true)
				url.="&Password=" md5(loginPw)
			
			if (!instr(url,"columns="))
				url.="&columns=" (PicWidth?PicWidth:a_screenwidth*2)
			else if PicWidth
				url:=RegExReplace(url,"(?<=columns=)[^&]+",PicWidth)
		}else{
		
			if InStr(baseUrl, "pacsmobile") && !InStr(baseUrl, "pacsmobilenew"){
				if !instr(url,"user=")
					url.="&user=" loginId
				if !instr(url,"password=")
					url.="&password=" loginPw
				
				
			}
			if (!instr(url,"rows="))
				url.="&rows=" (PicWidth?PicWidth:a_screenwidth*2)
			else if PicWidth
				url:=RegExReplace(url,"(?<=rows=)[^&]+",PicWidth)
			
		}
	}
	
	
	
	if (folder="")
		folder:=A_ScriptDir
	if (filename="")
		filename:=AccNo " " chartNo " 1.jpeg"
	
	regexmatch(header,"(?<=Content-Length: )\d+",len)
	if !InStr(FileExist(folder), "D")
		FileCreateDir,% folder
	fileFullPath:=folder "\" filename
	if FileExist(fileFullPath)  {
		
		if !isValidJpeg(fileFullPath)
			FileDelete,% fileFullPath
	}
	
	_contentType:=""
	if(DownloadFileType="dicom" || fileName~="i).dcm$")
		_contentType:="&contentType=application/dicom"
		,DownloadFileType:="dicom"
	else if (DownloadFileType="png" || fileName~="i).png$")
		_contentType:="&contentType=image/png"
		,DownloadFileType:="png"
		,url.="&imageQuality=100"
	else
		url.="&imageQuality=100"
		,DownloadFileType:="jpeg"
	
	if InStr(baseUrl, "pacsmobilenew"){
		header=
			( LTRIM
			Referer: %baseUrl%
			Host: %host%
			)
		winhttprequest(url _contentType, post:="", header1:=header "`n" __ua_header , "binary`nsaveas: " fileFullPath , true)
		,PacsWebCookieRenew(header1)
			
		
			
		;~ regexmatch(header,"(?<=Content-Length: )\d+",len)
	
		;~ bytes:=BinWrite(fileFullPath,post,0)
		header:=header1
	}else{
		
	;~ url:="http://pacsmobile.hospital-n.local/wado/?v=2.0.SU3.3&requestType=XERO&studyUID=1.2.840.10008.1.1.0000.20200101.000001&seriesUID=1.2.840.10008.1.1.0000.20200101.000002&language=zh_TW&objectUID=1.2.840.10008.1.1.0000.20200101.000003&ae=local&user=MOCK_USER&password=MOCK_PASSWORD
		if InStr(baseUrl, "dlpacs.hospital-n-y.local"){
			header:="Referer: " baseUrl "/html5/ShowImage.html?User=" loginId "&Password=" md5(loginPw) "&patientID=" chartNo "&accessionNumber=" AccNo "`nHost: " host
		}else{
			header=
			( LTRIM
			Referer: %baseUrl%/?&tab=Display&PatientID=%chartNo%&AccessionNumber=%AccNo%&theme=epr
			Host: %host%
			)

			if (baseUrl~="xero-\d+")
				header.="`nCookie: " __PacsWebCookie
		
		}
		
		;~ url.="&contentType=application/dicom"
		httprequest(url,post:="",header,"charset: utf-8`nbinary`nsaveas: " fileFullPath)
		;~ msgbox % post
		;~ clipboard:=header
	}
	
	ifRetry:=false
	if isValidJpeg(fileFullPath) || (DownloadFileType!="jpeg"){
		if IsFunc(callback)
			SetTimerFn(callback,-1, param)
		ret:=0
	}else{
		ifRetry:=true
	}
	
	if(ifRetry){
		FileDelete,% fileFullPath
		if (--retry<1){
			ret:=-1
		}else
			ret:=1
	}

	return ret<1?ret:PacsWebDownloadJpeg2(url,AccNo,chartNo,fileName,folder,PicWidth,loginid,loginpw,retry,fileSize,0, callback, param)
	
	
	
	
	
	
	
	if (folder="")
		folder:=A_ScriptDir
	if (filename="")
		filename:=AccNo " " chartNo " 1.jpeg"
	
	regexmatch(header,"(?<=Content-Length: )\d+",len)
	filedelete,% folder "\" filename
	if !InStr(FileExist(folder), "D")
		FileCreateDir,% folder
	if (len>fileSize)
		bytes:=BinWrite(folder "\" filename,post,len)
	
}
;~ PacsWebDownloadJpeg("Y__________","4______","test.jpeg","","2500",loginId,loginPw)

PacsWebServer(AccNo, ByRef outBaseUrl, ByRef outHost, new=true){
	if (AccNo~="i)^Y"){
		outBaseUrl:="http://dlpacs.hospital-n-y.local"
		,outHost:="dlpacs.hospital-n-y.local"
		return
	}
	
	RegExMatch(AccNo, "i)^T(\d)", hospitalCode)
	if (hospitalCode1="4" || SubStr(AccNo,1,1)="H")
		;~ outBaseUrl:="http://xero-01.hospital-h.local"
		;~ ,outHost:="xero-01.hospital-h.local"
		outBaseUrl:="http://pacs.hospital-n-h.local"
		,outHost:="pacs.hospital-n-h.local"
	else
		outBaseUrl:=new?"http://pacsmobilenew.hospital-n.local":"http://pacsmobile.hospital-n.local"
		,outHost:=new?"pacsmobilenew.hospital-n.local":"pacsmobile.hospital-n.local"
}



PacsWebDownloadJpeg(AccNo,chartNo="",fileName="",folder="",PicWidth="",loginid="",loginpw="",retry=3,fileSize=100){
	static tried

	++tried
	
	if (chartNo!="")
		while strlen(chartNo)<7
			chartNo:="0" chartNo
		
	PacsWebServer(AccNo, baseUrl, host)
	
	url:=PacsWebUrl(AccNo,chartNo,loginId,loginPw)
	header:="Host: " host "`nReferer: http://pacswide.hospital-n.local:8080/kQuery.php"
	httprequest(url,post:="",header)

	regexmatch(post,"i)wado\/\?v=[^\ \""]+",match)
	StringReplace,match,match,&amp;,&,all
	
	url:=baseUrl "/" match
	url:=RegExReplace(url,"\d+$",picWidth?picWidth:a_screenwidth)
	header:="Referer: " baseUrl "/?&tab=Display&PatientID=" chartNo "&AccessionNumber=" AccNo "&theme=epr`nHost: " host
	httprequest(url,post:="",header1:=header,"charset: utf-8`nbinary")
	
	
	if (folder="") 
		folder:=A_ScriptDir
	if (filename="")
		filename:=AccNo " " chartNo " 1.jpeg"
	
	regexmatch(header1,"(?<=Content-Length: )\d+",len)
	
	filedelete,% folder "\" filename
	bytes:=BinWrite(folder "\" filename,post,len)
	
	if(bytes>100)
		return 0
	else if (tried>=retry)
		return tried
	else
		return PacsWebDownloadJpeg(AccNo,chartNo,fileName,folder,PicWidth,loginid,loginpw,retry,fileSize)
	
}

PacsWebCookieRenew(respoinse_headers){
	global JSESSIONID, JSESSIONIDSSO
	
	new_set:=false
	if RegExMatch(respoinse_headers, "(?<=Set-Cookie: JSESSIONID=)\w+", match)
		JSESSIONID:=match, new_set:=true
	if RegExMatch(respoinse_headers, "(?<=Set-Cookie: JSESSIONIDSSO=)\w+", match)
		JSESSIONIDSSO:=match, new_set:=true
	
	return new_set
}

;~ askForPortalIdPw(0,0)
;~ ,accNo:=""
;~ ,chartNo:=""
;~ PacsWebLoginNew(accNo, chartNO,  loginId, loginPw)
;~ Info:=PacsWebInfoNew(accNo, chartNO, loginId, loginPw)
;~ ExitApp
PacsWebLoginNew(accno, chartNo, loginId, loginPw){
	global JSESSIONID, JSESSIONIDSSO, __ua_header
	url:=Format("https://pacsmobilenew.hospital-n.local/?user=MOCK_USER&password=MOCK_PASSWORD&tab=Display&PatientID={}&AccessionNumber={}"
		, loginId, loginPw, chartNo, accno)
	,header:="Referer: http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PACS/MobileScreen.aspx`nHost: pacsmobilenew.hospital-n.local`n" __ua_header 
	
	,winhttprequest(url, post:="", header1:=header , "charset: utf-8", true)
	,PacsWebCookieRenew(header1)
		;~ winhttprequest(url, post:="", headher1:=header "`nCookie: " PacsWebCookie(JSESSIONID, JSESSIONIDSSO), "charset: utf-8", true)
	;~ RegExMatch(header1, "(?<=Set-Cookie: JSESSIONID=)\w+", JSESSIONID)
	;~ post:="hash=&user=" loginId "&password=" encodeurl(loginPw) "&domain=Impax&resolution=2048+*+2560"
	;~ httprequest(url, post:="", header1:=header "`nCookies: JSESSIONIDSSO=" JSESSIONID "`nxero-viewport-size=2048/2560", "+NO_AUTO_REDIRECT`ncharset: utf-8")
	;~ ,RegExMatch(header, "(?<=Set-Cookie: JSESSIONIDSSO=)\w+", JSESSIONIDSSO)
	
	;~ a:=1
}

PacsWebLogoutNew(){
	global JSESSIONID, JSESSIONIDSSO, __ua_header
	static url:="https://pacsmobilenew.hospital-n.local/logout?v=3.0.SU6.23&language=zh_TW"
	header=
	(LTrim
	Host: pacsmobilenew.hospital-n.local
	Referer: https://pacsmobilenew.hospital-n.local/
	)
	header.="`n" __ua_header "`nCookie: JSESSIONID=" JSESSIONID "; xero-viewport-size=1194/1438; JSESSIONIDSSO=" JSESSIONIDSSO "; version=3.0.SU6.23"
	,winhttprequest(url,post:="", header1:=header, "charset: utf-8", true)
	d:=1
}

PacsWebInfoNew(accNo, chartNo, loginId, loginPw, viewPortSize="1002/729"){
	global JSESSIONID, JSESSIONIDSSO, __ua_header
	;~ PacsWebLoginNew(accNo, chartNo, loginId, loginPw)
	url:=Format("https://pacsmobilenew.hospital-n.local/wado/?v=3.0.SU6.23&requestType=STUDY&contentType=text/javascript&maxResults=500&PatientID={}&AccessionNumber={}&ae=local&IssuerOfPatientID=&groupByIssuer=*&suppressReportFlags=PRELIMINARY&language=zh_TW&theme=theme"
		, chartNo, accno)
	header=
	(LTrim
	Referer: https://pacsmobilenew.hospital-n.local/
	Host: pacsmobilenew.hospital-n.local
	)

	winhttprequest(url, post:="", header1:= header "`n" __ua_header, "charset: utf-8", true)
	
	
	try
		info := JXON_load(post)
	catch
		return []
	
	output:=[]
	
	,studyUID := info["children"][1]["children"][2]["studyUID"]
	,ver := info["children"][1]["children"][2]["ver"]
	,count := info["children"][1]["children"][2]["NumberOfStudyRelatedInstances"]

	,url := Format("https://pacsmobilenew.hospital-n.local/wado/?v=3.0.SU6.23&requestType=IMAGE&contentType=text/javascript&regroup=*&studyUID={}&Position=0&Count={}&extraDicomAttributes=ImageOrientationPatient\ImagePositionPatient\PixelSpacing\FrameOfReferenceUID&fromHeader=false&suppressReportFlags=PRELIMINARY&ver={}&ae=local&gsps=Impax%20Presentation&language=zh_TW&theme=theme"
		,studyUID, Count, ver)

	,winhttprequest(url, post:="", header1:=header "`n" __ua_header, "charset: utf-8", true)

	try {
		json := JXON_load(post)			
		ind:=0
		for k,v in json.children.1.children.2.children {
			if (v.seriesUID="" || InStr(SeriesDescription, "Synthetic series") || InStr(v.seriesUID, "Markup"))
				continue
			++ind
			output[ind]:=[]
			,output[ind,"seriesUID"]:=seriesUID:=v.seriesUID
			;~ ,output[ind,"url"]:=PacsWebUrlTrans(v.url, baseUrl, host)

			,ind2:=0
			
			for x,y in v.children {
				if (y.objectUID="" || InStr(y.objectUID, "Markup"))
					continue
				++ind2
				output[ind,ind2,"objectUID"]:=y.objectUID
				,output[ind,ind2,"url"]:=Format("https://pacsmobilenew.hospital-n.local/wado/?requestType=XERO&studyUID={}&seriesUID={}&language=zh_TW&objectUID={}&ae=local&v=3.0.SU6.23"
					, studyUID, seriesUID, y.objectUID)
			}
		}
		return output
	}
	catch
		return []
}


PacsWebLogin(loginid,loginpw){
	global pacsWebPhpid
	
	if (pacsWebPhpId=""){
		httprequest("http://pacswide.hospital-n.local:8080/",post:="",header:="","charset: utf-8")
		RegExMatch(header,"i)PHPSESSID=(\w+)",match)
		pacsWebPhpId:=match1
	}
	
	url:="http://pacswide.hospital-n.local:8080/auth_n.php"
	header:="Accept: image/gif, image/jpeg, image/pjpeg, image/pjpeg, application/x-shockwave-flash, application/x-ms-application, application/x-ms-xbap, application/vnd.ms-xpsdocument, application/xaml+xml, */*`nReferer: http://pacswide.hospital-n.local:8080/`nAccept-Language: zh-tw`nUser-Agent: Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; .NET CLR 1.1.4322; .NET4.0C; .NET4.0E)`nContent-Type: application/x-www-form-urlencoded`nAccept-Encoding: gzip, deflate`nHost: pacswide.hospital-n.local:8080`nConnection: Keep-Alive`nPragma: no-cache`nCookie: PHPSESSID=" pacsWebPhpId
	post:="account=" loginId "&pwd=" loginPw "&signIn=%E7%99%BB%E5%85%A5"
	
	httprequest(url,post,header,"charset: utf-8")
	
	if instr(post,"﻿﻿<script language='javascript'>location.replace('kQuery.php')</script>")
		return 1
	else
		return 0
}

;hospital="1,2,3,4,5,6" -> N總院、J分院、B分院、H分院、ZD分院、Y分院
; one page = 10 results
PacsWebQuery(chartNo,hospital="1",pageLimit=3){
	global pacsWebPhpId
	
	while strlen(chartNo)<7
		chartNo:="0" chartNo
	
	
	url:="http://pacsweb.hospital-n.local/gXWL.php"
	header:="x-requested-with: XMLHttpRequest`nAccept-Language: zh-tw`nReferer: http://pacswide.hospital-n.local:8080/kQuery.php`nAccept: text/html, */*; q=0.01`nContent-Type: application/x-www-form-urlencoded; charset=UTF-8`nAccept-Encoding: gzip, deflate`nUser-Agent: Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; .NET CLR 1.1.4322; .NET4.0C; .NET4.0E)`nHost: pacswide.hospital-n.local:8080`nConnection: Keep-Alive`nPragma: no-cache`nCookie: PHPSESSID=" pacsWebPhpId
	
	;~ post:="qMethod=pt_id&hosp_id=hosp_id_01&user_hosp=01&pt_id=" chartNo "&fetchDbFlag=Y&qDirect=+&emgFlag=T"
	hospitalCode:=""
	loop,parse,hospital,`,
		hospitalCode.="hosp_id_0" a_loopfield "%2C"
	hospitalCode:=substr(hospitalCode,1,-3)
	if (hospitalCode="")
		hospitalCode:="hosp_id_01"
	post:="qMethod=pt_id&hosp_id=" hospitalCode "&user_hosp=01&pt_id=" chartNo "&fetchDbFlag=Y&qDirect=+&emgFlag=F"
	
	httprequest(url,post,headerSent:=header,"charset: utf-8")
	
	regexmatch(post,"第(\d)頁 / 共(\d)頁",match)
	
	result:=[]
	PacsWebResult(post,result)
	loop % match2-1 {
		if (pageLimit && a_index>pageLimit)
			break
		
		httprequest(url,post:="qMethod=pt_id&hosp_id=" hospitalCode "&user_hosp=01&pt_id=" chartNo "&fetchDbFlag=N&qDirect=next&emgFlag=F",headerSent:=header,"charset: utf-8")
		PacsWebResult(post,result)
	}
	
	return result
}

;; 院區 姓名 性別 年齡 生日 病歷號 Modality 檢查時間 AccessNo 檢查項目
PacsWebResult(html,byref arr){
	dom:=ComObjCreate("HtmlFile")
	
	,dom.write(html)
	
	,table:=$(dom,"ptWL_table")
	loop % table.rows.length-1 {
		row:=table.rows[a_index]
		,tmp:=[]
		,tmp["Hospital"]:=trim(row.cells[2].innerText)
		,tmp["Name"]:=trim(row.cells[3].innerText)
		,tmp["Gender"]:=trim(row.cells[4].innerText)
		,tmp["Age"]:=trim(row.cells[5].innerText)
		,tmp["Birthday"]:=trim(row.cells[6].innerText)
		,tmp["ChartNo"]:=trim(row.cells[7].innerText)
		,tmp["Modality"]:=trim(row.cells[8].innerText)
		,tmp["ExamDate"]:=trim(row.cells[9].innerText) ;2015/11/11 19:21:54
		,tmp["AccessNo"]:=trim(row.cells[10].innerText)
		,tmp["ExamName"]:=trim(row.cells[11].innerText)
		,arr.push(tmp)
	}
	
	return arr
	
}

/*POST http://hiswsvc.hospital-n.local/HL7Central_IIS/Central.asmx HTTP/1.1
User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; MS Web Services Client Protocol 2.0.50727.3623)
Content-Type: text/xml; charset=utf-8
SOAPAction: "http://localhost/HL7Central/HL7Port"
Host: hiswsvc.hospital-n.local
Content-Length: 763
Expect: 100-continue

<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><HL7Port xmlns="http://localhost/HL7Central/"><HL7Input>&lt;QBP_Z10&gt;&lt;MSH&gt;&lt;MSH.3&gt;&lt;HD.1&gt;WebPageID&lt;/HD.1&gt;&lt;/MSH.3&gt;&lt;MSH.7&gt;&lt;TS.1&gt;20200101000000.0000&lt;/TS.1&gt;&lt;/MSH.7&gt;&lt;MSH.9&gt;&lt;MSG.2&gt;Z01&lt;/MSG.2&gt;&lt;/MSH.9&gt;&lt;/MSH&gt;&lt;PV1&gt;&lt;PV1.2&gt;I&lt;/PV1.2&gt;&lt;PV1.3&gt;&lt;PL.11&gt;&lt;HD.1&gt;T0&lt;/HD.1&gt;&lt;/PL.11&gt;&lt;/PV1.3&gt;&lt;PV1.19&gt;&lt;CX.1&gt;T0000000001&lt;/CX.1&gt;&lt;/PV1.19&gt;&lt;/PV1&gt;&lt;/QBP_Z10&gt;</HL7Input></HL7Port></soap:Body></soap:Envelope>
*/

/*
HTTP/1.1 200 OK
Date: Sun, 15 Nov 2015 03:41:23 GMT
Server: Microsoft-IIS/6.0
X-Powered-By: ASP.NET
X-AspNet-Version: 2.0.50727
Cache-Control: private, max-age=0
Content-Type: text/xml; charset=utf-8
Content-Length: 2112

<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><HL7PortResponse xmlns="http://localhost/HL7Central/"><HL7PortResult>&lt;BAR_Z01&gt;&lt;PID&gt;&lt;PID.3&gt;&lt;CX.1&gt;TEST_NID_001&lt;/CX.1&gt;&lt;/PID.3&gt;&lt;/PID&gt;&lt;BAR_Z01.VISIT&gt;&lt;PV1&gt;&lt;PV1.2&gt;I&lt;/PV1.2&gt;&lt;PV1.3&gt;&lt;PL.11&gt;&lt;HD.1&gt;T0&lt;/HD.1&gt;&lt;HD.2&gt;SURG&lt;/HD.2&gt;&lt;HD.3&gt;NA&lt;/HD.3&gt;&lt;/PL.11&gt;&lt;/PV1.3&gt;&lt;PV1.19&gt;&lt;CX.1&gt;T0000000001&lt;/CX.1&gt;&lt;/PV1.19&gt;&lt;/PV1&gt;&lt;ZDG1&gt;&lt;ZDG1.1&gt;I&lt;/ZDG1.1&gt;&lt;ZDG1.2&gt;M&lt;/ZDG1.2&gt;&lt;ZDG1.3&gt;486&lt;/ZDG1.3&gt;&lt;ZDG1.4&gt;Pneumonia&lt;/ZDG1.4&gt;&lt;ZDG1.5&gt;02&lt;/ZDG1.5&gt;&lt;ZDG1.6&gt;000000&lt;/ZDG1.6&gt;&lt;ZDG1.7&gt;&lt;TS.1&gt;20200101000000.0000&lt;/TS.1&gt;&lt;/ZDG1.7&gt;&lt;ZDG1.8&gt;10.0.0.1&lt;/ZDG1.8&gt;&lt;ZDG1.9&gt;000000&lt;/ZDG1.9&gt;&lt;ZDG1.10&gt;&lt;TS.1&gt;20200101000000.0000&lt;/TS.1&gt;&lt;/ZDG1.10&gt;&lt;ZDG1.11&gt;Y&lt;/ZDG1.11&gt;&lt;ZDG1.13&gt;000000&lt;/ZDG1.13&gt;&lt;ZDG1.14&gt;10.0.0.1&lt;/ZDG1.14&gt;&lt;ZDG1.15&gt;&lt;TS.1&gt;20200101000000.0000&lt;/TS.1&gt;&lt;/ZDG1.15&gt;&lt;ZDG1.16&gt;I&lt;/ZDG1.16&gt;&lt;ZDG1.17&gt;N&lt;/ZDG1.17&gt;&lt;/ZDG1&gt;&lt;/BAR_Z01.VISIT&gt;&lt;/BAR_Z01&gt;</HL7PortResult></HL7PortResponse></soap:Body></soap:Envelope>
*/
; need patient admission account no using getAccountIdFromAccNo(sid, AccNo)
;~ msgbox % a:=getAccountIdFromAccNo("MOCK_SESSION_TOKEN", "T__________")
;~ clipboard:=getRisPatientHx(a:="T0000000001")
getRisPatientDx(PatientAccNo,hospital="T0",patientType="I"){
	;~ random,rand,1,1000
	;~ while strlen(rand)<4
		;~ rand.="0" rand
	
	url:="http://hiswsvc.hospital-n.local/HL7Central_IIS/Central.asmx"
	header:="User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; MS Web Services Client Protocol 2.0.50727.3623)`nContent-Type: text/xml; charset=utf-8`nSOAPAction: ""http://localhost/HL7Central/HL7Port""`nHost: hiswsvc.hospital-n.local`nExpect: 100-continue"
	post:="<?xml version=""1.0"" encoding=""utf-8""?><soap:Envelope xmlns:soap=""http://schemas.xmlsoap.org/soap/envelope/"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" xmlns:xsd=""http://www.w3.org/2001/XMLSchema""><soap:Body><HL7Port xmlns=""http://localhost/HL7Central/""><HL7Input>&lt;QBP_Z10&gt;&lt;MSH&gt;&lt;MSH.3&gt;&lt;HD.1&gt;WebPageID&lt;/HD.1&gt;&lt;/MSH.3&gt;&lt;MSH.7&gt;&lt;TS.1&gt;" a_now ".0001"  "&lt;/TS.1&gt;&lt;/MSH.7&gt;&lt;MSH.9&gt;&lt;MSG.2&gt;Z01&lt;/MSG.2&gt;&lt;/MSH.9&gt;&lt;/MSH&gt;&lt;PV1&gt;&lt;PV1.2&gt;" patientType "&lt;/PV1.2&gt;&lt;PV1.3&gt;&lt;PL.11&gt;&lt;HD.1&gt;" hospital "&lt;/HD.1&gt;&lt;/PL.11&gt;&lt;/PV1.3&gt;&lt;PV1.19&gt;&lt;CX.1&gt;" PatientAccNo "&lt;/CX.1&gt;&lt;/PV1.19&gt;&lt;/PV1&gt;&lt;/QBP_Z10&gt;</HL7Input></HL7Port></soap:Body></soap:Envelope>"
	
	httprequest(url,post,header,"charset: utf-8")
	
	regexmatch(post,"is)<HL7PortResult>(.*)<\/HL7PortResult>",match)
	StringReplace,match1,match1,&lt;,<,all
	StringReplace,match1,match1,&gt;,>,all
	return match1
	
}

;~ ########
;~ clipboard:=GEZFPurl:=getGEZFPurl("MOCK_SESSION_TOKEN", "C0000000001", "A000001", "TEST_NID_001")
;~ token:=GEZFPauth(GEZFPurl)
;~ pwb:=ComObjCreate("InternetExplorer.Application")
;~ pwb.Visible:=true
;~ pwb.navigate("http://gezfp.hospital-n-cc.local/ZFP?mode=proxy&lights=off#pl=MOCK_TOKEN")

;~ #Persistent
;~ url:="http://gezfp.hospital-n-cc.local/ZFP?mode=proxy&lights=off#pl=MOCK_TOKEN"
;~ gez:=new GEZFP(url)

;~ Loop 3
;~ {
	;~ gez.ClickSeries("","",1)
	;~ Sleep 2000
;~ }
;~ gez.scrollImage()
;~ esc::ExitApp

class GEZFP {
	__New(pwbOrUrl){
		if IsObject(pwbOrUrl)
			pwb:=pwbOrUrl
		else if pwbOrUrl!=
			pwb:=ComObjCreate("InternetExplorer.Application")
			,pwb.navigate(pwbOrUrl)
			,pwb.Visible:=true
		else 
			return 
		
		Loop 
			Sleep 200
		until (pwb.document.getElementById("canvas0").toDataURL() && pwb.document.getElementById("accessionNumber").innerText) || A_Index>100
		
		this.hwnd:=pwb.hwnd
		,this.pwb:=pwb
		,this.pt:=[]
		,this.pt.name:=RegExReplace(pwb.document.getElementById("patientsName").innerText, "[, ]+$", "")
		,this.pt.Age:=RegExReplace(pwb.document.getElementById("patientsAge").innerText, "^Age: ", "")
		,this.pt.Gender:=this.pt.sex:=RegExReplace(pwb.document.getElementById("patientSex").innerText, "^Sex: ", "")
		,this.ChartNo:=RegExReplace(pwb.document.getElementById("patientId").innerText, "^Patient ID: ", "")
		,this.AccNo:=RegExReplace(pwb.document.getElementById("accessionNumber").innerText, "^ACC: ", "")
		,this.studyDescription:=pwb.document.getElementById("studyDescription").innerText
		,this.studyDate:=RegExReplace(pwb.document.getElementById("studyDate").innerText, "^Study Date: ", "") ; 2020-01-29
		,this.studyTime:=RegExReplace(pwb.document.getElementById("studyTime").innerText, "^Study Time: ", "") ; 09:26:21
		
		;~ a:=1
		;~ saveCanvasJS=
		;~ (LTrim
		;~ function saveCanvas(fileName) {
			;~ var canvas=document.getElementById('canvas0');
			;~ if (canvas.msToBlob) { // IE
				;~ blob = canvas.msToBlob();
				;~ window.navigator.msSaveBlob(blob, fileName);
			;~ } else { // CH, FF
				;~ image = canvas.toDataURL('image/png').replace('image/png', 'image/octet-stream');
				;~ window.location.href = image;
			;~ }
		;~ }
		;~ )
		;~ execJS(this.pwb, saveCanvasJS)
	}
	
	saveCanvas(fileName="canvas.png"){
		dataURL:=this.pwb.document.getElementById("canvas0").toDataURL()
		return clipboard:=dataURL
	}
	
	ClickSeries(num="", SE="", next=""){
		pwb:=this.pwb
		if(num!="")
			#(pwb, "Ser" (num-1)).parentNode.parentNode.parentNode.children[0].click()
		else if(SE!=""){
			Loop {
				el:=#(pwb, "Ser" A_Index-1)
				if !(el.id)
					break
				if(Trim(el.innerText)="Se:" SE){
					el.parentNode.parentNode.parentNode.children[0].click()
					break
				}
			}
		}else if (next){
			selected:=""
			Loop {
				el:=#(pwb, "Ser" A_Index-1)
				if !(el.id)
					break
				if(A_Index=1)
					first:=el
				if(selected){
					el.parentNode.parentNode.parentNode.children[0].click()
					,clicked:=true
					break
				}
				if InStr(el.parentNode.parentNode.parentNode.className, "selected-active-series-item")
					selected:=el
			}
			if !clicked
				first.parentNode.parentNode.parentNode.children[0].click()
		}
		
	}
	
	scrollImage(next=true){
		sc:="javascript:var evt = document.createEvent('MouseEvents'); evt.initEvent('wheel', true, true); evt.deltaY = " (next?"+":"-") "120; $('#presentationState0')[0].dispatchEvent(evt);void 0;"
		,this.pwb.navigate(sc)
	}
	
}





GEZFPauth(hashurl){
	;~ global GEZAspId
	
	if InStr(hashurl, "pl=")
		RegExMatch(hashurl, "pl=([\w\%]+)", h)
		,hashUrl:=h1
	;~ if !GEZAspId
		;~ url:="http://gezfp.hospital-n-cc.local/ZFP?mode=proxy&lights=off"
		;~ ,header:= url "`nHost: gezfp.hospital-n-cc.local"
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
		;~ ,RegExMatch(header1,"(?<=ASP.NET_SessionId=)[^;]+", GEZAspId)
		;~ ,refreshPortalAspId(header1)
	
	Loop 2 {
		url:="http://gezfp.hospital-n-cc.local/ZFP/api/Authentication/PayLoad"
		,header:="Referer: http://gezfp.hospital-n-cc.local/ZFP?mode=proxy&lights=off`nHost: gezfp.hospital-n-cc.local"
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
		,post:="hashUrl=" encodeurl(hashUrl) "&appMode=Proxy"
		,httprequest(url, post, header1:=header, "charset: utf-8")
		;~ clipboard:=header1 "`n`n" post
		RegExMatch(post, "<Token>([^<]+)<\/Token>", token)
		
		
		;~ if InStr(header1, "ASP.NET_SessionId")
			;~ GEZAspId:=refreshPortalAspId(header1)
			;~ , GEZAspId:=portalAspId
			
		if token!=
			break
	}
	return token1

}

;;;; single image, very low resolution 
;;;; todo: check every series
downloadGEZFP(url, saveFilePath){
	pwb:=ComObjCreate("InternetExplorer.Application")
	,pwb.navigate(url)
	;~ ,pwb.Visible:=true
	Loop
		Sleep 100
	until (!pwb.busy && (imageSnapshotButton:=#(pwb, "img-operation-imageSnapshot")).id)  || A_Index > 600
	
	if !imageSnapshotButton.id
		return
	imageSnapshotButton.getElementsByTagName("a")[0].click()
	
	Loop
		Sleep 100
	until (!pwb.busy && (snapshotBase64:=(snapshot:=#(pwb, "takeImageSnapshotData")).src))  || A_Index > 600
	
	if snapshotBase64
		Base64ToFile(snapshotBase64, saveFilePath)
	pwb.quit()
}

getGEZFPurl(sid, AccNo, ChartNo, personId=""){
	global __VIEWSTATE, __VIEWSTATEGENERATOR, __EVENTVALIDATION, portalAspId
	if personId=
		personId:=patientBasicInfo(ChartNo,sid).personId
	
	;~ Loop 2 {
	url:=Format("http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList2.aspx?SESSION={}&PersonID={}"
		, sid, personId)
	, header:="Referer: " url "`nHost: ihisaw.hospital-n.local"
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	, renewPortalState(post)
	, refreshPortalAspId(header1)
			;~ break
	;~ }
	
	
	dom:=ComObjCreate("HtmlFile")
	,dom.write(post)
	,arr:=[]
	,hospitalDivs:=$(dom, "TabCtnAllPACSImageList_body").getElementsByTagName("DIV")
	,rowselected:=""
	Loop % hospitalDivs.length {
		
		if !RegExMatch(hospitalDivs[A_Index-1].id, "TabCtnAllPACSImageList_Tab_(\w\d)$" , hospitalDivCode)
			continue
		rows:=hospitalDivs[A_Index-1].getElementsByTagName("DIV")[0].getElementsByTagName("TABLE")[0].getElementsByTagName("TABLE")[0].rows

		
		;~ if !rowselected {
			;全選  病歷號 單號 檢查日 檢查名稱 儀器 狀態 
			loop % rows.length-1 {
				cells:=rows[a_index].cells
				;~ ,tx:=rows[A_Index].innerHTML
				;~ ,tmp:=[]
				;~ ,tmp["HospitalCode"]:=hospitalDivCode1
				;~ ,chartNo:=tmp["ChartNo"]:=trim(cells[1].innerText)
				;~ ,tmp["AccessNo"]:=tmp["AccNo"]:=trim(cells[2].innerText)
				;~ ,tmp["ExamDate"]:=trim(cells[3].innerText) ;20151019
				;~ ,tmp["ExamName"]:=trim(cells[4].innerText)
				;~ ,tmp["Modality"]:=trim(cells[5].innerText)
				;~ ,tmp["Status"]:=trim(cells[6].innerText) ;已確認 
				;~ ,arr.push(tmp)
				if (trim(cells[2].innerText)=AccNo){
					rowselected:=cells[0].getElementsByTagName("INPUT")[0].value
					break,2
				}
			}
		;~ }
		
	}
	
	if rowselected=
		return
	
	oldPost:=post
	,post:="ScriptManager1=" encodeurl(RegExReplace("TabCtnAllPACSImageList$Tab_{}$UC_ID_{}$UdpPACSImageOneHospList|TabCtnAllPACSImageList$Tab_{}$UC_ID_{}$BtnSingleSelectMobile", "\{\}", hospitalDivCode1)) "&RowSelected=" rowselected
	,infoInputs:=dom.getElementById("form1").getElementsByTagName("INPUT")
	Loop % infoInputs.length {
		el:=infoInputs[A_Index-1]
		if(el.tagName="INPUT" && el.type="hidden")
			post.= "&" encodeurl(el.name) "=" encodeurl(el.value) 
	}
	post.="&__ASYNCPOST=true&TabCtnAllPACSImageList%24Tab_C0%24UC_ID_C0%24BtnSingleSelectMobile=PACS%E9%A1%AF%E7%A4%BA%E5%8B%BE%E9%81%B8%E9%86%AB%E4%BB%A4(Mobile)"
	
	
	if RegExMatch(post, "ScriptManager1_HiddenField=&") && RegExMatch(oldPost, "_TSM_CombinedScripts_=([^""]+)", ajaxInfo)
		post:=RegExReplace(post, "ScriptManager1_HiddenField=&", "ScriptManager1_HiddenField=" RegExReplace(ajaxInfo1, "\+", "%20") "&")
	
	;~ clipboard:=post
	;~ post:=clipboard
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	;~ clipboard:=post
	RegExMatch(post, "http:\/\/gezfp.hospital-n-cc.local\/ZFP[^']+", gezfpUrl)
	, refreshPortalAspId(header1)
	return gezfpUrl 
		
}


isPortalHomepage(html){
	return (html ~= "i)<title>\s*正式環境(Portal)介面\s*<\/title>")
}

;~ a:=a_tickcount
;~ b:=getPacsHx("47F2A5E82D067F40A7B490FC10C036E5E6","2______")
;~ msgbox % a_tickcount-a "," b.maxindex()
;~ ExitApp
getPacsHx(sid,patientIdorChartNo, hospital="T0"){
	
	
	;~ global portalAspId
	if(patientIdorChartNo="")
		return
	while strlen(patientIdorChartNo)<7
		patientIdorChartNo:="0" patientIdorChartNo
	
	if cache:=portalInfoTemp(chartNo, A_ThisFunc)
		return cache
	
	
	if hospital!=
		hospitalSpecified:=true
	
	;~ if StrLen(patientIdorChartNo)!=10 {
		;~ if SubStr(patientIdorChartNo,1,1)="H" 
			;~ hospital=T4
		;~ else if SubStr(patientIdorChartNo,1,1)="Y" 
			;~ hospital=Y0
	;~ }
	
	;~ if hospital=H
		;~ hospital=T4
	;~ else if hospital=Y
		;~ hospital=Y0
	
	;~ hospital:="&Hosp=" hospital
	
	personId:=strlen(patientIdorChartNo)<10?patientBasicInfo(patientIdorChartNo,sid).personId:patientIdorChartNo
	
	if cache:=portalInfoTemp(personId, A_ThisFunc)
		return cache
	
	url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList2.aspx?SESSION=" sid "&PersonID=" personId 
	
	,httprequest(url, post:="", header:="", "charset: utf-8")
	
	if isPortalHomepage(post)
		return []
	
	dom:=ComObjCreate("HtmlFile")
	,dom.write(post)
	,arr:=[]
	,hospitalDivs:=$(dom, "TabCtnAllPACSImageList_body").getElementsByTagName("DIV")
	
	
	
	Loop % hospitalDivs.length {
		
		if !RegExMatch(hospitalDivs[A_Index-1].id, "TabCtnAllPACSImageList_Tab_(\w\d)$" , hospitalDivCode)
			continue
		rows:=hospitalDivs[A_Index-1].getElementsByTagName("DIV")[0].getElementsByTagName("TABLE")[0].getElementsByTagName("TABLE")[0].rows
	
		;全選  病歷號 單號 檢查日 檢查名稱 儀器 狀態 
		loop % rows.length-1 {
			cells:=rows[a_index].cells
			;~ ,tx:=rows[A_Index].innerHTML
			,tmp:=[]
			,tmp["HospitalCode"]:=hospitalDivCode1
			,chartNo:=tmp["ChartNo"]:=trim(cells[1].innerText)
			,tmp["AccessNo"]:=tmp["AccNo"]:=trim(cells[2].innerText)
			,tmp["ExamDate"]:=trim(cells[3].innerText) ;20151019
			,tmp["ExamName"]:=trim(cells[4].innerText)
			,tmp["Modality"]:=trim(cells[5].innerText)
			,tmp["Status"]:=trim(cells[6].innerText) ;已確認 
			,arr.push(tmp)
		}
		
		if(dom.getElementById("TabCtnAllPACSImageList_Tab_" hospitalDivCode1 "_UC_ID_" hospitalDivCode1 "_DgdArchiveImageList").id){
			rows:=dom.getElementById("TabCtnAllPACSImageList_Tab_" hospitalDivCode1 "_UC_ID_" hospitalDivCode1 "_DgdArchiveImageList").rows
			;全選  病歷號 單號 檢查日 檢查名稱 儀器 狀態 
			loop % rows.length-1 {
				cells:=rows[a_index].cells
				;~ ,tx:=rows[A_Index].innerHTML
				,tmp:=[]
				,tmp["HospitalCode"]:=hospitalDivCode1
				,chartNo:=tmp["ChartNo"]:=trim(cells[0].innerText)
				,tmp["AccessNo"]:=tmp["AccNo"]:=trim(cells[1].innerText)
				,tmp["ExamDate"]:=trim(cells[2].innerText) ;20151019
				,tmp["ExamName"]:=trim(cells[3].innerText)
				,tmp["Modality"]:=trim(cells[4].innerText)
				,tmp["Status"]:=trim(cells[5].innerText) ;已確認 
				,arr.push(tmp)
			}
			
		}
		
	}
	
	
	
	
	
	;~ if (!hospitalSpecified && !arr.maxIndex() && hospital!="")
		;~ return getPacsHx(sid, patientId, "T0")
	;~ else{
		portalInfoTemp(chartNo, A_ThisFunc, arr)
		return arr
	;~ }
}
;~ queryOrderPriceIE("33026BZM", "MOCK_SESSION_TOKEN")
queryOrderPriceIE(orderCode, sid, ByRef pwb="", query="code", hospitalCode="T0", queryYear="", queryMonth=""){
	url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/OrderPriceInfo/OrderPriceInfoQuery.aspx?SESSION=" sid
	,year:=queryYear=""?A_YYYY:queryYear
	,month:=queryMonth=""?a_mm+0:queryMonth
	
	if !pwb
		pwb:=ComObjCreate("InternetExplorer.Application")
		,pwb.navigate(url)
	Loop
		Sleep 100
	until !pwb.busy || A_Index>30
	
	if(query="code")
		pwb.document.getElementById("TxbQueryNOrderCode").value:=orderCode
		,pwb.document.getElementById("TxbQueryOrderName").value:=""
	else
		pwb.document.getElementById("TxbQueryNOrderCode").value:=""
		,pwb.document.getElementById("TxbQueryOrderName").value:=SubStr(orderCode,1,30)
	
	pwb.document.getElementById("TxbHospitalCode").value:=hospitalCode
	,pwb.document.getElementById("TxbQueryYear").value:=year
	,pwb.document.getElementById("TxbQueryMonth").value:=month
	,pwb.document.getElementById("BtnQuery").Click()
	;~ pwb.Visible:=true
	Loop 
		Sleep 100
	until !pwb.busy && InStr(pwb.document.getElementById("DltNOrderInfoList").innerText, orderCode) || A_Index>30
	;~ Sleep 1000
	tables:=pwb.document.getElementById("DltNOrderInfoList").rows
	
	,ret:=[], col:=[]
	Loop % tables.length {
		dom:=ComObjCreate("HtmlFile")
		,dom.write(t:=pwb.document.getElementById("DltNOrderInfoList").rows[A_Index-1].cells[0].innerHTML)
		,table:=dom.getElementsByTagName("TABLE")[0]
		,row:=table.rows[0]
		;~ MsgBox % t
		if(A_Index=1){
			Loop % row.cells.length 
				col.push(Trim(row.cells[A_Index-1].innerText)) ; 院區代碼 	醫令代碼 	醫令中文名稱 	醫令英文名稱 	記帳類別 	自費價 	健保價 	需事前審查 	停用日期 	細項
		}else{
			ret[i:=A_Index-1]:=[]
			Loop % row.cells.length
				ret[i, col[A_Index]]:=Trim(row.cells[A_Index-1].innerText)
		}
	}
	return ret
	;~ pwb.quit()
}

;醫令價格查詢
/*
Host: ihisaw.hospital-n.local
User-Agent: Mozilla/5.0 (Windows NT 6.1; rv:50.0) Gecko/20100101 Firefox/50.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: zh-TW,zh;q=0.8,en-US;q=0.5,en;q=0.3
Accept-Encoding: gzip, deflate
X-MicrosoftAjax: Delta=true
Cache-Control: no-cache
Content-Type: application/x-www-form-urlencoded; charset=utf-8
Referer: http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/OrderPriceInfo/OrderPriceInfoQuery.aspx?
Content-Length: 9746
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
DNT: 1
Connection: keep-alive
*/
;~ queryOrderPrice("33026BZM", "MOCK_SESSION_TOKEN")
; not work
queryOrderPrice(orderCode, sid, hospitalCode="T0", queryYear="", queryMonth=""){
	global __VIEWSTATE, __VIEWSTATEGENERATOR, __EVENTVALIDATION, portalAspId
	
	url:="http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/OrderPriceInfo/OrderPriceInfoQuery.aspx?SESSION=" sid
	header1=
	(LTrim
	Host: ihisaw.hospital-n.local
	Referer: %url%
	Content-Type: application/x-www-form-urlencoded; charset=utf-8
	User-Agent: Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko
	X-Content-Type-Options: nosniff
	Cookie: menuHidden=Y; NPage_MenuSettingCookie=`%u91ab`%u4ee4`%u50f9`%u683c`%u67e5`%u8a62=Y
	)
	if (__VIEWSTATE="" || __EVENTVALIDATION="" || __VIEWSTATEGENERATOR="" || portalAspId=""){
		
		httprequest(url, post:="",header:=header1, "charset: utf-8")
		,RegExMatch(header,"i)(?<=ASP.NET_SessionId=)\w+",portalAspId)
		,httprequest(url, post:="",header:=header1 "; ASP.NET_SessionId=" portalAspId, "charset: utf-8")
		,renewPortalState(post)
	}
	
	header:=header1 "; ASP.NET_SessionId=" portalAspId
	
	year:=queryYear=""?A_YYYY:queryYear
	,month:=queryMonth=""?a_mm+0:queryMonth
	
	,post:="ScriptManager1=UdpNOrderInfo%7CBtnQuery&__EVENTTARGET=&__EVENTARGUMENT=&ctl08_ExpandState=eenunnnnnnn&ctl08_SelectedNode=&ctl08_PopulateLog=&TxbQueryNOrderCode=" orderCode "&TxbQueryNHIOrderCode=&TxbQueryOrderName=&TxbHospitalCode=" hospitalCode "&TxbQueryYear=" year "&TxbQueryMonth=" month "&__ASYNCPOST=true&BtnQuery=%E6%9F%A5%E8%A9%A2(Q)"
	;~ post:=addPortalState(post)
	httprequest(url
		, post:=addPortalState(post)
		, header, "charset: utf-8`n+NO_AUTO_REDIRECT")
	
	dom:=ComObjCreate("HtmlFile")
	,dom.write(post)
	,tables:=dom.getElementById("DltNOrderInfoList").getElementsByTagName("table")
	
	,ret:=[], col:=[]
	Loop % tables.length {
		table:=tables[A_Index-1]
		,row:=table.rows[0]
		if(A_Index=1){
			Loop % row.cells.length 
				col.push(Trim(row.cells[A_Index-1].innerText)) ; 院區代碼 	醫令代碼 	醫令中文名稱 	醫令英文名稱 	記帳類別 	自費價 	健保價 	需事前審查 	停用日期 	細項
		}else{
			ret[i:=A_Index-1]:=[]
			Loop % row.cells.length
				ret[i, col[A_Index]]:=Trim(row.cells[A_Index-1].innerText)
		}
	}
	return ret
}

;查詢醫令提成
;~ queryPerformancePercentage("33026BZM" ,"478C2718A117E746EBB70B85B735A08FCA", "T4")
queryPerformancePercentage(orderCode, sid, hospitalCode="T0"){
	global __VIEWSTATE, __VIEWSTATEGENERATOR, __EVENTVALIDATION, portalAspId
	
	url:="http://ahisaw.hospital-n.local/WebApplication/Administration/GCAPerformance/QueryPerformancePercentage.aspx?SESSION=" sid
	if (__VIEWSTATE="" || __EVENTVALIDATION="" || __VIEWSTATEGENERATOR="" || portalAspId=""){
		httprequest(url, post:="",header:="Host: ahisaw.hospital-n.local", "charset: utf-8")
		,RegExMatch(header,"i)(?<=ASP.NET_SessionId=)\w+",portalAspId)
		,renewPortalState(post)
	}
	
	header=
	(LTrim
	Referer: %url%
	Host: ahisaw.hospital-n.local
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	)
	
	post:="scrollLeft=0&scrollTop=0&WebCtrlQueryPP%24ddlHospital=" hospitalCode "&WebCtrlQueryPP%24tbxOrderCode=" orderCode "&WebCtrlQueryPP%24btnQueryOrderPP=%E6%9F%A5%E8%A9%A2%E9%86%AB%E4%BB%A4%E6%8F%90%E6%88%90&WebCtrlQueryPP%24QueryOrderPercentageByOrderName1%24tbxOrderName="
	
	,httprequest(url, post:=addPortalState(post), header, "charset: utf-8")
	;~ clipboard:=post
	
	dom:=ComObjCreate("HtmlFile")
	,dom.write(post)
	,table:=dom.getElementById("WebCtrlQueryPP_dgrQOrderPP")
	
	,ret:=[], col:=[]
	Loop % table.rows.length {
		row:=table.rows[A_Index-1]
		if(A_Index=1){
			Loop % row.cells.length 
				col.push(Trim(row.cells[A_Index-1].innerText)) ; 醫令碼	院區碼	醫令名稱	提成比率	是否提成
		}else{
			ret[i:=A_Index-1]:=[]
			Loop % row.cells.length
				ret[i, col[A_Index]]:=Trim(row.cells[A_Index-1].innerText)
		}
	}
	return ret
}


;~ getPortalMessages("46C4B2F7B45D8A41F78CE0173BEFC3979A")
;~ ExitApp
getPortalMessages(sid){
	httprequest(url:="http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/ShowInfo.aspx?SESSION=" sid "&ACT=ShowNCPHSMessage", post:="")
	,renewPortalState(post)
	,dom:=ComObjCreate("HtmlFile")
	,dom.write(post)
	,tables:=dom.getElementById("dtlPHSMessage").getElementsByTagName("TABLE")
	,arr:=[]
	
	Loop % (tables.length-1)
		Loop % (rows:=tables[A_Index].rows).length {
			cells:=rows[A_Index-1].cells
			,tmp:=[]
			; 選 	序號 	接收號碼 	發送者 	發送時間 	收到時間 	內容提示 	狀態
			for k,v in ["index", "receiveNo", "sender", "sendTime", "receiveTime", "text", "status"]
				tmp[v]:=Trim(cells[k].innerText)
			arr.push(tmp)
			break
		}	
	
	return arr
}


;~ sid:=askForPortalIdPw()
;~ a:=getPortalMessages2(sid)
;~ confirmMessage2(a[1],sid)
;~ ExitApp

getPortalMessages2(sid){
	global __VIEWSTATE, __VIEWSTATEGENERATOR, __EVENTVALIDATION, portalAspId
	
	header=
	(
	Host: portal.hospital-n.local
	Referer: http://portal.hospital-n.local/General/NewRedirect.aspx?SESSION=%sid%
	Content-Type: application/x-www-form-urlencoded; charset=UTF-8
	X-Requested-With: XMLHttpRequest
	)
	post:="Mode=CriticalPHSMessage"
	,url:="http://portal.hospital-n.local/General/GeneralHandler.ashx"
	,httprequest(url, post, header, "charset: utf-8")
	try
		return JXON_load(post)
}

;~ msg:=getPortalMessages("MOCK_SESSION_TOKEN")
;~ a:=1
;~ ExitApp

confirmMessage(msgIndex, sid, ByRef portalMessage=""){
	global __VIEWSTATE, __VIEWSTATEGENERATOR, __EVENTVALIDATION
	
	if !IsObject(portalMessage)
		msg:=getPortalMessages(sid)
	else 
		msg:=portalMessage
	
	for k, v in msg
		if (v.index=msgIndex){
			cb:="dtlPHSMessage$ctl" fill0(k,2) "$ckbSelect"
			break
		}
	
	if(cb="")
		return 1
	
	post:="__VIEWSTATE=" encodeurl(__VIEWSTATE) "&__EVENTVALIDATION=" encodeurl(__EVENTVALIDATION) "&__VIEWSTATEGENERATOR=" encodeurl(__VIEWSTATEGENERATOR) "&" encodeurl(cb) "=on&btnConfirm=%E7%A2%BA%E8%AA%8D%E7%B0%A1%E8%A8%8A" 
	,url:="http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/ShowInfo.aspx?SESSION=" sid "&ACT=ShowNCPHSMessage"
	,httprequest(url, post, header:="Host: ihisaw.hospital-n.local`nReferer: " url, "charset: utf-8")
	return !!InStr(post, "self.close()")
}

/*
msg: item from getPortalMessages2
*/
confirmMessage2(msg, sid){
	global __VIEWSTATE, __VIEWSTATEGENERATOR, __EVENTVALIDATION, portalAspId
	
	if (msg.hasKey("MessageSeqNo")) ; single msg
		jsonStr:=JXON_dump([{MessageSeqNo: msg.MessageSeqNo, PHSTelNo: msg.PHSTelNo, RoleCode: msg.RoleCode}])
	else{ ; multi msg
		json:=[]
		for k,v in msg
			json.push({MessageSeqNo: v.MessageSeqNo, PHSTelNo: v.PHSTelNo, RoleCode: v.RoleCode})
		jsonStr:=JXON_dump(json)
	}
	
	
	header:="Host: portal.hospital-n.local`nReferer: http://portal.hospital-n.local/General/NewRedirect.aspx?SESSION=" sid "`nContent-Type: application/x-www-form-urlencoded; charset=UTF-8`nX-Requested-With: XMLHttpRequest"
	
	
	
	,post:="Mode=CheckCriticalPHSMessage&ProcessString=" encodeurl(jsonStr)
	,url:="http://portal.hospital-n.local/General/GeneralHandler.ashx"
	,httprequest(url, post, header, "charset: utf-8")
	return post=""""""
}

;~ getPortalAspId()
;~ ExitApp
getPortalAspId(sid, url=""){
	global portalAspId
	if url=
		url:="http://portal.hospital-n.local/General/NewRedirect.aspx?SESSION=" sid
	httprequest(url, post:="", header:="")
	
	,RegExMatch(header, "i)ASP\.NET_SessionId=(\w+)", match)
	if match1
		portalAspId:=match1
	return portalAspId
}
;~ getVSConfirmList("MOCK_SESSION_TOKEN")
getVSConfirmList(sid){
	global portalAspId
	;~ if portalAspId=
		;~ getPortalAspId(sid)
	
	url:="http://portal.hospital-n.local/General/NewRedirect.aspx?SESSION=" sid
	,httprequest("http://portal.hospital-n.local/General/GeneralHandler.ashx", post:="Mode=VSConfirmList", header:="
	(LTrim
	X-Requested-With: XMLHttpRequest
	Content-Type: application/x-www-form-urlencoded; charset=UTF-8
	Referer: http://portal.hospital-n.local/General/NewRedirect.aspx?SESSION=" sid "
	Host: portal.hospital-n.local
    Cookie: ASP.NET_SessionId=MOCK_SESSION_ID
	User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64; rv:61.0) Gecko/20100101 Firefox/61.0
	)", "charset: utf-8")
	try 
		return j:=JXON_load(post)
	catch e
		return []
	
}

;~ pwb:=EBMWebPacsLogin_IE("H00000", "xx", "HC")
;~ HWebPacsQuery_IE("T__________", pwb)
;~ ExitApp
EBMWebPacsLogin_IE(loginId, loginPw, branch, ByRef pwb="", totalAmount=1){
	if (SubStr(branch,1,2)="HC")
		url:="http://webpacs.hospital-n-h.local/"
	else if (SubStr(branch,1,2)="YL")
		url:="http://hwpacs.hospital-y.local/"
	else if (branch=="ZD")
		url:="http://pacs.zd.hospital-n.local/"
	
	allpwbs:=[]
	,allpwbHwnd:=[]
	
	Loop % totalAmount {
		if !pwb || A_Index>1
			pwb:=ComObjCreate("InternetExplorer.Application")
		;~ pwb.Visible:=true
		allpwbHwnd.push(h:=pwb.hwnd)
		,pwb.navigate(url)
		;~ ,allpwbs.push(pwb)
	}
	
	loaded:=[]
	Loop {
		for k,v in allpwbHwnd
			if !loaded.hasKey(v) && !((p:=WBGet("ahk_id " v)).busy) && p.document.getElementsByTagName("INPUT").length>=3
			{
				loaded[v]:=1
			}
				
		Sleep 100
	}until (loaded.SetCapacity(0)=totalAmount) || (A_Index > 20*totalAmount)
	
	;~ MsgBox % p.document.getElementsByTagName("INPUT").length
	
	;~ while pwb.busy && A_Index <20
		;~ Sleep 100
	;~ Sleep 1000
	js=javascript: (d=document).querySelector('input[name=User][class=Form]').value='%loginId%';d.querySelector('input[name=Password][class=Form]').value='%loginPw%';d.querySelector('#raQuery').click();loginclick();void 0;
	
	for k,v in allpwbHwnd
		WBGet("ahk_id " v).navigate(js)
	
	loaded:=[]
	
	Loop {
		for k,v in allpwbHwnd
		{
			if !loaded.hasKey(v) && !(p:=WBGet("ahk_id " v)).busy && p.document.parentWindow.frames[0].document.getElementById("qkPatientID").getElementsByTagName("INPUT").length>1 {
				loaded[v]:=1
				,resetEBMFields(p)
			}
			;~ ToolTip % p.document.parentWindow.frames[0].document.getElementById("qkPatientID").getElementsByTagName("INPUT").length "," p.busy
				
		}
			
				
		Sleep 100
	}until (loaded.SetCapacity(0)=totalAmount) || (A_Index > 20*totalAmount)
	
	for k,v in allpwbHwnd
		allpwbs.push(WBGet("ahk_id " v))
	
	return totalAmount=1?WBGet("ahk_id " allpwbHwnd[1]):allpwbs
}

resetEBMFields(byref pwb){
	js=!function(){function e(e,t){return document.parentWindow.frames[0].document.getElementById("qk"+e).getElementsByTagName(t)[0]}for(var t,n,a,o=["Modality","StudyDate","RefPhy","StudyDesc","BodyPart","CompressQuality","Comparison"],c=0;c<o.length;c++)try{t=e(o[c],"SELECT"),n=0,t.selectedIndex!==n&&(t.selectedIndex=n,t.onchange())}catch(e){}for(c=0;c<o.length;c++)try{""!==(a=e(o[c],"INPUT")).value&&(a.value="",a.onchange())}catch(e){}}();
	execJS(pwb,js)
}

resetSelect(select, index=0){
	if(select.selectedIndex = index)
		return
	select.selecedIndex := index
	select.onchange()
}


AllPwbLoaded(allpwbs, ByRef breakQuery=false){
	loaded:=[]
	,totalAmount:=allpwbs.length()
	
	Loop {
		if breakQuery
			return -2
		for k,v in allpwbs
			if !loaded.hasKey(k) && !v.busy
				loaded[k]:=1
		Sleep 100
	}until (ret:=(loaded.length()=totalAmount)) || (A_Index < 20*totalAmount)
	return ret?0:1
}

HWebPacsLogin_IE(loginId, loginPw, ByRef pwb=""){
	static hWebPacsUrl:="http://webpacs.hospital-n-h.local/"
	if !pwb 
		pwb:=ComObjCreate("InternetExplorer.Application")
	;~ pwb.Visible:=true
	pwb.navigate(hWebPacsUrl)
	while pwb.busy && A_Index <20
		Sleep 100
	Sleep 1000
	js=javascript: (d=document).querySelector('input[name=User][class=Form]').value='%loginId%';d.querySelector('input[name=Password][class=Form]').value='%loginPw%';d.querySelector('#raQuery').click();loginclick();void 0;
	pwb.navigate(js)
	
	return pwb
}

EBMWebPacsQuery_IE_batch(AccNos, pwbs, chartNos, no_re_search=true, open=true, ByRef breakQuery=false){
	no_re_search:=!!no_re_search
	,open:=!!open
	,allChartNos:=[]
	
	for k,chartNo in chartNos {
		if WinExist(chartNo " ahk_exe WEBVIE~1.exe" ) || WinExist(chartNo " ahk_exe WebViewerComSrvEC.exe")
			continue
		while StrLen(chartNo<7)
			chartNo:="0" chartNo
		allChartNos.push(chartNo)
		,AccNo:=AccNos[k]
		,pwb:=pwbs[k]
		,resetEBMFields(pwb)	
		js=!function(){var t,n,o,a,c,i,l="%chartNo%",m="%accno%",s=%no_re_search%,r=%open%,g=new RegExp(l.slice(0,-2)+"\\w\\w","i"),d=new RegExp(m.slice(0,-2)+"\\w\\w","i"),u=0;function f(){var e;try{e=o.getElementById("qkAccessNo").getElementsByTagName("input")[0].value===m&&o.getElementById("qkPatientID").getElementsByTagName("input")[0].value===l}catch(e){}void 0===e||s&&e||(t.value=0,t.onchange(),(t=n.COMPARISON).value=1,t.onchange(),""===l?((a=o.getElementById("qkAccessNo").getElementsByTagName("input")[0]).value=m,a.onchange(),(a=o.getElementById("qkPatientID").getElementsByTagName("input")[0]).value=""):((a=o.getElementById("qkPatientID").getElementsByTagName("input")[0]).value=l,a.onchange(),(a=o.getElementById("qkAccessNo").getElementsByTagName("input")[0]).value=""),a.onchange(),o.getElementById("QueryBtn").click(),console.log("info entered")),r&&(u=0,setTimeout(T,500))}function T(){var e;try{e=!g.test((i=(o=document.getElementById("mainframeset").getElementsByTagName("frameset")[0].getElementsByTagName("frame").Patientfrm.contentWindow.document).getElementById("RTable")).innerText)&&-1==o.innerText.indexOf("連線逾")}catch(e){}++u<50?void 0===e||e||-1!=o.body.innerText.indexOf("連線逾")?(console.log("wait search..."),setTimeout(T,100)):setTimeout(y,500):console.log("wait search... time out!")}function y(){var e,t,n;for(e=0;e<i.rows.length;e++)if(-1<(t=i.rows[e]).innerText.indexOf(m))return N(t),void console.log("found accno!");for(;;){try{n=i.rows.length}catch(e){n=0}if(0<n)break}for(e=0;e<i.rows.length;e++)if(t=i.rows[e],d.test(t.innerText)&&/CT|MR/i.test(t.cells[14].innerText))return N(t),void console.log("found accnoRegex...");console.log("not found...")}function N(e){e.click(),setTimeout(function(){e.cells[0].firstChild.click()},200),setTimeout(e.parentNode.parentNode.parentNode.parentNode.parentNode.parentNode.parentNode.parentNode.ondblclick,500)}setTimeout(function e(){try{c=(t=(n=(o=document.getElementById("mainframeset").getElementsByTagName("frame").Queryfrm.contentWindow.document).getElementsByTagName("select")).DATEOPTION).name}catch(e){c=""}u++;u<50?""===c?(console.log("wait loaded..."),setTimeout(e,100)):setTimeout(f,500):console.log("wait loaded... time out!")},100)}();
		
		execJS(pwb, js)
	}
	
	if breakQuery
		return -2
	
	
	if(open){
		
		loaded:=[]
		Loop {
			for k,pwb in pwbs {
				if !loaded.hasKey(k) && !pwb.busy && ((tb:=(d:=pwb.document.getElementById("mainframeset").getElementsByTagName("frameset")[0].getElementsByTagName("frame")["Patientfrm"].contentWindow.document).getElementById("RTable")).innerText ~= "i)" SubStr(chartNo,1,-2) "\w\w" ) && !InStr(d.innerText, "連線逾"){
					Loop % (rows:=tb.rows).length {
						row:=rows[(lastIndex:=A_Index)-1]
						if InStr(row.innerText, accno){
							row.cells[0].firstChild.click()
							loaded[k]:=1
							break
						}
					}
					if loaded.hasKey(k)
						continue
					Loop % (rows:=tb.rows).length {
						row:=rows[(lastIndex:=A_Index)-1]
					;~ MsgBox % row.cells[14].innerText
						if (row.innerText~= "i)" SubStr(accno,1,-2) "\w\w") && (row.cells[14].innerText~="i)CT|MR"){
							row.cells[0].firstChild.click()
							loaded[k]:=1
							break
						}
					}
					if loaded.hasKey(k)
						continue
					Loop % (rows:=tb.rows).length {
						row:=rows[(lastIndex:=A_Index)-1]
						row.cells[0].firstChild.click()
						pwb.Visible:=true
						loaded[k]:=1
						break
					}
				}
			}
			Sleep 100
		}until (loaded.length()=pwbs.length()) || (A_Index>50*pwbs.length())
		
		
	}
	
}


EBMWebPacsQuery_IE(accno, ByRef pwb, chartNo="", no_re_search=true, open=true, ByRef breakQuery=false){
	;~ pwb.Visible:=true
	if WinExist(chartNo " ahk_exe WEBVIE~1.exe" ) || WinExist(chartNo " ahk_exe WebViewerComSrvEC.exe")
		return
	
	while StrLen(chartNo)<7
		chartNo:="0" chartNo
	
	;~ while pwb.busy && (lastIndex:=A_Index) <20
		;~ if breakQuery
			;~ return -2
		;~ else
			;~ Sleep 100
	;~ sleep 1000
	no_re_search:=!!no_re_search
	,open:=!!open
	;~ js1=javascript:function f1(){try{n=(s=(ss=(d=(w=document.getElementById('mainframeset').getElementsByTagName('frame')['Queryfrm'].contentWindow).document).getElementsByTagName('select'))['DATEOPTION']).name}catch(_){n=''}i++;if(n!==''){setTO=setTimeout(f2,500)}else if(i<50){setTO=setTimeout(f1,100)}}void 0;
	;~ js2=javascript:function f2(){var test;try{test=(d.getElementById('qkAccessNo').getElementsByTagName('input')[0].value===accno&&d.getElementById('qkPatientID').getElementsByTagName('input')[0].value===chartNo)}catch(_){}if(test!==undefined&&(!no_re_search||!test)){s.value=0;s.onchange();(s=ss['COMPARISON']).value=1;s.onchange();if(chartNo===''){(e=d.getElementById('qkAccessNo').getElementsByTagName('input')[0]).value=accno;e.onchange();(e=d.getElementById('qkPatientID').getElementsByTagName('input')[0]).value='';e.onchange()}else{(e=d.getElementById('qkPatientID').getElementsByTagName('input')[0]).value=chartNo;e.onchange();(e=d.getElementById('qkAccessNo').getElementsByTagName('input')[0]).value='';e.onchange()}d.getElementById('QueryBtn').click()}if(open){i=0;setTO=setTimeout(f3,500)}}void 0;
	;~ js3=javascript:function f3(){var test;try{test=!chartNoRegex.test((tb=(d=document.getElementById('mainframeset').getElementsByTagName('frameset')[0].getElementsByTagName('frame')['Patientfrm'].contentWindow.document).getElementById('RTable')).innerText)&&(d.innerText.indexOf('連線逾')==-1)}catch(_){}i++;if(test&&i<50){setTO=setTimeout(f3,100)}else if(test!==undefined&&!test&&i<50&&(d.body.innerText.indexOf('連線逾')==-1)){setTO=setTimeout(f4,500)}}void 0;
	;~ js4=javascript:function f4(){var row_id,row;for(row_id=0;row_id<tb.rows.length;row_id++){row=tb.rows[row_id];if(row.innerText.indexOf(accno)>-1){row.cells[0].firstChild.click();console.log(row.cells[0].firstChild);return}}for(row_id=0;row_id<tb.rows.length;row_id++){row=tb.rows[row_id];if(accNoRegEx.test(row.innerText)&&/CT|MR/i.test(row.cells[14].innerText)){row.cells[0].firstChild.click();console.log(row.cells[0].firstChild);return}}}void 0;
	;~ js5=javascript: (function(){var chartNo='%chartNo%',accno='%accno%',no_re_search=%no_re_search%,open=%open%,chartNoRegex=new RegExp(chartNo.slice(0,-2)+'\\w\\w','i'),accNoRegex=new RegExp(accno.slice(0,-2)+'\\w\\w','i'),s,ss,d,w,e,i,n,_,setTO,tb,i=0,setTO=setTimeout(f1,100)})();void 0;
	
	;~ pwb.navigate(js1)
	;~ pwb.navigate(js2)
	;~ pwb.navigate(js3)
	;~ pwb.navigate(js4)
	;~ pwb.navigate(js5)
	

	resetEBMFields(pwb)	
	
	js=!function(){var t,n,o,a,c,i,l="%chartNo%",m="%accno%",s=%no_re_search%,r=%open%,g=new RegExp(l.slice(0,-2)+"\\w\\w","i"),d=new RegExp(m.slice(0,-2)+"\\w\\w","i"),u=0;function f(){var e;try{e=o.getElementById("qkAccessNo").getElementsByTagName("input")[0].value===m&&o.getElementById("qkPatientID").getElementsByTagName("input")[0].value===l}catch(e){}void 0===e||s&&e||(t.value=0,t.onchange(),(t=n.COMPARISON).value=1,t.onchange(),""===l?((a=o.getElementById("qkAccessNo").getElementsByTagName("input")[0]).value=m,a.onchange(),(a=o.getElementById("qkPatientID").getElementsByTagName("input")[0]).value=""):((a=o.getElementById("qkPatientID").getElementsByTagName("input")[0]).value=l,a.onchange(),(a=o.getElementById("qkAccessNo").getElementsByTagName("input")[0]).value=""),a.onchange(),o.getElementById("QueryBtn").click(),console.log("info entered")),r&&(u=0,setTimeout(T,500))}function T(){var e;try{e=!g.test((i=(o=document.getElementById("mainframeset").getElementsByTagName("frameset")[0].getElementsByTagName("frame").Patientfrm.contentWindow.document).getElementById("RTable")).innerText)&&-1==o.innerText.indexOf("連線逾")}catch(e){}++u<50?void 0===e||e||-1!=o.body.innerText.indexOf("連線逾")?(console.log("wait search..."),setTimeout(T,100)):setTimeout(y,500):console.log("wait search... time out!")}function y(){var e,t,n;for(e=0;e<i.rows.length;e++)if(-1<(t=i.rows[e]).innerText.indexOf(m))return N(t),void console.log("found accno!");for(;;){try{n=i.rows.length}catch(e){n=0}if(0<n)break}for(e=0;e<i.rows.length;e++)if(t=i.rows[e],d.test(t.innerText)&&/CT|MR/i.test(t.cells[14].innerText))return N(t),void console.log("found accnoRegex...");console.log("not found...")}function N(e){e.click(),setTimeout(function(){e.cells[0].firstChild.click()},200),setTimeout(e.parentNode.parentNode.parentNode.parentNode.parentNode.parentNode.parentNode.parentNode.ondblclick,500)}setTimeout(function e(){try{c=(t=(n=(o=document.getElementById("mainframeset").getElementsByTagName("frame").Queryfrm.contentWindow.document).getElementsByTagName("select")).DATEOPTION).name}catch(e){c=""}u++;u<50?""===c?(console.log("wait loaded..."),setTimeout(e,100)):setTimeout(f,500):console.log("wait loaded... time out!")},100)}();
	
		;~ pwb.Visible:=true
	execJS(pwb, js)
		
	;~ js=javascript: (function(){var chartNo='%chartNo%',accno='%accno%',no_re_search=%no_re_search%,open=%open%,chartNoRegex=new RegExp(chartNo.slice(0,-2)+'\\w\\w','i'),accNoRegex=new RegExp(accno.slice(0,-2)+'\\w\\w','i'),s,ss,d,w,e,i,n,_,setTO,tb,i=0,setTO=setTimeout(f1,100);function f1(){try{n=(s=(ss=(d=(w=document.getElementById('mainframeset').getElementsByTagName('frame')['Queryfrm'].contentWindow).document).getElementsByTagName('select'))['DATEOPTION']).name}catch(_){n=''}i++;if(n!==''){setTO=setTimeout(f2,500)}else if(i<50){setTO=setTimeout(f1,100)}}function f2(){var test;try{test=(d.getElementById('qkAccessNo').getElementsByTagName('input')[0].value===accno&&d.getElementById('qkPatientID').getElementsByTagName('input')[0].value===chartNo)}catch(_){}if(test!==undefined&&(!no_re_search||!test)){s.value=0;s.onchange();(s=ss['COMPARISON']).value=1;s.onchange();if(chartNo===''){(e=d.getElementById('qkAccessNo').getElementsByTagName('input')[0]).value=accno;e.onchange();(e=d.getElementById('qkPatientID').getElementsByTagName('input')[0]).value='';e.onchange()}else{(e=d.getElementById('qkPatientID').getElementsByTagName('input')[0]).value=chartNo;e.onchange();(e=d.getElementById('qkAccessNo').getElementsByTagName('input')[0]).value='';e.onchange()}d.getElementById('QueryBtn').click()}if(open){i=0;setTO=setTimeout(f3,500)}}function f3(){var test;try{test=!chartNoRegex.test((tb=(d=document.getElementById('mainframeset').getElementsByTagName('frameset')[0].getElementsByTagName('frame')['Patientfrm'].contentWindow.document).getElementById('RTable')).innerText)&&(d.innerText.indexOf('連線逾')==-1)}catch(_){}i++;if(test&&i<50){setTO=setTimeout(f3,100)}else if(test!==undefined&&!test&&i<50&&(d.body.innerText.indexOf('連線逾')==-1)){setTO=setTimeout(f4,500)}}function f4(){var row_id,row;for(row_id=0;row_id<tb.rows.length;row_id++){row=tb.rows[row_id];if(row.innerText.indexOf(accno)>-1){row.cells[0].firstChild.click();console.log(row.cells[0].firstChild);return}}for(row_id=0;row_id<tb.rows.length;row_id++){row=tb.rows[row_id];if(accNoRegEx.test(row.innerText)&&/CT|MR/i.test(row.cells[14].innerText)){row.cells[0].firstChild.click();console.log(row.cells[0].firstChild);return}}}})();void 0;
	
	;~ pwb.navigate(js)
	;~ clipboard:=js
	;~ return
	;~ Sleep 2000
	;~ js=javascript: (s=(ss=(d=(w=document.getElementById('mainframeset').getElementsByTagName('frame')['Queryfrm'].contentWindow).document).getElementsByTagName('select'))['DATEOPTION']).value=0;s.onchange();(s=ss['COMPARISON']).value=1;s.onchange();(e=d.getElementById('qkAccessNo').getElementsByTagName('input')[0]).value='%accno%';e.onchange();d.getElementById('QueryBtn').click();void 0;
	;~ pwb.navigate(js)
	/*
	while !(s:=(ss:=(d:=(w:=pwb.document.getElementById("mainframeset").getElementsByTagName("frame")["Queryfrm"].contentWindow).document).getElementsByTagName("select"))["DATEOPTION"]).name && (lastIndex:=A_Index)<50
		if breakQuery
			return -2
		else
			Sleep 100
	if lastIndex==50
		return -1
	
	Sleep 500
	
	if breakQuery
		return -2
	
		
	;~ (s:=(ss:=(d:=(w:=pwb.document.getElementById("mainframeset").getElementsByTagName("frame")["Queryfrm"].contentWindow).document).getElementsByTagName("select"))["DATEOPTION"]).value:=0
	
	if no_re_search && (d.getElementById("qkAccessNo").getElementsByTagName("input")[0].value=accno && d.getElementById("qkPatientID").getElementsByTagName("input")[0].value=chartNo){
	}else{
		
		s.value:=0
		,s.onchange()
		,(s:=ss["COMPARISON"]).value:=1
		,s.onchange()
		if(chartNo="")
			(e:=d.getElementById("qkAccessNo").getElementsByTagName("input")[0]).value:=accno
			,e.onchange()
			,(e:=d.getElementById("qkPatientID").getElementsByTagName("input")[0]).value:=""
			,e.onchange()
		else
			(e:=d.getElementById("qkPatientID").getElementsByTagName("input")[0]).value:=chartNo
			,e.onchange()
			,(e:=d.getElementById("qkAccessNo").getElementsByTagName("input")[0]).value:=""
			,e.onchange()
		d.getElementById("QueryBtn").click()
	}
	
	*/
	if breakQuery
		return -2
	
	
	if(open){
		while pwb.busy && (lastIndex:=A_Index)<20
			if breakQuery
				return -2
			else
				Sleep 100
		;~ Sleep 1000
	
		while !((tb:=(d:=pwb.document.getElementById("mainframeset").getElementsByTagName("frameset")[0].getElementsByTagName("frame")["Patientfrm"].contentWindow.document).getElementById("RTable")).innerText ~= "i)" SubStr(chartNo,1,-2) "\w\w" ) && !InStr(d.innerText, "連線逾") && (lastIndex:=A_Index)<50
			if breakQuery
				return -2
			else
				Sleep 100
		if lastIndex=50
			return -1
	
		if InStr(d.innerText, "連線逾"){
			return -1
		}
		Sleep 500
		if breakQuery
			return -2
	
		Loop % (rows:=tb.rows).length {
			row:=rows[(lastIndex:=A_Index)-1]
			if InStr(row.innerText, accno){
				row.cells[0].firstChild.click()
				return
			}
		}
		if breakQuery
			return -2
		Loop % (rows:=tb.rows).length {
			row:=rows[(lastIndex:=A_Index)-1]
		;~ MsgBox % row.cells[14].innerText
			if (row.innerText~= "i)" SubStr(accno,1,-2) "\w\w") && (row.cells[14].innerText~="i)CT|MR"){
				row.cells[0].firstChild.click()
				return
			}
		}
		if breakQuery
			return -2
		Loop % (rows:=tb.rows).length {
			row:=rows[(lastIndex:=A_Index)-1]
			row.cells[0].firstChild.click()
			pwb.Visible:=true
			return
		}
	}
	return -1
	
	
	
}
/*

	(function(){
		var chartNo='%chartNo%',
			accno='%accno%',
			no_re_search='%no_re_search%',
			open='%open%',
			chartNoRegex=new RegExp(chartNo.slice(0,-2)+'\\w\\w','i'),
			accNoRegex=new RegExp(accno.slice(0,-2)+'\\w\\w','i'),
			s,ss,d,w,e,i,n,_,setTO,tb,
			i=0,
			setTO=setTimeout(f1, 100);
		
		function f1(){
			try {
				n=(s=(ss=(d=(w=document.getElementById('mainframeset').getElementsByTagName('frame')['Queryfrm'].contentWindow).document).getElementsByTagName('select'))['DATEOPTION']).name;
					}catch(_){
						n='';
					}
			i++;
			if(n!==''){
				setTO=setTimeout(f2, 500);
			}else if(i<50){
				setTO=setTimeout(f1,100);
			}
		}
		
		function f2(){
			var test;
			try{
				test=(d.getElementById('qkAccessNo').getElementsByTagName('input')[0].value===accno && d.getElementById('qkPatientID').getElementsByTagName('input')[0].value===chartNo);
			}catch(_){
			}
			if(test!==undefined && (!no_re_search || !test)){
				s.value=0;
				s.onchange();
				(s=ss['COMPARISON']).value=1;
				s.onchange();
				if(chartNo===''){
					(e=d.getElementById('qkAccessNo').getElementsByTagName('input')[0]).value=accno;
					e.onchange();
					(e=d.getElementById('qkPatientID').getElementsByTagName('input')[0]).value='';
					e.onchange();
				}else{
					(e=d.getElementById('qkPatientID').getElementsByTagName('input')[0]).value=chartNo;
					e.onchange();
					(e=d.getElementById('qkAccessNo').getElementsByTagName('input')[0]).value='';
					e.onchange();
				}
				d.getElementById('QueryBtn').click();
			}
			if(open){
				i=0;
				setTO=setTimeout(f3,500);
			}
		}
		
		function f3(){
			var test;
			try{
					test=!chartNoRegex.test((tb=(d=document.getElementById('mainframeset').getElementsByTagName('frameset')[0].getElementsByTagName('frame')['Patientfrm'].contentWindow.document).getElementById('RTable')).innerText) 
				&& (d.innerText.indexOf('連線逾')==-1);
			}catch(_){
			}
			i++;
			if(test && i<50){
				setTO=setTimeout(f3,100);
			}else if(test!==undefined && !test && i<50 && (d.body.innerText.indexOf('連線逾')==-1)){
				setTO=setTimeout(f4,500);
			} 
		}
		
		function f4(){
			var row_id,row;
			for(row_id=0;row_id<tb.rows.length;row_id++){
				row=tb.rows[row_id];
				if (row.innerText.indexOf(accno)>-1){
					f5(row);
					return;
				}
			}
			for(row_id=0;row_id<tb.rows.length;row_id++){
				row=tb.rows[row_id];
				if (accNoRegEx.test(row.innerText) && /CT|MR/i.test(row.cells[14].innerText)){
					f5(row);
					return;
				}
			}
			
		}
		
		function f5(row){
			var click=createEvent('click');
			var img = row.cells[0].firstChild;
			fireEvent(row,click);
			fireEvent(img,click);
			fireEvent(row.cells[3], createEvent('dblclick'));
			return;
		}
		function createEvent(evnt){
			if (document.createEvent) {
				event = document.createEvent("HTMLEvents");
				event.initEvent(evnt, true, true);
			} else {
				event = document.createEventObject();
				event.eventType = evnt;
			}

			event.eventName = evnt;
			return event;
		}
		function fireEvent(element, event){
			if (document.createEvent) {
				element.dispatchEvent(event);
			} else {
				element.fireEvent("on" + event.eventType, event);
			}
		}
		
	})();

*/



ParseHWebPacsQueryResult(ByRef pwb){
	d:=pwb.document.getElementById("mainframeset").getElementsByTagName("frameset")[0].getElementsByTagName("frame")["Patientfrm"].contentWindow.document
	,tb:=d.getElementById("RTable")
	
	,titles:=[]
	,data:=[]
	
	Loop % (rows:=tb.rows).length {
		row:=rows[A_Index-1]
		,r:=[]
		if (A_Index=1){
			Loop % (cells:=row.cells).length {
				cell:=cells[A_Index-1]
				,r.push(Trim(cell.innerText))
			}
		}else{
			
		}
	}
}


;~ h :=new HWebPacs("H00000", "MOCK_PASSWORD")
;~ ExitApp
class HWebPacs {
	__New(loginId, loginPw) {
		this.host:="webpacs.hospital-n-h.local"
		,this.url:="http://webpacs.hospital-n-h.local/"
		,this.params:=[]
		,httprequest(this.url, post:="", header:="")
		;~ if RegExMatch(header, "m)ETag: ""([^\n]+)""", match)
			;~ this.params.ETag:=match1
		;~ if RegExMatch(post, "i)\/DicomWeb\/Script\/ImgBtn.js\?t=(\d+)&v=([\d\.]+)&l=(\w+)", match){
			;~ this.params.t:=match1
			;~ ,this.params.v:=match2
			;~ ,this.params.l:=match3
			;~ ,httprequest(this.url SubStr(match,2), post:="", header:="")
		;~ }
		
		this.login(loginId, loginPw)
	}
	
	login(id, pw){
		httprequest(this.url "DicomWeb/DicomWeb.dll/Login", post:="User=" id "&Password=" pw, header:="
		(
		Referer: " this.url "
		Host: " this.host "
		Cookie: TS=43253.5002399074; SN=-1721468625
		)")
		if InStr(post, "LoginErrorLocalization()")
			MsgBox fail
		this.loginId:=id
		this.loginPw:=pw
	}
}



portalInfoTemp(chartNo, which, writeData="", dir="", deleteAction=false){
	global ____, __PORTAL_INFO_CACHE_DIR
	if !__PORTAL_INFO_CACHE_DIR
		return
	
	if(chartNo="" || (which="" && !deleteAction))
		return
	
	if(dir=""){
		if InStr(FileExist(__PORTAL_INFO_CACHE_DIR), "D") || InStr(__PORTAL_INFO_CACHE_DIR, "\"){
			FileCreateDir,% tempDir:=__PORTAL_INFO_CACHE_DIR
			
		}else if FileExist((tempDir:=A_ScriptDir "\.portalInfoTemp") "\" chartNo ".json") 
			|| FileExist((tempDir:=A_ScriptDir "\..\.portalInfoTemp") "\" chartNo ".json")
			|| FileExist((tempDir:=A_ScriptDir "\PacsIE\.portalInfoTemp") "\" chartNo ".json")
			|| FileExist(tempDir:=A_ScriptDir "\.portalInfoTemp") 
			|| FileExist(tempDir:=A_ScriptDir "\..\.portalInfoTemp")
			|| FileExist(tempDir:=A_ScriptDir "\PacsIE\.portalInfoTemp")
			|| FileExist((tempDir:=SubStr(A_ScriptDir,1,3) "scripts\Radiology\.portalInfoTemp") "\" chartNo ".json")
			|| FileExist((tempDir:=SubStr(A_ScriptDir,1,3) "scripts\Radiology\PacsIE\.portalInfoTemp") "\" chartNo ".json")
			|| FileExist((tempDir:=SubStr(A_ScriptDir,1,3) "scripts\Autorun\.portalInfoTemp") "\" chartNo ".json")
			|| FileExist(tempDir:=SubStr(A_ScriptDir,1,3) "scripts\Radiology\.portalInfoTemp")
			|| FileExist(tempDir:=SubStr(A_ScriptDir,1,3) "scripts\Radiology\PacsIE\.portalInfoTemp")
			|| FileExist(tempDir:=SubStr(A_ScriptDir,1,3) "scripts\Autorun\.portalInfoTemp") {
			
		}else{
			FileCreateDir,% tempDir:=A_ScriptDir "\.portalInfoTemp"
		}
	}else if !FileExist(dir){
		FileCreateDir,% tempDir:=dir
	}else{
		tempDir:=dir
	}
	
	while StrLen(chartNo)<7
		chartNo:="0" chartNo
	
	;~ MsgBox % chartNo "," which "," tempDir
	
	if(deleteAction){
		if FileExist(tempDir) && FileExist(f:=tempDir "\" chartNo ".json")
			FileDelete,% f
		return
	}
	
	if(writeData=""){ ; read
		ret:=""
		if FileExist(f:=tempDir "\" chartNo ".json"){
			fileread,j,% f
			
			if (j=="QnB60nwBxtXEbQHjjbLp2Q==")
				return
			
			if(____!=""){
				j:=Crypt.Encrypt.StrDecrypt(j,____,7,6)
			}
			
			try
				json:=JXON_load(j)
			catch
				return
			if json.hasKey(which)
				return json[which]
		}
	}else{
		if FileExist(f:=tempDir "\" chartNo ".json"){
			fileread,j,% f
			if(____!=""){
				j:=Crypt.Encrypt.StrDecrypt(j,____,7,6)
			}
			try
				json:=JXON_load(j)
			catch
				return "JSON parse error"
			if !IsObject(json)
				json:={}
			
			json[which]:=RegExReplace(writeData, "i)< *input +type *= *""?hidden""?[^>]+/?>", "")
			FileDelete,% f
			if(____!="")
				FileAppend,% Crypt.Encrypt.StrEncrypt(JXON_dump(json),____,7,6),% f,utf-8
			else
				FileAppend,% JXON_dump(json),% f,utf-8
		}else{
			json:=[]
			,json["ChartNo"]:=chartNo
			,json[which]:=writeData
			FileDelete,% f
			if(____!="")
				FileAppend,% Crypt.Encrypt.StrEncrypt(JXON_dump(json),____,7,6),% f,utf-8
			else
				FileAppend,% JXON_dump(json),% f,utf-8
		}
	}
	
}

class NBranch {
	static __list:={T0: "T0"
		,T2: "T2"
		,T3: "T3"
		,T4: "T4"
		,T5: "T5"
		,T6: "T6"
		,Y0: "Y0"
		,C0: "C0"
		,J: "T3"
		,N: "T2"
		,H: "T4"
		,HC: "T4"
		,H branch: "T4"
		,C: "T5"
		,ZD: "T5"
		,Y: "Y0"
		,YL: "Y0"
		,Y branch: "Y0"
		,CC: "C0"
		,A: "C0"
		,M: "T6"}
	__New(chartNo="", AccNo="", init="", healthExam=false){
		if (NBranch.__list.hasKey(init))
			this._value:=NBranch.__list[init]
		this.healthExam:=healthExam
		,this.chartNo:=chartNo
		,this.AccNo:=accNo
	}
	
	isEqual(ByRef branch){
		return this._value==branch._value
	}
	
	pacsViewer[]{
		get {
			if (this._value~="T4|T5|T6|Y0")
				return "EBM"
			else if (this._value="C0")
				return "GE"
			else
				return "IMPAX"
			
		}
	}
}

isChartNo(chartNo){
	for k,v in ["J","N","H","C","Y","M","A"]
		if RegExMatch(chartNo, "i)\b" v "\w{5}\d\b", c)
			return new NBranch(c,"",v)
	if RegExMatch(chartNo, "i)\b\w{6}\d\b", c)
		return new NBranch(c, "", "T0")
}

isAccNo(accNo){
	for k,v in ["T0","T2","T3","T4","T5","T6"]
		if RegExMatch(accNo, "i)\b" v "\w{8}\d\b", c)
			return new NBranch("", c, v)
	for k,v in ["TH"]
		if RegExMatch(accNo, "i)\b" v "\w{8}\d\b", c)
			return new NBranch("", c, "T0", true)
	for k,v in ["HH"]
		if RegExMatch(accNo, "i)\b" v "\w{8}\d\b", c)
			return new NBranch("", c, "T4", true)
	for k,v in ["YH"]
		if RegExMatch(accNo, "i)\b" v "\w{8}\d\b", c)
			return new NBranch("", c, "Y", true)
	
	for k,v in ["Y","C"]
		if RegExMatch(accNo, "i)\b" v "\w{9}\d\b", c)
			return new NBranch("", c, v)
	
}


;~ portalChangePassword("")
;~ ExitApp
portalChangePassword(hospitalCodes=""){
	if hospitalCodes=
		hospitalCodes:="0,H,Y,A"
	
	InputBox,oldPw,Enter Password,Current Password
	InputBox,newPw,Enter Password,New Password
	
	
	Loop,parse,hospitalCodes,`,
	{
		if A_LoopField in 0,H,Y,A
		{
			if (sid:=askForPortalIdPw(0, 1, A_LoopField, 0))=-1
				continue
			pwb:=ComObjCreate("InternetExplorer.Application")
			;~ pwb.Visible:=true
			
			,pwb.navigate(url:="http://portal.hospital-n.local/General/ChangePassword.aspx?SESSION=" sid)
			Loop
				Sleep 100
			until !pwb.busy || A_Index>100
			#(pwb, "txtPass").value:=oldPw
			,#(pwb, "txbNewPass1").value:=newPw
			js=javascript:Strenght();void 0;
			execJS(pwb, js)
			,#(pwb, "txbNewPass2").value:=newPw
			,#(pwb, "btnConfirmMod").click()
			Loop
				Sleep 100
			until !pwb.busy || A_Index>100
			pwb.quit()
		}
	}
	;~ #include <RisImpax>
	;~ refreshRisImpaxEncrypt(newPw)
}

fetchIEsids(){
	Name := (Name="New Tab - Windows Internet Explorer")? "about:Tabs":RegExReplace(Name, " - (Windows|Microsoft) Internet Explorer")
	,ret:=[]
   for wb in ComObjCreate("Shell.Application").Windows
      if (name="" || instr(wb.LocationName,Name)) and InStr(wb.FullName, "iexplore.exe") && ((url="") || instr(wb.LocationUrl,url))
	 {
		if InStr(wb.LocationUrl, ".hospital-n."){
			if RegExMatch(wb.LocationUrl, "SESSION=(\w+)", match)
				ret.push(match1)
			else if RegExMatch(wb.document.documentElement.innerHTML, "SESSION=(\w+)", match)
				ret.push(match1)
		}
	 }
	 return ret
}

;~ pwb:=comobjcreate("InternetExplorer.Application")
;~ ,hwnd:=pwb.hwnd
		;~ ,pwb.Navigate("http://portal.hospital-n.local")
		;~ ,pwb.visible:=true
;~ a:=new PwbCollections(hwnd)
;~ MsgBox % a.busy
;~ MsgBox % a.Navigate("http://google.com")
;~ ExitApp

class PwbCollections {
	__New(hwnd){
		if !IsObject(hwnd)
			this.hwnd:=[hwnd]
			,this.Single:=true
		else
			this.hwnd:=hwnd
			,this.Single:=false
	}
	
	Wrap(hwnd){
		return WBGet("ahk_id " hwnd)
	}
	
	__Get(aName){
		if !(aName~="i)hwnd|single"){
			ret:=[]
			for k,v in this.hwnd
				ret.push((this.Wrap(v))[aName])
			return this.Single?ret[1]:ret
		}
			
	}
	
	__Set(aName, aValue){
		if !(aName~="i)hwnd|single"){
			for k,v in this.hwnd
				(this.Wrap(v))[aName]:=aValue
			return this.Single?ret[1]:aValue
		}
		
	}
	
	__Call(fn, args*){
		if (fn!="wrap"){
			ret:=[]
			for k,v in this.hwnd
				ret.push(ObjBindMethod(this.Wrap(v), fn, args*).call())
			return this.Single?ret[1]:ret
		}
	}
	
}