#!/bin/bash

# Exit on error
set -e 

# CHECK WHETHER THE FIRST ARGUMENT IS EMPTY 
if [ -z "$1" ]; then 
    echo "Error: no PDB file provided"
    exit 1 
fi

# GUARD TO ALLOW THE EXECUTION ONLY IN THE PROJECT ROOT DIRECTORY
if [ ! -d "simulations" ] || [ ! -d "inputs" ]; then 
    echo "Error: run this script from the project root directory"
    exit 1
fi

INPUT_PDB=$1
ABS_PDB=$(realpath "$INPUT_PDB")
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
touch ions.mdp
gmx grompp \
    -f ions.mdp \
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
echo "[1/n] Energy Minimization (grompp & mdrun)..."
echo "integrator  = steep 
emtol = 1000.0 
emstep = 0.01  
nstenergy = 10   
nsteps = 1000    
constraints = h-bonds   
rcoulomb = 1.0      
rvdw = 1.0     
vdw-modifier = Potential-shift-Verlet 
DispCorr = EnerPres  
coulombtype = PME       
fourierspacing = 0.125" > em.mdp
mkdir -p "00-em"

gmx grompp \
    -f em.mdp \
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
echo "[2/n] Position Restraint (grompp)..." 
echo "title = NVT equilibration 
define = -DPOSRES  
integrator = md        
nsteps = 50000     
dt = 0.002     
nstxout = 500       
nstvout = 500       
nstenergy = 500       
nstlog = 500       
continuation = no        
constraint_algorithm = lincs     
constraints = h-bonds   
lincs_iter = 1         
lincs_order = 4         
cutoff-scheme = Verlet    
ns_type = grid      
nstlist = 10        
rcoulomb = 1.0       
rvdw = 1.0       
coulombtype = PME       
pme_order = 4         
fourierspacing = 0.16      
tcoupl = V-rescale             
tc-grps = Protein Non-Protein   
tau_t = 0.1     0.1           
ref_t = 300     300           
pcoupl = no        
pbc = xyz       
gen_vel = yes      
gen_temp = 300      
gen_seed = -1" > posres.mdp      
mkdir -p "01-posres"  

gmx grompp \
    -f posres.mdp \
    -c 00-em/em.gro \
    -r 00-em/em.gro \
    -p "${PROT}.top" \
    -o 01-posres/posres.tpr \
    -maxwarn 2 \
    -quiet &> logs/posres1.log 

gmx mdrun \
    -s 01-posres/posres.tpr \
    -deffnm 01-posres/posres \
    -v \
    -nt 12 \
    -quiet &> logs/posres2.log 


