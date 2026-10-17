# -*- coding: utf-8 -*-


import glob
import inspect
import json
import logging
import os, re
import statistics as stat
import sys
import PySide2
import pydicom
import numpy as np
import screeninfo

os.environ["QT_QPA_PLATFORM_PLUGIN_PATH"] = os.path.dirname(PySide2.__file__) + '/plugins/platforms'

import threading
from collections import OrderedDict
from contextlib import suppress
from functools import partial
from time import sleep, process_time as clock
from pathlib import Path
import cv2
import numpy as np
from PySide2.QtCore import Signal, Qt
from PySide2.QtGui import QPixmap, QImage, QFont, QMouseEvent, QKeyEvent, QKeySequence
from PySide2.QtWidgets import QLabel, QWidget, QMainWindow, QSizePolicy, QTextEdit, QApplication, QDesktopWidget, QMessageBox, QShortcut
from screeninfo import get_monitors
# import portalLib

import platform
__os__ = platform.system()
__is_win__ = 'Windows' in __os__
if __is_win__:
    import ctypes.wintypes
    sys.path.append(str(Path('.').resolve()))
    from win32func import WM_COPYDATA_Listener, Send_WM_COPYDATA
if 'Darwin' in __os__:
    os.environ['QT_MAC_WANTS_LAYER'] = '1'

def _async_raise(tid, exctype):
    """raises the exception, performs cleanup if needed"""
    if not inspect.isclass(exctype):
        exctype = type(exctype)
    res = ctypes.pythonapi.PyThreadState_SetAsyncExc(ctypes.c_long(tid), ctypes.py_object(exctype))
    if res == 0:
        raise ValueError("invalid thread id")
    elif res != 1:
        # """if it returns a number greater than one, you're in trouble,
        # and you should call it again with exc=NULL to revert the effect"""
        ctypes.pythonapi.PyThreadState_SetAsyncExc(tid, None)
        raise SystemError("PyThreadState_SetAsyncExc failed")


def stop_thread(thread):
    with suppress(Exception):
        _async_raise(thread.ident, SystemExit)


def _get_monitors():
    global app
    d = app.desktop()
    return [d.screenGeometry(i) for i in range(d.screenCount())]


class ImageLabel(QLabel):
    SIG_set_pixmap = Signal(QPixmap)
    SIG_set_pixmap_qimage = Signal(QImage)
    SIG_sharp_image = Signal(bool)

    def __init__(self, *args):
        super(ImageLabel, self).__init__(*args)

        self.if_mouse_event = self.parentWidget().app.if_mouse_event
        self.parent = args[0]
        self.label_index = -1

        self.mousePressed = False
        self.mouseMoving = False
        self.zooming_mode = False

        mag_label = QLabel(self)
        mag_label.setFixedSize(400, 400)
        mag_label.setStyleSheet('border: 1px solid white;')
        mag_label.hide()
        self.mag_label = mag_label
        self.cal_th = None
        self.cal_th_ev = threading.Event()
        self.calculating = False
        self.is_sharp_image = False
        # self.setMouseTracking(True)

        self.SIG_set_pixmap.connect(self.setPixmap)
        self.SIG_set_pixmap_qimage.connect(self.set_pixmap_qimage)
        self.SIG_sharp_image.connect(self.sharp_image)

        QShortcut(QKeySequence(Qt.Key_Down), self, activated=partial(self.myKeyPressEvent, 1))
        QShortcut(QKeySequence(Qt.Key_Up), self, activated=partial(self.myKeyPressEvent, 2))
        QShortcut(QKeySequence(Qt.Key_Right), self, activated=partial(self.myKeyPressEvent, 3))
        QShortcut(QKeySequence(Qt.Key_Left), self, activated=partial(self.myKeyPressEvent, 4))

    def myKeyPressEvent(self, which):
        if not self.underMouse() and not self.hasFocus():
            return

        if which==1:
            self.parent.app.SIG_next_study.emit(-1)
        elif which==2:
            self.parent.app.SIG_prior_study.emit()
        elif which==3:
            self.parent.SIG_next_image.emit('', self.label_index)
        elif which==4:
            self.parent.SIG_prior_image.emit('', self.label_index)





    def mousePressEvent(self, QMouseEvent):
        if not self.if_mouse_event:
            return

        if QMouseEvent.button() == Qt.LeftButton or QMouseEvent.button() == Qt.RightButton:
            self.mousePressed = QMouseEvent.button()
            self.mousePressedPosX = QMouseEvent.x()
            self.mousePressedPosY = QMouseEvent.y()
        elif QMouseEvent.button() == Qt.MiddleButton:
            self.is_sharp_image = not self.is_sharp_image
            self.SIG_sharp_image.emit(self.is_sharp_image)

    def mouseReleaseEvent(self, QMouseEvent):
        if not self.if_mouse_event:
            return

        if QMouseEvent.button() == Qt.LeftButton or QMouseEvent.button() == Qt.RightButton:
            try:
                self.cal_th_ev.set()
                self.cal_th.join()
                self.original_image_processing_tm.cancel()
                self.SIG_set_pixmap.emit(self.base_px)
            except:
                pass
            finally:
                # self.setPixmap(self.original_px)

                self.mousePressed = False

    def mouseMoveEvent(self, QMouseEvent):
        if not self.if_mouse_event:
            return

        if not self.mousePressed:
            return

        if not self.cal_th or not self.cal_th.is_alive():
            if self.mousePressed == Qt.LeftButton:
                target = self.cal_brightness_contrast
            else:
                target = self.cal_zoomin
            self.cal_th_ev.clear()
            th = threading.Thread(target=target, args=(QMouseEvent.x(), QMouseEvent.y()))
            th.start()
            self.cal_th = th

    # def show_mag(self):

    def sharp_image(self, do_sharpen=True):

        if not do_sharpen:
            self.base_image = self.original_image
        else:
            self.base_image = self.sharpen_image
        # cl = clock()
        self.base_px = QPixmap.fromImage(
            QImage(self.base_image.data, self.base_image.shape[1], self.base_image.shape[0],
                   self.base_image.shape[1], QImage.Format_Indexed8) \
                .scaled(self.fixedWidth, self.fixedHeight, Qt.KeepAspectRatio, Qt.SmoothTransformation))
        # print clock() - cl
        self.setPixmap(self.base_px)

    def cal_zoomin(self, mouseX, mouseY):
        ratio = np.float16(2.5)

        x = np.float16(mouseX) / self.fixedWidth
        y = np.float16(mouseY) / self.fixedHeight

        if x <= 0.5 / ratio:
            x = 0
        elif x >= 1 - 0.5 / ratio:
            x = 1 - 1 / ratio
        else:
            x = x - 0.5 / ratio

        if y <= 0.5 / ratio:
            y = 0
        elif y >= 1 - 0.5 / ratio:
            y = 1 - 1 / ratio
        else:
            y = y - 0.5 / ratio

        x = int(np.floor(self.base_image.shape[1] * x))
        y = int(np.floor(self.base_image.shape[0] * y))
        w = int(np.floor(self.base_image.shape[1] / ratio))
        h = int(np.floor(self.base_image.shape[0] / ratio))

        v = np.ascontiguousarray(self.base_image[y:(y + h), x:(x + w)])
        if self.cal_th_ev.is_set():
            return

        im2 = QImage(v.data, v.shape[1], v.shape[0],
                     v.shape[1], QImage.Format_Indexed8)
        if self.cal_th_ev.is_set():
            return
        self.SIG_set_pixmap_qimage.emit(im2)

    def cal_brightness_contrast(self, mouseX, mouseY, use_downsampled=True):
        # cl = clock()
        try:
            if not use_downsampled:
                using_image = self.base_image
            else:
                using_image = self.downsampled_sharpen_image if self.is_sharp_image else self.downsampled_image
        except:
            return

        contrast = self.sigmoid(np.float16(mouseX - self.mousePressedPosX) / self.fixedWidth)
        brightness = self.sigmoid(np.float16(mouseY - self.mousePressedPosY) / self.fixedHeight)
        # print contrast, brightness
        v = (using_image * contrast + brightness)
        v[v < 0] = 0
        v[v > 255] = 255
        v = v.astype(np.uint8)
        if self.cal_th_ev.is_set():
            return
        im2 = QImage(v.data, using_image.shape[1], using_image.shape[0],
                     using_image.shape[1], QImage.Format_Indexed8)
        if self.cal_th_ev.is_set():
            return
        self.SIG_set_pixmap_qimage.emit(im2)

        if use_downsampled:
            try:
                self.original_image_processing_tm.cancel()
            except:
                pass
            finally:
                th = threading.Timer(0.05, self.cal_brightness_contrast, [mouseX, mouseY, False])
                th.start()
                self.original_image_processing_tm = th

                # print clock() - cl

    def set_pixmap_qimage(self, im):
        # self.setPixmap(QPixmap.fromImage(im))
        self.setPixmap(QPixmap.fromImage(
            im.scaled(self.fixedWidth, self.fixedHeight, Qt.KeepAspectRatio, Qt.SmoothTransformation)))

    def sigmoid(self, x):
        return 1 + x / (1 + abs(x))

    def scale_image(self, v):
        w, h = np.float16(v.shape[0]), np.float16(v.shape[1])
        if h / w > np.float16(self.fixedHeight) / self.fixedWidth:
            return cv2.resize(v, (self.fixedHeight, int(np.round(w * self.fixedHeight / h))))
        else:
            return cv2.resize(v, (int(np.round(h * self.fixedWidth / w)), self.fixedWidth))


class ProgressWin(QWidget):
    SIG_update_text = Signal()
    SIG_show = Signal()
    SIG_hide = Signal()
    SIG_reset = Signal()
    SIG_first_init = Signal()

    def __init__(self, app=None):
        super(ProgressWin, self).__init__()
        self.app = app
        self.total_count = 0
        self.read_count = 0
        self.read_time = []
        self.read_time_sum = 0
        self.read_time_mean = 0
        self.estimated_time_remaining = 0
        self.pTick = 0

        progressLabel = QLabel(self)
        progressLabel.setStyleSheet('background-color: transparent; color: rgba(255,255,255,100); ')
        progressLabel.setFixedSize(250, 120)
        progressLabel.setGeometry(0, 0, 250, 120)
        progressLabel.setGeometry(0, 0, 0, 0)
        progressLabel.setFont(QFont("Verdana", 24, QFont.Normal))
        self.progress_label = progressLabel

        self.setGeometry(self.app.x + 50, self.app.y + self.app.h - 150, 250, 120)

        self.setWindowFlags(Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
        self.setAttribute(Qt.WA_TranslucentBackground)

        self.SIG_update_text.connect(self.update_text)
        self.SIG_show.connect(self.show_self)
        self.SIG_hide.connect(self.hide)
        self.SIG_reset.connect(self.reset)

    def reset(self):
        self.total_count = 0
        self.read_count = 0
        self.read_time = []
        self.read_time_sum = 0
        self.read_time_mean = 0
        self.estimated_time_remaining = 0
        self.pTick = 0
        self.SIG_hide.emit()

    def next_study(self, jumps=1):
        cl = clock()
        t = (cl - self.pTick) * 1.0

        self.read_time.append(t)
        if jumps > 1:
            for _ in range(jumps - 1):
                self.read_time.append(0.5)
        elif jumps <0:
            try:
                self.read_time = self.read_time[0:(jumps-1)]
            except:
                self.read_time=[]
        self.read_count += jumps

        if self.read_count == 1 and jumps == 1:
            self.read_time_mean = t
            self.read_time_sd = 0
        else:
            self.read_time_sd = stat.stdev(self.read_time)
            mean = stat.mean(self.read_time)
            in_range = [t for t in self.read_time if abs(t - mean) < 2 * self.read_time_sd]

            self.read_time_mean = stat.mean(in_range)

        etr = int((self.total_count - self.read_count) * self.read_time_mean)
        if etr < 0:
            self.estimated_time_remaining = ''
        elif etr < 60:
            self.estimated_time_remaining = '%d s' % (etr,)
        else:
            s = etr % 60
            m = int((etr - s) / 60)
            self.estimated_time_remaining = '%dm %ds' % (m, s)
        self.SIG_update_text.emit()

    def update_text(self):
        s = ('%d / %d\n%.1f ± %.1f\nETR: %s' % (self.read_count + 1
                                                , self.total_count
                                                , self.read_time_mean
                                                , self.read_time_sd
                                                , self.estimated_time_remaining))

        # self.progress_label.setText(QString.fromUtf8(s))
        self.progress_label.setText(s)
        # print s.decode('utf-8')

    def first_init(self):
        if self.total_count<1:
            return
        s = ('%d / %d\n\n' % (1, self.total_count))
        self.progress_label.setText(s)

    def show_self(self):
        self.show()

    def jump(self, jumps):
        pass


class ImageViewer(QMainWindow):
    SIG_load = Signal(int)
    SIG_show = Signal()
    SIG_load_old_hx = Signal(str)
    SIG_show_image = Signal(int, str, int)
    SIG_show_enable = Signal()
    SIG_hide_disable = Signal()
    SIG_next_image = Signal(str, int)
    SIG_prior_image = Signal(str, int)
    SIG_change_image = Signal(int, int, int)
    SIG_hide_count_label = Signal(int)
    SIG_show_count_label = Signal(int)
    SIG_hide_old_hx = Signal()
    SIG_clear_labels = Signal()
    SIG_border_color_toggle = Signal(bool)
    SIG_reset = Signal()

    def __init__(self, use_monitor=(1, -1), app=None):
        '''
        :param use_monitor: tuple, default with second to last monitor, use (None, None) for all monitors
        '''
        super(ImageViewer, self).__init__()

        logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name)
        self.load_lock = threading.Lock()
        self.show_lock = threading.Lock()
        self.setStyleSheet('background-color: black;')
        self.setWindowFlags(Qt.Tool | Qt.FramelessWindowHint)
        self.preloading_AccNo = ''
        self.app = app
        self.reset()
        self.study_index = -1
        self.viewer_index = -1

        monitors = get_monitors()
        if len(monitors) == 1:
            use_monitor = (0, 0)

        w_w = w_h = w_x = w_y = 0
        tmp_i = 0
        self.image_labels = []
        for i, m in enumerate(sorted(monitors, key=lambda m: m.x)):
            if i < use_monitor[0]:
                continue
            if i == use_monitor[0]:
                w_x, w_y = m.x, m.y
                self.app.x = m.x
                self.app.y = m.y
                self.app.h = m.height

            tmp_i += 1

            if m.height > w_h:
                w_h = m.height

            u = (m.height + m.width) / 4000.0  # length unit

            imageLabel = ImageLabel(self)
            imageLabel.label_index = len(self.image_labels)
            imageLabel.setStyleSheet('background-color: {};'.format('gray' if i==0 else 'black'))
            imageLabel.setFixedSize(m.width, m.height)
            imageLabel.setSizePolicy(QSizePolicy.Fixed, QSizePolicy.Fixed)
            # imageLabel.setScaledContents(True)
            imageLabel.setGeometry(w_w, 0, m.width, m.height)
            imageLabel.setAlignment(Qt.AlignCenter)
            imageLabel.fixedWidth = m.width
            imageLabel.fixedHeight = m.height

            countLabel = QLabel(imageLabel)
            countLabel.setStyleSheet('background-color: transparent; color: rgba(255,255,255,100); ')
            countLabel.setFixedSize(200 * u, 100 * u)
            countLabel.setGeometry(50 * u, 50 * u, 250 * u, 100 * u)
            countLabel.setFont(QFont("Verdana", 50 * u, QFont.Normal))

            curtainLabel = QLabel(imageLabel)
            curtainLabel.setStyleSheet('background-color: rgba(0,0,0,100); ')
            curtainLabel.setFixedSize(m.width, m.height)
            curtainLabel.setGeometry(w_w, 0, m.width, m.height)
            curtainLabel.hide()

            imageLabel.count_label = countLabel
            imageLabel.curtain_label = curtainLabel
            self.image_labels.append(imageLabel)

            if tmp_i == 2 or use_monitor[0] == use_monitor[1]:
                oldHxLabel = QTextEdit(self)
                oldHxLabel.setStyleSheet('background-color: rgba(0,0,0,50); color: rgba(255,255,255,200); ')
                oldHxLabel.viewport().setAutoFillBackground(False)
                oldHxLabel.setGeometry(w_w, m.height - 200 * u, m.width, 200 * u)
                oldHxLabel.setFont(QFont('Verdana', 24 * u, QFont.Normal))
                oldHxLabel.setReadOnly(True)
                # oldHxLabel.setText('test\ntest\ntest\ntest\ntest\ntest')
                # oldHxLabel.show()
                oldHxLabel.hide()
                self.old_hx_label = oldHxLabel

            w_w += m.width

            if i == use_monitor[1]:
                break

        infoLabel = QLabel(self)
        infoLabel.setStyleSheet('background-color: transparent; color: rgba(255,255,255,100); ')
        infoLabel.setFixedSize(250 * u, 100 * u)
        infoLabel.setGeometry(50 * u, 150 * u, 250 * u, 100 * u)
        infoLabel.setFont(QFont("Verdana", 24 * u, QFont.Normal))
        self.info_label = infoLabel

        infoLabel2 = QLabel(self)
        infoLabel2.setStyleSheet('background-color: transparent; color: rgba(255,255,255,100); ')
        infoLabel2.setFixedSize(1000 * u, 100 * u)
        infoLabel2.setGeometry(350 * u, 150 * u, 1000 * u, 100 * u)
        infoLabel2.setFont(QFont("Verdana", 18 * u, QFont.Normal))
        self.info_label2 = infoLabel2

        self.setFixedSize(w_w, w_h)
        self.move(w_x, w_y)
        self.hide()
        self.setEnabled(False)

        self.SIG_load.connect(self.load)
        self.SIG_show.connect(self.show)
        self.SIG_load_old_hx.connect(self.load_old_hx)
        self.SIG_show_image.connect(self.show_image)
        self.SIG_show_enable.connect(self.show_enable)
        self.SIG_hide_disable.connect(self.hide_disable)
        self.SIG_next_image.connect(self.next_image)
        self.SIG_prior_image.connect(self.prior_image)
        self.SIG_change_image.connect(self.change_image)
        self.SIG_hide_count_label.connect(self.hide_count_label)
        self.SIG_show_count_label.connect(self.show_count_label)
        self.SIG_hide_old_hx.connect(self.hide_old_hx)
        self.SIG_clear_labels.connect(self.clear_labels)
        self.SIG_border_color_toggle.connect(self.border_color_toggle)
        self.SIG_reset.connect(self.reset)

        # self._define_global_shortcuts()

        # def keyPressEvent(self, QKeyEvent):
        # if QKeyEvent.key() == Qt.Key_Z:
        #     image_label = self.image_labels[0]
        #     image_label.zooming_mode = not image_label.zooming_mode
        #     if not image_label.zooming_mode:
        #         image_label.SIG_set_pixmap.emit(image_label.original_px)

    # def keyReleaseEvent(self, QKeyEvent):
    #     if QKeyEvent.key()==Qt.Key_Z:
    #         image_label=self.image_labels[0]
    #         image_label.SIG_set_pixmap.emit(image_label.original_px)
    #         image_label.z_pressed=False
    def border_color_toggle(self, to_state=None):
        '''
        :param state: False to hide border
        :return:
        '''

        if to_state is not None:
            self.border_color_state = to_state
        else:
            self.border_color_state = ~self.border_color_state
        border_width = 5 if self.border_color_state else 0
        self.image_labels[0].setStyleSheet('ImageLabel {border: %dpx solid white;}' % (border_width,))

    def clear_labels(self):
        for l in self.image_labels:
            l.clear()

    def show_enable(self):
        self.setEnabled(True)
        # self.setWindowFlags(Qt.Tool | Qt.Widget | Qt.FramelessWindowHint | Qt.WindowSystemMenuHint | Qt.WindowStaysOnTopHint)
        self.show()
        self.activateWindow()
        map(lambda l: l.setEnabled(True), self.image_labels)

    def hide_disable(self):
        self.hide()
        # self.setWindowFlags(self.windowFlags() & ~Qt.WindowStaysOnTopHint)
        self.setEnabled(False)

    # def wheelEvent(self, QWheelEvent):
    #
    #     logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
    #     ind = -1
    #     for i, imageLabel in enumerate(self.image_labels):
    #         if imageLabel.contentsRect().contains(QWheelEvent.pos()):
    #             ind = i
    #             break
    #     if ind == -1:
    #         return
    #     if QWheelEvent.delta() < 0:
    #         self.next_image(index=ind)
    #     elif QWheelEvent.delta() > 0:
    #         self.prior_image(index=ind)

    # def _define_global_shortcuts(self):
    #
    #     shortcuts = []
    #
    #     sequence = {
    #         'Ctrl+Shift+Left': self.on_action_previous_comic_triggered,
    #         'Ctrl+Left': self.on_action_first_page_triggered,
    #         'Left': self.on_action_previous_page_triggered,
    #         'Right': self.on_action_next_page_triggered,
    #         'Ctrl+Right': self.on_action_last_page_triggered,
    #         'Ctrl+Shift+Right': self.on_action_next_comic_triggered,
    #         'Ctrl+R': self.on_action_rotate_left_triggered,
    #         'Ctrl+Shift+R': self.on_action_rotate_right_triggered,
    #     }
    #
    #     for key, value in list(sequence.items()):
    #         s = QWidget.QShortcut(QKeySequence(key),
    #                               self.ui.qscroll_area_viewer, value)
    #         s.setEnabled(False)
    #         shortcuts.append(s)
    #
    #     return shortcuts

    def reset(self):
        try:
            self.info_label.clear()
            self.info_label2.clear()
            self.old_hx_label.clear()
            list(map(lambda x: x.clear(), self.image_labels))
            list(map(lambda x: x.count_label.clear(), self.image_labels))
            list(map(lambda x: x.count_label.setText(''), self.image_labels))
            self.load_threads_ev.set()
            list(map(lambda x: x.join(), self.load_threads))
        except:
            pass


        self.old_hx = ''
        self.load_threads = []
        self.folder = ''
        self.expected_image_count = []
        self.total_image_count = 0
        self.loaded_image = OrderedDict()
        self.ind = OrderedDict()
        self.AccNo = ''
        self.ChartNo = ''
        self.ExamName = ''
        self.ExamDate = ''

        self.timers = []
        self.preprocessed = []
        self.load_image_th = []
        self.load_lock = threading.Lock()
        self.show_lock = threading.Lock()
        self.border_color_state = False

    def load(self, study_ind):

        study = self.app.study_list[study_ind]

        logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        logging.debug(study['ChartNo'])
        self.reset()

        ChartNo = study['ChartNo']
        AccNo = study['AccNo']
        folder_path = study['folder_path']

        # if False:
        if not 'expected_image_count' in study:

            study['expected_image_count'] = []
            dc = {}
            for im in Path(folder_path).glob('*.jpeg'):
                m = re.search(r'^([^\s]+)\s([^\s]+)\s(\d+)', im.name)
                if m:
                    if m.group(1) in dc:
                        dc[m.group(1)] += 1
                    else:
                        dc[m.group(1)] = 1
            for im in Path(folder_path).glob('*.dcm'):
                dcm = pydicom.dcmread(im, stop_before_pixels=True, force=True)
                try:
                    acc_no = dcm.AccessionNumber
                    if acc_no in dc:
                        dc[acc_no] += 1
                    else:
                        dc[acc_no] = 1
                except:
                    pass
            if not dc:
                for im in Path(folder_path).glob('**/*'):
                    dcm = pydicom.dcmread(im, stop_before_pixels=True, force=True)
                    try:
                        acc_no = dcm.AccessionNumber
                        if acc_no in dc:
                            dc[acc_no] += 1
                        else:
                            dc[acc_no] = 1
                    except:
                        pass



            if not dc:
                th = threading.Timer(1.0, partial(self.load, study_ind))
                th.start()
                return -1

            expected_image_count = dc[AccNo]

            for k, v in dc.items():
                if k==AccNo:
                    d = {}
                    d[k] = v
                    study['expected_image_count'].append(d)

            for k, v in dc.items():
                if k!=AccNo:
                    d = {}
                    d[k] = v
                    study['expected_image_count'].append(d)

        expected_image_count = study['expected_image_count']

        if self.expected_image_count == expected_image_count:
            th = threading.Timer(1.0, partial(self.load, study_ind))
            th.start()
            return

        self.ChartNo = ChartNo
        self.folder = folder_path
        self.expected_image_count = expected_image_count

        image_count_sum = 0

        if type(self.expected_image_count) is dict:
            self.expected_image_count = [self.expected_image_count]

        for image_count in self.expected_image_count:
            image_count_sum += sum(image_count.values())
        self.total_image_count = image_count_sum

        # with suppress(Exception):
        #     self.load_lock.release()
        map(lambda th: th.cancel(), self.load_image_th)
        self.load_image_th = []

        # self.load_dir()
        for i, d in enumerate(self.expected_image_count):
            if len(list(d.keys())) < 1:
                continue
            acc, image_count = list(d.keys())[0], list(d.values())[0]
            if i >= len(self.image_labels):
                break
            self.loaded_image[acc] = {}
            self.ind[acc] = ''
            th = threading.Timer(0.0001, partial(self.load_image, acc, image_count))
            self.load_image_th.append(th)
            th.start()
            self.next_image(acc, i)
        self.AccNo = AccNo

        self.info_label.setText(self.AccNo + '\n' + self.ChartNo)

        if 'ExamName' in study:
            self.ExamName = study['ExamName']
            self.ExamDate = study['ExamDate']
            self.info_label2.setText(self.ExamName + '\n' + self.ExamDate)
        # th = threading.Timer(1.0, partial(self.load, study_ind))
        # th.start()

    # def loading_image(self, AccNo, image_path):
    #     self.loaded_image[AccNo][image_path] = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)

    def load_image(self, AccNo, expected_count, ind=0):
        logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        AccNo, index = self.whichLabel(AccNo=AccNo)
        # last_k = 0
        # ind = 0
        if self.app.load_dir:
            for k, image_path in enumerate(self.app.accno_path[AccNo].glob('**/*')):
                if image_path not in self.loaded_image[AccNo]:
                    self.loaded_image[AccNo][image_path] = 'loading...'
                    dcm = pydicom.dcmread(image_path, force=True)
                    self.loaded_image[AccNo][image_path] = self.dcm_convert(dcm)
                    # threading.Thread(target=self.loading_image, args=(AccNo, image_path)).start()
                    # last_k = k
                    break

        else:
            # self.load_lock.acquire()
            for k, image_path in enumerate(glob.glob(os.path.join(self.folder, AccNo + ' *.jpeg'))):
                if image_path not in self.loaded_image[AccNo]:
                    # self.loaded_image[AccNo][image_path] = QImage(image_path)
                    self.loaded_image[AccNo][image_path] = 'loading...'
                    self.loaded_image[AccNo][image_path] = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
                    # threading.Thread(target=self.loading_image, args=(AccNo, image_path)).start()
                    # last_k = k
                    break
        is_done = len(self.loaded_image[AccNo]) < self.expected_image_count[index][AccNo]
        # self.load_lock.release()
        # if ind > 50:
        #     logging.error('load image timeout: %s expected %d images, only %d images' %
        #                   (AccNo, self.expected_image_count[index][AccNo], len(self.loaded_image[AccNo])))
        #     break
        if is_done:
            # sleep(0.5 if last_k == 0 else 0.1)
            # ind += 1
            tm = threading.Timer(0.1, self.load_image, [AccNo, expected_count, ind + 1])
            self.load_image_th.append(tm)
            tm.start()
            print(f'loading image: {AccNo}')
            return


    def load_single_image(self, AccNo, image_path):
        logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        # self.load_lock.acquire()
        self.loaded_image[AccNo][image_path] = image = QImage(image_path)
        # self.load_lock.release()
        return image
    def dcm_convert(self, dcm: pydicom.Dataset, depth=16):
        arr = dcm.pixel_array
        try:
            i = float(dcm.RescaleIntercept)
        except:
            i = 0

        try:
            s = float(dcm.RescaleSlope)
        except:
            s = 1

        arr = arr.astype(np.float64) *s+i
        range = 2**depth * 1.0
        min, max = dcm.WindowCenter-dcm.WindowWidth/2.0, dcm.WindowCenter+dcm.WindowWidth/2.0
        arr = np.clip(arr, min, max)
        arr-=min
        arr/=dcm.WindowWidth/range
        arr = np.clip(arr.astype(np.uint16), 0, int(range)-1)
        return arr

    def load_old_hx(self, old_hx):
        # print(self.AccNo)
        # print(old_hx)

        if old_hx.strip() == '':
            self.old_hx_label.clear()
            self.old_hx_label.hide()
        else:
            self.old_hx_label.setText(old_hx.strip())
            self.old_hx_label.show()

    def hide_old_hx(self):
        self.old_hx_label.hide()

    def whichLabel(self, AccNo='', index=0):
        if AccNo != '':
            for i, (acc, _) in enumerate(self.ind.items()):
                if acc == AccNo:
                    return (AccNo, i)
        else:
            return list(self.ind.items())[index][0], index

    def change_image(self, is_next, mouseX, mouseY):
        index = 0
        g = self.geometry()
        mouseX -= g.left()
        mouseY -= g.top()
        for i, image_label in enumerate(self.image_labels):
            if image_label.geometry().contains(mouseX, mouseY):
                index = i
                break
        if is_next:
            self.SIG_next_image.emit('', index)
        else:
            self.SIG_prior_image.emit('', index)

    def next_image(self, AccNo='', index=0):
        logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        # self.show_lock.acquire()
        AccNo, index = self.whichLabel(AccNo, index)
        expected_image_count = self.expected_image_count[index][AccNo]
        ind = self.ind[AccNo]

        if ind == '':
            ind = 0
        else:
            ind = (ind + 1) % expected_image_count
        self.ind[AccNo] = ind

        # self.show_image(ind, AccNo=AccNo)
        self.SIG_show_image.emit(ind, AccNo, 0)
        # self.after(1000, self.next_image)

    def prior_image(self, AccNo='', index=0):
        logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        # self.show_lock.acquire()
        AccNo, index = self.whichLabel(AccNo, index)
        expected_image_count = self.expected_image_count[index][AccNo]
        ind = self.ind[AccNo]

        if ind == '':
            ind = expected_image_count - 1
        else:
            ind = (ind + expected_image_count - 1) % expected_image_count
        self.ind[AccNo] = ind
        self.show_image(ind, AccNo=AccNo)

    def show_curtain(self, index=0, curtain_label=None):
        logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        if curtain_label is None:
            curtain_label = self.image_labels[index].curtain_label
        curtain_label.raise_()
        curtain_label.show()
        # curtain_label.activateWindow()

    def hide_count_label(self, index):
        self.image_labels[index].count_label.hide()

    def show_count_label(self, index):
        self.image_labels[index].count_label.show()

    def show_image(self, image_ind, AccNo='', index=0):
        logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        try:
            AccNo, index = self.whichLabel(AccNo, index)
        except:
            pass

        image_label = self.image_labels[index]
        image_label.count_label.setText('%d / %d' % (image_ind + 1,
                                                     self.expected_image_count[index][AccNo]))

        # if AccNo=='T0000000001':
        #     a=1

        try:
            image_label.count_label.hide_label_tm.cancel()
        except:
            pass
        finally:
            th = threading.Timer(1, lambda i: self.SIG_hide_count_label.emit(i), [index])
            th.start()
            image_label.count_label.hide_label_tm = th

        try:
            if self.app.load_dir:
                image_path = list(self.app.accno_path[AccNo].glob('**/*'))[index]
            else:
                image_path = glob.glob(os.path.join(self.folder, AccNo + ' ??????? ' + str(image_ind + 1) + '.jpeg'))[0]
        except:
            image_label.clear()
            # self.show_curtain(index=index)
            print(('Image %d not found!' % image_ind))
            threading.Timer(1, lambda args: self.SIG_show_image.emit(*args), [[image_ind, AccNo, index]]).start()
            return

        try:
            if image_path in self.loaded_image[AccNo]:
                while 1:
                    image = self.loaded_image[AccNo][image_path]
                    if image is None:
                        if 'jpeg' in image_path:
                            self.loaded_image[AccNo][image_path] = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
                        else:
                            self.loaded_image[AccNo][image_path] = self.dcm_convert(pydicom.dcmread(image_path, force=True))
                    elif type(image) is not str or image!='loading...':
                        break
            else:
                if 'jpeg' in image_path:
                    image = self.loaded_image[AccNo][image_path] = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
                else:
                    image = self.loaded_image[AccNo][image_path] = self.dcm_convert(pydicom.dcmread(image_path, force=True))
                # self.load_single_image(Acc, image_path, image)

            self.image_labels[index].curtain_label.hide()
            self.image_labels[index].count_label.show()
            self.info_label.show()
            self.info_label2.show()

            # TODO: keep preprocessed data according to image_ind, not image_label
            w = image_label.width()
            h = image_label.height()
            if self.app.load_dir:
                px = QPixmap.fromImage(
                    QImage(image.data, image.shape[1], image.shape[0], QImage.Format_Grayscale16)
                    .scaled(w, h, Qt.KeepAspectRatio, Qt.SmoothTransformation))
            else:
                px = QPixmap.fromImage(
                QImage(image.data, image.shape[1], image.shape[0], image.shape[1], QImage.Format_Indexed8)
                    .scaled(w, h, Qt.KeepAspectRatio, Qt.SmoothTransformation))

            scaled = px
            image_label.SIG_set_pixmap.emit(scaled)
            # image_label.setPixmap(scaled)
            image_label.setEnabled(True)
            image_label.show()
            # image_label.activateWindow()
        except:
            image_label.clear()
            # self.show_curtain(index=index)
            print(('Image %d not loaded!' % image_ind))
            threading.Timer(1, lambda args: self.SIG_show_image.emit(*args), [[image_ind, AccNo, index]]).start()
            return

        if not (self.app.fast_mode or self.app.turbo_mode):
            threading.Thread(target=self.preprocessing, args=(image_label, image, scaled)).start()
        # self.setWindowTitle(image_path)
        # self.show_lock.release()
        image_label.curtain_label.hide()
        if __is_win__:
            Send_WM_COPYDATA(self.app.bridge_hwnd, json.dumps({'activateSimpleRIS_2': 1}), self.app.dwData)

    def preprocessing(self, image_label, image, scaled):
        # cl=clock()
        if not self.app.preprocessing:
            return
        image_label.original_image = image
        image_label.base_image = image
        image_label.downsampled_image = cv2.resize(image.astype(np.float64),
                                                   (np.array(image.shape)*0.3).astype(np.int64))
        # image_label.downsampled_image = cv2.resize(image, (0, 0), fx=0.3, fy=0.3)
        image_label.base_px = scaled

        im = cv2.GaussianBlur(image, (0, 0), 10)
        cv2.addWeighted(image, 1.5, im, -0.5, 0, im)
        image_label.sharpen_image = im
        image_label.downsampled_sharpen_image = cv2.resize(im.astype(np.float64),
                                                           (np.array(im.shape)*0.3).astype(np.int64))
        # image_label.downsampled_sharpen_image = cv2.resize(im, (0, 0), fx=0.3, fy=0.3)
        # print clock()-cl


class ImageViewerApp(QApplication):
    dwData = 17

    SIG_show_study = Signal(int, int)
    SIG_next_study = Signal(int)
    SIG_activate_main = Signal()
    SIG_hide_all = Signal()
    SIG_show_dialog = Signal()

    def __init__(self, args, folderPath, totalViewer=None, load_dir=None, bridge_hwnd=None):
        super(ImageViewerApp, self).__init__(args)

        self.original_args = args
        self.screen_count = QDesktopWidget().screenCount()
        self.preprocessing = False
        self.if_mouse_event = False

        if totalViewer is None:
            # try:
            #     self.total_viewer_count = int(list[0])
            # except:
            #     self.total_viewer_count = 4
            if __is_win__:
                if self.screen_count<3:
                    self.total_viewer_count = 4
                else:
                    self.total_viewer_count = 8
            else:
                self.total_viewer_count = 4
            # print list
            # for v in args:
            #     try:
            #         self.total_viewer_count = int(v)
            #         break
            #     except:
            #         pass

        else:
            self.total_viewer_count = totalViewer


        # self.current_study = QMainWindow()
        self.folder_path = folderPath
        self.viewers = []
        self.viewer_index = -1
        self.study_index = -1
        self.show_index = -1
        self.study_list = {}
        self.preload_timers = []
        # self.portal = portalLib.Portal(noLogin=True)
        # self.study_list_lock = threading.Lock()
        self.show_study_lock = threading.Lock()
        self.load_thread_lock = threading.Lock()
        self.bridge_hwnd = bridge_hwnd
        self.old_hx_list = {}
        self.AccNo = ''
        self.old_hx_timer = None
        # self.old_hx_threads_ev = threading.Event()
        self.fast_mode = False
        self.turbo_mode = False


        self.turbo_unit = 8
        self.total_study_count = 0
        self.x = self.y = self.h = 0
        self.non_fast_mode_win_pos = []
        self.load_dir = Path(load_dir).expanduser().resolve() if load_dir else None

        if self.total_viewer_count > 2:
            self.preload_count = self.total_viewer_count - 2
        elif self.total_viewer_count > 1:
            self.preload_count = 1
        else:
            self.preload_count = 0

        for _ in range(self.total_viewer_count):
            _v = ImageViewer(app=self)
            _v.viewer_index = _
            self.viewers.append(_v)

        self.progressWin = ProgressWin(app=self)

        oldHxLabel = QLabel()
        oldHxLabel.setGeometry(0, 0, 0, 0)
        oldHxLabel.hide()
        self.oldHx_label = oldHxLabel

        self.SIG_show_study.connect(self.show_study)
        self.SIG_next_study.connect(self.next_study)
        self.SIG_activate_main.connect(self.activate_main)
        self.SIG_hide_all.connect(self.hide_all)
        self.SIG_show_dialog.connect(self.show_dialog)

        if self.load_dir:
            self.auto_load()
        if __is_win__:
            self.WM_COPYDATA_Listener = WM_COPYDATA_Listener(receiver=self.listener,
                                                         title='WM_COPYDATA_Listener_miniPACS')
        logging.info('----------APP READY----------')
        # self.next_study()

    def reset(self):
        with suppress(Exception):
            map(lambda t: t.cancel, self.preload_timers)
        map(lambda t: t.SIG_reset.emit(), self.viewers)
        # self.viewers = []
        # for _ in range(self.total_viewer_count):
        #     self.viewers.append(ImageViewer(app=self))
        self.progressWin.SIG_reset.emit()
        self.viewer_index = -1
        self.study_index = -1
        self.show_index = -1
        self.study_list = {}
        self.fast_mode = False
        self.turbo_mode = False
        self.turbo_unit = 8
        self.total_study_count = 0
        self.preload_timers = []
        with suppress(Exception):
            self.show_study_lock.release()
        with suppress(Exception):
            self.load_thread_lock.release()
        self.show_study_lock = threading.Lock()
        self.load_thread_lock = threading.Lock()
        # self.bridge_hwnd = 0
        self.old_hx_list = {}
        self.AccNo = ''
        self.old_hx_timer = None
        self.non_fast_mode_win_pos = []

    def auto_load(self):
        load_dir = self.load_dir
        dicom_images_dir = set()
        reported_txt = set()
        accno_chartno_re = re.compile('(\w+)[_ ](\w+)$')
        self.accno_path = {}
        self.dcm_info = {}

        for f in load_dir.iterdir():
            # if not accno_chartno_re.match(f.name):
            #     continue
            if f.is_dir():
                for f2 in f.glob('**/*'):
                    try:
                        dcm = pydicom.dcmread(f2, force=True, stop_before_pixels=True)
                        dicom_images_dir.add(dcm.AccessionNumber)
                        self.accno_path[dcm.AccessionNumber] = f
                        self.dcm_info[dcm.AccessionNumber] = dict(acc_no=dcm.AccessionNumber,
                                    chart_no=dcm.PatientID,
                                    exam_name=dcm.StudyDescription,
                                    exam_date=dcm.StudyDate)

                    except:
                        dicom_images_dir.add(f.name)
                        self.accno_path[f.name] = f
                    break

            elif '.txt' in f.name:
                reported_txt.add(f.stem)

        to_be_loaded = list(dicom_images_dir - reported_txt)
        to_be_loaded.sort(key=lambda x: os.path.getmtime(str(self.accno_path[x])))
        idx = 0
        for exam in to_be_loaded:
            matches = accno_chartno_re.search(exam)
            if matches:
                acc_no, chart_no = matches[1], matches[2]
            else:
                matches = accno_chartno_re.search(
                    self.accno_path[exam].stem if exam in self.accno_path else '')
                if matches:
                    acc_no, chart_no = matches[1], matches[2]
                else:
                    acc_no = exam
                    chart_no = ''
            exam_name = exam_date = ''
            if exam in self.dcm_info:
                exam_name = self.dcm_info[exam]['exam_name']
                exam_date = self.dcm_info[exam]['exam_date']
            study_info = dict(AccNo=acc_no, ChartNo=chart_no,
                              ExamName=exam_name, ExamDate=exam_date,
                              folder_path=str(self.accno_path[exam]))
            self.study_list[idx] = study_info
            idx+=1
        self.total_study_count = idx
        self.progressWin.total_count = self.total_study_count
        self.progressWin.SIG_first_init.emit()
        self.SIG_next_study.emit(0)


    def load(self, jsonStr):
        logging.info(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        return self.listener(dwData=ImageViewerApp.dwData, lpData=jsonStr)

    def request_study_list(self, ind):
        if __is_win__:
            Send_WM_COPYDATA(self.bridge_hwnd,
                         json.dumps({'request': ind}),
                         ImageViewerApp.dwData)

    def send_bridge(self, msg):
        if __is_win__:
            Send_WM_COPYDATA(self.bridge_hwnd,
                         json.dumps(msg),
                         ImageViewerApp.dwData)

    def listener(self, *args, **kwargs):
        # logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        try:
            if kwargs['dwData'] != ImageViewerApp.dwData:
                return

            json_data = json.loads(kwargs['lpData'])
            if 'study_data' in json_data:
                for k, l in json_data.items():
                    if k != 'study_data':
                        l['folder_path'] = os.path.join(self.folder_path, str(l['AccNo']) + ' ' + str(l['ChartNo']))
                        self.study_list[int(k)] = l
            elif 'oldHx' in json_data:
                self.old_hx_list.update(json_data['oldHx'])
                logging.debug(self.old_hx_list)
                # logging.warning(self.old_hx_list)
            elif 'next_study' in json_data:
                case = int(json_data['next_study'])
                if case == 1:
                    self.progressWin.next_study(case)
                    self.next_study()

                elif case > 1:
                    self.progressWin.next_study(case)
                    self.next_study(case, jump=True)

                else:
                    self.progressWin.next_study(-1)
                    self.prior_study()

                    # self.SIG_next_study.emit()
                    # QTimer.singleShot(0, self.next_study)
            elif 'next_image' in json_data:
                case = int(json_data['next_image'])

                self.viewers[self.viewer_index].SIG_change_image.emit(
                                                     case,
                                                     json_data['x'],
                                                     json_data['y'])
            elif 'activate_main' in json_data:
                self.SIG_activate_main.emit()
            elif 'setBridgeHwnd' in json_data:
                logging.debug('set bridge: ' + str(json_data['setBridgeHwnd']))
                self.bridge_hwnd = int(json_data['setBridgeHwnd'])

            elif 'total_study_count' in json_data:
                self.total_study_count = int(json_data['total_study_count'])
                self.progressWin.total_count = self.total_study_count
                self.progressWin.SIG_first_init.emit()
            elif 'request_info' in json_data:
                v = self.viewers[self.viewer_index]
                d = {}
                d['request_info'] = 1
                d['from'] = json_data['from']
                d['AccNo'] = v.AccNo
                d['ChartNo'] = v.ChartNo
                if __is_win__:
                    Send_WM_COPYDATA(self.bridge_hwnd, json.dumps(d), ImageViewerApp.dwData)
                if json_data['from'] == 'open_impax':
                    self.SIG_hide_all.emit()
            elif 'downloadPortalJpeg' in json_data:
                threading.Thread(target=self.portal.pacsMobileNewDownloadJpeg,
                                 args={'accNo': json_data['accNo'],
                                       'chartNo': json_data['chartNo'],
                                       'flatten': True,
                                       'folder': self.folder_path})
            elif 'sendReportEnd' in json_data:
                # self.progressWin.next_study(json_data['sendReportEnd'])
                pass
            elif 'fast_mode' in json_data:
                self.fast_mode = bool(json_data['fast_mode'])
                self.fast_mode_change()
            elif 'turbo_mode' in json_data:
                self.turbo_mode = bool(json_data['turbo_mode'])
                self.fast_mode_change()
            elif 'start_from' in json_data:
                self.SIG_next_study.emit(json_data['start_from'])
            elif 'reset_all' in json_data:
                self.reset()


        except Exception as e:
            print(e)
            return

    def fast_mode_change(self):
        monitors = get_monitors()
        self.use_monitor = (0,) if len(monitors) == 1 else (1,)
        self.monitors = sorted(monitors, key=lambda m: m.x)[self.use_monitor[0]:]
        self.monitors_total = len(self.monitors)

        if self.turbo_mode:
            expected_viewers_total = self.turbo_unit = 8
            if expected_viewers_total > self.total_viewer_count:
                for _ in range(expected_viewers_total - self.total_viewer_count):
                    self.viewers.append(ImageViewer(app=self))
                self.total_viewer_count = expected_viewers_total

            self.non_fast_mode_win_pos = []

            for mon_i in range(2):
                m = self.monitors[mon_i]
                w, h = int(m.width / 2.0), int(m.height / 2.0)
                x, y = np.full((4,), m.x), np.full((4,), m.y)
                x += np.array([0, w, w, 0])
                y += np.array([0, 0, h, h])
                for i, v in enumerate(self.viewers[(mon_i*4):(mon_i*4+4)]):
                    self.non_fast_mode_win_pos.append(v.geometry())
                    v.setFixedSize(w, h)
                    v.move(x[i], y[i])
                    v.image_labels[0].setFixedSize(w, h)


            swap_seq = [1,0,3,2,7,6,5,4]
            new_viewers = []
            for idx in swap_seq:
                new_viewers.append(self.viewers[idx])
            self.viewers = new_viewers


        elif (self.fast_mode and self.monitors_total == 1):
            expected_viewers_total = 4
            if expected_viewers_total > self.total_viewer_count:
                for _ in range(expected_viewers_total - self.total_viewer_count):
                    self.viewers.append(ImageViewer(app=self))
                self.total_viewer_count = expected_viewers_total

            self.non_fast_mode_win_pos = []
            m = self.monitors[0]
            w, h = int(m.width / 2.0), int(m.height / 2.0)
            x, y = np.full((4,), m.x), np.full((4,), m.y)
            x += np.array([0, w, w, 0])
            y += np.array([0, 0, h, h])
            for i, v in enumerate(self.viewers):
                self.non_fast_mode_win_pos.append(v.geometry())
                v.setFixedSize(w, h)
                v.move(x[i], y[i])
                v.image_labels[0].setFixedSize(w, h)

                # if self.first_launch:
                #     for i in range(3, 0, -1):
                #         self.viewers[i].SIG_show_enable.emit()
                #         self.preload(i+1)

        elif self.fast_mode:
            expected_viewers_total = self.monitors_total * 2
            if expected_viewers_total > self.total_viewer_count:
                for _ in range(expected_viewers_total - self.total_viewer_count):
                    self.viewers.append(ImageViewer(app=self))
                self.total_viewer_count = expected_viewers_total

            self.non_fast_mode_win_pos = []

            for i, v in enumerate(self.viewers):
                self.non_fast_mode_win_pos.append(v.geometry())

                m = self.monitors[i % self.monitors_total]
                v.setFixedSize(m.width, m.height)
                v.move(m.x, m.y)

            self.monitors_ind = 0
        else:
            stored_win_pos_count = len(self.non_fast_mode_win_pos)
            if stored_win_pos_count==0:
                return
            for i, v in enumerate(self.viewers):
                if i < stored_win_pos_count:
                    v.setGeometry(self.non_fast_mode_win_pos[i])
                else:
                    v.setGeometry(self.non_fast_mode_win_pos[stored_win_pos_count - 1])

        self.preload_count = self.total_viewer_count - 2

    def next_study(self, from_ind=None, retry=None, jump=False):
        logging.info(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')

        # if not from_ind in self.study_list:
        #     threading.Timer(0.5, self.next_study, [from_ind]).start()
        #     return

        with suppress(Exception):
            self.next_study_th.cancel()

        if from_ind==-1:
            from_ind=None

        self.show_study_lock.acquire()
        if from_ind is not None:
            from_ind = int(from_ind)
            # self.study_index = from_ind - 1
            if jump:
                thisStudyInd = self.study_index + from_ind
            else:
                thisStudyInd = from_ind
        else:
            thisStudyInd = self.study_index + 1

        if not thisStudyInd < self.total_study_count:
            with suppress(Exception):
                self.show_study_lock.release()
            self.viewers[self.viewer_index].SIG_hide_disable.emit()
            self.SIG_show_dialog.emit()
            self.send_bridge({'reach_end': 1})
            return
        if not thisStudyInd in self.study_list:
            if retry is None or retry < 10:
                self.show_study_lock.release()
                self.next_study_th = threading.Timer(0.5, self.next_study, [from_ind, retry + 1 if retry else 1])
                self.next_study_th.start()
            else:
                print('No information for study #' + str(thisStudyInd + 1) + '!!')
            with suppress(Exception):
                self.show_study_lock.release()
            return

        thisViewerInd = self.next_index(self.viewer_index + (from_ind - 1 if jump else 0), self.total_viewer_count)

        self.show_study(viewer=thisViewerInd, study=thisStudyInd, from_next=True,
                        jump=from_ind if jump else None)
        # self.SIG_show_study.emit(thisViewerInd, thisStudyInd)

        if self.turbo_mode:
            if self.show_index <= 1 or jump:
                for i in range(self.turbo_unit-1):
                    self.preload(i + 1, retry=1)
                    self.viewers[i + 1].SIG_show_enable.emit()
            else:
                self.preload(self.turbo_unit-1)
                self.viewers[(self.viewer_index + self.turbo_unit-1) % self.total_viewer_count].SIG_show_enable.emit()
                # pass
        else:

            try:
                list(map(lambda t: t.cancel(), self.preload_timers))
            except:
                pass
            finally:
                self.preload_timers = []
                for i in range(self.preload_count):
                    if i == 0:
                        self.preload()
                    elif self.fast_mode:
                        break
                    else:
                        th = threading.Timer(i / 2.0, partial(self.preload, i + 1))
                        th.start()
                        self.preload_timers.append(th)

    def prior_study(self):
        logging.info(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')

        with suppress(Exception):
            self.next_study_th.cancel()

        self.show_study_lock.acquire()
        thisStudyInd = self.study_index - 1
        if thisStudyInd < 0:
            print('Beyond first study!')
            with suppress(Exception):
                self.show_study_lock.release()
            return
        thisViewerInd = self.prior_index(self.viewer_index, self.total_viewer_count)

        self.show_study(viewer=thisViewerInd, study=thisStudyInd)
        # self.SIG_show_study.emit(thisViewerInd, thisStudyInd)

    def show_dialog(self):
        msg = QMessageBox()
        msg.setIcon(QMessageBox.Information)

        msg.setText("Already last study!\nExit?")
        msg.setWindowTitle("miniPACS")
        msg.setStandardButtons(QMessageBox.Ok | QMessageBox.Cancel)
        msg.setDefaultButton(QMessageBox.Ok)
        msg.setWindowFlags(msg.windowFlags() | Qt.WindowStaysOnTopHint)

        if msg.exec_() == QMessageBox.Ok:
            if __is_win__:
                Send_WM_COPYDATA(self.bridge_hwnd, json.dumps({'exit': 1}), ImageViewerApp.dwData)
            # stop_thread(self.WM_COPYDATA_Listener.thread)
            # self.WM_COPYDATA_Listener.quit()
            self.exit(0)
            # sys.exit(0)
            # self.quit()

    def show_study(self, viewer, study, from_next=False, jump=None):
        logging.info(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')

        viewer = int(viewer)
        study = int(study)

        w = self.viewers[viewer]
        s = self.study_list[study]
        AccNo = s['AccNo']
        ChartNo = s['ChartNo']

        if self.fast_mode:
            g = w.geometry()
            if __is_win__:
                Send_WM_COPYDATA(self.bridge_hwnd, json.dumps({'showStudy': 1, 'index': study, 'AccNo': AccNo,
                                                           'ChartNo': ChartNo,
                                                           'x': g.x(),
                                                           'y': g.y(),
                                                           'w': g.width(),
                                                           'h': g.height()}), ImageViewerApp.dwData)
            # self.current_study.setWindowTitle('CurrentStudy: ' + json.dumps({'showStudy': 1, 'index': study, 'AccNo': AccNo,
            #                                                'x': g.x(),
            #                                                'y': g.y(),
            #                                                'w': g.width(),
            #                                                'h': g.height()}))
        else:
            if __is_win__:
                Send_WM_COPYDATA(self.bridge_hwnd, json.dumps({'showStudy': 1, 'index': study, 'AccNo': AccNo,
                                                           'ChartNo': ChartNo, }), ImageViewerApp.dwData)
            # self.current_study.setWindowTitle(
            #     'CurrentStudy: ' + json.dumps({'showStudy': 1, 'index': study, 'AccNo': AccNo}))
        # print self.current_study.windowTitle()
        # Send_WM_COPYDATA(self.bridge_hwnd, json.dumps({'showStudy':1}), ImageViewerApp.dwData)

        c = self.viewers[self.viewer_index]
        c.study_index = study

        if w.AccNo != AccNo and w.preloading_AccNo != AccNo:
            # self.load_thread_lock.acquire()
            logging.info('load now')
            # w.load(**s)
            w.preloading_AccNo = AccNo
            w.SIG_load.emit(study)
            # SetWindowPos.insertAfter(w.winId(), c.winId())
            # self.load_thread_lock.release()

        w.SIG_hide_old_hx.emit()
        # WinToTop(w.winId())

        w.SIG_show_enable.emit()
        # w.setEnabled(True)
        # w.setWindowFlags(Qt.Widget | Qt.FramelessWindowHint | Qt.WindowSystemMenuHint | Qt.WindowStaysOnTopHint)
        # w.show()
        # w.activateWindow()

        # c.SIG_hide_disable.emit()

        # c.hide()
        # c.setEnabled(False)

        w.SIG_show_count_label.emit(0)
        th = threading.Timer(1, lambda i: w.SIG_hide_count_label.emit(i), [0])
        th.start()
        w.image_labels[0].count_label.hide_label_tm = th

        self.viewer_index = viewer
        self.study_index = study
        # print str(viewer) +','+str(study)
        if from_next:
            self.progressWin.pTick = clock()
            self.progressWin.SIG_show.emit()
        with suppress(Exception):
            self.show_study_lock.release()
        self.AccNo = AccNo

        # self.load_old_hx()
        if self.turbo_mode:
            for mw in self.viewers:
                if mw == w:
                    mw.SIG_border_color_toggle.emit(True)
                else:
                    mw.SIG_border_color_toggle.emit(False)
                    #
                    # if self.first_launch:
                    #     for i in range(3, 0, -1):
                    #         self.viewers[i].SIG_show_enable.emit()
                    # else:
                    #     c.SIG_border_color_toggle.emit()
                    #     self.viewers[(self.viewer_index + 3) % 4].SIG_show_enable.emit()
        elif not self.fast_mode:
            if not self.old_hx_timer:
                th = threading.Thread(target=partial(self.load_old_hx, AccNo, w))
                th.start()
                self.old_hx_timer = th

        self.show_index += 1

    def load_old_hx(self, AccNo=None, win=None):
        logging.debug(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        if AccNo is None:
            AccNo = self.AccNo
        if win is None:
            win = self.viewers[self.viewer_index]

        old_hx = self.old_hx_list.get(AccNo, '')

        if win.old_hx != old_hx:
            win.old_hx = old_hx

            win.SIG_load_old_hx.emit(old_hx)
            # win.old_hx_label.setText(old_hx)
            # if old_hx == '':
            #     win.old_hx_label.hide()
            # else:
            #     win.old_hx_label.show()
        if old_hx!='':
            th = threading.Timer(1.0, self.load_old_hx)
        else:
            th = threading.Timer(1.0, partial(self.load_old_hx, AccNo, win))

        th.start()
        self.old_hx_timer = th


    def hide(self):
        logging.info(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        self.show_study_lock.acquire()
        c = self.viewers[self.viewer_index]
        c.SIG_hide_disable.emit()
        with suppress(Exception):
            self.show_study_lock.release()

    def next_index(self, ind, total):
        return (ind + 1) % total

    def prior_index(self, ind, total):
        return (ind - 1 + total) % total

    def preload(self, inc=1, retry=None):
        logging.info(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')

        # self.load_thread_lock.acquire()
        # if inc==2:
        #     a=1
        preload_ind = (self.viewer_index + inc) % self.total_viewer_count
        preload_prior_ind = (self.viewer_index + inc - 1) % self.total_viewer_count
        study_ind = self.study_index + inc

        # hwndInsertAfter = self.viewers[preload_prior_ind].winId()
        # self.study_list_lock needed?
        if not study_ind < self.total_study_count:
            self.viewers[preload_ind].SIG_reset.emit()
            return

        # if study_ind not in self.study_list:
        #     if not self.turbo_mode:
        #         if retry is None or retry < 10:
        #             tm = threading.Timer(0.5, self.preload, [inc, retry + 1 if retry else 1])
        #             self.preload_timers.append(tm)
        #             tm.start()
        #         else:
        #             threading.Thread(target=self.request_study_list, args=(study_ind,)).start()
        #     elif retry and retry < 10:
        #         tm = threading.Timer(0.5, self.preload, [inc, retry + 1])
        #         self.preload_timers.append(tm)
        #         tm.start()
        #
        #     return

        study = self.study_list[study_ind]
        viewer = self.viewers[preload_ind]
        if viewer.AccNo != study['AccNo'] and viewer.preloading_AccNo != study['AccNo']:
            # viewer.load(**study)
            viewer.SIG_clear_labels.emit()
            viewer.SIG_load.emit(study_ind)
            viewer.preloading_AccNo = study['AccNo']
            viewer.old_hx = ''

            if self.fast_mode and inc == 1:
                viewer.SIG_show_enable.emit()

                # SetWindowPos.insertAfter(viewer.winId(), hwndInsertAfter)

                # viewer.show()
                # if inc == 1:
                #     viewer.SIG_show.emit()
                # self.load_thread_lock.release()

    def save_report(self, next=True):
        logging.info(str(self) + ': ' + inspect.currentframe().f_code.co_name + '\n' + str(locals()) + '\n')
        study = self.study_list[self.study_index]
        try:
            if __is_win__:
                Send_WM_COPYDATA(self.bridge_hwnd, json.dumps(study), ImageViewerApp.dwData)
            if next:
                self.SIG_next_study.emit()
        except:
            return

    def activate_main(self):
        self.viewers[self.viewer_index].SIG_show_enable.emit()

    def hide_all(self):
        self.viewers[self.viewer_index].SIG_hide_disable.emit()
        for w in self.viewers:
            w.SIG_hide_disable.emit()


def getMyDocPath():
    if __is_win__:
        CSIDL_PERSONAL = 5  # My Documents

        SHGFP_TYPE_CURRENT = 0  # Want current, not default value
        buf = ctypes.create_unicode_buffer(ctypes.wintypes.MAX_PATH)
        ctypes.windll.shell32.SHGetFolderPathW(0, CSIDL_PERSONAL, 0, SHGFP_TYPE_CURRENT, buf)
        return buf.value
    else:
        return str(Path('~').expanduser().resolve())


def parse_args():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--dir', nargs='?', help='parse specified dir')
    parser.add_argument('--bridge', nargs='?', help='bridge hwnd')
    parser.add_argument('--viewers', nargs='?', help='bridge hwnd')
    return parser.parse_args()

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    args = parse_args()

    app = ImageViewerApp(sys.argv, os.path.join(getMyDocPath(), 'feedRIS'),
                         totalViewer=args.viewers,
                         load_dir = args.dir, bridge_hwnd = args.bridge)

    sys.exit(app.exec_())
