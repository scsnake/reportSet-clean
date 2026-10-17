SetBatchLines,-1
#include <httprequest>
getPlace()

; NOTE (CH_RIS IPC migration): stays a LOCAL owner — do NOT set __CH_RIS_CLIENT. It needs
; parse_RIS_LIST(), which drives the RIS list DOM and returns a DataGridTable object (methods
; + .colNos), neither of which can cross the IPC boundary. One-shot on-demand list tool, so a
; transient owner is acceptable (migration targets resident idle owners). See CH_RIS_IPC_HANDOFF.md.
CH_RIS:=new CH_RIS_REPORT()
Reportlist:=CH_RIS.parse_RIS_LIST()

accno_col:=Reportlist.colNos["AccNo"]
examname_col:=Reportlist.colNos["ExamName"]
examdate_col:=Reportlist.colNos["ExamDate"]
Modality_col:=Reportlist.colNos["ExamType"]
DownloadURL:="http://192.0.2.10:5000/acc/"
;~ pwb:=ComObjCreate("InternetExplorer.Application")

target:="XR"
;~ target:="notXR"

fivedays := A_Now
fivedays += -5, Days

ret:=""
for k,v in ReportList {
	accNo:=v[accno_col]

	examName:=v[examname_col]
	examDate:=SubStr(RegExReplace(v[examdate_col], "\D", ""), 1, 8)
	Modality:=v[Modality_col]
	;~ if InStr(accNo, "90877")
		;~ a:=1
	;~ pwb.NAvigate(DownloadURL accno)
	;~ Loop {
		;~ Sleep 100
	;~ }until !pwb.busy
	;~ ToolTip % "Downloading: " accNo
	if (accNo="開單序號") || InStr(examName, "bone age") || (examName~="資源|共享|外院")
		continue
	
	if(target="notXR") && (Modality~="i)X-Ray|BMD|US|MG|特殊|MAMMO" || examDate>20250723)
		continue
	ret.=accNo "`n"
}
FileDelete,% "\\192.0.2.10\scsnake\DICOM\caselist"
FileAppend,% clipboard:=ret,% "\\192.0.2.10\scsnake\DICOM\caselist",utf-8-Raw
MsgBox,,,Done,10
ExitApp
return 



esc::ExitApp