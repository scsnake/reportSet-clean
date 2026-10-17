// ==UserScript==
// @name          Op Order
// @description   
// @include	http://*WebApplication/InPatient/OPManagement/DREnterOPOrder.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

if($$('NWeb1_DataListEnterOperationOrder_ctl00_InputOperationOrderCtrl1_txbOrderCode')){
	$$('NWeb1_DataListEnterOperationOrder_ctl00_InputOperationOrderCtrl1_txbOrderCode').ondblclick=function(){
		this.value='72017C00';
		this.onchange();
	}
	$$('NWeb1_SiteRadioAbdomen').click();
	$$('NWeb1_SideRadioNone').click();
	$$('NWeb1_WoundRadioClean').click();
	$$('NWeb1_DataListEnterOperationOrder_ctl01_LinkButtonDelete').click();
	// $$('NWeb1_SaveUpdateResult').focus();
}



void 0;