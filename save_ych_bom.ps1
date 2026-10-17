$path = 'C:\Users\raduser\Documents\reportSet\YCH_mammo_Enh.ahk'
$content = Get-Content $path -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
$bom = [System.Text.Encoding]::UTF8.GetPreamble()
[System.IO.File]::WriteAllBytes($path, $bom + $bytes)
