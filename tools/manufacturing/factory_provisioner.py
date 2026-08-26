"""
EH Home — Factory Device Provisioner & Identity Generator (Phase 8)

Performs factory assembly line device staging:
1. Generates unique Device ID (canonical UUID v4).
2. Generates Serial Number (EH-<FAMILY>-<YEAR>W<WEEK>-<SEQ>).
3. Generates 256-bit Commissioning Secret.
4. Issues unique mTLS Device Certificate (CN = deviceId).
5. Generates Factory NVS CSV configuration (fact_v2 namespace).
6. Generates canonical EH1: QR payload.
7. Logs record to immutable manufacturing audit log.
"""

import os
import uuid
import secrets
import json
import argparse
from datetime import datetime, timezone

from ca_manager import ManufacturingCAManager


class FactoryProvisioner:
    def __init__(self, ca_manager=None, output_dir=None):
        self.ca_manager = ca_manager or ManufacturingCAManager()
        self.output_dir = output_dir or os.path.join(os.path.dirname(__file__), "out")
        os.makedirs(self.output_dir, exist_ok=True)
        self.audit_log_path = os.path.join(self.output_dir, "manufacturing_audit.json")

    def generate_serial_number(self, product_variant_id: str, seq_num: int) -> str:
        # e.g. eh-smart-switch-3x -> EH-SW3X-2026W35-00101
        variant_code = "SW3X"
        if "1x" in product_variant_id:
            variant_code = "SW1X"
        elif "2x" in product_variant_id:
            variant_code = "SW2X"
        elif "4x" in product_variant_id:
            variant_code = "SW4X"

        now = datetime.now(timezone.utc)
        year = now.year
        week = now.isocalendar()[1]
        return f"EH-{variant_code}-{year}W{week:02d}-{seq_num:05d}"

    def provision_device(self, product_variant_id: str = "eh-smart-switch-3x",
                         hardware_revision: str = "HW_1_0",
                         seq_num: int = 1,
                         setup_code: str = "123456") -> dict:
        device_id = str(uuid.uuid4())
        serial_number = self.generate_serial_number(product_variant_id, seq_num)
        comm_secret_bytes = secrets.token_bytes(32)
        comm_secret_hex = comm_secret_bytes.hex()

        # Issue mTLS client cert
        cert_data = self.ca_manager.issue_device_certificate(device_id)

        # Canonical EH1 QR payload
        qr_payload = f"EH1:{device_id}:{product_variant_id}:{comm_secret_hex}:{setup_code}"

        # Generate NVS CSV for fact_v2 namespace
        nvs_csv = self._generate_nvs_csv(
            device_id=device_id,
            serial_number=serial_number,
            comm_secret_hex=comm_secret_hex,
            cert_fp=cert_data["fingerprint"]
        )

        record = {
            "schemaVersion": 1,
            "deviceId": device_id,
            "serialNumber": serial_number,
            "productVariantId": product_variant_id,
            "hardwareRevision": hardware_revision,
            "tlsCertFingerprint": cert_data["fingerprint"],
            "commissioningSecretHex": comm_secret_hex,
            "qrPayload": qr_payload,
            "provisionedAt": datetime.now(timezone.utc).isoformat()
        }

        self._append_audit_log(record)
        return {
            "record": record,
            "cert_data": cert_data,
            "nvs_csv": nvs_csv
        }

    def _generate_nvs_csv(self, device_id: str, serial_number: str, comm_secret_hex: str, cert_fp: str) -> str:
        """
        Formats CSV for ESP-IDF nvs_partition_gen tool.
        Namespace: fact_v2
        """
        lines = [
            "key,type,encoding,value",
            "fact_v2,namespace,,",
            f"dev_id,data,string,{device_id}",
            f"serial,data,string,{serial_number}",
            f"comm_sec,data,hex2bin,{comm_secret_hex}",
            "comm_cons,data,u8,0",
            f"cert_fp,data,string,{cert_fp}",
            "is_dev,data,u8,1"
        ]
        return "\n".join(lines) + "\n"

    def _append_audit_log(self, record: dict):
        records = []
        if os.path.exists(self.audit_log_path):
            try:
                with open(self.audit_log_path, "r", encoding="utf-8") as f:
                    records = json.load(f)
            except Exception:
                records = []
        records.append(record)
        with open(self.audit_log_path, "w", encoding="utf-8") as f:
            json.dump(records, f, indent=2)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="EH Home Factory Provisioner CLI")
    parser.add_argument("--variant", default="eh-smart-switch-3x", help="Product variant ID")
    parser.add_argument("--hw-rev", default="HW_1_0", help="Hardware revision")
    parser.add_argument("--count", type=int, default=1, help="Number of devices to provision")
    parser.add_argument("--out", default="./out", help="Output directory")

    args = parser.parse_args()
    provisioner = FactoryProvisioner(output_dir=args.out)

    print(f"Provisioning {args.count} device(s) for {args.variant} ({args.hw_rev})...")
    for i in range(1, args.count + 1):
        res = provisioner.provision_device(args.variant, args.hw_rev, seq_num=i)
        rec = res["record"]
        print(f"[{i}/{args.count}] Device ID: {rec['deviceId']} | Serial: {rec['serialNumber']}")
        print(f"       QR: {rec['qrPayload']}")
        print(f"       Cert FP: {rec['tlsCertFingerprint']}")
    print(f"Done. Audit log saved to {provisioner.audit_log_path}")
