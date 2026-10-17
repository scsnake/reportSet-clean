// ==UserScript==
// @name          TPR
// @description   
// @include	http://*WebApplication/InPatient/Nursing/VitalSign_TPR.aspx*
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



setTimeout(showPrescription,2000);

function showPrescription(){
	a=$$('NWeb1_btnShowPrescription');
	if(a){if(a.value.charCodeAt(0)==39023){a.click();}}
	b=$$('add');
	if(b){if(b.value.charCodeAt(0)==39023){b.click();}}
}


$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	nowURL='InPatient/Nursing/VitalSign_TPR';
	
	
	// if(k!=37||k!=39){return true;}
	var pt=$$('NWeb1_PatientAbstractBasicInfo1_LabelAbstractInfo').innerText.match(/[^\(\s]+/).toString();
	var ptTable=$jq('#NWeb1_PatientAbstractBasicInfo1_MenuPatientListn0Items').find('table')[0].rows;
	var ptCount=ptTable.length;
	var ptArr=[];
	for(var i=0;i<ptCount;i++){
		ptArr.push(ptTable[i].cells[0].innerText.trim().match(/[^_\s]+$/).toString());
	}
	var ptIndex=ptArr.indexOf(pt);
	if(k==37&&ptIndex>0&&(!isTextBox)){
		$jq(ptTable[ptIndex-1]).find('a')[0].click();
	}else if(k==39&&ptIndex>-1&&ptIndex<ptCount-1&&(!isTextBox)){
		$jq(ptTable[ptIndex+1]).find('a')[0].click();
	

	
	}else if(k==53 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
	}else if(k==52 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'ElectronicMedicalReportViewer/MedicalReportContent').replace('&Hosp=','&HospitalCode=').replace(/&EMRPop=[^&]*/,'').replace(/&PersonID=[^&]*/,'').replace(/&AccountIDSE=[^&]*/,'')+'&ChartNo='+chartNo+'&WardCode='+wardNo+'&IntervalDay=-3');
	}else if(k==51 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'InPatient/Ward/DoctorEnterOrder'));
	}else if(k==50 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'InPatient/Ward/MedicationV2'));
	// }else if(k==49 && e.ctrlKey){
		// window.open(location.href.replace(nowURL,'InPatient/Nursing/VitalSign_TPR'));
	}else if(k==192 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
		window.open(location.href.replace(nowURL,'ElectronicMedicalReportViewer/MedicalReportContent').replace('&Hosp=','&HospitalCode=').replace(/&EMRPop=[^&]*/,'').replace(/&PersonID=[^&]*/,'').replace(/&AccountIDSE=[^&]*/,'')+'&ChartNo='+chartNo+'&WardCode='+wardNo+'&IntervalDay=-3');
		window.open(location.href.replace(nowURL,'InPatient/Ward/DoctorEnterOrder'));
		window.open(location.href.replace(nowURL,'InPatient/Ward/MedicationV2'));
		// window.open(location.href.replace(nowURL,'InPatient/Nursing/VitalSign_TPR'));
		
	}
}
	

void 0;