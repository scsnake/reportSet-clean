"""Breast US OCR pipeline — site config for gpu-host.example.invalid."""
from pathlib import Path
import sys

# ── lungcad path + sys.path patch (must happen before any dicom_source import)
_LUNGCAD = Path('/home/raduser/PycharmProjects/lungcad_v2')
if str(_LUNGCAD) not in sys.path:
    sys.path.insert(0, str(_LUNGCAD))

# ── Patch dcm4che_bin_path to absolute so it works from any cwd ──────────────
DCM4CHE_BIN = _LUNGCAD / 'dcm4che' / 'bin'
import dicom_source.dcm4che_proc as _proc
_proc.dcm4che_bin_path = str(DCM4CHE_BIN)

# ── Calling AE (SCU side: movescu, findscu) ───────────────────────────────────
CALLING_AE = {
    'local_aet':  'gpu-host.example.invalid',
    'local_ip':   'localhost',
    'local_port': '4006',
}

# ── Local StoreSCP AE (receives incoming C-MOVE files) ────────────────────────
# Uses server_* keys expected by StoreSCP(directory, called_ae).
# server_ip = 0.0.0.0 so NETGATE127 can connect directly (no tunnel).
LOCAL_SCP_AE = {
    'server_aet':  'gpu-host.example.invalid',
    'server_ip':   '0.0.0.0',
    'server_port': '4006',
}

# ── Main hospital PACS (NETGATE127) ──────────────────────────────────────────
# bind_any=True: skips pinning movescu source socket to localhost so Linux
# does not reject pairing a loopback source with a non-loopback destination.
CHPACS_AE = {
    'server_aet':      'NETGATE127',
    'server_ip':       '192.0.2.10',
    'server_port':     '104',
    'retrieve_method': ['c-move'],
    'bind_any':        True,
}

# ── Storage paths ─────────────────────────────────────────────────────────────
DATA_ROOT = Path('/opt/breast_us_ocr')
DICOM_DIR = DATA_ROOT / 'dicom'
DB_PATH   = DATA_ROOT / 'lesions.db'
DICOM_DIR.mkdir(parents=True, exist_ok=True)
