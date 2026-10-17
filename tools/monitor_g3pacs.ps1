param(
    [string]$OutputPath = "",
    [int]$DurationMinutes = 0
)

$ErrorActionPreference = "Continue"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = Join-Path $PSScriptRoot "..\logs\g3pacs_monitor_${stamp}.log"
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$script:Writer = [IO.StreamWriter]::new(
    $OutputPath,
    $false,
    [Text.UTF8Encoding]::new($true)
)
$script:Writer.AutoFlush = $true

function Write-MonitorLine {
    param([string]$Kind, [string]$Message)

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"), $Kind, $Message
    $script:Writer.WriteLine($line)
    Write-Host $line
}

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class G3WindowMonitorNative {
    public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern bool IsHungAppWindow(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int maxCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetClassName(IntPtr hwnd, StringBuilder text, int maxCount);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hwnd,
        uint message,
        IntPtr wParam,
        IntPtr lParam,
        uint flags,
        uint timeoutMilliseconds,
        out IntPtr result
    );
}
'@

$relevantNamePattern = '(?i)^(iexplore|g3pacs|pacs.*|.*pacs|.*infinitt.*|.*g3.*|rundll32|dllhost|mshta|wscript|cscript|javaw?|autorun|autohotkey|ych_.*|simpleris.*)\.exe$'
$relevantWindowPattern = '(?i)(IEFrame|Internet Explorer|G3PACS|INFINITT|openimg|webcvis|\bPACS\b|\bRIS\b)'
$watchedPids = [Collections.Generic.HashSet[int]]::new()
$knownProcesses = @{}
$knownWindows = @{}
$knownShellWindows = @{}
$knownEventRecords = [Collections.Generic.HashSet[long]]::new()
$monitorStarted = Get-Date
$lastApplicationScan = $monitorStarted.AddSeconds(-1)
$deadline = if ($DurationMinutes -gt 0) { $monitorStarted.AddMinutes($DurationMinutes) } else { [datetime]::MaxValue }
$startSource = "G3Monitor.ProcessStart.$PID"
$stopSource = "G3Monitor.ProcessStop.$PID"

function Get-CommandLineText {
    param([uint32]$ProcessId)

    try {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction Stop
        return "path='$($process.ExecutablePath)' cmd='$($process.CommandLine)'"
    } catch {
        return "details unavailable (process may already have exited)"
    }
}

function Register-RelevantProcess {
    param(
        [string]$Name,
        [int]$ProcessId,
        [int]$ParentProcessId
    )

    $isRelevant = $Name -match $relevantNamePattern
    $isChildOfWatched = $watchedPids.Contains($ParentProcessId)
    if ($isRelevant -or $isChildOfWatched) {
        [void]$watchedPids.Add($ProcessId)
        return $true
    }
    return $false
}

function Get-WindowSnapshot {
    $snapshot = @{}
    $callback = [G3WindowMonitorNative+EnumWindowsProc]{
        param([IntPtr]$hwnd, [IntPtr]$lParam)

        [uint32]$windowProcessId = 0
        [void][G3WindowMonitorNative]::GetWindowThreadProcessId($hwnd, [ref]$windowProcessId)
        $titleBuilder = [Text.StringBuilder]::new(1024)
        $classBuilder = [Text.StringBuilder]::new(256)
        [void][G3WindowMonitorNative]::GetWindowText($hwnd, $titleBuilder, $titleBuilder.Capacity)
        [void][G3WindowMonitorNative]::GetClassName($hwnd, $classBuilder, $classBuilder.Capacity)
        $title = $titleBuilder.ToString()
        $className = $classBuilder.ToString()

        $processName = ""
        try { $processName = (Get-Process -Id $windowProcessId -ErrorAction Stop).ProcessName + ".exe" } catch {}
        $titleOnlyExcluded = $processName -match '(?i)^(WindowsTerminal|chrome|msedge|Code)\.exe$'
        $isRelevant = $watchedPids.Contains([int]$windowProcessId) -or
            $processName -match $relevantNamePattern -or
            $className -match $relevantWindowPattern -or
            ((-not $titleOnlyExcluded) -and $title -match $relevantWindowPattern)

        if ($isRelevant) {
            [IntPtr]$messageResult = [IntPtr]::Zero
            $responded = [G3WindowMonitorNative]::SendMessageTimeout(
                $hwnd,
                0,
                [IntPtr]::Zero,
                [IntPtr]::Zero,
                2,
                250,
                [ref]$messageResult
            ) -ne [IntPtr]::Zero
            $key = "0x{0:X}" -f $hwnd.ToInt64()
            $snapshot[$key] = [pscustomobject]@{
                Hwnd = $key
                ProcessId = [int]$windowProcessId
                ProcessName = $processName
                ClassName = $className
                Title = $title
                Visible = [G3WindowMonitorNative]::IsWindowVisible($hwnd)
                Hung = [G3WindowMonitorNative]::IsHungAppWindow($hwnd)
                Responded = $responded
            }
        }
        return $true
    }

    [void][G3WindowMonitorNative]::EnumWindows($callback, [IntPtr]::Zero)
    return $snapshot
}

function Format-WindowInfo {
    param($Window)

    $safeTitle = ($Window.Title -replace '[\r\n\t]+', ' ')
    return "hwnd=$($Window.Hwnd) pid=$($Window.ProcessId) process='$($Window.ProcessName)' class='$($Window.ClassName)' visible=$($Window.Visible) hung=$($Window.Hung) responded=$($Window.Responded) title='$safeTitle'"
}

function Get-ShellWindowSnapshot {
    $snapshot = @{}
    try {
        $shell = New-Object -ComObject Shell.Application
        foreach ($window in @($shell.Windows())) {
            try {
                $fullName = [string]$window.FullName
                $url = [string]$window.LocationURL
                if ($fullName -match '(?i)iexplore\.exe$' -or $url -match '(?i)webcvis|openimg|pacs|g3') {
                    $key = "$($window.HWND)|$url"
                    $snapshot[$key] = [pscustomobject]@{
                        Hwnd = $window.HWND
                        FullName = $fullName
                        Name = [string]$window.Name
                        Url = $url
                        ReadyState = $window.ReadyState
                        Busy = $window.Busy
                        Visible = $window.Visible
                    }
                }
            } catch {}
        }
        [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) | Out-Null
    } catch {
        Write-MonitorLine "MONITOR" "Shell.Application enumeration error: $($_.Exception.Message)"
    }
    return $snapshot
}

function Format-ShellWindowInfo {
    param($Window)

    return "hwnd=$($Window.Hwnd) visible=$($Window.Visible) busy=$($Window.Busy) readyState=$($Window.ReadyState) exe='$($Window.FullName)' url='$($Window.Url)'"
}

try {
    Register-CimIndicationEvent -Namespace root/cimv2 -Query "SELECT * FROM Win32_ProcessStartTrace" -SourceIdentifier $startSource | Out-Null
    Register-CimIndicationEvent -Namespace root/cimv2 -Query "SELECT * FROM Win32_ProcessStopTrace" -SourceIdentifier $stopSource | Out-Null

    Write-MonitorLine "MONITOR" "started pid=$PID output='$OutputPath' durationMinutes=$DurationMinutes"

    foreach ($process in @(Get-CimInstance Win32_Process)) {
        $knownProcesses[[int]$process.ProcessId] = [string]$process.Name
        if (Register-RelevantProcess -Name $process.Name -ProcessId $process.ProcessId -ParentProcessId $process.ParentProcessId) {
            Write-MonitorLine "PROCESS_BASELINE" "name='$($process.Name)' pid=$($process.ProcessId) ppid=$($process.ParentProcessId) path='$($process.ExecutablePath)' cmd='$($process.CommandLine)'"
        }
    }

    $knownWindows = Get-WindowSnapshot
    foreach ($window in $knownWindows.Values) {
        Write-MonitorLine "WINDOW_BASELINE" (Format-WindowInfo $window)
    }
    $knownShellWindows = Get-ShellWindowSnapshot
    foreach ($window in $knownShellWindows.Values) {
        Write-MonitorLine "SHELL_BASELINE" (Format-ShellWindowInfo $window)
    }
    Write-MonitorLine "READY" "Open IE, log in, open the RIS list, then open a study and press PACS. Leave any failed temporary window untouched."

    $lastWindowPoll = [datetime]::MinValue
    $lastShellPoll = [datetime]::MinValue
    $lastHeartbeat = Get-Date

    while ((Get-Date) -lt $deadline) {
        foreach ($eventItem in @(Get-Event -SourceIdentifier $startSource -ErrorAction SilentlyContinue)) {
            $eventData = $eventItem.SourceEventArgs.NewEvent
            $name = [string]$eventData.ProcessName
            $processId = [int]$eventData.ProcessID
            $parentProcessId = [int]$eventData.ParentProcessID
            $knownProcesses[$processId] = $name
            $relevant = Register-RelevantProcess -Name $name -ProcessId $processId -ParentProcessId $parentProcessId
            $details = if ($relevant) { " " + (Get-CommandLineText $processId) } else { "" }
            Write-MonitorLine "PROCESS_START" "name='$name' pid=$processId ppid=$parentProcessId relevant=$relevant$details"
            Remove-Event -EventIdentifier $eventItem.EventIdentifier -ErrorAction SilentlyContinue
        }

        foreach ($eventItem in @(Get-Event -SourceIdentifier $stopSource -ErrorAction SilentlyContinue)) {
            $eventData = $eventItem.SourceEventArgs.NewEvent
            $name = [string]$eventData.ProcessName
            $processId = [int]$eventData.ProcessID
            $wasRelevant = $watchedPids.Contains($processId)
            if ($wasRelevant -or $name -match $relevantNamePattern) {
                Write-MonitorLine "PROCESS_STOP" "name='$name' pid=$processId relevant=$wasRelevant exitStatus=$($eventData.ExitStatus)"
            }
            [void]$watchedPids.Remove($processId)
            $knownProcesses.Remove($processId)
            Remove-Event -EventIdentifier $eventItem.EventIdentifier -ErrorAction SilentlyContinue
        }

        $now = Get-Date
        if (($now - $lastWindowPoll).TotalMilliseconds -ge 200) {
            $windowSnapshot = Get-WindowSnapshot
            foreach ($key in $windowSnapshot.Keys) {
                if (-not $knownWindows.ContainsKey($key)) {
                    Write-MonitorLine "WINDOW_OPEN" (Format-WindowInfo $windowSnapshot[$key])
                } elseif (
                    $knownWindows[$key].Title -ne $windowSnapshot[$key].Title -or
                    $knownWindows[$key].Visible -ne $windowSnapshot[$key].Visible -or
                    $knownWindows[$key].Hung -ne $windowSnapshot[$key].Hung -or
                    $knownWindows[$key].Responded -ne $windowSnapshot[$key].Responded
                ) {
                    Write-MonitorLine "WINDOW_CHANGE" (Format-WindowInfo $windowSnapshot[$key])
                }
            }
            foreach ($key in @($knownWindows.Keys)) {
                if (-not $windowSnapshot.ContainsKey($key)) {
                    Write-MonitorLine "WINDOW_CLOSE" (Format-WindowInfo $knownWindows[$key])
                }
            }
            $knownWindows = $windowSnapshot
            $lastWindowPoll = $now
        }

        if (($now - $lastShellPoll).TotalMilliseconds -ge 500) {
            $shellSnapshot = Get-ShellWindowSnapshot
            foreach ($key in $shellSnapshot.Keys) {
                if (-not $knownShellWindows.ContainsKey($key)) {
                    Write-MonitorLine "SHELL_OPEN" (Format-ShellWindowInfo $shellSnapshot[$key])
                }
            }
            foreach ($key in @($knownShellWindows.Keys)) {
                if (-not $shellSnapshot.ContainsKey($key)) {
                    Write-MonitorLine "SHELL_CLOSE" (Format-ShellWindowInfo $knownShellWindows[$key])
                }
            }
            $knownShellWindows = $shellSnapshot
            $lastShellPoll = $now
        }

        if (($now - $lastApplicationScan).TotalSeconds -ge 3) {
            try {
                $applicationEvents = Get-WinEvent -FilterHashtable @{
                    LogName = 'Application'
                    StartTime = $lastApplicationScan
                    Level = @(2, 3)
                } -ErrorAction SilentlyContinue
                foreach ($applicationEvent in @($applicationEvents)) {
                    if (
                        $knownEventRecords.Add([long]$applicationEvent.RecordId) -and
                        ($applicationEvent.ProviderName -match '(?i)Application Error|Application Hang|Windows Error Reporting' -or
                         $applicationEvent.Message -match '(?i)iexplore|G3PACS|INFINITT|G3WebToolkit')
                    ) {
                        $message = ($applicationEvent.Message -replace '[\r\n\t]+', ' ')
                        Write-MonitorLine "APPLICATION_EVENT" "provider='$($applicationEvent.ProviderName)' id=$($applicationEvent.Id) record=$($applicationEvent.RecordId) message='$message'"
                    }
                }
            } catch {}
            $lastApplicationScan = $now.AddSeconds(-1)
        }

        if (($now - $lastHeartbeat).TotalSeconds -ge 15) {
            Write-MonitorLine "HEARTBEAT" "monitor active; watchedPids=$($watchedPids.Count) windows=$($knownWindows.Count) shellWindows=$($knownShellWindows.Count)"
            $lastHeartbeat = $now
        }
        Start-Sleep -Milliseconds 100
    }
} finally {
    Unregister-Event -SourceIdentifier $startSource -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $stopSource -ErrorAction SilentlyContinue
    Get-Event -SourceIdentifier $startSource -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue
    Get-Event -SourceIdentifier $stopSource -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue
    Write-MonitorLine "MONITOR" "stopped"
    $script:Writer.Dispose()
}
