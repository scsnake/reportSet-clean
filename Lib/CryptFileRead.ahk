#include <Crypt>

;~ CryptFilePW()

;~ clipboard:=Crypt.Encrypt.StrEncrypt("abcde123454", ____,7,6)
;~ ExitApp
CryptFilePW(){
	global ____
	f:="\____"
	if FileExist(p:=A_ScriptDir f)
		|| FileExist(p:=A_ScriptDir "\.." f)
		|| FileExist(p:=A_ScriptDir "\..\.." f)
		|| FileExist(p:=A_MyDocuments "\reportSet" f)
		|| FileExist(p:=SubStr(A_ScriptDir,1,2) f) {
			fileread,____,% p
			;~ ____:=Crypt.Hash.StrHash(t,6)
			;~ ToolTip % ____
	}else{
		MsgBox % "Cannot find file for CryptFilePW!"
		return 1
	}
}

CryptFileRead(path,Password, output_str=false){
	return CryptFileReadLines(path,Password, output_str)
}
CryptFileReadLines(path,Password, output_str=false){
	fileread,f,% path
	if (output_str){
		ret:=""
		Loop,Parse,f,`n,`r
			ret.= Crypt.Encrypt.StrDecrypt(A_LoopField,Password,7,6) "`r`n"
	}else{
		ret:=[]
		Loop,Parse,f,`n,`r
			ret.push(Crypt.Encrypt.StrDecrypt(A_LoopField,Password,7,6))
	}
	
	return ret
}

CryptFileAppend(line, path, Password, encoding="utf-8", linebreak="`r`n"){
	line:=RegExReplace(line, "\r?\n$", "")
	FileAppend,% Crypt.Encrypt.StrEncrypt(line,Password,7,6) linebreak,% path,% encoding
}