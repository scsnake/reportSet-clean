; ==============================================================================
; Library: WinHttpRequest.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum (WinHttpRequest COM wrapper)
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

; WinHttpRequest.ahk
; 
; Usage is similar to HTTPRequest (by VxE),
; Please visit the HTTPRequest page (http://goo.gl/CcnNOY) for more details.
; 
; Supported Options:
; 	NO_AUTO_REDIRECT
; 	Timeout: <Seconds>
; 	Proxy: <IP:Port>
; 	Codepage: <CPnnn>	- e.g. "Codepage: 65001"
; 	Charset: <Encoding>	- e.g. "Charset: UTF-8"
; 	SaveAs: <FileName>
; Return:
; 	Success = -1, Timeout = 0, No response = Empty String
; 
; How to clear cookie:
; 	WinHttpRequest( [] )
; 
; ChangeLog:
; 	2015-4-25 - Added option "Method: HEAD"
; 	2014-9-7  - Fixed a bug in "Charset:"
; 	2014-7-11 - Fixed a bug in "Charset:"
WinHttpRequest( URL, ByRef In_POST__Out_Data="", ByRef In_Out_HEADERS="", Options="", https=false)
{
	static nothing := ComObjError(0)
	static oHTTP   := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	static oADO    := ComObjCreate("adodb.stream")
	
	if(https){
		oHTTP.option(9):=0x2728 ; ssl 2.0 & 3.0
		,oHTTP.option(4):=0x3300 ;WinHttpRequestOption_SslErrorIgnoreFlags = all
	}
	

	; Clear cookie
	If IsObject(URL)
		Return oHTTP := ComObjCreate("WinHttp.WinHttpRequest.5.1")

	; POST or GET
	If (In_POST__Out_Data != "") || InStr(Options, "Method: POST")
		oHTTP.Open("POST", URL, True)
	Else If InStr(Options, "Method: HEAD")
		oHTTP.Open("HEAD", URL, True)
	Else
		oHTTP.Open("GET", URL, True)

	; HEADERS
	If In_Out_HEADERS
	{
		In_Out_HEADERS := Trim(In_Out_HEADERS, " `t`r`n")
		Loop, Parse, In_Out_HEADERS, `n, `r
		{
			If !( _pos := InStr(A_LoopField, ":") )
				Continue

			Header_Name  := SubStr(A_LoopField, 1, _pos-1)
			Header_Value := SubStr(A_LoopField, _pos+1)

			If (  Trim(Header_Value) != ""  )
				oHTTP.SetRequestHeader( Header_Name, Header_Value )
		}
	}

	If (In_POST__Out_Data != "") && !InStr(In_Out_HEADERS, "Content-Type:")
		oHTTP.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded")

	; Options
	If Options
	{
		Loop, Parse, Options, `n, `r
		{
			If ( _pos := InStr(A_LoopField, "Timeout:") )
				Timeout := SubStr(A_LoopField, _pos+8)
			Else If ( _pos := InStr(A_LoopField, "Proxy:") )
				oHTTP.SetProxy( 2, SubStr(A_LoopField, _pos+6) )
			Else If ( _pos := InStr(A_LoopField, "Codepage:") )
				oHTTP.Option(2) := SubStr(A_LoopField, _pos+9)
		}

		oHTTP.Option(6) := InStr(Options, "NO_AUTO_REDIRECT") ? 0 : 1
	}

	; Send...
	oHTTP.Send(In_POST__Out_Data)
	,ReturnCode := oHTTP.WaitForResponse(Timeout ? Timeout : -1)

	; Handle "SaveAs:" and "Charset:"
	If InStr(Options, "SaveAs:")
	{
		RegExMatch(Options, "i)SaveAs:[ \t]*\K[^\r\n]+", SavePath)
		
		;; source: https://autohotkey.com/board/topic/96316-downloading-and-saving-an-image-using-winhttprequest/
		,_s:=SavePath
		,_p:=comobjquery(oHTTP.responsestream,"{0000000c-0000-0000-C000-000000000046}")
		,_f:=fileopen(_s,"w")
		loop{
			varsetcapacity(_b,8192)
			,_r:=dllcall(numget(numget(_p+0)+3*a_ptrsize),ptr,_p,ptr,&_b,uint,8192, "ptr*",_c)
			,_f.rawwrite(&_b,_c)
		}until (_c=0)
		objrelease(_p)
		,_f.close()

		;~ oADO.Type := 1
		;~ oADO.Open()
		;~ oADO.Write( oHTTP.ResponseBody )
		;~ oADO.SaveToFile( SavePath, 2 )
		;~ oADO.Close()

		In_POST__Out_Data := ""
	}
	Else If InStr(Options, "Charset:")
	{
		RegExMatch(Options, "i)Charset:[ \t]*\K[\w-]+", Encoding)

		oADO.Type     := 1
		,oADO.Mode     := 3
		,oADO.Open()
		,oADO.Write( oHTTP.ResponseBody() )
		,oADO.Position := 0
		,oADO.Type     := 2
		,oADO.Charset  := Encoding
		,In_POST__Out_Data := IsByRef(In_POST__Out_Data) ? oADO.ReadText() : ""
		,oADO.Close()
	}
	Else
		In_POST__Out_Data := IsByRef(In_POST__Out_Data) ? oHTTP.ResponseText : ""
	
	; output headers
	In_Out_HEADERS := "HTTP/1.1 " oHTTP.Status() "`n" oHTTP.GetAllResponseHeaders()

	Return, ReturnCode ; Success = -1, Timeout = 0, No response = Empty String
}