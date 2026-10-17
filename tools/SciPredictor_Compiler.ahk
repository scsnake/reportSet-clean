; ==============================================================================
; AHK v1 Prediction Dictionary Compiler
; Environment: Windows 7 32-bit Compatible
; Description: Scans multiple AHK scripts (with wildcards) to build a prediction DB.
; ==============================================================================
#NoEnv
SetBatchLines, -1
FileEncoding, UTF-8 ; Ensure we handle special characters correctly

; ==============================================================================
; 1. CONFIGURATION
; ==============================================================================

; [Output] The path where the compiled database will be saved.
OutputDB := A_MyDocuments "\reportSet\words.db"

; [Input] Define your source scripts below.
; Format: FilePattern | Tags
; - FilePattern: Absolute or relative path. Supports wildcards (*).
; - Tags: Comma-separated context tags (optional).
;         These tags allow the predictor to filter words based on current study/modality.
InputConfig = 
(
 %A_MyDocuments%\reportSet\YCH_Enh.ahk   | Common,CT,MR
 %A_MyDocuments%\reportSet\YCH_XR_Enh.ahk   | XR
 %A_MyDocuments%\reportSet\YCH_Mammo_Enh.ahk   | MG
 %A_MyDocuments%\reportSet\YCH_BMD.ahk   | BMD
)

; ==============================================================================
; 2. COMPILATION LOGIC
; ==============================================================================

; GUI Setup for Progress Feedback
Gui, +AlwaysOnTop -MinimizeBox
Gui, Font, s9, Segoe UI
Gui, Add, Text, w400 vStatusText, Initializing...
Gui, Add, Progress, wp h20 vProgressBar cBlue
Gui, Show,, Dictionary Compiler

; The Master Database: DB[Word] = {Freq: Number, Tags: {Tag1:1, Tag2:1}}
DB := {}
FileCount := 0
WordCount := 0

; Clean previous output
FileDelete, %OutputDB%

; Parse the Configuration
Loop, Parse, InputConfig, `n, `r
{
    RuleLine := Trim(A_LoopField)
    
    ; Skip empty lines or comments
    if (RuleLine = "") || (SubStr(RuleLine, 1, 1) = ";")
        continue

    ; Split "Pattern | Tags"
    Parts := StrSplit(RuleLine, "|")
    Pattern := Trim(Parts[1])
    RuleTags := (Parts.MaxIndex() > 1) ? Trim(Parts[2]) : ""

    ; Resolve Wildcards using Loop, Files (Recurse optional)
    Loop, Files, %Pattern%, F 
    {
        CurrentPath := A_LoopFileFullPath
        FileCount++
        
        GuiControl,, StatusText, Scanning: %A_LoopFileName%
        
        FileRead, Content, %CurrentPath%
        ParseContent(Content, RuleTags)
    }
}

; Write to Database
GuiControl,, StatusText, Writing database to disk...
GuiControl,, ProgressBar, 90

Buffer := ""
Counter := 0

For Word, Data in DB {
    ; Flatten the Tags object into a CSV string
    TagString := ""
    For TagName, _ in Data.Tags
        TagString .= TagName . ","
    TagString := RTrim(TagString, ",")
    
    ; Format: Word|Frequency|Tags
    Buffer .= Word . "|" . Data.Freq . "|" . TagString . "`n"
    
    Counter++
    
    ; Write in chunks to keep memory usage low on Win7 32-bit
    if (Mod(Counter, 500) = 0) {
        FileAppend, %Buffer%, %OutputDB%
        Buffer := ""
    }
}

; Flush remaining buffer
if (Buffer != "")
    FileAppend, %Buffer%, %OutputDB%

GuiControl,, ProgressBar, 100
GuiControl,, StatusText, Done! %Counter% unique words from %FileCount% files.
Sleep, 2000
ExitApp

; ==============================================================================
; 3. HELPER FUNCTIONS
; ==============================================================================

ParseContent(ByRef FileContent, Tags) {
    Global DB
    InContinuation := false
    
    ; Loop line by line
    Loop, Parse, FileContent, `n, `r
    {
        Line := Trim(A_LoopField)
        if (Line = "")
            continue
            
        CurrentText := ""
        
        ; --- STATE MACHINE ---
        
        ; 1. Inside Continuation Section (lines between ( and ) )
        if (InContinuation) {
            if (Line = ")") {
                InContinuation := false
                continue
            }
            CurrentText := Line
        }
        
        ; 2. Start of Continuation Section (usually follows Send)
        else if (Line = "(") {
            InContinuation := true
            continue
        }
        
        ; 3. Standard Hotstring: ::key::Expansion
        else if RegExMatch(Line, "Oi)^:.*?:.*?:(.*)", Match) {
            CurrentText := Match.Value(1)
        }
        
        ; 4. Send Command: Send, Text OR SendInput, Text
        else if RegExMatch(Line, "Oi)^\s*Send\w*,?\s+(.*)", Match) {
            CurrentText := Match.Value(1)
        }
        
        ; 5. Function Call: quicksendFunc("key", "Text")
        ; Matches the second quoted string
        else if RegExMatch(Line, "Oi)quicksendFunc\s*\(.*?,?\s*""(.*?)""\)", Match) {
            CurrentText := Match.Value(1)
        }
        
        ; 6. Custom Function Call: sendByClipboard
        ; Matches: sendByClipboard("Text") or sendByClipboard(StringUpperFirst("Text"...))
        else if RegExMatch(Line, "Oi)sendByClipboard\s*\(\s*(?:StringUpperFirst\s*\(\s*)?""(.*?)""", Match) {
            CurrentText := Match.Value(1)
        }
        
        ; --- WORD PROCESSING ---
        
        if (CurrentText != "") {
            ; Remove inline comments
            if (Pos := InStr(CurrentText, ";"))
                CurrentText := SubStr(CurrentText, 1, Pos-1)
                
            ; Replace non-word chars (punctuation) with spaces to isolate words
            ; We keep apostrophes for words like "don't" or "patient's"
            ; Also adding support for Chinese characters (Unicode range 4E00-9FFF) if needed, 
            ; though standard regex \w might not catch them in AHK v1 depending on version.
            ; Using simple replace for common punctuation.
            
            CleanText := RegExReplace(CurrentText, "[^a-zA-Z0-9'\x80-\xFF]", " ")
            
            Loop, Parse, CleanText, %A_Space%
            {
                Word := Trim(A_LoopField)
                
                ; Filter out noise
                if (StrLen(Word) < 2)    ; Skip single letters like "a", "I"
                    continue
                if (Word is number)      ; Skip pure numbers
                    continue
                
                ; Add to Dictionary
                if !DB.HasKey(Word)
                    DB[Word] := {Freq: 0, Tags: {}}
                
                DB[Word].Freq += 1
                
                ; Add Context Tags
                if (Tags != "") {
                    Loop, Parse, Tags, CSV
                    {
                        CleanTag := Trim(A_LoopField)
                        if (CleanTag != "")
                            DB[Word].Tags[CleanTag] := 1
                    }
                }
            }
        }
    }
}