"""
EH Home — Manufacturing PKI CA Manager (Phase 8)

Manages CA hierarchy for device provisioning:
1. Manufacturing Root CA (Long-lived root)
2. Device Issuing Intermediate CA
3. Per-Device mTLS Client Certificates (CN = deviceId)

Uses standard OpenSSL CLI to avoid external pip dependencies.
"""

import os
import subprocess
import hashlib
import tempfile


class ManufacturingCAManager:
    def __init__(self, base_dir=None):
        self.base_dir = base_dir or os.path.join(os.path.dirname(__file__), ".local_pki")
        os.makedirs(self.base_dir, exist_ok=True)
        self.root_ca_key = os.path.join(self.base_dir, "root_ca.key")
        self.root_ca_crt = os.path.join(self.base_dir, "root_ca.crt")
        self.device_ca_key = os.path.join(self.base_dir, "device_ca.key")
        self.device_ca_crt = os.path.join(self.base_dir, "device_ca.crt")

    def _run_cmd(self, cmd):
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if res.returncode != 0:
            raise RuntimeError(f"OpenSSL command failed: {cmd}\nStderr: {res.stderr}")
        return res.stdout

    def init_test_ca_hierarchy(self):
        """Generates an ephemeral development Root CA and Device Intermediate CA."""
        # 1. Root CA Config & Generation
        root_cnf_content = """[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no
[req_distinguished_name]
O = EH Home Manufacturing
CN = EH Home Root CA - DEV ONLY
[v3_ca]
basicConstraints = critical, CA:true, pathlen:1
keyUsage = critical, keyCertSign, cRLSign
"""
        root_cnf = os.path.join(self.base_dir, "root_ca.cnf")
        with open(root_cnf, "w") as f:
            f.write(root_cnf_content)

        if not os.path.exists(self.root_ca_key) or not os.path.exists(self.root_ca_crt):
            self._run_cmd(f'openssl ecparam -genkey -name prime256v1 -noout -out "{self.root_ca_key}"')
            self._run_cmd(f'openssl req -new -x509 -key "{self.root_ca_key}" -out "{self.root_ca_crt}" -days 3650 -config "{root_cnf}" -sha256')

        # 2. Device Issuing CA
        dev_ca_cnf_content = """[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_intermediate_ca
prompt = no
[req_distinguished_name]
O = EH Home Manufacturing
CN = EH Device Issuing CA 1 - DEV
[v3_intermediate_ca]
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
"""
        dev_ca_cnf = os.path.join(self.base_dir, "device_ca.cnf")
        with open(dev_ca_cnf, "w") as f:
            f.write(dev_ca_cnf_content)

        dev_ca_csr = os.path.join(self.base_dir, "device_ca.csr")
        if not os.path.exists(self.device_ca_key) or not os.path.exists(self.device_ca_crt):
            self._run_cmd(f'openssl ecparam -genkey -name prime256v1 -noout -out "{self.device_ca_key}"')
            self._run_cmd(f'openssl req -new -key "{self.device_ca_key}" -out "{dev_ca_csr}" -config "{dev_ca_cnf}" -sha256')
            self._run_cmd(f'openssl x509 -req -in "{dev_ca_csr}" -CA "{self.root_ca_crt}" -CAkey "{self.root_ca_key}" -CAcreateserial -out "{self.device_ca_crt}" -days 1825 -extfile "{dev_ca_cnf}" -extensions v3_intermediate_ca -sha256')

    def issue_device_certificate(self, device_id: str):
        """
        Issues unique device certificate signed by Device CA with CN = device_id.
        """
        self.init_test_ca_hierarchy()

        dev_key = os.path.join(self.base_dir, f"{device_id}.key")
        dev_csr = os.path.join(self.base_dir, f"{device_id}.csr")
        dev_crt = os.path.join(self.base_dir, f"{device_id}.crt")
        dev_cnf = os.path.join(self.base_dir, f"{device_id}.cnf")

        dev_cnf_content = f"""[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_client
prompt = no
[req_distinguished_name]
O = EH Home Device
CN = {device_id}
[v3_client]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, keyEncipherment, keyAgreement
extendedKeyUsage = clientAuth
"""
        with open(dev_cnf, "w") as f:
            f.write(dev_cnf_content)

        self._run_cmd(f'openssl ecparam -genkey -name prime256v1 -noout -out "{dev_key}"')
        self._run_cmd(f'openssl req -new -key "{dev_key}" -out "{dev_csr}" -config "{dev_cnf}" -sha256')
        self._run_cmd(f'openssl x509 -req -in "{dev_csr}" -CA "{self.device_ca_crt}" -CAkey "{self.device_ca_key}" -CAcreateserial -out "{dev_crt}" -days 730 -extfile "{dev_cnf}" -extensions v3_client -sha256')

        with open(dev_crt, "r", encoding="utf-8") as f:
            cert_pem = f.read()
        with open(dev_key, "r", encoding="utf-8") as f:
            key_pem = f.read()

        # Compute SHA-256 fingerprint from DER certificate
        der_bytes = subprocess.run(f'openssl x509 -in "{dev_crt}" -outform DER', shell=True, capture_output=True).stdout
        fingerprint = hashlib.sha256(der_bytes).hexdigest()

        return {
            "device_id": device_id,
            "cert_pem": cert_pem,
            "key_pem": key_pem,
            "fingerprint": fingerprint
        }
