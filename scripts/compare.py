import pandas as pd
import numpy as np

# Define file paths to your MOOSE CSV outputs
FILE_SCENARIO_A = 'output_instant_contact.csv'  # Instant Loading
FILE_SCENARIO_B = 'output_C_15_layer.csv'       # Sequential Backfill

# The complete list of postprocessor variables tracked in the models
TARGET_VARIABLES = [
    'max_disp_x',
    'min_disp_x',
    'max_settlement_y',
    'max_vm_ground',
    'max_vm_concrete',
    'max_vm_steel',
    'max_compressive_yy_ground',
    'max_compressive_yy_concrete',
    'max_tensile_yy_concrete',
    'max_compressive_yy_steel',
    'max_principal_stress_concrete',
    'max_plastic_strain_steel'
]

def main():
    try:
        # Load the CSVs and isolate the final row (last timestep)
        # Using .iloc[-1] ensures we only compare the final loaded state at the end of the simulation
        df_a = pd.read_csv(FILE_SCENARIO_A).iloc[-1]
        df_b = pd.read_csv(FILE_SCENARIO_B).iloc[-1]
    except FileNotFoundError as e:
        print(f"Error loading files: {e}")
        print("Ensure the MOOSE simulations have finished and the CSV files are in the same directory as this script.")
        return
    except KeyError:
         print("Error: The CSVs do not appear to have the expected format. Ensure MOOSE ran successfully.")
         return

    # Epsilon prevents division by zero if a variable (like plasticity) is exactly 0.0
    epsilon = 1e-12 

    # Set up the formatted output table
    print(f"\n{'=== MOOSE SCENARIO COMPARISON (FINAL TIMESTEP) ==='}")
    print(f"{'Variable Name':<32} | {'A: Instant':<15} | {'B: Sequential':<15} | {'Abs Delta':<12} | {'% Error'}")
    print("-" * 95)

    for var in TARGET_VARIABLES:
        # Safety check in case a variable is missing from the CSV
        if var not in df_a.index or var not in df_b.index:
            print(f"{var:<32} | {'--- MISSING DATA ---'}")
            continue

        val_a = df_a[var]
        val_b = df_b[var]

        # Calculate differences
        abs_delta = np.abs(val_a - val_b)
        
        # Calculate percentage error using Scenario B (Sequential) as the true physical baseline
        pct_diff = (abs_delta / (np.abs(val_b) + epsilon)) * 100

        # Print formatted row
        print(f"{var:<32} | {val_a:<15.4e} | {val_b:<15.4e} | {abs_delta:<12.4e} | {pct_diff:.3f}%")
        
    print("\n* % Error uses Scenario B (Sequential) as the baseline.")

if __name__ == "__main__":
    main()