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
; Talk to the single CH_RIS owner (autorun) over IPC. As a "Hotstring Helper" script its
; CH_RIS_REPORT.__New early-returns (a non-functional stub), so its CH_RIS.* reads/writes
; were dead; client mode routes them to the real owner (an improvement). Set before any
; include whose auto-exec calls getPlace (portallib / risimpax). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <portallib>
#include <risimpax>
#include <.netgetcontrol>
#include <ImpaxContextServer>
#include <resetHotstringBuffer>
#include <RegExSplit>
resetHotstringBufferHook()

CloseOtherYCHAHK()
OnScreenDisplay("YCH MAMMO")

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

if __is_CH
    CH_RIS.AddAccNoChangedHookFn(Func("ShowLastBirads"))
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
sendByClipboard(brQ(SubStr($.value(0),1,-1)) SubStr($.value(0),0,1), StrLen($.value(0)))
return

opsite:
send % "{bs " StrLen($.value(0))  "}"
send % "Focal parenchymal loss, architectural distortion and skin retraction are noted at " brQ($.value(1)) " under the wire, compatible with post-operative change."
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


#IfWinActive,simple RIS ahk_class AutoHotkeyGUI
; magnified views
ctrlm:
^m::
editHwnds:=getSimpleRisEditHwnds()
Text:=Edit_GetText(editHwnds[2])
if (__is_N){

if (matched:=RegExMatch(Text, "i)(bilateral|left|right) (mlo|cc)", match)){
    PostMessage,0x2023,1000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
    Edit_GetSel(editHwnds[2],s,e)
    ,Edit_SetText(editHwnds[2],newText:=SubStr(Text,1,matched+StrLen(match1)) "magnified " SubStr(Text,matched+StrLen(match1)+1))
    ,Edit_SetText(editHwnds[1],newText)
    ,Edit_SetSel(editHwnds[2],s+10,e+10)
    ,Edit_SetSel(editHwnds[1],s+10,e+10)
}
}else if(__is_CH){
    if RegExMatch(Text, "is)^(INDICATION:)([^\r\n]+)(.+)$", match){
        ;~ Text:=match1 " " (InStr(structuredReport.views, "magnified")||InStr(examName, "diagnos")?"diagnostic":"screening") " mammography. " match3
        Text:=match1 " " (InStr(structuredReport.views, "magnified")?"diagnostic":"screening") " mammography. " match3
        Edit_SetText(editHwnds[2],Text)
        Edit_SetSel(editHwnds[2], -1, -1)
    }
}
return

^i::
editHwnds:=getSimpleRisEditHwnds()
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
editHwnds:=getSimpleRisEditHwnds()
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
    send {Numpad2}
}else{
    send {Numpad5}
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
settimer,setCtrlmHotkey,1000
return

setCtrlmHotkey:
Hotkey,IfWinActive,simple RIS ahk_class AutoHotkeyGUI
Hotkey,^m,CtrlM,on
Hotkey,IfWinActive
return


#ifwinactive,ahk_group PacsViewer

~2:
send % "{Numpad2}"
return
~3:
send % "{Numpad5}"
return

~s:
send {Left}
return
~d:
send {Right}
return 

~m:
~!m::
~^m::
send z
return

~g:
if !GetKeyState("Lbutton")
    send {LButton Down}
return 

~g_up:
send {lbutton up}
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
    send {%key%}
    mousemove,% Floor((mon1right-mon1left)/4*3),% Floor(mon1bottom/2),2
    send {%key%}
}else{
    mousemove,% ox:=Floor(mon1right+(mon2right-mon2left)/4*1),% oy:=Floor(mon2bottom/2),2
    send {%key%}
    mousemove,% Floor(mon1right+(mon2right-mon2left)/4*3),% Floor(mon2bottom/2),2
    send {%key%}
    
    if (monC=3){
        mousemove,% Floor(mon2right+(mon3right-mon3left)/4*1),% Floor(mon2bottom/2),2
        send {%key%}
        if !instr(a_thishotkey,"#") {
            mousemove,% Floor(mon2right+(mon3right-mon3left)/4*3),% Floor(mon2bottom/2),2
            send {%key%}
        }
    }
}
send {z}
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

#Hotstring, SI


::bc::breast cancer
::pm::partial mastectomy


:o:fm::family history of breast cancer ().{left 2}






::bctr::Breast cancer s/p right BCT
::bctl::Breast cancer s/p left BCT
::sbr::s/p right BCT with scar in
::sbrn::s/p right BCT with scar in No definite local recurrence.^{left}^{left}^{left}^{left}
::sbl::s/p left BCT with scar in
::sbln::s/p left BCT with scar in No definite local recurrence.^{left}^{left}^{left}^{left}
::mr::Breast cancer s/p right modified radical mastectomy
::ml::Breast cancer s/p left modified radical mastectomy
::smr::s/p right modified radical mastectomy
::smrn::s/p right modified radical mastectomy. No definite local recurrence
::sml::s/p left modified radical mastectomy
::smln::s/p left modified radical mastectomy. No definite local recurrence

::r::right
::l::left
::bi::bilateral

::red::are read and compared with prior mammograms dated
::redn::are read without prior mammograms available for comparison.{enter}- 


:o*:hsm1::
:o*:hsm2::
:o*:hsm3::
:o*:hsm4::
num:=substr(a_thishotkey,0,1)
:o:hsm::
resetReports()
Sleep 300
send History: screening mammogram.{enter}{enter}
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
send History: breast cancer s/p right BCT.{enter}{enter}
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
send History: breast cancer s/p left BCT.{enter}{enter}
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
send History: breast cancer s/p bilateral BCT.{enter}{enter}
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
send History: breast cancer s/p right mastectomy.{enter}{enter}
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
send History: breast cancer s/p left mastectomy.{enter}{enter}
gosub dt_
return

:o*:hfh::History: family history of breast cancer (){left}
:o*:hrl::History: right breast lump.{enter}{enter}
:o*:hll::History: left breast lump.{enter}{enter}
:o*:hbl::History: bilateral breast lumps.{enter}{enter}
:o*:hfu::History: follow up.{enter}{enter}
:o*:hrb::History: right breast benign lesion status post operation/biopsy.{enter}{enter}
:o*:hlb::History: left breast benign lesion status post operation/biopsy.{enter}{enter}
:o*:hbb::History: bilateral breast benign lesion status post operation/biopsy.{enter}{enter}

::bmc::Bilateral MLO/CC digital mammograms are read and compared with prior mammograms dated
::bmmc::Bilateral magnified MLO/CC digital mammograms are read and compared with prior mammograms dated
::bmcn::Bilateral MLO/CC digital mammograms are read without prior mammograms available for comparison. This study shows:`r`n- 
::bmci::Bilateral MLO and CC II/ID views are read and compared with prior mammograms dated
::bmcin::Bilateral MLO and CC II/ID views are read without prior mammograms available for comparison. This study shows:`r`n- 

::rmc::Right MLO/CC digital mammograms are read and compared with prior mammograms dated
::rmcn::Right MLO/CC digital mammograms are read without prior mammograms available for comparison. This study shows:`r`n- 
::rmci::Right MLO and CC II/ID views are read and compared with prior mammograms dated
::rmcin::Right MLO and CC II/ID views are read without prior mammograms available for comparison. This study shows:`r`n- 

::lmc::Left MLO/CC digital mammograms are read and compared with prior mammograms dated
::lmcn::Left MLO/CC digital mammograms are read without prior mammograms available for comparison. This study shows:`r`n- 
::lmci::Left MLO and CC II/ID views are read and compared with prior mammograms dated
::lmcin::Left MLO and CC II/ID views are read without prior mammograms available for comparison. This study shows:`r`n- 


:O*:op=::Focal parenchymal loss, architectural distortion and skin retraction are noted at breast under the wire, compatible with post-operative change.^{left 12}


:*:cal0::There are benign scattered calcifications present.
:o:bcal::There are benign scattered calcifications present bilaterally.{Enter}-{space}
:o:bcalv::There are benign appearing vascular wall calcifications in bilateral breasts.{Enter}-{space}
:o:lcal::There are benign scattered calcifications present in left breast.{Enter}-{space}
:o:lcalv::There are benign appearing vascular wall calcifications in left breast.{Enter}-{space}
:o:rcal::There are benign scattered calcifications present in right breast.{Enter}-{space}
:o:rcalv::There are benign appearing vascular wall calcifications in right breast.{Enter}-{space}

::neg::There are no definite mass, no suspicious microcalcifications, and no architectural distortion in this study.`r`n- No definite axillary lymphadenopathy.
::negc::There are no definite mass and no architectural distortion in this study.`r`n- No definite axillary lymphadenopathy.
::negm::There are no definite mass in this study.`r`n- No definite axillary lymphadenopathy.

:oc1:B0u::
:oc1:B0m::
:oc1:B0t::
:oc1:B1::
:oc1:B2::
:oc1:B3::
:oc1:B4::
:oc1:B4a::
:oc1:B4b::
:oc1:B4c::
:oc1:B5::
:oc1:B6::
:oc1:B0uk::
:oc1:B0mk::
:oc1:B0tk::
:oc1:B1k::
:oc1:B2k::
:oc1:B3k::
:oc1:B4k::
:oc1:B4ak::
:oc1:B4bk::
:oc1:B4ck::
:oc1:B5k::
:oc1:B6k::

:oc1:uB0u::
:oc1:uB0m::
:oc1:uB0t::
:oc1:uB1::
:oc1:uB2::
:oc1:uB3::
:oc1:uB4::
:oc1:uB4a::
:oc1:uB4b::
:oc1:uB4c::
:oc1:uB5::
:oc1:uB6::
:oc1:uB0uk::
:oc1:uB0mk::
:oc1:uB0tk::
:oc1:uB1k::
:oc1:uB2k::
:oc1:uB3k::
:oc1:uB4k::
:oc1:uB4ak::
:oc1:uB4bk::
:oc1:uB4ck::
:oc1:uB5k::
:oc1:uB6k::

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
Sleep 500
gosub F3
if(simpleRis:=WinExist("simple RIS ahk_class AutoHotkeyGUI")){
    
    PostMessage,0x2023,1000,1,,simpleRIS_main ahk_class AutoHotkeyGUI
    ;~ Edit_SetText(EditHwnd, "")
    ;~ resetSimpleRis()
    setTimerF("resetSimpleRis", -1000)
}
return

:o:b0u::BI-RADS category 0, indeterminate mammographic finding (need additional imaging evaluation), suggest breast ultrasound correlation.
:o:b0m::BI-RADS category 0, indeterminate mammographic finding (need additional imaging evaluation), suggest spot magnified view correlation.
:o:b1::BI-RADS category 1, negative finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)
:o:b2::BI-RADS category 2, benign finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)
:o:b3::BI-RADS category 3, probably benign finding, suggest 6-month mammogram follow up. (If there is clinical relevant finding, ultrasound is suggested.)
:o:b4::BI-RADS category 4, suspicious malignant lesion. Suggest tissue proof.
:o:b4a::BI-RADS category 4A, low suspicion for malignancy. Suggest tissue proof.
:o:b4b::BI-RADS category 4B, moderate suspicion for malignancy. Suggest tissue proof.
:o:b4c::BI-RADS category 4C, high suspicion for malignancy. Suggest tissue proof.
:o:b5::BI-RADS category 5, highly suggestive of malignancy. Suggest tissue proof.
:o:b6::BI-RADS category 6, known biopsy-proven malignancy.

::m6::suggest 6-month follow up.
::mvc::suggest magnified view correlation. 
::svc::suggest spot view correlation.

:b0:md1::
:b0:md2::
:b0:md3::
:b0:md4::
sendByClipboard(brDen[den:=substr(a_thishotkey,0,1)], 3)
den:=""
return


::iml::There are left retro-pectoral saline implants, with smooth surface without evidence of rupture.
::imr::There are right retro-pectoral saline implants, with smooth surface without evidence of rupture.
::imb::There are bilateral retro-pectoral saline implants, with smooth surface without evidence of rupture.

::ibb::in bilateral breasts
::irb::in right breast
::ilb::in left breast
::bb::bilateral breasts
::rb::right breast
::lb::left breast

::lj::(YCH/Dr.B)
::clin::( if there is clinical relevant finding, ultrasound is suggested. )

::FA::fibroadenoma
:*:FA1::fibroadenomas
::FCC::fibrocystic change
::FHX::family history of breast cancer (sister/mother/grandmother),


::LNR::benign appearing node at right axilla, size , having fat hilum.
::LNL::benign appearing node at left axilla, size , having fat hilum.
::MAGS::spot magnification views
::MAG::magnified
::MASY::Focal asymmetry is noted at right anterior UOQ near central, suggest ultrasound or mag. views.


::MMIC::There are two clusters of pleomorphic to amorphous microcalcifications at right UOQ, suggest biopsy.
::MMIC2::There are segmentally to regionally distributed microcalcifications at the UOQ left breast with probably benign appearance.

::MOP2::Focal architectural distortion, parenchymal retraction is noted at right UOQ under the wire and focal asymmetry near the surgical bed.
::MOP3::Post-op. changes at left UIQ breast with parenchymal loss, architectural deformity, skin retraction and thickening.

::MSUG::suggest breast ultrasound correlation and right mag. views.
::NP::No definite focal mass lesion. Suggest follow-up.
::PL::pleomorphic

::SAR::subareolar region
::SFUFNA::Suggest follow up and considered FNA if there is interval change. 
::SFU::suggest follow up.
;~ ::SM::History: screening mammogram.
::SR::skin retraction
::STH::skin thickening
::scm::screening mammography
::dgm::diagnostic mammography

::USB::Ultrasound of both breasts shows 
::USH::Heterogenous breast tissue of bilateral breasts.
::USL::A cm hypoechoic lesion in right/left breast at o'clock/cm,
::USN::Probably benign ultrasound findings. Suggest follow up.
::WM::wire marked
::mic::microcalcifications
::ca::calcifications


;~ ^!r::
;~ reload
;~ return

;~ ^!x::
;~ suspend
;~ return

::ti::There is
::ta::There are
::asy::asymmetry
::gsy::global asymmetry
::fsy::focal asymmetry
::dsy::developing asymmetry

::br::breast
::br1::breasts
::sta::unchanged
::com::as compared to previous study.
::ic::interval change
::x/::without
::w/::with
;~ ::def::definite
::ant::anterior
::pos::posterior
::cen::central
;~ ::sug::suggest
::sus::suspicious
::usc::suggest ultrasound correlation.
::wed::well-defined
::up::upper
::lo::lower
::ou::outer
::nn::inner
::ov::oval
::rn::round
::ir::irregular
::ci::circumscribed
::ob::obscured
::pob::partially obscured
:*:pbpc::partially obscured partially circumscribed
::mlb::microlobulated
::ind::indistinct
;~ ::sp::spiculated
::nod::nodule
::pu::punctate
::am::amorphous
::cr::coarse
::coh::coarse heterogeneous
::fp::fine pleomorphic
::ple::pleomorphic
::fl::fine linear
::flb::fine linear branching
::gr::grouped
::lin::linear
::ad::architectural distortion
::tt::trabecular thickening
::uw::under the wire
::ub::under the BB
::t::the
::sca::scattered
::mc::MLO/CC
:*:ln0::Bilateral axillary lymph nodes, probably non-specific.
::moc::milk of calcium
::mlo::MLO
::cc::CC
::uo::UOQ
::ui::UIQ
::lo::LOQ
::li::LIQ
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
::uob::UOQ breast
::uib::UIQ breast
::lob::LOQ breast
::lib::LIQ breast
::mam::mammography
::disp::is dispersed on spot view, benign tissue is considered.
::tom::tomosynthesis

::thn::(due to very thin breast, only needle localization is feasible)

#Hotstring, SE
::MDB::
(
P.S. There is increased false negative rate of mammography in dense breasts. Suggest ultrasound correlation if there is clinical concern, palpable mass, history of abnormal findings of breast ultrasound or family history of breast cancer. 緻密型乳房會增加乳房攝影之偽陰性， 如有臨床考量、摸到腫塊、過去異常之乳房超音波發現或有乳癌家族史，則建議乳房超音波對照。
)
::MDS::
(
P.S. There is increased false negative rate of mammography with history of silicone injection. Suggest MRI correlation if there is clinical concern, palpable mass, history of abnormal findings of breast ultrasound or family history of breast cancer. 小針美容會增加乳房攝影之偽陰性， 如有臨床考量、摸到腫塊、過去異常之乳房超音波發現或有乳癌家族史，則建議乳房磁振造影對照。
)

::M0::
(
There are benign calcifications present bilaterally. 
- There are neither definite mass nor architectural distortion in this study.
- No definite axillary lymphadenopathy. 
)
::M1::
(
There are neither definite mass, suspicious microcalcifications nor architectural distortion in this study. 
- No definite axillary lymphadenopathy. 
)
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
send % str1 " Suggest " joinAnd(arr1) " for " side " breast" (side="bilateral"?"s":"") ".`r`n" str2 "，建議" joinAnd(arr2,"、","") "對照（" (instr(side,"b")?"雙":instr(side,"r")?"右":"左") "乳）。"
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
::MB1::
(
ACR BI-RADS 1, negative finding. Suggest follow up annually and breast ultrasound correlation if there is clinical palpable lump or prior ultrasound detected abnormality. 無異常乳房攝影發現，建議每年追蹤，若有臨床可觸摸之腫塊或已知之超音波異常則需乳房超音波檢查.
)
::MB2::
(
ACR BI-RADS category 2, benign findings of this mammography. Suggest annual mammogram follow up or ultrasound study if there is any clinical palpable lump or prior ultrasound detected abnormality. 良性乳房攝影發現建議每年追蹤，若有臨床可觸摸之腫塊或已知之超音波異常則需乳房超音波檢查.
)
::MB3::
(
ACR BI-RADS 3, probably benign finding. Suggest 6-month mammogram follow up. (If there is clinical relevant finding, ultrasound is suggested.) 可能為良性乳房攝影發現，建議間隔六個月追蹤乳房攝影。(若摸到腫塊，則需施行乳房超音波對照。) 
)
::MB4::
(
ACR BI-RADS 4, suspicious malignant lesion. Suggest tissue proof. 疑似不正常的乳房攝影發現。建議組織採檢。
)
::MB4R::
(
ACR BI-RADS 4, suspicious malignant lesion. Suggest tissue proof for the right breast. 疑似不正常的乳房攝影發現。建議組織採檢(右乳)。
)
::MB4L::
(
ACR BI-RADS 4, suspicious malignant lesion. Suggest tissue proof for the left breast. 疑似不正常的乳房攝影發現。建議組織採檢(左乳)。
)

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
send % "{bs " StrLen($.value(0)) "}"
mammoSide:=$.value(1)
,mammoHasMag:=$.value(2)!=""
,mammoHasImplant:=$.value(3)!=""
,num:=mammoDensityNum:=$.value(4)
,fastMammoScreenReport:=false
goto dt_
return

fastMammoScreenReport:
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
num:=substr(a_thishotkey,0,1)
:o:dt::
;~ resetReports()
;~ Sleep 300
dt_:
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
    CH_RIS.Parse_pacs_hx()
    ,RisHistory:=CH_RIS.pacs_hx.data
,priorDate:="",priorCount:=0, lastReport:=""

for k,row in RisHistory
	if regexmatch(examName:=row[CH_RIS.pacs_hx_colNo.examName],"is)Mammogra|乳房造影") {
        if (++priorCount>6)
            break
        if lastReport=
            lastReport:=row[CH_RIS.pacs_hx_colNo.Report]
        thisDate:=RegExReplace(row[CH_RIS.pacs_hx_colNo.ExamDate], " \d\d:\d\d:\d\d\s*$", "")
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
,finalOutput.="FINDINGS: `r`n- "

,editHwnds:=getSimpleRisEditHwnds()
,sci:=WinExist("ahk_id " sci.hwnd) ? sci : new RemoteScintilla(editHwnds[2])
,sci.ClearAll()
,sci.AddText(finalOutput)

;~ send % finalOutput
;~ sendlevel,2
if num in 1,2,3,4
    ;~ send % brDen[num] "`r`n- "
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
    ;~ MsgBox % WinExist("prettyOldHx_main ahk_class AutoHotkeyGUI")
    PostMessage,0x2030,,,,prettyOldHx_main ahk_class AutoHotkeyGUI
    
    
    if InStr(match, "2")
        Edit_SetText(getRisReports(RisHwnd)[1,2], "BI-RADS 2, benign finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)")
    else
        Edit_SetText(getRisReports(RisHwnd)[1,2], "BI-RADS 1, negative finding, suggest annual mammogram follow up or at the recommendation of the patient's physician. (If there is clinical relevant finding, ultrasound is suggested.)")
    
}

Text:=Edit_GetText(editHwnds[2])
if (Text~="i)^dt?\d?INDIC"){
    Edit_SetText(editHwnds[2], RegExReplace(Text, "i)^dt?\d?", ""))
    ,Edit_SetSel(editHwnds[2], -1, -1)
}
CH_RIS.flush()
WinFocus(getSimpleRisGuiHwnds()[2], editHwnds[2])
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
    CH_RIS.reset(1)
    thisAccNo:=getRisAccNo(RisState[2])
    if(thisAccNo=priorAccNo)
        return
    priorAccNo:=thisAccNo
    thisChartNo:=getRisChartNo(RisState[2])
    IfWinnotExist,ahk_exe MammoSR.exe
        gosub openImages
    
    ;~ if __is_CH && (CH_RIS.examName!="" || CH_RIS.refresh_info()) && InStr(CH_RIS.examName, "巡迴車")
        ;~ openHxPDF()
}

ShowLastBirads(){
    global CH_RIS
    CH_RIS.refresh_info()
    if (!CH_RIS.examName~="Mammogra|乳房造影|巡迴車") ||  InStr(CH_RIS.examName,"超音波")
        return ShowLastBiradsGUI()
    RisHistory:=CH_RIS.pacs_hx.data
    ,priorDate:="",priorCount:=0, lastReport:=""
    for k,row in RisHistory
        if regexmatch(examName:=row[CH_RIS.pacs_hx_colNo.examName],"is)Mammogra|乳房造影") {
            lastReport:=row[CH_RIS.pacs_hx_colNo.Report]
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
    send {f6}
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

if !(Text~="i)mammo|vacuum|vab|needle|localiz|stereo|tomosynthesis|guide") && !InStr(Text, "乳房超音波") {
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
	,CH_RIS.exam:=newText
	,CH_RIS.impression:=newImpressionText
	,CH_RIS.report:=AllReportText
	,CH_RIS.flush()
	,CH_RIS.activate()
    Sleep 400
    if RegExCount(CH_RIS.impression, "i)BI-RADS")>1
        MsgBox % "More than one BI-RADS?"
}

;~ if(__is_CH && InStr(CH_RIS.examName, "乳房超音波")){
    ;~ new breastUS_SendPrint()
    ;~ CH_RIS.wb.document.getElementById("printSelectButton").click()
;~ }else
    risSendReport(RisState[2], SubStr(thishotkey,2,1))

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

#ifwinactive
^1::
add_indication:="Indication: mammography report of BI-RADS 0. `n`n"
if !(CH_RIS)
    getPlace()   ; flag-aware create: proxy when __CH_RIS_CLIENT, else local owner
ch_ris.inputElements.reportText.value:=add_indication . ch_ris.inputElements.reportText.value
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
::mom::mother
::sis::sister
::gmo::grandmother
::mat::maternal
::pat::paternal
::au::aunt
::cou::cousin
::dau::daughter

:*:mmm::
run, % "RadTemplate.exe Staging\Mammography.txt",% ".\RadTemplate"
return

:*:vabb::vacuum-assisted stereotactic biopsy
:*:vabc::status post vacuum-assisted stereotactic biopsy with clip retention at

#If (__is_CH && WinActive("ahk_exe iexplore.exe") && InStr(CH_RIS.examName, "乳房超音波")) 
up::
Down::
activeIE:=WinExist("A")
MouseGetPos,mx,my
winactivate,ahk_exe G3PACS.exe
;~ WinGetPos,x,y,w,h,ahk_exe G3PACS.exe
if monitorcount>1
    MouseMove,% A_ScreenWidth+100,% A_ScreenHeight//2,0
else
    MouseMove,% A_ScreenWidth-100,% A_ScreenHeight//2,0
send % "{" SubStr(A_ThisHotkey,1) "}"
if(monitors.length()>1){
    winactivate,% "ahk_id " activeIE
    MouseMove,% mx,% my,0
}
return
#if


;; breast US
::CYSB::small, oval, hypoechoic to anechoic lesion(s) with distinct margin in bilateral breasts, r/o fibrocystic change and/or fibroadenoma.
::CYSL::small, oval, hypoechoic to anechoic lesion(s) with distinct margin in left breast, r/o fibrocystic change and/or fibroadenoma.
::CYSR::small, oval, hypoechoic to anechoic lesion(s) with distinct margin in right breast, r/o fibrocystic change and/or fibroadenoma.


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

#if __is_CH && WinActive("ahk_exe G3PACS.exe")
1::
2::
if (WinGetClass(getFocusedHwnd())~="i)edit|combo"){
    SendLevelChange(A_ThisLabel)
    return
}
SendLevelChange("numpad" A_ThisHotkey)
~numpad2::
~numpad1::
if (WinGetClass(getFocusedHwnd())~="i)edit|combo"){
    return
}
Sleep 500
SendLevelChange("q")
Sleep 500
SendLevelChange("^x")
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

:*:mic0::no suspicious microcalcifications.
:*:USBxr::
t=
(
Ultrasound-guided large core biopsy for the right  breast lesion was performed by 14G biopsy gun smoothly. Total 3 specimens were retrieved.
The patient tolerated the procedure well.
Suggest persue final result.
)
send % t
send {left 161}
return

:*:USBxl::
t=
(
Ultrasound-guided large core biopsy for the left  breast lesion was performed by 14G biopsy gun smoothly. Total 3 specimens were retrieved.
The patient tolerated the procedure well.
Suggest persue final result.
)
send % t
send {left 161}
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
send % t
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
send % t
return

::hoh::hypoechoic
::heh::hyperechoic
::ioh::isoechoic
::anh::anechoic

::u0::
t=
(
No definite suspicious focal lesion in bilateral breasts. 
- No definite lymphadenopathy. 

Impression:
BI-RADS category 1, negative finding. 
)
send % t
return



#include %a_scriptdir%\YCH_main.ahk
