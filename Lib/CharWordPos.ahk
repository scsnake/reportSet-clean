; ==============================================================================
; Library: CharWordPos.ahk
; Classification: Modified Third-Party
; Original Author: scsnake (with MCode_Bin2Hex community snippet)
; Origin: simpleRIS UTF-8 Caret Math
; License: MIT (Repository License)
; Local Modifications: Workstation-specific extensions
; ==============================================================================

#include <StrPutVar>

;~ SetFormat,integer,h


;~ n := StrPutVar("■", UTF8, "UTF-8")
;~ MsgBox % n-1
;~ ExitApp

;~ MsgBox % MultiByteChars("一二三四五")

;~ controlget,hwnd,hwnd,,Scintilla1,simple RIS
;~ s:=new RemoteScintilla(hwnd)
;~ MsgBox % StrPut("■", "utf-8")
;~ MsgBox % Asc("■")
;~ s._setsel(0,8)
;~ ExitApp

;~ UTF16 := "■" 
;~ n := StrPutVar(UTF16, UTF8, "UTF-8")
;~ MsgBox % MCode_Bin2Hex(&UTF8, n-1)

MCode_Bin2Hex(addr, len) {
    Static fun
    If (fun = "") {
        If Not A_IsUnicode
        h=
        ( LTrim Join
            8B54240C85D2568B7424087E3A53578B7C24148A07478AC8C0E90480F9090F97C3F6
            DB80E30702D980C330240F881E463C090F97C1F6D980E10702C880C130880E464A75
            CE5F5BC606005EC3
        )
        Else
        h=
        ( LTrim Join
            8B44240C8B4C240485C07E53568B74240C578BF88A168AC2C0E804463C090FB6C076
            066683C037EB046683C03066890180E20F83C10280FA09760C0FB6D26683C2376689
            11EB0A0FB6C26683C03066890183C1024F75BD33D25F6689115EC333C0668901C3
        )
        VarSetCapacity(fun, n := StrLen(h)//2)
        Loop % n
            NumPut("0x" . SubStr(h, 2 * A_Index - 1, 2), fun, A_Index - 1, "Char")
    }
    VarSetCapacity(hex, A_IsUnicode ? 4 * len + 2 : 2 * len + 1)
    DllCall(&fun, "Ptr", &hex, "Ptr", addr, "Ptr", len, "cdecl")
    VarSetCapacity(hex, -1) ;update StrLen
    Return hex
}

;~ MsgBox % MultiByteChars("■")
;~ MsgBox % Asc("■") "," ord("■")
;~ ExitApp
MultiByteChars(ByRef str){
	a:=0
	Loop,Parse,str
		;~ a+= (c:=Asc(A_LoopField))>0xFFFFFF?4:c>0xFFFF?3:c>0xFF?2:1
		a+= StrPutVar(A_LoopField, UTF8:="", "UTF-8")-1
	return a
}




CharToWordPos(ByRef str, ByRef start, ByRef end="", swap=0){
	
	if(End="")
		End:=start
	
	if(start=0 && End=0){
		start:=0, End:=0
		return
	}
	
	if(start>End)
		start0:=End, End0:=start, swap:=1
	else
		start0:=start, End0:=End
	;~ }else{
	
	if (start0=-1)
		start0:=(l:=StrLen(str))*10
		,_start:=l
	if (end0=-1)
		end0:=(_End:=(l?l:StrLen(str)))*10
	
	if(start0!=-1 && End0!=-1){
		_start:=_end:=""

		,CharPos:=0
		Loop,Parse,str
		{
			if (CharPos>start0 && CharPos>End0)
				break
			;~ CharPos+= Asc(A_LoopField)<=0xFF?1:Asc(A_LoopField)<=0xFFFF?2:Asc(A_LoopField)<=0xFFFFFF?3:4
			CharPos+= StrPutVar(A_LoopField, UTF8, "UTF-8")-1
			if (CharPos>=start0 && _start="")
				_start:=A_Index
			if (CharPos>=End0 && _end="")
				_End:=A_Index
			ind:=A_Index
		}
	}
		
	;~ }
	
	
	if(!swap)
		start:=_start?_start:ind, End:=_end?_end:ind
	else
		start:=_end?_end:ind, End:=_start?_start:ind

}

WordToCharPos(ByRef str, ByRef start, ByRef end="", swap=0){
	if(End="")
		End:=start
	
	if(start=0 && End=0){
		start:=0, End:=0
		return
	}
	
	
	if(start>End)
		start0:=End, End0:=start, swap:=1
	else
		start0:=start, End0:=End
		;~ _start:=End, _End:=start
		;~ ret:=WordToCharPos(str, _End, _start, 1)
		;~ _start:=ret.1, _End:=ret.2
	;~ }else{
	
	if (start0=-1)
		start0:=(l:=StrLen(str))
	if (end0=-1)
		end0:=(l?l:StrLen(str))
	
	
		_start:=_end:=""
		;~ ,CharPos:=0
		
		,_start:=MultiByteChars(SubStr(str, 1, start0)), _End:=_start+MultiByteChars(SubStr(str, start0+1, End0-start0))
		
	;~ }
	
	if(!swap)
		return [start:=_start, End:=_End]
	else
		return [start:=_End, End:=_start]
	
	/*
	Loop,Parse,str
	{
		if (A_Index>start && A_Index>End)
			break
		;~ CharPos+= Asc(A_LoopField)<=0xFF?1:Asc(A_LoopField)<=0xFFFF?2:Asc(A_LoopField)<=0xFFFFFF?3:4
		CharPos+= StrPutVar(A_LoopField, UTF8, "UTF-8")-1
		if (A_Index=start && _start="")
			_start:=CharPos
		if (A_Index=End && _end="")
			_End:=CharPos
	}
	start:=_start?_start:CharPos, End:=_end?_end:CharPos
	*/
}