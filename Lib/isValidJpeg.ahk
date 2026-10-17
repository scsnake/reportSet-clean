; ==============================================================================
; Library: isValidJpeg.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

IsValidJPEG( JPEG ) {
 FileGetSize, Size, %JPEG%
 IfLessOrEqual, Size, 1, Return False
 FileRead, Bin, *c %JPEG%
Return ( NumGet( Bin, Size-2, "UShort" ) = 0xD9FF ) ? True : False
}