import gmsh
import subprocess
import random
import csv
import pandas as pd
import os

def generate_elliptical_mesh(crown_depth, a, b, filename):
    gmsh.initialize()
    gmsh.option.setNumber("General.Terminal", 0)
    
    # Required to prevent Segmentation Faults in MOOSE
    gmsh.option.setNumber("Mesh.MshFileVersion", 2.2) 
    
    gmsh.model.add("utilidor_model")

    lc_wall = 0.1
    lc_boundary = 1.0

    dist_h = 11.0 * a
    dist_v = 11.0 * b
    
    y_center = -(crown_depth + b)
    y_bottom_limit = y_center - dist_v
    x_left_limit = -dist_h
    x_right_limit = dist_h

    # 1. Ellipse Points 
    p_center = gmsh.model.geo.addPoint(0, y_center, 0, lc_wall)
    p_right  = gmsh.model.geo.addPoint(a, y_center, 0, lc_wall)
    p_top    = gmsh.model.geo.addPoint(0, y_center + b, 0, lc_wall)
    p_left   = gmsh.model.geo.addPoint(-a, y_center, 0, lc_wall)
    p_bottom = gmsh.model.geo.addPoint(0, y_center - b, 0, lc_wall)

    # 2. Ellipse Arcs
    arc1 = gmsh.model.geo.addEllipseArc(p_right, p_center, p_right, p_top)
    arc2 = gmsh.model.geo.addEllipseArc(p_top, p_center, p_left, p_left)
    arc3 = gmsh.model.geo.addEllipseArc(p_left, p_center, p_left, p_bottom)
    arc4 = gmsh.model.geo.addEllipseArc(p_bottom, p_center, p_right, p_right)
    tunnel_loop = gmsh.model.geo.addCurveLoop([arc1, arc2, arc3, arc4])

    # 3. Dynamic External Boundary Points
    p_bl = gmsh.model.geo.addPoint(x_left_limit,  y_bottom_limit, 0, lc_boundary)
    p_br = gmsh.model.geo.addPoint(x_right_limit, y_bottom_limit, 0, lc_boundary)
    p_tr = gmsh.model.geo.addPoint(x_right_limit, 0, 0, lc_boundary)
    p_tl = gmsh.model.geo.addPoint(x_left_limit,  0, 0, lc_boundary)

    # 4. External Boundary Lines
    line_bottom = gmsh.model.geo.addLine(p_bl, p_br)
    line_right  = gmsh.model.geo.addLine(p_br, p_tr)
    line_top    = gmsh.model.geo.addLine(p_tr, p_tl)
    line_left   = gmsh.model.geo.addLine(p_tl, p_bl)
    outer_loop  = gmsh.model.geo.addCurveLoop([line_bottom, line_right, line_top, line_left])

    # 5. Surface and Synchronization
    surface = gmsh.model.geo.addPlaneSurface([outer_loop, tunnel_loop])
    gmsh.model.geo.synchronize()

    # 6. Physical Groups 
    gmsh.model.addPhysicalGroup(1, [arc1, arc2, arc3, arc4], name="wall")
    gmsh.model.addPhysicalGroup(1, [line_bottom], name="bottom")
    gmsh.model.addPhysicalGroup(1, [line_right], name="right")
    gmsh.model.addPhysicalGroup(1, [line_top], name="top")
    gmsh.model.addPhysicalGroup(1, [line_left], name="left")
    gmsh.model.addPhysicalGroup(2, [surface], name="ground")

    # 7. Mesh Generation
    gmsh.model.mesh.generate(2)
    gmsh.write(filename)
    gmsh.finalize()


# ==========================================
# MASTER DATA GENERATION PIPELINE
# ==========================================
if __name__ == "__main__":
    print("Starting High Precision Data Generation Pipeline...")

    moose_app = "./dog-opt" 
    input_file = "simple_utilidor1.i"
    mesh_filename = "simple_utilidor.msh"
    moose_output_csv = "simple_utilidor1_out.csv"
    ml_dataset_name = "training_dataset.csv"

    # Define the output matrix targets
    target_locations = ['top', 'bottom', 'right', 'left']
    target_variables = ['disp_x', 'disp_y', 'stress_xx', 'stress_yy', 'stress_xy', 'strain_xx', 'strain_yy', 'strain_xy']

    # Dynamically build the 39 column headers
    headers = [
        "Youngs_Modulus", "Poissons_Ratio", "Gamma", "K_Value", 
        "Crown_Depth", "Semi_Major_a", "Semi_Minor_b", "Top_Load"
    ]
    for loc in target_locations:
        for var in target_variables:
            headers.append(f"{loc}_{var}")

    with open(ml_dataset_name, 'w', newline='') as master_file:
        writer = csv.writer(master_file)
        writer.writerow(headers)

        total_runs = 15000
        for i in range(total_runs):
            print(f"\n=== Simulation {i+1} of {total_runs} ===")
            
            # 1. Randomized Material Properties
            E_val = random.uniform(2.0e10, 5.0e10)
            nu_val = random.uniform(0.1, 0.3)
            gamma_val = random.uniform(1.5e4, 3.0e4)
            k_val = random.uniform(0.8, 2.0)
            p_val = random.uniform(0.0, 6.0e5)

            # 2. Randomized Geometric Properties 
            crown_depth = random.uniform(1.5, 10.0)
            a_val = random.uniform(0.75, 2.0)  
            b_val = random.uniform(1.0, 2.0)   

            # 3. Calculate Exact Coordinate Mappings
            y_top = -crown_depth
            y_center = -(crown_depth + b_val)
            y_bottom = -(crown_depth + 2.0 * b_val)
            x_right = a_val
            x_left = -a_val
            
            coord_map = {
                'top': f"0.0 {y_top} 0.0",
                'bottom': f"0.0 {y_bottom} 0.0",
                'right': f"{x_right} {y_center} 0.0",
                'left': f"{x_left} {y_center} 0.0"
            }

            # 4. Mesh Generation
            try:
                generate_elliptical_mesh(crown_depth, a_val, b_val, mesh_filename)
            except Exception as e:
                print(f"Gmsh Error: {e}. Skipping.")
                continue

            # 5. MOOSE Command Construction
            command = [
                moose_app, "-i", input_file, 
                f"youngs_modulus={E_val}",
                f"poissons_ratio={nu_val}",
                f"gamma={gamma_val}",
                f"K={k_val}",
                f"top_load={p_val}"
            ]
            
            # Dynamically inject the 32 postprocessor coordinates
            for loc in target_locations:
                for var in target_variables:
                    command.append(f"Postprocessors/{loc}_{var}/point='{coord_map[loc]}'")
            
            # 6. Execute MOOSE
            try:
                result = subprocess.run(command, check=True, capture_output=True, text=True)
            except subprocess.CalledProcessError as e:
                print("\n============================================================")
                print("MOOSE CRASHED! HERE IS THE EXACT ERROR MESSAGE:")
                print("============================================================")
                if e.stderr:
                    print(e.stderr)
                else:
                    print(e.stdout)
                print("============================================================")
                break 

            # 7. Extract Data
            if os.path.exists(moose_output_csv):
                df = pd.read_csv(moose_output_csv)
                try:
                    # Input columns
                    raw_data = [E_val, nu_val, gamma_val, k_val, crown_depth, a_val, b_val, p_val]
                    
                    # Extract all 32 targeted variables dynamically
                    for loc in target_locations:
                        for var in target_variables:
                            column_name = f"{loc}_{var}"
                            raw_data.append(df[column_name].iloc[-1])
                    
                    # Format and write row
                    formatted_row = [f"{val:.10e}" for val in raw_data]
                    writer.writerow(formatted_row)
                    
                    os.remove(moose_output_csv)
                    print(f"Success. Crown Depth: {crown_depth:.4f} m | Geometry: {2*a_val:.2f}m x {2*b_val:.2f}m")
                    
                except KeyError as e:
                    print(f"Error: Missing {e} in MOOSE output. Check Postprocessors.")
            else:
                print("Error: Output CSV not found.")

    print(f"\nPipeline Complete. Data saved to: {ml_dataset_name}")