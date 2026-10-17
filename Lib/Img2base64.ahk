; ==============================================================================
; Library: Img2base64.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

Img2base64(ImgFile, withPrefix=false){
	   ; -------------------------------------------------------------------------------------------------------------------
   File := FileOpen(ImgFile, "r")
   BinLen := File.Length
   File.RawRead(Bin, BinLen)
   File.Close()
   ; -------------------------------------------------------------------------------------------------------------------
   ; Encode the image file
   ; -------------------------------------------------------------------------------------------------------------------
   DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", &Bin, "UInt", BinLen, "UInt", 0x01, "Ptr", 0, "UIntP", B64Len)
   VarSetCapacity(B64, B64Len << !!A_IsUnicode, 0)
   DllCall("Crypt32.dll\CryptBinaryToString", "Ptr", &Bin, "UInt", BinLen, "UInt", 0x01, "Ptr", &B64, "UIntP", B64Len)
   Bin := ""
   VarSetCapacity(Bin, 0)
   VarSetCapacity(B64, -1)
	B64 := RegExReplace(B64, "\r\n")
	if withPrefix
		B64:="data:image/png;base64," B64
	return B64
}


;~ clipboard:=Img2base64("G:\scripts\Radiology\urgentReport\images\sort_asc.png")