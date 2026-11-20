#!/bin/bash

# Exit on error
set -e 

# GUARD TO ALLOW THE EXECUTION ONLY IN THE PROJECT ROOT DIRECTORY
if [ ! -d "simulations" ] || [ ! -d "inputs" ] || [ ! -d "inputs/mdp_files" ] ; then 
    echo "Error: run this script from the project root directory"
    exit 1
fi


echo "=== GMX Mutation Pipeline ==="


select_pdb_file() {
    shopt -s nullglob
    local pdb_files=(inputs/*.pdb)
    shopt -u nullglob

    if [ ${#pdb_files[@]} -eq 0 ]; then
        echo "Error: no .pdb files found in inputs/." >&2
        return 1
    fi

    # Extract file names
    local file_names=()
    for f in "${pdb_files[@]}"; do
        file_names+=("$(basename "$f")")
    done

    local old_ps3="$PS3"
    PS3="Select a PDB file (1-${#file_names[@]}): "
    select fname in "${file_names[@]}"; do
        if [ -n "$fname" ]; then
            SELECTED_PDB="${fname%.pdb}" 
            break
        else
            echo "Invalid selection. Insert a number from 1 to ${#file_names[@]}."
        fi
    done
    PS3="$old_ps3"
}


# MENU
echo ""
PS3="Select Option (1-5): "
options=("Download PDB" "Mutate protein" "Run simulation" "Erase /simulation" "Exit")

select opt in "${options[@]}"; do
    echo ""
    case "$REPLY" in
        1)
            read -rp "Insert protein PDB code (es. 1QLX): " PDB_RAW
            if [ -z "$PDB_RAW" ]; then
                echo "Error: no code provided" >&2
                continue
            fi

            PDB_ID="${PDB_RAW^^}"
            echo "Downloading ${PDB_ID}.pdb..."
            ./scripts/retrieve.sh "$PDB_ID"
            echo "Download completed: inputs/${PDB_ID}.pdb"
            echo ""
            REPLY=""
            ;;

        2)
            # TODO
            REPLY=""
            ;;

        3)
            select_pdb_file || { REPLY=""; continue; }

            echo "Running simulation for ${SELECTED_PDB}..."
            ./scripts/run_pipeline.sh "inputs/${SELECTED_PDB}.pdb"
            REPLY=""
            ;;
        4)
          rm -r simulations/*
          echo "simulations/ deleted "
          REPLY=""
          ;;



        5)
            echo "I hope you had fun. See you soon ;)"
            exit 0
            ;;
        *)
            echo "Insert a number from 1 to 5."
            ;;
    esac
done
