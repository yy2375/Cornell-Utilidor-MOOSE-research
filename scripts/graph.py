import jax
import jax.numpy as jnp
import equinox as eqx
import numpy as np
import joblib

import matplotlib
matplotlib.use('Agg') 
import matplotlib.pyplot as plt

# 1. ARCHITECTURE (Must match your trained weights)
class UtilidorModel(eqx.Module):
    layers: list
   
    def __init__(self, in_size, out_size, key):
        keys = jax.random.split(key, 5)
        self.layers = [
            eqx.nn.Linear(in_size, 192, key=keys[0]),
            eqx.nn.Linear(192, 192, key=keys[1]),
            eqx.nn.Linear(192, 192, key=keys[2]),
            eqx.nn.Linear(192, 192, key=keys[3]),
            eqx.nn.Linear(192, out_size, key=keys[4])
        ]
       
    def __call__(self, x):
        for layer in self.layers[:-1]:
            x = jax.nn.gelu(layer(x))
        return self.layers[-1](x)

def run_inference(model, scaler_X, scaler_Y, cases):
    """Predicts multiple scenarios at once."""
    cases_np = np.array(cases, dtype=np.float32)
    cases_np[:, 0] = np.log10(cases_np[:, 0]) # Log transform E
    X_scaled = scaler_X.transform(cases_np)
   
    preds_scaled = eqx.filter_vmap(model)(jnp.array(X_scaled))
   
    return scaler_Y.inverse_transform(np.array(preds_scaled))

if __name__ == "__main__":
    # 2. LOAD INFRASTRUCTURE
    key = jax.random.PRNGKey(0)
    skeleton = UtilidorModel(8, 32, key)
    try:
        model = eqx.tree_deserialise_leaves("utilidor_model (4).eqx", skeleton)
        scaler_X = joblib.load("scaler_X (4).pkl")
        scaler_Y = joblib.load("scaler_Y (4).pkl")
    except Exception as e:
        print(f"Error: {e}")
        exit()

    # 3. GENERATE DATAPOINTS: Top Load Sweep (0 to 500 kPa)
    # 500 kPa (500,000 Pa) simulates a massive surface surcharge above the utilidor
    top_loads = np.linspace(0.0, 500000.0, 50) 
    fixed_depth = 8.0 
    
    # Fixed params: [E, nu, gamma, K, depth, a, b, top_load]
    sweep_cases = [[2.3e10, 0.128, 24000.0, 1.5, fixed_depth, 1.89, 1.55, q] for q in top_loads]
    results = run_inference(model, scaler_X, scaler_Y, sweep_cases)

    # Extract specific indices
    top_stress_yy = results[:, 3]    # Crown Vertical Stress
    left_stress_yy = results[:, 27]  # Left Springline Vertical Stress
    right_stress_yy = results[:, 19] # Right Springline Vertical Stress
   
    # Theoretical Baseline (gamma * depth + top_load)
    # Soil weight is constant (24000 * 8.0), only top_load (q) changes
    theoretical = -(24000.0 * fixed_depth + top_loads)

    # 4. GRAPHING
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    # Graph A: Top Loading vs Crown Stress
    # X-axis in kPa (divide by 1000), Y-axis in MPa (divide by 1e6)
    ax1.plot(top_loads / 1000.0, theoretical / 1e6, 'r--', label=r"Theoretical Baseline ($\gamma z + q$)")
    ax1.scatter(top_loads / 1000.0, top_stress_yy / 1e6, color='blue', alpha=0.6, label="AI Prediction (Crown)")
    ax1.set_title(f"Surcharge Loading vs. Crown Stress (Depth = {fixed_depth}m)", fontsize=14)
    ax1.set_xlabel("Surface Surcharge / Top Load (kPa)")
    ax1.set_ylabel("Vertical Stress (MPa)")
    ax1.invert_yaxis() # Stress is compressive (negative)
    ax1.legend()
    ax1.grid(True, linestyle=':', alpha=0.7)

    # Graph B: Physical Symmetry Parity (Verifying loading doesn't break symmetry)
    ax2.scatter(left_stress_yy / 1e6, right_stress_yy / 1e6, color='purple', alpha=0.6)
    lims = [np.min(left_stress_yy/1e6), np.max(left_stress_yy/1e6)]
    ax2.plot(lims, lims, 'k--', alpha=0.75, zorder=0, label="Perfect Symmetry")
    ax2.set_title("Springline Parity Under Load Variation", fontsize=14)
    ax2.set_xlabel("Left Wall Vertical Stress (MPa)")
    ax2.set_ylabel("Right Wall Vertical Stress (MPa)")
    ax2.legend()
    ax2.grid(True, linestyle=':', alpha=0.7)

    plt.tight_layout()
   
    # 5. SAVE INSTEAD OF SHOW
    plt.savefig("utilidor_loading_results.png", dpi=300)
    print("\n[SUCCESS] Graphs saved as 'utilidor_loading_results.png' in your project folder.")