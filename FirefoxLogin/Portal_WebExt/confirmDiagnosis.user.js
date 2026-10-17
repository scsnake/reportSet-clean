// ==UserScript==
// @name          confirmDiagnosis
// @description   
// @include http://*WebApplication/InPatient/Ward/ConfirmDiagnosisOrder.aspx*
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
	nowURL='InPatient/Ward/ConfirmDiagnosisOrder';
	if(k==13){
		a=$$('NWeb1_PageLinkAndPrintControl1_wardMenuControlObj_btnTreatment4');
		if(a){a.click();}
	
	
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
		
	}
	else if(k==37||k==39){shiftPt(k);}
	
}


function shiftPt(k){
	// k=e.which;
	
	var pt=$$('NWeb1_PageLinkAndPrintControl1_PatientAbstractBasicInfo1_LabelAbstractInfo').innerText.match(/[^\(\s]+/).toString();
	var ptTable=$jq('#NWeb1_PageLinkAndPrintControl1_PatientAbstractBasicInfo1_MenuPatientListn0Items').find('table')[0].rows;;
	var ptCount=ptTable.length;
	var ptArr=[];
	for(var i=0;i<ptCount;i++){
		ptArr.push(ptTable[i].cells[0].innerText.trim().match(/[^_\s]+$/).toString());
	}
	var ptIndex=ptArr.indexOf(pt);
	if(k==37&&ptIndex>0){
		$jq(ptTable[ptIndex-1]).find('a')[0].click();
	}else if(k==39&&ptIndex>-1&&ptIndex<ptCount-1){
		$jq(ptTable[ptIndex+1]).find('a')[0].click();
	}
}

function unicodes(x,l){
	var a='';
	if(!l){l=x.length;}
	for(var i=0;i<l;i++){
		a+='#'+x.charCodeAt(i);
	}
	return a;
}


if($$('NWeb1_PageLinkAndPrintControl1_wardMenuControlObj_lblMessage') &&$$('NWeb1_PageLinkAndPrintControl1_wardMenuControlObj_lblMessage').innerText && unicodes($$('NWeb1_PageLinkAndPrintControl1_wardMenuControlObj_lblMessage').innerText)!='#30906#35469#23436#25104'){
	$$('NWeb1_PageLinkAndPrintControl1_wardMenuControlObj_lblMessage').style.fontSize='100px';
	alert($$('NWeb1_PageLinkAndPrintControl1_wardMenuControlObj_lblMessage').innerText);
}

function addTitle(a,b){
	if(a.title){
		a.title+='\n';
	}
	a.title='Hotkey: '+b;
}
addTitle($$('NWeb1_PageLinkAndPrintControl1_wardMenuControlObj_btnTreatment4'),'enter');



void 0;
