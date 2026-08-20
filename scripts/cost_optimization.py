import jax
import jax.numpy as jnp
import equinox as eqx
import numpy as np
import joblib
from scipy.optimize import minimize
from time import perf_counter

# ==========================================
# 1. AI SURROGATE MODEL DEFINITION
# ==========================================
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

def predict_scenario(model, scaler_X, scaler_Y, inputs):
    """
    Inputs array format: [depth, top_load, width, height, thickness]
    """
    new_inputs_np = np.array([inputs], dtype=float)
    
    # Retaining log10 scaling on depth (index 0) if utilized during training
    new_inputs_np[0, 0] = np.log10(new_inputs_np[0, 0]) 
    
    inputs_scaled = scaler_X.transform(new_inputs_np)
    prediction_scaled = model(jnp.array(inputs_scaled[0]))
    prediction_unscaled = scaler_Y.inverse_transform([prediction_scaled])
    
    return prediction_unscaled[0]

# ==========================================
# 2. MANHATTAN OPTIMIZATION SETUP
# ==========================================
if __name__ == "__main__":
    
    print("Loading AI infrastructure (192-width architecture)...")
    try:
        # 5 inputs, 5 outputs for iteration 1 dataset
        skeleton_model = UtilidorModel(5, 5, jax.random.PRNGKey(0))
        trained_model = eqx.tree_deserialise_leaves("concrete_utilidor_model.eqx", skeleton_model)
        scaler_X = joblib.load("scaler_X.pkl")
        scaler_Y = joblib.load("scaler_Y.pkl")
    except FileNotFoundError as e:
        print(f"Error loading files: {e}\nEnsure the .eqx and .pkl files are in the working directory.")
        exit()

    # --- Site Constraints & Constants ---
    INTERNAL_WIDTH = 1.6     # m (Fixed clearance requirement)
    INTERNAL_HEIGHT = 1.6    # m (Fixed clearance requirement)
    TOP_LOAD = 300000.0      # Pa (NYC Traffic Load)
    ALLOWABLE_STRESS = 15e6  # Pa (Yield limit with safety factor for concrete)

    # --- Cost Weighting Factors ---
    # Adjust these to heavily penalize deep excavation vs concrete volume
    COST_WEIGHT_EXCAVATION = 5000.0 
    COST_WEIGHT_CONCRETE = 1500.0

    def objective_function(x):
        """Minimize the combined financial/logistical cost of the trench and structure."""
        t_guess, d_guess = x[0], x[1]
        
        concrete_cost = COST_WEIGHT_CONCRETE * t_guess
        excavation_cost = COST_WEIGHT_EXCAVATION * d_guess
        
        return concrete_cost + excavation_cost

    def stress_constraint(x):
        """Ensure the peak Von Mises stress remains below the allowable limit."""
        t_guess, d_guess = x[0], x[1]
        
        # Calculate outer dimensions based on the guessed thickness
        outer_w = INTERNAL_WIDTH + (2 * t_guess)
        outer_h = INTERNAL_HEIGHT + (2 * t_guess)
        
        # Array: [depth, top_load, width, height, thickness]
        inputs = [d_guess, TOP_LOAD, outer_w, outer_h, t_guess]
        predictions = predict_scenario(trained_model, scaler_X, scaler_Y, inputs)
        
        # Output mapping: [u_y_crown, u_y_invert, M_roof, M_wall, sigma_vm]
        sigma_vm = predictions[4] 
        
        # SLSQP requires inequality constraints to be >= 0 to pass
        return ALLOWABLE_STRESS - sigma_vm

    # ==========================================
    # 3. SLSQP EXECUTION
    # ==========================================
    # Bounds: Thickness (0.1m - 0.5m), Depth (1.0m - 10.0m)
    bounds = [(0.10, 0.50), (1.0, 10.0)]
    cons = {'type': 'ineq', 'fun': stress_constraint}
    
    # Multi-start guesses to avoid local minima [thickness, depth]
    initial_guesses = [
        [0.30, 5.0],  # Standard starting point
        [0.15, 2.0],  # Aggressively thin and shallow
        [0.45, 8.0]   # Thick and deep
    ]
    
    best_result = None
    lowest_cost = float('inf')
    
    print("Running Multi-Start SLSQP Optimization...")
    
    start_time = perf_counter()
    
    for i, guess in enumerate(initial_guesses):
        result = minimize(
            objective_function, 
            guess, 
            method='SLSQP', 
            bounds=bounds, 
            constraints=cons
        )
        
        if result.success and result.fun < lowest_cost:
            lowest_cost = result.fun
            best_result = result
            
        print(f"   Run {i+1} completed. Calculated Cost Index: {result.fun:.2f}")
        
    calc_time = perf_counter() - start_time

    # ==========================================
    # 4. RESULTS OUTPUT
    # ==========================================
    if best_result is not None:
        opt_t, opt_d = best_result.x
        
        # Re-run prediction to output the exact final structural metrics
        final_w = INTERNAL_WIDTH + (2 * opt_t)
        final_h = INTERNAL_HEIGHT + (2 * opt_t)
        final_inputs = [opt_d, TOP_LOAD, final_w, final_h, opt_t]
        final_preds = predict_scenario(trained_model, scaler_X, scaler_Y, final_inputs)
        
        final_sigma = final_preds[4]
        
        print("\n==========================================")
        print("          OPTIMIZATION SUCCESSFUL         ")
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
        print("\nOptimization Failed. The applied load may exceed the structural capacity across all bounded dimensions.")