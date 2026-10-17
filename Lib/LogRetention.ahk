; ==============================================================================
; Library: LogRetention.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

; LogRetention.ahk -- conservative retention helpers for script-owned diagnostics.
; Callers must pass a dedicated directory plus a file or directory name pattern.

LogRetention_DeleteFilesOlderThan(dir, filePattern := "*", daysToKeep := 7) {
    if !FileExist(dir)
        return
    daysToKeep := Abs(daysToKeep)
    if (daysToKeep < 1)
        daysToKeep := 7
    cutoff := A_Now
    EnvAdd, cutoff, % -daysToKeep, Days
    Loop, Files, % dir "\" filePattern, F
    {
        if (A_LoopFileTimeModified < cutoff)
            FileDelete, % A_LoopFileFullPath
    }
}

LogRetention_DeleteDirectoriesOlderThan(dir, namePattern, daysToKeep := 7) {
    if !FileExist(dir)
        return
    daysToKeep := Abs(daysToKeep)
    if (daysToKeep < 1)
        daysToKeep := 7
    cutoff := A_Now
    EnvAdd, cutoff, % -daysToKeep, Days
    Loop, Files, % dir "\*", D
    {
        if !RegExMatch(A_LoopFileName, namePattern)
            continue
        if (A_LoopFileTimeModified < cutoff)
            FileRemoveDir, % A_LoopFileFullPath, 1
    }
}
