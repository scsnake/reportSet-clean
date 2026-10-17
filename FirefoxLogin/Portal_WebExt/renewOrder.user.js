// ==UserScript==
// @name          renewOrder
// @description   
// @include	http://*WebApplication/InPatient/Ward/OrderRenew.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

sid=location.href.match(/[\?&](SESSION=[^=&]+)&?/i);if(!sid){sid=document.documentElement.innerHTML.match(/(SESSION=[a-zA-Z0-9]+)/i);}if(sid){sid=sid[1];}


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
	if(k==67){
		temp=document.getElementsByTagName('input');
		for(var i=0;i<temp.length;i++){
			if(temp[i].type.toUpperCase()=='CHECKBOX'){
				temp[i].checked=!temp[i].checked;
			}
		}
		return e.preventDefault();
	}else if(k==82 && e.altKey){
		$$('NWeb1_btnRenew').click();
		return e.preventDefault();
	}else if(k==13 && e.ctrlKey){
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
		window.open(location.href.replace(/InPatient\/Ward\/OrderRenew/,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
	}else if(k==52 && e.ctrlKey){
		window.open(location.href.replace(/InPatient\/Ward\/OrderRenew[^\/]*PersonID/,'ElectronicMedicalReportViewer/MedicalReportContent.aspx?PatClass=I&PersonID').replace(/&Hosp=T0/,'').replace(/&EMRPop=Y/,'&IntervalDay=-3')+'&'+sid);
	}else if(k==51 && e.ctrlKey){
		window.open(location.href.replace(/Ward\/OrderRenew/,'Ward/DoctorEnterOrder'));
	}else if(k==50 && e.ctrlKey){
		window.open(location.href.replace(/Ward\/OrderRenew/,'Ward/MedicationV2'));
	}else if(k==49 && e.ctrlKey){
		window.open(location.href.replace(/Ward\/OrderRenew/,'Nursing/VitalSign_TPR'));
	}else if(k==192 && e.ctrlKey){
		window.open(location.href.replace(/InPatient\/Ward\/OrderRenew/,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
		window.open(location.href.replace(/InPatient\/Ward\/OrderRenew[^\/]*PersonID/,'ElectronicMedicalReportViewer/MedicalReportContent.aspx?PatClass=I&PersonID').replace(/&Hosp=T0/,'').replace(/&EMRPop=Y/,'&IntervalDay=-3')+'&'+sid);
		window.open(location.href.replace(/Ward\/OrderRenew/,'Ward/DoctorEnterOrder'));
		window.open(location.href.replace(/Ward\/OrderRenew/,'Ward/MedicationV2'));
		window.open(location.href.replace(/Ward\/OrderRenew/,'Nursing/VitalSign_TPR'));	
	
	}else if(e.ctrlKey||e.altKey||e.shiftKey){
		return;
	}else if(k==37||k==39){if(!isTextBox){shiftPt(k);}}
		
}
	


function shiftPt(k){
	// k=e.which;
	
	var pt=$$('NWeb1_PatientAbstractBasicInfo1_LabelAbstractInfo').innerText.match(/[^\(\s]+/).toString();
	var ptTable=$jq('#NWeb1_PatientAbstractBasicInfo1_MenuPatientListn0Items').find('table')[0].rows;
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

function addTitle(a,b){
	if(a.title){
		a.title+='\n';
	}
	a.title='Hotkey: '+b;
}
addTitle($$('NWeb1_btnRenew'),'Alt+r');






void 0;