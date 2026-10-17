// ==UserScript==
// @name          VS Confirm List
// @description   
// @include	http://*WebApplication/MedicalRecordManagement/VSConfirmList.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}


space=$$('btnToNonCompleteDis').nextSibling;
info=$$('lbUncompleteInfo');
// win=[];

newButton=document.createElement('INPUT');
newButton.id='btnToAllNonComplete';
newButton.className='buttonBig';
newButton.type='button';
newButton.value='全部開啟';
newButton.onclick=function(){
	var links=$$('gvDischarge').getElementsByTagName('A');
	for (var i=0;i<links.length;i++){
		// alert(links[i].onclick);
		if($jq(links[i]).closest('tr').attr('chosen')==1){continue; }
		
		open(location.href.match(/^http[^\n]+\//) + 
			links[i].getAttributeNode('onclick').nodeValue.match(/VSConfirmTargetPage\.aspx[^\'\"]+/));
		// var win=open(links[i].href);
		// win.onload=function(){
			// win.setInterval(function(){if(win.document.getElementById('NWeb1_ProcedureNoteMainTab_updProcHandler').innerText.indexOf('侵入性處置評估及記錄')>-1 && win.document.getElementById('NWeb1_ProcedureNoteMainTab_ucProcedureAttendingPhysicianConfirm_AttendingPhysicianConfirm').disabled){win.document.getElementById('NWeb1_ProcedureNoteMainTab_ucProcedureProcessRecord_ProcedureProcessRecordSave2').click();}},1000);
		// }
	}
};

info.parentNode.insertBefore(newButton,info);
info.parentNode.insertBefore(space.cloneNode(),info);

clickCache=[];
clickTimeout=0;
function refreshChosen(){
	
	for (var i=0; i<clickCache.length; i++){
		var v = clickCache[i];
		if(v.clickCount % 2 ==1){
			var e = $jq(v.obj);
			if(e.attr('chosen')==1){
				e.css({'background-color': '#eeeeee'});
				e.attr('chosen', 0);
			}else{
				e.css({'background-color': '#333333'});
				e.attr('chosen', 1);
			}
		}
	}
	clickCache=[];
}

var that=0;
$jq('#gvDischarge tr.tableText').on('click', function(event){
	
	var found=false;
	for (var i=0; i<clickCache.length; i++){
		if(clickCache[i].obj===this){
			clickCache[i].clickCount += 1;
			found=true;
			break;
		}
	}
	if(!found){
		clickCache.push({obj: this, clickCount: 1});
	}
	
	
	if(clickTimeout){clearTimeout(clickTimeout);}
	
	clickTimeout = setTimeout(refreshChosen, 500);
	
})


// private use
$jq('#gvDischarge tr.tableText').each(function(i, e){
	if(e.cells[8].innerText.indexOf('主治醫師A')>-1){
		if(e.cells[3].innerText.indexOf('主治醫師B')>-1 || e.cells[3].innerText.indexOf('住院醫師A')>-1){
			e.click();
		}
	}
});


void 0;