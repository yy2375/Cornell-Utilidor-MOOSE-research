import os
import subprocess
import numpy as np
import pandas as pd
from scipy.optimize import minimize
from time import perf_counter

# ==========================================
# 1. CONFIGURATION & PATHS
# ==========================================
MOOSE_EXEC = os.path.expanduser("~/projects/dog/dog-opt") 
GMSH_EXEC = "gmsh"

TEMPLATE_GEO = "template.geo"
TEMPLATE_MOOSE = "template.i"
CURRENT_GEO = "current.geo"
CURRENT_MOOSE = "current.i"
OUTPUT_CSV = "concrete_utilidor_out.csv"

# --- Site Constraints & Constants ---
INTERNAL_WIDTH = 1.6     # m
INTERNAL_HEIGHT = 1.6    # m
TOP_LOAD = 300000.0      # Pa
ALLOWABLE_STRESS = 15e6  # Pa 

COST_WEIGHT_EXCAVATION = 5000.0 
COST_WEIGHT_CONCRETE = 1500.0

# ==========================================
# 2. MOOSE EXECUTION WRAPPER
# ==========================================
def run_moose_simulation(t, d):
    """Generates mesh, runs FEM, and extracts Von Mises stress."""
    
    # Calculate outer bounds based on the optimizer's thickness guess
    w = INTERNAL_WIDTH + (2 * t)
    h = INTERNAL_HEIGHT + (2 * t)
    
    # 1. Geometry & Meshing
    with open(TEMPLATE_GEO, 'r') as file: geo_data = file.read()
    
    # Update based on your V1 templates
    geo_data = geo_data.replace('depth = DefineNumber[ 2, Name "Parameters/d" ];', f"depth = {d};")
    geo_data = geo_data.replace('height = DefineNumber[ 2, Name "Parameters/h" ];', f"height = {h};")
    geo_data = geo_data.replace('width = DefineNumber[ 2, Name "Parameters/w" ];', f"width = {w};")
    geo_data = geo_data.replace('thickness = DefineNumber[ 0.2, Name "Parameters/t" ];', f"thickness = {t};")
    with open(CURRENT_GEO, 'w') as file: file.write(geo_data)
        
    subprocess.run([GMSH_EXEC, "-2", CURRENT_GEO, "-o", "rect_shell.msh", "-v", "0"], check=True)

    # 2. MOOSE Simulation
    with open(TEMPLATE_MOOSE, 'r') as file: moose_data = file.read()
    moose_data = moose_data.replace("top_load = 6e5", f"top_load = {TOP_LOAD}")
    
    moose_data = moose_data.replace("'CROWN_OUTER'", f"'0 {-d} 0'")
    moose_data = moose_data.replace("'CROWN_INNER'", f"'0 {-d - t} 0'")
    moose_data = moose_data.replace("'INVERT_INNER'", f"'0 {-d - h + t} 0'")
    moose_data = moose_data.replace("'WALL_OUTER'", f"'{w/2.0} {-d - h/2.0} 0'")
    moose_data = moose_data.replace("'WALL_INNER'", f"'{w/2.0 - t} {-d - h/2.0} 0'")
    moose_data = moose_data.replace("'CORNER_INNER'", f"'{w/2.0 - t} {-d - t} 0'")
    with open(CURRENT_MOOSE, 'w') as file: file.write(moose_data)

    subprocess.run([MOOSE_EXEC, "-i", CURRENT_MOOSE], check=True)

    # 3. Data Extraction
    df_out = pd.read_csv(OUTPUT_CSV)
    results = df_out.iloc[-1].to_dict()
    
    s_xx = results.get('corner_stress_xx', 0)
    s_yy = results.get('corner_stress_yy', 0)
    vm_corner = np.sqrt(s_xx**2 - s_xx*s_yy + s_yy**2)
    
    return vm_corner

# ==========================================
# 3. OPTIMIZATION LOGIC
# ==========================================
def objective_function(x):
    """Algebraic cost function (Does NOT require MOOSE)."""
    t_guess, d_guess = x[0], x[1]
    return (COST_WEIGHT_CONCRETE * t_guess) + (COST_WEIGHT_EXCAVATION * d_guess)

def stress_constraint(x):
    """Requires a full MOOSE evaluation to calculate stress."""
    t_guess, d_guess = x[0], x[1]
    
    print(f"    Evaluating FEM at t={t_guess:.3f}m, d={d_guess:.3f}m...")
    sigma_vm = run_moose_simulation(t_guess, d_guess)
    
    # Must be >= 0 for SLSQP
    return ALLOWABLE_STRESS - sigma_vm

if __name__ == "__main__":
    
    # Bounds: Thickness (0.1m - 0.5m), Depth (1.0m - 10.0m)
    bounds = [(0.10, 0.50), (1.0, 10.0)]
    cons = {'type': 'ineq', 'fun': stress_constraint}
    
    initial_guesses = [
        [0.30, 5.0],  
        [0.15, 2.0],  
        [0.45, 8.0]   
    ]
    
    best_result = None
    lowest_cost = float('inf')
    
    print("Running Multi-Start SLSQP Optimization via MOOSE...")
    print("WARNING: This will take significant computational time.\n")
    
    start_time = perf_counter()
    
    for i, guess in enumerate(initial_guesses):
        print(f"--- Starting Optimization Run {i+1}/3 ---")
        result = minimize(
            objective_function, 
            guess, 
            method='SLSQP', 
            bounds=bounds, 
            constraints=cons,
            options={'ftol': 1e-3, 'disp': True} # Slightly loosened tolerance to save time
        )
        
        if result.success and result.fun < lowest_cost:
            lowest_cost = result.fun
            best_result = result
            
        print(f"Run {i+1} Finished. Cost: {result.fun:.2f}\n")
        
    calc_time = perf_counter() - start_time

    # ==========================================
    # 4. RESULTS OUTPUT
    # ==========================================
    if best_result is not None:
        opt_t, opt_d = best_result.x
        
        # Calculate final geometry
        final_w = INTERNAL_WIDTH + (2 * opt_t)
        final_h = INTERNAL_HEIGHT + (2 * opt_t)
        
        # Run one final simulation for exact output variables
        final_sigma = run_moose_simulation(opt_t, opt_d)
        
        print("\n==========================================")
        print("          FEM OPTIMIZATION SUCCESSFUL     ")
        print("==========================================")
        print(f"Optimization Time:      {calc_time:.4f} seconds")
        print("------------------------------------------")
        print(f"Optimal Thickness (t):  {opt_t:.4f} m")
        print(f"Optimal Depth (d):      {opt_d:.4f} m")
        print(f"Resulting Outer Width:  {final_w:.4f} m")
        print(f"Resulting Outer Height: {final_h:.4f} m")
        print("------------------------------------------")
        print(f"Minimized Cost Index:   {best_result.fun:.2f}")
        print(f"Peak Von Mises Stress:  {final_sigma/1e6:.2f} MPa")
        print(f"Allowable Limit:        {ALLOWABLE_STRESS/1e6:.2f} MPa")
        print("==========================================")
    else:
        print("\nOptimization Failed.")