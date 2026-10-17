_inj_load(['jquery.js', 'PortalLogin.user.js']);

var __leaving=false;
// msg from background script
browser.runtime.onMessage.addListener(function(message, sender){
	// console.log(message);
	if('portalId' in message && 'portalPw' in message && 'hospitalCode' in message && message.portalId.length>0 && message.portalPw.length>0 && message.hospitalCode.length>0){
		try{
			if(message.to==='background') return;
		}catch(e){}
		
		if(('sid' in message) && (message.sid.length)){
			if (__leaving) return;
			else {
				__leaving = true;
				
				if(location.href.indexOf('firefoxautologin')>-1){
					$jq('#noLogin').val('1');
					
				}else{
						setTimeout(function(sid){
							if($jq('#noLogin').val()==='0')
								location.href = 'http://portal.hospital-n.local/General/NewRedirect.aspx?SESSION='+sid+'&firefoxautologin=1';
						}, 1000, message.sid);
				}
				
				
				
			}
			// console.log('http://portal.hospital-n.local/General/NewRedirect.aspx?SESSION='+message.sid);
			// open('http://portal.hospital-n.local/General/NewRedirect.aspx?SESSION='+message.sid);
			
		}else{
			$jq('#reqLogin').text(JSON.stringify({'id':message.portalId,'pw':message.portalPw,'hospitalCode':message.hospitalCode}));
		}
		 
		// var injectedCode = "$jq('#autoLoginId').val('"+message.portalId+"');$jq('#validSid').val('"+message.sid+"');setTimeout(\"if(!noLogin){$jq('#txtUserID').val('"+message.portalId+"');$jq('#txtPass').val('"+message.portalPw+"');$jq('#ddlHospital').val('"+message.hospitalCode+"');$jq('#imgBtnSubmitNew')[0].click();}\", 800);";
		
		// var s = document.createElement('script');
		// s.type='text/javascript';
		// s.appendChild(document.createTextNode(injectedCode));
		// (document.head || document.documentElement).appendChild(s);
	}else if ('requestPortalLoginResult' in message){
		var result = message.requestPortalLoginResult;
		if(result && result.length){
			$jq('#validSid').val(result);
			$jq('#validSid')[0].onchange();
			location.href = 'http://portal.hospital-n.local/General/NewRedirect.aspx?SESSION='+result;
		}else{
			$jq('#useNormalLogin').val('1');
			$jq('#txtVerifyCode').select();
		}
		
	}
});


// browser.runtime.sendMessage({askFor: 'portalAccount'});

// document.addEventListener('DOMContentLoaded', function() {
document.addEventListener('submit', function(){
	browser.runtime.sendMessage({
		id: document.getElementById('txtUserID').value.toUpperCase(),
		pw: document.getElementById('txtPass2').value,
		hospitalCode: document.getElementById('ddlHospital').value.toUpperCase()
	});
});

var validSidInput=document.createElement('input');
validSidInput.type='hidden';
validSidInput.id='validSid';
validSidInput.onchange=function(){
	browser.runtime.sendMessage({
		id: document.getElementById('txtUserID').value.toUpperCase(),
		pw: document.getElementById('txtPass2').value,
		hospitalCode: document.getElementById('ddlHospital').value.toUpperCase(), 
		sid: document.getElementById('validSid').value
	});
};
document.body.appendChild(validSidInput);

var validSidInput=document.createElement('input');
validSidInput.type='hidden';
validSidInput.id='useNormalLogin';
validSidInput.value=0;
document.body.appendChild(validSidInput);
	
// });

$jq(document).ready(function(){
	setTimeout(function(){
		if(!__leaving) browser.runtime.sendMessage({askForLogin: true});		
	}, 1000);
	
	
	$jq('#Form1').unbind('submit').bind('submit', function(e){
		if($jq('#useNormalLogin').val()==='1' || $jq('#txtVerifyCode').val()!==''){
			
		}else{
			e.preventDefault();
		}
		
	});
	$jq('#imgBtnSubmitNew').unbind('click').bind('click', function(e){
		if($jq('#useNormalLogin').val()==='1' || $jq('#txtVerifyCode').val()!==''){
			
		}else{
			e.preventDefault();
		}
	});
	
	$jq('<input type=hidden id=reqLogin />').appendTo($jq(document.body));
	
	setInterval(function(){
		var jn = $jq('#reqLogin').text();
		var json_data;
		
		if(jn==='') return;
		
		try{
			json_data = JSON.parse(jn);
			json_data['requestPortalLogin'] = 1;
			browser.runtime.sendMessage(json_data);
			$jq('#reqLogin').text('');
		}catch(e){}
		
	},200);
	
	
});