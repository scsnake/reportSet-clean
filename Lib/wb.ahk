; ==============================================================================
; Library: wb.ahk
; Classification: Pure Third-Party
; Original Author: Jethrow (WBGet helper)
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/board/topic/47052-basic-ahk-v11-classes-progress/page-4#entry420800
; ==============================================================================

#(byref pwb,id){
	return pwb.document.getElementById(id)
}
$(byref dom,id){
	return dom.getElementById(id)
}

execJS(byref pwb, byref js){
	e:=pwb.document.createElement("script")
	,e.text:=js
	
	try
		if !(p:=pwb.document.head)
			throw Exception("")
	catch
	try
		if !(p:=pwb.document.documentElement)
			throw Exception("")
	catch
	try
		p:=pwb.document.body
	
	if p
		p.appendChild(e)
}

wbWaitElement(ByRef wb, element_id_or_filter, timeout=3000){
	;
	
	if !IsObject(element_id_or_filter)
		filter_id:=element_id_or_filter
	else if (element_id_or_filter.haskey(1))
		filter:={Type: element_id_or_filter[1], NAme: element_id_or_filter[2]}
		, use_filter:=true
	
	Loop {
		if A_Index>300
			return 1
		if !(wb.busy){
			if(filter_id !=""){
				try {
					_:=wb.document.getElementById(filter_id)
					return 0
				}
			}else if (use_filter) {
				if ((Type:=filter.Type)!="")
					Loop % (ele:=wb.document.getElementsByTagName(Type)).length {
						e:=ele[A_Index]
						if matchAttr(e, filter)
							return 0
					}
				
			}
		}
			
		Sleep 10
	}
}

matchAttr(ByRef element, filter){
	for k,v in filter {
		try
			_v:=element.getAttribute(k)
		catch
			return false
		if (_v!=v)
			return false
	}
	return true
}