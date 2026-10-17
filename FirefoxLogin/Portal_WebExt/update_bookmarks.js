browser.bookmarks.getTree().then(get_bookmarks, function(error){console.log(`Error: ${error}`)});

function get_bookmarks(bookmark_tree){
	for (var ch of bookmark_tree[0].children){
		if (ch.id==='toolbar_____') {
			for (var ch1 of ch.children){
				update_bookmarks(ch1); 
			}
			break;
		}
	}
	
}


function update_bookmarks(bm){
	if (! bm.url){ // folder
		for (var ch of bm.children){
			update_bookmarks(ch);
		}
	}else{
		var title = bm.title;
		if (bm.url.indexOf('updated01')==-1 && (title in new_bookmarks)) {
			browser.bookmarks.update(bm.id, {'url': new_bookmarks[title]}).then(
				function(bm){
					console.log('Updated: ' +bm.title);
				}, 
				function(err){
					console.log(`Update bookmark error: ${error}`);
				});
		}
	}
}


var new_bookmarks=[];
