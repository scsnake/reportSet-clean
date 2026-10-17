; ==============================================================================
; Library: SetWindowsHookEx.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

;~ return
; http://www.autohotkey.com/board/topic/45574-detecting-keystrokesmouse-movement-not-logging-them/#entry283734

;~ hHookKeybd := SetWindowsHookEx(WH_KEYBOARD_LL	:= 13, RegisterCallback("__Keyboard", "Fast"))
;~ hHookMouse := SetWindowsHookEx(WH_MOUSE_LL   := 14, RegisterCallback("__MouseMove", "Fast"))
;~ UnhookWindowsHookEx(hHookMouse)



SetWindowsHookEx(idHook, pfn)
{
   Return DllCall("SetWindowsHookEx", "int", idHook, "Ptr", pfn, "Ptr", DllCall("GetModuleHandle", "Ptr", 0 ,"Ptr"), "Uint", 0, "Ptr")
}


UnhookWindowsHookEx(hHook)
{
   Return DllCall("UnhookWindowsHookEx", "Ptr", hHook)
}
/*
__MouseMove(nCode, wParam, lParam){
	If nCode<0
		return CallNextHookEx(nCode, wParam, lParam)
	x:=NumGet(lParam+0, 0, "int")
	,y:=NumGet(lParam+0, 4, "int")
	
	if(wParam=0x200){  ;WM_MOUSEMOVE 
	}else if(wParam=0x201){ ; WM_LBUTTONDOWN
	}else if(wParam=0x202){ ; WM_LBUTTONUP
	}else if(wParam=0x204){ ; WM_RBUTTONDOWN 
	}else if(wParam=0x205){ ; WM_RBUTTONUP  
	}else if(wParam=0x20A){ ; WM_MOUSEWHEEL 
	}else if(wParam=0x20E){ ; WM_MOUSEHWHEEL  
	}
	
	Return CallNextHookEx(nCode, wParam, lParam)
}


__Keyboard(nCode, wParam, lParam)
{
	Critical
	SetFormat, Integer, H
	If ((wParam = 0x100)  ; WM_KEYDOWN
	|| (wParam = 0x101))  ; WM_KEYUP
	{
		KeyName := GetKeyName("vk" NumGet(lParam+0, 0))
		Tooltip, % (wParam = 0x100) ? KeyName " Down" : KeyName " Up"
	}
	Return CallNextHookEx(nCode, wParam, lParam)
}

*/
CallNextHookEx(nCode, wParam, lParam, hHook = 0)
{
   Return DllCall("CallNextHookEx", "Ptr", hHook, "int", nCode, "UPtr", wParam, "Ptr", lParam, "Ptr")
}