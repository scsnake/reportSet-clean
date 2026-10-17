// ==UserScript==
// @name          Ward
// @description   
// @include	http://*WebApplication/InPatient/Ward/OpenWard.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}


if(/^\w{6}$/.test($$('NWeb1_QueryInPatientPersonAccountControl1_IDInputTextBox').value)){
	userID=$$('NWeb1_QueryInPatientPersonAccountControl1_IDInputTextBox').value;
} else { userID='000000'; }

document.onmousedown=onMouseD;


WHICH_WARD='14B';
b=$$('NWeb1_QueryInPatientPersonAccountControl1_DropListHosp');
c=$$('NWeb1_QueryInPatientPersonAccountControl1_DropListWard');
i1=setInterval(function(){if(b.value!==''){clearInterval(i1);}else{b.value='T0';b.onchange();}routine();},200);
// i2=setInterval(function(){if(c.value.toUpperCase()==WHICH_WARD){clearInterval(i2);}else{c.value=WHICH_WARD;}},200);


// d=$$('NWeb1$QueryInPatientPersonAccountControl1$CheckBoxShowDrMainColumn');
// if(!d.checked){d.click();}

a=$$('NWeb1_QueryInPatientPersonAccountControl1_tbxChartNoInput');
if(a){a.select();}

$jq(window).on('focus', function(){
	a.select();
});


//internal medicine//
//e=$$('NWeb1_QueryInPatientPersonAccountControl1_IDInputTextBox');//
//radiology//
e=$$('NWeb1_QueryInPatientPersonAccountControl1_tbxChartNoInput');//
if(e){e.select();}

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;

		
	if(e.ctrlKey||e.altKey||e.shiftKey){return;}
	
	if(k==32 || k==13){ //space
		if($jq(':focus').attr('id')==='NWeb1_QueryInPatientPersonAccountControl1_tbxChartNoInput'){
			$$('NWeb1_QueryInPatientPersonAccountControl1_QueryAccountByPatientInput').click();
			return e.preventDefault();
		}
	}else if(k==83){  //s
		if(! /^\w{6}$/.test($$('NWeb1_QueryInPatientPersonAccountControl1_IDInputTextBox').value)){
			$$('NWeb1_QueryInPatientPersonAccountControl1_IDInputTextBox').value=userID;
		}
		$$('NWeb1_QueryInPatientPersonAccountControl1_EmpNoCareQueryButton').click();
		return e.preventDefault();
	}else if(k==87){  //w
		$$('NWeb1_QueryInPatientPersonAccountControl1_QueryAccountNoByWardInput').click();
		return e.preventDefault();
	}else if(k==70){
		var answer=prompt('Enter ward','');var option;
		for(var i=0;i<$$('NWeb1_QueryInPatientPersonAccountControl1_DropListWard').length;i++){
			if($$('NWeb1_QueryInPatientPersonAccountControl1_DropListWard').options[i].innerText.indexOf(answer.toUpperCase())>-1){
				$$('NWeb1_QueryInPatientPersonAccountControl1_DropListWard').options[i].selected='selected';
				$$('NWeb1_QueryInPatientPersonAccountControl1_DropListWard').onchange();
				break;
			}
		}
		return e.preventDefault();
	}else if(k==67){  //c
		timeColor=prompt('Color lab/pacs if within ___ hours ?','4');
		timeColor=Number(timeColor);
		if(!timeColor){timeColor=4;}
		
		links=document.getElementsByTagName('a');
		for(var i=0;i<links.length;i++){
			linkTitle=links[i].title;
			if(linkTitle.length>5&&/\((\d+)[^\)]+\)/.test(linkTitle)){
				titleHour=/\((\d+)[^\)]+\)/.exec(linkTitle)[1];
				
				if(titleHour<=timeColor){
					links[i].style.backgroundColor="#CCB433";
				}else{
					links[i].style.backgroundColor="transparent";
				}
			}
		}
		
		return e.preventDefault();
	}
	
	
	
	
}


function addPFE_Chemo(){
	if($$('NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList')){
		for(var i=0;i<$$('NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList').rows.length-1;i++){
			// var div=$$('NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl'+((i+2).pad())+'_PanelDRVIPFlag');
			
			var EMR=$$('NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl'+((i+2).pad())+'_LinkNurElectronicMedicalRecord')||$$('NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl'+((i+2).pad())+'_LinkElectronicMedicalRecord');
			
			var b=document.createElement('A');
			var u=document.createTextNode('化');
			b.href='javascript: return false;';
			b.title='抗癌藥品(黃單)';
			
			b.id='ChemoTreatment'+((i+2).pad());
			b.onclick=function(){
				var match=this.id.match(/ChemoTreatment(\d+)/);
				var vitalSign=$$('NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl'+match[1]+'_LinkVitalSign')||$$('NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl'+match[1]+'_LinkNurVitalSign');
				var url='http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/Chemotherapy/MainPage.aspx?'+(new RegExp('SESSION=\\w+&amp;PatClass=\\w&amp;AccountIDSE=\\w+&amp;PersonID=\\w+&amp;Hosp=\\w+&amp;Seed=\\d+','i').exec(vitalSign.outerHTML)).toString();
				open(url);
			};	
			
			b.appendChild(u);
			EMR.parentNode.insertBefore(b,EMR.nextSibling);	
			
			
			EMR.parentNode.insertBefore(document.createTextNode(' '),EMR.nextSibling);	
			
			
			var a=document.createElement('A');
			var t=document.createTextNode('衛');
			a.href='javascript: return false;';
			a.title='衛教指導紀錄';
			
			a.id='PatientEducation'+((i+2).pad());
			a.onclick=function(){
				var match=this.id.match(/PatientEducation(\d+)/);
				var vitalSign=$$('NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl'+match[1]+'_LinkVitalSign')||$$('NWeb1_QueryInPatientPersonAccountControl1_DataGridAccountList_ctl'+match[1]+'_LinkNurVitalSign');
				var url='http://ihisaw.hospital-n.local/WebApplication/InPatient/Nursing/HealthEducationNote.aspx?'+(new RegExp('SESSION=\\w+&amp;PatClass=\\w&amp;AccountIDSE=\\w+&amp;PersonID=\\w+&amp;Hosp=\\w+&amp;Seed=\\d+','i').exec(vitalSign.outerHTML)).toString();
				open(url);
			};	
			
			a.appendChild(t);
			EMR.parentNode.insertBefore(a,EMR.nextSibling);
			
			
					
			
			// div.appendChild(a);
		}
	}
}
addPFE_Chemo();



function routine(){
	
}


function onMouseD(){
	
}

function addTitle(a,b){
	if(a.title){
		a.title+='\n';
	}
	a.title='Hotkey: '+b;
}
addTitle($$('NWeb1_QueryInPatientPersonAccountControl1_IDInputTextBox'),'s');
addTitle($$('NWeb1_QueryInPatientPersonAccountControl1_QueryAccountNoByWardInput'),'w');







void 0;