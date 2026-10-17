// ==UserScript==
// @name          Confirm Messages
// @description   
// @include	http://*ShowInfo.aspx*
// @include	http://*ShowAllInfo1time.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

$jq('input:checkbox').prop('checked', true);

$jq(window).focus(function(){
  $jq('#btnConfirm').focus();
});

void 0;