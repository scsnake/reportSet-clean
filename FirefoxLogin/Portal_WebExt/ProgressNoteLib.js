function painScoreAsSpO2(){	
	var $ele = $jq(this) || $(this);
	var val = $ele.val().trim();
	if (parseInt(val) && parseInt(val)>10){
		$ele.val('SpO2 '+val+'%');
		highlight($ele[0]);
	}else if (/^SpO2 (\d\d|100)$/.test(val)){
		$ele.val(val+'%');
		highlight($ele[0]);
	}
}

function bodyTemperatureConvert(){
	var $ele = $jq(this) || $(this);
	var val = $ele.val().trim();
	if (parseInt(val) && parseInt(val)>45 && val.length==3){
		$ele.val((parseInt(val)/10).toString());
		highlight($ele[0]);
	}
}

function BPConvert(){
	var $ele = $jq(this) || $(this);
	var val = $ele.val().trim();
	if (val.indexOf('/')<0 && val.length==4){
		$ele.val(val.slice(0,2)+'/'+val.slice(2,4));
		highlight($ele[0]);
	}else if (val.indexOf('/')<0 && val.length==5){
		if(parseInt(val[0])>2) $ele.val(val.slice(0,2)+'/'+val.slice(2,5));
		else $ele.val(val.slice(0,3)+'/'+val.slice(3,5));
		highlight($ele[0]);
	}
}