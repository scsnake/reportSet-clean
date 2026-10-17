// ==UserScript==
// @name          Radiology - Patient Main Page
// @description   
// @include	http://*WebApplication/Radiology/PatientMainPage.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

var tempOrderCount=tmpA=tmpB=tmpB2=0;


biggerButtonWidth=150;
biggerButtonHeight=50;
$jq('#NWeb1_UpdateNHIFile, #NWeb1_btnAllergy, #NWeb1_ReturnToFirstPage').css({
  width: biggerButtonWidth,
  height: biggerButtonHeight
});
$jq('#NWeb1_btnIReport').css({
	width: '200',
	height: biggerButtonHeight
});


newTr=$jq('#NWeb1_PatientLogin').closest('table')[0].insertRow(1);
newTd=newTr.insertCell(0);
newTd.className='tableText';
newTd.align='right';
newTd.innerText='CT';
newTd=newTr.insertCell(1);
newTd.align='left';
newTd.id='CToptions';
newTd.innerHTML='<INPUT type="radio" id="withContrast" name="withwithoutContrast" value="with" checked="checked"><label onclick="javascript:clickRadio(this);">with</label>';
newTd.innerHTML+='<INPUT type="radio" id="withoutContrast" name="withwithoutContrast" value="without"><label onclick="javascript:clickRadio(this);">without</label>';
newTd.innerHTML+='<INPUT type="radio" id="withwithoutContrast" name="withwithoutContrast" value="withoutwith"><label onclick="javascript:clickRadio(this);">without/with</label><span>&nbsp;&nbsp;&nbsp;</span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="B" title="brain" type="button" onclick="javascript:CTclick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="N" title="neck" type="button" onclick="javascript:CTclick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="C" title="chest" type="button" onclick="javascript:CTclick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="A" title="abdomen" type="button" onclick="javascript:CTclick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="P" title="pelvis" type="button" onclick="javascript:CTclick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="UE" title="upper extremity" type="button" onclick="javascript:CTclick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="LE" title="lower extremity" type="button" onclick="javascript:CTclick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="Perf" title="perfusion" type="button" onclick="javascript:CTclick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="C Sp" title="C spine" type="button" onclick="javascript:CTclick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="T Sp" title="T spine" type="button" onclick="javascript:CTclick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:50" value="L Sp" title="L spine" type="button" onclick="javascript:CTclick(this);"><span> </span>';
CTarr=[['33071B0M','33071B1M','33071B2M','33071B3M','33071B5M','33071BXM','33071BWM','33072BYM','33071BRM','33071BSM','33071BTM'],['33070B0M','33070B1M','33070B2M','33070B3M','33070B5M','33070BXM','33070BYM','33072BYM','33070BWM','33070BSM','33070BTM'],['33072B0M','33072B1M','33072B2M','33072B3M','33072B5M','33072BWM','33072BQM','33072BYM','33072BRM','33072BSM','33072BTM']];

function clickRadio(e){
	e.previousSibling.click();
	e.previousSibling.focus();
}

function CTclick(e){
	var i=-1;
	$jq('[name="withwithoutContrast"').each(function(ind){
		if (this.checked){
			i=ind;
			return false;
		}
	});
	if(i==-1){return false;}
	
	var j=-1;
	$jq('#CToptions').find('input').each(function(ind){
		if(ind>=3 && this.value==e.value){
			j=ind;
			return false;
		}
	})
	if(j==-1){return false;}
	
	tempOrderCount=$jq('#NWeb1_AppendEditOrders1_grvTempOrders').find('tr').length | 1;
	
	
	$$('NWeb1_AppendSearchOrders1_ddlOrderType').selectedIndex=3;
	$$('NWeb1_AppendSearchOrders1_txbKeyword').value=CTarr[i][j-3];
	$$('NWeb1_AppendSearchOrders1_btnQuery').click();
	
	setTimeout(fA(),200);
	
	
}

function fA(){
	var c=(tempOrderCount+1).toString();
	c=c.length==1?'0'+c:c;
	if($$('NWeb1_AppendEditOrders1_grvTempOrders_ctl'+c+'_rptSubOrders_ctl00_txbSubOrderValue')){
		
		// $$('NWeb1_AppendEditOrders1_grvTempOrders_ctl'+c+'_rptSubOrders_ctl00_txbSubOrderValue').value='...';
		// $$('NWeb1_AppendEditOrders1_grvTempOrders_ctl'+c+'_rptSubOrders_ctl01_txbSubOrderValue').value='...';
		$$('NWeb1_AppendEditOrders1_btnConfirm').focus();
	}
	else{setTimeout(fA,200);}
}



newTr=$jq('#NWeb1_PatientLogin').closest('table')[0].insertRow(2);
newTd=newTr.insertCell(0);
newTd.className='tableText';
newTd.align='right';
newTd.innerText='Syringe';
newTd=newTr.insertCell(1);
newTd.align='left';
newTd.id='SyringeOptions';
newTd.innerHTML='<INPUT class="buttonBig" style="width:100" value="LS + C" title="LS'+'單管'+'\n20000937\n33090B0M" type="button" onclick="javascript:SyringeClick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:100" value="AS + C" title="AS'+'單管'+'\n20000943\n33090B0M" type="button" onclick="javascript:SyringeClick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:100" value="VCT + C" title="VCT'+'單管'+'\n20000943\n33090B0M" type="button" onclick="javascript:SyringeClick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:100" value="'+'雙管'+'" title="VCT'+'雙管'+'\n20000931\n33090B0M" type="button" onclick="javascript:SyringeClick(this);"><span> </span>';
newTd.innerHTML+='<INPUT class="buttonBig" style="width:100" value="Push" title="Hand push contrast\n33090B0M" type="button" onclick="javascript:SyringeClick(this);"><span> </span>';

function SyringeClick(e){
	$$('NWeb1_AppendSearchOrders1_ddlOrderType').selectedIndex=6;
	$$('NWeb1_AppendSearchOrders1_txbKeyword').value='33090B0M';
	$$('NWeb1_AppendSearchOrders1_btnQuery').click();
	
	if(e.value=='Push'){
		tmpB2=setInterval(fB2,200);
	}else if(e.value=='LS + C'){
		tmpB=setInterval(fB,200,'20000937');
	}else if(e.value=='AS + C'){
		tmpB=setInterval(fB,200,'20000943');
	}else if(e.value=='VCT + C'){
		tmpB=setInterval(fB,200,'20000943');
	}else{
		tmpB=setInterval(fB,200,'20000931');
	}
}

function fB(c){
	if(!isBusy()){
		clearInterval(tmpB);
		$$('NWeb1_AppendSearchOrders1_ddlOrderType').selectedIndex=6;
		$$('NWeb1_AppendSearchOrders1_txbKeyword').value=c;
		$$('NWeb1_AppendSearchOrders1_btnQuery').click();
		tmpB2=setInterval(fB2,200);
	}
}
function fB2(){
	if(!isBusy()){
		clearInterval(tmpB2);
		$$('NWeb1_AppendEditOrders1_btnConfirm').click();
	}
}

$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	if(e.ctrlKey||e.altKey||e.shiftKey){
			return;
	}
	
	if(!isTextBox){
		if(k==87){
			$$('NWeb1_UpdateNHIFile').click();
		}else if(k==65){
			$$('NWeb1_btnAllergy').click();
			
			
		}
		
	}
}


$$('NWeb1_UpdateNHIFile').focus();

function addTitle(a,b){
	if(a.title){
		a.title+='\n';
	}
	a.title='Hotkey: '+b;
}
addTitle($$('NWeb1_UpdateNHIFile'),'w');
addTitle($$('NWeb1_btnAllergy'),'a');


void 0;
