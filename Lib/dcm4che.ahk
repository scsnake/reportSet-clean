#include <DicomTagName>
#include <RegExSplit>
#include <XML>
ComObjError(false)

;~ d:=new dcm4che({aet: "OB1FPHCT01S1", ip: "10.0.0.1", port: 104})
;~ d.aet:="EPHICT01AW02:104"
;~ s:=d.getStudyByDate("20180904")

;~ ExitApp


;~ d:=new dcm4che("RAID")
;~ SeriesInfo:=dcm4che.getSeriesInfo("T__________")
;~ MsgBox % seriesInfo.maxindex()
;~ clipboard:=dcm4che.LastOutput
;~ dcm4che.Move([SeriesInfo.3.SeriesUID], "SYNGOVIA")
;~ esc::
;~ ExitApp


;~ d:=new dcm4che({aet: "PACSWFM2", ip: "10.0.0.1", port: "104"})
;~ clipboard:=s:=d.getSeriesInfo("T__________")
;~ ExitApp

;~ SeriesUIDArr:=[]
;~ #include <JXON>
;~ fileread,j,D:\20170808005417_1.txt
;~ a:=JXON_load(j)
;~ for k,v in a
	;~ SeriesUIDArr.push(v[3])
	
	
;~ d:=new dcm4che("PACSWFM2")
;~ d.PACStoRAID("T__________")
;~ ExitApp
;~ s:=d.getStudyByDate("20180516", {AccessionNumber: "T__________"})
;~ clipboard:=s[1].StudyInstanceUID	

;~ d:=new dcm4che("PACSWFM2")
;~ clip:="0000001"
;~ Loop,parse,clip,`n,`r
;~ {
	;~ studies:=d.getInfo({PatientID: A_LoopField, "00080060": "CT"}, "", "Study")
	
	;~ for k, study in studies {
		;~ studyUid:=StudyInstanceUID
		;~ for x,series in d.getSeriesInfo(studyUid) {
			;~ ToolTip % series.SeriesInstanceUID
		;~ }
	;~ }
	;~ for k,v in s:=d.getSeriesInfo(A_LoopField) {
	;~ if (v.NumberofSeriesRelatedInstances>300){
		;~ uid:=v.SeriesInstanceUID
		;~ d.PACStoRAID(A_LoopField, {SeriesInstanceUID: uid})
		;~ break
	;~ }
;~ }	

;~ d.Move(SeriesUIDArr, "SYNGOVIA")
;~ d.PACStoRAID({chartNo: "3______", date: "20170602"})
;~ clip:=Clipboard
;~ Loop,parse,clip,`n,`r
;~ {
	;~ d.MoveStudy(A_LoopField, "EPHICT01AW03")
	;~ d.PACStoRAID(A_LoopField)
	;~ Sleep 60000
;~ }

;~ ,d.getStudyByDate("20170519")
;~ info:=d.ParseTextResult(clipboard, {"Query/Retrieve Level":"STUDY"
			;~ , "Patient ID":""
			;~ , "Study Instance UID":""})
;~ ExitApp	

;~ esc::ExitApp

class dcm4che {
	static blocksPattern := "is)DEBUG - Command:(?P<command>[^<>]+?)" "DEBUG - Dataset:(?P<dataset>[^<>]+?)" "####### DimesRSP received after"
	static storescpPID:=0
	static instanceCount:=0
	
	__New(remote="", dcmpath=""){
		this.root:=SubStr(A_ScriptDir,1,2)
		,this.dcmVersion:="3.3.8"
		if(dcmpath=""){
			if FileExist(dcmpath:=A_MyDocuments "\dcm4che-" this.dcmVersion "\bin\") 
				|| FileExist(dcmpath:=A_ScriptDir "\Lib\dcm4che-" this.dcmVersion "\bin\")
				|| FileExist(dcmpath:=this.root "\scripts\AutoHotkey\Lib\dcm4che-" this.dcmVersion "\bin\") {
			
			}
			
		}
		if dcmPath=
			return -1
		this.dcmPath:=dcmpath
		,this.aet:="DCMAHK"
		if(remote=""){
			this.remote:={aet: "RAID", ip: "10.0.0.1", port: "4006"}
			,this.aet:="DCMQR"
		}else{
			if IsObject(remote)
				this.remote:=remote
			else if(remote="RAID")
				this.remote:={aet: "RAID", ip: "10.0.0.1", port: "4006"}
				;~ ,this.aet:="DCMQR"
			else if(remote="SYNGOVIA")
				this.remote:={aet: "SYNGOVIA", ip: "10.0.0.1", port: "104"}
				,this.aet:="RAID"
			else if(remote="PACSWFM2")
				this.remote:={aet: "PACSWFM2", ip: "10.0.0.1", port: "104"}	
				, this.aet:="EPHICT01AW02"
		}
		dcm4che.instanceCount++
	}
	
	filter(filterDict){
		str:=""
		for k,v in filterDict
			str.="-m " k "=" v " "
		return str
	}
	more(moreFields){
		more:=""
		for k,v in moreFields
			more.="-r " v " "
		return more
	}
	
	CountImages(seriesInfo){
		t:=0
		for k,v in seriesInfo {
			if v.NumberofSeriesRelatedInstances
				t+=v.NumberofSeriesRelatedInstances
		}
		return t
	}
	
	getInfo(filterDict, moreFields="", level="Series", Limit=0){
		str:=this.filter(filterDict)
		if(str=""){
			if(filterDict~="i)^[TY]\w{9}\d$")
				str:="-m AccessionNumber=" filterDict
			else if (filterDict~="^[\d\.]+$")
				str:=level="image"?("-m SeriesInstanceUID=" filterDict):("-m StudyInstanceUID=" filterDict)
			else if (filterDict~="^\w{6}\d$")
				str:="-m PatientID=" filterDict
			else
				return []
		}
		
		more:=this.more(moreFields)
		
		StringUpper,AccNo,AccNo
		outputDirName:=A_ScriptDir "\__dcm4cheOutput" a_now a_tickcount
		if (level="STUDY"){
			parameter:="-L STUDY -b " this.aet " -c " this.remote.aet "@" this.remote.ip ":" this.remote.port " " str " -r StudyDescription -r PatientID -r AccessionNumber -r StudyInstanceUID " more  " -X --out-file __dcm4cheOutput.xml --out-dir """ outputDirName """"
		}else if (level="Series"){
			parameter:="-L SERIES -b " this.aet " -c " this.remote.aet "@" this.remote.ip ":" this.remote.port " " str " -r SeriesDescription -r NumberOfSeriesRelatedInstances -r PatientID -r AccessionNumber -r SeriesInstanceUID " more  " -X --out-file __dcm4cheOutput.xml --out-dir """ outputDirName """"
		}else if (level="image"){
			parameter:="-L IMAGE -b " this.aet " -c " this.remote.aet "@" this.remote.ip ":" this.remote.port " " str " -r PatientID -r AccessionNumber " more " -X --out-file __dcm4cheOutput.xml --out-dir """ outputDirName """"
		}
		
		RunWait,% """" this.dcmPath "findscu.bat"" " parameter,% a_scriptdir,Hide
		return this.parseOutputXml(outputDirName, Limit)
		
		;~ RunWait,% """" this.dcmPath """ " parameter 
		fileread,__dcm4cheOutput,% A_ScriptDir "\" outputFileName
		FileDelete,% A_ScriptDir "\" outputFileName
		this.LastOutput:=__dcm4cheOutput
		;~ clipboard:=__dcm4cheOutput
		;~ if !RegExMatch(__dcm4cheOutput, "i)\[([^\]]+)\] Study Instance UID", StudyUID)
			;~ return []
		
		;~ this.LastStudyUID:=StudyUID1
		
		;~ MsgBox % clipboard:=__dcm4cheOutput
		;~ ,arr1:=[],arr2:=[]
		;~ ,rxms(__dcm4cheOutput,"(\r?\n){2,}","sarr1[] marr2[]")
		
		;~ StringReplace,t,__dcm4cheOutput,`r,% ""
		;~ StringReplace,t,t,`n`n,㏄
		
		return info:=this.ParseTextResult(__dcm4cheOutput)
	}
	
	
	
	getImageInfo(filterDict, moreFields="", Limit=0){
		return this.getInfo(filterDict, moreFields, "Image", Limit)
	}
	getSeriesInfo(filterDict, moreFields="", Limit=0){
		return this.getInfo(filterDict, moreFields, "Series", Limit)
	}
	
	getStudyByDate(date, filterDict="", moreFields="", getLevel="STUDY"){ ;2017/1/1
		if !(date~="^\d{8}$"){ ;date format to 20170101
			dateArr:=[]
			Loop,Parse,date,%a_space%`,`./\%a_tab%
			{
				if A_Index>3
					break
				if (A_LoopField>0){
					v:=A_LoopField
					while StrLen(v)<(A_Index=1?4:2)
						v:="0" v
				}
			}
			date:=""
			Loop 3
				date.=dateArr[A_Index]
		}
		
		filter:=this.filter(filterDict)
		,more:=this.more(moreFields)
		,outputDirName:=a_scriptdir "\__dcm4cheOutput" a_now a_tickcount
		,parameter:="-L " getLevel " -b " this.aet " -c " this.remote.aet "@" this.remote.ip ":" this.remote.port " -m StudyDate=" date  " " filter " -r PatientID -r AccessionNumber -r StudyDescription -r StudyInstanceUID " more " -X --out-file __dcm4cheOutput.xml --out-dir """ outputDirName """"
		
		RunWait,% """" this.dcmPath "findscu.bat"" " parameter,% a_scriptdir,Hide
		return this.parseOutputXml(outputDirName)
		
		fileread,__dcm4cheOutput,% A_ScriptDir "\" outputFileName
		FileDelete,% A_ScriptDir "\" outputFileName
		this.LastOutput:=__dcm4cheOutput
		
		;~ info:=this.ParseTextResult(__dcm4cheOutput, {"Query/Retrieve Level":"STUDY"
			;~ , "Patient ID":""
			;~ , "Study Instance UID":""})
		
		info2:=this.ParseTextResult(__dcm4cheOutput)
			
			
		return info2
		
		
	}
	
	getSeriesByDate(date, filterDict="", moreFields=""){
		return this.getStudyByDate(date, filterDict, moreFields, "SERIES")
	}
	
	ParseTextResult(outputtext){ 
		
		datasets := RegExMatchAll(outputtext, dcm4che.blocksPattern).dict
		
		,results := []
		for k, dataset in datasets
			results.push(new dcm4che_datarecord(dataset.dataset))

		return results
	}
	
	parseOutputXml(dirName, Limit=0){
		results:=[], i:=0
		Loop, % dirName "\__dcm4cheOutput*.xml" {
			try {
				X:=new XML(A_LoopFileLongPath)
				,y:=x.selectNodes("/NativeDicomModel/DicomAttribute")
				
				,data:=[]
				Loop % y.length {
					a:=y.item(A_Index)
					,dict:=[]
					for _, v in ["keyword", "tag", "vr"] 
						dict[v]:=a.getAttribute(v)
					dict["value"]:=a.SelectSingleNode(". /Value").Text
					,data.push(dict)
				}
				
				results.push(new dcm4che_datarecord(data))
				
				if ++i==Limit
					break
			}

		}
		
		FileRemoveDir,% dirName,1
		return results
	}
		
	__MoveStudy(AccNoArr, targetAet){
		if IsObject(AccNoArr){
			for k,AccNo in AccNoArr
				this.MoveStudy(AccNo, targetAet)
		}else{
			parameter:="-L STUDY -b " this.aet " --dest " targetAet " -c " this.remote.aet "@" this.remote.ip ":" this.remote.port " -m AccessionNumber=" AccNoArr " "
			Run,% """" this.dcmPath "movescu.bat"" " parameter ,% a_scriptdir,Hide
		}
		
	}
	
	moveStudyByUID(StudyUIDArr, targetAet="", directory="", wait=true){
		return this.moveStudy(StudyUIDArr, targetAet, directory, wait, true)
	}
	
	moveStudy(AccNoArr, targetAet="", directory="", wait=true, useUID=false){
		;~ clipboard:=""
		;~ MsgBox % SeriesUIDArr.maxindex() "," SeriesUIDArr[1]
		
		if (directory = "")
			directory:=A_ScriptDir
		
		if (!directory~="^\w+:")
			directory:=A_ScriptDir ((directory~="^[\/\\]")?"":"\") RegExReplace(directory, "[\\\/]", "\")
		
		if(targetAet="") { ; move to local
			targetAet:=this.aet 
			if !WinExist("ahk_pid " dcm4che.storescpPID)
				if this.storescp(11112, directory, "")=-1
					return
			;~ targetAet:=this.aet " -b " this.aet "@" A_IPAddress1 ":11112 " 
		}
		
		if !IsObject(AccNoArr)
			AccNoArr:=[AccNoArr]
		
		for k,v in AccNoArr {
			parameter:="-L STUDY -b " this.aet " --dest " targetAet " -c " this.remote.aet "@" this.remote.ip ":" this.remote.port " -m " (useUID?"StudyInstanceUID":"AccessionNumber") "=" v " " 
			,outputFileName:="__dcm4cheOutput" a_now a_tickcount
			;~ MsgBox % parameter
			;~ RunWait,% """" this.dcmPath """ " parameter " > """ a_scriptdir "\" outputFileName """",% a_scriptdir
			if (wait)
				RunWait,% """" this.dcmPath "movescu.bat"" " parameter ,% a_scriptdir,Hide
			else
				Run,% """" this.dcmPath "movescu.bat"" " parameter ,% a_scriptdir,Hide
			fileread,__dcm4cheOutput,% A_ScriptDir "\" outputFileName
			FileDelete,% A_ScriptDir "\" outputFileName
			this.LastOutput:=__dcm4cheOutput
			;~ fileread,__dcm4cheOutput,% A_ScriptDir "\" outputFileName
			;~ clipboard.=__dcm4cheOutput
			;~ FileDelete,% A_ScriptDir "\" outputFileName
		}
	}
	
	move(SeriesUIDArr, targetAet="", directory="", wait=true){
		;~ clipboard:=""
		;~ MsgBox % SeriesUIDArr.maxindex() "," SeriesUIDArr[1]
		if (directory = "")
			directory:=A_ScriptDir
		
		if (!directory~="^\w+:")
			directory:=A_ScriptDir ((directory~="^[\/\\]")?"":"\") RegExReplace(directory, "[\\\/]", "\")
		
		if(targetAet="") { ; move to local
			targetAet:=this.aet 
			if !WinExist("ahk_pid " dcm4che.storescpPID)
				if this.storescp(11112, directory, "")=-1
					return
			;~ targetAet:=this.aet " -b " this.aet "@" A_IPAddress1 ":11112 " 
		}
		
		if !IsObject(SeriesUIDArr)
			SeriesUIDArr:=[SeriesUIDArr]
		
		for k,v in SeriesUIDArr {
			parameter:="-L SERIES -b " this.aet " --dest " targetAet " -c " this.remote.aet "@" this.remote.ip ":" this.remote.port " -m SeriesInstanceUID=" v " " 
			,outputFileName:="__dcm4cheOutput" a_now a_tickcount
			;~ MsgBox % parameter
			;~ RunWait,% """" this.dcmPath """ " parameter " > """ a_scriptdir "\" outputFileName """",% a_scriptdir
			if (wait)
				RunWait,% """" this.dcmPath "movescu.bat"" " parameter ,% a_scriptdir,Hide
			else
				Run,% """" this.dcmPath "movescu.bat"" " parameter ,% a_scriptdir,Hide
			fileread,__dcm4cheOutput,% A_ScriptDir "\" outputFileName
			FileDelete,% A_ScriptDir "\" outputFileName
			this.LastOutput:=__dcm4cheOutput
			;~ fileread,__dcm4cheOutput,% A_ScriptDir "\" outputFileName
			;~ clipboard.=__dcm4cheOutput
			;~ FileDelete,% A_ScriptDir "\" outputFileName
		}
	}
	
	storescp(port="", directory="", filepath=""){
		if (directory = "")
			directory:=A_ScriptDir
		if (!directory~="^\w+:")
			directory:=A_ScriptDir ((directory~="^[\/\\]")?"":"\") RegExReplace(directory, "[\\\/]", "\")
		if filepath=
			filepath:="{00100020} {00080050}/{00200011}/{00080018}.dcm"
		if port is not number
			port:=11112
		
		if (prc:=process_listening_port(port)) && (prc!=dcm4che.storescpPID){
			process,Close,% prc
		}
		
		parameter:="-b " this.aet ":" port " --directory """ directory """ --filepath """ filepath """"
		Run, % """" this.dcmPath "storescp.bat"" " parameter,% A_ScriptDir,UseErrorLevel, PID
		if(ErrorLevel="ERROR")
			return -1
		else{
			Sleep 1000
			dcm4che.storescpPID:=PID
			WinHide,% "ahk_pid " PID
			return PID
		}		
		
	}
	
	PACStoRAID(AccNoOrChartNoDate="", filterDict=""){
		filter:=" " this.filter(filterDict)
		if InStr(filter, "SeriesInstanceUID")
			level:="SERIES"
		;~ else if InStr(filter, "InstanceUID")
			;~ level:="IMAGE"
		else
			level:="STUDY"
		if(AccNoOrChartNoDate=""){
			if Trim(filter)=""
				return
			parameter:="-L " level " -b EPHICT01AW02:104 --dest RAID -c PACSWFM2@10.0.0.1:104 " filter
			
		}else if !IsObject(AccNo:=AccNoOrChartNoDate)
			parameter:="-L " level " -b EPHICT01AW02:104 --dest RAID -c PACSWFM2@10.0.0.1:104 -m AccessionNumber=" AccNo " " filter
		else {
			chartNo:=AccNoOrChartNoDate.ChartNo
			, date:=AccNoOrChartNoDate.date
			if(chartNo!="" && date!="")
				;~ parameter:="-L STUDY EPHICT01AW02:104 PACSWFM2@10.0.0.1:104 -qPatientID=" chartNo " -qInstanceCreationDate=" date " -cmove RAID"
				parameter:="-L " level " -b EPHICT01AW02:104 --dest RAID -c PACSWFM2@10.0.0.1:104 -m PatientID=" chartNo " -m InstanceCreationDate=" date " " filter
			else 
				return
		}
		outputFileName:="__dcm4cheOutput" a_now a_tickcount
			;~ MsgBox % parameter
			;~ RunWait,% """" this.dcmPath """ " parameter " > """ a_scriptdir "\" outputFileName """",% a_scriptdir
			Run,% """" this.dcmPath "movescu.bat"" " parameter filter ,% a_scriptdir,Hide
			fileread,__dcm4cheOutput,% A_ScriptDir "\" outputFileName
			FileDelete,% A_ScriptDir "\" outputFileName
			;~ this.LastOutput:=__dcm4cheOutput
	}
	
	__Delete(){
		if(--dcm4che.instanceCount=0)
			WinClose,% "ahk_pid " dcm4che.storescpPID
	}
}


class dcm4che_datarecord {
	static fieldsPattern :="i)(?P<tag>\([\dA-F]{4},[\dA-F]{4}\)) " "(?P<VR>[A-Z]{2}) " "\[(?P<value>[^\]]*)\] ?" "(?P<field>\w*)"
		
	__New(txt){
		if IsObject(txt)
			this.fields:=txt
		else
			this.fields:=RegExMatchAll(txt, dcm4che_datarecord.fieldsPattern).dict
		;~ MsgBox 
		;~ for k,v in this.fields
			;~ this.fields[k]:=new dcm4che_datafield(v)
	}
	
	getValue(fieldNameOrDicomTag){
		fieldNameOrDicomTag := RegExReplace(fieldNameOrDicomTag, "\W", "")

        if !(fieldNameOrDicomTag~="i)^[\dA-F]{8}$")
            ;~ fieldNameOrDicomTag := (new DicomTagName(fieldNameOrDicomTag)).tagId
			if DicomTagName.haskey(fieldNameOrDicomTag)
				fieldNameOrDicomTag:=DicomTagName[fieldNameOrDicomTag]
				,dicomTagId := "("  fieldNameOrDicomTag ")"
			else
				return ""
      
		dicomTagId := "(" + SubStr(fieldNameOrDicomTag,1,4)  "," SubStr(fieldNameOrDicomTag,5,4) ")"

        for k, field in this.fields
            ;~ if (field.tag=dicomTagId)
			if (field.tag=fieldNameOrDicomTag )
                return field.value
        return ""
	}
    __get(item){
       return this.getValue(item)
	}	
}


;~ class dcm4che_datafield {
    ;~ __New(field_dict){
        ;~ for k, v in field_dict
            ;~ this[k]:=v
	;~ }
;~ }


