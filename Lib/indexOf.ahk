; ==============================================================================
; Library: indexOf.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

Array(items*)
{
	items.base := ArrayEx
	return items
}

class ArrayEx
{
	IsArray[]
	{
		get {
			return true
		}
	}

	IndexOf(item, case_sensitive:=false)
	{
		for i, val in this {
			if (case_sensitive ? (val == item) : (val = item))
				return i
		}
	}
}