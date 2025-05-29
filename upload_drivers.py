#!/bin/bash
set -e

#----------- Configuration --------------------

# Kernel version (change accordingly)
KERNEL_VER="5.15.0-140-rubrik7-generic"

# JFrog Artifactory Base Directory
ARTIFACTORY_BASE="legacy-archive-local/manufacturing/drivers"

# Driver versions (update if changed)
declare -A DRIVER_VERSIONS=(
    ["mpt3sas"]="mpt3sas-51.00.00.00"
    ["mellanox"]="mlx-5.8-5.1.1.2"
    ["ice"]="ice-1.14.13"
    ["bnxt_en"]="bnxt_en-1.10.3-231.0.162.0"
    ["mpi3mr"]="mpi3mr-8.6.1.0.0"
    ["igb"]="igb-5.17.4"
)

# Driver files
declare -A DRIVER_FILES=(
    ["mpt3sas"]="mpt3sas.ko"
    ["mellanox"]="mlx5_core.ko mlx_compat.ko mlxfw.ko mlx5_ib.ko mlxdevm.ko"
    ["ice"]="ice.ko ice-vfio-pci.ko ice-1.3.36.0.pkg LICENSE Module.symvers README"
    ["bnxt_en"]="bnxt_en.ko"
    ["mpi3mr"]="mpi3mr.ko"
    ["igb"]="igb.ko"
)

#------------ Script Execution ----------------

for DRIVER in "${!DRIVER_FILES[@]}"; do
    echo "=========================================="
    echo "Driver: $DRIVER"

    DRIVER_DIR="${DRIVER_VERSIONS[$DRIVER]}"
    ARTIFACTORY_DIR="$ARTIFACTORY_BASE/$DRIVER_DIR"
    echo "Artifactory Directory: $ARTIFACTORY_DIR"

    FILES="${DRIVER_FILES[$DRIVER]}"
    echo "Files to upload and verify:"

    for FILE_BASE in $FILES; do
        FULL_FILE_NAME="${FILE_BASE}.${KERNEL_VER}"

        if [ -f "$FULL_FILE_NAME" ]; then
            echo "   ✔️ Found file: $FULL_FILE_NAME"

            # Check if file is a kernel module (*.ko)
            if [[ "$FILE_BASE" =~ \.ko$ ]]; then
                echo "     Running modinfo on $FULL_FILE_NAME:"
                TEMP_FILE="$(basename "$FILE_BASE")"
                cp "$FULL_FILE_NAME" "$TEMP_FILE"
                #modinfo "$TEMP_FILE"
                rm "$TEMP_FILE"
            fi

            # Upload file to JFrog
            echo "     Uploading $FULL_FILE_NAME to $ARTIFACTORY_DIR/"
            jfrog rt upload --flat "$FULL_FILE_NAME" "$ARTIFACTORY_DIR/"

        else
            echo "   ❌ WARNING: $FULL_FILE_NAME not found!"
        fi
    done
    echo ""
done

echo "=========================================="
echo "🎉 All uploads done!"
