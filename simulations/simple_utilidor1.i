# Loading values
gamma = 2.4e4 # N.m-3
K = 1.5 
# Rock properties
youngs_modulus = 3.3e10 # Pa
poissons_ratio = 0.128 
top_load = 100000#default

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  file = simple_utilidor.msh
[]

[Physics/SolidMechanics/QuasiStatic]
  [all]
    strain = SMALL
    generate_output = 'stress_xx stress_xy stress_yy strain_xx strain_xy strain_yy '
    add_variables = true
    block = 'ground'
    material_output_family = 'MONOMIAL'
    material_output_order = 'CONSTANT'
    eigenstrain_names = ini_stress 
  []
[]

[Kernels]
  [gravity_y]
    type = ADGravity
    variable = 'disp_y' 
    value = -9.8
    density = '${fparse gamma / 9.8}' 
    block = 'ground'
  []
[]

[Functions]
  [sigma_v]
    type = ParsedFunction
    symbol_names = 'gamma'
    symbol_values = '${gamma}'
    expression = 'gamma*y'
  []
  [-sigma_v]
    type = ParsedFunction
    symbol_names = 'gamma'
    symbol_values = '${gamma}'
    expression = '-gamma*y'
  []
  [sigma_h]
    type = ParsedFunction
    symbol_names = 'K gamma'
    symbol_values = '${K} ${gamma}'
    expression = 'K*gamma*y'
  []
  [-sigma_h]
    type = ParsedFunction
    symbol_names = 'K gamma'
    symbol_values = '${K} ${gamma}'
    expression = '-K*gamma*y'
  []
[]

[BCs]
  [bottom_disp_y]
    type = DirichletBC
    variable = disp_y 
    boundary = 'bottom'
    value = 0
  []
  [left_normal_stress]
    type = FunctionNeumannBC
    variable = disp_x 
    boundary = 'left'
    function = -sigma_h 
  []
  [right_normal_stress]
    type = FunctionNeumannBC
    variable = disp_x 
    boundary = 'right'
    function = sigma_h 
  []
  [cavityPressure_x]
    type = Pressure
    boundary = 'wall'
    variable = 'disp_x'
    factor = 0 
  []
  [cavityPressure_y]
    type = Pressure
    boundary = 'wall'
    variable = 'disp_y'
    factor = 0 
  []
  [top_normal_stress]
    type = Pressure
    boundary = 'top'
    variable = 'disp_y'
    factor = '${top_load}' 
  []
[]

[Materials]
  [elasticity_tensor]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = '${youngs_modulus}' 
    poissons_ratio = '${poissons_ratio}'
    block = 'ground'
  []
  [linear_stress]
    type = ComputeLinearElasticStress
    block = 'ground'
  []
  [strain_from_initial_stress]
    type = ComputeEigenstrainFromInitialStress
    initial_stress = 'sigma_h 0 0 0 sigma_v 0 0 0 0'
    eigenstrain_name = ini_stress
    block = 'ground'
  []
[]

[Preconditioning]
  [SMP]
    type = SMP
    full = true
  []
[]

[Executioner]
  type = Steady 
  solve_type = NEWTON
  l_abs_tol = 1e-50
  l_tol = 1e-50
  l_max_its = 10000
  line_search = none
  nl_abs_tol = 1E-10
  nl_rel_tol = 1E-10
  nl_max_its = 500
[]

[Outputs]
  exodus = true
  [csv]
    type = CSV
    precision = 12
    file_base = 'simple_utilidor1_out'
  []
[]

[Postprocessors]
  [max_wall_deflection]
    type = NodalExtremeValue
    variable = disp_y
    boundary = 'wall'
  []

  # TOP POINTS
  [top_disp_x]
    type = PointValue
    point = '0 0 0'
    variable = disp_x
  []
  [top_disp_y]
    type = PointValue
    point = '0 0 0'
    variable = disp_y
  []
  [top_stress_xx]
    type = PointValue
    point = '0 0 0'
    variable = stress_xx
  []
  [top_stress_yy]
    type = PointValue
    point = '0 0 0'
    variable = stress_yy
  []
  [top_stress_xy]
    type = PointValue
    point = '0 0 0'
    variable = stress_xy
  []
  [top_strain_xx]
    type = PointValue
    point = '0 0 0'
    variable = strain_xx
  []
  [top_strain_yy]
    type = PointValue
    point = '0 0 0'
    variable = strain_yy
  []
  [top_strain_xy]
    type = PointValue
    point = '0 0 0'
    variable = strain_xy
  []

  # BOTTOM POINTS
  [bottom_disp_x]
    type = PointValue
    point = '0 0 0'
    variable = disp_x
  []
  [bottom_disp_y]
    type = PointValue
    point = '0 0 0'
    variable = disp_y
  []
  [bottom_stress_xx]
    type = PointValue
    point = '0 0 0'
    variable = stress_xx
  []
  [bottom_stress_yy]
    type = PointValue
    point = '0 0 0'
    variable = stress_yy
  []
  [bottom_stress_xy]
    type = PointValue
    point = '0 0 0'
    variable = stress_xy
  []
  [bottom_strain_xx]
    type = PointValue
    point = '0 0 0'
    variable = strain_xx
  []
  [bottom_strain_yy]
    type = PointValue
    point = '0 0 0'
    variable = strain_yy
  []
  [bottom_strain_xy]
    type = PointValue
    point = '0 0 0'
    variable = strain_xy
  []

  # RIGHT POINTS
  [right_disp_x]
    type = PointValue
    point = '0 0 0'
    variable = disp_x
  []
  [right_disp_y]
    type = PointValue
    point = '0 0 0'
    variable = disp_y
  []
  [right_stress_xx]
    type = PointValue
    point = '0 0 0'
    variable = stress_xx
  []
  [right_stress_yy]
    type = PointValue
    point = '0 0 0'
    variable = stress_yy
  []
  [right_stress_xy]
    type = PointValue
    point = '0 0 0'
    variable = stress_xy
  []
  [right_strain_xx]
    type = PointValue
    point = '0 0 0'
    variable = strain_xx
  []
  [right_strain_yy]
    type = PointValue
    point = '0 0 0'
    variable = strain_yy
  []
  [right_strain_xy]
    type = PointValue
    point = '0 0 0'
    variable = strain_xy
  []

  # LEFT POINTS
  [left_disp_x]
    type = PointValue
    point = '0 0 0'
    variable = disp_x
  []
  [left_disp_y]
    type = PointValue
    point = '0 0 0'
    variable = disp_y
  []
  [left_stress_xx]
    type = PointValue
    point = '0 0 0'
    variable = stress_xx
  []
  [left_stress_yy]
    type = PointValue
    point = '0 0 0'
    variable = stress_yy
  []
  [left_stress_xy]
    type = PointValue
    point = '0 0 0'
    variable = stress_xy
  []
  [left_strain_xx]
    type = PointValue
    point = '0 0 0'
    variable = strain_xx
  []
  [left_strain_yy]
    type = PointValue
    point = '0 0 0'
    variable = strain_yy
  []
  [left_strain_xy]
    type = PointValue
    point = '0 0 0'
    variable = strain_xy
  []
[]