; ==============================================================================
; Library: StrPutVar.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

StrPutVar(string,ByRef var,encoding){
VarSetCapacity(var,StrPut(string,encoding)
*((encoding="utf-16"||encoding="cp1200")?2:1),00)
return StrPut(string,&var,encoding),VarSetCapacity(var,-1)
}

StrPutVar16(string){
    StrPutvar(string, ret, "utf-16")
    return ret
}

/*
StrPutVar(string, ByRef var, encoding)
{
    ; Ensure capacity.
    VarSetCapacity( var, StrPut(string, encoding)
        ; StrPut returns char count, but VarSetCapacity needs bytes.
        * ((encoding="utf-16"||encoding="cp1200") ? 2 : 1) )
    ; Copy or convert the string.
    return StrPut(string, &var, encoding),VarSetCapacity(var,-1)
}
*/