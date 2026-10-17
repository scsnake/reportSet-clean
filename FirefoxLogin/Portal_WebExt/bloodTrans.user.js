// ==UserScript==
// @name          patientBloodTrans
// @description   
// @include	http://*WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PatientBloodTrans.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}
sid=location.href.match(/[\?&](SESSION=[^=&]+)&?/i);if(!sid){sid=document.documentElement.innerHTML.match(/(SESSION=[a-zA-Z0-9]+)/i);}if(sid){sid=sid[1];}
info=document.documentElement.innerHTML.match(/(\w\d{6})[^T]+?T\d\s*-\s*([^-\s]+?)\s*-/i);
chartNo=info[1];
wardNo=info[2];


if (!Array.prototype.indexOf)
{
  Array.prototype.indexOf = function(elt /*, from*/)
  {
    var len = this.length;

    var from = Number(arguments[1]) || 0;
    from = (from < 0)
         ? Math.ceil(from)
         : Math.floor(from);
    if (from < 0)
      from += len;

    for (; from < len; from++)
    {
      if (from in this &&
          this[from] === elt)
        return from;
    }
    return -1;
  };
}


$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	if(k==13 && e.ctrlKey){
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
	
	}else if(k==53 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
	}else if(k==52 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'ElectronicMedicalReportViewer/MedicalReportContent').replace('&Hosp=','&HospitalCode=').replace(/&EMRPop=[^&]*/,'').replace(/&PersonID=[^&]*/,'').replace(/&AccountIDSE=[^&]*/,'')+'&ChartNo='+chartNo+'&WardCode='+wardNo+'&IntervalDay=-3');
	}else if(k==51 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'InPatient/Ward/DoctorEnterOrder'));
	}else if(k==50 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'InPatient/Ward/MedicationV2'));
	}else if(k==49 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'InPatient/Nursing/VitalSign_TPR'));
	}else if(k==192 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
		window.open(location.href.replace(nowURL,'ElectronicMedicalReportViewer/MedicalReportContent').replace('&Hosp=','&HospitalCode=').replace(/&EMRPop=[^&]*/,'').replace(/&PersonID=[^&]*/,'').replace(/&AccountIDSE=[^&]*/,'')+'&ChartNo='+chartNo+'&WardCode='+wardNo+'&IntervalDay=-3');
		window.open(location.href.replace(nowURL,'InPatient/Ward/DoctorEnterOrder'));
		window.open(location.href.replace(nowURL,'InPatient/Ward/MedicationV2'));
		window.open(location.href.replace(nowURL,'InPatient/Nursing/VitalSign_TPR'));
		
	
	
	
	}else if(e.ctrlKey||e.altKey||e.shiftKey){
		return true;
	}
}


void 0;