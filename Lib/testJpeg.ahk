; ==============================================================================
; Library: testJpeg.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

testJpeg(jpegFile, needDecryptPw){
	static testGuiHwnd, testGuiAddPicFirst:=true, testGuiPicVar
	if !WinExist("ahk_id " testGuiHwnd){
		gui,__testJpegGui:new,+hwndtestGuiHwnd
		testGuiAddPicFirst:=true
	}
	decryptedFile:="", catch_error:=false
	try{
		
		if(needDecryptPw!=""){
			decryptedFile:=jpegFile ".trydec"
			, Crypt.Encrypt.FileDecrypt(jpegFile, decryptedFile,needDecryptPw,7,6)
			, picFile:=decryptedFile
		}else
			picFile:=jpegFile
		
		if !FileExist(picFile)
			throw Exception("")
		
		if(testGuiAddPicFirst){
			gui,%testGuiHwnd%:Add,Picture,vtestGuiPicVar,% picFile
			testGuiAddPicFirst:=false
		}else{
			guicontrol,%testGuiHwnd%:,testGuiPicVar,% picFile
		}
		;~ if ErrorLevel
			;~ throw Exception("")
	}catch{
		catch_error:=true
	}
	
	if(decryptedFile!="")
		FileDelete,% decryptedFile
	
	return catch_error
	
}
