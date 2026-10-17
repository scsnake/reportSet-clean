; ==============================================================================
; Library: ProcessLimit.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

ProcessLimit(ProcessName="", Limit=10, timeout=120000){
	if(ProcessName="")
		ProcessName:=RegExReplace(A_ScriptName, "i).ahk$", ".exe")
	
	t:=A_TickCount
	Loop {
		if (A_TickCount-t > timeout)
			return -1
		
		i:=0
		list:=processList()
		if(!list.setCapacity(0)){
			winget,l,list,ahk_exe %processname%
			if(l>Limit){
				Sleep 1000
				continue
			}else{
				break
			}
		}else{
			for k,v in list
				if(v.NAme=ProcessName){
					if(++i > Limit){
						Sleep 1000
						continue,2
					}
				}
			break
		}
		
		
	}
}
		