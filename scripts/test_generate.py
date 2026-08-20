import gmsh
import subprocess
import pandas as pd
import os
import csv

def generate_elliptical_mesh(crown_depth, a, b, filename):
    gmsh.initialize()
    gmsh.option.setNumber("General.Terminal", 0)
    gmsh.option.setNumber("Mesh.MshFileVersion", 2.2) 
    gmsh.model.add("utilidor_model")

    lc_wall = 0.05  # Increased mesh density for high precision
    lc_boundary = 1.0

    dist_h = 11.0 * a
    dist_v = 11.0 * b
    y_center = -(crown_depth + b)
    
    # 1. Geometry
    p_center = gmsh.model.geo.addPoint(0, y_center, 0, lc_wall)
    p_right  = gmsh.model.geo.addPoint(a, y_center, 0, lc_wall)
    p_top    = gmsh.model.geo.addPoint(0, y_center + b, 0, lc_wall)
    p_left   = gmsh.model.geo.addPoint(-a, y_center, 0, lc_wall)
    p_bottom = gmsh.model.geo.addPoint(0, y_center - b, 0, lc_wall)

    arc1 = gmsh.model.geo.addEllipseArc(p_right, p_center, p_right, p_top)
    arc2 = gmsh.model.geo.addEllipseArc(p_top, p_center, p_left, p_left)
    arc3 = gmsh.model.geo.addEllipseArc(p_left, p_center, p_left, p_bottom)
    arc4 = gmsh.model.geo.addEllipseArc(p_bottom, p_center, p_right, p_right)
    tunnel_loop = gmsh.model.geo.addCurveLoop([arc1, arc2, arc3, arc4])

    p_bl = gmsh.model.geo.addPoint(-dist_h, y_center - dist_v, 0, lc_boundary)
    p_br = gmsh.model.geo.addPoint(dist_h, y_center - dist_v, 0, lc_boundary)
    p_tr = gmsh.model.geo.addPoint(dist_h, 0, 0, lc_boundary)
    p_tl = gmsh.model.geo.addPoint(-dist_h, 0, 0, lc_boundary)

    l_b = gmsh.model.geo.addLine(p_bl, p_br)
    l_r = gmsh.model.geo.addLine(p_br, p_tr)
    l_t = gmsh.model.geo.addLine(p_tr, p_tl)
    l_l = gmsh.model.geo.addLine(p_tl, p_bl)
    outer_loop = gmsh.model.geo.addCurveLoop([l_b, l_r, l_t, l_l])

    surface = gmsh.model.geo.addPlaneSurface([outer_loop, tunnel_loop])
    gmsh.model.geo.synchronize()

    gmsh.model.addPhysicalGroup(1, [arc1, arc2, arc3, arc4], name="wall")
    gmsh.model.addPhysicalGroup(1, [l_b], name="bottom")
    gmsh.model.addPhysicalGroup(1, [l_r], name="right")
    gmsh.model.addPhysicalGroup(1, [l_t], name="top")
    gmsh.model.addPhysicalGroup(1, [l_l], name="left")
    gmsh.model.addPhysicalGroup(2, [surface], name="ground")

    gmsh.model.mesh.generate(2)
    gmsh.write(filename)
    gmsh.finalize()

if __name__ == "__main__":
    # --- INPUTS ---
    E, nu, gamma, K = 3.3e10, 0.128, 24000.0, 1.5
    crown_depth, a, b = 3.0, 2.0, 2.0
    
    moose_app = "./dog-opt" 
    input_file = "simple_utilidor1.i"
    mesh_file = "simple_utilidor.msh"
    output_csv = "single_run_results.csv"

    # --- COORDINATE MAPPING ---
    y_top = -crown_depth
    y_center = -(crown_depth + b)
    y_bottom = -(crown_depth + 2.0 * b)
    
    coord_map = {
        'top': f"0.0 {y_top} 0.0",
        'bottom': f"0.0 {y_bottom} 0.0",
        'right': f"{a} {y_center} 0.0",
        'left': f"{-a} {y_center} 0.0"
    }

    # 1. Mesh Generation
    generate_elliptical_mesh(crown_depth, a, b, mesh_file)

    # 2. Command Build
    target_locs = ['top', 'bottom', 'right', 'left']
    target_vars = ['disp_x', 'disp_y', 'stress_xx', 'stress_yy', 'stress_xy', 'strain_xx', 'strain_yy', 'strain_xy']
    
    command = [
        moose_app, "-i", input_file,
        f"youngs_modulus={E}", f"poissons_ratio={nu}", f"gamma={gamma}", f"K={K}"
    ]
    
    for loc in target_locs:
        for var in target_vars:
            command.append(f"Postprocessors/{loc}_{var}/point='{coord_map[loc]}'")

    # 3. Execution
    print("Executing MOOSE...")
    subprocess.run(command, check=True)

    # 4. Extraction
    raw_results = pd.read_csv("simple_utilidor1_out.csv").iloc[-1]
    print("\n--- RESULTS FOR CROWN DEPTH 3.0m ---")
    for loc in target_locs:
        print(f"\nLocation: {loc.upper()}")
        for var in target_vars:
            val = raw_results[f"{loc}_{var}"]
            print(f"  {var:10}: {val:.6e}")