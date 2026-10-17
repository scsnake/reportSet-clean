import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch


SCRIPT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

from TB_CXR_copy_core import DiskScanResult, DiskState, scan_disk


class FakeDataset(dict):
    StudyDate = "20260828"


class ScanDiskTests(unittest.TestCase):
    def test_reports_a_missing_disk_without_copying(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)

            result = scan_disk(root / "missing", root / "destination")

        self.assertEqual(result.state, DiskState.DISCONNECTED)
        self.assertEqual(result.total, 0)

    def test_copies_then_reports_the_same_disk_as_up_to_date(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "usb"
            source_file = source / "DCM" / "12345" / "I0001"
            source_file.parent.mkdir(parents=True)
            source_file.write_bytes(b"DICOM test payload")
            destination = root / "destination"
            dataset = FakeDataset(
                AccessionNumber="ACC001",
                PatientID="PAT001",
            )
            progress_events = []

            with patch("TB_CXR_copy_core.pydicom.dcmread", return_value=dataset):
                first = scan_disk(source, destination, progress_events.append)
                second = scan_disk(source, destination)

            copied_file = destination / "20260828" / "20260828_ACC001_12345_PAT001"
            self.assertTrue(copied_file.exists())
            self.assertEqual(first.state, DiskState.COPIED)
            self.assertEqual(first.copied, 1)
            self.assertEqual(first.corrupted_by_date, {"20260828": 1})
            self.assertEqual(progress_events[-1].processed, 1)
            self.assertEqual(second.state, DiskState.UP_TO_DATE)
            self.assertEqual(second.skipped, 1)

    def test_reports_a_connected_disk_with_no_matching_dicoms(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "usb"
            source.mkdir()

            result = scan_disk(source, root / "destination")

        self.assertEqual(result.state, DiskState.NO_DICOM)


class ConsoleDashboardTests(unittest.TestCase):
    def test_dashboard_has_one_concise_line_per_disk(self):
        from TB_CXR_copy import render_dashboard

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            disconnected = scan_disk(root / "F", root / "destination")
            empty_source = root / "H"
            empty_source.mkdir()
            no_dicom = scan_disk(empty_source, root / "destination")

        dashboard = render_dashboard(
            [disconnected, no_dicom],
            destination=Path("D:/scsnake/CXR_health"),
            checked_at=datetime(2026, 8, 28, 10, 30),
            next_scan_seconds=30,
        )

        self.assertIn("F", dashboard)
        self.assertIn("not connected", dashboard)
        self.assertIn("H", dashboard)
        self.assertIn("no matching DICOM files", dashboard)
        self.assertIn("Next scan in 30s", dashboard)
        self.assertEqual(dashboard.count("\n"), 5)


class GuiStatusTests(unittest.TestCase):
    def test_formats_short_status_and_count_columns(self):
        from TB_CXR_copy_gui import format_result

        disconnected = DiskScanResult(
            disk_label="F:",
            source=Path("F:/"),
            state=DiskState.DISCONNECTED,
        )
        current = DiskScanResult(
            disk_label="H:",
            source=Path("H:/"),
            state=DiskState.UP_TO_DATE,
            total=12,
            skipped=12,
        )
        copied = DiskScanResult(
            disk_label="I:",
            source=Path("I:/"),
            state=DiskState.COPIED,
            total=12,
            copied=2,
            skipped=10,
        )

        self.assertEqual(format_result(disconnected), ("Not connected", "-", False))
        self.assertEqual(format_result(current), ("Up to date", "12 files", False))
        self.assertEqual(
            format_result(copied),
            ("Copy complete", "2 copied / 12 total", False),
        )


if __name__ == "__main__":
    unittest.main()
