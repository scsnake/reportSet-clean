; ==============================================================================
; Library: sendByClipboard_test.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================


	sendByClipboard(byref str, bs=0){
		global __HotstringEnhancer_pClipboard
		sendlevel,0
		focused:=getFocusedHwnd()
		wingetclass,class,ahk_id %focused%
		keywait,%  substr(str,0,1) ,T0.4
		if(class="Scintilla"){
			sci:=new RemoteScintilla(focused)
			if(bs)
				sci.DeleteRange(sci.getCurrentPos()-bs, bs)
			if(str!="")
				sci.AddText(str)
		}else{
			;~ keywait,% """" substr(str,0,1) """",T0.4
			;~ sleep 20
			
			if !instr(class, "Edit") {
				if bs>0
					send {bs %bs%}
				if __HotstringEnhancer_pClipboard=
					__HotstringEnhancer_pClipboard:=clipboardall
				clipboard:=str
				SetTimer,__HotstringEnhancer_pClipboard, -500
				while clipboard!=str && a_index<300
					sleep -1
				;~ keywait,bs,T0.1
				;~ sleep 20
				send ^v
			}else{
				if bs>0
					Edit_DeleteText(focused, "", bs)
				Edit_InsertText(focused, str)
				,Edit_ScrollCaret(focused)
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
		blockinput,mousemove
		resetHotstringBuffer(-1)
		blockinput,mousemoveoff
	}
	
	
	__HotstringEnhancer_pClipboard(){
		global __HotstringEnhancer_pClipboard
		clipboard:=__HotstringEnhancer_pClipboard
		,__HotstringEnhancer_pClipboard:=""
	}