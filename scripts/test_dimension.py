import os
import subprocess
import pandas as pd
import numpy as np
import time

# ==========================================
# 1. FIXED TEST PARAMETERS
# ==========================================
DEPTH = 5.0      # m
WIDTH = 2.0      # m
HEIGHT = 2.0     # m
THICKNESS = 0.2  # m
LOAD = 600000.0  # Pa

# ==========================================
# 2. PATHS & SETTINGS
# ==========================================
MOOSE_TEMPLATE = "template.i"
CURRENT_GEO = "dynamic_boundary.geo"
CURRENT_MOOSE = "dynamic_boundary.i"
MOOSE_EXEC = "/home/yiksany/projects/dog/dog-opt" 
OUTPUT_CSV = "concrete_utilidor_out.csv"
LOG_CSV = "boundary_convergence_log.csv"

STARTING_MULTIPLIER = 2 

# ==========================================
# 3. GENERATION FUNCTIONS
# ==========================================
def generate_mesh(depth, width, height, thickness, multiplier):
    bound_x = (width / 2.0) + (multiplier * width)
    bound_y_bottom = -(depth + height) - (multiplier * max(width, height))
    
    geo_content = f"""
    depth = {depth}; height = {height}; thickness = {thickness}; width = {width};
    Point(1) = {{-{bound_x}, 0, 0, 1.0}}; Point(2) = {{{bound_x}, 0, 0, 1.0}};
    Point(3) = {{{bound_x}, {bound_y_bottom}, 0, 1.0}}; Point(4) = {{-{bound_x}, {bound_y_bottom}, 0, 1.0}};
    Point(5) = {{-width/2, -depth, 0, 0.05}}; Point(6) = {{width/2, -depth, 0, 0.05}};
    Point(7) = {{width/2, -depth-height, 0, 0.05}}; Point(8) = {{-width/2, -depth-height, 0, 0.05}};
    Point(9) = {{-width/2+thickness, -depth-thickness, 0, 0.05}};
    Point(10) = {{width/2-thickness, -depth-thickness, 0, 0.05}};
    Point(11) = {{width/2-thickness, -depth-height+thickness, 0, 0.05}};
    Point(12) = {{-width/2+thickness, -depth-height+thickness, 0, 0.05}};

    Line(1)={{1,4}}; Line(2)={{4,3}}; Line(3)={{3,2}}; Line(4)={{2,1}};
    Line(5)={{6,7}}; Line(6)={{7,8}}; Line(7)={{8,5}}; Line(8)={{5,6}};
    Line(9)={{10,11}}; Line(10)={{11,12}}; Line(11)={{12,9}}; Line(12)={{9,10}};

    Curve Loop(1)={{4,1,2,3}}; Curve Loop(2)={{8,5,6,7}}; Curve Loop(3)={{12,9,10,11}};
    Plane Surface(1)={{1,2}}; Plane Surface(2)={{2,3}};
    Physical Surface("ground")={{1}}; Physical Surface("concrete")={{2}};
    Physical Curve("left")={{1}}; Physical Curve("bottom")={{2}}; 
    Physical Curve("right")={{3}}; Physical Curve("top")={{4}}; 
    Physical Curve("wall")={{9,10,11,12}};

    Coherence;
    Physical Surface("ground", 1) += {{1}}; Physical Surface("concrete", 2) += {{2}};
    """
    with open(CURRENT_GEO, 'w') as file:
        file.write(geo_content)

    subprocess.run(["gmsh", "-2", CURRENT_GEO, "-o", "rect_shell.msh", "-v", "0"], check=True)
    return bound_x, bound_y_bottom

def update_moose_file(depth, width, height, thickness, top_load):
    with open(MOOSE_TEMPLATE, 'r') as file:
        moose_data = file.read()

    moose_data = moose_data.replace("top_load = 6e5", f"top_load = {top_load}")

    moose_data = moose_data.replace("'CROWN_OUTER'", f"'0 {-depth} 0'")
    moose_data = moose_data.replace("'CROWN_INNER'", f"'0 {-depth - thickness} 0'")
    moose_data = moose_data.replace("'INVERT_INNER'", f"'0 {-depth - height + thickness} 0'")
    moose_data = moose_data.replace("'WALL_OUTER'", f"'{width/2.0} {-depth - height/2.0} 0'")
    moose_data = moose_data.replace("'WALL_INNER'", f"'{width/2.0 - thickness} {-depth - height/2.0} 0'")
    moose_data = moose_data.replace("'CORNER_INNER'", f"'{width/2.0 - thickness} {-depth - thickness} 0'")

    with open(CURRENT_MOOSE, 'w') as file:
        file.write(moose_data)

def run_moose():
    subprocess.run([MOOSE_EXEC, "-i", CURRENT_MOOSE], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

# ==========================================
# 4. CONTINUOUS EXECUTION LOOP
# ==========================================
def main():
    print(f"{'Mult.':<6} | {'Width (±X)':<10} | {'Depth (-Y)':<10} | {'M_roof (N-m/m)':<15} | {'Change %'}")
    print("-" * 65)
    print("Running continuously. Press [Ctrl+C] to stop and save data.\n")
    
    previous_moment = None
    current_multiplier = STARTING_MULTIPLIER
    master_log = [] 
    
    try:
        while True:
            # 1. Generate and solve
            bound_x, bound_y = generate_mesh(DEPTH, WIDTH, HEIGHT, THICKNESS, current_multiplier)
            update_moose_file(DEPTH, WIDTH, HEIGHT, THICKNESS, LOAD)
            run_moose()
            
            # 2. Extract RAW data from MOOSE
            df_out = pd.read_csv(OUTPUT_CSV)
            latest = df_out.iloc[-1].to_dict()
            
            # 3. Calculate true structural metrics
            current_m_roof = abs(latest.get('roof_stress_top', 0) - latest.get('roof_stress_bottom', 0)) * (THICKNESS**2) / 12.0
            current_m_wall = abs(latest.get('wall_stress_outer', 0) - latest.get('wall_stress_inner', 0)) * (THICKNESS**2) / 12.0
            
            s_xx = latest.get('corner_stress_xx', 0)
            s_yy = latest.get('corner_stress_yy', 0)
            vm_corner = np.sqrt(s_xx**2 - s_xx*s_yy + s_yy**2)
            
            # 4. Document everything for this iteration
            iteration_data = {
                'Multiplier': current_multiplier,
                'Boundary_X': bound_x,
                'Boundary_Y': bound_y,
                'Calculated_M_roof': current_m_roof,
                'Calculated_M_wall': current_m_wall,
                'Calculated_Sigma_VM': vm_corner
            }
            iteration_data.update(latest) 
            master_log.append(iteration_data)
            
            # 5. Print out the results (No breaking on tolerance)
            if previous_moment is not None:
                pct_change = abs(current_m_roof - previous_moment) / previous_moment
                print(f"{current_multiplier:<6} | {bound_x:<10.1f} | {bound_y:<10.1f} | {current_m_roof:<15.2f} | {pct_change * 100:.3f}%")
            else:
                print(f"{current_multiplier:<6} | {bound_x:<10.1f} | {bound_y:<10.1f} | {current_m_roof:<15.2f} | N/A")
                
            previous_moment = current_m_roof
            current_multiplier += 1
            
    except KeyboardInterrupt:
        # This catches the Ctrl+C command
        print("\n\n[!] Script manually stopped by user.")
    except Exception as e:
        print(f"\n[!] Error on multiplier {current_multiplier}: {e}")

    # 6. Save the master log to disk (happens even after Ctrl+C)
    if master_log:
        pd.DataFrame(master_log).to_csv(LOG_CSV, index=False)
        print(f"Successfully saved {len(master_log)} iterations to: {LOG_CSV}")
    else:
        print("No iterations completed. Nothing to save.")

if __name__ == "__main__":
    main()