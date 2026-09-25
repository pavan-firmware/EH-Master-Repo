import os

pretty_dir = r"c:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\hardware\kicad\smart_switch_3x\smart_switch_3x.pretty"
os.makedirs(pretty_dir, exist_ok=True)

# 1. fp-lib-table
fp_lib_table = """(fp_lib_table
  (version 7)
  (lib (name "smart_switch_3x")(type "KiCad")(uri "${KIPRJMOD}/smart_switch_3x.pretty")(options "")(descr "EH Smart Switch Local Footprints"))
)
"""
with open(r"c:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\hardware\kicad\smart_switch_3x\fp-lib-table", "w", encoding="utf-8") as f:
    f.write(fp_lib_table)

# 2. HLK-PM01 Footprint
hlk_pm01 = """(footprint "HLK-PM01" (version 20221018) (generator pcbnew)
  (layer "F.Cu")
  (descr "Hi-Link HLK-PM01 AC-DC Converter")
  (tags "HLK-PM01 SMPS")
  (attr through_hole)
  (fp_line (start -17.0 -10.1) (end 17.0 -10.1) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 17.0 -10.1) (end 17.0 10.1) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 17.0 10.1) (end -17.0 10.1) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start -17.0 10.1) (end -17.0 -10.1) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (pad "1" thru_hole rect (at -14.7 -2.5) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask"))
  (pad "2" thru_hole circle (at -14.7 2.5) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask"))
  (pad "3" thru_hole circle (at 14.7 7.7) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask"))
  (pad "4" thru_hole circle (at 14.7 -7.7) (size 2.5 2.5) (drill 1.2) (layers "*.Cu" "*.Mask"))
)
"""
with open(os.path.join(pretty_dir, "HLK-PM01.kicad_mod"), "w", encoding="utf-8") as f:
    f.write(hlk_pm01)

# 3. ESP32-C6-WROOM-1 Footprint
esp32_c6 = """(footprint "ESP32-C6-WROOM-1" (version 20221018) (generator pcbnew)
  (layer "F.Cu")
  (descr "Espressif ESP32-C6-WROOM-1 Module")
  (tags "ESP32-C6 RF Module")
  (attr smd)
  (fp_line (start -8.0 -12.75) (end 8.0 -12.75) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 8.0 -12.75) (end 8.0 12.75) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 8.0 12.75) (end -8.0 12.75) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start -8.0 12.75) (end -8.0 -12.75) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (pad "1" smd rect (at -8.0 -6.5) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "2" smd rect (at -8.0 -5.0) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "3" smd rect (at -8.0 -3.5) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "4" smd rect (at -8.0 -2.0) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "5" smd rect (at -8.0 -0.5) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "6" smd rect (at -8.0 1.0) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "7" smd rect (at -8.0 2.5) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "8" smd rect (at -8.0 4.0) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "9" smd rect (at -8.0 5.5) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "16" smd rect (at 8.0 5.5) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "17" smd rect (at 8.0 4.0) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "18" smd rect (at 8.0 2.5) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "19" smd rect (at 8.0 1.0) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "20" smd rect (at 8.0 -0.5) (size 1.5 0.9) (layers "F.Cu" "F.Paste" "F.Mask"))
  (pad "29" smd rect (at 0 0) (size 4.5 4.5) (layers "F.Cu" "F.Paste" "F.Mask"))
)
"""
with open(os.path.join(pretty_dir, "ESP32-C6-WROOM-1.kicad_mod"), "w", encoding="utf-8") as f:
    f.write(esp32_c6)

# 4. HF32F-G Relay Footprint
relay_hf32 = """(footprint "Relay_HF32F-G" (version 20221018) (generator pcbnew)
  (layer "F.Cu")
  (descr "Hongfa HF32F-G Subminiature 10A Relay")
  (tags "HF32F-G Relay")
  (attr through_hole)
  (fp_line (start -9.5 -7.75) (end 9.5 -7.75) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 9.5 -7.75) (end 9.5 7.75) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 9.5 7.75) (end -9.5 7.75) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start -9.5 7.75) (end -9.5 -7.75) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (pad "1" thru_hole circle (at -6.0 -6.0) (size 2.2 2.2) (drill 1.2) (layers "*.Cu" "*.Mask"))
  (pad "2" thru_hole circle (at -6.0 6.0) (size 2.2 2.2) (drill 1.2) (layers "*.Cu" "*.Mask"))
  (pad "3" thru_hole rect (at 6.0 -6.0) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask"))
  (pad "4" thru_hole circle (at 6.0 6.0) (size 2.5 2.5) (drill 1.3) (layers "*.Cu" "*.Mask"))
)
"""
with open(os.path.join(pretty_dir, "Relay_HF32F-G.kicad_mod"), "w", encoding="utf-8") as f:
    f.write(relay_hf32)

# 5. Fuse TR5
fuse_tr5 = """(footprint "Fuse_TR5" (version 20221018) (generator pcbnew)
  (layer "F.Cu")
  (descr "TR5 / TE5 Radial Subminiature Fuse")
  (tags "TR5 Fuse")
  (attr through_hole)
  (fp_circle (center 0 0) (end 4.25 0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (pad "1" thru_hole rect (at -2.54 0) (size 2.0 2.0) (drill 1.0) (layers "*.Cu" "*.Mask"))
  (pad "2" thru_hole circle (at 2.54 0) (size 2.0 2.0) (drill 1.0) (layers "*.Cu" "*.Mask"))
)
"""
with open(os.path.join(pretty_dir, "Fuse_TR5.kicad_mod"), "w", encoding="utf-8") as f:
    f.write(fuse_tr5)

# 6. MOV 14D
mov_14d = """(footprint "Varistor_14D" (version 20221018) (generator pcbnew)
  (layer "F.Cu")
  (descr "14D Varistor Disc 14mm P7.5mm")
  (tags "MOV 14D")
  (attr through_hole)
  (fp_line (start -7.5 -2.0) (end 7.5 -2.0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 7.5 2.0) (end -7.5 2.0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (pad "1" thru_hole rect (at -3.75 0) (size 2.2 2.2) (drill 1.0) (layers "*.Cu" "*.Mask"))
  (pad "2" thru_hole circle (at 3.75 0) (size 2.2 2.2) (drill 1.0) (layers "*.Cu" "*.Mask"))
)
"""
with open(os.path.join(pretty_dir, "Varistor_14D.kicad_mod"), "w", encoding="utf-8") as f:
    f.write(mov_14d)

# 7. NTC 9D
ntc_9d = """(footprint "NTC_9D" (version 20221018) (generator pcbnew)
  (layer "F.Cu")
  (descr "NTC Thermistor Disc 9mm P5.0mm")
  (tags "NTC Inrush")
  (attr through_hole)
  (fp_circle (center 0 0) (end 4.5 0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (pad "1" thru_hole rect (at -2.5 0) (size 2.0 2.0) (drill 0.9) (layers "*.Cu" "*.Mask"))
  (pad "2" thru_hole circle (at 2.5 0) (size 2.0 2.0) (drill 0.9) (layers "*.Cu" "*.Mask"))
)
"""
with open(os.path.join(pretty_dir, "NTC_9D.kicad_mod"), "w", encoding="utf-8") as f:
    f.write(ntc_9d)

# 8. Box Capacitor 10mm pitch (X2 & Snubber)
c_box = """(footprint "Capacitor_Box_P10mm" (version 20221018) (generator pcbnew)
  (layer "F.Cu")
  (descr "Box Film / Class-X2 Capacitor 10mm Pitch")
  (tags "X2 Film Cap")
  (attr through_hole)
  (fp_line (start -6.5 -3.0) (end 6.5 -3.0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 6.5 -3.0) (end 6.5 3.0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 6.5 3.0) (end -6.5 3.0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start -6.5 3.0) (end -6.5 -3.0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (pad "1" thru_hole rect (at -5.0 0) (size 2.2 2.2) (drill 1.0) (layers "*.Cu" "*.Mask"))
  (pad "2" thru_hole circle (at 5.0 0) (size 2.2 2.2) (drill 1.0) (layers "*.Cu" "*.Mask"))
)
"""
with open(os.path.join(pretty_dir, "Capacitor_Box_P10mm.kicad_mod"), "w", encoding="utf-8") as f:
    f.write(c_box)

# 9. Terminal Block 2-Pin 3.5mm
tb_2p = """(footprint "TerminalBlock_2P_P3.5mm" (version 20221018) (generator pcbnew)
  (layer "F.Cu")
  (descr "Terminal Block 2-Pin 3.5mm Pitch")
  (tags "Screw Terminal 3.5mm")
  (attr through_hole)
  (fp_line (start -3.5 -4.0) (end 3.5 -4.0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 3.5 -4.0) (end 3.5 4.0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start 3.5 4.0) (end -3.5 4.0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (fp_line (start -3.5 4.0) (end -3.5 -4.0) (stroke (width 0.15) (type solid)) (layer "F.SilkS"))
  (pad "1" thru_hole rect (at -1.75 0) (size 2.2 2.2) (drill 1.2) (layers "*.Cu" "*.Mask"))
  (pad "2" thru_hole circle (at 1.75 0) (size 2.2 2.2) (drill 1.2) (layers "*.Cu" "*.Mask"))
)
"""
with open(os.path.join(pretty_dir, "TerminalBlock_2P_P3.5mm.kicad_mod"), "w", encoding="utf-8") as f:
    f.write(tb_2p)

print("Created complete self-contained smart_switch_3x.pretty footprint library!")
