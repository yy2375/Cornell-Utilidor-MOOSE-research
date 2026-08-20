top_load = 300e3 # 1.1 MPa applied as Pressure on the top boundary
gamma = 20e3     # N.m-3
K = 1

# Ground properties
youngs_modulus_ground = 70e6 # Pa
poissons_ratio_ground = 0.3

# Concrete properties
youngs_modulus_concrete = 27.6e9 # Pa
poissons_ratio_concrete = 0.2

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  file = experiment.msh # Replace with your actual conformal mesh file
[]

[Physics/SolidMechanics/QuasiStatic]
  [ground_physics]
    strain = SMALL
    generate_output = 'stress_xx stress_xy stress_yy strain_xx strain_xy strain_yy'
    add_variables = true
    block = 'ground'
    material_output_family = 'MONOMIAL'
    material_output_order = 'CONSTANT'
    eigenstrain_names = ini_stress 
  []
  [concrete_physics]
    strain = SMALL
    generate_output = 'stress_xx stress_xy stress_yy strain_xx strain_xy strain_yy'
    add_variables = true # MOOSE will merge this safely with the ground variables
    block = 'concrete'
    material_output_family = 'MONOMIAL'
    material_output_order = 'CONSTANT'
  []
[]

[Kernels]
  [gravity_y_ground]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 20e2 # gamma/g
    block = 'ground'
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = 'disp_y'
    value = -10
    density = 2400 # kg.m-3
    block = 'concrete'
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
  [right_disp_x]
    type = DirichletBC
    variable = disp_x 
    boundary = 'right'
    value = 0
  []
  [left_disp_x]
    type = DirichletBC
    variable = disp_x 
    boundary = 'left'
    value = 0
  []
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
  # Ground Materials
  [elasticity_tensor_ground]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = '${youngs_modulus_ground}' 
    poissons_ratio = '${poissons_ratio_ground}'
    block = 'ground'
  []
  [linear_stress_ground]
    type = ComputeLinearElasticStress
    block = 'ground'
  []
  [strain_from_initial_stress_ground] 
    type = ComputeEigenstrainFromInitialStress
    initial_stress = 'sigma_h 0 0 0 sigma_v 0 0 0 0'
    eigenstrain_name = ini_stress
    block = 'ground'
  []

  # Concrete Materials
  [elasticity_tensor_concrete]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = '${youngs_modulus_concrete}'
    poissons_ratio = '${poissons_ratio_concrete}'
    block = 'concrete'
  []
  [linear_stress_concrete]
    type = ComputeLinearElasticStress
    block = 'concrete'
  []
  # Initial stress strictly excluded from concrete block
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
  l_abs_tol = 1e-4
  l_tol = 1e-4
  l_max_its = 10000
  line_search = none
  nl_abs_tol = 1E-4
  nl_rel_tol = 1E-4
  nl_max_its = 5000
[]

[Outputs]
  exodus = true
  [csv]
    type = CSV
    precision = 12
    file_base = 'concrete_utilidor_out'
  []
[]
