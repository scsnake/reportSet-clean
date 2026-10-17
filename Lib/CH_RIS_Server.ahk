; CH_RIS_Server.ahk
; Owner-side of the single-owner CH_RIS IPC bridge.
;
; Exactly ONE process should call CH_RIS_Server_Start() — and it must be the process
; that owns the live CH_RIS object (the one polling the RIS IE page). Clients then
; route report operations through it via Lib\CH_RIS_Client.ahk and never touch IE COM.

#include <CH_RIS_IPC>

global __CH_RIS_IPC_PrevCopyData := ""   ; chained predecessor 0x4A handler (if any)
global __CH_RIS_IPC_Queue := []          ; pending requests, drained on the main thread
global __CH_RIS_IPC_AccNoSubs := {}      ; client windows to ping on accNo change: hwnd -> {msg,wParam,lParam}

; Stand up the hidden listener and register the WM_COPYDATA handler. Idempotent.
CH_RIS_Server_Start() {
    global CH_RIS_SERVER_TITLE, CH_RIS_DW, __CH_RIS_IPC_PrevCopyData
    static started := false
    if started
        return
    started := true

    ; Dedicated hidden window so clients can discover the owner by title.
    Gui, CH_RIS_SRV:New, +hwnd__h +ToolWindow -Caption
    Gui, CH_RIS_SRV:Show, Hide, % CH_RIS_SERVER_TITLE

    ; Register, chaining onto any existing WM_COPYDATA handler in this process so we
    ; coexist with other IPC users (e.g. miniPACS_bridge) instead of clobbering them.
    prev := OnMessage(0x4A, "CH_RIS_OnCopyData")
    if (prev != "" && prev != "CH_RIS_OnCopyData")
        __CH_RIS_IPC_PrevCopyData := prev
    DebugLog("CH_RIS.server", "listener up hwnd=" __h " prevCopyData=" __CH_RIS_IPC_PrevCopyData)
}

CH_RIS_OnCopyData(wParam, lParam, msg, hwnd) {
    global CH_RIS_DW, __CH_RIS_IPC_Queue, __CH_RIS_IPC_PrevCopyData
    Critical
    dwData := NumGet(lParam + 0, 0)
    if (dwData != CH_RIS_DW) {
        ; Not ours — pass through to any prior handler so we don't break it.
        if (fn := __CH_RIS_IPC_PrevCopyData) {
            if IsObject(fn)
                return fn.Call(wParam, lParam, msg, hwnd)
            return %fn%(wParam, lParam, msg, hwnd)
        }
        return
    }
    lp  := NumGet(lParam + 2 * A_PtrSize)
    str := StrGet(lp)
    try req := Jxon_Load(str)
    catch
        return 1
    __CH_RIS_IPC_Queue.Push(req)
    SetTimer, CH_RIS_IPC_Drain, -1     ; defer to the owner's main thread
    return 1
}

; Runs queued requests on the main thread, where touching CH_RIS / IE COM is safe.
CH_RIS_IPC_Drain() {
    global __CH_RIS_IPC_Queue
    while (__CH_RIS_IPC_Queue.Length()) {
        req := __CH_RIS_IPC_Queue.RemoveAt(1)
        result := CH_RIS_IPC_Dispatch(req)
        if (req.resp != "")
            CH_RIS_IPC_WriteResp(req.resp, result)
    }
}

; Maps one command onto the local CH_RIS object. Returns a serializable result object.
CH_RIS_IPC_Dispatch(req) {
    global CH_RIS
    cmd  := req.cmd
    args := req.args
    if !IsObject(args)
        args := {}

    if (cmd = "ping")                       ; health check — no CH_RIS required
        return {ok: true, pong: 1, owner_pid: DllCall("GetCurrentProcessId")}

    if (cmd = "sub_accno") {                ; register a client window for accNo-change pings
        global __CH_RIS_IPC_AccNoSubs
        if !IsObject(__CH_RIS_IPC_AccNoSubs)
            __CH_RIS_IPC_AccNoSubs := {}
        __CH_RIS_IPC_AccNoSubs[args.hwnd] := {msg: args.msg, wParam: args.wParam, lParam: args.lParam}
        DebugLog("CH_RIS.server", "sub_accno hwnd=" args.hwnd " msg=" args.msg)
        return {ok: true}
    }

    if !CH_RIS
        return {ok: false, error: "no owner CH_RIS"}

    try {
        switch cmd {
        case "get_state":
            return {ok: true, state: CH_RIS_IPC_Snapshot()}
        case "get":
            return {ok: true, value: CH_RIS[args.name] . ""}
        case "set":
            CH_RIS[args.name] := args.value
            return {ok: true}
        case "func":
            ; Run a getRis*/action through CH_RIS_Func on the owner's main thread and
            ; return the (serializable) result. Owner is never a client, so CH_RIS_Func
            ; here executes the real switch. risSendReport is interactive (GetKeyState /
            ; MsgBox) and must run in the client process, never deferred here.
            if (args.fn = "")
                return {ok: false, error: "func: no fn"}
            if (args.fn = "risSendReport")
                return {ok: false, error: "func: risSendReport must run client-side"}
            fnArgs := IsObject(args.args) ? args.args : []
            return {ok: true, value: CH_RIS_Func(args.fn, fnArgs*)}
        case "wb_hwnd":
            return {ok: true, value: CH_RIS.wb.hwnd}
        case "click_save":
            CH_RIS.inputElements.saveReport.Click()
            return {ok: true}
        case "reset":
            CH_RIS.reset(args.wait, args.reset_simpleris)
            return {ok: true}
        case "set_report":
            CH_RIS.exam := args.exam
            , CH_RIS.impression := args.impression
            return {ok: true}
        case "flush":
            err := CH_RIS.flush()
            reportText := ""
            try reportText := CH_RIS.inputElements.reportText.value
            return {ok: !err, error: err, state: CH_RIS_IPC_Snapshot(), reportText: reportText}
        case "set_and_flush":
            CH_RIS.exam := args.exam
            , CH_RIS.impression := args.impression
            err := CH_RIS.flush()
            return {ok: !err, error: err}
        case "activate":
            CH_RIS.activate()
            return {ok: true}
        case "next_study":
            CH_RIS.next_study()
            return {ok: true}
        case "prior_study":
            CH_RIS.prior_study()
            return {ok: true}
        case "refresh":
            CH_RIS.check_wb()
            , CH_RIS.refresh_info(true)
            return {ok: true, state: CH_RIS_IPC_Snapshot()}
        ; ---- object-prop sub-proxy support (Step 1) ----
        ; gui[field] is an AHK Edit control hwnd — valid cross-process, so the client can
        ; ControlGetText / Edit_SetText it directly.
        case "get_gui_hwnd":
            return {ok: true, value: CH_RIS.gui[args.field] . ""}
        ; inputElements[name] is an IE DOM element (process-bound). Expose its value get/set
        ; and Click() so clients never hold the COM object themselves.
        case "get_input_value":
            return {ok: true, value: CH_RIS.inputElements[args.name].value . ""}
        case "set_input_value":
            CH_RIS.inputElements[args.name].value := args.value
            return {ok: true}
        case "click_input":
            CH_RIS.inputElements[args.name].Click()
            return {ok: true}
        ; pacs_hx.data is a nested array; pacs_hx_colNo / pacs_hx.colNo is a column-name->index
        ; map. Both are JXON-serialisable, so we ship them whole.
        case "get_pacs_hx_data":
            return {ok: true, value: CH_RIS.pacs_hx.data}
        case "get_pacs_hx_colno":
            return {ok: true, value: (IsObject(CH_RIS.pacs_hx_colNo) ? CH_RIS.pacs_hx_colNo : CH_RIS.pacs_hx.colNo)}
        ; wb.ReadyState (4 = complete). wb.hwnd is served by the existing wb_hwnd case.
        case "wb_ready":
            return {ok: true, value: CH_RIS.wb.ReadyState . ""}
        ; The RIS *list* window hwnd (CH_RIS.ris_list_wb.wb.hwnd) — distinct from the report
        ; wb. Throws into the outer catch (-> client "") when there's no list window.
        case "ris_list_wb_hwnd":
            return {ok: true, value: CH_RIS.ris_list_wb.wb.hwnd}
        ; Run a whitelisted, non-interactive CH_RIS method on the owner's main thread.
        case "call_method":
            return CH_RIS_IPC_CallMethod(args.name, IsObject(args.args) ? args.args : [])
        default:
            return {ok: false, error: "unknown cmd: " cmd}
        }
    } catch e {
        return {ok: false, error: "exception: " e.message}
    }
}

; Run one CH_RIS method by name on the owner. Whitelisted to the non-interactive
; refresh/parse/visibility helpers consumers call directly — never report-send or other
; user-interactive flows (those run client-side; see CH_RIS_RisSendReport_Client).
CH_RIS_IPC_CallMethod(name, args) {
    global CH_RIS
    static allowed := {refresh_info: 1, check_wb: 1, get_fields: 1, Parse_pacs_hx: 1
                     , RIS_list_wb_changed: 1, update_wb: 1, HideWb: 1, showWB: 1
                     , GetModalityCode: 1, parse_exam_type: 1}
    if !allowed.HasKey(name)
        return {ok: false, error: "method not allowed: " name}
    if !IsObject(args)
        args := []
    try {
        val := CH_RIS[name](args*)
        return {ok: true, value: (IsObject(val) ? val : val . "")}
    } catch e {
        return {ok: false, error: "method exception: " e.message}
    }
}

; Scalar-only snapshot. Object props (wb / gui / inputElements / pacs_hx) are
; intentionally omitted — they can't cross a process boundary.
CH_RIS_IPC_Snapshot() {
    global CH_RIS
    snap := {}
    for i, k in ["accNo", "chartNo", "examname", "examtime", "examDate", "patname", "patidno", "gender", "age", "patno", "namec", "mccid", "status", "memo", "remark", "exam", "impression", "report"]
        try snap[k] := CH_RIS[k] . ""
    return snap
}
