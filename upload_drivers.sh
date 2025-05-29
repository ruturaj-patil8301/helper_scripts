#!/bin/bash
#
# Driver Upload Script
# 
# This script automates the process of uploading compiled kernel drivers to Rubrik's Artifactory.
# It handles two categories of drivers:
# 1. Regular drivers: mpt3sas, mellanox, ice, bnxt_en, mpi3mr, igb
# 2. Special drivers: jnl, ufsd
#
# For each driver, the script:
# - Verifies file existence
# - Runs modinfo on kernel modules (.ko files)
# - Uploads files to the appropriate Artifactory location
#
# The script requires JFrog CLI, which it downloads and configures automatically.
#
set -e  # Exit immediately if a command exits with a non-zero status

#--------- Configuration ---------

# Kernel version for which these drivers are compiled
KERNEL_VER="5.15.0-140-rubrik7-generic"

# RC number for special drivers (jnl, ufsd)
RC_NUMBER="56"

# Artifactory base directories
ARTIFACTORY_BASE="legacy-archive-local/manufacturing/drivers"
ARTIFACTORY_SPECIAL="artifactory/files/rubrik/refs"

# JFrog CLI binary URL (Ubuntu)
JFROG_BINARY_URL="https://repository.rubrik.com/artifactory/files/tools/stark/jfrog/jfrog-cli-linux-amd64/2.3.0/jfrog"

# Driver Versions - maps driver names to their version strings
# These versions are used in the Artifactory path
declare -A DRIVER_VERSIONS=(
    ["mpt3sas"]="mpt3sas-51.00.00.00"
    ["mellanox"]="mlx-5.8-5.1.1.2"
    ["ice"]="ice-1.14.13"
    ["bnxt_en"]="bnxt_en-1.10.3-231.0.162.0"
    ["mpi3mr"]="mpi3mr-8.6.1.0.0"
    ["igb"]="igb-5.17.4"
)

# Driver Files - maps driver names to their associated files
# These are the base filenames without the kernel version suffix
declare -A DRIVER_FILES=(
    ["mpt3sas"]="mpt3sas.ko"
    ["mellanox"]="mlx5_core.ko mlx_compat.ko mlxfw.ko mlx5_ib.ko mlxdevm.ko"
    ["ice"]="ice.ko ice-vfio-pci.ko ice-1.3.36.0.pkg LICENSE Module.symvers README"
    ["bnxt_en"]="bnxt_en.ko"
    ["mpi3mr"]="mpi3mr.ko"
    ["igb"]="igb.ko"
)

# Special Drivers - maps special driver names to their complete filenames
# These drivers use a different naming convention that includes kernel version and RC number
declare -A SPECIAL_DRIVERS=(
    ["jnl"]="jnl.ko.${KERNEL_VER}.${RC_NUMBER}"
    ["ufsd"]="ufsd.ko.${KERNEL_VER}.${RC_NUMBER}"
)

#--------- Functions ---------

# Download and configure JFrog CLI for Artifactory uploads
initiate_setup() {
    echo "[INIT] Downloading JFrog CLI..."
    curl -Lo jfrog "$JFROG_BINARY_URL"
    chmod +x jfrog

    echo "[INIT] Running JFrog CLI setup..."
    if ! ./jfrog rt p; then
        # Exit if JFrog CLI setup fails
        echo "[ERROR] JFrog CLI setup failed. Exiting."
        exit 1
    else
        echo "[INIT] JFrog CLI successfully configured."
    fi
}

# Run modinfo command on kernel module files
# Creates a temporary copy to avoid permission issues
run_modinfo_if_ko() {
    local file="$1"
    local temp_mod="temp_module.ko"
    cp "$file" "$temp_mod"
    echo "----- Running modinfo on $file -----"
    #modinfo "$temp_mod"
    rm "$temp_mod"
    echo "------------------------------------"
}

# Upload a file to JFrog Artifactory
# Uses the JFrog CLI with the --flat option to preserve filename
upload_file_to_jfrog() {
    local file="$1"
    local dest_dir="$2"
    echo "Uploading: $file --> $dest_dir/"
    ./jfrog rt upload --flat "$file" "$dest_dir/"
    echo "Upload successful."
}

# Process a regular driver
# Checks if each file exists, runs modinfo if it's a kernel module, and uploads it
process_driver() {
    local driver="$1"
    local version="$2"
    local art_dir="$3"
    local file_list="$4"

    full_art_dir="$art_dir/$version"

    echo "=========================================="
    echo "Driver: $driver"
    echo "Artifactory Directory: $full_art_dir"
    echo "File(s): $file_list"

    for file in $file_list; do
        if [ -f "$file" ]; then
            echo "[FOUND] $file"

            # Run modinfo on kernel module files
            if [[ "$file" =~ \.ko ]]; then
                run_modinfo_if_ko "$file"
            fi

            upload_file_to_jfrog "$file" "$full_art_dir"
        else
            echo "[MISSING] $file"
        fi
        echo ""
    done
}

# Process a special driver (jnl, ufsd)
# Checks if the file exists, runs modinfo if it's a kernel module, and uploads it
process_special_driver() {
    local driver="$1"
    local special_file="$2"
    local art_dir="$3"

    echo "=========================================="
    echo "Special Driver: $driver"
    echo "Artifactory Directory: $art_dir"
    echo "File: $special_file"

    if [ -f "$special_file" ]; then
        echo "[FOUND] $special_file"

        # Run modinfo on kernel module files
        if [[ "$special_file" =~ \.ko ]]; then
            run_modinfo_if_ko "$special_file"
        fi

        upload_file_to_jfrog "$special_file" "$art_dir"
    else
        echo "[MISSING] $special_file"
    fi
    echo ""
}

#--------- Main Execution ----------------

# Step 1: Initiate setup of jfrog binary and configuration
initiate_setup

# Step 2: Process regular drivers
for driver in "${!DRIVER_FILES[@]}"; do
    version="${DRIVER_VERSIONS[$driver]}"
    files="${DRIVER_FILES[$driver]}"

    # Append kernel version to each file name
    files_to_process=""
    for file in $files; do
        files_to_process+="$file.$KERNEL_VER "
    done

    process_driver "$driver" "$version" "$ARTIFACTORY_BASE" "$files_to_process"
done

# Step 3: Process special drivers (jnl & ufsd)
for special_driver in "${!SPECIAL_DRIVERS[@]}"; do
    special_file="${SPECIAL_DRIVERS[$special_driver]}"
    process_special_driver "$special_driver" "$special_file" "$ARTIFACTORY_SPECIAL"
done

echo "=========================================="
echo "All driver uploads completed."
