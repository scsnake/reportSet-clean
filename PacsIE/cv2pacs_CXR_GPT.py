from pathlib import Path
import pydicom
import matplotlib.pyplot as plt
import numpy as np
from screeninfo import get_monitors
from threading import Thread
import traceback

def display_image(index):
    global last_read

    if 0 <= index < len(dicom_files):
        dicom_file = dicom_files[index]
        with open(last_read, 'w') as f:
            f.write(str(dicom_file.resolve()))

        dcm = load_dcm(index, dicom_file)
        pixel_data = dcm.pixel_array


        acc_no = chart_no = exam_date = exam_name = '???'
        try:
            acc_no = dcm.AccessionNumber
            chart_no = dcm.PatientID
            exam_date = dcm.StudyDate
            exam_name = dcm.StudyDescription
        except:
            traceback.print_exc()
            print(dcm)
        window_name = '{}/{}: {} | {} | {}'.format(index+1, len(dicom_files), acc_no, chart_no, exam_name)


        bits = dcm.BitsStored
        max_value = 2 ** bits


        # if pixel_data[-11:-1, 0:10].sum()+pixel_data[-11:-1, -11:-1].sum()>max_value*100:
        if dcm.PhotometricInterpretation == 'MONOCHROME1':
            pixel_data = max_value - pixel_data

        # has_loaded_dcm = None
        ax.clear()

        ax.imshow(pixel_data, cmap='gray', vmin=0, vmax=max_value)
        ax.set_title(window_name)

        # load_next_th = Thread(target=load_next, args=(index,))
        # load_next_th.start()
        # del_prv_th = Thread(target=delete_prv, args=(index,))
        # del_prv_th.start()

        print('displaying index', index)
        plt.draw()

def load_next(index):
    # if 0 <= index < len(dicom_files):
    #     has_loaded_dcm = load_dcm(dicom_files[index])
    #     print('loading index', index)
    for ind in range(index+1, index+6):
        load_dcm(ind, dicom_files[ind])

def load_dcm(image_ind, dicom_file):
    global image_pool

    path = str(dicom_file.resolve())
    dcm = image_pool.get(path, None)
    if dcm is None:
        dcm = pydicom.dcmread(dicom_file, force=True)
        # pixel_data = dcm.pixel_array
        # image_pool[path] = dcm

    return dcm

def delete_prv(index):
    for ind in range(index-25, index-15):
        try:
            del image_pool[dicom_files[ind % len(dicom_files)]]
        except:
            pass


def on_key(event):
    global image_index
    if event.key == 'up':
        image_index = (image_index - 1) % len(dicom_files)
    elif event.key == 'down':
        image_index = (image_index + 1) % len(dicom_files)
    elif event.key == 'escape':
        plt.close()
        return
    display_image(image_index)

def background_loader_all():
    for image_ind in range(start_ind+9, start_ind+4+len(dicom_files)):
        try:
            image_ind = image_ind % len(dicom_files)
            load_dcm(image_ind, dicom_files[image_ind])
        except:
            traceback.print_exc()


if __name__=='__main__':

    # Specify the directory containing the DICOM files
    specify_date = ''
    dicom_directory = Path(r"D:\scsnake\CXR_health")

    if specify_date:
        dicom_directory = dicom_directory.joinpath(specify_date)
    else:
        dirs = [i.stem for i in dicom_directory.iterdir() if i.is_dir()]
        dirs.sort(reverse=True)
        dicom_directory = dicom_directory.joinpath(dirs[0])

    last_read = Path('./CXR_last')
    start_ind = 0 # 1-based

    # Get a list of DICOM files in the directory
    dicom_files = [file for file in dicom_directory.iterdir() if not file.is_dir() and file.name!= 'sync.ffs_lock']
    dicom_files.sort(key=lambda f: f.stem)

    if start_ind == 0:

        if last_read.exists():
            with open(last_read, 'r') as f:
                last_read_file = f.read().strip()
            for i, dicom_file in enumerate(dicom_files):
                if str(dicom_file.resolve()) == last_read_file:
                    start_ind = i+1
                    break
            else:
                start_ind = 1
        else:
            start_ind = 1



    image_pool = dict()
    # for image_ind in range(start_ind-1, start_ind+4):
    #     load_dcm(image_ind % len(dicom_files), dicom_files[image_ind])

    # th = Thread(target=background_loader_all)
    # th.start()
    load_next_th = None
    del_prv_th = None

    # Initialize monitor information
    monitors = get_monitors()
    if len(monitors) > 1:
        second_monitor = monitors[1]
        screen_width = second_monitor.width
        screen_height = second_monitor.height
        x, y = second_monitor.x, second_monitor.y
    else:
        screen_width, screen_height = monitors[0].width, monitors[0].height
        x, y = monitors[0].x, monitors[0].y

    plt.style.use('dark_background')
    # Initialize Matplotlib figure
    fig, ax = plt.subplots()
    plt.xticks([])
    plt.yticks([])


    ax.xaxis.set_tick_params(labelbottom=False)
    ax.yaxis.set_tick_params(labelleft=False)
    fig.canvas.set_window_title("DICOM Viewer")
    plt.subplots_adjust(left=0, bottom=0, right=1, top=1, wspace=0, hspace=0)

    # Initialize image index
    image_index = start_ind-1

    # Initial display
    display_image(image_index)

    fig.canvas.mpl_connect('key_press_event', on_key)
    plt.get_current_fig_manager().window.setGeometry(x,y,screen_width, screen_height)

    plt.show()
