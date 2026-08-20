import os
import subprocess
import numpy as np
import pandas as pd
import re
from scipy.stats import qmc
import jax
import jax.numpy as jnp
import equinox as eqx
import joblib

# ==========================================
# 1. PARAMETER BOUNDS & CONFIG
# ==========================================
N_TRIALS = 1  # Set the number of test trials here

# Geometric Inputs (Gmsh)
WIDTH_MIN, WIDTH_MAX = 1.5, 3.0       
HEIGHT_MIN, HEIGHT_MAX = 1.5, 3.0     
THICK_MIN, THICK_MAX = 0.15, 0.40     
DEPTH_MIN, DEPTH_MAX = 1.0, 5.0       
BASE_Y_MIN, BASE_Y_MAX = -40.0, -20.0 

# Material & Load Inputs (MOOSE)
E_FILL_MIN, E_FILL_MAX = 10e6, 80e6   
E_SOIL_MIN, E_SOIL_MAX = 50e6, 150e6  
PHI_MIN, PHI_MAX = 0.436, 0.610       
LOAD_MIN, LOAD_MAX = 0.0, 100000.0    

# Paths
GEO_TEMPLATE = "thin_layer2.geo"
MOOSE_TEMPLATE = "summer3_script.i"
CURRENT_GEO = "current.geo"
CURRENT_MOOSE = "current.i"
OUTPUT_CSV = "summer3.csv"
RESULTS_FILE = "model_accuracy_results.csv"

# Output field names mapping
OUTPUT_FIELDS = [
    'top_disp_x', 'top_disp_y', 'top_stress_xx', 'top_stress_yy', 'top_stress_vm',
    'invert_disp_x', 'invert_disp_y', 'invert_stress_xx', 'invert_stress_yy', 'invert_stress_vm',
    'left_disp_x', 'left_disp_y', 'left_stress_xx', 'left_stress_yy', 'left_stress_vm',
    'right_disp_x', 'right_disp_y', 'right_stress_xx', 'right_stress_yy', 'right_stress_vm'
]

# ==========================================
# 2. NEURAL NETWORK ARCHITECTURE & INFERENCE
# ==========================================
class UtilidorModel(eqx.Module):
    layers: list

    def __init__(self, in_size, out_size, key):
        key1, key2, key3, key4, key5 = jax.random.split(key, 5)
        self.layers = [
            eqx.nn.Linear(in_size, 192, key=key1),
            eqx.nn.Linear(192, 192, key=key2),
            eqx.nn.Linear(192, 192, key=key3),
            eqx.nn.Linear(192, 192, key=key4),
            eqx.nn.Linear(192, out_size, key=key5)
        ]

    def __call__(self, x):
        for layer in self.layers[:-1]:
            x = jax.nn.gelu(layer(x))
        return self.layers[-1](x)

# Global cache to prevent reloading from disk on every trial
_MODEL_CACHE = None
_SCALER_X_CACHE = None
_SCALER_Y_CACHE = None

def load_ai_assets():
    """Lazy loads the model and scalers into memory."""
    global _MODEL_CACHE, _SCALER_X_CACHE, _SCALER_Y_CACHE
    if _MODEL_CACHE is None:
        _SCALER_X_CACHE = joblib.load("scaler_X_v3.pkl")
        _SCALER_Y_CACHE = joblib.load("scaler_Y_v3.pkl")
        
        # Initialize an empty model shell to load weights into
        key = jax.random.PRNGKey(0) 
        skeleton = UtilidorModel(in_size=9, out_size=20, key=key)
        _MODEL_CACHE = eqx.tree_deserialise_leaves("concrete_utilidor_model_v3.eqx", skeleton)

def predict_with_model(w, h, t, d, by, e_f, e_s, phi, load):
    """Executes the JAX AI model and returns outputs mapped to MOOSE fields."""
    load_ai_assets()

    # Format inputs and scale
    inputs = np.array([[w, h, t, d, by, e_f, e_s, phi, load]], dtype=np.float32)
    inputs_scaled = _SCALER_X_CACHE.transform(inputs)
    
    # Run inference
    pred_scaled = _MODEL_CACHE(jnp.array(inputs_scaled[0]))
    
    # Unscale outputs
    pred_unscaled = _SCALER_Y_CACHE.inverse_transform([np.array(pred_scaled)])[0]

    # Map the 20-element array to the expected dictionary keys
    return {
        'top_disp_x': pred_unscaled[0],       'top_disp_y': pred_unscaled[1],
        'top_stress_xx': pred_unscaled[2],    'top_stress_yy': pred_unscaled[3],    'top_stress_vm': pred_unscaled[4],
        
        'invert_disp_x': pred_unscaled[5],    'invert_disp_y': pred_unscaled[6],
        'invert_stress_xx': pred_unscaled[7], 'invert_stress_yy': pred_unscaled[8], 'invert_stress_vm': pred_unscaled[9],
        
        'left_disp_x': pred_unscaled[10],     'left_disp_y': pred_unscaled[11],
        'left_stress_xx': pred_unscaled[12],  'left_stress_yy': pred_unscaled[13],  'left_stress_vm': pred_unscaled[14],
        
        'right_disp_x': pred_unscaled[15],    'right_disp_y': pred_unscaled[16],
        'right_stress_xx': pred_unscaled[17], 'right_stress_yy': pred_unscaled[18], 'right_stress_vm': pred_unscaled[19]
    }

# ==========================================
# 3. MOOSE EXECUTION FUNCTIONS
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

    subprocess.run(["gmsh", "-2", CURRENT_GEO, "-o", "thin_layer.msh", "-v", "0"], check=True)

def update_moose_file(e_fill, e_soil, phi, load, w, h, d):
    with open(MOOSE_TEMPLATE, 'r') as file:
        moose_data = file.read()

    moose_data = re.sub(r'value\s*=\s*0\.488692', f'value = {phi:.6f}', moose_data)
    moose_data = re.sub(r'factor\s*=\s*80000', f'factor = {load:.1f}', moose_data)
    moose_data = re.sub(r'80e6', f'{e_fill:.1f}', moose_data)

    top_conc   = f"0 {-(d + 0.01):.4f} 0"
    inv_conc   = f"0 {-(d + h - 0.01):.4f} 0"
    left_conc  = f"{-(w/2 - 0.01):.4f} {-(d + h/2):.4f} 0"
    right_conc = f"{(w/2 - 0.01):.4f} {-(d + h/2):.4f} 0"

    top_soil   = f"0 {-(d - 0.06):.4f} 0"
    inv_soil   = f"0 {-(d + h + 0.06):.4f} 0"
    left_soil  = f"{-(w/2 + 0.06):.4f} {-(d + h/2):.4f} 0"
    right_soil = f"{(w/2 + 0.06):.4f} {-(d + h/2):.4f} 0"

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
# 4. ERROR CALCULATION & MAIN LOOP
# ==========================================
def calculate_percent_error(true_val, pred_val):
    # Add small epsilon to denominator to prevent division by zero on negligible displacements
    epsilon = 1e-9
    return np.abs((true_val - pred_val) / (true_val + epsilon)) * 100

def main():
    l_bounds = [WIDTH_MIN, HEIGHT_MIN, THICK_MIN, DEPTH_MIN, BASE_Y_MIN, E_FILL_MIN, E_SOIL_MIN, PHI_MIN, LOAD_MIN]
    u_bounds = [WIDTH_MAX, HEIGHT_MAX, THICK_MAX, DEPTH_MAX, BASE_Y_MAX, E_FILL_MAX, E_SOIL_MAX, PHI_MAX, LOAD_MAX]

    sampler = qmc.LatinHypercube(d=9, seed=123)
    sample = sampler.random(n=N_TRIALS)
    scaled_samples = qmc.scale(sample, l_bounds, u_bounds)

    # Insert specific test case as the first trial
    test_case = [2.0, 2.0, 0.2, 2.0, -30.0, 40e6, 100e6, 0.5, 50000.0]
    scaled_samples[0] = test_case 

    all_errors = {field: [] for field in OUTPUT_FIELDS}
    successful_runs = 0

    print(f"Starting model verification with {N_TRIALS} trials...\n")

    for i in range(N_TRIALS):
        w, h, t, d, by, e_f, e_s, phi, load = scaled_samples[i]
        print(f"Trial {i+1}/{N_TRIALS} | W:{w:.2f} | H:{h:.2f} | D:{d:.2f} | Load:{load/1000:.1f}kPa")

        # 1. Get Model Prediction
        pred = predict_with_model(w, h, t, d, by, e_f, e_s, phi, load)

        # 2. Get MOOSE Ground Truth
        try:
            generate_mesh(w, h, t, d, by)
            update_moose_file(e_f, e_s, phi, load, w, h, d)
            run_moose()

            df_out = pd.read_csv(OUTPUT_CSV)
            moose_truth = df_out.iloc[-1].to_dict()

            # 3. Calculate Errors
            print("  Comparing outputs...")
            trial_errors = {}
            for field in OUTPUT_FIELDS:
                true_val = moose_truth.get(field, np.nan)
                pred_val = pred.get(field, np.nan)
                
                if pd.isna(true_val) or pd.isna(pred_val):
                    continue

                pct_err = calculate_percent_error(true_val, pred_val)
                all_errors[field].append(pct_err)
                trial_errors[field] = pct_err
            
            successful_runs += 1

            if i == 0:
                print("  [Test Case 0 Results]")
                for field in OUTPUT_FIELDS:
                    print(f"    {field}: MOOSE={moose_truth.get(field):.3e} | Pred={pred.get(field):.3e} | Err={trial_errors[field]:.2f}%")

        except Exception as e:
            print(f"  Trial {i+1} MOOSE execution failed: {e}")
            continue

    # ==========================================
    # 5. FINAL REPORT
    # ==========================================
    if successful_runs == 0:
        print("\nAll MOOSE runs failed. Cannot calculate accuracy.")
        return

    print("\n" + "="*50)
    print(f"OVERALL MODEL ACCURACY REPORT (Based on {successful_runs} runs)")
    print("="*50)
    print(f"{'Output Field':<20} | {'Mean Error (%)':<15} | {'Max Error (%)':<15}")
    print("-" * 50)
    
    for field in OUTPUT_FIELDS:
        if all_errors[field]:
            mean_err = np.mean(all_errors[field])
            max_err = np.max(all_errors[field])
            print(f"{field:<20} | {mean_err:<15.4f} | {max_err:<15.4f}")
        else:
            print(f"{field:<20} | N/A             | N/A")

if __name__ == "__main__":
    main()