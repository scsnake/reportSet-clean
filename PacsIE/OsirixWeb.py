import hashlib
import re
import argparse
import requests


class OsirixPortal(object):
    def __init__(self, id='', pw='', OSID='', url=''):
        self.url = url
        self.OsirixPortalUrl = 'http://' + url
        self.session = requests.Session()
        self.session.hooks = {'response': lambda r, *args, **kwargs: r.raise_for_status()}
        self.header = {'Referer': self.OsirixPortalUrl, 'Host': self.url}
        self.session.get(self.OsirixPortalUrl)
        self.id = id
        self.pw = pw
        self.OSID = OSID
        if id != '' and pw != '':
            self.login(id, pw)
        if OSID != '':
            self.is_valid(OSID)

    def login(self, id='', pw=''):
        if id == '':
            id = self.id
        if pw == '':
            pw = self.pw
        sh = hashlib.sha1((str(pw) + str(id)).encode('utf-8')).hexdigest()
        self.session.post(self.OsirixPortalUrl,
                          data={'login': '',
                                'username': str(id),
                                'password': str(pw),
                                'sha1': str(sh)},
                          headers=self.header)
        if 'OSID' in self.session.cookies:
            self.OSID = self.session.cookies['OSID']
            return self.OSID
        else:
            return ''

    def is_valid(self, osid=''):
        if osid == '':
            osid = self.OSID
        try:
            r = requests.get(self.OsirixPortalUrl+'/main',
                             cookies={'OSID': osid},
                             headers=self.header)
        except Exception as e:
            print(e)
            return False
        return (not 'Access to this page is restricted' in r.text)

    def searchAccNo(self, AccNo):
        r = self.session.get(self.OsirixPortalUrl + '/studyList?searchAccessionNumber=' + AccNo,
                             headers=self.header)
        xid_re = re.findall(r'study\?searchAccessionNumber=' + AccNo + '&xid=([\w-]+)', r.text, re.IGNORECASE)
        if xid_re:
            return xid_re[0]
        else:
            return ''

    def deleteStudy(self, AccNo, xid=''):
        if xid == '':
            xid = self.searchAccNo(AccNo)
        url = self.OsirixPortalUrl + '/studyList?searchAccessionNumber=' + AccNo
        r = self.session.post(url,
                              headers={'Referer': url, 'Host': self.url},
                              data={'delete': xid})


if __name__ == '__main__':
    id, pw = 'MOCK_USER', 'MOCK_PASSWORD'
    parser=argparse.ArgumentParser()
    parser.add_argument('--url', type=str, help='osirix web url ip:host to connect')
    parser.add_argument('--AccNo', '--AccNos', dest='AccNos', metavar='N', nargs='+', help='AccNos to be deleted from RAID')
    args = parser.parse_args()

    os = OsirixPortal(id, pw, url=args.url)
    for AccNo in args.AccNos:
        print('Delete %s from RAID...' % (AccNo, ))
        os.deleteStudy(AccNo)
