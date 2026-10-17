// ==UserScript==
// @name          Dr Scheduling
// @description   
// @include	http://*WebApplication/DrScheduling/NoticeDrScheduling.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}



// document.addEventListener("focus",_dom_trackActiveElement,true);
// document.attachEvent("onfocus",_dom_trackActiveElement);
setInterval(_dom_trackActiveElement,200);
lastFocused='';currentFocused=0;

function _dom_trackActiveElement() {	
	var isTextBox = isTextBoxFocused();
    
	if (isTextBox && (currentFocused!==$jq(':focus')[0])) { 
        lastFocused=currentFocused;currentFocused=$jq(':focus')[0];
    }
}


floatDiv();
function floatDiv(){
	if($jq('#floatDiv').length){return;}
	
	try {
		if(!contacts.length) throw 1;
	}catch(_){
		setTimeout(floatDiv, 1000);
		return;
	}
	
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
	}).html('<table><tr><td><select id="VSlist" onChange="fillForm(this)">'+VSlistHTML()+'</select></td></tr><tr><td><select id="Rlist" onChange="fillForm(this)">'+RlistHTML()+'</select></td></tr><tr><td><input type="button" class="buttonMiddle" style="width:100px;height:24px" value="'+'查詢'+'" onclick="searchButton()" /></td></tr></table>')
  .appendTo($jq(document.body));
	
}



function searchButton(){
	$$('NWeb1_QueryNotifyContent').click();
}




function fillForm(opt){
	if(opt.value){
		currentFocused.value=opt.value;
		currentFocused.onchange();
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