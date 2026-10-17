#include <ACC>
#include <winvisible>
;~ CoordMode,mouse,Screen

;~ ebm:= new EBMViewer("")
;~ b:=ebm.ViewerForm
;~ ebm.SelectTool(path:="5.8")
;~ ebm.SelectTool2(path:="10")
;~ ebm.SelectImageGrid(path:="1")
;~ ebm.PopupMenuWin(path:="11")
;~ Loop{
	;~ ToolTip % ebm.isLoading()
	;~ Sleep 500
;~ }
;~ a:=ebm.PatientInfo()
;~ h:=acc_windowfromobject(b)
;~ WinHide,ahk_id %h%
;~ Sleep 5000
;~ WinShow,ahk_id %h%
;~ ExitApp

;~ esc::ExitApp

ImportHotkeyIni(file=""){
	if !FileExist(file)
		file:=A_ScriptDir "\EBMhelperHotkey.ini"
	fileread,ini,% file
	ret:=[], i:=0
	Loop,Parse,ini,`n,`r
	{
		if  RegExMatch(A_LoopField, "\[([^\]]+)\]", match){
			ret[sec:= SubStr("0" ++i,-1) "_" match1]:=[], j:=0
		}else if RegExMatch(A_LoopField, "([^=]+)=([^\n\r]*)", match){
			j++
			if (match2="")
				continue
			
			StringReplace,match2,match2,Shift+,+,All
			StringReplace,match2,match2,Alt+,!,All
			StringReplace,match2,match2,Win+,#,All
			StringReplace,match2,match2,Ctrl+,^,All
			
			ret[sec, SubStr("0" j,-1) "_" match1]:=match2
		}
	}
	return ret
}

class EBMViewer {
	;~ static ToolNames:={01尺寸／縮放: ["原始尺寸"
		;~ , }
	static Instances:={}
	
	__New(chartNo="", hwnd=""){
		DetectHiddenWindows,On
		SetTitleMatchMode,2
		CoordMode,mouse,Screen
		if WinExist("ahk_id " hwnd){
			if RegExMatch(WinGetTitle(hwnd), "is)病歷號: (\w+) 姓名: (\D+) (\d+)(M|F) 日期: (\d{4}\/\d\d\/\d\d) 存取編號: ([TYHA]\w{9}\d)", match)
				chartNo:=match1
		}
		
		if(chartNo=""){
			for k,v in AltTab_window_list()
				if (v.class="TViewerForm") && RegExMatch(v.title, "is)病歷號: (\w+) 姓名: (\D+) (\d+)(M|F) 日期: (\d{4}\/\d\d\/\d\d) 存取編號: ([TYHA]\w{9}\d)", match){
					chartNo:=match1
					break
				}
			if chartNo=
				return
		}
		
		this.patientName:=match2
		,this.patientAge:=match3 match4
		,this.examDate:=match5
		,this.accNo:=match6
		
		while StrLen(chartNo)<7
			chartNo:="0" chartNo
		
		if EBMViewer.Instances.haskey[chartNo]
			return EBMViewer.Instances[chartNo]
		
		
		winget,pid,pid,% "ahk_id " hwnd:= WinExist(chartNo " ahk_class TViewerForm")
		this.hwnd:=hwnd
		,this.pid:=pid
		,this.chartNo:=chartNo
		,EBMViewer.Instances[chartNo]:=this
	}
	
	activate(waitActive=3){
		winactivate,ahk_class TViewerForm
		if(waitActive>0)
			WinWaitActive,ahk_class TViewerForm
	}
	
	ListAllWindowOfSamePid(class=""){
		DetectHiddenWindows,On
		winget,list,list,% "ahk_pid " this.pid
		arr:=[]
		if(class=""){
			Loop % list {
				WinGetTitle,t,% "ahk_id " list%a_index%
				;~ if (chartNo="" || InStr(t, chartNo))
					arr.push(list%a_index%)
			}
		}else{
			Loop % list {
				hwnd:=list%a_index%
				WinGetClass,cl,ahk_id %hwnd%
				WinGetTitle,t,% "ahk_id " hwnd
				;~ clipboard.=cl "`n"
				;~ if InStr(cl, class) && (chartNo="" || InStr(t, chartNo))
				if InStr(cl, class) 
					arr.push(hwnd)
			}
		}
		return arr
	}
	
	GetChildWithClassname(AccOrHwnd, className, getWhich=1, returnAcc=true){
		if !IsObject(AccOrHwnd)
			Acc:=ACC_objectfromwindow(AccOrHwnd), hwnd:=AccOrHwnd
		else
			acc:=AccOrHwnd, hwnd:=acc_windowfromobject(acc)
		
		arr:=[],i:=0
		winget,ControlList,ControlListhwnd,ahk_id %hwnd%
		Loop,Parse,ControlList,`n
		{
			WinGetClass,cl,ahk_id %a_loopfield%
			if InStr(cl, className) || InStr(cl, "T" className){
				if(++i = getWhich)
					return returnAcc?ACC_objectfromwindow(A_LoopField):A_LoopField
				else
					arr.push(returnAcc?ACC_objectfromwindow(A_LoopField):A_LoopField)
			}
		}
		
		return arr
		
	}
	
	__Get(e){
		if e in ViewerForm
			return ACC_objectfromwindow(this.hwnd)
		else if RegExMatch(e, "^([^_]+)_([^_]+)_?([^_]+)?_?([^_]+)?$", m){
			ret:=this[m1]
			Loop 4 {
				i:=A_Index+1
				if (p:=m%i%)=""
					return ret
				else
					ret:=this.GetChildWithClassname(ret, p)
			}
		}else if e in ComSrvMainForm,Application,ChatClientFrm,FrmTag,AkamiCustomizePopupMenuWindow,InputForm
			return ACC_objectfromwindow(this.ListAllWindowOfSamePid("T" e)[1])
		else if e in PriorStudyOSTFrame,ControlBar,DcmPrnThumbFrame
			return this.GetChildWithClassname(this.ViewerForm, "T" e)
		else if e in EBMDAXParkingWindow,DAXParkingWindow,OleDdeWndClass
			return ACC_objectfromwindow(this.ListAllWindowOfSamePid(e)[1])
		
	}
		

	
	
	; path = 1.1 ~ 10.21
	SelectTool(path, rec=0){
		if !RegExMatch(path, "^(\d+)[\.]([\d\.]+)$", m)
			return 1
		pathArr:=[]
		Loop,Parse,path,`.
			pathArr.push(A_LoopField+0)
		
		if !IsObject(this.ToolTab)
			obj:=this.ToolTab:=this.ControlBar_PageControl
		else	
			obj:=this.ToolTab
		
		try {
			loc1:=acc_location(obj, pathArr[1])
			, hwnd:=acc_windowfromobject(obj)
			;~ for k,v in obj:=acc_children(obj)
				;~ if IsObject(v)
					;~ break
			,tabSheets:=this.GetChildWithClassname(obj, "TabSheet", "")
			;~ , tabSheetsHwnd:=acc_windowfromobject(tabSheets)
			,pageScroller:=this.GetChildWithClassname(tabSheets[pathArr[1]], "PageScroller")
			;~ , pageScrollerhwnd:=acc_windowfromobject(pageScroller)
			,ToolBar:=this.GetChildWithClassname(pageScroller, "ToolBar")
			;~ , ToolBarhwnd:=acc_windowfromobject(ToolBar)
			;~ loc2:=acc_location(ToolBar, pathArr[2])
			,loc0:=acc_location(ToolBar, 1)
			;~ obj:=this.GetChildWithClassname(obj[k-1+pathArr[1]], "PageScroller")
			;~ obj:=this.GetChildWithClassname(obj, "ToolBar")
			;~ loc2:=acc_Location(obj, pathArr[2])
			,this.activate()
			MouseGetPos,x,y
			if !this.controlvisible(hwnd){
				Hidden:=true
				,this.PopupMenuWin(5)
				Loop 
					Sleep 10
				until this.controlvisible(hwnd) || A_Index>100
			}
				
			
			mouseclick,L,% loc1.x+Floor(loc1.w/2),% loc1.y+Floor(loc1.h/2),1,0
			Sleep 100	
			mouseclick,L,% loc0.x+ Floor((pathArr[2]-0.2)*loc0.w),% loc0.y+Floor(loc0.h/2),1,1
			;~ return
			MouseMove,% x,% y, 1
			if Hidden
				this.PopupMenuWin(5)
		}catch e {
			if(rec=0){
				this.ToolTab:=this.ControlBar_PageControl
				return this.SelectTool(path , 1)
			}
		}
	}
	
	controlvisible(hwnd){
		WinGetPos,x,y,,,ahk_id %hwnd%
		con:=acc_windowfromobject(Acc_ObjectFromPoint("",x+1,y+1))
		return InStr(WinGetClass(con), "PageControl")
		;~ return con==hwnd
	}
	; path = 1 ~ 18
	SelectTool2(path){
		obj:=this.ControlBar_ToolBar
		
		,loc1:=acc_location(obj, path+0)
		, hwnd:=acc_windowfromobject(obj)

		,this.activate()
		if !this.controlvisible(hwnd){
			Hidden:=true
			,this.PopupMenuWin(5)
			Loop 
				Sleep 10
			until this.controlvisible(hwnd) || A_Index>100
		}
		MouseGetPos,x,y
		mouseclick,L,% loc1.x+loc1.w/2,% loc1.y+loc1.h/2,1,0
		MouseMove,% x,% y, 1
		if Hidden
			this.PopupMenuWin(5)
	}
	
	SelectImageGrid(path){
		obj:=this.ControlBar
		,obj:=this.GetChildWithClassname(obj, "ToolBar", 2)
		,obj:=this.GetChildWithClassname(obj, "ComboBox"), loc1:=acc_location(obj)
		,obj:=acc_get("Object", "3.4", 0, obj)
		,loc2:=acc_location(obj, path+0)
		,this.activate()
		if !this.controlvisible(hwnd){
			Hidden:=true
			,this.PopupMenuWin(5)
			Loop 
				Sleep 10
			until this.controlvisible(hwnd) || A_Index>100
		}
		MouseGetPos,x,y
		mouseclick,L,% loc1.x+loc1.w/2,% loc1.y+loc1.h/2,1,0
		Sleep 100	
		mouseclick,L,% loc2.x+loc2.w/2,% loc2.y+loc2.h/2,1,2
		;~ MouseMove,% loc2.x+loc2.w/2,% loc2.y+loc2.h/2,1
		MouseMove,% x,% y, 0
		if Hidden
			this.PopupMenuWin(5)
	}
	
	PopupMenuWin(path){
		obj:=this.ListAllWindowOfSamePid("TAkamiCustomizePopupMenuWindow")
		
		this.activate()
		for k,v in obj {
			if !winvisible(v)
				continue
			acc:=ACC_objectfromwindow(v)
			,loc:=acc_location(acc)
			MouseGetPos,x,y
			;~ Loop 11 {
				;~ MouseMove,% loc.x+loc.w/22*A_Index-10,% loc.y+loc.h/2
			MouseClick,L,% loc.x+loc.w/22*(path*2-1),% loc.y+loc.h/2,1,0
				;~ Sleep 500
			;~ }
			MouseMove,% x, % y,0
			break
		}
	}
	
	StudyPanel(){
		obj:=this.GetChildWithClassname(this.PriorStudyOSTFrame, "TPanel")
		return obj:=this.GetChildWithClassname(obj, "TPanel")
	}
	
	SeriesPanel(){
		obj:=this.GetChildWithClassname(this.PriorStudyOSTFrame, "TPageScroller")
		return obj:=this.GetChildWithClassname(obj, "TPanel")
	}
	
	isLoading(){
		;~ winget,list,list,% "ahk_pid " this.pid
		;~ Loop % list {
			;~ hwnd:=list%a_index%
			;~ WinGetTitle,t,% "ahk_id " DllCall("GetParent", "Uint", hwnd)
			;~ WinGetClass,cl,ahk_id %hwnd%
			;~ if (cl=="TProgressBar" && InStr(t, this.chartNo))
				;~ return true
		;~ }
		
		;~ return false
		obj:=this.GetChildWithClassname(this.ViewerForm, "TProgressBar")
		,pb_hwnd:=acc_windowfromobject(obj)
		WinGetPos,x,y,w,h,ahk_id %pb_hwnd%
		;~ MouseMove,% x+Floor(w/2),% y+Floor(h/2),0
		;~ MouseGetPos,,,win,con,2
		
		acc_hwnd:=acc_windowfromobject(Acc_ObjectFromPoint("", x+Floor(w/2),y+Floor(h/2)))
		
		;~ p_hwnd:=wingetatcoords(x+Floor(w*4/5), y+Floor(h/2), "id")
		;~ winget,list,list,ahk_class TProgressBar
		;~ return exploreobj(acc_location(obj))
		return pb_hwnd==acc_hwnd
	}
		
	isHidden(){
		hwnd:=acc_windowfromobject(this.ViewerForm)
		WinGetPos,x,y,w,h,ahk_id %hwnd%
		hwnd2:=wingetatcoords(x+Floor(w/2),y+h-10,"id")
		return !winvisible(hwnd) || (hwnd!=hwnd2)
	}
	
	PatientInfo(){
		WinGetTitle,t,% "ahk_id " acc_windowfromobject(this.ViewerForm)
		RegExMatch(t, "is)病歷號: (\w+) 姓名: ([^\s]+) (\d+)(\w) 日期: (\d{4}\/\d\d\/\d\d) 存取編號: ([TYHA]\w{9}\d)", match)
		return {chartNo: match1, name: match2, age: match3, gender: match4, examDate: match5, accNo: match6}
	}
	
	Exists(){
		process,Exist,% this.pid
		if (ErrorLevel~=this.pid || !this.pid) || !WinExist("ahk_id " this.hwnd)
			return false
		else
			return true
	}
	
	quit(){
		WinClose,% "ahk_id " this.hwnd
		winget,l,list,% "ahk_pid " this.pid
		Loop % l 
			WinClose,% "ahk_id " l%a_index%
		process,Close,% this.pid
	}
;~ p:=acc
;~ Loop {
	;~ p:=acc_parent(p)
	;~ if(A_Index>10)
		;~ break
	;~ h:=acc_windowfromobject(p)
	;~ WinGetTitle,t,ahk_id %h%
	;~ WinGetClass,c,ahk_id %h%
	;~ clipboard.=h "," t "," c "`n"
;~ }
;~ }
;~ MsgBox % clipboard
	
}