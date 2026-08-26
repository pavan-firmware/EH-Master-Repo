"""
EH Home — Manufacturing PKI & Provisioner Unit Tests (Phase 8)
"""

import os
import unittest
import tempfile
import json
import re

from ca_manager import ManufacturingCAManager
from factory_provisioner import FactoryProvisioner


class TestManufacturingPKI(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.ca_manager = ManufacturingCAManager(base_dir=self.temp_dir.name)
        self.provisioner = FactoryProvisioner(ca_manager=self.ca_manager, output_dir=self.temp_dir.name)

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_ca_hierarchy_generation(self):
        self.ca_manager.init_test_ca_hierarchy()
        self.assertTrue(os.path.exists(self.ca_manager.root_ca_crt))
        self.assertTrue(os.path.exists(self.ca_manager.device_ca_crt))

    def test_device_certificate_issuance_cn_matches_device_id(self):
        device_id = "0194fe23-7a1b-7890-a123-456789abcdef"
        cert_data = self.ca_manager.issue_device_certificate(device_id)

        self.assertEqual(cert_data["device_id"], device_id)
        self.assertTrue(cert_data["cert_pem"].startswith("-----BEGIN CERTIFICATE-----"))
        self.assertTrue(cert_data["key_pem"].startswith("-----BEGIN EC PRIVATE KEY-----") or cert_data["key_pem"].startswith("-----BEGIN PRIVATE KEY-----"))
        self.assertEqual(len(cert_data["fingerprint"]), 64)

    def test_factory_provisioning_flow(self):
        res = self.provisioner.provision_device(
            product_variant_id="eh-smart-switch-3x",
            hardware_revision="HW_1_0",
            seq_num=42,
            setup_code="987654"
        )
        rec = res["record"]
        self.assertEqual(rec["schemaVersion"], 1)
        self.assertEqual(rec["productVariantId"], "eh-smart-switch-3x")
        self.assertEqual(rec["hardwareRevision"], "HW_1_0")
        self.assertTrue(re.match(r"^EH-SW3X-\d{4}W\d{2}-00042$", rec["serialNumber"]))
        self.assertEqual(len(rec["commissioningSecretHex"]), 64)

        # Check QR format: EH1:<deviceId>:<variant>:<secretHex>:<setupCode>
        qr = rec["qrPayload"]
        self.assertTrue(qr.startswith("EH1:"))
        parts = qr.split(":")
        self.assertEqual(len(parts), 5)
        self.assertEqual(parts[0], "EH1")
        self.assertEqual(parts[1], rec["deviceId"])
        self.assertEqual(parts[2], "eh-smart-switch-3x")
        self.assertEqual(parts[3], rec["commissioningSecretHex"])
        self.assertEqual(parts[4], "987654")

    def test_nvs_csv_generation(self):
        res = self.provisioner.provision_device()
        nvs_csv = res["nvs_csv"]

        self.assertIn("key,type,encoding,value", nvs_csv)
        self.assertIn("fact_v2,namespace,,", nvs_csv)
        self.assertIn("dev_id,data,string,", nvs_csv)
        self.assertIn("serial,data,string,", nvs_csv)
        self.assertIn("comm_sec,data,hex2bin,", nvs_csv)
        self.assertIn("comm_cons,data,u8,0", nvs_csv)
        self.assertIn("cert_fp,data,string,", nvs_csv)
        self.assertIn("is_dev,data,u8,1", nvs_csv)

    def test_manufacturing_audit_logging(self):
        self.provisioner.provision_device(seq_num=1)
        self.provisioner.provision_device(seq_num=2)

        audit_path = os.path.join(self.temp_dir.name, "manufacturing_audit.json")
        self.assertTrue(os.path.exists(audit_path))
        with open(audit_path, "r", encoding="utf-8") as f:
            logs = json.load(f)
        self.assertEqual(len(logs), 2)
        self.assertEqual(logs[0]["schemaVersion"], 1)
        self.assertEqual(logs[1]["schemaVersion"], 1)


if __name__ == "__main__":
    unittest.main()
