#!/bin/bash

# Exit on error
set -e 

# Check whether the first argument is empty 
if [ -z "$1" ]; then 
    echo "Error: no PDB file provided"
    exit 1 
fi

# Guard to avoid running the command in the root
if [ ! -d "simulations" ] || [ ! -d "inputs" ]; then 
    echo "Error: run this script from the project root directory"
    exit 1
fi

INPUT_PDB=$1
ABS_PDB=$(realpath "$INPUT_PDB")
PROT=$(basename "$INPUT_PDB" .pdb)
RUN_DIR="simulations/run_${PROT}"

echo -e "\n>>> SIMULATION: $PROT"
echo "[INFO] Workspace: $RUN_DIR"
mkdir -p "$RUN_DIR"
cd "$RUN_DIR" || exit 1

# Topology
echo "[1/4] Topology generation (pdb2gmx)..."
gmx pdb2gmx -f "$ABS_PDB" -o "${PROT}_processed.gro" -p "${PROT}.top" -ff amber99sb-ildn -water tip3p -ignh -quiet &> pdb2gmx.log

# Box 
echo "[2/4] Defining the simulation box (editconfig)..."
gmx editconf -f "${PROT}_processed.gro" -o "${PROT}_box gro" -c -d 1.2 -bt cubic -quiet &> editconfig.log
