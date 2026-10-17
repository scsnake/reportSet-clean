; AHK v1 standalone viewport layout review helper for INFINITT.
; Draws frames over the detected 2x1 or 1x2 image viewports and copies coords/info.

#NoEnv
#SingleInstance, Force
#Include %A_ScriptDir%\Lib\INFINITT_PACS.ahk

SetBatchLines, -1
SetTitleMatchMode, 2
DetectHiddenWindows, Off
CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen

global VIEWPORT_REVIEW_GUIS := []
global VIEWPORT_REVIEW_FRAME_W := 4
global VIEWPORT_REVIEW_FORCE_LAYOUT := ""

INFINITT_ViewportReview_Draw()
return

F5::INFINITT_ViewportReview_Draw()
F6::
    VIEWPORT_REVIEW_FORCE_LAYOUT := "1x2 left/right"
    INFINITT_ViewportReview_Draw()
return
F7::
    VIEWPORT_REVIEW_FORCE_LAYOUT := "2x1 up/down"
    INFINITT_ViewportReview_Draw()
return
F8::
    VIEWPORT_REVIEW_FORCE_LAYOUT := ""
    INFINITT_ViewportReview_Draw()
return
Esc::ExitApp

INFINITT_ViewportReview_Draw() {
    global VIEWPORT_REVIEW_GUIS, VIEWPORT_REVIEW_FORCE_LAYOUT

    INFINITT_ViewportReview_Clear()

    hwnd := INFINITT_ViewportReview_GetActiveOrLeftmostHwnd()
    if (!hwnd) {
        MsgBox, 48, INFINITT viewport layout review, INFINITT PACS viewer not found.
        return
    }

    WinActivate, ahk_id %hwnd%
    Sleep, 150

    pacs := new INFINITT_PACS(hwnd)
    libViewport := pacs.getViewportControl("image", hwnd)
    candidates := INFINITT_ViewportReview_GetCandidates(pacs, hwnd)
    selected := INFINITT_ViewportReview_SelectTwo(candidates)
    derivedMode := false
    layout := VIEWPORT_REVIEW_FORCE_LAYOUT
    if (selected.Length() = 1) {
        if (!layout)
            layout := INFINITT_ViewportReview_InferCombinedLayout(selected[1])
        selected := INFINITT_ViewportReview_DeriveHalves(selected[1], layout)
        derivedMode := true
    }
    if (!layout)
        layout := INFINITT_ViewportReview_DetectLayout(selected)
    selected := INFINITT_ViewportReview_SortByLayout(selected, layout)

    WinGetPos, winX, winY, winW, winH, ahk_id %hwnd%
    rawList := ""
    selectedList := ""
    halfRangeList := ""
    libPosition := "not matched"
    expectedHalves := []
    if (derivedMode)
        expectedHalves := selected

    for i, c in candidates {
        selectedMark := INFINITT_ViewportReview_IsSelected(c.hwnd, selected) ? " SELECTED" : ""
        libMark := (c.hwnd = libViewport) ? " LIB_IMAGE" : ""
        rawList .= i ". hwnd " c.hwnd selectedMark libMark "`n"
            . "   score " c.score " area " c.area "`n"
            . "   classNN " c.classNN "`n"
            . "   class " c.class "`n"
            . "   text " c.text "`n"
            . "   visible " c.visible " (" c.visibleReason ")`n"
            . "   screen [" c.x "," c.y "," c.w "," c.h "]`n"
            . "   client [" c.cx "," c.cy "," c.cw "," c.ch "]`n"
            . "   acc " c.acc "`n`n"

        if (c.visible && !INFINITT_ViewportReview_IsSelected(c.hwnd, selected) && c.w >= 100 && c.h >= 100)
            INFINITT_ViewportReview_ShowFrame("Candidate" i, "cand " i, c.x, c.y, c.w, c.h, "Aqua", 2)
    }

    if (expectedHalves.Length()) {
        for i, half in expectedHalves {
            position := INFINITT_ViewportReview_PositionName(i, layout)
            halfRangeList .= position " expected half [" half.x "," half.y "," half.w "," half.h "]`n"
            found := false
            for j, c in candidates {
                if (INFINITT_ViewportReview_IsSameSourceCandidate(c, half))
                    continue
                overlapText := INFINITT_ViewportReview_OverlapText(c, half)
                if (overlapText != "") {
                    found := true
                    halfRangeList .= "   candidate " j " hwnd " c.hwnd " visible " c.visible " text " c.text " overlap " overlapText "`n"
                }
            }
            if (!found)
                halfRangeList .= "   no other Afx:b candidates overlap this half`n"
            halfRangeList .= "`n"
        }
    }

    for i, c in selected {
        position := INFINITT_ViewportReview_PositionName(i, layout)
        if (!derivedMode && c.hwnd = libViewport)
            libPosition := position
        else if (derivedMode && c.sourceHwnd = libViewport)
            libPosition := "source combined pane, derived " position
        positionUpper := INFINITT_ViewportReview_PositionUpper(position)
        label := positionUpper " viewport " i " hwnd " c.hwnd
        if (derivedMode)
            label .= " DERIVED"
        color := (i = 1) ? "Lime" : "Yellow"
        INFINITT_ViewportReview_ShowFrame("Selected" i, label, c.x, c.y, c.w, c.h, color, 4)
        INFINITT_ViewportReview_ShowCenterLine("SelectedMid" i, c.x, c.y, c.w, c.h, color)

        selectedList .= position ": hwnd " c.hwnd "`n"
            . "   screen [" c.x "," c.y "," c.w "," c.h "]`n"
            . "   client [" c.cx "," c.cy "," c.cw "," c.ch "]`n"
            . "   center [" Round(c.x + c.w/2) "," Round(c.y + c.h/2) "]`n"
            . "   classNN " c.classNN "`n"
            . "   text " c.text "`n`n"
    }

    if (!selected.Length()) {
        ToolTip, % "No viewport candidates found. Raw candidate count: " candidates.Length(), 20, 20
        SetTimer, INFINITT_ViewportReview_HideTooltip, -8000
        return
    }

    clip =
    (LTrim
        INFINITT viewport layout review
        Window hwnd: %hwnd%
        Window screen: [%winX%,%winY%,%winW%,%winH%]

        Current lib getViewportControl("image"):
        hwnd %libViewport%
        matched position: %libPosition%
        layout: %layout%
        forced layout: %VIEWPORT_REVIEW_FORCE_LAYOUT%
        derived halves mode: %derivedMode%

        Selected viewport positions:
        %selectedList%
        Candidate overlap with expected halves:
        %halfRangeList%
        All Afx:b candidates:
        %rawList%
    )
    Clipboard := clip

    info =
    (LTrim
        INFINITT viewport layout review - copied to clipboard

        F5: redraw
        Esc: exit

        Window: %winX%,%winY% %winW%x%winH%
        Lib image hwnd: %libViewport% (%libPosition%)
        Layout: %layout%
        Forced layout: %VIEWPORT_REVIEW_FORCE_LAYOUT%
        Derived halves mode: %derivedMode%

        F6: force left/right
        F7: force up/down
        F8: auto

        %selectedList%
    )
    ToolTip, %info%, 20, 20
    SetTimer, INFINITT_ViewportReview_HideTooltip, -12000
}

INFINITT_ViewportReview_GetCandidates(pacs, parentHwnd) {
    ret := []
    for k, hwnd in pacs.getViewportControls(parentHwnd) {
        WinGetPos, x, y, w, h, ahk_id %hwnd%
        if (w <= 0 || h <= 0)
            continue

        visibility := INFINITT_ViewportReview_Visibility(parentHwnd, hwnd, x, y, w, h)
        visible := visibility.visible
        class := INFINITT_ViewportReview_WinClass(hwnd)
        classNN := INFINITT_ViewportReview_ControlClassNN(parentHwnd, hwnd)
        text := INFINITT_ViewportReview_ControlText(hwnd)
        acc := INFINITT_ViewportReview_AccOneLine(hwnd)

        VarSetCapacity(pt, 8, 0)
        DllCall("ClientToScreen", "ptr", hwnd, "ptr", &pt)
        cx := NumGet(pt, 0, "int")
        cy := NumGet(pt, 4, "int")
        VarSetCapacity(rc, 16, 0)
        DllCall("GetClientRect", "ptr", hwnd, "ptr", &rc)
        cw := NumGet(rc, 8, "int")
        ch := NumGet(rc, 12, "int")

        area := w * h
        score := area
        if (w < 250 || h < 200)
            score -= 50000000
        if (text ~= "i)Thumnail|Thumbnail|SimpleView")
            score -= 90000000
        if (text ~= "i)WindowPane")
            score += 100000000
        if (acc ~= "i)WindowPane")
            score += 25000000

        ret.Push({hwnd: hwnd, x: x, y: y, w: w, h: h
            , cx: cx, cy: cy, cw: cw, ch: ch
            , area: area, score: score, class: class, classNN: classNN
            , text: text, acc: acc, visible: visible, visibleReason: visibility.reason})
    }
    return ret
}

INFINITT_ViewportReview_SelectTwo(candidates) {
    picked := []
    for i, c in candidates {
        if (!c.visible)
            continue
        if (c.score < 0)
            continue
        INFINITT_ViewportReview_InsertByScore(picked, c)
    }

    selected := []
    Loop, % picked.Length() {
        if (A_Index > 2)
            break
        selected.Push(picked[A_Index])
    }

    return selected
}

INFINITT_ViewportReview_DeriveHalves(c, layout := "") {
    gap := 0
    up := INFINITT_ViewportReview_CloneCandidate(c)
    down := INFINITT_ViewportReview_CloneCandidate(c)

    if (layout = "1x2 left/right") {
        halfW := Floor((c.w - gap) / 2)
        rightW := c.w - halfW - gap

        up.w := halfW
        up.cw := halfW
        up.hwnd := c.hwnd " derived-left"
        up.text := c.text " (derived left half)"
        up.sourceHwnd := c.hwnd

        down.x := c.x + halfW + gap
        down.cx := c.cx + halfW + gap
        down.w := rightW
        down.cw := rightW
        down.hwnd := c.hwnd " derived-right"
        down.text := c.text " (derived right half)"
        down.sourceHwnd := c.hwnd
    } else {
        halfH := Floor((c.h - gap) / 2)
        lowerH := c.h - halfH - gap

        up.h := halfH
        up.ch := halfH
        up.hwnd := c.hwnd " derived-up"
        up.text := c.text " (derived upper half)"
        up.sourceHwnd := c.hwnd

        down.y := c.y + halfH + gap
        down.cy := c.cy + halfH + gap
        down.h := lowerH
        down.ch := lowerH
        down.hwnd := c.hwnd " derived-down"
        down.text := c.text " (derived lower half)"
        down.sourceHwnd := c.hwnd
    }

    return [up, down]
}

INFINITT_ViewportReview_InferCombinedLayout(c) {
    if (c.w > c.h * 1.25)
        return "1x2 left/right"
    if (c.h > c.w * 1.25)
        return "2x1 up/down"

    ; A nearly square combined WindowPane can represent either 2x1 or 1x2.
    ; Keep the previous default for auto mode; use F6/F7 when testing layout changes.
    return "2x1 up/down"
}

INFINITT_ViewportReview_CloneCandidate(c) {
    clone := {}
    for key, value in c
        clone[key] := value
    clone.sourceHwnd := c.hwnd
    return clone
}

INFINITT_ViewportReview_DetectLayout(selected) {
    if (selected.Length() < 2)
        return "single"
    first := selected[1]
    second := selected[2]
    dx := Abs((first.x + first.w / 2) - (second.x + second.w / 2))
    dy := Abs((first.y + first.h / 2) - (second.y + second.h / 2))
    return (dx > dy) ? "1x2 left/right" : "2x1 up/down"
}

INFINITT_ViewportReview_SortByLayout(arr, layout) {
    if (layout = "1x2 left/right")
        return INFINITT_ViewportReview_SortByX(arr)
    return INFINITT_ViewportReview_SortByY(arr)
}

INFINITT_ViewportReview_SortByX(arr) {
    sorted := []
    for i, item in arr {
        if (!sorted.Length()) {
            sorted.Push(item)
            continue
        }
        inserted := false
        for j, other in sorted {
            if (item.x < other.x || (item.x = other.x && item.y < other.y)) {
                sorted.InsertAt(j, item)
                inserted := true
                break
            }
        }
        if (!inserted)
            sorted.Push(item)
    }
    return sorted
}

INFINITT_ViewportReview_PositionName(i, layout) {
    if (layout = "1x2 left/right")
        return (i = 1) ? "left" : "right"
    return (i = 1) ? "up" : "down"
}

INFINITT_ViewportReview_PositionUpper(position) {
    if (position = "left")
        return "LEFT"
    if (position = "right")
        return "RIGHT"
    if (position = "up")
        return "UP"
    return "DOWN"
}

INFINITT_ViewportReview_IsSameSourceCandidate(c, half) {
    if (half.sourceHwnd != "" && c.hwnd = half.sourceHwnd)
        return true
    if (c.hwnd = half.hwnd)
        return true
    return false
}

INFINITT_ViewportReview_OverlapText(c, half) {
    ix1 := INFINITT_ViewportReview_Max(c.x, half.x)
    iy1 := INFINITT_ViewportReview_Max(c.y, half.y)
    ix2 := INFINITT_ViewportReview_Min(c.x + c.w, half.x + half.w)
    iy2 := INFINITT_ViewportReview_Min(c.y + c.h, half.y + half.h)
    iw := ix2 - ix1
    ih := iy2 - iy1
    if (iw <= 0 || ih <= 0)
        return ""
    overlapArea := iw * ih
    cArea := c.w * c.h
    halfArea := half.w * half.h
    return "[" ix1 "," iy1 "," iw "," ih "] cRatio=" Format("{:.3f}", overlapArea / cArea) " halfRatio=" Format("{:.3f}", overlapArea / halfArea)
}

INFINITT_ViewportReview_InsertByScore(ByRef arr, item) {
    if (!arr.Length()) {
        arr.Push(item)
        return
    }
    for i, c in arr {
        if (item.score > c.score) {
            arr.InsertAt(i, item)
            return
        }
    }
    arr.Push(item)
}

INFINITT_ViewportReview_SortByY(arr) {
    sorted := []
    for i, item in arr {
        if (!sorted.Length()) {
            sorted.Push(item)
            continue
        }
        inserted := false
        for j, other in sorted {
            if (item.y < other.y || (item.y = other.y && item.x < other.x)) {
                sorted.InsertAt(j, item)
                inserted := true
                break
            }
        }
        if (!inserted)
            sorted.Push(item)
    }
    return sorted
}

INFINITT_ViewportReview_IsSelected(hwnd, selected) {
    for i, c in selected {
        if (c.hwnd = hwnd)
            return true
    }
    return false
}

INFINITT_ViewportReview_ShowFrame(id, label, x, y, w, h, color, thickness := 3) {
    global VIEWPORT_REVIEW_GUIS

    if (w <= 0 || h <= 0)
        return

    topGui := "VPFrame" id "Top"
    bottomGui := "VPFrame" id "Bottom"
    leftGui := "VPFrame" id "Left"
    rightGui := "VPFrame" id "Right"
    labelGui := "VPFrame" id "Label"
    VIEWPORT_REVIEW_GUIS.Push(topGui)
    VIEWPORT_REVIEW_GUIS.Push(bottomGui)
    VIEWPORT_REVIEW_GUIS.Push(leftGui)
    VIEWPORT_REVIEW_GUIS.Push(rightGui)
    VIEWPORT_REVIEW_GUIS.Push(labelGui)

    INFINITT_ViewportReview_ShowLine(topGui, x, y, w, thickness, color)
    INFINITT_ViewportReview_ShowLine(bottomGui, x, y + h - thickness, w, thickness, color)
    INFINITT_ViewportReview_ShowLine(leftGui, x, y, thickness, h, color)
    INFINITT_ViewportReview_ShowLine(rightGui, x + w - thickness, y, thickness, h, color)

    ly := y - 26
    if (ly < -32000)
        ly := y + h + 4
    Gui, %labelGui%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %labelGui%:Color, Black
    Gui, %labelGui%:Font, s10 c%color% Bold, Consolas
    Gui, %labelGui%:Add, Text, x4 y3, % label " [" x "," y "," w "," h "]"
    Gui, %labelGui%:Show, x%x% y%ly% NoActivate, %labelGui%
}

INFINITT_ViewportReview_ShowCenterLine(id, x, y, w, h, color) {
    global VIEWPORT_REVIEW_GUIS
    lineGui := "VPFrame" id "Center"
    VIEWPORT_REVIEW_GUIS.Push(lineGui)
    INFINITT_ViewportReview_ShowLine(lineGui, x, Round(y + h / 2), w, 2, color)
}

INFINITT_ViewportReview_ShowLine(guiName, x, y, w, h, color) {
    Gui, %guiName%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %guiName%:Color, %color%
    Gui, %guiName%:Show, x%x% y%y% w%w% h%h% NoActivate, %guiName%
}

INFINITT_ViewportReview_ControlClassNN(parentHwnd, controlHwnd) {
    try {
        ret := Control_GetClassNN(parentHwnd, controlHwnd)
        if (ret != "")
            return ret
    }
    return ""
}

INFINITT_ViewportReview_ControlText(hwnd) {
    ControlGetText, text,, ahk_id %hwnd%
    return INFINITT_ViewportReview_OneLine(text)
}

INFINITT_ViewportReview_AccOneLine(hwnd) {
    try acc := Acc_ObjectFromWindow(hwnd)
    catch
        return ""
    if (!IsObject(acc))
        return ""

    role := ""
    name := ""
    state := ""
    childCount := ""
    try role := INFINITT_ViewportReview_OneLine(Acc_Role(acc))
    try name := INFINITT_ViewportReview_OneLine(acc.accName(0))
    try state := INFINITT_ViewportReview_OneLine(Acc_State(acc))
    try childCount := acc.accChildCount
    return "role=" role " name=" name " state=" state " childCount=" childCount
}

INFINITT_ViewportReview_OneLine(text) {
    text := "" text
    text := RegExReplace(text, "[\r\n\t]+", " ")
    text := Trim(text)
    if (StrLen(text) > 160)
        text := SubStr(text, 1, 157) "..."
    return text
}

INFINITT_ViewportReview_WinClass(hwnd) {
    WinGetClass, class, ahk_id %hwnd%
    return class
}

INFINITT_ViewportReview_Visibility(parentHwnd, hwnd, x, y, w, h) {
    reason := ""
    visible := 1

    WinGet, style, Style, ahk_id %hwnd%
    if !(style & 0x10000000)
        visible := 0, reason .= "no WS_VISIBLE; "

    if (!DllCall("IsWindowVisible", "ptr", hwnd))
        visible := 0, reason .= "IsWindowVisible=0; "

    cloaked := 0
    try {
        if (DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 14, "int*", cloaked, "uint", 4) = 0 && cloaked)
            visible := 0, reason .= "DWM cloaked; "
    }

    parentRect := INFINITT_ViewportReview_ClientScreenRect(parentHwnd)
    ix1 := INFINITT_ViewportReview_Max(x, parentRect.x)
    iy1 := INFINITT_ViewportReview_Max(y, parentRect.y)
    ix2 := INFINITT_ViewportReview_Min(x + w, parentRect.x + parentRect.w)
    iy2 := INFINITT_ViewportReview_Min(y + h, parentRect.y + parentRect.h)
    iw := ix2 - ix1
    ih := iy2 - iy1
    if (iw < 100 || ih < 100)
        visible := 0, reason .= "outside active viewer client; "

    if (reason = "")
        reason := "visible, intersects active viewer client [" iw "x" ih "]"
    return {visible: visible, reason: reason}
}

INFINITT_ViewportReview_ClientScreenRect(hwnd) {
    VarSetCapacity(pt, 8, 0)
    DllCall("ClientToScreen", "ptr", hwnd, "ptr", &pt)
    x := NumGet(pt, 0, "int")
    y := NumGet(pt, 4, "int")
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "ptr", hwnd, "ptr", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
    return {x: x, y: y, w: w, h: h}
}

INFINITT_ViewportReview_Min(a, b) {
    return (a < b) ? a : b
}

INFINITT_ViewportReview_Max(a, b) {
    return (a > b) ? a : b
}

INFINITT_ViewportReview_Clear() {
    global VIEWPORT_REVIEW_GUIS
    for _, guiName in VIEWPORT_REVIEW_GUIS {
        try
        Gui, %guiName%:Destroy
    }
    VIEWPORT_REVIEW_GUIS := []
    ToolTip
}

INFINITT_ViewportReview_GetActiveOrLeftmostHwnd() {
    WinGet, activeHwnd, ID, A
    if (INFINITT_ViewportReview_IsPacsViewer(activeHwnd))
        return activeHwnd
    return INFINITT_ViewportReview_GetLeftmostHwnd()
}

INFINITT_ViewportReview_IsPacsViewer(hwnd) {
    return IsInfinittViewerWindow(hwnd)
}

INFINITT_ViewportReview_GetLeftmostHwnd() {
    return FindInfinittViewerHwnd("leftmost", true)
}

INFINITT_ViewportReview_HideTooltip:
    ToolTip
return
