makeGUI(guiTitle, groupName="mainGui"){
	global 
	gui,main:Default
	gui,new
	gui,+hwndguihwnd  -Resize -Caption +AlwaysOnTop
	WinSetTitle,% "ahk_id " guihwnd,,% guiTitle
	GroupAdd,% groupName,ahk_id %guihwnd%
	gui,Font,s12,Calibri
	gui,Add,Text,,Data source

	clipboardTemp:=clipboard
	if InStr(clipboardTemp, "檢查日") && InStr(clipboardTemp, "病歷號") && InStr(clipboardTemp, "檢查名稱") {
		useClip:=true
	}else
		useClip:=false

	gui,Add,Radio,% "vdatasource " ,RIS list (All)
	gui,Add,Radio,% (useClip?"":"checked"),RIS list (Selected)
	gui,Add,Radio,% (useClip?"checked":""),Clipboard

	gui,Add,Text,,Filter
	gui,Add,Radio,% "vopt " (useClip?"checked":""),CXR/KUB/Spine
	gui,Add,Radio,,Ortho films
	gui,Add,Radio,% (useClip?"":"checked"),All
	gui,Add,Radio,,Ortho films (ER)
	

}