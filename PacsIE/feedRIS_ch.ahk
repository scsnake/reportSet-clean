#MaxMem 4095
SetTitleMatchMode,2
SetBatchLines,-1
SetControlDelay,-1
ComObjError(false)
DetectHiddenWindows,on
DetectHiddenText,on
#persistent
; NOTE (CH_RIS IPC migration): feedRIS_ch intentionally stays a LOCAL CH_RIS owner — do
; NOT set __CH_RIS_CLIENT here. Its core drives the RIS *list* DOM directly
; (ris_list_wb.wb.document row iteration / row.Click() below), which can't cross the IPC
; boundary, and it batch-WRITES reports to many studies. It is a one-shot on-demand tool
; (runs once, then ExitApp), so the transient second owner is acceptable — the migration
; targets resident idle owners, not short-lived batch runs. See CH_RIS_IPC_HANDOFF.md.
#include <risimpax>


global thisPlace:=getPlace()
feedris_dir := A_MyDocuments "\feedRIS"
feedris_reported_dir := A_MyDocuments "\feedRIS\reported"

FileCreateDir % feedris_dir
FileCreateDir % feedris_reported_dir
priorAccNo:=""
gosub main2

return

main2:
rowdata:=[], AllText:=""

loop,Files,% feedris_dir "\*.txt",F
{
	if is_pause
		loop 999
			Sleep 999
		until !is_pause
	
	if !RegExMatch(A_LoopFileName, "(\w+)\W(\w+)", m)
		continue
	thisAccNo:=m1, thisChartNo:=m2, thisReportFile:=A_LoopFileLongPath
	
	;~ Reportlist:=CH_RIS.parse_RIS_LIST()
	
	found:=false
	
	if (AllText!="" && !RegExMatch(AllText, "\b" thisAccNo "\b"))
		continue 
	
	if rowdata.length() {
		for k,rowtext in rowdata {
			if !InStr(rowtext, thisAccNo)
				continue
			table := CH_RIS.ris_list_wb.wb.document.getElementById("row_main")
			rows:=table.rows
			row:=rows[k]
			row.Click()
			rowdata:=[], AllText:=""
			found:=true
			break
		}
	}else{
		CH_RIS.refresh_info()
		CH_RIS.RIS_list_wb_changed()
		;~ CH_RIS.check_wb()
		table := CH_RIS.ris_list_wb.wb.document.getElementById("row_main")
		rows:=table.rows
	
		Loop % (row_count:=rows.length-1) {
			row := rows[A_Index]
			rowtext:=row.innerText
			rowdata.push(rowtext), allText.=rowText "`n"
			if !InStr(rowtext, thisAccNo)
				continue
			row.Click()
			rowdata:=[], AllText:=""
			found:=true
			break
		}
	}
	if(found){
		;~ CH_RIS.refresh_info()
		loaded:=false
		loop {
			CH_RIS.get_fields()
			if(CH_RIS.accno=thisAccNo && CH_RIS.chartNo=thisChartNo){
				loaded:=true
				break
			}
			Sleep 200
		}until A_Index>40
		if (loaded){
			;~ CH_RIS.check_wb()
			fileread,reportText,% thisReportFile
			reportText:=Trim(RegExReplace(reportText, "is)\r?\n-=-=-=-=-\r?\n?.*", ""))
			CH_RIS.exam:=CH_RIS.report:=reportText
			CH_RIS.flush()
			;~ CH_RIS.inputElements.reportText.value := reportText
			
			CH_RIS.inputElements.saveReport.Click()
			filemove,% thisReportFile,% feedris_reported_dir
			Sleep 700
			WinClose, % "ahk_id " CH_RIS.wb.hwnd
		}
	}
}
ExitApp
return

esc::
is_pause:=!is_pause
return 

main:
Count:=0
Loop {
	CH_RIS.get_fields()
	thisAccNo:=CH_RIS.accno
	thisChartNo:=CH_RIS.chartNo
	if (thisAccNo!="" && thisChartNo!="" && ( thisAccNo!=priorAccNo)){
		break
	}
	if(++Count>10)
		break
	Sleep 200
}
CH_RIS.RIS_list_wb_changed()
CH_RIS.refresh_info()
if (FileExist(ReportFile:=feedris_dir "\" thisAccNo " " thisChartNo ".txt")){
	fileread,reportText,% ReportFile
	reportText:=Trim(RegExReplace(reportText, "is)\r?\n-=-=-=-=-\r?\n?.*", ""))
	
	CH_RIS.exam:=CH_RIS.report:=reportText
	CH_RIS.flush()
	CH_RIS.saveReport.Click()
	filemove,% ReportFile,% feedris_reported_dir,
	priorAccNo:=thisAccNo
}else{
	priorAccNo:=thisAccNo
	ToolTip % CH_RIS.wb.hwnd
	CH_RIS.next_study()
}

Loopmain:
SetTimer,main,-1500
return