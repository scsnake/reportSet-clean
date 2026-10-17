// ==UserScript==
// @name          Patient Query after 'Enter'
// @description   
// @include	http://*WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PatientFamilyEducation*
// ==/UserScript==

function $$(x){return document.getElementById(x);}
function $getByName(x){return document.getElementsByName(x)[0];}
// a=$$('NWeb1_PatientBasicInfoQueryByName1');
// if(a){a.parentNode.removeChild(a);}
document.title = '衛教紀錄';

a=$getByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl02');
if(a){
	a.parentNode.removeChild(a.previousSibling);
	a.parentNode.removeChild(a);
}
a=$getByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl03');
if(a){a.parentNode.removeChild(a);}
a=$getByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl04');
if(a){a.parentNode.removeChild(a);}
// b=$$('NWeb1$ChartInputTextBox');
b=$getByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01');
// b.parentNode.removeChild(b.nextSibling);
if(b){b.select();
$jq(b).on('keydown', function(e){return validateForm(e);});
}


$jq(window).on('focus', function(){
	b.select();
});

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;	
	if(e.ctrlKey && k==13){
		if($$('NWeb1_btnSave')){
			$$('NWeb1_btnSave').click();
		}
	}
	
	if(e.ctrlKey || e.altKey ||e.shiftKey){return true;}
	
	
	if(!isTextBox){
		if((k>=96 && k<=105)||(k>=48 && k<=57)||k==78||k==74||k==89){
			$getByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01').select();
		}
	
	}
}

function validateForm(e){
	var c=e.which;
	var l=$getByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01').value.length;
	
	if(c==13 || c==108){
		
		if(l==0){return e.preventDefault();}
		$getByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01').value=$getByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01').value.substr(0,7).toUpperCase();
		$$('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl09').click();
		return e.preventDefault();
	}
	if(c==32){$getByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl09').click();return e.preventDefault();}
	if(l>7){return e.preventDefault();}
	if((c>=48 && c<=57) || (c>=96 && c<=105)){return true;}
	if(c==78 || c==110||c==74){return true;}
	return e.preventDefault();
}

// newTd=$$('NWeb1_PatAccountListRecord1_personidHidden').nextSibling.nextSibling.insertRow(1).insertCell(0);
// newTd.innerHTML='<INPUT style="BACKGROUND-COLOR: #ccccff; FONT-WEIGHT: bold" id=NWeb1_PatAccountListRecord1_ShowRecentRad class=button value=?拙僑?批蔣?賊 type=button>';

if($$('NWeb1_btnAdd')){
	$$('NWeb1_btnAdd').focus();
}

if($$('NWeb1_EducationItems1_ddlSheetType')&&!$$('NWeb1_EducationItems1_ddlSheetType').value){
	$$('NWeb1_EducationItems1_ddlSheetType').value='A02';
	
	var birthDate=/(\d+)\/(\d+)\/(\d+)/.exec($$('NWeb1_LabelPatientBasicInfo').innerText);
	if (birthDate.length==4){
		var birthDay=new Date(birthDate[1],birthDate[2],birthDate[3]);
	}
	var now=new Date();
	
	if(!birthDay||now.getTime()-birthDay.getTime()>=18*365*24*60*60000){
		$$('NWeb1_EducationItems1_ddlGuideObject').value='A00';
	}else{
		$$('NWeb1_EducationItems1_ddlGuideObject').value='A03';
	}
	
	$$('NWeb1_EducationItems1_dgBasicInfo_ctl04_ckItem_0').checked='checked';
	$$('NWeb1_EducationItems1_dgBasicInfo_ctl05_rbItem_0').checked='checked';
	
	$$('NWeb1_EducationItems1_EduItemList_ctl02_rbItem_0').checked='checked';
	$$('NWeb1_EducationItems1_EduItemList_ctl03_ckItem_0').checked='checked';
	$$('NWeb1_EducationItems1_EduItemList_ctl04_ckItem_0').checked='checked';
	
	$$('NWeb1_EducationItems1_EduItemList_ctl04_ckItem_2').checked='checked';
	
	$$('NWeb1_EducationItems1_EduItemList_ctl05_ckItem_2').checked='checked';
	$$('NWeb1_EducationItems1_EduItemList_ctl05_ckItem_9').checked='checked';
	
	$$('NWeb1_EducationItems1_EduItemList_ctl06_rbItem_0').checked='checked';
	$$('NWeb1_EducationItems1_EduItemList_ctl07_ckItem_0').checked='checked';
	
	
	pfe1=document.createElement('INPUT');
	pfe1.type='button';
	pfe1.className='button';
	pfe1.onclick=function(){fillPFE(this);};
	// pfe11.outerHTML='<input type="button" class="button" style="font-weight: bold;" onclick="javascript:fillpfe1(this);" value="CT" />';
	($$('NWeb1_btnRefresh').parentNode.appendChild(pfe1)).value='CT';
	
	(pfe2=pfe1.cloneNode()).onclick=function(){fillPFE(this);};
	($$('NWeb1_btnRefresh').parentNode.appendChild(pfe2)).value='MRI';
	
	
	// td=$$('NWeb1_EducationItems1_panel1').getElementsByTagName('TD');
	// for(i=0;i<td.length;i++){
		// if(td[i].innerText.indexOf('1000')){
			// td[i].appendChild(pfe1);
			// break;
		// }
	// }
	pfe1.click();
	
}

function fillPFE(button){
	if(button.value.indexOf('CT')+1){
		$$('NWeb1_EducationItems1_txtEduContents').value='CT'+'檢查注意事項\n預防跌倒衛教\n施打顯影劑注意事項衛教';
	}else if(button.value.indexOf('MRI')+1){
		$$('NWeb1_EducationItems1_txtEduContents').value='MRI'+'檢查注意事項\n預防跌倒衛教\n施打顯影劑注意事項衛教';
	}
}

function addTitle(a,b){
	if(a.title){
		a.title+='\n';
	}
	a.title='Hotkey: '+b;
}



addTitle($$('NWeb1_btnSave'),'ctrl+enter');






void 0;