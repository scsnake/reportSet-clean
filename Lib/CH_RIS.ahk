#include <DebugLog>
#include <ReportImpression>
#include <WinHook>
#include <LineBreakConvert>
#include <SetTimerClass>
#include <CH_Mobile_Bridge>
#include <WM_COPYDATA>
#include <HH_Announce>
#include <JXON>
#include <DataGridTable>
#include <wb>
;~ #include <SCI>
ComObjError(0)
DetectHiddenWindows, On
SetBatchLines,-1

;~ OnMessage(0x4a, "ON_WM_COPYDATA")
;~ global __debug:=true
;~ CH_RIS:=r:=new CH_RIS_REPORT()
;~ MsgBox % r.inputElements.sendSaveSelect.innerHTML
;~ ExitApp
;~ k:=CH_RIS.parse_RIS_LIST()
;~ us:=new CH_RIS_BRUS()

;~ esc::ExitApp
;~ global CH_RIS_REPORT_OBJ:=new CH_RIS_REPORT()
 /*
 On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
; dwData = Command
; cbData = String lenght
; lpData = String
	dwData := NumGet(lParam+0, 0)
	,cbData := NumGet(lParam + A_PtrSize)
	,lpData := NumGet(lParam + 2*A_PtrSize)
	,lpData := StrGet(lpData)
	
	try
		j:=JXON_load(lpData)
	catch
		return
	
	switch j.do {
		case "set_exam":
			Edit_SetText(CH_RIS_REPORT_OBJ.gui.exam_edit, j.value)
			,CH_RIS_REPORT_OBJ.flush()
		case "set_impression":
			Edit_SetText(CH_RIS_REPORT_OBJ.gui.impression_edit, j.value)
			,CH_RIS_REPORT_OBJ.flush()
		case "get":
			value:="0920aec4e4"
			for k,v in j.fields
				if k=1
					value:=CH_RIS_REPORT_OBJ[v]
				else
					value:=value[v]
			
	}
}
 */

class CH_RIS_SYSTEM {
	__New(){
		
		this.hook_new_win()
		,this.auto_login_ris:=true
		,this.ris_login_wbs:=[]
		,this.ris_list_wbs:=[]
		,this.ris_report_wbs:=[]
		,this.scan_IEs()
	}
	
	hook_new_win(){
		
		this.ShellHook:=this.new_win_created.bind(this)
		WinHook.Shell.Add(this.ShellHook,,, "iexplore.exe",1) 

	}
	
	new_win_created(hWnd, win_title, win_class, win_exe, win_event){
		Sleep 500
		if ris_login_wb:=this.is_ris_login(hWnd){
			this.ris_login_wbs.push(ris_login_wb)
			if (this.auto_login_ris)
				this.login_ris(ris_login_wb)
		}
	}
	
	is_ris_login(hWnd){
		wb:=this.wb_hwnd(hWnd)
		if InStr(wb.LocationURL, "/webcvis/comm/log") && wb.document.getElementById("loginButton").id
			return wb
	}
	
	is_ris_list(hWnd){
		wb:=this.wb_hwnd(hWnd)
		
		try {
			MsgBox %  wb.currentSessionID
		}
		
		if InStr(wb.LocationURL, "/webcvis/comm/log") 
			&& (RegExMatch(wb.LocationURL, "jsessionid=(\w+)", jsid) ) {
			this.jsid:=jsid1
			return wb
		}
	}
	
	wb_hwnd(hWnd_or_wb){
		if !IsObject(hWnd_or_wb)
			return WBGet("ahk_id " hWnd_or_wb)
		else 
			return hWnd_or_wb
	}
	
	login_ris(wb=0, wait=true){
		if (wb=0)
			for k,v in this.ris_login_wbs {
				wb:=v
				break
			}
		
		if !wb
			return
		wb.document.getElementsByName("userid")[0].value:=test_userid
		,wb.document.getElementsByName("password")[0].value:=test_pw
		,wb.document.getElementById("loginButton").Click()
		if(wait){
			Loop 
				Sleep 50
			until (!wb.busy && this.is_ris_list(wb)) || A_Index>100
			if this.is_ris_list(wb)
				this.ris_list_wbs[wb.hwnd]:=wb
				,this.ris_login_wbs.delete(wb.hwnd)
			else{
				this.ris_login_wbs[wb.hwnd]:=wb
				return -1
			}
		}
	}
	
	scan_IEs(){
		for wb in ComObjCreate("Shell.Application").Windows() {
			if !InStr(wb.FullName, "iexplore.exe")
				continue
			
			if this.is_ris_list(wb)
				this.ris_list_wbs[wb.hwnd]:=wb
			else if this.is_ris_login(wb)
				this.ris_login_wbs[wb.hwnd]:=wb
		}
		if (this.auto_login_ris)
			this.login_ris(0)
	}
}

class CH_RIS_LIST extends SetTimerClass {
	__New(ByRef wb=""){
		
		if !((hwnd:=this.get_CH_RIS_LIST_hwnd()) && WinExist("ahk_id " hwnd) && !__debug){
			not_exist:=true
			this.setTimer("enhance_button", 1000)
			
		}
			
		
		if(wb && WinExist("ahk_id " wb.hwnd))
			this.wb:=wb
		else{
			for wb in ComObjCreate("Shell.Application").Windows()
				if(wb.hwnd=hwnd){
					this.wb:=wb
					break
				}
		}
		
		if not_exist
		{
			gui,CH_RIS_LIST_GUI:new,,CH_RIS_LIST_GUI
			gui,CH_RIS_LIST_GUI:Add,edit,,% this.wb.hwnd
		}
		
	}
	
	get_table(){
		table := this.wb.document.getElementById("row_main")
		,rows:=table.rows
		,data:=[]
		Loop % (row_count:=rows.length) {
			row := rows[A_Index-1]
			,cells:=row.cells
			,row_data:=[]
			Loop % cells.length {
				cell := cells[A_Index-1]
				,row_data.push(Trim(cell.innerText))
			}
			ToolTip % "Get RIS row: " A_Index " / " row_count
			data.push(row_data)
		}
		ToolTip
		return new DataGridTable(data)
	}
	
	get_CH_RIS_LIST_hwnd(){
		DetectHiddenWindows,on
		ControlGetText,t,Edit1,CH_RIS_LIST_GUI ahk_class AutoHotkeyGUI
		return t+0
	}
	
	enhance_button(){
		enhanced:=false
		wb:=this.wb
		try 
			enhanced:=!!#(wb, "ahk_is_enhanced").value
		try {
			if (#(wb, "QueryButton").id) && !enhanced {
				js=javascript:$('<input type=hidden />').attr('id', 'ahk_is_enhanced').val('1').appendTo($(document.body));void 0;
				wb.navigate(js)
	
				
				FileRead, js, *P65001 %A_ScriptDir%\Lib\CH_RIS_LIST_enhance.js
				execJS(wb, js)
			}
		}
	}
}

class CH_RIS_REPORT extends SetTimerClass  {
	__New(wb=""){
		if InStr(A_ScriptName, "Hotstring Helper")
			return
		
		DebugLog("CH_RIS.__New", "=== CH_RIS_REPORT instantiated PID=" DllCall("GetCurrentProcessId") " script=" A_ScriptName " ===")
		this.inputElements:={}
		,this.pid:=DllCall("GetCurrentProcessId")
		,this.create_gui()
		,this.pacs_hx:={colNo:{hospitalBranch: 1, EIO: 2, ReportVS: 3, examname: 4, examtype: 5, accNo: 6, examdate: 7, Report: 12}
			, colNoReported:{hospitalBranch: 9, EIO: 8, ReportVS: 7, examname: 6, examtype: 5, accNo: 6, examdate: 4, Report: 10}}
		,this.auto_ahk_change:=true
		,this.accNoChangedHookFn:=[]
		,this.pacs_hx_dismissed_accno:=""
		,this.send_report_mode:="normal"
		,this.send_report_mode_accno:=""
		this.refresh_monitor_info()
		OnMessage(0x004E, "WM_NOTIFY")
		settimer,MouseMoveactivate,500
		
		
		if(A_ScriptName~="YCH[ \w]*.ahk|simpleRIS.ahk|autorun.ahk") || __debug
			this.refresh_level:=3
		else 
			this.refresh_level:=0
		
		;~ this.setTimer("accNoChanged", 1000)
		;~ ,this.setTimer("syncReport", 1000)
		this.setTimer("RIS_list_wb_changed", 2000)
		,this.setTimer("check_boneage_window", 5000)
		
		if (wb=""){
			this.update_wb()
		}else
			this.wb:=wb
			,this.setTimer("update_wb", -500)
		this.setTimer("initial_change_ahk", -1500)
		,this.setTimer("mobile_bridge_poll", 250)
		
		
		Hotkey,~!Tab,disableCHRISfocus,on
		;~ this.get_fields()
		;~ this.Parse_pacs_hx()
		;~ this.get_elements()

		
		;~ this.settimer("refresh_info", 500)
		;~ this.hook_new_win()
		
		
	}

	mobile_bridge_poll(){
		if !IsObject(this.wb)
			return
		try {
			doc:=this.wb.document
			request_el:=doc.getElementById("CH-ris-mobile-request")
			if !request_el
				return
			request:=Trim(request_el.value)
			if (request!="") {
				request_el.value:=""
				separator:=InStr(request, "|")
				chart_no:=separator ? SubStr(request,1,separator-1) : request
				if !IsObject(this.mobile_bridge)
					this.mobile_bridge:=new CH_Mobile_Bridge()
				this.mobile_bridge.OpenChart(chart_no)
			}
			status_el:=doc.getElementById("CH-ris-mobile-status")
			if status_el {
				status:=IsObject(this.mobile_bridge) ? this.mobile_bridge.GetStatus() : "Mobile chart ready"
				if (status_el.innerText!=status)
					status_el.innerText:=status
			}
		} catch e {
			; The RIS page may be navigating while this short poll runs.
		}
	}

	refresh_monitor_info(){
		this.monitors:=monitorInfo()
		this.monitor_count:=this.monitors.length()
		return this.monitor_count
	}
	
	RIS_list_wb_changed(){
		for wb in ComObjCreate("Shell.Application").Windows()
			;~ try
			if InStr(WinGetTitle(wb.hwnd), "C醫院") && InStr(wb.LocationURL, ":9090/webcvis/MJB/MJB3W001.do") ;  ip can be 10.0.0.1 or 192.0.2.10
				;~ && (wb.hwnd!=this.ris_list_wb.wb.hwnd && (__debug || !WinExist("CH_RIS_LIST_GUI ahk_class AutoHotkeyGUI"))){
				&& (wb.hwnd!=this.ris_list_wb.wb.hwnd){
				DebugLog("CH_RIS.RIS_list_wb_changed", "RIS list window detected hwnd=" wb.hwnd " url=" wb.LocationURL)
				if IsObject(this.ris_list_wb)
					this.ris_list_wb.DisposeTimers()
				this.ris_list_wb:=new CH_RIS_LIST(wb)
				return
			}
	}
	
	is_boneage_exam(examname:=""){
		if (examname="")
			examname:=this.examname
		return examname~="i)\bbone[\s_-]*age\b"
	}

	boneage_helper_hwnd(){
		return WinExist("Bone Age Report System ahk_class AutoHotkeyGUI")
	}

	open_boneage_helper(){
		if !h:=this.boneage_helper_hwnd() {
			DebugLog("CH_RIS.change_ahk", "opening boneage_CH.ahk for accNo=" this.accNo " examname=" this.examname)
			run % """" A_ScriptDir "\AutoHotkey.exe"" """ A_ScriptDir "\boneage_CH.ahk" """"
		} else {
			winactivate,% "ahk_id " h
		}
	}

	close_boneage_helper(){
		if h:=this.boneage_helper_hwnd() {
			DebugLog("CH_RIS.change_ahk", "closing Bone Age Report System for non-bone-age accNo=" this.accNo " examname=" this.examname)
			WinClose,% "ahk_id " h
		}
	}

	has_active_report_wb(){
		try hwnd:=this.wb.hwnd
		catch
			return false
		if (!hwnd || !WinExist("ahk_id " hwnd))
			return false
		try {
			if !(this.wb.document.getElementById("exam").id)
				return false
		} catch {
			return false
		}
		return true
	}

	clear_current_study(reason:=""){
		if (this.accNo="" && this.accno="" && this.referno="" && this.chartNo="" && this.patno="" && this.examname="" && this.report="")
			return false
		was_boneage:=this.is_boneage_exam()
		DebugLog("CH_RIS.update_wb", "clearing current RIS study: reason=" reason " accNo=" this.accNo " examname=" this.examname)
		if was_boneage
			this.close_boneage_helper()
		this.Pause_refresh:=false
		this.inputElements:={}
		for k, field in ["patno","referno","gender","mciname","checktime","chartNo","accNo","accno","examname","examtime","examdate","birthday","age","mccid","report","exam","impression"]
			this[field]:=""
		this.reset_gui()
		return true
	}

	check_boneage_window(){
		if this.is_boneage_exam() && !this.has_active_report_wb()
			this.clear_current_study("boneage watchdog found no active RIS report window")
		else if this.is_boneage_exam() && this.has_ych_ahk() && !this.boneage_helper_hwnd()
			this.change_ahk()
		this.setTimer("check_boneage_window", 5000)
	}

	parse_RIS_LIST(){
		if !this.ris_list_wb
			this.RIS_list_wb_changed()
		return this.ris_list_wb.get_table()
	}
	
	syncReport(){
		if this.refresh_level<2
			return
		if !WinExist("ahk_id " this.simpleRIS_edit_hwnd)
			this.simpleRIS_edit_hwnd:=getSimpleRisEditHwnds()[1]
		if (Edit_GetText(this.simpleRIS_edit_hwnd)=""){
			reports:=this.split_report(this.report:=this.inputElements.reportText.value)
			,Edit_SetText(this.gui.exam_edit, this.exam:=reports[1])
			,Edit_SetText(this.gui.impression_edit, this.impression:=reports[2])
		}
	}
	
	prettyRisHx(){
		if this.is_pacs_hx_gui_dismissed() {
			DebugLog("CH_RIS.prettyRisHx", "skip user-dismissed accNo=" this.accno)
			return
		}
		this.Parse_pacs_hx()
		if (this.pacs_hx.data_accno!=this.accno || !IsObject(this.pacs_hx.data))
			return
		exam_type:=this.parse_exam_type(this.examname)
		
		if (this.pacs_hx.data.length()=1)
			return this.make_pacs_hx_gui(-1)
		
		new_pacs_hx:=[], no_pacs_hx_gui:=false
		if(exam_type~="CT|MR|特殊"){
			last_exam_type:="CTMR"
			for k,v in this.pacs_hx.data {
				row:=this.copy_pacs_hx_row(v, k)
				if (row[this.pacs_hx_colNo.examtype]~="CT|MR|特殊") {
					new_pacs_hx.push(row), last_exam_type:="CTMR"
				}else{
					if (last_exam_type="CTMR")
						new_pacs_hx.push({"ChildNode":true}),last_exam_type=""
					new_pacs_hx[new_pacs_hx.length()].push(row)
				}
			}
		}else if(exam_type~="US|Mammo"){
			last_exam_type:="mammo"
			for k,v in this.pacs_hx.data {
				row:=this.copy_pacs_hx_row(v, k)
				if (row[this.pacs_hx_colNo.examtype]~="i)US5B|Mammo") {
					new_pacs_hx.push(row), last_exam_type:="mammo"
				}else{
					if (last_exam_type="mammo")
						new_pacs_hx.push({"ChildNode":true}),last_exam_type=""
					new_pacs_hx[new_pacs_hx.length()].push(row)
				}
			}
		}else{
			no_pacs_hx_gui:=true
		}
		
		this.pacs_hx_new:=new_pacs_hx
		gui_signature:=this.make_pacs_hx_gui_signature(exam_type, no_pacs_hx_gui)
		this.make_pacs_hx_gui(no_pacs_hx_gui?-1:0, gui_signature)
	}

	copy_pacs_hx_row(ByRef source_row, source_index){
		row:=[]
		for k,v in source_row
			row[k]:=v
		row.push("#" source_index)  ; index in original pacs_hx.data
		return row
	}

	make_pacs_hx_gui_signature(exam_type, no_pacs_hx_gui=false){
		colNo:=this.pacs_hx_colNo
		sig:=this.accno "|" this.examname "|" this.ChartNo "|" this.patname "|" exam_type "|" no_pacs_hx_gui "|" this.pacs_hx.data_type "|" this.pacs_hx.data.length()
		for k,row in this.pacs_hx.data {
			if !IsObject(row)
				continue
			report:=row[colNo.Report]
			sig.="|" k ":" row[colNo.accNo] ":" row[colNo.examdate] ":" row[colNo.examname] ":" row[colNo.examtype] ":" row[colNo.ReportVS] ":" StrLen(report) ":" report
		}
		return sig
	}

	enhance_pacs_hx_view(){
		if !IsObject(this.wb)
			return false
		try {
			if !(this.wb.document.getElementById("dbrlist").id)
				return false
			FileRead, js, *P65001 %A_ScriptDir%\Lib\CH_RIS_HX_enhance.js
			if (ErrorLevel || js="")
				return false
			wb:=this.wb
			execJS(wb, js)
			DebugLog("CH_RIS.enhance_pacs_hx_view", "injected accNo=" this.accno)
			return true
		} catch e {
			DebugLog("CH_RIS.enhance_pacs_hx_view", "failed accNo=" this.accno " error=" e.Message)
			return false
		}
	}
	
	make_pacs_hx_gui(to_destroy=0, gui_signature:=""){
		global pacs_hx_gui_TV, pacs_hx_gui_hwnd, pacs_hx_gui_TV_hwnd, pacs_hx_report_gui_hwnd
		
		if(to_destroy=-1){
			this.pacs_hx_gui_signature:=""
			this.pacs_hx_gui_accno:=""
			this.pacs_hx_gui_data:=""
			this.pacs_hx_gui_colNo:=""
			gui,pacs_hx_gui:Destroy
			return
		}

		if this.is_pacs_hx_gui_dismissed() {
			DebugLog("CH_RIS.make_pacs_hx_gui", "skip user-dismissed accNo=" this.accno)
			return
		}
		
		existing_hx_hwnd:=0
		if (pacs_hx_gui_hwnd && WinExist("ahk_id " pacs_hx_gui_hwnd))
			existing_hx_hwnd:=pacs_hx_gui_hwnd
		else if (pacs_hx_gui_hwnd:=WinExist("C hospital RIS Hx ahk_class AutoHotkeyGUI"))
			existing_hx_hwnd:=pacs_hx_gui_hwnd
		
		if (existing_hx_hwnd && gui_signature!="" && gui_signature=this.pacs_hx_gui_signature) {
			DebugLog("CH_RIS.make_pacs_hx_gui", "skip unchanged accNo=" this.accno)
			return
		}
		
		if (existing_hx_hwnd && this.pacs_hx_gui_accno=this.accno && pacs_hx_report_gui_hwnd && WinExist("ahk_id " pacs_hx_report_gui_hwnd)) {
			DebugLog("CH_RIS.make_pacs_hx_gui", "skip same-study rebuild while report GUI open accNo=" this.accno)
			return
		}
		
		if existing_hx_hwnd
			gui,pacs_hx_gui:Destroy
		
		gui,pacs_hx_gui:new,+hwndpacs_hx_gui_hwnd +AlwaysOnTop +ToolWindow -Resize
		this.pacs_hx_gui_signature:=gui_signature
		this.pacs_hx_gui_accno:=this.accno
		this.pacs_hx_gui_data:=this.pacs_hx.data
		this.pacs_hx_gui_colNo:=this.pacs_hx_colNo
		GroupAdd,pacs_hx_report_gui,ahk_id %pacs_hx_gui_hwnd%
		gui,pacs_hx_gui:Font,s10 cWhite,Verdana
		gui,pacs_hx_gui:Color,black
		WinSet, TransColor, black,ahk_id %pacs_hx_gui_hwnd%
		winset,trans,200,ahk_id %pacs_hx_gui_hwnd%
		gui,pacs_hx_gui:add,TreeView,backgroundBlack vpacs_hx_gui_TV hwndpacs_hx_gui_TV_hwnd gpacs_hx_gui_TV_event AltSubmit w400 h200 +0x0800
		for k,v in this.pacs_hx_new {
			if (v.haskey("ChildNode")){
				parent_display_text:=""
				pn:=TV_Add("", pacs_hx_gui_TV)
				for _k,_v in v {
					if (_k="ChildNode") 
						continue
					display_text:=_v[this.pacs_hx_colNo.examdate] "_" _v[this.pacs_hx_colNo.examname]  "_" _v[_v.length()]
					TV_Add(display_text, pn)
					
					;~ if InStr(_v[this.pacs_hx_colNo.examtype], "X-Ray(")
						;~ a:=1
					
					if(_v[this.pacs_hx_colNo.examtype]~="US") 
						parent_display_text.=!(parent_display_text~="US") ? "US " :""
					else if(_v[this.pacs_hx_colNo.examtype]~="Mammo") 
						parent_display_text.=!(parent_display_text~="Mammo") ?"Mammo " :""
					else if(_v[this.pacs_hx_colNo.examtype]~="X-Ray")
						parent_display_text.= !(parent_display_text~="XR") ?"XR " :""
					else if !InStr(parent_display_text, _v[this.pacs_hx_colNo.examtype]) 
						parent_display_text.=_v[this.pacs_hx_colNo.examtype] " "
					
					
				}
				TV_Modify(pn, "", Trim(parent_display_text))
				
			}else{
				display_text:=v[this.pacs_hx_colNo.examdate] "_" v[this.pacs_hx_colNo.examname]  "_" v[v.length()]
				TV_Add(display_text, pacs_hx_gui_TV)
			}
		}
		gui,pacs_hx_gui:show,NA x-1024 y-1024,% guititle:="C hospital RIS Hx - " this.ChartNo " " this.patname
		
		this.refresh_monitor_info()
		if (this.monitor_count>=2)
			gui,pacs_hx_gui:show,% "NA " GuiPos(pacs_hx_gui_hwnd, "1r", "c"),% guititle
		else {
			WinGetPos,,,guiW,guiH,% "ahk_id " pacs_hx_gui_hwnd
			mon:=this.monitors[1]
			guiX:=mon.l+Floor((mon.w-guiW)/2)+150
			guiY:=mon.t+Floor((mon.h-guiH)/2)
			gui,pacs_hx_gui:show,% "NA x" guiX " y" guiY,% guititle
		}
	}

	is_pacs_hx_gui_dismissed(){
		return (this.accno!="" && this.pacs_hx_dismissed_accno=this.accno)
	}

	dismiss_pacs_hx_gui(){
		dismissed_accno:=this.pacs_hx_gui_accno
		if (dismissed_accno="")
			dismissed_accno:=this.accno
		if (dismissed_accno!="") {
			this.pacs_hx_dismissed_accno:=dismissed_accno
			DebugLog("CH_RIS.make_pacs_hx_gui", "user dismissed accNo=" dismissed_accno)
		}
		this.pacs_hx_gui_signature:=""
		this.pacs_hx_gui_accno:=""
		this.pacs_hx_gui_data:=""
		this.pacs_hx_gui_colNo:=""
	}
	
	accNoChanged(force=false){
		static prvAccNo
		if (force) || (prvAccNo="") || (prvAccNo!="" && this.AccNo!="" && this.AccNo!=prvAccNo){
			;~ showtooltip(A_TickCount ": " prvAccNo "," this.accNo)
			;~ showtooltip(A_ScriptName "," this.refresh_level)
			;~ filelog(prvAccNo "," this.accNo, a_desktop "\simplerislog.txt")
			;~ this.refresh_info()
			if (this.refresh_level>=2){
				PostMessage,0x2024,,,,simpleRIS_main ahk_class AutoHotkeyGUI
				PostMessage,0x1122,,,,simpleRIS_main ahk_class AutoHotkeyGUI
				this.setTimer("syncReport", -1000)
				if this.has_ych_ahk() || __debug
					this.setTimer("prettyRisHx", -1000)
			}
			for k,v in this.accNoChangedHookFn
				if v
					SetTimerFn(k, -500)

			; Ping cross-process IPC subscribers (clients that registered via sub_accno).
			; List is owned by autorun's CH_RIS_Server; empty/undefined elsewhere -> no-op.
			global __CH_RIS_IPC_AccNoSubs
			if IsObject(__CH_RIS_IPC_AccNoSubs) {
				dead := []
				for h, m in __CH_RIS_IPC_AccNoSubs {
					if WinExist("ahk_id " h)
						PostMessage, % m.msg, % m.wParam + 0, % m.lParam + 0,, % "ahk_id " h
					else
						dead.Push(h)
				}
				for i, h in dead
					__CH_RIS_IPC_AccNoSubs.Delete(h)
			}
					
		}
		if (this.AccNo!="")
			prvAccNo:=this.accNo
	}
	
	AddAccNoChangedHookFn(fn){ ; func obj or bindfunc
		this.accNoChangedHookFn[fn]:=1
	}
	RemoveAccNoChangedHookFn(fn){ ; func obj or bindfunc
		if this.accNoChangedHookFn.haskey(fn)
			this.accNoChangedHookFn[fn]:=0
	}
	
	reset(wait_wb=false, reset_simpleris=false){
		if(wait_wb){
			Loop{
				Sleep 100
				try
					edit_exists:=!!this.wb.document.getElementById("exam").id
				catch
					edit_exists:=false
			} until !this.wb.busy || !edit_exists ||  A_Index>30
			if reset_simpleris
				this.reset_simpleris()
			return this.reset_gui()
		}else
			if reset_simpleris
				this.reset_simpleris()
			
			return this.reset_gui()
	}
	
	reset_simpleris(){
		PostMessage,0x2024,,,,simpleRIS_main ahk_class AutoHotkeyGUI
	}
	
	activate(){
		this.showWb()
		WinActivate,% "ahk_id " this.wb.hwnd
		;~ WinWaitActive,% "ahk_id " this.wb.hwnd,,2
		this.inputElements.reportText.Focus()
	}
	
	check_wb(){
		if !WinExist("ahk_id " this.wb.hwnd)
			this.update_wb()
	}
	
	update_wb(){
		static empty_accno_count:=0, dom_fail_count:=0, last_ready_state:="", _log_sig:="", _log_tick:=0
		wb_gone:=false
		try
			this_wb_hwnd:=this.wb.hwnd
		catch
			wb_gone:=true

		rsState := "", wbBusy := ""
		try rsState := this.wb.ReadyState
		try wbBusy := this.wb.Busy
		; Detect ReadyState transition to 4 (page fully loaded)
		; When this fires, JS has now populated reportText — force a full refresh
		; even if accNo looks unchanged (it was read before JS populated the textarea)
		rs_just_ready := (last_ready_state != 4 && rsState = 4)
		last_ready_state := rsState
		; Throttle the per-poll log: emit only when the (wb/ReadyState/accNo) signature changes
		; or every 60s heartbeat — kills the idle ~2/sec "entry"/"accNo unchanged" flood. Real
		; events (accNo CHANGED / RS->4 / wb lost / re-acquired) below still log unconditionally.
		_sig := wb_gone "|" this_wb_hwnd "|" rsState "|" this.accNo
		_logIdle := (_sig != _log_sig) || (A_TickCount - _log_tick > 60000)
		if (_logIdle) {
			_log_sig := _sig
			, _log_tick := A_TickCount
			, DebugLog("CH_RIS.update_wb", "entry wb_gone=" wb_gone " hwnd=" this_wb_hwnd " ReadyState=" rsState " accNo=" this.accNo (rs_just_ready ? " [RS->4 TRANSITION]" : ""))
		}

		if wb_gone || !WinExist("ahk_id " this_wb_hwnd){
			DebugLog("CH_RIS.update_wb", "wb lost — scanning Shell.Application.Windows for RIS study page")
			found_wb:=false
			for wb in ComObjCreate("Shell.Application").Windows()
			if (WinGetTitle(wb.hwnd)~="i)\/webcvis\/MJB[\w\W]+index=") {
				try {
					__ :=wb.document.getElementById("exam").id
					this.wb:=wb
					found_wb:=true
					DebugLog("CH_RIS.update_wb", "wb re-acquired hwnd=" wb.hwnd " url=" wb.LocationURL)
					WinMaximize,% "ahk_id " wb.hwnd
					break
				}
			}
			if !found_wb {
				this.wb:=""
				this.clear_current_study("RIS report window closed")
			}

		}
		if !IsObject(this.wb) {
			DebugLog("CH_RIS.update_wb", "no RIS study wb available — deferring")
			this.clear_current_study("no RIS study wb available")
			this.setTimer("update_wb", -500)
			return
		}
		if ((rsState!="" && rsState!=4) || wbBusy) {
			if (_logIdle)
				DebugLog("CH_RIS.update_wb", "wb navigating/loading — defer DOM read ReadyState=" rsState " Busy=" wbBusy)
			this.setTimer("update_wb", -500)
			return
		}
		;~ this.get_fields()
		;~ ToolTip % this.accno
		;~ return
		
		try{
			inputs:=this.wb.document.getElementsByTagName("input")
			;~ Loop % (Textareas:=this.wb.document.getElementsByTagName("textarea")).length
				;~ inputs.push(Textareas[A_Index-1])
			wb_accno:="", wb_examname:=""
			Loop % inputs.length {
				try {
					input:=inputs[A_Index-1]
					if (input.name="referno")
						wb_accno:=Trim(input.value)
					else if (input.name="mciname")
						wb_examname:=Trim(input.value)
				}
			}
			;~ if GetKeyState("SHIFT"){
				;~ tmp:=[]
				;~ Loop % inputs.length
					;~ tmp[inputs[A_Index-1].name] := inputs[a_inde-1].value
				;~ MsgBox % empty_accno_count "`n" exploreobj(tmp) 
			;~ }
			if(wb_accno!=""){
				empty_accno_count:=0
				dom_fail_count:=0
				if (wb_accno!=Trim(this.accno) || (wb_examname!="" && wb_examname!=Trim(this.examname))){
					prev_accno:=Trim(this.accno)
					prev_examname:=Trim(this.examname)
					prev_report:=this.report
					try {
						if (prev_report="")
							prev_report:=(new ReportImpression(Edit_GetText(this.gui.exam_edit), Edit_GetText(this.gui.impression_edit))).combine()
					}
					DebugLog("CH_RIS.update_wb", "study CHANGED: accNo '" this.accno "' -> '" wb_accno "', examname '" this.examname "' -> '" wb_examname "' url=" this.wb.LocationURL)
					this.Pause_refresh:=true
					fields_changed:=this.get_fields(inputs)
					if (!fields_changed && (wb_accno!=Trim(this.accno) || (wb_examname!="" && wb_examname!=Trim(this.examname)))) {
						DebugLog("CH_RIS.update_wb", "study change candidate but required fields incomplete/stale — deferring")
						this.Pause_refresh:=false
						this.setTimer("update_wb", -500)
						return
					}
					;~ ShowTooltip(this.refresh_level "," wb_accno)
					if (this.refresh_level>=2) {
						this.begin_pacs_hx_transition_refresh()
						this.setTimer("AccNoChanged", -500)
					}
					this.get_elements()
					this.Pause_refresh:=false
					this.reset_gui()  ; clear stale impression/exam before reading new page DOM
					this.clear_stale_transition_report(prev_accno, prev_examname, prev_report)
					refresh_error:=this.refresh_info(true)
					if (refresh_error=-1) {
						DebugLog("CH_RIS.update_wb", "post-change refresh_info failed — deferring simpleRIS reset")
						this.setTimer("update_wb", -500)
						return
					}
					DebugLog("CH_RIS.update_wb", "post-refresh accNo=" this.accNo " examname=" this.examname " examtime=" this.examtime)
					; try-guard: a missing simpleRIS_main must not throw and abort the poll
					; (which would hit the catch below and wipe accNo -> re-parse churn loop).
					try PostMessage,0x2024,,,,simpleRIS_main ahk_class AutoHotkeyGUI
					DebugLog("CH_RIS.update_wb", "PostMessage 0x2024 -> simpleRIS_main")
					;~ PostMessage,0x2024,,,,simpleRIS__main ahk_class AutoHotkeyGUI
					;~ PostMessage,0x2020,,,,simpleRIS_main ahk_class AutoHotkeyGUI
				}else if (rs_just_ready){
					; Page just finished loading (RS 1->4): JS has now populated reportText.
					; Re-run refresh_info so exam_edit / impression_edit get the real text,
					; then notify simpleRIS via AccNo msg so it re-pulls text1 into the editor.
					DebugLog("CH_RIS.update_wb", "RS->4 with same accNo=" wb_accno " — re-refreshing for reportText")
					refresh_error:=this.refresh_info(true)
					if (refresh_error=-1) {
						DebugLog("CH_RIS.update_wb", "RS->4 refresh_info failed — deferring simpleRIS AccNo notification")
						this.setTimer("update_wb", -500)
						return
					}
					DebugLog("CH_RIS.update_wb", "post RS->4 refresh exam(50)=" SubStr(this.exam,1,50) " imp(50)=" SubStr(this.impression,1,50))
					this.enhance_pacs_hx_view()
					try PostMessage,0x1122,,,,simpleRIS_main ahk_class AutoHotkeyGUI
					DebugLog("CH_RIS.update_wb", "PostMessage 0x1122 (AccNo) -> simpleRIS_main [RS->4 report ready]")
				}else{
					if (_logIdle)
						DebugLog("CH_RIS.update_wb", "accNo unchanged=" wb_accno)
				}
			}else if(wb_accno=""){
				DebugLog("CH_RIS.update_wb", "wb_accno empty count=" empty_accno_count+1)
				if(++empty_accno_count>4){
					empty_accno_count:=0
					this.wb.hwnd:=0
					this.wb:=""
					this.clear_current_study("RIS report accNo empty")
				}
			}
		}catch e {
			DebugLog("CH_RIS.update_wb", "EXCEPTION: " e.Message " | transient count=" dom_fail_count+1)
			if (++dom_fail_count>4){
				dom_fail_count:=0
				this.wb:=""
				this.clear_current_study("RIS report DOM unavailable")
			}
		}
		
		this.setTimer("update_wb", -500)
	}

	normalize_report_text(txt){
		return Trim(LineBreakConvert(txt, "\r?\n", "`n"))
	}

	clear_stale_transition_report(prev_accno, prev_examname, prev_report){
		if (prev_accno="" || prev_accno=Trim(this.accNo))
			return false

		current_report:=""
		try current_report:=this.inputElements.reportText.value
		current_norm:=this.normalize_report_text(current_report)
		if (current_norm="")
			return false

		prev_report_norm:=this.normalize_report_text(prev_report)
		if (prev_report_norm!="" && current_norm=prev_report_norm){
			DebugLog("CH_RIS.update_wb", "stale reportText detected on study change: oldAccNo=" prev_accno " newAccNo=" this.accNo " oldExam='" prev_examname "' newExam='" this.examname "' len=" StrLen(current_report) " -> clear")
			try this.inputElements.reportText.value:=""
			this.report:=""
			return true
		}
		return false
	}

	begin_pacs_hx_transition_refresh(){
		if (this.pacs_hx_dismissed_accno!="" && this.pacs_hx_dismissed_accno!=this.accno) {
			DebugLog("CH_RIS.make_pacs_hx_gui", "clear dismissal oldAccNo=" this.pacs_hx_dismissed_accno " newAccNo=" this.accno)
			this.pacs_hx_dismissed_accno:=""
		}
		this.pacs_hx_pending_accno:=this.accno
		this.pacs_hx_pending_tick:=A_TickCount
		this.pacs_hx_refresh_until:=A_TickCount+5000
		this.pacs_hx.data_accno:=""
		this.pacs_hx.data:=[]
		Edit_SetText(this.gui.old_exam_edit, "")
		Edit_SetText(this.gui.old_impression_edit, "")
		DebugLog("CH_RIS.Parse_pacs_hx", "transition refresh armed accNo=" this.accno)
		this.setTimer("refresh_pacs_hx_after_transition", -1200)
	}

	refresh_pacs_hx_after_transition(){
		if (this.pacs_hx_pending_accno="" || this.pacs_hx_pending_accno!=this.accno)
			return
		if (A_TickCount-this.pacs_hx_pending_tick<1000){
			this.setTimer("refresh_pacs_hx_after_transition", -500)
			return
		}
		wbBusy:=false
		try wbBusy:=this.wb.Busy
		if (wbBusy){
			DebugLog("CH_RIS.Parse_pacs_hx", "transition refresh waiting: wb busy accNo=" this.accno)
			this.setTimer("refresh_pacs_hx_after_transition", -500)
			return
		}
		DebugLog("CH_RIS.Parse_pacs_hx", "transition forced parse accNo=" this.accno)
		parse_ok:=true
		try this.Parse_pacs_hx(true)
		catch e {
			parse_ok:=false
			DebugLog("CH_RIS.Parse_pacs_hx", "transition parse failed accNo=" this.accno " error=" e.Message)
		}
		if (!parse_ok){
			if (A_TickCount<this.pacs_hx_refresh_until)
				this.setTimer("refresh_pacs_hx_after_transition", -1000)
			return
		}
		try PostMessage,0x1124,1,0,,simpleRIS_main ahk_class AutoHotkeyGUI
		if (this.has_ych_ahk() || __debug)
			this.setTimer("prettyRisHx", -1)
		if (A_TickCount<this.pacs_hx_refresh_until)
			this.setTimer("refresh_pacs_hx_after_transition", -1500)
		else
			this.pacs_hx_pending_accno:=""
	}
	
	hook_new_win(){
		
		this.ShellHook:=this.new_win_created.bind(this)
		WinHook.Shell.Add(this.ShellHook,,, "iexplore.exe",1) 
		WinHook.Shell.Add(this.ShellHook,,,,2) 

	}
	
	new_win_created(hWnd, win_title, win_class, win_exe, win_event){	
		switch win_event {
			case 1:
				if(GetKeyState("Shift")){
					ShowTooltip("Shift pressed, close window: " hwnd ", " win_title)
					WinClose,% "ahk_id " hwnd
					return
				}
				Sleep 500
				found:=false
				for wb in ComObjCreate("Shell.Application").Windows()
					if (wb.hwnd=hwnd) && (WinGetTitle(hwnd)~="i)\/webcvis\/MJB[\w\W]+index=") {
						found:=true
						break
					}
				
				if (found){
					
					;~ this.Pause_refresh:=true
					this.wb:=wb
					this.update_wb()
					;~ this.Pause_refresh:=false
					
					
					PostMessage,0x2024,,,,simpleRIS_main ahk_class AutoHotkeyGUI
					;~ PostMessage,0x2024,,,,simpleRIS__main ahk_class AutoHotkeyGUI
					;~ PostMessage,0x2020,,,,simpleRIS_main ahk_class AutoHotkeyGUI
						
				}
			case 2:
				try current_wb_hwnd:=this.wb.hwnd
				catch
					current_wb_hwnd:=0
				if (current_wb_hwnd && hWnd=current_wb_hwnd) {
					this.wb:=""
					this.clear_current_study("current RIS report window destroyed")
				}
		}
	}
	
	get_fields(ByRef inputs=""){
		DebugLog("CH_RIS.get_fields", "entry inputs=" (inputs?"passed":"none") " accNo=" this.accNo)
		if !inputs
			try{
				inputs:=this.wb.document.getElementsByTagName("input")
				;~ Loop % (Textareas := this.wb.document.getElementsByTagName("textarea")).length
					;~ inputs.push(Textareas[A_Index-1])
			} catch e {
				DebugLog("CH_RIS.get_fields", "EXCEPTION getting inputs: " e.Message)
				throw Exception("can't get wb inputs")
			}
		
		temp:={}
		Loop % inputs.length 
			try
			if ((k:=(input:=inputs[A_Index-1]).name)!="" && ((v:=input.value)!="")) || (k~="i)remark") || (input.tagName="textarea" && (k:=input.id)!="")
				temp[k]:=v
		
		
		if (temp.patno!="" && temp.referno!="" && temp.gender!="" && temp.mciname!="" && temp.checktime!=""){
			for k,v in temp
				this[k]:=v
			lastaccNo:=Trim(this.accNo), lastExamName:=Trim(this.examname)
			newAccNo:=Trim(this.referno), newExamName:=Trim(this.mciname)
			if (lastaccNo!=newAccNo || lastExamName!=newExamName)
				this.reset_gui()
			this.chartNo:=this.patno
			,this.accNo:=newAccNo
			,this.gender:=this.gender=1?"M":"F"
			,this.examname:=newExamName
			,this.examtime:=this.checktime ;; 2022-01-04 09:02:37.0
			,this.examdate:=RegExReplace(SubStr(this.examtime,1,10), "\-", "")
			DebugLog("CH_RIS.get_fields", "fields parsed accNo=" this.accNo " examname=" this.examname " examtime=" this.examtime " chartNo=" this.chartNo)

			if (lastaccNo!=this.accNo || lastExamName!=this.examname){
				DebugLog("CH_RIS.get_fields", "study CHANGED: accNo '" lastaccNo "' -> '" this.accNo "', examname '" lastExamName "' -> '" this.examname "'")
				this.refresh_monitor_info()
				disableCHRISfocus()
				if (this.auto_ahk_change) {
					this.change_ahk()
				}
				
				;~ MsgBox,% is_ych_ahk "," monitorInfo().length()
				
				if (this.has_ych_ahk() && this.monitor_count=1){
					;~ MsgBox % WinGetTitle(this.wb.hwnd)
					;; todo: settimer not effect if changed ahk, winshow but not overlap pacs
					;~ WinHide,% "ahk_id " this.HiddenWbHwnd:= this.wb.hwnd
					;~ Hotkey,~#space,ShowWbSub,on
					;~ this.SetTimer("showWb", -6000)
				}
				return true
			}
			
		}
	}
	
	is_ych_ahk(){
		return WinExist("YCH_AHK_main ahk_pid " this.pid) || WinExist("YCH_XR_main ahk_pid " this.pid) || WinExist("YCH_MAMMO_AHK_main ahk_pid " this.pid) || WinExist("YCH_BMD_main ahk_pid " this.pid)
	}

	has_ych_ahk(){
		return WinExist("YCH_AHK_main ahk_class AutoHotkeyGUI") || WinExist("YCH_XR_main ahk_class AutoHotkeyGUI") || WinExist("YCH_MAMMO_AHK_main ahk_class AutoHotkeyGUI") || WinExist("YCH_BMD_main ahk_class AutoHotkeyGUI")
	}
	
	change_ahk(){
		if !this.has_active_report_wb() {
			; The report DOM can be temporarily incomplete while the page is loading.
			; get_fields() calls change_ahk() after assigning the new study, so clearing
			; here makes refresh_info() parse and clear the same study recursively.
			DebugLog("CH_RIS.change_ahk", "defer AHK change until RIS report DOM is ready accNo=" this.accNo " examname=" this.examname)
			return false
		}
		exam_type:=this.parse_exam_type(this.examname)
		has_ych_ahk := this.has_ych_ahk()
		
		if !has_ych_ahk
			return
		
		;~ MsgBox % this.examname "," exam_type
		if this.is_boneage_exam() {
			this.open_boneage_helper()
			return
		}else {
			this.close_boneage_helper()
		}

		if InStr(this.examname,"超音波導引(為組織切片)放射科")
			t:="YCH_MAMMO_AHK_main", e:="YCH_Mammo_Enh.ahk"
		else if (this.examname~="乳房超音波|超音波導引")
			t:="YCH_MAMMO_AHK_main", e:="YCH_Mammo_Enh.ahk"
		else if(this.examname~="i)density|\bBMD\b|骨密|骨質密度|自費-全身體脂肪掃描分析" || this.mccid = 57)
			t:="YCH_BMD_main", e:="YCH_BMD.ahk"
		else if(this.examname~="I\.?V\.?P\.?|血管阻塞")
			t:="YCH_AHK_main", e:="YCH_Enh.ahk"
		else
			switch exam_type {
				case "特殊":
					t:="YCH_AHK_main", e:="YCH_Enh.ahk"
				case "CT", "MR":
					t:="YCH_AHK_main", e:="YCH_Enh.ahk"
				case "Mammo":
					t:="YCH_MAMMO_AHK_main", e:="YCH_Mammo_Enh.ahk"
				case "X-Ray":
					t:="YCH_XR_main", e:="YCH_XR_Enh.ahk"
				
			}
		
		if(t="" || e="")
			return
		;~ MsgBox % WinExist(t " ahk_pid " this.pid) "," t
		if WinExist(t " ahk_class AutoHotkeyGUI")
			return
		
		dir:=A_ScriptDir
		;~ MsgBox % Commands(dir "\" SubStr(e,1,-4) ".exe", dir "\" e)
		
		
		try{
			DebugLog("CH_RIS.change_ahk", "switching to " e " for accNo=" this.accNo " examname=" this.examname " - resetting CH_RIS/simpleRIS before launch")
			this.report:=""
			this.reset(false, true)
			run,% Commands(dir "\" SubStr(e,1,-4) ".exe", dir "\" e),% dir
			; Notify persistent Hotstring Helper which YCH variant is now live.
			; HH_Announce normalises YCH_*_Enh.ahk → YCH_*.ahk for source matching.
			HH_Announce(e)
		}
	}

	initial_change_ahk(){
		if !this.auto_ahk_change
			return
		if !this.has_ych_ahk() {
			if (++this.initial_change_ahk_tries<10)
				this.setTimer("initial_change_ahk", -1000)
			return
		}
		if (this.examname="") {
			try this.update_wb()
			if (++this.initial_change_ahk_tries<10)
				this.setTimer("initial_change_ahk", -1000)
			return
		}
		DebugLog("CH_RIS.initial_change_ahk", "initial script selection for accNo=" this.accNo " examname=" this.examname)
		this.change_ahk()
	}
	
	Parse_pacs_hx(force=false){
		if (this.pacs_hx.data_accno=this.accno && !force){
			this.enhance_pacs_hx_view()
			return
		}
		if (this.pacs_hx_pending_accno=this.accno && !force && this.pacs_hx.data_accno!=this.accno){
			DebugLog("CH_RIS.Parse_pacs_hx", "transition refresh pending; defer caller accNo=" this.accno)
			this.setTimer("refresh_pacs_hx_after_transition", -500)
			return
		}
		
		this.pacs_hx.element:=tb:=this.wb.document.getElementById("row_beforereport")
		
		try
			pacs_hx_element_id := tb.id
		data:=[]
		
		if (pacs_hx_element_id){
			
			Loop % (rows:=tb.rows).length {
				if A_Index=1
					continue
				row_data:=[]
				row:=rows[A_Index-1]
				try row_class:=row.className
				catch
					row_class:=""
				if InStr(" " row_class " ", " CH-hx-synthetic ")
					continue
				Loop % (cells:=row.cells).length {
					if (A_Index=12)
						try
						row_data[A_Index]:=(Trim(RegExReplace(cells[A_Index-1].childNodes[0].value, "s)<br *\/>", "`n")))
					else
						try
						row_data[A_Index]:=(Trim(cells[A_Index-1].innerText))
				}
				data.push(row_data)
			}
			this.pacs_hx.data_type:="colNo"
		}else{
			; The in-page history bar can precede the reported table in #dbrlist.
			box:=this.wb.document.getElementById("dbrlist")
			this.pacs_hx.element:=tb:=box.getElementsByTagName("table")[0]
			
			Loop % (rows:=tb.rows).length {
				if A_Index=1
					continue
				row_data:=[]
				row:=rows[A_Index-1]
				try row_class:=row.className
				catch
					row_class:=""
				if InStr(" " row_class " ", " CH-hx-synthetic ")
					continue
				Loop % (cells:=row.cells).length+1 {
					if (A_Index>cells.length) {
						report_title:=""
						try report_title:=Trim(row.title)
						if (report_title="") {
							cached_row_text:=""
							current_row_text:=""
							try cached_row_text:="" row.getAttribute("data-CH-hx-row-text")
							try current_row_text:="" row.innerText
							if (cached_row_text!="" && cached_row_text=current_row_text)
								try report_title:=Trim("" row.getAttribute("data-CH-hx-native-title"))
						}
						row_data[A_Index]:=report_title
					}
					else
						try
						row_data[A_Index]:=(Trim(cells[A_Index-1].innerText))
				}
				data.push(row_data)
			}
			this.pacs_hx.data_type:="colNoReported"
		
		}
		this.pacs_hx.data_accno:=this.accno
		
		this.pacs_hx.data:=data
		DebugLog("CH_RIS.Parse_pacs_hx", "parsed accNo=" this.accno " rows=" data.Length() " type=" this.pacs_hx.data_type)
		
		this.get_last_report()
		this.enhance_pacs_hx_view()
	}
	
	parse_exam_type(examname){
		
		if(examname~="大腸造影術-使用水溶性顯影劑|Hysterosal|ystography|消化道|食道|小腸|吞|T-tube"){
			return "特殊"
		}else if(examname~="\b(?:CT|CTA|CTV)\b|電腦斷層|心臟鈣化指數|低劑量|肺癌"){
			return "CT"
		}else if(examname~="\b(?:MRI|MRCP|MRA|MRV)\b"){
			return "MR"
		}else if(examname~="i)mammo|乳"){
			return "Mammo"
		}else if(examname~="超音波"){
			return "US"
		}else{
			return "X-Ray"
		}
	}
	
	get_last_report(){
		examtype:=this.parse_exam_type(this.examname)
		
		for k,v in this.pacs_hx.data {
			if InStr(v[this.pacs_hx_colNo.examtype], examtype) && (v[this.pacs_hx_colNo.ReportVS]!="") {
				last_report:=new ReportImpression(v[this.pacs_hx_colNo.Report])
				,Edit_SetText(this.gui.old_exam_edit, last_report.exam)
				,Edit_SetText(this.gui.old_impression_edit, last_report.impression)
			}
		}
	}
	
	get_elements(){
		;~ this.check_wb()
		this.inputElements.examRemark:=this.wb.document.getElementById("remarktx")
		,this.inputElements.chiftComplaints:=this.wb.document.getElementById("memotx")
		,this.inputElements.icdInfo:=this.wb.document.getElementById("icdtx")
		,this.inputElements.openImage:=this.wb.document.getElementById("ImageButton")
		,this.inputElements.saveReport:=this.wb.document.getElementById("saveSelectButton")
		,this.inputElements.priorExam:=this.wb.document.getElementById("prerow")
		,this.inputElements.nextExam:=this.wb.document.getElementById("nextrow")
		,this.inputElements.followPatho:=this.wb.document.getElementById("Chkpatdata")
		,this.inputElements.autoExamName:=this.wb.document.getElementById("isAutoMciname")
		,this.inputElements.reportText:=this.wb.document.getElementById("exam")
		,this.inputElements.sendSaveSelect:=this.wb.document.getElementById("sendSelectButton")
		,this.inputElements.sendSelect:=this.wb.document.getElementById("sendSelect")

		if (this.send_report_mode_accno!=this.accno) {
			this.load_send_report_mode()
			this.send_report_mode_accno:=this.accno
		}
		this.apply_send_report_mode()
	}

	load_send_report_mode(){
		config_path:=A_ScriptDir "\CH_RIS.ini"
		IniRead, mode, % config_path, Settings, sendReportMode, normal
		mode:=Trim(mode)
		StringLower, mode, mode
		if (mode!="normal" && mode!="save") {
			DebugLog("CH_RIS.send_report_mode", "invalid mode='" mode "' in " config_path " - using normal")
			mode:="normal"
		}
		this.send_report_mode:=mode
		DebugLog("CH_RIS.send_report_mode", "configured mode=" mode " accNo=" this.accno)
		return mode
	}

	apply_send_report_mode(){
		desired_value:=(this.send_report_mode="save") ? "0" : "1"
		current_value:=""
		try current_value:=Trim("" this.inputElements.sendSelect.value)
		if (current_value!="0" && current_value!="1") {
			DebugLog("CH_RIS.send_report_mode", "sendSelect state unavailable accNo=" this.accno)
			return false
		}
		if (current_value=desired_value)
			return true

		try {
			this.inputElements.sendSaveSelect.Click()
		} catch e {
			DebugLog("CH_RIS.send_report_mode", "toggle click failed accNo=" this.accno " error=" e.Message)
			return false
		}

		actual_value:=""
		try actual_value:=Trim("" this.inputElements.sendSelect.value)
		if (actual_value!=desired_value) {
			DebugLog("CH_RIS.send_report_mode", "toggle verification failed accNo=" this.accno " desired=" desired_value " actual=" actual_value)
			return false
		}

		icon_src:=""
		try icon_src:=this.wb.document.getElementById("sendSelectButtonImage").src
		DebugLog("CH_RIS.send_report_mode", "applied mode=" this.send_report_mode " accNo=" this.accno " sendSelect=" actual_value " icon=" icon_src)
		return true
	}
	
	
	create_gui(){
		this.gui:={}
		gui,CH_RIS_GUI:new,+hwnd__guiHwnd +toolwindow -caption
		WinSetTitle,ahk_id %__guiHwnd%,,CH_RIS_GUI
		WinHide,ahk_id %__guiHwnd%
		gui,CH_RIS_GUI:Add,Edit,hwnd__editHwnd1 g__6d241884ad75fa6
		gui,CH_RIS_GUI:Add,Edit,hwnd__editHwnd2 g__6d241884ad75fa6
		Loop 11
			gui,CH_RIS_GUI:Add,Edit,% " g__6d241884ad75fa6 hwnd__editHwnd" A_Index+2
		Loop 3
			gui,CH_RIS_GUI:Add,Edit,% " g__6d241884ad75fa6 hwnd__editHwnd" A_Index+13
		Loop 2
			gui,CH_RIS_GUI:Add,Edit,% " g__6d241884ad75fa6 hwnd__editHwnd" A_Index+16
		
		this.gui.guihwnd:=__guihwnd
		,this.gui.exam_edit:=__editHwnd1
		,this.gui.impression_edit:=__editHwnd2
		
		;; ,this.[attr name]_edit_auto will auto update value of ,this.[attr name]
		,this.gui.patname_edit_auto:=__editHwnd3
		,this.gui.accno_edit_auto:=__editHwnd4
		,this.gui.gender_edit_auto:=__editHwnd5
		,this.gui.age_edit_auto:=__editHwnd6
		,this.gui.examname_edit_auto:=__editHwnd7
		,this.gui.examtime_edit_auto:=__editHwnd8
		,this.gui.patidno_edit_auto:=__editHwnd9
		,this.gui.source_edit_auto:=__editHwnd10
		,this.gui.depname_edit_auto:=__editHwnd11
		,this.gui.referdrname_edit_auto:=__editHwnd12
		,this.gui.birthday_edit_auto:=__editHwnd13
		,this.gui.remark_edit_auto:=__editHwnd14
		,this.gui.memo_edit_auto:=__editHwnd15
		,this.gui.icd_edit_auto:=__editHwnd16
		,this.gui.old_exam_edit:=__editHwnd17
		,this.gui.old_impression_edit:=__editHwnd18
		,this.last_reset:=A_TickCount
		
		gui,CH_RIS_GUI:Add,button,hwnd__hideButtonHwnd,Hide
		method := ObjBindMethod(this, "hide_gui")
		GuiControl +g, %__hideButtonHwnd%, %method%
		
		if (__debug){
			this.show_gui()
		}
			
		
	}
	
	show_gui(){
		gui,CH_RIS_GUI:Show
		winset,AlwaysOnTop,on,ahk_id %__guiHwnd%
	}
	
	hide_gui(){
		gui,CH_RIS_GUI:hide
		
	}
	
	HideWb(){
		WinHide,% "ahk_id " this.HiddenWbHwnd:=this.wb.hwnd
	}
	
	ShowWb(){
		WinShow,% "ahk_id " this.HiddenWbHwnd
	}
	
	refresh_info(bypass_get_fields=false){
		;~ if (this.Pause_refresh) || (A_TickCount-this.last_reset<1500)
			;~ return

		DebugLog("CH_RIS.refresh_info", "entry bypass=" bypass_get_fields " accNo=" this.accNo)
		this.doing_refresh:=true
		if (this.accNo!="")
			this.lastaccNo:=this.accNo
		if (!bypass_get_fields || this.accno=""){
			this.doing_refresh:=false
			; Continue in this invocation after get_fields(). Recursive refresh used to
			; exhaust AHK's call-depth limit when a transient callback cleared accNo.
			this.get_fields()
			this.doing_refresh:=true
		}
		;~ if(this.accNo!="" && this.accNo!=ControlGetText(this.gui.accno_edit_auto)){
			try{
			Edit_SetText(this.gui.accno_edit_auto, this.accno)
			,reports:=this.split_report(this.report:=this.inputElements.reportText.value)
			,Edit_SetText(this.gui.exam_edit, this.exam:=reports[1])
			,Edit_SetText(this.gui.impression_edit, this.impression:=reports[2])
			DebugLog("CH_RIS.refresh_info", "GUI updated accNo=" this.accno " exam(50)=" SubStr(reports[1],1,50) " imp(50)=" SubStr(reports[2],1,50))
			for var_edit, edit_hwnd in this.gui {
				if (i:=InStr(var_edit, "_edit_auto")){
					var:=SubStr(var_edit,1,i-1)
					,Edit_SetText(edit_hwnd, this[var])
				}
			}
			}catch {
				;~ Edit_SetText(this.gui.accno_edit_auto, "")
				this.reset_gui()
				this.doing_refresh:=false
				return -1
			}
		;~ }
		this.doing_refresh:=false
	}
	
	reset_gui(){
		this.last_reset:=A_TickCount
		for k,v in this.gui {
			if InStr(k, "edit")
				Edit_SetText(v, "")
		}
	}
	
	exam {
		get {
			return Edit_GetText(this.gui.exam_edit)
		}
		set {
			Edit_SetText(this.gui.exam_edit, value)
			return value
		}
	}
	
	pacs_hx_colNo {
		get {
			return this.pacs_hx[this.pacs_hx.data_type]
		}
	}
	
	impression {
		get {
			return Edit_GetText(this.gui.impression_edit)
		}
		set {
			Edit_SetText(this.gui.impression_edit, value)
			return value
		}
	}
	
	next_study(){
		this.inputElements.nextExam.click()
	}
	prior_study(){
		this.inputElements.priorExam.click()
	}
	
	flush(){
		this.Pause_refresh:=true
		
		report:=new ReportImpression(Edit_GetText(this.gui.exam_edit), Edit_GetText(this.gui.impression_edit))
		
		;~ ,exam_reports:=this.split_report(Edit_GetText(this.gui.exam_edit))
		;~ ,exam:=RegExReplace(exam_reports[1], "(^[\r\n]+)|([\r\n]+$)", "")
		
		;~ ,imp:=Edit_GetText(this.gui.impression_edit) "`n" exam_reports[2]
		;~ ,imp:=Trim(RegExReplace(Trim(imp), "(\r?\n){2,}", "`n"))
		;~ ,imp:=RegExReplace(imp, "(^[\r\n]+)|([\r\n]+$", "")
		;~ ,reports:=LineBreakConvert(RegExReplace(Trim(exam), "[\r\n]*$", "")  (imp=""?"":"`n`nImpression:`n" imp), "\r\n", "`n")
		;~ ToolTip % "//" exam "//`n//" imp "//"
		;~ if (Trim(exam_reports[2])!="")
			;~ Edit_SetText(this.gui.exam_edit, exam)
			;~ ,Edit_SetText(this.gui.impression_edit, imp)
		report.set_text(this.gui.exam_edit, this.gui.impression_edit)
		this.exam:=report.exam
		this.impression:=report.impression
		this.report:=clipboard:=reports:=report.combine()
		;~ showtooltip(reports, 3000)
		set_text_error:=false
		Loop {
			if !WinExist("ahk_id " this.wb.hwnd){
				set_text_error:="no ris ie`n"
				this.Pause_refresh:=false
				return set_text_error
			}
			this.inputElements.reportText.value:=reports
			if (LineBreakConvert(this.inputElements.reportText.value)=LineBreakConvert(reports))
				break
			else if (A_Index>100){
				;~ MsgBox % "//" this.inputElements.reportText.value "//`n//" reports "//"
				clipboard:=reports, set_text_error:="set text not match`n"
				,Edit_SetText(getSimpleRisEditHwnds()[1], RegExReplace(reports, "(?<!\r)\n", "`r`n"))
				this.Pause_refresh:=false
				return set_text_error
			}else
				this.get_elements()
			Sleep 20
		}
		try
		this.inputElements.reportText.setSelectionRange(-1,-1)
		this.Pause_refresh:=false
		return set_text_error
	}
	
	split_report(txt){
		if i:=RegExMatch(txt, "i)(?<=\n)(Impression:|IMP:) *\n?", m){
			return [SubStr(txt,1,i-1), SubStr(txt,i+StrLen(m))]
		}else
			return [txt, ""]
	}
	
	;~ overlay_input(){
		;~ this.create_overlay_input()
		;~ this.move_overlay_input()
	;~ }
	
	;~ create_overlay_input(){
		;~ if WinExist("ahk_id " this.overlay.guihwnd)
			;~ return
		;~ gui,CH_RIS_OVERLAY:default
		;~ gui,+hwnd__guiHwnd +toolwindow -caption +lastfound
		;~ this.overlay.guihwnd:=__guihwnd
		;~ WinSetTitle,ahk_id %__guihwnd%,,CH_RIS_OVERLAY
		;~ gui,color,EEAACC,black
		;~ winset,TransColor,EEAACC
		;~ gui,font,s14 csilver,Georgia
		;~ gui,add,button,w0 h0 g__6d241884ad75fa6
		;~ gui,add,text,vthisAccNoText hwnd__thisAccNoTextHwnd w0 h0
		;~ this.overlay.accNoTextHwnd:=__thisAccNoTextHwnd
		
		
	;~ }
	
	
	enhance_copy_text(){
		enhanced:=false
		wb:=this.wb
		try 
			enhanced:=!!#(wb, "ahk_is_enhanced").value
		try {
			if (#(wb, "exam").id) && !enhanced {
				js=javascript:$('<input type=hidden />').attr('id', 'ahk_is_enhanced').val('1').appendTo($(document.body));void 0;
				wb.navigate(js)
	
				
				js=
				(LTrim %
				
				  // Create the tooltip element
				var tooltip = document.createElement('div');
				tooltip.textContent = 'Text copied!!';
				tooltip.style.display = 'none';
				tooltip.style.position = 'absolute';
				tooltip.style.backgroundColor = '#f0f0f0';
				tooltip.style.border = '1px solid #ccc';
				tooltip.style.padding = '10px';
				tooltip.style.boxShadow = '2px 2px 5px #888888';
				tooltip.style.zIndex = '1';

				// Add the tooltip element to the document body
				document.body.appendChild(tooltip);
				
				// Function to hide the tooltip
				function hideTooltip() {
					tooltip.style.display = 'none';
				}
				function showTooltip(elementToDoubleClick){
				// Get the position of the element
					var rect = elementToDoubleClick.getBoundingClientRect();

					// Set the position of the tooltip to appear near the element
					tooltip.style.left = rect.left + 'px';
					tooltip.style.top = (rect.bottom + 5) + 'px';

					// Show the tooltip
					tooltip.style.display = 'block';

					// Schedule hiding the tooltip after 1 second (1000 milliseconds)
					setTimeout(hideTooltip, 1000);
				}
				
				// Add a double-click event listener to the element
				document.getElementsByTagName('td').addEventListener('dblclick', function () {
				  // Create a temporary input element
				  var tempInput = document.createElement('input');
				  tempInput.value = copyElement.innerText;
				  document.body.appendChild(tempInput);
				  

				  // Select the text inside the input element
				  tempInput.select();

				  try {
					// Execute the copy command
					document.execCommand('copy');
					console.log('Text copied to clipboard.');
					showTooltip(this);
				  } catch (err) {
					console.error('Unable to copy text: ' + err);
				  }

				  // Remove the temporary input element
				  document.body.removeChild(tempInput);
				});
				
				)
				;~ clipboard:=js
				execJS(wb, js0 js)
			}
		}
	}
	
	__Delete(){
		this.showWb()
	}
}


disableCHRISfocus(){
	global CH_RIS
	ComObjError(0)
	try
	if WinExist("ahk_id " CH_RIS.wb.hwnd){
		js=javascript:setFocus=function(){return 0;};void 0;
		CH_RIS.wb.navigate(js)
		;~ execJS(CH_RIS.wb, js)
	}
		
}


ShowWbSub:
WinShow,Internet Explorer
return

__6d241884ad75fa6(CtrlHwnd, GuiEvent, EventInfo, ErrLevel:=""){
	
	return
}


class CH_RIS_BRUS {
	__New(){
		global CH_RIS
		if !CH_RIS
			CH_RIS:=new CH_RIS_REPORT()
		;~ this.check_wb()
		this.get_pos()
	}
	
	get_pos(){
		global CH_RIS
		this.check_wb()
		js=
		(
		javascript:!function(){
			var rect = $('#silverlightControlHost')[0].getBoundingClientRect();
			var val = rect.left + ',' + rect.right + ',' + rect.top + ',' + rect.bottom;
			$('#brus_ele_rect').remove();
			$('<input type=hidden />').attr('id', 'brus_ele_rect').val(val).appendTo($(document.body));
		}();void 0;
		)
		CH_RIS.wb.navigate(js)
		RegExMatch(CH_RIS.wb.document.getElementById("brus_ele_rect").value, "(\d+),(\d+),(\d+),(\d+)", match)
		return {l: match1, r: match2, t: match3, b: match4}
		;~ MsgBox % CH_RIS.wb.getElementById("silverlightControlHost").
	}
	
	click_icon(){
		
	}
	
	check_wb(){
		global CH_RIS
		CH_RIS.check_wb()
	}

	; Hidden input field accessor methods
	GetModalityCode(){
		return this.mccid ? this.mccid : ""
	}

	GetGender(){
		return this.gender ? this.gender : ""
	}

	GetAge(){
		return this.age ? this.age : ""
	}

	GetDepartment(){
		return this.depname ? this.depname : ""
	}

	GetBirthday(){
		return this.birthday ? this.birthday : ""
	}

	GetCheckTime(){
		return this.checktime ? this.checktime : ""
	}

	GetICDInfo(){
		return this.icd ? this.icd : ""
	}

	GetSource(){
		return this.source ? this.source : ""
	}

	GetPACS(){
		return this.pacs ? this.pacs : ""
	}

	GetRemark(){
		return this.remark ? this.remark : ""
	}

	GetMemo(){
		return this.memo ? this.memo : ""
	}
}


WM_NOTIFY(wParam, lParam) {
   Static TVN_GETINFOTIPA := -412, TVN_GETINFOTIPW := -414
   global pacs_hx_gui_TV_hwnd, CH_RIS
   Critical 500
   HWND := NumGet(lParam + 0, 0, "UPtr")
   Code := NumGet(lParam + 0, A_PtrSize * 2, "Int")
   If (HWND = pacs_hx_gui_TV_hwnd) && ((Code = TVN_GETINFOTIPW) || (Code = TVN_GETINFOTIPA)) {
      
	  HITEM  := NumGet(lParam + 0, A_PtrSize * 5, "UPtr")
      TipPtr := NumGet(lParam + 0, A_PtrSize * 3, "UPtr")
      TipLen := NumGet(lParam + 0, A_Ptrsize * 4, "Int")
	  TV_GetText(t, HITEM)
	 if RegExMatch(t, "_#(\d+)$", row_no) && IsObject(CH_RIS.pacs_hx_gui_data) {
		data_row := CH_RIS.pacs_hx_gui_data[row_no1]
		TipTxt:=report:= data_row[CH_RIS.pacs_hx_gui_colNo.Report]
		StrPut(TipTxt, TipPtr, TipLen, Code = TVN_GETINFOTIPW ? "UTF-16" : "CP0")
	}else
		StrPut("", TipPtr, TipLen, Code = TVN_GETINFOTIPW ? "UTF-16" : "CP0")
      ;~ TipTxt := "Code: " . Code . "`nTipLen: " . TipLen . "`nhItem: " . HITEM
      
      Return 0
   }
}

pacs_hx_guiGUIClose:
if IsObject(CH_RIS)
	CH_RIS.dismiss_pacs_hx_gui()
gui,pacs_hx_gui:Destroy
return

pacs_hx_gui_TV_event(){
	global CH_RIS, INFINITT_PACS
	if !IsObject(CH_RIS.pacs_hx_gui_data)
		return
	if(A_GuiEvent ="Normal"){
		TV_GetText(t, A_EventInfo)
		if RegExMatch(t, "_#(\d+)$", row_no) {
			data_row := CH_RIS.pacs_hx_gui_data[row_no1]
			report:= data_row[CH_RIS.pacs_hx_gui_colNo.Report]
			ShowSubGUI(report)
		}
	}else if(A_GuiEvent = "RightClick"){
		TV_GetText(t, A_EventInfo)
		if RegExMatch(t, "_#(\d+)$", row_no) {
			data_row := CH_RIS.pacs_hx_gui_data[row_no1]
			examtype := data_row[CH_RIS.pacs_hx_gui_colNo.examtype]
			if (examtype~="CT")
				modality:="CT"
			else if (examtype~="MR")
				modality:="MR"
			else if (examtype~="Mammo")
				modality:="MG"
			else if (examtype~="X-Ray")
				modality:="DX"
			else
				modality:=""
			
			ShowTooltip("Open study: " (examDate:=data_row[CH_RIS.pacs_hx_gui_colNo.examDate]) " " (examName:=data_row[CH_RIS.pacs_hx_gui_colNo.examname]))
			if !(INFINITT_PACS)
				INFINITT_PACS:=new INFINITT_PACS()
			INFINITT_PACS.openOldStudy({examDate: examDate
					, examname: examname
					, modality: modality})
		}
	}
	
}

ShowSubGUI(t){
	global 
	gui,pacs_hx_report_gui:new,+hwndpacs_hx_report_gui_hwnd +ToolWindow -Caption -Resize  +AlwaysOnTop +Owner%pacs_hx_gui_hwnd%
	GroupAdd,pacs_hx_report_gui,ahk_id %pacs_hx_report_gui_hwnd%
	gui,pacs_hx_report_gui:Color,black
	WinSet, TransColor, black, ahk_id %pacs_hx_report_gui_hwnd%
	winset,trans,200,ahk_id %pacs_hx_report_gui_hwnd%
	gui,pacs_hx_report_gui:Font,s10 cWhite,Georgia
	gui,pacs_hx_report_gui:Add,Edit,ReadOnly w400 h200   hwndpacs_hx_report_edit_hwnd,% t
	Edit_SetSel(pacs_hx_report_edit_hwnd, 0,0)
	if IsObject(CH_RIS) && (CH_RIS.monitor_count<2) {
		gui,pacs_hx_report_gui:show,NA x-1024 y-1024
		WinGetPos,,,guiW,guiH,% "ahk_id " pacs_hx_report_gui_hwnd
		mon:=CH_RIS.monitors[1]
		guiX:=mon.l+Floor((mon.w-guiW)/2)+150
		guiY:=mon.t+Floor((mon.h-guiH)/2)
		gui,pacs_hx_report_gui:show,% "x" guiX " y" guiY
	}else
		gui,pacs_hx_report_gui:show
	
}

MouseMoveactivate(){
	global pacs_hx_report_gui_hwnd, pacs_hx_gui_hwnd
	WinGetPos,,,,,hwnd
	if(hwnd=pacs_hx_report_gui_hwnd || hwnd=pacs_hx_gui_hwnd) && !WinActive("ahk_id " hwnd)
		winactivate,% "ahk_id " hwnd
}

#IfWinActive,ahk_group pacs_hx_report_gui

~LButton::
if !(A_ThisHotkey=A_PriorHotkey && A_TimeSincePriorHotkey<400)
	return
esc::
;~ gui,pacs_hx_report_gui:Destroy
WinClose,A
return
#IfWinActive

~^#!+s::
;~ global __debug:=true
if CH_RIS.has_ych_ahk()
	CH_RIS.show_gui()
return
