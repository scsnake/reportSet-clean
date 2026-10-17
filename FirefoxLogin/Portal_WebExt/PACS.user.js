// ==UserScript==
// @name          PACS
// @description   
// @include	http://*WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PACSImageShowList.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

function recentImage(reg,n){
	b=$$('BloodCallRecordDataGrid').getElementsByTagName('TR');
	CXRchecked=0;
	for(var i=0;i<b.length;i++){
		if(reg.test(b[i].getElementsByTagName('TD')[4].innerText)){
			b[i].getElementsByTagName('INPUT')[0].click();
			if((++CXRchecked)>=n){
				break;
			}
		}
	}
}


a=document.createElement('input');
a.type='button';a.tabIndex='10';a.className='button';a.id='recentCXR';a.onclick=function(){recentImage(/Chest\s:\s\w+?\sView\s\(\w+?\)/,3);};
a.value='最近'+'3'+'次'+'CXR';
a.title='Hotkey: 1';
$$('ButtonMultiSelect').parentNode.appendChild(a);

a=document.createElement('input');
a.type='button';a.tabIndex='11';a.className='button';a.id='recentKUB';a.onclick=function(){recentImage(/Abdomen:KUB/,3);};
a.value='最近'+'3'+'次'+'KUB';
a.title='Hotkey: 2';
$$('ButtonMultiSelect').parentNode.appendChild(a);

a=document.createElement('input');
a.type='button';a.tabIndex='12';a.className='button';a.id='recentCT';a.onclick=function(){recentImage(/CT[^-]+Contrast-\w+/,3);};
a.value='最近'+'3'+'次'+'CT';
a.title='Hotkey: 3';
$$('ButtonMultiSelect').parentNode.appendChild(a);

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;	
	if(e.ctrlKey||e.altKey||e.shiftKey){
			return true;
	}else if(k==13){
		$$('ButtonMultiSelect').click();
	}else if(k==49){
		$$('recentCXR').click();
	}else if(k==50){
		$$('recentKUB').click();
	}else if(k==51){
		$$('recentCT').click();
	}else if(k==65){
		$$('BloodCallRecordDataGrid_ctl01_LinkButtonAllSelect').click();

	}
}

function addTitle(a,b){
	if(a.title){
		a.title+='\n';
	}
	a.title='Hotkey: '+b;
}
addTitle($$('BloodCallRecordDataGrid_ctl01_LinkButtonAllSelect'),'a');
addTitle($$('ButtonMultiSelect'),'enter');




void 0;