SetTitleMatchMode,2
SetBatchLines,-1
SetControlDelay,-1
ComObjError(false)
DetectHiddenWindows,on
DetectHiddenText,on
#Persistent
#SingleInstance,force
#NoTrayIcon
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#InstallKeybdHook
#InstallMouseHook
process,priority,,h
OnMessage(0x10101, "quit")

setRisHotkey:
RisState:=risopened()
,RisListHwnd:=getRisList(RisState[2])
,RisListAcc:=acc_ObjectFromWindow(RisListHwnd)
;~ ,HotkeyListStr:="0123456789abcdefghijklmnopqrstuvwxyz"
,HotkeyListStr:="0123456789"
gui,+ToolWindow -Caption -Border +hwndquickSearchguiHwnd
gui,Font,s14,Verdana
gui,add,Text,vquickSearchStr,% "_________"
hotkey,IfWinActive,ahk_exe Menu.exe
Loop,Parse,HotkeyListStr
    hotkey,% "~" A_LoopField,quickSearch

Loop 10
    hotkey,% "~NumPad" A_Index-1,quickSearch

 hotkey,% "~bs",quickSearch
hotkey,IfWinActive
gosub HideQuickSearch
return 

quickSearch:
if WinExist("ahk_exe searchOpHx.exe")
	return
WinGetClass,FocusedClass,% "ahk_id " focused:=getfocusedHwnd()
if (FocusedClass~="i)Edit|DateTime")
    return
WinGetTitle,focusedTitle,% "ahk_id " focused
if (focusedTitle="kReport")
	return

if searchingStatus
	return
;~ if (refresh)
	;~ ReportList:=ParseDataGrid2(controlexist(RisListHwnd)?RisListHwnd:(RisListHwnd:=getRisList(RisState[2])))
;~ refresh:=false
if !controlexist(RisListHwnd)
	RisListHwnd:=getRisList(RisState[2])
	,RisListAcc:=acc_ObjectFromWindow(RisListHwnd)
hk:=RegExReplace(A_ThisHotkey, "i)^(\W|Numpad)+", "")
if (hk="bs")
    buffer:=SubStr(buffer,1,-1)
else if StrLen(buffer)>=7
    buffer:=hk
else
    buffer.=hk
ShowQuickSearch(buffer)

return

;~ compareList(ByRef ReportList, ByRef RisListAcc, ByRef RisListHwnd, col){
	;~ rows:=acc_children(RisListAcc)
	;~ ,lastInd:=rows.maxIndex()
	;~ if (ReportList[1][col] != acc_children(rows[1])[col].accValue) 
		;~ || lastInd<2
		;~ || (ReportList[2][col] != acc_children(rows[2])[col].accValue) 
		;~ return ReportList:=ParseDataGrid2(RisListHwnd)
	
	
	;~ Loop {
		;~ v:=acc_children(rows[lastInd-A_Index+1])[col].accValue
		;~ if (v="")
			;~ continue
		;~ if (v!=ReportList[lastInd-A_Index+1][col])
			;~ return ReportList:=ParseDataGrid2(RisListHwnd)
		;~ else
			;~ break
	;~ }
	
;~ }

DoQuickSearch(){
    global RisListAcc,ReportList,RisListHwnd,RisState,quickSearchStr,searchingStatus, _loc, _row, _mm_i, Clicked, RisState, RisListAccChildren
    ;~ ToolTip % acc_children(RisListAcc).maxIndex() "," ReportList.maxIndex()
    
    ;~ if acc_children(RisListAcc).maxIndex()!=ReportList.maxIndex()+1
        ;~ ReportList:=ParseDataGrid2(RisListHwnd)
	str:=quickSearchStr
	if (str="")
		return
	
	if searchingStatus
		return
	
	searchingStatus:=true
	if !ReportList.maxIndex() 
		ReportList:=ParseDataGrid2(RisListHwnd, RisState[2], RisListAccChildren:=acc_children(RisListAcc:=acc_ObjectFromWindow(RisListHwnd)))
		, justRenewed:=true
	
    ;~ RisListAccRows:=acc_children(RisListAcc)
    for k,v in ReportList[1] {
        if (v="病歷號") {
            chartNoCol:=k
		}
		if (v="狀態")
			statusCol:=k
    }
	
	if !chartNoCol
		chartNoCol:=5
	
	if !justRenewed
		RisListAccChildren:=acc_children(RisListAcc:=acc_ObjectFromWindow(RisListHwnd))
		,compareList(ReportList, RisListAcc, RisListHwnd, "ChartNo", RisListAccChildren)
		
	
    ReportListLoc:=Acc_Location(RisListAcc)
    for k,v in ReportList
        if RegExMatch(v[chartNoCol], "i)^[yhnj]?" str ) && (Trim(v[statusCol])!="已發報告"){
			RisListAccChildren:=acc_children(RisListAcc:=acc_ObjectFromWindow(RisListHwnd))
            row:=selectRisListItem(k-1, "", "", ReportList, RisListAccChildren, RisState)
            ;~ v.accSelect(ComObj(3,3), 0)
            Sleep 50
			loc:=Acc_Location(row)
			if ((loc.y>=ReportListLoc.y && loc.y<ReportListLoc.y+ReportListLoc.h))
				MouseMove,% loc.x+500,% loc.y+Floor(loc.h/2),1
			_loc:=loc, _row:=row, _mm_i:=0, Clicked:=false
			
			SetTimer,mousemove, 100
			;~ SetTimer,debug,100
			tabs:=getNetControl2(RisState[2],"","B_ACTIVE","","WindowsForms10.BUTTON")
			if tabs[2]
				acc_objectfromwindow(tabs[2]).accDoDefaultAction()
            break
        }
		
    searchingStatus:=false
}


debug:
_loc2:=Acc_Location(_row)
ToolTip % exploreobj(_loc2)
return

#IfWinActive,ahk_exe Menu.exe
~LButton::
~RButton::
~MButton::
~WheelUp::
~WheelDown::
Clicked:=true
return
#IfWinActive

MouseMove:
	;~ if _mm_i>20
		;~ return
	if (Clicked){
		SetTimer,,Off
		return
	}
	_loc2:=Acc_Location(_row)
	if (_loc.x!=_loc2.x || _loc.y!=_loc2.y) && (_loc2.y>=ReportListLoc.y && _loc2.y<ReportListLoc.y+ReportListLoc.h){
		MouseMove,% _loc2.x+500,% _loc2.y+Floor(_loc2.h/2),1
		;~ loc:=l
	}else{
		_mm_i++
		SetTimer,MouseMove, -100
	}
return

ShowQuickSearch(str){
    global
    StringUpper,str,str
    guicontrol,,quickSearchStr,% str
    gui,show,% "noactivate center"
    winset,AlwaysOnTop,on,% "ahk_id " quickSearchGuiHwnd
    ;~ SetTimerF("DoQuickSearch", 0)
    ;~ ,SetTimerF("DoQuickSearch", -300, [str])
	quickSearchStr:=str
	settimer,DoQuickSearch,-300
    SetTimer,HideQuickSearch,-1000
}

HideQuickSearch:
gui,hide
buffer:=""
;~ ,refresh:=true
return


quit:
ExitApp
return