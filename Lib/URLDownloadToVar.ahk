; ==============================================================================
; Library: URLDownloadToVar.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

#include <httprequest>
#include <binaryIO>

URLDownloadToVar(url, SetTimeouts="", WaitForResponse="", proxy=""){
	hObject:=ComObjCreate("WinHttp.WinHttpRequest.5.1")
	if(proxy!="")
		hObject.SetProxy(HTTPREQUEST_PROXYSETTING_PROXY:=2 , proxy)
	if IsObject(SetTimeouts)
		hObject.SetTimeouts(SetTimeouts[1], SetTimeouts[2], SetTimeouts[3], SetTimeouts[4])
	hObject.Open("GET",url)
	,hObject.Send()
	if (WaitForResponse!="")
		hObject.WaitForResponse(WaitForResponse)
	return hObject.ResponseText
}

URL2Var(url, proxy="", binary=false, toFile="", encoding="cp0"){
	httprequest(url ,post:="",header:="", "binary" (proxy!=""?"`nproxy: " proxy:""))
	,regexmatch(header," (\d+) ",code),regexmatch(header,"(?<=Content-Length: )\d+",len)
	if (code1<200 || code1>=300) 
		return 
	
	if !binary
		post:=StrGet(&post, encoding)
	if (toFile!="")
		if binary
			BinWrite(toFile, post, len)
		else
			FileAppend,% post,% toFile, utf-8
		
	return post
}


;~ MsgBox % t:=URL2Var("https://example.com/downloads/",)
;~ a:=1