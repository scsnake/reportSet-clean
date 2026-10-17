; ==============================================================================
; Library: waitKeysUp.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

waitKeysUp(keys, timeout=2000){
	if !IsObject(keys){
		hotkey:=RegExReplace(keys, "^[$~\*]","")
		,hotkey:=RegExReplace(hotkey,"i) +up$", "")
		,keys:=[]
		Loop {
			if RegExMatch(Hotkey, "^([<>])?([!^#\+])", match){
				k:=match1="<"?"L":match1=">"?"R":""
				if match2=!
					k.="Alt", keys.push(k)
				else if match2=^
					k.="Ctrl", keys.push(k)
				else if match2=#
					if k=
						keys.push("LWin"), keys.push("RWin")
					else
						k.="Win", keys.push(k)
				else if match2=+
					k.="Shift", keys.push(k)
				Hotkey:=SubStr(Hotkey, StrLen(match)+1)
			}else{
				keys.push(Hotkey)
				break
			}
		}
	}
	Loop {
		AllUp:=true
		for k,key in keys
			AllUp&=!GetKeyState(key)
		Sleep 10
	}until (A_Index>timeout/10) || AllUp
	return AllUp
}

