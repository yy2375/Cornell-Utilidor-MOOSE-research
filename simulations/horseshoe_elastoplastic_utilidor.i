
# Loading values
gamma = 2.4e4 # TBD # N.m-3
K = 0.5 
# Rock properties
youngs_modulus = 3.3e10 #pa
poissons_ratio = 0.128 


[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  file = horseshoe2.msh
[]

[Physics/SolidMechanics/QuasiStatic]
  [all]
    incremental = true
    strain = SMALL
    generate_output = 'stress_xx stress_xy stress_yy strain_xx strain_xy strain_yy vonmises_stress effective_plastic_strain'
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
    value = -10 # m.s-2
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
        value = 30e6*t     # goes 0 -> 1 linearly as t goes 0..10
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
    variable = 'disp_y'
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

[UserObjects]
    [mc_coh]
        type = SolidMechanicsHardeningConstant
        value = 6.6e6 # TBD
    []
    [mc_phi]
        type = SolidMechanicsHardeningConstant
        value = 50 # TBD
        convert_to_radians = true
    []
    [mc_psi]
        type = SolidMechanicsHardeningConstant
        value = 12.5 # TBD
        convert_to_radians = true
    []
    [mc]
      type = SolidMechanicsPlasticMohrCoulomb
      cohesion = mc_coh
      friction_angle = mc_phi
      dilation_angle = mc_psi
      mc_lode_cutoff = 1.0E-6
      yield_function_tolerance = 1E-8 
      internal_constraint_tolerance = 1E-12 
      mc_tip_smoother = 6.6e5 # Typical 0.1*cohesion
      mc_edge_smoother = 15 # Default is 25 max is 30 min is 0
    []
  []

[Materials]
  [elasticity]
    type = ComputeIsotropicElasticityTensor 
    youngs_modulus = '${youngs_modulus}' # Pa
    poissons_ratio = '${poissons_ratio}'
    block = 'ground'
  []

  [mc]
    type = ComputeMultiPlasticityStress
    block = 'ground'
    ep_plastic_tolerance = 1E-15 
    plastic_models = mc
    max_NR_iterations = 100
 #   debug_fspb = crash
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
  end_time = 0.83
  start_time = 0
  dt = 0.01
  nl_max_its = 30 # 10 #
  nl_abs_tol = 1e-6 # 1e-6 #
  nl_rel_tol = 1e-8 # 1e-8 #
  solve_type = NEWTON # 
  l_tol = 1e-6 # 1E-6
  l_abs_tol = 1e-16
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

