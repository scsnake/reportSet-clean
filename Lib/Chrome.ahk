; ==============================================================================
; Library: Chrome.ahk
; Classification: Pure Third-Party
; Original Author: GeekDude (G33k)
; Origin: GitHub (Chrome.ahk)
; License: MIT
; Source URL: https://github.com/G33kDude/Chrome.ahk
; ==============================================================================

#include <GetActiveBrowserURL>
#include <WinHttpRequest>
#include <JXON>

class Chrome {
	WindowSpec(){
		return "ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe"
	}

	IsOpen(){
		return WinExist(this.WindowSpec())
	}

	Activate(timeoutSec:=2, hwnd:=0){
		if (!hwnd)
			hwnd:=this.IsOpen()
		if (!hwnd)
			return false
		WinActivate, ahk_id %hwnd%
		WinWaitActive, ahk_id %hwnd%,,% timeoutSec
		return !ErrorLevel
	}

	ActiveUrl(){
		global nWindow, accAddressBar
		; Focus can move back to RIS while Chrome is loading. Never query another
		; application's URL (the DDE fallback can also block for ten seconds).
		if !WinActive(this.WindowSpec())
			return ""
		try url:=GetActiveBrowserURL()
		catch
			url:=""
		; Chrome can replace its accessibility objects during a tab change.
		; Rebuild the cached address-bar object on the next poll after a miss.
		if (url="")
			nWindow:=0, accAddressBar:=""
		return url
	}

	UrlStartsWith(url, prefix){
		return SubStr(url, 1, StrLen(prefix)) = prefix
	}

	FindTabByUrlPrefix(prefix, maxTabs:=20){
		if !this.Activate()
			return false
		firstURL:=""
		Loop, % maxTabs {
			currentURL:=this.ActiveUrl()
			if this.UrlStartsWith(currentURL, prefix)
				return true
			if (A_Index>1 && firstURL!="" && currentURL=firstURL)
				break
			if (A_Index=1)
				firstURL:=currentURL
			if !WinActive(this.WindowSpec())
				return false
			Send ^{Tab}
			Sleep 100
		}
		return false
	}

	; With verifyUrl=false, success means the address was submitted. Use this
	; when a caller must avoid duplicates if Chrome cannot expose the loaded URL.
	Navigate(url, matchPrefix:="", openNewIfMissing:=true, maxTabs:=20, verifyUrl:=true){
		if !this.Activate()
			return false
		found:=true
		if (matchPrefix!="")
			found:=this.FindTabByUrlPrefix(matchPrefix, maxTabs)
		if (!found && !openNewIfMissing)
			return false
		if !this.Activate()
			return false
		hwnd:=WinActive(this.WindowSpec())
		if (!found) {
			Send ^t
			Sleep 60
		}
		oldClipboard:=ClipboardAll
		try {
			Loop, 2 {
				if (this.SubmitAddress(url, hwnd) && (!verifyUrl || this.WaitForUrl(url)))
					return true
			}
		} finally {
			Clipboard:=oldClipboard
		}
		return false
	}

	OpenOrNavigate(url, matchPrefix:="", openNewIfMissing:=true, maxTabs:=20, verifyUrl:=true){
		if this.Navigate(url, matchPrefix, openNewIfMissing, maxTabs, verifyUrl)
			return true
		; A launch may still be loading when URL verification times out. Give it
		; time to appear before issuing another command that would duplicate tabs.
		if (this.lastLaunchUrl=url && A_TickCount-this.lastLaunchTick<10000)
			return false
		if !this.LaunchUrl(url)
			return false
		this.lastLaunchUrl:=url, this.lastLaunchTick:=A_TickCount
		return !verifyUrl || this.WaitForUrl(url, 5000)
	}

	LaunchUrl(url){
		browser:=this.FindBrowserPath()
		if (browser!="")
			Run,% Chr(34) browser Chr(34) " " Chr(34) url Chr(34),, UseErrorLevel
		else
			Run,% url,, UseErrorLevel
		return !ErrorLevel
	}

	WaitForUrl(url, timeoutMs:=1500){
		started:=A_TickCount
		Loop {
			if (this.ActiveUrl()=url)
				return true
			if (A_TickCount-started>=timeoutMs)
				return false
			Sleep 100
		}
	}

	SubmitAddress(value, hwnd:=0){
		if !this.Activate(2, hwnd)
			return false
		if (!hwnd)
			hwnd:=WinActive(this.WindowSpec())
		Clipboard:=value
		ClipWait, 0.5
		if (ErrorLevel)
			return false
		Send ^l
		Sleep 100
		if !WinActive("ahk_id " hwnd)
			return false
		Send ^v
		; Chrome consumes the paste asynchronously; don't press Enter or restore
		; the user's clipboard before the address bar has received the URL.
		Sleep 100
		if !WinActive("ahk_id " hwnd)
			return false
		Send {Enter}
		return true
	}

	ExecJS(js, matchPrefix:="", maxTabs:=20){
		if (matchPrefix!="" && !this.FindTabByUrlPrefix(matchPrefix, maxTabs))
			return false
		if !this.Activate()
			return false
		oldClipboard:=ClipboardAll
		Send !d
		Sleep 20
		SendInput, javascript:
		Clipboard:=js
		Send ^v{Enter}
		Clipboard:=oldClipboard
		return true
	}

	GetDOM(selector:="", mode:="html", matchPrefix:="", timeoutMs:=1000){
		oldClipboard:=ClipboardAll
		Clipboard:=""
		js:=this.BuildCopyDomJS(selector, mode)
		if !this.ExecJS(js, matchPrefix) {
			Clipboard:=oldClipboard
			return ""
		}
		ClipWait,% timeoutMs/1000
		out:=ErrorLevel ? "" : Clipboard
		Clipboard:=oldClipboard
		return out
	}

	HookDOM(selector, eventName, jsBody, matchPrefix:=""){
		js:="(function(){var nodes=document.querySelectorAll(" this.JSString(selector) ");"
			. "for(var i=0;i<nodes.length;i++){nodes[i].addEventListener(" this.JSString(eventName) ",function(event){"
			. jsBody
			. "});}})();"
		return this.ExecJS(js, matchPrefix)
	}

	ClickDOM(selector, matchPrefix:=""){
		js:="(function(){var e=document.querySelector(" this.JSString(selector) ");if(e)e.click();})();"
		return this.ExecJS(js, matchPrefix)
	}

	SetDOMValue(selector, value, matchPrefix:=""){
		js:="(function(){var e=document.querySelector(" this.JSString(selector) ");if(e){e.value=" this.JSString(value) ";e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));}})();"
		return this.ExecJS(js, matchPrefix)
	}

	BuildCopyDomJS(selector:="", mode:="html"){
		expr:=(selector="") ? "document.documentElement" : "document.querySelector(" this.JSString(selector) ")"
		prop:=(mode="text") ? "innerText" : "outerHTML"
		return "(function(){var e=" expr ";var t=e?(e." prop "||''):'';"
			. "var ta=document.createElement('textarea');ta.value=t;document.body.appendChild(ta);ta.select();"
			. "document.execCommand('copy');ta.remove();})();"
	}

	RemoteTabs(port:=9222){
		data:="", headers:=""
		if (WinHttpRequest("http://127.0.0.1:" port "/json", data, headers, "Timeout: 1") != -1)
			return []
		try return Jxon_Load(data)
		catch
			return []
	}

	RemoteFindTabByUrlPrefix(prefix, port:=9222){
		tabs:=this.RemoteTabs(port)
		for k, tab in tabs
			if this.UrlStartsWith(tab.url, prefix)
				return tab
		return ""
	}

	RemoteActivate(tabId, port:=9222){
		if IsObject(tabId)
			tabId:=tabId.id
		data:="", headers:=""
		return WinHttpRequest("http://127.0.0.1:" port "/json/activate/" tabId, data, headers, "Timeout: 1") = -1
	}

	RemoteOpen(url, port:=9222){
		data:="", headers:=""
		if (WinHttpRequest("http://127.0.0.1:" port "/json/new?" this.UrlEncode(url), data, headers, "Timeout: 1") != -1)
			return ""
		try return Jxon_Load(data)
		catch
			return ""
	}

	RemoteClose(tabId, port:=9222){
		if IsObject(tabId)
			tabId:=tabId.id
		data:="", headers:=""
		return WinHttpRequest("http://127.0.0.1:" port "/json/close/" tabId, data, headers, "Timeout: 1") = -1
	}

	FindBrowserPath(){
		if (path:=this.ActiveChromePath())
			return path
		EnvGet, ProgramFilesX86, ProgramFiles(x86)
		candidates:=[A_ProgramFiles "\Google\Chrome\Application\chrome.exe"
			,ProgramFilesX86 "\Google\Chrome\Application\chrome.exe"
			,A_LocalAppData "\Google\Chrome\Application\chrome.exe"]
		for k,path in candidates
			if FileExist(path)
				return path
		return ""
	}

	ActiveChromePath(){
		Process, Exist, chrome.exe
		pid:=ErrorLevel
		if (!pid)
			return ""
		WinGet, path, ProcessPath, ahk_pid %pid%
		return path
	}

	JSString(str){
		q:=Chr(34)
		str:=StrReplace(str, "\", "\\")
		str:=StrReplace(str, q, "\" q)
		str:=StrReplace(str, "`r", "\r")
		str:=StrReplace(str, "`n", "\n")
		str:=StrReplace(str, "`t", "\t")
		return q str q
	}

	UrlEncode(str){
		f := A_FormatInteger
		SetFormat, IntegerFast, H
		out:=""
		Loop, Parse, str
		{
			ch:=A_LoopField
			if ch is alnum
				out.=ch
			else if InStr("-_.~", ch)
				out.=ch
			else {
				hex:=SubStr(Asc(ch)+0, 3)
				if (StrLen(hex)=1)
					hex:="0" hex
				out.="%" hex
			}
		}
		SetFormat, IntegerFast, %f%
		return out
	}
}
