; ==============================================================================
; Library: wingetcontrollist.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

#include <WinVisible>
WinGetControlList(WinTitle="",WinText="",ExcludeTitle="",ExcludeText=""){
	if WinTitle is Integer
		WinTitle:="ahk_id " WinTitle
	winget,list,controllisthwnd,% WinTitle,% WinText,% ExcludeTitle,% ExcludeText
	ret:=[]
	loop,Parse,list,`n
		ret.push(A_LoopField)
	return ret
}