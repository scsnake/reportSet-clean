// ==UserScript==
// @name          focusTextInput
// @description   
// @include http://*WebApplication/InPatient/Ward/MedicationV2.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

  
	k=e.which;
	if(k<65||k>90){return true;}

	if(isTextBox){
    return true;
  }
	b=$$('NWeb1_OrderEntryCommonSelectionBox_txbKeywordInput');
	
	if(b){b.select();return true;}
	
}


void 0;
// setInterval(jumpFocusToTextInput,200);

// function jumpFocusToTextInput(){
	// a=document.activeElement;
	// if(a&&a.type.toUpperCase()=='TEXT'){return true;}
	// b=$$('NWeb1_OrderEntryCommonSelectionBox_txbKeywordInput');
	// if(b){b.focus();return true;}
	// c=$$('NWeb1_OrderEntryCommonSelection1_txbKeywordInput');
	// if(c){c.focus();return true;}
// }
// target1.focus();target2.focus();

