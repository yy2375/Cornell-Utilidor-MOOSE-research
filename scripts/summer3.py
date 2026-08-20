import os
import subprocess
import numpy as np
import pandas as pd
import re
import sys
from scipy.stats import qmc # Added for LHS

# ==========================================
# 1. PARAMETER BOUNDS
# ==========================================
N_SAMPLES = 1300

# Geometric Inputs (Gmsh)
WIDTH_MIN, WIDTH_MAX = 1.5, 3.0       # m (w)
HEIGHT_MIN, HEIGHT_MAX = 1.5, 3.0     # m (h)
THICK_MIN, THICK_MAX = 0.15, 0.40     # m (t)
DEPTH_MIN, DEPTH_MAX = 1.0, 5.0       # m (d - depth to crown)
BASE_Y_MIN, BASE_Y_MAX = -40.0, -20.0 # m (by - deepest soil depth)

# Material & Load Inputs (MOOSE)
E_FILL_MIN, E_FILL_MAX = 10e6, 80e6   # Pa
E_SOIL_MIN, E_SOIL_MAX = 50e6, 150e6  # Pa (Native soil)
PHI_MIN, PHI_MAX = 0.436, 0.610       # Radians 
LOAD_MIN, LOAD_MAX = 0.0, 100000.0    # Pa 

# ==========================================
# 2. PATHS
# ==========================================
GEO_TEMPLATE = "thin_layer2.geo"
MOOSE_TEMPLATE = "summer3_script.i"
CURRENT_GEO = "current.geo"
CURRENT_MOOSE = "current.i"
OUTPUT_CSV = "summer3.csv"
FINAL_DATASET = "surrogate_comprehensive_training_datav2.csv"

# ==========================================
# 3. EXECUTION FUNCTIONS
# ==========================================
def generate_mesh(w, h, t, d, by):
    with open(GEO_TEMPLATE, 'r') as file:
        geo_data = file.read()

    geo_data = re.sub(r'w\s*=\s*[\d\.\-]+;', f'w = {w};', geo_data)
    geo_data = re.sub(r'h\s*=\s*[\d\.\-]+;', f'h = {h};', geo_data)
    geo_data = re.sub(r't\s*=\s*[\d\.\-]+;', f't = {t};', geo_data)
    geo_data = re.sub(r'd\s*=\s*[\d\.\-]+;', f'd = {d};', geo_data)
    geo_data = re.sub(r'by\s*=\s*[\d\.\-]+;', f'by = {by};', geo_data)

    with open(CURRENT_GEO, 'w') as file:
        file.write(geo_data)

    subprocess.run(["gmsh", "-2", CURRENT_GEO, "-o", "thin_layer2.msh", "-v", "0"], check=True)

def update_moose_file(e_fill, e_soil, phi, load, w, h, d):
    with open(MOOSE_TEMPLATE, 'r') as file:
        moose_data = file.read()

    # Physics
    moose_data = re.sub(r'value\s*=\s*0\.488692', f'value = {phi:.6f}', moose_data)
    moose_data = re.sub(r'factor\s*=\s*80000', f'factor = {load:.1f}', moose_data)
    moose_data = re.sub(r'80e6', f'{e_fill:.1f}', moose_data)

    # Dynamic points
    top_conc   = f"0 {-(d + 0.01):.4f} 0"
    inv_conc   = f"0 {-(d + h - 0.01):.4f} 0"
    left_conc  = f"{-(w/2 - 0.01):.4f} {-(d + h/2):.4f} 0"
    right_conc = f"{(w/2 - 0.01):.4f} {-(d + h/2):.4f} 0"

    top_soil   = f"0 {-(d - 0.06):.4f} 0"
    inv_soil   = f"0 {-(d + h + 0.06):.4f} 0"
    left_soil  = f"{-(w/2 + 0.06):.4f} {-(d + h/2):.4f} 0"
    right_soil = f"{(w/2 + 0.06):.4f} {-(d + h/2):.4f} 0"

    # Inject coordinates
    moose_data = moose_data.replace("TOP_CONC_PT", top_conc)
    moose_data = moose_data.replace("INV_CONC_PT", inv_conc)
    moose_data = moose_data.replace("LEFT_CONC_PT", left_conc)
    moose_data = moose_data.replace("RIGHT_CONC_PT", right_conc)
    
    moose_data = moose_data.replace("TOP_SOIL_PT", top_soil)
    moose_data = moose_data.replace("INV_SOIL_PT", inv_soil)
    moose_data = moose_data.replace("LEFT_SOIL_PT", left_soil)
    moose_data = moose_data.replace("RIGHT_SOIL_PT", right_soil)

    with open(CURRENT_MOOSE, 'w') as file:
        file.write(moose_data)

def run_moose():
    subprocess.run(["./dog-opt", "-i", CURRENT_MOOSE], check=True)

# ==========================================
# 4. MAIN GENERATION LOOP
# ==========================================
def main():
    # Define parameter bounds for LHS scaling
    l_bounds = [WIDTH_MIN, HEIGHT_MIN, THICK_MIN, DEPTH_MIN, BASE_Y_MIN, E_FILL_MIN, E_SOIL_MIN, PHI_MIN, LOAD_MIN]
    u_bounds = [WIDTH_MAX, HEIGHT_MAX, THICK_MAX, DEPTH_MAX, BASE_Y_MAX, E_FILL_MAX, E_SOIL_MAX, PHI_MAX, LOAD_MAX]

    # Generate LHS samples (d=9 for 9 variables)
    sampler = qmc.LatinHypercube(d=9, seed=42)
    sample = sampler.random(n=N_SAMPLES)
    scaled_samples = qmc.scale(sample, l_bounds, u_bounds)

    dataset = []

    try:
        for i in range(N_SAMPLES):
            # Extract variables for this run
            w, h, t, d, by, e_f, e_s, phi, load = scaled_samples[i]

            print(f"Run {i+1}/{N_SAMPLES} | W: {w:.2f} | H: {h:.2f} | D: {d:.2f} | Load: {load/1000:.1f}kPa")

            try:
                generate_mesh(w, h, t, d, by)
                update_moose_file(e_f, e_s, phi, load, w, h, d)
                run_moose()

                df_out = pd.read_csv(OUTPUT_CSV)
                fs = df_out.iloc[-1].to_dict()

                row = {
                    'input_width': w, 'input_height': h, 'input_thickness': t,
                    'input_depth': d, 'input_base_y': by, 'input_e_fill': e_f,
                    'input_e_soil': e_s, 'input_phi': phi, 'input_load': load,
                    
                    'top_disp_x': fs.get('top_disp_x', np.nan), 'top_disp_y': fs.get('top_disp_y', np.nan),
                    'top_stress_xx': fs.get('top_stress_xx', np.nan), 'top_stress_yy': fs.get('top_stress_yy', np.nan), 'top_stress_vm': fs.get('top_stress_vm', np.nan),

                    'invert_disp_x': fs.get('invert_disp_x', np.nan), 'invert_disp_y': fs.get('invert_disp_y', np.nan),
                    'invert_stress_xx': fs.get('invert_stress_xx', np.nan), 'invert_stress_yy': fs.get('invert_stress_yy', np.nan), 'invert_stress_vm': fs.get('invert_stress_vm', np.nan),

                    'left_disp_x': fs.get('left_disp_x', np.nan), 'left_disp_y': fs.get('left_disp_y', np.nan),
                    'left_stress_xx': fs.get('left_stress_xx', np.nan), 'left_stress_yy': fs.get('left_stress_yy', np.nan), 'left_stress_vm': fs.get('left_stress_vm', np.nan),

                    'right_disp_x': fs.get('right_disp_x', np.nan), 'right_disp_y': fs.get('right_disp_y', np.nan),
                    'right_stress_xx': fs.get('right_stress_xx', np.nan), 'right_stress_yy': fs.get('right_stress_yy', np.nan), 'right_stress_vm': fs.get('right_stress_vm', np.nan)
                }
                dataset.append(row)

            except Exception as e:
                print(f"Run {i+1} failed: {e}")
                continue
                
    except KeyboardInterrupt:
        print("\n[!] Script interrupted by user. Initiating auto-save...")
        
    finally:
        if dataset:
            df_final = pd.DataFrame(dataset)
            df_final.dropna(inplace=True)
            df_final.to_csv(FINAL_DATASET, index=False)
            print(f"Auto-save complete. Saved {len(df_final)} samples to {FINAL_DATASET}.")
        else:
            print("No completed iterations to save.")

if __name__ == "__main__":
    main()