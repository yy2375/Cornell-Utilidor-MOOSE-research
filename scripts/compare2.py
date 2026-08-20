import pandas as pd
import numpy as np

# Define file paths to your MOOSE CSV outputs
FILE_SCENARIO_A = 'output_instant_contact2.csv'
FILE_SCENARIO_B = 'output_sequential_contact2.csv'

# Updated variable list reflecting the intersection of columns from both outputs
TARGET_VARIABLES = [
    'invert_disp_y',
    'invert_plastic_strain',
    'invert_stress_vm',
    'left_disp_x',
    'left_plastic_strain',
    'left_stress_vm',
    'max_compressive_yy_concrete',
    'max_compressive_yy_ground',
    'max_plastic_strain_soil',
    'max_principal_stress_concrete',
    'max_settlement_y',
    'max_tensile_yy_concrete',
    'max_vm_concrete',
    'max_vm_ground',
    'right_disp_x',
    'right_plastic_strain',
    'right_stress_vm',
    'top_disp_y',
    'top_plastic_strain',
    'top_stress_vm'
]

def main():
    try:
        df_a = pd.read_csv(FILE_SCENARIO_A).iloc[-1]
        df_b = pd.read_csv(FILE_SCENARIO_B).iloc[-1]
    except FileNotFoundError as e:
        print(f"Error loading files: {e}")
        return
    except KeyError:
        print("Error: CSV format mismatch.")
        return

    epsilon = 1e-12 

    print(f"\n{'=== MOOSE SCENARIO COMPARISON (FINAL TIMESTEP) ==='}")
    print(f"{'Variable Name':<32} | {'Instant2':<15} | {'Sequential2':<15} | {'Abs Delta':<12} | {'% Error'}")
    print("-" * 95)

    for var in TARGET_VARIABLES:
        if var not in df_a.index or var not in df_b.index:
            print(f"{var:<32} | {'--- MISSING DATA IN ONE OR BOTH FILES ---'}")
            continue

        val_a = float(df_a[var])
        val_b = float(df_b[var])

        abs_delta = np.abs(val_a - val_b)
        pct_diff = (abs_delta / (np.abs(val_b) + epsilon)) * 100

        print(f"{var:<32} | {val_a:<15.4e} | {val_b:<15.4e} | {abs_delta:<12.4e} | {pct_diff:.3f}%")
        
    print("\n* % Error uses Sequential2 as the baseline.")

if __name__ == "__main__":
    main()