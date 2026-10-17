; CH_RIS_Client.ahk
; Client-side of the single-owner CH_RIS IPC bridge.
;
; A client sends commands to the owner (the process that called CH_RIS_Server_Start())
; instead of instantiating its own CH_RIS_REPORT and touching IE COM directly.
;
; Migration is opt-in: a consumer sets global __CH_RIS_CLIENT := true before the risimpax
; include to route report operations through the owner instead of creating its own
; IE-polling CH_RIS. While unset (the default), callers keep the existing direct path, so
; this file is safe to include without changing behavior. (The flag is read by getPlace()
; and CH_RIS_Func(); see Lib\getPlace.ahk and Lib\RisImpax.ahk.)

#include <CH_RIS_IPC>

; Locate the owner's listener window (hidden) without disturbing caller settings.
CH_RIS_Server_Hwnd() {
    global CH_RIS_SERVER_TITLE
    prevDHW := A_DetectHiddenWindows
    prevTMM := A_TitleMatchMode
    DetectHiddenWindows, On
    SetTitleMatchMode, 2
    h := WinExist(CH_RIS_SERVER_TITLE " ahk_class AutoHotkeyGUI")
    DetectHiddenWindows, % prevDHW
    SetTitleMatchMode, % prevTMM
    return h
}

CH_RIS_ServerAvailable() {
    return CH_RIS_Server_Hwnd() ? true : false
}

; Core request/reply. Returns the parsed reply object (always an object).
; wantReply=false makes it fire-and-forget (returns immediately after a successful send).
CH_RIS_Call(cmd, args := "", wantReply := true, timeout := 4000) {
    global CH_RIS_DW
    h := CH_RIS_Server_Hwnd()
    if !h
        return {ok: false, error: "no CH_RIS server"}
    id   := CH_RIS_IPC_NewId()
    resp := wantReply ? CH_RIS_IPC_RespPath(id) : ""
    if (resp != "")
        try FileDelete, % resp
    if !IsObject(args)
        args := {}
    payload := Jxon_Dump({id: id, cmd: cmd, args: args, resp: resp})
    sendTimeout := (timeout && timeout < 1000) ? timeout : 1000
    if !Send_WM_COPYDATA(h, CH_RIS_DW, payload, sendTimeout)
        return {ok: false, error: "send failed"}
    if (resp = "")
        return {ok: true}
    endTick := A_TickCount + timeout
    loop {
        r := CH_RIS_IPC_ReadResp(resp)
        if IsObject(r)
            return r
        if (A_TickCount > endTick)
            return {ok: false, error: "timeout"}
        Sleep, 15
    }
}

; ---- convenience wrappers (mirror the common CH_RIS calls) ----

CH_Ping() {
    return CH_RIS_Call("ping")
}
CH_GetState() {
    r := CH_RIS_Call("get_state")
    return r.ok ? r.state : ""
}
CH_Get(name) {
    r := CH_RIS_Call("get", {name: name})
    return r.ok ? r.value : ""
}
CH_SetReport(exam, impression := "") {
    return CH_RIS_Call("set_report", {exam: exam, impression: impression})
}
CH_FlushReport() {
    return CH_RIS_Call("flush")
}
CH_SetAndFlush(exam, impression := "") {
    return CH_RIS_Call("set_and_flush", {exam: exam, impression: impression})
}

; Older owners report ok=false,error=0 for a successful flush. Accept that
; legacy reply while retaining transport failures and real owner errors.
CH_RIS_FlushReplyError(r) {
    if !IsObject(r)
        return "invalid RIS sync reply"
    if (r.ok || (r.HasKey("error") && r.error == 0))
        return ""
    return r.error != "" ? r.error : "RIS sync failed without an error description"
}
CH_Activate(wait := false) {
    return CH_RIS_Call("activate", "", wait)
}
CH_NextStudy() {
    return CH_RIS_Call("next_study", "", false)
}
CH_PriorStudy() {
    return CH_RIS_Call("prior_study", "", false)
}
CH_Refresh() {
    r := CH_RIS_Call("refresh")
    return r.ok ? r.state : ""
}

; ---- generic scalar set + report-send primitives (used by converted consumers) ----

; Set one scalar field on the owner object (e.g. exam/impression/report).
CH_Set(name, value) {
    return CH_RIS_Call("set", {name: name, value: value})
}
; The owner's RIS IE window handle (for ArmSendRptIEBlock and similar).
CH_WbHwnd() {
    r := CH_RIS_Call("wb_hwnd")
    return r.ok ? r.value : ""
}
; Click the owner's "save report" button (saveSelectButton).
CH_ClickSave() {
    return CH_RIS_Call("click_save")
}
; Reset the owner's report GUI (and optionally simpleRIS).
CH_Reset(wait := 1, reset_simpleris := 0) {
    return CH_RIS_Call("reset", {wait: wait, reset_simpleris: reset_simpleris})
}

; ---- object-prop accessors (back the sub-proxies below) ----

; A field hwnd from the owner's report GUI (gui.exam_edit, gui.accno_edit_auto, ...).
; AHK Edit control hwnds are valid cross-process, so callers ControlGetText / Edit_SetText
; them directly. Not cached: the owner may rebuild its GUI (re-login) and hand out new hwnds.
CH_GuiHwnd(field) {
    r := CH_RIS_Call("get_gui_hwnd", {field: field})
    return r.ok ? r.value : ""
}
; Value of an owner IE input element (inputElements.reportText.value, ...).
CH_InputValue(name) {
    r := CH_RIS_Call("get_input_value", {name: name})
    return r.ok ? r.value : ""
}
CH_SetInputValue(name, value) {
    return CH_RIS_Call("set_input_value", {name: name, value: value})
}
; Click an owner IE input element (saveReport, nextExam, priorExam, openImage, ...).
CH_ClickInput(name) {
    return CH_RIS_Call("click_input", {name: name})
}
; The owner's parsed prior-study history table (nested array) and its column-index map.
CH_PacsHxData() {
    r := CH_RIS_Call("get_pacs_hx_data")
    return r.ok ? r.value : ""
}
CH_PacsHxColNo() {
    r := CH_RIS_Call("get_pacs_hx_colno")
    return r.ok ? r.value : ""
}
; The owner RIS IE page ReadyState (4 = complete).
CH_WbReady() {
    r := CH_RIS_Call("wb_ready")
    return r.ok ? r.value : ""
}
; The owner's RIS *list* window hwnd (distinct from the report wb); "" if no list window.
CH_RisListWbHwnd() {
    r := CH_RIS_Call("ris_list_wb_hwnd")
    return r.ok ? r.value : ""
}
; Run a whitelisted, non-interactive CH_RIS method on the owner; returns its result.
CH_CallMethod(name, args*) {
    r := CH_RIS_Call("call_method", {name: name, args: args})
    return (IsObject(r) && r.ok) ? r.value : ""
}

; ---- accNo-change subscription (drop-in for the owner's addAccNoChangedHookFn) ----
; A client can't hook the owner's in-process accNoChangedHookFn list. Instead it asks
; the owner to PostMessage __CH_RIS_CLIENT_AccNoMsg to this script's window whenever the
; accNo changes; the local dispatcher then runs the registered callbacks here.
global __CH_RIS_CLIENT_AccNoMsg := 0x8401        ; WM_APP-range, private to this bridge
global __CH_RIS_CLIENT_AccNoFns := []

CH_RIS_Client_AddAccNoHook(fn) {
    global __CH_RIS_CLIENT_AccNoMsg, __CH_RIS_CLIENT_AccNoFns
    static registered := false
    if !IsObject(__CH_RIS_CLIENT_AccNoFns)
        __CH_RIS_CLIENT_AccNoFns := []
    __CH_RIS_CLIENT_AccNoFns.Push(fn)
    if !registered {
        registered := true
        OnMessage(__CH_RIS_CLIENT_AccNoMsg, "CH_RIS_Client_AccNoDispatch")
    }
    ; Register our window with the owner. autorun restart kills clients, so a single
    ; subscribe at hook time matches the process lifecycle (re-subscribe on relaunch).
    CH_RIS_Call("sub_accno", {hwnd: A_ScriptHwnd, msg: __CH_RIS_CLIENT_AccNoMsg}, false)
}

CH_RIS_Client_AccNoDispatch(wParam, lParam, msg, hwnd) {
    global __CH_RIS_CLIENT_AccNoFns
    if !IsObject(__CH_RIS_CLIENT_AccNoFns)
        return
    for i, fn in __CH_RIS_CLIENT_AccNoFns {
        if IsObject(fn)
            fn.Call()
        else if IsFunc(fn)
            %fn%()
    }
}

; ---- proxy object: a stand-in for the CH_RIS owner object in client processes ----
; getPlace()/CH_RIS_Func() set the global CH_RIS to one of these when __CH_RIS_CLIENT
; is true. Property reads/writes and method calls are forwarded to the autorun owner over
; IPC, so existing consumer code (CH_RIS.exam / .flush() / .chartNo / .addAccNoChangedHookFn)
; keeps working without per-call-site edits.
;
; Object-typed properties (.wb/.gui/.inputElements/.pacs_hx) can't cross a process boundary
; and aren't used by consumers directly (they go through CH_RIS_Func, which runs on the
; owner) — __Get returns blank for them and logs, so any stray direct use is visible.
CH_RIS_Client_MakeProxy() {
    return new CH_RIS_CLIENT_PROXY()
}

class CH_RIS_CLIENT_PROXY {
    ; Object props return a small sub-proxy that forwards each field/element access to the
    ; owner over IPC (Step 1). Scalars go straight through CH_Get. pacs_hx_colNo is a plain
    ; column-index map, fetched whole.
    __Get(name, params*) {
        switch name {
        case "gui":
            return new CH_RIS_GUI_SUBPROXY()
        case "inputElements":
            return new CH_RIS_INPUT_SUBPROXY()
        case "pacs_hx":
            return new CH_RIS_PACSHX_SUBPROXY()
        case "pacs_hx_colNo":
            return CH_PacsHxColNo()
        case "wb":
            return new CH_RIS_WB_SUBPROXY()
        case "ris_list_wb":
            return new CH_RIS_RISLIST_SUBPROXY()
        }
        return CH_Get(name)
    }
    __Set(name, params*) {
        value := params[params.MaxIndex()]
        CH_Set(name, value)
        return value
    }
    __Call(method, params*) {
        static methodCmds := {refresh_info: 1, check_wb: 1, get_fields: 1, Parse_pacs_hx: 1
                            , RIS_list_wb_changed: 1, update_wb: 1, HideWb: 1, showWB: 1
                            , GetModalityCode: 1, parse_exam_type: 1}
        if (method = "")
            return
        switch method {
        case "flush":
            r := CH_FlushReport()
            return CH_RIS_FlushReplyError(r)
        case "activate":
            CH_Activate()
            return
        case "next_study":
            CH_NextStudy()
            return
        case "prior_study":
            CH_PriorStudy()
            return
        case "reset":
            CH_Reset(params[1], params[2])
            return
        case "addAccNoChangedHookFn":
            CH_RIS_Client_AddAccNoHook(params[1])
            return
        case "removeAccNoChangedHookFn":
            return  ; owner prunes dead subscriber windows; nothing to do client-side yet
        default:
            ; Whitelisted non-interactive CH_RIS methods run on the owner via IPC.
            if methodCmds.HasKey(method)
                return CH_CallMethod(method, params*)
            DebugLog("CH_RIS.client", "proxy __Call unhandled method '" method "' -> no-op")
            return
        }
    }
}

; ---- sub-proxies for the owner's object properties ----
; Each is created on demand by CH_RIS_CLIENT_PROXY.__Get and forwards one level of access
; to the owner. They hold no COM/state, so they're cheap to recreate per access.

; CH_RIS.gui.<field> -> owner Edit control hwnd (valid cross-process).
class CH_RIS_GUI_SUBPROXY {
    __Get(field, params*) {
        return CH_GuiHwnd(field)
    }
}

; CH_RIS.inputElements.<name> -> an element-proxy exposing .value (get/set) and .Click().
class CH_RIS_INPUT_SUBPROXY {
    __Get(name, params*) {
        return new CH_RIS_INPUT_ELEM_PROXY(name)
    }
}

; One owner IE input element. Stores its element name via ObjRawSet so the meta-functions
; below don't intercept the internal field.
class CH_RIS_INPUT_ELEM_PROXY {
    __New(elemName) {
        ObjRawSet(this, "elemName", elemName)
    }
    __Get(prop, params*) {
        if (prop = "value")
            return CH_InputValue(this.elemName)
        DebugLog("CH_RIS.client", "inputElements." this.elemName " read '" prop "' unsupported -> ''")
        return ""
    }
    __Set(prop, params*) {
        value := params[params.MaxIndex()]
        if (prop = "value")
            CH_SetInputValue(this.elemName, value)
        return value
    }
    __Call(method, params*) {
        if (method = "")
            return
        if (method = "Click")
            return CH_ClickInput(this.elemName)
        DebugLog("CH_RIS.client", "inputElements." this.elemName " call '" method "' unsupported -> no-op")
        return
    }
}

; CH_RIS.pacs_hx.data / .colNo -> serialisable prior-study table + column map.
class CH_RIS_PACSHX_SUBPROXY {
    __Get(prop, params*) {
        if (prop = "data")
            return CH_PacsHxData()
        if (prop = "colNo")
            return CH_PacsHxColNo()
        DebugLog("CH_RIS.client", "pacs_hx read '" prop "' unsupported -> ''")
        return ""
    }
}

; CH_RIS.wb.hwnd / .ReadyState. .document.* is raw IE DOM and can't cross IPC — those
; callers must be refactored to snapshot/IPC (see CH_RIS_IPC_HANDOFF Step 3).
class CH_RIS_WB_SUBPROXY {
    __Get(prop, params*) {
        if (prop = "hwnd")
            return CH_WbHwnd()
        if (prop = "ReadyState")
            return CH_WbReady()
        DebugLog("CH_RIS.client", "wb read '" prop "' unsupported (raw DOM not proxyable) -> ''")
        return ""
    }
}

; CH_RIS.ris_list_wb.wb.hwnd. The list page's raw DOM (.wb.document.*) can't cross IPC.
class CH_RIS_RISLIST_SUBPROXY {
    __Get(prop, params*) {
        if (prop = "wb")
            return new CH_RIS_RISLISTWB_SUBPROXY()
        DebugLog("CH_RIS.client", "ris_list_wb read '" prop "' unsupported -> ''")
        return ""
    }
}
class CH_RIS_RISLISTWB_SUBPROXY {
    __Get(prop, params*) {
        if (prop = "hwnd")
            return CH_RisListWbHwnd()
        DebugLog("CH_RIS.client", "ris_list_wb.wb read '" prop "' unsupported (raw DOM not proxyable) -> ''")
        return ""
    }
}
