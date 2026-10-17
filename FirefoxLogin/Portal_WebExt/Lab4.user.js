// ==UserScript==
// @name          Patient Lab4
// @description   
// @include	http://*WebApplication/ElectronicMedicalReportViewer/MedicalReportOpen.aspx*
// @include	http://*WebApplication/ElectronicMedicalReportViewer/MedicalReportContent.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}




// if(location.href.indexOf('MedicalReportOpen')){
	// ind2=0;
	// int2=setInterval(function(){if(++ind2>10||$$('qtip-0-title')){clearInterval(int2);}$$('qtip-0-title').click();},500);
// }

// if(location.href.indexOf('MedicalReportContent')){
	// ind1=0;
	// int1=setInterval(function(){if(++ind1>10||document.getElementsByTagName('button')[1]){clearInterval(int1);}document.getElementsByTagName('button')[1].click();},500);
// }

setInterval(function(){
	jQuery.curCSS=jQuery.css;
		jQuery.browser=[];
}, 1000);


setTimeout(closeDialog,200);



function closeDialog(){
	if (!$('#headerDialog').length){
		setTimeout(closeDialog,200);
	}else{
		$('#headerDialog').dialog('close');

		a=$$('HeaderTemplate1_txbIDInput');
		if(a){a.select();}
		a=$$('HeaderTemplate1_TextBoxWatermarkExtender1');
		if(a){a.select();}
	}
}

$jq(window).on('focus', function(){
	$$('HeaderTemplate1_txbIDInput').select();
});

$jq(document).on('keydown', function(e){keydown(e);}).on('keydown','#HeaderTemplate1_txbIDInput',function(e){
	if(e.ctrlKey || e.altKey ||e.shiftKey){return true;}
	var k=e.which;
	if(k==13 || k==32){
		$('#HeaderTemplate1_btnQueryAction').click();
		return e.preventDefault();
	}
});
function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	if(e.ctrlKey || e.altKey ||e.shiftKey){return true;}

	
	if(!isTextBox){
		if((k>=96 && k<=105)||(k>=48 && k<=57)||k==78||k==74||k==89){
			$$('HeaderTemplate1_txbIDInput').select();
		}
	
	}

	
}


void 0;