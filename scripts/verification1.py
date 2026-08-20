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

TEMPLATE_GEO = "template.geo"
TEMPLATE_MOOSE = "template.i"
CURRENT_GEO = "current.geo"
CURRENT_MOOSE = "current.i"
OUTPUT_CSV = "concrete_utilidor_out.csv"

PARAM_BOUNDS = {
    'depth': (1.5, 10.0),
    'top_load': (0.0, 600000.0)
}

FIXED_PARAMS = {
    'width': 2.0,
    'height': 2.0,
    'thickness': 0.2
}

# --- RESTORED AI LOADING BLOCK ---
in_features = 5  
out_features = 5 
key = jax.random.PRNGKey(0)
skeleton_model = UtilidorModel(in_features, out_features, key)

print("Loading model weights and scalers...")
try:
    loaded_model = eqx.tree_deserialise_leaves("concrete_utilidor_model.eqx", skeleton_model)
    scaler_X = joblib.load("scaler_X.pkl")
    scaler_Y = joblib.load("scaler_Y.pkl")
except FileNotFoundError as e:
    print(f"CRITICAL ERROR: {e}")
    print("Ensure the .eqx and .pkl files are in the same folder as this script.")
    exit()
# ---------------------------------

# ==========================================
# 3. PIPELINE FUNCTIONS
# ==========================================
def generate_random_params():
    params = {k: random.uniform(v[0], v[1]) for k, v in PARAM_BOUNDS.items()}
    params.update(FIXED_PARAMS)
    return params

def predict_with_ai(params):
    """Passes parameters through the scaled JAX model with strict type handling."""
    test_case = [
        params['depth'], 
        params['top_load'], 
        params['width'], 
        params['height'], 
        params['thickness']
    ]
    
    new_inputs_np = np.array([test_case], dtype=np.float32)
    inputs_scaled = scaler_X.transform(new_inputs_np)
    
    jax_input = jnp.array(inputs_scaled[0], dtype=jnp.float32)
    prediction_scaled = loaded_model(jax_input)

    prediction_scaled_np = jax.device_get(prediction_scaled)
    prediction_unscaled = scaler_Y.inverse_transform([prediction_scaled_np])
    
    return prediction_unscaled[0].astype(np.float32)

def run_moose_ground_truth(params):
    """Generates mesh, runs FEM, calculates derived metrics, and returns exact results."""
    with open(TEMPLATE_GEO, 'r') as file: geo_data = file.read()
    geo_data = geo_data.replace('depth = DefineNumber[ 2, Name "Parameters/d" ];', f"depth = {params['depth']};")
    geo_data = geo_data.replace('height = DefineNumber[ 2, Name "Parameters/h" ];', f"height = {params['height']};")
    geo_data = geo_data.replace('width = DefineNumber[ 2, Name "Parameters/w" ];', f"width = {params['width']};")
    geo_data = geo_data.replace('thickness = DefineNumber[ 0.2, Name "Parameters/t" ];', f"thickness = {params['thickness']};")
    with open(CURRENT_GEO, 'w') as file: file.write(geo_data)
        
    subprocess.run([GMSH_EXEC, "-2", CURRENT_GEO, "-o", "rect_shell.msh", "-v", "0"], check=True)

    with open(TEMPLATE_MOOSE, 'r') as file: moose_data = file.read()
    moose_data = moose_data.replace("top_load = 6e5", f"top_load = {params['top_load']}")
    
    d, w, h, t = params['depth'], params['width'], params['height'], params['thickness']
    moose_data = moose_data.replace("'CROWN_OUTER'", f"'0 {-d} 0'")
    moose_data = moose_data.replace("'CROWN_INNER'", f"'0 {-d - t} 0'")
    moose_data = moose_data.replace("'INVERT_INNER'", f"'0 {-d - h + t} 0'")
    moose_data = moose_data.replace("'WALL_OUTER'", f"'{w/2.0} {-d - h/2.0} 0'")
    moose_data = moose_data.replace("'WALL_INNER'", f"'{w/2.0 - t} {-d - h/2.0} 0'")
    moose_data = moose_data.replace("'CORNER_INNER'", f"'{w/2.0 - t} {-d - t} 0'")
    with open(CURRENT_MOOSE, 'w') as file: file.write(moose_data)

    subprocess.run([MOOSE_EXEC, "-i", CURRENT_MOOSE], check=True)

    df_out = pd.read_csv(OUTPUT_CSV)
    results = df_out.iloc[-1].to_dict()

    sigma_roof_top = results.get('roof_stress_top', 0)
    sigma_roof_bot = results.get('roof_stress_bottom', 0)
    M_roof = abs(sigma_roof_top - sigma_roof_bot) * (t**2) / 12.0
    
    sigma_wall_out = results.get('wall_stress_outer', 0)
    sigma_wall_in = results.get('wall_stress_inner', 0)
    M_wall = abs(sigma_wall_out - sigma_wall_in) * (t**2) / 12.0
    
    s_xx = results.get('corner_stress_xx', 0)
    s_yy = results.get('corner_stress_yy', 0)
    vm_corner = np.sqrt(s_xx**2 - s_xx*s_yy + s_yy**2)

    truth = np.array([
        results['u_y_crown'], 
        results['u_y_invert'], 
        M_roof, 
        M_wall, 
        vm_corner
    ], dtype=np.float32)
    
    return truth

# ==========================================
# 4. MAIN VALIDATION LOOP
# ==========================================
def main():
    print(f"Starting {N_TRIALS} validation trials...\n")
    
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
    print("VALIDATION RESULTS")
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