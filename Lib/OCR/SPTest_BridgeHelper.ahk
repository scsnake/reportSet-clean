#Requires AutoHotkey v2.0
#SingleInstance Off
#Include C:\Users\raduser\Documents\reportSet\Lib\OCR\OCR.ahk
SetTimer(ExitApp, 12000)
hwnd := 0x1151704
x := 1527, y := 87, w := 149, h := 66
bmpPath := "C:\Users\raduser\Documents\reportSet\Lib\OCR\debug_roi\20260508224000_C_v2Bridge_cap_rx1527_ry87_w149_h66.bmp"
textPath := "C:\Users\raduser\Documents\reportSet\Lib\OCR\debug_roi\20260508224000_C_v2Bridge_ocrtext.txt"
try {
    result := OCR.FromWindow(hwnd, {lang:"en-US", scale:4, x:x, y:y, w:w, h:h, mode:5})
    FileAppend(result.Text, textPath, "UTF-8")
} catch as e {
    try {
        result := OCR.FromWindow(hwnd, {lang:"en-US", scale:4, x:x, y:y, w:w, h:h, mode:4})
        FileAppend(result.Text, textPath, "UTF-8")
    } catch as e2 {
        FileAppend("ERR: " . e.Message . " / " . e2.Message, textPath, "UTF-8")
    }
}
; PrintWindow capture of viewport client region
hDC := DllCall("GetDC", "Ptr", hwnd, "Ptr")
cr := Buffer(16, 0)
DllCall("GetClientRect", "Ptr", hwnd, "Ptr", cr)
cW := NumGet(cr, 8, "int"), cH := NumGet(cr, 12, "int")
scW := Max(40, w * 4), scH := Max(40, h * 4)
pDC  := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
hBM  := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", cW, "Int", cH, "Ptr")
oBM  := DllCall("SelectObject", "Ptr", pDC, "Ptr", hBM, "Ptr")
DllCall("PrintWindow", "Ptr", hwnd, "Ptr", pDC, "UInt", 3)
pDC2 := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
hBM2 := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", scW, "Int", scH, "Ptr")
oBM2 := DllCall("SelectObject", "Ptr", pDC2, "Ptr", hBM2, "Ptr")
DllCall("SetStretchBltMode", "Ptr", pDC2, "Int", 3)
DllCall("StretchBlt","Ptr",pDC2,"Int",0,"Int",0,"Int",scW,"Int",scH,"Ptr",pDC,"Int",x,"Int",y,"Int",w,"Int",h,"UInt",0x00CC0020)
DllCall("SelectObject", "Ptr", pDC2, "Ptr", oBM2)
DllCall("SelectObject", "Ptr", pDC,  "Ptr", oBM)
DllCall("DeleteObject", "Ptr", hBM)
DllCall("DeleteDC",     "Ptr", pDC)
DllCall("DeleteDC",     "Ptr", pDC2)
DllCall("ReleaseDC",    "Ptr", hwnd, "Ptr", hDC)
si := Buffer(16, 0), NumPut("uint", 1, si)
DllCall("Gdiplus\GdiplusStartup", "Ptr*", &tok:=0, "Ptr", si, "Ptr", 0)
DllCall("Gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBM2, "Ptr", 0, "Ptr*", &pb:=0)
clsid := Buffer(16, 0)
DllCall("ole32\CLSIDFromString", "WStr", "{557cf400-1a04-11d3-9a73-0000f81ef32e}", "Ptr", clsid)
DllCall("Gdiplus\GdipSaveImageToFile", "Ptr", pb, "WStr", "C:\Users\raduser\Documents\reportSet\Lib\OCR\debug_roi\20260508224000_C_v2Bridge_cap_rx1527_ry87_w149_h66.bmp", "Ptr", clsid, "Ptr", 0)
DllCall("Gdiplus\GdipDisposeImage", "Ptr", pb)
DllCall("Gdiplus\GdiplusShutdown", "Ptr", tok)
DllCall("DeleteObject", "Ptr", hBM2)
ExitApp 0
