# RIS Mammo / Breast US Annotation Session Summary

## Done

- Added Windows HTTP review path for the Ubuntu breast-US OCR service:
  - `study_client.py`
    - Calls `GET /healthz`, `GET /api/study?accession=...`, and `POST /api/process`.
    - Writes full `study_payload.json`, compact `study_status.txt`, and simplified `lesions_pending.json`.
    - Preserves the API distinctions between `not_found`, `busy`, `finding_kind=negative`, and non-`ocr_done` failure statuses.
  - `study_review_gui.ahk`
    - Detects accession from selected text/clipboard or active window title, with manual edit fallback.
    - Accepts RIS metadata arguments from `YCH_mammo_Enh.ahk`: `--accession`, `--chart-no`, `--study-date`, `--patient-name`, `--exam-name`, `--exam-time`.
    - Fetches/processes via `study_client.py`.
    - Shows RIS metadata, OCR state, lesions, and side-wide flags.
    - Distinguishes `NOT PARSED`, `BUSY`, `PARSED ERROR`, `NEGATIVE / NORMAL`, and `POSITIVE OCR`.
    - Clicking/changing a lesion row copies `clock/dist, size` to clipboard, e.g. `9-10/2.5, 2.7cm`.
    - When the lesion table has focus, `R` / `L` sets the selected row's side, saves `lesions_pending.json`, refreshes the row, and updates the clipboard.
    - Provides a per-lesion review editor for side, clock, distance, max size, finding type, and include/skip.
    - Blocks annotation launch while an included lesion still has `?` or `R?` side hints.
  - `ris_annotate.ahk`
    - Accepts an optional JSON path argument.
    - Parses the simplified HTTP-derived JSON fields.
    - Requires included `?` lesions to be changed to R/L before placement.
    - Updated button type choices to match the current calibrated `ris_button_map.ini` (`FCC`, `CYST`, `FA`, `LN`, scars, `SUS`, `DU`).
  - `YCH_mammo_Enh.ahk`
    - Registers `BreastUSOCR_OnAccNoChanged` as a C hospital RIS accession-change hook.
    - Automatically launches the OCR review GUI for breast-US studies only.
    - Also checks the current active RIS study shortly after `YCH_mammo_Enh.ahk` starts, so an already-open breast-US study is picked up.
    - Adds manual launcher hotkey `Ctrl+Alt+U` for the current RIS study.

- MacBook RIS-Horos server: reach it over HTTP only (`http://192.0.2.10:7788`).
  - Superseded 2026-10-14: the earlier SSH path (`scsnake@192.0.2.10` with the key
    `scsmbp_choffice`) is retired. The key is deleted. Do not use SSH.
  - Record: `SECURITY_HARDENING_PLAN.md` in the Mac repo `scsnake/ris-horos-sync`, Part 5.
  - Restart the server with `POST /restart`. `LaunchRisHoros.bat` does this.

- Confirmed `server.py` already supports pure Windows/RDP pixel-coordinate control:
  - `POST /rdp-mouse`
  - `POST /rdp-drag`
  - `GET /rdp-screen-info`
  - No RIS study metadata is needed for cursor movement.

- Confirmed `/rdp-screen-info` uses live Mac RDP window bounds and accepts `win_screen:{w,h}` override from Windows/AHK.

- Added `YCH_mammo_Enh.ahk` hook:
  - Includes `IsCurrentSessionRDP`.
  - On C hospital accession change, checks current `CH_RIS.examName` / `examtype`.
  - If breast ultrasound (`乳房超音波`, `US5B`, or breast/ultrasound English match) and current session is RDP, launches:
    - `CH scripts\LaunchRisHoros.bat`
  - Does nothing in local session.
  - Launches only once per `YCH_mammo_Enh.ahk` process.
  - Does not send study info to Mac server.

- Built `ris_annotate_calib_test.ahk`:
  - Finds RIS IE study page / Silverlight host.
  - Supports interactive calibration.
  - Uses host-relative pixel coordinates, not ratios.
  - Saves `PX_*` values in `ris_annotate_calib.ini`.
  - Keeps separate `Calibration_rdp` / `Calibration_local`.
  - Blue breast guides are bounding squares for the outer black circles, not
    quadrant annotations. Overlay GUI DPI scaling is disabled so physical-pixel
    guides remain square on the 200% RDP desktop.
  - Rejects/repairs a nipple-ring radius using the nipple-center separation;
    production independently blocks implausible radius calibration.
  - Hotkeys:
    - `F6`: calibrate/report/overlay
    - `F2`: interactive mode
    - `F3/F4`: cycle target
    - arrows / Shift+arrows / Ctrl+arrows: nudge
    - `Ctrl+Alt+LeftClick`: snap target to mouse
    - `Ctrl+Alt+S`: save calibration

- Updated `RIS_ANNOTATE_NOTES.md` with calibration harness notes.

- Verified AHK syntax with `/ErrorStdOut`:
  - `YCH_mammo_Enh.ahk`: OK via non-executing wrapper
  - `ris_annotate_calib_test.ahk`: OK
  - AHK files kept UTF-8 BOM where needed.

## Important Findings

- The Ubuntu HTTP service contract is documented in `/opt/breast_us_ocr/docs/windows_side_brief.md`.
- On this check, `gpu-host.example.invalid` was reachable by SSH, but no process was listening on `127.0.0.1:7205` / `gpu-host.example.invalid:7205`; Windows health check returned connection refused. Start the Flask service before live GUI testing.
- `side="?"` and `side_inferred=true` must be treated as review states, not final placement data. The GUI should keep the stored side unless the user edits it, but annotation placement requires an explicit R/L choice.

- IE/Silverlight annotation buttons are not exposed as individual UI Automation controls.
- IE DOM exposes the windowless Silverlight object rectangle, but not internal annotation buttons.
- Production now uses DOM-first discovery, live CSS-to-screen conversion,
  host-size-aware calibration scaling, visibility gates, and before/after
  `GetXML()` verification.
- Practical placement remains coordinate-based AHK interaction with per-lesion F12 approval.
- In RDP from Mac Retina, do not apply a Retina 2x factor in AHK.
- Use Windows logical screen pixels for AHK; Mac server maps those into Mac logical points through live RDP window bounds.

## Next Steps

0. Start or verify the Ubuntu Flask service on `gpu-host.example.invalid:7205`, then run:
   - `python windows\study_client.py health`
   - `python windows\study_client.py fetch --accession <ACC>`
   - `study_review_gui.ahk <ACC>`
1. Run `ris_annotate_calib_test.ahk` on a live breast ultrasound annotation page.
2. Press `F6`, then `F2`.
3. Calibrate these targets:
   - drawing box
   - RT/LT nipple centers
   - radius
   - RT/LT label anchors
   - button col0 / col1
   - button row0
   - button pitch
4. Save with `Ctrl+Alt+S`.
5. Review generated `ris_annotate_calib.ini`.
6. Production loads and scales saved `PX_*` calibration values. Re-save once
   with `Ctrl+Alt+S` to persist `BASE_CTRL_W` / `BASE_CTRL_H` for the current layout.
7. Add Mac-server-backed cursor move/click helper if RDP synthetic AHK click is unreliable:
   - call `/rdp-mouse` with Windows screen pixel coordinates and `win_screen`.
8. Test end-to-end annotation workflow:
   - open breast US RIS study
   - verify `LaunchRisHoros.bat` starts only in RDP
   - run calibration
   - dry-run lesion positions
   - only then enable real click placement.
