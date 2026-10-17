/*
 * contentScriptWhen: "start"
 *
 * "start": Load content scripts immediately after the document
 * element is inserted into the DOM, but before the DOM content
 * itself has been loaded
 */

/*
 * use an empty HTMLElement both as a place_holder
 * and a way to prevent the DOM content from loading
 */

if (document.URL.indexOf('SESSION') < 0) {
	var rqst = new XMLHttpRequest();
	rqst.open("GET", document.URL);
	rqst.responseType = 'text';
	rqst.onload = function () {
		if (this.status == 200) {
			// /* edit the document */
			var match = this.response.match(/SESSION=\w+/);
			if (match) {
				var ses = (document.URL.indexOf('?') > -1 ? '&' : '?') + match[0];
				// document.title += ses;
				var sending=browser.runtime.sendMessage({
					'openInIE': document.URL + ses
				});
				sending.then(function () {
						window.close();
					}, function (error) {
						console.log('error open IE' + error);
					});
			}

		}
	};
	rqst.send();
} else {
	var sending = browser.runtime.sendMessage({
		'openInIE': document.URL
	});
	sending.then(function () {
			window.close();
		}, function (error) {
			console.log('error open IE' + error);
		});
}

// sending = browser.runtime.sendMessage({
// 'openInIE': document.URL
// });
// sending.then(function () {
// window.close();
// }, function (error) {
// console.log('error open IE' + error);
// });

// sending.then(function(response){console.log(response);},
// function(error){console.log(`Error: ${error}`);});
