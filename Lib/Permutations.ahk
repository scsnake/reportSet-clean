; ==============================================================================
; Library: Permutations.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

;-------------------------------------------------------------------------------
Permutations(Word) { ; return an unsorted array with all permutations of Word
;-------------------------------------------------------------------------------
    If (Len := StrLen(Word)) = 1
        Return, [Word]

    Result := []
    Loop, %Len% {

        Split1 := SubStr(Word, 1, A_Index - 1)      ; before pos
        ,Split2 := SubStr(Word, A_Index, 1)          ; at pos
        ,Split3 := SubStr(Word, A_Index + 1)         ; after pos

        For each, Perm in Permutations(Split1 Split3)
            Result.Push(Split2 Perm)
    }

    Return, Result
}
