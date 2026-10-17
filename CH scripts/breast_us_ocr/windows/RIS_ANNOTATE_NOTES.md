# ris_annotate.ahk — IE Auto-Click Annotation Notes

## Overview

`study_review_gui.ahk` is the Windows entry point for the Ubuntu HTTP service.
It fetches or triggers OCR for the current accession, renders the result for
review, and writes `lesions_pending.json`.

`ris_annotate.ahk` then drives semi-automatic placement of reviewed breast US
findings on the IE/Silverlight RIS annotation canvas.

```
Ubuntu: DICOM retrieve -> OCR -> parse -> lesions.db -> HTTP API :7205
          ↓  (study_client.py)
Windows: study_review_gui.ahk -> lesions_pending.json -> ris_annotate.ahk
```

The older `export_lesions.py` SQLite path is now fallback-only. The preferred
contract is the HTTP API documented in
`/opt/breast_us_ocr/docs/windows_side_brief.md` on `gpu-host.example.invalid`.

---

## Workflow (user perspective)

| Key | Phase | Action |
|-----|-------|--------|
| F8  | Dry-run | Calibrate canvas, trace clock positions with mouse — no clicks |
| F9  | Annotate | Full run: calibrate → load JSON → Review GUI → semi-auto loop |
| F12 | (during loop) | Confirm: place marker at current mouse position |
| F11 | (during loop) | Skip current lesion |
| F10 | (during loop) | Abort remaining lesions |

Production safety behavior:

- Preview never selects a Silverlight button and never changes canvas state.
- The reviewed accession must exactly match the open RIS `referno`; it is
  checked before review and again immediately before every F12 click.
- F12 reacquires the live DOM rectangle and recalibrates before clicking.
- A target or finding button outside the visible IE content area is blocked.
- Canvas XML is captured before placement and checked afterward. The marker
  count and expected label count must both increase or the run stops.
- The script never saves or sends the RIS report.

---

## HTTP Review GUI

`study_review_gui.ahk`:

| Key / Button | Action |
|--------------|--------|
| Detect | Copy selected RIS text or read active window title and extract a 10-15 digit accession |
| Fetch / F6 | `GET /api/study?accession=...` through `study_client.py` |
| Process / F7 | `POST /api/process` when the API returned `not_found` |
| Review/Edit | Edit side, clock, distance, size, type, and include flag |
| Annotate RIS / F9 | Launch `ris_annotate.ahk` with the reviewed JSON |

`study_client.py` writes three files beside the scripts:

| File | Purpose |
|------|---------|
| `study_payload.json` | Full HTTP response for debugging |
| `study_status.txt` | Compact status text for the AHK GUI |
| `lesions_pending.json` | Simplified JSON consumed by `ris_annotate.ahk` |

HTTP handling:

- `404 status=not_found`: GUI shows the "Process" path.
- `409 status=busy`: GUI warns that another `/api/process` is running.
- `run_status=ocr_done` + `finding_kind=negative`: verified clean study, not missing data.
- Non-`ocr_done` statuses (`pacs_not_found`, `pacs_move_failed`, `pacs_incomplete`, `dicom_unreadable`) are surfaced through `study_status.txt` and `error_detail`.

Side handling:

- `side_inferred=true` is shown as `R?` / `L?`.
- `side="?"` is common on icon-only GE studies and must be changed to `R` or `L`, or the lesion must be unchecked, before annotation.
- `ris_annotate.ahk` now also blocks included `?` lesions in its own review window so they cannot silently map to the LT circle.

---

## Calibration Test Harness

`ris_annotate_calib_test.ahk` is a separate read-only calibration script for the
IE/Silverlight annotation canvas.

| Key | Action |
|-----|--------|
| F6  | Find IE study page, measure the Silverlight DOM object/native host, scan breast circles, save/copy calibration report, and draw overlays |
| F7  | Copy the last calibration report to clipboard |
| F8  | Move through RT/LT text anchors, nipple centers, circle edges, and right-side button centers without clicking |
| F9  | Move through sample lesion coordinates, including axillary placements, without clicking |
| F10 | Clear overlays |
| F2  | Toggle interactive calibration mode |
| F3/F4 | Cycle the editable target: drawing box, RT/LT centers, radius, labels, button columns, row-0, row pitch |
| Arrows | Nudge selected target by 1 px; `Shift+Arrows` = 10 px; `Ctrl+Arrows` = 50 px |
| Ctrl+Alt+LeftClick | Snap selected target to the mouse position |
| Ctrl+Alt+S | Save host-relative pixel calibration to `ris_annotate_calib.ini` |
| Esc | Exit |

Output is written to `ris_annotate_calib_last.txt` beside the script.  The test
converts screenshot-derived anchors into host-relative pixels first, then refines
the two breast circles with dark-pixel scanning when the live canvas is visible.
Saved values in `ris_annotate_calib.ini` override screenshot-derived defaults on
the next run. The INI uses separate `Calibration_rdp` and `Calibration_local`
sections. New saves also record `BASE_CTRL_W` / `BASE_CTRL_H`; production scales
all `PX_*` values to the current live host rectangle. Legacy RDP calibration is
treated as having been captured against the known 1155×1162 host. No Mac Retina
factor is applied manually.

Overlay legend:

- Red cross: RT/LT nipple center.
- Blue square: bounding square for the calibrated **outer breast circle**. Its
  four sides should be tangent to the outer black circumference at 12/3/6/9.
- Orange cross: RT/LT text anchor.
- Green rectangle: estimated drawing area.
- Blue crosses at the right: finding-button anchors.

The blue square is not an anatomical quadrant or saved RIS annotation. A radius
near the small nipple/areola ring is invalid; the harness repairs/rejects it and
production refuses to use it. Overlay GUIs disable AHK DPI scaling because their
coordinates are already physical screen pixels.

---

## IE Window Detection

- Preferred path: enumerate IE through `Shell.Application`, find the report URL,
  locate the `application/x-silverlight-2` DOM object, and convert its
  `getBoundingClientRect()` from DOM pixels to AHK screen pixels.
- `getBoundingClientRect()` is already viewport-relative; page scroll must not
  be subtracted a second time.
- Fallback path: use a native `SilverlightControlHost` child window when an older
  page exposes one.
- Production retains the IE document reference so it can call
  `appHost.Content.MainPage.GetXML()` for post-click verification.

---

## Canvas Layout (proportional constants — **need live verification**)

```
┌────────────────────────────────────────────────────────┐
│  Tab bar  (~7.5% height)                               │
├──────────────────────────────────────────┬─────────────┤
│                                          │  Button col │
│   Drawing area                           │  (~17% w)   │
│   RT circle   |   LT circle              │  rows 0–N   │
│                                          │             │
└──────────────────────────────────────────┴─────────────┘
  left border ~1.5%                   right border ~1.5%
  bottom border ~1.5%
```

Constants in `_Calibrate()` (all fractions of Silverlight control dimensions):

| Variable        | Current value | Meaning |
|-----------------|---------------|---------|
| `g_draw_x` offset | 1.5%  | Left draw margin |
| `g_draw_y` offset | 7.5%  | Top (tab bar height) |
| `g_draw_w` fraction | 82.5% | Draw width (rest = button col) |
| `g_draw_h` fraction | 91.0% | Draw height |
| `g_btn_c0x` | 89.3% | Button col-0 center x |
| `g_btn_c1x` | 95.2% | Button col-1 center x |
| `g_btn_r0y` | 12.7% | Row-0 button center y |
| `g_btn_rh`  | 7.6%  | Row pitch (px per row) |

**These are estimates from screenshot analysis.  Calibrate by running F8 and
checking the ToolTip positions, then adjusting fractions until markers land
correctly on the canvas.**

---

## Circle Detection (PixelSearch)

`_ScanCircle()` locates each breast circle by scanning for dark pixels (`r < 60`)
along a vertical hint line and a horizontal mid-line:

1. Scan down from `hintX` to find `topY` of circle outline
2. Scan up to find `botY`
3. Scan across at `midY` to find `leftX`, `rightX`
4. `cx = (leftX+rightX)/2`, `cy = (topY+botY)/2`, `r = (rightX-leftX)/2`

Fallback (if no dark pixels found): uses hard-coded fractions:

| | RT | LT |
|-|----|----|
| hintX | 35.5% of draw width | 68.5% |
| cy fallback | 24.2% draw height | 24.2% |
| r fallback | 18.7% draw width | 18.1% |

**Action needed:** open a study on the live canvas, run F8, and verify the
ToolTip says "RT nipple (r=Npx)" at the correct nipple center.  Adjust
`PIX_DARK` (default 60) if circle outline is light grey instead of black.

---

## Clock → Screen Coordinate Formula

Same formula for both breasts (frontal-view diagram, no side-specific mirroring):

```
angle  = clock_avg × π/6         (12=top, 3=right, 6=bottom, 9=left)
x      = cx + dist_px × sin(angle)
y      = cy − dist_px × cos(angle)
dist_px = dist_cm × g_scale       (g_scale = g_radius / BREAST_RADIUS_CM)
```

`BREAST_RADIUS_CM = 5.5` is the assumed real-world radius of the drawn circle.
If the on-screen circles represent a different radius, update this constant.

Axillary nodes are placed outside the circle at UOQ angle:
- RT: clock 10.5, dist = radius × 1.20
- LT: clock  1.5, dist = radius × 1.20

**Calibration check:** F8 dry-run traces RT clock 12/3/6/9 at 3 cm.  Watch
the mouse; it should trace a diamond pattern centred on the RT nipple at
roughly 55% of the circle's radius.

---

## Finding Types & Button Grid

`ris_button_map_test.ahk` is a separate button inventory harness. It loads
`ris_annotate_calib.ini`, draws row/column overlays for the right-side button
anchors, and provides an editor for revising labels. It saves the map to
`ris_button_map.ini` and writes/copies a report to `ris_button_map_last.txt`.

| Key | Action |
|-----|--------|
| F6  | Find IE/Silverlight host, load calibration, draw button overlays |
| F7  | Open editable button-label GUI |
| F8  | Walk through button anchors with mouse only, no clicks |
| F9  | Save current map and copy report |
| F10 | Clear overlays |
| Esc | Exit |

```
Type  | Clinical meaning           | BTN_*   | row | col
------|----------------------------|---------|-----|----
FCC   | Fibrocystic change / cyst  | BTN_FCC |  6  |  0
FA    | Fibroadenoma               | BTN_FA  |  2  |  0
SUS   | Suspicious (BIRADS 4-5)    | BTN_SUS |  3  |  0
DU    | Ductal ectasia             | BTN_DU  |  4  |  0
SC-H  | Scar, horizontal           | BTN_SC_H|  7  |  0
SC-V  | Scar, vertical             | BTN_SC_V|  7  |  1
SC-O  | Scar, oblique              | BTN_SC_O|  8  |  0
```

Button inventory from the calibrated live canvas:

```
row | col0                            | col1
----|---------------------------------|--------------------------------
0   | SCAR_DIAGONAL_SLASH            | SCAR_DIAGONAL_BACKSLASH
1   | SCAR_VERTICAL                  | SCAR_HORIZONTAL
2   | FA_LARGE                       | FA_SMALL
3   | SUS_LARGE                      | SUS_SMALL
4   | COARSE_CALCIFICATION_LARGE     | COARSE_CALCIFICATION_SMALL
5   | FCC_LARGE                      | FCC_SMALL
6   | CYST_LARGE                     | CYST_SMALL
7   | DUCT_ECTASIA_HORIZONTAL        | DUCT_ECTASIA_VERTICAL
8   | DUCT_ECTASIA_DIAGONAL_SLASH    | DUCT_ECTASIA_DIAGONAL_BACKSLASH
9   | INTRADUCTAL_PAPILLOMA          | COMPLEX_CYST
10  | DUCT_ECTASIA                   | MICROCALCIFICATION
11  | none                            | LN
```

Button crosses and orange label crosses mark calibrated clickable anchors, not
necessarily the visual center of the icon/text. RT/LT nipple red crosses mark
the actual nipple centers.

To calibrate:
1. Open the annotation canvas in IE
2. Run `ris_annotate_calib_test.ahk`
3. Press `F6`, then `F2`
4. Use `F3/F4` to cycle targets, drag/coarse-place, arrows/fine-place
5. Press `Ctrl+Alt+S`; production `ris_annotate.ahk` loads `ris_annotate_calib.ini`
6. Run F8 dry-run and verify `_SelectButton` clicks land on the correct icons

---

## Review GUI

Before annotation begins, a per-lesion review window is shown:

- Each lesion row shows: `[N] side clock/dist, size`
- DropDownList: `FCC | FA | SC-H | SC-V | SC-O | SUS | DU` (default FCC; pre-filled from JSON type hint)
- CheckBox: Include (checked by default; uncheck to skip that lesion)

On **Proceed**, the selected type and include flag are written back to
`g_lesions[i].type` and `g_lesions[i].include`.  `_ProcessNext()` skips any
lesion with `include = 0`.

---

## JSON Input Format (`lesions_pending.json`)

Produced by `study_client.py` from the Ubuntu HTTP API:

```json
{
  "patient_id": "0000000001",
  "study_date": "20260514",
  "accession":  "T0000000001",
  "study_uid":  "1.2.410...",
  "run_status": "ocr_done",
  "finding_kind": "positive",
  "lesions": [
    {
      "side":        "R",
      "side_hint":   "R?",
      "side_inferred": true,
      "region":      "",
      "clock_start": 10,
      "clock_end":   null,
      "dist_cm":     2.5,
      "max_dim_mm":  12.0,
      "type":        "CYST",
      "axillary":    false,
      "flags_text":  "CYST",
      "frame_indices_text": "1"
    }
  ]
}
```

`type` in JSON is a hint/default; user can override in the Review GUI.

---

## Guarded Calibration and Test Sequence

Perform these steps on a test/dummy report before the first clinical placement
after a layout or RDP-resolution change:

1. Open the breast-US report page and keep the diagram visible.
2. Run `ris_annotate_calib_test.ahk` and press F6. Confirm the report identifies
   the 570×580 DOM object (about 1155×1162 AHK pixels at 2× DPI).
3. Press F8. Confirm RT/LT nipple, circle-edge, label, and button anchors using
   mouse movement only.
4. Press F9. Confirm sample 12/3/6/9 and axillary targets. This also moves only.
5. If correction is needed, use F2, F3/F4, arrows, and Ctrl+Alt+LeftClick; save
   with Ctrl+Alt+S. The saved host dimensions make later scaling deterministic.
6. Run `ris_button_map_test.ahk`: F6 draws overlays and F8 walks every button
   without clicking. Confirm especially FCC, CYST, FA, SUS, DU, and LN.
7. Run production F8 and confirm the final dry-run path.
8. On a disposable report, use one test lesion. Press F12 once and confirm the
   marker and label appear. A successful placement advances only after XML
   verification; a failure stops the run for manual inspection.
9. Resize or reconnect RDP, repeat steps 2–3, and confirm anchors rescale rather
   than retaining the previous raw pixel positions.

## Remaining Clinical Validation

- Confirm the clock/distance scale on RT and LT using known 12/3/6/9 targets.
- Confirm axillary placement for both sides.
- Confirm every clinically used finding button, especially LN at row 11.
- Confirm the label format accepted by the clinical workflow.
- Test a deliberate clipped-canvas case and confirm no click is sent.
