if (!String.prototype.splice) {
    /**
     * {JSDoc}
     *
     * The splice() method changes the content of a string by removing a range of
     * characters and/or adding new characters.
     *
     * @this {String}
     * @param {number} start Index at which to start changing the string.
     * @param {number} delCount An integer indicating the number of old chars to remove.
     * @param {string} newSubStr The String that is spliced in.
     * @return {string} A new string with the spliced substring.
     */
    String.prototype.splice = function(start, delCount, newSubStr) {
        return this.slice(0, start) + newSubStr + this.slice(start + Math.abs(delCount));
    };
}
var portalStatus=0;
function portalStatusCheckingDots(n){
	var dot='.';
	if(n>0 && !portalStatus){
		$jq('#portalStatus').html(dot.repeat(n) + '&nbsp;'.repeat(5-n));
		setTimeout(portalStatusCheckingDots, 200, (++n)>5?1:n);
	}
}

$jq(document).ready(function() {
	window.onfocus=windowFocus=function(){
		$jq('#portalid').select();
	};
	
	$jq.ajax({
		url: 'http://portal.hospital-n.local/General/Login.aspx',
		type: 'GET',
		timeout: 5000, 
		success: function(){
			portalStatus=1;
			$jq('#portalStatus').text('\u{2714}').css('color','green');
		},
		error: function(){
			portalStatus=-1;
			$jq('#portalStatus').text('\u{2718}').css('color','red');
		}
	});
	setTimeout(portalStatusCheckingDots, 0, 1);
	
	$jq('#portalid').select();

	$jq(document).on('keydown', function(e){
		var k = e.which;
		
		if(k==13){
			trimInput();
			if($jq('#portalid').val()==''){
				$jq('#portalpw').select();
				e.preventDefault();
			}else if($jq('#portalpw').val()==''){
				$jq('#portalpw').select();
				e.preventDefault();
			}else{
				$jq('#setIdPw').click();
			}
		}
	}).on('click', '#setIdPw', function() {
		trimInput();
		
		if($jq('#portalid').val()!=='' && $jq('#portalpw').val()!==''){
			changeHosp();
			tryLogin($jq('#portalid').val(), $jq('#portalpw').val(), $jq('#hospitalCode').val());
		}else{
			alert('請輸入帳號及密碼！');
			if($jq('#portalid').val()==''){
				$jq('#portalid').select();
			}else if($jq('#portalpw').val()==''){
				$jq('#portalpw').select();
			}
		}
	});
	
	$jq('#version').text(browser.runtime.getManifest().version);
	
	$jq('#portalid').blur(function(){
		var id = $jq('#portalid').val();
		id = $jq.trim(id).toUpperCase();
		if(id==='') return;
		if(id.length<6){
			var match = id.match(/^\D+/);
			var ii=6-id.length;
			if(match){
				for(var i=0;i<ii;i++){id=id.splice(match[0].length,0,'0');}
			}else{
				for(var i=0;i<ii;i++){id='0'+id;}
			}
		}
		$jq('#portalid').val(id);
		
		if(id.indexOf('H')==0){
			$jq('#hospitalCode').val('T4');
		}else if(id.indexOf('Y')==0){
			$jq('#hospitalCode').val('Y0');
		}else if(id.indexOf('N')==0){
			$jq('#hospitalCode').val('T2');
		}else if(id.indexOf('J')==0){
			$jq('#hospitalCode').val('T3');
		}else if(id.indexOf('C')==0){
			$jq('#hospitalCode').val('T5');
		}else if(id.indexOf('A')==0){
			$jq('#hospitalCode').val('C0');
		}
	});
		
});



var url='http://portal.hospital-n.local/General/Login.aspx';
var sidRegEx=/SESSION=(\w+)/;
var portalId='';
var portalPw='';
var hospitalCode='';
var cardPw='';
function tryLogin(id, pw, hCode){
	var dom;var ret=false;
	if(hCode===''){
		hCode = 'T0';
	}
	
	portalId = id.toUpperCase();
	portalPw = pw;
	hospitalCode = hCode.toUpperCase();
	
	var done=false;
	$jq.ajax({
		type: 'GET',
		url: url
	}).always(function(data){
		dom=$jq(data);
		// console.log(dom);
		// console.log(hospitalCode);
		// $jq.ajax({
			// type: 'POST',
			// url: url,
			// data: {
				// __VIEWSTATE: dom.find('#__VIEWSTATE').val(),
				// __EVENTVALIDATION: dom.find('#__EVENTVALIDATION').val(),
				// txtUserID: id.toUpperCase(),
				// txtPass: md5(pw),
				// ddlHospital: hospitalCode,
				// rdblQuickMenu: 'H',
				// 'imgBtnSubmitNew.x': '0',
				// 'imgBtnSubmitNew.y': '0'
			// }
		// })
		// $jq.ajax({
			// type: 'POST',
			// url: 'http://sess.hospital-n.local/SessionService/SessionService.asmx',
			// headers: {
				// 'SOAPAction': '"http://10.0.0.1/General/SessionService.asmx/NewSession"', 
				// 'Host': 'sess.hospital-n.local', 
				// 'Content-Type': 'text/xml; charset=utf-8'
			// },
			// data: '<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><NewSession xmlns="http://10.0.0.1/General/SessionService.asmx"><UserID>'+id.toUpperCase()+'</UserID><password>'+md5(pw)+'</password><RemoteIP>10.0.0.2</RemoteIP><strHospital>'+hCode+'</strHospital></NewSession></soap:Body></soap:Envelope>'
		// }).always(function(data){
			
			
		fetch('http://sess.hospital-n.local/SessionService/SessionService.asmx', {
			method: 'POST', 
			mode: 'cors', 
			cache: 'no-cache', 
			credentials: 'omit', 
			headers: {
				'SOAPAction': '"http://10.0.0.1/General/SessionService.asmx/NewSession"', 
				'Host': 'sess.hospital-n.local', 
				'Content-Type': 'text/xml; charset=utf-8'
			},
			body: '<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><NewSession xmlns="http://10.0.0.1/General/SessionService.asmx"><UserID>'+id.toUpperCase()+'</UserID><password>'+md5(pw)+'</password><RemoteIP>10.0.0.2</RemoteIP><strHospital>'+hCode+'</strHospital></NewSession></soap:Body></soap:Envelope>'
		}).then(function(response){
			if (! response.ok){
				alert('無法登入Portal！');
				$jq('#portalpw').val('').focus().select();
				return;
			}else{
				response.text().then(function(data){
					// console.log(data);
					// data = new XMLSerializer().serializeToString(data);
					var data = $jq.parseXML(data);
					var trySid = 'SESSION=';
					var v = '';
					try {
						var v = data.getElementsByTagName('NewSessionResult')[0].firstChild.firstChild.nodeValue;
					}catch(err){
						console.log(err);
					}
					
					if(v && v!=='False' && sidRegEx.test(trySid+v)){
						trySid += v
						var match=trySid.match(sidRegEx);
						setIdPw(match[1]);
						
						$jq('<tr><td colspan=2 style="text-align: center;" >登入成功！<span id="info"></span></td></tr>').css('color','blue').appendTo($jq('table'));
						setTimeout(function(){browser.runtime.sendMessage({closeMe: 'popupPage'}).catch((err)=>console.error(err));}, 800);
						
						// window.close();
					}else{
						alert('無法登入Portal！');
						$jq('#portalpw').val('').focus().select();
					}
				});
			}
		});
	});
	
	
}

function trimInput(){
	$jq('#portalid').val($jq('#portalid').val().trim().toUpperCase());
	$jq('#portalpw').val($jq('#portalpw').val().trim());
	$jq('#cardpw').val($jq('#cardpw').val().trim());
}			

// function $$(i){return document.getElementById(i);}



function setIdPw(sid){
	if(!sid) return ;
	browser.runtime.sendMessage({
		to: 'background',
		id: portalId,
		pw: portalPw,
		cardPw: cardPw,
		sid: sid.toString(),
		hospitalCode: hospitalCode, 
		loginNewPortal: true
	}).catch((err)=>console.error(err));
}

function changeHosp(){
	if($jq('#portalid').val().indexOf('H')==0) $jq('#hospitalCode').val('T4');
	else if($jq('#portalid').val().indexOf('Y')==0) $jq('#hospitalCode').val('Y0');
}