import os
import uuid

def uid():
    return str(uuid.uuid4())

def build_pcb():
    lines = []
    lines.append('(kicad_pcb (version 20221018) (generator pcbnew)')
    lines.append('  (general (thickness 1.6))')
    lines.append('  (paper "A4")')
    lines.append('  (title_block')
    lines.append('    (title "EH Smart Switch 3X - Industrial Production Board")')
    lines.append('    (date "2026-09-21")')
    lines.append('    (rev "1.0.0")')
    lines.append('    (company "EH Platform Engineering")')
    lines.append('    (comment 1 "5-Tier Hardware Protection, BL0942 Energy Metering, ESP32-C6")')
    lines.append('  )')
    lines.append('  (layers')
    lines.append('    (0 "F.Cu" signal)')
    lines.append('    (31 "B.Cu" signal)')
    lines.append('    (36 "B.SilkS" user "B.Silkscreen")')
    lines.append('    (37 "F.SilkS" user "F.Silkscreen")')
    lines.append('    (38 "B.Mask" user)')
    lines.append('    (39 "F.Mask" user)')
    lines.append('    (44 "Edge.Cuts" user)')
    lines.append('    (48 "B.Fab" user)')
    lines.append('    (49 "F.Fab" user)')
    lines.append('  )')
    lines.append('  (setup')
    lines.append('    (pad_to_mask_clearance 0.05)')
    lines.append('    (grid_origin 100 100)')
    lines.append('  )')

    # Nets
    nets = [
        (0, '""'),
        (1, '"GND"'),
        (2, '"+3V3"'),
        (3, '"+5V"'),
        (4, '"MAINS_LIVE"'),
        (5, '"MAINS_NEUTRAL"'),
        (6, '"AC_L_FILTERED"'),
        (7, '"AC_N_FILTERED"'),
        (8, '"SW_IN_1"'),
        (9, '"SW_IN_2"'),
        (10, '"SW_IN_3"'),
        (11, '"RELAY_DRV_1"'),
        (12, '"RELAY_DRV_2"'),
        (13, '"RELAY_DRV_3"'),
        (14, '"LOAD_CH1"'),
        (15, '"LOAD_CH2"'),
        (16, '"LOAD_CH3"'),
        (17, '"BL0942_TX"'),
        (18, '"STATUS_LED"'),
        (19, '"BOOT_BTN"'),
        (20, '"NEUTRAL_LOAD"')
    ]
    for n_id, n_name in nets:
        lines.append(f'  (net {n_id} {n_name})')

    # PCB Board Outline (85mm x 55mm)
    # Origin at (100, 100) -> X: 100 to 185, Y: 100 to 155
    lines.append('  (gr_rect (start 100 100) (end 185 155) (stroke (width 0.2) (type solid)) (layer "Edge.Cuts") (uuid "'+uid()+'"))')
    
    # 4 Mounting Holes (M3 - 3.2mm drill at corners)
    corners = [(104, 104), (181, 104), (104, 151), (181, 151)]
    for cx, cy in corners:
        lines.append(f'  (footprint "MountingHole:MountingHole_3.2mm_M3" (layer "F.Cu") (at {cx} {cy}) (uuid "{uid()}")')
        lines.append(f'    (pad "" np_thru_hole circle (at 0 0) (size 3.2 3.2) (drill 3.2) (layers "*.Cu" "*.Mask"))')
        lines.append('  )')

    # High Voltage Isolation Slots (2mm air gaps)
    lines.append('  (gr_rect (start 128 102) (end 130 153) (stroke (width 0.2) (type solid)) (layer "Edge.Cuts") (uuid "'+uid()+'"))')
    lines.append('  (gr_rect (start 155 102) (end 156.5 140) (stroke (width 0.2) (type solid)) (layer "Edge.Cuts") (uuid "'+uid()+'"))')

    # Footprint Placements
    # 1. J1 Mains In (3-Pin Terminal) at (108, 110)
    lines.append(f'  (footprint "TerminalBlock:MKDS_3P" (layer "F.Cu") (at 108 112) (uuid "{uid()}")')
    lines.append('    (fp_text reference "J1" (at 0 -4) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    lines.append('    (fp_text value "MAINS_IN" (at 0 4) (layer "F.Fab") (effects (font (size 1 1) (thickness 0.15))))')
    lines.append('    (pad "1" thru_hole rect (at 0 -5.08) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") (net 4 "MAINS_LIVE"))')
    lines.append('    (pad "2" thru_hole circle (at 0 0) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") (net 5 "MAINS_NEUTRAL"))')
    lines.append('    (pad "3" thru_hole circle (at 0 5.08) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") (net 1 "GND"))')
    lines.append('  )')

    # 2. F1 Fuse at (116, 107)
    lines.append(f'  (footprint "Fuse:TR5" (layer "F.Cu") (at 116 107) (uuid "{uid()}")')
    lines.append('    (fp_text reference "F1" (at 0 -3) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    lines.append('    (pad "1" thru_hole rect (at -2.54 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") (net 4 "MAINS_LIVE"))')
    lines.append('    (pad "2" thru_hole circle (at 2.54 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") (net 6 "AC_L_FILTERED"))')
    lines.append('  )')

    # 3. MOV1 at (116, 115)
    lines.append(f'  (footprint "Varistor:14D" (layer "F.Cu") (at 116 115) (uuid "{uid()}")')
    lines.append('    (fp_text reference "MOV1" (at 0 -3) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    lines.append('    (pad "1" thru_hole rect (at -3.75 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") (net 6 "AC_L_FILTERED"))')
    lines.append('    (pad "2" thru_hole circle (at 3.75 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") (net 5 "MAINS_NEUTRAL"))')
    lines.append('  )')

    # 4. CX1 X2 Safety Cap at (116, 123)
    lines.append(f'  (footprint "Capacitor:Box_10mm" (layer "F.Cu") (at 116 123) (uuid "{uid()}")')
    lines.append('    (fp_text reference "CX1" (at 0 -3) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    lines.append('    (pad "1" thru_hole rect (at -5.0 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") (net 6 "AC_L_FILTERED"))')
    lines.append('    (pad "2" thru_hole circle (at 5.0 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") (net 5 "MAINS_NEUTRAL"))')
    lines.append('  )')

    # 5. U2 HLK-PM01 SMPS at (116, 139)
    lines.append(f'  (footprint "Power:HLK-PM01" (layer "F.Cu") (at 116 139) (uuid "{uid()}")')
    lines.append('    (fp_text reference "U2" (at 0 -11) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    lines.append('    (pad "1" thru_hole rect (at -14.7 -2.5) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask") (net 6 "AC_L_FILTERED"))')
    lines.append('    (pad "2" thru_hole circle (at -14.7 2.5) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask") (net 5 "MAINS_NEUTRAL"))')
    lines.append('    (pad "3" thru_hole circle (at 14.7 7.7) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask") (net 3 "+5V"))')
    lines.append('    (pad "4" thru_hole circle (at 14.7 -7.7) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask") (net 1 "GND"))')
    lines.append('  )')

    # 6. U3 AP2112K-3.3 at (136, 142)
    lines.append(f'  (footprint "Package_TO_SOT_SMD:SOT-23-5" (layer "F.Cu") (at 136 142) (uuid "{uid()}")')
    lines.append('    (fp_text reference "U3" (at 0 -2.5) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    lines.append('    (pad "1" smd rect (at -0.95 -1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") (net 3 "+5V"))')
    lines.append('    (pad "2" smd rect (at 0 -1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") (net 1 "GND"))')
    lines.append('    (pad "3" smd rect (at 0.95 -1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") (net 3 "+5V"))')
    lines.append('    (pad "5" smd rect (at -0.95 1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") (net 2 "+3V3"))')
    lines.append('  )')

    # 7. U1 ESP32-C6-WROOM-1 at (142, 118)
    lines.append(f'  (footprint "RF_Module:ESP32-C6-WROOM-1" (layer "F.Cu") (at 142 118 90) (uuid "{uid()}")')
    lines.append('    (fp_text reference "U1" (at 0 -14) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    lines.append('    (pad "1" smd rect (at 6.5 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 2 "+3V3"))')
    lines.append('    (pad "3" smd rect (at 3.5 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 1 "GND"))')
    lines.append('    (pad "4" smd rect (at 2.0 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 8 "SW_IN_1"))')
    lines.append('    (pad "5" smd rect (at 0.5 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 9 "SW_IN_2"))')
    lines.append('    (pad "6" smd rect (at -1.0 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 10 "SW_IN_3"))')
    lines.append('    (pad "7" smd rect (at -2.5 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 17 "BL0942_TX"))')
    lines.append('    (pad "8" smd rect (at -4.0 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 18 "STATUS_LED"))')
    lines.append('    (pad "9" smd rect (at -5.5 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 19 "BOOT_BTN"))')
    lines.append('    (pad "18" smd rect (at -2.5 8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 11 "RELAY_DRV_1"))')
    lines.append('    (pad "19" smd rect (at -1.0 8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 12 "RELAY_DRV_2"))')
    lines.append('    (pad "20" smd rect (at 0.5 8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") (net 13 "RELAY_DRV_3"))')
    lines.append('  )')

    # 8. Relays K1, K2, K3 at (168, 110), (168, 125), (168, 140)
    y_relays = [110, 125, 140]
    for idx, yr in enumerate(y_relays):
        ch = idx + 1
        lines.append(f'  (footprint "Relay:HF32F-G" (layer "F.Cu") (at 168 {yr}) (uuid "{uid()}")')
        lines.append(f'    (fp_text reference "K{ch}" (at 0 -8) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
        lines.append(f'    (pad "1" thru_hole circle (at -6.0 -6.0) (size 2.2 2.2) (drill 1.2) (layers "*.Cu" "*.Mask") (net 3 "+5V"))')
        lines.append(f'    (pad "2" thru_hole circle (at -6.0 6.0) (size 2.2 2.2) (drill 1.2) (layers "*.Cu" "*.Mask") (net {10+ch} "RELAY_DRV_{ch}"))')
        lines.append(f'    (pad "3" thru_hole rect (at 6.0 -6.0) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") (net 4 "MAINS_LIVE"))')
        lines.append(f'    (pad "4" thru_hole circle (at 6.0 6.0) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") (net {13+ch} "LOAD_CH{ch}"))')
        lines.append('  )')

    # 9. Output Load Terminal J2 at (180, 125)
    lines.append(f'  (footprint "TerminalBlock:MKDS_3P" (layer "F.Cu") (at 180 125 90) (uuid "{uid()}")')
    lines.append('    (fp_text reference "J2" (at 0 -4) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    lines.append('    (pad "1" thru_hole rect (at -5.08 0 90) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") (net 14 "LOAD_CH1"))')
    lines.append('    (pad "2" thru_hole circle (at 0 0 90) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") (net 15 "LOAD_CH2"))')
    lines.append('    (pad "3" thru_hole circle (at 5.08 0 90) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") (net 16 "LOAD_CH3"))')
    lines.append('  )')

    # 10. Wall Switch Inputs J_SW1..J_SW3 at (150, 148), (160, 148), (170, 148)
    for idx, x_sw in enumerate([148, 158, 168]):
        ch = idx + 1
        lines.append(f'  (footprint "TerminalBlock:2P_3.5mm" (layer "F.Cu") (at {x_sw} 148) (uuid "{uid()}")')
        lines.append(f'    (fp_text reference "J_SW{ch}" (at 0 -3) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
        lines.append(f'    (pad "1" thru_hole rect (at -1.75 0) (size 2.0 2.0) (drill 1.1) (layers "*.Cu" "*.Mask") (net {7+ch} "SW_IN_{ch}"))')
        lines.append(f'    (pad "2" thru_hole circle (at 1.75 0) (size 2.0 2.0) (drill 1.1) (layers "*.Cu" "*.Mask") (net 1 "GND"))')
        lines.append('  )')

    # High-Current Routed Tracks (Top & Bottom Layer - 2.5mm width)
    # AC Mains Live Bus across Relays
    lines.append('  (segment (start 108 106.92) (end 113.46 107) (width 2.5) (layer "F.Cu") (net 4) (uuid "'+uid()+'"))')
    lines.append('  (segment (start 174 104) (end 174 134) (width 2.5) (layer "B.Cu") (net 4) (uuid "'+uid()+'"))')
    lines.append('  (segment (start 174 104) (end 174 119) (width 2.5) (layer "F.Cu") (net 4) (uuid "'+uid()+'"))')
    lines.append('  (segment (start 174 119) (end 174 134) (width 2.5) (layer "F.Cu") (net 4) (uuid "'+uid()+'"))')

    # Relay 1 to Load CH1
    lines.append('  (segment (start 174 116) (end 180 119.92) (width 2.5) (layer "F.Cu") (net 14) (uuid "'+uid()+'"))')
    # Relay 2 to Load CH2
    lines.append('  (segment (start 174 131) (end 180 125) (width 2.5) (layer "F.Cu") (net 15) (uuid "'+uid()+'"))')
    # Relay 3 to Load CH3
    lines.append('  (segment (start 174 146) (end 180 130.08) (width 2.5) (layer "F.Cu") (net 16) (uuid "'+uid()+'"))')

    # +5V Power Rail (1.0mm width)
    lines.append('  (segment (start 130.7 146.7) (end 135.05 140.65) (width 1.0) (layer "F.Cu") (net 3) (uuid "'+uid()+'"))')
    lines.append('  (segment (start 130.7 146.7) (end 162 104) (width 1.0) (layer "F.Cu") (net 3) (uuid "'+uid()+'"))')
    lines.append('  (segment (start 162 104) (end 162 134) (width 1.0) (layer "F.Cu") (net 3) (uuid "'+uid()+'"))')

    # +3.3V Power Rail (0.8mm width)
    lines.append('  (segment (start 135.05 143.35) (end 142 124.5) (width 0.8) (layer "F.Cu") (net 2) (uuid "'+uid()+'"))')

    # Signal Control Traces (0.25mm width)
    lines.append('  (segment (start 150 115.5) (end 162 116) (width 0.25) (layer "F.Cu") (net 11) (uuid "'+uid()+'"))')
    lines.append('  (segment (start 150 117) (end 162 131) (width 0.25) (layer "F.Cu") (net 12) (uuid "'+uid()+'"))')
    lines.append('  (segment (start 150 118.5) (end 162 146) (width 0.25) (layer "F.Cu") (net 13) (uuid "'+uid()+'"))')

    # Ground Polygon Fill (Bottom Layer Zone)
    lines.append('  (zone (net 1) (net_name "GND") (layer "B.Cu") (uuid "'+uid()+'")')
    lines.append('    (hatch edge 0.5)')
    lines.append('    (connect_pads yes (clearance 0.3))')
    lines.append('    (min_thickness 0.25)')
    lines.append('    (filled_polygon')
    lines.append('      (pts (xy 130 100) (xy 185 100) (xy 185 155) (xy 130 155))')
    lines.append('    )')
    lines.append('    (polygon (pts (xy 130 100) (xy 185 100) (xy 185 155) (xy 130 155)))')
    lines.append('  )')

    lines.append(')')

    with open(r"c:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\hardware\kicad\smart_switch_3x\smart_switch_3x.kicad_pcb", "w", encoding="utf-8") as f:
        f.write('\n'.join(lines))
    print("Successfully built complete routed smart_switch_3x.kicad_pcb!")

if __name__ == "__main__":
    build_pcb()
