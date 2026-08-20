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

[Materials]
  [elasticity_tensor_all_soil]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = '6 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115'
  []
  [linear_stress_ground]
    type = ComputeFiniteStrainElasticStress
    block = '6 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115'
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

  # ==========================================================
  # 1:1 COMPARISON POINT TRACKERS
  # ==========================================================
  
  # --- 1. Utilidor Crown Center (x = 0, y = -d) ---
  [crown_disp_y]
    type = PointValue
    point = '0 -5.0 0'
    variable = disp_y
  []
  [crown_stress_yy]
    type = PointValue
    point = '0 -5.0 0'
    variable = stress_yy
  []
  [crown_vm_stress]
    type = PointValue
    point = '0 -5.0 0'
    variable = vonmises_stress
  []

  # --- 2. Utilidor Invert Center (x = 0, y = -d - h) ---
  [invert_disp_y]
    type = PointValue
    point = '0 -7.0 0'
    variable = disp_y
  []
  [invert_stress_yy]
    type = PointValue
    point = '0 -7.0 0'
    variable = stress_yy
  []
  [invert_vm_stress]
    type = PointValue
    point = '0 -7.0 0'
    variable = vonmises_stress
  []

  # --- 3. Trench Surface Center (x = 0, y = 0) ---
  [surface_disp_y]
    type = PointValue
    point = '0 0.0 0'
    variable = disp_y
  []

  # --- 4. Left Wall Center (x = -w/2, y = -d - h/2) ---
  [left_wall_disp_x]
    type = PointValue
    point = '-1.0 -6.0 0'
    variable = disp_x
  []
  [left_wall_vm_stress]
    type = PointValue
    point = '-1.0 -6.0 0'
    variable = vonmises_stress
  []

  # --- 5. Right Wall Center (x = w/2, y = -d - h/2) ---
  [right_wall_disp_x]
    type = PointValue
    point = '1.0 -6.0 0'
    variable = disp_x
  []
  [right_wall_vm_stress]
    type = PointValue
    point = '1.0 -6.0 0'
    variable = vonmises_stress
  []
[]

[Executioner]
  type = Transient 
  solve_type = NEWTON
  line_search = 'none'
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
    file_base = 'output_instant_contact'
  []
[]