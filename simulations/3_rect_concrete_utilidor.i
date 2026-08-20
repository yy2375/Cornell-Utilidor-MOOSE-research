# ==========================================
# 1. PARAMETERS & STRATIGRAPHY (Manhattan Baseline)
# ==========================================
top_load = 3e5   # 300 kPa applied as Pressure (Manhattan high-rise surcharge)

# Stratigraphic Geometry
H_fill = 4.0     # Depth of the fill interface (meters)

# 1. Anthropogenic Fill Properties (Historic Fill / Debris)
gamma_fill = 16e3            # 16 kN/m^3 
K_fill = 1.0                 # High lateral pressure due to loose compaction
youngs_modulus_fill = 15e6   # 15 MPa 
poissons_ratio_fill = 0.35 

# 2. Native Soil Properties (Homogenized Glacial Till / Weathered Schist)
gamma_native = 21e3          # 21 kN/m^3 (Dense/Consolidated)
K_native = 0.5               # 0.5 (Standard at-rest earth pressure for dense soils)
youngs_modulus_native = 200e6 # 200 MPa (Reflects deep till/rock transition)
poissons_ratio_native = 0.30

# 3. Concrete Properties (ACI 318)
youngs_modulus_concrete = 27.6e9 
poissons_ratio_concrete = 0.2    

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  file = 3_layer.msh 
[]

# ==========================================
# 2. PHYSICS & KERNELS
# ==========================================
[Physics/SolidMechanics/QuasiStatic]
  [soil_physics]
    strain = SMALL
    generate_output = 'stress_xx stress_xy stress_yy strain_xx strain_xy strain_yy vonmises_stress'
    add_variables = true
    block = 'fill native' 
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
    density = 1600 
    block = 'fill'
  []
  [gravity_y_native]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2100 # Updated for gamma_native = 21e3
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
    symbol_names = 'K_fill K_native gamma_fill gamma_native H_fill'
    symbol_values = '${K_fill} ${K_native} ${gamma_fill} ${gamma_native} ${H_fill}'
    expression = 'if(y >= -H_fill, K_fill*gamma_fill*y, K_native*(-gamma_fill*H_fill + gamma_native*(y + H_fill)))'
  []
  [-sigma_h]
    type = ParsedFunction
    symbol_names = 'K_fill K_native gamma_fill gamma_native H_fill'
    symbol_values = '${K_fill} ${K_native} ${gamma_fill} ${gamma_native} ${H_fill}'
    expression = '-(if(y >= -H_fill, K_fill*gamma_fill*y, K_native*(-gamma_fill*H_fill + gamma_native*(y + H_fill))))'
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

  # 3. Initial Soil Stress Vector
  [strain_from_initial_stress_soil] 
    type = ComputeEigenstrainFromInitialStress
    initial_stress = 'sigma_h 0 0 0 sigma_v 0 0 0 0'
    eigenstrain_name = ini_stress
    block = 'fill native'
  []

  # 4. Concrete Structure
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
[]

[Postprocessors]
  [max_sigma_vm]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = 'concrete'
    value_type = max
  []
  [max_settlement]
    type = NodalExtremeValue
    variable = disp_y
    boundary = 'top' 
    value_type = min
  []
[]