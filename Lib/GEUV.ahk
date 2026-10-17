;~ a:=new GEUV
;~ a.ShowPacsHx()
;~ ExitApp
class GEUV {
	static Instances:={}
	static __vars:="ptname|personId|chartNo|AccNo|birthmonth|birthday|birthyear|age|studyDatemonth|studyDateday|studyDateyear|studyTimehour|studyTimemin|studyTimeSec|studyTimeAMPM|ExamName"
	static title_regex:="is)^([^ ]+) \/ ([^病]+) +病歷號碼：(\w{6}\d) +存取編號:([^ ]+) +出生日期:(\d\d)-(\d\d)-(\d+) +年齡:([^ ]+) +日期:(\d\d)-(\d\d)-(\d+) +(\d+):(\d+):(\d+) +(AM|PM) +(.*)$"
	__New(chartNo="", hwnd=""){
		DetectHiddenWindows,On
		SetTitleMatchMode,2
		CoordMode,mouse,Screen
		if WinExist("ahk_id " hwnd){
			if RegExMatch(WinGetTitle(hwnd), GEUV.title_regex, match){
				vars:=GEUV.__vars
				Loop,Parse,vars,|
					this[a_loopfield]:=match%a_index%
				this.viewer_class:=WinGetClass(hwnd)
			}
				
		}
		chartNo:=this.ChartNo
		
		if(chartNo=""){
			for k,v in AltTab_window_list()
				if (v.class~="^Afx:") && RegExMatch(t1:=v.title, t:=GEUV.title_regex, match){
					vars:=GEUV.__vars
					Loop,Parse,vars,|
						this[a_loopfield]:=match%a_index%
					chartNo:=this.chartNo
					,this.viewer_class:=v.class
					break
				}
			if chartNo=
				return
		}
		
		this.ExamDate:=this.StudyDate:=this.StudyDateYear this.StudyDatemonth this.studydateday
		
		while StrLen(chartNo)<7
			chartNo:="0" chartNo
		
		if GEUV.Instances.haskey[chartNo]
			return GEUV.Instances[chartNo]
		
		
		winget,pid,pid,% "ahk_id " hwnd:= WinExist(chartNo " ahk_class " this.viewer_class)
		this.hwnd:=hwnd
		,this.pid:=pid
		,this.chartNo:=chartNo
		,GEUV.Instances[chartNo]:=this
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
			if InStr(cl, className) || InStr(cl, "Afx:" className){
				if(++i = getWhich)
					return returnAcc?ACC_objectfromwindow(A_LoopField):A_LoopField
				else
					arr.push(returnAcc?ACC_objectfromwindow(A_LoopField):A_LoopField)
			}
		}
		
		return arr
		
	}
	
	GetControl(path*){
		root:=ACC_objectfromwindow(this.hwnd)
		for k,v in path {
			if i:=RegExMatch(v, "_(\d+)$", m)
				controlName:=SubStr(v, 1, i-1), controlIdx:=m1
			else
				controlName:=v, controlIdx:=1
			
			root:=this.GetChildWithClassname(root, controlName, controlIdx) 
			if !root
				return
		}
		return root
	}
	
	
	MouseClickAcc(accObj){
		loc:=acc_location(accObj)
		MouseGetPos,x,y
		mouseclick,l,% loc.x+loc.w//2,% loc.y+loc.h//2,1,0
		MouseMove,% x,% y,0
	}
	
	GetMenu(name=""){
		ret:=this.GetControl("DockPane", "ToolBar_3")
		if name=
			return ret
		
		max:=ret.accChildCount
		Loop {
			if ((r:=acc_child(ret, A_Index)).accName=name)
				return r
		}until max=A_Index
		;~ for k,v in acc_children(ret) {
			;~ if (v.accName=name)
				;~ return v
		;~ }
	}

	NavigatorToggle(state="toggle"){
		navigator:=this.GetControl("ControlBar")
		,navigator_state0:=winvisible(navigatorHwnd:=acc_windowfromobject(navigator))
		
		,navigator_toggle_item:=this.GetMenu()
		,loc:=acc_location(navigator_toggle_item, navigator_toggle_item.accChildCount)
		;~ ,loc0:=acc_location(navigator_toggle_item)
		
		MouseGetPos,x,y
		
		if(state="toggle" || navigator_state0!=state){
			;~ acc_get("DoAction", "", 2, navigator_toggle_item)
			;~ ControlGetPos,
			;~ ControlClick,,% "ahk_id " navigatorHwnd,,,,% "x" loc.x-loc0.x+1 " y" loc.y-loc0.y+1
			;~ ControlClick,,% "ahk_id " navigatorHwnd
			;~ acc_child(navigator_toggle_item, 2).accClick()
			mouseclick,l,% loc.x+1,% loc.y+1,1,0
			;~ Loop {
				;~ Sleep 100
			;~ }until winvisible(navigatorHwnd)!=navigator_state0 || A_Index>100
			MouseMove,% x,% y,0
		}
	}
	
	ShowPacsHx(){
		mn:=this.GetMenu("資料夾")
		mn.accDoDefaultAction()
	}
}

;~ new GEUV