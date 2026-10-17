#include <RegExSplit>
SetBatchLines,-1

clip:=Clipboard
ret:=""

Loop,Parse,clip,`n
{
	isLungCa:=false
	isLungMet:=false
	Loop,Parse,A_LoopField,|
	{
		t:=RegExReplace(A_LoopField, "^\d+: ", "")
		Loop,Parse,t,;
		{
			;~ thisLineMet:=!!(A_LoopField~="i)metasta")
				
			parts:=RegExSplit(A_LoopField, ", *").split
		
			if(InStr(parts[1], "lung")){
				for k,v in parts
					if (k>1)  && !(Trim(v)~="i)^(no|ne)"){
						if (v~="i)carcino|malignan|cancer")
							isLungCa:=true
						else if (v~="i)metastat")
							isLungMet:=true, isLungCa:=false
						;~ break,3
					}
			}
		}
	}
	ret.=(isLungCa) "`t" isLungMet "`n"
}
clipboard:=ret

