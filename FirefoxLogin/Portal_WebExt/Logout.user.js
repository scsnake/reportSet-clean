


$jq(document).on('click', '#ibtnLogOut, #LogoutImg, #li_Logout', function(){
	browser.runtime.sendMessage({
		logout: 'logout'
	});
});

document.addEventListener("click", function(event){
	var target = event.target;
	var id = "";
	if(target.id) id = target.id;
	
	if(['ibtnLogOut', 'LogoutImg', 'li_Logout'].indexOf(id)>-1 ||
		id.match(/log\W*out/,'i')){
		browser.runtime.sendMessage({
			logout: 'logout', 
			sid: getSid()
		});
	}
  
});

function getSid(){
	var match = location.href.match(/SESSION=(\w+)/);
	if(match) return match[1];
	match = document.documentElement.innerHTML.match(/SESSION=(\w+)/);
	if(match) return match[1];
}