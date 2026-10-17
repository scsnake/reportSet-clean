// ==UserScript==
// @name          Pathology Report
// @description   
// @include	http://*/DigReport/Lab/PathExam.asp*
// @include http://*WebApplication/OtherIndependentProj/MedicalReportQuery/PathExam.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

// window.onfocus=function(){
	// document.all.item('ChartNo').select();
// }


$jq(window).on('focus', function(){
	$$('QueryByChartNo1_txbPatChar').select();
});

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	if(e.ctrlKey || e.altKey ||e.shiftKey){return true;}
	
	if(k==32&&isTextBox){ //space
		$$('QueryByChartNo1_btnPerIDPatChar').click();
		return e.preventDefault();
	}
	
}


void 0;