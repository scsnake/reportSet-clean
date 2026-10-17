; ==============================================================================
; Library: OpText.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

#include <RegExSplit>
#include <Join>

;~ MsgBox % OpText(clipboard)

OpText(ByRef str){
	static lungLobesAbbr:="RUL|RML|RLL|LUL|LLL"
		, lungLobesFull:="(?:right|left) +(?:upper|lower|middle) +lobe"
		, op:="(?:proper +)?(?:(?:bi-?)?lobectomy|(?:bi-?)?segmentectomy|wedge resection)"
		, lungOp1:="i)(" lungLobesAbbr ")((?:\W| and )(?:" lungLobesAbbr "))? +(" op ")"
		, lungOp2:="i)(" lungLobesFull ") +(" op ")"
		, lungOp3:="i)(" lungLobesFull ")ctomy"
		
	ret:=[]
	for k,v in RegExMatchAll(str, lungOp1).List {
		if !ret.haskey(v[3])
			ret[v[3]]:=[]
		if !hasVal(ret[v[3]], val:=v[1] RegExReplace(v[2], " and ", "/"))
			ret[v[3]].push(val)
	}
		
	
	for k,v in RegExMatchAll(str, lungOp2).List {
		v[1]:=getAbbr(v[1])
		if !ret.haskey(v[2])
			ret[v[2]]:=[]
		if !hasVal(ret[v[2]], v[1])
			ret[v[2]].push(v[1])
	}
	
	for k,v in RegExMatchAll(str, lungOp3).List {
		v[2]:="lobectomy"
		,v[1]:=getAbbr(v[1])
		if !ret.haskey(v[2])
			ret[v[2]]:=[]
		if !hasVal(ret[v[2]], v[1])
			ret[v[2]].push(v[1])
	}
		
	retStr:=""
	for k,v in ret
		if v.length() {
			lobes:=""
			for x,y in v
				for m,n in RegExMatchAll(y, lungLobesAbbr).list
					if !InStr(lobes, n[0])
						lobes.=n[0] "/"
			retStr.= "status post " SubStr(lobes,1,-1) " " k ". "
		}
			
	
	return (retStr)
}


getAbbr(ByRef str){
	ret:=
	Loop,Parse,str,%a_space%
		ret.=StringUpper(SubStr(A_LoopField,1,1))
	return ret
}
