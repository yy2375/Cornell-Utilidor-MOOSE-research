# ==========================================
# 1. PARAMETERS & LOADING
# ==========================================
top_load = 3e5   # 300 kPa applied as Pressure
gamma = 20e3     # 20 kN/m^3
K = 1.0          # Lateral earth pressure

# Material Moduli
youngs_modulus_ground = 70e6
poissons_ratio_ground = 0.3
youngs_modulus_concrete = 27.6e9
poissons_ratio_concrete = 0.2
youngs_modulus_steel = 200e9
poissons_ratio_steel = 0.3

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
    type = FileMesh
    file = 'steel_utilidor.msh'
 
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
    block = '2 3' # Fill and Native
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    generate_output = 'stress_xx stress_yy vonmises_stress'
    eigenstrain_names = ini_stress 
  []
  [concrete_physics]
    block = '1' # Concrete Core and Cover
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    generate_output = 'stress_xx stress_yy vonmises_stress'
  []
  [steel_physics]
    block = '4 5' # Outer and Inner Rebar Shells
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    generate_output = 'stress_xx stress_yy vonmises_stress'
  []
[]

[Kernels]
  [gravity_y_ground]
    type = ADGravity
    variable = 'disp_y' 
    value = -10
    density = 2000
    block = '2 3'
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = 'disp_y'
    value = -10
    density = 2400
    block = '1'
  []
  [gravity_y_steel]
    type = ADGravity
    variable = 'disp_y'
    value = -10
    density = 7850
    block = '4 5'
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
  [top_normal_stress]
    type = Pressure
    boundary = 'top'
    variable = 'disp_y'
    factor = '${top_load}' 
  []
[]

[Materials]
  # 1. Ground Materials
  [elasticity_tensor_ground]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = '${youngs_modulus_ground}' 
    poissons_ratio = '${poissons_ratio_ground}'
    block = '2 3'
  []
  [linear_stress_ground]
    type = ComputeLinearElasticStress
    block = '2 3'
  []
  [strain_from_initial_stress_ground] 
    type = ComputeEigenstrainFromInitialStress
    initial_stress = 'sigma_h 0 0 0 sigma_v 0 0 0 0'
    eigenstrain_name = ini_stress
    block = '2 3'
  []

  # 2. Concrete Materials
  [elasticity_tensor_concrete]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = '${youngs_modulus_concrete}'
    poissons_ratio = '${poissons_ratio_concrete}'
    block = '1'
  []
  [linear_stress_concrete]
    type = ComputeLinearElasticStress
    block = '1'
  []

  # 3. Steel Materials
  [elasticity_tensor_steel]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = '${youngs_modulus_steel}'
    poissons_ratio = '${poissons_ratio_steel}'
    block = '4 5'
  []
  [linear_stress_steel]
    type = ComputeLinearElasticStress
    block = '4 5'
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
  console = true
  [csv]
    type = CSV
    precision = 12
    file_base = '2d_steel_utilidor_out'
  []
[]

[Postprocessors]
  [max_sigma_vm_concrete]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '1'
    value_type = max
  []
  [max_sigma_vm_steel_outer]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '4'
    value_type = max
  []
  [max_sigma_vm_steel_inner]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '5'
    value_type = max
  []
[]