; ==============================================================================
; Library: Base64ToFile.ahk
; Classification: Pure Third-Party
; Original Author: SKAN
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/viewtopic.php?t=35964
; ==============================================================================

#include <Base64Dec>

Base64ToFile(base64, filePath){
	if RegExMatch(base64, "i)data:image/(\w+);base64,", extension)
		base64:=SubStr(base64, StrLen(extension)+1)
		,extension:=extension1
	
	SplitPath,filePath,,,ext
	if (ext="" && extension!="")
		filePath.="." extension
	
	nBytes := Base64Dec( base64, Bin )
	File := FileOpen(filePath, "w")	
	,File.RawWrite(Bin, nBytes)
	,File.Close()

}

