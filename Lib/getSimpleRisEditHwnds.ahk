getSimpleRisEditHwnds(guiHwnds=""){
	static Edit1,edit2,edit3
	
	DetectHiddenWindows,on
	
	
	if guiHwnds=
		guiHwnds:=getSimpleRisGuiHwnds()
	v:=guiHwnds[1]
	controlget,editHwnd,hwnd,,Scintilla1,ahk_id %v%
	return [editHwnd, editHwnd]
	
	
	simpleMode:=!!WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI")
	
	ret:=[]
	
	if(simpleMode && controlexists(edit3))
		ret[2]:=edit3
	else if (!simpleMode && controlexists(edit2))
		ret[2]:=edit2
	if controlexists(Edit1)
		ret[1]:=Edit1
		
	;~ if controlexist(Edit1){
		;~ ret[1]:=Edit1
	;~ }
	;~ if controlexist(edit2){
		;~ ret[2]:=edit2
	;~ }
	
	if (ret[1] && ret[2])
		return ret
	
	if guiHwnds=
		guiHwnds:=getSimpleRisGuiHwnds()
	
	
	for k,v in guiHwnds {
		if (v=0){
			ret.push(0)
			continue
		}
		
		controlget,editHwnd,hwnd,,Scintilla1,ahk_id %v%
		if !editHwnd 
			controlget,editHwnd,hwnd,,Edit1,ahk_id %v%
		
		ret.push(editHwnd)
		
		if k=1
			Edit1:=editHwnd
		;~ else
			;~ edit2:=editHwnd
		else if simpleMode
			edit3:=editHwnd
		else
			edit2:=editHwnd
	}
	
	return ret
}

;~ t:=A_TickCount
;~ Loop 1000
;~ getSimpleRisEditHwnds()
;~ MsgBox % (A_TickCount-t)/1000