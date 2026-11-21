#!/bin/bash

# Exit on error
set -e 

# GUARD TO ALLOW THE EXECUTION ONLY IN THE PROJECT ROOT DIRECTORY
if [ ! -d "simulations" ] || [ ! -d "inputs" ] || [ ! -d "inputs/mdp_files" ] ; then 
    echo "Error: run this script from the project root directory"
    exit 1
fi

echo ""
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

select_mdp_file() {
    shopt -s nullglob
    local mdp_files=(inputs/mdp_files/*.mdp)
    shopt -u nullglob

    if [ ${#mdp_files[@]} -eq 0 ]; then
        echo "Error: no .mdp files found in inputs/mdp_files." >&2
        return 1
    fi

    # Extract file names
    local file_names=()
    for f in "${mdp_files[@]}"; do
        file_names+=("$(basename "$f")")
    done

    local old_ps3="$PS3"
    PS3="Select a MDP file (1-${#file_names[@]}): "
    select fname in "${file_names[@]}"; do
        if [ -n "$fname" ]; then
            SELECTED_MDP="${fname%.pdb}" 
            break
        else
            echo "Invalid selection. Insert a number from 1 to ${#file_names[@]}."
        fi
    done
    PS3="$old_ps3"
}


# MENU
PS3="Select Option (1-6): "
options=("Download PDB" "Edit molecular dynamics parameters (.mpd)" "Mutate protein" "Run simulation" "Purge /simulations" "Exit")

select opt in "${options[@]}"; do
    echo ""
    case "$REPLY" in
        1)
            read -rp "Insert protein PDB code (es. 1QLX): " PDB_RAW
            if [ -z "$PDB_RAW" ]; then
                echo "Error: no code provided" >&2
                continue
            fi

            PDB_ID=$(printf '%s' "$PDB_RAW" | tr '[:lower:]' '[:upper:]')
            echo "Downloading ${PDB_ID}.pdb..."
            ./scripts/retrieve.sh "$PDB_ID"
            echo "Download completed: inputs/${PDB_ID}.pdb"
            echo ""
            REPLY=""
            ;;

        2)
            select_mdp_file || { REPLY=""; continue; }
            nano "inputs/mdp_files/${SELECTED_MDP}"
            echo ""
            REPLY=""
            ;;


        3)
            # TODO
            REPLY=""
            ;;

        4)
            select_pdb_file || { REPLY=""; continue; }

            echo "Running simulation for ${SELECTED_PDB}..."
            ./scripts/run_pipeline.sh "inputs/${SELECTED_PDB}.pdb"
            REPLY=""
            ;;

        5)  
            rm -r simulations/*
            echo "All run directories have been deleted."
	    echo ""
            REPLY=""
            ;;

        6)
            echo "I hope you had fun. See you soon ;)"
            exit 0
            ;;

        *)
            echo "Insert a number from 1 to 6."
            ;;
    esac
done
