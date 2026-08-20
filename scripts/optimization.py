import jax
import jax.numpy as jnp
import equinox as eqx
import numpy as np
import joblib
from scipy.optimize import minimize

# 1. NEURAL NETWORK ARCHITECTURE (UPDATED TO 192 WIDTH / 5 LAYERS)
class UtilidorModel(eqx.Module):
    layers: list

    def __init__(self, in_size, out_size, key):
        # Increased split to 5 for the deeper architecture
        keys = jax.random.split(key, 5) 
        self.layers = [
            eqx.nn.Linear(in_size, 192, key=keys[0]), # Layer 1: Input to Hidden
            eqx.nn.Linear(192, 192, key=keys[1]),     # Layer 2: Hidden to Hidden
            eqx.nn.Linear(192, 192, key=keys[2]),     # Layer 3: Hidden to Hidden
            eqx.nn.Linear(192, 192, key=keys[3]),     # Layer 4: Hidden to Hidden
            eqx.nn.Linear(192, out_size, key=keys[4]) # Layer 5: Hidden to Output
        ]

    def __call__(self, x):
        # Apply tanh activation to all but the final layer
        for layer in self.layers[:-1]:
            x = jax.nn.gelu(layer(x))
        return self.layers[-1](x)

# 2. PREDICTION HELPER FUNCTION
def predict_scenario(model, scaler_X, scaler_Y, inputs):
    new_inputs_np = np.array([inputs], dtype=float)
    new_inputs_np[0, 0] = np.log10(new_inputs_np[0, 0]) 
    
    inputs_scaled = scaler_X.transform(new_inputs_np)
    prediction_scaled = model(jnp.array(inputs_scaled[0]))
    prediction_unscaled = scaler_Y.inverse_transform([prediction_scaled])
    
    return prediction_unscaled[0]

# ==========================================
# EXECUTION BLOCK
# ==========================================
if __name__ == "__main__":
    
    # 3. LOAD INFRASTRUCTURE
    print("Loading AI infrastructure (192-width architecture)...")
    try:
        # Create skeleton matching the 192x5 structure
        skeleton_model = UtilidorModel(8, 32, jax.random.PRNGKey(0))
        loaded_model = eqx.tree_deserialise_leaves("utilidor_model (4).eqx", skeleton_model)
        scaler_X = joblib.load("scaler_X (4).pkl")
        scaler_Y = joblib.load("scaler_Y (4).pkl")
    except FileNotFoundError as e:
        print(f"Error loading files: {e}. Ensure the .eqx and .pkl files are in this directory.")
        exit()

    # 4. DEFINE FIXED ENVIRONMENTAL PARAMETERS
    E_val = 3.6e10           # Young's Modulus (Pa)
    nu_val = 0.4            # Poisson's Ratio
    gamma_val = 29000.0     # Unit Weight (N/m^3)
    K_val = 1.1             # Lateral Earth Pressure Coefficient
    depth_val = 2.0         # Depth to Crown (m)
    top_load_val = 1000000.0 # Surface Load (Pa)
    
    # 5. DEFINE CONSTRAINTS
    target_area = 15.0      # Cross-sectional area constraint (m^2)
    
    def area_constraint(x):
        a, b = x[0], x[1]
        area = np.pi * a * b
        return area - target_area 

    # 6. DEFINE OBJECTIVE FUNCTION
    def objective_function(x):
        a, b = x[0], x[1]
        inputs = [E_val, nu_val, gamma_val, K_val, depth_val, a, b, top_load_val]
        predictions = predict_scenario(loaded_model, scaler_X, scaler_Y, inputs)
        
        # Stress Indices mapping:
        # 2: top_stress_xx, 10: bottom_stress_xx, 19: right_stress_yy, 27: left_stress_yy
        critical_stresses = [predictions[2], predictions[10], predictions[19], predictions[27]]
        
        # Minimize the maximum absolute stress magnitude
        return np.max(np.abs(critical_stresses))

    # 7. OPTIMIZATION SETUP
    bounds = [(0.5, 5.0), (0.5, 5.0)]
    cons = {'type': 'eq', 'fun': area_constraint}
    
    initial_guesses = [
        [2.185, 2.185],  # Circular
        [1.0, 4.77],     # Tall Oval
        [4.77, 1.0]      # Wide Oval
    ]
    
    best_result = None
    lowest_stress = float('inf')
    
    print("Running Multi-Start SLSQP Optimization...")
    
    for i, guess in enumerate(initial_guesses):
        result = minimize(
            objective_function, 
            guess, 
            method='SLSQP', 
            bounds=bounds, 
            constraints=cons
        )
        
        if result.success and result.fun < lowest_stress:
            lowest_stress = result.fun
            best_result = result
            
        print(f"   Run {i+1} completed. Found stress: {result.fun:.2e} Pa")

    # 8. OUTPUT RESULTS
    if best_result is not None:
        opt_a, opt_b = best_result.x
        print("\n==========================================")
        print("          OPTIMIZATION SUCCESSFUL         ")
        print("==========================================")
        print(f"Optimal Semi-Major (a): {opt_a:.4f} m")
        print(f"Optimal Semi-Minor (b): {opt_b:.4f} m")
        print(f"Resulting Area:         {(np.pi * opt_a * opt_b):.4f} m^2")
        print(f"Minimized Max Stress:   {best_result.fun:.2e} Pa")
    else:
        print("\nOptimization Failed.")