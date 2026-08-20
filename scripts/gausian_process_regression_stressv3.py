import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.gaussian_process import GaussianProcessRegressor
from sklearn.gaussian_process.kernels import Matern, ConstantKernel as C
from sklearn.multioutput import MultiOutputRegressor
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error

# 1. Load Data
file_path = 'surrogate_comprehensive_training_datav2.csv'
df = pd.read_csv(file_path)

# 2. Extract specific columns using string matching
# Finds the 9 inputs (input_width ... input_load)
input_cols = [col for col in df.columns if col.startswith('input_')]

# Finds the 12 stresses (xx, yy, vm for top, invert, left, right)
stress_cols = [col for col in df.columns if 'stress' in col]

X = df[input_cols].values
y_stress = df[stress_cols].values

# 3. Split into Train/Test (80/20 split)
X_train, X_test, y_train, y_test = train_test_split(X, y_stress, test_size=0.2, random_state=42)

# 4. Scale Data
scaler_X = StandardScaler()
scaler_y = StandardScaler()

X_train_scaled = scaler_X.fit_transform(X_train)
X_test_scaled = scaler_X.transform(X_test)
y_train_scaled = scaler_y.fit_transform(y_train)
y_test_scaled = scaler_y.transform(y_test)

# 5. Define Kernel and Model
# length_scale_bounds increased to 1e5 to prevent ARD ceiling issues
kernel = C(1.0, (1e-3, 1e3)) * Matern(length_scale=[1.0]*9, length_scale_bounds=(1e-2, 1e5), nu=1.5)

base_gpr = GaussianProcessRegressor(
    kernel=kernel, 
    n_restarts_optimizer=5, # Restored to 5 to avoid local minima
    normalize_y=False,      
    random_state=42
)

# n_jobs=-1 handles the 5 restarts across all 12 models in parallel
model_stress = MultiOutputRegressor(base_gpr, n_jobs=-1)

from sklearn.gaussian_process.kernels import WhiteKernel

# Add WhiteKernel to estimate and absorb FEA numerical noise
kernel = C(1.0, (1e-3, 1e3)) * Matern(length_scale=[1.0]*9, length_scale_bounds=(1e-2, 1e5), nu=1.5) \
         + WhiteKernel(noise_level=0.1, noise_level_bounds=(1e-5, 1e1))

base_gpr = GaussianProcessRegressor(
    kernel=kernel, 
    n_restarts_optimizer=5, 
    normalize_y=False,      
    random_state=42
)

# 6. Train the Model
print(f"Training 12 Stress GPRs using inputs: {len(input_cols)} features...")
model_stress.fit(X_train_scaled, y_train_scaled)

# 7. Evaluate
y_pred_scaled = model_stress.predict(X_test_scaled)
y_pred = scaler_y.inverse_transform(y_pred_scaled) 

print("\n--- Per-Component Performance ---")
print(f"{'Stress Component':<20} | {'R2 Score':<8} | {'MAE (Physical Units)':<20}")
print("-" * 55)

r2_scores = []
for i, col in enumerate(stress_cols):
    r2_col = r2_score(y_test[:, i], y_pred[:, i])
    mae_col = mean_absolute_error(y_test[:, i], y_pred[:, i])
    r2_scores.append(r2_col)
    print(f"{col:<20} | {r2_col:>8.4f} | {mae_col:>20.2e}")

print("-" * 55)
print(f"Average R2: {np.mean(r2_scores):.4f}")

# Overall MSE for baseline comparison
mse = mean_squared_error(y_test, y_pred)
print(f"\nOverall MSE: {mse:.2e}")

# 8. Save Artifacts
joblib.dump(model_stress, 'gpr_stress_model.pkl')
joblib.dump(scaler_X, 'scaler_X_stress.pkl')
joblib.dump(scaler_y, 'scaler_y_stress.pkl')
print("\nModel and scalers saved to disk.")