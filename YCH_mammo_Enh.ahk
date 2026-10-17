#Hotstring ocZk-1
Process, Priority,, R
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance,force
SetBatchLines, -1
SetKeyDelay,-1,-1
coordMode,mouse,screen
coordMode,pixel,screen
coordMode,tooltip,screen
SetTitleMatchMode,2
setformat,float,0.2
SetControlDelay,-1
#SingleInstance,force
DetectHiddenWindows,on
comobjerror(false)
; Talk to the single CH_RIS owner (autorun) over IPC instead of creating our own
; IE-polling owner. Must be set before any include whose auto-exec calls getPlace (portallib
; / risimpax both can), which honours this flag. See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <portallib>
#include <risimpax>
#include <INFINITT_PACS>
#include <.netgetcontrol>
#include <ImpaxContextServer>
#include <resetHotstringBuffer>
#include <RegExSplit>
#include <WinGetList>
#include <JXON>
#include <MammoPdfDB>
#include %A_ScriptDir%\Lib\IsCurrentSessionRDP.ahk
resetHotstringBufferHook()

global MammoPdfDB_AutoShow := true
global Mammo_CH_ExpectedReport := ""
global Mammo_CH_FastReportCache := {ready: false, accNo: ""}
global MammoPdfDB_PollAccNo_Busy := false
global Mammo_CH_PreloadFastReportCache_Busy := false
global Mammo_ReportBuildBusy := false
global Mammo_PendingIndicationToggle := false
global Mammo_ReportReadyEdits := ""
global Mammo_ReportSyncDirty := false
global Mammo_IndicationSyncEdits := ""
global Mammo_IndicationSyncBusy := false
CloseOtherYCHAHK("YCH_MAMMO_AHK_main")
OnScreenDisplay("YCH MAMMO")
MammoPdfDB_RefreshAsync()  ; pick up any new screening PDFs dropped onto the share
; Mammo PDF DB lookup auto-opens for matching mammo RIS studies.
; SetTimer, MammoPdfDB_StartupSummary, -6000  ; OSD the parse summary once update.log catches up
SetTimer, MammoPdfDB_PollAccNo, 1000        ; IE web RIS study-change watcher (CH_RIS.accNo)

gosub openSimpleRIS
gosub RisGroup

global thisPlace:=getPlace()
OnMessage(0x10101,"Exit")
    ,OnMessage(0x10102,"win_a")
    ,OnMessage(0x10103,"_10103")
    ,OnMessage(0x10104,"_10104")
;~ for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name = 'Autorun.exe' and CommandLine like '%YCH%' and not CommandLine like '%" A_ScriptName "%' ")
;~ PostMessage,0x10103,,,,% "ahk_pid " process.ProcessId
;~ for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name like 'YCH%.exe'")
;~ if (process.ProcessId!=DllCall("GetCurrentProcessId"))
;~ PostMessage,0x10101,,,,% "ahk_pid " process.ProcessId

gui,new,+hwndmainguihwnd +LastFound
WinSetTitle,ahk_id %mainguihwnd%,,% "YCH_MAMMO_AHK_main"

#Hotstring EndChars -()[]{}:;"\,.?!`n `t
#Hotstring T
dynamic_hotstring("i)\bb0([usz]+?)([blr])\W","MB0",3,0)
dynamic_hotstring("i)\b([lrb])(m?)mc(i?)(\d)[\/ ]","CHmammoTitle",3,0)
    ,dynamic_hotstring("i)\b(\d{8}|\d{6})(r?)(\/|\.|\-)","insertDate",3,0)
    ;~ ,dynamic_hotstring("i)\b([blr])(\w+?)(s?)//","combineHotstring",3,0)
    ,dynamic_hotstring("i)\bop([lrb][ulc][oic])","opsite",3,0)
    ,dynamic_hotstring("i)\blocd?([lrb][ulc][oic])([gsrcn\W])","brloc",3,0)
    ,dynamic_hotstring("i)\bvab([lrb][ulc][oic])","vab",3,0)
    ,dynamic_hotstring("i)\b([rlb])([amp]?)([ulc])([oic])(b?)(\W)","Q",3,0)
    ,bullet:="- "

    ,brDen:=["The breasts are almost entirely fatty. (breast composition a) (1)","There are scattered areas of fibroglandular density. (breast composition b) (2)","The breasts are heterogeneously dense, which may obscure small masses. (breast composition c) (3)","The breasts are extremely dense, which lowers the sensitivity of mammography. (breast composition d) (4)"]

    ;~ sendmessage,0x10103,,,,ahk_exe autorun.exe
    ;~ msgbox % errorlevel
    ;~ exitapp

    ,thisHwnd:=WinExist("Ahk_PID " thisPid:=DllCall("GetCurrentProcessId"))
;~ if __is_N
RISImpaxRegister([ {app: "Ris", type: "AccNo", hwnd: thisHwnd, msg: {msg: 0x1122}, Func:"accNoChanged", initStart:100}
    , {app: "Ris", type: "State", hwnd: thisHwnd, msg: {msg: 0x8000}, func: "RisStateChange", initStart: 1}])
NoTrayOrphans()
    ,birads_category:={B0u: "BI-RADS category 0, indeterminate mammographic finding (need additional imaging evaluation), suggest breast ultrasound correlation.", B0m: "BI-RADS category 0, indeterminate mammographic finding (need additional imaging evaluation), suggest spot magnified view correlation.", B0t: "BI-RADS category 0, indeterminate mammographic finding (need additional imaging evaluation), suggest tomosynthesis correlation.", B1: "BI-RADS category 1, negative finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)", B2: "BI-RADS category 2, benign finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)", B3: "BI-RADS category 3, probably benign finding, suggest 6-month mammogram follow up. (If there is clinical relevant finding, ultrasound is suggested.)", B4: "BI-RADS category 4, suspicious malignant lesion. Suggest tissue proof.", B4a: "BI-RADS category 4A, low suspicion for malignancy. Suggest tissue proof.", B4b: "BI-RADS category 4B, moderate suspicion for malignancy. Suggest tissue proof.", B4c: "BI-RADS category 4C, high suspicion for malignancy. Suggest tissue proof.", B5: "BI-RADS category 5, highly suggestive of malignancy. Suggest tissue proof.", B6: "BI-RADS category 6, known biopsy-proven malignancy."}
    ,birads_category_us:={B1: "BI-RADS category 1, negative finding.", B2: "BI-RADS category 2, benign finding.", B3: "BI-RADS category 3, probably benign finding, suggest 6-month follow up.", B4: "BI-RADS category 4, suspicious malignant lesion. Suggest tissue proof.", B4a: "BI-RADS category 4A, low suspicion for malignancy. Suggest tissue proof.", B4b: "BI-RADS category 4B, moderate suspicion for malignancy. Suggest tissue proof.", B4c: "BI-RADS category 4C, high suspicion for malignancy. Suggest tissue proof.", B5: "BI-RADS category 5, highly suggestive of malignancy. Suggest tissue proof.", B6: "BI-RADS category 6, known biopsy-proven malignancy."}
menu, tray, icon,% a_scriptdir "\mammo.ico",1,0
monitors:=monitorInfo()
;~ WinMove,simple RIS ahk_class AutoHotkeyGUI,,% monitors.2.l+Floor(monitors.2.w/2)-505,% Floor(monitors.2.b/2)-155,
PostMessage,0x2022,,0,,simpleRIS_main ahk_class AutoHotkeyGUI
PostMessage,0x2025,1,,,simpleRIS_main ahk_class AutoHotkeyGUI
;~ PostMessage,0x2030,,,,simpleRIS__main ahk_class AutoHotkeyGUI

gosub sethotkey
WinHide,miniPACS Main ahk_class AutoHotkeyGUI

if InStr(A_OSVersion, "10."){
    try
    run,% A_ScriptDir "\win10hook.exe",,Hide
}

GroupAdd,PacsViewer,ahk_exe impax-client-main.exe
GroupAdd,PacsViewer,ahk_exe WebViewerComSrvEC.exe
GroupAdd,PacsViewer,ahk_exe WEBVIE~1.EXE
GroupAdd,PacsViewer,ahk_exe Miv2Lib.exe
;~ GroupAdd,PacsViewer,ahk_exe G3PACS.exe

if __is_CH {
    CH_RIS.AddAccNoChangedHookFn(Func("ShowLastBirads"))
    CH_RIS.AddAccNoChangedHookFn(Func("BreastUSOCR_OnAccNoChanged"))
    CH_RIS.AddAccNoChangedHookFn(Func("Mammo_CH_ScheduleFastReportPreload"))
    SetTimer, Mammo_CH_PreloadFastReportCache, -2500
    SetTimer, BreastUSOCR_CheckCurrentStudy, -2500
}
settimer,ShowLastBirads,-1500

return

win_a(w,l,m,h){
    settimer,% (l?"+":"") "#a",-1
}
_10103(){
    gosub _10103
}
_10104(w,l,m,h){
    if w=0
        gosub _+#m
    else if w=1
        gosub _+#left
    else if w=2
        gosub _+#right
}
Exit(){
    Exitapp
}

Q:
    send % "{bs " StrLen($.value(0))  "}"
    sendByClipboard(brQ(SubStr($.value(0),1,-1)) SubStr($.value(0),0,1))
return

opsite:
    send % "{bs " StrLen($.value(0))  "}"
    sendByClipboard("Focal parenchymal loss, architectural distortion and skin retraction are noted at " brQ($.value(1)) " under the wire, compatible with post-operative change.")
return

brQ(str){
    static side:={l:"left", r:"right", b:"bilateral"}
    static depth:={a: "anterior", m: "middle", p: "posterior"}
    static quadrant:={u:"upper", l:"lower", o:"outer", i:"inner", c:"central"}
    ret:=side[SubStr(str,1,1)] " "
        ,i:=2
    if (SubStr(str,i,1)~="i)[amp]")
        ret.=depth[SubStr(str,i,1)] " "
            , i++

    if InStr(str, "c"){
        ret.= quadrant[SubStr(str,i,1)] " " quadrant[SubStr(str,i+1,1)]
    }else{
        StringUpper,str,str
        ret.= SubStr(str,i,2) "Q"
    }

    if SubStr(str,0,1)="b" ||  InStr(str, "c")
        ret.=" breast"

    return ret

}

Mammo_SimpleRisHotkeyEditHwnds(){
    activeEdit := ""
    if WinActive("ahk_group SimpleRisHotkeys") {
        ; Prefer the report control over an unrelated focused Edit (search,
        ; accession, etc.) in the same SimpleRIS window.
        ControlGet, activeEdit, Hwnd,, Scintilla1, A
        if !ControlExists(activeEdit) {
            ControlGet, activeEdit, Hwnd,, Edit1, A
        }
    }
    if ControlExists(activeEdit)
        return [activeEdit, activeEdit]
    editHwnds := getSimpleRisEditHwnds()
    if IsObject(editHwnds) && ControlExists(editHwnds[2])
        return editHwnds
    return []
}

Mammo_ToggleSimpleRisIndication(editHwnds:=""){
    global __is_CH, __is_N

    if !IsObject(editHwnds)
        editHwnds:=Mammo_SimpleRisHotkeyEditHwnds()
    if !IsObject(editHwnds) || !editHwnds.length() || !ControlExists(editHwnds[2])
        return false
    Text:=Edit_GetText(editHwnds[2])
    changed:=false
    if (__is_N){
        if (matched:=RegExMatch(Text, "i)(bilateral|left|right) (mlo|cc)", match)){
            PostMessage,0x2023,1000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
            Edit_GetSel(editHwnds[2],s,e)
                ,Edit_SetText(editHwnds[2],newText:=SubStr(Text,1,matched+StrLen(match1)) "magnified " SubStr(Text,matched+StrLen(match1)+1))
                ,Edit_SetText(editHwnds[1],newText)
                ,Edit_SetSel(editHwnds[2],s+10,e+10)
                ,Edit_SetSel(editHwnds[1],s+10,e+10)
                ,changed:=true
        }
    }else if(__is_CH){
        if RegExMatch(Text, "is)(INDICATION:\s*)(diagnostic|screening)( mammography\.?)", match){
            newInd := (match2="screening" ? "diagnostic" : "screening")
            Text := RegExReplace(Text, "is)INDICATION:\s*(diagnostic|screening) mammography\.?", "INDICATION: " newInd " mammography.")
        } else if RegExMatch(Text, "is)INDICATION:([^\r\n]*)", match) {
            Text := RegExReplace(Text, "is)INDICATION:[^\r\n]*", "INDICATION: screening mammography.")
        } else {
            Text := "INDICATION: screening mammography.`r`n" . Text
        }
        Edit_SetText(editHwnds[2],Text)
        if (editHwnds[1] != editHwnds[2] && ControlExists(editHwnds[1]))
            Edit_SetText(editHwnds[1],Text)
        if (Edit_GetText(editHwnds[2]) != Text)
            return false
        Edit_SetSel(editHwnds[2], -1, -1)
        changed:=true
    }
    return changed
}

Mammo_RequestSimpleRisIndicationToggle(){
    global __is_CH, CH_RIS, Mammo_ReportBuildBusy, Mammo_PendingIndicationToggle
    global Mammo_ReportReadyEdits, Mammo_ReportSyncDirty
    global Mammo_IndicationSyncEdits

    if (__is_CH && Mammo_ReportBuildBusy){
        if IsObject(Mammo_ReportReadyEdits) {
            ; The visible report is complete. Change it now, even if the
            ; builder is awaiting an older RIS reply; it will sync again.
            if Mammo_ToggleSimpleRisIndication(Mammo_ReportReadyEdits)
                Mammo_ReportSyncDirty:=true
        } else {
            ; Only construction needs a deferred toggle.
            Mammo_PendingIndicationToggle:=!Mammo_PendingIndicationToggle
        }
        return
    }
    editHwnds:=Mammo_SimpleRisHotkeyEditHwnds()
    if Mammo_ToggleSimpleRisIndication(editHwnds) {
        if (__is_CH && IsObject(CH_RIS)) {
            ; Finish the key thread before any owner IPC wait. Otherwise
            ; AHK's one-thread-per-hotkey default drops subsequent Ctrl+M
            ; presses for the entire impression lookup + flush timeout.
            Mammo_IndicationSyncEdits:=editHwnds
            SetTimer, Mammo_SyncIndicationReport, -100
        }
    } else {
        OnScreenDisplay("Mammography: cannot edit indication; check the SimpleRIS report editor.")
    }
}

Mammo_SyncIndicationReport(){
    global Mammo_IndicationSyncEdits, Mammo_IndicationSyncBusy, Mammo_ReportBuildBusy

    if Mammo_IndicationSyncBusy
        return
    ; A new report builder owns its final sync; never send an older edit.
    if Mammo_ReportBuildBusy {
        Mammo_IndicationSyncEdits:=""
        return
    }
    if !IsObject(Mammo_IndicationSyncEdits)
        return
    editHwnds:=Mammo_IndicationSyncEdits
    Mammo_IndicationSyncEdits:=""
    Mammo_IndicationSyncBusy:=true
    try {
        Mammo_FlushReport(editHwnds)
    } finally {
        Mammo_IndicationSyncBusy:=false
        if IsObject(Mammo_IndicationSyncEdits)
            SetTimer, Mammo_SyncIndicationReport, -100
    }
}

Mammo_NotifyPriorHistory(historyHwnd){
    ; This optional viewer may be absent or close between lookup and posting.
    ; Its notification must not abort construction or the final RIS sync.
    if !historyHwnd
        return false
    try {
        PostMessage,0x2030,,,,% "ahk_id " historyHwnd
        return !ErrorLevel
    } catch e {
        return false
    }
}

Mammo_FlushReport(editHwnds, preserveSeparateImpression:=true){
    global CH_RIS, __is_CH, __CH_RIS_CLIENT
    if (__is_CH){
        if !IsObject(editHwnds) || !ControlExists(editHwnds[2])
            return false
        ; flush() reads the owner's edits, not the SimpleRIS Scintilla control.
        ; Transfer the completed text explicitly instead of racing update1.
        reportText:=Edit_GetText(editHwnds[2])
        report:=new ReportImpression(reportText)
        ; bmc3 can set BI-RADS directly in the owner's separate impression
        ; field while its new Scintilla text contains only the findings.
        if (preserveSeparateImpression && !RegExMatch(reportText, "i)(Impression:|IMP:)"))
            report.impression:=CH_RIS.impression
        if (__CH_RIS_CLIENT){
            flushError:=CH_RIS_FlushReplyError(CH_SetAndFlush(report.exam, report.impression))
        } else {
            CH_RIS.exam:=report.exam
            CH_RIS.impression:=report.impression
            flushError:=CH_RIS.flush()
        }
    } else {
        flushError:=CH_RIS.flush()
    }
    if flushError
        OnScreenDisplay("Mammography: RIS sync failed (" flushError "). Please check the report in RIS.")
    return !flushError
}

Mammo_ApplyPendingIndicationToggle(editHwnds, buildAccNo){
    global __is_CH, Mammo_PendingIndicationToggle

    Critical
    if (!__is_CH || !Mammo_PendingIndicationToggle){
        Critical, Off
        return false
    }
    Mammo_PendingIndicationToggle:=false
    Critical, Off
    ; A queued key belongs to the report being built, not whichever editor
    ; happens to have focus when the RIS call finishes.
    if (buildAccNo = "" || Mammo_CH_GetAccNoQuick(300) != buildAccNo){
        OnScreenDisplay("Mammography: study changed or unavailable; indication toggle cancelled.")
        return false
    }
    return Mammo_ToggleSimpleRisIndication(editHwnds)
}

; Use the native window condition for the editor: it does not need the
; script's main thread to evaluate an expression during a blocking RIS call.
#IfWinActive,ahk_group MammoIndicationHotkeys
    $!j::
    $!m::
    $^m::
        Mammo_RequestSimpleRisIndicationToggle()
        ; One toggle per physical press, even when a key is held down.
        KeyWait, % SubStr(A_ThisHotkey, 0)
    return
#If

#IfWinActive,ahk_group SimpleRisHotkeys
    ^k::
        editHwnds:=Mammo_SimpleRisHotkeyEditHwnds()
        if !editHwnds.length()
            return
        Text:=Edit_GetText(editHwnds[2])
        if (__is_CH){
            ; Replace the specific string as requested
            newText := StrReplace(Text, "(V) (The findings are roughly unchanged.)", "(V)")
            if (newText != Text) {
                Edit_SetText(editHwnds[2], newText)
                Edit_SetText(editHwnds[1], newText)
                Edit_SetSel(editHwnds[2], -1, -1)
            }
        }
    return

    ^i::
        editHwnds:=Mammo_SimpleRisHotkeyEditHwnds()
        Text:=Edit_GetText(editHwnds[2])
        if (matched:=RegExMatch(Text, "i)and (bilateral|left|right) magnified mlo\/cc", match)){
            PostMessage,0x2023,1000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
            Edit_GetSel(editHwnds[2],s,e)
                ,Edit_SetText(editHwnds[2],newText:=RegExReplace(Text, "i)and (bilateral|left|right) magnified mlo\/cc", "II/ID", "", 1))
                ,Edit_SetText(editHwnds[1],newText)
                ,Edit_SetSel(editHwnds[2], s<matched+StrLen(match)?s:s- StrLen(match)+5, e<matched+StrLen(match)?e:e- StrLen(match)+5)
                ,Edit_SetSel(editHwnds[1], s<matched+StrLen(match)?s:s- StrLen(match)+5, e<matched+StrLen(match)?e:e- StrLen(match)+5)
        }
    return

    ^o::
        editHwnds:=Mammo_SimpleRisHotkeyEditHwnds()
        Text:=Edit_GetText(editHwnds[2])
        if (matched:=RegExMatch(Text, "i)are read without prior mammograms available for comparison.", match)){
            PostMessage,0x2023,1000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
            Edit_GetSel(editHwnds[2],s,e)
                ,Edit_SetText(editHwnds[2],newText:=RegExReplace(Text, "i)are read without prior mammograms available for comparison."
                , "are read and compared with prior mammograms dated ", "", 1))
                ,Edit_SetText(editHwnds[1],newText)
                ,Edit_SetSel(editHwnds[2], s:=matched+StrLen("are read and compared with prior mammograms dated"), s)
                ,Edit_SetSel(editHwnds[1], s, s)
        }
    return
#IfWinActive

;~ #IfWinExist,__maskImpaxLoading ahk_class AutoHotkeyGUI
_10103:
#v::
    winactivate,% "ahk_id " impaxopened()[2,1]
    winwaitactive,% "ahk_id " impaxopened()[2,1],,1
    ;~ if !Winvisible(WinExist("__maskImpaxLoading ahk_class AutoHotkeyGUI")){
    ;~ gosub zoomAll
    ;~ }
    MouseMove,% monitors[2].l+Floor(monitors[2].w/2),% monitors[2].t+Floor(monitors[2].h/2),0
    __maskImpaxClose()
    ;~ winactivate,% "ahk_id " impaxopened()[2,1]
    if (priorDate="" && !priorPacsHxDate.length()){
        send % "{Numpad2}"
    }else{
        send % "{Numpad5}"
    }
return
;~ #IfWinExist

sethotkey:
    hotkey,ifwinactive,ahk_group PacsViewer
    replaceKeys:="23sdmgf"
    Loop,parse,replaceKeys
        hotkey,% A_LoopField,~%a_loopfield%,on
    Hotkey,g up,~g_up,on
    hotkey,IfWinActive
return

#ifwinactive,ahk_group PacsViewer

        ~2:
        send % "{Numpad2}"
        return
        ~3:
        send % "{Numpad5}"
        return

        ~s:
        send % "{Left}"
        return
        ~d:
        send % "{Right}"
        return

        ~m:
        ; ~!m::
        ; ~^m::
        send % "z"
        return

        ~g:
        if !GetKeyState("Lbutton")
            send % "{LButton Down}"
        return

        ~g_up:
        send % "{lbutton up}"
        return

        zoomAll:
                ~f:
                +d::
                +s::
                +#left::
                +#right::
                +Left::
                +right::
                +m::
                +#m::
                _+#left:
                _+#right:
                _+#m:
                    WinHide,% "ahk_id " getSimpleRisGuiHwnds[2]

                    sysget,mon1,monitor,% monitors.1.ind
                    sysget,mon2,monitor,% monitors.2.ind
                    sysget,mon3,monitor,% monitors.3.ind
                    sysget,monC,monitorcount
                    ;~ mousegetpos,ox,oy
                    key:=RegExReplace(a_thishotkey,"\W","")
                    if key=d
                        key=Right
                    else if key=s
                        key=Left
                    if key=f
                        key=m

                    if (monC=1) {
                        mousemove,% ox:=Floor((mon1right-mon1left)/4*1),% oy:=Floor(mon1bottom/2),2
                        send % "{" key "}"
                        mousemove,% Floor((mon1right-mon1left)/4*3),% Floor(mon1bottom/2),2
                        send % "{" key "}"
                    }else{
                        mousemove,% ox:=Floor(mon1right+(mon2right-mon2left)/4*1),% oy:=Floor(mon2bottom/2),2
                        send % "{" key "}"
                        mousemove,% Floor(mon1right+(mon2right-mon2left)/4*3),% Floor(mon2bottom/2),2
                        send % "{" key "}"

                        if (monC=3){
                            mousemove,% Floor(mon2right+(mon3right-mon3left)/4*1),% Floor(mon2bottom/2),2
                            send % "{" key "}"
                            if !instr(a_thishotkey,"#") {
                                mousemove,% Floor(mon2right+(mon3right-mon3left)/4*3),% Floor(mon2bottom/2),2
                                send % "{" key "}"
                            }
                        }
                    }
                    send % "{z}"
                    ;~ Sleep 500
                    ;~ ToolTip % ox "," oy
                    if (!ox || !oy)
                        ox:=Floor(mon1right+(mon2right-mon2left)/4*1), oy:=Floor(mon2bottom/2)
                    mousemove,% ox,% oy,0
                    Sleep 300
                    MouseGetPos,x,y
                    if(Abs(x-ox)>500 || Abs(y-oy)>500)
                        mousemove,% ox,% oy,0
                return

            #ifwinactive

            #if BreastUSOCR_ShouldRightActivateRIS()
                $Right::
                    if BreastUSOCR_IsCurrentStudy()
                        BreastUSOCR_ActivateRisStudyPage()
                    else
                        Send, {Right}
                return
            #if

            #Hotstring, SI

            :B0:bc::
                sendByClipboard("breast cancer" A_EndChar,2)
            return
            :B0:pm::
                sendByClipboard("partial mastectomy" A_EndChar,2)
            return

            :o:fm::
                {
                    sendByClipboard("family history of breast cancer ()." "")
                    send % "{left 2}"
                }
            return

            :B0:bctr::
                sendByClipboard("Breast cancer s/p right BCT" A_EndChar,4)
            return
            :B0:bctl::
                sendByClipboard("Breast cancer s/p left BCT" A_EndChar,4)
            return
            :B0:sbr::
                sendByClipboard("s/p right BCT with scar in" A_EndChar,3)
            return
            ::sbrn::
                {
                    sendByClipboard("s/p right BCT with scar in No definite local recurrence.")
                    send % "^{left}"
                    send % "^{left}"
                    send % "^{left}"
                    send % "^{left}"
                }
                sendByClipboard(A_EndChar)
            return
            :B0:sbl::
                sendByClipboard("s/p left BCT with scar in" A_EndChar,3)
            return
            ::sbln::
                {
                    sendByClipboard("s/p left BCT with scar in No definite local recurrence.")
                    send % "^{left}"
                    send % "^{left}"
                    send % "^{left}"
                    send % "^{left}"
                }
                sendByClipboard(A_EndChar)
            return
            :B0:mr::
                sendByClipboard("Breast cancer s/p right modified radical mastectomy" A_EndChar,2)
            return
            :B0:ml::
                sendByClipboard("Breast cancer s/p left modified radical mastectomy" A_EndChar,2)
            return
            :B0:smr::
                sendByClipboard("s/p right modified radical mastectomy" A_EndChar,3)
            return
            :B0:smrn::
                sendByClipboard("s/p right modified radical mastectomy. No definite local recurrence" A_EndChar,4)
            return
            :B0:sml::
                sendByClipboard("s/p left modified radical mastectomy" A_EndChar,3)
            return
            :B0:smln::
                sendByClipboard("s/p left modified radical mastectomy. No definite local recurrence" A_EndChar,4)
            return

            :B0:r::
                sendByClipboard("right" A_EndChar,1)
            return
            :B0:l::
                sendByClipboard("left" A_EndChar,1)
            return
            :B0:bi::
                sendByClipboard("bilateral" A_EndChar,2)
            return

            :B0:red::
                sendByClipboard("are read and compared with prior mammograms dated" A_EndChar,3)
            return
            :B0:redn::
                sendByClipboard("are read without prior mammograms available for comparison.`n- " A_EndChar,4)
            return

            :o*:hsm1::
            :o*:hsm2::
            :o*:hsm3::
            :o*:hsm4::
                num:=substr(a_thishotkey,0,1)
            :o:hsm::
                resetReports()
                Sleep 300
                sendByClipboard("History: screening mammogram.`n`n")
                gosub dt_
            return

            :o*:rbct1::
            :o*:rbct2::
            :o*:rbct3::
            :o*:rbct4::
                num:=substr(a_thishotkey,0,1)
            :o:rbct::
                resetReports()
                Sleep 300
                sendByClipboard("History: breast cancer s/p right BCT.`n`n")
                gosub dt_
            return

            :o*:lbct1::
            :o*:lbct2::
            :o*:lbct3::
            :o*:lbct4::
                num:=substr(a_thishotkey,0,1)
            :o:lbct::
                resetReports()
                Sleep 300
                sendByClipboard("History: breast cancer s/p left BCT.`n`n")
                gosub dt_
            return

            :o*:bbct1::
            :o*:bbct2::
            :o*:bbct3::
            :o*:bbct4::
                num:=substr(a_thishotkey,0,1)
            :o:bbct::
                resetReports()
                Sleep 300
                sendByClipboard("History: breast cancer s/p bilateral BCT.`n`n")
                gosub dt_
            return

            :o*:rmrm1::
            :o*:rmrm2::
            :o*:rmrm3::
            :o*:rmrm4::
                num:=substr(a_thishotkey,0,1)
            :o:rmrm::
                resetReports()
                Sleep 300
                sendByClipboard("History: breast cancer s/p right mastectomy.`n`n")
                gosub dt_
            return

            :o*:lmrm1::
            :o*:lmrm2::
            :o*:lmrm3::
            :o*:lmrm4::
                num:=substr(a_thishotkey,0,1)
            :o:lmrm::
                resetReports()
                Sleep 300
                sendByClipboard("History: breast cancer s/p left mastectomy.`n`n")
                gosub dt_
            return

            :o*:hfh::
                {
                    sendByClipboard("History: family history of breast cancer ()" "")
                    send % "{left}"
                }
            return
            :o*B0:hrl::
                sendByClipboard("History: right breast lump.`n`n",2)
            return
            :o*B0:hll::
                sendByClipboard("History: left breast lump.`n`n",2)
            return
            :o*B0:hbl::
                sendByClipboard("History: bilateral breast lumps.`n`n",2)
            return
            :o*B0:hfu::
                sendByClipboard("History: follow up.`n`n",2)
            return
            :o*B0:hrb::
                sendByClipboard("History: right breast benign lesion status post operation/biopsy.`n`n",2)
            return
            :o*B0:hlb::
                sendByClipboard("History: left breast benign lesion status post operation/biopsy.`n`n",2)
            return
            :o*B0:hbb::
                sendByClipboard("History: bilateral breast benign lesion status post operation/biopsy.`n`n",2)
            return

            :B0:bmc::
                sendByClipboard("Bilateral MLO/CC digital mammograms are read and compared with prior mammograms dated" A_EndChar,3)
            return
            :B0:bmmc::
                sendByClipboard("Bilateral magnified MLO/CC digital mammograms are read and compared with prior mammograms dated" A_EndChar,4)
            return
            :B0:bmcn::
                sendByClipboard("Bilateral MLO/CC digital mammograms are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar,4)
            return
            :B0:bmci::
                sendByClipboard("Bilateral MLO and CC II/ID views are read and compared with prior mammograms dated" A_EndChar,4)
            return
            :B0:bmcin::
                sendByClipboard("Bilateral MLO and CC II/ID views are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar,5)
            return

            :B0:rmc::
                sendByClipboard("Right MLO/CC digital mammograms are read and compared with prior mammograms dated" A_EndChar,3)
            return
            :B0:rmcn::
                sendByClipboard("Right MLO/CC digital mammograms are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar,4)
            return
            :B0:rmci::
                sendByClipboard("Right MLO and CC II/ID views are read and compared with prior mammograms dated" A_EndChar,4)
            return
            :B0:rmcin::
                sendByClipboard("Right MLO and CC II/ID views are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar,5)
            return

            :B0:lmc::
                sendByClipboard("Left MLO/CC digital mammograms are read and compared with prior mammograms dated" A_EndChar,3)
            return
            :B0:lmcn::
                sendByClipboard("Left MLO/CC digital mammograms are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar,4)
            return
            :B0:lmci::
                sendByClipboard("Left MLO and CC II/ID views are read and compared with prior mammograms dated" A_EndChar,4)
            return
            :B0:lmcin::
                sendByClipboard("Left MLO and CC II/ID views are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar,5)
            return

            :o*:op=::
                {
                    sendByClipboard("Focal parenchymal loss, architectural distortion and skin retraction are noted at breast under the wire, compatible with post-operative change.")
                    send % "^{left 12}"
                }
            return

            :*B0:cal0::
                sendByClipboard("There are benign scattered calcifications present.",3)
            return
            :oB0:bcal::
                sendByClipboard("There are benign scattered calcifications present bilaterally.`n- ",4)
            return
            :oB0:bcalv::
                sendByClipboard("There are benign appearing vascular wall calcifications in bilateral breasts.`n- ",5)
            return
            :oB0:lcal::
                sendByClipboard("There are benign scattered calcifications present in left breast.`n- ",4)
            return
            :oB0:lcalv::
                sendByClipboard("There are benign appearing vascular wall calcifications in left breast.`n- ",5)
            return
            :oB0:rcal::
                sendByClipboard("There are benign scattered calcifications present in right breast.`n- ",4)
            return
            :oB0:rcalv::
                sendByClipboard("There are benign appearing vascular wall calcifications in right breast.`n- ",5)
            return

            :B0:neg::
                sendByClipboard("There are no definite mass, no suspicious microcalcifications, and no architectural distortion in this study.`r`n- No definite axillary lymphadenopathy." A_EndChar,3)
            return
            :B0:negc::
                sendByClipboard("There are no definite mass and no architectural distortion in this study.`r`n- No definite axillary lymphadenopathy." A_EndChar,4)
            return
            :B0:negm::
                sendByClipboard("There are no definite mass in this study.`r`n- No definite axillary lymphadenopathy." A_EndChar,4)
            return

            :oc1:b0u::
            :oc1:b0m::
            :oc1:b0t::
            :oc1:b1::
            :oc1:b2::
            :oc1:b3::
            :oc1:b4::
            :oc1:b4a::
            :oc1:b4b::
            :oc1:b4c::
            :oc1:b5::
            :oc1:b6::
            :oc1:b0uk::
            :oc1:b0mk::
            :oc1:b0tk::
            :oc1:b1k::
            :oc1:b2k::
            :oc1:b3k::
            :oc1:b4k::
            :oc1:b4ak::
            :oc1:b4bk::
            :oc1:b4ck::
            :oc1:b5k::
            :oc1:b6k::

            :oc1:ub0u::
            :oc1:ub0m::
            :oc1:ub0t::
            :oc1:ub1::
            :oc1:ub2::
            :oc1:ub3::
            :oc1:ub4::
            :oc1:ub4a::
            :oc1:ub4b::
            :oc1:ub4c::
            :oc1:ub5::
            :oc1:ub6::
            :oc1:ub0uk::
            :oc1:ub0mk::
            :oc1:ub0tk::
            :oc1:ub1k::
            :oc1:ub2k::
            :oc1:ub3k::
            :oc1:ub4k::
            :oc1:ub4ak::
            :oc1:ub4bk::
            :oc1:ub4ck::
            :oc1:ub5k::
            :oc1:ub6k::

                gosub sendBirads
            return

            sendBirads:
                hwnd:=getFocusedHWND()
                RegExMatch(a_thishotkey, "(u?)(\w+?)(k?)$", thishotkey)
                thisBirads:=thishotkey2 thishotkey3
                thisBirads1:=thishotkey2
                if !thisBirads || !birads_category.haskey(thisBirads1)
                    return
                if InStr(thisPlace, "N hospital"){
                    PostMessage,0x2020,,,,simpleRIS_main ahk_class AutoHotkeyGUI
                    if (hwnd)=getRisReports()[1,2]
                        Edit_SetText(hwnd, "")
                    Sleep 500
                    setReportText("", birads_category[thisBirads1], "", -1, false)

                }else if InStr(thisPlace, "C hospital"){
                    ;~ MsgBox % A_ThisHotkey
                    ;~ ExitApp
                    if (thishotkey3=""){
                        CH_RIS.impression:=""
                        Text:=RegExReplace(Edit_GetText(hwnd), "-\s*$", "")
                        if !InStr(Text, "Impression:")
                            Text.="`r`n`r`nImpression: `r`n"
                        Edit_SetText(hwnd, Text)
                        Edit_SetSel(hwnd, l:=StrLen(Text), l)
                    }
                    hk:=thisBirads1
                    birads_text:=thishotkey1?birads_category_us[thisBirads1]:birads_category[thisBirads1]

                    sendByClipboard(birads_text, 0, thishotkey1 hk)
                }

                if (thishotkey3!="k"){
                    thisHotkey:="F3"
                    gosub sendReport1
                }
            return

            :oc:b22::
            _b22:
                editHwnds:=getSimpleRisEditHwnds()
                    ,oldFindings:=Edit_GetText(editHwnds[2])
                findings=
(
- There are benign calcification(s).
- There are no definite mass and no architectural distortion in this study.
- No definite axillary lymphadenopathy.
)
                findings:=RegExReplace(oldFindings, "i)(\r?\n)(- )?(b22)?\s*$", "$1") findings
                    ,impression:="BI-RADS category 2, benign finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)"
                gosub fastsend
            return

            :oc:b11::
            _b11:
                editHwnds:=getSimpleRisEditHwnds()
                    ,oldFindings:=Edit_GetText(editHwnds[2])
                findings=
(
- There are no definite mass, no suspicious microcalcifications, and no architectural distortion in this study.
- No definite axillary lymphadenopathy.
)
                findings:=RegExReplace(oldFindings, "i)(\r?\n)(- )?(b11)?\s*$", "$1") findings
                    ,impression:="BI-RADS category 1, negative finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)"
                gosub fastsend
            return

            fastSend:
                findings:=RegExReplace(findings, "i)- B\d* *- ", "- ")
                    ,editHwnds:=getSimpleRisEditHwnds()
                    ,Edit_SetText(editHwnds[2], findings (__is_CH?"`r`n`r`nImpression:`r`n" impression:""))
                    ,Edit_SetText(editHwnds[1], findings (__is_CH?"`r`n`r`nImpression:`r`n" impression:""))
                if __is_CH
                    setReportText(findings, impression, "",  1, 1, 0, 0)
                else if __is_N
                    setReportText(findings, impression, "",  1)
                if __is_N
                    Sleep 500
                gosub F3
                if(simpleRis:=WinExist("simple RIS ahk_class AutoHotkeyGUI")){

                    PostMessage,0x2023,1000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
                    ;~ Edit_SetText(EditHwnd, "")
                    ;~ resetSimpleRis()
                    setTimerF("resetSimpleRis", -1000)
                }
            return

            :oB0:b0u::
                sendByClipboard("BI-RADS category 0, indeterminate mammographic finding (need additional imaging evaluation), suggest breast ultrasound correlation.",3)
            return
            :oB0:b0m::
                sendByClipboard("BI-RADS category 0, indeterminate mammographic finding (need additional imaging evaluation), suggest spot magnified view correlation.",3)
            return
            :oB0:b1::
                sendByClipboard("BI-RADS category 1, negative finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)",2)
            return
            :oB0:b2::
                sendByClipboard("BI-RADS category 2, benign finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)",2)
            return
            :oB0:b3::
                sendByClipboard("BI-RADS category 3, probably benign finding, suggest 6-month mammogram follow up. (If there is clinical relevant finding, ultrasound is suggested.)",2)
            return
            :oB0:b4::
                sendByClipboard("BI-RADS category 4, suspicious malignant lesion. Suggest tissue proof.",2)
            return
            :oB0:b4a::
                sendByClipboard("BI-RADS category 4A, low suspicion for malignancy. Suggest tissue proof.",3)
            return
            :oB0:b4b::
                sendByClipboard("BI-RADS category 4B, moderate suspicion for malignancy. Suggest tissue proof.",3)
            return
            :oB0:b4c::
                sendByClipboard("BI-RADS category 4C, high suspicion for malignancy. Suggest tissue proof.",3)
            return
            :oB0:b5::
                sendByClipboard("BI-RADS category 5, highly suggestive of malignancy. Suggest tissue proof.",2)
            return
            :oB0:b6::
                sendByClipboard("BI-RADS category 6, known biopsy-proven malignancy.",2)
            return

            :B0:m6::
                sendByClipboard("suggest 6-month follow up." A_EndChar,2)
            return
            :B0:mvc::
                sendByClipboard("suggest magnified view correlation. " A_EndChar,3)
            return
            :B0:svc::
                sendByClipboard("suggest spot view correlation." A_EndChar,3)
            return

            :b0:md1::
            :b0:md2::
            :b0:md3::
            :b0:md4::
                sendByClipboard(brDen[den:=substr(a_thishotkey,0,1)], 3)
                den:=""
            return

            :B0:iml::
                sendByClipboard("There are left retro-pectoral saline implants, with smooth surface without evidence of rupture." A_EndChar,3)
            return
            :B0:imr::
                sendByClipboard("There are right retro-pectoral saline implants, with smooth surface without evidence of rupture." A_EndChar,3)
            return
            :B0:imb::
                sendByClipboard("There are bilateral retro-pectoral saline implants, with smooth surface without evidence of rupture." A_EndChar,3)
            return

            :B0:ibb::
                sendByClipboard("in bilateral breasts" A_EndChar,3)
            return
            :B0:irb::
                sendByClipboard("in right breast" A_EndChar,3)
            return
            :B0:ilb::
                sendByClipboard("in left breast" A_EndChar,3)
            return
            :B0:bb::
                sendByClipboard("bilateral breasts" A_EndChar,2)
            return
            :B0:rb::
                sendByClipboard("right breast" A_EndChar,2)
            return
            :B0:lb::
                sendByClipboard("left breast" A_EndChar,2)
            return

            :B0:lj::
                sendByClipboard("(YCH/Dr.B)" A_EndChar,2)
            return
            :B0:clin::
                sendByClipboard("( if there is clinical relevant finding, ultrasound is suggested. )" A_EndChar,4)
            return

            :B0:fa::
                sendByClipboard("fibroadenoma" A_EndChar,2)
            return
            :*B0:fa1::
                sendByClipboard("fibroadenomas",2)
            return
            :B0:fcc::
                sendByClipboard("fibrocystic change" A_EndChar,3)
            return
            :B0:fhx::
                sendByClipboard("family history of breast cancer (sister/mother/grandmother)," A_EndChar,3)
            return

            :B0:lnr::
                sendByClipboard("benign appearing node at right axilla, size , having fat hilum." A_EndChar,3)
            return
            :B0:lnl::
                sendByClipboard("benign appearing node at left axilla, size , having fat hilum." A_EndChar,3)
            return
            :B0:mags::
                sendByClipboard("spot magnification views" A_EndChar,4)
            return
            :B0:mag::
                sendByClipboard("magnified" A_EndChar,3)
            return
            :B0:masy::
                sendByClipboard("Focal asymmetry is noted at right anterior UOQ near central, suggest ultrasound or mag. views." A_EndChar,4)
            return

            :B0:mmic::
                sendByClipboard("There are two clusters of pleomorphic to amorphous microcalcifications at right UOQ, suggest biopsy." A_EndChar,4)
            return
            :B0:mmic2::
                sendByClipboard("There are segmentally to regionally distributed microcalcifications at the UOQ left breast with probably benign appearance." A_EndChar,5)
            return

            :B0:mop2::
                sendByClipboard("Focal architectural distortion, parenchymal retraction is noted at right UOQ under the wire and focal asymmetry near the surgical bed." A_EndChar,4)
            return
            :B0:mop3::
                sendByClipboard("Post-op. changes at left UIQ breast with parenchymal loss, architectural deformity, skin retraction and thickening." A_EndChar,4)
            return

            :B0:msug::
                sendByClipboard("suggest breast ultrasound correlation and right mag. views." A_EndChar,4)
            return
            :B0:np::
                sendByClipboard("No definite focal mass lesion. Suggest follow-up." A_EndChar,2)
            return
            :B0:pl::
                sendByClipboard("pleomorphic" A_EndChar,2)
            return

            :B0:sar::
                sendByClipboard("subareolar region" A_EndChar,3)
            return
            :B0:sfufna::
                sendByClipboard("Suggest follow up and considered FNA if there is interval change. " A_EndChar,6)
            return
            :B0:sfu::
                sendByClipboard("suggest follow up." A_EndChar,3)
            return
            ;~ ::SM::History: screening mammogram.
            :B0:sr::
                sendByClipboard("skin retraction" A_EndChar,2)
            return
            :B0:sth::
                sendByClipboard("skin thickening" A_EndChar,3)
            return
            :B0:scm::
                sendByClipboard("screening mammography" A_EndChar,3)
            return
            :B0:dgm::
                sendByClipboard("diagnostic mammography" A_EndChar,3)
            return

            :B0:usb::
                sendByClipboard("Ultrasound of both breasts shows " A_EndChar,3)
            return
            :B0:ush::
                sendByClipboard("Heterogenous breast tissue of bilateral breasts." A_EndChar,3)
            return
            :B0:usl::
                sendByClipboard("A cm hypoechoic lesion in right/left breast at o'clock/cm," A_EndChar,3)
            return
            :B0:usn::
                sendByClipboard("Probably benign ultrasound findings. Suggest follow up." A_EndChar,3)
            return
            :B0:wm::
                sendByClipboard("wire marked" A_EndChar,2)
            return
            :B0:mic::
                sendByClipboard("microcalcifications" A_EndChar,3)
            return
            :B0:ca::
                sendByClipboard("calcifications" A_EndChar,2)
            return

            ;~ ^!r::
            ;~ reload
            ;~ return

            ;~ ^!x::
            ;~ suspend
            ;~ return

            :B0:ti::
                sendByClipboard("There is" A_EndChar,2)
            return
            :B0:ta::
                sendByClipboard("There are" A_EndChar,2)
            return
            :B0:asy::
                sendByClipboard("asymmetry" A_EndChar,3)
            return
            :B0:gsy::
                sendByClipboard("global asymmetry" A_EndChar,3)
            return
            :B0:fsy::
                sendByClipboard("focal asymmetry" A_EndChar,3)
            return
            :B0:dsy::
                sendByClipboard("developing asymmetry" A_EndChar,3)
            return

            :B0:br::
                sendByClipboard("breast" A_EndChar,2)
            return
            :B0:br1::
                sendByClipboard("breasts" A_EndChar,3)
            return
            :B0:sta::
                sendByClipboard("unchanged" A_EndChar,3)
            return
            :B0:com::
                sendByClipboard("as compared to previous study." A_EndChar,3)
            return
            :B0:ic::
                sendByClipboard("interval change" A_EndChar,2)
            return
            :B0:x/::
                sendByClipboard("without" A_EndChar,2)
            return
            :B0:w/::
                sendByClipboard("with" A_EndChar,2)
            return
            ;~ ::def::definite
            :B0:ant::
                sendByClipboard("anterior" A_EndChar,3)
            return
            :B0:pos::
                sendByClipboard("posterior" A_EndChar,3)
            return
            :B0:cen::
                sendByClipboard("central" A_EndChar,3)
            return
            ;~ ::sug::suggest
            :B0:sus::
                sendByClipboard("suspicious" A_EndChar,3)
            return
            :B0:usc::
                sendByClipboard("suggest ultrasound correlation." A_EndChar,3)
            return
            :B0:wed::
                sendByClipboard("well-defined" A_EndChar,3)
            return
            :B0:up::
                sendByClipboard("upper" A_EndChar,2)
            return
            :B0:lo::
                sendByClipboard("lower" A_EndChar,2)
            return
            :B0:ou::
                sendByClipboard("outer" A_EndChar,2)
            return
            :B0:nn::
                sendByClipboard("inner" A_EndChar,2)
            return
            :B0:ov::
                sendByClipboard("oval" A_EndChar,2)
            return
            :B0:rn::
                sendByClipboard("round" A_EndChar,2)
            return
            :B0:ir::
                sendByClipboard("irregular" A_EndChar,2)
            return
            :B0:ci::
                sendByClipboard("circumscribed" A_EndChar,2)
            return
            :B0:ob::
                sendByClipboard("obscured" A_EndChar,2)
            return
            :B0:pob::
                sendByClipboard("partially obscured" A_EndChar,3)
            return
            :*B0:pbpc::
                sendByClipboard("partially obscured partially circumscribed",3)
            return
            :B0:mlb::
                sendByClipboard("microlobulated" A_EndChar,3)
            return
            :B0:ind::
                sendByClipboard("indistinct" A_EndChar,3)
            return
            ;~ ::sp::spiculated
            :B0:nod::
                sendByClipboard("nodule" A_EndChar,3)
            return
            :B0:pu::
                sendByClipboard("punctate" A_EndChar,2)
            return
            :B0:am::
                sendByClipboard("amorphous" A_EndChar,2)
            return
            :B0:cr::
                sendByClipboard("coarse" A_EndChar,2)
            return
            :B0:coh::
                sendByClipboard("coarse heterogeneous" A_EndChar,3)
            return
            :B0:fp::
                sendByClipboard("fine pleomorphic" A_EndChar,2)
            return
            :B0:ple::
                sendByClipboard("pleomorphic" A_EndChar,3)
            return
            :B0:fl::
                sendByClipboard("fine linear" A_EndChar,2)
            return
            :B0:flb::
                sendByClipboard("fine linear branching" A_EndChar,3)
            return
            :B0:gr::
                sendByClipboard("grouped" A_EndChar,2)
            return
            :B0:lin::
                sendByClipboard("linear" A_EndChar,3)
            return
            :B0:ad::
                sendByClipboard("architectural distortion" A_EndChar,2)
            return
            :B0:tt::
                sendByClipboard("trabecular thickening" A_EndChar,2)
            return
            :B0:uw::
                sendByClipboard("under the wire" A_EndChar,2)
            return
            :B0:ub::
                sendByClipboard("under the BB" A_EndChar,2)
            return
            :B0:t::
                sendByClipboard("the" A_EndChar,1)
            return
            :B0:sca::
                sendByClipboard("scattered" A_EndChar,3)
            return
            :B0:mc::
                sendByClipboard("MLO/CC" A_EndChar,2)
            return
            :*B0:ln0::
                sendByClipboard("Bilateral axillary lymph nodes, probably non-specific.",2)
            return
            :B0:moc::
                sendByClipboard("milk of calcium" A_EndChar,3)
            return
            :B0:mlo::
                sendByClipboard("MLO" A_EndChar,3)
            return
            :B0:cc::
                sendByClipboard("CC" A_EndChar,2)
            return
            :B0:uo::
                sendByClipboard("UOQ" A_EndChar,2)
            return
            :B0:ui::
                sendByClipboard("UIQ" A_EndChar,2)
            return
            :B0:lo::
                sendByClipboard("LOQ" A_EndChar,2)
            return
            :B0:li::
                sendByClipboard("LIQ" A_EndChar,2)
            return
            ;~ ::ruo::right UOQ
            ;~ ::rui::right UIQ
            ;~ ::rlo::right LOQ
            ;~ ::rli::right LIQ
            ;~ ::luo::left UOQ
            ;~ ::lui::left UIQ
            ;~ ::llo::left LOQ
            ;~ ::lli::left LIQ
            ;~ ::ruob::right UOQ breast
            ;~ ::ruib::right UIQ breast
            ;~ ::rlob::right LOQ breast
            ;~ ::rlib::right LIQ breast
            ;~ ::luob::left UOQ breast
            ;~ ::luib::left UIQ breast
            ;~ ::llob::left LOQ breast
            ;~ ::llib::left LIQ breast
            :B0:uob::
                sendByClipboard("UOQ breast" A_EndChar,3)
            return
            :B0:uib::
                sendByClipboard("UIQ breast" A_EndChar,3)
            return
            :B0:lob::
                sendByClipboard("LOQ breast" A_EndChar,3)
            return
            :B0:lib::
                sendByClipboard("LIQ breast" A_EndChar,3)
            return
            :B0:mam::
                sendByClipboard("mammography" A_EndChar,3)
            return
            :B0:disp::
                sendByClipboard("is dispersed on spot view, benign tissue is considered." A_EndChar,4)
            return
            :B0:tom::
                sendByClipboard("tomosynthesis" A_EndChar,3)
            return

            :B0:thn::
                sendByClipboard("(due to very thin breast, only needle localization is feasible)" A_EndChar,3)
            return

            #Hotstring, SE
            :B0:mdb::
                sendByClipboard("
(
P.S. There is increased false negative rate of mammography in dense breasts. Suggest ultrasound correlation if there is clinical concern, palpable mass, history of abnormal findings of breast ultrasound or family history of breast cancer. 緻密型乳房會增加乳房攝影之偽陰性， 如有臨床考量、摸到腫塊、過去異常之乳房超音波發現或有乳癌家族史，則建議乳房超音波對照。
)")
                sendByClipboard(a_endchar)
            return
            :B0:mds::
                sendByClipboard("
(
P.S. There is increased false negative rate of mammography with history of silicone injection. Suggest MRI correlation if there is clinical concern, palpable mass, history of abnormal findings of breast ultrasound or family history of breast cancer. 小針美容會增加乳房攝影之偽陰性， 如有臨床考量、摸到腫塊、過去異常之乳房超音波發現或有乳癌家族史，則建議乳房磁振造影對照。
)")
                sendByClipboard(a_endchar)
            return

            :B0:m0::
                sendByClipboard("
(
There are benign calcifications present bilaterally.
- There are neither definite mass nor architectural distortion in this study.
- No definite axillary lymphadenopathy.
)")
                sendByClipboard(a_endchar)
            return
            :B0:m1::
                sendByClipboard("
(
There are neither definite mass, suspicious microcalcifications nor architectural distortion in this study.
- No definite axillary lymphadenopathy.
)")
                sendByClipboard(a_endchar)
            return
            MB0:
                str1:="ACR BI-RADS 0, indeterminate mammographic finding (need additional imaging evaluation).",str2:="性質未定之乳房攝影發現"
                    ,suggest:=$.value(1),side:=$.value(2)="b"?"bilateral":$.value(2)="r"?"right":"left"
                    ,arr1:=[],arr2:=[]
                ;~ msgbox % $.value(0) "," $.value(1)
                if instr(suggest,"u")
                    arr1.push("breast ultrasound"),arr2.push("乳房超音波")
                if instr(suggest,"s")
                    arr1.push("spot compression"),arr2.push("局部壓迫攝影")
                if instr(suggest,"z")  ; use "z" due to hotkey interfere of "~m" (Zoom)
                    arr1.push("spot magnified view"),arr2.push("加壓放大攝影")
                send % "{bs " StrLen($.value(0))  "}"
                sendByClipboard(str1 " Suggest " joinAnd(arr1) " for " side " breast" (side="bilateral"?"s":"") ".`r`n" str2 "，建議" joinAnd(arr2,"、","") "對照（" (instr(side,"b")?"雙":instr(side,"r")?"右":"左") "乳）。")
            return
            /*
            ::MB0UL::ACR BI-RADS 0, indeterminate mammographic finding (need additional imaging evaluation). Suggest breast ultrasound correlation for the left breast. 性質未定之乳房攝影發現，建議乳房超音波對照(左乳)。
            ::MB0UR::ACR BI-RADS 0, indeterminate mammographic finding (need additional imaging evaluation). Suggest breast ultrasound correlation for the right breast. 性質未定之乳房攝影發現，建議乳房超音波對照(右乳)。
            ::MB0UB::ACR BI-RADS 0, indeterminate mammographic finding (need additional imaging evaluation). Suggest breast ultrasound correlation for bilateral breasts. 性質未定之乳房攝影發現，建議乳房超音波對照(雙乳)。

            ::MB0SL::ACR BI-RADS 0, indeterminate mammographic finding (need additional imaging evaluation). Suggest spot compression for the left breast and ultrasound study. 建議局部壓迫攝影(左乳)，乳房超音波對照。
            ::MB0SR::ACR BI-RADS 0, indeterminate mammographic finding (need additional imaging evaluation). Suggest spot compression for the right breast and ultrasound study. 建議局部壓迫攝影(右乳)，乳房超音波對照。
            ::MB0SB::ACR BI-RADS 0, indeterminate mammographic finding (need additional imaging evaluation). Suggest spot compression for bilateral breasts and ultrasound study. 建議局部壓迫攝影(雙乳)，乳房超音波對照。

            ::MB0ML::ACR BI-RADS 0, indeterminate mammographic finding (need additional imaging evaluation). Suggest spot magnified view for the left breast and ultrasound study. 建議加壓放大(左乳)，乳房超音波對照。
            ::MB0MR::ACR BI-RADS 0, indeterminate mammographic finding (need additional imaging evaluation). Suggest spot magnified view for the right breast and ultrasound study. 建議加壓放大(右乳)，乳房超音波對照。
            ::MB0MB::ACR BI-RADS 0, indeterminate mammographic finding (need additional imaging evaluation). Suggest spot magnified view for bilateral breasts and ultrasound study. 建議加壓放大(雙乳)，乳房超音波對照。
            */
            :B0:mb1::
                sendByClipboard("
(
ACR BI-RADS 1, negative finding. Suggest follow up annually and breast ultrasound correlation if there is clinical palpable lump or prior ultrasound detected abnormality. 無異常乳房攝影發現，建議每年追蹤，若有臨床可觸摸之腫塊或已知之超音波異常則需乳房超音波檢查.
)")
                sendByClipboard(a_endchar)
            return
            :B0:mb2::
                sendByClipboard("
(
ACR BI-RADS category 2, benign findings of this mammography. Suggest annual mammogram follow up or ultrasound study if there is any clinical palpable lump or prior ultrasound detected abnormality. 良性乳房攝影發現建議每年追蹤，若有臨床可觸摸之腫塊或已知之超音波異常則需乳房超音波檢查.
)")
                sendByClipboard(a_endchar)
            return
            :B0:mb3::
                sendByClipboard("
(
ACR BI-RADS 3, probably benign finding. Suggest 6-month mammogram follow up. (If there is clinical relevant finding, ultrasound is suggested.) 可能為良性乳房攝影發現，建議間隔六個月追蹤乳房攝影。(若摸到腫塊，則需施行乳房超音波對照。)
)")
                sendByClipboard(a_endchar)
            return
            :B0:mb4::
                sendByClipboard("
(
ACR BI-RADS 4, suspicious malignant lesion. Suggest tissue proof. 疑似不正常的乳房攝影發現。建議組織採檢。
)")
                sendByClipboard(a_endchar)
            return
            :B0:mb4r::
                sendByClipboard("
(
ACR BI-RADS 4, suspicious malignant lesion. Suggest tissue proof for the right breast. 疑似不正常的乳房攝影發現。建議組織採檢(右乳)。
)")
                sendByClipboard(a_endchar)
            return
            :B0:mb4l::
                sendByClipboard("
(
ACR BI-RADS 4, suspicious malignant lesion. Suggest tissue proof for the left breast. 疑似不正常的乳房攝影發現。建議組織採檢(左乳)。
)")
                sendByClipboard(a_endchar)
            return

            getMammoViews(num=""){
                static views:="(CC|MLO|SIO|LM|ML|AT)"
                global __is_CH,__is_N, mammoSide, mammoHasMag, mammoHasImplant
                if __is_N
                {

                    series:=getSeriesName()
                        ,mammoViews:=","
                    for k,v in series {

                        if RegExMatch(v.1,"is)^(.+?)Tomo",match) && RegExMatch(Trim(match1), "(R|L) *" views, m)
                            mammoViews.=m1 m2 " tomosynthesis,"
                        else if (regexmatch(v.1,"(R|L)(?:M)?" views,match) && v.2>1){
                            mammoViews.=match1  match2 ","
                            mammoViews.=match1 (num=0?"":"M") match2 (num=0?" ID":"") ","
                        }else if regexmatch(v.1,"(R|L)(?:M)" views,match) && v.2=1
                            mammoViews.=match1 "M" match2 ","
                        else if regexmatch(v.1,"(R|L)" views, match) && num=5
                            mammoViews.=match1 "M" match2 ","
                        else if !instr(v.1,"關鍵影像")
                            mammoViews.=Trim(v.1) ","
                    }

                    str:=","
                    loop,parse,mammoViews,`,
                        if Trim(A_LoopField) = ""
                            continue
                        else if RegExMatch(A_LoopField, "is)(.+)ID$", m) && InStr(mammoViews, "," Trim(M1) ",") {
                            StringReplace,str,str,% "," Trim(M1) ",",% "," Trim(M1) " II,"
                            str.=A_LoopField ","
                        }else
                            str.=A_LoopField ","

                    str:=SubStr(RegExReplace(SubStr(str,2), "\,", ", "), 1, -2)

                }else if __is_CH
                {
                    str:=""
                    switch mammoSide {
                    case "l": str.="left "
                    case "r": str.="right "
                    case "b": str.= "bilateral "
                    }
                    if mammoHasMag
                        str.="magnified "
                    if mammoHasImplant
                        str.="(II/ID) "
                    str.= "MLO/CC"
                }
                return str
            }

            getMammoViews:
                series:=getSeriesName()
                mammoViews:=""
                for k,v in series {

                    if RegExMatch(v.1,"is)^(.+?)Tomo",match)
                        mammoViews.=RegExReplace(match1," ","") "T,"
                    else if regexmatch(v.1,"(R|L)(CC|MLO)",match) && v.2>1
                        mammoViews.=v.1 ","
                            ,mammoViews.=match1 "mag" (num=0?"i":"") match2 ","
                    else if regexmatch(v.1,"(R|L)(CC|MLO)",match) && num=5
                        mammoViews.=match1 "mag" (num=0?"i":"") match2 ","
                    else if !instr(v.1,"關鍵影像")
                        mammoViews.=v.1 ","
                }
                ;R+L->b
                temp:=[]
                loop,parse,mammoViews,`,
                    if regexmatch(a_loopfield,"^(R|L)(\w+)",match)
                        temp[match2,match1]:=1
                    else if (a_loopfield!="")
                        temp[a_loopfield]:=1
                temp2:=[]
                for k,v in temp
                    if isobject(v) {
                        if v.R && v.L
                            temp2.push("b" k),v.Delete("R"),v.Delete("L")
                        for x,y in v
                            temp2.push(x k)
                    } else
                        temp2.push(k)

                ;MLO+CC->mc
                temp:=[]
                for k,v in temp2
                    if regexmatch(v,"s)^(R|L|b)(mag)?(i)?(MLO|CC)(T)?",match)
                        temp[match1,match2 match3 match4 match5]:=1
                    else
                        temp[v]:=1
                temp2:=[]
                for k,v in temp
                    if isobject(v) {
                        if v.MLO && v.CC
                            temp2.push(k "mc"),v.Delete("MLO"),v.Delete("CC")
                        if v.magMLO && v.magCC
                            temp2.push(k "magmc"),v.Delete("magMLO"),v.Delete("magCC")
                        if v.magiMLO && v.magiCC
                            temp2.push(k "magimc"),v.Delete("magiMLO"),v.Delete("magiCC")
                        for x,y in v
                            temp2.push(k x)
                    }else
                        temp2.push(k)

                temp:=[]
                for k,v in temp2
                    if regexmatch(v,"^(R|L|b)(MLO|CC|mc)T$",match)
                        temp.push((match1="R"?"right ":match1="L"?"left ":"bilateral ") (match2="mc"?"MLO/CC":match2) " tomosynthesis")
                    else if regexmatch(v,"^(R|L|b)(mag)?(i)?(MLO|CC|mc)",match)
                        temp.push((match1="R"?"right ":match1="L"?"left ":"bilateral ") (match2?"magnified ":"") (match4="mc"?"MLO/CC":match4) (match3?" II/ID":""))
                    else if regexmatch(v,"^(R|L|b)(\w+)",match)
                        temp.push((match1="R"?"right ":match1="L"?"left ":"bilateral ") match2)
                    else
                        temp.push(v)

                outputStr:=""
                for k,v in temp
                    outputStr.=v ", "

                outputStr:=substr(outputStr,1,-2)
                RegExMatch(outputStr,"is)^(\w)(.+)$",match)
                outputStr:=upperCase(match1) match2
                RegExMatch(outputStr,"is)^(.+)(, )(.+?)$",match)
                if match2
                    outputStr:=match1 " and " match3

                if regexmatch(outputStr, "is)^(Left|Right)(.+)",match) && !instr(outputStr,"magnified") {
                    editHwnds:=getSimpleRisEditHwnds()
                    text:=controlgettext(editHwnds.length()?editHwnds[2]:getRisReports(risOpened()[2])[1,1])
                    if regexmatch(text,"i)follow up|f\/u") && !regexmatch(text,"i)mastectomy|MRM")
                        outputStr:=match1 " magnified" match2
                }
            ;~ outputStr:=RegExReplace(outputStr, "i)bilateral CC tomosynthesis( and|,) bilateral MLO tomosynthesis")
            return

            upperCase(str){
                stringupper,str,str
                return str
            }

            CHmammoTitle:
                if Mammo_ReportBuildBusy
                    return
                send % "{bs " StrLen($.value(0)) "}"
                mammoSide:=$.value(1)
                    ,mammoHasMag:=$.value(2)!=""
                    ,mammoHasImplant:=$.value(3)!=""
                    ,num:=mammoDensityNum:=$.value(4)
                    ,fastMammoScreenReport:=false
                goto dt_
            return

            fastMammoScreenReport:
                if Mammo_ReportBuildBusy
                    return
                mammoSide:="b"
                    ,mammoHasMag:=false
                    ,mammoHasImplant:=false
                    ,num:=mammoDensityNum:=mammoScreenDen
                    ,fastMammoScreenReport:=true
                goto dt_
            return

            :o*:dt0::
            :o*:dt1::
            :o*:dt2::
            :o*:dt3::
            :o*:dt4::
            :o*:dt5::
                if Mammo_ReportBuildBusy
                    return
                num:=substr(a_thishotkey,0,1)
            :o:dt::
            ;~ resetReports()
            ;~ Sleep 300
            dt_:
                if Mammo_ReportBuildBusy
                    return
                Mammo_PendingIndicationToggle:=false
                Mammo_ReportReadyEdits:=""
                Mammo_ReportSyncDirty:=false
                Mammo_ReportBuildBusy:=__is_CH ? true : false
                try {
                mammoBuildAccNo:=__is_CH ? Mammo_CH_GetAccNoQuick(300) : ""
                Hotkey,#f,_10103,Off
                Hotkey,#f,_10103,On
                Sleep 300
                if __is_N
                {
                    settimer,updateSimpleRISoldHx,-500
                    for k,v in (impaxControls:=getcontrols(impaxopened()[2,1])){
                        if v.text="BMP_VIRTUAL_SCREEN_BUTTON" && instr(v.ClassNN,"WindowsForms10.BUTTON") {
                            controlclick,,% "ahk_id " v.hwnd
                            break
                        }
                    }
                }
                structuredReport:=[]
                    ,clinicalInfo:=""
                    ,structuredReport.views:=getMammoViews(num)

                if __is_N
                {
                    RisHistoryAcc:=acc_ObjectFromWindow(getRisHistoryId(RisHwnd:=RisOpened()[2]))
                        ,priorDate:="",priorCount:=0
                    for k,v in rows:=acc_children(RisHistoryAcc)
                        if regexmatch(examName:=acc_children(v)[4].accValue,"is)Mammogra|乳房|LOCALIZATION- BREAST|Medio-lateral oblique|Mammotome|Stereotic|tomosynthesis") {
                            if (++priorCount>6)
                                break
                            thisDate:=acc_children(v)[2].accValue
                            if RegExReplace(thisDate,"\D","")<SubStr(a_now,1,8)-70000
                                break
                            priorDate.=thisDate
                            if instr(examName,"LOCALIZATION- BREAST")
                                priorDate.= " (needle localization)"
                            else if instr(examName,"Mammotome") || instr(examName,"Stereotic")
                                priorDate.= " (stereotactic biopsy)"
                            else if instr(examName,"tomosynthesis")
                                priorDate.= " (tomosynthesis)"
                            else if instr(examName,"Medio-lateral oblique")
                                priorDate.= " (MLO)"
                            priorDate.=", "
                            ;~ if (k<=6) {
                            ;~ v.accSelect(ComObj(3,3),0)
                            ;~ sleep 100
                            ;~ loc:=Acc_Location(v)
                            ;~ mouseclick,r,% loc.x+50,% loc.y+5,1,0
                            ;~ sleep 100
                            ;~ mouseclick,l,10,10,1,0,,R
                            ;~ }
                        }
                }else if __is_CH
                {
                    chFastCache:=Mammo_CH_GetFastReportCache()
                    if IsObject(chFastCache) {
                        priorDate:=chFastCache.priorDate
                            ,priorCount:=chFastCache.priorCount
                            ,lastReport:=chFastCache.lastReport
                            ,examName:=chFastCache.examName
                            ,clinicalInfo:=chFastCache.clinicalInfo
                    } else {
                        CH_RIS.Parse_pacs_hx(true)
                            ,RisHistory:=CH_RIS.pacs_hx.data
                            ,colNo:=CH_RIS.pacs_hx_colNo
                            ,priorDate:="",priorCount:=0, lastReport:="", clinicalInfo:=""

                        for k,row in RisHistory
                            if Mammo_CH_IsPriorMammoExam(examName:=row[colNo.examName], row[colNo.examType]) {
                                if (++priorCount>6)
                                    break
                                if lastReport=
                                    lastReport:=row[colNo.Report]
                                thisDate:=RegExReplace(row[colNo.ExamDate], " \d\d:\d\d:\d\d\s*$", "")
                                ;~ if RegExReplace(thisDate,"\D","")<SubStr(a_now,1,8)-70000
                                ;~ break
                                priorDate.=thisDate
                                if instr(examName,"LOCALIZATION- BREAST")
                                    priorDate.= " (needle localization)"
                                else if instr(examName,"Mammotome") || instr(examName,"Stereotic")
                                    priorDate.= " (stereotactic biopsy)"
                                else if instr(examName,"tomosynthesis")
                                    priorDate.= " (tomosynthesis)"
                                else if instr(examName,"Medio-lateral oblique")
                                    priorDate.= " (MLO)"
                                priorDate.=", "

                            }

                        examName:=CH_RIS.examName
                    }
                }

                if (priorDate="" && !priorPacsHxDate.length()){
                    structuredReport.comparison:="no prior mammograms available for comparison. " (__is_CH?"(X)":"")
                }else{
                    structuredReport.comparison:=priorDateCombine(priorDate, priorPacsHxDate)  (__is_CH?". (V) (The findings are roughly unchanged.)":"")
                }

                if priorPacsHxDate.length()
                    outReportPwb.Visible:=true

                ;~ structuredReport.indication:=(num=5||mammoHasMag||InStr(examName, "diagnos")?"diagnostic mammography.":"screening mammography.")
                structuredReport.indication:=(num=5||mammoHasMag?"diagnostic mammography.":"screening mammography.")

                if (priorCount){

                    oldReportText:=__is_CH?lastReport:ControlGetText(getRisReports(RisState[2])[2,1])
                    ;~ if (RegExMatch(oldReportText, "i)category ([\dabc])", priorBIRADS))
                    ;~ ShowToolTip("Last BIRADS: " priorBIRADS1, 5000)

                    indicationChanged:=false
                        ,bropRE:="i)family|mast?ectomy|biopsy|\bvab\b|needle|localiz|stereo|BCT|MRM|mammotome|benign|malignan|cancer|carcinoma|DCIS|IDC|ILC"
                        ,brDenline:="i)breast composition|heterogeneous\w* dense|entirely fat|extreme\w* dense|fibroglandular density"
                    Loop,parse,oldReportText,`n,`r
                    {
                        if (A_LoopField~=bropRE){
                            structuredReport.indication:= " " StringLowerFirst(RegExReplace(Trim(A_LoopField), "i)^(Indication and )?(History|Hx|Indication)?( of ?)?:? ?", ""))
                                , structuredReport.indication.= (structuredReport.indication~="\w$"?".":"")
                                , indicationChanged:=true
                            break
                        }else if (A_LoopField~=brDenLine)
                            break
                    }
                    if !indicationChanged {
                        if (clinicalInfo="")
                            clinicalInfo:=getRisClinicalInfoText(RisState[2])
                        Loop,parse,clinicalInfo,`n,`r
                        {
                            if (A_LoopField~=bropRE){
                                structuredReport.indication:= " "  StringLowerFirst(RegExReplace(Trim(A_LoopField), "i)^(Indication and )?(History|Hx|Indication)?( of ?)?:? ?", ""))
                                    , structuredReport.indication.= (structuredReport.indication~="\w$"?".":"")
                                    , indicationChanged:=true
                                break
                            }else if  (A_LoopField~=brDenLine)
                                break
                        }
                    }
                }
                if (structuredReport.views="LMLO, LMMLO, RMLO, RMMLO, LCC, LMCC, RCC, RMCC, LMLO tomosynthesis, RMLO tomosynthesis, LCC tomosynthesis, RCC tomosynthesis")
                    structuredReport.views:="bilateral MLO/CC mammography and tomosynthesis"

                finalOutput:=""
                    ;~ ,finalOutput.="INDICATION: " (InStr(examName, "diagnos")?"diagnostic mammography.":fastMammoScreenReport?"screening mammography.":Trim(structuredReport.indication)) "`r`n"
                    ,finalOutput.="INDICATION: " (fastMammoScreenReport?"screening mammography.":Trim(structuredReport.indication)) "`r`n"
                    ,finalOutput.="COMPARISON: " structuredReport.comparison "`r`n"
                    ,finalOutput.="MAMMOGRAPHY VIEWS: " structuredReport.views ".`r`n"
                /*
                TODO: insert SCREENING INFO line here, sourced from
                CH scripts/mammo_pdf_db/form_template.json -> "report_phrases".

                Wire-up sketch (not yet enabled):

                    if (__is_CH) {
                        recs := MammoPdfDB_AutoMatchByChRIS()
                        if (recs.MaxIndex())
                            finalOutput .= MammoPdfDB_BuildScreeningInfo(recs[1])
                    }

                BuildScreeningInfo() reads report_phrases (key = "<field>.<value>"),
                keeps insertion order, applies skip_if guards, wraps detail_placeholder
                values in "(...)", joins clauses with ". ", and returns either ""
                (no positives -> omit the entire SCREENING INFO line) or:
                    "SCREENING INFO: <phrase1>(<placeholder1>). <phrase2>. ...`r`n"
                */
                    ,finalOutput.="FINDINGS: `r`n- "

                    ,editHwnds:=getSimpleRisEditHwnds()
                    ,sci:=WinExist("ahk_id " sci.hwnd) ? sci : new RemoteScintilla(editHwnds[2])
                    ,sci.ClearAll()
                    ,sci.AddText(finalOutput)

                ;~ sendByClipboard(finalOutput)
                ;~ sendlevel,2
                if num in 1,2,3,4
                    ;~ sendByClipboard(brDen[num] "`r`n- ")
                    sci.AddText(brDen[num] "`r`n- ")
                num:=""
                ;~ sendlevel,0

                Allviews:=structuredReport.views
                RightViews:=LeftViews:=false
                Loop,parse,Allviews,`,
                {
                    if (Trim(A_LoopField)~="^R|[Bb]i|right")
                        RightViews:=true
                    else if (Trim(A_LoopField)~="^L|[Bb]i|left")
                        LeftViews:=true
                }
                if !InStr(Allviews, "bil") && (!RightViews || !LeftViews){
                    Text:=Edit_GetText(editHwnds[2])
                        ,text:=RegExReplace(text,"- The breasts are","- The " (RightViews?"right":"left") " breast is")
                    PostMessage,0x2023,1000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
                    Edit_SetText(editHwnds[2], Text)
                        ,Edit_SetSel(editHwnds[2],len:=strlen(text),len)
                        ,Edit_SetText(editHwnds[1], Text)
                        ,Edit_SetSel(editHwnds[1],len,len)
                }

                Text:=Edit_GetText(editHwnds[2])
                if (Text~="i)^dt?\d?INDIC"){
                    Edit_SetText(editHwnds[2], RegExReplace(Text, "i)^dt?\d?", ""))
                        ,Edit_SetSel(editHwnds[2], -1, -1)
                }
                ; The visible text is complete. Enable indication edits before
                ; the remaining history/impression work and RIS round trips.
                Mammo_ReportReadyEdits:=editHwnds
                WinFocus(getSimpleRisGuiHwnds()[2], editHwnds[2])
                Mammo_ApplyPendingIndicationToggle(editHwnds, mammoBuildAccNo)

                if priorCount && RegExMatch(ControlGetText(getRisReports(RisHwnd)[2,2]), "i)BI\W?RADS\s+(1|2)|category\s+(1|2)", match){
                    FirstLineFound:=false
                        ,str:=""
                    Loop,parse,oldReportText,`n,`r
                    {
                        if !FirstLineFound && (Trim(A_LoopField)~="^(\W+|\W?\d+\W+)") && (A_LoopField~="i)fatty|fibroglandular|dense")
                            FirstLineFound:=true
                        else if (FirstLineFound){
                            str.=A_LoopField "`r`n"
                        }
                    }

                    if(str=""){
                        Loop,parse,oldReportText,.`r`n
                        {
                            if !FirstLineFound && (A_LoopField~="i)fatty|fibroglandular|dense")
                                FirstLineFound:=true
                            else if (FirstLineFound){
                                str.=RegExReplace(A_LoopField , "i)\W*findings\W*", "") ".`r`n"
                            }
                        }

                    }

                    clipOld:=ClipboardAll
                        ,clipboard:=""
                        ,clipboard:=str
                    ClipWait,0.3
                    Mammo_NotifyPriorHistory(WinExist("prettyOldHx_main ahk_class AutoHotkeyGUI"))

                    if InStr(match, "2")
                        Edit_SetText(getRisReports(RisHwnd)[1,2], "BI-RADS 2, benign finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)")
                    else
                        Edit_SetText(getRisReports(RisHwnd)[1,2], "BI-RADS 1, negative finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)")

                }

                ; A request made from G3PACS while this report was being built
                ; must be applied to the completed text. If another request
                ; arrives during the synchronous RIS flush, repeat the flush;
                ; the critical check makes releasing the busy flag atomic.
                Loop
                {
                    ; Reset before reading text; a key that interrupts any
                    ; subsequent RIS wait marks this snapshot out of date.
                    Mammo_ReportSyncDirty:=false
                    Mammo_ApplyPendingIndicationToggle(editHwnds, mammoBuildAccNo)
                    Mammo_FlushReport(editHwnds, true)
                    Critical
                    if (!Mammo_PendingIndicationToggle && !Mammo_ReportSyncDirty) {
                        ; Keep the handoff atomic through the finally cleanup.
                        break
                    }
                    Critical, Off
                }
                } finally {
                    Critical
                    Mammo_ReportBuildBusy:=false
                    Mammo_PendingIndicationToggle:=false
                    Mammo_ReportReadyEdits:=""
                    Mammo_ReportSyncDirty:=false
                    Critical, Off
                }
                if(fastMammoScreenReport){
                    fastMammoScreenReport:=false
                    if (mammoScreenBIRADS=2){
                        goto _b22
                    }
                    else if (mammoScreenBIRADS=1){
                        goto _b11
                    }
                }
            return

            Mammo_CH_IsPriorMammoExam(examName, examType:=""){
                if (Trim(examType)="Mammo")
                    return !MammoRisHoros_IsBreastUS(examName, examType)
                return false
            }

            priorDateCombine(priorDate, priorPacsHxDate){
                priorDate:=RegExReplace(priorDate,"\, $","")
                for k,d in priorPacsHxDate {
                    added:=false
                        ,newPriorDate:=""
                    Loop,parse,priorDate,`,
                    {
                        if !RegExMatch(A_LoopField, "[\d\/]+", thisDate)
                            continue
                        thisDate:=RegExReplace(thisDate, "\/", "")
                        if(d==thisDate){
                            newPriorDate:=priorDate ", "
                                , added:=true
                            break
                        }else if (A_Index==1 && d>thisDate){
                            priorDate:=dateConv(d) ", " priorDate
                                ,newPriorDate:=priorDate ", "
                                , added:=true
                            break
                        }else if (!added && d>thisDate){
                            newPriorDate.=dateConv(d) ", " A_LoopField ", "
                        }else{
                            newPriorDate.=A_LoopField ", "
                        }
                    }
                    priorDate:=added?SubStr(newPriorDate,1,-2):newPriorDate dateConv(d)
                }
                return priorDate
            }

            dateConv(d, add_delimit="/"){
                return SubStr(d,1,4) add_delimit SubStr(d,5,2) add_delimit SubStr(d,7,2)
            }

            checkPacsHx(){
                global sid, RisState, priorPacsHxDate, sendStr, thisAccNo, outReportPwb, __is_N
                if !__is_N
                    return

                priorPacsHxDate:=[]
                    ,dates:=RegExReplace(priorDate, "\/", "")
                if !checksid(sid)
                    sid:=askforportalidpw()
                for k, v in arr := getPacsHx(sid, getRisChartNo(RisState[2])) {
                    if !InStr(v.Modality, "MG") || (v.ExamDate<SubStr(a_now,1,8)-60000) ; more than 6 year
                        continue
                    if (v.AccessNo!=thisAccNo)
                        priorPacsHxDate.push(v.ExamDate)
                    if (v.HospitalCode=="T0" && !InStr(sendStr, v.AccessNo))
                        ImpaxContextServer_Add(v.AccessNo)
                            ,SetTimerFn("ResendImpaxContextServerForOldStudy", -3000, [v.AccessNo])
                }

                if priorPacsHxDate.length() && (outReportLinks:=getOtherHospitalReports(thisChartNo, sid)).length()
                    outReportPwb:=ComObjCreate("InternetExplorer.Application")
                        ,outReportPwb.NAvigate(outReportLinks[1])
            }

            resetReports(){
                PostMessage,0x2027,,,,simpleRIS_main ahk_class AutoHotkeyGUI
            }

            accNoChanged(){
                static priorAccNo
                global RisState, thisAccNo, thisChartNo, __is_CH, CH_RIS
                if (__is_CH)
                    Mammo_CH_ResetQuick(800)
                else
                    CH_RIS.reset(1)
                thisAccNo:=getRisAccNo(RisState[2])
                if(thisAccNo=priorAccNo)
                    return
                priorAccNo:=thisAccNo
                thisChartNo:=getRisChartNo(RisState[2])
                IfWinnotExist,ahk_exe MammoSR.exe
                    gosub openImages

                ; Refresh CH_RIS so examName/patidno are populated for the new
                ; study, then let the PDF DB helper close the prior lookup
                ; window and spawn a new one for the new patient.
                if (__is_CH) {
                    Mammo_CH_CallMethodQuick("refresh_info", 800)
                    Mammo_CH_ScheduleFastReportPreload()
                    MammoPdfDB_FireOnRisChange()
                }

                ;~ if __is_CH && (CH_RIS.examName!="" || CH_RIS.refresh_info()) && InStr(CH_RIS.examName, "巡迴車")
                ;~ openHxPDF()
            }

            Mammo_CH_ScheduleFastReportPreload(){
                global __is_CH, Mammo_CH_PreloadFastReportCache_Busy
                if !__is_CH
                    return
                if (Mammo_CH_PreloadFastReportCache_Busy)
                    return
                Mammo_CH_ClearFastReportCache()
                SetTimer, Mammo_CH_PreloadFastReportCache, -700
            }

            Mammo_CH_ClearFastReportCache(){
                global Mammo_CH_FastReportCache
                Mammo_CH_FastReportCache := {ready: false, accNo: ""}
            }

            Mammo_CH_GetFastReportCache(){
                global __is_CH, Mammo_CH_FastReportCache
                if !__is_CH || !IsObject(Mammo_CH_FastReportCache) || !Mammo_CH_FastReportCache.ready
                    return ""

                curAcc := ""
                curAcc := Mammo_CH_GetAccNoQuick(300)
                if (curAcc != "" && curAcc = Mammo_CH_FastReportCache.accNo)
                    return Mammo_CH_FastReportCache
                return ""
            }

            Mammo_CH_BuildFastReportCache(){
                global __is_CH, CH_RIS, RisState, Mammo_CH_FastReportCache
                if !__is_CH || !IsObject(CH_RIS)
                    return

                accNo := ""
                accNo := Mammo_CH_GetAccNoQuick(300)
                if (accNo = "")
                    return

                cache := {ready: false, accNo: accNo, priorDate: "", priorCount: 0, lastReport: "", examName: "", clinicalInfo: ""}
                cache.examName := Mammo_CH_GetScalarQuick("examName", 300)

                RisHistory := ""
                colNo := ""
                Mammo_CH_CallMethodQuick("Parse_pacs_hx", 1000, true)
                RisHistory := Mammo_CH_GetPacsHxDataQuick(800)
                colNo := Mammo_CH_GetPacsHxColNoQuick(800)
                if IsObject(RisHistory) && IsObject(colNo) {
                    for k,row in RisHistory {
                        if Mammo_CH_IsPriorMammoExam(examName:=row[colNo.examName], row[colNo.examType]) {
                            if (++cache.priorCount>6)
                                break
                            if (cache.lastReport="")
                                cache.lastReport:=row[colNo.Report]
                            thisDate:=RegExReplace(row[colNo.ExamDate], " \d\d:\d\d:\d\d\s*$", "")
                            cache.priorDate.=thisDate
                            if instr(examName,"LOCALIZATION- BREAST")
                                cache.priorDate.= " (needle localization)"
                            else if instr(examName,"Mammotome") || instr(examName,"Stereotic")
                                cache.priorDate.= " (stereotactic biopsy)"
                            else if instr(examName,"tomosynthesis")
                                cache.priorDate.= " (tomosynthesis)"
                            else if instr(examName,"Medio-lateral oblique")
                                cache.priorDate.= " (MLO)"
                            cache.priorDate.=", "
                        }
                    }
                }

                try cache.clinicalInfo:=getRisClinicalInfoText(RisState[2])
                cache.ready := true

                curAcc := ""
                curAcc := Mammo_CH_GetAccNoQuick(300)
                if (curAcc = accNo)
                    Mammo_CH_FastReportCache := cache
            }

            ShowLastBirads(){
                Mammo_CH_CallMethodQuick("refresh_info", 800)
                examName := Mammo_CH_GetScalarQuick("examName", 300)
                if !(examName ~= "Mammogra|乳房造影|巡迴車") || InStr(examName,"超音波")
                    return ShowLastBiradsGUI()
                RisHistory:=Mammo_CH_GetPacsHxDataQuick(800)
                    ,colNo:=Mammo_CH_GetPacsHxColNoQuick(800)
                    ,priorDate:="",priorCount:=0, lastReport:=""
                if !IsObject(RisHistory) || !IsObject(colNo)
                    return ShowLastBiradsGUI()
                for k,row in RisHistory
                    if regexmatch(examName:=row[colNo.examName],"is)Mammogra|乳房造影") {
                        lastReport:=row[colNo.Report]
                        break
                    }
                RegExMatch(lastReport, "i)category ([\dabc])", priorBIRADS)
                RegExMatch(lastReport, "i)\((\d)\)", priorDensity)
                if(priorDensity1=""){
                    if InStr(lastReport, "extreme")
                        priorDensity1:="4"
                    else if InStr(lastReport, "heter")
                        priorDensity1:="3"
                    else if InStr(lastReport, "fibroglandular")
                        priorDensity1:="2"
                    else if InStr(lastReport, "almost entire")
                        priorDensity1:="1"

                }
                ;~ ShowToolTip("Last BIRADS: " priorBIRADS1, 2000)
                if (priorBIRADS1 priorDensity1 != "")
                    ShowLastBiradsGUI("Last Density: " priorDensity1 "`nBIRADS: " priorBIRADS1)
                else
                    ShowLastBiradsGUI()
            }

            ShowLastBiradsGUI(info=""){
                global ShowLastBiradsGUIHwnd
                if(info="")
                    try
                gui,ShowLastBirads:Destroy
                else{
                    gui,ShowLastBirads:new,+ToolWindow -Border -Caption +AlwaysOnTop +hwndShowLastBiradsGUIHwnd
                    gui,Font,s12,Verdana
                    gui,add,Text,w250 gShowLastBiradsGUIHwndClose,% info
                    gui,show,% "Center NA ycenter x" A_ScreenWidth-300
                }

            }

            ShowLastBiradsGUIHwndClose:
                try
                gui,%ShowLastBiradsGUIHwnd%:Destroy
            return

            openHxPDF(){
                global CH_RIS
                ExamDate:=SubStr(CH_RIS.examtime, 1, 10)
                formatedDate:=(SubStr(ExamDate,1,4)-1911) "." SubStr(ExamDate,6,2) "." SubStr(ExamDate,9,2)
                pdfs:=[]
                Loop,files,% "Z:\乳篩病人資料\000000\" formatedDate "*.pdf"
                    pdfs.push(A_LoopFileLongPath)

                if (pdfs.length()=1){
                    run % pdfs[1]
                }else if (pdfs.length()>1){
                    run,%  "explorer Z:\乳篩病人資料\000000",,,explorer_pid
                    winwait,000000,,3
                    winactivate,
                    WinWaitActive,,,3
                    controlsend,DirectUIHWND1,% formatedDate "{Enter}"
                }
            }

            openImages:
                ExamItems:=parseRisExamItems(getRisExamItems(risopened()[2]))
                    ,examName:=ExamItems[1,1]
                if !(examName~="is)Mammogra|乳房|LOCALIZATION- BREAST|Medio-lateral oblique|Mammotome|Stereotic|tomosynthesis")
                    return

            +#a::
            #a::
                if __is_CH
                    settimer,openHxPDF,-1
                ;~ if !InStr(A_ThisHotkey,"+"){
                ;~ resetReports()
                ;~ }
                MouseGetPos,,,win,con,2
                if (con=(RisListHwnd:=getRisList(RisHwnd:=risopened()[2]))){
                    Click,2
                    MouseGetPos,lastDblx,lastDbly
                    return
                }
                ;~ controlclick,,% "ahk_id " getNetControl2(RisHwnd:=RisOpened()[2],"IMPAX","cmdDs3000","IMPAX","WindowsForms10.BUTTON.app","","","",0)[1]
                settimer,updateSimpleRISoldHx,-500

                RisHwnd:=risopened()[2]

                    ,RisHistoryAcc:=acc_ObjectFromWindow(getRisHistoryId(RisHwnd))
                    ,priorDate:="",count:=0,prior:="", maxPrior:=6
                    ,thisAccNo:=getRisAccNo(RisHwnd)

                if(thisAccNo!=getImpaxAccNo(impaxopened()[2,1]))
                    risOpenStudyImpax(risHwnd, true)
                if !(impaxContextServerHwnd:=ImpaxContextServer_Init()) {
                    prior:=""
                    for k,v in rows:=acc_children(RisHistoryAcc)
                        if regexmatch(acc_children(v)[4].accValue,"is)Mammogra|乳房|LOCALIZATION- BREAST|Medio-lateral oblique|Mammotome|Stereotic|tomosynthesis") {
                            ;~ priorDate.=acc_children(v)[2].accValue ", "
                            if (!prior){
                                prior:=v
                                    ,prior.accSelect(ComObj(3,3),0)
                                Sleep 500
                                if RegExMatch(ControlGetText(getRisReports(RisHwnd)[2,2]), "i)BI\W?RADS\s+(1|2)|category\s+(1|2)")
                                    maxPrior:=1
                            }

                            if (++count<=maxPrior) {
                                v.accSelect(ComObj(3,3),0)
                                sleep 200
                                loc:=Acc_Location(v)
                                mouseclick,r,% loc.x+50,% loc.y+5,1,0
                                sleep 200
                                mouseclick,l,10,10,1,0,,R
                            }else{
                                break
                            }
                        }
                    if !prior
                        checkPacsHx()
                    else
                        priorPacsHxDate:=[]

                }else{
                    sendStr:=""
                    for k,v in rows:=acc_children(RisHistoryAcc) {
                        if(k=1){
                            for x,y in cells:=acc_children(v)
                                if (y.accValue="照會單號"){
                                    AccNoCol:=x
                                    break
                                }
                        }else if regexmatch(acc_children(v)[4].accValue,"is)Mammogra|乳房|LOCALIZATION- BREAST|Medio-lateral oblique|Mammotome|Stereotic|tomosynthesis") {
                            if (!prior){
                                prior:=v
                                    ,prior.accSelect(ComObj(3,3),0)
                                Sleep 500
                                if RegExMatch(ControlGetText(getRisReports(RisHwnd)[2,2]), "i)BI\W?RADS\s+(1|2)|category\s+(1|2)")
                                    maxPrior:=1
                            }
                            if (++count<=maxPrior) {
                                sendStr.="ADD_TO_DISPLAY_LIST || " Trim(acc_children(v)[AccNoCol].accValue) " || "
                            }else{

                                break
                            }
                        }
                    }

                    if sendStr=
                        checkPacsHx()
                    else
                        priorPacsHxDate:=[]

                    sendStr.="SYNC_DISPLAY || " thisAccNo " || "
                    if(Count=0)
                        sendStr.="ADD_TO_DISPLAY_LIST_WITH_PRIORS || " thisAccNo " || "

                    ;~ cmdContextServer(sendStr, impaxContextServerHwnd)
                    SetTimerF("ImpaxContextServer_SendCommand", -1000, [sendStr, impaxContextServerHwnd])

                }

                if (simpleRis:=WinExist("simple RIS ahk_class AutoHotkeyGUI")){
                    winactivate,% "ahk_id " getSimpleRisGuiHwnds[2]
                    ControlFocus,,% "ahk_id " getSimpleRisEditHwnds[2]
                }else{
                    send % "{f6}"
                }

            ;~ SetTimer,ShowLungCAD,-1000
            return

        #IfWinActive,ahk_exe Menu.exe
            ~LButton::
                if(A_TimeSincePriorHotkey<400 && A_ThisHotkey=A_PriorHotkey){
                    MouseGetPos,,,win,con,2
                    if (con=(RisListHwnd:=getRisList(RisHwnd:=risopened()[2]))){
                        MouseGetPos,lastDblx,lastDbly
                    }
                }

#IfWinActive

#ifwinactive,ahk_group RisGroup

    ;~ :*:mam::
    ;~ seriesName:=getSeriesName()
    ;~ mammoName:=""
    ;~ for k,v in seriesName {
    ;~ mammoName.=v.1 ", "
    ;~ if v.2=2
    ;~ mammoName.=substr(v.1,1,1) "M" substr(v.1,2) ", "
    ;~ }
    ;~ if instr(mammoName,")
    return

    checkReport:
        gosub copyToRis
    return

    F3::
    F2::
    F1::
    +F3::
    +F2::
    +F1::
        if(recentSent)
            return
        hotkey_has_shift:=instr(A_ThisHotkey,"+")
        thisHotkey:=RegExReplace(A_ThisHotkey, "^\W", "")
    sendReport1:
    quicksend:
        checkRis(RisState)
        gosub renewRisReports
        gosub copyToRis

        if simpleRisError
            return
        ;~ risReports:=getRisReports(risopened()[2])[1,1]
        editHwnds:=getSimpleRisEditHwnds()
        text:=controlgettext(editHwnds[2])

        if !(Text~="i)BI\W?RADS|mammo|vacuum|vab|needle|localiz|stereo|tomosynthesis|guide") && !InStr(Text, "乳房超音波") {
            MsgBox,260,,% "Mammography report?"
            IfMsgBox,No
                return
        }
        Text:=reportReplace(Text)

        text:=RegExReplace(text,"(?<!\n) {2,}"," ")
            ,text:=RegExReplace(text,"\.{2,}",".")
            ,text:=RegExReplace(text,",{2,}",",")
            ,text:=RegExReplace(text,"\.\,",",")
            ,text:=RegExReplace(text,"\,\.",".")
            ,text:=RegExReplace(text," ([,.;])","$1")
            ;~ text:=RegExReplace(text,"i)([a-z])\. ([a-z])","$1.$2")
            ,text:=RegExReplace(text,"([,;])(\w)","$1 $2")
            ,text:=RegExReplace(text,".  +(\r?\n)",". $1")
            ,text:=RegExReplace(text,"(?<=[\r\n])(-+|\d+[^\w\n\r]) +(\r?\n)|(-+|\d+[^\w\n\r]) +(\r?\n)*$","")
            ,text:=RegExReplace(text,"(?<=[\r\n])(-+|\d+[^\w\n\r]) +","$1 ")
            ;~ text:=RegExReplace(text,"is)^(History[^\r\n]+?)\s*;","$1.")
            ,RegExMatch(text,"is)(History[^\r\n]+)?(.+)",match)
        if regexmatch(match1,"(;)? *$",m) && strlen(m)
            text:=substr(match1,1,(-1)*strlen(m)) "." match2

        text:=RegExReplace(text,"-\s*$","")
            ,text:=RegExReplace(text," susp "," suspicious ")
            ,Text:=RegExReplace(Text, "u?b(11?|22?|3|4[abc]?|5|6)", "")

            ,arr1:=[],arr2:=[]
            ,rxms(text,"(\.\s*)|(-+\s+)|(\n?\d+[^\w\n\r\,\;]\s+)","sarr1[] marr2[]")
            ,newText:=""
        for k,v in arr1
            newText.=stringupper(substr(v,1,1)) substr(v,2) arr2[k]
        text:=RegExReplace(newText,"(?<!\n) {2,}"," ")
        ;~ text:=moveText(newText)

        if (Text~="i)dt\d|b11|b22"){
            MsgBox, 4, , Delete AHK residual?
            IfMsgBox,Yes
                Text:=RegExReplace(Text, "i)dt\d|b11|b22", "")
        }
        Text:=RegExReplace(Text, "i)bilateral-RADS", "BI-RADS")
        Text:=RegExReplace(Text, "i)u?b?\d?[abcmu]?k?\s*BI-RADS", "BI-RADS")
        Text:=RegExReplace(Text, "i)-?\s*u?b?\d?[abcmu]?k?\s*Impression", "`n`nImpression")
        Text:=RegExReplace(text, "i)(?:-? *|\. *)(u?b\d[abcmu]?k?) *(\r?\n)", "$2")

        regexmatch(text, "i)(category *)\b(u?b?\d?[abcmu]?k?)\b", match)
        if(match1="") && (match2~="[a-zA-Z]")
            Text:=RegExReplace(Text, "\bu?b?\d?[abc]?\b", "$1")
        controlsettext,,% text,% "ahk_id " risReports[1,1]
        ;~ controlsettext,Scintilla1,% text,simple RIS ahk_class AutoHotkeyGUI
        editHwnds:=getSimpleRisEditHwnds()
        PauseSimpleRis()
            ,Edit_SetText(editHwnds[2], Text)
            ,Edit_SetText(editHwnds[1], Text)

        if __is_N
        {
            winactivate,% "ahk_id " RisState[2]
            winwaitactive,% "ahk_id " RisState[2],,2
        }else if (__is_CH){
            AllReportText:=RegExReplace((lastReport:=new ReportImpression(Text)).combine(), "(?<!\r)\n", "`r`n")
            ;~ Edit_SetText(editHwnds[2], AllReportText)
            Edit_SetText(editHwnds[1], AllReportText)
                ;~ ,Edit_SetText(CH_RIS.gui.exam_edit, newText)
                ;~ ,Edit_SetText(CH_RIS.gui.impression_edit, newImpressionText)
                ,CH_RIS.exam:=lastReport.exam
                ,CH_RIS.impression:=lastReport.impression
                ,CH_RIS.report:=AllReportText
            ; The breast-US + Shift branch below skips risSendReport, so this is the only flush in
            ; that case. Otherwise risSendReport flushes the IE textarea before saving — flushing
            ; here too opens a populate-then-overwrite gap across the Sleep 400 / BI-RADS prompt.
            if (InStr(CH_RIS.examName, "乳房超音波") && hotkey_has_shift)
                CH_RIS.flush()
            CH_RIS.activate()
            Sleep 400
            if RegExCount(CH_RIS.impression, "i)BI-RADS")>1
                MsgBox % "More than one BI-RADS?"
        }

        if(__is_CH && InStr(CH_RIS.examName, "乳房超音波") && (hotkey_has_shift)){
        }
        ;~ new breastUS_SendPrint()
        ;~ CH_RIS.wb.document.getElementById("printSelectButton").click()
        ;~ }else
        Else{
            Mammo_CH_ExpectedReport := ""
            try {
                if (__is_CH && IsObject(lastReport))
                    Mammo_CH_ExpectedReport := {exam: lastReport.exam, impression: lastReport.impression}
                risSendReport(RisState[2], SubStr(thishotkey,2,1))
            } catch e {
                Mammo_CH_ExpectedReport := ""
                throw e
            }
            Mammo_CH_ExpectedReport := ""
        }

        CloseBreastAssistiveGuis()
        recentSent:=true
        SetTimer,recentSent,-3000
        if(__is_N){
            if (getNetAcc(RisState[2],"chkSequence","WindowsForms10.BUTTON").accState!=1048592)
                gosub goReportList
            if(lastDblx!="" && lastDbly!="")
                MouseMove,% lastDblx,% lastDbly+24,0
            else
                mousemove,500,500,0
        }
        if simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI") {
            ;~ controlsettext,Scintilla1,% "",ahk_id %simpleRIS%
            editHwnds:=getSimpleRisEditHwnds()
            ;~ Edit_SetText(editHwnd, "")
            ;~ resetSimpleRis()
        }
    ;~ controlsettext,Scintilla1,,simple RIS ahk_class AutoHotkeyGUI
    ;~ Edit_SetText(editHwnd, "")
    ;~ resetSimpleRis()
    return

    goReportList:
        tabs:=getNetControl2(RisOpened()[2],"","B_ACTIVE","","WindowsForms10.BUTTON")
        if tabs[2]
            acc_objectfromwindow(tabs[2]).accDoDefaultAction()
    return

#ifwinactive

;~ :*:vab/::
risReports:=getRisReports(risopened()[2])
text=
(
Indications: grouped microcalcifications at the right breast, categorized as 4 on prior mammographic report, requested for vacuum-assisted stereotactic biopsy.

Vacuum-assisted stereotactic breast biopsy is performed for the suspicious microcalcifications:
- This procedure is smoothly performed with a 10-gauge vacuum-assisted EnCor breast biopsy system in decubitus position. After injection of 8-10 ml 2`% Xylocaine and skin incision, the biopsy gun is inserted from outer aspect of the breast.
- There are more than 12 tissue cores extracted under stereotactic guidance successfully.
- A small clip is deployed at the biopsy site.
- Post-biopsy mammography shows nearly total removal of the target microcalcifications.
- Specimen mammography shows microcalcifications within the tissue cores.
- Suggest short term follow up with mammography.
)
controlsettext,,% RegExReplace(text,"\n","`r`n"),% "ahk_id " risReports[1,1]
;~ controlsettext,Scintilla1,% RegExReplace(text,"\n","`r`n"),simple RIS ahk_class AutoHotkeyGUI
editHwnds:=getSimpleRisEditHwnds()
    ,Edit_SetText(editHwnds[2], t:=RegExReplace(text,"\n","`r`n"))
    ,Edit_SetText(editHwnds[1], t)
controlsettext,,Vacuum-assisted stereotactic biopsy is performed for the right breast microcalcifications. The pathologic diagnosis is pending.,% "ahk_id " risReports[1,2]
return

vab:
    send % "{bs " StrLen($.value(0))  "}"
    loc:=RegExReplace(brQ($.value(1)), "i) ?breast","")
        ,route:=InStr(loc, "IQ")?"inner":"outer"
    txt=
(
Procedure name: vacuum-assisted stereotactic breast biopsy.
Target: grouped microcalcifications at %loc% breast, categorized as 4 on prior mammographic report.
Equipment: 10-gauge vacuum-assisted EnCor breast biopsy system.
Route: decubitus position, from %route% aspect of breast.
Sample mode: full-size, normal density.
Specimen: more than 12 tissue cores.
Biopsy clip: deployed without significant immediate migration.

Procedure:
- Patient positioning. Stereotactic localization of the target.
- Skin disinfection. Local anesthesia with 6ml of Xylocaine.
- Skin incision. Insert needle. Perform biopsy.
- Post-biopsy mammography shows nearly total removal of the target microcalcifications.
- Specimen mammography shows microcalcifications within the tissue cores.
- Suggest short term follow up with mammography.
)
    editHwnds:=getSimpleRisEditHwnds()
        ,Edit_SetText(editHwnds[2], t:=RegExReplace(txt,"\n","`r`n"))
        ,Edit_SetText(editHwnds[1], t)
        ,setReportText(txt
        , "Vacuum-assisted stereotactic biopsy is performed for the microcalcifications at " loc " breast. The pathologic diagnosis is pending.", "",1)
return

;~ :*:brloc::
;~ checkRis(RisState)
;~ gosub renewRisReports
;~ txt=
;~ (
;~ Needle localization of the grouped microcalcifications at left UOQ was performed smoothly using a 20G needle and hookwire marking system:
;~ - The tip of the hook wire passed the targeted microcalcifications about 1.5cm.
;~ - The patient stood well in the procedure.
;~ - Specimen mammogram showed a piece of breast tissue containing the same targeted microcalcifications.
;~ )
;~ controlsettext,,% RegExReplace(txt,"\r?\n","`r`n"),% "ahk_id " RisReports[1,1]
;~ controlsettext,,Hookwire needle localization of the grouped microcalcifications at left UOQ.,% "ahk_id " RisReports[1,2]
;~ return

brloc:
    send % "{bs " StrLen($.value(0))  "}"
    use_dye:=!!InStr($.value(0), "locd")
        ,loc:=RegExReplace(brQ($.value(1)), "i) ?breast","")
        ,route:=InStr(loc, "IQ")?"ML":"LM"
        ,targetOption:={g: "grouped microcalcifications", s: "segmental microcalcifications", r: "regional microcalcifications", n: "nodule", c: "biopsy clip"}
        ,target:= targetOption.haskey($.value(2))?targetOption[$.value(2)]:"grouped microcalcifications"

    if(use_dye)
        txt=
(
Procedure name: dye/needle localization of breast.
Target: %target% at %loc% breast.
Equipment: 20G needle and hookwire marking system.
Dye: Patent Blue V.
Route: %route%.

Procedure:
- Inject dye. The tip of the hook wire passed the targeted microcalcifications.
- The patient stood well in the procedure.
- Specimen mammogram showed a piece of breast tissue containing the same targeted microcalcifications.
)
    else
        txt=
(
Procedure name: needle localization of breast.
Target: %target% at %loc% breast.
Equipment: 20G needle and hookwire marking system.
Route: %route%.

Procedure:
- The tip of the hook wire passed the targeted microcalcifications.
- The patient stood well in the procedure.
- Specimen mammogram showed a piece of breast tissue containing the same targeted microcalcifications.
)

    editHwnds:=getSimpleRisEditHwnds()
        ,Edit_SetText(editHwnds[2], t:=RegExReplace(txt,"\n","`r`n"))
        ,Edit_SetText(editHwnds[1], t)
        ,setReportText(txt
        ,  (use_dye?"Dye/h":"H") "ookwire needle localization of the " target " at " loc " breast.", "", 1)
return

;relative term
:B0:mom::
    sendByClipboard("mother" A_EndChar,3)
return
:B0:sis::
    sendByClipboard("sister" A_EndChar,3)
return
:B0:gmo::
    sendByClipboard("grandmother" A_EndChar,3)
return
:B0:mat::
    sendByClipboard("maternal" A_EndChar,3)
return
:B0:pat::
    sendByClipboard("paternal" A_EndChar,3)
return
:B0:au::
    sendByClipboard("aunt" A_EndChar,2)
return
:B0:cou::
    sendByClipboard("cousin" A_EndChar,3)
return
:B0:dau::
    sendByClipboard("daughter" A_EndChar,3)
return

:*B0:mmm::
    sendbyclipboard("", 2)
    run, % "RadTemplate.exe Staging\Mammography.txt",% ".\RadTemplate"
return

:*B0:vabb::
    sendByClipboard("vacuum-assisted stereotactic biopsy",3)
return
:*B0:vabc::
    sendByClipboard("status post vacuum-assisted stereotactic biopsy with clip retention at",3)
return

#If (__is_CH && WinActive("webcvis/MJB ahk_exe iexplore.exe"))

    +UP::
    ^1::
        ; Prepends the mammography screening BI-RADS 0 indication string to the report
        activeIE := WinExist("A")
        wb := WBGet("ahk_id " activeIE)
        if (exam := wb.document.getElementById("exam")) {
            val := exam.value
            ; ^1 logic
            exam.value := "Indication: mammography report of BI-RADS 0. `n`n" val
            exam.fireEvent("onchange")
        }
    return

    Up::
    Down::
        activeIE := WinExist("A")
        BreastUSOCR_CacheRisStudyPageHwnd(activeIE)
        MouseGetPos, mx, my

        dbg := "[" A_ThisHotkey "] mouse=(" mx "," my ")"
        pacsHwnd := BreastUSOCR_FindInfinittViewerForActivation(viewerX, viewerY, viewerW, viewerH, dbg)
        if !pacsHwnd {
            ToolTip, % dbg . " -> NO VIEWER FOUND"
            SetTimer, _ClearPacsDebugTip, -4000
            return
        }

        winactivate, ahk_id %pacsHwnd%
        WinWaitActive, ahk_id %pacsHwnd%,,1
        dbg .= " | activated=" (!ErrorLevel ? "1" : "0(timeout)")
        if !ErrorLevel
            BreastUSOCR_CacheInfinittViewerHwnd(pacsHwnd)

        ; Always move to center of viewer: cursor may land on a non-scrollable
        ; sub-area (thumbnail strip, toolbar) even when inside the window rect
        targetX := viewerX + viewerW // 2
        targetY := viewerY + viewerH // 2
        MouseMove, %targetX%, %targetY%, 0
        dbg .= " | viewerRect=(" viewerX "," viewerY "," viewerW "x" viewerH ") -> moved to (" targetX "," targetY ")"

        ; Focus the control under the cursor, small delay, then send the key
        MouseGetPos, , , , viewportCtrl
        MouseGetPos,mx2,my2
        ControlFocus, %viewportCtrl%, ahk_id %pacsHwnd%
        dbg .= " | ctrl=" viewportCtrl

        ; ToolTip, %dbg%
        ; clipboard := dbg
        ; SetTimer, _ClearPacsDebugTip, -4000

        Sleep, 80
        send % "{" A_ThisHotkey "}"

        if (monitors.length() > 1) {
            risIE := BreastUSOCR_GetCachedRisStudyPageHwnd()
            if (!risIE)
                risIE := activeIE
            winactivate, % "ahk_id " risIE
            MouseMove, % mx, % my, 0
        }
    return
#if

BreastUSOCR_FindInfinittViewerForActivation(ByRef viewerX, ByRef viewerY, ByRef viewerW, ByRef viewerH, ByRef dbg) {
    if (pacsHwnd := BreastUSOCR_GetCachedInfinittViewerHwnd()) {
        WinGetPos, viewerX, viewerY, viewerW, viewerH, ahk_id %pacsHwnd%
        dbg .= " | cached hwnd=" pacsHwnd " pos=(" viewerX "," viewerY "," viewerW "x" viewerH ")"
        return pacsHwnd
    }

    viewers := []
    for k, hwnd in WinGetList("INFINITT PACS ahk_exe G3PACS.exe", "", "", "", "off") {
        if BreastUSOCR_IsInfinittViewerHwnd(hwnd)
            viewers.Push(hwnd)
    }
    if !viewers.length() {
        for k, hwnd in WinGetList("ahk_exe G3PACS.exe", "", "", "", "off") {
            if BreastUSOCR_IsInfinittViewerHwnd(hwnd)
                viewers.Push(hwnd)
        }
    }
    dbg .= " | viewers=" viewers.length()
    if !viewers.length() {
        if IsFunc("FindInfinittViewerHwnd") {
            pacsHwnd := FindInfinittViewerHwnd()
            if BreastUSOCR_IsInfinittViewerHwnd(pacsHwnd) {
                WinGetPos, viewerX, viewerY, viewerW, viewerH, ahk_id %pacsHwnd%
                BreastUSOCR_CacheInfinittViewerHwnd(pacsHwnd)
                dbg .= " | fallback hwnd=" pacsHwnd " pos=(" viewerX "," viewerY "," viewerW "x" viewerH ")"
                return pacsHwnd
            }
        }
        return 0
    }

    ; Find leftmost viewer by screen X position
    pacsHwnd := 0
    minX := 999999
    for k, v in viewers {
        WinGetPos, vx, vy, vw, vh, ahk_id %v%
        dbg .= " | hwnd=" v " cls=" WinGetClass(v) " pos=(" vx "," vy "," vw "x" vh ")"
        if (vx < minX) {
            minX := vx
            pacsHwnd := v
            viewerX := vx, viewerY := vy, viewerW := vw, viewerH := vh
        }
    }
    BreastUSOCR_CacheInfinittViewerHwnd(pacsHwnd)
    return pacsHwnd
}

_ClearPacsDebugTip:
    ToolTip
return

;; breast US
:B0:cysb::
    sendByClipboard("small, oval, hypoechoic to anechoic lesion(s) with distinct margin in bilateral breasts, r/o fibrocystic change and/or fibroadenoma." A_EndChar,4)
return
:B0:cysl::
    sendByClipboard("small, oval, hypoechoic to anechoic lesion(s) with distinct margin in left breast, r/o fibrocystic change and/or fibroadenoma." A_EndChar,4)
return
:B0:cysr::
    sendByClipboard("small, oval, hypoechoic to anechoic lesion(s) with distinct margin in right breast, r/o fibrocystic change and/or fibroadenoma." A_EndChar,4)
return

class breastUS_SendPrint extends SetTimerClass {
    __New(){
        global __is_CH

        if !__is_CH
            return

        this.risIEs:=risIEs:=WinGetList("webcvis/MJB ahk_exe iexplore.exe")
        if !risIEs.length()
            return

        ;~ this.ShellHook:=this.WinShellHook.bind(this)
        ;~ WinHook.Shell.Add(this.ShellHook,,, "iexplore.exe",1)

        this.risIE1:=risIE1:=risIEs[1]
        winactivate,% "ahk_id " risIE1
        WinWaitActive,% "ahk_id " risIE1,,2
        this.stage:=1 ; wait duplicate
        ; duplicate
        ;~ send ^n

        this.risIE1_wb:=risIE1_wb:=this.getWb(risIE1)
        if InStr(risIE1_wb.document.getElementById("printSelectButtonImage").src, "error")
            risIE1_wb.document.getElementById("printSelectButton").click()
        if(GetKeyState("Alt")){
            ShowToolTip("Alt pressed: not sending report")
        }else
            risIE1_wb.document.getElementById("saveSelectButton").click()
        this.currentFoxitReaderCount:=this.CountFoxitReaders()
        this.setTimer("printReport", -500)
    }

    getWb(hWnd){
        for wb in ComObjCreate("Shell.Application").Windows()
            if (wb.hwnd=hWnd)
                return wb

    }

    WinShellHook(hWnd, win_title, win_class, win_exe, win_event){
        if(this.stage=1 && win_event=1){
            this.risIE2:=hWnd
            this.risIE2_wb:=this.getWb(hWnd)
            this.SetTimer("clickNextStudy", -300)
            this.stage:=2  ; wait pacs open win
        }else if(this.stage=2 && win_event=1){
            WinClose,% "ahk_id " hWnd
        }
    }
    ClickNextStudy(){
        try{
            nextrow:=this.risIE2_wb.document.getElementById("nextrow")
            __:=nextrow.id
            nextrow.click()
            this.stage:=3
        }catch
            this.SetTimer("clickNextStudy", -300)
    }

    printReport(){
        try{
            __:=this.risIE1_wb.document.documentElement.innerHTML
            ;~ showToolTip(this.risIE1_wb.locationURL)
            if (__="") && (this.CountFoxitReaders() > this.currentFoxitReaderCount)
                throw Exception("no innerHTML")
            this.SetTimer("printReport", -500)
        }catch{  ; pdf document
            winactivate,% "ahk_id " this.risIE1
            WinWaitActive,% "ahk_id " this.risIE1,,2
            ;~ Sleep 3000
            ;~ send % "^p"
            winwait,Print ahk_class #32770,,60
            if !ErrorLevel
                ControlClick,OK,Print ahk_class #32770
            this.setTimer("closePrint", -2000)
        }
    }

    ClosePrint(){
        global CH_RIS
        this.DisposeTimers()
        WinClose,% "ahk_id " this.risIE1
        settimer,closeFoxitReaders,-2000
        ;~ winactivate,webcvis/MJB ahk_exe iexplore.exe
        winactivate,% "ahk_id " CH_RIS.ris_list_wb.wb.hwnd
    }

    CountFoxitReaders(){
        i:=0
        for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name = 'Foxit Reader.exe'")
            i++
        return i
    }

}

closeFoxitReaders:
    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where name = 'Foxit Reader.exe'")
        Taskkill(process.ProcessID)
return

CH_MammoPacsSendViewerKey(keyName){
    SendInput, % "{" keyName "}"
}

CH_MammoPacsQueuePostViewKeys(){
    SetTimer, CH_MammoPacsPostViewQ, Off
    SetTimer, CH_MammoPacsPostViewInvert, Off
    SetTimer, CH_MammoPacsPostViewQ, -500
}

CH_MammoPacsPostViewQ:
    if !(__is_CH && WinActive("ahk_exe G3PACS.exe"))
        return
    SendLevelChange("q")
    SetTimer, CH_MammoPacsPostViewInvert, -500
return

CH_MammoPacsPostViewInvert:
    if !(__is_CH && WinActive("ahk_exe G3PACS.exe"))
        return
    SendLevelChange("^x")
return

#if __is_CH && WinActive("ahk_exe G3PACS.exe")
    1::
    2::
        ; The scoped PACS hotkeys supersede dynamic_hotstring's global 1/2
        ; hooks, so explicitly keep its typed buffer in sync.
        dynamic_hotstring(A_ThisHotkey, "", "CALLBACK")
        if dynamic_hotstring("", "", "MAMMO_TITLE_PENDING") {
            SetTimer, CH_MammoPacsPostViewQ, Off
            SetTimer, CH_MammoPacsPostViewInvert, Off
            if (WinGetClass(getFocusedHwnd())~="i)edit|combo")
                SendInput, % A_ThisHotkey
            return
        }
        if (WinGetClass(getFocusedHwnd())~="i)edit|combo"){
            ; The physical key was already forwarded to the typed buffer.
            ; SendLevelChange would feed the synthetic copy into it again.
            SendInput, % A_ThisHotkey
            return
        }
        CH_MammoPacsSendViewerKey("Numpad" A_ThisHotkey)
        CH_MammoPacsQueuePostViewKeys()
    return
    ~numpad2::
    ~numpad1::
        dynamic_hotstring("Numpad" RegExReplace(A_ThisHotkey, "\D"), "", "CALLBACK")
        if dynamic_hotstring("", "", "MAMMO_TITLE_PENDING") {
            SetTimer, CH_MammoPacsPostViewQ, Off
            SetTimer, CH_MammoPacsPostViewInvert, Off
            return
        }
        if (WinGetClass(getFocusedHwnd())~="i)edit|combo"){
            return
        }
        CH_MammoPacsQueuePostViewKeys()
    return
#if

#if % __is_CH
    ^!1:: ; den3 birad1
    ^!2:: ; den3 birad2
    ^#1:: ; den 4 birad1
    ^#2:: ; den 4 birad2
        if !(WinActive("ahk_exe G3PACS.exe") || WinActive("ahk_exe iexplore.exe") || WinActive("simple RIS ahk_class AutoHotkeyGUI"))
            return
        thishotkey:=A_ThisHotkey
        RegExMatch(thishotkey, "\d", mammoScreenBIRADS)
        mammoScreenDen:=3+(InStr(thishotkey, "#")?1:0)
        gosub fastMammoScreenReport
    return
    ^!3:: ; den2 birad1
    ^!4:: ; den2 birad2
    ^#3:: ; den 1 birad1
    ^#4:: ; den 1 birad2
        if !(WinActive("ahk_exe G3PACS.exe") || WinActive("ahk_exe iexplore.exe") || WinActive("simple RIS ahk_class AutoHotkeyGUI"))
            return
        thishotkey:=A_ThisHotkey
        RegExMatch(thishotkey, "\d", mammoScreenBIRADS)
        mammoScreenBIRADS-=2
        mammoScreenDen:=2-(InStr(thishotkey, "#")?1:0)
        gosub fastMammoScreenReport
    return

#if

#if __is_CH && WinActive("ahk_exe G3PACS.exe")
    F1::
    F2::
    +F1::
    +F2::
        thishotkey:=A_ThisHotkey
        RegExMatch(thishotkey, "\d", mammoScreenBIRADS)
        mammoScreenDen:=3+(InStr(thishotkey, "+")?1:0)
        gosub fastMammoScreenReport
    return
    F3::
    F4::
    +F3::
    +F4::
        thishotkey:=A_ThisHotkey
        RegExMatch(thishotkey, "\d", mammoScreenBIRADS)
        mammoScreenBIRADS-=2
        mammoScreenDen:=2-(InStr(thishotkey, "+")?1:0)
        gosub fastMammoScreenReport
    return
#if

:*B0:mic0::
    sendByClipboard("no suspicious microcalcifications.",3)
return
:*:usbxr::
    t=
(
Ultrasound-guided large core biopsy for the right  breast lesion was performed by 14G biopsy gun smoothly. Total 3 specimens were retrieved.
The patient tolerated the procedure well.
Suggest persue final result.
)
    sendByClipboard(t)
    send % "{left 161}"
return

:*:usbxl::
    t=
(
Ultrasound-guided large core biopsy for the left  breast lesion was performed by 14G biopsy gun smoothly. Total 3 specimens were retrieved.
The patient tolerated the procedure well.
Suggest persue final result.
)
    sendByClipboard(t)
    send % "{left 161}"
return

:*:dctr::
    t=
(
Ductography of right breast is performed smoothly after identifying the discharging orifice:
> The breast is heterogeneously dense, which could obscure detection of small masses.
> Some bloody discharge was noted after squeezing the breast.
> The catheter is selectively inserted to the orifice of discharge with injection about 0.3 mL contrast medium.
> It shows opacification of the segmental ducts at right lower inner breast with ductal ectasia. A 0.3cm filling defect is noted in the opacified lactiferrous duct.

Impression:
Ductal ectasia with indeterminate filling defect in right LIQ breast.
)
    sendByClipboard(t)
return

:*:dctl::
    t=
(
Ductography of left breast is performed smoothly after identifying the discharging orifice:
> The breast is heterogeneously dense, which could obscure detection of small masses.
> Some bloody discharge was noted after squeezing the breast.
> The catheter is selectively inserted to the orifice of discharge with injection about 0.3 mL contrast medium.
> It shows opacification of the segmental ducts at left lower inner breast with ductal ectasia. A 0.3cm filling defect is noted in the opacified lactiferrous duct.

Impression:
Ductal ectasia with indeterminate filling defect in left LIQ breast.
)
    sendByClipboard(t)
return

:B0:hoh::
    sendByClipboard("hypoechoic" A_EndChar,3)
return
:B0:heh::
    sendByClipboard("hyperechoic" A_EndChar,3)
return
:B0:ioh::
    sendByClipboard("isoechoic" A_EndChar,3)
return
:B0:anh::
    sendByClipboard("anechoic" A_EndChar,3)
return

::u0::
    t=
(
No definite suspicious focal lesion in bilateral breasts.
- No definite lymphadenopathy.

Impression:
BI-RADS category 1, negative finding.
)
    sendByClipboard(t)
return

#InstallKeybdHook
#MaxHotkeysPerInterval 999999
#include <risimpax>
#include <EBMViewer>
#include <Edit>
#include <hash>
#include <WM_COPYDATA>
#include <getFocusedHwnd>
#include <dcm4che>
#include <RadiologyReportTemplate>
#include <resetHotstringBuffer>
#include <showToolTip>
#include <OpText>
#include <portallib>
#include <RegexSplit>
#include <ReportImpression>
#Hotstring, SI
SendMode Input
;~ *.::
;~ *numpaddot::
;~ send {.}
;~ return

;~ $-::
;~ if winactive("放射線資訊管理系統") || winactive("ahk_class SleipnirMainWindow") || winactive("ahk_class SciTEWindow") || winactive("ahk_exe simpleRIS.exe")
;~ send %a_space%{left}{right}
;~ else
;~ send '
;~ return

;~ ^-::
;~ if winactive("放射線資訊管理系統") || winactive("ahk_class SleipnirMainWindow") || winactive("ahk_class SciTEWindow") || winactive("ahk_exe simpleRIS.exe")
;~ send '
;~ else
;~ send "
;~ return

RisGroup:
    groupadd,RisGroup,放射線資訊管理系統(Radiology Information System)
    groupadd,RisGroup,simple RIS ahk_class AutoHotkeyGUI
    groupadd,SimpleRisHotkeys,simple RIS ahk_class AutoHotkeyGUI
    groupadd,SimpleRisHotkeys,simple RIS3 ahk_class AutoHotkeyGUI
    groupadd,SimpleRisHotkeys,simpleRISsimpleEdit ahk_class AutoHotkeyGUI
    groupadd,MammoIndicationHotkeys,simple RIS ahk_class AutoHotkeyGUI
    groupadd,MammoIndicationHotkeys,simple RIS3 ahk_class AutoHotkeyGUI
    groupadd,MammoIndicationHotkeys,simpleRISsimpleEdit ahk_class AutoHotkeyGUI
    if __is_CH
        groupadd,MammoIndicationHotkeys,ahk_exe G3PACS.exe
;~ groupadd,RisGroup,ahk_exe simpleRIS.exe
return

; IE web RIS does not feed RisImpaxPolling — CH_RIS posts 0x1122 only to
; simpleRIS_main when its IE DOM observer detects a new accession. Poll
; CH_RIS.accNo directly so the PDF DB lookup window follows IE navigation
; the same way simpleRIS does (it actively pulls CH_RIS on every event).
MammoPdfDB_PollAccNo:
    if (MammoPdfDB_PollAccNo_Busy)
        return
    if !__is_CH || !IsObject(CH_RIS)
        return
    MammoPdfDB_PollAccNo_Busy := true
    SetTimer, MammoPdfDB_PollAccNo, Off
    try {
        Mammo_CH_CallMethodQuick("check_wb", 300)
        curAcc := Mammo_CH_GetAccNoQuick(300)
        if (curAcc != "" && curAcc != MammoPdfDB_PriorAcc) {
            MammoPdfDB_PriorAcc := curAcc
            Mammo_CH_CallMethodQuick("refresh_info", 800)
            Mammo_CH_ScheduleFastReportPreload()
            MammoPdfDB_FireOnRisChange()
        }
    } catch e {
    }
    MammoPdfDB_PollAccNo_Busy := false
    SetTimer, MammoPdfDB_PollAccNo, 1000
return

Mammo_CH_PreloadFastReportCache:
    if (Mammo_CH_PreloadFastReportCache_Busy)
        return
    Mammo_CH_PreloadFastReportCache_Busy := true
    try {
        Mammo_CH_BuildFastReportCache()
    } catch e {
    }
    Mammo_CH_PreloadFastReportCache_Busy := false
return

Mammo_CH_GetAccNoQuick(timeout:=300) {
    return Mammo_CH_GetScalarQuick("accNo", timeout)
}

Mammo_CH_GetScalarQuick(name, timeout:=300) {
    global CH_RIS, __CH_RIS_CLIENT
    if (__CH_RIS_CLIENT && IsFunc("CH_RIS_Call")) {
        r := CH_RIS_Call("get", {name: name}, true, timeout)
        return (IsObject(r) && r.ok) ? Trim("" r.value) : ""
    }
    try return Trim("" CH_RIS[name])
    return ""
}

Mammo_CH_CallMethodQuick(name, timeout:=300, args*) {
    global CH_RIS, __CH_RIS_CLIENT
    if (__CH_RIS_CLIENT && IsFunc("CH_RIS_Call")) {
        r := CH_RIS_Call("call_method", {name: name, args: args}, true, timeout)
        return (IsObject(r) && r.ok) ? r.value : ""
    }
    try return CH_RIS[name](args*)
    return ""
}

Mammo_CH_ResetQuick(timeout:=800) {
    global CH_RIS, __CH_RIS_CLIENT
    if (__CH_RIS_CLIENT && IsFunc("CH_RIS_Call")) {
        r := CH_RIS_Call("reset", {wait: 1, reset_simpleris: 0}, true, timeout)
        return (IsObject(r) && r.ok)
    }
    try {
        CH_RIS.reset(1)
        return true
    }
    return false
}

Mammo_CH_ActivateQuick(timeout:=800) {
    global CH_RIS, __CH_RIS_CLIENT
    if (__CH_RIS_CLIENT && IsFunc("CH_RIS_Call")) {
        r := CH_RIS_Call("activate", "", true, timeout)
        return (IsObject(r) && r.ok)
    }
    try {
        CH_RIS.activate()
        return true
    }
    return false
}

Mammo_CH_WbHwndQuick(timeout:=300) {
    global CH_RIS, __CH_RIS_CLIENT
    if (__CH_RIS_CLIENT && IsFunc("CH_RIS_Call")) {
        r := CH_RIS_Call("wb_hwnd", "", true, timeout)
        return (IsObject(r) && r.ok) ? r.value : ""
    }
    try return CH_RIS.wb.hwnd
    return ""
}

Mammo_CH_GetPacsHxDataQuick(timeout:=800) {
    global CH_RIS, __CH_RIS_CLIENT
    if (__CH_RIS_CLIENT && IsFunc("CH_RIS_Call")) {
        r := CH_RIS_Call("get_pacs_hx_data", "", true, timeout)
        return (IsObject(r) && r.ok) ? r.value : ""
    }
    try return CH_RIS.pacs_hx.data
    return ""
}

Mammo_CH_GetPacsHxColNoQuick(timeout:=800) {
    global CH_RIS, __CH_RIS_CLIENT
    if (__CH_RIS_CLIENT && IsFunc("CH_RIS_Call")) {
        r := CH_RIS_Call("get_pacs_hx_colno", "", true, timeout)
        return (IsObject(r) && r.ok) ? r.value : ""
    }
    try return CH_RIS.pacs_hx_colNo
    return ""
}

MammoPdfDB_StartupSummary:
    if (!MammoPdfDB_AutoShow)
        return
    s := MammoPdfDB_FormatLastSummary()
    Gui, MammoPdfSummary: Destroy
    Gui, MammoPdfSummary: New, +AlwaysOnTop +ToolWindow +LabelMammoPdfSummary, Mammo PDF DB
    Gui, MammoPdfSummary: Margin, 16, 12
    Gui, MammoPdfSummary: Font, s10 w600, Segoe UI
    Gui, MammoPdfSummary: Add, Text,, Mammo PDF DB — last update
    if (s.ts != "") {
        Gui, MammoPdfSummary: Font, s8 w400 cGray, Segoe UI
        Gui, MammoPdfSummary: Add, Text,, % s.ts
    }
    Gui, MammoPdfSummary: Font, s10 w400, Consolas
    Gui, MammoPdfSummary: Add, Text,, % s.body
    Gui, MammoPdfSummary: Font, s9 w400, Segoe UI
    Gui, MammoPdfSummary: Add, Button, w100 h28 Default gMammoPdfSummaryClose vMammoPdfSummaryOK, OK
    Gui, MammoPdfSummary: Show, AutoSize Center
    GuiControl, MammoPdfSummary: Focus, MammoPdfSummaryOK
return

MammoPdfSummaryClose:
MammoPdfSummaryEscape:
MammoPdfSummaryGuiClose:
    Gui, MammoPdfSummary: Destroy
return

MammoRisHoros_IsBreastUS(examName, examType := "") {
    haystack := examName " " examType
    if InStr(haystack, "乳房超音波")
        return true
    if (haystack ~= "i)\bUS5B\b")
        return true
    if (haystack ~= "i)breast.*ultra|ultra.*breast")
        return true
    return false
}

BreastUSOCR_ShouldRightActivateRIS() {
    activeHwnd := WinExist("A")
    if !BreastUSOCR_IsInfinittViewerHwnd(activeHwnd)
        return false
    BreastUSOCR_CacheInfinittViewerHwnd(activeHwnd)
    if BreastUSOCR_FocusedControlIsTextInput()
        return false
    return true
}

BreastUSOCR_IsActiveInfinittViewer() {
    activeHwnd := WinExist("A")
    return BreastUSOCR_IsInfinittViewerHwnd(activeHwnd)
}

BreastUSOCR_IsInfinittViewerHwnd(hwnd) {
    if !hwnd
        return false
    if !WinExist("ahk_id " hwnd)
        return false

    if IsFunc("IsInfinittViewerWindow") && IsInfinittViewerWindow(hwnd)
        return true

    title := WinGetTitle(hwnd)
    exe := WinGet("ProcessName", hwnd)
    if InStr(title, "INFINITT")
        return true
    return (exe = "G3PACS.exe" || exe = "WEBVIE~1.EXE" || exe = "WebViewerComSrvEC.exe")
}

BreastUSOCR_CacheInfinittViewerHwnd(hwnd := "") {
    global BreastUSOCR_CachedInfinittViewerHwnd
    if (hwnd = "")
        hwnd := WinExist("A")
    if BreastUSOCR_IsInfinittViewerHwnd(hwnd) {
        BreastUSOCR_CachedInfinittViewerHwnd := hwnd
        return hwnd
    }
    return 0
}

BreastUSOCR_GetCachedInfinittViewerHwnd() {
    global BreastUSOCR_CachedInfinittViewerHwnd
    if BreastUSOCR_IsInfinittViewerHwnd(BreastUSOCR_CachedInfinittViewerHwnd)
        return BreastUSOCR_CachedInfinittViewerHwnd
    BreastUSOCR_CachedInfinittViewerHwnd := 0
    return 0
}

BreastUSOCR_IsRisStudyPageHwnd(hwnd) {
    if !hwnd
        return false
    return WinExist("webcvis/MJB ahk_id " hwnd)
}

BreastUSOCR_CacheRisStudyPageHwnd(hwnd := "") {
    global BreastUSOCR_CachedRisStudyHwnd
    if (hwnd = "")
        hwnd := WinExist("A")
    if BreastUSOCR_IsRisStudyPageHwnd(hwnd) {
        BreastUSOCR_CachedRisStudyHwnd := hwnd
        return hwnd
    }
    return 0
}

BreastUSOCR_GetCachedRisStudyPageHwnd() {
    global BreastUSOCR_CachedRisStudyHwnd
    if BreastUSOCR_IsRisStudyPageHwnd(BreastUSOCR_CachedRisStudyHwnd)
        return BreastUSOCR_CachedRisStudyHwnd
    BreastUSOCR_CachedRisStudyHwnd := 0
    return 0
}

BreastUSOCR_FocusedControlIsTextInput() {
    focusedHwnd := getFocusedHwnd()
    if !focusedHwnd
        return false
    class := WinGetClass(focusedHwnd)
    return (class ~= "i)edit|combo|scintilla|rich")
}

BreastUSOCR_IsCurrentStudy() {
    global CH_RIS, __is_CH

    if !__is_CH
        return false
    if !IsObject(CH_RIS)
        return false

    Mammo_CH_CallMethodQuick("check_wb", 300)
    Mammo_CH_CallMethodQuick("refresh_info", 800)

    examName := Mammo_CH_GetScalarQuick("examName", 300)
    examType := Mammo_CH_GetScalarQuick("examtype", 300)
    return MammoRisHoros_IsBreastUS(examName, examType)
}

BreastUSOCR_ActivateRisStudyPage() {
    global CH_RIS

    if (risIE := BreastUSOCR_GetCachedRisStudyPageHwnd()) {
        WinActivate, ahk_id %risIE%
        return true
    }

    if IsObject(CH_RIS) {
        if Mammo_CH_ActivateQuick(800) {
            wbHwnd := Mammo_CH_WbHwndQuick(300)
            if (wbHwnd)
                BreastUSOCR_CacheRisStudyPageHwnd(wbHwnd)
            return true
        }
    }

    if (risIE := WinExist("webcvis/MJB ahk_exe iexplore.exe")) {
        BreastUSOCR_CacheRisStudyPageHwnd(risIE)
        WinActivate, ahk_id %risIE%
        return true
    }

    if (simpleRis := WinExist("simple RIS ahk_class AutoHotkeyGUI")) {
        guiHwnds := getSimpleRisGuiHwnds()
        editHwnds := getSimpleRisEditHwnds()
        targetHwnd := guiHwnds.Length() >= 2 ? guiHwnds[2] : simpleRis
        WinActivate, ahk_id %targetHwnd%
        if (editHwnds.Length() >= 2)
            ControlFocus,, % "ahk_id " editHwnds[2]
        return true
    }
    return false
}

BreastUSOCR_ActivateSimpleRis() {
    guiHwnds := getSimpleRisGuiHwnds()
    editHwnds := getSimpleRisEditHwnds(guiHwnds)
    targetHwnd := guiHwnds[2] ? guiHwnds[2] : guiHwnds[1]
    targetEdit := editHwnds[2] ? editHwnds[2] : editHwnds[1]
    if !targetHwnd
        return false
    WinFocus(targetHwnd, targetEdit)
    return !!WinActive("ahk_id " targetHwnd)
}

BreastUSOCR_CloseReviewGuis() {
    WinClose, Review OCR Lesions ahk_class AutoHotkeyGUI
    WinClose, Breast US OCR Review ahk_class AutoHotkeyGUI
}

BreastUSOCR_CloseAndReturnToSimpleRis() {
    BreastUSOCR_CloseReviewGuis()
    BreastUSOCR_ActivateRisStudyPage()
    Sleep 100
    return BreastUSOCR_ActivateSimpleRis()
}

CloseBreastAssistiveGuis() {
    try MammoPdfDB_CloseLookupWindows()
    Gui, MammoPdfSummary: Destroy
    WinClose, Mammo PDF DB ahk_class AutoHotkeyGUI
    WinClose, Mammo PDF lookup
    BreastUSOCR_CloseReviewGuis()
}

BreastUSOCR_OnAccNoChanged() {
    global CH_RIS, __is_CH
    static lastAcc := ""

    if !__is_CH
        return
    if !IsObject(CH_RIS)
        return

    Mammo_CH_CallMethodQuick("check_wb", 300)
    Mammo_CH_CallMethodQuick("refresh_info", 800)

    accNo := Mammo_CH_GetAccNoQuick(300)
    if (accNo = "" || accNo = lastAcc)
        return
    lastAcc := accNo

    examName := Mammo_CH_GetScalarQuick("examName", 300)
    examType := Mammo_CH_GetScalarQuick("examtype", 300)
    if !MammoRisHoros_IsBreastUS(examName, examType)
        return

    BreastUSOCR_LaunchReviewGui(accNo)
}

BreastUSOCR_CheckCurrentStudy:
    BreastUSOCR_OnAccNoChanged()
return

BreastUSOCR_LaunchReviewGui(accNo := "") {
    global CH_RIS, __is_CH

    if !__is_CH
        return
    if !IsObject(CH_RIS)
        return

    Mammo_CH_CallMethodQuick("check_wb", 300)
    Mammo_CH_CallMethodQuick("refresh_info", 800)

    if (accNo = "")
        accNo := Mammo_CH_GetAccNoQuick(300)
    if (accNo = "") {
        MsgBox, 48, Breast US OCR, No current RIS accession found.
        return
    }

    chartNo := ""
    studyDate := ""
    patName := ""
    examName := ""
    examTime := ""
    chartNo := Mammo_CH_GetScalarQuick("chartNo", 300)
    if (chartNo = "")
        chartNo := Mammo_CH_GetScalarQuick("patno", 300)
    studyDate := Mammo_CH_GetScalarQuick("examDate", 300)
    patName := Mammo_CH_GetScalarQuick("patname", 300)
    if (patName = "")
        patName := Mammo_CH_GetScalarQuick("namec", 300)
    if (patName = "")
        patName := Mammo_CH_GetScalarQuick("patName", 300)
    examName := Mammo_CH_GetScalarQuick("examName", 300)
    examTime := Mammo_CH_GetScalarQuick("examtime", 300)
    if (studyDate = "" && examTime != "")
        studyDate := RegExReplace(SubStr(examTime, 1, 10), "\D", "")

    script := A_ScriptDir "\CH scripts\breast_us_ocr\windows\study_review_gui.ahk"
    if !FileExist(script) {
        MsgBox, 16, Breast US OCR, study_review_gui.ahk not found:`n%script%
        return
    }

    cmd := """" A_AhkPath """ """ script """ --accession """ BreastUSOCR_EscapeArg(accNo) """"
    if (chartNo != "")
        cmd .= " --chart-no """ BreastUSOCR_EscapeArg(chartNo) """"
    if (studyDate != "")
        cmd .= " --study-date """ BreastUSOCR_EscapeArg(studyDate) """"
    if (patName != "")
        cmd .= " --patient-name """ BreastUSOCR_EscapeArg(patName) """"
    if (examName != "")
        cmd .= " --exam-name """ BreastUSOCR_EscapeArg(examName) """"
    if (examTime != "")
        cmd .= " --exam-time """ BreastUSOCR_EscapeArg(examTime) """"
    Run, %cmd%, %A_ScriptDir%
}

BreastUSOCR_EscapeArg(s) {
    return StrReplace("" s, """", "\""")
}

~Esc::
    if (__is_CH && A_ThisHotkey = A_PriorHotkey && A_TimeSincePriorHotkey <= 400)
        BreastUSOCR_CloseAndReturnToSimpleRis()
    ; Waiting for release prevents a held Esc key's auto-repeat from counting as
    ; the second physical press. The tilde preserves normal single-Esc behavior.
    KeyWait, Esc
return

^!u::
    BreastUSOCR_LaunchReviewGui()
return

recentSent:
    recentSent:=false
return

/*
^!t::
ifwinexist,Convert first word
	return
gui,font,s10 Verdana
gui,add,edit,w800 h600 vreport
gui,add,edit,r1 w20 vfirstword,>
gui,add,button,x+5 yp,Convert

gui,show,w850 h650,Convert first word
return
*/

Buttonconvert:
    gui,submit,NoHide
    firstword:=trim(firstword)
    if firstword=>
    {
        report:=regexreplace(report,"\r?\n\d.\s*","`r`n" firstword " ")
        ;~ report:=regexreplace(report,"\r?\n(\d.\s*|\w\s+)([^\n]+\n*)","`r`n" firstword " $2")
        ;~ report:=regexreplace(report,"\r?\n(\d.\s*|\w\s+)(\w+)$",firstword " $2",1)
    }
    guicontrol,,report,% report
    guicontrol,focus,report
    controlsend,Scintilla1,{home}+^{end},Convert first word
return

~!q::
exitapp
return

^!x::suspend

;~ ^!e::
;~ inputbox,addahk
;~ if addahk!=
;~ fileappend,% addahk,% A_ScriptFullPath
;~ reload
;~ return

#ifwinactive,Radiology Information System
        +enter:B0:
        +numpadenter::
            sendByClipboard("`n" bullet, 13)
        return

    #ifwinactive

#ifwinactive,ahk_class SleipnirMainWindow
        ~+enter:B0:
        ~+numpadenter::
            sendByClipboard(bullet, 14)
        return
    #ifwinactive

    ; 健檢中文區
    :*B0:n-::
        sendByClipboard("無顯著異常",1)
    return
    :*B0:rs-::
        sendByClipboard("腎結石",2)
    return
    :*B0:r-::
        sendByClipboard("右側",1)
    return
    :*B0:l-::
        sendByClipboard("左側",1)
    return
    :*B0:b-::
        sendByClipboard("雙側",1)
    return
    :*B0:d-::
        sendByClipboard("退行性變化",1)
    return

    ; history
    :B0:hx::
        sendByClipboard("History:" A_EndChar,2)
    return
    :B0:sp::
        sendByClipboard("status post" A_EndChar,2)
    return
    :B0:r/t::
        sendByClipboard("radiotherapy" A_EndChar,3)
    return
    :B0:c/t::
        sendByClipboard("chemotherapy" A_EndChar,3)
    return
    :B0:lcl::
        sendByClipboard("localization" A_EndChar,3)
    return
    :oB0:hfn::
        sendByClipboard("History: for navigation.`n`n",3)
    return
    :oB0:hfc::
        sendByClipboard("History: for cyberknife.`n`n",3)
    return

    ; exam title
    examTitle:
        if ($.value(1)=""){
            ;~ sendByClipboard($.value(2) "=")
            return
        }

        ;~ sendByClipboard("{bs " StrLen($.value(0)))
        value2:=returnStr?partValue:$.value(2)

        if(value2<3)
            exam:="CT"
        else if(value2<6)
            exam:="MRI"

        if(mod(value2,3)=0)
            contrast:="without/with"
        else if(mod(value2,3)=1)
            contrast:="without"
        else if(mod(value2,3)=2)
            contrast:="with"

        part:=""
        if instr($.value(1),"b")
            part.="brain, "
        if instr($.value(1),"n")
            part.="neck, "
        if instr($.value(1),"c")
            part.="chest, "
        if instr($.value(1),"a")
            part.="abdomen, "
        if instr($.value(1),"p")
            part.="pelvis, "
        if instr($.value(1),"d")
            part.="C-spine, "
        if instr($.value(1),"t")
            part.="T-spine, "
        if instr($.value(1),"l")
            part.="L-spine, "
        if instr($.value(1),"u")
            part.="upper extremity, "
        if instr($.value(1),"v")
            part.="lower extremity, "
        ;~ part:=regexreplace(part,", $")
        ;~ StringReplace, part, part,% ", ",% ", ", UseErrorLevel
        ;~ if errorlevel=1
        ;~ stringreplace,part,part,% ", ",% " and "
        RegExMatch(part,"is)^(.*?)(,?)([\w -]+), $",match)
        if (match2="")
            part:=match3
        else
            part:=match1 " and" match3

        ;~ bs:=strlen($.value(1))+strlen(value2)
        ;~ loop % bs+1
        ;~ send {bs}
        if(returnStr){
            returnStr=%exam% of the %part% %contrast% contrast enhancement shows:
            returnStr.=" `r`n" bullet
            partValue:=""
            return
        }
        Sleep 50
        str:=exam " of the " part " " contrast " contrast enhancement shows:`r`n" bullet
        if (contrast="without" && regexmatch($.value(1),"[cap]") && value2<3)
            str.="Low sensitivity and specificity of non-contrast CT.`r`n" bullet
        send % "{bs " StrLen($.value(0))  "}"
        sendByClipboard(str)
        ;~ sendByClipboard(str, StrLen($.value(0)))
        $:=""
    return

    :oB0:y0::
        sendAndNextLine("This study shows:")
    return

    newline:
        if a_endchar=`n
            sendByClipboard("`n" bullet)
        else
            sendByClipboard(a_endchar)
    return

    sendAndNextLine(txt){
        global bullet
        sendByClipboard(txt "`r`n" bullet, -1)
    }

    :B0:xx::
        sendByClipboard("(非正式報告，僅供參考。)`n" A_EndChar,2)
    return

    ;modality

    :*B0:cta0::
        sendAndNextLine("CT angiography and perfusion scan of brain shows:")
    return
    :*B0:cta1::
        sendAndNextLine("CT angiography of brain shows:")
    return
    :*B0:cta2::
        sendAndNextLine("CT angiography of neck shows:")
    return
    :B0:ctp::
        sendByClipboard("CT perfusion shows" A_EndChar,3)
    return
    :B0:ce::
        sendByClipboard("contrast enhancement" A_EndChar,2)
    return
    :B0:ang::
        sendByClipboard("angiography" A_EndChar,3)
    return
    :B0:us::
        sendByClipboard("ultrasound" A_EndChar,2)
    return
    :B0:emer::
        sendByClipboard("emergency" A_EndChar,4)
    return
    :B0:ctd::
        sendByClipboard("the estimated radiation dose (mSv) of this study is:" A_EndChar,3)
    return

    ;direction
    :B0:qa::
        sendByClipboard("anterior aspect of" A_EndChar,2)
    return
    ;~ ::qal::antero-lateral aspect of
    ;~ ::qam::antero-medial aspect of
    :B0:qc::
        sendByClipboard("cephalic aspect of" A_EndChar,2)
    return
    :B0:qcc::
        sendByClipboard("caudal aspect of" A_EndChar,3)
    return
    :B0:qd::
        sendByClipboard("distal aspect of" A_EndChar,2)
    return
    :B0:qi::
        sendByClipboard("inferior aspect of" A_EndChar,2)
    return
    :B0:ql::
        sendByClipboard("lateral aspect of" A_EndChar,2)
    return
    :B0:qm::
        sendByClipboard("medial aspect of" A_EndChar,2)
    return
    :B0:qp::
        sendByClipboard("posterior aspect of" A_EndChar,2)
    return
    ;~ ::qpl::postero-lateral aspect of
    ;~ ::qpm::postero-medial aspect of
    :B0:qpp::
        sendByClipboard("proximal aspect of" A_EndChar,3)
    return
    :B0:qs::
        sendByClipboard("superior aspect of" A_EndChar,2)
    return

    :B0:cen::
        sendByClipboard("central" A_EndChar,3)
    return
    :B0:ant::
        sendByClipboard("anterior" A_EndChar,3)
    return
    ;~ ::antl::antero-lateral
    ;~ ::antm::antero-medial
    ;~ ::anti::antero-inferior
    ;~ ::ants::antero-superior
    :B0:pos::
        sendByClipboard("posterior" A_EndChar,3)
    return
    ;~ ::posl::postero-lateral
    ;~ ::posm::postero-medial
    ;~ ::posi::postero-inferior
    ;~ ::poss::postero-superior
    :B0:sup::
        sendByClipboard("superior" A_EndChar,3)
    return
    :B0:inf::
        sendByClipboard("inferior" A_EndChar,3)
    return
    :B0:lgt::
        sendByClipboard("longitudinal" A_EndChar,3)
    return
    :B0:prt::
        sendByClipboard("portion" A_EndChar,3)
    return
    :B0:dcb::
        sendByClipboard("decubitus" A_EndChar,3)
    return
    :B0:mid::
        sendByClipboard("middle" A_EndChar,3)
    return

    aspect:
        ;~ loop % strlen($1)+strlen($2)+1
        ;~ send {bs}

        a:=$.value(1),last:="", str:=""
        loop,parse,a
        {
            if (a_loopfield="a")
                str.="antero-"
            else if (a_loopfield="p")
                str.="postero-"
            else if (a_loopfield="s")
                str.="supero-"
            else if (a_loopfield="i")
                str.="infero-"
            else if (a_loopfield="m")
                str.="medio-"
            else if (a_loopfield="l")
                str.="latero-"
            last:=a_loopfield
        }
        str:=SubStr(str,1,-2)
        if last in m,l
            str.="al"
        else
            str.="ior"
        if strlen($.value(2))
            str.=" aspect of"
        send % "{bs " StrLen($.value(0))  "}"
        sendByClipboard(str)
        ;~ sendByClipboard(str, StrLen($.value(0)))
        $:=""
    return

    :B0:spf::
        sendByClipboard("superficial" A_EndChar,3)
    return
    :B0:prp::
        sendByClipboard("peripheral" A_EndChar,3)
    return

    :cB0:I::
        sendByClipboard("I" A_EndChar,1)
    return
    :*B0:i,::
        sendByClipboard("I,",1)
    return
    :*B0:i.::
        sendByClipboard("I.",1)
    return
    :*B0:i;::
        sendByClipboard("I;",1)
    return
    :B0:i::
        sendByClipboard("in" A_EndChar,1)
    return
    :*B0:i\::
        sendByClipboard("i",1)
    return
    :*B0:e\::
        sendByClipboard("e",1)
    return
    :*B0:o\::
        sendByClipboard("o",1)
    return
    :*B0:l\::
        sendByClipboard("l",1)
    return
    :*B0:r\::
        sendByClipboard("r",1)
    return
    :*B0:b\::
        sendByClipboard("b",1)
    return
    :*B0:m\::
        sendByClipboard("m",1)
    return
    :*B0:f\::
        sendByClipboard("f",1)
    return

    :B0:e::
        sendByClipboard("at" A_EndChar,1)
    return
    ;~ ::o::of
    :*B0:n\::
        sendByClipboard("n",1)
    return
    :B0:n::
        sendByClipboard("and" A_EndChar,1)
    return
    :*B0:t\::
        sendByClipboard("t",1)
    return
    :B0:t::
        sendByClipboard("the" A_EndChar,1)
    return
    :*B0:r-::
        sendByClipboard("右側",1)
    return
    :B0:r::
        sendByClipboard("right" A_EndChar,1)
    return
    :*B0:l-::
        sendByClipboard("左側",1)
    return
    :B0:l::
        sendByClipboard("left" A_EndChar,1)
    return
    :B0:o::
        sendByClipboard("of" A_EndChar,1)
    return
    :B0:u/::
        sendByClipboard("upper" A_EndChar,2)
    return
    :B0:v/::
        sendByClipboard("lower" A_EndChar,2)
    return
    :B0:med::
        sendByClipboard("medial" A_EndChar,3)
    return
    :B0:lat::
        sendByClipboard("lateral" A_EndChar,3)
    return
    :B0:pro::
        sendByClipboard("proximal" A_EndChar,3)
    return
    :B0:dis::
        sendByClipboard("distal" A_EndChar,3)
    return

    :B0:bi::
        sendByClipboard("bilateral" A_EndChar,2)
    return
    :B0:b::
        sendByClipboard("bilateral" A_EndChar,1)
    return
    :B0:trs::
        sendByClipboard("transverse" A_EndChar,3)
    return

    :B0:1ry::
        sendByClipboard("primary" A_EndChar,3)
    return
    :B0:2ry::
        sendByClipboard("secondary" A_EndChar,3)
    return

    ;程度
    :B0:sut::
        sendByClipboard("size up to" A_EndChar,3)
    return
    :B0:dif::
        sendByClipboard("difficult" A_EndChar,3)
    return
    :B0:lg::
        sendByClipboard("large" A_EndChar,2)
    return
    :*B0:lg1::
        sendByClipboard("larger",2)
    return
    :B0:mss::
        sendByClipboard("massive" A_EndChar,3)
    return
    :B0:ti::
        sendByClipboard("tiny" A_EndChar,2)
    return
    :B0:sm::
        sendByClipboard("small" A_EndChar,2)
    return
    :B0:ss::
        sendByClipboard("tiny (<6mm)" A_EndChar,2)
    return
    :B0:mm::
        sendByClipboard("small (<10mm)" A_EndChar,2)
    return
    ;~ ::ssn::(Solid nodule(s) smaller than 6 mm do not require routine follow-up in patients at low risk, according to MacMahon, Heber, et al. "Guidelines for management of incidental pulmonary nodules detected on CT images: from the Fleischner Society 2017." Radiology (2017): 161659.)
    :*B0:sm1::
        sendByClipboard("smaller",2)
    return
    :B0:str::
        sendByClipboard("strong" A_EndChar,3)
    return
    :B0:int::
        sendByClipboard("intermediate" A_EndChar,3)
    return
    :B0:sig::
        sendByClipboard("significant" A_EndChar,3)
    return
    :B0:siy::
        sendByClipboard("significantly" A_EndChar,3)
    return
    :B0:mi::
        sendByClipboard("minimal" A_EndChar,2)
    return
    :B0:miy::
        sendByClipboard("minimaly" A_EndChar,3)
    return
    :B0:sli::
        sendByClipboard("slight" A_EndChar,3)
    return
    :B0:sly::
        sendByClipboard("slightly" A_EndChar,3)
    return
    ;~ ::mil::mild
    :*B0:m-::
        sendByClipboard("輕度",1)
    return
    :B0:m::
        sendByClipboard("mild" A_EndChar,1)
    return

    :B0:my::
        sendByClipboard("mildly" A_EndChar,2)
    return

    :*B0:mo-::
        sendByClipboard("中度",2)
    return
    :B0:mo::
        sendByClipboard("moderate" A_EndChar,2)
    return
    :B0:moy::
        sendByClipboard("moderately" A_EndChar,3)
    return

    :*B0:sv-::
        sendByClipboard("重度",2)
    return
    :B0:sv::
        sendByClipboard("severe" A_EndChar,2)
    return
    :B0:bri::
        sendByClipboard("bright" A_EndChar,3)
    return
    :B0:ext::
        sendByClipboard("extensive" A_EndChar,3)
    return
    :B0:lim::
        sendByClipboard("limited" A_EndChar,3)
    return
    :B0:abn::
        sendByClipboard("abnormal" A_EndChar,3)
    return
    :B0:aby::
        sendByClipboard("abnormality" A_EndChar,3)
    return
    :B0:nor::
        sendByClipboard("normal" A_EndChar,3)
    return
    :B0:nap::
        sendByClipboard("normal appearance of" A_EndChar,3)
    return
    :B0:st::
        sendByClipboard("unchanged" A_EndChar,2)
    return
    :*B0:stml::
        sendByClipboard("unchanged but malignancy can not be excluded.",3)
    return
    :*B0:stns::
        sendByClipboard("unchanged, probably non-specific",3)
    return
    :B0:prog::
        sendByClipboard("in progression" A_EndChar,4)
    return
    :B0:inc::
        sendByClipboard("increased" A_EndChar,3)
    return
    :B0:dec::
        sendByClipboard("decreased" A_EndChar,3)
    return
    :B0:ifl::
        sendByClipboard("infiltrative" A_EndChar,3)
    return
    :*B0:ifl1::
        sendByClipboard("infiltration",3)
    return
    :B0:wed::
        sendByClipboard("well-defined" A_EndChar,3)
    return
    :B0:ild::
        sendByClipboard("ill-defined" A_EndChar,3)
    return
    :B0:mu::
        sendByClipboard("multiple" A_EndChar,2)
    return
    :B0:rec::
        sendByClipboard("recurrent" A_EndChar,3)
    return
    :B0:prm::
        sendByClipboard("prominent" A_EndChar,3)
    return
    :*B0:prm1::
        sendByClipboard("more prominent",3)
    return
    :*B0:prm2::
        sendByClipboard("less prominent",3)
    return
    :B0:evi::
        sendByClipboard("evident" A_EndChar,3)
    return
    :*B0:evi1::
        sendByClipboard("more evident",3)
    return
    :*B0:evi2::
        sendByClipboard("less evident",3)
    return
    :*B0:evi3::
        sendByClipboard("most evident",3)
    return
    :B0:acu::
        sendByClipboard("acute" A_EndChar,3)
    return
    :B0:chr::
        sendByClipboard("chronic" A_EndChar,3)
    return
    :B0:ju::
        sendByClipboard("junction" A_EndChar,2)
    return
    :B0:wnr::
        sendByClipboard("within normal range" A_EndChar,3)
    return
    :B0:mor::
        sendByClipboard("predominant on the right side" A_EndChar,3)
    return
    :B0:mol::
        sendByClipboard("predominant on the left side" A_EndChar,3)
    return
    :B0:prs::
        sendByClipboard("persistent" A_EndChar,3)
    return
    :B0:dil::
        sendByClipboard("dilatation" A_EndChar,3)
    return
    :*B0:dil1::
        sendByClipboard("dilated",3)
    return
    :B0:seg::
        sendByClipboard("segmental" A_EndChar,3)
    return
    :B0:sg::
        sendByClipboard("segment" A_EndChar,2)
    return
    :*B0:sg1::
        sendByClipboard("segments",2)
    return
    :B0:frq::
        sendByClipboard("frequent" A_EndChar,3)
    return
    :B0:smo::
        sendByClipboard("smoothly" A_EndChar,3)
    return

    ;介係詞 句首 句尾
    :B0:w/::
        sendByClipboard("with" A_EndChar,2)
    return
    :B0:x/::
        sendByClipboard("without" A_EndChar,2)
    return
    :B0:y/::
        sendByClipboard("without/with" A_EndChar,2)
    return
    :B0:comp::
        sendByClipboard("as compared with previous study on" A_EndChar,4)
    return
    :B0:com::
        sendByClipboard("as compared with last similar study." A_EndChar,3)
    return

    :B0:icl::
        sendByClipboard("including" A_EndChar,3)
    return
    :B0:su::
        sendByClipboard("suspect" A_EndChar,2)
    return
    :B0:sus::
        sendByClipboard("suspected" A_EndChar,3)
    return
    :B0:suo::
        sendByClipboard("suspicious of" A_EndChar,3)
    return
    :B0:ifa::
        sendByClipboard("is favored" A_EndChar,3)
    return
    :B0:sug::
        sendByClipboard("suggestive of" A_EndChar,3)
    return
    ;~ ::ido::indicative of
    :B0:sgg::
        sendByClipboard("suggest" A_EndChar,3)
    return
    :B0:nde::
        sendByClipboard("no definite" A_EndChar,3)
    return
    :B0:df::
        sendByClipboard("definite" A_EndChar,2)
    return
    :B0:nob::
        sendByClipboard("no obvious" A_EndChar,3)
    return
    :B0:nev::
        sendByClipboard("no evidence of" A_EndChar,3)
    return
    :*B0:ico1::
        sendByClipboard("are considered",3)
    return
    :B0:ico::
        sendByClipboard("is considered" A_EndChar,3)
    return
    :*B0:icf1::
        sendByClipboard("are considered first",3)
    return
    :B0:icf::
        sendByClipboard("is considered first" A_EndChar,3)
    return
    :B0:isg::
        sendByClipboard("is suggested" A_EndChar,3)
    return
    :B0:iss::
        sendByClipboard("is suspected" A_EndChar,3)
    return
    :B0:isn::
        sendByClipboard("is noted" A_EndChar,3)
    return
    :B0:isd::
        sendByClipboard("is done" A_EndChar,3)
    return
    :B0:unr::
        sendByClipboard("unremarkable" A_EndChar,3)
    return
    :B0:cow::
        sendByClipboard("consistent with" A_EndChar,3)
    return
    :B0:sbe::
        sendByClipboard("should be excluded first." A_EndChar,3)
    return
    :B0:cnx::
        sendByClipboard("can not be excluded." A_EndChar,3)
    return
    :*B0:mcnx::
        sendByClipboard("malignancy can not be excluded.",3)
    return
    :B0:prev::
        sendByClipboard("previous" A_EndChar,4)
    return
    :B0:prb::
        sendByClipboard("probably" A_EndChar,3)
    return
    :B0:psb::
        sendByClipboard("possible" A_EndChar,3)
    return
    :B0:esp::
        sendByClipboard("especially" A_EndChar,3)
    return
    :B0:usu::
        sendByClipboard("usually" A_EndChar,3)
    return
    :B0:awa::
        sendByClipboard("as well as" A_EndChar,3)
    return
    ;~ ::thr::through
    :B0:trh::
        sendByClipboard("through" A_EndChar,3)
    return
    ;image character
    :B0:hyv::
        sendByClipboard("hypervascular" A_EndChar,3)
    return
    :B0:hov::
        sendByClipboard("hypovascular" A_EndChar,3)
    return

    :B0:hom::
        sendByClipboard("homogeneous" A_EndChar,3)
    return
    :B0:het::
        sendByClipboard("heterogeneous" A_EndChar,3)
    return

    :B0:den::
        sendByClipboard("density" A_EndChar,3)
    return
    :*B0:den1::
        sendByClipboard("densities",3)
    return
    :B0:ro::
        sendByClipboard("radiopaque" A_EndChar,2)
    return
    :*B0:ro1::
        sendByClipboard("radiopaque density",2)
    return
    :*B0:ro2::
        sendByClipboard("radiopaque densities",2)
    return
    :B0:rl::
        sendByClipboard("radiolucent" A_EndChar,2)
    return
    :*B0:rl1::
        sendByClipboard("radiolucency",2)
    return
    :*B0:rl2::
        sendByClipboard("radiolucencies",2)
    return
    :B0:hy::
        sendByClipboard("hyperdense" A_EndChar,2)
    return
    :*B0:hy1::
        sendByClipboard("hyperdensity",2)
    return
    :*B0:hy2::
        sendByClipboard("hyperdensities",2)
    return
    :B0:hyi::
        sendByClipboard("hyperintense" A_EndChar,3)
    return
    :*B0:hyi1::
        sendByClipboard("hyperintensity",3)
    return
    :*B0:hyi2::
        sendByClipboard("hyperintensities",3)
    return
    :B0:ho::
        sendByClipboard("hypodense" A_EndChar,2)
    return
    :*B0:ho1::
        sendByClipboard("hypodensity",2)
    return
    :*B0:ho2::
        sendByClipboard("hypodensities",2)
    return
    :B0:hoi::
        sendByClipboard("hypointense" A_EndChar,3)
    return
    :*B0:hoi1::
        sendByClipboard("hypointensity",3)
    return
    :*B0:hoi2::
        sendByClipboard("hypointensities",3)
    return

    :B0:opac::
        sendByClipboard("opacification" A_EndChar,4)
    return
    :B0:opf::
        sendByClipboard("opacified" A_EndChar,3)
    return
    :B0:nen::
        sendByClipboard("non-enhancing" A_EndChar,3)
    return
    :B0:enh::
        sendByClipboard("enhancing" A_EndChar,3)
    return
    :B0:enn::
        sendByClipboard("enhancing nodule" A_EndChar,3)
    return
    :*B0:enn1::
        sendByClipboard("enhancing nodules",3)
    return
    :B0:enm::
        sendByClipboard("enhancing mass" A_EndChar,3)
    return
    :*B0:enm1::
        sendByClipboard("enhancing masses",3)
    return
    :B0:ens::
        sendByClipboard("enhancing lesion" A_EndChar,3)
    return
    :*B0:ens1::
        sendByClipboard("enhancing lesions",3)
    return
    :B0:ent::
        sendByClipboard("enhancing tumor" A_EndChar,3)
    return
    :*B0:ent1::
        sendByClipboard("enhancing tumors",3)
    return

    :*B0:enhc::
        sendByClipboard("enhancement",3)
    return
    :B0:hoe::
        sendByClipboard("hypoenhancing" A_EndChar,3)
    return
    :B0:hye::
        sendByClipboard("hyperenhancing" A_EndChar,3)
    return
    :*B0:hoec::
        sendByClipboard("hypoenhancement",3)
    return
    :*B0:hyec::
        sendByClipboard("hyperenhancement",3)
    return

    :B0:extv::
        sendByClipboard("extravasation" A_EndChar,4)
    return

    :B0:si::
        sendByClipboard("SI" A_EndChar,2)
    return
    :B0:sii::
        sendByClipboard("signal intensity" A_EndChar,3)
    return

    :B0:t2w::
        sendByClipboard("T2WI" A_EndChar,3)
    return
    :B0:t1w::
        sendByClipboard("T1WI" A_EndChar,3)
    return
    :B0:stir::
        sendByClipboard("T2 STIR" A_EndChar,4)
    return
    :B0:flar::
        sendByClipboard("T2 FLAIR" A_EndChar,4)
    return

    pigtail:
        digits:=$.value(1)
        stringleft,fr,digits,% strlen(digits)-2
        StringRight,cm,digits,2
        sendByClipboard(fr "Fr " cm "cm pigtail catheter" $.value(2))
        $:=""
    return

    catheter:
        send % "{bs " StrLen($.value(0))  "}"
        sendByClipboard(substr($.value(1),1,1) (strlen($.value(1))>1?"." substr($.value(1),2):"") "Fr " $.value(2) "cm " ($.value(1)>10?"micro":"") "catheter" $.value(3))
        $:=""
    return

    specifyImage:
        ;~ bs:=strlen($1)+strlen($2)+strlen($3)+strlen($4)
        ;~ loop % bs+2
        ;~ send {bs}
        if InStr(thisPlace, "C hospital")
            sestr:="Srs", Imstr:="Img"
        else
            seStr:="SE", imstr:="IM"
        if ($.value(1)="."){
            str:="(" seStr $.value(2) " " imstr $.value(3) ")" $.value(4)
        }
        ;~ sendByClipboard("(SE" $.value(2) " IM" $.value(3) ")" $.value(4), strlen($.value(0)))
        else{
            str:=$.value(1) seStr $.value(2) " " imstr $.value(3) $.value(4)
        }
        send % "{bs " StrLen($.value(0))  "}"
        sendByClipboard(str)
        ;~ sendByClipboard($.value(1) "SE" $.value(2) " IM" $.value(3) $.value(4), strlen($.value(0)))
        $:=""
    return
    ;general term
    :cB0:nj::
        sendByClipboard("injury" A_EndChar,2)
    return
    :*B0:spcm::
        sendByClipboard("smooth passage of contrast media",3)
    return
    :*B0:obs0::
        sendByClipboard("no definite obstructive lesion.",3)
    return
    :*B0:lap0::
        sendByClipboard("no definite lymphadenopathy.",3)
    return
    :B0:mmp::
        sendByClipboard("mammoplasty" A_EndChar,3)
    return
    :B0:eqv::
        sendByClipboard("equivocal" A_EndChar,3)
    return
    :B0:ktz::
        sendByClipboard("Please refer to key image series for possible transition zone." A_EndChar,3)
    return
    :B0:tzn::
        sendByClipboard("transition zone" A_EndChar,3)
    return
    :B0:pav::
        sendByClipboard("patent major arteries and veins." A_EndChar,3)
    return
    :B0:ama::
        sendByClipboard("as mentioned above" A_EndChar,3)
    return
    :B0:geo::
        sendByClipboard("geographic" A_EndChar,3)
    return
    :B0:ns::
        sendByClipboard("no significant findings in this study." A_EndChar,2)
    return
    :B0:sct::
        sendByClipboard("scattered" A_EndChar,3)
    return
    :B0:ids::
        sendByClipboard("indiscernible" A_EndChar,3)
    return
    :B0:mj::
        sendByClipboard("major" A_EndChar,2)
    return
    :B0:mn::
        sendByClipboard("minor" A_EndChar,2)
    return
    :B0:rct::
        sendByClipboard("recent" A_EndChar,3)
    return
    :B0:stu::
        sendByClipboard("structure" A_EndChar,3)
    return
    :*B0:stu1::
        sendByClipboard("structures",3)
    return
    :B0:cpn::
        sendByClipboard("component" A_EndChar,3)
    return
    :*B0:cpn1::
        sendByClipboard("components",3)
    return
    :B0:wl::
        sendByClipboard("wall" A_EndChar,2)
    return
    :B0:sgm::
        sendByClipboard("sigmoid" A_EndChar,3)
    return
    :B0:ctn::
        sendByClipboard("contents" A_EndChar,3)
    return
    :B0:mat::
        sendByClipboard("material" A_EndChar,3)
    return
    :B0:vas::
        sendByClipboard("vascular" A_EndChar,3)
    return
    :B0:cls::
        sendByClipboard("clustered" A_EndChar,3)
    return
    :B0:fbd::
        sendByClipboard("fibrous dysplasia" A_EndChar,3)
    return
    ;~ ::xz::
    ;~ sendByClipboard("`r`n(Only major findings are mentioned above; please contact the radiologist if detailed formal report is required.)")
    ;~ return
    :B0:ncc::
        sendByClipboard("necrotic change" A_EndChar,3)
    return
    :B0:ncm::
        sendByClipboard("necrotic mass" A_EndChar,3)
    return
    :B0:lpd::
        sendByClipboard("lymphoproliferative disease" A_EndChar,3)
    return
    :B0:ewt::
        sendByClipboard("edematous wall thickening" A_EndChar,3)
    return
    :B0:pdc::
        sendByClipboard("peduncle" A_EndChar,3)
    return
    :*B0:pdc1::
        sendByClipboard("peduncles",3)
    return
    :B0:bna::
        sendByClipboard("benign appearance" A_EndChar,3)
    return
    :B0:wba::
        sendByClipboard("with benign appearance" A_EndChar,3)
    return
    :B0:ape::
        sendByClipboard("appearance" A_EndChar,3)
    return
    :B0:hoc::
        sendByClipboard("hypodense change" A_EndChar,3)
    return
    :B0:fhc::
        sendByClipboard("focal hypodense change" A_EndChar,3)
    return
    :B0:tt::
        sendByClipboard("total" A_EndChar,2)
    return
    :B0:ren::
        sendByClipboard("rim-enhancing" A_EndChar,3)
    return
    :B0:itn::
        sendByClipboard("internal" A_EndChar,3)
    return
    :B0:etn::
        sendByClipboard("external" A_EndChar,3)
    return
    :B0:mal::
        sendByClipboard("mass lesion" A_EndChar,3)
    return
    :*B0:mal1::
        sendByClipboard("mass lesions",3)
    return
    :B0:pow::
        sendByClipboard("posterior wall" A_EndChar,3)
    return
    :B0:anw::
        sendByClipboard("anterior wall" A_EndChar,3)
    return
    :B0:law::
        sendByClipboard("lateral wall" A_EndChar,3)
    return
    :B0:mew::
        sendByClipboard("medial wall" A_EndChar,3)
    return
    :B0:inw::
        sendByClipboard("inferior wall" A_EndChar,3)
    return
    :B0:suw::
        sendByClipboard("superior wall" A_EndChar,3)
    return
    :B0:flo::
        sendByClipboard("floor" A_EndChar,3)
    return
    :B0:hh::
        sendByClipboard("high" A_EndChar,2)
    return
    :B0:bld::
        sendByClipboard("blood" A_EndChar,3)
    return
    :B0:clc::
        sendByClipboard("collection" A_EndChar,3)
    return
    :B0:rsd::
        sendByClipboard("residual" A_EndChar,3)
    return
    :B0:thw::
        sendByClipboard("thin-walled" A_EndChar,3)
    return
    :B0:amr::
        sendByClipboard("amorphous" A_EndChar,3)
    return
    :B0:trt::
        sendByClipboard("treated" A_EndChar,3)
    return
    :B0:eln::
        sendByClipboard("enlarged lymph node" A_EndChar,3)
    return
    :*B0:eln1::
        sendByClipboard("enlarged lymph nodes",3)
    return
    :B0:stas::
        sendByClipboard("some soft tissue around the sutures" A_EndChar,4)
    return
    :B0:bkg::
        sendByClipboard("background" A_EndChar,3)
    return
    :B0:itr::
        sendByClipboard("intrathoracic" A_EndChar,3)
    return
    :B0:cor::
        sendByClipboard("coronal" A_EndChar,3)
    return
    :B0:sag::
        sendByClipboard("sagittal" A_EndChar,3)
    return
    :B0:ax::
        sendByClipboard("axial" A_EndChar,2)
    return
    :B0:boi::
        sendByClipboard("non-specific sclerotic foci." A_EndChar,3)
    return
    :*B0:boi1::
        sendByClipboard("non-specific sclerotic focus at",3)
    return
    :B0:vsb::
        sendByClipboard("visible bones" A_EndChar,3)
    return
    :B0:arn::
        sendByClipboard("around" A_EndChar,3)
    return
    :B0:srr::
        sendByClipboard("surrounding" A_EndChar,3)
    return
    :B0:sev::
        sendByClipboard("several" A_EndChar,3)
    return
    :B0:nm::
        sendByClipboard("numerous" A_EndChar,2)
    return
    :B0:crc::
        sendByClipboard("circulation" A_EndChar,3)
    return
    :B0:ipm::
        sendByClipboard("if proven malignancy" A_EndChar,3)
    return
    :B0:fxa::
        sendByClipboard("fixation" A_EndChar,3)
    return
    :B0:psf::
        sendByClipboard("Please see the images and findings." A_EndChar,3)
    return
    :B0:edc::
        sendByClipboard("edematous change" A_EndChar,3)
    return
    :B0:col::
        sendByClipboard("collateral" A_EndChar,3)
    return
    :*B0:col1::
        sendByClipboard("collaterals",3)
    return
    :B0:ank::
        sendByClipboard("ankylosing spondylitis" A_EndChar,3)
    return
    :B0:fos::
        sendByClipboard("fossa" A_EndChar,3)
    return
    :B0:cau::
        sendByClipboard("causing" A_EndChar,3)
    return
    :B0:blg::
        sendByClipboard("bulging" A_EndChar,3)
    return
    :B0:hi::
        sendByClipboard("hilar" A_EndChar,2)
    return
    :B0:hl::
        sendByClipboard("hilum" A_EndChar,2)
    return
    :B0:ndo::
        sendByClipboard("nodular opacity" A_EndChar,3)
    return
    :*B0:ndo1::
        sendByClipboard("nodular opacities",3)
    return
    :B0:mlo::
        sendByClipboard("mass-like opacity" A_EndChar,3)
    return
    :*B0:mlo1::
        sendByClipboard("mass-like opacities",3)
    return
    :B0:msl::
        sendByClipboard("mass-like" A_EndChar,3)
    return
    :B0:arp::
        sendByClipboard("arthroplasty" A_EndChar,3)
    return
    :B0:fnd::
        sendByClipboard("finding" A_EndChar,3)
    return
    :*B0:fnd1::
        sendByClipboard("findings",3)
    return
    :B0:rst::
        sendByClipboard("roughly unchanged" A_EndChar,3)
    return
    :*B0:rstm::
        sendByClipboard("roughly unchanged but malignancy can not be excluded.",3)
    return
    :B0:rf::
        sendByClipboard("roughly" A_EndChar,2)
    return
    :B0:mll::
        sendByClipboard("mass-like lesion" A_EndChar,3)
    return
    :B0:bod::
        sendByClipboard("bony defect" A_EndChar,3)
    return
    :B0:coi::
        sendByClipboard("coiling" A_EndChar,3)
    return

    :B0:dpr::
        sendByClipboard("disappearance" A_EndChar,3)
    return
    :*B0:dpr1::
        sendByClipboard("disappeared",3)
    return

    :B0:ndl::
        sendByClipboard("nodular lesion" A_EndChar,3)
    return
    :*B0:ndl1::
        sendByClipboard("nodular lesions",3)
    return
    :B0:ndd::
        sendByClipboard("nodular density" A_EndChar,3)
    return
    :*B0:ndd1::
        sendByClipboard("nodular densities",3)
    return
    :B0:ndp::
        sendByClipboard("nodular opacity" A_EndChar,3)
    return
    :*B0:ndp1::
        sendByClipboard("nodular opacities",3)
    return

    :B0:nth::
        sendByClipboard("nodular thickening" A_EndChar,3)
    return

    :B0:wdg::
        sendByClipboard("wedge" A_EndChar,3)
    return
    :B0:nut::
        sendByClipboard("neurogenic tumor" A_EndChar,3)
    return
    :B0:skk::
        sendByClipboard("sclerotic focus" A_EndChar,3)
    return
    :B0:ski::
        sendByClipboard("sclerotic foci" A_EndChar,3)
    return
    :B0:ctl::
        sendByClipboard("cartilage" A_EndChar,3)
    return
    :B0:rta::
        sendByClipboard("retraction" A_EndChar,3)
    return
    :B0:pvc::
        sendByClipboard("perivascular" A_EndChar,3)
    return
    :B0:sft::
        sendByClipboard("soft tissue" A_EndChar,3)
    return
    :B0:sue::
        sendByClipboard("subcutaneous emphysema" A_EndChar,3)
    return
    :B0:bfr::
        sendByClipboard("bone fragment" A_EndChar,3)
    return
    :*B0:bfr1::
        sendByClipboard("bone fragments",3)
    return
    :B0:cyl::
        sendByClipboard("cystic lesion" A_EndChar,3)
    return
    :*B0:cyl1::
        sendByClipboard("cystic lesions",3)
    return
    :B0:cyc::
        sendByClipboard("cystic change" A_EndChar,3)
    return
    :B0:fis::
        sendByClipboard("fistula" A_EndChar,3)
    return
    :B0:g1::
        sendByClipboard("grade 1" A_EndChar,2)
    return
    :B0:g2::
        sendByClipboard("grade 2" A_EndChar,2)
    return
    :B0:g3::
        sendByClipboard("grade 3" A_EndChar,2)
    return
    :B0:g4::
        sendByClipboard("grade 4" A_EndChar,2)
    return
    :B0:rcn::
        sendByClipboard("reconstruction" A_EndChar,3)
    return
    :B0:ldc::
        sendByClipboard("low density change" A_EndChar,3)
    return
    :B0:sti::
        sendByClipboard("soft tissue thickening" A_EndChar,3)
    return
    :B0:pau::
        sendByClipboard("penetrating atherosclerotic ulcer" A_EndChar,3)
    return
    :B0:pvn::
        sendByClipboard("previously noted" A_EndChar,3)
    return
    :B0:psg::
        sendByClipboard("parasagittal" A_EndChar,3)
    return
    :B0:mur::
        sendByClipboard("mural" A_EndChar,3)
    return
    :B0:mtr::
        sendByClipboard("mural thrombus" A_EndChar,3)
    return
    :B0:sol::
        sendByClipboard("space-occupying lesion" A_EndChar,3)
    return
    :B0:swe::
        sendByClipboard("swelling" A_EndChar,3)
    return
    :B0:swo::
        sendByClipboard("swollen" A_EndChar,3)
    return
    :B0:aor::
        sendByClipboard("and/or" A_EndChar,3)
    return
    :B0:bos::
        sendByClipboard("borderline sized" A_EndChar,3)
    return
    :B0:rfy::
        sendByClipboard("roughly" A_EndChar,3)
    return
    :B0:abt::
        sendByClipboard("about" A_EndChar,3)
    return
    :B0:pst::
        sendByClipboard("positive" A_EndChar,3)
    return
    :B0:neg::
        sendByClipboard("negative" A_EndChar,3)
    return
    :B0:xps::
        sendByClipboard("expansile" A_EndChar,3)
    return
    :B0:vz::
        sendByClipboard("of varying sizes" A_EndChar,2)
    return
    :B0:def::
        sendByClipboard("deformity" A_EndChar,3)
    return
    :B0:orf::
        sendByClipboard("orifice" A_EndChar,3)
    return
    :B0:aan::
        sendByClipboard("aortic aneurysm" A_EndChar,3)
    return
    :B0:aaa::
        sendByClipboard("abdominal aortic aneurysm" A_EndChar,3)
    return
    :B0:adl::
        sendByClipboard("aneurysmal dilatation" A_EndChar,3)
    return
    :B0:ac::
        sendByClipboard("acute" A_EndChar,2)
    return
    :B0:sak::
        sendByClipboard("subacute" A_EndChar,3)
    return
    :B0:mub::
        sendByClipboard("multiple bilateral" A_EndChar,3)
    return
    :B0:cas::
        sendByClipboard("calcification or stone" A_EndChar,3)
    return
    :B0:ed::
        sendByClipboard("edema" A_EndChar,2)
    return
    :B0:num::
        sendByClipboard("number" A_EndChar,3)
    return
    :B0:slx::
        sendByClipboard("subluxation" A_EndChar,3)
    return
    :B0:dlk::
        sendByClipboard("dislocation" A_EndChar,3)
    return
    :B0:vt::
        sendByClipboard("vertebra" A_EndChar,2)
    return
    :*B0:vt1::
        sendByClipboard("vertebrae",2)
    return
    :B0:vtb::
        sendByClipboard("vertebral" A_EndChar,3)
    return
    :B0:api::
        sendByClipboard("apical" A_EndChar,3)
    return
    :B0:res::
        sendByClipboard("resolution" A_EndChar,3)
    return
    :B0:rs::
        sendByClipboard("resolved" A_EndChar,2)
    return
    :*B0:rs1::
        sendByClipboard("resolving",2)
    return
    :B0:hmt::
        sendByClipboard("hematoma" A_EndChar,3)
    return
    :*B0:hmt1::
        sendByClipboard("hematomas",3)
    return
    :B0:pc::
        sendByClipboard("space" A_EndChar,2)
    return
    :*B0:pc1::
        sendByClipboard("space",2)
    return
    :B0:wen::
        sendByClipboard("well-enhancing" A_EndChar,3)
    return
    :B0:inn::
        sendByClipboard("is not noted" A_EndChar,3)
    return
    :B0:rpm::
        sendByClipboard("replacement" A_EndChar,3)
    return
    :B0:rp::
        sendByClipboard("replaced" A_EndChar,2)
    return
    :B0:cnn::
        sendByClipboard("cannula" A_EndChar,3)
    return
    :*B0:cnn1::
        sendByClipboard("cannulas",3)
    return
    :B0:sys::
        sendByClipboard("system" A_EndChar,3)
    return
    :B0:cav::
        sendByClipboard("cavitary" A_EndChar,3)
    return
    :B0:pdm::
        sendByClipboard("predominant" A_EndChar,3)
    return
    :*B0:pdm1::
        sendByClipboard("predominance",3)
    return
    :B0:stg::
        sendByClipboard("staging" A_EndChar,3)
    return
    :B0:bd::
        sendByClipboard("border" A_EndChar,2)
    return
    :B0:fk::
        sendByClipboard("focus" A_EndChar,2)
    return
    :B0:fi::
        sendByClipboard("foci" A_EndChar,2)
    return
    :B0:fkl::
        sendByClipboard("focal" A_EndChar,3)
    return
    :B0:sk::
        sendByClipboard("sclerotic" A_EndChar,2)
    return
    :B0:sks::
        sendByClipboard("sclerosis" A_EndChar,3)
    return
    :B0:tst::
        sendByClipboard("tentative radiology staging" A_EndChar,3)
    return
    :B0:oth::
        sendByClipboard("other" A_EndChar,3)
    return
    :B0:ano::
        sendByClipboard("another" A_EndChar,3)
    return
    :B0:rtr::
        sendByClipboard("reticular" A_EndChar,3)
    return
    :B0:dss::
        sendByClipboard("dissection" A_EndChar,3)
    return
    :B0:aod::
        sendByClipboard("aortic dissection" A_EndChar,3)
    return
    :B0:imh::
        sendByClipboard("intramural hematoma" A_EndChar,3)
    return
    :*B0:ns=::
        sendByClipboard("is not seen in this study",2)
    return
    :B0:obv::
        sendByClipboard("obvious" A_EndChar,3)
    return
    :B0:djd::
        sendByClipboard("degenerative change of spine" A_EndChar,3)
    return
    :B0:djcf::
        sendByClipboard("degenerative change of spine with compression fracture" A_EndChar,4)
    return
    :*B0:djcf1::
        sendByClipboard("degenerative change of spine with compression fractures",4)
    return
    :*B0:djop::
        sendByClipboard("degenerative and post-operative change of spine",3)
    return
    :B0:nal::
        sendByClipboard("normal alignment" A_EndChar,3)
    return
    :B0:muc::
        sendByClipboard("mucus" A_EndChar,3)
    return
    :B0:mre::
        sendByClipboard("mucus retention" A_EndChar,3)
    return
    :*B0:met0::
        sendByClipboard("no evidence of metastatic lesions.",3)
    return
    :*B0:met00::
        sendByClipboard("no evidence of metastatic lesions or lymphadenopathy.",4)
    return
    :B0:sem::
        sendByClipboard("subcutaneous emphysema" A_EndChar,3)
    return
    :B0:clp::
        sendByClipboard("collapse" A_EndChar,3)
    return
    :*B0:clp1::
        sendByClipboard("collapsed",3)
    return
    :B0:cpm::
        sendByClipboard("cardiovascular implantable electronic device" A_EndChar,3)
    return
    :B0:pgc::
        sendByClipboard("pigtail catheter" A_EndChar,3)
    return
    :B0:pgc1::
        sendByClipboard("pigtail catheters" A_EndChar,4)
    return
    :B0:flt::
        sendByClipboard("flattening" A_EndChar,3)
    return
    :B0:prv::
        sendByClipboard("previous" A_EndChar,3)
    return
    :B0:cfl::
        sendByClipboard("confluent" A_EndChar,3)
    return
    :B0:lnr::
        sendByClipboard("linear" A_EndChar,3)
    return
    :B0:prr::
        sendByClipboard("prior" A_EndChar,3)
    return
    :B0:gri::
        sendByClipboard("granulomatous infection" A_EndChar,3)
    return
    :B0:spi::
        sendByClipboard("spiculated" A_EndChar,3)
    return
    :B0:sed::
        sendByClipboard("seedings" A_EndChar,3)
    return
    :*B0:sed0::
        sendByClipboard("seeding",3)
    return
    :B0:crs::
        sendByClipboard("coarse" A_EndChar,3)
    return
    :B0:ple::
        sendByClipboard("pleomorphic" A_EndChar,3)
    return
    :B0:bnn::
        sendByClipboard("benign" A_EndChar,3)
    return
    :B0:mlg::
        sendByClipboard("malignancy" A_EndChar,3)
    return
    :*B0:slgr::
        sendByClipboard("slow-growing",3)
    return
    :B0:sym::
        sendByClipboard("symmetric" A_EndChar,3)
    return
    :B0:asy::
        sendByClipboard("asymmetric" A_EndChar,3)
    return
    :B0:prn::
        sendByClipboard("prolonged" A_EndChar,3)
    return
    :B0:acc::
        sendByClipboard("accessory" A_EndChar,3)
    return
    :B0:nv::
        sendByClipboard("nerve" A_EndChar,2)
    return
    :*B0:nv1::
        sendByClipboard("nerves",2)
    return
    :B0:ms::
        sendByClipboard("muscle" A_EndChar,2)
    return
    :*B0:ms1::
        sendByClipboard("muscles",2)
    return
    :B0:bn::
        sendByClipboard("bone" A_EndChar,2)
    return
    :*B0:bns::
        sendByClipboard("bones",2)
    return
    :*B0:lore::
        sendByClipboard("loco-regional",3)
    return
    :B0:pt::
        sendByClipboard("patchy" A_EndChar,2)
    return
    :B0:ecc::
        sendByClipboard("eccentric" A_EndChar,3)
    return
    :B0:ccc::
        sendByClipboard("concentric" A_EndChar,3)
    return
    :B0:ki::
        sendByClipboard("(Please refer to key image series.)" A_EndChar,2)
    return
    :B0:ref::
        sendByClipboard("Please refer to the text above for detailed findings." A_EndChar,3)
    return
    :B0:isa::
        sendByClipboard("in short axis" A_EndChar,3)
    return
    :B0:igd::
        sendByClipboard("in greatest dimension" A_EndChar,3)
    return
    :B0:ch::
        sendByClipboard("change" A_EndChar,2)
    return
    :*B0:ch1::
        sendByClipboard("changes",2)
    return
    :B0:bo::
        sendByClipboard("both" A_EndChar,2)
    return
    :B0:wid::
        sendByClipboard("widening" A_EndChar,3)
    return
    :B0:thew::
        sendByClipboard("abnormal thickening and enhancing wall" A_EndChar,4)
    return
    :B0:vpt::
        sendByClipboard("vertebroplasty" A_EndChar,3)
    return
    :B0:unk::
        sendByClipboard("unknown (unavailable) history in N hospital" A_EndChar,3)
    return
    :B0:ty::
        sendByClipboard("typical" A_EndChar,2)
    return
    :B0:aty::
        sendByClipboard("atypical" A_EndChar,3)
    return
    :*B0:tstc::
        sendByClipboard("too small to characterize",3)
    return
    :B0:tsc::
        sendByClipboard("tuberous sclerosis complex" A_EndChar,3)
    return
    :B0:std::
        sendByClipboard("soft tissue density" A_EndChar,3)
    return
    :*B0:std1::
        sendByClipboard("soft tissue densities",3)
    return
    :B0:sot::
        sendByClipboard("soft tissue" A_EndChar,3)
    return
    :B0:sw::
        sendByClipboard("shadow" A_EndChar,2)
    return
    :B0:scem::
        sendByClipboard("subcutaneous emphysema" A_EndChar,4)
    return
    :B0:sch::
        sendByClipboard("sclerotic change" A_EndChar,3)
    return
    :B0:skf::
        sendByClipboard("sclerotic foci" A_EndChar,3)
    return
    :B0:scl::
        sendByClipboard("surgical clips" A_EndChar,3)
    return
    :B0:pr::
        sendByClipboard("partial" A_EndChar,2)
    return
    :B0:py::
        sendByClipboard("partially" A_EndChar,2)
    return
    :B0:pob::
        sendByClipboard("partial obstruction" A_EndChar,3)
    return
    :B0:pq::
        sendByClipboard("plaque" A_EndChar,2)
    return
    :*B0:pq1::
        sendByClipboard("plaques",2)
    return
    :B0:plq::
        sendByClipboard("pleural plaque" A_EndChar,3)
    return
    :*B0:plq1::
        sendByClipboard("pleural plaques",3)
    return
    :B0:ovr::
        sendByClipboard("overriding" A_EndChar,3)
    return
    :B0:ocm::
        sendByClipboard("oral contrast media" A_EndChar,3)
    return
    :B0:nrt::
        sendByClipboard("no evidence of recurrent tumor." A_EndChar,3)
    return
    :*B0:nrtl::
        sendByClipboard("no evidence of recurrent tumor or lymphadenopathy.",3)
    return
    :*B0:nrt1::
        sendByClipboard("no evidence of residual tumor.",3)
    return
    :*B0:nrt2::
        sendByClipboard("no evidence of residual/recurrent tumor.",3)
    return

    :*B0:opnrt::
        sendByClipboard("post-operative changes. no evidence of recurrent tumor.",4)
    return
    :*B0:oprtn::
        sendByClipboard("post-operative and post-radiation changes. no evidence of recurrent tumor.",4)
    return

    :B0:nse::
        sendByClipboard("no solid or enhancing part is noted" A_EndChar,3)
    return
    :B0:bog::
        sendByClipboard("bowel gas" A_EndChar,3)
    return
    :B0:nic::
        sendByClipboard("no significant interval change." A_EndChar,3)
    return
    :B0:nfl::
        sendByClipboard("no definite focal lesion" A_EndChar,3)
    return
    :B0:mob::
        sendByClipboard("more obvious" A_EndChar,3)
    return
    :B0:mk::
        sendByClipboard("marked" A_EndChar,2)
    return
    :*B0:mk1::
        sendByClipboard("markedly",2)
    return
    :B0:mxd::
        sendByClipboard("maximal diameter" A_EndChar,3)
    return
    :B0:lbu::
        sendByClipboard("lobulated" A_EndChar,3)
    return
    :B0:lcu::
        sendByClipboard("loculated" A_EndChar,3)
    return
    :B0:vn::
        sendByClipboard("vein" A_EndChar,2)
    return
    :*B0:vn1::
        sendByClipboard("veins",2)
    return
    :B0:vsl::
        sendByClipboard("vessel" A_EndChar,3)
    return
    :*B0:vsl1::
        sendByClipboard("vessels",3)
    return
    :B0:vsc::
        sendByClipboard("vasculatures" A_EndChar,3)
    return
    :B0:its::
        sendByClipboard("in this study" A_EndChar,3)
    return
    :B0:isf::
        sendByClipboard("is found" A_EndChar,3)
    return
    :B0:ixp::
        sendByClipboard("infectious process" A_EndChar,3)
    return
    :B0:ifp::
        sendByClipboard("inflammatory process" A_EndChar,3)
    return
    :B0:fxp::
        sendByClipboard("inflammatory/infectious process" A_EndChar,3)
    return
    :*B0:fxp1::
        sendByClipboard("inflammatory/infectious process of lung, suggest clinical correlation and follow up.",3)
    return
    :*B0:fxp2::
        sendByClipboard("inflammatory/infectious process of lung, more prominent, suggest clinical correlation and follow up.",3)
    return
    :*B0:fxp3::
        sendByClipboard("inflammatory/infectious process of lung, less prominent, suggest clinical correlation and follow up.",3)
    return
    :B0:fxc::
        sendByClipboard("inflammatory/infectious change" A_EndChar,3)
    return
    :B0:ifc::
        sendByClipboard("inflammatory change" A_EndChar,3)
    return
    ;~ ::ioh::in other hospital
    :B0:ndt::
        sendByClipboard("indentation" A_EndChar,3)
    return
    :B0:inci::
        sendByClipboard("incidentally" A_EndChar,4)
    return
    :B0:idn::
        sendByClipboard("identified" A_EndChar,3)
    return
    :B0:isi::
        sendByClipboard("is identified" A_EndChar,3)
    return
    :B0:hm::
        sendByClipboard("hemorrhagic" A_EndChar,2)
    return
    :B0:grt::
        sendByClipboard("granulation tissue" A_EndChar,3)
    return
    :B0:fsf::
        sendByClipboard("fusiform" A_EndChar,3)
    return
    :B0:foc::
        sendByClipboard("focal lesion" A_EndChar,3)
    return
    :B0:fpl::
        sendByClipboard("fat plane" A_EndChar,3)
    return
    :B0:ffl::
        sendByClipboard("fluid-fluid level" A_EndChar,3)
    return
    :B0:ff::
        sendByClipboard("fluid-fluid layering" A_EndChar,2)
    return
    :B0:eva::
        sendByClipboard("evaluation" A_EndChar,3)
    return
    :B0:fev::
        sendByClipboard("further evaluation" A_EndChar,3)
    return
    :B0:fct::
        sendByClipboard("fat-containing tumor" A_EndChar,3)
    return
    :B0:fcn::
        sendByClipboard("fat-containing nodule" A_EndChar,3)
    return
    :B0:fcm::
        sendByClipboard("fat-containing mass" A_EndChar,3)
    return
    :B0:fla::
        sendByClipboard("fluid accumulation" A_EndChar,3)
    return
    :B0:flr::
        sendByClipboard("fluid retention" A_EndChar,3)
    return
    :B0:eti::
        sendByClipboard("The etiology should be further evaluated." A_EndChar,3)
    return
    :B0:sfe::
        sendByClipboard("suggest further evaluation." A_EndChar,3)
    return
    :B0:emf::
        sendByClipboard("emphysematous" A_EndChar,3)
    return
    :cB0:eca::
        sendByClipboard("encasement" A_EndChar,3)
    return
    :cB0:Eca::
        sendByClipboard("Encasement" A_EndChar,3)
    return
    :B0:eca::
        sendByClipboard("ECA" A_EndChar,3)
    return
    :B0:ele::
        sendByClipboard("elevated" A_EndChar,3)
    return
    :B0:drt::
        sendByClipboard("drainage tube" A_EndChar,3)
    return
    :*B0:drt1::
        sendByClipboard("drainage tubes",3)
    return
    :B0:dst::
        sendByClipboard("distended" A_EndChar,3)
    return
    :*B0:dst1::
        sendByClipboard("distention",3)
    return
    :B0:dlg::
        sendByClipboard("dislodgement" A_EndChar,3)
    return
    :B0:dfs::
        sendByClipboard("diffuse" A_EndChar,3)
    return
    :B0:dfy::
        sendByClipboard("diffusely" A_EndChar,3)
    return
    :B0:dao::
        sendByClipboard("details are obscured" A_EndChar,3)
    return
    :B0:des::
        sendByClipboard("destruction" A_EndChar,3)
    return
    :B0:dep::
        sendByClipboard("dependent" A_EndChar,3)
    return
    :*B0:cn1::
        sendByClipboard("cancerous",2)
    return
    :B0:stn::
        sendByClipboard("stenting" A_EndChar,3)
    return
    :B0:cm::
        sendByClipboard("contrast media" A_EndChar,2)
    return
    :B0:cir::
        sendByClipboard("circumferential" A_EndChar,3)
    return
    :B0:cli::
        sendByClipboard("clinical" A_EndChar,3)
    return
    :B0:rr::
        sendByClipboard("on the right side" A_EndChar,2)
    return
    :B0:ll::
        sendByClipboard("on the left side" A_EndChar,2)
    return
    :B0:bb::
        sendByClipboard("on both sides" A_EndChar,2)
    return
    :B0:bnt::
        sendByClipboard("blunting" A_EndChar,3)
    return
    :B0:asw::
        sendByClipboard("associated with" A_EndChar,3)
    return
    :B0:att::
        sendByClipboard("attenuation" A_EndChar,3)
    return
    :B0:pft::
        sendByClipboard("perifocal fat stranding" A_EndChar,3)
    return
    :B0:mfs::
        sendByClipboard("mesenteric fat stranding" A_EndChar,3)
    return
    :B0:aph::
        sendByClipboard("arterial phase" A_EndChar,3)
    return
    :B0:pvp::
        sendByClipboard("portal venous phase" A_EndChar,3)
    return
    :B0:vph::
        sendByClipboard("venous phase" A_EndChar,3)
    return
    :B0:ap::
        sendByClipboard("air pockets" A_EndChar,2)
    return
    :B0:amo::
        sendByClipboard("amount of" A_EndChar,3)
    return
    :B0:ana::
        sendByClipboard("anastomosis" A_EndChar,3)
    return
    :*B0:ana1::
        sendByClipboard("anastomotic",3)
    return
    :B0:prc::
        sendByClipboard("parenchyma" A_EndChar,3)
    return
    :B0:prc1::
        sendByClipboard("parenchymal" A_EndChar,4)
    return
    :B0:tnn::
        sendByClipboard("thinning" A_EndChar,3)
    return
    :B0:rel::
        sendByClipboard("relative" A_EndChar,3)
    return
    :B0:eng::
        sendByClipboard("engorged" A_EndChar,3)
    return
    :B0:vsz::
        sendByClipboard("variable-sized" A_EndChar,3)
    return
    :B0:ifx::
        sendByClipboard("infection" A_EndChar,3)
    return
    :B0:tbx::
        sendByClipboard("tuberculous infection" A_EndChar,3)
    return
    :B0:sos::
        sendByClipboard("suboptimal study" A_EndChar,3)
    return
    :B0:sos1::
        sendByClipboard("suboptimal study due to motion artifact" A_EndChar,4)
    return
    :B0:sos2::
        sendByClipboard("suboptimal study due to malpositioning." A_EndChar,4)
    return
    :B0:prl::
        sendByClipboard("probably related to" A_EndChar,3)
    return
    :B0:prx::
        sendByClipboard("pre-existing" A_EndChar,3)
    return
    :B0:nva::
        sendByClipboard("normal variant" A_EndChar,3)
    return
    :B0:afl::
        sendByClipboard("air-fluid level" A_EndChar,3)
    return
    :B0:mae::
        sendByClipboard("mass effect" A_EndChar,3)
    return
    :B0:oprt::
        sendByClipboard("post-operative and post-radiation changes" A_EndChar,4)
    return
    :B0:rtc::
        sendByClipboard("post-radiation change" A_EndChar,3)
    return
    :B0:txc::
        sendByClipboard("post-treatment changes" A_EndChar,3)
    return
    :B0:abc::
        sendByClipboard("post-ablation changes" A_EndChar,3)
    return
    :B0:nec::
        sendByClipboard("necrosis" A_EndChar,3)
    return
    :*B0:nec1::
        sendByClipboard("necrotic",3)
    return
    :B0:yre::
        sendByClipboard("hyperemia" A_EndChar,3)
    return
    :B0:yrc::
        sendByClipboard("hyperemic change" A_EndChar,3)
    return
    :B0:flc::
        sendByClipboard("fluid collection" A_EndChar,3)
    return
    :B0:dev::
        sendByClipboard("deviation" A_EndChar,3)
    return
    :B0:rco::
        sendByClipboard("reconstitution" A_EndChar,3)
    return
    :B0:ivs::
        sendByClipboard("invasion" A_EndChar,3)
    return
    :B0:ltz::
        sendByClipboard("lateralization" A_EndChar,3)
    return
    :B0:mdz::
        sendByClipboard("medialization" A_EndChar,3)
    return
    :B0:dz::
        sendByClipboard("disease" A_EndChar,2)
    return
    :B0:inv::
        sendByClipboard("involving" A_EndChar,3)
    return
    :B0:ivm::
        sendByClipboard("involvement" A_EndChar,3)
    return
    :B0:sh::
        sendByClipboard("showing" A_EndChar,2)
    return
    :B0:yd::
        sendByClipboard("showed" A_EndChar,2)
    return
    :B0:ys::
        sendByClipboard("shows" A_EndChar,2)
    return
    :B0:haz::
        sendByClipboard("haziness" A_EndChar,3)
    return
    :B0:owu::
        sendByClipboard("otherwise unremarkable" A_EndChar,3)
    return
    :B0:reg::
        sendByClipboard("region" A_EndChar,3)
    return
    :*B0:reg1::
        sendByClipboard("regions",3)
    return
    :*B0:reg2::
        sendByClipboard("regional",3)
    return
    :B0:asp::
        sendByClipboard("aspect" A_EndChar,3)
    return
    :*B0:asp1::
        sendByClipboard("aspects",3)
    return
    :B0:fid::
        sendByClipboard("filling defect" A_EndChar,3)
    return
    :*B0:fid1::
        sendByClipboard("filling defects",3)
    return
    :B0:xtn::
        sendByClipboard("extension" A_EndChar,3)
    return
    :B0:wxt::
        sendByClipboard("with extension to" A_EndChar,3)
    return
    :B0:hop::
        sendByClipboard("hypoplastic" A_EndChar,3)
    return
    :*B0:hop1::
        sendByClipboard("hypoplasia",3)
    return
    :B0:tor::
        sendByClipboard("tortuous" A_EndChar,3)
    return
    :B0:psc::
        sendByClipboard("presence" A_EndChar,3)
    return
    :B0:ifn::
        sendByClipboard("infarction" A_EndChar,3)
    return
    :*B0:ifn1::
        sendByClipboard("infarctions",3)
    return
    :B0:ifr::
        sendByClipboard("infarct" A_EndChar,3)
    return
    :*B0:ifr1::
        sendByClipboard("infarcts",3)
    return
    :B0:isc::
        sendByClipboard("ischemic change" A_EndChar,3)
    return
    :*B0:isca::
        sendByClipboard("ischemia",3)
    return
    :B0:dia::
        sendByClipboard("diameter" A_EndChar,3)
    return
    :B0:hrn::
        sendByClipboard("hernia" A_EndChar,3)
    return
    :*B0:hrn1::
        sendByClipboard("herniation",3)
    return
    :B0:cmp::
        sendByClipboard("compression" A_EndChar,3)
    return
    :*B0:cmp1::
        sendByClipboard("compressed",3)
    return
    :B0:bif::
        sendByClipboard("bifurcation" A_EndChar,3)
    return
    :B0:ter::
        sendByClipboard("territory" A_EndChar,3)
    return
    :*B0:mcat::
        sendByClipboard("MCA territory",3)
    return
    :*B0:acat::
        sendByClipboard("ACA territory",3)
    return
    :*B0:pcat::
        sendByClipboard("PCA territory",3)
    return
    :*B0:mcat1::
        sendByClipboard("MCA territories",4)
    return
    :*B0:acat1::
        sendByClipboard("ACA territories",4)
    return
    :*B0:pcat1::
        sendByClipboard("PCA territories",4)
    return
    :*B0:ter1::
        sendByClipboard("territories",3)
    return
    :B0:ede::
        sendByClipboard("edema" A_EndChar,3)
    return
    :B0:pfc::
        sendByClipboard("perifocal" A_EndChar,3)
    return
    :B0:pfe::
        sendByClipboard("perifocal edema" A_EndChar,3)
    return
    :B0:dire::
        sendByClipboard("diffusion restriction" A_EndChar,4)
    return
    :B0:aln::
        sendByClipboard("alignment" A_EndChar,3)
    return
    :B0:rcr::
        sendByClipboard("recurrence" A_EndChar,3)
    return
    :B0:anu::
        sendByClipboard("aneurysm" A_EndChar,3)
    return
    :B0:anu1::
        sendByClipboard("aneurysms" A_EndChar,4)
    return
    :B0:ret::
        sendByClipboard("retention" A_EndChar,3)
    return
    :B0:hpt::
        sendByClipboard("hypertrophy" A_EndChar,3)
    return
    :B0:ptn::
        sendByClipboard("patent" A_EndChar,3)
    return
    :B0:emb::
        sendByClipboard("embolism" A_EndChar,3)
    return
    :B0:teb::
        sendByClipboard("thromboembolism" A_EndChar,3)
    return
    :B0:ar::
        sendByClipboard("artery" A_EndChar,2)
    return
    :*B0:ar1::
        sendByClipboard("arteries",2)
    return
    :B0:obl::
        sendByClipboard("obliterated" A_EndChar,3)
    return
    :*B0:obl1::
        sendByClipboard("obliteration",3)
    return
    :B0:obc::
        sendByClipboard("obscured" A_EndChar,3)
    return
    :B0:lao::
        sendByClipboard("the largest one measured" A_EndChar,3)
    return
    :B0:ldi::
        sendByClipboard("in largest dimension" A_EndChar,3)
    return
    :B0:ut::
        sendByClipboard("up to" A_EndChar,2)
    return
    :B0:mulv::
        sendByClipboard("multiple varied-size" A_EndChar,4)
    return
    :B0:ef::
        sendByClipboard("effusion" A_EndChar,2)
    return
    :B0:flu::
        sendByClipboard("fluid" A_EndChar,3)
    return
    :B0:msa::
        sendByClipboard("magnetic susceptibility artifacts" A_EndChar,3)
    return
    :B0:bha::
        sendByClipboard("beam-hardening artifacts" A_EndChar,3)
    return
    :B0:bha0::
        sendByClipboard("There is beam-hardening artifacts and obscuration of adjacent structure." A_EndChar,4)
    return
    :B0:fca::
        sendByClipboard("fibrotic change" A_EndChar,3)
    return
    :B0:fcc::
        sendByClipboard("fibrocalcified change" A_EndChar,3)
    return
    :B0:fcl::
        sendByClipboard("fibrocalcified lesions" A_EndChar,3)
    return
    :B0:fnl::
        sendByClipboard("fibronodular lesions" A_EndChar,3)
    return
    :B0:nat::
        sendByClipboard("nature to be determined" A_EndChar,3)
    return
    :B0:nt::
        sendByClipboard("with indeterminate nature" A_EndChar,2)
    return
    :B0:moa::
        sendByClipboard("motion artifacts" A_EndChar,3)
    return
    :*B0:moa0::
        sendByClipboard("motion artifacts are noted, which may obscure small lesions.",3)
    return
    :B0:les::
        sendByClipboard("lesion" A_EndChar,3)
    return
    :*B0:les1::
        sendByClipboard("lesions",3)
    return
    :B0:abs::
        sendByClipboard("abscess" A_EndChar,3)
    return
    :*B0:abs1::
        sendByClipboard("abscesses",3)
    return
    :B0:lap::
        sendByClipboard("lymphadenopathy" A_EndChar,3)
    return
    :*B0:lap1::
        sendByClipboard("lymphadenopathies",3)
    return
    :B0:opc::
        sendByClipboard("post-operative change" A_EndChar,3)
    return
    :*B0:opc1::
        sendByClipboard("post-operative changes",3)
    return
    :B0:ca::
        sendByClipboard("calcification" A_EndChar,2)
    return
    :B0:cal::
        sendByClipboard("calcified" A_EndChar,3)
    return
    :B0:ca1::
        sendByClipboard("calcifications" A_EndChar,3)
    return
    :B0:ath::
        sendByClipboard("atherosclerotic change" A_EndChar,3)
    return
    :*B0:ath1::
        sendByClipboard("atherosclerotic changes",3)
    return
    :B0:caca::
        sendByClipboard("Calcified atherosclerotic plaques in the coronary arteries." A_EndChar,4)
    return
    :B0:atc::
        sendByClipboard("atherosclerotic calcification" A_EndChar,3)
    return
    :B0:atca::
        sendByClipboard("atherosclerotic calcification of the aorta." A_EndChar,4)
    return
    :*B0:atcac::
        sendByClipboard("atherosclerotic calcification of the aorta and coronary arteries.",4)
    return
    :*B0:atccc::
        sendByClipboard("calcification of the aorta, coronary arteries and cardiac valve.",4)
    return
    :B0:gca::
        sendByClipboard("cardiomegaly. atherosclerotic calcification of the aorta." A_EndChar,3)
    return
    :*B0:mgca::
        sendByClipboard("mild cardiomegaly. atherosclerotic calcification of the aorta.",3)
    return
    :*B0:gcac::
        sendByClipboard("cardiomegaly. atherosclerotic calcification of the aorta and coronary arteries.",3)
    return
    :B0:gcc::
        sendByClipboard("cardiomegaly. atherosclerotic calcification of the aorta and coronary arteries." A_EndChar,3)
    return
    :*B0:mgcc::
        sendByClipboard("mild cardiomegaly. atherosclerotic calcification of the aorta and coronary arteries.",3)
    return
    :*B0:gccc::
        sendByClipboard("cardiomegaly. calcification of the aorta, coronary arteries and cardiac valve.",3)
    return
    :*B0:mgccc::
        sendByClipboard("mild cardiomegaly. calcification of the aorta, coronary arteries and cardiac valve.",4)
    return
    :B0:met::
        sendByClipboard("metastasis" A_EndChar,3)
    return
    :*B0:met1::
        sendByClipboard("metastases",3)
    return
    :B0:mets::
        sendByClipboard("metastatic lesions" A_EndChar,4)
    return
    :*B0:met2::
        sendByClipboard("metastatic",3)
    return
    :*B0:bon0::
        sendAndNextLine("no obvious focal bone lesion.")
    return
    :B0:fas::
        sendByClipboard("fat stranding" A_EndChar,3)
    return
    :B0:adj::
        sendByClipboard("adjacent" A_EndChar,3)
    return
    :B0:sts::
        sendByClipboard("soft tissue swelling" A_EndChar,3)
    return
    :B0:lb::
        sendByClipboard("lobe" A_EndChar,2)
    return
    :*B0:lb1::
        sendByClipboard("lobes",2)
    return
    :*B0:lb2::
        sendByClipboard("lobar",2)
    return
    :B0:ste::
        sendByClipboard("stenosis" A_EndChar,3)
    return
    :B0:ocl::
        sendByClipboard("occlusion" A_EndChar,3)
    return
    :*B0:stoc::
        sendByClipboard("steno-occlusion",3)
    return
    :B0:gl::
        sendByClipboard("gland" A_EndChar,2)
    return
    :*B0:gl1::
        sendByClipboard("glands",2)
    return
    :B0:arti::
        sendByClipboard("artifacts" A_EndChar,4)
    return
    :B0:ln::
        sendByClipboard("lymph node" A_EndChar,2)
    return
    :*B0:ln1::
        sendByClipboard("lymph nodes",2)
    return
    :*B0:mth-::
        sendByClipboard("黏膜增厚",3)
    return
    :B0:mth::
        sendByClipboard("mucosal thickening" A_EndChar,3)
    return
    :B0:wth::
        sendByClipboard("wall thickening" A_EndChar,3)
    return
    :B0:thi::
        sendByClipboard("thickening" A_EndChar,3)
    return
    :B0:irn::
        sendByClipboard("irregular narrowing" A_EndChar,3)
    return
    :B0:irr::
        sendByClipboard("irregular" A_EndChar,3)
    return
    :*B0:irr1::
        sendByClipboard("irregularity",3)
    return
    :B0:le::
        sendByClipboard("level" A_EndChar,2)
    return
    :*B0:le1::
        sendByClipboard("levels",2)
    return
    :B0:hem::
        sendByClipboard("hemorrhage" A_EndChar,3)
    return
    :B0:nar::
        sendByClipboard("narrowing" A_EndChar,3)
    return
    :B0:nmx::
        sendAndNextLine("no definite metastatic lesion in visible field. (Mx)")
    return
    ;~ ::dis::distended
    :B0:obs::
        sendByClipboard("obstruction" A_EndChar,3)
    return
    :*B0:obs1::
        sendByClipboard("obstructive",3)
    return
    :B0:lig::
        sendByClipboard("ligament" A_EndChar,3)
    return
    :*B0:lig1::
        sendByClipboard("ligaments",3)
    return
    :B0:tdn::
        sendByClipboard("tendon" A_EndChar,3)
    return
    :*B0:tdn1::
        sendByClipboard("tendons",3)
    return
    :B0:ma::
        sendByClipboard("mass" A_EndChar,2)
    return
    :B0:mle::
        sendByClipboard("mass lesion" A_EndChar,3)
    return
    :*B0:ma1::
        sendByClipboard("masses",2)
    return
    :B0:tu::
        sendByClipboard("tumor" A_EndChar,2)
    return
    :*B0:tu1::
        sendByClipboard("tumors",2)
    return
    :B0:tu2::
        sendByClipboard("tumoral" A_EndChar,3)
    return
    :*B0:nd-::
        sendByClipboard("結節",2)
    return
    :B0:nd::
        sendByClipboard("nodule" A_EndChar,2)
    return
    :*B0:nd1::
        sendByClipboard("nodules",2)
    return
    :*B0:nd2::
        sendByClipboard("nodular",2)
    return
    :B0:nod::
        sendByClipboard("nodularity" A_EndChar,3)
    return
    :*B0:nod1::
        sendByClipboard("nodularities",3)
    return
    :B0:nos::
        sendByClipboard("non-specific" A_EndChar,3)
    return
    :*B0:pbns::
        sendByClipboard("probably non-specific",3)
    return
    :B0:plc::
        sendByClipboard("placement of" A_EndChar,3)
    return
    :B0:ett::
        sendByClipboard("an endotracheal tube" A_EndChar,3)
    return
    :B0:dlc::
        sendByClipboard("a double-lumen catheter" A_EndChar,3)
    return
    :B0:rcvc::
        sendByClipboard("a right central venous catheter" A_EndChar,4)
    return
    :B0:lcvc::
        sendByClipboard("a left central venous catheter" A_EndChar,4)
    return
    :B0:rpor::
        sendByClipboard("a right implantable venous access port" A_EndChar,4)
    return
    :B0:lpor::
        sendByClipboard("a left implantable venous access port" A_EndChar,4)
    return
    :B0:ppo::
        sendByClipboard("placement of implantable venous access port." A_EndChar,3)
    return
    :B0:ngt::
        sendByClipboard("a nasoenteric tube" A_EndChar,3)
    return
    :B0:pdt::
        sendByClipboard("a peritoneal dialysis tube" A_EndChar,3)
    return
    :B0:fol::
        sendByClipboard("a Foley catheter" A_EndChar,3)
    return
    :B0:cath::
        sendByClipboard("catheter" A_EndChar,4)
    return
    :B0:pig::
        sendByClipboard("pigtail" A_EndChar,3)
    return
    :*B0:pig1::
        sendByClipboard("pigtails",3)
    return
    :B0:enl::
        sendByClipboard("enlarged" A_EndChar,3)
    return
    :*B0:enl1::
        sendByClipboard("enlargement",3)
    return
    ;~ ::subc::subcutaneous
    :B0:thm::
        sendByClipboard("thrombosis" A_EndChar,3)
    return
    :*B0:thm1::
        sendByClipboard("thrombosed",3)
    return
    :B0:ptr::
        sendByClipboard("partially thrombosed" A_EndChar,3)
    return
    :B0:thr::
        sendByClipboard("thrombus" A_EndChar,3)
    return
    :B0:tmy::
        sendByClipboard("thrombectomy" A_EndChar,3)
    return
    :*B0:thr1::
        sendByClipboard("thrombi",3)
    return
    :B0:atr::
        sendByClipboard("atrophy" A_EndChar,3)
    return
    :B0:atrc::
        sendByClipboard("atrophic change" A_EndChar,4)
    return
    :*B0:atrc1::
        sendByClipboard("atrophic changes",4)
    return
    :B0:atk::
        sendByClipboard("atrophic change of bilateral kidneys." A_EndChar,3)
    return
    :*B0:atrk::
        sendByClipboard("atrophic change of the right kidney.",3)
    return
    :*B0:atlk::
        sendByClipboard("atrophic change of the left kidney.",3)
    return
    :B0:ddx::
        sendByClipboard("differential diagnosis including" A_EndChar,3)
    return
    :B0:ind::
        sendByClipboard("indeterminate" A_EndChar,3)
    return

    ;brain
    :B0:cist::
        sendByClipboard("cistern" A_EndChar,4)
    return
    :*B0:cist1::
        sendByClipboard("cisterns",4)
    return

    :B0:corr::
        sendByClipboard("corona radiata" A_EndChar,4)
    return

    :*B0:obsf::
        sendByClipboard("obliterated sulci and fissures",3)
    return

    :*B0:idem::
        sendByClipboard("intradural extramedullary",3)
    return
    :B0:imd::
        sendByClipboard("intramedullary" A_EndChar,3)
    return
    :B0:idl::
        sendByClipboard("intradural" A_EndChar,3)
    return
    :B0:xdl::
        sendByClipboard("extradural" A_EndChar,3)
    return

    :B0:swi::
        sendByClipboard("SWI shows" A_EndChar,3)
    return
    :*B0:swip::
        sendAndNextLine("SWI shows hypointensities in bilateral posterolateral putamina. ")
    return
    :*B0:swiq::
        sendAndNextLine("SWI shows mild hypointensities in bilateral posterolateral putamina. ")
    return
    :*B0:swi0::
        sendAndNextLine("SWI shows no significant micorbleeds  ")
    return

    :*B0:swi1::
        sendByClipboard("SWI shows some micorbleeds",3)
    return

    :B0:mcb::
        sendByClipboard("microbleed" A_EndChar,3)
    return
    :*B0:mcb1::
        sendByClipboard("microbleeds",3)
    return

    :*B0:cffx::
        sendByClipboard("craniofacial fracture",3)
    return
    :*B0:desh::
        sendByClipboard("disproportionately enlarged subarachnoid space hydrocephalus",3)
    return

    :*B0:prfc::
        sendByClipboard("parafalcine",3)
    return
    :B0:otk::
        sendByClipboard("optic chiasm" A_EndChar,3)
    return

    :*B0:sptn::
        sendByClipboard("supratentorial",3)
    return
    :*B0:iftn::
        sendByClipboard("infratentorial",3)
    return

    :o:ash::
        {
            sendByClipboard("asymmetric hypodense area at , which could be leukoaraiosis or recent cerebrovascular event.")
            send % "{Left 63}"
        }
    return
    :*B0:stcp::
        sendByClipboard("striatocapsular region",3)
    return
    :B0:brl::
        sendByClipboard("brain atrophy, leukoaraiosis." A_EndChar,3)
    return
    :B0:mba::
        sendByClipboard("mild brain atrophy" A_EndChar,3)
    return
    :*B0:brli::
        sendByClipboard("brain atrophy, leukoaraiosis, old insult(s).",3)
    return
    :*B0:brlo::
        sendByClipboard("brain atrophy, leukoaraiosis, old lacune(s).",3)
    return
    :B0:cnp::
        sendByClipboard("clinoid process" A_EndChar,3)
    return
    :*B0:cnp1::
        sendByClipboard("clinoid processes",3)
    return
    :B0:ppb::
        sendByClipboard("preserved posterior pituitary bright T1 signal." A_EndChar,3)
    return
    :B0:cbp::
        sendByClipboard("cerebellar peduncle" A_EndChar,3)
    return
    :*B0:cbp1::
        sendByClipboard("cerebellar peduncles",3)
    return

    :B0:mgt::
        sendByClipboard("meningitis" A_EndChar,3)
    return

    :B0:ina::
        sendByClipboard("intracranial arteries" A_EndChar,3)
    return
    :*B0:dssa::
        sendByClipboard("dissecting aneurysm",3)
    return
    :B0:dth::
        sendByClipboard("dural thickening" A_EndChar,3)
    return
    :B0:fcr::
        sendByClipboard("falx cerebri" A_EndChar,3)
    return
    :B0:ten::
        sendByClipboard("tentorium" A_EndChar,3)
    return
    :*B0:ten1::
        sendByClipboard("tentorial",3)
    return
    :B0:ftn::
        sendByClipboard("falcotentorial" A_EndChar,3)
    return
    :B0:slw::
        sendByClipboard("sphenoid lesser wing" A_EndChar,3)
    return
    :B0:sgw::
        sendByClipboard("sphenoid greater wing" A_EndChar,3)
    return
    :B0:srd::
        sendByClipboard("sphenoid ridge" A_EndChar,3)
    return
    :*B0:plsf::
        sendByClipboard("planum sphenoidale",3)
    return

    :*B0:etym::
        sendByClipboard("epitympanum",3)
    return
    :*B0:mtym::
        sendByClipboard("mesotympanum",3)
    return
    :*B0:htym::
        sendByClipboard("hypotympanum",3)
    return

    :B0:cah::
        sendByClipboard("caudate head" A_EndChar,3)
    return
    :B0:gp::
        sendByClipboard("globus pallidus" A_EndChar,2)
    return
    :*B0:gp1::
        sendByClipboard("globus pallidi",2)
    return
    :B0:lgp::
        sendByClipboard("left globus pallidus" A_EndChar,3)
    return
    :B0:rgp::
        sendByClipboard("right globus pallidus" A_EndChar,3)
    return
    :B0:bgp::
        sendByClipboard("bilateral globus pallidi" A_EndChar,3)
    return
    :B0:ptm::
        sendByClipboard("putamen" A_EndChar,3)
    return
    :*B0:ptm1::
        sendByClipboard("putamina",3)
    return
    :B0:isl::
        sendByClipboard("insula" A_EndChar,3)
    return
    :*B0:isl1::
        sendByClipboard("insular",3)
    return

    :cB0:orn::
        sendByClipboard("osteoradionecrosis" A_EndChar,3)
    return

    :B0:bnm::
        sendByClipboard("brain metastases" A_EndChar,3)
    return
    :B0:ach::
        sendByClipboard("arachnoid" A_EndChar,3)
    return
    :B0:acha::
        sendByClipboard("anterior choroidal artery" A_EndChar,4)
    return
    :B0:pcha::
        sendByClipboard("posterior choroidal artery" A_EndChar,4)
    return
    :B0:dmy::
        sendByClipboard("demyelinating" A_EndChar,3)
    return
    :B0:tea::
        sendByClipboard("transependymal absorption" A_EndChar,3)
    return
    :B0:psp::
        sendByClipboard("paraspinal" A_EndChar,3)
    return
    :*B0:psp0::
        sendAndNextLine("clear paraspinal soft tissue.")
    return
    :B0:pnc::
        sendByClipboard("pneumocephalus" A_EndChar,3)
    return
    :B0:eib::
        sendByClipboard("EC-IC bypass" A_EndChar,3)
    return
    :*B0:tsc0::
        sendByClipboard("
(
Multifocal ill-defined hyperintensity change on FLAIR images at bilateral cortical/subcortical junction without enhancement. Tuberous sclerosis with cortical/subcortical tubers is compatible.
- Multiple tiny subependymal nodules with variable enhancement.
)")
    return
    :B0:hmv::
        sendByClipboard("hematoventricle" A_EndChar,3)
    return
    :B0:cbn::
        sendByClipboard("cyberknife" A_EndChar,3)
    return
    :B0:pmj::
        sendByClipboard("ponto-medullary junction" A_EndChar,3)
    return
    :B0:brm::
        sendByClipboard("brainstem" A_EndChar,3)
    return
    :B0:mdo::
        sendByClipboard("medulla oblongata" A_EndChar,3)
    return
    :*B0:sel0::
        sendByClipboard("MRI of the sella without/with contrast enhancement shows:`r`n-",3)
    return
    ;~ ::mca1::MCA M1
    ;~ ::mca2::MCA M2
    ;~ ::aca1::ACA A1
    ;~ ::aca2::ACA A2
    ;~ ::pca1::PCA P1
    ;~ ::pca2::PCA P2
    :B0:rbg::
        sendByClipboard("right basal ganglion" A_EndChar,3)
    return
    :B0:lbg::
        sendByClipboard("left basal ganglion" A_EndChar,3)
    return
    :B0:bbg::
        sendByClipboard("bilateral basal ganglia" A_EndChar,3)
    return

    :B0:rth::
        sendByClipboard("right thalamus" A_EndChar,3)
    return
    :B0:lth::
        sendByClipboard("left thalamus" A_EndChar,3)
    return
    :B0:bth::
        sendByClipboard("bilateral thalami" A_EndChar,3)
    return

    :B0:rfl::
        sendByClipboard("right frontal lobe" A_EndChar,3)
    return
    :B0:lfl::
        sendByClipboard("left frontal lobe" A_EndChar,3)
    return
    :B0:bfl::
        sendByClipboard("bilateral frontal lobes" A_EndChar,3)
    return
    :B0:rpl::
        sendByClipboard("right parietal lobe" A_EndChar,3)
    return
    :B0:lpl::
        sendByClipboard("left parietal lobe" A_EndChar,3)
    return
    :B0:bpl::
        sendByClipboard("bilateral parietal lobes" A_EndChar,3)
    return
    :B0:rol::
        sendByClipboard("right occipital lobe" A_EndChar,3)
    return
    :B0:lol::
        sendByClipboard("left occipital lobe" A_EndChar,3)
    return
    :B0:bol::
        sendByClipboard("bilateral occipital lobes" A_EndChar,3)
    return
    :B0:rtl::
        sendByClipboard("right temporal lobe" A_EndChar,3)
    return
    :B0:ltl::
        sendByClipboard("left temporal lobe" A_EndChar,3)
    return
    :B0:btl::
        sendByClipboard("bilateral temporal lobes" A_EndChar,3)
    return

    :B0:dub::
        sendByClipboard("dural-based" A_EndChar,3)
    return
    :B0:acf::
        sendByClipboard("anterior cranial fossa" A_EndChar,3)
    return
    :B0:mcf::
        sendByClipboard("middle cranial fossa" A_EndChar,3)
    return
    :B0:pcf::
        sendByClipboard("posterior cranial fossa" A_EndChar,3)
    return
    :B0:iac::
        sendByClipboard("internal auditory canal" A_EndChar,3)
    return
    :B0:eac::
        sendByClipboard("external auditory canal" A_EndChar,3)
    return
    :B0:cmc::
        sendByClipboard("chronic mastoiditis change" A_EndChar,3)
    return
    :B0:vmg::
        sendByClipboard("ventriculomegaly" A_EndChar,3)
    return
    :B0:sbd::
        sendByClipboard("subdural" A_EndChar,3)
    return
    :B0:epd::
        sendByClipboard("epidural" A_EndChar,3)
    return
    :B0:sar::
        sendByClipboard("subarachnoid" A_EndChar,3)
    return
    :B0:bl::
        sendByClipboard("Brain atrophy with dilated sulci, fissures and ventricles.`r`n- ", 2)
        if InStr(getRisExamItemsAll()[1], "MR"){
            sendByClipboard("Multiple nonspecific hyperintensities over bilateral cerebral white matter on T2 FLAIR, suggestive of leukoaraiosis.`r`n- ")
        }else{
            sendByClipboard("Low densities at bilateral periventricular white matter, suggestive of leukoaraiosis.`r`n- ")
        }
    return
    :B0:htr::
        sendByClipboard("hemorrhagic transformation" A_EndChar,3)
    return
    :*B0:bo0::
        sendByClipboard("no definite intracranial organic lesion.",2)
    return
    :B0:pvs::
        sendByClipboard("perivascular spaces" A_EndChar,3)
    return
    :B0:skh::
        sendByClipboard("scalp hematoma" A_EndChar,3)
    return
    :B0:skp::
        sendByClipboard("scalp" A_EndChar,3)
    return
    :B0:cx::
        sendByClipboard("cortex" A_EndChar,2)
    return
    :*B0:cx1::
        sendByClipboard("cortical",2)
    return
    :B0:scx::
        sendByClipboard("subcortical" A_EndChar,3)
    return
    :B0:scw::
        sendByClipboard("subcortical" A_EndChar,3)
    return
    :B0:gy::
        sendByClipboard("gyrus" A_EndChar,2)
    return
    :*B0:gy1::
        sendByClipboard("gyri",2)
    return
    :B0:ssr::
        sendByClipboard("suprasellar" A_EndChar,3)
    return
    :B0:isr::
        sendByClipboard("infrasellar" A_EndChar,3)
    return
    :B0:psr::
        sendByClipboard("parasellar" A_EndChar,3)
    return
    :*B0:sslr::
        sendByClipboard("sellar-suprasellar",3)
    return
    :B0:esa::
        sendByClipboard("empty sella" A_EndChar,3)
    return
    :B0:lesa::
        sendByClipboard("enlarged and empty sella" A_EndChar,4)
    return
    :*B0:sku0::
        sendByClipboard("no definite abnormal focal bony change. The sella is intact. No definite change in the vascular groove and the sutures.",3)
    return
    :B0:hpp::
        sendByClipboard("hippocampus" A_EndChar,3)
    return
    :B0:clnc::
        sendByClipboard("cortical laminar necrosis" A_EndChar,4)
    return
    :B0:rof::
        sendByClipboard("foramen rotundum" A_EndChar,3)
    return
    :B0:ovf::
        sendByClipboard("foramen ovale" A_EndChar,3)
    return
    :B0:juf::
        sendByClipboard("jugular foramen" A_EndChar,3)
    return
    :B0:hyc::
        sendByClipboard("hypoglossal canal" A_EndChar,3)
    return
    :B0:cvs::
        sendByClipboard("cavernous sinus" A_EndChar,3)
    return
    :B0:cvn::
        sendByClipboard("cavernous" A_EndChar,3)
    return
    :B0:mvm::
        sendByClipboard("medullary venous malformation" A_EndChar,3)
    return
    :B0:dbs0::
        sendByClipboard("status post bilateral deep brain stimulator wire insertion." A_EndChar,4)
    return
    :*B0:dbs00::
        sendByClipboard("placement of deep brain stimulator at bilateral subthalamic nuclei from bilateral frontal regions, which causing artifacts on images.",4)
    return
    :B0:skl::
        sendByClipboard("skull" A_EndChar,3)
    return
    :B0:mtd::
        sendByClipboard("mastoid" A_EndChar,3)
    return
    :B0:moya::
        sendByClipboard("reaching brain surface with regional neovasculature" A_EndChar,4)
    return
    :B0:csi::
        sendByClipboard("centrum semiovale" A_EndChar,3)
    return
    :B0:b0::
        sendByClipboard("no definite acute intracranial hemorrhage." A_EndChar,2)
    return
    :*B0:b00::
        sendAndNextLine("no definite acute intracranial hemorrhage.")
    return
    :*B0:b/::
        sendAndNextLine("no definite acute intracranial hemorrhage. \")
    return
    :B0:vps::
        sendByClipboard("ventriculo-peritoneal shunt" A_EndChar,3)
    return
    :B0:lai::
        sendByClipboard("lacunar infarcts" A_EndChar,3)
    return
    :B0:cvsp::
        sendByClipboard("cavum septum pellucidum" A_EndChar,4)
    return
    :B0:cvvi::
        sendByClipboard("cavum velum interpositum" A_EndChar,4)
    return
    :*B0:orb=::
        sendByClipboard("CT of the orbits without contrast enhancement shows:`r`n-",3)
    return
    :*B0:tem=::
        sendByClipboard("HRCT of the temporal bones without contrast enhancement shows:`r`n-",3)
    return
    :*B0:sin=::
        sendByClipboard("CT of the paranasal sinuses without contrast enhancement shows:`r`n-",3)
    return
    :*B0:sel=::
        sendByClipboard("MRI of the sella without/with contrast enhancement shows:`r`n-",3)
    return
    :B0:mng::
        sendByClipboard("meningioma" A_EndChar,3)
    return
    :*B0:mng1::
        sendByClipboard("meningiomas",3)
    return
    :*B0:evdd::
        sendByClipboard("extra-ventricular drainage",3)
    return
    :*B0:incp::
        sendByClipboard("internal capsule",3)
    return
    :*B0:excp::
        sendByClipboard("external capsule",3)
    return
    :B0:ifd::
        sendByClipboard("infundibulum" A_EndChar,3)
    return
    :B0:coc::
        sendByClipboard("corpus callosum" A_EndChar,3)
    return
    :B0:lpm::
        sendByClipboard("leptomeningeal" A_EndChar,3)
    return
    :B0:lmcc::
        sendByClipboard("leptomeningeal carcinomatosis" A_EndChar,4)
    return
    :B0:cpa::
        sendByClipboard("cerebellopontine angle" A_EndChar,3)
    return
    :B0:cis::
        sendByClipboard("3D T2WI CISS shows" A_EndChar,3)
    return
    :*B0:csr0::
        sendByClipboard("possible contact of right AICA loop with right facial nerve root exit zone.",3)
    return
    :*B0:csl0::
        sendByClipboard("possible contact of left AICA loop with left facial nerve root exit zone.",3)
    return
    :*B0:csr1::
        sendByClipboard("contact of right AICA loop with right facial nerve root exit zone.",3)
    return
    :*B0:csl1::
        sendByClipboard("contact of left AICA loop with left facial nerve root exit zone.",3)
    return
    :B0:hdc::
        sendByClipboard("hydrocephalus" A_EndChar,3)
    return
    :B0:iax::
        sendByClipboard("intra-axial" A_EndChar,3)
    return
    :B0:xax::
        sendByClipboard("extra-axial" A_EndChar,3)
    return
    :B0:cvx::
        sendByClipboard("convexity" A_EndChar,3)
    return
    :*B0:cvx1::
        sendByClipboard("convexities",3)
    return
    :B0:sin::
        sendByClipboard("sinus" A_EndChar,3)
    return
    :*B0:sin1::
        sendByClipboard("sinuses",3)
    return
    :*B0:sela0::
        sendByClipboard("normal size of sellar fossa.",4)
    return
    :*B0:sten0::
        sendByClipboard("Stenver's view showed normal size of bilateral internal auditory canals.",4)
    return
    :*B0:mast0::
        sendByClipboard("Well pneumatization of bilateral mastoid bone.",4)
    return
    :*B0:bm/::
        sendByClipboard("bilateral mastoid effusion.",2)
    return
    :*B0:rm/::
        sendByClipboard("right mastoid effusion.",2)
    return
    :*B0:lm/::
        sendByClipboard("left mastoid effusion.",2)
    return
    :B0:mos::
        sendByClipboard("mastoiditis" A_EndChar,3)
    return
    :*B0:c2c::
        sendByClipboard("cervicocranial arteries",2)
    return
    :B0:cro::
        sendByClipboard("craniotomy" A_EndChar,3)
    return
    :B0:cre::
        sendByClipboard("craniectomy" A_EndChar,3)
    return
    :B0:bur::
        sendByClipboard("burr hole" A_EndChar,3)
    return
    :*B0:bur1::
        sendByClipboard("burr holes",3)
    return
    :B0:pal::
        sendByClipboard("parenchyma loss" A_EndChar,3)
    return
    :*B0:pit0::
        sendByClipboard("No evidence of pituitary tumor.`r`n- No deviation of pituitary stalk.`r`n- The posterior pituitary bright SI is preserved.`r`n- The optic chiasm is not displaced.",3)
    return
    :*B0:pit1::
        sendByClipboard("preserved physiologic high signal intensity on T1WI at the posterior pituitary gland",3)
    return
    :B0:hump::
        sendByClipboard("humping of the diaphragma sella, compatible with peripubertal changes" A_EndChar,4)
    return
    :*B0:orb0::
        sendByClipboard("There is no definite abnormality nor enhancement of bilateral globes, periseptal soft tissue, optic nerves and complex, extraorcular muscles and the bony orbit.",3)
    return
    :*B0:or0::
        sendByClipboard("intact orbits.",2)
    return
    :B0:pit::
        sendByClipboard("pituitary" A_EndChar,3)
    return
    :B0:ptg::
        sendByClipboard("pituitary gland" A_EndChar,3)
    return
    :B0:cb::
        sendByClipboard("cerebrum" A_EndChar,2)
    return
    :*B0:cb1::
        sendByClipboard("cerebral",2)
    return
    :B0:crb::
        sendByClipboard("cerebellum" A_EndChar,3)
    return
    :*B0:crb1::
        sendByClipboard("cerebellar",3)
    return
    :B0:wm::
        sendByClipboard("white matter" A_EndChar,2)
    return
    :B0:gm::
        sendByClipboard("gray matter" A_EndChar,2)
    return
    :B0:gwj::
        sendByClipboard("gray-white matter junction" A_EndChar,3)
    return
    :*B0:pvwm::
        sendByClipboard("periventricular white matter",3)
    return
    :*B0:pwvm::
        sendByClipboard("periventricular white matter",3)
    return
    :B0:pvw::
        sendByClipboard("periventricular" A_EndChar,3)
    return
    :*B0:leu-::
        sendByClipboard("非特異性腦白質變化",3)
    return
    :B0:leu::
        sendByClipboard("leukoaraiosis" A_EndChar,3)
    return
    :B0:lue::
        sendByClipboard("leukoaraiosis" A_EndChar,3)
    return
    :B0:bra::
        sendByClipboard("brain atrophy" A_EndChar,3)
    return
    :B0:epm::
        sendByClipboard("encephalomalacia" A_EndChar,3)
    return
    :*B0:csf0::
        sendAndNextLine("normal appearance of sulci, fissures and ventricles. ")
    return
    :*B0:bra0::
        sendAndNextLine("Mild brain atrophy with dilated sulci, fissures and ventricles. ")
    return
    :*B0:bra1::
        sendAndNextLine("Brain atrophy with dilated sulci, fissures and ventricles. ")
    return
    :*B0:bra2::
        sendAndNextLine("Prominent brain atrophy with dilated sulci, fissures and ventricles. ")
    return
    :B0:clu::
        sendAndNextLine("Low densities at bilateral periventricular white matter, suggestive of leukoaraiosis. ")
    return
    :*B0:clu1::
        sendAndNextLine("Low densities at bilateral periventricular white matter, suggestive of mild leukoaraiosis. ")
    return
    :*B0:clu2::
        sendAndNextLine("Confluent low densities at bilateral periventricular white matter, suggestive of leukoaraiosis. ")
    return
    :B0:mlu::
        sendAndNextLine("Multiple nonspecific hyperintensities over bilateral cerebral white matter on T2 FLAIR, suggestive of leukoaraiosis. ")
    return
    :*B0:mlu1::
        sendAndNextLine("Some hyperintensities over bilateral cerebral white matter on FLAIR, suggestive of mild leukoaraiosis. ")
    return
    :*B0:mlu2::
        sendAndNextLine("Confluent nonspecific hyperintensities over bilateral cerebral white matter on T2 FLAIR, suggestive of extensive leukoaraiosis. ")
    return
    :B0:vau::
        sendAndNextLine("normal appearance of the cranial vault and skull base. ")
    return
    :B0:vua::
        sendAndNextLine("normal appearance of the cranial vault and skull base. ")
    return
    :*B0:vau1::
        sendAndNextLine("normal appearance of the skull base. ")
    return
    :*B0:vua1::
        sendAndNextLine("normal appearance of the skull base. ")
    return
    :*B0:dwi0::
        sendAndNextLine("no definite focal restriction of diffusion on DWI and ADC map. ")
    return
    :*B0:diw0::
        sendAndNextLine("no definite focal restriction of diffusion on DWI and ADC map. ")
    return
    :*B0:dw0::
        sendAndNextLine("no definite focal restriction of diffusion on DWI and ADC map. ")
    return
    :*B0:tof0::
        sendAndNextLine("TOF MRA of circle of Willis appears normal. ")
    return
    :*B0:mra0::
        sendAndNextLine("TOF and contrast enhanced MRA shows no significant abnormality of major cervicocranial vessels. ")
    return
    :*B0:mra1::
        sendAndNextLine("TOF MRA shows no significant abnormality of major cervicocranial vessels. ")
    return
    :*B0:mra2::
        sendAndNextLine("Contrast enhanced MRA shows no significant abnormality of major cervicocranial vessels. ")
    return
    :*B0:mas0::
        sendAndNextLine("Clear bilateral mastoid air cells. ")
    return
    :*:mas1::
        {
            sendByClipboard("Decreased pneumatization of mastoid air cells. ")
            send % "{left 19}"
        }
    return
    :*B0:mas2::
        sendAndNextLine("Bilateral small amount mastoid effusion. ")
    return
    :B0:mas::
        sendByClipboard("mastoid air cells" A_EndChar,3)
    return
    :B0:nbe::
        sendAndNextLine("no abnormal enhancing lesion in the brain parenchyma. ")
    return
    :B0:nba::
        sendAndNextLine("no abnormal attenuation in the brain parenchyma. ")
    return
    :*B0:nba1::
        sendAndNextLine("no abnormal SI in the brain parenchyma. ")
    return
    :B0:nbae::
        sendAndNextLine("no abnormal signal change or enhancing lesion in the brain parenchyma. ")
    return
    :*B0:nbae1::
        sendAndNextLine("no abnormal attenuation or enhancing lesion in the brain parenchyma. ")
    return
    :B0:oi::
        sendByClipboard("old insult" A_EndChar,2)
    return
    :*B0:oi1::
        sendByClipboard("old insults",2)
    return
    :B0:rif::
        sendByClipboard("recent ischemia/infarct" A_EndChar,3)
    return
    :*B0:rif1::
        sendByClipboard("recent infarct",3)
    return
    :B0:ric::
        sendByClipboard("recent ischemic change" A_EndChar,3)
    return
    :B0:fro::
        sendByClipboard("frontal" A_EndChar,3)
    return
    :B0:par::
        sendByClipboard("parietal" A_EndChar,3)
    return
    :B0:occ::
        sendByClipboard("occipital" A_EndChar,3)
    return
    :B0:tem::
        sendByClipboard("temporal" A_EndChar,3)
    return

    upToSize:
        send % "{bs " StrLen($.value(0))  "}"
        sendByClipboard("up to " $.value(1) "mm" $.value(2))
        $:=""
    return

    brainLobe:
        ;~ loop % strlen($1)+1
        ;~ send {bs}
        a:=$.value(1), str:=""
        ;~ MsgBox % $
        loop,parse,a
        {
            if (a_loopfield="f")
                str.="fronto-"
            else if (a_loopfield="t")
                str.="temporo-"
            else if (a_loopfield="p")
                str.="parieto-"
            else if (a_loopfield="o")
                str.="occipito-"
            else if (A_LoopField = "i")
                str.="insulo-"
        }
        ;~ MsgBox % str
        send % "{bs " StrLen($.value(0))  "}"
        sendByClipboard(SubStr(str,1,-2) "a" (str~="i)insulo-$"?"r":"l"))
        $:=""
    return
    :B0:th::
        sendByClipboard("thalamus" A_EndChar,2)
    return
    :*B0:th1::
        sendByClipboard("thalami",2)
    return
    :B0:bath::
        sendAndNextLine("atherosclerotic calcification of the intracranial vessels.")
    return
    :*B0:bath0::
        sendAndNextLine("mild atherosclerotic calcification of the intracranial vessels.")
    return
    :B0:bnc::
        sendByClipboard("atherosclerotic calcification of cervicocranial arteries." A_EndChar,3)
    return
    :*B0:scwm::
        sendByClipboard("subcortical white matter",3)
    return
    :B0:mx::
        sendByClipboard("maxillary" A_EndChar,2)
    return
    :*:max0::
        {
            sendByClipboard("Mucus retention in maxillary sinus.")
            send % "{left 16}"
        }
    return
    :*:max1::
        {
            sendByClipboard("Mucosal thickening in maxillary sinus.")
            send % "{left 16}"
        }
    return
    :*:max2::
        {
            sendByClipboard("Retention cyst in maxillary sinus.")
            send % "{left 16}"
        }
    return
    :B0:bg::
        sendByClipboard("basal ganglion" A_EndChar,2)
    return
    :*B0:bg1::
        sendByClipboard("basal ganglia",2)
    return
    :B0:intc::
        sendByClipboard("intracranial" A_EndChar,4)
    return
    :B0:vnt::
        sendByClipboard("ventricle" A_EndChar,3)
    return
    :*B0:vnt1::
        sendByClipboard("ventricles",3)
    return
    :*B0:vnt2::
        sendByClipboard("ventricular",3)
    return
    :B0:vnd::
        sendByClipboard("ventricular device" A_EndChar,3)
    return
    :B0:hemi::
        sendByClipboard("hemisphere" A_EndChar,4)
    return
    :*B0:hemi1::
        sendByClipboard("hemispheres",4)
    return
    :B0:cbh::
        sendByClipboard("cerebral hemisphere" A_EndChar,3)
    return
    :*B0:cbh1::
        sendByClipboard("cerebral hemispheres",3)
    return
    :*B0:cbh2::
        sendByClipboard("cerebellar hemisphere",3)
    return
    :*B0:cbh3::
        sendByClipboard("cerebellar hemispheres",3)
    return
    :B0:cab::
        sendByClipboard("carotid bulb" A_EndChar,3)
    return
    :*B0:cab1::
        sendByClipboard("carotid bulbs",3)
    return
    :B0:sfn::
        sendByClipboard("carotid siphon" A_EndChar,3)
    return
    :*B0:sfn1::
        sendByClipboard("carotid siphons",3)
    return
    :*B0:ccaa::
        sendByClipboard("common carotid artery",3)
    return
    :*B0:ccaa1::
        sendByClipboard("common carotid arteries",4)
    return
    :*B0:scaa::
        sendByClipboard("subclavian artery",3)
    return
    :*B0:scaa1::
        sendByClipboard("subclavian arteries",4)
    return
    :*B0:scvv::
        sendByClipboard("subclavian vein",3)
    return
    :*B0:scvv1::
        sendByClipboard("subclavian veins",4)
    return

    :*B0:icaa::
        sendByClipboard("internal carotid artery",3)
    return
    :*B0:icaa1::
        sendByClipboard("internal carotid arteries",4)
    return
    :*B0:scvv::
        sendByClipboard("subclavian vein",3)
    return
    :*B0:scvv1::
        sendByClipboard("subclavian veins",4)
    return
    :B0:paic::
        sendByClipboard("paraclinoid ICA" A_EndChar,4)
    return
    :*B0:ecaa::
        sendByClipboard("external carotid artery",3)
    return
    :*B0:ecaa1::
        sendByClipboard("external carotid arteries",4)
    return
    :*B0:acma::
        sendByClipboard("anterior communicating artery",3)
    return
    :*B0:acom::
        sendByClipboard("AComA",3)
    return
    :*B0:pcom::
        sendByClipboard("PComA",3)
    return
    :*B0:pcma::
        sendByClipboard("posterior communicating artery",3)
    return
    :*B0:pcma1::
        sendByClipboard("posterior communicating arteries",4)
    return
    :*B0:mcaa::
        sendByClipboard("middle cerebral artery",3)
    return
    :*B0:acaa::
        sendByClipboard("anterior cerebral artery",3)
    return
    :*B0:pcaa::
        sendByClipboard("posterior cerebral artery",3)
    return
    :*B0:picaa::
        sendByClipboard("posterior inferior cerebellar artery",4)
    return
    :*B0:aicaa::
        sendByClipboard("anterior inferior cerebellar artery",4)
    return
    :*B0:vaa::
        sendByClipboard("vertebral artery",2)
    return
    :*B0:vaa1::
        sendByClipboard("vertebral arteries",3)
    return
    :*B0:baa::
        sendByClipboard("basilar artery",2)
    return
    :*B0:vbaa::
        sendByClipboard("vertebrobasilar artery",3)
    return
    :*B0:lac-::
        sendByClipboard("微細梗塞",3)
    return
    :B0:lac::
        sendByClipboard("lacune" A_EndChar,3)
    return
    :*B0:lac1::
        sendByClipboard("lacunes",3)
    return
    :B0:ol::
        sendByClipboard("old lacune" A_EndChar,2)
    return
    :*B0:ol1::
        sendByClipboard("old lacunes",2)
    return
    :B0:aol::
        sendByClipboard("an old lacune" A_EndChar,3)
    return
    :*B0:ctp0::
        sendByClipboard("CT perfusion shows symmetric cerebral perfusion.",3)
    return
    :*B0:ctp1::
        sendByClipboard("CT perfusion shows decreased CBF and prolonged MTT",3)
    return
    :B0:ptnb::
        sendByClipboard("patent bilateral ICA, MCA, ACA, PCA, VA, and BA." A_EndChar,4)
    return
    :*B0:cow0::
        sendByClipboard("TOF MRA shows no definite vascular abnormality of the Willis circle of arteries.",3)
    return
    :B0:toma::
        sendByClipboard("TOF MRA shows" A_EndChar,4)
    return
    :B0:cema::
        sendByClipboard("Contrast-enhanced MRA shows" A_EndChar,4)
    return
    :B0:tcma::
        sendByClipboard("TOF MRA and contrast-enhanced MRA show" A_EndChar,4)
    return
    :B0:pds::
        sendByClipboard("patent dural sinuses." A_EndChar,3)
    return
    :B0:tsn::
        sendByClipboard("transverse sinus" A_EndChar,3)
    return
    :*B0:tsn1::
        sendByClipboard("transverse sinuses",3)
    return
    :B0:ssn::
        sendByClipboard("sigmoid sinus" A_EndChar,3)
    return
    :*B0:ssn1::
        sendByClipboard("sigmoid sinuses",3)
    return
    :*B0:tssn::
        sendByClipboard("transverse-sigmoid sinus",3)
    return

    :*B0:tra0::
        sendByClipboard("no evidence of traumatic brain injury nor cervical fracture.",3)
    return
    :*B0:tem0::
        sendByClipboard("
(
HRCT for temporal bones without contrast enhancement shows:
- Normal appearance of bilateral external ear canal and middle ear ossicles.
- Normal appearance of bilateral inner ear bony labyrinthes.
- Well pneumatization of bilateral mastoids.
)")
    return
    :*B0:forp::
        sendByClipboard("fetal origin of the right PCA",3)
    return
    :*B0:folp::
        sendByClipboard("fetal origin of the left PCA",3)
    return
    :B0:fobp::
        sendByClipboard("fetal origin of bilateral PCA" A_EndChar,4)
    return
    :B0:tsh::
        sendByClipboard("trans-sphenoid hypophysectomy" A_EndChar,3)
    return
    :*B0:tsh1::
        sendByClipboard("Post-operative change in the sella turcica with evidence of prior trans-sphenoid hypophysectomy.",3)
    return
    :*B0:tsh2::
        sendByClipboard("Post-operative changes of trans-sphenoid hypophysectomy with increased SI in the sphenoid sinus and bony defect at the sellar floor.",3)
    return
    :B0:ocd::
        sendByClipboard("downward herniation of the optic chiasm due to post-operative change." A_EndChar,3)
    return
    :*B0:ocd1::
        sendByClipboard("Mild downward herniation of the optic chiasm due to post-operative change.",3)
    return
    :*B0:mlsr::
        sendByClipboard("midline shift to right side",3)
    return
    :*B0:mlsl::
        sendByClipboard("midline shift to left side",3)
    return
    :B0:mls::
        sendByClipboard("midline shift" A_EndChar,3)
    return
    :*B0:lpic::
        sendByClipboard("left vertebral artery ending at PICA",3)
    return
    :*B0:rpic::
        sendByClipboard("right vertebral artery ending at PICA",3)
    return

    ;neck
    :B0:bnl::
        sendByClipboard("bilateral neck lymph nodes" A_EndChar,3)
    return

    :B0:bpx::
        sendByClipboard("brachial plexus" A_EndChar,3)
    return
    :*B0:bpx1::
        sendByClipboard("brachial plexi",3)
    return

    :B0:mlm::
        sendByClipboard("myelomalacia" A_EndChar,3)
    return

    :B0:ggb::
        sendByClipboard("gingivobuccal" A_EndChar,3)
    return
    :*B0:bcab::
        sendByClipboard("bilateral carotid bulbs",3)
    return
    :*B0:rcab::
        sendByClipboard("right carotid bulb",3)
    return
    :*B0:lcab::
        sendByClipboard("left carotid bulb",3)
    return

    :*B0:bsfn::
        sendByClipboard("bilateral carotid siphons",3)
    return
    :*B0:rsfn::
        sendByClipboard("right carotid siphon",3)
    return
    :*B0:lsfn::
        sendByClipboard("left carotid siphon",3)
    return

    :B0:kkb::
        sendByClipboard("concha bullosa" A_EndChar,3)
    return
    :*B0:rcrm::
        sendByClipboard("retention cyst in right maxillary sinus.",3)
    return
    :*B0:rcrm1::
        sendByClipboard("retention cysts in right maxillary sinus.",4)
    return
    :*B0:rclm::
        sendByClipboard("retention cyst in left maxillary sinus.",3)
    return
    :*B0:rclm1::
        sendByClipboard("retention cysts in left maxillary sinus.",4)
    return
    :*B0:rcbm::
        sendByClipboard("retention cysts in bilateral maxillary sinuses.",3)
    return

    :*B0:mtrm::
        sendByClipboard("mucosal thickening in right maxillary sinus.",3)
    return
    :*B0:mtlm::
        sendByClipboard("mucosal thickening in left maxillary sinus.",3)
    return
    :*B0:mtbm::
        sendByClipboard("mucosal thickening in bilateral maxillary sinuses.",3)
    return

    :*B0:mrrm::
        sendByClipboard("mucus retention in right maxillary sinus.",3)
    return
    :*B0:mrlm::
        sendByClipboard("mucus retention in left maxillary sinus.",3)
    return
    :*B0:mrbm::
        sendByClipboard("mucus retention in bilateral maxillary sinuses.",3)
    return

    :*B0:art1::
        sendByClipboard("Beam-hardening artifacts from dental prosthesis obscure the image details in oral cavity.",3)
    return
    :*B0:art2::
        sendByClipboard("Magnetic susceptibility artifacts from dental prosthesis obscure the image details in oral cavity.",3)
    return
    :B0:omt::
        sendByClipboard("osteomucosal thickening" A_EndChar,3)
    return
    :B0:zyg::
        sendByClipboard("zygomatic" A_EndChar,3)
    return
    :B0:trg::
        sendByClipboard("pterygoid" A_EndChar,3)
    return
    :B0:vcc::
        sendByClipboard("vocal cord" A_EndChar,3)
    return
    :B0:mdb::
        sendByClipboard("mandible" A_EndChar,3)
    return
    :*B0:mdb1::
        sendByClipboard("mandibular",3)
    return
    :B0:scb::
        sendByClipboard("scleral buckling" A_EndChar,3)
    return
    :B0:nnl::
        sendByClipboard("no definite neck lymphadenopathy." A_EndChar,3)
    return
    :B0:lrg::
        sendByClipboard("laryngectomy" A_EndChar,3)
    return
    :B0:tlg::
        sendByClipboard("total laryngectomy" A_EndChar,3)
    return
    :B0:msp::
        sendByClipboard("masticator space" A_EndChar,3)
    return
    :B0:crp::
        sendByClipboard("carotid space" A_EndChar,3)
    return
    :B0:crt::
        sendByClipboard("carotid" A_EndChar,3)
    return
    :B0:ppp::
        sendByClipboard("parapharyngeal space" A_EndChar,3)
    return
    :B0:rpp::
        sendByClipboard("retropharyngeal space" A_EndChar,3)
    return
    :B0:bcp::
        sendByClipboard("buccal space" A_EndChar,3)
    return
    :B0:buc::
        sendByClipboard("buccal" A_EndChar,3)
    return
    :B0:itf::
        sendByClipboard("infratemporal fossa" A_EndChar,3)
    return
    :B0:ptp::
        sendByClipboard("parotid space" A_EndChar,3)
    return
    :B0:skb::
        sendByClipboard("skull base" A_EndChar,3)
    return

    :B0:por::
        sendByClipboard("periorbital" A_EndChar,3)
    return
    :B0:orb::
        sendByClipboard("orbital" A_EndChar,3)
    return
    :B0:orw::
        sendByClipboard("orbital wall" A_EndChar,3)
    return

    :B0:snc::
        sendByClipboard("sinonasal cavity" A_EndChar,3)
    return
    :*B0:snc1::
        sendByClipboard("sinonasal cavities",3)
    return

    :B0:rms::
        sendByClipboard("right maxillary sinus" A_EndChar,3)
    return
    :B0:lms::
        sendByClipboard("left maxillary sinus" A_EndChar,3)
    return
    :B0:bms::
        sendByClipboard("bilateral maxillary sinuses" A_EndChar,3)
    return

    :B0:rps::
        sendByClipboard("right sphenoid sinus" A_EndChar,3)
    return
    :B0:lps::
        sendByClipboard("left sphenoid sinus" A_EndChar,3)
    return
    :B0:bps::
        sendByClipboard("bilateral sphenoid sinuses" A_EndChar,3)
    return

    :B0:rfs::
        sendByClipboard("right frontal sinus" A_EndChar,3)
    return
    :B0:lfs::
        sendByClipboard("left frontal sinus" A_EndChar,3)
    return
    :B0:bfs::
        sendByClipboard("bilateral frontal sinuses" A_EndChar,3)
    return

    :B0:res::
        sendByClipboard("right ethmoid sinus" A_EndChar,3)
    return
    :B0:les::
        sendByClipboard("left ethmoid sinus" A_EndChar,3)
    return
    :B0:bes::
        sendByClipboard("bilateral ethmoid sinuses" A_EndChar,3)
    return

    :B0:rmx::
        sendByClipboard("retromaxillary" A_EndChar,3)
    return
    :B0:adt::
        sendByClipboard("aerodigestive tract" A_EndChar,3)
    return
    :B0:rpx::
        sendByClipboard("retropharyngeal" A_EndChar,3)
    return
    :*B0:rpx1::
        sendByClipboard("retropharynx",3)
    return
    :*B0:dllp::
        sendByClipboard("dehiscence of left lamina papyracea.",3)
    return
    :*B0:drlp::
        sendByClipboard("dehiscence of right lamina papyracea.",3)
    return
    :*B0:thyd::
        sendByClipboard("thyroidectomy",3)
    return
    :*B0:lart::
        sendByClipboard("laryngectomy",3)
    return
    :*B0:trko::
        sendByClipboard("tracheostomy",3)
    return
    :B0:nlc::
        sendByClipboard("nuchal ligament calcification." A_EndChar,3)
    return
    :*B0:npcy-::
        sendByClipboard("鼻咽囊腫",4)
    return
    :B0:npcy::
        sendByClipboard("nasopharyngeal cyst" A_EndChar,4)
    return
    :*B0:aoas::
        sendByClipboard("atlanto-occipital assimilation",3)
    return
    :B0:pys::
        sendByClipboard("pyriform sinus" A_EndChar,3)
    return
    :*B0:pys1::
        sendByClipboard("pyriform sinuses",3)
    return
    :B0:exf::
        sendByClipboard("exophthalmos" A_EndChar,3)
    return
    :B0:gof::
        sendByClipboard("Graves' ophthalmopathy" A_EndChar,3)
    return
    :B0:oca::
        sendByClipboard("oral cavity" A_EndChar,3)
    return
    :B0:nca::
        sendByClipboard("nasal cavity" A_EndChar,3)
    return
    :*B0:nca1::
        sendByClipboard("nasal cavities",3)
    return
    :B0:gst::
        sendByClipboard("glossectomy" A_EndChar,3)
    return
    :B0:tym::
        sendByClipboard("tympanic membrane" A_EndChar,3)
    return
    :B0:tye::
        sendByClipboard("thyroidectomy" A_EndChar,3)
    return
    :B0:aef::
        sendByClipboard("aryepiglottic fold" A_EndChar,3)
    return
    :B0:nst::
        sendByClipboard("nasal septum" A_EndChar,3)
    return
    ;~ ::omc::ostiomeatal complex
    :B0:ppf::
        sendByClipboard("pterygopalatine fossa" A_EndChar,3)
    return
    :*B0:rcy-::
        sendByClipboard("鼻竇滯留囊腫",3)
    return
    :B0:rcy::
        sendByClipboard("retention cyst" A_EndChar,3)
    return
    :*B0:rcy1::
        sendByClipboard("retention cysts",3)
    return
    :B0:faf::
        sendByClipboard("fissula ante fenestram" A_EndChar,3)
    return
    :B0:mps::
        sendByClipboard("mucosal thickening in paranasal sinuses." A_EndChar,3)
    return
    :B0:rmr::
        sendByClipboard("retromolar" A_EndChar,3)
    return
    :B0:tg::
        sendByClipboard("tongue" A_EndChar,2)
    return
    :B0:ig::
        sendByClipboard("eyeglobe" A_EndChar,2)
    return
    :*B0:ig1::
        sendByClipboard("eyeglobes",2)
    return
    :B0:nk::
        sendByClipboard("neck" A_EndChar,2)
    return
    :B0:msad::
        sendByClipboard("Magnetic suceptibility artifacts from dental prosthesis obscure the image details in oral cavity." A_EndChar,4)
    return
    :*B0:eye0::
        sendByClipboard("phthisis bulbi",3)
    return
    :*B0:eye1::
        sendByClipboard("status post phacoemulsification",3)
    return
    :B0:oph::
        sendByClipboard("ophthalmic" A_EndChar,3)
    return
    :B0:djdc::
        sendByClipboard("degenerative change of cervical spine" A_EndChar,4)
    return
    :*B0:cs0::
        sendByClipboard("normal alignment of cervical spine.",2)
    return
    :*B0:ts0::
        sendByClipboard("normal alignment of thoracic spine.",2)
    return
    :*B0:ls0::
        sendByClipboard("normal alignment of lumbar spine.",2)
    return
    :*B0:tls0::
        sendByClipboard("normal alignment of thoracolumbar spine.",3)
    return
    :B0:mpo::
        sendByClipboard("mucoperiosteal" A_EndChar,3)
    return
    :B0:pnm::
        sendByClipboard("pneumatization" A_EndChar,3)
    return
    :*B0:pns-::
        sendByClipboard("鼻竇",3)
    return
    :B0:pns::
        sendByClipboard("paranasal sinuses" A_EndChar,3)
    return
    :*B0:pns1::
        sendByClipboard("paranasal sinusitis",3)
    return
    :B0:sns::
        sendByClipboard("sinusitis" A_EndChar,3)
    return
    :B0:npx::
        sendByClipboard("nasopharynx" A_EndChar,3)
    return
    :B0:np::
        sendByClipboard("nasopharyngeal" A_EndChar,2)
    return
    :*B0:npx1::
        sendByClipboard("nasopharyngeal",3)
    return
    :B0:opx::
        sendByClipboard("oropharynx" A_EndChar,3)
    return
    :*B0:opx1::
        sendByClipboard("oropharyngeal",3)
    return
    :B0:lx::
        sendByClipboard("larynx" A_EndChar,2)
    return
    :*B0:lx1::
        sendByClipboard("laryngeal",2)
    return
    :B0:ppx::
        sendByClipboard("parapharyngeal" A_EndChar,3)
    return
    :B0:px::
        sendByClipboard("pharynx" A_EndChar,2)
    return
    :*B0:px1::
        sendByClipboard("pharyngeal",2)
    return
    :B0:hpx::
        sendByClipboard("hypopharynx" A_EndChar,3)
    return
    :*B0:hpx1::
        sendByClipboard("hypopharyngeal",3)
    return
    :*B0:ijvv::
        sendByClipboard("internal jugular vein",3)
    return
    :*B0:ijvv1::
        sendByClipboard("internal jugular veins",4)
    return
    :B0:mxy::
        sendByClipboard("maxillary" A_EndChar,3)
    return
    :B0:mxs::
        sendByClipboard("maxillary sinus" A_EndChar,3)
    return
    :*B0:mxs1::
        sendByClipboard("maxillary sinuses",3)
    return
    :*B0:mxs2::
        sendByClipboard("maxillary sinusitis",3)
    return
    :B0:ets::
        sendByClipboard("ethmoid sinus" A_EndChar,3)
    return
    :*B0:ets1::
        sendByClipboard("ethmoid sinuses",3)
    return
    :*B0:ets2::
        sendByClipboard("ethmoid sinusitis",3)
    return
    :B0:eth::
        sendByClipboard("ethmoid" A_EndChar,3)
    return
    :B0:sph::
        sendByClipboard("sphenoid" A_EndChar,3)
    return
    :B0:sps::
        sendByClipboard("sphenoid sinus" A_EndChar,3)
    return
    :*B0:sps1::
        sendByClipboard("sphenoid sinuses",3)
    return
    :*B0:sps2::
        sendByClipboard("sphenoid sinusitis",3)
    return
    :B0:frs::
        sendByClipboard("frontal sinus" A_EndChar,3)
    return
    :*B0:frs1::
        sendByClipboard("frontal sinuses",3)
    return
    :*B0:frs2::
        sendByClipboard("frontal sinusitis",3)
    return
    :*B0:thy-::
        sendByClipboard("甲狀腺",3)
    return
    :B0:thy::
        sendByClipboard("thyroid" A_EndChar,3)
    return
    :B0:thg::
        sendByClipboard("thyroid gland" A_EndChar,3)
    return
    :*B0:thg1::
        sendByClipboard("thyroid glands",3)
    return
    :B0:etg::
        sendByClipboard("enlarged thyroid gland" A_EndChar,3)
    return
    :*B0:etgn::
        sendByClipboard("enlarged thyroid gland with nodule(s).",3)
    return
    :*B0:thyc::
        sendByClipboard("thyroid calcification(s)",3)
    return
    :B0:pvst::
        sendByClipboard("prevertebral soft tissue" A_EndChar,4)
    return
    :*B0:rtc0::
        sendAndNextLine("post-radiation edematous change of the retropharyngeal space and bilateral neck interstitium as well as fatty change in the C spine. ")
    return
    :*B0:rtc1::
        sendAndNextLine("post-radiation edematous change of bilateral neck interstitium as well as fatty change in the C spine. ")
    return
    :*B0:rtc2::
        sendAndNextLine("post-radiation fatty change in the C spine. ")
    return
    :*B0:rtc3::
        sendAndNextLine("post-radiation edematous change of bilateral neck interstitium. ")
    return
    :B0:cerv::
        sendByClipboard("cervical" A_EndChar,4)
    return
    :*B0:pns0::
        sendAndNextLine("Clear paranasal sinuses. ")
    return
    :*B0:ph0::
        sendAndNextLine("Clear nasopharynx and parapharyngeal space. ")
    return
    :B0:sbm::
        sendByClipboard("submandibular" A_EndChar,3)
    return
    :B0:sbg::
        sendByClipboard("submandibular gland" A_EndChar,3)
    return
    :*B0:sbg1::
        sendByClipboard("submandibular glands",3)
    return
    :B0:sln::
        sendByClipboard("sublingual" A_EndChar,3)
    return
    :B0:slg::
        sendByClipboard("sublingual gland" A_EndChar,3)
    return
    :*B0:slg1::
        sendByClipboard("sublingual glands",3)
    return
    :B0:ptd::
        sendByClipboard("parotid" A_EndChar,3)
    return
    :B0:pdg::
        sendByClipboard("parotid gland" A_EndChar,3)
    return
    :*B0:pdg1::
        sendByClipboard("parotid glands",3)
    return
    :B0:scv::
        sendByClipboard("supraclavicular" A_EndChar,3)
    return
    :B0:icv::
        sendByClipboard("infraclavicular" A_EndChar,3)
    return
    :B0:nln::
        sendByClipboard("no definite enlarged (>1cm) neck lymph node.`n-" A_EndChar,3)
    return
    :*B0:nln0::
        sendAndNextLine("small lymph nodes (<1cm) in bilateral neck. ")
    return
    :*:nlap1::
        {
            sendByClipboard("Enlarged lymph nodes in bilateral neck, the largest one () at " "")
            send % "{left 5}"
        }
    return
    :*B0:br0::
        sendByClipboard("no SI change nor abnormal enhancing lesion of visible brain parenchyma.",2)
    return
    :*B0:tn-::
        sendByClipboard("甲狀腺結節",2)
    return
    :*B0:tn/::
        sendByClipboard("thyroid nodule(s).",2)
    return
    :*B0:tn1::
        sendByClipboard("thyroid nodules",2)
    return
    :B0:btn::
        sendByClipboard("bilateral thyroid nodules." A_EndChar,3)
    return
    :B0:tn::
        sendByClipboard("thyroid nodule" A_EndChar,2)
    return
    :*B0:thn1::
        sendByClipboard("thyroid nodules",3)
    return
    :*B0:n1/::
        sendByClipboard("
(
- Post-RT fatty change of the C spine bone marrow and flattened mucosa at nasopharynx.
- No obvious local recurrent tumor.
- No obvious abnormality at skull base and visible brain.
- No evidence of abnormally enlarged (>1cm) lymph nodes.
- Clear paranasal sinuses and mastoids.
)")
    return
    :*B0:n0/::
        sendByClipboard("
(
- Clear nasopharynx and parapharyngeal space.
- No obvious abnormality at skull base and visible brain.
- No evidence of abnormally enlarged (>1cm) lymph nodes.
- Clear paranasal sinuses and mastoids.
)")
    return

    ;ortho
    :B0:mtp::
        sendByClipboard("medial tibial plateau" A_EndChar,3)
    return
    :B0:ltp::
        sendByClipboard("lateral tibial plateau" A_EndChar,3)
    return

    :*B0:mpar::
        sendByClipboard("medial patellar retinaculum",3)
    return
    :*B0:lpar::
        sendByClipboard("lateral patellar retinaculum",3)
    return

    :*B0:chll::
        sendByClipboard("coracohumeral ligament",3)
    return
    :*B0:roii::
        sendByClipboard("rotator interval",3)
    return
    :*B0:rcii::
        sendByClipboard("rotator cuff interval",3)
    return
    :*B0:ritt::
        sendByClipboard("rotator interval tear",3)
    return
    :B0:bts::
        sendByClipboard("biceps tendon sheath" A_EndChar,3)
    return
    :B0:pli::
        sendByClipboard("periligamentous" A_EndChar,3)
    return
    :B0:mso::
        sendByClipboard("mixed sclerotic/osteolytic" A_EndChar,3)
    return

    :*B0:frz0::
        sendByClipboard("thickening of the axillary recess joint capsule",3)
    return
    :B0:frz::
        sendByClipboard("adhesive capsulitis" A_EndChar,3)
    return

    :B0:ije::
        sendByClipboard("increased joint effusion" A_EndChar,3)
    return
    :B0:ahi::
        sendByClipboard("acromio-humeral interval" A_EndChar,3)
    return
    :*B0:tnlg::
        sendByClipboard("intact tendons and ligaments.",3)
    return
    :*B0:lgtn::
        sendByClipboard("intact ligaments and tendons.",3)
    return
    :*B0:tn0::
        sendByClipboard("intact tendons.",2)
    return
    :*B0:lg0::
        sendByClipboard("intact ligaments.",2)
    return
    :*B0:mn0::
        sendByClipboard("intact meniscus.",2)
    return

    :B0:lum::
        sendByClipboard("lumbar" A_EndChar,3)
    return
    :*B0:prnc::
        sendByClipboard("perineural cyst(s)",3)
    return
    :B0:tlv::
        sendByClipboard("Tarlov cyst" A_EndChar,3)
    return
    :*B0:tlv1::
        sendByClipboard("Tarlov cysts",3)
    return
    :*B0:stlv::
        sendByClipboard("sacral Tarlov cyst(s).",3)
    return

    :*B0:fd0::
        sendByClipboard("no obvious displaced fracture. (Small bone fracture may not be detected by images.)",2)
    return
    :*B0:acet::
        sendByClipboard("acetabulum",3)
    return
    :B0:scp::
        sendByClipboard("scapula" A_EndChar,3)
    return
    :B0:mrl::
        sendByClipboard("marrow-replacing lesion" A_EndChar,3)
    return
    :*B0:mrl1::
        sendByClipboard("marrow-replacing lesions",3)
    return
    :B0:nvr::
        sendByClipboard("nerve root" A_EndChar,3)
    return
    :*B0:nvr1::
        sendByClipboard("nerve roots",3)
    return
    :B0:ceq::
        sendByClipboard("cauda equina" A_EndChar,3)
    return
    :*B0:spst::
        sendByClipboard("spinal stenosis",3)
    return
    :*B0:ss0::
        sendByClipboard("no significant spinal stenosis.",2)
    return
    :B0:bom::
        sendByClipboard("bone metastases" A_EndChar,3)
    return
    :*B0:bomc::
        sendByClipboard("bone metastases with compression fracture.",3)
    return
    :*B0:bomf::
        sendByClipboard("bone metastases with fracture.",3)
    return
    :*B0:sbom::
        sendByClipboard("sclerotic bone metastases.",3)
    return
    :*B0:obom::
        sendByClipboard("osteolytic bone metastases.",3)
    return
    :B0:hum::
        sendByClipboard("humerus" A_EndChar,3)
    return
    :*B0:hum1::
        sendByClipboard("humeral",3)
    return
    :B0:fem::
        sendByClipboard("femur" A_EndChar,3)
    return
    :*B0:fem1::
        sendByClipboard("femoral",3)
    return
    :B0:tbi::
        sendByClipboard("tibia" A_EndChar,3)
    return
    :*B0:tbi1::
        sendByClipboard("tibial",3)
    return
    :B0:fbu::
        sendByClipboard("fibula" A_EndChar,3)
    return
    :*B0:fbu1::
        sendByClipboard("fibulal",3)
    return
    :B0:rad::
        sendByClipboard("radius" A_EndChar,3)
    return
    :*B0:rad1::
        sendByClipboard("radial",3)
    return
    :B0:un::
        sendByClipboard("ulna" A_EndChar,2)
    return
    :*B0:un1::
        sendByClipboard("ulnar",2)
    return
    :B0:sld::
        sendByClipboard("shoulder" A_EndChar,3)
    return
    :B0:bme::
        sendByClipboard("bone marrow edema" A_EndChar,3)
    return
    :B0:pop::
        sendByClipboard("popliteal artery" A_EndChar,3)
    return
    :*B0:pop1::
        sendByClipboard("popliteal arteries",3)
    return
    :B0:clv::
        sendByClipboard("clavicle" A_EndChar,3)
    return
    :*B0:clv1::
        sendByClipboard("clavicles",3)
    return
    :*B0:clv2::
        sendByClipboard("clavicular",3)
    return
    :B0:opk::
        sendByClipboard("osteopoikilosis" A_EndChar,3)
    return
    :B0:acll::
        sendByClipboard("anterior cruciate ligament" A_EndChar,4)
    return
    :*B0:crl0::
        sendByClipboard("intact cruciate ligaments.",3)
    return
    :*B0:crl1::
        sendByClipboard("cruciate ligaments",3)
    return
    :B0:acl1::
        sendByClipboard("grade 1 ACL injury (intraligamentous injury)" A_EndChar,4)
    return
    :B0:acl2::
        sendByClipboard("grade 2 ACL tear (suggesting partial tear)" A_EndChar,4)
    return
    :B0:abn1::
        sendByClipboard("type I accessory navicular bone" A_EndChar,4)
    return
    :B0:abn2::
        sendByClipboard("type II accessory navicular bone" A_EndChar,4)
    return
    :B0:aclam::
        sendByClipboard("anteromedial bundle" A_EndChar,5)
    return
    ;~ ::LPL::posterolateral bundle
    :B0:acr::
        sendByClipboard("acromion" A_EndChar,3)
    return
    :B0:ahlm::
        sendByClipboard("anterior horn of lateral meniscus" A_EndChar,4)
    return
    :B0:ahmm::
        sendByClipboard("anterior horn of medial meniscus" A_EndChar,4)
    return
    :B0:aco::
        sendByClipboard("accessory ossicle" A_EndChar,3)
    return
    :*B0:aco1::
        sendByClipboard("accessory ossicles",3)
    return
    :B0:ars::
        sendByClipboard("articular-side" A_EndChar,3)
    return
    :B0:ass::
        sendByClipboard("multilevel syndesmophytoses, ligamentous ossifications, bamboo-appearance of spine, and ankylosis of bilateral sacroiliac joints, compatible with ankylosing spondylitis" A_EndChar,3)
    return

    :B0:avn::
        sendByClipboard("avascular necrosis" A_EndChar,3)
    return
    :B0:avn2::
        sendByClipboard("subchondral geographic lesion with serpigeous sclerotic margin" A_EndChar,4)
    return
    :B0:avn3::
        sendByClipboard("subchondral geographic lesion with serpigeous sclerotic margin and subchondral collapse" A_EndChar,4)
    return
    :B0:avnmrr::
        sendByClipboard("geographic subchondral lesion, of intermediate to low SI on T1WI, mixed SI on T2WI, and marginal enhancement on post-contrast T1WI, with serpiginous sclerotic margin at the right femoral head; mild ill-defined area of hyperemic or edematous bone marrow at the adjacent region of right femoral neck to right trochanteric area; partial collapse with subchondral fracture at the right femoral head; abnormal increased effusion and synovial enhancement in the right hip joint space." A_EndChar,6)
    return
    :B0:avnmrl::
        sendByClipboard("geographic subchondral lesion, of intermediate to low SI on T1WI, mixed SI on T2WI, and marginal enhancement on post-contrast T1WI, with serpiginous sclerotic margin at the left femoral head; mild ill-defined area of hyperemic or edematous bone marrow at the adjacent region of left femoral neck to left trochanteric area; partial collapse with subchondral fracture at the left femoral head; abnormal increased effusion and synovial enhancement in the left hip joint space." A_EndChar,6)
    return
    :B0:b1::
        sendByClipboard("epiphysis" A_EndChar,2)
    return
    :B0:b12::
        sendByClipboard("epimetaphysis" A_EndChar,3)
    return
    :B0:b2::
        sendByClipboard("metaphysis" A_EndChar,2)
    return
    :B0:b23::
        sendByClipboard("diametaphysis" A_EndChar,3)
    return
    :B0:b3::
        sendByClipboard("diaphysis" A_EndChar,2)
    return
    :B0:bakers::
        sendByClipboard("loculated cystic lesion, with communicating tract to the synovial cavity and between the medial head of gastrocnemius muscle and semimenbranosus tendon, at posterior medial aspect of knee joint." A_EndChar,6)
    return
    :B0:bfg::
        sendByClipboard("femoral greater trochanteric region" A_EndChar,3)
    return
    :B0:bfi::
        sendByClipboard("femoral intertrochanteric region" A_EndChar,3)
    return
    :B0:bfis::
        sendByClipboard("femoral inter- to subtrochanteric region" A_EndChar,4)
    return
    ;~ ::BFL::femoral lesser trochanteric region
    ;~ ::BFS::femoral subtrochanteric region
    :B0:bgd::
        sendByClipboard("bulging disc" A_EndChar,3)
    return
    :*B0:bgd1::
        sendByClipboard("bulging discs",3)
    return
    :B0:bgc::
        sendByClipboard("concentric bulging disc" A_EndChar,3)
    return
    :*B0:bgc1::
        sendByClipboard("concentric bulging discs",3)
    return
    :B0:bge::
        sendByClipboard("eccentric bulging disc" A_EndChar,3)
    return
    :*B0:bge1::
        sendByClipboard("eccentric bulging discs",3)
    return
    :B0:bgg::
        sendByClipboard("bulging disc(s) with adjacent thecal sac indentation" A_EndChar,3)
    return
    :B0:bgm::
        sendByClipboard("mild bulging disc(s) with mild adjcent thecal sac indentation" A_EndChar,3)
    return
    :B0:bpd::
        sendByClipboard("bulging-protruding disc" A_EndChar,3)
    return
    :*B0:bpd1::
        sendByClipboard("bulging-protruding discs",3)
    return
    :B0:bhg::
        sendByClipboard("humeral greater tubercle" A_EndChar,3)
    return
    :B0:bhn::
        sendByClipboard("humeral surgical neck" A_EndChar,3)
    return
    :B0:bip::
        sendByClipboard("biphalangism at the little toe" A_EndChar,3)
    return
    :B0:bip2::
        sendByClipboard("biphalangism at the little and 4th toes" A_EndChar,4)
    return
    :B0:bis::
        sendByClipboard("bone island(s) (enostosis)" A_EndChar,3)
    return
    :*B0:blc1::
        sendByClipboard("biceps-labral complex",3)
    return
    :B0:btt::
        sendByClipboard("tibial tuberosity" A_EndChar,3)
    return
    :B0:bus::
        sendByClipboard("bursal-side" A_EndChar,3)
    return
    :B0:cop::
        sendByClipboard("cord compression" A_EndChar,3)
    return
    :B0:cid::
        sendByClipboard("cortical indistinctness" A_EndChar,3)
    return
    :B0:cdhl::
        sendByClipboard("shallowing of acetabulum with superior lateral subluxation of the deformed femoral head and joint space narrowing and subchondral sclerosis, suggestive of congenital dysplasia of left hip joint." A_EndChar,4)
    return
    :B0:cdhr::
        sendByClipboard("shallowing of acetabulum with superior lateral subluxation of the deformed femoral head and joint space narrowing and subchondral sclerosis, suggestive of congenital dysplasia of right hip joint." A_EndChar,4)
    return
    :B0:cfaa::
        sendByClipboard("common femoral artery" A_EndChar,4)
    return
    :B0:cfaa1::
        sendByClipboard("common femoral arteries" A_EndChar,5)
    return
    :B0:cff::
        sendByClipboard("wedge deformity and decreased height, suggestive of compression fracture, at" A_EndChar,3)
    return
    :B0:cfh::
        sendByClipboard("compression fracture with decreased vertebral height at" A_EndChar,3)
    return
    ;~ ::CFHH::decreased vertebral height(s), sugg. of compression fracture, at
    :B0:cfp::
        sendByClipboard("pathological compression fracture" A_EndChar,3)
    return
    :B0:cfw::
        sendByClipboard("compression fracture with wedge deformity at" A_EndChar,3)
    return
    ;~ ::CFWW::wedge deformity, sugg. of compression fracture, at
    :B0:cj::
        sendByClipboard("in conjunction with" A_EndChar,2)
    return
    :B0:cjj::
        sendByClipboard("in conjunction with bilateral facet joint arthroses and hypertrophic ligamenta flava, causing" A_EndChar,3)
    return
    :B0:cj1::
        sendByClipboard("with hypertrophic ligamenta flava, causing" A_EndChar,3)
    return
    :B0:cj2::
        sendByClipboard("with bilateral facet joint arthroses and hypertrophic ligamenta flava, causing" A_EndChar,3)
    return
    :B0:cmp0::
        sendByClipboard("chondromalacia patella" A_EndChar,4)
    return
    ;~ ::CMP1::swelling and softening with increased SI on fat-suppressed PD images at grade I chondromalacia patella (Shahriaree grading system)
    :B0:cmp2::
        sendByClipboard("small cartilage fissure (involving less than 50% thickness) at grade II chondromalacia patella (Shahriaree grading system)" A_EndChar,4)
    return
    :B0:cmp3::
        sendByClipboard("irregular cartilage thinning and fissuring (involving more than 50% thickness) at grade III chondromalacia patella (Shahriaree grading system)" A_EndChar,4)
    return
    :B0:cmp4::
        sendByClipboard("full-thickness cartilage defect with exposure of overlying bone at grade IV chondromalacia patella (Shahriaree grading system)" A_EndChar,4)
    return
    :B0:cppd::
        sendByClipboard("CPPD (Calcium Pyrophosphate Dihydrate Deposition Disease)" A_EndChar,4)
    return
    :B0:da::
        sendByClipboard("degenerative arthroses" A_EndChar,2)
    return
    :B0:dac::
        sendByClipboard("degenerative arthrosis of the anterior atlantoaxial joint" A_EndChar,3)
    return
    :B0:daw::
        sendByClipboard("degenerative arthroses of the distal radioulnar, ulnocarpal and radiocarpal joints" A_EndChar,3)
    return
    :B0:dbf::
        sendByClipboard("displaced bone fragment" A_EndChar,3)
    return
    :*B0:dbf1::
        sendByClipboard("displaced bone fragments",3)
    return
    :B0:dbp::
        sendByClipboard("distal bone part" A_EndChar,3)
    return
    :*B0:dbp1::
        sendByClipboard("distal bone parts",3)
    return
    :B0:dc::
        sendByClipboard("degenerative change" A_EndChar,2)
    return
    :*B0:dc1::
        sendByClipboard("degenerative changes",2)
    return
    :B0:ddd::
        sendByClipboard("degenerative disc disease" A_EndChar,3)
    return
    :B0:ddh::
        sendByClipboard("developmental dysplasia of hip" A_EndChar,3)
    return
    :B0:ddh1::
        sendByClipboard("shallowing of the acetabulum" A_EndChar,4)
    return
    :B0:ddh2::
        sendByClipboard("mild lateral positioning of femoral head" A_EndChar,4)
    return
    :B0:ddhb::
        sendByClipboard("shallowing of the acetabulum with relative lateral subluxated femoral head on both sides, suggesting developmental dysplasia of both hips" A_EndChar,4)
    return
    :B0:ddhl::
        sendByClipboard("shallowing of the acetabulum with relative lateral subluxated femoral head on left side, suggesting developmental dysplasia of hip" A_EndChar,4)
    return
    :B0:ddhr::
        sendByClipboard("shallowing of the acetabulum with relative lateral subluxated femoral head on right side, suggesting developmental dysplasia of hip" A_EndChar,4)
    return
    :B0:deh::
        sendByClipboard("dehydrated disc" A_EndChar,3)
    return
    :*B0:dend::
        sendByClipboard("dehydrated narrowed disc",3)
    return
    :B0:dhb::
        sendByClipboard("degenerative arthroses of both hip joints" A_EndChar,3)
    return
    :B0:dhl::
        sendByClipboard("degenerative arthroses of left hip joint" A_EndChar,3)
    return
    :B0:dhr::
        sendByClipboard("degenerative arthroses of right hip joint" A_EndChar,3)
    return
    :B0:dish::
        sendByClipboard("flowing ossification of anterior longitudinal ligament at lower thoracic to upper lumbar spine, diffuse idiopathic skeletal hyperostosis (DISH) is suspected" A_EndChar,4)
    return
    :B0:disi::
        sendByClipboard("dorsal intercalated-segmental instability" A_EndChar,4)
    return
    :B0:dll::
        sendByClipboard("decreased lordosis of the lumbar spine" A_EndChar,3)
    return
    :B0:dpaa::
        sendByClipboard("dorsalis pedis artery" A_EndChar,4)
    return
    :B0:ds::
        sendByClipboard("degenerative change of spine" A_EndChar,2)
    return
    :B0:dsd::
        sendByClipboard("degenerative spinal and disc disease" A_EndChar,3)
    return
    :B0:dsi::
        sendByClipboard("degenerative arthroses of bilateral sacroiliac joints" A_EndChar,3)
    return
    :B0:dsih::
        sendByClipboard("degenerative arthroses of bilateral sacroiliac and hip joints" A_EndChar,4)
    return
    :B0:dsihl::
        sendByClipboard("degenerative arthroses of left sacroiliac and hip joints" A_EndChar,5)
    return
    :B0:dsihr::
        sendByClipboard("degenerative arthroses of right sacroiliac and hip joints" A_EndChar,5)
    return
    :B0:dsil::
        sendByClipboard("degenerative arthroses of left sacroiliac joint" A_EndChar,4)
    return
    :B0:dsir::
        sendByClipboard("degenerative arthroses of right sacroiliac joint" A_EndChar,4)
    return
    :B0:dssi::
        sendByClipboard("lumbar spondylosis and degenerative arthroses of bilateral sacroiliac joints" A_EndChar,4)
    return
    :B0:dssih::
        sendByClipboard("lumbar spondylosis and degenerative arthroses of bilateral sacroiliac and hip joints" A_EndChar,5)
    return
    ;~ ::DSS::degenerative change of spine and both shoulders
    :B0:ec::
        sendByClipboard("endplate change" A_EndChar,2)
    return
    :B0:ecd::
        sendByClipboard("degenerative endplate change" A_EndChar,3)
    return
    :B0:ecm::
        sendByClipboard("Modic type" A_EndChar,3)
    return
    :B0:eh::
        sendByClipboard("edema/hyperemia" A_EndChar,2)
    return
    :B0:efs::
        sendByClipboard("increased suprapatellar effusion" A_EndChar,3)
    return
    :B0:efsb::
        sendByClipboard("effusion in the bilateral suprapatellar pouches" A_EndChar,4)
    return
    :B0:efsbb::
        sendByClipboard("effusion in the bilateral suprapatellar pouches and knee joint spaces" A_EndChar,5)
    return
    :B0:efsl::
        sendByClipboard("effusion in the left suprapatellar pouch" A_EndChar,4)
    return
    :B0:efsll::
        sendByClipboard("effusion in the left suprapatellar pouch and knee joint space" A_EndChar,5)
    return
    :B0:efsr::
        sendByClipboard("effusion in the right suprapatellar pouch" A_EndChar,4)
    return
    :B0:efsrr::
        sendByClipboard("effusion in the right suprapatellar pouch and knee joint space" A_EndChar,5)
    return
    ;~ ::ENT::enthesopathic change
    :B0:exo::
        sendByClipboard("exostosis" A_EndChar,3)
    return
    :B0:exec::
        sendByClipboard("except for degenerative endplate change" A_EndChar,4)
    return
    :B0:exd::
        sendByClipboard("extruding disc" A_EndChar,3)
    return
    :B0:f2::
        sendByClipboard("index (2nd) finger" A_EndChar,2)
    return
    :B0:f3::
        sendByClipboard("middle (third) finger" A_EndChar,2)
    return
    :B0:f4::
        sendByClipboard("ring (4th) finger" A_EndChar,2)
    return
    :B0:f5::
        sendByClipboard("little (5th) finger" A_EndChar,2)
    return
    :B0:fa::
        sendByClipboard("angulation of distal fragment" A_EndChar,2)
    return
    :B0:faa::
        sendByClipboard("anterior angulation of distal bone part" A_EndChar,3)
    return
    :B0:fad::
        sendByClipboard("dorsal angulation of distal bone part" A_EndChar,3)
    return
    :B0:fai::
        sendByClipboard("femoro-acetabular impingement" A_EndChar,3)
    return
    :B0:fal::
        sendByClipboard("lateral (valgus) angulation of distal bone part" A_EndChar,3)
    return
    :B0:fam::
        sendByClipboard("medial (varus) angulation of distal bone part" A_EndChar,3)
    return
    :B0:fap::
        sendByClipboard("posterior angulation of distal bone part" A_EndChar,3)
    return
    :B0:fav::
        sendByClipboard("volar angulation of distal bone part" A_EndChar,3)
    return
    :B0:fc::
        sendByClipboard("comminuted fracture" A_EndChar,2)
    return
    :B0:fcas::
        sendByClipboard("femoral condylar articular surface" A_EndChar,4)
    return
    :B0:fcd::
        sendByClipboard("comminuted displaced fracture" A_EndChar,3)
    return
    :B0:fcdi::
        sendByClipboard("comminuted displaced impacted fracture" A_EndChar,4)
    return
    :B0:fcdia::
        sendByClipboard("comminuted displaced intra-articular fracture" A_EndChar,5)
    return
    :B0:fcdiia::
        sendByClipboard("comminuted displaced intra-articular fracture" A_EndChar,6)
    return
    :B0:fci::
        sendByClipboard("comminuted impacted fracture" A_EndChar,3)
    return
    :B0:fcia::
        sendByClipboard("comminuted intraarticular fracture" A_EndChar,4)
    return
    :B0:fciia::
        sendByClipboard("comminuted impacted intra-articular fracture" A_EndChar,5)
    return
    :B0:fcll::
        sendByClipboard("fibular collateral ligament" A_EndChar,4)
    return
    :B0:fcp::
        sendByClipboard("complex fracture" A_EndChar,3)
    return
    :B0:fd::
        sendByClipboard("displaced fracture" A_EndChar,2)
    return
    :B0:fda::
        sendByClipboard("anterior displacement of distal bone part" A_EndChar,3)
    return
    :B0:fdd::
        sendByClipboard("dorsal displacement of distal bone part" A_EndChar,3)
    return
    :B0:fdi::
        sendByClipboard("displaced impacted fracture" A_EndChar,3)
    return
    :B0:fdia::
        sendByClipboard("displaced intra-articular fracture" A_EndChar,4)
    return
    :B0:fdis::
        sendByClipboard("distraction of bone parts" A_EndChar,4)
    return
    :B0:fdiia::
        sendByClipboard("displaced impacted intra-articular fracture" A_EndChar,5)
    return
    :B0:fdl::
        sendByClipboard("lateral displacement of distal bone part" A_EndChar,3)
    return
    :B0:fdm::
        sendByClipboard("medial displacement of distal bone part" A_EndChar,3)
    return
    :B0:fdp::
        sendByClipboard("posterior displacement of distal bone part" A_EndChar,3)
    return
    :B0:fdv::
        sendByClipboard("volar displacement of distal bone part" A_EndChar,3)
    return
    :B0:fe::
        sendByClipboard("neural foraminal encroachment" A_EndChar,2)
    return
    :B0:fel::
        sendByClipboard("encroachment to the left neural foramen" A_EndChar,3)
    return
    :B0:fer::
        sendByClipboard("encroachment to the right neural foramen" A_EndChar,3)
    return
    :B0:fh::
        sendByClipboard("healed fracture" A_EndChar,2)
    return
    :B0:fhh::
        sendByClipboard("healing fracture" A_EndChar,3)
    return
    :B0:fho::
        sendByClipboard("healed oblique fracture" A_EndChar,3)
    return
    :B0:fhs::
        sendByClipboard("healed spiral fracture" A_EndChar,3)
    return
    :B0:fht::
        sendByClipboard("healed transverse fracture" A_EndChar,3)
    return
    ;~ ::FI::impacted fracture
    :B0:fia::
        sendByClipboard("intra-articular fracture" A_EndChar,3)
    return
    :B0:fiia::
        sendByClipboard("impacted intraarticular fracture" A_EndChar,4)
    return
    :B0:fja::
        sendByClipboard("facet joint arthroses" A_EndChar,3)
    return
    :B0:fjal::
        sendByClipboard("facet joint arthroses at lower levels" A_EndChar,4)
    return
    :B0:fn::
        sendByClipboard("neural foraminal narrowing" A_EndChar,2)
    return
    :B0:fo::
        sendByClipboard("previous oblique fracture" A_EndChar,2)
    return
    :B0:fover::
        sendByClipboard("overriding of fracture ends" A_EndChar,5)
    return
    :B0:fp::
        sendByClipboard("pathological fracture" A_EndChar,2)
    return
    :B0:fr::
        sendByClipboard("rotation of distal fragment" A_EndChar,2)
    return
    ;~ ::FS::previous spiral fracture
    :B0:fsi::
        sendByClipboard("fat-supressed images" A_EndChar,3)
    return
    :B0:ft::
        sendByClipboard("previous transverse fracture" A_EndChar,2)
    return
    :B0:hlf::
        sendByClipboard("hypertrophic ligamenta flava" A_EndChar,3)
    return
    :B0:hv::
        sendByClipboard("hallux valgus" A_EndChar,2)
    return
    :B0:ixt::
        sendByClipboard("intraarticular extention to" A_EndChar,3)
    return
    :B0:ibfu::
        sendByClipboard("interbody fusion" A_EndChar,4)
    return
    :B0:ifar::
        sendByClipboard("inflammatory arthritis" A_EndChar,4)
    return
    :B0:imp::
        sendByClipboard("shoulder impingement" A_EndChar,3)
    return
    :B0:impl::
        sendByClipboard("lateral downsloping and lowlying of left acromion with subacromial spur formation and narrowed subacromial space, suggestive of shoulder impingment." A_EndChar,4)
    return
    :B0:impr::
        sendByClipboard("lateral downsloping and lowlying of right acromion with subacromial spur formation and narrowed subacromial space, suggestive of shoulder impingment." A_EndChar,4)
    return
    :B0:tsi::
        sendByClipboard("adjacent thecal sac indentation" A_EndChar,3)
    return
    :B0:inj::
        sendByClipboard("multiple calcified injection granulomas over bilateral buttocks" A_EndChar,3)
    return
    :B0:isb::
        sendByClipboard("intrasubstance" A_EndChar,3)
    return
    :B0:istt::
        sendByClipboard("infraspinatus tendon" A_EndChar,4)
    return
    :B0:jac::
        sendByClipboard("acromioclavicular joint" A_EndChar,3)
    return
    :*B0:jac1::
        sendByClipboard("acromioclavicular joints",3)
    return
    :B0:jca::
        sendByClipboard("patellofemoral joint compartment" A_EndChar,3)
    return
    :*B0:jca1::
        sendByClipboard("patellofemoral joint compartments",3)
    return
    :B0:jcaa::
        sendByClipboard("all joint compartment" A_EndChar,4)
    return
    :*B0:jcaa1::
        sendByClipboard("all joint compartments",4)
    return
    :B0:jcal::
        sendByClipboard("patellofemoral and lateral joint comparment" A_EndChar,4)
    return
    :*B0:jcal1::
        sendByClipboard("patellofemoral and lateral joint comparments",4)
    return
    :B0:jcam::
        sendByClipboard("patellofemoral and medial joint compartment" A_EndChar,4)
    return
    :*B0:jcam1::
        sendByClipboard("patellofemoral and medial joint compartments",4)
    return
    :B0:jcb::
        sendByClipboard("all joint compartments of both knee joints" A_EndChar,3)
    return
    :B0:jcc::
        sendByClipboard("calcaneocuboid joint" A_EndChar,3)
    return
    :*B0:jcc1::
        sendByClipboard("calcaneocuboid joints",3)
    return
    :B0:jcl::
        sendByClipboard("lateral joint compartment" A_EndChar,3)
    return
    :*B0:jcl1::
        sendByClipboard("lateral joint compartments",3)
    return
    :B0:jcm::
        sendByClipboard("medial joint compartment" A_EndChar,3)
    return
    :*B0:jcm1::
        sendByClipboard("medial joint compartments",3)
    return
    :B0:jcmc::
        sendByClipboard("carpometacarpal joint" A_EndChar,4)
    return
    :*B0:jcmc1::
        sendByClipboard("carpometacarpal joints",4)
    return
    :B0:jcml::
        sendByClipboard("medial and lateral joint compartment" A_EndChar,4)
    return
    :*B0:jcml1::
        sendByClipboard("medial and lateral joint compartments",4)
    return
    :B0:jd::
        sendByClipboard("junction of middle and distal thirds of" A_EndChar,2)
    return
    :B0:jdip::
        sendByClipboard("distal interphalangeal joint" A_EndChar,4)
    return
    :*B0:jdip1::
        sendByClipboard("distal interphalangeal joints",4)
    return
    :B0:jft::
        sendByClipboard("femorotibial joint" A_EndChar,3)
    return
    :*B0:jft1::
        sendByClipboard("femorotibial joints",3)
    return
    :B0:jgh::
        sendByClipboard("glenohumeral joint" A_EndChar,3)
    return
    :*B0:jgh1::
        sendByClipboard("glenohumeral joints",3)
    return
    :B0:jhr::
        sendByClipboard("humeroradial joint" A_EndChar,3)
    return
    :*B0:jhr1::
        sendByClipboard("humeroradial joints",3)
    return
    :B0:jhu::
        sendByClipboard("humeroulnar joint" A_EndChar,3)
    return
    :*B0:jhu1::
        sendByClipboard("humeroulnar joints",3)
    return
    :B0:jip::
        sendByClipboard("interphalangeal joint" A_EndChar,3)
    return
    :*B0:jip1::
        sendByClipboard("interphalangeal joints",3)
    return
    :B0:jipf::
        sendByClipboard("interphalangeal joint(s) of thumb(s) and some distal interphalangeal joint(s) of finger(s)" A_EndChar,4)
    return
    :B0:jipff::
        sendByClipboard("interphalangeal joint(s) of thumb(s) and some distal interphalangeal and proximal interphalangeal joint(s) of finger(s)" A_EndChar,5)
    return
    :B0:jipt::
        sendByClipboard("interphalangeal joint(s) of big toe(s) and some distal interphalangeal joint(s) of toe(s)" A_EndChar,4)
    return
    :B0:jiptt::
        sendByClipboard("interphalangeal joint(s) of big toe(s) and some distal interphalangeal and proximal interphalangeal joint(s) of toe(s)" A_EndChar,5)
    return
    :B0:jk::
        sendByClipboard("knee joint" A_EndChar,2)
    return
    :*B0:jk1::
        sendByClipboard("knee joints",2)
    return
    :B0:jkb::
        sendByClipboard("both knee joint" A_EndChar,3)
    return
    :*B0:jkb1::
        sendByClipboard("both knee joints",3)
    return
    :B0:jkl::
        sendByClipboard("left knee joint" A_EndChar,3)
    return
    :B0:jkr::
        sendByClipboard("right knee joint" A_EndChar,3)
    return
    :B0:jmc::
        sendByClipboard("mid-carpal joint" A_EndChar,3)
    return
    :*B0:jmc1::
        sendByClipboard("mid-carpal joints",3)
    return
    :B0:jmp::
        sendByClipboard("metacarpophalangeal joint" A_EndChar,3)
    return
    :*B0:jmp1::
        sendByClipboard("metacarpophalangeal joints",3)
    return
    :B0:jmt::
        sendByClipboard("metatarsophalangeal joint" A_EndChar,3)
    return
    :*B0:jmt1::
        sendByClipboard("metatarsophalangeal joints",3)
    return
    :B0:jj::
        sendByClipboard("no obvious bony fracture; no evidence of joint subluxation or dislocation; suggest clinical correlation." A_EndChar,2)
    return
    :B0:jo::
        sendByClipboard("no obvious bony fracture or destructive lesion; no evidence of joint subluxation or dislocation; suggest clinical correlation." A_EndChar,2)
    return
    :B0:joo::
        sendByClipboard("no obvious bony fracture or destructive lesion; no evidence of joint subluxation or dislocation; however, small bone fracture or lesion may not be detected by the plain radiography." A_EndChar,3)
    return
    :B0:jp::
        sendByClipboard("junction of proximal and middle thirds of" A_EndChar,2)
    return
    :B0:jpf::
        sendByClipboard("patellofemoral joint" A_EndChar,3)
    return
    :*B0:jpf1::
        sendByClipboard("patellofemoral joints",3)
    return
    :B0:jpip::
        sendByClipboard("proximal interphalangeal joint" A_EndChar,4)
    return
    :*B0:jpip1::
        sendByClipboard("proximal interphalangeal joints",4)
    return
    :B0:jrc::
        sendByClipboard("radiocarpal joint" A_EndChar,3)
    return
    :*B0:jrc1::
        sendByClipboard("radiocarpal joints",3)
    return
    :B0:jru::
        sendByClipboard("radioulnar joint" A_EndChar,3)
    return
    :*B0:jru1::
        sendByClipboard("radioulnar joints",3)
    return
    :B0:druj::
        sendByClipboard("distal radioulnar joint" A_EndChar,4)
    return
    :*B0:druj1::
        sendByClipboard("distal radioulnar joints",4)
    return
    :B0:pruj::
        sendByClipboard("proximal radioulnar joint" A_EndChar,4)
    return
    :*B0:pruj1::
        sendByClipboard("proximal radioulnar joints",4)
    return

    :B0:ptl::
        sendByClipboard("patella" A_EndChar,3)
    return
    :B0:lpt::
        sendByClipboard("lateral patellar tilt" A_EndChar,3)
    return

    :B0:jsi::
        sendByClipboard("sacroiliac joint" A_EndChar,3)
    return
    :*B0:jsi1::
        sendByClipboard("sacroiliac joints",3)
    return
    :B0:jst::
        sendByClipboard("subtalar joint" A_EndChar,3)
    return
    :*B0:jst1::
        sendByClipboard("subtalar joints",3)
    return
    :B0:jt::
        sendByClipboard("joint" A_EndChar,2)
    return
    :*B0:jt1::
        sendByClipboard("joints",2)
    return
    :B0:jtts::
        sendByClipboard("trapzium-trapzoid-scaphoid joint" A_EndChar,4)
    return
    :*B0:jtts1::
        sendByClipboard("trapzium-trapzoid-scaphoid joints",4)
    return
    :B0:jtm::
        sendByClipboard("temporomandibular joint" A_EndChar,3)
    return
    :*B0:jtm1::
        sendByClipboard("temporomandibular joints",3)
    return
    :B0:jtmt::
        sendByClipboard("tarsometatarsal joint" A_EndChar,4)
    return
    :*B0:jtmt1::
        sendByClipboard("tarsometatarsal joints",4)
    return
    :B0:jtn::
        sendByClipboard("talonavicular joint" A_EndChar,3)
    return
    :*B0:jtn1::
        sendByClipboard("talonavicular joints",3)
    return
    :B0:jtt::
        sendByClipboard("tibiotalar joint" A_EndChar,3)
    return
    :*B0:jtt1::
        sendByClipboard("tibiotalar joints",3)
    return
    :B0:juc::
        sendByClipboard("ulnocarpal joint" A_EndChar,3)
    return
    :*B0:juc1::
        sendByClipboard("ulnocarpal joints",3)
    return
    :B0:ksc::
        sendByClipboard("kyphoscoliosis" A_EndChar,3)
    return
    :B0:ky::
        sendByClipboard("kyphosis" A_EndChar,2)
    return
    :B0:lank::
        sendByClipboard("anterior talofibular ligament, posterior talofibular ligament, and calcaneofibular ligament" A_EndChar,4)
    return
    :B0:latf::
        sendByClipboard("anterior talofibular ligament" A_EndChar,4)
    return
    :B0:lptf::
        sendByClipboard("posterior talofibular ligament" A_EndChar,4)
    return
    :*B0:aitfl::
        sendByClipboard("anterior inferior tibiofibular ligament",4)
    return
    :*B0:pitfl::
        sendByClipboard("posterior inferior tibiofibular ligament",4)
    return
    :B0:lbd::
        sendByClipboard("loose body" A_EndChar,3)
    return
    :B0:lbd1::
        sendByClipboard("loose bodies" A_EndChar,4)
    return
    :B0:lcf::
        sendByClipboard("calcaneofibular ligament" A_EndChar,3)
    return
    :B0:lcpd::
        sendByClipboard("Legg-Calve-Perthes disease" A_EndChar,4)
    return
    :B0:lex::
        sendByClipboard("lower extremities" A_EndChar,3)
    return
    :B0:lhbt::
        sendByClipboard("long head of biceps tendon" A_EndChar,4)
    return
    :B0:lrs::
        sendByClipboard("lateral recess stenosis" A_EndChar,3)
    return
    :B0:mam::
        sendByClipboard("medial malleolus" A_EndChar,3)
    return
    :B0:leom::
        sendByClipboard("medial malleolus" A_EndChar,4)
    return
    :B0:leol::
        sendByClipboard("lateral malleolus" A_EndChar,4)
    return
    ;~ ::MAL::distal fibula lateral malleolus
    :B0:mcll::
        sendByClipboard("medial collateral ligament" A_EndChar,4)
    return
    :B0:mcl1::
        sendByClipboard("grade 1 signal (suggesting sprain or minimal tear) of the MCL" A_EndChar,4)
    return
    :B0:mcl2::
        sendByClipboard("grade 2 signal (suggesting partial tear) of the MCL" A_EndChar,4)
    return
    :B0:mcl3::
        sendByClipboard("grade 3 signal (suggesting complete tear) of the MCL" A_EndChar,4)
    return
    :B0:md1::
        sendByClipboard("bulging disc at posterior central aspect of L4-5 and causes intentation of the adjacent thecal sac" A_EndChar,3)
    return
    :B0:md2::
        sendByClipboard("protruding disc at posterior central aspect of the L4-5 and causes indentation of the adjacent thecal sac" A_EndChar,3)
    return
    :B0:mdd::
        sendByClipboard("degenerative change with dehydrated discs at multi-levels" A_EndChar,3)
    return
    :B0:menm::
        sendByClipboard("medial meniscus" A_EndChar,4)
    return
    :B0:menl::
        sendByClipboard("lateral meniscus" A_EndChar,4)
    return
    :B0:menb::
        sendByClipboard("medial and lateral meniscii" A_EndChar,4)
    return
    :B0:men1::
        sendByClipboard("short intrasubstance linear (or nodular) high SI on coronal GRE T2WI without extention to the capsular periphery or the articular surface at grade 1 signal (suggesting early intrasubstance degeneration)" A_EndChar,4)
    return
    :B0:men2::
        sendByClipboard("horizontal linear high SI on coronal GRE T2WI with extention to the capsular periphery and without involvement of the articular surface at grade 2 signal (suggesting intrasubstance degeneration)" A_EndChar,4)
    return
    :B0:ment::
        sendByClipboard("meniscal tear" A_EndChar,4)
    return
    :*B0:ment1::
        sendByClipboard("meniscal tears",4)
    return
    :B0:mf::
        sendByClipboard("multifocal" A_EndChar,2)
    return
    :B0:mhe1::
        sendByClipboard("small well-defined lesion of homogeneous high SI on both T1WI and T2WI at L4, considered vertebral hemangioma first." A_EndChar,4)
    return
    :B0:vth::
        sendByClipboard("vertebral hemangioma" A_EndChar,3)
    return
    :*B0:vth1::
        sendByClipboard("vertebral hemangiomas",3)
    return
    :B0:mhe2::
        sendByClipboard("several varying-sized well-defined lesions of homogeneous high SI on both T1WI and T2WI at lumbar vertebrae, considered vertebral hemangiomas first." A_EndChar,4)
    return
    :B0:mi3::
        sendByClipboard("middle third" A_EndChar,3)
    return
    ;~ ::MLL::multilevel
    ;~ ::MLS::multiple levels
    :*B0:mnb0::
        sendAndNextLine("no evidence of abnormal SI at the visible bony structures.")
    return
    :*B0:mnb1::
        sendAndNextLine("no evidence of abnormal SI or enhancing lesion at the visible bony structures.")
    return
    :*B0:mnbm::
        sendAndNextLine("no evidence of abnormal SI or enhancing lesion at bony or muscular structures.")
    return
    :*B0:mnc0::
        sendAndNextLine("no evidence of abnormal SI at visible part of the spinal cord.")
    return
    :*B0:mnc00::
        sendAndNextLine("no evidence of abnormal SI at the spinal cord.")
    return
    :*B0:mnc1::
        sendAndNextLine("no evidence of abnormal SI or enhancing lesion at visible part of the spinal cord.")
    return
    :*B0:mnc11::
        sendAndNextLine("no evidence of abnormal SI or enhancing lesion at the spinal cord.")
    return
    :*B0:mnm0::
        sendAndNextLine("no evidence of abnormal SI at the muscular structures.")
    return
    :*B0:mnm1::
        sendAndNextLine("no evidence of abnormal SI or enhancing lesion at the muscular structures.")
    return
    :B0:mrmet::
        sendByClipboard("multifocal varying-sized patchy and nodular marrow lesions of abnormal SI and enhancement at" A_EndChar,5)
    return
    :B0:myelo::
        sendByClipboard("Myelography of the lumbar spine with injection of non-ionic contrast medium via L2-3 level was performed smoothly and it shows:" A_EndChar,5)
    return
    :B0:myeloct::
        sendByClipboard("Myelo-CT study of lumbar spine with intrathecal injection of non-ionic contrast shows:>" A_EndChar,7)
    return
    :B0:fba::
        sendByClipboard("fine bony alignment" A_EndChar,3)
    return
    :B0:ndh::
        sendByClipboard("fine disc hydration" A_EndChar,3)
    return
    :B0:nf::
        sendByClipboard("no obvious bony fracture" A_EndChar,2)
    return
    :B0:nds::
        sendByClipboard("the disc spaces are acceptable" A_EndChar,3)
    return
    :B0:njs::
        sendByClipboard("the joint spaces are within normal limit" A_EndChar,3)
    return
    :B0:nl::
        sendByClipboard("no evidence of joint subluxation or dislocation" A_EndChar,2)
    return
    :B0:nrc::
        sendByClipboard("nerve root compression" A_EndChar,3)
    return
    :B0:nsi::
        sendByClipboard("normal morphology of the bilateral sacroiliac joints" A_EndChar,3)
    return
    :B0:nuv::
        sendByClipboard("negative ulnar variance" A_EndChar,3)
    return
    :B0:oa::
        sendByClipboard("osteoarthritis" A_EndChar,2)
    return
    :B0:oaa::
        sendByClipboard("osteoarthritic change" A_EndChar,3)
    return
    :B0:oa1::
        sendByClipboard("minimal osteoarthritis" A_EndChar,3)
    return
    :B0:oa12::
        sendByClipboard("minimal to mild osteoarthritis" A_EndChar,4)
    return
    :B0:oa2::
        sendByClipboard("mild osteoarthritis" A_EndChar,3)
    return
    :B0:oa23::
        sendByClipboard("mild to moderate osteoarthritis" A_EndChar,4)
    return
    :B0:oa3::
        sendByClipboard("moderate osteoarthritis" A_EndChar,3)
    return
    :B0:oa34::
        sendByClipboard("moderate to severe osteoarthritis" A_EndChar,4)
    return
    :B0:oa4::
        sendByClipboard("severe osteoarthritis" A_EndChar,3)
    return
    :B0:oa11::
        sendByClipboard("minimal osteoarthritis with tiny marginal osteophyte(s) at" A_EndChar,4)
    return
    :B0:oa122::
        sendByClipboard("mild osteoarthritis with tiny or small marginal osteophyte(s) at" A_EndChar,5)
    return
    :B0:oa22::
        sendByClipboard("mild osteoarthritis with small marginal osteophyte(s) at" A_EndChar,4)
    return
    :B0:oa233::
        sendByClipboard("mild to moderate osteoarthritis with marginal osteophyte(s) and mild joint space narrowing at" A_EndChar,5)
    return
    :B0:oa33::
        sendByClipboard("moderate osteoarthritis with marginal osteophyte(s) and joint space narrowing at" A_EndChar,4)
    return
    :B0:oa344::
        sendByClipboard("moderate to severe osteoarthritis with marginal osteophyte(s), joint space narrowing, and mild uneven articular surface at" A_EndChar,5)
    return
    :B0:oaa4::
        sendByClipboard("severe osteoarthritis with large marginal osteophyte(s), joint space narrowing, and uneven articular surface at" A_EndChar,4)
    return
    :B0:oaank::
        sendByClipboard("osteoarthritis at the tibiotalar joint, subtalar joint, and midtarsal joints" A_EndChar,5)
    return
    :B0:oaf1::
        sendByClipboard("osteoarthritis at interphalangeal joint(s) of thumb(s) and some distal interphalangeal joint(s) of finger(s)" A_EndChar,4)
    return
    :B0:oaf2::
        sendByClipboard("osteoarthritis at interphalangeal joint(s) of thumb(s) and some distal interphalangeal and proximal interphalangeal joint(s) of finger(s)" A_EndChar,4)
    return
    :B0:oat1::
        sendByClipboard("osteoarthritis at interphalangeal joint(s) of big toe(s) and some distal interphalangeal joint(s) of toe(s)" A_EndChar,4)
    return
    :B0:oat2::
        sendByClipboard("osteoarthritis at interphalangeal joint(s) of big toe(s) and some distal interphalangeal and proximal interphalangeal joint(s) of toe(s)" A_EndChar,4)
    return
    ;~ ::OAB::osteoarthritic change at all joint compartments of both knee joints
    :B0:oaba::
        sendByClipboard("osteoarthritic change at all joint compartments, more at patellofemoral joint compartments, of both knee joints" A_EndChar,4)
    return
    :B0:oacl::
        sendByClipboard("status post anterior cruciate ligament reconstruction with presence of tibial and femoral tunnels and metallic prostheses at distal femur and proximal tibia; fine alignment of the femorotibial joint and postOP change around the knee joint; suggest follow up study." A_EndChar,4)
    return
    :B0:oah::
        sendByClipboard("osteoarthritic change of both hip joints" A_EndChar,3)
    return
    :B0:oahr::
        sendByClipboard("osteoarthritic change of right hip joint" A_EndChar,4)
    return
    :B0:oahl::
        sendByClipboard("osteoarthritic change of left hip joint" A_EndChar,4)
    return
    :B0:oal::
        sendByClipboard("osteoarthritic change at all joint compartments of left knee joint" A_EndChar,3)
    return
    :B0:oala::
        sendByClipboard("osteoarthritic change at all joint compartments, more at patellofemoral joint compartment, of left knee joint" A_EndChar,4)
    return
    :B0:oalb::
        sendByClipboard("the joint spaces are more narrowed at both lateral joint compartments and cause valgus deformity of both knee joints" A_EndChar,4)
    return
    :B0:oall::
        sendByClipboard("the joint space is more narrowed at lateral joint compartment and causes valgus deformity of left knee joint" A_EndChar,4)
    return
    :B0:oalr::
        sendByClipboard("the joint space is more narrowed at lateral joint compartment and causes valgus deformity of right knee joint" A_EndChar,4)
    return
    :B0:oamb::
        sendByClipboard("the joint spaces are more narrowed at both medial joint compartments and cause varus deformity of both knee joints" A_EndChar,4)
    return
    :B0:oaml::
        sendByClipboard("the joint space is more narrowed at medial joint compartment and causes varus deformity of left knee joint" A_EndChar,4)
    return
    :B0:oamr::
        sendByClipboard("the joint space is more narrowed at medial joint compartment and causes varus deformity of right knee joint" A_EndChar,4)
    return
    :B0:oap::
        sendByClipboard("osteoarthritic change at the patellofemoral joint" A_EndChar,3)
    return
    :B0:oar::
        sendByClipboard("osteoarthritic change at all joint compartments of right knee joint" A_EndChar,3)
    return
    :B0:oara::
        sendByClipboard("osteoarthritic change at all joint compartments, more at patellofemoral joint compartment, of right knee joint" A_EndChar,4)
    return
    :B0:obg::
        sendByClipboard("bone grafting" A_EndChar,3)
    return
    :B0:obi::
        sendByClipboard("external immobilization" A_EndChar,3)
    return
    :B0:obp::
        sendByClipboard("status post blade plate and screw fixation" A_EndChar,3)
    return
    :B0:oc::
        sendByClipboard("external cast or splint application" A_EndChar,2)
    return
    :B0:oc1::
        sendByClipboard("status post external cast or splint application; the detail of bones is obliterated by artifacts of the cast or splint" A_EndChar,3)
    return
    :B0:ocd::
        sendByClipboard("osteochondral" A_EndChar,3)
    return
    :B0:ocdd::
        sendByClipboard("osteochondrosis" A_EndChar,4)
    return
    :B0:oci::
        sendByClipboard("patchy sclerotic change over lower poles of bilateral sacroiliac joints, suggesting osteitis condensans ilii" A_EndChar,3)
    return
    ;~ ::OCP::status post calcaneal lengthening and 1st toe interphalangeal fusion
    :B0:oddh1::
        sendByClipboard("acetabuloplasty" A_EndChar,5)
    return
    :B0:oddh2::
        sendByClipboard("varus osteotomy" A_EndChar,5)
    return
    :B0:odp::
        sendByClipboard("status post dynamic compression plate and screw fixation" A_EndChar,3)
    return
    :B0:ods::
        sendByClipboard("status post dynamic compression screw fixation" A_EndChar,3)
    return
    :B0:oe::
        sendByClipboard("status post external fixator application" A_EndChar,2)
    return
    :B0:oeb::
        sendByClipboard("status post external bandage with radiopaque artifacts and some detail of bones is obliterated" A_EndChar,3)
    return
    :B0:oei::
        sendByClipboard("status post external immobilization" A_EndChar,3)
    return
    :B0:ofc::
        sendByClipboard("status post calcaneal lengthening" A_EndChar,3)
    return
    :B0:ofn::
        sendByClipboard("posterior tibialis tendon transfer" A_EndChar,3)
    return
    :B0:ofs::
        sendByClipboard("status post subtalar arthroereisis" A_EndChar,3)
    return
    :B0:oft::
        sendByClipboard("talonavicular stapling" A_EndChar,3)
    return
    :B0:ohb::
        sendByClipboard("status post arthroplasty at both hip joints" A_EndChar,3)
    return
    :B0:ohhb::
        sendByClipboard("status post hemiarthroplasty at both hip joints" A_EndChar,4)
    return
    :B0:ohhl::
        sendByClipboard("status post hemiarthroplasty at left hip joint" A_EndChar,4)
    return
    :B0:ohhr::
        sendByClipboard("status post hemiarthroplasty at right hip joint" A_EndChar,4)
    return
    :B0:ohl::
        sendByClipboard("status post arthroplasty at left hip joint" A_EndChar,3)
    return
    :B0:ohr::
        sendByClipboard("status post arthroplasty at right hip joint" A_EndChar,3)
    return
    :B0:oii::
        sendByClipboard("status post internal (metallic) fixation" A_EndChar,3)
    return
    :B0:oib::
        sendByClipboard("interbody fusion at" A_EndChar,3)
    return
    :B0:oif::
        sendByClipboard("status post interbody fusion at" A_EndChar,3)
    return
    :B0:oin::
        sendByClipboard("status post intramedullary nail and interlocking screw fixation" A_EndChar,3)
    return
    :B0:oip::
        sendByClipboard("status post metallic pin fixation" A_EndChar,3)
    return
    :B0:oir::
        sendByClipboard("status post intramedullary rod insertion" A_EndChar,3)
    return
    :B0:okb::
        sendByClipboard("status post total knee arthroplasty at both knee joints" A_EndChar,3)
    return
    :B0:okbb::
        sendByClipboard("status post total knee arthroplasty at both knee joints with fine alignment and soft tissue swelling at anterior aspects; suggest clinical correlation." A_EndChar,4)
    return
    :B0:okl::
        sendByClipboard("status post total knee arthroplasty at left knee joint" A_EndChar,3)
    return
    :B0:okll::
        sendByClipboard("status post total knee arthroplasty at left knee joint with fine alignment and soft tissue swelling at anterior aspect; suggest clinical correlation." A_EndChar,4)
    return
    :B0:okr::
        sendByClipboard("status post total knee arthroplasty at right knee joint" A_EndChar,3)
    return
    :B0:okrr::
        sendByClipboard("status post total knee arthroplasty at right knee joint with fine alignment and soft tissue swelling at anterior aspect; suggest clinical correlation." A_EndChar,4)
    return
    :B0:oksl::
        sendByClipboard("status post limb salvage at left distal femur with long stem knee arthroplasty at left knee joint" A_EndChar,4)
    return
    :B0:oksr::
        sendByClipboard("status post limb salvage at left distal femur with long stem knee arthroplasty at right knee joint" A_EndChar,4)
    return
    :B0:okw::
        sendByClipboard("status post K-wire fixation" A_EndChar,3)
    return
    :B0:omp::
        sendByClipboard("status post metallic plate and screw fixation" A_EndChar,3)
    return
    :B0:oms::
        sendByClipboard("status post metallic screw fixation" A_EndChar,3)
    return
    :B0:omw::
        sendByClipboard("metallic wire fixation" A_EndChar,3)
    return
    :B0:onn::
        sendByClipboard("intravertebral vacuum, suggesting osteonecrosis" A_EndChar,3)
    return
    :B0:ons::
        sendByClipboard("decreased height(s) with suspect intravertebral vacuum, suggesting osteonecrosis, at" A_EndChar,3)
    return
    :B0:opv::
        sendByClipboard("osteopenic change of visible bones" A_EndChar,3)
    return
    :B0:opcl::
        sendByClipboard("status post posterior cruciate ligament reconstruction with presence of tibial and femoral tunnels; fine alignment of the femorotibial joint and postOP change around the knee joint; suggest follow up study." A_EndChar,4)
    return
    :B0:opd::
        sendByClipboard("osteopenic change at distal aspects of fracture site, suggestive of disuse osteopenia" A_EndChar,3)
    return
    ;~ ::OPLL::ossification of posterior longitudinal ligament (OPLL)
    :B0:opm::
        sendByClipboard("marked osteopenic change of visible bones" A_EndChar,3)
    return
    :B0:opp::
        sendByClipboard("periarticular osteopenia" A_EndChar,3)
    return
    :B0:opv1::
        sendByClipboard("suspected osteopenic change of visible bones" A_EndChar,4)
    return
    :B0:ore::
        sendByClipboard("removal of the implant" A_EndChar,3)
    return
    :B0:orp::
        sendByClipboard("status post reconstruction plate and screw fixation" A_EndChar,3)
    return
    :B0:osal::
        sendByClipboard("status post soft tissue anchor fixation over the left humeral greater tuberosity" A_EndChar,4)
    return
    :B0:osar::
        sendByClipboard("status post soft tissue anchor fixation over the right humeral greater tuberosity" A_EndChar,4)
    return
    :B0:osb::
        sendByClipboard("osteoblastic lesion" A_EndChar,3)
    return
    :*B0:osb1::
        sendByClipboard("osteoblastic lesions",3)
    return
    :B0:osg::
        sendByClipboard("irregularity and fragmentation at the tibial tuberosity with adjacent soft tissue swelling, Osgood-Schlatter disease is considered first" A_EndChar,3)
    return
    :B0:osl::
        sendByClipboard("status post posterior decompression and posterior instrumentation at" A_EndChar,3)
    return
    :B0:osll::
        sendByClipboard("status post laminectomy and posterior decompression, lateral bony fusion, transpedicle screw insertion and posterior instrumentation at" A_EndChar,4)
    return
    :B0:oslll::
        sendByClipboard("status post laminectomy and posterior decompression, lateral bony fusion, transpedicle screw insertion and posterior instrumentation, and interbody fusion at" A_EndChar,5)
    return
    ;~ ::OSP::external splinting
    :B0:otb::
        sendByClipboard("status post intramedullary pin and tension band wire fixation" A_EndChar,3)
    return
    ;~ ::P1::distal phalanx bone(s)
    ;~ ::P2::middle phalanx bone(s)
    :B0:p3::
        sendByClipboard("proximal phalanx bone" A_EndChar,2)
    return
    :*B0:p31::
        sendByClipboard("proximal phalanx bones",2)
    return
    :B0:p4::
        sendByClipboard("metacarpal bone" A_EndChar,2)
    return
    :*B0:p41::
        sendByClipboard("metacarpal bones",2)
    return
    :B0:p5::
        sendByClipboard("metatarsal bone" A_EndChar,2)
    return
    :*B0:p51::
        sendByClipboard("metatarsal bones",2)
    return
    :B0:p11::
        sendByClipboard("distal phalangeal" A_EndChar,3)
    return
    :B0:p22::
        sendByClipboard("middle phalangeal" A_EndChar,3)
    return
    :B0:p33::
        sendByClipboard("proximal phalangeal" A_EndChar,3)
    return
    :B0:p44::
        sendByClipboard("metacarpal" A_EndChar,3)
    return
    :B0:p55::
        sendByClipboard("metatarsal" A_EndChar,3)
    return
    :B0:paod::
        sendByClipboard("peripheral arterial occlusive disease" A_EndChar,4)
    return
    :B0:paodq::
        sendByClipboard("atherosclerosis with wall calcifications at the abdominal aorta and bilateral common iliac arteries as well as multifocal varying-sized calcified wall plaques on the wall of arteries in both lower limbs." A_EndChar,5)
    return
    :B0:pars::
        sendByClipboard("pars interarticularis" A_EndChar,4)
    return
    :B0:pcll::
        sendByClipboard("posterior cruciate ligament" A_EndChar,4)
    return
    :B0:pd::
        sendByClipboard("posterior decompression" A_EndChar,2)
    return
    :B0:pdfs::
        sendByClipboard("fat-suppressed PD images" A_EndChar,4)
    return
    :B0:pera::
        sendByClipboard("periprosthetic radiolucency" A_EndChar,4)
    return
    :B0:peri1::
        sendByClipboard("osteolysis" A_EndChar,5)
    return
    :B0:peri2::
        sendByClipboard("osteolysis or prosthetic loosening" A_EndChar,5)
    return
    :B0:peri3::
        sendByClipboard("prosthetic loosening" A_EndChar,5)
    return
    :B0:perif::
        sendByClipboard("periprosthetic fracture" A_EndChar,5)
    return
    :B0:pla::
        sendByClipboard("pes planus" A_EndChar,3)
    return
    :B0:plaa::
        sendByClipboard("small calcaneal inclination angle (calcaneal pitch), suggestive of pes planus" A_EndChar,4)
    return
    :B0:pf::
        sendByClipboard("previous fracture" A_EndChar,2)
    return
    :*B0:pf1::
        sendByClipboard("previous fractures",2)
    return
    :B0:pff::
        sendByClipboard("previous fracture or osteotomy" A_EndChar,3)
    return
    :B0:phlm::
        sendByClipboard("posterior horn of lateral meniscus" A_EndChar,4)
    return
    :B0:phmm::
        sendByClipboard("posterior horn of medial meniscus" A_EndChar,4)
    return
    :B0:pi::
        sendByClipboard("posterior instrumentation/fixation" A_EndChar,2)
    return
    :B0:plf::
        sendByClipboard("posterior lateral fusion" A_EndChar,3)
    return
    :B0:sac0::
        sendByClipboard("the sacrum is obliterated by the bowel gas" A_EndChar,4)
    return
    :B0:prd::
        sendByClipboard("protruding disc" A_EndChar,3)
    return
    :*B0:pcnt::
        sendByClipboard("paracentral",3)
    return
    :B0:frm::
        sendByClipboard("foramen" A_EndChar,3)
    return
    :*B0:frm1::
        sendByClipboard("foramina",3)
    return
    :*B0:frm2::
        sendByClipboard("foraminal",3)
    return

    :B0:pvb::
        sendByClipboard("pelvic bone" A_EndChar,3)
    return
    :*B0:pvb1::
        sendByClipboard("pelvic bones",3)
    return

    :B0:prob::
        sendByClipboard("broad-based protruding disc" A_EndChar,4)
    return
    :*B0:prob1::
        sendByClipboard("broad-based protruding discs",4)
    return
    :B0:prol::
        sendByClipboard("eccentric protruding disc(s) at left posterior aspect" A_EndChar,4)
    return
    :B0:pror::
        sendByClipboard("eccentric protruding disc(s) at right posterior aspect" A_EndChar,4)
    return
    :B0:puv::
        sendByClipboard("positive ulnar variance" A_EndChar,3)
    return
    :B0:pvns::
        sendByClipboard("pigmented villonodular synovitis" A_EndChar,4)
    return
    :B0:r3mt::
        sendByClipboard("right 3rd metatarsal" A_EndChar,4)
    return
    :B0:r4mt::
        sendByClipboard("right 4th metatarsal" A_EndChar,4)
    return
    :B0:r5mt::
        sendByClipboard("right 5th metatarsal" A_EndChar,4)
    return
    ;~ ::RA::rheumatoid arthritis
    :B0:rm1::
        sendByClipboard("hematopoietic (red) marrow" A_EndChar,3)
    return
    :B0:rm2::
        sendByClipboard("heterogeneous marrow signal change of mild hypointensity on T1WI but no abnormal hyperintensity on fat-suppressed T2WI at sacrum, bilateral pelvic bones and proximal femurs, hematopoietic (red) marrow is considered first." A_EndChar,3)
    return
    :B0:tsi1::
        sendByClipboard("thecal sac indentation and potential spinal stenosis" A_EndChar,4)
    return
    :B0:rpc::
        sendByClipboard("retropulsed posterior cortex" A_EndChar,3)
    return
    :B0:ftr::
        sendByClipboard("full-thickness rupture" A_EndChar,3)
    return
    ;~ ::ptr::partial-thickness rupture
    :B0:sal::
        sendByClipboard("straightening alignment" A_EndChar,3)
    return
    :B0:sacb::
        sendByClipboard("lumbar sacralization of L5 on both sides" A_EndChar,4)
    return
    :B0:sacl::
        sendByClipboard("partial lumbar sacralization of L5 on left side" A_EndChar,4)
    return
    :B0:sacr::
        sendByClipboard("partial lumbar sacralization of L5 on right side" A_EndChar,4)
    return
    :B0:sasd::
        sendByClipboard("subacromion-subdeltoid bursa" A_EndChar,4)
    return
    :B0:sbcb::
        sendByClipboard("subcoracoid bursa" A_EndChar,4)
    return
    :B0:sbf::
        sendByClipboard("spina bifida" A_EndChar,3)
    return
    :B0:scob::
        sendByClipboard("scoliosis with main (fixed) curvature at mid-thoracic spine and compensatory (correctable) curvature at the lumbar spine" A_EndChar,4)
    return
    :B0:scol::
        sendByClipboard("scoliosis with convexity of the thoracic spine to left side" A_EndChar,4)
    return
    :B0:scolr::
        sendByClipboard("scoliosis of spine with convexity of the thoracic spine to left side and convexity of the lumbar spine to right side" A_EndChar,5)
    return
    :B0:scor::
        sendByClipboard("scoliosis with convexity of the thoracic spine to right side" A_EndChar,4)
    return
    :B0:scorl::
        sendByClipboard("scoliosis of spine with convexity of the thoracic spine to right side and convexity of the lumbar spine to left side" A_EndChar,5)
    return
    :B0:sctl::
        sendByClipboard("scoliosis of the thoracolumbar spine" A_EndChar,4)
    return
    :B0:sd::
        sendByClipboard("decreased disc space and end-plate change" A_EndChar,2)
    return
    :B0:sds::
        sendByClipboard("decreased disc space and sclerotic end-plate change" A_EndChar,3)
    return
    :B0:sec::
        sendByClipboard("sclerotic endplate change" A_EndChar,3)
    return
    :B0:eec::
        sendByClipboard("edematous endplate change" A_EndChar,3)
    return
    :B0:seq::
        sendByClipboard("sequestrated disc" A_EndChar,3)
    return
    :*B0:seq1::
        sendByClipboard("sequestrated discs",3)
    return

    :B0:sh0::
        sendByClipboard("the glenohumeral joint appear normal; no obvious fracture line; no evidence of joint subluxation or dislocation." A_EndChar,3)
    return
    :B0:sh1::
        sendByClipboard("lateral down-sloping" A_EndChar,3)
    return
    :B0:sh2::
        sendByClipboard("subacromial spur" A_EndChar,3)
    return
    :B0:sh3::
        sendByClipboard("inferior marginal spur" A_EndChar,3)
    return
    :B0:shd::
        sendByClipboard("lateral down-sloping of the acromion" A_EndChar,3)
    return
    :B0:shdl::
        sendByClipboard("down-sloping and low-lying of the acromion" A_EndChar,4)
    return
    :B0:shl::
        sendByClipboard("low-lying" A_EndChar,3)
    return
    :B0:shn::
        sendByClipboard("subacromial space narrowing" A_EndChar,3)
    return
    :B0:shp::
        sendByClipboard("synovial herniation pit" A_EndChar,3)
    return
    :*B0:shp1::
        sendByClipboard("synovial herniation pits",3)
    return
    :B0:shs::
        sendByClipboard("subacromial spur formation" A_EndChar,3)
    return
    :B0:slac::
        sendByClipboard("SLAC (superior labrum anterior cuff) lesion" A_EndChar,4)
    return
    :B0:slapp::
        sendByClipboard("superior labral anterior-posterior (SLAP) lesion" A_EndChar,5)
    return
    :B0:slap2::
        sendByClipboard("linear high SI on T2WI and GRE T2WI in the superior labrum with anterior and posterior extension." A_EndChar,5)
    return
    :B0:slap3::
        sendByClipboard("large irregular high SI on T2WI and GRE T2WI in the superior labrum with anterior and posterior extension with bucket-handle like split and susp. extension into the biceps root." A_EndChar,5)
    return
    :B0:smn::
        sendByClipboard("Schmorl's node" A_EndChar,3)
    return
    :B0:sonk::
        sendByClipboard("spontaneous osteonecrosis of the knee (SONK)" A_EndChar,4)
    return
    :B0:sonkl::
        sendByClipboard("osteochondral defect with sclerotic margin at left medial femoral condylar articular surface, suggesting osteonecrosis." A_EndChar,5)
    return
    :B0:sonkr::
        sendByClipboard("osteochondral defect with sclerotic margin at right medial femoral condylar articular surface, suggesting osteonecrosis." A_EndChar,5)
    return
    :B0:sst::
        sendByClipboard("supraspinatus tendon" A_EndChar,3)
    return
    :B0:sstt::
        sendByClipboard("subscapularis tendon" A_EndChar,4)
    return
    :B0:st1::
        sendByClipboard("mild stenosis" A_EndChar,3)
    return
    :B0:st12::
        sendByClipboard("mild to moderate stenosis" A_EndChar,4)
    return
    :B0:st2::
        sendByClipboard("moderate stenosis" A_EndChar,3)
    return
    :B0:st23::
        sendByClipboard("moderate to severe stenosis" A_EndChar,4)
    return
    :B0:st3::
        sendByClipboard("severe stenosis" A_EndChar,3)
    return
    :B0:st4::
        sendByClipboard("nearly-total occlusion" A_EndChar,3)
    return
    :B0:st5::
        sendByClipboard("total occlusion" A_EndChar,3)
    return
    ;~ ::ST::spinal stenosis
    :B0:stc::
        sendByClipboard("soft tissue calcification" A_EndChar,3)
    return
    :*B0:stc1::
        sendByClipboard("soft tissue calcifications",3)
    return
    :B0:cat::
        sendByClipboard("calcific tendinitis" A_EndChar,3)
    return
    :B0:cabt::
        sendByClipboard("calcific bursitis or tendinosis" A_EndChar,4)
    return
    :B0:sth::
        sendByClipboard("increased heterogeneous soft tissue density" A_EndChar,3)
    return
    :B0:sti::
        sendByClipboard("increased soft tissue density" A_EndChar,3)
    return
    :B0:stirr::
        sendByClipboard("fat-suppressed T2WI" A_EndChar,5)
    return
    :B0:stl::
        sendByClipboard("soft tissue lesion" A_EndChar,3)
    return
    :B0:stm::
        sendByClipboard("soft tissue mass" A_EndChar,3)
    return
    :B0:stos::
        sendByClipboard("soft tissue ossification" A_EndChar,4)
    return
    :*B0:stos1::
        sendByClipboard("soft tissue ossifications",4)
    return
    :B0:stsa::
        sendByClipboard("adjacent soft tissue swelling" A_EndChar,4)
    return
    :B0:stsp::
        sendByClipboard("periarticular soft tissue swelling" A_EndChar,4)
    return
    :B0:stt::
        sendByClipboard("soft tissue tumor" A_EndChar,3)
    return
    :B0:subc::
        sendByClipboard("subchondral" A_EndChar,4)
    return
    :B0:suc::
        sendByClipboard("subcutaneous" A_EndChar,3)
    return
    :*B0:suc1::
        sendByClipboard("subcutis",3)
    return
    :B0:cu::
        sendByClipboard("cutaneous" A_EndChar,2)
    return
    :*B0:cu1::
        sendByClipboard("cutis",2)
    return

    :B0:mtj::
        sendByClipboard("musculotendinous junction" A_EndChar,3)
    return

    ;~ ::SUC1::subcutaneous swelling and fat stranding
    ;~ ::SUC2::subcutaneous swelling and edema
    ;~ ::T121::T12-L1
    ;~ ::T122::T12-L2
    ;~ ::T123::T12-L3
    ;~ ::T124::T12-L4
    ;~ ::T125::T12-L5
    ;~ ::T111::T11-L1
    ;~ ::T112::T11-L2
    ;~ ::T113::T11-L3
    ;~ ::T114::T11-L4
    ;~ ::T115::T11-L5
    ;~ ::T101::T10-L1
    ;~ ::T102::T10-L2
    ;~ ::T103::T10-L3
    ;~ ::T104::T10-L4
    ;~ ::T105::T10-L5
    :*B0:t00::
        sendByClipboard("T1-2",2)
    return
    :B0:taf::
        sendByClipboard("torn annulus fibrosus" A_EndChar,3)
    return
    :B0:te::
        sendByClipboard("traction enthesophyte formation at" A_EndChar,2)
    return
    :B0:tecb::
        sendByClipboard("traction enthesophyte formation at bilateral calcaneal posterior processes" A_EndChar,4)
    return
    :B0:tecl::
        sendByClipboard("traction enthesophyte formation at left calcaneal posterior process" A_EndChar,4)
    return
    :B0:tecr::
        sendByClipboard("traction enthesophyte formation at right calcaneal posterior process" A_EndChar,4)
    return
    :B0:tehb::
        sendByClipboard("traction enthesopathy at bilateral humeral greater tuberosities" A_EndChar,4)
    return
    :B0:tehl::
        sendByClipboard("traction enthesopathy at left humeral greater tuberosity" A_EndChar,4)
    return
    :B0:tehr::
        sendByClipboard("traction enthesopathy at right humeral greater tuberosity" A_EndChar,4)
    return
    :B0:tepb::
        sendByClipboard("traction enthesophyte formation at bilateral patellar bases" A_EndChar,4)
    return
    :B0:tepl::
        sendByClipboard("traction enthesophyte formation at left patellar base" A_EndChar,4)
    return
    :B0:tepr::
        sendByClipboard("traction enthesophyte formation at right patellar base" A_EndChar,4)
    return
    :B0:tis::
        sendByClipboard("tibial intercondylar spine" A_EndChar,3)
    return
    :B0:tie::
        sendByClipboard("tibial intercondylar eminance" A_EndChar,3)
    return
    :B0:tlj::
        sendByClipboard("thoracolumbar junction" A_EndChar,3)
    return
    :B0:tls::
        sendByClipboard("thoracolumbar spondylosis" A_EndChar,3)
    return
    :B0:tls1::
        sendByClipboard("thoracolumbar spondylosis with marginal osteophyte formation" A_EndChar,4)
    return
    :B0:tlsf::
        sendByClipboard("thoracolumbar spondylosis with marginal osteophyte formation and facet joint arthroses" A_EndChar,4)
    return
    :B0:tlss::
        sendByClipboard("thoracolumbar scoliosis and spondylosis" A_EndChar,4)
    return
    ;~ ::TLSS1::thoracolumbar scoliosis and spondylosis with marginal osteophyte formation
    :B0:tec::
        sendByClipboard("traction enthesopathic change" A_EndChar,3)
    return
    :B0:tech::
        sendByClipboard("traction enthesopathic change at the humeral greater tubercle" A_EndChar,4)
    return
    :B0:tecc::
        sendByClipboard("subchondral cyst(s) at the humeral head which may relate to traction enthesopathic change." A_EndChar,4)
    return
    :B0:ts::
        sendByClipboard("thoracic spondylosis" A_EndChar,2)
    return
    ;~ ::TS1::thoracic spondylosis with marginal osteophyte formation
    :B0:tsp::
        sendByClipboard("traction spur at patellar base" A_EndChar,3)
    return
    :B0:tss::
        sendByClipboard("thoracic scoliosis and spondylosis" A_EndChar,3)
    return
    ;~ ::TSS1::thoracic scoliosis and spondylosis with marginal osteophyte formation
    :B0:uc::
        sendByClipboard("callus formation" A_EndChar,2)
    return
    :B0:ud::
        sendByClipboard("suggestive of delayed union" A_EndChar,2)
    return
    :B0:udn::
        sendByClipboard("radiolucent gap at fracture cleft, suggesting radiological delayed or non-union" A_EndChar,3)
    return
    :B0:uao::
        sendByClipboard("a small bony focus near the ulnar styloid process which is probably related to accessory ossicle or old fracture" A_EndChar,3)
    return
    :B0:uop::
        sendByClipboard("ulnar olecranon process" A_EndChar,3)
    return
    :B0:usp::
        sendByClipboard("ulnar styloid process" A_EndChar,3)
    return
    :B0:uuc::
        sendByClipboard("unilateral callus formation" A_EndChar,3)
    return
    :B0:uw::
        sendByClipboard("well union of fracture cleft" A_EndChar,2)
    return
    :B0:uwc::
        sendByClipboard("well union and callus formation" A_EndChar,3)
    return
    :B0:vp0::
        sendByClipboard("status post vertebroplasty with bone cement in position" A_EndChar,3)
    return
    :B0:vwc::
        sendByClipboard("vascular wall calcifications" A_EndChar,3)
    return
    :B0:vld::
        sendByClipboard("valgus deformity" A_EndChar,3)
    return
    :B0:vrd::
        sendByClipboard("varus deformity" A_EndChar,3)
    return
    :B0:wd::
        sendByClipboard("wedge deformity" A_EndChar,2)
    return
    :B0:xc::
        sendByClipboard("subchondral cyst" A_EndChar,2)
    return
    :*B0:xc1::
        sendByClipboard("subchondral cysts",2)
    return
    :B0:xd::
        sendByClipboard("disc space narrowing" A_EndChar,2)
    return
    :B0:xe::
        sendByClipboard("subchondral erosion" A_EndChar,2)
    return
    :*B0:xe1::
        sendByClipboard("subchondral erosions",2)
    return
    :B0:xep::
        sendByClipboard("periarticular erosion" A_EndChar,3)
    return
    :*B0:xep1::
        sendByClipboard("periarticular erosions",3)
    return
    :B0:xj::
        sendByClipboard("joint space narrowing" A_EndChar,2)
    return
    :B0:xjj::
        sendByClipboard("joint space widening" A_EndChar,3)
    return
    :B0:xja::
        sendByClipboard("asymmetrical joint space narrowing" A_EndChar,3)
    return
    :B0:xjl::
        sendByClipboard("localized joint space narrowing" A_EndChar,3)
    return
    :B0:xjo::
        sendByClipboard("marginal spur formation and joint space narrowing at" A_EndChar,3)
    return
    :B0:xjs::
        sendByClipboard("symmetrical joint space narrowing" A_EndChar,3)
    return
    :B0:xo::
        sendByClipboard("marginal osteophyte" A_EndChar,2)
    return
    :*B0:xo1::
        sendByClipboard("marginal osteophytes",2)
    return
    :B0:xp::
        sendByClipboard("posterior spur" A_EndChar,2)
    return
    :*B0:xp1::
        sendByClipboard("posterior spurs",2)
    return
    :B0:xpp::
        sendByClipboard("disc space narrowing and posterior spur(s) with potential spinal stenosis" A_EndChar,3)
    return
    :B0:xr::
        sendByClipboard("subchondral radiolucencies" A_EndChar,2)
    return
    :B0:xs::
        sendByClipboard("subchondral sclerosis" A_EndChar,2)
    return
    :B0:xu::
        sendByClipboard("uneven articular surface" A_EndChar,2)
    return
    ;~ ::XX::joint space narrowing and margnial osteophytes formation
    :B0:zja::
        sendByClipboard("zygapophyseal joint arthrosis" A_EndChar,3)
    return
    :B0:z0::
        sendByClipboard("remainder of the exam is unremarkable" A_EndChar,2)
    return
    :B0:zsa::
        sendByClipboard("subarticular zone" A_EndChar,3)
    return

    :*B0:lscf::
        sendByClipboard("lumbar spondylosis with compression fracture",3)
    return
    :*B0:cscf::
        sendByClipboard("cervical spondylosis with compression fracture",3)
    return
    :*B0:tscf::
        sendByClipboard("thoracic spondylosis with compression fracture",3)
    return
    :*B0:tlscf::
        sendByClipboard("thoracolumbar spondylosis with compression fracture",4)
    return

    :*B0:lsop::
        sendByClipboard("lumbar spondylosis with post-operative changes",3)
    return
    :*B0:csop::
        sendByClipboard("cervical spondylosis with post-operative changes",3)
    return
    :*B0:tsop::
        sendByClipboard("thoracic spondylosis with post-operative changes",3)
    return
    :*B0:tlsop::
        sendByClipboard("thoracolumbar spondylosis with post-operative changes",4)
    return
    :B0:ops::
        sendByClipboard("post-operative changes of the spine." A_EndChar,3)
    return

    :*B0:csst::
        sendByClipboard("cervical spondylosis with spinal stenosis.",3)
    return
    :*B0:tsst::
        sendByClipboard("thoracic spondylosis with spinal stenosis.",3)
    return
    :*B0:lsst::
        sendByClipboard("lumbar spondylosis with spinal stenosis.",3)
    return
    :*B0:tlsst::
        sendByClipboard("thoracolumbar spondylosis with spinal stenosis.",4)
    return

    :B0:cs::
        sendByClipboard("cervical spondylosis" A_EndChar,2)
    return
    ;~ ::CS1::cervical spondylosis with marginal osteophyte formation
    ;~ ::CS2::cervical spondylosis with marginal osteophyte formation and facet joint arthroses
    :B0:csl::
        sendByClipboard("cervical spondylosis with marginal osteophyte formation at lower levels" A_EndChar,3)
    return
    :B0:csm::
        sendByClipboard("mild cervical spondylosis with small marginal osteophyte formation" A_EndChar,3)
    return
    :B0:csp::
        sendByClipboard("fine alignment; no obvious fracture line; no abnormal retropharyngeal soft tissue;" A_EndChar,3)
    return
    :B0:css::
        sendByClipboard("cervical scoliosis and spondylosis" A_EndChar,3)
    return
    ;~ ::CSS1::cervical scoliosis and spondylosis with marginal osteophyte formation
    ;~ ::CSS2::cervical scoliosis and spondylosis with marginal osteophyte formation and facet joint arthroses
    :B0:cssl::
        sendByClipboard("cervical scoliosis and spondylosis with marginal osteophyte formation at lower levels" A_EndChar,4)
    return
    :B0:cssm::
        sendByClipboard("cervical scoliosis and spondylosis with small marginal osteophyte formation" A_EndChar,4)
    return
    :B0:ls::
        sendByClipboard("lumbar spondylosis" A_EndChar,2)
    return
    ;~ ::LS1::lumbar spondylosis with marginal osteophyte formation
    ;~ ::LS2::lumbar spondylosis with marginal osteophyte formation and facet joint arthroses
    ;~ ::LS3::lumbar spondylosis with marginal osteophyte formation at multiple levels and facet joint arthroses at lower levels
    :B0:lsl::
        sendByClipboard("lumbar spondylosis with marginal osteophyte formation at lower lumbar levels" A_EndChar,3)
    return
    :B0:lsm::
        sendByClipboard("mild lumbar spondylosis with small marginal osteophyte formation" A_EndChar,3)
    return
    :B0:lss::
        sendByClipboard("lumbar scoliosis and spondylosis" A_EndChar,3)
    return
    ;~ ::LSS1::lumbar scoliosis and spondylosis with marginal osteophyte formation
    ;~ ::LSS2::lumbar scoliosis and spondylosis with marginal osteophyte formation and facet joint arthroses
    :B0:lssl::
        sendByClipboard("lumbar scoliosis and spondylosis with marginal osteophyte formation at lower lumbar levels" A_EndChar,4)
    return
    :B0:lssm::
        sendByClipboard("lumbar scoliosis and spondylosis with small marginal osteophyte formation" A_EndChar,4)
    return
    :B0:lsk::
        sendByClipboard("lumbar kyphoscoliosis and spondylosis" A_EndChar,3)
    return
    ;~ ::LSK1::lumbar kyphoscoliosis and spondylosis with marginal osteophyte formation
    ;~ ::LSK2::lumbar kyphoscoliosis and spondylosis with marginal osteophyte formation and facet joint arthroses
    :B0:lskl::
        sendByClipboard("lumbar kyphoscoliosis and spondylosis with marginal osteophyte formation at lower lumbar levels" A_EndChar,4)
    return
    :B0:lskm::
        sendByClipboard("lumbar kyphoscoliosis and spondylosis with small marginal osteophyte formation" A_EndChar,4)
    return
    :B0:lstv::
        sendByClipboard("lumbosacral transitional vertebrae" A_EndChar,4)
    return
    :B0:lstvb::
        sendByClipboard("lumbosacral transitional vertebrae with pseudoarticulation on both sides" A_EndChar,5)
    return
    :B0:lstvr::
        sendByClipboard("lumbosacral transitional vertebrae with pseudoarticulation on right side" A_EndChar,5)
    return
    :B0:lstvl::
        sendByClipboard("lumbosacral transitional vertebrae with pseudoarticulation on left side" A_EndChar,5)
    return

    :B0:lhar::
        sendByClipboard("lipohemoarthrosis" A_EndChar,4)
    return
    :B0:mof::
        sendByClipboard("marginal osteophyte formation" A_EndChar,3)
    return
    :B0:pmof::
        sendByClipboard("posterior marginal osteophyte formation" A_EndChar,4)
    return
    ;~ ::wdg::wedge deformity
    :B0:dch::
        sendByClipboard("decreased height" A_EndChar,3)
    return
    :B0:dcl::
        sendByClipboard("decreased lordosis" A_EndChar,3)
    return
    :B0:cf::
        sendByClipboard("compression fracture" A_EndChar,2)
    return
    :*B0:cf1::
        sendByClipboard("compression fractures",2)
    return
    :B0:iar::
        sendByClipboard("intra-articular" A_EndChar,3)
    return
    :B0:cmn::
        sendByClipboard("comminuted" A_EndChar,3)
    return
    :B0:dsp::
        sendByClipboard("displaced" A_EndChar,3)
    return
    :B0:ndsp::
        sendByClipboard("non-displaced" A_EndChar,4)
    return
    :B0:dpm::
        sendByClipboard("displacement" A_EndChar,3)
    return
    :B0:fx::
        sendByClipboard("fracture" A_EndChar,2)
    return
    :*B0:fx1::
        sendByClipboard("fractures",2)
    return
    :B0:spc::
        sendByClipboard("cervical spine" A_EndChar,3)
    return
    :B0:spt::
        sendByClipboard("thoracic spine" A_EndChar,3)
    return
    :B0:spl::
        sendByClipboard("lumbar spine" A_EndChar,3)
    return
    :B0:sptl::
        sendByClipboard("thoracolumbar spine" A_EndChar,4)
    return
    :B0:spct::
        sendByClipboard("cervicothoracic spine" A_EndChar,4)
    return
    :B0:spls::
        sendByClipboard("lumbosacral spine" A_EndChar,4)
    return
    :B0:spd::
        sendByClipboard("spondylosis" A_EndChar,3)
    return
    :B0:li::
        sendByClipboard("spondylolisthesis" A_EndChar,2)
    return
    :B0:li2::
        sendByClipboard("spondylolisthesis at L2-3" A_EndChar,3)
    return
    :B0:li3::
        sendByClipboard("spondylolisthesis at L3-4" A_EndChar,3)
    return
    :B0:li4::
        sendByClipboard("spondylolisthesis at L4-5" A_EndChar,3)
    return
    :B0:li5::
        sendByClipboard("spondylolisthesis at L5-S1" A_EndChar,3)
    return
    :B0:lid::
        sendByClipboard("degenerative spondylolisthesis" A_EndChar,3)
    return
    :B0:lid2::
        sendByClipboard("degenerative spondylolisthesis at L2-3" A_EndChar,4)
    return
    :B0:lid3::
        sendByClipboard("degenerative spondylolisthesis at L3-4" A_EndChar,4)
    return
    :B0:lid4::
        sendByClipboard("degenerative spondylolisthesis at L4-5" A_EndChar,4)
    return
    :B0:lid5::
        sendByClipboard("degenerative spondylolisthesis at L5-S1" A_EndChar,4)
    return
    :B0:lil::
        sendByClipboard("spondylolytic spondylolisthesis" A_EndChar,3)
    return
    :B0:lil2::
        sendByClipboard("spondylolytic spondylolisthesis at L2-3" A_EndChar,4)
    return
    :B0:lil3::
        sendByClipboard("spondylolytic spondylolisthesis at L3-4" A_EndChar,4)
    return
    :B0:lil4::
        sendByClipboard("spondylolytic spondylolisthesis at L4-5" A_EndChar,4)
    return
    :B0:lil5::
        sendByClipboard("spondylolytic spondylolisthesis at L5-S1" A_EndChar,4)
    return
    :B0:lia::
        sendByClipboard("anterolisthesis" A_EndChar,3)
    return
    :B0:lir::
        sendByClipboard("retrolisthesis" A_EndChar,3)
    return
    :B0:fx0::
        sendByClipboard("no obvious bony fracture" A_EndChar,3)
    return
    :B0:cst::
        sendByClipboard("spinal canal narrowing" A_EndChar,3)
    return
    :*B0:spca::
        sendByClipboard("spinal canal",3)
    return
    :B0:doc::
        sendByClipboard("disc osteophyte complex" A_EndChar,3)
    return

    ;~ ::L11::T12-L1
    ;~ ::L12::L1-L2
    ;~ ::L23::L2-L3
    ;~ ::L34::L3-L4
    ;~ ::L45::L4-L5
    ;~ ::L41::L4-L5-S1
    ;~ ::L51::L5-S1
    ;~ ::L35::L3-L4-L5
    ;~ ::L31::L3-L4-L5-S1

    ;~ ::C12::atlantoaxial joint

    :*B0:sfaa::
        sendByClipboard("superficial femoral artery",3)
    return
    :*B0:sfaa1::
        sendByClipboard("superficial femoral arteries",4)
    return
    :*B0:ataa::
        sendByClipboard("anterior tibial artery",3)
    return
    :*B0:ataa1::
        sendByClipboard("anterior tibial arteries",4)
    return
    :*B0:ptaa::
        sendByClipboard("posterior tibial artery",3)
    return
    :*B0:ptaa1::
        sendByClipboard("posterior tibial arteries",4)
    return

    :B0:bfn::
        sendByClipboard("bilateral neural foraminal narrowing" A_EndChar,3)
    return
    :B0:rfn::
        sendByClipboard("right neural foraminal narrowing" A_EndChar,3)
    return
    :B0:lfn::
        sendByClipboard("left neural foraminal narrowing" A_EndChar,3)
    return
    :*B0:cst1::
        sendByClipboard("mild spinal canal narrowing",3)
    return
    :*B0:cst2::
        sendByClipboard("moderate spinal canal narrowing",3)
    return
    :*B0:cst3::
        sendByClipboard("severe spinal canal narrowing",3)
    return

    spine:
        send % "{bs " StrLen($.value(0))  "}"
        sendByClipboard(spineLevel($))
    return

    spineLevel($){
        if ($.value(0)="")
            strMode:=true

        str:=""

        if(strMode)
            RegExMatch($, "^\D+", sg)
                ,RegExMatch($, "\d+$", lvl)
        else
            sg:=$.value(1)
                ,lvl:=$.value(2)
        if StrLen(lvl)=4 {
            if(sg!="t")
                goto nonSpine
            else
                match1:=SubStr(lvl,1,2), match2:=SubStr(lvl,3,2)
            if(match1>match2)
                goto Nonspine
        }else if StrLen(lvl)=3 {
            if(sg="t"){
                match1:=SubStr(lvl,1,2), match2:=SubStr(lvl,3,1)
                if(match1>12)
                    match1:=SubStr(lvl,1,1), match2:=SubStr(lvl,2,2)
            }
            else if (sg="c")
                match1:=SubStr(lvl,1,1), match2:=SubStr(lvl,2,2)
            else
                goto nonSpine
        }else{
            regexmatch(lvl,"^(\d)(\d)$",match)
        }

        stringupper,sg,sg
        if (strlen(lvl)=1) || (StrLen(lvl)=2 && lvl<13 && sg="t") {
            if(sg="t")
                str:=sg lvl
            else if ((sg="C" && lvl<9) || (sg="L" && lvl<6) || (sg="S" && lvl<5))
                str:=sg lvl
            else
                goto nonSpine
        }else if (sg="c") {
            ;~ if(lvl="12")
            ;~ str:="atlantoaxial joint"
            if (match1>match2)
                str:="C" match1 "-T" match2
            else if (match1<match2)
                str:="C" match1 "-" (StrLen(match2)=2?"T":"") match2
        }else if (sg="t") {
            if (match1>match2)
                str:="T" match1 "-L" match2
            else if (match1<match2)
                str:="T" match1 "-" match2
        }else if (sg="l") {
            if (match1>match2)
                str:="L" match1 "-S" match2
            else if (match1<match2)
                str:="L" match1 "-" match2
        }else if (sg="s") {
            if (match1<match2)
                str:="S" match1 "-" match2
            else
                goto nonSpine
        }

        vb:="", cf:=""
        if InStr($.value(3), "b"){
            vb:=InStr(str, "-")?" vertebral bodies":" vertebral body"
        }else if InStr($.value(3), "c"){
            cf:=InStr(str, "-")?"compression fractures at ":"compression fracture at "
        }else if InStr($.value(3), "e"){
            cf:="bone marrow edema at "
                ,vb:=InStr(str, "-")?" vertebral bodies":" vertebral body"
        }

        Sleep 50
        if (str="")
            return
        else{
            return % cf str vb $.value(4)
        }
        ;~ sendByClipboard(str $.value(3), strlen($.value(0)))
        $:=""
        return
        nonSpine:
        ;~ sendByClipboard($.value(0))
        $:=""
        return
    }
    ;~ spineName(segment,from,to=""){
    ;~ if (to="")
    ;~ to:=segment="c"?7:segment="t"?12:segment="l"?5:segment="s"?4:0
    ;~ str:=""
    ;~ while to>from
    ;~ str.="
    ;~ }

    :B0:sco::
        sendByClipboard("scoliosis" A_EndChar,3)
    return
    :B0:lor::
        sendByClipboard("lordosis" A_EndChar,3)
    return
    ;~ ::dgc::degenerative change(s)
    :B0:nsc::
        sendByClipboard("no abnormal prevertebral soft tissue swelling" A_EndChar,3)
    return
    :B0:vb::
        sendByClipboard("vertebral body" A_EndChar,2)
    return
    :*B0:vb1::
        sendByClipboard("vertebral bodies",2)
    return
    :B0:nfn::
        sendByClipboard("neural foraminal narrowing" A_EndChar,3)
    return
    :B0:oly::
        sendByClipboard("osteolytic" A_EndChar,3)
    return
    :B0:oba::
        sendByClipboard("osteoblastic" A_EndChar,3)
    return
    :B0:olma::
        sendByClipboard("odontoid-lateral mass interval asymmetry" A_EndChar,4)
    return

    ;pediatric
    :B0:intus::
        sendByClipboard("intussusception" A_EndChar,5)
    return

    ;body
    :B0:rhc::
        sendByClipboard("right hemicolectomy" A_EndChar,3)
    return
    :B0:lhc::
        sendByClipboard("left hemicolectomy" A_EndChar,3)
    return
    :B0:hct::
        sendByClipboard("hemicolectomy" A_EndChar,3)
    return

    :B0:gbw::
        sendByClipboard("gallbladder wall" A_EndChar,3)
    return
    :B0:ppv::
        sendByClipboard("patent portal vein" A_EndChar,3)
    return
    :B0:whp::
        sendByClipboard("status post Whipple operation." A_EndChar,3)
    return

    :cB0:aml::
        sendByClipboard("AML" A_EndChar,3)
    return
    :B0:amls::
        sendByClipboard("AMLs" A_EndChar,4)
    return

    :B0:oab::
        sendByClipboard("post-operative change in abdomen." A_EndChar,3)
    return

    :B0:rcx::
        sendByClipboard("renal calyx" A_EndChar,3)
    return
    :*B0:rcx1::
        sendByClipboard("renal calyces",3)
    return

    :B0:nab::
        sendAndNextLine("no definite abdominal lymphadenopathy.")
    return
    :*B0:pao1::
        sendAndNextLine("small para-aortic lymph nodes.")
    return

    :B0:bma::
        sendByClipboard("biloma" A_EndChar,3)
    return
    :*B0:bma1::
        sendByClipboard("bilomas",3)
    return

    :B0:dbj::
        sendByClipboard("double-J catheter" A_EndChar,3)
    return
    :*B0:dbj1::
        sendByClipboard("double-J catheters",3)
    return

    :B0:utm::
        sendByClipboard("uterine mass" A_EndChar,3)
    return
    :*B0:utm1::
        sendByClipboard("uterine masses",3)
    return
    :B0:pss::
        sendByClipboard("porto-systemic shunts" A_EndChar,3)
    return
    :B0:hia::
        sendByClipboard("hiatal hernia" A_EndChar,3)
    return
    :*B0:schm::
        sendByClipboard("subcapsular hematoma",3)
    return

    :*B0:pclv::
        sendByClipboard("polycystic liver",3)
    return
    :*B0:pclk::
        sendByClipboard("polycystic liver and kidney",3)
    return
    :B0:pck::
        sendByClipboard("polycystic kidney" A_EndChar,3)
    return

    :B0:oco::
        sendByClipboard("post-operative changes of colon" A_EndChar,3)
    return
    :B0:olv::
        sendByClipboard("post-operative changes of liver" A_EndChar,3)
    return
    :B0:osp::
        sendByClipboard("post-operative changes of spine" A_EndChar,3)
    return
    :B0:umb::
        sendByClipboard("umbilical" A_EndChar,3)
    return
    :B0:clt::
        sendByClipboard("celiac trunk" A_EndChar,3)
    return

    :B0:plv::
        sendByClipboard("pelvic" A_EndChar,3)
    return
    :*B0:atbk::
        sendByClipboard("atrophic change of bilateral kidneys",3)
    return
    :*B0:atkc::
        sendByClipboard("atrophic change of bilateral kidneys with cysts",3)
    return
    :*B0:atrk::
        sendByClipboard("atrophic change of right kidney",3)
    return
    :*B0:atlk::
        sendByClipboard("atrophic change of left kidney",3)
    return
    :*B0:atpn::
        sendByClipboard("atrophic change of pancreas",3)
    return
    :B0:rsc::
        sendByClipboard("rectosigmoid colon" A_EndChar,3)
    return
    :B0:rcm::
        sendByClipboard("rectum" A_EndChar,3)
    return
    :B0:rcl::
        sendByClipboard("rectal" A_EndChar,3)
    return

    :B0:pht::
        sendByClipboard("portal hypertension with collaterals" A_EndChar,3)
    return
    :B0:rpv::
        sendByClipboard("renal pelvis" A_EndChar,3)
    return
    :*B0:rpv1::
        sendByClipboard("renal pelvises",3)
    return
    :B0:adg::
        sendByClipboard("adrenal gland" A_EndChar,3)
    return
    :*B0:adg1::
        sendByClipboard("adrenal glands",3)
    return
    :B0:pgb::
        sendByClipboard("perigallbladder" A_EndChar,3)
    return
    :B0:ppn::
        sendByClipboard("peripancreatic" A_EndChar,3)
    return
    :B0:prl::
        sendByClipboard("perirenal" A_EndChar,3)
    return
    :*B0:prl1::
        sendByClipboard("pararenal",3)
    return
    :B0:ptt::
        sendByClipboard("prostate" A_EndChar,3)
    return
    :B0:ils::
        sendByClipboard("ileus" A_EndChar,3)
    return
    :cB0:hys::
        sendByClipboard("hysterectomy" A_EndChar,3)
    return
    :*B0:bx/::
        sendByClipboard("bilateral adnexal cystic lesions",2)
    return
    :*B0:lx/::
        sendByClipboard("left adnexal cystic lesion",2)
    return
    :*B0:rx/::
        sendByClipboard("right adnexal cystic lesion",2)
    return
    :B0:xcl::
        sendByClipboard("adnexal cystic lesion" A_EndChar,3)
    return
    :B0:abw::
        sendByClipboard("abdominal wall" A_EndChar,3)
    return
    :*B0:dc0::
        sendByClipboard("degenerative change of spine.`r`n- atherosclerotic calcification of the aorta.`r`n-",2)
    return
    :B0:aov::
        sendByClipboard("ampulla of Vater" A_EndChar,3)
    return
    :B0:hcc::
        sendByClipboard("HCC" A_EndChar,3)
    return
    :B0:hccs::
        sendByClipboard("HCCs" A_EndChar,4)
    return
    :*B0:app0::
        sendByClipboard("the appendix is not well-identified.",3)
    return
    :*B0:msn1::
        sendByClipboard("mesenteric",3)
    return
    :B0:msn::
        sendByClipboard("mesentery" A_EndChar,3)
    return
    :B0:aba::
        sendByClipboard("abdominal aorta" A_EndChar,3)
    return
    :*B0:hc/::
        sendByClipboard("hypodense lesion(s) in liver, probably cyst(s).",2)
    return
    :*B0:rc/::
        sendByClipboard("hypodense lesion(s) in kidney(s), probably cyst(s).",2)
    return
    :B0:hrc::
        sendByClipboard("hepatic and renal cysts." A_EndChar,3)
    return
    :*B0:hrc0::
        sendByClipboard("hypodense lesions in liver and kidneys, cysts are favored.",3)
    return
    :B0:cos::
        sendByClipboard("collecting system" A_EndChar,3)
    return
    :B0:nft::
        sendByClipboard("nephrectomy" A_EndChar,3)
    return
    :*B0:spln::
        sendByClipboard("splenectomy",3)
    return
    :*B0:adrn::
        sendByClipboard("adrenectomy",3)
    return
    :B0:sbi::
        sendByClipboard("small bowel ileus" A_EndChar,3)
    return
    :B0:ffs::
        sendByClipboard("focal fatty sparing" A_EndChar,3)
    return
    :B0:hmp::
        sendByClipboard("hemoperitoneum" A_EndChar,3)
    return
    :B0:hrp::
        sendByClipboard("hemoretroperitoneum" A_EndChar,3)
    return
    :B0:adn::
        sendByClipboard("adnexal" A_EndChar,3)
    return
    :B0:cds::
        sendByClipboard("cul-de-sac" A_EndChar,3)
    return
    :*B0:taec::
        sendByClipboard("post-TAE change",3)
    return
    :B0:txl::
        sendByClipboard("post-treatment change of the liver." A_EndChar,3)
    return
    :*B0:txl1::
        sendByClipboard("post-TAE change of the liver.",3)
    return
    :*B0:txl2::
        sendByClipboard("post-RFA change of the liver.",3)
    return
    :*B0:txl3::
        sendByClipboard("post-TAE and post-RFA change of the liver.",3)
    return
    :*B0:uvjj::
        sendByClipboard("ureterovesical junction",3)
    return
    :*B0:upjj::
        sendByClipboard("ureteropelvic junction",3)
    return
    :B0:amm::
        sendByClipboard("adenomyomatosis" A_EndChar,3)
    return
    :B0:djj::
        sendByClipboard("duodenojejunal junction" A_EndChar,3)
    return
    :B0:gej::
        sendByClipboard("gastroesophageal junction" A_EndChar,3)
    return
    :B0:tpt::
        sendByClipboard("transplantation" A_EndChar,3)
    return
    :B0:hp::
        sendByClipboard("hepatic" A_EndChar,2)
    return
    :B0:hpc::
        sendByClipboard("hepatic calcification" A_EndChar,3)
    return
    :*B0:hpc1::
        sendByClipboard("hepatic calcifications",3)
    return

    :B0:git::
        sendByClipboard("gastrointestinal tract" A_EndChar,3)
    return
    :*B0:git1::
        sendByClipboard("gastrointestinal tracts",3)
    return
    :B0:gt::
        sendByClipboard("gastric" A_EndChar,2)
    return
    :B0:gtb::
        sendByClipboard("gastric body" A_EndChar,3)
    return
    :B0:gta::
        sendByClipboard("gastric antrum" A_EndChar,3)
    return
    :B0:gtc::
        sendByClipboard("gastric cardia" A_EndChar,3)
    return
    :B0:sfr::
        sendByClipboard("subphrenic" A_EndChar,3)
    return
    :B0:panu::
        sendByClipboard("pseudoaneurysm" A_EndChar,4)
    return
    :*B0:panu1::
        sendByClipboard("pseudoaneurysms",4)
    return
    :*B0:iiavc::
        sendByClipboard("IVC interruption with azygos vein continuation",4)
    return
    :B0:hmn::
        sendByClipboard("hemangioma" A_EndChar,3)
    return
    :*B0:hmn1::
        sendByClipboard("hemangiomas",3)
    return
    ;~ :*:rc/::Bilateral renal cysts.
    :*B0:br/::
        sendByClipboard("bilateral renal cysts.",2)
    return
    :*B0:rr/::
        sendByClipboard("right renal cyst(s).",2)
    return
    :*B0:lr/::
        sendByClipboard("left renal cyst(s).",2)
    return
    ;~ :*:hc/::hepatic cyst(s).
    :B0:ifll::
        sendByClipboard("indeterminate focal liver lesions" A_EndChar,4)
    return
    :B0:pnp::
        sendByClipboard("pneumoperitoneum" A_EndChar,3)
    return
    :*B0:abd0::
        sendByClipboard("no definite focal lesions in the GI tract, liver, spleen, pancreas, both adrenal glands and kidneys.",3)
    return
    :B0:lspak::
        sendAndNextLine("no definite focal lesions in the liver, spleen, pancreas, both adrenal glands and kidneys")
    return
    :B0:lspa::
        sendAndNextLine("no definite focal lesions in the liver, spleen, pancreas and both adrenal glands")
    return
    :B0:lsp::
        sendAndNextLine("no definite focal lesions in the liver, spleen and pancreas")
    return
    :B0:spak::
        sendAndNextLine("no definite focal lesions in the spleen, pancreas, both adrenal glands and kidneys")
    return
    :B0:spa::
        sendAndNextLine("no definite focal lesions in the spleen, pancreas, both adrenal glands")
    return
    :B0:gb::
        sendByClipboard("gallbladder" A_EndChar,2)
    return
    :B0:sto::
        sendByClipboard("stomach" A_EndChar,3)
    return
    :*B0:cbdd::
        sendByClipboard("common bile duct",3)
    return
    :*B0:ihdd::
        sendByClipboard("intrahepatic duct",3)
    return
    :*B0:ihdd1::
        sendByClipboard("intrahepatic ducts",4)
    return
    :cB0:lv::
        sendByClipboard("liver" A_EndChar,2)
    return
    :cB0:Lv::
        sendByClipboard("Liver" A_EndChar,2)
    return
    :B0:llv::
        sendByClipboard("left lobe of liver" A_EndChar,3)
    return
    :B0:rlv::
        sendByClipboard("right lobe of liver" A_EndChar,3)
    return
    :B0:blv::
        sendByClipboard("both lobes of liver" A_EndChar,3)
    return
    :B0:kd::
        sendByClipboard("kidney" A_EndChar,2)
    return
    :*B0:kd1::
        sendByClipboard("kidneys",2)
    return
    :B0:lk::
        sendByClipboard("left kidney" A_EndChar,2)
    return
    :B0:rk::
        sendByClipboard("right kidney" A_EndChar,2)
    return
    :B0:bk::
        sendByClipboard("bilateral kidneys" A_EndChar,2)
    return
    :B0:duo::
        sendByClipboard("duodenum" A_EndChar,3)
    return
    :*B0:duo1::
        sendByClipboard("duodenal",3)
    return
    :B0:jej::
        sendByClipboard("jejunum" A_EndChar,3)
    return
    :*B0:jej1::
        sendByClipboard("jejunal",3)
    return
    :B0:ilm::
        sendByClipboard("ileum" A_EndChar,3)
    return
    :*B0:ilm1::
        sendByClipboard("ileal",3)
    return
    :B0:icj::
        sendByClipboard("ileocecal junction" A_EndChar,3)
    return
    :B0:icvv::
        sendByClipboard("ileocecal valve" A_EndChar,4)
    return
    :B0:ad::
        sendByClipboard("adrenal" A_EndChar,2)
    return
    :*B0:ad1::
        sendByClipboard("adrenals",2)
    return
    :B0:ag::
        sendByClipboard("adrenal gland" A_EndChar,2)
    return
    :*B0:ag1::
        sendByClipboard("adrenal glands",2)
    return
    :B0:ab::
        sendByClipboard("abdomen" A_EndChar,2)
    return
    :*B0:ab1::
        sendByClipboard("abdominal",2)
    return
    :B0:pel::
        sendByClipboard("pelvic" A_EndChar,3)
    return
    :B0:pev::
        sendByClipboard("pelvic cavity" A_EndChar,3)
    return
    :B0:pao::
        sendByClipboard("para-aortic" A_EndChar,3)
    return
    :B0:aoc::
        sendByClipboard("aorto-caval" A_EndChar,3)
    return
    :B0:asc::
        sendByClipboard("ascites" A_EndChar,3)
    return
    :*B0:sp0::
        sendByClipboard("spondylosis of the lumbar spine with marginal osteophyte formation.",2)
    return
    :B0:ph::
        sendByClipboard("phlebolith" A_EndChar,2)
    return
    :*B0:ph1::
        sendByClipboard("phleboliths",2)
    return
    :B0:gs::
        sendByClipboard("gallstone" A_EndChar,2)
    return
    :*B0:gs1::
        sendByClipboard("gallstones",2)
    return
    :B0:div::
        sendByClipboard("diverticulum" A_EndChar,3)
    return
    :*B0:div1::
        sendByClipboard("diverticulosis",3)
    return
    :*B0:div2::
        sendByClipboard("diverticulitis",3)
    return
    :B0:pan::
        sendByClipboard("pancreas" A_EndChar,3)
    return
    :*B0:pan1::
        sendByClipboard("pancreatic",3)
    return
    :B0:pnh::
        sendByClipboard("pancreatic head" A_EndChar,3)
    return
    :B0:pnb::
        sendByClipboard("pancreatic body" A_EndChar,3)
    return
    :B0:pnt::
        sendByClipboard("pancreatic tail" A_EndChar,3)
    return
    :B0:pnd::
        sendByClipboard("pancreatic duct" A_EndChar,3)
    return
    :B0:ub::
        sendByClipboard("urinary bladder" A_EndChar,2)
    return
    :B0:per::
        sendByClipboard("peritoneum" A_EndChar,3)
    return
    :*B0:pers::
        sendByClipboard("peritoneal seedings",3)
    return
    :*B0:pert::
        sendByClipboard("peritoneal thickening",3)
    return
    :*B0:per1::
        sendByClipboard("peritoneal",3)
    return
    :*B0:pecr::
        sendByClipboard("peritoneal carcinomatosis",3)
    return
    :B0:ptc::
        sendByClipboard("peritoneal cavity" A_EndChar,3)
    return
    :B0:rpr::
        sendByClipboard("retroperitoneum" A_EndChar,3)
    return
    :*B0:rpr1::
        sendByClipboard("retroperitoneal",3)
    return
    :B0:app::
        sendByClipboard("appendix" A_EndChar,3)
    return
    :*B0:gi0::
        sendAndNextLine("no definite obstructive lesion of the gastrointestinal tracts.")
    return
    :B0:chs::
        sendByClipboard("cholecystitis" A_EndChar,3)
    return
    :*B0:chs1::
        sendByClipboard("acute cholecystitis",3)
    return
    :B0:lvpr::
        sendByClipboard("hypremic change of the surrounding liver parenchyma" A_EndChar,4)
    return
    :B0:aps::
        sendByClipboard("appendicitis" A_EndChar,3)
    return
    :*B0:aps1::
        sendByClipboard("acute appendicitis",3)
    return
    :B0:pas::
        sendByClipboard("pancreatitis" A_EndChar,3)
    return
    :*B0:pas1::
        sendByClipboard("acute pancreatitis",3)
    return
    :*B0:pas2::
        sendByClipboard("chronic pancreatitis",3)
    return
    :B0:djdl::
        sendByClipboard("degenerative change of lumbar spine" A_EndChar,4)
    return
    :B0:acol::
        sendByClipboard("ascending colon" A_EndChar,4)
    return
    :B0:tcol::
        sendByClipboard("transverse colon" A_EndChar,4)
    return
    :B0:dcol::
        sendByClipboard("descending colon" A_EndChar,4)
    return
    :B0:sigc::
        sendByClipboard("sigmoid colon" A_EndChar,4)
    return
    :B0:rect::
        sendByClipboard("rectum" A_EndChar,4)
    return
    :*B0:pro1::
        sendByClipboard("enlarged prostate with calcification.",3)
    return
    :*B0:pro2::
        sendByClipboard("enlarged prostate with nodular enhancement and calcification.",3)
    return
    :*B0:pro3::
        sendByClipboard("enlarged prostate with intravesical protrusion.",3)
    return
    :B0:ipp::
        sendByClipboard("intravesical protrusion" A_EndChar,3)
    return
    :B0:cr::
        sendByClipboard("cirrhosis" A_EndChar,2)
    return
    :*B0:cr1::
        sendByClipboard("cirrhotic change",2)
    return
    :*B0:cr0::
        sendByClipboard("Uneven surface and coarse architecture of liver, cirrhosis is considered.",2)
    return
    :B0:cct::
        sendByClipboard("cholecystectomy" A_EndChar,3)
    return
    :*B0:cct0::
        sendByClipboard("status post cholecystectomy with mild dilatation of bile ducts.",3)
    return
    :B0:cy::
        sendByClipboard("cyst" A_EndChar,2)
    return
    :*B0:cy1::
        sendByClipboard("cysts",2)
    return
    :B0:clg::
        sendByClipboard("cholangiocarcinoma" A_EndChar,3)
    return
    :B0:fl::
        sendByClipboard("fatty liver" A_EndChar,2)
    return
    :B0:ftc::
        sendByClipboard("fatty change" A_EndChar,3)
    return
    :B0:rc::
        sendByClipboard("renal cyst" A_EndChar,2)
    return
    :B0:rrc::
        sendByClipboard("right renal cyst" A_EndChar,3)
    return
    :B0:lrc::
        sendByClipboard("left renal cyst" A_EndChar,3)
    return
    :*B0:rc1::
        sendByClipboard("renal cysts",2)
    return
    :*B0:rrc1::
        sendByClipboard("right renal cysts",3)
    return
    :*B0:lrc1::
        sendByClipboard("left renal cysts",3)
    return
    :B0:hc::
        sendByClipboard("hepatic cyst" A_EndChar,2)
    return
    :*B0:hc1::
        sendByClipboard("hepatic cysts",2)
    return
    ;~ ::lrc::liver and renal cysts
    ;~ :*:rcy0::Bilateral renal cysts.
    :*B0:lc0::
        sendByClipboard("Multiple small cysts in both hepatic lobes.",2)
    return
    :*B0:lc1::
        sendByClipboard("liver cysts",2)
    return
    :*B0:rcy1::
        sendByClipboard("renal cysts",3)
    return
    :B0:sn::
        sendByClipboard("spleen" A_EndChar,2)
    return
    :*B0:sn1::
        sendByClipboard("splenic",2)
    return
    :*B0:snn::
        sendByClipboard("splenic nodule",2)
    return
    :*B0:snn1::
        sendByClipboard("splenic nodules",3)
    return
    :B0:hdn::
        sendByClipboard("hydronephrosis" A_EndChar,3)
    return
    :B0:smg::
        sendByClipboard("splenomegaly" A_EndChar,3)
    return
    :B0:hmg::
        sendByClipboard("hepatomegaly" A_EndChar,3)
    return
    :B0:hsmg::
        sendByClipboard("hepatosplenomegaly" A_EndChar,4)
    return
    :B0:acs::
        sendByClipboard("accessory spleen" A_EndChar,3)
    return
    :B0:lni::
        sendByClipboard("nonspecific lymph node(s) at bilateral inguinal areas." A_EndChar,3)
    return
    :B0:uph::
        sendByClipboard("urolithiasis or phlebolith" A_EndChar,3)
    return
    :B0:ul::
        sendByClipboard("urolithiasis" A_EndChar,2)
    return
    :B0:nhpd::
        sendByClipboard("normal hepatic perfusion defect" A_EndChar,4)
    return
    :*B0:nhpd0::
        sendByClipboard("normal hepatic perfusion defect at S4b adjacent to the fissure of the ligamentum teres.",4)
    return
    :B0:fm::
        sendByClipboard("fecal material" A_EndChar,2)
    return
    :B0:pba::
        sendByClipboard("pneumobilia" A_EndChar,3)
    return
    :B0:chila::
        sendByClipboard("Hepatodiaphragmatic interposition of the colon (Chilaiditi syndrome)." A_EndChar,5)
    return
    :B0:gev::
        sendByClipboard("gastroesophageal varices" A_EndChar,3)
    return
    :B0:gav::
        sendByClipboard("gastric varices" A_EndChar,3)
    return
    :B0:esv::
        sendByClipboard("esophageal varices" A_EndChar,3)
    return
    :B0:srs::
        sendByClipboard("splenorenal shunts" A_EndChar,3)
    return
    :B0:vrc::
        sendByClipboard("varices" A_EndChar,3)
    return
    :B0:ing::
        sendByClipboard("inguinal" A_EndChar,3)
    return
    :B0:inga::
        sendByClipboard("inguinal area" A_EndChar,4)
    return
    :B0:unc::
        sendByClipboard("uncinate process" A_EndChar,3)
    return
    :B0:ampv::
        sendByClipboard("Periampullary lesions can not be totally excluded by the CT or MR study." A_EndChar,4)
    return
    :B0:anc::
        sendByClipboard("acute necrotic collection" A_EndChar,3)
    return
    :B0:apfc::
        sendByClipboard("acute peripancreatic fluid collection" A_EndChar,4)
    return
    :B0:apn::
        sendByClipboard("acute pyelonephritis" A_EndChar,3)
    return
    :B0:apt::
        sendByClipboard("arterioportal shunt" A_EndChar,3)
    return
    :B0:apc::
        sendByClipboard("appendicolith" A_EndChar,3)
    return
    :*:apslv::
        {
            sendByClipboard("a small irregular nodule is noted at the , only identified in the arterial phase; a small arterioportal shunt is considered.")
            send % "^{left 15}"
        }
    return
    :*B0:brcy::
        sendByClipboard("Bartholin cyst",3)
    return
    :B0:biha::
        sendByClipboard("biliary hamartoma (von Meyenburg complex)" A_EndChar,4)
    return
    :B0:bnk1::
        sendByClipboard("Bosniak category 1 of renal cystic neosplasm is considered." A_EndChar,4)
    return
    :B0:bp0::
        sendByClipboard("The bile ducts and the pancreatic duct are not dilated." A_EndChar,3)
    return
    :B0:bti::
        sendByClipboard("biliary tract infection" A_EndChar,3)
    return
    :B0:bit::
        sendByClipboard("biliary tracts" A_EndChar,3)
    return
    :*B0:bit0::
        sendByClipboard("no definite filling defect in the biliary tracts.",3)
    return
    :B0:cvtr::
        sendByClipboard("cavernous transformation" A_EndChar,4)
    return
    :*B0:ciaa::
        sendByClipboard("common iliac artery",3)
    return
    :*B0:ciaa1::
        sendByClipboard("common iliac arteries",4)
    return
    :*B0:eiaa::
        sendByClipboard("external iliac artery",3)
    return
    :*B0:eiaa1::
        sendByClipboard("external iliac arteries",4)
    return
    :*B0:iiaa::
        sendByClipboard("internal iliac artery",3)
    return
    :*B0:iiaa1::
        sendByClipboard("internal iliac arteries",4)
    return
    :*B0:civv::
        sendByClipboard("common iliac vein",3)
    return
    :*B0:civv1::
        sendByClipboard("common iliac veins",4)
    return
    :*B0:eivv::
        sendByClipboard("external iliac vein",3)
    return
    :*B0:eivv1::
        sendByClipboard("external iliac veins",4)
    return
    :*B0:iivv::
        sendByClipboard("internal iliac vein",3)
    return
    :*B0:iivv1::
        sendByClipboard("internal iliac veins",4)
    return

    :B0:cnd::
        sendByClipboard("cirrhotic nodule" A_EndChar,3)
    return
    :*B0:crn1::
        sendByClipboard("cirrhotic nodules",3)
    return
    :B0:dnd::
        sendByClipboard("dysplastic nodule" A_EndChar,3)
    return
    :*B0:dnd1::
        sendByClipboard("dysplastic nodules",3)
    return
    :B0:rnd::
        sendByClipboard("regenerative nodule" A_EndChar,3)
    return
    :*B0:rnd1::
        sendByClipboard("regenerative nodules",3)
    return
    :B0:pts::
        sendByClipboard("peritonitis" A_EndChar,3)
    return
    :B0:crt::
        sendByClipboard("capsular retraction" A_EndChar,3)
    return
    :B0:wav::
        sendByClipboard("washout on venous phase" A_EndChar,3)
    return
    :*B0:hcc0::
        sendByClipboard("hypodense lesion on precontrast, hyperdensity on arterial phase and rapid washout on venous phase; compatible with typical HCC.",3)
    return
    :*B0:hem0::
        sendByClipboard("hypodense lesion on precontrast, peripheral dot-like enhancement on arterial phase, and progressive filling-in on venous phase; compatible with liver hemangioma.",3)
    return
    :*B0:hem1::
        sendByClipboard("isodense lesion on precontrast, global enhancement on arterial phase, and persistent enhancement on venous phase; compatible with liver hemangioma.",3)
    return
    :*B0:ctap0::
        sendByClipboard("CTAP was performed with tip in the SMA orifice, 2ml/sec, delayed 30 sec, total 50 ml:",4)
    return
    :B0:ctss::
        sendByClipboard("(Non-enhanced CT study is not sensitive and specific for the detection of focal lesions in the abdominal organs)" A_EndChar,4)
    return
    :B0:ctst::
        sendByClipboard("NECT and CECT of abdomen and pelvis with air and water distention of the stomach for evaluation:" A_EndChar,4)
    return
    :B0:ctco::
        sendByClipboard("NECT and CECT of abdomen and pelvis for colon cancer with air distention:" A_EndChar,4)
    return
    :B0:dud::
        sendByClipboard("duodenal diverticulum." A_EndChar,3)
    return
    :B0:fra::
        sendByClipboard("free air" A_EndChar,3)
    return
    :B0:ety::
        sendByClipboard("enterostomy" A_EndChar,3)
    return
    ;~ ::pys::pyelonephritis
    :B0:sep::
        sendByClipboard("sclerosing encapsulating peritonitis" A_EndChar,3)
    return
    ;~ ::fcl::falciform ligament
    :*B0:mrfl::
        sendByClipboard("Heterogeneous decreased signal of the liver on out-of-phase images as compared with in-phase images, suggestive of fatty liver.",3)
    return
    :B0:fga::
        sendByClipboard("focal type of the gallbladder adenomyomatosis" A_EndChar,3)
    return
    :B0:gc::
        sendByClipboard("greater curvature" A_EndChar,2)
    return
    :B0:lc::
        sendByClipboard("lesser curvature" A_EndChar,2)
    return
    :B0:gcs::
        sendByClipboard("greater curvature side" A_EndChar,3)
    return
    :B0:lcs::
        sendByClipboard("lesser curvature side" A_EndChar,3)
    return
    ;~ ::ggb::Gamna-Gandy bodies (splenic siderotic nodules)
    :B0:ghll::
        sendByClipboard("gastrohepatic ligament" A_EndChar,4)
    return
    :B0:hmc::
        sendByClipboard("hemorrhagic cyst" A_EndChar,3)
    return
    :B0:hdll::
        sendByClipboard("hepatoduodenal ligament" A_EndChar,4)
    return
    :B0:hfx::
        sendByClipboard("hepatic flexure" A_EndChar,3)
    return
    :B0:sfx::
        sendByClipboard("splenic flexure" A_EndChar,3)
    return
    :B0:hhl::
        sendByClipboard("hepatic hilum" A_EndChar,3)
    return
    :B0:owrs::
        sendByClipboard("Osler-Weber-Rendu syndrome" A_EndChar,4)
    return
    :B0:htu::
        sendByClipboard("hepatic tumor" A_EndChar,3)
    return
    :*B0:htu1::
        sendByClipboard("hepatic tumors",3)
    return
    :*B0:hv0::
        sendByClipboard("Hepatic veins and portal veins are patent.",2)
    return
    ;~ :c:iac::interaortocaval region
    ;~ :c:Iac::Interaortocaval region
    :B0:itpi::
        sendByClipboard("status post intrathecal pump implantation" A_EndChar,4)
    return
    :B0:jjy::
        sendByClipboard("jejunostomy" A_EndChar,3)
    return
    :B0:ily::
        sendByClipboard("ileostomy" A_EndChar,3)
    return
    :B0:cny::
        sendByClipboard("colostomy" A_EndChar,3)
    return
    :B0:amll::
        sendByClipboard("angiomyolipoma" A_EndChar,4)
    return
    :B0:lsg::
        sendByClipboard("lateral segment" A_EndChar,3)
    return
    :B0:msg::
        sendByClipboard("medial segment" A_EndChar,3)
    return
    :B0:crsm::
        sendByClipboard("cirrhosis with splenomegaly" A_EndChar,4)
    return
    :B0:lcy::
        sendByClipboard("Multiple small low density nodules are noted in the liver; liver cysts are considered in current status." A_EndChar,3)
    return
    :*B0:lcy1::
        sendByClipboard("A small low density nodule in the liver; liver cyst is considered in current status.",3)
    return
    :B0:hon::
        sendByClipboard("hypodense nodule" A_EndChar,3)
    return
    :*B0:hon1::
        sendByClipboard("hypodense nodules",3)
    return
    :*B0:lrst::
        sendByClipboard("left renal stone",3)
    return
    :*B0:lrss::
        sendByClipboard("left renal stones",3)
    return
    :*B0:rrss::
        sendByClipboard("right renal stones",3)
    return
    :*B0:rrst::
        sendByClipboard("right renal stone",3)
    return

    :B0:rne::
        sendByClipboard("renal stone" A_EndChar,3)
    return
    :*B0:rne1::
        sendByClipboard("renal stones",3)
    return
    :B0:ne::
        sendByClipboard("stone" A_EndChar,2)
    return
    :*B0:ne1::
        sendByClipboard("stones",2)
    return

    :*B0:brst::
        sendByClipboard("bilateral renal stones",3)
    return
    :*B0:mrcp0::
        sendByClipboard("MRCP reveals no evidence of bile ducts or pancreatic duct dilatation; no anomalous pancreaticobiliary union.",4)
    return
    :*B0:mrcn::
        sendByClipboard("Cirrhotic nodules in both lobes of liver, mixed with regenerative nodules and dysplastic nodules, presenting as hyperintensity on T1WI, hypointensity on T2WI, and no enhancement.",3)
    return
    :*B0:mrdn::
        sendByClipboard("with increased hyperintensity on T1WI, isointensity to hypointensity on T2WI and no definite enhancement after contrast media injection; dysplastic nodules are favored.",3)
    return
    :*B0:mrfnh::
        sendByClipboard("slight hypointensity on T1WI, slight hyperintensity on T2WI, and global enhancement on early arterial phase, near isointensity on delayed enhanced images; compatible with FNH.",4)
    return
    :*B0:mrhcc::
        sendByClipboard("hypointensity on T1WI, slight hyperintensity on T2WI, and global enhancement on early arterial phase, rapid washout on delayed enhanced images; compatible with HCC.",4)
    return
    :*B0:mrhem::
        sendByClipboard("hypointensity on T1WI, hyperintensity on T2WI, and peripheral patches enhancement on dynamic contrast-enhanced study, persistent enhancement on delayed contrast-enhanced images; compatible with liver hemangioma.",4)
    return
    :*B0:mrprca::
        sendByClipboard("with hypointensity on T2WI, diffusion restriction on DWI/ADC, and early enhancement in early dynamic study; compatible with prostate cancer.",5)
    return
    :B0:umy::
        sendByClipboard("uterine myoma" A_EndChar,3)
    return
    :B0:uma::
        sendByClipboard("uterine mass" A_EndChar,3)
    return
    :*B0:uma1::
        sendByClipboard("uterine masses",3)
    return
    :B0:utn::
        sendByClipboard("uterine nodule" A_EndChar,3)
    return
    :*B0:utn1::
        sendByClipboard("uterine nodules",3)
    return
    :B0:utr::
        sendByClipboard("uterus" A_EndChar,3)
    return
    :*B0:utr1::
        sendByClipboard("uterine",3)
    return

    :B0:umx::
        sendByClipboard("uterine mass(es) and bilateral adnexal cystic lesions" A_EndChar,3)
    return
    :B0:net::
        sendByClipboard("neuroendocrine tumor" A_EndChar,3)
    return
    :B0:nfla::
        sendByClipboard("no definite focal lesion in the abdomen." A_EndChar,4)
    return
    :B0:nflp::
        sendByClipboard("no definite focal lesion in the pelvis." A_EndChar,4)
    return
    :B0:ncl::
        sendByClipboard("nodular and contracted liver contour" A_EndChar,3)
    return
    :B0:notae::
        sendByClipboard("The imaging pattern hints the limited effect of embolization and increased/aggravated liver cirrhosis if embolization; clinical follow up or local treatment is more favored. Liver transplantation is also considered." A_EndChar,5)
    return
    :B0:oble::
        sendByClipboard("obstructive level" A_EndChar,4)
    return
    :B0:opcolon::
        sendByClipboard("operative change of the colon; no evidence of local recurrence is noted; non-specific bowel gas distribution is noted." A_EndChar,7)
    return
    :B0:opgyn::
        sendByClipboard("status post operative change of the gynecological organs; no evidence of local recurrence is noted." A_EndChar,5)
    return
    :B0:opkidney::
        sendByClipboard("operative change of the kidney; no evidence of local recurrence is noted;" A_EndChar,8)
    return
    :B0:opstomach::
        sendByClipboard("operative change of the stomach; no evidence of local recurrence is noted; non-specific bowel gas distribution is noted." A_EndChar,9)
    return
    :B0:paa::
        sendByClipboard("porcelain abdominal aorta" A_EndChar,3)
    return
    :B0:pcs::
        sendByClipboard("portocaval space" A_EndChar,3)
    return
    :B0:phs::
        sendByClipboard("perihepatic space" A_EndChar,3)
    return
    :B0:pnin::
        sendByClipboard("pneumatosis intestinalis" A_EndChar,4)
    return
    :B0:pjsy::
        sendByClipboard("Peutz-Jeghers syndrome" A_EndChar,4)
    return
    :B0:pmf::
        sendByClipboard("peripheral mass-forming type of cholangiocarcinoma" A_EndChar,3)
    return
    :B0:primo::
        sendByClipboard(" Primovist MR study may be considered in next followed study (liver specific MR contrast medium; specially arranged; please call MR room 62540 for arrangement; or Dr. A 51685 or Dr. B 53315)." A_EndChar,5)
    return
    :B0:psco::
        sendByClipboard("phlebosclerotic colitis" A_EndChar,4)
    return
    :B0:pv::
        sendByClipboard("portal vein" A_EndChar,2)
    return
    :B0:pvt::
        sendByClipboard("portal vein thrombosis" A_EndChar,3)
    return
    :B0:cz::
        sendByClipboard("central zone" A_EndChar,2)
    return
    :B0:tz::
        sendByClipboard("transitional zone" A_EndChar,2)
    return
    :B0:pz::
        sendByClipboard("peripheral zone" A_EndChar,2)
    return
    :B0:sa1::
        sendByClipboard("Study: monophasic abdominal CT, without contrast enhancement" A_EndChar,3)
    return
    :B0:sa2::
        sendByClipboard("Study: 2 phases of abdominal CT, without and with contrast enhancement" A_EndChar,3)
    return
    :B0:sa3::
        sendByClipboard("Study: 3 phases of abdominal CT, without and with (arterial and portal venous phases) contrast enhancement" A_EndChar,3)
    return
    :B0:sa4::
        sendByClipboard("Study: 4 phases of abdominal CT, without and with (arterial and portal venous and delayed phases) contrast enhancement" A_EndChar,3)
    return
    :B0:co::
        sendByClipboard("colon" A_EndChar,2)
    return
    :B0:sb::
        sendByClipboard("small bowels" A_EndChar,2)
    return
    :B0:sbo::
        sendByClipboard("small bowel obstruction" A_EndChar,3)
    return
    :B0:sbtae::
        sendByClipboard("The small bowel embolization is still a risky issue and the long-term follow-up evidence is still scant. Possible short term and long term of complications (perforation, stenosis, etc.) should be followed and alerted." A_EndChar,5)
    return
    :B0:sbt::
        sendByClipboard("Sengstaken-Blakemore tube" A_EndChar,3)
    return
    :B0:bgh::
        sendByClipboard("Brunner gland hyperplasia" A_EndChar,3)
    return
    :B0:seml::
        sendByClipboard("subepithelial mass lesion" A_EndChar,4)
    return
    :B0:sml::
        sendByClipboard("submucosal lesion" A_EndChar,3)
    return
    :B0:sfci::
        sendByClipboard("suprapubic foley catheter insertion" A_EndChar,4)
    return
    :B0:stece::
        sendByClipboard("suspected stenosis of the celiac axis and IMA with dilated arc of Buhler, arc of Riolan, and marginal artery of Drummond." A_EndChar,5)
    return
    :B0:seve::
        sendByClipboard("seminal vesicle" A_EndChar,4)
    return
    :B0:thad::
        sendByClipboard("THAD (transient hepatic attenuation differences)" A_EndChar,4)
    return
    :B0:tei::
        sendByClipboard("terminal ileum" A_EndChar,3)
    return
    :B0:tnmrec::
        sendByClipboard("
(
Rectal cancer: distal rectum.
---T: T3, abnormal thickening and enhancing wall with increased fatty strandings in the perirectal space.
---N: N1c, small LNs in the perirectal space; there is no evidence of paraaortic LAPs in abdomen; there is no evidence of LAPs in pelvic cavity and bilateral inguinal areas.
---M: M0, multiple liver cysts; no definite mets; but slightly increased fatty strandings in the omentum should be followed.
---The local staging is favored as cT3N1cM0.
)")
        sendByClipboard(a_endchar)
    return
    :B0:tnmkd::
        sendByClipboard("
(
Renal cancer: right kidney.
---T: T1b, right kidney; a well-defined renal mass 46.3 mm is noted at the right kidney without definite fat density or calcifications; the tumor is solid but heterogeneous enhancement; the pattern should exclude the RCC (such as chromophobe type) first; the differential diagnosis includes the fat-paucity of renal angiomyolipoma. Accorrding the imaging pattern, partial or total nephrectomy is first considered even though the AML is differentiated.
---N: N0, no regional LNs.
---M: M0, no definite distant metastases.
---The local staging is favored as cT3N1cM0.
)")
        sendByClipboard(a_endchar)
    return
    :B0:tnmsto::
        sendByClipboard("
(
---T: T3, abnormal thickening and enhancing wall with increased fatty strandings;
---N: N2, small LNs (3-6) in the regional areas and lesser omentum;
---M: M0, no definite metastases in the abdomen;
---The local staging is favored as cT3N2M0.
)")
        sendByClipboard(a_endchar)
    return
    :*B0:smcy::
        sendByClipboard("The size of cysts is too small to be differentiated. Clinical follow-up or correlation is suggested.",3)
    return
    :B0:uca::
        sendByClipboard("uterine cavity" A_EndChar,3)
    return
    :B0:ur::
        sendByClipboard("ureter" A_EndChar,2)
    return
    :*B0:lush::
        sendByClipboard("left ureter stone causing hydronephrosis",3)
    return
    :*B0:rush::
        sendByClipboard("right ureter stone causing hydronephrosis",3)
    return
    :*B0:bush::
        sendByClipboard("bilateral ureter stones causing hydronephrosis",3)
    return
    :*B0:ur1::
        sendByClipboard("ureteral",2)
    return
    :B0:urs::
        sendByClipboard("ureter stone" A_EndChar,3)
    return
    :*B0:urs1::
        sendByClipboard("ureter stones",3)
    return
    :*B0:utii::
        sendByClipboard("urinary tract infection",3)
    return
    :B0:vcugg::
        sendByClipboard("voiding cystourethrography" A_EndChar,5)
    return
    :B0:iab::
        sendByClipboard("intraabdominal" A_EndChar,3)
    return
    :*:ivu0::
        insertTemplate("
(
KUB and IVU shows:
- Bilateral clear psoas shadows.
- Bilateral functioning kidneys with normal size, shape and axis.
- Bilateral normal collecting system without definite filling defect or obstruction.
- Well-distended urinary bladder with smooth contour.
- Phlebolith at pelvic cavity.
- The postvoiding film reveals small residual urine.

The lateral film reveals marked indentation on the bladder floor. There is also hooking of bilateral ureters on the delayed films. All of these pictures are compatible with enlarged prostate gland.
)","
(
No evidence of obstructive uropathy.
)")
    return

    insertTemplate(finding, impression){
        global editHwnds, RisReports, thisPlace

        if InStr(thisPlace, "N hospital"){
            gosub renewReportHwnd
            str1:=RegExReplace(finding, "\r?\n","`r`n")
                ,str2:=RegExReplace(impression, "\r?\n","`r`n")
                ;~ ,changeLineBreak(str1)
                ;~ ,changeLineBreak(str2)
                ,Edit_SetText(editHwnds[2], str1)
                ,Edit_SetText(editHwnds[1], str1)
                ,Edit_SetText(RisReports[1,1], str1)
                ,Edit_SetText(RisReports[1,2], str2)
        }else{
            sendByClipboard(trim(finding) "`n`nImpression: `n" impression)
        }

    }

    ;chest
    :B0:opl::
        sendByClipboard("post-operative changes of lung." A_EndChar,3)
    return
    :*B0:blggo::
        sendByClipboard("which could be insufficient inspiration or pulmonary infection.",4)
    return

    :B0:sili::
        sendByClipboard("silicone granulomas" A_EndChar,4)
    return

    :*B0:hr0::
        sendByClipboard("no obvious structural cardiac abnormality.",2)
    return

    :B0:ldm::
        sendByClipboard("left deviation of mediastinal structures" A_EndChar,3)
    return
    :B0:rdm::
        sendByClipboard("right deviation of mediastinal structures" A_EndChar,3)
    return
    :*B0:hpec::
        sendByClipboard("hemopericardium",3)
    return
    :B0:htx::
        sendByClipboard("hemothorax" A_EndChar,3)
    return
    :B0:cry::
        sendByClipboard("coronary" A_EndChar,3)
    return
    :*B0:crst::
        sendByClipboard("coronary stent",3)
    return
    :*B0:crst1::
        sendByClipboard("coronary stents",4)
    return
    :B0:put::
        sendByClipboard("pulmonary trunk" A_EndChar,3)
    return
    :B0:mpa::
        sendByClipboard("main pulmonary artery" A_EndChar,3)
    return
    :B0:lpa::
        sendByClipboard("left pulmonary artery" A_EndChar,3)
    return
    :B0:rpa::
        sendByClipboard("right pulmonary artery" A_EndChar,3)
    return
    :*B0:lpa1::
        sendByClipboard("left pulmonary arteries",3)
    return
    :*B0:rpa1::
        sendByClipboard("right pulmonary arteries",3)
    return

    :*B0:lucn::
        sendByClipboard("lung cancer",3)
    return
    :*B0:rlca::
        sendByClipboard("right lung cancer",3)
    return
    :*B0:llca::
        sendByClipboard("left lung cancer",3)
    return
    :*B0:escn::
        sendByClipboard("esophageal cancer",3)
    return
    :*B0:brcn::
        sendByClipboard("breast cancer",3)
    return
    :*B0:lbca::
        sendByClipboard("left breast cancer",3)
    return
    :*B0:rbca::
        sendByClipboard("right breast cancer",3)
    return

    :B0:ite::
        sendByClipboard("intrathoracic extension" A_EndChar,3)
    return
    :B0:mim::
        sendByClipboard("mucus impaction" A_EndChar,3)
    return
    :B0:mpg::
        sendByClipboard("mucus plug" A_EndChar,3)
    return
    :*B0:mpg1::
        sendByClipboard("mucus plugs",3)
    return
    :B0:enb::
        sendByClipboard("endobronchial" A_EndChar,3)
    return
    :B0:bks::
        sendByClipboard("bronchiectasis, peribronchial tiny (<6mm) nodules and bronchial wall thickening" A_EndChar,3)
    return
    ;~ ::pfd::perifissural nodule
    ;~ :*:pfd1::perifissural nodules
    :B0:pfd::
        sendByClipboard("juxtapleural nodule" A_EndChar,3)
    return
    :*B0:pfd1::
        sendByClipboard("juxtapleural nodules",3)
    return
    :B0:bwt::
        sendByClipboard("bronchial wall thickening" A_EndChar,3)
    return
    :B0:pls::
        sendByClipboard("pleural seedings" A_EndChar,3)
    return
    :B0:plm::
        sendByClipboard("pleural metastasis" A_EndChar,3)
    return
    :*B0:plm1::
        sendByClipboard("pleural metastases",3)
    return
    :B0:blm::
        sendByClipboard("bilateral lung metastases" A_EndChar,3)
    return
    :*B0:blml::
        sendByClipboard("bilateral lung metastases, larger.",3)
    return
    :*B0:blms::
        sendByClipboard("bilateral lung metastases, smaller.",3)
    return
    :B0:lbm::
        sendByClipboard("bilateral lung and bone metastases." A_EndChar,3)
    return
    :*B0:blpm::
        sendByClipboard("bilateral lung, pleural and bone metastases.",3)
    return
    :*B0:rulb::
        sendByClipboard("RUL lobectomy",3)
    return
    :*B0:rmlb::
        sendByClipboard("RML lobectomy",3)
    return
    :*B0:rllb::
        sendByClipboard("RLL lobectomy",3)
    return
    :*B0:lulb::
        sendByClipboard("LUL lobectomy",3)
    return
    :*B0:lllb::
        sendByClipboard("LLL lobectomy",3)
    return
    :*B0:ruls::
        sendByClipboard("RUL segmentectomy",3)
    return
    :*B0:rmls::
        sendByClipboard("RML segmentectomy",3)
    return
    :*B0:rlls::
        sendByClipboard("RLL segmentectomy",3)
    return
    :*B0:luls::
        sendByClipboard("LUL segmentectomy",3)
    return
    :*B0:llls::
        sendByClipboard("LLL segmentectomy",3)
    return
    :*B0:rulw::
        sendByClipboard("RUL wedge resection",3)
    return
    :*B0:rmlw::
        sendByClipboard("RML wedge resection",3)
    return
    :*B0:rllw::
        sendByClipboard("RLL wedge resection",3)
    return
    :*B0:lulw::
        sendByClipboard("LUL wedge resection",3)
    return
    :*B0:lllw::
        sendByClipboard("LLL wedge resection",3)
    return

    :B0:blc::
        sendByClipboard("bilateral lung consolidation" A_EndChar,3)
    return
    :B0:blo::
        sendByClipboard("bilateral lung opacities" A_EndChar,3)
    return
    :B0:rmi::
        sendByClipboard("status post right mastectomy with breast implant." A_EndChar,3)
    return
    :B0:lmi::
        sendByClipboard("status post left mastectomy with breast implant." A_EndChar,3)
    return
    :B0:bmi::
        sendByClipboard("status post bilateral mastectomy with breast implant." A_EndChar,3)
    return
    :*B0:rtrm::
        sendByClipboard("post-radiation change at right medial lung.",3)
    return
    :*B0:rtlm::
        sendByClipboard("post-radiation change at left medial lung.",3)
    return
    :*B0:rtbm::
        sendByClipboard("post-radiation change at bilateral medial lung.",3)
    return
    :B0:stf::
        sendByClipboard("unchanged thoracic findings." A_EndChar,3)
    return
    :B0:sf::
        sendByClipboard("unchanged findings." A_EndChar,2)
    return
    :B0:osf::
        sendByClipboard("other unchanged findings." A_EndChar,3)
    return
    :B0:rsf::
        sendByClipboard("roughly unchanged findings." A_EndChar,3)
    return
    :B0:bln::
        sendByClipboard("bilateral lung nodules" A_EndChar,3)
    return
    :B0:tbln::
        sendByClipboard("tiny bilateral lung nodules" A_EndChar,4)
    return
    :*B0:tblns::
        sendByClipboard("tiny bilateral lung nodules, unchanged.",4)
    return
    :B0:tln::
        sendByClipboard("tiny lung nodules" A_EndChar,3)
    return
    :*B0:tlns::
        sendByClipboard("tiny lung nodules, unchanged.",3)
    return
    :B0:lns::
        sendByClipboard("lung nodules, unchanged." A_EndChar,3)
    return
    :B0:psn::
        sendByClipboard("part-solid nodule" A_EndChar,3)
    return
    :B0:ssl::
        sendByClipboard("sub-solid nodule" A_EndChar,3)
    return
    :*B0:segt::
        sendByClipboard("segmentectomy",3)
    return
    :*B0:pnut::
        sendByClipboard("pneumectomy",3)
    return
    :*B0:ldct/::
        sendByClipboard("(Low dose CT is incompetent for soft tissue lesion detection.)",4)
    return
    :B0:tpm::
        sendByClipboard("temporary pacemaker" A_EndChar,3)
    return
    :B0:tef::
        sendByClipboard("tracheoesophageal fistula" A_EndChar,3)
    return
    :*B0:lbrc::
        sendByClipboard("left breast cancer",3)
    return
    :*B0:rbrc::
        sendByClipboard("right breast cancer",3)
    return
    :B0:lbr::
        sendByClipboard("left breast" A_EndChar,3)
    return
    :B0:rbr::
        sendByClipboard("right breast" A_EndChar,3)
    return
    :B0:bbr::
        sendByClipboard("bilateral breasts" A_EndChar,3)
    return
    :B0:lcw::
        sendByClipboard("lateral chest wall" A_EndChar,3)
    return
    :B0:acw::
        sendByClipboard("anterior chest wall" A_EndChar,3)
    return
    :B0:rbn::
        sendByClipboard("right breast nodule" A_EndChar,3)
    return
    :B0:lbn::
        sendByClipboard("left breast nodule" A_EndChar,3)
    return
    :B0:bbn::
        sendByClipboard("bilateral breast nodules" A_EndChar,3)
    return
    :B0:rbc::
        sendByClipboard("right breast calcification(s)" A_EndChar,3)
    return
    :B0:lbc::
        sendByClipboard("left breast calcification(s)" A_EndChar,3)
    return
    :B0:bbc::
        sendByClipboard("bilateral breast calcifications" A_EndChar,3)
    return
    :B0:brc::
        sendByClipboard("breast calcification" A_EndChar,3)
    return
    :*B0:brc1::
        sendByClipboard("breast calcifications",3)
    return
    :B0:brn::
        sendByClipboard("breast nodule" A_EndChar,3)
    return
    :*B0:brn1::
        sendByClipboard("breast nodules",3)
    return
    :B0:bim::
        sendByClipboard("breast implant" A_EndChar,3)
    return
    :*B0:bim1::
        sendByClipboard("breast implants",3)
    return

    :B0:apw::
        sendByClipboard("aortopulmonary window" A_EndChar,3)
    return
    :B0:hnx::
        sendByClipboard("hydropneumothorax" A_EndChar,3)
    return
    :B0:slf::
        sendByClipboard("unchanged lung findings." A_EndChar,3)
    return
    :B0:llu::
        sendByClipboard("left lung" A_EndChar,3)
    return
    :B0:rlu::
        sendByClipboard("right lung" A_EndChar,3)
    return
    :B0:blu::
        sendByClipboard("bilateral lungs" A_EndChar,3)
    return
    :B0:plu::
        sendByClipboard("pleura" A_EndChar,3)
    return
    :B0:plb::
        sendByClipboard("pleura-based" A_EndChar,3)
    return
    :B0:moz::
        sendByClipboard("mosaic attenuation" A_EndChar,3)
    return
    :B0:thc::
        sendByClipboard("thoracic" A_EndChar,3)
    return
    :B0:ido::
        sendByClipboard("ill-defined opacities" A_EndChar,3)
    return
    :*B0:lmet::
        sendByClipboard("Multiple bilateral lung nodules of varying sizes, suggestive of metastases",3)
    return
    :B0:ip::
        sendByClipboard("interstitial pneumonitis" A_EndChar,2)
    return
    :B0:hnc::
        sendByClipboard("honeycombing" A_EndChar,3)
    return

    :B0:cvr::
        sendByClipboard("status post cardiac valve replacement." A_EndChar,3)
    return
    ;~ :*:card::cardiac
    ;~ ::cdv::cardiac valve
    ;~ :*:cdv1::cardiac valves
    :B0:prh::
        sendByClipboard("perihilar" A_EndChar,3)
    return
    :B0:avv::
        sendByClipboard("aortic valve" A_EndChar,3)
    return
    :B0:pvv::
        sendByClipboard("pulmonary valve" A_EndChar,3)
    return
    :B0:mvv::
        sendByClipboard("mitral valve" A_EndChar,3)
    return
    :B0:tvv::
        sendByClipboard("tricuspid valve" A_EndChar,3)
    return
    :B0:vv::
        sendByClipboard("valve" A_EndChar,2)
    return
    :*B0:vv1::
        sendByClipboard("valves",2)
    return
    :B0:cvv::
        sendByClipboard("cardiac valve" A_EndChar,3)
    return
    :*B0:cvv1::
        sendByClipboard("cardiac valves",3)
    return
    :B0:mbn::
        sendByClipboard("multiple bilateral lung nodules" A_EndChar,3)
    return
    :B0:plr::
        sendByClipboard("pleural retraction" A_EndChar,3)
    return
    :B0:ibl::
        sendByClipboard("in bilateral lungs" A_EndChar,3)
    return
    :B0:irl::
        sendByClipboard("in the right lung" A_EndChar,3)
    return
    :B0:ill::
        sendByClipboard("in the left lung" A_EndChar,3)
    return
    :B0:ral::
        sendByClipboard("right apical lung" A_EndChar,3)
    return
    :B0:lal::
        sendByClipboard("left apical lung" A_EndChar,3)
    return
    :*B0:iral::
        sendByClipboard("at right apical lung",3)
    return
    :*B0:ilal::
        sendByClipboard("at left apical lung",3)
    return
    :B0:ith::
        sendByClipboard("interstitial thickening" A_EndChar,3)
    return
    :B0:chw::
        sendByClipboard("chest wall" A_EndChar,3)
    return
    :B0:scr::
        sendByClipboard("subcarinal" A_EndChar,3)
    return
    :B0:pbk::
        sendByClipboard("peribronchial" A_EndChar,3)
    return
    :B0:pbt::
        sendByClipboard("peribronchial thickening" A_EndChar,3)
    return
    :B0:ptk::
        sendByClipboard("paratracheal" A_EndChar,3)
    return
    :B0:peo::
        sendByClipboard("paraesophageal" A_EndChar,3)
    return
    :*B0:ggos::
        sendByClipboard("GGOs",3)
    return
    :*B0:mggo::
        sendByClipboard("multiple GGOs",3)
    return
    :B0:ilg::
        sendByClipboard("ill-defined GGO" A_EndChar,3)
    return
    :*B0:ilg1::
        sendByClipboard("ill-defined GGOs",3)
    return
    :*B0:milg::
        sendByClipboard("multiple ill-defined GGOs",3)
    return
    :*B0:ggns::
        sendByClipboard("GGNs",3)
    return
    :*B0:mggn::
        sendByClipboard("multiple GGNs",3)
    return
    :B0:ggo::
        sendByClipboard("GGO" A_EndChar,3)
    return
    :B0:ggn::
        sendByClipboard("GGN" A_EndChar,3)
    return
    :B0:rml::
        sendByClipboard("RML" A_EndChar,3)
    return
    :B0:rul::
        sendByClipboard("RUL" A_EndChar,3)
    return
    :B0:rll::
        sendByClipboard("RLL" A_EndChar,3)
    return
    :B0:lul::
        sendByClipboard("LUL" A_EndChar,3)
    return
    :B0:lll::
        sendByClipboard("LLL" A_EndChar,3)
    return
    :*B0:irml::
        sendByClipboard("in the RML",3)
    return
    :*B0:irul::
        sendByClipboard("in the RUL",3)
    return
    :*B0:irll::
        sendByClipboard("in the RLL",3)
    return
    :*B0:ilul::
        sendByClipboard("in the LUL",3)
    return
    :*B0:illl::
        sendByClipboard("in the LLL",3)
    return
    :*B0:ilin::
        sendByClipboard("at the lingular LUL",3)
    return
    :B0:lnl::
        sendByClipboard("lung nodule" A_EndChar,3)
    return
    :B0:brll::
        sendByClipboard("basal RLL" A_EndChar,4)
    return
    :B0:blll::
        sendByClipboard("basal LLL" A_EndChar,4)
    return
    :B0:tln::
        sendByClipboard("tiny lung nodule." A_EndChar,3)
    return
    :*B0:tln1::
        sendByClipboard("tiny lung nodules.",3)
    return
    :*B0:lnl1::
        sendByClipboard("lung nodules",3)
    return
    :*B0:nd0::
        sendByClipboard("other tiny or probably non-specific lung nodules and minor or non-specific parenchymal changes of bilateral lung, suggest clinical correlation.",2)
    return
    :B0:aos::
        sendByClipboard("acute aortic syndrome" A_EndChar,3)
    return
    :B0:brk::
        sendByClipboard("bronchus" A_EndChar,3)
    return
    :*B0:brk1::
        sendByClipboard("bronchial",3)
    return
    :*B0:brk2::
        sendByClipboard("bronchi",3)
    return
    :B0:lmb::
        sendByClipboard("left main bronchus" A_EndChar,3)
    return
    :B0:rmb::
        sendByClipboard("right main bronchus" A_EndChar,3)
    return
    :B0:tib::
        sendByClipboard("tree-in-bud" A_EndChar,3)
    return
    :B0:tin::
        sendByClipboard("tree-in-bud nodules" A_EndChar,3)
    return
    :B0:ttn::
        sendByClipboard("tiny (<=4mm) tree-in-bud nodules" A_EndChar,3)
    return
    :B0:rma::
        sendByClipboard("respiratory motion artifacts" A_EndChar,3)
    return
    :*B0:rma0::
        sendByClipboard("respiratory motion artifacts are noted, which may obscure small lesions.",3)
    return
    :B0:bpe::
        sendByClipboard("bilateral pleural effusion" A_EndChar,3)
    return
    :B0:rpe::
        sendByClipboard("right pleural effusion" A_EndChar,3)
    return
    :B0:lpe::
        sendByClipboard("left pleural effusion" A_EndChar,3)
    return
    :*B0:lpet::
        sendByClipboard("left pleural effusion with pleural thickening",3)
    return
    :*B0:rpet::
        sendByClipboard("right pleural effusion with pleural thickening",3)
    return
    :*B0:bpet::
        sendByClipboard("bilateral pleural effusion with pleural thickening",3)
    return
    :B0:pfl::
        sendByClipboard("previous fracture at left rib(s)." A_EndChar,3)
    return
    :B0:pfr::
        sendByClipboard("previous fracture at right rib(s)." A_EndChar,3)
    return
    :B0:pflc::
        sendByClipboard("previous fracture at left rib(s) and left clavicle." A_EndChar,4)
    return
    :B0:pfrc::
        sendByClipboard("previous fracture at right rib(s) and right clavicle." A_EndChar,4)
    return
    :B0:pfb::
        sendByClipboard("previous fractures at bilateral ribs." A_EndChar,3)
    return

    :B0:bll::
        sendByClipboard("bilateral lower lungs" A_EndChar,3)
    return
    :B0:bul::
        sendByClipboard("bilateral upper lungs" A_EndChar,3)
    return
    :B0:bal::
        sendByClipboard("bilateral apical lungs" A_EndChar,3)
    return
    :B0:bml::
        sendByClipboard("RML and lingular LUL" A_EndChar,3)
    return
    :B0:em::
        sendByClipboard("emphysema" A_EndChar,2)
    return
    ;~ ::prf::perifissural
    :B0:prf::
        sendByClipboard("juxtapleural" A_EndChar,3)
    return
    :B0:arsa::
        sendByClipboard("aberrant right subclavian artery" A_EndChar,4)
    return
    :B0:alsa::
        sendByClipboard("aberrant left subclavian artery" A_EndChar,4)
    return
    :B0:br::
        sendByClipboard("breast" A_EndChar,2)
    return
    :*B0:br1::
        sendByClipboard("breasts",2)
    return
    :B0:fs::
        sendByClipboard("fissure" A_EndChar,2)
    return
    :*B0:fs1::
        sendByClipboard("fissures",2)
    return
    :*B0:fs2::
        sendByClipboard("fissural",2)
    return

    :B0:mjf::
        sendByClipboard("major fissure" A_EndChar,3)
    return
    :B0:mif::
        sendByClipboard("minor fissure" A_EndChar,3)
    return

    :B0:axi::
        sendByClipboard("axillary" A_EndChar,3)
    return
    :B0:pco::
        sendByClipboard("patchy consolidation" A_EndChar,3)
    return
    :*B0:pco1::
        sendByClipboard("patchy consolidations",3)
    return
    :B0:aoa::
        sendByClipboard("aortic arch" A_EndChar,3)
    return
    :B0:ata::
        sendByClipboard("ascending aorta" A_EndChar,3)
    return
    :B0:dta::
        sendByClipboard("descending thoracic aorta" A_EndChar,3)
    return
    :B0:tbc::
        sendByClipboard("tracheobronchial calcifications" A_EndChar,3)
    return
    :B0:pna::
        sendByClipboard("pneumonia" A_EndChar,3)
    return
    ;~ ::bpa::bronchopneumonia
    :B0:ppq::
        sendByClipboard("pleural plaque" A_EndChar,3)
    return
    :*B0:ppq1::
        sendByClipboard("pleural plaques",3)
    return
    :*B0:mmph::
        sendByClipboard("multifocal micronodular pneumocyte hyperplasia (MMPH)",3)
    return
    :B0:lmcr::
        sendByClipboard("lymphangitic carcinomatosis" A_EndChar,4)
    return
    :B0:cfa::
        sendByClipboard("costophrenic angle" A_EndChar,3)
    return
    :*B0:cfa1::
        sendByClipboard("costophrenic angles",3)
    return
    :*B0:cfa2::
        sendByClipboard("cardiophrenic angle",3)
    return
    ;~ :*:ly/::(YCH/Dr.A)
    ;~ :*:lj/::(YCH/Dr.B)
    ;~ :*:lw/::(YCH/Dr.C)
    ;~ :*:lt/::(YCH/Dr.E)
    ;~ :*:lc/::(YCH/Dr.F)
    ;~ :*:lh/::(YCH/Dr.H)
    :B0:bcv::
        sendByClipboard("brachiocephalic vein" A_EndChar,3)
    return
    :B0:bca::
        sendByClipboard("brachiocephalic artery" A_EndChar,3)
    return
    :*B0:ad0::
        sendByClipboard("no definite abnormality of both adrenals.",2)
    return
    :B0:bdl::
        sendByClipboard("bilateral dependent lungs" A_EndChar,3)
    return
    :B0:sbp::
        sendByClipboard("subpleural" A_EndChar,3)
    return
    :B0:pl::
        sendByClipboard("pleural" A_EndChar,2)
    return
    :B0:fss::
        sendByClipboard("fissural" A_EndChar,3)
    return
    :*B0:plfs::
        sendByClipboard("pleural/fissural",3)
    return
    :B0:pth::
        sendByClipboard("pleural thickening" A_EndChar,3)
    return
    :B0:tho::
        sendByClipboard("thoracic" A_EndChar,3)
    return
    :B0:pul::
        sendByClipboard("pulmonary" A_EndChar,3)
    return
    :B0:lu::
        sendByClipboard("lung" A_EndChar,2)
    return
    :*B0:lu1::
        sendByClipboard("lungs",2)
    return
    :B0:lin::
        sendByClipboard("lingular LUL" A_EndChar,3)
    return
    :B0:eso::
        sendByClipboard("esophagus" A_EndChar,3)
    return
    :*B0:eso1::
        sendByClipboard("esophageal",3)
    return
    :*B0:nl0::
        sendByClipboard("no obvious worrisome lung nodule.",2)
    return
    :*B0:nl1::
        sendByClipboard("minor or non-specific lung parenchymal change.",2)
    return
    :*B0:nl2::
        sendByClipboard("tiny or probably non-specific nodules and minor or non-specific lung parenchymal change.",2)
    return
    :*B0:nl3::
        sendByClipboard("minor or non-specific lung findings.",2)
    return
    :*B0:onl1::
        sendByClipboard("other minor or non-specific lung parenchymal change.",3)
    return
    :*B0:onl2::
        sendByClipboard("other tiny or probably non-specific nodules and minor or non-specific lung parenchymal change.",3)
    return
    :*B0:onl3::
        sendByClipboard("other minor or non-specific lung findings.",3)
    return

    :*B0:l0/::
        sendByClipboard("no definite detectable lung abnormality.",2)
    return
    :B0:nh::
        sendByClipboard("normal heart size" A_EndChar,2)
    return
    :B0:cmg::
        sendByClipboard("cardiomegaly" A_EndChar,3)
    return
    :B0:pec::
        sendByClipboard("pericardial" A_EndChar,3)
    return
    :B0:pef::
        sendByClipboard("pericardial effusion" A_EndChar,3)
    return
    :*B0:peft::
        sendByClipboard("pericardial effusion with pericardial thickening",3)
    return
    :*B0:peth::
        sendByClipboard("pericardial thickening",3)
    return
    :*B0:ggoo::
        sendByClipboard("ground glass opacity",3)
    return
    :*B0:ggo1::
        sendByClipboard("ground glass opacities",3)
    return
    :*B0:ggnn::
        sendByClipboard("ground glass nodule",3)
    return
    :*B0:ggn1::
        sendByClipboard("ground glass nodules",3)
    return
    :B0:ggl::
        sendByClipboard("ground glass lesion" A_EndChar,3)
    return
    :*B0:ggl1::
        sendByClipboard("ground glass lesions",3)
    return
    :B0:pso::
        sendByClipboard("part-solid" A_EndChar,3)
    return
    :B0:sso::
        sendByClipboard("sub-solid" A_EndChar,3)
    return
    :B0:opa::
        sendByClipboard("opacity" A_EndChar,3)
    return
    :*B0:opa1::
        sendByClipboard("opacities",3)
    return
    :*:comch::
        {
            sendByClipboard("CT of the chest without and with contrast enhancement is read and compared with previous study dated . This CT study shows:")
            send % "{left 22}"
        }
    return
    :B0:corl::
        sendByClipboard("Please correlate with the imaging findings and report of the abdominal/pelvic CT study." A_EndChar,4)
    return
    :*B0:comc2::
        sendByClipboard("CT of the chest without and with contrast enhancement is read without prior CT for comparison. This CT study shows:",4)
    return
    :*:comc1::
        {
            sendByClipboard("CT of the chest with contrast enhancement is read and compared with previous study dated . This CT study shows:")
            send % "{left 22}"
        }
    return
    :*:comc0::
        {
            sendByClipboard("CT of the chest without contrast enhancement is read and compared with previous study dated . This CT study shows:")
            send % "{left 22}"
        }
    return
    :B0:wdgr::
        sendByClipboard("wedge resection" A_EndChar,4)
    return
    :B0:ssa::
        sendByClipboard("subsegmental atelectasis" A_EndChar,3)
    return
    :*B0:ssab::
        sendByClipboard("subsegmental atelectasis in bilateral lungs.",3)
    return
    :*B0:sa0::
        sendByClipboard("subsegmental atelectasis at bilateral basal lungs.",2)
    return
    :B0:ate::
        sendByClipboard("atelectasis" A_EndChar,3)
    return
    :*B0:atco::
        sendByClipboard("atelectasis/consolidation",3)
    return
    :B0:lte::
        sendByClipboard("linear atelectasis" A_EndChar,3)
    return
    :B0:brs::
        sendByClipboard("bronchiectasis" A_EndChar,3)
    return
    :B0:tbr::
        sendByClipboard("tractional bronchiectasis" A_EndChar,3)
    return
    :B0:pe::
        sendByClipboard("pleural effusion" A_EndChar,2)
    return
    :B0:mdi::
        sendByClipboard("mediastinum" A_EndChar,3)
    return
    ;~ :*:mdi1::mediastinal
    :B0:md::
        sendByClipboard("mediastinal" A_EndChar,2)
    return
    :B0:ptx::
        sendByClipboard("pneumothorax" A_EndChar,3)
    return
    :B0:pmd::
        sendByClipboard("pneumomediastinum" A_EndChar,3)
    return
    :B0:con::
        sendByClipboard("consolidation" A_EndChar,3)
    return
    :*B0:con1::
        sendByClipboard("consolidations",3)
    return
    :*B0:con2::
        sendByClipboard("consolidative",3)
    return
    :B0:emc::
        sendByClipboard("emphysematous change" A_EndChar,3)
    return
    :*B0:emc0::
        sendByClipboard("emphysematous change in bilateral lungs.",3)
    return
    :*B0:emc1::
        sendByClipboard("emphysematous change in bilateral upper lungs.",3)
    return
    :B0:efc::
        sendByClipboard("emphysematous and fibrotic change" A_EndChar,3)
    return
    :B0:bbl::
        sendByClipboard("bilateral basal lungs" A_EndChar,3)
    return
    :B0:rull::
        sendByClipboard("right upper lobe" A_EndChar,4)
    return
    :B0:rlll::
        sendByClipboard("right lower lobe" A_EndChar,4)
    return
    :B0:rmll::
        sendByClipboard("right middle lobe" A_EndChar,4)
    return
    :B0:lull::
        sendByClipboard("left upper lobe" A_EndChar,4)
    return
    :B0:llll::
        sendByClipboard("left lower lobe" A_EndChar,4)
    return
    :B0:djdt::
        sendByClipboard("degenerative change of the thoracic spine" A_EndChar,4)
    return
    :B0:djdtl::
        sendByClipboard("degenerative change of the thoracolumbar spine" A_EndChar,5)
    return
    :B0:bpk::
        sendByClipboard("bilateral apical pleural thickening" A_EndChar,3)
    return
    :B0:cora::
        sendByClipboard("coronary artery" A_EndChar,4)
    return
    :*B0:cora1::
        sendByClipboard("coronary arteries",4)
    return
    :*B0:cln0::
        sendByClipboard("no definite mediastinal or hilar lymphadenopathy.",3)
    return
    :*B0:ml0::
        sendByClipboard("non-specific small mediastinal lymph nodes.",2)
    return
    :B0:tlap::
        sendByClipboard("thoracic lymphadenopathy." A_EndChar,4)
    return
    :B0:ntl::
        sendByClipboard("no definite thoracic lymphadenopathy." A_EndChar,3)
    return
    :*B0:esre::
        sendByClipboard("status post esophagectomy and reconstruction.",3)
    return
    :B0:lbt::
        sendByClipboard("lobectomy" A_EndChar,3)
    return
    :B0:smt::
        sendByClipboard("segmentectomy" A_EndChar,3)
    return
    :B0:mst::
        sendByClipboard("mastectomy" A_EndChar,3)
    return
    :B0:ap/::
        sendByClipboard("the appendix is not clearly demonstrated." A_EndChar,3)
    return
    :B0:ist::
        sendByClipboard("interlobular septal thickening" A_EndChar,3)
    return
    :B0:pbv::
        sendByClipboard("peribronchovascular" A_EndChar,3)
    return
    :B0:cln::
        sendByClipboard("centrilobular nodules" A_EndChar,3)
    return
    :B0:msw::
        sendByClipboard("metallic sternal wires" A_EndChar,3)
    return
    :B0:ao::
        sendByClipboard("aorta" A_EndChar,2)
    return
    :*B0:ao1::
        sendByClipboard("aortic",2)
    return
    :B0:dph::
        sendByClipboard("diaphragm" A_EndChar,3)
    return
    :B0:hdp::
        sendByClipboard("hemidiaphragm" A_EndChar,3)
    return
    :B0:tra::
        sendByClipboard("a tracheostomy tube" A_EndChar,3)
    return
    :B0:trm::
        sendByClipboard("tracheostomy" A_EndChar,3)
    return
    :*B0:mi/::
        sendByClipboard("subendocardial hypoenhancement of LV, suspicious of ischemic change.",2)
    return

    ;intervention
    :B0:fld::
        sendByClipboard("flow diverter" A_EndChar,3)
    return
    :*B0:note0::
        sendByClipboard("
(
Procedure name:
Indication:
Anesthesia: Lidocaine HCL (Xylocaine 2%, 20 mg/mL) 200 mg local injection.
Route: Right femoral artery approach.
Equipment:
Complication: nil.

Procedure:
-
)")
    return
    :B0:gel::
        sendByClipboard("Gelfoam particles" A_EndChar,3)
    return
    :*B0:gel1::
        sendByClipboard("Gelfoam fine particles",3)
    return
    :*B0:gel2::
        sendByClipboard("Gelfoam coarse particles",3)
    return
    :B0:prer::
        sendByClipboard("pre-RFA TAE" A_EndChar,4)
    return
    :B0:sl10::
        sendByClipboard("1.7Fr microcatheter (SL-10; Boston Scientific)" A_EndChar,4)
    return
    :B0:prgr::
        sendByClipboard("a 2.7Fr microcatheter (Progreat; Terumo)" A_EndChar,4)
    return
    :B0:rene::
        sendByClipboard("a 2.5Fr microcatheter (Renegade; Boston Scientific)" A_EndChar,4)
    return
    :B0:rpy::
        sendByClipboard("retrograde pyelography" A_EndChar,3)
    return
    :B0:pegj::
        sendByClipboard("Decreased peristalsis of the stomach is noted; prominent colon gas, indicating ileus. A 5Fr H1 insertion into the stomach first; then 150 cm guidewire was delivered and this 5Fr H1 was adjusted into the duodenum. Therefore, the gastrojejunal tube (12Fr in 24Fr) was delivered smoothly with tip in the proximal jejunum. Prevention from tube occlusion was educated. Please give peristalsis-stimulating drugs (such as Motilin or Mopride; 1# tid); local wound care ointment (such as Bacitracin Neomycin Ointment; Zinc oxide ointment)." A_EndChar,4)
    return
    :B0:jtub::
        sendByClipboard("The yellow port is for feeding; the red port is for decompression. Please give the ointments for wound care and peristalsis stimulating drug." A_EndChar,4)
    return
    :B0:embz::
        sendByClipboard("Embozene particles (400 micrometer, CeloNova Bioscience)" A_EndChar,4)
    return
    :B0:dtvn::
        sendByClipboard("a 5Fr, 15cm DTVN drainage tube (Cook)" A_EndChar,4)
    return
    :B0:apy::
        sendByClipboard("antegrade pyelography" A_EndChar,3)
    return
    :B0:emz::
        sendByClipboard("embolization" A_EndChar,3)
    return
    :B0:lpo::
        sendByClipboard("lipiodol" A_EndChar,3)
    return
    :B0:lpr::
        sendByClipboard("lipiodol retention" A_EndChar,3)
    return
    :*B0:lhaa::
        sendByClipboard("left hepatic artery",3)
    return
    :*B0:lhvv::
        sendByClipboard("left hepatic vein",3)
    return
    :*B0:mhaa::
        sendByClipboard("middle hepatic artery",3)
    return
    :*B0:mhvv::
        sendByClipboard("middle hepatic vein",3)
    return
    :*B0:rhaa::
        sendByClipboard("right hepatic artery",3)
    return
    :*B0:rhvv::
        sendByClipboard("right hepatic vein",3)
    return
    :*B0:phaa::
        sendByClipboard("proper hepatic artery",3)
    return
    :*B0:chaa::
        sendByClipboard("common hepatic artery",3)
    return
    :*B0:smaa::
        sendByClipboard("superior mesenteric artery",3)
    return
    :*B0:ipaa::
        sendByClipboard("inferior phrenic artery",3)
    return
    :*B0:spda::
        sendByClipboard("superior pancreaticoduodenal artery",3)
    return
    :*B0:rgea::
        sendByClipboard("right gastroepiploic artery",3)
    return
    :*B0:lgea::
        sendByClipboard("left gastroepiploic artery",3)
    return
    :*B0:lgaa::
        sendByClipboard("left gastric artery",3)
    return
    :B0:rep::
        sendByClipboard("replaced" A_EndChar,3)
    return
    :B0:bch::
        sendByClipboard("branch" A_EndChar,3)
    return
    :*B0:bch1::
        sendByClipboard("branches",3)
    return
    :B0:rev::
        sendByClipboard("revision" A_EndChar,3)
    return
    :*B0:rev1::
        sendByClipboard("revised",3)
    return
    :B0:rem::
        sendByClipboard("remove" A_EndChar,3)
    return
    :B0:badi::
        sendByClipboard("balloon dilatation" A_EndChar,4)
    return
    :B0:seh::
        sendByClipboard("sheath" A_EndChar,3)
    return
    :B0:sty::
        sendByClipboard("stylet" A_EndChar,3)
    return
    :B0:ish::
        sendByClipboard("introducer sheath" A_EndChar,3)
    return
    :B0:exc::
        sendByClipboard("exchange" A_EndChar,3)
    return
    :B0:adv::
        sendByClipboard("advance" A_EndChar,3)
    return
    :B0:gw::
        sendByClipboard("guidewire" A_EndChar,2)
    return
    :B0:mgw::
        sendByClipboard("microguidewire" A_EndChar,3)
    return
    :B0:mcth::
        sendByClipboard("microcatheter" A_EndChar,4)
    return
    :B0:nav::
        sendByClipboard("navigate" A_EndChar,3)
    return
    :B0:ins::
        sendByClipboard("insert" A_EndChar,3)
    return
    :*B0:ins1::
        sendByClipboard("insertion",3)
    return
    :B0:vi::
        sendByClipboard("via" A_EndChar,2)
    return
    :B0:f::
        sendByClipboard("from" A_EndChar,1)
    return
    :B0:proc::
        sendByClipboard("procedure" A_EndChar,4)
    return
    :B0:gdaa::
        sendByClipboard("gastroduodenal artery" A_EndChar,4)
    return
    :B0:wbao::
        sendByClipboard("will be arranged on" A_EndChar,4)
    return
    :B0:wwcf::
        sendByClipboard("We were consulted for" A_EndChar,4)
    return
    :B0:rfa::
        sendByClipboard("RFA" A_EndChar,3)
    return
    :B0:tae::
        sendByClipboard("TAE" A_EndChar,3)
    return
    :B0:aspi::
        sendByClipboard("aspiration" A_EndChar,4)
    return
    :B0:drn::
        sendByClipboard("drainage" A_EndChar,3)
    return
    :B0:bx::
        sendByClipboard("biopsy" A_EndChar,2)
    return
    :B0:ctg::
        sendByClipboard("CT-guided" A_EndChar,3)
    return
    :B0:abl::
        sendByClipboard("ablation" A_EndChar,3)
    return
    :B0:mcw::
        sendByClipboard("microwave" A_EndChar,3)
    return
    :B0:cox::
        sendByClipboard("contrast extravasation" A_EndChar,3)
    return
    :*B0:cox0::
        sendByClipboard("no definite active contrast extravasation",3)
    return
    :B0:ufg::
        sendByClipboard("under fluoroscopic guidance" A_EndChar,3)
    return
    :B0:uug::
        sendByClipboard("under ultrasound guidance" A_EndChar,3)
    return
    :B0:ucg::
        sendByClipboard("under CT guidance" A_EndChar,3)
    return
    :B0:obj::
        sendByClipboard("obstructive jaundice" A_EndChar,3)
    return
    :B0:ja::
        sendByClipboard("jaundice" A_EndChar,2)
    return
    :B0:obu::
        sendByClipboard("obstructive uropathy" A_EndChar,3)
    return
    :B0:apr::
        sendByClipboard("approach" A_EndChar,3)
    return
    :B0:chg::
        sendByClipboard("cholangiogram" A_EndChar,3)
    return
    pcn:
        tmp:=$.value(3)
        if tmp not in l,r,b
        {
            sendByClipboard($.value(0))
            return
        }
        post=
(

No obvious discomfort was complained after the procedure.
Post-procedure vital signs: stable.
)
        arr:={l:"left",r:"right",b:"bilateral"}
        side:=arr[tmp]
        if($.value(4)=""){  ;new PCN
            exam=
(
History:

Indication: obstructive uropathy, for %side% PCN.
Catheter: 6Fr 25cm pigtail.

Findings:

Procedure:
- Patient in prone position. Skin disinfection. Place sterile drapes.
- Fentanyl 0.05 mg IV for pain control.
- Place sterile cover on ultrasound transducer. Visualize dilated renal calyces. Local anesthesia with lidocaine 2`% 10 ml.
- Advance 18G chiba needle into renal calyx under ultrasound guidance.
- Remove needle stylet; aspirate some pus-like urine; inject contrast for antegrade nephrogram.
- Advance 0.035" guidewire into renal collecting system under fluoroscopic guidance.
- Nick skin with `#11 blade. Remove chiba needle.
- Advance the pigtail catheter; remove inner stiffener; position catheter in renal pelvis.
- Confirm position with contrast injection.
- Skin suture to fix the catheter.

)
            imp:="status post " side " PCN."
        }else if ($.value(4)=1){ ;revision
            exam=
(
History:

Indication: obstructive uropathy, for %side% PCN revision.
Catheter: 6Fr 25cm pigtail.

Procedure:
- Patient in prone position. Skin disinfection. Place sterile drapes.
- Antegrade nephrogram via previous PCN shows
- Local anesthesia with lidocaine 2`% 10 ml.
- Advance 0.035" guidewire into renal collecting system under fluoroscopic guidance.
- Advance a new pigtail catheter; remove inner stiffener; position catheter in renal pelvis.
- Confirm position with contrast injection.
- Skin suture to fix the catheter.

)
            imp:="status post " side " PCN revision."
        }
        if tmp=b
            exam.="- Same steps for contralateral side."
        sendByClipboard(exam post "`t" imp)
        $:=""
    return
    ptcd:
        tmp:=$.value(3)
        if tmp not in l,r,b
        {
            sendByClipboard($.value(0))
            return
        }
        post=
(

No obvious discomfort was complained after the procedure.
Post-procedure vital signs: stable.
)
        arr:={l:"left",r:"right",b:"bilateral"}
        side:=arr[tmp]
        if($.value(4)=""){  ;new ptcd
            exam=
(
History:

Indication: obstructive jaundice, for %side% PTCD.
Catheter: 6Fr 25cm pigtail.

Findings:

Procedure:
- Patient in supine position. Skin disinfection. Place sterile drapes.
- Fentanyl 0.05 mg IV for pain control.
- Place sterile cover on ultrasound transducer. Visualize dilated %side% IHD. Local anesthesia with lidocaine 2`% 10 ml.
- Advance 21G chiba needle into dilated S3 IHD under ultrasound.
- Remove needle stylet; inject small contrast aliquots under fluoroscopy to opacify the IHD.
- Advance 0.018" guidewire into IHD and exchange needle for dilator-sheath under fluoroscopy.
- Remove guidewire and dilator; perform cholangiogram via sheath.
- Advance and navigate 0.035" guidewire to CBD.
- Nick skin with `#11 blade; remove sheath.
- Advance the pigtail catheter; remove inner stiffener; position catheter in CBD.
- Confirm position and drainage function with contrast injection.
- Skin suture to fix the catheter.

)
            imp:="status post " side " PTCD."
        }else if ($.value(4)=1){ ;revision
            exam=
(
History:

Indication: obstructive jaundice, for %side% PTCD revision.
Catheter: 6Fr 25cm pigtail.

Procedure:
- Patient in supine position. Skin disinfection. Place sterile drapes.
- Cholangiogram via previous PTCD shows
- Advance and navigate 0.035" guidewire to CBD.
- Remove previous pigtail catheter.
- Advance a new pigtail catheter; remove inner stiffener; position catheter in %side% IHD.
- Confirm position and drainage function with contrast injection.
- Skin suture to fix the catheter.

)
            imp:="status post " side " PTCD revision."
        }
        if tmp=b
            exam.="- Same steps for contralateral side."

        sendByClipboard(exam post "`t" imp)
        $:=""
    return
    :B0:lbx::
        sendByClipboard("We will evaluate the feasibility of CT guided biopsy for this patient. Please discuss and inform this patient and the family for the possible complications, such as pneumothorax, hemoptysis, hemorrhage, air embolism, etc." A_EndChar,3)
    return
    :*:lubx::
        d:=a_now
        d+=1,days
        if (a_wday=6)
            d+=2,days
        d:=substr(d,1,4) "/" substr(d,5,2) "/" substr(d,7,2)
        sendByClipboard("
(
CT guided biopsy will be arranged on %d% AM on call.
Please reassure the following things:
1. Informed consent. Family accompany. Please discuss and inform this patient and the family for the possible complications, such as pneumothorax, hemoptysis, hemorrhage, air embolism, etc.
2. Prepare O2 bottle, nasal canula, on IV cath, surgical bed and clothes.
3. Check PLT>80k, INR< 1.5.
4. Discontinue anticoagulant or antiplatelet drugs for at least 5 days if used.
5. 電腦斷層導引切片術需自費 NTD.2000 元
Thanks for your consultation.
)")
    return
    :*:lulo::
        d:=a_now
        d+=1,days
        if (a_wday=6)
            d+=2,days
        d:=substr(d,1,4) "/" substr(d,5,2) "/" substr(d,7,2)
        sendByClipboard("
(
CT guided localization will be arranged on %d% AM on call.
Please reassure the following things:
1. Informed consent. Family accompany. Please discuss and inform this patient and the family for the possible complications, such as pneumothorax, hemoptysis, hemorrhage, air embolism, etc.
2. Prepare O2 bottle, nasal canula, on IV cath, surgical bed and clothes.
3. Check PLT>80k, INR< 1.5.
4. Discontinue anticoagulant or antiplatelet drugs for at least 5 days if used.
5. 電腦斷層導引切片術需自費 NTD.2000 元
Thanks for your consultation.
)")
    return
    :*:bobx::
        d:=a_now
        d+=1,days
        if (a_wday=6)
            d+=2,days
        d:=substr(d,1,4) "/" substr(d,5,2) "/" substr(d,7,2)
        sendByClipboard("
(
CT guided biopsy will be arranged on %d% PM on call.
Please reassure the following things:
1. Informed consent. Family accompany. Please discuss and inform this patient and the family for the possible complications, such as hemorrhage, bowel perforation, etc.
2. Prepare O2 bottle, nasal canula, on IV cath, surgical bed and clothes.
3. Check PLT>80k, INR< 1.5.
4. Discontinue anticoagulant or antiplatelet drugs for at least 5 days if used.
5. 電腦斷層導引切片術需自費 NTD.2000 元
Thanks for your consultation.
)")
    return
    :*:bodr::
        d:=a_now
        d+=1,days
        if (a_wday=6)
            d+=2,days
        d:=substr(d,1,4) "/" substr(d,5,2) "/" substr(d,7,2)
        sendByClipboard("
(
CT guided drainage will be arranged on %d% PM on call.
Please reassure the following things:
1. Informed consent. Family accompany. Please discuss and inform this patient and the family for the possible complications, such as hemorrhage, bowel perforation, transient bacteremia/sepsis or septic shock , etc.
2. Prepare O2 bottle, nasal canula, on IV cath, surgical bed and clothes.
3. Check PLT>80k, INR< 1.5.
4. Discontinue anticoagulant or antiplatelet drugs for at least 5 days if used.
Thanks for your consultation.
)")

    return

    :B0:fesh::
        sendByClipboard("The femoral artery sheath is not removed. Please remove it in 48 hours if no further indication of angiographic intervention." A_EndChar,4)
    return

    ;conclusion
    :*B0:un0::
        sendByClipboard("negative or unremarkable radiological findings of the unmentioned organs.",2)
    return
    :*:rd0::
        quicksendFunc("rd0", "no obvious radiological abnormality noted. Suggest clinical correlation.")
    return
    :B0:yy::
        sendByClipboard("Reported by YCH (#00000)." A_EndChar,2)
    return
    :B0:nonc::
        sendByClipboard("(Low sensitivity and specificity of non-contrast CT.)" A_EndChar,4)
    return
    :*B0:noncmet::
        sendByClipboard("(Low sensitivity of non-contrast CT for metastatic lesions.)",6)
    return
    :*B0:ld=::
        sendByClipboard("(Low dose CT is inferior for soft tissue lesion detection.)",2)
    return
    :B0:sc::
        sendByClipboard("suggest clinical correlation." A_EndChar,2)
    return
    :B0:scf::
        sendByClipboard("suggest clinical correlation and follow up." A_EndChar,3)
    return
    :B0:sfu::
        sendByClipboard("suggest follow up." A_EndChar,3)
    return
    :*B0:sfu1::
        sendByClipboard("suggest short term follow up.",3)
    return
    :B0:fu::
        sendByClipboard("follow up" A_EndChar,2)
    return
    :B0:crr::
        sendByClipboard("correlation" A_EndChar,3)
    return
    :B0:mmc::
        sendByClipboard("suggest mammography correlation." A_EndChar,3)
    return
    :B0:mrc::
        sendByClipboard("suggest MRI correlation." A_EndChar,3)
    return
    :B0:ctc::
        sendByClipboard("suggest CT correlation." A_EndChar,3)
    return
    :B0:enc::
        sendByClipboard("suggest endoscope correlation." A_EndChar,3)
    return
    :B0:cec::
        sendByClipboard("suggest contrast enhanced study if indicated." A_EndChar,3)
    return
    :B0:lfc::
        sendByClipboard("suggest correlation with local findings." A_EndChar,3)
    return
    :*B0:enc2::
        sendByClipboard("suggest coloscope correlation.",3)
    return
    :*B0:enc1::
        sendByClipboard("suggest bronchoscope correlation.",3)
    return
    :B0:usc::
        sendByClipboard("suggest ultrasound correlation." A_EndChar,3)
    return
    :B0:guc::
        sendByClipboard("suggest gynecologic ultrasound correlation." A_EndChar,3)
    return
    :B0:sci::
        sendByClipboard("suggest clinical correlation for possible infectious process." A_EndChar,3)
    return
    :B0:nn::
        sendByClipboard("no significant lesion. Suggest clinical correlation." A_EndChar,2)
    return
    :B0:zlf::
        sendByClipboard("suggest correlation with local finding." A_EndChar,3)
    return
    :B0:stp::
        sendByClipboard("suggest tissue proof." A_EndChar,3)
    return
    :B0:reas::
        sendByClipboard("(This study is reassigned to current radiologist on " A_YYYY "/" a_mm "/" a_dd ".)",4)
    return
    :B0:othp::
        sendByClipboard("(Please correlate with the report of other body parts.)",4)
    return

    ;medical abbreviation
    :*B0:taee::
        sendByClipboard("transarterial embolization",3)
    return
    :*B0:avmm::
        sendByClipboard("arteriovenous malformation",3)
    return
    :*B0:avff::
        sendByClipboard("arteriovenous fistula",3)
    return
    :B0:vam::
        sendByClipboard("vascular malformation" A_EndChar,3)
    return
    :*B0:tbil::
        sendByClipboard("T-bil",3)
    return
    :B0:htn::
        sendByClipboard("hypertension" A_EndChar,3)
    return
    :*B0:ca/::
        sendByClipboard("ca",2)
    return
    :B0:cn::
        sendByClipboard("cancer" A_EndChar,2)
    return
    :B0:adc::
        sendByClipboard("adenocarcinoma" A_EndChar,3)
    return
    :B0:car::
        sendByClipboard("carcinoma" A_EndChar,3)
    return

    ;~ #x::
    PostMessage,0x2020,,,,ahk_exe EBMpreload.exe
    s:="TECHNIQUE: "  formatExamName(RisState[2]) "`r`n"
        ,s.="FINDINGS: `r`n-  "
        ,setReportText(s, "Please see the images and findings.", getRisReports(RisState[2]))
    if (simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")){
        editHwnds:=getSimpleRisEditHwnds()
        Edit_SetText(editHwnds[2], s)
            ,Edit_SetText(editHwnds[1], s)
            ,Edit_SetSel(editHwnds[2],cursorPoint:=StrLen(s),cursorPoint)
            ,Edit_SetSel(editHwnds[1],cursorPoint,cursorPoint)
            ,Edit_ScrollCaret(editHwnds[2])

    }
    winactivate,ahk_id %simpleRis%
    resetHotstringBuffer(-1)
    return

    ;VS templates

    :*:ct/::
        checkRis(RisState)
        gosub renewRisReports
    chestCTtemplate:
        lastChestCTtemplateAccNo:=getRisAccNo(risHwnd)
        winactivate,% "ahk_id " RisState[2]
        studyOpened:=0,RisHwnd:=RisOpened()[2]
            ,ExamItems:=parseRisExamItems(getRisExamItems(RisHwnd))

        clinicalHx:=getClinicalInfo(RisHwnd)
            , withCount:=withoutCount:=withwithoutCount:=0
        if instr(ExamItems[1,1],"With/Without") || InStr(ExamItems[1,1], "有&無造影劑")
            withwithoutCount+=1
        else if instr(ExamItems[1,1],"Without") || (ExamItems[1,1]~="i)low dose|lung cancer screen|ldct|低劑量|(無造影劑)")
            withoutCount+=1
        else
            withCount+=1
        if (ldct:=regexmatch(ExamItems[1,1],"i)low dose|lung cancer screen|ldct|低劑量"))
            withwithout:="without"
        otherCT:=ExamItems[2].maxindex()>ExamItems[1].maxindex()
            , otherParts:=[]
        if ExamItems[1].maxIndex()>1
            for k,v in ExamItems[1]
                if  !regexmatch(v,"is)chest|lung|(low dose)|EPS"){
                    ;~ otherCT:=true

                    RegExMatch(v, "i)-+([a-z \(\)]+)$", part)
                    StringLower,part1,part1
                    otherParts[InStr(part1, "neck")?"neck":part1]:=1

                    if instr(v,"With/Without")
                        withwithoutCount+=1
                    else if instr(v,"Without") || (v~="i)low dose|lung cancer screen|ldct")
                        withoutCount+=1
                    else
                        withCount+=1

                }

        RisHistoryAcc:=acc_ObjectFromWindow(getRisHistoryId(RisHwnd))
            ,priorDate:=""
        controlfocus,,% "ahk_id " risreporthwnd:=RisReports[1,1]
        ;~ if (getRisChartNo(RisHwnd)!=getImpaxChartNo(ImpaxOpened()[2,1])
        ;~ && getRisChartNo(RisHwnd)!=getEBMChartNo()) {
        ;~ if !RisChartNoMatchPacs(RisState, ImpaxState){
        ;~ simpleRISBlack()
        ;~ ,risOpenStudyImpax(risHwnd)
        ;~ ,studyOpened:=1
        ;~ }

        examDate:=getRisExamDate(RisState[2])
            ,thisAccNo:=getRisAccNo(RisState[2])

        ;open old film
        for k,v in rows:=acc_children(RisHistoryAcc){
            if(k=1){
                for x,y in cells:=acc_children(v) {
                    if (y.accValue="照會單號"){
                        AccNoCol:=x
                    }else if (y.accValue="檢查日"){
                        examDateCol:=x
                    }else if (y.accValue="檢查名稱"){
                        examNameCol:=x
                    }
                }
            }else if regexmatch(acc_children(v)[examNameCol].accValue,"is)CT.+Contrast-Chest|Low dose") {
                _priorDate:=acc_children(v)[examDateCol].accValue
                if RegExReplace(_priorDate,"\W","")>=SubStr(RegExReplace(examDate,"\W",""),1,8){
                    continue
                }
                priorDate:=_priorDate
                    ,v.accSelect(ComObj(3,3),0)

                if(impaxContextServerHwnd:=ImpaxContextServer_Init()){
                    ;~ if(0){
                    sendStr:="SYNC_DISPLAY || " thisAccNo " || "
                        ,sendStr.="ADD_TO_DISPLAY_LIST || " Trim(acc_children(v)[AccNoCol].accValue) " || "
                    Loop {
                        if !(RegExReplace(priorDate,"\W","")=RegExReplace(test:=(nearRow:=acc_children(rows[k-A_Index]))[examDateCol].accValue,"\W","") && InStr(test2:=nearRow[examNameCol].accValue,"CT"))
                            break
                        sendStr.="ADD_TO_DISPLAY_LIST || " Trim(nearRow[AccNoCol].accValue) " || "
                    }
                    Loop {
                        if !(RegExReplace(priorDate,"\W","")=RegExReplace((nearRow:=acc_children(rows[k+A_Index]))[examDateCol].accValue,"\W","") && InStr(nearRow[examNameCol].accValue,"CT"))
                            break
                        sendStr.="ADD_TO_DISPLAY_LIST || " Trim(nearRow[AccNoCol].accValue) " || "
                    }
                    sendStr.="ADD_TO_DISPLAY_LIST_WITH_PRIORS || " thisAccNo " || "
                    ;~ ,SetTimerF("cmdContextServer", -3000, [sendStr, impaxContextServerHwnd])
                }else{
                    sleep 200
                    loc:=Acc_Location(v)
                    mouseclick,r,% loc.x+50,% loc.y+5,1,0
                    sleep 200
                    mouseclick,l,10,10,1,0,,R
                }
                break
            }
        }
        settimer,updateSimpleRISoldHx,-500

        withwithout:=withwithoutCount>0?"without/with":withoutCount>0?"without":"with"
            ,AllParts:=""
            ,otherParts["chest"]:=1
            ,otherPartsList:=""
        otherPartDefaultFinding:=(ClinicalHx~="i)neoplasm|cancer|malignancy|carcinoma|metasta")?{brain: "no abnormal enhancing lesion in the brain parenchyma. "
            , neck: "no definite enlarged (>1cm) neck lymph node. "
            , abdomen: "no definite lymphadenopathy or metastatic lesions. "}:[]
        for k,v in ["brain", "neck", "chest", "abdomen", "pelvis", "C spine", "T spine", "L spine", "upper extremities", "lower extremities"]
            if otherParts.HasKey(v)
                AllParts.=InStr(v,"spine")?(StringUpper(SubStr(v,1,1)) "-" SubStr(v,3)):v ", "
                    , otherParts.delete(v)
                    , otherPartsList.=v~="i)chest|spine|extremit"?"":bullet StringUpper(SubStr(v,1,1)) SubStr(v,2) ": " otherPartDefaultFinding[v] "`r`n"
        for k,v in otherParts
            AllParts.=v ", "
        AllParts:=RegExReplace(AllParts, ", $", "")
            ,AllParts:=RegExReplace(AllParts, ", (\w+)$", " and $1")

        text:=""
        __ind:=RegExReplace(trim(getIndicationText(risHwnd)), "[\.\r\n]+$","")

        if !__is_CH && !(__ind="") && !(__ind="N/A")
            text.="INDICATION: " __ind ". `r`n`r`n"
        text.="TECHNIQUE: " (ldct&&withwithout="without"?"Low dose ":"") "CT of the " AllParts " " withwithout " intravenous contrast.`r`n"
        if priorDate
            text.="COMPARISON: " priorDate ".`r`n"
        text.="FINDINGS:`r`n"
            ,text.=ifbreast:=RegExMatch(ClinicalHx,"is)(neoplasm|malignan|cancer|carcinoma)[^\r\n]+breast|breast[^\r\n]+(neoplasm|malignan|cancer|carcinoma)")?bullet "Breast: `r`n":""
        if ifbreast
            cursorPoint:=strlen(text)-2
        text.=bullet "Lung/airway: `r`n  -- `r`n"
        if !ifbreast
            cursorPoint:=strlen(text)-2
        text.=bullet "Pleura: no pleural effusion. `r`n"
            ,text.=(instr(ClinicalHx,"lymphoma")||instr(ClinicalHx,"leukemia"))?bullet "Thoracic lymph node: small mediastinal and supraclavicular lymph nodes. `r`n":ifbreast?bullet "Mediastinum: small mediastinal and axillary lymph nodes. `r`n":bullet "Mediastinum: small mediastinal lymph nodes. `r`n"
            ,text.=bullet "Other: `r`n"
            ,text.=bullet "Heart/great vessel: `r`n"
            ,text.=bullet "Bone: spondylosis with marginal spur formation. `r`n"
            ,Text.=otherPartsList
        if withwithout=without
            text.="(Low sensitivity and specificity of non-contrast CT.)`r`n"
        if (ldct || (ClinicalHx~="i)小部位[^\r\n]+(LDCT|low\W*dose)"))
            text.="(Low dose CT is incompetent for soft tissue lesion detection.)`r`n"
        if otherCT
            text.="(Please correlate with the report of other body parts.)`r`n"
        ;~ text.="(YCH/)"
        text:=SubStr(text,1, -2)
        ;~ changeLineBreak(Text)

        ;; lung op
        if OpText:=chestCTtemplateAddOpText(Text)
            controlsettext,,% "Post-operative changes of lung.`r`n",% "ahk_id " RisReports[1,2]

        if !ifbreast
            cursorPoint+=StrLen(OpText)

        ;;;;; breast op text
        if RegExMatch(oldReportText:=ControlGetText(RisReports[2,1]), "i)[^\r\n\.:\-\)\*>=]+mast?ectomy[^\r\n\.:]*\.?", ms)
            || RegExMatch(oldReportText getRisClinicalInfoText(RisState[2]), "i)(bilateral|right|left) *(partial)? *mast?ectomy", m){
            breast_optext:=ms?StringLowerFirst(RegExReplace(RegExReplace(Trim(ms), "i)s\/p", "status post"), "masectomy", "mastectomy")):"status post " m1 " mastectomy. "
            if i:=RegExMatch(Text, "i)- Breast: ")
                Text:=SubStr(Text,1,i+9) breast_optext SubStr(Text, i+10)
                    ,cursorPoint+=StrLen(breast_optext), ifbreast:=false
            else if i:=RegExMatch(Text, "i)- Others?: ", m)
                Text:=SubStr(Text,1,i+StrLen(m)-1) breast_optext SubStr(Text, i+StrLen(m)), ifbreast:=false
            else if i:=RegExMatch(Text, "i)Findings: *\r?\n", m)
                breast_optext.="`r`n"
                    ,Text:=SubStr(Text,1,i+StrLen(m)-1) breast_optext SubStr(Text, i+StrLen(m))
                    ,cursorPoint+=StrLen(breast_optext), ifbreast:=false
        }

        ;;; old lung change
        for k,v in RegExMatchAll(oldReportText, "i)[\w, ]*(fibro|emphyse)[^.\r\n]+").list {
            Text:=RegExReplace(Text, "i)(- Lung[^\r\n]+\r?\n( *--[^\r\n]*\r?\n)*( *--[^\r\n]))", "$1" Trim(v[0]) ". `r`n  -- ")
        }

        ;;; eso op text
        if RegExMatch(oldReportText, "i)esophagectomy|gastric tube") {
            Text:=RegExReplace(Text, "i)Mediastinum:[^\r\n]*", "Mediastinum: status post esophagectomy and reconstruction.")
        }

        bulletRE:="(?:(?:[\-\*>]+|\d+\.?) *)?"

        ;; pleural findings
        ophx:=""
        for k,v in RegExMatchAll(oldReportText, "i)(?:[\w ,\/\-]|\d+\.\d+)*(pleural)[^\r\n\.]*").list {
            if !(Trim(v[0])~="i)^" bulletRE "(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne)") && !InStr(v[0], "subpleur") && !(v[0]~="i)pleural retraction|pleural tail")
                ophx.=regexreplace(RegExReplace(Trim(v[0]), "i)s\/p", "status post") ". ", "^" bulletRE, "")
        }
        if(ophx!="")
            Text:=RegExReplaceSeq(text, ["i)(Pleural?:) *(no pleural effusion.)?", "i)(Other:)"], "$1 " StringLowerFirst(ophx))

        ;;; abdominal hx
        ophx:=""
        for k,v in RegExMatchAll(oldReportText, "i)(?:[\w ,\/\-]|\d+\.\d+)*(splenectomy|cholecystectomy|nephr\w+tomy|gastrectomy|whipple|bypass|ostomy|RFA|TAE|TACE|cirrho|fatty)[^\r\n\.]*").list {
            if !(Trim(v[0])~="i)^" bulletRE "(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne)")
                ophx.=regexreplace(RegExReplace(Trim(v[0]), "i)s\/p", "status post") ". ", "^" bulletRE, "")
        }
        if(ophx!="")
            Text:=RegExReplaceSeq(text, ["i)(Abdomen:)", "i)(Other:)"], "$1 " StringLowerFirst(ophx))

        ;;; pelvic hx
        ophx:=""
        for k,v in RegExMatchAll(oldReportText, "i)(?:[\w ,\/\-]|\d+\.\d+)*(\bTURP\w+|prostat|bladder|hyster|adnex|ovar)[^\r\n\.]*").list {
            if !(Trim(v[0])~="i)^" bulletRE "(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne)")
                ophx.=regexreplace(RegExReplace(Trim(v[0]), "i)s\/p", "status post") ". ", "^" bulletRE, "")
        }
        if(ophx!="")
            Text:=RegExReplaceSeq(text, ["i)(Pelvis:)", "i)(Other:)"], "$1 " StringLowerFirst(ophx))

        ;;; neck op hx
        ophx:=""
        for k,v in RegExMatchAll(oldReportText, "i)(?:[\w ,\/\-]|\d+\.\d+)*(thyroidectomy)[^\r\n\.]*").list {
            if !(Trim(v[0])~="i)^" bulletRE "(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne)")
                ophx.=regexreplace(RegExReplace(Trim(v[0]), "i)s\/p", "status post") ". ", "^" bulletRE, "")
        }
        if(ophx!="")
            Text:=RegExReplaceSeq(text, ["i)(Neck:)", "i)(Other:)"], "$1 " StringLowerFirst(ophx))

        ;;;; metastasis text
        if RegExMatch(oldReportText, "i)" bulletRE "(?:(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(no|unr|ne)?[ \w]+)?(bone|bony|spinal|vertebral|skull) metasta", mets) && (mets1="") {
            Text:=RegExReplaceSeq(text, ["i)(Bone:[^\r\n]*)", "i)(Other:[^\r\n]*)"], "$1 bone metastases. ")
        }
        if RegExMatch(oldReportText, "i)\W? *((?:(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne))[ \w]+)?(liver|hepatic) metasta", mets) && (SubStr(Trim(mets1),1,1)!="n") {
            Text:=RegExReplace(text, "i)Abdomen: no definite lymphadenopathy or metastatic lesions. *", "Abdomen:", "", 1)
            Text:=RegExReplaceSeq(text, ["i)(Abdomen:[^\r\n]*)", "i)(Other:[^\r\n]*)"], "$1 liver metastases. ")
        }

        ;;; bone finding
        ophx:=""
        for k,v in RegExMatchAll(oldReportText, "i)(?:[\w ,\/\-]|\d+\.\d+)*(fracture)[^\r\n\.]*").list {
            if !(Trim(v[0])~="i)^" bulletRE "(?:there(?:\'s|\'re| +is| +are| +was| +were) +)? ?(?:no|unr|ne)")
                ophx.=regexreplace(RegExReplace(Trim(v[0]), "i)s\/p", "status post") ".", "^" bulletRE, "")
        }
        if(ophx!="")
            Text:=RegExReplaceSeq(text, ["i)(Bone:[^\r\n]*)", "i)(Other:[^\r\n]*)"], "$1 " StringLowerFirst(ophx))

        Text:=RegExReplace(Text, "i) *\(? *(?:SE|S) *\d+[^\w\)\r\n]*(?:IM|I) *\d+(,? *(?:IM|I) *\d+)* *\)?", "")

        PostMessage,0x2023,1,0,,simpleRIS_main ahk_class AutoHotkeyGUI

        if InStr(ExamItems[1,1], "Low dose lung cancer screening CT for employee(N hospital)"){
            if FileExist(path:=A_ScriptDir "\LDCTreport\LDCTreport.exe") || FileExist(path:=A_ScriptDir "\LDCTreport.exe")
                run,% path
        }else{

            controlsettext,,% text,% "ahk_id " RisReports[1,1]

            if (ifbreast)
                i:=RegExMatch(Text, "i)- Breast: [^\r\n]*", m)
                    ,cursorPoint:=i+StrLen(m)-1
            else
                i:=RegExMatch(Text, "i)- Lung[^\r\n]+\r?\n( *--[^\r\n]*\r?\n)+", m)
                    ,cursorPoint:=i+StrLen(RegExReplace(m, "[\r\n]+$", ""))-1

            Edit_SetSel(RisReports[1,1],cursorPoint,cursorPoint)
                ,Edit_ScrollCaret(RisReports[1,1])
            if (simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")){
                winactivate,ahk_id %simpleRis%
                editHwnds:=getSimpleRisEditHwnds()
                    ,Edit_SetText(editHwnds[2], Text)
                    ,Edit_SetSel(editHwnds[2],cursorPoint,cursorPoint)
                    ,Edit_SetText(editHwnds[1], Text)
                    ,Edit_SetSel(editHwnds[1],cursorPoint,cursorPoint)
                    ,Edit_ScrollCaret(editHwnds[2])

            }
        }
    ;~ if !studyOpened
    ;~ settimer,moveToSeriesList,-2000
    ;~ if(ldct)
    ;~ settimer,showLungCAD,-3000
    return

    chestCTtemplateAddOpText(ByRef Text){
        global RisReports, RisState, cursorPoint
        ClinicalHx:=getRisClinicalInfoText(RisState[2])
        optext:=RegExReplace(OpText(ControlGetText(RisReports[2,1]) "`r`n" ControlGetText(RisReports[2,1]) "`r`n" ClinicalHx), "i)s\/p", "status post")

        if (OpText!="")
            Text:=RegExReplace(Text, "(- Lung\/airway: \r?\n  -- )", "$1" OpText " `r`n  -- ")
                ,cursorPoint+=8

        return OpText
    }

    updateSimpleRISoldHx:
        PostMessage,0x1124,1,0,,simpleRIS_main ahk_class AutoHotkeyGUI
    return

    moveToSeriesList:
        Impax:=impaxOpened()
        for k,v in (impaxControls:=getcontrols(Impax[2,1])){
            if v.text="BMP_VIRTUAL_SCREEN_BUTTON" && instr(v.ClassNN,"WindowsForms10.BUTTON") {
                controlclick,,% "ahk_id " v.hwnd
                controlgetpos,x,y,,,,% "ahk_id " v.hwnd
                mousemove,% x+a_screenwidth+300,% y+300,0
                break
            }
        }
        winactivate,% "ahk_id " ImpaxState[2,1]

    return

    :B0:cyyb::
        sendByClipboard("
(
Brain CT without/with contrast enhancement shows:
- Hemorrhage: None
- CSF spaces: Normal in size and morphology for the patient's age
- Cerebral parenchyma: Normal
- Cerebellum: Normal
- Brainstem: Normal
- Calvarium: Normal
- Vascular system: Unremarkable
- Visualized paranasal sinuses: Clear
- Visualized orbits: Normal
- Visualized cervical spine: Normal
- Sella and skull base: Normal
)")
        sendByClipboard(a_endchar)
    return
    :B0:cyyn::
        sendByClipboard("
(
Neck CT without/with contrast enhancement shows:
- Orbits/Sinonasal Cavities/Skull Base: Mild sinusitis change.
- Nasopharynx: Normal.
- Suprahyoid Neck: Normal.
- Infrahyoid Neck: Normal.
- Thyroid: Normal.
- Lymph Nodes: Normal.
- Vascular Structures: Normal.
)")
        sendByClipboard(a_endchar)
    return

    ^!r::
        reload
    return

    joinAnd(arr,del=", ",lastDel="and"){
        str:="",ind:=arr.maxindex()
        for k,v in arr
            str.=v del

        if (lastDel="" || k=1)
            return substr(str,1,strlen(str)-strlen(del))
        else
            return substr(str,1,strlen(str)-strlen(del)*2-strlen(v)) " " lastDel " " v

    }

    parseAhk(path){
        arr:=[],hotstring:="",str:=""
        fullScript:=JoinScript(path)

        loop,parse,fullscript,`r`n
        ;~ loop,read,% path
        {
            if RegExMatch(a_loopfield,"is)^:[^:]*?:(.+):[^:]?:([^\n\r]*)",match) {
                if match2
                    arr["" match1]:=match2
                else
                    hotstring:=match1

                continue
            }

            if (hotstring!="") {
                if(a_loopfield=")" || trim(a_loopfield)="return") {
                    arr["" hotstring]:=str
                        ,hotstring:="",str:=""
                }else if (a_loopfield!="(") {
                    str.=a_loopfield "`r`n"
                }

            }
        }
        return arr

    }

    combineHotstring:
        sendlevel,1
        sendByClipboard($.value(1) ($.value(1)="b"?"i ":" "))
        sleep 100
        sendByClipboard($.value(2) " ")
        sleep 100
        if $.value(3) {
            if regexmatch(substr($.value(2),0,1),"[xsz]")
            {
                send % "{bs}"
                sendByClipboard("es")
            }
            else if regexmatch(substr($.value(2),-1,2),"ch|sh")
            {
                send % "{bs}"
                sendByClipboard("es")
            }
            else if substr($.value(2),0,1)="y"
            {
                send % "{bs 2}"
                sendByClipboard("ies")
            }
            else
            {
                send % "{bs}"
                sendByClipboard("s")
            }
        }
        $:=""
    return

    :B0:facetblock::
        sendByClipboard("
(
The study was for CT-guided facet block. The patient had right low back pain
> Image findings: lumbar spondylosis. Mild spondylolisthesis at L4-L5 level. Hypertrophy and calcified ligamentum flavum.
> Four 26G needles were inserted from bilateral posterior approach with tip into the bilateral L4-5, L5-S1 facet joint region. Total 5ml mixture of steroid (Triamcinolone suspension 1amp=40mg=1ml), 2`% xylocaine (3ml) and contrast medium (Omnipaque 1ml) was injected slowly through the needles.
> F/U CT showed well dispersion of the contrast medium in the facet joint regions.
> The patient tolerated the procedure well.
)")
        send % "{tab}"
        sendByClipboard(")
(
Status post facet joint injection at bilateral L4-5 and L5-S1 levels.
)")
    return

    ::qq::
    :*:qqq::
    _qq:

        RisReports:=getRisReports(risHwnd:=RisOpened()[2])
        if InStr(A_ThisLabel, "qqq")

            controlsettext,,% "Radiological images from outside hospital had been uploaded into the PACS (Picture Archiving and Communication System) server as a baseline or for comparison. Please check the original formal report of these images from the source hospital. Brief (but not detailed) findings: `r`n" bullet,% "ahk_id " risReports[1,1]
        else
            controlsettext,,% "Radiological images from outside hospital had been uploaded into the PACS (Picture Archiving and Communication System) server as a baseline or for comparison. Please check the original formal report of these images from the source hospital.",% "ahk_id " risReports[1,1]
        winactivate,ahk_id %rishwnd%
        ControlFocus,,% "ahk_id " RisReports[1,1]
        controlsend,,^{end},% "ahk_id " RisReports[1,1]

        if !InStr(A_ThisLabel, "qqq")
            getNetAcc(risHwnd,"cmdRunVerifySend","WindowsForms10.BUTTON").accDoDefaultAction()
    return

    loadAbbr(){
        fileread,abbr,% a_scriptdir "\YCH_abbr.txt"
        arr:=[]
        loop,parse,abbr,`n,`r
        {
            if regexmatch(a_loopfield,"^\s*\;") || (trim(a_loopfield)="")
                continue
            if regexmatch(a_loopfield,"^\s*([^=]+)=\s*([^\n]+)",match)
                if isobject(arr[match1])
                    arr[match1].push(match2)
                else
                    arr[match1]:=array(match2)
        }
        return arr
    }
    appendAbbr(){
        global abbr,risReports,RisState,editHwnds, thisPlace, CH_RIS, __is_CH
        checkRis(RisState)
        gosub renewRisReports
        ;~ risReport:=getRisReports(risopened()[2])
        if !RisState[2] && !InStr(thisPlace, "C hospital")
            fullText:=ControlGetText(editHwnds[2])
        else if __is_CH
            fullText:=CH_RIS.report
        else
            fullText:=controlgettext(risReports[1,1]) "`r`n" controlgettext(risReports[1,2])
        fullReport:=RegExReplace(fullText,"is)^History[^\r\n]+","")
            ,fullReport:=RegExReplace(fullReport,"is)^INDICATION:[^\r\n]+","")
            ,fullReport:=RegExReplace(fullReport,"(\r?\n)+\(([A-Z]+: [^;\.]+(\.|; ))+\)","")
            ,ind:=0,outText:="("
            ,abbrLog:=","
            ,output:=[]
            ,fullReport:=RegExReplace(fullReport, "^[^\r\n]+\r?\n", "")
        while ind:=regexmatch(fullReport,"\b(D[Rr]\.? *)?([A-Z]{2,})s?\b",match,ind+1) {
            if match1
                continue
            if match2 in CT,MR,MRI,YCH,INDICATION,TECHNIQUE,EXAMINATION,COMPARISON,FINDINGS,PACS,HMC,II,III,IV,VI,VII,VIII,IX,XI,XII,CCRT,POSTERIOR,FOSSA,MRCP,BRAIN,NECK,SPINE,ABDOMEN,CONT,WITH,WITHOUT
                continue
            ;~ else if (fullReport~=match2 " *\/(D[Rr].?)? *YCH")
            ;~ continue
            else if isobject(a:=abbr[match2]) && !instr(abbrLog,"," match2 ",") {
                if (a.maxIndex()=1)
                    ;~ outText.=match2 ": " a.1 "; "
                    output["" match2]:=a.1
                else {
                    prompt:=""
                    for k,v in a
                        prompt.=k ": " v "`r`n"
                    inputBox,choice,% """" match2 """ means ?",% prompt
                    choice:=choice?(choice+0):1
                    ;~ outText.=match2 ": " a[choice] "; "
                    output["" match2]:=a[choice]
                }

            }else if !instr(abbrLog,"," match2 ",") {
                inputbox,choice,% "What do you mean """ match2 """ ?"
                if (choice) {
                    ;~ outText.=match1 ": " choice "; "
                    output["" match2]:="" choice
                    abbrLog.=match2 ","
                    clipboard:=match2 "=" choice
                    if !winexist("YCH_abbr")
                        run % a_scriptdir "\YCH_abbr.txt"
                }
            }
            abbrLog.=match1 ","
        }
        for k,v in output
            outText.=k ": " v "; "
        outText:=substr(outText,1,-2) ".)"
        ;~ msgbox % outtext
        ;~ outText.=")"
        ;~ StringReplace,outText,outText,% "; )",% ".)"
        if (outText=".)")
            outText:=""
        else{

            if __is_CH
            {
                report:=new ReportImpression(CH_RIS.Report)
                    ,report:=new ReportImpression(report.exam "`r`n`r`n" outText, report.impression)
                    ,report.set_text(getSimpleRisEditHwnds()[1])
                    ,CH_RIS.report:=report.combine()
                    ,CH_RIS.exam:=report.exam
                    ,CH_RIS.impression:=report.impression
                    ,CH_RIS.flush()
            }else

                outText:=RegExReplace(controlgettext(editHwnds[2]),"(\r?\n$)|((\r?\n)+\(([A-Z]+: [^;\.]+(\.|; ))+\))","") "`r`n`r`n" outText
                    ,Edit_SetText(risReports[1,1], outText)
                    ,Edit_SetText(editHwnds[2], outText)
                    ,Edit_SetText(editHwnds[1], outText)

        }

        return outText
    }
    moveText(text){
        str:="",other:=0
        loop,parse,text,`n,`r
        {
            if instr(a_loopfield,"- Other")=1 || (instr(a_loopfield,"  -- ")=1 && other) {
                temp.=(temp?"`r`n":"") A_LoopField, other:=1
            }else if instr(a_loopfield,"- ")=1 || instr(a_loopfield,"  -- ")=1 {
                report:=1, other:=0
                str.=a_loopfield "`r`n"
            }else{
                str.=(report&&temp?(temp "`r`n"):"") a_loopfield "`r`n",report:=0,temp:=""
            }
        }
        if temp
            str.=temp
        return str
    }

    TrimConvert(t){
        return Trim(RegExReplace(t, "\r?\n", "`r`n"))
    }

    copyToRis:
        if __is_N
            PostMessage,0x2020,,,,simpleRIS_main ahk_class AutoHotkeyGUI
        checkRis(RisState)
        gosub renewRisReports
        risReport:=risReports[1,1]
            ,editHwnds:=getSimpleRisEditHwnds()
            ,simpleRisError:=false
        if (simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI")) || WinExist("simpleRIS_main ahk_class AutoHotkeyGUI")   {
            if (__is_CH){
                Text:=ControlGetText(editHwnds[1])
                    ,oText:=new ReportImpression(text)
                    ,oText.add_impression(ControlGetText((RisReports:=getRisReports())[1,2]))
                    ,oText.set_text(RisReports[1,1], RisReports[1,2])
                    ,oText.set_text(editHwnds[1])

            }else if !WinExist("simpleRISsimpleEdit ahk_class AutoHotkeyGUI") {
                Loop {
                    Text:=TrimConvert(ControlGetText(editHwnds[1]))
                        ,Text2:=TrimConvert(controlgettext(editHwnds[2]))
                        ,oText:=new ReportImpression(text)
                        ,oText2:=new ReportImpression(text2)
                    if(oText.combine()="")
                        text:=Text2, otext:=oText2
                    else if (oText2.combine()="")
                        Text2:=text, oText2:=oText

                    if InStr(thisPlace, "C hospital")
                        text3:=text, oText3:=oText
                    else
                        text3:=TrimConvert(controlgettext(risReport))
                            , oText3:=new ReportImpression(ControlGetText(getRisReports()[1,1]), ControlGetText(getRisReports()[1,2]))

                    if(!oText.is_equal(oText2)) || (!oText.is_equal(oText3))
                        Sleep 100
                    else
                        break
                    if A_Index>4
                        break
                }

                if !controlexists(risReport) || !controlexists(editHwnds[1]) || !controlexists(editHwnds[2]) || (Text!=Text2) || (Text!=text3) {
                    simpleRisError:=true
                    clipboard:=text "`n----------------------`n" Text2 "`n----------------------`n" text3
                    MsgBox % "Simple RIS text error"
                    return
                }
                ;~ Edit_SetText(editHwnds[1], Text)
                ;~ controlsettext,,% text,% "ahk_id " RisReports[1,1]
            }else{
                Text:=TrimConvert(ControlGetText(editHwnds[2])), oText:=new ReportImpression(text)
            }
        }else{
            ;~ msgbox % simpleRis "," text "," editHwnd
            text:=controlgettext(risReport)
                , oText:=new ReportImpression(ControlGetText(getRisReports()[1,1]), ControlGetText(getRisReports()[1,2]))
        }

        if __is_N && (InStr(reportHint:=getReportHint(RisState[2]),"請於impression輸入中文診斷") && Trim(ControlGetText(RisReports[1,2]))="" )
            ControlSetText,,% "無顯著異常。",% "ahk_id " RisReports[1,2]
    return

    renewRisReports:
        ;~ if !(isobject(risReports) && controlexists(RisReports[1,1]))
        RisReports:=getRisReports(RisState[2])
            ,editHwnds:=getSimpleRisEditHwnds()
    return
    openSimpleRis:
        if !winexist("simpleRIS_main ahk_class AutoHotkeyGUI") {
            ;~ PostMessage,0x10101,,,,simpleRIS_main ahk_class AutoHotkeyGUI
            taskkill("simpleRIS_patch.exe")
                ;~ ,taskkill(WinGet("PID", "simpleRIS__main ahk_class AutoHotkeyGUI"))
                ,taskkill(WinGet("PID", "simpleRIS_main ahk_class AutoHotkeyGUI"))
            try
            run, % commands(A_ScriptDir "\AutoHotkey.exe", a_scriptdir "\PacsIE\simpleRIS.ahk"),% a_scriptdir "\PacsIE"
        }
        ;~ winwait,% "simpleRIS__main ahk_class AutoHotkeyGUI",,2
        ;~ Sleep 1000
        editHwnds:=getSimpleRisEditHwnds()
        ;~ if(!editHwnds.length()){
        ;~ WinClose,% "simple RIS ahk_class AutoHotkeyGUI"
        ;~ Sleep 100
        ;~ run % a_scriptdir "\PacsIE\simpleRIS.exe"
        ;~ winwait,% "simple RIS ahk_class AutoHotkeyGUI",,2
        ;~ editHwnds:=getSimpleRisEditHwnds()
        ;~ }

        WinFocus(getSimpleRisGuiHwnds()[2], editHwnds[2])
    return

    ;~ staging
    :B0:npcst::
        sendbyclipboard("", 5)
        run,RadTemplate.exe .\staging\AJCC8_Nasopharyngeal_cancer.txt,% a_scriptdir "\RadTemplate"
    return
    :B0:oralst::
        sendbyclipboard("", 6)
        run,RadTemplate.exe .\staging\AJCC8_Oral_cavity_cancer.txt,% a_scriptdir "\RadTemplate"
    return
    :B0:larst1::
        sendbyclipboard("", 6)
        run,RadTemplate.exe .\staging\AJCC8_Laryngeal_cancer_supraglottis.txt,% a_scriptdir "\RadTemplate"
    return
    :B0:larst2::
        sendbyclipboard("", 6)
        run,RadTemplate.exe .\staging\AJCC8_Laryngeal_cancer_glottis.txt,% a_scriptdir "\RadTemplate"
    return
    :B0:larst3::
        sendbyclipboard("", 6)
        run,RadTemplate.exe .\staging\AJCC8_Laryngeal_cancer_subglottis.txt,% a_scriptdir "\RadTemplate"
    return
    :B0:hypst::
        sendbyclipboard("", 5)
        run,RadTemplate.exe .\staging\AJCC8_Hypopharyngeal_cancer.txt,% a_scriptdir "\RadTemplate"
    return
    :B0:orost2::
        sendbyclipboard("", 6)
        run,RadTemplate.exe .\staging\AJCC8_Oropharyngeal_cancer_with_p16.txt,% a_scriptdir "\RadTemplate"
    return
    :B0:orost1::
        sendbyclipboard("", 6)
        run,RadTemplate.exe .\staging\AJCC8_Oropharyngeal_cancer_without_p16.txt,% a_scriptdir "\RadTemplate"
    return
    :B0:lust::
        sendbyclipboard("", 4)
        run,RadTemplate.exe .\staging\AJCC8_Lung_cancer.txt,% a_scriptdir "\RadTemplate"
    return
    :B0:esst::
        sendbyclipboard("", 4)
        run,RadTemplate.exe .\staging\AJCC8_Esophageal_cancer.txt,% a_scriptdir "\RadTemplate"
    return

    :B0:tavi/::
        sendbyclipboard("", 5)
        run,RadTemplate.exe .\Procedure\TAVI.txt,% a_scriptdir "\RadTemplate"
    return
    :B0:tavip/::
        sendbyclipboard("", 6)
        run,RadTemplate.exe ".\Procedure\TAVI post.txt",% a_scriptdir "\RadTemplate"
    return

    renewReportHwnd:
        RisState:=RisOpened()
        gosub renewRisReports
        editHwnds:=getSimpleRisEditHwnds()
    return

    ::hmctem::
        ToolTip,
(
hmcbn0: no TOF, minimal leukoaraiosis
hmcbn1: no TOF, normal
hmcbn2: no TOF, +DWI, normal
hmcbn3: +TOF, normal
hmccmri: chest
hmcbmri: body
)
        settimer,ToolTip,-3000
    return
    ;~ HMC template
    :*:hmcbn3::
        insertTemplate("
(
MRI of head without contrast enhancement was performed including axial FLAIR, 3-D T1-weighted images for brain, T2-weighted images for neck, diffusion-weighted imaging for brain and neck and 3-D TOF MRA of cervicocranial arteries.

Radiological findings:
- No focal signal change in the brain parenchyma on FLAIR.
- Normal sized sulci, fissures and ventricles.
- No definite abnormality at the cervical portion of carotid and vertebral arteries as well as the circle of Willis portion of intracranial arteries.
- Normal appearance of the cranial vault and skull base.
- Clear paranasal sinuses.
- No obvious large neck mass or enlarged lymph nodes. However, mucosal lesion and small mass would be hard to detect in this study.
- No abnormal bright lesion on DWI.
)","
(
No obvious intracranial abnormality. 無明顯顱內異常
No obvious neck mass. 無明顯頸部腫塊
Normal MRA. 磁振血管造影無異狀
)")
    return

    :*:hmcbn1::
        insertTemplate("
(
MRI of brain and neck without contrast enhancement was performed including 3-D T1WI, axial FLAIR images of brain and axial T2WI for neck.

Radiological findings:
- No focal signal change in the brain parenchyma on FLAIR.
- Normal sized sulci, fissures and ventricles.
- No obvious intracranial space taking lesion.
- Normal appearance of the cranial vault and skull base
- Clear paranasal sinuses.
- No obvious large neck mass or enlarged lymph nodes. However, mucosal lesion and small mass would be hard to detect in this study.
)","
(
No obvious intracranial abnormality. 無明顯顱內異常
No obvious neck mass. 無明顯頸部腫塊
)")
    return

    :*:hmcbn0::
        insertTemplate("
(
MRI of brain and neck without contrast enhancement was performed including 3-D T1WI, axial FLAIR images of brain and axial T2WI for neck.

Radiological findings:
- Bilateral multiple tiny nonspecific hyperintensities over cerebral white matter on FLAIR.
- Normal sized sulci, fissures and ventricles.
- No obvious intracranial space taking lesion.
- Normal appearance of the cranial vault and skull base
- Clear paranasal sinuses.
- No obvious large neck mass or enlarged lymph nodes. However, mucosal lesion and small mass would be hard to detect in this study.
)","
(
Minimal nonspecific cerebral white matter change. 輕微非特異性腦白質變化.
No obvious neck mass. 無明顯頸部腫塊
)")
    return

    :*:hmcbn2::
        insertTemplate("
(
MRI of brain and neck without contrast enhancement was performed including 3-D T1WI, axial FLAIR images of brain, axial T2WI for neck and diffusion weighted imaging for brain and neck

Radiological findings:
- No focal signal change in the brain parenchyma on FLAIR.
- Normal sized sulci, fissures and ventricles.
- No obvious intracranial space taking lesion.
- Normal appearance of the cranial vault and skull base
- Clear paranasal sinuses.
- No obvious large neck mass or enlarged lymph nodes. However, mucosal lesion and small mass would be hard to detect in this study.
- No abnormal bright lesion on DWI.
)","
(
No obvious intracranial abnormality. 無明顯顱內異常
No obvious neck mass. 無明顯頸部腫塊
)")
    return

    :*:hmccmri::
        insertTemplate("
(
MRI of the chest with multiple pulse sequences (coronal, axial and sagittal T2 HASTE, axial turboFLASH T1, axial and coronal diffusion weighted images) is read with comparison of low dose chest CT on 20160615. This study shows:
- No definite mediastinal or hilar lymphadenopathy.
- No definite focal abnormality in bilateral lung parenchyma. However, there is limitation of evaluating tiny lung parenchymal abnormality in MRI. Correlation with low dose chest CT is suggested.
- No definite abnormal focal signal change on DWI.
)","
(
No definite abnormality in the screening chest MRI study. Suggest clinical correlation and follow up.
胸部磁振造影檢查無異常發現。建議臨床評估對照與追蹤。
)")
    return

    :*:hmcbmri::
        insertTemplate("
(
MRI of abdomen and pelvis without contrast enhancement for health examination shows:
- Liver: unremarkable.
- MRCP: unremarkable.
- Spleen: unremarkable.
- Pancreas: unremarkable.
- Kidneys: unremarkable.
- Adrenal glands: unremarkable.
- Great vessels: unremarkable.
- Uterus: unremarkable.
- Ovaries: unremarkable.
- Urinary bladder: unremarkable.
(MRI is not sensitive for small gastrointestinal lesions, urolithiasis, small ureteral tumors without hydronephrosis, small cervical and endometrial cancers.)
)","
(
No definite abnormality in the screening abdominal/pelvic MRI study. Suggest clinical correlation and follow up.
腹部磁振造影檢查無異常發現，建議臨床評估對照與追蹤。肝水泡。腎水泡。子宮肌瘤。
)")
    return

    ;~ cmdContextServer(str,hwnd=""){
    ;~ DetectHiddenWindows,on
    ;~ if !hwnd && !hwnd:=winexist("ahk_exe ImpaxContextServer.exe")
    ;~ return 1
    ;~ loop,parse,str
    ;~ {
    ;~ PostMessage,0x10303,,% asc(a_loopfield),,ahk_id %hwnd%
    ;~ sleep 20
    ;~ }
    ;~ PostMessage,0x10303,,0x0,,ahk_id %hwnd%

    ;~ }
    ;~ cmdContextServer(str,hwnd=""){
    ;~ oldDetectHiddenWindows:=A_DetectHiddenWindows
    ;~ DetectHiddenWindows,on

    ;~ Send_WM_COPYDATA(hwnd, 0, str)

    ;~ DetectHiddenWindows,% oldDetectHiddenWindows
    ;~ }

    showLungCAD:
        if WinExist("ahk_exe autorun.exe"){
            SendMessage,0x8100,,,,showLungCAD_main ahk_class AutoHotkeyGUI
            ;~ MsgBox % ErrorLevel
            return
        }
        ip:="http://10.0.0.1:8042/"
        chartNo:=getRisChartNo(RisState[2])

        dateStr:=SubStr(examDate,1,4) SubStr(examDate,6,2) SubStr(examDate,9,2)
        ;~ examDate:=getRisExamDate(RisOpened()[2])

        httprequest(url:=ip "patients/" SHA1dash(chartNo),post:="",header:="","charset: utf-8")
        if !post
            goto fail

        patient:=json_from(post)
        url:="",processed:=0
        Loop % patient.studies.maxindex() {
            httprequest(ip "studies/" patient.studies[A_Index],post:="",header:="","charset: utf-8")
            if !post
                continue
            study:=json_from(post)
            if(study.MainDicomTags.StudyDate=dateStr){
                Loop % study.series.maxindex() {
                    httprequest(ip "series/" study.series[A_Index],post:="",header:="","charset: utf-8")
                    if(!post)
                        continue
                    series:=json_from(post)
                    ;~ else if ()
                    if(series.MainDicomTags.SeriesDescription="Evidence Documents MM Oncology Reading"){
                        processed:=1
                    }else if(series.MainDicomTags.SeriesDescription="Results MM Oncology Reading" || series.MainDicomTags.SeriesDescription="Hologic R2 ImageChecker CAD SC"){
                        clipboard:=url:=ip "web-viewer/app/viewer.html?series=" study.series[A_Index]
                        break 2
                    }

                }
            }
        }
        if(url=""){
            if(processed)
                goto noResult
            else
                goto fail
        }

        ;~ test:
        ;~ clipboard:=url:=ip:="http://www.yahoo.com.tw/"

        ifwinexist,ahk_class MozillaWindowClass
            winactivate
else ifwinexist,ahk_class Chrome_WidgetWin_1
    WinActivate
else
    goto openNewChromeOrFirefox

        winwaitactive,,,2
        if(ErrorLevel)
            return

        if !InStr(activeUrl:=GetActiveBrowserURL(),ip) && activeUrl!="" {
            send % "^t"
            Sleep 100
        }
        send % "!d"
        sleep 100
        send % "^v"
        sleep 100
        send % "`n"
    recoverClip:
    return
    openNewChromeOrFirefox:
        appPath:=""
        Loop,% a_desktop "\*.lnk"
            if InStr(A_LoopFileName, "firefox"){
                FileGetShortcut,% A_LoopFileFullPath, appPath
                break
            }
        if(appPath!=""){
            run % """" appPath """ """ url """"
            return
        }
        Loop,% A_DesktopCommon "\*.lnk"
            if InStr(A_LoopFileName, "firefox"){
                FileGetShortcut,% A_LoopFileFullPath, appPath
                break
            }
        if(appPath!=""){
            run % """" appPath """ """ url """"
            return
        }
        Loop,% a_desktop "\*.lnk"
            if InStr(A_LoopFileName, "chrome"){
                FileGetShortcut,% A_LoopFileFullPath, appPath
                break
            }
        if(appPath!=""){
            run % """" appPath """ """ url """"
            return
        }
        Loop,% A_DesktopCommon "\*.lnk"
            if InStr(A_LoopFileName, "chrome"){
                FileGetShortcut,% A_LoopFileFullPath, appPath
                break
            }
        if(appPath!=""){
            run % """" appPath """ """ url """"
            return
        }
        MsgBox % "Please open Firefox or Chrome first!"
    return

    noResult:
        MsgBox,,,% "No lesion found by CAD",3
        goto recoverClip
    return

    fail:
        if !InStr(A_ScriptName, "mammo")
            settimer,dcmqr,-1
        goto recoverClip
    return

    dcmqr:
        if !IsObject(dcmRAID)
            dcmRAID:=new dcm4che(), dcmSyngovia:= new dcm4che("SYNGOVIA")
        ;~ MsgBox % dcmRAID.root "," dcmRAID.dcmqrPath
        seriesInfoSyngovia:=dcmSyngovia.getSeriesInfo(thisAccNo:=getRisAccNo((RisState:=RisOpened())[2]))
        ;~ MsgBox % seriesInfo.maxindex()
        if(seriesInfoSyngovia.maxindex()>0){
            MsgBox,,,Not processed yet in Syngovia!,3
            return
        }

        seriesInfo:=dcmRAID.getSeriesInfo(thisAccNo)
        if(seriesInfo.maxindex()<1){
            msgbox,,,Not found in RAID!,3
            return
        }
        gui,dcmqr:Default
        gui,destroy
        for k,v in seriesInfo {
            ;~ MsgBox % v.SeriesDescription
            gui,Add,Checkbox,% "vdcmqrCb" k " w400 " (v.InstanceCount>300?"checked":""),% v.SeriesDescription " (" v.InstanceCount ")"
        }
        gui,Add,button,gdcmqrSubmit,to Syngovia
        gui,show,AutoSize,Select series
    return

    dcmqrSubmit:
        gui,Submit
        for k,v in seriesInfo {
            if (dcmqrCb%k%)
                dcmRAID.Move([v.SeriesUID], "SYNGOVIA")
        }

    return

    SHA1dash(str){
        str:=SHA(str)
        stringlower,str,str
        return substr(str,1,8) "-" substr(str,9,8) "-" substr(str,17,8) "-" substr(str,25,8) "-" substr(str,33,8)
    }

    #z::
        KeyWait,lwin,t1
        KeyWait,z,t1
        checkRis(RisState)
        ;~ PostMessage,0x2021,,,,ahk_exe simpleRIS.exe
        gosub renewRisReports
        ExamItems:=parseRisExamItems(getRisExamItems(RisOpened()[2]))
            ,str:=""
            ,cChartNo:=getRisChartNo(RisState[2])
            ,cAccNo:=getRisAccNo(RisState[2])
        if InStr(ExamItems[1,1], "requesting"){
            goto _qq
        }
        risOpenOldStudy(RisState[2],false,true)
        ;~ ToolTip % cChartNo
        ;~ if (cChartNo~="^(H|Y)" && WinExist("ahk_exe EBMpreload.exe"))
        PostMessage,0x2021,,,,EBM Preload ahk_class AutoHotkeyGUI
        ;~ else
        ;~ openRisStudy()
        ;~ PostMessage,0x2026,,,,simple RIS ahk_class AutoHotkeyGUI

        for k,ExamName in ExamItems[1]
            str.=examName "; "
        report:="Chart No: " cChartNo ".`r`nEXAMINATION: " SubStr(str,1,-2) ".`r`nFindings: `r`n- "
            ,setReportText(report, "", RisReports,1)
        ;~ Sleep 1000
        ;~ winactivate,simple RIS ahk_class AutoHotkeyGUI
        PostMessage,0x10103,,,,HotstringHintMain ahk_class AutoHotkeyGUI
    return

    #c::
        checkRis(RisState)
        ;~ PostMessage,0x2021,,,,ahk_exe simpleRIS.exe
        gosub renewRisReports

        ExamItems:=parseRisExamItems(getRisExamItems(RisOpened()[2]))
            ,hasChest:=false
        for k,ExamName in ExamItems[1]
            if (ExamName~="is)CT.+Chest|lung|EPS"){
                hasChest:=true
                break
            }else if (examName=""){
                RisState:=RisOpened()
                return
            }

        ;~ cChartNo:=getRisChartNo(RisState[2])
        ;~ if (cChartNo!=getImpaxChartNo()){
        if !RisChartNoMatchPacs(RisState, ImpaxState, cChartNo){
            if (isChartNo(cChartNo).pacsViewer="EBM" && WinExist("EBM Preload ahk_class AutoHotkeyGUI"))
                PostMessage,0x2020,,,,EBM Preload ahk_class AutoHotkeyGUI
            else
                openRisStudy()
        }

        if(!hasChest){
            cChartNo:=getRisChartNo(RisState[2])
            ;~ ToolTip % cChartNo

            return
        }

        ;~ RisReports:=getRisReports(RisState[2])

        thisReport:=controlgettext(RisReports[1,1])
        if(Trim(thisReport)=""){
            ;~ HideImpax(true)
            goto chestCTtemplate
        }else if !(thisReport~="INDICATION:[\w\W]+?TECHNIQUE:[\w\W]+?(COMPARISON:[\w\W]+?)?FINDINGS:") {
            ;~ if (cChartNo!=getImpaxChartNo()){
            ;~ openRisStudy()
            ;~ }
            return
        }

        priorReport:=chestTemplateSplit(controlgettext(RisReports[2,1]))
            ,thisReport:=chestTemplateSplit(thisReport)
            ,copiedReport:=RegExReplace(thisReport[1] priorReport[2] thisReport[3],"(\r\n){2,}","`r`n")

            ,regexmatch(priorReport[2],"\s*[-\*] [^\r\n]+(\r?\n\s*([-\*]+ |\d+\W+)[^\r\n]+)?",match)
            ,copiedReport:=RegExReplace(copiedReport, "\(<=?5mm|\(<=?4mm", "(<6mm")

        controlsettext,,% text:=RegExReplace(copiedReport,"i) *\([\d\.\,mc ]*?((SE|IM)[^\)]+)[\d\.mc ]*?\)",""),% "ahk_id " risreports[1,1]

        controlsettext,,% controlgettext(RisReports[2,2]),% "ahk_id " RisReports[1,2]
        Edit_SetSel(RisReports[1,1],sel:=strlen(thisReport[1] match),sel)
        Edit_ScrollCaret(RisReports[1,1])

        if simpleRis:=winexist("simple RIS ahk_class AutoHotkeyGUI") {
            editHwnds:=getSimpleRisEditHwnds()
                ,Edit_SetText(editHwnds[2], text)
                ,Edit_SetSel(editHwnds[2],sel,sel)
                ,Edit_SetText(editHwnds[1], text)
                ,Edit_SetSel(editHwnds[1],sel,sel)
                ,Edit_ScrollCaret(editHwnds[2])
        }
    ;~ HideImpax(false)
    return

    openRisStudy(){
        PostMessage,0x2026,,,,simpleRIS_main ahk_class AutoHotkeyGUI
        ;~ SendLevel,2
        ;~ winactivate,simple RIS ahk_class AutoHotkeyGUI.exe
        ;~ WinWaitActive,simple RIS ahk_class AutoHotkeyGUI,,3
        ;~ send {F5}
    }

    HideImpax(toggle){
        if !WinExist("ahk_exe AntiImpaxFlash.exe"){
            run % A_ScriptDir "\AntiImpaxFlash.exe"
            Loop
                Sleep 50
            until WinExist("ahk_exe AntiImpaxFlash.exe") || (A_Index>100)
        }
        PostMessage,0x10305,,% toggle=""?"":!!toggle,,AntiImpaxFlash ahk_class AutoHotkey
    }

    chestTemplateSplit(text){
        arr:=[],mid:=0
        loop,parse,text,`n,`r
        {
            if regexmatch(a_loopfield,"is)^\s*([-\*]+ |\d+\W+).*",match)
                arr.2:=arr.2 match "`r`n",mid:=1
            else
                arr[1+mid*2]:=arr[1+mid*2] a_loopfield "`r`n"
        }
        return arr
    }

    resetSimpleRis(){
        PostMessage,0x2024,1,,,simpleRIS_main ahk_class AutoHotkeyGUI
    }
    simpleRISBlack(){
        PostMessage,0x2029,1,,,simpleRIS_main ahk_class AutoHotkeyGUI
    }
    PauseSimpleRis(){
        PostMessage,0x2023,3000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
    }

    ^!y::
    editCCTAreport:
        FocusedHwnd:=getFocusedHwnd()
            ,pText:=Edit_GetText(FocusedHwnd)
            ,pText:=RegExReplace(pText, "(\r?\n)\* ", "$1- ")
            ,Edit_SetText(FocusedHWND, pText)
    return

    ribNo:
        if($.value(1)="l")
            str:="left"
        else if($.value(1)="r")
            str:="right"
        else if($.value(1)="b")
            str:="bilateral"

        str.=" " $.value(2)

        if (SubStr($.value(2),0,1)="1")
            str.="st"
        else if (SubStr($.value(2),0,1)="2")
            str.="nd"
        else if (SubStr($.value(2),0,1)="3")
            str.="rd"
        else
            str.="th"

        str.=" rib" ($.value(1)="b"?"s":"")
        send % "{bs " StrLen($.value(0))  "}"
        ;~ Sleep 50
        sendByClipboard(str $.value(3))
        $:=""
    return

    degenerativeSpine($){
        static spinekylorsco:={k:"kyphosis",l:"lordosis",s:"scoliosis"}
            , spine_findings:=["marginal osteophyte formation", "dehydrated disc", "dehydrated narrowed disc", "facet joint arthroses", "hypertrophic ligamenta flava"]
        send % "{bs " StrLen($.value(0))  "}"
        ret:=spineParts($.value(1))
            ,ret.=" spondylosis"
        k:=$.value(2)
        Loop,parse,k
            if spinekylorsco.HasKey(A_LoopField)
                ret.="/" spinekylorsco[A_LoopField]
        ret.=" "
            ,k:=$.value(3)

            ,_findings_str:=""
        Loop,parse,k
            _findings_str.=spine_findings[A_LoopField] ", "
        ret.=(_findings_str=""?"":"with " RegExReplace(SubStr(_findings_str,1,-2), ", ([^,]+)$", " and $1")) $.value(4)
        sendByClipboard(ret)
        $:=""

    }

    spineParts(str, delim="-"){
        static arr:={c: "cervical", c_:"cervico"
            ,t: "thoracic", t_: "thoraco"
            ,l: "lumbar", l_: "lumbo"
            ,s: "sacral", s_: "sacro"}
        ret:=""
        Loop,parse,str
        {
            if arr.HasKey(A_LoopField)
                ret.=arr[(last:=A_LoopField) "_"] delim
        }
        return SubStr(ret,1,-2 - StrLen(delim)) SubStr(arr[last],-2)
    }

    ToolTip:
    ToolTip
    return

    ;abbr
    :cB0:ica::
        sendByClipboard("ICA" A_EndChar,3)
    return
    :cB0:aca::
        sendByClipboard("ACA" A_EndChar,3)
    return
    :cB0:mca::
        sendByClipboard("MCA" A_EndChar,3)
    return
    :cB0:icas::
        sendByClipboard("ICAs" A_EndChar,4)
    return
    :cB0:acas::
        sendByClipboard("ACAs" A_EndChar,4)
    return
    :cB0:mcas::
        sendByClipboard("MCAs" A_EndChar,4)
    return
    :cB0:sca::
        sendByClipboard("SCA" A_EndChar,3)
    return
    :cB0:m1::
        sendByClipboard("M1" A_EndChar,2)
    return
    :cB0:m2::
        sendByClipboard("M2" A_EndChar,2)
    return
    :cB0:a1::
        sendByClipboard("A1" A_EndChar,2)
    return
    :cB0:a2::
        sendByClipboard("A2" A_EndChar,2)
    return
    :cB0:p1::
        sendByClipboard("P1" A_EndChar,2)
    return
    :cB0:p2::
        sendByClipboard("P2" A_EndChar,2)
    return
    :cB0:pca::
        sendByClipboard("PCA" A_EndChar,3)
    return
    :cB0:pcas::
        sendByClipboard("PCAs" A_EndChar,4)
    return
    :cB0:eca::
        sendByClipboard("ECA" A_EndChar,3)
    return
    :cB0:ecas::
        sendByClipboard("ECAs" A_EndChar,4)
    return
    :cB0:mma::
        sendByClipboard("MMA" A_EndChar,3)
    return
    :cB0:mmas::
        sendByClipboard("MMAs" A_EndChar,4)
    return
    :cB0:cca::
        sendByClipboard("CCA" A_EndChar,3)
    return
    :cB0:ccas::
        sendByClipboard("CCAs" A_EndChar,4)
    return
    :cB0:pica::
        sendByClipboard("PICA" A_EndChar,4)
    return
    :cB0:aica::
        sendByClipboard("AICA" A_EndChar,4)
    return
    :cB0:va::
        sendByClipboard("VA" A_EndChar,2)
    return
    :cB0:picas::
        sendByClipboard("PICAs" A_EndChar,5)
    return
    :cB0:aicas::
        sendByClipboard("AICAs" A_EndChar,5)
    return
    :cB0:vsa::
        sendByClipboard("VAs" A_EndChar,3)
    return
    :cB0:ba::
        sendByClipboard("BA" A_EndChar,2)
    return
    :cB0:sov::
        sendByClipboard("SOV" A_EndChar,3)
    return
    :cB0:ccf::
        sendByClipboard("CCF" A_EndChar,3)
    return
    :cB0:avf::
        sendByClipboard("AVF" A_EndChar,3)
    return
    :cB0:avm::
        sendByClipboard("AVM" A_EndChar,3)
    return
    :cB0:tof::
        sendByClipboard("TOF" A_EndChar,3)
    return
    :cB0:flair::
        sendByClipboard("FLAIR" A_EndChar,5)
    return
    :cB0:mri::
        sendByClipboard("MRI" A_EndChar,3)
    return
    :cB0:ct::
        sendByClipboard("CT" A_EndChar,2)
    return
    :cB0:mtt::
        sendByClipboard("MTT" A_EndChar,3)
    return
    :cB0:cbf::
        sendByClipboard("CBF" A_EndChar,3)
    return
    :cB0:cbv::
        sendByClipboard("CBV" A_EndChar,3)
    return
    :cB0:ich::
        sendByClipboard("ICH" A_EndChar,3)
    return
    :cB0:ichs::
        sendByClipboard("ICHs" A_EndChar,4)
    return
    :cB0:sah::
        sendByClipboard("SAH" A_EndChar,3)
    return
    :cB0:sahs::
        sendByClipboard("SAHs" A_EndChar,4)
    return
    :cB0:sdh::
        sendByClipboard("SDH" A_EndChar,3)
    return
    :cB0:sdhs::
        sendByClipboard("SDHs" A_EndChar,4)
    return
    :cB0:edh::
        sendByClipboard("EDH" A_EndChar,3)
    return
    :cB0:edhs::
        sendByClipboard("EDHs" A_EndChar,4)
    return
    :cB0:ijv::
        sendByClipboard("ijv" A_EndChar,3)
    return

    :cB0:ihds::
        sendByClipboard("IHDs" A_EndChar,4)
    return
    :cB0:cbd::
        sendByClipboard("CBD" A_EndChar,3)
    return

    :cB0:rv::
        sendByClipboard("RV" A_EndChar,2)
    return
    :cB0:la::
        sendByClipboard("LA" A_EndChar,2)
    return
    :cB0:ra::
        sendByClipboard("RA" A_EndChar,2)
    return

    :cB0:svc::
        sendByClipboard("SVC" A_EndChar,3)
    return

    ;~ getFocusedHwnd(){
    ;~ static GuiThreadInfoSize = 48
    ;~ VarSetCapacity(GuiThreadInfo, GuiThreadInfoSize)
    ;~ NumPut(GuiThreadInfoSize, GuiThreadInfo, 0)
    ;~ DllCall("GetGUIThreadInfo", uint, 0, str, GuiThreadInfo)
    ;~ return FocusedHWND := NumGet(GuiThreadInfo, 12)
    ;~ }

    ;~ focusedEditBS(bs, hwnd=""){
    ;~ sendByClipboard("", bs, hwnd)
    ;~ }

    sendByEdit(byref str, bs="", hwnd=""){
        ; global __HotstringEnhancer_pClipboard
        ; sendlevel,0
        ; !!assumption: no selection range!!
        static focused, focused_p, sci, cached:=[]
        return sendByClipboard(str, StrLen(bs))
        if(hwnd!="" && WinExist("ahk_id " hwnd))
            focused:=hwnd
        else
            focused:=getFocusedHwnd()

        ;~ Edit_InsertText(focused, str)
        ;~ if(bs!="")
        ;~ {
        ;~ KeyWait, % SubStr(bs,-1,1),t0.2
        ;~ send % "{bs " StrLen(bs) "}"
        ;~ }
        ;~ Edit_DeleteText(focused, "", StrLen(bs))

        wingetclass,class,ahk_id %focused%
        if(class="Scintilla"){
            if(focused_p!=focused)
                sci:=new RemoteScintilla(focused)
            if(bs!=""){
                if (StrLen(bs)>=sci.GetTextLength()) {
                    resetSimpleRis()
                    Sleep 50
                }else{
                    KeyWait, % SubStr(bs,0,1),T0.2
                    bsLen:=StrLen(bs)
                    sci.DeleteRange(sci.getCurrentPos()-bsLen, bsLen)
                }
            }
            if(str!="")
                sci.AddText(str)
            focused_p:=focused
        }else{
            ;~ t:=ControlGetText(focused), Edit_GetSel(focused, s, e)
            ;~ ,bsLen:=StrLen(bs)
            ;~ if(bsLen)
            ;~ s:=e:=s-bsLen>=0?s-bsLen:0
            ;~ t:=(s>=0?SubStr(t, 1, s):"") str SubStr(t, s+bs+1)
            ;~ ,Edit_SetText(focused, t)
            ;~ ,e:=(s+=StrLen(str))
            ;~ ,Edit_SetSel(focused, s, e)
            if(bs!=""){
                KeyWait, % SubStr(bs,0,1),T0.2
                send % "{bs " StrLen(bs) "}"
            }
            Sleep 20
            sendByClipboard(str)

        }
        blockinput,mousemove
        resetHotstringBuffer(-1)
        blockinput,mousemoveoff
    }

    AppsKey & z::
        ToolTip,
(

1 2 3
T H R

A F G
S C B

W E Q
Z
)
        settimer, ToolTip, -5000
    return

    ; for feedRIS
    :B0:imp::
        sendByClipboard("`n-=-=-=-=-`n",3)
    return

    ; CCTA

    :B0:cpq::
        sendByClipboard("calcified plaque" A_EndChar,3)
    return
    :*B0:cpq1::
        sendByClipboard("calcified plaques",3)
    return
    :B0:npq::
        sendByClipboard("noncalcified plaque" A_EndChar,3)
    return
    :*B0:npq1::
        sendByClipboard("noncalcified plaques",3)
    return
    :B0:mpq::
        sendByClipboard("mixed plaque" A_EndChar,3)
    return
    :*B0:mpq1::
        sendByClipboard("mixed plaques",3)
    return

    :*B0:ds1::
        sendByClipboard("minimal (<25%) stenosis",2)
    return
    :*B0:ds2::
        sendByClipboard("mild (25%-49%) stenosis",2)
    return
    :*B0:ds3::
        sendByClipboard("moderate (50%-69%) stenosis",2)
    return
    :*B0:ds4::
        sendByClipboard("severe (70%-99%) stenosis",2)
    return
    :*B0:ds5::
        sendByClipboard("total occlusion",2)
    return

    :C*B0:plad::
        sendByClipboard("pLAD",3)
    return
    :C*B0:mlad::
        sendByClipboard("mLAD",3)
    return
    :C*B0:dlad::
        sendByClipboard("dLAD",3)
    return
    :C*B0:plcx::
        sendByClipboard("pLCX",3)
    return
    :C*B0:mlcx::
        sendByClipboard("mLCX",3)
    return
    :C*B0:dlcx::
        sendByClipboard("dLCX",3)
    return
    :C*B0:prca::
        sendByClipboard("pRCA",3)
    return
    :C*B0:mrca::
        sendByClipboard("mRCA",3)
    return
    :C*B0:drca::
        sendByClipboard("dRCA",3)
    return

    :B0:ccta::
        sendbyclipboard("", 4)
        run,RadTemplate.exe ".\Procedure\ccta.txt",% a_scriptdir "\RadTemplate\"
    return

    ;----------------------------------------------------------------------------------
    ;0 No detectable calcified plaque
    ;1-10 Minimal detectable calcified plaque
    ;11-100 Mild atherosclerotic plaque burden
    ;101-400 Moderate atherosclerotic plaque burden
    ;>400 Extensive atherosclerotic plaque burden

    :*:cstem::
        report=
(
Agatston calcium score:
- LM: 0
- LAD: 0
- LCX: 0
- RCA: 0
- Total: 0 (No detectable calcified plaque)

Other findings:
- No obvious abnormality in visible lung.
- Degenerative change of spine.
)
        imp=
(
Calcium score: 0
)
        setReportText(report, imp, getRisReports(RisState[2]))
    return

    ::cals::
        ;~ sendByClipboard("", 4)
        WinGet, active_id, ID, A
        InputBox, CCS,,Calcium score:,,200,120
        ;~ clipboard=%CCS%

        Rank=Error

        if (CCS = 0)
        {
            Rank=No detectable calcified plaque
        }
        if (CCS >0)
        {
            Rank=Minimal detectable calcified plaque
        }
        if (CCS >10)
        {
            Rank=Mild atherosclerotic plaque burden
        }
        if (CCS >100)
        {
            Rank=Moderate atherosclerotic plaque burden
        }
        if (CCS >400)
        {
            Rank=Extensive atherosclerotic plaque burden
        }

        WinActivate, ahk_id %active_id%
        WinWaitActive,ahk_id %active_id%,,3
        ;~ SendPlay %CCS% (%Rank%)%A_EndChar%
        if(Rank="error")
            return
        sendByClipboard(CCS " (" Rank ")")
    return

    :*B0:ld0::
        sendByClipboard("肺部：無異常。",2)
    return
    :*B0:ld1::
        sendByClipboard("肺部：無異常。請詳閱影像報告。",2)
    return
    :*B0:ld2::
        sendByClipboard("肺部：無顯著異常。請詳閱影像報告。",2)
    return
    :*B0:ld3::
        sendByClipboard("肺部：有異常。請詳閱影像報告。",2)
    return
    :*B0:ld4::
        sendByClipboard("肺部：明顯異常。請詳閱影像報告。",2)
    return
    :*B0:ld5::
        sendByClipboard("肺部：疑似惡性腫瘤。請詳閱影像報告。",2)
    return

    RisStateChange(){
        global RisState
        RisState:=risopened()
        MammoPdfDB_FireOnRisChange()
    }

    bodyCysts:
        cysts_parts := $.value(1)
            ,str:="hypodense lesions in "
            ,parts:=[]
            ,parts_ref:={h: "liver", r: "kidney", s: "spleen", p: "pancreas"}
        for k,v in ["h", "k", "s", "p"]
            if InStr(cysts_parts,v)
                parts.push(parts_ref[v])
        for k,v in parts
            str.= v (k==parts.length()-1?" and ":", ")
        str:=SubStr(str,1,-2) ", cysts are considered first."
        send % "{bs " StrLen($.value(0))  "}"
        sendByClipboard(str)
        $:=""
    return

    :*:epsct::
        setReportText("Indication: this study is for CT image integration of electroanatomical mapping. `r`nFindings: `r`n" bullet,"This study is for CT image integration of electroanatomical mapping. ")
    return

    reportReplace(Text){
        Text:=RegExReplace(Text, "i)a (stable|stationary) *(\W)", "an unchanged$2")
            ,Text:=RegExReplace(Text, "i)(stable|stationary) *(\W)", "unchanged$2")
            ,Text:=RegExReplace(Text, "(\r?\n[ \t]*){2,}$", "`r`n`r`n")
            , Text:=RegExReplace(Text, "i)phayngeal", "phayrngeal")
            , Text:=RegExReplace(Text, "i)no enlarge ", "no enlarged ")
            , Text:=RegExReplace(Text, "LAPs?", "lymphadenopathy")
            , Text:=RegExReplace(Text, "i)\bsusp\.?\b", "suspicious")
            , Text:=RegExReplace(Text, "i)\bLt\.?\b", "left")
            , Text:=RegExReplace(Text, "i)\bRt\.?\b", "right")
            , Text:=RegExReplace(Text, "i)BI-RAD", "B_I_R_A_D")
            , Text:=RegExReplace(Text, "i)\bBil?\.?\b", "bilateral")
            , Text:=RegExReplace(Text, "B_I_R_A_D", "BI-RAD")
        return Text
    }

    :*B0:gtran::
        sendByClipboard("（本翻譯結果由Google Translate提供，請務必與專業醫師討論本報告內容）",4)
    return

    /*
    dynamic_hotstring(
    	trigger:
    		A string or a regular expression to trigger the hotstring. (If you use a regex here, the mode should be 3 for the regex to work)

    	label:
    		A string to replace the trigger / A label to go to / A function to call when the hotstring is triggered.
    		If you used a regular expression as the trigger and mode was set to three, backreferences like $0, $1 would work.
    		If a function name was passed, the function will be called with the phrase that triggered the hotstring(If the trigger was a string)
    			or the Match object(If the trigger was a regex & mode equals 3).
    		If this parameter was a label, the global variable '$' will contain the string/match object.
    		If you wish to remove a hotstring, Pass the trigger with this parameter empty.

    	Mode:
    		A number between 1 and 3 that determines the properties of the hotstring.
    		If Mode == 1 then the hotstring is case insensitive.
    		If Mode == 2 then the hostrings is case sensitive.
    		If Mode == 3 then you can use regex in the trigger.

    		1 is the defualt.

    	clearTrigger:
    			Determines if the trigger is erased after the hotstring is triggered.

    	cond:
    			A name of a function that allows the conditional trigerring of the hotstring.

    )
    */
    dynamic_hotstring(trigger, label, mode := 1, clearTrigger := 1, cond := "", forceBreak:=false){
        global $

        ;symbols exclude ' \ for special use in this script
        static keysBound := false,hotkeyPrefix := "~$", dynamic_hotstrings := {}, typed := "", keys := {"symbols": "!""#$%&()*+,-.:;<=>?@[/]^_``{|}~", "num": "0123456789", "alpha":"abcdefghijklmnopqrstuvwxyz", "other": "BS,Return,Tab,Space", "breakKeys":"Left,Right,Up,Down,Home,End,RButton,LButton,LControl,RControl,AppsKey,LAlt,RAlt,Lwin,Rwin,WheelDown,WheelUp,f1,f2,f3,f4,f5,f6,f7,f8,f9,f6,f7,f9,f10,f11,f12", "numpad":"Numpad0,Numpad1,Numpad2,Numpad3,Numpad4,Numpad5,Numpad6,Numpad7,Numpad8,Numpad9,NumpadDot,NumpadDiv,NumpadMult,NumpadAdd,NumpadSub,NumpadEnter"}, effect := {"Return" : "`n", "Tab":A_Tab, "Space": A_Space, "Enter":"`n", "Dot": ".", "Div":"/", "Mult":"*", "Add":"+", "Sub":"-"}

        if(forceBreak){
            typed := ""
            return
        }

        ; A scoped PACS digit handler needs to distinguish report typing
        ; from a viewer command before sending view/focus-changing keys.
        if (mode == "MAMMO_TITLE_PENDING")
            return RegExMatch(typed, "i)\b[lrb]m?mci?[0-5]$") != 0

        if (!keysBound){
            ;Binds the keys to watch for triggers.
            for k,v in ["symbols", "num", "alpha"]
            {
                ;alphanumeric/symbols
                v := keys[v]
                Loop,Parse, v
                    Hotkey,%hotkeyPrefix%%A_LoopField%,__dynamic_hotstring
            }

            v := keys.alpha
            Loop,Parse, v
                Hotkey, %hotkeyPrefix%+%A_Loopfield%,__dynamic_hotstring
            for k,v in ["other", "breakKeys", "numpad"]
            {
                ;comma separated values
                v := keys[v]
                Loop,Parse, v,`,
                    Hotkey,%hotkeyPrefix%%A_LoopField%,__dynamic_hotstring
            }
            keysBound := true ;keysBound is a static varible. Now, the keys won't be bound twice.
        }
        if (mode == "CALLBACK"){
            ; AHK shares the first-created name across hotkey variants:
            ; the static 1::/2:: names remain "1"/"2" even in the global
            ; ~$ watcher. Strip actual hook prefixes, not two characters.
            ; Keep at least one character for literal $, * and ~ keys.
            Hotkey := RegExReplace(trigger != "" ? trigger : A_ThisHotkey, "^[~$*]+(?=.)")
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
            } else if (RegExMatch(Hotkey, "i)^Numpad(.+)$", numKey)) {
                if (numkey1 ~= "\d"){
                    typed .= numkey1
                } else {
                    typed .= effect[numKey1]
                }
            } else {
                typed .= Hotkey
            }
            matched := false
            ;~ ToolTip % "." typed "."
            for k,v in dynamic_hotstrings
            {
                matchRegex := (v.mode == 1 ? "Oi)" : "")  . (v.mode == 3 ? RegExReplace(v.trigger, "\$", "") : "\Q" . v.trigger . "\E") . "$"

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
                        ; If dynamic_hotstring has a condition function.
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
                        SendEvent % "{BS " . StrLen(local$.Value(0))  . "}"
                        ;~ focusedEditBs(StrLen(local$.Value(0)))
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
                        SendEvent,%toSend%
                    }

                }
            }
            if (matched){
                typed := ""
            } else if (StrLen(typed) > 350){
                StringTrimLeft,typed,typed,200
            }
        } else {
            if (dynamic_hotstrings.HasKey(trigger) && label == ""){
                ; Removing a dynamic_hotstring.
                dynamic_hotstrings.Delete(trigger)
            } else {
                ; Add to dynamic_hotstrings object.
                dynamic_hotstrings[trigger] := {"trigger" : trigger, "label":label, "mode":mode, "clearTrigger" : clearTrigger, "cond": cond}
            }

        }
        return

        __dynamic_hotstring:
        ; This label is triggered every time a key is pressed.
        dynamic_hotstring("", "", "CALLBACK")
        return
    }

    insertDate($){
        send % "{bs " StrLen($.value(0))  "}"
        s:=$.value(1)
        if ($.value(2))
            s:=substr(s,5,strlen(s)-4) substr(s,1,4)

        if strlen(s)=6
            if substr(s,1,2)<80
                s:="20" s
            else
                s:="19" s
        if (substr(s,5,2)>12 || substr(s,7,2)>31) {
            sendByClipboard($.value(0))
            return
        }

        Sleep 50
        sendByClipboard(substr(s,1,4) $.value(3) substr(s,5,2) $.value(3) substr(s,7,2))
    }

    :*:im/::
        if WinActive("simple RIS ahk_class AutoHotkeyGUI")
            txt:=RegExReplace(Edit_GetText(activeHwnd:=getFocusedHwnd()), "im\/?(\r?\n)", "$1")
                ,txt:=RegExReplace(txt, "\s*(- \r?\n?)*\s*$", "")
                ,Edit_SetText(activeHwnd, txt.="`r`n`r`nImpression:`r`n")
                ,Edit_SetSel(activeHwnd, l:=StrLen(txt), l)
                ,Edit_ScrollCaret(activeHwnd)
        else{
            __str:="impression:`r`n"
            sendByClipboard(__str)
        }
    return

    :B0:pm0::
        sendByClipboard("通報臨床醫師0" A_EndChar,3)
    return
    :B0:pm1::
        sendByClipboard("通報臨床醫師1" A_EndChar,3)
    return
    :B0:pm2::
        sendByClipboard("通報臨床醫師(急)" A_EndChar,3)
    return
    :B0:pmtb::
        sendByClipboard("疑似肺結核" A_EndChar,4)
    return

    :B0:dbs::
        sendByClipboard("placement of implantable electronic stimulation devices." A_EndChar,3)
    return
    :B0:mnf::
        sendByClipboard("minor or non-specific findings." A_EndChar,3)
    return

    :*B0:mlss::
        sendByClipboard("spinal stenosis at multiple levels",3)
    return
    :*B0:mlse::
        sendByClipboard("spinal stenosis at multiple levels, most evident at",3)
    return
    ::lsms::
        quicksendFunc("lsms", "lumbar spondylosis. spinal stenosis at multiple levels. suggest clinical correlation.")
    return
    ::csms::
        quicksendFunc("lsms", "cervical spondylosis. spinal stenosis at multiple levels. suggest clinical correlation.")
    return
    :B0:vcu::
        sendByClipboard("vacuum phenomenon" A_EndChar,3)
    return

    quicksendFunc(trigger, hotstring){
        global thishotkey, __win11__

        if (__win11__){
            focusedHwnd:=getFocusedHwnd()
            txt:=Edit_GetText(focusedHwnd)
            l:=strlen(trigger)
            txt:=substr(txt,1,-1*l)
            edit_setText(focusedHwnd, txt:=txt hotstring ".")
            ;~ sendinput % hotstring

            sleep 300
            gosub quicksend
        }
        focusedHwnd:=getFocusedHwnd()
            ,triggerRegex:=""
            ,Edit_GetSel(focusedHwnd,s,e)
        loop,parse,trigger
            triggerRegex.=((A_LoopField~="\W")?"\":"") A_LoopField (A_Index=1?"":"?")
        RegExMatch(SubStr(t:=Edit_GetText(focusedHwnd), 1, e), "i)" triggerRegex "$", match)
        Edit_SetText(focusedHwnd, t:=SubStr(t,1,e-StrLen(match)) Hotstring SubStr(t,1+e))
        thishotkey:="F3"
        gosub quicksend
    }

    brainAging($){
        send % "{bs " strlen($.value(0)) "}"

        atrophyLevel:=$.value(1)
            ,leuLevel:=$.value(2)
            ,ending:=$.value(3)
            ,str:=""

        switch atrophyLevel {
        case 1:
            str:="Mild brain atrophy with dilated sulci, fissures and ventricles. "
        case 2:
            str:="Brain atrophy with dilated sulci, fissures and ventricles. "
        case 3:
            str:="Prominent brain atrophy with dilated sulci, fissures and ventricles. "
        }
        str.="`r`n- "

        if InStr(getRisExamItemsAll()[1], "MR"){
            switch leuLevel {
            case 0:
                str.="Some hyperintensities over bilateral cerebral white matter on FLAIR, suggestive of minimal leukoaraiosis. "
            case 1:
                str.="Some hyperintensities over bilateral cerebral white matter on FLAIR, suggestive of mild leukoaraiosis. "
            case 2:
                str.="Multiple nonspecific hyperintensities over bilateral cerebral white matter on T2 FLAIR, suggestive of leukoaraiosis. "
            case 3:
                str.="Confluent nonspecific hyperintensities over bilateral cerebral white matter on T2 FLAIR, suggestive of extensive leukoaraiosis. "
            }
        }else{
            switch leuLevel {
            case 0:
                str.="Low densities at bilateral periventricular white matter, suggestive of minimal leukoaraiosis. "
            case 1:
                str.="Low densities at bilateral periventricular white matter, suggestive of mild leukoaraiosis. "
            case 2:
                str.="Low densities at bilateral periventricular white matter, suggestive of leukoaraiosis. "
            case 3:
                str.="Confluent low densities at bilateral periventricular white matter, suggestive of leukoaraiosis. "
            }
        }
        str.="`r`n- "

        sendByClipboard(str)
    }

    :*:abus0::
        t=
(
Ultrasongraphic examination of abdomen:

Liver: Homogeneous echopattern without focal lesions.
Intrahepatic Bile Duct: Negative.
Common Bile Duct: Negative.
Portal Vein: Negative.
Gall Bladder: No stone.
Pancreas: Negative.
Spleen: Negative.
Kidneys: No stone or hydronephrosis.

Impression:
No abnormal findings in the abdomen.
)
        sendByClipboard(t)
    return

    :*:cyss::
        t=
(
Cystography shows:
- Moderate distention of urinary bladder with smooth contour.
- No evidence of urine leakage.
- Failed urination during the procedure.

Impression:
No significant radiological abnormality.
)
        sendByClipboard(t)
    return
    :*:vcugg::
        t=
(
Voiding urethrocystography
- Well distended urinary bladder with smooth contour.
- No evidence of vesicoureteral reflux.
- No congenital anomalies or stricture of urethra.

Impression:
No evidence of vesicoureteral reflux.
)
        sendByClipboard(t)
    return

    :*:bct0::
        t=
(
CT of the brain without contrast enhancement shows:
- normal appearance of sulci, fissures and ventricles.
- no definite acute intracranial hemorrhage.
- normal appearance of the cranial vault and skull base.

Impression:
no definite acute intracranial hemorrhage.
)
        sendByClipboard(t)
        thisHotkey:="F3"
        gosub quicksend
    return

    :B0:outhos::
        sendByClipboard("I concur with the report generated by the radiologist at the medical facility where the patient underwent this diagnostic imaging study. The initial report is presented below:`n" A_EndChar,6)
    return
    :B0:othhos::
        sendByClipboard("I concur with the report generated by the radiologist at the medical facility where the patient underwent this diagnostic imaging study. The initial report is presented below:`n" A_EndChar,6)
    return

    :B0:Bc::
        sendByClipboard(StringUpperFirst("breast cancer" A_EndChar),2)
    return
    :B0:Pm::
        sendByClipboard(StringUpperFirst("partial mastectomy" A_EndChar),2)
    return
    :B0:Bctr::
        sendByClipboard(StringUpperFirst("Breast cancer s/p right BCT" A_EndChar),4)
    return
    :B0:Bctl::
        sendByClipboard(StringUpperFirst("Breast cancer s/p left BCT" A_EndChar),4)
    return
    :B0:Sbr::
        sendByClipboard(StringUpperFirst("s/p right BCT with scar in" A_EndChar),3)
    return
    :B0:Sbl::
        sendByClipboard(StringUpperFirst("s/p left BCT with scar in" A_EndChar),3)
    return
    :B0:Mr::
        sendByClipboard(StringUpperFirst("Breast cancer s/p right modified radical mastectomy" A_EndChar),2)
    return
    :B0:Ml::
        sendByClipboard(StringUpperFirst("Breast cancer s/p left modified radical mastectomy" A_EndChar),2)
    return
    :B0:Smr::
        sendByClipboard(StringUpperFirst("s/p right modified radical mastectomy" A_EndChar),3)
    return
    :B0:Smrn::
        sendByClipboard(StringUpperFirst("s/p right modified radical mastectomy. No definite local recurrence" A_EndChar),4)
    return
    :B0:Sml::
        sendByClipboard(StringUpperFirst("s/p left modified radical mastectomy" A_EndChar),3)
    return
    :B0:Smln::
        sendByClipboard(StringUpperFirst("s/p left modified radical mastectomy. No definite local recurrence" A_EndChar),4)
    return
    :B0:R::
        sendByClipboard(StringUpperFirst("right" A_EndChar),1)
    return
    :B0:L::
        sendByClipboard(StringUpperFirst("left" A_EndChar),1)
    return
    :B0:Bi::
        sendByClipboard(StringUpperFirst("bilateral" A_EndChar),2)
    return
    :B0:Red::
        sendByClipboard(StringUpperFirst("are read and compared with prior mammograms dated" A_EndChar),3)
    return
    :B0:Redn::
        sendByClipboard(StringUpperFirst("are read without prior mammograms available for comparison.`n- " A_EndChar),4)
    return
    :o*B0:Hrl::
        sendByClipboard(StringUpperFirst("History: right breast lump.`n`n"),2)
    return
    :o*B0:Hll::
        sendByClipboard(StringUpperFirst("History: left breast lump.`n`n"),2)
    return
    :o*B0:Hbl::
        sendByClipboard(StringUpperFirst("History: bilateral breast lumps.`n`n"),2)
    return
    :o*B0:Hfu::
        sendByClipboard(StringUpperFirst("History: follow up.`n`n"),2)
    return
    :o*B0:Hrb::
        sendByClipboard(StringUpperFirst("History: right breast benign lesion status post operation/biopsy.`n`n"),2)
    return
    :o*B0:Hlb::
        sendByClipboard(StringUpperFirst("History: left breast benign lesion status post operation/biopsy.`n`n"),2)
    return
    :o*B0:Hbb::
        sendByClipboard(StringUpperFirst("History: bilateral breast benign lesion status post operation/biopsy.`n`n"),2)
    return
    :B0:Bmc::
        sendByClipboard(StringUpperFirst("Bilateral MLO/CC digital mammograms are read and compared with prior mammograms dated" A_EndChar),3)
    return
    :B0:Bmmc::
        sendByClipboard(StringUpperFirst("Bilateral magnified MLO/CC digital mammograms are read and compared with prior mammograms dated" A_EndChar),4)
    return
    :B0:Bmcn::
        sendByClipboard(StringUpperFirst("Bilateral MLO/CC digital mammograms are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar),4)
    return
    :B0:Bmci::
        sendByClipboard(StringUpperFirst("Bilateral MLO and CC II/ID views are read and compared with prior mammograms dated" A_EndChar),4)
    return
    :B0:Bmcin::
        sendByClipboard(StringUpperFirst("Bilateral MLO and CC II/ID views are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar),5)
    return
    :B0:Rmc::
        sendByClipboard(StringUpperFirst("Right MLO/CC digital mammograms are read and compared with prior mammograms dated" A_EndChar),3)
    return
    :B0:Rmcn::
        sendByClipboard(StringUpperFirst("Right MLO/CC digital mammograms are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar),4)
    return
    :B0:Rmci::
        sendByClipboard(StringUpperFirst("Right MLO and CC II/ID views are read and compared with prior mammograms dated" A_EndChar),4)
    return
    :B0:Rmcin::
        sendByClipboard(StringUpperFirst("Right MLO and CC II/ID views are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar),5)
    return
    :B0:Lmc::
        sendByClipboard(StringUpperFirst("Left MLO/CC digital mammograms are read and compared with prior mammograms dated" A_EndChar),3)
    return
    :B0:Lmcn::
        sendByClipboard(StringUpperFirst("Left MLO/CC digital mammograms are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar),4)
    return
    :B0:Lmci::
        sendByClipboard(StringUpperFirst("Left MLO and CC II/ID views are read and compared with prior mammograms dated" A_EndChar),4)
    return
    :B0:Lmcin::
        sendByClipboard(StringUpperFirst("Left MLO and CC II/ID views are read without prior mammograms available for comparison. This study shows:`r`n- " A_EndChar),5)
    return
    :*B0:Cal0::
        sendByClipboard(StringUpperFirst("There are benign scattered calcifications present."),3)
    return
    :oB0:Bcal::
        sendByClipboard(StringUpperFirst("There are benign scattered calcifications present bilaterally.`n- "),4)
    return
    :oB0:Bcalv::
        sendByClipboard(StringUpperFirst("There are benign appearing vascular wall calcifications in bilateral breasts.`n- "),5)
    return
    :oB0:Lcal::
        sendByClipboard(StringUpperFirst("There are benign scattered calcifications present in left breast.`n- "),4)
    return
    :oB0:Lcalv::
        sendByClipboard(StringUpperFirst("There are benign appearing vascular wall calcifications in left breast.`n- "),5)
    return
    :oB0:Rcal::
        sendByClipboard(StringUpperFirst("There are benign scattered calcifications present in right breast.`n- "),4)
    return
    :oB0:Rcalv::
        sendByClipboard(StringUpperFirst("There are benign appearing vascular wall calcifications in right breast.`n- "),5)
    return
    :B0:Neg::
        sendByClipboard(StringUpperFirst("There are no definite mass, no suspicious microcalcifications, and no architectural distortion in this study.`r`n- No definite axillary lymphadenopathy." A_EndChar),3)
    return
    :B0:Negc::
        sendByClipboard(StringUpperFirst("There are no definite mass and no architectural distortion in this study.`r`n- No definite axillary lymphadenopathy." A_EndChar),4)
    return
    :B0:Negm::
        sendByClipboard(StringUpperFirst("There are no definite mass in this study.`r`n- No definite axillary lymphadenopathy." A_EndChar),4)
    return
    :B0:M6::
        sendByClipboard(StringUpperFirst("suggest 6-month follow up." A_EndChar),2)
    return
    :B0:Mvc::
        sendByClipboard(StringUpperFirst("suggest magnified view correlation. " A_EndChar),3)
    return
    :B0:Svc::
        sendByClipboard(StringUpperFirst("suggest spot view correlation." A_EndChar),3)
    return
    :B0:Iml::
        sendByClipboard(StringUpperFirst("There are left retro-pectoral saline implants, with smooth surface without evidence of rupture." A_EndChar),3)
    return
    :B0:Imr::
        sendByClipboard(StringUpperFirst("There are right retro-pectoral saline implants, with smooth surface without evidence of rupture." A_EndChar),3)
    return
    :B0:Imb::
        sendByClipboard(StringUpperFirst("There are bilateral retro-pectoral saline implants, with smooth surface without evidence of rupture." A_EndChar),3)
    return
    :B0:Ibb::
        sendByClipboard(StringUpperFirst("in bilateral breasts" A_EndChar),3)
    return
    :B0:Irb::
        sendByClipboard(StringUpperFirst("in right breast" A_EndChar),3)
    return
    :B0:Ilb::
        sendByClipboard(StringUpperFirst("in left breast" A_EndChar),3)
    return
    :B0:Bb::
        sendByClipboard(StringUpperFirst("bilateral breasts" A_EndChar),2)
    return
    :B0:Rb::
        sendByClipboard(StringUpperFirst("right breast" A_EndChar),2)
    return
    :B0:Lb::
        sendByClipboard(StringUpperFirst("left breast" A_EndChar),2)
    return
    :B0:Lj::
        sendByClipboard(StringUpperFirst("(YCH/Dr.B)" A_EndChar),2)
    return
    :B0:Clin::
        sendByClipboard(StringUpperFirst("( if there is clinical relevant finding, ultrasound is suggested. )" A_EndChar),4)
    return
    :B0:Fa::
        sendByClipboard(StringUpperFirst("fibroadenoma" A_EndChar),2)
    return
    :*B0:Fa1::
        sendByClipboard(StringUpperFirst("fibroadenomas"),2)
    return
    :B0:Fcc::
        sendByClipboard(StringUpperFirst("fibrocystic change" A_EndChar),3)
    return
    :B0:Fhx::
        sendByClipboard(StringUpperFirst("family history of breast cancer (sister/mother/grandmother)," A_EndChar),3)
    return
    :B0:Lnr::
        sendByClipboard(StringUpperFirst("benign appearing node at right axilla, size , having fat hilum." A_EndChar),3)
    return
    :B0:Lnl::
        sendByClipboard(StringUpperFirst("benign appearing node at left axilla, size , having fat hilum." A_EndChar),3)
    return
    :B0:Mags::
        sendByClipboard(StringUpperFirst("spot magnification views" A_EndChar),4)
    return
    :B0:Mag::
        sendByClipboard(StringUpperFirst("magnified" A_EndChar),3)
    return
    :B0:Masy::
        sendByClipboard(StringUpperFirst("Focal asymmetry is noted at right anterior UOQ near central, suggest ultrasound or mag. views." A_EndChar),4)
    return
    :B0:Mmic::
        sendByClipboard(StringUpperFirst("There are two clusters of pleomorphic to amorphous microcalcifications at right UOQ, suggest biopsy." A_EndChar),4)
    return
    :B0:Mmic2::
        sendByClipboard(StringUpperFirst("There are segmentally to regionally distributed microcalcifications at the UOQ left breast with probably benign appearance." A_EndChar),5)
    return
    :B0:Mop2::
        sendByClipboard(StringUpperFirst("Focal architectural distortion, parenchymal retraction is noted at right UOQ under the wire and focal asymmetry near the surgical bed." A_EndChar),4)
    return
    :B0:Mop3::
        sendByClipboard(StringUpperFirst("Post-op. changes at left UIQ breast with parenchymal loss, architectural deformity, skin retraction and thickening." A_EndChar),4)
    return
    :B0:Msug::
        sendByClipboard(StringUpperFirst("suggest breast ultrasound correlation and right mag. views." A_EndChar),4)
    return
    :B0:Np::
        sendByClipboard(StringUpperFirst("No definite focal mass lesion. Suggest follow-up." A_EndChar),2)
    return
    :B0:Pl::
        sendByClipboard(StringUpperFirst("pleomorphic" A_EndChar),2)
    return
    :B0:Sar::
        sendByClipboard(StringUpperFirst("subareolar region" A_EndChar),3)
    return
    :B0:Sfufna::
        sendByClipboard(StringUpperFirst("Suggest follow up and considered FNA if there is interval change. " A_EndChar),6)
    return
    :B0:Sfu::
        sendByClipboard(StringUpperFirst("suggest follow up." A_EndChar),3)
    return
    :B0:Sr::
        sendByClipboard(StringUpperFirst("skin retraction" A_EndChar),2)
    return
    :B0:Sth::
        sendByClipboard(StringUpperFirst("skin thickening" A_EndChar),3)
    return
    :B0:Scm::
        sendByClipboard(StringUpperFirst("screening mammography" A_EndChar),3)
    return
    :B0:Dgm::
        sendByClipboard(StringUpperFirst("diagnostic mammography" A_EndChar),3)
    return
    :B0:Usb::
        sendByClipboard(StringUpperFirst("Ultrasound of both breasts shows " A_EndChar),3)
    return
    :B0:Ush::
        sendByClipboard(StringUpperFirst("Heterogenous breast tissue of bilateral breasts." A_EndChar),3)
    return
    :B0:Usl::
        sendByClipboard(StringUpperFirst("A cm hypoechoic lesion in right/left breast at o'clock/cm," A_EndChar),3)
    return
    :B0:Usn::
        sendByClipboard(StringUpperFirst("Probably benign ultrasound findings. Suggest follow up." A_EndChar),3)
    return
    :B0:Wm::
        sendByClipboard(StringUpperFirst("wire marked" A_EndChar),2)
    return
    :B0:Mic::
        sendByClipboard(StringUpperFirst("microcalcifications" A_EndChar),3)
    return
    :B0:Ca::
        sendByClipboard(StringUpperFirst("calcifications" A_EndChar),2)
    return
    :B0:Ti::
        sendByClipboard(StringUpperFirst("There is" A_EndChar),2)
    return
    :B0:Ta::
        sendByClipboard(StringUpperFirst("There are" A_EndChar),2)
    return
    :B0:Asy::
        sendByClipboard(StringUpperFirst("asymmetry" A_EndChar),3)
    return
    :B0:Gsy::
        sendByClipboard(StringUpperFirst("global asymmetry" A_EndChar),3)
    return
    :B0:Fsy::
        sendByClipboard(StringUpperFirst("focal asymmetry" A_EndChar),3)
    return
    :B0:Dsy::
        sendByClipboard(StringUpperFirst("developing asymmetry" A_EndChar),3)
    return
    :B0:Br::
        sendByClipboard(StringUpperFirst("breast" A_EndChar),2)
    return
    :B0:Br1::
        sendByClipboard(StringUpperFirst("breasts" A_EndChar),3)
    return
    :B0:Sta::
        sendByClipboard(StringUpperFirst("unchanged" A_EndChar),3)
    return
    :B0:Com::
        sendByClipboard(StringUpperFirst("as compared to previous study." A_EndChar),3)
    return
    :B0:Ic::
        sendByClipboard(StringUpperFirst("interval change" A_EndChar),2)
    return
    :B0:X/::
        sendByClipboard(StringUpperFirst("without" A_EndChar),2)
    return
    :B0:W/::
        sendByClipboard(StringUpperFirst("with" A_EndChar),2)
    return
    :B0:Ant::
        sendByClipboard(StringUpperFirst("anterior" A_EndChar),3)
    return
    :B0:Pos::
        sendByClipboard(StringUpperFirst("posterior" A_EndChar),3)
    return
    :B0:Cen::
        sendByClipboard(StringUpperFirst("central" A_EndChar),3)
    return
    :B0:Sus::
        sendByClipboard(StringUpperFirst("suspicious" A_EndChar),3)
    return
    :B0:Usc::
        sendByClipboard(StringUpperFirst("suggest ultrasound correlation." A_EndChar),3)
    return
    :B0:Wed::
        sendByClipboard(StringUpperFirst("well-defined" A_EndChar),3)
    return
    :B0:Up::
        sendByClipboard(StringUpperFirst("upper" A_EndChar),2)
    return
    :B0:Lo::
        sendByClipboard(StringUpperFirst("lower" A_EndChar),2)
    return
    :B0:Ou::
        sendByClipboard(StringUpperFirst("outer" A_EndChar),2)
    return
    :B0:Nn::
        sendByClipboard(StringUpperFirst("inner" A_EndChar),2)
    return
    :B0:Ov::
        sendByClipboard(StringUpperFirst("oval" A_EndChar),2)
    return
    :B0:Rn::
        sendByClipboard(StringUpperFirst("round" A_EndChar),2)
    return
    :B0:Ir::
        sendByClipboard(StringUpperFirst("irregular" A_EndChar),2)
    return
    :B0:Ci::
        sendByClipboard(StringUpperFirst("circumscribed" A_EndChar),2)
    return
    :B0:Ob::
        sendByClipboard(StringUpperFirst("obscured" A_EndChar),2)
    return
    :B0:Pob::
        sendByClipboard(StringUpperFirst("partially obscured" A_EndChar),3)
    return
    :*B0:Pbpc::
        sendByClipboard(StringUpperFirst("partially obscured partially circumscribed"),3)
    return
    :B0:Mlb::
        sendByClipboard(StringUpperFirst("microlobulated" A_EndChar),3)
    return
    :B0:Ind::
        sendByClipboard(StringUpperFirst("indistinct" A_EndChar),3)
    return
    :B0:Nod::
        sendByClipboard(StringUpperFirst("nodule" A_EndChar),3)
    return
    :B0:Pu::
        sendByClipboard(StringUpperFirst("punctate" A_EndChar),2)
    return
    :B0:Am::
        sendByClipboard(StringUpperFirst("amorphous" A_EndChar),2)
    return
    :B0:Cr::
        sendByClipboard(StringUpperFirst("coarse" A_EndChar),2)
    return
    :B0:Coh::
        sendByClipboard(StringUpperFirst("coarse heterogeneous" A_EndChar),3)
    return
    :B0:Fp::
        sendByClipboard(StringUpperFirst("fine pleomorphic" A_EndChar),2)
    return
    :B0:Ple::
        sendByClipboard(StringUpperFirst("pleomorphic" A_EndChar),3)
    return
    :B0:Fl::
        sendByClipboard(StringUpperFirst("fine linear" A_EndChar),2)
    return
    :B0:Flb::
        sendByClipboard(StringUpperFirst("fine linear branching" A_EndChar),3)
    return
    :B0:Gr::
        sendByClipboard(StringUpperFirst("grouped" A_EndChar),2)
    return
    :B0:Lin::
        sendByClipboard(StringUpperFirst("linear" A_EndChar),3)
    return
    :B0:Ad::
        sendByClipboard(StringUpperFirst("architectural distortion" A_EndChar),2)
    return
    :B0:Tt::
        sendByClipboard(StringUpperFirst("trabecular thickening" A_EndChar),2)
    return
    :B0:Uw::
        sendByClipboard(StringUpperFirst("under the wire" A_EndChar),2)
    return
    :B0:Ub::
        sendByClipboard(StringUpperFirst("under the BB" A_EndChar),2)
    return
    :B0:T::
        sendByClipboard(StringUpperFirst("the" A_EndChar),1)
    return
    :B0:Sca::
        sendByClipboard(StringUpperFirst("scattered" A_EndChar),3)
    return
    :B0:Mc::
        sendByClipboard(StringUpperFirst("MLO/CC" A_EndChar),2)
    return
    :*B0:Ln0::
        sendByClipboard(StringUpperFirst("Bilateral axillary lymph nodes, probably non-specific."),2)
    return
    :B0:Moc::
        sendByClipboard(StringUpperFirst("milk of calcium" A_EndChar),3)
    return
    :B0:Mlo::
        sendByClipboard(StringUpperFirst("MLO" A_EndChar),3)
    return
    :B0:Cc::
        sendByClipboard(StringUpperFirst("CC" A_EndChar),2)
    return
    :B0:Uo::
        sendByClipboard(StringUpperFirst("UOQ" A_EndChar),2)
    return
    :B0:Ui::
        sendByClipboard(StringUpperFirst("UIQ" A_EndChar),2)
    return
    :B0:Li::
        sendByClipboard(StringUpperFirst("LIQ" A_EndChar),2)
    return
    :B0:Uob::
        sendByClipboard(StringUpperFirst("UOQ breast" A_EndChar),3)
    return
    :B0:Uib::
        sendByClipboard(StringUpperFirst("UIQ breast" A_EndChar),3)
    return
    :B0:Lob::
        sendByClipboard(StringUpperFirst("LOQ breast" A_EndChar),3)
    return
    :B0:Lib::
        sendByClipboard(StringUpperFirst("LIQ breast" A_EndChar),3)
    return
    :B0:Mam::
        sendByClipboard(StringUpperFirst("mammography" A_EndChar),3)
    return
    :B0:Disp::
        sendByClipboard(StringUpperFirst("is dispersed on spot view, benign tissue is considered." A_EndChar),4)
    return
    :B0:Tom::
        sendByClipboard(StringUpperFirst("tomosynthesis" A_EndChar),3)
    return
    :B0:Thn::
        sendByClipboard(StringUpperFirst("(due to very thin breast, only needle localization is feasible)" A_EndChar),3)
    return
    :B0:Mom::
        sendByClipboard(StringUpperFirst("mother" A_EndChar),3)
    return
    :B0:Sis::
        sendByClipboard(StringUpperFirst("sister" A_EndChar),3)
    return
    :B0:Gmo::
        sendByClipboard(StringUpperFirst("grandmother" A_EndChar),3)
    return
    :B0:Mat::
        sendByClipboard(StringUpperFirst("maternal" A_EndChar),3)
    return
    :B0:Pat::
        sendByClipboard(StringUpperFirst("paternal" A_EndChar),3)
    return
    :B0:Au::
        sendByClipboard(StringUpperFirst("aunt" A_EndChar),2)
    return
    :B0:Cou::
        sendByClipboard(StringUpperFirst("cousin" A_EndChar),3)
    return
    :B0:Dau::
        sendByClipboard(StringUpperFirst("daughter" A_EndChar),3)
    return
    :*B0:Vabb::
        sendByClipboard(StringUpperFirst("vacuum-assisted stereotactic biopsy"),3)
    return
    :*B0:Vabc::
        sendByClipboard(StringUpperFirst("status post vacuum-assisted stereotactic biopsy with clip retention at"),3)
    return
    :B0:Cysb::
        sendByClipboard(StringUpperFirst("small, oval, hypoechoic to anechoic lesion(s) with distinct margin in bilateral breasts, r/o fibrocystic change and/or fibroadenoma." A_EndChar),4)
    return
    :B0:Cysl::
        sendByClipboard(StringUpperFirst("small, oval, hypoechoic to anechoic lesion(s) with distinct margin in left breast, r/o fibrocystic change and/or fibroadenoma." A_EndChar),4)
    return
    :B0:Cysr::
        sendByClipboard(StringUpperFirst("small, oval, hypoechoic to anechoic lesion(s) with distinct margin in right breast, r/o fibrocystic change and/or fibroadenoma." A_EndChar),4)
    return
    :*B0:Mic0::
        sendByClipboard(StringUpperFirst("no suspicious microcalcifications."),3)
    return
    :B0:Hoh::
        sendByClipboard(StringUpperFirst("hypoechoic" A_EndChar),3)
    return
    :B0:Heh::
        sendByClipboard(StringUpperFirst("hyperechoic" A_EndChar),3)
    return
    :B0:Ioh::
        sendByClipboard(StringUpperFirst("isoechoic" A_EndChar),3)
    return
    :B0:Anh::
        sendByClipboard(StringUpperFirst("anechoic" A_EndChar),3)
    return
    :*B0:N-::
        sendByClipboard(StringUpperFirst("無顯著異常"),1)
    return
    :*B0:Rs-::
        sendByClipboard(StringUpperFirst("腎結石"),2)
    return
    :*B0:R-::
        sendByClipboard(StringUpperFirst("右側"),1)
    return
    :*B0:L-::
        sendByClipboard(StringUpperFirst("左側"),1)
    return
    :*B0:B-::
        sendByClipboard(StringUpperFirst("雙側"),1)
    return
    :*B0:D-::
        sendByClipboard(StringUpperFirst("退行性變化"),1)
    return
    :B0:Hx::
        sendByClipboard(StringUpperFirst("History:" A_EndChar),2)
    return
    :B0:Sp::
        sendByClipboard(StringUpperFirst("status post" A_EndChar),2)
    return
    :B0:R/t::
        sendByClipboard(StringUpperFirst("radiotherapy" A_EndChar),3)
    return
    :B0:C/t::
        sendByClipboard(StringUpperFirst("chemotherapy" A_EndChar),3)
    return
    :B0:Lcl::
        sendByClipboard(StringUpperFirst("localization" A_EndChar),3)
    return
    :oB0:Hfn::
        sendByClipboard(StringUpperFirst("History: for navigation.`n`n"),3)
    return
    :oB0:Hfc::
        sendByClipboard(StringUpperFirst("History: for cyberknife.`n`n"),3)
    return
    :B0:Xx::
        sendByClipboard(StringUpperFirst("(非正式報告，僅供參考。)`n" A_EndChar),2)
    return
    :B0:Ctp::
        sendByClipboard(StringUpperFirst("CT perfusion shows" A_EndChar),3)
    return
    :B0:Ce::
        sendByClipboard(StringUpperFirst("contrast enhancement" A_EndChar),2)
    return
    :B0:Ang::
        sendByClipboard(StringUpperFirst("angiography" A_EndChar),3)
    return
    :B0:Us::
        sendByClipboard(StringUpperFirst("ultrasound" A_EndChar),2)
    return
    :B0:Emer::
        sendByClipboard(StringUpperFirst("emergency" A_EndChar),4)
    return
    :B0:Ctd::
        sendByClipboard(StringUpperFirst("the estimated radiation dose (mSv) of this study is:" A_EndChar),3)
    return
    :B0:Qa::
        sendByClipboard(StringUpperFirst("anterior aspect of" A_EndChar),2)
    return
    :B0:Qc::
        sendByClipboard(StringUpperFirst("cephalic aspect of" A_EndChar),2)
    return
    :B0:Qcc::
        sendByClipboard(StringUpperFirst("caudal aspect of" A_EndChar),3)
    return
    :B0:Qd::
        sendByClipboard(StringUpperFirst("distal aspect of" A_EndChar),2)
    return
    :B0:Qi::
        sendByClipboard(StringUpperFirst("inferior aspect of" A_EndChar),2)
    return
    :B0:Ql::
        sendByClipboard(StringUpperFirst("lateral aspect of" A_EndChar),2)
    return
    :B0:Qm::
        sendByClipboard(StringUpperFirst("medial aspect of" A_EndChar),2)
    return
    :B0:Qp::
        sendByClipboard(StringUpperFirst("posterior aspect of" A_EndChar),2)
    return
    :B0:Qpp::
        sendByClipboard(StringUpperFirst("proximal aspect of" A_EndChar),3)
    return
    :B0:Qs::
        sendByClipboard(StringUpperFirst("superior aspect of" A_EndChar),2)
    return
    :B0:Sup::
        sendByClipboard(StringUpperFirst("superior" A_EndChar),3)
    return
    :B0:Inf::
        sendByClipboard(StringUpperFirst("inferior" A_EndChar),3)
    return
    :B0:Lgt::
        sendByClipboard(StringUpperFirst("longitudinal" A_EndChar),3)
    return
    :B0:Prt::
        sendByClipboard(StringUpperFirst("portion" A_EndChar),3)
    return
    :B0:Dcb::
        sendByClipboard(StringUpperFirst("decubitus" A_EndChar),3)
    return
    :B0:Mid::
        sendByClipboard(StringUpperFirst("middle" A_EndChar),3)
    return
    :B0:Spf::
        sendByClipboard(StringUpperFirst("superficial" A_EndChar),3)
    return
    :B0:Prp::
        sendByClipboard(StringUpperFirst("peripheral" A_EndChar),3)
    return
    :*B0:I,::
        sendByClipboard(StringUpperFirst("I,"),1)
    return
    :*B0:I.::
        sendByClipboard(StringUpperFirst("I."),1)
    return
    :*B0:I;::
        sendByClipboard(StringUpperFirst("I;"),1)
    return
    :*B0:I\::
        sendByClipboard(StringUpperFirst("i"),1)
    return
    :*B0:E\::
        sendByClipboard(StringUpperFirst("e"),1)
    return
    :*B0:O\::
        sendByClipboard(StringUpperFirst("o"),1)
    return
    :*B0:L\::
        sendByClipboard(StringUpperFirst("l"),1)
    return
    :*B0:R\::
        sendByClipboard(StringUpperFirst("r"),1)
    return
    :*B0:B\::
        sendByClipboard(StringUpperFirst("b"),1)
    return
    :*B0:M\::
        sendByClipboard(StringUpperFirst("m"),1)
    return
    :*B0:F\::
        sendByClipboard(StringUpperFirst("f"),1)
    return
    :B0:E::
        sendByClipboard(StringUpperFirst("at" A_EndChar),1)
    return
    :*B0:N\::
        sendByClipboard(StringUpperFirst("n"),1)
    return
    :B0:N::
        sendByClipboard(StringUpperFirst("and" A_EndChar),1)
    return
    :*B0:T\::
        sendByClipboard(StringUpperFirst("t"),1)
    return
    :B0:O::
        sendByClipboard(StringUpperFirst("of" A_EndChar),1)
    return
    :B0:U/::
        sendByClipboard(StringUpperFirst("upper" A_EndChar),2)
    return
    :B0:V/::
        sendByClipboard(StringUpperFirst("lower" A_EndChar),2)
    return
    :B0:Med::
        sendByClipboard(StringUpperFirst("medial" A_EndChar),3)
    return
    :B0:Lat::
        sendByClipboard(StringUpperFirst("lateral" A_EndChar),3)
    return
    :B0:Pro::
        sendByClipboard(StringUpperFirst("proximal" A_EndChar),3)
    return
    :B0:Dis::
        sendByClipboard(StringUpperFirst("distal" A_EndChar),3)
    return
    :B0:B::
        sendByClipboard(StringUpperFirst("bilateral" A_EndChar),1)
    return
    :B0:Trs::
        sendByClipboard(StringUpperFirst("transverse" A_EndChar),3)
    return
    :B0:Sut::
        sendByClipboard(StringUpperFirst("size up to" A_EndChar),3)
    return
    :B0:Dif::
        sendByClipboard(StringUpperFirst("difficult" A_EndChar),3)
    return
    :B0:Lg::
        sendByClipboard(StringUpperFirst("large" A_EndChar),2)
    return
    :*B0:Lg1::
        sendByClipboard(StringUpperFirst("larger"),2)
    return
    :B0:Mss::
        sendByClipboard(StringUpperFirst("massive" A_EndChar),3)
    return
    :B0:Sm::
        sendByClipboard(StringUpperFirst("small" A_EndChar),2)
    return
    :B0:Ss::
        sendByClipboard(StringUpperFirst("tiny (<6mm)" A_EndChar),2)
    return
    :B0:Mm::
        sendByClipboard(StringUpperFirst("small (<10mm)" A_EndChar),2)
    return
    :*B0:Sm1::
        sendByClipboard(StringUpperFirst("smaller"),2)
    return
    :B0:Str::
        sendByClipboard(StringUpperFirst("strong" A_EndChar),3)
    return
    :B0:Int::
        sendByClipboard(StringUpperFirst("intermediate" A_EndChar),3)
    return
    :B0:Sig::
        sendByClipboard(StringUpperFirst("significant" A_EndChar),3)
    return
    :B0:Siy::
        sendByClipboard(StringUpperFirst("significantly" A_EndChar),3)
    return
    :B0:Mi::
        sendByClipboard(StringUpperFirst("minimal" A_EndChar),2)
    return
    :B0:Miy::
        sendByClipboard(StringUpperFirst("minimaly" A_EndChar),3)
    return
    :B0:Sli::
        sendByClipboard(StringUpperFirst("slight" A_EndChar),3)
    return
    :B0:Sly::
        sendByClipboard(StringUpperFirst("slightly" A_EndChar),3)
    return
    :*B0:M-::
        sendByClipboard(StringUpperFirst("輕度"),1)
    return
    :B0:M::
        sendByClipboard(StringUpperFirst("mild" A_EndChar),1)
    return
    :B0:My::
        sendByClipboard(StringUpperFirst("mildly" A_EndChar),2)
    return
    :*B0:Mo-::
        sendByClipboard(StringUpperFirst("中度"),2)
    return
    :B0:Mo::
        sendByClipboard(StringUpperFirst("moderate" A_EndChar),2)
    return
    :B0:Moy::
        sendByClipboard(StringUpperFirst("moderately" A_EndChar),3)
    return
    :*B0:Sv-::
        sendByClipboard(StringUpperFirst("重度"),2)
    return
    :B0:Sv::
        sendByClipboard(StringUpperFirst("severe" A_EndChar),2)
    return
    :B0:Bri::
        sendByClipboard(StringUpperFirst("bright" A_EndChar),3)
    return
    :B0:Ext::
        sendByClipboard(StringUpperFirst("extensive" A_EndChar),3)
    return
    :B0:Lim::
        sendByClipboard(StringUpperFirst("limited" A_EndChar),3)
    return
    :B0:Abn::
        sendByClipboard(StringUpperFirst("abnormal" A_EndChar),3)
    return
    :B0:Aby::
        sendByClipboard(StringUpperFirst("abnormality" A_EndChar),3)
    return
    :B0:Nor::
        sendByClipboard(StringUpperFirst("normal" A_EndChar),3)
    return
    :B0:Nap::
        sendByClipboard(StringUpperFirst("normal appearance of" A_EndChar),3)
    return
    :B0:St::
        sendByClipboard(StringUpperFirst("unchanged" A_EndChar),2)
    return
    :*B0:Stml::
        sendByClipboard(StringUpperFirst("unchanged but malignancy can not be excluded."),3)
    return
    :*B0:Stns::
        sendByClipboard(StringUpperFirst("unchanged, probably non-specific"),3)
    return
    :B0:Prog::
        sendByClipboard(StringUpperFirst("in progression" A_EndChar),4)
    return
    :B0:Inc::
        sendByClipboard(StringUpperFirst("increased" A_EndChar),3)
    return
    :B0:Dec::
        sendByClipboard(StringUpperFirst("decreased" A_EndChar),3)
    return
    :B0:Ifl::
        sendByClipboard(StringUpperFirst("infiltrative" A_EndChar),3)
    return
    :*B0:Ifl1::
        sendByClipboard(StringUpperFirst("infiltration"),3)
    return
    :B0:Ild::
        sendByClipboard(StringUpperFirst("ill-defined" A_EndChar),3)
    return
    :B0:Mu::
        sendByClipboard(StringUpperFirst("multiple" A_EndChar),2)
    return
    :B0:Rec::
        sendByClipboard(StringUpperFirst("recurrent" A_EndChar),3)
    return
    :B0:Prm::
        sendByClipboard(StringUpperFirst("prominent" A_EndChar),3)
    return
    :*B0:Prm1::
        sendByClipboard(StringUpperFirst("more prominent"),3)
    return
    :*B0:Prm2::
        sendByClipboard(StringUpperFirst("less prominent"),3)
    return
    :B0:Evi::
        sendByClipboard(StringUpperFirst("evident" A_EndChar),3)
    return
    :*B0:Evi1::
        sendByClipboard(StringUpperFirst("more evident"),3)
    return
    :*B0:Evi2::
        sendByClipboard(StringUpperFirst("less evident"),3)
    return
    :*B0:Evi3::
        sendByClipboard(StringUpperFirst("most evident"),3)
    return
    :B0:Acu::
        sendByClipboard(StringUpperFirst("acute" A_EndChar),3)
    return
    :B0:Chr::
        sendByClipboard(StringUpperFirst("chronic" A_EndChar),3)
    return
    :B0:Ju::
        sendByClipboard(StringUpperFirst("junction" A_EndChar),2)
    return
    :B0:Wnr::
        sendByClipboard(StringUpperFirst("within normal range" A_EndChar),3)
    return
    :B0:Mor::
        sendByClipboard(StringUpperFirst("predominant on the right side" A_EndChar),3)
    return
    :B0:Mol::
        sendByClipboard(StringUpperFirst("predominant on the left side" A_EndChar),3)
    return
    :B0:Prs::
        sendByClipboard(StringUpperFirst("persistent" A_EndChar),3)
    return
    :B0:Dil::
        sendByClipboard(StringUpperFirst("dilatation" A_EndChar),3)
    return
    :*B0:Dil1::
        sendByClipboard(StringUpperFirst("dilated"),3)
    return
    :B0:Seg::
        sendByClipboard(StringUpperFirst("segmental" A_EndChar),3)
    return
    :B0:Sg::
        sendByClipboard(StringUpperFirst("segment" A_EndChar),2)
    return
    :*B0:Sg1::
        sendByClipboard(StringUpperFirst("segments"),2)
    return
    :B0:Frq::
        sendByClipboard(StringUpperFirst("frequent" A_EndChar),3)
    return
    :B0:Smo::
        sendByClipboard(StringUpperFirst("smoothly" A_EndChar),3)
    return
    :B0:Y/::
        sendByClipboard(StringUpperFirst("without/with" A_EndChar),2)
    return
    :B0:Comp::
        sendByClipboard(StringUpperFirst("as compared with previous study on" A_EndChar),4)
    return
    :B0:Icl::
        sendByClipboard(StringUpperFirst("including" A_EndChar),3)
    return
    :B0:Su::
        sendByClipboard(StringUpperFirst("suspect" A_EndChar),2)
    return
    :B0:Suo::
        sendByClipboard(StringUpperFirst("suspicious of" A_EndChar),3)
    return
    :B0:Ifa::
        sendByClipboard(StringUpperFirst("is favored" A_EndChar),3)
    return
    :B0:Sug::
        sendByClipboard(StringUpperFirst("suggestive of" A_EndChar),3)
    return
    :B0:Sgg::
        sendByClipboard(StringUpperFirst("suggest" A_EndChar),3)
    return
    :B0:Nde::
        sendByClipboard(StringUpperFirst("no definite" A_EndChar),3)
    return
    :B0:Df::
        sendByClipboard(StringUpperFirst("definite" A_EndChar),2)
    return
    :B0:Nob::
        sendByClipboard(StringUpperFirst("no obvious" A_EndChar),3)
    return
    :B0:Nev::
        sendByClipboard(StringUpperFirst("no evidence of" A_EndChar),3)
    return
    :*B0:Ico1::
        sendByClipboard(StringUpperFirst("are considered"),3)
    return
    :B0:Ico::
        sendByClipboard(StringUpperFirst("is considered" A_EndChar),3)
    return
    :*B0:Icf1::
        sendByClipboard(StringUpperFirst("are considered first"),3)
    return
    :B0:Icf::
        sendByClipboard(StringUpperFirst("is considered first" A_EndChar),3)
    return
    :B0:Isg::
        sendByClipboard(StringUpperFirst("is suggested" A_EndChar),3)
    return
    :B0:Iss::
        sendByClipboard(StringUpperFirst("is suspected" A_EndChar),3)
    return
    :B0:Isn::
        sendByClipboard(StringUpperFirst("is noted" A_EndChar),3)
    return
    :B0:Isd::
        sendByClipboard(StringUpperFirst("is done" A_EndChar),3)
    return
    :B0:Unr::
        sendByClipboard(StringUpperFirst("unremarkable" A_EndChar),3)
    return
    :B0:Cow::
        sendByClipboard(StringUpperFirst("consistent with" A_EndChar),3)
    return
    :B0:Sbe::
        sendByClipboard(StringUpperFirst("should be excluded first." A_EndChar),3)
    return
    :B0:Cnx::
        sendByClipboard(StringUpperFirst("can not be excluded." A_EndChar),3)
    return
    :*B0:Mcnx::
        sendByClipboard(StringUpperFirst("malignancy can not be excluded."),3)
    return
    :B0:Prev::
        sendByClipboard(StringUpperFirst("previous" A_EndChar),4)
    return
    :B0:Prb::
        sendByClipboard(StringUpperFirst("probably" A_EndChar),3)
    return
    :B0:Psb::
        sendByClipboard(StringUpperFirst("possible" A_EndChar),3)
    return
    :B0:Esp::
        sendByClipboard(StringUpperFirst("especially" A_EndChar),3)
    return
    :B0:Usu::
        sendByClipboard(StringUpperFirst("usually" A_EndChar),3)
    return
    :B0:Awa::
        sendByClipboard(StringUpperFirst("as well as" A_EndChar),3)
    return
    :B0:Trh::
        sendByClipboard(StringUpperFirst("through" A_EndChar),3)
    return
    :B0:Hyv::
        sendByClipboard(StringUpperFirst("hypervascular" A_EndChar),3)
    return
    :B0:Hov::
        sendByClipboard(StringUpperFirst("hypovascular" A_EndChar),3)
    return
    :B0:Hom::
        sendByClipboard(StringUpperFirst("homogeneous" A_EndChar),3)
    return
    :B0:Het::
        sendByClipboard(StringUpperFirst("heterogeneous" A_EndChar),3)
    return
    :B0:Den::
        sendByClipboard(StringUpperFirst("density" A_EndChar),3)
    return
    :*B0:Den1::
        sendByClipboard(StringUpperFirst("densities"),3)
    return
    :B0:Ro::
        sendByClipboard(StringUpperFirst("radiopaque" A_EndChar),2)
    return
    :*B0:Ro1::
        sendByClipboard(StringUpperFirst("radiopaque density"),2)
    return
    :*B0:Ro2::
        sendByClipboard(StringUpperFirst("radiopaque densities"),2)
    return
    :B0:Rl::
        sendByClipboard(StringUpperFirst("radiolucent" A_EndChar),2)
    return
    :*B0:Rl1::
        sendByClipboard(StringUpperFirst("radiolucency"),2)
    return
    :*B0:Rl2::
        sendByClipboard(StringUpperFirst("radiolucencies"),2)
    return
    :B0:Hy::
        sendByClipboard(StringUpperFirst("hyperdense" A_EndChar),2)
    return
    :*B0:Hy1::
        sendByClipboard(StringUpperFirst("hyperdensity"),2)
    return
    :*B0:Hy2::
        sendByClipboard(StringUpperFirst("hyperdensities"),2)
    return
    :B0:Hyi::
        sendByClipboard(StringUpperFirst("hyperintense" A_EndChar),3)
    return
    :*B0:Hyi1::
        sendByClipboard(StringUpperFirst("hyperintensity"),3)
    return
    :*B0:Hyi2::
        sendByClipboard(StringUpperFirst("hyperintensities"),3)
    return
    :B0:Ho::
        sendByClipboard(StringUpperFirst("hypodense" A_EndChar),2)
    return
    :*B0:Ho1::
        sendByClipboard(StringUpperFirst("hypodensity"),2)
    return
    :*B0:Ho2::
        sendByClipboard(StringUpperFirst("hypodensities"),2)
    return
    :B0:Hoi::
        sendByClipboard(StringUpperFirst("hypointense" A_EndChar),3)
    return
    :*B0:Hoi1::
        sendByClipboard(StringUpperFirst("hypointensity"),3)
    return
    :*B0:Hoi2::
        sendByClipboard(StringUpperFirst("hypointensities"),3)
    return
    :B0:Opac::
        sendByClipboard(StringUpperFirst("opacification" A_EndChar),4)
    return
    :B0:Opf::
        sendByClipboard(StringUpperFirst("opacified" A_EndChar),3)
    return
    :B0:Nen::
        sendByClipboard(StringUpperFirst("non-enhancing" A_EndChar),3)
    return
    :B0:Enh::
        sendByClipboard(StringUpperFirst("enhancing" A_EndChar),3)
    return
    :B0:Enn::
        sendByClipboard(StringUpperFirst("enhancing nodule" A_EndChar),3)
    return
    :*B0:Enn1::
        sendByClipboard(StringUpperFirst("enhancing nodules"),3)
    return
    :B0:Enm::
        sendByClipboard(StringUpperFirst("enhancing mass" A_EndChar),3)
    return
    :*B0:Enm1::
        sendByClipboard(StringUpperFirst("enhancing masses"),3)
    return
    :B0:Ens::
        sendByClipboard(StringUpperFirst("enhancing lesion" A_EndChar),3)
    return
    :*B0:Ens1::
        sendByClipboard(StringUpperFirst("enhancing lesions"),3)
    return
    :B0:Ent::
        sendByClipboard(StringUpperFirst("enhancing tumor" A_EndChar),3)
    return
    :*B0:Ent1::
        sendByClipboard(StringUpperFirst("enhancing tumors"),3)
    return
    :*B0:Enhc::
        sendByClipboard(StringUpperFirst("enhancement"),3)
    return
    :B0:Hoe::
        sendByClipboard(StringUpperFirst("hypoenhancing" A_EndChar),3)
    return
    :B0:Hye::
        sendByClipboard(StringUpperFirst("hyperenhancing" A_EndChar),3)
    return
    :*B0:Hoec::
        sendByClipboard(StringUpperFirst("hypoenhancement"),3)
    return
    :*B0:Hyec::
        sendByClipboard(StringUpperFirst("hyperenhancement"),3)
    return
    :B0:Extv::
        sendByClipboard(StringUpperFirst("extravasation" A_EndChar),4)
    return
    :B0:Si::
        sendByClipboard(StringUpperFirst("SI" A_EndChar),2)
    return
    :B0:Sii::
        sendByClipboard(StringUpperFirst("signal intensity" A_EndChar),3)
    return
    :B0:T2w::
        sendByClipboard(StringUpperFirst("T2WI" A_EndChar),3)
    return
    :B0:T1w::
        sendByClipboard(StringUpperFirst("T1WI" A_EndChar),3)
    return
    :B0:Stir::
        sendByClipboard(StringUpperFirst("T2 STIR" A_EndChar),4)
    return
    :B0:Flar::
        sendByClipboard(StringUpperFirst("T2 FLAIR" A_EndChar),4)
    return
    :cB0:Nj::
        sendByClipboard(StringUpperFirst("injury" A_EndChar),2)
    return
    :*B0:Spcm::
        sendByClipboard(StringUpperFirst("smooth passage of contrast media"),3)
    return
    :*B0:Obs0::
        sendByClipboard(StringUpperFirst("no definite obstructive lesion."),3)
    return
    :*B0:Lap0::
        sendByClipboard(StringUpperFirst("no definite lymphadenopathy."),3)
    return
    :B0:Mmp::
        sendByClipboard(StringUpperFirst("mammoplasty" A_EndChar),3)
    return
    :B0:Eqv::
        sendByClipboard(StringUpperFirst("equivocal" A_EndChar),3)
    return
    :B0:Ktz::
        sendByClipboard(StringUpperFirst("Please refer to key image series for possible transition zone." A_EndChar),3)
    return
    :B0:Tzn::
        sendByClipboard(StringUpperFirst("transition zone" A_EndChar),3)
    return
    :B0:Pav::
        sendByClipboard(StringUpperFirst("patent major arteries and veins." A_EndChar),3)
    return
    :B0:Ama::
        sendByClipboard(StringUpperFirst("as mentioned above" A_EndChar),3)
    return
    :B0:Geo::
        sendByClipboard(StringUpperFirst("geographic" A_EndChar),3)
    return
    :B0:Ns::
        sendByClipboard(StringUpperFirst("no significant findings in this study." A_EndChar),2)
    return
    :B0:Sct::
        sendByClipboard(StringUpperFirst("scattered" A_EndChar),3)
    return
    :B0:Ids::
        sendByClipboard(StringUpperFirst("indiscernible" A_EndChar),3)
    return
    :B0:Mj::
        sendByClipboard(StringUpperFirst("major" A_EndChar),2)
    return
    :B0:Mn::
        sendByClipboard(StringUpperFirst("minor" A_EndChar),2)
    return
    :B0:Rct::
        sendByClipboard(StringUpperFirst("recent" A_EndChar),3)
    return
    :B0:Stu::
        sendByClipboard(StringUpperFirst("structure" A_EndChar),3)
    return
    :*B0:Stu1::
        sendByClipboard(StringUpperFirst("structures"),3)
    return
    :B0:Cpn::
        sendByClipboard(StringUpperFirst("component" A_EndChar),3)
    return
    :*B0:Cpn1::
        sendByClipboard(StringUpperFirst("components"),3)
    return
    :B0:Wl::
        sendByClipboard(StringUpperFirst("wall" A_EndChar),2)
    return
    :B0:Sgm::
        sendByClipboard(StringUpperFirst("sigmoid" A_EndChar),3)
    return
    :B0:Ctn::
        sendByClipboard(StringUpperFirst("contents" A_EndChar),3)
    return
    :B0:Vas::
        sendByClipboard(StringUpperFirst("vascular" A_EndChar),3)
    return
    :B0:Cls::
        sendByClipboard(StringUpperFirst("clustered" A_EndChar),3)
    return
    :B0:Fbd::
        sendByClipboard(StringUpperFirst("fibrous dysplasia" A_EndChar),3)
    return
    :B0:Ncc::
        sendByClipboard(StringUpperFirst("necrotic change" A_EndChar),3)
    return
    :B0:Ncm::
        sendByClipboard(StringUpperFirst("necrotic mass" A_EndChar),3)
    return
    :B0:Lpd::
        sendByClipboard(StringUpperFirst("lymphoproliferative disease" A_EndChar),3)
    return
    :B0:Ewt::
        sendByClipboard(StringUpperFirst("edematous wall thickening" A_EndChar),3)
    return
    :B0:Pdc::
        sendByClipboard(StringUpperFirst("peduncle" A_EndChar),3)
    return
    :*B0:Pdc1::
        sendByClipboard(StringUpperFirst("peduncles"),3)
    return
    :B0:Bna::
        sendByClipboard(StringUpperFirst("benign appearance" A_EndChar),3)
    return
    :B0:Wba::
        sendByClipboard(StringUpperFirst("with benign appearance" A_EndChar),3)
    return
    :B0:Ape::
        sendByClipboard(StringUpperFirst("appearance" A_EndChar),3)
    return
    :B0:Hoc::
        sendByClipboard(StringUpperFirst("hypodense change" A_EndChar),3)
    return
    :B0:Fhc::
        sendByClipboard(StringUpperFirst("focal hypodense change" A_EndChar),3)
    return
    :B0:Ren::
        sendByClipboard(StringUpperFirst("rim-enhancing" A_EndChar),3)
    return
    :B0:Itn::
        sendByClipboard(StringUpperFirst("internal" A_EndChar),3)
    return
    :B0:Etn::
        sendByClipboard(StringUpperFirst("external" A_EndChar),3)
    return
    :B0:Mal::
        sendByClipboard(StringUpperFirst("mass lesion" A_EndChar),3)
    return
    :*B0:Mal1::
        sendByClipboard(StringUpperFirst("mass lesions"),3)
    return
    :B0:Pow::
        sendByClipboard(StringUpperFirst("posterior wall" A_EndChar),3)
    return
    :B0:Anw::
        sendByClipboard(StringUpperFirst("anterior wall" A_EndChar),3)
    return
    :B0:Law::
        sendByClipboard(StringUpperFirst("lateral wall" A_EndChar),3)
    return
    :B0:Mew::
        sendByClipboard(StringUpperFirst("medial wall" A_EndChar),3)
    return
    :B0:Inw::
        sendByClipboard(StringUpperFirst("inferior wall" A_EndChar),3)
    return
    :B0:Suw::
        sendByClipboard(StringUpperFirst("superior wall" A_EndChar),3)
    return
    :B0:Flo::
        sendByClipboard(StringUpperFirst("floor" A_EndChar),3)
    return
    :B0:Hh::
        sendByClipboard(StringUpperFirst("high" A_EndChar),2)
    return
    :B0:Bld::
        sendByClipboard(StringUpperFirst("blood" A_EndChar),3)
    return
    :B0:Clc::
        sendByClipboard(StringUpperFirst("collection" A_EndChar),3)
    return
    :B0:Rsd::
        sendByClipboard(StringUpperFirst("residual" A_EndChar),3)
    return
    :B0:Thw::
        sendByClipboard(StringUpperFirst("thin-walled" A_EndChar),3)
    return
    :B0:Amr::
        sendByClipboard(StringUpperFirst("amorphous" A_EndChar),3)
    return
    :B0:Trt::
        sendByClipboard(StringUpperFirst("treated" A_EndChar),3)
    return
    :B0:Eln::
        sendByClipboard(StringUpperFirst("enlarged lymph node" A_EndChar),3)
    return
    :*B0:Eln1::
        sendByClipboard(StringUpperFirst("enlarged lymph nodes"),3)
    return
    :B0:Stas::
        sendByClipboard(StringUpperFirst("some soft tissue around the sutures" A_EndChar),4)
    return
    :B0:Bkg::
        sendByClipboard(StringUpperFirst("background" A_EndChar),3)
    return
    :B0:Itr::
        sendByClipboard(StringUpperFirst("intrathoracic" A_EndChar),3)
    return
    :B0:Cor::
        sendByClipboard(StringUpperFirst("coronal" A_EndChar),3)
    return
    :B0:Sag::
        sendByClipboard(StringUpperFirst("sagittal" A_EndChar),3)
    return
    :B0:Ax::
        sendByClipboard(StringUpperFirst("axial" A_EndChar),2)
    return
    :B0:Boi::
        sendByClipboard(StringUpperFirst("non-specific sclerotic foci." A_EndChar),3)
    return
    :*B0:Boi1::
        sendByClipboard(StringUpperFirst("non-specific sclerotic focus at"),3)
    return
    :B0:Vsb::
        sendByClipboard(StringUpperFirst("visible bones" A_EndChar),3)
    return
    :B0:Arn::
        sendByClipboard(StringUpperFirst("around" A_EndChar),3)
    return
    :B0:Srr::
        sendByClipboard(StringUpperFirst("surrounding" A_EndChar),3)
    return
    :B0:Sev::
        sendByClipboard(StringUpperFirst("several" A_EndChar),3)
    return
    :B0:Nm::
        sendByClipboard(StringUpperFirst("numerous" A_EndChar),2)
    return
    :B0:Crc::
        sendByClipboard(StringUpperFirst("circulation" A_EndChar),3)
    return
    :B0:Ipm::
        sendByClipboard(StringUpperFirst("if proven malignancy" A_EndChar),3)
    return
    :B0:Fxa::
        sendByClipboard(StringUpperFirst("fixation" A_EndChar),3)
    return
    :B0:Psf::
        sendByClipboard(StringUpperFirst("Please see the images and findings." A_EndChar),3)
    return
    :B0:Edc::
        sendByClipboard(StringUpperFirst("edematous change" A_EndChar),3)
    return
    :B0:Col::
        sendByClipboard(StringUpperFirst("collateral" A_EndChar),3)
    return
    :*B0:Col1::
        sendByClipboard(StringUpperFirst("collaterals"),3)
    return
    :B0:Ank::
        sendByClipboard(StringUpperFirst("ankylosing spondylitis" A_EndChar),3)
    return
    :B0:Fos::
        sendByClipboard(StringUpperFirst("fossa" A_EndChar),3)
    return
    :B0:Cau::
        sendByClipboard(StringUpperFirst("causing" A_EndChar),3)
    return
    :B0:Blg::
        sendByClipboard(StringUpperFirst("bulging" A_EndChar),3)
    return
    :B0:Hi::
        sendByClipboard(StringUpperFirst("hilar" A_EndChar),2)
    return
    :B0:Hl::
        sendByClipboard(StringUpperFirst("hilum" A_EndChar),2)
    return
    :B0:Ndo::
        sendByClipboard(StringUpperFirst("nodular opacity" A_EndChar),3)
    return
    :*B0:Ndo1::
        sendByClipboard(StringUpperFirst("nodular opacities"),3)
    return
    :*B0:Mlo1::
        sendByClipboard(StringUpperFirst("mass-like opacities"),3)
    return
    :B0:Msl::
        sendByClipboard(StringUpperFirst("mass-like" A_EndChar),3)
    return
    :B0:Arp::
        sendByClipboard(StringUpperFirst("arthroplasty" A_EndChar),3)
    return
    :B0:Fnd::
        sendByClipboard(StringUpperFirst("finding" A_EndChar),3)
    return
    :*B0:Fnd1::
        sendByClipboard(StringUpperFirst("findings"),3)
    return
    :B0:Rst::
        sendByClipboard(StringUpperFirst("roughly unchanged" A_EndChar),3)
    return
    :*B0:Rstm::
        sendByClipboard(StringUpperFirst("roughly unchanged but malignancy can not be excluded."),3)
    return
    :B0:Rf::
        sendByClipboard(StringUpperFirst("roughly" A_EndChar),2)
    return
    :B0:Mll::
        sendByClipboard(StringUpperFirst("mass-like lesion" A_EndChar),3)
    return
    :B0:Bod::
        sendByClipboard(StringUpperFirst("bony defect" A_EndChar),3)
    return
    :B0:Coi::
        sendByClipboard(StringUpperFirst("coiling" A_EndChar),3)
    return
    :B0:Dpr::
        sendByClipboard(StringUpperFirst("disappearance" A_EndChar),3)
    return
    :*B0:Dpr1::
        sendByClipboard(StringUpperFirst("disappeared"),3)
    return
    :B0:Ndl::
        sendByClipboard(StringUpperFirst("nodular lesion" A_EndChar),3)
    return
    :*B0:Ndl1::
        sendByClipboard(StringUpperFirst("nodular lesions"),3)
    return
    :B0:Ndd::
        sendByClipboard(StringUpperFirst("nodular density" A_EndChar),3)
    return
    :*B0:Ndd1::
        sendByClipboard(StringUpperFirst("nodular densities"),3)
    return
    :B0:Ndp::
        sendByClipboard(StringUpperFirst("nodular opacity" A_EndChar),3)
    return
    :*B0:Ndp1::
        sendByClipboard(StringUpperFirst("nodular opacities"),3)
    return
    :B0:Nth::
        sendByClipboard(StringUpperFirst("nodular thickening" A_EndChar),3)
    return
    :B0:Wdg::
        sendByClipboard(StringUpperFirst("wedge" A_EndChar),3)
    return
    :B0:Nut::
        sendByClipboard(StringUpperFirst("neurogenic tumor" A_EndChar),3)
    return
    :B0:Skk::
        sendByClipboard(StringUpperFirst("sclerotic focus" A_EndChar),3)
    return
    :B0:Ski::
        sendByClipboard(StringUpperFirst("sclerotic foci" A_EndChar),3)
    return
    :B0:Ctl::
        sendByClipboard(StringUpperFirst("cartilage" A_EndChar),3)
    return
    :B0:Rta::
        sendByClipboard(StringUpperFirst("retraction" A_EndChar),3)
    return
    :B0:Pvc::
        sendByClipboard(StringUpperFirst("perivascular" A_EndChar),3)
    return
    :B0:Sft::
        sendByClipboard(StringUpperFirst("soft tissue" A_EndChar),3)
    return
    :B0:Sue::
        sendByClipboard(StringUpperFirst("subcutaneous emphysema" A_EndChar),3)
    return
    :B0:Bfr::
        sendByClipboard(StringUpperFirst("bone fragment" A_EndChar),3)
    return
    :*B0:Bfr1::
        sendByClipboard(StringUpperFirst("bone fragments"),3)
    return
    :B0:Cyl::
        sendByClipboard(StringUpperFirst("cystic lesion" A_EndChar),3)
    return
    :*B0:Cyl1::
        sendByClipboard(StringUpperFirst("cystic lesions"),3)
    return
    :B0:Cyc::
        sendByClipboard(StringUpperFirst("cystic change" A_EndChar),3)
    return
    :B0:Fis::
        sendByClipboard(StringUpperFirst("fistula" A_EndChar),3)
    return
    :B0:G1::
        sendByClipboard(StringUpperFirst("grade 1" A_EndChar),2)
    return
    :B0:G2::
        sendByClipboard(StringUpperFirst("grade 2" A_EndChar),2)
    return
    :B0:G3::
        sendByClipboard(StringUpperFirst("grade 3" A_EndChar),2)
    return
    :B0:G4::
        sendByClipboard(StringUpperFirst("grade 4" A_EndChar),2)
    return
    :B0:Rcn::
        sendByClipboard(StringUpperFirst("reconstruction" A_EndChar),3)
    return
    :B0:Ldc::
        sendByClipboard(StringUpperFirst("low density change" A_EndChar),3)
    return
    :B0:Sti::
        sendByClipboard(StringUpperFirst("soft tissue thickening" A_EndChar),3)
    return
    :B0:Pau::
        sendByClipboard(StringUpperFirst("penetrating atherosclerotic ulcer" A_EndChar),3)
    return
    :B0:Pvn::
        sendByClipboard(StringUpperFirst("previously noted" A_EndChar),3)
    return
    :B0:Psg::
        sendByClipboard(StringUpperFirst("parasagittal" A_EndChar),3)
    return
    :B0:Mur::
        sendByClipboard(StringUpperFirst("mural" A_EndChar),3)
    return
    :B0:Mtr::
        sendByClipboard(StringUpperFirst("mural thrombus" A_EndChar),3)
    return
    :B0:Sol::
        sendByClipboard(StringUpperFirst("space-occupying lesion" A_EndChar),3)
    return
    :B0:Swe::
        sendByClipboard(StringUpperFirst("swelling" A_EndChar),3)
    return
    :B0:Swo::
        sendByClipboard(StringUpperFirst("swollen" A_EndChar),3)
    return
    :B0:Aor::
        sendByClipboard(StringUpperFirst("and/or" A_EndChar),3)
    return
    :B0:Bos::
        sendByClipboard(StringUpperFirst("borderline sized" A_EndChar),3)
    return
    :B0:Rfy::
        sendByClipboard(StringUpperFirst("roughly" A_EndChar),3)
    return
    :B0:Abt::
        sendByClipboard(StringUpperFirst("about" A_EndChar),3)
    return
    :B0:Pst::
        sendByClipboard(StringUpperFirst("positive" A_EndChar),3)
    return
    :B0:Xps::
        sendByClipboard(StringUpperFirst("expansile" A_EndChar),3)
    return
    :B0:Vz::
        sendByClipboard(StringUpperFirst("of varying sizes" A_EndChar),2)
    return
    :B0:Def::
        sendByClipboard(StringUpperFirst("deformity" A_EndChar),3)
    return
    :B0:Orf::
        sendByClipboard(StringUpperFirst("orifice" A_EndChar),3)
    return
    :B0:Aan::
        sendByClipboard(StringUpperFirst("aortic aneurysm" A_EndChar),3)
    return
    :B0:Aaa::
        sendByClipboard(StringUpperFirst("abdominal aortic aneurysm" A_EndChar),3)
    return
    :B0:Adl::
        sendByClipboard(StringUpperFirst("aneurysmal dilatation" A_EndChar),3)
    return
    :B0:Ac::
        sendByClipboard(StringUpperFirst("acute" A_EndChar),2)
    return
    :B0:Sak::
        sendByClipboard(StringUpperFirst("subacute" A_EndChar),3)
    return
    :B0:Mub::
        sendByClipboard(StringUpperFirst("multiple bilateral" A_EndChar),3)
    return
    :B0:Cas::
        sendByClipboard(StringUpperFirst("calcification or stone" A_EndChar),3)
    return
    :B0:Ed::
        sendByClipboard(StringUpperFirst("edema" A_EndChar),2)
    return
    :B0:Num::
        sendByClipboard(StringUpperFirst("number" A_EndChar),3)
    return
    :B0:Slx::
        sendByClipboard(StringUpperFirst("subluxation" A_EndChar),3)
    return
    :B0:Dlk::
        sendByClipboard(StringUpperFirst("dislocation" A_EndChar),3)
    return
    :B0:Vt::
        sendByClipboard(StringUpperFirst("vertebra" A_EndChar),2)
    return
    :*B0:Vt1::
        sendByClipboard(StringUpperFirst("vertebrae"),2)
    return
    :B0:Vtb::
        sendByClipboard(StringUpperFirst("vertebral" A_EndChar),3)
    return
    :B0:Api::
        sendByClipboard(StringUpperFirst("apical" A_EndChar),3)
    return
    :B0:Res::
        sendByClipboard(StringUpperFirst("resolution" A_EndChar),3)
    return
    :B0:Rs::
        sendByClipboard(StringUpperFirst("resolved" A_EndChar),2)
    return
    :*B0:Rs1::
        sendByClipboard(StringUpperFirst("resolving"),2)
    return
    :B0:Hmt::
        sendByClipboard(StringUpperFirst("hematoma" A_EndChar),3)
    return
    :*B0:Hmt1::
        sendByClipboard(StringUpperFirst("hematomas"),3)
    return
    :B0:Pc::
        sendByClipboard(StringUpperFirst("space" A_EndChar),2)
    return
    :*B0:Pc1::
        sendByClipboard(StringUpperFirst("space"),2)
    return
    :B0:Wen::
        sendByClipboard(StringUpperFirst("well-enhancing" A_EndChar),3)
    return
    :B0:Inn::
        sendByClipboard(StringUpperFirst("is not noted" A_EndChar),3)
    return
    :B0:Rpm::
        sendByClipboard(StringUpperFirst("replacement" A_EndChar),3)
    return
    :B0:Rp::
        sendByClipboard(StringUpperFirst("replaced" A_EndChar),2)
    return
    :B0:Cnn::
        sendByClipboard(StringUpperFirst("cannula" A_EndChar),3)
    return
    :*B0:Cnn1::
        sendByClipboard(StringUpperFirst("cannulas"),3)
    return
    :B0:Sys::
        sendByClipboard(StringUpperFirst("system" A_EndChar),3)
    return
    :B0:Cav::
        sendByClipboard(StringUpperFirst("cavitary" A_EndChar),3)
    return
    :B0:Pdm::
        sendByClipboard(StringUpperFirst("predominant" A_EndChar),3)
    return
    :*B0:Pdm1::
        sendByClipboard(StringUpperFirst("predominance"),3)
    return
    :B0:Stg::
        sendByClipboard(StringUpperFirst("staging" A_EndChar),3)
    return
    :B0:Bd::
        sendByClipboard(StringUpperFirst("border" A_EndChar),2)
    return
    :B0:Fk::
        sendByClipboard(StringUpperFirst("focus" A_EndChar),2)
    return
    :B0:Fi::
        sendByClipboard(StringUpperFirst("foci" A_EndChar),2)
    return
    :B0:Fkl::
        sendByClipboard(StringUpperFirst("focal" A_EndChar),3)
    return
    :B0:Sk::
        sendByClipboard(StringUpperFirst("sclerotic" A_EndChar),2)
    return
    :B0:Sks::
        sendByClipboard(StringUpperFirst("sclerosis" A_EndChar),3)
    return
    :B0:Tst::
        sendByClipboard(StringUpperFirst("tentative radiology staging" A_EndChar),3)
    return
    :B0:Oth::
        sendByClipboard(StringUpperFirst("other" A_EndChar),3)
    return
    :B0:Ano::
        sendByClipboard(StringUpperFirst("another" A_EndChar),3)
    return
    :B0:Rtr::
        sendByClipboard(StringUpperFirst("reticular" A_EndChar),3)
    return
    :B0:Dss::
        sendByClipboard(StringUpperFirst("dissection" A_EndChar),3)
    return
    :B0:Aod::
        sendByClipboard(StringUpperFirst("aortic dissection" A_EndChar),3)
    return
    :B0:Imh::
        sendByClipboard(StringUpperFirst("intramural hematoma" A_EndChar),3)
    return
    :*B0:Ns=::
        sendByClipboard(StringUpperFirst("is not seen in this study"),2)
    return
    :B0:Obv::
        sendByClipboard(StringUpperFirst("obvious" A_EndChar),3)
    return
    :B0:Djd::
        sendByClipboard(StringUpperFirst("degenerative change of spine" A_EndChar),3)
    return
    :B0:Djcf::
        sendByClipboard(StringUpperFirst("degenerative change of spine with compression fracture" A_EndChar),4)
    return
    :*B0:Djcf1::
        sendByClipboard(StringUpperFirst("degenerative change of spine with compression fractures"),4)
    return
    :*B0:Djop::
        sendByClipboard(StringUpperFirst("degenerative and post-operative change of spine"),3)
    return
    :B0:Nal::
        sendByClipboard(StringUpperFirst("normal alignment" A_EndChar),3)
    return
    :B0:Muc::
        sendByClipboard(StringUpperFirst("mucus" A_EndChar),3)
    return
    :B0:Mre::
        sendByClipboard(StringUpperFirst("mucus retention" A_EndChar),3)
    return
    :*B0:Met0::
        sendByClipboard(StringUpperFirst("no evidence of metastatic lesions."),3)
    return
    :*B0:Met00::
        sendByClipboard(StringUpperFirst("no evidence of metastatic lesions or lymphadenopathy."),4)
    return
    :B0:Sem::
        sendByClipboard(StringUpperFirst("subcutaneous emphysema" A_EndChar),3)
    return
    :B0:Clp::
        sendByClipboard(StringUpperFirst("collapse" A_EndChar),3)
    return
    :*B0:Clp1::
        sendByClipboard(StringUpperFirst("collapsed"),3)
    return
    :B0:Cpm::
        sendByClipboard(StringUpperFirst("cardiovascular implantable electronic device" A_EndChar),3)
    return
    :B0:Pgc::
        sendByClipboard(StringUpperFirst("pigtail catheter" A_EndChar),3)
    return
    :B0:Pgc1::
        sendByClipboard(StringUpperFirst("pigtail catheters" A_EndChar),4)
    return
    :B0:Flt::
        sendByClipboard(StringUpperFirst("flattening" A_EndChar),3)
    return
    :B0:Prv::
        sendByClipboard(StringUpperFirst("previous" A_EndChar),3)
    return
    :B0:Cfl::
        sendByClipboard(StringUpperFirst("confluent" A_EndChar),3)
    return
    :B0:Prr::
        sendByClipboard(StringUpperFirst("prior" A_EndChar),3)
    return
    :B0:Gri::
        sendByClipboard(StringUpperFirst("granulomatous infection" A_EndChar),3)
    return
    :B0:Spi::
        sendByClipboard(StringUpperFirst("spiculated" A_EndChar),3)
    return
    :B0:Sed::
        sendByClipboard(StringUpperFirst("seedings" A_EndChar),3)
    return
    :*B0:Sed0::
        sendByClipboard(StringUpperFirst("seeding"),3)
    return
    :B0:Crs::
        sendByClipboard(StringUpperFirst("coarse" A_EndChar),3)
    return
    :B0:Bnn::
        sendByClipboard(StringUpperFirst("benign" A_EndChar),3)
    return
    :B0:Mlg::
        sendByClipboard(StringUpperFirst("malignancy" A_EndChar),3)
    return
    :*B0:Slgr::
        sendByClipboard(StringUpperFirst("slow-growing"),3)
    return
    :B0:Sym::
        sendByClipboard(StringUpperFirst("symmetric" A_EndChar),3)
    return
    :B0:Prn::
        sendByClipboard(StringUpperFirst("prolonged" A_EndChar),3)
    return
    :B0:Acc::
        sendByClipboard(StringUpperFirst("accessory" A_EndChar),3)
    return
    :B0:Nv::
        sendByClipboard(StringUpperFirst("nerve" A_EndChar),2)
    return
    :*B0:Nv1::
        sendByClipboard(StringUpperFirst("nerves"),2)
    return
    :B0:Ms::
        sendByClipboard(StringUpperFirst("muscle" A_EndChar),2)
    return
    :*B0:Ms1::
        sendByClipboard(StringUpperFirst("muscles"),2)
    return
    :B0:Bn::
        sendByClipboard(StringUpperFirst("bone" A_EndChar),2)
    return
    :*B0:Bns::
        sendByClipboard(StringUpperFirst("bones"),2)
    return
    :*B0:Lore::
        sendByClipboard(StringUpperFirst("loco-regional"),3)
    return
    :B0:Pt::
        sendByClipboard(StringUpperFirst("patchy" A_EndChar),2)
    return
    :B0:Ecc::
        sendByClipboard(StringUpperFirst("eccentric" A_EndChar),3)
    return
    :B0:Ccc::
        sendByClipboard(StringUpperFirst("concentric" A_EndChar),3)
    return
    :B0:Ki::
        sendByClipboard(StringUpperFirst("(Please refer to key image series.)" A_EndChar),2)
    return
    :B0:Ref::
        sendByClipboard(StringUpperFirst("Please refer to the text above for detailed findings." A_EndChar),3)
    return
    :B0:Isa::
        sendByClipboard(StringUpperFirst("in short axis" A_EndChar),3)
    return
    :B0:Igd::
        sendByClipboard(StringUpperFirst("in greatest dimension" A_EndChar),3)
    return
    :B0:Ch::
        sendByClipboard(StringUpperFirst("change" A_EndChar),2)
    return
    :*B0:Ch1::
        sendByClipboard(StringUpperFirst("changes"),2)
    return
    :B0:Bo::
        sendByClipboard(StringUpperFirst("both" A_EndChar),2)
    return
    :B0:Wid::
        sendByClipboard(StringUpperFirst("widening" A_EndChar),3)
    return
    :B0:Thew::
        sendByClipboard(StringUpperFirst("abnormal thickening and enhancing wall" A_EndChar),4)
    return
    :B0:Vpt::
        sendByClipboard(StringUpperFirst("vertebroplasty" A_EndChar),3)
    return
    :B0:Unk::
        sendByClipboard(StringUpperFirst("unknown (unavailable) history in N hospital" A_EndChar),3)
    return
    :B0:Ty::
        sendByClipboard(StringUpperFirst("typical" A_EndChar),2)
    return
    :B0:Aty::
        sendByClipboard(StringUpperFirst("atypical" A_EndChar),3)
    return
    :*B0:Tstc::
        sendByClipboard(StringUpperFirst("too small to characterize"),3)
    return
    :B0:Tsc::
        sendByClipboard(StringUpperFirst("tuberous sclerosis complex" A_EndChar),3)
    return
    :B0:Std::
        sendByClipboard(StringUpperFirst("soft tissue density" A_EndChar),3)
    return
    :*B0:Std1::
        sendByClipboard(StringUpperFirst("soft tissue densities"),3)
    return
    :B0:Sot::
        sendByClipboard(StringUpperFirst("soft tissue" A_EndChar),3)
    return
    :B0:Sw::
        sendByClipboard(StringUpperFirst("shadow" A_EndChar),2)
    return
    :B0:Scem::
        sendByClipboard(StringUpperFirst("subcutaneous emphysema" A_EndChar),4)
    return
    :B0:Sch::
        sendByClipboard(StringUpperFirst("sclerotic change" A_EndChar),3)
    return
    :B0:Skf::
        sendByClipboard(StringUpperFirst("sclerotic foci" A_EndChar),3)
    return
    :B0:Scl::
        sendByClipboard(StringUpperFirst("surgical clips" A_EndChar),3)
    return
    :B0:Pr::
        sendByClipboard(StringUpperFirst("partial" A_EndChar),2)
    return
    :B0:Py::
        sendByClipboard(StringUpperFirst("partially" A_EndChar),2)
    return
    :B0:Pq::
        sendByClipboard(StringUpperFirst("plaque" A_EndChar),2)
    return
    :*B0:Pq1::
        sendByClipboard(StringUpperFirst("plaques"),2)
    return
    :B0:Plq::
        sendByClipboard(StringUpperFirst("pleural plaque" A_EndChar),3)
    return
    :*B0:Plq1::
        sendByClipboard(StringUpperFirst("pleural plaques"),3)
    return
    :B0:Ovr::
        sendByClipboard(StringUpperFirst("overriding" A_EndChar),3)
    return
    :B0:Ocm::
        sendByClipboard(StringUpperFirst("oral contrast media" A_EndChar),3)
    return
    :B0:Nrt::
        sendByClipboard(StringUpperFirst("no evidence of recurrent tumor." A_EndChar),3)
    return
    :*B0:Nrtl::
        sendByClipboard(StringUpperFirst("no evidence of recurrent tumor or lymphadenopathy."),3)
    return
    :*B0:Nrt1::
        sendByClipboard(StringUpperFirst("no evidence of residual tumor."),3)
    return
    :*B0:Nrt2::
        sendByClipboard(StringUpperFirst("no evidence of residual/recurrent tumor."),3)
    return
    :*B0:Opnrt::
        sendByClipboard(StringUpperFirst("post-operative changes. no evidence of recurrent tumor."),4)
    return
    :*B0:Oprtn::
        sendByClipboard(StringUpperFirst("post-operative and post-radiation changes. no evidence of recurrent tumor."),4)
    return
    :B0:Nse::
        sendByClipboard(StringUpperFirst("no solid or enhancing part is noted" A_EndChar),3)
    return
    :B0:Bog::
        sendByClipboard(StringUpperFirst("bowel gas" A_EndChar),3)
    return
    :B0:Nic::
        sendByClipboard(StringUpperFirst("no significant interval change." A_EndChar),3)
    return
    :B0:Nfl::
        sendByClipboard(StringUpperFirst("no definite focal lesion" A_EndChar),3)
    return
    :B0:Mob::
        sendByClipboard(StringUpperFirst("more obvious" A_EndChar),3)
    return
    :B0:Mk::
        sendByClipboard(StringUpperFirst("marked" A_EndChar),2)
    return
    :*B0:Mk1::
        sendByClipboard(StringUpperFirst("markedly"),2)
    return
    :B0:Mxd::
        sendByClipboard(StringUpperFirst("maximal diameter" A_EndChar),3)
    return
    :B0:Lbu::
        sendByClipboard(StringUpperFirst("lobulated" A_EndChar),3)
    return
    :B0:Lcu::
        sendByClipboard(StringUpperFirst("loculated" A_EndChar),3)
    return
    :B0:Vn::
        sendByClipboard(StringUpperFirst("vein" A_EndChar),2)
    return
    :*B0:Vn1::
        sendByClipboard(StringUpperFirst("veins"),2)
    return
    :B0:Vsl::
        sendByClipboard(StringUpperFirst("vessel" A_EndChar),3)
    return
    :*B0:Vsl1::
        sendByClipboard(StringUpperFirst("vessels"),3)
    return
    :B0:Vsc::
        sendByClipboard(StringUpperFirst("vasculatures" A_EndChar),3)
    return
    :B0:Its::
        sendByClipboard(StringUpperFirst("in this study" A_EndChar),3)
    return
    :B0:Isf::
        sendByClipboard(StringUpperFirst("is found" A_EndChar),3)
    return
    :B0:Ixp::
        sendByClipboard(StringUpperFirst("infectious process" A_EndChar),3)
    return
    :B0:Ifp::
        sendByClipboard(StringUpperFirst("inflammatory process" A_EndChar),3)
    return
    :B0:Fxp::
        sendByClipboard(StringUpperFirst("inflammatory/infectious process" A_EndChar),3)
    return
    :*B0:Fxp1::
        sendByClipboard(StringUpperFirst("inflammatory/infectious process of lung, suggest clinical correlation and follow up."),3)
    return
    :*B0:Fxp2::
        sendByClipboard(StringUpperFirst("inflammatory/infectious process of lung, more prominent, suggest clinical correlation and follow up."),3)
    return
    :*B0:Fxp3::
        sendByClipboard(StringUpperFirst("inflammatory/infectious process of lung, less prominent, suggest clinical correlation and follow up."),3)
    return
    :B0:Fxc::
        sendByClipboard(StringUpperFirst("inflammatory/infectious change" A_EndChar),3)
    return
    :B0:Ifc::
        sendByClipboard(StringUpperFirst("inflammatory change" A_EndChar),3)
    return
    :B0:Ndt::
        sendByClipboard(StringUpperFirst("indentation" A_EndChar),3)
    return
    :B0:Inci::
        sendByClipboard(StringUpperFirst("incidentally" A_EndChar),4)
    return
    :B0:Idn::
        sendByClipboard(StringUpperFirst("identified" A_EndChar),3)
    return
    :B0:Isi::
        sendByClipboard(StringUpperFirst("is identified" A_EndChar),3)
    return
    :B0:Hm::
        sendByClipboard(StringUpperFirst("hemorrhagic" A_EndChar),2)
    return
    :B0:Grt::
        sendByClipboard(StringUpperFirst("granulation tissue" A_EndChar),3)
    return
    :B0:Fsf::
        sendByClipboard(StringUpperFirst("fusiform" A_EndChar),3)
    return
    :B0:Foc::
        sendByClipboard(StringUpperFirst("focal lesion" A_EndChar),3)
    return
    :B0:Fpl::
        sendByClipboard(StringUpperFirst("fat plane" A_EndChar),3)
    return
    :B0:Ffl::
        sendByClipboard(StringUpperFirst("fluid-fluid level" A_EndChar),3)
    return
    :B0:Ff::
        sendByClipboard(StringUpperFirst("fluid-fluid layering" A_EndChar),2)
    return
    :B0:Eva::
        sendByClipboard(StringUpperFirst("evaluation" A_EndChar),3)
    return
    :B0:Fev::
        sendByClipboard(StringUpperFirst("further evaluation" A_EndChar),3)
    return
    :B0:Fct::
        sendByClipboard(StringUpperFirst("fat-containing tumor" A_EndChar),3)
    return
    :B0:Fcn::
        sendByClipboard(StringUpperFirst("fat-containing nodule" A_EndChar),3)
    return
    :B0:Fcm::
        sendByClipboard(StringUpperFirst("fat-containing mass" A_EndChar),3)
    return
    :B0:Fla::
        sendByClipboard(StringUpperFirst("fluid accumulation" A_EndChar),3)
    return
    :B0:Flr::
        sendByClipboard(StringUpperFirst("fluid retention" A_EndChar),3)
    return
    :B0:Eti::
        sendByClipboard(StringUpperFirst("The etiology should be further evaluated." A_EndChar),3)
    return
    :B0:Sfe::
        sendByClipboard(StringUpperFirst("suggest further evaluation." A_EndChar),3)
    return
    :B0:Emf::
        sendByClipboard(StringUpperFirst("emphysematous" A_EndChar),3)
    return
    :cB0:Eca::
        sendByClipboard(StringUpperFirst("encasement" A_EndChar),3)
    return
    :B0:Ele::
        sendByClipboard(StringUpperFirst("elevated" A_EndChar),3)
    return
    :B0:Drt::
        sendByClipboard(StringUpperFirst("drainage tube" A_EndChar),3)
    return
    :*B0:Drt1::
        sendByClipboard(StringUpperFirst("drainage tubes"),3)
    return
    :B0:Dst::
        sendByClipboard(StringUpperFirst("distended" A_EndChar),3)
    return
    :*B0:Dst1::
        sendByClipboard(StringUpperFirst("distention"),3)
    return
    :B0:Dlg::
        sendByClipboard(StringUpperFirst("dislodgement" A_EndChar),3)
    return
    :B0:Dfs::
        sendByClipboard(StringUpperFirst("diffuse" A_EndChar),3)
    return
    :B0:Dfy::
        sendByClipboard(StringUpperFirst("diffusely" A_EndChar),3)
    return
    :B0:Dao::
        sendByClipboard(StringUpperFirst("details are obscured" A_EndChar),3)
    return
    :B0:Des::
        sendByClipboard(StringUpperFirst("destruction" A_EndChar),3)
    return
    :B0:Dep::
        sendByClipboard(StringUpperFirst("dependent" A_EndChar),3)
    return
    :*B0:Cn1::
        sendByClipboard(StringUpperFirst("cancerous"),2)
    return
    :B0:Stn::
        sendByClipboard(StringUpperFirst("stenting" A_EndChar),3)
    return
    :B0:Cm::
        sendByClipboard(StringUpperFirst("contrast media" A_EndChar),2)
    return
    :B0:Cir::
        sendByClipboard(StringUpperFirst("circumferential" A_EndChar),3)
    return
    :B0:Cli::
        sendByClipboard(StringUpperFirst("clinical" A_EndChar),3)
    return
    :B0:Rr::
        sendByClipboard(StringUpperFirst("on the right side" A_EndChar),2)
    return
    :B0:Ll::
        sendByClipboard(StringUpperFirst("on the left side" A_EndChar),2)
    return
    :B0:Bnt::
        sendByClipboard(StringUpperFirst("blunting" A_EndChar),3)
    return
    :B0:Asw::
        sendByClipboard(StringUpperFirst("associated with" A_EndChar),3)
    return
    :B0:Att::
        sendByClipboard(StringUpperFirst("attenuation" A_EndChar),3)
    return
    :B0:Pft::
        sendByClipboard(StringUpperFirst("perifocal fat stranding" A_EndChar),3)
    return
    :B0:Mfs::
        sendByClipboard(StringUpperFirst("mesenteric fat stranding" A_EndChar),3)
    return
    :B0:Aph::
        sendByClipboard(StringUpperFirst("arterial phase" A_EndChar),3)
    return
    :B0:Pvp::
        sendByClipboard(StringUpperFirst("portal venous phase" A_EndChar),3)
    return
    :B0:Vph::
        sendByClipboard(StringUpperFirst("venous phase" A_EndChar),3)
    return
    :B0:Ap::
        sendByClipboard(StringUpperFirst("air pockets" A_EndChar),2)
    return
    :B0:Amo::
        sendByClipboard(StringUpperFirst("amount of" A_EndChar),3)
    return
    :B0:Ana::
        sendByClipboard(StringUpperFirst("anastomosis" A_EndChar),3)
    return
    :*B0:Ana1::
        sendByClipboard(StringUpperFirst("anastomotic"),3)
    return
    :B0:Prc::
        sendByClipboard(StringUpperFirst("parenchyma" A_EndChar),3)
    return
    :B0:Prc1::
        sendByClipboard(StringUpperFirst("parenchymal" A_EndChar),4)
    return
    :B0:Tnn::
        sendByClipboard(StringUpperFirst("thinning" A_EndChar),3)
    return
    :B0:Rel::
        sendByClipboard(StringUpperFirst("relative" A_EndChar),3)
    return
    :B0:Eng::
        sendByClipboard(StringUpperFirst("engorged" A_EndChar),3)
    return
    :B0:Vsz::
        sendByClipboard(StringUpperFirst("variable-sized" A_EndChar),3)
    return
    :B0:Ifx::
        sendByClipboard(StringUpperFirst("infection" A_EndChar),3)
    return
    :B0:Tbx::
        sendByClipboard(StringUpperFirst("tuberculous infection" A_EndChar),3)
    return
    :B0:Sos::
        sendByClipboard(StringUpperFirst("suboptimal study" A_EndChar),3)
    return
    :B0:Sos1::
        sendByClipboard(StringUpperFirst("suboptimal study due to motion artifact" A_EndChar),4)
    return
    :B0:Sos2::
        sendByClipboard(StringUpperFirst("suboptimal study due to malpositioning." A_EndChar),4)
    return
    :B0:Prl::
        sendByClipboard(StringUpperFirst("probably related to" A_EndChar),3)
    return
    :B0:Prx::
        sendByClipboard(StringUpperFirst("pre-existing" A_EndChar),3)
    return
    :B0:Nva::
        sendByClipboard(StringUpperFirst("normal variant" A_EndChar),3)
    return
    :B0:Afl::
        sendByClipboard(StringUpperFirst("air-fluid level" A_EndChar),3)
    return
    :B0:Mae::
        sendByClipboard(StringUpperFirst("mass effect" A_EndChar),3)
    return
    :B0:Oprt::
        sendByClipboard(StringUpperFirst("post-operative and post-radiation changes" A_EndChar),4)
    return
    :B0:Rtc::
        sendByClipboard(StringUpperFirst("post-radiation change" A_EndChar),3)
    return
    :B0:Txc::
        sendByClipboard(StringUpperFirst("post-treatment changes" A_EndChar),3)
    return
    :B0:Abc::
        sendByClipboard(StringUpperFirst("post-ablation changes" A_EndChar),3)
    return
    :B0:Nec::
        sendByClipboard(StringUpperFirst("necrosis" A_EndChar),3)
    return
    :*B0:Nec1::
        sendByClipboard(StringUpperFirst("necrotic"),3)
    return
    :B0:Yre::
        sendByClipboard(StringUpperFirst("hyperemia" A_EndChar),3)
    return
    :B0:Yrc::
        sendByClipboard(StringUpperFirst("hyperemic change" A_EndChar),3)
    return
    :B0:Flc::
        sendByClipboard(StringUpperFirst("fluid collection" A_EndChar),3)
    return
    :B0:Dev::
        sendByClipboard(StringUpperFirst("deviation" A_EndChar),3)
    return
    :B0:Rco::
        sendByClipboard(StringUpperFirst("reconstitution" A_EndChar),3)
    return
    :B0:Ivs::
        sendByClipboard(StringUpperFirst("invasion" A_EndChar),3)
    return
    :B0:Ltz::
        sendByClipboard(StringUpperFirst("lateralization" A_EndChar),3)
    return
    :B0:Mdz::
        sendByClipboard(StringUpperFirst("medialization" A_EndChar),3)
    return
    :B0:Dz::
        sendByClipboard(StringUpperFirst("disease" A_EndChar),2)
    return
    :B0:Inv::
        sendByClipboard(StringUpperFirst("involving" A_EndChar),3)
    return
    :B0:Ivm::
        sendByClipboard(StringUpperFirst("involvement" A_EndChar),3)
    return
    :B0:Sh::
        sendByClipboard(StringUpperFirst("showing" A_EndChar),2)
    return
    :B0:Yd::
        sendByClipboard(StringUpperFirst("showed" A_EndChar),2)
    return
    :B0:Ys::
        sendByClipboard(StringUpperFirst("shows" A_EndChar),2)
    return
    :B0:Haz::
        sendByClipboard(StringUpperFirst("haziness" A_EndChar),3)
    return
    :B0:Owu::
        sendByClipboard(StringUpperFirst("otherwise unremarkable" A_EndChar),3)
    return
    :B0:Reg::
        sendByClipboard(StringUpperFirst("region" A_EndChar),3)
    return
    :*B0:Reg1::
        sendByClipboard(StringUpperFirst("regions"),3)
    return
    :*B0:Reg2::
        sendByClipboard(StringUpperFirst("regional"),3)
    return
    :B0:Asp::
        sendByClipboard(StringUpperFirst("aspect" A_EndChar),3)
    return
    :*B0:Asp1::
        sendByClipboard(StringUpperFirst("aspects"),3)
    return
    :B0:Fid::
        sendByClipboard(StringUpperFirst("filling defect" A_EndChar),3)
    return
    :*B0:Fid1::
        sendByClipboard(StringUpperFirst("filling defects"),3)
    return
    :B0:Xtn::
        sendByClipboard(StringUpperFirst("extension" A_EndChar),3)
    return
    :B0:Wxt::
        sendByClipboard(StringUpperFirst("with extension to" A_EndChar),3)
    return
    :B0:Hop::
        sendByClipboard(StringUpperFirst("hypoplastic" A_EndChar),3)
    return
    :*B0:Hop1::
        sendByClipboard(StringUpperFirst("hypoplasia"),3)
    return
    :B0:Tor::
        sendByClipboard(StringUpperFirst("tortuous" A_EndChar),3)
    return
    :B0:Psc::
        sendByClipboard(StringUpperFirst("presence" A_EndChar),3)
    return
    :B0:Ifn::
        sendByClipboard(StringUpperFirst("infarction" A_EndChar),3)
    return
    :*B0:Ifn1::
        sendByClipboard(StringUpperFirst("infarctions"),3)
    return
    :B0:Ifr::
        sendByClipboard(StringUpperFirst("infarct" A_EndChar),3)
    return
    :*B0:Ifr1::
        sendByClipboard(StringUpperFirst("infarcts"),3)
    return
    :B0:Isc::
        sendByClipboard(StringUpperFirst("ischemic change" A_EndChar),3)
    return
    :*B0:Isca::
        sendByClipboard(StringUpperFirst("ischemia"),3)
    return
    :B0:Dia::
        sendByClipboard(StringUpperFirst("diameter" A_EndChar),3)
    return
    :B0:Hrn::
        sendByClipboard(StringUpperFirst("hernia" A_EndChar),3)
    return
    :*B0:Hrn1::
        sendByClipboard(StringUpperFirst("herniation"),3)
    return
    :B0:Cmp::
        sendByClipboard(StringUpperFirst("compression" A_EndChar),3)
    return
    :*B0:Cmp1::
        sendByClipboard(StringUpperFirst("compressed"),3)
    return
    :B0:Bif::
        sendByClipboard(StringUpperFirst("bifurcation" A_EndChar),3)
    return
    :B0:Ter::
        sendByClipboard(StringUpperFirst("territory" A_EndChar),3)
    return
    :*B0:Mcat::
        sendByClipboard(StringUpperFirst("MCA territory"),3)
    return
    :*B0:Acat::
        sendByClipboard(StringUpperFirst("ACA territory"),3)
    return
    :*B0:Pcat::
        sendByClipboard(StringUpperFirst("PCA territory"),3)
    return
    :*B0:Mcat1::
        sendByClipboard(StringUpperFirst("MCA territories"),4)
    return
    :*B0:Acat1::
        sendByClipboard(StringUpperFirst("ACA territories"),4)
    return
    :*B0:Pcat1::
        sendByClipboard(StringUpperFirst("PCA territories"),4)
    return
    :*B0:Ter1::
        sendByClipboard(StringUpperFirst("territories"),3)
    return
    :B0:Ede::
        sendByClipboard(StringUpperFirst("edema" A_EndChar),3)
    return
    :B0:Pfc::
        sendByClipboard(StringUpperFirst("perifocal" A_EndChar),3)
    return
    :B0:Pfe::
        sendByClipboard(StringUpperFirst("perifocal edema" A_EndChar),3)
    return
    :B0:Dire::
        sendByClipboard(StringUpperFirst("diffusion restriction" A_EndChar),4)
    return
    :B0:Aln::
        sendByClipboard(StringUpperFirst("alignment" A_EndChar),3)
    return
    :B0:Rcr::
        sendByClipboard(StringUpperFirst("recurrence" A_EndChar),3)
    return
    :B0:Anu::
        sendByClipboard(StringUpperFirst("aneurysm" A_EndChar),3)
    return
    :B0:Anu1::
        sendByClipboard(StringUpperFirst("aneurysms" A_EndChar),4)
    return
    :B0:Ret::
        sendByClipboard(StringUpperFirst("retention" A_EndChar),3)
    return
    :B0:Hpt::
        sendByClipboard(StringUpperFirst("hypertrophy" A_EndChar),3)
    return
    :B0:Ptn::
        sendByClipboard(StringUpperFirst("patent" A_EndChar),3)
    return
    :B0:Emb::
        sendByClipboard(StringUpperFirst("embolism" A_EndChar),3)
    return
    :B0:Teb::
        sendByClipboard(StringUpperFirst("thromboembolism" A_EndChar),3)
    return
    :B0:Ar::
        sendByClipboard(StringUpperFirst("artery" A_EndChar),2)
    return
    :*B0:Ar1::
        sendByClipboard(StringUpperFirst("arteries"),2)
    return
    :B0:Obl::
        sendByClipboard(StringUpperFirst("obliterated" A_EndChar),3)
    return
    :*B0:Obl1::
        sendByClipboard(StringUpperFirst("obliteration"),3)
    return
    :B0:Obc::
        sendByClipboard(StringUpperFirst("obscured" A_EndChar),3)
    return
    :B0:Lao::
        sendByClipboard(StringUpperFirst("the largest one measured" A_EndChar),3)
    return
    :B0:Ldi::
        sendByClipboard(StringUpperFirst("in largest dimension" A_EndChar),3)
    return
    :B0:Ut::
        sendByClipboard(StringUpperFirst("up to" A_EndChar),2)
    return
    :B0:Mulv::
        sendByClipboard(StringUpperFirst("multiple varied-size" A_EndChar),4)
    return
    :B0:Ef::
        sendByClipboard(StringUpperFirst("effusion" A_EndChar),2)
    return
    :B0:Flu::
        sendByClipboard(StringUpperFirst("fluid" A_EndChar),3)
    return
    :B0:Msa::
        sendByClipboard(StringUpperFirst("magnetic susceptibility artifacts" A_EndChar),3)
    return
    :B0:Bha::
        sendByClipboard(StringUpperFirst("beam-hardening artifacts" A_EndChar),3)
    return
    :B0:Bha0::
        sendByClipboard(StringUpperFirst("There is beam-hardening artifacts and obscuration of adjacent structure." A_EndChar),4)
    return
    :B0:Fca::
        sendByClipboard(StringUpperFirst("fibrotic change" A_EndChar),3)
    return
    :B0:Fcl::
        sendByClipboard(StringUpperFirst("fibrocalcified lesions" A_EndChar),3)
    return
    :B0:Fnl::
        sendByClipboard(StringUpperFirst("fibronodular lesions" A_EndChar),3)
    return
    :B0:Nat::
        sendByClipboard(StringUpperFirst("nature to be determined" A_EndChar),3)
    return
    :B0:Nt::
        sendByClipboard(StringUpperFirst("with indeterminate nature" A_EndChar),2)
    return
    :B0:Moa::
        sendByClipboard(StringUpperFirst("motion artifacts" A_EndChar),3)
    return
    :*B0:Moa0::
        sendByClipboard(StringUpperFirst("motion artifacts are noted, which may obscure small lesions."),3)
    return
    :B0:Les::
        sendByClipboard(StringUpperFirst("lesion" A_EndChar),3)
    return
    :*B0:Les1::
        sendByClipboard(StringUpperFirst("lesions"),3)
    return
    :B0:Abs::
        sendByClipboard(StringUpperFirst("abscess" A_EndChar),3)
    return
    :*B0:Abs1::
        sendByClipboard(StringUpperFirst("abscesses"),3)
    return
    :B0:Lap::
        sendByClipboard(StringUpperFirst("lymphadenopathy" A_EndChar),3)
    return
    :*B0:Lap1::
        sendByClipboard(StringUpperFirst("lymphadenopathies"),3)
    return
    :B0:Opc::
        sendByClipboard(StringUpperFirst("post-operative change" A_EndChar),3)
    return
    :*B0:Opc1::
        sendByClipboard(StringUpperFirst("post-operative changes"),3)
    return
    :B0:Cal::
        sendByClipboard(StringUpperFirst("calcified" A_EndChar),3)
    return
    :B0:Ca1::
        sendByClipboard(StringUpperFirst("calcifications" A_EndChar),3)
    return
    :B0:Ath::
        sendByClipboard(StringUpperFirst("atherosclerotic change" A_EndChar),3)
    return
    :*B0:Ath1::
        sendByClipboard(StringUpperFirst("atherosclerotic changes"),3)
    return
    :B0:Caca::
        sendByClipboard(StringUpperFirst("Calcified atherosclerotic plaques in the coronary arteries." A_EndChar),4)
    return
    :B0:Atc::
        sendByClipboard(StringUpperFirst("atherosclerotic calcification" A_EndChar),3)
    return
    :B0:Atca::
        sendByClipboard(StringUpperFirst("atherosclerotic calcification of the aorta." A_EndChar),4)
    return
    :*B0:Atcac::
        sendByClipboard(StringUpperFirst("atherosclerotic calcification of the aorta and coronary arteries."),4)
    return
    :*B0:Atccc::
        sendByClipboard(StringUpperFirst("calcification of the aorta, coronary arteries and cardiac valve."),4)
    return
    :B0:Gca::
        sendByClipboard(StringUpperFirst("cardiomegaly. atherosclerotic calcification of the aorta." A_EndChar),3)
    return
    :*B0:Mgca::
        sendByClipboard(StringUpperFirst("mild cardiomegaly. atherosclerotic calcification of the aorta."),3)
    return
    :*B0:Gcac::
        sendByClipboard(StringUpperFirst("cardiomegaly. atherosclerotic calcification of the aorta and coronary arteries."),3)
    return
    :B0:Gcc::
        sendByClipboard(StringUpperFirst("cardiomegaly. atherosclerotic calcification of the aorta and coronary arteries." A_EndChar),3)
    return
    :*B0:Mgcc::
        sendByClipboard(StringUpperFirst("mild cardiomegaly. atherosclerotic calcification of the aorta and coronary arteries."),3)
    return
    :*B0:Gccc::
        sendByClipboard(StringUpperFirst("cardiomegaly. calcification of the aorta, coronary arteries and cardiac valve."),3)
    return
    :*B0:Mgccc::
        sendByClipboard(StringUpperFirst("mild cardiomegaly. calcification of the aorta, coronary arteries and cardiac valve."),4)
    return
    :B0:Met::
        sendByClipboard(StringUpperFirst("metastasis" A_EndChar),3)
    return
    :*B0:Met1::
        sendByClipboard(StringUpperFirst("metastases"),3)
    return
    :B0:Mets::
        sendByClipboard(StringUpperFirst("metastatic lesions" A_EndChar),4)
    return
    :*B0:Met2::
        sendByClipboard(StringUpperFirst("metastatic"),3)
    return
    :B0:Fas::
        sendByClipboard(StringUpperFirst("fat stranding" A_EndChar),3)
    return
    :B0:Adj::
        sendByClipboard(StringUpperFirst("adjacent" A_EndChar),3)
    return
    :B0:Sts::
        sendByClipboard(StringUpperFirst("soft tissue swelling" A_EndChar),3)
    return
    :*B0:Lb1::
        sendByClipboard(StringUpperFirst("lobes"),2)
    return
    :*B0:Lb2::
        sendByClipboard(StringUpperFirst("lobar"),2)
    return
    :B0:Ste::
        sendByClipboard(StringUpperFirst("stenosis" A_EndChar),3)
    return
    :B0:Ocl::
        sendByClipboard(StringUpperFirst("occlusion" A_EndChar),3)
    return
    :*B0:Stoc::
        sendByClipboard(StringUpperFirst("steno-occlusion"),3)
    return
    :B0:Gl::
        sendByClipboard(StringUpperFirst("gland" A_EndChar),2)
    return
    :*B0:Gl1::
        sendByClipboard(StringUpperFirst("glands"),2)
    return
    :B0:Arti::
        sendByClipboard(StringUpperFirst("artifacts" A_EndChar),4)
    return
    :B0:Ln::
        sendByClipboard(StringUpperFirst("lymph node" A_EndChar),2)
    return
    :*B0:Ln1::
        sendByClipboard(StringUpperFirst("lymph nodes"),2)
    return
    :*B0:Mth-::
        sendByClipboard(StringUpperFirst("黏膜增厚"),3)
    return
    :B0:Mth::
        sendByClipboard(StringUpperFirst("mucosal thickening" A_EndChar),3)
    return
    :B0:Wth::
        sendByClipboard(StringUpperFirst("wall thickening" A_EndChar),3)
    return
    :B0:Thi::
        sendByClipboard(StringUpperFirst("thickening" A_EndChar),3)
    return
    :B0:Irn::
        sendByClipboard(StringUpperFirst("irregular narrowing" A_EndChar),3)
    return
    :B0:Irr::
        sendByClipboard(StringUpperFirst("irregular" A_EndChar),3)
    return
    :*B0:Irr1::
        sendByClipboard(StringUpperFirst("irregularity"),3)
    return
    :B0:Le::
        sendByClipboard(StringUpperFirst("level" A_EndChar),2)
    return
    :*B0:Le1::
        sendByClipboard(StringUpperFirst("levels"),2)
    return
    :B0:Hem::
        sendByClipboard(StringUpperFirst("hemorrhage" A_EndChar),3)
    return
    :B0:Nar::
        sendByClipboard(StringUpperFirst("narrowing" A_EndChar),3)
    return
    :B0:Obs::
        sendByClipboard(StringUpperFirst("obstruction" A_EndChar),3)
    return
    :*B0:Obs1::
        sendByClipboard(StringUpperFirst("obstructive"),3)
    return
    :B0:Lig::
        sendByClipboard(StringUpperFirst("ligament" A_EndChar),3)
    return
    :*B0:Lig1::
        sendByClipboard(StringUpperFirst("ligaments"),3)
    return
    :B0:Tdn::
        sendByClipboard(StringUpperFirst("tendon" A_EndChar),3)
    return
    :*B0:Tdn1::
        sendByClipboard(StringUpperFirst("tendons"),3)
    return
    :B0:Ma::
        sendByClipboard(StringUpperFirst("mass" A_EndChar),2)
    return
    :B0:Mle::
        sendByClipboard(StringUpperFirst("mass lesion" A_EndChar),3)
    return
    :*B0:Ma1::
        sendByClipboard(StringUpperFirst("masses"),2)
    return
    :B0:Tu::
        sendByClipboard(StringUpperFirst("tumor" A_EndChar),2)
    return
    :*B0:Tu1::
        sendByClipboard(StringUpperFirst("tumors"),2)
    return
    :B0:Tu2::
        sendByClipboard(StringUpperFirst("tumoral" A_EndChar),3)
    return
    :*B0:Nd-::
        sendByClipboard(StringUpperFirst("結節"),2)
    return
    :B0:Nd::
        sendByClipboard(StringUpperFirst("nodule" A_EndChar),2)
    return
    :*B0:Nd1::
        sendByClipboard(StringUpperFirst("nodules"),2)
    return
    :*B0:Nd2::
        sendByClipboard(StringUpperFirst("nodular"),2)
    return
    :*B0:Nod1::
        sendByClipboard(StringUpperFirst("nodularities"),3)
    return
    :B0:Nos::
        sendByClipboard(StringUpperFirst("non-specific" A_EndChar),3)
    return
    :*B0:Pbns::
        sendByClipboard(StringUpperFirst("probably non-specific"),3)
    return
    :B0:Plc::
        sendByClipboard(StringUpperFirst("placement of" A_EndChar),3)
    return
    :B0:Ett::
        sendByClipboard(StringUpperFirst("an endotracheal tube" A_EndChar),3)
    return
    :B0:Dlc::
        sendByClipboard(StringUpperFirst("a double-lumen catheter" A_EndChar),3)
    return
    :B0:Rcvc::
        sendByClipboard(StringUpperFirst("a right central venous catheter" A_EndChar),4)
    return
    :B0:Lcvc::
        sendByClipboard(StringUpperFirst("a left central venous catheter" A_EndChar),4)
    return
    :B0:Rpor::
        sendByClipboard(StringUpperFirst("a right implantable venous access port" A_EndChar),4)
    return
    :B0:Lpor::
        sendByClipboard(StringUpperFirst("a left implantable venous access port" A_EndChar),4)
    return
    :B0:Ppo::
        sendByClipboard(StringUpperFirst("placement of implantable venous access port." A_EndChar),3)
    return
    :B0:Ngt::
        sendByClipboard(StringUpperFirst("a nasoenteric tube" A_EndChar),3)
    return
    :B0:Pdt::
        sendByClipboard(StringUpperFirst("a peritoneal dialysis tube" A_EndChar),3)
    return
    :B0:Fol::
        sendByClipboard(StringUpperFirst("a Foley catheter" A_EndChar),3)
    return
    :B0:Cath::
        sendByClipboard(StringUpperFirst("catheter" A_EndChar),4)
    return
    :B0:Pig::
        sendByClipboard(StringUpperFirst("pigtail" A_EndChar),3)
    return
    :*B0:Pig1::
        sendByClipboard(StringUpperFirst("pigtails"),3)
    return
    :B0:Enl::
        sendByClipboard(StringUpperFirst("enlarged" A_EndChar),3)
    return
    :*B0:Enl1::
        sendByClipboard(StringUpperFirst("enlargement"),3)
    return
    :B0:Thm::
        sendByClipboard(StringUpperFirst("thrombosis" A_EndChar),3)
    return
    :*B0:Thm1::
        sendByClipboard(StringUpperFirst("thrombosed"),3)
    return
    :B0:Ptr::
        sendByClipboard(StringUpperFirst("partially thrombosed" A_EndChar),3)
    return
    :B0:Thr::
        sendByClipboard(StringUpperFirst("thrombus" A_EndChar),3)
    return
    :B0:Tmy::
        sendByClipboard(StringUpperFirst("thrombectomy" A_EndChar),3)
    return
    :*B0:Thr1::
        sendByClipboard(StringUpperFirst("thrombi"),3)
    return
    :B0:Atr::
        sendByClipboard(StringUpperFirst("atrophy" A_EndChar),3)
    return
    :B0:Atrc::
        sendByClipboard(StringUpperFirst("atrophic change" A_EndChar),4)
    return
    :*B0:Atrc1::
        sendByClipboard(StringUpperFirst("atrophic changes"),4)
    return
    :B0:Atk::
        sendByClipboard(StringUpperFirst("atrophic change of bilateral kidneys." A_EndChar),3)
    return
    :*B0:Atrk::
        sendByClipboard(StringUpperFirst("atrophic change of the right kidney."),3)
    return
    :*B0:Atlk::
        sendByClipboard(StringUpperFirst("atrophic change of the left kidney."),3)
    return
    :B0:Ddx::
        sendByClipboard(StringUpperFirst("differential diagnosis including" A_EndChar),3)
    return
    :B0:Cist::
        sendByClipboard(StringUpperFirst("cistern" A_EndChar),4)
    return
    :*B0:Cist1::
        sendByClipboard(StringUpperFirst("cisterns"),4)
    return
    :B0:Corr::
        sendByClipboard(StringUpperFirst("corona radiata" A_EndChar),4)
    return
    :*B0:Obsf::
        sendByClipboard(StringUpperFirst("obliterated sulci and fissures"),3)
    return
    :*B0:Idem::
        sendByClipboard(StringUpperFirst("intradural extramedullary"),3)
    return
    :B0:Imd::
        sendByClipboard(StringUpperFirst("intramedullary" A_EndChar),3)
    return
    :B0:Idl::
        sendByClipboard(StringUpperFirst("intradural" A_EndChar),3)
    return
    :B0:Xdl::
        sendByClipboard(StringUpperFirst("extradural" A_EndChar),3)
    return
    :B0:Swi::
        sendByClipboard(StringUpperFirst("SWI shows" A_EndChar),3)
    return
    :*B0:Swi1::
        sendByClipboard(StringUpperFirst("SWI shows some micorbleeds"),3)
    return
    :B0:Mcb::
        sendByClipboard(StringUpperFirst("microbleed" A_EndChar),3)
    return
    :*B0:Mcb1::
        sendByClipboard(StringUpperFirst("microbleeds"),3)
    return
    :*B0:Cffx::
        sendByClipboard(StringUpperFirst("craniofacial fracture"),3)
    return
    :*B0:Desh::
        sendByClipboard(StringUpperFirst("disproportionately enlarged subarachnoid space hydrocephalus"),3)
    return
    :*B0:Prfc::
        sendByClipboard(StringUpperFirst("parafalcine"),3)
    return
    :B0:Otk::
        sendByClipboard(StringUpperFirst("optic chiasm" A_EndChar),3)
    return
    :*B0:Sptn::
        sendByClipboard(StringUpperFirst("supratentorial"),3)
    return
    :*B0:Iftn::
        sendByClipboard(StringUpperFirst("infratentorial"),3)
    return
    :*B0:Stcp::
        sendByClipboard(StringUpperFirst("striatocapsular region"),3)
    return
    :B0:Brl::
        sendByClipboard(StringUpperFirst("brain atrophy, leukoaraiosis." A_EndChar),3)
    return
    :B0:Mba::
        sendByClipboard(StringUpperFirst("mild brain atrophy" A_EndChar),3)
    return
    :*B0:Brli::
        sendByClipboard(StringUpperFirst("brain atrophy, leukoaraiosis, old insult(s)."),3)
    return
    :*B0:Brlo::
        sendByClipboard(StringUpperFirst("brain atrophy, leukoaraiosis, old lacune(s)."),3)
    return
    :B0:Cnp::
        sendByClipboard(StringUpperFirst("clinoid process" A_EndChar),3)
    return
    :*B0:Cnp1::
        sendByClipboard(StringUpperFirst("clinoid processes"),3)
    return
    :B0:Ppb::
        sendByClipboard(StringUpperFirst("preserved posterior pituitary bright T1 signal." A_EndChar),3)
    return
    :B0:Cbp::
        sendByClipboard(StringUpperFirst("cerebellar peduncle" A_EndChar),3)
    return
    :*B0:Cbp1::
        sendByClipboard(StringUpperFirst("cerebellar peduncles"),3)
    return
    :B0:Mgt::
        sendByClipboard(StringUpperFirst("meningitis" A_EndChar),3)
    return
    :B0:Ina::
        sendByClipboard(StringUpperFirst("intracranial arteries" A_EndChar),3)
    return
    :*B0:Dssa::
        sendByClipboard(StringUpperFirst("dissecting aneurysm"),3)
    return
    :B0:Dth::
        sendByClipboard(StringUpperFirst("dural thickening" A_EndChar),3)
    return
    :B0:Fcr::
        sendByClipboard(StringUpperFirst("falx cerebri" A_EndChar),3)
    return
    :B0:Ten::
        sendByClipboard(StringUpperFirst("tentorium" A_EndChar),3)
    return
    :*B0:Ten1::
        sendByClipboard(StringUpperFirst("tentorial"),3)
    return
    :B0:Ftn::
        sendByClipboard(StringUpperFirst("falcotentorial" A_EndChar),3)
    return
    :B0:Slw::
        sendByClipboard(StringUpperFirst("sphenoid lesser wing" A_EndChar),3)
    return
    :B0:Sgw::
        sendByClipboard(StringUpperFirst("sphenoid greater wing" A_EndChar),3)
    return
    :B0:Srd::
        sendByClipboard(StringUpperFirst("sphenoid ridge" A_EndChar),3)
    return
    :*B0:Plsf::
        sendByClipboard(StringUpperFirst("planum sphenoidale"),3)
    return
    :*B0:Etym::
        sendByClipboard(StringUpperFirst("epitympanum"),3)
    return
    :*B0:Mtym::
        sendByClipboard(StringUpperFirst("mesotympanum"),3)
    return
    :*B0:Htym::
        sendByClipboard(StringUpperFirst("hypotympanum"),3)
    return
    :B0:Cah::
        sendByClipboard(StringUpperFirst("caudate head" A_EndChar),3)
    return
    :B0:Gp::
        sendByClipboard(StringUpperFirst("globus pallidus" A_EndChar),2)
    return
    :*B0:Gp1::
        sendByClipboard(StringUpperFirst("globus pallidi"),2)
    return
    :B0:Lgp::
        sendByClipboard(StringUpperFirst("left globus pallidus" A_EndChar),3)
    return
    :B0:Rgp::
        sendByClipboard(StringUpperFirst("right globus pallidus" A_EndChar),3)
    return
    :B0:Bgp::
        sendByClipboard(StringUpperFirst("bilateral globus pallidi" A_EndChar),3)
    return
    :B0:Ptm::
        sendByClipboard(StringUpperFirst("putamen" A_EndChar),3)
    return
    :*B0:Ptm1::
        sendByClipboard(StringUpperFirst("putamina"),3)
    return
    :B0:Isl::
        sendByClipboard(StringUpperFirst("insula" A_EndChar),3)
    return
    :*B0:Isl1::
        sendByClipboard(StringUpperFirst("insular"),3)
    return
    :cB0:Orn::
        sendByClipboard(StringUpperFirst("osteoradionecrosis" A_EndChar),3)
    return
    :B0:Bnm::
        sendByClipboard(StringUpperFirst("brain metastases" A_EndChar),3)
    return
    :B0:Ach::
        sendByClipboard(StringUpperFirst("arachnoid" A_EndChar),3)
    return
    :B0:Acha::
        sendByClipboard(StringUpperFirst("anterior choroidal artery" A_EndChar),4)
    return
    :B0:Pcha::
        sendByClipboard(StringUpperFirst("posterior choroidal artery" A_EndChar),4)
    return
    :B0:Dmy::
        sendByClipboard(StringUpperFirst("demyelinating" A_EndChar),3)
    return
    :B0:Tea::
        sendByClipboard(StringUpperFirst("transependymal absorption" A_EndChar),3)
    return
    :B0:Psp::
        sendByClipboard(StringUpperFirst("paraspinal" A_EndChar),3)
    return
    :B0:Pnc::
        sendByClipboard(StringUpperFirst("pneumocephalus" A_EndChar),3)
    return
    :B0:Eib::
        sendByClipboard(StringUpperFirst("EC-IC bypass" A_EndChar),3)
    return
    :B0:Hmv::
        sendByClipboard(StringUpperFirst("hematoventricle" A_EndChar),3)
    return
    :B0:Cbn::
        sendByClipboard(StringUpperFirst("cyberknife" A_EndChar),3)
    return
    :B0:Pmj::
        sendByClipboard(StringUpperFirst("ponto-medullary junction" A_EndChar),3)
    return
    :B0:Brm::
        sendByClipboard(StringUpperFirst("brainstem" A_EndChar),3)
    return
    :B0:Mdo::
        sendByClipboard(StringUpperFirst("medulla oblongata" A_EndChar),3)
    return
    :*B0:Sel0::
        sendByClipboard(StringUpperFirst("MRI of the sella without/with contrast enhancement shows:`r`n-"),3)
    return
    :B0:Rbg::
        sendByClipboard(StringUpperFirst("right basal ganglion" A_EndChar),3)
    return
    :B0:Lbg::
        sendByClipboard(StringUpperFirst("left basal ganglion" A_EndChar),3)
    return
    :B0:Bbg::
        sendByClipboard(StringUpperFirst("bilateral basal ganglia" A_EndChar),3)
    return
    :B0:Rth::
        sendByClipboard(StringUpperFirst("right thalamus" A_EndChar),3)
    return
    :B0:Lth::
        sendByClipboard(StringUpperFirst("left thalamus" A_EndChar),3)
    return
    :B0:Bth::
        sendByClipboard(StringUpperFirst("bilateral thalami" A_EndChar),3)
    return
    :B0:Rfl::
        sendByClipboard(StringUpperFirst("right frontal lobe" A_EndChar),3)
    return
    :B0:Lfl::
        sendByClipboard(StringUpperFirst("left frontal lobe" A_EndChar),3)
    return
    :B0:Bfl::
        sendByClipboard(StringUpperFirst("bilateral frontal lobes" A_EndChar),3)
    return
    :B0:Rpl::
        sendByClipboard(StringUpperFirst("right parietal lobe" A_EndChar),3)
    return
    :B0:Lpl::
        sendByClipboard(StringUpperFirst("left parietal lobe" A_EndChar),3)
    return
    :B0:Bpl::
        sendByClipboard(StringUpperFirst("bilateral parietal lobes" A_EndChar),3)
    return
    :B0:Rol::
        sendByClipboard(StringUpperFirst("right occipital lobe" A_EndChar),3)
    return
    :B0:Lol::
        sendByClipboard(StringUpperFirst("left occipital lobe" A_EndChar),3)
    return
    :B0:Bol::
        sendByClipboard(StringUpperFirst("bilateral occipital lobes" A_EndChar),3)
    return
    :B0:Rtl::
        sendByClipboard(StringUpperFirst("right temporal lobe" A_EndChar),3)
    return
    :B0:Ltl::
        sendByClipboard(StringUpperFirst("left temporal lobe" A_EndChar),3)
    return
    :B0:Btl::
        sendByClipboard(StringUpperFirst("bilateral temporal lobes" A_EndChar),3)
    return
    :B0:Dub::
        sendByClipboard(StringUpperFirst("dural-based" A_EndChar),3)
    return
    :B0:Acf::
        sendByClipboard(StringUpperFirst("anterior cranial fossa" A_EndChar),3)
    return
    :B0:Mcf::
        sendByClipboard(StringUpperFirst("middle cranial fossa" A_EndChar),3)
    return
    :B0:Pcf::
        sendByClipboard(StringUpperFirst("posterior cranial fossa" A_EndChar),3)
    return
    :B0:Iac::
        sendByClipboard(StringUpperFirst("internal auditory canal" A_EndChar),3)
    return
    :B0:Eac::
        sendByClipboard(StringUpperFirst("external auditory canal" A_EndChar),3)
    return
    :B0:Cmc::
        sendByClipboard(StringUpperFirst("chronic mastoiditis change" A_EndChar),3)
    return
    :B0:Vmg::
        sendByClipboard(StringUpperFirst("ventriculomegaly" A_EndChar),3)
    return
    :B0:Sbd::
        sendByClipboard(StringUpperFirst("subdural" A_EndChar),3)
    return
    :B0:Epd::
        sendByClipboard(StringUpperFirst("epidural" A_EndChar),3)
    return
    :B0:Htr::
        sendByClipboard(StringUpperFirst("hemorrhagic transformation" A_EndChar),3)
    return
    :*B0:Bo0::
        sendByClipboard(StringUpperFirst("no definite intracranial organic lesion."),2)
    return
    :B0:Pvs::
        sendByClipboard(StringUpperFirst("perivascular spaces" A_EndChar),3)
    return
    :B0:Skh::
        sendByClipboard(StringUpperFirst("scalp hematoma" A_EndChar),3)
    return
    :B0:Skp::
        sendByClipboard(StringUpperFirst("scalp" A_EndChar),3)
    return
    :B0:Cx::
        sendByClipboard(StringUpperFirst("cortex" A_EndChar),2)
    return
    :*B0:Cx1::
        sendByClipboard(StringUpperFirst("cortical"),2)
    return
    :B0:Scx::
        sendByClipboard(StringUpperFirst("subcortical" A_EndChar),3)
    return
    :B0:Scw::
        sendByClipboard(StringUpperFirst("subcortical" A_EndChar),3)
    return
    :B0:Gy::
        sendByClipboard(StringUpperFirst("gyrus" A_EndChar),2)
    return
    :*B0:Gy1::
        sendByClipboard(StringUpperFirst("gyri"),2)
    return
    :B0:Ssr::
        sendByClipboard(StringUpperFirst("suprasellar" A_EndChar),3)
    return
    :B0:Isr::
        sendByClipboard(StringUpperFirst("infrasellar" A_EndChar),3)
    return
    :B0:Psr::
        sendByClipboard(StringUpperFirst("parasellar" A_EndChar),3)
    return
    :*B0:Sslr::
        sendByClipboard(StringUpperFirst("sellar-suprasellar"),3)
    return
    :B0:Esa::
        sendByClipboard(StringUpperFirst("empty sella" A_EndChar),3)
    return
    :B0:Lesa::
        sendByClipboard(StringUpperFirst("enlarged and empty sella" A_EndChar),4)
    return
    :*B0:Sku0::
        sendByClipboard(StringUpperFirst("no definite abnormal focal bony change. The sella is intact. No definite change in the vascular groove and the sutures."),3)
    return
    :B0:Hpp::
        sendByClipboard(StringUpperFirst("hippocampus" A_EndChar),3)
    return
    :B0:Clnc::
        sendByClipboard(StringUpperFirst("cortical laminar necrosis" A_EndChar),4)
    return
    :B0:Rof::
        sendByClipboard(StringUpperFirst("foramen rotundum" A_EndChar),3)
    return
    :B0:Ovf::
        sendByClipboard(StringUpperFirst("foramen ovale" A_EndChar),3)
    return
    :B0:Juf::
        sendByClipboard(StringUpperFirst("jugular foramen" A_EndChar),3)
    return
    :B0:Hyc::
        sendByClipboard(StringUpperFirst("hypoglossal canal" A_EndChar),3)
    return
    :B0:Cvs::
        sendByClipboard(StringUpperFirst("cavernous sinus" A_EndChar),3)
    return
    :B0:Cvn::
        sendByClipboard(StringUpperFirst("cavernous" A_EndChar),3)
    return
    :B0:Mvm::
        sendByClipboard(StringUpperFirst("medullary venous malformation" A_EndChar),3)
    return
    :B0:Dbs0::
        sendByClipboard(StringUpperFirst("status post bilateral deep brain stimulator wire insertion." A_EndChar),4)
    return
    :*B0:Dbs00::
        sendByClipboard(StringUpperFirst("placement of deep brain stimulator at bilateral subthalamic nuclei from bilateral frontal regions, which causing artifacts on images."),4)
    return
    :B0:Skl::
        sendByClipboard(StringUpperFirst("skull" A_EndChar),3)
    return
    :B0:Mtd::
        sendByClipboard(StringUpperFirst("mastoid" A_EndChar),3)
    return
    :B0:Moya::
        sendByClipboard(StringUpperFirst("reaching brain surface with regional neovasculature" A_EndChar),4)
    return
    :B0:Csi::
        sendByClipboard(StringUpperFirst("centrum semiovale" A_EndChar),3)
    return
    :B0:B0::
        sendByClipboard(StringUpperFirst("no definite acute intracranial hemorrhage." A_EndChar),2)
    return
    :B0:Vps::
        sendByClipboard(StringUpperFirst("ventriculo-peritoneal shunt" A_EndChar),3)
    return
    :B0:Lai::
        sendByClipboard(StringUpperFirst("lacunar infarcts" A_EndChar),3)
    return
    :B0:Cvsp::
        sendByClipboard(StringUpperFirst("cavum septum pellucidum" A_EndChar),4)
    return
    :B0:Cvvi::
        sendByClipboard(StringUpperFirst("cavum velum interpositum" A_EndChar),4)
    return
    :*B0:Orb=::
        sendByClipboard(StringUpperFirst("CT of the orbits without contrast enhancement shows:`r`n-"),3)
    return
    :*B0:Tem=::
        sendByClipboard(StringUpperFirst("HRCT of the temporal bones without contrast enhancement shows:`r`n-"),3)
    return
    :*B0:Sin=::
        sendByClipboard(StringUpperFirst("CT of the paranasal sinuses without contrast enhancement shows:`r`n-"),3)
    return
    :*B0:Sel=::
        sendByClipboard(StringUpperFirst("MRI of the sella without/with contrast enhancement shows:`r`n-"),3)
    return
    :B0:Mng::
        sendByClipboard(StringUpperFirst("meningioma" A_EndChar),3)
    return
    :*B0:Mng1::
        sendByClipboard(StringUpperFirst("meningiomas"),3)
    return
    :*B0:Evdd::
        sendByClipboard(StringUpperFirst("extra-ventricular drainage"),3)
    return
    :*B0:Incp::
        sendByClipboard(StringUpperFirst("internal capsule"),3)
    return
    :*B0:Excp::
        sendByClipboard(StringUpperFirst("external capsule"),3)
    return
    :B0:Ifd::
        sendByClipboard(StringUpperFirst("infundibulum" A_EndChar),3)
    return
    :B0:Coc::
        sendByClipboard(StringUpperFirst("corpus callosum" A_EndChar),3)
    return
    :B0:Lpm::
        sendByClipboard(StringUpperFirst("leptomeningeal" A_EndChar),3)
    return
    :B0:Lmcc::
        sendByClipboard(StringUpperFirst("leptomeningeal carcinomatosis" A_EndChar),4)
    return
    :B0:Cpa::
        sendByClipboard(StringUpperFirst("cerebellopontine angle" A_EndChar),3)
    return
    :B0:Cis::
        sendByClipboard(StringUpperFirst("3D T2WI CISS shows" A_EndChar),3)
    return
    :*B0:Csr0::
        sendByClipboard(StringUpperFirst("possible contact of right AICA loop with right facial nerve root exit zone."),3)
    return
    :*B0:Csl0::
        sendByClipboard(StringUpperFirst("possible contact of left AICA loop with left facial nerve root exit zone."),3)
    return
    :*B0:Csr1::
        sendByClipboard(StringUpperFirst("contact of right AICA loop with right facial nerve root exit zone."),3)
    return
    :*B0:Csl1::
        sendByClipboard(StringUpperFirst("contact of left AICA loop with left facial nerve root exit zone."),3)
    return
    :B0:Hdc::
        sendByClipboard(StringUpperFirst("hydrocephalus" A_EndChar),3)
    return
    :B0:Iax::
        sendByClipboard(StringUpperFirst("intra-axial" A_EndChar),3)
    return
    :B0:Xax::
        sendByClipboard(StringUpperFirst("extra-axial" A_EndChar),3)
    return
    :B0:Cvx::
        sendByClipboard(StringUpperFirst("convexity" A_EndChar),3)
    return
    :*B0:Cvx1::
        sendByClipboard(StringUpperFirst("convexities"),3)
    return
    :B0:Sin::
        sendByClipboard(StringUpperFirst("sinus" A_EndChar),3)
    return
    :*B0:Sin1::
        sendByClipboard(StringUpperFirst("sinuses"),3)
    return
    :*B0:Sela0::
        sendByClipboard(StringUpperFirst("normal size of sellar fossa."),4)
    return
    :*B0:Sten0::
        sendByClipboard(StringUpperFirst("Stenver's view showed normal size of bilateral internal auditory canals."),4)
    return
    :*B0:Mast0::
        sendByClipboard(StringUpperFirst("Well pneumatization of bilateral mastoid bone."),4)
    return
    :*B0:Bm/::
        sendByClipboard(StringUpperFirst("bilateral mastoid effusion."),2)
    return
    :*B0:Rm/::
        sendByClipboard(StringUpperFirst("right mastoid effusion."),2)
    return
    :*B0:Lm/::
        sendByClipboard(StringUpperFirst("left mastoid effusion."),2)
    return
    :B0:Mos::
        sendByClipboard(StringUpperFirst("mastoiditis" A_EndChar),3)
    return
    :*B0:C2c::
        sendByClipboard(StringUpperFirst("cervicocranial arteries"),2)
    return
    :B0:Cro::
        sendByClipboard(StringUpperFirst("craniotomy" A_EndChar),3)
    return
    :B0:Cre::
        sendByClipboard(StringUpperFirst("craniectomy" A_EndChar),3)
    return
    :B0:Bur::
        sendByClipboard(StringUpperFirst("burr hole" A_EndChar),3)
    return
    :*B0:Bur1::
        sendByClipboard(StringUpperFirst("burr holes"),3)
    return
    :B0:Pal::
        sendByClipboard(StringUpperFirst("parenchyma loss" A_EndChar),3)
    return
    :*B0:Pit0::
        sendByClipboard(StringUpperFirst("No evidence of pituitary tumor.`r`n- No deviation of pituitary stalk.`r`n- The posterior pituitary bright SI is preserved.`r`n- The optic chiasm is not displaced."),3)
    return
    :*B0:Pit1::
        sendByClipboard(StringUpperFirst("preserved physiologic high signal intensity on T1WI at the posterior pituitary gland"),3)
    return
    :B0:Hump::
        sendByClipboard(StringUpperFirst("humping of the diaphragma sella, compatible with peripubertal changes" A_EndChar),4)
    return
    :*B0:Orb0::
        sendByClipboard(StringUpperFirst("There is no definite abnormality nor enhancement of bilateral globes, periseptal soft tissue, optic nerves and complex, extraorcular muscles and the bony orbit."),3)
    return
    :*B0:Or0::
        sendByClipboard(StringUpperFirst("intact orbits."),2)
    return
    :B0:Pit::
        sendByClipboard(StringUpperFirst("pituitary" A_EndChar),3)
    return
    :B0:Ptg::
        sendByClipboard(StringUpperFirst("pituitary gland" A_EndChar),3)
    return
    :B0:Cb::
        sendByClipboard(StringUpperFirst("cerebrum" A_EndChar),2)
    return
    :*B0:Cb1::
        sendByClipboard(StringUpperFirst("cerebral"),2)
    return
    :B0:Crb::
        sendByClipboard(StringUpperFirst("cerebellum" A_EndChar),3)
    return
    :*B0:Crb1::
        sendByClipboard(StringUpperFirst("cerebellar"),3)
    return
    :B0:Gm::
        sendByClipboard(StringUpperFirst("gray matter" A_EndChar),2)
    return
    :B0:Gwj::
        sendByClipboard(StringUpperFirst("gray-white matter junction" A_EndChar),3)
    return
    :*B0:Pvwm::
        sendByClipboard(StringUpperFirst("periventricular white matter"),3)
    return
    :*B0:Pwvm::
        sendByClipboard(StringUpperFirst("periventricular white matter"),3)
    return
    :B0:Pvw::
        sendByClipboard(StringUpperFirst("periventricular" A_EndChar),3)
    return
    :*B0:Leu-::
        sendByClipboard(StringUpperFirst("非特異性腦白質變化"),3)
    return
    :B0:Leu::
        sendByClipboard(StringUpperFirst("leukoaraiosis" A_EndChar),3)
    return
    :B0:Lue::
        sendByClipboard(StringUpperFirst("leukoaraiosis" A_EndChar),3)
    return
    :B0:Bra::
        sendByClipboard(StringUpperFirst("brain atrophy" A_EndChar),3)
    return
    :B0:Epm::
        sendByClipboard(StringUpperFirst("encephalomalacia" A_EndChar),3)
    return
    :B0:Mas::
        sendByClipboard(StringUpperFirst("mastoid air cells" A_EndChar),3)
    return
    :B0:Oi::
        sendByClipboard(StringUpperFirst("old insult" A_EndChar),2)
    return
    :*B0:Oi1::
        sendByClipboard(StringUpperFirst("old insults"),2)
    return
    :B0:Rif::
        sendByClipboard(StringUpperFirst("recent ischemia/infarct" A_EndChar),3)
    return
    :*B0:Rif1::
        sendByClipboard(StringUpperFirst("recent infarct"),3)
    return
    :B0:Ric::
        sendByClipboard(StringUpperFirst("recent ischemic change" A_EndChar),3)
    return
    :B0:Fro::
        sendByClipboard(StringUpperFirst("frontal" A_EndChar),3)
    return
    :B0:Par::
        sendByClipboard(StringUpperFirst("parietal" A_EndChar),3)
    return
    :B0:Occ::
        sendByClipboard(StringUpperFirst("occipital" A_EndChar),3)
    return
    :B0:Tem::
        sendByClipboard(StringUpperFirst("temporal" A_EndChar),3)
    return
    :B0:Th::
        sendByClipboard(StringUpperFirst("thalamus" A_EndChar),2)
    return
    :*B0:Th1::
        sendByClipboard(StringUpperFirst("thalami"),2)
    return
    :B0:Bnc::
        sendByClipboard(StringUpperFirst("atherosclerotic calcification of cervicocranial arteries." A_EndChar),3)
    return
    :*B0:Scwm::
        sendByClipboard(StringUpperFirst("subcortical white matter"),3)
    return
    :B0:Mx::
        sendByClipboard(StringUpperFirst("maxillary" A_EndChar),2)
    return
    :B0:Bg::
        sendByClipboard(StringUpperFirst("basal ganglion" A_EndChar),2)
    return
    :*B0:Bg1::
        sendByClipboard(StringUpperFirst("basal ganglia"),2)
    return
    :B0:Intc::
        sendByClipboard(StringUpperFirst("intracranial" A_EndChar),4)
    return
    :B0:Vnt::
        sendByClipboard(StringUpperFirst("ventricle" A_EndChar),3)
    return
    :*B0:Vnt1::
        sendByClipboard(StringUpperFirst("ventricles"),3)
    return
    :*B0:Vnt2::
        sendByClipboard(StringUpperFirst("ventricular"),3)
    return
    :B0:Vnd::
        sendByClipboard(StringUpperFirst("ventricular device" A_EndChar),3)
    return
    :B0:Hemi::
        sendByClipboard(StringUpperFirst("hemisphere" A_EndChar),4)
    return
    :*B0:Hemi1::
        sendByClipboard(StringUpperFirst("hemispheres"),4)
    return
    :B0:Cbh::
        sendByClipboard(StringUpperFirst("cerebral hemisphere" A_EndChar),3)
    return
    :*B0:Cbh1::
        sendByClipboard(StringUpperFirst("cerebral hemispheres"),3)
    return
    :*B0:Cbh2::
        sendByClipboard(StringUpperFirst("cerebellar hemisphere"),3)
    return
    :*B0:Cbh3::
        sendByClipboard(StringUpperFirst("cerebellar hemispheres"),3)
    return
    :B0:Cab::
        sendByClipboard(StringUpperFirst("carotid bulb" A_EndChar),3)
    return
    :*B0:Cab1::
        sendByClipboard(StringUpperFirst("carotid bulbs"),3)
    return
    :B0:Sfn::
        sendByClipboard(StringUpperFirst("carotid siphon" A_EndChar),3)
    return
    :*B0:Sfn1::
        sendByClipboard(StringUpperFirst("carotid siphons"),3)
    return
    :*B0:Ccaa::
        sendByClipboard(StringUpperFirst("common carotid artery"),3)
    return
    :*B0:Ccaa1::
        sendByClipboard(StringUpperFirst("common carotid arteries"),4)
    return
    :*B0:Scaa::
        sendByClipboard(StringUpperFirst("subclavian artery"),3)
    return
    :*B0:Scaa1::
        sendByClipboard(StringUpperFirst("subclavian arteries"),4)
    return
    :*B0:Scvv::
        sendByClipboard(StringUpperFirst("subclavian vein"),3)
    return
    :*B0:Scvv1::
        sendByClipboard(StringUpperFirst("subclavian veins"),4)
    return
    :*B0:Icaa::
        sendByClipboard(StringUpperFirst("internal carotid artery"),3)
    return
    :*B0:Icaa1::
        sendByClipboard(StringUpperFirst("internal carotid arteries"),4)
    return
    :B0:Paic::
        sendByClipboard(StringUpperFirst("paraclinoid ICA" A_EndChar),4)
    return
    :*B0:Ecaa::
        sendByClipboard(StringUpperFirst("external carotid artery"),3)
    return
    :*B0:Ecaa1::
        sendByClipboard(StringUpperFirst("external carotid arteries"),4)
    return
    :*B0:Acma::
        sendByClipboard(StringUpperFirst("anterior communicating artery"),3)
    return
    :*B0:Acom::
        sendByClipboard(StringUpperFirst("AComA"),3)
    return
    :*B0:Pcom::
        sendByClipboard(StringUpperFirst("PComA"),3)
    return
    :*B0:Pcma::
        sendByClipboard(StringUpperFirst("posterior communicating artery"),3)
    return
    :*B0:Pcma1::
        sendByClipboard(StringUpperFirst("posterior communicating arteries"),4)
    return
    :*B0:Mcaa::
        sendByClipboard(StringUpperFirst("middle cerebral artery"),3)
    return
    :*B0:Acaa::
        sendByClipboard(StringUpperFirst("anterior cerebral artery"),3)
    return
    :*B0:Pcaa::
        sendByClipboard(StringUpperFirst("posterior cerebral artery"),3)
    return
    :*B0:Picaa::
        sendByClipboard(StringUpperFirst("posterior inferior cerebellar artery"),4)
    return
    :*B0:Aicaa::
        sendByClipboard(StringUpperFirst("anterior inferior cerebellar artery"),4)
    return
    :*B0:Vaa::
        sendByClipboard(StringUpperFirst("vertebral artery"),2)
    return
    :*B0:Vaa1::
        sendByClipboard(StringUpperFirst("vertebral arteries"),3)
    return
    :*B0:Baa::
        sendByClipboard(StringUpperFirst("basilar artery"),2)
    return
    :*B0:Vbaa::
        sendByClipboard(StringUpperFirst("vertebrobasilar artery"),3)
    return
    :*B0:Lac-::
        sendByClipboard(StringUpperFirst("微細梗塞"),3)
    return
    :B0:Lac::
        sendByClipboard(StringUpperFirst("lacune" A_EndChar),3)
    return
    :*B0:Lac1::
        sendByClipboard(StringUpperFirst("lacunes"),3)
    return
    :B0:Ol::
        sendByClipboard(StringUpperFirst("old lacune" A_EndChar),2)
    return
    :*B0:Ol1::
        sendByClipboard(StringUpperFirst("old lacunes"),2)
    return
    :B0:Aol::
        sendByClipboard(StringUpperFirst("an old lacune" A_EndChar),3)
    return
    :*B0:Ctp0::
        sendByClipboard(StringUpperFirst("CT perfusion shows symmetric cerebral perfusion."),3)
    return
    :*B0:Ctp1::
        sendByClipboard(StringUpperFirst("CT perfusion shows decreased CBF and prolonged MTT"),3)
    return
    :B0:Ptnb::
        sendByClipboard(StringUpperFirst("patent bilateral ICA, MCA, ACA, PCA, VA, and BA." A_EndChar),4)
    return
    :*B0:Cow0::
        sendByClipboard(StringUpperFirst("TOF MRA shows no definite vascular abnormality of the Willis circle of arteries."),3)
    return
    :B0:Toma::
        sendByClipboard(StringUpperFirst("TOF MRA shows" A_EndChar),4)
    return
    :B0:Cema::
        sendByClipboard(StringUpperFirst("Contrast-enhanced MRA shows" A_EndChar),4)
    return
    :B0:Tcma::
        sendByClipboard(StringUpperFirst("TOF MRA and contrast-enhanced MRA show" A_EndChar),4)
    return
    :B0:Pds::
        sendByClipboard(StringUpperFirst("patent dural sinuses." A_EndChar),3)
    return
    :B0:Tsn::
        sendByClipboard(StringUpperFirst("transverse sinus" A_EndChar),3)
    return
    :*B0:Tsn1::
        sendByClipboard(StringUpperFirst("transverse sinuses"),3)
    return
    :B0:Ssn::
        sendByClipboard(StringUpperFirst("sigmoid sinus" A_EndChar),3)
    return
    :*B0:Ssn1::
        sendByClipboard(StringUpperFirst("sigmoid sinuses"),3)
    return
    :*B0:Tssn::
        sendByClipboard(StringUpperFirst("transverse-sigmoid sinus"),3)
    return
    :*B0:Tra0::
        sendByClipboard(StringUpperFirst("no evidence of traumatic brain injury nor cervical fracture."),3)
    return
    :*B0:Forp::
        sendByClipboard(StringUpperFirst("fetal origin of the right PCA"),3)
    return
    :*B0:Folp::
        sendByClipboard(StringUpperFirst("fetal origin of the left PCA"),3)
    return
    :B0:Fobp::
        sendByClipboard(StringUpperFirst("fetal origin of bilateral PCA" A_EndChar),4)
    return
    :B0:Tsh::
        sendByClipboard(StringUpperFirst("trans-sphenoid hypophysectomy" A_EndChar),3)
    return
    :*B0:Tsh1::
        sendByClipboard(StringUpperFirst("Post-operative change in the sella turcica with evidence of prior trans-sphenoid hypophysectomy."),3)
    return
    :*B0:Tsh2::
        sendByClipboard(StringUpperFirst("Post-operative changes of trans-sphenoid hypophysectomy with increased SI in the sphenoid sinus and bony defect at the sellar floor."),3)
    return
    :B0:Ocd::
        sendByClipboard(StringUpperFirst("downward herniation of the optic chiasm due to post-operative change." A_EndChar),3)
    return
    :*B0:Ocd1::
        sendByClipboard(StringUpperFirst("Mild downward herniation of the optic chiasm due to post-operative change."),3)
    return
    :*B0:Mlsr::
        sendByClipboard(StringUpperFirst("midline shift to right side"),3)
    return
    :*B0:Mlsl::
        sendByClipboard(StringUpperFirst("midline shift to left side"),3)
    return
    :B0:Mls::
        sendByClipboard(StringUpperFirst("midline shift" A_EndChar),3)
    return
    :*B0:Lpic::
        sendByClipboard(StringUpperFirst("left vertebral artery ending at PICA"),3)
    return
    :*B0:Rpic::
        sendByClipboard(StringUpperFirst("right vertebral artery ending at PICA"),3)
    return
    :B0:Bnl::
        sendByClipboard(StringUpperFirst("bilateral neck lymph nodes" A_EndChar),3)
    return
    :B0:Bpx::
        sendByClipboard(StringUpperFirst("brachial plexus" A_EndChar),3)
    return
    :*B0:Bpx1::
        sendByClipboard(StringUpperFirst("brachial plexi"),3)
    return
    :B0:Mlm::
        sendByClipboard(StringUpperFirst("myelomalacia" A_EndChar),3)
    return
    :B0:Ggb::
        sendByClipboard(StringUpperFirst("gingivobuccal" A_EndChar),3)
    return
    :*B0:Bcab::
        sendByClipboard(StringUpperFirst("bilateral carotid bulbs"),3)
    return
    :*B0:Rcab::
        sendByClipboard(StringUpperFirst("right carotid bulb"),3)
    return
    :*B0:Lcab::
        sendByClipboard(StringUpperFirst("left carotid bulb"),3)
    return
    :*B0:Bsfn::
        sendByClipboard(StringUpperFirst("bilateral carotid siphons"),3)
    return
    :*B0:Rsfn::
        sendByClipboard(StringUpperFirst("right carotid siphon"),3)
    return
    :*B0:Lsfn::
        sendByClipboard(StringUpperFirst("left carotid siphon"),3)
    return
    :B0:Kkb::
        sendByClipboard(StringUpperFirst("concha bullosa" A_EndChar),3)
    return
    :*B0:Rcrm::
        sendByClipboard(StringUpperFirst("retention cyst in right maxillary sinus."),3)
    return
    :*B0:Rcrm1::
        sendByClipboard(StringUpperFirst("retention cysts in right maxillary sinus."),4)
    return
    :*B0:Rclm::
        sendByClipboard(StringUpperFirst("retention cyst in left maxillary sinus."),3)
    return
    :*B0:Rclm1::
        sendByClipboard(StringUpperFirst("retention cysts in left maxillary sinus."),4)
    return
    :*B0:Rcbm::
        sendByClipboard(StringUpperFirst("retention cysts in bilateral maxillary sinuses."),3)
    return
    :*B0:Mtrm::
        sendByClipboard(StringUpperFirst("mucosal thickening in right maxillary sinus."),3)
    return
    :*B0:Mtlm::
        sendByClipboard(StringUpperFirst("mucosal thickening in left maxillary sinus."),3)
    return
    :*B0:Mtbm::
        sendByClipboard(StringUpperFirst("mucosal thickening in bilateral maxillary sinuses."),3)
    return
    :*B0:Mrrm::
        sendByClipboard(StringUpperFirst("mucus retention in right maxillary sinus."),3)
    return
    :*B0:Mrlm::
        sendByClipboard(StringUpperFirst("mucus retention in left maxillary sinus."),3)
    return
    :*B0:Mrbm::
        sendByClipboard(StringUpperFirst("mucus retention in bilateral maxillary sinuses."),3)
    return
    :*B0:Art1::
        sendByClipboard(StringUpperFirst("Beam-hardening artifacts from dental prosthesis obscure the image details in oral cavity."),3)
    return
    :*B0:Art2::
        sendByClipboard(StringUpperFirst("Magnetic susceptibility artifacts from dental prosthesis obscure the image details in oral cavity."),3)
    return
    :B0:Omt::
        sendByClipboard(StringUpperFirst("osteomucosal thickening" A_EndChar),3)
    return
    :B0:Zyg::
        sendByClipboard(StringUpperFirst("zygomatic" A_EndChar),3)
    return
    :B0:Trg::
        sendByClipboard(StringUpperFirst("pterygoid" A_EndChar),3)
    return
    :B0:Vcc::
        sendByClipboard(StringUpperFirst("vocal cord" A_EndChar),3)
    return
    :B0:Mdb::
        sendByClipboard(StringUpperFirst("mandible" A_EndChar),3)
    return
    :*B0:Mdb1::
        sendByClipboard(StringUpperFirst("mandibular"),3)
    return
    :B0:Scb::
        sendByClipboard(StringUpperFirst("scleral buckling" A_EndChar),3)
    return
    :B0:Nnl::
        sendByClipboard(StringUpperFirst("no definite neck lymphadenopathy." A_EndChar),3)
    return
    :B0:Lrg::
        sendByClipboard(StringUpperFirst("laryngectomy" A_EndChar),3)
    return
    :B0:Tlg::
        sendByClipboard(StringUpperFirst("total laryngectomy" A_EndChar),3)
    return
    :B0:Msp::
        sendByClipboard(StringUpperFirst("masticator space" A_EndChar),3)
    return
    :B0:Crp::
        sendByClipboard(StringUpperFirst("carotid space" A_EndChar),3)
    return
    :B0:Crt::
        sendByClipboard(StringUpperFirst("carotid" A_EndChar),3)
    return
    :B0:Ppp::
        sendByClipboard(StringUpperFirst("parapharyngeal space" A_EndChar),3)
    return
    :B0:Rpp::
        sendByClipboard(StringUpperFirst("retropharyngeal space" A_EndChar),3)
    return
    :B0:Bcp::
        sendByClipboard(StringUpperFirst("buccal space" A_EndChar),3)
    return
    :B0:Buc::
        sendByClipboard(StringUpperFirst("buccal" A_EndChar),3)
    return
    :B0:Itf::
        sendByClipboard(StringUpperFirst("infratemporal fossa" A_EndChar),3)
    return
    :B0:Ptp::
        sendByClipboard(StringUpperFirst("parotid space" A_EndChar),3)
    return
    :B0:Skb::
        sendByClipboard(StringUpperFirst("skull base" A_EndChar),3)
    return
    :B0:Por::
        sendByClipboard(StringUpperFirst("periorbital" A_EndChar),3)
    return
    :B0:Orb::
        sendByClipboard(StringUpperFirst("orbital" A_EndChar),3)
    return
    :B0:Orw::
        sendByClipboard(StringUpperFirst("orbital wall" A_EndChar),3)
    return
    :B0:Snc::
        sendByClipboard(StringUpperFirst("sinonasal cavity" A_EndChar),3)
    return
    :*B0:Snc1::
        sendByClipboard(StringUpperFirst("sinonasal cavities"),3)
    return
    :B0:Rms::
        sendByClipboard(StringUpperFirst("right maxillary sinus" A_EndChar),3)
    return
    :B0:Lms::
        sendByClipboard(StringUpperFirst("left maxillary sinus" A_EndChar),3)
    return
    :B0:Bms::
        sendByClipboard(StringUpperFirst("bilateral maxillary sinuses" A_EndChar),3)
    return
    :B0:Rps::
        sendByClipboard(StringUpperFirst("right sphenoid sinus" A_EndChar),3)
    return
    :B0:Lps::
        sendByClipboard(StringUpperFirst("left sphenoid sinus" A_EndChar),3)
    return
    :B0:Bps::
        sendByClipboard(StringUpperFirst("bilateral sphenoid sinuses" A_EndChar),3)
    return
    :B0:Rfs::
        sendByClipboard(StringUpperFirst("right frontal sinus" A_EndChar),3)
    return
    :B0:Lfs::
        sendByClipboard(StringUpperFirst("left frontal sinus" A_EndChar),3)
    return
    :B0:Bfs::
        sendByClipboard(StringUpperFirst("bilateral frontal sinuses" A_EndChar),3)
    return
    :B0:Bes::
        sendByClipboard(StringUpperFirst("bilateral ethmoid sinuses" A_EndChar),3)
    return
    :B0:Rmx::
        sendByClipboard(StringUpperFirst("retromaxillary" A_EndChar),3)
    return
    :B0:Adt::
        sendByClipboard(StringUpperFirst("aerodigestive tract" A_EndChar),3)
    return
    :B0:Rpx::
        sendByClipboard(StringUpperFirst("retropharyngeal" A_EndChar),3)
    return
    :*B0:Rpx1::
        sendByClipboard(StringUpperFirst("retropharynx"),3)
    return
    :*B0:Dllp::
        sendByClipboard(StringUpperFirst("dehiscence of left lamina papyracea."),3)
    return
    :*B0:Drlp::
        sendByClipboard(StringUpperFirst("dehiscence of right lamina papyracea."),3)
    return
    :*B0:Thyd::
        sendByClipboard(StringUpperFirst("thyroidectomy"),3)
    return
    :*B0:Lart::
        sendByClipboard(StringUpperFirst("laryngectomy"),3)
    return
    :*B0:Trko::
        sendByClipboard(StringUpperFirst("tracheostomy"),3)
    return
    :B0:Nlc::
        sendByClipboard(StringUpperFirst("nuchal ligament calcification." A_EndChar),3)
    return
    :*B0:Npcy-::
        sendByClipboard(StringUpperFirst("鼻咽囊腫"),4)
    return
    :B0:Npcy::
        sendByClipboard(StringUpperFirst("nasopharyngeal cyst" A_EndChar),4)
    return
    :*B0:Aoas::
        sendByClipboard(StringUpperFirst("atlanto-occipital assimilation"),3)
    return
    :B0:Pys::
        sendByClipboard(StringUpperFirst("pyriform sinus" A_EndChar),3)
    return
    :*B0:Pys1::
        sendByClipboard(StringUpperFirst("pyriform sinuses"),3)
    return
    :B0:Exf::
        sendByClipboard(StringUpperFirst("exophthalmos" A_EndChar),3)
    return
    :B0:Gof::
        sendByClipboard(StringUpperFirst("Graves' ophthalmopathy" A_EndChar),3)
    return
    :B0:Oca::
        sendByClipboard(StringUpperFirst("oral cavity" A_EndChar),3)
    return
    :B0:Nca::
        sendByClipboard(StringUpperFirst("nasal cavity" A_EndChar),3)
    return
    :*B0:Nca1::
        sendByClipboard(StringUpperFirst("nasal cavities"),3)
    return
    :B0:Gst::
        sendByClipboard(StringUpperFirst("glossectomy" A_EndChar),3)
    return
    :B0:Tym::
        sendByClipboard(StringUpperFirst("tympanic membrane" A_EndChar),3)
    return
    :B0:Tye::
        sendByClipboard(StringUpperFirst("thyroidectomy" A_EndChar),3)
    return
    :B0:Aef::
        sendByClipboard(StringUpperFirst("aryepiglottic fold" A_EndChar),3)
    return
    :B0:Nst::
        sendByClipboard(StringUpperFirst("nasal septum" A_EndChar),3)
    return
    :B0:Ppf::
        sendByClipboard(StringUpperFirst("pterygopalatine fossa" A_EndChar),3)
    return
    :*B0:Rcy-::
        sendByClipboard(StringUpperFirst("鼻竇滯留囊腫"),3)
    return
    :B0:Rcy::
        sendByClipboard(StringUpperFirst("retention cyst" A_EndChar),3)
    return
    :*B0:Rcy1::
        sendByClipboard(StringUpperFirst("retention cysts"),3)
    return
    :B0:Faf::
        sendByClipboard(StringUpperFirst("fissula ante fenestram" A_EndChar),3)
    return
    :B0:Mps::
        sendByClipboard(StringUpperFirst("mucosal thickening in paranasal sinuses." A_EndChar),3)
    return
    :B0:Rmr::
        sendByClipboard(StringUpperFirst("retromolar" A_EndChar),3)
    return
    :B0:Tg::
        sendByClipboard(StringUpperFirst("tongue" A_EndChar),2)
    return
    :B0:Ig::
        sendByClipboard(StringUpperFirst("eyeglobe" A_EndChar),2)
    return
    :*B0:Ig1::
        sendByClipboard(StringUpperFirst("eyeglobes"),2)
    return
    :B0:Nk::
        sendByClipboard(StringUpperFirst("neck" A_EndChar),2)
    return
    :B0:Msad::
        sendByClipboard(StringUpperFirst("Magnetic suceptibility artifacts from dental prosthesis obscure the image details in oral cavity." A_EndChar),4)
    return
    :*B0:Eye0::
        sendByClipboard(StringUpperFirst("phthisis bulbi"),3)
    return
    :*B0:Eye1::
        sendByClipboard(StringUpperFirst("status post phacoemulsification"),3)
    return
    :B0:Oph::
        sendByClipboard(StringUpperFirst("ophthalmic" A_EndChar),3)
    return
    :B0:Djdc::
        sendByClipboard(StringUpperFirst("degenerative change of cervical spine" A_EndChar),4)
    return
    :*B0:Cs0::
        sendByClipboard(StringUpperFirst("normal alignment of cervical spine."),2)
    return
    :*B0:Ts0::
        sendByClipboard(StringUpperFirst("normal alignment of thoracic spine."),2)
    return
    :*B0:Ls0::
        sendByClipboard(StringUpperFirst("normal alignment of lumbar spine."),2)
    return
    :*B0:Tls0::
        sendByClipboard(StringUpperFirst("normal alignment of thoracolumbar spine."),3)
    return
    :B0:Mpo::
        sendByClipboard(StringUpperFirst("mucoperiosteal" A_EndChar),3)
    return
    :B0:Pnm::
        sendByClipboard(StringUpperFirst("pneumatization" A_EndChar),3)
    return
    :*B0:Pns-::
        sendByClipboard(StringUpperFirst("鼻竇"),3)
    return
    :B0:Pns::
        sendByClipboard(StringUpperFirst("paranasal sinuses" A_EndChar),3)
    return
    :*B0:Pns1::
        sendByClipboard(StringUpperFirst("paranasal sinusitis"),3)
    return
    :B0:Sns::
        sendByClipboard(StringUpperFirst("sinusitis" A_EndChar),3)
    return
    :B0:Npx::
        sendByClipboard(StringUpperFirst("nasopharynx" A_EndChar),3)
    return
    :*B0:Npx1::
        sendByClipboard(StringUpperFirst("nasopharyngeal"),3)
    return
    :B0:Opx::
        sendByClipboard(StringUpperFirst("oropharynx" A_EndChar),3)
    return
    :*B0:Opx1::
        sendByClipboard(StringUpperFirst("oropharyngeal"),3)
    return
    :B0:Lx::
        sendByClipboard(StringUpperFirst("larynx" A_EndChar),2)
    return
    :*B0:Lx1::
        sendByClipboard(StringUpperFirst("laryngeal"),2)
    return
    :B0:Ppx::
        sendByClipboard(StringUpperFirst("parapharyngeal" A_EndChar),3)
    return
    :B0:Px::
        sendByClipboard(StringUpperFirst("pharynx" A_EndChar),2)
    return
    :*B0:Px1::
        sendByClipboard(StringUpperFirst("pharyngeal"),2)
    return
    :B0:Hpx::
        sendByClipboard(StringUpperFirst("hypopharynx" A_EndChar),3)
    return
    :*B0:Hpx1::
        sendByClipboard(StringUpperFirst("hypopharyngeal"),3)
    return
    :*B0:Ijvv::
        sendByClipboard(StringUpperFirst("internal jugular vein"),3)
    return
    :*B0:Ijvv1::
        sendByClipboard(StringUpperFirst("internal jugular veins"),4)
    return
    :B0:Mxy::
        sendByClipboard(StringUpperFirst("maxillary" A_EndChar),3)
    return
    :B0:Mxs::
        sendByClipboard(StringUpperFirst("maxillary sinus" A_EndChar),3)
    return
    :*B0:Mxs1::
        sendByClipboard(StringUpperFirst("maxillary sinuses"),3)
    return
    :*B0:Mxs2::
        sendByClipboard(StringUpperFirst("maxillary sinusitis"),3)
    return
    :B0:Ets::
        sendByClipboard(StringUpperFirst("ethmoid sinus" A_EndChar),3)
    return
    :*B0:Ets1::
        sendByClipboard(StringUpperFirst("ethmoid sinuses"),3)
    return
    :*B0:Ets2::
        sendByClipboard(StringUpperFirst("ethmoid sinusitis"),3)
    return
    :B0:Eth::
        sendByClipboard(StringUpperFirst("ethmoid" A_EndChar),3)
    return
    :B0:Sph::
        sendByClipboard(StringUpperFirst("sphenoid" A_EndChar),3)
    return
    :B0:Sps::
        sendByClipboard(StringUpperFirst("sphenoid sinus" A_EndChar),3)
    return
    :*B0:Sps1::
        sendByClipboard(StringUpperFirst("sphenoid sinuses"),3)
    return
    :*B0:Sps2::
        sendByClipboard(StringUpperFirst("sphenoid sinusitis"),3)
    return
    :B0:Frs::
        sendByClipboard(StringUpperFirst("frontal sinus" A_EndChar),3)
    return
    :*B0:Frs1::
        sendByClipboard(StringUpperFirst("frontal sinuses"),3)
    return
    :*B0:Frs2::
        sendByClipboard(StringUpperFirst("frontal sinusitis"),3)
    return
    :*B0:Thy-::
        sendByClipboard(StringUpperFirst("甲狀腺"),3)
    return
    :B0:Thy::
        sendByClipboard(StringUpperFirst("thyroid" A_EndChar),3)
    return
    :B0:Thg::
        sendByClipboard(StringUpperFirst("thyroid gland" A_EndChar),3)
    return
    :*B0:Thg1::
        sendByClipboard(StringUpperFirst("thyroid glands"),3)
    return
    :B0:Etg::
        sendByClipboard(StringUpperFirst("enlarged thyroid gland" A_EndChar),3)
    return
    :*B0:Etgn::
        sendByClipboard(StringUpperFirst("enlarged thyroid gland with nodule(s)."),3)
    return
    :*B0:Thyc::
        sendByClipboard(StringUpperFirst("thyroid calcification(s)"),3)
    return
    :B0:Pvst::
        sendByClipboard(StringUpperFirst("prevertebral soft tissue" A_EndChar),4)
    return
    :B0:Cerv::
        sendByClipboard(StringUpperFirst("cervical" A_EndChar),4)
    return
    :B0:Sbm::
        sendByClipboard(StringUpperFirst("submandibular" A_EndChar),3)
    return
    :B0:Sbg::
        sendByClipboard(StringUpperFirst("submandibular gland" A_EndChar),3)
    return
    :*B0:Sbg1::
        sendByClipboard(StringUpperFirst("submandibular glands"),3)
    return
    :B0:Sln::
        sendByClipboard(StringUpperFirst("sublingual" A_EndChar),3)
    return
    :B0:Slg::
        sendByClipboard(StringUpperFirst("sublingual gland" A_EndChar),3)
    return
    :*B0:Slg1::
        sendByClipboard(StringUpperFirst("sublingual glands"),3)
    return
    :B0:Ptd::
        sendByClipboard(StringUpperFirst("parotid" A_EndChar),3)
    return
    :B0:Pdg::
        sendByClipboard(StringUpperFirst("parotid gland" A_EndChar),3)
    return
    :*B0:Pdg1::
        sendByClipboard(StringUpperFirst("parotid glands"),3)
    return
    :B0:Scv::
        sendByClipboard(StringUpperFirst("supraclavicular" A_EndChar),3)
    return
    :B0:Icv::
        sendByClipboard(StringUpperFirst("infraclavicular" A_EndChar),3)
    return
    :B0:Nln::
        sendByClipboard(StringUpperFirst("no definite enlarged (>1cm) neck lymph node.`n-" A_EndChar),3)
    return
    :*B0:Br0::
        sendByClipboard(StringUpperFirst("no SI change nor abnormal enhancing lesion of visible brain parenchyma."),2)
    return
    :*B0:Tn-::
        sendByClipboard(StringUpperFirst("甲狀腺結節"),2)
    return
    :*B0:Tn/::
        sendByClipboard(StringUpperFirst("thyroid nodule(s)."),2)
    return
    :*B0:Tn1::
        sendByClipboard(StringUpperFirst("thyroid nodules"),2)
    return
    :B0:Btn::
        sendByClipboard(StringUpperFirst("bilateral thyroid nodules." A_EndChar),3)
    return
    :B0:Tn::
        sendByClipboard(StringUpperFirst("thyroid nodule" A_EndChar),2)
    return
    :*B0:Thn1::
        sendByClipboard(StringUpperFirst("thyroid nodules"),3)
    return
    :B0:Mtp::
        sendByClipboard(StringUpperFirst("medial tibial plateau" A_EndChar),3)
    return
    :B0:Ltp::
        sendByClipboard(StringUpperFirst("lateral tibial plateau" A_EndChar),3)
    return
    :*B0:Mpar::
        sendByClipboard(StringUpperFirst("medial patellar retinaculum"),3)
    return
    :*B0:Lpar::
        sendByClipboard(StringUpperFirst("lateral patellar retinaculum"),3)
    return
    :*B0:Chll::
        sendByClipboard(StringUpperFirst("coracohumeral ligament"),3)
    return
    :*B0:Roii::
        sendByClipboard(StringUpperFirst("rotator interval"),3)
    return
    :*B0:Rcii::
        sendByClipboard(StringUpperFirst("rotator cuff interval"),3)
    return
    :*B0:Ritt::
        sendByClipboard(StringUpperFirst("rotator interval tear"),3)
    return
    :B0:Bts::
        sendByClipboard(StringUpperFirst("biceps tendon sheath" A_EndChar),3)
    return
    :B0:Pli::
        sendByClipboard(StringUpperFirst("periligamentous" A_EndChar),3)
    return
    :B0:Mso::
        sendByClipboard(StringUpperFirst("mixed sclerotic/osteolytic" A_EndChar),3)
    return
    :*B0:Frz0::
        sendByClipboard(StringUpperFirst("thickening of the axillary recess joint capsule"),3)
    return
    :B0:Frz::
        sendByClipboard(StringUpperFirst("adhesive capsulitis" A_EndChar),3)
    return
    :B0:Ije::
        sendByClipboard(StringUpperFirst("increased joint effusion" A_EndChar),3)
    return
    :B0:Ahi::
        sendByClipboard(StringUpperFirst("acromio-humeral interval" A_EndChar),3)
    return
    :*B0:Tnlg::
        sendByClipboard(StringUpperFirst("intact tendons and ligaments."),3)
    return
    :*B0:Lgtn::
        sendByClipboard(StringUpperFirst("intact ligaments and tendons."),3)
    return
    :*B0:Tn0::
        sendByClipboard(StringUpperFirst("intact tendons."),2)
    return
    :*B0:Lg0::
        sendByClipboard(StringUpperFirst("intact ligaments."),2)
    return
    :*B0:Mn0::
        sendByClipboard(StringUpperFirst("intact meniscus."),2)
    return
    :B0:Lum::
        sendByClipboard(StringUpperFirst("lumbar" A_EndChar),3)
    return
    :*B0:Prnc::
        sendByClipboard(StringUpperFirst("perineural cyst(s)"),3)
    return
    :B0:Tlv::
        sendByClipboard(StringUpperFirst("Tarlov cyst" A_EndChar),3)
    return
    :*B0:Tlv1::
        sendByClipboard(StringUpperFirst("Tarlov cysts"),3)
    return
    :*B0:Stlv::
        sendByClipboard(StringUpperFirst("sacral Tarlov cyst(s)."),3)
    return
    :*B0:Fd0::
        sendByClipboard(StringUpperFirst("no obvious displaced fracture. (Small bone fracture may not be detected by images.)"),2)
    return
    :*B0:Acet::
        sendByClipboard(StringUpperFirst("acetabulum"),3)
    return
    :B0:Scp::
        sendByClipboard(StringUpperFirst("scapula" A_EndChar),3)
    return
    :B0:Mrl::
        sendByClipboard(StringUpperFirst("marrow-replacing lesion" A_EndChar),3)
    return
    :*B0:Mrl1::
        sendByClipboard(StringUpperFirst("marrow-replacing lesions"),3)
    return
    :B0:Nvr::
        sendByClipboard(StringUpperFirst("nerve root" A_EndChar),3)
    return
    :*B0:Nvr1::
        sendByClipboard(StringUpperFirst("nerve roots"),3)
    return
    :B0:Ceq::
        sendByClipboard(StringUpperFirst("cauda equina" A_EndChar),3)
    return
    :*B0:Spst::
        sendByClipboard(StringUpperFirst("spinal stenosis"),3)
    return
    :*B0:Ss0::
        sendByClipboard(StringUpperFirst("no significant spinal stenosis."),2)
    return
    :B0:Bom::
        sendByClipboard(StringUpperFirst("bone metastases" A_EndChar),3)
    return
    :*B0:Bomc::
        sendByClipboard(StringUpperFirst("bone metastases with compression fracture."),3)
    return
    :*B0:Bomf::
        sendByClipboard(StringUpperFirst("bone metastases with fracture."),3)
    return
    :*B0:Sbom::
        sendByClipboard(StringUpperFirst("sclerotic bone metastases."),3)
    return
    :*B0:Obom::
        sendByClipboard(StringUpperFirst("osteolytic bone metastases."),3)
    return
    :B0:Hum::
        sendByClipboard(StringUpperFirst("humerus" A_EndChar),3)
    return
    :*B0:Hum1::
        sendByClipboard(StringUpperFirst("humeral"),3)
    return
    :B0:Fem::
        sendByClipboard(StringUpperFirst("femur" A_EndChar),3)
    return
    :*B0:Fem1::
        sendByClipboard(StringUpperFirst("femoral"),3)
    return
    :B0:Tbi::
        sendByClipboard(StringUpperFirst("tibia" A_EndChar),3)
    return
    :*B0:Tbi1::
        sendByClipboard(StringUpperFirst("tibial"),3)
    return
    :B0:Fbu::
        sendByClipboard(StringUpperFirst("fibula" A_EndChar),3)
    return
    :*B0:Fbu1::
        sendByClipboard(StringUpperFirst("fibulal"),3)
    return
    :B0:Rad::
        sendByClipboard(StringUpperFirst("radius" A_EndChar),3)
    return
    :*B0:Rad1::
        sendByClipboard(StringUpperFirst("radial"),3)
    return
    :B0:Un::
        sendByClipboard(StringUpperFirst("ulna" A_EndChar),2)
    return
    :*B0:Un1::
        sendByClipboard(StringUpperFirst("ulnar"),2)
    return
    :B0:Sld::
        sendByClipboard(StringUpperFirst("shoulder" A_EndChar),3)
    return
    :B0:Bme::
        sendByClipboard(StringUpperFirst("bone marrow edema" A_EndChar),3)
    return
    :B0:Pop::
        sendByClipboard(StringUpperFirst("popliteal artery" A_EndChar),3)
    return
    :*B0:Pop1::
        sendByClipboard(StringUpperFirst("popliteal arteries"),3)
    return
    :B0:Clv::
        sendByClipboard(StringUpperFirst("clavicle" A_EndChar),3)
    return
    :*B0:Clv1::
        sendByClipboard(StringUpperFirst("clavicles"),3)
    return
    :*B0:Clv2::
        sendByClipboard(StringUpperFirst("clavicular"),3)
    return
    :B0:Opk::
        sendByClipboard(StringUpperFirst("osteopoikilosis" A_EndChar),3)
    return
    :B0:Acll::
        sendByClipboard(StringUpperFirst("anterior cruciate ligament" A_EndChar),4)
    return
    :*B0:Crl0::
        sendByClipboard(StringUpperFirst("intact cruciate ligaments."),3)
    return
    :*B0:Crl1::
        sendByClipboard(StringUpperFirst("cruciate ligaments"),3)
    return
    :B0:Acl1::
        sendByClipboard(StringUpperFirst("grade 1 ACL injury (intraligamentous injury)" A_EndChar),4)
    return
    :B0:Acl2::
        sendByClipboard(StringUpperFirst("grade 2 ACL tear (suggesting partial tear)" A_EndChar),4)
    return
    :B0:Abn1::
        sendByClipboard(StringUpperFirst("type I accessory navicular bone" A_EndChar),4)
    return
    :B0:Abn2::
        sendByClipboard(StringUpperFirst("type II accessory navicular bone" A_EndChar),4)
    return
    :B0:Aclam::
        sendByClipboard(StringUpperFirst("anteromedial bundle" A_EndChar),5)
    return
    :B0:Acr::
        sendByClipboard(StringUpperFirst("acromion" A_EndChar),3)
    return
    :B0:Ahlm::
        sendByClipboard(StringUpperFirst("anterior horn of lateral meniscus" A_EndChar),4)
    return
    :B0:Ahmm::
        sendByClipboard(StringUpperFirst("anterior horn of medial meniscus" A_EndChar),4)
    return
    :B0:Aco::
        sendByClipboard(StringUpperFirst("accessory ossicle" A_EndChar),3)
    return
    :*B0:Aco1::
        sendByClipboard(StringUpperFirst("accessory ossicles"),3)
    return
    :B0:Ars::
        sendByClipboard(StringUpperFirst("articular-side" A_EndChar),3)
    return
    :B0:Ass::
        sendByClipboard(StringUpperFirst("multilevel syndesmophytoses, ligamentous ossifications, bamboo-appearance of spine, and ankylosis of bilateral sacroiliac joints, compatible with ankylosing spondylitis" A_EndChar),3)
    return
    :B0:Avn::
        sendByClipboard(StringUpperFirst("avascular necrosis" A_EndChar),3)
    return
    :B0:Avn2::
        sendByClipboard(StringUpperFirst("subchondral geographic lesion with serpigeous sclerotic margin" A_EndChar),4)
    return
    :B0:Avn3::
        sendByClipboard(StringUpperFirst("subchondral geographic lesion with serpigeous sclerotic margin and subchondral collapse" A_EndChar),4)
    return
    :B0:Avnmrr::
        sendByClipboard(StringUpperFirst("geographic subchondral lesion, of intermediate to low SI on T1WI, mixed SI on T2WI, and marginal enhancement on post-contrast T1WI, with serpiginous sclerotic margin at the right femoral head; mild ill-defined area of hyperemic or edematous bone marrow at the adjacent region of right femoral neck to right trochanteric area; partial collapse with subchondral fracture at the right femoral head; abnormal increased effusion and synovial enhancement in the right hip joint space." A_EndChar),6)
    return
    :B0:Avnmrl::
        sendByClipboard(StringUpperFirst("geographic subchondral lesion, of intermediate to low SI on T1WI, mixed SI on T2WI, and marginal enhancement on post-contrast T1WI, with serpiginous sclerotic margin at the left femoral head; mild ill-defined area of hyperemic or edematous bone marrow at the adjacent region of left femoral neck to left trochanteric area; partial collapse with subchondral fracture at the left femoral head; abnormal increased effusion and synovial enhancement in the left hip joint space." A_EndChar),6)
    return
    :B0:Bakers::
        sendByClipboard(StringUpperFirst("loculated cystic lesion, with communicating tract to the synovial cavity and between the medial head of gastrocnemius muscle and semimenbranosus tendon, at posterior medial aspect of knee joint." A_EndChar),6)
    return
    :B0:Bfg::
        sendByClipboard(StringUpperFirst("femoral greater trochanteric region" A_EndChar),3)
    return
    :B0:Bfi::
        sendByClipboard(StringUpperFirst("femoral intertrochanteric region" A_EndChar),3)
    return
    :B0:Bfis::
        sendByClipboard(StringUpperFirst("femoral inter- to subtrochanteric region" A_EndChar),4)
    return
    :B0:Bgd::
        sendByClipboard(StringUpperFirst("bulging disc" A_EndChar),3)
    return
    :*B0:Bgd1::
        sendByClipboard(StringUpperFirst("bulging discs"),3)
    return
    :B0:Bgc::
        sendByClipboard(StringUpperFirst("concentric bulging disc" A_EndChar),3)
    return
    :*B0:Bgc1::
        sendByClipboard(StringUpperFirst("concentric bulging discs"),3)
    return
    :B0:Bge::
        sendByClipboard(StringUpperFirst("eccentric bulging disc" A_EndChar),3)
    return
    :*B0:Bge1::
        sendByClipboard(StringUpperFirst("eccentric bulging discs"),3)
    return
    :B0:Bgg::
        sendByClipboard(StringUpperFirst("bulging disc(s) with adjacent thecal sac indentation" A_EndChar),3)
    return
    :B0:Bgm::
        sendByClipboard(StringUpperFirst("mild bulging disc(s) with mild adjcent thecal sac indentation" A_EndChar),3)
    return
    :B0:Bpd::
        sendByClipboard(StringUpperFirst("bulging-protruding disc" A_EndChar),3)
    return
    :*B0:Bpd1::
        sendByClipboard(StringUpperFirst("bulging-protruding discs"),3)
    return
    :B0:Bhg::
        sendByClipboard(StringUpperFirst("humeral greater tubercle" A_EndChar),3)
    return
    :B0:Bhn::
        sendByClipboard(StringUpperFirst("humeral surgical neck" A_EndChar),3)
    return
    :B0:Bip::
        sendByClipboard(StringUpperFirst("biphalangism at the little toe" A_EndChar),3)
    return
    :B0:Bip2::
        sendByClipboard(StringUpperFirst("biphalangism at the little and 4th toes" A_EndChar),4)
    return
    :B0:Bis::
        sendByClipboard(StringUpperFirst("bone island(s) (enostosis)" A_EndChar),3)
    return
    :*B0:Blc1::
        sendByClipboard(StringUpperFirst("biceps-labral complex"),3)
    return
    :B0:Btt::
        sendByClipboard(StringUpperFirst("tibial tuberosity" A_EndChar),3)
    return
    :B0:Bus::
        sendByClipboard(StringUpperFirst("bursal-side" A_EndChar),3)
    return
    :B0:Cop::
        sendByClipboard(StringUpperFirst("cord compression" A_EndChar),3)
    return
    :B0:Cid::
        sendByClipboard(StringUpperFirst("cortical indistinctness" A_EndChar),3)
    return
    :B0:Cdhl::
        sendByClipboard(StringUpperFirst("shallowing of acetabulum with superior lateral subluxation of the deformed femoral head and joint space narrowing and subchondral sclerosis, suggestive of congenital dysplasia of left hip joint." A_EndChar),4)
    return
    :B0:Cdhr::
        sendByClipboard(StringUpperFirst("shallowing of acetabulum with superior lateral subluxation of the deformed femoral head and joint space narrowing and subchondral sclerosis, suggestive of congenital dysplasia of right hip joint." A_EndChar),4)
    return
    :B0:Cfaa::
        sendByClipboard(StringUpperFirst("common femoral artery" A_EndChar),4)
    return
    :B0:Cfaa1::
        sendByClipboard(StringUpperFirst("common femoral arteries" A_EndChar),5)
    return
    :B0:Cff::
        sendByClipboard(StringUpperFirst("wedge deformity and decreased height, suggestive of compression fracture, at" A_EndChar),3)
    return
    :B0:Cfh::
        sendByClipboard(StringUpperFirst("compression fracture with decreased vertebral height at" A_EndChar),3)
    return
    :B0:Cfp::
        sendByClipboard(StringUpperFirst("pathological compression fracture" A_EndChar),3)
    return
    :B0:Cfw::
        sendByClipboard(StringUpperFirst("compression fracture with wedge deformity at" A_EndChar),3)
    return
    :B0:Cj::
        sendByClipboard(StringUpperFirst("in conjunction with" A_EndChar),2)
    return
    :B0:Cjj::
        sendByClipboard(StringUpperFirst("in conjunction with bilateral facet joint arthroses and hypertrophic ligamenta flava, causing" A_EndChar),3)
    return
    :B0:Cj1::
        sendByClipboard(StringUpperFirst("with hypertrophic ligamenta flava, causing" A_EndChar),3)
    return
    :B0:Cj2::
        sendByClipboard(StringUpperFirst("with bilateral facet joint arthroses and hypertrophic ligamenta flava, causing" A_EndChar),3)
    return
    :B0:Cmp0::
        sendByClipboard(StringUpperFirst("chondromalacia patella" A_EndChar),4)
    return
    :B0:Cmp2::
        sendByClipboard(StringUpperFirst("small cartilage fissure (involving less than 50% thickness) at grade II chondromalacia patella (Shahriaree grading system)" A_EndChar),4)
    return
    :B0:Cmp3::
        sendByClipboard(StringUpperFirst("irregular cartilage thinning and fissuring (involving more than 50% thickness) at grade III chondromalacia patella (Shahriaree grading system)" A_EndChar),4)
    return
    :B0:Cmp4::
        sendByClipboard(StringUpperFirst("full-thickness cartilage defect with exposure of overlying bone at grade IV chondromalacia patella (Shahriaree grading system)" A_EndChar),4)
    return
    :B0:Cppd::
        sendByClipboard(StringUpperFirst("CPPD (Calcium Pyrophosphate Dihydrate Deposition Disease)" A_EndChar),4)
    return
    :B0:Da::
        sendByClipboard(StringUpperFirst("degenerative arthroses" A_EndChar),2)
    return
    :B0:Dac::
        sendByClipboard(StringUpperFirst("degenerative arthrosis of the anterior atlantoaxial joint" A_EndChar),3)
    return
    :B0:Daw::
        sendByClipboard(StringUpperFirst("degenerative arthroses of the distal radioulnar, ulnocarpal and radiocarpal joints" A_EndChar),3)
    return
    :B0:Dbf::
        sendByClipboard(StringUpperFirst("displaced bone fragment" A_EndChar),3)
    return
    :*B0:Dbf1::
        sendByClipboard(StringUpperFirst("displaced bone fragments"),3)
    return
    :B0:Dbp::
        sendByClipboard(StringUpperFirst("distal bone part" A_EndChar),3)
    return
    :*B0:Dbp1::
        sendByClipboard(StringUpperFirst("distal bone parts"),3)
    return
    :B0:Dc::
        sendByClipboard(StringUpperFirst("degenerative change" A_EndChar),2)
    return
    :*B0:Dc1::
        sendByClipboard(StringUpperFirst("degenerative changes"),2)
    return
    :B0:Ddd::
        sendByClipboard(StringUpperFirst("degenerative disc disease" A_EndChar),3)
    return
    :B0:Ddh::
        sendByClipboard(StringUpperFirst("developmental dysplasia of hip" A_EndChar),3)
    return
    :B0:Ddh1::
        sendByClipboard(StringUpperFirst("shallowing of the acetabulum" A_EndChar),4)
    return
    :B0:Ddh2::
        sendByClipboard(StringUpperFirst("mild lateral positioning of femoral head" A_EndChar),4)
    return
    :B0:Ddhb::
        sendByClipboard(StringUpperFirst("shallowing of the acetabulum with relative lateral subluxated femoral head on both sides, suggesting developmental dysplasia of both hips" A_EndChar),4)
    return
    :B0:Ddhl::
        sendByClipboard(StringUpperFirst("shallowing of the acetabulum with relative lateral subluxated femoral head on left side, suggesting developmental dysplasia of hip" A_EndChar),4)
    return
    :B0:Ddhr::
        sendByClipboard(StringUpperFirst("shallowing of the acetabulum with relative lateral subluxated femoral head on right side, suggesting developmental dysplasia of hip" A_EndChar),4)
    return
    :B0:Deh::
        sendByClipboard(StringUpperFirst("dehydrated disc" A_EndChar),3)
    return
    :*B0:Dend::
        sendByClipboard(StringUpperFirst("dehydrated narrowed disc"),3)
    return
    :B0:Dhb::
        sendByClipboard(StringUpperFirst("degenerative arthroses of both hip joints" A_EndChar),3)
    return
    :B0:Dhl::
        sendByClipboard(StringUpperFirst("degenerative arthroses of left hip joint" A_EndChar),3)
    return
    :B0:Dhr::
        sendByClipboard(StringUpperFirst("degenerative arthroses of right hip joint" A_EndChar),3)
    return
    :B0:Dish::
        sendByClipboard(StringUpperFirst("flowing ossification of anterior longitudinal ligament at lower thoracic to upper lumbar spine, diffuse idiopathic skeletal hyperostosis (DISH) is suspected" A_EndChar),4)
    return
    :B0:Disi::
        sendByClipboard(StringUpperFirst("dorsal intercalated-segmental instability" A_EndChar),4)
    return
    :B0:Dll::
        sendByClipboard(StringUpperFirst("decreased lordosis of the lumbar spine" A_EndChar),3)
    return
    :B0:Dpaa::
        sendByClipboard(StringUpperFirst("dorsalis pedis artery" A_EndChar),4)
    return
    :B0:Ds::
        sendByClipboard(StringUpperFirst("degenerative change of spine" A_EndChar),2)
    return
    :B0:Dsd::
        sendByClipboard(StringUpperFirst("degenerative spinal and disc disease" A_EndChar),3)
    return
    :B0:Dsi::
        sendByClipboard(StringUpperFirst("degenerative arthroses of bilateral sacroiliac joints" A_EndChar),3)
    return
    :B0:Dsih::
        sendByClipboard(StringUpperFirst("degenerative arthroses of bilateral sacroiliac and hip joints" A_EndChar),4)
    return
    :B0:Dsihl::
        sendByClipboard(StringUpperFirst("degenerative arthroses of left sacroiliac and hip joints" A_EndChar),5)
    return
    :B0:Dsihr::
        sendByClipboard(StringUpperFirst("degenerative arthroses of right sacroiliac and hip joints" A_EndChar),5)
    return
    :B0:Dsil::
        sendByClipboard(StringUpperFirst("degenerative arthroses of left sacroiliac joint" A_EndChar),4)
    return
    :B0:Dsir::
        sendByClipboard(StringUpperFirst("degenerative arthroses of right sacroiliac joint" A_EndChar),4)
    return
    :B0:Dssi::
        sendByClipboard(StringUpperFirst("lumbar spondylosis and degenerative arthroses of bilateral sacroiliac joints" A_EndChar),4)
    return
    :B0:Dssih::
        sendByClipboard(StringUpperFirst("lumbar spondylosis and degenerative arthroses of bilateral sacroiliac and hip joints" A_EndChar),5)
    return
    :B0:Ec::
        sendByClipboard(StringUpperFirst("endplate change" A_EndChar),2)
    return
    :B0:Ecd::
        sendByClipboard(StringUpperFirst("degenerative endplate change" A_EndChar),3)
    return
    :B0:Ecm::
        sendByClipboard(StringUpperFirst("Modic type" A_EndChar),3)
    return
    :B0:Eh::
        sendByClipboard(StringUpperFirst("edema/hyperemia" A_EndChar),2)
    return
    :B0:Efs::
        sendByClipboard(StringUpperFirst("increased suprapatellar effusion" A_EndChar),3)
    return
    :B0:Efsb::
        sendByClipboard(StringUpperFirst("effusion in the bilateral suprapatellar pouches" A_EndChar),4)
    return
    :B0:Efsbb::
        sendByClipboard(StringUpperFirst("effusion in the bilateral suprapatellar pouches and knee joint spaces" A_EndChar),5)
    return
    :B0:Efsl::
        sendByClipboard(StringUpperFirst("effusion in the left suprapatellar pouch" A_EndChar),4)
    return
    :B0:Efsll::
        sendByClipboard(StringUpperFirst("effusion in the left suprapatellar pouch and knee joint space" A_EndChar),5)
    return
    :B0:Efsr::
        sendByClipboard(StringUpperFirst("effusion in the right suprapatellar pouch" A_EndChar),4)
    return
    :B0:Efsrr::
        sendByClipboard(StringUpperFirst("effusion in the right suprapatellar pouch and knee joint space" A_EndChar),5)
    return
    :B0:Exo::
        sendByClipboard(StringUpperFirst("exostosis" A_EndChar),3)
    return
    :B0:Exec::
        sendByClipboard(StringUpperFirst("except for degenerative endplate change" A_EndChar),4)
    return
    :B0:Exd::
        sendByClipboard(StringUpperFirst("extruding disc" A_EndChar),3)
    return
    :B0:Faa::
        sendByClipboard(StringUpperFirst("anterior angulation of distal bone part" A_EndChar),3)
    return
    :B0:Fad::
        sendByClipboard(StringUpperFirst("dorsal angulation of distal bone part" A_EndChar),3)
    return
    :B0:Fai::
        sendByClipboard(StringUpperFirst("femoro-acetabular impingement" A_EndChar),3)
    return
    :B0:Fal::
        sendByClipboard(StringUpperFirst("lateral (valgus) angulation of distal bone part" A_EndChar),3)
    return
    :B0:Fam::
        sendByClipboard(StringUpperFirst("medial (varus) angulation of distal bone part" A_EndChar),3)
    return
    :B0:Fap::
        sendByClipboard(StringUpperFirst("posterior angulation of distal bone part" A_EndChar),3)
    return
    :B0:Fav::
        sendByClipboard(StringUpperFirst("volar angulation of distal bone part" A_EndChar),3)
    return
    :B0:Fc::
        sendByClipboard(StringUpperFirst("comminuted fracture" A_EndChar),2)
    return
    :B0:Fcas::
        sendByClipboard(StringUpperFirst("femoral condylar articular surface" A_EndChar),4)
    return
    :B0:Fcd::
        sendByClipboard(StringUpperFirst("comminuted displaced fracture" A_EndChar),3)
    return
    :B0:Fcdi::
        sendByClipboard(StringUpperFirst("comminuted displaced impacted fracture" A_EndChar),4)
    return
    :B0:Fcdia::
        sendByClipboard(StringUpperFirst("comminuted displaced intra-articular fracture" A_EndChar),5)
    return
    :B0:Fcdiia::
        sendByClipboard(StringUpperFirst("comminuted displaced intra-articular fracture" A_EndChar),6)
    return
    :B0:Fci::
        sendByClipboard(StringUpperFirst("comminuted impacted fracture" A_EndChar),3)
    return
    :B0:Fcia::
        sendByClipboard(StringUpperFirst("comminuted intraarticular fracture" A_EndChar),4)
    return
    :B0:Fciia::
        sendByClipboard(StringUpperFirst("comminuted impacted intra-articular fracture" A_EndChar),5)
    return
    :B0:Fcll::
        sendByClipboard(StringUpperFirst("fibular collateral ligament" A_EndChar),4)
    return
    :B0:Fcp::
        sendByClipboard(StringUpperFirst("complex fracture" A_EndChar),3)
    return
    :B0:Fd::
        sendByClipboard(StringUpperFirst("displaced fracture" A_EndChar),2)
    return
    :B0:Fda::
        sendByClipboard(StringUpperFirst("anterior displacement of distal bone part" A_EndChar),3)
    return
    :B0:Fdd::
        sendByClipboard(StringUpperFirst("dorsal displacement of distal bone part" A_EndChar),3)
    return
    :B0:Fdi::
        sendByClipboard(StringUpperFirst("displaced impacted fracture" A_EndChar),3)
    return
    :B0:Fdia::
        sendByClipboard(StringUpperFirst("displaced intra-articular fracture" A_EndChar),4)
    return
    :B0:Fdis::
        sendByClipboard(StringUpperFirst("distraction of bone parts" A_EndChar),4)
    return
    :B0:Fdiia::
        sendByClipboard(StringUpperFirst("displaced impacted intra-articular fracture" A_EndChar),5)
    return
    :B0:Fdl::
        sendByClipboard(StringUpperFirst("lateral displacement of distal bone part" A_EndChar),3)
    return
    :B0:Fdm::
        sendByClipboard(StringUpperFirst("medial displacement of distal bone part" A_EndChar),3)
    return
    :B0:Fdp::
        sendByClipboard(StringUpperFirst("posterior displacement of distal bone part" A_EndChar),3)
    return
    :B0:Fdv::
        sendByClipboard(StringUpperFirst("volar displacement of distal bone part" A_EndChar),3)
    return
    :B0:Fe::
        sendByClipboard(StringUpperFirst("neural foraminal encroachment" A_EndChar),2)
    return
    :B0:Fel::
        sendByClipboard(StringUpperFirst("encroachment to the left neural foramen" A_EndChar),3)
    return
    :B0:Fer::
        sendByClipboard(StringUpperFirst("encroachment to the right neural foramen" A_EndChar),3)
    return
    :B0:Fh::
        sendByClipboard(StringUpperFirst("healed fracture" A_EndChar),2)
    return
    :B0:Fhh::
        sendByClipboard(StringUpperFirst("healing fracture" A_EndChar),3)
    return
    :B0:Fho::
        sendByClipboard(StringUpperFirst("healed oblique fracture" A_EndChar),3)
    return
    :B0:Fhs::
        sendByClipboard(StringUpperFirst("healed spiral fracture" A_EndChar),3)
    return
    :B0:Fht::
        sendByClipboard(StringUpperFirst("healed transverse fracture" A_EndChar),3)
    return
    :B0:Fia::
        sendByClipboard(StringUpperFirst("intra-articular fracture" A_EndChar),3)
    return
    :B0:Fiia::
        sendByClipboard(StringUpperFirst("impacted intraarticular fracture" A_EndChar),4)
    return
    :B0:Fja::
        sendByClipboard(StringUpperFirst("facet joint arthroses" A_EndChar),3)
    return
    :B0:Fjal::
        sendByClipboard(StringUpperFirst("facet joint arthroses at lower levels" A_EndChar),4)
    return
    :B0:Fn::
        sendByClipboard(StringUpperFirst("neural foraminal narrowing" A_EndChar),2)
    return
    :B0:Fo::
        sendByClipboard(StringUpperFirst("previous oblique fracture" A_EndChar),2)
    return
    :B0:Fover::
        sendByClipboard(StringUpperFirst("overriding of fracture ends" A_EndChar),5)
    return
    :B0:Fr::
        sendByClipboard(StringUpperFirst("rotation of distal fragment" A_EndChar),2)
    return
    :B0:Fsi::
        sendByClipboard(StringUpperFirst("fat-supressed images" A_EndChar),3)
    return
    :B0:Ft::
        sendByClipboard(StringUpperFirst("previous transverse fracture" A_EndChar),2)
    return
    :B0:Hlf::
        sendByClipboard(StringUpperFirst("hypertrophic ligamenta flava" A_EndChar),3)
    return
    :B0:Hv::
        sendByClipboard(StringUpperFirst("hallux valgus" A_EndChar),2)
    return
    :B0:Ixt::
        sendByClipboard(StringUpperFirst("intraarticular extention to" A_EndChar),3)
    return
    :B0:Ibfu::
        sendByClipboard(StringUpperFirst("interbody fusion" A_EndChar),4)
    return
    :B0:Ifar::
        sendByClipboard(StringUpperFirst("inflammatory arthritis" A_EndChar),4)
    return
    :B0:Imp::
        sendByClipboard(StringUpperFirst("shoulder impingement" A_EndChar),3)
    return
    :B0:Impl::
        sendByClipboard(StringUpperFirst("lateral downsloping and lowlying of left acromion with subacromial spur formation and narrowed subacromial space, suggestive of shoulder impingment." A_EndChar),4)
    return
    :B0:Impr::
        sendByClipboard(StringUpperFirst("lateral downsloping and lowlying of right acromion with subacromial spur formation and narrowed subacromial space, suggestive of shoulder impingment." A_EndChar),4)
    return
    :B0:Tsi::
        sendByClipboard(StringUpperFirst("adjacent thecal sac indentation" A_EndChar),3)
    return
    :B0:Inj::
        sendByClipboard(StringUpperFirst("multiple calcified injection granulomas over bilateral buttocks" A_EndChar),3)
    return
    :B0:Isb::
        sendByClipboard(StringUpperFirst("intrasubstance" A_EndChar),3)
    return
    :B0:Istt::
        sendByClipboard(StringUpperFirst("infraspinatus tendon" A_EndChar),4)
    return
    :B0:Jac::
        sendByClipboard(StringUpperFirst("acromioclavicular joint" A_EndChar),3)
    return
    :*B0:Jac1::
        sendByClipboard(StringUpperFirst("acromioclavicular joints"),3)
    return
    :B0:Jca::
        sendByClipboard(StringUpperFirst("patellofemoral joint compartment" A_EndChar),3)
    return
    :*B0:Jca1::
        sendByClipboard(StringUpperFirst("patellofemoral joint compartments"),3)
    return
    :B0:Jcaa::
        sendByClipboard(StringUpperFirst("all joint compartment" A_EndChar),4)
    return
    :*B0:Jcaa1::
        sendByClipboard(StringUpperFirst("all joint compartments"),4)
    return
    :B0:Jcal::
        sendByClipboard(StringUpperFirst("patellofemoral and lateral joint comparment" A_EndChar),4)
    return
    :*B0:Jcal1::
        sendByClipboard(StringUpperFirst("patellofemoral and lateral joint comparments"),4)
    return
    :B0:Jcam::
        sendByClipboard(StringUpperFirst("patellofemoral and medial joint compartment" A_EndChar),4)
    return
    :*B0:Jcam1::
        sendByClipboard(StringUpperFirst("patellofemoral and medial joint compartments"),4)
    return
    :B0:Jcb::
        sendByClipboard(StringUpperFirst("all joint compartments of both knee joints" A_EndChar),3)
    return
    :B0:Jcc::
        sendByClipboard(StringUpperFirst("calcaneocuboid joint" A_EndChar),3)
    return
    :*B0:Jcc1::
        sendByClipboard(StringUpperFirst("calcaneocuboid joints"),3)
    return
    :B0:Jcl::
        sendByClipboard(StringUpperFirst("lateral joint compartment" A_EndChar),3)
    return
    :*B0:Jcl1::
        sendByClipboard(StringUpperFirst("lateral joint compartments"),3)
    return
    :B0:Jcm::
        sendByClipboard(StringUpperFirst("medial joint compartment" A_EndChar),3)
    return
    :*B0:Jcm1::
        sendByClipboard(StringUpperFirst("medial joint compartments"),3)
    return
    :B0:Jcmc::
        sendByClipboard(StringUpperFirst("carpometacarpal joint" A_EndChar),4)
    return
    :*B0:Jcmc1::
        sendByClipboard(StringUpperFirst("carpometacarpal joints"),4)
    return
    :B0:Jcml::
        sendByClipboard(StringUpperFirst("medial and lateral joint compartment" A_EndChar),4)
    return
    :*B0:Jcml1::
        sendByClipboard(StringUpperFirst("medial and lateral joint compartments"),4)
    return
    :B0:Jd::
        sendByClipboard(StringUpperFirst("junction of middle and distal thirds of" A_EndChar),2)
    return
    :B0:Jdip::
        sendByClipboard(StringUpperFirst("distal interphalangeal joint" A_EndChar),4)
    return
    :*B0:Jdip1::
        sendByClipboard(StringUpperFirst("distal interphalangeal joints"),4)
    return
    :B0:Jft::
        sendByClipboard(StringUpperFirst("femorotibial joint" A_EndChar),3)
    return
    :*B0:Jft1::
        sendByClipboard(StringUpperFirst("femorotibial joints"),3)
    return
    :B0:Jgh::
        sendByClipboard(StringUpperFirst("glenohumeral joint" A_EndChar),3)
    return
    :*B0:Jgh1::
        sendByClipboard(StringUpperFirst("glenohumeral joints"),3)
    return
    :B0:Jhr::
        sendByClipboard(StringUpperFirst("humeroradial joint" A_EndChar),3)
    return
    :*B0:Jhr1::
        sendByClipboard(StringUpperFirst("humeroradial joints"),3)
    return
    :B0:Jhu::
        sendByClipboard(StringUpperFirst("humeroulnar joint" A_EndChar),3)
    return
    :*B0:Jhu1::
        sendByClipboard(StringUpperFirst("humeroulnar joints"),3)
    return
    :B0:Jip::
        sendByClipboard(StringUpperFirst("interphalangeal joint" A_EndChar),3)
    return
    :*B0:Jip1::
        sendByClipboard(StringUpperFirst("interphalangeal joints"),3)
    return
    :B0:Jipf::
        sendByClipboard(StringUpperFirst("interphalangeal joint(s) of thumb(s) and some distal interphalangeal joint(s) of finger(s)" A_EndChar),4)
    return
    :B0:Jipff::
        sendByClipboard(StringUpperFirst("interphalangeal joint(s) of thumb(s) and some distal interphalangeal and proximal interphalangeal joint(s) of finger(s)" A_EndChar),5)
    return
    :B0:Jipt::
        sendByClipboard(StringUpperFirst("interphalangeal joint(s) of big toe(s) and some distal interphalangeal joint(s) of toe(s)" A_EndChar),4)
    return
    :B0:Jiptt::
        sendByClipboard(StringUpperFirst("interphalangeal joint(s) of big toe(s) and some distal interphalangeal and proximal interphalangeal joint(s) of toe(s)" A_EndChar),5)
    return
    :B0:Jk::
        sendByClipboard(StringUpperFirst("knee joint" A_EndChar),2)
    return
    :*B0:Jk1::
        sendByClipboard(StringUpperFirst("knee joints"),2)
    return
    :B0:Jkb::
        sendByClipboard(StringUpperFirst("both knee joint" A_EndChar),3)
    return
    :*B0:Jkb1::
        sendByClipboard(StringUpperFirst("both knee joints"),3)
    return
    :B0:Jkl::
        sendByClipboard(StringUpperFirst("left knee joint" A_EndChar),3)
    return
    :B0:Jkr::
        sendByClipboard(StringUpperFirst("right knee joint" A_EndChar),3)
    return
    :B0:Jmc::
        sendByClipboard(StringUpperFirst("mid-carpal joint" A_EndChar),3)
    return
    :*B0:Jmc1::
        sendByClipboard(StringUpperFirst("mid-carpal joints"),3)
    return
    :B0:Jmp::
        sendByClipboard(StringUpperFirst("metacarpophalangeal joint" A_EndChar),3)
    return
    :*B0:Jmp1::
        sendByClipboard(StringUpperFirst("metacarpophalangeal joints"),3)
    return
    :B0:Jmt::
        sendByClipboard(StringUpperFirst("metatarsophalangeal joint" A_EndChar),3)
    return
    :*B0:Jmt1::
        sendByClipboard(StringUpperFirst("metatarsophalangeal joints"),3)
    return
    :B0:Jj::
        sendByClipboard(StringUpperFirst("no obvious bony fracture; no evidence of joint subluxation or dislocation; suggest clinical correlation." A_EndChar),2)
    return
    :B0:Jo::
        sendByClipboard(StringUpperFirst("no obvious bony fracture or destructive lesion; no evidence of joint subluxation or dislocation; suggest clinical correlation." A_EndChar),2)
    return
    :B0:Joo::
        sendByClipboard(StringUpperFirst("no obvious bony fracture or destructive lesion; no evidence of joint subluxation or dislocation; however, small bone fracture or lesion may not be detected by the plain radiography." A_EndChar),3)
    return
    :B0:Jp::
        sendByClipboard(StringUpperFirst("junction of proximal and middle thirds of" A_EndChar),2)
    return
    :B0:Jpf::
        sendByClipboard(StringUpperFirst("patellofemoral joint" A_EndChar),3)
    return
    :*B0:Jpf1::
        sendByClipboard(StringUpperFirst("patellofemoral joints"),3)
    return
    :B0:Jpip::
        sendByClipboard(StringUpperFirst("proximal interphalangeal joint" A_EndChar),4)
    return
    :*B0:Jpip1::
        sendByClipboard(StringUpperFirst("proximal interphalangeal joints"),4)
    return
    :B0:Jrc::
        sendByClipboard(StringUpperFirst("radiocarpal joint" A_EndChar),3)
    return
    :*B0:Jrc1::
        sendByClipboard(StringUpperFirst("radiocarpal joints"),3)
    return
    :B0:Jru::
        sendByClipboard(StringUpperFirst("radioulnar joint" A_EndChar),3)
    return
    :*B0:Jru1::
        sendByClipboard(StringUpperFirst("radioulnar joints"),3)
    return
    :B0:Druj::
        sendByClipboard(StringUpperFirst("distal radioulnar joint" A_EndChar),4)
    return
    :*B0:Druj1::
        sendByClipboard(StringUpperFirst("distal radioulnar joints"),4)
    return
    :B0:Pruj::
        sendByClipboard(StringUpperFirst("proximal radioulnar joint" A_EndChar),4)
    return
    :*B0:Pruj1::
        sendByClipboard(StringUpperFirst("proximal radioulnar joints"),4)
    return
    :B0:Ptl::
        sendByClipboard(StringUpperFirst("patella" A_EndChar),3)
    return
    :B0:Lpt::
        sendByClipboard(StringUpperFirst("lateral patellar tilt" A_EndChar),3)
    return
    :B0:Jsi::
        sendByClipboard(StringUpperFirst("sacroiliac joint" A_EndChar),3)
    return
    :*B0:Jsi1::
        sendByClipboard(StringUpperFirst("sacroiliac joints"),3)
    return
    :B0:Jst::
        sendByClipboard(StringUpperFirst("subtalar joint" A_EndChar),3)
    return
    :*B0:Jst1::
        sendByClipboard(StringUpperFirst("subtalar joints"),3)
    return
    :B0:Jt::
        sendByClipboard(StringUpperFirst("joint" A_EndChar),2)
    return
    :*B0:Jt1::
        sendByClipboard(StringUpperFirst("joints"),2)
    return
    :B0:Jtts::
        sendByClipboard(StringUpperFirst("trapzium-trapzoid-scaphoid joint" A_EndChar),4)
    return
    :*B0:Jtts1::
        sendByClipboard(StringUpperFirst("trapzium-trapzoid-scaphoid joints"),4)
    return
    :B0:Jtm::
        sendByClipboard(StringUpperFirst("temporomandibular joint" A_EndChar),3)
    return
    :*B0:Jtm1::
        sendByClipboard(StringUpperFirst("temporomandibular joints"),3)
    return
    :B0:Jtmt::
        sendByClipboard(StringUpperFirst("tarsometatarsal joint" A_EndChar),4)
    return
    :*B0:Jtmt1::
        sendByClipboard(StringUpperFirst("tarsometatarsal joints"),4)
    return
    :B0:Jtn::
        sendByClipboard(StringUpperFirst("talonavicular joint" A_EndChar),3)
    return
    :*B0:Jtn1::
        sendByClipboard(StringUpperFirst("talonavicular joints"),3)
    return
    :B0:Jtt::
        sendByClipboard(StringUpperFirst("tibiotalar joint" A_EndChar),3)
    return
    :*B0:Jtt1::
        sendByClipboard(StringUpperFirst("tibiotalar joints"),3)
    return
    :B0:Juc::
        sendByClipboard(StringUpperFirst("ulnocarpal joint" A_EndChar),3)
    return
    :*B0:Juc1::
        sendByClipboard(StringUpperFirst("ulnocarpal joints"),3)
    return
    :B0:Ksc::
        sendByClipboard(StringUpperFirst("kyphoscoliosis" A_EndChar),3)
    return
    :B0:Ky::
        sendByClipboard(StringUpperFirst("kyphosis" A_EndChar),2)
    return
    :B0:Lank::
        sendByClipboard(StringUpperFirst("anterior talofibular ligament, posterior talofibular ligament, and calcaneofibular ligament" A_EndChar),4)
    return
    :B0:Latf::
        sendByClipboard(StringUpperFirst("anterior talofibular ligament" A_EndChar),4)
    return
    :B0:Lptf::
        sendByClipboard(StringUpperFirst("posterior talofibular ligament" A_EndChar),4)
    return
    :*B0:Aitfl::
        sendByClipboard(StringUpperFirst("anterior inferior tibiofibular ligament"),4)
    return
    :*B0:Pitfl::
        sendByClipboard(StringUpperFirst("posterior inferior tibiofibular ligament"),4)
    return
    :B0:Lbd::
        sendByClipboard(StringUpperFirst("loose body" A_EndChar),3)
    return
    :B0:Lbd1::
        sendByClipboard(StringUpperFirst("loose bodies" A_EndChar),4)
    return
    :B0:Lcf::
        sendByClipboard(StringUpperFirst("calcaneofibular ligament" A_EndChar),3)
    return
    :B0:Lcpd::
        sendByClipboard(StringUpperFirst("Legg-Calve-Perthes disease" A_EndChar),4)
    return
    :B0:Lex::
        sendByClipboard(StringUpperFirst("lower extremities" A_EndChar),3)
    return
    :B0:Lhbt::
        sendByClipboard(StringUpperFirst("long head of biceps tendon" A_EndChar),4)
    return
    :B0:Lrs::
        sendByClipboard(StringUpperFirst("lateral recess stenosis" A_EndChar),3)
    return
    :B0:Leom::
        sendByClipboard(StringUpperFirst("medial malleolus" A_EndChar),4)
    return
    :B0:Leol::
        sendByClipboard(StringUpperFirst("lateral malleolus" A_EndChar),4)
    return
    :B0:Mcll::
        sendByClipboard(StringUpperFirst("medial collateral ligament" A_EndChar),4)
    return
    :B0:Mcl1::
        sendByClipboard(StringUpperFirst("grade 1 signal (suggesting sprain or minimal tear) of the MCL" A_EndChar),4)
    return
    :B0:Mcl2::
        sendByClipboard(StringUpperFirst("grade 2 signal (suggesting partial tear) of the MCL" A_EndChar),4)
    return
    :B0:Mcl3::
        sendByClipboard(StringUpperFirst("grade 3 signal (suggesting complete tear) of the MCL" A_EndChar),4)
    return
    :B0:Md1::
        sendByClipboard(StringUpperFirst("bulging disc at posterior central aspect of L4-5 and causes intentation of the adjacent thecal sac" A_EndChar),3)
    return
    :B0:Md2::
        sendByClipboard(StringUpperFirst("protruding disc at posterior central aspect of the L4-5 and causes indentation of the adjacent thecal sac" A_EndChar),3)
    return
    :B0:Mdd::
        sendByClipboard(StringUpperFirst("degenerative change with dehydrated discs at multi-levels" A_EndChar),3)
    return
    :B0:Menm::
        sendByClipboard(StringUpperFirst("medial meniscus" A_EndChar),4)
    return
    :B0:Menl::
        sendByClipboard(StringUpperFirst("lateral meniscus" A_EndChar),4)
    return
    :B0:Menb::
        sendByClipboard(StringUpperFirst("medial and lateral meniscii" A_EndChar),4)
    return
    :B0:Men1::
        sendByClipboard(StringUpperFirst("short intrasubstance linear (or nodular) high SI on coronal GRE T2WI without extention to the capsular periphery or the articular surface at grade 1 signal (suggesting early intrasubstance degeneration)" A_EndChar),4)
    return
    :B0:Men2::
        sendByClipboard(StringUpperFirst("horizontal linear high SI on coronal GRE T2WI with extention to the capsular periphery and without involvement of the articular surface at grade 2 signal (suggesting intrasubstance degeneration)" A_EndChar),4)
    return
    :B0:Ment::
        sendByClipboard(StringUpperFirst("meniscal tear" A_EndChar),4)
    return
    :*B0:Ment1::
        sendByClipboard(StringUpperFirst("meniscal tears"),4)
    return
    :B0:Mf::
        sendByClipboard(StringUpperFirst("multifocal" A_EndChar),2)
    return
    :B0:Mhe1::
        sendByClipboard(StringUpperFirst("small well-defined lesion of homogeneous high SI on both T1WI and T2WI at L4, considered vertebral hemangioma first." A_EndChar),4)
    return
    :B0:Vth::
        sendByClipboard(StringUpperFirst("vertebral hemangioma" A_EndChar),3)
    return
    :*B0:Vth1::
        sendByClipboard(StringUpperFirst("vertebral hemangiomas"),3)
    return
    :B0:Mhe2::
        sendByClipboard(StringUpperFirst("several varying-sized well-defined lesions of homogeneous high SI on both T1WI and T2WI at lumbar vertebrae, considered vertebral hemangiomas first." A_EndChar),4)
    return
    :B0:Mi3::
        sendByClipboard(StringUpperFirst("middle third" A_EndChar),3)
    return
    :B0:Mrmet::
        sendByClipboard(StringUpperFirst("multifocal varying-sized patchy and nodular marrow lesions of abnormal SI and enhancement at" A_EndChar),5)
    return
    :B0:Myelo::
        sendByClipboard(StringUpperFirst("Myelography of the lumbar spine with injection of non-ionic contrast medium via L2-3 level was performed smoothly and it shows:" A_EndChar),5)
    return
    :B0:Myeloct::
        sendByClipboard(StringUpperFirst("Myelo-CT study of lumbar spine with intrathecal injection of non-ionic contrast shows:>" A_EndChar),7)
    return
    :B0:Fba::
        sendByClipboard(StringUpperFirst("fine bony alignment" A_EndChar),3)
    return
    :B0:Ndh::
        sendByClipboard(StringUpperFirst("fine disc hydration" A_EndChar),3)
    return
    :B0:Nf::
        sendByClipboard(StringUpperFirst("no obvious bony fracture" A_EndChar),2)
    return
    :B0:Nds::
        sendByClipboard(StringUpperFirst("the disc spaces are acceptable" A_EndChar),3)
    return
    :B0:Njs::
        sendByClipboard(StringUpperFirst("the joint spaces are within normal limit" A_EndChar),3)
    return
    :B0:Nl::
        sendByClipboard(StringUpperFirst("no evidence of joint subluxation or dislocation" A_EndChar),2)
    return
    :B0:Nrc::
        sendByClipboard(StringUpperFirst("nerve root compression" A_EndChar),3)
    return
    :B0:Nsi::
        sendByClipboard(StringUpperFirst("normal morphology of the bilateral sacroiliac joints" A_EndChar),3)
    return
    :B0:Nuv::
        sendByClipboard(StringUpperFirst("negative ulnar variance" A_EndChar),3)
    return
    :B0:Oa::
        sendByClipboard(StringUpperFirst("osteoarthritis" A_EndChar),2)
    return
    :B0:Oaa::
        sendByClipboard(StringUpperFirst("osteoarthritic change" A_EndChar),3)
    return
    :B0:Oa1::
        sendByClipboard(StringUpperFirst("minimal osteoarthritis" A_EndChar),3)
    return
    :B0:Oa12::
        sendByClipboard(StringUpperFirst("minimal to mild osteoarthritis" A_EndChar),4)
    return
    :B0:Oa2::
        sendByClipboard(StringUpperFirst("mild osteoarthritis" A_EndChar),3)
    return
    :B0:Oa23::
        sendByClipboard(StringUpperFirst("mild to moderate osteoarthritis" A_EndChar),4)
    return
    :B0:Oa3::
        sendByClipboard(StringUpperFirst("moderate osteoarthritis" A_EndChar),3)
    return
    :B0:Oa34::
        sendByClipboard(StringUpperFirst("moderate to severe osteoarthritis" A_EndChar),4)
    return
    :B0:Oa4::
        sendByClipboard(StringUpperFirst("severe osteoarthritis" A_EndChar),3)
    return
    :B0:Oa11::
        sendByClipboard(StringUpperFirst("minimal osteoarthritis with tiny marginal osteophyte(s) at" A_EndChar),4)
    return
    :B0:Oa122::
        sendByClipboard(StringUpperFirst("mild osteoarthritis with tiny or small marginal osteophyte(s) at" A_EndChar),5)
    return
    :B0:Oa22::
        sendByClipboard(StringUpperFirst("mild osteoarthritis with small marginal osteophyte(s) at" A_EndChar),4)
    return
    :B0:Oa233::
        sendByClipboard(StringUpperFirst("mild to moderate osteoarthritis with marginal osteophyte(s) and mild joint space narrowing at" A_EndChar),5)
    return
    :B0:Oa33::
        sendByClipboard(StringUpperFirst("moderate osteoarthritis with marginal osteophyte(s) and joint space narrowing at" A_EndChar),4)
    return
    :B0:Oa344::
        sendByClipboard(StringUpperFirst("moderate to severe osteoarthritis with marginal osteophyte(s), joint space narrowing, and mild uneven articular surface at" A_EndChar),5)
    return
    :B0:Oaa4::
        sendByClipboard(StringUpperFirst("severe osteoarthritis with large marginal osteophyte(s), joint space narrowing, and uneven articular surface at" A_EndChar),4)
    return
    :B0:Oaank::
        sendByClipboard(StringUpperFirst("osteoarthritis at the tibiotalar joint, subtalar joint, and midtarsal joints" A_EndChar),5)
    return
    :B0:Oaf1::
        sendByClipboard(StringUpperFirst("osteoarthritis at interphalangeal joint(s) of thumb(s) and some distal interphalangeal joint(s) of finger(s)" A_EndChar),4)
    return
    :B0:Oaf2::
        sendByClipboard(StringUpperFirst("osteoarthritis at interphalangeal joint(s) of thumb(s) and some distal interphalangeal and proximal interphalangeal joint(s) of finger(s)" A_EndChar),4)
    return
    :B0:Oat1::
        sendByClipboard(StringUpperFirst("osteoarthritis at interphalangeal joint(s) of big toe(s) and some distal interphalangeal joint(s) of toe(s)" A_EndChar),4)
    return
    :B0:Oat2::
        sendByClipboard(StringUpperFirst("osteoarthritis at interphalangeal joint(s) of big toe(s) and some distal interphalangeal and proximal interphalangeal joint(s) of toe(s)" A_EndChar),4)
    return
    :B0:Oaba::
        sendByClipboard(StringUpperFirst("osteoarthritic change at all joint compartments, more at patellofemoral joint compartments, of both knee joints" A_EndChar),4)
    return
    :B0:Oacl::
        sendByClipboard(StringUpperFirst("status post anterior cruciate ligament reconstruction with presence of tibial and femoral tunnels and metallic prostheses at distal femur and proximal tibia; fine alignment of the femorotibial joint and postOP change around the knee joint; suggest follow up study." A_EndChar),4)
    return
    :B0:Oah::
        sendByClipboard(StringUpperFirst("osteoarthritic change of both hip joints" A_EndChar),3)
    return
    :B0:Oahr::
        sendByClipboard(StringUpperFirst("osteoarthritic change of right hip joint" A_EndChar),4)
    return
    :B0:Oahl::
        sendByClipboard(StringUpperFirst("osteoarthritic change of left hip joint" A_EndChar),4)
    return
    :B0:Oal::
        sendByClipboard(StringUpperFirst("osteoarthritic change at all joint compartments of left knee joint" A_EndChar),3)
    return
    :B0:Oala::
        sendByClipboard(StringUpperFirst("osteoarthritic change at all joint compartments, more at patellofemoral joint compartment, of left knee joint" A_EndChar),4)
    return
    :B0:Oalb::
        sendByClipboard(StringUpperFirst("the joint spaces are more narrowed at both lateral joint compartments and cause valgus deformity of both knee joints" A_EndChar),4)
    return
    :B0:Oall::
        sendByClipboard(StringUpperFirst("the joint space is more narrowed at lateral joint compartment and causes valgus deformity of left knee joint" A_EndChar),4)
    return
    :B0:Oalr::
        sendByClipboard(StringUpperFirst("the joint space is more narrowed at lateral joint compartment and causes valgus deformity of right knee joint" A_EndChar),4)
    return
    :B0:Oamb::
        sendByClipboard(StringUpperFirst("the joint spaces are more narrowed at both medial joint compartments and cause varus deformity of both knee joints" A_EndChar),4)
    return
    :B0:Oaml::
        sendByClipboard(StringUpperFirst("the joint space is more narrowed at medial joint compartment and causes varus deformity of left knee joint" A_EndChar),4)
    return
    :B0:Oamr::
        sendByClipboard(StringUpperFirst("the joint space is more narrowed at medial joint compartment and causes varus deformity of right knee joint" A_EndChar),4)
    return
    :B0:Oap::
        sendByClipboard(StringUpperFirst("osteoarthritic change at the patellofemoral joint" A_EndChar),3)
    return
    :B0:Oar::
        sendByClipboard(StringUpperFirst("osteoarthritic change at all joint compartments of right knee joint" A_EndChar),3)
    return
    :B0:Oara::
        sendByClipboard(StringUpperFirst("osteoarthritic change at all joint compartments, more at patellofemoral joint compartment, of right knee joint" A_EndChar),4)
    return
    :B0:Obg::
        sendByClipboard(StringUpperFirst("bone grafting" A_EndChar),3)
    return
    :B0:Obi::
        sendByClipboard(StringUpperFirst("external immobilization" A_EndChar),3)
    return
    :B0:Obp::
        sendByClipboard(StringUpperFirst("status post blade plate and screw fixation" A_EndChar),3)
    return
    :B0:Oc::
        sendByClipboard(StringUpperFirst("external cast or splint application" A_EndChar),2)
    return
    :B0:Oc1::
        sendByClipboard(StringUpperFirst("status post external cast or splint application; the detail of bones is obliterated by artifacts of the cast or splint" A_EndChar),3)
    return
    :B0:Ocdd::
        sendByClipboard(StringUpperFirst("osteochondrosis" A_EndChar),4)
    return
    :B0:Oci::
        sendByClipboard(StringUpperFirst("patchy sclerotic change over lower poles of bilateral sacroiliac joints, suggesting osteitis condensans ilii" A_EndChar),3)
    return
    :B0:Oddh1::
        sendByClipboard(StringUpperFirst("acetabuloplasty" A_EndChar),5)
    return
    :B0:Oddh2::
        sendByClipboard(StringUpperFirst("varus osteotomy" A_EndChar),5)
    return
    :B0:Odp::
        sendByClipboard(StringUpperFirst("status post dynamic compression plate and screw fixation" A_EndChar),3)
    return
    :B0:Ods::
        sendByClipboard(StringUpperFirst("status post dynamic compression screw fixation" A_EndChar),3)
    return
    :B0:Oe::
        sendByClipboard(StringUpperFirst("status post external fixator application" A_EndChar),2)
    return
    :B0:Oeb::
        sendByClipboard(StringUpperFirst("status post external bandage with radiopaque artifacts and some detail of bones is obliterated" A_EndChar),3)
    return
    :B0:Oei::
        sendByClipboard(StringUpperFirst("status post external immobilization" A_EndChar),3)
    return
    :B0:Ofc::
        sendByClipboard(StringUpperFirst("status post calcaneal lengthening" A_EndChar),3)
    return
    :B0:Ofn::
        sendByClipboard(StringUpperFirst("posterior tibialis tendon transfer" A_EndChar),3)
    return
    :B0:Ofs::
        sendByClipboard(StringUpperFirst("status post subtalar arthroereisis" A_EndChar),3)
    return
    :B0:Oft::
        sendByClipboard(StringUpperFirst("talonavicular stapling" A_EndChar),3)
    return
    :B0:Ohb::
        sendByClipboard(StringUpperFirst("status post arthroplasty at both hip joints" A_EndChar),3)
    return
    :B0:Ohhb::
        sendByClipboard(StringUpperFirst("status post hemiarthroplasty at both hip joints" A_EndChar),4)
    return
    :B0:Ohhl::
        sendByClipboard(StringUpperFirst("status post hemiarthroplasty at left hip joint" A_EndChar),4)
    return
    :B0:Ohhr::
        sendByClipboard(StringUpperFirst("status post hemiarthroplasty at right hip joint" A_EndChar),4)
    return
    :B0:Ohl::
        sendByClipboard(StringUpperFirst("status post arthroplasty at left hip joint" A_EndChar),3)
    return
    :B0:Ohr::
        sendByClipboard(StringUpperFirst("status post arthroplasty at right hip joint" A_EndChar),3)
    return
    :B0:Oii::
        sendByClipboard(StringUpperFirst("status post internal (metallic) fixation" A_EndChar),3)
    return
    :B0:Oib::
        sendByClipboard(StringUpperFirst("interbody fusion at" A_EndChar),3)
    return
    :B0:Oif::
        sendByClipboard(StringUpperFirst("status post interbody fusion at" A_EndChar),3)
    return
    :B0:Oin::
        sendByClipboard(StringUpperFirst("status post intramedullary nail and interlocking screw fixation" A_EndChar),3)
    return
    :B0:Oip::
        sendByClipboard(StringUpperFirst("status post metallic pin fixation" A_EndChar),3)
    return
    :B0:Oir::
        sendByClipboard(StringUpperFirst("status post intramedullary rod insertion" A_EndChar),3)
    return
    :B0:Okb::
        sendByClipboard(StringUpperFirst("status post total knee arthroplasty at both knee joints" A_EndChar),3)
    return
    :B0:Okbb::
        sendByClipboard(StringUpperFirst("status post total knee arthroplasty at both knee joints with fine alignment and soft tissue swelling at anterior aspects; suggest clinical correlation." A_EndChar),4)
    return
    :B0:Okl::
        sendByClipboard(StringUpperFirst("status post total knee arthroplasty at left knee joint" A_EndChar),3)
    return
    :B0:Okll::
        sendByClipboard(StringUpperFirst("status post total knee arthroplasty at left knee joint with fine alignment and soft tissue swelling at anterior aspect; suggest clinical correlation." A_EndChar),4)
    return
    :B0:Okr::
        sendByClipboard(StringUpperFirst("status post total knee arthroplasty at right knee joint" A_EndChar),3)
    return
    :B0:Okrr::
        sendByClipboard(StringUpperFirst("status post total knee arthroplasty at right knee joint with fine alignment and soft tissue swelling at anterior aspect; suggest clinical correlation." A_EndChar),4)
    return
    :B0:Oksl::
        sendByClipboard(StringUpperFirst("status post limb salvage at left distal femur with long stem knee arthroplasty at left knee joint" A_EndChar),4)
    return
    :B0:Oksr::
        sendByClipboard(StringUpperFirst("status post limb salvage at left distal femur with long stem knee arthroplasty at right knee joint" A_EndChar),4)
    return
    :B0:Okw::
        sendByClipboard(StringUpperFirst("status post K-wire fixation" A_EndChar),3)
    return
    :B0:Omp::
        sendByClipboard(StringUpperFirst("status post metallic plate and screw fixation" A_EndChar),3)
    return
    :B0:Oms::
        sendByClipboard(StringUpperFirst("status post metallic screw fixation" A_EndChar),3)
    return
    :B0:Omw::
        sendByClipboard(StringUpperFirst("metallic wire fixation" A_EndChar),3)
    return
    :B0:Onn::
        sendByClipboard(StringUpperFirst("intravertebral vacuum, suggesting osteonecrosis" A_EndChar),3)
    return
    :B0:Ons::
        sendByClipboard(StringUpperFirst("decreased height(s) with suspect intravertebral vacuum, suggesting osteonecrosis, at" A_EndChar),3)
    return
    :B0:Opv::
        sendByClipboard(StringUpperFirst("osteopenic change of visible bones" A_EndChar),3)
    return
    :B0:Opcl::
        sendByClipboard(StringUpperFirst("status post posterior cruciate ligament reconstruction with presence of tibial and femoral tunnels; fine alignment of the femorotibial joint and postOP change around the knee joint; suggest follow up study." A_EndChar),4)
    return
    :B0:Opd::
        sendByClipboard(StringUpperFirst("osteopenic change at distal aspects of fracture site, suggestive of disuse osteopenia" A_EndChar),3)
    return
    :B0:Opm::
        sendByClipboard(StringUpperFirst("marked osteopenic change of visible bones" A_EndChar),3)
    return
    :B0:Opp::
        sendByClipboard(StringUpperFirst("periarticular osteopenia" A_EndChar),3)
    return
    :B0:Opv1::
        sendByClipboard(StringUpperFirst("suspected osteopenic change of visible bones" A_EndChar),4)
    return
    :B0:Ore::
        sendByClipboard(StringUpperFirst("removal of the implant" A_EndChar),3)
    return
    :B0:Orp::
        sendByClipboard(StringUpperFirst("status post reconstruction plate and screw fixation" A_EndChar),3)
    return
    :B0:Osal::
        sendByClipboard(StringUpperFirst("status post soft tissue anchor fixation over the left humeral greater tuberosity" A_EndChar),4)
    return
    :B0:Osar::
        sendByClipboard(StringUpperFirst("status post soft tissue anchor fixation over the right humeral greater tuberosity" A_EndChar),4)
    return
    :B0:Osb::
        sendByClipboard(StringUpperFirst("osteoblastic lesion" A_EndChar),3)
    return
    :*B0:Osb1::
        sendByClipboard(StringUpperFirst("osteoblastic lesions"),3)
    return
    :B0:Osg::
        sendByClipboard(StringUpperFirst("irregularity and fragmentation at the tibial tuberosity with adjacent soft tissue swelling, Osgood-Schlatter disease is considered first" A_EndChar),3)
    return
    :B0:Osl::
        sendByClipboard(StringUpperFirst("status post posterior decompression and posterior instrumentation at" A_EndChar),3)
    return
    :B0:Osll::
        sendByClipboard(StringUpperFirst("status post laminectomy and posterior decompression, lateral bony fusion, transpedicle screw insertion and posterior instrumentation at" A_EndChar),4)
    return
    :B0:Oslll::
        sendByClipboard(StringUpperFirst("status post laminectomy and posterior decompression, lateral bony fusion, transpedicle screw insertion and posterior instrumentation, and interbody fusion at" A_EndChar),5)
    return
    :B0:Otb::
        sendByClipboard(StringUpperFirst("status post intramedullary pin and tension band wire fixation" A_EndChar),3)
    return
    :B0:Paod::
        sendByClipboard(StringUpperFirst("peripheral arterial occlusive disease" A_EndChar),4)
    return
    :B0:Paodq::
        sendByClipboard(StringUpperFirst("atherosclerosis with wall calcifications at the abdominal aorta and bilateral common iliac arteries as well as multifocal varying-sized calcified wall plaques on the wall of arteries in both lower limbs." A_EndChar),5)
    return
    :B0:Pars::
        sendByClipboard(StringUpperFirst("pars interarticularis" A_EndChar),4)
    return
    :B0:Pcll::
        sendByClipboard(StringUpperFirst("posterior cruciate ligament" A_EndChar),4)
    return
    :B0:Pd::
        sendByClipboard(StringUpperFirst("posterior decompression" A_EndChar),2)
    return
    :B0:Pdfs::
        sendByClipboard(StringUpperFirst("fat-suppressed PD images" A_EndChar),4)
    return
    :B0:Pera::
        sendByClipboard(StringUpperFirst("periprosthetic radiolucency" A_EndChar),4)
    return
    :B0:Peri1::
        sendByClipboard(StringUpperFirst("osteolysis" A_EndChar),5)
    return
    :B0:Peri2::
        sendByClipboard(StringUpperFirst("osteolysis or prosthetic loosening" A_EndChar),5)
    return
    :B0:Peri3::
        sendByClipboard(StringUpperFirst("prosthetic loosening" A_EndChar),5)
    return
    :B0:Perif::
        sendByClipboard(StringUpperFirst("periprosthetic fracture" A_EndChar),5)
    return
    :B0:Pla::
        sendByClipboard(StringUpperFirst("pes planus" A_EndChar),3)
    return
    :B0:Plaa::
        sendByClipboard(StringUpperFirst("small calcaneal inclination angle (calcaneal pitch), suggestive of pes planus" A_EndChar),4)
    return
    :B0:Pf::
        sendByClipboard(StringUpperFirst("previous fracture" A_EndChar),2)
    return
    :*B0:Pf1::
        sendByClipboard(StringUpperFirst("previous fractures"),2)
    return
    :B0:Pff::
        sendByClipboard(StringUpperFirst("previous fracture or osteotomy" A_EndChar),3)
    return
    :B0:Phlm::
        sendByClipboard(StringUpperFirst("posterior horn of lateral meniscus" A_EndChar),4)
    return
    :B0:Phmm::
        sendByClipboard(StringUpperFirst("posterior horn of medial meniscus" A_EndChar),4)
    return
    :B0:Pi::
        sendByClipboard(StringUpperFirst("posterior instrumentation/fixation" A_EndChar),2)
    return
    :B0:Plf::
        sendByClipboard(StringUpperFirst("posterior lateral fusion" A_EndChar),3)
    return
    :B0:Sac0::
        sendByClipboard(StringUpperFirst("the sacrum is obliterated by the bowel gas" A_EndChar),4)
    return
    :B0:Prd::
        sendByClipboard(StringUpperFirst("protruding disc" A_EndChar),3)
    return
    :*B0:Pcnt::
        sendByClipboard(StringUpperFirst("paracentral"),3)
    return
    :B0:Frm::
        sendByClipboard(StringUpperFirst("foramen" A_EndChar),3)
    return
    :*B0:Frm1::
        sendByClipboard(StringUpperFirst("foramina"),3)
    return
    :*B0:Frm2::
        sendByClipboard(StringUpperFirst("foraminal"),3)
    return
    :B0:Pvb::
        sendByClipboard(StringUpperFirst("pelvic bone" A_EndChar),3)
    return
    :*B0:Pvb1::
        sendByClipboard(StringUpperFirst("pelvic bones"),3)
    return
    :B0:Prob::
        sendByClipboard(StringUpperFirst("broad-based protruding disc" A_EndChar),4)
    return
    :*B0:Prob1::
        sendByClipboard(StringUpperFirst("broad-based protruding discs"),4)
    return
    :B0:Prol::
        sendByClipboard(StringUpperFirst("eccentric protruding disc(s) at left posterior aspect" A_EndChar),4)
    return
    :B0:Pror::
        sendByClipboard(StringUpperFirst("eccentric protruding disc(s) at right posterior aspect" A_EndChar),4)
    return
    :B0:Puv::
        sendByClipboard(StringUpperFirst("positive ulnar variance" A_EndChar),3)
    return
    :B0:Pvns::
        sendByClipboard(StringUpperFirst("pigmented villonodular synovitis" A_EndChar),4)
    return
    :B0:R3mt::
        sendByClipboard(StringUpperFirst("right 3rd metatarsal" A_EndChar),4)
    return
    :B0:R4mt::
        sendByClipboard(StringUpperFirst("right 4th metatarsal" A_EndChar),4)
    return
    :B0:R5mt::
        sendByClipboard(StringUpperFirst("right 5th metatarsal" A_EndChar),4)
    return
    :B0:Rm1::
        sendByClipboard(StringUpperFirst("hematopoietic (red) marrow" A_EndChar),3)
    return
    :B0:Rm2::
        sendByClipboard(StringUpperFirst("heterogeneous marrow signal change of mild hypointensity on T1WI but no abnormal hyperintensity on fat-suppressed T2WI at sacrum, bilateral pelvic bones and proximal femurs, hematopoietic (red) marrow is considered first." A_EndChar),3)
    return
    :B0:Tsi1::
        sendByClipboard(StringUpperFirst("thecal sac indentation and potential spinal stenosis" A_EndChar),4)
    return
    :B0:Rpc::
        sendByClipboard(StringUpperFirst("retropulsed posterior cortex" A_EndChar),3)
    return
    :B0:Ftr::
        sendByClipboard(StringUpperFirst("full-thickness rupture" A_EndChar),3)
    return
    :B0:Sal::
        sendByClipboard(StringUpperFirst("straightening alignment" A_EndChar),3)
    return
    :B0:Sacb::
        sendByClipboard(StringUpperFirst("lumbar sacralization of L5 on both sides" A_EndChar),4)
    return
    :B0:Sacl::
        sendByClipboard(StringUpperFirst("partial lumbar sacralization of L5 on left side" A_EndChar),4)
    return
    :B0:Sacr::
        sendByClipboard(StringUpperFirst("partial lumbar sacralization of L5 on right side" A_EndChar),4)
    return
    :B0:Sasd::
        sendByClipboard(StringUpperFirst("subacromion-subdeltoid bursa" A_EndChar),4)
    return
    :B0:Sbcb::
        sendByClipboard(StringUpperFirst("subcoracoid bursa" A_EndChar),4)
    return
    :B0:Sbf::
        sendByClipboard(StringUpperFirst("spina bifida" A_EndChar),3)
    return
    :B0:Scob::
        sendByClipboard(StringUpperFirst("scoliosis with main (fixed) curvature at mid-thoracic spine and compensatory (correctable) curvature at the lumbar spine" A_EndChar),4)
    return
    :B0:Scol::
        sendByClipboard(StringUpperFirst("scoliosis with convexity of the thoracic spine to left side" A_EndChar),4)
    return
    :B0:Scolr::
        sendByClipboard(StringUpperFirst("scoliosis of spine with convexity of the thoracic spine to left side and convexity of the lumbar spine to right side" A_EndChar),5)
    return
    :B0:Scor::
        sendByClipboard(StringUpperFirst("scoliosis with convexity of the thoracic spine to right side" A_EndChar),4)
    return
    :B0:Scorl::
        sendByClipboard(StringUpperFirst("scoliosis of spine with convexity of the thoracic spine to right side and convexity of the lumbar spine to left side" A_EndChar),5)
    return
    :B0:Sctl::
        sendByClipboard(StringUpperFirst("scoliosis of the thoracolumbar spine" A_EndChar),4)
    return
    :B0:Sd::
        sendByClipboard(StringUpperFirst("decreased disc space and end-plate change" A_EndChar),2)
    return
    :B0:Sds::
        sendByClipboard(StringUpperFirst("decreased disc space and sclerotic end-plate change" A_EndChar),3)
    return
    :B0:Sec::
        sendByClipboard(StringUpperFirst("sclerotic endplate change" A_EndChar),3)
    return
    :B0:Eec::
        sendByClipboard(StringUpperFirst("edematous endplate change" A_EndChar),3)
    return
    :B0:Seq::
        sendByClipboard(StringUpperFirst("sequestrated disc" A_EndChar),3)
    return
    :*B0:Seq1::
        sendByClipboard(StringUpperFirst("sequestrated discs"),3)
    return
    :B0:Sh0::
        sendByClipboard(StringUpperFirst("the glenohumeral joint appear normal; no obvious fracture line; no evidence of joint subluxation or dislocation." A_EndChar),3)
    return
    :B0:Sh1::
        sendByClipboard(StringUpperFirst("lateral down-sloping" A_EndChar),3)
    return
    :B0:Sh2::
        sendByClipboard(StringUpperFirst("subacromial spur" A_EndChar),3)
    return
    :B0:Sh3::
        sendByClipboard(StringUpperFirst("inferior marginal spur" A_EndChar),3)
    return
    :B0:Shd::
        sendByClipboard(StringUpperFirst("lateral down-sloping of the acromion" A_EndChar),3)
    return
    :B0:Shdl::
        sendByClipboard(StringUpperFirst("down-sloping and low-lying of the acromion" A_EndChar),4)
    return
    :B0:Shl::
        sendByClipboard(StringUpperFirst("low-lying" A_EndChar),3)
    return
    :B0:Shn::
        sendByClipboard(StringUpperFirst("subacromial space narrowing" A_EndChar),3)
    return
    :B0:Shp::
        sendByClipboard(StringUpperFirst("synovial herniation pit" A_EndChar),3)
    return
    :*B0:Shp1::
        sendByClipboard(StringUpperFirst("synovial herniation pits"),3)
    return
    :B0:Shs::
        sendByClipboard(StringUpperFirst("subacromial spur formation" A_EndChar),3)
    return
    :B0:Slac::
        sendByClipboard(StringUpperFirst("SLAC (superior labrum anterior cuff) lesion" A_EndChar),4)
    return
    :B0:Slapp::
        sendByClipboard(StringUpperFirst("superior labral anterior-posterior (SLAP) lesion" A_EndChar),5)
    return
    :B0:Slap2::
        sendByClipboard(StringUpperFirst("linear high SI on T2WI and GRE T2WI in the superior labrum with anterior and posterior extension." A_EndChar),5)
    return
    :B0:Slap3::
        sendByClipboard(StringUpperFirst("large irregular high SI on T2WI and GRE T2WI in the superior labrum with anterior and posterior extension with bucket-handle like split and susp. extension into the biceps root." A_EndChar),5)
    return
    :B0:Smn::
        sendByClipboard(StringUpperFirst("Schmorl's node" A_EndChar),3)
    return
    :B0:Sonk::
        sendByClipboard(StringUpperFirst("spontaneous osteonecrosis of the knee (SONK)" A_EndChar),4)
    return
    :B0:Sonkl::
        sendByClipboard(StringUpperFirst("osteochondral defect with sclerotic margin at left medial femoral condylar articular surface, suggesting osteonecrosis." A_EndChar),5)
    return
    :B0:Sonkr::
        sendByClipboard(StringUpperFirst("osteochondral defect with sclerotic margin at right medial femoral condylar articular surface, suggesting osteonecrosis." A_EndChar),5)
    return
    :B0:Sst::
        sendByClipboard(StringUpperFirst("supraspinatus tendon" A_EndChar),3)
    return
    :B0:Sstt::
        sendByClipboard(StringUpperFirst("subscapularis tendon" A_EndChar),4)
    return
    :B0:St1::
        sendByClipboard(StringUpperFirst("mild stenosis" A_EndChar),3)
    return
    :B0:St12::
        sendByClipboard(StringUpperFirst("mild to moderate stenosis" A_EndChar),4)
    return
    :B0:St2::
        sendByClipboard(StringUpperFirst("moderate stenosis" A_EndChar),3)
    return
    :B0:St23::
        sendByClipboard(StringUpperFirst("moderate to severe stenosis" A_EndChar),4)
    return
    :B0:St3::
        sendByClipboard(StringUpperFirst("severe stenosis" A_EndChar),3)
    return
    :B0:St4::
        sendByClipboard(StringUpperFirst("nearly-total occlusion" A_EndChar),3)
    return
    :B0:St5::
        sendByClipboard(StringUpperFirst("total occlusion" A_EndChar),3)
    return
    :B0:Stc::
        sendByClipboard(StringUpperFirst("soft tissue calcification" A_EndChar),3)
    return
    :*B0:Stc1::
        sendByClipboard(StringUpperFirst("soft tissue calcifications"),3)
    return
    :B0:Cat::
        sendByClipboard(StringUpperFirst("calcific tendinitis" A_EndChar),3)
    return
    :B0:Cabt::
        sendByClipboard(StringUpperFirst("calcific bursitis or tendinosis" A_EndChar),4)
    return
    :B0:Stirr::
        sendByClipboard(StringUpperFirst("fat-suppressed T2WI" A_EndChar),5)
    return
    :B0:Stl::
        sendByClipboard(StringUpperFirst("soft tissue lesion" A_EndChar),3)
    return
    :B0:Stm::
        sendByClipboard(StringUpperFirst("soft tissue mass" A_EndChar),3)
    return
    :B0:Stos::
        sendByClipboard(StringUpperFirst("soft tissue ossification" A_EndChar),4)
    return
    :*B0:Stos1::
        sendByClipboard(StringUpperFirst("soft tissue ossifications"),4)
    return
    :B0:Stsa::
        sendByClipboard(StringUpperFirst("adjacent soft tissue swelling" A_EndChar),4)
    return
    :B0:Stsp::
        sendByClipboard(StringUpperFirst("periarticular soft tissue swelling" A_EndChar),4)
    return
    :B0:Stt::
        sendByClipboard(StringUpperFirst("soft tissue tumor" A_EndChar),3)
    return
    :B0:Subc::
        sendByClipboard(StringUpperFirst("subchondral" A_EndChar),4)
    return
    :B0:Suc::
        sendByClipboard(StringUpperFirst("subcutaneous" A_EndChar),3)
    return
    :*B0:Suc1::
        sendByClipboard(StringUpperFirst("subcutis"),3)
    return
    :B0:Cu::
        sendByClipboard(StringUpperFirst("cutaneous" A_EndChar),2)
    return
    :*B0:Cu1::
        sendByClipboard(StringUpperFirst("cutis"),2)
    return
    :B0:Mtj::
        sendByClipboard(StringUpperFirst("musculotendinous junction" A_EndChar),3)
    return
    :B0:Taf::
        sendByClipboard(StringUpperFirst("torn annulus fibrosus" A_EndChar),3)
    return
    :B0:Te::
        sendByClipboard(StringUpperFirst("traction enthesophyte formation at" A_EndChar),2)
    return
    :B0:Tecb::
        sendByClipboard(StringUpperFirst("traction enthesophyte formation at bilateral calcaneal posterior processes" A_EndChar),4)
    return
    :B0:Tecl::
        sendByClipboard(StringUpperFirst("traction enthesophyte formation at left calcaneal posterior process" A_EndChar),4)
    return
    :B0:Tecr::
        sendByClipboard(StringUpperFirst("traction enthesophyte formation at right calcaneal posterior process" A_EndChar),4)
    return
    :B0:Tehb::
        sendByClipboard(StringUpperFirst("traction enthesopathy at bilateral humeral greater tuberosities" A_EndChar),4)
    return
    :B0:Tehl::
        sendByClipboard(StringUpperFirst("traction enthesopathy at left humeral greater tuberosity" A_EndChar),4)
    return
    :B0:Tehr::
        sendByClipboard(StringUpperFirst("traction enthesopathy at right humeral greater tuberosity" A_EndChar),4)
    return
    :B0:Tepb::
        sendByClipboard(StringUpperFirst("traction enthesophyte formation at bilateral patellar bases" A_EndChar),4)
    return
    :B0:Tepl::
        sendByClipboard(StringUpperFirst("traction enthesophyte formation at left patellar base" A_EndChar),4)
    return
    :B0:Tepr::
        sendByClipboard(StringUpperFirst("traction enthesophyte formation at right patellar base" A_EndChar),4)
    return
    :B0:Tis::
        sendByClipboard(StringUpperFirst("tibial intercondylar spine" A_EndChar),3)
    return
    :B0:Tie::
        sendByClipboard(StringUpperFirst("tibial intercondylar eminance" A_EndChar),3)
    return
    :B0:Tlj::
        sendByClipboard(StringUpperFirst("thoracolumbar junction" A_EndChar),3)
    return
    :B0:Tls::
        sendByClipboard(StringUpperFirst("thoracolumbar spondylosis" A_EndChar),3)
    return
    :B0:Tls1::
        sendByClipboard(StringUpperFirst("thoracolumbar spondylosis with marginal osteophyte formation" A_EndChar),4)
    return
    :B0:Tlsf::
        sendByClipboard(StringUpperFirst("thoracolumbar spondylosis with marginal osteophyte formation and facet joint arthroses" A_EndChar),4)
    return
    :B0:Tlss::
        sendByClipboard(StringUpperFirst("thoracolumbar scoliosis and spondylosis" A_EndChar),4)
    return
    :B0:Tec::
        sendByClipboard(StringUpperFirst("traction enthesopathic change" A_EndChar),3)
    return
    :B0:Tech::
        sendByClipboard(StringUpperFirst("traction enthesopathic change at the humeral greater tubercle" A_EndChar),4)
    return
    :B0:Tecc::
        sendByClipboard(StringUpperFirst("subchondral cyst(s) at the humeral head which may relate to traction enthesopathic change." A_EndChar),4)
    return
    :B0:Ts::
        sendByClipboard(StringUpperFirst("thoracic spondylosis" A_EndChar),2)
    return
    :B0:Tsp::
        sendByClipboard(StringUpperFirst("traction spur at patellar base" A_EndChar),3)
    return
    :B0:Tss::
        sendByClipboard(StringUpperFirst("thoracic scoliosis and spondylosis" A_EndChar),3)
    return
    :B0:Uc::
        sendByClipboard(StringUpperFirst("callus formation" A_EndChar),2)
    return
    :B0:Ud::
        sendByClipboard(StringUpperFirst("suggestive of delayed union" A_EndChar),2)
    return
    :B0:Udn::
        sendByClipboard(StringUpperFirst("radiolucent gap at fracture cleft, suggesting radiological delayed or non-union" A_EndChar),3)
    return
    :B0:Uao::
        sendByClipboard(StringUpperFirst("a small bony focus near the ulnar styloid process which is probably related to accessory ossicle or old fracture" A_EndChar),3)
    return
    :B0:Uop::
        sendByClipboard(StringUpperFirst("ulnar olecranon process" A_EndChar),3)
    return
    :B0:Usp::
        sendByClipboard(StringUpperFirst("ulnar styloid process" A_EndChar),3)
    return
    :B0:Uuc::
        sendByClipboard(StringUpperFirst("unilateral callus formation" A_EndChar),3)
    return
    :B0:Uwc::
        sendByClipboard(StringUpperFirst("well union and callus formation" A_EndChar),3)
    return
    :B0:Vp0::
        sendByClipboard(StringUpperFirst("status post vertebroplasty with bone cement in position" A_EndChar),3)
    return
    :B0:Vwc::
        sendByClipboard(StringUpperFirst("vascular wall calcifications" A_EndChar),3)
    return
    :B0:Vld::
        sendByClipboard(StringUpperFirst("valgus deformity" A_EndChar),3)
    return
    :B0:Vrd::
        sendByClipboard(StringUpperFirst("varus deformity" A_EndChar),3)
    return
    :B0:Wd::
        sendByClipboard(StringUpperFirst("wedge deformity" A_EndChar),2)
    return
    :B0:Xc::
        sendByClipboard(StringUpperFirst("subchondral cyst" A_EndChar),2)
    return
    :*B0:Xc1::
        sendByClipboard(StringUpperFirst("subchondral cysts"),2)
    return
    :B0:Xd::
        sendByClipboard(StringUpperFirst("disc space narrowing" A_EndChar),2)
    return
    :B0:Xe::
        sendByClipboard(StringUpperFirst("subchondral erosion" A_EndChar),2)
    return
    :*B0:Xe1::
        sendByClipboard(StringUpperFirst("subchondral erosions"),2)
    return
    :B0:Xep::
        sendByClipboard(StringUpperFirst("periarticular erosion" A_EndChar),3)
    return
    :*B0:Xep1::
        sendByClipboard(StringUpperFirst("periarticular erosions"),3)
    return
    :B0:Xj::
        sendByClipboard(StringUpperFirst("joint space narrowing" A_EndChar),2)
    return
    :B0:Xjj::
        sendByClipboard(StringUpperFirst("joint space widening" A_EndChar),3)
    return
    :B0:Xja::
        sendByClipboard(StringUpperFirst("asymmetrical joint space narrowing" A_EndChar),3)
    return
    :B0:Xjl::
        sendByClipboard(StringUpperFirst("localized joint space narrowing" A_EndChar),3)
    return
    :B0:Xjo::
        sendByClipboard(StringUpperFirst("marginal spur formation and joint space narrowing at" A_EndChar),3)
    return
    :B0:Xjs::
        sendByClipboard(StringUpperFirst("symmetrical joint space narrowing" A_EndChar),3)
    return
    :B0:Xo::
        sendByClipboard(StringUpperFirst("marginal osteophyte" A_EndChar),2)
    return
    :*B0:Xo1::
        sendByClipboard(StringUpperFirst("marginal osteophytes"),2)
    return
    :B0:Xp::
        sendByClipboard(StringUpperFirst("posterior spur" A_EndChar),2)
    return
    :*B0:Xp1::
        sendByClipboard(StringUpperFirst("posterior spurs"),2)
    return
    :B0:Xpp::
        sendByClipboard(StringUpperFirst("disc space narrowing and posterior spur(s) with potential spinal stenosis" A_EndChar),3)
    return
    :B0:Xr::
        sendByClipboard(StringUpperFirst("subchondral radiolucencies" A_EndChar),2)
    return
    :B0:Xs::
        sendByClipboard(StringUpperFirst("subchondral sclerosis" A_EndChar),2)
    return
    :B0:Xu::
        sendByClipboard(StringUpperFirst("uneven articular surface" A_EndChar),2)
    return
    :B0:Zja::
        sendByClipboard(StringUpperFirst("zygapophyseal joint arthrosis" A_EndChar),3)
    return
    :B0:Z0::
        sendByClipboard(StringUpperFirst("remainder of the exam is unremarkable" A_EndChar),2)
    return
    :B0:Zsa::
        sendByClipboard(StringUpperFirst("subarticular zone" A_EndChar),3)
    return
    :*B0:Lscf::
        sendByClipboard(StringUpperFirst("lumbar spondylosis with compression fracture"),3)
    return
    :*B0:Cscf::
        sendByClipboard(StringUpperFirst("cervical spondylosis with compression fracture"),3)
    return
    :*B0:Tscf::
        sendByClipboard(StringUpperFirst("thoracic spondylosis with compression fracture"),3)
    return
    :*B0:Tlscf::
        sendByClipboard(StringUpperFirst("thoracolumbar spondylosis with compression fracture"),4)
    return
    :*B0:Lsop::
        sendByClipboard(StringUpperFirst("lumbar spondylosis with post-operative changes"),3)
    return
    :*B0:Csop::
        sendByClipboard(StringUpperFirst("cervical spondylosis with post-operative changes"),3)
    return
    :*B0:Tsop::
        sendByClipboard(StringUpperFirst("thoracic spondylosis with post-operative changes"),3)
    return
    :*B0:Tlsop::
        sendByClipboard(StringUpperFirst("thoracolumbar spondylosis with post-operative changes"),4)
    return
    :B0:Ops::
        sendByClipboard(StringUpperFirst("post-operative changes of the spine." A_EndChar),3)
    return
    :*B0:Csst::
        sendByClipboard(StringUpperFirst("cervical spondylosis with spinal stenosis."),3)
    return
    :*B0:Tsst::
        sendByClipboard(StringUpperFirst("thoracic spondylosis with spinal stenosis."),3)
    return
    :*B0:Lsst::
        sendByClipboard(StringUpperFirst("lumbar spondylosis with spinal stenosis."),3)
    return
    :*B0:Tlsst::
        sendByClipboard(StringUpperFirst("thoracolumbar spondylosis with spinal stenosis."),4)
    return
    :B0:Cs::
        sendByClipboard(StringUpperFirst("cervical spondylosis" A_EndChar),2)
    return
    :B0:Csl::
        sendByClipboard(StringUpperFirst("cervical spondylosis with marginal osteophyte formation at lower levels" A_EndChar),3)
    return
    :B0:Csm::
        sendByClipboard(StringUpperFirst("mild cervical spondylosis with small marginal osteophyte formation" A_EndChar),3)
    return
    :B0:Csp::
        sendByClipboard(StringUpperFirst("fine alignment; no obvious fracture line; no abnormal retropharyngeal soft tissue;" A_EndChar),3)
    return
    :B0:Css::
        sendByClipboard(StringUpperFirst("cervical scoliosis and spondylosis" A_EndChar),3)
    return
    :B0:Cssl::
        sendByClipboard(StringUpperFirst("cervical scoliosis and spondylosis with marginal osteophyte formation at lower levels" A_EndChar),4)
    return
    :B0:Cssm::
        sendByClipboard(StringUpperFirst("cervical scoliosis and spondylosis with small marginal osteophyte formation" A_EndChar),4)
    return
    :B0:Ls::
        sendByClipboard(StringUpperFirst("lumbar spondylosis" A_EndChar),2)
    return
    :B0:Lsl::
        sendByClipboard(StringUpperFirst("lumbar spondylosis with marginal osteophyte formation at lower lumbar levels" A_EndChar),3)
    return
    :B0:Lsm::
        sendByClipboard(StringUpperFirst("mild lumbar spondylosis with small marginal osteophyte formation" A_EndChar),3)
    return
    :B0:Lss::
        sendByClipboard(StringUpperFirst("lumbar scoliosis and spondylosis" A_EndChar),3)
    return
    :B0:Lssl::
        sendByClipboard(StringUpperFirst("lumbar scoliosis and spondylosis with marginal osteophyte formation at lower lumbar levels" A_EndChar),4)
    return
    :B0:Lssm::
        sendByClipboard(StringUpperFirst("lumbar scoliosis and spondylosis with small marginal osteophyte formation" A_EndChar),4)
    return
    :B0:Lsk::
        sendByClipboard(StringUpperFirst("lumbar kyphoscoliosis and spondylosis" A_EndChar),3)
    return
    :B0:Lskl::
        sendByClipboard(StringUpperFirst("lumbar kyphoscoliosis and spondylosis with marginal osteophyte formation at lower lumbar levels" A_EndChar),4)
    return
    :B0:Lskm::
        sendByClipboard(StringUpperFirst("lumbar kyphoscoliosis and spondylosis with small marginal osteophyte formation" A_EndChar),4)
    return
    :B0:Lstv::
        sendByClipboard(StringUpperFirst("lumbosacral transitional vertebrae" A_EndChar),4)
    return
    :B0:Lstvb::
        sendByClipboard(StringUpperFirst("lumbosacral transitional vertebrae with pseudoarticulation on both sides" A_EndChar),5)
    return
    :B0:Lstvr::
        sendByClipboard(StringUpperFirst("lumbosacral transitional vertebrae with pseudoarticulation on right side" A_EndChar),5)
    return
    :B0:Lstvl::
        sendByClipboard(StringUpperFirst("lumbosacral transitional vertebrae with pseudoarticulation on left side" A_EndChar),5)
    return
    :B0:Lhar::
        sendByClipboard(StringUpperFirst("lipohemoarthrosis" A_EndChar),4)
    return
    :B0:Mof::
        sendByClipboard(StringUpperFirst("marginal osteophyte formation" A_EndChar),3)
    return
    :B0:Pmof::
        sendByClipboard(StringUpperFirst("posterior marginal osteophyte formation" A_EndChar),4)
    return
    :B0:Dch::
        sendByClipboard(StringUpperFirst("decreased height" A_EndChar),3)
    return
    :B0:Dcl::
        sendByClipboard(StringUpperFirst("decreased lordosis" A_EndChar),3)
    return
    :B0:Cf::
        sendByClipboard(StringUpperFirst("compression fracture" A_EndChar),2)
    return
    :*B0:Cf1::
        sendByClipboard(StringUpperFirst("compression fractures"),2)
    return
    :B0:Iar::
        sendByClipboard(StringUpperFirst("intra-articular" A_EndChar),3)
    return
    :B0:Cmn::
        sendByClipboard(StringUpperFirst("comminuted" A_EndChar),3)
    return
    :B0:Dsp::
        sendByClipboard(StringUpperFirst("displaced" A_EndChar),3)
    return
    :B0:Ndsp::
        sendByClipboard(StringUpperFirst("non-displaced" A_EndChar),4)
    return
    :B0:Dpm::
        sendByClipboard(StringUpperFirst("displacement" A_EndChar),3)
    return
    :B0:Fx::
        sendByClipboard(StringUpperFirst("fracture" A_EndChar),2)
    return
    :*B0:Fx1::
        sendByClipboard(StringUpperFirst("fractures"),2)
    return
    :B0:Spc::
        sendByClipboard(StringUpperFirst("cervical spine" A_EndChar),3)
    return
    :B0:Spt::
        sendByClipboard(StringUpperFirst("thoracic spine" A_EndChar),3)
    return
    :B0:Spl::
        sendByClipboard(StringUpperFirst("lumbar spine" A_EndChar),3)
    return
    :B0:Sptl::
        sendByClipboard(StringUpperFirst("thoracolumbar spine" A_EndChar),4)
    return
    :B0:Spct::
        sendByClipboard(StringUpperFirst("cervicothoracic spine" A_EndChar),4)
    return
    :B0:Spls::
        sendByClipboard(StringUpperFirst("lumbosacral spine" A_EndChar),4)
    return
    :B0:Spd::
        sendByClipboard(StringUpperFirst("spondylosis" A_EndChar),3)
    return
    :B0:Li2::
        sendByClipboard(StringUpperFirst("spondylolisthesis at L2-3" A_EndChar),3)
    return
    :B0:Li3::
        sendByClipboard(StringUpperFirst("spondylolisthesis at L3-4" A_EndChar),3)
    return
    :B0:Li4::
        sendByClipboard(StringUpperFirst("spondylolisthesis at L4-5" A_EndChar),3)
    return
    :B0:Li5::
        sendByClipboard(StringUpperFirst("spondylolisthesis at L5-S1" A_EndChar),3)
    return
    :B0:Lid::
        sendByClipboard(StringUpperFirst("degenerative spondylolisthesis" A_EndChar),3)
    return
    :B0:Lid2::
        sendByClipboard(StringUpperFirst("degenerative spondylolisthesis at L2-3" A_EndChar),4)
    return
    :B0:Lid3::
        sendByClipboard(StringUpperFirst("degenerative spondylolisthesis at L3-4" A_EndChar),4)
    return
    :B0:Lid4::
        sendByClipboard(StringUpperFirst("degenerative spondylolisthesis at L4-5" A_EndChar),4)
    return
    :B0:Lid5::
        sendByClipboard(StringUpperFirst("degenerative spondylolisthesis at L5-S1" A_EndChar),4)
    return
    :B0:Lil::
        sendByClipboard(StringUpperFirst("spondylolytic spondylolisthesis" A_EndChar),3)
    return
    :B0:Lil2::
        sendByClipboard(StringUpperFirst("spondylolytic spondylolisthesis at L2-3" A_EndChar),4)
    return
    :B0:Lil3::
        sendByClipboard(StringUpperFirst("spondylolytic spondylolisthesis at L3-4" A_EndChar),4)
    return
    :B0:Lil4::
        sendByClipboard(StringUpperFirst("spondylolytic spondylolisthesis at L4-5" A_EndChar),4)
    return
    :B0:Lil5::
        sendByClipboard(StringUpperFirst("spondylolytic spondylolisthesis at L5-S1" A_EndChar),4)
    return
    :B0:Lia::
        sendByClipboard(StringUpperFirst("anterolisthesis" A_EndChar),3)
    return
    :B0:Lir::
        sendByClipboard(StringUpperFirst("retrolisthesis" A_EndChar),3)
    return
    :B0:Fx0::
        sendByClipboard(StringUpperFirst("no obvious bony fracture" A_EndChar),3)
    return
    :B0:Cst::
        sendByClipboard(StringUpperFirst("spinal canal narrowing" A_EndChar),3)
    return
    :*B0:Spca::
        sendByClipboard(StringUpperFirst("spinal canal"),3)
    return
    :B0:Doc::
        sendByClipboard(StringUpperFirst("disc osteophyte complex" A_EndChar),3)
    return
    :*B0:Sfaa::
        sendByClipboard(StringUpperFirst("superficial femoral artery"),3)
    return
    :*B0:Sfaa1::
        sendByClipboard(StringUpperFirst("superficial femoral arteries"),4)
    return
    :*B0:Ataa::
        sendByClipboard(StringUpperFirst("anterior tibial artery"),3)
    return
    :*B0:Ataa1::
        sendByClipboard(StringUpperFirst("anterior tibial arteries"),4)
    return
    :*B0:Ptaa::
        sendByClipboard(StringUpperFirst("posterior tibial artery"),3)
    return
    :*B0:Ptaa1::
        sendByClipboard(StringUpperFirst("posterior tibial arteries"),4)
    return
    :B0:Bfn::
        sendByClipboard(StringUpperFirst("bilateral neural foraminal narrowing" A_EndChar),3)
    return
    :B0:Rfn::
        sendByClipboard(StringUpperFirst("right neural foraminal narrowing" A_EndChar),3)
    return
    :B0:Lfn::
        sendByClipboard(StringUpperFirst("left neural foraminal narrowing" A_EndChar),3)
    return
    :*B0:Cst1::
        sendByClipboard(StringUpperFirst("mild spinal canal narrowing"),3)
    return
    :*B0:Cst2::
        sendByClipboard(StringUpperFirst("moderate spinal canal narrowing"),3)
    return
    :*B0:Cst3::
        sendByClipboard(StringUpperFirst("severe spinal canal narrowing"),3)
    return
    :B0:Sco::
        sendByClipboard(StringUpperFirst("scoliosis" A_EndChar),3)
    return
    :B0:Lor::
        sendByClipboard(StringUpperFirst("lordosis" A_EndChar),3)
    return
    :B0:Nsc::
        sendByClipboard(StringUpperFirst("no abnormal prevertebral soft tissue swelling" A_EndChar),3)
    return
    :B0:Vb::
        sendByClipboard(StringUpperFirst("vertebral body" A_EndChar),2)
    return
    :*B0:Vb1::
        sendByClipboard(StringUpperFirst("vertebral bodies"),2)
    return
    :B0:Nfn::
        sendByClipboard(StringUpperFirst("neural foraminal narrowing" A_EndChar),3)
    return
    :B0:Oly::
        sendByClipboard(StringUpperFirst("osteolytic" A_EndChar),3)
    return
    :B0:Oba::
        sendByClipboard(StringUpperFirst("osteoblastic" A_EndChar),3)
    return
    :B0:Olma::
        sendByClipboard(StringUpperFirst("odontoid-lateral mass interval asymmetry" A_EndChar),4)
    return
    :B0:Intus::
        sendByClipboard(StringUpperFirst("intussusception" A_EndChar),5)
    return
    :B0:Rhc::
        sendByClipboard(StringUpperFirst("right hemicolectomy" A_EndChar),3)
    return
    :B0:Lhc::
        sendByClipboard(StringUpperFirst("left hemicolectomy" A_EndChar),3)
    return
    :B0:Hct::
        sendByClipboard(StringUpperFirst("hemicolectomy" A_EndChar),3)
    return
    :B0:Gbw::
        sendByClipboard(StringUpperFirst("gallbladder wall" A_EndChar),3)
    return
    :B0:Ppv::
        sendByClipboard(StringUpperFirst("patent portal vein" A_EndChar),3)
    return
    :B0:Whp::
        sendByClipboard(StringUpperFirst("status post Whipple operation." A_EndChar),3)
    return
    :cB0:Aml::
        sendByClipboard(StringUpperFirst("AML" A_EndChar),3)
    return
    :B0:Amls::
        sendByClipboard(StringUpperFirst("AMLs" A_EndChar),4)
    return
    :B0:Oab::
        sendByClipboard(StringUpperFirst("post-operative change in abdomen." A_EndChar),3)
    return
    :B0:Rcx::
        sendByClipboard(StringUpperFirst("renal calyx" A_EndChar),3)
    return
    :*B0:Rcx1::
        sendByClipboard(StringUpperFirst("renal calyces"),3)
    return
    :B0:Bma::
        sendByClipboard(StringUpperFirst("biloma" A_EndChar),3)
    return
    :*B0:Bma1::
        sendByClipboard(StringUpperFirst("bilomas"),3)
    return
    :B0:Dbj::
        sendByClipboard(StringUpperFirst("double-J catheter" A_EndChar),3)
    return
    :*B0:Dbj1::
        sendByClipboard(StringUpperFirst("double-J catheters"),3)
    return
    :B0:Utm::
        sendByClipboard(StringUpperFirst("uterine mass" A_EndChar),3)
    return
    :*B0:Utm1::
        sendByClipboard(StringUpperFirst("uterine masses"),3)
    return
    :B0:Pss::
        sendByClipboard(StringUpperFirst("porto-systemic shunts" A_EndChar),3)
    return
    :B0:Hia::
        sendByClipboard(StringUpperFirst("hiatal hernia" A_EndChar),3)
    return
    :*B0:Schm::
        sendByClipboard(StringUpperFirst("subcapsular hematoma"),3)
    return
    :*B0:Pclv::
        sendByClipboard(StringUpperFirst("polycystic liver"),3)
    return
    :*B0:Pclk::
        sendByClipboard(StringUpperFirst("polycystic liver and kidney"),3)
    return
    :B0:Pck::
        sendByClipboard(StringUpperFirst("polycystic kidney" A_EndChar),3)
    return
    :B0:Oco::
        sendByClipboard(StringUpperFirst("post-operative changes of colon" A_EndChar),3)
    return
    :B0:Olv::
        sendByClipboard(StringUpperFirst("post-operative changes of liver" A_EndChar),3)
    return
    :B0:Osp::
        sendByClipboard(StringUpperFirst("post-operative changes of spine" A_EndChar),3)
    return
    :B0:Umb::
        sendByClipboard(StringUpperFirst("umbilical" A_EndChar),3)
    return
    :B0:Clt::
        sendByClipboard(StringUpperFirst("celiac trunk" A_EndChar),3)
    return
    :B0:Plv::
        sendByClipboard(StringUpperFirst("pelvic" A_EndChar),3)
    return
    :*B0:Atbk::
        sendByClipboard(StringUpperFirst("atrophic change of bilateral kidneys"),3)
    return
    :*B0:Atkc::
        sendByClipboard(StringUpperFirst("atrophic change of bilateral kidneys with cysts"),3)
    return
    :*B0:Atpn::
        sendByClipboard(StringUpperFirst("atrophic change of pancreas"),3)
    return
    :B0:Rsc::
        sendByClipboard(StringUpperFirst("rectosigmoid colon" A_EndChar),3)
    return
    :B0:Rcm::
        sendByClipboard(StringUpperFirst("rectum" A_EndChar),3)
    return
    :B0:Rcl::
        sendByClipboard(StringUpperFirst("rectal" A_EndChar),3)
    return
    :B0:Pht::
        sendByClipboard(StringUpperFirst("portal hypertension with collaterals" A_EndChar),3)
    return
    :B0:Rpv::
        sendByClipboard(StringUpperFirst("renal pelvis" A_EndChar),3)
    return
    :*B0:Rpv1::
        sendByClipboard(StringUpperFirst("renal pelvises"),3)
    return
    :B0:Adg::
        sendByClipboard(StringUpperFirst("adrenal gland" A_EndChar),3)
    return
    :*B0:Adg1::
        sendByClipboard(StringUpperFirst("adrenal glands"),3)
    return
    :B0:Pgb::
        sendByClipboard(StringUpperFirst("perigallbladder" A_EndChar),3)
    return
    :B0:Ppn::
        sendByClipboard(StringUpperFirst("peripancreatic" A_EndChar),3)
    return
    :*B0:Prl1::
        sendByClipboard(StringUpperFirst("pararenal"),3)
    return
    :B0:Ptt::
        sendByClipboard(StringUpperFirst("prostate" A_EndChar),3)
    return
    :B0:Ils::
        sendByClipboard(StringUpperFirst("ileus" A_EndChar),3)
    return
    :cB0:Hys::
        sendByClipboard(StringUpperFirst("hysterectomy" A_EndChar),3)
    return
    :*B0:Bx/::
        sendByClipboard(StringUpperFirst("bilateral adnexal cystic lesions"),2)
    return
    :*B0:Lx/::
        sendByClipboard(StringUpperFirst("left adnexal cystic lesion"),2)
    return
    :*B0:Rx/::
        sendByClipboard(StringUpperFirst("right adnexal cystic lesion"),2)
    return
    :B0:Xcl::
        sendByClipboard(StringUpperFirst("adnexal cystic lesion" A_EndChar),3)
    return
    :B0:Abw::
        sendByClipboard(StringUpperFirst("abdominal wall" A_EndChar),3)
    return
    :*B0:Dc0::
        sendByClipboard(StringUpperFirst("degenerative change of spine.`r`n- atherosclerotic calcification of the aorta.`r`n-"),2)
    return
    :B0:Aov::
        sendByClipboard(StringUpperFirst("ampulla of Vater" A_EndChar),3)
    return
    :B0:Hcc::
        sendByClipboard(StringUpperFirst("HCC" A_EndChar),3)
    return
    :B0:Hccs::
        sendByClipboard(StringUpperFirst("HCCs" A_EndChar),4)
    return
    :*B0:App0::
        sendByClipboard(StringUpperFirst("the appendix is not well-identified."),3)
    return
    :*B0:Msn1::
        sendByClipboard(StringUpperFirst("mesenteric"),3)
    return
    :B0:Msn::
        sendByClipboard(StringUpperFirst("mesentery" A_EndChar),3)
    return
    :B0:Aba::
        sendByClipboard(StringUpperFirst("abdominal aorta" A_EndChar),3)
    return
    :*B0:Hc/::
        sendByClipboard(StringUpperFirst("hypodense lesion(s) in liver, probably cyst(s)."),2)
    return
    :*B0:Rc/::
        sendByClipboard(StringUpperFirst("hypodense lesion(s) in kidney(s), probably cyst(s)."),2)
    return
    :B0:Hrc::
        sendByClipboard(StringUpperFirst("hepatic and renal cysts." A_EndChar),3)
    return
    :*B0:Hrc0::
        sendByClipboard(StringUpperFirst("hypodense lesions in liver and kidneys, cysts are favored."),3)
    return
    :B0:Cos::
        sendByClipboard(StringUpperFirst("collecting system" A_EndChar),3)
    return
    :B0:Nft::
        sendByClipboard(StringUpperFirst("nephrectomy" A_EndChar),3)
    return
    :*B0:Spln::
        sendByClipboard(StringUpperFirst("splenectomy"),3)
    return
    :*B0:Adrn::
        sendByClipboard(StringUpperFirst("adrenectomy"),3)
    return
    :B0:Sbi::
        sendByClipboard(StringUpperFirst("small bowel ileus" A_EndChar),3)
    return
    :B0:Ffs::
        sendByClipboard(StringUpperFirst("focal fatty sparing" A_EndChar),3)
    return
    :B0:Hmp::
        sendByClipboard(StringUpperFirst("hemoperitoneum" A_EndChar),3)
    return
    :B0:Hrp::
        sendByClipboard(StringUpperFirst("hemoretroperitoneum" A_EndChar),3)
    return
    :B0:Adn::
        sendByClipboard(StringUpperFirst("adnexal" A_EndChar),3)
    return
    :B0:Cds::
        sendByClipboard(StringUpperFirst("cul-de-sac" A_EndChar),3)
    return
    :*B0:Taec::
        sendByClipboard(StringUpperFirst("post-TAE change"),3)
    return
    :B0:Txl::
        sendByClipboard(StringUpperFirst("post-treatment change of the liver." A_EndChar),3)
    return
    :*B0:Txl1::
        sendByClipboard(StringUpperFirst("post-TAE change of the liver."),3)
    return
    :*B0:Txl2::
        sendByClipboard(StringUpperFirst("post-RFA change of the liver."),3)
    return
    :*B0:Txl3::
        sendByClipboard(StringUpperFirst("post-TAE and post-RFA change of the liver."),3)
    return
    :*B0:Uvjj::
        sendByClipboard(StringUpperFirst("ureterovesical junction"),3)
    return
    :*B0:Upjj::
        sendByClipboard(StringUpperFirst("ureteropelvic junction"),3)
    return
    :B0:Amm::
        sendByClipboard(StringUpperFirst("adenomyomatosis" A_EndChar),3)
    return
    :B0:Djj::
        sendByClipboard(StringUpperFirst("duodenojejunal junction" A_EndChar),3)
    return
    :B0:Gej::
        sendByClipboard(StringUpperFirst("gastroesophageal junction" A_EndChar),3)
    return
    :B0:Tpt::
        sendByClipboard(StringUpperFirst("transplantation" A_EndChar),3)
    return
    :B0:Hp::
        sendByClipboard(StringUpperFirst("hepatic" A_EndChar),2)
    return
    :B0:Hpc::
        sendByClipboard(StringUpperFirst("hepatic calcification" A_EndChar),3)
    return
    :*B0:Hpc1::
        sendByClipboard(StringUpperFirst("hepatic calcifications"),3)
    return
    :B0:Git::
        sendByClipboard(StringUpperFirst("gastrointestinal tract" A_EndChar),3)
    return
    :*B0:Git1::
        sendByClipboard(StringUpperFirst("gastrointestinal tracts"),3)
    return
    :B0:Gt::
        sendByClipboard(StringUpperFirst("gastric" A_EndChar),2)
    return
    :B0:Gtb::
        sendByClipboard(StringUpperFirst("gastric body" A_EndChar),3)
    return
    :B0:Gta::
        sendByClipboard(StringUpperFirst("gastric antrum" A_EndChar),3)
    return
    :B0:Gtc::
        sendByClipboard(StringUpperFirst("gastric cardia" A_EndChar),3)
    return
    :B0:Sfr::
        sendByClipboard(StringUpperFirst("subphrenic" A_EndChar),3)
    return
    :B0:Panu::
        sendByClipboard(StringUpperFirst("pseudoaneurysm" A_EndChar),4)
    return
    :*B0:Panu1::
        sendByClipboard(StringUpperFirst("pseudoaneurysms"),4)
    return
    :*B0:Iiavc::
        sendByClipboard(StringUpperFirst("IVC interruption with azygos vein continuation"),4)
    return
    :B0:Hmn::
        sendByClipboard(StringUpperFirst("hemangioma" A_EndChar),3)
    return
    :*B0:Hmn1::
        sendByClipboard(StringUpperFirst("hemangiomas"),3)
    return
    :*B0:Br/::
        sendByClipboard(StringUpperFirst("bilateral renal cysts."),2)
    return
    :*B0:Rr/::
        sendByClipboard(StringUpperFirst("right renal cyst(s)."),2)
    return
    :*B0:Lr/::
        sendByClipboard(StringUpperFirst("left renal cyst(s)."),2)
    return
    :B0:Ifll::
        sendByClipboard(StringUpperFirst("indeterminate focal liver lesions" A_EndChar),4)
    return
    :B0:Pnp::
        sendByClipboard(StringUpperFirst("pneumoperitoneum" A_EndChar),3)
    return
    :*B0:Abd0::
        sendByClipboard(StringUpperFirst("no definite focal lesions in the GI tract, liver, spleen, pancreas, both adrenal glands and kidneys."),3)
    return
    :B0:Gb::
        sendByClipboard(StringUpperFirst("gallbladder" A_EndChar),2)
    return
    :B0:Sto::
        sendByClipboard(StringUpperFirst("stomach" A_EndChar),3)
    return
    :*B0:Cbdd::
        sendByClipboard(StringUpperFirst("common bile duct"),3)
    return
    :*B0:Ihdd::
        sendByClipboard(StringUpperFirst("intrahepatic duct"),3)
    return
    :*B0:Ihdd1::
        sendByClipboard(StringUpperFirst("intrahepatic ducts"),4)
    return
    :cB0:Lv::
        sendByClipboard(StringUpperFirst("liver" A_EndChar),2)
    return
    :B0:Llv::
        sendByClipboard(StringUpperFirst("left lobe of liver" A_EndChar),3)
    return
    :B0:Rlv::
        sendByClipboard(StringUpperFirst("right lobe of liver" A_EndChar),3)
    return
    :B0:Blv::
        sendByClipboard(StringUpperFirst("both lobes of liver" A_EndChar),3)
    return
    :B0:Kd::
        sendByClipboard(StringUpperFirst("kidney" A_EndChar),2)
    return
    :*B0:Kd1::
        sendByClipboard(StringUpperFirst("kidneys"),2)
    return
    :B0:Lk::
        sendByClipboard(StringUpperFirst("left kidney" A_EndChar),2)
    return
    :B0:Rk::
        sendByClipboard(StringUpperFirst("right kidney" A_EndChar),2)
    return
    :B0:Bk::
        sendByClipboard(StringUpperFirst("bilateral kidneys" A_EndChar),2)
    return
    :B0:Duo::
        sendByClipboard(StringUpperFirst("duodenum" A_EndChar),3)
    return
    :*B0:Duo1::
        sendByClipboard(StringUpperFirst("duodenal"),3)
    return
    :B0:Jej::
        sendByClipboard(StringUpperFirst("jejunum" A_EndChar),3)
    return
    :*B0:Jej1::
        sendByClipboard(StringUpperFirst("jejunal"),3)
    return
    :B0:Ilm::
        sendByClipboard(StringUpperFirst("ileum" A_EndChar),3)
    return
    :*B0:Ilm1::
        sendByClipboard(StringUpperFirst("ileal"),3)
    return
    :B0:Icj::
        sendByClipboard(StringUpperFirst("ileocecal junction" A_EndChar),3)
    return
    :B0:Icvv::
        sendByClipboard(StringUpperFirst("ileocecal valve" A_EndChar),4)
    return
    :*B0:Ad1::
        sendByClipboard(StringUpperFirst("adrenals"),2)
    return
    :B0:Ag::
        sendByClipboard(StringUpperFirst("adrenal gland" A_EndChar),2)
    return
    :*B0:Ag1::
        sendByClipboard(StringUpperFirst("adrenal glands"),2)
    return
    :B0:Ab::
        sendByClipboard(StringUpperFirst("abdomen" A_EndChar),2)
    return
    :*B0:Ab1::
        sendByClipboard(StringUpperFirst("abdominal"),2)
    return
    :B0:Pel::
        sendByClipboard(StringUpperFirst("pelvic" A_EndChar),3)
    return
    :B0:Pev::
        sendByClipboard(StringUpperFirst("pelvic cavity" A_EndChar),3)
    return
    :B0:Pao::
        sendByClipboard(StringUpperFirst("para-aortic" A_EndChar),3)
    return
    :B0:Aoc::
        sendByClipboard(StringUpperFirst("aorto-caval" A_EndChar),3)
    return
    :B0:Asc::
        sendByClipboard(StringUpperFirst("ascites" A_EndChar),3)
    return
    :*B0:Sp0::
        sendByClipboard(StringUpperFirst("spondylosis of the lumbar spine with marginal osteophyte formation."),2)
    return
    :B0:Ph::
        sendByClipboard(StringUpperFirst("phlebolith" A_EndChar),2)
    return
    :*B0:Ph1::
        sendByClipboard(StringUpperFirst("phleboliths"),2)
    return
    :B0:Gs::
        sendByClipboard(StringUpperFirst("gallstone" A_EndChar),2)
    return
    :*B0:Gs1::
        sendByClipboard(StringUpperFirst("gallstones"),2)
    return
    :B0:Div::
        sendByClipboard(StringUpperFirst("diverticulum" A_EndChar),3)
    return
    :*B0:Div1::
        sendByClipboard(StringUpperFirst("diverticulosis"),3)
    return
    :*B0:Div2::
        sendByClipboard(StringUpperFirst("diverticulitis"),3)
    return
    :B0:Pan::
        sendByClipboard(StringUpperFirst("pancreas" A_EndChar),3)
    return
    :*B0:Pan1::
        sendByClipboard(StringUpperFirst("pancreatic"),3)
    return
    :B0:Pnh::
        sendByClipboard(StringUpperFirst("pancreatic head" A_EndChar),3)
    return
    :B0:Pnb::
        sendByClipboard(StringUpperFirst("pancreatic body" A_EndChar),3)
    return
    :B0:Pnt::
        sendByClipboard(StringUpperFirst("pancreatic tail" A_EndChar),3)
    return
    :B0:Pnd::
        sendByClipboard(StringUpperFirst("pancreatic duct" A_EndChar),3)
    return
    :B0:Per::
        sendByClipboard(StringUpperFirst("peritoneum" A_EndChar),3)
    return
    :*B0:Pers::
        sendByClipboard(StringUpperFirst("peritoneal seedings"),3)
    return
    :*B0:Pert::
        sendByClipboard(StringUpperFirst("peritoneal thickening"),3)
    return
    :*B0:Per1::
        sendByClipboard(StringUpperFirst("peritoneal"),3)
    return
    :*B0:Pecr::
        sendByClipboard(StringUpperFirst("peritoneal carcinomatosis"),3)
    return
    :B0:Ptc::
        sendByClipboard(StringUpperFirst("peritoneal cavity" A_EndChar),3)
    return
    :B0:Rpr::
        sendByClipboard(StringUpperFirst("retroperitoneum" A_EndChar),3)
    return
    :*B0:Rpr1::
        sendByClipboard(StringUpperFirst("retroperitoneal"),3)
    return
    :B0:App::
        sendByClipboard(StringUpperFirst("appendix" A_EndChar),3)
    return
    :B0:Chs::
        sendByClipboard(StringUpperFirst("cholecystitis" A_EndChar),3)
    return
    :*B0:Chs1::
        sendByClipboard(StringUpperFirst("acute cholecystitis"),3)
    return
    :B0:Lvpr::
        sendByClipboard(StringUpperFirst("hypremic change of the surrounding liver parenchyma" A_EndChar),4)
    return
    :B0:Aps::
        sendByClipboard(StringUpperFirst("appendicitis" A_EndChar),3)
    return
    :*B0:Aps1::
        sendByClipboard(StringUpperFirst("acute appendicitis"),3)
    return
    :B0:Pas::
        sendByClipboard(StringUpperFirst("pancreatitis" A_EndChar),3)
    return
    :*B0:Pas1::
        sendByClipboard(StringUpperFirst("acute pancreatitis"),3)
    return
    :*B0:Pas2::
        sendByClipboard(StringUpperFirst("chronic pancreatitis"),3)
    return
    :B0:Djdl::
        sendByClipboard(StringUpperFirst("degenerative change of lumbar spine" A_EndChar),4)
    return
    :B0:Acol::
        sendByClipboard(StringUpperFirst("ascending colon" A_EndChar),4)
    return
    :B0:Tcol::
        sendByClipboard(StringUpperFirst("transverse colon" A_EndChar),4)
    return
    :B0:Dcol::
        sendByClipboard(StringUpperFirst("descending colon" A_EndChar),4)
    return
    :B0:Sigc::
        sendByClipboard(StringUpperFirst("sigmoid colon" A_EndChar),4)
    return
    :B0:Rect::
        sendByClipboard(StringUpperFirst("rectum" A_EndChar),4)
    return
    :*B0:Pro1::
        sendByClipboard(StringUpperFirst("enlarged prostate with calcification."),3)
    return
    :*B0:Pro2::
        sendByClipboard(StringUpperFirst("enlarged prostate with nodular enhancement and calcification."),3)
    return
    :*B0:Pro3::
        sendByClipboard(StringUpperFirst("enlarged prostate with intravesical protrusion."),3)
    return
    :B0:Ipp::
        sendByClipboard(StringUpperFirst("intravesical protrusion" A_EndChar),3)
    return
    :*B0:Cr1::
        sendByClipboard(StringUpperFirst("cirrhotic change"),2)
    return
    :*B0:Cr0::
        sendByClipboard(StringUpperFirst("Uneven surface and coarse architecture of liver, cirrhosis is considered."),2)
    return
    :B0:Cct::
        sendByClipboard(StringUpperFirst("cholecystectomy" A_EndChar),3)
    return
    :*B0:Cct0::
        sendByClipboard(StringUpperFirst("status post cholecystectomy with mild dilatation of bile ducts."),3)
    return
    :B0:Cy::
        sendByClipboard(StringUpperFirst("cyst" A_EndChar),2)
    return
    :*B0:Cy1::
        sendByClipboard(StringUpperFirst("cysts"),2)
    return
    :B0:Clg::
        sendByClipboard(StringUpperFirst("cholangiocarcinoma" A_EndChar),3)
    return
    :B0:Ftc::
        sendByClipboard(StringUpperFirst("fatty change" A_EndChar),3)
    return
    :B0:Rc::
        sendByClipboard(StringUpperFirst("renal cyst" A_EndChar),2)
    return
    :B0:Rrc::
        sendByClipboard(StringUpperFirst("right renal cyst" A_EndChar),3)
    return
    :B0:Lrc::
        sendByClipboard(StringUpperFirst("left renal cyst" A_EndChar),3)
    return
    :*B0:Rc1::
        sendByClipboard(StringUpperFirst("renal cysts"),2)
    return
    :*B0:Rrc1::
        sendByClipboard(StringUpperFirst("right renal cysts"),3)
    return
    :*B0:Lrc1::
        sendByClipboard(StringUpperFirst("left renal cysts"),3)
    return
    :B0:Hc::
        sendByClipboard(StringUpperFirst("hepatic cyst" A_EndChar),2)
    return
    :*B0:Hc1::
        sendByClipboard(StringUpperFirst("hepatic cysts"),2)
    return
    :*B0:Lc0::
        sendByClipboard(StringUpperFirst("Multiple small cysts in both hepatic lobes."),2)
    return
    :*B0:Lc1::
        sendByClipboard(StringUpperFirst("liver cysts"),2)
    return
    :B0:Sn::
        sendByClipboard(StringUpperFirst("spleen" A_EndChar),2)
    return
    :*B0:Sn1::
        sendByClipboard(StringUpperFirst("splenic"),2)
    return
    :*B0:Snn::
        sendByClipboard(StringUpperFirst("splenic nodule"),2)
    return
    :*B0:Snn1::
        sendByClipboard(StringUpperFirst("splenic nodules"),3)
    return
    :B0:Hdn::
        sendByClipboard(StringUpperFirst("hydronephrosis" A_EndChar),3)
    return
    :B0:Smg::
        sendByClipboard(StringUpperFirst("splenomegaly" A_EndChar),3)
    return
    :B0:Hmg::
        sendByClipboard(StringUpperFirst("hepatomegaly" A_EndChar),3)
    return
    :B0:Hsmg::
        sendByClipboard(StringUpperFirst("hepatosplenomegaly" A_EndChar),4)
    return
    :B0:Acs::
        sendByClipboard(StringUpperFirst("accessory spleen" A_EndChar),3)
    return
    :B0:Lni::
        sendByClipboard(StringUpperFirst("nonspecific lymph node(s) at bilateral inguinal areas." A_EndChar),3)
    return
    :B0:Uph::
        sendByClipboard(StringUpperFirst("urolithiasis or phlebolith" A_EndChar),3)
    return
    :B0:Ul::
        sendByClipboard(StringUpperFirst("urolithiasis" A_EndChar),2)
    return
    :B0:Nhpd::
        sendByClipboard(StringUpperFirst("normal hepatic perfusion defect" A_EndChar),4)
    return
    :*B0:Nhpd0::
        sendByClipboard(StringUpperFirst("normal hepatic perfusion defect at S4b adjacent to the fissure of the ligamentum teres."),4)
    return
    :B0:Fm::
        sendByClipboard(StringUpperFirst("fecal material" A_EndChar),2)
    return
    :B0:Pba::
        sendByClipboard(StringUpperFirst("pneumobilia" A_EndChar),3)
    return
    :B0:Chila::
        sendByClipboard(StringUpperFirst("Hepatodiaphragmatic interposition of the colon (Chilaiditi syndrome)." A_EndChar),5)
    return
    :B0:Gev::
        sendByClipboard(StringUpperFirst("gastroesophageal varices" A_EndChar),3)
    return
    :B0:Gav::
        sendByClipboard(StringUpperFirst("gastric varices" A_EndChar),3)
    return
    :B0:Esv::
        sendByClipboard(StringUpperFirst("esophageal varices" A_EndChar),3)
    return
    :B0:Srs::
        sendByClipboard(StringUpperFirst("splenorenal shunts" A_EndChar),3)
    return
    :B0:Vrc::
        sendByClipboard(StringUpperFirst("varices" A_EndChar),3)
    return
    :B0:Ing::
        sendByClipboard(StringUpperFirst("inguinal" A_EndChar),3)
    return
    :B0:Inga::
        sendByClipboard(StringUpperFirst("inguinal area" A_EndChar),4)
    return
    :B0:Unc::
        sendByClipboard(StringUpperFirst("uncinate process" A_EndChar),3)
    return
    :B0:Ampv::
        sendByClipboard(StringUpperFirst("Periampullary lesions can not be totally excluded by the CT or MR study." A_EndChar),4)
    return
    :B0:Anc::
        sendByClipboard(StringUpperFirst("acute necrotic collection" A_EndChar),3)
    return
    :B0:Apfc::
        sendByClipboard(StringUpperFirst("acute peripancreatic fluid collection" A_EndChar),4)
    return
    :B0:Apn::
        sendByClipboard(StringUpperFirst("acute pyelonephritis" A_EndChar),3)
    return
    :B0:Apt::
        sendByClipboard(StringUpperFirst("arterioportal shunt" A_EndChar),3)
    return
    :B0:Apc::
        sendByClipboard(StringUpperFirst("appendicolith" A_EndChar),3)
    return
    :*B0:Brcy::
        sendByClipboard(StringUpperFirst("Bartholin cyst"),3)
    return
    :B0:Biha::
        sendByClipboard(StringUpperFirst("biliary hamartoma (von Meyenburg complex)" A_EndChar),4)
    return
    :B0:Bnk1::
        sendByClipboard(StringUpperFirst("Bosniak category 1 of renal cystic neosplasm is considered." A_EndChar),4)
    return
    :B0:Bp0::
        sendByClipboard(StringUpperFirst("The bile ducts and the pancreatic duct are not dilated." A_EndChar),3)
    return
    :B0:Bti::
        sendByClipboard(StringUpperFirst("biliary tract infection" A_EndChar),3)
    return
    :B0:Bit::
        sendByClipboard(StringUpperFirst("biliary tracts" A_EndChar),3)
    return
    :*B0:Bit0::
        sendByClipboard(StringUpperFirst("no definite filling defect in the biliary tracts."),3)
    return
    :B0:Cvtr::
        sendByClipboard(StringUpperFirst("cavernous transformation" A_EndChar),4)
    return
    :*B0:Ciaa::
        sendByClipboard(StringUpperFirst("common iliac artery"),3)
    return
    :*B0:Ciaa1::
        sendByClipboard(StringUpperFirst("common iliac arteries"),4)
    return
    :*B0:Eiaa::
        sendByClipboard(StringUpperFirst("external iliac artery"),3)
    return
    :*B0:Eiaa1::
        sendByClipboard(StringUpperFirst("external iliac arteries"),4)
    return
    :*B0:Iiaa::
        sendByClipboard(StringUpperFirst("internal iliac artery"),3)
    return
    :*B0:Iiaa1::
        sendByClipboard(StringUpperFirst("internal iliac arteries"),4)
    return
    :*B0:Civv::
        sendByClipboard(StringUpperFirst("common iliac vein"),3)
    return
    :*B0:Civv1::
        sendByClipboard(StringUpperFirst("common iliac veins"),4)
    return
    :*B0:Eivv::
        sendByClipboard(StringUpperFirst("external iliac vein"),3)
    return
    :*B0:Eivv1::
        sendByClipboard(StringUpperFirst("external iliac veins"),4)
    return
    :*B0:Iivv::
        sendByClipboard(StringUpperFirst("internal iliac vein"),3)
    return
    :*B0:Iivv1::
        sendByClipboard(StringUpperFirst("internal iliac veins"),4)
    return
    :B0:Cnd::
        sendByClipboard(StringUpperFirst("cirrhotic nodule" A_EndChar),3)
    return
    :*B0:Crn1::
        sendByClipboard(StringUpperFirst("cirrhotic nodules"),3)
    return
    :B0:Dnd::
        sendByClipboard(StringUpperFirst("dysplastic nodule" A_EndChar),3)
    return
    :*B0:Dnd1::
        sendByClipboard(StringUpperFirst("dysplastic nodules"),3)
    return
    :B0:Rnd::
        sendByClipboard(StringUpperFirst("regenerative nodule" A_EndChar),3)
    return
    :*B0:Rnd1::
        sendByClipboard(StringUpperFirst("regenerative nodules"),3)
    return
    :B0:Pts::
        sendByClipboard(StringUpperFirst("peritonitis" A_EndChar),3)
    return
    :B0:Wav::
        sendByClipboard(StringUpperFirst("washout on venous phase" A_EndChar),3)
    return
    :*B0:Hcc0::
        sendByClipboard(StringUpperFirst("hypodense lesion on precontrast, hyperdensity on arterial phase and rapid washout on venous phase; compatible with typical HCC."),3)
    return
    :*B0:Hem0::
        sendByClipboard(StringUpperFirst("hypodense lesion on precontrast, peripheral dot-like enhancement on arterial phase, and progressive filling-in on venous phase; compatible with liver hemangioma."),3)
    return
    :*B0:Hem1::
        sendByClipboard(StringUpperFirst("isodense lesion on precontrast, global enhancement on arterial phase, and persistent enhancement on venous phase; compatible with liver hemangioma."),3)
    return
    :*B0:Ctap0::
        sendByClipboard(StringUpperFirst("CTAP was performed with tip in the SMA orifice, 2ml/sec, delayed 30 sec, total 50 ml:"),4)
    return
    :B0:Ctss::
        sendByClipboard(StringUpperFirst("(Non-enhanced CT study is not sensitive and specific for the detection of focal lesions in the abdominal organs)" A_EndChar),4)
    return
    :B0:Ctst::
        sendByClipboard(StringUpperFirst("NECT and CECT of abdomen and pelvis with air and water distention of the stomach for evaluation:" A_EndChar),4)
    return
    :B0:Ctco::
        sendByClipboard(StringUpperFirst("NECT and CECT of abdomen and pelvis for colon cancer with air distention:" A_EndChar),4)
    return
    :B0:Dud::
        sendByClipboard(StringUpperFirst("duodenal diverticulum." A_EndChar),3)
    return
    :B0:Fra::
        sendByClipboard(StringUpperFirst("free air" A_EndChar),3)
    return
    :B0:Ety::
        sendByClipboard(StringUpperFirst("enterostomy" A_EndChar),3)
    return
    :B0:Sep::
        sendByClipboard(StringUpperFirst("sclerosing encapsulating peritonitis" A_EndChar),3)
    return
    :*B0:Mrfl::
        sendByClipboard(StringUpperFirst("Heterogeneous decreased signal of the liver on out-of-phase images as compared with in-phase images, suggestive of fatty liver."),3)
    return
    :B0:Fga::
        sendByClipboard(StringUpperFirst("focal type of the gallbladder adenomyomatosis" A_EndChar),3)
    return
    :B0:Gc::
        sendByClipboard(StringUpperFirst("greater curvature" A_EndChar),2)
    return
    :B0:Lc::
        sendByClipboard(StringUpperFirst("lesser curvature" A_EndChar),2)
    return
    :B0:Gcs::
        sendByClipboard(StringUpperFirst("greater curvature side" A_EndChar),3)
    return
    :B0:Lcs::
        sendByClipboard(StringUpperFirst("lesser curvature side" A_EndChar),3)
    return
    :B0:Ghll::
        sendByClipboard(StringUpperFirst("gastrohepatic ligament" A_EndChar),4)
    return
    :B0:Hmc::
        sendByClipboard(StringUpperFirst("hemorrhagic cyst" A_EndChar),3)
    return
    :B0:Hdll::
        sendByClipboard(StringUpperFirst("hepatoduodenal ligament" A_EndChar),4)
    return
    :B0:Hfx::
        sendByClipboard(StringUpperFirst("hepatic flexure" A_EndChar),3)
    return
    :B0:Sfx::
        sendByClipboard(StringUpperFirst("splenic flexure" A_EndChar),3)
    return
    :B0:Hhl::
        sendByClipboard(StringUpperFirst("hepatic hilum" A_EndChar),3)
    return
    :B0:Owrs::
        sendByClipboard(StringUpperFirst("Osler-Weber-Rendu syndrome" A_EndChar),4)
    return
    :B0:Htu::
        sendByClipboard(StringUpperFirst("hepatic tumor" A_EndChar),3)
    return
    :*B0:Htu1::
        sendByClipboard(StringUpperFirst("hepatic tumors"),3)
    return
    :*B0:Hv0::
        sendByClipboard(StringUpperFirst("Hepatic veins and portal veins are patent."),2)
    return
    :B0:Itpi::
        sendByClipboard(StringUpperFirst("status post intrathecal pump implantation" A_EndChar),4)
    return
    :B0:Jjy::
        sendByClipboard(StringUpperFirst("jejunostomy" A_EndChar),3)
    return
    :B0:Ily::
        sendByClipboard(StringUpperFirst("ileostomy" A_EndChar),3)
    return
    :B0:Cny::
        sendByClipboard(StringUpperFirst("colostomy" A_EndChar),3)
    return
    :B0:Amll::
        sendByClipboard(StringUpperFirst("angiomyolipoma" A_EndChar),4)
    return
    :B0:Lsg::
        sendByClipboard(StringUpperFirst("lateral segment" A_EndChar),3)
    return
    :B0:Msg::
        sendByClipboard(StringUpperFirst("medial segment" A_EndChar),3)
    return
    :B0:Crsm::
        sendByClipboard(StringUpperFirst("cirrhosis with splenomegaly" A_EndChar),4)
    return
    :B0:Lcy::
        sendByClipboard(StringUpperFirst("Multiple small low density nodules are noted in the liver; liver cysts are considered in current status." A_EndChar),3)
    return
    :*B0:Lcy1::
        sendByClipboard(StringUpperFirst("A small low density nodule in the liver; liver cyst is considered in current status."),3)
    return
    :B0:Hon::
        sendByClipboard(StringUpperFirst("hypodense nodule" A_EndChar),3)
    return
    :*B0:Hon1::
        sendByClipboard(StringUpperFirst("hypodense nodules"),3)
    return
    :*B0:Lrst::
        sendByClipboard(StringUpperFirst("left renal stone"),3)
    return
    :*B0:Lrss::
        sendByClipboard(StringUpperFirst("left renal stones"),3)
    return
    :*B0:Rrss::
        sendByClipboard(StringUpperFirst("right renal stones"),3)
    return
    :*B0:Rrst::
        sendByClipboard(StringUpperFirst("right renal stone"),3)
    return
    :B0:Rne::
        sendByClipboard(StringUpperFirst("renal stone" A_EndChar),3)
    return
    :*B0:Rne1::
        sendByClipboard(StringUpperFirst("renal stones"),3)
    return
    :B0:Ne::
        sendByClipboard(StringUpperFirst("stone" A_EndChar),2)
    return
    :*B0:Ne1::
        sendByClipboard(StringUpperFirst("stones"),2)
    return
    :*B0:Brst::
        sendByClipboard(StringUpperFirst("bilateral renal stones"),3)
    return
    :*B0:Mrcp0::
        sendByClipboard(StringUpperFirst("MRCP reveals no evidence of bile ducts or pancreatic duct dilatation; no anomalous pancreaticobiliary union."),4)
    return
    :*B0:Mrcn::
        sendByClipboard(StringUpperFirst("Cirrhotic nodules in both lobes of liver, mixed with regenerative nodules and dysplastic nodules, presenting as hyperintensity on T1WI, hypointensity on T2WI, and no enhancement."),3)
    return
    :*B0:Mrdn::
        sendByClipboard(StringUpperFirst("with increased hyperintensity on T1WI, isointensity to hypointensity on T2WI and no definite enhancement after contrast media injection; dysplastic nodules are favored."),3)
    return
    :*B0:Mrfnh::
        sendByClipboard(StringUpperFirst("slight hypointensity on T1WI, slight hyperintensity on T2WI, and global enhancement on early arterial phase, near isointensity on delayed enhanced images; compatible with FNH."),4)
    return
    :*B0:Mrhcc::
        sendByClipboard(StringUpperFirst("hypointensity on T1WI, slight hyperintensity on T2WI, and global enhancement on early arterial phase, rapid washout on delayed enhanced images; compatible with HCC."),4)
    return
    :*B0:Mrhem::
        sendByClipboard(StringUpperFirst("hypointensity on T1WI, hyperintensity on T2WI, and peripheral patches enhancement on dynamic contrast-enhanced study, persistent enhancement on delayed contrast-enhanced images; compatible with liver hemangioma."),4)
    return
    :*B0:Mrprca::
        sendByClipboard(StringUpperFirst("with hypointensity on T2WI, diffusion restriction on DWI/ADC, and early enhancement in early dynamic study; compatible with prostate cancer."),5)
    return
    :B0:Umy::
        sendByClipboard(StringUpperFirst("uterine myoma" A_EndChar),3)
    return
    :B0:Uma::
        sendByClipboard(StringUpperFirst("uterine mass" A_EndChar),3)
    return
    :*B0:Uma1::
        sendByClipboard(StringUpperFirst("uterine masses"),3)
    return
    :B0:Utn::
        sendByClipboard(StringUpperFirst("uterine nodule" A_EndChar),3)
    return
    :*B0:Utn1::
        sendByClipboard(StringUpperFirst("uterine nodules"),3)
    return
    :B0:Utr::
        sendByClipboard(StringUpperFirst("uterus" A_EndChar),3)
    return
    :*B0:Utr1::
        sendByClipboard(StringUpperFirst("uterine"),3)
    return
    :B0:Umx::
        sendByClipboard(StringUpperFirst("uterine mass(es) and bilateral adnexal cystic lesions" A_EndChar),3)
    return
    :B0:Net::
        sendByClipboard(StringUpperFirst("neuroendocrine tumor" A_EndChar),3)
    return
    :B0:Nfla::
        sendByClipboard(StringUpperFirst("no definite focal lesion in the abdomen." A_EndChar),4)
    return
    :B0:Nflp::
        sendByClipboard(StringUpperFirst("no definite focal lesion in the pelvis." A_EndChar),4)
    return
    :B0:Ncl::
        sendByClipboard(StringUpperFirst("nodular and contracted liver contour" A_EndChar),3)
    return
    :B0:Notae::
        sendByClipboard(StringUpperFirst("The imaging pattern hints the limited effect of embolization and increased/aggravated liver cirrhosis if embolization; clinical follow up or local treatment is more favored. Liver transplantation is also considered." A_EndChar),5)
    return
    :B0:Oble::
        sendByClipboard(StringUpperFirst("obstructive level" A_EndChar),4)
    return
    :B0:Opcolon::
        sendByClipboard(StringUpperFirst("operative change of the colon; no evidence of local recurrence is noted; non-specific bowel gas distribution is noted." A_EndChar),7)
    return
    :B0:Opgyn::
        sendByClipboard(StringUpperFirst("status post operative change of the gynecological organs; no evidence of local recurrence is noted." A_EndChar),5)
    return
    :B0:Opkidney::
        sendByClipboard(StringUpperFirst("operative change of the kidney; no evidence of local recurrence is noted;" A_EndChar),8)
    return
    :B0:Opstomach::
        sendByClipboard(StringUpperFirst("operative change of the stomach; no evidence of local recurrence is noted; non-specific bowel gas distribution is noted." A_EndChar),9)
    return
    :B0:Paa::
        sendByClipboard(StringUpperFirst("porcelain abdominal aorta" A_EndChar),3)
    return
    :B0:Pcs::
        sendByClipboard(StringUpperFirst("portocaval space" A_EndChar),3)
    return
    :B0:Phs::
        sendByClipboard(StringUpperFirst("perihepatic space" A_EndChar),3)
    return
    :B0:Pnin::
        sendByClipboard(StringUpperFirst("pneumatosis intestinalis" A_EndChar),4)
    return
    :B0:Pjsy::
        sendByClipboard(StringUpperFirst("Peutz-Jeghers syndrome" A_EndChar),4)
    return
    :B0:Pmf::
        sendByClipboard(StringUpperFirst("peripheral mass-forming type of cholangiocarcinoma" A_EndChar),3)
    return
    :B0:Primo::
        sendByClipboard(StringUpperFirst(" Primovist MR study may be considered in next followed study (liver specific MR contrast medium; specially arranged; please call MR room 62540 for arrangement; or Dr. A 51685 or Dr. B 53315)." A_EndChar),5)
    return
    :B0:Psco::
        sendByClipboard(StringUpperFirst("phlebosclerotic colitis" A_EndChar),4)
    return
    :B0:Pv::
        sendByClipboard(StringUpperFirst("portal vein" A_EndChar),2)
    return
    :B0:Pvt::
        sendByClipboard(StringUpperFirst("portal vein thrombosis" A_EndChar),3)
    return
    :B0:Cz::
        sendByClipboard(StringUpperFirst("central zone" A_EndChar),2)
    return
    :B0:Tz::
        sendByClipboard(StringUpperFirst("transitional zone" A_EndChar),2)
    return
    :B0:Pz::
        sendByClipboard(StringUpperFirst("peripheral zone" A_EndChar),2)
    return
    :B0:Sa1::
        sendByClipboard(StringUpperFirst("Study: monophasic abdominal CT, without contrast enhancement" A_EndChar),3)
    return
    :B0:Sa2::
        sendByClipboard(StringUpperFirst("Study: 2 phases of abdominal CT, without and with contrast enhancement" A_EndChar),3)
    return
    :B0:Sa3::
        sendByClipboard(StringUpperFirst("Study: 3 phases of abdominal CT, without and with (arterial and portal venous phases) contrast enhancement" A_EndChar),3)
    return
    :B0:Sa4::
        sendByClipboard(StringUpperFirst("Study: 4 phases of abdominal CT, without and with (arterial and portal venous and delayed phases) contrast enhancement" A_EndChar),3)
    return
    :B0:Co::
        sendByClipboard(StringUpperFirst("colon" A_EndChar),2)
    return
    :B0:Sb::
        sendByClipboard(StringUpperFirst("small bowels" A_EndChar),2)
    return
    :B0:Sbo::
        sendByClipboard(StringUpperFirst("small bowel obstruction" A_EndChar),3)
    return
    :B0:Sbtae::
        sendByClipboard(StringUpperFirst("The small bowel embolization is still a risky issue and the long-term follow-up evidence is still scant. Possible short term and long term of complications (perforation, stenosis, etc.) should be followed and alerted." A_EndChar),5)
    return
    :B0:Sbt::
        sendByClipboard(StringUpperFirst("Sengstaken-Blakemore tube" A_EndChar),3)
    return
    :B0:Bgh::
        sendByClipboard(StringUpperFirst("Brunner gland hyperplasia" A_EndChar),3)
    return
    :B0:Seml::
        sendByClipboard(StringUpperFirst("subepithelial mass lesion" A_EndChar),4)
    return
    :B0:Sfci::
        sendByClipboard(StringUpperFirst("suprapubic foley catheter insertion" A_EndChar),4)
    return
    :B0:Stece::
        sendByClipboard(StringUpperFirst("suspected stenosis of the celiac axis and IMA with dilated arc of Buhler, arc of Riolan, and marginal artery of Drummond." A_EndChar),5)
    return
    :B0:Seve::
        sendByClipboard(StringUpperFirst("seminal vesicle" A_EndChar),4)
    return
    :B0:Thad::
        sendByClipboard(StringUpperFirst("THAD (transient hepatic attenuation differences)" A_EndChar),4)
    return
    :B0:Tei::
        sendByClipboard(StringUpperFirst("terminal ileum" A_EndChar),3)
    return
    :*B0:Smcy::
        sendByClipboard(StringUpperFirst("The size of cysts is too small to be differentiated. Clinical follow-up or correlation is suggested."),3)
    return
    :B0:Uca::
        sendByClipboard(StringUpperFirst("uterine cavity" A_EndChar),3)
    return
    :B0:Ur::
        sendByClipboard(StringUpperFirst("ureter" A_EndChar),2)
    return
    :*B0:Lush::
        sendByClipboard(StringUpperFirst("left ureter stone causing hydronephrosis"),3)
    return
    :*B0:Rush::
        sendByClipboard(StringUpperFirst("right ureter stone causing hydronephrosis"),3)
    return
    :*B0:Bush::
        sendByClipboard(StringUpperFirst("bilateral ureter stones causing hydronephrosis"),3)
    return
    :*B0:Ur1::
        sendByClipboard(StringUpperFirst("ureteral"),2)
    return
    :B0:Urs::
        sendByClipboard(StringUpperFirst("ureter stone" A_EndChar),3)
    return
    :*B0:Urs1::
        sendByClipboard(StringUpperFirst("ureter stones"),3)
    return
    :*B0:Utii::
        sendByClipboard(StringUpperFirst("urinary tract infection"),3)
    return
    :B0:Vcugg::
        sendByClipboard(StringUpperFirst("voiding cystourethrography" A_EndChar),5)
    return
    :B0:Iab::
        sendByClipboard(StringUpperFirst("intraabdominal" A_EndChar),3)
    return
    :B0:Opl::
        sendByClipboard(StringUpperFirst("post-operative changes of lung." A_EndChar),3)
    return
    :*B0:Blggo::
        sendByClipboard(StringUpperFirst("which could be insufficient inspiration or pulmonary infection."),4)
    return
    :B0:Sili::
        sendByClipboard(StringUpperFirst("silicone granulomas" A_EndChar),4)
    return
    :*B0:Hr0::
        sendByClipboard(StringUpperFirst("no obvious structural cardiac abnormality."),2)
    return
    :B0:Ldm::
        sendByClipboard(StringUpperFirst("left deviation of mediastinal structures" A_EndChar),3)
    return
    :B0:Rdm::
        sendByClipboard(StringUpperFirst("right deviation of mediastinal structures" A_EndChar),3)
    return
    :*B0:Hpec::
        sendByClipboard(StringUpperFirst("hemopericardium"),3)
    return
    :B0:Htx::
        sendByClipboard(StringUpperFirst("hemothorax" A_EndChar),3)
    return
    :B0:Cry::
        sendByClipboard(StringUpperFirst("coronary" A_EndChar),3)
    return
    :*B0:Crst::
        sendByClipboard(StringUpperFirst("coronary stent"),3)
    return
    :*B0:Crst1::
        sendByClipboard(StringUpperFirst("coronary stents"),4)
    return
    :B0:Put::
        sendByClipboard(StringUpperFirst("pulmonary trunk" A_EndChar),3)
    return
    :B0:Mpa::
        sendByClipboard(StringUpperFirst("main pulmonary artery" A_EndChar),3)
    return
    :B0:Lpa::
        sendByClipboard(StringUpperFirst("left pulmonary artery" A_EndChar),3)
    return
    :B0:Rpa::
        sendByClipboard(StringUpperFirst("right pulmonary artery" A_EndChar),3)
    return
    :*B0:Lpa1::
        sendByClipboard(StringUpperFirst("left pulmonary arteries"),3)
    return
    :*B0:Rpa1::
        sendByClipboard(StringUpperFirst("right pulmonary arteries"),3)
    return
    :*B0:Lucn::
        sendByClipboard(StringUpperFirst("lung cancer"),3)
    return
    :*B0:Rlca::
        sendByClipboard(StringUpperFirst("right lung cancer"),3)
    return
    :*B0:Llca::
        sendByClipboard(StringUpperFirst("left lung cancer"),3)
    return
    :*B0:Escn::
        sendByClipboard(StringUpperFirst("esophageal cancer"),3)
    return
    :*B0:Brcn::
        sendByClipboard(StringUpperFirst("breast cancer"),3)
    return
    :*B0:Lbca::
        sendByClipboard(StringUpperFirst("left breast cancer"),3)
    return
    :*B0:Rbca::
        sendByClipboard(StringUpperFirst("right breast cancer"),3)
    return
    :B0:Ite::
        sendByClipboard(StringUpperFirst("intrathoracic extension" A_EndChar),3)
    return
    :B0:Mim::
        sendByClipboard(StringUpperFirst("mucus impaction" A_EndChar),3)
    return
    :B0:Mpg::
        sendByClipboard(StringUpperFirst("mucus plug" A_EndChar),3)
    return
    :*B0:Mpg1::
        sendByClipboard(StringUpperFirst("mucus plugs"),3)
    return
    :B0:Enb::
        sendByClipboard(StringUpperFirst("endobronchial" A_EndChar),3)
    return
    :B0:Bks::
        sendByClipboard(StringUpperFirst("bronchiectasis, peribronchial tiny (<6mm) nodules and bronchial wall thickening" A_EndChar),3)
    return
    :B0:Pfd::
        sendByClipboard(StringUpperFirst("juxtapleural nodule" A_EndChar),3)
    return
    :*B0:Pfd1::
        sendByClipboard(StringUpperFirst("juxtapleural nodules"),3)
    return
    :B0:Bwt::
        sendByClipboard(StringUpperFirst("bronchial wall thickening" A_EndChar),3)
    return
    :B0:Pls::
        sendByClipboard(StringUpperFirst("pleural seedings" A_EndChar),3)
    return
    :B0:Plm::
        sendByClipboard(StringUpperFirst("pleural metastasis" A_EndChar),3)
    return
    :*B0:Plm1::
        sendByClipboard(StringUpperFirst("pleural metastases"),3)
    return
    :B0:Blm::
        sendByClipboard(StringUpperFirst("bilateral lung metastases" A_EndChar),3)
    return
    :*B0:Blml::
        sendByClipboard(StringUpperFirst("bilateral lung metastases, larger."),3)
    return
    :*B0:Blms::
        sendByClipboard(StringUpperFirst("bilateral lung metastases, smaller."),3)
    return
    :B0:Lbm::
        sendByClipboard(StringUpperFirst("bilateral lung and bone metastases." A_EndChar),3)
    return
    :*B0:Blpm::
        sendByClipboard(StringUpperFirst("bilateral lung, pleural and bone metastases."),3)
    return
    :*B0:Rulb::
        sendByClipboard(StringUpperFirst("RUL lobectomy"),3)
    return
    :*B0:Rmlb::
        sendByClipboard(StringUpperFirst("RML lobectomy"),3)
    return
    :*B0:Rllb::
        sendByClipboard(StringUpperFirst("RLL lobectomy"),3)
    return
    :*B0:Lulb::
        sendByClipboard(StringUpperFirst("LUL lobectomy"),3)
    return
    :*B0:Lllb::
        sendByClipboard(StringUpperFirst("LLL lobectomy"),3)
    return
    :*B0:Ruls::
        sendByClipboard(StringUpperFirst("RUL segmentectomy"),3)
    return
    :*B0:Rmls::
        sendByClipboard(StringUpperFirst("RML segmentectomy"),3)
    return
    :*B0:Rlls::
        sendByClipboard(StringUpperFirst("RLL segmentectomy"),3)
    return
    :*B0:Luls::
        sendByClipboard(StringUpperFirst("LUL segmentectomy"),3)
    return
    :*B0:Llls::
        sendByClipboard(StringUpperFirst("LLL segmentectomy"),3)
    return
    :*B0:Rulw::
        sendByClipboard(StringUpperFirst("RUL wedge resection"),3)
    return
    :*B0:Rmlw::
        sendByClipboard(StringUpperFirst("RML wedge resection"),3)
    return
    :*B0:Rllw::
        sendByClipboard(StringUpperFirst("RLL wedge resection"),3)
    return
    :*B0:Lulw::
        sendByClipboard(StringUpperFirst("LUL wedge resection"),3)
    return
    :*B0:Lllw::
        sendByClipboard(StringUpperFirst("LLL wedge resection"),3)
    return
    :B0:Blc::
        sendByClipboard(StringUpperFirst("bilateral lung consolidation" A_EndChar),3)
    return
    :B0:Blo::
        sendByClipboard(StringUpperFirst("bilateral lung opacities" A_EndChar),3)
    return
    :B0:Rmi::
        sendByClipboard(StringUpperFirst("status post right mastectomy with breast implant." A_EndChar),3)
    return
    :B0:Lmi::
        sendByClipboard(StringUpperFirst("status post left mastectomy with breast implant." A_EndChar),3)
    return
    :B0:Bmi::
        sendByClipboard(StringUpperFirst("status post bilateral mastectomy with breast implant." A_EndChar),3)
    return
    :*B0:Rtrm::
        sendByClipboard(StringUpperFirst("post-radiation change at right medial lung."),3)
    return
    :*B0:Rtlm::
        sendByClipboard(StringUpperFirst("post-radiation change at left medial lung."),3)
    return
    :*B0:Rtbm::
        sendByClipboard(StringUpperFirst("post-radiation change at bilateral medial lung."),3)
    return
    :B0:Stf::
        sendByClipboard(StringUpperFirst("unchanged thoracic findings." A_EndChar),3)
    return
    :B0:Sf::
        sendByClipboard(StringUpperFirst("unchanged findings." A_EndChar),2)
    return
    :B0:Osf::
        sendByClipboard(StringUpperFirst("other unchanged findings." A_EndChar),3)
    return
    :B0:Rsf::
        sendByClipboard(StringUpperFirst("roughly unchanged findings." A_EndChar),3)
    return
    :B0:Bln::
        sendByClipboard(StringUpperFirst("bilateral lung nodules" A_EndChar),3)
    return
    :B0:Tbln::
        sendByClipboard(StringUpperFirst("tiny bilateral lung nodules" A_EndChar),4)
    return
    :*B0:Tblns::
        sendByClipboard(StringUpperFirst("tiny bilateral lung nodules, unchanged."),4)
    return
    :B0:Tln::
        sendByClipboard(StringUpperFirst("tiny lung nodules" A_EndChar),3)
    return
    :*B0:Tlns::
        sendByClipboard(StringUpperFirst("tiny lung nodules, unchanged."),3)
    return
    :B0:Lns::
        sendByClipboard(StringUpperFirst("lung nodules, unchanged." A_EndChar),3)
    return
    :B0:Psn::
        sendByClipboard(StringUpperFirst("part-solid nodule" A_EndChar),3)
    return
    :B0:Ssl::
        sendByClipboard(StringUpperFirst("sub-solid nodule" A_EndChar),3)
    return
    :*B0:Segt::
        sendByClipboard(StringUpperFirst("segmentectomy"),3)
    return
    :*B0:Pnut::
        sendByClipboard(StringUpperFirst("pneumectomy"),3)
    return
    :*B0:Ldct/::
        sendByClipboard(StringUpperFirst("(Low dose CT is incompetent for soft tissue lesion detection.)"),4)
    return
    :B0:Tpm::
        sendByClipboard(StringUpperFirst("temporary pacemaker" A_EndChar),3)
    return
    :B0:Tef::
        sendByClipboard(StringUpperFirst("tracheoesophageal fistula" A_EndChar),3)
    return
    :*B0:Lbrc::
        sendByClipboard(StringUpperFirst("left breast cancer"),3)
    return
    :*B0:Rbrc::
        sendByClipboard(StringUpperFirst("right breast cancer"),3)
    return
    :B0:Lbr::
        sendByClipboard(StringUpperFirst("left breast" A_EndChar),3)
    return
    :B0:Rbr::
        sendByClipboard(StringUpperFirst("right breast" A_EndChar),3)
    return
    :B0:Bbr::
        sendByClipboard(StringUpperFirst("bilateral breasts" A_EndChar),3)
    return
    :B0:Lcw::
        sendByClipboard(StringUpperFirst("lateral chest wall" A_EndChar),3)
    return
    :B0:Acw::
        sendByClipboard(StringUpperFirst("anterior chest wall" A_EndChar),3)
    return
    :B0:Rbn::
        sendByClipboard(StringUpperFirst("right breast nodule" A_EndChar),3)
    return
    :B0:Lbn::
        sendByClipboard(StringUpperFirst("left breast nodule" A_EndChar),3)
    return
    :B0:Bbn::
        sendByClipboard(StringUpperFirst("bilateral breast nodules" A_EndChar),3)
    return
    :B0:Rbc::
        sendByClipboard(StringUpperFirst("right breast calcification(s)" A_EndChar),3)
    return
    :B0:Lbc::
        sendByClipboard(StringUpperFirst("left breast calcification(s)" A_EndChar),3)
    return
    :B0:Bbc::
        sendByClipboard(StringUpperFirst("bilateral breast calcifications" A_EndChar),3)
    return
    :B0:Brc::
        sendByClipboard(StringUpperFirst("breast calcification" A_EndChar),3)
    return
    :*B0:Brc1::
        sendByClipboard(StringUpperFirst("breast calcifications"),3)
    return
    :B0:Brn::
        sendByClipboard(StringUpperFirst("breast nodule" A_EndChar),3)
    return
    :*B0:Brn1::
        sendByClipboard(StringUpperFirst("breast nodules"),3)
    return
    :B0:Bim::
        sendByClipboard(StringUpperFirst("breast implant" A_EndChar),3)
    return
    :*B0:Bim1::
        sendByClipboard(StringUpperFirst("breast implants"),3)
    return
    :B0:Apw::
        sendByClipboard(StringUpperFirst("aortopulmonary window" A_EndChar),3)
    return
    :B0:Hnx::
        sendByClipboard(StringUpperFirst("hydropneumothorax" A_EndChar),3)
    return
    :B0:Slf::
        sendByClipboard(StringUpperFirst("unchanged lung findings." A_EndChar),3)
    return
    :B0:Llu::
        sendByClipboard(StringUpperFirst("left lung" A_EndChar),3)
    return
    :B0:Rlu::
        sendByClipboard(StringUpperFirst("right lung" A_EndChar),3)
    return
    :B0:Blu::
        sendByClipboard(StringUpperFirst("bilateral lungs" A_EndChar),3)
    return
    :B0:Plu::
        sendByClipboard(StringUpperFirst("pleura" A_EndChar),3)
    return
    :B0:Plb::
        sendByClipboard(StringUpperFirst("pleura-based" A_EndChar),3)
    return
    :B0:Moz::
        sendByClipboard(StringUpperFirst("mosaic attenuation" A_EndChar),3)
    return
    :B0:Thc::
        sendByClipboard(StringUpperFirst("thoracic" A_EndChar),3)
    return
    :B0:Ido::
        sendByClipboard(StringUpperFirst("ill-defined opacities" A_EndChar),3)
    return
    :*B0:Lmet::
        sendByClipboard(StringUpperFirst("Multiple bilateral lung nodules of varying sizes, suggestive of metastases"),3)
    return
    :B0:Ip::
        sendByClipboard(StringUpperFirst("interstitial pneumonitis" A_EndChar),2)
    return
    :B0:Hnc::
        sendByClipboard(StringUpperFirst("honeycombing" A_EndChar),3)
    return
    :B0:Cvr::
        sendByClipboard(StringUpperFirst("status post cardiac valve replacement." A_EndChar),3)
    return
    :B0:Prh::
        sendByClipboard(StringUpperFirst("perihilar" A_EndChar),3)
    return
    :B0:Avv::
        sendByClipboard(StringUpperFirst("aortic valve" A_EndChar),3)
    return
    :B0:Pvv::
        sendByClipboard(StringUpperFirst("pulmonary valve" A_EndChar),3)
    return
    :B0:Mvv::
        sendByClipboard(StringUpperFirst("mitral valve" A_EndChar),3)
    return
    :B0:Tvv::
        sendByClipboard(StringUpperFirst("tricuspid valve" A_EndChar),3)
    return
    :B0:Vv::
        sendByClipboard(StringUpperFirst("valve" A_EndChar),2)
    return
    :*B0:Vv1::
        sendByClipboard(StringUpperFirst("valves"),2)
    return
    :B0:Cvv::
        sendByClipboard(StringUpperFirst("cardiac valve" A_EndChar),3)
    return
    :*B0:Cvv1::
        sendByClipboard(StringUpperFirst("cardiac valves"),3)
    return
    :B0:Mbn::
        sendByClipboard(StringUpperFirst("multiple bilateral lung nodules" A_EndChar),3)
    return
    :B0:Plr::
        sendByClipboard(StringUpperFirst("pleural retraction" A_EndChar),3)
    return
    :B0:Ibl::
        sendByClipboard(StringUpperFirst("in bilateral lungs" A_EndChar),3)
    return
    :B0:Irl::
        sendByClipboard(StringUpperFirst("in the right lung" A_EndChar),3)
    return
    :B0:Ill::
        sendByClipboard(StringUpperFirst("in the left lung" A_EndChar),3)
    return
    :B0:Ral::
        sendByClipboard(StringUpperFirst("right apical lung" A_EndChar),3)
    return
    :B0:Lal::
        sendByClipboard(StringUpperFirst("left apical lung" A_EndChar),3)
    return
    :*B0:Iral::
        sendByClipboard(StringUpperFirst("at right apical lung"),3)
    return
    :*B0:Ilal::
        sendByClipboard(StringUpperFirst("at left apical lung"),3)
    return
    :B0:Ith::
        sendByClipboard(StringUpperFirst("interstitial thickening" A_EndChar),3)
    return
    :B0:Chw::
        sendByClipboard(StringUpperFirst("chest wall" A_EndChar),3)
    return
    :B0:Scr::
        sendByClipboard(StringUpperFirst("subcarinal" A_EndChar),3)
    return
    :B0:Pbk::
        sendByClipboard(StringUpperFirst("peribronchial" A_EndChar),3)
    return
    :B0:Pbt::
        sendByClipboard(StringUpperFirst("peribronchial thickening" A_EndChar),3)
    return
    :B0:Ptk::
        sendByClipboard(StringUpperFirst("paratracheal" A_EndChar),3)
    return
    :B0:Peo::
        sendByClipboard(StringUpperFirst("paraesophageal" A_EndChar),3)
    return
    :*B0:Ggos::
        sendByClipboard(StringUpperFirst("GGOs"),3)
    return
    :*B0:Mggo::
        sendByClipboard(StringUpperFirst("multiple GGOs"),3)
    return
    :B0:Ilg::
        sendByClipboard(StringUpperFirst("ill-defined GGO" A_EndChar),3)
    return
    :*B0:Ilg1::
        sendByClipboard(StringUpperFirst("ill-defined GGOs"),3)
    return
    :*B0:Milg::
        sendByClipboard(StringUpperFirst("multiple ill-defined GGOs"),3)
    return
    :*B0:Ggns::
        sendByClipboard(StringUpperFirst("GGNs"),3)
    return
    :*B0:Mggn::
        sendByClipboard(StringUpperFirst("multiple GGNs"),3)
    return
    :B0:Ggo::
        sendByClipboard(StringUpperFirst("GGO" A_EndChar),3)
    return
    :B0:Ggn::
        sendByClipboard(StringUpperFirst("GGN" A_EndChar),3)
    return
    :B0:Rml::
        sendByClipboard(StringUpperFirst("RML" A_EndChar),3)
    return
    :B0:Rul::
        sendByClipboard(StringUpperFirst("RUL" A_EndChar),3)
    return
    :B0:Rll::
        sendByClipboard(StringUpperFirst("RLL" A_EndChar),3)
    return
    :B0:Lul::
        sendByClipboard(StringUpperFirst("LUL" A_EndChar),3)
    return
    :B0:Lll::
        sendByClipboard(StringUpperFirst("LLL" A_EndChar),3)
    return
    :*B0:Irml::
        sendByClipboard(StringUpperFirst("in the RML"),3)
    return
    :*B0:Irul::
        sendByClipboard(StringUpperFirst("in the RUL"),3)
    return
    :*B0:Irll::
        sendByClipboard(StringUpperFirst("in the RLL"),3)
    return
    :*B0:Ilul::
        sendByClipboard(StringUpperFirst("in the LUL"),3)
    return
    :*B0:Illl::
        sendByClipboard(StringUpperFirst("in the LLL"),3)
    return
    :*B0:Ilin::
        sendByClipboard(StringUpperFirst("at the lingular LUL"),3)
    return
    :B0:Brll::
        sendByClipboard(StringUpperFirst("basal RLL" A_EndChar),4)
    return
    :B0:Blll::
        sendByClipboard(StringUpperFirst("basal LLL" A_EndChar),4)
    return
    :*B0:Tln1::
        sendByClipboard(StringUpperFirst("tiny lung nodules."),3)
    return
    :*B0:Lnl1::
        sendByClipboard(StringUpperFirst("lung nodules"),3)
    return
    :*B0:Nd0::
        sendByClipboard(StringUpperFirst("other tiny or probably non-specific lung nodules and minor or non-specific parenchymal changes of bilateral lung, suggest clinical correlation."),2)
    return
    :B0:Aos::
        sendByClipboard(StringUpperFirst("acute aortic syndrome" A_EndChar),3)
    return
    :B0:Brk::
        sendByClipboard(StringUpperFirst("bronchus" A_EndChar),3)
    return
    :*B0:Brk1::
        sendByClipboard(StringUpperFirst("bronchial"),3)
    return
    :*B0:Brk2::
        sendByClipboard(StringUpperFirst("bronchi"),3)
    return
    :B0:Lmb::
        sendByClipboard(StringUpperFirst("left main bronchus" A_EndChar),3)
    return
    :B0:Rmb::
        sendByClipboard(StringUpperFirst("right main bronchus" A_EndChar),3)
    return
    :B0:Tib::
        sendByClipboard(StringUpperFirst("tree-in-bud" A_EndChar),3)
    return
    :B0:Tin::
        sendByClipboard(StringUpperFirst("tree-in-bud nodules" A_EndChar),3)
    return
    :B0:Ttn::
        sendByClipboard(StringUpperFirst("tiny (<=4mm) tree-in-bud nodules" A_EndChar),3)
    return
    :B0:Rma::
        sendByClipboard(StringUpperFirst("respiratory motion artifacts" A_EndChar),3)
    return
    :*B0:Rma0::
        sendByClipboard(StringUpperFirst("respiratory motion artifacts are noted, which may obscure small lesions."),3)
    return
    :B0:Bpe::
        sendByClipboard(StringUpperFirst("bilateral pleural effusion" A_EndChar),3)
    return
    :B0:Rpe::
        sendByClipboard(StringUpperFirst("right pleural effusion" A_EndChar),3)
    return
    :B0:Lpe::
        sendByClipboard(StringUpperFirst("left pleural effusion" A_EndChar),3)
    return
    :*B0:Lpet::
        sendByClipboard(StringUpperFirst("left pleural effusion with pleural thickening"),3)
    return
    :*B0:Rpet::
        sendByClipboard(StringUpperFirst("right pleural effusion with pleural thickening"),3)
    return
    :*B0:Bpet::
        sendByClipboard(StringUpperFirst("bilateral pleural effusion with pleural thickening"),3)
    return
    :B0:Pfl::
        sendByClipboard(StringUpperFirst("previous fracture at left rib(s)." A_EndChar),3)
    return
    :B0:Pfr::
        sendByClipboard(StringUpperFirst("previous fracture at right rib(s)." A_EndChar),3)
    return
    :B0:Pflc::
        sendByClipboard(StringUpperFirst("previous fracture at left rib(s) and left clavicle." A_EndChar),4)
    return
    :B0:Pfrc::
        sendByClipboard(StringUpperFirst("previous fracture at right rib(s) and right clavicle." A_EndChar),4)
    return
    :B0:Pfb::
        sendByClipboard(StringUpperFirst("previous fractures at bilateral ribs." A_EndChar),3)
    return
    :B0:Bll::
        sendByClipboard(StringUpperFirst("bilateral lower lungs" A_EndChar),3)
    return
    :B0:Bul::
        sendByClipboard(StringUpperFirst("bilateral upper lungs" A_EndChar),3)
    return
    :B0:Bal::
        sendByClipboard(StringUpperFirst("bilateral apical lungs" A_EndChar),3)
    return
    :B0:Bml::
        sendByClipboard(StringUpperFirst("RML and lingular LUL" A_EndChar),3)
    return
    :B0:Em::
        sendByClipboard(StringUpperFirst("emphysema" A_EndChar),2)
    return
    :B0:Prf::
        sendByClipboard(StringUpperFirst("juxtapleural" A_EndChar),3)
    return
    :B0:Arsa::
        sendByClipboard(StringUpperFirst("aberrant right subclavian artery" A_EndChar),4)
    return
    :B0:Alsa::
        sendByClipboard(StringUpperFirst("aberrant left subclavian artery" A_EndChar),4)
    return
    :B0:Fs::
        sendByClipboard(StringUpperFirst("fissure" A_EndChar),2)
    return
    :*B0:Fs1::
        sendByClipboard(StringUpperFirst("fissures"),2)
    return
    :*B0:Fs2::
        sendByClipboard(StringUpperFirst("fissural"),2)
    return
    :B0:Mjf::
        sendByClipboard(StringUpperFirst("major fissure" A_EndChar),3)
    return
    :B0:Mif::
        sendByClipboard(StringUpperFirst("minor fissure" A_EndChar),3)
    return
    :B0:Axi::
        sendByClipboard(StringUpperFirst("axillary" A_EndChar),3)
    return
    :B0:Pco::
        sendByClipboard(StringUpperFirst("patchy consolidation" A_EndChar),3)
    return
    :*B0:Pco1::
        sendByClipboard(StringUpperFirst("patchy consolidations"),3)
    return
    :B0:Aoa::
        sendByClipboard(StringUpperFirst("aortic arch" A_EndChar),3)
    return
    :B0:Ata::
        sendByClipboard(StringUpperFirst("ascending aorta" A_EndChar),3)
    return
    :B0:Dta::
        sendByClipboard(StringUpperFirst("descending thoracic aorta" A_EndChar),3)
    return
    :B0:Tbc::
        sendByClipboard(StringUpperFirst("tracheobronchial calcifications" A_EndChar),3)
    return
    :B0:Pna::
        sendByClipboard(StringUpperFirst("pneumonia" A_EndChar),3)
    return
    :B0:Ppq::
        sendByClipboard(StringUpperFirst("pleural plaque" A_EndChar),3)
    return
    :*B0:Ppq1::
        sendByClipboard(StringUpperFirst("pleural plaques"),3)
    return
    :*B0:Mmph::
        sendByClipboard(StringUpperFirst("multifocal micronodular pneumocyte hyperplasia (MMPH)"),3)
    return
    :B0:Lmcr::
        sendByClipboard(StringUpperFirst("lymphangitic carcinomatosis" A_EndChar),4)
    return
    :B0:Cfa::
        sendByClipboard(StringUpperFirst("costophrenic angle" A_EndChar),3)
    return
    :*B0:Cfa1::
        sendByClipboard(StringUpperFirst("costophrenic angles"),3)
    return
    :*B0:Cfa2::
        sendByClipboard(StringUpperFirst("cardiophrenic angle"),3)
    return
    :B0:Bcv::
        sendByClipboard(StringUpperFirst("brachiocephalic vein" A_EndChar),3)
    return
    :B0:Bca::
        sendByClipboard(StringUpperFirst("brachiocephalic artery" A_EndChar),3)
    return
    :*B0:Ad0::
        sendByClipboard(StringUpperFirst("no definite abnormality of both adrenals."),2)
    return
    :B0:Bdl::
        sendByClipboard(StringUpperFirst("bilateral dependent lungs" A_EndChar),3)
    return
    :B0:Sbp::
        sendByClipboard(StringUpperFirst("subpleural" A_EndChar),3)
    return
    :B0:Fss::
        sendByClipboard(StringUpperFirst("fissural" A_EndChar),3)
    return
    :*B0:Plfs::
        sendByClipboard(StringUpperFirst("pleural/fissural"),3)
    return
    :B0:Pth::
        sendByClipboard(StringUpperFirst("pleural thickening" A_EndChar),3)
    return
    :B0:Tho::
        sendByClipboard(StringUpperFirst("thoracic" A_EndChar),3)
    return
    :B0:Pul::
        sendByClipboard(StringUpperFirst("pulmonary" A_EndChar),3)
    return
    :B0:Lu::
        sendByClipboard(StringUpperFirst("lung" A_EndChar),2)
    return
    :*B0:Lu1::
        sendByClipboard(StringUpperFirst("lungs"),2)
    return
    :B0:Eso::
        sendByClipboard(StringUpperFirst("esophagus" A_EndChar),3)
    return
    :*B0:Eso1::
        sendByClipboard(StringUpperFirst("esophageal"),3)
    return
    :*B0:Nl0::
        sendByClipboard(StringUpperFirst("no obvious worrisome lung nodule."),2)
    return
    :*B0:Nl1::
        sendByClipboard(StringUpperFirst("minor or non-specific lung parenchymal change."),2)
    return
    :*B0:Nl2::
        sendByClipboard(StringUpperFirst("tiny or probably non-specific nodules and minor or non-specific lung parenchymal change."),2)
    return
    :*B0:Nl3::
        sendByClipboard(StringUpperFirst("minor or non-specific lung findings."),2)
    return
    :*B0:Onl1::
        sendByClipboard(StringUpperFirst("other minor or non-specific lung parenchymal change."),3)
    return
    :*B0:Onl2::
        sendByClipboard(StringUpperFirst("other tiny or probably non-specific nodules and minor or non-specific lung parenchymal change."),3)
    return
    :*B0:Onl3::
        sendByClipboard(StringUpperFirst("other minor or non-specific lung findings."),3)
    return
    :*B0:L0/::
        sendByClipboard(StringUpperFirst("no definite detectable lung abnormality."),2)
    return
    :B0:Nh::
        sendByClipboard(StringUpperFirst("normal heart size" A_EndChar),2)
    return
    :B0:Cmg::
        sendByClipboard(StringUpperFirst("cardiomegaly" A_EndChar),3)
    return
    :B0:Pec::
        sendByClipboard(StringUpperFirst("pericardial" A_EndChar),3)
    return
    :B0:Pef::
        sendByClipboard(StringUpperFirst("pericardial effusion" A_EndChar),3)
    return
    :*B0:Peft::
        sendByClipboard(StringUpperFirst("pericardial effusion with pericardial thickening"),3)
    return
    :*B0:Peth::
        sendByClipboard(StringUpperFirst("pericardial thickening"),3)
    return
    :*B0:Ggoo::
        sendByClipboard(StringUpperFirst("ground glass opacity"),3)
    return
    :*B0:Ggo1::
        sendByClipboard(StringUpperFirst("ground glass opacities"),3)
    return
    :*B0:Ggnn::
        sendByClipboard(StringUpperFirst("ground glass nodule"),3)
    return
    :*B0:Ggn1::
        sendByClipboard(StringUpperFirst("ground glass nodules"),3)
    return
    :B0:Ggl::
        sendByClipboard(StringUpperFirst("ground glass lesion" A_EndChar),3)
    return
    :*B0:Ggl1::
        sendByClipboard(StringUpperFirst("ground glass lesions"),3)
    return
    :B0:Pso::
        sendByClipboard(StringUpperFirst("part-solid" A_EndChar),3)
    return
    :B0:Sso::
        sendByClipboard(StringUpperFirst("sub-solid" A_EndChar),3)
    return
    :B0:Opa::
        sendByClipboard(StringUpperFirst("opacity" A_EndChar),3)
    return
    :*B0:Opa1::
        sendByClipboard(StringUpperFirst("opacities"),3)
    return
    :B0:Corl::
        sendByClipboard(StringUpperFirst("Please correlate with the imaging findings and report of the abdominal/pelvic CT study." A_EndChar),4)
    return
    :*B0:Comc2::
        sendByClipboard(StringUpperFirst("CT of the chest without and with contrast enhancement is read without prior CT for comparison. This CT study shows:"),4)
    return
    :B0:Wdgr::
        sendByClipboard(StringUpperFirst("wedge resection" A_EndChar),4)
    return
    :B0:Ssa::
        sendByClipboard(StringUpperFirst("subsegmental atelectasis" A_EndChar),3)
    return
    :*B0:Ssab::
        sendByClipboard(StringUpperFirst("subsegmental atelectasis in bilateral lungs."),3)
    return
    :*B0:Sa0::
        sendByClipboard(StringUpperFirst("subsegmental atelectasis at bilateral basal lungs."),2)
    return
    :B0:Ate::
        sendByClipboard(StringUpperFirst("atelectasis" A_EndChar),3)
    return
    :*B0:Atco::
        sendByClipboard(StringUpperFirst("atelectasis/consolidation"),3)
    return
    :B0:Lte::
        sendByClipboard(StringUpperFirst("linear atelectasis" A_EndChar),3)
    return
    :B0:Brs::
        sendByClipboard(StringUpperFirst("bronchiectasis" A_EndChar),3)
    return
    :B0:Tbr::
        sendByClipboard(StringUpperFirst("tractional bronchiectasis" A_EndChar),3)
    return
    :B0:Pe::
        sendByClipboard(StringUpperFirst("pleural effusion" A_EndChar),2)
    return
    :B0:Mdi::
        sendByClipboard(StringUpperFirst("mediastinum" A_EndChar),3)
    return
    :B0:Md::
        sendByClipboard(StringUpperFirst("mediastinal" A_EndChar),2)
    return
    :B0:Ptx::
        sendByClipboard(StringUpperFirst("pneumothorax" A_EndChar),3)
    return
    :B0:Pmd::
        sendByClipboard(StringUpperFirst("pneumomediastinum" A_EndChar),3)
    return
    :B0:Con::
        sendByClipboard(StringUpperFirst("consolidation" A_EndChar),3)
    return
    :*B0:Con1::
        sendByClipboard(StringUpperFirst("consolidations"),3)
    return
    :*B0:Con2::
        sendByClipboard(StringUpperFirst("consolidative"),3)
    return
    :B0:Emc::
        sendByClipboard(StringUpperFirst("emphysematous change" A_EndChar),3)
    return
    :*B0:Emc0::
        sendByClipboard(StringUpperFirst("emphysematous change in bilateral lungs."),3)
    return
    :*B0:Emc1::
        sendByClipboard(StringUpperFirst("emphysematous change in bilateral upper lungs."),3)
    return
    :B0:Efc::
        sendByClipboard(StringUpperFirst("emphysematous and fibrotic change" A_EndChar),3)
    return
    :B0:Bbl::
        sendByClipboard(StringUpperFirst("bilateral basal lungs" A_EndChar),3)
    return
    :B0:Rull::
        sendByClipboard(StringUpperFirst("right upper lobe" A_EndChar),4)
    return
    :B0:Rlll::
        sendByClipboard(StringUpperFirst("right lower lobe" A_EndChar),4)
    return
    :B0:Rmll::
        sendByClipboard(StringUpperFirst("right middle lobe" A_EndChar),4)
    return
    :B0:Lull::
        sendByClipboard(StringUpperFirst("left upper lobe" A_EndChar),4)
    return
    :B0:Llll::
        sendByClipboard(StringUpperFirst("left lower lobe" A_EndChar),4)
    return
    :B0:Djdt::
        sendByClipboard(StringUpperFirst("degenerative change of the thoracic spine" A_EndChar),4)
    return
    :B0:Djdtl::
        sendByClipboard(StringUpperFirst("degenerative change of the thoracolumbar spine" A_EndChar),5)
    return
    :B0:Bpk::
        sendByClipboard(StringUpperFirst("bilateral apical pleural thickening" A_EndChar),3)
    return
    :B0:Cora::
        sendByClipboard(StringUpperFirst("coronary artery" A_EndChar),4)
    return
    :*B0:Cora1::
        sendByClipboard(StringUpperFirst("coronary arteries"),4)
    return
    :*B0:Cln0::
        sendByClipboard(StringUpperFirst("no definite mediastinal or hilar lymphadenopathy."),3)
    return
    :*B0:Ml0::
        sendByClipboard(StringUpperFirst("non-specific small mediastinal lymph nodes."),2)
    return
    :B0:Tlap::
        sendByClipboard(StringUpperFirst("thoracic lymphadenopathy." A_EndChar),4)
    return
    :B0:Ntl::
        sendByClipboard(StringUpperFirst("no definite thoracic lymphadenopathy." A_EndChar),3)
    return
    :*B0:Esre::
        sendByClipboard(StringUpperFirst("status post esophagectomy and reconstruction."),3)
    return
    :B0:Lbt::
        sendByClipboard(StringUpperFirst("lobectomy" A_EndChar),3)
    return
    :B0:Smt::
        sendByClipboard(StringUpperFirst("segmentectomy" A_EndChar),3)
    return
    :B0:Mst::
        sendByClipboard(StringUpperFirst("mastectomy" A_EndChar),3)
    return
    :B0:Ap/::
        sendByClipboard(StringUpperFirst("the appendix is not clearly demonstrated." A_EndChar),3)
    return
    :B0:Ist::
        sendByClipboard(StringUpperFirst("interlobular septal thickening" A_EndChar),3)
    return
    :B0:Pbv::
        sendByClipboard(StringUpperFirst("peribronchovascular" A_EndChar),3)
    return
    :B0:Cln::
        sendByClipboard(StringUpperFirst("centrilobular nodules" A_EndChar),3)
    return
    :B0:Msw::
        sendByClipboard(StringUpperFirst("metallic sternal wires" A_EndChar),3)
    return
    :B0:Ao::
        sendByClipboard(StringUpperFirst("aorta" A_EndChar),2)
    return
    :*B0:Ao1::
        sendByClipboard(StringUpperFirst("aortic"),2)
    return
    :B0:Dph::
        sendByClipboard(StringUpperFirst("diaphragm" A_EndChar),3)
    return
    :B0:Hdp::
        sendByClipboard(StringUpperFirst("hemidiaphragm" A_EndChar),3)
    return
    :B0:Tra::
        sendByClipboard(StringUpperFirst("a tracheostomy tube" A_EndChar),3)
    return
    :B0:Trm::
        sendByClipboard(StringUpperFirst("tracheostomy" A_EndChar),3)
    return
    :*B0:Mi/::
        sendByClipboard(StringUpperFirst("subendocardial hypoenhancement of LV, suspicious of ischemic change."),2)
    return
    :B0:Fld::
        sendByClipboard(StringUpperFirst("flow diverter" A_EndChar),3)
    return
    :B0:Gel::
        sendByClipboard(StringUpperFirst("Gelfoam particles" A_EndChar),3)
    return
    :*B0:Gel1::
        sendByClipboard(StringUpperFirst("Gelfoam fine particles"),3)
    return
    :*B0:Gel2::
        sendByClipboard(StringUpperFirst("Gelfoam coarse particles"),3)
    return
    :B0:Prer::
        sendByClipboard(StringUpperFirst("pre-RFA TAE" A_EndChar),4)
    return
    :B0:Sl10::
        sendByClipboard(StringUpperFirst("1.7Fr microcatheter (SL-10; Boston Scientific)" A_EndChar),4)
    return
    :B0:Prgr::
        sendByClipboard(StringUpperFirst("a 2.7Fr microcatheter (Progreat; Terumo)" A_EndChar),4)
    return
    :B0:Rene::
        sendByClipboard(StringUpperFirst("a 2.5Fr microcatheter (Renegade; Boston Scientific)" A_EndChar),4)
    return
    :B0:Rpy::
        sendByClipboard(StringUpperFirst("retrograde pyelography" A_EndChar),3)
    return
    :B0:Pegj::
        sendByClipboard(StringUpperFirst("Decreased peristalsis of the stomach is noted; prominent colon gas, indicating ileus. A 5Fr H1 insertion into the stomach first; then 150 cm guidewire was delivered and this 5Fr H1 was adjusted into the duodenum. Therefore, the gastrojejunal tube (12Fr in 24Fr) was delivered smoothly with tip in the proximal jejunum. Prevention from tube occlusion was educated. Please give peristalsis-stimulating drugs (such as Motilin or Mopride; 1# tid); local wound care ointment (such as Bacitracin Neomycin Ointment; Zinc oxide ointment)." A_EndChar),4)
    return
    :B0:Jtub::
        sendByClipboard(StringUpperFirst("The yellow port is for feeding; the red port is for decompression. Please give the ointments for wound care and peristalsis stimulating drug." A_EndChar),4)
    return
    :B0:Embz::
        sendByClipboard(StringUpperFirst("Embozene particles (400 micrometer, CeloNova Bioscience)" A_EndChar),4)
    return
    :B0:Dtvn::
        sendByClipboard(StringUpperFirst("a 5Fr, 15cm DTVN drainage tube (Cook)" A_EndChar),4)
    return
    :B0:Apy::
        sendByClipboard(StringUpperFirst("antegrade pyelography" A_EndChar),3)
    return
    :B0:Emz::
        sendByClipboard(StringUpperFirst("embolization" A_EndChar),3)
    return
    :B0:Lpo::
        sendByClipboard(StringUpperFirst("lipiodol" A_EndChar),3)
    return
    :B0:Lpr::
        sendByClipboard(StringUpperFirst("lipiodol retention" A_EndChar),3)
    return
    :*B0:Lhaa::
        sendByClipboard(StringUpperFirst("left hepatic artery"),3)
    return
    :*B0:Lhvv::
        sendByClipboard(StringUpperFirst("left hepatic vein"),3)
    return
    :*B0:Mhaa::
        sendByClipboard(StringUpperFirst("middle hepatic artery"),3)
    return
    :*B0:Mhvv::
        sendByClipboard(StringUpperFirst("middle hepatic vein"),3)
    return
    :*B0:Rhaa::
        sendByClipboard(StringUpperFirst("right hepatic artery"),3)
    return
    :*B0:Rhvv::
        sendByClipboard(StringUpperFirst("right hepatic vein"),3)
    return
    :*B0:Phaa::
        sendByClipboard(StringUpperFirst("proper hepatic artery"),3)
    return
    :*B0:Chaa::
        sendByClipboard(StringUpperFirst("common hepatic artery"),3)
    return
    :*B0:Smaa::
        sendByClipboard(StringUpperFirst("superior mesenteric artery"),3)
    return
    :*B0:Ipaa::
        sendByClipboard(StringUpperFirst("inferior phrenic artery"),3)
    return
    :*B0:Spda::
        sendByClipboard(StringUpperFirst("superior pancreaticoduodenal artery"),3)
    return
    :*B0:Rgea::
        sendByClipboard(StringUpperFirst("right gastroepiploic artery"),3)
    return
    :*B0:Lgea::
        sendByClipboard(StringUpperFirst("left gastroepiploic artery"),3)
    return
    :*B0:Lgaa::
        sendByClipboard(StringUpperFirst("left gastric artery"),3)
    return
    :B0:Rep::
        sendByClipboard(StringUpperFirst("replaced" A_EndChar),3)
    return
    :B0:Bch::
        sendByClipboard(StringUpperFirst("branch" A_EndChar),3)
    return
    :*B0:Bch1::
        sendByClipboard(StringUpperFirst("branches"),3)
    return
    :B0:Rev::
        sendByClipboard(StringUpperFirst("revision" A_EndChar),3)
    return
    :*B0:Rev1::
        sendByClipboard(StringUpperFirst("revised"),3)
    return
    :B0:Rem::
        sendByClipboard(StringUpperFirst("remove" A_EndChar),3)
    return
    :B0:Badi::
        sendByClipboard(StringUpperFirst("balloon dilatation" A_EndChar),4)
    return
    :B0:Seh::
        sendByClipboard(StringUpperFirst("sheath" A_EndChar),3)
    return
    :B0:Sty::
        sendByClipboard(StringUpperFirst("stylet" A_EndChar),3)
    return
    :B0:Ish::
        sendByClipboard(StringUpperFirst("introducer sheath" A_EndChar),3)
    return
    :B0:Exc::
        sendByClipboard(StringUpperFirst("exchange" A_EndChar),3)
    return
    :B0:Adv::
        sendByClipboard(StringUpperFirst("advance" A_EndChar),3)
    return
    :B0:Gw::
        sendByClipboard(StringUpperFirst("guidewire" A_EndChar),2)
    return
    :B0:Mgw::
        sendByClipboard(StringUpperFirst("microguidewire" A_EndChar),3)
    return
    :B0:Mcth::
        sendByClipboard(StringUpperFirst("microcatheter" A_EndChar),4)
    return
    :B0:Nav::
        sendByClipboard(StringUpperFirst("navigate" A_EndChar),3)
    return
    :B0:Ins::
        sendByClipboard(StringUpperFirst("insert" A_EndChar),3)
    return
    :*B0:Ins1::
        sendByClipboard(StringUpperFirst("insertion"),3)
    return
    :B0:Vi::
        sendByClipboard(StringUpperFirst("via" A_EndChar),2)
    return
    :B0:F::
        sendByClipboard(StringUpperFirst("from" A_EndChar),1)
    return
    :B0:Proc::
        sendByClipboard(StringUpperFirst("procedure" A_EndChar),4)
    return
    :B0:Gdaa::
        sendByClipboard(StringUpperFirst("gastroduodenal artery" A_EndChar),4)
    return
    :B0:Wbao::
        sendByClipboard(StringUpperFirst("will be arranged on" A_EndChar),4)
    return
    :B0:Wwcf::
        sendByClipboard(StringUpperFirst("We were consulted for" A_EndChar),4)
    return
    :B0:Rfa::
        sendByClipboard(StringUpperFirst("RFA" A_EndChar),3)
    return
    :B0:Tae::
        sendByClipboard(StringUpperFirst("TAE" A_EndChar),3)
    return
    :B0:Aspi::
        sendByClipboard(StringUpperFirst("aspiration" A_EndChar),4)
    return
    :B0:Drn::
        sendByClipboard(StringUpperFirst("drainage" A_EndChar),3)
    return
    :B0:Bx::
        sendByClipboard(StringUpperFirst("biopsy" A_EndChar),2)
    return
    :B0:Ctg::
        sendByClipboard(StringUpperFirst("CT-guided" A_EndChar),3)
    return
    :B0:Abl::
        sendByClipboard(StringUpperFirst("ablation" A_EndChar),3)
    return
    :B0:Mcw::
        sendByClipboard(StringUpperFirst("microwave" A_EndChar),3)
    return
    :B0:Cox::
        sendByClipboard(StringUpperFirst("contrast extravasation" A_EndChar),3)
    return
    :*B0:Cox0::
        sendByClipboard(StringUpperFirst("no definite active contrast extravasation"),3)
    return
    :B0:Ufg::
        sendByClipboard(StringUpperFirst("under fluoroscopic guidance" A_EndChar),3)
    return
    :B0:Uug::
        sendByClipboard(StringUpperFirst("under ultrasound guidance" A_EndChar),3)
    return
    :B0:Ucg::
        sendByClipboard(StringUpperFirst("under CT guidance" A_EndChar),3)
    return
    :B0:Obj::
        sendByClipboard(StringUpperFirst("obstructive jaundice" A_EndChar),3)
    return
    :B0:Ja::
        sendByClipboard(StringUpperFirst("jaundice" A_EndChar),2)
    return
    :B0:Obu::
        sendByClipboard(StringUpperFirst("obstructive uropathy" A_EndChar),3)
    return
    :B0:Apr::
        sendByClipboard(StringUpperFirst("approach" A_EndChar),3)
    return
    :B0:Chg::
        sendByClipboard(StringUpperFirst("cholangiogram" A_EndChar),3)
    return
    :B0:Lbx::
        sendByClipboard(StringUpperFirst("We will evaluate the feasibility of CT guided biopsy for this patient. Please discuss and inform this patient and the family for the possible complications, such as pneumothorax, hemoptysis, hemorrhage, air embolism, etc." A_EndChar),3)
    return
    :B0:Fesh::
        sendByClipboard(StringUpperFirst("The femoral artery sheath is not removed. Please remove it in 48 hours if no further indication of angiographic intervention." A_EndChar),4)
    return
    :*B0:Un0::
        sendByClipboard(StringUpperFirst("negative or unremarkable radiological findings of the unmentioned organs."),2)
    return
    :B0:Yy::
        sendByClipboard(StringUpperFirst("Reported by YCH (#00000)." A_EndChar),2)
    return
    :B0:Nonc::
        sendByClipboard(StringUpperFirst("(Low sensitivity and specificity of non-contrast CT.)" A_EndChar),4)
    return
    :*B0:Noncmet::
        sendByClipboard(StringUpperFirst("(Low sensitivity of non-contrast CT for metastatic lesions.)"),6)
    return
    :*B0:Ld=::
        sendByClipboard(StringUpperFirst("(Low dose CT is inferior for soft tissue lesion detection.)"),2)
    return
    :B0:Sc::
        sendByClipboard(StringUpperFirst("suggest clinical correlation." A_EndChar),2)
    return
    :B0:Scf::
        sendByClipboard(StringUpperFirst("suggest clinical correlation and follow up." A_EndChar),3)
    return
    :*B0:Sfu1::
        sendByClipboard(StringUpperFirst("suggest short term follow up."),3)
    return
    :B0:Fu::
        sendByClipboard(StringUpperFirst("follow up" A_EndChar),2)
    return
    :B0:Crr::
        sendByClipboard(StringUpperFirst("correlation" A_EndChar),3)
    return
    :B0:Mmc::
        sendByClipboard(StringUpperFirst("suggest mammography correlation." A_EndChar),3)
    return
    :B0:Mrc::
        sendByClipboard(StringUpperFirst("suggest MRI correlation." A_EndChar),3)
    return
    :B0:Ctc::
        sendByClipboard(StringUpperFirst("suggest CT correlation." A_EndChar),3)
    return
    :B0:Enc::
        sendByClipboard(StringUpperFirst("suggest endoscope correlation." A_EndChar),3)
    return
    :B0:Cec::
        sendByClipboard(StringUpperFirst("suggest contrast enhanced study if indicated." A_EndChar),3)
    return
    :B0:Lfc::
        sendByClipboard(StringUpperFirst("suggest correlation with local findings." A_EndChar),3)
    return
    :*B0:Enc2::
        sendByClipboard(StringUpperFirst("suggest coloscope correlation."),3)
    return
    :*B0:Enc1::
        sendByClipboard(StringUpperFirst("suggest bronchoscope correlation."),3)
    return
    :B0:Guc::
        sendByClipboard(StringUpperFirst("suggest gynecologic ultrasound correlation." A_EndChar),3)
    return
    :B0:Sci::
        sendByClipboard(StringUpperFirst("suggest clinical correlation for possible infectious process." A_EndChar),3)
    return
    :B0:Zlf::
        sendByClipboard(StringUpperFirst("suggest correlation with local finding." A_EndChar),3)
    return
    :B0:Stp::
        sendByClipboard(StringUpperFirst("suggest tissue proof." A_EndChar),3)
    return
    :B0:Reas::
        sendByClipboard(StringUpperFirst("(This study is reassigned to current radiologist on " A_YYYY "/" a_mm "/" a_dd ".)"),4)
    return
    :B0:Othp::
        sendByClipboard(StringUpperFirst("(Please correlate with the report of other body parts.)"),4)
    return
    :*B0:Taee::
        sendByClipboard(StringUpperFirst("transarterial embolization"),3)
    return
    :*B0:Avmm::
        sendByClipboard(StringUpperFirst("arteriovenous malformation"),3)
    return
    :*B0:Avff::
        sendByClipboard(StringUpperFirst("arteriovenous fistula"),3)
    return
    :B0:Vam::
        sendByClipboard(StringUpperFirst("vascular malformation" A_EndChar),3)
    return
    :*B0:Tbil::
        sendByClipboard(StringUpperFirst("T-bil"),3)
    return
    :B0:Htn::
        sendByClipboard(StringUpperFirst("hypertension" A_EndChar),3)
    return
    :*B0:Ca/::
        sendByClipboard(StringUpperFirst("ca"),2)
    return
    :B0:Cn::
        sendByClipboard(StringUpperFirst("cancer" A_EndChar),2)
    return
    :B0:Adc::
        sendByClipboard(StringUpperFirst("adenocarcinoma" A_EndChar),3)
    return
    :B0:Car::
        sendByClipboard(StringUpperFirst("carcinoma" A_EndChar),3)
    return
    :cB0:Ica::
        sendByClipboard(StringUpperFirst("ICA" A_EndChar),3)
    return
    :cB0:Aca::
        sendByClipboard(StringUpperFirst("ACA" A_EndChar),3)
    return
    :cB0:Mca::
        sendByClipboard(StringUpperFirst("MCA" A_EndChar),3)
    return
    :cB0:Icas::
        sendByClipboard(StringUpperFirst("ICAs" A_EndChar),4)
    return
    :cB0:Acas::
        sendByClipboard(StringUpperFirst("ACAs" A_EndChar),4)
    return
    :cB0:Mcas::
        sendByClipboard(StringUpperFirst("MCAs" A_EndChar),4)
    return
    :cB0:M2::
        sendByClipboard(StringUpperFirst("M2" A_EndChar),2)
    return
    :cB0:A1::
        sendByClipboard(StringUpperFirst("A1" A_EndChar),2)
    return
    :cB0:A2::
        sendByClipboard(StringUpperFirst("A2" A_EndChar),2)
    return
    :cB0:P1::
        sendByClipboard(StringUpperFirst("P1" A_EndChar),2)
    return
    :cB0:P2::
        sendByClipboard(StringUpperFirst("P2" A_EndChar),2)
    return
    :cB0:Pca::
        sendByClipboard(StringUpperFirst("PCA" A_EndChar),3)
    return
    :cB0:Pcas::
        sendByClipboard(StringUpperFirst("PCAs" A_EndChar),4)
    return
    :cB0:Ecas::
        sendByClipboard(StringUpperFirst("ECAs" A_EndChar),4)
    return
    :cB0:Mma::
        sendByClipboard(StringUpperFirst("MMA" A_EndChar),3)
    return
    :cB0:Mmas::
        sendByClipboard(StringUpperFirst("MMAs" A_EndChar),4)
    return
    :cB0:Cca::
        sendByClipboard(StringUpperFirst("CCA" A_EndChar),3)
    return
    :cB0:Ccas::
        sendByClipboard(StringUpperFirst("CCAs" A_EndChar),4)
    return
    :cB0:Pica::
        sendByClipboard(StringUpperFirst("PICA" A_EndChar),4)
    return
    :cB0:Aica::
        sendByClipboard(StringUpperFirst("AICA" A_EndChar),4)
    return
    :cB0:Va::
        sendByClipboard(StringUpperFirst("VA" A_EndChar),2)
    return
    :cB0:Picas::
        sendByClipboard(StringUpperFirst("PICAs" A_EndChar),5)
    return
    :cB0:Aicas::
        sendByClipboard(StringUpperFirst("AICAs" A_EndChar),5)
    return
    :cB0:Vsa::
        sendByClipboard(StringUpperFirst("VAs" A_EndChar),3)
    return
    :cB0:Ba::
        sendByClipboard(StringUpperFirst("BA" A_EndChar),2)
    return
    :cB0:Sov::
        sendByClipboard(StringUpperFirst("SOV" A_EndChar),3)
    return
    :cB0:Ccf::
        sendByClipboard(StringUpperFirst("CCF" A_EndChar),3)
    return
    :cB0:Avf::
        sendByClipboard(StringUpperFirst("AVF" A_EndChar),3)
    return
    :cB0:Avm::
        sendByClipboard(StringUpperFirst("AVM" A_EndChar),3)
    return
    :cB0:Tof::
        sendByClipboard(StringUpperFirst("TOF" A_EndChar),3)
    return
    :cB0:Flair::
        sendByClipboard(StringUpperFirst("FLAIR" A_EndChar),5)
    return
    :cB0:Mri::
        sendByClipboard(StringUpperFirst("MRI" A_EndChar),3)
    return
    :cB0:Ct::
        sendByClipboard(StringUpperFirst("CT" A_EndChar),2)
    return
    :cB0:Mtt::
        sendByClipboard(StringUpperFirst("MTT" A_EndChar),3)
    return
    :cB0:Cbf::
        sendByClipboard(StringUpperFirst("CBF" A_EndChar),3)
    return
    :cB0:Cbv::
        sendByClipboard(StringUpperFirst("CBV" A_EndChar),3)
    return
    :cB0:Ich::
        sendByClipboard(StringUpperFirst("ICH" A_EndChar),3)
    return
    :cB0:Ichs::
        sendByClipboard(StringUpperFirst("ICHs" A_EndChar),4)
    return
    :cB0:Sah::
        sendByClipboard(StringUpperFirst("SAH" A_EndChar),3)
    return
    :cB0:Sahs::
        sendByClipboard(StringUpperFirst("SAHs" A_EndChar),4)
    return
    :cB0:Sdh::
        sendByClipboard(StringUpperFirst("SDH" A_EndChar),3)
    return
    :cB0:Sdhs::
        sendByClipboard(StringUpperFirst("SDHs" A_EndChar),4)
    return
    :cB0:Edh::
        sendByClipboard(StringUpperFirst("EDH" A_EndChar),3)
    return
    :cB0:Edhs::
        sendByClipboard(StringUpperFirst("EDHs" A_EndChar),4)
    return
    :cB0:Ijv::
        sendByClipboard(StringUpperFirst("ijv" A_EndChar),3)
    return
    :cB0:Ihds::
        sendByClipboard(StringUpperFirst("IHDs" A_EndChar),4)
    return
    :cB0:Cbd::
        sendByClipboard(StringUpperFirst("CBD" A_EndChar),3)
    return
    :cB0:Rv::
        sendByClipboard(StringUpperFirst("RV" A_EndChar),2)
    return
    :cB0:La::
        sendByClipboard(StringUpperFirst("LA" A_EndChar),2)
    return
    :cB0:Ra::
        sendByClipboard(StringUpperFirst("RA" A_EndChar),2)
    return
    :B0:Cpq::
        sendByClipboard(StringUpperFirst("calcified plaque" A_EndChar),3)
    return
    :*B0:Cpq1::
        sendByClipboard(StringUpperFirst("calcified plaques"),3)
    return
    :B0:Npq::
        sendByClipboard(StringUpperFirst("noncalcified plaque" A_EndChar),3)
    return
    :*B0:Npq1::
        sendByClipboard(StringUpperFirst("noncalcified plaques"),3)
    return
    :B0:Mpq::
        sendByClipboard(StringUpperFirst("mixed plaque" A_EndChar),3)
    return
    :*B0:Mpq1::
        sendByClipboard(StringUpperFirst("mixed plaques"),3)
    return
    :*B0:Ds1::
        sendByClipboard(StringUpperFirst("minimal (<25%) stenosis"),2)
    return
    :*B0:Ds2::
        sendByClipboard(StringUpperFirst("mild (25%-49%) stenosis"),2)
    return
    :*B0:Ds3::
        sendByClipboard(StringUpperFirst("moderate (50%-69%) stenosis"),2)
    return
    :*B0:Ds4::
        sendByClipboard(StringUpperFirst("severe (70%-99%) stenosis"),2)
    return
    :*B0:Ds5::
        sendByClipboard(StringUpperFirst("total occlusion"),2)
    return
    :C*B0:Plad::
        sendByClipboard(StringUpperFirst("pLAD"),3)
    return
    :C*B0:Mlad::
        sendByClipboard(StringUpperFirst("mLAD"),3)
    return
    :C*B0:Dlad::
        sendByClipboard(StringUpperFirst("dLAD"),3)
    return
    :C*B0:Plcx::
        sendByClipboard(StringUpperFirst("pLCX"),3)
    return
    :C*B0:Mlcx::
        sendByClipboard(StringUpperFirst("mLCX"),3)
    return
    :C*B0:Dlcx::
        sendByClipboard(StringUpperFirst("dLCX"),3)
    return
    :C*B0:Prca::
        sendByClipboard(StringUpperFirst("pRCA"),3)
    return
    :C*B0:Mrca::
        sendByClipboard(StringUpperFirst("mRCA"),3)
    return
    :C*B0:Drca::
        sendByClipboard(StringUpperFirst("dRCA"),3)
    return
    :*B0:Ld0::
        sendByClipboard(StringUpperFirst("肺部：無異常。"),2)
    return
    :*B0:Ld1::
        sendByClipboard(StringUpperFirst("肺部：無異常。請詳閱影像報告。"),2)
    return
    :*B0:Ld2::
        sendByClipboard(StringUpperFirst("肺部：無顯著異常。請詳閱影像報告。"),2)
    return
    :*B0:Ld3::
        sendByClipboard(StringUpperFirst("肺部：有異常。請詳閱影像報告。"),2)
    return
    :*B0:Ld4::
        sendByClipboard(StringUpperFirst("肺部：明顯異常。請詳閱影像報告。"),2)
    return
    :*B0:Ld5::
        sendByClipboard(StringUpperFirst("肺部：疑似惡性腫瘤。請詳閱影像報告。"),2)
    return
    :*B0:Gtran::
        sendByClipboard(StringUpperFirst("（本翻譯結果由Google Translate提供，請務必與專業醫師討論本報告內容）"),4)
    return
    :B0:Pm0::
        sendByClipboard(StringUpperFirst("通報臨床醫師0" A_EndChar),3)
    return
    :B0:Pm1::
        sendByClipboard(StringUpperFirst("通報臨床醫師1" A_EndChar),3)
    return
    :B0:Pm2::
        sendByClipboard(StringUpperFirst("通報臨床醫師(急)" A_EndChar),3)
    return
    :B0:Pmtb::
        sendByClipboard(StringUpperFirst("疑似肺結核" A_EndChar),4)
    return
    :B0:Dbs::
        sendByClipboard(StringUpperFirst("placement of implantable electronic stimulation devices." A_EndChar),3)
    return
    :B0:Mnf::
        sendByClipboard(StringUpperFirst("minor or non-specific findings." A_EndChar),3)
    return
    :*B0:Mlss::
        sendByClipboard(StringUpperFirst("spinal stenosis at multiple levels"),3)
    return
    :*B0:Mlse::
        sendByClipboard(StringUpperFirst("spinal stenosis at multiple levels, most evident at"),3)
    return
    :B0:Vcu::
        sendByClipboard(StringUpperFirst("vacuum phenomenon" A_EndChar),3)
    return
    :B0:Outhos::
        sendByClipboard(StringUpperFirst("I concur with the report generated by the radiologist at the medical facility where the patient underwent this diagnostic imaging study. The initial report is presented below:`n" A_EndChar),6)
    return
    :B0:Othhos::
        sendByClipboard(StringUpperFirst("I concur with the report generated by the radiologist at the medical facility where the patient underwent this diagnostic imaging study. The initial report is presented below:`n" A_EndChar),6)
    return
