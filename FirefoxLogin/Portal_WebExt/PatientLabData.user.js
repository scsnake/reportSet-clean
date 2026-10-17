// ==UserScript==
// @name          Patient Lab Data
// @description   
// @include	http://*Lab/NewQuery*.asp*
// ==/UserScript==



// c=document.all['FrontPage_Form1'];
c=document.forms[0];
url=location.href.match(/[^\?]+/)[0];
c.onsubmit=onSubmit;

function onSubmit(){
	a=document.all['ChartNo'];
	// alert(url+'?ChartNo='+a.value);
	location.href=url+'?ChartNo='+a.value;
	return false;
}

a=document.all['ChartNo'];
a.select();

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	if(k==78||(k>=48&&k<=57)||(k>=96&&k<=105)){
		if($jq(':focus')[0]===a){return true;}
		a.select();
		return true;
	}
	return true;
}

// temp=document.getElementsByTagName('p')[1];
// button=document.createElement('p');
// button.innerHTML="<input type='button' value='test'>";
// temp.parentNode.insertBefore(button,temp.nextSibling);
// button.firstChild.onclick=parseLabData;

// function parseLabData(){
	// alert();
// }

void 0;