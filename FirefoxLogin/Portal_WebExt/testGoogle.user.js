alert('');
document.getElementById('lst-ib').onblur=function(){
	browser.runtime.sendMessage({
		test: document.getElementById('lst-ib').value.toString()
	});
};