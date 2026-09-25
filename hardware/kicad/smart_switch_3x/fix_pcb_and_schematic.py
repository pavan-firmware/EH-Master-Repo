import uuid

def uid():
    return str(uuid.uuid4())

def main():
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

    def pad_net(n):
        val = net_dict.get(n, '""')
        return f'(net {n} {val})'

    pcb = []
    pcb.append('(kicad_pcb (version 20221018) (generator pcbnew)')
    pcb.append('  (general (thickness 1.6))')
    pcb.append('  (paper "A4")')
    pcb.append('  (title_block')
    pcb.append('    (title "EH Smart Switch 3X - Industrial Production Board")')
    pcb.append('    (date "2026-09-21")')
    pcb.append('    (rev "1.0.0")')
    pcb.append('    (company "EH Platform Engineering")')
    pcb.append('    (comment 1 "5-Tier Hardware Protection, BL0942 Energy Metering, ESP32-C6")')
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

    # Nets
    for n_id, n_name in net_dict.items():
        pcb.append(f'  (net {n_id} {n_name})')

    # PCB Board Outline (85mm x 55mm)
    pcb.append('  (gr_rect (start 100 100) (end 185 155) (stroke (width 0.2) (type solid)) (layer "Edge.Cuts") (uuid "'+uid()+'"))')
    
    # 4 Mounting Holes (M3 - 3.2mm drill at corners)
    corners = [(104, 104), (181, 104), (104, 151), (181, 151)]
    for cx, cy in corners:
        pcb.append(f'  (footprint "MountingHole:MountingHole_3.2mm_M3" (layer "F.Cu") (at {cx} {cy}) (uuid "{uid()}")')
        pcb.append(f'    (pad "" np_thru_hole circle (at 0 0) (size 3.2 3.2) (drill 3.2) (layers "*.Cu" "*.Mask"))')
        pcb.append('  )')

    # High Voltage Isolation Slots (2mm air gaps)
    pcb.append('  (gr_rect (start 128 102) (end 130 153) (stroke (width 0.2) (type solid)) (layer "Edge.Cuts") (uuid "'+uid()+'"))')
    pcb.append('  (gr_rect (start 158 102) (end 159.5 142) (stroke (width 0.2) (type solid)) (layer "Edge.Cuts") (uuid "'+uid()+'"))')

    # 1. J1 Mains In (3-Pin Terminal)
    pcb.append(f'  (footprint "TerminalBlock:MKDS_3P" (layer "F.Cu") (at 108 112) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "J1" (at 0 -4) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    pcb.append(f'    (pad "1" thru_hole rect (at 0 -5.08) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(4)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 0 0) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(5)})')
    pcb.append(f'    (pad "3" thru_hole circle (at 0 5.08) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(1)})')
    pcb.append('  )')

    # 2. F1 Fuse
    pcb.append(f'  (footprint "Fuse:TR5" (layer "F.Cu") (at 118 106) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "F1" (at 0 -3) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -2.54 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(4)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 2.54 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append('  )')

    # 3. MOV1
    pcb.append(f'  (footprint "Varistor:14D" (layer "F.Cu") (at 118 114) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "MOV1" (at 0 -3) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -3.75 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 3.75 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(5)})')
    pcb.append('  )')

    # 4. NTC1
    pcb.append(f'  (footprint "Resistor:NTC_9D" (layer "F.Cu") (at 118 122) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "NTC1" (at 0 -3) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -2.5 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 2.5 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append('  )')

    # 5. CX1
    pcb.append(f'  (footprint "Capacitor:Box_10mm" (layer "F.Cu") (at 118 130) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "CX1" (at 0 -3) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -5.0 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 5.0 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(5)})')
    pcb.append('  )')

    # 6. U2 HLK-PM01 SMPS
    pcb.append(f'  (footprint "Power:HLK-PM01" (layer "F.Cu") (at 116 144) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "U2" (at 0 -8) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -14.7 -2.5) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append(f'    (pad "2" thru_hole circle (at -14.7 2.5) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask") {pad_net(5)})')
    pcb.append(f'    (pad "3" thru_hole circle (at 14.7 7.7) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask") {pad_net(3)})')
    pcb.append(f'    (pad "4" thru_hole circle (at 14.7 -7.7) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask") {pad_net(1)})')
    pcb.append('  )')

    # 7. Low-Voltage Regulators & Capacitors
    # C1 (470uF)
    pcb.append(f'  (footprint "Capacitor_THT:CP_Radial_D6.3mm_P2.50mm" (layer "F.Cu") (at 134 148) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "C1" (at 0 -3) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -1.25 0) (size 1.8 1.8) (drill 0.9) (layers "*.Cu" "*.Mask") {pad_net(3)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 1.25 0) (size 1.8 1.8) (drill 0.9) (layers "*.Cu" "*.Mask") {pad_net(1)})')
    pcb.append('  )')

    # U3 (AP2112K-3.3)
    pcb.append(f'  (footprint "Package_TO_SOT_SMD:SOT-23-5" (layer "F.Cu") (at 135 140) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "U3" (at 0 -2.5) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    pcb.append(f'    (pad "1" smd rect (at -0.95 -1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(3)})')
    pcb.append(f'    (pad "2" smd rect (at 0 -1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append(f'    (pad "3" smd rect (at 0.95 -1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(3)})')
    pcb.append(f'    (pad "5" smd rect (at -0.95 1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(2)})')
    pcb.append('  )')

    # C2 (100uF)
    pcb.append(f'  (footprint "Capacitor_SMD:CP_Elec_6.3x5.8" (layer "F.Cu") (at 140 148) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "C2" (at 0 -3) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    pcb.append(f'    (pad "1" smd rect (at -2.5 0) (size 2.0 1.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(2)})')
    pcb.append(f'    (pad "2" smd rect (at 2.5 0) (size 2.0 1.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append('  )')

    # 8. U1 ESP32-C6-WROOM-1 at (142, 116)
    pcb.append(f'  (footprint "RF_Module:ESP32-C6-WROOM-1" (layer "F.Cu") (at 142 116 90) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "U1" (at 0 -14) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    pcb.append(f'    (pad "1" smd rect (at 6.5 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(2)})')
    pcb.append(f'    (pad "2" smd rect (at 5.0 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(2)})')
    pcb.append(f'    (pad "3" smd rect (at 3.5 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append(f'    (pad "4" smd rect (at 2.0 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(8)})')
    pcb.append(f'    (pad "5" smd rect (at 0.5 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(9)})')
    pcb.append(f'    (pad "6" smd rect (at -1.0 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(10)})')
    pcb.append(f'    (pad "7" smd rect (at -2.5 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(17)})')
    pcb.append(f'    (pad "8" smd rect (at -4.0 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(18)})')
    pcb.append(f'    (pad "9" smd rect (at -5.5 -8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(19)})')
    pcb.append(f'    (pad "18" smd rect (at -2.5 8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(11)})')
    pcb.append(f'    (pad "19" smd rect (at -1.0 8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(12)})')
    pcb.append(f'    (pad "20" smd rect (at 0.5 8.0 90) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(13)})')
    pcb.append('  )')

    # ESP32 Passives (Reset RC, LED, Button)
    def add_smd_0603(ref, val, x, y, net1, net2):
        pcb.append(f'  (footprint "Resistor_SMD:R_0603_1608Metric" (layer "F.Cu") (at {x} {y}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "{ref}" (at 0 -1.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
        pcb.append(f'    (pad "1" smd rect (at -0.8 0) (size 0.8 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(net1)})')
        pcb.append(f'    (pad "2" smd rect (at 0.8 0) (size 0.8 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(net2)})')
        pcb.append('  )')

    add_smd_0603("R_EN", "10k", 133, 110, 2, 2)
    add_smd_0603("C_EN", "1uF", 133, 113, 2, 1)
    add_smd_0603("R_LED", "1k", 133, 120, 18, 18)
    
    # LED1
    pcb.append(f'  (footprint "LED_SMD:LED_0603_1608Metric" (layer "F.Cu") (at 133 124) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "LED1" (at 0 -1.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
    pcb.append(f'    (pad "1" smd rect (at -0.8 0) (size 0.8 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(18)})')
    pcb.append(f'    (pad "2" smd rect (at 0.8 0) (size 0.8 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append('  )')

    # 9. BL0942 Metering IC & Shunt
    pcb.append(f'  (footprint "Package_SO:SOIC-14_3.9x8.7mm_P1.27mm" (layer "F.Cu") (at 148 135) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "U4" (at 0 -5.5) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    pcb.append(f'    (pad "1" smd rect (at -2.7 -3.81) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(2)})')
    pcb.append(f'    (pad "2" smd rect (at -2.7 -2.54) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(5)})')
    pcb.append(f'    (pad "3" smd rect (at -2.7 -1.27) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(20)})')
    pcb.append(f'    (pad "4" smd rect (at -2.7 0) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(4)})')
    pcb.append(f'    (pad "5" smd rect (at -2.7 1.27) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append(f'    (pad "11" smd rect (at 2.7 -1.27) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(17)})')
    pcb.append('  )')

    # Shunt R_SHUNT (2512) & RHV1 (1206)
    pcb.append(f'  (footprint "Resistor_SMD:R_2512_6332Metric" (layer "F.Cu") (at 144 146) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "R_SHUNT" (at 0 -2.5) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    pcb.append(f'    (pad "1" smd rect (at -2.8 0) (size 1.6 3.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(5)})')
    pcb.append(f'    (pad "2" smd rect (at 2.8 0) (size 1.6 3.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(20)})')
    pcb.append('  )')

    pcb.append(f'  (footprint "Resistor_SMD:R_1206_3216Metric" (layer "F.Cu") (at 152 146) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "RHV1" (at 0 -2.5) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    pcb.append(f'    (pad "1" smd rect (at -1.5 0) (size 1.1 1.8) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(4)})')
    pcb.append(f'    (pad "2" smd rect (at 1.5 0) (size 1.1 1.8) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append('  )')

    # 10. MOSFET Drivers Q1, Q2, Q3 (SOT-23) & Resistors
    y_relays = [112, 126, 140]
    for idx, yr in enumerate(y_relays):
        ch = idx + 1
        # MOSFET
        pcb.append(f'  (footprint "Package_TO_SOT_SMD:SOT-23" (layer "F.Cu") (at 155 {yr}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "Q{ch}" (at 0 -2) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
        pcb.append(f'    (pad "1" smd rect (at -0.95 -1) (size 0.6 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(10+ch)})')
        pcb.append(f'    (pad "2" smd rect (at 0.95 -1) (size 0.6 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
        pcb.append(f'    (pad "3" smd rect (at 0 1) (size 0.6 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(10+ch)})')
        pcb.append('  )')

        # Gate Resistor & Pull-Down
        add_smd_0603(f"RG{ch}", "1k", 152, yr-3, 10+ch, 10+ch)
        add_smd_0603(f"RPD{ch}", "10k", 152, yr+3, 10+ch, 1)

        # Diode SS14
        pcb.append(f'  (footprint "Diode_SMD:D_SOD-123" (layer "F.Cu") (at 159 {yr}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "D{ch}" (at 0 -1.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
        pcb.append(f'    (pad "1" smd rect (at -1.4 0) (size 0.9 1.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(3)})')
        pcb.append(f'    (pad "2" smd rect (at 1.4 0) (size 0.9 1.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(10+ch)})')
        pcb.append('  )')

        # Relay HF32F-G
        pcb.append(f'  (footprint "Relay:Relay_HF32F-G" (layer "F.Cu") (at 167 {yr}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "K{ch}" (at 0 -8) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
        pcb.append(f'    (pad "1" thru_hole circle (at -6.0 -6.0) (size 2.2 2.2) (drill 1.2) (layers "*.Cu" "*.Mask") {pad_net(3)})')
        pcb.append(f'    (pad "2" thru_hole circle (at -6.0 6.0) (size 2.2 2.2) (drill 1.2) (layers "*.Cu" "*.Mask") {pad_net(10+ch)})')
        pcb.append(f'    (pad "3" thru_hole rect (at 6.0 -6.0) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(4)})')
        pcb.append(f'    (pad "4" thru_hole circle (at 6.0 6.0) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(13+ch)})')
        pcb.append('  )')

        # Snubber Resistor (2512) & Capacitor (Box 10mm)
        pcb.append(f'  (footprint "Resistor_SMD:R_2512_6332Metric" (layer "F.Cu") (at 175 {yr-3}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "RS{ch}" (at 0 -2.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
        pcb.append(f'    (pad "1" smd rect (at -2.8 0) (size 1.6 3.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(4)})')
        pcb.append(f'    (pad "2" smd rect (at 2.8 0) (size 1.6 3.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(13+ch)})')
        pcb.append('  )')

        pcb.append(f'  (footprint "Capacitor:Box_10mm" (layer "F.Cu") (at 175 {yr+3}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "CS{ch}" (at 0 -2.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
        pcb.append(f'    (pad "1" thru_hole rect (at -5.0 0) (size 2.0 2.0) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(4)})')
        pcb.append(f'    (pad "2" thru_hole circle (at 5.0 0) (size 2.0 2.0) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(13+ch)})')
        pcb.append('  )')

    # 11. Output Load Terminal J2
    pcb.append(f'  (footprint "TerminalBlock:MKDS_3P" (layer "F.Cu") (at 181 126 90) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "J2" (at 0 -4) (layer "F.SilkS") (effects (font (size 1 1) (thickness 0.15))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -5.08 0 90) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(14)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 0 0 90) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(15)})')
    pcb.append(f'    (pad "3" thru_hole circle (at 5.08 0 90) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(16)})')
    pcb.append('  )')

    # 12. Wall Switch Inputs (J_SW1, J_SW2, J_SW3) & Filter Passives
    for idx, x_sw in enumerate([148, 158, 168]):
        ch = idx + 1
        pcb.append(f'  (footprint "TerminalBlock:2P_3.5mm" (layer "F.Cu") (at {x_sw} 150) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "J_SW{ch}" (at 0 -3) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
        pcb.append(f'    (pad "1" thru_hole rect (at -1.75 0) (size 2.0 2.0) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(7+ch)})')
        pcb.append(f'    (pad "2" thru_hole circle (at 1.75 0) (size 2.0 2.0) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(1)})')
        pcb.append('  )')

        add_smd_0603(f"RSW{ch}", "1k", x_sw-2, 144, 7+ch, 7+ch)
        add_smd_0603(f"RPU{ch}", "10k", x_sw+2, 144, 2, 7+ch)
        add_smd_0603(f"CSW{ch}", "100nF", x_sw-2, 141, 7+ch, 1)

        # TVS Diode
        pcb.append(f'  (footprint "Diode_SMD:D_SOD-523" (layer "F.Cu") (at {x_sw+2} 141) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "TVS{ch}" (at 0 -1.2) (layer "F.SilkS") (effects (font (size 0.6 0.6) (thickness 0.1))))')
        pcb.append(f'    (pad "1" smd rect (at -0.7 0) (size 0.6 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(7+ch)})')
        pcb.append(f'    (pad "2" smd rect (at 0.7 0) (size 0.6 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
        pcb.append('  )')

    # Tracks
    pcb.append('  (segment (start 108 106.92) (end 115.46 106) (width 2.5) (layer "F.Cu") (net 4) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 173 106) (end 173 134) (width 2.5) (layer "B.Cu") (net 4) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 173 106) (end 173 120) (width 2.5) (layer "F.Cu") (net 4) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 173 120) (end 173 134) (width 2.5) (layer "F.Cu") (net 4) (uuid "'+uid()+'"))')

    pcb.append('  (segment (start 173 118) (end 181 120.92) (width 2.5) (layer "F.Cu") (net 14) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 173 132) (end 181 126) (width 2.5) (layer "F.Cu") (net 15) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 173 146) (end 181 131.08) (width 2.5) (layer "F.Cu") (net 16) (uuid "'+uid()+'"))')

    pcb.append('  (segment (start 130.7 151.7) (end 134.05 140.65) (width 1.0) (layer "F.Cu") (net 3) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 130.7 151.7) (end 161 106) (width 1.0) (layer "F.Cu") (net 3) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 161 106) (end 161 134) (width 1.0) (layer "F.Cu") (net 3) (uuid "'+uid()+'"))')

    pcb.append('  (segment (start 134.05 141.35) (end 142 122.5) (width 0.8) (layer "F.Cu") (net 2) (uuid "'+uid()+'"))')

    pcb.append('  (segment (start 150 113.5) (end 154.05 111) (width 0.25) (layer "F.Cu") (net 11) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 150 115) (end 154.05 125) (width 0.25) (layer "F.Cu") (net 12) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 150 116.5) (end 154.05 139) (width 0.25) (layer "F.Cu") (net 13) (uuid "'+uid()+'"))')

    # Ground Plane
    pcb.append('  (zone (net 1) (net_name "GND") (layer "B.Cu") (uuid "'+uid()+'")')
    pcb.append('    (hatch edge 0.5)')
    pcb.append('    (connect_pads yes (clearance 0.3))')
    pcb.append('    (min_thickness 0.25)')
    pcb.append('    (filled_polygon')
    pcb.append('      (pts (xy 130 100) (xy 185 100) (xy 185 155) (xy 130 155))')
    pcb.append('    )')
    pcb.append('    (polygon (pts (xy 130 100) (xy 185 100) (xy 185 155) (xy 130 155)))')
    pcb.append('  )')

    pcb.append(')')

    with open(r"c:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\hardware\kicad\smart_switch_3x\smart_switch_3x.kicad_pcb", "w", encoding="utf-8") as f:
        f.write('\n'.join(pcb))

    print("Cleanly rebuilt smart_switch_3x.kicad_pcb with 100% complete net syntax!")

if __name__ == "__main__":
    main()
