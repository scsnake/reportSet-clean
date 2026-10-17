// ==UserScript==
// @name          Progress Note
// @description   
// @include	http://*WebApplication/InPatient/Ward/InsertProgressNoteContent.aspx*
// ==/UserScript==



function $$(x){return document.getElementById(x);}
var newProcedureNote=false;
var match=location.href.match(/SESSION=(\w+)/);var sid;
if(!match){
	sid=match[1];
}else{
	match=$jq('html').html().match(/SESSION=(\w+)/);
	sid=match?match[1]:'';
}
if(sid==''){console.log("Can't get SESSION ID!");}
var wardUrl='http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/OpenWard.aspx?SESSION='+sid;
var chartNo;
var __VIEWSTATE,__EVENTVALIDATION;
var thisData;


var autocompleteApplied=false;

$jq('#NWeb1_btnInsertProcedureNote').animate({'width': 2.0*$jq('#NWeb1_btnInsertProcedureNote').width(), 
		'height': 1.5*$jq('#NWeb1_btnInsertProcedureNote').height(), 
		'font-size': '125%', 'font-weight': '700'});

var waitClose = function(){
	setTimeout(function(){
		if($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_lblShowMessage').length && 
		$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_lblShowMessage').text().indexOf('確認成功')>-1){
			window.close();
		}
	},3000);
};
$jq(document).on('dblclick', function(event){
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
	}else if(source.id&&source.id==='NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy'&&source.value==''){
		if (location.href.indexOf('InPatient')>-1){
			var url=location.href.replace('InsertProgressNoteContent','MedicationV2');
			$.get(url,function(result){
				// console.log($jq(result));
				var table=$jq(result).find('#NWeb1_OrderEntryCommonSelectionBox_AllergyDataBox_grvAllergyData');
				var allergy=table.find('tr').filter(function(index){
					if (index<1){return false;}
					// console.log(this);
					var t=this.cells[1].innerText.toUpperCase();
					return (t!='NO'&&t!='NIL'&&t!='UNCLEAR'&&t!='無');
				});
				var drugs=allergy.find('td:eq(1)').map(function(){return this.innerText.replace(/\s+\([^\n]+/,'');}).get().join(', ');
				if(drugs!==''){
					$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val(drugs).parent().find(':radio:eq(1)').attr('checked','checked');
					highlight($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy')[0]);
				}else{
					$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val('nil');
					highlight($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy')[0]);
					setTimeout(function(){$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val('');},2000);
				}
			});
		}else{
			var url=location.href.replace('InsertProgressNoteContent','QueryPatientBasicInfo');
			$.get(url,function(result){
				var table=$jq(result).find('#GenerateHtmlForAllergic');
				var allergy=table.find('tr').filter(function(index){
					if (index<2){return false;}
					var t=this.cells[1].innerText.toUpperCase();
					return (t!='NO'&&t!='NIL'&&t!='UNCLEAR'&&t!='NA'&&t!='無'&&t!='不清楚');
				});
				var drugs=allergy.find('td:eq(1)').map(function(){return this.innerText.replace(/\s+\([^\n]+/,'');}).get().join(', ');
				if(drugs!==''){
					$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val(drugs).parent().find(':radio:eq(1)').attr('checked','checked');
					highlight($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy')[0]);
				}else{
					$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val('nil');
					highlight($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy')[0]);
					setTimeout(function(){$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxHistoryOfAllergy').val('');},2000);
				}
			});
		}

	}else if (source.id&&source.id==='NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_tbxOtherMajorOrganSystemDisease'&&source.value==''){
		if(/VAB|(localization \(breast\))/i.test($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_txbBTableProcedureName').val())){
			source.value='breast calcifications';
			$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_radOtherMajorOrganSystemDiseaseYes').click();
		}
	}else if ($jq(source).is($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm').parent())){
		if($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm').is(':disabled')){
			

			
			if($jq('#ProcedureProcessRecordTable :radio:first:enabled').parent().parent().next().find('textarea').first().val()===''){
				$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ProcedureProcessRecordSave2').trigger('click');
				var waitForEl = function(selector, callback) {
					if (selector.text().indexOf('暫存成功')>-1) {
						callback();
					} else {
						setTimeout(function() {
							waitForEl(selector, callback);
						}, 100);
					}
				};

				waitForEl($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_AccessMessage'), function() {
					$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm').prop('disabled', false).click();
					
					waitClose();
				});
				
			}else{
				$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm').prop('disabled', false).click();
				waitClose();
			}
			
			

		}
	}
}).on('click','#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm',function(){
	waitClose();
}).on('keydown', function(event){
	lastKeyCode=event.which;
	return true;
}).on('click','#NWeb1_btnInsertProcedureNote', function(){

	newProcedureNote=true;
	return true;
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
		$jq(document).off('focus','#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_txbBTableProcedureName');
	}
	
	if ($ele.prev().prop('tagName')==='SELECT'){
		$ele.before('<br/>').animate({'width': $ele.closest('div').width()-5});
	}
	
}).on('click', '#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_btnSaveProcedureVitalSignAndPainPre', function(){
	// this.click();
	// $jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_AccessMessage').text('暫存成功').css({'color': 'rgb(0,128,0)'});
	
	// setTimeout(function(){
		// procedureNote=$jq('#ProcedureProcessRecordTable :radio:first:enabled').parent().parent().next().find('textarea').first();
		
		// if($jq.trim(procedureNote.val())===''){
			// procedureNote.val('Please refer to formal reports on PACS.');
		// }
		// if($jq('#ProcedureProcessRecordTable :radio:first:enabled').length && $jq('#ProcedureProcessRecordTable :radio:checked').length==0){
			// $jq('#ProcedureProcessRecordTable :radio:first:enabled').attr('checked','true');
		// }
		
		// $jq('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ExecutionDateTime').trigger('dblclick');
		// $jq('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ProcedureProcessRecordSave2').click();
		
	// }, 1000);
	
	
}).on('click', '#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ProcedureProcessRecordSave2', function(){
	var procedureNote=$jq('#ProcedureProcessRecordTable :radio:first:enabled').parent().parent().next().find('textarea').first();
	
	if($jq.trim(procedureNote.val())===''){
		procedureNote.val('Please refer to formal reports on PACS.');
		highlight(procedureNote[0]);
		
		var postProcedure=$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_lblPreAndPostVSEditor');
		var procedure = $jq('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_lblProcessEditor');
		var procedureSave = $jq('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_AccessMessage');
		if((postProcedure.text()!=='') && (procedure.text()==='' && procedureSave.text()==='')){
			// console.log($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_ExecutionDateTime').val());
			var postTime = new Date($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_ExecutionDateTime').val());
			var proTime = new Date($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ExecutionDateTime').val());
			if(proTime>postTime){
				$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ExecutionDateTime').val($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_ExecutionDateTime').val());
				highlight($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ExecutionDateTime')[0]);
			}
		}
	}
	
	if($jq('#ProcedureProcessRecordTable :radio:first:enabled').length && $jq('#ProcedureProcessRecordTable :radio:checked').length==0){
		$jq('#ProcedureProcessRecordTable :radio:first:enabled').attr('checked','true');
	}
	
});

setTimeout(function(){
	var filled=/評估者:.+/;
	var focus='';
	if(filled.test($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_lblPhyPreEditor').text())){
		focus='NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxTemperature';
	}
	if(filled.test($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_lblPreAndPostVSEditor').text())){
		focus='NWeb1_ProcedureNoteMainTab_ucProcedureTimeOut_TimeOutSave';
	}
	if(filled.test($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureTimeOut_lblTimeOutEditor').text())){
		focus='NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ProcedureProcessRecordSave2';
	}
	if($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm').is(':enabled')){
		focus='NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm';
	}
	
	if(focus!==''){
		$jq('#'+focus).focus();
		$jq('html, body').animate({
                    scrollTop: $jq('#'+focus).offset().top
                }, 1000);
	}
	
},1000);

setInterval(addButton,500);
function addButton(){
	if(location.href.indexOf('InPatient')>-1){
		// setTimeout(createIframe,60000);
		if(!$jq('#searchChartNo').length){
			$jq('<input type=button value="搜尋病歷號" id=searchChartNo class=button />').insertAfter($jq('<input type=text id=chartNo class="ui-multiselect ui-widget ui-state-default ui-corner-all" />').insertAfter($jq('#NWeb1_UpdatePanel1')).focus().keydown(function(event){
				if(event.which==13||event.which==32){$jq('#searchChartNo').click();return e.preventDefault();}
			})).click(function(event){
				chartNo=$.trim($jq('#chartNo').val());
				
				if(chartNo==''||chartNo.length!=7){return;}
				
				// if(!$jq('#wardIframe').length){
				
					// createIframe().load(function(){searchChartNo(this);});
				// }else{
					// searchChartNo($jq('#wardIframe')[0]);
				// }
				
				var url='http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/OpenWard.aspx?SESSION='+sid;
				showLoadingDialog();
				$.get(url, function(data){
					__VIEWSTATE=$jq(data).find('#__VIEWSTATE').val();
					__EVENTVALIDATION=$jq(data).find('#__EVENTVALIDATION').val();
					
					
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
							'NWeb1$QueryInPatientPersonAccountControl1$tbxChartNoInput': chartNo,
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
							IDSE=$jq(data).find('#NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl02_LinkConfirmDiagnosisOrder').attr('onclick');
							if(IDSE&&$.isArray(IDSE.match(/AccountIDSE=([^&]+?)&/))){
								location.href='http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/InsertProgressNoteContent.aspx?SESSION='+sid+'&AccountIDSE='+IDSE.match(/AccountIDSE=([^&]+?)&/)[1];
							}else{
								$jq('#chartNo').val('');
								alert('病歷號錯誤!');
							}
					}).fail(function(){
						$jq('#chartNo').val('');
						alert('病歷號錯誤!');
					}).always(function(){
						CloseDialog();
					});
				});
			});
		}
		
		if(!$jq('#NWeb1_btnPopupMedication').length){
			$jq(document.createTextNode(' ')).appendTo($jq('#NWeb1_UpdatePanel1'));
			$jq('<input type=submit class=button value="處" id="NWeb1_btnPopupMedication" />').click(function(e){
				open(location.href.replace('InsertProgressNoteContent','MedicationV2'));
				return e.preventDefault();
			}).appendTo($jq('#NWeb1_UpdatePanel1'));
		}
		
		if(!$jq('#NWeb1_btnPopupDoctorEnterOrder').length){
			$jq(document.createTextNode(' ')).appendTo($jq('#NWeb1_UpdatePanel1'));
			$jq('<input type=submit class=button value="診" id="NWeb1_btnPopupDoctorEnterOrder" />').click(function(e){
				open(location.href.replace('InsertProgressNoteContent','DoctorEnterOrder'));
				return e.preventDefault();
			}).appendTo($jq('#NWeb1_UpdatePanel1'));
		}
	}
}

	
function createIframe(){
	if($jq('#wardIframe').length){return ;}
	return $jq('<iframe id=wardIframe src="'+wardUrl+'"></iframe>').hide().appendTo('body').load(function(){
		$jq(this).contents().find('#NWeb1_QueryInPatientPersonAccountControl1_CheckBoxShowDrMainColumn').attr('checked','checked');
	});
}

function searchChartNo(iframe){
	// alert($jq(iframe).attr('id')+','+chartNo);
	$jq(iframe).contents().find('#NWeb1_QueryInPatientPersonAccountControl1_tbxChartNoInput').val(chartNo);
	$jq(iframe).contents().find('#NWeb1_QueryInPatientPersonAccountControl1_QueryAccountByPatientInput').click();
	$jq(iframe).unbind().load(function(){
		var url=$jq(iframe).contents().find('#NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl02_LinkProgressNote').attr('onclick').match(/http[^']+/);
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
setInterval(expandEdit,1000);
setInterval(monitorPostProcedureVitalSigns,200);





var lastKeyCode=0;

// $jq(document).click(function(){
	// var source = event.target || event.srcElement;
	// if(!$.contains($$('NWeb1_PnlProcedureNoteMainTab'),source)){return;}
	
	// var s=$jq(source);
	// if(s.prop('tagName')=='INPUT'&&s.prop('type')=='text'){
		// s.css({'font-weight':'bold', 'color':'blue'});
	// }else if(s.prop('tagName')=='INPUT'&&s.prop('type')=='radio'){
		// s.css({'border':'1px dashed blue'});
	// }else if(s.prop('tagName')=='INPUT'&&s.prop('type')=='button'){
		// s.css({'border':'1px dashed blue'});
	// }
	

// });


// $jq('#NWeb1_btnInsertProcedureNote').click(function(){
	// if(!$$('tblNoteList')){return;}
	// priorNoteListCount=$$('tblNoteList').rows.length;
	// showLoadingDialog();
	// setTimeout(checkNoteLoading,300);
// });

function checkNoteLoading(){
	if($$('tblNoteList')&&$$('tblNoteList').rows.length>priorNoteListCount){
		// CloseDialog();
		
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
	
	$jq('<select id="VSlist">'+VSlistHTML()+'</select>').insertBefore($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_tbxVSId')).change(function(){
		$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_tbxVSId').val(this.value).change();
		});
}


function setProcedureName(a){
	var sel=$$('NWeb1_ProcedureNoteMainTab_ucProcedureHandler_ddlProcedureName');
	if(!sel||sel.value!==''||!$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_ddlProcedureName').is(':visible')||$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_ddlProcedureName').is(':focus')){
		return;
	}else if(!a){
		setTimeout('setProcedureName(1);',500);
	}else{
		$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureHandler_ddlProcedureName > option:contains(A-Table)').attr('selected','true').change();
	}
}

function preProcedureAssessment(){

	$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureMedicalHistoryPhysiologicalAssessmentPre_radHistoryOfAllergyNo').parent().parent().parent().parent().find('td:has(:radio):not(:has(:radio:checked))').each(function(){
		$jq(this).find(':radio:first').attr('checked','true');
	});
}

var keyUpEle=this;
function expandEdit(){
	$jq('#NWeb1_ProcedureNoteMainTab_pnlPAPrePhyAss').find('tr:first').find(':text').each(function(){
		if($jq(this).width()!='250'){$jq(this).width('250')};
		$jq(this).keyup(function(){
			keyUpEle=this;
			delay(function(){
				if($.trim(keyUpEle.value)!==''){
					$jq(keyUpEle).parent().find(':radio:eq(1)').click();
				}else{
					$jq(keyUpEle).parent().find(':radio:first').click();
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
	if($$('NWeb1_ProcedureNoteMainTab_ucProcedureTimeOut_CheckPatientTrue')&&!$$('NWeb1_ProcedureNoteMainTab_ucProcedureTimeOut_CheckPatientTrue').disabled){ 
		$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureTimeOut_CheckPatientTrue').parent().parent().parent().parent().find('td:has(:radio:enabled)').each(function(i,ele){
			if(!parseInt($jq(this).find(':radio:enabled').map(function(){return this.checked?1:0;}).get().join(''))){
				$jq(this).find(':radio:enabled:eq('+timeOutArr[i]+')').attr('checked','true');
			}
		});
	}
	
}

function procedureContents(){
	// if($jq('#ProcedureProcessRecordTable :radio:first:enabled').length && $jq('#ProcedureProcessRecordTable :radio:checked').length==0){
		// $jq('#ProcedureProcessRecordTable :radio:first:enabled').attr('checked','true');
		// procedureNote=$jq('#ProcedureProcessRecordTable :radio:first:enabled').parent().parent().next().find('textarea').first();
		// if ($.trim(procedureNote.val())==''){
			// setTimeout(function(){procedureNote.val('Please refer to formal reports on PACS.');},500);
			// if(newProcedureNote){
				// setTimeout(function(){$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ProcedureProcessRecordSave2').click();newProcedureNote=false;},600);
			// }
		// }
	// }
	
	
	// if($jq('#A1010_1_1:enabled').length&&!$jq('#A1010_1_1').attr('checked')&&!$jq('#A1010_1_2').attr('checked')){
		// $jq('#A1010_1_1').attr('checked','true');
	// }
}






function fillVitalSigns(){
	
	if($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxTemperature').val()==''){
		$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxTemperature').val('NA').each(function(){highlight(this);});
	}
	if($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxTemperature').val()==''){
		$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxTemperature').val('NA').each(function(){highlight(this);});
	}
	if($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxPainScores').val()==''){
		$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPre_tbxPainScores').val('SpO2 ').each(function(){highlight(this);});
	}
	if($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxPainScores').val()==''){
		$jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxPainScores').val('SpO2 ').each(function(){highlight(this);});
	}
}


var postProcedureData=[];
// var testind=0;
function monitorPostProcedureVitalSigns(){
	if($jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxHeartRate:enabled').length){
		
		var tmp=[];var wiped=0;
		$jq('#NWeb1_ProcedureNoteMainTab_pnlPAPostVS').find(':text').each(function(i){
			if($.trim($jq(this).val())==''&&$.trim(postProcedureData[i])!==''&&lastKeyCode!=46&&lastKeyCode!=8){wiped=1;}
			tmp.push($.trim($jq(this).val()));
			if($jq(this).is(":focus")){tmp['focus']=this.id;}
		});
		
		if(wiped==1){
			$jq('#NWeb1_ProcedureNoteMainTab_pnlPAPostVS').find(':text').each(function(i){
				$jq(this).val($.trim(postProcedureData[i]));
				highlight(this);
			});
			$jq('#'+postProcedureData['focus']).focus();
		}else{
			postProcedureData=tmp.slice();
			// $jq('#NWeb1_ProcedureNoteMainTab_ucProcedureVSPost_tbxBloodPressure').val(++testind);
		}
	}
}



floatPatientInfoDiv($jq('#Table1'), $jq('#Table1').find('td:eq(2)').css('background-color'));


void 0;
