/*
scsnake@gmail.com
*/

#persistent
#NoEnv
#SingleInstance,force
SetBatchLines,-1
process,Priority,,R
;~ DetectHiddenWindows, On
SetTitleMatchMode,2
coordmode,mouse,screen
CoordMode,caret,screen
#NoTrayIcon
;~ #include <acc>
;~ #include <.netgetcontrol>
; Talk to the single CH_RIS owner (autorun) over IPC instead of a local owner. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <risimpax>
;~ #include <portallib>
;~ #include <hotstring>
;~ #include <SystemCursor>
#include <Edit>
#include <EditFunctions>
#include <getFocusedHwnd>
#include <resetHotstringBuffer>
sendmode input
#InstallKeybdHook
#InstallMouseHook
sendlevel,2
#inputlevel,2
resetHotstringBufferHook()
OnMessage(0x10102,"Exit")
/*

control: operate by word
alt: operate by sentence
shift: selection
win: operate by paragraph

*/
ini:=a_scriptdir "\textHotkey.ini"

gosub RisGroup
hotkey,ifwinactive,ahk_group RisGroup
;~ hotkey,ifwinactive,放射線資訊管理系統(Radiology Information System)

iniread,ctrl,% ini,Hotkey,ctrl,^
iniread,alt,% ini,Hotkey,alt,!
iniread,shift,% ini,Hotkey,shift,+
iniread,win,% ini,Hotkey,win,#
iniread,tab,% ini,Hotkey,tab,tab
iniread,selectLeft,% ini,Hotkey,selectLeft,[
iniread,selectRight,% ini,Hotkey,selectRight,]
iniread,shiftUp,% ini,Hotkey,shiftUp,!up
iniread,shiftDown,% ini,Hotkey,shiftDown,!down
;~ iniread,tab,% ini,Hotkey,tab,tab
iniread,deleteWord,% ini,Hotkey,deleteWord,``
iniread,jumpPriorLineEnd,% ini,Hotkey,jumpPriorLineEnd,pgup
iniread,jumpNextLineEnd,% ini,Hotkey,jumpNextLineEnd,pgdn



;~ iniread,indent,% ini,Hotkey,indent,% "  "
indent:="  "
;~ ctrl:="^"
;~ ,alt:="!"
;~ ,shift:="+"
;~ ,win:="#"

;~ try {
;for scintilla
;~ Hotkey,Home,HomeEnd	
;~ Hotkey,End,HomeEnd	
	
	
hotkey,%tab%,tab
hotkey,+%tab%,Shifttab

hotkey,%shiftUp%,shiftLine
hotkey,%shiftDown%,shiftLine

hotkey,%ctrl%left,hotkey
hotkey,%alt%left,hotkey
hotkey,%win%left,hotkey
hotkey,%ctrl%right,hotkey
hotkey,%alt%right,hotkey
hotkey,%win%right,hotkey

hotkey,%shift%%ctrl%left,hotkey
hotkey,%shift%%alt%left,hotkey
hotkey,%shift%%win%left,hotkey
hotkey,%shift%%ctrl%right,hotkey
hotkey,%shift%%alt%right,hotkey
hotkey,%shift%%win%right,hotkey


hotkey,%ctrl%bs,hotkey
hotkey,%alt%bs,hotkey
hotkey,%win%bs,hotkey
hotkey,%ctrl%del,hotkey
hotkey,%alt%del,hotkey
hotkey,%win%del,hotkey


hotkey,%deleteWord%,deleteWord

;for triple click
hotkey,~lbutton,click
clickCount:=0


hotkey,%selectLeft%,select
hotkey,%alt%%selectLeft%,select
hotkey,%win%%selectLeft%,select
hotkey,%selectRight%,select
hotkey,%alt%%selectRight%,select
hotkey,%win%%selectRight%,select
hotkey,%ctrl%%selectLeft%,bracket
hotkey,%ctrl%%selectRight%,bracket


hotkey,%jumpPriorLineEnd%,jumpPriorLineEnd
hotkey,%jumpNextLineEnd%,jumpNextLineEnd
hotkey,%jumpPriorLineEnd% up,prime
hotkey,%jumpNextLineEnd% up,prime

Hotkey,IfWinNotActive,webcvis
hotkey,%alt%1,jumpToLine
Hotkey,IfWinNotActive
hotkey,%alt%2,jumpToLine
hotkey,%alt%3,jumpToLine
hotkey,%alt%4,jumpToLine
hotkey,%alt%5,jumpToLine
hotkey,%alt%6,jumpToLine
hotkey,%alt%7,jumpToLine
hotkey,%alt%8,jumpToLine
hotkey,%alt%9,jumpToLine
hotkey,%alt%0,jumpToLine
hotkey,%alt%numpad1,jumpToLine
hotkey,%alt%numpad2,jumpToLine
hotkey,%alt%numpad3,jumpToLine
hotkey,%alt%numpad4,jumpToLine
hotkey,%alt%numpad5,jumpToLine
hotkey,%alt%numpad6,jumpToLine
hotkey,%alt%numpad7,jumpToLine
hotkey,%alt%numpad8,jumpToLine
hotkey,%alt%numpad9,jumpToLine
hotkey,%alt%numpad0,jumpToLine

Hotkey,~RButton,selectToEnd
Hotkey,~LButton,selectToStart

;~ }
Hotkey,IfWinActive
Loop, 4
{
	Gui, %A_Index%: -Caption +ToolWindow +AlwaysOnTOp
	Gui, %A_Index%: Color, white
}

return


TextHotkey(ByRef Text, args){
	/*
	cursorStart, cursorEnd
	unit=alphabet, word, subsentence, sentence, list, paragraph
	action=jump, select, delete
	repeat=0, 1, 2, ...
	direction=1 (foreward), 0 (backward)
	greedy=true, false
	*/
	
	static specialChar:="``~!@#$%^&\*\(\)\+\-=\[\]{};:'""<>,\.\/\\\?，。；：！？\s"
	, alphabet:="[^" specialChar "]|(?:(?:[\da-zA-Z]+-)+[\da-zA-Z]+)|(?:(?:\d+\.)+\d+)"
	, word:= "(?:" alphabet ")+"
	, subsentence_end:= "(?:" word " +)*" word " *[:：\?!\.。！？]"
	, subsentence_not_end:= "(?:" word " +)*" word " *[;,；，:：]"
	;~ , subsentence_non_end:="(?:" word " +)*" word " *(?:[:：] *)?(?=[\n\r])"
	, subsentence_non_end:=subsentence_not_end " *(?=[\n\r])"
	, subsentence:="(?:" word " +)*" word " *[\?!\.。！？;,；，]"
	, sentence:= "(?:(?:" subsentence_not_end ") *)*(?:" subsentence_end "|" subsentence_non_end ")"
	, bullet:="(?:\n[ \t]*|^)(?:\(\d+\)|\[\d+\]|\{\d+\}|\d+[" SubStr(specialChar,1,-2) "]|([" SubStr(specialChar,1,-2) "])\1*) *"
	, list:=bullet "(?:" sentence " *)*" sentence
	
	
	
	
	for k,v in args
		%k%:=v
	
	if cursorStart=
		cursorStart:=args.cursorStart:=0
	if cursorEnd=
		cursorEnd:=args.cursorEnd:=cursorStart
	if unit=
		unit:=args.unit:="word"
	if action=
		action:=args.action:="jump"
	if repeat=
		repeat:=args.repeat:=0
	if direction=
		direction:=args.direction:=cursorStart<=cursorEnd?1:0
	if greedy=
		greedy:=args.greedy:=true
	
	if (repeat=0)
		return [cursorStart, cursorEnd]
	
	if(unit="alphabet" || unit="word"){
		;~ while RegExMatch(SubStr(text, cursorEnd))
		if(direction){
			if (loc:=RegExMatch(SubStr(text, cursorEnd), "S)" %unit%, match)){
				--args.repeat
				, args.cursorEnd:=loc+StrLen(match)
				return TextHotkey(text, args)
			}else
				return [cursorStart, cursorEnd]
		}
	}
	
}


RisGroup:
IniRead,actionWin,% ini:=A_ScriptDir "\textHotkey.ini",Hotkey,activeWin,% "notepad.exe,Menu.exe,simpleRIS.exe"
Loop,parse,actionWin,`,
{
	if InStr(A_LoopField, ".exe")
		GroupAdd,RisGroup,ahk_exe %a_loopfield%
	else
		GroupAdd,RisGroup,% A_LoopField
}
;~ groupadd,RisGroup,放射線資訊管理系統(Radiology Information System)
groupadd,RisGroup,simple RIS ahk_class AutoHotkeyGUI
guihwnds:=getSimpleRisGuiHwnds("RisGroup")

return

prime:
send {%a_thishotkey%}
return

jumpToLine:
num:=substr(a_thishotkey,2,1)+0
if (num=0)
	num:=10
focused:=getFocusedHwnd()
if (text:=controlgettext(focused))=""
	return
count:=found:=0,str:=""
loop,parse,text,`n
{
	str.=a_loopfield "`n"
	if regexmatch(a_loopfield,"^(\d+\W|\W )") && (++count = num)  {
		found:=1
		break
	}
}
if(found){
	str:=RegExReplace(str,"\r?\n$","")
	,Edit_SetSel(focused,len:=strlen(str),len)
	,Edit_ScrollCaret(focused)
	,_resetHotstringBuffer() 
}
return


_resetHotstringBuffer(){
	resetHotstringBuffer(-1)	
}


editInfo:
focused:=getFocusedHwnd()
,Edit_GetSel(focused,selStart,selEnd)
,line:=Edit_GetCurrentLineCount(focused)+1
;~ controlget,thisLine,line,% line,,% "ahk_id " focused
;~ thisLine:=Edit_GetLine(focused, -1)
;~ controlget,priorLine,line,% line-1,,% "ahk_id " focused
;~ priorLine:=Edit_GetLine(focused, line-2)
;~ SendMessage, 0xBB, line-1, 0 ,,% "ahk_id " focused ; EM_LINEINDEX
;~ offset:=Edit_LineIndex(focused, line-1)
return

jumpPriorLineEnd:
gosub editInfo
offset:=Edit_LineIndex(focused, line-2)
,priorLine:=Edit_GetLine(focused, line-2)
if line=1
	return 
Edit_SetSel(focused, sel:=Offset+StrLen(RegExReplace(priorLine,"[\r\n]","")), sel)
,Edit_ScrollCaret(focused)
,_resetHotstringBuffer() 
return 
;~ focused:=getFocusedHwnd()
;~ if (text:=controlgettext(focused))=""
	;~ return
;~ Edit_GetSel(focused,selStart,selEnd)
;~ count:=0
;~ loop,parse,text,`n
;~ {
	;~ len:=strlen(a_loopfield)
	;~ if (count+len>=selStart)
		;~ break
	;~ count+=len+1
;~ }
;~ Edit_SetSel(focused,sel:=regexmatch(substr(text,count,1),"\r")?count-2:count-1,sel)
;~ Edit_ScrollCaret(focused)
;~ return
jumpNextLineEnd:
gosub editInfo
if !(offset:=Edit_LineIndex(focused, line))
	return 
nextLine:=Edit_GetLine(focused, line)
,sel:=Offset+StrLen(RegExReplace(nextLine,"[\r\n]",""))
if (selStart=sel)
	return 
Edit_SetSel(focused, sel, sel)
,Edit_ScrollCaret(focused)
,_resetHotstringBuffer() 
return 
;~ focused:=getFocusedHwnd()
;~ if (text:=controlgettext(focused))=""
	;~ return
;~ Edit_GetSel(focused,selStart,selEnd)
;~ count:=0,next:=0
;~ loop,parse,text,`n
;~ {
	;~ len:=strlen(a_loopfield)
	;~ if (count+len>=selStart)
		;~ ++next
	;~ count+=len+1
	;~ if next>1
		;~ break
;~ }
;~ Edit_SetSel(focused,sel:=(sel:=regexmatch(substr(text,count,1),"\r")?count-2:count-1)>(len:=strlen(text))?len:sel,sel)
;~ Edit_ScrollCaret(focused)
;~ return

deleteWord:
deleteWord2()
;~ send ^+{left}{bs}
;~ focused:=getFocusedHwnd()
;~ DllCall("SendMessage","PTR",focused,"UINT", SCI_DELWORDLEFT,"PTR")
return

tab:
id:=getFocusedHwnd()
if (text:=controlgettext(id))=""
	goto normalTab
Edit_GetSel(id,s,e)
if(regexreplace(substr(text,s+1),"[\t\s\n\r]","")="")
	goto normalTab

strlen:=strlen(text)

if(s=e) && !regexmatch(substr(text,1,s),"\r?\n *(\d+[\)\.] ?|[>=*^#@-] )$") {
	loop {
		if regexmatch(substr(text,s+1,1),"[\)\]\}]")
			++s
		else
			break
	}until s>strlen
	if (s=e)
		goto normalTab
	else
		Edit_SetSel(id,s,s)
}else{
	parsed:=[],i:=0,lineS:=lineE:=-1
	loop,parse,text,`n,`r
	{
		parsed.push(a_loopfield)
		if (i:=i+strlen(a_loopfield)+2)>s && lineS<0
			lineS:=a_index
		if (i>=e) && lineE<0
			lineE:=a_index
	}
	if (lineE<lineS)
		lineE:=lineS
	text:=""
	loop % lineS-1
		text.=parsed[a_index] "`r`n"
	loop % lineE-lineS+1
		text.=indent (additional:=instr(parsedTemp:=parsed[a_index-1+lineS],"- ")=1?"-":"") parsedTemp "`r`n"
	loop % parsed.maxindex()-lineE
		text.=parsed[a_index+lineE] "`r`n"
	text:=RegExReplace(text,"\r\n$","")
	;~ controlsettext,,% text,ahk_id %id%
	Edit_SetText(id, Text)
	,Edit_SetSel(id,s+strlen(indent additional),e+(lineE-lineS+1)*strlen(indent additional))
	,_resetHotstringBuffer() 
}
return

shiftTab:
id:=getFocusedHwnd()
if (text:=controlgettext(id))=""
	goto normalTab
Edit_GetSel(id,s,e)
if(regexreplace(substr(text,s),"[\t\s\n\r]","")="")
	goto normalTab
strlen:=strlen(text)

if(s=e) && !regexmatch(substr(text,1,s),"\r?\n *(\d+[\)\.] ?|[>=*^#@-] )$") {
	loop {
		if regexmatch(substr(text,s,1),"[\(\[\{]")
			--s
		else
			break
	}until s<=0
	if (s=e)
		goto normalTab
	else
		Edit_SetSel(id,s,s)
}else{
	parsed:=[],i:=0,lineS:=lineE:=-1
	loop,parse,text,`n,`r
	{
		parsed.push(a_loopfield)
		if (i:=i+strlen(a_loopfield)+2)>s && lineS<0
			lineS:=a_index
		if (i>=e) && lineE<0
			lineE:=a_index
	}
	if (lineE<lineS)
		lineE:=lineS
	text:=""
	loop % lineS-1
		text.=parsed[a_index] "`r`n"
	
	subst1:=subst2:=0
	loop 1
		moText:=RegExReplace(parsed[lineS],"^" indent,"")
		,text.=moText "`r`n"
		,subst1:=strlen(parsed[lineS])-strlen(moText)
	;~ msgbox % subst1
	loop % lineE-lineS
		line:=parsed[a_index+lineS]
		,moText:=RegExReplace(line,"^" indent,"")
		,text.=moText "`r`n"
		,subst2+=strlen(line)-strlen(moText)
	;~ msgbox % subst2
	loop % parsed.maxindex()-lineE
		text.=parsed[a_index+lineE] "`r`n"
	text:=RegExReplace(text,"\r\n$","")
	;~ controlsettext,,% text,ahk_id %id%
	Edit_SetText(id, Text)
	,Edit_SetSel(id,s-subst1,e-subst2-subst1)
	,_resetHotstringBuffer() 
}
return

normalTab:
if instr(a_thishotkey,"+")
	send +{%tab%}
else 
	send {%tab%}
return

shiftLine:
id:=getFocusedHwnd()
,Edit_GetSel(id,s,e)
,text:=controlgettext(id)
,parsed:=[],i:=0,lineS:=lineE:=-1
loop,parse,text,`n,`r
{
	parsed.push(a_loopfield)
	if (i:=i+strlen(a_loopfield)+2)>s && lineS<0
		lineS:=a_index
	if (i>=e) && lineE<0
		lineE:=a_index
}
if (lineE<lineS)
	lineE:=lineS
text:=""
if instr(a_thishotkey,"UP") {
	if lineS=1
		return
	loop % lineS-2
		text.=parsed[a_index] "`r`n"
	loop % lineE-lineS+1
		text.=parsed[a_index-1+lineS] "`r`n"
	loop 1
		text.=(changedLine:=parsed[lineS-1] "`r`n"),s-=strlen(changedLine),e-=strlen(changedLine)
	loop % parsed.maxindex()-lineE
		text.=parsed[a_index+lineE] "`r`n"
}else if instr(a_thishotkey,"DOWN"){
	if (lineE=parsed.maxindex())
		return
	loop % lineS-1
		text.=parsed[a_index] "`r`n"
	loop 1
		text.=(changedLine:=parsed[lineE+1] "`r`n"),s+=strlen(changedLine),e+=strlen(changedLine)
	loop % lineE-lineS+1
		text.=parsed[a_index-1+lineS] "`r`n"
	loop % parsed.maxindex()-lineE-1
		text.=parsed[a_index+lineE+1] "`r`n"
}
text:=RegExReplace(text,"\r\n$","")
;~ controlsettext,,% text,ahk_id %id%
,Edit_SetText(id, Text)
,Edit_SetSel(id,s,e)
,_resetHotstringBuffer() 
return

bracket:
k:=A_ThisHotkey
if instr(k,"[")
	send {[}
else 
	send {]}
return

select:
k:=A_ThisHotkey
;~ id:=getRisReports(risopened()[2])[1,1]
id:=getFocusedHwnd()

s:=e:=""
Edit_GetSel(id,s,e)

,selection:=Edit_select2(id
	,selectBy:=instr(k,win)?3:instr(k,alt)?2:1
	,direction:=instr(k,"[")?0:1
	,selectionInfo:=instr(k,"[")?[s,s]:[e,e])

,Edit_SetSel(id, k="["?selection.2:selection.1, k="["?selection.1:selection.2)
,_resetHotstringBuffer() 
return

click:
if !(++clickCount>2){
	settimer,decay,-300
	return
}
clickCount:=0
settimer,decay,off

;~ id:=getRisReports(risopened()[2])[1,1]
id:=getFocusedHwnd()
EditFunc_SelectLine(0,0,id)
return

tooltip:
ToolTip
return

decay:
if(--clickCount=0)
	settimer,decay,off
else
	settimer,decay,-300
return

;~ tab:
;~ id:=getFocusedHwnd()
;~ if !skipClosure(id)
	;~ send {%tab%}
;~ return


hotkey:
k:=A_ThisHotkey
;~ id:=getRisReports(risopened()[2])[1,1]
id:=getFocusedHwnd()

,selection:=Edit_select2(id
	,selectBy:=instr(k,win)?3:instr(k,alt)?2:instr(k,ctrl)?1:0
	,direction:=(instr(k,"left")||instr(k,"bs"))?0:1)

,Edit_SetSel(id,(instr(k,shift)||instr(k,"bs")||instr(k,"del"))?selection.1:selection.2
	,selection.2)

SendLevel,0
if instr(k,"bs"){
	send {bs}
	;~ SetTimer,sendEsc,-1
}else if instr(k,"del")
	send {del}
SendLevel,2
;~ test:=Edit_Select2(id,2,1)
;~ Edit_Select(test.1,test.2,id)

if selectBy in 2,3
{
	Sleep 400
	newX:=a_caretx,newY:=A_CaretY+6,frame:=100
	settimer,show,-1
}
_resetHotstringBuffer() 
return

sendEsc:
KeyWait,Alt,1
KeyWait,Ctrl,1
KeyWait,Shift,1
KeyWait,LWin,1
KeyWait,RWin,1
send {esc}
return


;; select current caret to current line end
selectToEnd:
;~ LButton & RButton::
if !GetKeyState("LButton")
	return
Loop
	Sleep 10
until !GetKeyState("LButton") && !GetKeyState("RButton") && !A_Index<50
send {esc}  ; clsoe context menu
gosub editInfo
offset:=Edit_LineIndex(focused, line-1)
,thisLine:=Edit_GetLine(focused, line-1)
,SetTimerF("waitKeyUpSetSel", -1, [focused, selStart, sel:=Offset+StrLen(RegExReplace(thisLine,"[\r\n]",""))])
;~ ,Edit_SetSel(focused, selStart, )
;~ ,Edit_ScrollCaret(focused)
,_resetHotstringBuffer() 
return

;; select current mouse to current line start
selectToStart:
;~ RButton & LButton::
if !GetKeyState("RButton")
	return
Loop
	Sleep 10
until !GetKeyState("LButton") && !GetKeyState("RButton") && !A_Index<50
send {esc}  ; clsoe context menu
gosub editInfo
offset:=Edit_LineIndex(focused, line-1)
;~ ,thisLine:=Edit_GetLine(focused, line-1)
,SetTimerF("waitKeyUpSetSel", -1, [focused, selStart, sel:=Offset])
;~ ,Edit_SetSel(focused, selStart, )
;~ ,Edit_ScrollCaret(focused)
,_resetHotstringBuffer() 
return



waitKeyUpSetSel(focused, selStart, selEnd){
	Loop
		Sleep 10
	until !GetKeyState("Lbutton") && !GetKeyState("Rbutton") && !A_Index<50
	Edit_SetSel(focused, selStart, selEnd)
	,Edit_ScrollCaret(focused)
}

/*
start0: original start
end0:   original end
selectBy:
    0: alphabet
    1: word			(ctrl)
    2: sentence		(alt)
    3: paragraph	(win)
direction:
    0: left
    1: right
selectionInfo: array
	1 => start position
	2 => end position
*/

Edit_Select2(control="",selectBy=1,direction=0,selectionInfo="",Text=""){
    if !control {
        ;~ control:=getRisReports(risopened()[2])[1,1]
		control:=getFocusedHwnd()

    }
    
    if !control
        return
    
	if(selectionInfo=""){
		Edit_GetSel(control,s,e)
		s0:=s,e0:=e
	}else{
		s:=s0:=selectionInfo.1,e:=e0:=selectionInfo.2
	}
    ;~ controlgettext,text,,ahk_id %control%
	if(Text="")
		text:=ControlGetText(control)
	StrLen:=StrLen(Text)
    
    position:=[0],i:=1, position[0]:=0
    ,start:=end:="",l:=0,parser:=[]
    
	,parser[3]:="`n`r"
	,parser[2]:="`n`r.;:,"
	,parser[1]:="`n`r.;:,()-/> "
	,allparser:="`n`r.;:,()-/> "
	
	


	,chop(s,e,text,parserRegex:="\n\r\.\;\,\(\)\-\/\>\ ",direction,0)

	
	loop,parse,text,% parser[selectBy]
	{
		
		l+=(len:=strlen(A_LoopField))
		;~ ,delim:=substr(text,l+1,1)
		if(len=0){
			goto continue
		}

		if(direction=0){
			if(l>=s && start="")
				start:=position[i]=s?position[i-1]:position[i]
			if(l>e){
				end:=l
				break
			}
		}else{
			if(l>s && start="")
				start:=position[i]
			if(l>=e){
				end:=l
				break
			}
		}
continue:		
		
		position[++i]:=direction?l++:++l

		;~ Edit_Select(position[i-1],position[i],control)
		;~ sleep 1000
	}
	
	if(start="")
		start:=s-1
	if(end="")
		end:=StrLen
	
	chop(start,end,text,parserRegex,direction,selectBy)
	

	if(direction=0){
		if(start=s0&&s0!=0){
			if (s0=e0)
				ret:=[e0, s]
			else
				ret:=[e0, Edit_Select2(control,selectBy,direction,[s0,s0],Text).2]
		}else{
			;~ ret:=[e0, start>e0?0:start]
			ret:=[e0, start>e0?s-1:start]
		}
		;~ MsgBox % ret[1] "," ret[2] "," SubStr(text, ret[2], ret[1]-ret[2]+1) "," SubStr(text, 1, ret[2]-1)
		;;; patch for parenthesis
		if ((_t:=SubStr(text, ret[2], ret[1]-ret[2]+1))~="\)\s*$") &&  (_t~="^\(\s*")
			ret[2]-=1
		return ret
		;~ ret:=[e0, (start=s0&&s0!=0)?(Edit_Select2(control,selectBy,direction,[s0,s0],Text)).2:start]
	}else{
		if(end=e0&&e0!=StrLen){
			if (s0=e0)
				;~ ret:=[s0, e=e0?StrLen:e]
				ret:=[s0, e=e0?e+1:e]
			else
				ret:=[s0, Edit_Select2(control,selectBy,direction,[e0,e0],Text).2]
		}else{
			ret:=[s0, End<s0?StrLen:End]
		}
		;;; patch for parenthesis
		if (SubStr(text, ret[1], ret[2]-ret[1]+1)~="^\s*\(") && RegExMatch(SubStr(text, ret[2]+1), "^\s*\)", _m) 
			ret[2]+=StrLen(_m)
		return ret
		;~ return [e0, (start=s0&&s0!=0)?(Edit_Select2(control,selectBy,direction,[s0,s0],Text)).2:start]
	}
		;~ return [s0, (end=e0&&e0!=strlen(text))?(Edit_Select2(control,selectBy,direction,[e0,e0],Text)).2:end]
}

chop(byref s, byref e, text, parserRegex, direction,selectBy=1){

	if(s!=e){
		RegExMatch(substr(text,s+1,e-s),tempreg:="s)^([" parserRegex "]*)(.*?)([" parserRegex "]*)$",match)
		
		if strlen(match2)=0
			if (direction=0)
				e:=s
			else
				s:=e
		else
			s+=strlen(match1),flag1:=true
	}
	
	if(!flag1){
		if(direction=0){
			RegExMatch(substr(text,1,s),tempreg:="s)^(.*?)([" parserRegex "]*)$",match)
			,s-=strlen(match2),e:=s
		}else{
			RegExMatch(substr(text,s+1),tempreg:="s)^([" parserRegex "]*)(.*?)$",match)
			,s+=strlen(match1),e:=s
		}
	}	
	
	if(selectBy=1){
		regexmatch(substr(text,e+1),"s)^([ ]*)",match)
		,e+=strlen(match1)
	}else if(selectBy=2){
		regexmatch(substr(text,e+1),"s)^([\,\;\.]*[ ]*)",match)
		,e+=strlen(match1)
	}else if(selectBy=3){
		regexmatch(substr(text,e+1),"s)^([^\r\n]*[\r\n]*)",match)
		,e+=strlen(match1)
	}
	
}

skipClosure(control){
    if !control {
        ;~ control:=getRisReports(risopened()[2])[1,1]
		control:=getFocusedHwnd()

    }
    
    if !control
        return
    

	Edit_GetSel(control,s,e)
	
	if (s!=e)
		return 0
	
	;~ controlgettext,text,,ahk_id %control%
    text:=ControlGetText(control)
	
	RegExMatch(substr(text,s+1),"s)^([\W_]*)",match)
	return (l:=strlen(match1))?Edit_SetSel(control,s+l,s+l):0

}

GetText(hWnd, Encoding := "") {
	wingetclass,class,ahk_id %hwnd%
	if instr(class,"Scintilla")
		encoding:="UTF-8"
DllCall("SendMessage", UInt, hWnd, UInt, 13, Int, VarSetCapacity(Text, DllCall("SendMessage", UInt, hWnd, UInt, 14) + 1 << 1) >> 1, Str, Text)
	return Encoding ? StrGet(&Text, Encoding) : Text
}

show:
if (frame<20){
	settimer,show,off
	settimer,hide,-1
	return
}
cornerX1:=floor(newX-frame/2),cornerY1:=floor(newY-frame/2)
,cornerX2:=floor(newX+frame/2),cornerY2:=floor(newY+frame/2)
Gui, 1: Show, % "x" cornerX1 " y" cornerY1 " w" frame " h2 NoActivate"
Gui, 4: Show, % "x" cornerX1 " y" cornerY2 " w" frame " h2 NoActivate"
Gui, 2: Show, % "x" cornerX1 " y" cornerY1 " w2 h" frame " NoActivate"
Gui, 3: Show, % "x" cornerX2 " y" cornerY1 " w2 h" frame " NoActivate"
frame:=floor(frame/2)
settimer,show,-100

return


hide:
loop 4
	gui, %a_index%:hide
return



;~ esc::
~!^q::
exitapp
return


exit(){
	ExitApp
}



/*
Edit_Select2(control="",selectBy=1,direction=0,selectionInfo="",Text=""){
    if !control
 		control:=getFocusedHwnd()
    
    if !control
        return
    
	if(selectionInfo=""){
		Edit_GetSel(control,s,e)
		s0:=s,e0:=e
	}else{
		s:=s0:=selectionInfo.1,e:=e0:=selectionInfo.2
	}
    ;~ controlgettext,text,,ahk_id %control%
	if(Text="")
		text:=ControlGetText(control)
    
    position:=[[0,0,0]],i:=1, position[0]:=[0,0,0]
    ,start:=end:="",l:=0,parser:=[]
    
	,parser[3]:="`n`r"
	,parser[2]:="`n`r.;:,"
	,parser[1]:="`n`r.;:,()-/ "
	,allparser:="`n`r.;:,()-/ "

	segments:=[]
	Loop,parse,Text,% allparser
	{
		ind:=A_Index
		Loop 3
			if InStr(parser[4-A_Index]){
				segments[ind]:=4-A_Index
				break
			}
	}
	
	for k,v in segments
	{
		
	}

	
	loop,parse,text,% parser[selectBy]
	{
		
		l+=(len:=strlen(A_LoopField))
		;~ ,delim:=substr(text,l+1,1)
		if(len=0){
			goto continue
		}

		if(direction=0){
			if(l>=s && start="")
				start:=position[i]=s?position[i-1]:position[i]
			if(l>e){
				end:=l
				break
			}
		}else{
			if(l>s && start="")
				start:=position[i]
			if(l>=e){
				end:=l
				break
			}
		}
continue:		
		
		position[++i]:=direction?l++:++l

		;~ Edit_Select(position[i-1],position[i],control)
		;~ sleep 1000
	}
	
	if(start="")
		start:=0
	if(end="")
		end:=strlen(text)
	
	chop(start,end,text,parserRegex,direction,selectBy)
	

	if(direction=0)
		return [e0, (start=s0&&s0!=0)?(Edit_Select2(control,selectBy,direction,[s0,s0],Text)).2:start]
	else
		return [s0, (end=e0&&e0!=strlen(text))?(Edit_Select2(control,selectBy,direction,[e0,e0],Text)).2:end]
}
*/

deleteWord2(){
	;~ focused:=getFocusedHwnd()
	;~ ,text1:=Edit_GetText(focused)
	send ^+{left}{bs}
	;~ text2:=Edit_GetText(focused)
	;~ if (text1=text2){
		;~ Edit_GetSel(focused,s,e)
		
	;~ }
}

#IfWinNotActive,ahk_group RisGroup
$`::
if (WinGetClass(getFocusedHwnd())~="i)Edit|Scintilla|text") && !(WinGet("ProcessName", WinExist("A"))~="i)scite|notepad\+{2}")
	deleteWord2()
else
	send ``
return
#IfWinNotActive

#IfWinActive,ahk_group RisGroup
`::
deleteWord2()
return

^w::
^y::
if(sci.hWnd==(focusedHwnd:=getFocusedHwnd())){
	sci.delline()
}else{
	sci:=new RemoteScintilla(focusedHwnd)
	,sci.delline()
}
;~ oldSendLevel:=a_sendlevel
;~ SendLevel,0
;~ send {home}+{end}{del}{del}
;~ SendLevel,% oldSendlevel
return

#IfWinActive