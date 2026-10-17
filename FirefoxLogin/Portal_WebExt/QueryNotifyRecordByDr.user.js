// ==UserScript==
// @name          Query Notify Record
// @description   
// @include	http://*WebApplication/InPatient/Ward/QueryNotifyRecordByDr.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}





// $$('NWeb1_NotDepartSelectionObj_ddlDeptCode').selectedIndex=30;
// $$('NWeb1_NotDepartSelectionObj_ddlDeptCode').onchange();

if($$('NWeb1_NotifyDrRecord')){
	setTimeout(function(){
		var i=0;
		for (row of $$('NWeb1_NotifyDrRecord').rows){
			++i;
			if(i==1){continue;}
			
			var cells=row.cells;
			
			
			$jq(cells[7]).find('span').text(function(){return htmlDecode(this.title);});
			$jq(cells[8]).find('span').text(function(){return this.innerText
				.replace('影像醫學部','')
				.replace('影醫部','')
				.replace('第二意見諮詢會診申請','')
				.replace('guided procedure','guided')
				.replace(/^\(/,'')
				.replace(/\)$/,'');});
			if(cells[13].innerText.indexOf('待回覆')>-1){
				$jq(cells[13]).find('span').css('font-weight', '1200');
			}
			var title=$jq(cells[1]).find('span').attr('title');
			if(title!==undefined){
				var matches=title.match(/T\d\-(\w+)\s?\-(\d+)\-(\d+)/);
				// alert(matches.length);
				if(Object.prototype.toString.call(matches) === '[object Array]' && matches.length>3){
					$jq(cells[1]).find('span').text(matches[1]+'\n'+matches[2]+'-'+matches[3]);
				}
			}
			
		}
	},0);
}


setTimeout(LT, 60000);
function LT(){
	if($$('NWeb1_NotifyDrRecord')){
		var i=0;
		for(row of $$('NWeb1_NotifyDrRecord').rows){
			i++;
			if(i==1){continue;}
			
			var m=row.cells[14].innerText.match(/(\-?)(\d+)\:(\d+)/);
			if(m){
				var n=(!!m[1])?(-1):(1);
				var k=n*(m[2]*60+(m[3]*1))-1;
				var a=Math.floor(Math.abs(k)/60);
				var b=Math.abs(k)%60;
				var r=((a*60+b*1)<=10 && n>0)?true:false;
				// if(a.length<2){a='0'+a;}
				// if(b.length<2){b='0'+b;}
				a=(a).pad(); 
				b=(b).pad();
				if(!r){
					row.cells[14].innerHTML=m[1]+a+':'+b;
				}else{
					row.cells[14].innerHTML='<span style="color: red; font-weight: 700;">'+m[1]+a+':'+b+'</span>';
				}
			}
			
			
		}
	}
	setTimeout(LT,60000);
}



// window.onfocus=function(){
	// $$('NWeb1_txbChartNo').select();
// };

setInterval(routine,500);
setInterval(setEndDate,600000);
function setEndDate(){
	var d=new Date();
	$jq('#NWeb1_DateTextBoxYearMonthDayEnd_YearInput').val(d.getFullYear());
	$jq('#NWeb1_DateTextBoxYearMonthDayEnd_MonthInput').val(d.getMonth()+1);
	$jq('#NWeb1_DateTextBoxYearMonthDayEnd_DayInput').val(d.getDate());
}

function routine(){
	$jq('a').each(function(){
		if (/NWeb1_NotifyDrRecord_ctl\d+_lbtnReply/.test(this.id)){
			this.disabled='';
			this.onclick=function(){return replyURL(this);};
		}
		
	});
	
}


$jq(document).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	
	activeId=$jq(':focus').attr('id');
	
	
	
	if(e.ctrlKey||e.altKey||e.shiftKey){return;}
	
	if(k==13){  //enter
		if(activeId==='NWeb1_PersonIDInput'){
			$$('NWeb1_QueryNotifyContent').click();return e.preventDefault();
		}else if(activeId==='NWeb1_txbChartNo'){
			$$('NWeb1_btnQueryByChartNo').click();return e.preventDefault();
		}
	}
	
	if(isTextBox){
		if(k==32){   //space
			if(activeId==='NWeb1_txbChartNo'){
				$$('NWeb1_btnQueryByChartNo').click();return e.preventDefault();
			}
		}
	}else if(($jq(':focus').attr('id')!='VSlist') && ($jq(':focus').attr('id')!='Rlist')){
		if((k>=96 && k<=105)||k==78||k==74||k==89||(k>=48&&k<=57)){
				$$('NWeb1_txbChartNo').select();
		}
	}
}

$jq(document).on('mousedown', function(e){

	
	var match;var url;
	if(e.which == 2 ){ //middle button
		replyURL(e.target)
		return e.preventDefault();
	}
		
});

function replyURL(element){
	// var match;
	// if((match=((clickedId=element.id).match(/NWeb1_NotifyDrRecord_ctl(\d\d)_SelectButton/)))||(match=((clickedId=element.id).match(/NWeb1_NotifyDrRecord_ctl(\d\d)_lbtnReply/)))){  //view consult
		// var d=new Date();var h;var ele;
		// if((!/\d/.test((ele=$$('NWeb1_NotifyDrRecord_ctl'+match[1]+'_WardCodeLabel')).value))&&(!ele.title)){
			// patClassString='E';
		// }else{patClassString='I';}
		// seedString=((h=d.getHours())>=12?('下'):('上'))+'午'+' '+fill0(h%12?h%12:12)+':'+fill0(d.getMinutes())+':'+fill0(d.getSeconds());
		// open(location.href.replace('QueryNotifyRecordByDr','NotifyOtherDoctor')+'&AccountIDSE='+$$('NWeb1_NotifyDrRecord_ctl'+match[1]+'_PersonBasicInfo').title+'&NotifyIDSE='+$$('NWeb1_NotifyDrRecord_ctl'+match[1]+'_PersonChartNo').title+'&PatClass='+patClassString+'&Seed='+seedString+(match[0].indexOf('Reply')?'&Reply=Y':''));
		// return false;
	// }
	var url;
	if(url=replyURLcreator(element)){
		open(url);
		return false;
	}
}

function replyURLcreator(element){

	var match;
	if((match=((clickedId=element.id).match(/NWeb1_NotifyDrRecord_ctl(\d\d)_SelectButton/)))||(match=((clickedId=element.id).match(/NWeb1_NotifyDrRecord_ctl(\d\d)_lbtnReply/)))){  //view consult
		var d=new Date();var h;var ele;
		if(!(/\d/.test((ele=$$('NWeb1_NotifyDrRecord_ctl'+match[1]+'_WardCodeLabel')).value))&&(!ele.title)){
			patClassString='E';
		}else{patClassString='I';}
		seedString=((h=d.getHours())>=12?('下'):('上'))+'午'+' '+(h%12?h%12:12).pad()+':'+(d.getMinutes().pad())+':'+(d.getSeconds().pad());
		return (location.href.replace('QueryNotifyRecordByDr','NotifyOtherDoctor')+'&AccountIDSE='+$$('NWeb1_NotifyDrRecord_ctl'+match[1]+'_PersonBasicInfo').title+'&NotifyIDSE='+$$('NWeb1_NotifyDrRecord_ctl'+match[1]+'_PersonChartNo').title+'&PatClass='+patClassString+'&Seed='+seedString+(match[0].indexOf('Reply')?'&Reply=Y':''));
	}
	
	return false;
}


floatDiv();
function floatDiv(){
	if($jq('#floatDiv').length){return;}
	
	try {
		if(!contacts.length) throw 1;
	}catch(_){
		setTimeout(floatDiv, 1000);
		return;
	}

	
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
	}).html('<table><tr><td><select id="VSlist" onChange="selectStaff(this)">'+VSlistHTML()+'</select></td></tr><tr><td><select id="Rlist" onChange="selectStaff(this)">'+RlistHTML()+'</select></td></tr><tr><td><input type=button id=analyzeReply class=buttonMiddle value=查詢照會狀態 style="width:100px; height:24px" onclick="return analyzeReply();" /></td></tr></table>')
  .appendTo($jq(document.body));
	
}



function searchButton(){
	$jq('#NWeb1_QueryNotifyContent').click();
}



function selectStaff(opt){
	if(opt.value){
		$$('NWeb1_PersonIDInput').value=opt.value;
		$$('NWeb1_QueryNotifyContent').click();
	}
}


window.onscroll=function(){
	var top = (document.documentElement && document.documentElement.scrollTop) || 
             document.body.scrollTop;
	if($$('floatDiv')){
		$$('floatDiv').style.top = (top + 30) + 'px';
	}
};


function analyzeReply(){
	if($$('NWeb1_NotifyDrRecord')){
		setTimeout(function(){
			var i=0;
			for(row of $$('NWeb1_NotifyDrRecord').rows){
				i++;
				if(i==1){continue;}
				var cells=row.cells;
				
				if((cells[8].innerText.indexOf('CT-guided')<0&&cells[8].innerText.indexOf('血管攝影')<0)||(cells[13].innerText=='刪除'||cells[13].innerText=='待回覆')){continue;}
				
				var url=replyURLcreator($jq(cells[0]).find('a')[2]);
				
				if(!url){continue;}
				
				load(url, function(xhr){
					var row=xhr.element;
					var cells=row.cells;
					
					var match=xhr.responseText.match(/<textarea[^>]+?NWeb1_TextboxSuggestion[^>]+?>([^<]+?)<\/textarea>/);
					var match2=xhr.responseText.match(/<textarea[^>]+?NWeb1_TextboxDescription[^>]+?>([^<]+?)<\/textarea>/);
					
					if(match2){
						$jq(cells[7]).find('span').attr('title', htmlDecode(match2[1]));
					}
					
					if(match){
						$jq(cells[13]).find('span').attr('title', htmlDecode(match[1]));
						// if(m==''){return;}
						var m=match[1].match(/(\d+)\/(\d+)(\/(\d+))?/i);
						var n=match[1].match(/(\d+)\W(\d+)\W(\d+)/i);
						if(m){
							if(m[4]===''){
								cells[13].innerHTML=cells[13].innerHTML+'<br /><span style="color: green;">'+m[1]+'/'+m[2]+'</span>';
							}else{
								cells[13].innerHTML=cells[13].innerHTML+'<br /><span style="color: green;">'+m[1]+'/'+m[2]+'/'+m[4]+'</span>';
							}
						}else if(n && n.length>3){
							cells[13].innerHTML=cells[13].innerHTML+'<br /><span style="color: green;">'+n[1]+'/'+n[2]+'/'+n[3]+'</span>';
						}else{
							// cells[13].innerHTML=cells[13].innerHTML+'\n未排程 ';
							cells[13].innerHTML=cells[13].innerHTML+'<br /><span style="color: red;">'+'未排程 </span>';
						}
					}
				},row);
				
			}
		},0);
	}
}


$$('NWeb1_txbChartNo').select();
$$('NWeb1_ckbSortByNotTime').checked='checked';

function load(url, callback, ele) {
        var xhr;
         
        if(typeof XMLHttpRequest !== 'undefined') xhr = new XMLHttpRequest();
        else {
            var versions = ["MSXML2.XmlHttp.5.0",
                            "MSXML2.XmlHttp.4.0",
                            "MSXML2.XmlHttp.3.0",
                            "MSXML2.XmlHttp.2.0",
                            "Microsoft.XmlHttp"]
 
             for(var i = 0, len = versions.length; i < len; i++) {
                try {
                    xhr = new ActiveXObject(versions[i]);
                    break;
                }
                catch(e){}
             } // end for
        }
         
        xhr.onreadystatechange = ensureReadiness;
         
        function ensureReadiness() {
            if(xhr.readyState < 4) {
                return;
            }
             
            if(xhr.status !== 200) {
                return;
            }
 
            // all is well 
            if(xhr.readyState === 4) {
				xhr.element=ele;
                callback(xhr);
            }          
        }
         
        xhr.open('GET', url, true);
        xhr.send('');
    }

function htmlDecode(input){
  var e = document.createElement('div');
  e.innerHTML = input;
	return e.innerText;
}
	
void 0;