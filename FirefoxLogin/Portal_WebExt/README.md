# Portal_WebExt
Porting old Sleipnir SeaHorse scripts to Firefox WebExtension

## Structure
- background-script.js: monitor activeTab
- content scripts: act as userscripts, will load **\FILENAME.inj.user.js**, which load **jquery.js** and **FILENAME.user.js**
- jquery.js: contains jquery 3.1.1 (use as **$jq**) and some functions

## TODO
- Revise all \*.user.js using jquery($jq) and improve coding quality
- Revise bookmarklets, consider using jquery?
- Design add-on icon and login dialog

## Test Environment
- Download <a href="http://portableapps.com/apps/internet/firefox-developer-portable">Portable Firefox Developer Edition (32-bit)</a> (You can delete 64-bit version in App folder)
- In **about\:config**, set **xpinstall.signatures.required** as false
- Import bookmarklets from **bookmarks.html**
- Add/remove add-on in **about\:addons**
- Activate debugging in **about\:debugging** (for background script)
- Activate console with **Ctrl+Shift+I** to debug page and view errors. (Ctrl+Shift+K to focus on command line)

### Use AHK to package - Firefox_Dev.exe
- Require: **Portal_WebExt** folder opened in explorer, **Firefox** opened, **7z.exe** and **Firefox_Dev.exe** in the same folder
- Use **Alt+Z** to automate:
 - Zip all files except \*.xpi in the Portal_WebExt folder to a zip
 - Rename zip to xpi
 - Activate Firefox and open (jump to) Add-on page
 - Activate and deactivate the Portal_WebExt explorer (for later Alt-Tab)
