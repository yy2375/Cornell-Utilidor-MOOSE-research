[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'Scenario_A.msh' 
  []
  [gen_top]
    type = ParsedGenerateSideset
    input = fmg
    combinatorial_geometry = 'y > -0.001'
    new_sideset_name = 'top'
  []
  [gen_bottom]
    type = ParsedGenerateSideset
    input = gen_top
    combinatorial_geometry = 'y < -30.499'
    new_sideset_name = 'bottom'
  []
  [gen_left]
    type = ParsedGenerateSideset
    input = gen_bottom
    combinatorial_geometry = 'x < -10.999'
    new_sideset_name = 'left'
  []
  [gen_right]
    type = ParsedGenerateSideset
    input = gen_left
    combinatorial_geometry = 'x > 10.999'
    new_sideset_name = 'right'
  []
[]

[Variables]
  [disp_x]
    order = SECOND
  []
  [disp_y]
    order = SECOND
  []
[]

[AuxVariables]
  [effective_plastic_strain]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[Physics/SolidMechanics/QuasiStatic]
  [ground_physics]
    block = '2 3 6'  
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    # Added strain_yy to track vertical soil compression
    generate_output = 'stress_yy vonmises_stress strain_yy'
  []
  [concrete_physics]
    block = '1' 
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    # Max principal stress is critical here for concrete cracking analysis
    generate_output = 'stress_yy vonmises_stress max_principal_stress strain_yy' 
  []
  [steel_physics]
    block = '4 5' 
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    generate_output = 'stress_yy vonmises_stress strain_yy'
  []
[]

[AuxKernels]
  [eps_aux]
    type = MaterialRealAux
    variable = effective_plastic_strain
    property = effective_plastic_strain
    block = '4 5'
  []
[]

[Functions]
  [global_ramp]
    type = ParsedFunction
    expression = 't'
  []
[]

[Kernels]
  [gravity_y_native_ground]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2100
    block = '6'
    function = global_ramp
  []
  [gravity_y_side_ground]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '2'
    function = global_ramp
  []
  [gravity_y_top_ground]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '3'
    function = global_ramp
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = 'disp_y'
    value = -10
    density = 2400
    block = '1'
    function = global_ramp
  []
  [gravity_y_steel]
    type = ADGravity
    variable = 'disp_y'
    value = -10
    density = 7850
    block = '4 5'
    function = global_ramp
  []
[]

[BCs]
  [bottom_disp_y]
    type = DirichletBC
    variable = disp_y 
    boundary = 'bottom'
    value = 0
  []
  [bottom_disp_x]
    type = DirichletBC
    variable = disp_x 
    boundary = 'bottom'
    value = 0
  []
  [left_roller]
    type = DirichletBC
    variable = disp_x 
    boundary = 'left'
    value = 0
  []
  [right_roller]
    type = DirichletBC
    variable = disp_x 
    boundary = 'right'
    value = 0
  []
  [top_normal_stress]
    type = Pressure
    boundary = 'top'
    variable = 'disp_y'
    factor = 80000
    function = global_ramp
  []
[]

[Materials]
  [elasticity_tensor_side_fill]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = '2 6'
  []
  [elasticity_tensor_top_fill]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 30e6
    poissons_ratio = 0.35
    block = '3'
  []
  [linear_stress_ground]
    type = ComputeFiniteStrainElasticStress
    block = '2 3 6'
  []
  [elasticity_tensor_concrete]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 27.6e9
    poissons_ratio = 0.2
    block = '1'
  []
  [linear_stress_concrete]
    type = ComputeFiniteStrainElasticStress
    block = '1'
  []
  [elasticity_tensor_steel]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 200e9
    poissons_ratio = 0.3
    block = '4 5'
  []
  [plastic_stress_steel]
    type = ComputeMultipleInelasticStress
    inelastic_models = 'steel_plasticity'
    block = '4 5'
  []
  [steel_plasticity]
    type = IsotropicPlasticityStressUpdate
    yield_stress = 420e6
    hardening_constant = 2e9
  []
[]

[Postprocessors]
  # --- Displacements (Nodal) ---
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
    value_type = min # Settlement is negative, so min captures the maximum downward shift
  []

  # --- Von Mises Stress (Elemental) ---
  [max_vm_ground]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '2 3 6'
    value_type = max
  []
  [max_vm_concrete]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '1'
    value_type = max
  []
  [max_vm_steel]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '4 5'
    value_type = max
  []

  # --- Vertical Stress (YY) ---
  [max_compressive_yy_ground]
    type = ElementExtremeValue
    variable = stress_yy
    block = '2 3 6'
    value_type = min # Compression is negative
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
    value_type = max # Tension is positive, critical for concrete failure
  []
  [max_compressive_yy_steel]
    type = ElementExtremeValue
    variable = stress_yy
    block = '4 5'
    value_type = min
  []

  # --- Principal Stress ---
  [max_principal_stress_concrete]
    type = ElementExtremeValue
    variable = max_principal_stress
    block = '1'
    value_type = max
  []

  # --- Plasticity ---
  [max_plastic_strain_steel]
    type = ElementExtremeValue
    variable = effective_plastic_strain
    block = '4 5'
    value_type = max
  []
[]

[Executioner]
  type = Transient 
  solve_type = NEWTON
  end_time = 1.0

  petsc_options_iname = '-pc_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu       mumps'
  
  nl_abs_tol = 1e-6
  nl_rel_tol = 1e-6

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 0.1
    cutback_factor = 0.5
    growth_factor = 1.2
  []
[]

[Outputs]
  exodus = true
  [csv]
    type = CSV
    file_base = 'output_A_wished'
  []
[]