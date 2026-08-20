import os
import jax
import jax.numpy as jnp
import equinox as eqx
import optax
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import r2_score, mean_absolute_error
from time import perf_counter

# ==========================================
# 1. CONFIGURATION
# ==========================================
DATE_STR = "6_10"
ALGORITHMS = ["Random", "LHS", "Sobol", "Grid"]
LINEAR_N_STEPS = [128, 256, 512, 1024, 2048]

INPUT_COLS = ['input_depth', 'input_top_load', 'input_width', 'input_height', 
              'input_thickness', 'input_h_fill', 'input_e_ratio']
OUTPUT_COLS = ['u_y_crown', 'u_y_invert', 'M_roof', 'M_wall', 'sigma_vm']

EPOCHS = 5000
PATIENCE = 200  # Early stopping limit
LEARNING_RATE = 1e-3

# ==========================================
# 2. NEURAL NETWORK ARCHITECTURE (EQUINOX)
# ==========================================
class UtilidorSurrogate(eqx.Module):
    layers: list

    def __init__(self, in_size, out_size, key):
        keys = jax.random.split(key, 4)
        self.layers = [
            eqx.nn.Linear(in_size, 64, key=keys[0]),
            jax.nn.relu,
            eqx.nn.Linear(64, 64, key=keys[1]),
            jax.nn.relu,
            eqx.nn.Linear(64, 64, key=keys[2]),
            jax.nn.relu,
            eqx.nn.Linear(64, out_size, key=keys[3])
        ]

    def __call__(self, x):
        for layer in self.layers:
            x = layer(x)
        return x

@eqx.filter_value_and_grad
def compute_loss(model, x, y):
    pred_y = jax.vmap(model)(x)
    return jnp.mean((pred_y - y) ** 2)

@eqx.filter_jit
def make_step(model, x, y, opt_state, optim):
    loss, grads = compute_loss(model, x, y)
    updates, opt_state = optim.update(grads, opt_state, model)
    model = eqx.apply_updates(model, updates)
    return model, opt_state, loss

# ==========================================
# 3. TRAINING ENGINE WITH EARLY STOPPING
# ==========================================
def train_model(X_train, y_train, X_val, y_val):
    key = jax.random.PRNGKey(42)
    model = UtilidorSurrogate(in_size=len(INPUT_COLS), out_size=len(OUTPUT_COLS), key=key)
    
    optim = optax.adam(LEARNING_RATE)
    opt_state = optim.init(eqx.filter(model, eqx.is_inexact_array))

    X_train_jnp = jnp.array(X_train)
    y_train_jnp = jnp.array(y_train)
    X_val_jnp = jnp.array(X_val)
    y_val_jnp = jnp.array(y_val)

    best_val_loss = float('inf')
    best_model = model
    patience_counter = 0

    for epoch in range(EPOCHS):
        model, opt_state, train_loss = make_step(model, X_train_jnp, y_train_jnp, opt_state, optim)
        
        # Validation pass
        val_pred = jax.vmap(model)(X_val_jnp)
        val_loss = jnp.mean((val_pred - y_val_jnp) ** 2)

        # Early Stopping Logic
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            best_model = model
            patience_counter = 0
        else:
            patience_counter += 1

        if patience_counter >= PATIENCE:
            print(f"      -> Early stopping triggered at Epoch {epoch}. Best Val Loss: {best_val_loss:.6f}")
            break

    return best_model

# ==========================================
# 4. BENCHMARKING LOOP
# ==========================================
def main():
    print("========================================")
    print("PHASE 2: AI TRAINING & VERIFICATION")
    print("========================================\n")

    # 1. Load the Ground Truth "Exam" (Verification Dataset)
    verify_df = pd.read_csv(f"verification_data_{DATE_STR}.csv")
    X_verify_raw = verify_df[INPUT_COLS].values
    y_verify_raw = verify_df[OUTPUT_COLS].values
    
    results_log = []

    # 2. Iterate through all generated datasets
    for algo in ALGORITHMS:
        sample_sizes = [128, 2187] if algo == "Grid" else LINEAR_N_STEPS
        
        for n in sample_sizes:
            file_name = f"training_data_{DATE_STR}_{algo}_{n}.csv"
            if not os.path.exists(file_name):
                continue
            
            print(f"\n--- Training AI: {algo} | N={n} ---")
            start_time = perf_counter()

            # Load Data
            df = pd.read_csv(file_name)
            
            # 80/20 Train-Validation Split (for Early Stopping)
            train_idx = int(len(df) * 0.8)
            train_df = df.iloc[:train_idx]
            val_df = df.iloc[train_idx:]

            X_train = train_df[INPUT_COLS].values
            y_train = train_df[OUTPUT_COLS].values
            X_val = val_df[INPUT_COLS].values
            y_val = val_df[OUTPUT_COLS].values

            # Scale Data (Fit on train, apply to val and verification)
            scaler_X = StandardScaler().fit(X_train)
            scaler_y = StandardScaler().fit(y_train)

            X_train_s = scaler_X.transform(X_train)
            y_train_s = scaler_y.transform(y_train)
            X_val_s = scaler_X.transform(X_val)
            y_val_s = scaler_y.transform(y_val)

            # 3. Train the Model
            trained_model = train_model(X_train_s, y_train_s, X_val_s, y_val_s)
            
            train_time = perf_counter() - start_time
            print(f"      -> Training Complete in {train_time:.1f} seconds.")

            # 4. The Final Exam (Test against Verification Data)
            X_verify_s = scaler_X.transform(X_verify_raw)
            y_verify_pred_s = jax.vmap(trained_model)(jnp.array(X_verify_s))
            y_verify_pred = scaler_y.inverse_transform(np.array(y_verify_pred_s))

            # Calculate Metrics Line-by-Line
            mae = mean_absolute_error(y_verify_raw, y_verify_pred)
            r2 = r2_score(y_verify_raw, y_verify_pred)
            
            print(f"      -> Exam Graded: Global R2 = {r2:.4f} | Global MAE = {mae:.4f}")

            # 5. Log Results
            results_log.append({
                "Algorithm": algo,
                "Sample Size (N)": n,
                "R2 Score": r2,
                "Mean Absolute Error": mae,
                "Train Time (s)": round(train_time, 2)
            })

    # 6. Save Final Spreadsheet
    final_df = pd.DataFrame(results_log)
    output_excel = f"Surrogate_Benchmark_Results_{DATE_STR}.xlsx"
    final_df.to_excel(output_excel, index=False)
    print(f"\n[SUCCESS] Benchmark complete. Results compiled in {output_excel}")

if __name__ == "__main__":
    main()