// ==UserScript==
// @name          Op Schedule
// @description   
// @include	http://*WebApplication/InPatient/OPManagement/SimpleQueryOpSchedule.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

$$('NWeb1_QueryOPPatListCommon1_txbInputRN').value='28';

$jq(window).on('focus', function(){
	$$('NWeb1_QueryOPPatListCommon1_QueryPersonIDByChartNo1_txbChartNoInput').select();
});

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	activeId=$jq(':focus').attr('id');
	
	
	
	if(e.ctrlKey||e.altKey||e.shiftKey){return;}
	
	if(k==32){   //space
		if(activeId=='NWeb1_QueryOPPatListCommon1_QueryPersonIDByChartNo1_txbChartNoInput'){
			$$('NWeb1_QueryOPPatListCommon1_QueryPersonIDByChartNo1_btnQuery').click();return e.preventDefault();
		}
	}else if(k==13){  //enter
		if(activeId=='NWeb1_QueryOPPatListCommon1_QueryPersonIDByChartNo1_txbChartNoInput'){
			$$('NWeb1_QueryOPPatListCommon1_QueryPersonIDByChartNo1_btnQuery').click();return e.preventDefault();
		}
	}
}

$$('NWeb1_QueryOPPatListCommon1_QueryPersonIDByChartNo1_txbChartNoInput').select();



void 0;