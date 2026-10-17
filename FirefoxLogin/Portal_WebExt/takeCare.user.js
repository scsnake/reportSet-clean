// ==UserScript==
// @name          TakeCare
// @description   
// @include	http://*WebApplication/InPatient/Ward/EnterTakeCarePersonInfo.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

sid=location.href.match(/[\?&](SESSION=[^=&]+)&?/i);if(!sid){sid=document.documentElement.innerHTML.match(/(SESSION=[a-zA-Z0-9]+)/i);}if(sid){sid=sid[1];}
accid=location.href.match(/[\?&](AccountIDSE=[^=&]+)&?/i);if(accid){accid=accid[1];}

$$('NWeb1_EnterPersonExcuteInfoUI1_RoleCategoryList_ctl00_RepeaterRoleEmpNo_ctl00_EmpNoInput').focus();
$$('NWeb1_EnterPersonExcuteInfoUI1_RoleCategoryList_ctl00_RepeaterRoleEmpNo_ctl00_EmpNoInput').tabIndex='1';
$$('NWeb1_EnterPersonExcuteInfoUI1_RoleCategoryList_ctl01_RepeaterRoleEmpNo_ctl00_EmpNoInput').tabIndex='2';
$$('NWeb1_EnterPersonExcuteInfoUI1_RoleCategoryList_ctl02_RepeaterRoleEmpNo_ctl00_EmpNoInput').tabIndex='3';


$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	if(k==13 && e.ctrlKey){
		$$('NWeb1_InsertButton').click();
		setTimeout(function(){$$('NWeb1_ReturnToOrigin').click();},1000);
	}

}
	

void 0;