// ==UserScript==
// @name          orderConfirm
// @description   
// @include	http:///*WebApplication/InPatient/Ward/OrderConfirm.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

setTimeout(function(){if(/^\s*$/.test($$('NWeb1_upnlOrder').innerText)){window.opener=null;$$('NWeb1_btnClose').click();}},3000);

void 0;