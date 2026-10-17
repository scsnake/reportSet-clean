; ==============================================================================
; Library: FakeRemoteScintilla.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

class FakeRemoteScintilla {
	__New(hwnd){
		this.hwnd:=hwnd
	}

	GetSel(ByRef s,ByRef e){
		Edit_GetSel(this.hwnd, s, e)
	}
	ClearAll(){
		Edit_SetText(this.hwnd, "")
	}

	__Call(var*){
		if ! (var[1]~="i)GetSel|ClearAll")
			try {
				params:=[]
				for k,v in var
					if k=1
						fn:="Edit_" v
						,params.push(this.hwnd)
					else
						params.push(v)
				
				
				return Func(fn).call(params*)
			}
	}
	
}

