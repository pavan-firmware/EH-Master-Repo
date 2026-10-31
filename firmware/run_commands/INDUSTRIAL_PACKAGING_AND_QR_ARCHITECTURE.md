# Industrial Packaging Line & Device-to-Box QR Architecture

This guide documents how commercial smart home (Matter, Apple HomeKit, Tuya) and smartphone (Realme, Foxconn, Apple) assembly lines solve physical QR code pairing and packaging at scale.

---

## 1. The Core Industrial Problem

When producing thousands of identical devices (e.g. 100 units of `EH-SK-3X`), every single unit contains a unique cryptographically generated identity (`DeviceId`, `Serial`, `CommissioningSecret`, `SetupPIN`).

**If 100 stickers are printed in advance and left on a table:**
Human operators will inevitably stick Label #5 on Box #6, causing severe device-to-box mismatches.

---

## 2. The Two Standard Factory Methodologies

### Method 1: On-Demand "Twin-Sticker" Dispense (Flashing Station)
*Best suited for low-to-medium volume manufacturing lines where flashing and boxing occur at the same station.*

```text
[Operator inserts Board into JIG]
          │
          ▼
[PC Flashes Unique Identity & Runs Functional Tests]
          │
          ▼
[Thermal Printer Dispenses EXACTLY 2 Twin Stickers]
   ├── Sticker 1 (Small): Pasted directly onto the PCB / Enclosure
   └── Sticker 2 (Large): Pasted directly onto the Retail Packaging Box
          │
          ▼
[Operator places device inside its box immediately]
```
- **Invariant:** Only **one** pair of stickers ever exists on the workbench at any given time.
- **Mix-up probability:** 0%.

---

### Method 2: "Scan-to-Print" Kitting Station (Foxconn / Smartphone Lines)
*Used in high-speed, conveyor-based mass manufacturing where PCB flashing (Station 1) and Packaging (Station 2) are separated.*

1. **Station 1 (Flashing & Assembly):**
   - JIG flashes the board and dispenses **Sticker 1** (micro-QR + Serial).
   - The worker applies Sticker 1 to the device enclosure.
   - The assembled unit travels down the conveyor to the packing station.
2. **Station 2 (Packaging & Kitting):**
   - The packaging worker holds a 2D handheld barcode scanner.
   - The worker picks up the device and **scans the QR code on the physical unit**.
   - The system looks up the serial in the manufacturing database, verifies all tests passed (`STATUS: PASS`), and **instantly triggers the printer to print the matching Retail Box Label and Quick Start Card on demand**.
   - The worker attaches the label to the box and places the device inside.
   - **Double-Scan Verification:** The worker scans the box label barcode. If the device and box match, a green confirmation chimes.

---

## 3. Daily Development: Instant Zero-Command QR Capture

For daily developer testing, manual Python script execution has been replaced with automatic COM-port capture.

### Instant QR Capture for Connected Board:
```powershell
powershell .\scripts\show_board_qr.ps1 -Port COM6
```
- Connects to COM6.
- Resets the ESP32 and captures `DEV_COMMISSIONING_QR` from the bootloader in ~600ms.
- **Prints an ASCII QR code directly inside your PowerShell console.**
- **Pops open `dev_qr_preview.html` in your default browser.**

### Flash & Auto-Show QR in One Step:
```powershell
powershell .\scripts\flash_and_show_qr.ps1 -Port COM6
```
Flashes the board and immediately launches the QR code upon completion.
