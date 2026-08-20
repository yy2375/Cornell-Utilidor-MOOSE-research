# ==========================================
# 1. PARAMETERS & LOADING
# ==========================================
top_load = 3e5   # 300 kPa applied as Pressure
K = 1.0          # Lateral earth pressure coefficient

# Stratigraphic Geometry (Controlled by Python script)
H_fill = 4.0     # Depth of the fill interface

# 1. Anthropogenic Fill Properties
gamma_fill = 16e3            # 16 kN/m^3 (Loose historic fill)
youngs_modulus_fill = 15e6   # 15 MPa 
poissons_ratio_fill = 0.35 

# 2. Native Soil Properties
gamma_native = 20e3          # 20 kN/m^3 (Dense outwash/till)
youngs_modulus_native = 100e6 # 100 MPa
poissons_ratio_native = 0.30

# 3. Concrete Properties
youngs_modulus_concrete = 27.6e9 
poissons_ratio_concrete = 0.2    

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  file = test2_shell.msh 
[]

# ==========================================
# 2. PHYSICS & KERNELS
# ==========================================
[Physics/SolidMechanics/QuasiStatic]
  [soil_physics]
    strain = SMALL
    generate_output = 'stress_xx stress_xy stress_yy strain_xx strain_xy strain_yy vonmises_stress'
    add_variables = true
    block = 'fill native' # Applied to both soil blocks simultaneously
    material_output_family = 'MONOMIAL'
    material_output_order = 'CONSTANT'
    eigenstrain_names = ini_stress 
  []
  [concrete_physics]
    strain = SMALL
    generate_output = 'stress_xx stress_xy stress_yy strain_xx strain_xy strain_yy vonmises_stress'
    add_variables = true 
    block = 'concrete'
    material_output_family = 'MONOMIAL'
    material_output_order = 'CONSTANT'
  []
[]

[Kernels]
  [gravity_y_fill]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 1600 # gamma_fill/g
    block = 'fill'
  []
  [gravity_y_native]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000 # gamma_native/g
    block = 'native'
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = 'disp_y'
    value = -10
    density = 2400 
    block = 'concrete'
  []
[]

# ==========================================
# 3. BOUNDARY CONDITIONS (PIECEWISE)
# ==========================================
[Functions]
  [sigma_v]
    type = ParsedFunction
    symbol_names = 'gamma_fill gamma_native H_fill'
    symbol_values = '${gamma_fill} ${gamma_native} ${H_fill}'
    # Calculates exact vertical overburden pressure accounting for two different densities
    expression = 'if(y >= -H_fill, gamma_fill*y, -gamma_fill*H_fill + gamma_native*(y + H_fill))'
  []
  [-sigma_v]
    type = ParsedFunction
    symbol_names = 'gamma_fill gamma_native H_fill'
    symbol_values = '${gamma_fill} ${gamma_native} ${H_fill}'
    expression = '-(if(y >= -H_fill, gamma_fill*y, -gamma_fill*H_fill + gamma_native*(y + H_fill)))'
  []
  [sigma_h]
    type = ParsedFunction
    symbol_names = 'K gamma_fill gamma_native H_fill'
    symbol_values = '${K} ${gamma_fill} ${gamma_native} ${H_fill}'
    # Calculates lateral earth pressure across the discontinuous density boundary
    expression = 'K * if(y >= -H_fill, gamma_fill*y, -gamma_fill*H_fill + gamma_native*(y + H_fill))'
  []
  [-sigma_h]
    type = ParsedFunction
    symbol_names = 'K gamma_fill gamma_native H_fill'
    symbol_values = '${K} ${gamma_fill} ${gamma_native} ${H_fill}'
    expression = '-(K * if(y >= -H_fill, gamma_fill*y, -gamma_fill*H_fill + gamma_native*(y + H_fill)))'
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
  # 1. Fill Layer
  [elasticity_tensor_fill]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = '${youngs_modulus_fill}' 
    poissons_ratio = '${poissons_ratio_fill}'
    block = 'fill'
  []
  [linear_stress_fill]
    type = ComputeLinearElasticStress
    block = 'fill'
  []

  # 2. Native Layer
  [elasticity_tensor_native]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = '${youngs_modulus_native}' 
    poissons_ratio = '${poissons_ratio_native}'
    block = 'native'
  []
  [linear_stress_native]
    type = ComputeLinearElasticStress
    block = 'native'
  []

  # Common Initial Soil Stress Vector (Applies piecewise functions)
  [strain_from_initial_stress_soil] 
    type = ComputeEigenstrainFromInitialStress
    initial_stress = 'sigma_h 0 0 0 sigma_v 0 0 0 0'
    eigenstrain_name = ini_stress
    block = 'fill native'
  []

  # 3. Concrete Structure
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
  
  l_abs_tol = 1e-6
  l_tol = 1e-5
  l_max_its = 500
  nl_abs_tol = 1e-6
  nl_rel_tol = 1e-6
  nl_max_its = 50
  
  petsc_options_iname = '-ksp_type -pc_type -pc_asm_overlap -sub_pc_type -ksp_gmres_restart'
  petsc_options_value = 'gmres     asm      2               lu            200'
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

  # 2. ROOF MOMENT DATA 
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

  # 3. WALL MOMENT DATA 
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

  # 4. CORNER STRESS DATA
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
  
  # 5. STRAIN DATA
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

  # 6. TRUE VON MISES STRESS
  [max_sigma_vm]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = 'concrete'
    value_type = max
  []
[]