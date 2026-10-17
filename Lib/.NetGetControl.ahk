
#include <RemoteScintilla>
;~ #include <getControlNameByHwnd64>
#include <ACC>

hModuleKernel := DllCall("LoadLibrary", "Str", "Kernel32.dll", "Ptr")  

listAccChildProperty(hwnd){
	
}	

;~ #include <risimpax>
;~ MsgBox % getControlNameByHwnd(RisOpened()[2],0xC1BC8)
;~ ExitApp

getControlNameByHwnd(winHwnd,controlHwnd, tried=0){
	;~ if(A_Is64bitOS){
		;~ if WinExist("ahk_exe getControlNameByHwnd64.exe")
			;~ return getControlNameByHwnd64(winHwnd, controlHwnd)
	;~ }
	bufSize:=1024
	winget,processID,pid,ahk_id %winHwnd%
	VarSetCapacity(var1,bufSize)
	getName:=DllCall( "RegisterWindowMessage", "str", "WM_GETCONTROLNAME" )
	if(ErrorLevel || !getName)
		goto getControlNameByHwnd_FAIL
	
	;~ dwResult:=DllCall("GetWindowThreadProcessId", "Ptr", winHwnd)
	;~ if(ErrorLevel && ErrorLevel!="A-4" )
		;~ goto getControlNameByHwnd_FAIL
	
	hProcess:=DllCall("OpenProcess", "UInt", 0x8 | 0x10 | 0x20, "Uint", 0, "UInt", processID, "Ptr")
	if(ErrorLevel || !hProcess)
		goto getControlNameByHwnd_FAIL
	
	otherMem:=DllCall("VirtualAllocEx", "Ptr", hProcess, "Ptr", 0, "PTR", bufSize, "UInt", 0x3000, "UInt", 0x0004, "Ptr")
	if(ErrorLevel || !otherMem)
		goto getControlNameByHwnd_FAIL

	SendMessage,%getName%,%bufSize%,%otherMem%,,ahk_id %controlHwnd%
	if(ErrorLevel="FAIL")
		goto getControlNameByHwnd_FAIL
	
	DllCall("ReadProcessMemory","Ptr",hProcess,"Ptr",otherMem,"Str",var1,"UInt",bufSize,"Ptr",0)
	,DllCall("VirtualFreeEx","Ptr", hProcess,"Ptr",otherMem,"UInt", 0, "UInt", 0x8000)
	,DllCall("CloseHandle","Ptr",hProcess)
	return var1
getControlNameByHwnd_FAIL:
	;~ ToolTip % "A_LastError: " A_LastError
	if(tried>2)
		return A_LastError
	else
		return getControlNameByHwnd(winHwnd, controlHwnd, ++tried)
}

getControlNameByHwnd64(winHwnd, controlHwnd){
	return
	SetBatchLines,-1
	DetectHiddenWindows,on
	process,Exist,getControlNameByHwnd64.exe
	if(!ErrorLevel){
		ToolTip % "Please run ""getControlNameByHwnd64.exe""!"
		return
	}
	
	processID:=ErrorLevel
	
	bufSize=65536
	VarSetCapacity(var1,bufSize)
	getName:=DllCall( "RegisterWindowMessage", "str", "WM_GETCONTROLNAME" )
	if(ErrorLevel || !getName)
		return A_LastError
	
	
	;~ dwResult:=DllCall("GetWindowThreadProcessId", "Ptr", winHwnd)
	;~ if(!dwResult)
		;~ return A_LastError
	
	hProcess:=DllCall("OpenProcess", "UInt", 0x8 | 0x10 | 0x20, "Uint", 0, "UInt", processID, "Ptr")
	if(ErrorLevel || !hProcess)
		return A_LastError
	
	otherMem:=DllCall("VirtualAllocEx", "Ptr", hProcess, "Ptr", 0, "PTR", bufSize, "UInt", 0x3000, "UInt", 0x0004, "Ptr")
	if(ErrorLevel || !otherMem)
		return A_LastError

	SendMessage,%getName%,%bufSize%,%otherMem%,,ahk_id %controlHwnd%
	if(ErrorLevel="FAIL")
		return
	DllCall("ReadProcessMemory","Ptr",hProcess,"Ptr",otherMem,"Str",var1,"UInt",bufSize,"Ptr",0)
	,DllCall("VirtualFreeEx","Ptr", hProcess,"Ptr",otherMem,"UInt", 0, "UInt", 0x8000)
	,DllCall("CloseHandle","Ptr",hProcess)
	return var1
	
}


getControlNameByHwnd2(_, controlHwnd){
	UIAutomation := ComObjCreate("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
	,DllCall(NumGet(NumGet(UIAutomation+0)+6*A_PtrSize), "Ptr", UIAutomation, "Ptr", controlHwnd, "Ptr*", IUIAutomationElement)
	,DllCall(NumGet(NumGet(IUIAutomationElement+0)+29*A_PtrSize), "Ptr", IUIAutomationElement, "Ptr*", automationId)
	,ret := StrGet(automationId,, "UTF-16")
	,DllCall("oleaut32\SysFreeString", "Ptr", automationId)
	,ObjRelease(IUIAutomationElement)
	,ObjRelease(UIAutomation)
	return ret
}

;~ a:=A_TickCount
;~ Loop 100
	;~ ToolTip % getByControlName2(RisOpened()[2],"EXAMITEM")[1]
;~ MsgBox % A_TickCount-a
;~ ExitApp

; search by control name
; return hwnd 
getByControlName(winHwnd,name){
	winget,controlList,controlListhwnd,ahk_id %winHwnd%
    arr:=[]
    ,bufSize=1024
	winget,processID,pid,ahk_id %winHwnd%
	VarSetCapacity(var1,bufSize)
	if !(getName:=DllCall( "RegisterWindowMessage", "str", "WM_GETCONTROLNAME" )) || ErrorLevel
        return []
	dwResult:=DllCall("GetWindowThreadProcessId", "Ptr", winHwnd)
      
	if !(hProcess:=DllCall("OpenProcess", "UInt", 0x8 | 0x10 | 0x20, "Uint", 0, "UInt", processID), "Ptr") || ErrorLevel
        return []
    if !(otherMem:=DllCall("VirtualAllocEx", "Ptr", hProcess, "Ptr", 0, "PTR", bufSize, "UInt", 0x3000, "UInt", 0x0004, "Ptr")) || ErrorLevel
        return []
    
	loop,parse,controlList,`n
	{
        SendMessage,%getName%,%bufSize%,%otherMem%,,ahk_id %a_loopfield%
        if errorlevel=FAIL
            return []
        if !DllCall("ReadProcessMemory","Ptr",hProcess,"Ptr",otherMem,"Str",var1,"UInt",bufSize,"Ptr",0)
            return []
        if (var1=name)
            arr.push(a_loopfield)
            ,var1:=""
	}
    
    DllCall("VirtualFreeEx","Ptr", hProcess,"Ptr",otherMem,"UInt", 0, "UInt", 0x8000)
	,DllCall("CloseHandle","Ptr",hProcess)
    return arr
}

getByControlName2(winHwnd,name){
	winget,controlList,controlListhwnd,ahk_id %winHwnd%
    arr:=[], UIAutomation := ComObjCreate("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
	Loop,Parse,controllist,`n
	{
		controlHwnd:=A_LoopField
		,DllCall(NumGet(NumGet(UIAutomation+0)+6*A_PtrSize), "Ptr", UIAutomation, "Ptr", controlHwnd, "Ptr*", IUIAutomationElement)
		,DllCall(NumGet(NumGet(IUIAutomationElement+0)+29*A_PtrSize), "Ptr", IUIAutomationElement, "Ptr*", automationId)
		,controlName := StrGet(automationId,, "UTF-16")
		
		if(controlName = name){
			;~ ret:=controlHwnd
			;~ break
			arr.push(controlHwnd)
		}
	}
	
	if (automationId)
		DllCall("oleaut32\SysFreeString", "Ptr", automationId)
	if (IUIAutomationElement)
		ObjRelease(IUIAutomationElement)
	ObjRelease(UIAutomation)
	return arr
	
}






getNetAcc(winHwnd,controlName,classNN,shift=0,acc=true,name="",text="", getNonEmpty=false){
	ret:=getNetControl2(winHwnd,text,controlName,name,classNN,"","","",shift)
	
	if(getNonEmpty || InStr(classNN,"Edit"))
		ret:=getNonEmptyControl(ret)
	
	if (acc){
		return acc_objectfromwindow(ret[1])
	}else 
		return ret[1]
}

/*
param[n].winHwnd
param[n].text
...
*/

getNetControls(ByRef param){
	ret:=[]
	,winHwndControls:=[]
	
	for k,v in param {
		if !IsObject(v) {
			oneParam:=true
			v:=param
		}
		if (winHwnd:=v.winHwnd) && WinExist("ahk_id " winHwnd) {
			if(winHwndControls.hasKey(winHwnd))
				list:=winHwndControls[winHwnd]
			else{
				winget,list,controllisthwnd,ahk_id %winHwnd%
				winHwndControls[winHwnd]:=list
			}
		}else{
			continue
		}
		
		for x,y in ["text", "ClassNN", "controlName", "accName", "accHelp", "accRole", "style", "shift", "getNonEmpty"]
			%y%:=v[y]
		if(shift="")
			shift:=0
		arr:=[],controlArr:=[]
		loop,parse,list,`n 
		{
			controlArr.push(a_loopfield)
			if (text="" || instr(controlgettext(a_loopfield),text)) && (classNN="" || instr(winGetClass(a_loopfield),classNN)) && (controlName="" || getControlNameByHwnd(winHwnd,a_loopfield)=controlName) && (accName="" || instr((acc:=acc_objectfromwindow(a_loopfield)).accName,accName)) && (accHelp="" || instr(acc.accHelp,accHelp)) && (accRole="" || instr(acc.accRole,accRole)) && (!style || DllCall("GetWindowLong",Ptr,a_loopfield,Int,-16)=style)
				arr[a_index]:=a_loopfield
		}
		result:=[]
		
		for k,v in arr
			if (r:=controlArr[k+shift])
				result.push(r)
		
		
		
		if(oneParam)
			return getNonEmpty?getNonEmptyControl(result):result
		else{
			ret.push(getNonEmpty?getNonEmptyControl(result):result)
		}
	}
	return ret
	
}

;getNetControl2(syngoViaState[2],"","myHostedTextbox","","WindowsForms10.EDIT","","","",0)[1]
;~ getSyngoCommonContainerWindows(){
		;~ winget,list,list,ahk_exe syngo.Common.Container.exe
		;~ arr:=[]
		;~ loop % list
			;~ arr.push(list%a_index%)
		;~ return arr
	;~ }
;~ getNetAcc(getSyngoCommonContainerWindows(),"OncologyTask_CP_Oncology@ShowHideLungCAD","Button",0,0)
getNetControl2(winHwnd,text="",controlName="",accName="",classNN="",accHelp="",accRole="",style="",shift=0, result="", getNonEmpty=false){
	if !isobject(result)
		result:=[]
	
	if isobject(winHwnd){
		
		for k,v in winHwnd
			getNetControl2(v,text,controlName,accName,classNN,accHelp,accRole,style,shift,result)
		return getNonEmpty?getNonEmptyControl(result):result
	}
	
	winget,list,controllisthwnd,ahk_id %winHwnd%
	arr:=[],controlArr:=[]
	loop,parse,list,`n 
	{
		controlArr.push(a_loopfield)
		;~ if(getControlNameByHwnd(winHwnd,a_loopfield)=controlName){
			;~ MsgBox % winGetClass(a_loopfield)
		;~ }
		if (text="" || instr(controlgettext(a_loopfield),text)) && (classNN="" || instr(winGetClass(a_loopfield),classNN)) && (controlName="" || getControlNameByHwnd(winHwnd,a_loopfield)=controlName) && (accName="" || instr((acc:=acc_objectfromwindow(a_loopfield)).accName,accName)) && (accHelp="" || instr(acc.accHelp,accHelp)) && (accRole="" || instr(acc.accRole,accRole)) && (!style || DllCall("GetWindowLong",Ptr,a_loopfield,Int,-16)=style)
			arr[a_index]:=a_loopfield
	}
	;~ result:=[]
	
	for k,v in arr
		if (r:=controlArr[k+shift])
			result.push(r)
	
	return getNonEmpty?getNonEmptyControl(result):result
}

getNonEmptyControl(ByRef arr, acc=false){
	ret:=[]
	if(!acc){
		for k,v in arr
			if ControlGetText(v)!=""
				ret.push(v)
	}else{
		for k,v in arr
			if (v.accValue!="")
				ret.push(v)
	}
	return ret.maxindex()>0?ret:[arr[1]]
}

getNetControlGlobal(text="",controlName="",accName="",classNN="",accHelp="",accRole="",style="",shift=0){
	ret:=[],win=[]
	DetectHiddenWindows,on
	winget,lst,list
	loop % lst {
		winhwnd:=lst%a_index%
		a:=getNetControl2(winHwnd,text,controlName,accName,classNN,accHelp,accRole,style,shift)
		if (a.maxindex()){
			for k,v in a
				ret.push(v)
			b:=[]
			b["" winHwnd]:=a
			win.push(b)
		}
	}
	return [ret,win]
}
	

; search for specific control
; return hwnd
getNetControl(winHwnd,controlName="",accName="",classNN="",accHelp=""){
	winget,list,controllisthwnd,ahk_id %winHwnd%
	
	bufSize=1024
	winget,processID,pid,ahk_id %winHwnd%
	VarSetCapacity(var1,bufSize)
	getName:=DllCall( "RegisterWindowMessage", "str", "WM_GETCONTROLNAME" )
	if(ErrorLevel || !getName)
		return A_LastError
	
	;~ dwResult:=DllCall("GetWindowThreadProcessId", "Ptr", winHwnd)
	;~ if(ErrorLevel || !dwResult)
		;~ return A_LastError
	
	hProcess:=DllCall("OpenProcess", "UInt", 0x8 | 0x10 | 0x20, "Uint", 0, "UInt", processID, "Ptr")
	if(ErrorLevel || !hProcess)
		return A_LastError
	
	otherMem:=DllCall("VirtualAllocEx", "Ptr", hProcess, "Ptr", 0, "PTR", bufSize, "UInt", 0x3000, "UInt", 0x0004, "Ptr")
	if(ErrorLevel || !otherMem)
		return A_LastError

	count=0
	;~ static hModule := DllCall("LoadLibrary", "Str", "oleacc", "Ptr")
	;~ static hModule2 := DllCall("LoadLibrary", "Str", "Kernel32", "Ptr")
	;~ static AccessibleObjectFromWindowProc := DllCall("GetProcAddress", Ptr, DllCall("GetModuleHandle", Str, "oleacc", "Ptr"), AStr, "AccessibleObjectFromWindow", "Ptr")
	;~ static ReadProcessMemoryProc:=DllCall("ReadProcessMemory", Ptr, DllCall("GetModuleHandle", Str, "Kernel32", "Ptr"), AStr, "AccessibleChildren", "Ptr")
	;~ msgbox % AccessibleObjectFromWindowProc
	;~ static idObject:=-4
	loop,parse,list,`n
	{
		SendMessage,%getName%,%bufSize%,%otherMem%,,ahk_id %a_loopfield%
        if !DllCall("ReadProcessMemory","Ptr",hProcess,"Ptr",otherMem,"Str",var1,"UInt",bufSize,"UInt *",0) || ErrorLevel
			continue
		
		;~ acc:=acc_objectfromwindow2(a_loopfield)
		
		;~ if !DllCall(AccessibleObjectFromWindowProc, "Ptr", a_loopfield, "UInt", idObject&=0xFFFFFFFF, "Ptr", -VarSetCapacity(IID,16)+NumPut(idObject==0xFFFFFFF0?0x46000000000000C0:0x719B3800AA000C81,NumPut(idObject==0xFFFFFFF0?0x0000000000020400:0x11CF3C3D618736E0,IID,"Int64"),"Int64"), "Ptr*", pacc)
			;~ acc:=ComObjEnwrap(9,pacc,1)
		;~ else
			;~ acc:=""
		
		
		
		
	;&&(accParentHwnd=""||acc_windowfromobject(acc.accParent)=accParentHwnd)
		if ((var1&&var1=controlName)&&(accName=""||(acc:=Acc_ObjectFromWindow(a_loopfield)).accName=accName)){
			WinGetClass,cl,ahk_id %a_loopfield%
			if(instr(cl,classNN)=1&&(accHelp=""||acc.accHelp=accHelp)) {
				ret:=a_loopfield
				break
			}
		}
		
		var1:=""
	}
	
    DllCall("VirtualFreeEx","Ptr", hProcess,"Ptr",otherMem,"UInt", 0, "UInt", 0x8000)
	,DllCall("CloseHandle","Ptr",hProcess)
	,DllCall("FreeLibrary", "Ptr", hModule)
	return ret
	
}

;~ clipboard:=getControlDescription(0x27048E,0x680532)
;~ clipboard:=getControlDescription(0x3e0784,0x380CA4)
getControlDescription(winHwnd,controlHwnd){
	return "getNetControl2(RisState[2],""" controlgettext(controlHwnd) """,""" getControlNameByHwnd(winHwnd,controlHwnd) """,""" (acc:=acc_objectfromwindow(controlHwnd)).accName """,""" winGetClass(controlHwnd) """,""" acc.accHelp """,""" acc.accRole """,""" DllCall("GetWindowLong",Ptr,controlHwnd,Int,-16) """,0)"	
}

