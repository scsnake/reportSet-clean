getSimpleRisGuiHwnds(AddToGroup=""){
	static gui1,gui2,gui3,DefaultAddToGroup
	
	DetectHiddenWindows,on
	
	pid:=WinGet("PID", "simpleRIS_main ahk_class AutoHotkeyGUI")
	if (pid){
		gui1:=(WinExist("simple RIS ahk_class AutoHotkeyGUI ahk_pid " pid))
		,addGuiToGroup(gui1, AddToGroup=""?DefaultAddToGroup:AddToGroup)
		,DefaultAddToGroup:=AddToGroup
	}
	return [gui1, gui1]
	
	
	ret:=[]
	if WinExist("ahk_id " gui1)
		ret[1]:=gui1
	else {
		pid:=WinGet("PID", "simpleRIS_main ahk_class AutoHotkeyGUI")
		if (pid){
			ret[1]:=gui1:=(WinExist("simple RIS ahk_class AutoHotkeyGUI ahk_pid " pid))
			,addGuiToGroup(gui1, AddToGroup=""?DefaultAddToGroup:AddToGroup)
			,DefaultAddToGroup:=AddToGroup
		}
			
		else
			ret[1]:=0
		
	}
	
	;~ ret:=[]
	;~ if WinExist("ahk_id " gui2)
		;~ ret[1]:=gui2
	;~ else {
		;~ pid:=WinGet("PID", "simpleRIS__main ahk_class AutoHotkeyGUI")
		;~ if pid
			;~ ret[1]:=gui2:=(WinExist("simple RIS ahk_class AutoHotkeyGUI ahk_pid " pid))
		;~ else
			;~ ret[1]:=0
		
	;~ }
	
	;~ return ret
	
	simpleMode:=!!WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
	,useOld:=false
	if (simpleMode){
		if WinExist("ahk_id " gui3)
			useOld:=gui3
	}else{
		if WinExist("ahk_id " gui2)
			useOld:=gui2
	}
	
	
	if(useOld){
		ret[2]:=useOld
	}else if (pid:=WinGet("PID", "simpleRIS__main ahk_class AutoHotkeyGUI"))
		{
			if(simpleMode && h:=WinExist("simple RIS3 ahk_pid " pid))
				ret[2]:=gui3:=h
				,addGuiToGroup(gui3, AddToGroup=""?DefaultAddToGroup:AddToGroup)
				,DefaultAddToGroup:=AddToGroup
			else{
				old_titlematchmode:=A_TitleMatchMode
				SetTitleMatchMode,1
				if(!simpleMode && h:=WinExist("simple RIS ahk_pid " pid))
					ret[2]:=gui2:=h
					,addGuiToGroup(gui1, AddToGroup=""?DefaultAddToGroup:AddToGroup)
					,DefaultAddToGroup:=AddToGroup
				SetTitleMatchMode,% old_titlematchmode
			}
		}
	
	
	
	return ret
}

addGuiToGroup(hwnd, groupname){
	if groupname=
		return
	if !WinExist("ahk_id " hwnd " ahk_group " groupname)
		GroupAdd,% groupname,% "ahk_id " hwnd
}

;~ t:=A_TickCount
;~ Loop 1000
;~ getSimpleRisGuiHwnds()
;~ MsgBox % (A_TickCount-t)/1000