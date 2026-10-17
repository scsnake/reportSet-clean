// ==UserScript==
// @name          Pre op assessment (for PEG)
// @description   
// @include	http://*WebApplication/InPatient/OPManagement/PreOperativeAssessment.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

function check(id){if($$(id)){$$(id).checked='checked';}}

if($$('NWeb1_SubPhysicalExam_DescriptionTextBox')==''){check('NWeb1_SubPhysicalExam_NormalRadio');}
check('NWeb1_SubBleeding_NoneRadio');
if($$('NWeb1_SubOperationHistory_DescriptionTextBox')==''){check('NWeb1_SubOperationHistory_NoneRadio');}
check('NWeb1_SubBloodTransHistory_NoneRadio');
check('NWeb1_SubBloodReaction_NoneRadio');
check('NWeb1_ClinicSymptom');
check('NWeb1_NoNeedBloodTransRadio');
check('NWeb1_SubPrepareBloodAmount_NoRadio');
check('NWeb1_SubSpecialInstruction_NoRadio');
if($$('NWeb1_TextBoxcClinicSymptom').value==''){
	$$('NWeb1_TextBoxcClinicSymptom').value='dysphagia';
}



void 0;