// ==UserScript==
// @name          Duty Fee
// @description   
// @include	http://*WebApplication/Administration/SalaryNH/RDoctorDuty.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}




// document.addEventListener("focus",_dom_trackActiveElement,true);
// document.attachEvent("onfocus",_dom_trackActiveElement);
setInterval(_dom_trackActiveElement,200);
lastFocused='';currentFocused=0;

function _dom_trackActiveElement() {	
	var isTextBox = isTextBoxFocused();
    
	if (isTextBox && (currentFocused!==document.activeElement)) { 
        lastFocused=currentFocused;currentFocused=document.activeElement;
    }
}


floatDiv();
function floatDiv(){
	if($jq('#floatDiv').length){return;}
	
	var top = (document.documentElement && document.documentElement.scrollTop) || 
              document.body.scrollTop;
	
	$jq('<div/>', {
		id: 'floatDiv', 		
	}).css({
		position: 'absolute',
		top: (top+115)+'px',
		right: '0px',
		border: 'solid 1px black',
		padding: '2px'
	}).html('<table><tr><td><select id="Rlist" onChange="fillForm(this)">'+RlistHTML()+'</select></td></tr></table>')
  .appendTo($jq(document.body));
	
}


function searchButton(){
	$$('NWeb1_QueryNotifyContent').click();
}



function fillForm(opt){
	if(opt.value){
		$$('txbEmpNo').value=opt.value;
		$$('btnQuery').click();
	}
}


window.onscroll=function(){
	var top = (document.documentElement && document.documentElement.scrollTop) || 
             document.body.scrollTop;
	if($$('floatDiv')){
		$$('floatDiv').style.top = (top + 115) + 'px';
	}
};







void 0;