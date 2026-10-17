import sys
import os  # Needed for fsync
import subprocess  # Needed for explorer
import pydicom
import numpy as np
import gc
import platform
from pathlib import Path
from pydicom.tag import Tag

from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QLabel, QVBoxLayout,
                               QMessageBox, QDialog, QListWidget, QPushButton,
                               QDialogButtonBox, QFileDialog, QListWidgetItem,
                               QLineEdit, QHBoxLayout, QSizePolicy)
from PySide6.QtCore import Qt, QThread, QObject, Signal, Slot, QPoint, QTimer
from PySide6.QtGui import QIntValidator, QFont, QSurfaceFormat
from PySide6.QtOpenGLWidgets import QOpenGLWidget
from OpenGL import GL

# --- CONFIGURATION ---
def _sorted_screens():
    """Screens sorted by X position (left to right)."""
    return sorted(QApplication.screens(), key=lambda s: s.geometry().x())


CONFIG_FILE = Path.home() / ".dicom_viewer_last_viewed.txt"
ALIGN_DEBUG_LOG = Path.home() / ".dicom_viewer_align_debug.txt"
PROBLEM_TAG = 0x00081111
DEFAULT_WC = 150
DEFAULT_WW = 300
PLAY_INTERVAL = 500
INFO_UPDATE_DELAY = 1000  # 1.0 second delay for title update & auto-save
ZOOM_SENSITIVITY = 0.005  # Matches legacy viewer


# --- Helper Functions ---
def read_and_fix_corrupted_dicom(file_path):
    try:
        tag_to_remove = Tag(PROBLEM_TAG)
        dataset = pydicom.dcmread(file_path, defer_size="2 MB", force=True)
        if tag_to_remove in dataset:
            del dataset[tag_to_remove]
        return dataset
    except Exception:
        return pydicom.dcmread(file_path, force=True)


def _try_recover_pixel_array(dcm):
    """Zero-pad truncated PixelData to expected size and retry pixel_array."""
    try:
        rows = int(dcm.get('Rows', 0))
        cols = int(dcm.get('Columns', 0))
        bits = int(dcm.get('BitsAllocated', 16))
        samples = int(dcm.get('SamplesPerPixel', 1))
        if rows > 0 and cols > 0 and bits > 0:
            expected = rows * cols * samples * (bits // 8)
            raw = bytes(dcm.PixelData) if hasattr(dcm, 'PixelData') else b''
            if len(raw) < expected:
                dcm.PixelData = raw + b'\x00' * (expected - len(raw))
                return dcm.pixel_array.astype(np.uint16)
    except Exception:
        pass
    return None


# --- Experimental CXR Alignment Worker ---
# Intended behavior:
# - While rapidly reviewing one folder/date of CXR images, estimate a view preset
#   for every image so the two lung fields stay roughly centered and similarly
#   sized across cases.
# - Use fast downsampled pixel statistics only. This is deliberately not a
#   diagnostic segmentation model.
# - Exclude extra-body air, find the largest right/left lung-shadow components,
#   then use the two lung centroids/bounding boxes to compute a series-median
#   reference, zoom, and pan.
# - Also derive a conservative per-image WC/WW from body histogram percentiles
#   to reduce brightness/contrast jumps without hiding lung markings.
#
# Current status / known issue:
# - Direct tests on D:\scsnake\CXR_health\20260425 produced usable stats for
#   95/95 images and final alignment presets for 94/95 images.
# - The live viewer path has still been observed to show "ALIGN FAILED 0".
#   Keep this block marked experimental until that runtime discrepancy is fixed.
# - Runtime diagnostics are written to ALIGN_DEBUG_LOG when the worker finishes.
class LungAlignWorker(QThread):
    progress = Signal(int, int)  # processed, total
    alignment_finished = Signal(dict)  # {index: {'zoom': float, 'pan': [x, y], 'wc': float, 'ww': float}}

    def __init__(self, file_list, ref_index):
        super().__init__()
        self.files = file_list
        self.ref_index = ref_index
        self.is_running = True

    @staticmethod
    def _robust_normalize(arr):
        finite = arr[np.isfinite(arr)]
        if finite.size == 0:
            return None
        lo, hi = np.percentile(finite, [1.0, 99.0])
        if hi <= lo:
            lo, hi = finite.min(), finite.max()
        if hi <= lo:
            return None
        return np.clip((arr - lo) / (hi - lo), 0.0, 1.0)

    @staticmethod
    def _largest_component(mask, min_area):
        h, w = mask.shape
        seen = np.zeros(mask.shape, dtype=bool)
        best = None
        best_area = 0

        ys, xs = np.where(mask)
        for start_y, start_x in zip(ys, xs):
            if seen[start_y, start_x]:
                continue

            stack = [(int(start_y), int(start_x))]
            seen[start_y, start_x] = True
            area = 0
            sum_x = 0
            sum_y = 0
            min_x = max_x = int(start_x)
            min_y = max_y = int(start_y)

            while stack:
                y, x = stack.pop()
                area += 1
                sum_x += x
                sum_y += y
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)

                for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))

            if area >= min_area and area > best_area:
                best_area = area
                best = {
                    'area': area,
                    'cx': sum_x / area,
                    'cy': sum_y / area,
                    'bbox': [min_x, min_y, max_x, max_y],
                }

        return best

    @staticmethod
    def _profile_bounds(mask, axis, min_fraction):
        prof = mask.mean(axis=axis)
        idx = np.where(prof > min_fraction)[0]
        if len(idx) < 2:
            return None
        return int(idx[0]), int(idx[-1])

    def _extract_stats(self, ds):
        if not hasattr(ds, 'PixelData'):
            return None

        try:
            full = ds.pixel_array.astype(np.float32)
        except Exception:
            recovered = _try_recover_pixel_array(ds)
            if recovered is None:
                return None
            full = recovered.astype(np.float32)

        stride = max(8, int(max(full.shape) / 96))
        raw = full[::stride, ::stride]
        norm = self._robust_normalize(raw)
        if norm is None:
            return None

        photometric = ds.get('PhotometricInterpretation', 'MONOCHROME2')
        lung_bright = 1.0 - norm if photometric == 'MONOCHROME2' else norm
        tissue_bright = norm if photometric == 'MONOCHROME2' else 1.0 - norm

        # Use tissue-containing rows/columns to crop away extra-body air before
        # searching for the two largest air-density lung shadows.
        tissue_thr = np.percentile(tissue_bright, 45.0)
        tissue_mask = tissue_bright > tissue_thr
        y_bounds = self._profile_bounds(tissue_mask, axis=1, min_fraction=0.02)
        x_bounds = self._profile_bounds(tissue_mask, axis=0, min_fraction=0.02)
        if not y_bounds or not x_bounds:
            return None

        y1, y2 = y_bounds
        x1, x2 = x_bounds
        h = y2 - y1 + 1
        w = x2 - x1 + 1
        if h < 12 or w < 12:
            return None

        pad_y = max(1, int(h * 0.03))
        pad_x = max(1, int(w * 0.03))
        y1 = min(max(0, y1 + pad_y), raw.shape[0] - 1)
        y2 = max(min(raw.shape[0] - 1, y2 - pad_y), y1 + 1)
        x1 = min(max(0, x1 + pad_x), raw.shape[1] - 1)
        x2 = max(min(raw.shape[1] - 1, x2 - pad_x), x1 + 1)

        body = lung_bright[y1:y2 + 1, x1:x2 + 1]
        if body.size == 0:
            return None

        body_span_mask = np.zeros(body.shape, dtype=bool)
        local_tissue = tissue_mask[y1:y2 + 1, x1:x2 + 1]
        for row_idx in range(local_tissue.shape[0]):
            cols = np.where(local_tissue[row_idx])[0]
            if len(cols) >= 2:
                body_span_mask[row_idx, int(cols[0]):int(cols[-1]) + 1] = True
        if body_span_mask.mean() < 0.20:
            body_span_mask[:, :] = True

        # Lung shadows are bright after photometric normalization. A percentile
        # threshold adapts to portable/AP/PA exposure differences better than a
        # fixed intensity cutoff.
        search_values = body[body_span_mask]
        if search_values.size < 20:
            return None
        local_h, local_w = body.shape
        mid = local_w // 2
        left = right = None
        for pct, area_frac in ((65.0, 0.012), (58.0, 0.008), (52.0, 0.004)):
            lung_thr = np.percentile(search_values, pct)
            candidate = (body > lung_thr) & body_span_mask

            # Avoid diaphragm/lower abdomen dominance and tiny label artifacts.
            candidate[:max(1, int(local_h * 0.05)), :] = False
            candidate[int(local_h * 0.92):, :] = False
            min_area = max(5, int(local_h * local_w * area_frac))

            left = self._largest_component(candidate[:, :mid], min_area)
            right = self._largest_component(candidate[:, mid:], min_area)
            if left is not None and right is not None:
                break
        if left is None or right is None:
            return None

        right['cx'] += mid
        right['bbox'][0] += mid
        right['bbox'][2] += mid

        left_cx = x1 + left['cx']
        left_cy = y1 + left['cy']
        right_cx = x1 + right['cx']
        right_cy = y1 + right['cy']
        pair_distance = abs(right_cx - left_cx)
        if pair_distance < raw.shape[1] * 0.12:
            return None

        mid_x = (left_cx + right_cx) / 2.0
        mid_y = (left_cy + right_cy) / 2.0
        area_balance = min(left['area'], right['area']) / max(left['area'], right['area'])
        vertical_balance = 1.0 - min(1.0, abs(left_cy - right_cy) / max(1.0, local_h * 0.35))
        confidence = 0.5 * area_balance + 0.5 * vertical_balance
        if confidence < 0.35:
            return None

        true_values = full * float(ds.get('RescaleSlope', 1.0)) + float(ds.get('RescaleIntercept', 0.0))
        fy1 = max(0, min(true_values.shape[0] - 1, y1 * stride))
        fy2 = max(fy1 + 1, min(true_values.shape[0], (y2 + 1) * stride))
        fx1 = max(0, min(true_values.shape[1] - 1, x1 * stride))
        fx2 = max(fx1 + 1, min(true_values.shape[1], (x2 + 1) * stride))
        roi = true_values[fy1:fy2, fx1:fx2]
        finite_roi = roi[np.isfinite(roi)]
        if finite_roi.size:
            p_low, p_high = np.percentile(finite_roi, [2.0, 98.0])
        else:
            p_low, p_high = DEFAULT_WC - DEFAULT_WW / 2.0, DEFAULT_WC + DEFAULT_WW / 2.0

        return {
            'cx': mid_x / raw.shape[1],
            'cy': mid_y / raw.shape[0],
            'lung_distance': pair_distance,
            'body_w': w,
            'body_h': h,
            'p_low': float(p_low),
            'p_high': float(p_high),
            'confidence': float(confidence),
            'left_lung': {
                'cx': left_cx / raw.shape[1],
                'cy': left_cy / raw.shape[0],
                'bbox': [
                    (x1 + left['bbox'][0]) / raw.shape[1],
                    (y1 + left['bbox'][1]) / raw.shape[0],
                    (x1 + left['bbox'][2]) / raw.shape[1],
                    (y1 + left['bbox'][3]) / raw.shape[0],
                ],
            },
            'right_lung': {
                'cx': right_cx / raw.shape[1],
                'cy': right_cy / raw.shape[0],
                'bbox': [
                    (x1 + right['bbox'][0]) / raw.shape[1],
                    (y1 + right['bbox'][1]) / raw.shape[0],
                    (x1 + right['bbox'][2]) / raw.shape[1],
                    (y1 + right['bbox'][3]) / raw.shape[0],
                ],
            },
        }

    def run(self):
        stats = {}
        total = len(self.files)
        debug_lines = [
            f"files={total}",
            f"first={self.files[0] if self.files else ''}",
        ]
        failures = {}

        # 1. Gather Stats from all images
        for i, f in enumerate(self.files):
            if not self.is_running: break
            try:
                ds = read_and_fix_corrupted_dicom(f)
                image_stats = self._extract_stats(ds)
                if image_stats is not None:
                    stats[i] = image_stats
                else:
                    failures['extract_none'] = failures.get('extract_none', 0) + 1

            except Exception as e:
                key = type(e).__name__
                failures[key] = failures.get(key, 0) + 1
                if len(debug_lines) < 20:
                    debug_lines.append(f"error[{i}]={Path(f).name}: {key}: {e}")

            self.progress.emit(i + 1, total)

        # 2. Calculate Alignments relative to the median successful geometry.
        results = {}
        rejected_zoom = 0
        rejected_pan = 0
        if stats:
            ref = {
                'cx': float(np.median([s['cx'] for s in stats.values()])),
                'cy': float(np.median([s['cy'] for s in stats.values()])),
                'lung_distance': float(np.median([s['lung_distance'] for s in stats.values()])),
            }
            lows = np.array([s['p_low'] for s in stats.values()], dtype=np.float32)
            highs = np.array([s['p_high'] for s in stats.values()], dtype=np.float32)
            ref_low = float(np.median(lows))
            ref_high = float(np.median(highs))
            ref_ww = max(1.0, ref_high - ref_low)
            ref_wc = (ref_low + ref_high) / 2.0

            for i, s in stats.items():
                if s['lung_distance'] == 0: continue
                zoom = ref['lung_distance'] / s['lung_distance']

                # Constraint: 1/1.2 < Zoom < 1.2 (Avoid outlier zooms)
                if not (0.83 < zoom < 1.2):
                    rejected_zoom += 1
                    continue

                # Calculate Pan (NDC coordinates -1..1)
                # Convert Texture Space (0..1) to NDC
                # NDC_X = (TexX * 2) - 1
                # NDC_Y = 1 - (TexY * 2)  (Inverted Y)

                ref_ndc_x = (ref['cx'] * 2.0) - 1.0
                ref_ndc_y = 1.0 - (ref['cy'] * 2.0)
                tgt_ndc_x = (s['cx'] * 2.0) - 1.0
                tgt_ndc_y = 1.0 - (s['cy'] * 2.0)

                # Pan formula: Ref = Tgt * Zoom + Pan  =>  Pan = Ref - Tgt * Zoom
                pan_x = ref_ndc_x - (tgt_ndc_x * zoom)
                pan_y = ref_ndc_y - (tgt_ndc_y * zoom)

                # Portable CXR varies more vertically than horizontally.
                # Keep horizontal moves tight, but allow modest vertical
                # recentering so low-position films still benefit.
                if abs(pan_x) > 0.18 or abs(pan_y) > 0.35:
                    rejected_pan += 1
                    continue

                img_ww = max(1.0, s['p_high'] - s['p_low'])
                img_wc = (s['p_low'] + s['p_high']) / 2.0

                # Conservative histogram matching: follow the series median,
                # but keep enough of each image's native range for lung markings.
                ww = 0.70 * img_ww + 0.30 * ref_ww
                wc = 0.70 * img_wc + 0.30 * ref_wc
                ww = float(np.clip(ww, img_ww * 0.75, img_ww * 1.35))

                results[i] = {
                    'zoom': float(zoom),
                    'pan': [float(pan_x), float(pan_y)],
                    'wc': float(wc),
                    'ww': float(max(1.0, ww)),
                    'confidence': s['confidence'],
                    'left_lung': s['left_lung'],
                    'right_lung': s['right_lung'],
                }

        debug_lines.insert(2, f"stats={len(stats)} results={len(results)} failures={failures}")
        debug_lines.insert(3, f"rejected_zoom={rejected_zoom} rejected_pan={rejected_pan}")
        try:
            ALIGN_DEBUG_LOG.write_text("\n".join(debug_lines), encoding="utf-8")
        except Exception:
            pass

        self.alignment_finished.emit(results)

    def stop(self):
        self.is_running = False


# --- File Counting Worker (Background Thread) ---
class FileCounterWorker(QThread):
    # Emits (row_index, display_text)
    update_item = Signal(int, str)

    def __init__(self, folders_to_process, last_viewed_name=None, last_viewed_index=-1):
        super().__init__()
        # List of tuples: (path_object, row_index)
        self.folders = folders_to_process
        self.last_viewed_name = last_viewed_name
        self.last_viewed_index = last_viewed_index
        self.is_running = True

    def run(self):
        for path, row in self.folders:
            if not self.is_running: break
            try:
                # RAM-safe recursive count using generator
                count = sum(1 for _ in path.rglob('*') if _.is_file())

                # Re-apply marker if this is the last viewed folder
                marker = ""
                if path.name == self.last_viewed_name:
                    # Check if index corresponds to the last image (or beyond)
                    if count > 0 and self.last_viewed_index >= count - 1:
                        marker = " [Last Viewed to End]"
                    else:
                        marker = " [LAST VIEWED]"

                new_text = f"{path.name}{marker} ({count} files)"

                self.update_item.emit(row, new_text)
            except Exception:
                pass  # Ignore permission errors etc

    def stop(self):
        self.is_running = False


# --- Startup Dialog ---
class StartupDialog(QDialog):
    def __init__(self, default_path, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Select DICOM Source")
        self.setMinimumSize(500, 400)
        self.default_path = Path(default_path)
        if not self.default_path.exists():
            self.default_path = Path.home()

        self.selected_files = []
        self.counter_thread = None

        self.last_viewed_folder_name, self.last_viewed_index = self.get_last_viewed_info()

        self.layout = QVBoxLayout(self)
        self.folder_list_widget = QListWidget()
        self.populate_folders()

        self.layout.addWidget(QLabel(f"Recent date folders in: {self.default_path}"))
        self.layout.addWidget(self.folder_list_widget)
        self.button_box = QDialogButtonBox()
        self.select_folder_btn = self.button_box.addButton("Open Selected Folder", QDialogButtonBox.ButtonRole.AcceptRole)
        self.select_files_btn = self.button_box.addButton("Select Files...", QDialogButtonBox.ButtonRole.ActionRole)
        self.select_other_folder_btn = self.button_box.addButton("Other Folder...", QDialogButtonBox.ButtonRole.ActionRole)
        self.refresh_btn = self.button_box.addButton("🔄 Refresh", QDialogButtonBox.ButtonRole.ActionRole)
        self.button_box.addButton("Exit Application", QDialogButtonBox.ButtonRole.RejectRole)
        self.layout.addWidget(self.button_box)

        self.select_folder_btn.clicked.connect(self.accept_folder_selection)
        self.select_files_btn.clicked.connect(self.select_files)
        self.select_other_folder_btn.clicked.connect(self.select_other_folder)
        self.refresh_btn.clicked.connect(self.refresh_folders)
        self.button_box.rejected.connect(self.reject)
        self.folder_list_widget.itemDoubleClicked.connect(self.accept_folder_selection)

    def get_last_viewed_info(self):
        name = None
        index = -1
        if CONFIG_FILE.exists():
            try:
                lines = CONFIG_FILE.read_text().strip().splitlines()
                if len(lines) >= 1:
                    name = Path(lines[0]).name
                if len(lines) >= 2:
                    index = int(lines[1])
            except Exception:
                pass
        return name, index

    def refresh_folders(self):
        if self.counter_thread and self.counter_thread.isRunning():
            self.counter_thread.stop()
            self.counter_thread.wait()
        self.last_viewed_folder_name, self.last_viewed_index = self.get_last_viewed_info()
        self.populate_folders()

    def populate_folders(self):
        self.folder_list_widget.clear()
        folders_to_count = []

        if self.default_path.exists():
            try:
                valid_folders = []
                for d in self.default_path.iterdir():
                    if d.is_dir() and d.name.isdigit() and len(d.name) == 8:
                        valid_folders.append(d)

                # Sort newest first
                sorted_folders = sorted(valid_folders, key=lambda p: int(p.name), reverse=True)

                for i, folder in enumerate(sorted_folders):
                    marker = " [LAST VIEWED]" if folder.name == self.last_viewed_folder_name else ""
                    item = QListWidgetItem(f"{folder.name}{marker} (counting...)")
                    item.setData(Qt.ItemDataRole.UserRole, folder)
                    self.folder_list_widget.addItem(item)
                    folders_to_count.append((folder, i))
                    if folder.name == self.last_viewed_folder_name:
                        self.folder_list_widget.setCurrentRow(i)

                if folders_to_count:
                    self.counter_thread = FileCounterWorker(folders_to_count, self.last_viewed_folder_name,
                                                            self.last_viewed_index)
                    self.counter_thread.update_item.connect(self.update_list_item)
                    self.counter_thread.start()

            except Exception as e:
                self.folder_list_widget.addItem(f"Error reading folders: {e}")

    @Slot(int, str)
    def update_list_item(self, row, text):
        if row < self.folder_list_widget.count():
            item = self.folder_list_widget.item(row)
            item.setText(text)

    def closeEvent(self, event):
        if self.counter_thread and self.counter_thread.isRunning():
            self.counter_thread.stop()
            self.counter_thread.wait()
        super().closeEvent(event)

    def accept_folder_selection(self):
        selected_item = self.folder_list_widget.currentItem()
        if selected_item and selected_item.data(Qt.ItemDataRole.UserRole):
            folder_path = selected_item.data(Qt.ItemDataRole.UserRole)
            self.selected_files = sorted(
                [f for f in folder_path.rglob('*') if f.is_file() and not f.name.startswith('.')])
            if self.selected_files:
                self.accept()
            else:
                QMessageBox.warning(self, "Empty Folder", f"No visible files found in '{folder_path.name}'.")

    def select_files(self):
        files, _ = QFileDialog.getOpenFileNames(self, "Select DICOM Files", str(self.default_path),
                                                "DICOM files (*.dcm *.ima);;All files (*)")
        if files: self.selected_files = sorted([Path(f) for f in files]); self.accept()

    def select_other_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Select Other Folder", str(self.default_path))
        if folder:
            folder_path = Path(folder)
            self.selected_files = sorted(
                [f for f in folder_path.rglob('*') if f.is_file() and not f.name.startswith('.')])
            if self.selected_files:
                self.accept()
            else:
                QMessageBox.warning(self, "Empty Folder", f"No files found in '{folder_path.name}'.")


# --- Custom Input Widget ---
class JumpInput(QLineEdit):
    space_pressed = Signal(str)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Space:
            self.space_pressed.emit(self.text())
        else:
            super().keyPressEvent(event)


# --- DicomWorker ---
class DicomWorker(QObject):
    finished = Signal(np.ndarray, dict, str)

    def __init__(self, file_path):
        super().__init__()
        self.file_path = file_path

    @Slot()
    def run(self):
        try:
            dcm = read_and_fix_corrupted_dicom(self.file_path)
            try:
                pixel_array = dcm.pixel_array.astype(np.uint16)
            except Exception:
                pixel_array = _try_recover_pixel_array(dcm)
                if pixel_array is None:
                    raise
            patient_name = str(dcm.get('PatientName', 'N/A'))
            metadata = {
                'Patient ID': dcm.get('PatientID', 'N/A'),
                'Patient Name': patient_name,
                'Accession Number': dcm.get('AccessionNumber', 'N/A'),
                'Bits Stored': dcm.get('BitsStored', 16),
                'RescaleSlope': float(dcm.get('RescaleSlope', 1.0)),
                'RescaleIntercept': float(dcm.get('RescaleIntercept', 0.0)),
                'PresentationLUTShape': dcm.get((0x2050, 0x0020), None).value if (0x2050, 0x0020) in dcm else None,
                'PhotometricInterpretation': dcm.get('PhotometricInterpretation', 'MONOCHROME2')
            }
            del dcm  # Explicit deletion
            self.finished.emit(pixel_array, metadata, "")
        except Exception as e:
            error_message = f"Failed to process '{self.file_path.name}':\n{str(e)}"
            self.finished.emit(np.array([]), {}, error_message)


# --- OpenGL Widget ---
class DICOMOpenGLWidget(QOpenGLWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.pixel_data = None;
        self.texture_id = None;
        self.program = None
        self.texture_needs_update = False;
        self.gl_initialized = False
        self.current_tex_w = 0;
        self.current_tex_h = 0
        self.window_min = 0.0;
        self.inv_window_width = 1.0 / 4096.0
        self.rescale_slope, self.rescale_intercept = 1.0, 0.0
        self.max_pixel_value = 4095.0
        self.should_invert = False
        self.image_width = 1;
        self.image_height = 1

        # ** NEW: Zoom and Windowing State **
        self.scale = (1.0, 1.0)  # Aspect ratio scale
        self.zoom_factor = 1.0
        self.pan_offset = [0.0, 0.0]
        self.zoom_center_clip = [0.0, 0.0]

        self.current_wc = DEFAULT_WC
        self.current_ww = DEFAULT_WW

        # Interaction Mode
        self.is_zoom_mode = False
        self.sharpen_applied = False  # Added Sharpen State

        self.drag_start_pos = None
        self.last_mouse_pos = None

    def set_image_data(self, pixel_array, metadata, should_invert):
        self.pixel_data = pixel_array;
        self.image_height, self.image_width = self.pixel_data.shape
        self.max_pixel_value = (2 ** metadata.get('Bits Stored', 16)) - 1
        self.rescale_slope = metadata.get('RescaleSlope', 1.0);
        self.rescale_intercept = metadata.get('RescaleIntercept', 0.0)
        self.should_invert = should_invert

        # Recalculate GL windowing based on current WC/WW state
        self._update_gl_windowing()

        self.texture_needs_update = True
        self.update()

    def _update_gl_windowing(self):
        # Calculate GL params from current WC/WW
        self.window_min = self.current_wc - self.current_ww / 2.0
        if self.current_ww > 0:
            self.inv_window_width = 1.0 / self.current_ww
        else:
            self.inv_window_width = 1.0  # Prevent div by zero

    # ** Reset View Method **
    def reset_view(self):
        self.zoom_factor = 1.0
        self.pan_offset = [0.0, 0.0]
        self.current_wc = DEFAULT_WC
        self.current_ww = DEFAULT_WW
        self.sharpen_applied = False
        self._update_gl_windowing()
        self.update()

    def apply_view_preset(self, data):
        self.zoom_factor = data.get('zoom', 1.0)
        self.pan_offset = data.get('pan', [0.0, 0.0])
        if 'wc' in data and 'ww' in data:
            self.current_wc = data['wc']
            self.current_ww = max(1.0, data['ww'])
            self._update_gl_windowing()
        self.update()

    # ** NEW: Mouse Events for Dragging **
    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.last_mouse_pos = event.position().toPoint()
            self.drag_start_pos = event.position().toPoint()

            # Calculate NDC coordinates (-1 to 1) of the click for zooming
            clip_x = (event.position().x() / self.width()) * 2.0 - 1.0
            clip_y = 1.0 - (event.position().y() / self.height()) * 2.0
            self.zoom_center_clip = [clip_x, clip_y]

    def mouseMoveEvent(self, event):
        if self.last_mouse_pos and event.buttons() & Qt.MouseButton.LeftButton:
            dx = int(event.position().x()) - self.last_mouse_pos.x()
            dy = int(event.position().y()) - self.last_mouse_pos.y()

            if self.is_zoom_mode:
                # Zoom around start point
                drag_dy = self.drag_start_pos.y() - event.pos().y()
                zoom_change = -dy * ZOOM_SENSITIVITY
                self.zoom_factor += self.zoom_factor * zoom_change
                self.zoom_factor = max(0.1, min(self.zoom_factor, 10.0))

                # Pan Logic: Offset = Clip * (1 - Zoom)
                pan_x = self.zoom_center_clip[0] * (1.0 - self.zoom_factor)
                pan_y = self.zoom_center_clip[1] * (1.0 - self.zoom_factor)
                self.pan_offset = [pan_x, pan_y]

            else:
                # Windowing Logic (Action: Drag Right -> Increase Contrast)
                # Increase Contrast = Decrease Window Width
                self.current_ww -= dx * 2

                # Action: Drag Up -> Increase Brightness
                # Increase Brightness = Decrease Window Level
                # dy is negative when dragging up, so we Add negative dy to lower wc
                self.current_wc += dy * 2

                self.current_ww = max(1.0, self.current_ww)
                self._update_gl_windowing()

            self.last_mouse_pos = event.position().toPoint()
            self.update()  # Trigger repaint

    def mouseReleaseEvent(self, event):
        self.last_mouse_pos = None
        self.drag_start_pos = None

    def initializeGL(self):
        self.gl_initialized = True
        self.vao = GL.glGenVertexArrays(1)
        GL.glBindVertexArray(self.vao)
        self.texture_id = GL.glGenTextures(1)
        GL.glBindTexture(GL.GL_TEXTURE_2D, self.texture_id)
        GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_NEAREST)
        GL.glTexParameteri(GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_NEAREST)
        GL.glBindTexture(GL.GL_TEXTURE_2D, 0)

        # ** MODIFIED: Vertex Shader supports panOffset **
        vertex_shader_source = """#version 330 core
        in vec2 position; out vec2 texCoord; 
        uniform vec2 scale;
        uniform vec2 panOffset; 

        void main() { 
            // Scale first, then translate
            gl_Position = vec4(position * scale + panOffset, 0.0, 1.0); 
            texCoord = vec2(position.x*0.5+0.5, -position.y*0.5+0.5); 
        }"""

        # Fragment Shader with Sharpening
        fragment_shader_source = """#version 330 core
        in vec2 texCoord; out vec4 outColor; uniform sampler2D dicomTexture;
        uniform float windowMin, invWindowWidth, maxPixelValue, rescaleSlope, rescaleIntercept; 
        uniform bool shouldInvert;
        uniform bool applySharpen;
        uniform vec2 texelSize;

        void main() { 
            float rawValue;

            if (applySharpen) {
                float sharpenedVal = 0.0;
                sharpenedVal += texture(dicomTexture, texCoord + vec2(0.0, -1.0) * texelSize).r * -1.0;
                sharpenedVal += texture(dicomTexture, texCoord + vec2(-1.0, 0.0) * texelSize).r * -1.0;
                sharpenedVal += texture(dicomTexture, texCoord).r * 5.0;
                sharpenedVal += texture(dicomTexture, texCoord + vec2(1.0, 0.0) * texelSize).r * -1.0;
                sharpenedVal += texture(dicomTexture, texCoord + vec2(0.0, 1.0) * texelSize).r * -1.0;
                rawValue = sharpenedVal * maxPixelValue;
            } else {
                rawValue = texture(dicomTexture, texCoord).r * maxPixelValue;
            }

            float trueValue = rawValue * rescaleSlope + rescaleIntercept; 
            float intensity = clamp((trueValue - windowMin) * invWindowWidth, 0.0, 1.0);
            if (shouldInvert) { intensity = 1.0 - intensity; } 
            outColor = vec4(intensity, intensity, intensity, 1.0); 
        }"""

        v_shader = GL.glCreateShader(GL.GL_VERTEX_SHADER);
        GL.glShaderSource(v_shader, vertex_shader_source);
        GL.glCompileShader(v_shader)
        f_shader = GL.glCreateShader(GL.GL_FRAGMENT_SHADER);
        GL.glShaderSource(f_shader, fragment_shader_source);
        GL.glCompileShader(f_shader)
        self.program = GL.glCreateProgram();
        GL.glAttachShader(self.program, v_shader);
        GL.glAttachShader(self.program, f_shader);
        GL.glLinkProgram(self.program)
        vertices = np.array([-1, -1, 1, -1, 1, 1, -1, 1], dtype=np.float32)
        vbo = GL.glGenBuffers(1);
        GL.glBindBuffer(GL.GL_ARRAY_BUFFER, vbo);
        GL.glBufferData(GL.GL_ARRAY_BUFFER, vertices.nbytes, vertices, GL.GL_STATIC_DRAW)
        pos = GL.glGetAttribLocation(self.program, "position");
        GL.glEnableVertexAttribArray(pos);
        GL.glVertexAttribPointer(pos, 2, GL.GL_FLOAT, GL.GL_FALSE, 0, None)
        GL.glBindVertexArray(0)

    def paintGL(self):
        if self.texture_needs_update and self.gl_initialized: self._update_texture_on_gl_thread()
        GL.glClearColor(0.0, 0.0, 0.0, 1.0);
        GL.glClear(GL.GL_COLOR_BUFFER_BIT)
        if self.program and self.texture_id is not None:
            GL.glUseProgram(self.program)

            final_scale_x = self.scale[0] * self.zoom_factor
            final_scale_y = self.scale[1] * self.zoom_factor

            GL.glUniform2f(GL.glGetUniformLocation(self.program, "scale"), final_scale_x, final_scale_y)
            # ** NEW: Pass Pan Offset **
            GL.glUniform2f(GL.glGetUniformLocation(self.program, "panOffset"), self.pan_offset[0], self.pan_offset[1])

            GL.glUniform1f(GL.glGetUniformLocation(self.program, "windowMin"), self.window_min)
            GL.glUniform1f(GL.glGetUniformLocation(self.program, "invWindowWidth"), self.inv_window_width)
            GL.glUniform1f(GL.glGetUniformLocation(self.program, "maxPixelValue"), self.max_pixel_value)
            GL.glUniform1f(GL.glGetUniformLocation(self.program, "rescaleSlope"), self.rescale_slope)
            GL.glUniform1f(GL.glGetUniformLocation(self.program, "rescaleIntercept"), self.rescale_intercept)
            GL.glUniform1i(GL.glGetUniformLocation(self.program, "shouldInvert"), self.should_invert)

            GL.glUniform1i(GL.glGetUniformLocation(self.program, "applySharpen"), self.sharpen_applied)
            if self.image_width > 0 and self.image_height > 0:
                GL.glUniform2f(GL.glGetUniformLocation(self.program, "texelSize"), 1.0 / self.image_width,
                               1.0 / self.image_height)

            GL.glActiveTexture(GL.GL_TEXTURE0);
            GL.glBindTexture(GL.GL_TEXTURE_2D, self.texture_id)
            GL.glBindVertexArray(self.vao)
            GL.glDrawArrays(GL.GL_TRIANGLE_FAN, 0, 4)
            GL.glBindVertexArray(0)

    def resizeGL(self, w, h):
        pixel_ratio = self.devicePixelRatio()
        GL.glViewport(0, 0, int(w * pixel_ratio), int(h * pixel_ratio))
        if self.image_width == 0 or h == 0: return
        widget_aspect = w / h;
        image_aspect = self.image_width / self.image_height
        if image_aspect > widget_aspect:
            self.scale = (1.0, widget_aspect / image_aspect)
        else:
            self.scale = (image_aspect / widget_aspect, 1.0)

    def _update_texture_on_gl_thread(self):
        if self.pixel_data is not None and self.pixel_data.size > 0:
            h, w = self.pixel_data.shape
            GL.glBindTexture(GL.GL_TEXTURE_2D, self.texture_id)
            if w == self.current_tex_w and h == self.current_tex_h:
                GL.glTexSubImage2D(GL.GL_TEXTURE_2D, 0, 0, 0, w, h, GL.GL_RED, GL.GL_UNSIGNED_SHORT, self.pixel_data)
            else:
                GL.glTexImage2D(GL.GL_TEXTURE_2D, 0, GL.GL_R16, w, h, 0, GL.GL_RED, GL.GL_UNSIGNED_SHORT,
                                self.pixel_data)
                self.current_tex_w = w;
                self.current_tex_h = h
            GL.glFinish()
            GL.glBindTexture(GL.GL_TEXTURE_2D, 0)
        self.texture_needs_update = False


# --- Main Application Window ---
class DICOMViewer(QMainWindow):
    closed = Signal()

    def __init__(self, file_list, start_index=None):
        super().__init__()
        self.dicom_files = file_list
        if not self.dicom_files: raise ValueError("DICOMViewer initialized with empty list.")
        self.directory = self.dicom_files[0].parent
        self.last_mouse_pos = QPoint();
        self.thread = None;
        self.worker = None
        self.is_manual_invert_on = False;
        self.current_pixel_array = None;
        self.current_metadata = {}
        self.is_loading = False
        self.load_error_count = 0

        # Experimental alignment state:
        # alignment_results is intentionally session-only. If the calculation
        # succeeds, RAW/ALIGN toggles reuse these presets until the app exits.
        # If results are empty, the next ALIGN click should recalculate.
        self.alignment_results = {}
        self.alignment_active = False
        self.alignment_calculated = False
        self.align_worker = None

        self.play_timer = QTimer(self);
        self.play_timer.setInterval(PLAY_INTERVAL)
        self.play_timer.timeout.connect(self.auto_advance)
        self.osd_timer = QTimer(self);
        self.osd_timer.setSingleShot(True)
        self.osd_timer.timeout.connect(self.hide_osd)

        self.info_update_timer = QTimer(self)
        self.info_update_timer.setSingleShot(True)
        self.info_update_timer.setInterval(INFO_UPDATE_DELAY)
        self.info_update_timer.timeout.connect(self.update_info_label)
        self.pending_info_text = "Ready"

        self.determine_start_index(start_index)
        self.setWindowFlags(self.windowFlags() | Qt.WindowType.WindowStaysOnTopHint)
        self.initUI()

    def determine_start_index(self, start_index_arg):
        if start_index_arg is not None:
            self.current_index = start_index_arg
        elif CONFIG_FILE.exists():
            self.current_index = 0
            try:
                lines = CONFIG_FILE.read_text().strip().splitlines()
                if len(lines) >= 2:
                    last_dir_path = Path(lines[0])
                    last_index = int(lines[1])
                    if last_dir_path == self.directory.resolve():
                        last_file_name = lines[3] if len(lines) >= 4 else ""
                        if last_file_name:
                            try:
                                self.current_index = next(
                                    i for i, path in enumerate(self.dicom_files)
                                    if path.name == last_file_name
                                )
                            except StopIteration:
                                self.current_index = 0
                        else:
                            self.current_index = last_index
            except (ValueError, IndexError):
                self.current_index = 0
        else:
            self.current_index = 0
        self.current_index = max(0, min(self.current_index, len(self.dicom_files) - 1))

    def initUI(self):
        self.setWindowTitle("Universal DICOM Viewer")
        font_info = "font-family: Consolas, 'Courier New', monospace; font-size: 20pt; font-weight: bold; padding-left: 10px;"

        self.info_label = QLabel("Ready")
        self.info_label.setAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
        self.info_label.setStyleSheet(font_info)
        self.info_label.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Preferred)
        self.info_label.setMinimumWidth(0)

        # Explorer Button
        self.btn_explorer = QPushButton("📂")
        self.btn_explorer.setFixedSize(40, 40)
        self.btn_explorer.setToolTip("Open in File Explorer (E)")
        self.btn_explorer.setFocusPolicy(Qt.FocusPolicy.NoFocus)  # Fix: Prevent Space key steal
        self.btn_explorer.clicked.connect(self.open_current_in_explorer)

        # Experimental smart CXR alignment toggle. RAW shows the original view;
        # CALC means the background worker is building presets; ALIGN applies
        # cached zoom/pan/WC/WW presets when available for the current image.
        self.btn_align = QPushButton("RAW")
        self.btn_align.setFixedSize(72, 40)
        self.btn_align.setCheckable(True)
        self.btn_align.setToolTip("Toggle smart lung alignment")
        self.btn_align.setFocusPolicy(Qt.FocusPolicy.NoFocus)  # Fix: Prevent Space key steal
        self.btn_align.clicked.connect(self.toggle_alignment)

        # Progress Label (Hidden by default)
        self.lbl_progress = QLabel("")
        self.lbl_progress.setStyleSheet("color: #9a7a00; font-weight: bold; margin-right: 10px;")
        self.lbl_progress.hide()

        self.jump_box = JumpInput()
        self.jump_box.setFixedWidth(100);
        self.jump_box.setPlaceholderText("Go to...")
        self.jump_box.setValidator(QIntValidator(1, len(self.dicom_files), self))
        self.jump_box.setStyleSheet(f"font-family: Arial; font-size: 14pt;")
        self.jump_box.returnPressed.connect(self.jump_to_image)
        self.jump_box.space_pressed.connect(self.handle_jump_and_play)

        top_layout = QHBoxLayout();
        top_layout.addWidget(self.info_label, 1);
        top_layout.addWidget(self.btn_explorer);
        top_layout.addWidget(self.btn_align);
        top_layout.addWidget(self.lbl_progress);
        top_layout.addWidget(self.jump_box)

        self.gl_widget = DICOMOpenGLWidget()
        self.osd_label = QLabel(self);
        self.osd_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.osd_label.setStyleSheet("""
            QLabel { font-family: Arial; font-size: 60pt; color: yellow; font-weight: bold;
                background-color: rgba(0, 0, 0, 100); border-radius: 10px; padding: 10px; }""")
        self.osd_label.hide()
        main_layout = QVBoxLayout();
        main_layout.addLayout(top_layout);
        main_layout.addWidget(self.gl_widget, 1)
        central_widget = QWidget();
        central_widget.setLayout(main_layout);
        self.setCentralWidget(central_widget)
        self.update_alignment_button()

    # ** NEW: Alignment Logic **
    def update_alignment_button(self):
        if self.alignment_active:
            self.btn_align.setText("ALIGN")
            self.btn_align.setChecked(True)
            if self.current_index in self.alignment_results:
                self.btn_align.setToolTip("Smart lung alignment is ON. Click to return to RAW view.")
            else:
                self.btn_align.setToolTip("Alignment is ON, but this image had no reliable lung match.")
        else:
            self.btn_align.setText("RAW")
            self.btn_align.setChecked(False)
            if self.alignment_results:
                self.btn_align.setToolTip("Raw view. Click to reapply cached smart lung alignment.")
            elif self.alignment_calculated:
                self.btn_align.setToolTip("Raw view. Last alignment found no usable images; click to recalculate.")
            else:
                self.btn_align.setToolTip("Raw view. Click to calculate smart lung alignment.")

    @Slot()
    def toggle_alignment(self):
        # Experimental workflow:
        # 1. First ALIGN click asks for confirmation and starts LungAlignWorker.
        # 2. Successful results are cached in memory and reused by later toggles.
        # 3. RAW resets to the original unaligned display.
        # 4. Empty results mean the experimental detector failed at runtime and
        #    should be recalculated after reviewing ALIGN_DEBUG_LOG.
        if self.alignment_active:
            # Turn OFF
            self.alignment_active = False
            self.gl_widget.reset_view()
            self.update_alignment_button()
            self.show_osd_message("RAW", duration=800)
            self.update_info_label()
        else:
            # Fix: Confirmation Dialog to prevent accidental trigger
            if not self.alignment_results:
                reply = QMessageBox.question(self, 'Run Alignment?',
                                             'Calculate and apply smart lung alignment for this series?\n(This uses background processing)',
                                             QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                                             QMessageBox.StandardButton.No)

                if reply == QMessageBox.StandardButton.No:
                    self.update_alignment_button()
                    return

            # Turn ON
            if self.alignment_results:
                self.alignment_active = True
                # Re-apply current if available
                if self.current_index in self.alignment_results:
                    self.gl_widget.apply_view_preset(self.alignment_results[self.current_index])
                    self.show_osd_message("ALIGN", duration=800)
                else:
                    self.gl_widget.reset_view()
                    self.show_osd_message("NO ALIGN", duration=800)
                self.update_alignment_button()
                self.update_info_label()
            else:
                # Start Calculation
                self.alignment_calculated = False
                self.lbl_progress.show()
                self.lbl_progress.setText("Calculating...")
                self.btn_align.setText("CALC")
                self.btn_align.setChecked(True)
                self.btn_align.setToolTip("Calculating smart lung alignment...")
                self.align_worker = LungAlignWorker(self.dicom_files, self.current_index)
                self.align_worker.progress.connect(self.on_align_progress)
                self.align_worker.alignment_finished.connect(self.on_align_finished)
                self.align_worker.start()

    @Slot(int, int)
    def on_align_progress(self, current, total):
        self.lbl_progress.setText(f"[ {current}/{total} ]")

    @Slot(dict)
    def on_align_finished(self, results):
        self.alignment_results = results
        self.alignment_calculated = True
        self.lbl_progress.hide()

        if results:
            self.alignment_active = True
            # Apply to current image immediately if valid
            if self.current_index in results:
                self.gl_widget.apply_view_preset(results[self.current_index])
                self.show_osd_message(f"ALIGN {len(results)}/{len(self.dicom_files)}", duration=1200)
            else:
                self.gl_widget.reset_view()
                self.show_osd_message(f"NO ALIGN {len(results)}/{len(self.dicom_files)}", duration=1200)
        else:
            self.alignment_active = False
            self.gl_widget.reset_view()
            self.show_osd_message("ALIGN FAILED 0", duration=1600)

        self.update_alignment_button()
        self.update_info_label()

    # ** NEW: Open Explorer (Safe) **
    @Slot()
    def open_current_in_explorer(self):
        if not self.dicom_files: return
        file_path = self.dicom_files[self.current_index]

        system_platform = platform.system()
        try:
            if system_platform == "Windows":
                # Ensure path is absolute and uses backslashes
                path_str = str(file_path.resolve())
                # Use shell=True to detach effectively on older Windows
                subprocess.Popen(f'explorer /select,"{path_str}"', shell=True)
            elif system_platform == "Darwin":  # macOS
                subprocess.run(["open", "-R", str(file_path)])
            else:  # Linux
                subprocess.run(["xdg-open", str(file_path.parent)])
        except Exception as e:
            print(f"Error opening explorer: {e}")

    def load_image(self):
        if self.is_loading: return
        self.is_loading = True

        file_path = self.dicom_files[self.current_index]
        self.thread = QThread();
        self.worker = DicomWorker(file_path);
        self.worker.moveToThread(self.thread)
        self.thread.started.connect(self.worker.run);
        self.worker.finished.connect(self.on_loading_finished)
        self.worker.finished.connect(self.thread.quit);
        self.worker.finished.connect(self.worker.deleteLater)
        self.thread.finished.connect(self.thread.deleteLater);
        self.thread.start()

    @Slot(np.ndarray, dict, str)
    def on_loading_finished(self, pixel_array, metadata, error_message):
        if error_message:
            self.is_loading = False
            self.load_error_count += 1
            self.show_osd_message("⚠", duration=600)
            if self.load_error_count >= min(10, len(self.dicom_files)):
                self.info_label.setText(error_message)
                self.current_pixel_array = None
                self.current_metadata = {}
            elif self.current_index < len(self.dicom_files) - 1:
                self.current_index += 1
                self.load_image()
            else:
                self.info_label.setText(error_message)
                self.current_pixel_array = None
                self.current_metadata = {}
            return

        self.load_error_count = 0
        self.current_pixel_array = pixel_array
        self.current_metadata = metadata
        photometric_interp = metadata.get('PhotometricInterpretation', 'MONOCHROME2')
        is_dicom_inverted = (photometric_interp == 'MONOCHROME1')
        final_inversion_state = is_dicom_inverted ^ self.is_manual_invert_on
        self.gl_widget.set_image_data(pixel_array, metadata, final_inversion_state)

        # ** NEW: Apply Alignment if Active **
        if self.alignment_active and self.current_index in self.alignment_results:
            self.gl_widget.apply_view_preset(self.alignment_results[self.current_index])
        elif self.alignment_active:
            # Reset if no alignment found for this specific image (e.g. outlier)
            self.gl_widget.zoom_factor = 1.0
            self.gl_widget.pan_offset = [0.0, 0.0]
            self.gl_widget.current_wc = DEFAULT_WC
            self.gl_widget.current_ww = DEFAULT_WW
            self.gl_widget._update_gl_windowing()
            self.gl_widget.update()
        self.update_alignment_button()

        current_num = self.current_index + 1;
        file_count = len(self.dicom_files)

        patient_name = str(metadata.get('Patient Name', 'N/A')).replace('^', ' ').strip()
        patient_id = str(metadata.get('Patient ID', 'N/A'))
        accession_number = str(metadata.get('Accession Number', 'N/A'))

        inversion_status = " (INV)" if final_inversion_state else ""
        play_status = " [PLAY]" if self.play_timer.isActive() else ""
        # Show sharp status
        sharpen_status = " [SHARP]" if self.gl_widget.sharpen_applied else ""
        if self.alignment_active:
            align_status = " [ALIGN]" if self.current_index in self.alignment_results else " [NOALIGN]"
        else:
            align_status = " [RAW]"

        folder_name = self.dicom_files[self.current_index].parent.name
        p_name_trunc = patient_name[:12]

        self.pending_info_text = (
            f"{folder_name:<10}  "
            f"{current_num:>4}/{file_count:<4} : "
            f"{accession_number:<15} - "
            f"{patient_id:<14} - "
            f"{p_name_trunc:<12}"
            f"{inversion_status}{play_status}{sharpen_status}{align_status}"
        )

        self.info_update_timer.start()

        if current_num % 100 == 0:
            self.show_osd_message(str(current_num))
            self.save_current_state()
            self.update_info_label()

        self.is_loading = False
        gc.collect()

    @Slot()
    def update_info_label(self):
        self.info_label.setText(self.pending_info_text)
        self.save_current_state()

    def show_osd_message(self, text, duration=2000):
        self.osd_timer.stop()
        self.osd_label.setText(text)
        self.osd_label.adjustSize()
        self.adjust_osd_position()
        self.osd_label.show()
        self.osd_label.raise_()
        self.osd_timer.start(duration)

    @Slot()
    def hide_osd(self):
        self.osd_label.hide()

    def showEvent(self, event):
        super().showEvent(event)
        if not self.is_loading and self.current_pixel_array is None:
            self.load_image()

    def resizeEvent(self, event):
        super().resizeEvent(event);
        self.adjust_osd_position()

    def adjust_osd_position(self):
        x = (self.width() - self.osd_label.width()) // 2
        y = 80
        self.osd_label.move(x, y)

    @Slot()
    def jump_to_image(self):
        self.stop_playback();
        self._perform_jump()

    @Slot(str)
    def handle_jump_and_play(self, text):
        if not text:
            self.toggle_play();
            self.jump_box.clearFocus();
            self.gl_widget.setFocus();
            return
        if self._perform_jump():
            if not self.play_timer.isActive():
                self.play_timer.start()
                if self.current_pixel_array is not None: self.on_loading_finished(self.current_pixel_array,
                                                                                  self.current_metadata, "")

    def _perform_jump(self):
        try:
            text = self.jump_box.text()
            if not text: return False
            new_index = int(text) - 1
            if 0 <= new_index < len(self.dicom_files):
                if new_index != self.current_index:
                    self.current_index = new_index;
                    self.load_image();
                    self.save_current_state()
                self.jump_box.clear();
                self.gl_widget.setFocus();
                return True
            else:
                self.jump_box.selectAll();
                return False
        except ValueError:
            return False

    def stop_playback(self):
        if self.play_timer.isActive():
            self.play_timer.stop()

    def toggle_play(self):
        if self.play_timer.isActive():
            self.play_timer.stop()
        else:
            self.play_timer.start()
        self.save_current_state()

        if self.current_pixel_array is not None:
            self.on_loading_finished(self.current_pixel_array, self.current_metadata, "")
            self.update_info_label()

    @Slot()
    def auto_advance(self):
        if self.current_index < len(self.dicom_files) - 1:
            self.current_index += 1;
            self.load_image();
            self.save_current_state()
        else:
            self.play_timer.stop();
            if self.current_pixel_array is not None: self.on_loading_finished(self.current_pixel_array,
                                                                              self.current_metadata, "")

    def keyPressEvent(self, event):
        if event.isAutoRepeat(): return
        if event.key() == Qt.Key_Up:
            self.stop_playback();
            self.show_previous()
        elif event.key() == Qt.Key_Down:
            self.stop_playback();
            self.show_next()
        elif event.key() == Qt.Key_I:
            self.is_manual_invert_on = not self.is_manual_invert_on
            if self.current_pixel_array is not None: self.on_loading_finished(self.current_pixel_array,
                                                                              self.current_metadata, "")
        elif event.key() == Qt.Key_Space:
            self.toggle_play()
        elif event.key() == Qt.Key_Z:
            self.gl_widget.is_zoom_mode = not self.gl_widget.is_zoom_mode
            mode = "ZOOM" if self.gl_widget.is_zoom_mode else "WINDOW"
            self.show_osd_message(mode)
        # ** NEW: Tab for Sharpening **
        elif event.key() == Qt.Key_Tab:
            self.gl_widget.sharpen_applied = not self.gl_widget.sharpen_applied
            self.gl_widget.update()
            # Update info text to show [SHARP] status immediately
            if self.current_pixel_array is not None:
                self.on_loading_finished(self.current_pixel_array, self.current_metadata, "")
                self.update_info_label()
        # ** NEW: R for Reset **
        elif event.key() == Qt.Key_R:
            # Disable alignment on Reset
            self.alignment_active = False
            self.gl_widget.reset_view()
            self.update_alignment_button()
            if self.current_pixel_array is not None:
                self.on_loading_finished(self.current_pixel_array, self.current_metadata, "")
                self.update_info_label()
        # ** NEW: E for Explorer **
        elif event.key() == Qt.Key_E:
            self.open_current_in_explorer()
        else:
            super().keyPressEvent(event)

    def show_previous(self):
        if self.current_index > 0: self.current_index -= 1; self.load_image(); self.save_current_state()

    def show_next(self):
        if self.current_index < len(self.dicom_files) - 1:
            self.current_index += 1;
            self.load_image();
            self.save_current_state()
        else:
            reply = QMessageBox.question(self, 'End of Series',
                                         'This is the last image.\nDo you want to exit the viewer?',
                                         QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                                         QMessageBox.StandardButton.No)
            if reply == QMessageBox.StandardButton.Yes: self.close()

    def save_current_state(self):
        try:
            screens = _sorted_screens()
            current_screen = self.screen()
            screen_idx = next((i for i, s in enumerate(screens) if s == current_screen),
                              len(screens) // 2)
            current_file_name = self.dicom_files[self.current_index].name
            content = f"{self.directory.resolve()}\n{self.current_index}\n{screen_idx}\n{current_file_name}"
            with open(CONFIG_FILE, 'w') as f:
                f.write(content)
                f.flush()
                os.fsync(f.fileno())
        except Exception:
            pass

    def closeEvent(self, event):
        self.play_timer.stop();
        self.save_current_state();
        self.closed.emit();
        event.accept()


# --- AppController ---
class AppController(QObject):
    def __init__(self, base_directory):
        super().__init__()
        self.base_directory = base_directory
        self.viewer = None
        self.dialog = None

    def _load_preferred_screen(self):
        """Return target screen: last remembered (line 3 of config), else middle by X."""
        screens = _sorted_screens()
        default_idx = len(screens) // 2
        if CONFIG_FILE.exists():
            try:
                lines = CONFIG_FILE.read_text().strip().splitlines()
                if len(lines) >= 3:
                    saved_idx = int(lines[2])
                    if 0 <= saved_idx < len(screens):
                        return screens[saved_idx]
            except Exception:
                pass
        return screens[default_idx]

    def run(self):
        self.show_dialog()

    @Slot()
    def show_dialog(self):
        if self.viewer:
            self.viewer.hide()
            self.viewer = None

        target_screen = self._load_preferred_screen()
        geo = target_screen.availableGeometry()

        self.dialog = StartupDialog(default_path=self.base_directory)
        self.dialog.adjustSize()
        dlg_rect = self.dialog.frameGeometry()
        dlg_rect.moveCenter(geo.center())
        self.dialog.move(dlg_rect.topLeft())

        if self.dialog.exec() == QDialog.DialogCode.Accepted:
            file_list = self.dialog.selected_files
            if not file_list:
                QMessageBox.critical(None, "No Files Selected",
                                     "No files found. The application will now exit.")
                QApplication.quit()
                return
            self.viewer = DICOMViewer(file_list)
            self.viewer.closed.connect(self.show_dialog)
            if len(QApplication.screens()) > 1:
                self.viewer.move(geo.topLeft())
                self.viewer.showMaximized()
            else:
                self.viewer.resize(800, 800)
                self.viewer.show()
        else:
            QApplication.quit()


if __name__ == '__main__':
    fmt = QSurfaceFormat()
    fmt.setVersion(3, 3)
    fmt.setProfile(QSurfaceFormat.OpenGLContextProfile.CoreProfile)
    QSurfaceFormat.setDefaultFormat(fmt)
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    current_os = platform.system()
    if current_os == "Windows":
        base_directory = r"D:\scsnake\CXR_health"
    else:
        base_directory = str(Path.home())
    controller = AppController(base_directory)
    controller.run()
    sys.exit(app.exec())
