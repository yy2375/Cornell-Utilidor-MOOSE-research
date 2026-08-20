import jax
import jax.numpy as jnp
import equinox as eqx
import optax
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import joblib




def load_and_scale_data(csv_filepath):
    print("Loading data...")
    df = pd.read_csv(csv_filepath)
    
    
    X_raw = df.iloc[:, :5].values.astype(np.float32)
    
    Y_raw = df.iloc[:, 5:10].values.astype(np.float32) 
    
    
    temp_scaler = StandardScaler()
    Y_scaled_temp = temp_scaler.fit_transform(Y_raw)
    valid_rows_mask = np.all(np.abs(Y_scaled_temp) < 4.0, axis=1)
    
    X_clean = X_raw[valid_rows_mask]
    Y_clean = Y_raw[valid_rows_mask]
    
    dropped_count = len(X_raw) - len(X_clean)
    print(f"Auto-Filter removed {dropped_count} corrupted/extreme MOOSE runs.")
    
    
    X_train, X_val, Y_train, Y_val = train_test_split(X_clean, Y_clean, test_size=0.2, random_state=42)
    
    
    scaler_X = StandardScaler()
    X_train_scaled = scaler_X.fit_transform(X_train).astype(np.float32)
    X_val_scaled = scaler_X.transform(X_val).astype(np.float32)
    
    
    scaler_Y = StandardScaler()
    Y_train_scaled = scaler_Y.fit_transform(Y_train).astype(np.float32)
    Y_val_scaled = scaler_Y.transform(Y_val).astype(np.float32)
    
    return X_train_scaled, X_val_scaled, Y_train_scaled, Y_val_scaled, scaler_X, scaler_Y




def get_batch_indices(num_samples, batch_size, key):
    indices = jax.random.permutation(key, num_samples)
    num_batches = num_samples // batch_size
    indices = indices[:num_batches * batch_size]
    return indices.reshape((num_batches, batch_size))




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




def compute_loss(model, x, y_true):
    """Pure Mean Squared Error (MSE) - No Physics."""
    y_pred_scaled = jax.vmap(model)(x)
    mse = jnp.mean((y_pred_scaled - y_true) ** 2)
    return mse

@eqx.filter_jit
def step(model, opt_state, x, y, optimizer):
    loss, grads = jax.value_and_grad(compute_loss)(model, x, y)
    updates, opt_state = optimizer.update(grads, opt_state, model)
    model = eqx.apply_updates(model, updates)
    return model, opt_state, loss

@eqx.filter_jit
def evaluate_validation(model, x_val, y_val):
    return compute_loss(model, x_val, y_val)




def train_model(X_train, Y_train, X_val, Y_val, epochs=5000, batch_size=256):
    print(f"Initializing pure data-driven model (Batch Size: {batch_size})...")
    key = jax.random.PRNGKey(42)
    model_key, batch_key = jax.random.split(key)
    
    in_size = X_train.shape[1]
    out_size = Y_train.shape[1]
    model = UtilidorModel(in_size, out_size, model_key)
    
    
    lr_schedule = optax.cosine_decay_schedule(init_value=0.001, decay_steps=epochs, alpha=0.01)
    optimizer = optax.chain(optax.clip_by_global_norm(1.0), optax.adam(lr_schedule))
    opt_state = optimizer.init(eqx.filter(model, eqx.is_array))
    
    
    x_jnp = jax.device_put(jnp.array(X_train))
    y_jnp = jax.device_put(jnp.array(Y_train))
    x_val_jnp = jax.device_put(jnp.array(X_val))
    y_val_jnp = jax.device_put(jnp.array(Y_val))
    
    num_samples = x_jnp.shape[0]
    
    print("Starting training loop...")
    try:
        for epoch in range(epochs):
            batch_key, subkey = jax.random.split(batch_key)
            
            
            current_batch_size = min(batch_size, num_samples)
            indices = get_batch_indices(num_samples, current_batch_size, subkey)
            
            batch_losses = []
            for i in range(indices.shape[0]):
                batch_idx = indices[i]
                model, opt_state, loss = step(model, opt_state, x_jnp[batch_idx], y_jnp[batch_idx], optimizer)
                batch_losses.append(loss.item())
                
            if epoch % 100 == 0 or epoch == epochs - 1:
                train_loss = sum(batch_losses) / len(batch_losses)
                val_loss = evaluate_validation(model, x_val_jnp, y_val_jnp).item()
                print(f"Epoch {epoch:04d} | Train MSE: {train_loss:.6f} | Val MSE: {val_loss:.6f}")
                
    except KeyboardInterrupt:
        print("\n[!] Training interrupted by user. Preserving current weights...")
        
    return model




def predict_new_scenario(model, scaler_X, scaler_Y, new_inputs):
    new_inputs_np = np.array([new_inputs], dtype=float)
    inputs_scaled = scaler_X.transform(new_inputs_np)
    prediction_scaled = model(jnp.array(inputs_scaled[0]))
    prediction_unscaled = scaler_Y.inverse_transform([prediction_scaled])
    return prediction_unscaled[0]




if __name__ == "__main__":
    csv_file = "surrogate_training_data.csv" 
    trained_model = None 
    
    try:
        X_train, X_val, Y_train, Y_val, scaler_X, scaler_Y = load_and_scale_data(csv_file)
        
        
        trained_model = train_model(X_train, Y_train, X_val, Y_val, epochs=5000, batch_size=256) 
        
        print("\nTesting Inference Engine...")
        
        test_case = [5.0, 300000.0, 2.0, 2.0, 0.2]
        results = predict_new_scenario(trained_model, scaler_X, scaler_Y, test_case)
        print(f"Predicted Outputs [u_y_crown, u_y_invert, M_roof, M_wall, sigma_vm]:\n{results}") 
            
    except FileNotFoundError:
        print(f"Error: Could not find {csv_file}.")
    except Exception as e:
        print(f"\n[!] Unexpected error in execution block: {e}")
        
    finally:
        if trained_model is not None:
            print("\nSaving AI model and scalers to disk...")
            try:
                eqx.tree_serialise_leaves("concrete_utilidor_model.eqx", trained_model)
                joblib.dump(scaler_X, "scaler_X.pkl")
                joblib.dump(scaler_Y, "scaler_Y.pkl")
                print("Success: AI model saved securely.")
            except Exception as save_err:
                print(f"CRITICAL: Failed to save the model! Error: {save_err}")