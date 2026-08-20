# ==========================================
# 1. PARAMETERS & LOADING
# ==========================================
top_load = 3e5   # 300 kPa applied as Pressure (Matches max Manhattan high-rise foundation surcharge)
gamma = 20e3     # 20 kN/m^3 (Standard unit weight for heavily compacted structural fill)
K = 1.0          # Lateral earth pressure for vibratory compacted sand (Range: 0.8 - 1.2)

# Ground properties (Engineered Compacted Structural Fill)
youngs_modulus_ground = 70e6 # 70 MPa (Reflects dense compacted sand/gravel)
poissons_ratio_ground = 0.3  # Standard for dense sand

# Concrete properties (Utilidor standard - ACI 318 / ASTM C1577)
youngs_modulus_concrete = 27.6e9 # 27.6 GPa (Standard for 4,000 psi compressive strength concrete)
poissons_ratio_concrete = 0.2    # Standard for structural concrete

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  file = test2_shell.msh # Replace with your actual conformal mesh file
[]

[Physics/SolidMechanics/QuasiStatic]
  [ground_physics]
    strain = SMALL
    generate_output = 'stress_xx stress_xy stress_yy strain_xx strain_xy strain_yy vonmises_stress'
    add_variables = true
    block = 'ground'
    material_output_family = 'MONOMIAL'
    material_output_order = 'CONSTANT'
    eigenstrain_names = ini_stress 
  []
  [concrete_physics]
    strain = SMALL
    generate_output = 'stress_xx stress_xy stress_yy strain_xx strain_xy strain_yy vonmises_stress'
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
    density = 2000 # gamma/g (Corrected for gamma = 20e3)
    block = 'ground'
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = 'disp_y'
    value = -10
    density = 2400 # kg.m-3 (Standard reinforced concrete density)
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
  
  # Tolerances (Adjusted for numerical reality)
  l_abs_tol = 1e-6
  l_tol = 1e-5
  l_max_its = 500
  nl_abs_tol = 1e-6
  nl_rel_tol = 1e-6
  nl_max_its = 50
  
  # Keep GMRES, but force a powerful preconditioner
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
  [max_sigma_vm]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = 'concrete'
    value_type = max
  []
[]