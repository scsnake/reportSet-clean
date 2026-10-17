function _inj_load(scripts){
	var j = document.createElement('script');

	j.src = browser.runtime.getURL(scripts[0]);
	j.onload = function() {
		if (scripts[1]){
			_inj_load(scripts.slice(1));
			
		}
		this.remove();
		
	};
	(document.head || document.documentElement).appendChild(j);
	// console.log('load: '+scripts[0]);
}