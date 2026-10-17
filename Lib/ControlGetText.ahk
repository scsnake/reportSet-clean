; ==============================================================================
; Library: ControlGetText.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

ControlGetText(ByRef control="", ByRef title="",ByRef Text="",ByRef exclude_title="",ByRef exclude_text=""){
	if control is integer
	{
	if(title text exclude_title  exclude_text=="")
		return __ControlGetText(hwnd:=control)
	}
	ControlGetText,var,% control,% title,% Text,% exclude_title,% exclude_text
	return var
}




__controlGetText(hwnd){
	if IsObject(hwnd) {
		if (hwnd.__Class="Scintilla") {
			Text:=""
			if (len:=hwnd.GetTextLength())>0
				hwnd.GetText(hwnd.GetTextLength()+4, Text)
		}else if (hwnd.__Class="RemoteScintilla"){
			Text:=hwnd.GetText()
		}
		return Text
	}
	
	WinGetClass,class,ahk_id %hwnd%
	if (class="scintilla") {
		hwnd:=new RemoteScintilla(hwnd)
		return hwnd.GetText()
	}else {
		controlgettext,t,,ahk_id %hwnd%
	}
	return t
}