# GROMACS Mutation Pipeline 🚧 (Work in Progress)

*Note: This project is currently under active development.*

This repository contains scripts to automate the preparation and simulation of molecular dynamics systems in GROMACS. 

## 📁 Directory Structure

* **`inputs/`** $\rightarrow$ Place your initial `.pdb` files here.
* **`scripts/`** $\rightarrow$ Contains bash scripts (`run_pipeline.sh`).
* **`simulations/`** $\rightarrow$ Output directory. The script generates isolated subfolders for each run.
* **`analysis/`** $\rightarrow$ Reserved for post-simulation analysis.

---

## 🚀 Quick Start

**1. Grant execution permissions (first time only):**
```bash
chmod +x scripts/run_pipeline.sh
```

**2. Run the setup script:**
Pass the the path of the PDB file as an argument.
```bash
./scripts/run_pipeline.sh inputs/protein.pdb
```

## 📂 Generated Outputs

For each execution, the script creates a dedicated subfolder inside `simulations/` (e.g., `simulations/run_protein/`). Inside this folder, you will find the prepared system and all the intermediate files:

* **`*_box_ions.gro`**: The final, fully prepared structure containing the protein, water molecules, and ions. *(This is the main coordinate file for the next steps).*
* **`*.top`**: The system topology file, automatically updated to include water and ions.
* **`*.itp`**: Position restraint files used to lock the protein structure during equilibration.
* **`logs/`**: A dedicated subdirectory containing all the raw text outputs from GROMACS commands (e.g., `pdb2gmx.log`, `solvate.log`). This keeps the workspace clean while allowing easy debugging if anything goes wrong.
