[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'loading_thin_layer.msh' 
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
    generate_output = 'stress_xx stress_yy vonmises_stress strain_yy'
  []
  [concrete_physics]
    block = 'concrete'
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    generate_output = 'stress_xx stress_yy vonmises_stress max_principal_stress strain_yy' 
  []
  [interface_physics]
    block = 'interface'
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    generate_output = 'stress_xx stress_yy vonmises_stress strain_yy'
  []
[]

[Functions]
  [ramp_initial]
    type = ParsedFunction
    expression = 'if(t<=0, 0.0, if(t<=1, t, 1.0))'
  []
  
  [dynamic_multi_load]
    type = ParsedFunction
    symbol_names = 'num_loads m1 w1 c1 m2 w2 c2 m3 w3 c3'
    # PARAMETERS: Modify the values below to change the loading scenario
    symbol_values = '2 40000.0 1.0 -2.0 60000.0 1.5 3.0 0.0 1.0 0.0'
    expression = 't * (if(num_loads>=1,1,0)*m1*if(abs(x-c1)<=w1/2,1.0,0.0) + if(num_loads>=2,1,0)*m2*if(abs(x-c2)<=w2/2,1.0,0.0) + if(num_loads>=3,1,0)*m3*if(abs(x-c3)<=w3/2,1.0,0.0))'
  []
[]

[Kernels]
  [gravity_y_native]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2100
    block = 'native_soil'
    function = ramp_initial
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2400
    block = 'concrete'
    function = ramp_initial
  []
  [gravity_y_interface]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2100
    block = 'interface'
    function = ramp_initial
  []
  [gravity_y_layers]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10 layer_11 layer_12 layer_13 layer_14 layer_15'
    function = ramp_initial
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
  [top_press_dynamic]
    type = Pressure
    boundary = 'top'
    variable = disp_y
    factor = 1.0
    function = dynamic_multi_load
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
  [elasticity_layers]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10 layer_11 layer_12 layer_13 layer_14 layer_15'
  []
  [elasticity_native]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = 'native_soil'
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
  [elasticity_interface]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = 'interface'
  []
  [linear_stress_interface]
    type = ComputeFiniteStrainElasticStress
    block = 'interface'
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
    point = '0 -0.95 0'
    variable = plastic_strain_yy_aux
  []
  [invert_plastic_strain]
    type = PointValue
    point = '0 -3.05 0'
    variable = plastic_strain_yy_aux
  []
  [left_plastic_strain]
    type = PointValue
    point = '-1.05 -2.0 0'
    variable = plastic_strain_yy_aux
  []
  [right_plastic_strain]
    type = PointValue
    point = '1.05 -2.0 0'
    variable = plastic_strain_yy_aux
  []
  
  [top_disp_y]
    type = PointValue
    point = '0 -1.0 0'
    variable = disp_y
  []
  [top_disp_x]
    type = PointValue
    point = '0 -1.0 0'
    variable = disp_x
  []
  [top_stress_yy]
    type = PointValue
    point = '0 -1.0 0'
    variable = stress_yy
  []
  [top_stress_xx]
    type = PointValue
    point = '0 -1.0 0'
    variable = stress_xx
  []
  [top_stress_vm]
    type = PointValue
    point = '0 -1.0 0'
    variable = vonmises_stress
  []

  [invert_disp_y]
    type = PointValue
    point = '0 -3.0 0'
    variable = disp_y
  []
  [invert_disp_x]
    type = PointValue
    point = '0 -3.0 0'
    variable = disp_x
  []
  [invert_stress_yy]
    type = PointValue
    point = '0 -3.0 0'
    variable = stress_yy
  []
  [invert_stress_xx]
    type = PointValue
    point = '0 -3.0 0'
    variable = stress_xx
  []
  [invert_stress_vm]
    type = PointValue
    point = '0 -3.0 0'
    variable = vonmises_stress
  []

  [left_disp_x]
    type = PointValue
    point = '-1.0 -2.0 0'
    variable = disp_x
  []
  [left_disp_y]
    type = PointValue
    point = '-1.0 -2.0 0'
    variable = disp_y
  []
  [left_stress_yy]
    type = PointValue
    point = '-1.0 -2.0 0'
    variable = stress_yy
  []
  [left_stress_xx]
    type = PointValue
    point = '-1.0 -2.0 0'
    variable = stress_xx
  []
  [left_stress_vm]
    type = PointValue
    point = '-1.0 -2.0 0'
    variable = vonmises_stress
  []

  [right_disp_x]
    type = PointValue
    point = '1.0 -2.0 0'
    variable = disp_x
  []
  [right_disp_y]
    type = PointValue
    point = '1.0 -2.0 0'
    variable = disp_y
  []
  [right_stress_yy]
    type = PointValue
    point = '1.0 -2.0 0'
    variable = stress_yy
  []
  [right_stress_xx]
    type = PointValue
    point = '1.0 -2.0 0'
    variable = stress_xx
  []
  [right_stress_vm]
    type = PointValue
    point = '1.0 -2.0 0'
    variable = vonmises_stress
  []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON
  line_search = 'bt'
  end_time = 1.0
  
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu mumps'
  automatic_scaling = true
  
  nl_abs_tol = 1e-8
  nl_rel_tol = 1e-5
  nl_max_its = 100
  
  # Adjusted tolerance to prevent phantom micro-steps at the end of the simulation
  dtmin = 1e-8
  timestep_tolerance = 1e-8


  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 1
    cutback_factor = 0.5
    growth_factor = 1.2
  []
[]

[Outputs]
  exodus = true
  [csv]
    type = CSV
    file_base = 'instant_parametric_load'
    execute_on = 'INITIAL TIMESTEP_END FAILED'
  []
[]