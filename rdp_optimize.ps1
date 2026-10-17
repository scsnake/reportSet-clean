# RDP Optimization for "No Compromise" Image Viewing
# This script sets registry keys equivalent to Group Policies for high-fidelity RDP.

$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"

# Ensure the path exists
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

# 1. Enable AVC/H.264 hardware encoding
# Equivalent to: Configure H.264/AVC hardware encoding for Remote Desktop connections
Set-ItemProperty -Path $registryPath -Name "UserAVC" -Value 1 -Type DWord

# 2. Prioritize H.264/AVC 4:4:4 Graphics Mode
# Equivalent to: Prioritize H.264/AVC 444 graphics mode for Remote Desktop connections
Set-ItemProperty -Path $registryPath -Name "AllowHigherFourFourFourEncoding" -Value 1 -Type DWord

# 3. Set Visual Quality to Lossless
# Equivalent to: Configure image quality for RemoteFX Adaptive Graphics
# Value: 1 = High, 2 = Lossless
Set-ItemProperty -Path $registryPath -Name "VisualQuality" -Value 2 -Type DWord

# 4. Enable Hardware Graphics Adapter for all sessions
# Equivalent to: Use hardware graphics adapters for all Remote Desktop Services sessions
Set-ItemProperty -Path $registryPath -Name "HardwareGraphicsAdapter" -Value 1 -Type DWord

# 5. Enable UDP for Remote Desktop
# Equivalent to: Select RDP transport protocols (Use both UDP and TCP)
# Note: 0 = Both, 1 = TCP only. Default is 0, but setting explicitly ensures it's correct.
Set-ItemProperty -Path $registryPath -Name "SelectNetworkDetect" -Value 1 -Type DWord

Write-Host "RDP Optimizations applied successfully."
Write-Host "Please restart the computer or the 'Remote Desktop Services' (TermService) for changes to take effect."
