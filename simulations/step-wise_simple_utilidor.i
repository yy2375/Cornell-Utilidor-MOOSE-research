# Loading values
gamma = 2.4e4  # N.m-3
K = 0.5 
# Rock properties
youngs_modulus = 3.3e10 #pa
poissons_ratio = 0.128 

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
    value = -9.8 # m.s-2
    density = 2.4e3 # gamma/g
    block = 'ground'
  []
[]
[Functions]
    [sigma_v]
        type = ParsedFunction
        symbol_names = 'gamma'
        symbol_values = '${gamma}'
        value = gamma*y
    []
    [-sigma_v]
        type = ParsedFunction
        symbol_names = 'gamma'
        symbol_values = '${gamma}'
        value = -gamma*y
    []
    [sigma_h]
        type = ParsedFunction
        symbol_names = 'K gamma'
        symbol_values = '${K} ${gamma}'
        value = K*gamma*y
    []
    [-sigma_h]
        type = ParsedFunction
        symbol_names = 'K gamma'
        symbol_values = '${K} ${gamma}'
        value = -K*gamma*y
    []
    [p_top_stress]
        type = ParsedFunction
        value = 1e4*t     
    []

  []

[BCs]
# Dirichlet condition at the bottom
  [bottom_disp_y]
    type = DirichletBC
    variable = disp_y	
    boundary = 'bottom'
    value = 0
  []

# Neumann condition on the sides 
  [left_normal_stress]
    type = FunctionNeumannBC
    variable = disp_x	
    boundary = 'left'
    function = -sigma_h # Pa
  []
  [right_normal_stress]
    type = FunctionNeumannBC
    variable = disp_x	
    boundary = 'right'
    function = sigma_h # Pa
  []

# Alternatively, fixing the horizontal displacements instead of applying a horizontal stress should give similar results for K=1
#   [left_disp_x]
#     type = DirichletBC
#     variable = disp_x	
#     boundary = 'left'
#     value = 0
#   []
#   [right_disp_x]
#     type = DirichletBC
#     variable = disp_x	
#     boundary = 'right'
#     value = 0
#   []

# Pressure at the wall
  [cavityPressure_x]
    type = Pressure
    boundary = 'wall'
    variable = 'disp_x'
    factor = 0
  []
  [cavityPressure_y]
    type = Pressure
    boundary = 'wall'
    variable = disp_y
    factor = 0
  []



  [top_normal_stress]
     # TBD if traffic, buildings, people...
     type = Pressure
     boundary = "top"
     variable = 'disp_y'
     function = p_top_stress

  []
[]

[Materials]
  [elasticity_tensor]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = '${youngs_modulus}' # Pa
    poissons_ratio = '${poissons_ratio}'
    block = 'ground'
  []
  [linear_stress]
    type = ComputeLinearElasticStress
    block = 'ground'
  []
  [strain_from_initial_stress] # To initialize the displacement to zero based on in situ initial stress
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
  type = Transient
  end_time = 1
  start_time = 0 # 0.5 # 
  dt = 1E-2
  # num_steps = 1
  nl_max_its = 30 # 10 #
  nl_abs_tol = 1e-6 # 1e-6 #
  nl_rel_tol = 1e-8 # 1e-8 #
  solve_type = NEWTON # 
  l_tol = 1e-15 # 1E-6
  l_abs_tol = 1e-50
  l_max_its = 200
  line_search = none # basic # oes not converge if not set to none 
  petsc_options_iname = '-pc_type -pc_asm_overlap -sub_pc_type -ksp_type -ksp_gmres_restart'
  petsc_options_value = ' asm      2              lu            gmres     200'
[]



# [VectorPostprocessors]
#   [point_sample]
#     type = PositionsFunctorValueSampler
#     functors = 'disp_x disp_y stress_xx stress_xy stress_yy strain_xx strain_xy strain_yy'
#     positions = 'all_elements'
#     sort_by = 'x'
#     execute_on = TIMESTEP_END # Default value
#   []
# []

# [Positions]
#   [all_elements]
#     type = ElementCentroidPositions
#   []
# []

[Outputs]
    exodus = true
    csv = true
[]

