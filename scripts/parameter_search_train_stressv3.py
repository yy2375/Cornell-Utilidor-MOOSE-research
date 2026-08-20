import jax
import jax.numpy as jnp
import equinox as eqx
import optax
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import itertools
import time

# ==========================================
# 1. DATA PREPROCESSING
# ==========================================
def load_and_scale_data(csv_filepath):
    df = pd.read_csv(csv_filepath)
    X_raw = df.iloc[:, :9].values.astype(np.float32)
    Y_all = df.iloc[:, 9:29].values.astype(np.float32)
    
    # ISOLATE STRESSES
    target_indices = [2, 3, 4, 7, 8, 9, 12, 13, 14, 17, 18, 19]
    Y_raw = Y_all[:, target_indices]
    
    temp_scaler = StandardScaler()
    Y_scaled_temp = temp_scaler.fit_transform(Y_raw)
    valid_rows_mask = np.all(np.abs(Y_scaled_temp) < 4.0, axis=1)
    
    X_clean = X_raw[valid_rows_mask]
    Y_clean = Y_raw[valid_rows_mask]
    
    X_train, X_val, Y_train, Y_val = train_test_split(X_clean, Y_clean, test_size=0.2, random_state=42)
    
    scaler_X = StandardScaler()
    X_train_scaled = scaler_X.fit_transform(X_train).astype(np.float32)
    X_val_scaled = scaler_X.transform(X_val).astype(np.float32)
    
    scaler_Y = StandardScaler()
    Y_train_scaled = scaler_Y.fit_transform(Y_train).astype(np.float32)
    Y_val_scaled = scaler_Y.transform(Y_val).astype(np.float32)
    
    return X_train_scaled, X_val_scaled, Y_train_scaled, Y_val_scaled

# ==========================================
# 2. DYNAMIC ARCHITECTURE
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
# 3. TRAINING ENGINE
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

def train_run(X_train, Y_train, X_val, Y_val, config, max_epochs=1000):
    key = jax.random.PRNGKey(42)
    model_key, batch_key = jax.random.split(key)
    
    model = UtilidorModel(X_train.shape[1], Y_train.shape[1], config['hidden_size'], config['num_layers'], model_key)
    
    lr_schedule = optax.cosine_decay_schedule(init_value=config['lr'], decay_steps=max_epochs, alpha=0.01)
    optimizer = optax.chain(optax.clip_by_global_norm(1.0), optax.adamw(lr_schedule, weight_decay=config['weight_decay']))
    opt_state = optimizer.init(eqx.filter(model, eqx.is_array))
    
    x_jnp = jax.device_put(jnp.array(X_train))
    y_jnp = jax.device_put(jnp.array(Y_train))
    x_val_jnp = jax.device_put(jnp.array(X_val))
    y_val_jnp = jax.device_put(jnp.array(Y_val))
    
    num_samples = x_jnp.shape[0]
    best_val_loss = float('inf')
    patience_counter = 0
    
    for epoch in range(max_epochs):
        batch_key, subkey = jax.random.split(batch_key)
        indices = get_batch_indices(num_samples, min(config['batch_size'], num_samples), subkey)
        
        for batch_idx in indices:
            model, opt_state, _ = step(model, opt_state, x_jnp[batch_idx], y_jnp[batch_idx], optimizer)
        
        val_loss = evaluate_validation(model, x_val_jnp, y_val_jnp).item()
        
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            patience_counter = 0
        else:
            patience_counter += 1
            
        if patience_counter >= 50: # Tighter early stopping for the sweep
            break
            
    return best_val_loss

# ==========================================
# 4. GRID SEARCH LOGIC
# ==========================================
if __name__ == "__main__":
    csv_file = "surrogate_symmetrized_training_data.csv"
    print(f"Loading dataset...")
    X_train, X_val, Y_train, Y_val = load_and_scale_data(csv_file)
    
    # Define hyperparameter grid
    grid = {
        'batch_size': [32, 64, 128],
        'lr': [0.005, 0.001, 0.0005],
        'weight_decay': [1e-3, 1e-4],
        'hidden_size': [64, 128],
        'num_layers': [3, 4, 5]
    }
    
    keys = list(grid.keys())
    combinations = list(itertools.product(*grid.values()))
    
    print(f"Starting Hyperparameter Sweep: {len(combinations)} configurations.\n")
    
    results = []
    start_time = time.time()
    
    for i, values in enumerate(combinations):
        config = dict(zip(keys, values))
        val_mse = train_run(X_train, Y_train, X_val, Y_val, config)
        results.append((val_mse, config))
        print(f"Run {i+1:03d}/{len(combinations)} | MSE: {val_mse:.6f} | Config: {config}")
        
    elapsed = (time.time() - start_time) / 60
    
    # Sort and display results
    results.sort(key=lambda x: x[0])
    
    print("=" * 60)
    print(f"Sweep Complete in {elapsed:.1f} minutes.")
    print("Top 3 Configurations:")
    print("-" * 60)
    for rank in range(3):
        print(f"Rank {rank+1}: MSE = {results[rank][0]:.6f}")
        for k, v in results[rank][1].items():
            print(f"   {k}: {v}")
    print("=" * 60)