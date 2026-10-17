// ==UserScript==
// @name          digitalSignature
// @description   
// @include	http://*WebApplication/DigitalSignature/DSQuery.aspx*
// ==/UserScript==

// function $$(x){return document.getElementById(x);}

DigiSigPw='';

var openAllWins1=[];
var openAllWins2=[];
var reloadInterval;
$jq('#btnDoSignatureByPCSC').focus();


$jq(document).ready(function(){
	var naming = $jq('h3').first();
	var t = naming.text().replace(/[^\s]*主治醫師[^\s]*/, 'VS');
	var t = t.replace(/[^\s]*住院醫師[^\s]*/, 'R');
	naming.text(t);
	
	// reload every 10 min
	reloadInterval = setInterval(function(){
		$jq('#btnRefresh_All').click();
		$jq('#btnRefresh_e').click();
		$jq('#btnRefresh_d').click();
		iframeSelf();
	},600000);
	
}).on('click', '#btnDoSignatureByPCSC', function(e){
	if($jq('#InputPINPassword').val()===''){
		$jq('#InputPINPassword').focus();
		e.preventDefault();
	}
}).on('keydown', '#InputPINPassword', function(e){
	var k=e.which;
	if(k==13){
		$jq('#btnDoSignatureByPCSC').click();
		e.preventDefault();
	}
	
}).on('dblclick', '#DIV_NeedCheckArea thead:eq(0)', function(e){
	$jq(this).parent().parent().parent().height($jq('#table_NeedCheckArea').height());
}).on('dblclick', '#TopDIVContent div.fixed-table-header thead', function(e){
	var div=$jq(this).parent().parent().parent();
	div.height(div.find('div.fixed-table-body table').height());
}).on('click', '#table_NeedCheckArea tr',  function(event){
	
	if(event.target.tagName.toLowerCase()==='a') return;
	
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
	
});





clickCache=[];
clickTimeout=0;
function refreshChosen(){
	
	for (var i=0; i<clickCache.length; i++){
		var v = clickCache[i];
		if(v.clickCount % 2 ==1){
			var e = $jq(v.obj);
			if(e.attr('chosen')==1){
				e.css({'background-color': '#F5F5F5'});
				e.attr('chosen', 0);
			}else{
				e.css({'background-color': '#555555'});
				e.attr('chosen', 1);
			}
		}
	}
	clickCache=[];
}

var that=0;
// $jq('#table_NeedCheckArea tr').on('click', function(event){
	
	// var found=false;
	// for (var i=0; i<clickCache.length; i++){
		// if(clickCache[i].obj===this){
			// clickCache[i].clickCount += 1;
			// found=true;
			// break;
		// }
	// }
	// if(!found){
		// clickCache.push({obj: this, clickCount: 1});
	// }
	
	
	// if(clickTimeout){clearTimeout(clickTimeout);}
	
	// clickTimeout = setTimeout(refreshChosen, 500);
	
// });


// private use
setTimeout(function(){
	ignoreFn=function(){
		$jq('#table_NeedCheckArea tr').each(function(i, e){
			// if(e.cells[8].innerText.indexOf('主治醫師A')>-1){
				if(['0000001', '0000002'].indexOf(e.cells[1].innerText)>-1){
					e.click();
				}
			// }
		});
	};
	
	$jq('#btnRefresh_All').click(function(){
		setTimeout(ignoreFn,3000);
	});
	
	ignoreFn();
	
}, 5000);



setTimeout(function(){
	$jq('<li/>').insertAfter($jq('#myTab>li:eq(1)')).append($jq('<button/>', {
		'class': 'btn btn-success',
		'id': 'btnToAllNonComplete'
	}).text('全部開啟').click(function(e){
		var loop_i=0;
		$jq('#DIV_NeedCheckArea table a').each(function(){
			if($jq(this).closest('tr').attr('chosen')!=1){
				setTimeout(function(url){
					openAllWins1.push(open(location.href.match(/^http[^\n]+\//) + url));
				}, 1+100*loop_i, $jq(this).attr('href').match(/ConfirmTargetPage\.aspx[^\'\"]+/));
				loop_i+=1;
			}
		});
		
		setTimeout(reloadIfAllClosed,1+100*loop_i,openAllWins1, $jq(this).parent().next().find('button'));
		
		return false;
	}));

	$jq('<button/>', {
		'class': 'btn btn-success',
		'id': 'btnToAllNonComplete'
	}).text('全部開啟').click(function(e){
		var loop_i=0;
		$jq('#table_e a').each(function(){
			setTimeout(function(url){
				openAllWins2.push(open(url));
			}, 1+100*loop_i, $jq(this).attr('href'));
			loop_i+=1;
		});
		
		setTimeout(reloadIfAllClosed,1+100*loop_i,openAllWins2,$jq('#btnRefresh_e'));
		
		return false;
	}).appendTo('#toolbar_buttonDIV_e');
	
	selectAll = function(){$jq('input[name=btSelectAll]')[0].click();};
	$jq('#btnRefresh_d').click(function(){
		setTimeout(selectAll, 3000);
	});
	selectAll();
	
	$jq('#OL_MISWSArea a').each(function(){
		if($jq.trim(this.innerText)!=='0'){
			$jq(this).css({'color': 'red'}).animate({'font-size': '150%', 'font-weight': '700'})
		}
	});
	
	$jq('#countNeedcheckDS').each(function(){
		if($jq(this).text()!=='0'){
			$jq(this).add($jq(this).closest('a')).animate({'font-size': '150%', 'font-weight': '700'});
		}
	});
	
}, 3000);


function reloadIfAllClosed(allWins, refreshButton){
	if(allWins.filter(w => !!w && !w.closed).length==0){
		allWins=[];
		refreshButton.click();
	}else{
		setTimeout(reloadIfAllClosed,1000,allWins,refreshButton);
	}
}

// $jq('#btnDoSignatureByPCSC').on('click', function(e){
	// $jq('#lastCardPw').val($jq('#InputPINPassword').val());
// });
// var nameTitle=$jq('#DIVShowUserName h3').text().match(/([^\s]+)\s([^\s]+)\s(\u60A8\u597D!)/);
// if(nameTitle!==null){
	// var numberConvert={'一':'1'}
	// var title = nameTitle[2].replace(/^[^\s+]\u8058/, '').replace('住院醫師', 'R').replace('主治醫師', 'VS');
	
// }


function iframeSelf(){
	$jq('<iframe>', {src: location.href, id: 'iframeSelfForRefresh'}).hide().on('load', function(){
		setTimeout(function(){$jq('#iframeSelfForRefresh').remove();}, 3000);
	}).appendTo('body');
}


void 0;