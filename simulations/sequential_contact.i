[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'contact.msh' 
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
  [steel_physics]
    block = '4 5' 
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    generate_output = 'stress_yy vonmises_stress strain_yy'
  []
[]

[Contact]
  [soil_structure_interface]
    primary = 'concrete_outer_wall' 
    secondary = 'soil_inner_wall'   
    model = coulomb                 
    friction_coefficient = 0.4      
    penalty = 1e7                   
    formulation = penalty         
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
  # Fills from the bottom (115) up to the top (101)
  [ramp_115]
    type = ParsedFunction
    expression = 'if(t<=0, 0.0, if(t<=1, t, 1.0))'
  []
  [ramp_114]
    type = ParsedFunction
    expression = 'if(t<=1, 0.0, if(t<=2, t-1, 1.0))'
  []
  [ramp_113]
    type = ParsedFunction
    expression = 'if(t<=2, 0.0, if(t<=3, t-2, 1.0))'
  []
  [ramp_112]
    type = ParsedFunction
    expression = 'if(t<=3, 0.0, if(t<=4, t-3, 1.0))'
  []
  [ramp_111]
    type = ParsedFunction
    expression = 'if(t<=4, 0.0, if(t<=5, t-4, 1.0))'
  []
  [ramp_110]
    type = ParsedFunction
    expression = 'if(t<=5, 0.0, if(t<=6, t-5, 1.0))'
  []
  [ramp_109]
    type = ParsedFunction
    expression = 'if(t<=6, 0.0, if(t<=7, t-6, 1.0))'
  []
  [ramp_108]
    type = ParsedFunction
    expression = 'if(t<=7, 0.0, if(t<=8, t-7, 1.0))'
  []
  [ramp_107]
    type = ParsedFunction
    expression = 'if(t<=8, 0.0, if(t<=9, t-8, 1.0))'
  []
  [ramp_106]
    type = ParsedFunction
    expression = 'if(t<=9, 0.0, if(t<=10, t-9, 1.0))'
  []
  [ramp_105]
    type = ParsedFunction
    expression = 'if(t<=10, 0.0, if(t<=11, t-10, 1.0))'
  []
  [ramp_104]
    type = ParsedFunction
    expression = 'if(t<=11, 0.0, if(t<=12, t-11, 1.0))'
  []
  [ramp_103]
    type = ParsedFunction
    expression = 'if(t<=12, 0.0, if(t<=13, t-12, 1.0))'
  []
  [ramp_102]
    type = ParsedFunction
    expression = 'if(t<=13, 0.0, if(t<=14, t-13, 1.0))'
  []
  [ramp_101]
    type = ParsedFunction
    expression = 'if(t<=14, 0.0, if(t<=15, t-14, 1.0))'
  []
  [surcharge_ramp]
    type = ParsedFunction
    expression = 'if(t<=15, 0.0, t-15)'
  []
[]

[Kernels]
  [gravity_y_native_ground]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2100
    block = '6'
    function = ramp_115
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = 'disp_y'
    value = -10
    density = 2400
    block = '1'
    function = ramp_115
  []
  [gravity_y_steel]
    type = ADGravity
    variable = 'disp_y'
    value = -10
    density = 7850
    block = '4 5'
    function = ramp_115
  []
  [gravity_y_115]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '115'
    function = ramp_115
  []
  [gravity_y_114]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '114'
    function = ramp_114
  []
  [gravity_y_113]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '113'
    function = ramp_113
  []
  [gravity_y_112]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '112'
    function = ramp_112
  []
  [gravity_y_111]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '111'
    function = ramp_111
  []
  [gravity_y_110]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '110'
    function = ramp_110
  []
  [gravity_y_109]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '109'
    function = ramp_109
  []
  [gravity_y_108]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '108'
    function = ramp_108
  []
  [gravity_y_107]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '107'
    function = ramp_107
  []
  [gravity_y_106]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '106'
    function = ramp_106
  []
  [gravity_y_105]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '105'
    function = ramp_105
  []
  [gravity_y_104]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '104'
    function = ramp_104
  []
  [gravity_y_103]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '103'
    function = ramp_103
  []
  [gravity_y_102]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '102'
    function = ramp_102
  []
  [gravity_y_101]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '101'
    function = ramp_101
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
  [elasticity_tensor_side_fill]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = '111 112 113 114 115'
  []
  [elasticity_tensor_top_fill]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 30e6
    poissons_ratio = 0.35
    block = '101 102 103 104 105 106 107 108 109 110'
  []
  [elasticity_tensor_native]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = '6'
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
  [max_vm_steel]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '4 5'
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
  [max_compressive_yy_steel]
    type = ElementExtremeValue
    variable = stress_yy
    block = '4 5'
    value_type = min
  []
  [max_principal_stress_concrete]
    type = ElementExtremeValue
    variable = max_principal_stress
    block = '1'
    value_type = max
  []
  [max_plastic_strain_steel]
    type = ElementExtremeValue
    variable = effective_plastic_strain
    block = '4 5'
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
  # Tracks actual settlement of the top fill under the 80 kPa surcharge
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
  end_time = 16.0

  petsc_options_iname = '-pc_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu       mumps'
  
  nl_abs_tol = 1e-4
  nl_rel_tol = 1e-4
  nl_max_its = 10

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
    file_base = 'output_sequential_contact'
  []
[]