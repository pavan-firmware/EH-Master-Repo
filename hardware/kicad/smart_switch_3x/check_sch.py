with open(r'c:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\hardware\kicad\smart_switch_3x\smart_switch_3x.kicad_sch', 'r', encoding='utf-8') as f:
    lines = f.readlines()

cur_ref = ''
cur_val = ''
for line in lines:
    if 'property "Reference"' in line:
        parts = line.split('"')
        if len(parts) >= 4:
            cur_ref = parts[3]
    elif 'property "Value"' in line:
        parts = line.split('"')
        if len(parts) >= 4:
            cur_val = parts[3]
    elif 'property "Footprint"' in line:
        parts = line.split('"')
        if len(parts) >= 4:
            fp = parts[3]
            if cur_ref:
                print(f'{cur_ref:10} | {cur_val:20} | {fp}')
                cur_ref = ''
