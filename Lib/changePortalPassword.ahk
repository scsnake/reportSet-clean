#include <CryptFileRead>
#include <portallib>
#include <RisImpax>
#include <RegexSplit>
DetectHiddenWindows,on

;~ changePortalPassword()
;~ ExitApp

changePortalPassword(){
	global ____, loginId, loginPw, newLoginPw
	CryptFilePW()
	
	;~ InputBox,newLoginPw,,new portal pw,
	newLoginPw:=""
	loginIds:=[]
	refreshRisImpaxEncrypt(newLoginPw, loginIds)
	
	ids:=[]
	
	for k, loginId in loginIds {
		if ids.haskey(loginId)
			continue
		else
			ids[loginId]:=1
		
		if checksid(login(loginId, newLoginPw))
			continue
		
		sid:=askForPortalIdPw(0,1, loginId~="^\d"?0:SubStr(loginId,1,1))
		;~ continue
		url:="http://portal.hospital-n.local/General/ChangePassword.aspx?SESSION=" sid
		
		if !pwb
			pwb:=ComObjCreate("InternetExplorer.Application")
		;~ pwb:=new PwbCollections(pwb.hwnd)
		pwb.Visible:=true
		pwb.Navigate(url)
		
		Loop
			Sleep 100
		until !pwb.busy && (pwb.document.getElementById("txbNewPass2").id) && !A_Index<100
		
		pwb.document.getElementById("txtPass").value:=loginPw
		pwb.document.getElementById("txbNewPass1").value:=newLoginPw
		pwb.document.getElementById("txbNewPass2").value:=newLoginPw
		pwb.Navigate("javascript:Strenght();void 0;")
		Sleep 300
		pwb.document.getElementById("btnConfirmMod").click()
		
		Loop
			Sleep 100
		until !pwb.busy && !A_Index<100
		
		if(loginId~="^\d"){
			pwb.Navigate("https://help.hospital-n.local/query/index.html")
			Sleep 500
			js=document.querySelector('input[name=empno]').value='%loginId%';document.querySelector('input[name=opwd]').value='%loginPw%';document.querySelector('input[name=submit]').click();
			execJs(pwb, js)
			Sleep 500
			js=document.querySelector('input[name=pwd]').value='%newLoginPw%';document.querySelector('input[name=pwd1]').value='%newLoginPw%';document.querySelector('input[name=submit]').click();
			execJs(pwb, js)
			Sleep 500
			
		}
		
	}
	pwb.quit()
	
	if fileexist("portal.ini")
		path:="portal.ini"
	else if fileexist((dir:=regexreplace(a_scriptdir,"[/\\][^/\\]+$")) "\portal.ini")
		path:=dir "\portal.ini"
	
	fileread,portalini,% path
	portalini:=RegExReplaceFn(portalini, "i)pw=([^\r\n]+)", "changePortalIniPw")
	FileDelete,% path
	FileAppend,% portalini,% path,utf-8-Raw
}

changePortalIniPw(ByRef m){
	global ____, newLoginPw
	enc_pw:=m[1]
	dec_pw:=Crypt.Encrypt.StrDecrypt(enc_pw, ____,7, 6)
	if !(i:=RegExMatch(dec_pw, "\!\@\#(\w+)\$\%\^", loginId))
		return m[0]
	old_pw:=SubStr(dec_pw,1,i-1) SubStr(dec_pw,i+StrLen(loginId))
	Random,rand,0,% StrLen(newLoginPw)
	loginPw:=rand=0? loginId newLoginPw:(SubStr(newLoginPw,1,rand) loginId SubStr(newLoginPw, rand+1))
	
	return "pw=" Crypt.Encrypt.StrEncrypt(loginPw,____,7,6)
}

