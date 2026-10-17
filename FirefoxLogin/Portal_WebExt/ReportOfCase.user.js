// ==UserScript==
// @name          medication
// @description   
// @include	http://*WebApplication/InspectionReport/ReportOfCase.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

$(document).keypress(function(event){
	if(event.which==13){
		if(this.id=='ucQueryHandler_QueryTab_QueryForFilledCase_txbChartNoOrPersonId'){
			$('#ucQueryHandler_QueryTab_QueryForFilledCase_btnQueryFilled').click();
		}else if(this.id=='ucQueryHandler_QueryTab_QueryFromScheduling_txbQueryPat'){
			$('#ucQueryHandler_QueryTab_QueryFromScheduling_btnQuery').click();
		}
	}
});

void 0;