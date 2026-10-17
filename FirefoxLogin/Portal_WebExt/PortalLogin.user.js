// ==UserScript==
// @name          N hospital Portal auto-login
// @description
// @include       http://portal*Login.aspx*
// ==/UserScript==

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

function $$(x) {
	return document.getElementById(x);
}

var noLogin = false;
var username = '';
var password = '';
var passwordEncoded = false;

$$('rdblQuickMenu_0').checked = true;
$$('ddlHospital').value = 'T0';

$jq(document).ready(function(){
	$$('ddlHospital').onchange='';
	$$('ddlHospital').value='T0';
	
	$jq('#txtUserID').blur(function(){
		var id = $jq('#txtUserID').val();
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
		$jq('#txtUserID').val(id);
		
		if(id.indexOf('H')==0){
			$jq('#ddlHospital').val('T4');
		}else if(id.indexOf('Y')==0){
			$jq('#ddlHospital').val('Y0');
		}else if(id.indexOf('N')==0){
			$jq('#ddlHospital').val('T2');
		}else if(id.indexOf('J')==0){
			$jq('#ddlHospital').val('T3');
		}else if(id.indexOf('C')==0){
			$jq('#ddlHospital').val('T5');
		}else if(id.indexOf('A')==0){
			$jq('#hospitalCode').val('C0');
		}
	});
}).on('keydown', function (e) {
	$jq('#noLogin').val('1');
	noLogin=true;
	
	var k = e.which;

	if (k == 13) {
		if ($$('txtUserID').value == '') {
			$$('txtUserID').focus().select();
			return e.preventDefault();
		} else if ($$('txtPass').value == '') {
			$$('txtPass').focus().select();
			return e.preventDefault();
		}else {
			$$('imgBtnSubmitNew').click();
		}
	}

}).on('mousedown', function () {
	$jq('#noLogin').val('1');
}).on('keydown', '#txtPass', logPass)
	.on('change', '#txtPass', logPass)
	.on('blur', '#txtPass', logPass);

// log uncrypted password
$jq('<input/>', {
	id: 'txtPass2',
	type: 'hidden',
	value: ''
}).appendTo(document.body);

// log valid sid
// $jq('<input/>', {
	// id: 'validSid',
	// type: 'hidden',
	// value: ''
// }).appendTo(document.body);

// log autologin id
$jq('<input/>', {
	id: 'autoLoginId',
	type: 'hidden',
	value: ''
}).appendTo(document.body);

$jq('<input/>', {
	id: 'noLogin', 
	type: 'hidden',
	value: '0'
}).appendTo(document.body);

function logPass(){
	if(!passwordEncoded){
		$jq('#txtPass2').val($jq('#txtPass').val());
	}
}

$jq('table:eq(3)').find('td:first').html('<input type=button id="cancelAutoLoginButton" value="   ' + '按任意鍵' + String.fromCharCode(10) + '取消自動登入' + '" />')
.find(':first-child')
.css({'width': '385px', 
			'height': '221px', 
			'font-weight': 'bold', 
			'font-size': '2.5em', 
			'font-family': 'Noto Sans TC'})
.on('mousedown', function () {
	$jq('#noLogin').val('1');
	$jq('#cancelAutoLoginButton').val('取消自動登入!');
	$jq('#txtUserID').focus().select();
}).focus();

if ($jq(document).html().indexOf('密碼錯誤') > -1) {
	$jq('#noLogin').val('1');
}

// overwrite func
function handleLogin(){
	passwordEncoded=true;
	CheckAndSetPassTextBox('txtPass');
}
function chk(){
	if (!$$('txtUserID').value.length || !$$('txtPass').value.length)
		return false;
	
	if (!$$('txtVerifyCode').value.length && $$('rdblQuickMenu_0').checked){
		sess_login($$('txtUserID').value, $$('txtPass').value, $$('ddlHospital').value);
		return false;
	}else
		return true;
}

function sess_login(id, pw, hospitalCode){
	$jq('#reqLogin').text(JSON.stringify({'id':id,'pw':pw,'hospitalCode':hospitalCode}));
	
}




void 0;

