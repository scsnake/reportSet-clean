FileEncoding,utf-8-Raw
; Does not use CH_RIS — opt out of owning a local (IE-polling) CH_RIS. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <PortalLib>
#include <ImpaxContextServer>
#include <JXON>
SetBatchLines,-1

clip:=Clipboard
ret:=""
FileDelete,result.txt
Loop,Parse,clip,`n
{
	i:=RegExMatch(A_LoopField, "is)\b[a-zA-Z\d]{7}\b", match)
	if (match=""){
		if A_Index!=1
			ret.="nomatch`n"
		continue
	}
		
	chartNo:=match
	;~ if InStr(stas_result, chartNo "`t2")
		;~ continue
	i:=RegExMatch(A_LoopField, "is)\b(\d{4})\/?(\d\d)\/?(\d\d)\b", match)
	if (match="")
		op_date:="00000000"
		;~ continue
	;~ op_date:=match3 fill0(match1) fill0(match2)
	else
	op_date:=match1 fill0(match2) fill0(match3)
	op_date_3w:=op_date
	op_date_3w+=21, Days
	op_date_3w:=SubStr(op_date_3w,1,8)
	ret.=chartNo "`t"
	;~ if !FileExist(path:="C:\Users\IDI\Documents\ImpaxBatch\results\" chartNo ".json"){
	if !FileExist(path:="C:\Users\IDI\Documents\updateOpPatho\json\" chartNo ".json"){
		ret.="nofile`n"
		FileAppend,% ret,result.txt,utf-8-Raw
		ret:=""
		continue
	}
	try {
		fileread,js,% path
	
	js:=jxon_load(js)
	
	;~ for k,v in js {
	for k,v in js.patho {
		;~ if (v.ExamDate<op_date && !(v.ExamName~="i)biopsy|local") && (v.Modality="" || v.Modality~="CT")){
		if (v.date>op_date && v.date<=op_date_3w){
			ret.=v.date ": "
			dom:=ComObjCreate("HtmlFile")
			dom.write(v.Report)
			Report:=dom.getElementById("rReportTab_lsvReportBody_ctrl0_ctl00_TextBox2").innerText
			Report:=RegExReplace(Report, "is)^(.+)(Ref\b.+)?$", "$1")
			Loop,Parse,Report,`n,`r
				if Trim(A_LoopField)=""
					break
				else
					ret.=Trim(A_LoopField) "; "
			ret .= "|"
			
			;~ ret.=v.ExamDate
			;~ if (v.ExamName~="i)request")
				;~ ret.="`t" v.AccNo
				;~ ret.="`t" v.ExamName
				;~ ,ImpaxContextServer_Add(v.AccNo)
				;~ ,ImpaxContextServer_Show(v.AccNo)
			;~ break
			;~ continue,2
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