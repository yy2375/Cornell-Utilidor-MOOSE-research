import jax
import jax.numpy as jnp
import equinox as eqx
import numpy as np
import joblib

# 1. NEURAL NETWORK ARCHITECTURE
class UtilidorModel(eqx.Module):
    layers: list

    def __init__(self, in_size, out_size, key):
        # Ensure we split enough keys for the layers
        keys = jax.random.split(key, 5) 
        self.layers = [
            eqx.nn.Linear(in_size, 192, key=keys[0]), # MATCH TRAINING WIDTH (192)
            eqx.nn.Linear(192, 192, key=keys[1]),
            eqx.nn.Linear(192, 192, key=keys[2]),
            eqx.nn.Linear(192, 192, key=keys[3]),
            eqx.nn.Linear(192, out_size, key=keys[4])
        ]

    def __call__(self, x):
        for layer in self.layers[:-1]:
            x = jax.nn.gelu(layer(x)) 
        return self.layers[-1](x)

if __name__ == "__main__":
    # 2. DIMENSIONS
    in_features = 8  # CHANGED: 7 to 8 for top_load
    out_features = 32 
    
    # 3. INITIALIZE SKELETON
    key = jax.random.PRNGKey(0)
    skeleton_model = UtilidorModel(in_features, out_features, key)
    
    # 4. LOAD WEIGHTS AND SCALERS
    try:
        loaded_model = eqx.tree_deserialise_leaves("utilidor_model (2).eqx", skeleton_model)
        scaler_X = joblib.load("scaler_X (2).pkl")
        scaler_Y = joblib.load("scaler_Y (2).pkl")
    except FileNotFoundError as e:
        print(f"Error loading files: {e}. Ensure the .eqx and .pkl files are in the same directory.")
        exit()
    
    # 5. EXECUTE PREDICTION
    # Format: [E, nu, gamma, K, depth, a, b, top_load]
    # CHANGED: Added 1000000.0 (1 MPa) as the 8th parameter
    test_case = [2.3e10, 0.128, 24000.0, 1.5, 8.0, 3.78/2, 3.11/2, 10000.0]
    # CHANGED: Enforced dtype=float to prevent JAX TypeErrors with mixed int/float arrays
    new_inputs_np = np.array([test_case], dtype=float)
    new_inputs_np[0, 0] = np.log10(new_inputs_np[0, 0]) # Log transform E
    
    inputs_scaled = scaler_X.transform(new_inputs_np)
    prediction_scaled = loaded_model(jnp.array(inputs_scaled[0]))
    prediction_unscaled = scaler_Y.inverse_transform([prediction_scaled])
    
    # 6. FORMATTED OUTPUT
    output_labels = [
        "top_disp_x", "top_disp_y", "top_stress_xx", "top_stress_yy", "top_stress_xy", "top_strain_xx", "top_strain_yy", "top_strain_xy",
        "bottom_disp_x", "bottom_disp_y", "bottom_stress_xx", "bottom_stress_yy", "bottom_stress_xy", "bottom_strain_xx", "bottom_strain_yy", "bottom_strain_xy",
        "right_disp_x", "right_disp_y", "right_stress_xx", "right_stress_yy", "right_stress_xy", "right_strain_xx", "right_strain_yy", "right_strain_xy",
        "left_disp_x", "left_disp_y", "left_stress_xx", "left_stress_yy", "left_stress_xy", "left_strain_xx", "left_strain_yy", "left_strain_xy"
    ]

    print("\n==========================================")
    print("      UTILIDOR SURROGATE PREDICTION       ")
    print("==========================================")
    
    results = prediction_unscaled[0]

    print("SCALED INPUTS: ", inputs_scaled[0])
    print("SCALED PREDICTION: ", prediction_scaled)
    
    for label, val in zip(output_labels, results):
        # The :<20 ensures the labels are left-aligned with a width of 20 characters
        # The :.6e formats the number in scientific notation with 6 decimal places
        print(f"{label:<20}: {val:.6e}")