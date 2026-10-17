// ==UserScript==
// @name          chemotherapy page
// @description   
// @include	http://*OtherIndependentProj/Chemotherapy/MainPage.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

sid=location.href.match(/[\?&](SESSION=[^=&]+)&?/i);if(!sid){sid=document.documentElement.innerHTML.match(/(SESSION=[a-zA-Z0-9]+)/i);}if(sid){sid=sid[1];}
// info=document.documentElement.innerHTML.match(/(\w\d{6})[^T]+?T\d\s*-\s*([^-\s]+?)\s*-/i);
// chartNo=info[1];
// wardNo=info[2];
oNew=0;
detectRestricted=0;

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



$('#PatientInfo').dblclick(function(){
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
					location.href='http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/Chemotherapy/MainPage.aspx?'+sid+'&AccountIDSE='+IDSE.match(/AccountIDSE=([^&]+?)&/)[1]+'&PersonID='+IDSE.match(/PersonID=(\w\d{9})&/)[1];
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