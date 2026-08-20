import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler

df = pd.read_csv("training_dataset.csv")
Y_raw = df.iloc[:, 8:].values.astype(float)
Y_scaled = StandardScaler().fit_transform(Y_raw)

# Find rows where any scaled value is outside the healthy -4 to +4 range
bad_rows = np.where((Y_scaled > 4) | (Y_scaled < -4))[0]
bad_rows_unique = np.unique(bad_rows)

print(f"Found {len(bad_rows_unique)} corrupted rows.")
print("Row indices to delete in your CSV:")
print(bad_rows_unique)