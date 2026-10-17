// ==UserScript==
// @name          
// @description   
// @include	http:///
// ==/UserScript==

function $$(x){return document.getElementById(x);}

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	/*object-related hotkey */
	
	/*hotkey with ctrl or alt or shift or win key*/
	
	/*bypass default hotkey*/
	if(e.ctrlKey||e.altKey||e.shiftKey){return;}
	
	/*hotkey not related with text area*/
	
	/*hotkey not in text area*/
	if(!isTextBox){
		
	}else{ /*hotkey in text area */
	
	}
}

function addTitle(a,b){
	if(a.title){
		a.title+='\n';
	}
	a.title='Hotkey: '+b;
}
addTitle($$(''),'');

void 0;
