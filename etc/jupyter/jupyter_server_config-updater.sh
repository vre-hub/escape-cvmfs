#!/bin/bash

# Usage:
#   ./jupyter_server_config-updater.sh

set -e  # Exit on error
set -u  # Treat unset variables as errors

MOUNTPOINT="/cvmfs/sw.escape.eu"
TARGET_DIR="etc/jupyter"

if [[ ! -f "./jupyter_server_config.py"  ]]; then
  echo "The jupyter_server_config.py does not exist in the current directory."
  exit 1
fi

echo "Starting CVMFS transaction..."
cvmfs_server transaction sw.escape.eu

echo "Cleaning old jupyter_server_config.pyt file if it exist..."

mkdir -p "${MOUNTPOINT}/${TARGET_DIR}"
rm "${MOUNTPOINT}/${TARGET_DIR}/jupyter_server_config.py" || true

echo "Copying jupyter_server_config.py file..."
cp jupyter_server_config.py "${MOUNTPOINT}/${TARGET_DIR}/"

cd "$HOME"

echo "Publishing CVMFS..."
cvmfs_server publish sw.escape.eu

echo "Done."
