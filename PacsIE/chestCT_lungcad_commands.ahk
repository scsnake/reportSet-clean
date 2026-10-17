SetBatchLines,-1
getPlace()

; NOTE (CH_RIS IPC migration): stays a LOCAL owner — do NOT set __CH_RIS_CLIENT. It needs
; parse_RIS_LIST(), which drives the RIS list DOM and returns a DataGridTable object (methods
; + .colNos), neither of which can cross the IPC boundary. One-shot on-demand list tool, so a
; transient owner is acceptable (migration targets resident idle owners). See CH_RIS_IPC_HANDOFF.md.
CH_RIS:=new CH_RIS_REPORT()
Reportlist:=CH_RIS.parse_RIS_LIST()


examname_col:=Reportlist.colNos["examname"]
chartno_col:=Reportlist.colNos["chartno"]
accno_col:=Reportlist.colNos["accno"]
examdate_col:=Reportlist.colNos["examdate"]

All=
ret:="cd ~/PycharmProjects/lungcad &&  `n"
accNos:=""
for k,v in ReportList {
	
	chartno:=v[chartno_col]
	,accno:=v[accno_col]
	,examname:=v[examname_col]
	,examdate:=RegExReplace(v[examdate_col], "\D", "")
	
	;~ for m,n in v
		;~ All.=n "`t"
	;~ All.="`n"
	;~ MsgBox % InStr(examname, "肺癌")
	if !(examname~="i)CHEST CT|肺癌") 
		continue
	;~ pwb.NAvigate(DownloadURL accno)
	;~ Loop {
		;~ Sleep 100
	;~ }until !pwb.busy
	;~ ToolTip % "Downloading: " accNo
	
	ret.="([ ! -f /data/lungCAD/lungNoduleResult/" chartno "_" accno ".json ] && python3 main.py --force --date " SubStr(examdate, 1, 8) " --id " chartNo ")  `n"
	accNos.=accNo "`n"
	
	;~ new_ie := ComObjCreate("InternetExplorer.Application")
	;~ ,new_ie.NAvigate("http://http://192.0.2.10:8001/" SubStr(examdate, 1, 8) "_" chartNo)
	;~ ,new_id.Hidden:=false
}
;~ clipboard:=ret
clipboard:=accNos
ExitApp
return 



esc::ExitApp