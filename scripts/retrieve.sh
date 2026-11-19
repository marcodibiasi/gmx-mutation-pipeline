#!/bin/bash

# Exit on error
set -e 

# CHECK WHETHER THE FIRST ARGUMENT IS EMPTY 
if [ -z "$1" ]; then 
    echo "Error: no PDB name provided"
    exit 1 
fi

# GUARD TO ALLOW THE EXECUTION ONLY IN THE PROJECT ROOT DIRECTORY
if [ ! -d "simulations" ] || [ ! -d "inputs" ] || [ ! -d "inputs/mdp_files" ] ; then 
    echo "Error: run this script from the project root directory"
    exit 1
fi

PDB=${1^^}
OUT="inputs/${PDB}.pdb"
curl -f -s -S "https://files.rcsb.org/download/${PDB}.pdb" -o "inputs/${PDB}.pdb"


if ! curl -f -s "https://files.rcsb.org/download/${PDB}.pdb" -o "$OUT"; then
    echo "Error: PDB file '${PDB_ID}' not found or download failed." >&2
    rm -f "$OUT"
    exit 1
fi
