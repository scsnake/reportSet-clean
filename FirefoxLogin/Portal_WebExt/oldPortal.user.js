// ==UserScript==
// @name          N hospital old Portal
// @description   
// @include	http://intra.mc.hospital-n.local/*
// @exclude http://intra.mc.hospital-n.local/DigReport/mainframe.htm
// ==/UserScript==

oldPortalId='000000';
oldPortalPw='MOCK_PASSWORD';


a=document.all.item("uid");
if(a){a.value=oldPortalId;}

b=document.all.item("pwd");
if(b){b.value=oldPortalPw;}

c=document.all.item("form1");
if(c){c.submit();}

// d=document.frames(1)
// if(d&&d.location.href!='http://intra.mc.hospital-n.local/DigReport/mainframe.htm'){
	// d.location.href='http://intra.mc.hospital-n.local/DigReport/mainframe.htm';
// }

// e=document.frames(1).frames(1)
// if(e){e.document.all.item("VSID").value='000000';}

void 0;