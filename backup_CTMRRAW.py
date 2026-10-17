import subprocess
from pydicom import dcmread
from pathlib import Path
from datetime import datetime, timedelta

home_dir = str(Path('~/backup_CTMRRAW').expanduser())
findscu_bin = str(Path('~/dcm4che/bin/findscu').expanduser())
movescu_bin = str(Path('~/dcm4che/bin/movescu').expanduser())
result_outdir = 'dcm4che_results'


# def backup(studydate):

    # cmd = '{} -b gpu-host.example.invalid@10.0.0.1:11112 -c CTMRRAW@10.0.0.1:5678 -m StudyDate={} -r StudyInstanceUID --out-dir {} --out-file result0000'.format(
    #     findscu_bin, studydate, result_outdir
    # )
    # subprocess.run('rm {}/result*'.format(result_outdir), shell=True, cwd=home_dir)
    # subprocess.run(cmd, shell=True, cwd=home_dir)
    #
    # all_uids=[]
    # for res in Path(home_dir).joinpath(result_outdir).glob('result*'):
    #     try:
    #         ds = dcmread(res, force=True)
    #         study_uid = ds.StudyInstanceUID
    #         all_uids.append(study_uid)
    #     except:
    #         pass

start_date = datetime.strptime('20170531', '%Y%m%d')
one_day = timedelta(days=1)
while True:
    this_date = start_date.strftime('%Y%m%d')
    cmd = '{} -b gpu-host.example.invalid@10.0.0.1:11112 -c CTMRRAW@10.0.0.1:5678 -m StudyDate={} --dest CTMRRAW-T'.format(
        movescu_bin, this_date
    )
    subprocess.run(cmd, shell=True, cwd=home_dir)
    start_date = start_date-one_day



