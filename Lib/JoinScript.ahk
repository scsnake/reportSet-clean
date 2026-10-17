#include <RXMS>
#include <md5_file>
;~ script:="F:\scripts\Radiology\PacsIE\PacsIE.ahk"
;~ script:="M:\scripts\Radiology\YCH_main.ahk"
;~ msgbox % fileexist(script)
;~ exitapp

;~ clipboard:=JoinScript("F:\scripts\Autohotkey\Lib\RisImpax.ahk")
;~ FileDelete,F:\scripts\Radiology\showLungCAD\showLungCAD_J.ahk
;~ FileAppend,% JoinScript("F:\scripts\Radiology\showLungCAD\showLungCAD.ahk"),F:\scripts\Radiology\showLungCAD\showLungCAD_J.ahk,utf-8
;~ ExitApp
;~ FileDelete,F:\scripts\Autorun\for HotKeyIt\Autorun_All.ahk
;~ a:=JoinLib("C:\Users\Administrator\Documents\FirefoxLogin\FirefoxLoginApp\FirefoxLoginApp.ahk")
;~ ExitApp
;~ JoinLib("G:\scripts\Radiology\PacsIE\getalljpeg.ahk", "F:\miniPACS")

;~ JoinScript("G:\scripts\Radiology\LDCTreport\LDCTreport_Fleischner2017.ahk")
;~ ExitApp
JoinLib(scriptFullPath,workingDir=""){
	
	libs:=ListIncludes(scriptFullPath, "|")
	,ret1:=[], ret2:=[]
	Loop,Parse,libs,|
		if A_LoopField!=
			ret1.push(A_LoopField)
	count:=ret1.maxindex()
	Loop % (count:=ret1.maxindex())-1
		ret2[count-A_Index]:=ret1[A_Index+1]
	for k,v in ret2
		filecopy,% v, % workingDir "\Lib",1
	for k,v in ret2
		JoinLib(v, workingDir)
	
	return 
	JoinScript(scriptFullPath,workingDir,0,includedLib:=[])
	SplitPath,scriptFullPath,,ScriptDir
	if workingDir=
		workingDir:=scriptDir
	

	if !InStr(FileExist(workingDir "\Lib"),"D")
		FileCreateDir,% workingDir "\Lib"
	
	md5s:=[], fileList:=[]
	for k,v in includedLib {
		if md5s.hasKey(md5:=md5_file(k))
			continue
		md5s["" md5]:=1
		SplitPath,k,fileName,,fileExt,fileNameNoExt
		fileNameChange:=false
		while fileList.hasKey(fileName)
			fileName:=fileNameNoExt "_" A_Index "." fileExt, fileNameChanged:=true
		fileList["" fileName]:=1
		if(fileNameChanged)
			MsgBox % k " copied and changed name:`n" workingDir "\Lib\" fileName "`ndue to duplicated file name"
		FileCopy,% k,% workingDir "\Lib\" fileName,1
	}

}


;~ clipboard:=joinScript("F:\scripts\Radiology\YCH.ahk")
;~ ExitApp
JoinScriptStr(ScriptText, workingDir="",depth=0, returnLib=""){
	static tmpFile:=A_ScriptDir "\198bawef8192fabpwoefj.ahk"
	FileDelete,% tmpFile
	FileAppend,% ScriptText,% tmpFile,UTF-8
	t:=JoinScript(tmpFile, A_ScriptDir)
	FileDelete,% tmpFile
	return t
}

JoinScript(scriptFullPath,workingDir="",depth=0, returnLib=""){
	PreprocessScript(t, scriptFullPath, "")
	
	SplitPath,scriptFullPath,,dir,ext,fname
	
	if FileExist(dir "\" fname "_Full." ext)
		FileDelete,% dir "\" fname "_Full." ext
	FileAppend,% t, % dir "\" fname "_Full." ext,UTF-8-Raw
	
	return t
	;~ libs:=ListIncludes(scriptFullPath, "|", newScriptText:="", returnLib)
	;~ return newScriptText
	;~ ,ret1:=[], ret2:=[]
	;~ Loop,Parse,libs,|
		;~ if A_LoopField!=
			;~ ret1.push(A_LoopField)
	;~ count:=ret1.maxindex()
	;~ Loop % (count:=ret1.maxindex())-1
		;~ ret2[count-A_Index]:=ret1[A_Index+1]
	;~ returnLib:=ret2
	
	;~ str:=""
	;~ for k,lib in ret2 {
		;~ fileread,tmpFile,% lib
		;~ str.=";--------------include: " lib "------------`n" tmpFile "`n" 
	;~ }
	;~ fileread,tmpFile,% scriptFullPath
	;~ str.= ";--------------include: " scriptFullPath "------------`n" tmpFile 
	;~ return RegExReplace(str, "mi`a)^\s*#include(?:again)?(?:\s+|\s*,\s*)(?:\*i[ `t]?)?(.+)", "")
	global outputvar
	static includedLib, errorLib, md5s
	if !isobject(includedLib) || depth=0
		includedLib:=[], errorLib:=[], md5s:=[]
	
	;~ scriptDir:=RegExReplace(scriptFullPath,"(\/|\\)([^\/\\]+)$","")
	SplitPath,scriptFullPath,,ScriptDir
	if workingDir=
		workingDir:=scriptDir
	
	lib:=[]
	if fileexist(workingDir "\Lib.lnk") {
		FileGetShortcut, % workingDir "\Lib.lnk", target
		lib.push(target)
	}
	SplitPath,a_ahkpath,,ahkpath
	for k,v in [workingDir "\Lib", a_mydocuments "\AutoHotkey\Lib", ahkpath "\Lib"]
		if FileExist(v)
			lib.push(v)
	
	
	fileread,scriptText,% scriptFullPath
	
	static includePattern:="is)(;[^\r\n]+)?#include(again|)\s+(?:\*i\s+)?(<?)([^\n\r;>]+)(>?)(?:;[^\n\r]*)?\r?\n?"
	;~ nonincludeText:=[]
	;~ includeText:=[]
	
	;~ if InStr(scriptFullPath, "SCI.ahk")
		;~ aaa:=1
	matched:=[]
	i:=0,match:="1"
	while i:=RegExMatch(scriptText,includePattern,match,j:=i+strlen(match)){
		RegExReplace(beforeText:=SubStr(scriptText,1,i-1), "(^\/\*)|([\s\n]\/\*)", "", CountL)
		RegExReplace(beforeText,  "([\s\n]\*\/)", "", CountR)
		;~ if(match1!="")
			;~ bbb:=1
		if(CountL=CountR && !match1){
			matched.push(array(match,match2?1:0,match4,match3&&match5?1:0,i,strlen(match)))
		}
	}
	; v.2 -> is includeagain
	; v.3 -> include path
	; v.4 -> is <> presented, i.e. use library path
	; v.5 -> start position of this include line
	; v.6 -> lenght of this include line
	
	;~ RXMS(scriptText,includePattern, "snonincludeText[] mincludeText[]")
	;~ split:=[]
	;~ loop %OutputVar0%
		;~ split.push(OutputVar%a_index%)
	
	fullScript:=""
	for k,v in matched {
		valued:=0
		includePath:=v.3
		;~ if InStr(includePath, "Edit")
			;~ bbb:=1
		if (v.4) { ;search in lib
			for x,y in lib
				if fileexist(y "\" includePath ".ahk") {
					includePath:=y "\" includePath ".ahk"
					if (includedLib.haskey(includePath) && !v.2){
						noRec:=true
						break
					}else if !md5s.hasKey(md5:=md5_file(includePath)) {
						includedLib["" includePath]:=1,valued:=1, md5s["" md5]:=1
						break
					}
				}
		}else{
			StringReplace,includePath,includePath,% "%A_AppData%",%a_appdata%,all
			StringReplace,includePath,includePath,% "%A_AppDataCommon%",%A_AppDataCommon%,all
			StringReplace,includePath,includePath,% "%A_ScriptDir%",%ScriptDir%,all
			StringReplace,includePath,includePath,`",,all
			;~ clipboard:=includePath
			if !InStr(includePath, ":")
				includePath:=RelToAbs(workingDir, includePath)
			
			if instr(fx:=fileexist(includePath),"D") { ;folder
				workingDir:=RegExReplace(includePath,"(\\|\/)?$","")
				
			}
			if (includedLib.hasKey(includePath) && !v.2){
				;~ noRec:=true
			}else if (fx) && !md5s.hasKey(md5:=md5_file(includePath))  {
				includedLib["" includePath]:=1,valued:=1, md5s["" md5]:=1
			}else{
				if !errorLib.hasKey(includePath)
					MsgBox % "Library: " includePath " not found!"
				errorLib.push(includePath)
			}
		}
		
		;~ if IncludedScript.hasKey(includePath) && v.1=0
			;~ valued:=0
		
		includedLib["" includePath]:=1
		tmp:=""
		Loop % depth+1
			tmp.="--"
		fullScript.=(k=1?substr(scriptText,1,v.5-1):substr(scriptText,matched[k-1,5]+matched[k-1,6],v.5-matched[k-1,5]-matched[k-1,6])) 
			. (valued?(strPart1:=";" tmp " include" (v.2?" again":"")) (strPart2:=" """ includePath """ in " scriptFullPath tmp "`n")  
			. JoinScript(includePath,"",depth+1)
			. "`n" strPart1 " end" strPart2 "`n`n":"") 
		
		
		
	
	}
	if(depth=0){
		returnLib:=includedLib.clone()
		,includedLib:=[], errorLib:=[], md5s:=[]
	}
	;~ if instr(scriptFullPath,"PacsIE")
			;~ clipboard:=fullScript
	return matched.maxindex()?(fullScript substr(scriptText,v.5+v.6)):scriptText
	
}

;~ A:=ListIncludes("f:\scriPtS\test.ahk")
;~ b:=1


ListIncludes(script_file, delim="|", ByRef newScript="", listOfLib="")
{
    if !(attr := FileExist(script_file)) or InStr(attr,"D")
        return
    
    wd := A_WorkingDir
    SplitPath, script_file,, script_dir
    SetWorkingDir, %script_dir%
    
    ; ListIncludes_Recursive() uses auto-trim.
    atrim := A_AutoTrim
    AutoTrim, On
    
    ; Start the list with this file.
	if listOfLib=
		list := ListIncludes_GetFullPathName(script_file)
	else
		list:=listOfLib
    
    ; Recursively read and build a list of script files.
	
    ListIncludes_Recursive(list, script_file, script_dir, delim, newScript)
    
    SetWorkingDir, %script_dir%
    
    ; Resolve automatic includes (from the function library.)
    VarSetCapacity(temp_file, 260, 0)
    DllCall("GetTempFileName", "str", script_dir, "str", "lib", "uint", 0, "str", temp_file)
    RunWait, "%A_AhkPath%" /iLib "%temp_file%" "%script_file%"
    if (FileExist(temp_file)) {
        ListIncludes_Recursive(list, temp_file, script_dir, delim)
        FileDelete, %temp_file%
    }

    ; Restore previous auto-trim setting and working directory.
    AutoTrim, %atrim%
    SetWorkingDir, %wd%
    
    return list
}

ListIncludes_Recursive(ByRef list, script_file, script_dir="", delim="|", ByRef newScript="")
{
	lib:=[]
	if fileexist(script_dir "\Lib.lnk") {
		FileGetShortcut, % workingDir "\Lib.lnk", target
		lib.push(target)
	}
	SplitPath,a_ahkpath,,ahkpath
	for k,v in [workingDir "\Lib", a_mydocuments "\AutoHotkey\Lib", ahkpath "\Lib"]
		if FileExist(v)
			lib.push(v)
	
	if script_dir=
		SplitPath,script_file,,script_dir
    FileRead, script, %script_file%
	newScript:=script
    ; Remove any text which may contain false #includes.
    script := RegExReplace(script
        , "ms`a)^\s*/\*.*?^\s*\*/\s*"  ; multi-line comments
        . "|\s*(?<!\S);.*?$"           ; single-line comments
        . "|^\s*\(.*?^\s*\)\s*")       ; continuation sections
    
    ; Techinically, continuation sections/lines may be used to split an #include
    ; across multiple lines, but this seems rare enough to ignore.
    
    pos = 1
	newLibTxtCount:=0
    Loop
    {
        ; Find the next #Include or #IncludeAgain.
        ; Filename may have optional "*i " (ignore failure) prefix.
        if !(pos := RegExMatch(script
            , regex:="mi`a)^\s*#include(?:again)?(?:\s+|\s*,\s*)(?:\*i[ `t]?)?(.+)"
            , m, pos))
            break
		FoundPos:=pos
        pos += StrLen(m)
        
        StringReplace, m1, m1, `%A_ScriptDir`%, %script_dir%
        StringReplace, m1, m1, `%A_AppData`%, %A_AppData%
        StringReplace, m1, m1, `%A_AppDataCommon`%, %A_AppDataCommon%
        ; ';' can be escaped in an #include line, but not any other character.
        ; The third '`' is needed in this case because `; sequences are replaced
        ; before any other escape sequence.
        StringReplace, m1, m1,```;,;, All

		found:=false
		if RegExMatch(m1, "<([^>]+)>", libPath){
			for k,v in lib
				if attr:=FileExist(m1:=path:=RegExReplace(v, "[\\\/]$", "") "\" libPath1 ".ahk"){
					Found:=true
					break
				}
			
			If !Found
				continue
			
		}else{
        ; Skip files that don't exist.
        if !(attr := FileExist(m1))
        {
            ;MsgBox File not found:`n%m1%
            continue
        }
		}
        
		m1 := ListIncludes_GetFullPathName(m1)
        if InStr(attr, "D")
        {   ; #include relative to this directory.
            SetWorkingDir, %m1%
            continue
        }else if  !InStr(delim . list . delim, delim . m1 . delim){
			list .= delim . m1
			;~ if InStr(m1, "SCI.ahk")
				;~ MsgBox % m1
			InsertLib:="/*`n=========include: " m1 "========`n*/`n" JoinScript(m1, A_WorkingDir, "", list)
			newScript:=RegExReplace(newScript, regex, InsertLib, "", FoundPos+newLibTxtCount, 1)
			newLibTxtCount+=StrLen(InsertLib)
			
			;~ ListIncludes_Recursive(list, m1, script_dir, delim)
		}
        
        ; Expand relative paths in full. This is important because
        ;   a) the caller doesn't necessarily know the working directory, and
        ;   b) it makes filenames consistent so that two includes of the same
        ;      file will always be recognized as duplicates.
        ;~ m1 := ListIncludes_GetFullPathName(m1)
        
        ;~ if !InStr(delim . list . delim, delim . m1 . delim) {
            ;~ list .= delim . m1
			
            ;~ ListIncludes_Recursive(list, m1, script_dir, delim)
        ;~ }
    }
}


ListIncludes_GetFullPathName(path) {
    ;~ Loop, %relative_path%, 1
        ;~ return A_LoopFileLongPath
    ;~ return relative_path
	VarSetCapacity(fullpath, 260 * (!!A_IsUnicode + 1))
	if DllCall("GetFullPathName", "Str", path, "UInt", 260, "Ptr", &fullpath, "Ptr", 0, "UInt")
		return fullpath,VarSetCapacity(fullpath,-1)
}



;~ PreprocessScript(t, "G:\scripts\radiology\ych_xr.ahk", "")
;~ MsgBox % clipboard:=t
;~ ExitApp
PreprocessScript(ByRef ScriptText, AhkScript, ExtraFiles, FileList := "", FirstScriptDir := "", Options := "", iOption := 0, noAutoIncludeFunc:=0)
{
	SplitPath, AhkScript, ScriptName, ScriptDir
	if !IsObject(FileList)
	{
		FileList := [AhkScript]
		,ScriptText := "; <COMPILER: v" A_AhkVersion ">`n"
		,FirstScriptDir := ScriptDir
		,IsFirstScript := true
		,Options := { comm: ";", esc: "``", directives: [] }
		
		,OldWorkingDir := A_WorkingDir
		SetWorkingDir, %ScriptDir%
	}
	
	If !FileExist(AhkScript)
		;~ if !iOption
			; Util_Error((IsFirstScript ? "Script" : "#include") " file """ AhkScript """ cannot be opened.")
		;~ else return
		return
	cmtBlock := false, contSection := false, ignoreSection := false
	Loop,Read, %AhkScript%
	{
		tline := Trim(A_LoopReadLine)
		if !cmtBlock
		{
			if ignoreSection
			{
				if (tline == Options.comm "@Ahk2Exe-IgnoreEnd")
					ignoreSection := false
				continue
			}
			if !contSection
			{
				if StrStartsWith(tline, Options.comm)
				{
					tline := SubStr(tline,1 + StrLen(Options.comm))
					if !StrStartsWith(tline, "@Ahk2Exe-")
						continue
					tline := SubStr(tline, 10)
					if (tline = "IgnoreBegin")
						ignoreSection := true
					else if (tline != "")
						Options.directives.push(tline)
					continue
				}
				else if (tline = "")
					continue
				else if StrStartsWith(tline, "/*")
				{
					if (tline == "/*@Ahk2Exe-Keep")
						continue
					cmtBlock := true
					continue
				}
				else if StrStartsWith(tline, "*/")
					continue ; Will only happen in a 'Keep' section
			}
			if StrStartsWith(tline, "(") && !InStr(tline, ")")
				contSection := true
			else if StrStartsWith(tline, ")")
				contSection := false
			
			tline := RegExReplace(tline, "\s+" RegExEscape(Options.comm) ".*$", "")
			if !contSection && RegExMatch(tline, "i)^#Include(Again)?[ \t]*[, \t]?\s+(.*)$", o)
			{
				IsIncludeAgain := (o1 = "Again")
				IgnoreErrors := false
				IncludeFile := o2
				if RegExMatch(IncludeFile, "\*[iI]\s+?(.*)", o)
					IgnoreErrors := true, IncludeFile := Trim(o1)
				
				if RegExMatch(IncludeFile, "^<(.+)>$", o)
				{
					if IncFile2 := FindLibraryFile(o1, FirstScriptDir)
					{
						IncludeFile := IncFile2
						goto _skip_findfile
					}
				}
				
				StringReplace, IncludeFile, IncludeFile, `%A_ScriptDir`%, %FirstScriptDir%, All
				StringReplace, IncludeFile, IncludeFile, `%A_AppData`%, %A_AppData%, All
				StringReplace, IncludeFile, IncludeFile, `%A_AppDataCommon`%, %A_AppDataCommon%, All
				StringReplace, IncludeFile, IncludeFile, `%A_LineFile`%, %AhkScript%, All
				
				if InStr(FileExist(IncludeFile), "D")
				{
					SetWorkingDir, %IncludeFile%
					continue
				}
				
				_skip_findfile:
				
				IncludeFile := Util_GetFullPath(IncludeFile)
				
				AlreadyIncluded := false
				for k,v in FileList
				if (v = IncludeFile)
				{
					AlreadyIncluded := true
					break
				}
				if(IsIncludeAgain || !AlreadyIncluded)
				{
					if !AlreadyIncluded
						FileList.push(IncludeFile)
					PreprocessScript(ScriptText, IncludeFile, ExtraFiles, FileList, FirstScriptDir, Options, IgnoreErrors)
				}
			}else if (!contSection && tline ~= "i)^FileInstall[, \t]")
			{
				if (tline ~= "^\w+\s+(:=|\+=|-=|\*=|/=|//=|\.=|\|=|&=|\^=|>>=|<<=)")
					continue ; This is an assignment!
				if !RegExMatch(tline, "i)^FileInstall[ \t]*[, \t][ \t]*([^,]+?)[ \t]*(,|$)", o) || o1 ~= "[^``]%" ; TODO: implement `, detection
					; Util_Error("Error: Invalid ""FileInstall"" syntax found. Note that the first parameter must not be specified using a continuation section.")
				_ := Options.esc
				StringReplace, o1, o1, %_%`%, `%, All
				StringReplace, o1, o1, %_%`,, `,, All
				StringReplace, o1, o1, %_%%_%,, %_%,, All
				ExtraFiles.push(o1)
				ScriptText .= tline "`n"
			}else if !contSection && RegExMatch(tline, "i)^#CommentFlag\s+(.+)$", o)
				Options.comm := o1, ScriptText .= tline "`n"
			else if !contSection && RegExMatch(tline, "i)^#EscapeChar\s+(.+)$", o)
				Options.esc := o1, ScriptText .= tline "`n"
			;~ else if !contSection && RegExMatch(tline, "i)^#DerefChar\s+(.+)$", o)
				; Util_Error("Error: #DerefChar is not supported.")
			;~ else if !contSection && RegExMatch(tline, "i)^#Delimiter\s+(.+)$", o)
				; Util_Error("Error: #Delimiter is not supported.")
			else
				ScriptText .= (contSection ? A_LoopReadLine : tline) "`n"
		}else if StrStartsWith(tline, "*/")
			cmtBlock := false
	}
	
	Loop, % !!IsFirstScript ; equivalent to "if IsFirstScript" except you can break from the block
	{
		if noAutoIncludeFunc
			break
		SB_SetText("Auto-including any functions called from a library...")
		ilibfile := FirstScriptDir "\97DC7311BAB2456FA272D3D5DCE54722.ahk"
		FileDelete, %ilibfile%
		FileDelete, %ilibfile%.script
		FileDelete, %ilibfile%.error
		static AhkPath := A_AhkPath ;A_IsCompiled ? A_ScriptDir "\..\AutoHotkey.exe" : A_AhkPath
		;~ AhkType := AHKType(AhkPath)
		;~ if AhkType = FAIL
			; Util_Error("Error: The AutoHotkey build used for auto-inclusion of library functions is not recognized.", 1, AhkPath)
		;~ if AhkType = Legacy
			; Util_Error("Error: Legacy AutoHotkey versions (prior to v1.1) are not allowed as the build used for auto-inclusion of library functions.", 1, AhkPath)
		FileAppend,%ScriptText%,%ilibfile%.script, UTF-8
		if(A_DllPath)
			RunWait, % """" comspec """ /C """"" AhkPath """ /iLib """ ilibfile """ /ErrorStdOut /E """ ilibfile ".script"" 2>""" ilibfile ".error""""", %FirstScriptDir%, HIDE UseErrorLevel
		else
			RunWait, % """" comspec """ /C """"" AhkPath """ /iLib """ ilibfile """ /ErrorStdOut """ ilibfile ".script"" 2>""" ilibfile ".error""""", %FirstScriptDir%, HIDE UseErrorLevel
		if (ErrorLevel = 2)
		{		
			FileRead,script_error,%ilibfile%.error
			FileDelete, %ilibfile%.error
			line_error:=SubStr(line_error:=SubStr(script_error,StrLen(ilibfile) + 10),1,InStr(line_error,")")-1)
			Loop, Parse,ScriptText,`n,`r
				If (A_Index=line_error){
					line_error:=A_LoopField
					break
				}
			FileDelete, %ilibfile%
			FileDelete, %ilibfile%.script
			; Util_Error("Error: The script contains syntax errors.",true,line_error "`n" SubStr(script_error,StrLen(ilibfile) + 9))
		}
		If FileExist(ilibfile)
			PreprocessScript(ScriptText, ilibfile, ExtraFiles, FileList, FirstScriptDir, Options)
		FileDelete, %ilibfile%
		FileDelete, %ilibfile%.script
		FileDelete, %ilibfile%.error
		StringTrimRight, ScriptText, ScriptText, 1 ; remove trailing newline
	}
	
	if OldWorkingDir
		SetWorkingDir, %OldWorkingDir%
	
	if IsFirstScript
		return Options.directives
}

FindLibraryFile(name, ScriptDir)
{
	SplitPath,A_AhkPath,,ahkpath
	FileGetShortCut,%ahkpath%\lib.lnk,target
	libs := [ScriptDir "\Lib", A_MyDocuments "\AutoHotkey\Lib", A_ScriptDir "\..\Lib", ahkpath "\Lib",A_ScriptDir "\..\..\Lib",target]
	if p := InStr(name, "_")
		name_lib := SubStr(name, 1, p-1)
	
	for each,lib in libs
	{
		file := lib "\" name ".ahk"
		If FileExist(file)
			return file
		
		if !p
			continue
		
		file := lib "\" name_lib ".ahk"
		If FileExist(file)
			return file
	}
}

StrStartsWith(ByRef v, ByRef w)
{
	return SubStr(v, 1, StrLen(w)) = w
}

RegExEscape(t)
{
	static _ := "\.*?+[{|()^$"
	Loop, Parse, _
		StringReplace, t, t, %A_LoopField%, \%A_LoopField%, All
	return t
}


    

Util_GetFullPath(path)
{
	VarSetCapacity(fullpath, 260 * (!!A_IsUnicode + 1))
	if DllCall("GetFullPathName", "Str", path, "UInt", 260, "Ptr", &fullpath, "Ptr", 0, "UInt")
		return fullpath,VarSetCapacity(fullpath,-1)
}