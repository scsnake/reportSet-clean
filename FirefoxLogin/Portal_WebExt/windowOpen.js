var openedWindows = [];
window._open = window.open;
window.open = function() {
    var win = winOpen.apply(this, arguments);
    openedWindows.push(win);
	win.onbeforeunload = function(){
		openedWindows = openedWindows.filter(function(value, index, arr){
			return value !==this;
		});
	}
    return win;
};