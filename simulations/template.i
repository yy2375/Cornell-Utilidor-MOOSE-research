# ==========================================
# 1. PARAMETERS & LOADING
# ==========================================
top_load = 6e5   # 600 kPa applied as Pressure
gamma = 20e3     # 20 kN/m^3 (Compacted structural fill)
K = 1.0          # Lateral earth pressure

# Ground properties (Engineered Compacted Structural Fill)
youngs_modulus_ground = 70e6 
poissons_ratio_ground = 0.3  

# Concrete properties (Utilidor standard - ACI 318)
youngs_modulus_concrete = 27.6e9 
poissons_ratio_concrete = 0.2    

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  file = rect_shell.msh
[]

# ==========================================
# 2. PHYSICS & KERNELS
# ==========================================
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
    add_variables = true 
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
    density = 2000 # gamma/g
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

# ==========================================
# 3. BOUNDARY CONDITIONS
# ==========================================
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
  [bottom_disp_x]
    type = DirichletBC
    variable = disp_x 
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

# ==========================================
# 4. MATERIALS
# ==========================================
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
[]

# ==========================================
# 5. SOLVER & POSTPROCESSORS
# ==========================================
[Preconditioning]
  [SMP]
    type = SMP
    full = true
  []
[]

[Executioner]
  type = Steady 
  solve_type = NEWTON
  
 
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu       superlu_dist'

  l_abs_tol = 1e-8
  l_tol = 1e-8
  l_max_its = 100
  nl_abs_tol = 1e-6
  nl_rel_tol = 1e-8
  nl_max_its = 200
[]

[Outputs]
  exodus = true
  [csv]
    type = CSV
    precision = 12
    file_base = 'concrete_utilidor_out'
  []
[]

[Postprocessors]
  # 1. DISPLACEMENTS
  [u_y_crown]
    type = PointValue
    point = 'CROWN_OUTER'
    variable = disp_y
  []
  [u_y_invert]
    type = PointValue
    point = 'INVERT_INNER'
    variable = disp_y
  []

  # 2. ROOF MOMENT DATA (Horizontal Stress at Midspan)
  [roof_stress_top]
    type = PointValue
    point = 'CROWN_OUTER'
    variable = stress_xx
  []
  [roof_stress_bottom]
    type = PointValue
    point = 'CROWN_INNER'
    variable = stress_xx
  []

  # 3. WALL MOMENT DATA (Vertical Stress at Mid-height)
  [wall_stress_outer]
    type = PointValue
    point = 'WALL_OUTER'
    variable = stress_yy
  []
  [wall_stress_inner]
    type = PointValue
    point = 'WALL_INNER'
    variable = stress_yy
  []

  # 4. CORNER STRESS CONCENTRATION
  [corner_stress_xx]
    type = PointValue
    point = 'CORNER_INNER'
    variable = stress_xx
  []
  [corner_stress_yy]
    type = PointValue
    point = 'CORNER_INNER'
    variable = stress_yy
  []
  # 5. STRAIN POSTPROCESSORS
  [corner_strain_xx]
    type = PointValue
    point = 'CORNER_INNER'
    variable = strain_xx
  []
  [corner_strain_yy]
    type = PointValue
    point = 'CORNER_INNER'
    variable = strain_yy
  []
  [corner_strain_xy]
    type = PointValue
    point = 'CORNER_INNER'
    variable = strain_xy
  []
  [crown_strain_xx]
    type = PointValue
    point = 'CROWN_INNER'
    variable = strain_xx
  []
  [wall_strain_yy]
    type = PointValue
    point = 'WALL_INNER'
    variable = strain_yy
  []
[]