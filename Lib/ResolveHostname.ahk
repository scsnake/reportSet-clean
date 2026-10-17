; ==============================================================================
; Library: ResolveHostname.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

ResolveHostname(hostname)
{
    VarSetCapacity(WSADATA, 394 + (A_PtrSize - 2) + A_PtrSize, 0)
    if (DllCall("ws2_32\WSAStartup", "ushort", 0x0202, "ptr", &WSADATA) != 0)
        return "WSAStartup failed", DllCall("ws2_32\WSACleanup")

    VarSetCapacity(hints, 16 + 4 * A_PtrSize, 0)
    NumPut(2, hints, 4, "int") && NumPut(1, hints, 8, "int") && NumPut(6, hints, 12, "int")
    if (DllCall("ws2_32\getaddrinfo", "astr", hostname, "ptr", 0, "ptr", &hints, "ptr*", result))
        return "getaddrinfo failed with error: " DllCall("ws2_32\WSAGetLastError"), DllCall("ws2_32\WSACleanup")

    addr := result, IPList := []
    while (addr) {
        ipaddr := DllCall("ws2_32\inet_ntoa", "uint", NumGet(NumGet(addr+0, 16 + 2 * A_PtrSize) + 4, 0, "uint"), "astr")
        IPList[A_Index] := ipaddr, addr := NumGet(addr+0, 16 + 3 * A_PtrSize)
    }
    return IPList, DllCall("ws2_32\WSACleanup")
}