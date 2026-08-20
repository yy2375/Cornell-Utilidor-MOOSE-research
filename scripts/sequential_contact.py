import os
import subprocess

LAYERS = [str(i) for i in range(115, 100, -1)]

def generate_moose_file(step_num):
    # ---------------------------------------------------------
    # 1. Determine Active & Inactive Blocks
    # ---------------------------------------------------------
    if step_num == 0:
        active_layers = []
    elif step_num <= 15:
        active_layers = LAYERS[:step_num]
    else:
        active_layers = LAYERS

    active_soil_blocks = "6 " + " ".join(active_layers)
    inactive_layers = [l for l in LAYERS if l not in active_layers]
    inactive_blocks_str = " ".join(inactive_layers)

    # ---------------------------------------------------------
    # 2. Build the Mesh Block (Direct Gmsh Deletion)
    # ---------------------------------------------------------
    if inactive_blocks_str:
        mesh_block = f"""[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'contact2.msh'
  []
  [convert_order]
    type = ElementOrderConversionGenerator
    input = fmg
    conversion_type = FIRST_ORDER
  []
  [delete_inactive]
    type = BlockDeletionGenerator
    input = convert_order
    block = '{inactive_blocks_str}'
  []
[]"""
    else:
        mesh_block = """[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'contact2.msh'
  []
  [convert_order]
    type = ElementOrderConversionGenerator
    input = fmg
    conversion_type = FIRST_ORDER
  []
[]"""

    # ---------------------------------------------------------
    # 3. Variables & Spatial Field Projection
    # ---------------------------------------------------------
    variables_block = """[Variables]
  [disp_x]
    order = FIRST
  []
  [disp_y]
    order = FIRST
  []
[]"""

    if step_num > 0:
        prev_step = step_num - 1
        
        if prev_step == 0:
            prev_active_blocks = "6 1"
        else:
            prev_active_layers = LAYERS[:prev_step]
            prev_active_blocks = "6 1 " + " ".join(prev_active_layers)

        restart_funcs_ics = f"""
[UserObjects]
  [prev_soln]
    type = SolutionUserObject
    mesh = 'step_{prev_step}_out.e'
    system_variables = 'disp_x disp_y'
    nodal_variable_order = FIRST
    execute_on = INITIAL
    extrap_tol = 1.0
  []
[]

[Functions]
  [init_disp_x]
    type = SolutionFunction
    solution = prev_soln
    from_variable = disp_x
  []
  [init_disp_y]
    type = SolutionFunction
    solution = prev_soln
    from_variable = disp_y
  []
[]

[ICs]
  [ic_disp_x]
    type = FunctionIC
    variable = disp_x
    function = init_disp_x
    block = '{prev_active_blocks}'
  []
  [ic_disp_y]
    type = FunctionIC
    variable = disp_y
    function = init_disp_y
    block = '{prev_active_blocks}'
  []
[]"""
    else:
        restart_funcs_ics = ""

    # ---------------------------------------------------------
    # 4. Boundary Conditions & Gravity
    # ---------------------------------------------------------
    bcs_block = """[BCs]
  [bottom_y]
    type = DirichletBC
    variable = disp_y
    boundary = 'bottom'
    value = 0
  []
  [bottom_x]
    type = DirichletBC
    variable = disp_x
    boundary = 'bottom'
    value = 0
  []
  [left_roll]
    type = DirichletBC
    variable = disp_x
    boundary = 'left'
    value = 0
  []
  [right_roll]
    type = DirichletBC
    variable = disp_x
    boundary = 'right'
    value = 0
  []
  [pin_center]
    type = DirichletBC
    variable = disp_x
    boundary = 'concrete_outer_wall'
    value = 0
  []"""

    if step_num == 16:
        bcs_block += """
  [top_press]
    type = Pressure
    boundary = 'top'
    variable = disp_y
    factor = 80000
  []"""
    bcs_block += "\n[]"

    kernels_block = """[Kernels]
  [gravity_y_native]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2100
    block = '6'
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2400
    block = '1'
  []"""
    
    for layer in active_layers:
        kernels_block += f"""
  [gravity_y_{layer}]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = '{layer}'
  []"""
    kernels_block += "\n[]"

    # ---------------------------------------------------------
    # 5. Materials Block (Consolidated Native Soil)
    # ---------------------------------------------------------
    userobjects_block = """[UserObjects]
  [c_native]
    type = SolidMechanicsHardeningConstant
    value = 15e3
  []
  [phi_native]
    type = SolidMechanicsHardeningConstant
    value = 0.488692
  []
  [psi_native]
    type = SolidMechanicsHardeningConstant
    value = 0.0
  []
  [dp_native_model]
    type = SolidMechanicsPlasticDruckerPrager
    mc_cohesion = c_native
    mc_friction_angle = phi_native
    mc_dilation_angle = psi_native
    yield_function_tolerance = 1e-9
    internal_constraint_tolerance = 1e-9
  []
[]"""

    materials_block = f"""[Materials]
  [elasticity_concrete]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 27.6e9
    poissons_ratio = 0.2
    block = '1'
  []
  [linear_stress_concrete]
    type = ComputeFiniteStrainElasticStress
    block = '1'
  []
  [elasticity_native]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = '{active_soil_blocks}'
  []
  [soil_plasticity_native]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_native_model'
    block = '{active_soil_blocks}'
    ep_plastic_tolerance = 1e-9
    debug_fspb = none
  []
[]"""

    # ---------------------------------------------------------
    # 6. Assemble Complete Script
    # ---------------------------------------------------------
    moose_script = f"""[GlobalParams]
  displacements = 'disp_x disp_y'
[]

{mesh_block}

{variables_block}

{restart_funcs_ics}

[AuxVariables]
  [plastic_strain_yy_aux]
    order = CONSTANT
    family = MONOMIAL
    block = '{active_soil_blocks}'
  []
[]

[AuxKernels]
  [eps_yy_aux]
    type = MaterialRankTwoTensorAux
    variable = plastic_strain_yy_aux
    property = plastic_strain
    i = 1
    j = 1
    block = '{active_soil_blocks}'
  []
[]

[Physics/SolidMechanics/QuasiStatic]
  [ground_physics]
    block = '{active_soil_blocks}'
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    generate_output = 'stress_yy vonmises_stress strain_yy'
  []
  [concrete_physics]
    block = '1'
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    generate_output = 'stress_yy vonmises_stress max_principal_stress strain_yy' 
  []
[]

[Contact]
  [soil_structure_interface]
    primary = 'concrete_outer_wall'
    secondary = 'soil_inner_wall'
    model = coulomb
    friction_coefficient = 0.4
    penalty = 1e4
    formulation = penalty
  []
[]

{kernels_block}

{bcs_block}

{userobjects_block}

{materials_block}

[Postprocessors]
  [max_disp_x]
    type = NodalExtremeValue
    variable = disp_x
    value_type = max
  []
  [min_disp_x]
    type = NodalExtremeValue
    variable = disp_x
    value_type = min
  []
  [max_plastic_strain_soil]
    type = ElementExtremeValue
    variable = plastic_strain_yy_aux
    block = '{active_soil_blocks}'
    value_type = min 
  []    
  [max_settlement_y]
    type = NodalExtremeValue
    variable = disp_y
    value_type = min
  []
  [max_vm_ground]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '{active_soil_blocks}'
    value_type = max
  []
  [max_vm_concrete]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '1'
    value_type = max
  []
  [max_compressive_yy_ground]
    type = ElementExtremeValue
    variable = stress_yy
    block = '{active_soil_blocks}'
    value_type = min 
  []
  [max_compressive_yy_concrete]
    type = ElementExtremeValue
    variable = stress_yy
    block = '1'
    value_type = min
  []
  [max_tensile_yy_concrete]
    type = ElementExtremeValue
    variable = stress_yy
    block = '1'
    value_type = max 
  []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON
  line_search = 'bt'
  num_steps = 1
  dt = 1.0
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu mumps'
  nl_abs_tol = 1e-4
  nl_rel_tol = 1e-4
  nl_max_its = 15

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 1.0
    cutback_factor = 0.5
    growth_factor = 1.1
  []
[]

[Outputs]
  exodus = true
  [csv]
    type = CSV
    file_base = 'step_{step_num}_out'
  []
[]
"""
    
    filename = f"step_{step_num}.i"
    with open(filename, 'w') as f:
        f.write(moose_script)
    
    return filename

def main():
    print("=== Starting Phased Spatial Projection Construction Analysis ===")
    
    for step in range(17):
        print(f"\n--- Generating and Running Phase {step} ---")
        input_file = generate_moose_file(step)
        
        print(f"Executing: ./dog-opt -i {input_file}")
        
        result = subprocess.run(['./dog-opt', '-i', input_file], capture_output=False)
        
        if result.returncode != 0:
            print(f"\n[ERROR] Solver crashed on Phase {step}. Halting sequence.")
            break
            
        print(f"Phase {step} completed successfully.")
        
    print("\nSequence complete. Your final fully-loaded CSV data is in 'step_16_out.csv'.")

if __name__ == "__main__":
    main()