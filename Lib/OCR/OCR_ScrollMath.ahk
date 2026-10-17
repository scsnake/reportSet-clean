; Pure navigation calculations; also exercised without a PACS window.
OCR_PlanCircularTicks(mode, current, target, step, directionMult, knownTotal := "") {
    if (step <= 0)
        return {ticks: 0, sign: 1, wrapped: false, stackTicks: 0, directTicks: 0}
    signedDirect := Round((target - current) / step)
    directTicks := Abs(signedDirect)
    sign := (signedDirect * directionMult >= 0) ? 1 : -1
    ; SP alone supplies no stack length. Never invent one from chest coverage.
    ; Image wrap requires an observed total and valid indices in that stack.
    total := (mode = "Img" && knownTotal > 1 && current >= 1 && target >= 1
        && current <= knownTotal && target <= knownTotal) ? Round(knownTotal) : 0
    if (total && total - directTicks < directTicks)
        return {ticks: total - directTicks, sign: -sign, wrapped: true, stackTicks: total, directTicks: directTicks}
    return {ticks: directTicks, sign: sign, wrapped: false, stackTicks: total, directTicks: directTicks}
}

OCR_MovedOppositeShortPath(mode, beforeVal, afterVal, step, directionMult, sign, knownTotal := "", sentTicks := 1) {
    rawSteps := (afterVal - beforeVal) / step
    alongExpected := rawSteps * directionMult * sign
    if (alongExpected >= -0.5)
        return false
    if (mode = "Img" && knownTotal > 1 && Abs(rawSteps) > knownTotal / 2)
        return false
    ; Only an adjacent, bounded key/wheel move can disprove its direction.
    ; A large jump can be wraparound or bad OCR, not a reason to flip it.
    return Abs(rawSteps) <= sentTicks + 0.5
}

OCR_TargetReached(mode, current, target, step) {
    if (current = "" || target = "" || step <= 0)
        return false
    return Abs(current - target) < ((mode = "Img") ? 0.5 : Max(0.011, step * 0.45))
}

OCR_RefineBatchTicks(ticks, maxTicks, reliable := false) {
    ; Verify the first small batch, then cover distance with fewer OCR reads.
    return Min(ticks, reliable ? Max(maxTicks, Min(48, Floor(ticks * 0.8))) : maxTicks)
}

OCR_MeasuredDragRatio(dragInfo, beforeVal, afterVal, step, directionMult, sign) {
    if (!IsObject(dragInfo) || step <= 0 || dragInfo.viewportH <= 0 || dragInfo.pxPerTick <= 0)
        return ""
    if (dragInfo.HasKey("pathVerified") && !dragInfo.pathVerified)
        return ""
    actualTicks := (afterVal - beforeVal) / step * directionMult * sign
    ; Ignore no movement, reversed motion, partial OCR, and boundary jumps.
    travel := dragInfo.HasKey("actualDy") ? Abs(dragInfo.actualDy) : Abs(dragInfo.dy)
    effectiveTicks := travel / dragInfo.pxPerTick
    if (travel < 2 || Abs(actualTicks - Round(actualTicks)) > 0.1)
        return ""
    if (actualTicks < 3 || actualTicks < effectiveTicks * 0.25 || actualTicks > effectiveTicks * 3)
        return ""
    ; Plausibility comes from observed travel and response, not a universal
    ; viewport-height ratio ceiling. The logged 0.545 response is valid.
    return travel * 100.0 / (actualTicks * dragInfo.viewportH)
}

OCR_DragRequestTicks(remaining, calibrated, leaveTicks := 3) {
    ticks := Max(1, remaining - Max(2, leaveTicks))
    return calibrated ? ticks : Min(24, ticks)
}

OCR_DragMoveSteps(distance, stepPx := 12) {
    ; Do not cap the step count: long drags must retain the same event spacing.
    return Max(4, Ceil(Abs(distance) / Max(3, stepPx)))
}

OCR_ViewportDragCalibration(key, ratio := "", invalidate := false) {
    static entries := {}
    if (invalidate) {
        entries.Delete(key)
        return ""
    }
    if (ratio != "" && ratio > 0) {
        ; Bound memory across studies/controls; expired records cannot train a run.
        for oldKey, value in entries {
            if (A_TickCount - value.tick >= 120000)
                entries.Delete(oldKey)
        }
        entries[key] := {ratio: ratio, tick: A_TickCount}
        return ratio
    }
    if (entries.HasKey(key) && A_TickCount - entries[key].tick < 120000)
        return entries[key].ratio
    return ""
}

OCR_PlanDragPath(vx, vy, vw, vh, dy) {
    if (vw <= 0 || vh <= 0 || Abs(dy) < 2)
        return false
    ; Stay away from overlays and edges. An upward drag starts near the bottom
    ; so it has the same available travel as a downward drag starting near the top.
    top := vy + Round(vh * 0.2)
    bottom := vy + Round(vh * 0.8)
    travel := Min(Abs(dy), bottom - top)
    if (travel < 2)
        return false
    sx := vx + Round(vw * 0.5)
    sy := (dy < 0) ? bottom : top
    dy := (dy < 0) ? -travel : travel
    return {sx: sx, sy: sy, ex: sx, ey: sy + dy, dy: dy}
}
