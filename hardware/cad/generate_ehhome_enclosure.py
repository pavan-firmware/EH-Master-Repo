"""
EH Home Smart Switch 3X - Precision Production Enclosure Generator V2
Faithfully matches the reference product image:
- Top detachable LED strip with side snap tabs and 5 LED pinholes
- Top U-notch cutout extending to the top edge for the detachable strip
- Compact, properly proportioned 9-terminal screw block bay (5.6mm height, 3.4mm x 5.6mm pockets)
- Fully enclosed bottom base with flush regulatory label pocket and 9 wire entry ports
- Production-grade tool-less snap-fit assembly & interlocking alignment lip
"""

import os
import math
import FreeCAD
import Part
from FreeCAD import Vector

def make_rounded_prism(dx, dy, dz, r):
    """Creates a solid prism of size (dx, dy, dz) with 4 rounded vertical corners of radius r."""
    r = max(0.2, min(r, dx/2.01, dy/2.01))
    p1 = Vector(0, r, 0)
    p2 = Vector(r, 0, 0)
    p3 = Vector(dx - r, 0, 0)
    p4 = Vector(dx, r, 0)
    p5 = Vector(dx, dy - r, 0)
    p6 = Vector(dx - r, dy, 0)
    p7 = Vector(r, dy, 0)
    p8 = Vector(0, dy - r, 0)

    diag = r * math.sin(math.pi/4)
    a1 = Part.Arc(p1, Vector(r - diag, r - diag, 0), p2).toShape()
    l1 = Part.makeLine(p2, p3)
    a2 = Part.Arc(p3, Vector(dx - r + diag, r - diag, 0), p4).toShape()
    l2 = Part.makeLine(p4, p5)
    a3 = Part.Arc(p5, Vector(dx - r + diag, dy - r + diag, 0), p6).toShape()
    l3 = Part.makeLine(p6, p7)
    a4 = Part.Arc(p7, Vector(r - diag, dy - r + diag, 0), p8).toShape()
    l4 = Part.makeLine(p8, p1)

    wire = Part.Wire([a1, l1, a2, l2, a3, l3, a4, l4])
    face = Part.Face(wire)
    return face.extrude(Vector(0, 0, dz))

def make_snap_bead(thick, width, height, direction='outward_left'):
    """Creates a cantilever snap catch lug with entry lead-in ramp and retention undercut."""
    if direction == 'outward_left':
        pts = [
            Vector(0, 0, 0),
            Vector(-thick, 0, height * 0.4),
            Vector(-thick, 0, height),
            Vector(0, 0, height),
            Vector(0, 0, 0)
        ]
    else:
        pts = [
            Vector(0, 0, 0),
            Vector(thick, 0, height * 0.4),
            Vector(thick, 0, height),
            Vector(0, 0, height),
            Vector(0, 0, 0)
        ]
    poly = Part.makePolygon(pts)
    face = Part.Face(poly)
    return face.extrude(Vector(0, width, 0))

# -------------------------------------------------------------
# GLOBAL PARAMETERS (Matching Reference Photo)
# -------------------------------------------------------------
CASE_W = 45.0          # Width
CASE_H = 43.0          # Height (aspect ratio matching photo)
TOP_D  = 7.0           # Top shell depth
BASE_D = 13.0          # Bottom base depth
TOTAL_D = TOP_D + BASE_D # 20.0 mm total depth
WALL_T = 1.8           # Wall thickness (Flame-retardant PC/ABS)
CORNER_R = 3.8         # Outer corner fillet radius

# Terminal Block Dimensions (Compact 9-terminal bay)
TB_W = 37.0            # Total span across 9 terminals
TB_H = 5.6             # Compact height (just framing the screw cages!)
TB_X = (CASE_W - TB_W) / 2.0 # 4.0 mm
TB_Y = 3.8             # Distance from bottom edge
TB_PITCH = TB_W / 9.0  # ~4.11 mm
RIB_T = 0.8            # Divider rib thickness

# Top Detachable LED Strip Dimensions
STRIP_W = 30.6         # Width of strip
STRIP_H = 6.6          # Height of strip
STRIP_D = 2.2          # Thickness of detachable strip
STRIP_R = 1.5          # Corner radius
STRIP_X = (CASE_W - STRIP_W) / 2.0 # 7.2 mm
STRIP_Y = CASE_H - STRIP_H - 1.2   # Positioned close to top edge

def build_top_cover():
    """Builds the Top Cover (Front Shell) matching Image 1."""
    # 1. Main outer solid
    top_outer = make_rounded_prism(CASE_W, CASE_H, TOP_D, CORNER_R)

    # 2. Hollow out inside cavity (leaving 1.8mm walls and 1.8mm front face)
    cav_w = CASE_W - 2*WALL_T
    cav_h = CASE_H - 2*WALL_T
    cav_d = TOP_D - WALL_T
    cav_r = max(0.5, CORNER_R - WALL_T)
    cavity = make_rounded_prism(cav_w, cav_h, cav_d + 1.0, cav_r)
    cavity.translate(Vector(WALL_T, WALL_T, -0.5))
    top_shell = top_outer.cut(cavity)

    # 3. Top Cutout / Bay for the Detachable LED Strip (Extends near top edge with hinge/snap pockets)
    recess_w = STRIP_W + 0.4 # 0.2mm clearance per side
    recess_h = STRIP_H + 0.4
    recess_x = (CASE_W - recess_w) / 2.0
    recess_y = STRIP_Y - 0.2

    strip_bay = make_rounded_prism(recess_w, recess_h, STRIP_D + 0.2, STRIP_R)
    strip_bay.translate(Vector(recess_x, recess_y, TOP_D - STRIP_D))
    top_shell = top_shell.cut(strip_bay)

    # Top notch opening extending to the top edge (as seen in photo)
    top_notch = Part.makeBox(STRIP_W - 2.0, CASE_H - (recess_y + recess_h) + 1.0, STRIP_D + 0.2)
    top_notch.translate(Vector(recess_x + 1.0, recess_y + recess_h - 0.2, TOP_D - STRIP_D))
    top_shell = top_shell.cut(top_notch)

    # Left & Right side snap-latch pockets for the detachable strip
    latch_w = 1.4
    latch_h = 2.6
    latch_d = STRIP_D + 0.2
    pocket_l = Part.makeBox(latch_w, latch_h, latch_d)
    pocket_l.translate(Vector(recess_x - latch_w + 0.2, recess_y + (recess_h - latch_h)/2, TOP_D - STRIP_D))
    pocket_r = Part.makeBox(latch_w, latch_h, latch_d)
    pocket_r.translate(Vector(recess_x + recess_w - 0.2, recess_y + (recess_h - latch_h)/2, TOP_D - STRIP_D))
    top_shell = top_shell.cut(pocket_l)
    top_shell = top_shell.cut(pocket_r)

    # 5 Pass-through holes through the back wall of the bay so light from PCB reaches the strip
    led_xs = [STRIP_X + 3.3 + i * 6.0 for i in range(5)]
    led_y = STRIP_Y + STRIP_H / 2.0
    for lx in led_xs:
        pass_hole = Part.makeCylinder(1.2, WALL_T + 1.0)
        pass_hole.translate(Vector(lx, led_y, TOP_D - WALL_T - 0.5))
        top_shell = top_shell.cut(pass_hole)

    # 4. Terminal Block Bay (Compact: 5.6mm height, 37mm width)
    tb_window = Part.makeBox(TB_W, TB_H, WALL_T + 0.5)
    tb_window.translate(Vector(TB_X, TB_Y, TOP_D - WALL_T))
    top_shell = top_shell.cut(tb_window)

    # Add 8 Isolation Divider Ribs (creates 9 distinct screw chambers)
    for i in range(1, 9):
        rx = TB_X + i * TB_PITCH - (RIB_T / 2.0)
        rib = Part.makeBox(RIB_T, TB_H, WALL_T)
        rib.translate(Vector(rx, TB_Y, TOP_D - WALL_T))
        top_shell = top_shell.fuse(rib)

    # 5. Continuous Stepped Alignment Tongue (Interlocking perimeter seam)
    step_inset = 0.9
    step_thick = 0.9
    step_h = 1.2
    step_outer = make_rounded_prism(CASE_W - 2*step_inset, CASE_H - 2*step_inset, step_h, max(0.5, CORNER_R - step_inset))
    step_outer.translate(Vector(step_inset, step_inset, -step_h))
    step_cav = make_rounded_prism(CASE_W - 2*(step_inset + step_thick), CASE_H - 2*(step_inset + step_thick), step_h + 1.0, max(0.5, CORNER_R - step_inset - step_thick))
    step_cav.translate(Vector(step_inset + step_thick, step_inset + step_thick, -step_h - 0.5))
    step_rim = step_outer.cut(step_cav)
    top_shell = top_shell.fuse(step_rim)

    # 6. Snap-fit female catch pockets (2 left, 2 right)
    for side_x in [WALL_T - 0.1, CASE_W - WALL_T - 0.7]:
        for y_pos in [14.0, 28.0]:
            sp = Part.makeBox(0.8, 3.4, 1.6)
            sp.translate(Vector(side_x, y_pos, 0.8))
            top_shell = top_shell.cut(sp)

    return top_shell

def build_detachable_led_strip():
    """Builds the separate Detachable Top LED Strip matching the photo."""
    # Outer body of strip
    strip = make_rounded_prism(STRIP_W, STRIP_H, STRIP_D, STRIP_R)

    # Side retention/pivot snap ears (Left & Right)
    ear_w = 1.2
    ear_h = 2.4
    ear_d = STRIP_D - 0.4
    ear_l = Part.makeBox(ear_w, ear_h, ear_d)
    ear_l.translate(Vector(-ear_w, (STRIP_H - ear_h)/2.0, 0.2))
    ear_r = Part.makeBox(ear_w, ear_h, ear_d)
    ear_r.translate(Vector(STRIP_W, (STRIP_H - ear_h)/2.0, 0.2))
    strip = strip.fuse(ear_l).fuse(ear_r)

    # 5 LED Pinhole apertures (matching PWR, STAT, CH1, CH2, CH3)
    led_spacing = 6.0
    start_x = 3.3
    for i in range(5):
        lx = start_x + i * led_spacing
        hole = Part.makeCylinder(0.55, STRIP_D + 1.0)
        hole.translate(Vector(lx, STRIP_H / 2.0, -0.5))
        strip = strip.cut(hole)

    # Position the strip exactly in the Top Cover's bay
    strip.translate(Vector(STRIP_X, STRIP_Y, TOP_D - STRIP_D))
    return strip

def build_bottom_base():
    """Builds the Bottom Base (Back Enclosure) complete with rear features."""
    # 1. Main outer body
    base_outer = make_rounded_prism(CASE_W, CASE_H, BASE_D, CORNER_R)

    # 2. Hollow out inside cavity
    cav_w = CASE_W - 2*WALL_T
    cav_h = CASE_H - 2*WALL_T
    cav_d = BASE_D - WALL_T
    cav_r = max(0.5, CORNER_R - WALL_T)
    cavity = make_rounded_prism(cav_w, cav_h, cav_d + 1.0, cav_r)
    cavity.translate(Vector(WALL_T, WALL_T, WALL_T))
    bottom_base = base_outer.cut(cavity)

    # 3. Exterior Back Plate: Recessed Regulatory & Specs Label Pocket (0.4mm deep)
    label_w = 33.0
    label_h = 23.0
    label_d = 0.4
    label_r = 2.0
    label_x = (CASE_W - label_w) / 2.0
    label_y = 14.0
    label_cut = make_rounded_prism(label_w, label_h, label_d + 0.2, label_r)
    label_cut.translate(Vector(label_x, label_y, -0.1))
    bottom_base = bottom_base.cut(label_cut)

    # 4. 9 Wire Entry Funnels on bottom face (Y = 0 face, aligned with terminals)
    wire_z = 5.0
    for i in range(9):
        wx = TB_X + (i + 0.5) * TB_PITCH
        # 3.2mm diameter wire hole
        hole = Part.makeCylinder(1.6, WALL_T + 1.0, Vector(wx, -0.5, wire_z), Vector(0, 1, 0))
        bottom_base = bottom_base.cut(hole)
        # Lead-in funnel chamfer
        funnel = Part.makeCone(2.2, 1.6, 1.0, Vector(wx, -0.1, wire_z), Vector(0, 1, 0))
        bottom_base = bottom_base.cut(funnel)

    # 5. Internal PCB Standoffs (4 corners at Z = WALL_T, height = 2.5mm)
    standoff_h = 2.5
    so_size = 4.0
    so_positions = [
        Vector(WALL_T, WALL_T, WALL_T),
        Vector(CASE_W - WALL_T - so_size, WALL_T, WALL_T),
        Vector(CASE_W - WALL_T - so_size, CASE_H - WALL_T - so_size, WALL_T),
        Vector(WALL_T, CASE_H - WALL_T - so_size, WALL_T)
    ]
    for pos in so_positions:
        so = Part.makeBox(so_size, so_size, standoff_h)
        so.translate(pos)
        bottom_base = bottom_base.fuse(so)

    # Diagonal PCB locating guide pins
    pin1 = Part.makeCylinder(0.9, 1.5, Vector(WALL_T + so_size/2, WALL_T + so_size/2, WALL_T + standoff_h), Vector(0, 0, 1))
    pin2 = Part.makeCylinder(0.9, 1.5, Vector(CASE_W - WALL_T - so_size/2, CASE_H - WALL_T - so_size/2, WALL_T + standoff_h), Vector(0, 0, 1))
    bottom_base = bottom_base.fuse(pin1).fuse(pin2)

    # 6. Terminal Block Anti-Flex Support Ledge (Prevents PCB stress when tightening screws)
    tb_ledge = Part.makeBox(TB_W, 6.0, standoff_h)
    tb_ledge.translate(Vector(TB_X, WALL_T, WALL_T))
    bottom_base = bottom_base.fuse(tb_ledge)

    # 7. High-Voltage Creepage Barrier (Isolates Mains AC from low-voltage MCU)
    iso_barrier = Part.makeBox(1.2, 20.0, 5.0)
    iso_barrier.translate(Vector(26.0, 12.0, WALL_T))
    bottom_base = bottom_base.fuse(iso_barrier)

    # 8. Perimeter Mating Groove (receives top shell tongue with 0.15mm tolerance)
    groove_inset = 0.9 - 0.15
    groove_thick = 0.9 + 0.30
    groove_depth = 1.3
    gr_out = make_rounded_prism(CASE_W - 2*groove_inset, CASE_H - 2*groove_inset, groove_depth + 0.1, max(0.5, CORNER_R - groove_inset))
    gr_out.translate(Vector(groove_inset, groove_inset, BASE_D - groove_depth))
    gr_in = make_rounded_prism(CASE_W - 2*(groove_inset + groove_thick), CASE_H - 2*(groove_inset + groove_thick), groove_depth + 0.5, max(0.5, CORNER_R - groove_inset - groove_thick))
    gr_in.translate(Vector(groove_inset + groove_thick, groove_inset + groove_thick, BASE_D - groove_depth - 0.2))
    groove = gr_out.cut(gr_in)
    bottom_base = bottom_base.cut(groove)

    # 9. Cantilever Snap-Fit Arms (2 on left, 2 on right)
    for side in ['left', 'right']:
        for y_pos in [14.0, 28.0]:
            if side == 'left':
                sx = WALL_T
                snap_arm = Part.makeBox(1.1, 3.2, 4.0)
                snap_arm.translate(Vector(sx, y_pos, BASE_D - 2.5))
                bead = make_snap_bead(0.65, 3.2, 1.4, 'outward_left')
                bead.translate(Vector(sx, y_pos, BASE_D - 1.0))
                bottom_base = bottom_base.fuse(snap_arm).fuse(bead)
            else:
                sx = CASE_W - WALL_T - 1.1
                snap_arm = Part.makeBox(1.1, 3.2, 4.0)
                snap_arm.translate(Vector(sx, y_pos, BASE_D - 2.5))
                bead = make_snap_bead(0.65, 3.2, 1.4, 'outward_right')
                bead.translate(Vector(sx + 1.1, y_pos, BASE_D - 1.0))
                bottom_base = bottom_base.fuse(snap_arm).fuse(bead)

    # 10. Anti-slip Side Grip Ribs
    for side_x in [0.0, CASE_W - 0.5]:
        for y_pos in [17.0, 22.0, 27.0]:
            grip = Part.makeBox(0.5, 3.5, BASE_D - 4.0)
            grip.translate(Vector(side_x, y_pos, 2.0))
            bottom_base = bottom_base.fuse(grip)

    return bottom_base

def main():
    print("="*60)
    print("EH Home Smart Switch 3X - Precision V2 Generation Starting...")
    print("="*60)

    out_dir = r"c:\Users\pavan\Downloads\Flutter\SMART_HOME_V1\hardware\cad"
    os.makedirs(out_dir, exist_ok=True)

    doc_name = "EH_Home_Smart_Switch_3X"
    doc = FreeCAD.newDocument(doc_name)

    print("1. Generating Top Cover (Front Shell)...")
    top_shape = build_top_cover()
    print("   Top Cover Solid Valid:", top_shape.isValid(), "Volume:", f"{top_shape.Volume:.2f} mm3")
    top_obj = doc.addObject("Part::Feature", "Top_Cover")
    top_obj.Shape = top_shape
    top_obj.Placement.Base = Vector(0, 0, BASE_D)

    print("2. Generating Detachable Top LED Strip...")
    strip_shape = build_detachable_led_strip()
    print("   LED Strip Solid Valid:", strip_shape.isValid(), "Volume:", f"{strip_shape.Volume:.2f} mm3")
    strip_obj = doc.addObject("Part::Feature", "Detachable_LED_Strip")
    strip_obj.Shape = strip_shape
    strip_obj.Placement.Base = Vector(0, 0, BASE_D)

    print("3. Generating Bottom Base (Back Enclosure)...")
    base_shape = build_bottom_base()
    print("   Bottom Base Solid Valid:", base_shape.isValid(), "Volume:", f"{base_shape.Volume:.2f} mm3")
    base_obj = doc.addObject("Part::Feature", "Bottom_Base")
    base_obj.Shape = base_shape

    doc.recompute()

    # Save native .FCStd document
    fcstd_path = os.path.join(out_dir, "EH_Home_Smart_Switch_3X.FCStd")
    doc.saveAs(fcstd_path)
    print(f" Saved FreeCAD Document: {fcstd_path}")

    # Export individual STEP & STL files
    top_step = os.path.join(out_dir, "EH_Home_Top_Cover.step")
    top_shape.exportStep(top_step)

    strip_step = os.path.join(out_dir, "EH_Home_Detachable_LED_Strip.step")
    strip_shape.exportStep(strip_step)

    base_step = os.path.join(out_dir, "EH_Home_Bottom_Base.step")
    base_shape.exportStep(base_step)

    import Mesh
    top_stl = os.path.join(out_dir, "EH_Home_Top_Cover.stl")
    Mesh.export([top_obj], top_stl)

    strip_stl = os.path.join(out_dir, "EH_Home_Detachable_LED_Strip.stl")
    Mesh.export([strip_obj], strip_stl)

    base_stl = os.path.join(out_dir, "EH_Home_Bottom_Base.stl")
    Mesh.export([base_obj], base_stl)

    # Full Assembly STEP & STL
    assy_step = os.path.join(out_dir, "EH_Home_Full_Assembly.step")
    top_placed = top_obj.Shape.copy()
    top_placed.Placement = top_obj.Placement
    strip_placed = strip_obj.Shape.copy()
    strip_placed.Placement = strip_obj.Placement
    base_placed = base_obj.Shape.copy()
    base_placed.Placement = base_obj.Placement

    assy_compound = Part.makeCompound([top_placed, base_placed, strip_placed])
    assy_compound.exportStep(assy_step)
    print(f" Exported Full Assembly STEP: {assy_step}")

    assy_stl = os.path.join(out_dir, "EH_Home_Full_Assembly.stl")
    Mesh.export([top_obj, base_obj, strip_obj], assy_stl)
    print(f" Exported Full Assembly STL: {assy_stl}")

    print("="*60)
    print("V2 Precision Models successfully generated!")
    print("="*60)

if __name__ == "__main__":
    main()
