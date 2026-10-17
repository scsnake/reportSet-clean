// ==UserScript==
// @name          consult
// @description   
// @include	http://*WebApplication/InPatient/Ward/NotifyOtherDoctor.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

var sid=location.href.match(/[\?&](SESSION=[^=&]+)&?/i);if(!sid){sid=document.documentElement.innerHTML.match(/(SESSION=[a-zA-Z0-9]+)/i);}if(sid){sid=sid[1];}
info=document.documentElement.innerHTML.match(/(\w\d{6})([^T]+T\d\s*-\s*([^-\s]+?)\s*-)?/i);

var chartNo;
var wardNo;
if(info){
  chartNo=info[1];
  wardNo=info[3];
}

// $jq.ajaxSetup({global: true});

$jq(document).ready(function(){
	setTimeout(function(){
		if($jq('#NWeb1_lblMessage').text().indexOf('照會回覆儲存完成')>-1) window.close();
		
		if($jq('#NWeb1_lblPreviousReply').length && $jq('#NWeb1_lblPreviousReply').text().indexOf('上次回覆者:')>-1){
			$jq("html, body").animate({ scrollTop: $jq(document).height()-$jq(window).height() }, 'fast');
		}
	}, 2000);
	
	floatPatientInfoDiv($jq('#Table2'));
	
});

$jq(document).on('click', '#NWeb1_ConfirmReplyContent', function(){
	$jq( window ).on('unload', function( event ) {
    window.close();
	});
});

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	
	
	
	if(k==13 && e.ctrlKey){  //^enter
		oNew=window.open(location.href.replace('MedicationV2.aspx?','OrderConfirm.aspx?ManagerKey=__PageOrderConfirm&')+'&PIN=');
		
		
		oNew.onload=function(){
			oNew.focus();
			function fill0(n,pan){if(!pan){pan=2;}n=''+n;while(n.length<pan){n='0'+n;}return n;}
			for(var i=0;i<oNew.document.getElementById('NWeb1_grvOrders').getElementsByTagName('TR').length-1;i++){
				if(oNew.document.getElementById('NWeb1_grvOrders_ctl'+fill0(i+2)+'_lblCreateEmpName').innerText==oNew.document.getElementById('vertical').innerText){
					oNew.document.getElementById('NWeb1_grvOrders_ctl'+fill0(i+2)+'_ckbSelect').checked=1;
				}else{
					oNew.document.getElementById('NWeb1_grvOrders_ctl'+fill0(i+2)+'_ckbSelect').checked=0;
				}
			}
			oNew.document.getElementById('NWeb1_btnConfirm').click();
			window.setTimeout(function(){window.history.go(0);},1000);
		};	
	
	}else if(k==53 && e.ctrlKey){ //^5
		window.open(location.href.replace(nowURL,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
	}else if(k==52 && e.ctrlKey){ //^4
		window.open(location.href.replace(nowURL,'ElectronicMedicalReportViewer/MedicalReportContent').replace('&Hosp=','&HospitalCode=').replace(/&EMRPop=[^&]*/,'').replace(/&PersonID=[^&]*/,'').replace(/&AccountIDSE=[^&]*/,'')+'&ChartNo='+chartNo+'&WardCode='+wardNo+'&IntervalDay=-3');
	}else if(k==51 && e.ctrlKey){  //^3
		window.open(location.href.replace(nowURL,'InPatient/Ward/DoctorEnterOrder'));
	}else if(k==50 && e.ctrlKey){  //^2
		window.open(location.href.replace(nowURL,'InPatient/Ward/MedicationV2'));
	}else if(k==49 && e.ctrlKey){  //^1
		window.open(location.href.replace(nowURL,'InPatient/Nursing/VitalSign_TPR'));
	}else if(k==192 && e.ctrlKey){  //^`
		window.open(location.href.replace(nowURL,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
		window.open(location.href.replace(nowURL,'ElectronicMedicalReportViewer/MedicalReportContent').replace('&Hosp=','&HospitalCode=').replace(/&EMRPop=[^&]*/,'').replace(/&PersonID=[^&]*/,'').replace(/&AccountIDSE=[^&]*/,'')+'&ChartNo='+chartNo+'&WardCode='+wardNo+'&IntervalDay=-3');
		window.open(location.href.replace(nowURL,'InPatient/Ward/DoctorEnterOrder'));
		window.open(location.href.replace(nowURL,'InPatient/Ward/MedicationV2'));
		window.open(location.href.replace(nowURL,'InPatient/Nursing/VitalSign_TPR'));
		
	
	}else if(e.ctrlKey||e.altKey||e.shiftKey){
		return;
	}
	
	
}

// $jq(document).on('contextmenu', '#NWeb1_ConfirmReplyContent, NWeb1_btnRecordFisrtAnalysisTime', function(e){
	// $jq(document).ajaxSuccess(function( event, xhr, settings ) {
		// window.close()
	// });
	// this.click();
// });
// function waitReplyComplete(e){
	// if ($jq('#NWeb1_lblMessage').text().indexOf('儲存完成')>-1){
		// window.close();
	// }else {
		// setTimeout(function(e){waitReplyComplete(e);}, 1000, e);
	// }
// }


window.onscroll=function(){
	var top = (document.documentElement && document.documentElement.scrollTop) || 
              document.body.scrollTop;
	if($$('floatDiv')){
		// $$('floatDiv').style.top = (top + 30) + 'px';
		$$('floatDiv').style.top = (top + document.documentElement.clientHeight - 220) + 'px';
	}
};

function fill0(n,pan){if(!pan){pan=2;}n=''+n;while(n.length<pan){n='0'+n;}return n;}

floatDiv();
function floatDiv(){
	if($jq('#floatDiv').length){return;}
	
	try {
		if(!contacts.length) throw 1;
	}catch(_){
		setTimeout(floatDiv, 1000);
		return;
	}
	
	var top = (document.documentElement && document.documentElement.scrollTop) || 
              document.body.scrollTop;
	
	$jq('<div/>', {
		id: 'floatDiv', 		
	}).css({
		position: 'absolute',
		top: (top + document.documentElement.clientHeight-220)+'px',
		right: '0px',
		border: 'solid 1px black',
		padding: '2px'
	}).html('<table><tr><td><select id="VSlist" onChange="changeVS(this)">'+VSlistHTML()+'</select></td></tr></table>').appendTo($jq(document.body));
	
}


function changeVS(opt){

	if(!opt.value){return false;}
	
	var j=0;
	for(var i=2;i<100;i++){
		if($$('NWeb1_NotifyDrRecord_ctl'+(i.pad())+'_txbGCAempno')){
			$$('NWeb1_NotifyDrRecord_ctl'+(i.pad())+'_txbGCAempno').value=opt.value;
			$$('NWeb1_NotifyDrRecord_ctl'+(i.pad())+'_btnConfirmGCA').click();
			j=1;
			break;
		}
	}
	
	if(j==0){
		$$('NWeb1_atxbGCAEmpNo_txbContent').value=opt.value;
		$$('NWeb1_atxbGCAEmpNo_txbContent').onchange();
		$$('NWeb1_atxbGCAEmpNo_txbContent').focus();
	}
}



$$('NWeb1_TextboxDescription').value=$$('NWeb1_TextboxDescription').value;
$$('NWeb1_TextboxMainPurpose').value=$$('NWeb1_TextboxMainPurpose').value;

void 0;