_inj_load(['jquery.js', 'digitalSignature.user.js']);

browser.runtime.onMessage.addListener(function(message, sender){
	if('cardPw' in message && message.cardPw.length>0){
		var injectedCode = "$jq('#NWeb1_txbPinCode').val('"+message.cardPw+"');$jq('#NWeb1_btnDoSignatureByPCSC').focus();";
		var s = document.createElement('script');
		s.appendChild(document.createTextNode(injectedCode));
		(document.head || document.documentElement).appendChild(s);
	}
});

// browser.runtime.sendMessage({askFor: 'cardPw'});

// document.addEventListener('DOMContentLoaded', function() {
	document.addEventListener('submit', function(){
		browser.runtime.sendMessage({
			cardPw: document.getElementById('NWeb1_txbPinCode').value
		});
	});
// });