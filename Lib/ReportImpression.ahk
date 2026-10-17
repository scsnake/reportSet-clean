class ReportImpression {
	__New(exam="", impression=""){
		this.exam:=""
		,this.impression:=""
		,this.Parse_text(exam, impression)
	}
	
	Parse_text(txt="", impression=""){
		if i:=RegExMatch(txt, "i)(Impression:|IMP:) *\n?", m){
			this.exam:=this.cleanup(i=1?"":SubStr(txt,1,i-1))
			, this.impression:=this.cleanup(SubStr(txt,i+StrLen(m)))
		}else
			this.exam:=this.cleanup(txt)
			,this.impression:=this.cleanup(impression)
	}
	
	cleanup(txt){
		txt:=RegExReplace(txt, "^[\r\n\t ]*", "")
		txt:=RegExReplace(txt, "[\r\n\t ]*$", "")
		txt:=RegExReplace(txt, "\r\n", "`n")
		txt:=RegExReplace(txt, "\r", "")
		return txt
	}
	
	Add_Impression(txt){
		txt:=this.cleanup(txt)
		this.impression.="`n" txt
		this.impression:=this.cleanup(this.impression)
		this.check_duplicate_impression()
	}
	
	check_duplicate_impression(){
		ret:=""
		dic:=[]
		imp:=this.impression
		Loop,parse,imp,`n,`r
		{
			s:=RegExReplace(Trim(A_LoopField), " {2,}", " ")
			if !(dic.haskey(s)) && (s!="")
				ret.=s "`n", dic[s]:=1
		}
		this.impression:=Trim(ret)
	}
	
	combine(){
		ret:=this.exam
		this.check_duplicate_impression()
		if (this.impression!="")
			ret.="`n`nImpression:`n" this.impression
		return ret
	}
	
	win_linebreaks(txt){
		return RegExReplace(txt, "(?<!\r)\n", "`r`n")
	}
	
	is_equal(obj_or_exam, impression=""){
		if IsObject(obj:=obj_or_exam) { ;; compare objects
			return this.cleanup(this.exam)==this.cleanup(obj.exam) && this.cleanup(this.impression)==this.cleanup(obj.impression)
		}else{ 
			obj:=new ReportImpression(obj_or_exam, impression)
			return this.cleanup(this.exam)==this.cleanup(obj.exam) && this.cleanup(this.impression)=this.cleanup(obj.impression)
		}
	}
	
	set_text(exam_edit, impression_edit=0, exam_only=false){
		if !impression_edit
			Edit_SetText(exam_edit, this.win_linebreaks(exam_only?this.exam:this.combine()))
		else
			this.check_duplicate_impression()
			,Edit_SetText(exam_edit, this.win_linebreaks(this.exam))
			,Edit_SetText(impression_edit, this.win_linebreaks(this.impression))
	}
}
