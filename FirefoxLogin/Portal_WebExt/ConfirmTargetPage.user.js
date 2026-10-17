// ==UserScript==
// @name          VS Confirm Target
// @description   
// @include	http://*.hospital-n.local/*WebApplication/MedicalRecordManagement/VSConfirmTargetPage.aspx*
// ==/UserScript==

// location.href= $jq('#ifrReporting').attr('src');
// $jq('#ifrReporting').load(function(){
	// var src = $jq('#ifrReporting').attr('src');
	// var ifr = $jq('#ifrReporting').contents();
	
	// if(src.indexOf('hospital-n.local/WebApplication/InPatient/Ward/InsertProgressNoteContent.aspx')>-1){
		// var match = ifr.find('#NWeb1_PatBasicInfoLabel').text().match(/([^\(]+)\([^\)]+\)\s*(\w+)[\w\W]+?T\d-([\w-\s]+)\s*等/);
		// document.title = '病程紀錄';
		// if(match){
			// document.title = ['病程紀錄: ',
				// match[1],
				// match[2],
				// match[3].replace(' ','')].join(' ');
		// }

	// }else if(src.indexOf('hospital-n.local/WebApplication/InPatient/Ward/NotifyOtherDoctor.aspx')>-1){
		// var match = ifr.find('#NWeb1_PatBasicInfoLabel').text().match(/病:(\w+)\s*床號:T\d-([\w\s-]+)/);
		// document.title='照會';
		// if(match){
			// document.title = ['照會: ',
				// match[1],
				// match[2].replace(' ',''),
				// $jq(this).find('#NWeb1_TextboxMainPurpose').val()].join(' ');
		// }
		
	// }
	
	
// });




void 0;