ParseStagingText(txt, path_prefix){
	Loop,parse,txt,`n`r
	{
		if RegExMatch(A_LoopField, "i)AJCC[^\r\ncp]{0,10}(c|p)?[^\r\n]{0,10}T[^\r\n\d\w]{0,10}([\/\d\w-]+)[^\r\n\d\w]{0,10}N[^\r\n\d\w]{0,10}([\/\d\w-]+)[^\r\n\d\w]{0,10}M[^\r\n\d\w]{0,10}([\/\d\w-]+)[^\r\n\d\w]{0,10}(?:[^\r\n\d\w]{0,10}Stage[^\r\n\d\w]{0,10}([\/\d\w-]+))?", m)
			if !InStr(m, "TioNIfMultipleS")
				path_prefix.="_" m1 "T" m2 "N" m3 "M" m4 "S" m5
	}
	FileAppend,,% path_prefix,utf-8-Raw
}