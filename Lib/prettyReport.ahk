/*
arr[lineCount, itemTitle, subItemCount] -> subItem

subItemCount=0 -> same line as itemTitle
subItemCount>0 -> sub item line below itemTitle
*/
#include <SCI>
#include <CharWordPos>
#include <RegExSplit>
;~ MsgBox % parseReport("
;~ (
;~ INDICATION: Follow up. 

;~ TECHNIQUE: CT of the chest without/with intravenous contrast.
;~ FINDINGS:
;~ - Lung/airway: 
  ;~ -- 
;~ - Pleura: no pleural effusion. 
;~ - Mediastinum: small mediastinal lymph nodes. 
;~ - Other: 
;~ - Heart/great vessel: 
;~ - Bone: spondylosis with marginal spur formation. 
;~ )")
;~ ExitApp

parseReport(byref input, returnArr=0){
	if !isobject(input){
		text:=input
		arr:=[],i:=0
		loop,parse,text,`n,`r
		{
			line:=RegExReplace(a_loopfield," *$","")
			;~ line:=a_loopfield
			if RegExMatch(line, "is)^(\w[^:]*: *)(.*)",match){
				++i,arr[i]:=[]
				arr[i, k:="" trim(match1) " "]:=[]
				if(trim(match2)!="")
					arr[i, k, 0]:=parseSentence(match2)
			}else if regexmatch(line, "is)^([^\w\(\[\{ ]|\d+[^\w\(\[\{]) +(.*)",match){
				if regexmatch(match2, "is)^([^:]+): *(.*)",m){
					++i,arr[i]:=[]
					arr[i, k:=match1 " " m1 ": "]:=[]
					if (trim(m2)!="")
						arr[i, k, 0]:=parseSentence(m2)
				}else if (trim(match2)!=""){
					++i
					arr[i]:=match1 " " parseSentence(match2, 0)
				}
			}else if regexmatch(line, "is)^( +)([^\w\(\[\{ ]{2,}|\d+[^\w\(\[\{]) +(.*)",match) && (trim(match3)!=""){
				arr[i, k].push(match1 match2 " " parseSentence(match3, 0))
			}else if (trim(line)!="" && !regexmatch(line, "^([ \W]+| *\d+[^\w\(\[\{] *)$")){
				++i
				arr[i]:=parseSentence(line, 0)
			}

		}
		if(returnArr)
			return arr
	}
	
		if isobject(input)
			arr:=input
		
		str:=""
		for k,v in arr {
			newLine:=""
			if !isobject(v) {
				newLine.=appendDot(v) "`n"
				
			}else{
				for x, y in v {
					;~ if(y.maxindex()="" && (!RegExMatch(x,"show|FINDINGS") || )
						;~ continue
					
					newLine.=appendDot(x)
					for a,b in y {
						newLine.=(a>0?"`n":"") appendDot(b)
					}
					newLine.="`n"
					if regexmatch(x,"i)^(indication|history|hx)")
						newLine.="`n"
					
					
				}
			}
			
			if RegExMatch(newLine, "is)^[\W\d]+", match) && RegExMatch(str, "is)(.+)(\r?\n)([^\r\n]+?\:)(\s+?)$", lastLine) && InStr(lastLine3,match)=1
				str:=lastLine1 lastLine2
			else if RegExMatch(newLine, "is)^\(") && RegExMatch(str, "is)(.+)(\r?\n)([^\r\n]+?\:)(\s+?)$", lastLine)
				str:=lastLine1 lastLine2
			
			str.=newLine
		}
		
		if RegExMatch(str, "is)(.+)(\r?\n)([^\r\n]+?\:)(\s+?)$", lastLine)
			str:=lastLine1 lastLine2
		
		return RegExReplace(str,"\n","`r`n")
	
}

appendDot(str){
	RegExMatch(str, "s)^(.+?)( *?)(\W?)(\s)*$", match)
	return match1 (match3=""?".":match3) match4
}

/*
capitalize after period (do not use abbr with period)
remove extra spaces
only one space after ".,;"

.. -> .
., -> , 
etc.
*/

parseSentence(text,capitalizeFirst=1){
	return text
}

_parseSentence(text, capitalizeFirst=1){
	arr:=[]
	
	text:=RegExReplace(text,"\ {2,}"," ")
	text:=RegExReplace(text,"(?<![\,\;\.])[\,\;\.]([\,\;\.])(?![\,\;\.])","$1")
	text:=RegExReplace(text,"(?<!\d)[\.\,\;](?![\d ])","$0 ")
	
	
	if !regexmatch(text,"[\(\)\[\]\{\}]") {
		arr.push(trim(text))
	}else{
		text:=trim(text),tmp:="",enclosed:=0
		loop,parse,text
		{
			if !regexmatch(a_loopfield,"[\(\)\[\]\{\}]",match)
				tmp.=a_loopfield
			else if (match && !enclosed){
				if(tmp!="")
					arr.push(tmp)
				tmp:=enclosed:=a_loopfield
			}else if (enclosed && a_loopfield=(enclosed="("?")":enclosed="["?"]":"}")){
				arr.push(tmp.=a_loopfield)
				,tmp:=enclosed:=""
			}
		}
		if(tmp!="")
			arr.push(tmp)
	}
	
	
	str:="",ind:=1+(capitalizeFirst?0:1)
	for k,v in arr {
		RegExMatch(v, "is)^( *[\(\[\{)])?(.*?)([\(\[\{)] *)?$",match)
		
		
		previousEnclosedSentence:=enclosedSentence
		
		if (match1!="" && regexmatch(match2,"\. *$"))
			enclosedSentence:=1
		else
			enclosedSentence:=0
			,str:=RegExReplace(str,"\. *$","")
		
		str.=(enclosedSentence=1||previousEnclosedSentence?" ":"") match1
		
		tmp:=""
		loop,parse,match2,`.
		{
			if(a_index=1 && trim(a_loopfield)=""){
				str.=". "
				continue
			}
	
			if regexmatch(substr(tmp,0,1),"\d") && regexmatch(substr(a_loopfield,1,1),"\d"){
				tmp.="." a_loopfield
			}else {
				if (tmp!="")
					str.=(ind=1||previousEnclosedSentence=0?(tmp):capitalize(tmp)) ". "
					,++ind
				tmp:=a_loopfield
			}
		}
		if (tmp!="")
			str.=(ind=1||previousEnclosedSentence=0?(tmp):capitalize(tmp)) (enclosedSentence?". ":"")
		str:=trim(str)
		str:=RegExReplace(str,"\ {2,}"," ")
		
		str.= match3
		
	}
	
	str:=RegExReplace(str,"(?<![\,\;\.])[\,\;\.]([\,\;\.])(?![\,\;\.])","$1")

	str:=RegExReplace(trim(str),"[\,\;] *$",".")
	str:=RegExReplace(str," ([\,\;\.])","$1")
	str:=RegExReplace(str,"(?<![\,\;\.])[\,\;\.]([\,\;\.])(?![\,\;\.])","$1")

	
	
	return str
}

capitalize(s){
	matched:=RegExMatch(s,"\w",match)
	StringUpper,match,match
	if matched=1
		return match substr(s,2)
	else
		return substr(s,1,matched-1) match substr(s,matched+1)
}

;~ text=
;~ (
;~ - Other: probably cyst(s). soft tissue density around sternum, suggest clinical correlation and contrast enhanced study if indicated.
;~ (Low sensitivity and specificity of non-contrast CT.)

;~ (RLL: right lower lobe.)
;~ )

;~ msgbox % parseReport(text)

;~ text=
;~ (

;~ CT of the abdomen and pelvis without/with contrast enhancement shows:
;~ - fatty liver. 
;~ - 
;~ tg//

;~ )
;~ MsgBox % parseImpressionSentences(text)
;~ ExitApp
parseImpressionSentences(ByRef text){
	static regex:="i)([\.;:\-])( +\\? *[^\r\n\.;:]| *\\? *[a-z])([^\r\n\.;:]+)([\.,;: ]*)\\"
	global thisPlace
	
	if InStr(thisPlace, "C hospital"){
		if (i:=RegExMatch(text, "i)(Impression:|\.\.\.) *\r?\n?", m)) 
			imp0:=SubStr(text,i+StrLen(m)) "`n", text:=SubStr(text,1,i-1)
	}
	
	sen:=RegExMatchAll(text, regex)
	ret:=""
	for k,v in sen.list
		ret.=RegExReplace(RegExReplace(StringUpperFirst(Trim(v.2 v.3)) ".`r`n", "\([^\)]+\)", " "), " {2,}", " ")
	text:=RegExReplace(text, "\\", "")
	return imp0 SubStr(ret, 1, -2)
}

;~ msgbox % parseChestCTCommand(text)
/*
1: calcification of aorta 
2: calcification of coronary artery 
3: calcification of cardiac valve
a: implantable venous access port
b: no egenerative change of spine
c: calcified mediastinal lymph nodes
f: fatty liver
e: bilateral pleural effusion
ee: right pleural effusion 
eee: left pleural effusion 
t: thyroid nodule 
g: cardiomegaly 
s: gallstone(s) 
h: hypodense lesion(s) in liver, probably cyst(s). 
r: hypodense lesion(s) in kidney(s), probably cyst(s). 
w: bilateral renal stones
ww: right renal stone
www: left renal stone
x: status post cholecystectomy.
*/
parseChestCTCommand(text){
	
	 if !(text~="(?:INDICATION:[\w\W]+?)?TECHNIQUE:[\w\W]+?(COMPARISON:[\w\W]+?)?FINDINGS:") 
		notTemplate:=true
		
		
	matchWhere:=regexmatch(text,"([\w]+)//",match)
	,text:=substr(text,1,matchWhere-1) substr(text,matchWhere+strlen(match))
	
	,ret:=""
	
	,regexmatch(match1, "i)(\d+)c?",ca)
	static caArr:=["aorta","coronary artery","cardiac valve"]
	if(ca1!=""){
		caText:=""
		count:=0
		loop,parse,ca1
			caText.=caArr[a_loopfield+0] ", ",count:=a_index
		
		caText:=substr(caText,1,-2)
		
		if (count>1)
			caText:=RegExReplace(caText,", ([^,]+)$"," and $1")
		
		text:=RegExReplace(text,"i)Heart/great vessel: *","$0 calcifications of the " caText ". ")
		,ret.="calcifications of the " caText ". "
	}
	
	
	if instr(match1,"t")
		text:=RegExReplaceSeq(text,["i)(Neck): *","i)(Other): *"],"$0 thyroid nodule(s). ")
		,ret.="thyroid nodule(s). "
	
	if instr(match1,"c")
		text:=RegExReplace(text,"i)Mediastinum: ([^\r\n]*)small mediastinal lymph nodes.","Mediastinum: $1small calcified mediastinal lymph nodes.")
		,ret.="small calcified mediastinal lymph nodes. "
	
	if instr(match1,"g")
		text:=RegExReplace(text,"i)Heart/great vessel: *","$0 cardiomegaly. ")
		,ret.="cardiomegaly. "
	
	if instr(match1,"b")
		text:=RegExReplace(text,"i)spondylosis with marginal spur formation.","")
	
	if instr(match1,"a")
		text:=RegExReplace(text,"i)Other: *","$0 placement of implantable venous access port. ")
		,ret.="placement of implantable venous access port. "
	
	if instr(match1,"x")
		text:=RegExReplaceSeq(text,["i)(Abdomen): *","i)(Other): *"],"$0 status post cholecystectomy. ")
		,ret.="status post cholecystectomy. "
		
	
	if instr(match1,"s")
		text:=RegExReplaceSeq(text,["i)(Abdomen): *","i)(Other): *"],"$0 gallstone(s). ")
		,ret.="gallstone(s). "
	
	if instr(match1,"f")
		text:=RegExReplaceSeq(text,["i)(Abdomen): *","i)(Other): *"],"$0 fatty liver. ")
		,ret.="fatty liver. "
	
	static laterality:=["bilateral", "right", "left"]
	if RegExMatch(match1, "e+", ef) {
		text:=RegExReplace(text, "i)(Pleura: *)(no pleural effusion\.)?", "$1" laterality[StrLen(ef)] " pleural effusion. ")
		,ret.= laterality[StrLen(ef)] " pleural effusion. "
	}
	if RegExMatch(match1, "w+", rs) {
		text:=RegExReplaceSeq(text,["i)(Abdomen): *","i)(Other): *"], "$0" laterality[StrLen(rs)] " renal stone" (StrLen(rs)=3?"s":"(s)") ". ")
		,ret.=laterality[StrLen(rs)] " renal stone" (StrLen(rs)=3?"s":"(s)") ". "
	}
	
	h:=r:=0
	,RegExReplace(match1, "i)h", "", h)
	,RegExReplace(match1, "i)r", "", r)
	
	if(h=2 && r=2)
		text:=RegExReplaceSeq(text,["i)(Abdomen): *","i)(Other): *"],"$0 hypodense lesions in liver and kidneys, suggest ultrasound correlation. ")
		,ret.="hypodense lesions in liver and kidneys, suggest ultrasound correlation. "
	else if (h=1 && r=1)
			text:=RegExReplaceSeq(text,["i)(Abdomen): *","i)(Other): *"],"$0 hypodense lesions in liver and kidneys, cysts are favored. ")
			,ret.="hypodense lesions in liver and kidneys, cysts are favored. "
	else {
		if(h>0)
			text:=RegExReplaceSeq(text,["i)(Abdomen): *","i)(Other): *"],"$0 hypodense lesion(s) in liver, " (h=1?"probably cyst(s). ":"suggest ultrasound correlation. "))
			,ret.="hypodense lesion(s) in liver, " (h=1?"probably cyst(s). ":"suggest ultrasound correlation. ")
		if (r>0)
			text:=RegExReplaceSeq(text,["i)(Abdomen): *","i)(Other): *"],"$0 hypodense lesion(s) in kidney(s), " (r=1?"probably cyst(s). ":"suggest ultrasound correlation. "))
			,ret.="hypodense lesion(s) in kidney(s), " (r=1?"probably cyst(s). ":"suggest ultrasound correlation. ")
	}
		
	RegExReplace(match1, "i)(- Lung\/airway: \r?\n  -- )(\r?\n)", "$1Minor or non-specific lung parenchymal change. $2")
	
	
	return !notTemplate?text:(RegExReplace(Trim(text), "\r?\n-?\s*$", "") "`r`n- " ret)
}


colorKeywords(RegEx, byref Font, byref RE){
	text:=RE.getText(), sel:=RE.getSel()
	,i:=0, match:="0", count:=0
	while i:=regexmatch(text, RegEx, match, i+strlen(match)) {
		RE.setSel(i-1, i+strlen(match)-1)
		RE.setFont(Font)
		++count
	}
	RE.setSel(-1, -1)
}


;color: color monitor or not
;reset: reset background
;whitebackground: white background style in color monitor
colorRadReport(RE, color=1, reset=1, whiteBackground=1){
	
	if(reset){
		if(color=1){
			RE.SetBkgndColor(whiteBackground?"white":"black")
			,RE.SetDefaultFont({Color: whiteBackground?"Black":"White"})
		}else {
			RE.SetBkgndColor("black")
			,RE.SetDefaultFont({Color: "Silver"})
		}
	}
	colorKeywords("i)\b(right|left|bilateral)\b",{Color: color?(whiteBackground?"navy":"AQUA"):"white", style: "b"},RE)
	,colorKeywords("i)\bpost[- \w]+?changes?\b",{Color: color?(whiteBackground?"purple":"0xff69b4"):"white", style: "b"},RE)
	,colorKeywords("i)\bno(rmal)?\b", {Color: color?0x00cc00:"white", style: "b"}, RE)
	,colorKeywords("i)\b(cysts?|(micro)?calcifications?|mild|minimal|small)\b", {Color: color?0x00cc00:"white", style: "b"}, RE) ;light green
	
	,colorKeywords("i)\b(fractures?|moderate)\b", {Color: color?"0xcccc":"white", style: "b"}, RE)
	,colorKeywords("i)\b(mass(es)?|nodules?|tumors?|lesions?|cancer|malignanc(y|ies)|malignant|neoplasm|metastas[ei]s|mets|severe|large|marked|total)\b", {Color: color?"red":"white", style: "b"}, RE)
	,colorKeywords("i)\b(larger|enlarged|engorged|disten([st]ion|ded)|dilat(ed|ation)|more prominent|thicken(ing|ed)|ruptured?)\b", {Color: color?"red":"white", style: "b"}, RE)

	;sentence
	,colorKeywords("i)\b(clear|intact|subcentimeter|unremarkable|normal|negative|no (definite|obvious|significant)?|non( |-)(specific)?|spondylosis|degenerative|atherosclero(sis|tic)|fibrotic changes?)\b[^\.;\r\n]+[\.;\r\n]", {Color: color?0x00cc00:"white", style: "b"}, RE)
	

	,RE.Deselect()
}

;color: color monitor or not
;reset: reset background
;whitebackground: white background style in color monitor
WB_colorRadReport(ByRef WB, ByRef StyleRange, color=1, reset=1, whiteBackground=1){
	StyleRange.text:=WB.document.body.innerText
	
	if(reset){
		if(color=1){
			WB.document.body.style.backgroundColor := (whiteBackground?"white":"black")
		}else {
			WB.document.body.style.backgroundColor := "black"
		}
	}
	StyleRange.ResetStyles()
	,StyleRange.AddStyleRegex("i)\b(right|left|bilateral)\b", "{color: " (color?(whiteBackground?"navy":"AQUA"):"white") "; font-weight: bold; }", 1)
	,StyleRange.AddStyleRegex("i)\bpost[- \w]+?changes?\b", "{color: " (color?(whiteBackground?"purple":"#ff69b4"):"white") "; font-weight: bold; }", 1)
	,StyleRange.AddStyleRegex("i)\bno(rmal)?\b", "{color: " (color?"#00cc00":"white") "; font-weight: bold; }", 1)
	,StyleRange.AddStyleRegex("i)\b(cysts?|(micro)?calcifications?|mild|minimal|small)\b", "{color: " (color?"#00cc00":"white") "; font-weight: bold; }", 1) ;light green
	
	,StyleRange.AddStyleRegex("i)\b(fractures?|moderate)\b", "{color: " (color?"#00cccc":"white") "; font-weight: bold; }", 1)
	,StyleRange.AddStyleRegex("i)\b(mass(es)?|nodules?|tumors?|lesions?|cancer|malignanc(y|ies)|malignant|neoplasm|metastas[ei]s|mets|severe|large|marked|total)\b", "{color: " (color?"red":"white") "; font-weight: bold; }", 1)
	,StyleRange.AddStyleRegex("i)\b(larger|enlarged|engorged|disten([st]ion|ded)|dilat(ed|ation)|more prominent|thicken(ing|ed)|ruptured?)\b", "{color: " (color?"red":"white") "; font-weight: bold; }", 1)

	;sentence
	,StyleRange.AddStyleRegex("i)\b(clear|intact|subcentimeter|unremarkable|normal|negative|no (definite|obvious|significant)?|non( |-)(specific)?|spondylosis|degenerative|atherosclero(sis|tic)|fibrotic changes?)\b[^\.;\r\n]+[\.;\r\n]", "{color: " (color?"#00cc00":"white") "; font-weight: bold; }", 1)
	
	,StyleRange.ApplyToHTML(WB)
}

SCI_ColorRadReport(ByRef sci, ByRef StyleRange, color=1, whiteBackground=0){
	;~ Critical
	
	if !(len:=sci.GetLength()) {
		StyleRange.reset()
		return 
	}else{
		;~ sci.GetText(len+4,text:="")
		text:=SCI_GetText(sci)
		,StyleRange.reset()
		,StyleRange.text:=text
	}
	StyleRange.initSci(sci)
	;~ StyleRange.ResetStyles()
	;~ if(!color){
		StyleRange.AddStyleRegex("i)\b(right|left|bilateral)\b", (color?(whiteBackground?"navy":"AQUA"):(whiteBackground?"black":"white")))
		,StyleRange.AddStyleRegex("i)\bpost[- \w]+?changes?\b", (color?(whiteBackground?"purple":"#ff69b4"):(whiteBackground?"black":"white")))
		,StyleRange.AddStyleRegex("i)\bno(rmal)?\b", (color?"#00cc00":(whiteBackground?"black":"white")) )
		,StyleRange.AddStyleRegex("i)\b(cysts?|(micro)?calcifications?|mild|minimal|small)\b", (color?"#00cc00":(whiteBackground?"black":"white")) ) ;light green
		
		,StyleRange.AddStyleRegex("i)\b(fractures?|moderate)\b", (color?"#00cccc":(whiteBackground?"black":"white")) )
		,StyleRange.AddStyleRegex("i)\b(mass(es)?|nodules?|tumors?|lesions?|cancer|malignanc(y|ies)|malignant|neoplasm|metastas[ei]s|filling defects?|mets|severe|large|marked|total)\b", (color?"red":(whiteBackground?"black":"white")))
		,StyleRange.AddStyleRegex("i)\b(larger|enlarged|engorged|disten([st]ion|ded)|dilat(ed|ation)|more prominent|thicken(ing|ed)|ruptured?)\b",  (color?"red":(whiteBackground?"black":"white")) )
		,StyleRange.AddStyleRegex("i)【[^】\r\n]+】",  (whiteBackground?"black":"white"))

		;sentence
		,StyleRange.AddStyleRegex("i)\b(clear|intact|subcentimeter|unremarkable|normal|negative|no (definite|obvious|significant)?|non( |-)(specific)?|spondylosis|degenerative|atherosclero(sis|tic)|fibrotic changes?)\b[^\.;\r\n]*[\.;\r\n]?", (color?"#00cc00":(whiteBackground?"black":"white")))
	;~ }
	
    StyleRange.ApplyToSCI(sci)
	

}

class StyleRange 
{
    __New(Text){
        this.TextLen:=StrLen(Text)
        this.ResetStyles()
        this.__Text:=Text
		this.Lock:=false
    }
	
	
    Text {
		
        get {
            return this.__Text
        }
        set {
			if(value="")
				return this.reset()
            if((newLen:=StrLen(value)) > this.TextLen )
                this.AddStyle(this.TextLen, newLen)
            else if (newLen< this.TextLen)
                for k,v in this.styles
                    this.exclude(this.styles, v, newLen, this.TextLen)
            this.TextLen:=newLen
            return this.__Text:=value
        }
        
    
    }
	
	
	reset(){
		this.__Text:=""
		,this.TextLen:=0
		,this.ResetStyles()
	}
    
	diffStyles(){
		newStyles:={}
		for style,Ranges in this.Styles {
			newStyles[style]:=[]
			,contRanges:=[]
			,rangeCount:=Ranges.maxIndex()
			,rangeCount_p:=(pRanges:=this.priorStyles[style]).maxIndex()
			,i:=0, j:=k:=1
			while (i<=this.TextLen){
				isInclude:=false
				while(j<=rangeCount){
					if this.isBetween(i,Ranges[j]){
						isInclude:=true
						break
					}else if (Ranges[j].1>i){
						break
					}else{
						j++
					}
				}
				if(!isInclude){
					i++
					continue
				}
				
				
				isNew:=true
				while(k<=rangeCount_p){
					if this.isBetween(i, pRanges[k]){
						isNew:=false
						break
					}else if (pRanges[k].1>i){
						break
					}else{
						k++
					}
				}
				if(isNew)
					contRanges.push(i)
				
				i++
			}
			
			start:="", pV:="", finishRange:=true
			for k,v in contRanges {
				if (k=1)
					start:=v
				else if(pV!="" && (v-pV)>1){
					if(start!=pV)
						newStyles[style].push([start, pV])
					start:=v, finishRange:=true
				}else{
					finishRange:=false
				}
				pV:=v
			}
			if(!finishRange){
				if(start!="" && start!=pV)
					newStyles[style].push([start, pV])
			}
			
		}
		this.priorStyles:=this.Styles.clone()
		return newStyles
	}
	
	isBetween(n,ByRef range){
		return (n>=range.1 && n<=range.2)
	}
	
	initSci(sci){
		if(!sci.user_defined_style){
			sci.style_dict:={}
			, FontSize:=sci.StyleGetSize(STYLE_DEFAULT)-1
			,bg:=sci.StyleGetBack(STYLE_DEFAULT)
			,font:=(new remotescintilla(sci.hwnd)).StyleGetFont(STYLE_DEFAULT)
			for k,v in sci.user_defined_styles:= {"navy":0x800000, "AQUA":0xffff00, "white":0xffffff, "purple":0x800080, "#00cc00":0x00cc00, "#ff69b4": 0xb469ff, "red":0x0000ff} ; scintilla use B/G/R
				sci.StyleSetFore(A_Index, v)
				, sci.StyleSetBold(A_Index, true)
				, sci.StyleSetSize(A_Index, FontSize)
				, sci.StyleSetFont(A_Index, tmp:=font)
				, sci.StyleSetBack(A_Index, bg), sci.style_dict[k]:=A_Index
			
		}
		this.sci:=sci
		
	}
	
    ApplyToSCI(ByRef sci){
		
		
        ;~ for style,Ranges in this.styles {
		;~ clipboard:=""
        ;~ for style,Ranges in this.diffStyles() {
        for style,Ranges in this.Styles {
            SciStyle:= sci.style_dict[style]
			,SciStyle:=SciStyle?SciStyle:STYLE_DEFAULT
            for k,v in Ranges 
                if(v.1!=v.2){
					sci.StartStyling(v.1, 0x1f)
					, sci.SetStyling(v.2-v.1, SciStyle)
					;~ Loop % v.2-v.1 {
						;~ i:=A_Index+v.1-1
						;~ ,j:=sci.GetStyleAt(i)
						;~ clipboard.=i "," j "`n"
						;~ if(j!=SciStyle)
							;~ sci.StartStyling(i, 0x1f)
							;~ , sci.SetStyling(1, SciStyle)
					;~ }
					
                    
				}
					;~ , clipboard.=v.1 "-" v.2 " " SubStr(ControlGetText(sci),v.1, v.2-v.1+1) ": " SciStyle ", " style "`n"
        }
    }
	
	ApplyToHTML(ByRef WB){
		if Trim(text:=WB.document.body.innerText)=""
			return
		sortedStyles:=[],css:="",offset:=0
        for style,Ranges in this.Styles {
			i:=A_Index
			for ind, range in Ranges
				sortedStyles[range[1]]:={ind: i, style: style, Range: range}
		}
		;~ style:=WB.document.createElement("style")
		;~ ,style.setAttribute("type", "text/css")
		;~ ,WB.document.getElementsByTagName("head")[0].appendChild(style)
		
		for start,styleInfo in sortedStyles {
			if (s:=styleInfo.range[1]+offset)=(e:=styleInfo.range[2]+offset)
				continue
			if !InStr(css, ".style" styleInfo.ind)
				css.=".style" styleInfo.ind " " styleInfo.style "`n"
				,WB.document.styleSheets[0].addRule(".style" styleInfo.ind, RegExReplace(styleInfo.style,"[\{\}]",""), -1)
			text:=SubStr(text,1,s) (str1:="<span class=""style" styleInfo.ind """>") SubStr(text,s+1,e-s) (str2:="</span>") SubStr(text,e+1)
			,offset+=StrLen(str1)+StrLen(str2)
        }
		WB.document.body.innerHTML:=RegExReplace(text, "\r?\n", "<br/>")
		;~ WB.document.getElementById("text").innerHTML:= RegExReplace(text, "\r?\n", "`r`n")
		;~ ,WB.document.getElementsByTagName("head")[0].innerHTML.="<style type=""text/css"">" css "</style>"
		;~ ,clipboard:=wb.document.documentElement.innerHTML
    }
    
    ResetStyles(){
        this.Styles:={Default:[[0, this.TextLen:=StrLen(this.__Text)]]}
		,this.priorStyles:={}
    }
    
    AddStyleRegex(RegEx, style="Default", multiByteAsOneChar=0){
        if IsObject(RegEx){
            for k,v in RegEx
                this.AddStyleRegex(v, style)
            return 
        }
        i:=0,match:="0",matchLen:=1
        while i:=RegExMatch(this.__Text, RegEx, match, i+matchLen) { 
			if(!multiByteAsOneChar){
				Offset1:=MultiByteChars(SubStr(this.__Text,1,i-1)), Offset2:=MultiByteChars(SubStr(this.__Text,i,matchLen:=StrLen(match))), this.AddStyle(Offset1,Offset1+Offset2, style), (matchLen:=StrLen(match))
			}else{
				this.AddStyle(i-1,(matchLen:=StrLen(match))+i-1, style)
			}
			
            ;~ this.AddStyle(i-1,(matchLen:=StrLen(match))+i-1, style)
		}
    }

    AddStyle(start,End,style="Default"){
		if(start<0 && End<0) || (start=End)
			return
        if !this.styles.haskey(style)
            this.Styles[style]:=[[0,0]]
        for k,v in this.Styles {
            if(k=style)
                this.include(this.Styles, k,start,End)
            else
                this.exclude(this.Styles, k,start,End)
        }
		
		;~ SciStyle:= this.sci.style_dict[style]
		;~ ,SciStyle:=SciStyle?SciStyle:STYLE_DEFAULT
		;~ Loop % End-start {
			;~ i:=start+A_Index-1
			;~ j:=this.sci.GetStyleAt(i)
			;~ if(this.sci.GetStyleAt(i)!=SciStyle)
				;~ this.sci.StartStyling(i, 0x1f)
				;~ ,this.sci.SetStyling(1, SciStyle)
		;~ }
		
    }
    
	include(ByRef styles, style, start, End){
		if(start=End)
			return 
		
		arr:=styles[style].clone()
		ret:=[], added:=false, lastAdded:=0
		for k,range in arr {
			if(added || start > range.2){
				lastAdded:=k
				,ret.push(range)
			}else if !(End>range.2){
				added:=true
				,newStart:=start<(lastStart:=arr[lastAdded+1].1)?start:lastStart
				,lastAdded:=k
				if(End>=range.1)
					ret.push([newStart ,range.2])
				else
					ret.push([newStart ,End])
					,ret.push(range)
			}else{
			}
		}
		if !(added){
			if(lastAdded=arr.maxIndex())
				ret.push([start, End])
			else
				newStart:=start<(lastStart:=arr[lastAdded+1].1)?start:lastStart
				,ret.push([newStart, End])
		}
		styles[style]:=ret.clone()
	}
	
	exclude(ByRef styles, style, start, End){
		if(start=End)
			return 
		
		arr:=styles[style].clone()
		ret:=[], added:=false, lastAdded:=0
		for k,range in arr {
			if(added || start >= range.2){
				lastAdded:=k
				,ret.push(range)
			}else if (End<range.2){
				if(start>(lastStart:=arr[lastAdded+1].1))
					ret.push([lastStart, start])
				added:=true
				,lastAdded:=k
				,ret.push([End>range.1?End:range.1 ,range.2])
			}else{
			}
		}
		if !(added) && !(lastAdded=arr.maxIndex()) {
			if(start>(lastStart:=arr[lastAdded+1].1))
				ret.push([lastStart, start])
		}
		styles[style]:=ret.clone()
	}
	
    includeOld(ByRef styles, style, start, End){
        arr:=[],added:=0,Count:=styles[style].maxIndex()

        for k,v in styles[style] {
            if (continue){
                --continue
                continue
            }
			;~ ToolTip % arr.maxIndex()
            if(added || start>v.2){
                arr.push(v)
				
                continue
            }
            if(End<v.1){
                if(!added){
                    added:=1
                    ,arr.push([start, End])
                }
                arr.push(v)
                continue
            }
            
            
            
            added:=1
            if(End<=v.2){
                arr.push([start>v.1?v.1:start, End<v.2?v.2:End])
                continue
            }
            farEnd:="",continue:=0
            Loop % Count-k {
                if(End>=(after:=styles[style,A_Index+k]).1)
                    farEnd:=after.2,++continue
                else 
                    break
            }
            arr.push([start>v.1?v.1:start, farEnd=""?End:farEnd])
        }
        
        if !added
            arr.push([start,End])
        
		if arr.maxIndex()
			styles[style]:=arr.clone()
        
    }
    
    excludeOld(ByRef styles, style, start, End){
        arr:=[],added:=0,Count:=styles[style].maxIndex()

        for k,v in styles[style] {
            if (continue){
                --continue
                continue
            }
			;~ ToolTip % arr.maxIndex()
            if(added || start>=v.2){
                arr.push(v)
                continue
            }
            if(End<=v.1){
                if(!added){
                    added:=1
                    ;~ ,arr.push([start, End])
                }
                arr.push(v)
                continue
            }
            
            
            
            added:=1
      
            if(start>v.1)
                arr.push([v.1, start])
            if(End<v.2){
                arr.push([End, v.2])
                continue
            }
            continue:=0
            Loop % Count-k {
                if(End>(after:=styles[style,A_Index+k]).1){
                    ++continue
                    if(End<after.2){
                        arr.push([End, after.2])
                        break
                    }
                }else 
                    break
            }
            
        }
        
        ;~ if !added
            ;~ arr.push([start,End])
        

		styles[style]:=arr.maxIndex()?arr.clone():[[0,0]]        
    }
	
	SetTimer( Function, Period=0, ParmObject=0, Priority=0 ) { 
    Static tmrs:=[] ; will hold timers that are currently running
    If IsFunc( Function ) {
      if IsObject(tmr:=tmrs[this]) ;destroy timer before creating a new one
        ret := DllCall( "KillTimer", "UInt",0, "UInt", tmr.tmr)
        , DllCall("GlobalFree", "UInt", tmr.CBA)
        , ObjRemove(tmrs,this)
      if (Period = 0 || Period = "off")
        return ret ;Return as we want to turn off timer
      ; create object that will hold information for timer, it will be passed trough A_EventInfo when Timer is launched
      tmr:=tmrs[this]:={func:Function,ref:this,Period:Period="on" ? 250 : Period,Priority:Priority
                        ,OneTime:Period<0,params:IsObject(ParmObject)?ParmObject:[],Tick:A_TickCount}
      ,tmr.CBA := RegisterCallback(this.base.SetTimer,"F",4,&tmr)
      return !!(tmr.tmr  := DllCall("SetTimer", "UInt",0, "UInt",0, "UInt"
            , (Period && Period!="On") ? Abs(Period) : (Period := 250)
            , "UInt",tmr.CBA)) ;Create Timer and return true if a timer was created
            , tmr.Tick:=A_TickCount
   }
  if IsObject(tmr := Object(A_EventInfo)) { ;A_Event holds object which contains timer information
    DllCall("KillTimer", "UInt",0, "UInt",tmr.tmr) ;deactivate timer so it does not run again while we are processing the function
    ,tmr.tick:= ErrorLevel := A_TickCount ;update tick to launch function on time
    ,func:=tmr.func,%func%(tmr.ref,tmr.params*) ; call function
    if (tmr.OneTime) ;One time timer, deactivate and delete it
      return DllCall("GlobalFree", "UInt",tmr.CBA)
            ,ObjRemove(tmrs,tmr.ref?tmr.ref:tmr.func)
   tmr.tmr := DllCall("SetTimer", "UInt",0, "UInt",0, "UInt" ;reset timer
            ,((A_TickCount-tmr.Tick) > tmr.Period) ? 0 : (tmr.Period-(A_TickCount-tmr.Tick)), "UInt",tmr.CBA)
  }
  }
}