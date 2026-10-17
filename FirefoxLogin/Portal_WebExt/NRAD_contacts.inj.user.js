_inj_load(['jquery.js', 'crypto-js.js', 'NRAD_contacts.js']);

browser.runtime.onMessage.addListener(function(message, sender){
	if('decryptKey' in message){
		var s = document.createElement('input');
		s.type='hidden';
		s.id = '__decrypt';
		s.value=md5(message.decryptKey);
		(document.head || document.documentElement).appendChild(s);
		
	}
});

var _sid='';
var sidMatch = location.href.match(/SESSION=(\w+)/);
if (sidMatch) _sid = sidMatch[1];

if(_sid!==''){
	browser.runtime.sendMessage({
		requestDecryptKey: true,
		sid: _sid
	});	
}
