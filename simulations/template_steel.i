# ==========================================
# 1. PARAMETERS & LOADING (YOUR AI FEATURES)
# ==========================================
top_load = 3e5   # AI Input X_1 (Surcharge Pressure, Pa)
gamma = 20e3     # Geotechnical Unit Weight (N/m^3)
K = 1.0          # AI Input X_2 (Lateral Earth Pressure Coef)

# Material Moduli
youngs_modulus_ground = 70e6
poissons_ratio_ground = 0.3
youngs_modulus_concrete = 27.6e9
poissons_ratio_concrete = 0.2
youngs_modulus_steel = 200e9
poissons_ratio_steel = 0.3

# Steel Plasticity 
yield_strength_steel = 420e6   # Grade 60 Rebar Yield Limit (Pa)
hardening_modulus = 2e9        # Slight strain hardening for solver stability

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

# ==========================================
# 2. MESH & BULLETPROOF BOUNDARIES
# ==========================================
[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'template_steel.msh' 
  []
  [gen_top]
    type = ParsedGenerateSideset
    input = fmg
    combinatorial_geometry = 'y > -0.001'
    new_sideset_name = 'top'
  []
  [gen_bottom]
    type = ParsedGenerateSideset
    input = gen_top
    combinatorial_geometry = 'y < -30.499'
    new_sideset_name = 'bottom'
  []
  [gen_left]
    type = ParsedGenerateSideset
    input = gen_bottom
    combinatorial_geometry = 'x < -10.999'
    new_sideset_name = 'left'
  []
  [gen_right]
    type = ParsedGenerateSideset
    input = gen_left
    combinatorial_geometry = 'x > 10.999'
    new_sideset_name = 'right'
  []
[]

# ==========================================
# 3. VARIABLES (ENFORCING 2ND ORDER MATH)
# ==========================================
[Variables]
  [disp_x]
    order = SECOND
  []
  [disp_y]
    order = SECOND
  []
[]

# ==========================================
# 4. PHYSICS (GENERATING AI TARGET VARIABLES)
# ==========================================
[Physics/SolidMechanics/QuasiStatic]
  [ground_physics]
    block = '2 3' 
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    generate_output = 'vonmises_stress'
    eigenstrain_names = ini_stress 
  []
  [concrete_physics]
    block = '1' 
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    # Explicitly commands MOOSE to calculate 1st Principal Stress for the AI
    generate_output = 'max_principal_stress' 
  []
  [steel_physics]
    block = '4 5' 
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    generate_output = 'vonmises_stress'
  []
[]

# ==========================================
# 5. LOADING & BOUNDARY CONDITIONS
# ==========================================
[Functions]
  [sigma_v]
    type = ParsedFunction
    symbol_names = 'gamma'
    symbol_values = '${gamma}'
    expression = 'gamma*y'
  []
  [sigma_h]
    type = ParsedFunction
    symbol_names = 'K gamma'
    symbol_values = '${K} ${gamma}'
    expression = 'K*gamma*y'
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
    function = -sigma_h  # Pushes inward (positive X)
  []
  [right_normal_stress]
    type = FunctionNeumannBC
    variable = disp_x 
    boundary = 'right'
    function = sigma_h   # Pushes inward (negative X)
  []
  [top_normal_stress]
    type = Pressure
    boundary = 'top'
    variable = 'disp_y'
    factor = '${top_load}' 
  []
[]

# ==========================================
# 6. MATERIALS (NON-LINEAR STEEL PLASTICITY)
# ==========================================
[Materials]
  # Ground
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

  # Concrete (Linear - AI predicts cracking threshold via max_principal_stress)
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

  # Steel (Non-Linear Elastoplasticity)
  [elasticity_tensor_steel]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = '${youngs_modulus_steel}'
    poissons_ratio = '${poissons_ratio_steel}'
    block = '4 5'
  []
  [plastic_stress_steel]
    type = ComputeMultipleInelasticStress
    inelastic_models = 'steel_plasticity'
    block = '4 5'
  []
  [steel_plasticity]
    type = IsotropicPlasticity
    yield_stress = '${yield_strength_steel}'
    hardening_constant = '${hardening_modulus}'
  []
[]

# ==========================================
# 7. AI TARGET POSTPROCESSORS
# ==========================================
[Postprocessors]
  # A. SERVICEABILITY (Deflections track Block 1 regardless of size)
  [roof_midspan_deflection]
    type = NodalExtremeValue
    variable = disp_y
    block = '1' 
    value_type = min 
  []
  [left_wall_convergence]
    type = NodalExtremeValue
    variable = disp_x
    block = '1'
    value_type = max 
  []
  [right_wall_convergence]
    type = NodalExtremeValue
    variable = disp_x
    block = '1'
    value_type = min 
  []

  # B. CONCRETE LIMIT STATE (Tracks first principal stress for tensile cracking)
  [max_principal_stress_concrete]
    type = ElementExtremeValue
    variable = max_principal_stress
    block = '1'
    value_type = max
  []

  # C. STEEL YIELD STATE (Tracks Von Mises against 420 MPa limit)
  [max_vm_outer_steel]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '4'
    value_type = max
  []
  [max_vm_inner_steel]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '5'
    value_type = max
  []

  # D. GEOTECHNICAL FAILURE STATE
  [max_soil_stress]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '2 3'
    value_type = max
  []
[]

# ==========================================
# 8. SOLVER & OUTPUTS
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
  console = false
  [csv]
    type = CSV
    precision = 12
    file_base = 'utilidor_ai_data'
  []
[]