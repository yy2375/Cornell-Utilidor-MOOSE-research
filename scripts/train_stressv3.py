import jax
import jax.numpy as jnp
import equinox as eqx
import optax
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import joblib
import time

# ==========================================
# 1. DATA PREPROCESSING
# ==========================================
def load_and_scale_data(csv_filepath):
    print(f"Loading augmented stress data from {csv_filepath}...")
    df = pd.read_csv(csv_filepath)
    
    # ISOLATE INPUTS (9 Base + 8 Displacements)
    base_cols = [
        'input_width', 'input_height', 'input_thickness', 'input_depth', 
        'input_base_y', 'input_e_fill', 'input_e_soil', 'input_phi', 'input_load'
    ]
    disp_cols = [col for col in df.columns if 'disp' in col]
    X_raw = df[base_cols + disp_cols].values.astype(np.float32)
    
    # ISOLATE OUTPUTS (12 Stresses)
    stress_cols = [col for col in df.columns if 'stress' in col]
    Y_raw = df[stress_cols].values.astype(np.float32)
    
    # Outlier Rejection
    temp_scaler = StandardScaler()
    Y_scaled_temp = temp_scaler.fit_transform(Y_raw)
    valid_rows_mask = np.all(np.abs(Y_scaled_temp) < 4.0, axis=1)
    
    X_clean = X_raw[valid_rows_mask]
    Y_clean = Y_raw[valid_rows_mask]
    
    print(f"Removed {len(Y_raw) - len(Y_clean)} outliers. Remaining samples: {len(Y_clean)}")
    
    X_train, X_val, Y_train, Y_val = train_test_split(X_clean, Y_clean, test_size=0.2, random_state=42)
    
    scaler_X = StandardScaler()
    X_train_scaled = scaler_X.fit_transform(X_train).astype(np.float32)
    X_val_scaled = scaler_X.transform(X_val).astype(np.float32)
    
    scaler_Y = StandardScaler()
    Y_train_scaled = scaler_Y.fit_transform(Y_train).astype(np.float32)
    Y_val_scaled = scaler_Y.transform(Y_val).astype(np.float32)
    
    return X_train_scaled, X_val_scaled, Y_train_scaled, Y_val_scaled, scaler_X, scaler_Y

# ==========================================
# 2. DYNAMIC ARCHITECTURE
# ==========================================
class UtilidorModel(eqx.Module):
    layers: list

    def __init__(self, in_size, out_size, hidden_size, num_layers, key):
        keys = jax.random.split(key, num_layers + 1)
        
        # Input layer
        self.layers = [eqx.nn.Linear(in_size, hidden_size, key=keys[0])]
        
        # Hidden layers
        for i in range(num_layers - 1):
            self.layers.append(eqx.nn.Linear(hidden_size, hidden_size, key=keys[i+1]))
            
        # Output layer
        self.layers.append(eqx.nn.Linear(hidden_size, out_size, key=keys[-1]))

    def __call__(self, x):
        for layer in self.layers[:-1]:
            x = jax.nn.gelu(layer(x))
        return self.layers[-1](x)

# ==========================================
# 3. TRAINING LOGIC
# ==========================================
def get_batch_indices(num_samples, batch_size, key):
    indices = jax.random.permutation(key, num_samples)
    num_batches = num_samples // batch_size
    return indices[:num_batches * batch_size].reshape((num_batches, batch_size))

def compute_loss(model, x, y_true):
    return jnp.mean((jax.vmap(model)(x) - y_true) ** 2)

@eqx.filter_jit
def step(model, opt_state, x, y, optimizer):
    loss, grads = jax.value_and_grad(compute_loss)(model, x, y)
    updates, opt_state = optimizer.update(grads, opt_state, model)
    return eqx.apply_updates(model, updates), opt_state, loss

@eqx.filter_jit
def evaluate_validation(model, x_val, y_val):
    return compute_loss(model, x_val, y_val)

def train_model(X_train, Y_train, X_val, Y_val, config, epochs=3000):
    key = jax.random.PRNGKey(42)
    model_key, batch_key = jax.random.split(key)
    
    model = UtilidorModel(X_train.shape[1], Y_train.shape[1], config['hidden_size'], config['num_layers'], model_key)
    
    lr_schedule = optax.cosine_decay_schedule(init_value=config['lr'], decay_steps=epochs, alpha=0.01)
    optimizer = optax.chain(optax.clip_by_global_norm(1.0), optax.adamw(lr_schedule, weight_decay=config['weight_decay']))
    opt_state = optimizer.init(eqx.filter(model, eqx.is_array))
    
    x_jnp = jax.device_put(jnp.array(X_train))
    y_jnp = jax.device_put(jnp.array(Y_train))
    x_val_jnp = jax.device_put(jnp.array(X_val))
    y_val_jnp = jax.device_put(jnp.array(Y_val))
    
    num_samples = x_jnp.shape[0]
    best_val_loss, best_model, patience_counter = float('inf'), model, 0
    
    for epoch in range(epochs):
        batch_key, subkey = jax.random.split(batch_key)
        indices = get_batch_indices(num_samples, min(config['batch_size'], num_samples), subkey)
        
        for batch_idx in indices:
            model, opt_state, _ = step(model, opt_state, x_jnp[batch_idx], y_jnp[batch_idx], optimizer)
        
        val_loss = evaluate_validation(model, x_val_jnp, y_val_jnp).item()
        
        if val_loss < best_val_loss:
            best_val_loss, best_model, patience_counter = val_loss, model, 0
        else:
            patience_counter += 1
            
        if patience_counter >= 200:
            print(f"Early stopping triggered at epoch {epoch}. Best Val Loss: {best_val_loss:.6f}")
            break
            
    return best_val_loss, best_model

# ==========================================
# 4. FINAL TRAINING EXECUTION
# ==========================================
if __name__ == "__main__":
    # 1. Point to the augmented dataset
    csv_file = "surrogate_symmetrized_training_data.csv"
    X_train, X_val, Y_train, Y_val, scaler_X, scaler_Y = load_and_scale_data(csv_file)
    
    print(f"Training on {X_train.shape[0]} samples, Validating on {X_val.shape[0]} samples.\n")
    
    # 2. Hardcoded optimal configuration
    best_config = {
        'batch_size': 64,
        'lr': 0.001,
        'weight_decay': 0.001,
        'hidden_size': 64,
        'num_layers': 4
    }
    
    print(f"Starting Final Training Run | Config: {best_config}\n")
    
    start_time = time.time()
    
    # 3. Train the model
    val_mse, final_model = train_model(X_train, Y_train, X_val, Y_val, best_config)
    
    # 4. Save Final Model Artifacts for Stress
    eqx.tree_serialise_leaves("stress_model_final.eqx", final_model)
    joblib.dump(scaler_X, "scaler_X_stress_final.pkl")
    joblib.dump(scaler_Y, "scaler_Y_stress_final.pkl")
    
    elapsed = (time.time() - start_time) / 60
    print("="*40)
    print(f"Training Complete in {elapsed:.1f} minutes.")
    print(f"Final Validation MSE: {val_mse:.6f}")
    print("Model 'stress_model_final.eqx' and scalers saved successfully.")