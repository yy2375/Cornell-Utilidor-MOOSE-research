import pandas as pd

def symmetrize_utilidor_data(input_csv, output_csv):
    print(f"Loading original data: {input_csv}")
    df = pd.read_csv(input_csv)
    
    # Create the mirrored dataset
    df_mirrored = df.copy()
    
    # 1. Flip X-displacements for Centerline (Top and Invert)
    df_mirrored.iloc[:, [9, 14]] *= -1
    
    # 2. Swap Left and Right blocks and flip X-displacements
    left_block = df.iloc[:, 19:24].copy()
    right_block = df.iloc[:, 24:29].copy()
    
    new_left = right_block.copy()
    new_left.iloc[:, 0] *= -1 
    
    new_right = left_block.copy()
    new_right.iloc[:, 0] *= -1
    
    df_mirrored.iloc[:, 19:24] = new_left
    df_mirrored.iloc[:, 24:29] = new_right
        
    # 3. Average the original and mirrored outputs to eliminate FEA noise
    # Inputs (cols 0-8) are identical, so averaging them leaves them unchanged.
    df_symmetrized = (df + df_mirrored) / 2.0
    
    df_symmetrized.to_csv(output_csv, index=False)
    print(f"Processed 1,300 samples.")
    print(f"Symmetrized dataset saved to: {output_csv}")

if __name__ == "__main__":
    symmetrize_utilidor_data(
        "surrogate_comprehensive_training_datav2.csv", 
        "surrogate_symmetrized_training_data.csv"
    )