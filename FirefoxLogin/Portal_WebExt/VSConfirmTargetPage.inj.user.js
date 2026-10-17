
// alert(!!document.getElementById('ifrReporting'));
if(document.getElementById('ifrReporting') && document.getElementById('ifrReporting').src){
	location.href = document.getElementById('ifrReporting').src;
	void 0;
}

_inj_load(['jquery.js', 'VSConfirmTargetPage.user.js']);