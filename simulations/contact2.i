[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'contact2.msh' 
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

[Physics/SolidMechanics/QuasiStatic]
  [ground_physics]
    block = '6 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115' 
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    # ADDED: plastic_strain_yy
    generate_output = 'stress_yy vonmises_stress strain_yy plastic_strain_yy'
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
    penalty = 1e6                  
    formulation = penalty         
  []
[]

[Functions]
  [gravity_ramp]
    type = ParsedFunction
    expression = 'if(t<=1, t, 1.0)'
  []
  [surcharge_ramp]
    type = ParsedFunction
    expression = 'if(t<=1, 0.0, t-1)'
  []
[]

[Kernels]
  [gravity_y_native_ground]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2100
    block = '6'
    function = gravity_ramp
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = 'disp_y'
    value = -10
    density = 2400
    block = '1'
    function = gravity_ramp
  []
  [gravity_y_soil_layers]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '101 102 103 104 105 106 107 108 109 110 111 112 113 114 115'
    function = gravity_ramp
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
    function = surcharge_ramp
  []
  [pin_utilidor_center]
    type = DirichletBC
    variable = disp_x
    boundary = 'concrete_outer_wall' 
    value = 0
  []
[]

[UserObjects]
  # ==========================================================
  # 1. CONSTANT HARDENING PROPERTIES (Perfect Plasticity)
  # ==========================================================
  
  # --- Top Fill (Granular: c = 1 kPa, phi = 35 deg) ---
  [c_top]
    type = SolidMechanicsHardeningConstant
    value = 1e3
  []
  [phi_top]
    type = SolidMechanicsHardeningConstant
    value = 0.610865  # 35 degrees in radians
  []
  [psi_top]
    type = SolidMechanicsHardeningConstant
    value = 0.0       # Zero dilation
  []

  # --- Side Fill (CLSM: c = 150 kPa, phi = 38 deg) ---
  [c_side]
    type = SolidMechanicsHardeningConstant
    value = 150e3
  []
  [phi_side]
    type = SolidMechanicsHardeningConstant
    value = 0.663225  # 38 degrees in radians
  []
  [psi_side]
    type = SolidMechanicsHardeningConstant
    value = 0.0       
  []

  # --- Native Ground (Historic Fill: c = 15 kPa, phi = 28 deg) ---
  [c_native]
    type = SolidMechanicsHardeningConstant
    value = 15e3
  []
  [phi_native]
    type = SolidMechanicsHardeningConstant
    value = 0.488692  # 28 degrees in radians
  []
  [psi_native]
    type = SolidMechanicsHardeningConstant
    value = 0.0       
  []

  # ==========================================================
  # 2. DRUCKER-PRAGER YIELD MODELS
  # ==========================================================
  
  [dp_top_fill_model]
    type = SolidMechanicsPlasticDruckerPrager
    mc_cohesion = c_top
    mc_friction_angle = phi_top
    mc_dilation_angle = psi_top
    yield_function_tolerance = 1e-9
    internal_constraint_tolerance = 1e-9
  []
  
  [dp_side_fill_model]
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
  # --- Soil Elasticity Tensors ---
  [elasticity_tensor_all_soil]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = '6 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115'
  []

  # --- Soil Inelastic Stress Pipelines ---
  [soil_plasticity_top_fill]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_top_fill_model'
    block = '101 102 103 104 105 106 107 108 109 110'
    ep_plastic_tolerance = 1e-9
  []
  [soil_plasticity_side_fill]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_side_fill_model'
    block = '111 112 113 114 115'
    ep_plastic_tolerance = 1e-9
  []
  [soil_plasticity_native]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_native_model'
    block = '6'
    ep_plastic_tolerance = 1e-9
  []

  # --- Concrete (Linear Elastic) ---
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
[]

[Postprocessors]
  # --- Original Global Extreme Values ---
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
    # --- Soil Plasticity Tracking ---
  [max_plastic_strain_soil]
    type = ElementExtremeValue
    variable = plastic_strain_yy
    block = '6 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115'
    value_type = min 
  []    
  # --- Localized Plastic Strain (5cm into the soil) ---
  
  # Top Soil Yielding (5cm above utilidor roof)
  [top_plastic_strain]
    type = PointValue
    point = '0 -4.95 0'
    variable = plastic_strain_yy
  []

  # Bottom Soil Yielding (5cm below utilidor invert)
  [invert_plastic_strain]
    type = PointValue
    point = '0 -7.05 0'
    variable = plastic_strain_yy
  []

  # Left Trench Gap Yielding (5cm outside left wall)
  [left_plastic_strain]
    type = PointValue
    point = '-1.05 -6.0 0'
    variable = plastic_strain_yy
  []

  # Right Trench Gap Yielding (5cm outside right wall)
  [right_plastic_strain]
    type = PointValue
    point = '1.05 -6.0 0'
    variable = plastic_strain_yy
  []
  [max_settlement_y]
    type = NodalExtremeValue
    variable = disp_y
    value_type = min
  []
  [max_vm_ground]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '6 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115'
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
    block = '6 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115'
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
  [max_principal_stress_concrete]
    type = ElementExtremeValue
    variable = max_principal_stress
    block = '1'
    value_type = max
  []

  # --- Localized Point Postprocessors (Utilidor Faces) ---
  
  # Top Roof Center (x = 0, y = -d)
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

  # Bottom Invert Center (x = 0, y = -d - h)
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

  # Left Wall Center (x = -w/2, y = -d - h/2)
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

  # Right Wall Center (x = w/2, y = -d - h/2)
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
  line_search = 'bt' # Enabled backtracking for numerical stability in plastic zone
  end_time = 2.0

  petsc_options_iname = '-pc_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu       mumps'
  
  nl_abs_tol = 1e-4
  nl_rel_tol = 1e-4
  nl_max_its = 50

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 0.1
    cutback_factor = 0.5
    growth_factor = 1.1
  []
[]

[Outputs]
  exodus = true
  [csv]
    type = CSV
    file_base = 'output_instant_contact2'
  []
[]