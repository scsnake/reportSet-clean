// ==UserScript==
// @name          Add Op Schedule
// @description   
// @include	http://*WebApplication/InPatient/OPManagement/AddScheduleForSingleInPatient.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

if($$('NWeb1_AddPrepareOPScheduleContent1_DDLAreaCode')){
	$$('NWeb1_AddPrepareOPScheduleContent1_DDLAreaCode').value='E';
	$$('NWeb1_AddPrepareOPScheduleContent1_DDLAreaCode').onchange();
	selectRoom();
}


function selectRoom(){
	if($$('NWeb1_AddPrepareOPScheduleContent1_DDLRoom')&&$$('NWeb1_AddPrepareOPScheduleContent1_DDLRoom').value!='028'){
		$$('NWeb1_AddPrepareOPScheduleContent1_DDLRoom').value='028';
		setTimeout(selectRoom,500);
	}
}

if($$('NWeb1_BtnAddOpNPOtime')){
	$$('NWeb1_BtnAddOpNPOtime').onclick=function(){
		$$('NWeb1_AddOpNPOtime').value=$$('NWeb1_AddPrepareOPScheduleContent1_OPDateTextBox').value+' 00:00';
		return false;
	};
}
if($$('NWeb1_QueryOpModeControl1_DrDeptList')){
	$$('NWeb1_QueryOpModeControl1_DrDeptList').value='RAD';
	$$('NWeb1_QueryOpModeControl1_DrDeptList').onchange();
}

window.onscroll=function(){
	var top = (document.documentElement && document.documentElement.scrollTop) || 
              document.body.scrollTop;
	if($$('floatDiv')){
		// $$('floatDiv').style.top = (top + 30) + 'px';
		$$('floatDiv').style.top = (top + document.documentElement.clientHeight - 220) + 'px';
	}
};

floatDiv();
function floatDiv(){
	if($jq('#floatDiv').length){return;}
	
	try {
		if(!contacts.length) throw 1;
	}catch(_){
		setTimeout(floatDiv, 1000);
		return;
	}
	
	var top = (document.documentElement && document.documentElement.scrollTop) || 
              document.body.scrollTop;
	
	$jq('<div/>', {
		id: 'floatDiv', 		
	}).css({
		position: 'absolute',
		top: (top+30)+'px',
		right: '0px',
		border: 'solid 1px black',
		padding: '2px'
	}).html('<table><tr><td><select id="VSlist" onChange="changeVS(this)">'+VSlistHTML()+'</select></td></tr></table>')
  .appendTo($jq(document.body));
	
}




function changeVS(opt){
	if(opt.value){
		$$('NWeb1_AddPrepareOPScheduleContent1_QueryDrNameByDrCode1_EmpNoQueryInput').value=opt.value;
		$$('NWeb1_AddPrepareOPScheduleContent1_QueryDrNameByDrCode1_EmpNoQueryInput').onchange();
		$$('NWeb1_AddPrepareOPScheduleContent1_QueryDrNameByDrCode1_EmpNoQueryInput').focus();
	}
}

document.onclick=function(){
	var source = event.target || event.srcElement;
	if(source.id=='NWeb1_NewOpSchBtn'){
		var d=new Date($$('NWeb1_AddPrepareOPScheduleContent1_OPDateTextBox').value);
		var day=d.getDay();
		if (day!=1 || day!=4){
			alert('非angioroom全麻日！');
		}
	}
}

void 0;