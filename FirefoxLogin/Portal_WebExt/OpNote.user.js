// ==UserScript==
// @name          Op Note (for PEG)
// @description   
// @include	http://*WebApplication/InPatient/OPManagement/OPNoteInsertUpdate_V2.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

function check(id){if($$(id)){$$(id).checked='checked';}}
function click(id){if($$(id)){$$(id).click();}}
function busy(){if($$('UpdateProgress1').style.display!='none'){return 1;}return 0;}


click('OpNoteUsePhraseSelection1_CloseButton');
if($$('NWeb1_OPNoteControl1_DropDownListDeptCode')){
	$$('NWeb1_OPNoteControl1_DropDownListDeptCode').value='RAD';
	$$('NWeb1_OPNoteControl1_DropDownListDeptCode').onchange();
	setTimeout(selectPEGnote,500);
}
if($$('NWeb1_OPNoteControl1_dtlOPNoteItems_ctl09_dtlOPNoteItemContent_ctl00_txbRecordContent')){
	$$('NWeb1_OPNoteControl1_dtlOPNoteItems_ctl09_dtlOPNoteItemContent_ctl00_txbRecordContent').value='Nil';
}
if($$('NWeb1_OPNoteControl1_dtlOPNoteItems_ctl10_dtlOPNoteItemContent_ctl00_txbRecordContent')){
	$$('NWeb1_OPNoteControl1_dtlOPNoteItems_ctl10_dtlOPNoteItemContent_ctl00_txbRecordContent').value='Minimum';
}




function fillOpVS(){
	if($$('OpNoteDrSelection1_actxbDr1_txbContent')&&!busy()){
		$$('OpNoteDrSelection1_actxbDr1_txbContent').value='000000';
		click('OpNoteDrSelection1_ConfirmEnter');
	}else{
		setTimeout(fillOpVS,500);
	}
}
function selectPEGnote(){
	if($$('OpNoteUsePhraseSelection1_TreeViewOPCommonPhraseCategoryShow1_TreeViewOpMethodCategoryt2')&&$$('OpNoteUsePhraseSelection1_TreeViewOPCommonPhraseCategoryShow1_TreeViewOpMethodCategoryt2').innerText.indexOf('Gastrostomy')>-1&&!busy()){
		click('OpNoteUsePhraseSelection1_TreeViewOPCommonPhraseCategoryShow1_TreeViewOpMethodCategoryt2');
		setTimeout(importPEGnote,500);
	}else{
		setTimeout(selectPEGnote,500);
	}
}
function importPEGnote(){
	if($$('OpNoteUsePhraseSelection1_ConfirmEnter')&&!busy()){
		click('OpNoteUsePhraseSelection1_ConfirmEnter');
		setTimeout(function(){click('NWeb1_OPNoteControl1_dtlOPNoteItems_ctl06_lnkbOPNoteTitle');fillOpVS()},1000);
	}else{
		setTimeout(importPEGnote,500);
	}
}
click('OPNoteSpecimenEditControl1_Ababon');
void 0;