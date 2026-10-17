$extensions = @('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tif', '.tiff')
foreach ($ext in $extensions) {
    # 1. Map extension to the PhotoViewer class
    $key = "HKCU:\Software\Classes\$ext"
    if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name '(default)' -Value 'PhotoViewer.FileAssoc.Tiff' -Force
    
    # 2. Try to remove the Windows 10 UserChoice hash constraint so it resets
    $userChoice = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
    if (Test-Path $userChoice) {
        Remove-Item -Path $userChoice -Force -Recurse -ErrorAction SilentlyContinue
    }
}
Write-Host "Associations updated!"
