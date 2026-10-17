browser.runtime.onMessage.addListener(function(message, sender){
	// console.log('from:'+message);
	if('selectedChartNo' in message){
		var injectedCode = "setTimeout(function(){var __chartNoInput=document.getElementsByName('NWeb1$PatientBasicInfoQueryByIDAndName1$ctl01')[0];if(__chartNoInput.value==''){__chartNoInput.value='" + message.selectedChartNo +"';__chartNoInput.select();}}, 500);";
		// var injectedCode = "setTimeout(\"if(!noLogin){$jq('#txtUserID').val('"+message.portalId+"');$jq('#txtPass').val('"+message.portalPw+"');}else{alert('test');}\", 1000);";
		// console.log(injectedCode);
		var s = document.createElement('script');
		s.type='text/javascript';
		s.appendChild(document.createTextNode(injectedCode));
		(document.head || document.documentElement).appendChild(s);
	}
});

_inj_load(['jquery.js', 'PatientMedicalRecordListQuery.user.js']);

