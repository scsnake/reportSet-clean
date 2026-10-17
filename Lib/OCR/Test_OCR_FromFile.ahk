#Requires AutoHotkey v2.0
#Include C:\Users\raduser\Documents\reportSet\Lib\OCR\OCR.ahk

baseDir := A_ScriptDir
outFile := baseDir "\ocr_from_file_results.txt"
bmpFiles := [
    baseDir "\debug_capture_print.bmp",
    baseDir "\debug_capture_screen.bmp",
]

tests := [
    {name: "plain_enUS", opts: {lang: "en-US"}},
    {name: "gray_enUS", opts: {lang: "en-US", grayscale: 1}},
    {name: "invert_enUS", opts: {lang: "en-US", invertcolors: 1}},
    {name: "gray_invert_enUS", opts: {lang: "en-US", grayscale: 1, invertcolors: 1}},
    {name: "scaled2_enUS", opts: {lang: "en-US", scale: 2}},
    {name: "scaled4_enUS", opts: {lang: "en-US", scale: 4}},
    {name: "gray_invert_scaled4_enUS", opts: {lang: "en-US", grayscale: 1, invertcolors: 1, scale: 4}},
]

if FileExist(outFile)
    FileDelete(outFile)
FileAppend("START`n", outFile, "UTF-8")

for bmp in bmpFiles {
    FileAppend("FILE: " bmp "`n", outFile, "UTF-8")
    if !FileExist(bmp) {
        FileAppend("  missing`n`n", outFile, "UTF-8")
        continue
    }

    for test in tests {
        try {
            result := OCR.FromFile(bmp, test.opts)
            text := IsObject(result) ? result.Text : ""
            text := StrReplace(text, "`r", "\r")
            text := StrReplace(text, "`n", "\n")
            FileAppend("  " test.name ": [" text "]`n", outFile, "UTF-8")
        } catch as e {
            FileAppend("  " test.name ": ERROR [" Type(e) "] " e.Message "`n", outFile, "UTF-8")
        }
    }
    FileAppend("`n", outFile, "UTF-8")
}
