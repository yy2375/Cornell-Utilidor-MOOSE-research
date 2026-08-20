import os
import subprocess
import itertools
import numpy as np
import pandas as pd
from scipy.stats import qmc
from time import perf_counter

# ==========================================
# 1. CONFIGURATION & BOUNDS
# ==========================================
DATE_STR = "6_10"
MOOSE_EXEC = os.path.expanduser("~/projects/dog/dog-opt")
GMSH_EXEC = "gmsh"

GEO_TEMPLATE = "template2.geo"
MOOSE_TEMPLATE = "template2.i"
TEMP_GEO = f"temp_run_{DATE_STR}.geo"
TEMP_MOOSE = f"temp_run_{DATE_STR}.i"
TEMP_MSH = f"temp_mesh_{DATE_STR}.msh"
OUTPUT_CSV = "concrete_utilidor_out.csv"

# Global Variables
E_NATIVE = 100e6  # Pa
L_BOUNDS = [1.0, 1.5, 1.5, 0.15, 0.0, 2.0, 0.05]
U_BOUNDS = [10.0, 3.0, 3.0, 0.50, 600000.0, 6.0, 0.5]

# Sweep Parameters (Updated to Powers of 2 for Sobol math)
ALGORITHMS = ["Random", "LHS", "Sobol", "Grid"]
LINEAR_N_STEPS = [128, 256, 512, 1024, 2048] 
VERIFICATION_N = 256

# ==========================================
# 2. SAMPLING ENGINE
# ==========================================
def generate_samples(n, algorithm):
    """Generates an N x 7 matrix of scaled parameters based on the chosen algorithm."""
    if algorithm == "Random":
        return np.random.uniform(L_BOUNDS, U_BOUNDS, (n, 7))
        
    elif algorithm == "LHS":
        sampler = qmc.LatinHypercube(d=7)
        sample_matrix = sampler.random(n=n)
        return qmc.scale(sample_matrix, L_BOUNDS, U_BOUNDS)
        
    elif algorithm == "Sobol":
        sampler = qmc.Sobol(d=7, scramble=True)
        # We suppress the warning since we guarantee n is a power of 2 now
        sample_matrix = sampler.random(n=n)
        return qmc.scale(sample_matrix, L_BOUNDS, U_BOUNDS)
        
    elif algorithm == "Grid":
        pts_per_dim = int(round(n ** (1/7)))
        print(f"   -> Building Grid: {pts_per_dim}^7 = {pts_per_dim**7} points")
        grids = [np.linspace(L_BOUNDS[i], U_BOUNDS[i], pts_per_dim) for i in range(7)]
        return np.array(list(itertools.product(*grids)))

# ==========================================
# 3. FEM EXECUTION
# ==========================================
def run_moose_simulation(d, w, h, t, load, h_f, e_r):
    """Executes a single Gmsh + MOOSE pipeline safely."""
    # 1. Mesh Generation
    with open(GEO_TEMPLATE, 'r') as file:
        geo_data = file.read()

    geo_data = geo_data.replace('depth = DefineNumber[ 5.0, Name "Parameters/d" ];', f'depth = {d};')
    geo_data = geo_data.replace('height = DefineNumber[ 2.0, Name "Parameters/h" ];', f'height = {h};')
    geo_data = geo_data.replace('width = DefineNumber[ 2.0, Name "Parameters/w" ];', f'width = {w};')
    geo_data = geo_data.replace('thickness = DefineNumber[ 0.2, Name "Parameters/t" ];', f'thickness = {t};')
    geo_data = geo_data.replace('H_fill = DefineNumber[ 4.0, Name "Parameters/H_fill" ];', f'H_fill = {h_f};')

    with open(TEMP_GEO, 'w') as file:
        file.write(geo_data)

    # FIX: Output directly to test2_shell.msh exactly like summer2.py
    subprocess.run([GMSH_EXEC, "-2", TEMP_GEO, "-o", "test2_shell.msh", "-v", "0"], check=True)

    # 2. MOOSE Update
    with open(MOOSE_TEMPLATE, 'r') as file:
        moose_data = file.read()

    # FIX: Removed the broken mesh filename replacement. 

    moose_data = moose_data.replace("top_load = 3e5", f"top_load = {load}")
    moose_data = moose_data.replace("H_fill = 4.0", f"H_fill = {h_f}")
    e_fill_actual = E_NATIVE * e_r
    moose_data = moose_data.replace("youngs_modulus_fill = 15e6", f"youngs_modulus_fill = {e_fill_actual}")

    # FIX: Restored your exact PointValue coordinates with no nudges
    moose_data = moose_data.replace("'CROWN_OUTER'", f"'0 {-d} 0'")
    moose_data = moose_data.replace("'CROWN_INNER'", f"'0 {-d - t} 0'")
    moose_data = moose_data.replace("'INVERT_INNER'", f"'0 {-d - h + t} 0'")
    moose_data = moose_data.replace("'WALL_OUTER'", f"'{w/2.0} {-d - h/2.0} 0'")
    moose_data = moose_data.replace("'WALL_INNER'", f"'{w/2.0 - t} {-d - h/2.0} 0'")
    moose_data = moose_data.replace("'CORNER_INNER'", f"'{w/2.0 - t} {-d - t} 0'")

    with open(TEMP_MOOSE, 'w') as file:
        file.write(moose_data)

    # 3. Execute
    # 3. Execute
    subprocess.run([MOOSE_EXEC, "-i", TEMP_MOOSE], check=True)

    # 4. Extract
    df_out = pd.read_csv(OUTPUT_CSV)
    results = df_out.iloc[-1].to_dict()

    sigma_roof_top = results.get('roof_stress_top', 0)
    sigma_roof_bot = results.get('roof_stress_bottom', 0)
    M_roof = abs(sigma_roof_top - sigma_roof_bot) * (t**2) / 12.0
    
    sigma_wall_out = results.get('wall_stress_outer', 0)
    sigma_wall_in = results.get('wall_stress_inner', 0)
    M_wall = abs(sigma_wall_out - sigma_wall_in) * (t**2) / 12.0

    return {
        'input_depth': d, 'input_top_load': load, 'input_width': w, 
        'input_height': h, 'input_thickness': t, 'input_h_fill': h_f, 'input_e_ratio': e_r,
        'u_y_crown': results.get('u_y_crown', 0),
        'u_y_invert': results.get('u_y_invert', 0),
        'M_roof': M_roof,     
        'M_wall': M_wall,     
        'sigma_vm': results.get('max_sigma_vm', 0)
    }
# ==========================================
# 4. DATASET GENERATION PIPELINE
# ==========================================
def build_dataset(n_samples, algorithm, filename):
    print(f"\n--- Generating {algorithm} Dataset (N={n_samples}) ---")
    
    matrix = generate_samples(n_samples, algorithm)
    actual_n = matrix.shape[0]
    
    all_data = []
    start_time = perf_counter()

    for i in range(actual_n):
        d, w, h, t, load, h_f, e_r = matrix[i]
        
        # Print exact parameters for every single run
        print(f"Run {i+1}/{actual_n} | Depth: {d:.2f}m | H_fill: {h_f:.2f}m | Load: {load/1000:.0f}kPa")

        try:
            row_data = run_moose_simulation(d, w, h, t, load, h_f, e_r)
            all_data.append(row_data)
        except Exception as e:
            # Print a warning if a run fails and drops
            print(f"  [!] Skipped run {i+1} due to error.")
            continue

    df = pd.DataFrame(all_data)
    df.to_csv(filename, index=False)
    
    elapsed = (perf_counter() - start_time) / 60
    print(f"Saved {len(df)} successful runs to {filename} ({elapsed:.1f} minutes)")
# ==========================================
# 5. MASTER EXECUTION
# ==========================================
def main():
    print("========================================")
    print("PHASE 1: BENCHMARK DATASET GENERATOR")
    print("========================================\n")

    verify_file = f"verification_data_{DATE_STR}.csv"
    if not os.path.exists(verify_file):
        print(f"Building Global Verification Dataset...")
        build_dataset(VERIFICATION_N, "Sobol", verify_file)
    else:
        print(f"Verification dataset {verify_file} already exists. Skipping.")

    for algo in ALGORITHMS:
        sample_sizes = [128, 2187] if algo == "Grid" else LINEAR_N_STEPS
        
        for n in sample_sizes:
            file_name = f"training_data_{DATE_STR}_{algo}_{n}.csv"
            
            if os.path.exists(file_name):
                print(f"Skipping {file_name} (Already generated)")
                continue
                
            build_dataset(n, algo, file_name)

    for file in [TEMP_GEO, TEMP_MOOSE, TEMP_MSH]:
        if os.path.exists(file):
            os.remove(file)

    print("\n[SUCCESS] All datasets generated securely. Ready for AI Training.")

if __name__ == "__main__":
    main()