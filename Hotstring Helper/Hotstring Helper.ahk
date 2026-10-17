/*
scsnake@gmail.com
*/
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
SetBatchLines, -1
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
coordmode,caret,screen
SetTitleMatchMode,2
SetControlDelay,-1
SetFormat, float, 2.1
DetectHiddenWindows,on
comobjerror(false)
;~ sendlevel,1
#include <risimpax>
#include <HotstringEnhancer>
#include <HotstringScan>
#include <GetModuleFileNameExW>
#include <GetParentProcess>
;~ #include <Dynamic_Hotstring>
;~ #include <sendByClipboard>
#InstallKeybdHook
#InstallMouseHook

try
	Menu,tray,icon,% A_ScriptDir "\Hotstring Helper.ico"
monitors:=monitorInfo()
,param:=[]
loop %0%
	param.push(%a_index%)
;~ MsgBox % exploreobj(param)


;~ if !%0%
;~ {
	;~ thisPid:=DllCall("GetCurrentProcessId")
	;~ ,parentPid:=GetParentProcess(thisPid)
	;~ WinGetTitle,t,ahk_pid %parentPid%
	;~ if RegExMatch(t, "s)(.+\.ahk) - AutoHotkey", m) && FileExist(m1){
		;~ param.push(m1)
		;~ ,SetTimerF("closeWIthParent", 1000, [m])
	;~ }
;~ }
;~ MsgBox % caller "," parentPid
gui,Main:Default
gui,+hwndguiHwnd
WinSetTitle,ahk_id %guihwnd%,,HotstringHelperMain

; activeHosts: set of basenames of YCH variants currently "live" in the host
; environment. Populated by WM_COPYDATA "activate\tpath" from autorun.ahk
; (Win+N) or Lib\CH_RIS.ahk (exam-name → YCH switch). Drives search-result
; priority and the simulate-trigger fallback in chooseKey.
activeHosts:={}
OnMessage(0x4A, "HH_OnCopyData")

;~ onmessage(0x10102, "hotstringHintReset")
;~ OnMessage(0x10103, "hotstringPause")
hotstringPause:=true
;~ hotstringPause:=false
;~ ,Dynamic_Hotstring("i)\b([a-z]{3,})(\W)", "hotstringHint", 3, 0, "RIS_env_test")
groupadd,RIS,simple RIS ahk_class AutoHotkeyGUI
groupadd,RIS,Radiology Information System ahk_exe Menu.exe

gosub setHotkey
;~ msgbox % param[1]
if param.MaxIndex() {
	dic:={}
	for k,targetAhk in param {
		if (targetAhk~="i)Hotstring Helper.ahk|HotstringHint")
			continue
		;~ MsgBox % targetAhk
		;~ targetAhk:=param[param.MaxIndex()]
		parsed:=parseAhk(targetAhk)
		dic[targetAhk]:= array("" targetAhk,parsed.map,parsed.entryMap)
	}

}else{
	dic:=parseAhkFolder(a_scriptdir)
}
;~ dic:=[]
;~ dic["cwy37.ahk",1]:="cwy37.ahk"
;~ dic["cwy37.ahk",2]:=parseAhk("cwy37.ahk")
postSearch:=0

;~ MsgBox % param[1]
;~ gosub showAllHS

;acr

SetTimer,setOnTop,500
Menu,tray,Add
Menu,tray,Add,Show All,showAllHS
return

showAllHS:
allStr:=""
for k,v in dic {
	if !isobject(v.2)
		continue
	allStr.="---   " v.1 "   ---`n"
	for m,n in v.2 
		allStr.=m ": " n "`n"
}
gui,All:Default
gui,Destroy
gui,+hwndAllHwnd
gui,Font,s12,Verdana
gui,Add,button,gtooltip w0 h0,dummy
gui,Add,Edit,w1000 h700 xp+0 yp+0,% allStr
gui,Show
WinWaitClose,ahk_id %allhwnd%
gui,1:Default
return
ToolTip:
ToolTip
return

CloseWithParent(title){
	IfWinNotExist,%title%
		ExitApp
}

setHotkey:
iniPath:=A_ScriptDir "\Hotstring Helper.ini"

IniRead,actionWin,% iniPath,Hotkey,activeWin,% "notepad.exe,Menu.exe,simpleRIS.exe"
Loop,parse,actionWin,`,
{
	if InStr(A_LoopField, ".exe")
		GroupAdd,ActionWin,ahk_exe %a_loopfield%
	else
		GroupAdd,ActionWin,% A_LoopField
}
GroupAdd,ActionWin,simple RIS ahk_class AutoHotkeyGUI
Hotkey,IfWinActive,ahk_group ActionWin
Default:=[presearchChar:=";", postsearchChar:="'",  keywordSearchHotkey:="!f"]
for k,v in ["preSearch", "postSearch", "keywordSearch"] {
	tmp:=v "Hotkey"
	IniRead,%tmp%,% iniPath,Hotkey,% v,% Default[k]
	try
		Hotkey,% "~" %tmp%,% v "Sub"
	catch e {
		MsgBox % "Can't set hotkey for " v " using: " %tmp% "`nHotkey " Default[k] " will be used."
		Hotkey,% "~" Default[k],% v "Sub"
	}
		
}
Hotkey,IfWinActive
return


setOnTop:
if(showTip){
	winset,AlwaysOnTop,on,ahk_id %guihwnd%
}
return

~lbutton::
~rbutton::
~mbutton::
~up::
~down::
~left::
~right::
gosub reset2
return

;~ #ifwinactive,放射線資訊管理系統(Radiology Information System)
;~ ~;::
preSearchSub:
searchType:=1
keyBuffer:=""
result:=[]
prefixSearch:
breakLoop:=0
loop 
{
	;~ tooltip,loop
	escChars={bs}{up}{down}{left}{right}{pgup}{pgdn}{home}{end}{del}{esc}{space}!@#$```%^&*()\'
	escChars.= "``" postsearchChar
	Input,keyEnter,L1 I V *,{bs}{up}{down}{left}{right}{pgup}{pgdn}{home}{end}{del}{esc}{space}!@#$```%^&*()\'
	
	if(breakLoop){
		breakLoop:=0
		break
	}
	

	if regexmatch(Errorlevel,"EndKey:([^\n]+)",endKey) {
		if (searchType=2 && EndKey1=postsearchChar){
			sendByClipboard(keyBuffer postsearchChar, 1, 0)
			,resetHotstringBuffer(-1)
			gosub reset2
			return
		}else if (endKey1="BackSpace") {
			
			keyBuffer:=(len:=strlen(keyBuffer))>1?substr(keyBuffer,1,len-1):""
			;~ traytip,,% keyBuffer
			
			if(searchType=2 || searchType=3){
				gosub reset2
				return
			}else if (searchType=1 && strlen(keyBuffer)=0){
				gosub reset2
				exit
				return
			}
			
			if (strlen(keyBuffer)>2 ) {
				settimer,matchkey,off
				settimer,matchkey,-300
			}else{
				gosub reset1
				breakLoop:=0
			}
		}else if (endKey1="Space") && strlen(keyBuffer)>=3 {
			settimer,matchkey,off
			gosub matchkey
			keyEnter:=1
			gosub chooseKey
			gosub reset2
			send {space}
			return
		}else if (keyEnter:=RegExMatch("[\!\@\#\$\%\^\&\*\(\)]$",EndKey1)) {
			shiftPress:=1
			gosub chooseKey
			gosub reset2
			return
		}else{
			gosub reset2
			return
		}
	} Else If StrLen(ErrorLevel) > 3 {  ; NewInput, EndKey
		gosub reset1
		return
	} else if regexmatch(keyEnter,"\d$") {
		shiftPress:=0
		gosub chooseKey
		gosub reset2
		return
	} Else If !regexmatch(keyEnter,"[\w\*\?]") {   ; Sentence end
		gosub reset2
		return
	}Else {
		keyBuffer.=keyEnter
		if (strlen(keyBuffer)>2 ) {
			settimer,matchkey,off
			settimer,matchkey,-300
		}else{
			gosub reset1
			breakLoop:=0
		}
		;~ settimer,showKey,off
		;~ settimer,showKey,1000
	}
	
	
}
return
;acr
reset2:
keyBuffer:=""
reset1:
gosub destroyGUI
showTip:=0
settimer,matchkey,off
breakLoop:=1
return


destroyGUI:
gui,destroy
return

matchKey:
result:=[],keyMatchPattern:=""
StringReplace,keyMatchPattern,keyBuffer,?,[^\n],A
StringReplace,keyMatchPattern,keyMatchPattern,*,[^\n]*,A
searchKey:
resultsDic:={}
; Two-pass iteration: active-host files first so their triggers head the
; result list (and de-duped by resultsDic, so an active-host trigger wins
; over the same trigger from a non-active file).
for k,v in dic
	if HH_IsActiveHost(k)
		HH_SearchOne(v, result, resultsDic, keyMatchPattern)
for k,v in dic
	if !HH_IsActiveHost(k)
		HH_SearchOne(v, result, resultsDic, keyMatchPattern)
showKeyPage:=1
gosub showkey
return
;acr

;
;
;acr;acr;acr


;rento
chooseKey:
if !isobject(result) || result.maxIndex()<1
	return
if !WinExist("[Hotstring Helper] ahk_class AutoHotkeyGUI")
	return
chosenIdx:=10*(showKeyPage-1)+(keyEnter?keyEnter:10)
chosenRow:=result[chosenIdx]
if !IsObject(chosenRow)
	return
chosenEntry:=chosenRow[4]
choosenKey:=chosenRow[3]
gosub destroyGUI
WinWaitNotActive,[Hotstring Helper] ahk_class AutoHotkeyGUI,,1

if searchType=1
	bsCount:=strlen(keyBuffer)+2
else if searchType=2
	bsCount:=1
else if searchType=3
	bsCount:=1

if IsObject(chosenEntry) {
	kind:=chosenEntry.sendKind
	if (kind="auto" || kind="clip" || kind="sendLit") {
		payload:=shiftPress?StringUpperFirst(chosenEntry.payload):chosenEntry.payload
		sendByClipboard(payload, bsCount, 0)
		,resetHotstringBuffer(-1)
	} else if HH_IsActiveHost(chosenEntry.sourcePath) {
		; complex / sendExpr with active host: let the host's hotstring
		; engine fire the body by typing trigger+endchar at SendLevel 1.
		HH_SimulateTrigger(chosenEntry, bsCount)
	} else {
		; complex / sendExpr without active host: preview-only.
		HH_ShowToolTip("Preview only - no active host script for """ chosenEntry.trigger """", 1500)
	}
} else {
	sendByClipboard(shiftPress?StringUpperFirst(choosenKey):choosenKey, bsCount, 0)
	,resetHotstringBuffer(-1)
}
postSearch:=0
gosub reset2
return

showKey:
showKeyString:="[Hotstring Helper]`n`n"
shownKey:=[]
if result.maxIndex()<1
	showKeyString.="No matched."
else {
	loop 10 {
		if (i:=10*(showKeyPage-1)+a_index)>result.maxIndex()
			break
		if (i=1 || result[i,1]<>result[i-1,1])
			showKeyString.="---   " result[i,1] "   ---`n`n"
			,shownKey.push("---   " result[i,1] "   ---")
		
		showKeyString.= (strlen(a_index)=1?a_index:0) ") " filterLongText(result[i,2]) ": " filterLongText(result[i,3]) "`n`n"
		,shownKey.push("[" (strlen(a_index)=1?a_index:0) "] " filterLongText(result[i,2]) ": " filterLongText(result[i,3]))
	}
	
	showKeyString.="                Page " showKeyPage "/" (maxPage:=floor(result.MaxIndex()/10)+1)
	,shownKey["paging"]:="                Page " showKeyPage "/" (maxPage:=floor(result.MaxIndex()/10)+1)
}
;~ tooltip,% showKeyString,% a_caretx,% a_carety+30
;acr
createGUI(shownKey)
showTip:=1
return

createGUI(shownKey){
	global
	gosub destroyGUI
	gui,+toolwindow -caption +alwaysontop +hwndguiHwnd +0x800000
	gui,color,white
	gui,font,s10 cblack,Verdana
	gui,add,text,w1000,% "[Hotstring Helper]"
	for k,v in shownKey {
		if (k!="paging") {
			if instr(v,"---  ")=1
				gui,add,text,w1000 y+10,% v
			else
				gui,add,text,w1000 y+6,% v
		}
	}
	if shownKey.hasKey("paging")
		gui,add,text,w500 y+10,% shownKey["paging"]
	else
		gui,add,text,w500 y+10,% "No matched."
	
	if(!a_caretx || !a_carety){
		wingetpos,wx,wy,,,A
	}else{
		;~ mousegetpos,mx,my
		;~ whichMonitor:=whichMonitor(mx,my,monitors)[1]
		wx:=a_caretx,wy:=A_CaretY
		;~ loop % whichMonitor-1 {
			;~ wx+=monitors[a_index,"w"]
		;~ }
	}
	
	
	gui,show,% "autosize noactivate x" wx " y" (wy+30),[Hotstring Helper]
	DllCall("SetWindowPos", "Ptr", guihwnd, "Ptr", 0, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
	,DllCall("SetWindowPos", "Ptr", guihwnd, "Ptr", -1, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)

	
	WinSet, Transparent,240, ahk_id %guiHwnd%
	settimer,adjustGUI,-1
}
;acr;acr;acr ;acr;acr;acr;acr;acr;acr;acr;acr
;acr;acr;acr
;acr;acr;acr

adjustGUI:
wingetpos,wx,wy,ww,wh,ahk_id %guiHwnd%
whichMonitor:=monitors[whichMonitor(wx,wy,monitors)[1]]
if (wx+ww>whichMonitor.r)
	if (wx:=whichMonitor.r-ww)<whichMonitor.l
		wx:=whichMonitor.l
if (wy+wh>whichMonitor.b)
	if (wy:=whichMonitor.b-wh)<whichMonitor.t
		wy:=whichMonitor.t
winmove,ahk_id %guiHwnd%,,% wx,% wy
return

;~ !f::
keywordSearchSub:
searchType:=3
keywait,alt,t1
keywait,f,t1
sleep 100
prevClip:=clipboardall
clipboard:=
send ^c
clipwait,0.5
keyBuffer:=(regexmatch(clipboard,"\w+")?trim(clipboard):trim(prevClip))
result:=[]
StringReplace,keyMatchPattern,keyBuffer,?,[^\n],A
StringReplace,keyMatchPattern,keyMatchPattern,*,[^\n]*,A
settimer,matchKey,off
gosub searchKey
gosub prefixSearch

return

;~ ~\::
postSearchSub:
;~ if !(winactive("simple RIS ahk_class AutoHotkeyGUI") || winactive("放射線資訊管理系統") || (A_YYYY a_mm a_dd = "20170319")  || (A_YYYY a_mm a_dd = "20170318")){
	;~ send {\}
	;~ return
;~ }
if winvisible(guiHwnd){
	return
}
Input,postSearchKeyEnter,T0.5 L1 I V *,abcdefghijklmnopqrstuvwxyz
if (ErrorLevel!="Timeout")
	return
searchType:=2
,prevClip:=clipboardall
;~ Sleep 1000
send ^+{left}
if(getFocused("Class")="Scintilla")
	send ^+{Left}
;~ if winactive("ahk_class SleipnirMainWindow") || winactive("ahk_class SciTEWindow")
	;~ send ^+{left}  ;additional selection

clipboard=
send ^c
clipwait,0.5
keyBuffer:=RegExReplace(clipboard,"(^;)|(\" postsearchChar "$)","")
;~ clipboard:=prevClip
if (keyBuffer=""){
	send ^+{Left}
	clipboard=
	send ^c
	clipwait,0.5
	keyBuffer:=RegExReplace(clipboard,"(^;)|(\" postsearchChar "$)","")
	if (keyBuffer="")
		return
}
result:=[]
StringReplace,keyMatchPattern,keyBuffer,?,[^\n],A
StringReplace,keyMatchPattern,keyMatchPattern,*,[^\n]*,A
settimer,matchKey,off
postSearch:=1
gosub searchKey
gosub prefixSearch

return
#IfWinActive
;acr2
;acr
;~ #ifwinactive

filterLongText(str,maxLine=5,indentation="    "){
	ret:=""
	loop,parse,str,`n
	{
		if a_index=6
			return regexreplace(ret,"\n$") " ...... "
		else if a_index=1
			ret.=A_LoopField "`n"
		else 
			ret.=indentation A_LoopField "`n"
	}
	until a_index=6
	return regexreplace(ret,"\n$")
}
;acr;acr

#ifwinexist,[Hotstring Helper] ahk_class AutoHotkeyGUI
~esc::
if (searchType=3)
	return
wingettext,winText,[Hotstring Helper] ahk_class AutoHotkeyGUI
if !instr(winText,"[Hotstring Helper]")
	return
gosub destroyGUI
WinWaitNotActive,winText,[Hotstring Helper] ahk_class AutoHotkeyGUI,,1
keywait,esc,t1
prevClip:=clipboardall
if (postSearch!=1) {
	send ^+{left}
	if(getFocused("Class")="Scintilla")
		send ^+{Left}
	clipboard=
	send ^x
	clipwait,0.5
	if(clipboard=""){
		send ^+{Left}
		clipboard=
		send ^x
		ClipWait,0.5
	}
		
}
clipboard:=RegExReplace(RegExReplace(clipboard,"^;",""),"\\$","")
sleep 100
send {esc}^v
sleep  100
clipboard:=prevClip
gosub reset2
return
;acracromion
pgdn::
wheeldown::
;~ hwnd:=winexist("","[Hotstring Helper]")
;~ wingetclass,class,ahk_id %hwnd%
;~ msgbox % class
wingettext,winText,[Hotstring Helper] ahk_class AutoHotkeyGUI
if !instr(winText,"[Hotstring Helper]")
	return
if !showTip
	return
if (++showKeyPage)>maxPage
	--showKeyPage
else
	settimer,showKey,-1
return

pgup::
wheelup::
wingettext,winText,[Hotstring Helper] ahk_class AutoHotkeyGUI
if !instr(winText,"[Hotstring Helper]")
	return
if !showTip
	return
if (--showKeyPage)<1
	++showKeyPage
else
	settimer,showKey,-1
return
;acr
~lbutton::
mousegetpos,,,mWin,mControl
controlgettext,clickedChoice,% mControl,ahk_id %mWIn%
if (mWin=winexist("[Hotstring Helper] ahk_class AutoHotkeyGUI")) {
	if (clickedChoice!=""){
		keyEnter:=substr(clickedChoice,2,1)
		gosub destroyGUI
		gosub chooseKey
	}
}else{
	gosub destroyGUI
	gosub reset2
}
return
;acr
#ifwinexist
;acracroacromion 
~^!q::
;~ ~esc::
exitapp
return

;acr
 ;;acr

parseAhk(path){
	; Returns {map:{trig->displayBody}, entryMap:{trig->entry}}.
	; map is consumed by matchKey's regex passes (legacy v.2 slot);
	; entryMap is consumed by chooseKey to branch on sendKind / isHost.
	entries:=HS_Scan(path)
	return { map: HS_BuildMap(entries), entryMap: HS_BuildEntryMap(entries) }
}

;~ parseAhk(path){
	;~ arr:=[],hotstring:="",str:=""
	;~ fullScript:=JoinScript(path)
	
	;~ loop,parse,fullscript,`n,`r
	;~ {
		;~ if RegExMatch(a_loopfield,"is)^:[^:]*?:(.+):[^:]?:([^\n\r]*)$",match) {
			;~ if (Trim(match2)!="") 
				;~ arr["" match1]:=match2
			;~ else 
				;~ hotstring:=match1
			
			;~ continue
		;~ }
		
		;~ if (hotstring!="") {
			;~ if(a_loopfield=")" || trim(a_loopfield)="return") {
				;~ arr["" hotstring]:=str
				;~ ,hotstring:="",str:=""
			;~ }else if (a_loopfield!="(") {
				;~ str.=a_loopfield "`n"
			;~ }
			
		;~ }
	;~ }
	;~ return arr
	
;~ }




parseAhkFolder(folder,recurse=0){
	arr:=[]

	if isobject(folder){
		for k,v in folder {
			parsed:=parseAhk(v)
			arr["" v]:=[RegExReplace(v,"is)^.+(\/|\\)",""),parsed.map,parsed.entryMap]
		}
	}else{
		loop,%folder%\*.ahk,0,% recurse
		{
			if !(A_LoopFileName~="i)Hotstring Helper.ahk|HotstringHint") {
				parsed:=parseAhk(A_LoopFileLongPath)
				arr["" A_LoopFileLongPath]:=array("" A_LoopFileName,parsed.map,parsed.entryMap)
			}
		}
	}
	return arr
}
getFocused(info="id"){
	static GuiThreadInfoSize = 48
	VarSetCapacity(GuiThreadInfo, GuiThreadInfoSize)
	,NumPut(GuiThreadInfoSize, GuiThreadInfo, 0)
	,DllCall("GetGUIThreadInfo", uint, 0, str, GuiThreadInfo)
	,FocusedHWND := NumGet(GuiThreadInfo, 12)  ; Retrieve the hwndFocus field from the struct.
	if(info="class"){
		WinGetClass,class,ahk_id %focusedHWND%
		return class
	}else{
		return FocusedHwnd
	}
}




hotstringPause(){
	global 
	hotstringPause:=true
	settimer,hotstringPauseReset,-10000
}



hotstringPauseReset:
hotstringPause:=false
return

; ============================================================================
; Persistent + reactive YCH switching
;
; HH is launched once and stays resident. autorun.ahk (Win+N) and
; Lib\CH_RIS.ahk (exam-name → YCH switch) send WM_COPYDATA to the
; "HotstringHelperMain" hidden window saying which YCH variant is now live.
; HH updates `activeHosts`, lazy-parses the file if it hasn't been seen yet,
; and the search ranking + simulate-trigger fallback adjust on the fly.
; ============================================================================

HH_IsActiveHost(path) {
	global activeHosts
	if !IsObject(activeHosts) || !activeHosts.Count()
		return false
	if activeHosts.HasKey(path)
		return true
	SplitPath, path, fname
	StringLower, fname, fname
	return activeHosts.HasKey(fname)
}

HH_SearchOne(v, ByRef result, ByRef resultsDic, keyMatchPattern) {
	if !IsObject(v) || !IsObject(v.2)
		return
	em := IsObject(v.3) ? v.3 : {}
	; Exact + prefix-word + word-boundary
	for m,n in v.2 {
		if (Trim(n)=Trim(keyMatchPattern)) && !resultsDic.HasKey(m) {
			result.Push(array(v.1,m,n,em[m])), resultsDic[m]:=1
		}
		if (Trim(n)~="i)" Trim(keyMatchPattern) "\w*") && !resultsDic.HasKey(m) {
			result.Push(array(v.1,m,n,em[m])), resultsDic[m]:=1
		}
		if regexmatch(n,"i)\b" keyMatchPattern "\b") && !resultsDic.HasKey(m) {
			result.Push(array(v.1,m,n,em[m])), resultsDic[m]:=1
		}
	}
	for m,n in v.2 {
		if regexmatch(n,"i)\b" keyMatchPattern "\B") && !resultsDic.HasKey(m) {
			result.Push(array(v.1,m,n,em[m])), resultsDic[m]:=1
		}
	}
	for m,n in v.2 {
		if regexmatch(n,"i)\B" keyMatchPattern "\b") && !resultsDic.HasKey(m) {
			result.Push(array(v.1,m,n,em[m])), resultsDic[m]:=1
		}
	}
	for m,n in v.2 {
		if regexmatch(n,"i)\B" keyMatchPattern "\B") && !resultsDic.HasKey(m) {
			result.Push(array(v.1,m,n,em[m])), resultsDic[m]:=1
		}
	}
}

; SendLevel 1 is required so the host script's hotstring engine (default
; #InputLevel 0) doesn't filter out our synthetic keystrokes. `{Text}` would
; NOT trigger hotstrings, so we escape modifier chars and use plain SendInput.
; B0 (no-backspace) hotstrings are skipped: the host wouldn't auto-erase the
; trigger, leaving it visible in the document.
HH_SimulateTrigger(entry, bsCount := 0) {
	if !IsObject(entry) || entry.opts.noBS
		return false
	if (bsCount > 0)
		SendInput % "{BS " bsCount "}"
	prevLevel := A_SendLevel
	SendLevel 1
	SendInput % HH_EscapeForSend(entry.trigger)
	if (!entry.opts.star && entry.endChar != "")
		SendInput % HH_EscapeForSend(entry.endChar)
	SendLevel %prevLevel%
	resetHotstringBuffer(-1)
	return true
}

HH_EscapeForSend(s) {
	s := StrReplace(s, "{", "{{}")
	s := StrReplace(s, "}", "{}}")
	s := StrReplace(s, "!", "{!}")
	s := StrReplace(s, "^", "{^}")
	s := StrReplace(s, "+", "{+}")
	s := StrReplace(s, "#", "{#}")
	return s
}

HH_OnCopyData(wParam, lParam, msg, hwnd) {
	global dic, activeHosts
	cbData := NumGet(lParam + A_PtrSize, 0, "UInt")
	lpData := NumGet(lParam + 2*A_PtrSize, 0, "Ptr")
	payload := StrGet(lpData, cbData // (A_IsUnicode ? 2 : 1))
	if !RegExMatch(payload, "^activate\t(.+?)\s*$", m)
		return
	path := m1
	SplitPath, path, fname
	StringLower, fname, fname
	; Resolve which dic key (if any) this announce refers to.
	hitKey := ""
	if dic.HasKey(path) {
		hitKey := path
	} else {
		for k in dic {
			SplitPath, k, kn
			if (kn = fname) {
				hitKey := k
				break
			}
		}
	}
	; Lazy parse if not seen yet, or re-parse if file changed on disk.
	if (hitKey = "") {
		if FileExist(path) {
			parsed := parseAhk(path)
			dic[path] := array(fname, parsed.map, parsed.entryMap)
			hitKey := path
		}
	} else {
		FileGetTime, mt, %hitKey%, M
		stored := activeHosts.HasKey(fname) ? activeHosts[fname] : ""
		if (mt != "" && stored != "" && mt != stored && FileExist(hitKey)) {
			parsed := parseAhk(hitKey)
			dic[hitKey] := array(dic[hitKey][1], parsed.map, parsed.entryMap)
		}
	}
	; Last-wins: replace the active set with this one.
	activeHosts := {}
	if (hitKey != "") {
		FileGetTime, mt, %hitKey%, M
		activeHosts[fname] := mt ? mt : 1
	}
}

HH_ShowToolTip(text, ms := 1500) {
	ToolTip, %text%
	SetTimer, HH_ClearToolTip, % -Abs(ms)
}

HH_ClearToolTip:
ToolTip
return