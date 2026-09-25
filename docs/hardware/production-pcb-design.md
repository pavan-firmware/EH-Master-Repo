# EH Home — Production-Grade Smart Switch Hardware & PCB Design Specification

**Target Product:** EH Smart Switch (3X / 4X Channel with BL0942 Energy Metering)  
**Target Silicon:** Espressif ESP32-C6-WROOM-1-N4 (or ESP32-C3-WROOM-02)  
**Standard Compliance:** IEC/EN 60669-2-1, IEC 62368-1, UL 60730-1, RoHS  

---

## 1. Executive Summary & Protection Philosophy

Operating inside residential wall switchboards presents the harshest electrical environment in consumer electronics:
- **Grid Voltage Surges & Lightning Spikes:** Voltage spikes exceeding 2kV–4kV (IEC 61000-4-5).
- **Broken / Floating Neutral:** Voltage rises up to 415V–440V RMS in 3-phase residential distribution.
- **Inductive Kickback Arcing:** High inductive kickback when switching ceiling fans, transformers, and fluorescent ballasts.
- **Capacitive/Inductive Cable Coupling:** Long wall switch cables (5–15 meters) picking up 230V AC induced noise.
- **Thermal Buildup:** Confined plastic wall gang boxes without active ventilation.

This hardware design provides **5-Tier Hardware Protection** to guarantee zero-fire risk, failure containment, continuous noise immunity, and 10+ year operating life.

---

## 2. 5-Tier Industrial Protection Architecture

```
                  ┌─────────────────────────────────────────────────────────┐
                  │                 MAINS 90V - 250V AC                     │
                  └───────────────────────────┬─────────────────────────────┘
                                              │
                    [Tier 1: Input Overcurrent, Surge & 440V Protection]
                    ├─ 2A / 250V Thermal Slow-Blow Fuse (Micro TR5 / SMD)
                    ├─ 14D561K Metal Oxide Varistor (Surge Clamp @ 350VAC/560V)
                    ├─ 10D-9 Inrush NTC Thermistor
                    └─ 0.1µF 275VAC Class-X2 Safety Suppression Capacitor
                                              │
                                              ▼
                    [Tier 2: Dual Galvanic & Low-Noise Power Supply]
                    ├─ HLK-PM01 (5V 3W) / VIPer12A Flyback Isolated SMPS (3kV Isolation)
                    ├─ Output Common-Mode Choke + 470µF Low-ESR Filter
                    └─ AP2112K-3.3 / ME6211 Ultra-Low-Noise LDO (3.3V 600mA)
                                              │
                      ┌───────────────────────┴────────────────────────┐
                      ▼                                                ▼
     [Tier 3: Relay Arc & Inductive Protection]    [Tier 4: Long-Wire Switch ESD / Noise]
     ├─ 10A / 250VAC Hongfa HF32F-G Relays         ├─ 1kΩ Series + 10kΩ Pull-Up Resistor
     ├─ RC Snubbers (100Ω 1W + 100nF 630V X2)      ├─ 100nF High-Frequency Decoupling Cap
     ├─ SS14 / 1N4148W Flyback Diodes              ├─ Bidirectional TVS Diode (ESD5Z3.3)
     └─ AO3400A N-MOSFET + 10kΩ Gate Pull-Down     └─ Digital Debounce Filter in ESP32 ISR
                                              │
                                              ▼
                        [Tier 5: Creepage, Thermal & Air-Gap PCB Isolation]
                        ├─ 2.0mm Physical PCB Isolation Slots (Milling Cutouts)
                        ├─ >4.5mm High-Voltage to Low-Voltage Clearance
                        ├─ 2oz (70µm) Copper Traces + Exposed Solder Tinned High-Current Paths
                        └─ Dedicated Keep-Out Zone under ESP32-C6 PCB Antenna
```

---

## 3. Detailed Circuit Schematics by Subsystem

### 3.1 Subsystem A: AC Input Protection & Power Supply

```
 LIVE_IN ────[ FUSE 2A 250V ]──┬───[ NTC 10D-9 ]───┬─────────────── L_AC_IN (HLK-PM01 Pin 1)
                               │                   │
                            [ 14D561K ]         [ X2 CAP ]
                              (MOV)            (0.1uF 275V)
                               │                   │
NEUTRAL ───────────────────────┴───────────────────┴─────────────── N_AC_IN (HLK-PM01 Pin 2)

HLK-PM01:
  Pin 3 (+Vout: 5.0V) ──┬──[ 470uF 16V ]──┬──[ 0.1uF ]──> +5V_RELAY_RAIL
                        │                 │
                        │             [ AP2112K-3.3 ] (Pin 1: VIN, Pin 3: EN)
                        │                 │
                        │                 └── Pin 5 (VOUT) ──┬──[ 100uF 10V ]──┬──[ 0.1uF ]──> +3V3_MCU
  Pin 4 (-Vout: GND)  ──┴─────────────────┴──────────────────┴─────────────────┴─────────────> GND_DIGITAL
```

---

### 3.2 Subsystem B: Relay Driver Stage with Snubber (Per Channel)

```
+5V_RELAY_RAIL ──────────┬──────────────────────────────────────┐
                         │                                      │
                    [ 1N4148W / SS14 ] (Cathode to +5V)      [ RELAY COIL ]
                         │                                      │
                         ├──────────────────────────────────────┘
                         │
                      Drain (AO3400A N-MOSFET)
                         │
GPIO18 (CH1_RELAY) ──[ 1kΩ ]── Gate
                         │
                     [ 10kΩ ] (Pull-Down to GND)
                         │
                      Source ──── GND_DIGITAL

Relay AC Contact Circuit:
AC_LIVE_BUS ──────── COM Contact
                      NO Contact ──┬──[ 100Ω 1W ]──[ 100nF 630V ]── AC_LIVE_BUS (Arc Snubber)
                                   │
                                   └───────────────────────────── LOAD_OUT_CH1 (To Terminal)
```

---

### 3.3 Subsystem C: Manual Wall Switch Input Filter (Per Channel)

```
+3V3_MCU ────────[ 10kΩ Pull-Up ]
                     │
WALL_SW_1 Terminal ──┼──[ 1kΩ Series ]──┬──[ ESD5Z3.3 TVS ]──┬──[ 100nF Cap ]──> GPIO 4 (ESP32-C6)
                     │                  │                    │
                     │                 GND                  GND
WALL_SW_COM ─────────┴─────────────────────────────────────────────────────────> GND_DIGITAL
```

---

### 3.4 Subsystem D: BL0942 Energy Metering Circuit

```
NEUTRAL_IN ───[ 1mΩ 2W 1% Shunt Resistor ]─── NEUTRAL_LOAD_BUS
              │                         │
            [ 33Ω ]                   [ 33Ω ]
              │                         │
           Pin 2 (IP)                Pin 3 (IN)
              │                         │
            [ 10nF to GND ]           [ 10nF to GND ]

AC_LIVE_IN ──[ 240kΩ ]──[ 240kΩ ]──[ 240kΩ ]──[ 240kΩ ]──┬──[ 1kΩ 1% ]── GND
(1206 HV)                                                │
                                                      [ 33Ω ]
                                                         │
                                                      Pin 4 (VP)
                                                         │
                                                      [ 10nF to GND ]

BL0942 Pin Connections:
- Pin 1 (VDD): +3.3V DC with 0.1µF + 10µF bypass caps
- Pin 5 (GND): Connected to GND_DIGITAL
- Pin 11 (TX): Connected directly to ESP32-C6 / ESP32-C3 GPIO 7 (UART1 RX)
```

---

### 3.5 Subsystem E: Production MCU Pin Assignments (ESP32-C6 vs ESP32-C3)

| Function | ESP32-C6-WROOM-1 | ESP32-C3-WROOM-02 | Direction | Electrical Logic / Hardware Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Relay CH1 Driver** | `GPIO 18` | `GPIO 18` | Output | Active HIGH $\to$ AO3400A Gate (via 1kΩ) |
| **Relay CH2 Driver** | `GPIO 19` | `GPIO 19` | Output | Active HIGH $\to$ AO3400A Gate (via 1kΩ) |
| **Relay CH3 Driver** | `GPIO 20` | **`GPIO 10`** | Output | Active HIGH $\to$ AO3400A Gate (via 1kΩ) *(GPIO 10 avoids UART0 conflict on C3)* |
| **Switch CH1 Sense** | `GPIO 4` | `GPIO 4` | Input | Pulled HIGH $\to$ Switched to GND (RC + TVS filtered) |
| **Switch CH2 Sense** | `GPIO 5` | `GPIO 5` | Input | Pulled HIGH $\to$ Switched to GND (RC + TVS filtered) |
| **Switch CH3 Sense** | `GPIO 6` | `GPIO 6` | Input | Pulled HIGH $\to$ Switched to GND (RC + TVS filtered) |
| **BL0942 Energy RX** | `GPIO 7` | `GPIO 7` | Input | UART1 RX @ 4800 Baud (Direct connection to BL0942 TX) |
| **Status LED Drive** | `GPIO 8` | `GPIO 8` | Output | Active HIGH $\to$ 1kΩ resistor $\to$ Blue LED |
| **Reset / Boot Button**| `GPIO 9` | `GPIO 9` | Input | Active LOW $\to$ Tactile switch to GND (10s hold = Reset) |
| **Factory Flashing TX**| `GPIO 16` | **`GPIO 21`** | Output | UART0 TX Test Point Pad |
| **Factory Flashing RX**| `GPIO 17` | **`GPIO 20`** | Input | UART0 RX Test Point Pad |

---

## 4. Complete Bill of Materials (BOM) with Manufacturer Part Numbers

| Item | Reference Des | Description | Package / Footprint | Recommended MPN | Manufacturer | Qty |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1A | U1 (Option A) | Microcontroller Module 4MB Flash (Wi-Fi 6 / Thread / BLE) | SMD Module ($16 \times 25.5\text{ mm}$) | ESP32-C6-WROOM-1-N4 | Espressif Systems | 1 |
| 1B | U1 (Option B - Budget) | Microcontroller Module 4MB Flash (Wi-Fi 4 / BLE 5.0) | SMD Module ($18 \times 20\text{ mm}$) | ESP32-C3-WROOM-02-N4 | Espressif Systems | 1 |
| 2 | U2 | AC/DC Isolated Power Module 5V 3W | 4-Pin Through Hole ($34 \times 20\text{ mm}$) | HLK-PM01 | Hi-Link | 1 |
| 3 | U3 | Ultra-Low-Noise 3.3V 600mA LDO | SOT-23-5 | AP2112K-3.3TRG1 | Diodes Inc. | 1 |
| 4 | U4 | Single Phase Energy Meter IC (UART) | SOP-14 | BL0942-SOP14 | Shanghai Belling | 1 |
| 5 | K1, K2, K3 | 10A 250VAC Subminiature Power Relay | 5-Pin Subminiature ($19 \times 15.5\text{ mm}$) | HF32F-G/005-HS | Hongfa | 3 |
| 6 | Q1, Q2, Q3 | 30V 5.8A N-Channel MOSFET | SOT-23 | AO3400A | Alpha & Omega | 3 |
| 7 | D1, D2, D3 | 40V 1A Schottky Flyback Diode | SOD-123FL | SS14FL | ON Semi / Vishay | 3 |
| 8 | D4, D5, D6 | 3.3V Bi-directional ESD TVS Diode | SOD-523 | ESD5Z3.3T1G | onsemi | 3 |
| 9 | F1 | 2A 250V Slow-Blow Subminiature Fuse | Radial Micro TR5 / SMD | 37212000411 | Littelfuse | 1 |
| 10 | MOV1 | 350VAC / 560V 4.5kA Varistor | Disc 14mm Radial | 14D561K | Bourns / TDK | 1 |
| 11 | NTC1 | 10Ω 2A Inrush Current Limiter NTC | Disc 9mm Radial | B57236S0100M000 | TDK / EPCOS | 1 |
| 12 | CX1 | 0.1µF 275VAC/310VAC Class-X2 Cap | Box Radial ($13 \times 6\text{ mm}$) | B32922C3104M | TDK / EPCOS | 1 |
| 13 | R_SHUNT | 1mΩ 2W 1% Alloy Current Shunt | SMD 2512 | CSS2H-2512R-1L00F | Bourns | 1 |
| 14 | R_HV1..R_HV4 | 240kΩ 1% 200V High Voltage Resistors | SMD 1206 | RVC1206FT240K | Stackpole | 4 |
| 15 | RS1, RS2, RS3 | 100Ω 1W Flameproof Resistor (Snubber)| SMD 2512 or Metal Film 1W | CRM2512-FX-1000ELF| Bourns | 3 |
| 16 | CS1, CS2, CS3 | 100nF (0.1µF) 630V Metalized Poly Cap | Box Radial / 1812 SMD | C440C104K5R5TA | KEMET / TDK | 3 |
| 17 | C_BULK1 | 470µF 16V Low-ESR Electrolytic | Radial $\varnothing 6.3\times 11\text{ mm}$ | EEU-FR1C471 | Panasonic | 1 |
| 18 | C_BULK2 | 100µF 10V Low-ESR Tantalum / Alum | SMD Case B / Radial | 293D107X9010B2TE3 | Vishay | 1 |
| 19 | C_DEC | 0.1µF 50V X7R Ceramic Decoupling | SMD 0603 / 0402 | CL10B104KB8NNNC | Samsung / Yageo | 12 |
| 20 | R_GATE, R_SW | 1kΩ, 10kΩ 1% Resistors | SMD 0603 | RC0603FR-0710KL | Yageo | 10 |
| 21 | LED1 | 0603 SMD Blue Status Indicator | SMD 0603 | LTST-C190TBKT | Lite-On | 1 |
| 22 | SW_BOOT | 3x4mm SMD Tactile Push Button | SMD 2-Pin | KMR221G LFS | C&K / Wurth | 1 |
| 23 | TB_AC, TB_SW | 5.08mm & 3.5mm Screw Terminal Blocks | PCB Screw Terminals 16A | 1985234 (PTSA 1,5) | Phoenix Contact | 2 |

---

## 5. PCB Layout & Manufacturing Engineering Rules

### 5.1 Layer Stackup (Standard 2-Layer 1.6mm FR-4)
- **Top Layer:** Signal Traces + Low-Voltage DC Ground Pour (Polygon Fill) + High-Voltage Load Lines.
- **Bottom Layer:** Low-Voltage DC Ground Pour (Solid Return Path) + High-Voltage AC Phase Bus (Tinned).
- **Copper Thickness:** **2.0 oz (70 µm)** minimum for heavy load current carrying capacity.

### 5.2 Creepage, Clearance & Air-Gap Milling Slots
1. **Mains-to-Low Voltage Clearance:** Minimum **$4.5\text{ mm}$** air distance between 230V AC lines and 3.3V/5V digital traces.
2. **Isolation Slots (Air Gaps):** Route **$1.5\text{ mm}$ to $2.0\text{ mm}$ width non-plated milling slots** (cutouts in the PCB):
   - Under the optocouplers / power supply isolation barrier.
   - Between the relay high-voltage NO/COM contacts and the relay 5V coil driving pins.
3. **High Current Trace Sizing (16A Total Capacity):**
   - AC Live In and Relay Contact traces width $\ge 3.5\text{ mm}$ on 2oz copper.
   - Remove top/bottom solder mask over high-current AC tracks (expose bare copper) so that during wave soldering, solder adheres and doubles current carrying capacity.

### 5.3 ESP32-C6 Antenna Placement
- The PCB antenna of the ESP32-C6 must **hang over the outer edge of the PCB** or be placed over a complete **Keep-Out Zone** (no copper traces, no ground fill, and no components on any layer for at least $15\text{ mm} \times 8\text{ mm}$).
- Keep AC transformers and switching power modules at least $20\text{ mm}$ away from the RF antenna to prevent 2.4GHz interference.

### 5.4 Factory Programming & Test Jig (Pogo-Pin Pads)
Place a 6-pad 2.54mm inline test point footprint on the bottom of the PCB for automated factory testing with `tools/manufacturing/flash_device.py`:
1. `Pad 1`: **3V3**
2. `Pad 2`: **GND**
3. `Pad 3`: **UART0_TX** (GPIO 16)
4. `Pad 4`: **UART0_RX** (GPIO 17)
5. `Pad 5`: **CHIP_PU** (EN)
6. `Pad 6`: **GPIO 9** (BOOT)

---

## 6. Manufacturing Export Checklist

When sending to PCB manufacturers (e.g., JLCPCB, PCBWay, Eurocircuits):
1. **Gerber Format:** RS-274X (Imperial / Metric).
2. **Material:** FR-4 Standard TG150 or High TG170 (recommended for high heat in wall box).
3. **Copper Weight:** 2 oz (Outer layers).
4. **Solder Mask:** Matt Green or Black.
5. **Surface Finish:** HASL Lead-Free or ENIG (Electroless Nickel Immersion Gold for high durability test pads).
6. **Flammability Rating:** UL 94V-0 certified.
