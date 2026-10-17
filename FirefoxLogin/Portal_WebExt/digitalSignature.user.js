// ==UserScript==
// @name          digitalSignature
// @description   
// @include	http://*WebApplication/DigitalSignature/DSQuery.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

DigiSigPw='';


// $$('NWeb1_txbPinCode').value=DigiSigPw;

$$('NWeb1_btnDoSignatureByPCSC').focus();


$jq(document).on('click', '#NWeb1_btnDoSignatureByPCSC', function(e){
	if($jq('#NWeb1_txbPinCode').val()===''){
		$jq('#NWeb1_txbPinCode').focus();
		e.preventDefault();
	}
}).on('keydown', '#NWeb1_txbPinCode', function(e){
	var k=e.which;
	if(k==13){
		$jq('#NWeb1_btnDoSignatureByPCSC').click();
		e.preventDefault();
	}
	
});

void 0;