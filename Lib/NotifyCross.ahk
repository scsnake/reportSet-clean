
#include <MonitorInfo>


;~ n:=new NotifyCross
;~ n.Show(1500, 1200)
;~ Sleep 1000
;~ ExitApp
class NotifyCross {
	__New(Color="red"){
		CoordMode,mouse,Screen
		this.guiHwnds:=[]
		loop 4 {
			gui,__notify%a_index%: -Caption +ToolWindow +AlwaysOnTOp +lastfound +hwndguihwnd
			this.guiHwnds.push(guihwnd)
			gui,__notify%a_index%:  Color, % color
		}
		this.hideFn:=this.hide.bind(this)
		
	}
	
	Show(CenterX, CenterY, CenterSpace=12, length=28, width=2, hideAfter=1000){
		MonitorInfo:=MonitorInfo()
		,which:=whichMonitor(CenterX, CenterY, MonitorInfo)[1]
		,thisMonitor:=MonitorInfo[which]
		,halfWidth:=Floor(width/2)
		,x:=[CenterX-halfWidth, CenterX+CenterSpace, CenterX-halfWidth, length=0?thisMonitor.l:CenterX-CenterSpace-length]
		,y:=[length=0?thisMonitor.t:centerY-CenterSpace-length, CenterY-halfWidth, CenterY+CenterSpace, CenterY-halfWidth]
		,a:=[x[1]+width-1, length=0?thisMonitor.r:x[2]+length-1, x[3]+width-1, CenterX-CenterSpace]
		,b:=[CenterY-CenterSpace, y[2]+width-1, length=0?thisMonitor.b:y[3]+length-1, y[2]+width-1]
		Loop 4 {
			id:=this.guiHwnds[i:=A_Index]
			gui,%id%:Show,% "x" x[i] " y" y[i] " w" a[i]-x[i]+1 " h" b[i]-y[i]+1 " NoActivate"
		}
		if (hideAfter>0){
			fn:=this.hideFn
			SetTimer,% fn,% (-1)*hideAfter
		}
		
	}
	
	hide(){
		Loop 4 {
			id:=this.guiHwnds[i:=A_Index]
			gui,%id%:hide
		}
	}
	
	__Delete(){
		for k,v in this.guiHwnds
			WinClose,ahk_id %v%
	}

}

