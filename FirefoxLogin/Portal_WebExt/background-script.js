var portalId = '';
var portalPw = '';
var hospitalCode = '';
var cardPw = '';
var portalInfoIsSet = false;
var selectedChartNo = '';
var loginNewPortal=true;
// var validSid=[];
// var invalidSid=[];
var sidPool = new Map(); // key (sid): value (valid or not)
var id_sid = new Map(); // key (id): value (array of sid)
var id_pw = new Map();
var id_hc = new Map();
var id_cardpw = new Map();
// var sidNowChecking = [];
const sidRegEx = /SESSION=(\w+)/;
const loginPageRegEx = /^https?:\/\/(portal|testenv)(|\.hospital-n\.local)\/General\/Login.aspx/;
const newPortalUrl = 'portal.hospital-n.local/General/NewRedirect.aspx';
const patientQueryUrl = 'http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PatientMedicalRecordListQuery.aspx';
const digiSignRegEx = /^https?:\/\/ihisaw.hospital-n.local\/WebApplication\/DigitalSignature\/D(S|s)Query.aspx/;
const portalRegEx = /^https?:\/\/[^.]+.hospital-n.local($|\/[^\n]*)/;
//open login page on startup
var popupTab;
// var sidNowCheckingTO;


// focusTab5Sec('popup/PortalLogin.html',3);

function openPopup(){
	var popupURL = browser.extension.getURL('popup/PortalLogin.html');
	
	browser.tabs.query({url: popupURL}).then(
		function(tabs){
			if(tabs.length>0){
				browser.tabs.update(tabs[0].id, {active: true});
			}else{
				browser.tabs.create({
					url: popupURL
				}).then(function (tab) {
					popupTab = tab;
				});
			}
		}
	);
	
	
}

function cancel(requestDetails){
	// console.log("Canceling: " + requestDetails.url);
	// console.log(requestDetails);
	if(loginPageRegEx.test(requestDetails.originalUrl)){
		return {cancel: true};
	}
}

// block loading intra pic at login page
browser.webRequest.onBeforeRequest.addListener(
	cancel,
  {urls: [
		'http://intra.hospital-n.local/news/document/message_board.htm',
		'http://intra.hospital-n.local/news/document/staff_message.htm',
		'http://intra.hospital-n.local/news/images1/building.jpg', 
		'http://intra/news/images1/book.jpg', 
		'http://intra/news/images1/staff_bg.gif'
	]},
  ["blocking"]
);

function getValidSid(id){
	var ret = [];
	if(id_sid.has(id)){
		var sids = id_sid.get(id);
		var sid;
		for(sid of sids){
			if((sidPool.has(sid)) && (sidPool.get(sid))) ret.push(sid);
		}
	}
	return ret;
}

function tabEventHandler(tabId, changeInfo, tabInfo) {
	// console.log(portalInfoIsSet);
	// console.log(portalId);
	// if(!portalInfoIsSet){return;}

	// onUpdated return tabId, onActivated return activeInfo
	var tabId = Number.isInteger(tabId) ? tabId : (tabId.tabId);

	if (tabId) {
		browser.tabs.get(tabId).then(function (tab) {
			var url = tab.url;
			// alert(url);
			// console.log(url);
			
			if(loginPageRegEx.test(url) && (portalId.length == 0 || portalPw.length == 0)){
				
				// browser.idle.queryState(5).then(function(state){
					// if(state==='idle'){
						// browser.tabs.query({currentWindow: true}).then(function(tabs){
							// for (tab of tabs){
								// var url = tab.url;
								// if (/popup\/PortalLogin\.html$/.test(url)){
									// browser.tabs.update(tab.id, {active: true}).catch((err)=>console.error(err));
									// activateOnce--;
									// return;
								// }
							// }
							
						// });
					// }
				// });
				
		

			}else if (loginPageRegEx.test(url) && portalId.length > 0 && portalPw.length > 0) {
				var validSid='';
				if (id_sid.has(portalId)){
					for (s of id_sid.get(portalId)) {
						if ((sidPool.has(s)) && sidPool.get(s)){
							validSid=s;
							break;
						}
					}
				}
				if(validSid){
					
					browser.tabs.sendMessage(tab.id, {
						portalId: portalId,
						portalPw: portalPw,
						hospitalCode: hospitalCode, 
						sid: validSid, 
						loginNewPortal: loginNewPortal
					}).catch((err)=>console.error(err));
					setTimeout(checkSid, 0, validSid);
					setTimeout(routineCheckSid, 1000);
				
				}
				
				
			} else if ((digiSignRegEx.test(url) || url.indexOf(newPortalUrl) > 0) && cardPw.length > 0) {
				browser.tabs.sendMessage(tab.id, {
					cardPw: cardPw
				}).catch((err)=>console.error(err));

			} else if (selectedChartNo.length > 0
				 && url.indexOf('/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/PatientMedicalRecordListQuery.aspx') > -1) {

				browser.tabs.sendMessage(tab.id, {
					selectedChartNo: selectedChartNo
				}).catch((err)=>console.error(err));
			}

		}, (err)=>console.error(err));

	}

}

// listen to tab URL changes
browser.tabs.onUpdated.addListener(tabEventHandler);

// listen to tab switching
var activateOnce=1;
browser.tabs.onActivated.addListener(tabEventHandler);
// tabEventHandler();

// for 4th lab, avoid redirecting to mobile page
// browser.webRequest.onBeforeSendHeaders.addListener(function (e) {
	// for (var header of e.requestHeaders) {
		// if (header.name.toLowerCase() === "user-agent") {
			// header.value = "Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko";
		// }
	// }
	// return {
		// requestHeaders: e.requestHeaders
	// };
// }, {
	// urls: ["*://*.hospital-n.local/WebApplication/ElectronicMedicalReportViewer/MedicalReportContent.aspx*"]
// },
	// ["blocking", "requestHeaders"]);

// redirect VS confirm page
// browser.webRequest.onBeforeRequest.addListener(function(requestDetails){

// return {redirectUrl: ""};
// },
// {urls: ["*://*.hospital-n.local/WebApplication/MedicalRecordManagement/VSConfirmTargetPage.aspx*"]},
// ["blocking"]
// );


browser.runtime.onMessage.addListener(function (message, sender) {
	// console.log(message);
	// console.log(sender);

	// disable request from page for safety
	// if('askFor' in message){
	// // console.log((message.askFor==='portalAccount') +','+ portalInfoIsSet +','+loginPageRegEx.test(sender.tab.url));
	// if(message.askFor==='portalAccount' && loginPageRegEx.test(sender.tab.url) && portalInfoIsSet){
	// browser.tabs.sendMessage(sender.tab.id, {portalId: portalId, portalPw: portalPw});
	// }else if(message.askFor==='cardPw' && sender.tab.url.indexOf(digiSignUrl)==0 && cardPw.length>0){
	// browser.tabs.sendMessage(sender.tab.id, {cardPw: cardPw});
	// }
	// }else
	if ('closeMe' in message) {
		// console.log(message.closeMe);
		if (message.closeMe === 'popupPage' && popupTab) {
			browser.tabs.remove(popupTab.id).catch((err)=>console.error(err));

			function reloadTabs(tabs) {
				if (!portalInfoIsSet) {
					return;
				}

				var i = 0;
				
				var validSid='';
				if (id_sid.has(portalId)){
					for (s of id_sid.get(portalId)) {
						if ((sidPool.has(s)) && sidPool.get(s)){
							validSid=s;
							break;
						}
					}
				}
				
				for (tab of tabs) {
					if (tab === popupTab) { // need not reload popup page
						continue;
					}
					var url = tab.url;
					// console.log('reload: '+url);
					if (loginPageRegEx.test(url)) {
						// console.log('send:'+tab.id);
						// console.log(tab);
						i++;
						if (i == 1) {
							browser.tabs.update(tab.id, {active: true}).catch((err)=>console.error(err));
						}
						
						if(validSid){
							browser.tabs.executeScript(tab.id, {
								code: "try{location.href=location.href;}catch(e){}"
							})
							
							// browser.tabs.reload(tab.id);
							
							// browser.tabs.sendMessage(tab.id, {
								// portalId: portalId,
								// portalPw: portalPw,
								// hospitalCode: hospitalCode, 
								// sid: validSid,
								// loginNewPortal: loginNewPortal
							// }).catch((err)=>console.error(err));
						}
						
					} else if (digiSignRegEx.test(url) || url.indexOf(newPortalUrl) > 0) {
						browser.tabs.sendMessage(tab.id, {
							cardPw: cardPw
						}).catch((err)=>console.error(err));

					}
				};
			}
			var gettingTabs = browser.tabs.query({
					currentWindow: true
				});
			gettingTabs.then(reloadTabs);

		}
	} else if ('gotSource' in message) {
		if (sidRegEx.test(message.gotSource)) {
			var match = message.gotSource.match(sidRegEx);
			// console.log('gotsource: ' + match[1]);
			setTimeout(refreshSidList, 0, match[1]);
			// console.log('gotSource SID: ' + match[1]);
		}
	} else if ('focusMe' in message) {
		var url = message.url;
		browser.tabs.query({url: url}).then(
			function(tabs){
				if(tabs.length>0) browser.tabs.update(tabs[0].id, {active: true});
			}
		);
		// focusTab5Sec(url);
	} else if ('selectedChartNo' in message) {
		selectedChartNo = message.selectedChartNo;
	} else if ('openInIE' in message) {
		// console.log('openInIE'+message.URL);
		openInIE(message.openInIE);
	} else if ('requestPortalLogin' in message) {
		var id = message.id;
		var pw = message.pw;
		var hCode = message.hospitalCode;
		
		portalLogin2(id, pw, hCode, function(res){
			var sending = browser.tabs.sendMessage(sender.tab.id, {'requestPortalLoginResult': res}).catch((err)=>console.error(err));
			
			if(res){
				portalId = message.id;
				portalPw = message.pw; id_pw.set(portalId, portalPw);
				hospitalCode = message.hospitalCode; id_hc.set(portalId, hospitalCode);
				portalInfoIsSet = true;
			}
		});
	} else if (('refreshSid' in message && message.refreshSid) && message.sid) {
		// console.log('openInIE'+message.URL);
		if (! (sidPool.has(message.sid))) sidPool.set(message.sid, true);
		if (! (id_sid.has(message.id))) id_sid.set(message.id, []);
		if (! (id_sid.get(message.id).indexOf(message.sid)>-1)) id_sid.get(message.id).push(message.sid);
	} else if ('askForLogin' in message) {
		openPopup();
	} else if ('requestDecryptKey' in message) {
		if(message.sid!==''){
			$jq.get({
				url: 'http://portal.hospital-n.local/General/ChangePassword.aspx?SESSION=' + message.sid, 
				success: function(data){
					var val = $jq(data).find('tr>td>font').eq(0).text().trim();
					if(!val || val==='') return;
					var sending = browser.tabs.sendMessage(sender.tab.id, {'decryptKey': val}).catch((err)=>console.error(err));
					
				}, 
				dataType: 'text',
				crossDomain: true});
		}
	} else {
		if (('logout' in message) && message.logout.length > 0 ) {
			portalId = '';
			portalPw = '';
			hospitalCode = '';
			cardPw = '';
						
			portalInfoIsSet = false;
			
			if ('sid' in message && message.sid.length>0 && message.sid)	sidPool.set(sid, false);
			
			
			routineCheckSid();
		}

		if (('id' in message) && ('pw' in message) && ('hospitalCode' in message)) {
			var portalInfoIsChanged = 0;
			// // console.log(message.id  + "," + portalId);

			if (message.id.length > 0 && message.id != portalId) {

				portalId = message.id.toUpperCase();
				portalInfoIsChanged++;
			}
			if (message.pw.length > 0 && message.pw !== portalPw) {
				portalPw = message.pw;
				id_pw.set(portalId, portalPw);
				portalInfoIsChanged++;
			}
			if (message.loginNewPortal.length > 0 && message.loginNewPortal !== loginNewPortal) {
				loginNewPortal = message.loginNewPortal;
				portalInfoIsChanged++;
			}
			if ('sid' in message && message.sid.length > 0 && message.sid) {
				sidPool.set(message.sid, true);
				if(message.id){
					if (!(id_sid.has(message.id))){
						id_sid.set(message.id, []);
					}
					id_sid.get(message.id).push(message.sid);
				}
			}
			if (message.hospitalCode.length > 0 && message.hospitalCode !== hospitalCode) {
				hospitalCode = message.hospitalCode.toUpperCase();
				id_hc.set(portalId, hospitalCode);
				portalInfoIsChanged++;
			}
			if (portalInfoIsChanged >= 3) {
				portalInfoIsSet = true;
			}

			if (portalInfoIsChanged > 0) {
				routineCheckSid();
			}
		}

		if (('cardPw' in message) && message.cardPw.length > 0) {
			cardPw = message.cardPw;
			if(portalId) id_cardpw.set(portalId, cardPw);
		}
	}

});

var checkSidTI;
function routineCheckSid(){
	clearInterval(checkSidTI);
	setTimeout(function(){checkSid();},0);
	checkSidTI = setInterval(function () {
		checkSid();
	}, 300000);
	
}

function checkSid(sid) {
	sid = sid ? sid.toString() : '';
	if (sid !== '') {
		// console.log('Check ' + sid + ' at '+ (new Date().toLocaleString()));
		refreshSidList(sid);
	} else {
		// sidNowChecking = [];
		// clearTimeout(sidNowCheckingTO);
		// sidNowCheckingTO = setTimeout(function () {
			// sidNowChecking = [];
		// }, 60000); // reset
	// console.log('Check all session id at '+ (new Date().toLocaleString()));

		for (let [key, value] of sidPool) {
			if(value) refreshSidList(key);
		}

		function updateTabs(tabs) {
			var tab;

			for (tab of tabs) {
				if (sidRegEx.test(tab.url)) {
					var match = tab.url.match(sidRegEx);
					refreshSidList(match[1]);
				} else if (portalRegEx.test(tab.url)){
					
					browser.tabs.sendMessage(tab.id, {
						getSource: 'getSource'
					}).catch((err)=>console.error(err));
					
					
				}
			};
		}
		var gettingTabs = browser.tabs.query({
				currentWindow: true
			});
		gettingTabs.then(updateTabs);

	}

}

function sidIsValid(sid) {
	// var xhr = new XMLHttpRequest();

	// xhr.open("GET", "http://portal.hospital-n.local/General/Redirect.aspx?SESSION="+sid, false);
	// xhr.send();
	if (!sid) {
		return;
	}

	$jq.ajax({
		type: 'GET',
		url: 'http://portal.hospital-n.local/General/Redirect.aspx?SESSION=' + sid,
		sid: sid
	}).done(function (data) {
		// sidPool[this.sid] = (data.indexOf(this.sid) > -1);
		// sidPool[this.sid] = sidRegEx.test(data);

		//jQuery cannot detect redirect
		sidPool.set(this.sid, (data.toString().indexOf(this.sid) > 0));
		// console.log(this.sid, (data.indexOf('window.mm_menu02_01')>0));

	});

}

function refreshSidList(sid) {
	var ind;
	if (!sid) return;
	sid = sid.toString();
	// if (sidNowChecking.indexOf(sid) > -1) { // recently checked
		// return;
	// } else {
		// sidNowChecking.push(sid);
	// }
	
	setTimeout(function (sid) {
		sidIsValid(sid);
	}, 0, sid);
	// sidPool[sid]=sidIsValid(sid);

	// var isValid=sidIsValid(sid);

	// if(!isValid){
	// ind=validSid.indexOf(sid)
	// if(ind>-1){validSid.splice(ind, 1);}
	// ind=invalidSid.indexOf(sid)
	// if(ind>-1){invalidSid.splice(ind, 1);}
	// invalidSid.push(sid);
	// }else{
	// ind=invalidSid.indexOf(sid)
	// if(ind>-1){invalidSid.splice(ind, 1);}
	// ind=validSid.indexOf(sid)
	// if(ind>-1){validSid.splice(ind, 1);}
	// validSid.push(sid);
	// }
}

var appPort = browser.runtime.connectNative('FirefoxLoginApp');

appPort.onMessage.addListener(function (response) {
	
	
	if (!(typeof response === 'function' || (typeof response === 'object' && !!response))) return; // determine object
	
	if ('searchChartNo' in response && response.searchChartNo !== '' && response.searchChartNo.length == 7) {
		console.log('search chartno: '+response.searchChartNo);
		searchChartNo(response.searchChartNo);
	}
});

function searchChartNo(chartNo) {
	

	browser.tabs.query({
		currentWindow: true
	}).then(function (tabs) {
		var patientQueryTabIsOpened = false;
		for (tab of tabs) {
			var url = tab.url;
			if (url.indexOf(patientQueryUrl) == 0) {
				patientQueryTabIsOpened = tab;
				break;
			}
		}

		if (!patientQueryTabIsOpened) {
			
			// if (!portalInfoIsSet) {
				// console.log('portal info not available');
				// return;
			// }

			var willUseSid = '';
			// get a valid sid from pool
			for (let [key, value] of sidPool) {
				if (value === true) {
					willUseSid = key;
					break;
				}
			}

			if (willUseSid === '') {
				console.log('searchChartNo: no available sid');
				return;
			}

			browser.tabs.create({
				'active': true,
				'url': patientQueryUrl + '?QueryBySelf=N&SESSION=' + willUseSid + '&NWeb1%24PatientBasicInfoQueryByIDAndName1%24ctl01=' + chartNo
			}).then(function (tab) {
				searchPatientChartNo(tab.id, chartNo);
			});
		} else {
			// patient query tab opened
			browser.tabs.update(patientQueryTabIsOpened.id, {active: true});
			browser.tabs.executeScript(patientQueryTabIsOpened.id, {
				// code: 'window.focus();location.href="' + patientQueryUrl + '?QueryBySelf=N&SESSION=' + willUseSid + '&NWeb1%24PatientBasicInfoQueryByIDAndName1%24ctl01=' + chartNo + '";'
				code: 'codeInjection(\'__searchByPatientChartNo("' + chartNo + '");\');'
			}).then(()=>{
				searchPatientChartNo(patientQueryTabIsOpened.id, chartNo);
			});
			
		}
	});
}

function searchPatientChartNo(tabId, chartNo) {
	// wait patient query tab loaded
	browser.tabs.get(tabId).then(function (tab) {
		var tabId = tab.id;
		var checkPatientQueryTabLoaded = setInterval(function (tabId, chartNo) {
				browser.tabs.get(tabId).then(function (tab) {
					if (tab.status === 'complete' && tab.title.indexOf('就診紀錄: ' + chartNo) == 0) {
						clearInterval(checkPatientQueryTabLoaded);
						clearTimeout(checkPatientQueryTabLoadedTimeout);
						browser.tabs.executeScript(tab.id, {
							code: "try{if(oNewWin.document.innerText.indexOf(chartNo)>-1){oNewWin.focus();}else{document.getElementById('NWeb1_PatAccountListRecord1_ButtonWebEMR').click();}}catch(e){document.getElementById('NWeb1_PatAccountListRecord1_ButtonWebEMR').click();}"
						}).catch((err)=>console.error(err));
						
						setTimeout(function(){
							browser.tabs.query({url: 'http://ihisaw.hospital-n.local/WebApplication/OtherIndependentProj/PatientBasicInfoEdit/SimpleShowiframePage.aspx*'}).then(function(tabs){
								console.log(tabs);
								if(tabs.length) browser.tabs.update(tabs[0].id, {active:true});
							}, (err)=>console.error(err));
							
						},5000);
						
						
					} else if (tab === null) {
						clearInterval(checkPatientQueryTabLoaded);
						clearTimeout(checkPatientQueryTabLoadedTimeout);

					}
				});
			}, 200, tabId, chartNo);
		var checkPatientQueryTabLoadedTimeout = setTimeout(function () {
				clearInterval(checkPatientQueryTabLoaded);
			}, 60000);

	});

}

// function searchPatientChartNo(tabId, chartNo) {
// browser.tabs.executeScript(tabId, {
// code: "document.addEventListener('DOMContentLoaded', function() { __searchByPatientChartNo('" + chartNo + "');});"
// });
// var checkPatientQueryTabLoaded2 = setInterval(function (tabId) {
// browser.tabs.get(tabId).then(function (tab) {
// if (tab.status === 'complete') {
// clearInterval(checkPatientQueryTabLoaded2);
// browser.tabs.executeScript(tabId, {
// code: "document.addEventListener('DOMContentLoaded', function() { document.getElementsByName('NWeb1_PatAccountListRecord1_ButtonWebEMR')[0].click();});"
// });
// }
// });
// }, 200, tabId);

// }
// test();
// function test(){

// browser.runtime.sendNativeMessage('FirefoxLoginApp', {'test':345})
// }

function openInIE(url) {
	// console.log('open in ie func: \n' + url)
	appPort.postMessage({'URL': url});
	// var sending = browser.runtime.sendNativeMessage('FirefoxLoginApp', {
			// 'URL': url
		// });
	// sending.then(onResponse, onError);
}

function onResponse(response) {
	console.log("Received " + response);
}

function onError(error) {
	console.log(`Error: ${error}`);
}



function portalLogin2(id, pw, hospitalCode, handler){
	var sid = getValidSid(id);
	if(sid.length){
		handler(sid[0]);
		return;
	}
	
	$jq.ajax({
		type: 'POST',
		url: 'http://sess.hospital-n.local/SessionService/SessionService.asmx',
		headers: {
			'SOAPAction': '"http://10.0.0.1/General/SessionService.asmx/NewSession"', 
			'Host': 'sess.hospital-n.local', 
			'Content-Type': 'text/xml; charset=utf-8'
		},
		data: '<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><NewSession xmlns="http://10.0.0.1/General/SessionService.asmx"><UserID>'+id.toUpperCase()+'</UserID><password>'+md5(pw)+'</password><RemoteIP>10.0.0.2</RemoteIP><strHospital>'+hospitalCode+'</strHospital></NewSession></soap:Body></soap:Envelope>'	
	}).always(function(data, textStatus, errorThrown){
		// console.log(data);
		// console.log(textStatus);
		// console.log(errorThrown);
		// data = new XMLSerializer().serializeToString(data);
		var trySid = '';
		try {
			trySid = data.getElementsByTagName('NewSessionResult')[0].firstChild.firstChild.nodeValue;
		}catch(err){
			handler(false);
		}
		if(trySid!==''){
			handler(trySid);
		}else{
			handler(false);
		}
	});	
	
}



function focusTab5Sec(url, seconds){
	return;
	if(!seconds) seconds=5;
	seconds*=1000;
	var focusInterval = setInterval(function(){
		browser.idle.queryState(0.2).then(function(state){
			console.log(state);
			if(state==='idle'){
				browser.tabs.query({active: true, currentWindow: true}).then(function(tabs){
					for (let tab of tabs){
						if(tab.url.indexOf(url)>-1) return;
					}
					
					browser.tabs.query({currentWindow: true}).then(function(tabs){
						for (let tab of tabs){
							if(tab.url.indexOf(url)>-1){
								browser.tabs.update(tab.id, {active: true});
								clearInterval(focusInterval);
								return;	
							}
						}
					});
				});
			}else if(state==='active'){
				clearInterval(focusInterval);
			}
			
		});
		
	},100);
	setTimeout(function(f){clearInterval(f);},seconds,focusInterval);
}