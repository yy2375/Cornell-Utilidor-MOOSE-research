import pandas as pd
import os

# --- Configuration ---
SCENARIOS = {
    "Elastic_NoContact":  {"csv": "output_A_wished.csv"},
    "Elastic_Contact":    {"csv": "output_instant_contact.csv"},
    "Plastic_NoContact":  {"csv": "output_A_plastic.csv"},
    "Plastic_Contact":    {"csv": "output_instant_contact2.csv"}
}

# Map unified metric names to possible CSV column names to handle inconsistencies
METRIC_MAPPING = {
    "max_settlement_y": ["max_settlement_y"], 
    "max_vm_concrete": ["max_vm_concrete"], 
    "max_compressive_yy_concrete": ["max_compressive_yy_concrete"],
    "max_vm_ground": ["max_vm_ground"],
    "crown_disp_y": ["crown_disp_y", "top_disp_y"],
    "invert_disp_y": ["invert_disp_y"],
    "left_wall_disp_x": ["left_wall_disp_x", "left_disp_x"],
    "crown_vm_stress": ["crown_vm_stress", "top_stress_vm"]
}

def extract_final_data():
    """Reads the last row of each CSV and extracts the required metrics."""
    data = {}
    for name, paths in SCENARIOS.items():
        csv_file = paths["csv"]
        if not os.path.exists(csv_file):
            print(f"WARNING: {csv_file} not found. Cannot extract data for {name}.")
            continue
            
        df = pd.read_csv(csv_file)
        final_step = df.iloc[-1]
        
        row_data = {}
        for unified_name, possible_cols in METRIC_MAPPING.items():
            val = pd.NA
            for col in possible_cols:
                if col in final_step.index:
                    val = final_step[col]
                    break
            row_data[unified_name] = val
            
        data[name] = row_data
        
    return pd.DataFrame.from_dict(data, orient='index')

def compute_percent_differences(df):
    """Calculates percent differences between key scenarios."""
    diff_df = pd.DataFrame(index=METRIC_MAPPING.keys())
    
    def pct_diff(baseline, new):
        return ((df.loc[new] - df.loc[baseline]) / df.loc[baseline].abs()) * 100

    if "Elastic_NoContact" in df.index and "Elastic_Contact" in df.index:
        diff_df["% Diff: Contact vs No-Contact (Elastic)"] = pct_diff("Elastic_NoContact", "Elastic_Contact")

    if "Plastic_NoContact" in df.index and "Plastic_Contact" in df.index:
        diff_df["% Diff: Contact vs No-Contact (Plastic)"] = pct_diff("Plastic_NoContact", "Plastic_Contact")

    if "Elastic_Contact" in df.index and "Plastic_Contact" in df.index:
        diff_df["% Diff: Plastic vs Elastic (Contact)"] = pct_diff("Elastic_Contact", "Plastic_Contact")

    return diff_df

if __name__ == "__main__":
    
    print("\n--- Raw Data (Final Time Step) ---")
    raw_df = extract_final_data()
    
    if not raw_df.empty:
        raw_df_t = raw_df.transpose()
        pd.set_option('display.float_format', '{:.4e}'.format)
        print(raw_df_t.to_string())
        
        print("\n--- Percentage Differences (%) ---")
        diff_df = compute_percent_differences(raw_df)
        pd.set_option('display.float_format', '{:.2f}%'.format)
        print(diff_df.to_string())
    else:
        print("No data available to compare. Ensure CSV files are in the current directory.")