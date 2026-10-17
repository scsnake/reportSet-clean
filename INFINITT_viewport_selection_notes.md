# INFINITT Viewport Selection Notes

Context: `showLungCAD.ahk` needs the real INFINITT image scrolling viewport for CAD nodule mouse positioning and OCR scroll regions. Earlier logic used `getViewportControl("leftmost")`, which selected a wrong small pane. Current test logic selects the largest `Afx:00400000:b:` control and works in the observed RDP layout.

## Observed RDP Controls

Correct viewport reference from manual screen coords:

- Viewport: `(1347,176)` to `(3022,1821)` => `[1347,176,1675,1645]`
- SL OCR: `(1346,330)` to `(1506,423)` => `[1346,330,160,93]`
- Img OCR: `(2897,268)` to `(3023,337)` => `[2897,268,126,69]`

RegionReview detected:

- Selected hwnd `0x71596`
- Class: `Afx:00400000:b:00000000:00000013:00000000`
- ClassNN: `Afx:00400000:b:00000000:00000013:000000005`
- Text: `WindowPane`
- Rect: `[1345,172,1679,1648]`
- Client: `[1345,172,1679,1648]`
- Sanity vs manual viewport: OK, delta `[-2,-4,+4,+3]`
- MSAA: role `用戶端`, name `WindowPane`, state `可設定焦點`, childCount `0`

Other `Afx:b` candidates:

- `...002`, text/name `SimpleView`, rect `[1090,853,600,509]`, childCount `0`
- `...003`, text/name `Thumnail`, rect `[1188,183,154,1518]`, childCount `1`

## Current Inference

INFINITT reuses the same `Afx:00400000:b:` class family for multiple viewer subpanes. The class alone is insufficient.

Observed distinguishing traits for the desired viewport:

- Text/name is `WindowPane`
- Largest area among `Afx:b` candidates
- Large image-like dimensions, roughly full viewport size
- MSAA childCount `0`, but this is not unique because `SimpleView` also has childCount `0`

Observed exclusion traits:

- `Thumnail` is thumbnail strip, not scrolling image viewport
- `SimpleView` is smaller auxiliary/simple preview pane, not target

## Candidate Algorithm To Design

Enumerate `pacs.getViewportControls(parent_hwnd)` / `Afx:00400000:b:` controls, then score:

1. Exclude hidden/nonvisible and controls smaller than a sane threshold.
2. Strongly exclude text/name matching `Thumnail`.
3. Prefer text/name matching `WindowPane`.
4. Prefer large area and image-like viewport dimensions.
5. Fallback to largest area.

Need to validate across local and RDP sessions before locking production logic.

## Ratio Notes

Local ratio config is not valid in current RDP layout.

Current RDP desired ratios from detected viewport `[1345,172,1679,1648]`:

- SP: `0.0006,0.0959,0.0953,0.0564`
- Img: `0.9244,0.0583,0.0750,0.0419`

From manual reference viewport `[1347,176,1675,1645]`:

- SP: approximately `0,0.0936,0.0955,0.0565`
- Img: `0.9254,0.0559,0.0752,0.0419`

Production currently has separate local/RDP ratio settings in `showLungCAD.ini`.
