#Requires AutoHotkey v2.0
;#NoTrayIcon
#SingleInstance Off
#Warn All, Stdout
#ErrorStdOut "UTF-8"

/**
 * RadTemplate v2.0 (Ported to AHK v2)
 * Based on original scsnake@gmail.com v1 script
 */

SetWorkingDir(A_ScriptDir)
DetectHiddenWindows(true)
SetTitleMatchMode(2)

; --- Global Variables ---
global TemplateText := ""
global MatchArr := []
global Controls := Map()
global VarNameMap := Map()
global AllFormula := Map()

; --- Main Entry ---
Main()

Main() {
    global templateListHwnd, LS

    ; Parse Arguments
    if A_Args.Length > 0 && FileExist(A_Args[1]) {
        ShowTemplateGui(A_Args[1])
        return
    }

    ; List View of Templates
    MyGui := Gui("+Resize", "Radiology Template Selection")
    MyGui.SetFont("s10", "Verdana")

    global LS := MyGui.Add("ListView", "vLS r20 w500", ["Folder", "File"])
    LS.OnEvent("DoubleClick", LS_DoubleClick)

    PopulateTemplateList(LS)

    MyGui.Show()
}

PopulateTemplateList(LV) {
    loop files, A_ScriptDir "\*.txt", "R" {
        if A_LoopFileName == "ReadMe.txt"
            continue

        relPath := SubStr(A_LoopFileFullPath, StrLen(A_ScriptDir) + 2)
        if RegExMatch(relPath, "s)(.*?)\\?([^\\]+)\.txt", &m) {
            LV.Add("", m[1], m[2])
        }
    }
    LV.ModifyCol(1, 150)
    LV.ModifyCol(2, 350)
}

LS_DoubleClick(LV, RowNumber) {
    if RowNumber == 0
        return

    folder := LV.GetText(RowNumber, 1)
    fileName := LV.GetText(RowNumber, 2)
    fullPath := A_ScriptDir "\" (folder ? folder "\" : "") fileName ".txt"

    if FileExist(fullPath) {
        if A_IsCompiled
            Run('"' A_ScriptFullPath '" "' fullPath '"')
        else
            Run('"' A_AhkPath '" "' A_ScriptFullPath '" "' fullPath '"')
    }
}

ShowTemplateGui(TemplatePath) {
    global TemplateText, MatchArr, Controls, VarNameMap

    TemplateText := FileRead(TemplatePath)
    TemplateText := StrReplace(TemplateText, "`t", "    ") ; Tab to spaces

    SplitPath(TemplatePath, , , , &OutNameNoExt)
    Title := OutNameNoExt

    MyGui := Gui("+Resize", Title)
    MyGui.SetFont("s9", "Verdana")
    MyGui.OnEvent("Size", Gui_Size)
    MyGui.OnEvent("Close", (*) => ExitApp())

    ; Main Scrollable Area Container
    ; Note: Implementing a full Scrollable GUI in v2 without external libs
    ; often involves putting controls in a large child GUI or using an ActiveX window.
    ; For this port, we will use a Fixed Footer for Buttons.

    GenerateControls(MyGui)

    ; Fixed Footer Buttons
    MyGui.SetFont("s10", "Verdana")
    global BtnClipboard := MyGui.Add("Button", "Default w120 h40", "To Clipboard")
    BtnClipboard.OnEvent("Click", (*) => SubmitReport("clipboard"))

    global BtnRis := MyGui.Add("Button", "x+20 w120 h40", "To RIS")
    BtnRis.OnEvent("Click", (*) => SubmitReport("ris"))

    global BtnReset := MyGui.Add("Button", "x+40 w120 h40", "Reset")
    BtnReset.OnEvent("Click", (*) => Reload())

    MyGui.Show("w800 h600")
}

GenerateControls(GuiObj) {
    global TemplateText, MatchArr, Controls, VarNameMap

    Pos := 1
    loop {
        ; Find next placeholder
        Found := RegExMatch(TemplateText, "is)\[(.*?)\]|\{(.*?)\}", &m, Pos)
        if !Found {
            ; Remaining text
            AddText(GuiObj, SubStr(TemplateText, Pos))
            break
        }

        ; Text before placeholder
        AddText(GuiObj, SubStr(TemplateText, Pos, Found - Pos))

        ; Process placeholder
        Placeholder := m[1] ? m[1] : m[2]
        ProcessPlaceholder(GuiObj, Placeholder)

        Pos := Found + m.Len
    }
}

AddText(GuiObj, Content) {
    if Content == ""
        return

    loop parse, Content, "`n", "`r" {
        if A_LoopField == ""
            continue
        GuiObj.Add("Text", "xm", A_LoopField)
    }
}

ProcessPlaceholder(GuiObj, Content) {
    ; Basic parsing of [] or {}
    if InStr(Content, "|") {
        ; ListBox or ComboBox
        items := StrSplit(Content, "|")
        if InStr(Content, "{") ; Simple heuristic for ListBox if it was {} in v1
            ctrl := GuiObj.Add("ListBox", "x+5 r3 Multi", items)
        else
            ctrl := GuiObj.Add("ComboBox", "x+5", items)
    } else {
        ; Edit
        ctrl := GuiObj.Add("Edit", "x+5 w150", Content)
    }
}

Gui_Size(thisGui, MinMax, Width, Height) {
    if MinMax == -1 ; Minimized
        return

    ; Anchor buttons to bottom
    BtnY := Height - 60
    BtnClipboard.Move(, BtnY)
    BtnRis.Move(, BtnY)
    BtnReset.Move(, BtnY)
}

SubmitReport(Target) {
    ; In a real port, we'd iterate through MatchArr and build 'export'
    ; For this minimal port demonstration:
    MsgBox("Submit to " Target " (Logic to be implemented based on full v1 parser)")

}

SplitPath_Obj(Path) {
    SplitPath(Path, &OutFileName, &OutDir, &OutExtension, &OutNameNoExt, &OutDrive)
    return { name: OutNameNoExt, dir: OutDir, ext: OutExtension, drive: OutDrive, full: OutFileName }
}
