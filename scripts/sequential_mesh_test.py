import subprocess
import time
import os
import sys

# ==========================================
# CONFIGURATION
# ==========================================
GEO_FILE = "contact_trenchonly_large_first.geo"               
MOOSE_INPUT = "sequential_large_first.i"    
MOOSE_APP = os.path.expanduser("~/projects/dog/dog-opt")
MESH_OUTPUT = "contact_trenchonly_large_first.msh"

TEST_SIZES = [0.15, 0.10, 0.08, 0.06, 0.04] 

# ==========================================
# AUTOMATION LOGIC
# ==========================================
def run_command(cmd, step_name):
    """Executes a shell command and captures the output."""
    try:
        result = subprocess.run(
            cmd, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.STDOUT, 
            text=True, 
            check=False
        )
        return result.returncode, result.stdout
    except Exception as e:
        print(f"Failed to execute {step_name}: {e}")
        sys.exit(1)

def update_geo_file(geo_path, new_size):
    """Updates the Field[1].VIn parameter robustly."""
    with open(geo_path, 'r') as file:
        lines = file.readlines()

    modified = False
    for i, line in enumerate(lines):
        if "Field[1].VIn" in line and "=" in line:
            parts = line.split(";")
            comment = ";" + parts[1] if len(parts) > 1 else ";\n"
            lines[i] = f"Field[1].VIn = {new_size}{comment}"
            modified = True
            break

    if not modified:
        print(f"Error: Could not find 'Field[1].VIn' in {geo_path}")
        sys.exit(1)

    with open(geo_path, 'w') as file:
        file.writelines(lines)

def main():
    if not os.path.exists(GEO_FILE) or not os.path.exists(MOOSE_INPUT):
        print(f"Error: Ensure {GEO_FILE} and {MOOSE_INPUT} exist in this directory.")
        return

    print(f"{'Mesh Size (VIn)':<20} | {'Status':<15} | {'Solve Time (s)':<15}")
    print("-" * 55)

    for size in TEST_SIZES:
        # 1. Update Geometry
        update_geo_file(GEO_FILE, size)
        
        # 2. Generate Mesh
        gmsh_cmd = ["gmsh", "-2", GEO_FILE, "-o", MESH_OUTPUT, "-format", "msh2"]
        gmsh_code, gmsh_out = run_command(gmsh_cmd, "Gmsh")
        
        # EXPOSE GMSH ERRORS
        if gmsh_code != 0:
            print(f"{size:<20} | {'Mesh Failed':<15} | {'N/A':<15}")
            print(f"\n--- GMSH ERROR LOG ---")
            print(gmsh_out)
            print("----------------------\n")
            break 

        # 3. Run MOOSE (Direct execution, no mpiexec to prevent Path errors)
        moose_cmd = [MOOSE_APP, "-i", MOOSE_INPUT]
        
        start_time = time.time()
        moose_code, moose_out = run_command(moose_cmd, "MOOSE")
        exec_time = round(time.time() - start_time, 2)

        # 4. Evaluate Convergence
        if moose_code == 0 and "Solve Did NOT Converge" not in moose_out:
            status = "Converged"
        elif "DIVERGED_LINE_SEARCH" in moose_out:
            status = "Diverged (Line)"
        else:
            status = "Failed (Other)"

        print(f"{size:<20} | {status:<15} | {exec_time:<15}")

        # 5. Save Outputs 
        if status != "Converged":
            log_name = f"failed_run_VIn_{size}.log"
            with open(log_name, 'w') as log_file:
                log_file.write(moose_out)
                
        if moose_code == 0:
            try:
                # The CSV uses the file_base you set
                os.rename("output_sequential_contact_large_kinematic_first.csv", f"output_VIn_{size}.csv")
                # The Exodus file defaults to the input script name
                os.rename("sequential_large_first_out.e", f"output_VIn_{size}.e")
            except FileNotFoundError as e:
                print(f"Warning: Could not rename output files. {e}")

if __name__ == "__main__":
    main()