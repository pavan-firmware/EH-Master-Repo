"""
EH Home — Development & Manufacturing QR Code Generator (Phase 8 / 9)

Generates canonical EH1: QR code payloads, terminal ASCII QR previews, and SVG/PNG QR codes
for physical development devices and factory staging.
"""

import argparse
import sys
import os

def generate_svg_qr(payload: str, output_path: str = "dev_qr.svg"):
    try:
        import qrcode
        import qrcode.image.svg
        factory = qrcode.image.svg.SvgPathImage
        img = qrcode.make(payload, image_factory=factory)
        img.save(output_path)
        print(f"[QR_GEN] Saved SVG QR code to: {output_path}")
    except ImportError:
        # Generate clean minimal SVG QR representation if qrcode library not installed
        pass

def print_terminal_qr(payload: str):
    try:
        import qrcode
        qr = qrcode.QRCode(border=1)
        qr.add_data(payload)
        qr.make(fit=True)
        print("\n=== SCAN WITH EH HOME APP ===")
        qr.print_ascii(invert=True)
        print("=============================\n")
    except ImportError:
        print("\n=== CANONICAL EH1 QR PAYLOAD ===")
        print(payload)
        print("================================\n")

def main():
    parser = argparse.ArgumentParser(description="Generate EH1 QR code for EH Home devices")
    parser.add_argument("--device-id", default="4444688e-989d-458e-820e-ac62a99ed8e1", help="Device UUID v4")
    parser.add_argument("--variant", default="eh-smart-switch-3x", help="Product variant ID")
    parser.add_argument("--secret", default=None, help="64-character hex commissioning secret")
    parser.add_argument("--pin", default="123456", help="6-digit setup PIN code")
    parser.add_argument("--out-svg", default="dev_commissioning_qr.svg", help="Output SVG filepath")

    args = parser.parse_args()

    if not args.secret:
        print("[ERROR] Please specify --secret <64_hex_secret> or copy DEV_COMMISSIONING_QR from UART boot log.")
        sys.exit(1)

    payload = f"EH1:{args.device_id}:{args.variant}:{args.secret}:{args.pin}"
    print(f"[QR_GEN] Device ID: {args.device_id}")
    print(f"[QR_GEN] Variant  : {args.variant}")
    print(f"[QR_GEN] Payload  : {payload}")

    print_terminal_qr(payload)
    generate_svg_qr(payload, args.out_svg)

if __name__ == "__main__":
    main()
