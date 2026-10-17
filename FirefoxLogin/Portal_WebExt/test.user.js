// ==UserScript==
// @name          test
// @description   
// @include	http://*google*
// ==/UserScript==

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	if(e.ctrlKey){
		return;
	}
}
	

void 0;