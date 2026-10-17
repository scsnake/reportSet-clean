#include <RisImpax>

class RadiologyReportTemplate {
	__New(RisHwnd=""){
		;~ for ["indication", "technique", "findings", "impression"]
		
		
	}
	
	
}

trimExamName(examName){
	if RegExMatch(examName, "i)(CT|MRI) (With)?\/?(Without)? Contrast\-([\w ]+)", match)
		return match1 " " (match2&&match3?"∓":match1?"+":"-") (InStr(match4,"neck")?"Neck":match4)
	else if RegExMatch(examName, "i)Chest : (PA|AP) View", match)
		return "CXR" (match1="AP"?" (AP)":"")
	else if (examName="Abdomen:KUB")
		return "KUB"
	else
		return examName
}
;~ MsgBox % trimExamName("CT With/Without Contrast-Head and Neck(Skull Base to Clavicle)")
;~ #y::
;~ MsgBox % formatExamName()
;~ return 

;~ esc::ExitApp

; use hwnd or input string
formatExamName(RisHwnd=""){
	if((RisHwnd+0)=RisHwnd){
		if !WinExist("ahk_id " RisHwnd) && !WinExist("ahk_id " RisHwnd:=RisOpened()[2]) 
			return
	}else
		useString:=RisHwnd
	
	static abbr:={"head and neck\(skull base to clavicle\)": "neck"
		, "(\w) spine": "spine"}
	, part_abbr:={b: "brain"
		, n: "neck"
		, c: "chest"
		, a: "abdomen"
		, p: "pelvis"}
	
	info:=[]
	if (useString=""){
		
		ExamItems:=parseRisExamItems(getRisExamItems(RisHwnd))
	}else{
		ExamItems:=[[useString]]
	}
	
	for k,exam in ExamItems[1] {
		if matchAllKeywords(exam, "low\Wdose", "lung|chest|thora"){
			info.push({Modality: "CT"
				, contrast: "-"
				, part:  ""
				, name: "Low dose chest CT"})
		}else if matchAllKeywords(exam, "CT", "angiography", "coronary"){
			info.push({Modality: "CT"
				, contrast: "+"
				, part:  ""
				, name: "Coronary CT angiography"})
		}else if matchAllKeywords(exam, "CT", "calcium", "coronary"){
			info.push({Modality: "CT"
				, contrast: "+"
				, part:  ""
				, name: "Coronary calcium score"})
		}else if matchAllKeywords(exam, "CT", "perfusion"){
			info.push({Modality: "CT"
				, contrast: "+"
				, part:  "" 
				, name: "CT angiography of brain and neck, with cerebral CT perfusion"})
		}else if RegExMatch(exam, "is)^(CT|MR).+?(\bwith\b)?\/?(\bwithout\b)?.+?-+(\b.+?)$", match){
			info.push({Modality: match1
				, contrast: match2&&match3?"-+":match3?"-":"+"
				, part:  match4})
		}else  {
			info.push({Modality: matchAllKeywords(exam, "CT")?"CT":matchAllKeywords(exam, "MRI?")?"MR":""
				, contrast: ""
				, part:  "" 
				, name: RegExReplace(exam, "\([^\(\)]*(self-paid|自費|HMC|健檢|health|check)[^\(\)]*\)", "")})
		}
	}
	
	AllBodyParts:="", AllSpineParts:="", AllOtherParts:=[], AllOtherNames:=[]
	,Modality:="`n", contrast:="`n"
	
	for k,v in info {
		if !v.haskey("name"){
			if RegExMatch(v.part, "i)(\w) spine", m){
				AllSpineParts.=m1
			}else if (v.part~="i)brain|neck|chest|abdomen|pelvis"){
				AllBodyParts.=InStr(v.part, "neck")?"n":SubStr(v.part,1,1)
			}else if (v.part){
				AllOtherParts.push(v.part)
			}
		}else{
			AllOtherNames.push(v.name)
		}
		Modality.=v.Modality "`n"
		,contrast.=v.contrast "`n"
	}
	
	studies:=[]
	,parts:=[]
	if (AllBodyParts){
		p:="bncap"
		Loop,parse,p
			if InStr(AllBodyParts, A_LoopField)
				parts.push(part_abbr[A_LoopField])
		
	}
	if (AllSpineParts){
		sp:=[], p:="ctl"
		Loop,parse,p
			if InStr(AllSpineParts, A_LoopField)
				sp.push(A_LoopField)
		parts.push(ArrToStr(sp, "-", false) " spine")
		
	}
	for k,v in AllOtherParts
		parts.push(v)
	if parts.maxindex() {
		Modality:=InStr(Modality, "`nCT`n")?"CT":InStr(Modality, "`nMR`n")?"MRI":""
		,contrast:=InStr(contrast, "`n-+`n") || (InStr(contrast, "`n+`n")&& InStr(contrast, "`n-`n") )?"without/with":InStr(contrast, "`n-`n")?"without":"with"
		, parts:=[Modality " of the " ArrToStr(parts) " " contrast " intravenous contrast enhancement"]
	}
	
	for k,v in AllOtherNames 
		parts.push(v)
	
	parts:=ArrToStr(parts, "; ", false)
	StringLower,parts,parts
	parts:=RegExReplace(parts, "\bct\b", "CT")
	,parts:=RegExReplace(parts, "\bmri\b", "MRI")
	if RegExMatch(parts, "([ctl-]+) spine", m){
		sp:=m1
		StringUpper,sp,sp
		parts:=RegExReplace(parts, "([ctl-]+) spine", sp " spine")
	}
	
	;~ return StringUpperFirst(parts)
	return parts
}

matchAllKeywords(ByRef str, keywords*){
	for k,v in keywords
		if !(str~="i)\b(" v ")\b")
			return false
	
	return true
}


ArrToStr(arr, Join=", ", lastAnd=true){
	str:="", k:=0
	for k,v in arr
		str.=(lastItem:=v Join)
	if k=0
		return str
	else if (k=1 || !lastAnd)
		return SubStr(str, 1, (-1)*StrLen(Join))
	else 
		return SubStr(str, 1, (-1)*StrLen(lastItem Join)) " and " v
}