[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
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
    block = '114 113 112 111 110 109 108 107 106 105 104 103 102 101'
  []
[]

[Variables]
  [disp_x]
    order = FIRST
  []
  [disp_y]
    order = FIRST
  []
[]


[UserObjects]
  [prev_soln]
    type = SolutionUserObject
    mesh = 'step_0_out.e'
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
    block = '6 1'
  []
  [ic_disp_y]
    type = FunctionIC
    variable = disp_y
    function = init_disp_y
    block = '6 1'
  []
[]

[AuxVariables]
  [plastic_strain_yy_aux]
    order = CONSTANT
    family = MONOMIAL
    block = '6 115'
  []
[]

[AuxKernels]
  [eps_yy_aux]
    type = MaterialRankTwoTensorAux
    variable = plastic_strain_yy_aux
    property = plastic_strain
    i = 1
    j = 1
    block = '6 115'
  []
[]

[Physics/SolidMechanics/QuasiStatic]
  [ground_physics]
    block = '6 115'
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

[Kernels]
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
  []
  [gravity_y_115]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = '115'
  []
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
  []
[]

[UserObjects]
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
[]

[Materials]
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
    block = '6 115'
  []
  [soil_plasticity_native]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_native_model'
    block = '6 115'
    ep_plastic_tolerance = 1e-9
    debug_fspb = none
  []
[]

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
    block = '6 115'
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
    block = '6 115'
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
    block = '6 115'
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
    file_base = 'step_1_out'
  []
[]
