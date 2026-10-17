# Local configuration

`showLungCAD.ini.example` is the tracked reference for LungCAD settings.
It contains the workstation calibration and RDP address captured on 2026-10-07.
These values may need adjustment on another workstation.

`showLungCAD.ini` is a local runtime file.
Git ignores it because the application updates calibration values during use.

1. Preserve an existing `showLungCAD.ini` when updating this repository.
2. Create the runtime file from the sample only when it is absent:

```powershell
if (!(Test-Path -LiteralPath .\showLungCAD.ini)) {
    Copy-Item -LiteralPath .\showLungCAD.ini.example -Destination .\showLungCAD.ini
}
```

3. Adjust the RDP address and calibration for the workstation.
4. Update the sample deliberately when a useful reference setting changes.

`CH_RIS.ini` remains tracked.
Its shared `sendReportMode=send` setting saves and sends reports.
