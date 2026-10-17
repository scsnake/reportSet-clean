; ==============================================================================
; Library: WinGetList.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

#include <WinVisible>
WinGetList(WinTitle="",WinText="",ExcludeTitle="",ExcludeText="", WinVisible=true){
	if WinTitle is Integer
		WinTitle:="ahk_id " WinTitle
	winget,list,list,% WinTitle,% WinText,% ExcludeTitle,% ExcludeText
	ret:=[]
	loop % list 
		if (WinVisible(hwnd:=list%a_index%)==WinVisible || WinVisible=="off")
			ret.push(list%a_index%)
	return ret
}