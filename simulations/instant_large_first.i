[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'contact_trenchonly_large_first.msh' 
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
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10 layer_11 layer_12 layer_13 layer_14 layer_15 native_soil'
  []
[]

[Physics/SolidMechanics/QuasiStatic]
  [ground_physics]
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10 layer_11 layer_12 layer_13 layer_14 layer_15 native_soil'
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    generate_output = 'stress_yy vonmises_stress strain_yy'
  []
  [concrete_physics]
    block = 'concrete'
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
    friction_coefficient = 0
    formulation = kinematic
  []
[]

[Functions]
  [ramp_gravity]
    type = ParsedFunction
    expression = 'if(t<=1, t, 1.0)'
  []
  [ramp_pressure]
    type = ParsedFunction
    expression = 'if(t<=1, 0.0, if(t<=2, t-1, 1.0))'
  []
[]

[Kernels]
  [gravity_y_native]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2100
    block = 'native_soil'
    function = ramp_gravity
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2400
    block = 'concrete'
    function = ramp_gravity
  []
  [gravity_y_fill]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10 layer_11 layer_12 layer_13 layer_14 layer_15'
    function = ramp_gravity
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
  [top_press]
    type = Pressure
    boundary = 'top'
    variable = disp_y
    factor = 80000
    function = ramp_pressure
  []
  [pin_center]
    type = DirichletBC
    variable = disp_x
    boundary = 'concrete_outer_wall'
    value = 0
  []
[]

[UserObjects]
  [c_soil]
    type = SolidMechanicsHardeningConstant
    value = 15e3
  []
  [phi_soil]
    type = SolidMechanicsHardeningConstant
    value = 0.488692
  []
  [psi_soil]
    type = SolidMechanicsHardeningConstant
    value = 0.0
  []
  [dp_soil_model]
    type = SolidMechanicsPlasticDruckerPrager
    mc_cohesion = c_soil
    mc_friction_angle = phi_soil
    mc_dilation_angle = psi_soil
    yield_function_tolerance = 1e-6
    internal_constraint_tolerance = 1e-6
  []

  [tensile_limit_val]
    type = SolidMechanicsHardeningConstant
    value = 1e3
  []
  [tensile_model]
    type = SolidMechanicsPlasticTensile
    tensile_strength = tensile_limit_val
    tensile_tip_smoother = 100 
    yield_function_tolerance = 1e-6
    internal_constraint_tolerance = 1e-6
  []
[]

[Materials]
  [elasticity_soil]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10 layer_11 layer_12 layer_13 layer_14 layer_15 native_soil'
  []
  [elasticity_concrete]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 27.6e9
    poissons_ratio = 0.2
    block = 'concrete'
  []
  [linear_stress_concrete]
   type = ComputeFiniteStrainElasticStress
   block = 'concrete'
  []
  [soil_plasticity]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_soil_model tensile_model'
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10 layer_11 layer_12 layer_13 layer_14 layer_15 native_soil'
    ep_plastic_tolerance = 1e-9
  []
[]

[Postprocessors]
  [max_plastic_strain_soil]
    type = ElementExtremeValue
    variable = plastic_strain_yy_aux
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10 layer_11 layer_12 layer_13 layer_14 layer_15 native_soil'
    value_type = min
  []
  [top_plastic_strain]
    type = PointValue
    point = '0 -4.95 0'
    variable = plastic_strain_yy_aux
  []
  [invert_plastic_strain]
    type = PointValue
    point = '0 -7.05 0'
    variable = plastic_strain_yy_aux
  []
  [left_plastic_strain]
    type = PointValue
    point = '-1.05 -6.0 0'
    variable = plastic_strain_yy_aux
  []
  [right_plastic_strain]
    type = PointValue
    point = '1.05 -6.0 0'
    variable = plastic_strain_yy_aux
  []
  [max_settlement_y]
    type = NodalExtremeValue
    variable = disp_y
    value_type = min
  []
  [max_vm_ground]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10 layer_11 layer_12 layer_13 layer_14 layer_15 native_soil'
    value_type = max
  []
  [max_vm_concrete]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = 'concrete'
    value_type = max
  []
  [max_compressive_yy_ground]
    type = ElementExtremeValue
    variable = stress_yy
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10 layer_11 layer_12 layer_13 layer_14 layer_15 native_soil'
    value_type = min
  []
  [max_compressive_yy_concrete]
    type = ElementExtremeValue
    variable = stress_yy
    block = 'concrete'
    value_type = min
  []
  [max_tensile_yy_concrete]
    type = ElementExtremeValue
    variable = stress_yy
    block = 'concrete'
    value_type = max
  []
  [max_principal_stress_concrete]
    type = ElementExtremeValue
    variable = max_principal_stress
    block = 'concrete'
    value_type = max
  []
  [top_disp_y]
    type = PointValue
    point = '0 -5.0 0'
    variable = disp_y
  []
  [top_stress_vm]
    type = PointValue
    point = '0 -5.0 0'
    variable = vonmises_stress
  []
  [invert_disp_y]
    type = PointValue
    point = '0 -7.0 0'
    variable = disp_y
  []
  [invert_stress_vm]
    type = PointValue
    point = '0 -7.0 0'
    variable = vonmises_stress
  []
  [left_disp_x]
    type = PointValue
    point = '-1.0 -6.0 0'
    variable = disp_x
  []
  [left_stress_vm]
    type = PointValue
    point = '-1.0 -6.0 0'
    variable = vonmises_stress
  []
  [right_disp_x]
    type = PointValue
    point = '1.0 -6.0 0'
    variable = disp_x
  []
  [right_stress_vm]
    type = PointValue
    point = '1.0 -6.0 0'
    variable = vonmises_stress
  []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON
  line_search = 'bt'
  end_time = 2.0
  
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu mumps'
  automatic_scaling = true
  
  nl_abs_tol = 1e-8
  nl_rel_tol = 1e-5
  nl_max_its = 100
  dtmin = 1e-20
  timestep_tolerance = 1e-20

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 0.005
    cutback_factor = 0.5
    growth_factor = 1.2
  []
[]

[Outputs]
  exodus = true
  [csv]
    type = CSV
    file_base = 'output_instant_contact_large_kinematic_first'
  []
[]