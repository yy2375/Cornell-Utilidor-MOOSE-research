import os
import re
import subprocess
import pandas as pd
import numpy as np

# ==========================================
# CONFIGURATION
# ==========================================
# Replace with the path to your compiled MOOSE application
MOOSE_EXEC = "./dog-opt" 
BASE_INPUT_FILE = "summer3_script.i"

# Define the dtmax values to test. The first value is treated as the "ground truth" baseline.
DTMAX_TEST_VALUES = [ 0.1, 100]

# Metrics to track for variance (adjust based on critical parameters)
TARGET_METRICS = [
    'top_disp_y', 'top_stress_vm', 
    'invert_disp_y', 'invert_stress_vm',
    'left_disp_x', 'right_disp_x'
]

# ==========================================
# EXECUTION LOGIC
# ==========================================
def modify_and_run(dtmax_val, run_id):
    """Modifies dtmax and file_base, runs MOOSE, and returns the final time step results."""
    
    with open(BASE_INPUT_FILE, 'r') as file:
        content = file.read()
        
    # Update dtmax in Executioner block
    content = re.sub(r'dtmax\s*=\s*[\d\.]+', f'dtmax = {dtmax_val}', content)
    
    # Update file_base in Outputs block to prevent overwriting
    csv_base = f'dtmax_test_{run_id}'
    content = re.sub(r"file_base\s*=\s*'.*?'", f"file_base = '{csv_base}'", content)
    
    temp_input = f"temp_run_{run_id}.i"
    with open(temp_input, 'w') as file:
        file.write(content)
        
    print(f"Running MOOSE with dtmax = {dtmax_val}...")
    try:
        subprocess.run([MOOSE_EXEC, "-i", temp_input], check=True)
    except subprocess.CalledProcessError as e:
        print(f"MOOSE execution failed for dtmax={dtmax_val}")
        return None
    finally:
        if os.path.exists(temp_input):
            os.remove(temp_input)
            
    # Read the generated CSV and extract the final row
    csv_filename = f"{csv_base}.csv"
    if os.path.exists(csv_filename):
        df = pd.read_csv(csv_filename)
        final_row = df.iloc[-1]
        
        # Cleanup output files
        for ext in ['.csv', '_e.exo']:
            f = f"{csv_base}{ext}"
            if os.path.exists(f): os.remove(f)
            
        return final_row
    return None

# ==========================================
# MAIN ROUTINE
# ==========================================
if __name__ == "__main__":
    if not os.path.exists(BASE_INPUT_FILE):
        print(f"Error: Base input file '{BASE_INPUT_FILE}' not found.")
        exit(1)
        
    results = []
    baseline_data = None
    
    for i, dt in enumerate(DTMAX_TEST_VALUES):
        final_state = modify_and_run(dt, i)
        
        if final_state is not None:
            # Extract target metrics
            row_data = {'dtmax': dt}
            for metric in TARGET_METRICS:
                row_data[metric] = final_state.get(metric, np.nan)
                
            if i == 0:
                baseline_data = row_data
                row_data['max_error_vs_baseline_%'] = 0.0
            else:
                # Calculate maximum percent difference across tracked metrics compared to baseline
                errors = []
                for metric in TARGET_METRICS:
                    base_val = baseline_data[metric]
                    test_val = row_data[metric]
                    if abs(base_val) > 1e-12: # Avoid division by zero
                        pct_error = abs((test_val - base_val) / base_val) * 100
                        errors.append(pct_error)
                row_data['max_error_vs_baseline_%'] = max(errors) if errors else np.nan
                
            results.append(row_data)

    # Output compilation
    if results:
        results_df = pd.DataFrame(results)
        pd.set_option('display.max_columns', None)
        pd.set_option('display.width', 1000)
        print("\n--- TEST RESULTS ---")
        print(results_df.to_string(index=False))
        
        max_deviation = results_df['max_error_vs_baseline_%'].max()
        print(f"\nMaximum observed deviation across all tests: {max_deviation:.4f}%")
        
        if max_deviation < 1.0:
            print("Conclusion: dtmax has negligible impact on final equilibrium outputs.")
        else:
            print("Conclusion: dtmax significantly impacts outputs. The problem is path-dependent or lacks strict convergence.")