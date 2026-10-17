# INFINITT OCR SP Capture Issue Notes

Date: 2026-05-08

## Context

`showLungCAD.ahk` uses `Lib/OCR/INFINITT_OCR_Scroll.ahk` to OCR INFINITT overlay text for:

- `Img` mode: current image number.
- `SP` mode: slice position and optional slice interval (`SL` / `sp5.00`).

The target viewport selection is currently correct for the local `1x1` combined viewport. The remaining issue is specific to SP OCR capture.

## Observed Problem

The AHK GUI overlay frame for the SP region can be positioned correctly using screen coordinates from AHK tools / visual inspection, but the bitmap captured from the same nominal screen rectangle does not correspond to the same visible GUI-framed region.

Specifically:

- GUI visualized SP region is correct.
- Captured SP bitmap is shifted superiorly relative to the GUI frame.
- This discrepancy does **not** occur for `Img` mode:
  - `Img` GUI frame and captured bitmap are consistent.
  - `Img` OCR region can be narrowed normally.

For SP mode, attempts to capture only the bottom approximately `70 px` where the `SL` / `SP` text appears still produced captures from the wrong vertical portion of the overlay. The capture backend effectively returned pixels from a more superior part of the left overlay block.

## Correct Visual Regions Found

Local viewport example:

```text
Viewport screen/client: [1922,-326,1225,1335]
```

Correct `Img` region:

```text
screen [3036,-250,109,48]
ratio 0.9094,0.0569,0.0890,0.0360
```

Correct broader SP overlay block:

```text
screen [1920,-326,136,176]
ratio -0.0016,0.0000,0.1110,0.1318
```

Desired OCR subregion for SP is the bottom part of this block:

```text
height about 70 px
contains:
SL : 5.00|sp5.00
SP : 61.00
```

## Attempts Made

### 1. DPI Awareness Changes

Global `DllCall("SetProcessDPIAware")` was removed from `INFINITT_OCR_Scroll.ahk` because it could make AHK GUI/debug coordinates differ from user-reported AHK tool coordinates.

Result:

- Helped make visual/debug coordinates consistent.
- Did **not** fix SP capture mismatch.
- Debug showed cases where logical and physical values were identical (`scale=1.0`), so the remaining SP problem was not explained by simple DPI scaling.

### 2. Logical vs Physical Coordinate Capture

The review helper was changed to capture both:

- logical screen rectangle
- `LogicalToPhysicalPointForPerMonitorDPI` converted rectangle

Result:

- Physical conversion expanded/shifted the capture and was not a clean fix.
- It did not explain why `Img` mode captured correctly while SP did not.
- Absolute coordinate conversion was rejected as an unsuitable solution.

### 3. Absolute Y Offset

A temporary `OCR_SCREEN_CAPTURE_Y_OFFSET := 110` was tried after observing that SP capture looked about `110 px` superior to the GUI frame.

Result:

- This was considered the wrong approach.
- It was monitor/layout-specific and did not explain the root cause.
- It was removed.

### 4. Capture Backend Changes

The OCR path was modified to try window-based OCR through the v2 bridge before screen-rect OCR:

- `OCR_WINDOW_RECT`
- `OCR.FromWindow(... mode: 5)`
- fallback to `mode: 4`
- fallback to screen rectangle OCR

Result:

- Added useful diagnostic path.
- Did not establish a reliable SP bottom-region capture solution.

### 5. Broad SP Region Plus Bottom Crop

The SP ratio was changed back to the broader stable left overlay block, and code was added to crop/read only the bottom `70 px` internally:

```ahk
OCR_SP_BOTTOM_READ_HEIGHT := 70
OCR_SPBottomRegion(region)
```

Result:

- Conceptually matches the desired region: bottom `SL/SP` lines inside the left overlay block.
- In practice, the SP capture mismatch persisted: captured pixels still did not reliably correspond to the visualized bottom GUI region.

## Current Assessment

The problem appears to be a capture-backend / rendering-coordinate discrepancy specific to the left SP overlay area in INFINITT.

Important observations:

- The SP GUI frame is correct.
- The SP captured bitmap is not the same region as the GUI frame.
- The issue is not seen for `Img`.
- Narrowing SP capture height to the bottom `70 px` is not reliable because the captured region itself is vertically inconsistent with the GUI frame.

This suggests the capture method is reading from a different rendered surface or coordinate basis for the left overlay area than the one used by AHK GUI visual overlays.

## Current Practical State

`Img` OCR region is usable.

SP OCR remains unresolved because the correct visual region cannot yet be captured reliably at the intended bottom-only height.

Current local ratios:

```ini
INFINITTOCRSPRatio=-0.0016,0.0000,0.1110,0.1318
INFINITTOCRImgRatio=0.9094,0.0569,0.0890,0.0360
```

SP parser behavior is prepared for text like:

```text
SL : 5.00|sp5.00
SP : 61.00
```

It should:

- parse final `SP` as slice position (`61.00`)
- parse `SL` / `sp5.00` as step size (`5.00`)

But this parsing only helps if the capture backend actually returns the bottom SP text.

## Recommended Next Investigation

Focus on capture method rather than ratio tuning:

1. Compare capture APIs specifically for the SP overlay:
   - GDI screen capture
   - PrintWindow
   - Windows Graphics Capture / Direct3D window capture
   - v2 `OCR.FromWindow` modes
2. Save side-by-side captures for the same visual GUI frame.
3. Identify which API captures the visible SP text exactly as framed.
4. Only then re-enable bottom-height narrowing.

Avoid further fixes based on absolute screen offsets unless they are strictly temporary diagnostics.
