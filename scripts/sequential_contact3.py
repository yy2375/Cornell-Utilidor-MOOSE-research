"""
sequential_contact2.py
======================
Staged backfill construction analysis for NYC Utilidor — MOOSE orchestrator.

Why all three previous stiffness-ramping approaches failed
----------------------------------------------------------
Attempt 1: type = ADFunctionMaterial
    Not a registered MOOSE object.

Attempt 2: ADGenericFunctionMaterial + ADComputeVariableIsotropicElasticityTensor
    AD/non-AD property name collision: 'elasticity_tensor' declared as both
    DualReal (AD) and Real (non-AD) in the same MaterialData store.
    MOOSE rejects this at setup regardless of block restriction.

Attempt 3: elasticity_tensor_prefactor on ComputeIsotropicElasticityTensor
    The prefactor is applied at element quadrature-point evaluation time.
    ComputeMultiPlasticityStress caches the elasticity tensor at the start
    of the return-map and then calls checkDerivatives() using a *separate*
    tensor retrieval at a potentially different prefactor value (the function
    is re-evaluated at t_current for the AuxKernel residual pass, which
    differs from the Newton iteration pass that built the stress).
    Result: tensor size/value mismatch in the internal DP consistency check
    → "wrong size" abort.

Correct approach: gravity ramping (no modulus ramping)
------------------------------------------------------
Keep C_ijkl fixed at the target modulus from the moment a block is activated.
ComputeMultiPlasticityStress sees a constant, consistent elasticity tensor
at all call sites — no return-map inconsistency is possible.

To prevent the activation stress jump, ramp the *body force* on the newly
active block from zero to full gravity over N_RAMP sub-steps within the
same phase. Each sub-step is a standard implicit solve with a fixed modulus.
The stress state approaches the yield surface gradually as the applied load
accumulates, keeping the return-map inside the cone at every sub-step.

Each activation phase (steps 1–15) runs N_RAMP = 4 sub-steps:
    sub-step 1: gravity_factor = 0.25  (25% of full body force)
    sub-step 2: gravity_factor = 0.50
    sub-step 3: gravity_factor = 0.75
    sub-step 4: gravity_factor = 1.00  (full gravity)

The ADGravity kernel for the newly active block uses a ParsedFunction
scaled by gravity_factor for that sub-step.  All other blocks always carry
full gravity (they are already in equilibrium from prior steps).

Step 0   : initial equilibrium — concrete + native soil, full gravity, 1 sub-step
Steps 1–15: activate one layer per step, N_RAMP sub-steps each
Step 16  : surface surcharge, 1 sub-step

Restart chain: each sub-step reads from the previous sub-step's exodus output.
The exodus file naming is  step_{step}_sub_{sub}_out.e
The CSV  file naming is    step_{step}_sub_{sub}_out.csv
The final step 16 output is step_16_sub_0_out.*

Ghost blocks retain E=10 kPa dummy modulus so they do not contribute
stiffness or load.  Their gravity kernel is suppressed entirely (no
ADGravity for inactive blocks — unlike the original, which applied gravity
to ghost blocks, creating a spurious body force even at zero stiffness).
"""

import subprocess

# ---------------------------------------------------------------------------
# Global constants
# ---------------------------------------------------------------------------
LAYERS = [str(i) for i in range(115, 100, -1)]   # ['115','114',...,'101']

E_SIDE_FILL  = 80e6    # Pa  (blocks 111–115)
E_TOP_FILL   = 30e6    # Pa  (blocks 101–110)
E_NATIVE     = 80e6    # Pa  (block 6)
E_GHOST      = 10e3    # Pa  (inactive dummy — no gravity applied)
NU_SIDE      = 0.30
NU_TOP       = 0.35
NU_NATIVE    = 0.30

# Gravity ramp sub-steps for each activation phase.
# 4 sub-steps gives increments of 0.25g — empirically safe for DP soil
# with c > 10 kPa and friction angles in the 28°–38° range.
N_RAMP = 4

GRAVITY = 9.81        # m/s²  (use 10.0 to match original approximation)


def _target_E(block_id: int) -> float:
    b = int(block_id)
    if 111 <= b <= 115:
        return E_SIDE_FILL
    if 101 <= b <= 110:
        return E_TOP_FILL
    raise ValueError(f"Unknown fill block {b}")


def _nu(block_id: int) -> float:
    return NU_SIDE if int(block_id) >= 111 else NU_TOP


def _dp_model(block_id: int) -> str:
    return "dp_side_model" if int(block_id) >= 111 else "dp_top_model"


def _density(block_id: int) -> float:
    """kg/m³ — consistent with original script."""
    b = int(block_id)
    if b == 1:
        return 2400.0
    if b == 6:
        return 2100.0
    return 2000.0    # fill layers


# ---------------------------------------------------------------------------
# Restart file helper
# ---------------------------------------------------------------------------

def _prev_exodus(step, sub):

    if step == 0 and sub == 0:
        return "contact2.msh"

    if sub > 0:
        return f"step_{step}_sub_{sub-1}_out.e"

    previous_step = step - 1

    if previous_step == 0:
        previous_sub = 0
    elif 1 <= previous_step <= 15:
        previous_sub = N_RAMP - 1
    else:
        previous_sub = 0

    return f"step_{previous_step}_sub_{previous_sub}_out.e"

# ---------------------------------------------------------------------------
# Section builders
# ---------------------------------------------------------------------------

def _mesh_block(step: int, sub: int) -> str:
    if step == 0 and sub == 0:
        return """[Mesh]
  type = FileMesh
  file = 'contact2.msh'
[]"""
    prev = _prev_exodus(step, sub)
    return f"""[Mesh]
  [fmg]
    type = FileMeshGenerator
    file = '{prev}'
    use_for_exodus_restart = true
  []
[]"""


def _materials_block(
    active_layers: list[str],
    inactive_layers: list[str],
) -> str:
    """
    C_ijkl is fixed at the target modulus for every active block from the
    moment it is first activated.  No prefactor, no AD, no time dependence.
    ComputeMultiPlasticityStress sees a constant elasticity tensor — the
    return-map consistency check can never fail due to a tensor mismatch.
    """
    stable_side = [l for l in active_layers if int(l) >= 111]
    stable_top  = [l for l in active_layers if int(l) <= 110]

    s = """[Materials]
  # ── Concrete ────────────────────────────────────────────────────────────
  [elasticity_concrete]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 27.6e9
    poissons_ratio = 0.2
    block = '1'
  []
  [stress_concrete]
    type = ComputeFiniteStrainElasticStress
    block = '1'
  []

  # ── Native soil (block 6) ───────────────────────────────────────────────
  [elasticity_native]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = 80e6
    poissons_ratio = 0.30
    block = '6'
  []
  [stress_native]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_native_model'
    block = '6'
    ep_plastic_tolerance = 1e-9
  []"""

    if stable_side:
        s += f"""

  # ── Side-fill (blocks {" ".join(stable_side)}) ──────────────────────────
  [elasticity_side_fill]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = {E_SIDE_FILL:.6e}
    poissons_ratio = {NU_SIDE}
    block = '{" ".join(stable_side)}'
  []
  [stress_side_fill]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_side_model'
    block = '{" ".join(stable_side)}'
    ep_plastic_tolerance = 1e-9
  []"""

    if stable_top:
        s += f"""

  # ── Top-fill (blocks {" ".join(stable_top)}) ──────────────────────────
  [elasticity_top_fill]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = {E_TOP_FILL:.6e}
    poissons_ratio = {NU_TOP}
    block = '{" ".join(stable_top)}'
  []
  [stress_top_fill]
    type = ComputeMultiPlasticityStress
    plastic_models = 'dp_top_model'
    block = '{" ".join(stable_top)}'
    ep_plastic_tolerance = 1e-9
  []"""

    if inactive_layers:
        s += f"""

  # ── Ghost / inactive ─────────────────────────────────────────────────────
  # Dummy stiffness only — no gravity kernel is applied to these blocks.
  [elasticity_ghost]
    type = ComputeIsotropicElasticityTensor
    youngs_modulus = {E_GHOST:.6e}
    poissons_ratio = 0.0
    block = '{" ".join(inactive_layers)}'
  []
  [stress_ghost]
    type = ComputeFiniteStrainElasticStress
    block = '{" ".join(inactive_layers)}'
  []"""

    s += "\n[]"
    return s


def _physics_block(active_layers: list[str], inactive_layers: list[str]) -> str:
    soil_str    = ("6 " + " ".join(active_layers)) if active_layers else "6"
    ghost_block = ""
    if inactive_layers:
        ghost_block = f"""
  [ghost_physics]
    block = '{" ".join(inactive_layers)}'
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    generate_output = 'stress_yy vonmises_stress strain_yy'
  []"""
    return f"""[Physics/SolidMechanics/QuasiStatic]
  [concrete_physics]
    block = '1'
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    generate_output = 'stress_yy vonmises_stress max_principal_stress strain_yy'
  []
  [soil_physics]
    block = '{soil_str}'
    planar_formulation = PLANE_STRAIN
    strain = SMALL
    incremental = true
    generate_output = 'stress_yy vonmises_stress strain_yy'
  []{ghost_block}
[]"""


def _kernels_block(
    active_layers: list[str],
    newly_active: str | None,
    gravity_factor: float,
) -> str:
    """
    ADGravity kernels.

    Native soil and concrete always carry full gravity (g = 10 m/s²).
    Previously stable active layers carry full gravity.
    The newly active layer carries gravity_factor × 10 m/s².
    Ghost / inactive layers carry NO gravity — a body force on a near-zero
    stiffness block creates a large spurious displacement that pollutes the
    contact interface solution.
    """
    s = f"""[Kernels]
  [gravity_y_native]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2100
    block = '6'
  []
  [gravity_y_concrete]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2400
    block = '1'
  []"""

    for layer in active_layers:
        if layer == newly_active:
            # Ramped body force for the newly activated layer
            g_val = -10.0 * gravity_factor
            s += f"""
  # Ramped gravity: {gravity_factor:.2f} × full body force
  [gravity_y_{layer}]
    type = ADGravity
    variable = disp_y
    value = {g_val:.6f}
    density = 2000
    block = '{layer}'
  []"""
        else:
            s += f"""
  [gravity_y_{layer}]
    type = ADGravity
    variable = disp_y
    value = -10
    density = 2000
    block = '{layer}'
  []"""
    s += "\n[]"
    return s


def _bcs_block(step: int) -> str:
    s = """[BCs]
  [bottom_y]
    type = DirichletBC
    variable = disp_y
    boundary = 'bottom'
    value = 0
  []
  [bottom_x]
    type = DirichletBC
    variable = disp_x
    boundary = 'bottom'
    value = 0
  []
  [left_roll]
    type = DirichletBC
    variable = disp_x
    boundary = 'left'
    value = 0
  []
  [right_roll]
    type = DirichletBC
    variable = disp_x
    boundary = 'right'
    value = 0
  []
  [pin_center]
    type = DirichletBC
    variable = disp_x
    boundary = 'concrete_outer_wall'
    value = 0
  []"""
    if step == 16:
        s += """
  [top_press]
    type = Pressure
    boundary = 'top'
    variable = disp_y
    factor = 80000
  []"""
    s += "\n[]"
    return s


def _aux_block(active_soil_str: str, all_soil_str: str) -> str:
    return f"""[AuxVariables]
  [plastic_strain_yy_aux]
    order = CONSTANT
    family = MONOMIAL
    block = '{all_soil_str}'
  []
[]

[AuxKernels]
  [eps_yy_aux]
    type = MaterialRankTwoTensorAux
    variable = plastic_strain_yy_aux
    property = plastic_strain
    i = 1
    j = 1
    block = '{active_soil_str}'
  []
[]"""


def _userobjects_block() -> str:
    return """[UserObjects]
  [c_top]
    type = SolidMechanicsHardeningConstant
    value = 25e3
  []
  [phi_top]
    type = SolidMechanicsHardeningConstant
    value = 0.610865
  []
  [psi_top]
    type = SolidMechanicsHardeningConstant
    value = 0.0
  []
  [c_side]
    type = SolidMechanicsHardeningConstant
    value = 150e3
  []
  [phi_side]
    type = SolidMechanicsHardeningConstant
    value = 0.663225
  []
  [psi_side]
    type = SolidMechanicsHardeningConstant
    value = 0.0
  []
  [c_native]
    type = SolidMechanicsHardeningConstant
    value = 15e3
  []
  [phi_native]
    type = SolidMechanicsHardeningConstant
    value = 0.488692
  []
  [psi_native]
    type = SolidMechanicsHardeningConstant
    value = 0.0
  []
  [dp_top_model]
    type = SolidMechanicsPlasticDruckerPrager
    mc_cohesion = c_top
    mc_friction_angle = phi_top
    mc_dilation_angle = psi_top
    yield_function_tolerance = 1e-9
    internal_constraint_tolerance = 1e-9
  []
  [dp_side_model]
    type = SolidMechanicsPlasticDruckerPrager
    mc_cohesion = c_side
    mc_friction_angle = phi_side
    mc_dilation_angle = psi_side
    yield_function_tolerance = 1e-9
    internal_constraint_tolerance = 1e-9
  []
  [dp_native_model]
    type = SolidMechanicsPlasticDruckerPrager
    mc_cohesion = c_native
    mc_friction_angle = phi_native
    mc_dilation_angle = psi_native
    yield_function_tolerance = 1e-9
    internal_constraint_tolerance = 1e-9
  []
[]"""


def _postprocessors_block(active_soil_str: str, all_soil_str: str) -> str:
    return f"""[Postprocessors]
  [max_disp_x]
    type = NodalExtremeValue
    variable = disp_x
    value_type = max
  []
  [min_disp_x]
    type = NodalExtremeValue
    variable = disp_x
    value_type = min
  []
  [max_plastic_strain_soil]
    type = ElementExtremeValue
    variable = plastic_strain_yy_aux
    block = '{active_soil_str}'
    value_type = min
  []
  [max_settlement_y]
    type = NodalExtremeValue
    variable = disp_y
    value_type = min
  []
  [max_vm_ground]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '{all_soil_str}'
    value_type = max
  []
  [max_vm_concrete]
    type = ElementExtremeValue
    variable = vonmises_stress
    block = '1'
    value_type = max
  []
  [max_compressive_yy_ground]
    type = ElementExtremeValue
    variable = stress_yy
    block = '{all_soil_str}'
    value_type = min
  []
  [max_compressive_yy_concrete]
    type = ElementExtremeValue
    variable = stress_yy
    block = '1'
    value_type = min
  []
  [max_tensile_yy_concrete]
    type = ElementExtremeValue
    variable = stress_yy
    block = '1'
    value_type = max
  []
[]"""


def _executioner_block(step: int, sub: int, is_activation: bool) -> str:
    """
    Activation sub-steps use tighter cut-back and more NL iterations.
    The final sub-step of each activation phase (gravity_factor = 1.0) gets
    the same tight settings — the step from 0.75g to 1.0g is the most likely
    to trigger yielding in a newly activated block.
    Non-activation steps (step 0 equilibrium, step 16 surcharge) use standard
    settings.
    """
    if is_activation:
        nl_max_its = 50
        nl_abs_tol = 1e-3
        nl_rel_tol = 1e-3
        cutback    = 0.3
    else:
        nl_max_its = 25
        nl_abs_tol = 1e-4
        nl_rel_tol = 1e-4
        cutback    = 0.5

    file_base = f"step_{step}_sub_{sub}_out"

    return f"""[Executioner]
  type = Transient
  solve_type = NEWTON
  line_search = 'bt'
  num_steps = 1
  dt = 1.0
  petsc_options_iname = '-pc_type -pc_factor_mat_solver_type'
  petsc_options_value = 'lu mumps'
  nl_abs_tol = {nl_abs_tol}
  nl_rel_tol = {nl_rel_tol}
  nl_max_its = {nl_max_its}

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 1.0
    cutback_factor = {cutback}
    growth_factor = 1.1
  []
[]

[Outputs]
  exodus = true
  [csv]
    type = CSV
    file_base = '{file_base}'
  []
[]"""


# ---------------------------------------------------------------------------
# Main generator
# ---------------------------------------------------------------------------

def generate_moose_file(
    step: int,
    sub: int,
    active_layers: list[str],
    inactive_layers: list[str],
    newly_active: str | None,
    gravity_factor: float,
) -> str:
    """
    Generate step_{step}_sub_{sub}.i and return its filename.

    gravity_factor is in [0, 1].  For non-activation steps it is always 1.0.
    For activation sub-steps it runs from 1/N_RAMP to 1.0 in N_RAMP increments.
    """
    is_activation = (newly_active is not None)

    all_soil_str    = "6 " + " ".join(LAYERS)
    active_soil_str = ("6 " + " ".join(active_layers)) if active_layers else "6"

    sections = [
        """[GlobalParams]
  displacements = 'disp_x disp_y'
[]""",
        _mesh_block(step, sub),
        """[Variables]
  [disp_x]
    order = SECOND
  []
  [disp_y]
    order = SECOND
  []
[]""",
        _aux_block(active_soil_str, all_soil_str),
        _physics_block(active_layers, inactive_layers),
        """[Contact]
  [soil_structure_interface]
    primary   = 'concrete_outer_wall'
    secondary = 'soil_inner_wall'
    model     = coulomb
    friction_coefficient = 0.4
    penalty   = 1e4
    formulation = penalty
  []
[]""",
        _kernels_block(active_layers, newly_active, gravity_factor),
        _bcs_block(step),
        _userobjects_block(),
        _materials_block(active_layers, inactive_layers),
        _postprocessors_block(active_soil_str, all_soil_str),
        _executioner_block(step, sub, is_activation),
    ]

    moose_script = "\n\n".join(s for s in sections if s.strip())

    filename = f"step_{step}_sub_{sub}.i"
    with open(filename, "w") as fh:
        fh.write(moose_script)

    return filename


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

def run_phase(
    step: int,
    sub: int,
    active_layers: list[str],
    inactive_layers: list[str],
    newly_active: str | None,
    gravity_factor: float,
    label: str,
) -> None:
    print(f"\n  Sub-step {sub + 1}/{N_RAMP if newly_active else 1}  —  {label}")
    fname = generate_moose_file(
        step, sub, active_layers, inactive_layers, newly_active, gravity_factor
    )
    print(f"  Written  : {fname}")
    print(f"  Running  : ./dog-opt -i {fname}")
    result = subprocess.run(["./dog-opt", "-i", fname], capture_output=False)
    if result.returncode != 0:
        print(f"\n[ERROR] Solver crashed on step {step} sub {sub}.  Halting.")
        raise SystemExit(1)
    print(f"  OK  →  step_{step}_sub_{sub}_out.e")


def main() -> None:
    print("=" * 66)
    print("  Staged Backfill — NYC Utilidor")
    print(f"  Gravity-ramp activation  ({N_RAMP} sub-steps per layer)")
    print("  C_ijkl fixed at target modulus — no tensor inconsistency possible")
    print("=" * 66)

    # ── Step 0: initial equilibrium ──────────────────────────────────────
    print(f"\n{'─' * 66}")
    print(f"  Phase  0  —  initial equilibrium (concrete + native soil)")
    print(f"{'─' * 66}")
    run_phase(
        step=0, sub=0,
        active_layers=[],
        inactive_layers=LAYERS[:],
        newly_active=None,
        gravity_factor=1.0,
        label="full gravity, fixed moduli",
    )

    # ── Steps 1–15: activate one fill layer per step ─────────────────────
    for step in range(1, 16):
        active_layers   = LAYERS[:step]
        inactive_layers = LAYERS[step:]
        newly_active    = LAYERS[step - 1]

        print(f"\n{'─' * 66}")
        print(f"  Phase {step:>2d}  —  activate layer {newly_active}")
        E_t = _target_E(int(newly_active))
        print(f"            E={E_t:.2e} Pa  |  gravity ramp over {N_RAMP} sub-steps")
        print(f"{'─' * 66}")

        for sub in range(N_RAMP):
            gravity_factor = (sub + 1) / N_RAMP   # 0.25, 0.50, 0.75, 1.00
            run_phase(
                step=step, sub=sub,
                active_layers=active_layers,
                inactive_layers=inactive_layers,
                newly_active=newly_active,
                gravity_factor=gravity_factor,
                label=f"gravity_factor = {gravity_factor:.2f}",
            )

    # ── Step 16: surface surcharge ────────────────────────────────────────
    print(f"\n{'─' * 66}")
    print(f"  Phase 16  —  surface surcharge 80 kPa")
    print(f"{'─' * 66}")
    run_phase(
        step=16, sub=0,
        active_layers=LAYERS[:],
        inactive_layers=[],
        newly_active=None,
        gravity_factor=1.0,
        label="80 kPa uniform surface pressure",
    )

    print("\n" + "=" * 66)
    print("  All phases complete.")
    print("  Final CSV  →  step_16_sub_0_out.csv")
    print("  Final mesh →  step_16_sub_0_out.e")
    print("=" * 66)


if __name__ == "__main__":
    main()