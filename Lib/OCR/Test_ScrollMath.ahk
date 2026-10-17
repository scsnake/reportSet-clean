#NoEnv
#SingleInstance, Off
SetBatchLines, -1
#Include %A_LineFile%\..\OCR_ScrollMath.ahk

checks := 0
; September 16: 242 slices were incorrectly shortened to an eight-slice wrap.
p := OCR_PlanCircularTicks("SP", -362.5, -60, 1.25, 1)
Assert(p.ticks = 242 && p.sign = 1 && !p.wrapped, "SP must not guess a 250-slice stack")
p := OCR_PlanCircularTicks("SP", -362.5, -60, 1.25, -1)
Assert(p.ticks = 242 && p.sign = -1, "reversed acquisition direction")
p := OCR_PlanCircularTicks("Img", 290, 5, 1, 1, 300)
Assert(p.ticks = 15 && p.sign = 1 && p.wrapped, "known image total permits wrap")
p := OCR_PlanCircularTicks("Img", 290, 5, 1, 1)
Assert(p.ticks = 285 && p.sign = -1 && !p.wrapped, "missing total must use direct path")
p := OCR_PlanCircularTicks("Img", 290, 5, 1, 1, 250)
Assert(p.ticks = 285 && !p.wrapped, "invalid total rejected")

Assert(!OCR_MovedOppositeShortPath("SP", -12.5, -375, 1.25, 1, 1), "boundary jump must not flip direction")
Assert(OCR_MovedOppositeShortPath("SP", -100, -110, 1.25, 1, 1, "", 8), "bounded opposite keys correct direction")
Assert(!OCR_MovedOppositeShortPath("Img", 298, 6, 1, 1, 1, 300, 8), "observed image wrap retains direction")
Assert(!OCR_TargetReached("SP", "", 0, 1.25), "blank OCR is not zero")
Assert(OCR_TargetReached("SP", 0, 0, 1.25), "zero is a valid location")
Assert(!OCR_TargetReached("SP", -310, -311.25, 1.25), "adjacent slice is not success")

; Logged drag requested 70 ticks, travelled 267px, and moved 110 slices.
d := {dy: 267, pxPerTick: 3.818319, viewportH: 1339}
ratio := OCR_MeasuredDragRatio(d, -222.5, -360, 1.25, 1, -1)
Assert(Abs(ratio - 26700 / (110 * 1339)) < 0.000001, "learn full observed drag response")
d := {dy: 100, pxPerTick: 2, viewportH: 1000, requestedTicks: 200}
ratio := OCR_MeasuredDragRatio(d, 0, 50, 1, 1, 1)
Assert(Abs(ratio - 0.2) < 0.000001, "clipped drag learns actual pixels, not requested ticks")
Assert(OCR_MeasuredDragRatio(d, 0, -50, 1, 1, 1) = "", "reverse drag is not key calibration")
Assert(OCR_MeasuredDragRatio(d, 0, 0, 1, 1, 1) = "", "no-motion drag cannot train")
Assert(OCR_MeasuredDragRatio(d, 0, 500, 1, 1, 1) = "", "implausible drag cannot train")

; First Win+I on September 16: both upward drags were clipped to 258px.
p := OCR_PlanDragPath(1920, -328, 1229, 1339, -696)
Assert(p.dy = -696 && p.sy = 743 && p.ey = 47, "long first upward drag retains full travel")
p := OCR_PlanDragPath(1920, -328, 1229, 1339, 696)
Assert(p.dy = 696 && p.sy = -60 && p.ey = 636, "downward drag has equal travel")
for _, dy in [-2000, -696, -20, 20, 696, 2000] {
    p := OCR_PlanDragPath(1920, -328, 1229, 1339, dy)
    Assert(p.sy >= -60 && p.sy <= 743 && p.ey >= -60 && p.ey <= 743, "negative-origin drag stays in image interior")
    Assert(p.sx = p.ex && p.dy * dy > 0 && Abs(p.dy) <= Abs(dy), "clipping preserves direction and vertical path")
}
Assert(!OCR_PlanDragPath(0, 0, 0, 100, 30), "invalid viewport cannot drag")
Assert(!OCR_PlanDragPath(0, 0, 100, 100, 1), "subpixel-scale drag rejected")

; Local-login regression: the 803px/110-slice response must not disable drag.
d := {dy: -803, actualDy: -803, pxPerTick: 4.436375, viewportH: 1339, pathVerified: true}
ratio := OCR_MeasuredDragRatio(d, -353.75, -216.25, 1.25, 1, 1)
Assert(Abs(ratio - 0.5451829724) < 0.000001, "accept observed local response above old ceiling")
d.pathVerified := false
Assert(OCR_MeasuredDragRatio(d, -353.75, -216.25, 1.25, 1, 1) = "", "bad cursor path cannot calibrate")
Assert(OCR_DragMoveSteps(803, 12) = 67, "long drag retains twelve-pixel increments")
Assert(OCR_DragMoveSteps(331, 12) = 28, "short drag uses same event spacing")
Assert(OCR_DragRequestTicks(256, false) = 24, "unknown local control starts with short probe")
Assert(OCR_DragRequestTicks(146, true) = 143, "measured response continues dragging")
Assert(OCR_DragRequestTicks(10, true) = 7, "reserve few exact keys near target")
Assert(OCR_ViewportDragCalibration("local|viewport1|up") = "", "new viewport is uncalibrated")
OCR_ViewportDragCalibration("local|viewport1|up", 0.54518)
Assert(OCR_ViewportDragCalibration("local|viewport1|up") = 0.54518, "same control reuses calibration")
Assert(OCR_ViewportDragCalibration("local|viewport2|up") = "", "different control cannot inherit calibration")
Assert(OCR_ViewportDragCalibration("local|viewport1|down") = "", "opposite direction calibrates separately")
Assert(OCR_ViewportDragCalibration("RDP|viewport1|up") = "", "RDP cannot inherit local calibration")
OCR_ViewportDragCalibration("local|viewport1|up", "", true)
Assert(OCR_ViewportDragCalibration("local|viewport1|up") = "", "rejected response invalidates calibration")

; Simulate first-jump drag + final keys using the same production planner,
; viewport clipping, and measured calibration. No live window or input is used.
for _, actualRatio in [0.283794, 0.353142, 0.5451829724] {
    for _, remainingStart in [48, 77, 256, 500] {
        for _, sign in [-1, 1] {
            current := -353.75
            target := current + sign * remainingStart * 1.25
            runRatio := ""
            dragCount := 0
            while (Abs(target - current) / 1.25 >= 10 && dragCount < 6) {
                remaining := Round(Abs(target - current) / 1.25)
                request := OCR_DragRequestTicks(remaining, runRatio != "")
                activeRatio := runRatio != "" ? runRatio : 0.33132
                pxPerTick := 1339 * activeRatio / 100
                path := OCR_PlanDragPath(1920, -328, 1229, 1339, -sign * Round(request * pxPerTick))
                actualTicks := Round(Abs(path.dy) / (1339 * actualRatio / 100))
                before := current
                current += sign * actualTicks * 1.25
                info := {dy: path.dy, actualDy: path.dy, pxPerTick: pxPerTick, viewportH: 1339, pathVerified: true}
                runRatio := OCR_MeasuredDragRatio(info, before, current, 1.25, 1, sign)
                Assert(runRatio != "", "valid local drag response remains usable")
                dragCount++
            }
            finishKeys := Round(Abs(target - current) / 1.25)
            Assert(finishKeys <= 9, "far jump finishes with few keys, not a long key train")
            Assert(dragCount <= 6, "far jump keeps bounded drag count")
        }
    }
}

; Simulate exact wheel/key response across distances, intervals and directions.
for _, step in [0.625, 1, 1.25, 2.5, 3, 5] {
    for _, dir in [-1, 1] {
        for _, distance in [-500, -242, -40, -8, -1, 0, 1, 8, 40, 242, 500] {
            current := -375
            target := current + distance * step
            passes := 0
            while (!OCR_TargetReached("SP", current, target, step) && passes < 20) {
                p := OCR_PlanCircularTicks("SP", current, target, step, dir)
                batch := OCR_RefineBatchTicks(p.ticks, 8, passes > 0)
                Assert(batch >= 1 && batch <= p.ticks, "batch must not overshoot target")
                current += dir * p.sign * batch * step
                passes++
            }
            Assert(OCR_TargetReached("SP", current, target, step), "converge with exact input")
            if (Abs(distance) = 242)
                Assert(passes <= 9, "242-slice correction uses fewer reads than 31 fixed batches")
        }
    }
}

FileAppend, % "PASS: " checks " navigation checks`n", *
ExitApp, 0

Assert(condition, description) {
    global checks
    checks++
    if (!condition) {
        FileAppend, % "FAIL: " description "`n", **
        ExitApp, 1
    }
}
