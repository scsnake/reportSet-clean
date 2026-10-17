; ==============================================================================
; Library: RegExReplaceC.ahk
; Classification: Pure Third-Party
; Original Author: majkinetor
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/board/topic/45851-regexreplacec-with-callouts/
; ==============================================================================

RegExReplaceC( ByRef Haystack, Pattern, Func, H=""){  ;by majkinetor
	_RegExReplaceC(Func,_,Pattern), RegExMatch(Haystack, Pattern "(?C_RegExReplaceC)" ), _RegExReplaceC(res, i := 1)
	return res SubStr(Haystack, i)
}

_RegExReplaceC( ByRef m="", ByRef n="", p="", h="" ) {
	static
	if (n = "") {
		names := res := "", func := m, mc := Object(), i:=j:=1
		while k := InStr(p, "(?<", 0, j)
			j := InStr(p, ">",0,k+3+1), names .= SubStr(p, k+3, j-k-3) "|"
		return
	}
	ifEqual, p,,return m := res, n := i
	loop, 10				 ;we don't have m0 here so lets just put some value big enough for general purpose
		mc[ A_Index ] := m%A_Index%
	loop, parse, names, |
		mc[ A_LoopField ] := m%A_LoopField%

	mc.0 := m, mc.pos := p, mc.eventInfo := A_EventInfo, res .= SubStr(h, i, p-i) %func%(mc), i := p + strlen(m)
	return 1
}


/*
text= 
   (Ltrim 
      www.google.com 
      www.yahoo.com 
      www.autohotkey.com 
   ) 
   msgbox % RegExReplaceC(text, "`am)www\.(.+?)\.com$", "MyFunc") 

  ;google (58 ms)
  ;yahoo (159 ms)
  ;autohotkey (163 ms)
return 

MyFunc(m) { 
	match := m.0
	RunWait, %COMSPEC% /C ping %match% -n 1 >out, ,Hide 
	FileRead out, out 
	RegExMatch(out, "([0-9]+)ms", o) 
	return m.1 " (" o1 " ms)" 
}
*/