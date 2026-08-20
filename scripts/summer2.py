import os
import subprocess
import numpy as np
import pandas as pd

# ==========================================
# 1. PARAMETER BOUNDS (Iteration 2 - Multi-Layer)
# ==========================================
N_SAMPLES = 3500

# Geometric Bounds
DEPTH_MIN, DEPTH_MAX = 1.0, 10.0      # m (Depth to crown)
WIDTH_MIN, WIDTH_MAX = 1.5, 3.0       # m
HEIGHT_MIN, HEIGHT_MAX = 1.5, 3.0     # m
THICK_MIN, THICK_MAX = 0.15, 0.50     # m

# Load and Soil Bounds
LOAD_MIN, LOAD_MAX = 0.0, 600000.0    # Pa
H_FILL_MIN, H_FILL_MAX = 2.0, 6.0     # m (Interface depth)
E_RATIO_MIN, E_RATIO_MAX = 0.05, 0.5  # E_fill / E_native
E_NATIVE = 100e6                      # Pa (Fixed native stiffness)

# ==========================================
# 2. PATHS & EXECUTABLES
# ==========================================
GEO_TEMPLATE = "template2.geo"
MOOSE_TEMPLATE = "template2.i"
CURRENT_GEO = "current.geo"
CURRENT_MOOSE = "current.i"
MOOSE_EXEC = os.path.expanduser("~/projects/dog/dog-opt") 
OUTPUT_CSV = "concrete_utilidor_out.csv"

# ==========================================
# 3. HELPER FUNCTIONS
# ==========================================
def generate_mesh(depth, width, height, thickness, h_fill):
    """Reads the geo template, updates 5 parameters, and generates the .msh file."""
    with open(GEO_TEMPLATE, 'r') as file:
        geo_data = file.read()

    # Replace parameter lines (Must match Gmsh template exactly)
    geo_data = geo_data.replace('depth = DefineNumber[ 5.0, Name "Parameters/d" ];', f'depth = {depth};')
    geo_data = geo_data.replace('height = DefineNumber[ 2.0, Name "Parameters/h" ];', f'height = {height};')
    geo_data = geo_data.replace('width = DefineNumber[ 2.0, Name "Parameters/w" ];', f'width = {width};')
    geo_data = geo_data.replace('thickness = DefineNumber[ 0.2, Name "Parameters/t" ];', f'thickness = {thickness};')
    geo_data = geo_data.replace('H_fill = DefineNumber[ 4.0, Name "Parameters/H_fill" ];', f'H_fill = {h_fill};')

    with open(CURRENT_GEO, 'w') as file:
        file.write(geo_data)

    # Run Gmsh silently
    subprocess.run(["gmsh", "-2", CURRENT_GEO, "-o", "test2_shell.msh", "-v", "0"], check=True, timeout=20)

def update_moose_file(depth, width, height, thickness, top_load, h_fill, e_ratio):
    """Updates load, stratigraphy, and dynamic extraction coordinates."""
    with open(MOOSE_TEMPLATE, 'r') as file:
        moose_data = file.read()

    # 1. Update Load and Soil Parameters
    moose_data = moose_data.replace("top_load = 3e5", f"top_load = {top_load}")
    moose_data = moose_data.replace("H_fill = 4.0", f"H_fill = {h_fill}")
    
    e_fill_actual = E_NATIVE * e_ratio
    moose_data = moose_data.replace("youngs_modulus_fill = 15e6", f"youngs_modulus_fill = {e_fill_actual}")

    # 2. Calculate dynamic coordinates based on current mesh parameters
    crown_outer  = f"'0 {-depth} 0'"
    crown_inner  = f"'0 {-depth - thickness} 0'"
    invert_inner = f"'0 {-depth - height + thickness} 0'"
    wall_outer   = f"'{width/2.0} {-depth - height/2.0} 0'"
    wall_inner   = f"'{width/2.0 - thickness} {-depth - height/2.0} 0'"
    corner_inner = f"'{width/2.0 - thickness} {-depth - thickness} 0'"

    # 3. Inject coordinates into the MOOSE placeholders
    moose_data = moose_data.replace("'CROWN_OUTER'", crown_outer)
    moose_data = moose_data.replace("'CROWN_INNER'", crown_inner)
    moose_data = moose_data.replace("'INVERT_INNER'", invert_inner)
    moose_data = moose_data.replace("'WALL_OUTER'", wall_outer)
    moose_data = moose_data.replace("'WALL_INNER'", wall_inner)
    moose_data = moose_data.replace("'CORNER_INNER'", corner_inner)

    with open(CURRENT_MOOSE, 'w') as file:
        file.write(moose_data)

def run_moose():
    """Executes the MOOSE simulation."""
    subprocess.run([MOOSE_EXEC, "-i", CURRENT_MOOSE], check=True, timeout=90)

# ==========================================
# 4. MAIN GENERATION LOOP
# ==========================================
def main():
    np.random.seed(42)
    
    # Generate randomized arrays for all 7 input variables
    depths = np.random.uniform(DEPTH_MIN, DEPTH_MAX, N_SAMPLES)
    widths = np.random.uniform(WIDTH_MIN, WIDTH_MAX, N_SAMPLES)
    heights = np.random.uniform(HEIGHT_MIN, HEIGHT_MAX, N_SAMPLES)
    thicknesses = np.random.uniform(THICK_MIN, THICK_MAX, N_SAMPLES)
    top_loads = np.random.uniform(LOAD_MIN, LOAD_MAX, N_SAMPLES)
    h_fills = np.random.uniform(H_FILL_MIN, H_FILL_MAX, N_SAMPLES)
    e_ratios = np.random.uniform(E_RATIO_MIN, E_RATIO_MAX, N_SAMPLES)

    all_data = []

    print(f"Starting generation of {N_SAMPLES} multi-layer samples...")

    for i in range(N_SAMPLES):
        d = depths[i]
        w = widths[i]
        h = heights[i]
        t = thicknesses[i]
        load = top_loads[i]
        h_f = h_fills[i]
        e_r = e_ratios[i]

        print(f"Run {i+1}/{N_SAMPLES} | Depth: {d:.2f}m | H_fill: {h_f:.2f}m | Load: {load/1000:.0f}kPa")

        try:
            # 1. Pre-Processing
            generate_mesh(d, w, h, t, h_f)
            update_moose_file(d, w, h, t, load, h_f, e_r)
            
            # 2. Solving
            run_moose()

            # 3. Post-Processing / Data Extraction
            df_out = pd.read_csv(OUTPUT_CSV)
            results = df_out.iloc[-1].to_dict()

            # 4. Structural Math (Stress to True Bending Moments)
            # Formula: M = |sigma_outer - sigma_inner| * t^2 / 12
            
            # Roof Moment
            sigma_roof_top = results.get('roof_stress_top', 0)
            sigma_roof_bot = results.get('roof_stress_bottom', 0)
            M_roof = abs(sigma_roof_top - sigma_roof_bot) * (t**2) / 12.0
            
            # Wall Moment
            sigma_wall_out = results.get('wall_stress_outer', 0)
            sigma_wall_in = results.get('wall_stress_inner', 0)
            M_wall = abs(sigma_wall_out - sigma_wall_in) * (t**2) / 12.0
            
            # Peak Von Mises Stress (Extracted directly from MOOSE)
            vm_max = results.get('max_sigma_vm', 0)

            # 5. Compile Final Training Row (7 Inputs, 5 Outputs)
            row_data = {
                'input_depth': d,
                'input_top_load': load,
                'input_width': w,
                'input_height': h,
                'input_thickness': t,
                'input_h_fill': h_f,
                'input_e_ratio': e_r,
                'u_y_crown': results.get('u_y_crown', 0),
                'u_y_invert': results.get('u_y_invert', 0),
                'M_roof': M_roof,     
                'M_wall': M_wall,     
                'sigma_vm': vm_max    
            }

            all_data.append(row_data)

        except Exception as e:
            print(f"Error on run {i+1}: {e}")
            continue

    # 6. Save Dataset
    master_df = pd.DataFrame(all_data)
    master_df.to_csv("surrogate_training_data_v2.csv", index=False)
    print("\nData generation complete. Saved to surrogate_training_data_v2.csv")

if __name__ == "__main__":
    main()