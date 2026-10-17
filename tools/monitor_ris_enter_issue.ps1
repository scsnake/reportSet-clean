param(
    [string]$LogPath = "",
    [int]$DurationSeconds = 1800,
    [int]$PollMilliseconds = 200
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogPath = Join-Path $PSScriptRoot "..\logs\ris_enter_monitor_${stamp}.log"
}

$resolvedLogPath = [System.IO.Path]::GetFullPath($LogPath)
$logDirectory = Split-Path -Parent $resolvedLogPath
if (-not (Test-Path -LiteralPath $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
}

function Write-MonitorLine {
    param([string]$Message)

    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $Message"
    Add-Content -LiteralPath $resolvedLogPath -Value $line -Encoding UTF8
    Write-Output $line
    [Console]::Out.Flush()
}

function Get-DocumentToken {
    param($Document)

    $unknownPointer = [IntPtr]::Zero
    try {
        $unknownPointer = [Runtime.InteropServices.Marshal]::GetIUnknownForObject($Document)
        return $unknownPointer.ToInt64()
    }
    catch {
        return 0
    }
    finally {
        if ($unknownPointer -ne [IntPtr]::Zero) {
            [void][Runtime.InteropServices.Marshal]::Release($unknownPointer)
        }
    }
}

function Get-ElementValueByName {
    param($Document, [string]$Name)

    try {
        $elements = $Document.getElementsByName($Name)
        if ($elements -and $elements.length -gt 0) {
            return [string]$elements.item(0).value
        }
    }
    catch {}
    return ""
}

function Get-StatsStorageSummary {
    param($Document)

    try {
        $rawValue = [string]$Document.parentWindow.sessionStorage.getItem("ahkRISStatsFocusV1")
        if ([string]::IsNullOrWhiteSpace($rawValue)) {
            return "none"
        }
        $parts = $rawValue.Split('|')
        $activeKey = if ($parts.Length -gt 0) { [Uri]::UnescapeDataString($parts[0]) } else { "?" }
        $cursor = if ($parts.Length -gt 1) { $parts[1] } else { "?" }
        return "${activeKey}@${cursor}"
    }
    catch {
        return "unavailable"
    }
}

function Get-FocusedNativeIndex {
    param($Document)

    try {
        $table = $Document.getElementById("row_main")
        if (-not $table) {
            return ""
        }
        for ($rowIndex = 1; $rowIndex -lt $table.rows.length; $rowIndex++) {
            $row = $table.rows.item($rowIndex)
            if (-not $row -or -not $row.cells -or $row.cells.length -le 2) {
                continue
            }
            $firstCell = $row.cells.item(0)
            $borderWidth = [string]$firstCell.style.borderTopWidth
            $borderStyle = [string]$firstCell.style.borderTopStyle
            if ($borderWidth -eq "2px" -and $borderStyle -eq "solid") {
                return ([string]$row.cells.item(2).innerHTML).Trim()
            }
        }
    }
    catch {}
    return ""
}

function Get-OpenerSummary {
    param($Document)

    try {
        $opener = $Document.parentWindow.opener
        if (-not $opener) {
            return "none"
        }
        if ($opener.closed) {
            return "closed"
        }

        $openerDocument = $opener.document
        $openerUrl = [string]$opener.location.href
        $masterIndex = Get-ElementValueByName -Document $openerDocument -Name "masterindex"
        $hasForm = $false
        $hasCallReport = $false
        try { $hasForm = [bool]$openerDocument.forms.item("MJB3WForm") } catch {}
        try { $hasCallReport = [bool]$opener.callreport } catch {}
        $pageName = if ($openerUrl -match '/([^/?]+)(?:\?|$)') { $Matches[1] } else { $openerUrl }
        return "${pageName},form=${hasForm},callreport=${hasCallReport},master=${masterIndex}"
    }
    catch {
        return "error"
    }
}

function Get-WindowSnapshot {
    param($BrowserWindow)

    $windowHandle = [long]$BrowserWindow.HWND
    $url = [string]$BrowserWindow.LocationURL
    $busy = $false
    $readyState = "?"
    $document = $null
    try { $busy = [bool]$BrowserWindow.Busy } catch {}
    try { $readyState = [string]$BrowserWindow.ReadyState } catch {}

    try {
        $document = $BrowserWindow.Document
    }
    catch {
        return [pscustomobject]@{
            HWND = $windowHandle
            Kind = "ie"
            Summary = "url=${url} ready=${readyState} busy=${busy} dom=unavailable"
            BlankCandidate = $false
        }
    }

    $documentToken = Get-DocumentToken -Document $document
    $hasList = $false
    $hasExam = $false
    $bodyTextLength = -1
    $bodyHtmlLength = -1
    try { $hasList = [bool]$document.getElementById("row_main") } catch {}
    try { $hasExam = [bool]$document.getElementById("exam") } catch {}
    try { $bodyTextLength = ([string]$document.body.innerText).Trim().Length } catch {}
    try { $bodyHtmlLength = ([string]$document.body.innerHTML).Length } catch {}

    if ($hasList) {
        $rowCount = -1
        try { $rowCount = [int]$document.getElementById("row_main").rows.length } catch {}
        $masterIndex = Get-ElementValueByName -Document $document -Name "masterindex"
        $focusedIndex = Get-FocusedNativeIndex -Document $document
        $statsState = Get-StatsStorageSummary -Document $document
        $enhanced = $false
        try { $enhanced = [bool]$document.getElementById("ahk_is_enhanced") } catch {}
        return [pscustomobject]@{
            HWND = $windowHandle
            Kind = "list"
            Summary = "doc=${documentToken} ready=${readyState} busy=${busy} rows=${rowCount} master=${masterIndex} focus=${focusedIndex} stats=${statsState} enhanced=${enhanced}"
            BlankCandidate = $false
        }
    }

    $isReportUrl = $url -match '/MJB/MJB3[A-Z0-9]+\.do'
    if ($isReportUrl -or $hasExam) {
        $urlIndex = ""
        if ($url -match '[?&]index=([^&]+)') {
            $urlIndex = $Matches[1]
        }
        $formIndex = Get-ElementValueByName -Document $document -Name "index"
        $status = Get-ElementValueByName -Document $document -Name "status"
        $sendSelect = Get-ElementValueByName -Document $document -Name "sendSelect"
        $openerSummary = Get-OpenerSummary -Document $document
        $errorPage = $false
        try {
            $bodyText = [string]$document.body.innerText
            $errorPage = $bodyText -match 'Requested page not found|發生錯誤'
        }
        catch {}
        $blankCandidate = (-not $busy) -and ($readyState -eq "4" -or $readyState -eq "complete") -and (-not $hasExam) -and ($bodyTextLength -le 0)
        return [pscustomobject]@{
            HWND = $windowHandle
            Kind = "report"
            Summary = "doc=${documentToken} urlIndex=${urlIndex} formIndex=${formIndex} ready=${readyState} busy=${busy} exam=${hasExam} status=${status} send=${sendSelect} textLen=${bodyTextLength} htmlLen=${bodyHtmlLength} error=${errorPage} opener=[${openerSummary}]"
            BlankCandidate = $blankCandidate
        }
    }

    return [pscustomobject]@{
        HWND = $windowHandle
        Kind = "ie"
        Summary = "doc=${documentToken} url=${url} ready=${readyState} busy=${busy} textLen=${bodyTextLength}"
        BlankCandidate = $false
    }
}

$shellApplication = New-Object -ComObject Shell.Application
$lastSnapshots = @{}
$blankStarted = @{}
$blankConfirmed = @{}
$deadline = (Get-Date).AddSeconds($DurationSeconds)

Write-MonitorLine "MONITOR_START log=${resolvedLogPath} durationSeconds=${DurationSeconds} pollMilliseconds=${PollMilliseconds}"

while ((Get-Date) -lt $deadline) {
    $seenHandles = @{}
    try {
        $windows = @($shellApplication.Windows())
    }
    catch {
        Write-MonitorLine "ENUMERATION_ERROR message=$($_.Exception.Message)"
        Start-Sleep -Milliseconds $PollMilliseconds
        continue
    }

    foreach ($browserWindow in $windows) {
        try {
            if ([string]$browserWindow.FullName -notmatch 'iexplore\.exe$') {
                continue
            }
            $snapshot = Get-WindowSnapshot -BrowserWindow $browserWindow
            $handleKey = [string]$snapshot.HWND
            $seenHandles[$handleKey] = $true
            $snapshotKey = "$($snapshot.Kind)|$($snapshot.Summary)"

            if (-not $lastSnapshots.ContainsKey($handleKey) -or $lastSnapshots[$handleKey] -ne $snapshotKey) {
                Write-MonitorLine "WINDOW hwnd=$handleKey kind=$($snapshot.Kind) $($snapshot.Summary)"
                $lastSnapshots[$handleKey] = $snapshotKey
            }

            if ($snapshot.BlankCandidate) {
                if (-not $blankStarted.ContainsKey($handleKey)) {
                    $blankStarted[$handleKey] = Get-Date
                    Write-MonitorLine "BLANK_CANDIDATE hwnd=$handleKey"
                }
                $blankAge = ((Get-Date) - $blankStarted[$handleKey]).TotalSeconds
                if ($blankAge -ge 2 -and -not $blankConfirmed.ContainsKey($handleKey)) {
                    $blankConfirmed[$handleKey] = $true
                    Write-MonitorLine "BLANK_CONFIRMED hwnd=$handleKey durationSeconds=$([Math]::Round($blankAge, 1)) $($snapshot.Summary)"
                }
            }
            elseif ($blankStarted.ContainsKey($handleKey)) {
                $blankAge = ((Get-Date) - $blankStarted[$handleKey]).TotalSeconds
                Write-MonitorLine "BLANK_RECOVERED hwnd=$handleKey durationSeconds=$([Math]::Round($blankAge, 1))"
                $blankStarted.Remove($handleKey)
                $blankConfirmed.Remove($handleKey)
            }
        }
        catch {
            Write-MonitorLine "WINDOW_ERROR message=$($_.Exception.Message)"
        }
    }

    foreach ($knownHandle in @($lastSnapshots.Keys)) {
        if (-not $seenHandles.ContainsKey($knownHandle)) {
            Write-MonitorLine "WINDOW_CLOSED hwnd=$knownHandle"
            $lastSnapshots.Remove($knownHandle)
            $blankStarted.Remove($knownHandle)
            $blankConfirmed.Remove($knownHandle)
        }
    }

    Start-Sleep -Milliseconds $PollMilliseconds
}

Write-MonitorLine "MONITOR_TIMEOUT"
