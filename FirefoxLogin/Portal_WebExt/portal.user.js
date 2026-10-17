// ==UserScript==
// @name          portal global functions
// @description   
// @include	http://*hisaw.hospital-n.local*
// @include http://portal.hospital-n.local*
// @include http://portal/*
// ==/UserScript==

String.prototype.trim = function() { return this.replace(/(^\s*)|(\s*$)/g, ""); } 
String.prototype.lTrim = function() { return this.replace(/(^\s*)/g, ""); }       
String.prototype.rTrim = function() { return this.replace(/(\s*$)/g, ""); }       
String.prototype.Trim= function() { return this.lTrim().rTrim(); }  

// sid=location.href.match(/[\?&](SESSION=[^=&]+)&?/i);if(!sid){sid=document.documentElement.innerHTML.match(/(SESSION=[a-zA-Z0-9]+)/i);}if(sid){sid=sid[1];}


// var iframes=[];

// document.body.style.margin='0';
// document.body.style.padding='0';

// for(var i=0;i<6;i++){
	// var div=document.createElement('DIV');
	// var iframe=document.createElement('IFRAME');
	// div.id='iframeDiv'+(i+3);
	// div.style.display='none';
	// div.style.width='100%';
	// div.style.height=document.body.scrollHeight;
	// div.style.position='absolute';
	// div.style.top='0';
	// div.style.overflow='hidden';
	// iframe.id='iframe'+(i+3);
	// iframe.style.width='100%';
	// iframe.style.height='100%';
	// iframe.style.position='fixed';
	// iframe.style.display='block';
	// iframe.scrolling='no';
	// iframe.src='http://portal.hospital-n.local/General/Redirect.aspx?Num='+(i+3)+'&'+sid;
	// div.appendChild(iframe);
	// document.body.appendChild(div);
	// iframes[i]=div;
// }


void 0;