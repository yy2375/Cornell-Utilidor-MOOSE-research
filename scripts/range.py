import pandas as pd
import numpy as np

# Load the raw data
df = pd.read_csv("training_dataset.csv")

# Extract the 7 inputs
X_raw = df.iloc[:, :7].copy()

# Apply your log10 transformation to E so the bounds make sense
X_raw.iloc[:, 0] = np.log10(X_raw.iloc[:, 0])

# Define labels based on your script
labels = [
    "Log10(Young's Modulus, E)", 
    "Poisson's Ratio (nu)", 
    "Unit Weight (gamma)", 
    "Lateral Earth Pressure (K)", 
    "Depth to Crown", 
    "Semi-Major Axis (a)", 
    "Semi-Minor Axis (b)"
]

print("\n==========================================")
print("      AI OPERATIONAL ENVELOPE (BOUNDS)    ")
print("==========================================")
print("The AI is only valid within these ranges:\n")

for i, label in enumerate(labels):
    min_val = X_raw.iloc[:, i].min()
    max_val = X_raw.iloc[:, i].max()
    print(f"{label:<30} Min: {min_val:>8.3f}  |  Max: {max_val:>8.3f}")