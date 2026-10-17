# Registers the "MammoPdfDB Logon" task and removes the legacy daily task.
# This task mounts Z: P: Q: network drives AND runs the mammo DB refresh.
# Run once, in an *elevated* PowerShell, as the reporting user.
#
#   powershell -ExecutionPolicy Bypass -File .\register_logon_task.ps1
#
# Pre-req: store credentials ONCE so they survive reboots:
#   cmdkey /add:192.0.2.10   /user:<DOMAIN\user> /pass:<password>
#   cmdkey /add:10.0.0.1  /user:<DOMAIN\user> /pass:<password>
#
# Uses the ScheduledTasks module instead of schtasks.exe so paths with spaces
# (e.g. "CH scripts") don't need shell-quoting gymnastics.

$ErrorActionPreference = 'Stop'

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$logonBat   = Join-Path $scriptDir 'logon_setup.bat'
$launcher   = Join-Path $scriptDir 'logon_run_hidden.py'
$newTask    = 'MammoPdfDB Logon'
$legacyTask = 'MammoPdfDB Daily'

if (-not (Test-Path -LiteralPath $logonBat)) {
    throw "logon_setup.bat not found at: $logonBat"
}
if (-not (Test-Path -LiteralPath $launcher)) {
    throw "logon_run_hidden.py not found at: $launcher"
}

# --- Remove legacy daily task (ignore if absent) -----------------------------
if (Get-ScheduledTask -TaskName $legacyTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $legacyTask -Confirm:$false
    Write-Host "Removed legacy task: $legacyTask"
} else {
    Write-Host "Legacy task not present: $legacyTask (skipped)"
}

# --- (Re)register logon task -------------------------------------------------
if (Get-ScheduledTask -TaskName $newTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $newTask -Confirm:$false
    Write-Host "Removed existing task before re-create: $newTask"
}

# Run headless: launch pythonw.exe (GUI subsystem -> no console window) on
# logon_run_hidden.py, which re-runs logon_setup.bat with a hidden console.
# This kills the cmd flash that appeared every 2 h with the old cmd.exe action.
$pythonw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
if (-not $pythonw) {
    throw "pythonw.exe not found on PATH - install Python or add it to PATH."
}

$action    = New-ScheduledTaskAction `
    -Execute $pythonw `
    -Argument "`"$launcher`"" `
    -WorkingDirectory $scriptDir

# Two triggers so the index refreshes regardless of login habits:
#   - AtLogOn : fresh mounts + parse right after each logon (30 s NIC settle).
#   - Daily   : fires even on always-on sessions that never log off. A logon-only
#               task last fired 2026-05-15 on this workstation and let 8 PDFs pile
#               up unindexed. Repeats every 2 h from 07:30 to 19:30 to also catch
#               PDFs dropped mid-day.
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$triggerLogon.Delay = 'PT30S'   # 30-second delay so NIC/DHCP settle before mapping

$triggerDaily = New-ScheduledTaskTrigger -Daily -At 7:30am
# Cmdlet quirk: a -Daily trigger can't take -Repetition directly, so build the
# repetition on a throwaway -Once trigger and graft it on.
$triggerDaily.Repetition = (New-ScheduledTaskTrigger -Once -At 7:30am `
    -RepetitionInterval (New-TimeSpan -Hours 2) `
    -RepetitionDuration (New-TimeSpan -Hours 12)).Repetition

$trigger = @($triggerLogon, $triggerDaily)

$settings  = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $newTask `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal | Out-Null

Write-Host "Registered: $newTask"
Write-Host "  Trigger : At log on of $env:USERDOMAIN\$env:USERNAME (30 s delay)"
Write-Host "  Trigger : Daily 07:30, repeat every 2 h for 12 h (07:30-19:30)"
Write-Host "  Action  : pythonw `"$launcher`" (headless -> runs logon_setup.bat hidden)"
Write-Host ""
Write-Host "Verify with: Get-ScheduledTask -TaskName '$newTask' | Format-List *"
Write-Host "Trigger now: Start-ScheduledTask -TaskName '$newTask'"
