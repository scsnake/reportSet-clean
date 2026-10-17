SetTitleMatchMode,2
coordmode,mouse,screen
SetBatchLines,-1

x:=[1138,3222]
y:=[361,393,431,462]
hx:=[]
#If WinActive("III Annotation Tool - Google Chrome") and !EditMode
a::
KeyWait,% A_ThisHotkey,1
send !1
return
s::
KeyWait,% A_ThisHotkey,1
send !2
return
d::
KeyWait,% A_ThisHotkey,1
send !3
return
f::
KeyWait,% A_ThisHotkey,1
send !4
return
g::
KeyWait,% A_ThisHotkey,1
send !5
return
_q:
q::
view(1,1,2,2)
return
w::
view(1,3,2,4)
return
e::
view(1,1,2,3)
return
r::
view(1,2,2,4)
return
+q::
keywait,shift,1
view(1,2,2,1)
return
+w::
keywait,shift,1
view(1,4,2,3)
return
+e::
keywait,shift,1
view(1,3,2,1)
return
+r::
keywait,shift,1
view(1,4,2,2)
return

1::
2::
3::
4::
Move(x[1], y[A_ThisHotkey])
hx[1]:=A_ThisHotkey
return

z::
MouseGetPos,mx,my
mouseclick,l,2894,92,1,0
MouseMove,% mx,% my,0
return


~Right::
if !(A_PriorHotkey=A_ThisHotkey && A_TimeSincePriorHotkey<400)
	return
~Space::
MouseGetPos,mx,my
mouseclick,l,2836,96
mouseclick,l,4883,96
MouseMove,% mx,% my,0
hx:=[]
;~ gosub _q
return
#If 

ClickScreen(which="12"){
	Sleep 500
	if InStr(which, "1")
		MouseClick,l,2101,1259,1,0
	if InStr(which, "2")
		MouseClick,l,4132,1414,1,0
}

Move(a,b,c="",d=""){
	MouseGetPos,mx,my
	mouseclick,l,% a,% b,1,0
	send !1
	if(c!="" && d!="")
		mouseclick,l,% c,% d,1,0
	send !1
	;~ ClickScreen((c!="" && d!="")?"12":"1")
	MouseMove,% mx,% my,0
}

view(a,b,c="",d=""){
	global x,y,hx
	MouseGetPos,mx,my
	clicked:=""
	if (hx[a]!=b){
		mouseclick,l,% x[a],% y[b],1,0
		hx[a]:=b, clicked.=a
		send !1
	}
		
	if(c!="" && d!="")
		if(hx[c]!=d){
			mouseclick,l,% x[c],% y[d],1,0
			hx[c]:=d, clicked.=c
			send !1
		}
			
	ClickScreen(clicked)
	MouseMove,% mx,% my,0
}

esc::
if (A_PriorHotkey=A_ThisHotkey && A_TimeSincePriorHotkey<400)
	ExitApp
if (EditMode:=!EditMode)
	ShowToolTip("Edit Mode")
else
	ShowToolTip("Hotkey Mode")
return