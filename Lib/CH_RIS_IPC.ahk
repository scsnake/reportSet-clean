; CH_RIS_IPC.ahk
; Shared protocol layer for the single-owner CH_RIS bridge.
;
; Design (see ych_refactor_worktree\CH_RIS_Mechanism.md, "Recommended Target Architecture"):
;   - Exactly one process (the OWNER) drives the RIS IE COM page and hosts a hidden
;     listener window titled CH_RIS_SERVER. It loads Lib\CH_RIS_Server.ahk.
;   - Every other (CLIENT) script sends commands instead of touching IE COM. It loads
;     Lib\CH_RIS_Client.ahk.
;
; Transport:
;   - Request : WM_COPYDATA (0x4A) carrying a JSON string {id, cmd, args, resp}.
;               (WM_COPYDATA is the only message that safely marshals a buffer across
;                processes, so we namespace it with dwData = CH_RIS_DW.)
;   - Reply   : a small JSON temp file at resp=%TEMP%\ch_ris_resp_<id>.json. The owner
;               writes it after running the command on its own main thread; the client
;               polls for it. This avoids the cross-process SendMessage reply deadlock.

#include <WM_COPYDATA>
#include <JXON>
#include <DebugLog>

global CH_RIS_SERVER_TITLE := "CH_RIS_SERVER"   ; hidden listener window title
global CH_RIS_DW           := 0x43544852          ; dwData namespace, "CHR"

; Unique, filesystem-safe request id (tick + pid + per-process counter).
CH_RIS_IPC_NewId() {
    static n := 0
    return A_TickCount "_" DllCall("GetCurrentProcessId") "_" (++n)
}

CH_RIS_IPC_RespPath(id) {
    return A_Temp "\ch_ris_resp_" id ".json"
}

; Write a reply object to its temp file atomically (write .tmp, then move into place).
CH_RIS_IPC_WriteResp(path, obj) {
    tmp := path ".tmp"
    try FileDelete, % tmp
    s := Jxon_Dump(obj)
    try FileAppend, % s, % tmp, UTF-8
    try FileMove, % tmp, % path, 1
}

; Read + consume a reply temp file. Returns the parsed object, or "" if absent/bad.
CH_RIS_IPC_ReadResp(path) {
    if !FileExist(path)
        return ""
    raw := ""
    try FileRead, raw, % path
    try FileDelete, % path
    if (raw = "")
        return ""
    try return Jxon_Load(raw)
    return ""
}
