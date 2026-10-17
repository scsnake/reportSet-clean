from pydicom.dataset import Dataset
from pynetdicom import AE, evt, build_role
from pynetdicom.sop_class import StudyRootQueryRetrieveInformationModelFind
from flask import Flask, render_template
import pandas as pd
import re
import concurrent.futures

app = Flask(__name__)


@app.route('/')
def hello():
    return 'Hello, World!'

def find_studydate(calling, called:tuple, studydate):
    # Initialize the Application Entity
    ae = AE(ae_title=calling)
    # Add the requested presentation context
    ae.add_requested_context(StudyRootQueryRetrieveInformationModelFind)

    ds = Dataset()
    ds.StudyDate = studydate
    ds.QueryRetrieveLevel = 'STUDY'
    ds.PatientID = ''
    ds.AccessionNumber = ''
    ds.StudyInstanceUID = ''
    ds.StudyDescription = ''

    aet,ip,port = called

    res = []
    print('checking', aet)
    assoc = ae.associate(ip, port, ae_title=aet)
    if assoc.is_established:
        responses = assoc.send_c_find(ds, StudyRootQueryRetrieveInformationModelFind)

        for status, resp in responses:
            try:
                # res[str(resp.StudyInstanceUID)] = (node, resp)
                # all_studies_by_node[node].append(resp)
                # studies.append(str(resp.StudyInstanceUID))
                studyUID = resp.StudyInstanceUID
                res.append(resp)
            except:
                pass

        assoc.release()
    return res


@app.route('/check/<studydate>')
def check_diff(studydate):
    date = re.sub(r'\D', '', str(studydate))[:8]
    if len(studydate) != 8:
        return 'Date format error, eg. "20230101"', 403
    print('checking study date:', studydate)
    # Create query Dataset


    # Setup origin nodes details
    pacs_nodes = {
        'D750': ('D750', '192.0.2.10', 4006),
        # 'Aquilion': ('Aquilion', '192.0.2.10', 2700),
        # 'MRAWP145402': ('MRAWP145402', '192.0.2.10', 104),
        # 'MRAWP141584': ('MRAWP141584', '192.0.2.10', 104),
    }

    # Setup origin nodes details
    nas_nodes = {
        # 'CTMRRAW': ('CTMRRAW', '192.0.2.10', 5678),
        # 'CTMRRAW0': ('CTMRRAW0', '192.0.2.10', 5678),

    }


    all_studies = dict()
    all_studies_by_node = dict()
    # Query studies from PACS nodes
    studies = []

    futures = dict()
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as executor:
        for node, (aet, ip, port) in dict(pacs_nodes, **nas_nodes).items():
            futures[executor.submit(find_studydate, 'iMac', (aet, ip, port), studydate)]= node

        for future in concurrent.futures.as_completed(futures):
            node = futures[future]
            try:
                for resp in future.result():
                    all_studies[str(resp.StudyInstanceUID)] = (node, resp)
                    all_studies_by_node[node].append(resp)
                    studies.append(str(resp.StudyInstanceUID))
            except:
                pass



    from_studies = dict()
    from_set = set()
    to_studies = dict()
    to_set = set()
    for studyuid, (node, study) in all_studies.items():
        if node in pacs_nodes.keys():
            try:
                from_set.add(study.StudyInstanceUID)
                from_studies[study.StudyInstanceUID] = (
                    node, study.StudyDate, study.PatientID, study.StudyDescription, study.AccessionNumber
                )
            except:
                pass
        elif node in nas_nodes.keys():
            try:
                to_set.add(study.StudyInstanceUID)
                to_studies[study.StudyInstanceUID] = (
                    node, study.StudyDate, study.PatientID, study.StudyDescription, study.AccessionNumber
                )
            except:
                pass



# Find studies in Node A but not in Node B
    diff_studies = from_set - to_set

    df_cols = ('Source', 'StudyDate', 'PatientID', 'StudyDescription', 'AccessionNumber')

    if len(diff_studies) == 0:
        df = pd.DataFrame(columns=df_cols)
        for studyuid, row in from_studies:
            df = df.append(pd.Series(
                    row
                    , index=df.columns), ignore_index=True)

        return 'All done!<br/><br/>' + df.to_html(header="true", table_id="table")
    else:
        df = pd.DataFrame(columns=df_cols)
        # Print the studies unique to Node A
        for studyUID in diff_studies:
            row = from_studies[studyUID]
            df = df.append(pd.Series(
                row
                , index=df.columns), ignore_index=True)

        return 'Studies not done:<br/><br/>' + df.to_html(header="true", table_id="table")
        # return render_template('simple.html',  tables=[df.to_html(classes='data')], titles=df.columns.values)


if __name__ == '__main__':
    # pass
    check_diff('20230620')