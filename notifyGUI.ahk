;~ threadIds:=CriticalObject(" (&ThreadIds) "), threadIds["notify"]:=DllCall("GetCurrentThreadId"), clipboard.="notify " DllCall("GetCurrentThreadId") "``n"
#persistent
#notrayicon
#SingleInstance,Force
DetectHiddenWindows,on
#include <WM_COPYDATA>
#include <JXON>
process,priority,,R

OnMessage(0x4a, "ON_WM_COPYDATA")

setbatchlines,-1


gui,main: +hwndguihwnd
WinSetTitle,% "ahk_id " guihwnd,,% "notifyGUI_main"
SetTimer,exit,3000

frame:=newX:=newY:=0
alive:=1
Loop, 4
{
	Gui, notify%A_Index%: -Caption +ToolWindow +AlwaysOnTOp
	Gui, notify%A_Index%: Color, white
}
return
show:
if(!frame || frame="")
	frame:=400
if(!newX || !newY){
	mousegetpos,newX,newY
}
if (frame<20){
	settimer,show,off
	settimer,hide,-1
	return
}
cornerX1:=floor(newX-frame/2),cornerY1:=floor(newY-frame/2)
,cornerX2:=floor(newX+frame/2),cornerY2:=floor(newY+frame/2)
Gui, notify1: Show, % "x" cornerX1 " y" cornerY1 " w" frame " h2 NoActivate"
Gui, notify4: Show, % "x" cornerX1 " y" cornerY2 " w" frame " h2 NoActivate"
Gui, notify2: Show, % "x" cornerX1 " y" cornerY1 " w2 h" frame " NoActivate"
Gui, notify3: Show, % "x" cornerX2 " y" cornerY1 " w2 h" frame " NoActivate"
frame:=floor(frame/2)
settimer,show,-50
return
hide:
loop 4
	gui, notify%a_index%:hide
frame:=newX:=newY:=0
return



exit:
if !WinExist("scsnake_autorun_main ahk_class AutoHotkeyGUI")
	ExitApp
return



On_WM_COPYDATA(wParam, lParam, msg, hwnd) {
	global newX,newY,frame
; dwData = Command
; cbData = String lenght
; lpData = String
	dwData := NumGet(lParam+0, 0)
	,cbData := NumGet(lParam + A_PtrSize)
	,lpData := NumGet(lParam + 2*A_PtrSize)
	,str := StrGet(lpData)
	
	;~ str:=lpData
	
	If  (dwData = 19) ; CMD_CURRENTPOSITION
	{
		try
			j:=JXON_load(str)
		catch
			return
		
		if(j.haskey("show")){
			newX:=j.newX
			,newY:=j.newY
			,frame:=j.frame
			SetTimer,Show,-1
		}else if(j.haskey("hide")){
			SetTimer,Hide,-1
		}
		
		
	}
}