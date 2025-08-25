#!/bin/bash

# Usage:
#   The ./generate_certs.sh script need to be present on the current directory
#   ./rucio_ca_certs-cvmfs-updater.sh

set -e  # Exit on error
set -u  # Treat unset variables as errors

MOUNTPOINT="/cvmfs/sw.escape.eu"
TARGET_DIR="etc/ssl/certs"

echo "Generate RUCIO CA certs..."
if [ -f "./generate_certs.sh" ]; then
    ./generate_certs.sh
else
    echo "ERROR: `generate_certs.sh` is not present in the current directory."
    exit 1
fi

echo "Starting CVMFS transaction..."
cvmfs_server transaction sw.escape.eu

echo "Cleaning old rucio CA certs if they exists..."

rm "${MOUNTPOINT}/${TARGET_DIR}/rucio_ca.pem" || true

echo "Copying Rucio CA certs..."
mv rucio_ca.pem "${MOUNTPOINT}/${TARGET_DIR}/"

cd "$HOME"

echo "Publishing CVMFS..."
cvmfs_server publish sw.escape.eu

echo "Done."