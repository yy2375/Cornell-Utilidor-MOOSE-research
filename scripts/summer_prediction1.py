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
N_TRIALS = 100
MOOSE_EXEC = "./your_app-opt" 
GMSH_EXEC = "gmsh"

TEMPLATE_GEO = "template.geo"
TEMPLATE_MOOSE = "template.i"
CURRENT_GEO = "current.geo"
CURRENT_MOOSE = "current.i"
OUTPUT_CSV = "verification.csv"

PARAM_BOUNDS = {
    'depth': (2.0, 15.0),
    'top_load': (50000.0, 300000.0), # Assuming Pascal input based on your 200000.0 test case
    'width': (2.0, 6.0),
    'height': (2.0, 5.0),
    'thickness': (0.2, 0.6)
}

# Pre-load AI model to RAM once
in_features = 5  
out_features = 5 
key = jax.random.PRNGKey(0)
skeleton_model = UtilidorModel(in_features, out_features, key)

print("Loading model weights and scalers...")
loaded_model = eqx.tree_deserialise_leaves("concrete_utilidor_model.eqx", skeleton_model)
scaler_X = joblib.load("scaler_X.pkl")
scaler_Y = joblib.load("scaler_Y.pkl")

# ==========================================
# 3. PIPELINE FUNCTIONS
# ==========================================
def generate_random_params():
    return {k: random.uniform(v[0], v[1]) for k, v in PARAM_BOUNDS.items()}

def predict_with_ai(params):
    """Passes parameters through the scaled JAX model."""
    # Ensure exact order: depth, top_load, width, height, thickness
    test_case = [
        params['depth'], 
        params['top_load'], 
        params['width'], 
        params['height'], 
        params['thickness']
    ]
    
    new_inputs_np = np.array([test_case], dtype=float)
    inputs_scaled = scaler_X.transform(new_inputs_np)
    
    prediction_scaled = loaded_model(jnp.array(inputs_scaled[0]))
    prediction_unscaled = scaler_Y.inverse_transform([prediction_scaled])
    
    return prediction_unscaled[0].astype(np.float32)

def run_moose_ground_truth(params):
    """Generates mesh, runs FEM, and extracts exact CSV results."""
    with open(TEMPLATE_GEO, 'r') as f: geo_text = f.read()
    for key, val in params.items():
        geo_text = geo_text.replace(f'${{{key}}}', str(val))
    with open(CURRENT_GEO, 'w') as f: f.write(geo_text)
        
    subprocess.run([GMSH_EXEC, CURRENT_GEO, "-2", "-format", "msh2", "-o", "current.msh"], capture_output=True)

    with open(TEMPLATE_MOOSE, 'r') as f: moose_text = f.read()
    for key, val in params.items():
        moose_text = moose_text.replace(f'${{{key}}}', str(val))
    with open(CURRENT_MOOSE, 'w') as f: f.write(moose_text)

    subprocess.run([MOOSE_EXEC, "-i", CURRENT_MOOSE], capture_output=True)

    # Extract exact results
    df = pd.read_csv(OUTPUT_CSV)
    
    # CRITICAL: These headers must exactly match your MOOSE CSV output headers.
    truth = df.iloc[-1][['u_y_crown', 'u_y_invert', 'M_roof', 'M_wall', 'sigma_vm']].values
    return truth.astype(np.float32)

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