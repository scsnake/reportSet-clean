#include <RegExSplit>
#include <PathCombine>
#include <Img2base64>

convertCSSimage2base64(css_path){
	fileread,css,% css_path
	SplitPath,% css_path,,css_dir
	;~ css_dir:=RegExReplace(css_dir, "\/", "\")
	return RegExReplaceFn(css, "i)url\(([^\)]+)\)", "__convertCSSimage2base64_callback", "", "", css_dir)
}
__convertCSSimage2base64_callback(ByRef m, css_dir){
	pngPath:=m[1]
	if SubStr(pngPath,1,1)="""" && SubStr(pngPath,0,1)="""" 
		pngPath:=SubStr(pngPath,2,-1)
	p:=PathCombine(css_dir, pngPath)
	if FileExist(p) && (b64:=Img2base64(p, true))
		return "url(""" b64 """)"
	else 
		return m[0]
}


JoinHtml(html_path){
	fileread,html,% html_path
	SplitPath,% html_path,,html_dir
	html:=RegExReplaceFn(html, "i)<script[^>]+src=""([^"">]+\.js)""[^>]*>[^<]*<\/script>", "__JoinHtmlJS_callback", "", "", html_dir)
	html:=RegExReplaceFn(html, "i)<link[^>]+href=""([^"">]+\.css)""[^>]*\/?>", "__JoinHtmlCSS_callback", "", "", html_dir)
	return html
}

__JoinHtmlJS_callback(ByRef m, html_dir){
	if SubStr(m[1],1,2)="./"
		js_path:=SubStr(m[1],3)
	else
		js_path:=m[1]
	js_path:=RegExReplace(js_path, "\/", "\")
	p:=PathCombine(html_dir, js_path)
	if FileExist(p) && (script_all:=__JoinJS(p))
		return "<script type=""text/javascript"">`r`n" script_all "`r`n</script>"
	else 
		return m[0]
}

__JoinJS(js_path){
	fileread,js,% js_path
	return js
}

__JoinHtmlCSS_callback(ByRef m, html_dir){
	if SubStr(m[1],1,2)="./"
		css_path:=SubStr(m[1],3)
	else
		css_path:=m[1]
	css_path:=RegExReplace(css_path, "\/", "\")
	p:=PathCombine(html_dir, css_path)
	if FileExist(p) && (css_all:=convertCSSimage2base64(p))
		return "<style type=""text/css"">`r`n" css_all "`r`n</style>"
	else 
		return m[0]
}

;~ clipboard:=JoinHtml("G:\scripts\Radiology\urgentReport\dataTable.html")
;~ FileDelete,% "G:\scripts\Radiology\urgentReport\datatable2.html"
;~ FileAppend,% JoinHtml("G:\scripts\Radiology\urgentReport\datatable.html"),% "G:\scripts\Radiology\urgentReport\datatable2.html",utf-8