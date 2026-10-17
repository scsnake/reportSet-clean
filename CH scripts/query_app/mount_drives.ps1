$drives = @{
    "P:" = "\\10.0.0.1\relexe"
    "Q:" = "\\10.0.0.1\vbtool6"
}

Write-Host "Checking network drives..." -ForegroundColor Cyan

foreach ($drive in $drives.Keys) {
    $path = $drives[$drive]
    $mounted = Get-PSDrive -Name $drive.Replace(":", "") -ErrorAction SilentlyContinue
    
    if ($mounted) {
        if ($mounted.DisplayRoot -ieq $path) {
            Write-Host "${drive} is correctly mounted to $path" -ForegroundColor Green
        } else {
            Write-Host "${drive} is mapped to $($mounted.DisplayRoot). Remapping to ${path}..." -ForegroundColor Yellow
            $net = New-Object -ComObject WScript.Network
            $net.RemoveNetworkDrive($drive, $true, $true)
            $net.MapNetworkDrive($drive, $path, $true)
            Write-Host "${drive} remapped successfully." -ForegroundColor Green
        }
    } else {
        Write-Host "Mounting ${drive} to ${path}..." -ForegroundColor Cyan
        try {
            $net = New-Object -ComObject WScript.Network
            $net.MapNetworkDrive($drive, $path, $true)
            Write-Host "${drive} mounted successfully." -ForegroundColor Green
        } catch {
            $msg = $_.Exception.Message
            Write-Error "Failed to mount ${drive}: ${msg}"
        }
    }
}
Write-Host "Done."
