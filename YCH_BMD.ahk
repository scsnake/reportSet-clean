#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
SetBatchLines, -1
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
SetTitleMatchMode,2
setformat,float,0.2
SetControlDelay,-1
#SingleInstance,force
; Talk to the single CH_RIS owner (autorun) over IPC instead of a local owner. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include %A_ScriptDir%\Lib\OCR\INFINITT_OCR_BMD.ahk
DetectHiddenWindows,on
ComObjError(false)

CloseOtherYCHAHK("YCH_BMD_main")
OnScreenDisplay("YCH BMD")
OCR_WinRT_Init()

global BMD_LAST_OCR_ACCNO := ""
global BMD_OCR_POLL_INTERVAL := 1500
global BMD_OCR_LOAD_DELAY := 2000
global BMD_DXA_WRITTEN := false   ; set after dxa0 OCR; causes bmd: to auto-append whole body BMD

global thisPlace:=getPlace()
OnMessage(0x10101,"Exit")
gui,new,+hwndmainguihwnd +LastFound
WinSetTitle,ahk_id %mainguihwnd%,,% "YCH_BMD_main"

gui,simpleRISsimpleEdit:new,+hwndsimpleRISsimpleEditGuiHwnd
WinSetTitle,ahk_id %simpleRISsimpleEditGuiHwnd%,,simpleRISsimpleEdit

gosub simpleRISnoUpdate
winwait,simpleRIS_main ahk_class AutoHotkeyGUI,,30
PostMessage,0x2025,0,,,simpleRIS_main ahk_class AutoHotkeyGUI

if InStr(thisPlace, "C hospital")
	SetTimer, BMD_OCR_PollExam, % BMD_OCR_POLL_INTERVAL

Loop {
	input,var,v,{/}{NumpadDiv}
	gosub bmd
}

return

; Include the INFINITT OCR scroll library HERE (after the main return) so that its
; top-level subroutine labels (OCRPreviewClose:, INFINITT_OCR_OnExit_UNUSED:) land in
; the subroutine section and never terminate the auto-execute section above.
; All functions are compiled globally so BMD OCR functions can call OCR_ReadText,
; ShowOCRRegion, etc. even though the #include appears after return.
#include %A_ScriptDir%\Lib\OCR\INFINITT_OCR_Scroll.ahk

; Click-capture label for BMD_WaitForClick_Hook (INFINITT_OCR_BMD.ahk).
; Fires in a new thread when the temporary LButton hotkey is active.
; Must live here (after the main return) so it does not terminate auto-execute.
_BMD_ClickHook:
	global _BMD_ClickX, _BMD_ClickY, _BMD_ClickState
	CoordMode, Mouse, Screen
	MouseGetPos, _BMD_ClickX, _BMD_ClickY
	_BMD_ClickState := "got"
return

; ─────────────────────────────────────────────────────────────────────────
; OCR pipeline — runs alongside the hand-input loop above.
;
; Trigger paths:
;   • C hospital study change (timer below polls CH_RIS.accNo)
;   • Manual hotkey ^!b (force-run on the current study)
;   • Calibration hotkey ^!k (interactive ROI capture for current subtype)
; ─────────────────────────────────────────────────────────────────────────
BMD_OCR_PollExam:
	try {
		CH_RIS.check_wb()
		curAcc := Trim("" CH_RIS.accNo)
		if (curAcc != "" && curAcc != BMD_LAST_OCR_ACCNO) {
			BMD_LAST_OCR_ACCNO := curAcc
			BMD_DXA_WRITTEN := false
			BMD_HideDXAFrames(BMD_DXA_FRAME_COUNT)
			BMD_DXA_FRAME_COUNT := 0
			SetTimer, BMD_OCR_RunOnNewStudy, % -BMD_OCR_LOAD_DELAY
		}
	} catch e {
	}
return

BMD_OCR_RunOnNewStudy:
	BMD_OCR_TriggerFromCurrent(false)
return

BMD_OCR_ManualTrigger:
	BMD_OCR_TriggerFromCurrent(true)
return

BMD_OCR_CalibrateCurrent:
	try CH_RIS.refresh_info()
	subtype := BMD_DetectSubtype(CH_RIS.examname)
	if (subtype = "") {
		ToolTip, % "BMD subtype not recognized for: " CH_RIS.examname "`nUse ^!K then choose subtype manually"
		Sleep, 1500
		ToolTip
		return
	}
	BMD_CalibrateSubtype(subtype)
return

BMD_OCR_CalibratePicker:
	BMD_PickAndCalibrate()
return

BMD_OCR_TriggerFromCurrent(showOverlay := false) {
	global BMD_OCR_LAST_SUBTYPE, BMD_OCR_LAST_PARSED
	try CH_RIS.refresh_info()
	subtype := BMD_DetectSubtype(CH_RIS.examname)
	if (subtype = "") {
		ToolTip, % "BMD subtype not recognized: " CH_RIS.examname
		Sleep, 1200
		ToolTip
		return
	}
	ocr := BMD_OCR_ReadAll(subtype, showOverlay)
	if !IsObject(ocr) {
		ToolTip, OCR failed (no viewport / no schema)
		Sleep, 1200
		ToolTip
		return
	}
	if (ocr._missing.Length() > 0) {
		ToolTip, % "Missing calibration for " subtype ": " BMD_JoinList(ocr._missing) "`nRun ^!K to calibrate"
		Sleep, 1800
		ToolTip
		return
	}
	parsed := BMD_OCR_ToParsed(ocr)
	if !IsObject(parsed) {
		ToolTip, % "OCR parse failed for " subtype "`nRaw: " BMD_OCR_DumpRaw(ocr)
		Sleep, 2000
		ToolTip
		return
	}
	BMD_OCR_LAST_SUBTYPE := subtype
	BMD_OCR_LAST_PARSED := parsed
	BMD_OCR_WriteReport(subtype, parsed, false)
}

; Write a pre-built result object to all production report surfaces.
; Callers: BMD_OCR_WriteReport (single subtype) and DXA_OCR_Trigger (combined report).
BMD_WriteResult(result) {
	global thisPlace
	thisPlace := getPlace()
	if !InStr(thisPlace, "C hospital")
		return

	clipboard := result.text

	Controlget, editHwnd, hwnd,, Scintilla1, simple RIS ahk_class AutoHotkeyGUI
	if (editHwnd)
		Edit_SetText(editHwnd, result.text)

	risReports := getRisReports()
	if (IsObject(risReports) && IsObject(risReports[1])) {
		Edit_SetText(risReports[1,1], result.text)
		Edit_SetText(risReports[1,2], "")
	}

	try {
		CH_RIS.exam := result.text
		CH_RIS.impression := ""
	}

	if (editHwnd)
		BMD_ApplyHighlights(editHwnd, result.text, result.spans)
	CH_RIS.flush()
	BMD_ActivateReportTargets(editHwnd, result)
}

BMD_ActivateReportTargets(editHwnd, result) {
	if (editHwnd) {
		simpleHwnd := WinExist("simple RIS ahk_class AutoHotkeyGUI")
		if (simpleHwnd)
			WinActivate, ahk_id %simpleHwnd%
		ControlFocus,, ahk_id %editHwnd%
		Sleep, 80
	}

	try CH_RIS.activate()

	if (editHwnd && IsObject(result) && IsObject(result.missing) && result.missing.Length() > 0)
		BMD_FocusFirstMissingInput(editHwnd, result)
}

BMD_FocusFirstMissingInput(editHwnd, result) {
	if (!IsObject(result) || !IsObject(result.missing) || result.missing.Length() = 0)
		return
	first := result.missing[1]
	pos := first.pos
	Edit_SetSel(editHwnd, pos, pos)
	SendMessage, 2169, 0, 0,, ahk_id %editHwnd%   ; SCI_SCROLLCARET
	ControlFocus,, ahk_id %editHwnd%
	ToolTip, % "DXA OCR missing: " first.label "`nType value here, then review report/impression."
	SetTimer, BMD_HideMissingTooltip, -4500
}

BMD_HideMissingTooltip:
	ToolTip
return

BMD_OCR_WriteReport(subtype, parsed, append_report) {
	global thisPlace
	thisPlace := getPlace()
	if !InStr(thisPlace, "C hospital")
		return
	CH_RIS.check_wb()
	CH_RIS.refresh_info()
	oldReport := append_report ? (CH_RIS.exam "`n`n" CH_RIS.impression "`n`n") : ""
	result := BMD_BuildReport(subtype, parsed, append_report, oldReport)
	if !IsObject(result)
		return
	BMD_WriteResult(result)
}

BMD_PickAndCalibrate() {
	global BMD_OCR_SCHEMA
	choices := ""
	for k in BMD_OCR_SCHEMA
		choices .= (choices = "" ? "" : "|") k
	InputBox, pick, BMD calibration, % "Subtype to calibrate?`n(" choices ")",, 320, 160,,,,, lumbar
	if (ErrorLevel || pick = "")
		return
	BMD_CalibrateSubtype(pick)
}

BMD_JoinList(arr, sep := ", ") {
	out := ""
	for _, v in arr
		out .= (out = "" ? "" : sep) v
	return out
}

BMD_OCR_DumpRaw(ocr) {
	out := ""
	for k, v in ocr {
		if (SubStr(k,1,1) = "_")
			continue
		out .= (out = "" ? "" : " | ") k "=" v
	}
	return out
}
simpleRISnoUpdate:
	PostMessage,0x2022,3600000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
return
bmd:
	/*
	prefix - = append report not replace

	aaa = value of BMD(g/cm2) * 1000
	bb = abs(T or Z score)*10
	c = z if use z score else empty
	d = + if score>0 else empty

	score_info = aaacdbb

	lumbar:
	default level = L1-L4
	other level: xy = Lx-Ly

	input: [xy]score_info

	hip:
	side = r or l
	score_info1 = femoral neck info
	score_info2 = total BMD info

	input: side score_info1 score_info2

	whole body:
	w score_info

	*/

	hotstr:=var,keys:=[]
	;~ send % "{bs " strlen(var) "}"
	append_report:=false
	if SubStr(hotstr, 1,1)="-"
		append_report:=true
			,hotstr:=SubStr(hotstr, 2)
	if (BMD_DXA_WRITTEN && !append_report)
		append_report := true
	loop,parse,hotstr,.
		keys.push(Trim(a_loopfield))
	part:="",level:="L1-L4",outstr:="",t:=999,z:=999
	for k,v in keys {
		if v in r,l,w
			part:=v, showToolTip(part)
		else if regexmatch(v,"is)(\d{3})(z?)(\+?\d{1,2}) (\d{3})(z?)(\+?\d{1,2})",match){
			useZ:=!!match2,score:=scoreVal(match3)
				,useZ2:=!!match5,score2:=scoreVal(match6)
			bmd:=bmdVal(match1, score), bmd2:=bmdVal(match4, score2)

			if useZ
				z:=min(score, score2)<z?min(score, score2):z
			else
				t:=min(score, score2)<t?min(score, score2):t
			if (outstr!="")
				outstr.="`n"
			outstr.="Bone Mineral Density (BMD) of the " (part="r"?"right":"left") " hip with quantitative dual-energy X-ray absorptiometry shows:`n- The BMD of femoral neck is " bmd " g/cm2 (" (useZ?"Z":"T") "-score = " score ").`n- The total BMD of " (part="r"?"right":"left") " hip is " bmd2 " g/cm2 (" (useZ2?"Z":"T") "-score = " score2 ").`n"
		}else if regexmatch(v,"(\d{3})(z?)(\+?\d{1,2})",match){
			useZ:=!!match2,score:=scoreVal(match3), bmd:=bmdVal(match1,score)
			body_part:=part="w"?"whole body":"lumbar spine"
			level:=part="w"?"":" (" level ")"
			if useZ
				z:=score<z?score:z
			else
				t:=score<t?score:t
			if (outstr!="")
				outstr.="`n"
			outstr.="Bone Mineral Density (BMD) of the " body_part " with quantitative dual-energy X-ray absorptiometry shows:`n- The BMD of " body_part  level " is " bmd " g/cm2 (" (useZ?"Z":"T") "-score = " score ").`n"
		}else if regexmatch(v,"(\d)(\d)(\d?)",match)
			level:="L" match1 "-L" match2 (match3?"-L" match3:"")

	}
	thisPlace:=getPlace()
	Controlget,editHwnd,hwnd,,Scintilla1, simple RIS ahk_class AutoHotkeyGUI
	if InStr(thisPlace, "N hospital"){
		checkRis(RisState)
		gosub renewRisReports
		controlsettext,,% outstr,% "ahk_id " risReports[1,1]
		;~ controlsettext,Scintilla1,% outstr,simple RIS ahk_class AutoHotkeyGUI
		Edit_SetText(editHwnd, outstr)
		controlsettext,,% (t<=-2.5?"Osteoporosis. (T-score <= -2.5)":t<-1?"Osteopenia. (-2.5 < T-score < -1)":t<2?"Normal.":t!=999?"High BMD.":z<-2?"Below the expected range for age. (Z-score < -2)":z!=999?"Normal.":"")  ,% "ahk_id " risReports[1,2]
	}
	else if InStr(thisPlace, "C hospital"){
		;~ send % "{bs " StrLen(hotstr)+1 "}"
		CH_RIS.check_wb()
			,CH_RIS.refresh_info()
		if append_report
			old_report:=CH_RIS.exam "`n`n" CH_RIS.impression "`n`n"
		else
			old_report:=""

		clipboard:=AllText:=old_report outstr "`n`nImpression:`n" (t<=-2.5?"Osteoporosis. (T-score <= -2.5)":t<-1?"Osteopenia. (-2.5 < T-score < -1)":t<2?"Normal.":t!=999?"High BMD.":z<-2?"Below the expected range for age. (Z-score < -2)":z!=999?"Normal.":"")
		Edit_SetText(editHwnd, AllText)
			,Edit_SetText(getRisReports()[1,1], AllText)
			,Edit_SetText(getRisReports()[1,2], "")
		CH_RIS.flush()
			,CH_RIS.activate()
	}
return
renewRisReports:
	if !(isobject(risReports) && controlexist(RisReports[1,1]))
		RisReports:=getRisReports(RisState[2])
return
;~ bmdVal(str, score=""){
;~ SetFormat, float, 0.3
;~ if strlen(str)=3
;~ return str>450||score<0?str/1000:(str/1000+1)
;~ else
;~ return str/1000
;~ }
bmdVal(str, score="") {
	SetFormat, float, 0.3

	; Remove any leading '+' or '-' for length check
	firstChar := SubStr(str, 1, 1)
	cleanStr := (firstChar = "+" || firstChar = "-") ? SubStr(str, 2) : str

	val := str / 1000.0  ; Ensure float division
	len := StrLen(cleanStr)

	if (len == 4) {
		return val
	}

	if (len < 4) {
		floatPart := Abs(val - Floor(Abs(val)))
		if (floatPart < 0.450) {
			return (val > 0 ? val + 1 : val - 1)
		}
	}

	return val
}

scoreVal(str){
	SetFormat, float, 0.1
	return (0.0+str)/10**(strlen(str)-(instr(str,"+"))-1)*(instr(str,"+")?1:-1)
}

;~ esc::exitapp
Hotstring(trigger, label, mode := 1, clearTrigger := 1, cond := ""){
	global $

	;symbols exclude ' \ / . + for special use in this script
	static keysBound := false,hotkeyPrefix := "~$", hotstrings := {}, typed := "", keys := {"symbols": "!""#$%&()*,-:;<=>?@[]^_``{|}~", "num": "0123456789", "alpha":"abcdefghijklmnopqrstuvwxyz", "other": "BS,Return,Tab,Space", "breakKeys":"Left,Right,Up,Down,Home,End,RButton,LButton,LControl,RControl,AppsKey,LAlt,RAlt,Lwin,Rwin,WheelDown,WheelUp,f1,f2,f3,f4,f5,f6,f7,f8,f9,f6,f7,f9,f10,f11,f12", "numpad":"Numpad0,Numpad1,Numpad2,Numpad3,Numpad4,Numpad5,Numpad6,Numpad7,Numpad8,Numpad9,NumpadDot,NumpadDiv,NumpadMult,NumpadAdd,NumpadSub,NumpadEnter"}, effect := {"Return" : "`n", "Tab":A_Tab, "Space": A_Space, "Enter":"`n", "Mult":"*"}

	if (!keysBound){
		;Binds the keys to watch for triggers.
		for k,v in ["symbols", "num", "alpha"]
		{
			;alphanumeric/symbols
			v := keys[v]
			Loop,Parse, v
				Hotkey,%hotkeyPrefix%%A_LoopField%,__hotstring
		}

		v := keys.alpha
		Loop,Parse, v
			Hotkey, %hotkeyPrefix%+%A_Loopfield%,__hotstring
		for k,v in ["other", "breakKeys", "numpad"]
		{
			;comma separated values
			v := keys[v]
			Loop,Parse, v,`,
				Hotkey,%hotkeyPrefix%%A_LoopField%,__hotstring
		}
		keysBound := true ;keysBound is a static varible. Now, the keys won't be bound twice.
	}
	if (mode == "CALLBACK"){
		; Callback for the hotkey.s
		Hotkey := SubStr(A_ThisHotkey,3)
		if (StrLen(Hotkey) == 2 && Substr(Hotkey,1,1) == "+" && Instr(keys.alpha, Substr(Hotkey, 2,1))){
			Hotkey := Substr(Hotkey,2)
			if (!GetKeyState("Capslock", "T")){
				StringUpper, Hotkey,Hotkey
			}
		}

		shiftState := GetKeyState("Shift", "P")
		uppercase :=  GetKeyState("Capslock", "T") ? !shiftState : shiftState
		;If capslock is down, shift's function is reversed.(ie pressing shift and a key while capslock is on will provide the lowercase key)
		if (uppercase && Instr(keys.alpha, Hotkey)){
			StringUpper, Hotkey,Hotkey
		}
		if (Instr("," . keys.breakKeys . ",", "," . Hotkey . ",")){
			typed := ""
			return
		} else if Hotkey in Return,Tab,Space
		{
			typed .= effect[Hotkey]
		} else if (Hotkey == "BS"){
			; trim typed var if Backspace was pressed.
			StringTrimRight,typed,typed,1
			return
		} else if (RegExMatch(Hotkey, "Numpad(.+?)", numKey)) {
			if (numkey1 ~= "\d"){
				typed .= numkey1
			} else {
				typed .= effects[numKey1]
			}
		} else {
			typed .= Hotkey
		}
		matched := false
		for k,v in hotstrings
		{
			matchRegex := (v.mode == 1 ? "Oi)" : "")  . (v.mode == 3 ? RegExReplace(v.trigger, "\$$", "") : "\Q" . v.trigger . "\E") . "$"

			if (v.mode == 3){
				if (matchRegex ~= "^[^\s\)\(\\]+?\)"){
					matchRegex := "O" . matchRegex
				} else {
					matchRegex := "O)" . matchRegex
				}
			}
			if (RegExMatch(typed, matchRegex, local$)){
				matched := true
				if (v.cond != "" && IsFunc(v.cond)){
					; If hotstring has a condition function.
					A_LoopCond := Func(v.cond)
					if (A_LoopCond.MinParams >= 1){
						; If the function has atleast 1 parameters.
						A_LoopRetVal := A_LoopCond.(v.mode == 3 ? local$ : local$.Value(0))
					} else {
						A_LoopRetVal := A_LoopCond.()
					}
					if (!A_LoopRetVal){
						; If the function returns a non-true value.
						matched := false
						continue
					}
				}
				if (v.clearTrigger){
					;Delete the trigger
					SendInput % "{BS " . StrLen(local$.Value(0))  . "}"
				}
				if (IsLabel(v.label)){
					$ := v.mode == 3 ? local$ : local$.Value(0)
					gosub, % v.label
				} else if (IsFunc(v.label)){
					callbackFunc := Func(v.label)
					if (callbackFunc.MinParams >= 1){
						callbackFunc.(v.mode == 3 ? local$ : local$.Value(0))
					} else {
						callbackFunc.()
					}
				} else {
					toSend := v.label

					;Working out the backreferences
					Loop, % local$.Count()
						StringReplace, toSend,toSend,% "$" . A_Index,% local$.Value(A_index),All
					toSend := RegExReplace(toSend,"([!#\+\^\{\}])","{$1}") ;Escape modifiers
					SendInput,%toSend%
				}

			}
		}
		if (matched){
			typed := ""
		} else if (StrLen(typed) > 350){
			StringTrimLeft,typed,typed,200
		}
	} else {
		if (hotstrings.HasKey(trigger) && label == ""){
			; Removing a hotstring.
			hotstrings.Delete(trigger)
		} else {
			; Add to hotstrings object.
			hotstrings[trigger] := {"trigger" : trigger, "label":label, "mode":mode, "clearTrigger" : clearTrigger, "cond": cond}
		}

	}
	return

	__hotstring:
	; This label is triggered every time a key is pressed.
	Hotstring("", "", "CALLBACK")
	return
}
exit(){
	ExitApp
}

^!r::
	Reload
return

^!x::
	suspend
return

^!q::
ExitApp
return

; OCR-driven report from current INFINITT viewport
^!b::
	gosub BMD_OCR_ManualTrigger
return

; Calibrate ROI rectangles for the current study's subtype
^!k::
	gosub BMD_OCR_CalibrateCurrent
return

; Calibrate ROI rectangles for a manually-picked subtype
^!+k::
	gosub BMD_OCR_CalibratePicker
return

; Seed DXA viewport ratios from hardcoded screen coordinates (local session only)
^!+n::
	BMD_SeedDXAFromScreenCoords()
return

; DXA OCR test: seed coords → show all 6 ROI frames → OCR → MsgBox with raw values
^!+t::
	BMD_DXA_OCR_Test()
return

; DXA OCR debug: OCR all fields + save PNG screenshots + log → opens debug_dxa folder
^!+g::
	BMD_DXA_OCR_Debug()
return

; DXA ALMI capture variants: save multiple capture/OCR methods for ROI debugging
^!+a::
	BMD_DXA_DebugAlmiCaptureVariants()
return

; ROI debug: show red frames + save captures + OCR for all DXA fields in INI
^!+h::
	BMD_OCR_DebugROI_DXA()
return

; ROI debug: show red frames + save captures + OCR for current study's BMD subtype
^!+e::
	try CH_RIS.refresh_info()
	dbgSub := BMD_DetectSubtype(CH_RIS.examname)
	if (dbgSub = "") {
		InputBox, dbgSub, ROI Debug, % "Subtype not detected. Enter manually:`n(lumbar / hip_r / hip_l / whole / sarco)",, 320, 130
		if (ErrorLevel || dbgSub = "")
			return
	}
	BMD_OCR_DebugROI_Subtype(dbgSub)
return

; DXA field calibration: pick a field → 2-click to draw ROI → saves ratio + test OCR
^!+c::
	global BMD_DXA_FIELD_DISPLAY
	choices := ""
	for k in BMD_DXA_FIELD_DISPLAY
		choices .= (choices = "" ? "" : "|") k
	InputBox, pick, DXA Field Calibration, % "Field to calibrate:`n(" choices ")`n`nEsc=abort  F2=skip during click",, 340, 170,,,,,lean_kg_g
	if (ErrorLevel || pick = "")
		return
	BMD_CalibrateDXAField(pick)
return

#ifwinactive,ahk_exe simpleRIS.exe
	F3::
		if (__is_N) {
			RisState := RisOpened()
			if (!sendButton || !controlexist(sendButton)) {
				sendButton := getNetControl2(RisState[2], "存檔發送", "cmdRunVerifySend", "存檔發送", "WindowsForms10.BUTTON.app", "", "", "", 0)[1]
			}
			controlclick,, % "ahk_id " sendButton
		} else if (__is_CH) {
			risSendReport(RisState[2], 3)
		}
	return
#IfWinActive

:*:dxa0::
	DXA_OCR_Trigger()
return

; ─────────────────────────────────────────────────────────────────────────
; DXA combined OCR — single "dxa" subtype reads all 5 numeric fields plus
; gender across two INFINITT viewports (2nd and 3rd physical displays).
; Local-session only; falls back to template paste on RDP or missing calibration.
; ─────────────────────────────────────────────────────────────────────────
DXA_OCR_Trigger() {
	global BMD_DXA_WRITTEN

	if IsCurrentSessionRDP() {
		DXA_PasteTemplate()
		return
	}

	ocr := BMD_DXA_OCR_ReadAll(true)
	if !IsObject(ocr) {
		DXA_PasteTemplate()
		return
	}
	if (ocr._missing.Length() > 0) {
		ToolTip, % "Missing DXA calibration: " BMD_JoinList(ocr._missing) "`nRun ^!+n to seed coords, or ^!K for manual calibration"
		Sleep, 2200
		ToolTip
		DXA_PasteTemplate()
		return
	}

	parsed := BMD_OCR_ToParsed(ocr)
	if !IsObject(parsed) {
		ToolTip, % "DXA OCR parse failed`nRaw: " BMD_OCR_DumpRaw(ocr)
		Sleep, 2000
		ToolTip
		DXA_PasteTemplate()
		return
	}

	; Confirm gender when OCR result is ambiguous
	if (!parsed.genderConfident) {
		InputBox, gInput, DXA — Patient Gender, % "OCR gender read: """ ocr.gender """`nEnter Male or Female:",, 300, 130
		if ErrorLevel {
			DXA_PasteTemplate()
			return
		}
		parsed.gender := (gInput ~= "i)^f") ? "female" : "male"
	}

	BMD_DXA_PromptSingleMissing(parsed)

	CH_RIS.check_wb()
	CH_RIS.refresh_info()
	result := BMD_BuildDXAReport(parsed, parsed.gender)
	if !IsObject(result) {
		DXA_PasteTemplate()
		return
	}
	BMD_WriteResult(result)
	BMD_DXA_WRITTEN := true
}

DXA_PasteTemplate() {
	t := "Body composition and bone mineral density of the whole body was performed with quantitative dual-energy X-ray absorptiometry.`n`nFindings:`n"
		. "- Total Body % fat: %`n"
		. "(overweight: male > 23%, female > 35%; obese: male > 25%, female > 38%)`n"
		. "- Total lean mass:  kg`n"
		. "- Appendicular lean mass index:  kg/m^2`n"
		. "(sarcopenia: male < 7 kg/m^2, female < 5.4 kg/m^2)`n"
		. "- The BMD of whole body is  g/cm2 (T-score = ).`n`n"
		. "Impression:`n"
		. "Normal BMD."
	clipboard := t
	send ^v
}
