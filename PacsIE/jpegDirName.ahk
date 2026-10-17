jpegDirName(reportdir, accno, chartNo, oldAccNo="", oldChartNo="", ind="1", ext=".jpeg"){
	global ____, __is_CH
	
	if(__is_CH){
		if (ext=".jpeg")
			ext:=".dcm"
	}
	
	if fileexist(reportdir "\" accNo " " chartNo)
		return reportdir "\" accNo " " chartNo (oldAccNo=""?""
			: ( "\" oldAccNo " " oldChartNo " " ind ext))
	else
		return reportdir "\" __CryptStr(accNo " " chartNo,____) (oldAccNo=""?""
			: "\" __CryptStr(oldAccNo " " oldChartNo,____) " " ind ext (InStr(ext, "_")?"":"_"))
	
	;~ if (____!=""){
		;~ accNo_chartno:=__CryptStr(accNo " " chartNo,____)
		;~ ,index:=SubStr(chartNo,1,1) SubStr(accNo,-1)
		;~ if FileExist(p1:=reportdir "\" accNo_chartno (oldAccNo=""?""
			;~ : "\" accNo_chartno " " ind ext))
			;~ || FileExist(p1:=reportdir "\" accNo_chartno (oldAccNo=""?""
			;~ : "\" accNo_chartno " " ind ext))
	;~ }
}