#InstallKeybdHook

/*

::tae::
sendtest("testtesttest")
return

sendtest(txt){
	sendbyclipboard(txt, -1)
}
*/


__sendByClipboard_outputVar_setText(){
	global __sendByClipboard_outputVar
	focused:=getFocusedHwnd()
	,Edit_SetText(focused, __sendByClipboard_outputVar)
	,__sendByClipboard_outputVar:=""
	,Edit_SetSel(focused, -1, -1)
	,Edit_ScrollCaret(focused)
}

;; if bs=-1, check if trigger backspaced
sendByClipboard(byref str, bs=0, trigger=""){
		global __sendByClipboard_pClipboard,$
			,__sendByClipboard_outputVarMode,__sendByClipboard_outputVar, thisPlace, __sendbyClipboard_debug
		static upperChr:="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
			, originalMode:=false
			, testTime:=0
			, priorTrigger:=""
			, lastTick:=0
			, triggerMap:={" ": "space", "`n": "enter", "`t": "tab"}
			, p_sci:=""
			, nonWordHook:=""
			, AllUseClipboard:=false
			, lastActiveSimpleRisWithScintilla:=0
			, lastFocusedHwnd:=0
			, guihwnd:=0
			, edithwnd:=0
		
		if __sendbyClipboard_debug
			original_args:=[s:=strong, bs, trigger]
		;~ if !nonWordHook
			;~ nonWordHook:=InputHook("B", "{esc}", " ,.,;,,,")
		;~ nonWordHook.start()	
		sendlevel,0
		;~ tooltip % a_thislabel
		_tick:=A_TickCount
		
		
		if (str!=""){
			if(trigger="")
				trigger:=$.value(0)!=""?$.value(0):$!=""?$:regexreplace(a_thislabel,"^:?[^:]*:?([^:]+)", "$1")
			if InStr(upperChr, SubStr(trigger,1,1), true)
				str:=StringUpperFirst(str)
		}
		
		;~ focused:=getFocusedHwnd()
		;~ ,class:=WinGetClass(focused)
		;~ if (class~="i)Scintilla"){
			;~ ToolTip % class "," WinGetTitle(WinExist("A"))
			;~ if !(WinExist("ahk_id " guihwnd) && controlexists(edithwnd)){
				;~ guihwnds:=getSimpleRisGuiHwnds()
				;~ ,editHwnds:=getSimpleRisEditHwnds()
				;~ if controlexists(editHwnds[2])
					;~ guihwnd:=guihwnds[2]
					;~ ,edithwnd:=editHwnds[2]
				;~ else if controlexists(editHwnds[1])
					;~ guihwnd:=guihwnds[1]
					;~ ,edithwnd:=editHwnds[1]
				;~ else if (RisState:=RisOpened())[2] && (RisReports:=getRisReports(RisState[2]))[1,1]
					;~ guihwnd:=RisState[2]
					;~ ,edithwnd:=RisReports[1,1]
			;~ }
			;~ if WinExist("ahk_id " guihwnd) && controlexists(edithwnd) {
				;~ if !WinActive("ahk_id " guihwnd) {
					;~ WinActivate,% "ahk_id " guihwnd
					;~ WinWaitActive,% "ahk_id " guihwnd,,1
					;~ ControlFocus,,% "ahk_id " edithwnd
				;~ }
			;~ }
		;~ }
		
		;~ keywait,%  (triggerMap.haskey(trg:=substr(trigger,0,1))?triggerMap[trg]:trg),T0.4
		;~ if bs
				;~ SendInput {bs %bs%}
				
			;~ if str!=
				;~ SendInput % RegExReplace(str, "\r", "")
			;~ if (following:=nonWordHook.input)!=""
				;~ SendInput % following
			
			;~ goto sendByClipboard_return
			;~ return
		;~ }
		
		;~ if(str="" && priorTrigger=trigger){
			;~ if(lastTick && A_TickCount-lastTick<300 && lastTick:=A_TickCount)
				;~ goto sendByClipboard_return
		;~ }
		lastTick:=A_TickCount
		,priorTrigger:=trigger
		
		if(__sendByClipboard_outputVarMode){
			thisSend:=str nonWordHook.input 
			if !(thisSend~="\W$")
				thisSend.="."
			__sendByClipboard_outputVar.=thisSend
			goto sendByClipboard_return
			
		}
		
		if(originalMode && !AllUseClipboard){
			if bs>0
				SendInput {bs %bs%}
				
			if str!=
				SendInput % RegExReplace(str, "\r", "")
			if (following:=nonWordHook.input)!=""
				SendInput % following
			goto sendByClipboard_return
		}
		
		
		if(testTime==0){
			testTimePre:=a_tickcount
		}
		
		;~ activeWin:=WinExist("A")
		;~ if (activeWin = lastActiveSimpleRisWithScintilla){
			;~ focused:=lastFocusedHwnd
			;~ ,class:="Scintilla"
			;~ ,sci:=p_sci ? p_sci : (p_sci:=new RemoteScintilla(focused))
		;~ }else {
			
			;~ focused:=getFocusedHwnd()
			;~ ,class:=WinGetClass(focused)
			;~ if HasVal(getSimpleRisGuiHwnds(), activeWin) && (class="Scintilla")
				;~ lastActiveSimpleRisWithScintilla:=activeWin
			
			;~ if (class="Scintilla")
				;~ lastFocusedHwnd:=focused
				;~ ,sci:=p_sci.hwnd=focused ? p_sci : (p_sci:=new RemoteScintilla(focused))
		;~ }
		
		focused:=getFocusedHwnd()
		,class:=WinGetClass(focused)
		
		
		;~ ToolTip % (triggerMap.haskey(trg:=substr(trigger,0,1))?"{" triggerMap[trg] "}":trg)
		;~ if str!=
			keywait,%  (triggerMap.haskey(trg:=substr(trigger,0,1))?triggerMap[trg]:trg),L T0.4
			;~ ToolTip % trigger "." ErrorLevel "." trg
		
		;~ if InStr(thisPlace, "C hospital"){
			;~ str:=RegExReplace(str, " *\.*([\.,]) *([\r\n\t]*)$", "$1 $2")
			;~ str:=RegExReplace(str, "\.\)([ \.,]*)([\r\n\t]*)$", ") $2")
			;~ ,str:=RegExReplace(str, "\r?\n", "`r`n")
		;~ }
		
		if __sendbyClipboard_debug
			OutputDebug,sendbyclipboard
		
		if(class="Scintilla") && !AllUseClipboard {
			sci:=new RemoteScintilla(focused)
			;~ ToolTip % A_TickCount-_tick
			if(bs>0)
				sci.DeleteRange(sci.getCurrentPos()-bs, bs)
			else if(bs=-1){
				;~ MsgBox % trigger "," A_ThisLabel "."
				sci.DeleteRange(sci.getCurrentPos()-(bs:=StrLen(trigger)-(InStr(A_ThisLabel,"*")?1:0)), bs)	
				;~ Showtooltip(bs)
				;~ txt:=sci.getText()
				;~ ,sci._GetSel(s,e,txt)
				;~ ,trigger_len:=StrLen(trigger)
				;~ ,Range_txt:=SubStr(txt, s-trigger_len+1, trigger_len)
				;~ ,trigger_regex:=Text2Regex(trigger)
				
				;~ if RegExMatch(Range_txt, "\b(" trigger_regex ")$", match) && InStr(trigger, match1)==1
					;~ bs:=StrLen(match1)
					;~ ,sci.DeleteRange(sci.getCurrentPos(txt)-bs, bs)
			}
			
			if(str!=""){
				if (str~="^\{[^\r\n]+\}$")
					SendInput % RegExReplace(str, "\r", "")
				else
					sci.AddText(str)
			}
			if (following:=nonWordHook.input)!=""
				sci.AddText(following)
		}else{
			;~ keywait,% "{" substr(str,-1,1) "}",T0.1
			;~ sleep 20
			if !instr(class, "Edit") || AllUseClipboard {
				if bs>0
					SendInput {bs %bs%}
				
				if str=
					goto sendByClipboard_return
				
				if __sendByClipboard_pClipboard=
					__sendByClipboard_pClipboard:=clipboardall
				clipboard:=""
				clipboard:=str (nonWordHook.input)
				ClipWait,1,0
				;~ while (clipboard!=str) && a_index<300
					;~ sleep -1
				keywait,bs,T0.1
				;~ sleep 20
				SendInput ^v
				SetTimer,__sendByClipboard_pClipboard, -500
			}else{
				if bs>0
					Edit_DeleteText(focused, "", bs)
				
				if(str!=""){
					if (str~="^\{[^\r\n]+\}$")
						SendInput % RegExReplace(str, "\r", "") (nonWordHook.input)
					else
						Edit_InsertText(focused, str (nonWordHook.input))
				}
				
					
				;~ sleep 20
				;~ send % str
			}
			;~ t:=Edit_GetText(focused), Edit_GetSel(focused, s, e)
			;~ if(bs)
				;~ s:=e:=s-bs>=0?s-bs:0
			;~ t:=(s>=0?SubStr(t, 1, s):"") str SubStr(t, s+bs+1)
			;~ ,Edit_SetText(focused, t)
			;~ ,e:=(s+=StrLen(str))
			;~ ,Edit_SetSel(focused, s, e)
		}
		;~ if (hotstringHelperHwnd:=winexist("ahk_exe Hotstring Helper.exe"))
			;~ PostMessage,0x10102,,,,ahk_id %hotstringHelperHwnd%
		resetHotstringBuffer(-2)
		;~ Suspend on 
		;~ Suspend Off
		
		
		if(testTime==0){
			testTime:=a_tickcount-testTimePre
			;~ ,Showtooltip("send by clipboard test time: " testTime)
			;~ if(testTime>400)
				;~ originalMode:=true
		}
sendByClipboard_return:
		nonWordHook.stop()
		,hotstring("reset")
		,$:=""
		,Dynamic_Hotstring("", "", "", "", "", true)
		;~ ,Showtooltip("sent", 500)
		return
		
	}
	
	
	__sendByClipboard_pClipboard(){
		global __sendByClipboard_pClipboard
		clipboard:=__sendByClipboard_pClipboard
		,__sendByClipboard_pClipboard:=""
	}
	
	~+!^d::
	ShowTooltip("sendbyclipboard debug: " __sendbyClipboard_debug:=!__sendbyClipboard_debug)
	return