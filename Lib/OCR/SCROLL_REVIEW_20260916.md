# Lung CAD navigation review — 2026-09-16

The INFINITT branch of `showLungCAD.ahk` delegates navigation to
`INFINITT_OCR_Scroll.ahk`. The IMPAX branch is unchanged.

## Initial findings and changes

- Every viewport lookup constructed an `INFINITT_PACS` object. Its constructor
  runs `RefreshInfo` immediately and registers a repeating 500 ms timer holding
  the object. Repeated lookups accumulate polling work. Both viewport lookup
  paths now call the control-enumeration methods directly with an explicit HWND.
  A reload is required to clear timers created by the old process.
- Physical-position navigation guessed a 250-slice stack at 1.25 mm. The September
  16 log at 14:51:22 shows a real 242-slice difference planned as an eight-slice
  wrap in the opposite direction. SP now uses the direct physical distance.
  Image-number wrap shortcuts require a displayed total that contains both indices.
- Calibration rejected end-to-start stack transitions. It now probes again in the
  same direction to measure an adjacent pair. SP measures the actual interval on
  each navigation; displayed thickness and accession alone cannot identify the
  reconstruction interval. A matching displayed spacing preserves precision for
  0.625 mm intervals rendered with two decimals.
- At 14:52:46, one navigation overshot twice: a requested 70-slice drag moved 110
  slices, then a requested 38-slice drag moved 55. Its last logged keypress was at
  +106,250 ms. The next drag now uses the full measured pixels-per-slice response;
  persistent calibration blends that measurement for the next navigation. Learning
  uses actual endpoint displacement when a drag is clipped by the viewport.
- Fixed eight-slice correction batches caused many verification cycles. After a
  small batch confirms one slice per input, correction batches expand up to 48
  inputs, shrinking near the target. Batches retain per-input cancellation checks.
- Removed the 800–2,500 ms pause when snapping a rounded CAD coordinate to the
  nearest available slice. Cold OCR retries no longer multiply across every ROI
  enlargement.
- A stale or blank OCR read previously allowed more scrolling from the old
  position. Post-input reads now require a changed value stable across two reads,
  and final success gets a further confirmation. Failed or unsettled reads stop
  navigation. The script shows the crosshair only after a successful result.
- Removed speculative restoration of missing image digits from the optimized
  path, and decimal insertion that changed integer SP values such as -100 to -1.00.
- New requests wait for the previous run to release input. Cleanup runs on early
  returns and exceptions. A cooperative 15-second deadline is checked during
  navigation; synchronous external calls can finish after that deadline.

## Verification

Run from the repository root in PowerShell:

```powershell
& .\AutoHotkey.exe /iLib NUL /ErrorStdOut .\showLungCAD.ahk | Out-String
& .\AutoHotkey.exe /ErrorStdOut .\Lib\OCR\Test_ScrollMath.ahk | Out-String
& .\Lib\OCR\Test_ScrollReadings.ps1
```

AutoHotkey v1.1.33.02 load-only parsing passed. All 945 math checks and 20 OCR
reading/cancellation checks passed. The latter extract the current production
functions and supply simulated OCR frames; they do not start PACS or send input.
All changed/new AHK files retain UTF-8 BOM encoding.

No live PACS or RDP timing benchmark was performed. Existing local changes to
the viewer window matching and INI calibration were preserved. The executable
was not rebuilt and the running automation was not restarted. Reload the AHK
script, or rebuild/relaunch the executable if that is the deployed entry point.

## Follow-up: first Win+I jump

The user's subsequent live test at 15:12:52 failed on the first target. Calibration
was correct (1.25 mm), but both upward drags started at 20% viewport height and
were clipped to 258 pixels at the top edge. They left 119 slices to go. The next
eight Up events produced no changed SP during five reads over about 300 ms;
navigation stopped at 2,390 ms. The log cannot distinguish lost control focus
from a delayed or ignored input response.

The following seven Win+PgDn jumps reached their targets in 734–2,453 ms. These
are live measurements of the initial optimization, before this follow-up patch.

Upward drags now start at 80% height, with both directions confined to the
20–80% interior of the viewport. The failing case's 696-pixel request fits this
corridor without clipping. Before switching from drag to keys, the code restores
viewer activation and viewport keyboard focus. When all five initial reads show
the old position, it permits a bounded read-only settling grace of approximately
one second; no extra scroll input is sent during that wait. Normal changed reads
still return immediately after two matching observations.

Regression tests cover the recorded negative-origin viewport, long upward and
downward travel, clipping, and movement arriving after five unchanged frames.
Syntax and all 825 checks pass. This follow-up patch still needs a live Win+I test
after reload; the running script/executable was not restarted by the assistant.

## Local-login viewport calibration

The user confirmed these tests and configuration apply to a local Windows login.
At 15:17:46 the first jump took 8,047 ms: an 803-pixel drag advanced 110 slices,
then the code rejected the resulting 0.54518 ratio because of the old 0.40 ceiling.
It finished with 146 Up events. At 15:18:23 a shorter first jump took 2,000 ms
with one drag and seven Up events. These are measurements before this latest fix.

The latest implementation supersedes global INI learning described above:

- Local cursor movement uses SetCursorPos, the method that the historical M4
  test actually recorded as vertical/full-length. GetCursorPos verifies start
  and end positions for every drag. Cancellation, errors and exceptions release
  the button. DRAG ACTUAL PATH logs commanded versus observed travel.
- Movement count is Ceil(distance / step size), without the old 45-step cap.
  Thus an 803-pixel drag uses 67 steps at the configured 12-pixel maximum spacing.
- The first drag for a new control/direction is a probe of at most 24 estimated
  slices. The old local INI ratio only seeds this probe. Stable OCR movement and
  verified cursor travel determine the ratio for subsequent drags.
- Calibration is kept in memory for two minutes, keyed by study, parent/control,
  geometry, measured slice interval, direction, input settings and session/backend.
  Opposite directions and RDP have separate cache entries. INI ratios are no longer
  overwritten by individual viewport measurements.
- Valid responses above 0.40 are accepted. A rejected response invalidates its
  cache entry and permits a short re-probe when motion remains trustworthy and
  improves distance. Wrong-direction or unverifiable motion does not train it.
- The default rough-drag budget is six (explicit INI overrides still apply),
  with the existing overall deadline. Verified drags continue while at least ten
  slices remain, normally reserving three slices for precise keys. Keyboard
  fallback remains available if dragging fails or exhausts its budget.

All 965 automated checks pass. The simulations cover 48–500-slice jumps at the
sampled local response rates, finishing within nine keys and six drags. Pointer
tests use mocks; no live cursor or PACS input was sent. Reload the AHK script
before testing Win+I again. Actual local-PACS performance and endpoint verification
for this latest change still require that live test.
