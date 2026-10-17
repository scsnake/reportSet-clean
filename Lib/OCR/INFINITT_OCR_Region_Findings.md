# INFINITT OCR Scroll Notes

## Current Status

`Lib\OCR\INFINITT_OCR_Scroll.ahk` can scroll an INFINITT series to a target `SP` slice position or `Img` instance number using Windows OCR.

The current RDP test path uses:

- Control/window-aspect capture, not visible screen capture.
- Shared RDP detection from `Lib\IsCurrentSessionRDP.ahk`.
- Fixed RDP ROIs relative to the INFINITT top-level window, converted to viewport-control margins.
- Direct-jump scrolling after one calibration wheel tick.
- Debug disabled by default.

Current important settings:

```ahk
OCR_DEBUG_MODE := false
OCR_DIRECT_SCROLL := true
OCR_SLEEP_CALIBRATE := 80
OCR_SLEEP_CLICK := 30
OCR_SLEEP_BATCH_SETTLE_IMG := 80
OCR_SLEEP_BATCH_SETTLE_SP := 80
OCR_IMG_MAX_BATCH := 100
```

## RDP ROIs

For the current RDP layout, the default top-window-relative regions are:

- `SP`: `(320,336)` to `(456,407)`, stored as `[320, 336, 136, 71]`
- `Img`: `(1848,271)` to `(1987,326)`, stored as `[1848, 271, 139, 55]`

When an INFINITT viewport control is available, these are converted to control-relative capture regions:

- `SP` touches the left margin of the viewport control.
- `Img` touches the right margin of the viewport control.

This avoids capturing other visible windows that may overlap the PACS viewer in an RDP session.

## Files Involved

- `Lib\OCR\INFINITT_OCR_Scroll.ahk`
  Main OCR scroll logic, calibration, direct jump, debug logging, ROI capture, OCR parsing.

- `Lib\OCR\OCR_WinRT.ahk`
  Windows OCR and bitmap capture helpers.

- `Lib\OCR\OCR_Bridge.ahk`
  AHK v2 bridge used to run Windows OCR from AHK v1 code.

- `Lib\INFINITT_PACS.ahk`
  INFINITT window/control helpers, including viewport control discovery.

- `Lib\IsCurrentSessionRDP.ahk`
  Shared helper for detecting whether the current Windows session is RDP.

- `CH scripts\RisHorosSync.ahk`
  Also uses the shared RDP detector.

## OCR Parsing Notes

`Img` OCR can confuse `I`, `l`, and `1`.

The parser tolerates labels like `lmg`, `Imq`, or `Image`, then normalizes digit-shaped characters in the value:

- `l`, `I`, `|` -> `1`
- `O`, `o` -> `0`

Example:

```text
lmg:lll -> Img 111
```

`SP` parsing accepts labels such as `SP`, `Pos`, `Position`, and a lone `P` label. This handles OCR outputs such as:

```text
SL 1.00 P : 93.00
```

## Scroll Behavior

The default mode is direct jump:

1. OCR the current value.
2. Send one calibration wheel tick.
3. OCR again to determine direction and step size.
4. Compute the direct wheel count to the target.
5. Send wheel ticks with `OCR_SLEEP_CLICK` between events.
6. Re-OCR and apply up to three direct correction passes if needed.

This is used for both `SP` and `Img`.

In testing, very fast wheel bursts caused INFINITT to drop events. The current smooth config uses:

```ahk
OCR_SLEEP_CLICK := 30
OCR_SLEEP_BATCH_SETTLE_SP := 80
OCR_SLEEP_BATCH_SETTLE_IMG := 80
```

## Debug Mode

Debug mode is controlled by:

```ahk
OCR_DEBUG_MODE := false
OCR_SAVE_ROI_BITMAPS := OCR_DEBUG_MODE
```

When enabled, the script logs timestamped steps to:

```text
Lib\OCR\OCR_Log.txt
```

and saves ROI captures under:

```text
Lib\OCR\debug_roi\
```

The timestamp log format includes total elapsed time and delta time between steps, which is useful for profiling slow OCR/capture/scroll stages.

## Latest RDP Test Notes

Known working scenarios during this session:

- `Img = 15` after restarting `G3PACS.exe`.
- `SP = 100.00` using control-level capture.
- `SP = 60.00` direct jump became smooth after keeping the current settle/click timing.

The current configuration should be kept as the baseline for RDP testing.
