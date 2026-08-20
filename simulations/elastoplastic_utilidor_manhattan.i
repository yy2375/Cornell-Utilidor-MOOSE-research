
gamma = 25e3 # TBD # N.m-3
K = 0.5 # TBD 
# Rock properties
youngs_modulus = 8e9 # TBD # Pa
poissons_ratio = 0.28 # TBD

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Mesh]
  file = simple_utilidor.msh
[]

[Physics/SolidMechanics/QuasiStatic]
  [all]
    incremental = true
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
    value = -10 # m.s-2
    density = 18e2 # gamma/g
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
    [p_ramp]
        type = ParsedFunction
        expression = 1.0e5*(t/10)     # goes 0 -> 1 linearly as t goes 0..10
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
    function = p_ramp
  []
  [cavityPressure_y]
    type = Pressure
    boundary = 'wall'
    variable = disp_y
    function = p_ramp
  []



# [top_normal_stress]
#     # TBD if traffic, buildings, people...
# []
[]

[UserObjects]
    [mc_coh]
        type = SolidMechanicsHardeningConstant
        value = 1E6 # TBD
    []
    [mc_phi]
        type = SolidMechanicsHardeningConstant
        value = 35 # TBD
        convert_to_radians = true
    []
    [mc_psi]
        type = SolidMechanicsHardeningConstant
        value = 10 # TBD
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
      mc_tip_smoother = 1E5 # Typical 0.1*cohesion
      mc_edge_smoother = 25 # Default is 25 max is 30 min is 0
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
    debug_fspb = crash
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
  end_time = 0.1
  start_time = 0
  dt = 0.01
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
