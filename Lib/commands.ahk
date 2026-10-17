; ==============================================================================
; Library: commands.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

commands(args*){
	com:=""
	for k, v in args {
		if IsObject(v)
			com.=commands(v)
		else{
			v:=RegExReplace(v, """", "\""""")
			if InStr(v, " ")
				v:= """" v """"
			com.=v " "
		}
	}
	return com 
}
