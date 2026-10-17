// ==UserScript==
// @name          report
// @description   
// @include	http://*WebApplication/Administration/UrgentAviso/AvisoPage/AvisoForm.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

dateTime=new Date();
$$('txbHappenDate').value=dateTime.getFullYear()+"/"+(dateTime.getMonth()+1)+"/"+(dateTime.getDay()+1);
$$('txbHappenHour').value=dateTime.getHours();
$$('txbHappenMin').value=dateTime.getMinutes();

$$('chkPersonRole_0').click();
$$('chkPersonEventVenue_5').click();
$$('chkPersonInspectRoom_2').click();
$$('chkPersonAffectPerson_0').click();
$$('rdoPersonAffectHealth_0').click();
$$('rdoPersonAffectHurt_2').click();
$$('chkPersonRelPerson_0').click();
$$('chkPersonRelPerson_1').click();
$$('chkPersonRelPerson_5').click();
$$('chkPersonDoctor_1').click();
$$('chkPersonNurse_1').click();
$$('chkPersonRadiateMan_0').click();
$$('rdoAvisoRole_0').click();



void 0;