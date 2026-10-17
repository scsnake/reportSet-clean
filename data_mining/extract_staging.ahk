FileEncoding,utf-8-Raw
SetBatchLines,-1

clip:=Clipboard
ret:=""
d:="E:\scsnake\2020 lung ca\results"
SetWorkingDir,% d
;~ FileDelete,result.txt
Loop,Parse,clip,`n
{
	i:=RegExMatch(A_LoopField, "is)\b[a-zA-Z\d]{7}\b", match)
	if (match=""){
		if A_Index!=1
			ret.="nomatch`n"
		continue
	}
		
	chartNo:=match
	
	ret.=chartNo "`t"
	stg:=""
	Loop,Files,% chartNo "*",F
	{
		if (A_LoopFileExt!="")
			continue
		if RegExMatch(A_LoopFileName, chartNo "_([^_]+)(?:_([^_]+))?", m){
			stg.=m1 (m2?", " m2:"") "; "
		}
	}
	ret.=RegExReplace(stg, "; $", "") "`n"
}
clipboard:=ret
ToolTip % "Done"
Sleep 1000
ExitApp

esc::ExitApp