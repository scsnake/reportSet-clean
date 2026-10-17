; Crash-safe, process-shared recovery store for simpleRIS and YCH send paths.
; A study is keyed only by accession number. Metadata stays inside the study folder so
; delayed chart/date discovery cannot split one report across multiple recovery files.

SimpleRISRecovery_Dir() {
	global SimpleRISRecovery_TestDir
	if (SimpleRISRecovery_TestDir != "")
		return SimpleRISRecovery_TestDir
	if InStr(FileExist(A_ScriptDir "\PacsIE"), "D")
		return A_ScriptDir "\PacsIE\simpleRIS_autosave"
	return A_ScriptDir "\simpleRIS_autosave"
}

SimpleRISRecovery_NormalizeText(text) {
	text := RegExReplace(text, "\r\n?", "`n")
	return RegExReplace(text, "\n", "`r`n")
}

SimpleRISRecovery_ComparableText(text) {
	return Trim(RegExReplace(SimpleRISRecovery_NormalizeText(text), "[ `t]+", " "))
}

SimpleRISRecovery_IsBlankOrTitle(text, examName := "") {
	text := SimpleRISRecovery_ComparableText(text)
	examName := SimpleRISRecovery_ComparableText(examName)
	return (text = "" || (examName != "" && text = examName))
}

SimpleRISRecovery_SanitizePart(text, fallback := "") {
	text := Trim(text)
	if (text = "")
		text := fallback
	text := RegExReplace(text, "[^0-9A-Za-z._-]", "_")
	; Never allow a sanitized accession to become a relative path component or a
	; Windows device name. RIS accessions are normally numeric, but recovery storage
	; must remain contained even when upstream data is malformed.
	if RegExMatch(text, "^\.+$")
		text := RegExReplace(text, "\.", "_")
	if RegExMatch(text, "i)^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)")
		text := "_" text
	return text
}

SimpleRISRecovery_StudyDir(accNo) {
	accNo := SimpleRISRecovery_SanitizePart(accNo)
	return (accNo = "") ? "" : SimpleRISRecovery_Dir() "\" accNo
}

SimpleRISRecovery_CurrentPath(accNo) {
	dir := SimpleRISRecovery_StudyDir(accNo)
	return (dir = "") ? "" : dir "\current.txt"
}

SimpleRISRecovery_MetaPath(accNo) {
	dir := SimpleRISRecovery_StudyDir(accNo)
	return (dir = "") ? "" : dir "\meta.ini"
}

SimpleRISRecovery_MetaValue(text) {
	return Trim(RegExReplace(text, "[\r\n=]", " "))
}

SimpleRISRecovery_CompareStamp(left, right) {
	; A recovery stamp is YYYYMMDDHH24MISSmmm. Compare the 14-digit second and
	; 3-digit millisecond portions separately so old AHK v1 builds do not lose
	; precision by coercing the full 17-digit value to a floating-point number.
	leftSecond:=SubStr(left, 1, 14)+0
	rightSecond:=SubStr(right, 1, 14)+0
	if (leftSecond!=rightSecond)
		return (leftSecond>rightSecond) ? 1 : -1
	leftMillisecond:=SubStr(left, 15)+0
	rightMillisecond:=SubStr(right, 15)+0
	if (leftMillisecond=rightMillisecond)
		return 0
	return (leftMillisecond>rightMillisecond) ? 1 : -1
}

SimpleRISRecovery_Lock(timeoutMs := 3000) {
	hMutex := DllCall("CreateMutex", "Ptr", 0, "Int", 0
		, "Str", "Local\SimpleRISRecoveryStoreV2", "Ptr")
	if !hMutex
		return 0
	waitResult := DllCall("WaitForSingleObject", "Ptr", hMutex, "UInt", timeoutMs)
	if (waitResult = 0 || waitResult = 0x80)
		return hMutex
	DllCall("CloseHandle", "Ptr", hMutex)
	return 0
}

SimpleRISRecovery_Unlock(hMutex) {
	if !hMutex
		return
	DllCall("ReleaseMutex", "Ptr", hMutex)
	DllCall("CloseHandle", "Ptr", hMutex)
}

SimpleRISRecovery_AtomicWrite(path, text) {
	global SimpleRISRecovery_LastError
	SimpleRISRecovery_LastError := ""
	SplitPath, path, fileName, dir
	FileCreateDir, % dir
	tmpPath := path "." DllCall("GetCurrentProcessId") "." A_TickCount ".tmp"
	backupPath := path ".bak"
	if FileExist(tmpPath)
		FileDelete, % tmpPath

	file := FileOpen(tmpPath, "w", "UTF-8-RAW")
	if !IsObject(file) {
		SimpleRISRecovery_LastError := "FileOpen failed: " path
		return false
	}
	file.Write(text)
	try DllCall("FlushFileBuffers", "Ptr", file.__Handle)
	file.Close()
	if !FileExist(tmpPath) {
		SimpleRISRecovery_LastError := "temporary file missing: " tmpPath
		return false
	}

	if FileExist(backupPath)
		FileDelete, % backupPath
	if FileExist(path) {
		FileMove, % path, % backupPath, 1
		if ErrorLevel {
			SimpleRISRecovery_LastError := "backup move failed: " path
			if FileExist(tmpPath)
				FileDelete, % tmpPath
			return false
		}
	}

	FileMove, % tmpPath, % path, 1
	if ErrorLevel {
		SimpleRISRecovery_LastError := "replacement move failed: " tmpPath
		if FileExist(backupPath)
			FileMove, % backupPath, % path, 1
		if FileExist(tmpPath)
			FileDelete, % tmpPath
		return false
	}
	if FileExist(backupPath)
		FileDelete, % backupPath
	return true
}

SimpleRISRecovery_ReadFile(path, ByRef found := false) {
	found := false
	readPath := path
	if !FileExist(readPath) && FileExist(path ".bak")
		readPath := path ".bak"
	if !FileExist(readPath)
		return ""
	file:=FileOpen(readPath, "r", "UTF-8-RAW")
	if !IsObject(file)
		return ""
	text:=file.Read()
	file.Close()
	found := true
	return SimpleRISRecovery_NormalizeText(text)
}

SimpleRISRecovery_ReadMeta(accNo) {
	path := SimpleRISRecovery_MetaPath(accNo)
	meta := {status: "", updated: "", updatedStamp: "", chartNo: "", examDate: "", examName: ""}
	readPath:=path
	if !FileExist(readPath) && FileExist(path ".bak")
		readPath:=path ".bak"
	if !FileExist(readPath)
		return meta
	IniRead, value, % readPath, Recovery, status,
	meta.status := value
	IniRead, value, % readPath, Recovery, updated,
	meta.updated := value
	IniRead, value, % readPath, Recovery, updatedStamp,
	meta.updatedStamp := value
	IniRead, value, % readPath, Recovery, chartNo,
	meta.chartNo := value
	IniRead, value, % readPath, Recovery, examDate,
	meta.examDate := value
	IniRead, value, % readPath, Recovery, examName,
	meta.examName := value
	return meta
}

SimpleRISRecovery_BuildMeta(status, study := "") {
	chartNo := "", examDate := "", examName := ""
	if IsObject(study) {
		try chartNo := study.chartNo
		try examDate := study.examDate
		if (examDate = "")
			try examDate := study.examdate
		try examName := study.examName
		if (examName = "")
			try examName := study.examname
	}
	return "[Recovery]`r`n"
		. "version=2`r`n"
		. "status=" SimpleRISRecovery_MetaValue(status) "`r`n"
		. "updated=" A_Now "`r`n"
		. "updatedStamp=" A_Now A_MSec "`r`n"
		. "chartNo=" SimpleRISRecovery_MetaValue(chartNo) "`r`n"
		. "examDate=" SimpleRISRecovery_MetaValue(examDate) "`r`n"
		. "examName=" SimpleRISRecovery_MetaValue(examName) "`r`n"
}

SimpleRISRecovery_Save(accNo, text, status := "draft", study := "", forceSnapshot := false
	, sourceEditStamp := "") {
	global SimpleRISRecovery_LastError, SimpleRISRecovery_LastStep
	SimpleRISRecovery_LastError := ""
	SimpleRISRecovery_LastStep := "validate input"
	accNo := Trim(accNo)
	if (accNo = "")
		return false
	text := SimpleRISRecovery_NormalizeText(text)
	studyDir := SimpleRISRecovery_StudyDir(accNo)
	if (studyDir = "")
		return false

	hMutex := SimpleRISRecovery_Lock()
	if !hMutex {
		SimpleRISRecovery_LastError := "recovery store lock timed out"
		return false
	}
	result := false
	try {
		SimpleRISRecovery_LastStep := "create directories"
		FileCreateDir, % studyDir
		FileCreateDir, % studyDir "\history"
		SimpleRISRecovery_LastStep := "read existing recovery"
		currentPath := studyDir "\current.txt"
		oldText := SimpleRISRecovery_ReadFile(currentPath, oldFound)
		oldMeta := SimpleRISRecovery_ReadMeta(accNo)

		; A send event is authoritative. A passive timer/reset may not replace the exact YCH
		; final text. Only a later SC_PERFORMED_USER edit can reopen it as a new draft.
		if (oldMeta.status = "finalized"
			&& (status = "draft" || status = "cleared" || status = "title_only")) {
			if (oldText = text || sourceEditStamp = ""
				|| SimpleRISRecovery_CompareStamp(sourceEditStamp, oldMeta.updatedStamp) <= 0) {
				result := true
				throw Exception("SimpleRISRecoveryNoChange")
			}
		}

		if (oldFound && oldText = text && oldMeta.status = status && !forceSnapshot) {
			result := true
			throw Exception("SimpleRISRecoveryNoChange")
		}

		SimpleRISRecovery_LastStep := "write current"
		if !SimpleRISRecovery_AtomicWrite(currentPath, text)
			throw Exception("cannot write current recovery text")
		SimpleRISRecovery_LastStep := "write metadata"
		if !SimpleRISRecovery_AtomicWrite(studyDir "\meta.ini"
			, SimpleRISRecovery_BuildMeta(status, study))
			throw Exception("cannot write recovery metadata")

		SimpleRISRecovery_LastStep := "write history"
		snapshotStatus := SimpleRISRecovery_SanitizePart(status, "draft")
		snapshotPath := studyDir "\history\" A_Now "_" A_MSec "_"
			. DllCall("GetCurrentProcessId") "_" snapshotStatus ".txt"
		SimpleRISRecovery_AtomicWrite(snapshotPath, text)
		SimpleRISRecovery_LastStep := "prune history"
		SimpleRISRecovery_PruneHistory(studyDir "\history", 50)
		result := true
	} catch e {
		if (e.Message != "SimpleRISRecoveryNoChange") {
			SimpleRISRecovery_LastError := SimpleRISRecovery_LastStep ": " e.Message
				. " | what=" e.What " | line=" e.Line " | extra=" e.Extra
			result := false
		}
	}
	SimpleRISRecovery_Unlock(hMutex)
	return result
}

SimpleRISRecovery_PruneHistory(historyDir, maxFiles := 50) {
	fileCount := 0
	Loop, Files, % historyDir "\*.txt"
		fileCount++
	while (fileCount > maxFiles) {
		oldestPath := "", oldestName := ""
		Loop, Files, % historyDir "\*.txt"
		{
			if (oldestName = "" || A_LoopFileName < oldestName) {
				oldestName := A_LoopFileName
				oldestPath := A_LoopFileLongPath
			}
		}
		if (oldestPath = "")
			break
		FileDelete, % oldestPath
		if ErrorLevel
			break
		fileCount--
	}
}

SimpleRISRecovery_FindLegacy(accNo, ByRef found := false) {
	found := false
	safeAccNo := SimpleRISRecovery_SanitizePart(accNo)
	if (safeAccNo = "")
		return ""
	newestPath := "", newestTime := ""
	Loop, Files, % SimpleRISRecovery_Dir() "\*_*_" safeAccNo ".txt"
	{
		if (newestTime = "" || A_LoopFileTimeModified > newestTime) {
			newestTime := A_LoopFileTimeModified
			newestPath := A_LoopFileLongPath
		}
	}
	if (newestPath = "")
		return ""
	return SimpleRISRecovery_ReadFile(newestPath, found)
}

SimpleRISRecovery_Load(accNo, ByRef status := "", ByRef found := false) {
	status := "", found := false
	path := SimpleRISRecovery_CurrentPath(accNo)
	if (path = "")
		return ""
	text := SimpleRISRecovery_ReadFile(path, found)
	if found {
		meta := SimpleRISRecovery_ReadMeta(accNo)
		status := (meta.status = "") ? "draft" : meta.status
		; current.txt is replaced before meta.ini. If the process or metadata write fails
		; between those operations, do not let a stale tombstone hide a newer nonblank
		; draft. A genuine title-only value must still match the title stored in metadata.
		if (status = "cleared" && Trim(text) != "")
			status := "draft"
		else if (status = "title_only"
			&& !SimpleRISRecovery_IsBlankOrTitle(text, meta.examName))
			status := "draft"
		return text
	}
	text := SimpleRISRecovery_FindLegacy(accNo, found)
	if found
		status := "draft"
	return text
}

SimpleRISRecovery_Cleanup(retentionDays := 31) {
	dir := SimpleRISRecovery_Dir()
	if !InStr(FileExist(dir), "D")
		return
	now := A_Now
	Loop, Files, % dir "\*", FR
	{
		ageDays := now
		EnvSub, ageDays, % A_LoopFileTimeModified, Days
		if (ageDays > retentionDays)
			FileDelete, % A_LoopFileLongPath
	}
	; Remove only empty directories; active or recently retained studies remain untouched.
	Loop, Files, % dir "\*", D
	{
		studyDir := A_LoopFileLongPath
		FileRemoveDir, % studyDir "\history"
		FileRemoveDir, % studyDir
	}
}
