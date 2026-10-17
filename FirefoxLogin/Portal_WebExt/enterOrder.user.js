// ==UserScript==
// @name          enterOrder
// @description   
// @include	http://*WebApplication/InPatient/Ward/DoctorEnterOrder.aspx*
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
	if(k==67 && e.altKey){  // !c
		$$('NWeb1_OrderSearch1_btnSelect').click();
		return e.preventDefault();
	}else if(k==82 && e.altKey){  // !r
		$('#NWeb1_EditTempOrders1_btnConfirm').click();
		return e.preventDefault();
	}else if(k==13 && e.ctrlKey){
		oNew=window.open(location.href.replace('DoctorEnterOrder.aspx?','OrderConfirm.aspx?ManagerKey=__PageOrderConfirm&')+'&PIN=');
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
	// }else if(k==51 && e.ctrlKey){
		// window.open(location.href.replace(nowURL,'InPatient/Ward/DoctorEnterOrder'));
	}else if(k==50 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'InPatient/Ward/MedicationV2'));
	}else if(k==49 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'InPatient/Nursing/VitalSign_TPR'));
	}else if(k==192 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
		window.open(location.href.replace(nowURL,'ElectronicMedicalReportViewer/MedicalReportContent').replace('&Hosp=','&HospitalCode=').replace(/&EMRPop=[^&]*/,'').replace(/&PersonID=[^&]*/,'').replace(/&AccountIDSE=[^&]*/,'')+'&ChartNo='+chartNo+'&WardCode='+wardNo+'&IntervalDay=-3');
		// window.open(location.href.replace(nowURL,'InPatient/Ward/DoctorEnterOrder'));
		window.open(location.href.replace(nowURL,'InPatient/Ward/MedicationV2'));
		window.open(location.href.replace(nowURL,'InPatient/Nursing/VitalSign_TPR'));
		
	
	
	}else if(e.ctrlKey||e.altKey||e.shiftKey){
		return;
	}
	
	if(!isTextBox){
		if(k>64&&k<91){
			$('#NWeb1_OrderEntryCommonSelection1_txbKeywordInput').select();
		}else if(k==37||k==39){shiftPt(k);}
	}
		
}
	


setInterval(routine,500);
function routine(){
	$('#NWeb1_EditTempOrders1_btnConfirm').attr('title','Hotkey: Alt+r');
	$('#NWeb1_OrderSearch1_btnSelect').attr('title','Hotkey: Alt+c');
}

function shiftPt(k){
	// k=e.which;
	
	var pt=$$('NWeb1_OrderEntryCommonSelection1_PatientAbstractBasicInfo1_LabelAbstractInfo').innerText.match(/[^\(\s]+/).toString();
	var ptTable=$jq('#NWeb1_OrderEntryCommonSelection1_PatientAbstractBasicInfo1_MenuPatientListn0Items').find('table')[0].rows;
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

$('#NWeb1_OrderEntryCommonSelection1_PatientAbstractBasicInfo1_LabelAbstractInfo').dblclick(function(event){
	var chartNoSearch=prompt('搜尋病歷號','');

	chartNoSearch=$.trim(chartNoSearch);
	
	if(chartNoSearch==''||chartNoSearch.length!=7){return;}
	
	$('#NWeb1_UpdateProgress1').show();
	var url='http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/OpenWard.aspx?'+sid;
	
	$.get(url, function(data){
		__VIEWSTATE=$(data).find('#__VIEWSTATE').val();
		__EVENTVALIDATION=$(data).find('#__EVENTVALIDATION').val();
		
		
		now=new Date();
		
		$.ajax({
			url: url,
			type: 'POST',
			headers: {
				Host: 'ihisaw.hospital-n.local',
				Referer: url
			},
			data: {
				'scrollLeft': '0',
				'scrollTop': '0',
				'__EVENTTARGET': '',
				'__EVENTARGUMENT': '',
				'__LASTFOCUS': '',
				'__VIEWSTATE': __VIEWSTATE,
				'__EVENTVALIDATION': __EVENTVALIDATION,
				'NWeb1$QueryInPatientPersonAccountControl1$DropListHosp': 'T0',
				'NWeb1$QueryInPatientPersonAccountControl1$DropListWard': '',
				'NWeb1$QueryInPatientPersonAccountControl1$SearchDayRangeTextBox': '4',
				'NWeb1$QueryInPatientPersonAccountControl1$PersonIDInput': '',
				'NWeb1$QueryInPatientPersonAccountControl1$AccountIDSEInput': '',
				'NWeb1$QueryInPatientPersonAccountControl1$tbxChartNoInput': chartNoSearch,
				'NWeb1$QueryInPatientPersonAccountControl1$PatientBasicInfoQueryByName1$ctl00': '',
				'NWeb1$QueryInPatientPersonAccountControl1$QueryAccountByPatientInput': '病人查詢',
				'NWeb1$QueryInPatientPersonAccountControl1$OperationRoomInput': '',
				'NWeb1$QueryInPatientPersonAccountControl1$OPDateInput$YearInput': now.getFullYear(),
				'NWeb1$QueryInPatientPersonAccountControl1$OPDateInput$MonthInput': now.getMonth()+1,
				'NWeb1$QueryInPatientPersonAccountControl1$OPDateInput$DayInput': now.getDate(),
				'NWeb1$QueryInPatientPersonAccountControl1$IDInputTextBox': '000000',
				'NWeb1$QueryInPatientPersonAccountControl1$DateTextBoxYearMonthDayInputUI1$YearInput': now.getFullYear(),
				'NWeb1$QueryInPatientPersonAccountControl1$DateTextBoxYearMonthDayInputUI1$MonthInput': now.getMonth()+1,
				'NWeb1$QueryInPatientPersonAccountControl1$DateTextBoxYearMonthDayInputUI1$DayInput': now.getDate(),
				'NWeb1$QueryInPatientPersonAccountControl1$DateTextBoxYearMonthDayInputUI2$YearInput': now.getFullYear(),
				'NWeb1$QueryInPatientPersonAccountControl1$DateTextBoxYearMonthDayInputUI2$MonthInput': now.getMonth()+1,
				'NWeb1$QueryInPatientPersonAccountControl1$DateTextBoxYearMonthDayInputUI2$DayInput': now.getDate(),
				'NWeb1$QueryInPatientPersonAccountControl1$CheckBoxShowDrMainColumn': 'on',
				'NWeb1$QueryInPatientPersonAccountControl1$ShowIntraReportCheck': 'on',
				'NWeb1$QueryInPatientPersonAccountControl1$QueryPersonIDByChartNo1$ChartNoTextBox': '',
				'NWeb1$QueryInPatientPersonAccountControl1$QueryPersonIDByChartNo1$LNameInput': '',
				'NWeb1$QueryInPatientPersonAccountControl1$QueryPersonIDByChartNo1$FNameInput': '',
				'NWeb1$QueryInPatientPersonAccountControl1$QueryPersonIDByChartNo1$BirthDayInput': '',
				'NWeb1$QueryInPatientPersonAccountControl1$HiddenFieldIntraReport': '',
				'NWeb1$Group': 'BySelectPrint',
				'NWeb1$ConditionLevelDropList': '#',
				'NWeb1$DateExecuteSwitchDate$YearInput': now.getFullYear(),
				'NWeb1$DateExecuteSwitchDate$MonthInput': now.getMonth()+1,
				'NWeb1$DateExecuteSwitchDate$DayInput': now.getDate(),
				'NWeb1$OriginalUserID': '',
				'NWeb1$TransferUserID': '',
				'NWeb1$QueryDrIDInfoByDrName1$EmpNoQueryInput': '',
				'NWeb1$DateTextBoxYearMonthDayInputDrugGiven$YearInput': now.getFullYear(),
				'NWeb1$DateTextBoxYearMonthDayInputDrugGiven$MonthInput': now.getMonth()+1,
				'NWeb1$DateTextBoxYearMonthDayInputDrugGiven$DayInput': now.getDate(),
				'NWeb1$PrintStartDate$YearInput': '1500',
				'NWeb1$PrintStartDate$MonthInput': '1',
				'NWeb1$PrintStartDate$DayInput': '1',
				'NWeb1$PrintEndDate$YearInput': now.getFullYear(),
				'NWeb1$PrintEndDate$MonthInput': now.getMonth()+1,
				'NWeb1$PrintEndDate$DayInput': now.getDate()				
			},
			dataType: 'text',
			timeout: 30000
		}).done(function(data,textStatus){
				IDSE=$(data).find('#NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl02_LinkConfirmDiagnosisOrder').attr('onclick');
				if(IDSE&&$.isArray(IDSE.match(/AccountIDSE=([^&]+?)&/))){
					location.href='http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/MedicationV2.aspx?'+sid+'&AccountIDSE='+IDSE.match(/AccountIDSE=([^&]+?)&/)[1];
				}else{
					
					alert('病歷號錯誤!');
				}
		}).fail(function(){
			
			alert('病歷號錯誤!');
		}).always(function(){
			$('#NWeb1_UpdateProgress1').hide();
		});
	});

	
});

void 0;