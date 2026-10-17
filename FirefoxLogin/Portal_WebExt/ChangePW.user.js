// ==UserScript==
// @name          change password 
// @description   
// @include http://*ChangePassword.aspx*
// ==/UserScript==

function $$(x){return document.getElementById(x);}

function runDes() 
{
	var key = document.getElementById('txtPass').value; 
	var message = document.getElementById('txbNewPass1').value;
	var messageConfirm = document.getElementById('txbNewPass2').value;
	
	if (key == '' || message == '' || messageConfirm == '')
	{
		alert('輸入資料不可為空。');
		return false;
	}
	 
	if ( message != messageConfirm )
	{
		alert('新密碼輸入兩次不相同，請重新確認輸入。');
		return  false;
	}
	var padding = hex_md5(key).substr(0, 8);
	var iv = '';

	message = padding + message;

	while (iv.length < 8) 
	{
		iv = key.length > 7 ? key.substr(0, 8) : iv + key;
	}
	iv = iv.substr(0, 8);
	
	var cipher = document.getElementById('hdfCipher');
	var result = des(key, message, 1, 1, iv);

	result = stringToHex(result); //output as hex
	cipher.value = result; //put the result into the form

}

// a=document.createElement('input');
// a.type='button';
// a.value='延用舊密碼';
// a.onclick=function(){$$('txbNewPass1').value=$$('txtPass').value;$$('txbNewPass2').value=$$('txtPass').value;};
// $$('btnConfirmMod').parentNode.insertBefore(a,$$('btnConfirmMod'));
$$('btnConfirmMod').onclick=function(){return runDes();};

void 0;