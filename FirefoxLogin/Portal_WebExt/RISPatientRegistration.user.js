// ==UserScript==
// @name          RIS Patient Registration
// @description   
// @include	http://*WebApplication/Radiology/RISPatientRegistration.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

d=$$('NWeb1_cbxIsShowChartNo');
if(d&&!d.checked){d.click();}
n=tmpA=0;
day=new Date();

// setTimeout(function(){
	
// }, 1000);



var originalName = ['N總院舊址骨密度攝影室(GE/Hologic)', 
	'N總院東址(新大樓)影醫部影像中心骨質密度檢查室(DMS)', 
	'N總院兒醫大樓電腦斷層檢查室',
	'N總院兒醫大樓核磁共振檢查室',
	'N總院東址電腦斷層室',
	'N總院東址電腦斷層室 (LS)',
	'N總院東址電腦斷層室(三)',
	'N總院東址(新大樓)超高速電腦斷層室',
	'N總院東址(新大樓)超高速電腦斷層室(B)',
	'N總院東址電腦斷層室(EVO)',
	'N總院西址電腦斷層室(Siemens)',
	'N總院兒醫大樓子宮輸卵管攝影室',
	'N總院東址泌尿道攝影室',
	'N總院東址下消化道攝影室',
	'N總院東址第九攝影室',
	'N總院東址第十攝影室',
	'N總院東址(新大樓)影醫部影像中心乳房斷層掃描室',
	'N總院東址磁振掃描室 GE',
	'N總院東址磁振掃描室 VRERIO',
	'N總院東址磁振掃描室 AERA(一)',
	'N總院東址磁振掃描室 AERA(二)',
	'N總院東址(新大樓)磁振正子掃描中心',
	'N總院西址磁振掃描室 TIM',
	'兒醫下消化道檢查室'
	];

var abbrName = ['BMD(W)', 
	'BMD(E)', 
	'PedCT',
	'PedMR',
	'ECT 1',
	'ECT 2',
	'ECT 3',
	'ICT A',
	'ICT B',
	'ECT EVO',
	'WCT',
	'HSG',
	'IVU',
	'UGI / LGI / VFSS',
	'Mammo 9',
	'Mammo 10',
	'Mammo Hologic',
	'MR: GE',
	'MR: Verio',
	'MR: Aera1',
	'MR: Aera2',
	'MR-PET',
	'MR: TIM',
	'Ped UGI / LGI / VCUG'
	];
	
var quickButtonAbbr = [[
	'ECT 1', 'ECT 2', 'ECT 3', 'ICT A', 'ICT B', 'ECT EVO', 'WCT', 'PedCT'
	], [
	'MR: GE', 'MR: Verio', 'MR: Aera1', 'MR: Aera2', 'MR-PET', 'MR: TIM', 'PedMR'
	], [
	'IVU', 'UGI / LGI / VFSS', 'Ped UGI / LGI / VCUG', 'Mammo 9'
	]];

var listClicked=false;
$jq(document).on('keydown',function(e){
	var k=e.which;
	if(e.ctrlKey||e.altKey||e.shiftKey){
		return true;
	}
	
	
	
	
	if(!isTextBoxFocused()){
		if((k>=96 && k<=105)||k==78||k==74||k==89||k==89||(k>=48&&k<=57)){
				$$('NWeb1_txbChartNo').select();
		}else if(k==37||k==39){
			day.setDate(day.getDate()+k-38);
			$$('NWeb1_txbQueryStartDate').value=day.getFullYear()+'/'+(day.getMonth()+1)+'/'+(day.getDate());
		}
		
		if($jq(':focus').attr('id')!='NWeb1_ddlUnitList'){
			if(k==85){//U=UGI
				$$('NWeb1_ddlUnitList').value='UGE1';
				$$('NWeb1_btnQueryBySchedule').click();
			}else if(k==80){//P=PCT
				$$('NWeb1_ddlUnitList').value='CHCT';
				$$('NWeb1_btnQueryBySchedule').click();
			}else if(k==67){//C=ECT(LS)
				$$('NWeb1_ddlUnitList').value='CTE2';
				$$('NWeb1_btnQueryBySchedule').click();
			}else if(k==76){//L=LGI
				$$('NWeb1_ddlUnitList').value='LGE1';
				$$('NWeb1_btnQueryBySchedule').click();
			}else if(k==71){//G=PED GI
				$$('NWeb1_ddlUnitList').value='PEE2';
				$$('NWeb1_btnQueryBySchedule').click();
			}else if(k==86){//V=IVU
				$$('NWeb1_ddlUnitList').value='IVE1';
				$$('NWeb1_btnQueryBySchedule').click();
			}		
		}
		
	}
}).ready(function(){
	var style = $jq('<style>.nonSelect {-webkit-touch-callout: none;-webkit-user-select: none;-khtml-user-select: none;-moz-user-select: none;-ms-user-select: none;user-select: none; }</style>');
	$jq('html > head').append(style);
	
	
	$jq('#NWeb1_ddlUnitList').click(function(){listClicked=true;});
	
	setTimeout(function(){
		if(!listClicked && $jq('#quickButtonDiv').is(':visible')){
			$jq('#quickButtonDiv').click();
		}
	},2000);
	
});
$jq('#NWeb1_grvPatientOrderList tr input:checkbox').on('change',function(e){
	var source = e.target;
	// console.log(source.id+' '+/NWeb1_grvPatientOrderList_ctl\d+_cbxSelect/.test(source.id));
	if(/NWeb1_grvPatientOrderList_ctl\d+_cbxSelect/.test(source.id)){
		var state=source.checked;
		
		var thisRow=$jq(source).closest('tr')[0];
		var thisCells=thisRow.cells;
		var examName=thisCells[10].innerText;
		if(examName.indexOf('CT With')==0){
			var examType='CT';
		}else if(examName.indexOf('MRI With')==0){
			var examType='MRI';
		}else{
			thisRow.onclick();
			return true;
		}
		
		var thisTable=$$('NWeb1_grvPatientOrderList');
		
		
		for (var i=0;i<thisTable.rows.length;i++){
			var row=thisTable.rows[i];var cells=row.cells;
			if(cells[5].innerText==thisCells[5].innerText && 
				cells[3].innerText==thisCells[3].innerText &&
				cells[10].innerText.indexOf(examType+' With')==0 &&
				// cells[16].firstChild.checked==state  && 
				(cells[2].innerText==thisCells[2].innerText || 
				(cells[2].innerText.indexOf('/')<0 && thisCells[2].innerText.indexOf('/')<0))){
				// if(row!==thisRow){
					// $jq(cells[16]).find(':checkbox')[0].checked=state;
					// console.log(state);
					row.onclick();
				// }
			}
		}
		
		// thisRow.cells[16].firstChild.checked=!thisRow.cells[16].firstChild.checked;
		return true;
		
	}
	return true;

});



$jq('#form1').on('submit', function(){
	setTimeout(scrollToBottom, 500);
	function scrollToBottom() {
		if (!isBusy()) {
				setTimeout(function(){window.scrollTo(0,document.body.scrollHeight);},0);
		} else {
				setTimeout(scrollToBottom, 200);
		}
}
});

setInterval(function(){quickButtons();floatDiv();updateOptions();updateTable();},300);



// $$('NWeb1_ddlUnitList').selectedIndex=7;
$$('NWeb1_ddlStatisticGroupCode').selectedIndex=3;

var a=$$('NWeb1_txbChartNo');
$jq(window).on('focus', windowFocus=function(){
	$$('NWeb1_txbChartNo').select();
});
windowFocus();

$jq('#NWeb1_txbChartNo, #NWeb1_txbAccountNo, #NWeb1_txbRequestSheetNo, #NWeb1_txbPersonID').on('keydown', function(e){
	var k=e.which;
	
	if(k==32||k==13){
		this.value=this.value.toUpperCase();
		if(this.value.length>=7){
			$$('NWeb1_btnQueryByPatient').click();
		}
		return e.preventDefault();
	}
	
	
});



function busy(n){return (n&&n.document&&n.document.readyState=='complete')?0:1;}

function uploadCard(){
	if(!$$('NWeb1_grvPatientOrderList')){return 0;}
	var i=2;choosen=0;var e;
	while(e=$$('NWeb1_grvPatientOrderList_ctl'+(i.pad())+'_cbxSelect')){
		if(e.checked){choosen=i;break;}
		i++;
	}
	if(choosen==0){return 0;}
	nn=window.open(location.href);
	setTimeout(uploadCard2,400);
}
function uploadCard2(){
	if(busy(nn)){setTimeout(uploadCard2,200);}else{
		var e=nn.document.createElement('script');
		e.type='text/javascript';
		e.text="function a(){window.opener.document.getElementById('NWeb1_grvPatientOrderList_ctl"+(choosen.pad())+"_lbnSelect').click();setTimeout(b,400);}function b(){if(window.opener.document&&window.opener.document.readyState=='complete'&&window.opener.document.getElementById('NWeb1_UpdateNHIFile')){window.opener.document.getElementById('NWeb1_UpdateNHIFile').click();window.opener=null;window.close();}else{setTimeout(b,200);}}a();";
		nn.document.getElementsByTagName('head')[0].appendChild(e);
	}
}




function printExam(){
	$$('NWeb1_ddlFunctionType').selectedIndex=3;
	$$('NWeb1_ddlFunctionType').onchange();
}
function regis(){
	if($$('NWeb1_btnRegister')){
		$$('NWeb1_btnRegister').click()
	}
}
function unregis(){
	if($$('NWeb1_btnCancelRegister')){
		$$('NWeb1_btnCancelRegister').click()
	}
}
function cancelExam1(){
	if($$('NWeb1_ddlNotPerformReasonList')){
		$$('NWeb1_ddlNotPerformReasonList').value='Q';
		$$('NWeb1_ddlNotPerformReasonList').onchange();
	}
}

function floatDiv(){
	if($jq('#floatDiv').length){return;}
	
	var top = (document.documentElement && document.documentElement.scrollTop) || 
              document.body.scrollTop;
	
	$jq('<div/>', {
		id: 'floatDiv', 		
	}).css({
		position: 'absolute',
		top: (top+30)+'px',
		right: '0px',
		border: 'solid 1px black',
		padding: '2px'
	}).html('<table><tr><td><input type="button" class="buttonMiddle" style="width:100px;height:40px" value="'+'報到'+'" onclick="javascript:regis();" /></td></tr><tr><td><input type="button" class="buttonMiddle" style="width:100px;height:40px" value="'+'取消報到'+'" onclick="javascript:unregis();" /></td></tr><tr><td><input type="button" class="buttonMiddle" style="width:100px;height:40px" value="'+'列印'+'" onclick="javascript:printExam();" /></td></tr><tr><td><input type="button" class="buttonMiddle" style="width:100px;height:40px;" value="'+'未執行:\n健保因素'+'" onclick="javascript:cancelExam1();" /></td></tr><tr><td><input type="button" class="buttonMiddle" style="width:100px;height:40px" value="'+'寫卡上傳'+'" onclick="javascript:uploadCard();" /></td></tr></table>')
  .appendTo($jq(document.body));
	
}


window.onscroll=function(){
	var top = (document.documentElement && document.documentElement.scrollTop) || 
              document.body.scrollTop;
	if($$('floatDiv')){
		$$('floatDiv').style.top = (top + 30) + 'px';
	}
};

function addTitle(a,b){
	if(a.title){
		a.title+='\n';
	}
	a.title='Hotkey: '+b;
}

function getOptionByText(sel,text){
	for(var i=0;i<sel.length;i++){
		if(sel.options[i].text==text){
			return sel.options[i];
		}
	}
}

function fromCharCode(str,del){
	if(del==''){del=',';}
	var arr=str.split(del);var s='';
	for(var i=0;i<arr.length;i++){
		s+=String.fromCharCode(parseInt(arr[i]));
	}
	return s;
}

function updateOptions(){
	// return 0;
	var sel=$$('NWeb1_ddlUnitList');
	if(!sel){return;}
	// if(getOptionByText(sel,'PCT')){return;}
	// var arr1=['CHCT','CHMR','CTE2','CTE3','CTE1','CTE4','CTE5','CTW1','HSE2','IVE1','LGE1', 'MAE1', 'MRGE', 'MRI1','MRI2','MRI3','MRPT','MRW1','MYE1','PEE2'];	
	
	// var arr2=['PCT','PMR','ECT: GE','ECT: VCT','ECT: Toshiba','ICT(A)','ICT(B)','WCT: Siemens','HSG','IVU','UGI/LGI', 'Mammo', 'MR: GE', 'MR: VERIO','MR: AERA1','MR: AERA2','MR-PET','MR: TIM','Myelography','Ped Special'];

	// var arr3=['BRE1','CHP1','CHP2','HSE1','PEE1'];
	
	for(var i=0;i<originalName.length;i++){
		for(var j=0;j<sel.options.length;j++){
			if(sel.options[j].innerText===originalName[i]){
				sel.options[j].text=abbrName[i];
				break;
			}
		}
	}
	
	// var arr3=['1','4','5','11','23']
	// arr3.reverse();
	// for(var i=0;i<arr3.length;i++){
		// sel.remove(arr3[i]);
	// }
	
}

function updateTable(){
	var table=$$('NWeb1_grvPatientOrderList');
	if(!table){return;}
	if(!table.rows.length || table.rows[0].cells.length<19){return;}
	
	for(var i=table.rows.length-1;i>=0;i--){
		table.rows[i].deleteCell(16);
		table.rows[i].deleteCell(15);
		if(table.rows[i].cells[14].innerText){
			table.rows[i].color='#FF0000';
		}
		// table.rows[i].deleteCell(14);
	}
	
	
	for(var i=1;i<table.rows.length;i++){
		// table.rows[i].onclick=function(){
			// var cbx = $jq(this.cells[16]).find(':checkbox');
			// cbx.checked = !cbx.checked; 
			// if (this.style.backgroundColor==='yellow') { 
				// this.setAttribute('prevBG',this.style.backgroundColor);
				// this.setAttribute('prevColor',this.style.color);
				// this.setAttribute('choosen','1');
				// this.style.backgroundColor='yellow'; this.style.color='black'; 
			// }else {
				// this.setAttribute('choosen','0');
				// this.style.backgroundColor=this.getAttribute('prevBG');
				// this.style.color=this.getAttribute('prevColor');
			// }
		// };
		var state=table.rows[i].cells[11].innerText;
		if(state=='報到 '){
			table.rows[i].style.backgroundColor='cyan';
		}else if(state=='執行 '){
			table.rows[i].style.backgroundColor='lightgreen';
		}else if(state=='未執行 '){
			table.rows[i].style.backgroundColor='#707070';
		}
		table.rows[i].setAttribute('prevBG',table.rows[i].style.backgroundColor);
		table.rows[i].setAttribute('prevColor',table.rows[i].style.color);
		table.rows[i].setAttribute('choosen','0');
		
	}
	
	$$('NWeb1_grvPatientOrderList_ctl01_cbxSelectDitto').onclick=function(){
		var table=$$('NWeb1_grvPatientOrderList');var state=this.checked;
		for(var i=1;i<table.rows.length;i++){
			if(state==(table.rows[i].getAttribute('choosen')=='0')){
				table.rows[i].onclick();
			}
		}
	};
	
}


addTitle($$('NWeb1_btnQueryBySchedule'),'U=UGI\nL=LGI\nP=PCT\nC=ECT(LS)\nV=IVU');


setTimeout(function(){
	$jq(document.body).scrollTop($jq(document).height());
}, 500);

var options = $$('NWeb1_ddlUnitList').options;

function quickButtons(){
	if(!$$('NWeb1_grvPatientOrderList') && !$$('quickButtonDiv')){
		
		var div = document.createElement('div');
		div.innerText = '常    用';
		div.className = 'buttonMiddle';
		div.id = 'quickButtonDiv';
		div.onclick = function(){
			this.style.display = 'none';
		
			// var tb = document.createElement('table');
			// tb.style.border='0';
			
			var div = document.createElement('div');
			div.style.display = 'flex';
			div.style.justifyContent = 'center';
			div.style.alignItems = 'center';
			
			var e  = document.createElement('div');
			e.style.width = '25%';
			e.style.height='50px';
			e.innerText = '前一天';
			e.style.display = 'flex';
			e.style.justifyContent = 'center';
			e.style.alignItems = 'center';
			e.className = 'buttonMiddle nonSelect';
			e.onclick=function(){
				day.setDate(day.getDate()-1);
				$$('NWeb1_txbQueryStartDate').value=day.getFullYear()+'/'+(day.getMonth()+1)+'/'+(day.getDate());
			};
			div.appendChild(e);
			var e  = e.cloneNode();
			e.innerText = '後一天';
			e.style.left = '';
			e.onclick=function(){
				day.setDate(day.getDate()+1);
				$$('NWeb1_txbQueryStartDate').value=day.getFullYear()+'/'+(day.getMonth()+1)+'/'+(day.getDate());
			};
			div.appendChild(e);
			$$('NWeb1_uPnlQrcode').appendChild(div);
			
			
			for(var i=0;i<quickButtonAbbr.length;i++){
				createButtonRow(quickButtonAbbr[i]);
			}
			
			
			
		};
		$$('NWeb1_uPnlQrcode').appendChild(div);
	}

	
}


function createButtonRow(names){
	
	// var selectIds = ids;
	var sel=$$('NWeb1_ddlUnitList');
	
	var div = document.createElement('div');
	
	div.style.display = 'flex';
	div.style.justifyContent = 'space_between';
	for(var name of names){
		var id = -1; 
		
		var ind = abbrName.indexOf(name);
		if(ind<=-1){
			continue;
		}
		
		var fullName = originalName[ind];
		
		for(var j=0;j<sel.options.length;j++){
			if(sel.options[j].innerText===name || sel.options[j].innerText===fullName){
				id = j;
				break;
			}
		}
		
		if(id<=-1){
			continue;
		}
			
		var e = createButton(sel.options[id].value, name);
		e.style.height = '100px';
		// e.style.cssFloat = 'left';
		e.style.display = 'flex';
		e.style.justifyContent = 'center';
		e.style.alignItems = 'center';
		e.style.width = (100/names.length).toFixed(1) + '%';
		div.appendChild(e);
	}
	$$('NWeb1_uPnlQrcode').appendChild(div);
	
}

function createButton(value, txt){
	var e = document.createElement('div');
	e.addEventListener('click', function(e){
		$$('NWeb1_ddlUnitList').value = e.target.value;
		$$('NWeb1_ddlUnitList').onchange();
	});
	e.innerText = txt.replace(/\s*\/\s*/g, '\n/ ').replace(/: /g, ':\n');
	e.value= value;
	e.className = 'buttonMiddle nonSelect';
	
	
	return e;
}

//
void 0;