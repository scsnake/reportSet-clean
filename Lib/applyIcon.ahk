; ==============================================================================
; Library: applyIcon.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

applyIcon(){
	SplitPath,A_ScriptName,,,,n
	try
		menu, tray, icon,% a_scriptdir "\" n ".ico",1,0
}