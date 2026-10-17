FileEncoding,utf-8-Raw
;~ #include <RisImpax>
#include <PortalLib>
;~ #include <ImpaxContextServer>
#include <JXON>
SetBatchLines,-1

clip:=Clipboard
ret:=""
FileDelete,result.txt
Loop,Parse,clip,`n
{
	i:=RegExMatch(thisLine:=A_LoopField, "is)^(\d+) ([a-zA-Z\d]{7}) (\w+) (.+)$", match)
	if (match=""){
		if A_Index!=1
			ret.="`n"
		continue
	}
		
	chartNo:=match2
	ExamDate:=match1
	AccNo:=match3
	;~ op_date_3w:=op_date
	;~ op_date_3w+=21, Days
	;~ ret.=chartNo "`t"
	if !FileExist(path:="E:\scsnake\ImpaxBatch\results\" chartNo ".json"){
	;~ if !FileExist(path:="C:\Users\IDI\Documents\updateOpPatho\json\" chartNo ".json"){
		ret.="nofile`n"
		FileAppend,% ret,result.txt,utf-8-Raw
		ret:=""
		continue
	}
	try {
		fileread,js,% path
	
	js:=jxon_load(js)
	
	for k,v in js {
	;~ for k,v in js.patho {
		if (v.AccNo=AccNo) && !(v.ExamName~="i)with(/without)? contrast")  && !(v.ExamName~="i)biopsy|local|\bPET\b|tomo"){
			ret.=thisLine
			break
		}
	}
	ret.="`n"
	FileAppend,% ret,result.txt,utf-8-Raw
	ret:=""
	}catch, e{
		ret.="error`n"
		FileAppend,% ret,result.txt,utf-8-Raw
		ret:=""
		continue
	}
	
}
;~ clipboard:=ret
ToolTip % "Done"
Sleep 1000
ExitApp

esc::ExitApp