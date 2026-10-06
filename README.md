# NYC Utilidor Structural Analysis & ML Surrogate Pipeline

[![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://www.python.org/)
[![JAX](https://img.shields.io/badge/JAX-Equinox-orange.svg)](https://github.com/patrick-kidger/equinox)
[![MOOSE](https://img.shields.io/badge/MOOSE-Framework-lightgrey.svg)](https://mooseframework.inl.gov/)

Computational pipeline for integrated utility tunnel (utilidor) structural stability analysis in heterogeneous New York City geology. This project establishes a baseline methodology integrating automated `Gmsh` mesh generation, the MOOSE finite element framework, and `JAX`/`Equinox` neural network surrogate modeling. 

## 1. Engineering Problem
NYC’s subterranean utility infrastructure relies on an antiquated "direct burial" system, causing frequent excavations and traffic congestion. Utilidors offer a "Smart City" solution, but implementation requires navigating NYC’s heterogeneous geology—ranging from unconsolidated soil to Manhattan schist. This project provides a computational framework to evaluate utilidor structural performance and accelerate design iterations using machine learning.

## 2. Methodology & Computational Workflow
The pipeline automates parameterization, finite element analysis (FEA), and surrogate training:

*   **Geometry & Meshing (`Gmsh`):** Automated generation of 2D cross-sections (e.g., elliptical, rectangular, and filleted geometries) at varying crown depths (1.5 m to 10.0 m) and dimensions (1.5 m × 2.0 m to 4.0 m × 4.0 m).
*   **Finite Element Analysis (`MOOSE`):** A 2D elastic plane strain model simulates structural performance across heterogeneous soil-rock interfaces under parameterized surface loading (up to 2.0 MPa). The solver extracts 39 high-precision node variables (displacements, stress tensors, strain tensors).
*   **Target Output:** Target variables include 12 critical stress and displacement components utilized for model training.

## 3. ML Surrogate Model
The surrogate model bypasses computationally expensive MOOSE FEA runs to provide instant structural predictions.
*   **Architecture:** Dynamic Multi-Layer Perceptron (MLP) built with `JAX` and `Equinox`, utilizing `GELU` activations.
*   **Training Mechanics:** XLA compiled (`@eqx.filter_jit`) and optimized via `Optax` AdamW with cosine decay, gradient clipping, and early stopping. 
*   **Data Processing:** Ingests geometric, soil, and loading features using standard scaling and Z-score outlier rejection.

## 4. Results & Structural Findings
*   **Optimal Geometry:** Both the finite element analysis and the ML surrogate optimization script indicate that a filleted, near-square cross-section provides the highest structural stability across the majority of tested NYC geological scenarios.
*   **Surrogate Accuracy:**
    *   **Baseline Elastic Model (No sequential backfilling):** Achieves **>95% accuracy** predicting structural stress components.
    *   **Intermediate Model (No varied loading shapes):** Demonstrates a 33% error rate.
    *   **Advanced Model (Elastoplasticity + Sequential Backfilling + Varied Loading):** Currently in development. 

## 5. Next Steps
This repository provides a validated baseline methodology for utilidor simulation. Future work required to finalize the computational pipeline includes:
1.  Complete training of the final-stage surrogate model incorporating sequential backfilling and elastoplastic material behavior (e.g., Drucker-Prager yield surfaces).
2.  Integrate varying load shapes and dynamic multimodal transit vibrations into the training dataset.
3.  Refine cross-sectional optimization for resonance resistance.

## 6. Repository Structure
*   **`simulations/`**: MOOSE input scripts (`.i`, e.g., `simple_utilidor1.i`) defining physics, materials, and boundary conditions.
*   **`meshes/`**: Generated spatial mesh files (`.msh`).
*   **`geo files/`**: `Gmsh` geometry definitions (`.geo`) for physical domain construction.
*   **`data/`**: Training datasets and raw extracted simulation outputs (`.csv`, `.xlsx`).
*   **`scripts/`**: Python pipelines for data processing, automated execution, and JAX/Equinox training (`.py`).
*   **`models/`**: Serialized neural network weights (`.eqx`) and data transformations (`.pkl`).

## 7. Installation & Execution

### Prerequisites
1.  Install the [MOOSE framework](https://mooseframework.inl.gov/).
2.  Install Python dependencies: `pip install jax equinox optax gmsh pandas scipy scikit-learn`

### Compilation
When compiling your MOOSE application, use the `make -jN` command, where `N` is the number of CPU cores you want to allocate (e.g., `make -j2`, `make -j4`, or `make -j8`). Match this number to your hardware specifications to optimize compilation and solver speed.

**Important:** The configuration scripts assume your compiled executable is named `dog` (executed via `./dog-opt`). Update run commands if your binary is named differently.

### Running the Pipeline
1.  **Generate Meshes:** Execute Python scripts in `scripts/` to generate `.msh` files via Gmsh.
2.  **Run FEA:** Execute MOOSE simulations (e.g., `./dog-opt -i simulations/simple_utilidor1.i`).
3.  **Train Surrogate:** Run the model training script to process `/data/` outputs and serialize the trained model to `models/`.