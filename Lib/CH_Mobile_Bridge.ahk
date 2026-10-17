#include <SetTimerClass>
#include <DebugLog>

; Persistent bridge between the RIS IE page and the C hospital mobile rounding site.
;
; The bridge owns one IE COM window and therefore one browser session.  Every chart
; request first visits /mobile/ to verify the real server-side session.  If the
; server redirects to the login page (including after an idle timeout), the bridge
; logs in again and resumes the queued chart search.
;
; Credentials are loaded lazily from query_app\.env and are never placed in the
; RIS DOM.  The state machine is timer-driven so an unavailable mobile server does
; not block the RIS/reporting process.
class CH_Mobile_Bridge extends SetTimerClass {
	__New(env_path:="", base_url:="http://im.hospital-c.local:8080") {
		this.base_url:=RTrim(base_url, "/")
		,this.env_path:=env_path
		,this.wb:=""
		,this.username:=""
		,this.password:=""
		,this.authenticated:=false
		,this.last_verified_tick:=0
		,this.current_chart:=""
		,this.queued_chart:=""
		,this.state:="idle"
		,this.status:="Mobile chart ready"
		,this.busy:=false
		,this.retry_count:=0
		,this.stage_started:=0
		,this.stage_deadline:=0
	}

	; Open the chart-search result in the persistent mobile IE window.  If another
	; request is already running, keep only the newest requested chart.
	OpenChart(chart_no) {
		chart_no:=this.NormalizeChartNo(chart_no)
		if (chart_no="") {
			this._SetStatus("Invalid mobile chart number")
			return false
		}
		if this.busy {
			this.queued_chart:=chart_no
			this._SetStatus("Queued mobile chart " chart_no)
			return true
		}
		return this._BeginChart(chart_no)
	}

	NormalizeChartNo(chart_no) {
		chart_no:=RegExReplace(Trim("" chart_no), "\s")
		if !RegExMatch(chart_no, "^\d{1,10}$")
			return ""
		while (StrLen(chart_no)<10)
			chart_no:="0" chart_no
		return chart_no
	}

	IsAuthenticated() {
		return this.authenticated && this._BrowserExists() && !this._IsLoginPage()
	}

	GetStatus() {
		return this.status
	}

	GetBrowser() {
		return this._BrowserExists() ? this.wb : ""
	}

	Close() {
		this.DisposeTimers()
		try this.wb.Quit()
		this.wb:=""
		,this.authenticated:=false
		,this.busy:=false
		,this.state:="idle"
		,this.current_chart:=""
		,this.queued_chart:=""
		,this._SetStatus("Mobile chart window closed")
	}

	_BeginChart(chart_no) {
		this.current_chart:=chart_no
		,this.queued_chart:=""
		,this.busy:=true
		,this.retry_count:=0
		,this.authenticated:=false
		if !this._EnsureBrowser() {
			this._Fail("Cannot create mobile IE window")
			return false
		}
		this.state:="wait_auth_check"
		,this._ArmStage(20000)
		,this._SetStatus("Checking mobile login...")
		try {
			this.wb.Visible:=true
			this.wb.Navigate(this.base_url "/mobile/")
		} catch e {
			this._Fail("Cannot open mobile site")
			return false
		}
		this.setTimer("_Tick", 100)
		return true
	}

	_Tick() {
		if !this.busy {
			this.setTimer("_Tick", "Off")
			return
		}
		if !this._BrowserExists() {
			this._Fail("Mobile IE window was closed")
			return
		}
		if (A_TickCount>this.stage_deadline) {
			this._Fail("Mobile site timed out")
			return
		}
		if !this._BrowserReady()
			return

		; Avoid evaluating the old document in the short interval between form.submit()
		; and IE changing ReadyState/LocationURL.
		if (A_TickCount-this.stage_started<400)
			return

		switch this.state {
			case "wait_auth_check":
				if this._IsLoginPage()
					this._StartLogin()
				else {
					this.authenticated:=true
					,this.last_verified_tick:=A_TickCount
					,this._StartSearch()
				}

			case "wait_login":
				if this._IsLoginPage() {
					this.authenticated:=false
					,this._Fail("Mobile login was rejected")
				} else {
					this.authenticated:=true
					,this.last_verified_tick:=A_TickCount
					,this._StartSearch()
				}

			case "wait_search":
				if this._IsLoginPage() {
					this.authenticated:=false
					if (this.retry_count<1) {
						this.retry_count++
						this._StartLogin()
					} else
						this._Fail("Mobile session expired during search")
				} else
					this._Complete()
		}
	}

	_StartLogin() {
		if !this._LoadCredentials() {
			this._Fail("Mobile credentials not found")
			return false
		}
		this.state:="wait_login"
		,this._ArmStage(20000)
		,this._SetStatus("Logging in to mobile...")
		data:={"clerkId": this.username
			,"passwd": this.password
			,"_action_authenticate": "login"}
		if !this._SubmitForm(this.base_url "/mobile/user/index", data) {
			this._Fail("Cannot submit mobile login")
			return false
		}
		return true
	}

	_StartSearch() {
		this.state:="wait_search"
		,this._ArmStage(20000)
		,this._SetStatus("Searching mobile chart " this.current_chart "...")
		data:={"hhisnum": this.current_chart, "patNoYN": "Y"}
		if !this._SubmitForm(this.base_url "/mobile/patAdmCase/listbysearch", data) {
			this._Fail("Cannot submit mobile chart search")
			return false
		}
		return true
	}

	_Complete() {
		chart_no:=this.current_chart
		this.authenticated:=true
		,this.last_verified_tick:=A_TickCount
		,this.current_chart:=""
		,this.busy:=false
		,this.state:="idle"
		,this.setTimer("_Tick", "Off")
		,this._SetStatus("Opened mobile chart " chart_no)
		try {
			hwnd:=this.wb.hwnd
			WinShow, % "ahk_id " hwnd
			WinMaximize, % "ahk_id " hwnd
			WinActivate, % "ahk_id " hwnd
		}
		this._RunQueuedChart()
	}

	_Fail(message) {
		try DebugLog("CH_Mobile_Bridge", message " state=" this.state " chart=" this.current_chart)
		this.current_chart:=""
		,this.busy:=false
		,this.state:="idle"
		,this.setTimer("_Tick", "Off")
		,this._SetStatus("Mobile error: " message)
		this._RunQueuedChart()
	}

	_RunQueuedChart() {
		if (this.queued_chart="")
			return
		next_chart:=this.queued_chart
		,this.queued_chart:=""
		this._BeginChart(next_chart)
	}

	_ArmStage(timeout_ms) {
		this.stage_started:=A_TickCount
		,this.stage_deadline:=A_TickCount+timeout_ms
	}

	_SetStatus(message) {
		this.status:=message
		try DebugLog("CH_Mobile_Bridge", message)
	}

	_EnsureBrowser() {
		if this._BrowserExists()
			return true
		try {
			this.wb:=ComObjCreate("InternetExplorer.Application")
			this.wb.Visible:=true
			return true
		} catch e {
			this.wb:=""
			return false
		}
	}

	_BrowserExists() {
		if !IsObject(this.wb)
			return false
		try hwnd:=this.wb.hwnd
		catch
			return false
		return hwnd && WinExist("ahk_id " hwnd)
	}

	_BrowserReady() {
		try return !this.wb.Busy && this.wb.ReadyState=4 && IsObject(this.wb.document)
		catch
			return false
	}

	_IsLoginPage() {
		if !this._BrowserExists()
			return true
		try {
			url:=this.wb.LocationURL
			if InStr(url, "/mobile/user/login")
				return true
			doc:=this.wb.document
			if doc.getElementById("loginForm")
				return true
			fields:=doc.getElementsByName("clerkId")
			return fields && fields.length>0
		} catch e {
			return true
		}
	}

	_SubmitForm(action_url, data) {
		try {
			doc:=this.wb.document
			form:=doc.createElement("form")
			form.method:="POST"
			,form.action:=action_url
			,form.style.display:="none"
			for name,value in data {
				input:=doc.createElement("input")
				input.type:="hidden"
				,input.name:=name
				,input.value:=value
				,form.appendChild(input)
			}
			doc.body.appendChild(form)
			form.submit()
			return true
		} catch e {
			try DebugLog("CH_Mobile_Bridge", "form submit failed: " e.Message)
			return false
		}
	}

	_LoadCredentials(force:=false) {
		if (!force && this.username!="" && this.password!="")
			return true
		path:=this._CredentialPath()
		if (path="" || !FileExist(path))
			return false
		FileRead, content, *P65001 %path%
		if ErrorLevel
			return false
		values:={}
		Loop, Parse, content, `n, `r
		{
			line:=Trim(A_LoopField)
			if (line="" || SubStr(line,1,1)="#")
				continue
			if !RegExMatch(line, "^\s*([^#=\s]+)\s*=(.*)$", match)
				continue
			key:=match1
			,value:=Trim(match2, " `t`r`n")
			if ((SubStr(value,1,1)="""" && SubStr(value,0)="""")
				|| (SubStr(value,1,1)="'" && SubStr(value,0)="'"))
				value:=SubStr(value,2,StrLen(value)-2)
			values[key]:=value
		}
		this.username:=values.HasKey("user") ? values.user : values.MOBILE_USER
		,this.password:=values.HasKey("pw") ? values.pw : values.MOBILE_PASSWORD
		return this.username!="" && this.password!=""
	}

	_CredentialPath() {
		if (this.env_path!="")
			return this.env_path
		candidates:=[A_ScriptDir "\CH scripts\query_app\.env"
			,A_ScriptDir "\query_app\.env"
			,A_ScriptDir "\.env"
			,A_ScriptDir "\..\CH scripts\query_app\.env"
			,A_WorkingDir "\CH scripts\query_app\.env"]
		for _,path in candidates
			if FileExist(path)
				return path
		return candidates[1]
	}
}
