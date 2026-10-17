# Breast Ultrasound OCR & Annotation Workflow — Plan

**Date:** 2026-05-18  
**Location:** `CH scripts/breast_us_ocr/`  
**Status:** Planning

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Ubuntu (PACS/processing node)                              │
│                                                             │
│  PACS ──DICOM-C-MOVE──► dicom_retrieve.py                  │
│                               │                             │
│                          pixel extraction                   │
│                               │                             │
│                          ocr_extract.py ── EasyOCR          │
│                               │                             │
│                          parse_us_text.py                   │
│                               │                             │
│                          lesion_db.py (SQLite)              │
│                               │                             │
│              SMB share / SSH / REST API                     │
└───────────────────────────────┼─────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────┐
│  Windows (reporting workstation)                            │
│                                                             │
│  read_lesion_db.py  ──► compare_lesions.py                  │
│                               │                             │
│                         comparison_gui.ahk (AHK GUI)        │
│                               │                             │
│                         ris_annotate.ahk (IE Silverlight)   │
│                                                             │
│  [Fallback only — if Ubuntu pipeline unavailable]           │
│  pacs_capture.ahk  ──► (feeds same OCR pipeline via SSH)   │
└─────────────────────────────────────────────────────────────┘
```

**Key principle:** Ubuntu owns all the heavy lifting (DICOM I/O, OCR, parsing, DB). Windows only consumes the finished DB and drives the UI/RIS annotation.

---

## Proposed Directory Structure

```
CH scripts/breast_us_ocr/
├── PLAN.md                    ← this file
│
│   ── Ubuntu-side (deploy to Ubuntu) ──
├── ubuntu/
│   ├── dicom_retrieve.py      ← DICOM C-MOVE from PACS to local
│   ├── ocr_extract.py         ← pixel extraction + EasyOCR per frame
│   ├── parse_us_text.py       ← structured parsing of raw OCR output
│   ├── lesion_db.py           ← SQLite schema + insert/query helpers
│   ├── pipeline.py            ← orchestrator: retrieve → OCR → parse → store
│   └── serve_db.py            ← optional: tiny Flask REST API for Windows client
│
│   ── Windows-side (AHK + Python) ──
├── windows/
│   ├── read_lesion_db.py      ← read SQLite (via SMB mount or SSH copy)
│   ├── compare_lesions.py     ← matching + progression logic
│   ├── comparison_gui.ahk     ← AHK GUI: side-by-side lesion table
│   ├── ris_annotate.ahk       ← IE RIS Silverlight mouse automation
│   └── pacs_capture.ahk       ← fallback: INFINITT viewport screenshot loop
│
└── shared/
    └── schema.sql             ← canonical DB schema (used by both sides)
```

---

## Step-by-Step Plan & Feasibility

---

### Step 1 — Ubuntu: DICOM Retrieval

**Goal:** Pull DICOM files for a given accession / study from the PACS into a local working directory on Ubuntu.

**Approach:**
- Use `pynetdicom` (`AE.send_c_move`) or call `movescu` (DCMTK) targeting the PACS C-MOVE SCP
- Trigger can be: cron on new MG study arrival, or on-demand when Windows client requests a study
- Store files under `/data/breast_us/<study_uid>/` or equivalent

**Feasibility: HIGH** — standard DICOM workflow; `pynetdicom` or DCMTK both work reliably on Ubuntu.

**Key question:** Does the Ubuntu machine already have a working DICOM node (AE title + port) registered with the PACS? If yes, this is trivial wiring.

---

### Step 2 — Ubuntu: OCR Extraction (`ocr_extract.py`)

**Goal:** Render each DICOM frame to a pixel array and OCR the burned-in text overlays.

**Approach:**
- `pydicom` + `pillow` for pixel extraction; `python-gdcm` for compressed transfer syntaxes (JPEG 2000, RLE — common on ultrasound)
- Preprocess per frame: convert to grayscale, apply adaptive threshold (Otsu) to maximize text contrast on dark ultrasound background
- **EasyOCR** preferred over Tesseract: handles mixed English/digit/Chinese without training data, GPU-optional
- Run on **region crops** rather than full frame to reduce noise:

| Region | Content | Crop heuristic |
|---|---|---|
| Bottom-left quadrant | Measured lengths (mm/cm), may be multiple | `img[h*0.75:h, 0:w//2]` |
| Bottom-center strip | Lesion position (`9-10/2.5`) — may be absent | `img[h*0.80:h, w*0.30:w*0.70]` |
| Top strip | Side label (R/L), probe orientation (SAG/TRV/RAD) | `img[0:h*0.15, :]` |

- For caliper marks (`+` symbols): **OpenCV template matching** against a small `+` template per machine model — not OCR. Output: count and approximate coordinates of each caliper pair.
- Handle multi-frame DICOM (cine): iterate all frames, deduplicate by perceptual hash (frames with identical image content kept once).

**Feasibility: HIGH for text overlays, MODERATE for caliper detection**
- Burned-in ultrasound text is typically white on black — OCR-friendly after threshold
- Caliper `+` icons vary by machine; need one template image per machine type
- `python-gdcm` installation on Ubuntu via `apt install python3-gdcm` is reliable

**Key risks:**
- Some machines render probe label in non-standard corners — ROI heuristics need sample images to validate
- OCR may merge nearby text blocks; post-processing must split on whitespace patterns

---

### Step 3 — Ubuntu: Text Parsing (`parse_us_text.py`)

**Goal:** Convert raw EasyOCR strings into structured per-frame records.

**Patterns:**

| Field | Example | Regex |
|---|---|---|
| Side | `R`, `L`, `右`, `左` | `^[RLrl右左]$` in top-strip tokens |
| Probe orientation | `SAG`, `TRV`, `LONG`, `RAD`, `ANTI`, `OBL` | keyword set lookup |
| Lesion clock | `9-10`, `9`, `10-11` | `(\d{1,2})(?:-(\d{1,2}))?` |
| Distance from nipple | `2.5`, `3cm` | `([\d.]+)\s*cm` |
| Combined annotation | `9-10/2.5` | `(\d{1,2}(?:-\d{1,2})?)/([\d.]+)` |
| Measurement | `13mm`, `1.3cm`, `23x14mm` | `([\d.]+)\s*(?:x\s*[\d.]+\s*)?(?:mm|cm)` |

**Output per study (JSON, also written to DB):**
```json
{
  "study_uid": "...",
  "patient_id": "...",
  "study_date": "2026-05-18",
  "accession": "...",
  "frames": [
    {
      "frame_index": 0,
      "side": "R",
      "orientation": "TRANS",
      "lesion_pos": { "clock_start": 9, "clock_end": 10, "dist_cm": 2.5 },
      "measurements_mm": [13.0, 8.5],
      "caliper_count": 2
    }
  ],
  "lesions": [
    {
      "side": "R", "clock_start": 9, "clock_end": 10,
      "dist_cm": 2.5, "max_dim_mm": 13.0, "dims_mm": [13.0, 8.5],
      "frame_indices": [0, 1, 2]
    }
  ]
}
```

Lesion consolidation: frames with the same `side + clock + dist` within tolerance are merged into a single lesion record; dimensions taken from the frame with the largest measurement.

**Feasibility: HIGH**

---

### Step 4 — Ubuntu: Lesion Database (`lesion_db.py`)

**Goal:** SQLite store on Ubuntu; Windows reads it via SMB share or `scp`.

**Schema (`shared/schema.sql`):**
```sql
CREATE TABLE studies (
  study_uid   TEXT PRIMARY KEY,
  patient_id  TEXT NOT NULL,
  study_date  TEXT NOT NULL,   -- YYYY-MM-DD
  accession   TEXT,
  processed_at TEXT
);

CREATE TABLE lesions (
  id           INTEGER PRIMARY KEY,
  study_uid    TEXT REFERENCES studies(study_uid),
  side         TEXT CHECK(side IN ('R','L')),
  clock_start  REAL,           -- e.g. 9.0
  clock_end    REAL,           -- e.g. 10.0, NULL if single
  dist_cm      REAL,
  max_dim_mm   REAL,
  dims_json    TEXT,           -- JSON array of all measurements
  orientation  TEXT,
  frame_indices TEXT           -- JSON array of frame numbers
);

CREATE INDEX idx_lesions_patient ON lesions(study_uid);
CREATE INDEX idx_studies_patient ON studies(patient_id, study_date);
```

**Windows access options (pick one):**
| Method | Pros | Cons |
|---|---|---|
| SMB share (existing `RIS_PACS_share`) | No extra software, already set up | DB file locked during write |
| `scp` on demand | Simple, no lock contention | Needs SSH key auth on Windows |
| Flask REST API on Ubuntu (`serve_db.py`) | No file sharing, query by patient_id | Extra service to maintain |

**Recommended:** SMB share (already exists in the project) with a write-lock-safe approach — Ubuntu writes to a temp file and renames atomically; Windows reads the committed file.

**Feasibility: HIGH**

---

### Step 5 — Ubuntu: Pipeline Orchestrator (`pipeline.py`)

**Goal:** Single entry point: given accession or patient ID, run retrieve → OCR → parse → store.

```
python pipeline.py --accession 20260518XXXX
python pipeline.py --patient_id 0000000001 --latest
```

Can be triggered:
- By a cron job watching a DICOM incoming directory (inotifywait)
- By an AHK hotkey on Windows that SSH-executes the pipeline remotely (`plink.exe` or existing SSH setup)

**Feasibility: HIGH**

---

### Step 6 — Windows: Fallback PACS Capture (`pacs_capture.ahk`)

**Goal:** When Ubuntu pipeline is unavailable, capture frames directly from the INFINITT PACS viewport on the Windows machine and send them to Ubuntu for OCR via SSH, OR run a local lightweight OCR.

**Approach:**
- AHK scrolls through the current study in INFINITT (reuse `INFINITT_OCR_RegionReview.ahk` coordinate detection)
- Screenshot each frame via `BitBlt` DllCall → save to temp BMP
- Either: `scp` batch to Ubuntu and trigger `pipeline.py --from-bmp` remotely
- Or: run a minimal local Python OCR (same `ocr_extract.py` but accepting BMP input) — Python is available on Windows

**Feasibility: MODERATE** — same as before; the Ubuntu-side OCR code now works on BMP input too with minimal changes, which removes the need for a separate Windows OCR stack.

---

### Step 7 — Windows: Lesion Comparison (`compare_lesions.py`)

**Goal:** Load current + prior studies from DB and match lesions.

**Algorithm unchanged from original plan:**
- Clock center: `(clock_start + clock_end) / 2`
- Clock distance: `min(abs(a-b), 12-abs(a-b))` to handle wrap-around (e.g. 11 vs 1)
- Tight match: clock ≤ 0.5, dist ≤ 0.5 cm → "same lesion"
- Loose match: clock ≤ 1.0, dist ≤ 1.0 cm → "possible same, verify"
- Progression: stable ±2 mm, growing >+2 mm, shrinking <−2 mm

**Feasibility: HIGH**

---

### Step 8 — Windows: Comparison GUI (`comparison_gui.ahk`)

**Goal:** AHK GUI showing matched lesions, status, and largest.

Layout (unchanged from original plan) — see AHK `Gui` + `ListView`.  
Alternative: `compare_lesions.py` writes an HTML file → open in default browser (easier color coding, no AHK ListView color complexity).

**Feasibility: HIGH**

---

### Step 9 — Windows: IE RIS Annotation (`ris_annotate.ahk`)

**Goal:** Mouse-simulate lesion marker placement on the Silverlight breast diagram.

**Unchanged from original plan.** Key points:
- Calibrate canvas pixel bounds once (hardcode or detect via reference pixel color)
- `clockToXY()` maps clock + dist_cm to canvas pixel
- Dry-run mode: move mouse without clicking for user verification
- One-lesion-at-a-time with confirmation prompt is safer than fully automated batch

**Feasibility: LOW-MODERATE** — still the highest-risk step; unchanged assessment.

---

### Step 2 — Structured Text Parsing

**Goal:** Parse raw OCR strings into structured fields.

**Patterns to extract:**

| Field | Example raw text | Regex / rule |
|---|---|---|
| Side | `R`, `L`, `右`, `左` | `[RLrl右左]` at start or in label region |
| Probe orientation | `SAG`, `TRV`, `LONG`, `TRANS`, `OBL`, `RAD`, `ANTI` | keyword lookup |
| Lesion clock position | `9-10`, `9`, `10-11` | `\d{1,2}(?:-\d{1,2})?` |
| Distance from nipple | `2.5`, `3`, `2.5cm` | `[\d.]+\s*cm` |
| Lesion annotation combined | `9-10/2.5` | `(\d{1,2}(?:-\d{1,2})?)/([\d.]+)` |
| Measurement | `13mm`, `1.3cm`, `23 x 14` | `[\d.]+\s*(?:mm|cm)` |
| Caliper count | two `+` icons in image | image processing output |

**Output schema (per frame):**
```json
{
  "frame_index": 0,
  "side": "R",
  "orientation": "TRANS",
  "lesion_pos": { "clock_start": 9, "clock_end": 10, "dist_cm": 2.5 },
  "measurements_mm": [13.0, 8.5],
  "caliper_count": 2,
  "raw_ocr": "..."
}
```

**Feasibility: HIGH**
- Patterns are well-defined and regex-parseable
- OCR errors (0→O, 1→I) need post-correction for numeric fields
- Chinese side labels (`右`/`左`) must be handled — EasyOCR supports this natively

---

### Step 3 — Lesion Database (SQLite)

**Goal:** Persist parsed findings per patient per study for future comparison.

**Schema:**
```sql
CREATE TABLE studies (
  study_id TEXT PRIMARY KEY,
  patient_id TEXT,
  study_date TEXT,
  accession TEXT
);

CREATE TABLE lesions (
  id INTEGER PRIMARY KEY,
  study_id TEXT,
  side TEXT,           -- R or L
  clock_start REAL,    -- 9
  clock_end REAL,      -- 10 (NULL if single clock)
  dist_cm REAL,        -- 2.5
  max_dim_mm REAL,     -- largest measured dimension
  dims_json TEXT,      -- all measurements as JSON array
  orientation TEXT,
  frame_indices TEXT   -- which frames this lesion appears on
);
```

**Feasibility: HIGH**
- SQLite, no server needed
- `study_id` = DICOM StudyInstanceUID or derived from accession number (linked to C hospital RIS via existing accession patterns)

---

### Step 4 — IE RIS Annotation (SilverlightControlHost)

**Goal:** Automate placement of lesion markers on the IE RIS breast diagram canvas using mouse simulation.

**Context:**
The annotation panel is a `SilverlightControlHost` — standard UI Automation cannot interrogate its internal elements. Only mouse/keyboard simulation is possible.

**Known actions (from description):**
- Click a **lesion type button** to select lesion category
- **Left-click** on the canvas to place a lesion marker at that position
- **Right-click** a placed lesion to delete it
- **Double-click** a placed lesion to open a text input describing location + size (e.g. `R 9-10/2.5, 13mm`)

**Approach:**
1. **Calibrate canvas geometry:** Record the pixel bounds of the Silverlight canvas using `WinGetPos` on the IE frame + known offsets. The canvas is a circular breast diagram; map clock positions to (x, y) coordinates:
   - 12 o'clock → top center; 3 o'clock → right; 6 → bottom; 9 → left
   - `x = cx + r * sin(clock * 30°)`, `y = cy - r * cos(clock * 30°)`
   - `r` scaled to canvas radius × (dist_cm / max_radius_cm)
2. **Button locations:** Hardcode or auto-detect via pixel color/template matching. Lesion type button row is at a fixed Y offset above the canvas.
3. **Text entry:** After double-click on placed lesion, `SendInput` the formatted string. Tab/Enter to confirm.
4. **State verification:** After each click, capture a small screenshot of the canvas and confirm a marker appeared (color change at click point).

**Coordinate computation (AHK):**
```ahk
clockToXY(clock, dist_cm, cx, cy, scale_px_per_cm) {
  angle := (clock - 12) * 30  ; degrees, clockwise from top
  rad := angle * 3.14159 / 180
  x := cx + scale_px_per_cm * dist_cm * Sin(rad)
  y := cy - scale_px_per_cm * dist_cm * Cos(rad)
  return [Round(x), Round(y)]
}
```

**Feasibility: LOW-MODERATE**
- Mouse simulation is achievable but fragile — depends on consistent window size, zoom level, canvas position
- Silverlight does not expose accessible names; no way to confirm marker placement via UIA, only via pixel inspection
- No way to programmatically read back existing markers already placed in a previous session
- Window must be in foreground; any focus steal aborts the operation
- The double-click → text box interaction is the most fragile point (timing-sensitive)

**Mitigations:**
- Add configurable delays between actions (`Sleep`)
- Require the user to pre-position the window and not interact during automation
- Provide a "dry run" mode that moves the mouse to each target coordinate without clicking, so the user can verify positions
- Log all placed lesions to a local file for audit/undo

**Risk:** If the canvas is not at a fixed pixel offset (e.g., IE toolbar height changes, window is not maximized), all coordinates will be wrong. Mitigation: detect a known reference point (e.g., a fixed UI element near the canvas) using `ImageSearch` or pixel color before proceeding.

---

### Step 5 — Lesion Comparison Logic

**Goal:** Given the current study's parsed lesions and prior studies in the database, identify same, growing, new, and resolved lesions.

**Matching algorithm:**
Two lesions are the "same" if:
1. Same side (R / L)
2. Clock position overlap: `abs(clock_center_current - clock_center_prior) <= tolerance_clock` (default 0.5 hour)
3. Distance match: `abs(dist_cm_current - dist_cm_prior) <= tolerance_dist` (default 0.5 cm)

Clock center: `(clock_start + clock_end) / 2`, wrapping at 12.

**Ambiguous match** (hint to user): match at tolerance 1.0 clock + 1.0 cm, but not at tight tolerance — flag as "possible same lesion, verify".

**Progression classification:**
| Status | Condition |
|---|---|
| Stable | `abs(max_dim_current - max_dim_prior) <= 2mm` |
| Growing | `max_dim_current > max_dim_prior + 2mm` |
| Shrinking | `max_dim_current < max_dim_prior - 2mm` |
| New | No match in prior study |
| Resolved | Match in prior but absent in current |

**Largest lesion:** `max(all current lesions by max_dim_mm)` — always highlighted.

**Feasibility: HIGH**
- Pure algorithmic, no external dependencies
- Clock wrap-around edge case (e.g., 11 vs 1 o'clock) needs special handling: distance via `min(abs(a-b), 12-abs(a-b))`

---

### Step 6 — AHK GUI for Comparison

**Goal:** Display a side-by-side or list-based comparison of current vs prior lesions with color-coded status.

**UI design:**
```
┌──────────────────────────────────────────────────────────┐
│  Patient: 0000000001    Study: 2026-05-18  vs  2025-11-20│
├──────────────────────────────────────────────────────────┤
│  [Current]              [Prior]          [Status]        │
│  R 9-10/2.5  13mm   ←→  R 9-10/2.5 11mm  ▲ Growing +2mm │
│  R 6/3.0     8mm    ←→  R 6/3.0    9mm   ▼ Shrinking    │
│  L 2/1.5     5mm    ←→  (none)            ★ New         │
│  (none)             ←→  R 12/2.0   6mm   ✓ Resolved     │
├──────────────────────────────────────────────────────────┤
│  ★ Largest: R 9-10/2.5 = 13mm (was 11mm, +2mm)          │
│                                    [Annotate RIS] [Close] │
└──────────────────────────────────────────────────────────┘
```

**Implementation:**
- AHK v1 `Gui` with `ListView` control for the comparison table
- Color rows: red = growing, green = shrinking, yellow = new, grey = resolved, white = stable
- "Annotate RIS" button triggers `ris_annotate.ahk` with the current study's lesion list as a parameter
- Ambiguous matches shown with `?` status and tooltip

**Feasibility: HIGH**
- AHK ListView supports color (via `LV_ModifyCol` + owner-draw is complex; simpler: use separate label rows with colored backgrounds via `Gui, Color`)
- Alternative: output an HTML report instead for richer display — easier color coding, open in default browser

---

## Overall Feasibility Summary

| Step | Node | Feasibility | Key Risk | Mitigation |
|---|---|---|---|---|
| 1 DICOM retrieval | Ubuntu | HIGH | AE title registered with PACS? | Confirm with PACS admin |
| 2 OCR extraction | Ubuntu | HIGH (text) / MOD (calipers) | Machine layout variation, compressed DICOM | `python-gdcm`, adaptive ROI, per-machine templates |
| 3 Text parsing | Ubuntu | HIGH | OCR digit errors (0↔O) | Post-correction regex + validation |
| 4 SQLite DB | Ubuntu | HIGH | File lock during write | Atomic rename pattern |
| 5 Pipeline orchestrator | Ubuntu | HIGH | — | `inotifywait` or SSH-triggered |
| 6 PACS fallback capture | Windows | MODERATE | Viewport coord detection | Reuse `INFINITT_OCR_RegionReview.ahk`; fallback feeds Ubuntu OCR via SSH |
| 7 Comparison logic | Windows | HIGH | Clock wrap-around | `min(abs, 12-abs)` formula |
| 8 Comparison GUI | Windows | HIGH | ListView color in AHK | HTML report as simpler alternative |
| 9 IE RIS annotation | Windows | LOW-MOD | Silverlight, no UIA, pixel fragility | Dry-run mode, reference anchor, one-at-a-time with confirm |

---

## Recommended Implementation Order

1. **Steps 3 + 4** — parser + DB schema (pure Python, testable with sample strings immediately)
2. **Step 2** — OCR extraction (needs a few sample `.dcm` files from the Ubuntu machine)
3. **Step 1** — DICOM retrieval (needs PACS AE title confirmation)
4. **Step 5** — pipeline orchestrator (wires 1-4 together; add `inotifywait` trigger)
5. **Steps 7 + 8** — comparison + GUI on Windows (stubbable with sample DB data)
6. **Step 6** — PACS fallback (needs live INFINITT session)
7. **Step 9** — IE RIS annotation (last; most fragile; needs live IE RIS + calibration session)

---

## Prerequisites / Dependencies

### Ubuntu
| Tool | Purpose | Install |
|---|---|---|
| `pynetdicom` or `dcmtk` | DICOM C-MOVE | `pip install pynetdicom` or `apt install dcmtk` |
| `pydicom` | DICOM parsing | `pip install pydicom` |
| `python-gdcm` | Compressed DICOM decode | `apt install python3-gdcm` |
| `pillow` | Image conversion | `pip install pillow` |
| `opencv-python` | Preprocessing, template match | `pip install opencv-python` |
| `easyocr` | OCR engine (GPU optional) | `pip install easyocr` |
| `sqlite3` | DB | stdlib |
| `flask` (optional) | REST API for Windows client | `pip install flask` |

### Windows
| Tool | Purpose | Notes |
|---|---|---|
| Python 3.x | `read_lesion_db.py`, `compare_lesions.py` | Already available |
| AHK v1 | GUI + RIS annotation + fallback capture | Already installed |
| `plink.exe` / SSH | Trigger Ubuntu pipeline remotely | Part of PuTTY; check if installed |

---

## Open Questions

1. **DICOM node:** Is the Ubuntu machine already registered as an AE with the PACS? What AE title / port?
2. **DB access method:** SMB share (existing `RIS_PACS_share`) or SSH `scp` on demand — which is more reliable in the current network?
3. **IE RIS canvas size:** Is the Silverlight breast diagram always the same pixel size? Need a calibration screenshot before Step 9.
4. **Prior study lookup:** Can the Ubuntu pipeline automatically find prior US studies for the same patient by querying the PACS worklist or DICOM C-FIND? (Or use chart number from the existing `query_app` infrastructure?)
5. **Clock format variation:** Do all US machines print `9-10/2.5` or could some print `9:00`, `09`, `9h`? Need sample OCR output from each machine in use.
6. **Multi-lesion per frame:** Can one frame show two separate lesion annotations simultaneously? Parser must handle this if so.
