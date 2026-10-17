// ==UserScript==
// @name          HealthEducationNote
// @description   
// @include	http://*WebApplication/InPatient/Nursing/HealthEducationNote.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}
if (!String.prototype.trim) {
  String.prototype.trim = function () {
    return this.replace(/^\s+|\s+$/g, '');
  };
}
function check(str){if($$(str)){$$(str).checked=true;}}
function click(str){if($$(str)){$$(str).click();}}

setInterval(routine,500);
checked=0;

function routine(){
	if(!$('#NWeb1_rbl_SubjectType_4').attr('checked')){
		$('#NWeb1_rbl_SubjectType_4').click();
	}
	
	if($('#NWeb1_lb_SubjectKind').val()!='SS'){
		$('#NWeb1_lb_SubjectKind').val('SS');
		$$('NWeb1_lb_SubjectKind').onchange();
	}
	
	if($$('NWeb1_cbl_LearningWays_L_0')&&!checked){
		check('NWeb1_cbl_LearningWays_L_0');
		check('NWeb1_cbl_LearningWays_L_1');
		check('NWeb1_cbl_LearningResult_L_1');
		check('NWeb1_cbl_LearningResult_L_5');
		check('NWeb1_cbl_AssessmentBasis_L_0');
		check('NWeb1_cbl_AssessmentBasis_L_2');
		checked=1;
	}

}

if($$('NWeb1_tbx_Content_O')){
	$$('NWeb1_tbx_Content_O').ondblclick=education;
}
	

function education(){
	
	if($$('NWeb1_tbx_Content_O')){
		exam=getCheckedText($$('NWeb1_rbl_SubjectList').getElementsByTagName('INPUT')).trim().replace('　','');
		if(exam.indexOf('檢查')>-1){
			$$('NWeb1_tbx_Content_O').value=exam+'注意事項\n預防跌倒衛教\n施打顯影劑注意事項衛教';
		}else{
			$$('NWeb1_tbx_Content_O').value=exam+'檢查注意事項\n預防跌倒衛教\n施打顯影劑注意事項衛教';
		}
	}
	
}



function getCheckedText(radioObj) {
    if(!radioObj)
        return "";
    var radioLength = radioObj.length;
    if(radioLength === undefined)
        if(radioObj.checked)
            return radioObj.value;
        else
            return "";
    for(var i = 0; i < radioLength; i++) {
        if(radioObj[i].checked) {
            return radioObj[i].nextSibling.innerText;
        }
    }
    return "";
}


void 0;