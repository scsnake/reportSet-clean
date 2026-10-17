// ==UserScript==
// @name          Table Position
// @description   
// @include	http://*/Radiology/RISPatientRegistration.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}


$jq(window).on('focus', function(){
	tablePosition();
});

tablePosition();
setInterval(tablePosition(),3000);

function tablePosition(){
	if($$('UpperBannerInfoTable')){
		$$('UpperBannerInfoTable').style.left='30';
	}
}

void 0;