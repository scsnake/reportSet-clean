$code = @'
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
Add-Type -TypeDefinition $code
[Wallpaper]::SystemParametersInfo(0x0014, 0, "C:\Windows\Web\Wallpaper\Theme1\img4.jpg", 0x0001 -bor 0x0002)
Write-Host "Wallpaper updated successfully!"
