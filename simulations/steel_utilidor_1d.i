[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = 'utilidor_1d.e' 
  []
  [gen_top]
    type = ParsedGenerateSideset
    input = fmg
    combinatorial_geometry = 'y > -0.001'
    new_sideset_name = 'top'
    included_subdomains = '1 2 3'
  []
  [gen_bottom]
    type = ParsedGenerateSideset
    input = gen_top
    combinatorial_geometry = 'y < -30.499'
    new_sideset_name = 'bottom'
    included_subdomains = '1 2 3'
  []
  [gen_left]
    type = ParsedGenerateSideset
    input = gen_bottom
    combinatorial_geometry = 'x < -10.999'
    new_sideset_name = 'left'
    included_subdomains = '1 2 3'
  []
  [gen_right]
    type = ParsedGenerateSideset
    input = gen_left
    combinatorial_geometry = 'x > 10.999'
    new_sideset_name = 'right'
    included_subdomains = '1 2 3'
  []
[]

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Variables]
  [disp_x]
  []
  [disp_y]
  []
[]

[Physics/SolidMechanics/QuasiStatic]
  [soil]
    block = '2 3'
    planar_formulation = PLANE_STRAIN
    generate_output = 'vonmises_stress stress_xx stress_yy'
    eigenstrain_names = ini_stress
    strain = SMALL
  []
  [concrete]
    block = '1'
    planar_formulation = PLANE_STRAIN
    generate_output = 'vonmises_stress stress_xx stress_yy'
    strain = SMALL
  []
[]

[Kernels]
  [truss_x]
    type = StressDivergenceTensorsTruss
    variable = disp_x
    component = 0
    block = '4 5'
  []
  [truss_y]
    type = StressDivergenceTensorsTruss
    variable = disp_y
    component = 1
    block = '4 5'
  []
  [gravity_y_soil]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = '2 3'
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2400 
    block = '1'
  []
[]

[Functions]
  [sigma_v]
    type = ParsedFunction
    expression = '20000 * y'
  []
  [sigma_h]
    type = ParsedFunction
    expression = '20000 * y'
  []
  [-sigma_h]
    type = ParsedFunction
    expression = '-20000 * y'
  []
[]

[BCs]
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
  [top_pressure]
    type = Pressure
    variable = disp_y
    boundary = 'top'
    factor = 3e5 
  []
[]

[Materials]
  [fill_elasticity]
    type = ComputeIsotropicElasticityTensor
    block = '2'
    youngs_modulus = 70e6
    poissons_ratio = 0.3
  []
  [fill_stress]
    type = ComputeLinearElasticStress
    block = '2'
  []
  [native_elasticity]
    type = ComputeIsotropicElasticityTensor
    block = '3'
    youngs_modulus = 100e6 
    poissons_ratio = 0.3
  []
  [native_stress]
    type = ComputeLinearElasticStress
    block = '3'
  []
  [strain_from_initial_stress_soil] 
    type = ComputeEigenstrainFromInitialStress
    initial_stress = 'sigma_h 0 0 0 sigma_v 0 0 0 0'
    eigenstrain_name = ini_stress
    block = '2 3'
  []
  [concrete_elasticity]
    type = ComputeIsotropicElasticityTensor
    block = '1'
    youngs_modulus = 27.6e9 
    poissons_ratio = 0.2
  []
  [concrete_stress]
    type = ComputeLinearElasticStress
    block = '1'
  []
  [steel_elasticity]
    type = ComputeIsotropicElasticityTensor
    block = '4 5'
    youngs_modulus = 200e9 
    poissons_ratio = 0.3
  []
  [steel_stress]
    type = ComputeLinearElasticStress
    block = '4 5'
  []
  [rebar_area]
    type = GenericConstantMaterial
    block = '4 5'
    prop_names = 'cross_sectional_area'
    prop_values = '0.00142' 
  []
[]

[Executioner]
  type = Steady
  solve_type = 'NEWTON'
  l_abs_tol = 1e-6
  l_tol = 1e-5
  l_max_its = 500
  nl_abs_tol = 1e-6
  nl_rel_tol = 1e-6
  nl_max_its = 50
  petsc_options_iname = '-pc_type -ksp_type'
  petsc_options_value = 'lu       preonly'
[]

[Postprocessors]
  [u_y_crown]
    type = PointValue
    variable = disp_y
    point = '0 -5.2 0'
  []
  [u_y_invert]
    type = PointValue
    variable = disp_y
    point = '0 -6.8 0'
  []
  [max_stress_outer_rebar]
    type = ElementExtremeValue
    variable = axial_stress
    block = '4'
    value_type = max
  []
  [max_stress_inner_rebar]
    type = ElementExtremeValue
    variable = axial_stress
    block = '5'
    value_type = max
  []
[]

[Outputs]
  exodus = true
  console = true
  [csv]
    type = CSV
    precision = 12
    file_base = 'elastic_steel_utilidor_out'
  []
[]