#NoEnv
#include <CH_RIS_Client>
#include <ReportImpression>
cases := [{reply: {ok: true, error: 0}, expected: ""}
        , {reply: {ok: false, error: 0}, expected: ""}
        , {reply: {ok: true, error: ""}, expected: ""}
        , {reply: {ok: false, error: "timeout"}, expected: "timeout"}
        , {reply: {ok: false, error: "no ris ie"}, expected: "no ris ie"}
        , {reply: "", expected: "invalid RIS sync reply"}
        , {reply: {ok: false}, expected: "RIS sync failed without an error description"}]
for i, case in cases {
    actual := CH_RIS_FlushReplyError(case.reply)
    if (actual != case.expected) {
        FileAppend, % "FAIL: reply case " i " returned [" actual "]`n", *
        ExitApp, 1
    }
}
report := new ReportImpression("INDICATION: diagnostic mammography.`r`nFINDINGS: unchanged.`r`n`r`nImpression:`r`nBI-RADS 2.")
if (report.impression != "BI-RADS 2." || !InStr(report.exam, "INDICATION: diagnostic mammography.")) {
    FileAppend, FAIL: report transfer lost indication or impression`n, *
    ExitApp, 1
}
FileAppend, PASS: 7 reply cases and report transfer split (no live RIS calls)`n, *
ExitApp, 0
