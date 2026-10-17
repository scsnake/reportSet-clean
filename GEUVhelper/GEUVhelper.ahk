#include <GEUV>
SetBatchLines,-1
CoordMode,mouse,Screen
SetTitleMatchMode,2
DetectHiddenWindows,On
sendmode input
#SingleInstance,force
#Persistent
#NoTrayIcon
#InputLevel, 0
#InstallKeybdHook
#InstallMouseHook
process,Priority,,h
OnExit,OnExit

SendLevel,2
GroupAdd,GEUV,ahk_exe Miv2Lib.exe
SetTimer,refreshGEUVhwnd,1000
return

refreshGEUVhwnd:
if  !GEUVViewer.chartNo || !WinExist(GEUVViewer.chartNo " ahk_group GEUV")
	GEUVViewer:=new GEUV
return

#IfWinActive,ahk_group GEUV
;~ tab::
;~ GEUVViewer.NavigatorToggle()
;~ return

`::
send {F1}
;~ GEUVViewer.ShowPacsHx()
return


del::
GEUVViewer.resetStudy()
return
#IfWinActive


;~ esc::
OnExit:
ExitApp

