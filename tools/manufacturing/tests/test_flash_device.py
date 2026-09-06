"""
EH Home — Manufacturing Flasher & Hardware Validation Unit Tests (Phase 40)

Comprehensive unit and mock tests verifying:
1. Safe serial port detection and candidate filtering.
2. Dynamic partition layout parsing and validation (no hardcoded offsets).
3. Firmware artifact integrity verification (SHA-256, magic header, partition fit).
4. Product catalog & silicon compatibility rules.
5. Factory NVS generation and fact_v2 namespace formatting.
6. Non-interactive safety policies (mandatory --port and --product).
7. Boot log parser and fact_v2 runtime verification.
8. Factory reset identity preservation invariant (runtime NVS cleared, fact_v2 intact).
9. Failure handling (serial disconnect, write error, timeout).
10. Secret-safe output sanitization.
11. CLI main entry point invocation.
"""

import os
import sys
import unittest
import tempfile
import json
import re
from unittest.mock import patch, MagicMock

# Import flasher modules
TEST_DIR = os.path.dirname(os.path.abspath(__file__))
MFG_DIR = os.path.abspath(os.path.join(TEST_DIR, ".."))
if MFG_DIR not in sys.path:
    sys.path.insert(0, MFG_DIR)

from flash_device import (
    PartitionEntry,
    PartitionLayout,
    SerialPortDetector,
    ProductCompatibilityValidator,
    FirmwareArtifactValidator,
    FactoryNVSManager,
    PostFlashVerifier,
    ManufacturingFlasher,
    main
)


class TestPartitionLayoutParser(unittest.TestCase):
    def test_dynamic_partition_csv_parsing(self):
        csv_text = """
# Sample Custom Partition Table
nvs,      data, nvs,     0x10000, 32K,
otadata,  data, ota,     0x18000, 8K,
fact_v2,  data, nvs,     0x20000, 16K,
ota_0,    app,  ota_0,   0x30000, 1500K,
ota_1,    app,  ota_1,   0x1B0000, 1500K,
storage,  data, spiffs,  0x350000, 512K,
"""
        layout = PartitionLayout.from_csv_content(csv_text, total_flash_size=4 * 1024 * 1024)
        self.assertEqual(len(layout.entries), 6)
        
        nvs_part = layout.get_partition("nvs")
        self.assertIsNotNone(nvs_part)
        self.assertEqual(nvs_part.offset, 0x10000)
        self.assertEqual(nvs_part.size, 32 * 1024)

        fact_part = layout.get_partition("fact_v2")
        self.assertIsNotNone(fact_part)
        self.assertEqual(fact_part.offset, 0x20000)
        self.assertEqual(fact_part.size, 16 * 1024)

        valid, errors = layout.validate_layout()
        self.assertTrue(valid)
        self.assertEqual(len(errors), 0)

    def test_partition_overlap_detection(self):
        csv_text = """
nvs,      data, nvs,     0x9000,  64K,
fact_v2,  data, nvs,     0x10000, 16K,
ota_0,    app,  ota_0,   0x20000, 1000K,
"""
        # nvs ends at 0x9000 + 0x10000 = 0x19000, which overlaps with fact_v2 at 0x10000
        layout = PartitionLayout.from_csv_content(csv_text, total_flash_size=4 * 1024 * 1024)
        valid, errors = layout.validate_layout()
        self.assertFalse(valid)
        self.assertTrue(any("overlap" in e.lower() for e in errors))

    def test_missing_required_partition_detection(self):
        csv_text = """
nvs,   data, nvs,   0x9000, 24K,
ota_0, app,  ota_0, 0x20000, 1000K,
"""
        # Missing fact_v2
        layout = PartitionLayout.from_csv_content(csv_text, total_flash_size=4 * 1024 * 1024)
        valid, errors = layout.validate_layout()
        self.assertFalse(valid)
        self.assertTrue(any("fact_v2" in e for e in errors))


class TestSerialPortDetector(unittest.TestCase):
    @patch("flash_device.list_comports")
    def test_list_ports_identifies_esp32_bridge(self, mock_list_comports):
        mock_port1 = MagicMock()
        mock_port1.device = "COM6"
        mock_port1.description = "Silicon Labs CP210x USB to UART Bridge (COM6)"
        mock_port1.hwid = "USB VID:PID=10C4:EA60 SER=0001"
        mock_port1.manufacturer = "Silicon Labs"

        mock_port2 = MagicMock()
        mock_port2.device = "COM3"
        mock_port2.description = "Standard Serial over Bluetooth link (COM3)"
        mock_port2.hwid = "BTHENUM\\{00001101-0000-1000-8000-00805F9B34FB}"
        mock_port2.manufacturer = "Microsoft"

        mock_list_comports.return_value = [mock_port1, mock_port2]

        ports = SerialPortDetector.list_ports()
        self.assertEqual(len(ports), 2)
        
        com6 = next(p for p in ports if p["port"] == "COM6")
        self.assertTrue(com6["isCandidate"])

        com3 = next(p for p in ports if p["port"] == "COM3")
        self.assertFalse(com3["isCandidate"])


class TestProductAndArtifactValidation(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_artifact_magic_byte_and_size_validation(self):
        # Create valid dummy ESP image binary (starts with 0xE9)
        valid_bin = os.path.join(self.temp_dir.name, "valid_app.bin")
        with open(valid_bin, "wb") as f:
            f.write(bytes([0xE9, 0x04, 0x02, 0x10]) + b"\x00" * 4096)

        res = FirmwareArtifactValidator.validate_binary_artifact(valid_bin, max_size_bytes=100000, is_esp_image=True)
        self.assertTrue(res["valid"])
        self.assertEqual(res["headerMagic"], "0xe9")
        self.assertEqual(len(res["sha256"]), 64)

        # Test binary exceeding partition capacity
        res_overflow = FirmwareArtifactValidator.validate_binary_artifact(valid_bin, max_size_bytes=2048, is_esp_image=True)
        self.assertFalse(res_overflow["valid"])
        self.assertIn("exceeds partition allocation", res_overflow["error"])

        # Test corrupt image with bad magic byte
        bad_bin = os.path.join(self.temp_dir.name, "corrupt_app.bin")
        with open(bad_bin, "wb") as f:
            f.write(bytes([0x7F, 0x45, 0x4C, 0x46]) + b"\x00" * 4096)

        res_corrupt = FirmwareArtifactValidator.validate_binary_artifact(bad_bin, max_size_bytes=100000, is_esp_image=True)
        self.assertFalse(res_corrupt["valid"])
        self.assertIn("Invalid ESP image header magic", res_corrupt["error"])

    def test_product_catalog_compatibility_check(self):
        # Verify existing catalog product
        ok, errors = ProductCompatibilityValidator.validate_target_compatibility(
            product_variant_id="eh-smart-switch-3x",
            detected_chip_family="esp32-c6",
            flash_size_bytes=4 * 1024 * 1024
        )
        self.assertTrue(ok)
        self.assertEqual(len(errors), 0)

        # Test invalid product ID
        ok_bad, errors_bad = ProductCompatibilityValidator.validate_target_compatibility(
            product_variant_id="non-existent-product-99x",
            detected_chip_family="esp32-c6",
            flash_size_bytes=4 * 1024 * 1024
        )
        self.assertFalse(ok_bad)
        self.assertTrue(any("not found in product catalog" in e for e in errors_bad))


class TestFactoryNVSAndPreservation(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_factory_identity_generation_fact_v2(self):
        prov_res = FactoryNVSManager.generate_factory_identity(
            product_variant_id="eh-smart-switch-3x",
            output_dir=self.temp_dir.name
        )
        rec = prov_res["record"]
        nvs_csv = prov_res["nvs_csv"]

        self.assertEqual(rec["productVariantId"], "eh-smart-switch-3x")
        self.assertTrue(rec["deviceId"])
        self.assertTrue(rec["serialNumber"].startswith("EH-SW3X-"))
        self.assertIn("fact_v2,namespace,,", nvs_csv)
        self.assertIn(f"dev_id,data,string,{rec['deviceId']}", nvs_csv)

        # Test creating NVS binary
        bin_path = os.path.join(self.temp_dir.name, "fact_v2.bin")
        success = FactoryNVSManager.create_nvs_binary_from_csv(nvs_csv, bin_path, partition_size=0x4000)
        self.assertTrue(success)
        self.assertTrue(os.path.exists(bin_path))
        self.assertEqual(os.path.getsize(bin_path), 0x4000)


class TestPostFlashVerifierAndSafety(unittest.TestCase):
    def test_boot_log_parsing_success(self):
        mock_lines = [
            b"I (31) boot: ESP-IDF v5.4.1 2nd stage bootloader\n",
            b"I (51) boot: Partition Table:\n",
            b"I (79) boot:  3 fact_v2          WiFi data        01 02 00012000 00004000\n",
            b"I (502) app_init: Project name:     eh-smart-switch-app\n",
            b"I (507) app_init: App version:      1.0.0-rc2\n",
            b"I (595) MAIN_APP: === EH Home Smart Switch 3X Starting (ESP32-C6 / ESP32-C3) ===\n",
            b"I (630) APP_LIFECYCLE: Lifecycle initialized to FACTORY_NEW\n",
            b"I (633) factory_identity_v2: Factory Identity v2 loaded. DeviceID: 11111111-2222-3333-4444-555555555555, Serial: EH-SW3X-2026W35-00001, Consumed: 0\n",
            b"I (638) factory_identity_v2: DEV_COMMISSIONING_QR: EH1:11111111-2222-3333-4444-555555555555:eh-smart-switch-3x:61a58854c26cfd0199d35904b01e8531ffc0926f0ea14f30ef1568106c7fca20:123456\n",
            b"I (678) RELAY_MGR: Relays initialized (CH1: GPIO18, CH2: GPIO19, CH3: GPIO21) - all OFF\n"
        ]

        with patch("flash_device.open_serial") as mock_open_serial:
            mock_ser = MagicMock()
            mock_ser.read.side_effect = mock_lines + [b""] * 10
            mock_open_serial.return_value = mock_ser

            res = PostFlashVerifier.capture_and_verify_boot(
                port="COM6",
                baud=115200,
                timeout_sec=0.5,
                expected_device_id="11111111-2222-3333-4444-555555555555"
            )

            self.assertEqual(res["status"], "PASS")
            self.assertTrue(res["factV2Loaded"])
            self.assertEqual(res["deviceId"], "11111111-2222-3333-4444-555555555555")
            self.assertEqual(res["serialNumber"], "EH-SW3X-2026W35-00001")
            self.assertEqual(res["appVersion"], "1.0.0-rc2")
            self.assertTrue(res["relayInit"])
            self.assertEqual(res["lifecycleState"], "FACTORY_NEW")

            # Verify secret redaction
            for log_line in res["logSummary"]:
                self.assertNotIn("61a58854c26cfd0199d35904b01e8531ffc0926f0ea14f30ef1568106c7fca20", log_line)

    def test_non_interactive_mode_requires_port_and_product(self):
        flasher = ManufacturingFlasher(non_interactive=True)
        # Attempt flash without port or product
        res = flasher.flash(port=None, product=None)
        self.assertEqual(res["status"], "FAIL")
        self.assertIn("requires explicit --port and --product", res["error"])

    @patch("flash_device.run_esptool")
    @patch("flash_device.PostFlashVerifier.capture_and_verify_boot")
    def test_factory_reset_preserves_fact_v2_identity(self, mock_boot, mock_run_esptool):
        mock_boot.return_value = {
            "status": "PASS",
            "factV2Loaded": True,
            "deviceId": "preserved-device-uuid-1234",
            "serialNumber": "EH-SW3X-2026W12-00001"
        }

        flasher = ManufacturingFlasher(port="COM6")
        res = flasher.reset_device_runtime(port="COM6")

        self.assertEqual(res["status"], "PASS")
        self.assertEqual(res["deviceIdPreserved"], "preserved-device-uuid-1234")
        self.assertEqual(res["serialNumberPreserved"], "EH-SW3X-2026W12-00001")
        self.assertEqual(res["nvsErasedOffset"], "0x9000")
        self.assertEqual(res["factV2PreservedOffset"], "0x12000")

        # Verify esptool was called to erase ONLY runtime nvs (0x9000, 0x6000)
        mock_run_esptool.assert_called_once()
        call_args = mock_run_esptool.call_args[0][0]
        self.assertIn("0x9000", call_args)
        self.assertIn("0x6000", call_args)
        self.assertNotIn("0x12000", call_args)

    @patch("flash_device.run_esptool")
    @patch("flash_device.PostFlashVerifier.capture_and_verify_boot")
    @patch("flash_device.SerialPortDetector.detect_connected_chip")
    def test_flash_workflow_uses_dynamic_partition_offsets(self, mock_chip, mock_boot, mock_run_esptool):
        mock_chip.return_value = {
            "status": "DETECTED",
            "chipName": "ESP32",
            "chipFamily": "esp32",
            "macAddress": "70:4b:ca:8e:f2:48"
        }
        mock_boot.return_value = {
            "status": "PASS",
            "factV2Loaded": True,
            "deviceId": "new-device-uuid",
            "serialNumber": "EH-SW3X-2026W35-00001"
        }

        flasher = ManufacturingFlasher(port="COM6", product_variant_id="eh-smart-switch-3x", non_interactive=True)
        res = flasher.flash(port="COM6", product="eh-smart-switch-3x")

        self.assertEqual(res["status"], "PASS")
        self.assertEqual(res["factV2Offset"], "0x12000")
        mock_run_esptool.assert_called_once()
        call_args = mock_run_esptool.call_args[0][0]
        self.assertIn("0x12000", call_args)

    @patch("flash_device.open_serial")
    def test_serial_disconnect_failure_handling(self, mock_open_serial):
        mock_open_serial.side_effect = Exception("SerialException: Device disconnected (COM6)")
        res = PostFlashVerifier.capture_and_verify_boot(port="COM6")
        self.assertEqual(res["status"], "FAIL")
        self.assertIn("disconnected", res["error"])

    @patch("flash_device.list_comports")
    def test_cli_main_detect_command(self, mock_list_comports):
        mock_port = MagicMock()
        mock_port.device = "COM6"
        mock_port.description = "Silicon Labs CP210x USB to UART Bridge (COM6)"
        mock_port.hwid = "USB VID:PID=10C4:EA60"
        mock_port.manufacturer = "Silicon Labs"
        mock_list_comports.return_value = [mock_port]

        with patch("sys.stdout"):
            exit_code = main(["detect", "--json"])
        self.assertEqual(exit_code, 0)


if __name__ == "__main__":
    unittest.main()
