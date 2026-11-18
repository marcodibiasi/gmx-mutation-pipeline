#!/bin/bash

# Exit on error
set -e 

# CHECK WHETHER THE FIRST ARGUMENT IS EMPTY 
if [ -z "$1" ]; then 
    echo "Error: no PDB file provided"
    exit 1 
fi

# GUARD TO ALLOW THE EXECUTION ONLY IN THE PROJECT ROOT DIRECTORY
if [ ! -d "simulations" ] || [ ! -d "inputs" ] || [ ! -d "inputs/mdp_files" ] ; then 
    echo "Error: run this script from the project root directory"
    exit 1
fi

INPUT_PDB=$1
ABS_PDB=$(realpath "$INPUT_PDB")
MDP_DIR=$(realpath "inputs/mdp_files")
PROT=$(basename "$INPUT_PDB" .pdb)
RUN_DIR="simulations/run_${PROT}"

echo -e "\n>>> PREPARATION: $PROT"
echo "[INFO] Workspace: $RUN_DIR"
mkdir -p "$RUN_DIR"
cd "$RUN_DIR" || exit 1
mkdir -p "logs"


# =======================
#        TOPOLOGY
# =======================
# -f: input file (.pdb)
# -i: position restrains (.itp) -> lock the protein structure
# -o: output structure (.gro) -> spatial coordinates and velocities
# -p: topology file (.top) -> system physical rules
# -ff: forcefield
# -water: water model
# -ignh: ignore hydrogens
# -heavyh: makes hydrogen atoms heavy -> reduce oscillations
# -quiet: reduce the printed output
echo "[1/4] Topology generation (pdb2gmx)..."
gmx pdb2gmx \
    -f "$ABS_PDB" \
    -i "${PROT}_posre.itp" \
    -o "${PROT}_processed.gro" \
    -p "${PROT}.top" \
    -ff amber99sb-ildn \
    -water tip3p \
    -ignh \
    -heavyh \
    -quiet &> logs/pdb2gmx.log


# =======================
#          BOX
# =======================
# -f: input file (.gro)
# -o: output box file (.gro)
# -c: center molecule in box
# -d: distance between the solute and the box
# -bt: box type
# -quiet: reduce the printed output
echo "[2/4] Defining the simulation box (editconfig)..."
gmx editconf \
    -f "${PROT}_processed.gro" \
    -o "${PROT}_box.gro" \
    -c \
    -d 0.8 \
    -bt cubic \
    -quiet &> logs/editconfig.log


# =======================
#        SOLVATION
# =======================
# -cp: configuration protein (.gro): box containing the centered protein 
# -cs: configuration solvent (.gro): generic water box (can be omitted)
# -o: output structure (.gro): final coordinated of protein + water
# -p: topology file (.top): auto-updates the topology file
# -quiet: reduce the printed output
echo "[3/4] Solvation of the system (solvate)..."
gmx solvate \
    -cp "${PROT}_box.gro" \
    -cs spc216.gro \
    -o "${PROT}_solvated.gro" \
    -p "${PROT}.top" \
    -quiet &> logs/solvate.log


# =======================
#      GENERATE IONS 
# =======================
# grompp (gromacs pre-processor):
# -f: input parameters (.mdp): parameters for compilation
# -c: input coordinates (.gro): solvated system
# -p: topology file (.top)
# -o: output run file (.trp): compiled binary file for genion
# -quiet: reduce the printed output

# genion (generate ions):
# -s: input run file (.tpr)
# -p: topology file (.top): auto-updates the topology file
# -o: output structure (.gro): final system
# -pname / -name: names of positive and negative ions 
# -neutral: neutralize the system charge 
# -conc: adds salt concentration
# -quiet: reduce the printed output
echo "[4/4] Adding ions to the system (grompp & genion)..."

gmx grompp \
    -f "$MDP_DIR/ions.mdp" \
    -c "${PROT}_solvated.gro" \
    -p "${PROT}.top" \
    -o ions.tpr \
    -quiet &> logs/grompp_ions.log

echo "SOL" | gmx genion \
    -s ions.tpr \
    -p "${PROT}.top" \
    -o "${PROT}_box_ions.gro" \
    -pname NA \
    -nname CL \
    -neutral \
    -conc 0.15 \
    -quiet &> logs/genion.log


# -----------------------
#  SIMULATING THE SYSTEM
# -----------------------
echo -e "\n>>> SIMULATION: $PROT"

# =======================
#   ENERGY MINIMIZATION 
# =======================
# mdrun (simulator):
# -s: input file (.tpr)
# -deffnm: define file name 
# -quiet: reduce the printed output
#
# energy (extracts energy data): 
# -f: input file (.edr)
# -o: output file (.xvg)
echo "[1/3] Energy Minimization (grompp & mdrun)..."
mkdir -p "00-em"

gmx grompp \
    -f "$MDP_DIR/em.mdp" \
    -p "${PROT}.top" \
    -c "${PROT}_box_ions.gro" \
    -o 00-em/em.tpr \
    -quiet &> logs/grompp_em.log

gmx mdrun \
    -s 00-em/em.tpr \
    -deffnm 00-em/em \
    -quiet &> logs/mdrun.log

echo -e "Potential \n 0" | gmx energy \
    -f 00-em/em.edr \
    -o 00-em/potential_em.xvg\
    -quiet &> logs/energy.log


# =======================
#   POSITION RESTRAINT 
# =======================
echo "[2/3] Position Restraint (grompp, mdrun)..." 

# NVT equilibration
mkdir -p "01-posres"  
mkdir -p 01-posres/nvt 01-posres/npt
gmx grompp \
    -f "$MDP_DIR/nvt_posres.mdp" \
    -c 00-em/em.gro \
    -r 00-em/em.gro \
    -p "${PROT}.top" \
    -o 01-posres/nvt/nvt_posres.tpr \
    -maxwarn 2 \
    -quiet &> logs/posres1.log 

gmx mdrun \
    -s 01-posres/nvt/nvt_posres.tpr \
    -deffnm 01-posres/nvt/nvt_posres \
    -quiet &> logs/posres2.log

# NPT equilibration
gmx grompp \
    -f "$MDP_DIR/ntp_posres.mdp" \
    -c 00-em/em.gro \
    -r 00-em/em.gro \
    -p "${PROT}.top" \
    -o 01-posres/npt/npt_posres.tpr \
    -maxwarn 2 \
    -quiet &> logs/posres3.log 

gmx mdrun \
    -s 01-posres/npt/npt_posres.tpr \
    -deffnm 01-posres/npt/npt_posres \
    -quiet &> logs/posres4.log


#check if the temperature and pressure are well equilibrated 
# echo -e "Temperature \n Pressure \n 0" | gmx energy \
#    -f 01-posres/posres.edr \
#    -o 01-posres/Temp_Press.xvg \
#    -quiet &> logs/temp_press.log

#echo -e "Density \n 0" | gmx energy \
#    -f 01-posres/posres.edr \
#    -o 01-posres/Density.xvg \
#    -quiet &> logs/temp_press.log

# ======================================
# PRODUCTION WITHOUT POSITION RESTRAINT
# =====================================

echo "[3/3] Production Without Position Restraint (grompp, mdrun)..." 

mkdir 02-prod
gmx grompp \
    -f "$MDP_DIR/prod.mdp" \
    -c 01-posres/npt/npt_posres.gro \
    -p "${PROT}.top" \
    -o 02-prod/prod.tpr\
    -quiet &> logs/prod1.log

gmx mdrun \
    -deffnm 02-prod/prod \
    -s 02-prod/prod.tpr \
    -v \
    -quiet &> logs/prod2.log


