#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
sendmode input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
process,Priority,,R
#SingleInstance,Force
#NoTrayIcon
SetBatchLines, -1
;~ coordMode,mouse,screen
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
CoordMode,caret,client
DetectHiddenWindows,on
SetTitleMatchMode,2
SetControlDelay,-1
SendLevel,0
;~ SetFormat, float, 2.1
comobjerror(false)
;~ onexit,onexit
;~ #include <portalLib>
;~ #include <SetWindowsHookEx>
; Does not use CH_RIS — opt out of owning a local (IE-polling) CH_RIS. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <Edit>
#include <SCI>
#include <SetWindowsHookEx>
#include <resetHotstringBuffer>
#InstallKeybdHook
;~ #persistent
;~ #include <WindowShellEvent>
;~ #include <AltTab_window_list>
;~ #include <SetTimerF>
OnMessage(0x10102,"Exit")
resetHotstringBufferHook()

,hHookKeybd := SetWindowsHookEx(WH_KEYBOARD_LL	:= 13, RegisterCallback("__Keyboard", "Fast"))
;~ msgbox 
gosub RisGroup
return
RisGroup:
IniRead,actionWin,% iniPath:=A_ScriptDir "\AutoNum.ini",Hotkey,activeWin,% "notepad.exe,Menu.exe,simpleRIS.exe"
Loop,parse,actionWin,`,
{
	if InStr(A_LoopField, ".exe") && !InStr(A_LoopField, "ahk_")
		GroupAdd,RisGroup,ahk_exe %a_loopfield%
	else
		GroupAdd,RisGroup,% A_LoopField
}
;~ groupadd,RisGroup,放射線資訊管理系統(Radiology Information System)
groupadd,RisGroup,simple RIS ahk_class AutoHotkeyGUI
guihwnds:=getSimpleRisGuiHwnds("RisGroup")
return

editInfo:
focused:=GetFocused()
,Edit_GetSel(focused,selStart,selEnd)
,line:=Edit_GetCurrentLineCount(focused)+1
;~ controlget,thisLine,line,% line,,% "ahk_id " focused
,thisLine:=Edit_GetLine(focused, -1)
;~ controlget,priorLine,line,% line-1,,% "ahk_id " focused
,priorLine:=Edit_GetLine(focused, line-2)
;~ SendMessage, 0xBB, line-1, 0 ,,% "ahk_id " focused ; EM_LINEINDEX
,offset:=Edit_LineIndex(focused, line-1)
,allText:=controlgettext(focused)
,count:=0
,texts:=[substr(allText,1,selStart),substr(alltext,selStart+1,selEnd-selStart),substr(alltext,selEnd+1)]
;~ msgbox % instr(alltext,"`r")
,paragraph:=""
return

#ifwinactive,ahk_group RisGroup
~*home::
KeyWait,Home,t0.2
focused:=GetFocused()
,allText:=controlgettext(focused)
,Edit_GetSel(focused,selStart,selEnd)
if(selStart=selEnd){
	regexmatch(substr(allText,selStart+1,10),"^( *)(\W+ *|\d+\W *)",match)
	,Edit_SetSel(focused,selStart+(len:=strlen(match)),selEnd+len)
}else{
	regexmatch(substr(allText,selStart+1,selEnd-selStart),"^( *)(\W+ *|\d+\W *)",match)
	,Edit_SetSel(focused,selStart+(len:=strlen(match))>selEnd?(selEnd+len):selEnd,selStart+(len))
}

Edit_ScrollCaret(focused)
return

;~ End::
;~ HomeEnd:
;~ focused:=getFocused()
;~ WinGetClass,class,focused
;~ if(class!="Scintilla"){
	;~ send {%a_thishotkey%}
	;~ return
;~ }
;~ SetTimer,HomeEndOnScintillaReset,-500
;~ if(++HomeEndOnScintilla>1)
	;~ DllCall("SendMessage","PTR",focused,"UINT", InStr(A_ThisHotkey,"Home")?SCI_HOME:SCI_LINEEND,"PTR")
	;~ ,HomeEndOnScintilla:=0
;~ else
	;~ DllCall("SendMessage","PTR",focused,"UINT", InStr(A_ThisHotkey,"Home")?SCI_HOMEWRAP:SCI_LINEENDWRAP,"PTR")
;~ return	
;~ HomeEndOnScintillaReset:
;~ HomeEndOnScintilla:=0
;~ return


__Keyboard(nCode, wParam, lParam)
{
	global
	local ProcessName
	Critical
	
	;~ SetFormat, Integer, H
	If (wParam = 0x100)  ; WM_KEYDOWN
	{
		
		;~ ToolTip % NumGet(lParam+0,0)
		if (NumGet(lParam+0, 0)=8){
			winget,ProcessName,ProcessName,% "ahk_id " activeWin:=WinExist("A")
			if (ProcessName~="i)Menu.exe|simpleRIS.exe|Sleipnir.exe") || (WinGetTitle(activeWin)~="i)^simple RIS" && WinGetClass(activeWin)="AutoHotkeyGUI")
			{
				gosub editInfo
				if regexmatch(thisLine,"is)^(\s*)(\d+|[>=*^#@-])([^\r\n\w]*)$",match) {
					selText:=Edit_GetSelText(focused,selStart,selEnd)
					,offset_y:=selStart-offset
					if (offset_y!=strlen(match) && !regexmatch(selText,"\d+\W\s")){
						Return CallNextHookEx(nCode, wParam, lParam)
						
					}
					;~ loop % strlen(thisLine)
						;~ send {bs}
					if (selStart=selEnd){
						allText:=substr(allText,1,newSel:=(offset>=2)?offset-2:offset) substr(allText,selEnd+1)
					}else{
						allText:=substr(allText,1,newSel:=selStart) substr(allText,selEnd+1)
					}
					;~ send {bs}
					str:="",number:="",match:=""
					loop,parse,allText,`n,`r
					{
						if (trim(a_loopfield)=""){
							number:=""
							,str.=a_loopfield "`r`n"
							continue
						}
						
						regexmatch(a_loopfield,"isS)^(\s*)(\d+)([^\r\n\w]*)(.*)$",match)
						if ((match2="") || (match3="")) {
							str.=a_loopfield "`r`n"
						}else if (number=""){
								number:=match2
								,str.=a_loopfield "`r`n"
						}else {
							str.=match1 (++number) match3 match4 "`r`n"
						}
					}
					
					
					;~ controlsettext,,% RegExReplace(str,"\r?\n?$",""),ahk_id %focused%
					str:=SubStr(str,1,newSel) "_" SubStr(str, ++newSel)
					,Edit_SetText(focused, RegExReplace(str,"\r?\n?$",""))
					,Edit_SetSel(focused,newSel,newSel)
					,Edit_ScrollCaret(focused)
				}
			}
		}
		
	}
	Return CallNextHookEx(nCode, wParam, lParam)
}


$numpadenter::
$enter::
gosub editInfo
controlgetpos,,,w,h,,ahk_id %focused%
if (w<200 && h<200){
	send % "{" substr(a_thishotkey,2) "}"
	return 
}
loop,parse,alltext,`n,`r
{
	count+=strlen(a_loopfield)+2
	if (count>selstart){
		thisLine:=a_loopfield "`r`n"
		break
	}else{
		priorLine:=a_loopfield "`r`n"
	}
}
RegExMatch(thisLine,regex:="is)^(\s*)(\d+|[>=*^#@-])([^\r\n\w]*)(.*)",match)
,RegExmatch(lineText:=(offset=selStart)?((match2="" || match3="")?thisLine:priorLine):thisLine,"is)^(\s*)(\d+|[>=*^#@-])([^\r\n\w]*)(.*)",match)
,addLine:=match1 match2 match3 
;~ if (match2!="" && match4="") {
	;~ controlsend,,% "{bs " strlen(match2)+strlen(match3) "}",ahk_id %editHwnd%
	;~ controlsend,,% "{enter}" match1,ahk_id %editHwnd%
;~ }else

if(!regexmatch(match2,"\W") && match3="" || match4="") {
	;~ controlsend,,% "{enter}",ahk_id %editHwnd%
	send {enter}
	;~ controlsettext,,% texts[1] "`r`n" texts[3],% "ahk_id " focused
	;~ Edit_SetSel(focused,selStart+2,selEnd+2)
	;~ send {enter}
}else if !regexmatch(match2,"\d") {
	
	if (offset=selStart){
		;~ controlsendraw,,% match1 match2 match3,ahk_id %editHwnd%	
		;~ controlsend,,{enter},ahk_id %editHwnd%
		;~ controlsettext,,% texts[1] addLine "`r`n" texts[3],% "ahk_id " focused
		;~ Edit_SetSel(focused,selStart+2+strlen(addLine),selEnd+2+strlen(addLine))
		send %  addLine  "{enter}"
	}else{
		;~ msgbox % match3=" "
		;~ controlsend,,{enter},ahk_id %editHwnd%
		;~ controlsendraw,,% match1 match2 match3,ahk_id %editHwnd%	
		;~ controlsettext,,% texts[1] "`r`n" match1 match2 match3 texts[3] ,% "ahk_id " focused
		;~ Edit_SetSel(focused,selStart+2+strlen(addLine),selEnd+2+strlen(addLine))
		send % "{enter}" match1 match2 match3
	
	}
		;~ send % "{enter}" match1 match2 match3
}else if regexmatch(match2,"\d") {
	settimer,numbering,-50
}else{
	;~ controlsend,,{enter} ,% "ahk_id " focused
	send {Enter}
}
_resetHotstringBuffer()
sleep 100
Edit_getsel(focused,selStart,selEnd)
if RegExMatch(texts[1], "( *(?:\d+|[>=*^#@-])+? ?) *$", match)
	jumpBack:=StrLen(match1)+(InStr(allText,"`r")?2:1)
else
	jumpBack:=0

if regexmatch(startWord:=substr(text:=controlgettext(focused),selStart+1,1),"[a-z]") {
	stringupper,startWord,startWord
	;~ controlsettext,,% substr(text,1,selStart) startWord substr(text,selStart+2)
	Edit_SetText(focused, substr(text,1,selStart) startWord substr(text,selStart+2))
	,Edit_setsel(focused,selStart-jumpBack,selEnd-jumpBack)
	,Edit_ScrollCaret(focused)
}
;~ Edit_ScrollCaret(focused)
;~ Edit_ScrollCaret(focused)
return

_resetHotstringBuffer(){
	resetHotstringBuffer(-1)	
}

#ifwinactive

numbering:
match:="",parsed:="",number:=""

if (offset=selStart)
	allText:=texts[1] addLine "`r`n" texts[3]
else
	allText:=texts[1] "`r`n"  addLine texts[3]

loop,parse,allText,`n,`r
{
	if (trim(a_loopfield)=""){
		number:=""
		,parsed.=a_loopfield "`r`n"
		continue
	}
	
	RegExMatch(a_loopfield,"isS)^(\s*)(\d+)([^\r\n\w]*)(.*)$",match)
	if ((match2="") || (match3="")) {
		parsed.=a_loopfield "`r`n"
	}else if (number=""){
			number:=match2
			parsed.=a_loopfield "`r`n"
	}else {
		parsed.=match1 (++number) match3 match4 "`r`n"
	}
}
parsed:=RegExReplace(parsed,"\r?\n$","")
;~ controlsettext,,% parsed,% "ahk_id " focused
,Edit_SetText(focused, parsed)
,Edit_SetSel(focused,selStart+strlen(number match3)+2,selStart+strlen(number match3)+2)
,Edit_ScrollCaret(focused)
return


getFocused(){
	static GuiThreadInfoSize = 48
	VarSetCapacity(GuiThreadInfo, GuiThreadInfoSize)
	,NumPut(GuiThreadInfoSize, GuiThreadInfo, 0)
	,DllCall("GetGUIThreadInfo", uint, 0, str, GuiThreadInfo)
	return FocusedHWND := NumGet(GuiThreadInfo, 12)  ; Retrieve the hwndFocus field from the struct.
}


;~ esc::

~^!q::
exitapp
return


exit(){
	ExitApp
}