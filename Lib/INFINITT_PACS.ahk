#include <SetTimerClass>
;~ #include <indexOf>
#include <acc>
#include <appendItem>
#include <dataGridTable>
DetectHiddenWindows,on
CoordMode,mouse,Screen

;~ i:=0x012213FE
;~ pacs:=(new INFINITT_PACS)
;~ pacs.ClicktoList()
;~ a:=pacs.getControls()
;~ MsgBox %  pacs.examdate_
;~ MsgBox % ControlGetText(i)
;~ MsgBox % (acc_objectfromwindow(i)).accChildCount
;~ MsgBox % WinGet("ProcessName", i)

;~ (new INFINITT_PACS).openOldStudy({examdate:"2024/08/08", modality: "DX"})
;~ MsgBox % (new test)._test_3
;~ esc::ExitApp


INFINITT_PACS_OldStudy_list(){
	static pacs
	if !pacs
		pacs:=new INFINITT_PACS
	pacs.ClickHxButton()
	pacs.getStudyHx()
	prettyStudyHx:=pacs.prettyStudyHx()
	
}

ActivateInfinittViewerFromRIS(){
	hwnd:=FindInfinittViewerHwnd()
	if !hwnd {
		WinActivate,ahk_exe G3PACS.exe
		return false
	}

	if ActivateInfinittViewerWindowVerified(hwnd)
		return true

	; Last-resort nudge for the state where the taskbar button is active but the viewer is not visible.
	WinMinimize,% "ahk_id " hwnd
	Sleep 80
	DllCall("ShowWindow", "Ptr", hwnd, "Int", 9) ; SW_RESTORE
	return ActivateInfinittViewerWindowVerified(hwnd)
}

InfinittPacsAfxClassPattern(windowType=""){
	; The module-address token changed when G3PACS moved from 32-bit to 64-bit.
	; Match the stable MFC role field (:3: main viewer, :b: viewport) instead.
	static prefix:="^Afx:[^:]+"
	return prefix (windowType="" ? ":" : ":" windowType ":")
}

IsInfinittAfxWindow(hwnd, windowType=""){
	return WinExist("ahk_id " hwnd)
		&& (WinGetClass(hwnd) ~= InfinittPacsAfxClassPattern(windowType))
}

GetInfinittViewerHwnds(sortByX=false, visibleOnly=false){
	ret:=[]
	for k, hwnd in WinGetList("ahk_exe G3PACS.exe", "", "", "", "off") {
		if (visibleOnly && !WinVisible(hwnd))
			continue
		if IsInfinittViewerWindow(hwnd)
			ret.push(hwnd)
	}

	if (sortByX && ret.length()>1) {
		Loop % ret.length()-1 {
			changed:=false
			Loop % ret.length()-A_Index {
				i:=A_Index
				WinGetPos,x1,,,,% "ahk_id " ret[i]
				WinGetPos,x2,,,,% "ahk_id " ret[i+1]
				if (x1>x2)
					tmp:=ret[i], ret[i]:=ret[i+1], ret[i+1]:=tmp, changed:=true
			}
			if !changed
				break
		}
	}
	return ret
}

FindInfinittViewerHwnd(which="first", visibleOnly=false){
	sortByX:=(which="leftmost" || (0+which=which))
	viewers:=GetInfinittViewerHwnds(sortByX, visibleOnly)
	if !viewers.length()
		return 0
	if (0+which=which)
		return (which>=1 && which<=viewers.length()) ? viewers[which] : 0
	return viewers[1]
}

GetNthInfinittViewerHwnd(n, visibleOnly=true){
	; n is zero-based to match the multi-display OCR callers.
	return FindInfinittViewerHwnd(n+1, visibleOnly)
}

IsInfinittViewerWindow(hwnd){
	if !WinExist("ahk_id " hwnd)
		return false
	if (WinGetTitle(hwnd)!="INFINITT PACS")
		return false
	if !IsInfinittAfxWindow(hwnd, "3")
		return false
	WinGetPos,,,w,h,% "ahk_id " hwnd
	return (w>300 && h>300)
}

IsInfinittViewportControl(hwnd){
	return IsInfinittAfxWindow(hwnd, "b")
}

ActivateInfinittViewerWindowVerified(hwnd){
	Loop 3 {
		WinShow,% "ahk_id " hwnd
		WinGet,mm,MinMax,% "ahk_id " hwnd
		if (mm=-1)
			DllCall("ShowWindow", "Ptr", hwnd, "Int", 9) ; SW_RESTORE
		DllCall("BringWindowToTop", "Ptr", hwnd)
		WinActivate,% "ahk_id " hwnd
		WinWaitActive,% "ahk_id " hwnd,,1
		if WinActive("ahk_id " hwnd)
			return true

		DllCall("SetForegroundWindow", "Ptr", hwnd)
		Sleep 100
		if WinActive("ahk_id " hwnd)
			return true
	}
	return false
}


class INFINITT_PACS extends SetTimerClass {
	__New(hwnd=""){
		this.renew_hwnd(hwnd)
		this.__StudyHx:={}
		this.RefreshInfo()
		this.SetTimer("RefreshInfo", 500)
		this.monitors:=monitorInfo()
		,this.monitor_count:=this.monitors.length()
		this.StudyHxColNo:={Mark: 1, ExamStatus: 2, Modality: 3, ExamDate: 4, Description: 5}
	}
	
	renew_hwnd(hwnd=""){
		if !WinExist("ahk_id " hwnd?hwnd:this.hwnd){
			for k,v in list:=wingetlist("INFINITT PACS ahk_exe G3PACS.exe","","","","off") {
				if IsInfinittViewerWindow(v) {
					this.hwnd:=v
					this.acc:=acc_objectfromwindow(this.hwnd)
					return this.hwnd
				}
			}
			
		}
	}
	
	CloseProcess(){
		TaskKill("G3PACS.exe")
	}
	
	RefreshInfo(refresh_items=""){
		if (refresh_items="")
			refresh_items:=StrSplit("ChartNo,AccNo,ExamName,PatientName,PatientAge,PatientGender,ExamDate,Windows,Frames", ",")
		
		this.pacsAcc:=this.getPacsParent(true,false)
		
		if HasVal(refresh_items, "ChartNo") || HasVal(refresh_items, "PatientName") || HasVal(refresh_items, "PatientAge") || HasVal(refresh_items, "PatientGender"){
			this.getPatientInfo()
		}
		if HasVal(refresh_items, "ExamDate") || HasVal(refresh_items, "ExamName") {
			if !this.PatientInfoHwnd1
				this.getPatientInfo()
			this.getStudyInfo()
		}
	}
	
	__Get(attr){
		; attr starts with one _ = bivalue var
		; ends with _\d = get array's nth element
		if (attr~="_\d*$") {
			RegExMatch(attr, "^(\w+?)(?:_(\d+)?)$", var)
			
			if IsObject(var_value:=this[var1])
				return var2=""?var_value[1]:var2=0?var_value:var_value[var2]
			else
				return var2=0?[var_value]:var_value
		}
	}
	
	getPatientInfo(){
		static patientInfoRE:="(\w{10})\s*([^\d]+)\s*(\d+[YMD])\|([MF])"

		; Reset accumulators so study changes don't leave stale data
		this.patientInfoHwnd:=[], this.ChartNo:=[], this.PatientName:=[], this.PatientAge:=[], this.PatientGender:=[]

		this.renew_hwnd()
		for k,v in this.getControls() {
			if (WinGetClass(v)="AfxWnd140u" && RegExMatch(ControlGetText(v), patientInfoRE, match)){
				appendItemObj(this, "patientInfoHwnd", v)
				appendItemObj(this, "ChartNo", match1)
				appendItemObj(this, "PatientName", match2)
				appendItemObj(this, "PatientAge", match3)
				appendItemObj(this, "PatientGender", match4)
			}
		}
	}
	
	getChildren(parent_hwnd, class_pattern){
		ret:=[]
		for k,v in this.getControls() {
			if (WinGetClass(v)~=class_pattern) && getparent(v)=parent_hwnd {
				ret.push(v)
			}
		}
		return ret
	}
	
	getStudyInfo(){
		;;; CT, 2022/07/05 11:26:55, HIGH RESOLUTION CHEST CT (無造影劑),

		; Reset accumulators so study changes don't leave stale data
		this.studyInfoHwnd:=[], this.examModality:=[], this.examDate:=[], this.examTime:=[], this.ExamName:=[]

		for k,v in this.patientInfoHwnd {
			patientInfoAcc:=acc_objectfromwindow(v)
			;~ infohwnd:=GetParent(v)
			;~ MsgBox % infohwnd=0x21332
			;~ infoacc:=acc_Parent(patientInfoAcc)
			for k,v_ in this.getChildren(GetParent(v), "AfxWnd"){
				if(v_=v)
					continue
				for k,studyInfoHwnd in this.getChildren(v_, "AfxWnd") {
					infos:=RegExSplit(ControlGetText(studyinfohwnd), "\s*,[,\s]*").split
					appendItemObj(this, "studyInfoHwnd", studyInfoHwnd)
					appendItemObj(this, "examModality", infos[1])
					appendItemObj(this, "examDate", RegExReplace(SubStr(infos[2], 1, 10), "\D", ""))
					appendItemObj(this, "examTime", RegExReplace(SubStr(infos[2], 12, 8), "\D", ""))
					appendItemObj(this, "ExamName", infos[3])
					
				}
			}
			break
			;~ appendItemObj(this, "studyInfoHwnd", acc_windowfromobject(studyInfoAcc), k)
			;~ Text:=ControlGetText(acc_windowfromobject(infoacc))
			
		}
	}
	
	;~ getChartNo(){
		;~ this.getPatientInfo()
		;~ return this.ChartNo
	;~ }
	
	getPacsParent(acc=true, return_one=true){
		return this.getByClassName(InfinittPacsAfxClassPattern("3"), acc, return_one)
	}
	
	activate(){
		winactivate,% "ahk_id " this.hwnd
	}
	
	openOldStudy(filter_dict, which="last"){
		this.activate()
		which:=this.whichMonitor(which)
		Loop 2 {
			this.ClickStudyHxButton(which)
			Sleep 100
			this.getStudyHx(false, which,  filter_dict) ; click while getting rows
			
		}
	}
	
	whichMonitor(which){
		if (which="last")
			return this.monitors.length()-1
		else if (0+which=which)
			return which
		else 
			return 1
	}
	
	ClickStudyHxButton(which=1, getStudyHx=false){
		;~ static prv
		;~ if controlexist(prv)
			;~ button:=prv
		;~ else
		which:=this.whichMonitor(which)
		this.getVMTool(which)
		
		
		for k,v in this.VMToolHwnd_0
			appendItemObj(this, "ClickStudyHxButtonHwnd", acc_windowfromobject(acc_decendantFilter(v, [{class: "Button", name: "Study"}])))
		ControlClick,,% "ahk_id " _:=this.whichByPos("ClickStudyHxButtonHwnd", which)
		
		if getStudyHx
			this.SetTimer("getStudyHx",-100, [false, which])
	}
	
	whichByPos(attr, which=1, pos_x_first=true){
		x_pos:=[]
		,y_pos:=[]
		
		,attr:=this[attr "_0"] 
		which:=this.whichMonitor(which)
		; no need to sort
		if (attr.length()=1){
			return attr[1]
		}
		
		for k,v in attr
			loc:=acc_location(acc_objectfromwindow(v))
			,appendItemObj(x_pos, loc.x, k)
			,appendItemObj(y_pos, loc.y, k)
		
		ret:=[]
		if(pos_x_first){
			for x_pos,ks in x_pos {
				if(ks.length()=1)
					ret.push(ks[1])
				else{
					y_pos2:=[]
					for _,k in ks 
						loc:=acc_location(attr[k])
						,appendItemObj(y_pos2, loc.y, k)
					for y_pos,ks2 in y_pos2
						for _,k in ks2
							ret.push(k)
				}
			}
			;~ hwnds:=[]
			;~ for _,k in ret
				;~ hwnds.push(attr[k])
			return _hwnd:=attr[ret[which]]
		}
		
	}
	
	getVMTool(which=1){
		;~ static prv
		;~ if controlexist(prv)
			;~ return acc?acc_objectfromwindow(prv):prv
		;~ else{
		
		which:=this.whichMonitor(which)
			;~ ret=
			for k,pacs in this.getPacsParent(false, false)
			for k,v in this.getControls(pacs) {
				if (WinGetClass(v)~="AfxWnd140u" && ControlGetText(v)="VMTool"){
					appendItemObj(this, "VMToolHwnd", v)
				}
			}
			;~ ret:=acc_decendantFilter(this.getPacsParent()
			;~ , [{class: "AfxWnd140u"}
				;~ , {class: "AfxWnd140u", name: "VMTool"}])
			;~ if ret
				;~ prv:=ret
			
			return this.whichByPos("VMToolHwnd", which)
		}
	;~ }
	
	prettyStudyHx(studyHx=""){
		if studyHx=
			studyHx:=this.StudyHx
		
		if (this.pacs_hx.data.length()=1)
			return this.make_pacs_hx_gui(-1)
		
		new_pacs_hx:=[]
		last_exam_type:="v"
		for k,v in studyHx.data {
			v.push("#" k)  ; index in original data
			if (v[this.StudyHxColNo.modality]~="CT|MR|MG|US") {
				new_pacs_hx.push(v), last_exam_type:="v"
			}else{
				if (last_exam_type="v")
					new_pacs_hx.push({"ChildNode":true}),last_exam_type=""
				new_pacs_hx[new_pacs_hx.length()].push(v)
			}
		}
		
		this.pacs_hx_new:=new_pacs_hx
		this.make_pacs_hx_gui(no_pacs_hx_gui?-1:0)
	
		
	}
	
	make_pacs_hx_gui(to_destroy=0){
		global pacs_hx_gui_TV, pacs_hx_gui_hwnd, pacs_hx_gui_TV_hwnd
		
		if(to_destroy=-1){
			gui,pacs_hx_gui:Destroy
			return
		}
		guititle:="INFINITT_STUDY_HX"
		if pacs_hx_gui_hwnd:=WinExist(guititle " ahk_class AutoHotkeyGUI")
			return this.pacs_hx_gui_hwnd:=pacs_hx_gui_hwnd
		
		gui,pacs_hx_gui:new,+hwndpacs_hx_gui_hwnd +AlwaysOnTop -Resize
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
					
					if(_v[this.pacs_hx_colNo.examtype]~="X-Ray")
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
		gui,pacs_hx_gui:show,NA x-1024 y-1024,% guititle.=" - " this.ChartNo " " this.patname
		
		if (this.monitor_count>=2)
			gui,pacs_hx_gui:show,% "NA " GuiPos(pacs_hx_gui_hwnd, "2c", "2c"),% guititle
		else
			gui,pacs_hx_gui:show,Center NA,C hospital RIS Hx,% guititle
	}
	
	getStudyHx(getAccOnly=false, which=1, click_filter=false){
		which:=this.whichMonitor(which)
		StudyHxAcc=
		for k,win in wingetlist("ahk_class #32770 ahk_exe G3PACS.exe") 
			for k,v in wingetcontrollist(win){
				if (WinGetClass(v)~="SysListView32"){
					;~ controlget,ret,list,,,ahk_id %v%
					if (StudyHxAcc:=acc_objectfromwindow(v)).accChildCount>=2 {
						appendItemObj(this, "StudyHxHwnd", v)
					}
				}
		}

		; find in cache
		;~ if(this.__StudyHx.HasKey(this.ChartNo)){
			;~ for k,v in this.__StudyHx[this.ChartNo] {
				;~ cache_time:=99999999999999-k
				;~ if DateDiff(cache_time, a_now, true, "minutes")<=60
					;~ return getAccOnly?v.acc:v 
				;~ break
			;~ }
		;~ }
		
		hwnd:=StudyHxHwnd:=this.whichByPos("StudyHxHwnd", which)
		
		if !hwnd ; not found, or closed
			return []
		
		StudyHxAcc:=acc_objectfromwindow(StudyHxHwnd)
		
		if getAccOnly
			return StudyHxAcc
		
		has_clicked := ! click_filter ; if has filter, set 0 for click
		,filter_dict:=click_filter
		
		ret:={acc: StudyHxAcc, ChartNo: this.ChartNo_1}
		data:=[["Mark","ExamStatus","Modality","ExamDate","Description"]]
		,examdate_col := 4
		,modality_col := 3
		,Description_col := 5
		if (StudyHxAcc){
			controlget,Text,list,,,% "ahk_id " hwnd
			for k,v in ParseTable(Text) {
				data.push(v)
				if(!has_clicked){
					if (filter_dict.examdate!="") && !InStr(v[examdate_col], filter_dict.examdate)
						continue
					if (filter_dict.examname!="" && InStr(v[Description_col], filter_dict.examname)) 
					|| (filter_dict.modality!="" && InStr(v[modality_col], filter_dict.modality)){
						ControlClick,% "x50 y" (k*22-11),% "ahk_id " StudyHxHwnd
						has_clicked:=true

					} 
					
				}
			}
		}
		ret.data:=new dataGridTable(data)
		;~ if (this.ChartNo!=""){
			;~ appendItem(this.__StudyHx[this.ChartNo], ret, (99999999999999-a_now))
		;~ }
		return this.StudyHx:=ret
	}
	
	getControls(hwnd=""){
		return wingetcontrollist(hwnd?hwnd:WinExist("INFINITT PACS ahk_exe G3PACS.exe"))
	}

	getViewportControls(parent_hwnd:=""){
		ret:=[]
		parent_hwnd:=parent_hwnd?parent_hwnd:this.renew_hwnd()
		for k, v in this.getControls(parent_hwnd) {
			if IsInfinittViewportControl(v)
				ret.push(v)
		}
		return ret
	}

	getViewportControl(which:="rightmost", parent_hwnd:=""){
		parent_hwnd:=parent_hwnd?parent_hwnd:this.renew_hwnd()
		viewports:=this.getViewportControls(parent_hwnd)
		if !viewports.length()
			return 0

		best:=0
		if (which="largest" || which="image") {
			bestArea:=0
			for k, v in viewports {
				WinGetPos, x, y, w, h, % "ahk_id " v
				if (w < 100 || h < 100)
					continue
				area:=w*h
				if (area > bestArea)
					bestArea:=area, best:=v
			}
			return best
		}

		bestX:=(which="leftmost") ? 999999 : -999999
		for k, v in viewports {
			WinGetPos, x, y, w, h, % "ahk_id " v
			if (w < 100 || h < 100)
				continue
			if (which="leftmost") {
				if (x < bestX)
					bestX:=x, best:=v
			} else {
				if (x > bestX)
					bestX:=x, best:=v
			}
		}
		return best
	}
	
	getByClassName(classNameRE, acc=false, return_one=true){
		ret:=[]
		for k,v in list:=wingetlist("INFINITT PACS ahk_exe G3PACS.exe","","","","off") {
			if (WinGetClass(v)~=classNameRE){
				if return_one
					return acc?acc_objectfromwindow(v):v
				else
					ret.push(acc?acc_objectfromwindow(v):v)
			}
		}
		return ret
	}
	
	getReportingWindow() {
		for k, v in wingetlist("ahk_class #32770 ahk_exe G3PACS.exe", "", "", "", "off") {
			for idx, ctrl in wingetcontrollist(v) {
				if (InStr(ctrl, "RichEdit20W")) {
					for idx2, c in wingetcontrollist(v) {
						if (InStr(c, "Button")) {
							controlgettext, txt, %c%, ahk_id %v%
							if (InStr(txt, "儲存"))
								return v
						}
					}
				}
			}
		}
		return 0
	}

	InvokeReportingAction(actionName) {
		hwnd := this.getReportingWindow()
		if (!hwnd)
			return false
		for idx, ctrl in wingetcontrollist(hwnd) {
			if (InStr(ctrl, "Button")) {
				controlgettext, txt, %ctrl%, ahk_id %hwnd%
				if (InStr(txt, actionName)) {
					ControlClick, %ctrl%, ahk_id %hwnd%
					return true
				}
			}
		}
		return false
	}

	SaveReport() {
		return this.InvokeReportingAction("儲存")
	}

	ApproveReport() {
		return this.InvokeReportingAction("批准")
	}

	ClearSearchConditions() {
		this.renew_hwnd()
		hwnd := this.hwnd
		for idx, ctrl in wingetcontrollist(hwnd) {
			if (InStr(ctrl, "Button")) {
				controlgettext, txt, %ctrl%, ahk_id %hwnd%
				if (InStr(txt, "清除搜尋條件")) {
					ControlClick, %ctrl%, ahk_id %hwnd%
					return true
				}
			}
		}
		return false
	}

	ClicktoList(){
		this.renew_hwnd()
		if (this.monitor_count=1){
			this.activate()
			WinGetPos,x,y,w,h,% "ahk_id " this.hwnd
			mouseclick,L,% x+25,% y+140,1,0
			Sleep 1000
			mouseclick,L,% x+370,% y+158,2,0
		}
	}
}
