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
    friction_coefficient = 0.4
    formulation = penalty
    penalty = 0
  []
[]

[Functions]
  # --- Initial Gravity (Native Soil & Concrete) ---
  [ramp_initial]
    type = ParsedFunction
    expression = 'if(t<=0, 0.0, if(t<=1, t, 1.0))'
  []

  # --- Layer 15 (Stiffens t=1 to 1.2, Loads t=1.2 to 2) ---
  [E_ramp_115]
    type = ParsedFunction
    expression = 'if(t<=1, 1e4, if(t<=1.2, 1e4 + (80e6 - 1e6)*((t-1)/0.2), 80e6))'
  []
  [ramp_115]
    type = ParsedFunction
    expression = 'if(t<=1.2, 0.0, if(t<=2, (t-1.2)/0.8, 1.0))'
  []
  [nu_ramp_115]
    type = ParsedFunction
    expression = 'if(t<=1.2, 0.0, if(t<=2, 0.30*((t-1.2)/0.8), 0.30))'
  []

  # --- Layer 14 (Stiffens t=2 to 2.2, Loads t=2.2 to 3) ---
  [E_ramp_114]
    type = ParsedFunction
    expression = 'if(t<=2, 1e4, if(t<=2.2, 1e4 + (80e6 - 1e6)*((t-2)/0.2), 80e6))'
  []
  [ramp_114]
    type = ParsedFunction
    expression = 'if(t<=2.2, 0.0, if(t<=3, (t-2.2)/0.8, 1.0))'
  []
  [nu_ramp_114]
    type = ParsedFunction
    expression = 'if(t<=2.2, 0.0, if(t<=3, 0.30*((t-2.2)/0.8), 0.30))'
  []

  # --- Layer 13 (Stiffens t=3 to 3.2, Loads t=3.2 to 4) ---
  [E_ramp_113]
    type = ParsedFunction
    expression = 'if(t<=3, 1e4, if(t<=3.2, 1e4 + (80e6 - 1e6)*((t-3)/0.2), 80e6))'
  []
  [ramp_113]
    type = ParsedFunction
    expression = 'if(t<=3.2, 0.0, if(t<=4, (t-3.2)/0.8, 1.0))'
  []
  [nu_ramp_113]
    type = ParsedFunction
    expression = 'if(t<=3.2, 0.0, if(t<=4, 0.30*((t-3.2)/0.8), 0.30))'
  []

  # --- Layer 12 (Stiffens t=4 to 4.2, Loads t=4.2 to 5) ---
  [E_ramp_112]
    type = ParsedFunction
    expression = 'if(t<=4, 1e4, if(t<=4.2, 1e4 + (80e6 - 1e6)*((t-4)/0.2), 80e6))'
  []
  [ramp_112]
    type = ParsedFunction
    expression = 'if(t<=4.2, 0.0, if(t<=5, (t-4.2)/0.8, 1.0))'
  []
  [nu_ramp_112]
    type = ParsedFunction
    expression = 'if(t<=4.2, 0.0, if(t<=5, 0.30*((t-4.2)/0.8), 0.30))'
  []

  # --- Layer 11 (Stiffens t=5 to 5.2, Loads t=5.2 to 6) ---
  [E_ramp_111]
    type = ParsedFunction
    expression = 'if(t<=5, 1e4, if(t<=5.2, 1e4 + (80e6 - 1e6)*((t-5)/0.2), 80e6))'
  []
  [ramp_111]
    type = ParsedFunction
    expression = 'if(t<=5.2, 0.0, if(t<=6, (t-5.2)/0.8, 1.0))'
  []
  [nu_ramp_111]
    type = ParsedFunction
    expression = 'if(t<=5.2, 0.0, if(t<=6, 0.30*((t-5.2)/0.8), 0.30))'
  []

  # --- Layer 10 (Stiffens t=6 to 6.2, Loads t=6.2 to 7) ---
  [E_ramp_110]
    type = ParsedFunction
    expression = 'if(t<=6, 1e4, if(t<=6.2, 1e4 + (30e6 - 1e6)*((t-6)/0.2), 30e6))'
  []
  [ramp_110]
    type = ParsedFunction
    expression = 'if(t<=6.2, 0.0, if(t<=7, (t-6.2)/0.8, 1.0))'
  []
  [nu_ramp_110]
    type = ParsedFunction
    expression = 'if(t<=6.2, 0.0, if(t<=7, 0.35*((t-6.2)/0.8), 0.35))'
  []

  # --- Layer 9 (Stiffens t=7 to 7.2, Loads t=7.2 to 8) ---
  [E_ramp_109]
    type = ParsedFunction
    expression = 'if(t<=7, 1e4, if(t<=7.2, 1e4 + (30e6 - 1e6)*((t-7)/0.2), 30e6))'
  []
  [ramp_109]
    type = ParsedFunction
    expression = 'if(t<=7.2, 0.0, if(t<=8, (t-7.2)/0.8, 1.0))'
  []
  [nu_ramp_109]
    type = ParsedFunction
    expression = 'if(t<=7.2, 0.0, if(t<=8, 0.35*((t-7.2)/0.8), 0.35))'
  []

  # --- Layer 8 (Stiffens t=8 to 8.2, Loads t=8.2 to 9) ---
  [E_ramp_108]
    type = ParsedFunction
    expression = 'if(t<=8, 1e4, if(t<=8.2, 1e4 + (30e6 - 1e6)*((t-8)/0.2), 30e6))'
  []
  [ramp_108]
    type = ParsedFunction
    expression = 'if(t<=8.2, 0.0, if(t<=9, (t-8.2)/0.8, 1.0))'
  []
  [nu_ramp_108]
    type = ParsedFunction
    expression = 'if(t<=8.2, 0.0, if(t<=9, 0.35*((t-8.2)/0.8), 0.35))'
  []

  # --- Layer 7 (Stiffens t=9 to 9.2, Loads t=9.2 to 10) ---
  [E_ramp_107]
    type = ParsedFunction
    expression = 'if(t<=9, 1e4, if(t<=9.2, 1e4 + (30e6 - 1e6)*((t-9)/0.2), 30e6))'
  []
  [ramp_107]
    type = ParsedFunction
    expression = 'if(t<=9.2, 0.0, if(t<=10, (t-9.2)/0.8, 1.0))'
  []
  [nu_ramp_107]
    type = ParsedFunction
    expression = 'if(t<=9.2, 0.0, if(t<=10, 0.35*((t-9.2)/0.8), 0.35))'
  []

  # --- Layer 6 (Stiffens t=10 to 10.2, Loads t=10.2 to 11) ---
  [E_ramp_106]
    type = ParsedFunction
    expression = 'if(t<=10, 1e4, if(t<=10.2, 1e4 + (30e6 - 1e6)*((t-10)/0.2), 30e6))'
  []
  [ramp_106]
    type = ParsedFunction
    expression = 'if(t<=10.2, 0.0, if(t<=11, (t-10.2)/0.8, 1.0))'
  []
  [nu_ramp_106]
    type = ParsedFunction
    expression = 'if(t<=10.2, 0.0, if(t<=11, 0.35*((t-10.2)/0.8), 0.35))'
  []

  # --- Layer 5 (Stiffens t=11 to 11.2, Loads t=11.2 to 12) ---
  [E_ramp_105]
    type = ParsedFunction
    expression = 'if(t<=11, 1e4, if(t<=11.2, 1e4 + (30e6 - 1e6)*((t-11)/0.2), 30e6))'
  []
  [ramp_105]
    type = ParsedFunction
    expression = 'if(t<=11.2, 0.0, if(t<=12, (t-11.2)/0.8, 1.0))'
  []
  [nu_ramp_105]
    type = ParsedFunction
    expression = 'if(t<=11.2, 0.0, if(t<=12, 0.35*((t-11.2)/0.8), 0.35))'
  []

  # --- Layer 4 (Stiffens t=12 to 12.2, Loads t=12.2 to 13) ---
  [E_ramp_104]
    type = ParsedFunction
    expression = 'if(t<=12, 1e4, if(t<=12.2, 1e4 + (30e6 - 1e6)*((t-12)/0.2), 30e6))'
  []
  [ramp_104]
    type = ParsedFunction
    expression = 'if(t<=12.2, 0.0, if(t<=13, (t-12.2)/0.8, 1.0))'
  []
  [nu_ramp_104]
    type = ParsedFunction
    expression = 'if(t<=12.2, 0.0, if(t<=13, 0.35*((t-12.2)/0.8), 0.35))'
  []

  # --- Layer 3 (Stiffens t=13 to 13.2, Loads t=13.2 to 14) ---
  [E_ramp_103]
    type = ParsedFunction
    expression = 'if(t<=13, 1e4, if(t<=13.2, 1e4 + (30e6 - 1e6)*((t-13)/0.2), 30e6))'
  []
  [ramp_103]
    type = ParsedFunction
    expression = 'if(t<=13.2, 0.0, if(t<=14, (t-13.2)/0.8, 1.0))'
  []
  [nu_ramp_103]
    type = ParsedFunction
    expression = 'if(t<=13.2, 0.0, if(t<=14, 0.35*((t-13.2)/0.8), 0.35))'
  []

  # --- Layer 2 (Stiffens t=14 to 14.2, Loads t=14.2 to 15) ---
  [E_ramp_102]
    type = ParsedFunction
    expression = 'if(t<=14, 1e4, if(t<=14.2, 1e4 + (30e6 - 1e6)*((t-14)/0.2), 30e6))'
  []
  [ramp_102]
    type = ParsedFunction
    expression = 'if(t<=14.2, 0.0, if(t<=15, (t-14.2)/0.8, 1.0))'
  []
  [nu_ramp_102]
    type = ParsedFunction
    expression = 'if(t<=14.2, 0.0, if(t<=15, 0.35*((t-14.2)/0.8), 0.35))'
  []

  # --- Layer 1 (Stiffens t=15 to 15.2, Loads t=15.2 to 16) ---
  [E_ramp_101]
    type = ParsedFunction
    expression = 'if(t<=15, 1e4, if(t<=15.2, 1e4 + (30e6 - 1e6)*((t-15)/0.2), 30e6))'
  []
  [ramp_101]
    type = ParsedFunction
    expression = 'if(t<=15.2, 0.0, if(t<=16, (t-15.2)/0.8, 1.0))'
  []
  [nu_ramp_101]
    type = ParsedFunction
    expression = 'if(t<=15.2, 0.0, if(t<=16, 0.35*((t-15.2)/0.8), 0.35))'
  []

  # --- Surface Surcharge (Loads t=16 to 17) ---
  [surcharge_ramp]
    type = ParsedFunction
    expression = 'if(t<=16, 0.0, t-16)'
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
  [gravity_y_115]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_15'
    function = ramp_115
  []
  [gravity_y_114]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_14'
    function = ramp_114
  []
  [gravity_y_113]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_13'
    function = ramp_113
  []
  [gravity_y_112]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_12'
    function = ramp_112
  []
  [gravity_y_111]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_11'
    function = ramp_111
  []
  [gravity_y_110]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_10'
    function = ramp_110
  []
  [gravity_y_109]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_9'
    function = ramp_109
  []
  [gravity_y_108]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_8'
    function = ramp_108
  []
  [gravity_y_107]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_7'
    function = ramp_107
  []
  [gravity_y_106]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_6'
    function = ramp_106
  []
  [gravity_y_105]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_5'
    function = ramp_105
  []
  [gravity_y_104]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_4'
    function = ramp_104
  []
  [gravity_y_103]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_3'
    function = ramp_103
  []
  [gravity_y_102]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_2'
    function = ramp_102
  []
  [gravity_y_101]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = 'layer_1'
    function = ramp_101
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
    function = surcharge_ramp
  []
  [pin_center]
    type = DirichletBC
    variable = disp_x
    boundary = 'concrete_outer_wall'
    value = 0
  []
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
  # --- Layer 15 ---
  [props_115_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_115 nu_115'
    prop_values = 'E_ramp_115 nu_ramp_115'
    block = 'layer_15'
  []
  [elasticity_115]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_115
    poissons_ratio = nu_115
    args = 'disp_x disp_y'
    block = 'layer_15'
  []

  # --- Layer 14 ---
  [props_114_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_114 nu_114'
    prop_values = 'E_ramp_114 nu_ramp_114'
    block = 'layer_14'
  []
  [elasticity_114]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_114
    poissons_ratio = nu_114
    args = 'disp_x disp_y'
    block = 'layer_14'
  []

  # --- Layer 13 ---
  [props_113_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_113 nu_113'
    prop_values = 'E_ramp_113 nu_ramp_113'
    block = 'layer_13'
  []
  [elasticity_113]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_113
    poissons_ratio = nu_113
    args = 'disp_x disp_y'
    block = 'layer_13'
  []

  # --- Layer 12 ---
  [props_112_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_112 nu_112'
    prop_values = 'E_ramp_112 nu_ramp_112'
    block = 'layer_12'
  []
  [elasticity_112]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_112
    poissons_ratio = nu_112
    args = 'disp_x disp_y'
    block = 'layer_12'
  []

  # --- Layer 11 ---
  [props_111_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_111 nu_111'
    prop_values = 'E_ramp_111 nu_ramp_111'
    block = 'layer_11'
  []
  [elasticity_111]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_111
    poissons_ratio = nu_111
    args = 'disp_x disp_y'
    block = 'layer_11'
  []

  # --- Layer 10 ---
  [props_110_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_110 nu_110'
    prop_values = 'E_ramp_110 nu_ramp_110'
    block = 'layer_10'
  []
  [elasticity_110]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_110
    poissons_ratio = nu_110
    args = 'disp_x disp_y'
    block = 'layer_10'
  []

  # --- Layer 9 ---
  [props_109_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_109 nu_109'
    prop_values = 'E_ramp_109 nu_ramp_109'
    block = 'layer_9'
  []
  [elasticity_109]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_109
    poissons_ratio = nu_109
    args = 'disp_x disp_y'
    block = 'layer_9'
  []

  # --- Layer 8 ---
  [props_108_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_108 nu_108'
    prop_values = 'E_ramp_108 nu_ramp_108'
    block = 'layer_8'
  []
  [elasticity_108]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_108
    poissons_ratio = nu_108
    args = 'disp_x disp_y'
    block = 'layer_8'
  []

  # --- Layer 7 ---
  [props_107_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_107 nu_107'
    prop_values = 'E_ramp_107 nu_ramp_107'
    block = 'layer_7'
  []
  [elasticity_107]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_107
    poissons_ratio = nu_107
    args = 'disp_x disp_y'
    block = 'layer_7'
  []

  # --- Layer 6 ---
  [props_106_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_106 nu_106'
    prop_values = 'E_ramp_106 nu_ramp_106'
    block = 'layer_6'
  []
  [elasticity_106]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_106
    poissons_ratio = nu_106
    args = 'disp_x disp_y'
    block = 'layer_6'
  []

  # --- Layer 5 ---
  [props_105_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_105 nu_105'
    prop_values = 'E_ramp_105 nu_ramp_105'
    block = 'layer_5'
  []
  [elasticity_105]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_105
    poissons_ratio = nu_105
    args = 'disp_x disp_y'
    block = 'layer_5'
  []

  # --- Layer 4 ---
  [props_104_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_104 nu_104'
    prop_values = 'E_ramp_104 nu_ramp_104'
    block = 'layer_4'
  []
  [elasticity_104]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_104
    poissons_ratio = nu_104
    args = 'disp_x disp_y'
    block = 'layer_4'
  []

  # --- Layer 3 ---
  [props_103_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_103 nu_103'
    prop_values = 'E_ramp_103 nu_ramp_103'
    block = 'layer_3'
  []
  [elasticity_103]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_103
    poissons_ratio = nu_103
    args = 'disp_x disp_y'
    block = 'layer_3'
  []

  # --- Layer 2 ---
  [props_102_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_102 nu_102'
    prop_values = 'E_ramp_102 nu_ramp_102'
    block = 'layer_2'
  []
  [elasticity_102]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_102
    poissons_ratio = nu_102
    args = 'disp_x disp_y'
    block = 'layer_2'
  []

  # --- Layer 1 ---
  [props_101_mat]
    type = GenericFunctionMaterial
    prop_names = 'E_101 nu_101'
    prop_values = 'E_ramp_101 nu_ramp_101'
    block = 'layer_1'
  []
  [elasticity_101]
    type = ComputeVariableIsotropicElasticityTensor
    youngs_modulus = E_101
    poissons_ratio = nu_101
    args = 'disp_x disp_y'
    block = 'layer_1'
  []

  # --- Static Materials ---
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
  [soil_plasticity_top]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_top_model'
    block = 'layer_1 layer_2 layer_3 layer_4 layer_5 layer_6 layer_7 layer_8 layer_9 layer_10'
    ep_plastic_tolerance = 1e-9
  []
  [soil_plasticity_side]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_side_model'
    block = 'layer_11 layer_12 layer_13 layer_14 layer_15'
    ep_plastic_tolerance = 1e-9
  []
  [soil_plasticity_native]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_native_model'
    block = 'native_soil'
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
  end_time = 17.0
  
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu mumps'
  automatic_scaling = true
  
  nl_abs_tol = 1e-10
  nl_rel_tol = 1e-6
  nl_max_its = 15

  dtmin = 1e-6

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 0.05
    cutback_factor = 0.5
    growth_factor = 1.2
  []
[]

[Outputs]
  exodus = true
  [csv]
    type = CSV
    file_base = 'output_sequential_contact2.2'
  []
[]