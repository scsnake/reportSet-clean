// ==UserScript==
// @name          find person
// @description   
// @include	http://*WebApplication/Administration/PersonNH/EmpQuery.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

// setTimeout(function(){$('txbEmpName').select();},500);
window.onload=function(){$$('txbEmpName').focus();$$('txbEmpName').select();};



$jq(window).on('focus', windowFocus=function(){
	$$('txbEmpName').focus();$$('txbEmpName').select();
});
windowFocus();

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	if(e.ctrlKey||e.altKey||e.shiftKey){
		return true;
	}
	else if(k==13){
		if(/^\d+$/.test($$('txbEmpName').value)){
			$$('txbPhsNo').value=$$('txbEmpName').value;
			$$('txbEmpName').value='';$$('txbEngName').value='';
		}else if(/^[a-zA-Z-]+$/.test($$('txbEmpName').value)){
			$$('txbEngName').value=$$('txbEmpName').value;
			$$('txbEmpName').value='';	$$('txbPhsNo').value='';
		}
		return true;
	}
}

void 0;