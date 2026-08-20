# Cornell-Utilidor-MOOSE-research
Computational pipeline for utilidor structural stability analysis in heterogeneous NYC geology. Integrates MOOSE framework finite element modeling with JAX/Equinox surrogate neural networks. Evaluates structural performance under variable geological and loading conditions. Includes simulation inputs, datasets, and trained model weights.

## Instructions

### Prerequisites
1. Download and install the [MOOSE framework](https://mooseframework.inl.gov/).
2. Compile your MOOSE application.
3. **Important:** The configuration files and scripts in this repository assume your compiled application executable is named `dog` (e.g., executed via `./dog-opt`). If your compiled application is named differently, you must update the executable name in your run commands before executing the `.i` files.

### Repository Structure
This repository is organized into distinct categories. Review the individual `README.md` file located inside each folder for detailed execution instructions.

* **`simulations/`**: MOOSE input scripts (`.i`) defining the finite element physics, materials, and boundary conditions.
* **`meshes/`**: Gmsh geometry definitions (`.geo`) and generated spatial mesh files (`.msh`).
* **`data/`**: Structured training datasets and raw extracted simulation outputs (`.csv`, `.xlsx`).
* **`scripts/`**: Python pipelines for data processing, machine learning training via JAX/Equinox, and prediction generation (`.py`).
* **`models/`**: Serialized machine learning artifacts, including neural network weights (`.eqx`) and data transformations (`.pkl`).
