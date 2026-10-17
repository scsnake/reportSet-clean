; ==============================================================================
; Library: Crypt_AES.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

Crypt_AES(pData, nSize, sPassword, SID = 256, bEncrypt = True)
{
	CALG_AES_256 := 1 + CALG_AES_192 := 1 + CALG_AES_128 := 0x660E
	CALG_SHA1 := 1 + CALG_MD5 := 0x8003
	DllCall("advapi32\CryptAcquireContextA", "UintP", hProv, "Uint", 0, "Uint", 0, "Uint", 24, "Uint", 0xF0000000)
	DllCall("advapi32\CryptCreateHash", "Uint", hProv, "Uint", CALG_SHA1, "Uint", 0, "Uint", 0, "UintP", hHash)
	DllCall("advapi32\CryptHashData", "Uint", hHash, "Uint", &sPassword, "Uint", StrLen(sPassword), "Uint", 0)
	DllCall("advapi32\CryptDeriveKey", "Uint", hProv, "Uint", CALG_AES_%SID%, "Uint", hHash, "Uint", SID<<16, "UintP", hKey)
	DllCall("advapi32\CryptDestroyHash", "Uint", hHash)
	If	bEncrypt
		DllCall("advapi32\CryptEncrypt", "Uint", hKey, "Uint", 0, "Uint", True, "Uint", 0, "Uint", pData, "UintP", nSize, "Uint", nSize+16)
	Else	DllCall("advapi32\CryptDecrypt", "Uint", hKey, "Uint", 0, "Uint", True, "Uint", 0, "Uint", pData, "UintP", nSize)
	DllCall("advapi32\CryptDestroyKey", "Uint", hKey)
	DllCall("advapi32\CryptReleaseContext", "Uint", hProv, "Uint", 0)
	Return	nSize
}

;~ Crypt_AES(pData, nSize, sPassword, SID = 256, bEncrypt = True)
;~ {
   ;~ CALG_AES_256 := 1 + CALG_AES_192 := 1 + CALG_AES_128 := 0x660E
   ;~ CALG_SHA1 := 1 + CALG_MD5 := 0x8003
   ;~ DllCall("advapi32\CryptAcquireContext", "UPtr*", hProv, "UPtr", 0, "UPtr", 0, "UPtr", 24, "UPtr", 0xF0000000)
   ;~ DllCall("advapi32\CryptCreateHash", "UPtr", hProv, "UPtr", CALG_SHA1, "UPtr", 0, "UPtr", 0, "UPtr*", hHash)
   ;~ DllCall("advapi32\CryptHashData", "UPtr", hHash
   ;~ , "UPtr", &sPassword
   ;~ , "UPtr", (A_IsUnicode ? StrLen(sPassword)*2 : StrLen(sPassword)), "UPtr", 0)
   ;~ DllCall("advapi32\CryptDeriveKey", "UPtr", hProv, "UPtr", CALG_AES_%SID%, "UPtr", hHash, "UPtr", SID<<16, "UPtr*", hKey)
   ;~ DllCall("advapi32\CryptDestroyHash", "UPtr", hHash)
   ;~ bEncrypt
   ;~ ? DllCall("advapi32\CryptEncrypt", "UPtr", hKey, "UPtr", 0, "UPtr", True, "UPtr", 0
    ;~ , (A_PtrSize = 8 ? "UInt64" : "UInt"), pData, (A_PtrSize = 8 ? "UInt64P" : "UIntP"), nSize, "UPtr", nSize+16)
   ;~ : DllCall("advapi32\CryptDecrypt", "UPtr", hKey, "UPtr", 0, "UPtr", True, "UPtr", 0
    ;~ , (A_PtrSize = 8 ? "UInt64" : "UInt"), pData, (A_PtrSize = 8 ? "UInt64P" : "UIntP"), nSize)
   ;~ DllCall("advapi32\CryptDestroyKey", "UPtr", hKey)
   ;~ DllCall("advapi32\CryptReleaseContext", "UPtr", hProv, "UPtr", 0)
   ;~ Return   nSize
;~ }