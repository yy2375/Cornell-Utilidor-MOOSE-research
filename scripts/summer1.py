import os
import subprocess
import numpy as np
import pandas as pd




N_SAMPLES = 3000
DEPTH_MIN, DEPTH_MAX = 1.5, 10.0      
LOAD_MIN, LOAD_MAX = 0.0, 600000.0    


WIDTH = 2.0      
HEIGHT = 2.0     
THICKNESS = 0.2  




GEO_TEMPLATE = "template.geo"
MOOSE_TEMPLATE = "template.i"
CURRENT_GEO = "current.geo"
CURRENT_MOOSE = "current.i"
MOOSE_EXEC = os.path.expanduser("~/projects/dog/dog-opt") 
OUTPUT_CSV = "concrete_utilidor_out.csv"




def generate_mesh(depth, width, height, thickness):
    """Reads the geo template, updates parameters, and generates the .msh file."""
    with open(GEO_TEMPLATE, 'r') as file:
        geo_data = file.read()

    
    geo_data = geo_data.replace('depth = DefineNumber[ 2, Name "Parameters/d" ];', f'depth = {depth};')
    geo_data = geo_data.replace('height = DefineNumber[ 2, Name "Parameters/h" ];', f'height = {height};')
    geo_data = geo_data.replace('width = DefineNumber[ 2, Name "Parameters/w" ];', f'width = {width};')
    geo_data = geo_data.replace('thickness = DefineNumber[ 0.2, Name "Parameters/t" ];', f'thickness = {thickness};')

    with open(CURRENT_GEO, 'w') as file:
        file.write(geo_data)

    
    subprocess.run(["gmsh", "-2", CURRENT_GEO, "-o", "rect_shell.msh", "-v", "0"], check=True)

def update_moose_file(depth, width, height, thickness, top_load):
    """Updates the top load and the exact dynamic coordinates for postprocessors."""
    with open(MOOSE_TEMPLATE, 'r') as file:
        moose_data = file.read()

    
    moose_data = moose_data.replace("top_load = 6e5", f"top_load = {top_load}")

    
    crown_outer  = f"'0 {-depth} 0'"
    crown_inner  = f"'0 {-depth - thickness} 0'"
    invert_inner = f"'0 {-depth - height + thickness} 0'"
    wall_outer   = f"'{width/2.0} {-depth - height/2.0} 0'"
    wall_inner   = f"'{width/2.0 - thickness} {-depth - height/2.0} 0'"
    corner_inner = f"'{width/2.0 - thickness} {-depth - thickness} 0'"

    
    moose_data = moose_data.replace("'CROWN_OUTER'", crown_outer)
    moose_data = moose_data.replace("'CROWN_INNER'", crown_inner)
    moose_data = moose_data.replace("'INVERT_INNER'", invert_inner)
    moose_data = moose_data.replace("'WALL_OUTER'", wall_outer)
    moose_data = moose_data.replace("'WALL_INNER'", wall_inner)
    moose_data = moose_data.replace("'CORNER_INNER'", corner_inner)

    with open(CURRENT_MOOSE, 'w') as file:
        file.write(moose_data)

def run_moose():
    """Executes the MOOSE simulation."""
    subprocess.run([MOOSE_EXEC, "-i", CURRENT_MOOSE], check=True)




def main():
    np.random.seed(42)
    depths = np.random.uniform(DEPTH_MIN, DEPTH_MAX, N_SAMPLES)
    top_loads = np.random.uniform(LOAD_MIN, LOAD_MAX, N_SAMPLES)

    all_data = []

    print(f"Starting generation of {N_SAMPLES} samples...")

    for i in range(N_SAMPLES):
        d = depths[i]
        load = top_loads[i]
        t = THICKNESS

        print(f"Run {i+1}/{N_SAMPLES} | Depth: {d:.2f} m | Load: {load/1000:.1f} kPa")

        try:
            
            generate_mesh(d, WIDTH, HEIGHT, t)
            update_moose_file(d, WIDTH, HEIGHT, t, load)
            
            
            run_moose()

            
            df_out = pd.read_csv(OUTPUT_CSV)
            results = df_out.iloc[-1].to_dict()

           
            
            
            
            sigma_roof_top = results.get('roof_stress_top', 0)
            sigma_roof_bot = results.get('roof_stress_bottom', 0)
            M_roof = abs(sigma_roof_top - sigma_roof_bot) * (t**2) / 12.0
            
            
            sigma_wall_out = results.get('wall_stress_outer', 0)
            sigma_wall_in = results.get('wall_stress_inner', 0)
            M_wall = abs(sigma_wall_out - sigma_wall_in) * (t**2) / 12.0
            
            
            s_xx = results.get('corner_stress_xx', 0)
            s_yy = results.get('corner_stress_yy', 0)
            
            vm_corner = np.sqrt(s_xx**2 - s_xx*s_yy + s_yy**2)

            
            row_data = {
                'input_depth': d,
                'input_top_load': load,
                'input_width': WIDTH,
                'input_height': HEIGHT,
                'input_thickness': t,
                'u_y_crown': results['u_y_crown'],
                'u_y_invert': results['u_y_invert'],
                'M_roof': M_roof,     
                'M_wall': M_wall,     
                'sigma_vm': vm_corner 
            }

            all_data.append(row_data)

        except Exception as e:
            print(f"Error on run {i+1}: {e}")
            continue

    
    master_df = pd.DataFrame(all_data)
    master_df.to_csv("surrogate_training_data.csv", index=False)
    print("\nData generation complete. Saved to surrogate_training_data.csv")

if __name__ == "__main__":
    main()