// http://stackoverflow.com/questions/5379120/get-the-highlighted-selected-text


function getSelectionText() {
    var text = "";
    var activeEl = document.activeElement;
    var activeElTagName = activeEl ? activeEl.tagName.toLowerCase() : null;
    if (
      (activeElTagName == "textarea") || (activeElTagName == "input" &&
      /^(?:text|search|password|tel|url)$/i.test(activeEl.type)) &&
      (typeof activeEl.selectionStart == "number")
    ) {
        text = activeEl.value.slice(activeEl.selectionStart, activeEl.selectionEnd);
    } else if (window.getSelection) {
        text = window.getSelection().toString();
    }
    return text;
}

document.addEventListener('mouseup', selectedChartNo);
document.addEventListener('keyup', selectedChartNo);
document.addEventListener('selectionchange', selectedChartNo);


function selectedChartNo() {
  var match = getSelectionText().match(/\w\w\d{5}/);
	if(match){
		browser.runtime.sendMessage({
			selectedChartNo: match[0].toUpperCase()
		});
	}
}