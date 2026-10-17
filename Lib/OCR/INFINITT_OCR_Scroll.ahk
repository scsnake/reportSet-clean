; AHK v1 Script
#Include %A_LineFile%\..\..\INFINITT_PACS.ahk
#Include %A_LineFile%\..\..\IsCurrentSessionRDP.ahk
#Include %A_LineFile%\..\..\LogRetention.ahk
#Include %A_LineFile%\..\OCR_WinRT.ahk
#Include %A_LineFile%\..\OCR_ScrollMath.ahk

OCR_DEBUG_STARTUP_CAPTURE := false
OCR_DEBUG_REGION_VIEW := false
OCR_DEBUG_PREVIEW_CAPTURE := false
OCR_AUTO_NARROW_REGION := false
OCR_RUN_SELF_TEST := false
OCR_FORCE_RDP_REGION := false
OCR_DEBUG_MODE := false
OCR_SAVE_ROI_BITMAPS := OCR_DEBUG_MODE
OCR_ROI_SAVE_DIR := A_ScriptDir "\debug_roi"
OCR_ROI_SAVE_COUNT := 0
OCR_LOG_FILE := ""
OCR_SP_REGION_RATIO := [-0.0016, 0.0000, 0.1110, 0.1318]
OCR_IMG_REGION_RATIO := [0.9094, 0.0569, 0.0890, 0.0360]
OCR_SP_REGION_RATIO_RDP := [0, 0.0936, 0.0955, 0.0565]
OCR_IMG_REGION_RATIO_RDP := [0.9248, 0.0559, 0.0752, 0.0419]
OCR_SP_BOTTOM_READ_HEIGHT := 70
OCR_RUN_T0 := 0
OCR_LOG_LAST_TICK := 0
OCR_USE_ONESHOT_FILE_OCR := true
OCR_DIRECT_SCROLL := true
OCR_SLEEP_CALIBRATE := 40
OCR_SLEEP_CLICK := 10
OCR_SLEEP_BATCH_SETTLE_IMG := 40
OCR_SLEEP_BATCH_SETTLE_SP := 40
OCR_SLEEP_PRECISION_IMG := 40
OCR_SLEEP_PRECISION_SP := 0
OCR_SLEEP_FOCUS_CLICK := 10
OCR_SLEEP_DONE := 0
OCR_IMG_MAX_BATCH := 100
OCR_DIRECT_REFINE_MAX_TICKS_IMG := 20
OCR_DIRECT_REFINE_MAX_TICKS_SP := 8
OCR_COLD_READ_RETRIES := 4
OCR_COLD_READ_SLEEP := 120
OCR_SLEEP_INITIAL_READ := 120
OCR_DRAG_SCROLL_DEFAULT := true
OCR_DRAG_SCROLL_RDP_ENABLE := false
OCR_RDP_DRAG_URL := ""
OCR_DRAG_SCROLL_SP_ENABLE := true
OCR_DRAG_SCROLL_SP_MIN_TICKS := 10
OCR_DRAG_SCROLL_SP_LEAVE_TICKS := 1
OCR_DRAG_SCROLL_MAX_ROUGH_ATTEMPTS := 6
OCR_DRAG_SCROLL_SP_AUTO_LEARN := true
OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100 := 0.11524  ; calibrated: 65 frames / 100px @ vh=1335 (incremental drag)
OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100_RDP := 0.11524
OCR_DRAG_SCROLL_SP_SIGN := 1
OCR_DRAG_SCROLL_SP_CONFIG_FILE := ""
OCR_DRAG_SCROLL_SP_CONFIG_SECTION := "Hotkey"
OCR_DRAG_SCROLL_SP_CONFIG_KEY := "INFINITTOCRDragScrollSPRatioPer100"
OCR_DRAG_SCROLL_SP_CONFIG_KEY_RDP := "INFINITTOCRDragScrollSPRatioPer100RDP"
OCR_SCROLL_INPUT_MODE := "wheel"
OCR_SCROLL_KEY_UP := "Up"
OCR_SCROLL_KEY_DOWN := "Down"
OCR_DRAG_STEP_PX := 12
OCR_DRAG_STEP_SLEEP := 2
OCR_DRAG_ENDPOINT_SLEEP := 3
; The host script's physical-input abort hooks also see some Click commands
; generated here.  Each pointer action sets a brief suppression window so it
; cannot abort its own OCR run.
OCR_IGNORE_MANUAL_ABORT_UNTIL := 0

OCR_WinRT_Init()

if (OCR_DEBUG_STARTUP_CAPTURE)
    OCR_DebugStartupCapture()

if (OCR_RUN_SELF_TEST)
    INFINITT_OCR_Scroll({SP: 60.00})
if (A_LineFile = A_ScriptFullPath)
    return

; INFINITT_OCR_Scroll(target_obj [, region, options])
;   target_obj : {Img: 10}  or  {SP: -71.5}
;   region     : [x, y, w, h] relative to window client — omit for defaults
;   options    : {parentHwnd: hwnd, viewportHwnd: hwnd, mouseX: x, mouseY: y}
;
; Img mode: 1 scroll = exactly 1 frame (integer, cycling)
; SP  mode: 1 scroll = 1 slice step (float, varies: 5/3/1.5/1.25/1.0/0.625×n mm, cycling)

INFINITT_OCR_Scroll(target, region := "", options := "") {
    global OCR_RUN_ACTIVE, OCR_ACTIVE_RUN_ID
    ; A newly selected nodule must wait for the previous run to release input.
    if (OCR_RUN_ACTIVE) {
        INFINITT_OCR_RequestAbort()
        return {ok: false, reason: "busy"}
    }
    try {
        return INFINITT_OCR_ScrollRun(target, region, options)
    } finally {
        if (OCR_RUN_ACTIVE)
            OCR_FinishRun(OCR_ACTIVE_RUN_ID, INFINITT_OCR_IsAbortRequested(OCR_ACTIVE_RUN_ID))
        ToolTip
    }
}

INFINITT_OCR_ScrollRun(target, region := "", options := "") {
    global OCR_DEBUG_REGION_VIEW, OCR_AUTO_NARROW_REGION, OCR_RUN_T0, OCR_LOG_LAST_TICK
    global OCR_SLEEP_CALIBRATE, OCR_SLEEP_CLICK, OCR_SLEEP_BATCH_SETTLE_IMG, OCR_SLEEP_BATCH_SETTLE_SP
    global OCR_SLEEP_PRECISION_IMG, OCR_SLEEP_PRECISION_SP, OCR_SLEEP_FOCUS_CLICK, OCR_SLEEP_DONE, OCR_IMG_MAX_BATCH
    global OCR_DIRECT_REFINE_MAX_TICKS_IMG, OCR_DIRECT_REFINE_MAX_TICKS_SP, OCR_COLD_READ_RETRIES, OCR_COLD_READ_SLEEP, OCR_SLEEP_INITIAL_READ
    global OCR_DIRECT_SCROLL
    global OCR_RUN_ACTIVE, OCR_ABORT_REQUESTED, OCR_RUN_SEQ, OCR_ACTIVE_RUN_ID, OCR_ABORTED_RUNS, OCR_LAST_ABORTED
    global OCR_DRAG_SCROLL_AVAILABLE, OCR_DRAG_SCROLL_DEFAULT, OCR_DRAG_SCROLL_RDP_ENABLE, OCR_RDP_DRAG_URL
    global OCR_DRAG_SCROLL_SP_ENABLE, OCR_DRAG_SCROLL_SP_MIN_TICKS, OCR_DRAG_SCROLL_SP_LEAVE_TICKS
    global OCR_DRAG_SCROLL_MAX_ROUGH_ATTEMPTS
    global OCR_SCROLL_INPUT_MODE
    global OCR_RUN_DEADLINE
    global OCR_DRAG_STEP_PX, OCR_DRAG_STEP_SLEEP, OCR_DRAG_ENDPOINT_SLEEP, OCR_DRAG_SCROLL_SP_SIGN
    static calibrationCache := {}

    INFINITT_OCR_InitDefaults()

    if !IsObject(OCR_ABORTED_RUNS)
        OCR_ABORTED_RUNS := {}
    OCR_RUN_SEQ := (OCR_RUN_SEQ + 0) + 1
    ocrRunId := OCR_RUN_SEQ
    OCR_ACTIVE_RUN_ID := ocrRunId
    OCR_RUN_ACTIVE := true
    OCR_ABORT_REQUESTED := false
    OCR_LAST_ABORTED := false
    OCR_RUN_T0 := A_TickCount
    OCR_RUN_DEADLINE := OCR_RUN_T0 + 15000
    OCR_LOG_LAST_TICK := OCR_RUN_T0

    CoordMode, Mouse, Screen
    if !IsObject(target)
        target := {Img: target}

    regionWasDefault := (region = "")
    if (target.HasKey("Img")) {
        target_val := target.Img
        mode := "Img"
        if (region = "")
            region := OCR_DefaultRegion(mode, 0)
    }
    else if (target.HasKey("SP")) {
        target_val := target.SP
        mode := "SP"
        if (region = "")
            region := OCR_DefaultRegion(mode, 0)
    }

    ; ── Window setup ──────────────────────────────────────────────
    hwnd := (IsObject(options) && options.HasKey("parentHwnd") && WinExist("ahk_id " options.parentHwnd)) ? options.parentHwnd : GetLeftmostINFINITTHwnd()
    if (!hwnd) {
        OCR_LogStep("WINDOW NOT FOUND")
        ToolTip, INFINITT window not found!
        Sleep, 2000
        ToolTip
        OCR_FinishRun(ocrRunId)
        return
    }

    WinGet, hwnd, ID, ahk_id %hwnd%
    captureHwnd := hwnd
    viewportHwnd := (IsObject(options) && options.HasKey("viewportHwnd") && WinExist("ahk_id " options.viewportHwnd)) ? options.viewportHwnd : OCR_GetViewportHwnd(hwnd, mode, region)
    if (viewportHwnd) {
        captureHwnd := viewportHwnd
        if (regionWasDefault) {
            if (IsObject(options) && options.HasKey("viewportHwnd"))
                region := OCR_ViewportRatioRegion(mode, viewportHwnd)
            else
                region := OCR_ControlMarginRegion(mode, hwnd, viewportHwnd, region)
        }
    }

    OCR_LogStep("START | Mode=" mode " | Target=" target_val " | RDPScenario=" OCR_IsRDPScenario() " | CaptureHwnd=" captureHwnd " | ViewportHwnd=" viewportHwnd " | Region=" region[1] "," region[2] "," region[3] "," region[4])

    if (OCR_IsRDPScenario()) {
        OCR_LogStep("ACTIVATE | hwnd=" hwnd)
        WinActivate, ahk_id %hwnd%
        WinWaitActive, ahk_id %hwnd%,, 2
        OCR_LogStep("ACTIVE | hwnd=" hwnd " | ErrorLevel=" ErrorLevel)
    }
    if (mode = "SP")
        region := OCR_SPBottomRegion(region)

    VarSetCapacity(rect, 16)
    DllCall("GetClientRect", "ptr", captureHwnd, "ptr", &rect)
    cW := NumGet(rect, 8, "int"), cH := NumGet(rect, 12, "int")

    VarSetCapacity(pt, 8, 0)
    DllCall("ClientToScreen", "ptr", captureHwnd, "ptr", &pt)
    wx := NumGet(pt, 0, "int"), wy := NumGet(pt, 4, "int")

    ax := wx + region[1], ay := wy + region[2]
    OCR_LogStep("CAPTURE ROOT | hwnd=" captureHwnd " | client=" cW "x" cH " | screenOrigin=" wx "," wy " | roiScreen=" ax "," ay)
    ; Visual ROI frame disabled during interactive scrolling. It can interfere
    ; with PACS focus/mouse responsiveness when launched from the nodule-list GUI.
    ; if (OCR_DEBUG_REGION_VIEW) {
    ;     ToolTip, % "ROI: " ax "," ay " " region[3] "x" region[4]
    ;     ShowOCRRegion(ax, ay, region[3], region[4], 1500)
    ;     ToolTip
    ; }

    OCR_EnsureINFINITTReady(hwnd, viewportHwnd)

    if (IsObject(options) && options.HasKey("mouseX") && options.HasKey("mouseY"))
        mousePt := {x: options.mouseX, y: options.mouseY}
    else
        mousePt := OCR_GetViewportPoint(mode, wx, wy, cW, cH, region)
    mouseX := mousePt.x
    mouseY := mousePt.y
    OCR_LogStep("MOUSE | x=" mouseX " | y=" mouseY " | FocusClick=1")
    OCR_SetCursorPoint(mouseX, mouseY)
    Sleep, 10
    OCR_LogINFINITTDragCursor(viewportHwnd)
    OCR_DRAG_SCROLL_AVAILABLE := ((!IsCurrentSessionRDP() || OCR_DRAG_SCROLL_RDP_ENABLE) && OCR_DRAG_SCROLL_DEFAULT)
    OCR_LogStep("DRAG MODE | Available=" OCR_DRAG_SCROLL_AVAILABLE " | RDP=" IsCurrentSessionRDP() " | RDPEnable=" OCR_DRAG_SCROLL_RDP_ENABLE " | RDPDragUrl=" (Trim("" OCR_RDP_DRAG_URL) != "" ? "SET" : "EMPTY") " | ScrollInput=" OCR_SCROLL_INPUT_MODE)
    OCR_SendPointerClick()
    Sleep, %OCR_SLEEP_FOCUS_CLICK%
    if (INFINITT_OCR_CheckAbort("after focus click", ocrRunId))
        return

    if (OCR_AUTO_NARROW_REGION)
        region := OCR_ResolveReadingRegion(region, hwnd, mode)

    calibrationKey := ""
    if (IsObject(options) && options.HasKey("calibrationKey"))
        calibrationKey := options.calibrationKey
    cacheId := calibrationKey ? (calibrationKey "|" captureHwnd "|" cW "x" cH "|" mode "|" OCR_SCROLL_INPUT_MODE "|" OCR_IsRDPScenario()) : ""
    Sleep, %OCR_SLEEP_INITIAL_READ%

    ; ── Calibration: 1 tick → direction + exact step size ─────────
    ; Img: step is always 1 (definitional), calibrate direction only
    ; SP:  step = actual slice thickness for this series (auto-detected)
    baseline_text := OCR_ReadTextDynamic(region, captureHwnd, mode, cacheId, cW, cH, OCR_COLD_READ_RETRIES, OCR_COLD_READ_SLEEP)
    baseline := ParseOCR(baseline_text, mode)
    imgStackTicks := (mode = "Img") ? ParseOCR_ImgTotal(baseline_text) : ""
    OCR_LogStep("BASELINE | " mode "=" baseline " | Raw=" OCR_OneLine(baseline_text))
    if (baseline = "") {
        OCR_LogStep("BASELINE FAILED | Raw=" OCR_OneLine(baseline_text))
        ToolTip, % "Calibration baseline OCR failed`nOCR: " OCR_TooltipText(baseline_text)
        Sleep, 2000
        ToolTip
        OCR_FinishRun(ocrRunId)
        return {ok: false, reason: "baseline"}
    }
    if (((mode = "Img") && (Abs(baseline - target_val) < 0.5))
        || ((mode = "SP") && (Abs(baseline - target_val) < 0.05))) {
        Sleep, 40
        confirmed := ParseOCR(OCR_ReadText(region, captureHwnd, mode), mode)
        if (confirmed = "" || Abs(confirmed - baseline) > 0.01)
            return {ok: false, reason: "baseline-unstable"}
        if (INFINITT_OCR_CheckAbort("baseline confirmation", ocrRunId))
            return
        OCR_LogStep("DONE | Cur=" baseline " | Target=" target_val " | Raw=" OCR_OneLine(baseline_text) " | AlreadyAtTarget=1")
        ToolTip, % "Done: " baseline " (target: " target_val ")`nOCR: " OCR_TooltipText(baseline_text)
        Sleep, %OCR_SLEEP_DONE%
        ToolTip
        OCR_FinishRun(ocrRunId)
        return {ok: true, current: baseline, target: target_val}
    }
    ToolTip, % "Baseline " mode ": " baseline "`nOCR: " OCR_TooltipText(baseline_text)
    ; Sleep, 300

    spacing := (mode = "SP") ? ParseOCR_SPSpacing(baseline_text) : 1
    ; An accession/viewport can switch between reconstructions with the same SL
    ; but different slice intervals. Re-measure SP; only Img has a fixed step.
    cacheHit := (mode = "Img" && cacheId && calibrationCache.HasKey(cacheId)
        && A_TickCount - calibrationCache[cacheId].tick < 120000
        && (spacing = "" || Abs(spacing - calibrationCache[cacheId].spacing) < 0.001))
    if (cacheHit) {
        cached := calibrationCache[cacheId]
        direction_mult := cached.dir
        if (mode = "Img") {
            step := 1
            stepSource := "cached"
        } else {
            spacing := ParseOCR_SPSpacing(baseline_text)
            step := cached.step
            stepSource := "cached-measured"
        }
        current := baseline
        raw_text := baseline_text
        OCR_LogStep("CALIBRATION CACHE HIT | Key=" cacheId " | Mode=" mode " | Step=" step " | Dir=" direction_mult " | Source=" stepSource)
        ToolTip, % "Cached calibration  step=" step "  dir=" direction_mult "`nCur: " current " → Target: " target_val
    } else {
        OCR_LogStep("CALIBRATION CLICK | WheelUp | Input=" OCR_SCROLL_INPUT_MODE)
        OCR_SendScrollAction("WheelUp", viewportHwnd)
        Sleep, %OCR_SLEEP_CALIBRATE%
        if (INFINITT_OCR_CheckAbort("after calibration wheelup", ocrRunId))
            return
        after1_text := OCR_ReadAfterInput(region, captureHwnd, mode, cacheId, cW, cH, baseline, ocrRunId)
        after1 := ParseOCR(after1_text, mode)
        if (mode = "Img" && imgStackTicks = "")
            imgStackTicks := ParseOCR_ImgTotal(after1_text)
        OCR_LogStep("AFTER WHEELUP | " mode "=" after1 " | Raw=" OCR_OneLine(after1_text))
        ToolTip, % "After WheelUp " mode ": " after1 "`nOCR: " OCR_TooltipText(after1_text)
        ;Sleep, 300

        if (after1 != "" && Abs(after1 - baseline) > 0.001) {
            delta          := after1 - baseline
            direction_mult := (delta > 0) ? 1 : -1   ; +1 → WheelUp raises value
        }
        else {
            ; WheelUp had no effect — try WheelDown
            OCR_SendScrollAction("WheelDown", viewportHwnd)
            Sleep, %OCR_SLEEP_CALIBRATE%
            if (INFINITT_OCR_CheckAbort("after calibration wheeldown", ocrRunId))
                return
            after1_text := OCR_ReadAfterInput(region, captureHwnd, mode, cacheId, cW, cH, baseline, ocrRunId)
            after1 := ParseOCR(after1_text, mode)
            if (mode = "Img" && imgStackTicks = "")
                imgStackTicks := ParseOCR_ImgTotal(after1_text)
            OCR_LogStep("AFTER WHEELDOWN | " mode "=" after1 " | Raw=" OCR_OneLine(after1_text))
            ToolTip, % "After WheelDown " mode ": " after1 "`nOCR: " OCR_TooltipText(after1_text)
            ;Sleep, 300
            if (after1 = "" || Abs(after1 - baseline) < 0.001) {
                OCR_LogStep("CALIBRATION FAILED | Baseline=" baseline " | After=" after1 " | Raw=" OCR_OneLine(after1_text))
                ToolTip, % "Calibration failed — no scroll response`nOCR: " OCR_TooltipText(after1_text)
                Sleep, 2000
                ToolTip
                OCR_FinishRun(ocrRunId)
                return
            }
            delta          := after1 - baseline
            direction_mult := (delta > 0) ? -1 : 1   ; WheelDown raised → WheelUp lowers
        }

        ; A single probe can cross the end of a cycling stack. Probe once more
        ; in that same direction and measure an adjacent pair inside the stack.
        probeSign := (delta * direction_mult > 0) ? 1 : -1
        probeLimit := (mode = "Img") ? 1.5 : ((spacing != "") ? Max(2, spacing * 2.5) : 20)
        if (Abs(delta) > probeLimit) {
            probeStart := after1
            OCR_SendScrollAction(probeSign = 1 ? "WheelUp" : "WheelDown", viewportHwnd)
            Sleep, %OCR_SLEEP_CALIBRATE%
            after1_text := OCR_ReadAfterInput(region, captureHwnd, mode, cacheId, cW, cH, probeStart, ocrRunId)
            after1 := ParseOCR(after1_text, mode)
            if (after1 = "" || Abs(after1 - probeStart) > probeLimit)
                return {ok: false, reason: "calibration"}
            delta := after1 - probeStart
            direction_mult := (delta * probeSign > 0) ? 1 : -1
            OCR_LogStep("CALIBRATION BOUNDARY RECOVERY | Step=" Abs(delta) " | Dir=" direction_mult)
        }

        if (mode = "Img") {
            step := 1   ; exact by definition — no per-series variation
            stepSource := "fixed"
        }
        else {
            spacing := ParseOCR_SPSpacing(baseline_text)
            if (spacing = "")
                spacing := ParseOCR_SPSpacing(after1_text)
            ; SL may be slice thickness, which need not equal the reconstruction
            ; interval. The measured adjacent SP difference is the scroll step.
            step := Abs(delta)
            if (spacing != "" && Abs(step - spacing) <= 0.011)
                step := spacing  ; e.g. 0.625 mm displayed with only two decimals
            stepSource := "scroll-delta"
            OCR_LogStep("SP STEP | Source=" stepSource " | Step=" step " | ScrollDelta=" Abs(delta))
            if (spacing != "" && Abs(delta) > Max(spacing * 2.5, 2.0)) {
                OCR_LogStep("CALIBRATION REJECTED | Reason=implausible-delta | Baseline=" baseline " | After=" after1 " | Step=" step " | Delta=" delta " | Raw=" OCR_OneLine(after1_text))
                ToolTip, % "Calibration rejected — OCR jump too large`nOCR: " OCR_TooltipText(after1_text)
                Sleep, 1200
                ToolTip
                OCR_FinishRun(ocrRunId)
                return
            }
        }

        current := after1
        raw_text := after1_text
        if (cacheId && mode = "Img") {
            calibrationCache[cacheId] := {dir: direction_mult, step: step, spacing: spacing, tick: A_TickCount}
            OCR_LogStep("CALIBRATION CACHE STORE | Key=" cacheId " | Mode=" mode " | Step=" step " | Dir=" direction_mult " | Source=" stepSource)
        }
    }

    if (mode = "SP") {

        ; Snap target to nearest achievable grid point.
        ; SP values live on a discrete grid: origin ± n×step.
        ; A target between grid points cannot be reached; snap to nearest.
        gridOrigin := baseline
        raw_ticks := (target_val - gridOrigin) / step
        snapped := gridOrigin + Round(raw_ticks) * step
        offGrid := Abs(target_val - snapped)
        snapTolerance := Max(0.001, step * 0.02)
        if (offGrid > snapTolerance) {
            OCR_LogStep("SNAP TARGET | Requested=" target_val " | Snapped=" snapped " | Step=" step " | Origin=" gridOrigin " | OffGrid=" offGrid " | Tolerance=" snapTolerance)
            ToolTip, % "Target " target_val " not on slice grid (step=" step ").`nNearest reachable SP: " snapped
            target_val := snapped
        }
    }

    OCR_LogStep("CALIBRATED | Mode=" mode " | Step=" step " | Dir=" direction_mult " | Start=" current " | Target=" target_val)
    ToolTip, % "Calibrated  step=" step "  dir=" direction_mult "`nStart: " current " → Target: " target_val "`nOCR: " OCR_TooltipText(raw_text)
    ;Sleep, 600

    if (OCR_DIRECT_SCROLL) {
        final := current
        dragUsed := false
        untrustedDrags := 0
        ; Geometry, study, input backend, measured interval and direction all
        ; affect response. A different control/direction starts with a short probe.
        dragCacheBase := calibrationKey "|" hwnd "|" viewportHwnd "|" wx "," wy "|" cW "x" cH
            . "|" mode "|" step "|" direction_mult "|" OCR_SCROLL_INPUT_MODE "|" OCR_IsRDPScenario()
            . "|" OCR_DRAG_SCROLL_SP_SIGN "|" OCR_DRAG_STEP_PX "|" OCR_DRAG_STEP_SLEEP "|" OCR_DRAG_ENDPOINT_SLEEP
            . "|" (IsCurrentSessionRDP() && Trim("" OCR_RDP_DRAG_URL) != "" ? "http:" OCR_RDP_DRAG_URL : "SetCursorPos")
        roughAttempts := Max(0, Min(12, OCR_DRAG_SCROLL_MAX_ROUGH_ATTEMPTS + 0))
        Loop, %roughAttempts% {
            if (INFINITT_OCR_CheckAbort("rough plan", ocrRunId))
                return
            plan := OCR_PlanCircularTicks(mode, final, target_val, step, direction_mult, imgStackTicks)
            ticks := plan.ticks, sign := plan.sign
            if !(OCR_DRAG_SCROLL_SP_ENABLE && OCR_DRAG_SCROLL_AVAILABLE && ticks >= Max(10, OCR_DRAG_SCROLL_SP_MIN_TICKS))
                break
            dragCacheKey := dragCacheBase "|" sign
            runDragRatio := OCR_ViewportDragCalibration(dragCacheKey)
            dragTicks := OCR_DragRequestTicks(ticks, runDragRatio != "", Max(3, OCR_DRAG_SCROLL_SP_LEAVE_TICKS))
            OCR_LogStep("DRAG PLAN | Session=" (IsCurrentSessionRDP() ? "RDP" : "local") " | Pass=" A_Index " | Remaining=" ticks " | Request=" dragTicks " | Calibration=" (runDragRatio = "" ? "probe" : "viewport") " | Ratio=" runDragRatio)
            dragStart := final
            dragAttempt := OCR_TryRoughDrag(viewportHwnd, sign, dragTicks, ocrRunId, runDragRatio)
            if (!dragAttempt)
                break
            dragUsed := true
            if (INFINITT_OCR_CheckAbort("drag complete", ocrRunId))
                return
            Sleep, % (mode = "Img") ? OCR_SLEEP_BATCH_SETTLE_IMG : OCR_SLEEP_BATCH_SETTLE_SP
            raw_text := OCR_ReadAfterInput(region, captureHwnd, mode, cacheId, cW, cH, dragStart, ocrRunId)
            final := ParseOCR(raw_text, mode)
            OCR_LogStep("ROUGH DRAG VERIFY | Pass=" A_Index " | Start=" dragStart " | Cur=" final " | Target=" target_val)
            if (final = "")
                return {ok: false, reason: "drag-unverified"}
            measuredRatio := OCR_MeasuredDragRatio(dragAttempt, dragStart, final, step, direction_mult, sign)
            if (measuredRatio = "") {
                OCR_ViewportDragCalibration(dragCacheKey, "", true)
                untrustedDrags++
                OCR_LogStep("DRAG CALIBRATION REJECTED | Reprobe=" untrustedDrags " | Before=" dragStart " | After=" final)
                ; A rejected measurement is not automatically a broken drag.
                ; Retry a short probe if it moved toward the target. Do not learn
                ; from wrong-direction movement or keep repeating bad paths.
                if (untrustedDrags >= 2 || (final - dragStart) * direction_mult * sign <= 0
                    || Abs(target_val - final) >= Abs(target_val - dragStart)
                    || (dragAttempt.HasKey("pathVerified") && !dragAttempt.pathVerified))
                    break
                continue
            }
            untrustedDrags := 0
            OCR_ViewportDragCalibration(dragCacheKey, measuredRatio)
            OCR_LogStep("DRAG VIEWPORT CALIBRATION | viewport=" viewportHwnd " | Sign=" sign " | Ratio=" measuredRatio)
            if (OCR_TargetReached(mode, final, target_val, step))
                break
        }

        reliableBatch := false
        if (dragUsed) {
            ; A drag can leave the image control without keyboard focus. Restore
            ; it before changing input methods, especially on the first long jump.
            OCR_EnsureINFINITTReady(hwnd, viewportHwnd)
            if (INFINITT_OCR_CheckAbort("post-drag focus", ocrRunId))
                return
            ControlFocus,, ahk_id %viewportHwnd%
            OCR_LogStep("POST-DRAG FOCUS | viewport=" viewportHwnd " | ErrorLevel=" ErrorLevel)
        }
        Loop, 20 {
            if (INFINITT_OCR_CheckAbort("refine plan", ocrRunId))
                return
            if (OCR_TargetReached(mode, final, target_val, step))
                break
            plan := OCR_PlanCircularTicks(mode, final, target_val, step, direction_mult, imgStackTicks)
            ticks := plan.ticks, sign := plan.sign
            if (ticks <= 0)
                break
            action := (sign = 1) ? "WheelUp" : "WheelDown"
            maxBatch := (mode = "Img") ? OCR_DIRECT_REFINE_MAX_TICKS_IMG : OCR_DIRECT_REFINE_MAX_TICKS_SP
            batchTicks := OCR_RefineBatchTicks(ticks, Max(1, maxBatch), reliableBatch)
            verifyStart := final
            OCR_LogStep("DIRECT REFINE | Pass=" A_Index " | Cur=" final " | Target=" target_val " | " OCR_ScrollActionText(action, batchTicks))
            ToolTip, % "Locating " mode " " final " -> " target_val
            Loop, %batchTicks% {
                if (INFINITT_OCR_CheckAbort("direct scroll", ocrRunId))
                    return
                OCR_SendScrollAction(action, viewportHwnd)
                Sleep, %OCR_SLEEP_CLICK%
            }
            Sleep, % (mode = "Img") ? OCR_SLEEP_BATCH_SETTLE_IMG : OCR_SLEEP_BATCH_SETTLE_SP
            raw_text := OCR_ReadAfterInput(region, captureHwnd, mode, cacheId, cW, cH, verifyStart, ocrRunId)
            final := ParseOCR(raw_text, mode)
            OCR_LogStep("DIRECT VERIFY | Cur=" final " | Target=" target_val " | Raw=" OCR_OneLine(raw_text))
            ; Never send another batch from an assumed pre-input position.
            if (final = "")
                return {ok: false, reason: "scroll-unverified"}
            if (mode = "Img" && imgStackTicks = "")
                imgStackTicks := ParseOCR_ImgTotal(raw_text)
            directionWrong := OCR_MovedOppositeShortPath(mode, verifyStart, final, step, direction_mult, sign, imgStackTicks, batchTicks)
            reliableBatch := Abs(Abs(final - verifyStart) / step - batchTicks) < 0.25
            if (directionWrong) {
                direction_mult := -direction_mult
                reliableBatch := false
                if (cacheId && calibrationCache.HasKey(cacheId))
                    calibrationCache[cacheId].dir := direction_mult
                OCR_LogStep("DIRECTION CORRECTED FROM KEYS | Dir=" direction_mult)
            }
        }
        if (INFINITT_OCR_CheckAbort("final verification", ocrRunId))
            return
        reached := OCR_TargetReached(mode, final, target_val, step)
        if (reached) {
            Sleep, 40
            confirmed := ParseOCR(OCR_ReadText(region, captureHwnd, mode), mode)
            reached := OCR_TargetReached(mode, confirmed, target_val, step)
            if (!reached)
                return {ok: false, reason: "target-unstable"}
        }
        OCR_LogStep((reached ? "DONE" : "NOT REACHED") " | Cur=" final " | Target=" target_val " | ElapsedMs=" (A_TickCount - OCR_RUN_T0))
        ; Calibration stays scoped to this viewport/direction. Do not overwrite a
        ; global INI ratio with one control's response (or write INI during a jump).
        if (INFINITT_OCR_CheckAbort("completion", ocrRunId))
            return
        ToolTip
        OCR_FinishRun(ocrRunId)
        return {ok: reached, current: final, target: target_val}
    }

    ; Zone thresholds (in steps, same meaning for both modes)
    ; Coarse zone  (>coarse_zone steps away): full-speed batch scrolls
    ; Braking zone (fine_zone < n ≤ coarse_zone): power-law deceleration
    ; Precision    (≤ fine_zone steps):  single tick → immediate re-read
    coarse_zone := (mode = "Img") ? 20 : 10
    fine_zone   := (mode = "Img") ?  4 :  2

    last_val := current
    expected_current := ""

    ; ── Main Loop ─────────────────────────────────────────────────
    Loop, 100 {
        if (INFINITT_OCR_CheckAbort("main loop", ocrRunId))
            return
        raw_text := OCR_ReadTextDynamic(region, captureHwnd, mode, cacheId, cW, cH)
        current  := ParseOCR(raw_text, mode)

        if (current = "") {
            OCR_LogStep("OCR FAILED | Raw=" OCR_OneLine(raw_text))
            ToolTip, % "OCR failed: " OCR_TooltipText(raw_text)
            ;Sleep, 300
            continue
        }

        if (mode = "Img" && expected_current != "") {
            corrected := OCR_CorrectImgPartial(current, expected_current)
            if (corrected != current) {
                OCR_LogStep("IMG OCR CORRECTED | RawCur=" current " | Corrected=" corrected " | Expected=" expected_current " | Raw=" OCR_OneLine(raw_text))
                current := corrected
            }
        }

        ; Cycle-wrap detection.
        ; Both Img and SP stacks cycle at their boundaries.
        ; A large jump in the unexpected direction is a wrap, not an overshoot.
        ; Log it but do NOT penalise — just recalculate from the new position.
        movement := current - last_val
        if (Abs(movement) > 2 * Max(step, 1) && (movement * (target_val - last_val)) < 0)
            OCR_LogStep("CYCLE WRAP | " last_val " → " current)

        last_val := current
        diff     := target_val - current
        diff_abs := Abs(diff)

        ; Convergence:
        ;   Img — integer frames, half-frame tolerance catches OCR noise
        ;   SP  — within 45% of one step = already at the nearest achievable slice
        if (mode = "Img")
            is_match := (diff_abs < 0.5)
        else
            is_match := (diff_abs < step * 0.45)

        if (is_match) {
            OCR_LogStep("DONE | Cur=" current " | Target=" target_val " | Raw=" OCR_OneLine(raw_text))
            ToolTip, % "Done: " current " (target: " target_val ")`nOCR: " OCR_TooltipText(raw_text)
            Sleep, %OCR_SLEEP_DONE%
            ToolTip
            OCR_FinishRun(ocrRunId)
            return
        }

        ; Convert remaining distance to integer step count.
        ; SP: Round() snaps to the grid — if result is 0, we are already
        ;     at the closest reachable slice even though diff ≠ 0.
        if (mode = "Img")
            steps_away := Round(diff_abs)
        else {
            steps_away := Round(diff_abs / step)
            if (steps_away = 0) {
                OCR_LogStep("NEAREST SLICE | Cur=" current " | Target=" target_val " | Raw=" OCR_OneLine(raw_text))
                ToolTip, % "At nearest slice: " current " (target: " target_val ")`nOCR: " OCR_TooltipText(raw_text)
                Sleep, 2000
                ToolTip
                OCR_FinishRun(ocrRunId)
                return
            }
        }

        ; ── Phase selection ───────────────────────────────────────
        if (mode = "Img" && steps_away > 20) {
            ; Img OCR may intermittently miss leading digits at the right edge.
            ; Keep batches small enough that a partial read cannot drive a huge overshoot.
            ticks := Min(OCR_IMG_MAX_BATCH, steps_away)
            phase := "ImgStep"
        }
        else if (steps_away > coarse_zone) {
            ; Phase 1 — Coarse: maximum speed, one OCR read per batch
            ticks := Min(60, steps_away)
            phase := "Coarse"
        }
        else if (steps_away > fine_zone) {
            ; Phase 2 — Brake: power-law deceleration (concave curve,
            ; brakes quickly at zone entry, eases into a crawl near fine_zone)
            ticks := Max(2, Floor(steps_away ** 0.75))
            phase := "Brake"
        }
        else {
            ; Phase 3 — Precision: single tick then immediate re-read;
            ; one-step bracket naturally converges without hill-climb logic
            ticks := 1
            phase := "Precision"
        }

        ; Scroll direction
        sign   := (diff * direction_mult > 0) ? 1 : -1
        action := (sign = 1) ? "WheelUp" : "WheelDown"

        actionText := OCR_ScrollActionText(action, ticks)
        ToolTip, % "[" phase "] " mode "  steps=" steps_away "`nCur: " current " → " target_val "`nOCR: " OCR_TooltipText(raw_text) "`n" actionText
        OCR_LogStep(phase " | Cur=" current " | Target=" target_val " | Steps=" steps_away " | " actionText " | Raw=" OCR_OneLine(raw_text))

        if (mode = "Img")
            expected_current := current + ((action = "WheelUp") ? direction_mult : -direction_mult) * ticks

        if (phase = "Precision") {
			if (INFINITT_OCR_CheckAbort("precision scroll", ocrRunId))
				return
            OCR_SendScrollAction(action, viewportHwnd)
            Sleep, % (mode = "Img") ? OCR_SLEEP_PRECISION_IMG : OCR_SLEEP_PRECISION_SP
        }
        else {
            Loop, %ticks% {
                if (INFINITT_OCR_CheckAbort("batch scroll", ocrRunId))
                    return
                OCR_SendScrollAction(action, viewportHwnd)
                Sleep, %OCR_SLEEP_CLICK%
            }
            Sleep, % (mode = "Img") ? OCR_SLEEP_BATCH_SETTLE_IMG : OCR_SLEEP_BATCH_SETTLE_SP
        }
    }

    OCR_LogStep("MAX ITERATIONS | Last=" current " | Target=" target_val " | Raw=" OCR_OneLine(raw_text))
    ToolTip, % "Max iterations reached. Last=" current "  Target=" target_val "`nOCR: " OCR_TooltipText(raw_text)
    Sleep, 3000
    ToolTip
    OCR_FinishRun(ocrRunId)
}

INFINITT_OCR_InitDefaults() {
    global OCR_DEBUG_STARTUP_CAPTURE, OCR_DEBUG_REGION_VIEW, OCR_DEBUG_PREVIEW_CAPTURE
    global OCR_AUTO_NARROW_REGION, OCR_RUN_SELF_TEST, OCR_FORCE_RDP_REGION, OCR_DEBUG_MODE
    global OCR_SAVE_ROI_BITMAPS, OCR_ROI_SAVE_DIR, OCR_ROI_SAVE_COUNT, OCR_LOG_FILE, OCR_SP_BOTTOM_READ_HEIGHT
    global OCR_SP_REGION_RATIO, OCR_IMG_REGION_RATIO, OCR_SP_REGION_RATIO_RDP, OCR_IMG_REGION_RATIO_RDP
    global OCR_RUN_T0, OCR_LOG_LAST_TICK
    global OCR_USE_ONESHOT_FILE_OCR, OCR_DIRECT_SCROLL
    global OCR_SLEEP_CALIBRATE, OCR_SLEEP_CLICK, OCR_SLEEP_BATCH_SETTLE_IMG, OCR_SLEEP_BATCH_SETTLE_SP
    global OCR_SLEEP_PRECISION_IMG, OCR_SLEEP_PRECISION_SP, OCR_SLEEP_FOCUS_CLICK, OCR_SLEEP_DONE, OCR_IMG_MAX_BATCH
    global OCR_DIRECT_REFINE_MAX_TICKS_IMG, OCR_DIRECT_REFINE_MAX_TICKS_SP, OCR_COLD_READ_RETRIES, OCR_COLD_READ_SLEEP, OCR_SLEEP_INITIAL_READ
    global OCR_DRAG_SCROLL_DEFAULT, OCR_DRAG_SCROLL_AVAILABLE, OCR_DRAG_SCROLL_RDP_ENABLE, OCR_RDP_DRAG_URL
    global OCR_DRAG_SCROLL_SP_ENABLE, OCR_DRAG_SCROLL_SP_MIN_TICKS, OCR_DRAG_SCROLL_SP_LEAVE_TICKS, OCR_DRAG_SCROLL_SP_AUTO_LEARN
    global OCR_DRAG_SCROLL_MAX_ROUGH_ATTEMPTS
    global OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100, OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100_RDP, OCR_DRAG_SCROLL_SP_SIGN
    global OCR_DRAG_SCROLL_SP_CONFIG_FILE, OCR_DRAG_SCROLL_SP_CONFIG_SECTION, OCR_DRAG_SCROLL_SP_CONFIG_KEY, OCR_DRAG_SCROLL_SP_CONFIG_KEY_RDP
    global OCR_SCROLL_INPUT_MODE, OCR_SCROLL_KEY_UP, OCR_SCROLL_KEY_DOWN
    global OCR_DRAG_STEP_PX, OCR_DRAG_STEP_SLEEP, OCR_DRAG_ENDPOINT_SLEEP
    static initialized := false

    if (initialized)
        return

    SplitPath, A_LineFile,, ocrDir

    if (OCR_DEBUG_STARTUP_CAPTURE="")
        OCR_DEBUG_STARTUP_CAPTURE := false
    if (OCR_DEBUG_REGION_VIEW="")
        OCR_DEBUG_REGION_VIEW := false
    if (OCR_DEBUG_PREVIEW_CAPTURE="")
        OCR_DEBUG_PREVIEW_CAPTURE := false
    if (OCR_AUTO_NARROW_REGION="")
        OCR_AUTO_NARROW_REGION := false
    if (OCR_RUN_SELF_TEST="")
        OCR_RUN_SELF_TEST := false
    if (OCR_FORCE_RDP_REGION="")
        OCR_FORCE_RDP_REGION := false
    if (OCR_DEBUG_MODE="")
        OCR_DEBUG_MODE := false
    if (OCR_SAVE_ROI_BITMAPS="")
        OCR_SAVE_ROI_BITMAPS := OCR_DEBUG_MODE
    if (OCR_ROI_SAVE_DIR="")
        OCR_ROI_SAVE_DIR := ocrDir "\debug_roi"
    LogRetention_DeleteFilesOlderThan(OCR_ROI_SAVE_DIR)
    LogRetention_DeleteFilesOlderThan(ocrDir, "OCR_Log*.txt")
    if (OCR_LOG_FILE="")
        OCR_LOG_FILE := ocrDir "\OCR_Log_" A_YYYY A_MM A_DD ".txt"
    if !IsObject(OCR_SP_REGION_RATIO)
        OCR_SP_REGION_RATIO := [-0.0016, 0.0000, 0.1110, 0.1318]
    if !IsObject(OCR_IMG_REGION_RATIO)
        OCR_IMG_REGION_RATIO := [0.9094, 0.0569, 0.0890, 0.0360]
    if !IsObject(OCR_SP_REGION_RATIO_RDP)
        OCR_SP_REGION_RATIO_RDP := [0, 0.0936, 0.0955, 0.0565]
    if !IsObject(OCR_IMG_REGION_RATIO_RDP)
        OCR_IMG_REGION_RATIO_RDP := [0.9248, 0.0559, 0.0752, 0.0419]
    if (OCR_SP_BOTTOM_READ_HEIGHT="")
        OCR_SP_BOTTOM_READ_HEIGHT := 70
    if (OCR_ROI_SAVE_COUNT="")
        OCR_ROI_SAVE_COUNT := 0
    if (OCR_RUN_T0="")
        OCR_RUN_T0 := 0
    if (OCR_LOG_LAST_TICK="")
        OCR_LOG_LAST_TICK := 0
    if (OCR_USE_ONESHOT_FILE_OCR="")
        OCR_USE_ONESHOT_FILE_OCR := true
    if (OCR_DIRECT_SCROLL="")
        OCR_DIRECT_SCROLL := true
    if (OCR_SLEEP_CALIBRATE="")
        OCR_SLEEP_CALIBRATE := 40
    if (OCR_SLEEP_CLICK="")
        OCR_SLEEP_CLICK := 10
    if (OCR_SLEEP_BATCH_SETTLE_IMG="")
        OCR_SLEEP_BATCH_SETTLE_IMG := 40
    if (OCR_SLEEP_BATCH_SETTLE_SP="")
        OCR_SLEEP_BATCH_SETTLE_SP := 40
    if (OCR_SLEEP_PRECISION_IMG="")
        OCR_SLEEP_PRECISION_IMG := 40
    if (OCR_SLEEP_PRECISION_SP="")
        OCR_SLEEP_PRECISION_SP := 0
    if (OCR_SLEEP_FOCUS_CLICK="")
        OCR_SLEEP_FOCUS_CLICK := 10
    if (OCR_SLEEP_DONE="")
        OCR_SLEEP_DONE := 0
    if (OCR_IMG_MAX_BATCH="")
        OCR_IMG_MAX_BATCH := 100
    if (OCR_DIRECT_REFINE_MAX_TICKS_IMG="")
        OCR_DIRECT_REFINE_MAX_TICKS_IMG := 20
    if (OCR_DIRECT_REFINE_MAX_TICKS_SP="")
        OCR_DIRECT_REFINE_MAX_TICKS_SP := 8
    if (OCR_COLD_READ_RETRIES="")
        OCR_COLD_READ_RETRIES := 4
    if (OCR_COLD_READ_SLEEP="")
        OCR_COLD_READ_SLEEP := 120
    if (OCR_SLEEP_INITIAL_READ="")
        OCR_SLEEP_INITIAL_READ := 120
    if (OCR_DRAG_SCROLL_DEFAULT="")
        OCR_DRAG_SCROLL_DEFAULT := true
    if (OCR_DRAG_SCROLL_RDP_ENABLE="")
        OCR_DRAG_SCROLL_RDP_ENABLE := false
    if (OCR_RDP_DRAG_URL="")
        OCR_RDP_DRAG_URL := ""
    if (OCR_DRAG_SCROLL_AVAILABLE="")
        OCR_DRAG_SCROLL_AVAILABLE := false
    if (OCR_DRAG_SCROLL_SP_ENABLE="")
        OCR_DRAG_SCROLL_SP_ENABLE := true
    if (OCR_DRAG_SCROLL_SP_MIN_TICKS="")
        OCR_DRAG_SCROLL_SP_MIN_TICKS := 10
    if (OCR_DRAG_SCROLL_SP_LEAVE_TICKS="")
        OCR_DRAG_SCROLL_SP_LEAVE_TICKS := 1
    if (OCR_DRAG_SCROLL_MAX_ROUGH_ATTEMPTS="")
        OCR_DRAG_SCROLL_MAX_ROUGH_ATTEMPTS := 6
    if (OCR_DRAG_SCROLL_SP_AUTO_LEARN="")
        OCR_DRAG_SCROLL_SP_AUTO_LEARN := true

    if (OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100="")
        OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100 := 0.11524
    if (OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100_RDP="")
        OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100_RDP := OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100
    if (OCR_DRAG_SCROLL_SP_SIGN="")
        OCR_DRAG_SCROLL_SP_SIGN := 1
    if (OCR_DRAG_SCROLL_SP_CONFIG_FILE="")
        OCR_DRAG_SCROLL_SP_CONFIG_FILE := ""
    if (OCR_DRAG_SCROLL_SP_CONFIG_SECTION="")
        OCR_DRAG_SCROLL_SP_CONFIG_SECTION := "Hotkey"
    if (OCR_DRAG_SCROLL_SP_CONFIG_KEY="")
        OCR_DRAG_SCROLL_SP_CONFIG_KEY := "INFINITTOCRDragScrollSPRatioPer100"
    if (OCR_DRAG_SCROLL_SP_CONFIG_KEY_RDP="")
        OCR_DRAG_SCROLL_SP_CONFIG_KEY_RDP := "INFINITTOCRDragScrollSPRatioPer100RDP"
    if (OCR_SCROLL_INPUT_MODE="")
        OCR_SCROLL_INPUT_MODE := "wheel"
    if (OCR_SCROLL_KEY_UP="")
        OCR_SCROLL_KEY_UP := "Up"
    if (OCR_SCROLL_KEY_DOWN="")
        OCR_SCROLL_KEY_DOWN := "Down"
    if (OCR_DRAG_STEP_PX="")
        OCR_DRAG_STEP_PX := 12
    if (OCR_DRAG_STEP_SLEEP="")
        OCR_DRAG_STEP_SLEEP := 2
    if (OCR_DRAG_ENDPOINT_SLEEP="")
        OCR_DRAG_ENDPOINT_SLEEP := 3

    OCR_WinRT_Init()
    initialized := true
}

OCR_DefaultRegion(mode, captureHwnd := 0) {
    if (OCR_IsRDPScenario()) {
        ; RDP one-monitor layout, client-relative to the INFINITT viewer window.
        if (mode = "Img")
            return [1828, 271, 163, 55]  ; (1828,271) - (1991,326)
        return [320, 336, 136, 71]      ; (320,336) - (456,407)
    }

    if (mode = "Img")
        return [1120, 372, 140, 72]
    return [0, 430, 149, 100]
}

OCR_ControlMarginRegion(mode, parentHwnd, viewportHwnd, parentRegion) {
    VarSetCapacity(parentPt, 8, 0)
    DllCall("ClientToScreen", "ptr", parentHwnd, "ptr", &parentPt)
    parentX := NumGet(parentPt, 0, "int"), parentY := NumGet(parentPt, 4, "int")

    VarSetCapacity(viewPt, 8, 0)
    DllCall("ClientToScreen", "ptr", viewportHwnd, "ptr", &viewPt)
    viewX := NumGet(viewPt, 0, "int"), viewY := NumGet(viewPt, 4, "int")

    VarSetCapacity(rect, 16, 0)
    DllCall("GetClientRect", "ptr", viewportHwnd, "ptr", &rect)
    cw := NumGet(rect, 8, "int"), ch := NumGet(rect, 12, "int")

    oldAbsY := parentY + parentRegion[2]
    if (mode = "Img") {
        w := Min(163, cw), h := Min(55, ch)
        x := Max(0, cw - w)
    } else {
        w := Min(136, cw), h := Min(71, ch)
        x := 3
    }
    y := Max(0, Min(ch - h, oldAbsY - viewY))
    OCR_LogStep("CONTROL ROI | parentRegion=" parentRegion[1] "," parentRegion[2] "," parentRegion[3] "," parentRegion[4] " | parentScreen=" parentX "," parentY " | viewScreen=" viewX "," viewY " | controlRegion=" x "," y "," w "," h " | screenROI=" viewX+x "," viewY+y)
    return [x, y, w, h]
}

OCR_ViewportRatioRegion(mode, viewportHwnd) {
    global OCR_SP_REGION_RATIO, OCR_IMG_REGION_RATIO, OCR_SP_REGION_RATIO_RDP, OCR_IMG_REGION_RATIO_RDP
    VarSetCapacity(rect, 16, 0)
    DllCall("GetClientRect", "ptr", viewportHwnd, "ptr", &rect)
    cw := NumGet(rect, 8, "int"), ch := NumGet(rect, 12, "int")
    WinGetPos, vx, vy, vw, vh, % "ahk_id " viewportHwnd

    useRDPProfile := IsCurrentSessionRDP()
    if (mode = "Img")
        ratio := useRDPProfile ? OCR_IMG_REGION_RATIO_RDP : OCR_IMG_REGION_RATIO
    else
        ratio := useRDPProfile ? OCR_SP_REGION_RATIO_RDP : OCR_SP_REGION_RATIO
    x := Round(cw * ratio[1])
    y := Round(ch * ratio[2])
    w := Max(1, Round(cw * ratio[3]))
    h := Max(1, Round(ch * ratio[4]))

    OCR_LogStep("VIEWPORT RATIO ROI | mode=" mode " | RDPProfile=" useRDPProfile " | viewportScreen=" vx "," vy "," vw "," vh " | client=" cw "x" ch " | ratio=" ratio[1] "," ratio[2] "," ratio[3] "," ratio[4] " | controlRegion=" x "," y "," w "," h " | screenROI=" vx+x "," vy+y)
    return [x, y, w, h]
}

OCR_SPBottomRegion(region) {
    global OCR_SP_BOTTOM_READ_HEIGHT
    if (!IsObject(region) || region.Length() < 4)
        return region
    h := Min(region[4], OCR_SP_BOTTOM_READ_HEIGHT)
    y := region[2] + region[4] - h
    return [region[1], y, region[3], h]
}

OCR_GetViewportHwnd(parentHwnd, mode, parentRegion := "") {
    try {
        ; No constructor: viewport enumeration needs no patient polling timer.
        pacs := INFINITT_PACS
        if IsObject(parentRegion) {
            VarSetCapacity(pt, 8, 0)
            DllCall("ClientToScreen", "ptr", parentHwnd, "ptr", &pt)
            targetX := NumGet(pt, 0, "int") + parentRegion[1] + (parentRegion[3] // 2)
            targetY := NumGet(pt, 4, "int") + parentRegion[2] + (parentRegion[4] // 2)
            for k, viewport in pacs.getViewportControls(parentHwnd) {
                WinGetPos, x, y, w, h, % "ahk_id " viewport
                if (targetX >= x && targetX <= x + w && targetY >= y && targetY <= y + h) {
                    OCR_LogStep("VIEWPORT BY ROI | hwnd=" viewport " | rect=" x "," y "," w "," h " | target=" targetX "," targetY)
                    return viewport
                }
            }
        }
        viewport := pacs.getViewportControl("image", parentHwnd)
        if (viewport) {
            WinGetPos, x, y, w, h, % "ahk_id " viewport
            OCR_LogStep("VIEWPORT BY POSITION | hwnd=" viewport " | rect=" x "," y "," w "," h)
            return viewport
        }
    } catch e {
        OCR_LogStep("VIEWPORT FIND FAILED | " e.Message)
    }
    return 0
}

OCR_IsRDPScenario() {
    global OCR_FORCE_RDP_REGION
    return OCR_FORCE_RDP_REGION || IsCurrentSessionRDP()
}

OCR_GetViewportPoint(mode, wx, wy, cW, cH, region) {
    ; Wheel scrolling in INFINITT depends on hover over the image viewport.
    ; Use a point well inside the viewport, away from corner overlays.
    if (OCR_IsRDPScenario() && mode = "Img")
        return {x: wx + region[1] + (region[3] // 2), y: wy + Min(cH - 80, region[2] + 420)}
    if (OCR_IsRDPScenario() && mode = "SP")
        return {x: wx + Max(120, region[1] + 240), y: wy + Min(cH - 80, region[2] + 420)}
    return {x: wx + (cW // 2), y: wy + (cH // 2)}
}

OCR_EnsureINFINITTReady(parentHwnd, viewportHwnd := 0) {
    if (parentHwnd && !WinActive("ahk_id " parentHwnd)) {
        OCR_LogStep("READY ACTIVATE | hwnd=" parentHwnd)
        WinActivate, ahk_id %parentHwnd%
        WinWaitActive, ahk_id %parentHwnd%,, 2
        OCR_LogStep("READY ACTIVE | hwnd=" parentHwnd " | ErrorLevel=" ErrorLevel)
    }

    if (!viewportHwnd || !WinExist("ahk_id " viewportHwnd))
        return

    WinGetPos, vx, vy, vw, vh, ahk_id %viewportHwnd%
    MouseGetPos, mx, my
    if (mx < vx || mx > vx + vw || my < vy || my > vy + vh) {
        cx := vx + Round(vw * 0.5)
        cy := vy + Round(vh * 0.2)
        OCR_LogStep("READY MOUSE MOVE | viewport=" viewportHwnd " | from=" mx "," my " | to=" cx "," cy " | ratio=0.5,0.2")
        OCR_SetCursorPoint(cx, cy)
        Sleep, 20
    }
}

OCR_GetCursorInfoSnapshot() {
    cbSize := (A_PtrSize = 8) ? 24 : 20
    VarSetCapacity(ci, cbSize, 0)
    NumPut(cbSize, ci, 0, "UInt")
    if !DllCall("GetCursorInfo", "Ptr", &ci)
        return {ok: false, ahk: A_Cursor, flags: 0, hCursor: 0}
    return {ok: true
        , ahk: A_Cursor
        , flags: NumGet(ci, 4, "UInt")
        , hCursor: NumGet(ci, 8, "Ptr")}
}

OCR_LogINFINITTDragCursor(viewportHwnd := 0) {
    info := OCR_GetCursorInfoSnapshot()
    MouseGetPos, mx, my, hwndUnderMouse
    inViewport := true
    if (viewportHwnd && WinExist("ahk_id " viewportHwnd)) {
        WinGetPos, vx, vy, vw, vh, ahk_id %viewportHwnd%
        inViewport := (mx >= vx && mx <= vx + vw && my >= vy && my <= vy + vh)
    }
    handleHex := Format("0x{:X}", info.hCursor + 0)
    OCR_LogStep("DRAG CURSOR | Default=1 | A_Cursor=" info.ahk " | hCursor=" handleHex " | flags=" info.flags " | inViewport=" inViewport " | mouse=" mx "," my " | hwndUnderMouse=" hwndUnderMouse)
}

OCR_SendScrollAction(action, viewportHwnd := 0) {
    global OCR_SCROLL_INPUT_MODE, OCR_SCROLL_KEY_UP, OCR_SCROLL_KEY_DOWN
    mode := Trim("" OCR_SCROLL_INPUT_MODE)
    if (mode = "" || mode = "wheel") {
        OCR_SendPointerClick(action)
        return
    }

    key := (action = "WheelUp") ? OCR_SCROLL_KEY_UP : OCR_SCROLL_KEY_DOWN
    if (key = "")
        key := (action = "WheelUp") ? "Up" : "Down"
    sendText := "{" key "}"
    if (mode = "key-control" || mode = "control" || mode = "keys") {
        if (viewportHwnd && WinExist("ahk_id " viewportHwnd)) {
            ControlSend,, %sendText%, ahk_id %viewportHwnd%
            OCR_LogStep("SCROLL KEY | action=" action " | key=" sendText " | target=control | hwnd=" viewportHwnd)
            return
        }
    }
    SendEvent, %sendText%
    OCR_LogStep("SCROLL KEY | action=" action " | key=" sendText " | target=active")
}

OCR_SendPointerClick(action := "", graceMs := 80) {
    global OCR_IGNORE_MANUAL_ABORT_UNTIL
    OCR_IGNORE_MANUAL_ABORT_UNTIL := A_TickCount + graceMs
    if (action = "")
        Click
    else
        Click, %action%
}

OCR_ScrollActionText(action, count := 1) {
    global OCR_SCROLL_INPUT_MODE, OCR_SCROLL_KEY_UP, OCR_SCROLL_KEY_DOWN
    mode := Trim("" OCR_SCROLL_INPUT_MODE)
    if (mode = "" || mode = "wheel")
        return action " x" count

    key := (action = "WheelUp") ? OCR_SCROLL_KEY_UP : OCR_SCROLL_KEY_DOWN
    if (key = "")
        key := (action = "WheelUp") ? "Up" : "Down"
    return key " x" count
}


OCR_TryRoughDrag(viewportHwnd, sign, dragTicks, runId := "", ratioOverride := "") {
    global OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100, OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100_RDP, OCR_DRAG_SCROLL_SP_SIGN, OCR_RDP_DRAG_URL
    if (!viewportHwnd || !WinExist("ahk_id " viewportHwnd) || dragTicks <= 0)
        return false

    WinGetPos, vx, vy, vw, vh, ahk_id %viewportHwnd%
    if (vw <= 0 || vh <= 0)
        return false

    isRDPDrag := (IsCurrentSessionRDP() && Trim("" OCR_RDP_DRAG_URL) != "")
    activeRatio := isRDPDrag ? OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100_RDP : OCR_DRAG_SCROLL_SP_VIEWPORT_RATIO_PER_100
    if (ratioOverride != "")
        activeRatio := ratioOverride
    pxPerTick := vh * activeRatio / 100.0
    dy := Round(dragTicks * pxPerTick)
    if (Abs(dy) < 2)
        return false

    ; sign=1 is the same direction as WheelUp; sign=-1 is WheelDown.
    ; OCR_DRAG_SCROLL_SP_SIGN can be flipped from the INI if the viewer's drag
    ; direction is opposite on a machine/session.
    dy := dy * sign * OCR_DRAG_SCROLL_SP_SIGN

    path := OCR_PlanDragPath(vx, vy, vw, vh, dy)
    if (!IsObject(path))
        return false
    sx := path.sx, sy := path.sy, ex := path.ex, ey := path.ey, dy := path.dy
    dragInfo := {ok: true, requestedTicks: dragTicks, pxPerTick: pxPerTick, dy: dy
        , ratioPer100: activeRatio, viewportH: vh, isRDP: isRDPDrag}
    OCR_LogStep("ROUGH DRAG | viewport=" viewportHwnd " | sign=" sign " | ticks=" dragTicks " | pxPerTick=" pxPerTick " | from=" sx "," sy " | to=" ex "," ey " | dy=" dy)

    ; In RDP sessions, AHK's synthetic mouse events are ignored by INFINITT.
    ; Delegate the drag to the MacBook via HTTP: the Mac performs a real hardware
    ; drag inside its RDP client window, which INFINITT receives as genuine input.
    if (isRDPDrag) {
        ToolTip, % "RDP drag via Mac " dragTicks " steps`n" sx "," sy " -> " ex "," ey
        result := OCR_TryRoughDragViaHTTP(sx, sy, ex, ey, vx, vy, vw, vh)
        ToolTip
        ; An HTTP failure may occur after the remote machine sent input. Always
        ; verify the displayed slice before any fallback input.
        dragInfo.ok := result
        if (!result)
            dragInfo.pathVerified := false
        return dragInfo
    }

    ; The recorded M4 SetCursorPos test was vertical/full-length. M3 MouseMove
    ; was short/offset on this mixed-DPI layout. Measure endpoints on every drag.
    ToolTip, % "Rough drag " dragTicks " steps`n" sx "," sy " -> " ex "," ey
    motion := OCR_IncrementalDrag(sx, sy, ex, ey, runId)
    dragInfo.ok := motion.ok
    dragInfo.pathVerified := motion.ok
    if (IsObject(motion.start) && IsObject(motion.finish)) {
        dragInfo.actualDy := motion.finish.y - motion.start.y
        OCR_LogStep("DRAG ACTUAL PATH | from=" motion.start.x "," motion.start.y " | to=" motion.finish.x "," motion.finish.y
            . " | dy=" dragInfo.actualDy " | PlannedDy=" dy " | Steps=" motion.steps " | Verified=" motion.ok)
    }
    ToolTip
    return dragInfo
}


OCR_CursorPoint() {
    VarSetCapacity(pt, 8, 0)
    if !DllCall("GetCursorPos", "Ptr", &pt)
        return false
    return {x: NumGet(pt, 0, "Int"), y: NumGet(pt, 4, "Int")}
}

OCR_SetCursorPoint(x, y) {
    return DllCall("SetCursorPos", "Int", x, "Int", y)
}

; GetCursorPos and SetCursorPos use the same thread coordinate context. Keep it
; unchanged and check both endpoints rather than assuming synthetic travel.
OCR_IncrementalDrag(sx, sy, ex, ey, runId := "") {
    global OCR_DRAG_STEP_PX, OCR_DRAG_STEP_SLEEP, OCR_DRAG_ENDPOINT_SLEEP
    stepPx := Max(3, OCR_DRAG_STEP_PX + 0)
    stepSleep := Max(0, OCR_DRAG_STEP_SLEEP + 0)
    endpointSleep := Max(0, OCR_DRAG_ENDPOINT_SLEEP + 0)
    steps := OCR_DragMoveSteps(Max(Abs(ex - sx), Abs(ey - sy)), stepPx)
    if !OCR_SetCursorPoint(sx, sy)
        return {ok: false}
    if (endpointSleep > 0)
        Sleep, %endpointSleep%
    start := OCR_CursorPoint()
    if (!IsObject(start) || Abs(start.x - sx) > 2 || Abs(start.y - sy) > 2 || INFINITT_OCR_IsAbortRequested(runId))
        return {ok: false, start: start}
    try {
        OCR_SendPointerClick("Down")
        Loop, %steps% {
            if INFINITT_OCR_IsAbortRequested(runId)
                return {ok: false, start: start, finish: OCR_CursorPoint(), steps: A_Index - 1}
            t := A_Index / steps
            cx := Round(sx + (ex - sx) * t)
            cy := Round(sy + (ey - sy) * t)
            if !OCR_SetCursorPoint(cx, cy)
                return {ok: false, start: start, finish: OCR_CursorPoint(), steps: A_Index - 1}
            if (stepSleep > 0)
                Sleep, %stepSleep%
        }
        if (endpointSleep > 0)
            Sleep, %endpointSleep%
        finish := OCR_CursorPoint()
    } finally {
        OCR_SendPointerClick("Up")
    }
    ok := IsObject(finish) && Abs(finish.x - ex) <= 2 && Abs(finish.y - ey) <= 2 && !INFINITT_OCR_IsAbortRequested(runId)
    return {ok: ok, start: start, finish: finish, steps: steps}
}

; POST drag coordinates to the MacBook server.
;
; Coordinate chain (no Retina factor needed):
;   AHK WinGetPos → Windows logical px (= RDP session resolution, e.g. 2560×1440)
;   ─ HTTP payload ─
;   Mac server: mac_x = rdp_win_left + win_x * rdp_win_w / win_screen_w
;               mac_y = rdp_win_top  + win_y * rdp_win_h / win_screen_h
;   All Mac coords in logical POINTS.  cliclick/pyautogui use pts, so Retina 2×
;   is invisible — no extra scale factor.
;   rdp_win bounds: obtained server-side via AppleScript/Quartz on the Mac.
;
; Payload:
;   { "from_x", "from_y", "to_x", "to_y",
;     "win_screen": { "w": <Windows session width px>,
;                     "h": <Windows session height px> },
;     "viewport":   { "x", "y", "w", "h" } }
OCR_TryRoughDragViaHTTP(sx, sy, ex, ey, vx, vy, vw, vh) {
    global OCR_RDP_DRAG_URL
    url := Trim("" OCR_RDP_DRAG_URL)
    if (url = "")
        return false

    SysGet, winScrW, 0   ; SM_CXSCREEN — primary monitor width (= RDP session width)
    SysGet, winScrH, 1   ; SM_CYSCREEN — primary monitor height (= RDP session height)

    json := "{""from_x"":" sx ",""from_y"":" sy ",""to_x"":" ex ",""to_y"":" ey
        . ",""win_screen"":{""w"":" winScrW ",""h"":" winScrH "}"
        . ",""viewport"":{""x"":" vx ",""y"":" vy ",""w"":" vw ",""h"":" vh "}}"
    try {
        http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", url, false)
        http.SetRequestHeader("Content-Type", "application/json")
        http.SetTimeouts(3000, 3000, 3000, 5000)
        http.Send(json)
        status := 0
        try status := http.Status
        OCR_LogStep("RDP DRAG HTTP | status=" status " | " sx "," sy " -> " ex "," ey " | viewport=" vx "," vy "," vw "x" vh)
        return (status >= 200 && status < 300)
    } catch e {
        OCR_LogStep("RDP DRAG HTTP FAILED | " e.Message)
        return false
    }
}

; ── OCR helpers ───────────────────────────────────────────────────

OCR_LogStep(msg) {
    global OCR_DEBUG_MODE, OCR_RUN_T0, OCR_LOG_LAST_TICK, OCR_LOG_FILE
    if (!OCR_DEBUG_MODE)
        return
    nowTick := A_TickCount
    if (!OCR_RUN_T0)
        OCR_RUN_T0 := nowTick
    if (!OCR_LOG_LAST_TICK)
        OCR_LOG_LAST_TICK := nowTick
    elapsed := nowTick - OCR_RUN_T0
    delta := nowTick - OCR_LOG_LAST_TICK
    OCR_LOG_LAST_TICK := nowTick
    FileAppend, % A_Now " +" elapsed "ms d" delta "ms | " msg "`n", %OCR_LOG_FILE%
}

OCR_OneLine(text) {
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

OCR_CorrectImgPartial(current, expected) {
    expected := Round(expected)
    current := Round(current)

    ; INFINITT/OCR often reads two-digit Img values as only the tens digit.
    ; Use the known one-frame-per-wheel prediction to restore the lost ones digit.
    if (expected >= 10 && expected <= 99 && current = Floor(expected / 10))
        return expected

    return current
}

OCR_ReadAfterInput(region, hwnd, mode, cacheId, clientW, clientH, beforeVal, runId) {
    ; Wait for a changed value to settle twice, without issuing additional input
    ; against a stale/blank frame. Typical stable render costs two small ROI reads.
    lastVal := ""
    started := A_TickCount
    unchangedOnly := true
    settleGrace := false
    Loop, 24 {
        if (INFINITT_OCR_IsAbortRequested(runId))
            return ""
        text := (A_Index = 1) ? OCR_ReadTextDynamic(region, hwnd, mode, cacheId, clientW, clientH)
            : OCR_ReadText(region, hwnd, mode)
        value := ParseOCR(text, mode)
        if (value != "" && value != beforeVal && lastVal != "" && Abs(value - lastVal) < 0.011)
            return text
        if (value = "" || value != beforeVal)
            unchangedOnly := false
        lastVal := value
        if (A_Index = 5 && unchangedOnly) {
            ; The initial fast OCR pass can finish before PACS processes queued
            ; input. Wait once without sending any more keys or dragging again.
            settleGrace := true
            OCR_LogStep("SETTLE GRACE | Mode=" mode " | Before=" beforeVal)
        }
        if (A_Index >= 5 && (!settleGrace || A_TickCount - started >= 1000))
            break
        Sleep, 40
    }
    OCR_LogStep("UNSETTLED READ | Mode=" mode " | Before=" beforeVal " | Last=" lastVal)
    return ""
}

OCR_ReadTextDynamic(region, hwnd, mode, cacheId := "", clientW := "", clientH := "", retries := 0, retrySleep := 120) {
    static dynamicRegionCache := {}

    regionKey := (cacheId != "") ? cacheId : (hwnd "|" mode)
    if (regionKey != "" && dynamicRegionCache.HasKey(regionKey))
        OCR_CopyRegion(dynamicRegionCache[regionKey], region)

    text := OCR_ReadTextWithRetry(region, hwnd, mode, retries, retrySleep)
    if (OCR_ModeTextDetected(text, mode))
        return text

    if (clientW = "" || clientH = "") {
        VarSetCapacity(rect, 16)
        DllCall("GetClientRect", "ptr", hwnd, "ptr", &rect)
        clientW := NumGet(rect, 8, "int")
        clientH := NumGet(rect, 12, "int")
    }

    Loop, 8 {
        oldX := region[1], oldY := region[2], oldW := region[3], oldH := region[4]
        OCR_GrowRegionInPlace(region, clientW, clientH, 25)
        if (region[1] = oldX && region[2] = oldY && region[3] = oldW && region[4] = oldH)
            break

        OCR_LogStep("DYNAMIC ROI GROW | Mode=" mode " | Key=" regionKey " | Region=" region[1] "," region[2] "," region[3] "," region[4])
        ; Cold retries apply once, not another five times for every enlarged ROI.
        if (INFINITT_OCR_IsAbortRequested())
            return ""
        text := OCR_ReadTextWithRetry(region, hwnd, mode, 0, retrySleep)
        if (OCR_ModeTextDetected(text, mode)) {
            if (regionKey != "")
                dynamicRegionCache[regionKey] := [region[1], region[2], region[3], region[4]]
            OCR_LogStep("DYNAMIC ROI HIT | Mode=" mode " | Key=" regionKey " | Region=" region[1] "," region[2] "," region[3] "," region[4] " | Raw=" OCR_OneLine(text))
            return text
        }
    }
    OCR_LogStep("DYNAMIC ROI MISS | Mode=" mode " | Key=" regionKey " | Raw=" OCR_OneLine(text))
    return text
}

OCR_ReadTextWithRetry(region, hwnd, mode, retries := 0, retrySleep := 120) {
    text := OCR_ReadText(region, hwnd, mode)
    if (OCR_ModeTextDetected(text, mode))
        return text

    Loop, %retries% {
        if (INFINITT_OCR_IsAbortRequested())
            return ""
        Sleep, %retrySleep%
        retryText := OCR_ReadText(region, hwnd, mode)
        OCR_LogStep("OCR RETRY | Mode=" mode " | Attempt=" A_Index " | Text=" OCR_OneLine(retryText))
        if (OCR_ModeTextDetected(retryText, mode))
            return retryText
        if (StrLen(retryText) > StrLen(text))
            text := retryText
    }
    return text
}

OCR_CopyRegion(src, dst) {
    dst[1] := src[1]
    dst[2] := src[2]
    dst[3] := src[3]
    dst[4] := src[4]
}

OCR_GrowRegionInPlace(region, clientW, clientH, pad := 25) {
    oldRight := region[1] + region[3]
    oldBottom := region[2] + region[4]
    newX := Max(0, region[1] - pad)
    newY := Max(0, region[2] - pad)
    newRight := Min(clientW, oldRight + pad)
    newBottom := Min(clientH, oldBottom + pad)
    region[1] := newX
    region[2] := newY
    region[3] := Max(1, newRight - newX)
    region[4] := Max(1, newBottom - newY)
}

OCR_ModeTextDetected(text, mode) {
    if (mode = "Img")
        return RegExMatch(text, "i)(?:Img|lmg|lmq|Imq|Ima|Image)")

    text := NormalizeOCR_SpSlText(text)
    return RegExMatch(text, "i)(?:S\s*P|Pos|Position|\bP\b)\s*[=：:]?\s*[-]?\d")
}

OCR_Read(region, hwnd, mode) {
    text := OCR_ReadText(region, hwnd, mode)
    return ParseOCR(text, mode)
}

OCR_ReadText(region, hwnd, mode := "") {
    return OCR_ReadTextWindow(region, hwnd)
}

OCR_ReadTextWindow(region, hwnd) {
    global OCR_DEBUG_MODE, OCR_SAVE_ROI_BITMAPS

    cap := GetCaptureRectFromClient(hwnd, region[1], region[2], region[3], region[4])
    OCR_LogStep("OCR READ ROI | hwnd=" hwnd " | clientRegion=" region[1] "," region[2] "," region[3] "," region[4]
        . " | logicalScreen=" cap.screenX "," cap.screenY "," cap.screenW "," cap.screenH
        . " | physicalScreen=" cap.x "," cap.y "," cap.w "," cap.h " | scale=" cap.scale)

    text := _OWR_OcrWindowRectViaWorker(hwnd, region[1], region[2], region[3], region[4], "en-US")
    OCR_LogStep("OCR WINDOW ROI RESULT | hwnd=" hwnd " | Text=" OCR_OneLine(text))
    if (text = "") {
        text := OCR_WinRT_GetText(cap.screenX, cap.screenY, cap.screenW, cap.screenH, 0, 4)
        OCR_LogStep("OCR SCREEN ROI RESULT | Text=" OCR_OneLine(text))
    }

    if (OCR_DEBUG_MODE && OCR_SAVE_ROI_BITMAPS) {
        OCR_SaveScreenROIBitmap(cap)
        OCR_SaveROITextDebug(cap, text)
    }
    return text
}

OCR_OcrBitmapOneShotTemp(hBM) {
    tempBmp := A_Temp "\INFINITT_OCR_" A_TickCount "_" DllCall("GetCurrentProcessId") ".bmp"
    _OWR_SaveBitmap(hBM, tempBmp)
    text := _OWR_OcrFileOneShot(tempBmp)
    FileDelete, %tempBmp%
    return text
}

OCR_SaveROIBitmap(cap) {
    global OCR_DEBUG_MODE, OCR_SAVE_ROI_BITMAPS
    if (!OCR_DEBUG_MODE || !OCR_SAVE_ROI_BITMAPS)
        return

    hBM := _OWR_CaptureRect(cap.x, cap.y, cap.w, cap.h, cap.w, cap.h)
    OCR_SaveBitmapHandle(hBM, "screen_x" cap.x "_y" cap.y "_w" cap.w "_h" cap.h)
    if (hBM)
        DllCall("DeleteObject", "Ptr", hBM)
}

OCR_SaveScreenROIBitmap(cap) {
    global OCR_DEBUG_MODE, OCR_SAVE_ROI_BITMAPS
    if (!OCR_DEBUG_MODE || !OCR_SAVE_ROI_BITMAPS)
        return

    hBM := _OWR_CaptureRect(cap.screenX, cap.screenY, cap.screenW, cap.screenH, Max(1, cap.screenW), Max(1, cap.screenH))
    OCR_SaveBitmapHandle(hBM, "screen_logical_x" cap.screenX "_y" cap.screenY "_w" cap.screenW "_h" cap.screenH)
    if (hBM)
        DllCall("DeleteObject", "Ptr", hBM)

    scaleW := Max(40, cap.screenW * 4)
    scaleH := Max(40, cap.screenH * 4)
    hBM2 := _OWR_CaptureRect(cap.screenX, cap.screenY, cap.screenW, cap.screenH, scaleW, scaleH)
    OCR_SaveBitmapHandle(hBM2, "screen_logical_x" cap.screenX "_y" cap.screenY "_w" cap.screenW "_h" cap.screenH "_scale4")
    if (hBM2)
        DllCall("DeleteObject", "Ptr", hBM2)
}

OCR_SaveROITextDebug(cap, text) {
    global OCR_DEBUG_MODE, OCR_SAVE_ROI_BITMAPS, OCR_ROI_SAVE_DIR, OCR_ROI_SAVE_COUNT
    if (!OCR_DEBUG_MODE || !OCR_SAVE_ROI_BITMAPS)
        return
    if !FileExist(OCR_ROI_SAVE_DIR)
        FileCreateDir, %OCR_ROI_SAVE_DIR%
    file := OCR_ROI_SAVE_DIR "\" A_Now "_" Format("{:03}", OCR_ROI_SAVE_COUNT) "_ocr_region.txt"
    out := "logicalScreen=" cap.screenX "," cap.screenY "," cap.screenW "," cap.screenH "`n"
        . "physicalScreen=" cap.x "," cap.y "," cap.w "," cap.h "`n"
        . "scale=" cap.scale "`n"
        . "OCR=" text "`n"
    FileAppend, %out%, %file%
    OCR_LogStep("ROI TXT | " file)
}

OCR_SaveBitmapHandle(hBM, suffix) {
    global OCR_ROI_SAVE_DIR, OCR_ROI_SAVE_COUNT

    if !FileExist(OCR_ROI_SAVE_DIR)
        FileCreateDir, %OCR_ROI_SAVE_DIR%

    OCR_ROI_SAVE_COUNT += 1
    file := OCR_ROI_SAVE_DIR "\" A_Now "_" Format("{:03}", OCR_ROI_SAVE_COUNT)
        . "_" suffix ".bmp"

    if (hBM) {
        _OWR_SaveBitmap(hBM, file)
        OCR_LogStep("ROI BMP | " file)
        return file
    } else {
        OCR_LogStep("ROI BMP FAILED | " suffix)
    }
    return ""
}

OCR_TooltipText(text, maxLen := 80) {
    text := RegExReplace(text, "\s+", " ")
    text := Trim(text)
    if (text = "")
        return "<empty>"
    if (StrLen(text) > maxLen)
        return SubStr(text, 1, maxLen - 3) "..."
    return text
}

OCR_DebugStartupCapture() {
    global OCR_DEBUG_REGION_VIEW, OCR_DEBUG_PREVIEW_CAPTURE, _OWR_Engine, _OWR_LastBitmap

    ; Preserved for capture/coordinate troubleshooting. Disabled by default.
    _test_hwnd := GetLeftmostINFINITTHwnd()
    if !_test_hwnd {
        MsgBox, INFINITT not found. Engine init OK (ptr=%_OWR_Engine%)
        return
    }

    WinGet, _test_hwnd, ID, ahk_id %_test_hwnd%
    WinGetTitle, _tTitle, ahk_id %_test_hwnd%
    WinGetClass, _tClass, ahk_id %_test_hwnd%
    ToolTip, % "Found Window:`nID: " _test_hwnd "`nTitle: " _tTitle "`nClass: " _tClass
    Sleep, 2000
    ToolTip

    VarSetCapacity(pt, 8, 0)
    DllCall("ClientToScreen", "ptr", _test_hwnd, "ptr", &pt)
    wx := NumGet(pt, 0, "int"), wy := NumGet(pt, 4, "int")

    tx := 0, ty := 430, tw := 149, th := 100 ; Broad SP search region

    if (OCR_DEBUG_REGION_VIEW) {
        ToolTip, % "Visualizing ROI frame... (Screen: " wx+tx "," wy+ty ")"
        ShowOCRRegion(wx + tx, wy + ty, tw, th, 2000)
        ToolTip
    }

    _cap := GetCaptureRectFromClient(_test_hwnd, tx, ty, tw, th)
    _test_text := OCR_WinRT_GetText(_cap.x, _cap.y, _cap.w, _cap.h, 0, 4)
    _OWR_SaveBitmap(_OWR_LastBitmap, A_ScriptDir "\debug_capture_screen.bmp")

    if (OCR_DEBUG_PREVIEW_CAPTURE)
        ShowOCRPreview(_OWR_LastBitmap, "OCR Preview (Screen) - " tw "x" th)

    MsgBox, % "OCR result:`n[ScreenCapture]: [" _test_text "]"
        . "`n`nCapture saved to:`n" A_ScriptDir "\debug_capture_screen.bmp"
}

OCR_ResolveReadingRegion(region, hwnd, mode) {
    global OCR_LOG_FILE
    label := (mode = "Img") ? "Img" : "SP"
    cap := GetCaptureRectFromClient(hwnd, region[1], region[2], region[3], region[4])
    line := _OWR_LocateLineRectViaWorker(cap.x, cap.y, cap.w, cap.h, label)
    if !IsObject(line) {
        FileAppend, % A_Now " | ROI KEEP | Mode=" mode " | Region=" region[1] "," region[2] "," region[3] "," region[4] "`n", %OCR_LOG_FILE%
        return region
    }

    padTop := 4
    padBottom := 6
    relYPhys := line.y - cap.y
    relHPhys := line.h
    relY := Floor(relYPhys / cap.scale)
    relH := Ceil(relHPhys / cap.scale)

    newY := region[2] + Max(0, relY - padTop)
    newH := Max(28, relH + padTop + padBottom)
    maxBottom := region[2] + region[4]
    if (newY + newH > maxBottom)
        newH := Max(28, maxBottom - newY)

    narrowed := [region[1], newY, region[3], newH]
    log_line := A_Now " | ROI NARROW | Mode=" mode " | Label=" label " | Text=" line.text
        . " | Region=" narrowed[1] "," narrowed[2] "," narrowed[3] "," narrowed[4]
    FileAppend, % log_line "`n", %OCR_LOG_FILE%
    return narrowed
}

GetCaptureRectFromClient(hwnd, x, y, w, h) {
    ; AHK's GUI overlay coordinates were correct before the DPI-awareness experiment,
    ; so keep those logical coords for display and convert only the capture rect into
    ; physical pixels for desktop GDI capture.
    VarSetCapacity(pt, 8, 0)
    NumPut(x, pt, 0, "Int")
    NumPut(y, pt, 4, "Int")
    DllCall("ClientToScreen", "ptr", hwnd, "ptr", &pt)
    sx := NumGet(pt, 0, "Int")
    sy := NumGet(pt, 4, "Int")

    ; Convert logical screen coords to physical pixels when Windows is virtualizing
    ; coordinates for this process on a scaled monitor.
    VarSetCapacity(ptPhys, 8, 0)
    NumPut(sx, ptPhys, 0, "Int")
    NumPut(sy, ptPhys, 4, "Int")
    if DllCall("User32\LogicalToPhysicalPointForPerMonitorDPI", "ptr", hwnd, "ptr", &ptPhys) {
        px := NumGet(ptPhys, 0, "Int")
        py := NumGet(ptPhys, 4, "Int")
    } else {
        px := sx
        py := sy
    }

    scale := GetWindowDpiScale(hwnd)
    pw := Max(1, Round(w * scale))
    ph := Max(1, Round(h * scale))
    return {x: px, y: py, w: pw, h: ph, scale: scale
        , screenX: sx, screenY: sy, screenW: w, screenH: h}
}

GetWindowDpiScale(hwnd) {
    dpi := DllCall("User32\GetDpiForWindow", "ptr", hwnd, "uint")
    if (dpi)
        return dpi / 96.0
    return 1.0
}

; NormalizeOCR_SpSlText — fix common OCR misreads in the INFINITT SP overlay SL/SP line.
; Two patterns are addressed:
;   1. Capital letter 'O' mistaken for digit '0' in numeric runs  (e.g. "10.OO" → "10.00")
;   2. Digit '1' mistaken for pipe '|' when it immediately precedes the 'sp' label
;      (e.g. "580.551sp10.00" → "580.55|sp10.00")
; Capital 'I' / lowercase 'l' → '1' in numeric runs is also corrected (mirrors Img normalizer).
NormalizeOCR_SpSlText(text) {
    ; O → 0 when adjacent to digits or decimal point
    text := RegExReplace(text, "(?<=[0-9.])O", "0")
    text := RegExReplace(text, "O(?=[0-9.])", "0")
    ; I / l → 1 between digits
    text := RegExReplace(text, "(?<=[0-9])[Il](?=[0-9])", "1")
    ; Digit-1 immediately before 'sp' (case-insensitive) is a pipe separator
    text := RegExReplace(text, "i)(\d)1(sp)", "$1|$2")
    return text
}

ParseOCR(text, mode) {
    if (mode = "Img") {
        if RegExMatch(text, "i)(?:Img|lmg|lmq|Imq|Ima|Image)[^\dIl|Oo]*([0-9Il|Oo]+)", m)
            return OCR_NormalizeImgDigits(m1) + 0
        if RegExMatch(text, "i)(?:Srs|Ser|Series)[^\d]*\d+\D+(?:Img|lmg|lmq|Imq|Ima|Image)[^\dIl|Oo]*([0-9Il|Oo]+)", m)
            return OCR_NormalizeImgDigits(m1) + 0
        if RegExMatch(text, "i)(?:Img|lmg|lmq|Imq|Ima|Image)")
            return ""
        if RegExMatch(text, "(\d+)", m)
            return m1 + 0
        return ""
    }
    ; SP mode — recover decimal point mangled by OCR, strip noise chars
    text := NormalizeOCR_SpSlText(text)   ; fix O→0, I/l→1, digit-1-sp → pipe-sp
    c := RegExReplace(text, "[\[\]|{}!?;:_]", "")
    c := StrReplace(c, "一", "-")
    c := RegExReplace(c, "[—–−]", "-")
    c := RegExReplace(c, "(\d)\s*[,．]\s*(\d{2})\b", "$1.$2")  ; "9,50" or "9 50" → "9.50"
    c := RegExReplace(c, "(\d)\s+(\d)", "$1.$2")                ; "9 5" → "9.5"
    ; Preserve integer positions: inventing a decimal changes SP -100 to -1.00.
    ; Prefer the final SP/P-labelled number. Broad ROIs may include an
    ; "SL: 1.25 | sp5.00" spacing line before the real "SP: 71.25" position.
    lastSP := ""
    scanPos := 1
    while (scanPos := RegExMatch(c, "i)(?:S\s*P|Pos|Position|\bP\b)\s*[=：:]?\s*([-]?\d+\.?\d*)", m, scanPos)) {
        lastSP := m1
        scanPos += Max(1, StrLen(m))
    }
    if (lastSP != "")
        return lastSP + 0
    if RegExMatch(c, "i)(?:S\s*L|Slice|Spacing|\bsp\s*\d)")
        return ""
    if RegExMatch(c, "([\-—–−]?\d+\.?\d*)", m)
        return m1 + 0
    return ""
}

ParseOCR_SPSpacing(text) {
    text := NormalizeOCR_SpSlText(text)   ; fix O→0, I/l→1, digit-1-sp → pipe-sp
    c := RegExReplace(text, "[\[\]|{}!?;:_]", "")
    c := StrReplace(c, "一", "-")
    c := RegExReplace(c, "[—–−]", "-")
    c := RegExReplace(c, "(\d)\s*[,．]\s*(\d{1,3})\b", "$1.$2")
    c := RegExReplace(c, "(\d)\s+(\d)", "$1.$2")

    ; SL/SPac is slice spacing/location interval. Only trust the common
    ; displayed values; otherwise fall back to measured SP scroll delta.
    if RegExMatch(c, "i)(?:S\s*L|Slice\s*(?:Loc|Location)?|Spacing)[^\d\-]*([-]?\d+\.?\d*)", m) {
        valueText := RegExReplace(m1, "[^\d.]", "")
        value := Abs(valueText + 0)
        if (value >= 1.245 && value <= 1.255)
            return 1.25
        if (value >= 0.995 && value <= 1.005)
            return 1.00
        if (value >= 0.620 && value <= 0.630)
            return 0.625
        if (value >= 4.995 && value <= 5.005)
            return 5.00
        if (value >= 9.995 && value <= 10.005)
            return 10.00
    }
    ; 'sp{N}' inline label — covers sp5.00, sp10.00, sp1.25, etc.
    if RegExMatch(c, "i)\bsp\s*(\d+[.,]?\d*)", m) {
        valueText := RegExReplace(m1, "[^\d.]", "")
        value := Abs(valueText + 0)
        if (value >= 1.245 && value <= 1.255)
            return 1.25
        if (value >= 0.995 && value <= 1.005)
            return 1.00
        if (value >= 0.620 && value <= 0.630)
            return 0.625
        if (value >= 4.995 && value <= 5.005)
            return 5.00
        if (value >= 9.995 && value <= 10.005)
            return 10.00
    }
    return ""
}

OCR_NormalizeImgDigits(text) {
    text := RegExReplace(text, "i)[Il|]", "1")
    text := RegExReplace(text, "i)O", "0")
    text := RegExReplace(text, "\D", "")
    return text
}

ParseOCR_ImgTotal(text) {
    if RegExMatch(text, "i)(?:Img|lmg|lmq|Imq|Ima|Image)[^\dIl|Oo]*([0-9Il|Oo]+)\s*/\s*([0-9Il|Oo]+)", m)
        return OCR_NormalizeImgDigits(m2) + 0
    if RegExMatch(text, "i)(?:Img|lmg|lmq|Imq|Ima|Image)[^\dIl|Oo]*([0-9Il|Oo]+)\s*(?:of|OF)\s*([0-9Il|Oo]+)", m)
        return OCR_NormalizeImgDigits(m2) + 0
    return ""
}

; ── Window discovery ──────────────────────────────────────────────

GetLeftmostINFINITTHwnd() {
    return FindInfinittViewerHwnd("leftmost", true)
}

; ── OCR: native WinRT (no subprocess) ───────────────────────────
; Thin wrapper so all callers (OCR_Read, main loop) need no changes.

OCR_GetText_v2(x, y, w, h, hwnd := 0) {
    if (hwnd) {
        cap := GetCaptureRectFromClient(hwnd, x, y, w, h)
        return OCR_WinRT_GetText(cap.screenX, cap.screenY, cap.screenW, cap.screenH, 0)
    }
    return OCR_WinRT_GetText(x, y, w, h, 0)
}

; ── ROI visualizer ────────────────────────────────────────────────

ShowOCRRegion(x, y, w, h, duration := 2000) {
    static hGui := 0
    if (!hGui) {
        Gui, OCRRegion: +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20
        hGui := WinExist()
        Gui, OCRRegion: Color, Red
    }

    border := 2
    innerW := w - (border * 2)
    innerH := h - (border * 2)

    WinSet, Region, 0-0 %w%-0 %w%-%h% 0-%h% 0-0  %border%-%border% %innerW%-%border% %innerW%-%innerH% %border%-%innerH% %border%-%border%

    Gui, OCRRegion: Show, x%x% y%y% w%w% h%h% NoActivate
    if (duration > 0) {
        Sleep, %duration%
        Gui, OCRRegion: Hide
    }
}

ShowOCRPreview(hBM, title := "OCR Preview") {
    static hGui := 0, hPic := 0
    if (!hBM)
        return
    if (!hGui) {
        Gui, OCRPreview: +AlwaysOnTop +ToolWindow +LabelOCRPreview
        Gui, OCRPreview: Color, Black
        Gui, OCRPreview: Add, Picture, vhPic
        hGui := WinExist()
    }
    Gui, OCRPreview: Default
    GuiControl, , hPic, HBITMAP:%hBM%
    Gui, OCRPreview: Show, AutoSize NoActivate, %title%
}

OCRPreviewClose:
    Gui, OCRPreview: Hide
return

; Keep this file include-safe. Do not install a global Esc hotkey here.

INFINITT_OCR_RequestAbort() {
    global OCR_RUN_ACTIVE, OCR_ABORT_REQUESTED, OCR_ACTIVE_RUN_ID, OCR_ABORTED_RUNS
    if (!OCR_RUN_ACTIVE)
        return false
    if !IsObject(OCR_ABORTED_RUNS)
        OCR_ABORTED_RUNS := {}
    if (OCR_ACTIVE_RUN_ID != "")
        OCR_ABORTED_RUNS[OCR_ACTIVE_RUN_ID] := true
    OCR_ABORT_REQUESTED := true
    OCR_LogStep("ABORT REQUESTED | RunId=" OCR_ACTIVE_RUN_ID)
    ToolTip, OCR scroll abort requested
    return true
}

INFINITT_OCR_IsAbortRequested(runId := "") {
    global OCR_ABORT_REQUESTED, OCR_ACTIVE_RUN_ID, OCR_ABORTED_RUNS, OCR_RUN_ACTIVE, OCR_RUN_DEADLINE
    if (runId = "")
        runId := OCR_ACTIVE_RUN_ID
    if (IsObject(OCR_ABORTED_RUNS) && OCR_ABORTED_RUNS.HasKey(runId))
        return true
    if (OCR_RUN_ACTIVE && runId = OCR_ACTIVE_RUN_ID && OCR_RUN_DEADLINE && A_TickCount >= OCR_RUN_DEADLINE) {
        OCR_LogStep("TIME LIMIT | RunId=" runId)
        OCR_ABORT_REQUESTED := true
    }
    return (runId = OCR_ACTIVE_RUN_ID && OCR_ABORT_REQUESTED)
}

INFINITT_OCR_CheckAbort(stage := "", runId := "") {
	global OCR_ACTIVE_RUN_ID
	if (runId = "")
		runId := OCR_ACTIVE_RUN_ID
    if !INFINITT_OCR_IsAbortRequested(runId)
        return false
    OCR_LogStep("ABORTED | RunId=" runId " | " stage)
    ToolTip, OCR scroll aborted
    Sleep, 200
    ToolTip
    OCR_FinishRun(runId, true)
    return true
}

INFINITT_OCR_WasAborted() {
    global OCR_LAST_ABORTED
    return OCR_LAST_ABORTED
}

OCR_FinishRun(runId := "", aborted := false) {
    global OCR_RUN_ACTIVE, OCR_ABORT_REQUESTED, OCR_ACTIVE_RUN_ID, OCR_ABORTED_RUNS, OCR_LAST_ABORTED
    OCR_LAST_ABORTED := aborted
    if (IsObject(OCR_ABORTED_RUNS) && runId != "")
        OCR_ABORTED_RUNS.Delete(runId)
    if (runId = "" || runId = OCR_ACTIVE_RUN_ID) {
        OCR_RUN_ACTIVE := false
        OCR_ABORT_REQUESTED := false
    }
}

INFINITT_OCR_OnExit_UNUSED:
DllCall("mouse_event", "UInt", 0x0004, "Int", 0, "Int", 0, "UInt", 0, "UInt", 0)
exitapp
