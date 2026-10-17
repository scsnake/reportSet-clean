; ==============================================================================
; Library: TaskKill.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

TaskKill(ProcessNameOrId, force=true, tree=false){
	force:=force?" /F":""
	,tree:=tree?" /T":""
	if (ProcessNameOrId+0==ProcessNameOrId)
		Run,% comspec " /c ""taskkill /PID " ProcessNameOrId force tree """",,Hide
	else{
		Run,% comspec " /c ""taskkill /IM " ProcessNameOrId  ((ProcessNameOrId~="i).exe$")?"":".exe")  force tree """",,Hide
	}
}