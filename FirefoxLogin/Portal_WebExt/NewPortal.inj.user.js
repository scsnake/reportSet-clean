_inj_load(['jquery.js', 'NewPortal.user.js']);

browser.runtime.onMessage.addListener(function(message, sender){
	if('cardPw' in message && message.cardPw.length>0){
		var injectedCode = "$jq('#InputPINPassword').val('"+message.cardPw+"');$jq('#btnDoSignatureByPCSC').focus();";
		var s = document.createElement('script');
		s.appendChild(document.createTextNode(injectedCode));
		(document.head || document.documentElement).appendChild(s);
	}
});

// browser.runtime.sendMessage({askFor: 'cardPw'});



// document.addEventListener('DOMContentLoaded', function() {
var _portalId;
var _sid;
setTimeout(function(){	
	document.getElementById('btnDoSignatureByPCSC').onclick=function(e){
		browser.runtime.sendMessage({
			cardPw: document.getElementById('InputPINPassword').value
		});
	};
	var userIdMatch = document.documentElement.innerHTML.match(/Portal_UserID=(\w+)/);
	if (userIdMatch) _portalId = userIdMatch[1];
	var sidMatch = location.href.match(/SESSION=(\w+)/);
	if (sidMatch) _sid = sidMatch[1];
	browser.runtime.sendMessage({
		refreshSid: true,
		id: _portalId,
		sid: _sid
	});
		
}, 3000);

// });

