import jax
import jax.numpy as jnp
import equinox as eqx
import pandas as pd
import numpy as np
import joblib
from sklearn.metrics import mean_squared_error, mean_absolute_error

# ==========================================
# 1. ARCHITECTURE DEFINITION
# ==========================================
class UtilidorModel(eqx.Module):
    layers: list

    def __init__(self, in_size, out_size, hidden_size, num_layers, key):
        keys = jax.random.split(key, num_layers + 1)
        self.layers = [eqx.nn.Linear(in_size, hidden_size, key=keys[0])]
        for i in range(num_layers - 1):
            self.layers.append(eqx.nn.Linear(hidden_size, hidden_size, key=keys[i+1]))
        self.layers.append(eqx.nn.Linear(hidden_size, out_size, key=keys[-1]))

    def __call__(self, x):
        for layer in self.layers[:-1]:
            x = jax.nn.gelu(layer(x))
        return self.layers[-1](x)

# ==========================================
# 2. EXECUTION
# ==========================================
if __name__ == "__main__":
    print("Loading artifacts...")
    
    # 1. Load Scalers
    scaler_X = joblib.load("scaler_X_disp_final.pkl")
    scaler_Y = joblib.load("scaler_Y_disp_final.pkl")
    
    # 2. Load Raw Dataset
    raw_csv = "surrogate_comprehensive_training_datav2.csv"
    print(f"Loading raw dataset from {raw_csv}...")
    df = pd.read_csv(raw_csv)
    
    X_raw = df.iloc[:, :9].values.astype(np.float32)
    Y_all = df.iloc[:, 9:29].values.astype(np.float32)
    
    # Isolate the 8 displacement targets
    target_indices = [0, 1, 5, 6, 10, 11, 15, 16]
    Y_raw_disp = Y_all[:, target_indices]
    
    # Apply the same outlier filter used during training for a fair baseline
    from sklearn.preprocessing import StandardScaler
    temp_scaler = StandardScaler()
    Y_scaled_temp = temp_scaler.fit_transform(Y_raw_disp)
    valid_rows_mask = np.all(np.abs(Y_scaled_temp) < 4.0, axis=1)
    
    X_test = X_raw[valid_rows_mask]
    Y_test_actual = Y_raw_disp[valid_rows_mask]
    print(f"Testing on {len(X_test)} valid samples (filtered {len(X_raw) - len(X_test)} outliers).")

    # 3. Scale Inputs
    X_test_scaled = scaler_X.transform(X_test)
    X_jnp = jax.device_put(jnp.array(X_test_scaled))

    # 4. Initialize Model and Load Weights
    # Configuration matches your best_config for displacement: 
    # in_size=9, out_size=8, hidden_size=64, num_layers=4
    key = jax.random.PRNGKey(0)
    model_skeleton = UtilidorModel(9, 8, 64, 4, key)
    model = eqx.tree_deserialise_leaves("disp_model_final.eqx", model_skeleton)

    # 5. Run Inference
    print("Running inference...")
    @jax.jit
    def predict_batch(x):
        return jax.vmap(model)(x)
    
    Y_pred_scaled = predict_batch(X_jnp)
    
    # 6. Inverse Transform to Physical Units
    Y_pred_actual = scaler_Y.inverse_transform(np.array(Y_pred_scaled))

    # ==========================================
    # 3. METRICS & REPORTING
    # ==========================================
    # Calculate Scaled MSE (matches training loss format)
    Y_test_scaled = scaler_Y.transform(Y_test_actual)
    scaled_mse = mean_squared_error(Y_test_scaled, np.array(Y_pred_scaled))
    
    # Calculate Physical Error Metrics
    physical_mse = mean_squared_error(Y_test_actual, Y_pred_actual)
    physical_mae = mean_absolute_error(Y_test_actual, Y_pred_actual)
    
    # Calculate Max Error across the dataset
    max_error = np.max(np.abs(Y_test_actual - Y_pred_actual))

    print("\n" + "="*40)
    print("DISPLACEMENT MODEL ACCURACY (vs. Raw Data)")
    print("="*40)
    print(f"Scaled MSE (Training Metric): {scaled_mse:.6f}")
    print(f"Physical MSE (Real Units):    {physical_mse:.6f}")
    print(f"Physical MAE (Real Units):    {physical_mae:.6f}")
    print(f"Max Absolute Error:           {max_error:.6f}")
    print("="*40)
    print("Note: This error represents the deviation between the model's")
    print("perfectly symmetric predictions and the raw dataset's meshing noise.")