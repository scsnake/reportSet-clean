CREATE TABLE IF NOT EXISTS studies (
    -- Real DICOM StudyInstanceUID when known; otherwise a synthetic
    -- "missing:<accession>" string so we can still record a failure row.
    study_uid    TEXT PRIMARY KEY,
    patient_id   TEXT,                 -- may be NULL if PACS lookup failed
    study_date   TEXT,                 -- may be NULL on PACS failure
    accession    TEXT,
    processed_at TEXT,
    -- Outcome of this run:
    --   'pacs_not_found'   - C-FIND returned no study for the accession
    --   'pacs_move_failed' - C-FIND ok, but C-MOVE raised
    --   'pacs_incomplete'  - C-MOVE delivered fewer files than C-FIND expected
    --   'dicom_unreadable' - files on disk but pydicom couldn't read any
    --   'ocr_done'         - OCR + parse completed (findings may be 0)
    status                  TEXT NOT NULL,
    expected_instance_count INTEGER,   -- from C-FIND NumberOfStudyRelatedInstances
    received_instance_count INTEGER,   -- actual files in DICOM dir post C-MOVE
    frame_count             INTEGER,   -- unique frames OCR'd
    error_detail            TEXT,      -- exception message / diagnostic note
    -- Summary for the Win10 GUI's quick filter:
    --   'positive' - status='ocr_done' AND (>=1 lesion OR >=1 detected text flag OR >=1 unanchored measurement)
    --   'negative' - status='ocr_done' AND zero of all three -> verified clean study
    --   'unknown'  - anything else (failure cases)
    finding_kind            TEXT,
    -- 1 when the study has >=1 row in `lesions` (clock/dist was burned in and
    -- parsed). 0 when the only measurements are unanchored (frame_measurements
    -- only). Unanchored-only is the common fibrocystic-change (FCC) pattern and
    -- requires a different urgency level in the Win10 GUI.
    has_anchored_lesions    INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_studies_accession
    ON studies(accession);
CREATE INDEX IF NOT EXISTS idx_studies_status
    ON studies(status);

CREATE TABLE IF NOT EXISTS lesions (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    study_uid     TEXT REFERENCES studies(study_uid),
    side          TEXT CHECK(side IN ('R','L','?')),
    -- 1 when no contributing frame had an explicit OCR'd R/L mark (side came
    -- purely from the sequence-propagation pass, or could not be determined
    -- at all, in which case side is '?'). 0 when at least one frame OCR'd
    -- the side directly. Windows UI uses this for "R?" vs "R" hints.
    side_inferred INTEGER DEFAULT 0,
    region        TEXT,           -- AX / SCV / SUB / RETRO / PERI / TAIL / NULL
    clock_start   REAL,
    clock_end     REAL,           -- NULL if single clock value
    dist_cm       REAL,
    max_dim_mm    REAL,
    dims_json     TEXT,           -- JSON array of all measurements
    orientation   TEXT,
    flags_json    TEXT,           -- JSON array of per-lesion parser text flags, e.g. SCAR/BX/CYST/FA/LN
    frame_indices TEXT            -- JSON array of frame numbers
);

-- Frames where the technologist took measurements / placed calipers but
-- didn't burn in a clock/dist label. These cannot be merged with the lesions
-- table because there's no position to consolidate on, but the radiologist
-- still needs to see them - they represent real measured findings.
CREATE TABLE IF NOT EXISTS frame_measurements (
    study_uid     TEXT REFERENCES studies(study_uid),
    frame_index   INTEGER,
    dims_json     TEXT,           -- JSON array of mm values from BL crop
    max_dim_mm    REAL,
    caliper_count INTEGER,
    PRIMARY KEY (study_uid, frame_index)
);
CREATE INDEX IF NOT EXISTS idx_frame_measurements_study
    ON frame_measurements(study_uid);

-- Vision-LLM marker analysis on the right-lower 1/3 x 1/3 crop of each frame.
-- Populated by a separate pass (vision_marker.py, currently Gemini 2.5 Flash)
-- that reads the graphical body-marker icon - completely independent of the
-- text-OCR pipeline that fills `lesions` and `frame_measurements`.
--
-- One row per (study, frame) when a marker analysis was attempted. Absence of
-- a row simply means the LLM was not called for that frame. Multiple rows
-- per study are expected (one per analysed frame); the Win10 GUI typically
-- aggregates by side and uses these to override / fill in `lesions.side` when
-- OCR returned '?' or text-only Style B couldn't be read.
CREATE TABLE IF NOT EXISTS frame_markers (
    study_uid          TEXT REFERENCES studies(study_uid),
    frame_index        INTEGER,
    -- Provenance --------------------------------------------------------
    model_name         TEXT,             -- e.g. 'gemini-2.5-flash'
    processed_at       TEXT,             -- ISO timestamp of the LLM call
    -- Marker basics -----------------------------------------------------
    marker_present     INTEGER,          -- 1 = LLM saw a body-marker icon
    icon_style         TEXT,             -- 'A' (line-drawn) | 'B' (dotted) | NULL
    -- Side -------------------------------------------------------------
    side               TEXT CHECK(side IN ('R','L','?',NULL)),
    side_source        TEXT,             -- 'text' | 'axilla_geometry' | NULL
    region             TEXT,             -- 'breast' | 'axilla' | 'scv' | 'none'
    -- Probe ------------------------------------------------------------
    probe_visible      INTEGER,          -- 1 = a probe bar/line was visible
    probe_orientation  TEXT,             -- 'horizontal'|'vertical'|'slash'|'backslash'|'?'
    -- Polar coords of probe midpoint relative to nipple at centre.
    -- PRIMARY math representation; clock_hour is derived for display.
    --   angle_deg: 0 = 12 o'clock, increasing clockwise (90 = 3, 180 = 6, 270 = 9)
    --   r_ratio:   distance from nipple / breast-circle radius (0..1+; >1 = axilla)
    --   clock_hour = ((angle_deg + 15) // 30) % 12 or 12
    angle_deg          REAL,
    r_ratio            REAL,
    clock_hour         INTEGER,
    -- Quality / metadata ----------------------------------------------
    confidence         REAL,             -- LLM-reported 0.0..1.0
    notes              TEXT,             -- free-text from the model
    raw_json           TEXT,             -- full LLM response, for audit/debug
    PRIMARY KEY (study_uid, frame_index)
);
CREATE INDEX IF NOT EXISTS idx_frame_markers_study
    ON frame_markers(study_uid);

-- Parser-detected text flags that apply to the whole side/study context.
-- Current examples include PARTIAL mastectomy, MRM, IMPLANT, etc.; the
-- vocabulary intentionally comes from the remote parser rules and may grow.
CREATE TABLE IF NOT EXISTS study_side_flags (
    study_uid     TEXT REFERENCES studies(study_uid),
    side          TEXT,           -- 'R', 'L', or '?' if side was undetermined
    flag          TEXT,           -- parser keyword text, not a closed local enum
    side_inferred INTEGER DEFAULT 0,   -- 1 if side was inferred (UI shows "R?")
    PRIMARY KEY (study_uid, side, flag)
);

CREATE INDEX IF NOT EXISTS idx_studies_patient
    ON studies(patient_id, study_date);
CREATE INDEX IF NOT EXISTS idx_lesions_study
    ON lesions(study_uid);
CREATE INDEX IF NOT EXISTS idx_side_flags_study
    ON study_side_flags(study_uid);
