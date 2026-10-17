// ==UserScript==
// @name          N hospital Portal plug-in
// @description   Script to enhance N hospital Portal
// @include       http://hisaw.hospital-n.local/*
// @include       http://portal/*
// @include       http://portal.hospital-n.local/*
// @include       http://ihisaw.hospital-n.local/*
// @include       http://ehisaw.hospital-n.local/*
// @include       http://ehisaw.hospital-n.local/*
// ==/UserScript==

// function disable_refresh(){
	// var c=document.getElementById('NWeb1_ButtonRefresh');
	// if(!c){c.parentNode.removeChild(c);}
// }

/*

function menu2text(limit){
	if(!limit){limit=10;}
	
	var a=document.getElementsByTagName('select');
	for(var i=0;i<a.length;i++){
		var cur=a[i];
		var firstChar=[];
		
		
		if(cur.options.length<=limit){continue;}
		
		setTimeout(cur.id+'Arr=[];',0);
		setTimeout(cur.id+'Arr["outerHTML"]="test"',0);
		for(var j=0;j<cur.options.length;j++){
			var optionText=cur.options[j].text;
			setTimeout(cur.id+'Arr["'+optionText+'"]="'+cur.options[j].value+'"',0);
			if(/[a-zA-Z0-9]/.test(optionText.substr(0,1))){
				firstChar[optionText.substr(0,1).toLowerCase()]++;
			}
		}
		
		setTimeout('dropDownMenu.push('+cur.id+'Arr)',0);
		
		var nw=document.createElement('input');
		nw.type='text';
		nw.name=cur.id;
		cur.parentNode.replaceChild(nw,cur);
			
		
	}
}

*/


// disable_refresh();
//menu2text();
void 0;