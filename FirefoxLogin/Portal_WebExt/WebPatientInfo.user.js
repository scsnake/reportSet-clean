// ==UserScript==
// @name          Patient Basic Info
// @description   
// @include	http://*WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleShowiframePage.aspx*
// @include	http://*WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleInfoShowUsingPlaceHolder.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}



// top=window;
// while(top.parent){top=top.parent;}
// alert(top.document.title);

window.top.onload=onL;
var __si1;

$jq(document).ready(function(){
	__si1=setInterval(function(){
		if($jq('iframe').first().contents().text().includes('跨院查閱體系內之病歷，需為臨床醫療需求，且獲病人同意，並遵守相關法令、規範方可使用；學術研究需求，請依醫療體系醫療整合資料庫管理及申請作業辦理')){
			$jq('iframe').first().contents().find('#btnConfirm').click();
			clearInterval(__si1);
		}
	},500);
	
	setTimeout(function(){
		if($jq('iframe').first().contents().text().trim()==='' && $jq('iframe').first().is(':visible')){
			
			$jq('iframe').first().hide();
			var div = $jq('<div/>').css({
				'display': 'flex', 
				'justify-content':'space-evenly', 
				'align-items': 'center',
				'width': '100%'
			});
			$jq('#UpdatePanelPlaceHolder').prepend(div);
			div.height(div.closest('td').height());
			
			var button_title = ['入院','出院','門診','病理','手術'];
			var button_click_path = [
				['住院',0,'入院'], 
				['住院',0,'出院'], 
				['門診',/N總院區門診|分院門診/,0,'Html'], 
				['置頂','報告','病理報告',0], 
				['置頂','手術',0,'手術紀錄'] 
			];
			
			for(var i=0;i<5;i++){
				div.append(
					$jq('<input type="button" id="_button' + i + '" />').css({
						'width': '18%', 
						'height': '12%',
						'font-size': '1.3em',
						'font-family': '"Noto Sans TC", "微軟正黑體"'
					}).val(button_title[i]).click(button_click_path[i], function(e){
						// console.log(e.data);
						var nd = getTreeNode(...(e.data));
						if(nd && nd.length){nd[0].click();}
					})
				);
			}
		}
	}, 500);
	
}).on('keydown', function(e){return keydown(e);});function keydown(e){
	var isTextBox=isTextBoxFocused();

	k=e.which;
	// alert(k);
	if(e.altKey||e.ctrlKey||e.shiftKey){
		return true;
	}
	
	
	if(k==73){ //i
		$jq(window.top.document.getElementById('UpdatePanelPlaceHolder')).find('iframe:first')[0].contentWindow.location.href=window.top.location.href.replace('SimpleShowiframePage','SimpleInfoShowUsingPlaceHolder')+'&AccountIDSE=&Hosp=&WinPup=True&Func=RISReport';
		// links=window.top.document.getElementsByTagName('a');
		// for(var j=0;j<links.length;j++){
			// if(links[j].className=='TreeViewItem_0'){
				// if(unicodes(links[j].innerText,8)==ImageReportIn2Yr){alert('got');
					// links[j].click();
					// return false;
				// }
			// }
		// }
	}
	
	setTimeout(adjustHeight, 3000);
	
}

$jq(document).on('click', function(){
	setTimeout(adjustHeight, 3000);
});

// setInterval(function(){

function adjustHeight(noWait){
	if(!noWait && $jq('iframe')[0].contentDocument && $jq('iframe')[0].contentDocument.readyState!=='complete'){
		setTimeout(adjustHeight, 1000);
		return;
	}
	$jq('#form1').find('*').height('').css({'height': ''});
	$jq('#TableA div').first().css({'overflow': 'auto'});
	$jq('#TableA>tbody>tr>td, #TreeViewItem').height('').css({'vertical-align': 'top', 'height': $jq(window).height()-60});
	
	// $jq('iframe:eq(0)').contents().find('body').height()
	$jq('iframe').each(function(){
		$jq(this).height('').css({'height': $jq(window).height()-80});
	});
}
adjustHeight(false);
// }, 500);

// setInterval(function(){console.log($jq('#TableA td').height());}, 1000);

setTimeout(onL,0);
function onL(){
	if(/SimpleShowiframePage/.test(window.location.href)){
		$jq(window.top.document).find('a').each(function(j){
			var thisText=this.innerText;
			if(/TreeViewItemt\d+/.test(this.id)){
				if(thisText==='住院'){
					$jq(this).closest('table').next().children('table').each(function(i){
						if(i>1){return false;}
						setTimeout($jq(this).find('a:first').attr('href').replace('javascript:',''), 0);
					});
					
				}else if((thisText==='N總院區門診') || (thisText.indexOf('分院門診')>0)){
					$jq.globalEval($jq(this).closest('td').prev().find('a').attr('href').replace('javascript:',''));
					
					$jq('#' + $jq(this).closest('td').prev().find('a').attr('id') + 'Nodes').children('table').each(function(i){
						if(i>4){return false;}
						setTimeout($jq(this).find('a:first').attr('href').replace('javascript:',''), 0);
					});
										
				}else if(['報告', '手術', '內視鏡報告', '病理報告', '放射記錄摘要報告'].indexOf(thisText)>=0){
					setTimeout($jq(this).closest('td').prev().find('a').attr('href').replace('javascript:',''),0);
					
					if(thisText==='手術'){
						$jq(this).closest('table').next().children('table').each(function(i){
							var a = $jq(this).find('a:eq(1)')[0];
							var rec = $jq(a).closest('table').next().children('table').find('a:contains(手術紀錄)').first()[0];
							// console.debug(a);
							// console.debug(rec);
							if(rec && rec.hasAttribute('href')) a.href = rec.href;
							if(rec && rec.hasAttribute('onclick')) a.onclick = rec.onclick;
						});
					}
				}
			}
		});	
		

	}
}

setTimeout(onL2,500);

function onL2(){
	// need to find a way to expand 
	// if(location.href.indexOf('SimpleShowiframePage.aspx')){

		// $jq('#TableA').height('100%')
			// .find('td').height('100%')
			// .find('div').height('100%');
		// $jq('#TableA tr:first td:eq(1)').css('valign', 'top');
		// $jq('#UpdatePlaceHolderShowContent').height('100%');
		// $jq('#TreeViewItem').height('100%');
		// $jq('#TreeViewItemn0Nodes').height('100%');
	// }
	
	
	// if(location.href.indexOf('SimpleInfoShowUsingPlaceHolder.aspx')){
		
		// $jq('#TableA').height('100%')
			// .find('td:first').height('100%')
			// .find('div').height('100%');
		// $jq('#UpdatePlaceHolderShowContent').height('100%');
		// $jq('#TreeViewItem').height('100%');
		// $jq('#TreeViewItemn0Nodes').height('100%');
		
		// var pDoc=$jq(parent.document);
		// var ifr=pDoc.find('iframe:first').contents();
		
		
		// var h=Math.max(pDoc.find('#TableA').outerHeight(),ifr.find('#TableA tr:first td:eq(1)').outerHeight())*1+20;
			
		
		// pDoc.find('#TableA').css('height', h);


		// ifr.find('#TableA tr:first td:eq(1)').css('height', h);
		// pDoc.find('#UpdatePanelPlaceHolder').css('height', h)
			// .find('div:first').css('height', h);
		// pDoc.find('iframe:first').css('height', h);
		
	// }
}


// $$('TableA').height="100%";
// $$('TableA').getElementsByTagName('TD')[0].height="100%";
// $$('TableA').getElementsByTagName('TD')[0].firstChild.style.height="100%";
// $$('TableA').getElementsByTagName('TD')[1].height="100%";
// $$('TableA').getElementsByTagName('TD')[1].vAlign="top";
// setTimeout(updateDivHeight,500);
// $$('UpdatePanelPlaceHolder').getElementsByTagName('IFRAME')[0].height="100%";
// $$('TreeViewItem').style.height="100%";

// function updateDivHeight(){
	// if(!$$('UpdatePanelPlaceHolder')){return;}
	// $$('UpdatePanelPlaceHolder').style.height=$$('TableA').getElementsByTagName('TD')[0].height+'px';
	// $$('UpdatePanelPlaceHolder').getElementsByTagName('DIV')[0].style.height="100%";
	// setTimeout(updateDivHeight,500);
// }
function getTreeNode(...nodeNames){
	var thisNode = $jq('#TreeViewItemt0');
	var nextNode;
	for (nodeName of nodeNames){
		if(nodeName==='Start') continue;
		if(Number.isInteger(nodeName)){
			nextNode = thisNode.closest('table').next().children('table').find('a:eq(-1)').eq(nodeName);
		}else if(nodeName instanceof RegExp){
			nextNode = thisNode.closest('table').next().children('table').find('a:eq(-1)').filter(function(){
				return nodeName.test(this.innerText);
			});
		}else{
			nextNode = thisNode.closest('table').next().children('table').find('a:eq(-1)').filter(function(){
				return this.innerText.trim()===nodeName.trim();
			});
			
			if (!nextNode.length){
				nextNode = thisNode.closest('table').next().children('table').find('a:eq(-1)').filter(function(){
					return this.innerText.includes(nodeName.trim());
				});
			}

		}
		
		
		if (!nextNode.length) return false;
		
		thisNode = nextNode;
	}
	return thisNode;
}


void 0;