from pydicom.dataset import Dataset
from pynetdicom import AE, evt, build_role, StoragePresentationContexts
from pynetdicom.sop_class import StudyRootQueryRetrieveInformationModelFind, StudyRootQueryRetrieveInformationModelMove
from flask import Flask, render_template
import pandas as pd
import re

# Initialize the Application Entity
ae = AE(ae_title='iMac')

# Add the requested presentation context
ae.add_requested_context(StudyRootQueryRetrieveInformationModelFind)

def backup_date(studydate):
    date = re.sub(r'\D', '', str(studydate))[:8]
    if len(studydate) != 8:
        return 'Date format error, eg. "20230101"', 403

    # Create query Dataset
    ds = Dataset()
    ds.StudyDate = studydate
    ds.QueryRetrieveLevel = 'STUDY'
    ds.StudyInstanceUID=''


    # Setup origin nodes details
    pacs_nodes = {
        'CTMRRAW': ('CTMRRAW', '192.0.2.10', 5678)

    }

    # Setup origin nodes details
    nas_nodes = {
        'CTMRRAW-T': ('CTMRRAW-T', '192.0.2.10', 5679),

    }

    all_studies = dict()

    # Query studies from PACS nodes
    studies = []
    for node, (aet, ip, port) in pacs_nodes.items():
        assoc = ae.associate(ip, port, ae_title=aet)
        if assoc.is_established:
            responses = assoc.send_c_find(ds, StudyRootQueryRetrieveInformationModelFind)

            for status, resp in responses:
                try:
                    all_studies[str(resp.StudyInstanceUID)] = (node, resp)
                    studies.append(str(resp.StudyInstanceUID))
                except:
                    pass

            assoc.release()

    from_studies = set(studies)

    ae2 = AE(ae_title='iMac')
    ae2.add_requested_context(StudyRootQueryRetrieveInformationModelMove)
    # ae2.add_requested_context(StoragePresentationContexts)



    studies = []
    assoc = ae2.associate('192.0.2.10', 5678, ae_title='CTMRRAW')
    if assoc.is_established:
        for study_uid in from_studies:
            ds = Dataset()
            ds.QueryRetrieveLevel = 'STUDY'
            ds.StudyInstanceUID = study_uid

            responses = assoc.send_c_move(ds, 'CTMRRAW-T', StudyRootQueryRetrieveInformationModelMove)

            for status, resp in responses:
                pass

        assoc.release()

    # return render_template('simple.html',  tables=[df.to_html(classes='data')], titles=df.columns.values)





if __name__ == '__main__':

    backup_date('20170601')

