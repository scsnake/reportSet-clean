# INFINITT PACS ROI to OCR Path

This note records the working path for OCR on fixed ROIs inside INFINITT PACS GPU-rendered viewports.

## Core OCR Stack

- `YCH_BMD.ahk` includes `Lib\OCR\INFINITT_OCR_BMD.ahk`.
- `YCH_BMD.ahk` also includes `Lib\OCR\INFINITT_OCR_Scroll.ahk` after the main `return`.
- `INFINITT_OCR_Scroll.ahk` includes `Lib\OCR\OCR_WinRT.ahk`.
- `OCR_WinRT.ahk` delegates recognition to the persistent AutoHotkey v2 worker `Lib\OCR\OCR_Bridge.ahk`.
- `OCR_Bridge.ahk` wraps `Lib\OCR\OCR.ahk`, which uses Windows WinRT OCR.

## Correct ROI Capture Path

For INFINITT image text overlays, prefer client-relative window OCR:

```ahk
text := _OWR_OcrWindowRectViaWorker(hwnd, clientX, clientY, width, height, "en-US")
```

This is the path used by `INFINITT_OCR_Scroll.ahk` in `OCR_ReadTextWindow()` and by the DXA BMD OCR path in `BMD_DXA_OCR_ReadText()`.

Why this path:

- INFINITT PACS draws its viewport through GPU/DirectX surfaces.
- GDI/screen bitmap captures often save black images, especially on non-primary or negative-coordinate monitors.
- The AutoHotkey v2 worker can capture the target window/client ROI directly using the `OCR.FromWindow()` path in `OCR.ahk`.

## Fallback Path

`INFINITT_OCR_Scroll.ahk` uses this fallback if the window ROI returns empty:

```ahk
cap := GetCaptureRectFromClient(hwnd, clientX, clientY, width, height)
text := OCR_WinRT_GetText(cap.screenX, cap.screenY, cap.screenW, cap.screenH, 0, 4)
```

This fallback is useful for ordinary screen-visible content, but it is less reliable for INFINITT PACS GPU viewports. In current DXA debugging, screen ROI OCR returned empty while window ROI OCR succeeded for most fields.

## DXA BMD Current Behavior

`BMD_DXA_OCR_ReadText(fieldName, region, hwnd)`:

- Runs the window/client ROI OCR first.
- For weak DXA fields, retries with field-specific padded client rectangles.
- Normalizes `tscore` text so a trailing decimal such as `0.` becomes `0.0`.
- Leaves production ROI calibration unchanged unless the user recalibrates.

`^!+h` runs `BMD_OCR_DebugROI_DXA()`, which now calls the same DXA OCR read path as `dxa0`. This makes the debug summary reflect the production read behavior.

## Current Known Issue

As of 2026-05-14, these DXA fields read correctly in ROI debug:

- `bmd`
- `fat_pct`
- `gender`
- `lean_kg_g`
- `tscore`

`almi` remains empty with the narrow calibrated ROI. The debug helper now adds:

- an ALMI 4x centered probe around the original ALMI ROI
- an ALMI fat-column probe using the `fat_pct` ROI `x/w`, extending from the `fat_pct` ROI top to the inferior viewport margin
- focused ALMI row probes around the original row, one row above, and several rows below toward the viewport bottom

These probes are diagnostic only and do not change production `dxa0` extraction.

## ALMI Debug Attempts

Observed ROI debug output showed:

- Original `almi` ROI: empty.
- 4x centered ALMI probe: read nearby lower-result text such as `17.0 13 14`, but not `7.68`.
- Fat-column probe from `fat_pct` `x/w` down to viewport bottom: read `18.9 41S 1.19 546 590 113 Result 17.0 vssue`, skipping visible `7.68`.
- Focused row probes:
  - current ALMI row wide/tall: empty
  - row above: `17.0`
  - row below / lower rows: empty
- OCR variant sweep over ALMI line probes:
  - mode 4/5, scale 4/6/8, grayscale, invert, and monochrome variants all failed to recover `7.68`.

Conclusion: the visible ALMI value is likely being dropped by WinRT OCR segmentation for this small table row. Production keeps the same window/client OCR mechanism. The configured ALMI ROI was extended +5 px right and +5 px inferior, then ALMI is still treated as an expected possible blank.

## Production DXA Workflow

`dxa0` should create the body-composition/BMD report from available OCR values. Missing values are left blank in the generated report instead of blocking report generation.

Output targets:

- report text is written to the simpleRIS Scintilla edit
- report text is written to the IE RIS `exam` textarea
- report text is placed on the clipboard
- after writing and flushing, `dxa0` activates/focuses the simpleRIS edit, then activates the IE RIS report window; if blanks remain, it returns the caret to the first simpleRIS blank slot

For missing DXA values:

- `BMD_BuildDXAReport()` records missing field insertion positions.
- `BMD_WriteResult()` selects the first missing-value position in the simpleRIS Scintilla editor.
- A tooltip tells the user which value to enter manually.
- If exactly one parsed OCR field is missing, `dxa0` first opens an `InputBox` for that value and highlights the calibrated PACS ROI with a filled semi-transparent rectangle plus label.
- If the user cancels that `InputBox`, the report is still generated with the value left blank, and the simpleRIS caret/tooltip fallback remains active.

This keeps the production path fast while preserving review visibility for known OCR blind spots such as ALMI.

ROI overlay behavior:

- Persistent red DXA ROI frames are hidden before OCR because the frames can be captured by WinRT OCR and corrupt tight ROIs.
- Production `dxa0` now draws the persistent red frames only once after OCR. Earlier versions showed them twice: a pre-OCR preview, then a post-OCR persistent redraw.

Formatting and impression wording:

- Whole-body BMD is formatted with three decimal places, e.g. `1.195`.
- Numeric OCR parsing preserves the cleaned decimal text before report formatting, so `1.195` is not collapsed to `1.20` by the script-level float format.
- Values entered through the single-missing-field `InputBox` are kept as typed in the report, e.g. ALMI `7.68` remains `7.68`.
- Normal ALMI contributes `No sarcopenia.` to the impression.
- Normal BMD impression is `Normal BMD.` rather than `Normal.`
- DXA text uses no space before `%` and includes spaces around comparison operators, e.g. `male > 23%`.
