import pandas as pd
import numpy as np

# Define file paths to your MOOSE CSV outputs
FILE_INSTANT = 'output_instant_contact.csv'
FILE_SEQUENTIAL = 'output_sequential_contact.csv'

# The complete list of postprocessor variables tracked in the models
TARGET_VARIABLES = [
    # --- Global Extreme Values ---
    'max_disp_x',
    'min_disp_x',
    'max_settlement_y',
    'max_vm_ground',
    'max_vm_concrete',
    'max_compressive_yy_ground',
    'max_compressive_yy_concrete',
    'max_tensile_yy_concrete',
    'max_principal_stress_concrete',
    'max_plastic_strain_soil',
    
    # --- 1:1 Comparison Point Trackers (Utilidor & Surface) ---
    'crown_disp_y',
    'crown_stress_yy',
    'crown_vm_stress',
    'invert_disp_y',
    'invert_stress_yy',
    'invert_vm_stress',
    'surface_disp_y',
    'left_wall_disp_x',
    'left_wall_vm_stress',
    'right_wall_disp_x',
    'right_wall_vm_stress',
    
    # --- Localized Plasticity (5cm offsets) ---
    'top_plastic_strain',
    'invert_plastic_strain',
    'left_plastic_strain',
    'right_plastic_strain'
]

def main():
    try:
        # Load the CSVs
        df_inst_full = pd.read_csv(FILE_INSTANT)
        df_seq_full = pd.read_csv(FILE_SEQUENTIAL)
        
        # FIX: Strip trailing/leading whitespaces from MOOSE CSV headers
        df_inst_full.columns = df_inst_full.columns.str.strip()
        df_seq_full.columns = df_seq_full.columns.str.strip()

        # Isolate the final row (last timestep at t=16.0)
        df_inst = df_inst_full.iloc[-1]
        df_seq = df_seq_full.iloc[-1]
        
    except FileNotFoundError as e:
        print(f"Error loading files: {e}")
        print("Ensure both MOOSE simulations have finished and CSVs are in this directory.")
        return

    # Epsilon prevents division by zero
    epsilon = 1e-12 

    # Formatted output table
    print(f"\n{'=== MOOSE SCENARIO COMPARISON: INSTANT VS SEQUENTIAL CONTACT ==='}")
    print(f"{'Variable Name':<32} | {'Instant Contact':<17} | {'Sequential Contact':<18} | {'Abs Delta':<12} | {'% Error'}")
    print("-" * 110)

    missing_vars = []

    for var in TARGET_VARIABLES:
        # Safety check for missing columns
        if var not in df_inst.index or var not in df_seq.index:
            print(f"{var:<32} | {'--- MISSING DATA ---'}")
            missing_vars.append(var)
            continue

        val_inst = df_inst[var]
        val_seq = df_seq[var]

        # Calculate differences
        abs_delta = np.abs(val_inst - val_seq)
        
        # Calculate percentage error using Sequential as the baseline
        pct_diff = (abs_delta / (np.abs(val_seq) + epsilon)) * 100

        # Print formatted row
        print(f"{var:<32} | {val_inst:<17.4e} | {val_seq:<18.4e} | {abs_delta:<12.4e} | {pct_diff:.3f}%")
        
    print("\n* % Error uses Sequential Contact as the baseline.")

    # FIX: Debugger to list actual column names if mismatches occur
    if missing_vars:
        print("\n--- DEBUG: MISSING VARIABLES ---")
        print("The script could not find the variables above. Here are the actual columns in your Instant CSV:")
        print(df_inst_full.columns.tolist())

if __name__ == "__main__":
    main()