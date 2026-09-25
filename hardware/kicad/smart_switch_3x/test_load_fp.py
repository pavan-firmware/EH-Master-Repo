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

    # Parse and adjust footprint
    # Replace (footprint "..." with (footprint "...:..." (layer "F.Cu") (at x y rot) (uuid "...")
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
    # Pad pattern in KiCad: (pad "1" ... (layers ...))
    # We inject (net N "NETNAME") before closing pad paren
    def add_net_to_pad(match):
        pad_num = match.group(1)
        pad_body = match.group(0)
        if pad_num in pad_nets:
            net_id, net_name = pad_nets[pad_num]
            net_str = f' (net {net_id} "{net_name}")'
            # Insert before last closing paren
            if pad_body.endswith(')'):
                return pad_body[:-1] + net_str + ')'
        return pad_body

    pad_regex = re.compile(r'\(pad\s+"([^"]+)"[^\)]+\)', re.DOTALL)
    # Also handle multi-line pad definitions
    lines = content.splitlines()
    out_lines = []
    in_pad = False
    cur_pad_num = None
    pad_buffer = []

    for line in lines:
        if line.strip().startswith('(pad '):
            in_pad = True
            # extract pad number
            m = re.search(r'\(pad\s+"([^"]+)"', line)
            if m:
                cur_pad_num = m.group(1)
            pad_buffer = [line]
            if line.strip().endswith(')') and line.count('(') == line.count(')'):
                # single line pad
                in_pad = False
                if cur_pad_num in pad_nets:
                    n_id, n_nm = pad_nets[cur_pad_num]
                    line = line[:-1] + f' (net {n_id} "{n_nm}"))'
                out_lines.append(line)
        elif in_pad:
            pad_buffer.append(line)
            # check if pad closing
            total_open = sum(l.count('(') for l in pad_buffer)
            total_close = sum(l.count(')') for l in pad_buffer)
            if total_open == total_close:
                in_pad = False
                if cur_pad_num in pad_nets:
                    n_id, n_nm = pad_nets[cur_pad_num]
                    # inject net before closing paren
                    last_l = pad_buffer[-1]
                    idx = last_l.rfind(')')
                    if idx != -1:
                        pad_buffer[-1] = last_l[:idx] + f'\n\t\t(net {n_id} "{n_nm}")' + last_l[idx:]
                out_lines.extend(pad_buffer)
        else:
            out_lines.append(line)

    return "\n".join(out_lines)

print("Helper load_official_footprint defined.")
