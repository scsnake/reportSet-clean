// ==UserScript==
// @name          ER
// @description   
// @include	http://*WebApplication/Emergency/*
// ==/UserScript==

function $$(x){return document.getElementById(x);}
// String.prototype.trim = function () {
    // return this.replace(/^\s*/, "").replace(/\s*$/, "");
// }
var autocompleteApplied=false;




if(document.title.indexOf('-(HasNotBeenQueried,0001/1/1,待確認) HasNotBeenQueried')>-1){
	document.title = document.title.replace('-(HasNotBeenQueried,0001/1/1,待確認) HasNotBeenQueried','');
}
if(!String.prototype.trim) {
  String.prototype.trim = function () {
    return this.replace(/^\s+|\s+$/g,'');
  };
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

function $$$(x,y){
	if($$(x)){return $$(x);}
	if(!y){y='INPUT';}
	var tmp=document.getElementsByTagName(y);
	for(var i=0;i<tmp.length;i++){
		if(tmp[i].id.indexOf(x)>-1){
			return tmp[i];
		}
	}
}

if (location.href.indexOf('ProgressNote')>-1){

var match=location.href.match(/SESSION=(\w+)/);
var sid=match[1];
var wardUrl='http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/OpenWard.aspx?SESSION='+sid;
var chartNo;

	
function createIframe(){
	if($('#wardIframe').length){return ;}
	return $('<iframe id=wardIframe src="'+wardUrl+'"></iframe>').hide().appendTo('body').load(function(){
		$(this).contents().find('#NWeb1_QueryInPatientPersonAccountControl1_CheckBoxShowDrMainColumn').attr('checked','checked');
	});
}

function searchChartNo(iframe){
	// alert($(iframe).attr('id')+','+chartNo);
	$(iframe).contents().find('#NWeb1_QueryInPatientPersonAccountControl1_tbxChartNoInput').val(chartNo);
	$(iframe).contents().find('#NWeb1_QueryInPatientPersonAccountControl1_QueryAccountByPatientInput').click();
	$(iframe).unbind().load(function(){
		var url=$(iframe).contents().find('#NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl02_LinkProgressNote').attr('onclick').match(/http[^']+/);
		// alert(url);
		if(url!==''){
			location.href=url;
		}
	});
	
}
			




setInterval(VSlist,500);
setInterval(setProcedureName,500);
setInterval(preProcedureAssessment,500);
setInterval(timeOut,500);
setInterval(procedureContents,500);
setInterval(fillVitalSigns,500);
setInterval(expandEdit,500);
setInterval(monitorPostProcedureVitalSigns,200);

var waitClose = function(){
	setTimeout(function(){
		if($('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_lblShowMessage').length && 
		$('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_lblShowMessage').text().indexOf('確認成功')>-1){
			window.close();
		}
	},3000);
};


$(document).dblclick(function(event){
	var source = event.target || event.srcElement;
	if(source.id&&source.id.indexOf('ExecutionDateTime')>-1){
		var d = new Date();

		var month = d.getMonth()+1;
		var day = d.getDate();
		var hour = d.getHours();
		var minute = d.getMinutes();
		var second = d.getSeconds();

		source.value = d.getFullYear() + '/' +
			((''+month).length<2 ? '0' : '') + month + '/' +
			((''+day).length<2 ? '0' : '') + day + ' ' +
			((''+hour).length<2 ? '0' :'') + hour + ':' +
			((''+minute).length<2 ? '0' :'') + minute;
	}else if(source.id&&source.id=='NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy'&&source.value==''){
		if (location.href.indexOf('InPatient')>-1){
			var url=location.href.replace('InsertProgressNoteContent','MedicationV2');
			$.get(url,function(result){
				var table=$(result).find('#NWeb1_OrderEntryCommonSelectionBox_AllergyDataBox_grvAllergyData');
				var allergy=table.find('tr').filter(function(index){
					if (index<1){return false;}
					var t=this.cells[1].innerText.toUpperCase();
					return (t!='NO'&&t!='NIL'&&t!='UNCLEAR'&&t!='無');
				});
				var drugs=allergy.find('td:eq(1)').map(function(){return this.innerText.replace(/\s+\([^\n]+/,'');}).get().join(', ');
				if(drugs!==''){
					$('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val(drugs).parent().find(':radio:eq(1)').attr('checked','checked');
					highlight($('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy')[0]);
				}else{
					$('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val('nil');
					highlight($('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy')[0]);
					setTimeout(function(){$('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val('');},2000);
				}
			});
		}else{
			var url=location.href.replace('InsertProgressNoteContent','QueryPatientBasicInfo');
			$.get(url,function(result){
				var table=$(result).find('#GenerateHtmlForAllergic');
				var allergy=table.find('tr').filter(function(index){
					if (index<2){return false;}
					var t=this.cells[1].innerText.toUpperCase();
					return (t!='NO'&&t!='NIL'&&t!='UNCLEAR'&&t!='NA'&&t!='無'&&t!='不清楚');
				});
				var drugs=allergy.find('td:eq(1)').map(function(){return this.innerText.replace(/\s+\([^\n]+/,'');}).get().join(', ');
				if(drugs!==''){
					$('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val(drugs).parent().find(':radio:eq(1)').attr('checked','checked');
					highlight($('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy')[0]);
				}else{
					$('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val('nil');
					highlight($('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy')[0]);
					setTimeout(function(){$('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val('');},2000);
				}
			});
		}

	}else if ($(source).is($('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm').parent())){
		if($('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm').is(':disabled')){
			
			if($('#ProcedureProcessRecordTable :radio:first:enabled').parent().parent().next().find('textarea').first().val()===''){
				$('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ProcedureProcessRecordSave2').trigger('click');
				var waitForEl = function(selector, callback) {
					if (selector.text().indexOf('暫存成功')>-1) {
						callback();
					} else {
						setTimeout(function() {
							waitForEl(selector, callback);
						}, 100);
					}
				};

				waitForEl($('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_AccessMessage'), function() {
					$('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm').prop('disabled', false).click();
					
					waitClose();
				});
				
			}else{
				$('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm').prop('disabled', false).click();
				waitClose();
			}
			
			

		}
	}
}).on('click','#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm',function(){
	waitClose();
}).on('blur','#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxPainScores, #NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxPainScores', painScoreAsSpO2
).on('blur','#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxTemperature, #NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxTemperature', bodyTemperatureConvert
).on('blur','#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxBloodPressure, #NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxBloodPressure', BPConvert
).on('focus','#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_txbBTableProcedureName',function(){
	if(!autocompleteApplied){
		// use jquery and jquery UI from original page, so use "$"
		var $ele  = $('#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_txbBTableProcedureName');
		$ele.autocomplete({
			source: availableTags
		});
	}else{
		$(document).off('focus','#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_txbBTableProcedureName');
	}
	
	if ($ele.prev().prop('tagName')==='SELECT'){
		$ele.before('<br/>').animate({'width': $ele.closest('div').width()-5});
	}
	
}).on('click', '#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ProcedureProcessRecordSave2', function(){
	var procedureNote=$('#ProcedureProcessRecordTable :radio:first:enabled').parent().parent().next().find('textarea').first();
	
	if($.trim(procedureNote.val())===''){
		procedureNote.val('Please refer to formal reports on PACS.');
		highlight(procedureNote[0]);
		
		var postProcedure=$('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_lblPreAndPostVSEditor');
		var procedure = $('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_lblProcessEditor');
		var procedureSave = $('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_AccessMessage');
		if((postProcedure.text()!=='') && (procedure.text()==='' && procedureSave.text()==='')){
			// console.log($('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_ExecutionDateTime').val());
			var postTime = new Date($('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_ExecutionDateTime').val());
			var proTime = new Date($('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ExecutionDateTime').val());
			if(proTime>postTime){
				$('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ExecutionDateTime').val($('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_ExecutionDateTime').val());
				highlight($('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ExecutionDateTime')[0]);
			}
		}
	}
	
	if($('#ProcedureProcessRecordTable :radio:first:enabled').length && $('#ProcedureProcessRecordTable :radio:checked').length==0){
		$('#ProcedureProcessRecordTable :radio:first:enabled').attr('checked','true');
	}
	
});


var lastKeyCode=0;


$('#NWeb1_btnInsertProcedureNote').click(function(event){
	if(!$$('tblNoteList')){return;}
	priorNoteListCount=$$('tblNoteList').rows.length;
	showLoadingDialog();
	setTimeout(checkNoteLoading,300);
}).animate({'width': 2.0*$('#NWeb1_btnInsertProcedureNote').width(), 
		'height': 1.5*$('#NWeb1_btnInsertProcedureNote').height(), 
		'font-size': '125%', 'font-weight': '700'});

function checkNoteLoading(){
	if($$('tblNoteList').rows.length>priorNoteListCount){
		CloseDialog();

	}else{
		setTimeout(checkNoteLoading,300);
	}
}

function VSlist(){
	if($$('VSlist')&&$$('VSlist').id){return;}
	
	try {
		if(!contacts.length) throw 1;
	}catch(_){
		return;
	}
	
	$('<select id="VSlist">'+VSlistHTML()+'</select>').insertBefore($('#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_tbxVSId')).change(function(){
		$('#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_tbxVSId').val(this.value).change();
		});
}


function setProcedureName(){
	var sel=$$('NWeb1_ProcedureNoteMainTab_ucProcedureHandler_ddlProcedureName');
	if(!sel||sel.value!==''){return;}
	$('#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_ddlProcedureName > option:contains(A-Table)').attr('selected','true').change();
}

function preProcedureAssessment(){

	$('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_radHistoryOfAllergyNo').parent().parent().parent().parent().find('td:has(:radio):not(:has(:radio:checked))').each(function(){
		$(this).find(':radio:first').attr('checked','true');
	});
}

keyUpEle=this;
function expandEdit(){
	$('#NWeb1_ProcedureNoteMainTab_pnlPAPrePhyAss').find('tr:first').find(':text').each(function(){
		if($(this).width()!='250'){$(this).width('250')};
		$(this).keyup(function(){
			keyUpEle=this;
			delay(function(){
				if($.trim(keyUpEle.value)!==''){
					$(keyUpEle).parent().find(':radio:eq(1)').click();
				}else{
					$(keyUpEle).parent().find(':radio:first').click();
				}
			},300);
		});
	});

}
var delay = (function(){
  var timer = 0;
  return function(callback, ms){
    clearTimeout (timer);
    timer = setTimeout(callback, ms);
  };
})();

function timeOut(){
	var timeOutArr=[0,0,3,0,0,2,2];
	$('#NWeb1_ProcedureNoteMainTab_ucProcedureTimeOut_CheckPatientTrue').parent().parent().parent().parent().find('td:has(:radio:enabled)').each(function(i,ele){
		if(!parseInt($(this).find(':radio:enabled').map(function(){return this.checked?1:0;}).get().join(''))){
			$(this).find(':radio:enabled:eq('+timeOutArr[i]+')').attr('checked','true');
		}
	});
}

function procedureContents(){
	// if($('#ProcedureProcessRecordTable :radio:first:enabled').length && $('#ProcedureProcessRecordTable :radio:checked').length==0){
		// $('#ProcedureProcessRecordTable :radio:first:enabled').attr('checked','true');
	// }
	
	// procedureNote=$('#ProcedureProcessRecordTable :radio:first:enabled').parent().parent().next().find('textarea').first();
	// if ($.trim(procedureNote.val())==''){
		// setTimeout(function(){procedureNote.val('Please refer to formal reports on PACS.');},500);
	// }
		
	// if($('#A1010_1_1:enabled').length&&!$('#A1010_1_1').attr('checked')&&!$('#A1010_1_2').attr('checked')){
		// $('#A1010_1_1').attr('checked','true');
	// }
}

function fillVitalSigns(){
	
	if($('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxTemperature').val()==''){
		$('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxTemperature').val('NA').each(function(){highlight(this);});
	}
	if($('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxTemperature').val()==''){
		$('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxTemperature').val('NA').each(function(){highlight(this);});
	}
	if($('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxPainScores').val()==''){
		$('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxPainScores').val('SpO2 ').each(function(){highlight(this);});
	}
	if($('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxPainScores').val()==''){
		$('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxPainScores').val('SpO2 ').each(function(){highlight(this);});
	}
}


var postProcedureData=[];
// var testind=0;
function monitorPostProcedureVitalSigns(){
	if($('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxHeartRate:enabled').length){
		
		var tmp=[];var wiped=0;
		$('#NWeb1_ProcedureNoteMainTab_pnlPAPostVS').find(':text').each(function(i){
			if($.trim($(this).val())==''&&$.trim(postProcedureData[i])!==''&&lastKeyCode!=46&&lastKeyCode!=8){wiped=1;}
			tmp.push($.trim($(this).val()));
			if($(this).is(":focus")){tmp['focus']=this.id;}
		});
		
		if(wiped==1){
			$('#NWeb1_ProcedureNoteMainTab_pnlPAPostVS').find(':text').each(function(i){
				$(this).val($.trim(postProcedureData[i]));
				highlight(this);
			});
			$('#'+postProcedureData['focus']).focus();
		}else{
			postProcedureData=tmp.slice();
			// $('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxBloodPressure').val(++testind);
		}
	}
}



}else{

userID='000000';
sid=location.href.match(/[\?&](SESSION=[^=&]+)&?/i);if(!sid){sid=document.documentElement.innerHTML.match(/(SESSION=[a-zA-Z0-9]+)/i);}if(sid instanceof Array){sid=sid[1];}
if($$$('EmerSimplePatientList1_txtChartNo')){$$$('EmerSimplePatientList1_txtChartNo').select();}


if(location.href.indexOf('EnterPharmacyOrders.aspx')){
	setInterval(checkRestricted,200);
}


detectRestricted=0;
function checkRestricted(){
	if($$$('ContentPlaceHolder1_PreEditCheckBox_ShowMessageBox_dlsShowMessage')&&!detectRestricted){
		detectRestricted=1;
		setTimeout(function(){if($$$('ContentPlaceHolder1_PreEditCheckBox_ShowMessageBox_dlsShowMessage')){$$$('ContentPlaceHolder1_PreEditCheckBox_ShowMessageBox_dlsShowMessage').click();detectRestricted=0;}},500);
	}

}
function busy(){if($$$('UpdateProgress1','DIV').style.display!='none'){return 1;}return 0;}
function hasFound(){
	if(!$$$('grvSearchDrugs','TABLE')){return -1;}
	for(var i=1;i<$$$('grvSearchDrugs','TABLE').getElementsByTagName('TR').length;i++){
		if($$$('grvSearchDrugs','TABLE').getElementsByTagName('TR')[i].getElementsByTagName('TD')[1].innerText.indexOf(drugKeyword)+1){return i;}
	}
	return 0;
}
function tempOrders(){
	if($$$('EditPharmacyOrders1_uPnlOrders','DIV')){
		var ele=$($$$('EditPharmacyOrders1_uPnlOrders','DIV')).find('table:first');
	}else{
		return 0;
	}
	
	var ret=0;
	
	ele.each(function(j){
		if(j==0){return;}
		if(this.className==='tableText'){
			ret++;
		}
	});
	
	return ret;
}
function hasClicked(){
	if($$$('EditPharmacyOrders1_uPnlOrders','DIV')){
		var ele=$($$$('EditPharmacyOrders1_uPnlOrders','DIV')).find('table:first');
	}else{
		return 0;
	}
	
	var ret=0;
	ele.find('tbody>tr').each(function(j){
		if(this.className==='tableText' && this.Cells[3].innerText.indexOf(drugKeyword)>-1){
			var dose=$$$('lvwDrugs_ctrl'+(j)+'_InjectionDetail1_txbDose').value;
			var freq=$$$('lvwDrugs_ctrl'+(j)+'_InjectionDetail1_txbRepeatPatternCode').value; 
			if(dose===''&&freq===''){
				ret=j+1;
				return false;
			}
		}
	});
	
	
	return ret;

}


	
$(window).on('focus', function(){
	if($$$('EmerSimplePatientList1_txtChartNo')){$$$('EmerSimplePatientList1_txtChartNo').select();}

});


setInterval(function(){if($$('Form1')){$$('Form1').onsubmit=checkChartNo;}if($$('aspnetForm')){$$('aspnetForm').onsubmit=checkChartNo;}},500);

setInterval(function(){if($$('PreEditCheckBox_ShowMessageBox_dlsShowMessage_ctl00_btnConfirm')){$$('PreEditCheckBox_ShowMessageBox_dlsShowMessage_ctl00_btnConfirm').click();}},1000);



function checkChartNo(){
	if($$$('EmerSimplePatientList1_txtChartNo')){
		$$$('EmerSimplePatientList1_txtChartNo').value=$$$('EmerSimplePatientList1_txtChartNo').value.toUpperCase().substr(0,7);
		
	}
	// else if($$('ctl00_EmerSimplePatientList1_txtChartNo')){$$('ctl00_EmerSimplePatientList1_txtChartNo').value=$$('ctl00_EmerSimplePatientList1_txtChartNo').value.toUpperCase().substr(0,7);}
	
}

function addTitle(a,b){
	if(!a){return;}
	if(a.title){
		a.title+='\n';
	}
	a.title='Hotkey: '+b;
}


links=document.getElementsByTagName('A');
for(var i=0;i<links.length;i++){
	if(/javascript:PopupHis\([^\)]+WebApplication\/InPatient\/Nursing\/VitalSign_TPR.aspx/.test(links[i].href)){
		TPRlink=links[i];
		addTitle(TPRlink,'Ctrl+1');
		break;
	}
}

if($$('Form1')){
	$$('Form1').onsubmit=function(){
		if($(':focus').attr('id').indexOf('EmerSimplePatientList1_txtChartNo')&&!$$$('EmerSimplePatientList1_txtChartNo','INPUT').value.trim()){
			$$$('EmerSimplePatientList1_PatientListGrid_ctl02_LinkButtonName','A').click();
			return 0;
		}
	}
}
$(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	lastKeyCode=k;
	if(k==13&&e.ctrlKey){
		if($$('EditLabEmgOrders1_btnConfirm')){
			$$('EditLabEmgOrders1_btnConfirm').click();
			return e.preventDefault();
		}
		if($$('EditPharmacyOrders1_btnConfirmTempOrders')){
			$$('EditPharmacyOrders1_btnConfirmTempOrders').click();
			return e.preventDefault();
		}
		if($$('DisplayPharmacyOrders1_btnDoctorConfirm')){
			$$('DisplayPharmacyOrders1_btnDoctorConfirm').click();
			return e.preventDefault();
		}
		
	}
	if(e.ctrlKey||e.altKey||e.shiftKey){
		return;
	}
	
	if(k==13&&($(':focus').attr('id').indexOf('EmerSimplePatientList1_txtChartNo')+1)&&!$$$('EmerSimplePatientList1_txtChartNo','INPUT').value.trim()){
		setTimeout($$$('EmerSimplePatientList1_PatientListGrid_ctl02_LinkButtonName','A').href.replace('javascript:',''),0);
		return e.preventDefault();
	}
	
	
	if(!isTextBox){
		
		
		
		if($$$('PatientMenu1_lblChartNo','SPAN')){
			chartNo=$$$('PatientMenu1_lblChartNo','SPAN').innerText.match(/(N|n|\d)\d{6}/);
		}
		
		
	
	//	2012/6/5  
		if(chartNo){
			if($$$('PatientMenu1_mnuNursen1','TR')){
				personalID=$$$('PatientMenu1_mnuNursen1','TR').innerHTML.match(/PersonID=([^&]+?)/)[1];
				sessionID=$$$('PatientMenu1_mnuNursen1','TR').innerHTML.match(/SESSION=(\w+)/)[1];
			}
			if(k==49&&e.ctrlKey){
				open(TPRlink.href.match(/http[^\']+/));
			}else if(k==50&&e.ctrlKey){
				// medicationWindow=open(location.href);
				// medicationWindow.onload=function(){medicationWindow.document.getElementById('PatientMenu1_btnDrugs').click();};
				open('http://ehisaw.hospital-n.local/WebApplication/Emergency/EnterPharmacyOrders.aspx');
			}else if(k==51&&e.ctrlKey){
				// medicationWindow=open(location.href);
				// medicationWindow.onload=function(){medicationWindow.document.getElementById('PatientMenu1_btnLaboratory').click();};
				open('http://ehisaw.hospital-n.local/WebApplication/Emergency/EnterLabOrders.aspx');
			}else if(k==52&&e.ctrlKey){
				// $$('PatientMenu1_btnPopupReports').click();
				open('http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MedicalReportContent.aspx?HospitalCode=T0&ChartNo='+chartNo[0]+'&PatClass=E&IntervalDay=-1&SESSION='+sessionID);
			}else if(k==53&&e.ctrlKey){
				// $$('PatientMenu1_btnPopupPACs').click();
				open('http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList.aspx?SESSION='+sessionID+'&PersonID='+personalID);
			}else if(k==192 && e.ctrlKey){
			
				open('http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList.aspx?SESSION='+sessionID+'&PersonID='+personalID);
			
				open('http://ihisaw.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MedicalReportContent.aspx?HospitalCode=T0&DeptCode=MED&ChartNo='+chartNo[0]+'&PatClass=E&IntervalDay=-1&SESSION='+sessionID);
				
				open(TPRlink.href.match(/http[^\']+/));
				
			}
		}
		
		if(k==83){  //s
			if($$$('EmerSimplePatientList1_btnQueryByDoctor')){$$$('EmerSimplePatientList1_btnQueryByDoctor').click();}
		}else if(k==67){  //c
			if($$$('PatientMenu1_btnConsult')){$$$('PatientMenu1_btnConsult').click();}
		}else if(k==77){  //m
			if($$$('PatientMenu1_btnGoToMain')){$$$('PatientMenu1_btnGoToMain').click();}
		}else if(k==88){  //x
			if($$$('PatientMenu1_btnPermit')){$$$('PatientMenu1_btnPermit').click();}
		}else if(k==81){  //q
			a=document.getElementsByTagName('A');
			for(var i=0;i<a.length;i++){
				if(/EmerQualityManage.aspx/.test(a[i].href)){
					open(a[i].href);
				}
			}
		}else if(k==80){  //p
			if($$$('PatientMenu1_btnPrintTextOrders')){$$$('PatientMenu1_btnPrintTextOrders').click();}
		}else if(k==68){  //d
			if($$$('PatientMenu1_btnCreateCertificate')){$$$('PatientMenu1_btnCreateCertificate').click();}
		}else if(k==82){  //r
			if($$$('PatientMenu1_btnRadiology')){$$$('PatientMenu1_btnRadiology').click();}
		}else if(k==84){  //t
			if($$$('PatientMenu1_btnTextOrder')){$$$('PatientMenu1_btnTextOrder').click();}
		}else if(k==65){  //a
			if($$$('PatientMenu1_btnAllergy')){$$$('PatientMenu1_btnAllergy').click();}
		}else if(k==72){  //h
			if($$$('PatientMenu1_btnHistory')){$$$('PatientMenu1_btnHistory').click();}
		}else if(k==66){  //b
			if($$$('PatientMenu1_btnBloodOrder')){$$$('PatientMenu1_btnBloodOrder').click();}
		}else if(k==79){  //o
			if($$$('PatientMenu1_btnReserveRegister')){$$$('PatientMenu1_btnReserveRegister').click();}
			
			
		}else if(k==76){
			b=window.getSelection().toString();b=b.match(/(N|n|\d)\d{6}/);if(!b){b=$(':focus').text().match(/(N|n|\d)\d{6}/);}if(b instanceof Array){b=b[0];}
			if(!b){
				if($$('PatientMenu1_lblChartNo')){b=$$('PatientMenu1_lblChartNo').innerText.match(/(N|n|\d)\d{6}/)[0];}
			}
			if(!b){return;}
			b='?ChartNo='+b;
			a=location.href.match(/[\?&](SESSION=[^=&]+)&?/i);if(!a){a=document.documentElement.innerHTML.match(/(SESSION=[a-zA-Z0-9]+)/i);}
			if(a instanceof Array){open('http://portal/DigReport/CheckUser_report.asp?'+a[1]+'&myurl=DigReport/Lab/NewQuery.asp'+b);}
		}else if((k>=96 && k<=105)||(k>=48 && k<=57)||k==78||k==74||k==89){
			if($$$('EmerSimplePatientList1_txtChartNo')){$$$('EmerSimplePatientList1_txtChartNo').select();}
			// else if($$('ctl00_EmerSimplePatientList1_txtChartNo')){$$('ctl00_EmerSimplePatientList1_txtChartNo').focus();}
		}else if(k==37||k==39){shiftPtER(k);}
		
		
		
	}
}

setInterval(loadRoutine,500);
function loadRoutine(){

	if($$('PreEditCheckBox_AbxListBox_dlsList_ctl00_AbxBox_rdbPherQ1Yes')){
		$$('PreEditCheckBox_AbxListBox_dlsList_ctl00_AbxBox_rdbPherQ1Yes').checked=true;
		$$('PreEditCheckBox_AbxListBox_dlsList_ctl00_AbxBox_rdbPherQ2Yes').checked=true;
		$$('PreEditCheckBox_AbxListBox_dlsList_ctl00_AbxBox_rdbPherQ3Yes').checked=true;
	}
		
	if($$('EditLabEmgOrders1_dlsTempOrders')){
		closeLabDetail();
	}
	
	
}

if($$('ModifyStayTwoDaysReason')){
	$$('ModifyStayTwoDaysReason').onclick=function(){setTimeout(function(){window.opener='';window.close();},1500);};
}

function closeLabDetail(){
	a=$$('EditLabEmgOrders1_dlsTempOrders').getElementsByTagName('INPUT');
	for(var i=0;i<a.length;i++){
		if(/EditLabEmgOrders1_dlsTempOrders_ctl\d\d_btnCancel/.test(a[i].id)){
			b=a[i].parentNode.parentNode.parentNode.parentNode.nextSibling.getElementsByTagName('TEXTAREA');
			flag=0;
			for(var j=0;j<b.length;j++){if(b[j].style.backgroundColor){flag++;}}
			if(!flag){
				a[i].click();
			}
			break;
		}
	}

}


if(/Emergency\/EmgChiefComplaint.aspx/.test(location.href)){

	if($$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_txtResident')&&!$$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_txtResident').value){
		$$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_txtResident').value=userID;
	}
	if($$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_EmgPhysicalExam1_rblConsciousness_0')){
		$$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_EmgPhysicalExam1_rblConsciousness_0').click();
	}
	if($$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_EmgPhysicalExam1_ddlGCSE')){
		$$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_EmgPhysicalExam1_ddlGCSE').value='4';
	}
	if($$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_EmgPhysicalExam1_ddlGCSM')){
		$$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_EmgPhysicalExam1_ddlGCSM').value='6';
	}
	if($$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_EmgPhysicalExam1_ddlGCSV')){
		$$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_EmgPhysicalExam1_ddlGCSV').value='5';
	}
	
	if($$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_txtCurrMedication')&&$$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_txtCurrMedication').value.length>3900){
		chopCurrMed();
	}
	
}

function chopCurrMed(){
	currMed=$$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_txtCurrMedication').value;
	i=0;
	currMed=currMed.replace(/\r\n\r\n/g,'@#');
	while(currMed.length>3900){
		currMed=currMed.replace(/@#[^@#]+?$/,'');
		if(++i>1000){
			$$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_txtCurrMedication').value=currMed.substr(0,3890)+'\n...';
			return;
		}
	}
	$$('ctl00_ContentPlaceHolder1_EmgChiefComplaint1_txtCurrMedication').value=currMed.replace(/@#/g,'\r\n\r\n')+'\n...';
}


if(/Emergency\/PermitToDischarge.aspx/.test(location.href)){
	if($$('ckbSelectFirst')){$$('ckbSelectFirst').click();}
}

function shiftPtER(k){
	if(!$$('EmerSimplePatientList1_PatientListGrid')){return;}
	// k=e.which;
	
	pt=$$('PatientMenu1_lblPatientName').innerText.replace(/\(\w\)/,'');
	ptTable=$$('EmerSimplePatientList1_PatientListGrid').rows;
	ptCount=ptTable.length; 
	ptArr=[];
	
	if(ptCount<3||pt==''){return;}
	
	for(var i=1;i<ptCount;i++){
		ptArr.push($(ptTable[i].cells[2]).find('a:first').text());
	}
	ptIndex=ptArr.indexOf(pt);
	if(k==37&&ptIndex>0){
		$(ptTable[ptIndex].cells[2]).find('a:first').click();
	}else if(k==39&&ptIndex>-1&&ptIndex<ptCount-2){
		$(ptTable[ptIndex+2].cells[2]).find('a:first').click();
	}
}

addTitle($$$('PatientMenu1_btnDrugs'),'Ctrl+2');
addTitle($$$('PatientMenu1_btnLaboratory'),'Ctrl+3');
addTitle($$$('PatientMenu1_btnPopupReports'),'Ctrl+4');
addTitle($$$('PatientMenu1_btnPopupPACs'),'Ctrl+5');
addTitle($$$('EmerSimplePatientList1_btnQueryByDoctor'),'s');
addTitle($$$('PatientMenu1_btnGoToMain'),'m');
addTitle($$$('PatientMenu1_btnReserveRegister'),'o');
addTitle($$$('PatientMenu1_btnPermit'),'x');
addTitle($$$('PatientMenu1_btnConsult'),'c');
addTitle($$$('PatientMenu1_btnPrintTextOrders'),'p');
addTitle($$$('PatientMenu1_btnCreateCertificate'),'d');
addTitle($$$('PatientMenu1_btnRadiology'),'r');
addTitle($$$('PatientMenu1_btnBloodOrder'),'b');
addTitle($$$('PatientMenu1_btnTextOrder'),'t');
addTitle($$$('PatientMenu1_btnAllergy'),'a');
addTitle($$$('PatientMenu1_btnHistory'),'h');
a=document.getElementsByTagName('A');
for(var i=0;i<a.length;i++){
	if(/EmerQualityManage.aspx/.test(a[i].href)){
		addTitle(a[i],'q');
	}
}
}

floatPatientInfoDiv($('#NWeb1_uplPatientBasicInfo table'), $(document.body).css('background-color'));
void 0;