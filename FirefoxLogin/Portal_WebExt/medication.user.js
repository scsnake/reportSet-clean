// ==UserScript==
// @name          medication
// @description   
// @include	http://*WebApplication/InPatient/Ward/MedicationV2.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

sid=location.href.match(/[\?&](SESSION=[^=&]+)&?/i);if(!sid){sid=document.documentElement.innerHTML.match(/(SESSION=[a-zA-Z0-9]+)/i);}if(sid){sid=sid[1];}
info=document.documentElement.innerHTML.match(/(\w\d{6})[^T]+?T\d\s*-\s*([^-\s]+?)\s*-/i);
chartNo=info[1];
wardNo=info[2];
oNew=0;
detectRestricted=0;
ordering=0;

$$('Form1').onsubmit=function(){setTimeout(checkDrugCandidate,200);};

function checkDrugCandidate(){
	if($$('NWeb1_MedicationDrugSearchBox_dgrSearchResult_ctl02_btnSelect')){
		$$('NWeb1_MedicationDrugSearchBox_dgrSearchResult_ctl02_btnSelect').focus();
	}else{
		setTimeout(checkDrugCandidate,200);
	}
}

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



setInterval(function(){check();routine();},200);
// setInterval(function(){clickAlert()},1000);

function clickAlert(){
	if(!isBusy()&&$$('NWeb1_PreEditCheckBox_ShowMessageBox_dlsShowMessage_ctl00_btnConfirm')){
		$$('NWeb1_PreEditCheckBox_ShowMessageBox_dlsShowMessage_ctl00_btnConfirm').click();
	}

}


function check(){
	
	if($$('NWeb1_PreEditCheckBox_ShowMessageBox_dlsShowMessage_ctl00_btnConfirm')&&!detectRestricted&&!ordering){
		detectRestricted=1;
		setTimeout(function(){if($$('NWeb1_PreEditCheckBox_ShowMessageBox_dlsShowMessage_ctl00_btnConfirm')){$$('NWeb1_PreEditCheckBox_ShowMessageBox_dlsShowMessage_ctl00_btnConfirm').click();detectRestricted=0;}},500);
	}
	
}


$jq(document).on('keydown', function(e){return keydown(e);}).on('keydown', '#NWeb1_OrderEntryCommonSelectionBox_txbKeywordInput', function(e){
	var k= e.which;
	if(k==13){
		$jq('#NWeb1_OrderEntryCommonSelectionBox_btnKeywordQuery').click();
		e.preventDefault();
	}
});

function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	if(k==27){  //esc
		if($$('NWeb1_MedicationOrderQueryBox_pnlControl')&&$$('NWeb1_MedicationOrderQueryBox_pnlControl').style.display!='none'){
			$$('NWeb1_MedicationOrderQueryBox_btnClose').click();
		}else if($$('NWeb1_MedicationDrugSearchBox_dgrSearchResult_ctl01_btnClose')){
			$$('NWeb1_MedicationDrugSearchBox_dgrSearchResult_ctl01_btnClose').click();
		}
	}else if(k==82 && e.altKey && ($$('NWeb1_RegularEditorBox_btnStore')||$$('NWeb1_MedicationOrderQueryBox_btnChoose')||$$('NWeb1_ChemoEditorBox_btnStore'))){
		if($$('NWeb1_RegularEditorBox_btnStore')){$$('NWeb1_RegularEditorBox_btnStore').click();}
		else if($$('NWeb1_MedicationOrderQueryBox_btnChoose')){$$('NWeb1_MedicationOrderQueryBox_btnChoose').click();}
		else if($$('NWeb1_ChemoEditorBox_btnStore')){$$('NWeb1_ChemoEditorBox_btnStore').click();}
		
		return e.preventDefault();
	}else if(k==13 && e.ctrlKey){
		confirmOrder();
		
	
	}else if(k==53 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
	}else if(k==52 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'ElectronicMedicalReportViewer/MedicalReportContent').replace('&Hosp=','&HospitalCode=').replace(/&EMRPop=[^&]*/,'').replace(/&PersonID=[^&]*/,'').replace(/&AccountIDSE=[^&]*/,'')+'&ChartNo='+chartNo+'&WardCode='+wardNo+'&IntervalDay=-3');
	}else if(k==51 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'InPatient/Ward/DoctorEnterOrder'));
	// }else if(k==50 && e.ctrlKey){
		// window.open(location.href.replace(nowURL,'InPatient/Ward/MedicationV2'));
	}else if(k==49 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'InPatient/Nursing/VitalSign_TPR'));
	}else if(k==192 && e.ctrlKey){
		window.open(location.href.replace(nowURL,'OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList'));
		window.open(location.href.replace(nowURL,'ElectronicMedicalReportViewer/MedicalReportContent').replace('&Hosp=','&HospitalCode=').replace(/&EMRPop=[^&]*/,'').replace(/&PersonID=[^&]*/,'').replace(/&AccountIDSE=[^&]*/,'')+'&ChartNo='+chartNo+'&WardCode='+wardNo+'&IntervalDay=-3');
		window.open(location.href.replace(nowURL,'InPatient/Ward/DoctorEnterOrder'));
		// window.open(location.href.replace(nowURL,'InPatient/Ward/MedicationV2'));
		window.open(location.href.replace(nowURL,'InPatient/Nursing/VitalSign_TPR'));
		
	
	
	}else if(e.ctrlKey||e.altKey||e.shiftKey){
		return true;
	}
	
	if(!isTextBox){
		if(k>64&&k<91){
			$$('NWeb1_OrderEntryCommonSelectionBox_txbKeywordInput').select();
			return true;
		}
		else if(k>=49&&k<=56){setTimeout((k) => {$$('NWeb1_MedicationDrugSearchBox_dgrSearchResult_ctl0'+(k-47)+'_btnSelect').click();},0,k);}
		else if(k==48){setTimeout(function(){$$('NWeb1_MedicationDrugSearchBox_dgrSearchResult_ctl11_btnSelect').click();},0);}
		else if(k==57){setTimeout(function(){$$('NWeb1_MedicationDrugSearchBox_dgrSearchResult_ctl10_btnSelect').click();},0);}
		
		else if(k==37||k==39){shiftPt(k);}
	}
	
}
	


function routine(){
	if($$('NWeb1_PreEditCheckBox_AbxListBox_dlsList_ctl00_AbxBox_rdbPherQ1Yes')){
		$$('NWeb1_PreEditCheckBox_AbxListBox_dlsList_ctl00_AbxBox_rdbPherQ1Yes').checked=true;
		$$('NWeb1_PreEditCheckBox_AbxListBox_dlsList_ctl00_AbxBox_rdbPherQ2Yes').checked=true;
		$$('NWeb1_PreEditCheckBox_AbxListBox_dlsList_ctl00_AbxBox_rdbPherQ3Yes').checked=true;
	}
	if($$('NWeb1_MedicationOrderQueryBox_btnClose')){
		$$('NWeb1_MedicationOrderQueryBox_btnClose').title='Hotkey: esc';
	}
	if($$('NWeb1_MedicationDrugSearchBox_dgrSearchResult_ctl01_btnClose')){
		$$('NWeb1_MedicationDrugSearchBox_dgrSearchResult_ctl01_btnClose').title='Hotkey: esc';
	}
	if($$('NWeb1_RegularEditorBox_btnStore')){
		$$('NWeb1_RegularEditorBox_btnStore').title='Hotkey: Alt+r';
	}
	if($$('NWeb1_ChemoEditorBox_btnStore')){
		$$('NWeb1_ChemoEditorBox_btnStore').title='Hotkey: Alt+r';
	}
	if($$('NWeb1_MedicationOrderQueryBox_btnChoose')){
		$$('NWeb1_MedicationOrderQueryBox_btnChoose').title='Hotkey: Alt+r';
	}
	
	if($$('NWeb1_AbxFormBox_pnlAbxForm')){
		$$('NWeb1_AbxFormBox_pnlAbxForm').style.height='auto';
	}
	
}



function shiftPt(k){
	// k=e.which;
	
	var pt=$$('NWeb1_OrderEntryCommonSelectionBox_PatientAbstractBasicInfo1_LabelAbstractInfo').innerText.match(/[^\(\s]+/).toString();
	var ptTable=$jq('#NWeb1_OrderEntryCommonSelectionBox_PatientAbstractBasicInfo1_MenuPatientListn0Items').find('table')[0].rows;
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


function tempOrders(){
	if($$('NWeb1_RegularEditorBox_EditorInjBox_dgrOrderPlan')){
		var ele=$$('NWeb1_RegularEditorBox_EditorInjBox_dgrOrderPlan');
	}else if($$('NWeb1_ChemoEditorBox_EditorInjBox_dgrOrderPlan')){
		var ele=$$('NWeb1_ChemoEditorBox_EditorInjBox_dgrOrderPlan');
	}else{
		return 0;
	}
	
	var i=0;
	for(var j=1;j<ele.rows.length;j++){
		if(ele.rows[j].className=='tableText'){i++;}
	}
	return i;
}

function hasFound(){
	if(!$$('NWeb1_MedicationDrugSearchBox_dgrSearchResult')){return -1;}
	for(var i=1;i<$$('NWeb1_MedicationDrugSearchBox_dgrSearchResult').getElementsByTagName('TR').length;i++){
		if($$('NWeb1_MedicationDrugSearchBox_dgrSearchResult').getElementsByTagName('TR')[i].getElementsByTagName('TD')[2].innerText.indexOf(drugKeyword)+1){return i;}
	}
	return 0;
}
function hasClicked(){
	if($$('NWeb1_RegularEditorBox_EditorInjBox_dgrOrderPlan')){
		var ele=$$('NWeb1_RegularEditorBox_EditorInjBox_dgrOrderPlan');
		var type='RegularEditorBox';
	}else if($$('NWeb1_ChemoEditorBox_EditorInjBox_dgrOrderPlan')){
		var ele=$$('NWeb1_ChemoEditorBox_EditorInjBox_dgrOrderPlan');
		var type='ChemoEditorBox';
	}else{
		return 0;
	}
	
	for(var j=1;j<ele.rows.length;j++){
		if(ele.rows[j].className=='tableText'&&ele.rows[j].cells[4].innerText.indexOf(drugKeyword)>-1){
			var dose;var freq;
			dose=freq='';
			if($$('NWeb1_'+type+'_EditorInjBox_dgrOrderPlan_ctl'+((j+1).pad())+'_txbDose')){
				dose=$$('NWeb1_'+type+'_EditorInjBox_dgrOrderPlan_ctl'+((j+1).pad())+'_txbDose').value;
			}
			if($$('NWeb1_'+type+'_EditorInjBox_dgrOrderPlan_ctl'+((j+1).pad())+'_txbRepeatPattern')){
				freq=$$('NWeb1_'+type+'_EditorInjBox_dgrOrderPlan_ctl'+((j+1).pad())+'_txbRepeatPattern').value;
			}
			if(dose==''&&freq==''){return j;}
		}
	}
	return 0;

}





////////////////
//0000001 
$('#NWeb1_OrderEntryCommonSelectionBox_PatientAbstractBasicInfo1_LabelAbstractInfo').dblclick(function(){
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


function confirmOrder(){
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
	};}

window.onscroll=function(){
	var top = (document.documentElement && document.documentElement.scrollTop) || 
              document.body.scrollTop;
	if($$('cueOrderConfirm')){
		// $$('cueOrderConfirm').style.top = (top + 30) + 'px';
		$$('cueOrderConfirm').style.top = (top + document.documentElement.clientHeight - 500) + 'px';
	}
};


(function(){
	if($$('cueOrderConfirm')){return;}
	var div;
	document.body.appendChild(div=document.createElement('DIV'));
	div.id='cueOrderConfirm';
	// div.innerText='test';
	// div.style.width='300px';
	// div.style.height='200px';
	div.style.position='absolute';
	div.style.right='0px';
	div.style.border='0px';
	div.style.padding='2px';
	
	div.innerHTML='<input type=button id=confirmOrderButton value="確認醫囑&#x00A;(Ctrl+Enter)" class=button onclick="confirmOrder()" />';
	var top = (document.documentElement && document.documentElement.scrollTop) || 
              document.body.scrollTop;
	// div.style.top=(top+30)+'px';
	div.style.top=(top + document.documentElement.clientHeight-500)+'px';
	$('#confirmOrderButton').width(168).height(100).css({'font-size':'larger','font-family':'微軟正黑體,Calibri,Verdana','background-color': 'rgba(232,255,255,0.5)'});
})();
	
setInterval(checkUnconfirmedOrder,500);
function checkUnconfirmedOrder(){
	var r=false;
	var row,cell;
	
	for(var i=1;i<$$('NWeb1_RegularEditorBox_OrderBox_dgrPhrOrder').rows.length;i++){
		var cell=$$('NWeb1_RegularEditorBox_OrderBox_dgrPhrOrder').rows[i].cells[3];
		if(cell.innerText=='停用' || cell.innerText=='新增') {r=true;break;}
	}
	
	if(r){
		$('#cueOrderConfirm').show();
	}else{
		$('#cueOrderConfirm').hide();
	}
}

function setDrugDate(ind){
	if(ind==''){ind='02';}
	var d=new Date();
	if(d.getDay()==5||d.getDay()==6){
		d=new Date(d.getTime()+(8-d.getDay())*24*60*60000);
	}else{
		d=new Date(d.getTime()+24*60*60000);
	}
	
	$('#NWeb1_RegularEditorBox_EditorInjBox_dgrOrderPlan_ctl'+ind+'_ddlStartDateChar').val(''+(d.getMonth()+1)+(d.getDate()));
	$('#NWeb1_RegularEditorBox_EditorInjBox_dgrOrderPlan_ctl'+ind+'_ddlStartHourChar').val('09');
}

void 0;