// ==UserScript==
// @name          Drug Info
// @description   
// @include	http://*phar/intranet/druginfo/*
// ==/UserScript==

a=document.getElementsByTagName('input')



$jq(window).on('focus', windowFocus=function(){
	for(var i=0;i<a.length;i++){
		if(a[i].name=='drugname'){
			a[i].select();
			break;
		}
	}
});
windowFocus();


void 0;