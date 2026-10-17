#NoEnv
#SingleInstance, Off
#Include %A_LineFile%\..\..\Lib\SetTimerClass.ahk
SetBatchLines, -1
Thread, Interrupt, 0
; The startup thread has an initial grace period before timer interruption.
Sleep, 150
checks:=ticks:=freed:=0

obj:=new TimerFixture()
obj.SetTimer("Tick", "Off")
obj.SetTimer("OtherTick", "Delete")
Assert(obj.__setTimerBindFn.Count()=0, "stopping unknown timers creates no callback")
obj.SetTimer("Tick", 10)
first:=obj.__setTimerBindFn.Tick
obj.SetTimer("Tick", 10)
Assert(first=obj.__setTimerBindFn.Tick, "same instance reuses timer identity")
first:=""
Sleep, 60
Assert(ticks>0, "repeating timer fires")
obj.SetTimer("Tick", "Off")
paused:=ticks
Sleep, 60
Assert(ticks=paused && IsObject(obj.__setTimerBindFn.Tick), "Off pauses and preserves callback")
obj.SetTimer("Tick", "On")
Sleep, 60
Assert(ticks>paused, "On resumes paused timer")
obj.SetTimer("Tick", "Delete")
deleted:=ticks
Sleep, 60
Assert(ticks=deleted && !obj.__setTimerBindFn.HasKey("Tick"), "Delete stops and removes callback")
obj:=""
Assert(freed=1, "Delete releases circular reference")

obj:=new TimerFixture()
obj.SetTimer("Tick", 10)
obj.SetTimer("OtherTick", -10)
Sleep, 60
obj.DisposeTimers()
disposed:=ticks
Sleep, 60
Assert(ticks=disposed && !obj.HasKey("__setTimerBindFn"), "dispose clears repeating and completed one-shot callbacks")
obj.DisposeTimers()
Assert(!obj.HasKey("__setTimerBindFn"), "dispose is idempotent")
obj.SetTimer("Tick", -10)
Sleep, 60
Assert(ticks=disposed+1, "disposed instance can schedule again")
obj.DisposeTimers()
obj:=""
Assert(freed=2, "dispose allows owner destruction")

obj:=new TimerFixture()
obj.rearms:=0
obj.SetTimer("Rearm", -10)
Sleep, 160
Assert(obj.rearms=3, "one-shot callback can reschedule itself")
obj.DisposeTimers()
obj:=""

obj:=new TimerFixture()
obj.SetTimer("DisposeInside", -10)
Sleep, 60
Assert(!obj.HasKey("__setTimerBindFn"), "callback can dispose its own timers")
obj:=""

obj:=new TimerFixture()
obj.SetTimer("Tick", "Delete")
Assert(!A_IsCritical, "timer operation restores interruptibility")
Critical, 27
obj.SetTimer("Tick", -10)
Assert(A_IsCritical=27, "timer operation preserves caller critical interval")
obj.DisposeTimers()
Assert(A_IsCritical=27, "disposal preserves caller critical interval")
Critical, Off
obj:=""

firstOwner:=new TimerFixture()
secondOwner:=new TimerFixture()
firstOwner.SetTimer("Tick", 1000)
secondOwner.SetTimer("Tick", 1000)
Assert(firstOwner.__setTimerBindFn.Tick!=secondOwner.__setTimerBindFn.Tick, "instances have distinct callbacks")
firstOwner.DisposeTimers()
Assert(IsObject(secondOwner.__setTimerBindFn.Tick), "disposing one owner preserves another")
secondOwner.DisposeTimers()
firstOwner:=secondOwner:=""

obj:=new TimerFixture()
obj.SetTimer("Record", -10, [false, 3])
Sleep, 60
Assert(obj.recordCount=1 && obj.recordA=0 && obj.recordB=3, "callback receives explicit arguments including false (count=" obj.recordCount ", a=" obj.recordA ", b=" obj.recordB ")")
obj.SetTimer("Record", 10, ["old", 2])
obj.SetTimer("Record", -10, ["latest", 4])
Sleep, 60
Assert(obj.recordCount=2 && obj.recordA="latest" && obj.recordB=4, "updated parameters replace the old timer")
obj.SetTimer("Record", 10)
Sleep, 60
obj.SetTimer("Record", "Off")
recordPaused:=obj.recordCount
Sleep, 60
Assert(obj.recordCount=recordPaused, "parameterized callback pauses")
obj.SetTimer("Record", "On")
Sleep, 60
obj.SetTimer("Record", "Off")
Assert(obj.recordCount>recordPaused && obj.recordA="latest" && obj.recordB=4, "resume retains bound arguments")
obj.SetTimer("ArgsRearm", -10, [1])
Sleep, 160
Assert(obj.argsRearms=3 && obj.lastRearmArg=3, "callback can rearm itself with changed arguments")
obj.SetTimer("Record", -10, [])
Sleep, 60
Assert(obj.recordA="default" && obj.recordB=0, "empty argument array clears previous arguments")
obj.DisposeTimers()
obj:=""

FileAppend,% "PASS: " checks " SetTimerClass checks`n",*
ExitApp, 0

class TimerFixture extends SetTimerClass {
    Tick(){
        global ticks
        ticks++
    }
    OtherTick(){
        global ticks
        ticks++
    }
    Rearm(){
        if (++this.rearms<3)
            this.SetTimer("Rearm", -10)
    }
    DisposeInside(){
        this.DisposeTimers()
    }
    Record(a:="default", b:=0){
        this.recordCount:=(this.recordCount="" ? 0 : this.recordCount)+1
        this.recordA:=a
        this.recordB:=b
    }
    ArgsRearm(value){
        this.argsRearms:=(this.argsRearms="" ? 0 : this.argsRearms)+1
        this.lastRearmArg:=value
        if (value<3)
            this.SetTimer("ArgsRearm", -10, [value+1])
    }
    __Delete(){
        global freed
        freed++
    }
}
Assert(condition, description){
    global checks
    checks++
    if !condition {
        FileAppend,% "FAIL: " description "`n",**
        ExitApp, 1
    }
}
