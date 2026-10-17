// ==UserScript==
// @name          Add Op Schedule
// @description   
// @include	http://*WebApplication/InPatient/OPManagement/AddScheduleForPatientIDOnly.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

$jq('#NWeb1_AddPrepareOPScheduleContent1_DDLHospCode').val('T0').change();


selectFloor();
function selectFloor(){
	if($jq('#NWeb1_AddPrepareOPScheduleContent1_DDLAreaCode').length&&$jq('#NWeb1_AddPrepareOPScheduleContent1_DDLAreaCode').val()!='E'){
		$jq('#NWeb1_AddPrepareOPScheduleContent1_DDLAreaCode').val('E').change();
		setTimeout(selectFloor,500);
	}else{
		selectRoom();
	}
}


function selectRoom(){
	if($jq('#NWeb1_AddPrepareOPScheduleContent1_DDLRoom').length&&$jq('#NWeb1_AddPrepareOPScheduleContent1_DDLRoom').val()!='028'){
		$jq('#NWeb1_AddPrepareOPScheduleContent1_DDLRoom').val('028');
		setTimeout(selectRoom,500);
	}
}


$jq(document).on('click', '#NWeb1_EmerOpScheduleInputItems1_BtnNPOtime', function(e){
	$jq('#NWeb1_EmerOpScheduleInputItems1_txbNPOStartTime').val($jq('#NWeb1_AddPrepareOPScheduleContent1_OPDateTextBox').val()+' 00:00');
	return e.preventDefault();
});
// .on('click', function(event){
	// var source = event.target || event.srcElement;
	// if(source.id=='NWeb1_Add'){
		// var d=new Date($jq('#NWeb1_AddPrepareOPScheduleContent1_OPDateTextBox').val());
		// var day=d.getDay();
		// if (day!=1 || day!=4){
			// alert('非angioroom全麻日！');
		// }
	// }
// });


$jq('#NWeb1_QueryOpModeControl1_DrDeptList').val('RAD').change();
$jq('#NWeb1_EmerOpScheduleInputItems1_ddlEmrLevel').val('5');

window.onscroll=function(){
	var top = (document.documentElement && document.documentElement.scrollTop) || 
              document.body.scrollTop;
		// $jq('#floatDiv').style.top = (top + 30) + 'px';
		$jq('#floatDiv').css({"top": (top + document.documentElement.clientHeight - 220) + "px"});
	
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
	}).html('<table><tr><td><select id="VSlist" onChange="changeVS(this)">'+VSlistHTML()+'</select></td></tr></table>').appendTo($jq(document.body));
	
}



function changeVS(opt){
	if(opt.value){
		$jq('#NWeb1_AddPrepareOPScheduleContent1_QueryDrNameByDrCode1_EmpNoQueryInput').val(opt.value).change().focus();
	}
}


void 0;