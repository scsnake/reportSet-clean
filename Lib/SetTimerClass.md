# SetTimerClass (AHK v1)

An instance owns one cached bound callback for each method name.

```ahk
this.SetTimer("RefreshInfo", 500)         ; repeating callback
this.SetTimer("getStudyHx", -100, [false, which]) ; one shot with arguments
this.SetTimer("RefreshInfo", "Off")       ; pause, keeping callback and period
this.SetTimer("RefreshInfo", "On")        ; resume
this.SetTimer("RefreshInfo", "Delete")    ; stop and remove cached callback
this.DisposeTimers()                     ; stop all and remove callback cache
```

Calling `Off` or `Delete` for an unknown method creates no callback. Repeated
two-argument scheduling of the same method reuses the callback. Supplying a
parameter array for a numeric schedule replaces the previous timer and binds the
new arguments; an empty array clears previous arguments. Control operations keep
the current arguments. The scheduling operation returns true on success and false
after displaying a timer error, preserving the helper's existing error display.

Completed one-shot callbacks remain cached so existing self-rescheduling methods
and pause/resume behavior continue to work. Dispose an instance when its workflow
finishes or before replacing it. `DisposeTimers()` is idempotent and the instance
may schedule new timers afterwards.

Bound callbacks retain their owner; the cache also creates a circular reference.
The owner's own `__Delete()` cannot initiate disposal while these references exist.
Call disposal from a close/completion/replacement path, or from an outer owner
which is not itself retained by the child's callbacks. `activePacs.__Delete()`
uses the latter approach for its owned INFINITT viewer.

Validation: run `tools/Test_SetTimerClass.ahk` with the project's AHK v1 executable,
and run `tools/Test_TimerOwners.ps1` and `tools/Test_LungCADNavigation.ps1`.
Only test fixtures execute; production entry points should be checked with
`AutoHotkey.exe /iLib NUL /ErrorStdOut script.ahk` to avoid launching live automation.
