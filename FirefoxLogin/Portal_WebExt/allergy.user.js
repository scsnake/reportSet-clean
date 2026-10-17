// ==UserScript==
// @name          AllergyMenu
// @description   
// @include	http://*WebApplication/InPatient/Ward/AllergyMenu.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

$$('NWeb1_AllergyDataSource1_rblAllergyDataSource_6').checked=true;
// $$('NWeb1_AllergyUscFood1_rblAllergyFood_1').checked=true;
// $$('NWeb1_AllergyUscDevice1_rblAllergyDevice_1').checked=true;
// $$('NWeb1_AllergyUscBloodType1_rblAllergyBloodType_4').checked=true;
// $$('NWeb1_AllergyUscBloodType1_rblRhType_2').checked=true;
// $$('NWeb1_AllergyUscBloodHistory1_rblAllergyBloodHistory_1').checked=true;

$$('NWeb1_AllergyUscDrug1_rblAllergyDrug_2').click();

b=new Date();
setTimeout(function(){$$('NWeb1_AllergyDataSource1_rblIsInHosp_0').checked=true;$$('NWeb1_AllergyDataSource1_txbOcuDate').value=b.getFullYear()+'/'+(b.getMonth()+1)+'/'+(b.getDate());$$('NWeb1_AllergyUscDrug1_txbDrugSearch').focus();},1000);




void 0;