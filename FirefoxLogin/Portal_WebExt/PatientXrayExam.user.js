// ==UserScript==
// @name          Patient Xray Exam Report
// @description   
// @include	http://*Xray/XrayExam.asp*
// ==/UserScript==

a=document.getElementsByTagName('input')
b=document.getElementsByTagName('select')
c=document.forms[0];
// url=location.href.match(/[^(&ChartNo)]+/)[0];
oldChartNo=document.all['ChartNo'].value;
c.onsubmit=onSubmit;

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	
	if(k==32){
		onSubmit();
		return e.preventDefault();
	}
}
function onSubmit(){
	a=document.all['ChartNo'];
	// alert(url+'?ChartNo='+a.value);
	if(/ChartNo=(N|n|\d)\d{6}/.test(location.href)){
		url=location.href.replace('ChartNo='+oldChartNo,'ChartNo='+a.value);
	}else{
		url=location.href+'&ChartNo='+a.value;
	}
	location.href=url;
	return false;
}



for(var i=0;i<b.length;i++){
	if(b[i].name=='durnum'){
		b[i].value="12";
		break;
	}
}
for(var i=0;i<a.length;i++){
	if(a[i].name=='dattype'&&a[i].value=='Y'){
		a[i].click();
		break;
	}
}
$jq(window).on('focus', windowFocus=function(){
	for(var i=0;i<a.length;i++){
		if(a[i].name=='ChartNo'){
			a[i].select();
			break;
		}
	}

});
windowFocus();

void 0;