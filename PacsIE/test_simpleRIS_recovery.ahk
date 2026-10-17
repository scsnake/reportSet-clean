#NoEnv
SetBatchLines, -1
SetWorkingDir, % A_ScriptDir

global SimpleRISRecovery_TestDir := A_ScriptDir "\simpleRIS_recovery_test_tmp"
global SimpleRISRecovery_TestFailures := 0

; This path is a fixed test-only child of PacsIE; never point the override at production data.
if InStr(FileExist(SimpleRISRecovery_TestDir), "D")
	FileRemoveDir, % SimpleRISRecovery_TestDir, 1
FileCreateDir, % SimpleRISRecovery_TestDir

#Include %A_ScriptDir%\..\Lib\SimpleRISRecovery.ahk

study := {chartNo: "CHART001", examDate: "20260717", examName: "CT CHEST"}
Test_Assert(SimpleRISRecovery_CompareStamp("20260717120000124", "20260717120000123") > 0
	, "compare recovery timestamp milliseconds")
Test_Assert(SimpleRISRecovery_SanitizePart("..") = "__"
	&& SimpleRISRecovery_SanitizePart("CON.txt") = "_CON.txt"
	, "sanitize unsafe Windows path components")

directPath := SimpleRISRecovery_Dir() "\direct.txt"
directResult := SimpleRISRecovery_AtomicWrite(directPath, "direct")
Test_Assert(directResult && FileExist(directPath), "direct atomic write")
if (!directResult)
	FileAppend, % "  error: " SimpleRISRecovery_LastError "`n", *
nestedPath := SimpleRISRecovery_StudyDir("NESTED") "\current.txt"
nestedResult := SimpleRISRecovery_AtomicWrite(nestedPath, "nested")
Test_Assert(nestedResult && FileExist(nestedPath), "nested atomic write")
if (!nestedResult)
	FileAppend, % "  error: " SimpleRISRecovery_LastError "`n", *

Test_Assert(SimpleRISRecovery_Save("ACC001", "draft one", "draft", study)
	, "save draft")
if (SimpleRISRecovery_LastError != "")
	FileAppend, % "  error: " SimpleRISRecovery_LastError "`n", *
text := SimpleRISRecovery_Load("ACC001", status, found)
Test_Assert(found && status = "draft" && text = "draft one", "load draft")
Test_Assert(SimpleRISRecovery_Save("ACCUTF8", "中文報告：無異常", "draft", study)
	, "save UTF-8 report")
text := SimpleRISRecovery_Load("ACCUTF8", status, found)
Test_Assert(found && text = "中文報告：無異常", "load UTF-8 report")

; Simulate a crash after current.txt was moved aside but before replacement completed.
currentPath := SimpleRISRecovery_CurrentPath("ACC001")
FileMove, % currentPath, % currentPath ".bak", 1
text := SimpleRISRecovery_Load("ACC001", status, found)
Test_Assert(found && text = "draft one", "load atomic backup fallback")
FileMove, % currentPath ".bak", % currentPath, 1

Test_Assert(SimpleRISRecovery_Save("ACC001", "", "cleared", study, true)
	, "save cleared tombstone")
text := SimpleRISRecovery_Load("ACC001", status, found)
Test_Assert(found && status = "cleared" && text = "", "load cleared tombstone")

; Simulate interruption after current.txt was committed but before meta.ini. A stale
; cleared/title-only status must not suppress the newer nonblank draft.
Test_Assert(SimpleRISRecovery_AtomicWrite(SimpleRISRecovery_CurrentPath("ACC001")
	, "draft after clear"), "simulate text commit after clear")
text := SimpleRISRecovery_Load("ACC001", status, found)
Test_Assert(found && status = "draft" && text = "draft after clear"
	, "stale cleared metadata cannot hide newer draft")
Test_Assert(SimpleRISRecovery_Save("ACC005", "CT CHEST", "title_only", study, true)
	, "save title-only recovery")
text := SimpleRISRecovery_Load("ACC005", status, found)
Test_Assert(found && status = "title_only" && text = "CT CHEST"
	, "matching title-only recovery remains a tombstone")
Test_Assert(SimpleRISRecovery_AtomicWrite(SimpleRISRecovery_CurrentPath("ACC005")
	, "draft after title"), "simulate text commit after title")
text := SimpleRISRecovery_Load("ACC005", status, found)
Test_Assert(found && status = "draft" && text = "draft after title"
	, "stale title-only metadata cannot hide newer draft")

Test_Assert(SimpleRISRecovery_Save("ACC002", "exact final", "finalized", study, true)
	, "save finalized")
Test_Assert(SimpleRISRecovery_Save("ACC002", "older timer draft", "draft", study)
	, "ignore trailing timer draft")
text := SimpleRISRecovery_Load("ACC002", status, found)
Test_Assert(found && status = "finalized" && text = "exact final"
	, "finalized text remains authoritative")
Test_Assert(SimpleRISRecovery_Save("ACC004", "first final", "finalized", study, true)
	, "save finalized before revision")
Test_Assert(SimpleRISRecovery_Save("ACC004", "user revision", "draft", study, false
	, "99999999999999999"), "user edit reopens finalized report")
text := SimpleRISRecovery_Load("ACC004", status, found)
Test_Assert(found && status = "draft" && text = "user revision"
	, "reopened draft becomes recovery head")

Loop, 55
	SimpleRISRecovery_Save("ACC003", "version " A_Index, "draft", study, true)
historyCount := 0
Loop, Files, % SimpleRISRecovery_StudyDir("ACC003") "\history\*.txt"
	historyCount++
Test_Assert(historyCount <= 50, "history pruned to 50 snapshots")

legacyPath := SimpleRISRecovery_Dir() "\20260717_CHART_LEGACY.txt"
Test_WriteUtf8(legacyPath, "legacy report")
text := SimpleRISRecovery_Load("LEGACY", status, found)
Test_Assert(found && status = "draft" && text = "legacy report", "legacy file load")

Test_Assert(SimpleRISRecovery_Save("OLDACC", "expired", "draft", study)
	, "save cleanup fixture")
oldDir := SimpleRISRecovery_StudyDir("OLDACC")
Loop, Files, % oldDir "\*", FR
	FileSetTime, 20200101000000, % A_LoopFileLongPath, M
SimpleRISRecovery_Cleanup(31)
Test_Assert(!FileExist(SimpleRISRecovery_CurrentPath("OLDACC")), "delete expired recovery")

if (SimpleRISRecovery_TestFailures = 0)
	FileAppend, PASS: simpleRIS recovery tests`n, *
else
	FileAppend, % "FAILURES=" SimpleRISRecovery_TestFailures "`n", *

FileRemoveDir, % SimpleRISRecovery_TestDir, 1
testExitCode:=SimpleRISRecovery_TestFailures ? 1 : 0
ExitApp, % testExitCode

Test_Assert(condition, name) {
	global SimpleRISRecovery_TestFailures
	if condition {
		FileAppend, % "PASS: " name "`n", *
		return
	}
	SimpleRISRecovery_TestFailures++
	FileAppend, % "FAIL: " name "`n", *
}

Test_WriteUtf8(path, text) {
	SplitPath, path, fileName, dir
	FileCreateDir, % dir
	file := FileOpen(path, "w", "UTF-8-RAW")
	file.Write(text)
	file.Close()
}
