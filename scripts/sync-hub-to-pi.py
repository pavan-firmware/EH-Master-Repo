#!/usr/bin/env python3
"""
EH Home - Raspberry Pi 3B+ Automated Hub Deployment & Synchronization Tool
Uses Paramiko SFTP/SSH to deploy hub services to eh-hub.local without rewriting.
"""

import os
import sys
import argparse
import paramiko

PI_HOST = os.environ.get("EH_HUB_HOST", "eh-hub.local")
PI_PORT = int(os.environ.get("EH_HUB_PORT", 22))
PI_USER = os.environ.get("EH_HUB_USER", "ehpavan")
PI_PASSWORD = os.environ.get("EH_HUB_PASSWORD", "2004")
REMOTE_BASE_DIR = "/home/ehpavan/eh-hub"

def get_ssh_client():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=PI_HOST,
        port=PI_PORT,
        username=PI_USER,
        password=PI_PASSWORD,
        timeout=10,
    )
    return client

def run_remote_command(client, command, sudo=False):
    if sudo:
        command = f"echo '{PI_PASSWORD}' | sudo -S {command}"
    stdin, stdout, stderr = client.exec_command(command)
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    return out, err

def sftp_sync_dir(sftp, local_dir, remote_dir):
    try:
        sftp.mkdir(remote_dir)
    except IOError:
        pass

    for item in os.listdir(local_dir):
        if item in [".git", "node_modules", ".cache", "__pycache__"]:
            continue
        local_path = os.path.join(local_dir, item)
        remote_path = f"{remote_dir}/{item}"

        if os.path.isdir(local_path):
            sftp_sync_dir(sftp, local_path, remote_path)
        else:
            sftp.put(local_path, remote_path)
            print(f"  [SFTP] Synced: {item} -> {remote_path}")

def main():
    parser = argparse.ArgumentParser(description="EH Home Pi 3B+ Sync & Exec Tool")
    parser.add_argument("--exec", dest="command", help="Execute remote command on Pi")
    parser.add_argument("--sudo", action="store_true", help="Execute as sudo")
    parser.add_argument("--sync", dest="local_dir", help="Local directory to sync to Pi")
    parser.add_argument("--remote-dir", default=REMOTE_BASE_DIR, help="Remote target directory")
    args = parser.parse_args()

    client = get_ssh_client()
    try:
        if args.local_dir:
            abs_local = os.path.abspath(args.local_dir)
            print(f"[*] Syncing '{abs_local}' to '{args.remote_dir}' on {PI_HOST}...")
            sftp = client.open_sftp()
            sftp_sync_dir(sftp, abs_local, args.remote_dir)
            sftp.close()
            print("[+] Sync complete!")

        if args.command:
            print(f"[*] Executing on {PI_HOST}: {args.command}")
            out, err = run_remote_command(client, args.command, sudo=args.sudo)
            if out:
                print(out)
            if err:
                print(f"[STDERR] {err}")
    finally:
        client.close()

if __name__ == "__main__":
    main()
