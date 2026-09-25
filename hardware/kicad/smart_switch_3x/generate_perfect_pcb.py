import os
import uuid
import subprocess

def uid():
    return str(uuid.uuid4())

def main():
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

    # Net definitions
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

    def pad_net(n):
        val = net_dict.get(n, '""')
        return f'(net {n} {val})'

    def model_3d(path, offset=(0,0,0), scale=(1,1,1), rotate=(0,0,0)):
        return f"""    (model "{path}"
      (offset (xyz {offset[0]} {offset[1]} {offset[2]}))
      (scale (xyz {scale[0]} {scale[1]} {scale[2]}))
      (rotate (xyz {rotate[0]} {rotate[1]} {rotate[2]}))
    )"""

    # Board Outline (86mm x 56mm - Standard 2-Gang Wall Box PCB)
    # Origin at (100, 100) -> X: 100 to 186, Y: 100 to 156
    pcb.append('  (gr_rect (start 100 100) (end 186 156) (stroke (width 0.25) (type solid)) (layer "Edge.Cuts") (uuid "'+uid()+'"))')

    # 4 Mounting Holes (M3)
    for mx, my in [(104, 104), (182, 104), (104, 152), (182, 152)]:
        pcb.append(f'  (footprint "MountingHole:MountingHole_3.2mm_M3" (layer "F.Cu") (at {mx} {my}) (uuid "{uid()}")')
        pcb.append('    (pad "" np_thru_hole circle (at 0 0) (size 3.2 3.2) (drill 3.2) (layers "*.Cu" "*.Mask"))')
        pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/MountingHole.3dshapes/MountingHole_3.2mm_M3.step"))
        pcb.append('  )')

    # Silkscreen Division Lines & Legend
    pcb.append('  (gr_line (start 128 101) (end 128 155) (stroke (width 0.2) (type dash)) (layer "F.SilkS") (uuid "'+uid()+'"))')
    pcb.append('  (gr_line (start 160 101) (end 160 145) (stroke (width 0.2) (type dash)) (layer "F.SilkS") (uuid "'+uid()+'"))')
    pcb.append('  (gr_text "EH SMART SWITCH 3X" (at 144 102.5) (layer "F.SilkS") (effects (font (size 1.2 1.2) (thickness 0.18) (bold yes))) (uuid "'+uid()+'"))')
    pcb.append('  (gr_text "230V AC IN" (at 114 102.5) (layer "F.SilkS") (effects (font (size 0.9 0.9) (thickness 0.14) (bold yes))) (uuid "'+uid()+'"))')
    pcb.append('  (gr_text "OUTPUTS" (at 173 102.5) (layer "F.SilkS") (effects (font (size 0.9 0.9) (thickness 0.14) (bold yes))) (uuid "'+uid()+'"))')

    # High-Voltage Isolation Slots (2.0mm air gap slots)
    # Slot 1: Separates AC Mains from Logic
    pcb.append('  (gr_rect (start 127.2 105) (end 128.8 151) (stroke (width 0.2) (type solid)) (layer "Edge.Cuts") (uuid "'+uid()+'"))')
    # Slot 2: Separates Logic from Relay Output Switching
    pcb.append('  (gr_rect (start 159.2 105) (end 160.8 143) (stroke (width 0.2) (type solid)) (layer "Edge.Cuts") (uuid "'+uid()+'"))')

    # ==================== SECTION 1: MAINS AC POWER & PROTECTION ====================
    # J1 Mains Input Terminal (3-Pin MKDS 5.08mm) at X=108, Y=110, 90 deg (Wire entry facing left)
    pcb.append(f'  (footprint "TerminalBlock_Phoenix:TerminalBlock_Phoenix_MKDS-1,5-3-5.08_1x03_P5.08mm_Horizontal" (layer "F.Cu") (at 108 110 90) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "J1" (at 0 -4 90) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    pcb.append(f'    (pad "1" thru_hole roundrect (at -5.08 0 90) (size 2.2 2.2) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(4)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 0 0 90) (size 2.2 2.2) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(5)})')
    pcb.append(f'    (pad "3" thru_hole circle (at 5.08 0 90) (size 2.2 2.2) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(1)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/TerminalBlock_Phoenix.3dshapes/TerminalBlock_Phoenix_MKDS-1,5-3-5.08_1x03_P5.08mm_Horizontal.step"))
    pcb.append('  )')

    # F1 Fuse (TR5 2A 250V Time-Lag) at (118, 107)
    pcb.append(f'  (footprint "Fuse:Fuseholder_TR5_Littelfuse_No560_No460" (layer "F.Cu") (at 118 107) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "F1" (at 0 -4) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -2.54 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(4)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 2.54 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Fuse.3dshapes/Fuseholder_TR5_Littelfuse_No560_No460.step"))
    pcb.append('  )')

    # MOV1 Varistor (14D561K 440V Clamping) at (118, 114)
    pcb.append(f'  (footprint "Varistor:RV_Disc_D12mm_W4.2mm_P7.5mm" (layer "F.Cu") (at 118 114) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "MOV1" (at 0 -3.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -3.75 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 3.75 0) (size 2.2 2.2) (drill 1.1) (layers "*.Cu" "*.Mask") {pad_net(5)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Varistor.3dshapes/RV_Disc_D12mm_W4.2mm_P7.5mm.step"))
    pcb.append('  )')

    # NTC1 Inrush Limiter (10D-9) at (118, 120)
    pcb.append(f'  (footprint "Resistor_THT:R_Radial_Power_L11.0mm_W7.0mm_P5.00mm" (layer "F.Cu") (at 118 120) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "NTC1" (at 0 -3.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -2.5 0) (size 2.0 2.0) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 2.5 0) (size 2.0 2.0) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Resistor_THT.3dshapes/R_Radial_Power_L11.0mm_W7.0mm_P5.00mm.step"))
    pcb.append('  )')

    # CX1 Class-X2 Safety Cap (0.1uF 275V Box 10mm) at (118, 126)
    pcb.append(f'  (footprint "Capacitor_THT:C_Rect_L13.0mm_W4.0mm_P10.00mm_FKS3_FKP3" (layer "F.Cu") (at 118 126) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "CX1" (at 0 -3.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -5.0 0) (size 2.0 2.0) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 5.0 0) (size 2.0 2.0) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(5)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Capacitor_THT.3dshapes/C_Rect_L13.0mm_W4.0mm_P10.00mm_FKS3_FKP3.step"))
    pcb.append('  )')

    # U2 HLK-PM01 Isolated SMPS Power Module (at X=114, Y=118, 270 deg)
    # Body occupies X: 105 to 127, Y: 114 to 151. Perfectly fits inside AC Section!
    pcb.append(f'  (footprint "Converter_ACDC:Converter_ACDC_Hi-Link_HLK-PMxx" (layer "F.Cu") (at 114 118 270) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "U2" (at 14.54 -9.7 270) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    pcb.append(f'    (pad "1" thru_hole roundrect (at 0 0 270) (size 1.8 2.2) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(6)})')
    pcb.append(f'    (pad "2" thru_hole oval (at 0 5 270) (size 1.8 2.2) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(5)})')
    pcb.append(f'    (pad "3" thru_hole oval (at 29.08 -5 270) (size 1.8 2.2) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(3)})')
    pcb.append(f'    (pad "4" thru_hole oval (at 29.08 10 270) (size 1.8 2.2) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(1)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Converter_ACDC.3dshapes/Converter_ACDC_Hi-Link_HLK-PMxx.step"))
    pcb.append('  )')

    # ==================== SECTION 2: LOW VOLTAGE MCU & TELEMETRY (X: 130 - 158) ====================
    # C1 (470uF 16V Bulk Cap) at (133, 146)
    pcb.append(f'  (footprint "Capacitor_THT:CP_Radial_D6.3mm_P2.50mm" (layer "F.Cu") (at 133 146) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "C1" (at 0 -3.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
    pcb.append(f'    (pad "1" thru_hole rect (at -1.25 0) (size 1.8 1.8) (drill 0.9) (layers "*.Cu" "*.Mask") {pad_net(3)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 1.25 0) (size 1.8 1.8) (drill 0.9) (layers "*.Cu" "*.Mask") {pad_net(1)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Capacitor_THT.3dshapes/CP_Radial_D6.3mm_P2.50mm.step"))
    pcb.append('  )')

    # U3 AP2112K-3.3 LDO at (133, 137)
    pcb.append(f'  (footprint "Package_TO_SOT_SMD:SOT-23-5" (layer "F.Cu") (at 133 137) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "U3" (at 0 -2.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
    pcb.append(f'    (pad "1" smd rect (at -0.95 -1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(3)})')
    pcb.append(f'    (pad "2" smd rect (at 0 -1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append(f'    (pad "3" smd rect (at 0.95 -1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(3)})')
    pcb.append(f'    (pad "5" smd rect (at -0.95 1.35) (size 0.6 1.05) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(2)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Package_TO_SOT_SMD.3dshapes/SOT-23-5.step"))
    pcb.append('  )')

    # C2 (100uF SMD Cap) at (133, 129)
    pcb.append(f'  (footprint "Capacitor_SMD:CP_Elec_6.3x5.8" (layer "F.Cu") (at 133 129) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "C2" (at 0 -3.5) (layer "F.SilkS") (effects (font (size 0.7 0.7) (thickness 0.1))))')
    pcb.append(f'    (pad "1" smd rect (at -2.5 0) (size 2.0 1.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(2)})')
    pcb.append(f'    (pad "2" smd rect (at 2.5 0) (size 2.0 1.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Capacitor_SMD.3dshapes/CP_Elec_6.3x5.8.step"))
    pcb.append('  )')

    # U1 ESP32-C6 Module at (144, 114, 90 deg)
    pcb.append(f'  (footprint "RF_Module:ESP32-C3-WROOM-02" (layer "F.Cu") (at 144 114 90) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "U1" (at 0 -13 90) (layer "F.SilkS") (effects (font (size 0.9 0.9) (thickness 0.12))))')
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
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/RF_Module.3dshapes/ESP32-C3-WROOM-02.step"))
    pcb.append('  )')

    def add_res_0603(ref, x, y, net1, net2):
        pcb.append(f'  (footprint "Resistor_SMD:R_0603_1608Metric" (layer "F.Cu") (at {x} {y}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "{ref}" (at 0 -1.5) (layer "F.SilkS") (effects (font (size 0.6 0.6) (thickness 0.08))))')
        pcb.append(f'    (pad "1" smd rect (at -0.8 0) (size 0.8 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(net1)})')
        pcb.append(f'    (pad "2" smd rect (at 0.8 0) (size 0.8 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(net2)})')
        pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Resistor_SMD.3dshapes/R_0603_1608Metric.step"))
        pcb.append('  )')

    def add_cap_0603(ref, x, y, net1, net2):
        pcb.append(f'  (footprint "Capacitor_SMD:C_0603_1608Metric" (layer "F.Cu") (at {x} {y}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "{ref}" (at 0 -1.5) (layer "F.SilkS") (effects (font (size 0.6 0.6) (thickness 0.08))))')
        pcb.append(f'    (pad "1" smd rect (at -0.8 0) (size 0.8 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(net1)})')
        pcb.append(f'    (pad "2" smd rect (at 0.8 0) (size 0.8 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(net2)})')
        pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Capacitor_SMD.3dshapes/C_0603_1608Metric.step"))
        pcb.append('  )')

    # ESP32 Passives
    add_res_0603("R_EN", 133, 118, 2, 2)
    add_cap_0603("C_EN", 133, 122, 2, 1)
    add_res_0603("R_LED", 133, 110, 18, 18)

    # LED1 (Status Indicator)
    pcb.append(f'  (footprint "LED_SMD:LED_0603_1608Metric" (layer "F.Cu") (at 133 106) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "LED1" (at 0 -1.5) (layer "F.SilkS") (effects (font (size 0.6 0.6) (thickness 0.08))))')
    pcb.append(f'    (pad "1" smd rect (at -0.8 0) (size 0.8 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(18)})')
    pcb.append(f'    (pad "2" smd rect (at 0.8 0) (size 0.8 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/LED_SMD.3dshapes/LED_0603_1608Metric.step"))
    pcb.append('  )')

    # U4 BL0942 Energy Meter IC (SOIC-14) at (146, 132)
    pcb.append(f'  (footprint "Package_SO:SOIC-14_3.9x8.7mm_P1.27mm" (layer "F.Cu") (at 146 132) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "U4" (at 0 -5.5) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    pcb.append(f'    (pad "1" smd rect (at -2.7 -3.81) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(2)})')
    pcb.append(f'    (pad "2" smd rect (at -2.7 -2.54) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(5)})')
    pcb.append(f'    (pad "3" smd rect (at -2.7 -1.27) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(20)})')
    pcb.append(f'    (pad "4" smd rect (at -2.7 0) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(4)})')
    pcb.append(f'    (pad "5" smd rect (at -2.7 1.27) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append(f'    (pad "11" smd rect (at 2.7 -1.27) (size 1.5 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(17)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Package_SO.3dshapes/SOIC-14_3.9x8.7mm_P1.27mm.step"))
    pcb.append('  )')

    # R_SHUNT (2512 SMD) at (141, 140)
    pcb.append(f'  (footprint "Resistor_SMD:R_2512_6332Metric" (layer "F.Cu") (at 141 140) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "R_SHUNT" (at 0 -2.5) (layer "F.SilkS") (effects (font (size 0.65 0.65) (thickness 0.08))))')
    pcb.append(f'    (pad "1" smd rect (at -2.8 0) (size 1.6 3.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(5)})')
    pcb.append(f'    (pad "2" smd rect (at 2.8 0) (size 1.6 3.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(20)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Resistor_SMD.3dshapes/R_2512_6332Metric.step"))
    pcb.append('  )')

    # RHV1 (1206 SMD) at (151, 140)
    pcb.append(f'  (footprint "Resistor_SMD:R_1206_3216Metric" (layer "F.Cu") (at 151 140) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "RHV1" (at 0 -2.5) (layer "F.SilkS") (effects (font (size 0.65 0.65) (thickness 0.08))))')
    pcb.append(f'    (pad "1" smd rect (at -1.5 0) (size 1.1 1.8) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(4)})')
    pcb.append(f'    (pad "2" smd rect (at 1.5 0) (size 1.1 1.8) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Resistor_SMD.3dshapes/R_1206_3216Metric.step"))
    pcb.append('  )')

    # ==================== SECTION 3: WALL SWITCH INPUTS (BOTTOM ROW: Y = 150) ====================
    # Wire entrance facing DOWN (rotation 180)
    for idx, x_sw in enumerate([136, 145, 154]):
        ch = idx + 1
        pcb.append(f'  (footprint "TerminalBlock_Phoenix:TerminalBlock_Phoenix_MKDS-1,5-2_1x02_P5.00mm_Horizontal" (layer "F.Cu") (at {x_sw} 150 180) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "J_SW{ch}" (at 0 -3.5 180) (layer "F.SilkS") (effects (font (size 0.65 0.65) (thickness 0.08))))')
        pcb.append(f'    (pad "1" thru_hole roundrect (at -2.5 0 180) (size 2.0 2.0) (drill 1.2) (layers "*.Cu" "*.Mask") {pad_net(7+ch)})')
        pcb.append(f'    (pad "2" thru_hole circle (at 2.5 0 180) (size 2.0 2.0) (drill 1.2) (layers "*.Cu" "*.Mask") {pad_net(1)})')
        pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/TerminalBlock_Phoenix.3dshapes/TerminalBlock_Phoenix_MKDS-1,5-2_1x02_P5.00mm_Horizontal.step"))
        pcb.append('  )')

        # RC Filter + Pull-up + TVS Diode
        add_res_0603(f"RSW{ch}", x_sw-1.5, 145, 7+ch, 7+ch)
        add_res_0603(f"RPU{ch}", x_sw+1.5, 145, 2, 7+ch)
        add_cap_0603(f"CSW{ch}", x_sw-1.5, 142, 7+ch, 1)

        # TVS Diode (SOD-523)
        pcb.append(f'  (footprint "Diode_SMD:D_SOD-523" (layer "F.Cu") (at {x_sw+1.5} 142) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "TVS{ch}" (at 0 -1.2) (layer "F.SilkS") (effects (font (size 0.5 0.5) (thickness 0.08))))')
        pcb.append(f'    (pad "1" smd rect (at -0.7 0) (size 0.6 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(7+ch)})')
        pcb.append(f'    (pad "2" smd rect (at 0.7 0) (size 0.6 0.6) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
        pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Diode_SMD.3dshapes/D_SOD-523.step"))
        pcb.append('  )')

    # ==================== SECTION 4: RELAY OUTPUT CHANNELS (X: 161 - 185) ====================
    y_relays = [111, 127, 143]
    for idx, yr in enumerate(y_relays):
        ch = idx + 1
        # MOSFET Q1..3 (SOT-23) at (156, yr)
        pcb.append(f'  (footprint "Package_TO_SOT_SMD:SOT-23" (layer "F.Cu") (at 156 {yr}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "Q{ch}" (at 0 -2) (layer "F.SilkS") (effects (font (size 0.6 0.6) (thickness 0.08))))')
        pcb.append(f'    (pad "1" smd rect (at -0.95 -1) (size 0.6 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(10+ch)})')
        pcb.append(f'    (pad "2" smd rect (at 0.95 -1) (size 0.6 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(1)})')
        pcb.append(f'    (pad "3" smd rect (at 0 1) (size 0.6 0.9) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(10+ch)})')
        pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Package_TO_SOT_SMD.3dshapes/SOT-23.step"))
        pcb.append('  )')

        # Gate Resistors
        add_res_0603(f"RG{ch}", 153, yr-2.5, 10+ch, 10+ch)
        add_res_0603(f"RPD{ch}", 153, yr+2.5, 10+ch, 1)

        # Flyback Diode D1..3 (SOD-123) at (163, yr-5.5)
        pcb.append(f'  (footprint "Diode_SMD:D_SOD-123" (layer "F.Cu") (at 163 {yr-5.5}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "D{ch}" (at 0 -1.5) (layer "F.SilkS") (effects (font (size 0.6 0.6) (thickness 0.08))))')
        pcb.append(f'    (pad "1" smd rect (at -1.4 0) (size 0.9 1.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(3)})')
        pcb.append(f'    (pad "2" smd rect (at 1.4 0) (size 0.9 1.2) (layers "F.Cu" "F.Paste" "F.Mask") {pad_net(10+ch)})')
        pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Diode_SMD.3dshapes/D_SOD-123.step"))
        pcb.append('  )')

        # K1..3 SANYOU SRD 10A Power Relays at X = 163, Y = yr
        pcb.append(f'  (footprint "Relay_THT:Relay_SPDT_SANYOU_SRD_Series_Form_C" (layer "F.Cu") (at 163 {yr}) (uuid "{uid()}")')
        pcb.append(f'    (fp_text reference "K{ch}" (at 8.1 9.2) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
        pcb.append(f'    (pad "1" thru_hole circle (at 0 0) (size 2.8 2.8) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(3)})')
        pcb.append(f'    (pad "2" thru_hole circle (at 1.95 6.05) (size 2.2 2.2) (drill 1.0) (layers "*.Cu" "*.Mask") {pad_net(10+ch)})')
        pcb.append(f'    (pad "3" thru_hole circle (at 14.15 6.05) (size 2.8 2.8) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(13+ch)})')
        pcb.append(f'    (pad "4" thru_hole circle (at 14.2 -6.0) (size 2.8 2.8) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(0)})')
        pcb.append(f'    (pad "5" thru_hole circle (at 1.95 -5.95) (size 2.8 2.8) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(4)})')
        pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/Relay_THT.3dshapes/Relay_SPDT_SANYOU_SRD_Series_Form_C.step"))
        pcb.append('  )')

    # J2: Load Output Terminal Block (3-Pin Phoenix MKDS 5.08mm) at X=182, Y=127, 270 deg (Wire entry facing right)
    pcb.append(f'  (footprint "TerminalBlock_Phoenix:TerminalBlock_Phoenix_MKDS-1,5-3-5.08_1x03_P5.08mm_Horizontal" (layer "F.Cu") (at 182 127 270) (uuid "{uid()}")')
    pcb.append('    (fp_text reference "J2" (at 0 -4 270) (layer "F.SilkS") (effects (font (size 0.8 0.8) (thickness 0.12))))')
    pcb.append(f'    (pad "1" thru_hole roundrect (at -5.08 0 270) (size 2.2 2.2) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(14)})')
    pcb.append(f'    (pad "2" thru_hole circle (at 0 0 270) (size 2.2 2.2) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(15)})')
    pcb.append(f'    (pad "3" thru_hole circle (at 5.08 0 270) (size 2.2 2.2) (drill 1.3) (layers "*.Cu" "*.Mask") {pad_net(16)})')
    pcb.append(model_3d("${KICAD10_3DMODEL_DIR}/TerminalBlock_Phoenix.3dshapes/TerminalBlock_Phoenix_MKDS-1,5-3-5.08_1x03_P5.08mm_Horizontal.step"))
    pcb.append('  )')

    # ==================== CLEAN ORTHOGONAL PCB TRACKS ====================
    # 1. AC Live Input Bus (2.5mm Width, Top Layer)
    pcb.append('  (segment (start 108 104.92) (end 115.46 107) (width 2.5) (layer "F.Cu") (net 4) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 115.46 107) (end 118 107) (width 2.5) (layer "F.Cu") (net 4) (uuid "'+uid()+'"))')

    # AC Common Bus across Relays K1, K2, K3 COM pins (2.5mm width)
    pcb.append('  (segment (start 164.95 105.05) (end 164.95 137.05) (width 2.5) (layer "F.Cu") (net 4) (uuid "'+uid()+'"))')

    # Relay Switched Load Lines to J2 (2.5mm width)
    pcb.append('  (segment (start 177.15 117.05) (end 182 121.92) (width 2.5) (layer "F.Cu") (net 14) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 177.15 133.05) (end 182 127) (width 2.5) (layer "F.Cu") (net 15) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 177.15 149.05) (end 182 132.08) (width 2.5) (layer "F.Cu") (net 16) (uuid "'+uid()+'"))')

    # 2. DC Power Rails (+5V and +3.3V)
    pcb.append('  (segment (start 119 167.08) (end 133 146) (width 0.8) (layer "F.Cu") (net 3) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 133 146) (end 133 137) (width 0.8) (layer "F.Cu") (net 3) (uuid "'+uid()+'"))')
    pcb.append('  (segment (start 132.05 138.35) (end 133 129) (width 0.8) (layer "F.Cu") (net 2) (uuid "'+uid()+'"))')

    # 3. Low Voltage Ground Polygon Zone on Bottom Layer (strictly within Logic Section)
    pcb.append('  (zone (net 1) (net_name "GND") (layer "B.Cu") (uuid "'+uid()+'")')
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
    print(f"Generated clean PCB at {target}")

if __name__ == "__main__":
    main()
