"""
Retrieve breast US studies from the main hospital PACS (NETGATE127).

Wraps lungcad's dicom_source.gpu-host.example.invalid Move/Find classes — same dcm4che
tooling already proven for lung CT, but pointed at CHPACS (NETGATE127)
instead of PACSRAWDATA.

Usage:
    uv run python dicom_retrieve.py --accession T0000000001
    uv run python dicom_retrieve.py --patient_id 0000000001 --date 20260518
"""
import argparse
import sys
from pathlib import Path

import config  # noqa: F401  sets sys.path, defines AE dicts
from dicom_source.gpu-host.example.invalid import Find, Move, StoreSCP, Echo


def find_studies(modality: str = 'US', **criteria):
    """C-FIND study-level query against CHPACS. Yields pydicom Datasets."""
    finder = Find(
        outdir=config.DATA_ROOT / 'findscu_out',
        calling_ae=config.CALLING_AE,
        called_ae=config.CHPACS_AE,
    )
    yield from finder.study_level(Modality=modality, **criteria)


def retrieve_study(study_uid: str, dest_dir: Path = None) -> Path:
    """C-MOVE a study by StudyInstanceUID into dest_dir. Returns the dir."""
    dest = dest_dir or (config.DICOM_DIR / study_uid)
    dest.mkdir(parents=True, exist_ok=True)

    scp = StoreSCP(dest, config.LOCAL_SCP_AE)
    scp.start()
    try:
        mover = Move(config.CALLING_AE, config.CHPACS_AE)
        mover.study_level(StudyInstanceUID=study_uid)
    finally:
        scp.stop()
    return dest


def retrieve_by_accession(accession: str) -> Path:
    results = list(find_studies(AccessionNumber=accession))
    if not results:
        raise ValueError(f'No study found for accession {accession}')
    ds = results[0]
    uid = ds.StudyInstanceUID
    print(f'Found: {uid}  patient={ds.PatientID}  date={ds.StudyDate}')
    return retrieve_study(uid)


def main():
    ap = argparse.ArgumentParser(description='Retrieve breast US from CHPACS')
    ap.add_argument('--accession',  help='Accession number')
    ap.add_argument('--study_uid',  help='StudyInstanceUID (direct move)')
    ap.add_argument('--patient_id', help='Patient chart number for C-FIND')
    ap.add_argument('--date',       help='Study date YYYYMMDD')
    args = ap.parse_args()

    if args.accession:
        dest = retrieve_by_accession(args.accession)
        print(f'Retrieved to {dest}')
    elif args.study_uid:
        dest = retrieve_study(args.study_uid)
        print(f'Retrieved to {dest}')
    elif args.patient_id:
        for ds in find_studies(PatientID=args.patient_id, StudyDate=args.date or ''):
            print(ds.get('StudyDate'), ds.get('AccessionNumber'),
                  ds.get('StudyDescription'), ds.get('StudyInstanceUID'))
    else:
        ap.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
