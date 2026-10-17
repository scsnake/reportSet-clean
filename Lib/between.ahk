; ==============================================================================
; Library: between.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

between(v,lh,hl){
  return v>=(lh<hl?lh:hl)&&v<=(hl>lh?hl:lh)
}