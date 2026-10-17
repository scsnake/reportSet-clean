; ==============================================================================
; Library: FormatSeconds.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

FormatSeconds(NumberOfSeconds)  ; Convert the specified number of seconds to hh:mm:ss format.

{

    time = 19990101  ; *Midnight* of an arbitrary date.

    time += %NumberOfSeconds%, seconds

    FormatTime, mmss, %time%, mm:ss

    return Format("{:02}", NumberOfSeconds//3600) ":" mmss  ; This method is used to support more than 24 hours worth of sections.

}