; ==============================================================================
; Library: SearchImage.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

;~ SetBatchLines,-1
;~ #include <RisImpax>
;~ monitors:=monitorInfo()
;~ mon:=monitors[2]
;~ t:=A_TickCount
;~ Loop 100 {
	;~ mon:=monitors[2]
;~ SearchImage(mon.l,mon.t,mon.r,mon.b, "D:\Users\raduser\Documents\reportSet\square2.png", "*10")
;~ mon:=monitors[3]
;~ SearchImage(mon.l,mon.t,mon.r,mon.b, "D:\Users\raduser\Documents\reportSet\square2.png", "*10")

;~ }
;~ MsgBox % A_TickCount-t
;~ ExitApp

SearchImage(x1,y1,x2,y2, image, options=""){
	static image_info:=[]
	
	if !(image_info.haskey(image))
		image_info[image]:= liwh := GetDetailsOf(image)
	else
		liwh:=image_info[image]
	liw := liwh[1]
	,lih := liwh[2]
	,ret:=[]
	
	if(x2-x1+1<liw) || (y2-y1+1<lih)
		return ret
	
	ImageSearch, ix, iy, x1, y1, x2, y2, % options " " image
	if (!ErrorLevel && ix!="" && iy!=""){
		ret.push([ix,iy])
		,ret2:= (x2-ix+1>=2*liw)?SearchImage(ix+liw,iy, x2, iy+lih-1, image, options):[]
		,ret3:= (y2-iy+1>=2*lih)?SearchImage(x1,iy+lih,x2,y2, image, options):[]
	}
	for k,v in ret2
		ret.push(v)
	for k,v in ret3
		ret.push(v)
	return ret
}




GetDetailsOf(ByRef _file, _arr="")
{
	_enum := {}
	
	SplitPath, _file, lName, lDir
	
	if !lDir
		lDir := A_ScriptDir
	
	oDir  := ComObjCreate("Shell.Application").NameSpace(lDir)
	,oFile := oDir.ParseName(lName)

	;~ ,RegExMatch(details:= oDir.GetDetailsOf(oFile, -1), "Oi)Dimensions: ‪(\d+) x (\d+)", match)
	Loop, 512
		if (detail := oDir.GetDetailsOf(oFile, A_Index)) && RegExMatch(detail, "i)‪(\d+) x (\d+)", match)
			break
		;~ Clipboard:=exploreobj(_enum)
	return [match1, match2]

}