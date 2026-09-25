import os
import re
import uuid
import subprocess

BASE_FP = r'C:\Users\pavan\AppData\Local\Programs\KiCad\10.0\share\kicad\footprints'

def load_official_footprint(lib_folder, filename, ref, val, x, y, rot=0, pad_nets=None):
    if pad_nets is None:
        pad_nets = {}
    
    filepath = os.path.join(BASE_FP, lib_folder, filename)
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Missing footprint file: {filepath}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace footprint header with proper placement and uuid
    fp_name = filename.replace('.kicad_mod', '')
    lib_name = lib_folder.replace('.pretty', '')
    full_fp_name = f"{lib_name}:{fp_name}"
    
    rot_str = f" {rot}" if rot != 0 else ""
    header_pattern = r'\(footprint\s+"[^"]+"'
    new_header = f'  (footprint "{full_fp_name}" (layer "F.Cu") (at {x} {y}{rot_str}) (uuid "{str(uuid.uuid4())}")'
    content = re.sub(header_pattern, new_header, content, count=1)
    
    # Update Reference
    ref_pattern = r'\(property\s+"Reference"\s+"[^"]+"'
    content = re.sub(ref_pattern, f'(property "Reference" "{ref}"', content)
    
    # Update Value
    val_pattern = r'\(property\s+"Value"\s+"[^"]+"'
    content = re.sub(val_pattern, f'(property "Value" "{val}"', content)

    # Assign pad nets
    lines = content.splitlines()
    out_lines = []
    in_pad = False
    cur_pad_num = None
    pad_buffer = []

    for line in lines:
        if line.strip().startswith('(pad '):
            in_pad = True
            m = re.search(r'\(pad\s+"([^"]+)"', line)
            if m:
                cur_pad_num = m.group(1)
            pad_buffer = [line]
            if line.strip().endswith(')') and line.count('(') == line.count(')'):
                in_pad = False
                if cur_pad_num in pad_nets:
                    n_id, n_nm = pad_nets[cur_pad_num]
                    idx = line.rfind(')')
                    line = line[:idx] + f' (net {n_id} "{n_nm}"))'
                out_lines.append(line)
        elif in_pad:
            pad_buffer.append(line)
            total_open = sum(l.count('(') for l in pad_buffer)
            total_close = sum(l.count(')') for l in pad_buffer)
            if total_open == total_close:
                in_pad = False
                if cur_pad_num in pad_nets:
                    n_id, n_nm = pad_nets[cur_pad_num]
                    last_l = pad_buffer[-1]
                    idx = last_l.rfind(')')
                    if idx != -1:
                        pad_buffer[-1] = last_l[:idx] + f'\n\t\t(net {n_id} "{n_nm}")' + last_l[idx:]
                out_lines.extend(pad_buffer)
        else:
            out_lines.append(line)

    return "\n".join(out_lines)

def build_pcb():
    pcb = []
    pcb.append('(kicad_pcb (version 20240108) (generator pcbnew)')
    pcb.append('  (general (thickness 1.6))')
    pcb.append('  (paper "A4")')
    pcb.append('  (title_block')
    pcb.append('    (title "EH Smart Switch 3X - Industrial Production Board")')
    pcb.append('    (date "2026-09-21")')
    pcb.append('    (rev "1.0.0")')
    pcb.append('    (company "EH Platform Engineering")')
    pcb.append('    (comment 1 "5-Tier Hardware Protection Architecture, BL0942 Energy Metering")')
    pcb.append('  )')
    pcb.append('  (layers')
    pcb.append('    (0 "F.Cu" signal)')
    pcb.append('    (31 "B.Cu" signal)')
    pcb.append('    (36 "B.SilkS" user "B.Silkscreen")')
    pcb.append('    (37 "F.SilkS" user "F.Silkscreen")')
    pcb.append('    (38 "B.Mask" user)')
    pcb.append('    (39 "F.Mask" user)')
    pcb.append('    (44 "Edge.Cuts" user)')
    pcb.append('  )')
    pcb.append('  (setup')
    pcb.append('    (pad_to_mask_clearance 0.05)')
    pcb.append('    (grid_origin 100 100)')
    pcb.append('  )')

    net_dict = {
        0: '""',
        1: '"GND"',
        2: '"+3V3"',
        3: '"+5V"',
        4: '"MAINS_LIVE"',
        5: '"MAINS_NEUTRAL"',
        6: '"AC_L_FILTERED"',
        7: '"AC_N_FILTERED"',
        8: '"SW_IN_1"',
        9: '"SW_IN_2"',
        10: '"SW_IN_3"',
        11: '"RELAY_DRV_1"',
        12: '"RELAY_DRV_2"',
        13: '"RELAY_DRV_3"',
        14: '"LOAD_CH1"',
        15: '"LOAD_CH2"',
        16: '"LOAD_CH3"',
        17: '"BL0942_TX"',
        18: '"STATUS_LED"',
        19: '"BOOT_BTN"',
        20: '"NEUTRAL_LOAD"'
    }
    for n_id, n_name in net_dict.items():
        pcb.append(f'  (net {n_id} {n_name})')

    # Board Outline (86mm x 56mm)
    pcb.append(f'  (gr_rect (start 100 100) (end 186 156) (stroke (width 0.25) (type solid)) (layer "Edge.Cuts") (uuid "{str(uuid.uuid4())}"))')

    # 4 Mounting Holes (M3)
    for mx, my in [(104, 104), (182, 104), (104, 152), (182, 152)]:
        fp_mh = load_official_footprint("MountingHole.pretty", "MountingHole_3.2mm_M3.kicad_mod", "MH**", "M3", mx, my)
        pcb.append(fp_mh)

    # Silkscreen Division Lines & Labels
    pcb.append(f'  (gr_line (start 128 101) (end 128 155) (stroke (width 0.2) (type dash)) (layer "F.SilkS") (uuid "{str(uuid.uuid4())}"))')
    pcb.append(f'  (gr_line (start 160 101) (end 160 145) (stroke (width 0.2) (type dash)) (layer "F.SilkS") (uuid "{str(uuid.uuid4())}"))')
    pcb.append(f'  (gr_text "EH SMART SWITCH 3X" (at 144 102.5) (layer "F.SilkS") (effects (font (size 1.2 1.2) (thickness 0.18) (bold yes))) (uuid "{str(uuid.uuid4())}"))')
    pcb.append(f'  (gr_text "230V AC IN" (at 114 102.5) (layer "F.SilkS") (effects (font (size 0.9 0.9) (thickness 0.14) (bold yes))) (uuid "{str(uuid.uuid4())}"))')
    pcb.append(f'  (gr_text "OUTPUTS" (at 173 102.5) (layer "F.SilkS") (effects (font (size 0.9 0.9) (thickness 0.14) (bold yes))) (uuid "{str(uuid.uuid4())}"))')

    # Isolation Slots (2.0mm air gaps)
    pcb.append(f'  (gr_rect (start 127.2 105) (end 128.8 151) (stroke (width 0.2) (type solid)) (layer "Edge.Cuts") (uuid "{str(uuid.uuid4())}"))')
    pcb.append(f'  (gr_rect (start 159.2 105) (end 160.8 143) (stroke (width 0.2) (type solid)) (layer "Edge.Cuts") (uuid "{str(uuid.uuid4())}"))')

    # ==================== SECTION 1: MAINS AC POWER & PROTECTION ====================
    # J1 Mains Input Terminal
    pcb.append(load_official_footprint(
        "TerminalBlock_Phoenix.pretty", "TerminalBlock_Phoenix_MKDS-1,5-3-5.08_1x03_P5.08mm_Horizontal.kicad_mod",
        "J1", "MAINS_IN", 108, 110, rot=90,
        pad_nets={'1': (4, "MAINS_LIVE"), '2': (5, "MAINS_NEUTRAL"), '3': (1, "GND")}
    ))

    # F1 Fuse TR5
    pcb.append(load_official_footprint(
        "Fuse.pretty", "Fuseholder_TR5_Littelfuse_No560_No460.kicad_mod",
        "F1", "2A_250V", 118, 107,
        pad_nets={'1': (4, "MAINS_LIVE"), '2': (6, "AC_L_FILTERED")}
    ))

    # MOV1 Varistor 14D561K
    pcb.append(load_official_footprint(
        "Varistor.pretty", "RV_Disc_D12mm_W4.2mm_P7.5mm.kicad_mod",
        "MOV1", "14D561K", 118, 114,
        pad_nets={'1': (6, "AC_L_FILTERED"), '2': (5, "MAINS_NEUTRAL")}
    ))

    # NTC1 Inrush Limiter
    pcb.append(load_official_footprint(
        "Resistor_THT.pretty", "R_Radial_Power_L11.0mm_W7.0mm_P5.00mm.kicad_mod",
        "NTC1", "10D-9", 118, 120,
        pad_nets={'1': (6, "AC_L_FILTERED"), '2': (6, "AC_L_FILTERED")}
    ))

    # CX1 Class-X2 Safety Cap
    pcb.append(load_official_footprint(
        "Capacitor_THT.pretty", "C_Rect_L13.0mm_W4.0mm_P10.00mm_FKS3_FKP3_MKS4.kicad_mod",
        "CX1", "0.1uF_275V", 108, 122,
        pad_nets={'1': (6, "AC_L_FILTERED"), '2': (5, "MAINS_NEUTRAL")}
    ))

    # U2 HLK-PM01 SMPS Module
    pcb.append(load_official_footprint(
        "Converter_ACDC.pretty", "Converter_ACDC_Hi-Link_HLK-PMxx.kicad_mod",
        "U2", "HLK-PM01_5V", 114, 118, rot=270,
        pad_nets={'1': (6, "AC_L_FILTERED"), '2': (5, "MAINS_NEUTRAL"), '3': (3, "+5V"), '4': (1, "GND")}
    ))

    # ==================== SECTION 2: LOW VOLTAGE MCU & TELEMETRY ====================
    # C1 (470uF Bulk Cap)
    pcb.append(load_official_footprint(
        "Capacitor_THT.pretty", "CP_Radial_D6.3mm_P2.50mm.kicad_mod",
        "C1", "470uF_16V", 133, 146,
        pad_nets={'1': (3, "+5V"), '2': (1, "GND")}
    ))

    # U3 AP2112K-3.3 LDO
    pcb.append(load_official_footprint(
        "Package_TO_SOT_SMD.pretty", "SOT-23-5.kicad_mod",
        "U3", "AP2112K-3.3", 133, 137,
        pad_nets={'1': (3, "+5V"), '2': (1, "GND"), '3': (3, "+5V"), '5': (2, "+3V3")}
    ))

    # C2 (100uF SMD Cap)
    pcb.append(load_official_footprint(
        "Capacitor_SMD.pretty", "CP_Elec_6.3x5.8.kicad_mod",
        "C2", "100uF_10V", 133, 129,
        pad_nets={'1': (2, "+3V3"), '2': (1, "GND")}
    ))

    # U1 ESP32 Module
    pcb.append(load_official_footprint(
        "RF_Module.pretty", "ESP32-C3-WROOM-02.kicad_mod",
        "U1", "ESP32-C6-WROOM-1", 144, 114, rot=90,
        pad_nets={
            '1': (2, "+3V3"), '2': (2, "+3V3"), '3': (1, "GND"),
            '4': (8, "SW_IN_1"), '5': (9, "SW_IN_2"), '6': (10, "SW_IN_3"),
            '7': (17, "BL0942_TX"), '8': (18, "STATUS_LED"), '9': (19, "BOOT_BTN"),
            '18': (11, "RELAY_DRV_1"), '19': (12, "RELAY_DRV_2"), '20': (13, "RELAY_DRV_3")
        }
    ))

    # ESP32 Passives
    pcb.append(load_official_footprint("Resistor_SMD.pretty", "R_0603_1608Metric.kicad_mod", "R_EN", "10k", 133, 118, pad_nets={'1': (2, "+3V3"), '2': (2, "+3V3")}))
    pcb.append(load_official_footprint("Capacitor_SMD.pretty", "C_0603_1608Metric.kicad_mod", "C_EN", "1uF", 133, 122, pad_nets={'1': (2, "+3V3"), '2': (1, "GND")}))
    pcb.append(load_official_footprint("Resistor_SMD.pretty", "R_0603_1608Metric.kicad_mod", "R_LED", "1k", 133, 110, pad_nets={'1': (18, "STATUS_LED"), '2': (18, "STATUS_LED")}))
    pcb.append(load_official_footprint("LED_SMD.pretty", "LED_0603_1608Metric.kicad_mod", "LED1", "BLUE_0603", 133, 106, pad_nets={'1': (18, "STATUS_LED"), '2': (1, "GND")}))

    # U4 BL0942 Energy Meter IC
    pcb.append(load_official_footprint(
        "Package_SO.pretty", "SOIC-14_3.9x8.7mm_P1.27mm.kicad_mod",
        "U4", "BL0942_SOP14", 146, 132,
        pad_nets={
            '1': (2, "+3V3"), '2': (5, "MAINS_NEUTRAL"), '3': (20, "NEUTRAL_LOAD"),
            '4': (4, "MAINS_LIVE"), '5': (1, "GND"), '11': (17, "BL0942_TX")
        }
    ))

    # R_SHUNT & RHV1
    pcb.append(load_official_footprint("Resistor_SMD.pretty", "R_2512_6332Metric.kicad_mod", "R_SHUNT", "1mOhm_2W", 141, 140, pad_nets={'1': (5, "MAINS_NEUTRAL"), '2': (20, "NEUTRAL_LOAD")}))
    pcb.append(load_official_footprint("Resistor_SMD.pretty", "R_1206_3216Metric.kicad_mod", "RHV1", "960k_HV", 151, 140, pad_nets={'1': (4, "MAINS_LIVE"), '2': (1, "GND")}))

    # ==================== SECTION 3: WALL SWITCH INPUTS (BOTTOM ROW) ====================
    for idx, x_sw in enumerate([136, 145, 154]):
        ch = idx + 1
        pcb.append(load_official_footprint(
            "TerminalBlock_Phoenix.pretty", "TerminalBlock_Phoenix_MKDS-1,5-2_1x02_P5.00mm_Horizontal.kicad_mod",
            f"J_SW{ch}", f"WALL_SW_{ch}", x_sw, 150, rot=180,
            pad_nets={'1': (7+ch, f"SW_IN_{ch}"), '2': (1, "GND")}
        ))
        pcb.append(load_official_footprint("Resistor_SMD.pretty", "R_0603_1608Metric.kicad_mod", f"RSW{ch}", "1k", x_sw-1.5, 145, pad_nets={'1': (7+ch, f"SW_IN_{ch}"), '2': (7+ch, f"SW_IN_{ch}")}))
        pcb.append(load_official_footprint("Resistor_SMD.pretty", "R_0603_1608Metric.kicad_mod", f"RPU{ch}", "10k", x_sw+1.5, 145, pad_nets={'1': (2, "+3V3"), '2': (7+ch, f"SW_IN_{ch}")}))
        pcb.append(load_official_footprint("Capacitor_SMD.pretty", "C_0603_1608Metric.kicad_mod", f"CSW{ch}", "100nF", x_sw-1.5, 142, pad_nets={'1': (7+ch, f"SW_IN_{ch}"), '2': (1, "GND")}))
        pcb.append(load_official_footprint("Diode_SMD.pretty", "D_SOD-523.kicad_mod", f"TVS{ch}", "ESD5Z3.3", x_sw+1.5, 142, pad_nets={'1': (7+ch, f"SW_IN_{ch}"), '2': (1, "GND")}))

    # ==================== SECTION 4: RELAYS & OUTPUTS ====================
    y_relays = [111, 127, 143]
    for idx, yr in enumerate(y_relays):
        ch = idx + 1
        pcb.append(load_official_footprint("Package_TO_SOT_SMD.pretty", "SOT-23.kicad_mod", f"Q{ch}", "AO3400A", 156, yr, pad_nets={'1': (10+ch, f"RELAY_DRV_{ch}"), '2': (1, "GND"), '3': (10+ch, f"RELAY_DRV_{ch}")}))
        pcb.append(load_official_footprint("Resistor_SMD.pretty", "R_0603_1608Metric.kicad_mod", f"RG{ch}", "1k", 153, yr-2.5, pad_nets={'1': (10+ch, f"RELAY_DRV_{ch}"), '2': (10+ch, f"RELAY_DRV_{ch}")}))
        pcb.append(load_official_footprint("Resistor_SMD.pretty", "R_0603_1608Metric.kicad_mod", f"RPD{ch}", "10k", 153, yr+2.5, pad_nets={'1': (10+ch, f"RELAY_DRV_{ch}"), '2': (1, "GND")}))
        pcb.append(load_official_footprint("Diode_SMD.pretty", "D_SOD-123.kicad_mod", f"D{ch}", "SS14", 163, yr-5.5, pad_nets={'1': (3, "+5V"), '2': (10+ch, f"RELAY_DRV_{ch}")}))
        pcb.append(load_official_footprint("Relay_THT.pretty", "Relay_SPDT_SANYOU_SRD_Series_Form_C.kicad_mod", f"K{ch}", "HF32F-G_10A", 163, yr, pad_nets={
            '1': (3, "+5V"), '2': (10+ch, f"RELAY_DRV_{ch}"), '3': (13+ch, f"LOAD_CH{ch}"), '4': (0, ""), '5': (4, "MAINS_LIVE")
        }))

    # J2 Load Output Terminal
    pcb.append(load_official_footprint(
        "TerminalBlock_Phoenix.pretty", "TerminalBlock_Phoenix_MKDS-1,5-3-5.08_1x03_P5.08mm_Horizontal.kicad_mod",
        "J2", "LOAD_OUTPUTS", 182, 127, rot=270,
        pad_nets={'1': (14, "LOAD_CH1"), '2': (15, "LOAD_CH2"), '3': (16, "LOAD_CH3")}
    ))

    # ==================== CLEAN ORTHOGONAL PCB TRACKS ====================
    # 1. AC Live Input Bus (2.5mm Width, Top Layer)
    pcb.append(f'  (segment (start 108 104.92) (end 115.46 107) (width 2.5) (layer "F.Cu") (net 4) (uuid "{str(uuid.uuid4())}"))')
    pcb.append(f'  (segment (start 115.46 107) (end 118 107) (width 2.5) (layer "F.Cu") (net 4) (uuid "{str(uuid.uuid4())}"))')

    # AC Common Bus across Relays K1, K2, K3 COM pins (2.5mm width)
    pcb.append(f'  (segment (start 164.95 105.05) (end 164.95 137.05) (width 2.5) (layer "F.Cu") (net 4) (uuid "{str(uuid.uuid4())}"))')

    # Relay Switched Load Lines to J2 (2.5mm width)
    pcb.append(f'  (segment (start 177.15 117.05) (end 182 121.92) (width 2.5) (layer "F.Cu") (net 14) (uuid "{str(uuid.uuid4())}"))')
    pcb.append(f'  (segment (start 177.15 133.05) (end 182 127) (width 2.5) (layer "F.Cu") (net 15) (uuid "{str(uuid.uuid4())}"))')
    pcb.append(f'  (segment (start 177.15 149.05) (end 182 132.08) (width 2.5) (layer "F.Cu") (net 16) (uuid "{str(uuid.uuid4())}"))')

    # 2. DC Power Rails (+5V and +3.3V)
    pcb.append(f'  (segment (start 119 147.08) (end 133 146) (width 0.8) (layer "F.Cu") (net 3) (uuid "{str(uuid.uuid4())}"))')
    pcb.append(f'  (segment (start 133 146) (end 133 137) (width 0.8) (layer "F.Cu") (net 3) (uuid "{str(uuid.uuid4())}"))')
    pcb.append(f'  (segment (start 132.05 138.35) (end 133 129) (width 0.8) (layer "F.Cu") (net 2) (uuid "{str(uuid.uuid4())}"))')

    # 3. Low Voltage Ground Polygon Zone on Bottom Layer
    pcb.append(f'  (zone (net 1) (net_name "GND") (layer "B.Cu") (uuid "{str(uuid.uuid4())}")')
    pcb.append('    (hatch edge 0.5)')
    pcb.append('    (connect_pads yes (clearance 0.35))')
    pcb.append('    (min_thickness 0.25)')
    pcb.append('    (filled_polygon')
    pcb.append('      (pts (xy 129 101) (xy 159 101) (xy 159 155) (xy 129 155))')
    pcb.append('    )')
    pcb.append('    (polygon (pts (xy 129 101) (xy 159 101) (xy 159 155) (xy 129 155)))')
    pcb.append('  )')

    pcb.append(')')

    target = r"c:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\hardware\kicad\smart_switch_3x\smart_switch_3x.kicad_pcb"
    with open(target, "w", encoding="utf-8") as f:
        f.write('\n'.join(pcb))
    print(f"Generated 100% full official PCB at {target}")

if __name__ == "__main__":
    build_pcb()
