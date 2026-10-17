import SimpleITK as sitk
import multiprocessing
import os
import sys
from pathlib import Path
import argparse
import pydicom, json, pickle, traceback
from pydicom.pixel_data_handlers.util import apply_voi_lut
import cv2
import png
import numpy as np
from scipy.ndimage import zoom
from time import sleep

def zoom_within(im, max_width=1890):
    swapped=False
    if im.shape[0]>im.shape[1]:
        swapped=True
        im = np.swapaxes(im, 0, 1)

    if im.shape[1]>max_width:
        im = zoom(im, max_width/im.shape[1])

    if swapped:
        im = np.swapaxes(im, 0, 1)

    return im



def convert_image2(input_file_name, output_file_name, max_width=1890):
    try:
        print('Converting', input_file_name, 'to', output_file_name)
        ds = pydicom.dcmread(input_file_name, force=True)
        img = apply_voi_lut(ds.pixel_array, ds)
        # cv2.imwrite(output_file_name, img, )
        try:
            inverted = ds['00280004'].value=='MONOCHROME1'
        except:
            inverted = False

        img = zoom_within(img, max_width=max_width)
        img -= img.min()

        with open(output_file_name, 'wb') as f:
             # depth_image = (depth_map * 256.0).astype(np.uint16)
             depth_image = (img/img.max()*1023).astype(np.uint16)
             if inverted:
                 depth_image = 1023 - depth_image

             writer = png.Writer(width=depth_image.shape[1],
                                 height=depth_image.shape[0],
                                 bitdepth=10,
                                 greyscale=True)
             writer.write(f, depth_image)

        return True
    except BaseException as e:
        return False

def convert_image(input_file_name, output_file_name):
    try:
        image_file_reader = sitk.ImageFileReader()
        # only read DICOM images
        image_file_reader.SetImageIO("GDCMImageIO")
        image_file_reader.SetFileName(input_file_name)
        image_file_reader.ReadImageInformation()
        image_size = list(image_file_reader.GetSize())
        if len(image_size) == 3 and image_size[2] == 1:
            image_size[2] = 0
        image_file_reader.SetExtractSize(image_size)
        image = image_file_reader.Execute()

        # If a single channel image, rescale to [0,255]. Also modify the
        # intensity values based on the photometric interpretation. If
        # MONOCHROME2 (minimum should be displayed as black) we don't need to
        # do anything, if image has MONOCRHOME1 (minimum should be displayed as
        # white) we flip # the intensities. This is a constraint imposed by ITK
        # which always assumes MONOCHROME2.
        if image.GetNumberOfComponentsPerPixel() == 1:
            image = sitk.RescaleIntensity(image, 0, 255)
            if (
                    image_file_reader.GetMetaData("0028|0004").strip()
                    == "MONOCHROME1"
            ):
                image = sitk.InvertIntensity(image, maximum=255)
            image = sitk.Cast(image, sitk.sitkUInt8)
        sitk.WriteImage(image, output_file_name)
        return True
    except BaseException:
        return False


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--dir', type=str, help='root dir containing all DICOM files')
    args = parser.parse_args()
    root_dir = Path(r'~/Downloads/test/')
    # root_dir = Path(args.dir).expanduser().resolve()
    root_dir = root_dir.expanduser().resolve()
    out_ext = '.png'
    finished_count = 0

    while True:
        if finished_count>3:
            sys.exit()
        processed = 0

        for f in root_dir.glob('**/*.dcm'):
            out_info = f.parent.joinpath(f.stem + '.pkl')
            if not out_info.exists():
                info = {}
                try:
                    dcm = pydicom.dcmread(f, force=True, stop_before_pixels=True)
                    info['AccNo'] = dcm.AccessionNumber
                    info['ChartNo'] = dcm.PatientID
                    info['StudyDate'] = dcm.StudyDate
                    info['StudyDescription'] = dcm.StudyDescription
                    with open(out_info, 'wb') as out_info_f:
                        pickle.dump(info, out_info_f, protocol=pickle.HIGHEST_PROTOCOL)
                except:
                    traceback.print_exc()


            out_pic = f.parent.joinpath(f.stem + out_ext)
            if out_pic.exists():
                continue
            if convert_image2(str(f.resolve()), str(out_pic.resolve())):
                print('Saved:', out_pic.name)
                processed +=1

        if processed == 0:
            finished_count += 1
            sleep(5*finished_count)
        else:
            finished_count=0
    #
    # for f in root_dir.glob('**/*.dcm'):
    #  out_info = f.parent.joinpath(f.stem + '.pkl')
    #  if not out_info.exists():
    #      info = {}
    #      try:
    #          dcm = pydicom.dcmread(f, force=True, stop_before_pixels=True)
    #          info['AccNo']=dcm.AccessionNumber
    #          info['ChartNo']=dcm.PatientID
    #          info['StudyDate']=dcm.StudyDate
    #          info['StudyDescription']=dcm.StudyDescription
    #          with open(out_info, 'wb') as out_info_f:
    #              pickle.dump(info, out_info_f, protocol=pickle.HIGHEST_PROTOCOL)
    #      except:
    #          traceback.print_exc()
    #
    #  out_pic = f.parent.joinpath(f.stem + out_ext)
    #  if out_pic.exists():
    #      continue
    #  if convert_image2(str(f.resolve()), str(out_pic.resolve())):
    #      print('Saved:', out_pic.name)