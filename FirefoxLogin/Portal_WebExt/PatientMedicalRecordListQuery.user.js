// ==UserScript==
// @name          Patient Query after 'Enter'
// @description   
// @include	http://*WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PatientMedicalRecordListQuery*
// ==/UserScript==

function $$(x){return document.getElementById(x);}


$jq(document).keydown(function(e){
  if(e.ctrlKey || e.altKey || e.shiftKey){
    return true;
   }
   
   if(!isTextBoxFocused()){
    var k=e.which;
		if((k>=96 && k<=105)||(k>=48 && k<=57)||k==78||k==74||k==89){
			$jq('[name="NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01"]:first')[0].select();
		}
	
	}
   
   
});

$jq(document).ready(function(){
	var match = location.href.match(/NWeb1%24PatientBasicInfoQueryByIDAndName1%24ctl01=(\w{7})/);
	if(match && $jq('[name="NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01"]:first').val().toString()===''){
		__searchByPatientChartNo(match[1].toString());
	}
});
// .on('click', '#NWeb1_PatAccountListRecord1_ButtonWebEMR', function(){
	// var webemrfocus=setInterval(function(){oNewWin.focus()},100);
	// setTimeout(function(webemrfocus){
		// clearInterval(webemrfocus)
	// },5000,webemrfocus);
// });

document.title = '就診紀錄查詢';
setTimeout(function(){
	if($jq('#NWeb1_PatAccountListRecord1_PatBasicDescription').length){
		document.title = ['就診紀錄:', $jq('[name="NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01"]:first').val(), $jq('#NWeb1_PatAccountListRecord1_PatBasicDescription').text()].join(' ');
	}}, 500);	

b=$jq('[name="NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01"]:first');
// b.parentNode.removeChild(b.nextSibling);
// if(b){b.select();b.onkeydown=function(){return validateForm();};window.onfocus=function(){b.select();};}

$jq(window).on('focus', function(){
	b[0].select();
});

if(b[0]){b[0].select();

b.keydown(function(e){
  var c=e.which;
  
  if(e.ctrlKey || e.altKey || e.shiftKey){
    return true;
  }else if ([87,69,80,79].indexOf(c)>-1){
    Mousetrap.trigger(String.fromCharCode(c).toLowerCase());
    return e.preventDefault();
  }
   
  
	
	var l=$jq(this).val().length;
	
	var textSelected = this.value.slice(this.selectionStart, this.selectionEnd).toString()===this.value.toString();
	
  if(l>=7 && [35,36,37,39,46,8,9,13,32].indexOf(c)==-1 && !textSelected){
		return e.preventDefault();
	}
  
	if(c==13||c==32){
		
		if(l<7){return e.preventDefault();}
    
		$jq('[name="NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01"]:first').val($jq(this).val().substr(0,7).toUpperCase());
		$jq('[name="NWeb1$PatientBasicInfoQueryByIDAndName1$ctl09"]:first').click();
		return e.preventDefault();
	}
});

}

Mousetrap.bindGlobal('w', function(){
  $$('NWeb1_PatAccountListRecord1_ButtonWebEMR').click();
});

Mousetrap.bindGlobal('e', function(){
  $$('NWeb1_PatAccountListRecord1_ShowBriefHistory').click();
});

Mousetrap.bindGlobal('p', function(){
  $$('NWeb1_PatAccountListRecord1_ButtonShowPACS').click();
});

Mousetrap.bindGlobal('o', function(){
  $$('NWeb1_PatAccountListRecord1_ShowOperationList').click();
});



// document.onkeydown=keydown;

if($$('NWeb1_PatAccountListRecord1_personidHidden')){
	patientId=$$('NWeb1_PatAccountListRecord1_personidHidden').value;
}else{
	patientId='';
}

if(SID=location.href.match(/SESSION=(\w+)/)){
	SID=SID[1];
}else{
	SID='';
}

// if($$('NWeb1_PatAccountListRecord1_ButtonWebEMR')&&patientId&&SID){
	// $$('NWeb1_PatAccountListRecord1_ButtonWebEMR').onclick=function(){
			// var newWinUrl='http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleShowiframePage.aspx?SESSION='+SID+'&PersonID='+patientId+'&Seed='+nowString();
			// if(oNewWin){
				// oNewWin.location.href=newWinUrl;
			// }else{
				// oNewWin=open(newWinUrl);
			// }
			// return false;
		// };
// }


function nowString(){
	var now=new Date();
	return ''+now.getFullYear()+((now.getMonth()+1).pad())+((now.getDay()).pad())+(now.getHours().pad())+(now.getMinutes().pad())+(now.getSeconds().pad());
}


function fill0( number, width)
{
  if(!width){width=2;}
  width -= number.toString().length;
  if ( width > 0 )
  {
    return new Array( width + (/\./.test( number ) ? 2 : 1) ).join( '0' ) + number;
  }
  return number + ""; // always return a string
}


// newTd=$$('NWeb1_PatAccountListRecord1_personidHidden').nextSibling.nextSibling.insertRow(1).insertCell(0);
// newTd.innerHTML='<INPUT style="BACKGROUND-COLOR: #ccccff; FONT-WEIGHT: bold" id=NWeb1_PatAccountListRecord1_ShowRecentRad class=button value=?拙僑?批蔣?賊 type=button>';

function addTitle(a,b){
	if(a.title){
		a.title+='\n';
	}
	a.title='Hotkey: '+b;
}
addTitle($$('NWeb1_PatAccountListRecord1_ButtonWebEMR'),'w');
addTitle($$('NWeb1_PatAccountListRecord1_ShowBriefHistory'),'e');
addTitle($$('NWeb1_PatAccountListRecord1_ButtonShowPACS'),'p');
addTitle($$('NWeb1_PatAccountListRecord1_ShowOperationList'),'o');

//added by HUC
//sec1 : 過敏頁面按鈕
var st = '';
if($$('NWeb1_PatAccountListRecord1_personidHidden').value != ''){ //get patient person ID

	function checkAllergy(){
		var xmlhttp;
		if (window.XMLHttpRequest)
		  {// code for IE7+, Firefox, Chrome, Opera, Safari
		  xmlhttp=new XMLHttpRequest();
		  }
		else
		  {// code for IE6, IE5
		  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
		  }
		xmlhttp.onreadystatechange=function()
		  {
		  if (xmlhttp.readyState==4 && xmlhttp.status==200)
			{
			 if(xmlhttp.responseText){
				 var s, sDrug, oAllergy=[], s3, s4;
				 s = xmlhttp.responseText.match(/<table[^>]*?id="NWeb1_AllergyHistory1_rptAllergy_ctl[0-9]{2}_dgrAllergyMaster"[\S\s^>]*?>([\S\s^>]*?)<\/table>/g);
				 s4 = ''; s4=s4.concat(s); s4.replace(/,/g,"");
				 sDrug = s4.match(/<tr[^>]*?class="tableText[2]{0,1}">([\S\s^>]*?)<\/tr>/g);//tableText與tableText2只是資訊部用來分單雙行不同顏色的class
				 for(var key in sDrug){ //拆掉<TR>
				     if(isNaN(key)){continue;}
					 var s2;
					 s3='';
					 s2 = sDrug[key].match(/<tr[^>]*?class="tableText[2]{0,1}">([\S\s^>]*?)<\/tr>/)[1];
					 s2 = s2.match(/<td[^>]*?>([\S\s^>]*?)<\/td>/g);//拉出TD
					 s3 = s3.concat(s2);
					 s3 = s3.replace(/<[\S\s^>]*?>/g,""); //去掉tag
					 s3 = s3.replace(/[\s>]*/g,"");       //去掉空白
					 s3 = s3.replace(/&nbsp;/g,"");       //去掉空白
					 oAllergy[key] = s3.split(",");
				 }
				 var hasAllergy = false, hasUnclear= false, sAllergy="";
				 for(var key in oAllergy){
				     if(isNaN(key)){continue;}
					 if(oAllergy[key][1]=="不清楚"||oAllergy[key][1]=="UnClear"){
						 hasUnclear = true;
						 sAllergy = sAllergy + oAllergy[key][0] + ":" + oAllergy[key][1] + "\n";
					 }else if(oAllergy[key][1]!="無"){
						 //alert("allergy:"+oAllergy[key][1]);
						 hasAllergy = true;
						 sAllergy = sAllergy + oAllergy[key][1] + " Rxn:" + oAllergy[key][2] + "\n";

					 }
				 }
				 $$("NWeb1_PatAccountListRecord1_Allergy").style.borderWidth = "1px 1px 1px 1px";
				 if(hasAllergy){
					$$("NWeb1_PatAccountListRecord1_Allergy").style.borderColor = "#FF0000";
					$$("NWeb1_PatAccountListRecord1_Allergy").title = sAllergy;
				 }else if(hasUnclear){
					$$("NWeb1_PatAccountListRecord1_Allergy").value = $$("NWeb1_PatAccountListRecord1_Allergy").value + '?';
					$$("NWeb1_PatAccountListRecord1_Allergy").title = sAllergy;
				 }else{
					$$("NWeb1_PatAccountListRecord1_Allergy").style.borderColor = "#00FF00";
					$$("NWeb1_PatAccountListRecord1_Allergy").title = "查無過敏記錄";
				 }
				 //alert(hasAllergy);
				 //alert(sAllergy);
			 }
				 
			}else if (xmlhttp.readyState==4 && xmlhttp.status!=200){ //網頁讀取錯誤
				$$("NWeb1_PatAccountListRecord1_Allergy").title = "讀取失敗，請手動查詢";
			}
		  }
		xmlhttp.open("GET",'http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/AllergyMenu.aspx?'+location.href.match(/SESSION=(\w+)/)[0]+'&PersonID='+$$('NWeb1_PatAccountListRecord1_personidHidden').value,true);
		xmlhttp.send();
	}

	var p=document.createElement("input");
	p.type = 'button';
	p.id= 'NWeb1_PatAccountListRecord1_Allergy';
	p.className = 'button';
	p.value = '過敏';
	p.onclick = function(){
	window.open('http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/AllergyMenu.aspx?'+location.href.match(/SESSION=(\w+)/)[0]+'&PersonID='+$$('NWeb1_PatAccountListRecord1_personidHidden').value);
	};
	$$('NWeb1_PatAccountListRecord1_ButtonWebEMR').parentNode.appendChild(p);
	checkAllergy();
}
//end of sec1 : 過敏頁面按鈕

//sec2 : 病程紀錄按鈕

var _lastClicked;
function addProgressNoteButton()
{
if(!$$('NWeb1_PatAccountListRecord1_GridViewInPatRecord_ctl02_ShowDrugGiven')){ //檢查有否住院紀錄
    return "Failed";
}

var rows=$$('NWeb1_PatAccountListRecord1_GridViewInPatRecord').rows;

for(var i=0;i<rows.length-1;i++){
	var o = document.createElement('input');
	o.className = 'button';
	o.value = '程';
	o.type = 'button';
	o.id = "NWeb1_PatAccountListRecord1_ButtonProgressNote" + ((i+2).pad());
	o.title = "打開當次住院病程紀錄";
	// o.AccountIDSE = document.inPatientAccount[i];
	o.onclick = function(){
		_lastClicked=this.id;
		
		
		var xmlhttp;
		if (window.XMLHttpRequest)
		  {// code for IE7+, Firefox, Chrome, Opera, Safari
		  xmlhttp=new XMLHttpRequest();
		  }
		else
		  {// code for IE6, IE5
		  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
		  }
		xmlhttp.onreadystatechange=function()
		  {
		  if (xmlhttp.readyState==4 && xmlhttp.status==200)
			{
			
			 var matches = xmlhttp.responseText.match(/(\d{2}T\d{8}\|)*(\d{2}T\d{8})/); //get Account of individual admission from response
			 if(matches){
				
				 document.inPatientAccount = matches[0].split('|');
				 
				 for(var i = 0; i<document.inPatientAccount.length; i++){
					$$("NWeb1_PatAccountListRecord1_ButtonProgressNote" + ((i+2).pad())).AccountIDSE = document.inPatientAccount[i];
					$$("NWeb1_PatAccountListRecord1_ButtonProgressNote" + ((i+2).pad())).onclick=function(){
						window.open('http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/InsertProgressNoteContent.aspx?SESSION='+location.href.match(/SESSION=(\w+)/)[1]+'&AccountIDSE='+ this.AccountIDSE);
					};
					
				}
				if(_lastClicked!==''){
					$$(_lastClicked).onclick();
				}
			 }else{//沒有病程紀錄
			 }
			}
		  }
		 //making request header
		 var s= 'scrollLeft=0&scrollTop=0&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&';
		 s = s+ '__VIEWSTATE=' + encodeURIComponent($$('__VIEWSTATE').value.toString()) + '&';
		 s = s+ '__EVENTVALIDATION=' + encodeURIComponent($$('__EVENTVALIDATION').value.toString()) + '&';
		 s = s+ 'NWeb1%24PatAccountListRecord1%24personidHidden=' + encodeURIComponent($$('NWeb1_PatAccountListRecord1_personidHidden').value.toString()) + '&';
		 s = s+ 'NWeb1%24PatAccountListRecord1%24GridViewInPatRecord%24ctl02%24ShowAdmissionNote=%E5%85%A5';
		 //sending request
		xmlhttp.open("POST",document.forms['Form1'].action,true);
		xmlhttp.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
		xmlhttp.send(s);
	
	
		
	};

	$$('NWeb1_PatAccountListRecord1_GridViewInPatRecord_ctl'+((i+2).pad())+'_ShowDrugGiven').parentNode.appendChild(o);
	}
}	



addProgressNoteButton();
//end of sec2 : 病程紀錄按鈕

//end of added by HUC



//sec3 : 急診紀錄按鈕
function addERNoteButton()
{
if(!$$('NWeb1_PatAccountListRecord1_GridViewEmergencyContent_ctl02_ShowEmergencyClinicHistory')){ //檢查有否住院紀錄
    return "Failed";
}

var rows=$$('NWeb1_PatAccountListRecord1_GridViewEmergencyContent').rows;

for(var i=0;i<rows.length-1;i++){
	var o = document.createElement('input');
	o.className = 'button';
	o.value = '急';
	o.type = 'button';
	o.id = "NWeb1_PatAccountListRecord1_ButtonERNote" + ((i+2).pad());
	o.title = "打開當次急診醫療";
	// o.AccountIDSE = document.inPatientAccount[i];
	
	
	o.onclick = function(){
		_lastClicked=this.id;
		

		var xmlhttp;
		if (window.XMLHttpRequest)
		  {// code for IE7+, Firefox, Chrome, Opera, Safari
		  xmlhttp=new XMLHttpRequest();
		  }
		else
		  {// code for IE6, IE5
		  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
		  }
		xmlhttp.onreadystatechange=function()
		  {
		  if (xmlhttp.readyState==4 && xmlhttp.status==200)
			{
			
			 var matches = xmlhttp.responseText.match(/(\d{2}T\d{8}\|)*(\d{2}T\d{8})/); //get Account of individual admission from response
			
			 if(matches){
				 document.inPatientAccount = matches[0].split('|');
				 for(var i = 0; i<document.inPatientAccount.length; i++){
				 
					$$("NWeb1_PatAccountListRecord1_ButtonERNote" + ((i+2).pad())).AccountIDSE = $$("NWeb1_PatAccountListRecord1_ButtonERProgressNote" + ((i+2).pad())).AccountIDSE = document.inPatientAccount[i];
				 
					$$("NWeb1_PatAccountListRecord1_ButtonERNote" + ((i+2).pad())).onclick = function(){
						window.open('http://ehisaw.hospital-n.local/WebApplication/Emergency/EmergencyConfirmDiagnosisOrder.aspx?SESSION='+location.href.match(/SESSION=(\w+)/)[1]+'&accountidse='+ this.AccountIDSE);
					};
					$$("NWeb1_PatAccountListRecord1_ButtonERProgressNote" + ((i+2).pad())).onclick = function(){
						window.open('http://ehisaw.hospital-n.local/WebApplication/Emergency/InsertProgressNoteContent.aspx?SESSION='+location.href.match(/SESSION=(\w+)/)[1]+'&AccountIDSE='+ this.AccountIDSE);
					};
					
					
				 }
				 if(_lastClicked!==''){
					$$(_lastClicked).onclick();
				}
			 }else{//沒有急診紀錄
			 }
			}
		  }
		 //making request header
		 var s= 'scrollLeft=0&scrollTop=0&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&';
		 s = s+ '__VIEWSTATE=' + encodeURIComponent($$('__VIEWSTATE').value.toString()) + '&';
		 s = s+ '__EVENTVALIDATION=' + encodeURIComponent($$('__EVENTVALIDATION').value.toString()) + '&';
		 s = s+ 'NWeb1%24PatAccountListRecord1%24personidHidden=' + encodeURIComponent($$('NWeb1_PatAccountListRecord1_personidHidden').value.toString()) + '&';
		 s = s+ 'NWeb1%24PatAccountListRecord1%24GridViewEmergencyContent%24ctl02%24ShowEmergencyClinicHistory=%E7%97%85';
		 //sending request
		xmlhttp.open("POST",document.forms['Form1'].action,true);
		xmlhttp.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
		xmlhttp.send(s);
	};
	$$('NWeb1_PatAccountListRecord1_GridViewEmergencyContent_ctl'+((i+2).pad())+'_ShowEmergencyClinicHistory').parentNode.appendChild(o);

	var p = o.cloneNode(true);
	p.value='程';
	p.title='打開當次急診病程紀錄';
	p.id = "NWeb1_PatAccountListRecord1_ButtonERProgressNote" + ((i+2).pad());
	p.onclick = o.onclick;
	$$('NWeb1_PatAccountListRecord1_GridViewEmergencyContent_ctl'+((i+2).pad())+'_ShowEmergencyClinicHistory').parentNode.appendChild(document.createTextNode(' '));
	$$('NWeb1_PatAccountListRecord1_GridViewEmergencyContent_ctl'+((i+2).pad())+'_ShowEmergencyClinicHistory').parentNode.appendChild(p);
	}
}

addERNoteButton();
//end of sec3 : 急診記錄按鈕


//sec3 : 門診紀錄按鈕
function addOPDNoteButton()
{

if(!$$('NWeb1_PatAccountListRecord1_GridViewOutPatRecord_ctl02_ShowMedicalRecord')){ //檢查有否門診紀錄
    return "Failed";
}


var rows=$$('NWeb1_PatAccountListRecord1_GridViewOutPatRecord').rows;

for(var i=0;i<rows.length-1;i++){
	var o = document.createElement('input');
	o.className = 'button';
	o.value = '程';
	o.type = 'button';
	o.id = "NWeb1_PatAccountListRecord1_ButtonOPDNote" + ((i+2).pad());
	o.title = "打開當次門診病程紀錄";
	// o.AccountIDSE = document.inPatientAccount[i];
	
	
	o.onclick = function(){
		_lastClicked=this.id;



		var xmlhttp;
		if (window.XMLHttpRequest)
		  {// code for IE7+, Firefox, Chrome, Opera, Safari
		  xmlhttp=new XMLHttpRequest();
		  }
		else
		  {// code for IE6, IE5
		  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
		  }
		xmlhttp.onreadystatechange=function()
		  {
		  if (xmlhttp.readyState==4 && xmlhttp.status==200)
			{
			
			 var matches = xmlhttp.responseText.match(/(\d{2}T\d{8}\|)*(\d{2}T\d{8})/); //get Account of individual admission from response
			 if(matches){
				 document.inPatientAccount = matches[0].split('|');
				 for(i = 0; i<document.inPatientAccount.length; i++){
					$$("NWeb1_PatAccountListRecord1_ButtonOPDNote" + ((i+2).pad())).AccountIDSE = document.inPatientAccount[i];
					$$("NWeb1_PatAccountListRecord1_ButtonOPDNote" + ((i+2).pad())).onclick = function(){
						window.open('http://ihisaw.hospital-n.local/WebApplication/InPatient/Ward/InsertProgressNoteContent.aspx?SESSION='+location.href.match(/SESSION=(\w+)/)[1]+'&AccountIDSE='+ this.AccountIDSE);
					}
					
					
				 }
				 if(_lastClicked!==''){
						$$(_lastClicked).onclick();
					}
			 }else{//沒有急診紀錄
			 }
			}
		  }
		 //making request header
		 var s= 'scrollLeft=0&scrollTop=0&__EVENTTARGET=&__EVENTARGUMENT=&__LASTFOCUS=&';
		 s = s+ '__VIEWSTATE=' + encodeURIComponent($$('__VIEWSTATE').value.toString()) + '&';
		 s = s+ '__EVENTVALIDATION=' + encodeURIComponent($$('__EVENTVALIDATION').value.toString()) + '&';
		 s = s+ 'NWeb1%24PatAccountListRecord1%24personidHidden=' + encodeURIComponent($$('NWeb1_PatAccountListRecord1_personidHidden').value.toString()) + '&';
		 s = s+'NWeb1%24PatAccountListRecord1%24GridViewOutPatRecord%24ctl02%24ShowMedicalRecord=%E7%97%85';
		 //sending request
		xmlhttp.open("POST",document.forms['Form1'].action,true);
		xmlhttp.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
		xmlhttp.send(s);
	};
	

	$$('NWeb1_PatAccountListRecord1_GridViewOutPatRecord_ctl'+((i+2).pad())+'_ShowMedicalRecord').parentNode.appendChild(o);
	}
}

addOPDNoteButton();
//end of sec3 : 門診記錄按鈕


function __searchByPatientChartNo(chartNo){
	
	document.getElementsByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01')[0].value=chartNo;
	document.getElementsByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl09')[0].click();
}



void 0;
