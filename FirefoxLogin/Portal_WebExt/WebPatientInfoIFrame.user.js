// ==UserScript==
// @name          Patient Basic Info - IFrame
// @description   
// @include	http://*OtherIndependentProj/PatientBasicInfoEdit/SimpleInfoShowUsingPlaceHolder.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

$jq(document).ready(function(){
	
}).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;

	
	if(e.altKey||e.ctrlKey||e.shiftKey){
		return true;
	}
	
	if(k==36){
		parent.scrollTo(0,0);
		
	}else if(k==35){
		parent.scrollTo(0,9999);		
	}
	
	
}

void 0;