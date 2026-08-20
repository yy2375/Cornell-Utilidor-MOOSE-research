import os
import subprocess

LAYERS = [str(i) for i in range(115, 100, -1)]

def generate_moose_file(step_num):
    if step_num == 0:
        active_layers = []
    elif step_num <= 15:
        active_layers = LAYERS[:step_num]
    else:
        active_layers = LAYERS

    all_soil_blocks = "6 " + " ".join(LAYERS)
    active_soil_blocks = "6 " + " ".join(active_layers)
    
    active_side_fill = " ".join([l for l in active_layers if int(l) >= 111])
    active_top_fill = " ".join([l for l in active_layers if int(l) <= 110])

    inactive_layers = [l for l in LAYERS if l not in active_layers]
    inactive_blocks_str = " ".join(inactive_layers)

    if inactive_blocks_str:
        mesh_block = f"""[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'contact2.msh' 
  []
  [delete_inactive]
    type = BlockDeletionGenerator
    input = fmg
    block = '{inactive_blocks_str}'
  []
[]"""
    else:
        mesh_block = """[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'contact2.msh' 
  []
[]"""

    moose_script = f"""[GlobalParams]
  displacements = 'disp_x disp_y'
[]

{mesh_block}

[Variables]
  [disp_x]
    order = SECOND
  []
  [disp_y]
    order = SECOND
  []
[]

[AuxVariables]
  [plastic_strain_yy_aux]
    order = CONSTANT
    family = MONOMIAL
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
    generate_output = 'stress_yy vonmises_stress max_principal_stress strain_yy'
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
    formulation = penalty
    penalty = 1e8
  []
[]

[Functions]
  [gravity_ramp]
    type = ParsedFunction
    expression = 't'
  []
[]

[Kernels]
  [gravity_y_native]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2100
    block = '6'
    function = gravity_ramp
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2400
    block = '1'
    function = gravity_ramp
  []"""

    for layer in active_layers:
        moose_script += f"""
  [gravity_y_{layer}]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = '{layer}'
    function = gravity_ramp
  []"""

    moose_script += f"""
[]

[BCs]
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
        moose_script += """
  [top_press]
    type = Pressure
    boundary = 'top'
    variable = disp_y
    factor = 80000
    function = gravity_ramp
  []"""

    moose_script += f"""
[]

[UserObjects]
  [c_top]
    type = SolidMechanicsHardeningConstant
    value = 25e3
  []
  [phi_top]
    type = SolidMechanicsHardeningConstant
    value = 0.610865
  []
  [psi_top]
    type = SolidMechanicsHardeningConstant
    value = 0.0
  []
  [c_side]
    type = SolidMechanicsHardeningConstant
    value = 150e3
  []
  [phi_side]
    type = SolidMechanicsHardeningConstant
    value = 0.663225
  []
  [psi_side]
    type = SolidMechanicsHardeningConstant
    value = 0.0
  []
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
  [dp_top_model]
    type = SolidMechanicsPlasticDruckerPrager
    mc_cohesion = c_top
    mc_friction_angle = phi_top
    mc_dilation_angle = psi_top
    yield_function_tolerance = 1e-9
    internal_constraint_tolerance = 1e-9
  []
  [dp_side_model]
    type = SolidMechanicsPlasticDruckerPrager
    mc_cohesion = c_side
    mc_friction_angle = phi_side
    mc_dilation_angle = psi_side
    yield_function_tolerance = 1e-9
    internal_constraint_tolerance = 1e-9
  []
  [dp_native_model]
    type = SolidMechanicsPlasticDruckerPrager
    mc_cohesion = c_native
    mc_friction_angle = phi_native
    mc_dilation_angle = psi_native
    yield_function_tolerance = 1e-9
    internal_constraint_tolerance = 1e-9
  []
[]

[Materials]
  [elasticity_native]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = '6'
  []
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
  [soil_plasticity_native]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_native_model'
    block = '6'
    ep_plastic_tolerance = 1e-9
  []"""

    if active_side_fill:
        moose_script += f"""
  [elasticity_side_fill]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = '{active_side_fill}'
  []
  [soil_plasticity_side]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_side_model'
    block = '{active_side_fill}'
    ep_plastic_tolerance = 1e-9
  []"""

    if active_top_fill:
        moose_script += f"""
  [elasticity_top_fill]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 30e6
    poissons_ratio = 0.35
    block = '{active_top_fill}'
  []
  [soil_plasticity_top]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_top_model'
    block = '{active_top_fill}'
    ep_plastic_tolerance = 1e-9
  []"""

    moose_script += f"""
[]

[Postprocessors]
  [max_vm_concrete]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '1'
    value_type = max
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
  [max_principal_stress_concrete]
    type = ElementExtremeValue
    variable = max_principal_stress
    block = '1'
    value_type = max
  []
  [max_vm_ground]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '{active_soil_blocks}'
    value_type = max
  []
  [max_compressive_yy_ground]
    type = ElementExtremeValue
    variable = stress_yy
    block = '{active_soil_blocks}'
    value_type = min
  []
  [max_plastic_strain_soil]
    type = ElementExtremeValue
    variable = plastic_strain_yy_aux
    block = '{active_soil_blocks}'
    value_type = max
  []
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
  [max_settlement_y]
    type = NodalExtremeValue
    variable = disp_y
    value_type = min
  []
  [invert_disp_y]
    type = NodalExtremeValue
    variable = disp_y
    boundary = 'bottom'
    value_type = min
  []
  [invert_plastic_strain]
    type = SideExtremeValue
    variable = plastic_strain_yy_aux
    boundary = 'bottom'
    value_type = max
  []
  [invert_stress_vm]
    type = SideExtremeValue
    variable = vonmises_stress
    boundary = 'bottom'
    value_type = max
  []
  [left_disp_x]
    type = NodalExtremeValue
    variable = disp_x
    boundary = 'left'
    value_type = max
  []
  [left_plastic_strain]
    type = SideExtremeValue
    variable = plastic_strain_yy_aux
    boundary = 'left'
    value_type = max
  []
  [left_stress_vm]
    type = SideExtremeValue
    variable = vonmises_stress
    boundary = 'left'
    value_type = max
  []
  [right_disp_x]
    type = NodalExtremeValue
    variable = disp_x
    boundary = 'right'
    value_type = max
  []
  [right_plastic_strain]
    type = SideExtremeValue
    variable = plastic_strain_yy_aux
    boundary = 'right'
    value_type = max
  []
  [right_stress_vm]
    type = SideExtremeValue
    variable = vonmises_stress
    boundary = 'right'
    value_type = max
  []"""

    # Only request 'top' boundary telemetry when the top layer actually exists
    if step_num >= 15:
        moose_script += """
  [top_disp_y]
    type = NodalExtremeValue
    variable = disp_y
    boundary = 'top'
    value_type = min
  []
  [top_plastic_strain]
    type = SideExtremeValue
    variable = plastic_strain_yy_aux
    boundary = 'top'
    value_type = max
  []
  [top_stress_vm]
    type = SideExtremeValue
    variable = vonmises_stress
    boundary = 'top'
    value_type = max
  []"""

    moose_script += f"""
[]

[Executioner]
  type = Transient
  solve_type = NEWTON
  line_search = 'bt'
  end_time = 1.0
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu mumps'
  nl_abs_tol = 1e-4
  nl_rel_tol = 1e-4
  nl_max_its = 20

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 0.1
    cutback_factor = 0.5
    growth_factor = 1.2
  []
[]

[Outputs]
  exodus = false
  [csv]
    type = CSV
    file_base = 'phase_{step_num}_out'
  []
[]
"""
    filename = f"step_{step_num}.i"
    with open(filename, 'w') as f:
        f.write(moose_script)
    return filename

def main():
    print("=== Starting Independent Phase Batch Analysis ===")
    
    for step in range(17):
        print(f"\n--- Generating and Running Phase {step} ---")
        input_file = generate_moose_file(step)
        
        result = subprocess.run(['./dog-opt', '-i', input_file], capture_output=False)
        
        if result.returncode != 0:
            print(f"\n[ERROR] Solver crashed on Phase {step}. Halting sequence.")
            break
            
        print(f"Phase {step} completed successfully.")
        
    print("\nSequence complete. Your expanded ML data is ready in the 'phase_X_out.csv' files.")

if __name__ == "__main__":
    main()