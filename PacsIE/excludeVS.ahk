excludeVS(str){
	static excludeListRE:=["蔡醫師|TYD"]
	
	for k,v in excludeListRE
		if (str~="i)" v)
			return true
	
	return false
}