CoordMode,mouse,Screen
#SingleInstance,force


mon:=monitorinfo()
mon_index := mon.length()
xy_coord:=[ (mon[mon_index].l+20) , (mon[mon_index].t+mon[mon_index].h//2)]

Count:=1

return
#IfWinActive,ahk_exe G3PACS.exe
~End::
Count:=0
settimer,show,-1500
return


~Home::
~Right::
Count:=1
settimer,show,-1500
return


~Up::
Count-=1
settimer,show,-500
return

~Down::
Count+=1
settimer,show,-1500
return
#IfWinActive

~esc::
ExitApp
return

Show:
OnScreenDisplay(Count, , "30", ,, xy_coord)
return