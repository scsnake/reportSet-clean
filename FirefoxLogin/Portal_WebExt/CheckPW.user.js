// ==UserScript==
// @name          Ward
// @description   
// @include	http://*CheckPassword.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

a=$$('WaitChange');
if(a){a.click();}

void 0;