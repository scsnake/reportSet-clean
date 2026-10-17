; ==============================================================================
; Library: RegExSplit.ahk
; Classification: Modified Third-Party
; Original Author: AutoHotkey Community / scsnake
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Local Modifications: Workstation-specific extensions
; ==============================================================================

RegExSplit(txt, regex){
	i:=0, j:=1
	,a:=[], b:=[]
	while i:=RegExMatch(txt, regex, match, j) {
		a.push(SubStr(txt,j,i-j))
		,b.push(match)
		,j:=i+StrLen(match)
	}
	a.push(SubStr(txt,j))
	return {split: a, match: b}
}
/*
f(ByRef m){
	return SubStr(m[0],1,1)
}

txt=aa11bb22cc33
p=\d+
MsgBox % RegExReplaceFn(txt, p , "f")
*/

RegExReplaceFn(txt, regex, Fn, ByRef List="", ByRef Dict="", params=""){
	if !IsFunc(Fn) || !IsFunc(Fn:=Func(Fn))
		return
	
	if RegExMatch(regex, "^[\w``r``n``a]+\)", match) && !InStr(match, "O")
		regex:="O" regex
	else
		regex:= "O)" regex
	
	i:=0, j:=1
	,str:=""
	
	out:= IsObject(list) || IsObject(dict)
		
	
	while i:=RegExMatch(txt, regex, match, j) {
		str.=SubStr(txt,j, i-j)
		,str.=(params=""?Fn.call(match):Fn.call(match, params))
		
		if(out){
			tmp1:=[], tmp2:=[]
			Loop % match.Count()+1 {
				tmp1[A_Index-1]:=(val:=match.value(A_Index-1))
				if((name:=match.Name(A_Index-1))!="")
					tmp2["" name]:=val
			}
			list.push(tmp1)
			,dict.push(tmp2)
		}
		
		j:=i+match.len(0)
	}
	return str SubStr(txt, j)
}

RegExMatchAll(txt, regex){
	if RegExMatch(regex, "^[\w``r``n``a]+\)", match) && !InStr(match, "O")
		regex:="O" regex
	else
		regex:= "O)" regex
	
	i:=0, j:=1
	,list:=[], dict:=[]
	while i:=RegExMatch(txt, regex, match, j) {
		tmp1:=[], tmp2:=[]
		Loop % match.Count()+1 {
			tmp1[A_Index-1]:=(val:=match.value(A_Index-1))
			if((name:=match.Name(A_Index-1))!="")
				tmp2["" name]:=val
		}
		list.push(tmp1)
		,dict.push(tmp2)
		,j:=i+match.len(0)
	}
	return {list: list, dict: dict}
}

RegExCount(txt, regex){
	Count:=0
	,RegExReplace(txt, regex, "", Count)
	return Count
}