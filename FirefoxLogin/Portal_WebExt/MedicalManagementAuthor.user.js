// ==UserScript==
// @name          MedicalManagementAuthor
// @description   
// @include	http://*WebApplication/OtherIndependentProj/PatientBasicInfoEdit/MedicalManagementAuthor.aspx*
// ==/UserScript==

inputs=document.getElementsByTagName('INPUT');
for(i=0;i<inputs.length;i++){
	if(inputs[i].name=='RBList'&&inputs[i].value=='C5'){
		inputs[i].click();
		break;
	}
}


document.getElementById('ConfirmButton').focus();
document.getElementById('ConfirmButton').click();


void 0;