; ==============================================================================
; Library: IsCurrentSessionRDP.ahk
; Classification: Pure Third-Party
; Original Author: AutoHotkey Community
; Origin: AutoHotkey Forum / Public Domain
; License: Public Domain / Forum Free Use
; Source URL: https://www.autohotkey.com/boards/
; ==============================================================================

; Protocol alone can remain RDP while its client is disconnected. Use this
; stricter check for reconnect edges and network work that needs a live client.
IsCurrentSessionRDPConnected() {
    pBuffer := 0
    bytesReturned := 0
    success := DllCall("Wtsapi32.dll\WTSQuerySessionInformation"
        , "Ptr", 0, "UInt", 0xFFFFFFFF, "UInt", 8  ; WTSConnectState
        , "Ptr*", pBuffer, "UInt*", bytesReturned)
    if (success && pBuffer) {
        state := bytesReturned >= 4 ? NumGet(pBuffer+0, 0, "UInt") : -1
        DllCall("Wtsapi32.dll\WTSFreeMemory", "Ptr", pBuffer)
        if (state != 0)  ; WTSActive: user is signed in and connected
            return false
    }
    return IsCurrentSessionRDP()
}

IsCurrentSessionRDP() {
    ; Windows Terminal Services API. This checks the live session protocol,
    ; including cases where the user moved between RDP and Console.
    ; WTS_CURRENT_SERVER_HANDLE = 0, WTS_CURRENT_SESSION = -1,
    ; WTSClientProtocolType = 16. Protocol: 0 = Console, 2 = RDP.
    pBuffer := 0
    bytesReturned := 0
    success := DllCall("Wtsapi32.dll\WTSQuerySessionInformation"
        , "Ptr", 0
        , "UInt", 0xFFFFFFFF
        , "UInt", 16
        , "Ptr*", pBuffer
        , "UInt*", bytesReturned)

    if (success && pBuffer) {
        protocolType := NumGet(pBuffer+0, 0, "UShort")
        DllCall("Wtsapi32.dll\WTSFreeMemory", "Ptr", pBuffer)

        if (protocolType == 2)
            return true
        if (protocolType == 0)
            return false
    }

    SysGet, isRemote, 4096
    if (isRemote)
        return true

    EnvGet, clientName, CLIENTNAME
    if (clientName != "")
        return true

    EnvGet, sessionName, SESSIONNAME
    if (sessionName ~= "i)rdp")
        return true

    return false
}
