import gc
import jax
import jax.numpy as jnp
import equinox as eqx
import optax
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
import joblib

# 1. DATA PREPROCESSING MODULE
def load_and_scale_data(csv_filepath):
    print("Loading data...")
    df = pd.read_csv(csv_filepath)
    
    X_raw = df.iloc[:, :8].values.astype(np.float32)
    X_raw[:, 0] = np.log10(X_raw[:, 0]) 
    Y_raw = df.iloc[:, 8:].values.astype(np.float32)
    
    temp_scaler = StandardScaler()
    Y_scaled_temp = temp_scaler.fit_transform(Y_raw)
    valid_rows_mask = np.all(np.abs(Y_scaled_temp) < 3.0, axis=1)
    
    X_clean = X_raw[valid_rows_mask]
    Y_clean = Y_raw[valid_rows_mask]
    
    dropped_count = len(X_raw) - len(X_clean)
    print(f"Auto-Filter removed {dropped_count} corrupted MOOSE runs.")
    
    scaler_X = StandardScaler()
    X_scaled = scaler_X.fit_transform(X_clean).astype(np.float32)
    
    scaler_Y = StandardScaler()
    scaler_Y.fit(Y_clean) 
    
    noise_threshold = 1e-4
    noise_columns = np.where(scaler_Y.scale_ < noise_threshold)[0]
    
    if len(noise_columns) > 0:
        print(f"Patched {len(noise_columns)} columns of symmetry noise.")
        scaler_Y.scale_[noise_columns] = 1.0 
        scaler_Y.mean_[noise_columns] = 0.0
    
    Y_scaled = scaler_Y.transform(Y_clean).astype(np.float32)
    
    return X_scaled, Y_scaled, scaler_X, scaler_Y, X_clean

# 2. BATCH GENERATOR
def get_batch_indices(num_samples, batch_size, key):
    indices = jax.random.permutation(key, num_samples)
    num_batches = num_samples // batch_size
    indices = indices[:num_batches * batch_size]
    return indices.reshape((num_batches, batch_size))

# 3. NEURAL NETWORK ARCHITECTURE
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

def compute_loss(model, x, y_true, unscaled_x, scaler_y_mean, scaler_y_scale, current_lambda):
    y_pred_scaled = jax.vmap(model)(x)
    mse_data = jnp.mean((y_pred_scaled - y_true) ** 2)
    
    y_pred_unscaled = (y_pred_scaled * scaler_y_scale) + scaler_y_mean
    
    # 1. EXTRACT ALL 8 VARIABLES
    E = 10.0 ** unscaled_x[:, 0]   
    nu = unscaled_x[:, 1]          
    gamma = unscaled_x[:, 2]       
    K = unscaled_x[:, 3]           
    depth_crown = unscaled_x[:, 4] 
    a = unscaled_x[:, 5]           
    b = unscaled_x[:, 6]           
    top_load = unscaled_x[:, 7] 
    
    # Depth coordinates
    z_top = depth_crown
    z_bottom = depth_crown + (2.0 * b)
    z_mid = depth_crown + b
    
    # 2. SEPARATE SOIL WEIGHT FROM SURCHARGE LOAD
    s_v_soil_top = -1.0 * (gamma * z_top)
    s_v_soil_bot = -1.0 * (gamma * z_bottom)
    s_v_soil_mid = -1.0 * (gamma * z_mid)
    
    s_v_surcharge = -1.0 * top_load
    s_h_surcharge = K * s_v_surcharge
    
    s_v0_top = s_v_soil_top + s_v_surcharge
    s_h0_top = (K * s_v_soil_top) + s_h_surcharge
    
    s_v0_bot = s_v_soil_bot + s_v_surcharge
    s_h0_bot = (K * s_v_soil_bot) + s_h_surcharge
    
    s_v0_mid = s_v_soil_mid + s_v_surcharge
    s_h0_mid = (K * s_v_soil_mid) + s_h_surcharge

    stiffness_normal = E / ((1.0 + nu) * (1.0 - 2.0 * nu))
    stiffness_shear = E / (1.0 + nu)

    # 3. FULL PLANE-STRAIN EQUILIBRIUM
    # --- TOP POINT ---
    s_xx_top = y_pred_unscaled[:, 2]
    s_yy_top = y_pred_unscaled[:, 3] 
    s_xy_top = y_pred_unscaled[:, 4]
    e_xx_top = y_pred_unscaled[:, 5] 
    e_yy_top = y_pred_unscaled[:, 6] 
    e_xy_top = y_pred_unscaled[:, 7]
    
    s_xx_ind_top = stiffness_normal * ((1.0 - nu) * e_xx_top + nu * e_yy_top)
    s_yy_ind_top = stiffness_normal * ((1.0 - nu) * e_yy_top + nu * e_xx_top)
    s_xy_ind_top = stiffness_shear * e_xy_top
    
    err_xx_top = s_xx_top - (s_h0_top + s_xx_ind_top)
    err_yy_top = s_yy_top - (s_v0_top + s_yy_ind_top)
    err_xy_top = s_xy_top - s_xy_ind_top
    
    loss_top = (err_xx_top**2 + err_yy_top**2 + err_xy_top**2) / (s_v0_top**2 + 1e4)

    # --- BOTTOM POINT ---
    s_xx_bot = y_pred_unscaled[:, 10]
    s_yy_bot = y_pred_unscaled[:, 11]
    s_xy_bot = y_pred_unscaled[:, 12]
    e_xx_bot = y_pred_unscaled[:, 13] 
    e_yy_bot = y_pred_unscaled[:, 14] 
    e_xy_bot = y_pred_unscaled[:, 15]
    
    s_xx_ind_bot = stiffness_normal * ((1.0 - nu) * e_xx_bot + nu * e_yy_bot)
    s_yy_ind_bot = stiffness_normal * ((1.0 - nu) * e_yy_bot + nu * e_xx_bot)
    s_xy_ind_bot = stiffness_shear * e_xy_bot
    
    err_xx_bot = s_xx_bot - (s_h0_bot + s_xx_ind_bot)
    err_yy_bot = s_yy_bot - (s_v0_bot + s_yy_ind_bot)
    err_xy_bot = s_xy_bot - s_xy_ind_bot
    
    loss_bot = (err_xx_bot**2 + err_yy_bot**2 + err_xy_bot**2) / (s_v0_bot**2 + 1e4)

    # --- RIGHT POINT ---
    s_xx_right = y_pred_unscaled[:, 18]
    s_yy_right = y_pred_unscaled[:, 19]
    s_xy_right = y_pred_unscaled[:, 20]
    e_xx_right = y_pred_unscaled[:, 21] 
    e_yy_right = y_pred_unscaled[:, 22] 
    e_xy_right = y_pred_unscaled[:, 23]
    
    s_xx_ind_right = stiffness_normal * ((1.0 - nu) * e_xx_right + nu * e_yy_right)
    s_yy_ind_right = stiffness_normal * ((1.0 - nu) * e_yy_right + nu * e_xx_right)
    s_xy_ind_right = stiffness_shear * e_xy_right
    
    err_xx_right = s_xx_right - (s_h0_mid + s_xx_ind_right)
    err_yy_right = s_yy_right - (s_v0_mid + s_yy_ind_right)
    err_xy_right = s_xy_right - s_xy_ind_right
    
    loss_right = (err_xx_right**2 + err_yy_right**2 + err_xy_right**2) / (s_v0_mid**2 + 1e4)

    # --- LEFT POINT ---
    s_xx_left = y_pred_unscaled[:, 26]
    s_yy_left = y_pred_unscaled[:, 27]
    s_xy_left = y_pred_unscaled[:, 28]
    e_xx_left = y_pred_unscaled[:, 29] 
    e_yy_left = y_pred_unscaled[:, 30] 
    e_xy_left = y_pred_unscaled[:, 31]
    
    s_xx_ind_left = stiffness_normal * ((1.0 - nu) * e_xx_left + nu * e_yy_left)
    s_yy_ind_left = stiffness_normal * ((1.0 - nu) * e_yy_left + nu * e_xx_left)
    s_xy_ind_left = stiffness_shear * e_xy_left
    
    err_xx_left = s_xx_left - (s_h0_mid + s_xx_ind_left)
    err_yy_left = s_yy_left - (s_v0_mid + s_yy_ind_left)
    err_xy_left = s_xy_left - s_xy_ind_left
    
    loss_left = (err_xx_left**2 + err_yy_left**2 + err_xy_left**2) / (s_v0_mid**2 + 1e4)
                             
    physics_residual = jnp.mean(loss_top + loss_bot + loss_right + loss_left)
    
    total_loss = mse_data + (current_lambda * physics_residual)
    return total_loss, (mse_data, physics_residual)

@eqx.filter_jit
def step(model, opt_state, x, y, unscaled_x, scaler_y_mean, scaler_y_scale, optimizer, current_lambda):
    (loss, (mse_data, physics_residual)), grads = jax.value_and_grad(compute_loss, has_aux=True)(
        model, x, y, unscaled_x, scaler_y_mean, scaler_y_scale, current_lambda
    )
    updates, opt_state = optimizer.update(grads, opt_state, model)
    model = eqx.apply_updates(model, updates)
    return model, opt_state, loss, mse_data, physics_residual

# 5. MODIFIED TRAIN MODEL
def train_model(X_scaled, Y_scaled, X_raw, scaler_Y, epochs=30000, batch_size=256):
    print(f"Initializing model and optimizer (Batch Size: {batch_size})...")
    key = jax.random.PRNGKey(42)
    model_key, batch_key = jax.random.split(key)
    
    model = UtilidorModel(X_scaled.shape[1], Y_scaled.shape[1], model_key)
    
    # Applied Cosine Decay Schedule
    lr_schedule = optax.cosine_decay_schedule(
        init_value=0.001, 
        decay_steps=epochs, 
        alpha=0.01  # Minimum learning rate will be 0.00001 at the final epoch
    )
    optimizer = optax.chain(optax.clip_by_global_norm(1.0), optax.adam(lr_schedule))
    opt_state = optimizer.init(eqx.filter(model, eqx.is_array))
    
    x_jnp = jax.device_put(jnp.array(X_scaled))
    y_jnp = jax.device_put(jnp.array(Y_scaled))
    x_unscaled_jnp = jax.device_put(jnp.array(X_raw))
    y_mean = jax.device_put(jnp.array(scaler_Y.mean_))
    y_scale = jax.device_put(jnp.array(scaler_Y.scale_))
    
    num_samples = x_jnp.shape[0]
    
    print("Starting training loop from scratch...")
    try:
        for epoch in range(epochs):
            batch_key, subkey = jax.random.split(batch_key)
            
            # Physics Annealing
            if epoch < 2000:
                current_lambda = 0.0
            elif epoch < 10000:
                progress = (epoch - 2000) / 8000.0
                current_lambda = progress * 1.0
            else:
                current_lambda = 1.0
                
            current_lambda_jnp = jnp.array(current_lambda, dtype=jnp.float32)
                
            batch_losses, batch_mses, batch_phys = [], [], []
            
            indices = get_batch_indices(num_samples, batch_size, subkey)
            
            if epoch == 0:
                print("Compiling JAX computational graph (this takes a moment)...")

            for i in range(indices.shape[0]):
                batch_idx = indices[i]
                
                x_batch = x_jnp[batch_idx]
                y_batch = y_jnp[batch_idx]
                x_raw_batch = x_unscaled_jnp[batch_idx]
                
                model, opt_state, loss, mse, phys = step(
                    model, opt_state, x_batch, y_batch, x_raw_batch, y_mean, y_scale, optimizer, current_lambda_jnp
                )
                
                batch_losses.append(loss.item())
                batch_mses.append(mse.item())
                batch_phys.append(phys.item())
                
            epoch_loss = sum(batch_losses) / len(batch_losses)
            epoch_mse = sum(batch_mses) / len(batch_mses)
            epoch_phys = sum(batch_phys) / len(batch_phys)
            
            # [!] THE FIX: Indented this block by 4 spaces so it runs INSIDE the loop
            if epoch % 100 == 0 or epoch == epochs - 1:
                print(f"Epoch {epoch}: Total={epoch_loss:.6f} | Data={epoch_mse:.6f} | Physics={epoch_phys:.6f}")
                
    except KeyboardInterrupt:
        print("\n[!] Training interrupted by user. Preserving current weights...")
    except Exception as e:
        print(f"\n[!] Training aborted due to an error: {e}. Preserving current weights...")
        
    return model

# 6. PREDICTION INTERFACE
def predict_new_scenario(model, scaler_X, scaler_Y, new_inputs):
    new_inputs_np = np.array([new_inputs], dtype=float)
    new_inputs_np[0, 0] = np.log10(new_inputs_np[0, 0]) 
    
    inputs_scaled = scaler_X.transform(new_inputs_np)
    prediction_scaled = model(jnp.array(inputs_scaled[0]))
    prediction_unscaled = scaler_Y.inverse_transform([prediction_scaled])
    
    return prediction_unscaled[0]

# ==========================================
# EXECUTION BLOCK
# ==========================================
if __name__ == "__main__":
    csv_file = "training_dataset.csv" 
    trained_model = None # Initialize as None so the 'finally' block doesn't error out
    
    try:
        X_scaled, Y_scaled, scaler_X, scaler_Y, X_raw = load_and_scale_data(csv_file)
        
        trained_model = train_model(X_scaled, Y_scaled, X_raw, scaler_Y, epochs=30000, batch_size=256) 
        
        print("\nTesting Inference Engine...")
        test_case = [3.36e10, 0.128, 24000.0, 0.5, 27.0, 1.5, 2.0, 1000000.0]
        results = predict_new_scenario(trained_model, scaler_X, scaler_Y, test_case)
        print(f"Sample Result Output: {results[:4]}...") 
            
    except FileNotFoundError:
        print(f"Error: Could not find {csv_file}.")
    except Exception as e:
        print(f"\n[!] Unexpected error in execution block: {e}")
        
    finally:
        # NEW: This runs NO MATTER WHAT. If trained_model exists, it gets saved.
        if trained_model is not None:
            print("\nSaving AI model and scalers to disk...")
            try:
                eqx.tree_serialise_leaves("utilidor_model.eqx", trained_model)
                joblib.dump(scaler_X, "scaler_X.pkl")
                joblib.dump(scaler_Y, "scaler_Y.pkl")
                print("Success: AI model saved securely.")
            except Exception as save_err:
                print(f"CRITICAL: Failed to save the model! Error: {save_err}")
                
