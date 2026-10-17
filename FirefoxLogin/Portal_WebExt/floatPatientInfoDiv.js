
var hexDigits = new Array("0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"); 

//Function to convert rgb color to hex format
function rgb2hex(rgb) {
 rgb = rgb.match(/^rgb\((\d+),\s*(\d+),\s*(\d+)\)$/);
 return "#" + hex(rgb[1]) + hex(rgb[2]) + hex(rgb[3]);
}

function hex(x) {
	return (isNaN(x)&&!!x) ? "00" : hexDigits[(x - x % 16) / 16] + hexDigits[x % 16];
 }

 

function floatPatientInfoDiv(insideTable, rgba){
		var tb = insideTable;

		var tb_clone = tb.clone();

		var tb_color = (rgba===undefined)?rgb2hex(tb.find('td').css('background-color')):rgb2hex(rgba);
		
		
		var rgbaCol = 'rgba(' + parseInt(tb_color.slice(-6,-4),16)
				+ ',' + parseInt(tb_color.slice(-4,-2),16)
				+ ',' + parseInt(tb_color.slice(-2),16)
				+',0.7)';
		tb_clone.css('background-color', rgbaCol).find('td').css('background-color', rgbaCol);


		var floatPatientInfo = $jq('<div></div>').css({
			'width': tb.parent().width(), 
			'top': tb.parent().position().top, 
			'left': tb.parent().position().left, 
			'z-index': 2147483647
		}).append(tb_clone).css({
			'position':'fixed', 
			'top': tb.position().top, 
			'left': tb.position().left});
		floatPatientInfo.appendTo(tb.parent());
		setInterval(function(tb,tb_clone){
			tb_clone.parent().width(tb.parent().width()).css({
				top: tb.parent().position().top +'px',
				left: tb.parent().position().left +'px'
			});
			tb_clone.css({
				top: tb.position().top +'px',
				left: tb.position().left +'px'
			});
			
		},1000,tb,tb_clone);
}
