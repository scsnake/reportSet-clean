#include <RegExSplit>
#include <portalLib>

;~ txt1=
;~ (
;~ INDICATION: Follow up. 

;~ TECHNIQUE: CT of the brain and chest without/with intravenous contrast. 
;~ COMPARISON: 2016/06/10.
;~ FINDINGS: 
;~ - Lung/airway: 
  ;~ -- Status post RUL lobectomy. 
  ;~ -- Other minor or non-specific lung parenchymal change. 
;~ - Pleura: no pleural effusion. 
;~ - Mediastinum: small mediastinal lymph nodes. 
;~ - Heart/great vessel: calcification of the aorta. 
;~ - Bone: spondylosis with marginal spur formation. 
;~ - Brain: no abnormal enhancing lesion in the brain parenchyma. 
;~ - Other: hypodense lesion(s) in kidney(s), probably cyst(s). 

;~ (RUL: right upper lobe.)
;~ )


;~ txt2=
;~ (
;~ > Neither abnormal focal mass nor abnormal enhancement in the brain parenchyma
;~ > Normal sized sulci, fissures and ventricles.
;~ > No obvious abnormality at cranial vault and skull base.
;~ )

;~ a:=new ReportText(txt)
;~ MsgBox % (a.containsStr("metastas"))
;~ ExitApp

;~ a:=new ReportText(txt2)
;~ b:=a.getStructure()
;~ MsgBox % exploreobj(b)
;~ ExitApp
 
class ReportText {
	static sentenceRE:="([a-zA-Z]|\d+ |\d+\.\d+ )([^\.\;\?\!\r\n\:]|(?:\d\.\d))+([\.\;\?\!\r\n\:])"
	,bulletRE:="^( +)?(\d+\. +|\(?\d+\) *|[-=\+\*#@><]+ +)"
	,negativeRE:="i)^(\s*?)(there(\'s|\'re| +is| +are| +was| +were) +)?(normal|no|non|not|none|neither|negative|absen(t|ce)|resolv(ed|ing)|resolution|regress(ed|ing|sion)|disappear(ed|ance))\b"
	,suspectRE:="i)\bsuspect|\bsuspi|(\brule out\b)|\br\/o\b|(\bnot[ a-z]+exclude)"
	,parenthRE:=" ?\([^\)]{3,}\)"
	,postopRE:="i)\bpost-?op(erative)?|ectomy\b|resection|excision"
	;~ ,seimRE:="i) ?\((?:[^\)]*\bSE\b[^\)]*\bIM\b[^\)]*|[^\)]*\d+\/\d+[^\)]*)\)"
	,seimRE:="i) *\(? *(?:SE|S) *\d+[^\w\)\r\n]*(?:IM|I) *\d+(,? *(?:IM|I) *\d+)* *\)?"
	,referRE:="i) ?\([^\)]*(?:refer|key)[^\)]*\)"
	,measureRE:="i) ?\([^\)]*[\d\.]+ ?(?:mm|cm)[^\)]*\)"
	,partRE:="i)[a-z \/]+: ?"
	,measurementRE:="i)(a +)?(\d+(?:\.\d+)? *[cm]m)( *)(\w?)"

	
	__New(ByRef txt){
		this.Text:=txt
		,this.sentences:=[]
		,this.linebreak:="`r`n"
		,this.bullet:="- "
		,this.bullet2:="-- "
		,this.indent2:="  "
	}
	
	basicTextCleanUp(ByRef txt){
		txt:=RegExReplace(txt, " {2,}", " ")
		,txt:=RegExReplace(txt, "([,;])(\w)", "$1 $2")
		,txt:=RegExReplace(txt, "i)(\D)(\.)([^0-9\s])", "$1$2 $3")
		return txt:=RegExReplace(txt, "\.{2,}", ".")
	}
	
	AddDotEnd(ByRef txt){
		ret:=""
		loop,Parse,txt,`n,`r
			if (SubStr(RTrim(A_LoopField),0,1)~="\w")
				ret.=RTrim(A_LoopField) "." this.linebreak
			else
				ret.=A_LoopField this.linebreak
		return txt:=SubStr(ret, 1, (-1)*StrLen(this.linebreak))
	}
	
	StringUpperSentence(ByRef txt){
		txt:=RegExReplaceFn(txt, "^[a-z]|\n\s*[a-z]", "StringUpper")
		return txt:=RegExReplaceFn(txt, "\. +[a-z]", "StringUpper")
	}
	
	removeMeasurement(ByRef txt){
		if RegExMatch(txt, ReportText.measurementRE, m){
			if(m1!="" && m4~="i)[aeiou]"){
				t:= RegExReplace(txt, ReportText.measurementRE, "an $4")
			}else
				t:= RegExReplace(txt, ReportText.measurementRE, "$1$4")
			
			t:=RegExReplace(t, "i)(, *)?(up to|about)[\w ]+", "")
		}else
			t:=txt
		return t
	}
	
	toImpression(){
		if (Trim(txt)="minor or non-specific lung parenchymal change.")
			return "Minor or non-specific lung findings."
		
		txt:=RegExReplace(this.Text, this.parenthRE, "")
		,txt:=this.basicTextCleanUp(txt)
		,txt:=RegExReplace(txt, "m)" this.bulletRE, "")
		,txt:=this.removeMeasurement(txt)
		,txt:=RegExReplace(txt, this.partRE, "")
		,txt:=this.AddDotEnd(txt)
		,txt:=this.StringUpperSentence(txt)
		return txt
	}
	
	getStructure(){
		txt:=this.text
		,ret:=[]
		,tree:=[ret]
		,level:=1
		,indent:=[]
		Loop,Parse,txt,`r`n
		{
			
			
			if RegExMatch(A_LoopField, "\s*" ReportText.parenthRE "\s*"){
				continue
			}
			
			node:=[]
			
			if RegExMatch(A_LoopField, ReportText.bulletRE, match){
				node.indent:=match1
				,node.bullet:=match2
				,Loopfield:=SubStr(A_LoopField, StrLen(match)+1)
				
				
				
			}else{
				node.indent:=""
				,node.bullet:=""
				,Loopfield:=A_LoopField
			}
			
			bullet:=RegExReplace(node.bullet,"\d", "0")
			;~ if (bullet="--")
				;~ aaa:=1
			if !indent.haskey(level)
				indent[level]:=node.indent bullet
			else if (indent[level]!=node.indent bullet){
				if (ind:=HasVal(indent, node.indent bullet)){
					level:=ind
				}else{
					lastnode.children:=[]
					,tree[++level]:=lastnode.children
					,indent[level]:=node.indent bullet
				}
			}
			
			if !(Loopfield~="\W\s*$"){
				RegExMatch(Loopfield, "\s*$", match)
				Loopfield:=match=""?Loopfield ".":SubStr(Loopfield,1,(-1)*StrLen(match)) "." match
			}
			
			result:=RegExMatchAll(Loopfield, ReportText.sentenceRE)
			levelUp:=0
			for k,v in result.list {
				(lastNode:=node).push(v[0])
				if InStr(v[0],":"){
					node.children:=[]
					,tree[level].push(node)
					,tree[++level]:=node.children
					,node:=[], ++levelUp
				}
				
			}
			
			if (node.maxindex()>0)
				node[node.maxindex()].="`r`n"
				,tree[level].push(node)
			else if IsObject(lastnode)
				lastnode[lastnode.maxindex()].="`r`n"
			else
				lastnode:=node:=["`r`n"]
				,tree[level].push(node)
				
			
			level-=levelUp
			
		}
		return ret
	}
	
	
	getSentences(){
		txt:=this.text
		,ret:=[]
		Loop,Parse,txt,`r`n
		{
			result:=RegExMatchAll(A_LoopField, ReportText.sentenceRE)
			for k,v in result.list
				ret.push(Trim(v[0]))
		}
		return this.sentences:=ret
	}
	
	isNegative(ByRef sentence, suspectAsNegative=true){
		if suspectAsNegative
			RegExMatch(stn, ReportText.negativeRE) || RegExMatch(stn, ReportText.suspectRE)
		else
			RegExMatch(stn, ReportText.negativeRE)
	}
	
	contains(ByRef s, RegEx=false, returnFirst=true){
		if !this.sentences.maxindex()
			this.getSentences()
		ret:=[]
		
		if IsObject(s){
			if (!RegEx)
				for k, stn in this.sentences {
					if !this.isNegative() {
						for m,n in s
							if !InStr(stn,n)
								continue,2
						
						if returnFirst
							return stn 
						else
							ret.push(stn)
					}
				}
			else
				for k, stn in this.sentences {
					if !this.isNegative() {
						for m,n in s
							if !RegExMatch(stn, n)
								continue,2
						
						if returnFirst
							return stn 
						else
							ret.push(stn)
					}
				}

		}else{
			if (!RegEx)
				for k, stn in this.sentences {
					if !this.isNegative() && InStr(stn, s) {
						if returnFirst
							return stn 
						else
							ret.push(stn)
					}
				}
			else
				for k, stn in this.sentences {
					if !this.isNegative() && RegExMatch(stn, s) {
						if returnFirst
							return stn 
						else
							ret.push(stn)
					}
				}
		}
		return returnFirst?false:ret
		
	}

}
;~ MsgBox % AutoBriefReport("5______", "T__________", "46379C0FC41D0B4C9DAD87CDA9DE3CEA9B")
AutoBriefReport(chartNo, accNo, sid, ByRef PacsHx="", withTitle=true){
	static CXRExamNameRE:="i)^Chest : (AP|PA) View"
	if !PacsHx
		PacsHx:=getPacsHxByPortal(sid, chartNo, "", personId:="")
	
	CXR_PacsHx :=[]
	

	for m,n in PacsHx
		if RegExMatch(n.ExamName, CXRExamNameRE){
			CXR_PacsHx.push(n)
			if (n.accNo=accNo)
				target:=CXR_PacsHx.maxindex()
				;~ ,status:=getReportByPortal(sid, chartNo, accNo, PacsHx, personId).IOE
		}
	
	if !(target)
		return false
	
	Loop {
		item:=CXR_PacsHx[target-A_Index]
		if item.FormalVersion {
			nearAfter:=item, nearAfter["report"]:=getReportByPortal(sid, item.chartNo, item.accNo, PacsHx, personId)
			break
		}
	} until target-A_Index<=1
	
	maxindex:=CXR_PacsHx.maxindex()
	,CXR_Older:=[], CXR_Older_report:=[]
	Loop {
		item:=CXR_PacsHx[target+A_Index]
		if  item.FormalVersion {
			item.report:=getReportByPortal(sid, item.chartNo, item.accNo, PacsHx, personId)
			if !nearBefore
				nearBefore:=item
			CXR_Older.push(item)
			,CXR_Older_report.push(new ReportText(report.reportbody))
			if(CXR_Older.maxindex()>3)
				break
		}
	} until target+A_Index>=maxindex
	
	;~ if (!nearAfter || !nearBefore){
		;~ return false
	;~ }
	
	ret:=""
	,report1:=new ReportText(nearAfter.report.reportbody)
	,report2:=new ReportText(nearBefore.report.reportbody)
	
	for k,term in ["consolidation", "mass", "nodul", "infiltration", "opacit", "patch"
		, "haz", "peribronchial", "prominent", "radiopaque", "radiolucen", "densit", "marking"] {
		contain1:=report1.contains(term)
		,contain2:=report2.contains(term)
		if ((contain1 && contain2) || (contain1 && DateDiff(nearAfter.ExamDate, CXR_PacsHx[target].ExamDate)<=1)) && !InStr(ret, contain1)
			ret.=UpperFirst(contain1) " "
		else if (contain2 && DateDiff(nearBefore.ExamDate, CXR_PacsHx[target].ExamDate)<=1) && !InStr(ret, contain2)
			ret.=UpperFirst(contain2) " "
		
	}
	
	for k,term in ["pleural effusion", "pneumothorax", "pneumoperitoneum", "pneumomediastinum", "goiter", "hiatal hernia", "compression fracture"] 
		if (contain:=report1.contains(term)) && report2.contains(term) && !InStr(ret, contain)
			;~ ret.=term ". "
			ret.=UpperFirst(contain) " "
	
	for k,term in ["cardiomegaly", "calcification", "degenerati"]
		for m,v in CXR_Older_report
			if (contain:=v.contains(term)) && !InStr(ret, contain) {
				ret.=UpperFirst(contain) " "
				break
			}
	
	for term, cond in {"rib fracture": ["i)\brib","i)\bfracture"]
									,"clavicular fracture": ["i)\bclavic(le|cular)","i)\bfracture"]
									,"pulmonary metastasis": ["i)\blung|pulmonary", "i)\bmetasta(tic|sis|ses)"]
									,"bone metastasis": ["i)\bbon(e|y)", "i)\bmetasta(tic|sis|ses)"]
									,"postoperative change": [report1.base.postopRE]}
		for k,v in CXR_Older_report
			if v.contains(cond, true) {
				ret.=UpperFirst(term) ". "
				break
			}
		;~ if report1.contains(cond) && report2.contains(cond)
			;~ ret.=term ". "
		
	if !InStr(ret, "metastasis") && report1.contains("i)\bmetasta(tic|sis|ses)", true) && report2.contains("i)\bmetasta(tic|sis|ses)", true)
		ret.="Metastasis. "
	
	if (ret="")
		return false
	
	ret:=RegExReplace(ret, "i)[a-z ]+show[a-z]* *", "")
	
	if (withTitle){
		ret:="Chart No: " chartNo "`nAcession No: " accNo "`nEXAMINATION: " CXR_PacsHx[target].ExamName ".`nFINDINGS: `n" ret
	}
	
	return ret
}

DateDiff(date, refDate, AbsValue=true){
	date-=refDate, Days
	return AbsValue?abs(date):date
}

UpperFirst(str){
	a:=SubStr(str,1,1)
	StringUpper,a,a
	return a SubStr(str,2)
}