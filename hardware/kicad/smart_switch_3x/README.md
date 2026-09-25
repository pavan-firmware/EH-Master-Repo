# EH Home — KiCad 7 / 8 Production Hardware Project

This directory contains the **KiCad Schematic and PCB Design Project** for the **EH Smart Switch (3X / 4X Channel with BL0942 Metering)**.

---

## 1. Project Files

- **`smart_switch_3x.kicad_pro`**: KiCad Project File.
- **`smart_switch_3x.kicad_sch`**: KiCad Schematic Source.
- **`netlist_smart_switch_3x.net`**: Universal Netlist (can be imported into KiCad, EasyEDA, Altium, or OrCAD).

---

## 2. Universal Schematic Netlist & Pin Connections

Below is the complete machine-readable netlist and pin-to-pin wiring map:

### **Subsystem 1: Mains AC Input & Surge Protection**
| Component | Designator | Pin 1 | Pin 2 | Pin 3 / 4 / 5 | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Screw Terminal (AC IN) | J1 | `MAINS_LIVE` | `MAINS_NEUTRAL` | `EARTH_GND` | 5.08mm pitch, 16A rated |
| Fuse 2A 250V | F1 | `MAINS_LIVE` | `FUSE_OUT` | — | Micro TR5 / Radial |
| Varistor (MOV) 14D561K | MOV1 | `FUSE_OUT` | `MAINS_NEUTRAL` | — | Clamps surges $\ge 350\text{VAC}$ / 560V |
| NTC Thermistor 10D-9 | NTC1 | `FUSE_OUT` | `AC_L_FILTERED` | — | Limits inrush current |
| Safety Cap 0.1µF 275VAC | CX1 | `AC_L_FILTERED` | `MAINS_NEUTRAL` | — | Class-X2 EMI Suppression |
| Isolated SMPS (HLK-PM01) | U2 | Pin 1: `AC_L_FILTERED` | Pin 2: `MAINS_NEUTRAL` | Pin 3: `+5V`, Pin 4: `GND` | 3kV Isolation AC $\to$ 5V DC |

---

### **Subsystem 2: Low-Voltage Power Regulation (5V $\to$ 3.3V)**
| Component | Designator | Pin 1 | Pin 2 | Pin 3 | Pin 4 | Pin 5 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| LDO Regulator (AP2112K-3.3) | U3 | `+5V` (VIN) | `GND` | `+5V` (EN) | `NC` | `+3V3` (VOUT) |
| Bulk Filter Capacitor | C1 | `+5V` | `GND` | — | — | 470µF 16V Low-ESR |
| LDO Output Capacitor | C2 | `+3V3` | `GND` | — | — | 100µF 10V Tantalum/Alum |
| Decoupling Capacitors | C3, C4 | `+3V3` | `GND` | — | — | 0.1µF 50V X7R (0603) |

---

### **Subsystem 3: Microcontroller (ESP32-C6-WROOM-1-N4)**
| Pin Name | ESP32-C6 Pin | Connected Net | Description / Function |
| :--- | :--- | :--- | :--- |
| `3V3` | Pin 1, 2 | `+3V3` | Main 3.3V Power Rail |
| `GND` | Pin 3, 14, 29 | `GND` | System Digital Ground |
| `EN` / `CHIP_PU` | Pin 4 | `MCU_EN` | 10kΩ pull-up to 3.3V + 1µF cap to GND |
| `GPIO 4` | Pin 5 | `SW_IN_1` | Channel 1 Wall Switch Input (RC Filtered) |
| `GPIO 5` | Pin 6 | `SW_IN_2` | Channel 2 Wall Switch Input (RC Filtered) |
| `GPIO 6` | Pin 7 | `SW_IN_3` | Channel 3 Wall Switch Input (RC Filtered) |
| `GPIO 7` | Pin 8 | `BL0942_TX_OUT` | BL0942 UART1 Data In (4800 baud) |
| `GPIO 8` | Pin 9 | `STATUS_LED_DRIVE` | 1kΩ Resistor $\to$ Blue Status LED $\to$ GND |
| `GPIO 9` | Pin 10 | `BOOT_SW` | Tactile Button to GND (10s Hold = Reset) |
| `GPIO 16` | Pin 17 | `FACTORY_TX` | Factory Programming UART0 TX (Pogo Pad 3) |
| `GPIO 17` | Pin 18 | `FACTORY_RX` | Factory Programming UART0 RX (Pogo Pad 4) |
| `GPIO 18` | Pin 19 | `RELAY_DRV_1` | 1kΩ Resistor $\to$ Q1 MOSFET Gate |
| `GPIO 19` | Pin 20 | `RELAY_DRV_2` | 1kΩ Resistor $\to$ Q2 MOSFET Gate |
| `GPIO 20` | Pin 21 | `RELAY_DRV_3` | 1kΩ Resistor $\to$ Q3 MOSFET Gate |

---

### **Subsystem 4: Relay Actuation & Snubber (Channels 1, 2, 3)**
| Component | Channel 1 | Channel 2 | Channel 3 | Connections |
| :--- | :--- | :--- | :--- | :--- |
| **N-MOSFET Driver** | Q1 (AO3400A) | Q2 (AO3400A) | Q3 (AO3400A) | Gate: 1kΩ from GPIO, 10kΩ to GND; Source: GND; Drain: Relay Coil Pin 2 |
| **Flyback Diode** | D1 (SS14) | D2 (SS14) | D3 (SS14) | Cathode: `+5V`; Anode: MOSFET Drain |
| **10A Power Relay** | K1 (HF32F-G) | K2 (HF32F-G) | K3 (HF32F-G) | Coil 1: `+5V`; Coil 2: MOSFET Drain; COM: `MAINS_LIVE`; NO: `LOAD_OUT_CHx` |
| **Snubber Resistor** | RS1 (100Ω 1W) | RS2 (100Ω 1W) | RS3 (100Ω 1W) | In series with Snubber Cap across COM & NO |
| **Snubber Capacitor**| CS1 (100nF 630V)| CS2 (100nF 630V)| CS3 (100nF 630V)| In series with Snubber Resistor across COM & NO |

---

### **Subsystem 5: Wall Switch Noise & ESD Filter (Channels 1, 2, 3)**
| Component | Channel 1 | Channel 2 | Channel 3 | Connections |
| :--- | :--- | :--- | :--- | :--- |
| **Pull-Up Resistor** | R_PU1 (10kΩ) | R_PU2 (10kΩ) | R_PU3 (10kΩ) | Connected between `+3V3` and Switch Terminal Pin |
| **Series Resistor** | R_S1 (1kΩ) | R_S2 (1kΩ) | R_S3 (1kΩ) | In series between Switch Terminal and ESP32 GPIO |
| **TVS Clamp Diode** | D_TVS1 (ESD5Z3.3)| D_TVS2 (ESD5Z3.3)| D_TVS3 (ESD5Z3.3)| Connected between GPIO Line and `GND` |
| **Filter Capacitor** | C_SW1 (100nF) | C_SW2 (100nF) | C_SW3 (100nF) | Connected between GPIO Line and `GND` |

---

### **Subsystem 6: BL0942 Energy Metering (SOP-14)**
| BL0942 Pin | Pin Name | Connected To | Circuit Components |
| :--- | :--- | :--- | :--- |
| Pin 1 | `VDD` | `+3V3` | 0.1µF + 10µF bypass capacitors to GND |
| Pin 2 | `IP` | Positive Current Sense | 33Ω series resistor $\to$ Shunt Resistor (High Side) + 10nF to GND |
| Pin 3 | `IN` | Negative Current Sense | 33Ω series resistor $\to$ Shunt Resistor (Low Side) + 10nF to GND |
| Pin 4 | `VP` | Voltage Sense | 33Ω series resistor $\to$ (4x 240kΩ Divider tap) + 10nF to GND |
| Pin 5 | `GND` | `GND` | Direct to digital ground polygon |
| Pin 11 | `TX` | `GPIO 7` (ESP32-C6) | Direct UART connection at 4800 baud |

---

## 3. How to Open & Export in KiCad 7 / 8

1. Launch **KiCad 7** or **KiCad 8**.
2. Click **File $\longrightarrow$ Open Project** and select `smart_switch_3x.kicad_pro`.
3. Open the Schematic Editor to view and edit symbols, run **Electrical Rules Check (ERC)**.
4. Press `[F8]` (**Update PCB from Schematic**) to auto-place footprints and begin routing with 2oz copper and isolation slots.
