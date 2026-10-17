import sys
import pydicom
import numpy as np
from PySide2.QtWidgets import QApplication, QMainWindow, QGraphicsView, QGraphicsScene, QPushButton, QVBoxLayout, QWidget, QLabel
from PySide2.QtCore import Qt, QRunnable, QThreadPool, Slot
from PySide2.QtGui import QPixmap, QImage, QPainter
from pathlib import Path
from screeninfo import get_monitors  # Import the screeninfo package


class ImageLoader(QRunnable):
    def __init__(self, dicom_file, contrast, brightness, main=None):
        super().__init__()
        self.dicom_file = dicom_file
        self.contrast = contrast
        self.brightness = brightness
        self.main = main

    @Slot()
    def run(self):
        dcm = pydicom.dcmread(self.dicom_file, force=True)
        pixel_data = dcm.pixel_array

        acc_no = dcm.AccessionNumber
        chart_no = dcm.PatientID
        exam_date = dcm.StudyDate
        exam_name = dcm.StudyDescription
        # window_name = '{}/{}: {} | {} | {}'.format(index + 1, len(dicom_files), acc_no, chart_no, exam_name)

        bits = dcm.BitsStored
        max_value = 2 ** bits

        if dcm.PhotometricInterpretation == 'MONOCHROME1':
            pixel_data = max_value - pixel_data

        # Adjust contrast and brightness
        adjusted_data = pixel_data * self.contrast + self.brightness
        adjusted_data = np.clip(adjusted_data, 0, 4095)  # Ensure pixel values stay within bounds

        image = QImage(adjusted_data.data, pixel_data.shape[1], pixel_data.shape[0], pixel_data.shape[1], QImage.Format_Grayscale16)
        pixmap = QPixmap.fromImage(image)

        # viewer.update_image(pixmap)
        self.main.image_view.setPixmap(pixmap)

class DICOMViewer(QMainWindow):
    def __init__(self, directory, start_ind=1):
        super().__init__()

        dicom_files = [file for file in directory.iterdir() if not file.is_dir()]
        dicom_files.sort()
        self.dicom_files = dicom_files
        self.image = None
        self.contrast = 1.0
        self.brightness = 0.0
        self.current_index = start_ind-1
        self.thread_pool = QThreadPool()

        self.initUI()
        self.load_current_image()

    def initUI(self):
        self.image_view = QLabel()
        self.setCentralWidget(self.image_view)

        self.layout = QVBoxLayout()
        self.layout.addWidget(self.image_view)

        self.button_previous = QPushButton("Previous")
        self.button_next = QPushButton("Next")

        self.button_previous.clicked.connect(self.show_previous_image)
        self.button_next.clicked.connect(self.show_next_image)

        self.layout.addWidget(self.button_previous)
        self.layout.addWidget(self.button_next)

        central_widget = QWidget()
        central_widget.setLayout(self.layout)
        self.setCentralWidget(central_widget)

    def load_current_image(self):
        if 0 <= self.current_index < len(self.dicom_files):
            dicom_file = self.dicom_files[self.current_index]

            # Load the next image in the background using QThreadPool
            # next_index = self.current_index + 1
            # if next_index < len(self.dicom_files):
            #     next_dicom_file = self.dicom_files[next_index]
            #     self.load_next_image(next_dicom_file)

            # Load the current image using QThreadPool
            loader = ImageLoader(dicom_file, self.contrast, self.brightness, main=self)
            # self.thread_pool.start(loader)
            loader.run()

    def load_next_image(self, dicom_file):
        # Load the next image using QThreadPool
        next_loader = ImageLoader(dicom_file, self.contrast, self.brightness)
        self.thread_pool.start(next_loader)

    # def update_image(self, pixmap):
    #     self.image = pixmap
    #     self.repaint()
    #
    # def paintEvent(self, event):
    #     if self.image:
    #         painter = QPainter(self)
    #         painter.drawPixmap(0, 0, self.image)

    def show_previous_image(self):
        self.current_index -= 1
        self.load_current_image()

    def show_next_image(self):
        self.current_index += 1
        self.load_current_image()

if __name__ == '__main__':
    directory = Path(r"D:\scsnake\CXR_health")
    start_ind = 1 # 1 based
    app = QApplication(sys.argv)

    # Get the second monitor's dimensions using the screeninfo package
    monitors = get_monitors()
    if len(monitors) > 1:
        second_monitor = monitors[1]  # Assuming the second monitor exists
        viewer = DICOMViewer(directory, start_ind)
        viewer.show()

        viewer.setGeometry(second_monitor.x, second_monitor.y, second_monitor.width, second_monitor.height)


    sys.exit(app.exec_())
