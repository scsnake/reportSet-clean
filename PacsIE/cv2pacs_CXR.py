import traceback

import cv2
from pathlib import Path
from contextlib import suppress
import numpy as np
import pydicom
import os
from screeninfo import get_monitors
from time import sleep
import pickle, shutil, re
from dicom_convert_pic import convert_image2
from multiprocessing import Pool
import platform

__os__ = platform.system()

monitors = get_monitors()
use_monitor = len(monitors)-1
mon = monitors[use_monitor]
h = mon.height-50
w = mon.width-20
mode = 'dcm'


root_dir = Path(r'\\Mac\shared\test_dicom') if mode!='dcm' else Path(r'D:\scsnake\CXR_health')
action_folder_path = root_dir.joinpath('miniPACS_action')
action_folder_path.mkdir(parents=True, exist_ok=True)
bad_folder_path = root_dir.joinpath('bad_png')
bad_folder_path.mkdir(parents=True, exist_ok=True)

def change_ext(file_path, to='.png'):
    p = str(file_path)
    p = Path(p)
    ret = str(p.parent.joinpath(p.stem + to))
    if 'Darwin' in __os__:
        ret = ret.replace('\\', r'/')
    else:
        ret = ret.replace(r'/', '\\')
    return ret


def img_fit(img_shape: tuple, w=None, h=None):
    '''
    :param img_shape: shape[0] = h, shape[1] = w
    :param w:
    :param h:
    :return: desired (w, h) for cv2.resize
    '''
    if h is not None:
        if img_shape[0]>h:
            img_shape = (h, img_shape[1]* h/img_shape[0])
        if w is None:
            return tuple(int(i) for i in img_shape)[::-1]
        else:
            return img_fit(img_shape, w=w, h=None)
    if w is not None:
        if img_shape[1]>w:
            img_shape = (img_shape[0]* w/img_shape[1], w)
        if h is None:
            return tuple(int(i) for i in img_shape)[::-1]
        else:
            return img_fit(img_shape, w=None, h=h)

def get_one(img_path):
    png1 = change_ext(str(img_path))
    img = cv2.imread(png1, cv2.IMREAD_UNCHANGED)
    img = cv2.resize(img, (int(img.shape[1] * h / img.shape[0]), h), interpolation=cv2.INTER_AREA)
    if img.shape[0]>h or img.shape[1]>w:
        img = cv2.resize(img, img_fit(img.shape, w, h), interpolation=cv2.INTER_AREA)
    return img

def merge_two(i1_path, i2_path):
    image_path1 = str(i1_path)
    image_path2 = str(i2_path)
    img1 = cv2.imread(change_ext(image_path1), cv2.IMREAD_UNCHANGED)
    img2 = cv2.imread(change_ext(image_path2), cv2.IMREAD_UNCHANGED)
    # with suppress(Exception):

    if img1.shape[0] > img2.shape[0]:
        i1 = img1
        i2 = img2
    else:
        i1 = img2
        i2 = img1

    i2 = cv2.resize(i2, (int(i1.shape[0] / i2.shape[0] * i2.shape[1]), i1.shape[0]), interpolation=cv2.INTER_AREA)

    img = np.concatenate((i1, i2), axis=1)
    img = cv2.resize(img, img_fit(img.shape, w, h), interpolation=cv2.INTER_AREA)
    return img

if __name__=='__main__':


    for f in Path(action_folder_path).iterdir():
        if f.name.startswith('minipacs_') or f.name.startswith('thisStudy_'):
            with suppress(Exception):
                os.remove(f)

    for_loading = []
    to_convert= dict()
    for dcm_file in root_dir.iterdir():
        if dcm_file.is_dir():
            continue
        if not re.search(r'^(\w+)_(\d+)$', dcm_file.stem):
            continue

        try:
            info = dict()
            dcm = pydicom.dcmread(dcm_file, force=True)
            acc_no = info['AccNo'] = dcm.AccessionNumber
            chart_no = info['ChartNo'] = dcm.PatientID
            exam_date = info['StudyDate'] = dcm.StudyDate
            exam_name = info['StudyDescription'] = dcm.StudyDescription

        except:
            continue
        img = convert_image2(str(dcm_file), str(out_png_f), 2 * min(h, w))

        # open(action_folder_path.joinpath('thisStudy_{}_{}'.format(acc_no, chart_no)), 'a').close()
        window_name = 'cv2pacs: {} | {} | {}'.format(acc_no, chart_no, exam_name)

        cv2.namedWindow(window_name)  # Create a named window
        win_x, win_y = 0, 0

        # cv2.moveWindow(window_name, mon.x, mon.y)  # Move it to (40,30)
        cv2.moveWindow(window_name, win_x, win_y)  # Move it to (40,30)

        cv2.imshow(window_name, img)
        key = cv2.waitKey(1)
        next_study = False
        while not next_study:
            if Path(action_folder_path).joinpath('minipacs_next_study').exists():
                os.remove(Path(action_folder_path).joinpath('minipacs_next_study'))
                next_study=True
                with suppress(Exception):
                    cv2.destroyWindow(window_name)
            elif Path(action_folder_path).joinpath('minipacs_bad_study').exists():
                os.remove(Path(action_folder_path).joinpath('minipacs_bad_study'))
                next_study = True
                shutil.move(dcm_file, bad_folder_path.joinpath(dcm_file.stem))
                with suppress(Exception):
                    cv2.destroyWindow(window_name)


            else:
                sleep(0.2)



