# These are blocks you may need to add if you look at a plastic behavior of the rock. 
# The UserObjects block defines the failure criterion such as Mohr-Coulomb or Hoek and Brown of Von Mises
# The Materials block defines the elastic parameters (Young's modulus and Poisson's ratio) and adds the plastic parameters (cohesion, friction angle and dilatancy angle) defined in the UserObjects block
# The Executioner block is defined as Transient because it is easier to apply small incremental loading steps to make the code concverge
# In the Executioner block, the time is not actually the real time but rather represents some incremental loading steps
# Have fun!

[UserObjects]
    [mc_coh]
        type = SolidMechanicsHardeningConstant
        value = 1E6 # TBD
    []
    [mc_phi]
        type = SolidMechanicsHardeningConstant
        value = 27 # TBD
        convert_to_radians = true
    []
    [mc_psi]
        type = SolidMechanicsHardeningConstant
        value = 9 # TBD
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
    block = 'rock'
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
  end_time = 1
  start_time = 0 # 0.5 # 
  dt = 1E-1
  # num_steps = 1
  nl_max_its = 30 # 10 #
  nl_abs_tol = 1e-12 # 1e-6 #
  nl_rel_tol = 1e-12 # 1e-8 #
  solve_type = NEWTON # 
  l_tol = 1e-15 # 1E-6
  l_abs_tol = 1e-50
  l_max_its = 200
  line_search = none # basic # oes not converge if not set to none 
  petsc_options_iname = '-pc_type -pc_asm_overlap -sub_pc_type -ksp_type -ksp_gmres_restart'
  petsc_options_value = ' asm      2              lu            gmres     200'
[]