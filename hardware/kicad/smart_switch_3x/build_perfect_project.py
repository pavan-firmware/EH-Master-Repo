import os
import uuid

def uid():
    return str(uuid.uuid4())

def generate_schematic():
    sch = []
    sch.append('(kicad_sch')
    sch.append('\t(version 20231120)')
    sch.append('\t(generator "eeschema")')
    sch.append('\t(generator_version "8.0")')
    sch.append(f'\t(uuid "{uid()}")')
    sch.append('\t(paper "A3")')
    sch.append('\t(title_block')
    sch.append('\t\t(title "EH Smart Switch 3X - Industrial Production Board")')
    sch.append('\t\t(date "2026-09-21")')
    sch.append('\t\t(rev "v1.0.0")')
    sch.append('\t\t(company "EH Platform Engineering")')
    sch.append('\t\t(comment 1 "5-Tier Industrial Protection, BL0942 Metering, ESP32-C6")')
    sch.append('\t\t(comment 2 "Target: IEC/EN 60669-2-1, IEC 62368-1, RoHS")')
    sch.append('\t)')
    
    # Embedded Library Symbols
    sch.append('\t(lib_symbols')
    
    # Resistor
    sch.append('\t\t(symbol "Device:R"')
    sch.append('\t\t\t(pin passive line (at 0 3.81 270) (length 2.54) (name "~" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 0 -3.81 90) (length 2.54) (name "~" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -1.016 1.27) (end 1.016 -1.27) (stroke (width 0.254) (type solid)) (fill (type none)))')
    sch.append('\t\t)')

    # Capacitor
    sch.append('\t\t(symbol "Device:C"')
    sch.append('\t\t\t(pin passive line (at 0 3.81 270) (length 2.54) (name "~" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 0 -3.81 90) (length 2.54) (name "~" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(polyline (pts (xy -2.032 1.27) (xy 2.032 1.27)) (stroke (width 0.381) (type solid)))')
    sch.append('\t\t\t(polyline (pts (xy -2.032 -1.27) (xy 2.032 -1.27)) (stroke (width 0.381) (type solid)))')
    sch.append('\t\t)')

    # Polarized Cap
    sch.append('\t\t(symbol "Device:C_Polarized"')
    sch.append('\t\t\t(pin passive line (at 0 3.81 270) (length 2.54) (name "~" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 0 -3.81 90) (length 2.54) (name "~" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -2.032 1.27) (end 2.032 0.762) (stroke (width 0.254) (type solid)) (fill (type outline)))')
    sch.append('\t\t\t(polyline (pts (xy -2.032 -1.27) (xy 2.032 -1.27)) (stroke (width 0.381) (type solid)))')
    sch.append('\t\t)')

    # Diode
    sch.append('\t\t(symbol "Device:D_Schottky"')
    sch.append('\t\t\t(pin passive line (at -3.81 0 0) (length 2.54) (name "K" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 3.81 0 180) (length 2.54) (name "A" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(polyline (pts (xy 1.27 -1.27) (xy 1.27 1.27) (xy -1.27 0) (xy 1.27 -1.27)) (stroke (width 0.254) (type solid)) (fill (type outline)))')
    sch.append('\t\t\t(polyline (pts (xy -1.27 -1.27) (xy -1.27 1.27)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t)')

    # Fuse
    sch.append('\t\t(symbol "Device:Fuse"')
    sch.append('\t\t\t(pin passive line (at -3.81 0 0) (length 2.54) (name "~" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 3.81 0 180) (length 2.54) (name "~" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -1.905 0.762) (end 1.905 -0.762) (stroke (width 0.254) (type solid)) (fill (type none)))')
    sch.append('\t\t\t(polyline (pts (xy -1.905 0) (xy 1.905 0)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t)')

    # Varistor (MOV)
    sch.append('\t\t(symbol "Device:Varistor"')
    sch.append('\t\t\t(pin passive line (at 0 3.81 270) (length 2.54) (name "~" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 0 -3.81 90) (length 2.54) (name "~" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -1.016 1.524) (end 1.016 -1.524) (stroke (width 0.254) (type solid)) (fill (type none)))')
    sch.append('\t\t\t(polyline (pts (xy -1.524 1.524) (xy -1.016 1.524) (xy 1.016 -1.524) (xy 1.524 -1.524)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t)')

    # LED
    sch.append('\t\t(symbol "Device:LED"')
    sch.append('\t\t\t(pin passive line (at -3.81 0 0) (length 2.54) (name "A" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 3.81 0 180) (length 2.54) (name "K" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(polyline (pts (xy -1.27 -1.27) (xy -1.27 1.27) (xy 1.27 0) (xy -1.27 -1.27)) (stroke (width 0.254) (type solid)) (fill (type outline)))')
    sch.append('\t\t\t(polyline (pts (xy 1.27 -1.27) (xy 1.27 1.27)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t)')

    # Power +3V3
    sch.append('\t\t(symbol "power:+3V3"')
    sch.append('\t\t\t(pin power_in line (at 0 0 90) (length 0) (name "+3V3" (effects (font (size 1.27 1.27)) hide)) (number "1" (effects (font (size 1.27 1.27)) hide)))')
    sch.append('\t\t\t(polyline (pts (xy -0.762 1.27) (xy 0 2.54) (xy 0.762 1.27)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t\t(polyline (pts (xy 0 0) (xy 0 2.54)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t)')

    # Power +5V
    sch.append('\t\t(symbol "power:+5V"')
    sch.append('\t\t\t(pin power_in line (at 0 0 90) (length 0) (name "+5V" (effects (font (size 1.27 1.27)) hide)) (number "1" (effects (font (size 1.27 1.27)) hide)))')
    sch.append('\t\t\t(polyline (pts (xy -0.762 1.27) (xy 0 2.54) (xy 0.762 1.27)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t\t(polyline (pts (xy 0 0) (xy 0 2.54)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t)')

    # Power GND
    sch.append('\t\t(symbol "power:GND"')
    sch.append('\t\t\t(pin power_in line (at 0 0 270) (length 0) (name "GND" (effects (font (size 1.27 1.27)) hide)) (number "1" (effects (font (size 1.27 1.27)) hide)))')
    sch.append('\t\t\t(polyline (pts (xy -1.27 0) (xy 1.27 0)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t\t(polyline (pts (xy -0.762 -0.762) (xy 0.762 -0.762)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t\t(polyline (pts (xy -0.254 -1.524) (xy 0.254 -1.524)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t)')

    # Connector 2-Pin
    sch.append('\t\t(symbol "Connector:Conn_01x02"')
    sch.append('\t\t\t(pin passive line (at -5.08 1.27 0) (length 2.54) (name "Pin_1" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at -5.08 -1.27 0) (length 2.54) (name "Pin_2" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -2.54 2.54) (end 2.54 -2.54) (stroke (width 0.254) (type solid)) (fill (type background)))')
    sch.append('\t\t)')

    # Connector 3-Pin
    sch.append('\t\t(symbol "Connector:Conn_01x03"')
    sch.append('\t\t\t(pin passive line (at -5.08 2.54 0) (length 2.54) (name "Pin_1" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at -5.08 0 0) (length 2.54) (name "Pin_2" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at -5.08 -2.54 0) (length 2.54) (name "Pin_3" (effects (font (size 1.27 1.27)))) (number "3" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -2.54 3.81) (end 2.54 -3.81) (stroke (width 0.254) (type solid)) (fill (type background)))')
    sch.append('\t\t)')

    # Transistor N-MOS
    sch.append('\t\t(symbol "Device:Q_NMOS_GSD"')
    sch.append('\t\t\t(pin passive line (at -5.08 0 0) (length 2.54) (name "G" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 2.54 -5.08 90) (length 2.54) (name "S" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 2.54 5.08 270) (length 2.54) (name "D" (effects (font (size 1.27 1.27)))) (number "3" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(polyline (pts (xy -2.54 2.54) (xy -2.54 -2.54)) (stroke (width 0.381) (type solid)))')
    sch.append('\t\t\t(polyline (pts (xy 0 2.54) (xy 2.54 2.54) (xy 2.54 5.08)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t\t(polyline (pts (xy 0 -2.54) (xy 2.54 -2.54) (xy 2.54 -5.08)) (stroke (width 0.254) (type solid)))')
    sch.append('\t\t)')

    # Generic IC HLK-PM01
    sch.append('\t\t(symbol "Power_Supply:HLK-PM01"')
    sch.append('\t\t\t(pin power_in line (at -12.7 5.08 0) (length 2.54) (name "AC_L" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin power_in line (at -12.7 -5.08 0) (length 2.54) (name "AC_N" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin power_out line (at 12.7 5.08 180) (length 2.54) (name "+VOUT" (effects (font (size 1.27 1.27)))) (number "3" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin power_out line (at 12.7 -5.08 180) (length 2.54) (name "-VOUT" (effects (font (size 1.27 1.27)))) (number "4" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -10.16 7.62) (end 10.16 -7.62) (stroke (width 0.254) (type solid)) (fill (type background)))')
    sch.append('\t\t)')

    # AP2112K-3.3
    sch.append('\t\t(symbol "Regulator_Linear:AP2112K-3.3"')
    sch.append('\t\t\t(pin power_in line (at -10.16 2.54 0) (length 2.54) (name "VIN" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin power_in line (at 0 -7.62 90) (length 2.54) (name "GND" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin input line (at -10.16 -2.54 0) (length 2.54) (name "EN" (effects (font (size 1.27 1.27)))) (number "3" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 10.16 -2.54 180) (length 2.54) (name "NC" (effects (font (size 1.27 1.27)))) (number "4" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin power_out line (at 10.16 2.54 180) (length 2.54) (name "VOUT" (effects (font (size 1.27 1.27)))) (number "5" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -7.62 5.08) (end 7.62 -5.08) (stroke (width 0.254) (type solid)) (fill (type background)))')
    sch.append('\t\t)')

    # Relay 10A SPST
    sch.append('\t\t(symbol "Relay:HF32F-G"')
    sch.append('\t\t\t(pin passive line (at -7.62 2.54 0) (length 2.54) (name "COIL1" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at -7.62 -2.54 0) (length 2.54) (name "COIL2" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 7.62 2.54 180) (length 2.54) (name "COM" (effects (font (size 1.27 1.27)))) (number "3" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin passive line (at 7.62 -2.54 180) (length 2.54) (name "NO" (effects (font (size 1.27 1.27)))) (number "4" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -5.08 5.08) (end 5.08 -5.08) (stroke (width 0.254) (type solid)) (fill (type background)))')
    sch.append('\t\t)')

    # BL0942 Energy IC
    sch.append('\t\t(symbol "Sensor_Energy:BL0942"')
    sch.append('\t\t\t(pin power_in line (at -12.7 7.62 0) (length 2.54) (name "VDD" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin input line (at -12.7 2.54 0) (length 2.54) (name "IP" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin input line (at -12.7 -2.54 0) (length 2.54) (name "IN" (effects (font (size 1.27 1.27)))) (number "3" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin input line (at -12.7 -7.62 0) (length 2.54) (name "VP" (effects (font (size 1.27 1.27)))) (number "4" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin power_in line (at 0 -12.7 90) (length 2.54) (name "GND" (effects (font (size 1.27 1.27)))) (number "5" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin output line (at 12.7 2.54 180) (length 2.54) (name "TX_OUT" (effects (font (size 1.27 1.27)))) (number "11" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -10.16 10.16) (end 10.16 -10.16) (stroke (width 0.254) (type solid)) (fill (type background)))')
    sch.append('\t\t)')

    # ESP32-C6-WROOM-1
    sch.append('\t\t(symbol "RF_Module:ESP32-C6-WROOM-1"')
    sch.append('\t\t\t(pin power_in line (at -15.24 15.24 0) (length 2.54) (name "3V3" (effects (font (size 1.27 1.27)))) (number "1" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin input line (at -15.24 10.16 0) (length 2.54) (name "EN" (effects (font (size 1.27 1.27)))) (number "2" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at -15.24 5.08 0) (length 2.54) (name "IO4" (effects (font (size 1.27 1.27)))) (number "4" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at -15.24 0 0) (length 2.54) (name "IO5" (effects (font (size 1.27 1.27)))) (number "5" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at -15.24 -5.08 0) (length 2.54) (name "IO6" (effects (font (size 1.27 1.27)))) (number "6" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at -15.24 -10.16 0) (length 2.54) (name "IO7" (effects (font (size 1.27 1.27)))) (number "7" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at -15.24 -15.24 0) (length 2.54) (name "IO8" (effects (font (size 1.27 1.27)))) (number "8" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at -15.24 -20.32 0) (length 2.54) (name "IO9" (effects (font (size 1.27 1.27)))) (number "9" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin power_in line (at 0 -25.4 90) (length 2.54) (name "GND" (effects (font (size 1.27 1.27)))) (number "3" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at 15.24 10.16 180) (length 2.54) (name "IO18" (effects (font (size 1.27 1.27)))) (number "18" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at 15.24 5.08 180) (length 2.54) (name "IO19" (effects (font (size 1.27 1.27)))) (number "19" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at 15.24 0 180) (length 2.54) (name "IO20" (effects (font (size 1.27 1.27)))) (number "20" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at 15.24 -10.16 180) (length 2.54) (name "TXD0" (effects (font (size 1.27 1.27)))) (number "16" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(pin bidirectional line (at 15.24 -15.24 180) (length 2.54) (name "RXD0" (effects (font (size 1.27 1.27)))) (number "17" (effects (font (size 1.27 1.27)))))')
    sch.append('\t\t\t(rectangle (start -12.7 17.78) (end 12.7 -22.86) (stroke (width 0.254) (type solid)) (fill (type background)))')
    sch.append('\t\t)')

    sch.append('\t)') # end lib_symbols

    def add_sym(lib_id, x, y, ref, val, footprint, angle=0):
        sch.append('\t(symbol')
        sch.append(f'\t\t(lib_id "{lib_id}")')
        sch.append(f'\t\t(at {x:.2f} {y:.2f} {angle})')
        sch.append('\t\t(unit 1)')
        sch.append('\t\t(exclude_from_sim no)')
        sch.append('\t\t(in_bom yes)')
        sch.append('\t\t(on_board yes)')
        sch.append('\t\t(dnp no)')
        sch.append(f'\t\t(uuid "{uid()}")')
        sch.append(f'\t\t(property "Reference" "{ref}" (at {x+2.54:.2f} {y-1.27:.2f} 0) (effects (font (size 1.27 1.27)) (justify left)))')
        sch.append(f'\t\t(property "Value" "{val}" (at {x+2.54:.2f} {y+1.27:.2f} 0) (effects (font (size 1.27 1.27)) (justify left)))')
        sch.append(f'\t\t(property "Footprint" "{footprint}" (at {x:.2f} {y:.2f} 0) (effects (font (size 1.27 1.27)) hide))')
        sch.append('\t)')

    def add_pwr(lib_id, x, y, val, ref="#PWR"):
        sch.append('\t(symbol')
        sch.append(f'\t\t(lib_id "{lib_id}")')
        sch.append(f'\t\t(at {x:.2f} {y:.2f} 0)')
        sch.append('\t\t(unit 1)')
        sch.append('\t\t(exclude_from_sim no)')
        sch.append('\t\t(in_bom yes)')
        sch.append('\t\t(on_board yes)')
        sch.append('\t\t(dnp no)')
        sch.append(f'\t\t(uuid "{uid()}")')
        sch.append(f'\t\t(property "Reference" "{ref}" (at {x:.2f} {y-3.81:.2f} 0) (effects (font (size 1.27 1.27)) hide))')
        sch.append(f'\t\t(property "Value" "{val}" (at {x:.2f} {y-2.54:.2f} 0) (effects (font (size 1.27 1.27))))')
        sch.append(f'\t\t(property "Footprint" "" (at {x:.2f} {y:.2f} 0) (effects (font (size 1.27 1.27)) hide))')
        sch.append('\t)')

    def add_wire(x1, y1, x2, y2):
        sch.append('\t(wire')
        sch.append('\t\t(pts')
        sch.append(f'\t\t\t(xy {x1:.2f} {y1:.2f})')
        sch.append(f'\t\t\t(xy {x2:.2f} {y2:.2f})')
        sch.append('\t\t)')
        sch.append('\t\t(stroke (width 0) (type solid))')
        sch.append(f'\t\t(uuid "{uid()}")')
        sch.append('\t)')

    def add_label(text, x, y, angle=0):
        sch.append(f'\t(label "{text}"')
        sch.append(f'\t\t(at {x:.2f} {y:.2f} {angle})')
        sch.append('\t\t(fields_autoplaced yes)')
        sch.append('\t\t(effects (font (size 1.27 1.27)) (justify left bottom))')
        sch.append(f'\t\t(uuid "{uid()}")')
        sch.append('\t)')

    # Section Headers
    sch.append('\t(text "1. MAINS INPUT & SURGE CLAMP (Tier 1 Protection)" (at 25.4 35.56 0) (effects (font (size 2.54 2.54) (bold yes)) (justify left bottom)) (uuid "11111111-1111-1111-1111-111111111111"))')
    sch.append('\t(text "2. POWER SUPPLY (HLK-PM01 5V + AP2112K-3.3 LDO)" (at 160.0 35.56 0) (effects (font (size 2.54 2.54) (bold yes)) (justify left bottom)) (uuid "22222222-2222-2222-2222-222222222222"))')
    sch.append('\t(text "3. MCU CORE (ESP32-C6-WROOM-1-N4 4MB Flash)" (at 25.4 100.0 0) (effects (font (size 2.54 2.54) (bold yes)) (justify left bottom)) (uuid "33333333-3333-3333-3333-333333333333"))')
    sch.append('\t(text "4. RELAYS (3X HF32F-G 10A 250VAC with RC Snubbers)" (at 160.0 100.0 0) (effects (font (size 2.54 2.54) (bold yes)) (justify left bottom)) (uuid "44444444-4444-4444-4444-444444444444"))')
    sch.append('\t(text "5. BL0942 ENERGY TELEMETRY (UART 4800 Baud)" (at 25.4 180.0 0) (effects (font (size 2.54 2.54) (bold yes)) (justify left bottom)) (uuid "55555555-5555-5555-5555-555555555555"))')
    sch.append('\t(text "6. WALL SWITCH INPUTS (RC Filter + TVS Protection)" (at 160.0 180.0 0) (effects (font (size 2.54 2.54) (bold yes)) (justify left bottom)) (uuid "66666666-6666-6666-6666-666666666666"))')

    # Universal Footprints
    FP_CONN_3P = "TerminalBlock_Phoenix:TerminalBlock_Phoenix_MKDS-1,5-3-5.08_1x03_P5.08mm_Horizontal"
    FP_CONN_2P = "TerminalBlock_Phoenix:TerminalBlock_Phoenix_MKDS-1,5-2_1x02_P5.00mm_Horizontal"
    FP_R_0603 = "Resistor_SMD:R_0603_1608Metric"
    FP_R_1206 = "Resistor_SMD:R_1206_3216Metric"
    FP_R_2512 = "Resistor_SMD:R_2512_6332Metric"
    FP_C_0603 = "Capacitor_SMD:C_0603_1608Metric"
    FP_C_ELEC = "Capacitor_SMD:CP_Elec_6.3x5.8"
    FP_C_RADIAL = "Capacitor_THT:CP_Radial_D6.3mm_P2.50mm"
    FP_D_SOD123 = "Diode_SMD:D_SOD-123"
    FP_D_SOD523 = "Diode_SMD:D_SOD-523"
    FP_LED = "LED_SMD:LED_0603_1608Metric"
    FP_SOT23 = "Package_TO_SOT_SMD:SOT-23"
    FP_SOT23_5 = "Package_TO_SOT_SMD:SOT-23-5"
    FP_SOIC14 = "Package_SO:SOIC-14_3.9x8.7mm_P1.27mm"
    FP_ESP32 = "RF_Module:ESP32-WROOM-32"
    FP_RELAY = "Relay_THT:Relay_SPST_Finder_32.21"
    FP_HLK = "Package_DIP:DIP-4_W7.62mm"
    FP_FUSE = "Fuse:Fuse_1206_3216Metric"
    FP_MOV = "Resistor_SMD:R_1206_3216Metric"
    FP_NTC = "Resistor_SMD:R_1206_3216Metric"
    FP_BOX_CAP = "Capacitor_SMD:C_1206_3216Metric"

    # Block 1: Mains Protection
    add_sym("Connector:Conn_01x03", 35.0, 55.0, "J1", "MAINS_IN", FP_CONN_3P)
    add_label("MAINS_LIVE", 40.08, 52.46)
    add_label("MAINS_NEUTRAL", 40.08, 55.0)
    add_label("EARTH_GND", 40.08, 57.54)

    add_sym("Device:Fuse", 60.0, 52.46, "F1", "2A_250V", FP_FUSE, 0)
    add_wire(40.08, 52.46, 56.19, 52.46)
    add_sym("Device:Varistor", 80.0, 55.0, "MOV1", "14D561K", FP_MOV, 0)
    add_wire(63.81, 52.46, 80.0, 52.46)
    add_wire(80.0, 52.46, 80.0, 51.19)
    add_wire(80.0, 58.81, 80.0, 60.0)
    add_wire(40.08, 55.0, 40.08, 60.0)
    add_wire(40.08, 60.0, 80.0, 60.0)

    add_sym("Device:R", 100.0, 52.46, "NTC1", "10D-9", FP_NTC, 90)
    add_wire(80.0, 52.46, 96.19, 52.46)
    add_sym("Device:C", 115.0, 55.0, "CX1", "0.1uF_275V_X2", FP_BOX_CAP, 0)
    add_wire(103.81, 52.46, 115.0, 52.46)
    add_wire(115.0, 52.46, 115.0, 51.19)
    add_wire(115.0, 58.81, 115.0, 60.0)
    add_wire(80.0, 60.0, 115.0, 60.0)

    add_label("AC_L_FILTERED", 125.0, 52.46)
    add_wire(115.0, 52.46, 125.0, 52.46)
    add_label("AC_N_FILTERED", 125.0, 60.0)
    add_wire(115.0, 60.0, 125.0, 60.0)

    # Block 2: Power Supply
    add_sym("Power_Supply:HLK-PM01", 185.0, 55.0, "U2", "HLK-PM01_5V", FP_HLK)
    add_label("AC_L_FILTERED", 172.3, 49.92, 180)
    add_label("AC_N_FILTERED", 172.3, 60.08, 180)
    add_pwr("power:+5V", 205.0, 49.92, "+5V")
    add_wire(197.7, 49.92, 205.0, 49.92)
    add_pwr("power:GND", 205.0, 60.08, "GND")
    add_wire(197.7, 60.08, 205.0, 60.08)

    add_sym("Device:C_Polarized", 215.0, 55.0, "C1", "470uF_16V", FP_C_RADIAL, 0)
    add_wire(205.0, 49.92, 215.0, 49.92)
    add_wire(215.0, 49.92, 215.0, 51.19)
    add_wire(205.0, 60.08, 215.0, 60.08)
    add_wire(215.0, 60.08, 215.0, 58.81)

    add_sym("Regulator_Linear:AP2112K-3.3", 240.0, 55.0, "U3", "AP2112K-3.3", FP_SOT23_5)
    add_wire(215.0, 49.92, 229.84, 52.46)
    add_wire(229.84, 52.46, 229.84, 57.54)
    add_pwr("power:GND", 240.0, 65.0, "GND")
    add_wire(240.0, 62.62, 240.0, 65.0)

    add_sym("Device:C_Polarized", 260.0, 55.0, "C2", "100uF_10V", FP_C_ELEC, 0)
    add_wire(250.16, 52.46, 260.0, 52.46)
    add_wire(260.0, 52.46, 260.0, 51.19)
    add_wire(260.0, 60.0, 260.0, 58.81)
    add_pwr("power:GND", 260.0, 65.0, "GND")
    add_wire(260.0, 60.0, 260.0, 65.0)
    add_pwr("power:+3V3", 270.0, 52.46, "+3V3")
    add_wire(260.0, 52.46, 270.0, 52.46)

    # Block 3: MCU Core
    add_sym("RF_Module:ESP32-C6-WROOM-1", 65.0, 135.0, "U1", "ESP32-C6-WROOM-1-N4", FP_ESP32)
    add_pwr("power:+3V3", 49.76, 119.76, "+3V3")
    add_pwr("power:GND", 65.0, 165.0, "GND")
    add_wire(65.0, 160.4, 65.0, 165.0)

    # MCU Reset Circuit
    add_sym("Device:R", 38.0, 124.84, "R_EN2", "10k", FP_R_0603, 0)
    add_pwr("power:+3V3", 38.0, 118.0, "+3V3")
    add_wire(38.0, 121.03, 49.76, 124.84)
    add_sym("Device:C", 38.0, 135.0, "C_EN2", "1uF", FP_C_0603, 0)
    add_wire(38.0, 128.65, 49.76, 124.84)
    add_wire(38.0, 131.19, 49.76, 124.84)
    add_pwr("power:GND", 38.0, 142.0, "GND")
    add_wire(38.0, 138.81, 38.0, 142.0)

    # Switch Inputs & Telemetry to MCU
    add_label("SW_IN_1", 49.76, 129.92, 180)
    add_label("SW_IN_2", 49.76, 135.0, 180)
    add_label("SW_IN_3", 49.76, 140.08, 180)
    add_label("BL0942_TX_OUT", 49.76, 145.16, 180)
    add_label("STATUS_LED", 49.76, 150.24, 180)
    add_label("BOOT_BTN", 49.76, 155.32, 180)

    # Relay Outputs from MCU
    add_label("RELAY_DRV_1", 80.24, 124.84)
    add_label("RELAY_DRV_2", 80.24, 129.92)
    add_label("RELAY_DRV_3", 80.24, 135.0)
    add_label("FACTORY_TX0", 80.24, 145.16)
    add_label("FACTORY_RX0", 80.24, 150.24)

    # Status LED & Boot Switch Circuit
    add_sym("Device:R", 100.0, 150.24, "R_LED2", "1k", FP_R_0603, 90)
    add_label("STATUS_LED", 93.0, 150.24, 180)
    add_wire(93.0, 150.24, 96.19, 150.24)
    add_sym("Device:LED", 112.0, 150.24, "LED1", "BLUE_0603", FP_LED, 0)
    add_wire(103.81, 150.24, 108.19, 150.24)
    add_pwr("power:GND", 120.0, 150.24, "GND")
    add_wire(115.81, 150.24, 120.0, 150.24)

    # Block 4: Relays 1, 2, 3
    y_relays = [120.0, 145.0, 170.0]
    for i, y_pos in enumerate(y_relays):
        ch = i + 1
        add_sym("Device:Q_NMOS_GSD", 185.0, y_pos, f"Q{ch}", "AO3400A", FP_SOT23)
        add_label(f"RELAY_DRV_{ch}", 170.0, y_pos, 180)
        add_sym("Device:R", 175.0, y_pos, f"RG{ch}", "1k", FP_R_0603, 90)
        add_wire(170.0, y_pos, 171.19, y_pos)
        add_wire(178.81, y_pos, 179.92, y_pos)
        add_sym("Device:R", 179.92, y_pos+6.0, f"RPD{ch}", "10k", FP_R_0603, 0)
        add_wire(179.92, y_pos, 179.92, y_pos+2.19)
        add_pwr("power:GND", 179.92, y_pos+12.0, "GND")
        add_wire(179.92, y_pos+9.81, 179.92, y_pos+12.0)
        add_pwr("power:GND", 187.54, y_pos+7.62, "GND")
        add_wire(187.54, y_pos+5.08, 187.54, y_pos+7.62)

        # Relay & Flyback Diode
        add_sym("Relay:HF32F-G", 215.0, y_pos, f"K{ch}", "HF32F-G_10A", FP_RELAY)
        add_wire(187.54, y_pos-5.08, 207.38, y_pos+2.54)
        add_pwr("power:+5V", 207.38, y_pos-7.62, "+5V")
        add_wire(207.38, y_pos-2.54, 207.38, y_pos-7.62)
        add_sym("Device:D_Schottky", 200.0, y_pos, f"D{ch}", "SS14", FP_D_SOD123, 90)
        add_wire(207.38, y_pos-2.54, 200.0, y_pos-3.81)
        add_wire(207.38, y_pos+2.54, 200.0, y_pos+3.81)

        # Snubber
        add_sym("Device:R", 235.0, y_pos-2.54, f"RS{ch}", "100_1W", FP_R_2512, 90)
        add_sym("Device:C", 248.0, y_pos-2.54, f"CS{ch}", "100nF_630V", FP_BOX_CAP, 90)
        add_wire(222.62, y_pos-2.54, 231.19, y_pos-2.54)
        add_wire(238.81, y_pos-2.54, 244.19, y_pos-2.54)
        add_wire(251.81, y_pos-2.54, 255.0, y_pos-2.54)
        add_wire(222.62, y_pos+2.54, 255.0, y_pos+2.54)
        add_wire(255.0, y_pos-2.54, 255.0, y_pos+2.54)

        add_label("MAINS_LIVE", 222.62, y_pos-2.54)
        add_label(f"LOAD_CH{ch}", 222.62, y_pos+2.54)

    # Block 5: BL0942 Telemetry
    add_sym("Sensor_Energy:BL0942", 65.0, 215.0, "U4", "BL0942_SOP14", FP_SOIC14)
    add_pwr("power:+3V3", 52.3, 207.38, "+3V3")
    add_pwr("power:GND", 65.0, 235.0, "GND")
    add_wire(65.0, 227.7, 65.0, 235.0)
    add_label("BL0942_TX_OUT", 77.7, 212.46)

    # Shunt & Voltage Dividers
    add_sym("Device:R", 30.0, 212.46, "R_SHUNT2", "1mOhm_2W_1%", FP_R_2512, 0)
    add_label("MAINS_NEUTRAL", 30.0, 206.0, 90)
    add_wire(30.0, 206.0, 30.0, 208.65)
    add_label("NEUTRAL_LOAD", 30.0, 220.0, 270)
    add_wire(30.0, 216.27, 30.0, 220.0)
    add_wire(30.0, 208.65, 52.3, 212.46)
    add_wire(30.0, 216.27, 52.3, 217.54)

    add_sym("Device:R", 38.0, 222.62, "RHV1", "960k_HV", FP_R_1206, 90)
    add_label("MAINS_LIVE", 25.0, 222.62, 180)
    add_wire(25.0, 222.62, 34.19, 222.62)
    add_wire(41.81, 222.62, 52.3, 222.62)

    # Block 6: Wall Switch Inputs
    y_sw = [200.0, 218.0, 236.0]
    for i, y_pos in enumerate(y_sw):
        ch = i + 1
        add_sym("Connector:Conn_01x02", 170.0, y_pos, f"J_SW{ch}", f"WALL_SW_{ch}", FP_CONN_2P)
        add_label(f"SW_IN_{ch}", 225.0, y_pos)
        add_sym("Device:R", 185.0, y_pos, f"RSW{ch}", "1k", FP_R_0603, 90)
        add_wire(175.08, y_pos, 181.19, y_pos)
        add_wire(188.81, y_pos, 225.0, y_pos)
        
        # Pull-Up
        add_sym("Device:R", 195.0, y_pos-6.0, f"RPU{ch}", "10k", FP_R_0603, 0)
        add_wire(195.0, y_pos, 195.0, y_pos-2.19)
        add_pwr("power:+3V3", 195.0, y_pos-12.0, "+3V3")
        add_wire(195.0, y_pos-9.81, 195.0, y_pos-12.0)

        # Cap & TVS to GND
        add_sym("Device:C", 205.0, y_pos+6.0, f"CSW{ch}", "100nF", FP_C_0603, 0)
        add_wire(205.0, y_pos, 205.0, y_pos+2.19)
        add_pwr("power:GND", 205.0, y_pos+12.0, "GND")
        add_wire(205.0, y_pos+9.81, 205.0, y_pos+12.0)

        add_sym("Device:D_Schottky", 215.0, y_pos+6.0, f"TVS{ch}", "ESD5Z3.3", FP_D_SOD523, 270)
        add_wire(215.0, y_pos, 215.0, y_pos+2.19)
        add_pwr("power:GND", 215.0, y_pos+12.0, "GND")
        add_wire(215.0, y_pos+9.81, 215.0, y_pos+12.0)

    sch.append('\t(sheet_instances')
    sch.append('\t\t(path "/" (page "1"))')
    sch.append('\t)')
    sch.append(')')

    with open(r"c:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\hardware\kicad\smart_switch_3x\smart_switch_3x.kicad_sch", "w", encoding="utf-8") as f:
        f.write('\n'.join(sch))
    print("Generated 100% standard footprint-mapped smart_switch_3x.kicad_sch!")

if __name__ == "__main__":
    generate_schematic()
