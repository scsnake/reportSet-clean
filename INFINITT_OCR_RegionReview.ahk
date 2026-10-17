; AHK v1 standalone ROI review helper for INFINITT OCR regions.
; It draws candidate SP/Img OCR regions and the detected viewport frame.
; It does not click, scroll, or OCR.
; Filled overlays use 70% transparency (30% opacity).

#NoEnv
#SingleInstance, Force
#Include %A_ScriptDir%\Lib\INFINITT_PACS.ahk
#Include %A_ScriptDir%\Lib\IsCurrentSessionRDP.ahk

SetBatchLines, -1
SetTitleMatchMode, 2
DetectHiddenWindows, Off
CoordMode, Mouse, Screen

global REGION_REVIEW_GUIS := []
global REGION_REVIEW_COLORS := ["Red", "Lime", "Yellow", "Aqua", "Fuchsia", "Blue", "White", "Silver"]
global REGION_REVIEW_TRANSPARENT := 77

INFINITT_RegionReview_Draw()
return

F5::INFINITT_RegionReview_Draw()
Esc::ExitApp

INFINITT_RegionReview_Draw() {
    global REGION_REVIEW_GUIS

    INFINITT_RegionReview_Clear()

    hwnd := INFINITT_RegionReview_GetLeftmostHwnd()
    if (!hwnd) {
        MsgBox, 48, INFINITT OCR ROI review, INFINITT PACS viewer not found.
        return
    }

    WinActivate, ahk_id %hwnd%
    Sleep, 200

    pacs := new INFINITT_PACS(hwnd)
    viewport := pacs.getViewportControl("image", hwnd)
    if (!viewport) {
        MsgBox, 48, INFINITT OCR ROI review, INFINITT viewport control not found.
        return
    }

    WinGetPos, winX, winY, winW, winH, ahk_id %hwnd%
    WinGetPos, viewX, viewY, viewW, viewH, ahk_id %viewport%
    viewportClass := INFINITT_RegionReview_WinClass(viewport)
    viewportClassNN := INFINITT_RegionReview_ControlClassNN(hwnd, viewport)
    viewportText := INFINITT_RegionReview_ControlText(viewport)
    viewportAcc := INFINITT_RegionReview_AccSummary(viewport)
    viewportList := ""

    VarSetCapacity(parentPt, 8, 0)
    DllCall("ClientToScreen", "ptr", hwnd, "ptr", &parentPt)
    parentClientX := NumGet(parentPt, 0, "int")
    parentClientY := NumGet(parentPt, 4, "int")

    VarSetCapacity(viewPt, 8, 0)
    DllCall("ClientToScreen", "ptr", viewport, "ptr", &viewPt)
    viewClientX := NumGet(viewPt, 0, "int")
    viewClientY := NumGet(viewPt, 4, "int")
    VarSetCapacity(viewRect, 16, 0)
    DllCall("GetClientRect", "ptr", viewport, "ptr", &viewRect)
    viewClientW := NumGet(viewRect, 8, "int")
    viewClientH := NumGet(viewRect, 12, "int")

    candidates := []

    isRDP := IsCurrentSessionRDP()
    rdpRefViewX := 1347
    rdpRefViewY := 176
    rdpRefViewW := 3022 - 1347
    rdpRefViewH := 1821 - 176
    spRatioSetting := [0, 0.311, 0.111, 0.066]
    imgRatioSetting := [0.923, 0.263, 0.077, 0.056]
    spRatioSettingRDP := [0, 0.0936, 0.0955, 0.0565]
    imgRatioSettingRDP := [0.9248, 0.0559, 0.0752, 0.0419]
    activeSpRatio := isRDP ? spRatioSettingRDP : spRatioSetting
    activeImgRatio := isRDP ? imgRatioSettingRDP : imgRatioSetting
    sessionLabel := isRDP ? "RDP" : "Local"
    rdpViewportCheck := INFINITT_RegionReview_ViewportCheck(viewX, viewY, viewW, viewH, rdpRefViewX, rdpRefViewY, rdpRefViewW, rdpRefViewH)

    ; SP candidates. Yellow is the selected local user-reviewed region.
    INFINITT_RegionReview_Add(candidates, "SP A parentClient+prototypeY", viewX + 3, parentClientY + 336, 136, 71)
    INFINITT_RegionReview_Add(candidates, "SP B viewport+prototypeY", viewX + 3, viewY + 336, 136, 71)
    INFINITT_RegionReview_Add(candidates, "SP C LOCAL selected", 1923, -200, 136, 71)
    INFINITT_RegionReview_Add(candidates, "SP D viewport top", viewX + 3, viewY + 0, 136, 71)
    INFINITT_RegionReview_Add(candidates, "SP E viewport client+prototypeY", viewClientX + 3, viewClientY + 336, 136, 71)
    INFINITT_RegionReview_AddRatio(candidates, "SP RATIO local", viewX, viewY, viewW, viewH, spRatioSetting)
    INFINITT_RegionReview_Add(candidates, "SP RDP selected", 1346, 330, 160, 93)
    INFINITT_RegionReview_AddRatio(candidates, "SP RATIO RDP detected-viewport", viewX, viewY, viewW, viewH, spRatioSettingRDP)
    INFINITT_RegionReview_AddRatio(candidates, "SP RATIO RDP ref-viewport", rdpRefViewX, rdpRefViewY, rdpRefViewW, rdpRefViewH, spRatioSettingRDP)
    INFINITT_RegionReview_AddRatio(candidates, "SP RATIO ACTIVE", viewX, viewY, viewW, viewH, activeSpRatio)

    ; Img candidates for comparison. Img E is the selected user-reviewed region.
    INFINITT_RegionReview_Add(candidates, "IMG A parentClient+prototypeY", viewX + viewW - 163, parentClientY + 271, 163, 55)
    INFINITT_RegionReview_Add(candidates, "IMG B viewport+prototypeY", viewX + viewW - 163, viewY + 271, 163, 55)
    INFINITT_RegionReview_Add(candidates, "IMG C viewport top-right", viewX + viewW - 163, viewY + 0, 163, 55)
    INFINITT_RegionReview_Add(candidates, "IMG D right edge y=SP", viewX + viewW - 163, -200, 163, 55)
    INFINITT_RegionReview_Add(candidates, "IMG E LOCAL selected", 3049, -252, 94, 60)
    INFINITT_RegionReview_AddRatio(candidates, "IMG RATIO local", viewX, viewY, viewW, viewH, imgRatioSetting)
    INFINITT_RegionReview_Add(candidates, "IMG RDP selected", 2897, 268, 126, 69)
    INFINITT_RegionReview_AddRatio(candidates, "IMG RATIO RDP detected-viewport", viewX, viewY, viewW, viewH, imgRatioSettingRDP)
    INFINITT_RegionReview_AddRatio(candidates, "IMG RATIO RDP ref-viewport", rdpRefViewX, rdpRefViewY, rdpRefViewW, rdpRefViewH, imgRatioSettingRDP)
    INFINITT_RegionReview_AddRatio(candidates, "IMG RATIO ACTIVE", viewX, viewY, viewW, viewH, activeImgRatio)

    for k, candidateViewport in pacs.getViewportControls(hwnd) {
        WinGetPos, cvx, cvy, cvw, cvh, % "ahk_id " candidateViewport
        if (cvw < 100 || cvh < 100)
            continue
        selectedMark := (candidateViewport = viewport) ? " SELECTED" : ""
        cvClassNN := INFINITT_RegionReview_ControlClassNN(hwnd, candidateViewport)
        cvClass := INFINITT_RegionReview_WinClass(candidateViewport)
        cvText := INFINITT_RegionReview_ControlText(candidateViewport)
        cvAcc := INFINITT_RegionReview_AccSummary(candidateViewport, 5)
        viewportList .= "    " k ". hwnd " candidateViewport selectedMark "`n"
            . "       ClassNN: " cvClassNN "`n"
            . "       Class: " cvClass "`n"
            . "       Text: " cvText "`n"
            . "       Screen: [" cvx "," cvy "," cvw "," cvh "] area " (cvw*cvh) "`n"
            . cvAcc "`n"
        if (candidateViewport != viewport)
            INFINITT_RegionReview_ShowFrame("ViewportCandidate" k, "viewport cand " k, cvx, cvy, cvw, cvh, "Aqua", 1)
    }

    for i, r in candidates
        INFINITT_RegionReview_ShowBox(i, r.label, r.x, r.y, r.w, r.h, viewX, viewY, viewW, viewH)
    INFINITT_RegionReview_ShowFrame("ViewportWin", "VIEWPORT WinGetPos", viewX, viewY, viewW, viewH, "White", 4)
    INFINITT_RegionReview_ShowFrame("ViewportClient", "VIEWPORT ClientToScreen", viewClientX, viewClientY, viewClientW, viewClientH, "Silver", 2)
    INFINITT_RegionReview_ShowFrame("ViewportRDPRef", "RDP REF viewport", rdpRefViewX, rdpRefViewY, rdpRefViewW, rdpRefViewH, "Red", 3)

    spRel := INFINITT_RegionReview_Relative(candidates[3], viewX, viewY)
    spRatio := INFINITT_RegionReview_Ratio(candidates[3], viewX, viewY, viewW, viewH)
    spRatioRel := INFINITT_RegionReview_Relative(candidates[6], viewX, viewY)
    spRatioActual := INFINITT_RegionReview_Ratio(candidates[6], viewX, viewY, viewW, viewH)
    spRdpRel := INFINITT_RegionReview_Relative(candidates[7], viewX, viewY)
    spRdpRatio := INFINITT_RegionReview_Ratio(candidates[7], viewX, viewY, viewW, viewH)
    spRdpRatioRel := INFINITT_RegionReview_Relative(candidates[8], viewX, viewY)
    spRdpRefRel := INFINITT_RegionReview_Relative(candidates[9], rdpRefViewX, rdpRefViewY)
    spActiveRel := INFINITT_RegionReview_Relative(candidates[10], viewX, viewY)
    spRdpRefRatio := INFINITT_RegionReview_Ratio(candidates[7], rdpRefViewX, rdpRefViewY, rdpRefViewW, rdpRefViewH)

    imgBase := 11
    imgRelA := INFINITT_RegionReview_Relative(candidates[imgBase], viewX, viewY)
    imgRelB := INFINITT_RegionReview_Relative(candidates[imgBase+1], viewX, viewY)
    imgRelC := INFINITT_RegionReview_Relative(candidates[imgBase+2], viewX, viewY)
    imgRelD := INFINITT_RegionReview_Relative(candidates[imgBase+3], viewX, viewY)
    imgRelE := INFINITT_RegionReview_Relative(candidates[imgBase+4], viewX, viewY)
    imgRatioE := INFINITT_RegionReview_Ratio(candidates[imgBase+4], viewX, viewY, viewW, viewH)
    imgRatioRel := INFINITT_RegionReview_Relative(candidates[imgBase+5], viewX, viewY)
    imgRatioActual := INFINITT_RegionReview_Ratio(candidates[imgBase+5], viewX, viewY, viewW, viewH)
    imgRdpRel := INFINITT_RegionReview_Relative(candidates[imgBase+6], viewX, viewY)
    imgRdpRatio := INFINITT_RegionReview_Ratio(candidates[imgBase+6], viewX, viewY, viewW, viewH)
    imgRdpRatioRel := INFINITT_RegionReview_Relative(candidates[imgBase+7], viewX, viewY)
    imgRdpRefRel := INFINITT_RegionReview_Relative(candidates[imgBase+8], rdpRefViewX, rdpRefViewY)
    imgActiveRel := INFINITT_RegionReview_Relative(candidates[imgBase+9], viewX, viewY)
    imgRdpRefRatio := INFINITT_RegionReview_Ratio(candidates[imgBase+6], rdpRefViewX, rdpRefViewY, rdpRefViewW, rdpRefViewH)

    settings =
    (LTrim
        Target viewport hwnd: %viewport%
        Target viewport class: %viewportClass%
        Target viewport ClassNN: %viewportClassNN%
        Target viewport text: %viewportText%
        Target viewport screen: %viewX%,%viewY% %viewW%x%viewH%
        Target viewport client screen: %viewClientX%,%viewClientY% %viewClientW%x%viewClientH%
        RDP reference viewport screen: %rdpRefViewX%,%rdpRefViewY% %rdpRefViewW%x%rdpRefViewH%
        RDP viewport sanity: %rdpViewportCheck%
        Session: %sessionLabel%

        Target viewport accessible object:
        %viewportAcc%

        Candidate Afx:b viewport controls:
        %viewportList%

        LOCAL SP region:
        screen [1923,-200,136,71]
        viewport-relative %spRel%
        viewport-ratio %spRatio%
        local-ratio box relative %spRatioRel%
        production-ratio actual %spRatioActual%

        RDP SP region:
        screen [1346,330,160,93]
        viewport-relative %spRdpRel%
        viewport-ratio %spRdpRatio%
        rdp-ratio box relative %spRdpRatioRel%
        rdp-ref relative %spRdpRefRel%
        rdp-ref ratio from your coords %spRdpRefRatio%

        LOCAL IMG region:
        screen [3049,-252,94,60]
        viewport-relative %imgRelE%
        viewport-ratio %imgRatioE%
        local-ratio box relative %imgRatioRel%
        production-ratio actual %imgRatioActual%

        RDP IMG region:
        screen [2897,268,126,69]
        viewport-relative %imgRdpRel%
        viewport-ratio %imgRdpRatio%
        rdp-ratio box relative %imgRdpRatioRel%
        rdp-ref relative %imgRdpRefRel%
        rdp-ref ratio from your coords %imgRdpRefRatio%

        ACTIVE profile:
        SP relative %spActiveRel%
        IMG relative %imgActiveRel%

        INI:
        INFINITTOCRSPRatio=%spRatio%
        INFINITTOCRImgRatio=%imgRatioE%
        INFINITTOCRSPRatioRDP=%spRdpRatio%
        INFINITTOCRImgRatioRDP=%imgRdpRatio%
        INFINITTOCRSPRatioRDP_from_ref=%spRdpRefRatio%
        INFINITTOCRImgRatioRDP_from_ref=%imgRdpRefRatio%

        Other IMG candidate regions, viewport-relative:
        IMG A parentClient+prototypeY %imgRelA%
        IMG B viewport+prototypeY %imgRelB%
        IMG C viewport top-right %imgRelC%
        IMG D right edge y=SP %imgRelD%
    )
    Clipboard := settings

    info =
    (LTrim
        INFINITT OCR ROI review - settings copied to clipboard

        F5: redraw
        Esc: exit

        Window: %winX%,%winY% %winW%x%winH%
        Parent client origin: %parentClientX%,%parentClientY%
        Viewport: %viewX%,%viewY% %viewW%x%viewH%
        Viewport client: %viewClientX%,%viewClientY% %viewClientW%x%viewClientH%
        RDP ref viewport: %rdpRefViewX%,%rdpRefViewY% %rdpRefViewW%x%rdpRefViewH%
        RDP viewport sanity: %rdpViewportCheck%
        Session: %sessionLabel%

        Active SP ratio box: %spActiveRel%
        Active Img ratio box: %imgActiveRel%

        RDP SP selected: %spRdpRel% ratio %spRdpRatio%
        RDP Img selected: %imgRdpRel% ratio %imgRdpRatio%
    )
    ToolTip, %info%, 20, 20
    SetTimer, INFINITT_RegionReview_HideTooltip, -12000
}

INFINITT_RegionReview_Add(ByRef candidates, label, x, y, w, h) {
    candidates.Push({label: label, x: Round(x), y: Round(y), w: Round(w), h: Round(h)})
}

INFINITT_RegionReview_AddRatio(ByRef candidates, label, viewX, viewY, viewW, viewH, ratio) {
    INFINITT_RegionReview_Add(candidates
        , label
        , viewX + Round(viewW * ratio[1])
        , viewY + Round(viewH * ratio[2])
        , Round(viewW * ratio[3])
        , Round(viewH * ratio[4]))
}

INFINITT_RegionReview_ShowBox(i, label, x, y, w, h, viewX, viewY, viewW, viewH) {
    global REGION_REVIEW_GUIS, REGION_REVIEW_COLORS, REGION_REVIEW_TRANSPARENT

    color := REGION_REVIEW_COLORS[Mod(i - 1, REGION_REVIEW_COLORS.Length()) + 1]
    boxGui := "ROIBox" i
    labelGui := "ROILabel" i
    REGION_REVIEW_GUIS.Push(boxGui)
    REGION_REVIEW_GUIS.Push(labelGui)

    Gui, %boxGui%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %boxGui%:Color, %color%
    Gui, %boxGui%:Show, x%x% y%y% w%w% h%h% NoActivate, %boxGui%
    WinSet, Transparent, %REGION_REVIEW_TRANSPARENT%, %boxGui%

    lx := x
    ly := y - 22
    if (ly < -32000)
        ly := y + h + 2
    Gui, %labelGui%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %labelGui%:Color, Black
    Gui, %labelGui%:Font, s9 c%color%, Consolas
    rel := "[" (x - viewX) "," (y - viewY) "," w "," h "]"
    ratio := INFINITT_RegionReview_RatioText(x - viewX, y - viewY, w, h, viewW, viewH)
    Gui, %labelGui%:Add, Text, x3 y2, % i ". " label " screen [" x "," y "," w "," h "] rel " rel " ratio [" ratio "]"
    Gui, %labelGui%:Show, x%lx% y%ly% NoActivate, %labelGui%
}

INFINITT_RegionReview_ShowFrame(id, label, x, y, w, h, color, thickness := 3) {
    global REGION_REVIEW_GUIS

    if (w <= 0 || h <= 0)
        return

    topGui := "ROIFrame" id "Top"
    bottomGui := "ROIFrame" id "Bottom"
    leftGui := "ROIFrame" id "Left"
    rightGui := "ROIFrame" id "Right"
    labelGui := "ROIFrame" id "Label"
    REGION_REVIEW_GUIS.Push(topGui)
    REGION_REVIEW_GUIS.Push(bottomGui)
    REGION_REVIEW_GUIS.Push(leftGui)
    REGION_REVIEW_GUIS.Push(rightGui)
    REGION_REVIEW_GUIS.Push(labelGui)

    INFINITT_RegionReview_ShowLine(topGui, x, y, w, thickness, color)
    INFINITT_RegionReview_ShowLine(bottomGui, x, y + h - thickness, w, thickness, color)
    INFINITT_RegionReview_ShowLine(leftGui, x, y, thickness, h, color)
    INFINITT_RegionReview_ShowLine(rightGui, x + w - thickness, y, thickness, h, color)

    ly := y - 44
    if (ly < -32000)
        ly := y + h + 4
    Gui, %labelGui%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %labelGui%:Color, Black
    Gui, %labelGui%:Font, s10 c%color% Bold, Consolas
    Gui, %labelGui%:Add, Text, x4 y3, % label " screen [" x "," y "," w "," h "]"
    Gui, %labelGui%:Show, x%x% y%ly% NoActivate, %labelGui%
}

INFINITT_RegionReview_ShowLine(guiName, x, y, w, h, color) {
    Gui, %guiName%:New, +AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, %guiName%:Color, %color%
    Gui, %guiName%:Show, x%x% y%y% w%w% h%h% NoActivate, %guiName%
}

INFINITT_RegionReview_Relative(r, viewX, viewY) {
    return "[" (r.x - viewX) "," (r.y - viewY) "," r.w "," r.h "]"
}

INFINITT_RegionReview_Ratio(r, viewX, viewY, viewW, viewH) {
    return INFINITT_RegionReview_RatioText(r.x - viewX, r.y - viewY, r.w, r.h, viewW, viewH)
}

INFINITT_RegionReview_RatioText(x, y, w, h, viewW, viewH) {
    if (!viewW || !viewH)
        return ""
    return Format("{:.4f},{:.4f},{:.4f},{:.4f}", x/viewW, y/viewH, w/viewW, h/viewH)
}

INFINITT_RegionReview_ControlClassNN(parentHwnd, controlHwnd) {
    try {
        ret := Control_GetClassNN(parentHwnd, controlHwnd)
        if (ret != "")
            return ret
    }
    return ""
}

INFINITT_RegionReview_ControlText(hwnd) {
    ControlGetText, text,, ahk_id %hwnd%
    return INFINITT_RegionReview_OneLine(text)
}

INFINITT_RegionReview_AccSummary(hwnd, maxChildren := 12) {
    out := ""
    try acc := Acc_ObjectFromWindow(hwnd)
    catch e
        return "       Acc: unavailable " e.Message "`n"
    if (!IsObject(acc))
        return "       Acc: unavailable`n"

    rootRole := INFINITT_RegionReview_AccRoleText(acc)
    rootName := INFINITT_RegionReview_AccProp(acc, "Name")
    rootValue := INFINITT_RegionReview_AccProp(acc, "Value")
    rootState := INFINITT_RegionReview_AccStateText(acc)
    try childCount := acc.accChildCount
    catch
        childCount := ""

    out .= "       Acc root: role=" rootRole " name=" rootName " value=" rootValue " state=" rootState " childCount=" childCount "`n"

    try children := Acc_Children(acc)
    catch e
        return out "       Acc children: unavailable " e.Message "`n"
    if (!IsObject(children) || !children.Length())
        return out "       Acc children: none`n"

    shown := 0
    for i, child in children {
        shown++
        if (shown > maxChildren) {
            out .= "       Acc children: ... " (children.Length() - maxChildren) " more`n"
            break
        }
        out .= "       Acc child " i ": " INFINITT_RegionReview_AccNodeSummary(child) "`n"
    }
    return out
}

INFINITT_RegionReview_AccNodeSummary(acc) {
    role := INFINITT_RegionReview_AccRoleText(acc)
    name := INFINITT_RegionReview_AccProp(acc, "Name")
    value := INFINITT_RegionReview_AccProp(acc, "Value")
    state := INFINITT_RegionReview_AccStateText(acc)
    loc := INFINITT_RegionReview_AccLocationText(acc)
    try childCount := acc.accChildCount
    catch
        childCount := ""
    return "role=" role " name=" name " value=" value " state=" state " childCount=" childCount " loc=" loc
}

INFINITT_RegionReview_AccRoleText(acc) {
    try {
        if (ComObjType(acc, "Name") = "IAccessible")
            return INFINITT_RegionReview_OneLine(Acc_Role(acc))
    }
    try {
        if (acc.accRole != "")
            return INFINITT_RegionReview_OneLine(Acc_GetRoleText(acc.accRole))
    }
    return ""
}

INFINITT_RegionReview_AccStateText(acc) {
    try {
        if (ComObjType(acc, "Name") = "IAccessible")
            return INFINITT_RegionReview_OneLine(Acc_State(acc))
    }
    try {
        if (acc.accState != "")
            return INFINITT_RegionReview_OneLine(Acc_GetStateText(acc.accState))
    }
    return ""
}

INFINITT_RegionReview_AccProp(acc, prop) {
    try {
        if (ComObjType(acc, "Name") = "IAccessible")
            val := acc["acc" prop](0)
        else
            val := acc["acc" prop]
        return INFINITT_RegionReview_OneLine(val)
    }
    return ""
}

INFINITT_RegionReview_AccLocationText(acc) {
    try {
        if (ComObjType(acc, "Name") = "IAccessible")
            loc := Acc_Location(acc)
        else {
            acc.accLocation(ComObj(0x4003, &x:=0), ComObj(0x4003, &y:=0), ComObj(0x4003, &w:=0), ComObj(0x4003, &h:=0))
            loc := {x: NumGet(x, 0, "int"), y: NumGet(y, 0, "int"), w: NumGet(w, 0, "int"), h: NumGet(h, 0, "int")}
        }
        if IsObject(loc)
            return "[" loc.x "," loc.y "," loc.w "," loc.h "]"
    }
    return ""
}

INFINITT_RegionReview_OneLine(text) {
    text := "" text
    text := RegExReplace(text, "[\r\n\t]+", " ")
    text := Trim(text)
    if (StrLen(text) > 160)
        text := SubStr(text, 1, 157) "..."
    return text
}

INFINITT_RegionReview_ViewportCheck(x, y, w, h, refX, refY, refW, refH) {
    dx := x - refX
    dy := y - refY
    dw := w - refW
    dh := h - refH
    if (Abs(dx) <= 20 && Abs(dy) <= 20 && Abs(dw) <= 40 && Abs(dh) <= 40)
        return "OK delta [" dx "," dy "," dw "," dh "]"
    return "MISMATCH delta [" dx "," dy "," dw "," dh "]"
}

INFINITT_RegionReview_WinClass(hwnd) {
    WinGetClass, class, ahk_id %hwnd%
    return class
}

INFINITT_RegionReview_Clear() {
    global REGION_REVIEW_GUIS
    for _, guiName in REGION_REVIEW_GUIS {
        try
        Gui, %guiName%:Destroy
    }
    REGION_REVIEW_GUIS := []
    ToolTip
}

INFINITT_RegionReview_GetLeftmostHwnd() {
    return FindInfinittViewerHwnd("leftmost", true)
}

INFINITT_RegionReview_HideTooltip:
    ToolTip
return
