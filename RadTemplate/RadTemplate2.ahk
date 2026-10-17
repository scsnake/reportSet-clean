/*
=======================================================================================
    RADIOLOGY TEMPLATE PARSER - SYNTAX GUIDE
=======================================================================================
    1. Standard Edit Box:
       [Default Text]
       -> Creates a text input.
       -> Options: [Default Text // w200] (Sets width to 200px)

    2. Dropdown / Combobox:
       [Option1|Option2|Option3]
       -> Creates a dropdown.
       -> Metadata: //nl (Uses newline separator in final report)
       -> Metadata: //, (Uses comma separator, default)
       -> Example: [Benign|Malignant // &] (Joins with " & " in report)

    3. Checkboxes (Multi-select):
       {c)Option 1|Option 2|Option 3}
       -> Creates checkboxes.
       -> Default Checked: {c)Option 1//checked|Option 2}

    4. Radio Buttons (Single-select):
       {r)Option 1|Option 2}
       -> Creates radio buttons (only one can be selected).

    5. Variable & Formula Binding:
       // vName      -> Assigns this control to variable "Name"
       // v="10*5"   -> Assigns a formula to this variable.

       Example:
       [10 // vLength] [20 // vWidth] [ // vArea // v="Length * Width"]
       (The third box will auto-calculate based on the first two).

    6. Layout:
       The script attempts to follow the flow of your text file.
       Newlines in the text file = Newlines in the GUI.
=======================================================================================
*/

#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%
#SingleInstance, Force
SetBatchLines, -1
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr") ; Enable Per-Monitor v2 Awareness
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
CoordMode, ToolTip, Screen
SetTitleMatchMode, 2
SetControlDelay, -1
DetectHiddenWindows, On
ComObjError(false)
; CH_RIS IPC: route reads through the autorun owner instead of owning (objprop=0; scalar/getRis* only). See CH_RIS_IPC_HANDOFF.md.
global __CH_RIS_CLIENT := true
#include <RisImpax>
#include <Class_ScrollGUI>
#include <.NetGetControl>
#Include <Edit>
#include <Monster>
#include <ParseArg>

; --- Global Variables ---
global guiHwndFile := []
global thisPID := DllCall("GetCurrentProcessId")
global linelenlim := 120 ; Character limit for flow layout wrapping
global matchArr := []
global varName := []
global AllFormula := []
global GeneratedControls := []
global checkedCheckBox, uncheckedCheckbox, checkedRadio, uncheckedRadio

; --- Initialization ---
GoSub, checkBoxStyle

; --- Arguments Handling ---
mainExe := A_ScriptDir "\..\AutoHotkey.exe"
mainScript := A_IsCompiled ? RegExReplace(A_ScriptFullPath, "i)\.exe$", ".ahk") : A_ScriptFullPath

args := []
if IsFunc("ParseArg")
    args := ParseArg()

if (args.Count() = 0 && A_Args.Length() > 0) {
    for i, arg in A_Args
        args.Push(arg)
}

; Check if a file was passed directly
if (args[1] != "" && FileExist(args[1])) {
    param := args[1]
    goto, parseInput
}

; --- Main Selection GUI ---
Gui, +HwndtemplateListHwnd
Gui, 1:Font, s10, Verdana
Gui, 1:-Resize

templateList := ""
rootLen := StrLen(A_ScriptDir) + 2

Loop, *.txt, 0, 1
{
    if (A_LoopFileName != "ReadMe.txt") {
        relativePath := SubStr(A_LoopFileLongPath, rootLen)
        templateList .= relativePath "|"
    }
}

Gui, 1:Add, ListView, vLS gLV_Click AltSubmit w500 h%A_ScreenHeight%, Folder|File
Gui, 1:Default
LV_ModifyCol(1, 150)
LV_ModifyCol(2, 350)

Loop, Parse, templateList, |
{
    if (A_LoopField = "")
        continue
    RegExMatch(A_LoopField, "s)(.*?)\\?([^\\]+)\.txt", m)
    LV_Add("", m1, m2)
}

guiHeight := A_ScreenHeight - 100
GuiControl, Move, LS, h%guiHeight%
Gui, 1:Show, AutoSize, Radiology Template
return

; --- Selection GUI Events ---
LV_Click:
    if (A_GuiEvent = "DoubleClick" && A_EventInfo) {
        LV_GetText(Folder, A_EventInfo, 1)
        LV_GetText(File, A_EventInfo, 2)

        targetPath := A_ScriptDir "\" Folder (Folder ? "\" : "") File ".txt"

        if FileExist(targetPath) {
            LaunchRadTemplate(mainExe, mainScript, targetPath)
        }
    }
return

; --- Styles ---
checkBoxStyle:
    ; Try to read from INI, fallback to standard symbols if missing
    IniRead, checkedCheckBox, RadTemplate.ini, Settings, checkedCheckBox, [x]
    IniRead, uncheckedCheckbox, RadTemplate.ini, Settings, uncheckedCheckbox, [ ]
    IniRead, checkedRadio, RadTemplate.ini, Settings, checkedRadio, (x)
    IniRead, uncheckedRadio, RadTemplate.ini, Settings, uncheckedRadio, ( )
return

tabToSpaces:
    template := RegExReplace(template, "\t", "    ")
return

; --- Parsing Entry Point ---
parseInput:
    FileRead, template, % param
    GoSub, tabToSpaces
    GoSub, BuildGui
return

BuildGui:
    SysGet, workArea, MonitorWorkArea
    workAreaWidth := workAreaRight - workAreaLeft
    workAreaHeight := workAreaBottom - workAreaTop
    templateGuiHeight := workAreaHeight - 80
    if (templateGuiHeight < 300)
        templateGuiHeight := workAreaHeight
    templateGuiX := workAreaLeft
    templateGuiY := workAreaTop

    Gui, 2:New, +HwndtemplateHwnd +Resize +Label2GUI -DPIScale
    Gui, 2:Color, FFFFFF ; Set clean white background
    Gui, 2:Default
    Gui, 2:Font, s10, Segoe UI

    guiHwndFile[templateHwnd] := param
    GroupAdd, MyGui, % "ahk_id " templateHwnd

    i := 0, j := 1
    match := "", matchArr := []
    matchArr[1,1] := 1

    lineLen := 0
    checkBoxCount := 0, radioBoxCount := 0
    varName := []

    ; --- Regex Loop ---
    while (i := RegExMatch(template, "is)\[(.*?)\]|\{(.*?)\}", match, j)) {

        ; 1. Handle Preceding Text
        txt := SubStr(template, j, i - j)
        GoSub, textParser

        ; 2. Determine Type
        rawContent := match1 ? match1 : match2
        isBrace := (match2 != "")

        boxType := ""
        if (isBrace) {
            if RegExMatch(rawContent, "i)^(c|r)\)(.*)", mType) {
                boxType := (mType1 = "c") ? "checkbox" : "radio"
                listContent := mType2
            } else {
                listContent := rawContent
                boxType := InStr(listContent, "|") ? "radio" : "checkbox"
            }
        } else {
            listContent := rawContent
        }

        matchArr[A_Index, 2] := i - 1

        ; 3. Parse Metadata
        metaData := ""
        cleanList := listContent

        if RegExMatch(listContent, "s)\/\/(.*)$", meta) {
            metaData := meta1
            cleanList := SubStr(listContent, 1, StrLen(listContent) - StrLen(meta))
        }

        thisVarName := "%"
        thisFormula := ""

        if RegExMatch(metaData, "\bv(\w+)\b", mv)
            thisVarName := mv1

        if RegExMatch(metaData, "s)\bv=""([^""]+)""", mf) || RegExMatch(metaData, "s)\bv=([^ ]+)", mf)
            thisFormula := mf1

        cleanList := RegExReplace(cleanList, "^\s+|\s+$")

        ; 4. Generate Controls
        if (boxType != "") {
            matchArr[A_Index, 4] := boxType
            controlIDs := ""
            StringReplace, cleanList, cleanList, ||, `n, All

            Loop, Parse, cleanList, `n
            {
                currentRow := A_LoopField
                if (currentRow = "")
                    continue
                Loop, Parse, currentRow, |
                {
                    item := A_LoopField
                    if (item = "")
                        continue

                    isChecked := 0
                    if RegExMatch(item, "i)(.*)//(.*)", itemMeta) {
                        item := itemMeta1
                        if InStr(itemMeta2, "checked")
                            isChecked := 1
                    }

                    itemLen := StrLen(item) + 5
                    if (lineLen + itemLen > linelenlim || RegExMatch(txt, "[\r\n]$") || (A_Index=1 && txt=""))
                        pos := "xm", lineLen := itemLen
                    else
                        pos := "x+5 yp", lineLen += itemLen

                    if (boxType = "checkbox") {
                        checkBoxCount++
                        cVar := "cb" checkBoxCount
                        Gui, 2:Add, Checkbox, v%cVar% %pos% %isChecked% gValChanged, %item%
                        varName[thisVarName="%" ? "%" cVar : thisVarName] := {var: cVar, formula: thisFormula}
                        controlIDs .= cVar ","
                    } else {
                        radioBoxCount++
                        rVar := "rb" radioBoxCount
                        groupOpt := (A_Index = 1) ? "Group" : ""
                        Gui, 2:Add, Radio, v%rVar% %pos% %groupOpt% gValChanged, %item%
                        if (thisVarName != "%")
                            varName[thisVarName] := {var: rVar, formula: thisFormula}
                        controlIDs .= rVar ","
                    }
                }
            }
            matchArr[A_Index, 3] := controlIDs

        } else if InStr(cleanList, "|") {
            matchArr[A_Index, 4] := "combobox"

            delmt := ", "
            if RegExMatch(metaData, "i)^(\W\&?|nl) ?", dSettings)
                matchArr[A_Index, 5] := dSettings1

            maxW := 0
            Loop, Parse, cleanList, |
                if (StrLen(A_LoopField) > maxW)
                    maxW := StrLen(A_LoopField)

            ctrlW := (maxW * 8) + 30
            pos := (RegExMatch(txt, "[\r\n]$")) ? "xm" : "x+5 yp-4"
            cVar := "var" A_Index

            Gui, 2:Add, ComboBox, v%cVar% %pos% w%ctrlW% h24 gValChanged, %cleanList%
            matchArr[A_Index, 3] := cVar
            varName[thisVarName="%" ? "%" cVar : thisVarName] := {var: cVar, formula: thisFormula}
            lineLen += (ctrlW / 8)

        } else {
            matchArr[A_Index, 4] := "edit"
            cVar := "var" A_Index
            width := "w100"
            if RegExMatch(metaData, "i)w(\d+)", wMatch)
                width := "w" wMatch1

            pos := (RegExMatch(txt, "[\r\n]$")) ? "xm" : "x+5 yp-4"
            Gui, 2:Add, Edit, v%cVar% %pos% %width% h24 -Multi gValChanged, %cleanList%
            matchArr[A_Index, 3] := cVar
            varName[thisVarName="%" ? "%" cVar : thisVarName] := {var: cVar, formula: thisFormula}
            lineLen += 15
        }

        j := i + StrLen(match)
        matchArr[A_Index + 1, 1] := j
    }

    txt := SubStr(template, j)
    GoSub, textParser
    matchArr[matchArr.MaxIndex(), 2] := StrLen(template)

    Gui, 2:Add, Button, gSubmitForm xs y+20, Copy to Clipboard
    Gui, 2:Add, Button, gSubmitRis x+10, To RIS
    Gui, 2:Add, Button, gResetForm x+50, Reset
    Gui, 2:Add, Text, xm h120 w10, % " "

    guiTitle := RegExReplace(param, "^.*\\", "")

    Global SG1 := New ScrollGUI(templateHwnd, 0, templateGuiHeight, "+Resize +MinSize400x300 +Label2GUI -DPIScale", 3, 6)
    SG1.SetLine(2, 30)
    SG1.Show(guiTitle, "x" templateGuiX " y" templateGuiY)
    SG1.AdjustToChild()

    GoSub, fillExamDate
    GoSub, parseFormulaInitial
return

textParser:
    Loop, Parse, txt, `n, `r
    {
        currentLine := A_LoopField
        if (A_Index > 1) {
            Gui, 2:Add, Text, xm y+10 h0, ; Added vertical spacing
            lineLen := 0
        }
        if (currentLine = "")
            continue
        Gui, 2:Add, Text, x+5, %currentLine%
        lineLen += StrLen(currentLine)
        if (lineLen > linelenlim) {
            Gui, 2:Add, Text, xm h0,
            lineLen := 0
        }
    }
return

; --- Formula Logic ---
parseFormulaInitial:
    AllFormula := {}
    for name, data in varName {
        if (data.formula != "") {
            rawFormula := data.formula
            for otherName, otherData in varName {
                if (!InStr(otherName, "%") && RegExMatch(rawFormula, "\b" otherName "\b")) {
                    rawFormula := RegExReplace(rawFormula, "\b" otherName "\b", otherData.var)
                }
            }
            AllFormula[data.var] := rawFormula
        }
    }
return

ValChanged:
    SetTimer, UpdateFormulaExecute, -300
return

UpdateFormulaExecute:
    Gui, 2:Submit, NoHide
    for targetVar, formula in AllFormula {
        currentFormula := formula
        canEvaluate := true
        for name, data in varName {
            ctrlID := data.var
            val := %ctrlID%
            if (val = "" && RegExMatch(currentFormula, "\b" ctrlID "\b")) {
                canEvaluate := false
                break
            }
            if val is number
                currentFormula := RegExReplace(currentFormula, "\b" ctrlID "\b", val)
            else
                currentFormula := RegExReplace(currentFormula, "\b" ctrlID "\b", """" val """")
        }
        if (canEvaluate && IsFunc("Eval")) {
            try {
                result := Eval(currentFormula)
                if (result != "") {
                    GuiControl, 2:, %targetVar%, %result%
                    %targetVar% := result
                }
            }
        }
    }
return

; --- Form Submission & Spacing Logic ---
SubmitForm:
    Gui, 2:Submit, NoHide
    export := ""

    if (matchArr.MaxIndex() < 1) {
        Clipboard := template
        GoSub, ToolTipCopied
        return
    }

    Loop, % matchArr.MaxIndex()
    {
        ; 1. Append static text
        tStart := matchArr[A_Index, 1]
        tEnd := matchArr[A_Index, 2]
        export .= SubStr(template, tStart, tEnd - tStart + 1)

        ; 2. Append Control Value
        cType := matchArr[A_Index, 4]
        cID := matchArr[A_Index, 3]
        valStr := ""

        if (cType = "checkbox") {
            Loop, Parse, cID, `,
            {
                if (A_LoopField = "")
                    continue
                GuiControlGet, bVal,, %A_LoopField%
                GuiControlGet, bText,, %A_LoopField%, Text
                if (bVal)
                    valStr .= checkedCheckBox " " bText " "
                ; else (Uncomment below to show empty checkboxes)
                ;   valStr .= uncheckedCheckbox " " bText " "
            }
        } else if (cType = "radio") {
            Loop, Parse, cID, `,
            {
                if (A_LoopField = "")
                    continue
                GuiControlGet, bVal,, %A_LoopField%
                GuiControlGet, bText,, %A_LoopField%, Text
                if (bVal)
                    valStr .= checkedRadio " " bText " "
            }
        } else if (cType = "combobox" || cType = "listbox") {
            valRaw := %cID%
            delmtSetting := matchArr[A_Index, 5]
            sep := ", "
            if InStr(delmtSetting, "nl")
                sep := "`n"
            else if RegExMatch(delmtSetting, "^\W", m)
                sep := m
            valStr := StrReplace(valRaw, "|", sep)
        } else {
            valStr := %cID%
        }

        export .= valStr
    }

    lastIndex := matchArr.MaxIndex()
    export .= SubStr(template, matchArr[lastIndex, 1])

    ; --- SMART SPACING CLEANUP ---
    export := SmartSpacing(export)

    Clipboard := export
    GoSub, ToolTipCopied
return

SmartSpacing(str) {
    ; 1. Collapse multiple horizontal spaces (tabs/spaces) into a single space
    ;    We use [ \t] instead of \s to preserve newlines.
    str := RegExReplace(str, "[ \t]+", " ")

    ; 2. Remove space before punctuation (.,:;!?)
    ;    Example: "Tumor size is 5 cm ." -> "Tumor size is 5 cm."
    str := RegExReplace(str, " ([.,:;!\?])", "$1")

    ; 3. Clean up spaces around newlines
    ;    Remove space at end of line
    str := RegExReplace(str, " +(\r|\n)", "$1")
    ;    Remove space at start of line
    str := RegExReplace(str, "(\r|\n) +", "$1")

    ; 4. Fix specific math symbols
    str := StrReplace(str, "≤", "≦")
    str := StrReplace(str, "≥", "≧")

    return str
}

LaunchRadTemplate(mainExe, mainScript, templateFile := "") {
    if !FileExist(mainExe) {
        MsgBox, 16, , % "Launcher not found:`n" mainExe
        return false
    }
    if !FileExist(mainScript) {
        MsgBox, 16, , % "Script not found:`n" mainScript
        return false
    }
    cmd := """" mainExe """ """ mainScript """"
    if (templateFile != "")
        cmd .= " """ templateFile """"
    Run, % cmd
    return true
}

SubmitRis:
    GoSub, SubmitForm
    if IsFunc("RisOpened") {
        risInfo := RisOpened()
        if (risInfo[1] != 2)
            return
        targetHwnd := risInfo[2]
        risReports := getRisReports(targetHwnd)
        RegExMatch(export, "is)^(.*?)[\s\r\n]*(?:Impression\W*(.*))?$", parts)
        ControlSetText,, % parts1, % "ahk_id " risReports[1,1]
        if (risReports[1,2])
            ControlSetText,, % parts2, % "ahk_id " risReports[1,2]
        WinActivate, % "ahk_id " targetHwnd
    }
return

ResetForm:
    MsgBox, 52, Reset, Reload template?
    IfMsgBox, Yes
    {
        Gui, 2:Destroy
        GoSub, parseInput
    }
return

fillExamDate:
return

ToolTipCopied:
    ToolTip, Copied to Clipboard!
    SetTimer, RemoveToolTip, -2000
return

RemoveToolTip:
    ToolTip
return

2GUISize:
    if IsObject(SG1)
        SG1.Size(A_GuiWidth, A_GuiHeight)
return

2GuiClose:
    Gui, 2:Destroy
return

GuiClose:
ExitApp
return
