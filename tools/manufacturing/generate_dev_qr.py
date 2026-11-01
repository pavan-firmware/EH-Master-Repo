"""
EH Home — Development & Manufacturing QR Code Generator (Phase 8 / 9)

Generates canonical EH1: QR code payloads, standalone offline SVG QR preview, and
a self-contained HTML page that works 100% offline without any external scripts or CDNs.
"""

import argparse
import sys
import os
import re
import qrcode
import qrcode.image.svg

HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>EH Home — Device QR Code</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #090D14;
            color: #FFFFFF;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
            box-sizing: border-box;
        }
        .card {
            background-color: #121824;
            border: 1px solid #1E293B;
            border-radius: 24px;
            padding: 32px;
            text-align: center;
            max-width: 440px;
            width: 100%;
            box-shadow: 0 10px 30px rgba(0,0,0,0.5);
        }
        h1 {
            font-size: 20px;
            margin-top: 0;
            margin-bottom: 8px;
            color: #3B82F6;
            letter-spacing: 1px;
        }
        .subtitle {
            font-size: 13px;
            color: #94A3B8;
            margin-bottom: 24px;
        }
        .qr-wrapper {
            background-color: #FFFFFF;
            padding: 16px;
            border-radius: 16px;
            display: inline-block;
            margin-bottom: 20px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        }
        .qr-wrapper svg {
            display: block;
            width: 260px;
            height: 260px;
        }
        .payload-box {
            background-color: #090D14;
            border: 1px solid #1E293B;
            border-radius: 12px;
            padding: 12px;
            font-family: monospace;
            font-size: 11px;
            color: #38BDF8;
            word-break: break-all;
            text-align: left;
            user-select: all;
        }
        .instruction {
            font-size: 12px;
            color: #64748B;
            margin-top: 16px;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>EH HOME PROVISIONING</h1>
        <div class="subtitle">Scan this QR code with the EH Home App during setup</div>
        <div class="qr-wrapper">
            __INLINE_SVG__
        </div>
        <div class="payload-box">__PAYLOAD__</div>
        <div class="instruction">Point your mobile camera at this QR code inside the EH Home app</div>
    </div>
</body>
</html>
"""

def generate_svg_string(payload: str) -> str:
    factory = qrcode.image.svg.SvgPathImage
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=10,
        border=1,
        image_factory=factory,
    )
    qr.add_data(payload)
    qr.make(fit=True)
    img = qr.make_image()
    # Return raw SVG string
    return img.to_string(encoding="unicode")

def generate_html_qr(payload: str, output_path: str = "dev_qr_preview.html"):
    svg_str = generate_svg_string(payload)
    html_content = HTML_TEMPLATE.replace("__INLINE_SVG__", svg_str).replace("__PAYLOAD__", payload)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    abs_path = os.path.abspath(output_path)
    print(f"\n[QR_GEN] Created 100% offline standalone HTML preview:")
    print(f"         file:///{abs_path.replace(os.sep, '/')}")
    return abs_path

import webbrowser
try:
    import serial
    HAVE_SERIAL = True
except ImportError:
    serial = None
    HAVE_SERIAL = False

def print_terminal_qr(payload: str):
    """Prints a high-contrast ASCII QR code directly to the terminal."""
    try:
        qr = qrcode.QRCode(
            version=None,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=1,
            border=1,
        )
        qr.add_data(payload)
        qr.make(fit=True)
        print("\n" + "=" * 50)
        print("   SCAN THIS QR WITH EH HOME MOBILE APP:")
        print("=" * 50 + "\n")
        qr.print_ascii(invert=True)
        print("=" * 50 + "\n")
    except Exception as e:
        pass

def capture_qr_from_port(port: str, baud: int = 115200, timeout_sec: float = 3.5) -> str:
    """Resets ESP32 on specified serial port and captures DEV_COMMISSIONING_QR from boot output."""
    if not HAVE_SERIAL or serial is None:
        raise RuntimeError("pyserial is required to capture from port. Run: pip install pyserial")
    
    print(f"\n[QR_CAPTURE] Connecting to {port} @ {baud} baud...")
    ser = serial.Serial(port, baud, timeout=0.1)
    try:
        # Hardware auto-reset pulse sequence
        ser.setDTR(False)
        ser.setRTS(True)
        import time
        time.sleep(0.1)
        ser.setRTS(False)
        time.sleep(0.1)
        ser.setDTR(True)
        time.sleep(0.05)
        ser.setDTR(False)

        print(f"[QR_CAPTURE] Reset ESP32. Waiting for bootloader & factory identity...")
        start_time = time.time()
        buffer = ""
        while time.time() - start_time < timeout_sec:
            chunk = ser.read(512)
            if chunk:
                buffer += chunk.decode("utf-8", errors="replace")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if "DEV_COMMISSIONING_QR:" in line:
                        match = re.search(r'(EH1:[a-zA-Z0-9\-]+:[a-zA-Z0-9\-]+:[a-fA-F0-9]+:[0-9]+)', line)
                        if match:
                            ser.close()
                            return match.group(1)
            time.sleep(0.02)
    finally:
        if ser.is_open:
            ser.close()
    return None

def main():
    parser = argparse.ArgumentParser(description="Generate EH1 QR code for EH Home devices")
    parser.add_argument("raw_input", nargs="?", default=None, help="Raw DEV_COMMISSIONING_QR line or EH1: payload")
    parser.add_argument("--port", default=None, help="COM port of connected ESP32 (e.g. COM6) to capture QR on boot")
    parser.add_argument("--payload", default=None, help="Full canonical EH1:... payload string")
    parser.add_argument("--device-id", default="4444688e-989d-458e-820e-ac62a99ed8e1", help="Device UUID v4")
    parser.add_argument("--variant", default="eh-smart-switch-3x", help="Product variant ID")
    parser.add_argument("--secret", default=None, help="64-character hex commissioning secret")
    parser.add_argument("--pin", default="123456", help="6-digit setup PIN code")
    parser.add_argument("--out-html", default=None, help="Output HTML filepath")
    parser.add_argument("--ascii", action="store_true", help="Print ASCII QR code directly to terminal")
    parser.add_argument("--open", action="store_true", help="Automatically open generated HTML preview in browser")

    args = parser.parse_args()

    payload = None

    if args.port:
        captured = capture_qr_from_port(args.port)
        if captured:
            payload = captured
            print(f"[QR_CAPTURE] Successfully captured live payload from {args.port}!")
        else:
            print(f"[QR_CAPTURE] WARNING: No DEV_COMMISSIONING_QR detected on {args.port} within timeout.")

    if not payload:
        raw = args.raw_input or args.payload
        if raw:
            match = re.search(r'(EH1:[a-zA-Z0-9\-]+:[a-zA-Z0-9\-]+:[a-fA-F0-9]+:[0-9]+)', raw)
            if match:
                payload = match.group(1)
            elif raw.startswith("EH1:"):
                payload = raw.strip()

    if not payload and args.secret:
        payload = f"EH1:{args.device_id}:{args.variant}:{args.secret.strip()}:{args.pin}"

    if not payload:
        payload = "EH1:4444688e-989d-458e-820e-ac62a99ed8e1:eh-smart-switch-3x:61a58854c26cfd0199d35904b01e8531ffc0926f0ea14f30ef1568106c7fca20:123456"

    print(f"\n[QR_GEN] Canonical Payload:\n  {payload}\n")

    # Output HTML
    html_target = args.out_html or os.path.join(os.path.dirname(os.path.abspath(__file__)), "dev_qr_preview.html")
    html_path = generate_html_qr(payload, html_target)

    # ASCII Terminal QR
    if args.ascii or args.port:
        print_terminal_qr(payload)

    # Auto-open browser
    if args.open or args.port:
        print("[QR_GEN] Opening QR Code preview in your default browser...")
        webbrowser.open(f"file:///{html_path.replace(os.sep, '/')}")

    print(f"[QR_GEN] Ready for phone scanning.\n")

if __name__ == "__main__":
    main()
