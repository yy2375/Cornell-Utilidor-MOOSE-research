import os
import subprocess
import random
import numpy as np
import pandas as pd
from time import perf_counter
import jax
import jax.numpy as jnp
import equinox as eqx
import joblib

# ==========================================
# 1. NEURAL NETWORK ARCHITECTURE
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

# ==========================================
# 2. CONFIGURATION & GLOBAL INITIALIZATION
# ==========================================
N_TRIALS = 10
MOOSE_EXEC = os.path.expanduser("~/projects/dog/dog-opt") 
GMSH_EXEC = "gmsh"

TEMPLATE_GEO = "template2.geo"
TEMPLATE_MOOSE = "template2.i"
CURRENT_GEO = "current.geo"
CURRENT_MOOSE = "current.i"
OUTPUT_CSV = "concrete_utilidor_out.csv"

E_NATIVE = 100e6  # Pa (Fixed native stiffness)

# All 7 parameters are now randomized
PARAM_BOUNDS = {
    'depth': (1.0, 10.0),
    'width': (1.5, 3.0),
    'height': (1.5, 3.0),
    'thickness': (0.15, 0.50),
    'top_load': (0.0, 600000.0),
    'h_fill': (2.0, 6.0),
    'e_ratio': (0.05, 0.5)
}

# --- AI LOADING BLOCK ---
in_features = 7  # Updated for Iteration 2
out_features = 5 
key = jax.random.PRNGKey(0)
skeleton_model = UtilidorModel(in_features, out_features, key)

print("Loading model weights and scalers...")
try:
    loaded_model = eqx.tree_deserialise_leaves("concrete_utilidor_model_v2.eqx", skeleton_model)
    # Use the V2 scalers
    scaler_X = joblib.load("scaler_X_v2.pkl") 
    scaler_Y = joblib.load("scaler_Y_v2.pkl")
except FileNotFoundError as e:
    print(f"CRITICAL ERROR: {e}")
    print("Ensure the .eqx and .pkl files are in the same folder as this script.")
    exit()
# ---------------------------------

# ==========================================
# 3. PIPELINE FUNCTIONS
# ==========================================
def generate_random_params():
    return {k: random.uniform(v[0], v[1]) for k, v in PARAM_BOUNDS.items()}

def predict_with_ai(params):
    """Passes 7 parameters through the scaled JAX model."""
    # Strict order matching your V2 training CSV: 
    # depth, load, width, height, thickness, h_fill, e_ratio
    test_case = [
        params['depth'], 
        params['top_load'], 
        params['width'], 
        params['height'], 
        params['thickness'],
        params['h_fill'],
        params['e_ratio']
    ]
    
    new_inputs_np = np.array([test_case], dtype=np.float32)
    inputs_scaled = scaler_X.transform(new_inputs_np)
    
    jax_input = jnp.array(inputs_scaled[0], dtype=jnp.float32)
    prediction_scaled = loaded_model(jax_input)

    prediction_scaled_np = jax.device_get(prediction_scaled)
    prediction_unscaled = scaler_Y.inverse_transform([prediction_scaled_np])
    
    return prediction_unscaled[0].astype(np.float32)

def run_moose_ground_truth(params):
    """Generates V2 multi-layer mesh, runs FEM, and calculates results."""
    d = params['depth']
    w = params['width']
    h = params['height']
    t = params['thickness']
    load = params['top_load']
    h_f = params['h_fill']
    e_r = params['e_ratio']

    # 1. Mesh Generation
    with open(TEMPLATE_GEO, 'r') as file: geo_data = file.read()
    geo_data = geo_data.replace('depth = DefineNumber[ 5.0, Name "Parameters/d" ];', f'depth = {d};')
    geo_data = geo_data.replace('height = DefineNumber[ 2.0, Name "Parameters/h" ];', f'height = {h};')
    geo_data = geo_data.replace('width = DefineNumber[ 2.0, Name "Parameters/w" ];', f'width = {w};')
    geo_data = geo_data.replace('thickness = DefineNumber[ 0.2, Name "Parameters/t" ];', f'thickness = {t};')
    geo_data = geo_data.replace('H_fill = DefineNumber[ 4.0, Name "Parameters/H_fill" ];', f'H_fill = {h_f};')
    with open(CURRENT_GEO, 'w') as file: file.write(geo_data)
        
    subprocess.run([GMSH_EXEC, "-2", CURRENT_GEO, "-o", "test2_shell.msh", "-v", "0"], check=True)

    # 2. MOOSE Configuration
    with open(TEMPLATE_MOOSE, 'r') as file: moose_data = file.read()
    moose_data = moose_data.replace("top_load = 3e5", f"top_load = {load}")
    moose_data = moose_data.replace("H_fill = 4.0", f"H_fill = {h_f}")
    
    e_fill_actual = E_NATIVE * e_r
    moose_data = moose_data.replace("youngs_modulus_fill = 15e6", f"youngs_modulus_fill = {e_fill_actual}")
    
    moose_data = moose_data.replace("'CROWN_OUTER'", f"'0 {-d} 0'")
    moose_data = moose_data.replace("'CROWN_INNER'", f"'0 {-d - t} 0'")
    moose_data = moose_data.replace("'INVERT_INNER'", f"'0 {-d - h + t} 0'")
    moose_data = moose_data.replace("'WALL_OUTER'", f"'{w/2.0} {-d - h/2.0} 0'")
    moose_data = moose_data.replace("'WALL_INNER'", f"'{w/2.0 - t} {-d - h/2.0} 0'")
    moose_data = moose_data.replace("'CORNER_INNER'", f"'{w/2.0 - t} {-d - t} 0'")
    with open(CURRENT_MOOSE, 'w') as file: file.write(moose_data)

    subprocess.run([MOOSE_EXEC, "-i", CURRENT_MOOSE], check=True)

    # 3. Extraction & Math
    df_out = pd.read_csv(OUTPUT_CSV)
    results = df_out.iloc[-1].to_dict()

    sigma_roof_top = results.get('roof_stress_top', 0)
    sigma_roof_bot = results.get('roof_stress_bottom', 0)
    M_roof = abs(sigma_roof_top - sigma_roof_bot) * (t**2) / 12.0
    
    sigma_wall_out = results.get('wall_stress_outer', 0)
    sigma_wall_in = results.get('wall_stress_inner', 0)
    M_wall = abs(sigma_wall_out - sigma_wall_in) * (t**2) / 12.0
    
    vm_max = results.get('max_sigma_vm', 0)

    truth = np.array([
        results.get('u_y_crown', 0), 
        results.get('u_y_invert', 0), 
        M_roof, 
        M_wall, 
        vm_max
    ], dtype=np.float32)
    
    return truth

# ==========================================
# 4. MAIN VALIDATION LOOP
# ==========================================
def main():
    print(f"Starting {N_TRIALS} validation trials for V2 Model...\n")
    
    errors = []
    truths_log = []
    preds_log = []

    start_time = perf_counter()

    for i in range(N_TRIALS):
        params = generate_random_params()
        
        y_true = run_moose_ground_truth(params)
        y_pred = predict_with_ai(params)
        
        truths_log.append(y_true)
        preds_log.append(y_pred)
        
        trial_error = np.abs(y_true - y_pred)
        errors.append(trial_error)
        
        if (i + 1) % 10 == 0:
            print(f"Completed {i + 1}/{N_TRIALS} trials...")

    # --- STATISTICAL ANALYSIS ---
    truths_log = np.array(truths_log)
    preds_log = np.array(preds_log)
    errors = np.array(errors)

    mae = np.mean(errors, axis=0)
    max_err = np.max(errors, axis=0)
    
    ss_res = np.sum((truths_log - preds_log) ** 2, axis=0)
    ss_tot = np.sum((truths_log - np.mean(truths_log, axis=0)) ** 2, axis=0)
    r2_scores = 1 - (ss_res / ss_tot)

    print("\n" + "="*40)
    print("VALIDATION RESULTS (ITERATION 2)")
    print("="*40)
    print(f"Total Time: {perf_counter() - start_time:.2f} seconds\n")
    
    labels = ["u_y_crown", "u_y_invert", "M_roof", "M_wall", "sigma_vm"]
    for idx, label in enumerate(labels):
        print(f"--- {label} ---")
        print(f"R^2 Score      : {r2_scores[idx]:.4f}")
        print(f"Mean Abs Error : {mae[idx]:.4e}")
        print(f"Max Abs Error  : {max_err[idx]:.4e}")
        print("")

if __name__ == "__main__":
    main()